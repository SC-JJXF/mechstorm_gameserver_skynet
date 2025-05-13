local SendToClient_Original = _G.SendToClient  -- 先声明变量

local function SendToClient(type, body)
    SendToClient_Original("matchctl", {type = type, body = body})
end

local s = require "service"
local room_model = require "models.room"
local sm = require('statemachine')

local M = {}

local S = {}
-- 状态定义
S.NONE = "NONE" -- 无
S.MATCHING_RANDOM = "MATCHING_RANDOM" -- 匹配中 (随机)
S.CHALLENGING_WAIT_ACK = "CHALLENGING_WAIT_ACK" -- 挑战-等待对方接受
S.CHALLENGED_WAIT_MY_ACK = "CHALLENGED_WAIT_MY_ACK" -- 被挑战-等待我接受
S.CHALLENGE_ACCEPTED_WAIT_ROOM = "CHALLENGE_ACCEPTED_WAIT_ROOM" -- (我方)接受挑战后，等待服务器分配房间
S.ROOM_READY = "ROOM_READY" -- 获取到对战房间

-- 用于存储挑战者信息，当被挑战时，挑战只允许1v1
local current_challenger_uid = nil
-- 用于存储被挑战者信息，当发起挑战时
local current_opponent_uid = nil
-- 用于存储发起匹配时选择的游戏模式
local current_matching_mode = nil

local matchstate = sm.create({
    initial = S.NONE,
    events = {
        -- 随机匹配流程
        { name = 'match_random', from = S.NONE, to = S.MATCHING_RANDOM },
        { name = 'cancel_match_random', from = S.MATCHING_RANDOM, to = S.NONE },
        { name = 'room_ready', from = S.MATCHING_RANDOM, to = S.NONE },

        -- 发起挑战流程
        { name = 'challenge_player', from = S.NONE, to = S.CHALLENGING_WAIT_ACK },
        { name = 'opponent_rejected_challenge', from = S.CHALLENGING_WAIT_ACK, to = S.NONE }, -- 对方拒绝
        { name = 'room_ready', from = S.CHALLENGING_WAIT_ACK, to = S.NONE }, -- 对方接受

        -- 被挑战流程
        { name = 'being_challenged', from = S.NONE, to = S.CHALLENGED_WAIT_MY_ACK },
        { name = 'reject_incoming_challenge', from = S.CHALLENGED_WAIT_MY_ACK, to = S.NONE }, -- 我方拒绝
        { name = 'accept_incoming_challenge', from = S.CHALLENGED_WAIT_MY_ACK, to = S.CHALLENGE_ACCEPTED_WAIT_ROOM }, -- 我方接受
        { name = 'room_ready', from = S.CHALLENGE_ACCEPTED_WAIT_ROOM, to = S.NONE }, -- 房间就绪(我接受挑战后)

    },
    callbacks = {
        onafterNONE = function(self, event, from, to)
            current_challenger_uid = nil
            current_opponent_uid = nil
            current_matching_mode = nil
        end,
        onbeforematch_random = function(self, event, from, to, PVP_TYPE)
            -- Log("onbeforematch_random" .. PVP_TYPE)
            current_matching_mode = PVP_TYPE
            local ok, err = CallUniService("match", "i_want_match", user_info.uid, current_matching_mode)
            if not ok then
                Log(string.format("Player %s: i_want_match failed: %s", user_info.uid, err))
            end
            return ok
        end,
        oncancel_match_random = function(self, event, from, to)
            SendToUniService("match", "cancel_match", user_info.uid,current_matching_mode) -- PVP_TYPE is not strictly needed here by match service for now
        end,
        onbeforechallenge_player = function(self, event, from, to, opponent_uid)
            current_opponent_uid = opponent_uid -- 记录对手
            local ok, err = CallPlayer(current_opponent_uid, "handle_challenge_request", user_info.uid)
            if not ok then
                Log(string.format("Player %s: i_want_p1v1_with %s failed: %s", user_info.uid, opponent_uid, err))
                SendToClient_Original("pop-up-message", { message = "挑战请求发送失败：" .. err, status = "warning"})
            end
            return ok
        end,
        onopponent_rejected_challenge = function(self, event, from, to, reason)
            SendToClient_Original("pop-up-message", { message = "挑战请求被拒绝：" .. reason, status = "info" })
        end,
        onbeing_challenged = function(self, event, from, to, challenger_uid_in)
            current_challenger_uid = challenger_uid_in
            -- TODO: 通知客户端被挑战，等待回应
            SendToClient("being_challenged", {challenger_uid = challenger_uid_in})
        end,
        onreject_incoming_challenge = function(self, event, from, to, reason)
            SendToPlayer(current_opponent_uid, "handle_rejected_my_challenge",reason)
        end,
        onaccept_incoming_challenge = function(self, event, from, to)
            SendToUniService("match", "we_accept_challenge",  user_info.uid, current_challenger_uid)
        end,
        onroom_ready = function(self, event, from, to, room_ip)
            SendToActor(s.ip,"go_to_room",room_ip)
        end,
        onstatechange = function(self, event, from, to, ...)
            Log(string.format("Player %s: state %s -> %s by event %s", user_info.uid, from, to, event))
            SendToClient("match_state_update", {current_state = to, event = event, from_state = from})
        end
    }
})

function M.handle_client_message(type, body)
    body = body or {}
    local pvp_type_val
 
    if body.PVP_TYPE then
        pvp_type_val = room_model.PVP_TYPE[body.PVP_TYPE]
        if not pvp_type_val then
            Log(string.format("Player %s: 无效的PVP类型: %s", user_info.uid, body.PVP_TYPE))
            return
        end
    end

    if type == "i_want_match" then
        matchstate:match_random(pvp_type_val)
    elseif type == "cancel_match" then
        matchstate:cancel_match_random()
    elseif type == "i_want_p1v1_with" then
        if not body.opponent_uid then
            Log(string.format("Player %s: 'i_want_p1v1_with' 缺少对方UID", user_info.uid))
            return
        end
        matchstate:challenge_player(body.opponent_uid)
    elseif type == "accept_challenge" then
        matchstate:accept_incoming_challenge()
    elseif type == "reject_challenge" then
        matchstate:reject_incoming_challenge()
    end
end

M.CMD = {}
function M.CMD.handle_challenge_request(challenger_uid_in)
    matchstate:being_challenged(challenger_uid_in)
end
function M.CMD.handle_rejected_my_challenge(reason)
    matchstate:opponent_rejected_challenge(reason)
end
function M.CMD.handle_pvp_room_ready(room_ip)
    Log(matchstate.current)
    matchstate:room_ready(room_ip)
end
function M.on_close()
    -- 根据当前状态触发对应的副作用撤回操作
    local current = matchstate.current
    if current == S.MATCHING_RANDOM then
        matchstate:cancel_match_random()
    elseif current == S.CHALLENGING_WAIT_ACK then
        -- TODO
    elseif current == S.CHALLENGED_WAIT_MY_ACK then
        matchstate:reject_incoming_challenge("对方离开了游戏")
    elseif current == S.CHALLENGE_ACCEPTED_WAIT_ROOM then
        -- TODO
    end
end

return M

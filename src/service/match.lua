--不考虑各种优化匹配的机制（例如隐藏分），只实现简陋的匹配

local skynet = require "skynet"
local s = require "service"
local rm = require "models.room"
local cs = require "skynet.queue"()

local match_state = {
    -- 按PVP类型分组的匹配队列
    queues = {
        [rm.PVP_TYPE.P1V1] = {},
        [rm.PVP_TYPE.P1V1V1V1] = {},
        [rm.PVP_TYPE.P2V2] = {},
    },

}

--- 通知玩家们房间已准备好该进去了
local function notify_players_ready(playerUIDs, roomIP)
    for _, uid in ipairs(playerUIDs) do
        CallPlayer(uid,"handle_pvp_room_ready",roomIP)
    end
end

local function do_match(PVP_TYPE)
    local queue = match_state.queues[PVP_TYPE]
    local min_players = 2
    if PVP_TYPE == rm.PVP_TYPE.P1V1V1V1 or PVP_TYPE == rm.PVP_TYPE.P2V2 then
        min_players = 4
    end
    if #queue < min_players then
        return
    end


    local roomPlayers = {}
    for i = 1, min_players do
        table.insert(roomPlayers, queue[1])
        table.remove(queue, 1)
    end

    local roomIP = CallUniService("room_mgr","create_pvp_room",PVP_TYPE,roomPlayers)

    notify_players_ready(roomPlayers,roomIP)
end

---玩家使用该命令参与随机匹配
s.CMD.i_want_match = function(senderUID, PVP_TYPE)
    if not PVP_TYPE or not match_state.queues[PVP_TYPE] then
        return false, "PVP_TYPE is invaild"
    end
    table.insert(match_state.queues[PVP_TYPE], senderUID)
    do_match(PVP_TYPE) --这里有潜在的，有多个 actor 同时来调用i_want_match时, do_match执行情况未知的问题，小问题，以后再说
    return true
end

---玩家使用该命令取消匹配
s.CMD.cancel_match = function(senderUID, PVP_TYPE)
    local queue = match_state.queues[PVP_TYPE]
    -- 从队列中移除玩家
    for i, player_ip in ipairs(queue) do
        if player_ip == senderUID then
            table.remove(queue, i)
            return true
        end
    end
    return true
end



--- 双方接受挑战，将双方拉入1v1房间
s.CMD.we_accept_challenge = function(accepterUID, challengerUID)
    local roomIP = CallUniService("room_mgr", "create_pvp_room", 
                                rm.PVP_TYPE.P1V1, {challengerUID, accepterUID})
    

    notify_players_ready({challengerUID, accepterUID}, roomIP)
    
end

s.close = function()
end


s.start "match_service"

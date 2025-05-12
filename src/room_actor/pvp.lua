---@diagnostic disable: unnecessary-assert
--- 队伍划分、输赢判断
local M = {}
local rm = require "models.room"
local skynet = require("skynet")
local inited = false

---@type table<integer , integer>
local player_group = {}
local groups = 1

---@param uid integer
function M.on_player_enter(uid, player_sprite_info)
    assert(inited)
    assert(player_group[uid], uid .. "该玩家不合法地加入了房间")
    --当前有未对已死亡玩家做assert的小问题 先不管（估计就算不上问题）

    Room_state.players[uid].group = player_group[uid]
end

---@param uid integer
function M.on_player_leave(uid)
    --玩家游戏中离开即判为死亡
    call_module_func("on_player_die", uid) 
end

---@param uid integer
function M.handle_player_event(uid, type, body)
    if type == "be_hurted" then
        Room_state.players[uid]:DeductHP(body.reduceHP)
    end
end

-- 只有一组活着，胜利结算
function M.on_group_win(groupId)
    if Room_state.game_state == "ended" then
        return
    end
    Room_state.game_state = "ended"
    room_tx_to_players:publish({ type = "group_win", body = {group = groupId} })
end

---还活着的玩家
local alivePlayers = {}
---还活着的团队
local aliveGroups = {}

---@param uid integer
function M.on_player_die(uid)
    assert(inited)
    -- 从存活玩家列表中移除
    for i = #alivePlayers, 1, -1 do
        if alivePlayers[i] == uid then
            table.remove(alivePlayers, i)
            break
        end
    end

    -- 获取玩家所属组
    local group = player_group[uid]

    -- 检查该组是否还有存活玩家
    local hasSurvivor = false
    for _, playerUid in ipairs(alivePlayers) do
        if player_group[playerUid] == group then
            hasSurvivor = true
            break
        end
    end
    if hasSurvivor then
        return
    end
    for i = #aliveGroups, 1, -1 do
        if aliveGroups[i] == group then
            table.remove(aliveGroups, i)
            break
        end
    end
    if #aliveGroups == 1 then
        -- 只有一组活着
        skynet.fork(function()
            call_module_func("on_group_win", aliveGroups[1])
        end)
    end
end

M.CMD = {}
---@param roomPlayers integer[]
---@param PVP_TYPE integer
function M.CMD.pvp_init(roomPlayers, PVP_TYPE)
    if PVP_TYPE == rm.PVP_TYPE.P1V1 or PVP_TYPE == rm.PVP_TYPE.P2V2 then
        groups = 2
    elseif PVP_TYPE == rm.PVP_TYPE.P1V1V1V1 then
        groups = 4
    else
        error("未知PVP_TYPE")
    end

    assert(#roomPlayers % groups == 0, "玩家数必须可以被分组数整除，不然会导致有的组人少")

    for i, uid in ipairs(roomPlayers) do
        -- 0-based分组 (例如：i从1开始，groups=2时结果为1%2=1, 2%2=0, 3%2=1...)
        player_group[uid] = i % groups
        table.insert(alivePlayers, uid)
    end
    for i = 0, groups - 1 do
        table.insert(aliveGroups, i)
    end
    inited = true
end

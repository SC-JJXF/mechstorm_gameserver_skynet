---使得玩家可以连接至一个房间

---@diagnostic disable: need-check-nil
local skynet = require "skynet"
local mc = require "skynet.multicast"
local ROOM_MODEL = (require "models.room_model")
require "service.player_actor"

local M = {}

local tx_to_room, leave_current_room, change_room_to, rx_from_room 

local room = {
    id = nil,
    type = nil,
    tx_to_players_chan = nil
}

local function query_lobby_room_id(lobby_map_name)
    return skynet.call(skynet.queryservice("room_mgr"), "lua", "get_lobby_room",
        ROOM_MODEL.MAP_NAME.hall[lobby_map_name])
end

function M.handle_client_message(type, body)
    if type == "change_lobby_room" then
        if room.type == "lobby" then
            cs(function(map_name)
                local target_lobby_id = query_lobby_room_id(map_name)
                if target_lobby_id then
                    change_room_to(target_lobby_id)
                else
                    Log("无法找到大厅房间: " .. map_name)
                    send_msg_to_client("msg", { message = "目标地图不存在: " .. map_name, sender = "system" })
                end
            end, body.map_name)
        else
            Log("收到 'change_lobby_room' 消息但现在不在大厅中。当前房间类型: " .. (room.type or "无"))
            send_msg_to_client("msg", { message = "请先离开当前游戏房间。", sender = "system" })
        end
        return
    else
        cs(tx_to_room, type, body)
    end
end

rx_from_room = function(channel, source, msg)
    if msg.type == "frame_sync" then
        send_msg_to_client("frame_sync", msg.body)
    elseif msg.type == "room_destroyed" then
        Log("RoomModule: Current room " .. (room.id or "unknown") .. " destroyed, returning to lobby.")
        local lobby_id = query_lobby_room_id("Z战队营地")
        change_room_to(lobby_id)
        send_msg_to_client("msg", { message = "当前房间已关闭，您已被送回大厅。", sender = "system" })
    end
end

tx_to_room = function(type, body)
    if not room.id then
        Log("RoomModule: tx_to_room called but not in a room. Type: " .. type)
        return
    end
    skynet.send(room.id, "lua", "player_" .. type, user_info.uid, body)
end

leave_current_room = function()
    if room.id then
        Log("RoomModule: Leaving room " .. room.id)
        pcall(skynet.call, room.id, "lua", "player_leave", user_info.uid)
    end
    if room.tx_to_players_chan then
        room.tx_to_players_chan:unsubscribe()
        room.tx_to_players_chan = nil
    end
    room.id = nil
    room.type = nil
    Log("RoomModule: Left room. State cleared.")
end

change_room_to = function(new_room_id)
    leave_current_room()

    Log("RoomModule: Attempting to enter room " .. new_room_id)

    local connection_info = skynet.call(new_room_id, "lua", "player_enter", user_info.uid, sprite_info)
    Log("RoomModule: Successfully entered room. 连接至下发的房间频道")
    local new_channel = mc.new {
        channel = connection_info.room_tx_channel_id,
        dispatch = rx_from_room,
    }
    new_channel:subscribe()

    room.id = new_room_id
    room.type = connection_info.room_info and connection_info.room_info.type or "unknown"
    room.tx_to_players_chan = new_channel

    Log("RoomModule: Entered room " .. room.id .. " of type '" .. room.type .. "'. 房间频道已 Subscribed.")

    send_msg_to_client("room_update", connection_info.room_info)
    return true
end


return M

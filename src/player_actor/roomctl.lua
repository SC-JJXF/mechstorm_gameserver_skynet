---使得玩家可以连接至一个房间

---@diagnostic disable: need-check-nil
local skynet = require "skynet"
local mc = require "skynet.multicast"
local ROOM_MODEL = (require "models.room")

local M = {}

local tx_to_room, leave_current_room, change_room_to, rx_from_room 

local room = {
    id = nil,
    type = nil,
    tx_to_players_chan = nil,
    mapid = nil
}

local current_lobby_map_id = ROOM_MODEL.MAP_NAME.hall["Z战队营地"]

--- 若 lobby_map_name 为字符串，则认定其为 地图名 ，否则其为地图id
local function query_lobby_room_id(lobby_map_name_or_id)
    if type(lobby_map_name_or_id) ~= "string" then
        return CallUniService("room_mgr","get_lobby_room", lobby_map_name_or_id)
    end
    return CallUniService("room_mgr","get_lobby_room", ROOM_MODEL.MAP_NAME.hall[lobby_map_name_or_id])
end

function M.handle_client_message(type, body)
    if type == "change_lobby_room" then
        if room.type == ROOM_MODEL.ROOM_TYPE.LOBBY then
            cs(function(map_name)
                    local lri = query_lobby_room_id(map_name)
                    if lri then
                        change_room_to(lri)
                    end
            end, body.map_name)
        else
            Log("收到 'change_lobby_room' 消息但现在不在大厅中。当前房间类型: " .. (room.type or "无"))
        end
    elseif type == "leave_current_room" then
        if room.type ~= ROOM_MODEL.ROOM_TYPE.LOBBY then
            cs(function()
                    change_room_to(query_lobby_room_id(current_lobby_map_id))
            end)
        end
    else
        cs(tx_to_room, type, body)
    end
end

rx_from_room = function(channel, source, msg)
    if msg.type == "frame_sync" or msg.type == "group_win" then
        SendToClient(msg.type, msg.body)
    elseif msg.type == "room_destroyed" then
        Log("RoomModule: Current room " .. (room.id or "unknown") .. " destroyed, returning to lobby.")
        local lobby_id = query_lobby_room_id("Z战队营地")
        change_room_to(lobby_id)
        SendToClient("msg", { message = "当前房间已关闭，您已被送回大厅。", sender = "system" })
    end
        
end

tx_to_room = function(type, body)
    if not room.id then
        -- Log("RoomModule: tx_to_room called but not in a room. Type: " .. type)
        return
    end
    skynet.send(room.id, "lua", "player_" .. type, user_info.uid, body)
end

leave_current_room = function()
    if room.id then
        Log("RoomModule: Leaving room " .. room.id)
        CallActor(room.id,"player_leave", user_info.uid)
    end
    if room.tx_to_players_chan then
        room.tx_to_players_chan:unsubscribe()
        room.tx_to_players_chan = nil
    end
    room.id = nil
    room.type = nil
    room.mapid = nil
    -- Log("RoomModule: Left room. State cleared.")
end

change_room_to = function(new_room_id)
    leave_current_room()

    Log("RoomModule: Attempting to enter room " .. new_room_id)

    local connection_info = skynet.call(new_room_id, "lua", "player_enter", user_info.uid, sprite_info)
    -- Log("RoomModule: Successfully entered room. 连接至下发的房间频道")
    local new_channel = mc.new {
        channel = connection_info.room_tx_channel_id,
        dispatch = rx_from_room,
    }
    new_channel:subscribe()

    room.id = new_room_id
    assert(connection_info.room_info.type)
    room.type = connection_info.room_info.type
    room.tx_to_players_chan = new_channel
    room.mapid = connection_info.room_info.mapid

    if room.type == ROOM_MODEL.ROOM_TYPE.LOBBY then
        current_lobby_map_id = room.mapid
    end

    -- Log("RoomModule: Entered room " .. room.id .. " of type '" .. room.type .. "'. Room channel subscribed!")

    SendToClient("room_update", connection_info.room_info)
    return true
end

function M.on_open()
    local lobby_id = query_lobby_room_id("Z战队营地")
    change_room_to(lobby_id)
end

M.CMD = {}
function M.CMD.go_to_room(room_id)
    -- Log("go_to_room "..room_id)
    change_room_to(room_id)
end
function M.on_close()
    leave_current_room()
end

return M

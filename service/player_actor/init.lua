---@diagnostic disable: lowercase-global
local skynet = require "skynet"
local s = require "service"
local mc = require "skynet.multicast"
local ROOM_MODEL = (require "lualib.models.room_model")
local cjson = require "cjson"
local cs = (require "skynet.queue")()

local f_send_msg_to_client , user_data  = ...
local user_info = {
    uid = tonumber(user_data.uid),
    nickname= user_data.nickname
}

local sprite_info = {
    nickname = user_data.nickname,
    --- 指明是哪款机甲
    theme = "default",
    max_HP = 56000
}

local current_room = nil

--- 玩家是在大厅休闲 还是在PVP 还是在副本（PVE）
--- local current_mode = "lobby" TODO : current_mode 这种和room相关的玩意不应该放到player逻辑里


local function send_msg_to_client(type, body)
    f_send_msg_to_client(type, body )
end

function rx_from_room(channel, source, msg)
    if msg.type == "frame_sync" then
        send_msg_to_client("frame_sync", msg.body)
    elseif msg.type == "room_destroyed" then
        Log("所在房间被销毁，返回大厅。")
        change_room_to(query_lobby_room_id("Z战队营地"))
        send_msg_to_client("msg", { message = "当前房间已关闭，您已被送回大厅。", sender = "system" })
    end
end

local function tx_to_room(type, body)
    if not current_room then
        return
    end
    skynet.send(current_room, "lua", "player_" .. type, user_info.uid, body)
end

local room_tx_to_players = nil
local function leave_current_room()
    if current_room then
        Log("leave_current_room：告知当前room我离开了")
        skynet.call(current_room, "lua", "player_leave", user_info.uid)
    end
    if room_tx_to_players then
        room_tx_to_players:unsubscribe()
        room_tx_to_players = nil
    end
    current_room = nil
end

function change_room_to(new_room)
    leave_current_room()
    Log("change_room_to：向目标room报告说我进来了 " .. new_room)
    local connection_info = skynet.call(new_room, "lua", "player_enter", user_info.uid, sprite_info)
    Log("change_room_to：连接至room下发的房间频道")
    room_tx_to_players = mc.new {
        channel = connection_info.room_tx_channel_id,
        dispatch = rx_from_room,
    }
    room_tx_to_players:subscribe()
    current_room = new_room
    send_msg_to_client("room_update", connection_info.room_state)
end


-- Client message handlers
function query_lobby_room_id(lobby_map_name)
    return skynet.call(skynet.queryservice("room_mgr"), "lua", "get_lobby_room",
        ROOM_MODEL.MAP_NAME.hall[lobby_map_name])
end

function update_position(position)
    tx_to_room("position_update", position)
end

function user_event(event)
    tx_to_room("event_add", {
        type = event.type,
        body = event.body
    })
end

local CMD = {}
CMD.handle_client_message = function(message)
    local body = message.body
    if message.type == "in_lobby_change_room" then
        cs(function (i)
            change_room_to(query_lobby_room_id(i))
        end, body.map_name)
    elseif message.type == "in_room_position_update" then
        cs(update_position, body)
    elseif message.type == "in_room_event" then
        cs(user_event, body)
    end
end

CMD.client_disconnected = function()
    Log("与客户端断联")
    leave_current_room()
end

CMD.exit = function()
    skynet.exit()
end

local hello = function()
    Log("玩家模型初始化完毕，接下来加入大厅。")
    -- 默认加入大厅 
    change_room_to(query_lobby_room_id("Z战队营地"))
    return true
end

s.open = function()
    s.CMD = CMD
    -- 在此处加载角色数据
    -- skynet.sleep(200)
    skynet.fork(hello)
end

s.close = function()
    leave_current_room()
    -- 在此处保存角色数据
    -- skynet.sleep(200)
end

s.start("[player " .. user_info.uid .. " ] ", ...)

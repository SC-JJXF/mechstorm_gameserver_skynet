local queue = require "skynet.queue"
local skynet = require "skynet"
local mc = require "skynet.multicast"
local ROOM_MODEL = (require "room_model")
local cjson = require "cjson"

local ws_info = {
    agent_ip = nil,
    socket_id = nil
}
local current_room = nil

--- 玩家是在大厅休闲 还是在PVP 还是在副本（PVE）
local current_mode = "lobby"

local room_tx_to_players = nil

local player_info = {
    uid = nil,
    position = {
        x = 0,
        y = 0,
        --- 贴图 id
        texid = "",
        --- 贴图朝向
        texdir = 0
    }
}

local CMD = {}

function Log(...)
    skynet.error("[player " .. player_info.uid .. " ] " .. ...)
end

-- 初始化玩家Actor
function CMD.init(ws_agent_ip,ws_socket_id)
    ws_info.agent_ip = ws_agent_ip
    ws_info.socket_id = ws_socket_id
    player_info.uid = skynet.self()
    Log("玩家模型初始化完毕，接下来加入大厅。")
    -- 默认加入大厅 
    change_room_to(skynet.call(skynet.queryservice("room_mgr"),"lua", "get_lobby_room",ROOM_MODEL.MAP_NAME.hall["Z战队营地"]))
end

local cs = queue()  -- cs 是一个执行队列 (cs is a execute queue)
-- 处理客户端消息
function CMD.handle_client_message(message)
    local body = message.body
    -- 在大厅里面游览 大厅包含不同的地图
    if message.type == "in_lobby_change_room" then
        cs(in_lobby_change_room,body.map_name)
    elseif message.type == "position_update" then
        cs(update_position,body)
    elseif message.type == "in_room_event" then
        cs(user_event,body)
    end
end

function in_lobby_change_room(lobby_map_name)
    
end

--- 内部函数：切换房间
--- @param new_room number 新的房间ID
function change_room_to(new_room)
    leave_current_room()
    Log("change_room_to：向目标room报告说我进来了 "..new_room)
    local connection_info = skynet.call(new_room, "lua", "player_enter", player_info.uid, player_info.position)
    Log("change_room_to：连接至room下发的房间频道")
    room_tx_to_players = mc.new {
        channel = connection_info.room_tx_channel_id,   -- 绑定上一个频道
        dispatch = rx_from_room,  -- 设置这个频道的消息处理函数
    }
    room_tx_to_players:subscribe()
    current_room = new_room
    send_msg_to_client("room_update",connection_info.room_state)
end

-- 内部函数：更新位置
function update_position(position)
    -- Log("update_position：更新玩家位置为：" .. cjson.encode(position))
    player_info.position = position
    tx_to_room("position_update", player_info.position)
end


function user_event(event)
    tx_to_room("event_add", {
        type = event.type,
        body = event.body
    })
end

--- 下发消息到ws服务（ws服务再发送消息到客户端）
--- @param type string 消息类型
--- @param body table 消息内容
function send_msg_to_client(type, body)
    skynet.send( ws_info.agent_ip , "lua", "send", ws_info.socket_id, type, body)
end

-- 客户端断开连接
function CMD.client_disconnected()
    Log("与客户端断联")
    leave_current_room()
    skynet.exit()
end

--- 内部函数：从当前房间脱离
function leave_current_room()
    if current_room then
        Log("leave_current_room：告知当前room我离开了")
        skynet.call(current_room, "lua", "player_leave", player_info.uid)
    end
    if room_tx_to_players then
        room_tx_to_players:unsubscribe()
        room_tx_to_players = nil
    end
end

function rx_from_room(channel, source, msg)
    if msg.type == "frame_sync" then
        send_msg_to_client("frame_sync" ,msg.body)
    elseif msg.type == "room_destroyed" then
        Log("所在房间被销毁，返回大厅。")
        local lobby_room_id = skynet.call(skynet.queryservice("room_mgr"), "lua", "get_lobby_room", ROOM_MODEL.MAP_NAME.hall["Z战队营地"])
        change_room_to(lobby_room_id)
        send_msg_to_client("msg", { message = "当前房间已关闭，已将您送回大厅。",sender = "system" })
    end
end

---向房间推送自己的消息
---@param type string
---@param body table
function tx_to_room(type, body)
    skynet.send(current_room, "lua","player_"..type, player_info.uid , body)
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            skynet.error("Unknown command", cmd)
        end
    end)
end)

---@diagnostic disable: lowercase-global
local skynet = require "skynet"
local s = require "service"
local cjson = require "cjson"
cs = (require "skynet.queue")()
local RoomModule = require "service.player_actor.room"


local f_send_msg_to_client, user_data = ...

user_info                             = {
    uid = tonumber(user_data.uid),
    nickname = user_data.nickname
}

sprite_info                           = {
    nickname = user_data.nickname,
    --- theme指明是哪个机甲
    theme = "default",
    max_HP = 56000
}


function send_msg_to_client(type, body)
    f_send_msg_to_client(type, body)
end

local CMD = {}
CMD.handle_client_message = function(message)
    local msg_type = message.type
    local body = message.body

    if msg_type == "in_room" then
        cs(RoomModule.handle_client_message, body.type, body.body)
    elseif msg_type == "in_room" then

    else
        Log("收到预期外的客户端消息 msg_type: " .. msg_type)
    end
end

CMD.client_disconnected = function()
    -- 玩家下线/掉线，通知自己的 service 层销毁本服务
    skynet.send(skynet.self(),"lua", "close")
end


local hello = function()
    Log("玩家模型初始化完毕，接下来加入大厅。")

    local lobby_id = RoomModule.query_lobby_room_id("Z战队营地")
    RoomModule.change_room_to(lobby_id)
end

s.open = function()
    s.CMD = CMD

    skynet.call(skynet.queryservice("player_locator"), "lua", "register", user_info.uid, s.self())
    skynet.fork(hello)
    -- 在此处加载角色数据 (占位符)
    -- skynet.sleep(200)
end

s.close = function()
    RoomModule.leave_current_room()
    skynet.call(skynet.queryservice("player_locator"), "lua", "unregister", user_info.uid, s.self())

    -- 在此处保存角色数据 (占位符)
    -- skynet.sleep(200)
end

s.start("[player " .. user_info.uid .. " ] ", ...)

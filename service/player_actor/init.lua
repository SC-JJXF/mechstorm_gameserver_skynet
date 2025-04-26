---@diagnostic disable: lowercase-global
local skynet = require "skynet"
local s = require "service"
local cjson = require "cjson"
local cs = (require "skynet.queue")()
local RoomModule = require "service.player_actor.room"


local f_send_msg_to_client, user_data = ...

user_info                             = {
    uid = tonumber(user_data.uid),
    nickname = user_data.nickname
}

sprite_info                           = {
    nickname = user_data.nickname,
    --- 机甲主题类型
    theme = "default",
    max_HP = 56000
}


-- 保留包装函数，因为它需要传递给其他模块使用
function send_msg_to_client(type, body)
    f_send_msg_to_client(type, body)
end

local CMD = {}
CMD.handle_client_message = function(message)
    local msg_type = message.type
    local body = message.body

    if msg_type == "in_lobby_change_room" then
        if RoomModule.get_type() == "lobby" then
            cs(function(map_name)
                -- 使用模块的查询功能
                local target_lobby_id = RoomModule.query_lobby_room_id(map_name)
                if target_lobby_id then
                    RoomModule.change_room_to(target_lobby_id)
                else
                    Log("无法找到大厅房间: " .. map_name)
                    send_msg_to_client("msg", { message = "目标地图不存在: " .. map_name, sender = "system" })
                end
            end, body.map_name)
        else
            Log("收到'in_lobby_change_room'消息但当前不在大厅中。当前房间类型: " .. (RoomModule.get_type() or "无"))
            send_msg_to_client("msg", { message = "请先离开当前游戏房间。", sender = "system" }) -- 发送反馈给客户端
        end
    elseif string.sub(msg_type, 1, 8) == "in_room_" then
        local room_event_type = string.sub(msg_type, 9)
        if room_event_type and #room_event_type > 0 then
            cs(RoomModule.tx_to_room, room_event_type, body)
        else
            Log("收到无效的in_room_消息类型(空后缀): " .. msg_type)
        end
    else
        Log("收到预期外的客户端消息 msg_type: " .. msg_type)
    end
end

CMD.client_disconnected = function()
    RoomModule.leave_current_room()
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

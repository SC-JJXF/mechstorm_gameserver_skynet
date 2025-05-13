---@diagnostic disable: lowercase-global
local skynet = require "skynet"
local s = require "service"
local cjson = require "cjson"
cs = (require "skynet.queue")()


local gateway_connection_info, user_data

---下发消息到客户端
---@param type string 消息类型
---@param body string|table 主体
function SendToClient(type, body)
    SendToActor(gateway_connection_info.gatewayIP, "send", gateway_connection_info.fd, { type = type, body = body })
end


-- pa , player_actor 缩写
local pa_modules = {
    roomctl = require "roomctl",
    matchctl = require "matchctl"
}

-- 高阶函数：用于调用所有模块中的特定方法
local function call_module_func(func_name, ...)
    local result = nil
    for _, m in pairs(pa_modules) do
        if m[func_name] then
            result = m[func_name](...)
            -- if result == true then  -- 如果函数返回true，则中断循环
            --     return true
            -- end
        end
    end
end

s.CMD.handle_client_message = function(message)
    local msg_type = message.type
    local body = message.body

    if pa_modules[msg_type] then
        cs(pa_modules[msg_type]["handle_client_message"], body.type, body.body)
    else
        Log("收到预期外的客户端消息 msg_type: " .. msg_type)
    end
end

s.CMD.client_disconnected = function()
    -- 玩家下线/掉线，通知自己的 service 层销毁本服务
    skynet.send(skynet.self(), "lua", "close")
end

--- 注册模块们提供的消息处理函数
--- 感谢 huahua132 的文章！
for _, m in pairs(pa_modules) do
    local register_cmd = m.CMD
    for cmdname,func in pairs(register_cmd or {}) do
		assert(not s.CMD[cmdname], "exists cmdname: " .. cmdname)
		s.CMD[cmdname] = func
	end
end

local hello = function()
    call_module_func("on_open")
end

s.open = function(...)
    Log("启动")

    gateway_connection_info, user_data = ...
    user_info                          = {
        uid = tonumber(user_data.uid),
        nickname = user_data.nickname
    }
    sprite_info                        = {
        nickname = user_data.nickname,
        --- theme指明是哪个机甲
        theme = "default",
        max_HP = 56000
    }
    s.name                             = "player " .. user_info.uid
    CallUniService("player_actor_locator", "register", user_info.uid, s.ip)
    skynet.fork(hello)
    -- 在此处加载角色数据 (占位符)
    -- skynet.sleep(200)
end

s.close = function()
    call_module_func("on_close")
    CallUniService("player_actor_locator", "unregister", user_info.uid, s.ip)
    -- 在此处保存角色数据 (占位符)
    -- skynet.sleep(200)
end

s.start("player")

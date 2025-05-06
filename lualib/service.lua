local skynet = require "skynet"
-- https://blog.csdn.net/yangyu20121224/article/details/130163107
local M = {
    --本服务的阅读用名称，输出日志的时候会用到
    name = "",
    --skynet框架层面的[服务地址](https://github.com/cloudwu/skynet/wiki/LuaAPI#%E6%9C%8D%E5%8A%A1%E5%9C%B0%E5%9D%80)
    ip = 0,
    ---close回调函数应由上层填充。   
    ---本服务销毁时，service.lua会先调用这个回调函数让上层回收它生成的副作用
    close = nil,
    ---open回调函数应由上层填充。
    ---本服务启动时，service.lua会先调用这个回调函数让上层生成它的副作用
    open = nil,
    --本服务开放给外界调用的方法（RPC）
    CMD = {},
}

local S = {
    CMD = {},
    isopen = false
}

function S.CMD.open(...)
    if S.isopen then
        Log("open已经被调用了。")
        return
    end
    M.open(...)
    S.isopen = true
    Log("open调用成功，启动流结束。")
end

function S.CMD.close()
    Log("自销毁...")
    if M.close then
        M.close()
    end
    skynet.exit()
end

local dispatch = function(session, address, cmd, ...)
    -- Log(cmd)
    local f = S.CMD[cmd]
    if f then
        skynet.ret(skynet.pack(f(...)))
        return
    end

    if not S.isopen then
        Log("请将该错误反馈给开发者：在启动流未结束前不允许调用上层逻辑")
        return
    end

    local f = M.CMD[cmd]
    if not f then
        Log("调用 s.CMD." .. cmd.." 失败，未定义该指令的处理函数。" )
    else
        skynet.ret(skynet.pack(f(...)))
    end
end

-- 由上层调用
function M.start(name)
    M.name = name
    skynet.start(function ()
        M.ip = skynet.self()
        skynet.dispatch("lua", dispatch)
    end)
    if M.open then
        -- 启动参数其实是以字符串拼接的方式传递过去的。所以不要在参数中传递复杂的 Lua 对象。接收到的参数都是字符串，且字符串中不可以有空格（否则会被分割成多个参数）。
        -- 这种参数传递方式是历史遗留下来的，有很多潜在的问题。目前推荐的惯例是，让你的服务响应一个启动消息。
        -- 在 newservice 之后，立刻调用 skynet.call 发送启动请求。
        -- Log("初始化完毕。请携带启动参数调用 open 完成启动流程。")
    else
        S.isopen = true
        Log("初始化完毕。启动流结束。")
    end
end


function Log(err)
    skynet.error("[" .. M.name .. "] " .. tostring(err))
end
function CallUniService(servicename,...)
    return skynet.call(skynet.queryservice(servicename),"lua",...)
end
function CallActor(actorip,...)
    return skynet.call(actorip,"lua",...)
end
function SendToActor(actorip,...)
    return skynet.send(actorip,"lua",...)
end
function Traceback(err)
    Log(err)
    skynet.error(debug.traceback())
end

-- debug用
function PrintTable(tbl, indent)
    indent = indent or ""
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            Log(indent .. k .. " = {")
            PrintTable(v, indent .. "  ")
            Log(indent .. "}")
        else
            Log(indent .. k .. " = " .. tostring(v))
        end
    end
end

return M

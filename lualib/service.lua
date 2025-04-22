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
}


function S.CMD.close()
    Log("自销毁...")
    if M.close then
        M.close()
    end
    skynet.exit()
end

local dispatch = function(session, address, cmd, ...)
    local f = S.CMD[cmd]
    if f then
        skynet.ret(skynet.pack(f(...)))
        return
    end

    local f = M.CMD[cmd]
    if not f then
        Log("调用 s.resp." .. cmd.." 失败，未定义该指令的处理函数。" )
        skynet.ret()
    else
        skynet.ret(skynet.pack(f(...)))
    end
end

local function init() --相较球球大作战项目加了个local（我觉得不应该暴露给业务层）
    if M.open then
        M.open()
    end
    skynet.dispatch("lua", dispatch)
end

-- 由上层调用
function M.start(name, ...)
    M.name = name
    M.ip = skynet.self()
    skynet.start(init)
    Log("初始化完毕。")
end


function Log(err)
    skynet.error("[ " .. M.name .. " ] " .. tostring(err))
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

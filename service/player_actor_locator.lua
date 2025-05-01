---用于快速根据UID定位到一个actor
---@diagnostic disable: lowercase-global
local skynet = require "skynet"
local s = require "service"

-- 存储映射: uid -> player_actor_address
local players = {}

local CMD = {}

function CMD.register(uid, player_addr)
    uid = tonumber(uid)
    if not uid or not player_addr then
        Log("尝试使用无效的UID或地址进行注册。UID: " .. tostring(uid))
        return false
    end

    local existing_addr = players[uid]
    if existing_addr then
        Log("此 UID " .. uid .. "已在服务器上存在对应actor：" .. skynet.address(existing_addr) ..
                  ". 新注册尝试来自actor: " .. skynet.address(player_addr))
        return false
    end
    -- Log("注册 UID " .. uid .. " -> " .. skynet.address(player_addr))
    players[uid] = player_addr
    -- address_to_uid[player_addr] = uid -- Uncomment if reverse lookup is needed
    return true
end

function CMD.unregister(uid, player_addr)
    uid = tonumber(uid)
    if not uid then
        Log("尝试使用无效的UID类型注销。")
        return false
    end

    local registered_addr = players[uid]

    if not registered_addr then
        Log("请求注销 UID " .. uid .. "，但未找到注册信息。")
        return false -- 未找到
    end

    -- 可选验证：确保提供的地址匹配
    if player_addr and registered_addr ~= player_addr then
        Log("UID " .. uid .. " 的注销不匹配。已注册： " .. skynet.address(registered_addr) ..
                  ", 请求注销： " .. skynet.address(player_addr))
        return false -- 地址不匹配
    end

    Log("正在注销 UID " .. uid .. " (地址： " .. skynet.address(registered_addr) .. ")")
    players[uid] = nil
    -- if address_to_uid[registered_addr] then address_to_uid[registered_addr] = nil end -- Clean reverse map

    return true
end


function CMD.query(uid)
    uid = tonumber(uid)
    local addr = players[uid]
    Log("查询 UID " .. uid .. " -> " .. (addr and skynet.address(addr) or "未找到"))
    return addr
end


s.open = function()
    s.CMD = CMD
end

s.close = function()
end

s.start "player_actor_locator"

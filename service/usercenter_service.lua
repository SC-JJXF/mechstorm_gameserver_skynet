local skynet = require "skynet"
local httpc = require "httpc"
local cjson = require "cjson"

local CMD = {}

--- 验证token并获取用户信息
---@param token string 用户token
---@return boolean ok 是否成功
---@return table|string result 成功返回用户信息，失败返回错误信息
function CMD.verify_token(token)
    ---@type string | nil
    local usercenter_url = skynet.getenv "usercenter_url"
    if not usercenter_url then
        skynet.error("usercenter_url not configured!")
        return false, "用户中心未配置"
    end

    local auth_url = usercenter_url .. "/api/auth/current"
    local headers = {
        Authorization = "Bearer " .. token
    }

    -- 创建HTTP客户端并发起请求
    local client = httpc.create()
    local ok, status, body = pcall(client.request, client, {
        url = auth_url,
        method = "GET",
        headers = headers
    })
    if not ok then
        skynet.error("HTTP request failed:", status)
        return false, "用户中心请求失败"
    end

    if status ~= 200 then
        skynet.error("Usercenter auth failed:", status, body)
        return false, "认证失败"
    end

    local decode_ok, decoded_data = pcall(cjson.decode, body)
    if not decode_ok then
        skynet.error("Failed to decode user info:", body)
        return false, "用户信息解析失败"
    end

    return true, decoded_data
end

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            skynet.error("Unknown command:", cmd)
        end
    end)
end)

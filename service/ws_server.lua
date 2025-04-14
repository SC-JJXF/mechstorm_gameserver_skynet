local skynet = require "skynet"
local socket = require "skynet.socket"
local websocket = require "http.websocket"
local cjson = require "cjson"
cjson.encode_sparse_array(true)

local httpc = require "skynet.http" -- 引入 httpc

local MODE = ...

if MODE == "agent" then
    ---@class ConnStateWaitingAuth
    ---@field state "waiting_auth"
    ---@field timer integer skynet timer id
    ---@alias ConnState integer | ConnStateWaitingAuth actor_address or waiting state
    ---@type table<integer, ConnState>
    local connection_to_actor = {}
    ---@class WsHandler
    local ws_handler = {}

    ---@type integer 认证超时时间，单位 1/100 秒 (5秒)
    local AUTH_TIMEOUT = 500

    --- 发送错误消息并关闭连接
    ---@param id integer WebSocket 连接 ID
    ---@param message string 错误消息内容
    local function send_error_and_close(id, message)
        local err_msg = {
            type = "pop-up-message",
            body = {
                status = "error",
                message = message
            }
        }
        pcall(websocket.write, id, cjson.encode(err_msg)) -- 使用 pcall 以防写入时连接已关闭
        pcall(websocket.close, id)
        connection_to_actor[id] = nil -- 清理状态
    end

    --- 处理认证超时
    ---@param id integer WebSocket 连接 ID
    local function handle_auth_timeout(id)
        ---@type ConnState | nil
        local conn_state = connection_to_actor[id]
        -- 检查是否仍然处于等待认证状态，防止重复处理
        if type(conn_state) == "table" and conn_state.state == "waiting_auth" then
            skynet.error("Auth timeout for connection", id)
            send_error_and_close(id, "认证超时，请重新连接")
        end
    end

    --- WebSocket 连接建立回调 (handshake 前)
    ---@param id integer WebSocket 连接 ID
    function ws_handler.connect(id)
        skynet.error("agent：新客户端连接！socket_id：" .. id)
    end

    --- 创建玩家 Actor
    ---@param fd integer WebSocket 连接 ID
    ---@param user_info table 从用户中心获取的用户信息
    ---@return integer player_actor 的 skynet 服务地址
    local function create_player_actor(fd, user_info)
        ---@type integer
        local actor = skynet.newservice("player_actor")
        -- 确保 user_info 被正确传递
        skynet.call(actor, "lua", "init", skynet.self(), fd, user_info)
        connection_to_actor[fd] = actor
        return actor
    end

    --- WebSocket 握手回调
    ---@param id integer WebSocket 连接 ID
    ---@param header table HTTP 请求头
    ---@param url string 请求的 URL
    ---@return boolean 是否允许握手
    function ws_handler.handshake(id, header, url)
        ---@type string
        local addr = websocket.addrinfo(id)
        skynet.error("ws 握手 from: " .. tostring(id), "url", url, "addr:", addr)

        if url == "/v1/connect_to_my_actor" then
            -- 不立即创建 actor，而是等待客户端发送 token
            ---@type integer
            local timer_id = skynet.timeout(AUTH_TIMEOUT, function()
                handle_auth_timeout(id)
            end)
            connection_to_actor[id] = { state = "waiting_auth", timer = timer_id }
            skynet.error("Connection", id, "waiting for authentication token.")
            return true -- 握手成功，等待后续认证消息
        end

        skynet.error("Invalid URL，目前只接受 /v1/connect_to_my_actor")
        send_error_and_close(id,"Invalid URL，目前只接受 /v1/connect_to_my_actor")
        return false
    end

    --- WebSocket 收到消息回调
    ---@param id integer WebSocket 连接 ID
    ---@param msg string 收到的消息内容 (通常是 JSON 字符串)
    function ws_handler.message(id, msg)
        ---@type ConnState | nil
        local conn_state = connection_to_actor[id]

        if type(conn_state) == "table" and conn_state.state == "waiting_auth" then
            -- 处理认证消息
            skynet.timeout(conn_state.timer, nil) -- 取消超时定时器

            local ok, data = pcall(cjson.decode, msg)
            
            if not ok or type(data) ~= "table" or type(data.token) ~= "string" then
                skynet.error("Invalid auth message format from client", id, msg)
                send_error_and_close(id, "无效的认证消息格式")
                return
            end

            ---@type string
            local token = data.token
            local ok, result = skynet.call(skynet.uniqueservice("usercenter_service"), "lua", "verify_token", token)
            
            if ok then
                ---@type table
                local user_info = result
                skynet.error("Authentication successful for connection", id)
                -- 认证成功，创建 player_actor
                create_player_actor(id, user_info)
                -- 发送认证成功消息给客户端（可选）
                ---@type table
                local success_msg = { type = "auth_success" }
                pcall(websocket.write, id, cjson.encode(success_msg))
            else
                skynet.error("Authentication failed for connection", id, "Error:", result)
                send_error_and_close(id, result)
            end
            ---@cast conn_state integer
        elseif type(conn_state) == "number" then -- 已经认证，conn_state 是 actor 地址
            -- 转发消息给 player_actor

            local ok, data = pcall(cjson.decode, msg)

            if not ok then
                skynet.error("Invalid JSON message from client", id, msg)
                -- 可以选择是否关闭连接或仅忽略消息
                return
            end
            skynet.send(conn_state, "lua", "handle_client_message", data)
        else
            -- 既不是等待认证，也不是已分配 actor 的状态，可能连接已关闭或状态异常
            skynet.error("Received message for unknown or closed connection state", id)
            pcall(websocket.close, id) -- 尝试关闭以防万一
        end
    end

    --- WebSocket收到 ping 回调
    ---@param id integer WebSocket 连接 ID
    function ws_handler.ping(id)
        -- 回应客户端的ping
        websocket.pong(id)
    end

    --- WebSocket收到 pong 回调
    ---@param id integer WebSocket 连接 ID
    function ws_handler.pong(id)
        -- 可以在这里记录最后一次收到pong的时间，用于连接保活检测
    end

    --- WebSocket 连接关闭回调
    ---@param id integer WebSocket 连接 ID
    ---@param code? integer 关闭状态码
    ---@param reason? string 关闭原因
    function ws_handler.close(id, code, reason)
        ---@type ConnState | nil
        local conn_state = connection_to_actor[id]
        if type(conn_state) == "table" and conn_state.state == "waiting_auth" then
            -- 如果正在等待认证，取消超时定时器
            skynet.timeout(conn_state.timer, nil)
            skynet.error("ws close while waiting auth:", id, code, reason)
        elseif type(conn_state) == "number" then
            -- 如果已经连接到 actor，通知 actor
            ---@cast conn_state integer
            skynet.send(conn_state, "lua", "client_disconnected")
            skynet.error("ws close from:", id, code, reason)
        else
             skynet.error("ws close for unknown state:", id, code, reason)
        end
        connection_to_actor[id] = nil -- 清理状态
    end

    --- WebSocket 发生错误回调
    ---@param id integer WebSocket 连接 ID
    ---@param err string 错误信息
    function ws_handler.error(id, err)
        skynet.error("ws error from:", id, err)
        -- error 事件通常意味着底层 socket 出错，连接已经不可用
        -- 调用 close 来进行状态清理
        ws_handler.close(id, 1011, "Internal server error") -- 使用一个错误码
    end

    ---@class AgentCommands
    local CMD = {}

    --- 来自 player_actor 的消息会被下发到对应的客户端 (由 player_actor 调用)
    --- @param ws_id number WebSocket连接ID
    --- @param msg_type string 消息类型
    --- @param msg_body string|table 消息内容
    function CMD.send(ws_id, msg_type, msg_body)
        local message = {
            type = msg_type,
            body = msg_body -- cjson 会正确处理 table 或 string
        }
        local ok, json_str = pcall(cjson.encode, message)
        if not ok then
            -- 记录更详细的错误信息
            skynet.error("Failed to encode message to JSON. Type:", msg_type, "Error:", json_str)
            return
        end
        -- 使用 pcall 包装 websocket.write 以处理可能的写入错误
        websocket.write(ws_id, json_str)
    end

    --- 处理被分配的来自客户端的WebSocket连接 (由主服务调用)
    ---@param id integer WebSocket 连接 ID
    ---@param protocol string 协议 ("ws" or "wss")
    ---@param addr string 客户端地址
    function CMD.handle_wssocket(id, protocol, addr)
        
        local ok, err = websocket.accept(id, ws_handler, protocol, addr)
        if not ok then
            skynet.error(err)
        end
    end

    skynet.start(function()
        skynet.dispatch("lua", function(session, source, cmd, ...)
            ---@type function | nil
            local f = CMD[cmd]
            if f then
                skynet.ret(skynet.pack(f(...)))
            else
                skynet.error("Unknown command", cmd)
            end
        end)
    end)
else -- 主服务逻辑 (MODE ~= "agent")
    ---@type table<integer, integer> agent 服务地址列表
    local agents = {}
    ---@type integer 用于负载均衡的索引
    local balance = 1

    skynet.start(function()
        -- 创建多个ws服务做负载均衡
        skynet.error("Starting WebSocket main service...")

        for i = 1, 3 do
            ---@type integer
            agents[i] = skynet.newservice(SERVICE_NAME, "agent")
            skynet.error("Started agent service:", agents[i])
        end


        -- 启动WebSocket监听
        ---@type integer
        local port = assert(tonumber(skynet.getenv("websocket_port")), "websocket_port not configured or not a number")
        ---@type string
        local protocol = "ws" -- or "wss" if needed
        ---@type integer listener socket id
        local id = socket.listen("0.0.0.0", port)
        skynet.error(string.format("websocket入口 服务开放在端口 %d ，协议：%s", port, protocol))

        socket.start(id, function(client_id, client_addr)
            -- 将新连接分配给agent
            ---@type integer agent 服务地址
            local target_agent = agents[balance]
            skynet.send(target_agent, "lua","handle_wssocket", client_id, protocol, client_addr)
            skynet.error(string.format("接受连接：socket_id: %d ，来自%s，该连接负载均衡到 agent %d (%d) 负责。", client_id, client_addr, balance, target_agent))
            balance = balance + 1
            if balance > #agents then
                balance = 1
            end
        end)
    end)
end

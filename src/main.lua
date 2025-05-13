local skynet = require "skynet"
skynet.manager = require "skynet.manager"

skynet.start(function()
    -- debug 用
    skynet.uniqueservice("debug_console", 8000)

    -- 启动房间管理服务
    skynet.uniqueservice("room_mgr")
    -- skynet.manager.name(".room_mgr", room_mgr)

    -- 启动用户中心服务
    skynet.uniqueservice("usercenter")
    -- skynet.manager.name(".usercenter", usercenter)

    -- 启动WebSocket服务
    skynet.uniqueservice("ws_server")
    -- skynet.manager.name(".ws_server", ws_server)
    skynet.uniqueservice("player_actor_locator")
    skynet.uniqueservice("match")
    skynet.error("start ok")
    skynet.exit()
end)

---@diagnostic disable: lowercase-global
-- 复制粘贴自 【从零开始学Skynet】实战篇《球球大作战》
--必须配置
thread = 8                          --启用多少个工作线程
cpath = "./skynet/cservice/?.so"    --用C编写的服务模块的位置
bootstrap = "snlua bootstrap"       --启动的第一个服务

--bootstrap配置项
start = "main"                      --主程序入口
harbor = 0                          --不使用主从节点模式

--lua配置项
lualoader = "./skynet/lualib/loader.lua"
luaservice = "./service/?.lua;" .."./service/?/init.lua;".. "./skynet/service/?.lua;"
lua_path = "./etc/?.lua;" .. "./lualib/?.lua;" ..  "./skynet/lualib/?.lua;" .. "./skynet/lualib/?/init.lua" .. "./service/?.lua;" .."./service/?/init.lua;"
lua_cpath = "./luaclib/?.so;" .. "./skynet/luaclib/?.so"
-- lualib-3rd
lua_path = lua_path .. ";./lualib-3rd/share/lua/5.4/?.lua"
lua_cpath = lua_cpath .. ";./lualib-3rd/lib/lua/5.4/?.so"

--后台模式
--daemon = "./skynet.pid"
--logger = "./userlog"

-- 本项目相关设置
websocket_port = 8888
usercenter_url = "http://localhost:5150"

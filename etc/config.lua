root = "./"
luaservice = root .. "service/?.lua;" .. root .. "test/?.lua;" .. root .. "test/?/init.lua"
lualoader = root .. "lualib/loader.lua"
lua_path =  root .. "lualib/?.lua;" .. root .. "lualib/?/init.lua".. ";./game/service/models/?.lua"
lua_cpath = root .. "luaclib/?.so"

thread = 8
harbor = 0

websocket_port = 8888

usercenter_url = "0.0.0.0:5150"

max_client = 1024
bootstrap = "snlua bootstrap"
start = "main" -- 从main.lua启动
luaservice = luaservice .. ";./game/service/?.lua"
cpath = root .. "cservice/?.so"
daemon = nil

-- profile = true -- 性能分析

local skynet = require "skynet"
local s = require "service"

local CMD = {}


s.close = function()
end

s.CMD = CMD
s.start "match_server"

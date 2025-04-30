local skynet = require "skynet"
local s = require "service"

local CMD = {}


s.open = function()
    s.CMD = CMD
end

s.close = function()
end

s.start "match_server"

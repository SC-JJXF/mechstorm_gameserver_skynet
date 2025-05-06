local s = require "service"
local room_model = require "models.room"

local M = {}

---@type "none" | "pending" | "waiting_opponent"
local match_info = "none"

function M.handle_client_message(type, body)
    if type == "i_want_match" then
        CallUniService("match", s.ip, room_model.PVP_TYPE[body.PVP_TYPE])
        match_info = "pending"
    elseif type ==  "cancel_match" then
    
    elseif type == "i_want_p1v1_with" then
        CallUniService("match", s.ip, body.opponent_uid)
        match_info = "waiting_opponent"
    elseif  type == "cancel_match"  then
    end
end

function M.CMD.match_succ(roomid)
    match_info = "none"
end

function M.CMD.on_challenge_request()
    
end
function M.CMD.()
    
end

return M

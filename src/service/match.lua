--不考虑各种优化匹配的机制（例如隐藏分），只实现简陋的匹配

local skynet = require "skynet"
local s = require "service"
local room_model = require "models.room"

---玩家使用该命令参与随机匹配
s.CMD.i_want_match = function (sender,PVP_TYPE)
    
end

---玩家使用该命令取消匹配
s.CMD.cancel_match = function (sender)

end

---玩家使用该命令挑战指定玩家
s.CMD.i_want_p1v1_with = function (sender,opponent_uid)
    local opponent_ip = CallUniService("player_actor_locator","query",opponent_uid)
    if not opponent_ip then
        return false,"对方不在线"
    end
    --向对方发送挑战请求
    local ok,err = CallActor(opponent_ip,"on_challenge_request",sender)
    if not ok then
        return false,err
    end
    return true
end

s.close = function()
end


s.start "match_service"

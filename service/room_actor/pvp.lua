local bump = require "bump"

local M = {}

function M.on_open()
    bump.newWorld()
end

function M.on_close()
end

function M.on_player_enter(uid, player_sprite_info)
end

function M.on_player_leave(uid)
end

-- 处理玩家事件
-- @param uid 玩家ID
-- @param event 事件信息
-- @return boolean 如果事件被处理返回 true，否则返回 false
function M.handle_player_event(uid, event)
    -- 在这里处理玩家事件
    -- 例如：攻击、技能、移动等

    -- 根据事件类型处理不同的逻辑
    if event.type == "attack" then
        -- 处理攻击事件
        return true
    elseif event.type == "skill" then
        -- 处理技能事件
        return true
    end
    
    -- 返回 false 代表继续传播这个事件
    return false
end

return M

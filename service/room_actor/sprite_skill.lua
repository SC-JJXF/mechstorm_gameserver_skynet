--- 玩家的普攻也归 sprite_skill 处理
local M = {}
local bump = require "bump-3dpd"
local players = Room_state.players
local world = Room_state.world


function M.on_open()
end

function M.on_close()
end

function M.on_player_enter(uid, player_sprite_info)
    world:add(players[uid])
end

function M.on_player_leave(uid)
    world:remove(players[uid])
end

function M.on_player_position_update(uid, position)
    world:update(players[uid], position.x, position.y, position.z)
end

function M.handle_player_event(uid, event)

    if event.type == "attack" then
        
    elseif event.type == "skill" then
        
    end
    
    -- 返回 false 代表继续传播这个事件
    return false
end


return M
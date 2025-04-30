
最精简子模块：

```lua
local M = {}

function M.on_open()
end

function M.on_close()
end

function M.on_player_enter(uid, player_sprite_info)
end

function M.on_player_leave(uid)
end

function M.handle_player_event(uid, event)

    if event.type == "attack" then
        return false
    elseif event.type == "skill" then
        return true
    end
    
    -- 返回 false 代表继续传播这个事件
    return false
end


return M
```

解释说明：
```lua
-- Room_state 是全局变量，可以直接访问

local M = {}

-- 当房间服务启动时调用
function M.on_open()
    -- 在这里初始化 PVP 房间
    -- 例如：设置初始状态、加载地图数据等
end

-- 当玩家加入房间时调用
-- @param uid 玩家ID
-- @param player_sprite_info 玩家角色信息
function M.on_player_enter(uid, player_sprite_info)
    -- 在这里处理玩家加入房间的逻辑
    -- 例如：初始化玩家状态、广播玩家加入消息等
end

-- 当玩家离开房间时调用
-- @param uid 玩家ID
function M.on_player_leave(uid)
    -- 在这里处理玩家离开房间的逻辑
    -- 例如：清理玩家状态、广播玩家离开消息等
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

-- 当房间服务关闭时调用
function M.on_close()
    -- 在这里处理房间关闭的逻辑
    -- 例如：保存游戏结果、清理资源等
end

return M

```
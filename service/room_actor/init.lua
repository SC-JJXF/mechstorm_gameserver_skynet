local skynet = require "skynet"
local mc = require "skynet.multicast"
local s = require "service"
local bump = require "bump-3dpd"


local sprite_model = (require "models.sprite_model")
local room_model = (require "models.room_model")

local room_type, room_mapid

local player_count = 0
local players = {}


---@class FrameEvent
---@field uid integer 玩家uid
---@field type string 事件类型
---@field body string 事件内容
---@type FrameEvent[]
local frame_events = {}


-- Shared state accessible by the roomfunc_modules
Room_state = {
    players = players,
    room_type = room_type,
    mapid = room_mapid,
    world = bump.newWorld()
}

local room_tx_to_players = nil
local roomfunc_modules = {} -- 在 s.open 处加载

-- 高阶函数：用于调用所有模块中的特定方法
local function call_module_func(func_name, ...)
    local result = nil
    for _, m in ipairs(roomfunc_modules) do
        if m[func_name] then
            result = m[func_name](...)
            if result == true then  -- 如果函数返回true，则中断循环（用于handle_player_event）
                return true
            end
        end
    end
    return false
end

local CMD = {}

local function player(player_sprite_info)
    return {
        nickname = player_sprite_info.nickname,
        theme = player_sprite_info.theme,
        HP = player_sprite_info.max_HP,
        sprite = {
            position = {
                x = 0,
                y = 0,
                z = 0,
                --- 是否朝向地图左边，不是左就是右
                is_facing_left = false
            },
            --- 角色受到的击飞晕眩之类的效果
            debuff = sprite_model.debuff_type.none,
            debuff_starttime = 0 --前端计算动画用
        }
    }
end

-- 获取房间状态
local function get_room_info()
    return {
        type = room_type,
        mapid = room_mapid,
        room_current_time = skynet.now(),
    }
end

--- 玩家加入房间 返回帮助玩家连接到房间频道的 connection_info
function CMD.player_enter(uid, player_sprite_info)

    players[uid] = player(player_sprite_info)
    player_count = player_count + 1
    Log("玩家加入房间，当前玩家数量：" .. player_count)
    call_module_func("on_player_enter", uid, player_sprite_info)

    return {
        ---@diagnostic disable-next-line: need-check-nil, undefined-field
        room_tx_channel_id = room_tx_to_players.channel,
        room_info = get_room_info()
    }
end

-- 玩家离开房间
function CMD.player_leave(uid)


    player_count = player_count - 1
    players[uid] = nil
    call_module_func("on_player_leave", uid)

    Log("玩家离开房间，当前玩家数量：" .. player_count)

    -- Check if room should be destroyed when empty (optional, depends on game logic)
    -- if player_count == 0 then
    --     Log("房间为空，准备销毁...")
    --     skynet.send(s.self(), "lua", "close") -- Example: trigger self-destruction
    -- end
end

--- 玩家：位置更新
--- @param uid integer 玩家uid
--- @param position table 玩家位置信息
function CMD.player_position_update(uid, position)
    call_module_func("on_player_position_update", uid, position)
    -- Log("玩家位置更新：" .. uid .. " -> " .. cjson.encode(position))
    players[uid]["sprite"]["position"] = position
end

--- 玩家：事件添加
--- @param uid integer 玩家uid
--- @param event table 玩家事件信息
function CMD.player_event_add(uid, event)
    local event_handled = call_module_func("handle_player_event", uid, event)
    table.insert(frame_events, { uid = uid, type = event.type, body = event.body })
end

-- 内部函数：广播消息给房间内其他玩家
local function frame_syncer()
    while true do
        skynet.sleep(2)       -- 50fps左右

        call_module_func("world_update")
        if player_count > 0 and room_tx_to_players then -- Check room_tx_to_players exists
            local frame_buffer = {
                in_room_players = Room_state.players,
                events = frame_events,
                timestamp = skynet.now(),
            }

            room_tx_to_players:publish({ type = "frame_sync", body = frame_buffer })

            frame_events = {} -- Clear events after sending
        end
        -- If player_count <= 0, the loop continues, waiting for players
    end
end

s.open = function(...)
    room_type, room_mapid = ...
    s.name = "room "..room_type
    room_tx_to_players = mc.new()

    if room_type == room_model.ROOM_TYPE.PVP then
        table.insert(roomfunc_modules,(require "room_actor.sprite_skill"))
    end

    call_module_func("on_open")
    skynet.fork(frame_syncer)
end

s.close = function()
    call_module_func("on_close")

    skynet.call(skynet.queryservice("room_mgr"), "lua", "room_destroyed", s.ip)

    -- 通知房间内所有玩家房间已销毁
    if player_count > 0 and room_tx_to_players then
        Log("广播房间销毁通知给玩家")
        room_tx_to_players:publish({ type = "room_destroyed", body = {} })
    end

    -- 4. 退出服务
    Log("房间服务退出")
    skynet.exit()
    -- 在此处保存角色数据
    -- skynet.sleep(200)
end

s.CMD = CMD
s.start "room"

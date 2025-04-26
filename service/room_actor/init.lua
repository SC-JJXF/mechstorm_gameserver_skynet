---@diagnostic disable: lowercase-global
local skynet = require "skynet"
local mc = require "skynet.multicast"
local s = require "service"
local sprite_model = (require "lualib.models.sprite_model")

local room_type, room_mapid = ...

local player_count = 0

local players = {}

local behavior_module = nil
-- Shared state accessible by the behavior module
local room_state = {
    players = players,
    frame_events = {}, -- Moved frame_events here to be part of shared state
    room_tx_to_players = nil, -- Will be assigned in s.open
    room_type = room_type,
    mapid = room_mapid,
}

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
    return {
        ---@diagnostic disable-next-line: need-check-nil, undefined-field
        room_tx_channel_id = room_state.room_tx_to_players.channel,
        room_info = get_room_info()
    }
end

-- 玩家离开房间
function CMD.player_leave(uid)
    -- Notify behavior module first, if it exists
    if behavior_module and behavior_module.on_player_leave then
        behavior_module.on_player_leave(uid, room_state)
    end

    player_count = player_count - 1
    players[uid] = nil
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
    -- Log("玩家位置更新：" .. uid .. " -> " .. cjson.encode(position))
    players[uid]["sprite"]["position"] = position
end

--- 玩家：事件添加
--- @param uid integer 玩家uid
--- @param event table 玩家事件信息
function CMD.player_event_add(uid, event)
    if behavior_module and behavior_module.handle_player_event then
        behavior_module.handle_player_event(uid, event, room_state)
    else
        -- Default behavior if no module handles it
        table.insert(room_state.frame_events, { uid = uid, type = event.type, body = event.body })
    end
end

-- 内部函数：广播消息给房间内其他玩家
function frame_syncer()
    while true do
        skynet.sleep(2)          -- 保持原来的同步间隔
        if player_count > 0 and room_state.room_tx_to_players then -- Check room_tx_to_players exists
            local frame_buffer = {
                in_room_players = room_state.players,
                events = room_state.frame_events,
                timestamp = skynet.now(),
            }

            -- Allow behavior module to add/modify sync data
            if behavior_module and behavior_module.get_frame_sync_data then
                local behavior_data = behavior_module.get_frame_sync_data(room_state)
                if behavior_data then
                    for k, v in pairs(behavior_data) do
                        frame_buffer[k] = v
                    end
                end
            end

            room_state.room_tx_to_players:publish({ type = "frame_sync", body = frame_buffer })

            room_state.frame_events = {} -- Clear events after sending
        end
        -- If player_count <= 0, the loop continues, waiting for players
    end
end

s.open = function()
    s.CMD = CMD
    room_state.room_tx_to_players = mc.new() -- Assign to shared state

    -- Load and initialize behavior module based on room_type
    if room_type == "pvp" then
        -- Log("Loading PvP behavior module...")
        -- behavior_module = require("service.room_actor.pvp") -- Direct require, will error out if pvp.lua fails
        -- if behavior_module.init then
        --     behavior_module.init(room_state)
        -- else
        --     Log("PvP module loaded but has no init function.")
        -- end
    else
        Log("Room type is not PvP, running basic room logic.")
    end

    skynet.fork(frame_syncer)
end

s.close = function()
    -- Call behavior module's close function if it exists
    if behavior_module and behavior_module.on_close then
        behavior_module.on_close(room_state)
    end

    -- 2. 通知 room_mgr 房间已销毁
    Log("通知 Room Manager")
    skynet.call(skynet.queryservice("room_mgr"), "lua", "room_destroyed", s.ip)


    -- 通知房间内所有玩家房间已销毁
    if player_count > 0 and room_state.room_tx_to_players then
        Log("广播房间销毁通知给玩家")
        room_state.room_tx_to_players:publish({ type = "room_destroyed", body = {} })
    end

    -- 4. 退出服务
    Log("房间服务退出")
    skynet.exit()
    -- 在此处保存角色数据
    -- skynet.sleep(200)
end

s.start("[room " .. room_type .. " ]", ...)

---@diagnostic disable: lowercase-global
local skynet = require "skynet"
local mc = require "skynet.multicast"
local s = require "service"

local room_type, room_mapid = ...


local room_tx_to_players = nil

local player_count = 0

local playerUid_position = {}
local frame_events = {}

local CMD = {}


local players = {}

local function player(player_sprite_info)
    return {
        nickname = player_sprite_info.nickname,
        --- 指明是哪款机甲
        theme = player_sprite_info.theme,
        HP = player_sprite_info.max_HP,
        position = {
            x = 0,
            y = 0,
            z = 0,
            --- 是否朝向地图左边，不是左就是右
            isFacingLeft = false
        }
    }
end
-- 获取房间信息
function CMD.get_room_info()
    return {
        id = s.ip,
        type = room_type,
        mapid = room_mapid,
        player_count = player_count
    }
end

-- debug用
local function printTable(tbl, indent)
    indent = indent or ""
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            print(indent .. k .. " = {")
            printTable(v, indent .. "  ")
            print(indent .. "}")
        else
            print(indent .. k .. " = " .. tostring(v))
        end
    end
end


--- 玩家加入房间 返回帮助玩家连接到房间频道的 connection_info
---@return table
function CMD.player_enter(uid, player_sprite_info)
    playerUid_position[uid] = player(player_sprite_info)
    player_count = player_count + 1
    Log("玩家加入房间，当前玩家数量：" .. player_count)
    return {
        ---@diagnostic disable-next-line: need-check-nil, undefined-field
        room_tx_channel_id = room_tx_to_players.channel,
        room_state = get_room_state()
    }
end

-- 获取房间状态
function get_room_state()
    return {
        player_count = player_count,
        type = room_type,
        room_current_time = skynet.now(),
    }
end

-- 玩家离开房间
function CMD.player_leave(uid)
    player_count = player_count - 1
    playerUid_position[uid] = nil
    Log("玩家离开房间，当前玩家数量：" .. player_count)
end

--- 玩家：位置更新
--- @param uid string 玩家uid
--- @param position table 玩家位置信息
function CMD.player_position_update(uid, position)
    -- Log("玩家位置更新：" .. uid .. " -> " .. cjson.encode(position))
    playerUid_position[uid] = position
end

--- 玩家：事件添加
--- @param uid string 玩家uid
--- @param event table 玩家事件信息
function CMD.player_event_add(uid, event)
    table.insert(frame_events, { uid = uid, type = event.type, body = event.body })
end


-- 内部函数：广播消息给房间内其他玩家
function frame_syncer()
    while true do
        skynet.sleep(2)          -- 保持原来的同步间隔
        if player_count > 0 then -- 增加检查 room_tx_to_players 是否存在
            local frame_buffer = {
                in_room_players = playerUid_position,
                events = frame_events,
                timestamp = skynet.now(),
            }
            -- skynet.error(type(1))
            room_tx_to_players:publish({ type = "frame_sync", body = frame_buffer })

            frame_events = {}
        end
        -- 如果 player_count <= 0，循环继续，等待玩家加入
    end
end

s.open = function()
    s.CMD = CMD
    -- 在此处加载角色数据
    room_tx_to_players = mc.new()
    skynet.fork(frame_syncer)
end

s.close = function()
    -- 2. 通知 room_mgr 房间已销毁
    Log("通知 Room Manager")
    local ok, err = pcall(skynet.call, ".ROOM_MGR", "lua", "room_destroyed", s.ip)
    if not ok then
        Log("通知 Room Manager 失败: " .. tostring(err))
    end

    -- 3. （可选）通知房间内剩余玩家（如果需要）
    -- 这里可以添加逻辑，例如通过其他方式通知玩家房间关闭
    -- 通知房间内所有玩家房间已销毁
    if player_count > 0 then
        Log("广播房间销毁通知给玩家")
        room_tx_to_players:publish({ type = "room_destroyed", body = { ["s.ip"] = s.ip } })
        -- 短暂等待，确保消息有机会发出
        -- skynet.sleep(10)
    end


    -- 4. 退出服务
    Log("房间服务退出")
    skynet.exit()
    -- 在此处保存角色数据
    -- skynet.sleep(200)
end

s.start("[room " .. room_type .. " ]", ...)


local skynet = require "skynet"
local mc = require "skynet.multicast"

local room_type,room_mapid = ...


local room_tx_to_players = nil

local player_count = 0
room_id = nil
local playerId_position = {}
local frame_events = {}

local CMD = {}

function Log(...)
    skynet.error("[room " .. room_id .. " " .. room_type .. " ]" .. ... .. "。")
end

-- 关闭本房间
function CMD.destroy()
    Log("房间自销毁...")

    -- 2. 通知 room_mgr 房间已销毁
    Log("通知 Room Manager")
    local ok, err = pcall(skynet.call, ".ROOM_MGR", "lua", "room_destroyed", room_id)
    if not ok then
        Log("通知 Room Manager 失败: " .. tostring(err))
    end

    -- 3. （可选）通知房间内剩余玩家（如果需要）
    -- 这里可以添加逻辑，例如通过其他方式通知玩家房间关闭
    -- 通知房间内所有玩家房间已销毁
    if player_count > 0 then
        Log("广播房间销毁通知给玩家")
        room_tx_to_players:publish({type="room_destroyed", body={room_id=room_id}})
        -- 短暂等待，确保消息有机会发出
        -- skynet.sleep(10) 
    end
    

    -- 4. 退出服务
    Log("房间服务退出")
    skynet.exit()
end

-- 获取房间信息
function CMD.get_room_info()
    return {
        id = room_id,
        type = room_type,
        mapid = room_mapid,
        player_count = player_count
    }
end

-- 定义一个函数来递归打印 table
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
function CMD.player_enter(uid, player_position)
    playerId_position[uid] = player_position
    player_count = player_count + 1
    Log("玩家加入房间，当前玩家数量：" .. player_count)
    return {
    ---@diagnostic disable-next-line: need-check-nil, undefined-field
        room_tx_channel_id = room_tx_to_players.channel,
        room_state = get_room_state()
    }
end

-- 玩家离开房间
function CMD.player_leave(uid)
    player_count = player_count - 1
    playerId_position[uid] = nil
    Log("玩家离开房间，当前玩家数量：" .. player_count)
end

--- 玩家：位置更新
--- @param uid string 玩家uid
--- @param position table 玩家位置信息 
function CMD.player_position_update(uid, position)
    -- Log("玩家位置更新：" .. uid .. " -> " .. cjson.encode(position))
    playerId_position[uid] = position
end

--- 玩家：事件添加
--- @param uid string 玩家uid
--- @param event table 玩家事件信息 
function CMD.player_event_add(uid, event)
    table.insert(frame_events,{uid=uid,type=event.type,body=event.body})
end

-- 获取房间状态
function get_room_state()
    return {
        room_id = room_id,
        type = room_type,
        room_current_time = skynet.now(),
    }
end

-- 内部函数：广播消息给房间内其他玩家
function frame_syncer()
    while true do
        skynet.sleep(2) -- 保持原来的同步间隔
        if player_count > 0 then -- 增加检查 room_tx_to_players 是否存在
            local frame_buffer = {
                in_room_players = playerId_position,
                events = frame_events,
                timestamp = skynet.now(),
            }
            -- skynet.error(type(1))
            room_tx_to_players:publish({type="frame_sync",body=frame_buffer})

            frame_events = {}
        end
        -- 如果 player_count <= 0，循环继续，等待玩家加入
    end
end

skynet.start(function()
    room_id = skynet.self()
    room_tx_to_players = mc.new()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            Log("Unknown command", cmd)
        end
    end)

    Log("房间初始化完毕")
    skynet.fork(frame_syncer)
end)

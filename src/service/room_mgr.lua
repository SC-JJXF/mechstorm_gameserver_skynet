local skynet = require "skynet"
local s = require "service"

local rooms = {} -- 追踪所有房间
local lobby_mapid_room = {} -- 追踪每个地图的大厅房间 { [mapid] = room_id }

local CMD = {}
local ROOM_MODEL = (require "models.room")


--- 创建新房间
---@param room_type number
---@param room_mapid integer
---@return integer room_id
function CMD.create_room(room_type, room_mapid)
    Log("创建新房间, 类型: " .. room_type .. ", 地图ID: " .. room_mapid)

    local room_id = skynet.newservice("room_actor")
    skynet.call(room_id,"lua","open",room_type, room_mapid)

    rooms[room_id] = true -- 记录活跃房间
    Log("新房间 " .. room_id .. " 已创建")

    -- 如果是大厅房间，更新对应地图的大厅房间ID
    if room_type == ROOM_MODEL.ROOM_TYPE.LOBBY then
        lobby_mapid_room[room_mapid] = room_id
        Log("地图 " .. room_mapid .. " 的大厅房间更新为 " .. room_id)
    end

    return room_id
end

--- 按地图名获取大厅房间
---@param map_id integer
---@return integer room_id
function CMD.get_lobby_room(map_id)
    local room_id = lobby_mapid_room[map_id]
    if room_id and rooms[room_id] then -- 检查房间是否存在且活跃
        Log("找到地图为 " .. map_id .. " 的大厅房间: " .. room_id)
        return room_id
    else
        Log("未找到地图为 " .. map_id .. " 的大厅房间，创建一个")
        if room_id and not rooms[room_id] then
             lobby_mapid_room[map_id] = nil
        end
        return CMD.create_room(ROOM_MODEL.ROOM_TYPE.LOBBY, map_id )
    end
end

--- 房间actor通知管理器它已销毁
---@param room_id integer
function CMD.room_destroyed(room_id)
    if not rooms[room_id] then
        Log("尝试销毁一个不存在或已销毁的房间: " .. room_id)
        return
    end

    Log("房间 " .. room_id .. " 已销毁，进行清理")
    rooms[room_id] = nil -- 从活跃房间列表中移除

    -- 检查是否需要清理大厅房间记录
    for mapid, lobby_room_id in pairs(lobby_mapid_room) do
        if lobby_room_id == room_id then
            Log("清理地图 " .. mapid .. " 的大厅房间记录")
            lobby_mapid_room[mapid] = nil
            break -- 一个房间只可能是一个地图的大厅
        end
    end
end


-- 删除空房间
-- function CMD.remove_room(room_id)
--     if rooms[room_id] and room_id ~= lobby then
--         rooms[room_id] = nil
--     end
-- end


s.CMD = CMD
s.start "room_mgr"
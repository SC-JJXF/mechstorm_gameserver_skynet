local skynet = require "skynet"
local s = require "service"


local lobby_mapid_roomip = {} -- 大厅：追踪每个大厅地图对应的房间 { [mapid] = room_id }

local CMD = {}
local ROOM_MODEL = (require "models.room")


--- 创建新房间
---@param room_type number
---@param room_mapid integer
---@return integer room_id
function create_room(room_type, room_mapid)
    Log("创建新房间, 类型: " .. room_type .. ", 地图ID: " .. room_mapid)

    local room_id = skynet.newservice("room_actor")
    skynet.call(room_id,"lua","open",room_type, room_mapid)


    -- 如果是大厅房间，更新对应地图的大厅房间ID
    if room_type == ROOM_MODEL.ROOM_TYPE.LOBBY then
        lobby_mapid_roomip[room_mapid] = room_id
        Log("地图 " .. room_mapid .. " 的大厅房间更新为 " .. room_id)
    end

    return room_id
end

--- 创建新房间
---@param pvp_type integer
---@return integer room_id
function CMD.create_pvp_room(pvp_type,roomPlayers)
    Log("创建新pvp房间, pvp类型: " .. pvp_type)

    local room_id = create_room(ROOM_MODEL.ROOM_TYPE.PVP,ROOM_MODEL.getMapId(pvp_type))
    CallActor(room_id,"pvp_init",roomPlayers,pvp_type)
    return room_id
end

--- 按地图id获取大厅房间
---@param map_id integer
---@return integer|nil room_id 
function CMD.get_lobby_room(map_id)
    if not ROOM_MODEL.isHallMapId(map_id) then
       return nil 
    end
    local room_id = lobby_mapid_roomip[map_id]
    if room_id then -- 检查房间是否存在且活跃
        -- Log("找到地图为 " .. map_id .. " 的大厅房间: " .. room_id)
        return room_id
    else
        Log("未找到地图为 " .. map_id .. " 的大厅房间，创建一个")
        return create_room(ROOM_MODEL.ROOM_TYPE.LOBBY, map_id )
    end
end

--- 房间actor通知管理器它已销毁
---@param room_id integer
function CMD.room_destroyed(room_id)
    Log("房间 " .. room_id .. " 已销毁，更新索引")

    -- 检查是否需要清理大厅房间记录
    for mapid, lobby_room_id in pairs(lobby_mapid_roomip) do
        if lobby_room_id == room_id then
            Log("清理地图 " .. mapid .. " 对应的大厅房间记录")
            lobby_mapid_roomip[mapid] = nil
            break -- 一个房间只可能是一个地图的大厅
        end
    end
end


s.CMD = CMD
s.start "room_mgr"
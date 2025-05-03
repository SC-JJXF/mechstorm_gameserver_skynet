local skynet = require "skynet"

local active_rooms = {} -- 追踪所有活跃房间
local lobby_mapid_room = {} -- 追踪每个地图的大厅房间 { [mapid] = room_id }

local CMD = {}
local ROOM_MODEL = (require "models.room_model") -- 修正：移除多余的 lualib 前缀

function Log(...)
    skynet.error("[room_mgr]" .. ... .. "。")
end

--- 创建新房间
---@param room_type number
---@param room_mapid integer
---@return integer room_id
function CMD.create_room(room_type, room_mapid)
    Log("创建新房间, 类型: " .. room_type .. ", 地图ID: " .. room_mapid)
    local room_id = skynet.newservice("room_actor", room_type, room_mapid)
    skynet.call(room_id,"lua","open",room_type, room_mapid)

    active_rooms[room_id] = true -- 记录活跃房间
    Log("新房间 " .. room_id .. " 已创建")

    -- 如果是大厅房间，更新对应地图的大厅房间ID
    if room_type == ROOM_MODEL.ROOM_TYPE.LOBBY then
        lobby_mapid_room[room_mapid] = room_id
        Log("地图 " .. room_mapid .. " 的大厅房间更新为 " .. room_id)
    end

    return room_id
end

--- 按地图名获取大厅房间
---@param map_name string
---@return integer room_id
function CMD.get_lobby_room(map_name)
    ---验证 ROOM_MODEL.MAP_NAME.hall 的 key 列表 有没有lobby_map_name
    
    local room_id = lobby_mapid_room[map_name]
    if room_id and active_rooms[room_id] then -- 检查房间是否存在且活跃
        Log("找到地图为 " .. map_name .. " 的大厅房间: " .. room_id)
        return room_id
    else
        Log("未找到地图为 " .. map_name .. " 的大厅房间或房间已失效，创建新的大厅房间")
        -- 如果之前记录的房间失效了，也清理一下记录
        if room_id and not active_rooms[room_id] then
             lobby_mapid_room[map_name] = nil
        end
        return CMD.create_room(ROOM_MODEL.ROOM_TYPE.LOBBY, ROOM_MODEL.MAP_NAME.hall[map_name] )
    end
end

--- 房间服务通知管理器它已销毁
---@param room_id integer
function CMD.room_destroyed(room_id)
    if not active_rooms[room_id] then
        Log("尝试销毁一个不存在或已销毁的房间: " .. room_id)
        return
    end

    Log("房间 " .. room_id .. " 已销毁，进行清理")
    active_rooms[room_id] = nil -- 从活跃房间列表中移除

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

skynet.start(function()
    
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            skynet.error("Unknown command", cmd)
        end
    end)
end)

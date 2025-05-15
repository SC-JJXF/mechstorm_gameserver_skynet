local ROOM = {}

--- 房间类型定义
ROOM.ROOM_TYPE = {
    ---大厅
    LOBBY = 1,
    ---对战
    PVP = 2,
    ---副本 DUNGEON
    PVE = 3
}

---如果房间类型为pvp，那么pvp的类型是
ROOM.PVP_TYPE = {
    ---单挑
    P1V1 = 1,
    ---乱斗
    P1V1V1V1 = 2,
    ---组队竞技
    P2V2 = 3,
}

ROOM.MAP_NAME = {
    hall = {
        ["Z战队营地"] = 1, -- 使用引号和方括号确保key被正确解析
        ["特训平台"] = 2,
        ["俱乐部"] = 3
    },
    pvp = {
        ["P1V1"] = 4,
        ["P1V1V1V1"] = 5,
        ["P2V2"] = 6,
    }
}

--- 判断hall中是否存在指定的mapid
---@param mapid integer 要检查的地图ID
---@return boolean isHallMapId 如果存在返回true否则false
function ROOM.isHallMapId(mapid)
    for _, id in pairs(ROOM.MAP_NAME.hall) do
        if id == mapid then
            return true
        end
    end
    return false
end

--- 根据PVP类型获取地图ID
---@param pvpType integer PVP类型值(ROOM.PVP_TYPE中的值)
function ROOM.getMapId(pvpType)
    -- 查找PVP类型名称
    local pvpName
    for name, id in pairs(ROOM.PVP_TYPE) do
        if id == pvpType then
            pvpName = name
            break
        end
    end
    assert(pvpName)
    
    -- 查找地图ID
    return ROOM.MAP_NAME.pvp[pvpName]
end

return ROOM

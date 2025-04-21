local ROOM = {}
-- 房间类型定义
ROOM.ROOM_TYPE = {
    ---大厅
    LOBBY = 1,
    ---对战
    PVP = 2,
    ---副本 DUNGEON
    PVE = 3
}

ROOM.MAP_NAME = {
    hall = {
        Z战队营地 = 1,
    },
}

return ROOM

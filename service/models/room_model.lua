local room = {}
-- 房间类型定义
room.ROOM_TYPE = {
    ---大厅
    LOBBY = 1,
    ---对战
    PVP = 2,
    ---副本 DUNGEON
    PVE = 3
}

room.MAP_NAME = {
    hall = {
        Z战队营地 = 1,
    },
}

return room

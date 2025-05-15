local skynet = require "skynet"
local mc = require "skynet.multicast"
local s = require "service"


local sprite_model = (require "models.sprite")
local room_model = (require "models.room")

local room_type, room_mapid

local player_count = 0

---@class Player
---@field uid integer
---@field nickname string
---@field theme string
---@field HP integer
---@field sprite {position: {x:number, y:number, z:number, is_facing_left:boolean}, debuff: integer, debuff_starttime: number}
---@field group integer
---@field DeductHP fun(self: Player, reduceHP: integer)

---@type table<integer, Player>
local players = {}


---@class FrameEvent
---@field uid integer 玩家uid
---@field type string 事件类型
---@field body string 事件内容
---@type FrameEvent[]
local frame_events = {}


-- room_tx_to_players = nil
local roomfunc_modules = {} -- 在 s.open 处加载

-- 高阶函数：用于调用所有模块中的特定方法
function call_module_func(func_name, ...)
    local result = nil
    for _, m in ipairs(roomfunc_modules) do
        -- -- 添加模块有效性检查
        -- if type(m) ~= "table" then
        --     skynet.error("Invalid module type:", type(m))
        --     error("Attempt to call function on invalid module")
        -- end
        if m[func_name] and type(m[func_name]) == "function" then
            result = m[func_name](...)
            if result == true then
                return true
            end
        end
    end
    return false
end

local CMD = {}

-- Shared state accessible by the roomfunc_modules
Room_state = {
    players = players,
    room_type = room_type,
    mapid = room_mapid,
    world = nil,
    s = s,
    ---@type "ended" | "running"
    game_state = "running"
}

local player_metatable = {
    __index = {
        DeductHP = function(self, reduceHP)
            self.HP = self.HP - reduceHP
            if self.HP < 0 then
                self.HP = 0
            end
            if self.HP == 0 then
                call_module_func("on_player_die", self.uid)
            end
        end
    }
}

---@return Player
local function player(uid, player_sprite_info)
    local i = {
        uid = uid,
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
        },
        -- 相同 group 的玩家互为队友，编号从0开始
        group = 0,
        -- -- player_additional_info
        -- pai = {

        -- }
    }
    return setmetatable(i, player_metatable)
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
    players[uid] = player(uid, player_sprite_info)
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
    call_module_func("on_player_leave", uid)
    player_count = player_count - 1
    players[uid] = nil

    Log("玩家离开房间，当前玩家数量：" .. player_count)
    -- Log(player_count..room_type )
    if player_count == 0 and room_type ~= room_model.ROOM_TYPE.LOBBY then
        Log("房间无人，自我销毁...")
        skynet.send(s.ip, "lua", "close")
    end
end

--- 玩家：位置更新
--- @param uid integer 玩家uid
--- @param position table 玩家位置信息
function CMD.player_position_update(uid, position)
    if players[uid].HP == 0 or Room_state.game_state ~= "running" then
        return
    end
    call_module_func("on_player_position_update", uid, position)
    -- Log("玩家位置更新：" .. uid .. " -> " .. cjson.encode(position))
    players[uid]["sprite"]["position"] = position
end

--- 玩家：收到debuff（由玩家本身更新）
--- @param uid integer 玩家uid
--- @param debuffname string 玩家位置信息
function CMD.player_get_debuff(uid, debuffname)
    if Room_state.game_state ~= "running" then
        return
    end
    if players[uid].HP == 0 and debuffname ~= "die" then
        return
    end
    if sprite_model.debuff_type[debuffname] == nil then
        return
    end
    call_module_func("on_player_get_debuff", uid, debuffname)
    players[uid]["sprite"].debuff = sprite_model.debuff_type[debuffname]
    players[uid]["sprite"].debuff_starttime = skynet.now()
end

--- 玩家：事件添加
--- @param uid integer 玩家uid
--- @param event table 玩家事件信息
function CMD.player_event_add(uid, event)
    --- TODO: 将聊天系统从房间模块拆分出去后，屏蔽hp为0的玩家上报的任何事件
    --- 现在先硬编码 msg 吧。
    if players[uid].HP == 0 and event.type ~= "msg" then
        return
    end
    local event_handled = call_module_func("handle_player_event", uid, event.type, event.body)
    table.insert(frame_events, { uid = uid, type = event.type, body = event.body })
end

-- 内部函数：广播消息给房间内其他玩家
local function frame_syncer()
    while true do
        skynet.sleep(2)                                     -- 50fps左右
        call_module_func("world_update")
        if player_count > 0 and room_tx_to_players then     -- Check room_tx_to_players exists
            local frame_buffer = {
                in_room_players = Room_state.players,
                events = frame_events,
                timestamp = skynet.now(),
            }

            room_tx_to_players:publish({ type = "frame_sync", body = frame_buffer })

            frame_events = {}     -- Clear events after sending
        end
    end
end

s.open = function(...)
    room_type, room_mapid = ...
    s.name = "room " .. room_type
    room_tx_to_players = mc.new()

    -- 加载房间类型对应的模块
    if room_type == room_model.ROOM_TYPE.PVP then
        -- local pvp, err = require("pvp")
        -- if not pvp or type(pvp) ~= "table" then
        --     skynet.error("PVP模块加载失败:", err or "未知错误")
        --     error("PVP模块加载失败: " .. tostring(err or "模块未正确导出"))
        -- end

        -- if not pvp.CMD or type(pvp.CMD) ~= "table" then
        --     skynet.error("PVP模块缺少CMD表")
        --     error("PVP模块结构不完整：缺少CMD表")
        -- end

        -- if not pvp.CMD.pvp_init or type(pvp.CMD.pvp_init) ~= "function" then
        --     skynet.error("PVP模块缺少初始化函数")
        --     error("PVP模块缺少必要的pvp_init函数")
        -- end
        table.insert(roomfunc_modules, require("pvp"))
    end

    --- 注册模块们提供的消息处理函数
    --- 感谢 huahua132 的文章！
    for _, m in pairs(roomfunc_modules) do
        local register_cmd = m.CMD
        for cmdname, func in pairs(register_cmd or {}) do
            assert(not s.CMD[cmdname], "exists cmdname: " .. cmdname)
            s.CMD[cmdname] = func
        end
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

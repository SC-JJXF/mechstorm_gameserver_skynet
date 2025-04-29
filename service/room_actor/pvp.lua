--- PvP specific logic module for room_actor
local skynet = require "skynet"

local M = {}

-- Called when a PvP room is initialized
-- @param room_state A table containing the shared room state (players, room_tx_to_players, etc.)
function M.init(room_state)
    Log("PvP module initialized.")
    -- Initialize PvP specific state if needed
    room_state.pvp_data = {} -- Example placeholder
end

-- Called when a player adds an event in a PvP room
-- @param uid Player UID
-- @param event The event data
-- @param room_state Shared room state
function M.handle_player_event(uid, event, room_state)
    Log("PvP handling event from " .. uid .. ": type=" .. tostring(event.type))
    -- Handle events like 'attack', 'skill_cast', etc.
    -- Modify room_state.players based on PvP rules (e.g., HP changes)
    -- Add PvP specific events to frame_events if needed
end

-- Called by frame_syncer to get PvP specific data for the sync packet
-- @param room_state Shared room state
-- @return A table with PvP data, or nil
function M.get_frame_sync_data(room_state)
    -- Example: return scores, special states, etc.
    -- return { scores = room_state.pvp_data.scores }
    return nil -- Placeholder
end

-- Called when a player leaves a PvP room
-- @param uid Player UID
-- @param room_state Shared room state
function M.on_player_leave(uid, room_state)
    Log("PvP handling player leave: " .. uid)
    -- Clean up any PvP state related to the player
end

-- Called when the PvP room is closing
-- @param room_state Shared room state
function M.on_close(room_state)
    Log("PvP module closing.")
    -- Clean up any global PvP state for the room
end

return M

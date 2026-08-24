-- ================================================================
-- FILE: core/event_bus.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: DYNAMIC ZERO-GC HIGH PERFORMANCE EVENT BUS
-- Pre-allocated listener arrays for dynamic string-based events
-- ============================================================================
local EventBus = {}

EventBus.ON_BEAT            = "on_beat"
EventBus.ON_PIECE_SPAWN     = "on_piece_spawn"
EventBus.ON_PIECE_MOVE      = "on_piece_move"
EventBus.ON_PIECE_ROTATE    = "on_piece_rotate"
EventBus.ON_PIECE_LOCK      = "on_piece_lock"
EventBus.ON_LINE_CLEAR      = "on_line_clear"
EventBus.ON_PARRY           = "on_parry"
EventBus.ON_STANCE_CHANGE   = "on_stance_change"
EventBus.ON_ZONE_ENTER      = "on_zone_enter"
EventBus.ON_ZONE_EXIT       = "on_zone_exit"
EventBus.ON_BOARD_DEATH     = "on_board_death"
EventBus.ON_MATCH_RESTART   = "on_match_restart"
EventBus.ON_PLUGIN_RELOAD   = "on_plugin_reload"

local MAX_LISTENERS_PER_EVENT = 32
local listeners = {}
local listener_counts = {}

local function ensureEvent(event_id)
    if not listeners[event_id] then
        listeners[event_id] = {}
        listener_counts[event_id] = 0
        for i = 1, MAX_LISTENERS_PER_EVENT do
            listeners[event_id][i] = false
        end
    end
end

function EventBus.init()
    -- Clears out all current listeners but keeps the structure for reuse
    for event_id, _ in pairs(listeners) do
        listener_counts[event_id] = 0
        for i = 1, MAX_LISTENERS_PER_EVENT do
            listeners[event_id][i] = false
        end
    end
end

function EventBus.on(event_id, callback)
    if not event_id or type(event_id) ~= "string" or type(callback) ~= "function" then
        return false
    end

    ensureEvent(event_id)

    local count = listener_counts[event_id]
    if count >= MAX_LISTENERS_PER_EVENT then
        return false
    end

    for i = 1, count do
        if listeners[event_id][i] == callback then
            return true
        end
    end

    count = count + 1
    listeners[event_id][count] = callback
    listener_counts[event_id] = count
    return true
end

function EventBus.off(event_id, callback)
    if not event_id or type(event_id) ~= "string" then return end
    if not listeners[event_id] then return end

    local count = listener_counts[event_id]
    for i = 1, count do
        if listeners[event_id][i] == callback then
            listeners[event_id][i] = listeners[event_id][count]
            listeners[event_id][count] = false
            listener_counts[event_id] = count - 1
            return
        end
    end
end

function EventBus.emit(event_id, a, b, c, d, e)
    if not event_id or type(event_id) ~= "string" then return end
    if not listeners[event_id] then return end
    
    local count = listener_counts[event_id]
    local list = listeners[event_id]

    for i = 1, count do
        local fn = list[i]
        if fn then
            fn(a, b, c, d, e)
        end
    end
end

return EventBus
-- ================================================================
-- FILE: core/event_bus.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: ZERO-GC HIGH PERFORMANCE EVENT BUS
-- Pre-allocated listener arrays with direct scalar dispatch
-- ============================================================================
local EventBus = {}

EventBus.ON_BEAT            = 1
EventBus.ON_PIECE_SPAWN     = 2
EventBus.ON_PIECE_MOVE      = 3
EventBus.ON_PIECE_ROTATE    = 4
EventBus.ON_PIECE_LOCK      = 5
EventBus.ON_LINE_CLEAR      = 6
EventBus.ON_PARRY           = 7
EventBus.ON_STANCE_CHANGE   = 8
EventBus.ON_ZONE_ENTER      = 9
EventBus.ON_ZONE_EXIT       = 10
EventBus.ON_BOARD_DEATH     = 11
EventBus.ON_MATCH_RESTART   = 12
EventBus.ON_PLUGIN_RELOAD   = 13

local MAX_LISTENERS_PER_EVENT = 32
local listeners = {}
local listener_counts = {}

for event_id = 1, 32 do
    listeners[event_id] = {}
    listener_counts[event_id] = 0
    for i = 1, MAX_LISTENERS_PER_EVENT do
        listeners[event_id][i] = false
    end
end

function EventBus.init()
    for event_id = 1, 32 do
        listener_counts[event_id] = 0
        for i = 1, MAX_LISTENERS_PER_EVENT do
            listeners[event_id][i] = false
        end
    end
end

function EventBus.on(event_id, callback)
    if not event_id or event_id < 1 or event_id > 32 or type(callback) ~= "function" then
        return false
    end

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
    if not event_id or event_id < 1 or event_id > 32 then return end

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
    if not event_id or event_id < 1 or event_id > 32 then return end
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
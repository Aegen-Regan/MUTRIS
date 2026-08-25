-- ============================================================================
-- MUTRIS - SUBSISTEMA: ANOMALY_MANAGER.LUA (CORE MECHANICS INTERCEPTOR)
-- GOLDEN RULE: 100% ZERO-GC PARAMETRIC MODIFIERS. PREVENT RUNTIME ALLOCATIONS.
-- ============================================================================

local Blackbox = require "core.blackbox"

local AnomalyManager = {
    -- Persistent static flags (No dynamic tables inside the hot loop)
    is_controls_inverted = false,
    gravity_multiplier = 1.0,
    active_anomaly_id = 0,
    
    -- Timer variables driven by delta time
    internal_timer = 0.0,
    anomaly_duration = 4.0,   -- Duration in seconds
    cycle_interval = 12.0     -- Time between anomaly trigger attempts
}

-- Heat update logic called inside the main loop
function AnomalyManager.update(dt)
    AnomalyManager.internal_timer = AnomalyManager.internal_timer + dt
    
    -- If an anomaly is currently running, check if its duration expired
    if AnomalyManager.active_anomaly_id > 0 then
        if AnomalyManager.internal_timer >= AnomalyManager.anomaly_duration then
            AnomalyManager.clear_anomaly()
        end
    else
        -- Cycle evaluator: Every 12 seconds, switch to an active tactical modifier
        if AnomalyManager.internal_timer >= AnomalyManager.cycle_interval then
            -- Trigger Anomaly ID 1 (Atomic Input Inversion)
            AnomalyManager.trigger_anomaly(1)
        end
    end
end

-- Mutates specific static flags within the engine's memory layout
function AnomalyManager.trigger_anomaly(anomaly_id)
    AnomalyManager.active_anomaly_id = anomaly_id
    AnomalyManager.internal_timer = 0.0 -- Reset internal clock for duration tracking
    
    if anomaly_id == 1 then
        AnomalyManager.is_controls_inverted = true
        AnomalyManager.gravity_multiplier = 1.0
    elseif anomaly_id == 2 then
        AnomalyManager.is_controls_inverted = false
        AnomalyManager.gravity_multiplier = 3.5 -- Fast rhythmic gravity drop
    end
    
    if Blackbox and Blackbox.record then
        Blackbox.record(Blackbox.TYPES.ANOMALY, anomaly_id * 1.0, "ANOMALY_GATILLER_OK")
    end
end

-- Restores competitive parameters back to normal base values
function AnomalyManager.clear_anomaly()
    AnomalyManager.active_anomaly_id = 0
    AnomalyManager.internal_timer = 0.0 -- Reset internal clock for cycle tracking
    AnomalyManager.is_controls_inverted = false
    AnomalyManager.gravity_multiplier = 1.0
    
    if Blackbox and Blackbox.record then
        Blackbox.record(Blackbox.TYPES.ANOMALY, 0.0, "ANOMALY_CLEARED_OK")
    end
end

-- Ultra-fast input filter to inject directly into keypressed routines
function AnomalyManager.filter_direction(direction_string)
    if not AnomalyManager.is_controls_inverted then
        return direction_string
    end
    
    -- Fast cache lookup swap using static literal strings
    if direction_string == "left" then return "right" end
    if direction_string == "right" then return "left" end
    return direction_string
end

return AnomalyManager
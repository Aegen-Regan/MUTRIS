-- ============================================================================
-- FILE: core/sentinel.lua (RUNTIME DIAGNOSTIC SENTINEL v4.1 - PURE NUMERIC STATE)
-- Philosophy: Silent on Success. Strictly Zero Allocation. Absolute Zero-GC.
-- ============================================================================
---@diagnostic disable: undefined-global

local Sentinel = {}

-- ── ANSI ESCAPE SEQUENCES (Pre-allocated static pointers) ───────────────────
local ANSI_RED     = "\27[31m[SENTINEL CRITICAL]\27[0m "
local ANSI_YELLOW  = "\27[33m[SENTINEL WARN   ]\27[0m "
local ANSI_MAGENTA = "\27[35m[SENTINEL PERF   ]\27[0m "

-- --- THRESHOLDS
local FRAME_BUDGET_SEC  = 1.0 / 238.0
local RAM_DELTA_KB      = 1.0           -- Subido a 1.0 KB para mitigar falsos positivos
local GARBAGE_QUEUE_MAX = 20
local CONSECUTIVE_LIMIT = 3             -- La regla de los 3 frames de Claude

-- --- STATE (Pre-allocated fields, zero growth at runtime)
local _frame_count       = 0
local _prev_ram_kb       = 0.0
local _perf_consecutives = 0             -- Inicializador numérico limpio
local _leak_consecutives = 0             -- Inicializador numérico limpio

-- Public Flags (Zero-GC communication layer for HUD matrices)
-- "Silent on Success": both of these MUST be false/0.0 at boot and MUST
-- return to false/0.0 whenever no real anomaly is active. Sentinel.init()
-- re-asserts this explicitly on every (re)start, and the decay logic in
-- auditFrame() is the only path that flips is_breach_active back to false.
Sentinel.visual_alert_timer = 0.0
Sentinel.is_breach_active   = false
Sentinel.current_type       = ""

-- RAW NUMERIC DATA OVERLAY (Annihilates string allocation loops completely)
Sentinel.val_delta  = 0.0
Sentinel.val_total  = 0.0
Sentinel.val_frame  = 0

-- ── INIT ─────────────────────────────────────────────────────────────────────
function Sentinel.init()
    _frame_count = 0
    _prev_ram_kb = collectgarbage("count")
    -- Strict Alarm Reset: explicit false/0.0 on every boot, no exceptions.
    Sentinel.visual_alert_timer = 0.0
    Sentinel.is_breach_active   = false
    Sentinel.current_type       = ""
    Sentinel.val_delta          = 0.0
    Sentinel.val_total          = 0.0
    Sentinel.val_frame          = 0
    io.write("\27[36m[SENTINEL]\27[0m Runtime Sentinel v4.1 (Pure Numeric) Online.\n")
    io.flush()
end

-- ── AUDIT FRAME ──────────────────────────────────────────────────────────────
function Sentinel.auditFrame(dt, current_scene)
    _frame_count = _frame_count + 1

    -- Synchronize alert clock with pure float arithmetic (Zero-GC)
    if Sentinel.visual_alert_timer > 0 then
        Sentinel.visual_alert_timer = math.max(0, Sentinel.visual_alert_timer - dt)
        if Sentinel.visual_alert_timer == 0 then
            Sentinel.is_breach_active = false
            Sentinel.current_type     = nil
        end
    end

    -- CHECK 1: PERFORMANCE FLUCTUATIONS (Con ventana de persistencia de 3 frames)
    if _frame_count > WARMUP_FRAMES and dt > FRAME_BUDGET_SEC then
        _perf_consecutives = _perf_consecutives + 1
        if _perf_consecutives >= CONSECUTIVE_LIMIT then
            Sentinel.visual_alert_timer = ALERT_DURATION
            Sentinel.is_breach_active   = true
            Sentinel.current_type       = "PERF"
            
            -- Capture pure numerical data points
            Sentinel.val_delta          = dt * 1000.0
            Sentinel.val_total          = (dt - FRAME_BUDGET_SEC) * 1000000.0
            Sentinel.val_frame          = _frame_count
        end
    else
        _perf_consecutives = 0 -- Rompe la racha si el rendimiento es óptimo
    end

    -- CHECK 2: HEAP MEMORY EXPLOSIONS
    local cur_ram_kb = collectgarbage("count")
    local ram_delta  = cur_ram_kb - _prev_ram_kb

    -- BUGFIX (Silent Rule): Gating on _frame_count and enforcing CONSECUTIVE_LIMIT
    if _frame_count > WARMUP_FRAMES and ram_delta > RAM_DELTA_KB then
        local is_paused   = current_scene and current_scene.is_paused
        local is_blackout = _G.IsBlackoutActive
        
        if not is_paused and not is_blackout then
            _leak_consecutives = _leak_consecutives + 1
            if _leak_consecutives >= CONSECUTIVE_LIMIT then
                Sentinel.visual_alert_timer = ALERT_DURATION
                Sentinel.is_breach_active   = true
                Sentinel.current_type       = "LEAK"
                
                -- Store integers and floats directly in the module layout (No string.format!)
                Sentinel.val_delta          = ram_delta
                Sentinel.val_total          = cur_ram_kb
                Sentinel.val_frame          = _frame_count
            end
        else
            _leak_consecutives = 0 -- Reset instantáneo si está en pausa o blackout
        end
    else
        _leak_consecutives = 0 -- Mitiga blips legítimos y transitorios (font/texture caches)
    end

    -- Baseline tracking stays UNCONDITIONAL (runs every frame, warmup or not)
    _prev_ram_kb = cur_ram_kb

    -- CHECK 3: GARBAGE QUEUE OVERFLOW
    if current_scene and current_scene.boards then
        local human_board = current_scene.boards[1]
        if human_board and human_board.garbage_queue then
            local gq    = human_board.garbage_queue
            local depth = 0
            for i = 1, #gq do
                local g = gq[i]
                depth = depth + (type(g) == "table" and g.lines or g)
            end
            if depth > GARBAGE_QUEUE_MAX then
                io.write(ANSI_RED .. "GARBAGE OVERFLOW | depth=" .. depth .. "\n")
                io.flush()
            end
        end
    end
end

function Sentinel.drawOverlay() end

function Sentinel.getLayoutShift()
    if Sentinel.is_breach_active then
        local SM = package.loaded["core.scene_manager"] or _G.SceneManager
        local state = SM and SM.getState() or ""
        if state:find("menu") or state:find("settings") or state == "" then
            return 70
        end
    end
    return 0
end

return Sentinel
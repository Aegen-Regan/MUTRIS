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

-- ── THRESHOLDS ───────────────────────────────────────────────────────────────
local FRAME_BUDGET_SEC  = 1.0 / 238.0
local RAM_DELTA_KB      = 0.005
local GARBAGE_QUEUE_MAX = 20
-- 180 frames @ 60Hz = 3.0s of cold-boot grace (module loads, skin texturing,
-- initial asset streaming). Every alarm check below must respect this window
-- — see CHECK 2 fix: it was previously ungated and firing as early as
-- frame #1, which is what caused the yellow alert to appear ~frame #60.
local WARMUP_FRAMES     = 180
local ALERT_DURATION    = 3.5

-- ── STATE (Pre-allocated fields, zero growth at runtime) ─────────────────────
local _frame_count = 0
local _prev_ram_kb = 0.0

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
        end
    end

    -- CHECK 1: PERFORMANCE FLUCUATIONS
    if _frame_count > WARMUP_FRAMES and dt > FRAME_BUDGET_SEC then
        Sentinel.visual_alert_timer = ALERT_DURATION
        Sentinel.is_breach_active   = true
        Sentinel.current_type       = "PERF"
        
        -- Capture pure numerical data points
        Sentinel.val_delta          = dt * 1000.0
        Sentinel.val_total          = (dt - FRAME_BUDGET_SEC) * 1000000.0
        Sentinel.val_frame          = _frame_count
    end

    -- CHECK 2: HEAP MEMORY EXPLOSIONS
    local cur_ram_kb = collectgarbage("count")
    local ram_delta  = cur_ram_kb - _prev_ram_kb

    -- BUGFIX (Silent Rule): this check had NO warmup gate at all, unlike
    -- CHECK 1 above. Cold-boot streaming (module tables, skins, texture
    -- caches) routinely moves the heap by far more than RAM_DELTA_KB
    -- (0.005 KB = 5 bytes), so the LEAK alert was free to fire on frame 1
    -- and kept re-arming itself through legitimate boot allocations — this
    -- is exactly what surfaced as the yellow box around frame #60 and made
    -- it look "stuck" into the Main Menu. Gating on _frame_count here
    -- brings CHECK 2 in line with CHECK 1: real runtime spikes only count
    -- once the engine is past cold boot.
    if _frame_count > WARMUP_FRAMES and ram_delta > RAM_DELTA_KB then
        local is_paused   = current_scene and current_scene.is_paused
        local is_blackout = _G.IsBlackoutActive
        
        if not is_paused and not is_blackout then
            Sentinel.visual_alert_timer = ALERT_DURATION
            Sentinel.is_breach_active   = true
            Sentinel.current_type       = "LEAK"
            
            -- Store integers and floats directly in the module layout (No string.format!)
            Sentinel.val_delta          = ram_delta
            Sentinel.val_total          = cur_ram_kb
            Sentinel.val_frame          = _frame_count
        end
    end
    -- Baseline tracking stays UNCONDITIONAL (runs every frame, warmup or
    -- not) so that the moment frame #181 arrives, ram_delta is measured
    -- against the immediately-preceding frame's heap — never against the
    -- stale frame-0 snapshot from init(). This is what prevents a false
    -- "spike" the instant warmup ends.
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
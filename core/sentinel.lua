-- ================================================================
-- FILE: core/sentinel.lua  (RUNTIME DIAGNOSTIC SENTINEL v3.0 - PURE STATE KERNEL)
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: THRESHOLD-BASED HARDWARE SENTINEL (DATA OBSERVER ONLY)
-- Philosophy: Silent on Success. Zero allocation on the nominal path.
-- Breach: ANSI console log + Exposes public flags for scene hardware translations.
-- ============================================================================

local Sentinel = {}

-- ── ANSI ESCAPE SEQUENCES (pre-alocadas en load) ─────────────────────────────
local ANSI_RED     = "\27[31m[SENTINEL CRITICAL]\27[0m "
local ANSI_YELLOW  = "\27[33m[SENTINEL WARN   ]\27[0m "
local ANSI_MAGENTA = "\27[35m[SENTINEL PERF   ]\27[0m "

-- ── THRESHOLDS ───────────────────────────────────────────────────────────────
local FRAME_BUDGET_SEC  = 1.0 / 238.0
local RAM_DELTA_KB      = 0.005
local GARBAGE_QUEUE_MAX = 20
local WARMUP_FRAMES     = 10
local ALERT_DURATION    = 3.5

-- ── STATE (pre-alocado en init, nunca crece en runtime) ──────────────────────
local _frame_count = 0
local _prev_ram_kb = 0.0

-- Flags públicos para consumo directo por las escenas (Hardware Translate triggers)
Sentinel.visual_alert_timer = 0.0
Sentinel.visual_alert_msg   = ""
Sentinel.visual_alert_type  = ""
Sentinel.is_breach_active   = false
Sentinel.current_msg        = ""
Sentinel.current_type       = ""

-- ── INIT ─────────────────────────────────────────────────────────────────────
function Sentinel.init()
    _frame_count = 0
    _prev_ram_kb = collectgarbage("count")
    Sentinel.visual_alert_timer = 0.0
    Sentinel.visual_alert_msg   = ""
    Sentinel.visual_alert_type  = ""
    Sentinel.is_breach_active   = false
    Sentinel.current_msg        = ""
    Sentinel.current_type       = ""
    io.write("\27[36m[SENTINEL]\27[0m Runtime Sentinel v3.0 Online. Budget="
             .. string.format("%.3f", FRAME_BUDGET_SEC * 1000)
             .. "ms | RAM_DELTA=" .. string.format("%.4f", RAM_DELTA_KB) .. " KB\n")
    io.flush()
end

-- ── AUDIT FRAME ──────────────────────────────────────────────────────────────
function Sentinel.auditFrame(dt, current_scene)
    _frame_count = _frame_count + 1

    -- Decrementar timer y sincronizar flag publico (aritmetica pura, sin alloc)
    if Sentinel.visual_alert_timer > 0 then
        Sentinel.visual_alert_timer = math.max(0, Sentinel.visual_alert_timer - dt)
        if Sentinel.visual_alert_timer == 0 then
            Sentinel.is_breach_active = false
        end
    end

    -- CHECK 1: PERFORMANCE
    if _frame_count > WARMUP_FRAMES and dt > FRAME_BUDGET_SEC then
        local spike_us = (dt - FRAME_BUDGET_SEC) * 1000000.0
        local msg = string.format("FRAME SPIKE  dt=%.4fms  over_budget=+%.1fus  frame=#%d",
                                  dt * 1000, spike_us, _frame_count)
        io.write(ANSI_MAGENTA .. msg .. "\n")
        io.flush()
        Sentinel.visual_alert_timer = ALERT_DURATION
        Sentinel.visual_alert_msg   = msg
        Sentinel.visual_alert_type  = "PERF"
        Sentinel.is_breach_active   = true
        Sentinel.current_msg        = msg
        Sentinel.current_type       = "PERF"
    end

    -- CHECK 2: HEAP MEMORY
    local cur_ram_kb = collectgarbage("count")
    local ram_delta  = cur_ram_kb - _prev_ram_kb
    if ram_delta > RAM_DELTA_KB then
        local is_paused   = current_scene and current_scene.is_paused
        local is_blackout = _G.IsBlackoutActive
        if not is_paused and not is_blackout then
            local msg = string.format("RAM DELTA  +%.4f KB  total=%.2f KB  frame=#%d",
                                      ram_delta, cur_ram_kb, _frame_count)
            io.write(ANSI_YELLOW .. msg .. "\n")
            io.flush()
            Sentinel.visual_alert_timer = ALERT_DURATION
            Sentinel.visual_alert_msg   = msg
            Sentinel.visual_alert_type  = "LEAK"
            Sentinel.is_breach_active   = true
            Sentinel.current_msg        = msg
            Sentinel.current_type       = "LEAK"
        end
    end
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
                io.write(ANSI_RED .. string.format(
                    "GARBAGE QUEUE OVERFLOW  depth=%d lines  frame=#%d\n",
                    depth, _frame_count))
                io.flush()
            end
        end
    end
end

-- Deprecado e inactivado de forma permanente para el render de main.lua
function Sentinel.drawOverlay() end

-- Nueva API modular de consulta dinamica de frames por hardware
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

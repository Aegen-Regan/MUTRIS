-- ================================================================
-- FILE: core/blackbox.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: FLIGHT RECORDER & SYSTEM TELEMETRY (ZERO-GC)
-- ============================================================================
local Blackbox = {}
local FontCache    = require "tetris.font_cache"
local ThemeManager = require "tetris.theme_manager"

local MAX_EVENTS = 128
local event_buffer = {}
for i = 1, MAX_EVENTS do
    event_buffer[i] = {
        time = 0.0,
        type = "INIT",
        msg  = "SYSTEM BOOT",
        p1   = 0,
        p2   = 0
    }
end
local head = 1

function Blackbox.init()
    head = 1
    for i = 1, MAX_EVENTS do
        event_buffer[i].time = 0.0
        event_buffer[i].type = "INIT"
        event_buffer[i].msg  = "SYSTEM BOOT"
        event_buffer[i].p1   = 0
        event_buffer[i].p2   = 0
    end
    Blackbox.log("BOOT", "MUTRIS BLACKBOX INITIALIZED", 0, 0)
end

function Blackbox.log(evt_type, msg, p1, p2)
    local e = event_buffer[head]
    e.time = _G.RealMatchTimer or 0.0
    e.type = evt_type or "EVENT"
    e.msg  = msg or ""
    e.p1   = p1 or 0
    e.p2   = p2 or 0

    head = (head % MAX_EVENTS) + 1
end

function Blackbox.guardLoop(loop_name, max_iters, current_iter)
    if current_iter > max_iters then
        Blackbox.log("GUARD", "INFINITE LOOP DETECTED: " .. tostring(loop_name), current_iter, 0)
        return false
    end
    return true
end

function Blackbox.dumpToFile(path, extra_info)
    local f = io.open(path, "w")
    if not f then return false end

    f:write("====================================================================\n")
    f:write("                  MUTRIS ENGINE - FLIGHT RECORDER DUMP              \n")
    f:write("====================================================================\n")
    f:write(string.format("ENGINE VERSION: %s\n", _G.ENGINE_VERSION or "UNKNOWN"))
    f:write(string.format("MATCH TIMER:    %.2fs\n", _G.RealMatchTimer or 0.0))
    f:write(string.format("DATE/TIME:      %s\n\n", os.date("%Y-%m-%d %H:%M:%S")))

    if extra_info then
        f:write("CRASH / DIAGNOSTIC TRACE:\n")
        f:write(extra_info .. "\n\n")
    end

    f:write("LAST 128 TELEMETRY EVENTS (MOST RECENT FIRST):\n")
    f:write("--------------------------------------------------------------------\n")
    
    local idx = (head - 2 + MAX_EVENTS) % MAX_EVENTS + 1
    for _ = 1, MAX_EVENTS do
        local e = event_buffer[idx]
        if e.time > 0 or e.type ~= "INIT" then
            f:write(string.format("[%06.1fs] %-16s | %-28s | P1: %-4d | P2: %-4d\n", e.time, e.type, e.msg, e.p1, e.p2))
        end
        idx = (idx - 2 + MAX_EVENTS) % MAX_EVENTS + 1
    end

    f:write("====================================================================\n")
    f:close()
    return true
end

-- ============================================================================
-- 🎨 RENDERIZADO DEL FLIGHT RECORDER CENTRAL (ZERO-GC / PARAMÉTRICO)
-- ============================================================================
function Blackbox.drawPermanentHUD(p1, p2, center_x, is_boss_mode)
    local t = ThemeManager.getCurrent()
    local cx = center_x or 640
    local pw, ph = is_boss_mode and 260 or 300, 140
    local px = cx - (pw / 2)
    local py = 330

    love.graphics.push("all")

    ThemeManager.drawPanel(px, py, pw, ph, "", false)

    love.graphics.setFont(FontCache.get(9))
    love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.95)
    love.graphics.printf("LIVE FLIGHT RECORDER", px, py + 6, pw, "center")

    love.graphics.setFont(FontCache.get(8))
    local line_y = py + 22
    local count = 0
    local idx = (head - 2 + MAX_EVENTS) % MAX_EVENTS + 1

    while count < 8 do
        local e = event_buffer[idx]
        if e.time > 0 or e.type ~= "INIT" then
            love.graphics.setColor(0, 0.95, 1.0, 0.90)
            love.graphics.print(string.format("[%04.1fs] %s", e.time, e.type:sub(1, 10)), px + 8, line_y)

            love.graphics.setColor(1, 1, 1, 0.70)
            love.graphics.print("| " .. e.msg:sub(1, is_boss_mode and 14 or 18), px + (is_boss_mode and 95 or 105), line_y)

            line_y = line_y + 13
            count = count + 1
        end
        idx = (idx - 2 + MAX_EVENTS) % MAX_EVENTS + 1
    end

    love.graphics.pop()
end

return Blackbox
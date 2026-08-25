-- ================================================================
-- FILE: core/blackbox.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS - SUBSISTEMA: BLACKBOX CAJA NEGRA
-- REGLA DE ORO: 100% ZERO-GC LOOP. PRE-ASIGNACIÓN TOTAL EN MEMORIA.
-- ============================================================================
local Blackbox = {
    buffer = {},          -- Búfer circular estático de 128 ranuras
    max_records = 128,    -- Límite estricto de eventos en memoria
    pointer = 1,          -- Índice de escritura actual
    total_events = 0      -- Contador global histórico de eventos
}

local FontCache    = require "tetris.font_cache"
local ThemeManager = require "tetris.theme_manager"

-- Pre-asignamos la memoria de las 128 ranuras al cargar el motor.
-- Cada ranura tiene una estructura fija para que LuaJIT no altere el hash map.
for i = 1, Blackbox.max_records do
    Blackbox.buffer[i] = {
        id = 0,
        timestamp = 0.0,
        frame = 0,
        event_type = "NONE",
        param_num = 0.0,
        param_num2 = 0.0, -- Mantenido por retrocompatibilidad con logs existentes
        param_str = "NONE"
    }
end

-- Mapeo estático de tipos de eventos para evitar instanciar strings dinámicas en juego
Blackbox.TYPES = {
    SYSTEM = "SYS",
    INPUT = "INP",
    PHYSICS = "PHY",
    AUDIO = "AUD",
    ANOMALY = "ANM",
    ERROR = "ERR"
}

function Blackbox.init()
    Blackbox.pointer = 1
    Blackbox.total_events = 0
    for i = 1, Blackbox.max_records do
        local e = Blackbox.buffer[i]
        e.id = 0
        e.timestamp = 0.0
        e.frame = 0
        e.event_type = "INIT"
        e.param_str = "SYSTEM BOOT"
        e.param_num = 0
        e.param_num2 = 0
    end
    Blackbox.log(Blackbox.TYPES.SYSTEM, "MUTRIS BLACKBOX INITIALIZED", 0, 0)
end

function Blackbox.log(evt_type, msg, p1, p2)
    local e = Blackbox.buffer[Blackbox.pointer]
    Blackbox.total_events = Blackbox.total_events + 1
    
    e.id = Blackbox.total_events
    e.timestamp = _G.RealMatchTimer or 0.0
    e.frame = 0
    e.event_type = evt_type or "EVENT"
    e.param_str  = msg or ""
    e.param_num  = p1 or 0
    e.param_num2 = p2 or 0

    Blackbox.pointer = (Blackbox.pointer % Blackbox.max_records) + 1
end

function Blackbox.record(evt_type, param_num, param_str)
    Blackbox.log(evt_type, param_str, param_num, 0)
end

function Blackbox.guardLoop(loop_name, max_iters, current_iter)
    if current_iter > max_iters then
        Blackbox.log(Blackbox.TYPES.ERROR, "INFINITE LOOP DETECTED: " .. tostring(loop_name), current_iter, 0)
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
    
    local idx = (Blackbox.pointer - 2 + Blackbox.max_records) % Blackbox.max_records + 1
    for _ = 1, Blackbox.max_records do
        local e = Blackbox.buffer[idx]
        if e.timestamp > 0 or e.event_type ~= "INIT" then
            f:write(string.format("[%06.1fs] %-16s | %-28s | P1: %-4d | P2: %-4d\n", e.timestamp, e.event_type, e.param_str, e.param_num, e.param_num2))
        end
        idx = (idx - 2 + Blackbox.max_records) % Blackbox.max_records + 1
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
    local idx = (Blackbox.pointer - 2 + Blackbox.max_records) % Blackbox.max_records + 1

    while count < 8 do
        local e = Blackbox.buffer[idx]
        if e.timestamp > 0 or e.event_type ~= "INIT" then
            love.graphics.setColor(0, 0.95, 1.0, 0.90)
            love.graphics.print(string.format("[%04.1fs] %s", e.timestamp, e.event_type:sub(1, 10)), px + 8, line_y)

            love.graphics.setColor(1, 1, 1, 0.70)
            love.graphics.print("| " .. e.param_str:sub(1, is_boss_mode and 14 or 18), px + (is_boss_mode and 95 or 105), line_y)

            line_y = line_y + 13
            count = count + 1
        end
        idx = (idx - 2 + Blackbox.max_records) % Blackbox.max_records + 1
    end

    love.graphics.pop()
end

return Blackbox
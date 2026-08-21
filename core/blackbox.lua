-- ================================================================
-- FILE: core/blackbox.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: BLACKBOX FLIGHT RECORDER & TELEMETRY HUB (1280x720)
-- Arquitectura: Zero-GC / Búfer Circular 128 Slots / Calibrated Event Log
-- ============================================================================
local Blackbox = {}

local FontCache = require "tetris.font_cache"
local ThemeManager = nil

local MAX_EVENTS = 128
local events_buffer = {}
local buffer_head = 1
local total_events_logged = 0

function Blackbox.init()
    events_buffer = {}
    for i = 1, MAX_EVENTS do
        events_buffer[i] = {
            id = i,
            time = 0.0,
            category = "INIT",
            action = "SYSTEM BOOT",
            val1 = 0,
            val2 = 0,
            active = false
        }
    end
    buffer_head = 1
    total_events_logged = 0
end

function Blackbox.log(category, action, val1, val2)
    local slot = events_buffer[buffer_head]
    if slot then
        slot.time = _G.RealMatchTimer or 0.0
        slot.category = category or "EVENT"
        slot.action = action or ""
        slot.val1 = val1 or 0
        slot.val2 = val2 or 0
        slot.active = true

        buffer_head = (buffer_head % MAX_EVENTS) + 1
        total_events_logged = total_events_logged + 1
    end
end

function Blackbox.guardLoop(loop_name, max_allowed, current_count)
    if current_count > max_allowed then
        Blackbox.log("CRITICAL", "INFINITE LOOP DETECTED: " .. loop_name, current_count, max_allowed)
        return false
    end
    return true
end

function Blackbox.dumpToFile(filepath, custom_title)
    local lines = {}
    table.insert(lines, "================================================================================")
    table.insert(lines, "MUTRIS FLIGHT RECORDER AUTOPSY REPORT: " .. (custom_title or "DIAGNOSTIC SNAPSHOT"))
    table.insert(lines, "ENGINE VERSION: " .. (_G.ENGINE_VERSION or "UNKNOWN"))
    table.insert(lines, "MATCH TIME: " .. string.format("%.2fs", _G.RealMatchTimer or 0))
    table.insert(lines, "TIMESTAMP: " .. os.date("%Y-%m-%d %H:%M:%S"))
    table.insert(lines, "================================================================================")
    table.insert(lines, "LAST RECORDED EVENTS (CHRONOLOGICAL ORDER):")

    for i = 1, MAX_EVENTS do
        local idx = ((buffer_head - 1 - i + MAX_EVENTS) % MAX_EVENTS) + 1
        local ev = events_buffer[idx]
        if ev and ev.active then
            table.insert(lines, string.format("[%06.2fs] %-12s | %-32s (V1: %d, V2: %d)", ev.time, ev.category, ev.action, ev.val1, ev.val2))
        end
    end

    table.insert(lines, "================================================================================")
    local content = table.concat(lines, "\n")
    love.filesystem.write(filepath, content)
end

function Blackbox.drawPermanentHUD(player, bot)
    love.graphics.push("all")
    
    if not ThemeManager then
        ThemeManager = require "tetris.theme_manager"
    end
    local t = ThemeManager.getCurrent()

    -- ────────────────────────────────────────────────────────────────────────
    -- 1. TARJETA ALA IZQUIERDA: P1 TELEMETRY (x: 20..136, y: 140..600)
    -- ────────────────────────────────────────────────────────────────────────
    local p1_x, p1_y, p1_w, p1_h = 20, 140, 116, 460
    ThemeManager.drawPanel(p1_x, p1_y, p1_w, p1_h, "", false)

    love.graphics.setFont(FontCache.get(9))
    love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.95)
    love.graphics.printf("P1 TELEM", p1_x, p1_y + 8, p1_w, "center")

    love.graphics.setFont(FontCache.get(8))
    local p1_height = 0
    if player and player.grid then
        for r = 21, 40 do
            for c = 1, 10 do
                if player.grid[r][c] ~= 0 then
                    p1_height = math.max(p1_height, 41 - r)
                end
            end
        end
    end
    love.graphics.setColor(t.secondary[1], t.secondary[2], t.secondary[3], 0.9)
    love.graphics.printf(string.format("HEIGHT: %d/20", p1_height), p1_x, p1_y + 26, p1_w, "center")

    local p1_garb = (player and player.garbage_queue and #player.garbage_queue) or 0
    love.graphics.setColor(0.85, 0.85, 0.90, 0.85)
    love.graphics.printf(string.format("GARBAGE: %d", p1_garb), p1_x, p1_y + 44, p1_w, "center")

    local stance_name = (player and player.current_stance == 1 and "RUSH") 
                     or (player and player.current_stance == 2 and "BASTION") 
                     or (player and player.current_stance == 3 and "RESONANCE") 
                     or "STANDARD"
    love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.95)
    love.graphics.printf("ST: " .. stance_name, p1_x, p1_y + 62, p1_w, "center")

    love.graphics.setColor(t.border)
    love.graphics.line(p1_x + 8, p1_y + 82, p1_x + p1_w - 8, p1_y + 82)

    love.graphics.setFont(FontCache.get(8))
    love.graphics.setColor(t.secondary[1], t.secondary[2], t.secondary[3], 0.85)
    love.graphics.printf("EVENT LOG", p1_x, p1_y + 88, p1_w, "center")

    local log_y = p1_y + 108
    local shown = 0
    for i = 1, MAX_EVENTS do
        local idx = ((buffer_head - 1 - i + MAX_EVENTS) % MAX_EVENTS) + 1
        local ev = events_buffer[idx]
        if ev and ev.active and (ev.category:match("P1") or ev.category == "MATCH") then
            love.graphics.setColor(0.85, 0.85, 0.90, 0.80)
            love.graphics.printf(ev.category:sub(1, 10), p1_x + 8, log_y, p1_w - 16, "left")
            love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.65)
            love.graphics.printf(string.format("T: %.1fs", ev.time), p1_x + 8, log_y + 11, p1_w - 16, "left")

            log_y = log_y + 26
            shown = shown + 1
            if shown >= 11 then break end
        end
    end

    -- ────────────────────────────────────────────────────────────────────────
    -- 2. TARJETA ALA DERECHA: BOT TELEMETRY (x: 1144..1260, y: 140..600)
    -- ────────────────────────────────────────────────────────────────────────
    local bot_x, bot_y, bot_w, bot_h = 1144, 140, 116, 460
    ThemeManager.drawPanel(bot_x, bot_y, bot_w, bot_h, "", false)

    love.graphics.setFont(FontCache.get(9))
    love.graphics.setColor(1.0, 0.25, 0.35, 0.95)
    love.graphics.printf("BOT TELEM", bot_x, bot_y + 8, bot_w, "center")

    local bot_height = 0
    if bot and bot.grid then
        for r = 21, 40 do
            for c = 1, 10 do
                if bot.grid[r][c] ~= 0 then
                    bot_height = math.max(bot_height, 41 - r)
                end
            end
        end
    end
    love.graphics.setFont(FontCache.get(8))
    love.graphics.setColor(t.secondary[1], t.secondary[2], t.secondary[3], 0.9)
    love.graphics.printf(string.format("HEIGHT: %d/20", bot_height), bot_x, bot_y + 26, bot_w, "center")

    local bot_garb = (bot and bot.garbage_queue and #bot.garbage_queue) or 0
    love.graphics.setColor(0.85, 0.85, 0.90, 0.85)
    love.graphics.printf(string.format("GARBAGE: %d", bot_garb), bot_x, bot_y + 44, bot_w, "center")

    local target_pps = (_G.AI_ADAPTIVE_PROFILE and _G.AI_ADAPTIVE_PROFILE.ai_target_pps) or 1.45
    love.graphics.setColor(1.0, 0.85, 0.2, 0.95)
    love.graphics.printf(string.format("AI: %.2f PPS", target_pps), bot_x, bot_y + 62, bot_w, "center")

    love.graphics.setColor(t.border)
    love.graphics.line(bot_x + 8, bot_y + 82, bot_x + bot_w - 8, bot_y + 82)

    love.graphics.setFont(FontCache.get(8))
    love.graphics.setColor(1.0, 0.25, 0.35, 0.85)
    love.graphics.printf("EVENT LOG", bot_x, bot_y + 88, bot_w, "center")

    local bot_log_y = bot_y + 108
    local bot_shown = 0
    for i = 1, MAX_EVENTS do
        local idx = ((buffer_head - 1 - i + MAX_EVENTS) % MAX_EVENTS) + 1
        local ev = events_buffer[idx]
        if ev and ev.active and (ev.category:match("BOT") or ev.category == "ANOMALY") then
            love.graphics.setColor(0.85, 0.80, 0.90, 0.80)
            love.graphics.printf(ev.category:sub(1, 10), bot_x + 8, bot_log_y, bot_w - 16, "left")
            love.graphics.setColor(1.0, 0.35, 0.45, 0.65)
            love.graphics.printf(string.format("T: %.1fs", ev.time), bot_x + 8, bot_log_y + 11, bot_w - 16, "left")

            bot_log_y = bot_log_y + 26
            bot_shown = bot_shown + 1
            if bot_shown >= 11 then break end
        end
    end

    -- ────────────────────────────────────────────────────────────────────────
    -- 3. BAHÍA CENTRAL: LIVE FLIGHT RECORDER (Contraste Atenuado al 65%)
    -- ────────────────────────────────────────────────────────────────────────
    if _G.GameState ~= "gameover" then
        local cr_x, cr_y, cr_w, cr_h = 480, 240, 320, 230
        ThemeManager.drawPanel(cr_x, cr_y, cr_w, cr_h, "", false)

        love.graphics.setFont(FontCache.get(9))
        love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.90)
        love.graphics.printf("LIVE FLIGHT RECORDER", cr_x, cr_y + 8, cr_w, "center")

        local ev_y = cr_y + 28
        local count = 0
        for i = 1, MAX_EVENTS do
            local idx = ((buffer_head - 1 - i + MAX_EVENTS) % MAX_EVENTS) + 1
            local ev = events_buffer[idx]
            if ev and ev.active then
                love.graphics.setFont(FontCache.get(8))
                love.graphics.setColor(t.secondary[1], t.secondary[2], t.secondary[3], 0.75)
                love.graphics.print(string.format("[%04.1fs] %-8s", ev.time, ev.category:sub(1, 8)), cr_x + 12, ev_y)

                love.graphics.setColor(0.85, 0.85, 0.90, 0.65)
                love.graphics.print("| " .. ev.action:sub(1, 24), cr_x + 105, ev_y)

                ev_y = ev_y + 17
                count = count + 1
                if count >= 11 then break end
            end
        end
    end

    love.graphics.pop()
end

function Blackbox.draw()
end

return Blackbox
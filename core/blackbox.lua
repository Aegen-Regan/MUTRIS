---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: BLACKBOX FLIGHT RECORDER & WIDESCREEN HUD (1280x720)
-- Arquitectura: Zero-GC / 128 Eventos / Zero-Overlap en 16:9
-- ============================================================================
local Blackbox = {}
local FontCache = require "tetris.font_cache"

local MAX_LOGS = 128
Blackbox.logs = {}
Blackbox.head = 1
Blackbox.total_events = 0
Blackbox.overlay_active = false

for i = 1, MAX_LOGS do
    Blackbox.logs[i] = {
        time = 0.0,
        tag = "IDLE",
        msg = "INIT",
        val1 = 0,
        val2 = 0
    }
end

function Blackbox.init()
    Blackbox.head = 1
    Blackbox.total_events = 0
    Blackbox.overlay_active = false
    Blackbox.log("SYSTEM", "BLACKBOX FLIGHT RECORDER ARMED", 0, 0)
end

function Blackbox.log(tag, msg, val1, val2)
    local slot = Blackbox.logs[Blackbox.head]
    slot.time = _G.RealMatchTimer or 0.0
    slot.tag = tag or "MISC"
    slot.msg = msg or ""
    slot.val1 = val1 or 0
    slot.val2 = val2 or 0

    Blackbox.head = (Blackbox.head % MAX_LOGS) + 1
    Blackbox.total_events = Blackbox.total_events + 1
end

function Blackbox.guardLoop(loop_name, max_iter, current_iter)
    if current_iter > max_iter then
        Blackbox.log("CRITICAL", "LOOP OVERFLOW: " .. loop_name, current_iter, max_iter)
        return false
    end
    return true
end

function Blackbox.dumpToFile(filepath, extra_header)
    local save_path = filepath or "saves/crash_report.txt"
    if not love.filesystem.getInfo("saves") then
        love.filesystem.createDirectory("saves")
    end

    local lines = {}
    table.insert(lines, "================================================================================")
    table.insert(lines, " MUTRIS ENGINE: FLIGHT RECORDER SNAPSHOT")
    table.insert(lines, " Version: " .. (_G.ENGINE_VERSION or "MUTRIS v1.0.0"))
    table.insert(lines, " Timer: " .. string.format("%.2f s", _G.RealMatchTimer or 0))
    table.insert(lines, " Memory: " .. string.format("%.2f KB", collectgarbage("count")))
    table.insert(lines, "================================================================================\n")

    if extra_header then
        table.insert(lines, "HEADER: " .. extra_header .. "\n")
    end

    table.insert(lines, "RECENT EVENTS:")
    table.insert(lines, "--------------------------------------------------------------------------------")

    local count = math.min(32, Blackbox.total_events)
    local start_idx = Blackbox.head - count
    if start_idx < 1 then start_idx = start_idx + MAX_LOGS end

    for i = 0, count - 1 do
        local idx = ((start_idx + i - 1) % MAX_LOGS) + 1
        local ev = Blackbox.logs[idx]
        table.insert(lines, string.format("[T+%.3fs] [%-10s] %-28s (V1: %d, V2: %d)", ev.time, ev.tag, ev.msg, ev.val1, ev.val2))
    end

    local full_text = table.concat(lines, "\n")
    love.filesystem.write(save_path, full_text)
    local local_file = io.open(save_path, "w")
    if local_file then
        local_file:write(full_text)
        local_file:close()
    end
end

-- 🖥️ HUD WIDESCREEN EN ALAS LATERALES Y CENTRO (1280x720)
function Blackbox.drawPermanentHUD(player, bot)
    love.graphics.push("all")

    -- 1. ALA LATERAL IZQUIERDA: P1 TELEMETRY (x: 20..120, y: 120..600)
    local lx, ly, lw, lh = 20, 120, 100, 480
    love.graphics.setColor(0.01, 0.02, 0.05, 0.88)
    love.graphics.rectangle("fill", lx, ly, lw, lh, 4)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0, 0.8, 1.0, 0.25)
    love.graphics.rectangle("line", lx, ly, lw, lh, 4)

    love.graphics.setFont(FontCache.get(10))
    love.graphics.setColor(0, 0.95, 1, 0.95)
    love.graphics.printf("P1 TELEM", lx, ly + 8, lw, "center")

    local p_peak = 40
    if player then
        for r = 21, 40 do
            for c = 1, 10 do
                if player.grid[r][c] ~= 0 then
                    p_peak = r
                    break
                end
            end
            if p_peak < 40 then break end
        end
    end

    local p_peak_h = 41 - p_peak
    love.graphics.setFont(FontCache.get(9))
    if p_peak_h >= 16 then love.graphics.setColor(1, 0.2, 0.3, 0.95)
    elseif p_peak_h >= 10 then love.graphics.setColor(1, 0.85, 0.2, 0.95)
    else love.graphics.setColor(0.2, 0.9, 0.5, 0.9) end
    love.graphics.printf(string.format("HEIGHT: %d/20", p_peak_h), lx, ly + 28, lw, "center")

    love.graphics.setColor(0.6, 0.75, 0.85, 0.85)
    local p_gq = (player and #player.garbage_queue) or 0
    love.graphics.printf(string.format("GARBAGE: %d", p_gq), lx, ly + 46, lw, "center")

    local p_st = (player and player.current_stance) or 2
    local st_names = {"RUSH", "BASTION", "RESON"}
    love.graphics.setColor(0.9, 0.5, 1, 0.90)
    love.graphics.printf("ST: " .. (st_names[p_st] or "STD"), lx, ly + 64, lw, "center")

    love.graphics.setColor(0, 0.6, 0.9, 0.3)
    love.graphics.line(lx + 6, ly + 82, lx + lw - 6, ly + 82)

    love.graphics.setColor(0.4, 0.85, 1, 0.8)
    love.graphics.printf("EVENT LOG", lx, ly + 88, lw, "center")

    local p_count = 0
    for i = 0, 47 do
        local idx = ((Blackbox.head - 1 - i - 1) % MAX_LOGS) + 1
        local ev = Blackbox.logs[idx]
        if ev and (ev.tag:find("P1") or ev.tag:find("MATCH") or ev.tag:find("TSPIN")) then
            love.graphics.setColor(0.7, 0.8, 0.9, 0.80 - p_count * 0.08)
            love.graphics.printf(ev.tag:sub(1, 8), lx + 4, ly + 106 + p_count * 30, lw - 8, "center")
            love.graphics.setColor(0.5, 0.6, 0.7, 0.65)
            love.graphics.printf(string.format("T: %.1fs", ev.time), lx + 4, ly + 118 + p_count * 30, lw - 8, "center")
            p_count = p_count + 1
            if p_count >= 11 then break end
        end
    end

    -- 2. ALA LATERAL DERECHA: BOT TELEMETRY (x: 1160..1260, y: 120..600)
    local rx, ry, rw, rh = 1160, 120, 100, 480
    love.graphics.setColor(0.01, 0.02, 0.05, 0.88)
    love.graphics.rectangle("fill", rx, ry, rw, rh, 4)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1.0, 0.3, 0.4, 0.25)
    love.graphics.rectangle("line", rx, ry, rw, rh, 4)

    love.graphics.setFont(FontCache.get(10))
    love.graphics.setColor(1, 0.35, 0.4, 0.95)
    love.graphics.printf("BOT TELEM", rx, ry + 8, rw, "center")

    local b_peak = 40
    if bot then
        for r = 21, 40 do
            for c = 1, 10 do
                if bot.grid[r][c] ~= 0 then
                    b_peak = r
                    break
                end
            end
            if b_peak < 40 then break end
        end
    end

    local b_peak_h = 41 - b_peak
    love.graphics.setFont(FontCache.get(9))
    if b_peak_h >= 16 then love.graphics.setColor(1, 0.2, 0.3, 0.95)
    elseif b_peak_h >= 10 then love.graphics.setColor(1, 0.85, 0.2, 0.95)
    else love.graphics.setColor(0.2, 0.9, 0.5, 0.9) end
    love.graphics.printf(string.format("HEIGHT: %d/20", b_peak_h), rx, ry + 28, rw, "center")

    love.graphics.setColor(0.6, 0.75, 0.85, 0.85)
    local b_gq = (bot and #bot.garbage_queue) or 0
    love.graphics.printf(string.format("GARBAGE: %d", b_gq), rx, ry + 46, rw, "center")

    local ai_pps_val = (bot and bot.ai and bot.ai.pps) or 1.45
    love.graphics.setColor(1, 0.85, 0.2, 0.85)
    love.graphics.printf(string.format("AI: %.2f PPS", ai_pps_val), rx, ry + 64, rw, "center")

    love.graphics.setColor(1, 0.3, 0.4, 0.3)
    love.graphics.line(rx + 6, ry + 82, rx + rw - 6, ry + 82)

    love.graphics.setColor(1, 0.4, 0.5, 0.8)
    love.graphics.printf("EVENT LOG", rx, ry + 88, rw, "center")

    local b_count = 0
    for i = 0, 47 do
        local idx = ((Blackbox.head - 1 - i - 1) % MAX_LOGS) + 1
        local ev = Blackbox.logs[idx]
        if ev and (ev.tag:find("BOT") or ev.tag:find("PARRY") or ev.tag:find("ANOMALY")) then
            love.graphics.setColor(0.9, 0.7, 0.8, 0.80 - b_count * 0.08)
            love.graphics.printf(ev.tag:sub(1, 8), rx + 4, ly + 106 + b_count * 30, rw - 8, "center")
            love.graphics.setColor(0.6, 0.5, 0.6, 0.65)
            love.graphics.printf(string.format("T: %.1fs", ev.time), rx + 4, ly + 118 + b_count * 30, rw - 8, "center")
            b_count = b_count + 1
            if b_count >= 11 then break end
        end
    end

    -- 3. HUECO CENTRAL: LIVE FLIGHT RECORDER (x: 480..800, y: 230..470)
    local cx, cy, cw, ch = 480, 230, 320, 240
    love.graphics.setColor(0.01, 0.02, 0.04, 0.88)
    love.graphics.rectangle("fill", cx, cy, cw, ch, 4)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0, 0.7, 1.0, 0.25)
    love.graphics.rectangle("line", cx, cy, cw, ch, 4)

    love.graphics.setFont(FontCache.get(9))
    love.graphics.setColor(0.2, 0.95, 0.6, 0.95)
    love.graphics.printf("LIVE FLIGHT RECORDER", cx, cy + 6, cw, "center")
    love.graphics.setColor(0, 0.7, 1, 0.2)
    love.graphics.line(cx + 8, cy + 20, cx + cw - 8, cy + 20)

    local count = math.min(10, Blackbox.total_events)
    local start_idx = Blackbox.head - count
    if start_idx < 1 then start_idx = start_idx + MAX_LOGS end

    for i = 0, count - 1 do
        local idx = ((start_idx + i - 1) % MAX_LOGS) + 1
        local ev = Blackbox.logs[idx]
        local y_pos = cy + 26 + i * 20

        if ev.tag:find("DEATH") or ev.tag:find("CRIT") then
            love.graphics.setColor(1.0, 0.2, 0.3, 0.95)
        elseif ev.tag:find("TSPIN") or ev.tag:find("PARRY") then
            love.graphics.setColor(0.9, 0.2, 1.0, 0.95)
        elseif ev.tag:find("BOT") then
            love.graphics.setColor(1.0, 0.5, 0.6, 0.85)
        elseif ev.tag:find("P1") then
            love.graphics.setColor(0.2, 0.9, 1.0, 0.85)
        else
            love.graphics.setColor(0.7, 0.8, 0.9, 0.80)
        end

        local line1 = string.format("[%.1fs] %-12s | %s", ev.time, ev.tag:sub(1, 12), ev.msg:sub(1, 24))
        love.graphics.setFont(FontCache.get(8))
        love.graphics.print(line1, cx + 10, y_pos)
    end

    love.graphics.pop()
end

return Blackbox
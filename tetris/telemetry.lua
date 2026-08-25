-- ================================================================
-- FILE: tetris/telemetry.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: CENTRAL TELEMETRY CARD & MULTI-BOT DASHBOARD (1280x720)
-- Zero-GC / Dynamic Horizontal Centering / Multi-Grid Telemetry
-- ============================================================================
local Telemetry = {}
local FontCache    = require "tetris.font_cache"
local ThemeManager = require "tetris.theme_manager"

function Telemetry.draw(player, bot, center_x, is_boss_mode)
    love.graphics.push("all")
    local t = ThemeManager.getCurrent()
    local energy = _G.TrackEnergyPunch or 0
    local pw, ph = is_boss_mode and 260 or 300, 115
    local cx = center_x or 640
    local px = cx - (pw / 2)
    local py = 485
    
    ThemeManager.drawPanel(px, py, pw, ph, "", false)

    love.graphics.setFont(FontCache.get(10))
    love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.95)
    love.graphics.print(_G.ENGINE_VERSION or "MUTRIS v1.0.0", px + 8, py + 8)

    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.print(string.format("TIME: %05.1fs", _G.RealMatchTimer or 0), px + (is_boss_mode and 130 or 155), py + 8)
    love.graphics.print(string.format("%3d FPS", love.timer.getFPS()), px + (is_boss_mode and 215 or 248), py + 8)

    love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.15)
    love.graphics.rectangle("fill", px + 8, py + 26, pw - 16, 4, 1)
    love.graphics.setColor(t.secondary[1], t.secondary[2], t.secondary[3], 0.90)
    love.graphics.rectangle("fill", px + 8, py + 26, (pw - 16) * energy, 4, 1)

    if player and bot then
        love.graphics.setFont(FontCache.get(11))
        love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.95)
        love.graphics.print(string.format("P1:  %.2f PPS", player.current_pps_display or 0), px + 8, py + 38)
        
        love.graphics.setColor(1.0, 0.35, 0.4, 0.95)
        love.graphics.print(string.format("BOT: %.2f PPS", bot.current_pps_display or 0), px + (is_boss_mode and 130 or 155), py + 38)
    end

    local prof = _G.AI_ADAPTIVE_PROFILE
    if prof and _G.CURRENT_GAME_MODE == "versus" then
        love.graphics.setFont(FontCache.get(10))
        local target_pps = prof.ai_target_pps or 1.45
        
        if target_pps >= 2.5 then love.graphics.setColor(1.0, 0.25, 0.35, 0.95)
        elseif target_pps >= 1.6 then love.graphics.setColor(1.0, 0.85, 0.2, 0.95)
        else love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.95) end
        
        love.graphics.print(string.format("AI TARGET: %.2f PPS", target_pps), px + 8, py + 68)

        love.graphics.setColor(0.7, 0.80, 0.90, 0.85)
        love.graphics.print(string.format("RECORD: %d-%d (AVG P1: %.2f)", prof.player_wins or 0, prof.bot_wins or 0, prof.player_avg_pps or 1.0), px + 8, py + 88)
    end

    love.graphics.pop()
end

function Telemetry.drawMultiBot(boards)
    if not boards or #boards == 0 then return end
    love.graphics.push("all")
    local t = ThemeManager.getCurrent()
    local energy = _G.TrackEnergyPunch or 0

    local bx, by, bw, bh = 80, 530, 1120, 75
    ThemeManager.drawPanel(bx, by, bw, bh, "", false)

    love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.15)
    love.graphics.rectangle("fill", bx + 12, by + 10, bw - 24, 3, 1)
    love.graphics.setColor(t.secondary[1], t.secondary[2], t.secondary[3], 0.90)
    love.graphics.rectangle("fill", bx + 12, by + 10, (bw - 24) * energy, 3, 1)

    love.graphics.setFont(FontCache.get(10))
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.print(string.format("TIME: %05.1fs   |   %3d FPS", _G.RealMatchTimer or 0, love.timer.getFPS()), bx + 16, by + 18)

    local colors = {
        {0.1, 0.95, 0.55},
        {1.0, 0.85, 0.20},
        {1.0, 0.25, 0.35}
    }

    for i = 1, math.min(3, #boards) do
        local b = boards[i]
        local cx = bx + 16 + (i - 1) * 370
        local clr = colors[i] or {1, 1, 1}
        local label = (b.player_type == "human") and "PLAYER 1 (YOU)" or string.format("AI BOT 0%d", i - 1)
        local pps = b.current_pps_display or 0.0
        local lines = b.lines_cleared or 0

        love.graphics.setFont(FontCache.get(10))
        love.graphics.setColor(clr[1], clr[2], clr[3], 0.98)
        love.graphics.print(label, cx, by + 38)

        love.graphics.setFont(FontCache.get(11))
        love.graphics.setColor(1, 1, 1, 0.95)
        love.graphics.print(string.format("%.2f PPS", pps), cx + 130, by + 37)

        love.graphics.setFont(FontCache.get(9))
        love.graphics.setColor(0.7, 0.8, 0.9, 0.75)
        love.graphics.print(string.format("%d LINES", lines), cx + 220, by + 38)
    end

    love.graphics.pop()
end

return Telemetry
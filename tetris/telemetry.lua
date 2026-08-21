-- ================================================================
-- FILE: tetris/telemetry.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: CENTRAL TELEMETRY CARD (1280x720 WIDESCREEN)
-- ============================================================================
local Telemetry = {}
local FontCache    = require "tetris.font_cache"
local ThemeManager = require "tetris.theme_manager"

function Telemetry.draw(player, bot)
    love.graphics.push("all")
    local t = ThemeManager.getCurrent()
    local energy = _G.TrackEnergyPunch or 0
    local px, py = 480, 485
    local pw, ph = 320, 115
    
    ThemeManager.drawPanel(px, py, pw, ph, "", false)

    -- Encabezado y Reloj Monospace
    love.graphics.setFont(FontCache.get(10))
    love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.95)
    love.graphics.print(_G.ENGINE_VERSION or "MUTRIS v1.0.0", px + 12, py + 8)

    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.print(string.format("TIME: %05.1fs", _G.RealMatchTimer or 0), px + 168, py + 8)
    love.graphics.print(string.format("%3d FPS", love.timer.getFPS()), px + 264, py + 8)

    -- Barra de Adrenalina Musical (The Punch)
    love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.15)
    love.graphics.rectangle("fill", px + 12, py + 26, 296, 4, 1)
    love.graphics.setColor(t.secondary[1], t.secondary[2], t.secondary[3], 0.90)
    love.graphics.rectangle("fill", px + 12, py + 26, 296 * energy, 4, 1)

    -- PPS en Vivo
    if player and bot then
        love.graphics.setFont(FontCache.get(12))
        love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.95)
        love.graphics.print(string.format("P1:  %.2f PPS", player.current_pps_display or 0), px + 12, py + 38)
        
        love.graphics.setColor(1.0, 0.35, 0.4, 0.95)
        love.graphics.print(string.format("BOT: %.2f PPS", bot.current_pps_display or 0), px + 168, py + 38)
    end

    -- Monitor DDA ARCHON
    local prof = _G.AI_ADAPTIVE_PROFILE
    if prof and _G.CURRENT_GAME_MODE == "versus" then
        love.graphics.setFont(FontCache.get(10))
        local target_pps = prof.ai_target_pps or 1.45
        
        if target_pps >= 2.5 then love.graphics.setColor(1.0, 0.25, 0.35, 0.95)
        elseif target_pps >= 1.6 then love.graphics.setColor(1.0, 0.85, 0.2, 0.95)
        else love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.95) end
        
        love.graphics.print(string.format("AI TARGET: %.2f PPS", target_pps), px + 12, py + 68)

        love.graphics.setColor(0.7, 0.80, 0.90, 0.85)
        love.graphics.print(string.format("RECORD: %d-%d (AVG P1: %.2f)", prof.player_wins or 0, prof.bot_wins or 0, prof.player_avg_pps or 1.0), px + 12, py + 88)
    end

    love.graphics.pop()
end

return Telemetry
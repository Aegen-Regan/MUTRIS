---@diagnostic disable: undefined-global
local Telemetry = {}
local FontCache = require "tetris.font_cache"

function Telemetry.draw(player, bot)
    love.graphics.push("all")
    local energy = _G.TrackEnergyPunch or 0
    local px, py = 290, 526
    local pw, ph = 220, 64
    
    -- Panel translúcido central
    love.graphics.setColor(0.01, 0.02, 0.04, 0.85)
    love.graphics.rectangle("fill", px, py, pw, ph, 4)
    love.graphics.setColor(0, 0.7, 1, 0.25 + energy * 0.35)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", px, py, pw, ph, 4)

    -- Encabezado: Versión y Tiempo
    love.graphics.setFont(FontCache.get(9))
    love.graphics.setColor(0.4, 0.85, 1.0, 0.9)
    love.graphics.print(_G.ENGINE_VERSION or "MUTRIS v1.0.0", px + 8, py + 4)

    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print(string.format("T: %.1fs", _G.RealMatchTimer or 0), px + 124, py + 4)
    love.graphics.print(string.format("%d FPS", love.timer.getFPS()), px + 172, py + 4)

    -- Barra de Adrenalina Musical
    love.graphics.setColor(0, 0.8, 1, 0.12)
    love.graphics.rectangle("fill", px + 8, py + 18, 204, 3, 1)
    love.graphics.setColor(0, 0.85, 1, 0.85)
    love.graphics.rectangle("fill", px + 8, py + 18, 204 * energy, 3, 1)

    -- Lectura de Velocidad PPS en Vivo
    if player and bot then
        love.graphics.setFont(FontCache.get(10))
        love.graphics.setColor(0.2, 0.95, 1.0, 0.95)
        love.graphics.print(string.format("P1: %.1f PPS", player.current_pps_display or 0), px + 8, py + 25)
        
        love.graphics.setColor(1.0, 0.35, 0.4, 0.95)
        love.graphics.print(string.format("AI LIVE: %.1f", bot.current_pps_display or 0), px + 120, py + 25)
    end

    -- 🎯 MONITOR DE DIFICULTAD ADAPTATIVA (Lee ai_profile.json en tiempo real)
    local prof = _G.AI_ADAPTIVE_PROFILE
    if prof and _G.CURRENT_GAME_MODE == "versus" then
        love.graphics.setFont(FontCache.get(9))
        local target_pps = prof.ai_target_pps or 1.45
        
        if target_pps >= 2.5 then love.graphics.setColor(1.0, 0.25, 0.35, 0.95)
        elseif target_pps >= 1.6 then love.graphics.setColor(1.0, 0.85, 0.2, 0.95)
        else love.graphics.setColor(0.1, 0.95, 0.7, 0.95) end
        
        love.graphics.print(string.format("AI BASE: %.2f PPS", target_pps), px + 8, py + 44)

        love.graphics.setColor(0.6, 0.75, 0.85, 0.8)
        love.graphics.print(string.format("W/L: %d-%d (P1: %.2f)", prof.player_wins or 0, prof.bot_wins or 0, prof.player_avg_pps or 1.0), px + 105, py + 44)
    end

    love.graphics.pop()
end

return Telemetry
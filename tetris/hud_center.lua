---@diagnostic disable: undefined-global
local HUDCenter = {}
local FontCache = require "tetris.font_cache"

function HUDCenter.draw(player, bot)
    love.graphics.push("all")
    local active_punch = _G.TrackEnergyPunch or 0
    local pulse = _G.AudioBeatPulse or 0
    local scale = 1 + pulse * (0.04 + active_punch * 0.03)
    
    love.graphics.translate(400, 260)
    love.graphics.scale(scale, scale)

    -- Placa central oscura con borde neón traslúcido para aislar del fondo
    love.graphics.setColor(0.01, 0.02, 0.05, 0.85)
    love.graphics.rectangle("fill", -52, -18, 104, 36, 6)
    love.graphics.setLineWidth(1.5)
    love.graphics.setColor(0, 0.7, 1, 0.25 + pulse * 0.2)
    love.graphics.rectangle("line", -52, -18, 104, 36, 6)

    -- Separador VS Neón
    love.graphics.setFont(FontCache.get(10))
    love.graphics.setColor(1, 1, 1, 0.4 + pulse * 0.4)
    love.graphics.printf("VS", -15, -6, 30, "center")

    -- Marcador Humano (P1 - Cian / Alerta Roja)
    local p1_val = (player and player.current_pps_display) or 0
    local bot_val = (bot and bot.current_pps_display) or 0
    local p1_better = p1_val >= bot_val

    love.graphics.setFont(FontCache.get(12))
    if p1_better then
        love.graphics.setColor(0, 0.95, 1, 0.95)
    else
        love.graphics.setColor(1, 0.35, 0.35, 0.85)
    end
    love.graphics.printf(string.format("%.1f", p1_val), -48, -7, 32, "center")

    -- Marcador Bot (AI - Alerta Roja / Verde / Violeta)
    local bot_better = bot_val > p1_val
    if bot_better then
        love.graphics.setColor(1, 0.25, 0.3, 0.95)
    else
        love.graphics.setColor(0.5, 0.6, 0.75, 0.8)
    end
    love.graphics.printf(string.format("%.1f", bot_val), 16, -7, 32, "center")

    -- Subtítulo PPS
    love.graphics.setFont(FontCache.get(8))
    love.graphics.setColor(0.5, 0.6, 0.7, 0.6)
    love.graphics.printf("PPS", -20, 9, 40, "center")

    love.graphics.pop()
end

return HUDCenter
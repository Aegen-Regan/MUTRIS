---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: CENTER VS BADGE & PPS COMPARATOR (1280x720 WIDESCREEN)
-- ============================================================================
local HUDCenter = {}
local FontCache = require "tetris.font_cache"

function HUDCenter.draw(player, bot)
    love.graphics.push("all")
    local active_punch = _G.TrackEnergyPunch or 0
    local pulse = _G.AudioBeatPulse or 0
    local scale = 1 + pulse * (0.04 + active_punch * 0.03)
    
    -- Centrado milimétrico en el eje central de 1280px (x = 640, y = 145)
    love.graphics.translate(640, 145)
    love.graphics.scale(scale, scale)

    -- Placa central con marco neón
    love.graphics.setColor(0.01, 0.02, 0.05, 0.88)
    love.graphics.rectangle("fill", -54, -20, 108, 40, 6)
    love.graphics.setLineWidth(1.5)
    love.graphics.setColor(0, 0.7, 1, 0.30 + pulse * 0.25)
    love.graphics.rectangle("line", -54, -20, 108, 40, 6)

    -- Divisor VS
    love.graphics.setFont(FontCache.get(10))
    love.graphics.setColor(1, 1, 1, 0.45 + pulse * 0.4)
    love.graphics.printf("VS", -15, -7, 30, "center")

    -- Marcador P1
    local p1_val = (player and player.current_pps_display) or 0.0
    local bot_val = (bot and bot.current_pps_display) or 0.0
    local p1_better = p1_val >= bot_val

    love.graphics.setFont(FontCache.get(13))
    if p1_better then
        love.graphics.setColor(0, 0.95, 1, 0.95)
    else
        love.graphics.setColor(1, 0.35, 0.35, 0.85)
    end
    love.graphics.printf(string.format("%.1f", p1_val), -50, -8, 34, "center")

    -- Marcador Bot
    local bot_better = bot_val > p1_val
    if bot_better then
        love.graphics.setColor(1, 0.25, 0.3, 0.95)
    else
        love.graphics.setColor(0.5, 0.6, 0.75, 0.8)
    end
    love.graphics.printf(string.format("%.1f", bot_val), 16, -8, 34, "center")

    love.graphics.setFont(FontCache.get(8))
    love.graphics.setColor(0.5, 0.6, 0.7, 0.65)
    love.graphics.printf("PPS", -20, 10, 40, "center")

    love.graphics.pop()
end

return HUDCenter
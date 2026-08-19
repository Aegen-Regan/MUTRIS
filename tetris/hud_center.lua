local HUDCenter = {}

function HUDCenter.draw(player, bot)
    love.graphics.push("all")
    local active_punch = _G.TrackEnergyPunch or 0
    local scale = 1 + (_G.AudioBeatPulse or 0) * (0.04 + active_punch * 0.03)
    
    love.graphics.translate(400, 260)
    love.graphics.scale(scale, scale)
    love.graphics.setFont(love.graphics.newFont(10))

    -- Marcador Humano (Cian / Alerta Roja)
    local p1_better = (player.current_pps_display or 0) >= (bot.current_pps_display or 0)
    love.graphics.setColor(p1_better and {0, 0.9, 1, 0.9} or {1, 0.2, 0.2, 0.5})
    love.graphics.printf(string.format("%.1f", player.current_pps_display or 0), -50, -15, 45, "right")

    -- Separador VS
    love.graphics.setColor(1, 1, 1, 0.15 + (_G.AudioBeatPulse or 0) * 0.25)
    love.graphics.printf("VS", -20, -7, 40, "center")

    -- Marcador Bot (Alerta Roja / Gris)
    local bot_better = (bot.current_pps_display or 0) > (player.current_pps_display or 0)
    love.graphics.setColor(bot_better and {1, 0.2, 0.2, 0.9} or {0.5, 0.5, 0.6, 0.5})
    love.graphics.printf(string.format("%.1f", bot.current_pps_display or 0), 5, -15, 45, "left")
    love.graphics.pop()
end

return HUDCenter

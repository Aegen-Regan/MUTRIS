local Telemetry = {}

local VERSION_TAG = "MUTRIS v0.8.5 - ETHEREAL"

function Telemetry.draw(player, bot)
    love.graphics.push("all")
    local energy = _G.TrackEnergyPunch or 0
    local pulse = _G.AudioBeatPulse or 0
    
    -- MOVIDO AL PASILLO CENTRAL (Horizontal shift)
    local panel_x, panel_y = 280, 520 
    
    -- Fondo Neón
    love.graphics.setColor(0, 0.02, 0.05, 0.88)
    love.graphics.rectangle("fill", panel_x, panel_y, 240, 72, 4)
    love.graphics.setLineWidth(1 + pulse)
    love.graphics.setColor(0, 0.6, 1, 0.3 + energy * 0.4)
    love.graphics.rectangle("line", panel_x, panel_y, 240, 72, 4)

    love.graphics.setFont(love.graphics.newFont(10))
    
    -- Stats
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print(string.format("TIME: %.1fs", _G.RealMatchTimer or 0), panel_x + 10, panel_y + 8)
    love.graphics.setColor(0, 0.8, 1, 0.8)
    love.graphics.print(string.format("FPS: %d", love.timer.getFPS()), panel_x + 160, panel_y + 8)

    -- Barra Adrenalina
    love.graphics.setColor(1, 1, 1, 0.4)
    love.graphics.print("PUNCH:", panel_x + 10, panel_y + 24)
    love.graphics.rectangle("fill", panel_x + 65, panel_y + 28, 160, 4)
    love.graphics.setColor(0, 0.8, 1, 0.9)
    love.graphics.rectangle("fill", panel_x + 65, panel_y + 28, 160 * energy, 4)

    if player and bot then
        love.graphics.setColor(0.5, 0.9, 1, 0.8)
        love.graphics.print(string.format("P1: %.1f PPS", player.current_pps_display or 0), panel_x + 10, panel_y + 40)
        love.graphics.setColor(1, 0.3, 0.3, 0.8)
        love.graphics.print(string.format("AI: %.1f PPS", bot.current_pps_display or 0), panel_x + 130, panel_y + 40)
    end

    love.graphics.setFont(love.graphics.newFont(9))
    love.graphics.setColor(1, 0.8, 0, 0.5 + pulse * 0.5)
    love.graphics.printf(VERSION_TAG, panel_x, panel_y + 58, 240, "center")
    
    love.graphics.pop()
end

return Telemetry
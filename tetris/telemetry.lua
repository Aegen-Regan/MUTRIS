---@diagnostic disable: undefined-global
local Telemetry = {}
local FontCache = require "tetris.font_cache"

function Telemetry.draw(player, bot)
    love.graphics.push("all")
    local energy, pulse = _G.TrackEnergyPunch or 0, _G.AudioBeatPulse or 0
    local px, py = 310, 540
    
    love.graphics.setColor(0, 0, 0, 0.65)
    love.graphics.rectangle("fill", px, py, 180, 46, 4)
    love.graphics.setColor(0, 0.6, 1, 0.2 + energy * 0.3)
    love.graphics.rectangle("line", px, py, 180, 46, 4)

    love.graphics.setFont(FontCache.get(8))
    love.graphics.setColor(0.5, 0.8, 1, 0.8)
    love.graphics.print(_G.ENGINE_VERSION or "MUTRIS v0.9.0", px + 8, py + 4)

    love.graphics.setFont(FontCache.get(9))
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.print(string.format("T: %.1fs", _G.RealMatchTimer or 0), px + 100, py + 4)
    love.graphics.print(string.format("FPS: %d", love.timer.getFPS()), px + 140, py + 4)

    -- Barra de Adrenalina
    love.graphics.setColor(0, 0.8, 1, 0.1)
    love.graphics.rectangle("fill", px + 8, py + 18, 164, 2)
    love.graphics.setColor(0, 0.8, 1, 0.8)
    love.graphics.rectangle("fill", px + 8, py + 18, 164 * energy, 2)

    if player and bot then
        love.graphics.setColor(0.5, 0.9, 1, 0.8)
        love.graphics.print(string.format("P1: %.1f PPS", player.current_pps_display or 0), px + 8, py + 26)
        love.graphics.setColor(1, 0.3, 0.3, 0.8)
        love.graphics.print(string.format("AI: %.1f PPS", bot.current_pps_display or 0), px + 112, py + 26)
    end
    love.graphics.pop()
end

return Telemetry
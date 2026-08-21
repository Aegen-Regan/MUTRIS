-- ================================================================
-- FILE: tetris/shaker.lua
-- ================================================================
local Shaker = {}

function Shaker.update(board, dt)
    if board.shake_time and board.shake_time > 0 then 
        board.shake_time = board.shake_time - dt 
    end
end

function Shaker.apply(board)
    local SettingsManager = require "settings_manager"
    local shake_mult = SettingsManager.get("screen_shake") or 1.0
    if shake_mult > 1.0 then shake_mult = shake_mult / 100.0 end
    if shake_mult <= 0.01 then return end

    local energy = _G.TrackEnergyPunch or 0
    local pulse = _G.AudioBeatPulse or 0
    
    local sx, sy = 0, 0
    
    -- Sacudida por eventos (Lock/Lines)
    if board.shake_time and board.shake_time > 0 then
        sx = math.random(-board.shake_mag, board.shake_mag)
        sy = math.random(-board.shake_mag, board.shake_mag)
    end
    
    -- Vibración por Beat (Punch!)
    if energy > 0.8 and pulse > 0.7 then
        local vibe = (energy - 0.7) * 8
        sx = sx + math.random(-vibe, vibe)
        sy = sy + math.random(-vibe, vibe)
    end
    
    love.graphics.translate(sx * shake_mult, sy * shake_mult)
end

return Shaker
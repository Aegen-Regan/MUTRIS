local Shaker = {}

function Shaker.update(board, dt)
    if board.shake_time and board.shake_time > 0 then 
        board.shake_time = board.shake_time - dt 
    end
end

function Shaker.apply(board)
    local active_punch = _G.TrackEnergyPunch or 0
    
    -- Impacto inmediato por romper bloques en el juego (siempre activo)
    local shake_x = (board.shake_time and board.shake_time > 0) and math.random(-board.shake_mag, board.shake_mag) or 0
    
    -- TIER DE TEMBLOR RÍTMICO LATERAL (Desbloquea RECIÉN arriba del 85% de energía)
    if active_punch >= 0.85 and _G.AudioBeatPulse and _G.AudioBeatPulse > 0.5 then
        -- Entra en la fase crítica pre-drop: el sismo despierta de golpe de forma violenta
        local tier_factor = (active_punch - 0.85) / 0.15
        local pulse_intensity = 6.0 * tier_factor
        shake_x = shake_x + math.random(-pulse_intensity, pulse_intensity)
    end
    
    love.graphics.translate(shake_x, 0)
end

return Shaker

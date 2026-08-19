local Telemetry = {}

function Telemetry.draw(player, bot)
    love.graphics.push("all")
    love.graphics.setFont(love.graphics.newFont(10))
    
    -- 1. UBICACIÓN ESTRATÉGICA EN LA BASE INFERIOR IZQUIERDA (Zona muerta)
    local panel_x = 10
    local panel_y = 540 -- Se desplaza al sótano de la pantalla (debajo de la línea base)
    
    -- Fondo tipo consola súper ultra compacto
    love.graphics.setColor(0, 0, 0, 0.82)
    love.graphics.rectangle("fill", panel_x, panel_y, 235, 52, 4)
    love.graphics.setColor(0, 0.8, 1, 0.25)
    love.graphics.rectangle("line", panel_x, panel_y, 235, 52, 4)
    
    local match_time = _G.RealMatchTimer or 0
    local energy = (_G.TrackEnergyPunch or 0) * 100
    local fps = love.timer.getFPS()
    
    -- 2. RENDER DE DIAGNÓSTICO EN DOS COLUMNAS ULTRA COMPRIMIDAS
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.print(string.format("TIME: %.1fs  |  %d FPS", match_time, fps), panel_x + 10, panel_y + 6)
    
    if energy >= 95 then
        love.graphics.setColor(1, 0.2, 0.2, 1)
        love.graphics.print(string.format("PUNCH: %.1f%% [DROP]", energy), panel_x + 115, panel_y + 6)
    else
        love.graphics.setColor(0, 0.8, 1, 0.75)
        love.graphics.print(string.format("PUNCH: %.1f%%", energy), panel_x + 115, panel_y + 6)
    end
    
    -- Separador interno minimalista
    love.graphics.setColor(1, 1, 1, 0.08)
    love.graphics.line(panel_x + 10, panel_y + 19, panel_x + 225, panel_y + 19)
    
    -- 3. HISTORIAL CLÍNICO DE COMBATE COMPACTADO
    if player and bot then
        local p_hgt, b_hgt = 0, 0
        if player.grid then
            for r = 21, 40 do for c = 1, 10 do if player.grid[r][c] ~= 0 then p_hgt = math.max(p_hgt, 41 - r) end end end
        end
        if bot.grid then
            for r = 21, 40 do for c = 1, 10 do if bot.grid[r][c] ~= 0 then b_hgt = math.max(b_hgt, 41 - r) end end end
        end

        -- Métricas en una sola línea ultra-scannable
        love.graphics.setColor(0.8, 0.9, 1, 0.8)
        love.graphics.print(string.format("P1 HGT: %-2d  |  SPEED: %.1f PPS", p_hgt, player.current_pps_display or 0), panel_x + 10, panel_y + 24)
        
        love.graphics.setColor(1, 0.4, 0.4, 0.8)
        love.graphics.print(string.format("AI HGT: %-2d  |  SPEED: %.1f PPS", b_hgt, bot.current_pps_display or 0), panel_x + 10, panel_y + 36)
    else
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print("WAITING SYNC LINK...", panel_x + 10, panel_y + 24)
    end
    
    love.graphics.pop()
end

return Telemetry

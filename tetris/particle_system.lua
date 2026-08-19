local ParticleSystem = {}

function ParticleSystem.init(board)
    board.particles = {}
    -- Pool estático de 120 partículas reutilizables (Zero-GC compliant)
    for i = 1, 120 do
        board.particles[i] = { active = false, x = 0, y = 0, vx = 0, vy = 0, life = 0, max_life = 0, r = 1, g = 1, b = 1 }
    end
    board.particle_head = 1
end

function ParticleSystem.spawnLineBlast(board, row_index, color_id)
    local clr = board.colors[color_id] or {1, 1, 1}
    local y_pos = board.y + (row_index - 21) * 24 + 12
    
    -- Dispara 12 chispas láser horizontales a lo largo de la línea eliminada
    for c = 1, 10 do
        local x_pos = board.x + (c - 1) * 24 + 12
        local p = board.particles[board.particle_head]
        
        p.active = true
        p.x, p.y = x_pos, y_pos
        p.vx = math.random(-150, 150)
        p.vy = math.random(-60, 40)
        p.life = 0.4
        p.max_life = 0.4
        p.r, p.g, p.b = clr[1], clr[2], clr[3]
        
        board.particle_head = (board.particle_head % 120) + 1
    end
end

function ParticleSystem.update(board, dt)
    for i = 1, 120 do
        local p = board.particles[i]
        if p.active then
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.vy = p.vy + 200 * dt -- Gravedad leve hacia abajo
            p.life = p.life - dt
            if p.life <= 0 then p.active = false end
        end
    end
end

function ParticleSystem.draw(board)
    love.graphics.push("all")
    for i = 1, 120 do
        local p = board.particles[i]
        if p.active then
            local alpha = p.life / p.max_life
            local pulse = _G.AudioBeatPulse or 0
            -- Las chispas ganan tamaño e iluminación neón con el punch de la música
            local size = (2 + pulse * 2) * (alpha * 1.5)
            
            love.graphics.setColor(p.r, p.g, p.b, alpha * 0.8)
            love.graphics.rectangle("fill", p.x - size/2, p.y - size/2, size, size)
            love.graphics.setColor(1, 1, 1, alpha * 0.4)
            love.graphics.rectangle("fill", p.x - size/4, p.y - size/4, size/2, size/2)
        end
    end
    love.graphics.pop()
end -- <-- ESTE 'END' CIERRA LA FUNCIÓN ParticleSystem.draw

return ParticleSystem -- <-- ESTE CIERRA EL MÓDULO ENTERO
---@diagnostic disable: undefined-global
local ParticleSystem = {}

function ParticleSystem.init(board)
    board.particles = {}
    -- Pool estático de 200 partículas reutilizables (Zero-GC compliant)
    for i = 1, 200 do
        board.particles[i] = { 
            active = false, x = 0, y = 0, 
            vx = 0, vy = 0, life = 0, max_life = 0, 
            r = 1, g = 1, b = 1, size = 3 
        }
    end
    board.particle_head = 1
end

function ParticleSystem.spawnLineBlast(board, row_index, color_id)
    local clr = board.colors[color_id] or {1, 1, 1}
    local y_pos = board.y + (row_index - 21) * 24 + 12
    
    for c = 1, 10 do
        local x_pos = board.x + (c - 1) * 24 + 12
        local p = board.particles[board.particle_head]
        
        p.active = true
        p.x, p.y = x_pos, y_pos
        p.vx = math.random(-160, 160)
        p.vy = math.random(-70, 50)
        p.life = 0.4
        p.max_life = 0.4
        p.r, p.g, p.b = clr[1], clr[2], clr[3]
        p.size = 3
        
        board.particle_head = (board.particle_head % 200) + 1
    end
end

function ParticleSystem.spawnSupernova(board, color)
    local clr = color or {1.0, 0.85, 0.2}
    local center_x = board.x + 120
    local center_y = board.y + 240

    for i = 1, 60 do
        local p = board.particles[board.particle_head]
        local angle = math.random() * math.pi * 2
        local speed = math.random(120, 380)

        p.active = true
        p.x = center_x + math.cos(angle) * math.random(0, 40)
        p.y = center_y + math.sin(angle) * math.random(0, 40)
        p.vx = math.cos(angle) * speed
        p.vy = math.sin(angle) * speed
        p.life = 0.85
        p.max_life = 0.85
        p.r, p.g, p.b = clr[1], clr[2], clr[3]
        p.size = math.random(3, 6)

        board.particle_head = (board.particle_head % 200) + 1
    end
end

function ParticleSystem.update(board, dt)
    for i = 1, 200 do
        local p = board.particles[i]
        if p.active then
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.vy = p.vy + 180 * dt
            p.life = p.life - dt
            if p.life <= 0 then p.active = false end
        end
    end
end

function ParticleSystem.draw(board)
    love.graphics.push("all")
    for i = 1, 200 do
        local p = board.particles[i]
        if p.active then
            local alpha = p.life / p.max_life
            local pulse = _G.AudioBeatPulse or 0
            local size = (p.size + pulse * 1.5) * (alpha * 1.3)
            
            love.graphics.setColor(p.r, p.g, p.b, alpha * 0.85)
            love.graphics.rectangle("fill", p.x - size/2, p.y - size/2, size, size, 1)
            love.graphics.setColor(1, 1, 1, alpha * 0.5)
            love.graphics.rectangle("fill", p.x - size/4, p.y - size/4, size/2, size/2)
        end
    end
    love.graphics.pop()
end

return ParticleSystem
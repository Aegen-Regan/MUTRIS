-- ================================================================
-- FILE: tetris/particle_system.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: THEMED LINE CLEAR & SPARK PARTICLE ENGINE (1280x720)
-- Zero-GC / 200 Reusable Slots / 4 Distinct Line Clear Visuals
-- ============================================================================
local ParticleSystem = {}
local ThemeManager   = require "tetris.theme_manager"

function ParticleSystem.init(board)
    board.particles = {}
    for i = 1, 200 do
        board.particles[i] = { 
            active = false, x = 0, y = 0, 
            vx = 0, vy = 0, life = 0, max_life = 0, 
            r = 1, g = 1, b = 1, size = 3,
            p_type = 1, phase = 0
        }
    end
    board.particle_head = 1
end

function ParticleSystem.spawnLineBlast(board, row_index, color_id)
    local clr = board.colors[color_id] or {1, 1, 1}
    local y_pos = board.y + (row_index - 21) * 24 + 12
    local cur_theme = ThemeManager.current_theme

    for c = 1, 10 do
        local x_pos = board.x + (c - 1) * 24 + 12
        local p = board.particles[board.particle_head]
        p.active = true
        p.x, p.y = x_pos, y_pos
        p.p_type = cur_theme
        p.phase = math.random() * math.pi * 2

        if cur_theme == 1 then
            p.vx = (c <= 5) and math.random(-260, -100) or math.random(100, 260)
            p.vy = math.random(-30, 30)
            p.life, p.max_life = 0.35, 0.35
            p.r, p.g, p.b = 0.0, 1.0, 0.55
            p.size = 4

        elseif cur_theme == 2 then
            p.vx = math.random(-280, 280)
            p.vy = math.random(-140, 40)
            p.life, p.max_life = 0.30, 0.30
            p.r, p.g, p.b = 1.0, 0.85, 0.0
            p.size = 5

        elseif cur_theme == 3 then
            p.vx = math.random(-140, 140)
            p.vy = math.random(-120, 80)
            p.life, p.max_life = 0.40, 0.40
            p.r, p.g, p.b = 0.0, 0.95, 1.0
            p.size = 3

        elseif cur_theme == 4 then
            p.vx = math.random(-70, 70)
            p.vy = math.random(-180, -60)
            p.life, p.max_life = 0.65, 0.65
            p.r, p.g, p.b = 0.65, 0.35, 1.0
            p.size = math.random(3, 6)
        end

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
        p.p_type = 1

        board.particle_head = (board.particle_head % 200) + 1
    end
end

function ParticleSystem.update(board, dt)
    for i = 1, 200 do
        local p = board.particles[i]
        if p.active then
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt

            if p.p_type == 4 then
                p.phase = p.phase + dt * 6.0
                p.x = p.x + math.sin(p.phase) * 20 * dt
            else
                p.vy = p.vy + 180 * dt
            end

            p.life = p.life - dt
            if p.life <= 0 then p.active = false end
        end
    end
end

function ParticleSystem.draw(board)
    love.graphics.push("all")
    love.graphics.setBlendMode("add")

    for i = 1, 200 do
        local p = board.particles[i]
        if p.active then
            local alpha = p.life / p.max_life
            local pulse = _G.AudioBeatPulse or 0
            local size = (p.size + pulse * 1.5) * (alpha * 1.2)
            
            love.graphics.setColor(p.r, p.g, p.b, alpha * 0.9)
            love.graphics.rectangle("fill", p.x - size/2, p.y - size/2, size, size, (p.p_type == 3 and 0 or 2))
            love.graphics.setColor(1, 1, 1, alpha * 0.6)
            love.graphics.rectangle("fill", p.x - size/4, p.y - size/4, size/2, size/2)
        end
    end

    love.graphics.setBlendMode("alpha")
    love.graphics.pop()
end

return ParticleSystem
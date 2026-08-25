-- ============================================================================
-- FILE: tetris/particle_system.lua
-- MUTRIS ENGINE: THEMED LINE CLEAR & SPARK PARTICLE ENGINE (1280x720)
-- Zero-GC / 200 Pre-Allocated Slots / Self-Healing / Fast-Quad Rendering
-- TARGET: Intel Pentium G3250 Haswell / Intel HD Graphics (113MB VRAM)
-- ============================================================================
---@diagnostic disable: undefined-global

local ParticleSystem = {}

-- Carga segura de ThemeManager
local ok_theme, ThemeManager = pcall(require, "tetris.theme_manager")
if not ok_theme then
    ThemeManager = { current_theme = 1 }
end

-- CONSTANTES DE ARQUITECTURA
local POOL_SIZE = 200
local TAU = math.pi * 2

-- Fallbacks estáticos inmutables (Zero Allocations)
local FALLBACK_WHITE     = {1.0, 1.0, 1.0}
local FALLBACK_SUPERNOVA = {1.0, 0.85, 0.2}

-- Caché local de funciones para LuaJIT
local math_random     = math.random
local math_sin        = math.sin
local math_cos        = math.cos
local lg              = love.graphics
local lg_setColor     = lg.setColor
local lg_rect         = lg.rectangle
local lg_setBlendMode = lg.setBlendMode
local lg_getBlendMode = lg.getBlendMode
local lg_getColor     = lg.getColor

-- ============================================================================
-- INICIALIZACIÓN: POOL ESTÁTICO DE OBJETOS PRE-ASIGNADOS EN RAM
-- ============================================================================
function ParticleSystem.init(board)
    if not board then return end
    
    board.particles = board.particles or {}
    for i = 1, POOL_SIZE do
        if not board.particles[i] then
            board.particles[i] = {
                active   = false,
                x        = 0.0,
                y        = 0.0,
                vx       = 0.0,
                vy       = 0.0,
                life     = 0.0,
                max_life = 1.0,
                r        = 1.0,
                g        = 1.0,
                b        = 1.0,
                size     = 3.0,
                p_type   = 1,
                phase    = 0.0
            }
        else
            local p = board.particles[i]
            p.active = false
            p.life = 0.0
        end
    end
    board.particle_head = 1
end

-- Mecanismo de auto-recuperación si otra escena no llamó a init()
local function ensure_init(board)
    if not board.particles or #board.particles < POOL_SIZE or not board.particle_head then
        ParticleSystem.init(board)
    end
end

-- ============================================================================
-- EMISOR: LINE BLAST TEMÁTICO
-- ============================================================================
function ParticleSystem.spawnLineBlast(board, row_index, color_id)
    if not board then return end
    ensure_init(board)

    local clr = (board.colors and board.colors[color_id]) or FALLBACK_WHITE
    local bs = board.block_size or 24
    local cols = board.cols or 10
    local visible_rows = board.visible_rows or 20
    local bx = board.x or 0
    local by = board.y or 0
    
    local y_pos = by + (row_index - (visible_rows + 1)) * bs + (bs * 0.5)
    local cur_theme = (ThemeManager and ThemeManager.current_theme) or 1
    local head = board.particle_head

    for c = 1, cols do
        local x_pos = bx + (c - 1) * bs + (bs * 0.5)
        local p = board.particles[head]
        
        p.active = true
        p.x = x_pos
        p.y = y_pos
        p.p_type = cur_theme
        p.phase = math_random() * TAU

        if cur_theme == 1 then
            p.vx = (c <= 5) and math_random(-260, -100) or math_random(100, 260)
            p.vy = math_random(-30, 30)
            p.life = 0.35
            p.max_life = 0.35
            p.r = 0.0
            p.g = 1.0
            p.b = 0.55
            p.size = 4.0

        elseif cur_theme == 2 then
            p.vx = math_random(-280, 280)
            p.vy = math_random(-140, 40)
            p.life = 0.30
            p.max_life = 0.30
            p.r = 1.0
            p.g = 0.85
            p.b = 0.0
            p.size = 5.0

        elseif cur_theme == 3 then
            p.vx = math_random(-140, 140)
            p.vy = math_random(-120, 80)
            p.life = 0.40
            p.max_life = 0.40
            p.r = 0.0
            p.g = 0.95
            p.b = 1.0
            p.size = 3.0

        elseif cur_theme == 4 then
            p.vx = math_random(-70, 70)
            p.vy = math_random(-180, -60)
            p.life = 0.65
            p.max_life = 0.65
            p.r = 0.65
            p.g = 0.35
            p.b = 1.0
            p.size = math_random(3, 6)
        end

        head = (head % POOL_SIZE) + 1
    end

    board.particle_head = head
end

-- ============================================================================
-- EMISOR: SUPERNOVA
-- ============================================================================
function ParticleSystem.spawnSupernova(board, color)
    if not board then return end
    ensure_init(board)

    local clr = color or FALLBACK_SUPERNOVA
    local bs = board.block_size or 24
    local cols = board.cols or 10
    local visible_rows = board.visible_rows or 20
    local bx = board.x or 0
    local by = board.y or 0

    local center_x = bx + (cols * bs * 0.5)
    local center_y = by + (visible_rows * bs * 0.5)
    local head = board.particle_head
    local r, g, b = clr[1] or 1.0, clr[2] or 0.85, clr[3] or 0.2

    for _ = 1, 60 do
        local p = board.particles[head]
        local angle = math_random() * TAU
        local speed = math_random(120, 380)
        local dist  = math_random(0, 40)

        p.active = true
        p.x = center_x + math_cos(angle) * dist
        p.y = center_y + math_sin(angle) * dist
        p.vx = math_cos(angle) * speed
        p.vy = math_sin(angle) * speed
        p.life = 0.85
        p.max_life = 0.85
        p.r = r
        p.g = g
        p.b = b
        p.size = math_random(3, 6)
        p.p_type = 1

        head = (head % POOL_SIZE) + 1
    end

    board.particle_head = head
end

-- ============================================================================
-- EMISOR: T-SPIN BURST (CIAN / MAGENTA NEÓN)
-- ============================================================================
function ParticleSystem.spawnTSpinBlast(board, center_x, center_y)
    if not board then return end
    ensure_init(board)

    local head = board.particle_head
    local cx = center_x or (board.x or 0)
    local cy = center_y or (board.y or 0)

    for i = 1, 40 do
        local p = board.particles[head]
        local angle = math_random() * TAU
        local speed = math_random(160, 420)

        p.active = true
        p.x = cx
        p.y = cy
        p.vx = math_cos(angle) * speed
        p.vy = math_sin(angle) * speed
        p.life = 0.45
        p.max_life = 0.45
        p.size = math_random(2, 5)
        p.p_type = 1

        if i % 2 == 0 then
            p.r, p.g, p.b = 0.0, 0.95, 1.0
        else
            p.r, p.g, p.b = 0.95, 0.10, 0.85
        end

        head = (head % POOL_SIZE) + 1
    end

    board.particle_head = head
end

-- ============================================================================
-- HOT LOOP DE FÍSICA
-- ============================================================================
function ParticleSystem.update(board, dt)
    if not board or not board.particles then return end

    local particles = board.particles
    local grav_step = 180.0 * dt
    local phase_step = 6.0 * dt

    for i = 1, POOL_SIZE do
        local p = particles[i]
        if p and p.active then
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt

            if p.p_type == 4 then
                p.phase = p.phase + phase_step
                p.x = p.x + math_sin(p.phase) * (20.0 * dt)
            else
                p.vy = p.vy + grav_step
            end

            p.life = p.life - dt
            if p.life <= 0.0 then 
                p.active = false 
            end
        end
    end
end

-- ============================================================================
-- RENDER LOOP (OPTIMIZADO PARA INTEL HD GRAPHICS)
-- ============================================================================
function ParticleSystem.draw(board)
    if not board or not board.particles then return end

    local particles = board.particles
    local pulse = _G.AudioBeatPulse or 0
    local pulse_add = pulse * 1.5

    -- Respaldar estado sin llamadas pesadas
    local prev_r, prev_g, prev_b, prev_a = lg_getColor()
    local prev_blend, prev_alpha_mode = lg_getBlendMode()

    lg_setBlendMode("add", "alphamultiply")

    for i = 1, POOL_SIZE do
        local p = particles[i]
        if p and p.active and p.max_life > 0 then
            local alpha = p.life / p.max_life
            local sz = (p.size + pulse_add) * (alpha * 1.2)
            local half_sz = sz * 0.5
            local qtr_sz = sz * 0.25

            -- 1. Aura de color (Hardware quad)
            lg_setColor(p.r, p.g, p.b, alpha * 0.9)
            lg_rect("fill", p.x - half_sz, p.y - half_sz, sz, sz)

            -- 2. Núcleo blanco brillante
            lg_setColor(1.0, 1.0, 1.0, alpha * 0.6)
            lg_rect("fill", p.x - qtr_sz, p.y - qtr_sz, half_sz, half_sz)
        end
    end

    -- Restaurar estado original
    lg_setBlendMode(prev_blend, prev_alpha_mode)
    lg_setColor(prev_r, prev_g, prev_b, prev_a)
end

return ParticleSystem
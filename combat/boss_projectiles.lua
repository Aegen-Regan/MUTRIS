-- ================================================================
-- FILE: combat/boss_projectiles.lua (BALLISTIC ARC ENGINE)
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: TITAN METEORIC BOMBARDMENT & BALLISTIC CRATERS (ZERO-GC)
-- Parabolic trajectories, Mino Dislodging, Heavy HitStops & Kinetic Deflections
-- ============================================================================
local BossProjectiles = {}

local AudioManager = require "audio_manager"
local BloomShader  = require "tetris.bloom_shader"
local PartBreaking = require "combat.part_breaking"
local Blackbox     = require "core.blackbox"

local MAX_METEORS = 16
local meteors = {}
for i = 1, MAX_METEORS do
    meteors[i] = {
        active = false,
        start_x = 0, start_y = 0,
        target_x = 0, target_y = 0,
        current_x = 0, current_y = 0,
        arc_h = 160,
        timer = 0, duration = 0.85,
        target_col = 1,
        source_board = nil,
        target_board = nil,
        damage = 1,
        is_deflected = false,
        trail_timer = 0
    }
end

local MAX_SPARKS = 64
local sparks = {}
for i = 1, MAX_SPARKS do
    sparks[i] = { active = false, x = 0, y = 0, vx = 0, vy = 0, life = 0, max_life = 0, r = 1, g = 0.5, b = 0.1, size = 4 }
end
local spark_head = 1

function BossProjectiles.init()
    for i = 1, MAX_METEORS do
        meteors[i].active = false
    end
    for i = 1, MAX_SPARKS do
        sparks[i].active = false
    end
end

function BossProjectiles.spawnSparks(x, y, count, r, g, b)
    for _ = 1, count do
        local s = sparks[spark_head]
        s.active = true
        s.x = x
        s.y = y
        s.vx = math.random(-160, 160)
        s.vy = math.random(-220, 80)
        s.life = 0.50
        s.max_life = 0.50
        s.r = r or 1.0
        s.g = g or 0.45
        s.b = b or 0.1
        s.size = math.random(3, 6)

        spark_head = (spark_head % MAX_SPARKS) + 1
    end
end

-- ============================================================================
-- ☄️ DISPARO DE METEORITOS DESDE LAS LÍNEAS ROTAS DEL JEFE
-- ============================================================================
function BossProjectiles.spawnBarrage(boss_board, player_board, line_count)
    if not boss_board or not player_board or line_count <= 0 then return end

    local meteor_count = math.min(4, math.max(1, line_count))
    local bs = player_board.block_size or 19

    boss_board:triggerShake(16, 0.50)
    AudioManager.playImmediateSFX("death", true)
    AudioManager.playSubBassThud(3)

    for m = 1, meteor_count do
        for i = 1, MAX_METEORS do
            local p = meteors[i]
            if not p.active then
                p.active = true
                p.source_board = boss_board
                p.target_board = player_board
                p.is_deflected = false

                -- Origen: centro de las celdas del Titán
                p.start_x = boss_board.x + math.random(30, boss_board.cols * (boss_board.block_size or 25) - 30)
                p.start_y = boss_board.y + math.random(50, 220)

                -- Destino: columna aleatoria en el tope de la matriz de P1
                local col = math.random(1, player_board.cols)
                p.target_col = col
                p.target_x = player_board.x + (col - 0.5) * bs

                local col_height = 0
                for r = 1, player_board.rows do
                    if player_board.grid[r][col] ~= 0 then
                        col_height = (player_board.rows + 1) - r
                        break
                    end
                end

                local top_row = player_board.rows - col_height
                p.target_y = player_board.y + (top_row - player_board.visible_rows) * bs

                p.arc_h = math.random(160, 240)
                p.duration = 0.75 + (m * 0.14)
                p.timer = 0
                p.damage = 1

                BossProjectiles.spawnSparks(p.start_x, p.start_y, 10, 1.0, 0.25, 0.05)
                Blackbox.log("METEOR_LAUNCH", "TITAN LAUNCHED METEOR " .. tostring(m), p.start_x, p.target_col)
                break
            end
        end
    end
end

-- ============================================================================
-- 💥 RESOLUCIÓN DE IMPACTO / CRÁTER / KINETIC PARRY
-- ============================================================================
local function resolveImpact(p)
    local target = p.target_board
    if not target or target.is_dying then return end

    -- 🛡️ 1. PARADA KINETIC PARRY: REFLEJO BALÍSTICO
    if not p.is_deflected and target.player_type == "human" and target.parry_active_timer and target.parry_active_timer > 0 then
        target.parry_active_timer = 0
        p.is_deflected = true
        p.timer = 0
        p.duration = 0.40 -- Vuelve a toda velocidad hacia el Titán

        local old_tx, old_ty = p.target_x, p.target_y
        p.start_x, p.start_y = old_tx, old_ty
        p.target_x = p.source_board.x + (p.source_board.cols * (p.source_board.block_size or 25) * 0.5)
        p.target_y = p.source_board.y + 100

        _G.HitStopTimer = 0.15
        target.parry_success_flash = 1.0
        BloomShader.triggerShockwave(old_tx, old_ty)
        AudioManager.playImmediateSFX("phantom_attack", false)
        AudioManager.playSubBassThud(3)

        target:setPopup("METEOR PARRIED!", {0.1, 0.95, 1.0}, true, "DEFLECTED TO TITAN!")
        Blackbox.log("PARRY", "TITAN METEOR DEFLECTED", 0, 0)
        return
    end

    -- 💥 2. DEFLECTADO IMPACTANDO AL JEFE
    if p.is_deflected then
        _G.HitStopTimer = 0.25
        BloomShader.triggerShockwave(p.target_x, p.target_y)
        AudioManager.playImmediateSFX("ultimatris", false)
        AudioManager.playSubBassThud(4)
        PartBreaking.registerLineClear(p.source_board, 3, true)
        return
    end

    -- 🌋 3. IMPACTO EN CRÁTER SOBRE P1
    _G.HitStopTimer = 0.22
    BloomShader.triggerShockwave(p.target_x, p.target_y)
    AudioManager.playImmediateSFX("death", false)
    AudioManager.playSubBassThud(4)

    target:triggerShake(16, 0.40)
    BossProjectiles.spawnSparks(p.target_x, p.target_y, 25, 1.0, 0.20, 0.05)

    local col = p.target_col
    local g = target.grid

    local impact_r = target.rows
    for r = 1, target.rows do
        if g[r][col] ~= 0 then
            impact_r = r
            break
        end
    end

    -- Incrustar roca de meteorito
    local embed_r = math.max(target.visible_rows + 1, impact_r - 1)
    if embed_r <= target.rows then
        g[embed_r][col] = 8
    end

    -- Descomposición sísmica de celdas vecinas
    for _, c_offset in ipairs({-1, 1}) do
        local c = col + c_offset
        if c >= 1 and c <= target.cols then
            for r = embed_r, target.rows - 1 do
                if g[r + 1][c] ~= 0 and g[r][c] == 0 and math.random() < 0.65 then
                    g[r][c] = g[r + 1][c]
                    g[r + 1][c] = 0
                end
            end
        end
    end

    target:setPopup("CRATER IMPACT!", {1.0, 0.25, 0.1}, true, "TERRAIN DISRUPTED")
    Blackbox.log("METEOR", "CRATER IMPACT COL: " .. tostring(col), 0, 0)
end

function BossProjectiles.update(dt)
    for i = 1, MAX_METEORS do
        local p = meteors[i]
        if p.active then
            p.timer = p.timer + dt
            local prog = math.min(1.0, p.timer / p.duration)

            local cur_x = p.start_x + (p.target_x - p.start_x) * prog
            local linear_y = p.start_y + (p.target_y - p.start_y) * prog
            local arc = 4.0 * p.arc_h * prog * (1.0 - prog)
            local cur_y = linear_y - arc

            p.current_x = cur_x
            p.current_y = cur_y

            p.trail_timer = p.trail_timer + dt
            if p.trail_timer >= 0.035 then
                p.trail_timer = 0
                if p.is_deflected then
                    BossProjectiles.spawnSparks(cur_x, cur_y, 2, 0.1, 0.95, 1.0)
                else
                    BossProjectiles.spawnSparks(cur_x, cur_y, 2, 1.0, 0.45, 0.1)
                end
            end

            if prog >= 1.0 then
                p.active = false
                resolveImpact(p)
            end
        end
    end

    for i = 1, MAX_SPARKS do
        local s = sparks[i]
        if s.active then
            s.x = s.x + s.vx * dt
            s.y = s.y + s.vy * dt
            s.vy = s.vy + 360 * dt
            s.life = s.life - dt
            if s.life <= 0 then s.active = false end
        end
    end
end

function BossProjectiles.draw()
    love.graphics.push("all")
    love.graphics.setBlendMode("add")

    -- 1. Chispas y estelas
    for i = 1, MAX_SPARKS do
        local s = sparks[i]
        if s.active then
            local a = s.life / s.max_life
            love.graphics.setColor(s.r, s.g, s.b, a * 0.95)
            love.graphics.rectangle("fill", s.x - s.size/2, s.y - s.size/2, s.size, s.size)
        end
    end

    -- 2. Cuerpos de Meteorito
    for i = 1, MAX_METEORS do
        local p = meteors[i]
        if p.active then
            local pulse = math.sin(love.timer.getTime() * 18) * 3 + 10
            if p.is_deflected then
                love.graphics.setColor(0.1, 0.95, 1.0, 0.6)
                love.graphics.circle("fill", p.current_x, p.current_y, pulse + 6)
                love.graphics.setColor(1.0, 1.0, 1.0, 0.98)
                love.graphics.circle("fill", p.current_x, p.current_y, pulse * 0.55)
            else
                love.graphics.setColor(1.0, 0.20, 0.05, 0.65)
                love.graphics.circle("fill", p.current_x, p.current_y, pulse + 8)
                love.graphics.setColor(1.0, 0.80, 0.15, 0.90)
                love.graphics.circle("fill", p.current_x, p.current_y, pulse + 3)
                love.graphics.setColor(1.0, 1.0, 1.0, 0.98)
                love.graphics.circle("fill", p.current_x, p.current_y, pulse * 0.5)
            end
        end
    end

    love.graphics.pop()
end

return BossProjectiles

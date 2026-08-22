-- ================================================================
-- FILE: combat/boss_phases.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: TITAN MULTI-BOARD BOSS PHASES & DISRUPTIONS (FASE 16 & 18)
-- Arquitectura: Zero-GC / 3-Stage Colossus / EMP Hold Lock & Quantum Laser Row
-- ============================================================================
local BossPhases = {}

local FontCache    = require "tetris.font_cache"
local AudioManager = require "audio_manager"
local BloomShader  = require "tetris.bloom_shader"
local ThemeManager = require "tetris.theme_manager"
local Blackbox     = require "core.blackbox"

BossPhases.PHASE_1_ARMOR = 1
BossPhases.PHASE_2_CORE  = 2
BossPhases.PHASE_3_APEX  = 3

BossPhases.current_phase = 1
BossPhases.transition_timer = 0.0
BossPhases.transition_duration = 0.65
BossPhases.transition_text = ""

-- Habilidad Fase 1: EMP Bloqueo de Hold
BossPhases.hold_lock_timer = 0.0
BossPhases.emp_cooldown = 11.0
BossPhases.emp_timer = 0.0

-- Habilidad Fase 2: Láser Quemador de Fila
BossPhases.laser_target_row = 0
BossPhases.laser_burn_timer = 0.0
BossPhases.laser_cooldown = 10.0
BossPhases.laser_timer = 0.0

-- Habilidad Fase 3: 20G Gravity Pulse
BossPhases.gravity_surge_timer = 0.0

function BossPhases.init()
    BossPhases.current_phase = BossPhases.PHASE_1_ARMOR
    BossPhases.transition_timer = 0.0
    BossPhases.transition_text = ""

    BossPhases.hold_lock_timer = 0.0
    BossPhases.emp_timer = 0.0

    BossPhases.laser_target_row = 0
    BossPhases.laser_burn_timer = 0.0
    BossPhases.laser_timer = 0.0

    BossPhases.gravity_surge_timer = 0.0

    Blackbox.log("BOSS_PHASE", "TITAN ASSAULT ENGAGED: PHASE 1 (ARMOR)", 1, 0)
end

function BossPhases.isHoldLocked()
    return _G.CURRENT_GAME_MODE == "boss_hunt" and BossPhases.hold_lock_timer > 0
end

function BossPhases.triggerPhaseAdvance(player_board, boss_board)
    if BossPhases.current_phase == BossPhases.PHASE_1_ARMOR then
        BossPhases.current_phase = BossPhases.PHASE_2_CORE
        BossPhases.transition_text = "ARMOR SHATTERED! FUSION CORE EXPOSED"
        
        -- Configuración Fase 2: 1200 HP
        local PoiseSystem = require "combat.poise_system"
        PoiseSystem.max_hp = 1200
        PoiseSystem.hp = 1200
        PoiseSystem.max_poise = 320
        PoiseSystem.poise = 0
        PoiseSystem.is_stunned = false

    elseif BossPhases.current_phase == BossPhases.PHASE_2_CORE then
        BossPhases.current_phase = BossPhases.PHASE_3_APEX
        BossPhases.transition_text = "CORE OVERHEATED! APEX CONSCIOUSNESS AWAKENED"

        -- Configuración Fase 3: 1500 HP
        local PoiseSystem = require "combat.poise_system"
        PoiseSystem.max_hp = 1500
        PoiseSystem.hp = 1500
        PoiseSystem.max_poise = 360
        PoiseSystem.poise = 0
        PoiseSystem.is_stunned = false
        PoiseSystem.is_enraged = true
    end

    BossPhases.transition_timer = BossPhases.transition_duration
    _G.HitStopTimer = 0.40

    -- Reinicio del tablero del jefe con efecto de ruptura
    if boss_board then
        for r = 1, 40 do
            for c = 1, 10 do boss_board.grid[r][c] = 0 end
        end
        boss_board.garbage_queue = {}
        boss_board.is_dying = false
        boss_board.death_timer = 0.0
        boss_board:spawnPiece()
    end

    AudioManager.playImmediateSFX("ultimatris", false)
    AudioManager.playSubBassThud(4)
    BloomShader.triggerShockwave(640, 360)

    Blackbox.log("BOSS_PHASE", "ADVANCED TO PHASE " .. BossPhases.current_phase, BossPhases.current_phase, 0)
end

function BossPhases.update(dt, player_board, boss_board)
    if _G.CURRENT_GAME_MODE ~= "boss_hunt" then return end

    if BossPhases.transition_timer > 0 then
        BossPhases.transition_timer = math.max(0, BossPhases.transition_timer - dt)
    end

    -- ────────────────────────────────────────────────────────────────────────
    -- HABILIDADES ACTIVAS SEGÚN LA FASE
    -- ────────────────────────────────────────────────────────────────────────
    -- FASE 1: Pulso EMP que bloquea el HOLD
    if BossPhases.current_phase == BossPhases.PHASE_1_ARMOR then
        if BossPhases.hold_lock_timer > 0 then
            BossPhases.hold_lock_timer = math.max(0, BossPhases.hold_lock_timer - dt)
        else
            BossPhases.emp_timer = BossPhases.emp_timer + dt
            if BossPhases.emp_timer >= BossPhases.emp_cooldown then
                BossPhases.emp_timer = 0.0
                BossPhases.hold_lock_timer = 3.5
                AudioManager.playImmediateSFX("phantom_attack", false)
                if player_board then
                    player_board:setPopup("EMP PULSE!", {1.0, 0.2, 0.3}, true, "HOLD SYSTEM LOCKED (3.5s)")
                end
            end
        end

    -- FASE 2: Láser Quemador de Fila
    elseif BossPhases.current_phase == BossPhases.PHASE_2_CORE then
        if BossPhases.laser_target_row > 0 then
            BossPhases.laser_burn_timer = BossPhases.laser_burn_timer - dt
            if BossPhases.laser_burn_timer <= 0 then
                -- Convierte la fila en basura sólida si no se limpió
                if player_board and player_board.grid and BossPhases.laser_target_row >= 21 and BossPhases.laser_target_row <= 40 then
                    for c = 1, 10 do
                        if player_board.grid[BossPhases.laser_target_row][c] == 0 then
                            player_board.grid[BossPhases.laser_target_row][c] = 8
                        end
                    end
                    player_board:triggerShake(8, 0.3)
                    AudioManager.playImmediateSFX("death", false)
                end
                BossPhases.laser_target_row = 0
            end
        else
            BossPhases.laser_timer = BossPhases.laser_timer + dt
            if BossPhases.laser_timer >= BossPhases.laser_cooldown then
                BossPhases.laser_timer = 0.0
                BossPhases.laser_target_row = math.random(32, 39)
                BossPhases.laser_burn_timer = 4.0
                AudioManager.playImmediateSFX("rotate", true)
                if player_board then
                    player_board:setPopup("QUANTUM LASER!", {1.0, 0.1, 0.2}, true, "CLEAR MARKED ROW (4s)")
                end
            end
        end

    -- FASE 3: Gravedad 20G & Furia Despiadada
    elseif BossPhases.current_phase == BossPhases.PHASE_3_APEX then
        BossPhases.gravity_surge_timer = BossPhases.gravity_surge_timer + dt
        if BossPhases.gravity_surge_timer >= 7.0 then
            BossPhases.gravity_surge_timer = 0.0
            if player_board and player_board.active_piece and not player_board.is_dying then
                player_board.active_piece:move(0, 4, true)
                player_board:triggerShake(4, 0.2)
            end
        end
    end
end

-- ============================================================================
-- 🎨 RENDERIZADO DEL HUD DE FASE & ALERTA DE TRANSICIÓN
-- ============================================================================
function BossPhases.drawHUD(boss_board, player_board)
    if _G.CURRENT_GAME_MODE ~= "boss_hunt" then return end

    local t = ThemeManager.getCurrent()
    local pulse = _G.AudioBeatPulse or 0
    local time = love.timer.getTime()

    love.graphics.push("all")

    -- 1. Badge de Fase Activa en la parte superior
    local ph_w = 260
    local ph_x = 640 - (ph_w / 2)
    local ph_y = 6

    love.graphics.setColor(0.02, 0.03, 0.06, 0.92)
    love.graphics.rectangle("fill", ph_x, ph_y, ph_w, 20, 3)
    love.graphics.setLineWidth(1.2)
    love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.7)
    love.graphics.rectangle("line", ph_x, ph_y, ph_w, 20, 3)

    love.graphics.setFont(FontCache.get(8))
    local phase_title = (BossPhases.current_phase == 1 and "PHASE 1/3: CYBERNETIC ARMOR")
                     or (BossPhases.current_phase == 2 and "PHASE 2/3: FUSION CORE")
                     or "PHASE 3/3: APEX CONSCIOUSNESS"
    love.graphics.setColor(1.0, 0.85, 0.0, 0.95)
    love.graphics.printf(phase_title, ph_x, ph_y + 5, ph_w, "center")

    -- 2. Mira Láser Quemadora sobre la matriz del jugador (Fase 2)
    if BossPhases.laser_target_row >= 21 and BossPhases.laser_target_row <= 40 and player_board then
        local target_y = player_board.y + (BossPhases.laser_target_row - 21) * 24
        local flash = math.sin(time * 24) * 0.5 + 0.5
        love.graphics.setBlendMode("add")
        love.graphics.setColor(1.0, 0.1, 0.2, 0.35 + flash * 0.35)
        love.graphics.rectangle("fill", player_board.x, target_y, 240, 24)
        love.graphics.setColor(1.0, 0.85, 0.0, 0.9)
        love.graphics.setLineWidth(2)
        love.graphics.line(player_board.x, target_y + 12, player_board.x + 240, target_y + 12)
        love.graphics.setFont(FontCache.get(7))
        love.graphics.setColor(1, 1, 1, 0.95)
        love.graphics.print(string.format("! LASER TARGET %.1fs !", BossPhases.laser_burn_timer), player_board.x + 60, target_y + 6)
        love.graphics.setBlendMode("alpha")
    end

    -- 3. Indicador de EMP Lock sobre el botón de HOLD
    if BossPhases.hold_lock_timer > 0 and player_board then
        local is_human = (player_board.player_type == "human")
        local hold_x = is_human and (player_board.x - 78) or (player_board.x + 250)
        local hold_y = player_board.y + 10
        love.graphics.setBlendMode("add")
        love.graphics.setColor(1.0, 0.1, 0.25, 0.45)
        love.graphics.rectangle("fill", hold_x, hold_y, 70, 70, 4)
        love.graphics.setFont(FontCache.get(8))
        love.graphics.setColor(1.0, 0.85, 0.0, 0.95)
        love.graphics.printf("LOCKED", hold_x, hold_y + 26, 70, "center")
        love.graphics.setBlendMode("alpha")
    end

    -- 4. Cortina Cinemática de Transición de Fase
    if BossPhases.transition_timer > 0 then
        local progress = BossPhases.transition_timer / BossPhases.transition_duration
        local alpha = math.sin(progress * math.pi)

        love.graphics.setColor(0.0, 0.0, 0.0, 0.85 * alpha)
        love.graphics.rectangle("fill", 0, 0, 1280, 720)

        love.graphics.setFont(FontCache.get(26))
        love.graphics.setColor(1.0, 0.85, 0.0, alpha)
        love.graphics.printf("/// PHASE DESTROYED! ///", 0, 310, 1280, "center")

        love.graphics.setFont(FontCache.get(13))
        love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], alpha)
        love.graphics.printf(BossPhases.transition_text, 0, 360, 1280, "center")
    end

    love.graphics.pop()
end

return BossPhases
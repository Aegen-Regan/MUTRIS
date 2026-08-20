---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: COMBAT STANCES SYSTEM (FASE 8)
-- Arquitectura: Zero-GC / Físicas Dinámicas / Modulación Neón
-- ============================================================================
local CombatStances = {}

local AudioManager = require "audio_manager"
local MetaBalancer = require "core.meta_balancer"

CombatStances.STANCE_RUSH      = 1
CombatStances.STANCE_BASTION   = 2
CombatStances.STANCE_RESONANCE = 3

local STANCE_DATA = {
    [1] = {
        name = "RUSH",
        aura = {1.0, 0.22, 0.10},  -- Bermellón de ataque puro
        snd  = "rotate"
    },
    [2] = {
        name = "BASTION",
        aura = {0.12, 0.65, 1.00}, -- Azul Zafiro blindado
        snd  = "hold"
    },
    [3] = {
        name = "RESONANCE",
        aura = {0.85, 0.15, 0.95}, -- Púrpura Sinestésico / 20G
        snd  = "zone_enter"
    }
}

function CombatStances.initBoardState(board)
    board.current_stance = CombatStances.STANCE_BASTION -- Postura inicial estándar
    board.stance_aura_timer = 0.0
    board.stance_switch_cooldown = 0.0
end

-- 🔄 CONMUTACIÓN DE POSTURA (Ciclo con TAB / Shift / L3 / R3)
function CombatStances.cycleStance(board)
    if board.stance_switch_cooldown > 0 then return end
    
    local next_st = (board.current_stance % 3) + 1
    CombatStances.setStance(board, next_st)
end

function CombatStances.setStance(board, stance_id)
    if stance_id < 1 or stance_id > 3 then return end
    board.current_stance = stance_id
    board.stance_switch_cooldown = 0.20
    board.stance_aura_timer = 1.0

    local sdata = STANCE_DATA[stance_id]
    AudioManager.playImmediateSFX(sdata.snd, board.player_type == "bot")
    board:setPopup(sdata.name .. " STANCE", sdata.aura)
end

-- 🛡️ CONSULTA DE MODIFICADORES VIVOS PARA PIECE & BOARD
function CombatStances.applyPieceModifiers(board, piece)
    local st = board.current_stance
    local b = MetaBalancer.balance

    if st == CombatStances.STANCE_RUSH then
        piece.lock_delay = b.rush_lock_delay or 0.12
    elseif st == CombatStances.STANCE_RESONANCE then
        piece.lock_delay = 0.35
    else -- BASTION
        piece.lock_delay = 0.50
    end
end

function CombatStances.getAttackMultiplier(board)
    local st = board.current_stance
    if st == CombatStances.STANCE_RUSH then
        return MetaBalancer.get("rush_atk_mult") or 1.50
    elseif st == CombatStances.STANCE_BASTION then
        return MetaBalancer.get("bastion_atk_mult") or 0.50
    end
    return 1.00 -- Resonance
end

function CombatStances.getGravitySpeed(board, base_gravity)
    if board.current_stance == CombatStances.STANCE_RESONANCE then
        return 0.001 -- 20G Caída instantánea
    end
    return base_gravity or 0.8
end

function CombatStances.update(board, dt)
    if board.stance_switch_cooldown > 0 then
        board.stance_switch_cooldown = math.max(0, board.stance_switch_cooldown - dt)
    end
    if board.stance_aura_timer > 0 then
        board.stance_aura_timer = math.max(0, board.stance_aura_timer - dt * 2.5)
    end
end

function CombatStances.drawAura(board)
    local sdata = STANCE_DATA[board.current_stance]
    if not sdata then return end

    love.graphics.push("all")
    local clr = sdata.aura
    local pulse = _G.AudioBeatPulse or 0
    local alpha = 0.15 + (pulse * 0.10) + (board.stance_aura_timer * 0.40)

    love.graphics.setBlendMode("add")
    love.graphics.setLineWidth(2.0 + pulse * 2.0)
    love.graphics.setColor(clr[1], clr[2], clr[3], alpha)
    love.graphics.rectangle("line", board.x - 4, board.y - 4, 248, 488, 4)

    -- Insignia en el lateral
    love.graphics.setFont(love.graphics.newFont(8))
    love.graphics.setColor(clr[1], clr[2], clr[3], 0.85)
    local tag_x = (board.player_type == "human") and (board.x - 72) or (board.x + 248)
    love.graphics.printf("[" .. sdata.name .. "]", tag_x, board.y + 80, 64, "center")
    love.graphics.pop()
end

return CombatStances
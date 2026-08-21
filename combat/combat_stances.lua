-- ================================================================
-- FILE: combat/combat_stances.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: COMBAT STANCE SWITCHING SYSTEM (FASE 8)
-- 1: RUSH (1.5x Atk / Fast) | 2: BASTION (Parry / Def) | 3: RESONANCE (20G / 2x Zone)
-- ============================================================================
local CombatStances = {}

local AudioManager    = require "audio_manager"
local SettingsManager = require "settings_manager"
local MetaBalancer    = require "core.meta_balancer"
local Blackbox        = require "core.blackbox"

CombatStances.STANCE_NONE      = 0
CombatStances.STANCE_RUSH      = 1
CombatStances.STANCE_BASTION   = 2
CombatStances.STANCE_RESONANCE = 3

function CombatStances.initBoardState(board)
    board.current_stance = CombatStances.STANCE_BASTION
    board.stance_switch_flash = 0.0
end

function CombatStances.cycleStance(board)
    if not board or board.is_dying then return end
    
    local old_st = board.current_stance or CombatStances.STANCE_BASTION
    local new_st = (old_st % 3) + 1
    board.current_stance = new_st
    board.stance_switch_flash = 1.0

    AudioManager.playImmediateSFX("rotate", board.player_type == "bot")

    local name = (new_st == 1 and "RUSH") or (new_st == 2 and "BASTION") or "RESONANCE"
    local color = (new_st == 1 and {1.0, 0.15, 0.25}) or (new_st == 2 and {0.1, 0.85, 1.0}) or {0.7, 0.35, 1.0}
    board:setPopup("STANCE: " .. name, color, true, (new_st == 1 and "1.5x ATK POWER") or (new_st == 2 and "PARRY ABSORPTION") or "20G INSTANT GRAVITY")

    Blackbox.log("STANCE", "SWITCH TO " .. name, new_st, 0)
end

function CombatStances.applyPieceModifiers(board, piece)
    if not board or not piece then return end
    local st = board.current_stance or 0
    
    if st == CombatStances.STANCE_RUSH then
        piece.lock_delay = MetaBalancer.get("rush_lock_delay") or 0.12
    else
        piece.lock_delay = SettingsManager.get("lock_delay") or 0.50
    end
end

-- ⚔️ MULTIPLICADOR DE ATAQUE DINÁMICO (Consultado por GarbageManager)
function CombatStances.getAttackMultiplier(board)
    if not board or not board.current_stance then return 1.0 end
    local st = board.current_stance

    if st == CombatStances.STANCE_RUSH then
        return MetaBalancer.get("rush_atk_mult") or 1.50
    elseif st == CombatStances.STANCE_BASTION then
        return MetaBalancer.get("bastion_atk_mult") or 0.50
    end
    return 1.0
end

-- 🛡️ MULTIPLICADOR DE ENTRADA DE BASURA (Defensa en Bastion)
function CombatStances.getIntakeMultiplier(board)
    if not board or not board.current_stance then return 1.0 end
    if board.current_stance == CombatStances.STANCE_BASTION then
        return MetaBalancer.get("bastion_intake_mult") or 0.50
    end
    return 1.0
end

-- ⚡ MULTIPLICADOR DE CARGA DE ZONE (Resonance 2x)
function CombatStances.getZoneMultiplier(board)
    if not board or not board.current_stance then return 1.0 end
    if board.current_stance == CombatStances.STANCE_RESONANCE then
        return MetaBalancer.get("resonance_zone_mult") or 2.00
    end
    return 1.0
end

function CombatStances.getGravitySpeed(board, base_gravity)
    if not board then return base_gravity end
    if board.current_stance == CombatStances.STANCE_RESONANCE then
        return 0.001 -- 20G instantáneo
    end
    return base_gravity
end

function CombatStances.update(board, dt)
    if board.stance_switch_flash > 0 then
        board.stance_switch_flash = math.max(0, board.stance_switch_flash - dt * 4.0)
    end
end

function CombatStances.drawAura(board)
    local ThemeManager = require "tetris.theme_manager"
    ThemeManager.drawStanceAura(board)
end

return CombatStances
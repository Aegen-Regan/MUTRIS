-- ================================================================
-- FILE: core/ruleset_manager.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: UNIVERSAL MULTI-RULESET ENGINE (FASE 21)
-- Arquitectura: Zero-GC / Guideline SRS / TGM ARS 20G / NES 1989 Retro / Pento 18
-- ============================================================================
local RulesetManager = {}

local SettingsManager = require "settings_manager"
local Blackbox        = require "core.blackbox"

RulesetManager.RULESET_GUIDELINE = 1
RulesetManager.RULESET_TGM_20G   = 2
RulesetManager.RULESET_NES_1989  = 3
RulesetManager.RULESET_PENTOMINO = 4

RulesetManager.active_ruleset = 1

RulesetManager.RULESETS = {
    [1] = {
        id = "guideline",
        name = "01 // GUIDELINE MODERN",
        desc = "SRS 180° KICKS, UNLIMITED HOLD, 15 MOVE RESETS, FAST SDF",
        allow_hold = true,
        allow_hard_drop = true,
        allow_ghost = true,
        is_20g = false,
        reset_lock_on_move = true,
        max_lock_resets = 15,
        default_lock_delay = 0.50,
        rotation_system = "srs"
    },
    [2] = {
        id = "tgm_20g",
        name = "02 // TGM 20G SHIRASE",
        desc = "ARS ROTATION, FORCED 20G INSTANT GRAVITY, STRICT LOCK (NO STALL)",
        allow_hold = true,
        allow_hard_drop = true,
        allow_ghost = true,
        is_20g = true,
        reset_lock_on_move = false, -- En TGM los giros no resetean el lock delay
        max_lock_resets = 0,
        default_lock_delay = 0.30,
        rotation_system = "ars"
    },
    [3] = {
        id = "nes_1989",
        name = "03 // NES 1989 RETRO",
        desc = "NO WALL-KICKS, NO HOLD, NO HARD DROP, NO GHOST, INSTANT TOUCH LOCK",
        allow_hold = false,
        allow_hard_drop = false,
        allow_ghost = false,
        is_20g = false,
        reset_lock_on_move = false,
        max_lock_resets = 0,
        default_lock_delay = 0.001,
        rotation_system = "nes"
    },
    [4] = {
        id = "pentomino",
        name = "04 // PENTOMINO 18",
        desc = "18 EXTENDED 5-BLOCK POLYOMINOES WITH WIDE MATRIX DYNAMICS",
        allow_hold = true,
        allow_hard_drop = true,
        allow_ghost = true,
        is_20g = false,
        reset_lock_on_move = true,
        max_lock_resets = 15,
        default_lock_delay = 0.55,
        rotation_system = "srs"
    }
}

function RulesetManager.init()
    local saved = SettingsManager.get("active_ruleset")
    RulesetManager.active_ruleset = (type(saved) == "number" and saved >= 1 and saved <= 4) and saved or 1
    Blackbox.log("RULESET", "RULESET INITIALIZED: " .. RulesetManager.getCurrent().id, RulesetManager.active_ruleset, 0)
end

function RulesetManager.getCurrent()
    return RulesetManager.RULESETS[RulesetManager.active_ruleset] or RulesetManager.RULESETS[1]
end

function RulesetManager.setRuleset(idx)
    if idx < 1 then idx = 4 end
    if idx > 4 then idx = 1 end
    RulesetManager.active_ruleset = idx

    SettingsManager.settings.active_ruleset = idx
    SettingsManager.save()

    local cur = RulesetManager.getCurrent()
    Blackbox.log("RULESET", "RULESET SWITCHED: " .. cur.name, idx, 0)
end

function RulesetManager.cycleNext()
    RulesetManager.setRuleset(RulesetManager.active_ruleset + 1)
end

-- ============================================================================
-- 🔄 CONSULTAS DE FÍSICAS Y ROTACIÓN POR RULESET
-- ============================================================================
function RulesetManager.getKicks(piece_id, from_rot, to_rot)
    local cur = RulesetManager.getCurrent()

    if cur.rotation_system == "ars" then
        local ARS = require "tetris.rotation_systems.ars"
        return ARS.getKicks(piece_id, from_rot, to_rot)
    elseif cur.rotation_system == "nes" then
        local NES = require "tetris.rotation_systems.nes"
        return NES.getKicks(piece_id, from_rot, to_rot)
    else
        local SRS = require "tetris.rotation_systems.srs"
        return SRS.getKicks(piece_id, from_rot, to_rot)
    end
end

function RulesetManager.getShapes(piece_id)
    local cur = RulesetManager.getCurrent()

    if cur.rotation_system == "ars" then
        local ARS = require "tetris.rotation_systems.ars"
        return ARS.shapes[piece_id]
    elseif cur.rotation_system == "nes" then
        local NES = require "tetris.rotation_systems.nes"
        return NES.shapes[piece_id]
    else
        local SRS = require "tetris.rotation_systems.srs"
        return SRS.shapes[piece_id]
    end
end

function RulesetManager.allowHold()
    return RulesetManager.getCurrent().allow_hold
end

function RulesetManager.allowHardDrop()
    return RulesetManager.getCurrent().allow_hard_drop
end

function RulesetManager.allowGhost()
    return RulesetManager.getCurrent().allow_ghost
end

function RulesetManager.is20G()
    return RulesetManager.getCurrent().is_20g
end

function RulesetManager.shouldResetLockOnMove()
    return RulesetManager.getCurrent().reset_lock_on_move
end

function RulesetManager.getLockDelay()
    local cur = RulesetManager.getCurrent()
    return cur.default_lock_delay
end

return RulesetManager
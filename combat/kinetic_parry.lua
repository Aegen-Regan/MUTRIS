---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: KINETIC PARRY & COUNTER-SPIKES (FASE 9)
-- Arquitectura: Zero-GC / Ventana Determinista / Blackbox Logging
-- ============================================================================
local KineticParry = {}

local AudioManager = require "audio_manager"
local BloomShader  = require "tetris.bloom_shader"
local MetaBalancer = require "core.meta_balancer"
local Blackbox     = require "core.blackbox"

function KineticParry.initBoardState(board)
    board.parry_active_timer = 0.0
    board.parry_success_flash = 0.0
end

function KineticParry.openWindow(board)
    local frames = MetaBalancer.get("parry_window_frames") or 3
    board.parry_active_timer = frames * (1.0 / 60.0)
end

function KineticParry.attemptParry(receiver, incoming_lines)
    if incoming_lines <= 0 or not receiver then 
        return false, incoming_lines 
    end

    if receiver.parry_active_timer > 0 then
        receiver.parry_active_timer = 0.0

        local ratio = MetaBalancer.get("parry_counter_ratio") or 0.50
        local counter_lines = math.max(1, math.floor(incoming_lines * ratio))

        receiver.parry_success_flash = 1.0
        _G.HitStopTimer = 0.12

        BloomShader.triggerShockwave(receiver.x + 120, receiver.y + 240)
        AudioManager.playImmediateSFX("phantom_attack", receiver.player_type == "bot")
        AudioManager.playSubBassThud(4)

        receiver:setPopup("KINETIC PARRY!", {0.2, 0.9, 1.0}, true, "COUNTER-SPIKE")
        
        Blackbox.log(
            "PARRY", 
            (receiver.player_type == "human") and "P1 KINETIC PARRY" or "BOT KINETIC PARRY", 
            incoming_lines, 
            counter_lines
        )

        if receiver.opponent then
            local GarbageManager = require "tetris.garbage_manager"
            GarbageManager.sendGarbage(receiver, receiver.opponent, counter_lines, true)
            receiver.opponent:setPopup("COUNTER-SPIKE!", {1.0, 0.2, 0.3}, true, string.format("-%d LINES", counter_lines))
        end

        return true, 0
    end

    return false, incoming_lines
end

function KineticParry.update(board, dt)
    if board.parry_active_timer > 0 then
        board.parry_active_timer = math.max(0, board.parry_active_timer - dt)
    end
    if board.parry_success_flash > 0 then
        board.parry_success_flash = math.max(0, board.parry_success_flash - dt * 3.5)
    end
end

function KineticParry.draw(board)
    if board.parry_success_flash > 0 then
        love.graphics.push("all")
        love.graphics.setBlendMode("add")
        love.graphics.setColor(0.1, 0.8, 1.0, board.parry_success_flash * 0.7)
        love.graphics.circle("line", board.x + 120, board.y + 240, (1.0 - board.parry_success_flash) * 160)
        love.graphics.pop()
    end
end

return KineticParry
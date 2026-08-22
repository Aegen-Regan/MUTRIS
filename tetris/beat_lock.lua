-- ================================================================
-- FILE: tetris/beat_lock.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: BEAT-LOCK TIMING ENGINE (FASE 7 & 20)
-- Arquitectura: Zero-GC / Hardware Clock Anclado / Jewel Groove Synergy
-- ============================================================================
local BeatLock = {}

local AudioManager = require "audio_manager"
local MusicManager = require "music_manager"
local MetaBalancer = require "core.meta_balancer"
local HuntingForge = require "combat.hunting_forge"

function BeatLock.initBoardState(board)
    board.groove_streak = 0
    board.groove_multiplier = 1.0
    board.beat_lock_flash = 0.0
    board.beat_lock_hit = false
    board.last_lock_timing_delta = 0.0
end

function BeatLock.evaluate(board, is_resonance_stance)
    local song_time = MusicManager.getTime()
    if song_time <= 0.001 then
        song_time = _G.RealMatchTimer or 0.0
    end

    local bpm = AudioManager.current_bpm or 120
    local beat_duration = 60.0 / bpm
    local current_beat = song_time / beat_duration
    local fraction = current_beat - math.floor(current_beat)
    
    local dist_to_nearest_beat = math.min(fraction, 1.0 - fraction) * beat_duration
    board.last_lock_timing_delta = dist_to_nearest_beat

    local window = is_resonance_stance 
        and (MetaBalancer.get("resonance_window_ms") or 0.045)
        or (MetaBalancer.get("beat_window_ms") or 0.035)

    if dist_to_nearest_beat <= window then
        board.beat_lock_hit = true
        board.groove_streak = board.groove_streak + 1
        board.groove_multiplier = math.min(2.0, 1.0 + (board.groove_streak * 0.10))
        board.beat_lock_flash = 1.0

        _G.AudioBeatPulse = 1.0
        AudioManager.playSubBassThud(2)

        local base_bonus = MetaBalancer.get("beat_bonus_attack") or 1
        local jewel_bonus = (board.player_type == "human") and HuntingForge.getGrooveBonusLines() or 0
        return true, base_bonus + jewel_bonus
    else
        board.beat_lock_hit = false
        board.groove_streak = 0
        board.groove_multiplier = 1.0
        return false, 0
    end
end

function BeatLock.update(board, dt)
    if board.beat_lock_flash > 0 then
        board.beat_lock_flash = math.max(0, board.beat_lock_flash - dt * 4.5)
    end
end

function BeatLock.drawFeedback(board)
    if board.beat_lock_flash > 0 then
        love.graphics.push("all")
        love.graphics.setBlendMode("add")
        love.graphics.setColor(1.0, 0.85, 0.2, board.beat_lock_flash * 0.45)
        love.graphics.rectangle("fill", board.x, board.y, 240, 480, 4)
        
        love.graphics.setLineWidth(2.5)
        love.graphics.setColor(1.0, 1.0, 0.4, board.beat_lock_flash * 0.8)
        love.graphics.rectangle("line", board.x - 2, board.y - 2, 244, 484, 4)
        love.graphics.pop()
    end
end

return BeatLock
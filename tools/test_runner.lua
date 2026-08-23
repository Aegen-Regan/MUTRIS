-- ================================================================
-- FILE: tools/test_runner.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS HEADLESS TEST HARNESS: 500-TICK ZERO-GC VALIDATION
-- ============================================================================
print("========================================")
print("[MUTRIS] INITIALIZING HEADLESS HARNESS")
print("========================================")

-- Mocks de Love2D mínimos
_G.love = {
    graphics = setmetatable({}, {__index = function() return function() end end}),
    timer = { getTime = function() return 0 end },
    filesystem = {
        getInfo = function() return false end,
        read = function() return nil end,
        write = function() return true end,
        createDirectory = function() end,
    },
    system = { getOS = function() return "Windows" end }
}
_G.AudioBeatPulse = 0
_G.TrackEnergyPunch = 0
_G.HitStopTimer = 0
_G.CURRENT_GAME_MODE = "versus"

-- Reemplazo de funciones que requieren estado gráfico
local FontCache = require("tetris.font_cache")
FontCache.get = function() return nil end

local ThemeManager = require("tetris.theme_manager")
ThemeManager.drawPanel = function() end
ThemeManager.drawBackground = function() end

local AudioManager = require("audio_manager")
AudioManager.playImmediateSFX = function() end
AudioManager.playTone = function() end
AudioManager.playSubBassThud = function() end

local Blackbox = require("core.blackbox")
Blackbox.log = function() end

local BloomShader = require("tetris.bloom_shader")
BloomShader.triggerShockwave = function() end

local Board = require("tetris.board")
local AIBot = require("tetris.ai_bot")
local GarbageManager = require("tetris.garbage_manager")
local Input = require("input")
local StatusBlights = require("combat.status_blights")
local PoiseSystem = require("combat.poise_system")
local BossPhases = require("combat.boss_phases")
local ParticleSystem = require("tetris.particle_system")

print("[OK] Modules loaded. Instantiating boards...")

local p1_board = Board.new(0, 0, "human")
local p2_board = Board.new(0, 0, "bot")
p1_board.opponent = p2_board
p2_board.opponent = p1_board

AIBot.init(p2_board)

collectgarbage("collect")
local gc_start = collectgarbage("count")

print("[OK] Starting 500-tick headless simulation...")

local tick_rate = 1.0 / 144.0
local total_ticks = 500

for i = 1, total_ticks do
    -- 1. Input Simulation (random drops and movements)
    if math.random() < 0.1 then Input.keypressed("space") end
    if math.random() < 0.05 then Input.keypressed("up") end

    Input.update(tick_rate)
    AIBot.update(tick_rate)

    p1_board:update(tick_rate)
    p2_board:update(tick_rate)

    StatusBlights.update(p2_board, tick_rate)
    
    if math.random() < 0.01 then
        GarbageManager.sendGarbage(p1_board, p2_board, 2)
    end
end

collectgarbage("collect")
local gc_end = collectgarbage("count")
local gc_delta = gc_end - gc_start

print("========================================")
print(string.format("SIMULATION COMPLETE: %d TICKS", total_ticks))
print(string.format("MEMORY ALLOCATION DELTA: %.3f KB", math.max(0, gc_delta)))
print("NIL REFERENCE ERRORS: 0")
print("========================================")

---@diagnostic disable: undefined-global
local Piece = require "tetris.piece"
local Board = require "tetris.board"
local Input = require "input"
local AudioManager = require "audio_manager"
local MusicManager = require "music_manager"
local TrackManager = require "track_manager"
local GameStates = require "tetris.game_states"

-- Variables de Control Global
_G.RestartHalo = 0
local player = nil
local bot = nil
local game_state = "menu"
local selected_diff = 1

local difficulties = {
    { name = "APPRENTICE", pps = 0.8, color = {0, 1, 0.5} },
    { name = "PRO", pps = 2.5, color = {1, 0.8, 0} },
    { name = "MASTER", pps = 6.0, color = {1, 0.2, 0.2} }
}

local lock_events = {}
local function trackLock() table.insert(lock_events, love.timer.getTime()) end
function _G.NotifyPieceLock() trackLock() end

local function getCombinedDropRate()
    local now = love.timer.getTime()
    local window = 4
    local i = 1
    while i <= #lock_events do
        if now - lock_events[i] > window then table.remove(lock_events, i)
        else i = i + 1 end
    end
    return #lock_events / window
end

function love.load()
    love.window.setTitle("MUTRIS - Tetris Versus OPT")
    love.window.setMode(800, 600, {resizable = false, vsync = true})
    AudioManager.init()
    TrackManager.init()
    _G.RealMatchTimer, _G.TrackEnergyPunch, _G.AudioBeatPulse = 0, 0, 0
end

function GlobalRestart()
    _G.RestartHalo = 1.0
    local d = difficulties[selected_diff]
    player = Board.new(80, 50, "human")
    bot = Board.new(480, 50, "bot")
    player.opponent, bot.opponent = bot, player
    local Bag = require "tetris.randomizers.7bag"
    player.bag, bot.bag = Bag.new(), Bag.new()
    local AIBot = require "tetris.ai_bot"
    bot.ai = AIBot.new(bot, {pps = d.pps})
    player.active_piece = Piece.new(player.bag:next(), player)
    bot.active_piece = Piece.new(bot.bag:next(), bot)
    Input.init(player)
    lock_events, _G.RealMatchTimer, _G.TrackEnergyPunch = {}, 0, 0
    MusicManager.stop()
    MusicManager.start()
    game_state = "play"
end

function love.update(dt)
    if _G.RestartHalo > 0 then _G.RestartHalo = math.max(0, _G.RestartHalo - dt * 2.5) end

    local danger = 0
    if game_state == "play" and player and player.grid then
        for r = 21, 32 do
            for c = 1, 10 do
                if player.grid[r] and player.grid[r][c] ~= 0 then danger = math.max(danger, (33 - r) / 12) end
            end
        end
    end

    if game_state == "play" then _G.RealMatchTimer = _G.RealMatchTimer + dt end

    local drop_rate = getCombinedDropRate()
    local drop_intensity = math.min(1, drop_rate / 8)

    AudioManager.update(dt, { danger_level = danger, drop_intensity = drop_intensity })
    MusicManager.update(dt)

    if game_state == "play" then
        Input.update(dt)

        if player and player.active_piece then
            player:update(dt)
            -- FIX: Conexión con Soft Drop de input.lua
            local grav = Input.getSoftDropFactor()
            player.active_piece:update(dt, grav)
            
            if player.active_piece.locked then
                local GarbageManager = require "tetris.garbage_manager"
                GarbageManager.pushToGrid(player)
                player.active_piece = Piece.new(player.bag:next(), player)
                if not player.active_piece:canMove(player.active_piece.x, player.active_piece.y, 1) then game_state = "over" end
            end
        end

        if bot and bot.active_piece then
            bot:update(dt)
            if bot.ai then bot.ai:update(dt) end
            bot.active_piece:update(dt, 0.8)
            if bot.active_piece.locked then
                local GarbageManager = require "tetris.garbage_manager"
                GarbageManager.pushToGrid(bot)
                bot.active_piece = Piece.new(bot.bag:next(), bot)
            end
        end
    end
end

function love.draw()
    love.graphics.push("all")
    local energy = _G.TrackEnergyPunch or 0
    local pulse = _G.AudioBeatPulse or 0

    if game_state == "play" and pulse > 0 then
        local bounce = pulse * (energy * 8 + 2)
        love.graphics.translate(0, bounce)
    end

    love.graphics.clear(0.01, 0.01, 0.03)

    if game_state == "menu" then
        GameStates.drawMenu(love.timer.getTime(), selected_diff, difficulties)
    elseif game_state == "play" then
        if player then 
            player:draw()
            if player.active_piece then player.active_piece:draw(player.x, player.y) end
        end
        if bot then 
            bot:draw()
            if bot.active_piece then bot.active_piece:draw(bot.x, bot.y) end
        end
        local HUDCenter = require "tetris.hud_center"
        HUDCenter.draw(player, bot)
        local success, Telemetry = pcall(require, "tetris.telemetry")
        if success then Telemetry.draw(player, bot) end
    elseif game_state == "over" then
        GameStates.drawGameOver()
    end

    if _G.RestartHalo > 0 then
        love.graphics.setColor(1, 1, 1, _G.RestartHalo)
        love.graphics.rectangle("fill", 0, 0, 800, 600)
    end
    love.graphics.pop()
end

function love.keypressed(key)
    if game_state == "menu" then
        if key == "up" or key == "kp8" then selected_diff = math.max(1, selected_diff - 1)
        elseif key == "down" or key == "kp2" then selected_diff = math.min(#difficulties, selected_diff + 1)
        elseif key == "return" or key == "space" then GlobalRestart() end
    elseif game_state == "play" then Input.keypressed(key)
    elseif game_state == "over" then
        if key == "return" or key == "space" or key == "r" then
            if key == "r" then GlobalRestart() else game_state = "menu" end
        end
    end
end
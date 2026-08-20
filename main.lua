---@diagnostic disable: undefined-global
local Piece = require "tetris.piece"
local Board = require "tetris.board"
local Input = require "input"
local AudioManager = require "audio_manager"
local MusicManager = require "music_manager"
local TrackManager = require "track_manager"
local GameStates = require "tetris.game_states"

_G.RestartHalo = 0
_G.Winner = nil 
_G.GameOverPending = nil

local player, bot, game_state, selected_diff = nil, nil, "menu", 1

local difficulties = {
    { name = "MASTER", pps = 6.0, color = {1, 0.2, 0.3} }
}

function love.load()
    love.window.setTitle("MUTRIS - Ethereal Engine")
    love.window.setMode(800, 600, {resizable = false, vsync = true})
    AudioManager.init()
    TrackManager.init()
    _G.RealMatchTimer, _G.TrackEnergyPunch, _G.AudioBeatPulse = 0, 0, 0
    _G.Stars = {}
    for i=1, 150 do
        _G.Stars[i] = { x = math.random(800), y = math.random(600), s = math.random(1, 2), v = math.random(10, 40) }
    end
end

function GlobalRestart()
    _G.RestartHalo, _G.Winner, _G.GameOverPending = 1.0, nil, nil
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
    MusicManager.stop()
    MusicManager.start()
    game_state = "play"
end

function love.update(dt)
    if _G.RestartHalo > 0 then _G.RestartHalo = math.max(0, _G.RestartHalo - dt * 2.0) end
    local energy = _G.TrackEnergyPunch or 0
    for _, s in ipairs(_G.Stars) do
        s.y = s.y + s.v * dt * (1 + energy * 8) 
        if s.y > 600 then s.y, s.x = 0, math.random(800) end
    end

    if game_state == "play" then
        _G.RealMatchTimer = _G.RealMatchTimer + dt
        Input.update(dt)
        AudioManager.update(dt, { danger_level = 0, drop_intensity = 0 })
        MusicManager.update(dt)

        -- Chequeo de Game Over disparado por Hold: si al hacer swap la pieza nueva
        -- no entra en el tablero, board.lua deja la bandera _G.GameOverPending con
        -- el player_type ("human"/"bot") que se topeó -- antes esto no se detectaba
        -- y el partido podía seguir con una pieza inválida.
        if _G.GameOverPending then
            game_state, _G.Winner = "over", (_G.GameOverPending == "human") and "BOT" or "PLAYER"
            _G.GameOverPending = nil
        end

        if game_state == "play" and player and player.active_piece then
            player:update(dt)
            player.active_piece:update(dt, Input.getSoftDropFactor())
            if player.active_piece.locked then
                require("tetris.garbage_manager").pushToGrid(player)
                player.active_piece = Piece.new(player.bag:next(), player)
                if not player.active_piece:canMove(player.active_piece.x, player.active_piece.y, 1) then 
                    game_state, _G.Winner = "over", "BOT"
                end
            end
        end

        if game_state == "play" and bot and bot.active_piece then
            bot:update(dt)
            if bot.ai then bot.ai:update(dt) end
            bot.active_piece:update(dt, 0.8)
            if bot.active_piece.locked then
                require("tetris.garbage_manager").pushToGrid(bot)
                bot.active_piece = Piece.new(bot.bag:next(), bot)
                if not bot.active_piece:canMove(bot.active_piece.x, bot.active_piece.y, 1) then 
                    game_state, _G.Winner = "over", "PLAYER"
                end
            end
        end
    end
end

function love.draw()
    love.graphics.push("all")
    local pulse = _G.AudioBeatPulse or 0
    love.graphics.clear(0.002, 0.002, 0.008)
    for _, s in ipairs(_G.Stars) do
        love.graphics.setColor(0.5, 0.7, 1.0, 0.2 + pulse * 0.2)
        love.graphics.circle("fill", s.x, s.y, s.s)
    end
    if game_state == "menu" then
        GameStates.drawMenu(love.timer.getTime(), selected_diff, difficulties)
    elseif game_state == "play" then
        if player then player:draw() if player.active_piece then player.active_piece:draw(player.x, player.y) end end
        if bot then bot:draw() if bot.active_piece then bot.active_piece:draw(bot.x, bot.y) end end
        require("tetris.hud_center").draw(player, bot)
        local success, Telemetry = pcall(require, "tetris.telemetry")
        if success then Telemetry.draw(player, bot) end
    elseif game_state == "over" then
        GameStates.drawGameOver()
    end
    if _G.RestartHalo > 0 then
        love.graphics.setColor(1, 1, 1, _G.RestartHalo * 0.5)
        love.graphics.rectangle("fill", 0, 0, 800, 600)
    end
    love.graphics.pop()
end

function love.keypressed(key)
    if game_state == "menu" then
        if key == "up" then selected_diff = math.max(1, selected_diff - 1)
        elseif key == "down" then selected_diff = math.min(#difficulties, selected_diff + 1)
        elseif key == "return" or key == "space" then GlobalRestart() end
    elseif game_state == "play" then Input.keypressed(key)
    elseif game_state == "over" and key == "r" then GlobalRestart() end
end
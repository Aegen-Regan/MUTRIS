-- ================================================================
-- FILE: scenes/scene_game.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: DYNAMIC GAMEPLAY SCENE
-- Fully modular, instantiates boards internally, NO GLOBALS
-- ============================================================================
local SceneGame = {}

local Board = require "tetris.board"
local AIBot = require "tetris.ai_bot"
local Input = require "input"
local EventBus = require "core.event_bus"
local ThemeManager = require "tetris.theme_manager"
local FogLayer = require "tetris.fog_layer"
local HUDPanels = require "tetris.hud_panels"
local HUDCenter = require "tetris.hud_center"
local AnomalyManager = require "tetris.anomaly_manager"
local Telemetry = require "tetris.telemetry"
local Blackbox = require "core.blackbox"

-- Internal state
SceneGame.boards = {}
SceneGame.bots = {}
SceneGame.mode = "versus"

function SceneGame.init()
end

function SceneGame.enter(data)
    local ok, err = pcall(function()
        data = data or {}
        SceneGame.last_config = data
        SceneGame.mode = data.mode or "versus"
        SceneGame.boards = {}
        SceneGame.bots = {}

        -- Fallback default config if none is provided
        local boards_config = data.boards or {
            { x = 220, y = 120, type = "human", cols = 10, rows = 40, ai_profile = nil },
            { x = 820, y = 120, type = "bot",   cols = 10, rows = 40, ai_profile = "normal" }
        }

        local human_board = nil

        local sw, sh = love.graphics.getDimensions()
        local num_boards = #boards_config
        local available_width = sw * 0.9 -- 10% margin total
        local start_x = (sw - available_width) / 2
        local segment_width = available_width / num_boards

        -- 1. Create boards
        for i, cfg in ipairs(boards_config) do
            -- Calculate block size dynamically
            local max_w = segment_width * 0.85 -- 15% padding between boards
            local max_h = sh * 0.85
            local v_rows = math.floor(cfg.rows / 2)
            
            local bs_w = math.floor(max_w / cfg.cols)
            local bs_h = math.floor(max_h / v_rows)
            local block_size = math.min(bs_w, bs_h, 32) -- Clamp max size to 32px
            
            -- Calculate precise centering for this specific board
            local board_w = cfg.cols * block_size
            local board_h = v_rows * block_size
            local center_x = start_x + (segment_width * (i - 1)) + (segment_width / 2)
            
            local bx = math.floor(center_x - (board_w / 2))
            local by = math.floor((sh - board_h) / 2)

            local b = Board.new(bx, by, cfg.type, cfg.cols, cfg.rows, block_size)
            table.insert(SceneGame.boards, b)
            
            if cfg.type == "human" then
                human_board = b
                if Input and Input.init then Input.init(b) end
            elseif cfg.type == "bot" then
                local bot = AIBot.new(b, cfg.ai_profile)
                table.insert(SceneGame.bots, bot)
            end
        end

        -- 2. Link opponents (simple round-robin for now: board N targets board N-1 or N+1)
        if #SceneGame.boards >= 2 then
            for i, b in ipairs(SceneGame.boards) do
                local opp_index = (i % #SceneGame.boards) + 1
                b.opponent = SceneGame.boards[opp_index]
            end
        end
        
        EventBus.emit("on_match_restart")
        Blackbox.log("SCENE", "Game Scene entered in mode: " .. SceneGame.mode, 0, 0)
    end)
    
    if not ok then
        local log_f = io.open("debug_log.txt", "a")
        if log_f then
            log_f:write(tostring(os.date()) .. " - SceneGame.enter ERROR: " .. tostring(err) .. "\n" .. debug.traceback() .. "\n")
            log_f:close()
        end
        error(err)
    end
end

function SceneGame.update(dt)
    local ok, err = pcall(function()
        if Input and Input.update then
            Input.update(dt)
        end

        for i = 1, #SceneGame.boards do
            SceneGame.boards[i]:update(dt)
        end
        
        for i = 1, #SceneGame.bots do
            SceneGame.bots[i]:update(dt)
        end
    end)
    
    if not ok then
        local log_f = io.open("debug_log.txt", "a")
        if log_f then
            log_f:write(tostring(os.date()) .. " - SceneGame.update ERROR: " .. tostring(err) .. "\n" .. debug.traceback() .. "\n")
            log_f:close()
        end
        error(err)
    end
end

function SceneGame.draw()
    local ok, err = pcall(function()
        if ThemeManager.drawBackground then ThemeManager.drawBackground() end
        if FogLayer.draw then FogLayer.draw() end

        for i = 1, #SceneGame.boards do
            local b = SceneGame.boards[i]
            b:draw()
            if HUDPanels.draw then HUDPanels.draw(b) end
        end

        -- Optional: Only draw center HUD if there are at least two boards
        if #SceneGame.boards >= 2 then
            local p1 = SceneGame.boards[1]
            local p2 = SceneGame.boards[2]
            if HUDCenter.draw then HUDCenter.draw(p1, p2) end
            if AnomalyManager.draw then AnomalyManager.draw(p1, p2) end
            if Telemetry.draw then Telemetry.draw(p1, p2) end
            if Blackbox.drawPermanentHUD then Blackbox.drawPermanentHUD(p1, p2) end
        end
    end)
    
    if not ok then
        local log_f = io.open("debug_log.txt", "a")
        if log_f then
            log_f:write(tostring(os.date()) .. " - SceneGame.draw ERROR: " .. tostring(err) .. "\n" .. debug.traceback() .. "\n")
            log_f:close()
        end
        -- Fallback error render
        love.graphics.setColor(1,0,0,1)
        love.graphics.print("RENDER ERROR: " .. tostring(err), 10, 10)
    end
end

function SceneGame.keypressed(key)
    if key == "r" then
        local SceneManager = require "core.scene_manager"
        -- Keep the current mode when resetting via R
        SceneManager.setState("game", SceneGame.last_config)
        return true
    end

    if Input and Input.keypressed then
        Input.keypressed(key)
    end
end

function SceneGame.gamepadpressed(joystick, button)
    if Input and Input.gamepadpressed then
        Input.gamepadpressed(joystick, button)
    end
end

function SceneGame.exit()
    SceneGame.boards = {}
    SceneGame.bots = {}
    Blackbox.log("SCENE", "Game Scene exited", 0, 0)
end

function SceneGame.exit()
    SceneGame.boards = {}
    SceneGame.bots = {}
    collectgarbage("collect")
end

return SceneGame

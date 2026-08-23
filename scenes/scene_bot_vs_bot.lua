-- ================================================================
-- FILE: scenes/scene_bot_vs_bot.lua
-- ================================================================
---@diagnostic disable: undefined-global
local SceneBotVsBot = {}

local Board          = require("tetris.board")
local Input          = require("input")
local AIBot          = require("tetris.ai_bot")
local ThemeManager   = require("tetris.theme_manager")
local FontCache      = require("tetris.font_cache")
local Telemetry      = require("tetris.telemetry")
local HUDCenter      = require("tetris.hud_center")
local HUDPanels      = require("tetris.hud_panels")
local Blackbox       = require("core.blackbox")
local SceneManager   = require("core.scene_manager")
local AnomalyManager = require("tetris.anomaly_manager")
local FogLayer       = require("tetris.fog_layer")
local TrackManager   = require("track_manager")
local ParticleSystem = require("tetris.particle_system")

local player_board = nil
local bot_board    = nil

local function drawSideTelemetry(bx, by, bw, bh, board, title)
    local theme = ThemeManager.getCurrent()
    ThemeManager.drawPanel(bx, by, bw, bh, title, false)

    local height = 0
    if board and board.grid then
        for r = 21, 40 do
            for c = 1, 10 do
                if board.grid[r][c] ~= 0 then
                    height = 41 - r
                    break
                end
            end
            if height > 0 then break end
        end
    end

    local total_garbage = 0
    if board and board.garbage_queue then
        for _, g in ipairs(board.garbage_queue) do
            total_garbage = total_garbage + (type(g) == "table" and g.lines or g or 0)
        end
    end

    love.graphics.setFont(FontCache.get(8))
    love.graphics.setColor(1.0, 0.25, 0.45, 0.95)
    love.graphics.print(string.format("HEIGHT: %02d/20", height), bx + 16, by + 30)

    love.graphics.setColor(0.65, 0.75, 0.85, 0.85)
    love.graphics.print(string.format("GARBAGE: %d", total_garbage), bx + 16, by + 46)

    if board and board.player_type == "human" then
        local stance_name = (board.current_stance == 1 and "RUSH") or (board.current_stance == 2 and "BASTION") or "RESONANCE"
        love.graphics.setColor(0.1, 0.95, 0.6, 0.9)
        love.graphics.print("ST: " .. stance_name, bx + 16, by + 62)
    else
        love.graphics.setColor(1.0, 0.85, 0.2, 0.9)
        love.graphics.print(string.format("AI: %.2f PPS", (AIBot and AIBot.pps) or 1.45), bx + 16, by + 62)
    end

    love.graphics.setColor(theme.border)
    love.graphics.line(bx + 12, by + 82, bx + bw - 12, by + 82)
    love.graphics.setColor(0.5, 0.65, 0.8, 0.8)
    love.graphics.print("EVENT LOG", bx + 16, by + 90)

    local log_str = (board and board.last_event_text) or "STD_LOCK"
    local log_time = (board and board.last_event_time) or (_G.RealMatchTimer or 0.0)
    love.graphics.setColor(0.85, 0.9, 1.0, 0.75)
    love.graphics.print(string.format("%s\nT: %04.1fs", log_str:sub(1, 12), log_time), bx + 16, by + 108)
end

local function drawBottomTimeline(time)
    local theme = ThemeManager.getCurrent()
    local y_base = 670
    local playhead_x = ((time * 85) % 1200) + 40
    
    local pulse = _G.AudioBeatPulse or 0
    local energy = _G.TrackEnergyPunch or 0
    local amp1 = 12 + (pulse * 16) + (energy * 20)
    local amp2 = 8 + (pulse * 12) + (energy * 15)

    love.graphics.setBlendMode("add")
    for i = 0, 78 do
        local x1 = 40 + i * 15
        local w1 = math.sin(time * 4.0 + i * 0.22) * amp1 + math.cos(time * 2.0 + i * 0.08) * (amp1 * 0.4)
        local w2 = math.cos(time * 3.2 + i * 0.15) * amp2

        love.graphics.setColor(theme.secondary[1], theme.secondary[2], theme.secondary[3], 0.35 + pulse * 0.35)
        love.graphics.line(x1, y_base + w1, x1 + 15, y_base + w1)

        love.graphics.setColor(theme.primary[1], theme.primary[2], theme.primary[3], 0.30 + energy * 0.4)
        love.graphics.line(x1, y_base + w2, x1 + 15, y_base + w2)

        if i % 3 == 0 then
            local tri_scale = 1.0 + (pulse * 0.6)
            love.graphics.setColor(1.0, 0.15, 0.65, 0.75 + pulse * 0.25)
            love.graphics.polygon("fill", 
                x1, y_base + 12 * tri_scale, 
                x1 + 5 * tri_scale, y_base + 4, 
                x1 + 10 * tri_scale, y_base + 12 * tri_scale
            )
        end
    end

    love.graphics.setColor(0.1, 1.0, 0.8, 0.95)
    love.graphics.setLineWidth(2.5)
    love.graphics.line(playhead_x, y_base - 22, playhead_x, y_base + 22)
    love.graphics.setBlendMode("alpha")
end

function SceneBotVsBot.init()
    -- main.lua handles board initialization for versus mode via GlobalRestart
    -- We do not create duplicate boards here to prevent hijacking the Input singleton
end

function SceneBotVsBot.enter()
    SceneBotVsBot.init()
    _G.RealMatchTimer = 0.0
    _G.CURRENT_GAME_MODE = "versus"
    Blackbox.log("MATCH", "VERSUS 1v1 ENGAGED", 0, 0)
end

function SceneBotVsBot.onEnter()
    SceneBotVsBot.enter()
end

function SceneBotVsBot.update(dt)
    _G.RealMatchTimer = (_G.RealMatchTimer or 0.0) + dt

    Input.update(dt)
    AIBot.update(dt)

    if player_board then player_board:update(dt) end
    if bot_board then bot_board:update(dt) end

    AnomalyManager.update(dt, player_board, bot_board)
    FogLayer.update(dt)
    ThemeManager.update(dt)

    -- Detección de Fin de Partida / Muerte
    local p1_dead = player_board and (player_board.is_dead or (player_board.is_dying and player_board.death_timer >= 0.8))
    local bot_dead = bot_board and (bot_board.is_dead or (bot_board.is_dying and bot_board.death_timer >= 0.8))

    if p1_dead or bot_dead then
        AIBot.registerMatchOutcome(bot_dead, (player_board and player_board.current_pps_display) or 1.2)
        SceneManager.setState("gameover")
    end
end

function SceneBotVsBot.draw()
    local theme = ThemeManager.getCurrent()
    local time = _G.RealMatchTimer or 0.0

    ThemeManager.drawBackground()
    FogLayer.draw()

    -- 1. Paneles Laterales de Telemetría
    drawSideTelemetry(60, 140, 120, 420, player_board, "P1 TELEM")
    drawSideTelemetry(1100, 140, 120, 420, bot_board, "BOT TELEM")

    -- 2. Dron / Orbe Palico & Indicadores SHDR
    local orb_y = 300 + math.sin(time * 3.5) * 8
    love.graphics.setBlendMode("add")
    love.graphics.setColor(0.1, 0.95, 1.0, 0.4)
    love.graphics.circle("fill", 175, orb_y, 10)
    love.graphics.setColor(1.0, 0.2, 0.65, 0.8)
    love.graphics.circle("line", 175, orb_y, 12)

    love.graphics.setFont(FontCache.get(7))
    love.graphics.setColor(1.0, 0.3, 0.5, 0.9)
    love.graphics.print("SHDR", 192, 250)
    love.graphics.setColor(0.1, 0.9, 1.0, 0.8)
    love.graphics.rectangle("fill", 192, 260, 3, 18)
    love.graphics.setColor(1.0, 0.85, 0.1, 0.8)
    love.graphics.rectangle("fill", 198, 255, 3, 23)
    love.graphics.setColor(0.1, 1.0, 0.5, 0.8)
    love.graphics.rectangle("fill", 204, 265, 3, 13)
    love.graphics.setBlendMode("alpha")

    -- 3. Tableros Principales
    if player_board then player_board:draw() end
    if bot_board then bot_board:draw() end

    -- 4. Paneles HUD & Marcadores
    HUDPanels.draw(player_board, bot_board)
    HUDCenter.draw(player_board, bot_board)
    Telemetry.draw(player_board, bot_board)

    -- 5. LIVE FLIGHT RECORDER
    ThemeManager.drawPanel(480, 240, 320, 220, "LIVE FLIGHT RECORDER", false)
    local events = Blackbox and (Blackbox.events or Blackbox.log_buffer)
    love.graphics.setFont(FontCache.get(8))
    if events and #events > 0 then
        local max_ev = math.min(7, #events)
        local start_idx = math.max(1, #events - max_ev + 1)
        local ey = 265
        for i = #events, start_idx, -1 do
            local ev = events[i]
            local tag = tostring(ev.tag or ev[1] or "HOTFIX")
            local msg = tostring(ev.msg or ev[2] or "PAYLOAD EXECUTED")
            local t_sec = ev.time or (time - (i * 0.1))

            love.graphics.setColor(1.0, 0.25, 0.45, 0.95)
            love.graphics.print(string.format("[%04.1fs]", t_sec), 495, ey)

            love.graphics.setColor(theme.primary[1], theme.primary[2], theme.primary[3], 0.95)
            love.graphics.print(tag, 545, ey)

            love.graphics.setColor(0.7, 0.85, 0.95, 0.8)
            love.graphics.print("| " .. msg:sub(1, 26), 610, ey)
            ey = ey + 20
        end
    else
        love.graphics.setColor(0.5, 0.6, 0.7, 0.7)
        love.graphics.printf("STREAMING TELEMETRY BUS...", 480, 340, 320, "center")
    end

    AnomalyManager.draw(player_board, bot_board)
    drawBottomTimeline(time)

    -- Marca de versión obligatoria
    love.graphics.setFont(FontCache.get(9))
    love.graphics.setColor(0.0, 0.85, 1.0, 0.65)
    love.graphics.print((_G.ENGINE_VERSION or "MUTRIS v1.0.0") .. " | SKIN: " .. theme.name, 16, 698)
end

function SceneBotVsBot.keypressed(key)
    if key == "r" then
        TrackManager.nextTrack()
        ThemeManager.triggerRestartHalo()
        SceneBotVsBot.enter()
        return true
    elseif key == "f6" then
        ThemeManager.cyclePrev()
        return true
    elseif key == "escape" then
        SceneManager.setState("menu")
        return true
    end
    return false
end

function SceneBotVsBot.gamepadpressed(joystick, button)
    Input.gamepadpressed(joystick, button)
end

return SceneBotVsBot

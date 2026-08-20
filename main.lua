---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: SYNTHETIC TRANSCENDENCE [KERNEL CENTRAL 1280x720 WIDESCREEN]
-- Arquitectura Zero-GC / F9 Clip Recorder / F12 Screenshot / Crash-Proof Loop
-- ============================================================================

_G.ENGINE_VERSION       = "MUTRIS v1.0.0"
_G.RealMatchTimer       = 0.0
_G.HitStopTimer         = 0.0
_G.AudioBeatPulse       = 0.0
_G.TrackEnergyPunch     = 0.0
_G.CURRENT_GAME_MODE    = "versus"
_G.IS_DEMO_MODE         = false
_G.IsBlackoutActive     = false
_G.BlackoutStrobeVisibility = 1.0

local SettingsManager    = require "settings_manager"
local AudioManager       = require "audio_manager"
local MusicManager       = require "music_manager"
local TrackManager       = require "track_manager"
local TrackEditor        = require "track_editor"
local MetaBalancer       = require "core.meta_balancer"
local CombatStances      = require "combat.combat_stances"
local AnomalyManager     = require "tetris.anomaly_manager"
local BloomShader        = require "tetris.bloom_shader"
local FogLayer           = require "tetris.fog_layer"
local HUDCenter          = require "tetris.hud_center"
local HUDPanels          = require "tetris.hud_panels"
local Telemetry          = require "tetris.telemetry"
local FontCache          = require "tetris.font_cache"
local Board              = require "tetris.board"
local AIBot              = require "tetris.ai_bot"
local Input              = require "input"
local Blackbox           = require "core.blackbox"
local ScreenshotHelper   = require "core.screenshot_helper"
local ReplayManager      = require "core.replay_manager"
local ClipRecorder       = require "core.clip_recorder"

local gameState = "menu"
local menuSelection = 1
local menuItems = {
    "VS BOT DUEL",
    "GAUNTLET RUSH",
    "SOUNDTRACK & FX LAB",
    "SETTINGS"
}
local menuSubtitles = {
    "CLASSIC 1v1 DUEL VS ADAPTIVE DDA BOT",
    "ENDLESS SURVIVAL AGAINST FREQUENT ANOMALIES",
    "DAW TIMELINE, CUE PLACEMENT & SFX AUDITION",
    "REMAP CONTROLS, DAS / ARR & AUDIO MIXER"
}

local PlayerBoard = nil
local BotBoard    = nil

local view_scale = 1.0
local view_ox = 0
local view_oy = 0
local screenshot_flash_timer = 0.0

local function updateViewScaling()
    local win_w, win_h = love.graphics.getDimensions()
    local scale_x = win_w / 1280
    local scale_y = win_h / 720
    view_scale = math.min(scale_x, scale_y)
    view_ox = math.floor((win_w - 1280 * view_scale) / 2)
    view_oy = math.floor((win_h - 720 * view_scale) / 2)
end

function _G.ToggleFullscreen()
    local is_fs = love.window.getFullscreen()
    love.window.setFullscreen(not is_fs, "desktop")
    updateViewScaling()
    Blackbox.log("SYSTEM", "FULLSCREEN: " .. tostring(not is_fs), 0, 0)
end

function _G.TakeScreenshot()
    AudioManager.playSliderTick()
    screenshot_flash_timer = 1.5
    ScreenshotHelper.capture(function(copied, filename)
        if PlayerBoard and PlayerBoard.setPopup then
            PlayerBoard:setPopup("COPIED TO CLIPBOARD! (CTRL+V)", {0.1, 1.0, 0.5}, true, "SCREENSHOT READY")
        end
    end)
end

function _G.ToggleRecording()
    AudioManager.playSliderTick()
    ClipRecorder.toggle(function(frames, base_path)
        if PlayerBoard and PlayerBoard.setPopup then
            PlayerBoard:setPopup(string.format("CLIP SAVED! (%d FRAMES)", frames), {0.2, 0.95, 1.0}, true, "SAVED TO recordings/")
        end
    end)
end

function _G.SetGameState(state)
    gameState = state
    Blackbox.log("STATE", "STATE: " .. state, 0, 0)
end

function _G.GlobalRestart()
    _G.RealMatchTimer = 0.0
    _G.HitStopTimer = 0.0
    _G.AudioBeatPulse = 0.0
    _G.TrackEnergyPunch = 0.0

    PlayerBoard = Board.new(220, 120, "human")
    BotBoard    = Board.new(820, 120, "bot")
    PlayerBoard.opponent = BotBoard
    BotBoard.opponent    = PlayerBoard

    AIBot.board    = BotBoard
    AIBot.opponent = PlayerBoard
    AIBot.player   = PlayerBoard
    BotBoard.ai    = AIBot

    Input.init(PlayerBoard)
    
    if AIBot.init then 
        AIBot.init(BotBoard)
        AIBot.board = BotBoard
    end
    if AnomalyManager.init then 
        AnomalyManager.init() 
    end

    ReplayManager.startRecording(_G.CURRENT_GAME_MODE, math.random(100000, 999999), "MUTRIS_TRACK")
    Blackbox.log("MATCH", "RESTART EXECUTED", 0, 0)
end

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    updateViewScaling()
    Blackbox.init()
    ClipRecorder.init()
    
    if SettingsManager.init then SettingsManager.init() end
    if MetaBalancer.init    then MetaBalancer.init() end
    if AudioManager.init    then AudioManager.init() end
    if TrackManager.init    then TrackManager.init() end
    if BloomShader.init     then BloomShader.init() end
    if FogLayer.init        then FogLayer.init() end
    
    if MusicManager.start then 
        MusicManager.start() 
    elseif MusicManager.init then 
        MusicManager.init() 
    end

    _G.GlobalRestart()
end

function love.resize(w, h)
    updateViewScaling()
end

function love.update(dt)
    if screenshot_flash_timer > 0 then
        screenshot_flash_timer = math.max(0, screenshot_flash_timer - dt)
    end

    if _G.HitStopTimer > 0 then
        _G.HitStopTimer = math.max(0, _G.HitStopTimer - dt)
        return
    end

    AudioManager.update(dt)
    if MusicManager.update then MusicManager.update(dt) end
    BloomShader.update(dt)
    FogLayer.update(dt)
    ClipRecorder.update(dt)
    ReplayManager.update(dt)

    if gameState == "editor" then
        TrackEditor.update(dt)
        return
    end

    if gameState == "versus" or gameState == "gauntlet" then
        _G.RealMatchTimer = _G.RealMatchTimer + dt

        Input.update(dt)
        if PlayerBoard then PlayerBoard:update(dt) end
        
        if BotBoard then
            AIBot.board = BotBoard
            AIBot.opponent = PlayerBoard
            if AIBot.update and not BotBoard.is_dying then
                AIBot:update(dt)
            end
            BotBoard:update(dt)
        end

        AnomalyManager.update(dt, PlayerBoard, BotBoard)

        local p1_pps = (PlayerBoard and PlayerBoard.current_pps_display) or 0.0
        local bot_pps = (BotBoard and BotBoard.current_pps_display) or 0.0

        if PlayerBoard and PlayerBoard.is_dying and PlayerBoard.death_timer <= 0.05 then
            MetaBalancer.registerMatchOutcome(false, _G.RealMatchTimer, p1_pps, bot_pps)
            ReplayManager.saveReplay()
            Blackbox.log("MATCH_END", "PLAYER DEFEATED", math.floor(p1_pps * 10), math.floor(bot_pps * 10))
            gameState = "gameover"
        elseif BotBoard and BotBoard.is_dying and BotBoard.death_timer <= 0.05 then
            MetaBalancer.registerMatchOutcome(true, _G.RealMatchTimer, p1_pps, bot_pps)
            ReplayManager.saveReplay()
            Blackbox.log("MATCH_END", "BOT DEFEATED", math.floor(p1_pps * 10), math.floor(bot_pps * 10))
            gameState = "gameover"
        end
    end
end

local function drawCyberMenu()
    local pulse = _G.AudioBeatPulse or 0
    local time = love.timer.getTime()

    love.graphics.setLineWidth(1)
    love.graphics.setColor(0, 0.7, 1.0, 0.04 + pulse * 0.04)
    for x = 0, 1280, 40 do love.graphics.line(x, 0, x, 720) end
    for y = 0, 720, 40 do love.graphics.line(0, y, 1280, y) end

    love.graphics.setFont(FontCache.get(42))
    love.graphics.setColor(0, 0.8, 1, 0.25 + pulse * 0.35)
    love.graphics.printf("MUTRIS", 0, 80, 1280, "center")
    love.graphics.setColor(1, 1, 1, 0.98)
    love.graphics.printf("MUTRIS", 0, 78, 1280, "center")

    love.graphics.setFont(FontCache.get(16))
    love.graphics.setColor(0, 0.85, 1, 0.90)
    love.graphics.printf("SYNTHETIC TRANSCENDENCE", 0, 135, 1280, "center")

    love.graphics.setColor(0.01, 0.03, 0.08, 0.85)
    love.graphics.rectangle("fill", 440, 168, 400, 24, 4)
    love.graphics.setColor(0, 0.6, 0.9, 0.35 + pulse * 0.25)
    love.graphics.rectangle("line", 440, 168, 400, 24, 4)

    love.graphics.setFont(FontCache.get(10))
    love.graphics.setColor(0.4, 0.85, 1.0, 0.85)
    love.graphics.printf("ZERO-GC ENGINE  |  144/240Hz  |  SINESTHETIC COMBAT", 440, 173, 400, "center")

    local btn_w = 480
    local btn_h = 56
    local start_y = 225
    local spacing = 70

    for i, item in ipairs(menuItems) do
        local is_sel = (i == menuSelection)
        local btn_x = 640 - (btn_w / 2)
        local btn_y = start_y + (i - 1) * spacing

        if is_sel then
            local fill_alpha = 0.40 + pulse * 0.20
            love.graphics.setColor(0.0, 0.25, 0.45, fill_alpha)
            love.graphics.rectangle("fill", btn_x, btn_y, btn_w, btn_h, 6)

            local glow = 0.7 + math.sin(time * 8) * 0.3
            love.graphics.setLineWidth(2.0)
            love.graphics.setColor(1.0, 0.85, 0.2, glow)
            love.graphics.rectangle("line", btn_x, btn_y, btn_w, btn_h, 6)

            love.graphics.setColor(1.0, 0.85, 0.2, 0.95)
            love.graphics.rectangle("fill", btn_x + 4, btn_y + 8, 4, btn_h - 16, 2)
            love.graphics.rectangle("fill", btn_x + btn_w - 8, btn_y + 8, 4, btn_h - 16, 2)

            love.graphics.setFont(FontCache.get(16))
            love.graphics.setColor(1.0, 0.95, 0.4, 1.0)
            love.graphics.printf(">  " .. item .. "  <", btn_x, btn_y + 12, btn_w, "center")

            love.graphics.setFont(FontCache.get(9))
            love.graphics.setColor(0.8, 0.9, 1.0, 0.8)
            love.graphics.printf(menuSubtitles[i] or "", btn_x, btn_y + 34, btn_w, "center")
        else
            love.graphics.setColor(0.01, 0.02, 0.05, 0.70)
            love.graphics.rectangle("fill", btn_x, btn_y, btn_w, btn_h, 6)

            love.graphics.setLineWidth(1.0)
            love.graphics.setColor(0, 0.6, 0.9, 0.22)
            love.graphics.rectangle("line", btn_x, btn_y, btn_w, btn_h, 6)

            love.graphics.setFont(FontCache.get(15))
            love.graphics.setColor(0.65, 0.75, 0.85, 0.75)
            love.graphics.printf(item, btn_x, btn_y + 13, btn_w, "center")

            love.graphics.setFont(FontCache.get(9))
            love.graphics.setColor(0.4, 0.5, 0.6, 0.6)
            love.graphics.printf(menuSubtitles[i] or "", btn_x, btn_y + 35, btn_w, "center")
        end
    end

    local p_w = 540
    local p_h = 30
    local p_x = 640 - (p_w / 2)
    local p_y = 535

    love.graphics.setColor(0.01, 0.02, 0.04, 0.90)
    love.graphics.rectangle("fill", p_x, p_y, p_w, p_h, 4)

    love.graphics.setLineWidth(1.2)
    love.graphics.setColor(0.1, 0.9, 0.5, 0.45 + pulse * 0.25)
    love.graphics.rectangle("line", p_x, p_y, p_w, p_h, 4)

    love.graphics.setFont(FontCache.get(10))
    love.graphics.setColor(0.2, 0.95, 0.6, 0.95)
    local patch_str = "[ ARCHON ] " .. (MetaBalancer.patch_notes or "BASELINE EQUILIBRIUM ACTIVE")
    love.graphics.printf(patch_str, p_x, p_y + 8, p_w, "center")

    love.graphics.setFont(FontCache.get(10))
    love.graphics.setColor(0.45, 0.55, 0.65, 0.75)
    love.graphics.printf("[ UP / DOWN ] NAVEGAR  |  [ ENTER ] SELECCIONAR  |  [ F9 ] GRABAR CLIP  |  [ F12 ] CAPTURA", 0, 600, 1280, "center")
end

function love.draw()
    love.graphics.clear(0.01, 0.01, 0.02, 1.0)

    -- 1. Renderizado del Canvas nativo del juego
    BloomShader.beginDraw()
    FogLayer.draw()

    if gameState == "menu" then
        drawCyberMenu()

    elseif gameState == "versus" or gameState == "gauntlet" or gameState == "gameover" then
        if PlayerBoard then
            PlayerBoard:draw()
            HUDPanels.draw(PlayerBoard)
        end
        if BotBoard then
            BotBoard:draw()
            HUDPanels.draw(BotBoard)
        end

        HUDCenter.draw(PlayerBoard, BotBoard)
        AnomalyManager.draw(PlayerBoard, BotBoard)
        Telemetry.draw(PlayerBoard, BotBoard)
        Blackbox.drawPermanentHUD(PlayerBoard, BotBoard)

        if gameState == "gameover" then
            love.graphics.setColor(0, 0, 0, 0.75)
            love.graphics.rectangle("fill", 0, 0, 1280, 720)
            love.graphics.setFont(FontCache.get(38))
            if PlayerBoard and PlayerBoard.is_dying then
                love.graphics.setColor(1.0, 0.2, 0.3, 0.95)
                love.graphics.printf("ANNIHILATED", 0, 260, 1280, "center")
            else
                love.graphics.setColor(0.1, 1.0, 0.5, 0.95)
                love.graphics.printf("VICTORY ACHIEVED", 0, 260, 1280, "center")
            end
            love.graphics.setFont(FontCache.get(15))
            love.graphics.setColor(1, 1, 1, 0.85)
            love.graphics.printf("PRESS [R] OR [START] TO REMATCH | [ESC] MENU", 0, 340, 1280, "center")
        end

    elseif gameState == "editor" then
        TrackEditor.draw()
    end

    -- ⚠️ DIRECTIVA PRIMARIA PERMANENTE (REGLA DE ORO)
    love.graphics.push("all")
    love.graphics.setFont(FontCache.get(10))
    love.graphics.setColor(0.4, 0.85, 1.0, 0.9)
    love.graphics.print(_G.ENGINE_VERSION, 16, 698)
    love.graphics.pop()

    -- 2. Volcado del Canvas a la ventana (libera el canvas activo)
    BloomShader.endDraw(PlayerBoard and PlayerBoard.is_zone_active, view_ox, view_oy, view_scale)

    -- 🎥 3. Captura del Canvas YA liberado (Sin errores de framebuffer y sin el badge REC)
    if ClipRecorder.is_recording and BloomShader.canvas then
        ClipRecorder.captureFrame(BloomShader.canvas)
    end

    -- 4. Indicador REC y Feedback de Captura
    ClipRecorder.drawHUDIndicator()

    if screenshot_flash_timer > 0 then
        local a = math.min(1.0, screenshot_flash_timer * 1.5)
        love.graphics.setColor(0.01, 0.03, 0.06, 0.90 * a)
        love.graphics.rectangle("fill", (1280 - 400) / 2, 30, 400, 36, 6)
        love.graphics.setLineWidth(1.5)
        love.graphics.setColor(0.1, 1.0, 0.5, 0.90 * a)
        love.graphics.rectangle("line", (1280 - 400) / 2, 30, 400, 36, 6)
        love.graphics.setFont(FontCache.get(11))
        love.graphics.printf("COPIED TO CLIPBOARD! (CTRL+V)", (1280 - 400) / 2, 40, 400, "center")
    end
end

function love.keypressed(key)
    -- 🎥 GRABAR CLIP (F9 Toggle con feedback visual al guardar)
    if key == "f9" then
        _G.ToggleRecording()
        return
    end

    -- 📸 CAPTURA DE PANTALLA (F12, F2 o PrintScreen)
    if key == "f12" or key == "f2" or key == "printscreen" or key == "sysrq" then
        _G.TakeScreenshot()
        return
    end

    -- 🖥️ PANTALLA COMPLETA
    if key == "f11" or (key == "return" and (love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt"))) then
        _G.ToggleFullscreen()
        return
    end

    if key == "f8" then
        Blackbox.dumpToFile("saves/manual_snapshot.txt", "MANUAL F8 DIAGNOSTIC SNAPSHOT")
        if PlayerBoard then PlayerBoard:setPopup("DIAGNOSTIC DUMP SAVED", {0.1, 0.9, 0.5}) end
        return
    end

    if gameState == "editor" then
        TrackEditor.keypressed(key)
        return
    end

    if key == "escape" then
        if gameState == "menu" then
            love.event.quit()
        else
            gameState = "menu"
            if MusicManager.stop then MusicManager.stop() end
            if MusicManager.start then MusicManager.start() end
        end
        return
    end

    if gameState == "menu" then
        if key == "up" then
            menuSelection = (menuSelection == 1) and #menuItems or (menuSelection - 1)
            AudioManager.playMenuHover()
        elseif key == "down" then
            menuSelection = (menuSelection % #menuItems) + 1
            AudioManager.playMenuHover()
        elseif key == "return" or key == "space" then
            AudioManager.playMenuClick()
            if menuSelection == 1 then
                _G.CURRENT_GAME_MODE = "versus"
                _G.GlobalRestart()
                gameState = "versus"
            elseif menuSelection == 2 then
                _G.CURRENT_GAME_MODE = "gauntlet"
                _G.GlobalRestart()
                gameState = "gauntlet"
            elseif menuSelection == 3 then
                TrackEditor.active = true
                gameState = "editor"
            elseif menuSelection == 4 then
            end
        end
        return
    end

    if gameState == "gameover" then
        if key == "r" then
            _G.GlobalRestart()
            gameState = _G.CURRENT_GAME_MODE or "versus"
        end
        return
    end

    Input.keypressed(key)
end

function love.gamepadpressed(joystick, button)
    if gameState == "versus" or gameState == "gauntlet" then
        Input.gamepadpressed(joystick, button)
    elseif gameState == "gameover" then
        if button == "start" or button == "a" then
            _G.GlobalRestart()
            gameState = _G.CURRENT_GAME_MODE or "versus"
        end
    end
end

function love.mousepressed(x, y, button)
    if gameState == "editor" then
        local adj_x = (x - view_ox) / view_scale
        local adj_y = (y - view_oy) / view_scale
        TrackEditor.mousepressed(adj_x, adj_y, button)
    end
end

function love.errorhandler(msg)
    local err_text = tostring(msg) .. "\n\n" .. debug.traceback("", 2)
    pcall(Blackbox.dumpToFile, "saves/crash_report.txt", err_text)
    
    return function()
        love.event.pump()
        for e, a in love.event.poll() do
            if e == "quit" or (e == "keypressed" and a == "escape") then
                return 1
            end
        end

        love.graphics.origin()
        love.graphics.clear(0.02, 0.01, 0.04)
        
        love.graphics.setFont(love.graphics.newFont(18))
        love.graphics.setColor(1.0, 0.2, 0.3, 1.0)
        love.graphics.print("! MUTRIS ENGINE CRASH DETECTED !", 40, 40)
        
        love.graphics.setFont(love.graphics.newFont(12))
        love.graphics.setColor(0.2, 0.9, 0.6, 0.9)
        love.graphics.print("Flight recorder report saved to: saves/crash_report.txt  |  [ ESC ] TO EXIT", 40, 75)
        
        love.graphics.setColor(0.8, 0.8, 0.85, 0.95)
        love.graphics.printf(err_text, 40, 115, 1200, "left")
        
        love.graphics.setColor(0.4, 0.85, 1.0, 0.9)
        love.graphics.print(_G.ENGINE_VERSION, 16, 698)
        love.graphics.present()
    end
end
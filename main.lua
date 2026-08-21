-- ================================================================
-- FILE: main.lua
-- ================================================================
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
local previousState = "menu"
local menuSelection = 1
local pauseSelection = 1
local settingsSelection = 1
local is_dragging_slider = false

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

local pauseItems = {
    "RESUME MATCH",
    "RESTART & NEXT TRACK",
    "SETTINGS & CALIBRATION",
    "QUIT TO MAIN MENU"
}
local pauseSubtitles = {
    "RETURN TO COMBAT IMMEDIATELY [ESC]",
    "RELOAD MATRIX & ROTATE SOUNDTRACK [R]",
    "CALIBRATE DAS, ARR & AUDIO LEVELS",
    "ABORT CURRENT MATCH AND RETURN TO TITLE"
}

local settingsRows = {
    { id = "das",    label = "DAS (DELAYED AUTO-SHIFT)", min = 50, max = 200, step = 1, unit = "ms" },
    { id = "arr",    label = "ARR (AUTO-REPEAT RATE)",  min = 0,  max = 25,  step = 1, unit = "ms" },
    { id = "master", label = "MASTER VOLUME",           min = 0,  max = 100, step = 5, unit = "%" },
    { id = "bgm",    label = "MUSIC VOLUME (BGM)",      min = 0,  max = 100, step = 5, unit = "%" },
    { id = "sfx",    label = "SOUND FX VOLUME (SFX)",   min = 0,  max = 100, step = 5, unit = "%" },
    { id = "mute",   label = "MUTE ALL AUDIO",          is_toggle = true }
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
    previousState = gameState
    gameState = state
    Blackbox.log("STATE", "STATE: " .. state, 0, 0)
end

function _G.GlobalRestart(skip_track_advance)
    _G.RealMatchTimer = 0.0
    _G.HitStopTimer = 0.0
    _G.AudioBeatPulse = 0.0
    _G.TrackEnergyPunch = 0.0

    -- Rotación obligatoria de canción en reinicio
    if not skip_track_advance then
        TrackManager.nextTrack()
    end
    MusicManager.stop()
    MusicManager.start()

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

    local track_info = TrackManager.getCurrentTrack()
    local track_name = track_info and track_info.name or "MUTRIS_TRACK"
    ReplayManager.startRecording(_G.CURRENT_GAME_MODE, math.random(100000, 999999), track_name)
    Blackbox.log("MATCH", "RESTART EXECUTED: " .. track_name, 0, 0)
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

    _G.GlobalRestart(true)
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

    if gameState == "pause" or gameState == "settings" then
        -- En pausa o ajustes no corre la física de piezas ni el temporizador de combate
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

local function drawCyberPause()
    love.graphics.setColor(0.0, 0.0, 0.0, 0.75)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    local pulse = _G.AudioBeatPulse or 0
    local time = love.timer.getTime()

    local card_w = 500
    local card_h = 440
    local card_x = 640 - (card_w / 2)
    local card_y = 140

    love.graphics.setColor(0.01, 0.02, 0.05, 0.94)
    love.graphics.rectangle("fill", card_x, card_y, card_w, card_h, 8)

    love.graphics.setLineWidth(2.0)
    love.graphics.setColor(0.0, 0.8, 1.0, 0.45 + pulse * 0.3)
    love.graphics.rectangle("line", card_x, card_y, card_w, card_h, 8)

    love.graphics.setFont(FontCache.get(28))
    love.graphics.setColor(0.1, 0.9, 1.0, 0.95)
    love.graphics.printf("MATCH PAUSED", card_x, card_y + 20, card_w, "center")

    local track_info = TrackManager.getCurrentTrack()
    local track_title = track_info and track_info.name or "UNKNOWN TRACK"
    local track_bpm = track_info and track_info.bpm or 120
    love.graphics.setFont(FontCache.get(11))
    love.graphics.setColor(0.5, 0.65, 0.85, 0.85)
    love.graphics.printf("TRACK: " .. track_title .. " (" .. track_bpm .. " BPM)", card_x, card_y + 58, card_w, "center")

    local btn_w = 420
    local btn_h = 52
    local start_y = card_y + 90
    local spacing = 64

    for i, item in ipairs(pauseItems) do
        local is_sel = (i == pauseSelection)
        local btn_x = 640 - (btn_w / 2)
        local btn_y = start_y + (i - 1) * spacing

        if is_sel then
            local glow = 0.7 + math.sin(time * 8) * 0.3
            love.graphics.setColor(0.0, 0.30, 0.50, 0.50)
            love.graphics.rectangle("fill", btn_x, btn_y, btn_w, btn_h, 6)

            love.graphics.setLineWidth(1.8)
            love.graphics.setColor(1.0, 0.85, 0.2, glow)
            love.graphics.rectangle("line", btn_x, btn_y, btn_w, btn_h, 6)

            love.graphics.setColor(1.0, 0.85, 0.2, 0.95)
            love.graphics.rectangle("fill", btn_x + 4, btn_y + 6, 4, btn_h - 12, 2)
            love.graphics.rectangle("fill", btn_x + btn_w - 8, btn_y + 6, 4, btn_h - 12, 2)

            love.graphics.setFont(FontCache.get(15))
            love.graphics.setColor(1.0, 0.95, 0.4, 1.0)
            love.graphics.printf(">  " .. item .. "  <", btn_x, btn_y + 10, btn_w, "center")

            love.graphics.setFont(FontCache.get(9))
            love.graphics.setColor(0.8, 0.9, 1.0, 0.85)
            love.graphics.printf(pauseSubtitles[i] or "", btn_x, btn_y + 32, btn_w, "center")
        else
            love.graphics.setColor(0.02, 0.03, 0.07, 0.75)
            love.graphics.rectangle("fill", btn_x, btn_y, btn_w, btn_h, 6)

            love.graphics.setLineWidth(1.0)
            love.graphics.setColor(0.0, 0.6, 0.9, 0.25)
            love.graphics.rectangle("line", btn_x, btn_y, btn_w, btn_h, 6)

            love.graphics.setFont(FontCache.get(14))
            love.graphics.setColor(0.7, 0.8, 0.9, 0.8)
            love.graphics.printf(item, btn_x, btn_y + 11, btn_w, "center")

            love.graphics.setFont(FontCache.get(9))
            love.graphics.setColor(0.4, 0.5, 0.6, 0.65)
            love.graphics.printf(pauseSubtitles[i] or "", btn_x, btn_y + 32, btn_w, "center")
        end
    end

    love.graphics.setFont(FontCache.get(10))
    love.graphics.setColor(0.45, 0.55, 0.65, 0.8)
    love.graphics.printf("[ ESC ] REANUDAR  |  [ R ] REINICIAR Y CAMBIAR CANCION  |  [ ENTER ] SELECCIONAR", 0, card_y + card_h + 20, 1280, "center")
end

local function drawCyberSettings()
    local pulse = _G.AudioBeatPulse or 0
    local time = love.timer.getTime()

    love.graphics.setLineWidth(1)
    love.graphics.setColor(0, 0.7, 1.0, 0.04 + pulse * 0.04)
    for x = 0, 1280, 40 do love.graphics.line(x, 0, x, 720) end
    for y = 0, 720, 40 do love.graphics.line(0, y, 1280, y) end

    love.graphics.setFont(FontCache.get(34))
    love.graphics.setColor(0.1, 0.9, 1.0, 0.95)
    love.graphics.printf("CALIBRATION & SETTINGS", 0, 50, 1280, "center")

    love.graphics.setFont(FontCache.get(12))
    love.graphics.setColor(0.5, 0.65, 0.85, 0.85)
    love.graphics.printf("COMPETITIVE DAS / ARR TIMINGS & AUDIO ENGINE TUNING", 0, 92, 1280, "center")

    local card_w = 700
    local card_h = 440
    local card_x = 640 - (card_w / 2)
    local card_y = 125

    love.graphics.setColor(0.01, 0.02, 0.05, 0.92)
    love.graphics.rectangle("fill", card_x, card_y, card_w, card_h, 8)
    love.graphics.setLineWidth(1.5)
    love.graphics.setColor(0.0, 0.7, 1.0, 0.35 + pulse * 0.2)
    love.graphics.rectangle("line", card_x, card_y, card_w, card_h, 8)

    local s = SettingsManager.settings
    local row_start_y = card_y + 30
    local row_spacing = 58

    for i, r in ipairs(settingsRows) do
        local is_sel = (i == settingsSelection)
        local ry = row_start_y + (i - 1) * row_spacing

        if is_sel then
            love.graphics.setColor(0.0, 0.25, 0.45, 0.35)
            love.graphics.rectangle("fill", card_x + 16, ry - 6, card_w - 32, 48, 4)
            love.graphics.setLineWidth(1.2)
            love.graphics.setColor(1.0, 0.85, 0.2, 0.85)
            love.graphics.rectangle("line", card_x + 16, ry - 6, card_w - 32, 48, 4)
        end

        love.graphics.setFont(FontCache.get(12))
        love.graphics.setColor(is_sel and {1.0, 0.95, 0.4, 1.0} or {0.75, 0.85, 0.95, 0.85})
        love.graphics.print(r.label, card_x + 32, ry + 2)

        local slider_x = card_x + 360
        local slider_y = ry + 2
        local slider_w = 220
        local slider_h = 18

        if r.is_toggle then
            local is_muted = (s.mute_all and s.mute_all >= 0.5)
            love.graphics.setColor(is_muted and {0.8, 0.1, 0.2, 0.85} or {0.1, 0.8, 0.4, 0.85})
            love.graphics.rectangle("fill", slider_x, slider_y - 2, 90, 22, 4)
            love.graphics.setColor(1, 1, 1, 0.95)
            love.graphics.setFont(FontCache.get(11))
            love.graphics.printf(is_muted and "MUTED" or "ACTIVE", slider_x, slider_y + 1, 90, "center")
        else
            love.graphics.setColor(0.02, 0.04, 0.08, 0.9)
            love.graphics.rectangle("fill", slider_x, slider_y, slider_w, slider_h, 3)
            love.graphics.setColor(0.0, 0.6, 1.0, 0.35)
            love.graphics.rectangle("line", slider_x, slider_y, slider_w, slider_h, 3)

            local cur_val = 0
            if r.id == "das" then cur_val = s.das * 1000
            elseif r.id == "arr" then cur_val = s.arr * 1000
            elseif r.id == "master" then cur_val = (s.master_vol or 1.0) * 100
            elseif r.id == "bgm" then cur_val = (s.bgm_vol or 1.0) * 100
            elseif r.id == "sfx" then cur_val = (s.sfx_vol or 1.0) * 100
            end

            local pct = (cur_val - r.min) / math.max(1, (r.max - r.min))
            pct = math.max(0, math.min(1, pct))

            love.graphics.setColor(0.0, 0.85, 1.0, 0.8)
            love.graphics.rectangle("fill", slider_x + 2, slider_y + 2, (slider_w - 4) * pct, slider_h - 4, 2)

            love.graphics.setFont(FontCache.get(11))
            love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
            local val_str = string.format("%d %s", math.floor(cur_val + 0.5), r.unit)
            love.graphics.print(val_str, slider_x + slider_w + 14, slider_y + 1)
        end
    end

    local btn_save_w = 260
    local btn_save_h = 42
    local btn_save_x = 640 - (btn_save_w / 2)
    local btn_save_y = card_y + card_h - 56

    love.graphics.setColor(0.0, 0.5, 0.3, 0.75)
    love.graphics.rectangle("fill", btn_save_x, btn_save_y, btn_save_w, btn_save_h, 6)
    love.graphics.setLineWidth(1.5)
    love.graphics.setColor(0.1, 1.0, 0.5, 0.85)
    love.graphics.rectangle("line", btn_save_x, btn_save_y, btn_save_w, btn_save_h, 6)

    love.graphics.setFont(FontCache.get(13))
    love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
    love.graphics.printf("SAVE & RETURN [ENTER / ESC]", btn_save_x, btn_save_y + 12, btn_save_w, "center")

    love.graphics.setFont(FontCache.get(10))
    love.graphics.setColor(0.45, 0.55, 0.65, 0.75)
    love.graphics.printf("[ UP / DOWN ] SELECCIONAR  |  [ LEFT / RIGHT ] AJUSTAR VALOR  |  [ ESC ] REGRESAR", 0, 600, 1280, "center")
end

function love.draw()
    love.graphics.clear(0.01, 0.01, 0.02, 1.0)

    -- 1. Renderizado del Canvas nativo del juego
    BloomShader.beginDraw()
    FogLayer.draw()

    if gameState == "menu" then
        drawCyberMenu()

    elseif gameState == "versus" or gameState == "gauntlet" or gameState == "gameover" or gameState == "pause" then
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

        if gameState == "pause" then
            drawCyberPause()
        elseif gameState == "gameover" then
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
            love.graphics.printf("PRESS [R] OR [START] TO REMATCH WITH NEXT TRACK | [ESC] MENU", 0, 340, 1280, "center")
        end

    elseif gameState == "settings" then
        drawCyberSettings()

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

local function adjustSetting(delta)
    local s = SettingsManager.settings
    local row = settingsRows[settingsSelection]
    if not row then return end

    if row.is_toggle then
        SettingsManager.toggleMute()
        AudioManager.playMuteToggle(s.mute_all and s.mute_all >= 0.5)
    else
        if row.id == "das" then
            local ms = math.max(row.min, math.min(row.max, (s.das * 1000) + delta * row.step))
            s.das = ms / 1000.0
        elseif row.id == "arr" then
            local ms = math.max(row.min, math.min(row.max, (s.arr * 1000) + delta * row.step))
            s.arr = ms / 1000.0
        elseif row.id == "master" then
            local v = math.max(0, math.min(100, (s.master_vol or 1.0) * 100 + delta * row.step))
            s.master_vol = v / 100.0
        elseif row.id == "bgm" then
            local v = math.max(0, math.min(100, (s.bgm_vol or 1.0) * 100 + delta * row.step))
            s.bgm_vol = v / 100.0
        elseif row.id == "sfx" then
            local v = math.max(0, math.min(100, (s.sfx_vol or 1.0) * 100 + delta * row.step))
            s.sfx_vol = v / 100.0
        end
        AudioManager.playSliderTick()
    end
    SettingsManager.save()
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

    -- 🛑 MANEJO MAESTRO DE ESCAPE (Pausa contextual / Menú)
    if key == "escape" then
        if gameState == "menu" then
            love.event.quit()
        elseif gameState == "versus" or gameState == "gauntlet" then
            previousState = gameState
            gameState = "pause"
            pauseSelection = 1
            MusicManager.pause()
            AudioManager.playMenuBack()
        elseif gameState == "pause" then
            gameState = previousState or "versus"
            MusicManager.resume()
            AudioManager.playMenuClick()
        elseif gameState == "settings" then
            SettingsManager.save()
            gameState = previousState or "menu"
            if gameState == "pause" then
                MusicManager.pause()
            elseif gameState == "menu" then
                MusicManager.start()
            else
                MusicManager.resume()
            end
            AudioManager.playMenuBack()
        elseif gameState == "gameover" then
            gameState = "menu"
            MusicManager.stop()
            MusicManager.start()
            AudioManager.playMenuBack()
        end
        return
    end

    -- 🔄 REINICIO DIRECTO CON 'R' (Con rotación obligatoria de canción)
    if key == "r" then
        if gameState == "versus" or gameState == "gauntlet" or gameState == "pause" or gameState == "gameover" then
            _G.GlobalRestart(false) -- False para avanzar de canción
            gameState = _G.CURRENT_GAME_MODE or "versus"
            return
        end
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
                _G.GlobalRestart(true)
                gameState = "versus"
            elseif menuSelection == 2 then
                _G.CURRENT_GAME_MODE = "gauntlet"
                _G.GlobalRestart(true)
                gameState = "gauntlet"
            elseif menuSelection == 3 then
                TrackEditor.active = true
                gameState = "editor"
            elseif menuSelection == 4 then
                previousState = "menu"
                settingsSelection = 1
                gameState = "settings"
            end
        end
        return
    end

    if gameState == "pause" then
        if key == "up" then
            pauseSelection = (pauseSelection == 1) and #pauseItems or (pauseSelection - 1)
            AudioManager.playMenuHover()
        elseif key == "down" then
            pauseSelection = (pauseSelection % #pauseItems) + 1
            AudioManager.playMenuHover()
        elseif key == "return" or key == "space" then
            AudioManager.playMenuClick()
            if pauseSelection == 1 then -- Resume
                gameState = previousState or "versus"
                MusicManager.resume()
            elseif pauseSelection == 2 then -- Restart & Next
                _G.GlobalRestart(false)
                gameState = previousState or "versus"
            elseif pauseSelection == 3 then -- Settings
                previousState = "pause"
                settingsSelection = 1
                gameState = "settings"
            elseif pauseSelection == 4 then -- Quit
                gameState = "menu"
                MusicManager.stop()
                MusicManager.start()
            end
        end
        return
    end

    if gameState == "settings" then
        if key == "up" then
            settingsSelection = (settingsSelection == 1) and #settingsRows or (settingsSelection - 1)
            AudioManager.playMenuHover()
        elseif key == "down" then
            settingsSelection = (settingsSelection % #settingsRows) + 1
            AudioManager.playMenuHover()
        elseif key == "left" then
            adjustSetting(-1)
        elseif key == "right" then
            adjustSetting(1)
        elseif key == "return" or key == "space" then
            local row = settingsRows[settingsSelection]
            if row and row.is_toggle then
                adjustSetting(1)
            else
                SettingsManager.save()
                gameState = previousState or "menu"
                if gameState == "pause" then MusicManager.pause() end
                AudioManager.playMenuClick()
            end
        end
        return
    end

    if gameState == "gameover" then
        if key == "return" or key == "space" then
            _G.GlobalRestart(false)
            gameState = _G.CURRENT_GAME_MODE or "versus"
        end
        return
    end

    Input.keypressed(key)
end

function love.gamepadpressed(joystick, button)
    if gameState == "versus" or gameState == "gauntlet" then
        if button == "start" then
            previousState = gameState
            gameState = "pause"
            pauseSelection = 1
            MusicManager.pause()
            AudioManager.playMenuBack()
            return
        end
        Input.gamepadpressed(joystick, button)
    elseif gameState == "pause" then
        if button == "start" or button == "b" then
            gameState = previousState or "versus"
            MusicManager.resume()
            AudioManager.playMenuClick()
        elseif button == "dpup" then
            pauseSelection = (pauseSelection == 1) and #pauseItems or (pauseSelection - 1)
            AudioManager.playMenuHover()
        elseif button == "dpdown" then
            pauseSelection = (pauseSelection % #pauseItems) + 1
            AudioManager.playMenuHover()
        elseif button == "a" then
            if pauseSelection == 1 then
                gameState = previousState or "versus"
                MusicManager.resume()
            elseif pauseSelection == 2 then
                _G.GlobalRestart(false)
                gameState = previousState or "versus"
            elseif pauseSelection == 3 then
                previousState = "pause"
                settingsSelection = 1
                gameState = "settings"
            elseif pauseSelection == 4 then
                gameState = "menu"
                MusicManager.stop()
                MusicManager.start()
            end
            AudioManager.playMenuClick()
        end
    elseif gameState == "settings" then
        if button == "b" or button == "start" then
            SettingsManager.save()
            gameState = previousState or "menu"
            if gameState == "pause" then MusicManager.pause() end
            AudioManager.playMenuClick()
        elseif button == "dpup" then
            settingsSelection = (settingsSelection == 1) and #settingsRows or (settingsSelection - 1)
            AudioManager.playMenuHover()
        elseif button == "dpdown" then
            settingsSelection = (settingsSelection % #settingsRows) + 1
            AudioManager.playMenuHover()
        elseif button == "dpleft" then
            adjustSetting(-1)
        elseif button == "dpright" then
            adjustSetting(1)
        elseif button == "a" then
            adjustSetting(1)
        end
    elseif gameState == "gameover" then
        if button == "start" or button == "a" then
            _G.GlobalRestart(false)
            gameState = _G.CURRENT_GAME_MODE or "versus"
        elseif button == "b" or button == "back" then
            gameState = "menu"
            MusicManager.stop()
            MusicManager.start()
        end
    end
end

function love.mousepressed(x, y, button)
    if button ~= 1 then return end
    local adj_x = (x - view_ox) / view_scale
    local adj_y = (y - view_oy) / view_scale

    if gameState == "editor" then
        TrackEditor.mousepressed(adj_x, adj_y, button)
        return
    end

    if gameState == "menu" then
        local btn_w = 480
        local btn_h = 56
        local start_y = 225
        local spacing = 70
        for i = 1, #menuItems do
            local bx = 640 - (btn_w / 2)
            local by = start_y + (i - 1) * spacing
            if adj_x >= bx and adj_x <= bx + btn_w and adj_y >= by and adj_y <= by + btn_h then
                menuSelection = i
                AudioManager.playMenuClick()
                if i == 1 then
                    _G.CURRENT_GAME_MODE = "versus"
                    _G.GlobalRestart(true)
                    gameState = "versus"
                elseif i == 2 then
                    _G.CURRENT_GAME_MODE = "gauntlet"
                    _G.GlobalRestart(true)
                    gameState = "gauntlet"
                elseif i == 3 then
                    TrackEditor.active = true
                    gameState = "editor"
                elseif i == 4 then
                    previousState = "menu"
                    settingsSelection = 1
                    gameState = "settings"
                end
                return
            end
        end
    end

    if gameState == "pause" then
        local card_w = 500
        local btn_w = 420
        local btn_h = 52
        local start_y = 140 + 90
        local spacing = 64
        for i = 1, #pauseItems do
            local bx = 640 - (btn_w / 2)
            local by = start_y + (i - 1) * spacing
            if adj_x >= bx and adj_x <= bx + btn_w and adj_y >= by and adj_y <= by + btn_h then
                pauseSelection = i
                AudioManager.playMenuClick()
                if i == 1 then
                    gameState = previousState or "versus"
                    MusicManager.resume()
                elseif i == 2 then
                    _G.GlobalRestart(false)
                    gameState = previousState or "versus"
                elseif i == 3 then
                    previousState = "pause"
                    settingsSelection = 1
                    gameState = "settings"
                elseif i == 4 then
                    gameState = "menu"
                    MusicManager.stop()
                    MusicManager.start()
                end
                return
            end
        end
    end

    if gameState == "settings" then
        local card_x = 640 - 350
        local card_y = 125
        local row_start_y = card_y + 30
        local row_spacing = 58

        for i, r in ipairs(settingsRows) do
            local ry = row_start_y + (i - 1) * row_spacing
            local slider_x = card_x + 360
            local slider_y = ry + 2
            local slider_w = 220
            local slider_h = 18

            if r.is_toggle then
                if adj_x >= slider_x and adj_x <= slider_x + 90 and adj_y >= slider_y - 2 and adj_y <= slider_y + 20 then
                    settingsSelection = i
                    adjustSetting(1)
                    return
                end
            else
                if adj_x >= slider_x and adj_x <= slider_x + slider_w and adj_y >= slider_y - 4 and adj_y <= slider_y + slider_h + 4 then
                    settingsSelection = i
                    local pct = math.max(0, math.min(1, (adj_x - slider_x) / slider_w))
                    local val = r.min + pct * (r.max - r.min)
                    local s = SettingsManager.settings
                    if r.id == "das" then s.das = val / 1000.0
                    elseif r.id == "arr" then s.arr = val / 1000.0
                    elseif r.id == "master" then s.master_vol = val / 100.0
                    elseif r.id == "bgm" then s.bgm_vol = val / 100.0
                    elseif r.id == "sfx" then s.sfx_vol = val / 100.0
                    end
                    SettingsManager.save()
                    AudioManager.playSliderTick()
                    return
                end
            end
        end

        local btn_save_w = 260
        local btn_save_h = 42
        local btn_save_x = 640 - (btn_save_w / 2)
        local btn_save_y = card_y + 440 - 56
        if adj_x >= btn_save_x and adj_x <= btn_save_x + btn_save_w and adj_y >= btn_save_y and adj_y <= btn_save_y + btn_save_h then
            SettingsManager.save()
            gameState = previousState or "menu"
            if gameState == "pause" then MusicManager.pause() end
            AudioManager.playMenuClick()
            return
        end
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
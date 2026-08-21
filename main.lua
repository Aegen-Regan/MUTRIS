-- ================================================================
-- FILE: main.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: SYNTHETIC TRANSCENDENCE [KERNEL CENTRAL 1280x720 WIDESCREEN]
-- Master Calibration Suite / Multi-Theme Engine [F5] / Zero-GC Core
-- ============================================================================

_G.ENGINE_VERSION           = "MUTRIS v1.0.0"
_G.RealMatchTimer           = 0.0
_G.HitStopTimer             = 0.0
_G.AudioBeatPulse           = 0.0
_G.TrackEnergyPunch         = 0.0
_G.CURRENT_GAME_MODE        = "versus"
_G.IS_DEMO_MODE             = false
_G.IsBlackoutActive         = false
_G.BlackoutStrobeVisibility = 1.0

local SettingsManager    = require "settings_manager"
local ThemeManager       = require "tetris.theme_manager"
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
local settingsReturnState = "menu"
local menuSelection = 1
local pauseSelection = 1

local active_tab_index = 1
local active_item_index = 1

local menuItems = {
    "VS BOT DUEL",
    "GAUNTLET RUSH",
    "SOUNDTRACK & FX LAB",
    "SETTINGS & CALIBRATION"
}
local menuSubtitles = {
    "CLASSIC 1v1 DUEL VS ADAPTIVE DDA BOT",
    "ENDLESS SURVIVAL AGAINST FREQUENT ANOMALIES",
    "DAW TIMELINE, CUE PLACEMENT & SFX AUDITION",
    "MASTER CALIBRATION SUITE, DAS / ARR & PIPELINE"
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
    "CALIBRATE DAS, ARR, FX & CAPTURE MODES",
    "ABORT CURRENT MATCH AND RETURN TO TITLE"
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
    screenshot_flash_timer = 1.8
    ScreenshotHelper.capture(function(copied, filename)
        -- Toast inferior dedicado, sin sobrecargar la matriz de combate
    end)
end

function _G.ToggleRecording()
    AudioManager.playSliderTick()
    ClipRecorder.toggle(function(frames, base_path, mode)
        -- Toast inferior dedicado
    end)
end

function _G.SetGameState(state)
    gameState = state
    Blackbox.log("STATE", "STATE: " .. state, 0, 0)
end

function _G.GlobalRestart(skip_track_advance)
    _G.RealMatchTimer = 0.0
    _G.HitStopTimer = 0.0
    _G.AudioBeatPulse = 0.0
    _G.TrackEnergyPunch = 0.0

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
    if ThemeManager.init    then ThemeManager.init() end
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
    ThemeManager.update(dt)
    if MusicManager.update then MusicManager.update(dt) end
    BloomShader.update(dt)
    ClipRecorder.update(dt)
    ReplayManager.update(dt)

    if gameState == "editor" then
        TrackEditor.update(dt)
        return
    end

    if gameState == "pause" or gameState == "settings" then
        return
    end

    if gameState == "versus" or gameState == "gauntlet" then
        FogLayer.update(dt)
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

local function drawCyberPause()
    love.graphics.setColor(0.0, 0.0, 0.0, 0.82)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    local t = ThemeManager.getCurrent()
    local pulse = _G.AudioBeatPulse or 0

    local card_w = 500
    local card_h = 440
    local card_x = 640 - (card_w / 2)
    local card_y = 140

    ThemeManager.drawPanel(card_x, card_y, card_w, card_h, "", false)

    love.graphics.setFont(FontCache.get(28))
    love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.95)
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

        ThemeManager.drawPanel(btn_x, btn_y, btn_w, btn_h, "", is_sel)

        if is_sel then
            love.graphics.setColor(t.secondary[1], t.secondary[2], t.secondary[3], 0.95)
            love.graphics.rectangle("fill", btn_x + 4, btn_y + 6, 4, btn_h - 12, 2)
            love.graphics.rectangle("fill", btn_x + btn_w - 8, btn_y + 6, 4, btn_h - 12, 2)

            love.graphics.setFont(FontCache.get(15))
            love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
            love.graphics.printf(">  " .. item .. "  <", btn_x, btn_y + 10, btn_w, "center")

            love.graphics.setFont(FontCache.get(9))
            love.graphics.setColor(t.secondary[1], t.secondary[2], t.secondary[3], 0.85)
            love.graphics.printf(pauseSubtitles[i] or "", btn_x, btn_y + 32, btn_w, "center")
        else
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
    ThemeManager.drawBackground()

    local t     = ThemeManager.getCurrent()
    local pulse = _G.AudioBeatPulse or 0

    love.graphics.setFont(FontCache.get(26))
    love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.95)
    love.graphics.printf("MASTER CALIBRATION SUITE", 0, 26, 1280, "center")

    local current_tab = SettingsManager.tabs[active_tab_index]
    love.graphics.setFont(FontCache.get(11))
    love.graphics.setColor(0.5, 0.7, 0.9, 0.85)
    love.graphics.printf(current_tab.title or "SYSTEM TUNING", 0, 58, 1280, "center")

    local tab_w = 172
    local tab_h = 32
    local total_tabs_w = #SettingsManager.tabs * (tab_w + 8) - 8
    local tabs_start_x = 640 - (total_tabs_w / 2)
    local tabs_y = 82

    for i, tab in ipairs(SettingsManager.tabs) do
        local tx = tabs_start_x + (i - 1) * (tab_w + 8)
        local is_active_tab = (i == active_tab_index)

        ThemeManager.drawPanel(tx, tabs_y, tab_w, tab_h, "", is_active_tab)

        love.graphics.setFont(FontCache.get(10))
        if is_active_tab then
            love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
        else
            love.graphics.setColor(0.65, 0.75, 0.85, 0.75)
        end
        love.graphics.printf(tab.name, tx, tabs_y + 9, tab_w, "center")
    end

    local card_x = 180
    local card_y = 126
    local card_w = 920
    local card_h = 450

    ThemeManager.drawPanel(card_x, card_y, card_w, card_h, "", false)

    local row_start_y = card_y + 16
    local row_spacing = 49

    for i, item in ipairs(current_tab.items) do
        local is_sel = (i == active_item_index)
        local ry = row_start_y + (i - 1) * row_spacing

        if is_sel then
            love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.15)
            love.graphics.rectangle("fill", card_x + 12, ry - 4, card_w - 24, 43, 4)
            love.graphics.setLineWidth(1.2)
            love.graphics.setColor(t.secondary[1], t.secondary[2], t.secondary[3], 0.85)
            love.graphics.rectangle("line", card_x + 12, ry - 4, card_w - 24, 43, 4)
        end

        love.graphics.setFont(FontCache.get(11))
        love.graphics.setColor(is_sel and {1.0, 1.0, 1.0, 1.0} or {0.75, 0.85, 0.95, 0.85})
        love.graphics.print(item.label, card_x + 28, ry + 8)

        local slider_x = card_x + 360
        local slider_y = ry + 8
        local slider_w = 260
        local slider_h = 16

        local cur_val = SettingsManager.get(item.id)
        local def_val = SettingsManager.defaults[item.id]

        if item.is_toggle then
            local is_on = (cur_val and (cur_val == 1 or cur_val == true or (type(cur_val) == "number" and cur_val >= 0.5)))
            love.graphics.setColor(is_on and {0.1, 0.85, 0.45, 0.85} or {0.8, 0.15, 0.25, 0.85})
            love.graphics.rectangle("fill", slider_x, slider_y - 2, 80, 20, 3)
            love.graphics.setFont(FontCache.get(10))
            love.graphics.setColor(1, 1, 1, 0.95)
            love.graphics.printf(is_on and "ON" or "OFF", slider_x, slider_y + 2, 80, "center")

        elseif item.is_enum then
            local opt_idx = 1
            for idx, opt in ipairs(item.options) do
                if opt == cur_val then opt_idx = idx break end
            end
            local label_text = item.labels[opt_idx] or tostring(cur_val)
            love.graphics.setColor(0.0, 0.35, 0.55, 0.75)
            love.graphics.rectangle("fill", slider_x, slider_y - 2, 220, 22, 3)
            love.graphics.setColor(t.border)
            love.graphics.rectangle("line", slider_x, slider_y - 2, 220, 22, 3)
            love.graphics.setFont(FontCache.get(10))
            love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
            love.graphics.printf("< " .. label_text .. " >", slider_x, slider_y + 3, 220, "center")

        else
            love.graphics.setColor(0.02, 0.04, 0.08, 0.9)
            love.graphics.rectangle("fill", slider_x, slider_y, slider_w, slider_h, 3)
            love.graphics.setColor(t.border)
            love.graphics.rectangle("line", slider_x, slider_y, slider_w, slider_h, 3)

            local num_v = tonumber(cur_val) or 0
            if item.is_ms then num_v = num_v * 1000 end
            if item.is_pct then num_v = num_v * 100 end

            local pct = (num_v - item.min) / math.max(0.001, (item.max - item.min))
            pct = math.max(0, math.min(1, pct))

            love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.85)
            love.graphics.rectangle("fill", slider_x + 2, slider_y + 2, (slider_w - 4) * pct, slider_h - 4, 2)

            love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
            love.graphics.rectangle("fill", slider_x + (slider_w - 4) * pct - 2, slider_y - 2, 5, slider_h + 4, 1)

            love.graphics.setFont(FontCache.get(10))
            love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
            local val_str = item.is_pct and string.format("%d%%", math.floor(num_v + 0.5))
                         or (item.is_ms and string.format("%d ms", math.floor(num_v + 0.5))
                         or (item.is_int and string.format("%d %s", math.floor(num_v + 0.5), item.unit or "")
                         or string.format("%.2f %s", num_v, item.unit or "")))
            love.graphics.print(val_str, slider_x + slider_w + 14, slider_y)
        end

        local reset_btn_x = card_x + card_w - 120
        local reset_btn_y = ry + 4
        love.graphics.setColor(0.03, 0.06, 0.12, 0.85)
        love.graphics.rectangle("fill", reset_btn_x, reset_btn_y, 44, 22, 3)
        love.graphics.setColor(t.border)
        love.graphics.rectangle("line", reset_btn_x, reset_btn_y, 44, 22, 3)
        love.graphics.setFont(FontCache.get(9))
        love.graphics.setColor(t.primary)
        love.graphics.printf("RST", reset_btn_x, reset_btn_y + 4, 44, "center")

        love.graphics.setFont(FontCache.get(8))
        love.graphics.setColor(0.45, 0.55, 0.65, 0.75)
        local def_str = item.is_ms and string.format("%dms", def_val * 1000)
                     or (item.is_pct and string.format("%d%%", def_val * 100)
                     or (item.is_int and string.format("%d", def_val)
                     or tostring(def_val)))
        love.graphics.print("BASE: " .. def_str, reset_btn_x + 52, reset_btn_y + 5)
    end

    if current_tab.id == "handling" then
        local das_ms = (SettingsManager.get("das") or 0.094) * 1000
        local arr_ms = (SettingsManager.get("arr") or 0.008) * 1000
        local f60_das = das_ms / (1000 / 60)
        local f144_das = das_ms / (1000 / 144)
        local f240_das = das_ms / (1000 / 240)

        love.graphics.setColor(0.0, 0.05, 0.1, 0.88)
        love.graphics.rectangle("fill", card_x + 12, card_y + card_h - 68, card_w - 24, 24, 3)
        love.graphics.setFont(FontCache.get(9))
        love.graphics.setColor(0.2, 0.95, 0.6, 0.9)
        local telemetry_line = string.format(
            "FRAME-DATA LIVE MONITOR: DAS %.0fms = %.1ff @ 60Hz | %.1ff @ 144Hz | %.1ff @ 240Hz   --   ARR %.1fms",
            das_ms, f60_das, f144_das, f240_das, arr_ms
        )
        love.graphics.printf(telemetry_line, card_x + 12, card_y + card_h - 62, card_w - 24, "center")
    end

    local btn_reset_w = 200
    local btn_reset_h = 32
    local btn_reset_x = card_x + 20
    local btn_reset_y = card_y + card_h - 38

    love.graphics.setColor(0.25, 0.05, 0.08, 0.8)
    love.graphics.rectangle("fill", btn_reset_x, btn_reset_y, btn_reset_w, btn_reset_h, 4)
    love.graphics.setColor(1.0, 0.2, 0.3, 0.5)
    love.graphics.rectangle("line", btn_reset_x, btn_reset_y, btn_reset_w, btn_reset_h, 4)
    love.graphics.setFont(FontCache.get(10))
    love.graphics.setColor(1.0, 0.4, 0.5, 0.95)
    love.graphics.printf("RESTABLECER PESTANA", btn_reset_x, btn_reset_y + 8, btn_reset_w, "center")

    local btn_save_w = 260
    local btn_save_h = 32
    local btn_save_x = card_x + card_w - btn_save_w - 20
    local btn_save_y = card_y + card_h - 38

    love.graphics.setColor(0.0, 0.45, 0.25, 0.85)
    love.graphics.rectangle("fill", btn_save_x, btn_save_y, btn_save_w, btn_save_h, 4)
    love.graphics.setColor(0.1, 1.0, 0.5, 0.7)
    love.graphics.rectangle("line", btn_save_x, btn_save_y, btn_save_w, btn_save_h, 4)
    love.graphics.setFont(FontCache.get(11))
    love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
    love.graphics.printf("GUARDAR Y SALIR [ESC / ENTER]", btn_save_x, btn_save_y + 7, btn_save_w, "center")

    love.graphics.setFont(FontCache.get(9))
    love.graphics.setColor(0.45, 0.55, 0.65, 0.75)
    love.graphics.printf("[ Q / E ] CAMBIAR PESTANA  |  [ FLECHAS ] AJUSTAR  |  [ BACKSPACE / DEL ] RESET INDIVIDUAL  |  [ ESC ] REGRESAR", 0, 595, 1280, "center")
end

function love.draw()
    love.graphics.clear(0.01, 0.01, 0.02, 1.0)

    BloomShader.beginDraw()

    if gameState == "menu" then
        ThemeManager.drawMenu(menuItems, menuSubtitles, menuSelection, MetaBalancer)

    elseif gameState == "versus" or gameState == "gauntlet" or gameState == "gameover" or gameState == "pause" then
        ThemeManager.drawBackground()
        FogLayer.draw()

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
            -- 🏆 Modal de Fin de Partida: 100% Sólido, Sin Bleed-Through y Cristalino
            local t = ThemeManager.getCurrent()
            local is_victory = (BotBoard and BotBoard.is_dying)
            local modal_w, modal_h = 460, 220
            local modal_x = 640 - (modal_w / 2)
            local modal_y = 235

            love.graphics.setColor(0.0, 0.0, 0.0, 0.90)
            love.graphics.rectangle("fill", modal_x - 6, modal_y - 6, modal_w + 12, modal_h + 12, 10)

            love.graphics.setColor(0.01, 0.015, 0.03, 1.0)
            love.graphics.rectangle("fill", modal_x, modal_y, modal_w, modal_h, 8)

            local border_color = is_victory and (t.secondary or {0.1, 1.0, 0.5}) or {1.0, 0.2, 0.3}
            love.graphics.setLineWidth(2.5)
            love.graphics.setColor(border_color[1], border_color[2], border_color[3], 0.98)
            love.graphics.rectangle("line", modal_x, modal_y, modal_w, modal_h, 8)

            love.graphics.setFont(FontCache.get(30))
            if is_victory then
                love.graphics.setColor(0.1, 1.0, 0.5, 0.98)
                love.graphics.printf("VICTORY ACHIEVED", 0, modal_y + 22, 1280, "center")
            else
                love.graphics.setColor(1.0, 0.2, 0.3, 0.98)
                love.graphics.printf("ANNIHILATED", 0, modal_y + 22, 1280, "center")
            end

            love.graphics.setFont(FontCache.get(10))
            love.graphics.setColor(0.7, 0.85, 0.95, 0.85)
            local match_stat = string.format("MATCH TIME: %.1fs  |  P1 PPS: %.2f  |  BOT PPS: %.2f", 
                _G.RealMatchTimer or 0, 
                (PlayerBoard and PlayerBoard.current_pps_display) or 0,
                (BotBoard and BotBoard.current_pps_display) or 0
            )
            love.graphics.printf(match_stat, 0, modal_y + 75, 1280, "center")

            love.graphics.setFont(FontCache.get(12))
            love.graphics.setColor(1.0, 0.95, 0.4, 0.95)
            love.graphics.printf("PRESS [R] OR [START] TO REMATCH WITH NEXT TRACK", 0, modal_y + 115, 1280, "center")

            love.graphics.setFont(FontCache.get(10))
            love.graphics.setColor(0.55, 0.65, 0.75, 0.8)
            love.graphics.printf("[ESC] RETURN TO MAIN MENU", 0, modal_y + 155, 1280, "center")
        end

    elseif gameState == "settings" then
        drawCyberSettings()

    elseif gameState == "editor" then
        TrackEditor.draw()
    end

    -- ⚠️ DIRECTIVA PRIMARIA PERMANENTE + MARCADOR DE SKIN ACTIVA
    love.graphics.push("all")
    local t = ThemeManager.getCurrent()
    love.graphics.setFont(FontCache.get(10))
    love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.90)
    local watermark = string.format("%s  |  SKIN: %s", _G.ENGINE_VERSION, t.name)
    love.graphics.print(watermark, 16, 698)
    love.graphics.pop()

    BloomShader.endDraw(PlayerBoard and PlayerBoard.is_zone_active, view_ox, view_oy, view_scale)

    if ClipRecorder.is_recording and BloomShader.canvas then
        ClipRecorder.captureFrame(BloomShader.canvas)
    end

    ClipRecorder.drawHUDIndicator()

    -- Toast de Captura a Portapapeles
    if screenshot_flash_timer > 0 then
        local a = math.min(1.0, screenshot_flash_timer * 1.5)
        local t_cur = ThemeManager.getCurrent()
        love.graphics.setColor(0.02, 0.03, 0.06, 0.95 * a)
        love.graphics.rectangle("fill", 440, 655, 380, 36, 4)
        love.graphics.setLineWidth(1.2)
        love.graphics.setColor(t_cur.secondary[1], t_cur.secondary[2], t_cur.secondary[3], 0.90 * a)
        love.graphics.rectangle("line", 440, 655, 380, 36, 4)
        love.graphics.setFont(FontCache.get(10))
        love.graphics.setColor(1, 1, 1, 0.98 * a)
        love.graphics.printf("COPIED TO CLIPBOARD! (CTRL+V)", 440, 666, 380, "center")
    end

    ThemeManager.drawToast()
end

local function adjustActiveSetting(delta)
    local tab = SettingsManager.tabs[active_tab_index]
    if not tab then return end
    local item = tab.items[active_item_index]
    if not item then return end

    local s = SettingsManager.settings
    local cur = s[item.id]

    if item.is_toggle then
        if item.id == "mute_all" then
            SettingsManager.toggleMute()
            AudioManager.playMuteToggle(s.mute_all and s.mute_all >= 0.5)
        else
            s[item.id] = (cur == 1 or cur == true) and 0 or 1
            AudioManager.playSliderTick()
        end

    elseif item.is_enum then
        local opt_idx = 1
        for idx, opt in ipairs(item.options) do
            if opt == cur then opt_idx = idx break end
        end
        opt_idx = ((opt_idx + delta - 1) % #item.options) + 1
        s[item.id] = item.options[opt_idx]
        if item.id == "theme_skin" then
            ThemeManager.setTheme(item.options[opt_idx])
        end
        AudioManager.playSliderTick()

    else
        local num_v = tonumber(cur) or 0
        if item.is_ms then num_v = num_v * 1000 end
        if item.is_pct then num_v = num_v * 100 end

        num_v = math.max(item.min, math.min(item.max, num_v + delta * item.step))

        if item.is_ms then s[item.id] = num_v / 1000.0
        elseif item.is_pct then s[item.id] = num_v / 100.0
        else s[item.id] = num_v end
        AudioManager.playSliderTick()
    end

    SettingsManager.save()
end

function love.keypressed(key)
    if key == "f9" then
        _G.ToggleRecording()
        return
    end

    if key == "f12" or key == "f2" or key == "printscreen" or key == "sysrq" then
        _G.TakeScreenshot()
        return
    end

    if key == "f5" then
        ThemeManager.cycleNext()
        AudioManager.playSliderTick()
        return
    elseif key == "f6" then
        ThemeManager.cyclePrev()
        AudioManager.playSliderTick()
        return
    end

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
        elseif gameState == "versus" or gameState == "gauntlet" then
            gameState = "pause"
            pauseSelection = 1
            MusicManager.pause()
            AudioManager.playMenuBack()
        elseif gameState == "pause" then
            gameState = _G.CURRENT_GAME_MODE or "versus"
            MusicManager.resume()
            AudioManager.playMenuClick()
        elseif gameState == "settings" then
            SettingsManager.save()
            gameState = settingsReturnState or "menu"
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

    if key == "r" then
        if gameState == "versus" or gameState == "gauntlet" or gameState == "pause" or gameState == "gameover" then
            _G.GlobalRestart(false)
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
                settingsReturnState = "menu"
                active_tab_index = 1
                active_item_index = 1
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
            if pauseSelection == 1 then
                gameState = _G.CURRENT_GAME_MODE or "versus"
                MusicManager.resume()
            elseif pauseSelection == 2 then
                _G.GlobalRestart(false)
                gameState = _G.CURRENT_GAME_MODE or "versus"
            elseif pauseSelection == 3 then
                settingsReturnState = "pause"
                active_tab_index = 1
                active_item_index = 1
                gameState = "settings"
            elseif pauseSelection == 4 then
                gameState = "menu"
                MusicManager.stop()
                MusicManager.start()
            end
        end
        return
    end

    if gameState == "settings" then
        local current_tab = SettingsManager.tabs[active_tab_index]

        if key == "q" then
            active_tab_index = (active_tab_index == 1) and #SettingsManager.tabs or (active_tab_index - 1)
            active_item_index = 1
            AudioManager.playMenuHover()
        elseif key == "e" or key == "tab" then
            active_tab_index = (active_tab_index % #SettingsManager.tabs) + 1
            active_item_index = 1
            AudioManager.playMenuHover()
        elseif key == "up" then
            active_item_index = (active_item_index == 1) and #current_tab.items or (active_item_index - 1)
            AudioManager.playMenuHover()
        elseif key == "down" then
            active_item_index = (active_item_index % #current_tab.items) + 1
            AudioManager.playMenuHover()
        elseif key == "left" then
            adjustActiveSetting(-1)
        elseif key == "right" then
            adjustActiveSetting(1)
        elseif key == "backspace" or key == "delete" then
            local item = current_tab.items[active_item_index]
            if item then
                SettingsManager.resetKey(item.id)
                if item.id == "theme_skin" then
                    ThemeManager.setTheme(SettingsManager.get("theme_skin"))
                end
                AudioManager.playImmediateSFX("rotate", false)
            end
        elseif key == "return" or key == "space" then
            local item = current_tab.items[active_item_index]
            if item and (item.is_toggle or item.is_enum) then
                adjustActiveSetting(1)
            else
                SettingsManager.save()
                gameState = settingsReturnState or "menu"
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

function love.mousepressed(x, y, button)
    if button ~= 1 then return end
    local adj_x = (x - view_ox) / view_scale
    local adj_y = (y - view_oy) / view_scale

    if gameState == "editor" then
        TrackEditor.mousepressed(adj_x, adj_y, button)
        return
    end

    if gameState == "menu" then
        local start_y = (ThemeManager.current_theme == 1) and 130 or ((ThemeManager.current_theme == 3) and 115 or 145)
        local spacing = (ThemeManager.current_theme == 1) and 92 or ((ThemeManager.current_theme == 3) and 110 or 88)
        for i = 1, #menuItems do
            local by = start_y + (i - 1) * spacing
            if adj_y >= by and adj_y <= by + 75 and adj_x >= 80 and adj_x <= 750 then
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
                    settingsReturnState = "menu"
                    active_tab_index = 1
                    active_item_index = 1
                    gameState = "settings"
                end
                return
            end
        end
    end

    if gameState == "pause" then
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
                    gameState = _G.CURRENT_GAME_MODE or "versus"
                    MusicManager.resume()
                elseif i == 2 then
                    _G.GlobalRestart(false)
                    gameState = _G.CURRENT_GAME_MODE or "versus"
                elseif i == 3 then
                    settingsReturnState = "pause"
                    active_tab_index = 1
                    active_item_index = 1
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
        local tab_w = 172
        local tab_h = 32
        local total_tabs_w = #SettingsManager.tabs * (tab_w + 8) - 8
        local tabs_start_x = 640 - (total_tabs_w / 2)
        local tabs_y = 82

        for i = 1, #SettingsManager.tabs do
            local tx = tabs_start_x + (i - 1) * (tab_w + 8)
            if adj_x >= tx and adj_x <= tx + tab_w and adj_y >= tabs_y and adj_y <= tabs_y + tab_h then
                active_tab_index = i
                active_item_index = 1
                AudioManager.playMenuHover()
                return
            end
        end

        local card_x = 180
        local card_y = 126
        local card_w = 920
        local card_h = 450
        local row_start_y = card_y + 16
        local row_spacing = 49
        local current_tab = SettingsManager.tabs[active_tab_index]

        for i, item in ipairs(current_tab.items) do
            local ry = row_start_y + (i - 1) * row_spacing
            local slider_x = card_x + 360
            local slider_y = ry + 8
            local slider_w = 260
            local slider_h = 16
            local reset_btn_x = card_x + card_w - 120

            if adj_x >= reset_btn_x and adj_x <= reset_btn_x + 44 and adj_y >= ry + 4 and adj_y <= ry + 26 then
                active_item_index = i
                SettingsManager.resetKey(item.id)
                if item.id == "theme_skin" then
                    ThemeManager.setTheme(SettingsManager.get("theme_skin"))
                end
                AudioManager.playImmediateSFX("rotate", false)
                return
            end

            if item.is_toggle then
                if adj_x >= slider_x and adj_x <= slider_x + 80 and adj_y >= slider_y - 2 and adj_y <= slider_y + 18 then
                    active_item_index = i
                    adjustActiveSetting(1)
                    return
                end
            elseif item.is_enum then
                if adj_x >= slider_x and adj_x <= slider_x + 220 and adj_y >= slider_y - 2 and adj_y <= slider_y + 20 then
                    active_item_index = i
                    adjustActiveSetting(1)
                    return
                end
            else
                if adj_x >= slider_x and adj_x <= slider_x + slider_w and adj_y >= slider_y - 4 and adj_y <= slider_y + slider_h + 4 then
                    active_item_index = i
                    local pct = math.max(0, math.min(1, (adj_x - slider_x) / slider_w))
                    local val = item.min + pct * (item.max - item.min)
                    local s = SettingsManager.settings
                    if item.is_ms then s[item.id] = val / 1000.0
                    elseif item.is_pct then s[item.id] = val / 100.0
                    else s[item.id] = val end
                    SettingsManager.save()
                    AudioManager.playSliderTick()
                    return
                end
            end
        end

        local btn_reset_x = card_x + 20
        local btn_reset_y = card_y + card_h - 38
        if adj_x >= btn_reset_x and adj_x <= btn_reset_x + 200 and adj_y >= btn_reset_y and adj_y <= btn_reset_y + 32 then
            SettingsManager.resetTab(active_tab_index)
            if active_tab_index == 4 then
                ThemeManager.setTheme(SettingsManager.get("theme_skin"))
            end
            AudioManager.playImmediateSFX("rotate", false)
            return
        end

        local btn_save_w = 260
        local btn_save_x = card_x + card_w - btn_save_w - 20
        local btn_save_y = card_y + card_h - 38
        if adj_x >= btn_save_x and adj_x <= btn_save_x + btn_save_w and adj_y >= btn_save_y and adj_y <= btn_save_y + 32 then
            SettingsManager.save()
            gameState = settingsReturnState or "menu"
            if gameState == "pause" then 
                MusicManager.pause()
            elseif gameState == "menu" then
                MusicManager.start()
            else
                MusicManager.resume()
            end
            AudioManager.playMenuClick()
            return
        end
    end
end

function love.gamepadpressed(joystick, button)
    if gameState == "versus" or gameState == "gauntlet" then
        if button == "start" then
            gameState = "pause"
            pauseSelection = 1
            MusicManager.pause()
            AudioManager.playMenuBack()
            return
        end
        Input.gamepadpressed(joystick, button)
    elseif gameState == "pause" then
        if button == "start" or button == "b" then
            gameState = _G.CURRENT_GAME_MODE or "versus"
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
                gameState = _G.CURRENT_GAME_MODE or "versus"
                MusicManager.resume()
            elseif pauseSelection == 2 then
                _G.GlobalRestart(false)
                gameState = _G.CURRENT_GAME_MODE or "versus"
            elseif pauseSelection == 3 then
                settingsReturnState = "pause"
                active_tab_index = 1
                active_item_index = 1
                gameState = "settings"
            elseif pauseSelection == 4 then
                gameState = "menu"
                MusicManager.stop()
                MusicManager.start()
            end
            AudioManager.playMenuClick()
        end
    elseif gameState == "settings" then
        if button == "leftshoulder" then
            active_tab_index = (active_tab_index == 1) and #SettingsManager.tabs or (active_tab_index - 1)
            active_item_index = 1
            AudioManager.playMenuHover()
        elseif button == "rightshoulder" then
            active_tab_index = (active_tab_index % #SettingsManager.tabs) + 1
            active_item_index = 1
            AudioManager.playMenuHover()
        elseif button == "dpup" then
            local current_tab = SettingsManager.tabs[active_tab_index]
            active_item_index = (active_item_index == 1) and #current_tab.items or (active_item_index - 1)
            AudioManager.playMenuHover()
        elseif button == "dpdown" then
            local current_tab = SettingsManager.tabs[active_tab_index]
            active_item_index = (active_item_index % #current_tab.items) + 1
            AudioManager.playMenuHover()
        elseif button == "dpleft" then
            adjustActiveSetting(-1)
        elseif button == "dpright" or button == "a" then
            adjustActiveSetting(1)
        elseif button == "b" or button == "start" then
            SettingsManager.save()
            gameState = settingsReturnState or "menu"
            if gameState == "pause" then 
                MusicManager.pause() 
            elseif gameState == "menu" then
                MusicManager.start()
            else
                MusicManager.resume()
            end
            AudioManager.playMenuClick()
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
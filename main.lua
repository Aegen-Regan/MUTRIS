-- ================================================================
-- FILE: main.lua (PARTE 1 DE 2)
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: SYNTHETIC TRANSCENDENCE [PURE MICRO-KERNEL 1280x720]
-- Zero-GC / Fully Decoupled Scene Architecture / EventBus Hardware Clock
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
local RulesetManager     = require "core.ruleset_manager"
local AudioManager       = require "audio_manager"
local MusicManager       = require "music_manager"
local TrackManager       = require "track_manager"
local MetaBalancer       = require "core.meta_balancer"
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
local PoiseSystem        = require "combat.poise_system"
local PartBreaking       = require "combat.part_breaking"
local BossPhases         = require "combat.boss_phases"
local BenchmarkManager   = require "core.benchmark_manager"
local HuntingForge       = require "combat.hunting_forge"
local EventBus           = require "core.event_bus"
local PluginManager      = require "core.plugin_manager"
local SceneManager       = require "core.scene_manager"
local SceneCampaign      = require "scenes.scene_campaign"

local PlayerBoard = nil
local BotBoard    = nil

local view_scale = 1.0
local view_ox = 0
local view_oy = 0
local screenshot_flash_timer = 0.0
local engage_timer = 0.0
local engage_duration = 0.35

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
    ScreenshotHelper.capture(function(copied, filename) end)
end

function _G.ToggleRecording()
    AudioManager.playSliderTick()
    ClipRecorder.toggle(function(frames, base_path, mode) end)
end

function _G.SetGameState(state)
    SceneManager.setState(state)
end

function _G.StartEngageTransition()
    engage_timer = engage_duration
end

function _G.BenchmarkResetBoards()
    PlayerBoard = Board.new(220, 120, "human")
    BotBoard    = Board.new(820, 120, "bot")
    PlayerBoard.opponent = BotBoard
    BotBoard.opponent    = PlayerBoard

    AIBot.board    = BotBoard
    AIBot.opponent = PlayerBoard
    AIBot.player   = PlayerBoard
    BotBoard.ai    = AIBot

    if Input and Input.init then Input.init(PlayerBoard) end
    if AIBot.init then AIBot.init(BotBoard) end
    ThemeManager.triggerRestartHalo()
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

    if Input and Input.init then Input.init(PlayerBoard) end
    if AIBot.init then 
        AIBot.init(BotBoard)
        AIBot.board = BotBoard
    end
    if AnomalyManager.init then AnomalyManager.init() end

    if _G.CURRENT_GAME_MODE == "boss_hunt" then
        PoiseSystem.init()
        PartBreaking.init()
        BossPhases.init()
    elseif _G.CURRENT_GAME_MODE == "benchmark" then
        BenchmarkManager.init()
    end

    BloomShader.triggerShockwave(640, 360)
    ThemeManager.triggerRestartHalo()

    local track_info = TrackManager.getCurrentTrack()
    local track_name = track_info and track_info.name or "MUTRIS_TRACK"
    ReplayManager.startRecording(_G.CURRENT_GAME_MODE, math.random(100000, 999999), track_name)
    Blackbox.log("MATCH", "RESTART EXECUTED: " .. track_name, 0, 0)
    
    EventBus.emit(EventBus.ON_MATCH_RESTART)
end

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    updateViewScaling()
    Blackbox.init()
    ClipRecorder.init()
    
    if SettingsManager.init then SettingsManager.init() end
    if RulesetManager.init  then RulesetManager.init() end
    if ThemeManager.init    then ThemeManager.init() end
    if MetaBalancer.init    then MetaBalancer.init() end
    if AudioManager.init    then AudioManager.init() end
    if TrackManager.init    then TrackManager.init() end
    if BloomShader.init     then BloomShader.init() end
    if FogLayer.init        then FogLayer.init() end
    if HuntingForge.init    then HuntingForge.init() end
    
    EventBus.init()
    PluginManager.init()
    SceneManager.init()
    SceneManager.register("campaign", SceneCampaign)
    
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

    if engage_timer > 0 then
        engage_timer = math.max(0, engage_timer - dt)
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
    PluginManager.update(dt)

    local st = SceneManager.getState()

    -- ⚔️ ESTADOS DE COMBATE / DUELOS EN VIVO
    if st == "versus" or st == "gauntlet" or st == "boss_hunt" or st == "benchmark" then
        if _G.CURRENT_GAME_MODE == "benchmark" and BenchmarkManager.isWaitingBriefing() then
            return
        end

        FogLayer.update(dt)
        _G.RealMatchTimer = _G.RealMatchTimer + dt

        Input.update(dt)
        if PlayerBoard then PlayerBoard:update(dt) end
        
        if BotBoard then
            AIBot.board = BotBoard
            AIBot.opponent = PlayerBoard
            if AIBot.update and not BotBoard.is_dying then
                if _G.CURRENT_GAME_MODE == "boss_hunt" then
                    if BossPhases.current_phase == 2 then
                        AIBot.pps = AIBot.base_pps + 0.45
                    elseif BossPhases.current_phase == 3 then
                        AIBot.pps = AIBot.base_pps + 0.85
                    else
                        AIBot.pps = AIBot.base_pps
                    end
                end
                AIBot:update(dt)
            end
            BotBoard:update(dt)
        end

        AnomalyManager.update(dt, PlayerBoard, BotBoard)
        
        if _G.CURRENT_GAME_MODE == "boss_hunt" then
            PoiseSystem.update(dt)
            PartBreaking.update(dt)
            BossPhases.update(dt, PlayerBoard, BotBoard)

            if PoiseSystem.hp <= 0 and BossPhases.current_phase < 3 then
                BossPhases.triggerPhaseAdvance(PlayerBoard, BotBoard)
            end
        elseif _G.CURRENT_GAME_MODE == "benchmark" then
            BenchmarkManager.update(dt, PlayerBoard, BotBoard)
        end

        local p1_pps = (PlayerBoard and PlayerBoard.current_pps_display) or 0.0
        local bot_pps = (BotBoard and BotBoard.current_pps_display) or 0.0

        local titan_defeated = (_G.CURRENT_GAME_MODE == "boss_hunt" and BossPhases.current_phase == 3 and PoiseSystem.hp <= 0)
        local bot_knockout = (BotBoard and BotBoard.is_dying and BotBoard.death_timer <= 0.05 and _G.CURRENT_GAME_MODE ~= "boss_hunt")

        if PlayerBoard and PlayerBoard.is_dying and PlayerBoard.death_timer <= 0.05 and _G.CURRENT_GAME_MODE ~= "benchmark" then
            MetaBalancer.registerMatchOutcome(false, _G.RealMatchTimer, p1_pps, bot_pps)
            ReplayManager.saveReplay()
            Blackbox.log("MATCH_END", "PLAYER DEFEATED", math.floor(p1_pps * 10), math.floor(bot_pps * 10))
            SceneManager.setState("gameover")
        elseif (titan_defeated or bot_knockout) and st ~= "gameover" and _G.CURRENT_GAME_MODE ~= "benchmark" then
            MetaBalancer.registerMatchOutcome(true, _G.RealMatchTimer, p1_pps, bot_pps)
            ReplayManager.saveReplay()
            Blackbox.log("MATCH_END", titan_defeated and "TITAN COLOSSUS DEFEATED" or "BOT DEFEATED", math.floor(p1_pps * 10), math.floor(bot_pps * 10))
            SceneManager.setState("gameover")
        end
    else
        -- ⚡ DELEGACIÓN UNIVERSAL: Trainer Lab, Menú, Ajustes, Forja, Editor, Pausa, etc.
        SceneManager.update(dt)
    end
end
-- ================================================================
-- FILE: main.lua (PARTE 2 DE 2)
-- ================================================================
function love.draw()
    love.graphics.clear(0.01, 0.01, 0.02, 1.0)
    BloomShader.beginDraw()

    local st = SceneManager.getState()

    if st == "versus" or st == "gauntlet" or st == "boss_hunt" or st == "benchmark" or st == "gameover" or st == "pause" then
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

        if _G.CURRENT_GAME_MODE == "boss_hunt" then
            PoiseSystem.drawHUD()
            BossPhases.drawHUD(BotBoard, PlayerBoard)
        elseif _G.CURRENT_GAME_MODE == "benchmark" then
            BenchmarkManager.drawHUD()
        end

        PluginManager.draw()
        ThemeManager.drawRestartHalo()

        if st == "pause" or st == "gameover" then
            local modal_scene = SceneManager.getScene(st)
            if modal_scene and modal_scene.draw then modal_scene.draw(PlayerBoard, BotBoard) end
        end
    else
        -- Para Trainer Lab, Menú, Ajustes, Forja, Editor, Benchmark Results
        SceneManager.draw()
    end

    -- ⚠️ DIRECTIVA PRIMARIA PERMANENTE (REGLA DE ORO): Marca en x=16, y=698
    love.graphics.push("all")
    local t = ThemeManager.getCurrent()
    love.graphics.setFont(FontCache.get(10))
    love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.90)
    local watermark = string.format("%s  |  SKIN: %s", _G.ENGINE_VERSION, t.name)
    love.graphics.print(watermark, 16, 698)
    love.graphics.pop()

    if engage_timer > 0 then
        ThemeManager.drawEngageTransition(engage_timer, engage_duration)
    end

    BloomShader.endDraw(PlayerBoard and PlayerBoard.is_zone_active, view_ox, view_oy, view_scale)

    if ClipRecorder.is_recording and BloomShader.canvas then
        ClipRecorder.captureFrame(BloomShader.canvas)
    end

    ClipRecorder.drawHUDIndicator()

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

function love.keypressed(key)
    -- Atajos Globales de Sistema
    if key == "f9" then _G.ToggleRecording(); return end
    if key == "f12" or key == "f2" or key == "printscreen" or key == "sysrq" then _G.TakeScreenshot(); return end
    if key == "f5" then ThemeManager.cycleNext(); AudioManager.playSliderTick(); return end
    if key == "f6" then ThemeManager.cyclePrev(); AudioManager.playSliderTick(); return end
    if key == "f7" then 
        PluginManager.reloadAll()
        if PlayerBoard then PlayerBoard:setPopup("PLUGINS HOT-RELOADED", {0.1, 1.0, 0.5}) end
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

    local st = SceneManager.getState()

    if _G.CURRENT_GAME_MODE == "benchmark" and BenchmarkManager.isWaitingBriefing() then
        if key == "return" or key == "space" then BenchmarkManager.advanceFromBriefing(); return
        elseif key == "escape" then BenchmarkManager.is_active = false; SceneManager.setState("menu"); return end
    end

    -- Reinicio Rápido en Modos de Partida
    if key == "r" and (st == "versus" or st == "gauntlet" or st == "boss_hunt" or st == "benchmark" or st == "pause" or st == "gameover") then
        _G.GlobalRestart(false)
        SceneManager.setState(_G.CURRENT_GAME_MODE or "versus")
        return
    end

    -- Pausa Rápida con Escape en Modos de Partida
    if key == "escape" and (st == "versus" or st == "gauntlet" or st == "boss_hunt" or st == "benchmark") then
        local pause_scene = SceneManager.getScene("pause")
        if pause_scene then pause_scene.selection = 1 end
        SceneManager.setState("pause")
        MusicManager.pause()
        AudioManager.playMenuBack()
        return
    end

    -- Despacho a la Escena Activa (Trainer, Menú, Ajustes, etc.)
    if SceneManager.keypressed(key) then
        return
    end

    -- Fallback directo a los controles del jugador
    Input.keypressed(key)
end

function love.mousepressed(x, y, button)
    if button ~= 1 then return end
    local adj_x = (x - view_ox) / view_scale
    local adj_y = (y - view_oy) / view_scale

    if _G.CURRENT_GAME_MODE == "benchmark" and BenchmarkManager.isWaitingBriefing() then
        BenchmarkManager.advanceFromBriefing()
        return
    end

    SceneManager.mousepressed(adj_x, adj_y, button)
end

function love.gamepadpressed(joystick, button)
    local st = SceneManager.getState()

    if st == "versus" or st == "gauntlet" or st == "boss_hunt" or st == "benchmark" then
        if _G.CURRENT_GAME_MODE == "benchmark" and BenchmarkManager.isWaitingBriefing() then
            if button == "a" or button == "start" then
                BenchmarkManager.advanceFromBriefing()
                return
            end
        end

        if button == "start" then
            local pause_scene = SceneManager.getScene("pause")
            if pause_scene then pause_scene.selection = 1 end
            SceneManager.setState("pause")
            MusicManager.pause()
            AudioManager.playMenuBack()
            return
        end
        Input.gamepadpressed(joystick, button)
        return
    end

    SceneManager.gamepadpressed(joystick, button)
end

function love.errorhandler(msg)
    local err_text = tostring(msg) .. "\n\n" .. debug.traceback("", 2)
    pcall(Blackbox.dumpToFile, "saves/crash_report.txt", err_text)
    
    return function()
        love.event.pump()
        for e, a in love.event.poll() do
            if e == "quit" or (e == "keypressed" and a == "escape") then return 1 end
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
-- ================================================================
-- FILE: main.lua (RESTART HALO & ENHANCED WATERMARK PIPELINE)
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
local BloomShader        = require "tetris.bloom_shader"
local FogLayer           = require "tetris.fog_layer"
local FontCache          = require "tetris.font_cache"
local Blackbox           = require "core.blackbox"
local ScreenshotHelper   = require "core.screenshot_helper"
local ReplayManager      = require "core.replay_manager"
local ClipRecorder       = require "core.clip_recorder"
local SceneManager       = require "core.scene_manager"
local EventBus           = require "core.event_bus"
local PluginManager      = require "core.plugin_manager"
local AnomalyManager     = require "tetris.anomaly_manager"
_G.GifEncoder            = require "core.gif_encoder"

local OscClient          = require "network.osc_client"
local SoundManager       = require "audio.sound_manager"

local socket = require("socket")
local sc_rx_socket = nil
local sc_connected_flag = "SC_NET: DISCONNECTED"
local sc_audio_status = "AUDIO: SILENT"
local sc_timer = 0.0

local static_labels = {
    scene = "SCENE: ",
    skin = " | SKIN: ",
    fps = " | FPS: ",
    ram = " | RAM: ",
    mb = " MB | "
}
local watermark_buffer = { "", "", "", "", "", "", "", "", "", "", "", "", "", "" }

local view_scale, view_ox, view_oy = 1, 0, 0
local engage_timer, engage_duration = 0, 0
local screenshot_flash_timer = 0

local function updateViewScaling()
    local sw, sh = love.graphics.getDimensions()
    view_scale = math.min(sw / 1280, sh / 720)
    view_ox = (sw - 1280 * view_scale) / 2
    view_oy = (sh - 720 * view_scale) / 2
end

function love.load()
    sc_rx_socket = socket.udp()
    if sc_rx_socket then
        sc_rx_socket:setsockname("127.0.0.1", 12345)
        sc_rx_socket:settimeout(0)
    end

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
    
    _G.TakeScreenshot = function()
        ScreenshotHelper.capture(function(success)
            if success then
                screenshot_flash_timer = 1.0
                AudioManager.playImmediateSFX("menu_select", false)
            end
        end)
    end
    
    _G.ToggleRecording = function()
        if ClipRecorder.is_recording then
            ClipRecorder.stopRecording()
        else
            ClipRecorder.startRecording()
        end
    end
    
    _G.ToggleFullscreen = function()
        local isFullscreen = love.window.getFullscreen()
        love.window.setFullscreen(not isFullscreen, "desktop")
        updateViewScaling()
    end
    
    EventBus.init()
    PluginManager.init()
    SceneManager.init()
    
    -- Forced global hardware loop boot
    if _G.GifEncoder and _G.GifEncoder.init then
        _G.GifEncoder.init()
    end
    
    local SceneGame = require "scenes.scene_game"
    SceneManager.register("game", SceneGame)
    
    local SceneEditor = require "scenes.scene_editor"
    SceneManager.register("editor", SceneEditor)

    SceneManager.register("versus", SceneGame)
    SceneManager.register("boss_hunt", SceneGame)

    pcall(function() PluginManager.loadAllPlugins("plugins") end)
    pcall(function() PluginManager.initAllPlugins() end)

    MusicManager.start()
    SceneManager.setState("menu")
end

function love.resize(w, h)
    updateViewScaling()
end

function love.update(dt)
    -- --- 1. RUN THE GIF HUD FLASH TIMER OVERFLOW PROTECTION ---
    -- Dynamic HUD timer countdown update
    if _G.GifEncoder and _G.GifEncoder.update_hud then
        _G.GifEncoder.update_hud(dt)
    end

    -- --- RUN THE Parametric ANOMALY TIMER EACH FRAME ---
    if AnomalyManager and AnomalyManager.update then
        AnomalyManager.update(dt)
    end

    if sc_rx_socket then
        local data = sc_rx_socket:receive()
        if data then
            sc_connected_flag = "SC_NET: CONNECTED"
            sc_audio_status = "AUDIO: ACTIVE"
            sc_timer = 0.5
        end
    end
    
    if sc_timer > 0 then
        sc_timer = sc_timer - dt
        if sc_timer <= 0 then
            sc_audio_status = "AUDIO: SILENT"
        end
    end

    if _G.HitStopTimer > 0 then
        _G.HitStopTimer = _G.HitStopTimer - dt
        return
    end

    _G.RealMatchTimer = _G.RealMatchTimer + dt

    if screenshot_flash_timer > 0 then
        screenshot_flash_timer = math.max(0, screenshot_flash_timer - dt)
    end

    if engage_timer > 0 then
        engage_timer = math.max(0, engage_timer - dt)
    end

    if TrackManager.update then TrackManager.update(dt) end
    if BloomShader.update  then BloomShader.update(dt) end
    if FogLayer.update     then FogLayer.update(dt) end
    if ThemeManager.update then ThemeManager.update(dt) end

    SceneManager.update(dt)
end

function love.draw()
    love.graphics.clear(0.01, 0.01, 0.02, 1.0)
    BloomShader.beginDraw()

    -- 1. Renderizado de Escena Activa
    SceneManager.draw()

    -- 2. Halo Neón de Reinicio (Tecla 'R')
    if ThemeManager.drawRestartHalo then
        ThemeManager.drawRestartHalo()
    end

    -- 3. Marca de Agua Enriquecida Permanente (x=16, y=698)
    love.graphics.push("all")
    local t = ThemeManager.getCurrent() or { primary = {1, 1, 1} }
    local state_str = SceneManager.getState():upper()
    local scene_obj = SceneManager.getScene(SceneManager.getState())
    if state_str == "GAME" and scene_obj and scene_obj.layout_style then
        state_str = "GAME [" .. scene_obj.layout_style:upper() .. "]"
    end

    local current_fps = tostring(love.timer.getFPS())
    local current_ram = string.format("%.2f", collectgarbage("count") / 1024)
    local skin_name = t.name or "DEFAULT"
    local engine_ver = _G.ENGINE_VERSION or "MUTRIS v1.0"

    watermark_buffer[1] = engine_ver
    watermark_buffer[2] = " | "
    watermark_buffer[3] = static_labels.scene
    watermark_buffer[4] = state_str
    watermark_buffer[5] = static_labels.skin
    watermark_buffer[6] = skin_name
    watermark_buffer[7] = static_labels.fps
    watermark_buffer[8] = current_fps
    watermark_buffer[9] = static_labels.ram
    watermark_buffer[10] = current_ram
    watermark_buffer[11] = static_labels.mb
    watermark_buffer[12] = OscClient.get_telemetry()
    watermark_buffer[13] = " | "
    watermark_buffer[14] = "KEY: " .. (SoundManager.current_key_name or "8A (Am)")

    love.graphics.setFont(FontCache.get(9))
    love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.92)
    love.graphics.print(watermark_buffer, 16, 698)
    love.graphics.pop()

    if engage_timer > 0 then
        ThemeManager.drawEngageTransition(engage_timer, engage_duration)
    end

    BloomShader.endDraw(false, view_ox, view_oy, view_scale)

    if ClipRecorder.is_recording and BloomShader.canvas then
        ClipRecorder.captureFrame(BloomShader.canvas)
    end

    ClipRecorder.drawHUDIndicator()

    if screenshot_flash_timer > 0 then
        local a = math.min(1.0, screenshot_flash_timer * 1.5)
        local t_cur = ThemeManager.getCurrent() or { secondary = {1,1,1} }
        love.graphics.setColor(0.02, 0.03, 0.06, 0.95 * a)
        love.graphics.rectangle("fill", 440, 655, 380, 36, 4)
        love.graphics.setLineWidth(1.2)
        love.graphics.setColor(t_cur.secondary[1], t_cur.secondary[2], t_cur.secondary[3], 0.90 * a)
        love.graphics.rectangle("line", 440, 655, 380, 36, 4)
        love.graphics.setFont(FontCache.get(10))
        love.graphics.setColor(1, 1, 1, 0.98 * a)
        love.graphics.printf("COPIED TO CLIPBOARD! (CTRL+V)", 440, 666, 380, "center")
    end

    if ThemeManager.drawToast then ThemeManager.drawToast() end

    -- --- CRITICAL RE-ALINEATION: EXPLICIT SCREENSHOT SNAP FROM FRONT BUFFER ---
    if _G.GifEncoder and _G.GifEncoder.capture_frame then
        _G.GifEncoder.capture_frame()
    end

    -- --- DRAW INDESTRUCTIBLE PARADIGM NOTIFICATION OVER HUD GRAPHICS ---
    if _G.GifEncoder and _G.GifEncoder.draw_hud_indicator then
        _G.GifEncoder.draw_hud_indicator()
    end
end

function love.keypressed(key, scancode, isrepeat)
    -- --- SYSTEM CAPTURE DISPATCHER (FORCED GLOBAL ROUTING) ---
    if key == "f12" then
        if _G.GifEncoder and _G.GifEncoder.compile_clip then
            _G.GifEncoder.compile_clip()
        end
        return
    end

    if key == "f9" then _G.ToggleRecording(); return end
    if key == "f2" or key == "printscreen" or key == "sysrq" then _G.TakeScreenshot(); return end
    if key == "f5" then ThemeManager.cycleNext(); AudioManager.playSliderTick(); return end
    if key == "f6" then ThemeManager.cyclePrev(); AudioManager.playSliderTick(); return end
    if key == "f7" then 
        PluginManager.reloadAll()
        return 
    end
    if key == "f11" or (key == "return" and (love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt"))) then
        _G.ToggleFullscreen()
        return
    end

    SceneManager.keypressed(key)
end

function love.keyreleased(key)
    SceneManager.keyreleased(key)
end

function love.mousepressed(x, y, button)
    if button ~= 1 then return end
    local adj_x = (x - view_ox) / view_scale
    local adj_y = (y - view_oy) / view_scale

    SceneManager.mousepressed(adj_x, adj_y, button)
end

function love.gamepadpressed(joystick, button)
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
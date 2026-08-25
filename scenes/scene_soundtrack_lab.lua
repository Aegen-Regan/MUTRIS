-- ============================================================================
-- FILE: scenes/scene_soundtrack_lab.lua
-- MUTRIS ENGINE: SOUNDTRACK TONALITY LAB (CAMELOT CONFIGURATOR)
-- ============================================================================
---@diagnostic disable: undefined-global

local SceneSoundtrackLab = {}

local SoundtrackDB = require("audio.soundtrack_db")
local SoundManager = require("audio.sound_manager")
local ThemeManager = require("tetris.theme_manager")
local FontCache    = require("tetris.font_cache")
local SceneManager = require("core.scene_manager")

local selected_track_idx = 1
local max_tracks = 3

function SceneSoundtrackLab.enter()
    SoundtrackDB.load()
    max_tracks = #SoundtrackDB.tracks
    selected_track_idx = 1
    _G.AudioBeatPulse = 0.0
end

function SceneSoundtrackLab.update(dt)
    SoundManager.update(dt)
end

function SceneSoundtrackLab.draw()
    if ThemeManager.drawBackground then ThemeManager.drawBackground() end
    
    local w, h = love.graphics.getDimensions()
    local t = ThemeManager.getCurrent()
    
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, w, h)
    
    love.graphics.setFont(FontCache.get(32))
    love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 1.0)
    love.graphics.printf("SOUNDTRACK TONALITY LAB", 0, 80, w, "center")
    
    love.graphics.setFont(FontCache.get(14))
    love.graphics.setColor(0.7, 0.7, 0.7, 1.0)
    love.graphics.printf("CONFIGURA EL MAPEO CAMELOT PARA CADA PISTA", 0, 130, w, "center")

    local sy = 220
    for i, track in ipairs(SoundtrackDB.tracks) do
        local is_selected = (i == selected_track_idx)
        
        -- Draw Selection Box
        if is_selected then
            love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.2 + (_G.AudioBeatPulse * 0.3))
            love.graphics.rectangle("fill", w/2 - 350, sy - 15, 700, 50, 8)
            love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 1.0)
            love.graphics.rectangle("line", w/2 - 350, sy - 15, 700, 50, 8)
        end
        
        love.graphics.setFont(FontCache.get(18))
        love.graphics.setColor(1, 1, 1, is_selected and 1.0 or 0.5)
        love.graphics.print(track.name, w/2 - 320, sy)
        
        local camelot = SoundtrackDB.CAMELOT_KEYS[track.camelot_index]
        local key_text = camelot and camelot.name or "UNKNOWN"
        
        if is_selected then
            love.graphics.setColor(1, 0.9, 0.2, 1.0)
            love.graphics.print("<  " .. key_text .. "  >", w/2 + 150, sy)
        else
            love.graphics.setColor(0.6, 0.6, 0.6, 1.0)
            love.graphics.print(key_text, w/2 + 170, sy)
        end
        
        sy = sy + 70
    end
    
    -- Draw Controls
    love.graphics.setFont(FontCache.get(12))
    love.graphics.setColor(0.5, 0.9, 1.0, 0.8)
    local controls_y = h - 80
    love.graphics.printf("[ ARRIBA / ABAJO ] SELECCIONAR PISTA   |   [ IZQUIERDA / DERECHA ] CAMBIAR CAMELOT KEY", 0, controls_y, w, "center")
    love.graphics.printf("[ ESPACIO ] AUDICIONAR ACORDE   |   [ S ] GUARDAR EN DISCO   |   [ ESC ] VOLVER AL MENÚ", 0, controls_y + 25, w, "center")
end

function SceneSoundtrackLab.keypressed(key)
    if key == "escape" then
        SceneManager.setState("menu")
        return
    end
    
    if key == "up" then
        selected_track_idx = selected_track_idx - 1
        if selected_track_idx < 1 then selected_track_idx = max_tracks end
        SoundManager.play_move()
    elseif key == "down" then
        selected_track_idx = selected_track_idx + 1
        if selected_track_idx > max_tracks then selected_track_idx = 1 end
        SoundManager.play_move()
    end
    
    if key == "left" then
        local t = SoundtrackDB.tracks[selected_track_idx]
        t.camelot_index = t.camelot_index - 1
        if t.camelot_index < 1 then t.camelot_index = 24 end
        SoundManager.play_rotate()
    elseif key == "right" then
        local t = SoundtrackDB.tracks[selected_track_idx]
        t.camelot_index = t.camelot_index + 1
        if t.camelot_index > 24 then t.camelot_index = 1 end
        SoundManager.play_rotate()
    end
    
    if key == "space" or key == "return" then
        local t = SoundtrackDB.tracks[selected_track_idx]
        SoundManager.set_active_track(t.id)
        SoundManager.play_line_clear(4, 0) -- Play chord at Tetris intensity
    end
    
    if key == "s" then
        SoundtrackDB.save()
        SoundManager.play_hard_drop()
        if ThemeManager.showToast then
            ThemeManager.showToast("SOUNDTRACK DB SAVED", {0.1, 1.0, 0.5})
        end
    end
end

return SceneSoundtrackLab

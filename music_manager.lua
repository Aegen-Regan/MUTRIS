-- ================================================================
-- FILE: music_manager.lua
-- ================================================================
---@diagnostic disable: undefined-global
local MusicManager = {}
local love = love

MusicManager.layers = {}
MusicManager.custom_source = nil

function MusicManager.loadLayers(file_paths)
    MusicManager.layers = {}
end

function MusicManager.setIntensity(value) end

function MusicManager.stop()
    if MusicManager.custom_source and MusicManager.custom_source:isPlaying() then
        MusicManager.custom_source:stop()
    end
end

function MusicManager.pause()
    if MusicManager.custom_source and MusicManager.custom_source:isPlaying() then
        MusicManager.custom_source:pause()
    end
end

function MusicManager.resume()
    if MusicManager.custom_source and not MusicManager.custom_source:isPlaying() then
        MusicManager.custom_source:play()
    end
end

function MusicManager.isPlaying()
    if MusicManager.custom_source then
        return MusicManager.custom_source:isPlaying()
    end
    return false
end

function MusicManager.start()
    local TrackManager = require "track_manager"
    local SettingsManager = require "settings_manager"
    local current_track = TrackManager.getCurrentTrack()

    if current_track and not current_track.is_embedded and current_track.file_path ~= "" then
        if MusicManager.custom_source then 
            MusicManager.custom_source:stop() 
        end
        local success, src = pcall(love.audio.newSource, current_track.file_path, "stream")
        if success then
            MusicManager.custom_source = src
            MusicManager.custom_source:setLooping(true)
            local bgm_norm = SettingsManager.getBGM()
            MusicManager.custom_source:setVolume(bgm_norm * 0.85)
            MusicManager.custom_source:seek(0, "seconds")
            MusicManager.custom_source:play()
        end
    end
end

function MusicManager.getTime()
    if MusicManager.custom_source and MusicManager.custom_source:isPlaying() then
        return MusicManager.custom_source:tell("seconds")
    end
    return 0
end

function MusicManager.update(dt)
    local SettingsManager = require "settings_manager"
    local AudioManager = require "audio_manager"
    if MusicManager.custom_source and MusicManager.custom_source:isPlaying() then
        local bgm_norm = SettingsManager.getBGM()
        
        -- 🎚️ VACÍO TOTAL: En impactos la música cae a 0.0 (Silencio total)
        local duck = AudioManager.duck_intensity or 0
        local duck_multiplier = math.max(0.0, 1.0 - duck)
        
        local target_base = (AudioManager.zone_active and 1.15 or 0.85) * bgm_norm * duck_multiplier
        local cur_vol = MusicManager.custom_source:getVolume()
        
        -- Ataque de choque brutal (60 * dt) y recuperación suave
        local lerp_speed = (target_base < cur_vol) and 60 or 5
        MusicManager.custom_source:setVolume(cur_vol + (target_base - cur_vol) * lerp_speed * dt)
    end
end

return MusicManager
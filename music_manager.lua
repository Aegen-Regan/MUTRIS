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

function MusicManager.start()
    local TrackManager = require "track_manager"
    local SettingsManager = require "settings_manager"
    local current_track = TrackManager.getCurrentTrack()

    if not current_track.is_embedded then
        if MusicManager.custom_source then MusicManager.custom_source:stop() end
        MusicManager.custom_source = love.audio.newSource(current_track.file_path, "stream")
        MusicManager.custom_source:setLooping(true)

        local bgm_norm = SettingsManager.getBGM()
        MusicManager.custom_source:setVolume(bgm_norm * 0.85)

        MusicManager.custom_source:play()
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
        local target_base = (AudioManager.zone_active and 1.15 or 0.85) * bgm_norm
        local cur_vol = MusicManager.custom_source:getVolume()
        MusicManager.custom_source:setVolume(cur_vol + (target_base - cur_vol) * 4 * dt)
    end
end

return MusicManager
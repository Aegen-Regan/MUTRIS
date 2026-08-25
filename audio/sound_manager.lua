-- ============================================================================
-- FILE: audio/sound_manager.lua
-- MUTRIS ENGINE: DYNAMIC AUDIO & EXACT SOUNDTRACK TONALITY CALIBRATION (Zero-GC)
-- TARGET: Intel Pentium G3250 Haswell / Standalone High-Performance Audio
-- ============================================================================
---@diagnostic disable: undefined-global

local SoundManager = {}
local OscClient = nil -- Lazy load to prevent circular require
local SoundtrackDB = require("audio.soundtrack_db")

-- STATE VARIABLES
SoundManager.active_track_id   = "base_fondo"
SoundManager.current_track     = SoundtrackDB.tracks[1]
SoundManager.current_camelot   = 11
SoundManager.current_key_name  = "11A (F#m)"
SoundManager.sfx_enabled       = true
SoundManager.music_enabled     = true
SoundManager.master_volume     = 0.85

-- STATIC VOICE POOLS
local VOICE_COUNT = 6
local voice_pools = {}
local voice_heads = {}

-- Beat Pulse Tracker
_G.AudioBeatPulse = 0.0

-- ============================================================================
-- PROCEDURAL SOUND SYNTHESIZER (Fallbacks)
-- ============================================================================
local function generate_procedural_beep(freq, duration, decay_type)
    local sample_rate = 44100
    local samples = math.floor(sample_rate * duration)
    local sound_data = love.sound.newSoundData(samples, sample_rate, 16, 1)
    local tau = math.pi * 2

    for i = 0, samples - 1 do
        local t = i / sample_rate
        local envelope = 1.0
        
        if decay_type == "pluck" then
            envelope = math.exp(-t * 14.0)
        elseif decay_type == "impact" then
            envelope = math.exp(-t * 18.0)
        elseif decay_type == "chord" then
            envelope = math.exp(-t * 4.5)
        else
            envelope = 1.0 - (i / samples)
        end

        local val = (math.sin(tau * freq * t) * 0.70 + math.sin(tau * (freq * 2.0) * t) * 0.30) * envelope
        sound_data:setSample(i, val * 0.6)
    end

    return love.audio.newSource(sound_data, "static")
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================
function SoundManager.init()
    pcall(function() OscClient = require("network.osc_client") end)

    voice_pools = {
        drop       = {},
        move       = {},
        rotate     = {},
        line_clear = {},
        tspin      = {},
        tetris     = {},
        chord      = {}
    }

    voice_heads = {
        drop       = 1,
        move       = 1,
        rotate     = 1,
        line_clear = 1,
        tspin      = 1,
        tetris     = 1,
        chord      = 1
    }

    -- Pre-generate voice pool buffers
    local function load_or_synth(name, path, freq, dur, decay)
        voice_pools[name] = {}
        for i = 1, VOICE_COUNT do
            local src = nil
            if love.filesystem.getInfo(path) then
                src = love.audio.newSource(path, "static")
            else
                src = generate_procedural_beep(freq, dur, decay)
            end
            src:setVolume(SoundManager.master_volume)
            voice_pools[name][i] = src
        end
    end

    load_or_synth("drop",       "assets/audio/sfx/hard_drop.ogg",   92.5,  0.15, "impact")
    load_or_synth("move",       "assets/audio/sfx/move.ogg",        370.0, 0.04, "pluck")
    load_or_synth("rotate",     "assets/audio/sfx/rotate.ogg",      440.0, 0.05, "pluck")
    load_or_synth("line_clear", "assets/audio/sfx/line_clear.ogg",  554.3, 0.35, "chord")
    load_or_synth("tspin",      "assets/audio/sfx/tspin.ogg",       740.0, 0.45, "pluck")
    load_or_synth("tetris",     "assets/audio/sfx/tetris.ogg",      92.5,  0.60, "impact")

    -- Pre-allocate Chords for ALL 24 Camelot Keys
    voice_pools.chords = {}
    for i, data in ipairs(SoundtrackDB.CAMELOT_KEYS) do
        voice_pools.chords[i] = {}
        local path = string.format("assets/audio/chords/camelot_%s.ogg", data.id)
        for v = 1, 4 do
            local src = nil
            if love.filesystem.getInfo(path) then
                src = love.audio.newSource(path, "static")
            else
                src = generate_procedural_beep(data.root_freq, 0.85, "chord")
            end
            src:setVolume(SoundManager.master_volume)
            voice_pools.chords[i][v] = src
        end
    end

    SoundManager.set_active_track("base_fondo")
end

-- ============================================================================
-- DYNAMIC TRACK / TONALITY SELECTION
-- ============================================================================
function SoundManager.set_active_track(track_name_or_key)
    local track, camelot = SoundtrackDB.get_track_info(track_name_or_key)
    if track and camelot then
        SoundManager.active_track_id  = track.id
        SoundManager.current_track    = track
        SoundManager.current_camelot  = track.camelot_index
        SoundManager.current_key_name = camelot.name

        if OscClient and OscClient.is_active and OscClient.is_active() then
            OscClient.send_camelot(track.camelot_index)
        end
    end
end

-- ============================================================================
-- PLAYBACK METHODS (Zero-GC Multi-Voice)
-- ============================================================================
local function play_voice(name, pitch_mult, volume_mult)
    if not SoundManager.sfx_enabled then return end
    local pool = voice_pools[name]
    if not pool then return end

    local head = voice_heads[name]
    local src  = pool[head]

    if src then
        src:stop()
        src:setPitch(pitch_mult or 1.0)
        src:setVolume((volume_mult or 1.0) * SoundManager.master_volume)
        src:play()
    end

    voice_heads[name] = (head % VOICE_COUNT) + 1
end

function SoundManager.play_move()
    play_voice("move", 1.0, 0.4)
end

function SoundManager.play_rotate()
    play_voice("rotate", 1.0, 0.5)
end

function SoundManager.play_hard_drop()
    play_voice("drop", 1.0, 0.9)
    _G.AudioBeatPulse = math.max(_G.AudioBeatPulse, 0.6)
end

function SoundManager.play_line_clear(lines, combo)
    if lines == 4 then
        play_voice("tetris", 1.0, 1.0)
        _G.AudioBeatPulse = 1.0
    else
        play_voice("line_clear", 1.0 + (lines * 0.06), 0.8)
    end

    -- Trigger chord aligned with the active track tonality
    local camelot_id = SoundManager.current_camelot
    local pool = voice_pools.chords and voice_pools.chords[camelot_id]
    if pool then
        local voice_idx = (combo and (combo % 4) + 1) or 1
        local src = pool[voice_idx]
        if src then
            src:stop()
            local pitch = 1.0 + (math.min(combo or 0, 8) * 0.03)
            src:setPitch(pitch)
            src:play()
        end
    end

    _G.AudioBeatPulse = math.max(_G.AudioBeatPulse, 0.8)
end

function SoundManager.play_tspin()
    play_voice("tspin", 1.0, 1.0)
    _G.AudioBeatPulse = 1.0
end

function SoundManager.reset()
    local track = SoundManager.current_track or SoundtrackDB.tracks[1]
    SoundManager.set_active_track(SoundManager.active_track_id or "base_fondo")
    _G.AudioBeatPulse = 0.0
end

function SoundManager.update(dt)
    if _G.AudioBeatPulse > 0.0 then
        _G.AudioBeatPulse = math.max(0.0, _G.AudioBeatPulse - dt * 4.5)
    end
end

return SoundManager

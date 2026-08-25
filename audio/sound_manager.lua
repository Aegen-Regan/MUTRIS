-- ============================================================================
-- FILE: audio/sound_manager.lua
-- MUTRIS ENGINE: COMPLETE MULTI-TIMBRAL & PENTATONIC AUDIO ENGINE (Zero-GC)
-- ============================================================================
---@diagnostic disable: undefined-global

local SoundManager = {}
local SoundtrackDB = require("audio.soundtrack_db")
local OscClient    = require("network.osc_client")

-- SCALE DEFINITIONS (Semitone offsets across 2 Octaves)
local PENTATONIC_MINOR = { 0, 3, 5, 7, 10, 12, 15, 17, 19, 22 }
local PENTATONIC_MAJOR = { 0, 2, 4, 7, 9,  12, 14, 16, 19, 21 }

-- PRE-CALCULATED PITCH MAP (Zero-GC lookup, no runtime alloc)
local PITCH_MAP = {}
for st = 0, 36 do PITCH_MAP[st] = 2 ^ (st / 12.0) end

-- STATE
SoundManager.active_track_id   = "base_fondo"
SoundManager.current_key_name  = "11A (F#m)"
SoundManager.root_freq         = 185.00
SoundManager.root_midi         = 54
SoundManager.bass_midi         = 30
SoundManager.lead_midi         = 66
SoundManager.is_major          = false
SoundManager.active_intervals  = PENTATONIC_MINOR
SoundManager.sfx_enabled       = true
SoundManager.master_volume     = 0.85

local VOICE_COUNT  = 8
local voice_pools  = {}
local voice_heads  = {}
local chord_buffer = {0, 0, 0, 0, 0}

_G.AudioBeatPulse = 0.0

-- ============================================================================
-- PROCEDURAL SYNTHESIZER FALLBACK
-- ============================================================================
local function generate_procedural_beep(freq, duration, decay_type)
    local sample_rate = 44100
    local samples     = math.floor(sample_rate * duration)
    local sound_data  = love.sound.newSoundData(samples, sample_rate, 16, 1)
    local tau         = math.pi * 2

    for i = 0, samples - 1 do
        local t   = i / sample_rate
        local env = 1.0
        if     decay_type == "pluck"  then env = math.exp(-t * 16.0)
        elseif decay_type == "impact" then env = math.exp(-t * 20.0)
        elseif decay_type == "chord"  then env = math.exp(-t * 4.0)
        else                               env = 1.0 - (i / samples) end

        local val = (math.sin(tau * freq * t) * 0.75 + math.sin(tau * (freq * 2.0) * t) * 0.25) * env
        sound_data:setSample(i, val * 0.6)
    end
    return love.audio.newSource(sound_data, "static")
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================
function SoundManager.init()
    voice_pools = {
        drop = {}, move = {}, rotate = {}, hold = {}, tspin = {}, tetris = {}, chord = {}
    }
    voice_heads = {
        drop = 1, move = 1, rotate = 1, hold = 1, tspin = 1, tetris = 1, chord = 1
    }

    local function init_pool(name, path, freq, dur, decay)
        voice_pools[name] = {}
        for i = 1, VOICE_COUNT do
            local src = love.filesystem.getInfo(path)
                and love.audio.newSource(path, "static")
                or  generate_procedural_beep(freq, dur, decay)
            src:setVolume(SoundManager.master_volume)
            voice_pools[name][i] = src
        end
    end

    init_pool("drop",   "assets/audio/sfx/hard_drop.ogg",  92.5,  0.16, "impact")
    init_pool("move",   "assets/audio/sfx/move.ogg",       370.0, 0.04, "pluck")
    init_pool("rotate", "assets/audio/sfx/rotate.ogg",     554.3, 0.06, "pluck")
    init_pool("hold",   "assets/audio/sfx/hold.ogg",       493.8, 0.12, "pluck")
    init_pool("tspin",  "assets/audio/sfx/tspin.ogg",      740.0, 0.45, "pluck")
    init_pool("tetris", "assets/audio/sfx/tetris.ogg",     92.5,  0.65, "impact")
    init_pool("chord",  "assets/audio/sfx/line_clear.ogg", 370.0, 0.40, "chord")

    SoundManager.set_active_track("base_fondo")
end

-- ============================================================================
-- TONALITY SWITCHERS
-- ============================================================================
function SoundManager.set_active_track(track_id)
    local t, k, m = SoundtrackDB.get_track_info(track_id or "base_fondo")
    SoundManager.active_track_id  = t.id
    SoundManager.current_key_name = k.name
    SoundManager.root_freq        = k.root_freq or 185.00
    SoundManager.root_midi        = (k.midi or 54) + ((t.octave_offset or 0) * 12)
    SoundManager.bass_midi        = SoundManager.root_midi - 24
    SoundManager.lead_midi        = SoundManager.root_midi + 12
    SoundManager.is_major         = (k.scale == "major")
    SoundManager.active_intervals = m.intervals or (SoundManager.is_major and PENTATONIC_MAJOR or PENTATONIC_MINOR)
end

function SoundManager.load_stage_soundset(stage_num)
    local stg, t, k, m = SoundtrackDB.get_stage_info(stage_num)
    if not stg then return end
    SoundManager.active_track_id  = t.id
    SoundManager.current_key_name = k.name
    SoundManager.root_freq        = k.root_freq or 185.00
    SoundManager.root_midi        = (k.midi or 54) + ((stg.octave_offset or 0) * 12)
    SoundManager.bass_midi        = SoundManager.root_midi - 24
    SoundManager.lead_midi        = SoundManager.root_midi + 12
    SoundManager.is_major         = (k.scale == "major")
    SoundManager.active_intervals = m.intervals or (SoundManager.is_major and PENTATONIC_MAJOR or PENTATONIC_MINOR)
end

function SoundManager.sync_with_current_bgm(bgm_filename)
    if bgm_filename then
        SoundManager.set_active_track(bgm_filename)
    else
        SoundManager.set_active_track(SoundManager.active_track_id or "base_fondo")
    end
end

function SoundManager.reset()
    SoundManager.set_active_track(SoundManager.active_track_id or "base_fondo")
    _G.AudioBeatPulse = 0.0
end

-- ============================================================================
-- VOICE PLAYBACK HELPER (Zero-GC round-robin)
-- ============================================================================
local function play_voice(name, pitch, vol)
    if not SoundManager.sfx_enabled then return end
    local pool = voice_pools[name]
    if not pool then return end
    local head = voice_heads[name]
    local src  = pool[head]
    if src then
        src:stop()
        src:setPitch(pitch or 1.0)
        src:setVolume((vol or 1.0) * SoundManager.master_volume)
        src:play()
    end
    voice_heads[name] = (head % VOICE_COUNT) + 1
end

-- ============================================================================
-- SINESTHETIC GAMEPLAY HOOKS
-- ============================================================================

-- 1. Pentatonic Lateral Move (Cols 1..10)
function SoundManager.play_move_column(col_x)
    local col   = math.max(1, math.min(10, col_x or 5))
    local st    = SoundManager.active_intervals[col] or 0
    play_voice("move", PITCH_MAP[st] or 1.0, 0.40)
    OscClient.send_move_pentatonic(SoundManager.lead_midi + st)
end

-- Fallback: play_move without column pitch (event bus path)
function SoundManager.play_move()
    play_voice("move", 1.0, 0.4)
end

-- 2. Piece Rotation (5th interval arp of current column)
function SoundManager.play_rotate(current_col)
    local col     = math.max(1, math.min(10, current_col or 5))
    local base_st = SoundManager.active_intervals[col] or 0
    local rot_st  = math.min(base_st + 7, 36)
    play_voice("rotate", PITCH_MAP[rot_st] or 1.5, 0.50)
    OscClient.send_rotate_note(SoundManager.lead_midi + rot_st)
end

-- 3. Piece Hold (Sus4 tonal anchor)
function SoundManager.play_hold()
    play_voice("hold", PITCH_MAP[5] or 1.33, 0.60)  -- Sus4 = +5 semitones
    OscClient.send_hold_note(SoundManager.lead_midi + 5)
end

-- 4. Hard Drop (Sub-Bass Impact)
function SoundManager.play_hard_drop()
    play_voice("drop", 1.0, 0.95)
    _G.AudioBeatPulse = math.max(_G.AudioBeatPulse, 0.7)
    OscClient.send_drop(SoundManager.bass_midi)
end

-- 5. T-Spin (FM Lead Octave Stab)
function SoundManager.play_tspin()
    play_voice("tspin", 1.0, 1.0)
    _G.AudioBeatPulse = 1.0
    OscClient.send_tspin(SoundManager.lead_midi + 12)
end

-- 6. Functional Harmonic Line Clears (1L=Triad, 2L=7th, 3L=9th, 4L=Tetris)
function SoundManager.play_line_clear(lines, combo)
    local r     = SoundManager.root_midi
    local third = SoundManager.is_major and 4 or 3
    local count = 0

    if lines == 1 then
        chord_buffer[1], chord_buffer[2], chord_buffer[3] = r, r + third, r + 7
        count = 3
        play_voice("chord", 1.0, 0.8)
    elseif lines == 2 then
        local seventh = SoundManager.is_major and 11 or 10
        chord_buffer[1], chord_buffer[2], chord_buffer[3], chord_buffer[4] = r, r + third, r + 7, r + seventh
        count = 4
        play_voice("chord", 1.12, 0.85)
    elseif lines == 3 then
        local seventh = SoundManager.is_major and 11 or 10
        chord_buffer[1], chord_buffer[2], chord_buffer[3], chord_buffer[4], chord_buffer[5] = r, r + third, r + 7, r + seventh, r + 14
        count = 5
        play_voice("chord", 1.26, 0.90)
    elseif lines == 4 then
        chord_buffer[1], chord_buffer[2], chord_buffer[3], chord_buffer[4] = r - 12, r, r + 7, r + 12
        count = 4
        play_voice("tetris", 1.0, 1.0)
        OscClient.send_tetris(SoundManager.bass_midi - 12)
    end

    local notes_out = {}
    for n = 1, count do notes_out[n] = chord_buffer[n] end
    OscClient.send_chord(notes_out, 0.25)
    _G.AudioBeatPulse = 1.0
end

-- ============================================================================
-- FRAME UPDATE
-- ============================================================================
function SoundManager.update(dt)
    if _G.AudioBeatPulse > 0.0 then
        _G.AudioBeatPulse = math.max(0.0, _G.AudioBeatPulse - dt * 4.5)
    end
end

return SoundManager

---@diagnostic disable: undefined-global
local AudioManager = {}
local SettingsManager = require "settings_manager"

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  🎛️  PANEL DE CONTROL DE SFX HARMONIZATION MUTRIS v0.9.5         ║
-- ╚══════════════════════════════════════════════════════════════════════╝
AUDIO_CONFIG = {
    SFX_DURATION_BASE_BOOST_MIN = 1.0,
    SFX_DURATION_BASE_BOOST_MAX = 2.4,
    DELAY_TAP1_MS_MIN = 0.030,
    DELAY_TAP1_MS_MAX = 0.180,
    DELAY_TAP2_MS_MIN = 0.055,
    DELAY_TAP2_MS_MAX = 0.310,
    DELAY_FEEDBACK_TAP1_MIN = 0.02,
    DELAY_FEEDBACK_TAP1_MAX = 0.42,
    DELAY_FEEDBACK_TAP2_MIN = 0.01,
    DELAY_FEEDBACK_TAP2_MAX = 0.28,
    DRIVE_BOOST_MIN = 0.0,
    DRIVE_BOOST_MAX = 4.2,
    DECAY_DIVISOR_MIN = 1.0,
    DECAY_DIVISOR_MAX = 4.8,
    ZONE_EXTRA_DURATION = 1.35,
    ZONE_EXTRA_DRIVE  = 3.0,
    ZONE_PITCH_SHIFT  = 0.97,
    DANGER_GLITCH_CHANCE = 0.30,
}

local SCALE = {
    C2=65.41, C3=130.81, G2=98.00, F2=87.31,
    Eb2=77.78, Bb2=116.54,
    C4=261.63, E4=329.63, G4=392.00, B4=493.88
}

_G.PLAYER_NOTES = { SCALE.C2, SCALE.Eb2, SCALE.G2, SCALE.Bb2 }
_G.BOT_NOTES    = { SCALE.C2, SCALE.Eb2, SCALE.G2, SCALE.Bb2 }
_G.BG_SCALE      = { SCALE.C2 * 0.5, SCALE.Eb2 * 0.5, SCALE.G2 * 0.5 }

AudioManager.beat_timer = 0
AudioManager.base_bpm = 120
AudioManager.current_bpm = 120
AudioManager.step = 0

AudioManager.zone_active = false
AudioManager.glitch_timer = 0
_G.AudioBeatPulse = 0
AudioManager.melody_step = 1
_G.TrackEnergyPunch = 0

local function lerp(a, b, t) return a + (b - a) * t end

local function tanh(x)
    local e2x = math.exp(2 * x)
    return (e2x - 1) / (e2x + 1)
end

function AudioManager.init()
    AudioManager.beat_timer = 0
    AudioManager.step = 0
    AudioManager.melody_step = 1
    _G.TrackEnergyPunch = 0
    AudioManager.glitch_timer = 0
end

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  🔊  NUEVOS SFX: Menú, Hover, Slider, Back, Mute                  ║
-- ╚══════════════════════════════════════════════════════════════════════╝
function AudioManager.playMenuClick()
    AudioManager.playTone(1800, 0.11, 0.28, "sine", false, 0.0, 38, true)
end

function AudioManager.playMenuHover()
    AudioManager.playTone(620, 0.06, 0.18, "triangle", false, 0.0, 60, true)
end

function AudioManager.playSliderTick()
    AudioManager.playTone(1400, 0.03, 0.22, "sine", false, 0.0, 90, true)
end

function AudioManager.playMenuBack()
    local sfx_vol = SettingsManager.getSFX()
    local sample_rate = 44100
    local length = math.floor(sample_rate * 0.2)
    if length <= 0 then return end
    local data = love.sound.newSoundData(length, sample_rate, 16, 1)
    for i = 0, length - 1 do
        local t = i / sample_rate
        local f = 980 - (420 * (t / 0.2))
        local val = math.sin(2 * math.pi * f * t)
        val = val * math.exp(-14 * t)
        data:setSample(i, val * 0.32 * sfx_vol)
    end
    love.audio.play(love.audio.newSource(data, "static"))
end

function AudioManager.playMuteToggle(is_muted)
    if is_muted then
        AudioManager.playTone(600, 0.16, 0.3, "triangle", false, 0.5, 28, true)
    else
        local sfx_vol = SettingsManager.getSFX()
        local sample_rate = 44100
        local length = math.floor(sample_rate * 0.18)
        if length <= 0 then return end
        local data = love.sound.newSoundData(length, sample_rate, 16, 1)
        for i = 0, length - 1 do
            local t = i / sample_rate
            local f = 1600 + (600 * (t / 0.18))
            local val = math.sin(2 * math.pi * f * t)
            val = val * math.exp(-11 * t)
            data:setSample(i, val * 0.3 * sfx_vol)
        end
        love.audio.play(love.audio.newSource(data, "static"))
    end
end

function AudioManager.playTone(freq, duration, volume, wave_type, is_kick, drive, decay, no_lfo)
    if AudioManager.glitch_timer > 0 and math.random() < AUDIO_CONFIG.DANGER_GLITCH_CHANCE then return end

    local energy = _G.TrackEnergyPunch or 0
    local e2 = energy * energy
    local sample_rate = 44100

    local dur_boost    = lerp(AUDIO_CONFIG.SFX_DURATION_BASE_BOOST_MIN, AUDIO_CONFIG.SFX_DURATION_BASE_BOOST_MAX, energy)
    local zone_dur     = (AudioManager.zone_active and not is_kick) and AUDIO_CONFIG.ZONE_EXTRA_DURATION or 1.0
    local effective_duration = duration * dur_boost * zone_dur
    local length = math.floor(sample_rate * effective_duration)
    if length <= 0 then return end

    local drive_boost = lerp(AUDIO_CONFIG.DRIVE_BOOST_MIN, AUDIO_CONFIG.DRIVE_BOOST_MAX, energy)
    drive = (drive or 0) + drive_boost
    if AudioManager.zone_active and not is_kick then drive = drive + AUDIO_CONFIG.ZONE_EXTRA_DRIVE end

    local decay_div = lerp(AUDIO_CONFIG.DECAY_DIVISOR_MIN, AUDIO_CONFIG.DECAY_DIVISOR_MAX, energy)
    decay = (decay or 22) / decay_div

    if AudioManager.zone_active and not is_kick then freq = freq * AUDIO_CONFIG.ZONE_PITCH_SHIFT end

    local tap1_ms   = lerp(AUDIO_CONFIG.DELAY_TAP1_MS_MIN,   AUDIO_CONFIG.DELAY_TAP1_MS_MAX,   energy)
    local tap2_ms   = lerp(AUDIO_CONFIG.DELAY_TAP2_MS_MIN,   AUDIO_CONFIG.DELAY_TAP2_MS_MAX,   energy)
    local fb_tap1   = lerp(AUDIO_CONFIG.DELAY_FEEDBACK_TAP1_MIN, AUDIO_CONFIG.DELAY_FEEDBACK_TAP1_MAX, energy)
    local fb_tap2   = lerp(AUDIO_CONFIG.DELAY_FEEDBACK_TAP2_MIN, AUDIO_CONFIG.DELAY_FEEDBACK_TAP2_MAX, energy)
    local delay1_samples = math.floor(sample_rate * tap1_ms)
    local delay2_samples = math.floor(sample_rate * tap2_ms)

    local data = love.sound.newSoundData(length, sample_rate, 16, 1)
    for i = 0, length - 1 do
        local t = i / sample_rate
        local current_f = freq
        local f = is_kick and (current_f * math.exp(-24 * t)) or current_f
        local val = 0

        if wave_type == "square" then
            val = math.sin(2 * math.pi * f * t) >= 0 and 0.4 or -0.4
        elseif wave_type == "triangle" then
            local sv = math.sin(2 * math.pi * f * t)
            val = (2 / math.pi) * math.asin(math.max(-1, math.min(1, sv)))
        elseif wave_type == "saw" then
            local ft = f * t
            val = 1.4 * (ft - math.floor(ft + 0.5))
            val = val * (1 - math.min(0.7, t * 15))
        else
            val = math.sin(2 * math.pi * f * t)
        end

        if not is_kick and not no_lfo then
            local lfo_rate = 6 + energy * 4
            local lfo = (1.0 - energy * 0.2) + (0.2 + energy * 0.2) * math.sin(2 * math.pi * lfo_rate * t)
            val = val * lfo
        end

        if energy > 0.05 and i >= delay1_samples then
            local prev = data:getSample(i - delay1_samples)
            val = val + prev * fb_tap1
        end

        if energy > 0.35 and i >= delay2_samples then
            local prev = data:getSample(i - delay2_samples)
            val = val + prev * fb_tap2
        end

        if drive > 0 then val = tanh(val * drive) / tanh(drive) end
        data:setSample(i, val * math.exp(-decay * t) * volume)
    end

    local sfx_norm = SettingsManager.getSFX()
    local src = love.audio.newSource(data, "static")
    src:setVolume(src:getVolume() * sfx_norm)
    love.audio.play(src)
end

function AudioManager.playNoise(duration, volume, decay, drive)
    if AudioManager.zone_active then volume = volume * 0.2 end
    if AudioManager.glitch_timer > 0 and math.random() < 0.3 then return end

    local energy = _G.TrackEnergyPunch or 0
    local sample_rate = 44100

    local dur_boost = lerp(AUDIO_CONFIG.SFX_DURATION_BASE_BOOST_MIN, AUDIO_CONFIG.SFX_DURATION_BASE_BOOST_MAX, energy)
    local effective_duration = duration * dur_boost
    local length = math.floor(sample_rate * effective_duration)
    if length <= 0 then return end

    local decay_div = lerp(AUDIO_CONFIG.DECAY_DIVISOR_MIN, AUDIO_CONFIG.DECAY_DIVISOR_MAX, energy)
    decay = (decay or 45) / decay_div

    local drive_boost = lerp(AUDIO_CONFIG.DRIVE_BOOST_MIN, AUDIO_CONFIG.DRIVE_BOOST_MAX, energy) * 0.7
    drive = (drive or 0) + drive_boost

    local tap1_ms   = lerp(AUDIO_CONFIG.DELAY_TAP1_MS_MIN,   AUDIO_CONFIG.DELAY_TAP1_MS_MAX,   energy)
    local fb_tap1   = lerp(AUDIO_CONFIG.DELAY_FEEDBACK_TAP1_MIN, AUDIO_CONFIG.DELAY_FEEDBACK_TAP1_MAX, energy)
    local delay1_samples = math.floor(sample_rate * tap1_ms)

    local data = love.sound.newSoundData(length, sample_rate, 16, 1)
    for i = 0, length - 1 do
        local t = i / sample_rate
        local val = (math.random() * 2 - 1)
        val = val * math.sin(2 * math.pi * (3200 + energy * 800) * t)

        if energy > 0.05 and i >= delay1_samples then
            local prev = data:getSample(i - delay1_samples)
            val = val + prev * fb_tap1
        end

        if drive > 0 then val = tanh(val * drive) / tanh(drive) end
        data:setSample(i, val * math.exp(-decay * t) * volume)
    end

    local sfx_norm = SettingsManager.getSFX()
    local src = love.audio.newSource(data, "static")
    src:setVolume(src:getVolume() * sfx_norm)
    love.audio.play(src)
end

function AudioManager.playArpeggio(notes, wave_type, volume, drive, speed, scale_factor)
    speed = speed or 0.045
    scale_factor = scale_factor or 1
    local energy = _G.TrackEnergyPunch or 0

    local speed_mult = lerp(1.0, 0.72, energy)
    speed = speed * speed_mult

    for i, base_f in ipairs(notes) do
        local note_dur = 0.2 + (i * 0.03) + (energy * 0.35)
        AudioManager.playTone(base_f * scale_factor, note_dur, volume * 0.75, wave_type, false, drive, 18 - i, true)
    end
end

function AudioManager.playHatClosed(volume)
    AudioManager.playNoise(0.032, volume or 0.12, 110)
end

function AudioManager.triggerGlitch(duration)
    AudioManager.glitch_timer = duration or 0
end

function AudioManager.playImmediateSFX(type, is_bot, row_y)
    local notes = is_bot and _G.BOT_NOTES or _G.PLAYER_NOTES
    local vol = is_bot and 0.45 or 0.38
    local energy = _G.TrackEnergyPunch or 0

    if type == "move" then
        local idx = AudioManager.melody_step
        local current_note = notes[idx] or notes[1] or 130.81
        AudioManager.playTone(current_note, 0.06 + energy * 0.02, vol * 0.45, "triangle", false, 0, 65, true)
        AudioManager.melody_step = (AudioManager.melody_step % #notes) + 1

    elseif type == "rotate" then
        local rotate_note = notes[2] or notes[1] or 155.56
        AudioManager.playTone(rotate_note * 2, 0.08 + energy * 0.03, vol * 0.5, "sine", false, 0, 50, true)

    elseif type == "hold" then
        local n1 = notes[1] or 130.81
        local n4 = notes[4] or notes[3] or 233.08
        AudioManager.playTone(n1, 0.07, vol * 0.5, "sine", false, 0, 40, true)
        AudioManager.playTone(n4 * 2, 0.09 + energy * 0.04, vol * 0.45, "sine", false, 1, 30, true)

    elseif type == "drop" then
        local target_row = tonumber(row_y) or 40
        local height_factor = (41 - target_row) / 20
        local root = notes[1] or 130.81
        local third = notes[2] or 164.81
        local fifth = notes[3] or 196.00
        local pitch_mod = 1 + (height_factor * 0.3)
        local drop_vol_boost = 1 + (energy * 0.6)

        AudioManager.playTone(root * pitch_mod, 0.4, vol * 0.35 * drop_vol_boost, "sine", false, 0, 12, true)
        AudioManager.playTone(third * pitch_mod, 0.42, vol * 0.3 * drop_vol_boost, "sine", false, 0, 11, true)
        AudioManager.playTone(fifth * pitch_mod, 0.45, vol * 0.28 * drop_vol_boost, "sine", false, 0, 10, true)
        AudioManager.playNoise(0.28, vol * 0.25 * drop_vol_boost, 24, 0)

    elseif type == "line_clear" then
        local n1 = notes[1] or 130.81
        local n2 = notes[2] or 164.81
        local n3 = notes[3] or 196.00
        AudioManager.playArpeggio({n1, n2, n3}, "sine", vol * 0.85, energy * 2, 0.04, 2)
        AudioManager.playNoise(0.45 + energy * 0.1, vol * 0.45, 15, 1)

    elseif type == "t_spin" then
        local n1 = notes[1] or 130.81
        local n2 = notes[2] or 164.81
        local n3 = notes[3] or 196.00
        local n4 = notes[4] or 233.08
        AudioManager.playArpeggio({n1 * 2, n3 * 2, n4 * 2, n2 * 4}, "triangle", vol * 0.98, 1 + energy * 3, 0.035, 1)
        AudioManager.playNoise(0.55, vol * 0.35, 12, 0)

    elseif type == "phantom_attack" then
        local root = notes[1] or 130.81
        AudioManager.playTone(root * 4.5, 0.45, 0.85, "saw", true, 4, 10, false)
        AudioManager.playTone(root * 2.2, 0.65, 0.75, "triangle", false, 2, 6, false)
        AudioManager.playTone(root * 0.75, 0.8, 0.9, "sine", true, 5, 4, true)
        AudioManager.playNoise(0.4, 0.65, 18, 3)

    elseif type == "zone_enter" then
        local low_note = _G.BG_SCALE and _G.BG_SCALE[1] or 32.70
        AudioManager.playTone(low_note, 1.8, 0.95, "sine", false, 2, 1.2, true)
        AudioManager.playNoise(0.9, vol * 0.45, 6, 0)

    elseif type == "zone_enter_hyper" then
        local low_note = _G.BG_SCALE and _G.BG_SCALE[1] or 32.70
        AudioManager.playTone(low_note * 0.5, 2.2, 1.1, "sine", false, 3, 0.9, true)
        AudioManager.playArpeggio({130.81, 164.81, 196.00, 261.63, 329.63, 523.25}, "triangle", 1.2, 2, 0.025, 1)
        AudioManager.playNoise(1.1, 0.6, 4, 1)

    elseif type == "tetris" then
        local n1 = notes[1] or 130.81
        local n2 = notes[2] or 164.81
        local n3 = notes[3] or 196.00
        local n4 = notes[4] or 233.08
        AudioManager.playArpeggio({n1, n2, n3 * 2, n4 * 2, n1 * 4}, "sine", vol * 1.35, energy * 3, 0.028, 1)
        AudioManager.playNoise(0.9, vol * 0.55, 5, 0)

    elseif type == "ultimatris" or type == "perfect_clear" then
        local root = notes[1] or 130.81
        local third = notes[2] or 164.81
        local fifth = notes[3] or 196.00
        AudioManager.playArpeggio({
            root * 2, third * 2, fifth * 2,
            root * 4, third * 4, fifth * 4, root * 8
        }, "sine", 1.6, 4, 0.032, 1)
        AudioManager.playNoise(1.2, 0.65, 4, 2)

    elseif type == "death" then
        AudioManager.playTone(55.0, 1.6, 1.2, "saw", true, 5, 1.8, true)
        AudioManager.playNoise(1.4, 0.85, 3, 4)
        AudioManager.playTone(32.7, 2.0, 1.0, "sine", false, 6, 1.1, true)
    end
end

function AudioManager.update(dt, stats)
    if AudioManager.glitch_timer > 0 then
        AudioManager.glitch_timer = AudioManager.glitch_timer - dt
    end

    local TrackManager = require "track_manager"
    local MusicManager = require "music_manager"
    local current_track = TrackManager.getCurrentTrack()

    if current_track then
        AudioManager.base_bpm = current_track.bpm
    end

    local song_time = MusicManager.getTime()
    if song_time <= 0.01 then song_time = _G.RealMatchTimer or 0 end

    local bpm = AudioManager.base_bpm or 120
    local bar_duration = (60 / bpm) * 4

    local drop_point = (current_track and current_track.drop_second and current_track.drop_second > 0) and current_track.drop_second or (bar_duration * 32)
    local build_len = (current_track and current_track.build_duration and current_track.build_duration > 0) and current_track.build_duration or (bar_duration * 16)
    local build_start = math.max(0, drop_point - build_len)

    if song_time >= drop_point then
        _G.TrackEnergyPunch = 1.0
    elseif song_time >= build_start then
        local progress = (song_time - build_start) / build_len
        _G.TrackEnergyPunch = progress * progress * progress
    else
        _G.TrackEnergyPunch = 0.0
    end

    local danger = (stats and stats.danger_level) or 0
    local drop_rate_intensity = (stats and stats.drop_intensity) or 0
    local intensity_factor = math.max(danger, drop_rate_intensity)

    AudioManager.current_bpm = AudioManager.base_bpm + (intensity_factor * 26)

    if _G.AudioBeatPulse > 0 then
        local decay_speed = 4.5 + (_G.TrackEnergyPunch * 4.5)
        _G.AudioBeatPulse = _G.AudioBeatPulse - dt * decay_speed
        if _G.AudioBeatPulse < 0 then _G.AudioBeatPulse = 0 end
    end

    if song_time > 0.05 then
        local beat_duration = (60 / AudioManager.current_bpm)
        local current_beat = song_time / beat_duration
        local fraction = current_beat - math.floor(current_beat)
        if fraction < 0.09 and _G.AudioBeatPulse <= 0.1 then
            _G.AudioBeatPulse = 1.0
        end
    end
end

return AudioManager
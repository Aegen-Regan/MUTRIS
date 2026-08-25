-- ================================================================
-- FILE: audio_manager.lua
-- ================================================================
---@diagnostic disable: undefined-global
local AudioManager = {}
local ffi = require("ffi")
local socket = require("socket")
local BlackBox = require("core.blackbox")
local SettingsManager = require "settings_manager"
local EventBus = require "core.event_bus"

-- Declaramos la referencia local para evitar accesos globales lentos o nulos
local math = _G.math or math

AUDIO_CONFIG = {
    SFX_DURATION_BASE_BOOST_MIN = 1.0,
    SFX_DURATION_BASE_BOOST_MAX = 1.5,
    DELAY_TAP1_MS_MIN = 0.020,
    DELAY_TAP1_MS_MAX = 0.050,
    DELAY_FEEDBACK_TAP1_MIN = 0.01,
    DELAY_FEEDBACK_TAP1_MAX = 0.10,
    DRIVE_BOOST_MIN = 0.0,
    DRIVE_BOOST_MAX = 1.2,
    DECAY_DIVISOR_MIN = 1.0,
    DECAY_DIVISOR_MAX = 2.0,
    ZONE_EXTRA_DURATION = 1.10,
    ZONE_EXTRA_DRIVE  = 1.0,
    ZONE_PITCH_SHIFT  = 0.95,
    DANGER_GLITCH_CHANCE = 0.15,
}

-- Parámetros de conexión con el servidor scsynth
AudioManager.sc_host = "127.0.0.1"
AudioManager.sc_port = 57110
AudioManager.udp_socket = nil

AudioManager.bpm = 130
AudioManager.crochet = 60 / 130
AudioManager.song_position_samples = 0
AudioManager.current_beat = 0
AudioManager.beat_pulse_flag = false

-- --- RECTIFICACIÓN MAESTRA DE BYTES CON PADDING OSC ---

-- Búfer para titan_thud (64 bytes fijos)
-- "titan_thud" = 10 bytes -> Agregamos dos ceros para llegar a 12 (múltiplo de 4)
AudioManager._titan_buf = ffi.new("uint8_t[64]", {
    47,115,95,110,101,119,0,0,                      -- "/s_new\0\0"
    44,115,105,105,105,115,115,102,102,0,0,0,       -- ",siiissff\0\0\0"
    116,105,116,97,110,95,116,104,117,100,0,0,      -- "titan_thud\0\0"
    255,255,255,255, 0,0,0,0, 0,0,0,1,               -- Node -1, Action 0, Target 1
    112,97,110,0, 0,0,0,0,                          -- "pan\0" + 4 bytes float (offset 44)
    119,101,105,103,104,116,0,0,                    -- "weight\0\0" + 4 bytes float (offset 56)
    0,0,0,0
})

-- Búfer para glitch_click (64 bytes fijos)
-- "glitch_click" = 12 bytes -> Agregamos cuatro ceros para llegar a 16 (múltiplo de 4)
AudioManager._click_buf = ffi.new("uint8_t[64]", {
    47,115,95,110,101,119,0,0,                      -- "/s_new\0\0"
    44,115,105,105,105,115,102,0,                   -- ",siiissf\0"
    103,108,105,116,99,104,95,99,108,105,99,107,0,0,0,0, -- "glitch_click\0\0\0\0"
    255,255,255,255, 0,0,0,0, 0,0,0,1,               -- Node -1, Action 0, Target 1
    114,97,116,101,0,0,0,0,                         -- "rate\0\0\0\0" + 4 bytes float (offset 48)
    0,0,0,0, 0,0,0,0
})

-- Búfer para debug_ping (64 bytes fijos)
-- "debug_ping" = 10 bytes -> Agregamos dos ceros para llegar a 12 (múltiplo de 4)
AudioManager._debug_buf = ffi.new("uint8_t[64]", {
    47,115,95,110,101,119,0,0,                      -- "/s_new\0\0"
    44,115,105,105,105,115,102,0,                   -- ",siiissf\0"
    100,101,98,117,103,95,112,105,110,103,0,0,      -- "debug_ping\0\0"
    255,255,255,255, 0,0,0,0, 0,0,0,1,               -- Node -1, Action 0, Target 1
    102,114,101,113,0,0,0,0,                        -- "freq\0\0\0\0" + 4 bytes float (offset 48)
    0,0,0,0, 0,0,0,0
})

function AudioManager.init_external_backends()
    -- Open a decoupled, unconnected UDP socket to bypass local Windows API restrictions
    AudioManager.udp_socket = socket.udp()
    if AudioManager.udp_socket then
        -- CRITICAL BYPASS: Do NOT call setpeername. Keep it open and flexible.
        AudioManager.udp_socket:settimeout(0)
    end
    
    if _G.RustArchon and _G.RustArchon.init_audio_bridge then
        _G.RustArchon.init_audio_bridge(AudioManager.bpm)
    end
    
    local BlackBox = package.loaded["core.blackbox"]
    if BlackBox then 
        BlackBox.record(BlackBox.TYPES.SYSTEM, AudioManager.sc_port * 1.0, "UDP_UNCONNECTED_OPEN") 
    end
end

-- Alias nativo requerido por el micro-núcleo de main.lua
function AudioManager.init()
    AudioManager.init_external_backends()
end

function AudioManager.set_track(source_object, track_bpm)
    AudioManager.bpm = track_bpm or 130
    AudioManager.crochet = 60 / AudioManager.bpm
    AudioManager.current_beat = 0
    AudioManager.beat_pulse_flag = false
end

function AudioManager.update_clock()
    local sc_sample_time = 0
    if _G.RustArchon and _G.RustArchon.get_supercollider_samples then
        sc_sample_time = _G.RustArchon.get_supercollider_samples()
    end
    
    local sample_rate = 48000
    local hardware_time = sc_sample_time / sample_rate
    local next_beat = math.floor(hardware_time / AudioManager.crochet)
    
    if next_beat > AudioManager.current_beat then
        AudioManager.current_beat = next_beat
        AudioManager.beat_pulse_flag = true
    else
        AudioManager.beat_pulse_flag = false
    end
end

function AudioManager.is_beat_frame()
    return AudioManager.beat_pulse_flag
end

-- --- ZERO-GC TRANSMISSION EMITTERS UTILIZING EXPLICIT SENDTO ROUTINES ---

function AudioManager.trigger_titan_sism(grid_column, drop_height)
    if not AudioManager.udp_socket then return end
    local target_pan = ((grid_column - 1) / 9) * 2 - 1
    local target_weight = 1.0 + (math.min(drop_height or 0, 20) / 20) * 1.5

    local casted_ptr = ffi.cast("uint8_t*", AudioManager._titan_buf)
    ffi.cast("float*", casted_ptr + 44)[0] = target_pan
    ffi.cast("float*", casted_ptr + 56)[0] = target_weight
    
    -- CRITICAL BYPASS: Direct explicit network dispatch via sendto
    AudioManager.udp_socket:sendto(ffi.string(AudioManager._titan_buf, 64), AudioManager.sc_host, AudioManager.sc_port)
end

function AudioManager.trigger_player_click()
    if not AudioManager.udp_socket then return end
    local current_pps = (pps_counter and pps_counter.get_current_pps) and pps_counter.get_current_pps() or 1.0
    local target_rate = math.min(math.max(current_pps / 2.0, 1.0), 2.5)

    local casted_ptr = ffi.cast("uint8_t*", AudioManager._click_buf)
    ffi.cast("float*", casted_ptr + 48)[0] = target_rate
    
    -- CRITICAL BYPASS: Direct explicit network dispatch via sendto
    AudioManager.udp_socket:sendto(ffi.string(AudioManager._click_buf, 64), AudioManager.sc_host, AudioManager.sc_port)
end

function AudioManager.trigger_debug_ping(target_frequency, target_pan)
    if not AudioManager.udp_socket then return end
    local casted_ptr = ffi.cast("uint8_t*", AudioManager._debug_buf)
    ffi.cast("float*", casted_ptr + 48)[0] = target_frequency or 880.0
    
    -- CRITICAL BYPASS: Direct explicit network dispatch via sendto
    AudioManager.udp_socket:sendto(ffi.string(AudioManager._debug_buf, 64), AudioManager.sc_host, AudioManager.sc_port)
end

function AudioManager.trigger_line_clear_chord(lines_cleared)
    if AudioManager.trigger_debug_ping then
        AudioManager.trigger_debug_ping(660.0, 0.0)
    end
end

-- 📂 Escaneo y Carga de Voces Reales (.mp3 / .ogg / .wav)
function AudioManager.loadVoiceFiles()
    AudioManager.voice_cache = {}
    local files = {"tetris", "tspin", "double", "triple", "b2b", "hyper", "victory", "danger", "ready", "go"}
    local exts = {".mp3", ".ogg", ".wav"}
    
    for _, name in ipairs(files) do
        for _, ext in ipairs(exts) do
            local path = "sfx/announcer/" .. name .. ext
            if love.filesystem.getInfo(path) then
                local success, src = pcall(love.audio.newSource, path, "static")
                if success then
                    AudioManager.voice_cache[name] = src
                    break
                end
            end
        end
    end
end

-- ⚡ Disparo de Ensordecimiento (Ajustado por el porcentaje configurado por el usuario)
function AudioManager.triggerSidechain(amount, duration)
    local sidechain_setting = SettingsManager.get("sidechain_duck") or 1.0
    if sidechain_setting > 1.0 then sidechain_setting = sidechain_setting / 100.0 end
    
    if sidechain_setting <= 0.01 then
        AudioManager.duck_intensity = 0.0
        return
    end

    local safe_amount = amount or 1.0
    local effective_amount = safe_amount * sidechain_setting
    AudioManager.duck_intensity = math.max(AudioManager.duck_intensity or 0.0, effective_amount)
    AudioManager.duck_duration = duration or 0.60
end

-- 🗣️ Reproducción de la Voz del Presentador
function AudioManager.playVoiceAnnounce(voice_type)
    if not AudioManager.voice_cache then return false end

    local sfx_vol = SettingsManager.getSFX()
    if sfx_vol <= 0.01 then return end

    local announcer_mode = SettingsManager.get("announcer_mode") or 1
    if announcer_mode == 0 then return end

    if announcer_mode == 2 then
        local is_critical = (voice_type == "victory" or voice_type == "danger" or voice_type == "hyper" or voice_type == "ultimatris" or voice_type == "perfect_clear")
        if not is_critical then return end
    end
    
    AudioManager.triggerSidechain(1.0, 0.75)

    local key = voice_type:lower()
    local src = AudioManager.voice_cache[key]
    if src then
        src:setVolume(math.min(1.0, sfx_vol * 1.35))
        src:stop()
        src:play()
    else
        AudioManager.playSubBassThud(3)
    end
end

function AudioManager.playMenuClick()
    AudioManager.playTone(380, 0.04, 0.20, "sine", false, 0.0, 70, true)
end

function AudioManager.playMenuHover()
    AudioManager.playTone(240, 0.03, 0.12, "triangle", false, 0.0, 100, true)
end

function AudioManager.playSliderTick()
    AudioManager.playTone(320, 0.02, 0.15, "sine", false, 0.0, 140, true)
end

function AudioManager.playMenuBack()
    local sfx_vol = SettingsManager.getSFX()
    local sample_rate = 44100
    local length = math.floor(sample_rate * 0.12)
    if length <= 0 then return end
    local data = love.sound.newSoundData(length, sample_rate, 16, 1)
    for i = 0, length - 1 do
        local t = i / sample_rate
        local f = 280 - (120 * (t / 0.12))
        local val = math.sin(2 * math.pi * f * t) * math.exp(-25 * t)
        data:setSample(i, val * 0.25 * sfx_vol)
    end
    love.audio.play(love.audio.newSource(data, "static"))
end

function AudioManager.playMuteToggle(is_muted)
    if is_muted then
        AudioManager.playTone(180, 0.10, 0.22, "triangle", false, 0.2, 45, true)
    else
        local sfx_vol = SettingsManager.getSFX()
        local sample_rate = 44100
        local length = math.floor(sample_rate * 0.10)
        if length <= 0 then return end
        local data = love.sound.newSoundData(length, sample_rate, 16, 1)
        for i = 0, length - 1 do
            local t = i / sample_rate
            local f = 200 + (180 * (t / 0.10))
            local val = math.sin(2 * math.pi * f * t) * math.exp(-20 * t)
            data:setSample(i, val * 0.25 * sfx_vol)
        end
        love.audio.play(love.audio.newSource(data, "static"))
    end
end

-- 💥 IMPACTO DE SUBGRAVES ATERRADOR (30 Hz Cinematic Drop)
function AudioManager.playSubBassThud(power)
    local sfx_vol = SettingsManager.getSFX()
    if sfx_vol <= 0.01 then return end

    local tier = SettingsManager.get("subbass_power") or 3
    AudioManager.triggerSidechain(0.85, 0.60)

    local sample_rate = 44100
    local dur = 0.40 + tier * 0.05
    local length = math.floor(sample_rate * dur)
    if length <= 0 then return end

    local data = love.sound.newSoundData(length, sample_rate, 16, 1)
    local start_f = 45 + tier * 8 + (power or 1) * 4
    local end_f = 22

    for i = 0, length - 1 do
        local t = i / sample_rate
        local prog = t / dur
        local f = start_f + (end_f - start_f) * (prog * prog)
        local sub = math.sin(2 * math.pi * f * t)
        local rumble = math.sin(2 * math.pi * (f * 0.5) * t) * (0.3 + tier * 0.1)
        local thud = (t < 0.008) and (math.random() * 2 - 1) * (1.0 - t / 0.008) * 0.4 or 0

        local val = math.tanh((sub + rumble + thud) * (1.8 + tier * 0.4)) * math.exp(-5.0 * t)
        data:setSample(i, val * 0.98 * sfx_vol)
    end

    local src = love.audio.newSource(data, "static")
    src:setVolume(1.0)
    love.audio.play(src)
end

-- 💎 IMPACTO MECÁNICO TÁCTIL
function AudioManager.playMechanicalClear(lines_count, is_bot)
    local sfx_vol = SettingsManager.getSFX()
    if sfx_vol <= 0.01 then return end

    local duck_amount = is_bot and (0.30 + lines_count * 0.05) or (0.60 + lines_count * 0.08)
    AudioManager.triggerSidechain(duck_amount, 0.35)

    local sample_rate = 44100
    local dur = 0.28
    local length = math.floor(sample_rate * dur)
    if length <= 0 then return end

    local data = love.sound.newSoundData(length, sample_rate, 16, 1)
    local base_f = 110 + (lines_count * 20)

    for i = 0, length - 1 do
        local t = i / sample_rate
        local snap = (t < 0.006) and (math.random() * 2 - 1) * (1.0 - t / 0.006) * 0.5 or 0
        local body = math.sin(2 * math.pi * (base_f * math.exp(-15 * t)) * t) * 0.7
        local deep = math.sin(2 * math.pi * 48 * t) * 0.45 * math.exp(-8 * t)

        local val = math.tanh((snap + body + deep) * 2.0) * math.exp(-8.0 * t)
        data:setSample(i, val * 0.85 * sfx_vol)
    end

    local src = love.audio.newSource(data, "static")
    src:setVolume(is_bot and 0.55 or 1.0)
    love.audio.play(src)
end

function AudioManager.playTone(freq, duration, volume, wave_type, is_kick, drive, decay, no_lfo)
    if freq > 400 and not is_kick then freq = 280 end

    local sample_rate = 44100
    local length = math.floor(sample_rate * duration)
    if length <= 0 then return end
    decay = decay or 26

    local data = love.sound.newSoundData(length, sample_rate, 16, 1)
    for i = 0, length - 1 do
        local t = i / sample_rate
        local f = is_kick and (freq * math.exp(-24 * t)) or freq
        local val = math.sin(2 * math.pi * f * t)
        if wave_type == "triangle" then
            val = (2 / math.pi) * math.asin(math.max(-1, math.min(1, val)))
        end
        if drive and drive > 0 then val = math.tanh(val * drive) end
        data:setSample(i, val * math.exp(-decay * t) * volume)
    end

    local sfx_norm = SettingsManager.getSFX()
    local src = love.audio.newSource(data, "static")
    src:setVolume(src:getVolume() * sfx_norm)
    love.audio.play(src)
end

function AudioManager.playHatClosed(volume)
    AudioManager.playTone(180, 0.025, volume or 0.08, "triangle", true, 0, 90, true)
end

function AudioManager.triggerGlitch(duration)
    AudioManager.glitch_timer = duration or 0
end

function AudioManager.playImmediateSFX(type, is_bot, row_y)
    local vol = is_bot and 0.35 or 0.30

    if type == "move" then
        AudioManager.playTone(140, 0.035, vol * 0.30, "sine", false, 0, 95, true)

    elseif type == "rotate" then
        AudioManager.playTone(180, 0.045, vol * 0.35, "sine", false, 0, 80, true)

    elseif type == "hold" then
        AudioManager.playTone(120, 0.05, vol * 0.38, "sine", false, 0, 60, true)
        AudioManager.playTone(160, 0.06, vol * 0.32, "sine", false, 0, 50, true)

    elseif type == "drop" then
        local target_row = tonumber(row_y) or 40
        local height_factor = (41 - target_row) / 20
        local f = 90 + height_factor * 15
        AudioManager.playTone(f, 0.22, vol * 0.32, "sine", true, 0.4, 24, true)

    elseif type == "line_clear" then
        AudioManager.playMechanicalClear(1, is_bot)

    elseif type == "t_spin" then
        AudioManager.playSubBassThud(3)
        AudioManager.playVoiceAnnounce("tspin")

    elseif type == "phantom_attack" then
        AudioManager.playTone(65, 0.35, 0.65, "sine", true, 1.2, 14, true)

    elseif type == "zone_enter" then
        AudioManager.playTone(40, 1.4, 0.85, "sine", true, 1.0, 1.8, true)

    elseif type == "zone_enter_hyper" then
        AudioManager.playSubBassThud(4)
        AudioManager.playVoiceAnnounce("hyper")

    elseif type == "tetris" then
        AudioManager.playSubBassThud(3)
        AudioManager.playVoiceAnnounce("tetris")

    elseif type == "ultimatris" or type == "perfect_clear" then
        AudioManager.playSubBassThud(5)
        AudioManager.playVoiceAnnounce("victory")

    elseif type == "death" then
        AudioManager.triggerSidechain(1.0, 1.2)
        AudioManager.playTone(36.0, 1.6, 1.0, "sine", true, 3, 2.0, true)
    end
end

function AudioManager.update(dt, stats)
    if AudioManager.glitch_timer > 0 then
        AudioManager.glitch_timer = AudioManager.glitch_timer - dt
    end

    if (AudioManager.duck_intensity or 0.0) > 0 then
        local safe_duration = AudioManager.duck_duration or 0.60
        local decay_rate = 1.0 / math.max(0.1, safe_duration)
        AudioManager.duck_intensity = math.max(0.0, (AudioManager.duck_intensity or 0.0) - dt * decay_rate)
    end

    local TrackManager = require "track_manager"
    local MusicManager = require "music_manager"
    local current_track = TrackManager.getCurrentTrack()

    if current_track then AudioManager.base_bpm = current_track.bpm end

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
            
            -- 🪝 HOOK ZERO-GC: Disparo del beat a plugins y subsistemas
            EventBus.emit(EventBus.ON_BEAT, math.floor(current_beat), AudioManager.current_bpm)

            local beat_click = SettingsManager.get("beat_click") or 0
            if beat_click == 2 or (beat_click == 1 and danger > 0.45) then
                AudioManager.playHatClosed(0.12)
            end
        end
    end
end

return AudioManager
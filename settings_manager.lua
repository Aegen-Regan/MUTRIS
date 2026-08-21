-- ================================================================
-- FILE: settings_manager.lua
-- ================================================================
---@diagnostic disable: undefined-global
local SettingsManager = {}

-- ⚙️ VALORES POR DEFECTO DE FÁBRICA (BASELINE PERMANENTE)
SettingsManager.defaults = {
    -- 🕹️ HANDLING
    das               = 0.094,   -- 94 ms
    arr               = 0.008,   -- 8 ms
    sdf               = 40.0,    -- 40x Caída suave
    dcd               = 0.0,     -- 0 ms DAS Cut Delay
    lock_delay        = 0.50,    -- 0.50 s
    max_resets        = 15,      -- 15 movimientos
    srs_180           = 1,       -- 1 = Activo, 0 = Inactivo

    -- 🎚️ AUDIO / DAW
    master_vol        = 1.0,     -- 100%
    bgm_vol           = 0.85,    -- 85%
    sfx_vol           = 1.0,     -- 100%
    sidechain_duck    = 1.0,     -- 100% (Vacío total en impactos)
    subbass_power     = 3,       -- 1=Suave, 2=Medio, 3=Pesado, 4=Sísmico
    announcer_mode    = 1,       -- 1=Todas las voces, 2=Solo Críticos, 0=Apagado
    beat_click        = 0,       -- 0=Off, 1=Peligro, 2=Siempre
    mute_all          = 0,       -- 0=Normal, 1=Muted

    -- 🥊 COMBATE
    parry_window      = 3,       -- 3 frames (~50ms)
    beat_window       = 0.035,   -- ±35 ms Groove
    groove_bonus      = 1,       -- +1 línea
    counter_ratio     = 0.50,    -- 50% devuelto
    zone_trigger_mode = 1,       -- 1=Flexible (25%), 2=Hyper Only (100%)

    -- 👁️ VIDEO / FX
    bloom_intensity   = 1.0,     -- 100%
    screen_shake      = 1.0,     -- 100%
    ghost_alpha       = 0.35,    -- 35%
    glitch_mode       = 1,       -- 1=Dinámico por Energía, 0=Off
    fog_mode          = 1,       -- 1=Reactivo Camelot, 0=Off
    shockwaves        = 1,       -- 1=Activo, 0=Inactivo

    -- 🧠 ARCHON / IA
    archon_mode       = 1,       -- 1=Adaptativo DDA, 2=Fijo, 3=Hardcore
    bot_target_pps    = 1.45,    -- 1.45 PPS base
    anomaly_freq      = 25,      -- 25s

    -- 🎥 PIPELINE
    capture_mode      = "mp4",   -- "mp4" o "gif"
    gif_resolution    = 1,       -- 1=480x270 (Ligero), 2=640x360 (HQ)
    auto_save_replay  = 1        -- 1=On, 0=Off
}

-- Tabla de configuración viva del usuario
SettingsManager.settings = {}
for k, v in pairs(SettingsManager.defaults) do
    SettingsManager.settings[k] = v
end

-- 📑 ESQUEMA DE PESTAÑAS Y PARÁMETROS PARA LA INTERFAZ
SettingsManager.tabs = {
    {
        id = "handling",
        name = "🕹️ HANDLING",
        title = "COMPETITIVE DAS / ARR & FRAME-DATA",
        items = {
            { id = "das",        label = "DAS (DELAYED AUTO-SHIFT)", min = 50,  max = 200, step = 1,   unit = "ms", is_ms = true },
            { id = "arr",        label = "ARR (AUTO-REPEAT RATE)",  min = 0,   max = 25,  step = 0.5, unit = "ms", is_ms = true },
            { id = "sdf",        label = "SDF (SOFT DROP MULT)",    min = 5,   max = 40,  step = 5,   unit = "x" },
            { id = "dcd",        label = "DCD (DAS CUT DELAY)",     min = 0,   max = 40,  step = 2,   unit = "ms", is_ms = true },
            { id = "lock_delay", label = "LOCK DELAY BASE",         min = 0.1, max = 1.0, step = 0.05,unit = "s" },
            { id = "max_resets", label = "LOCK MOVE RESETS",        min = 4,   max = 30,  step = 1,   unit = "moves" },
            { id = "srs_180",    label = "SRS 180° WALL-KICKS",     is_toggle = true }
        }
    },
    {
        id = "audio",
        name = "🎚️ AUDIO & DAW",
        title = "SYNTHESIZER, MIXER & HARMONICS",
        items = {
            { id = "master_vol",     label = "MASTER VOLUME",          min = 0, max = 100, step = 5, unit = "%", is_pct = true },
            { id = "bgm_vol",        label = "MUSIC VOLUME (BGM)",     min = 0, max = 100, step = 5, unit = "%", is_pct = true },
            { id = "sfx_vol",        label = "SOUND FX VOLUME (SFX)",  min = 0, max = 100, step = 5, unit = "%", is_pct = true },
            { id = "sidechain_duck", label = "SIDECHAIN DUCKING (MUTE)",min = 0, max = 100, step = 10,unit = "%", is_pct = true },
            { id = "subbass_power",  label = "SUB-BASS 30Hz POWER",    min = 1, max = 4,   step = 1, unit = "tier" },
            { id = "beat_click",     label = "METRONOME BEAT CLICK",   min = 0, max = 2,   step = 1, unit = "mode" },
            { id = "mute_all",       label = "MUTE ALL AUDIO",         is_toggle = true }
        }
    },
    {
        id = "combat",
        name = "🥊 COMBATE",
        title = "STANCES, PARRY & SOULSBORNE GAUGES",
        items = {
            { id = "parry_window",      label = "KINETIC PARRY WINDOW", min = 1,     max = 6,     step = 1,     unit = "frames" },
            { id = "beat_window",       label = "BEAT-LOCK WINDOW",     min = 0.020, max = 0.060, step = 0.005, unit = "s", is_ms = true },
            { id = "groove_bonus",      label = "GROOVE STRIKE BONUS",  min = 1,     max = 3,     step = 1,     unit = "lines" },
            { id = "counter_ratio",     label = "COUNTER-SPIKE RATIO",  min = 0.25,  max = 0.75,  step = 0.05,  unit = "%", is_pct = true },
            { id = "zone_trigger_mode", label = "ZONE TRIGGER MODE",    min = 1,     max = 2,     step = 1,     unit = "mode" }
        }
    },
    {
        id = "video",
        name = "👁️ VIDEO & FX",
        title = "NEON BLOOM, SHADERS & JUICE",
        items = {
            { id = "bloom_intensity", label = "NEON BLOOM GLOW",    min = 0,    max = 200, step = 10,  unit = "%", is_pct = true },
            { id = "screen_shake",    label = "SCREEN SHAKE POWER",  min = 0,    max = 150, step = 10,  unit = "%", is_pct = true },
            { id = "ghost_alpha",     label = "GHOST PIECE VISIBILITY",min = 10, max = 100, step = 5,   unit = "%", is_pct = true },
            { id = "glitch_mode",     label = "CHROMATIC ABERRATION",is_toggle = true },
            { id = "fog_mode",        label = "VOLUMETRIC FOG LAYER",is_toggle = true },
            { id = "shockwaves",      label = "SHOCKWAVE DISTORTION",is_toggle = true }
        }
    },
    {
        id = "archon",
        name = "🧠 ARCHON IA",
        title = "AUTO-BALANCING & DDA ADAPTIVITY",
        items = {
            { id = "archon_mode",    label = "ARCHON DDA MODE",      min = 1,   max = 3,   step = 1,   unit = "mode" },
            { id = "bot_target_pps", label = "BOT TARGET BASE PPS",  min = 0.8, max = 4.0, step = 0.05,unit = "pps" },
            { id = "anomaly_freq",   label = "ANOMALY COOLDOWN TIME",min = 8,   max = 45,  step = 1,   unit = "s" }
        }
    },
    {
        id = "pipeline",
        name = "🎥 PIPELINE",
        title = "ESPORTS CAPTURE & REPLAYS",
        items = {
            { id = "capture_mode",     label = "F9 RECORDING FORMAT",  is_enum = true, options = {"mp4", "gif"}, labels = {"MP4 VIDEO 60FPS", "ANIMATED GIF (LIGHT)"} },
            { id = "gif_resolution",   label = "GIF RESOLUTION PRESET",is_enum = true, options = {1, 2}, labels = {"480x270 @ 20FPS", "640x360 @ 30FPS"} },
            { id = "auto_save_replay", label = "AUTO-SAVE .MUTRISREC", is_toggle = true }
        }
    }
}

local function clamp01(v) return math.max(0, math.min(1, v)) end

local function serializeJSON(t)
    local s = "{\n"
    for k, v in pairs(t) do
        if type(v) == "number" then
            s = s .. string.format('  "%s": %.4f,\n', k, v)
        elseif type(v) == "string" then
            s = s .. string.format('  "%s": "%s",\n', k, v)
        end
    end
    s = s:sub(1, -3) .. "\n}"
    return s
end

local function parseSimpleJSON(str)
    local t = {}
    for k, v in str:gmatch('"([%w_]+)":%s*([%-%d%.]+)') do
        t[k] = tonumber(v)
    end
    for k, v in str:gmatch('"([%w_]+)":%s*"([^"]+)"') do
        t[k] = v
    end
    return t
end

function SettingsManager.init()
    if love.filesystem.getInfo("settings.json") then
        local contents = love.filesystem.read("settings.json")
        if contents then
            local data = parseSimpleJSON(contents)
            for k, v in pairs(data) do
                if SettingsManager.defaults[k] ~= nil then
                    SettingsManager.settings[k] = v
                end
            end
        end
    else
        SettingsManager.save()
    end
end

function SettingsManager.save()
    love.filesystem.write("settings.json", serializeJSON(SettingsManager.settings))
end

-- ⟲ RESET INDIVIDUAL DE 1 VARIABLE
function SettingsManager.resetKey(key)
    if SettingsManager.defaults[key] ~= nil then
        SettingsManager.settings[key] = SettingsManager.defaults[key]
        SettingsManager.save()
    end
end

-- ⟲ RESET COMPLETO DE UNA PESTAÑA
function SettingsManager.resetTab(tab_index)
    local tab = SettingsManager.tabs[tab_index]
    if tab and tab.items then
        for _, item in ipairs(tab.items) do
            if SettingsManager.defaults[item.id] ~= nil then
                SettingsManager.settings[item.id] = SettingsManager.defaults[item.id]
            end
        end
        SettingsManager.save()
    end
end

function SettingsManager.get(key)
    return SettingsManager.settings[key] or SettingsManager.defaults[key]
end

function SettingsManager.getSFX()
    local s = SettingsManager.settings
    if s.mute_all and s.mute_all >= 0.5 then return 0 end
    return clamp01(s.sfx_vol or 1.0) * clamp01(s.master_vol or 1.0)
end

function SettingsManager.getBGM()
    local s = SettingsManager.settings
    if s.mute_all and s.mute_all >= 0.5 then return 0 end
    return clamp01(s.bgm_vol or 1.0) * clamp01(s.master_vol or 1.0)
end

function SettingsManager.getMaster()
    local s = SettingsManager.settings
    if s.mute_all and s.mute_all >= 0.5 then return 0 end
    return clamp01(s.master_vol or 1.0)
end

function SettingsManager.toggleMute()
    local s = SettingsManager.settings
    s.mute_all = (s.mute_all and s.mute_all >= 0.5) and 0 or 1
    SettingsManager.save()
end

return SettingsManager
-- ================================================================
-- FILE: settings_manager.lua
-- ================================================================
---@diagnostic disable: undefined-global
local SettingsManager = {
    filepath = "settings.json",
    tmp_filepath = "settings.json.tmp"
}

SettingsManager.defaults = {
    -- RULESET MAESTRO (FASE 21)
    active_ruleset    = 1,       -- 1=Guideline Modern, 2=TGM 20G Shirase, 3=NES 1989, 4=Pentomino 18

    -- HANDLING
    das               = 0.094,   -- 94 ms
    arr               = 0.008,   -- 8 ms
    sdf               = 40.0,    -- 40x Caída suave
    dcd               = 0.0,     -- 0 ms DAS Cut Delay
    lock_delay        = 0.50,    -- 0.50 s
    max_resets        = 15,      -- 15 movimientos
    srs_180           = 1,       -- 1 = Activo, 0 = Inactivo

    -- MAPEO DE CONTROLES PERSONALIZADOS
    control_preset    = 1,       -- 1=Standard (A/D/S/C + Arrows), 2=Guideline Classic (Z/X/A/C), 3=WASD
    key_left          = "left",
    key_right         = "right",
    key_soft_drop     = "down",
    key_hard_drop     = "space",
    key_rot_cw        = "d",     -- Rotación Horaria (D / X / UP)
    key_rot_ccw       = "a",     -- Rotación Antihoraria (A / Z)
    key_rot_180       = "s",     -- Rotación 180 (S / F)
    key_hold          = "c",     -- Hold / Reserva (C / Shift)
    key_zone          = "v",     -- Zone Mode / Recital
    key_stance        = "tab",   -- Stance Switch

    -- AUDIO / DAW
    master_vol        = 1.0,     -- 100%
    bgm_vol           = 0.85,    -- 85%
    sfx_vol           = 1.0,     -- 100%
    sidechain_duck    = 1.0,     -- 100%
    subbass_power     = 3,       -- 1=Soft, 2=Mid, 3=Heavy, 4=Seismic
    announcer_mode    = 1,       -- 1=All Voices, 2=Critical Only, 0=Off
    beat_click        = 0,       -- 0=Off, 1=Danger Only, 2=Always On
    mute_all          = 0,       -- 0=Normal, 1=Muted

    -- COMBATE
    parry_window      = 3,       -- 3 frames (~50ms)
    beat_window       = 0.035,   -- ±35 ms Groove
    groove_bonus      = 1,       -- +1 línea
    counter_ratio     = 0.50,    -- 50% devuelto
    zone_trigger_mode = 1,       -- 1=Flexible (25%+), 2=Hyper Only (100%)

    -- VIDEO / FX & SKINS
    theme_skin        = 4,       -- 1=Cyber-DAW, 2=Neo-Kinetic, 3=Esports, 4=Cosmic
    bloom_intensity   = 1.0,     -- 100%
    screen_shake      = 1.0,     -- 100%
    ghost_alpha       = 0.35,    -- 35%
    glitch_mode       = 1,       -- 1=Dinámico por Energía, 0=Off
    fog_mode          = 1,       -- 1=Reactivo Camelot, 0=Off
    shockwaves        = 1,       -- 1=Activo, 0=Inactivo

    -- ARCHON IA
    archon_mode       = 1,       -- 1=Adaptive DDA, 2=Locked, 3=Apex Hardcore
    bot_target_pps    = 1.45,    -- 1.45 PPS base
    anomaly_freq      = 25,      -- 25s

    -- PIPELINE
    capture_mode      = "mp4",   -- "mp4" o "gif"
    gif_resolution    = 1,       -- 1=480x270, 2=640x360
    auto_save_replay  = 1        -- 1=On, 0=Off
}

-- Cargar configuración maestra personalizada (default_keybinds.lua) si existe
local custom_binds_ok, custom_binds = pcall(require, "default_keybinds")
if custom_binds_ok and type(custom_binds) == "table" then
    for k, v in pairs(custom_binds) do
        SettingsManager.defaults[k] = v
    end
end

SettingsManager.settings = {}
for k, v in pairs(SettingsManager.defaults) do
    SettingsManager.settings[k] = v
end

SettingsManager.tabs = {
    {
        id = "rules",
        name = "01 // RULESET",
        title = "UNIVERSAL MULTI-RULESET ENGINE & ROTATION PHYSICS",
        items = {
            { id = "active_ruleset", label = "ACTIVE RULESET ENGINE", is_enum = true, options = {1, 2, 3, 4}, labels = {"01 // GUIDELINE MODERN", "02 // TGM 20G SHIRASE", "03 // NES 1989 RETRO", "04 // PENTOMINO 18"} },
            { id = "srs_180",        label = "SRS 180 DEGREE ROTATION KICKS", is_toggle = true },
            { id = "max_resets",     label = "LOCK MOVE RESETS (MAX STALL)", min = 0, max = 30, step = 1, unit = "moves", is_int = true }
        }
    },
    {
        id = "handling",
        name = "02 // HANDLING",
        title = "COMPETITIVE DAS / ARR & FRAME-DATA TIMINGS",
        items = {
            { id = "das",        label = "DAS (DELAYED AUTO-SHIFT)", min = 50,  max = 200, step = 1,   unit = "ms", is_ms = true, is_int = true },
            { id = "arr",        label = "ARR (AUTO-REPEAT RATE)",  min = 0,   max = 25,  step = 0.5, unit = "ms", is_ms = true },
            { id = "sdf",        label = "SDF (SOFT DROP MULT)",    min = 5,   max = 40,  step = 5,   unit = "x",  is_int = true },
            { id = "dcd",        label = "DCD (DAS CUT DELAY)",     min = 0,   max = 40,  step = 2,   unit = "ms", is_ms = true, is_int = true },
            { id = "lock_delay", label = "LOCK DELAY BASE",         min = 0.05, max = 1.0, step = 0.05,unit = "s" }
        }
    },
    {
        id = "controls",
        name = "03 // CONTROLS",
        title = "KEYBOARD & GAMEPAD INPUT MAPPING CALIBRATION",
        items = {
            { id = "control_preset", label = "CONTROL SCHEME PRESET", is_enum = true, options = {1, 2, 3}, labels = {"01 // ARROWS + A/D/S/C", "02 // GUIDELINE (Z/X/A/C)", "03 // WASD + NUMPAD"} },
            { id = "key_left",       label = "MOVE LEFT (IZQUIERDA)",    is_key = true },
            { id = "key_right",      label = "MOVE RIGHT (DERECHA)",     is_key = true },
            { id = "key_soft_drop",  label = "SOFT DROP (ABAJO)",        is_key = true },
            { id = "key_hard_drop",  label = "HARD DROP (CAIDA INSTANT)",is_key = true },
            { id = "key_rot_ccw",    label = "ROTATE CCW (ANTIHORARIO)", is_key = true },
            { id = "key_rot_cw",     label = "ROTATE CW (HORARIO)",      is_key = true },
            { id = "key_rot_180",    label = "ROTATE 180 (180 GRADOS)",  is_key = true },
            { id = "key_hold",       label = "HOLD / RESERVA",           is_key = true },
            { id = "key_zone",       label = "ZONE MODE / RECITAL",      is_key = true },
            { id = "key_stance",     label = "STANCE SWITCH / POSTURA",  is_key = true }
        }
    },
    {
        id = "audio",
        name = "04 // AUDIO",
        title = "PROCEDURAL SYNTHESIZER, MIXER & HARMONICS",
        items = {
            { id = "master_vol",     label = "MASTER VOLUME",          min = 0, max = 100, step = 5, unit = "%", is_pct = true, is_int = true },
            { id = "bgm_vol",        label = "MUSIC VOLUME (BGM)",     min = 0, max = 100, step = 5, unit = "%", is_pct = true, is_int = true },
            { id = "sfx_vol",        label = "SOUND FX VOLUME (SFX)",  min = 0, max = 100, step = 5, unit = "%", is_pct = true, is_int = true },
            { id = "sidechain_duck", label = "SIDECHAIN DUCKING (MUTE)",min = 0, max = 100, step = 10,unit = "%", is_pct = true, is_int = true },
            { id = "subbass_power",  label = "SUB-BASS 30Hz POWER",    is_enum = true, options = {1, 2, 3, 4}, labels = {"TIER 1 (LIGHT)", "TIER 2 (MID)", "TIER 3 (HEAVY)", "TIER 4 (SEISMIC)"} },
            { id = "beat_click",     label = "METRONOME BEAT CLICK",   is_enum = true, options = {0, 1, 2}, labels = {"DISABLED", "DANGER ONLY", "ALWAYS ON"} },
            { id = "mute_all",       label = "MUTE ALL AUDIO",         is_toggle = true }
        }
    },
    {
        id = "combat",
        name = "05 // COMBAT",
        title = "STANCES, KINETIC PARRY & ATTACK GAUGES",
        items = {
            { id = "parry_window",      label = "KINETIC PARRY WINDOW", min = 1,     max = 6,     step = 1,     unit = "frames", is_int = true },
            { id = "beat_window",       label = "BEAT-LOCK GROOVE WINDOW",min = 0.020, max = 0.060, step = 0.005, unit = "ms", is_ms = true, is_int = true },
            { id = "groove_bonus",      label = "GROOVE STRIKE BONUS",  min = 1,     max = 3,     step = 1,     unit = "lines",  is_int = true },
            { id = "counter_ratio",     label = "COUNTER-SPIKE RATIO",  min = 0.25,  max = 0.75,  step = 0.05,  unit = "%", is_pct = true, is_int = true },
            { id = "zone_trigger_mode", label = "ZONE TRIGGER MODE",    is_enum = true, options = {1, 2}, labels = {"FLEXIBLE (25%+)", "HYPER ONLY (100%)"} }
        }
    },
    {
        id = "video",
        name = "06 // VIDEO",
        title = "THEME ENGINES, NEON BLOOM & GLSL SHADERS",
        items = {
            { id = "theme_skin",      label = "ACTIVE THEME SKIN [F5]", is_enum = true, options = {1, 2, 3, 4}, labels = {"01 // CYBER-DAW RACK", "02 // NEO-KINETIC STRIKE", "03 // ESPORTS GLASS", "04 // COSMIC SINESTESIA"} },
            { id = "bloom_intensity", label = "NEON BLOOM GLOW",    min = 0,    max = 200, step = 10,  unit = "%", is_pct = true, is_int = true },
            { id = "screen_shake",    label = "SCREEN SHAKE POWER",  min = 0,    max = 150, step = 10,  unit = "%", is_pct = true, is_int = true },
            { id = "ghost_alpha",     label = "GHOST PIECE OPACITY", min = 10,   max = 100, step = 5,   unit = "%", is_pct = true, is_int = true },
            { id = "glitch_mode",     label = "CHROMATIC ABERRATION",is_toggle = true },
            { id = "fog_mode",        label = "CAMELOT MODAL FOG",   is_toggle = true },
            { id = "shockwaves",      label = "GLSL SHOCKWAVES",     is_toggle = true }
        }
    },
    {
        id = "archon",
        name = "07 // ARCHON",
        title = "AUTO-BALANCING & DDA ADAPTIVE ENGINE",
        items = {
            { id = "archon_mode",    label = "ARCHON DDA ENGINE",    is_enum = true, options = {1, 2, 3}, labels = {"ADAPTIVE DDA", "LOCKED BASELINE", "APEX HARDCORE"} },
            { id = "bot_target_pps", label = "BOT TARGET BASE PPS",  min = 0.8, max = 4.0, step = 0.05,unit = "pps" },
            { id = "anomaly_freq",   label = "ANOMALY COOLDOWN TIME",min = 8,   max = 45,  step = 1,   unit = "s", is_int = true }
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
            
            -- [BUGFIX] Limpiar mapeos corruptos de la versión anterior
            -- Si la rotación 180 está en D, y están en el preset 1, se rompió.
            if SettingsManager.settings.key_rot_180 == "d" then
                SettingsManager.settings.key_rot_180 = "s"
                SettingsManager.settings.key_rot_cw = "d"
                SettingsManager.settings.key_rot_ccw = "a"
                SettingsManager.save()
            end
        end
    else
        SettingsManager.save()
    end
end

function SettingsManager.save(current_settings_table)
    current_settings_table = current_settings_table or SettingsManager.settings
    local lf = love.filesystem
    if not lf then return false end
    
    local BlackBox = package.loaded["core.blackbox"]
    
    local success, json_string = pcall(serializeJSON, current_settings_table)
    if not success or type(json_string) ~= "string" then
        if BlackBox then BlackBox.record(BlackBox.TYPES.ERROR, 0.0, "JSON_ENCODE_FAIL") end
        return false
    end
    
    local write_success = lf.write(SettingsManager.tmp_filepath, json_string)
    if not write_success then
        if BlackBox then BlackBox.record(BlackBox.TYPES.ERROR, 0.0, "TMP_WRITE_FAIL") end
        return false
    end
    
    if lf.getInfo(SettingsManager.filepath) then
        lf.remove(SettingsManager.filepath)
    end
    
    local final_success = lf.write(SettingsManager.filepath, json_string)
    lf.remove(SettingsManager.tmp_filepath)
    
    if final_success then
        if BlackBox then BlackBox.record(BlackBox.TYPES.SYSTEM, 1.0, "SETTINGS_SAVED_OK") end
    else
        if BlackBox then BlackBox.record(BlackBox.TYPES.ERROR, 0.0, "FINAL_SETTINGS_FAIL") end
    end
    
    return final_success
end

function SettingsManager.resetKey(key)
    if SettingsManager.defaults[key] ~= nil then
        SettingsManager.settings[key] = SettingsManager.defaults[key]
        SettingsManager.save()
    end
end

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
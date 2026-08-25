-- ============================================================================
-- FILE: audio/soundtrack_db.lua
-- MUTRIS ENGINE: GLOBAL TRACKS & STORY STAGE DATABASE (Zero-GC)
-- ============================================================================
---@diagnostic disable: undefined-global

local SoundtrackDB = {}
local CONFIG_FILE = "soundtrack_config.json"

-- 24 CAMELOT KEYS DEFINITION
SoundtrackDB.CAMELOT_KEYS = {
    -- Minor Keys (A)
    { id = "1A",  name = "1A (G#m)",  root_freq = 207.65, midi = 56, scale = "minor" },
    { id = "2A",  name = "2A (D#m)",  root_freq = 155.56, midi = 51, scale = "minor" },
    { id = "3A",  name = "3A (A#m)",  root_freq = 233.08, midi = 58, scale = "minor" },
    { id = "4A",  name = "4A (Fm)",   root_freq = 174.61, midi = 53, scale = "minor" },
    { id = "5A",  name = "5A (Cm)",   root_freq = 130.81, midi = 48, scale = "minor" },
    { id = "6A",  name = "6A (Gm)",   root_freq = 196.00, midi = 55, scale = "minor" },
    { id = "7A",  name = "7A (Dm)",   root_freq = 146.83, midi = 50, scale = "minor" },
    { id = "8A",  name = "8A (Am)",   root_freq = 220.00, midi = 57, scale = "minor" },
    { id = "9A",  name = "9A (Em)",   root_freq = 164.81, midi = 52, scale = "minor" },
    { id = "10A", name = "10A (Bm)",  root_freq = 246.94, midi = 59, scale = "minor" },
    { id = "11A", name = "11A (F#m)", root_freq = 185.00, midi = 54, scale = "minor" },
    { id = "12A", name = "12A (C#m)", root_freq = 138.59, midi = 49, scale = "minor" },
    -- Major Keys (B)
    { id = "1B",  name = "1B (B)",    root_freq = 246.94, midi = 59, scale = "major" },
    { id = "2B",  name = "2B (F#)",   root_freq = 185.00, midi = 54, scale = "major" },
    { id = "3B",  name = "3B (Db)",   root_freq = 138.59, midi = 49, scale = "major" },
    { id = "4B",  name = "4B (Ab)",   root_freq = 207.65, midi = 56, scale = "major" },
    { id = "5B",  name = "5B (Eb)",   root_freq = 155.56, midi = 51, scale = "major" },
    { id = "6B",  name = "6B (Bb)",   root_freq = 233.08, midi = 58, scale = "major" },
    { id = "7B",  name = "7B (F)",    root_freq = 174.61, midi = 53, scale = "major" },
    { id = "8B",  name = "8B (C)",    root_freq = 130.81, midi = 48, scale = "major" },
    { id = "9B",  name = "9B (G)",    root_freq = 196.00, midi = 55, scale = "major" },
    { id = "10B", name = "10B (D)",   root_freq = 146.83, midi = 50, scale = "major" },
    { id = "11B", name = "11B (A)",   root_freq = 220.00, midi = 57, scale = "major" },
    { id = "12B", name = "12B (E)",   root_freq = 164.81, midi = 52, scale = "major" },
}

-- SCALE MODES
SoundtrackDB.SCALE_MODES = {
    { id = "pentatonic_minor", name = "Minor Pentatonic", intervals = {0, 3, 5, 7, 10, 12, 15, 17, 19, 22} },
    { id = "pentatonic_major", name = "Major Pentatonic", intervals = {0, 2, 4, 7, 9,  12, 14, 16, 19, 21} },
    { id = "dorian_cyberpunk", name = "Dorian Cyberpunk", intervals = {0, 2, 3, 5, 7,   9, 10, 12, 14, 15} },
    { id = "hirajoshi_japan",  name = "Hirajoshi Arcade", intervals = {0, 2, 3, 7, 8,  12, 14, 15, 19, 20} },
    { id = "blues_synth",      name = "Blues Synthwave",  intervals = {0, 3, 5, 6, 7,  10, 12, 15, 17, 18} },
}

-- GLOBAL TRACKS REGISTRY
SoundtrackDB.tracks = {
    { id = "base_fondo",                name = "Base Fondo (F# Minor)",              file = "music/base_fondo.mp3",                camelot_index = 11, scale_mode_index = 1, octave_offset = 0 },
    { id = "eliveta_uplifting_trance",  name = "Eliveta Uplifting Trance (B Minor)", file = "music/eliveta_uplifting_trance.mp3",  camelot_index = 10, scale_mode_index = 1, octave_offset = 0 },
    { id = "alex_morgan_trance_euphoria", name = "Alex Morgan Trance Euphoria (Eb Major)", file = "music/alex_morgan_trance_euphoria.mp3", camelot_index = 17, scale_mode_index = 2, octave_offset = 0 },
}

-- STORY MODE STAGES (50 stages, procedurally pre-allocated)
SoundtrackDB.stages = {}
for s = 1, 50 do
    local def_t = (s % 3 == 1) and 1 or ((s % 3 == 2) and 2 or 3)
    local def_k = (def_t == 1) and 11 or ((def_t == 2) and 10 or 17)
    local def_m = (s % 5 == 0) and 3 or ((s % 4 == 0) and 4 or 1)
    local def_o = (s % 10 == 0) and -1 or 0
    local name_sfx = (s == 50) and "T.U.N.E.R. Core" or ((s % 10 == 0) and "Colossus Node" or "Data Mainframe")
    SoundtrackDB.stages[s] = {
        stage_num        = s,
        name             = string.format("Stage %02d // %s", s, name_sfx),
        track_index      = def_t,
        camelot_index    = def_k,
        scale_mode_index = def_m,
        octave_offset    = def_o,
    }
end

-- ============================================================================
-- PERSISTENCE (Lightweight custom JSON parser — no external lib required)
-- ============================================================================
function SoundtrackDB.load()
    if not love.filesystem.getInfo(CONFIG_FILE) then return end
    local content = love.filesystem.read(CONFIG_FILE)
    if not content then return end

    -- Load global track overrides
    for _, t in ipairs(SoundtrackDB.tracks) do
        local cam  = content:match('"' .. t.id .. '":%s*{[^}]*"camelot":%s*(%d+)')
        local mode = content:match('"' .. t.id .. '":%s*{[^}]*"mode":%s*(%d+)')
        local oct  = content:match('"' .. t.id .. '":%s*{[^}]*"oct":%s*([%-]?%d+)')
        if cam  then t.camelot_index    = tonumber(cam)  end
        if mode then t.scale_mode_index = tonumber(mode) end
        if oct  then t.octave_offset    = tonumber(oct)  end
    end

    -- Load stage overrides
    for _, stg in ipairs(SoundtrackDB.stages) do
        local skey  = string.format("stage_%02d", stg.stage_num)
        local s_trk = content:match('"' .. skey .. '":%s*{[^}]*"track":%s*(%d+)')
        local s_cam = content:match('"' .. skey .. '":%s*{[^}]*"camelot":%s*(%d+)')
        local s_mod = content:match('"' .. skey .. '":%s*{[^}]*"mode":%s*(%d+)')
        local s_oct = content:match('"' .. skey .. '":%s*{[^}]*"oct":%s*([%-]?%d+)')
        if s_trk then stg.track_index      = tonumber(s_trk) end
        if s_cam then stg.camelot_index    = tonumber(s_cam) end
        if s_mod then stg.scale_mode_index = tonumber(s_mod) end
        if s_oct then stg.octave_offset    = tonumber(s_oct) end
    end
end

function SoundtrackDB.save()
    local lines = {}
    lines[#lines+1] = "{"
    lines[#lines+1] = '  "tracks": {'

    for i, t in ipairs(SoundtrackDB.tracks) do
        local comma = (i < #SoundtrackDB.tracks) and "," or ""
        lines[#lines+1] = string.format(
            '    "%s": { "camelot": %d, "mode": %d, "oct": %d }%s',
            t.id, t.camelot_index, t.scale_mode_index or 1, t.octave_offset or 0, comma)
    end

    lines[#lines+1] = '  },'
    lines[#lines+1] = '  "stages": {'

    for i, stg in ipairs(SoundtrackDB.stages) do
        local skey  = string.format("stage_%02d", stg.stage_num)
        local comma = (i < #SoundtrackDB.stages) and "," or ""
        lines[#lines+1] = string.format(
            '    "%s": { "track": %d, "camelot": %d, "mode": %d, "oct": %d }%s',
            skey, stg.track_index, stg.camelot_index, stg.scale_mode_index or 1, stg.octave_offset or 0, comma)
    end

    lines[#lines+1] = '  }'
    lines[#lines+1] = '}'

    love.filesystem.write(CONFIG_FILE, table.concat(lines, "\n"))
end

-- ============================================================================
-- QUERY API
-- ============================================================================
function SoundtrackDB.get_track_info(track_id)
    if not track_id then
        return SoundtrackDB.tracks[1], SoundtrackDB.CAMELOT_KEYS[11], SoundtrackDB.SCALE_MODES[1]
    end
    for _, t in ipairs(SoundtrackDB.tracks) do
        if t.id == track_id
            or t.file:find(track_id, 1, true)
            or track_id:find(t.id, 1, true) then
            local k = SoundtrackDB.CAMELOT_KEYS[t.camelot_index]   or SoundtrackDB.CAMELOT_KEYS[11]
            local m = SoundtrackDB.SCALE_MODES[t.scale_mode_index or 1] or SoundtrackDB.SCALE_MODES[1]
            return t, k, m
        end
    end
    return SoundtrackDB.tracks[1], SoundtrackDB.CAMELOT_KEYS[11], SoundtrackDB.SCALE_MODES[1]
end

function SoundtrackDB.get_stage_info(stage_num)
    local stg = SoundtrackDB.stages[stage_num] or SoundtrackDB.stages[1]
    local t   = SoundtrackDB.tracks[stg.track_index] or SoundtrackDB.tracks[1]
    local k   = SoundtrackDB.CAMELOT_KEYS[stg.camelot_index]        or SoundtrackDB.CAMELOT_KEYS[11]
    local m   = SoundtrackDB.SCALE_MODES[stg.scale_mode_index or 1] or SoundtrackDB.SCALE_MODES[1]
    return stg, t, k, m
end

-- Procedural harmonizer: assign optimal scale mode for the key type
function SoundtrackDB.generate_optimal_soundset(track_id)
    for _, t in ipairs(SoundtrackDB.tracks) do
        if t.id == track_id then
            local k = SoundtrackDB.CAMELOT_KEYS[t.camelot_index] or SoundtrackDB.CAMELOT_KEYS[11]
            t.scale_mode_index = (k.scale == "major") and 2 or 1
            t.octave_offset    = 0
            return t, k, SoundtrackDB.SCALE_MODES[t.scale_mode_index]
        end
    end
end

SoundtrackDB.load()
return SoundtrackDB

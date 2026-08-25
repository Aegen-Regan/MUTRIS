-- ============================================================================
-- FILE: audio/soundtrack_db.lua
-- MUTRIS ENGINE: PERSISTENT SOUNDTRACK & CAMELOT TONALITY DATABASE
-- ============================================================================
---@diagnostic disable: undefined-global

local SoundtrackDB = {}

local CONFIG_FILE = "soundtrack_config.json"

-- ALL 24 CAMELOT KEYS (1A-12A Minor, 1B-12B Major)
SoundtrackDB.CAMELOT_KEYS = {
    -- Minor Keys (A)
    { id = "1A", name = "1A (G#m)", root_freq = 207.65, midi = 56, scale = "minor" },
    { id = "2A", name = "2A (D#m)", root_freq = 155.56, midi = 51, scale = "minor" },
    { id = "3A", name = "3A (A#m)", root_freq = 233.08, midi = 58, scale = "minor" },
    { id = "4A", name = "4A (Fm)",  root_freq = 174.61, midi = 53, scale = "minor" },
    { id = "5A", name = "5A (Cm)",  root_freq = 130.81, midi = 48, scale = "minor" },
    { id = "6A", name = "6A (Gm)",  root_freq = 196.00, midi = 55, scale = "minor" },
    { id = "7A", name = "7A (Dm)",  root_freq = 146.83, midi = 50, scale = "minor" },
    { id = "8A", name = "8A (Am)",  root_freq = 220.00, midi = 57, scale = "minor" },
    { id = "9A", name = "9A (Em)",  root_freq = 164.81, midi = 52, scale = "minor" },
    { id = "10A", name = "10A (Bm)", root_freq = 246.94, midi = 59, scale = "minor" },
    { id = "11A", name = "11A (F#m)", root_freq = 185.00, midi = 54, scale = "minor" },
    { id = "12A", name = "12A (C#m)", root_freq = 138.59, midi = 49, scale = "minor" },
    -- Major Keys (B)
    { id = "1B", name = "1B (B)",   root_freq = 246.94, midi = 59, scale = "major" },
    { id = "2B", name = "2B (F#)",  root_freq = 185.00, midi = 54, scale = "major" },
    { id = "3B", name = "3B (Db)",  root_freq = 138.59, midi = 49, scale = "major" },
    { id = "4B", name = "4B (Ab)",  root_freq = 207.65, midi = 56, scale = "major" },
    { id = "5B", name = "5B (Eb)",  root_freq = 155.56, midi = 51, scale = "major" },
    { id = "6B", name = "6B (Bb)",  root_freq = 233.08, midi = 58, scale = "major" },
    { id = "7B", name = "7B (F)",   root_freq = 174.61, midi = 53, scale = "major" },
    { id = "8B", name = "8B (C)",   root_freq = 130.81, midi = 48, scale = "major" },
    { id = "9B", name = "9B (G)",   root_freq = 196.00, midi = 55, scale = "major" },
    { id = "10B", name = "10B (D)", root_freq = 146.83, midi = 50, scale = "major" },
    { id = "11B", name = "11B (A)", root_freq = 220.00, midi = 57, scale = "major" },
    { id = "12B", name = "12B (E)", root_freq = 164.81, midi = 52, scale = "major" },
}

-- DEFAULT TRACK REGISTRY
SoundtrackDB.tracks = {
    { id = "base_fondo", name = "Base Fondo", file = "music/base_fondo.mp3", camelot_index = 11 }, -- 11A (F#m)
    { id = "eliveta_uplifting_trance", name = "Eliveta Uplifting Trance", file = "music/eliveta_uplifting_trance.mp3", camelot_index = 10 }, -- 10A (Bm)
    { id = "alex_morgan_trance_euphoria", name = "Alex Morgan Trance Euphoria", file = "music/alex_morgan_trance_euphoria.mp3", camelot_index = 17 } -- 5B (Eb)
}

local function parseDB(str)
    local data = { tracks = {} }
    for id, idx in str:gmatch('"id":%s*"([^"]+)",%s*"camelot_index":%s*(%d+)') do
        table.insert(data.tracks, { id = id, camelot_index = tonumber(idx) })
    end
    return data
end

local function serializeDB(tracks)
    local s = "{\n  \"tracks\": [\n"
    for i, t in ipairs(tracks) do
        s = s .. string.format('    { "id": "%s", "camelot_index": %d }', t.id, t.camelot_index)
        if i < #tracks then s = s .. "," end
        s = s .. "\n"
    end
    s = s .. "  ]\n}\n"
    return s
end

function SoundtrackDB.load()
    if love.filesystem.getInfo(CONFIG_FILE) then
        local content = love.filesystem.read(CONFIG_FILE)
        if content then
            local ok, data = pcall(parseDB, content)
            if ok and data and data.tracks then
                for _, saved in ipairs(data.tracks) do
                    for _, current in ipairs(SoundtrackDB.tracks) do
                        if current.id == saved.id then
                            current.camelot_index = saved.camelot_index or current.camelot_index
                        end
                    end
                end
            end
        end
    end
end

function SoundtrackDB.save()
    local export_data = {}
    for _, t in ipairs(SoundtrackDB.tracks) do
        table.insert(export_data, { id = t.id, camelot_index = t.camelot_index })
    end
    local ok, encoded = pcall(serializeDB, export_data)
    if ok and encoded then
        love.filesystem.write(CONFIG_FILE, encoded)
    end
end

function SoundtrackDB.get_track_info(track_id)
    for _, t in ipairs(SoundtrackDB.tracks) do
        if t.id == track_id or t.file:find(track_id, 1, true) then
            local k = SoundtrackDB.CAMELOT_KEYS[t.camelot_index] or SoundtrackDB.CAMELOT_KEYS[11]
            return t, k
        end
    end
    return SoundtrackDB.tracks[1], SoundtrackDB.CAMELOT_KEYS[11]
end

SoundtrackDB.load()
return SoundtrackDB

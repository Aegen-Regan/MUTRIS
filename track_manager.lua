---@diagnostic disable: undefined-global
local TrackManager = {}
local love = love

TrackManager.NOTE_FREQS = {
    ["C"]  = 261.63, ["C#"] = 277.18, ["D"]  = 293.66, ["D#"] = 311.13,
    ["E"]  = 329.63, ["F"]  = 349.23, ["F#"] = 369.99, ["G"]  = 392.00,
    ["G#"] = 415.30, ["A"]  = 440.00, ["A#"] = 466.16, ["B"]  = 493.88
}

TrackManager.MODES = {
    ["MAJOR"] = {
        human = {1.0, 1.122, 1.260, 1.335, 1.498, 1.682, 1.888}, 
        bot   = {1.0, 1.059, 1.189, 1.335, 1.498, 1.587, 1.682}  
    },
    ["MINOR"] = {
        human = {1.0, 1.122, 1.189, 1.335, 1.498, 1.587, 1.782}, 
        bot   = {1.0, 1.059, 1.189, 1.335, 1.498, 1.587, 1.782}  
    }
}

TrackManager.tracks = {}
TrackManager.current_track_index = 1

local function serializeJSON(t)
    local s = "{\n"
    for k, v in pairs(t) do
        s = s .. '  "' .. tostring(k) .. '": '
        if type(v) == "string" then s = s .. '"' .. v .. '"'
        elseif type(v) == "number" or type(v) == "boolean" then s = s .. tostring(v)
        end
        s = s .. ",\n"
    end
    s = s:sub(1, -3) .. "\n}" 
    return s
end

local function parseSimpleJSON(str)
    local t = {}
    for k, v in str:gmatch('"([%w_]+)":%s*"?([^",\n}]+)"?') do
        local num = tonumber(v)
        if num then t[k] = num
        elseif v == "true" then t[k] = true
        elseif v == "false" then t[k] = false
        else t[k] = v end
    end
    return t
end

function TrackManager.init()
    TrackManager.loadSavedTracks()
end
function TrackManager.loadSavedTracks()
    TrackManager.tracks = {}
    
    local files = love.filesystem.getDirectoryItems("music")
    for _, file in ipairs(files) do
        local ext = file:match("%.([^%.]+)$")
        if ext and (ext:lower() == "mp3" or ext:lower() == "ogg") then
            local track_base_name = file:match("([^%.]+)%.")
            local json_file_path = "music/" .. track_base_name .. ".json"
            
            local track_data = {
                name = track_base_name:upper():gsub("_", " "):sub(1, 24),
                file_name = file,
                file_path = "music/" .. file,
                is_embedded = false,
                bpm = 120,
                root_note = "A",
                mode = "MINOR",
                drop_second = 60,       
                build_duration = 15
            }
            
            if love.filesystem.getInfo(json_file_path) then
                local contents = love.filesystem.read(json_file_path)
                if contents then
                    local data = parseSimpleJSON(contents)
                    track_data.bpm = tonumber(data.bpm) or 120
                    track_data.root_note = data.root_note or "A"
                    track_data.mode = data.mode or "MINOR"
                    track_data.drop_second = tonumber(data.drop_second) or 60
                    track_data.build_duration = tonumber(data.build_duration) or 15
                    if data.name then track_data.name = data.name:upper() end
                end
            end
            table.insert(TrackManager.tracks, track_data)
        end
    end
    
    if #TrackManager.tracks == 0 then
        table.insert(TrackManager.tracks, {
            name = "COLOQUE TEMAS EN MUSIC/", file_path = "", is_embedded = true,
            bpm = 120, root_note = "C", mode = "MINOR", drop_second = 60, build_duration = 15
        })
    end
end

function TrackManager.injectCustomTrack(source_full_path, track_name, bpm, root_note, mode, drop_sec, build_dur)
    local track_base_name = source_full_path:match("([^/\\]+)%.[^%.]+$") or "custom_track"
    local system_path = love.filesystem.getSource() .. "/music/" .. track_base_name .. ".json"
    
    local metadata = {
        name = track_name,
        bpm = tonumber(bpm) or 120,
        root_note = root_note or "A",
        mode = mode or "MINOR",
        drop_second = tonumber(drop_sec) or 60,
        build_duration = tonumber(build_dur) or 15
    }
    
    local file = io.open(system_path, "w")
    if file then
        file:write(serializeJSON(metadata))
        file:close()
    else
        love.filesystem.write("music/" .. track_base_name .. ".json", serializeJSON(metadata))
    end
    
    TrackManager.loadSavedTracks()
    return true, "Configuración inyectada con éxito físico en Windows."
end

function TrackManager.getCurrentTrack()
    return TrackManager.tracks[TrackManager.current_track_index]
end

function TrackManager.nextTrack()
    if #TrackManager.tracks <= 1 then return end
    TrackManager.current_track_index = (TrackManager.current_track_index % #TrackManager.tracks) + 1
end

function TrackManager.prevTrack()
    if #TrackManager.tracks <= 1 then return end
    TrackManager.current_track_index = TrackManager.current_track_index - 1
    if TrackManager.current_track_index < 1 then TrackManager.current_track_index = #TrackManager.tracks end
end

function TrackManager.applyTrackAudioSettings()
    local track = TrackManager.getCurrentTrack()
    if track.is_embedded and track.file_path == "" then return end
    
    local AudioManager = require "audio_manager"
    AudioManager.base_bpm = track.bpm
    AudioManager.current_bpm = track.bpm

    local root_freq = TrackManager.NOTE_FREQS[track.root_note] or 261.63
    local active_mode = TrackManager.MODES[track.mode] or TrackManager.MODES["MINOR"]
    local base_octave = root_freq * 0.25
    local scale_intervals = active_mode.human

    -- FIX BLINDADO ABSOLUTO: Acceder explícitamente renglón por renglón al índice numérico
    -- de la tabla de la escala para extraer flotantes puros y evitar la multiplicación directa de tablas.
    --: Tónica, [3]: Tercera, [5]: Quinta, [7]: Séptima menor/mayor
    _G.PLAYER_NOTES = { 
        base_octave * (scale_intervals[1] or 1.0), 
        base_octave * (scale_intervals[3] or 1.189), 
        base_octave * (scale_intervals[5] or 1.498), 
        base_octave * (scale_intervals[7] or 1.782) 
    }
    
    _G.BOT_NOTES = { 
        base_octave * (scale_intervals[1] or 1.0), 
        base_octave * (scale_intervals[3] or 1.189), 
        base_octave * (scale_intervals[5] or 1.498), 
        base_octave * (scale_intervals[7] or 1.782) 
    }
    
    _G.BG_SCALE = { 
        base_octave * 0.5, 
        base_octave * 0.5 * (scale_intervals[3] or 1.189), 
        base_octave * 0.5 * (scale_intervals[5] or 1.498) 
    }
end

return TrackManager

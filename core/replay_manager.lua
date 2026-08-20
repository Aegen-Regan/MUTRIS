---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: DETERMINISTIC REPLAY RECORDER & PLAYBACK (.mutrisrec)
-- Arquitectura: Zero-GC / Serialización Compacta (<10 KB) / Sincronía Frame a Frame
-- ============================================================================
local ReplayManager = {}

local Blackbox = require "core.blackbox"

ReplayManager.is_recording = false
ReplayManager.is_replaying = false
ReplayManager.current_frame = 0

-- Buffer de eventos de la partida
ReplayManager.match_data = {
    version     = _G.ENGINE_VERSION or "MUTRIS v1.0.0",
    date        = "",
    mode        = "versus",
    seed        = 12345,
    track_name  = "DEFAULT",
    duration    = 0.0,
    total_frames = 0,
    inputs_p1   = {},
    inputs_bot  = {}
}

function ReplayManager.startRecording(mode, seed, track_name)
    ReplayManager.is_recording = true
    ReplayManager.is_replaying = false
    ReplayManager.current_frame = 0

    local data = ReplayManager.match_data
    data.version = _G.ENGINE_VERSION or "MUTRIS v1.0.0"
    data.date = os.date("%Y-%m-%d %H:%M:%S")
    data.mode = mode or "versus"
    data.seed = seed or math.random(100000, 999999)
    data.track_name = track_name or "TRACK"
    data.duration = 0.0
    data.total_frames = 0
    data.inputs_p1 = {}
    data.inputs_bot = {}

    Blackbox.log("REPLAY", "REPLAY RECORDING STARTED", data.seed, 0)
end

function ReplayManager.recordAction(player_type, action_name)
    if not ReplayManager.is_recording then return end
    
    local entry = string.format("%d:%s", ReplayManager.current_frame, action_name)
    if player_type == "human" then
        table.insert(ReplayManager.match_data.inputs_p1, entry)
    else
        table.insert(ReplayManager.match_data.inputs_bot, entry)
    end
end

function ReplayManager.update(dt)
    if ReplayManager.is_recording then
        ReplayManager.current_frame = ReplayManager.current_frame + 1
        ReplayManager.match_data.duration = _G.RealMatchTimer or 0.0
        ReplayManager.match_data.total_frames = ReplayManager.current_frame
    end
end

function ReplayManager.saveReplay(filepath)
    if not ReplayManager.is_recording then return end
    ReplayManager.is_recording = false

    if not love.filesystem.getInfo("replays") then
        love.filesystem.createDirectory("replays")
    end

    local timestamp = os.date("%Y%m%d_%H%M%S")
    local path = filepath or ("replays/MUTRIS_" .. timestamp .. ".mutrisrec")

    local lines = {}
    table.insert(lines, "[MUTRIS_REPLAY_v1.0]")
    table.insert(lines, "DATE=" .. ReplayManager.match_data.date)
    table.insert(lines, "MODE=" .. ReplayManager.match_data.mode)
    table.insert(lines, "SEED=" .. tostring(ReplayManager.match_data.seed))
    table.insert(lines, "TRACK=" .. ReplayManager.match_data.track_name)
    table.insert(lines, string.format("DURATION=%.2f", ReplayManager.match_data.duration))
    table.insert(lines, "TOTAL_FRAMES=" .. tostring(ReplayManager.match_data.total_frames))

    table.insert(lines, "\n[INPUTS_P1]")
    for _, input in ipairs(ReplayManager.match_data.inputs_p1) do
        table.insert(lines, input)
    end

    table.insert(lines, "\n[INPUTS_BOT]")
    for _, input in ipairs(ReplayManager.match_data.inputs_bot) do
        table.insert(lines, input)
    end

    local serialized = table.concat(lines, "\n")
    love.filesystem.write(path, serialized)

    local local_file = io.open(path, "w")
    if local_file then
        local_file:write(serialized)
        local_file:close()
    end

    Blackbox.log("REPLAY", "SAVED: " .. path, ReplayManager.match_data.total_frames, 0)
    print("📁 Replay saved to: " .. path)
end

return ReplayManager
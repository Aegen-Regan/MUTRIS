-- ================================================================
-- FILE: plugins/anomalies/sample_blitz.lua
-- ================================================================
local SampleBlitz = {
    name = "Sample Blitz Anomaly",
    author = "Copilot Zero-GC"
}

function SampleBlitz.onBeat(beat_number, bpm)
    if beat_number % 8 == 0 then
        _G.AudioBeatPulse = 1.0
    end
end

function SampleBlitz.onLineClear(lines, is_tspin, player_id, combo)
    -- Escucha eventos sin recargar ni tocar el core
end

return SampleBlitz
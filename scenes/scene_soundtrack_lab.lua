-- ============================================================================
-- FILE: scenes/scene_soundtrack_lab.lua
-- MUTRIS ENGINE: AAA CYBERPUNK SOUNDSET FORGE & DAW STUDIO (1280x720 / Zero-GC)
-- TARGET: Intel Pentium G3250 Haswell / Intel HD Graphics (Zero Allocation Draw)
-- ============================================================================
---@diagnostic disable: undefined-global

local SceneSoundtrackLab = {}
local SoundtrackDB       = require("audio.soundtrack_db")
local SoundManager       = require("audio.sound_manager")
local OscClient          = require("network.osc_client")

local MODE_TRACKS = 1
local MODE_STAGES = 2
local current_mode = MODE_TRACKS

local sel_track_idx    = 1
local sel_stage_idx    = 1
local simulated_danger = 0.0
local active_pad        = 0
local pad_flash         = 0.0
local status_toast      = ""
local toast_timer       = 0.0

local run_active = false
local run_col    = 1
local run_timer  = 0.0

-- NOTE NAMES LOOKUP TABLE
local NOTE_NAMES = { "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" }

-- 16-BAND SPECTRUM VISUALIZER BUFFER (Zero-GC)
local SPECTRUM_BANDS = 16
local spec_levels = {}
local spec_decay  = {}
for b = 1, SPECTRUM_BANDS do
    spec_levels[b] = 0.0
    spec_decay[b]  = 2.5 + (b * 0.1)
end

-- AUDITION PADS MATRIX (Hardware Launchpad Layout)
local PADS = {
    { key = "1", title = "HARD DROP",      badge = "CH 1: BASS",   vst = "TB_Lowtone",           desc = "Sub-Bass 40Hz Impact",       col = {1.00, 0.25, 0.25} },
    { key = "2", title = "PENTATONIC RUN", badge = "CH 2: PLUCK",  vst = "TB_Flowtones",         desc = "10 Cols Ascending Scale",   col = {0.00, 0.88, 1.00} },
    { key = "3", title = "ROTATION (5th)", badge = "CH 2: ARP",    vst = "TB_Flowtones",         desc = "+7st Harmonic Arpeggio",    col = {0.15, 1.00, 0.55} },
    { key = "4", title = "HOLD (Sus4)",    badge = "CH 2: TEXTURE",vst = "TB_Flowtones",         desc = "+5st Suspended Atmosphere", col = {0.75, 0.35, 1.00} },
    { key = "5", title = "1-LINE (TRIAD)", badge = "CH 4: HARMONY",vst = "The Grandeur / Strings",desc = "Root + 3rd + 5th Chords",   col = {1.00, 0.85, 0.20} },
    { key = "6", title = "2-LINES (7th)",  badge = "CH 4: HARMONY",vst = "The Grandeur / Strings",desc = "Root + 3rd + 5th + 7th",    col = {1.00, 0.65, 0.15} },
    { key = "7", title = "3-LINES (9th)",  badge = "CH 4: HARMONY",vst = "The Grandeur / Strings",desc = "Extended 9th Tension Chord",col = {1.00, 0.45, 0.30} },
    { key = "8", title = "TETRIS 4L",      badge = "CH 1+4 HYBRID",vst = "Sub-Drop + Octave",    desc = "Full Dynamic Explosion",     col = {0.00, 1.00, 0.80} },
    { key = "9", title = "T-SPIN (FM)",    badge = "CH 3: LEAD",   vst = "Genny / Vital",        desc = "High FM Lead Synth Stab",    col = {1.00, 0.10, 0.75} },
}

local function apply_selection()
    if current_mode == MODE_TRACKS then
        local t = SoundtrackDB.tracks[sel_track_idx]
        if t then SoundManager.set_active_track(t.id) end
    else
        SoundManager.load_stage_soundset(sel_stage_idx)
    end
end

function SceneSoundtrackLab.enter()
    current_mode     = MODE_TRACKS
    sel_track_idx    = 1
    sel_stage_idx    = 1
    simulated_danger = 0.0
    status_toast     = "STUDIO FORGE READY // LINKED TO REAPER (127.0.0.1:8000)"
    toast_timer      = 3.5
    run_active       = false
    
    SoundManager.init()
    OscClient.init("127.0.0.1", 8000)
    apply_selection()
end

function SceneSoundtrackLab.update(dt)
    SoundManager.update(dt)
    OscClient.update(dt)

    if toast_timer > 0 then toast_timer = toast_timer - dt end
    if pad_flash > 0 then
        pad_flash = pad_flash - dt
        if pad_flash <= 0 then active_pad = 0 end
    end

    local pulse = _G.AudioBeatPulse or 0.0
    for b = 1, SPECTRUM_BANDS do
        if pulse > 0.01 then
            local target = math.min(1.0, pulse * (1.2 - (b * 0.04)) + (math.random() * 0.35))
            spec_levels[b] = math.max(spec_levels[b], target)
        end
        spec_levels[b] = math.max(0.0, spec_levels[b] - dt * spec_decay[b])
    end

    if run_active then
        run_timer = run_timer - dt
        if run_timer <= 0 then
            SoundManager.play_move_column(run_col)
            spec_levels[math.min(SPECTRUM_BANDS, run_col * 1.5)] = 1.0
            run_col = run_col + 1
            run_timer = 0.055
            if run_col > 10 then run_active = false; run_col = 1 end
        end
    end
end

local function trigger_pad_action(idx)
    active_pad = idx
    for b = 1, 6 do spec_levels[b + (idx % 8)] = 1.0 end

    if idx == 1 then
        pad_flash = 0.20; SoundManager.play_hard_drop()
    elseif idx == 2 then
        pad_flash = 0.65; run_active = true; run_col = 1; run_timer = 0.0
    elseif idx == 3 then
        pad_flash = 0.20; SoundManager.play_rotate(5)
    elseif idx == 4 then
        pad_flash = 0.20; SoundManager.play_hold()
    elseif idx == 5 then
        pad_flash = 0.22; SoundManager.play_line_clear(1)
    elseif idx == 6 then
        pad_flash = 0.22; SoundManager.play_line_clear(2)
    elseif idx == 7 then
        pad_flash = 0.22; SoundManager.play_line_clear(3)
    elseif idx == 8 then
        pad_flash = 0.35; SoundManager.play_line_clear(4)
    elseif idx == 9 then
        pad_flash = 0.22; SoundManager.play_tspin()
    end
end

function SceneSoundtrackLab.keypressed(key)
    if key == "tab" then
        current_mode = (current_mode == MODE_TRACKS) and MODE_STAGES or MODE_TRACKS
        apply_selection()
        status_toast = (current_mode == MODE_TRACKS) and "MODE: GLOBAL TRACKS CALIBRATION" or "MODE: STORY STAGES FORGE (1..50)"
        toast_timer = 1.8
        return
    end

    if current_mode == MODE_TRACKS then
        local t = SoundtrackDB.tracks[sel_track_idx]
        if key == "up" then
            sel_track_idx = ((sel_track_idx - 2 + #SoundtrackDB.tracks) % #SoundtrackDB.tracks) + 1
            apply_selection()
        elseif key == "down" then
            sel_track_idx = (sel_track_idx % #SoundtrackDB.tracks) + 1
            apply_selection()
        elseif key == "left" and t then
            t.camelot_index = ((t.camelot_index - 2 + #SoundtrackDB.CAMELOT_KEYS) % #SoundtrackDB.CAMELOT_KEYS) + 1
            apply_selection()
        elseif key == "right" and t then
            t.camelot_index = (t.camelot_index % #SoundtrackDB.CAMELOT_KEYS) + 1
            apply_selection()
        elseif key == "m" and t then
            t.scale_mode_index = (t.scale_mode_index % #SoundtrackDB.SCALE_MODES) + 1
            apply_selection()
        elseif key == "o" and t then
            t.octave_offset = ((t.octave_offset + 2) % 3) - 1
            apply_selection()
        elseif key == "g" and t then
            t.scale_mode_index = math.random(1, #SoundtrackDB.SCALE_MODES)
            t.octave_offset = math.random(-1, 1)
            apply_selection()
            status_toast = "HARMONIC SOUNDSET GENERATED!"
            toast_timer = 1.8
        end
    else
        local stg = SoundtrackDB.stages[sel_stage_idx]
        if key == "up" then
            sel_stage_idx = ((sel_stage_idx - 2 + #SoundtrackDB.stages) % #SoundtrackDB.stages) + 1
            apply_selection()
        elseif key == "down" then
            sel_stage_idx = (sel_stage_idx % #SoundtrackDB.stages) + 1
            apply_selection()
        elseif key == "t" and stg then
            stg.track_index = (stg.track_index % #SoundtrackDB.tracks) + 1
            apply_selection()
        elseif key == "left" and stg then
            stg.camelot_index = ((stg.camelot_index - 2 + #SoundtrackDB.CAMELOT_KEYS) % #SoundtrackDB.CAMELOT_KEYS) + 1
            apply_selection()
        elseif key == "right" and stg then
            stg.camelot_index = (stg.camelot_index % #SoundtrackDB.CAMELOT_KEYS) + 1
            apply_selection()
        elseif key == "m" and stg then
            stg.scale_mode_index = (stg.scale_mode_index % #SoundtrackDB.SCALE_MODES) + 1
            apply_selection()
        elseif key == "o" and stg then
            stg.octave_offset = ((stg.octave_offset + 2) % 3) - 1
            apply_selection()
        elseif key == "g" and stg then
            stg.track_index = math.random(1, #SoundtrackDB.tracks)
            stg.scale_mode_index = math.random(1, #SoundtrackDB.SCALE_MODES)
            stg.octave_offset = math.random(-1, 1)
            apply_selection()
            status_toast = "STAGE SOUNDSET GENERATED!"
            toast_timer = 1.8
        end
    end

    -- DANGER MODULATION
    if key == "d" then
        simulated_danger = math.max(0.0, simulated_danger - 0.1)
        OscClient.send_danger(simulated_danger)
        status_toast = string.format("DANGER FILTER: %d%%", math.floor(simulated_danger * 100))
        toast_timer = 1.0
    elseif key == "f" then
        simulated_danger = math.min(1.0, simulated_danger + 0.1)
        OscClient.send_danger(simulated_danger)
        status_toast = string.format("DANGER FILTER: %d%%", math.floor(simulated_danger * 100))
        toast_timer = 1.0

    -- PADS 1..9
    elseif key == "1" then trigger_pad_action(1)
    elseif key == "2" then trigger_pad_action(2)
    elseif key == "3" then trigger_pad_action(3)
    elseif key == "4" then trigger_pad_action(4)
    elseif key == "5" then trigger_pad_action(5)
    elseif key == "6" then trigger_pad_action(6)
    elseif key == "7" then trigger_pad_action(7)
    elseif key == "8" then trigger_pad_action(8)
    elseif key == "9" then trigger_pad_action(9)

    -- SAVE
    elseif key == "s" then
        SoundtrackDB.save()
        status_toast = "SAVED TO DISK: soundtrack_config.json"
        toast_timer = 2.5
        SoundManager.play_hard_drop()

    -- EXIT TO MENU (SAFE ROBUST TRANSITION)
    elseif key == "escape" then
        local ok, sm = pcall(require, "core.scene_manager")
        if not ok or not sm then ok, sm = pcall(require, "scene_manager") end
        if not ok or not sm then sm = _G.SceneManager end

        if sm and sm.setState then
            sm.setState("menu")
        elseif sm and sm.switch then
            sm.switch("menu")
        elseif sm and sm.changeScene then
            sm.changeScene("scene_menu")
        end
    end
end

function SceneSoundtrackLab.mousepressed(x, y, button)
    if button ~= 1 then return end

    -- Tab 1 click
    if x >= 40 and x <= 300 and y >= 66 and y <= 96 then
        current_mode = MODE_TRACKS
        apply_selection()
        return
    end
    -- Tab 2 click
    if x >= 315 and x <= 615 and y >= 66 and y <= 96 then
        current_mode = MODE_STAGES
        apply_selection()
        return
    end

    -- Danger Slider Click / Scrub
    if x >= 660 and x <= 1240 and y >= 108 and y <= 242 then
        if y >= 155 and y <= 190 then
            local rel_x = math.max(0.0, math.min(1.0, (x - 675) / 550))
            simulated_danger = rel_x
            OscClient.send_danger(simulated_danger)
            status_toast = string.format("DANGER FILTER: %d%%", math.floor(simulated_danger * 100))
            toast_timer = 1.0
            return
        end
    end

    -- Audition Pads Click (3x3 Matrix)
    local start_x, start_y = 40, 255
    local pad_w, pad_h = 386, 116
    local gap_x, gap_y = 20, 16

    for i = 1, 9 do
        local row = math.floor((i - 1) / 3)
        local col = (i - 1) % 3
        local px = start_x + col * (pad_w + gap_x)
        local py = start_y + row * (pad_h + gap_y)

        if x >= px and x <= px + pad_w and y >= py and y <= py + pad_h then
            trigger_pad_action(i)
            return
        end
    end
end

local function draw_rack_card(x, y, w, h, r, g, b, alpha)
    local lg = love.graphics
    lg.setColor(0.04, 0.07, 0.12, 0.94)
    lg.rectangle("fill", x, y, w, h, 4, 4)

    lg.setColor(0.12, 0.18, 0.28, 0.8)
    lg.setLineWidth(1)
    lg.rectangle("line", x, y, w, h, 4, 4)

    local b_len = 10
    lg.setColor(r, g, b, alpha)
    lg.setLineWidth(2)
    lg.line(x, y + b_len, x, y, x + b_len, y)
    lg.line(x + w - b_len, y, x + w, y, x + w, y + b_len)
    lg.line(x, y + h - b_len, x, y + h, x + b_len, y + h)
    lg.line(x + w - b_len, y + h, x + w, y + h, x + w, y + h - b_len)
    lg.setLineWidth(1)
end

function SceneSoundtrackLab.draw()
    local lg = love.graphics

    -- 1. TOP HEADER
    lg.setColor(0.0, 0.85, 1.0, 0.9)
    lg.rectangle("fill", 40, 15, 1200, 2)

    lg.setColor(0.0, 0.9, 1.0, 1.0)
    lg.print("MUTRIS", 45, 22)
    lg.setColor(1.0, 1.0, 1.0, 1.0)
    lg.print(" // SYNTHESIA WORKSTATION & SOUNDSET FORGE", 95, 22)

    lg.setColor(0.55, 0.65, 0.78, 0.9)
    lg.print("[TAB] Mode  [UP/DN] Select  [LT/RT] Key  [M] Mode  [O] Oct  [T] Song  [G] Harmonize  [S] Save  [ESC] Exit", 45, 42)

    -- 2. DUAL MODE SELECTOR TABS
    local is_tracks = (current_mode == MODE_TRACKS)
    lg.setColor(is_tracks and 0.05 or 0.02, is_tracks and 0.45 or 0.08, is_tracks and 0.75 or 0.16, 0.95)
    lg.rectangle("fill", 40, 66, 260, 30, 4, 4)
    lg.setColor(is_tracks and 0.0 or 0.25, is_tracks and 0.9 or 0.35, is_tracks and 1.0 or 0.45, is_tracks and 1.0 or 0.4)
    lg.setLineWidth(is_tracks and 2 or 1)
    lg.rectangle("line", 40, 66, 260, 30, 4, 4)
    lg.setColor(1.0, 1.0, 1.0, is_tracks and 1.0 or 0.5)
    lg.print(is_tracks and "[ 1 ] GLOBAL TRACKS (ACTIVE)" or "[ 1 ] GLOBAL TRACKS", 55, 73)

    lg.setColor(not is_tracks and 0.55 or 0.02, not is_tracks and 0.12 or 0.08, not is_tracks and 0.65 or 0.16, 0.95)
    lg.rectangle("fill", 315, 66, 300, 30, 4, 4)
    lg.setColor(not is_tracks and 1.0 or 0.25, not is_tracks and 0.35 or 0.35, not is_tracks and 1.0 or 0.45, not is_tracks and 1.0 or 0.4)
    lg.setLineWidth(not is_tracks and 2 or 1)
    lg.rectangle("line", 315, 66, 300, 30, 4, 4)
    lg.setColor(1.0, 1.0, 1.0, not is_tracks and 1.0 or 0.5)
    lg.print(not is_tracks and "[ 2 ] STORY STAGES (ACTIVE)" or "[ 2 ] STORY STAGE BUILDER", 330, 73)
    lg.setLineWidth(1)

    -- 3. LEFT CARD: HARMONIC DNA
    draw_rack_card(40, 108, 580, 134, is_tracks and 0.0 or 0.85, is_tracks and 0.85 or 0.35, 1.0, 0.9)

    if is_tracks then
        local t = SoundtrackDB.tracks[sel_track_idx]
        lg.setColor(0.5, 0.6, 0.75, 0.9)
        lg.print(string.format("GLOBAL TRACK PROFILE [%d / %d]", sel_track_idx, #SoundtrackDB.tracks), 55, 116)
        lg.setColor(1.0, 1.0, 1.0, 1.0)
        lg.print(t and t.name or "N/A", 55, 134)
    else
        local stg, t = SoundtrackDB.get_stage_info(sel_stage_idx)
        lg.setColor(1.0, 0.4, 0.8, 0.9)
        lg.print(string.format("STORY STAGE [%02d / 50] // BESPOKE SOUNDSET", sel_stage_idx), 55, 116)
        lg.setColor(1.0, 1.0, 1.0, 1.0)
        lg.print(stg and stg.name or "", 55, 134)
        lg.setColor(0.2, 1.0, 0.7, 1.0)
        lg.print("SONG: " .. (t and t.name or "") .. "  [Key 'T']", 290, 134)
    end

    lg.setColor(0.0, 0.4, 0.5, 0.8)
    lg.rectangle("fill", 55, 156, 130, 20, 3, 3)
    lg.setColor(0.0, 1.0, 0.8, 1.0)
    lg.print("KEY: " .. (SoundManager.current_key_name or "11A (F#m)"), 62, 159)

    local mode_idx = is_tracks and (SoundtrackDB.tracks[sel_track_idx].scale_mode_index or 1) or (SoundtrackDB.stages[sel_stage_idx].scale_mode_index or 1)
    local cur_mode = SoundtrackDB.SCALE_MODES[mode_idx] or SoundtrackDB.SCALE_MODES[1]
    lg.setColor(0.45, 0.35, 0.1, 0.8)
    lg.rectangle("fill", 195, 156, 210, 20, 3, 3)
    lg.setColor(1.0, 0.85, 0.3, 1.0)
    lg.print(cur_mode.name .. " [M]", 202, 159)

    local oct = is_tracks and (SoundtrackDB.tracks[sel_track_idx].octave_offset or 0) or (SoundtrackDB.stages[sel_stage_idx].octave_offset or 0)
    lg.setColor(0.25, 0.25, 0.35, 0.8)
    lg.rectangle("fill", 415, 156, 190, 20, 3, 3)
    lg.setColor(0.85, 0.85, 0.95, 1.0)
    lg.print(string.format("MIDI %d | OCT: %+d [O]", SoundManager.root_midi or 54, oct), 422, 159)

    lg.setColor(0.6, 0.7, 0.85, 0.8)
    lg.print("PENTATONIC SCALE DNA (COLS 1..10):", 55, 184)

    local chip_x, chip_y = 55, 204
    local chip_w, chip_h = 50, 24
    local chip_gap = 6

    for c = 1, 10 do
        local st = SoundManager.active_intervals and SoundManager.active_intervals[c] or 0
        local note_idx = (((SoundManager.root_midi or 54) + st) % 12) + 1
        local note_txt = NOTE_NAMES[note_idx] or "??"
        local cx = chip_x + (c - 1) * (chip_w + chip_gap)

        lg.setColor(0.08, 0.14, 0.22, 0.9)
        lg.rectangle("fill", cx, chip_y, chip_w, chip_h, 3, 3)
        lg.setColor(0.0, 0.75, 1.0, 0.6)
        lg.rectangle("line", cx, chip_y, chip_w, chip_h, 3, 3)

        lg.setColor(0.0, 1.0, 0.9, 1.0)
        lg.print(note_txt, cx + 8, chip_y + 4)
        lg.setColor(0.5, 0.6, 0.7, 0.8)
        lg.print(tostring(c), cx + chip_w - 12, chip_y + 9)
    end

    -- 4. RIGHT CARD: REAPER DANGER & LIVE SPECTRUM
    draw_rack_card(660, 108, 580, 134, 1.0, 0.35, 0.2, 0.9)

    lg.setColor(1.0, 0.4, 0.3, 1.0)
    lg.print("REAPER DANGER MODULATOR (/mutris/danger)", 675, 116)
    lg.setColor(0.65, 0.7, 0.8, 0.9)
    lg.print("[D] -10%  |  [F] +10%  (Or Drag Slider)", 675, 134)

    lg.setColor(0.0, 0.35, 0.25, 0.9)
    lg.rectangle("fill", 985, 116, 240, 20, 3, 3)
    lg.setColor(0.0, 1.0, 0.6, 1.0)
    lg.print(OscClient.get_telemetry(), 992, 119)

    local gauge_x, gauge_y, gauge_w, gauge_h = 675, 160, 550, 22
    lg.setColor(0.06, 0.08, 0.12, 1.0)
    lg.rectangle("fill", gauge_x, gauge_y, gauge_w, gauge_h, 2, 2)
    lg.setColor(0.18, 0.24, 0.32, 0.8)
    lg.rectangle("line", gauge_x, gauge_y, gauge_w, gauge_h, 2, 2)

    local segments = 32
    local active_segs = math.floor(simulated_danger * segments)
    local seg_w = (gauge_w - (segments - 1) * 2) / segments

    for s = 1, segments do
        local sx = gauge_x + (s - 1) * (seg_w + 2)
        local ratio = s / segments
        if s <= active_segs then
            if ratio < 0.45 then
                lg.setColor(0.0, 0.9, 1.0, 1.0)
            elseif ratio < 0.75 then
                lg.setColor(1.0, 0.85, 0.1, 1.0)
            else
                lg.setColor(1.0, 0.15, 0.25, 1.0)
            end
            lg.rectangle("fill", sx, gauge_y + 2, seg_w, gauge_h - 4)
        else
            lg.setColor(0.1, 0.14, 0.2, 0.3)
            lg.rectangle("fill", sx, gauge_y + 2, seg_w, gauge_h - 4)
        end
    end

    lg.setColor(0.5, 0.6, 0.7, 0.8)
    lg.print("0% [SAFE]", gauge_x, gauge_y + 24)
    lg.print("50% [ATTACK]", gauge_x + gauge_w * 0.45, gauge_y + 24)
    lg.setColor(1.0, 0.3, 0.3, 1.0)
    lg.print("100% [PEAK]", gauge_x + gauge_w - 75, gauge_y + 24)

    local spec_x, spec_y, spec_w, spec_h = 675, 204, 550, 24
    local bar_w = (spec_w - (SPECTRUM_BANDS - 1) * 3) / SPECTRUM_BANDS

    for b = 1, SPECTRUM_BANDS do
        local bx = spec_x + (b - 1) * (bar_w + 3)
        local lvl = math.max(0.05, spec_levels[b])
        local bh = spec_h * lvl
        local by = spec_y + spec_h - bh

        lg.setColor(0.0, 0.6 + lvl * 0.4, 1.0 - lvl * 0.5, 0.85)
        lg.rectangle("fill", bx, by, bar_w, bh, 1, 1)
    end

    -- 5. BOTTOM 3x3 SOUND MATRIX CONTROLLER
    local start_x, start_y = 40, 255
    local pad_w, pad_h = 386, 116
    local gap_x, gap_y = 20, 16

    for i = 1, 9 do
        local p = PADS[i]
        local row = math.floor((i - 1) / 3)
        local col = (i - 1) % 3
        local px = start_x + col * (pad_w + gap_x)
        local py = start_y + row * (pad_h + gap_y)

        local is_hit = (active_pad == i)
        local hit_boost = is_hit and 0.5 or 0.0

        lg.setColor(p.col[1] * 0.10 + hit_boost * 0.3, p.col[2] * 0.10 + hit_boost * 0.3, p.col[3] * 0.10 + hit_boost * 0.3, 0.96)
        lg.rectangle("fill", px, py, pad_w, pad_h, 4, 4)

        lg.setColor(p.col[1], p.col[2], p.col[3], is_hit and 1.0 or 0.55)
        lg.setLineWidth(is_hit and 2 or 1)
        lg.rectangle("line", px, py, pad_w, pad_h, 4, 4)

        local r_len = 8
        lg.line(px, py + r_len, px, py, px + r_len, py)
        lg.line(px + pad_w - r_len, py, px + pad_w, py, px + pad_w, py + r_len)
        lg.line(px, py + pad_h - r_len, px, py + pad_h, px + r_len, py + pad_h)
        lg.line(px + pad_w - r_len, py + pad_h, px + pad_w, py + pad_h, px + pad_w, py + pad_h - r_len)
        lg.setLineWidth(1)

        lg.setColor(1.0, 1.0, 1.0, is_hit and 1.0 or 0.7)
        lg.print(string.format("[%d]", i), px + 12, py + 12)

        lg.setColor(1.0, 1.0, 1.0, 1.0)
        lg.print(p.title, px + 40, py + 12)

        local badge_w = 120
        lg.setColor(p.col[1] * 0.25, p.col[2] * 0.25, p.col[3] * 0.25, 0.9)
        lg.rectangle("fill", px + pad_w - badge_w - 12, py + 10, badge_w, 18, 2, 2)
        lg.setColor(p.col[1], p.col[2], p.col[3], 1.0)
        lg.print(p.badge, px + pad_w - badge_w - 6, py + 12)

        lg.setColor(0.4, 0.8, 1.0, 0.9)
        lg.print("VST: " .. p.vst, px + 14, py + 46)

        lg.setColor(0.65, 0.72, 0.82, 0.8)
        lg.print(p.desc, px + 14, py + 72)

        if is_hit then
            lg.setColor(p.col[1], p.col[2], p.col[3], 0.25)
            lg.rectangle("fill", px + 2, py + 2, pad_w - 4, pad_h - 4, 3, 3)
        end
    end

    -- 6. BOTTOM TOAST
    if toast_timer > 0 then
        lg.setColor(0.0, 1.0, 0.8, math.min(1.0, toast_timer * 1.5))
        lg.print(">> " .. status_toast, 40, 656)
    end
end

return SceneSoundtrackLab
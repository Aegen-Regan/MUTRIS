-- ============================================================================
-- FILE: scenes/scene_soundtrack_lab.lua
-- MUTRIS ENGINE: MASTER CYBERPUNK SOUNDSET WORKSTATION 4.0 (Zero-GC / 1280x720)
-- TARGET: Intel Pentium G3250 Haswell / Intel HD Graphics (Zero Allocation Draw)
-- ============================================================================
---@diagnostic disable: undefined-global

local SoundManager = require("audio.sound_manager")
local SoundtrackDB = require("audio.soundtrack_db")
local OscClient    = require("network.osc_client")

local scene = {}

local VW, VH = 1280, 720

-- COLOR PALETTE (Hardware Studio Aesthetic)
local COLOR = {
    bg          = {0.020, 0.025, 0.045, 1.00},
    panel       = {0.035, 0.050, 0.085, 0.95},
    panel_top   = {0.055, 0.075, 0.120, 0.95},
    border_dim  = {0.14, 0.18, 0.26, 0.80},
    black       = {0.00, 0.00, 0.00, 0.55},

    cyan        = {0.25, 0.92, 1.00, 1.00},
    cyan_dim    = {0.10, 0.30, 0.36, 1.00},
    red         = {1.00, 0.28, 0.32, 1.00},
    red_dim     = {0.32, 0.10, 0.12, 1.00},
    green       = {0.35, 1.00, 0.58, 1.00},
    green_dim   = {0.10, 0.32, 0.20, 1.00},
    gold        = {1.00, 0.82, 0.22, 1.00},
    gold_dim    = {0.34, 0.27, 0.09, 1.00},
    purple      = {0.76, 0.48, 1.00, 1.00},
    purple_dim  = {0.24, 0.15, 0.34, 1.00},
    magenta     = {1.00, 0.32, 0.82, 1.00},
    magenta_dim = {0.34, 0.11, 0.28, 1.00},

    text        = {0.88, 0.94, 0.98, 1.00},
    text_dim    = {0.50, 0.58, 0.68, 1.00},
    text_faint  = {0.32, 0.38, 0.46, 1.00},
}

-- STATE
scene.state = {
    active_tab      = 1, -- 1: Global Tracks, 2: Story Stages (1..50)
    sel_track_idx   = 1,
    sel_stage_idx   = 1,
    danger_pct      = 0.0,
    selected_pad    = 1,
    hover_pad       = 0,
    hover_chip      = 0,
    pad_flash       = 0.0,
    status_toast    = "",
    toast_timer     = 0.0,
    is_playing      = false,
    is_recording    = false,
    mute_internal   = false,
    t               = 0.0,
}

-- PRE-ALLOCATED LED & VISUAL ENVELOPES
scene.led = {
    pad_glow    = {0,0,0,0,0,0,0,0,0},
    chip_glow   = {0,0,0,0,0,0,0,0,0,0},
    mix_glow    = {0,0,0,0},
    spectrum    = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    spec_peaks  = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
}

scene.mix = {
    mute = {false, false, false, false},
    solo = {false, false, false, false},
}

-- RUNNER FOR PENTATONIC RUN (PAD 2)
local run_active = false
local run_col    = 1
local run_timer  = 0.0

-- NOTE NAMES LOOKUP
local NOTE_NAMES = { "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" }

-- CHANNELS & PADS DEFINITIONS
local MIX_CHANNELS = {
    { label = "CH 1", sub = "BASS",    color = COLOR.red,     dim = COLOR.red_dim },
    { label = "CH 2", sub = "PLUCK",   color = COLOR.cyan,    dim = COLOR.cyan_dim },
    { label = "CH 3", sub = "LEAD",    color = COLOR.magenta, dim = COLOR.magenta_dim },
    { label = "CH 4", sub = "HARMONY", color = COLOR.gold,    dim = COLOR.gold_dim },
}

local PADS = {
    { id=1, key="01", name="HARD DROP",        chan="CH 1: BASS",   color=COLOR.red,     dim=COLOR.red_dim,     vst="VST: TB_Lowtone",            desc="Sub-Bass 40Hz Impact" },
    { id=2, key="02", name="PENTATONIC RUN",   chan="CH 2: PLUCK",  color=COLOR.cyan,    dim=COLOR.cyan_dim,    vst="VST: TB_Flowtones",          desc="10-Col Ascending Arp" },
    { id=3, key="03", name="ROTATION (5th)",   chan="CH 2: ARP",    color=COLOR.green,   dim=COLOR.green_dim,   vst="VST: TB_Flowtones",          desc="+7st Harmonic Arpeggio" },
    { id=4, key="04", name="HOLD (Sus4)",      chan="CH 2: TEXTURE",color=COLOR.purple,  dim=COLOR.purple_dim,  vst="VST: TB_Flowtones",          desc="+5st Suspended Atmosphere" },
    { id=5, key="05", name="1-LINE (TRIAD)",   chan="CH 4: HARMONY",color=COLOR.gold,    dim=COLOR.gold_dim,    vst="VST: The Grandeur / Strings",desc="Root + 3rd + 5th Chords" },
    { id=6, key="06", name="2-LINES (7th)",    chan="CH 4: HARMONY",color=COLOR.gold,    dim=COLOR.gold_dim,    vst="VST: The Grandeur / Strings",desc="Root + 3rd + 5th + 7th" },
    { id=7, key="07", name="3-LINES (9th)",    chan="CH 4: HARMONY",color=COLOR.gold,    dim=COLOR.gold_dim,    vst="VST: The Grandeur / Strings",desc="Extended 9th Tension Chord" },
    { id=8, key="08", name="TETRIS 4L",        chan="CH 1+4 HYBRID",color=COLOR.green,   dim=COLOR.green_dim,   vst="VST: Sub-Drop + Octave",     desc="Full Dynamic Explosion" },
    { id=9, key="09", name="T-SPIN (FM)",      chan="CH 3: LEAD",   color=COLOR.magenta, dim=COLOR.magenta_dim, vst="VST: Genny / Vital",         desc="High FM Lead Synth Stab" },
}

-- PRE-BAKED STRING CACHE (Zero-GC hot loop)
scene.cache = {
    key_str        = "",
    mode_str       = "",
    profile_str    = "",
    oct_str        = "",
    danger_str     = "0% [SAFE]",
    danger_atk_str = "50% [ATTACK]",
    danger_pk_str  = "100% [PEAK]",
}

local function refreshCache()
    local s = scene.state
    local is_tracks = (s.active_tab == 1)
    if is_tracks then
        local t = SoundtrackDB.tracks[s.sel_track_idx]
        scene.cache.profile_str = string.format("GLOBAL TRACK PROFILE [%d / %d]", s.sel_track_idx, #SoundtrackDB.tracks)
        local mode_idx = t and t.scale_mode_index or 1
        local cur_mode = SoundtrackDB.SCALE_MODES[mode_idx] or SoundtrackDB.SCALE_MODES[1]
        scene.cache.mode_str = cur_mode.name .. " [M]"
        local oct = t and t.octave_offset or 0
        scene.cache.oct_str = string.format("MIDI %d | OCT: %+d [O]", SoundManager.root_midi or 54, oct)
    else
        local stg, t = SoundtrackDB.get_stage_info(s.sel_stage_idx)
        scene.cache.profile_str = string.format("STORY STAGE [%02d / 50] // BESPOKE SOUNDSET", s.sel_stage_idx)
        local mode_idx = stg and stg.scale_mode_index or 1
        local cur_mode = SoundtrackDB.SCALE_MODES[mode_idx] or SoundtrackDB.SCALE_MODES[1]
        scene.cache.mode_str = cur_mode.name .. " [M]"
        local oct = stg and stg.octave_offset or 0
        scene.cache.oct_str = string.format("MIDI %d | OCT: %+d [O]", SoundManager.root_midi or 54, oct)
    end
    scene.cache.key_str = "KEY: " .. (SoundManager.current_key_name or "11A (F#m)")
end

local function applySelection()
    local s = scene.state
    if s.active_tab == 1 then
        local t = SoundtrackDB.tracks[s.sel_track_idx]
        if t then SoundManager.set_active_track(t.id) end
    else
        SoundManager.load_stage_soundset(s.sel_stage_idx)
    end
    refreshCache()
end

--================================================================
-- INITIALIZATION
--================================================================
function scene.enter()
    -- Reset del Pipeline Gráfico para eliminar el salto de pantalla
    love.graphics.origin()
    love.graphics.setShader()
    love.graphics.setBlendMode("alpha")
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)

    scene.state.active_tab    = 1
    scene.state.sel_track_idx = 1
    scene.state.sel_stage_idx = 1
    scene.state.danger_pct    = 0.0
    scene.state.status_toast  = "WORKSTATION 4.0 // REAPER DAW LINKED"
    scene.state.toast_timer   = 3.0
    run_active                = false

    SoundManager.init()
    OscClient.init("127.0.0.1", 8000)
    applySelection()
end

--================================================================
-- UPDATE LOOP (Zero-GC numeric mutation)
--================================================================
function scene.update(dt)
    local s = scene.state
    s.t = s.t + dt

    SoundManager.update(dt)
    OscClient.update(dt)

    if s.toast_timer > 0 then s.toast_timer = s.toast_timer - dt end

    -- Decay Pad Glows
    local pg = scene.led.pad_glow
    for i = 1, 9 do
        if pg[i] > 0 then pg[i] = math.max(0, pg[i] - dt * 4.0) end
    end
    local cg = scene.led.chip_glow
    for i = 1, 10 do
        if cg[i] > 0 then cg[i] = math.max(0, cg[i] - dt * 4.0) end
    end
    local mg = scene.led.mix_glow
    for i = 1, 4 do
        if mg[i] > 0 then mg[i] = math.max(0, mg[i] - dt * 3.0) end
    end

    -- 24-Band Spectrum Animation with Peak-Hold
    local spec = scene.led.spectrum
    local pks  = scene.led.spec_peaks
    local pulse = _G.AudioBeatPulse or 0.0
    for b = 1, 24 do
        if pulse > 0.01 then
            local target = math.min(1.0, pulse * (1.2 - (b * 0.03)) + (math.random() * 0.28))
            spec[b] = math.max(spec[b], target)
        end
        spec[b] = math.max(0.0, spec[b] - dt * (2.2 + b * 0.08))
        if spec[b] > pks[b] then
            pks[b] = spec[b]
        else
            pks[b] = math.max(0.0, pks[b] - dt * 0.8)
        end
    end

    -- Pentatonic Scale Runner (Pad 2)
    if run_active then
        run_timer = run_timer - dt
        if run_timer <= 0 then
            SoundManager.play_move_column(run_col)
            scene.led.chip_glow[run_col] = 1.0
            scene.led.mix_glow[2] = 1.0
            spec[math.min(24, math.floor(run_col * 2.3))] = 1.0
            run_col = run_col + 1
            run_timer = 0.055
            if run_col > 10 then run_active = false; run_col = 1 end
        end
    end
end

--================================================================
-- ACTION DISPATCHERS
--================================================================
local function triggerPad(idx)
    local s = scene.state
    s.selected_pad = idx
    scene.led.pad_glow[idx] = 1.0
    
    local pad = PADS[idx]
    if pad and pad.id == 1 then scene.led.mix_glow[1] = 1.0
    elseif pad and (pad.id >= 2 and pad.id <= 4) then scene.led.mix_glow[2] = 1.0
    elseif pad and pad.id == 9 then scene.led.mix_glow[3] = 1.0
    else scene.led.mix_glow[4] = 1.0 end
    if idx == 8 then scene.led.mix_glow[1] = 1.0; scene.led.mix_glow[4] = 1.0 end

    for b = 1, 8 do scene.led.spectrum[b + (idx % 12)] = 1.0 end

    if idx == 1 then
        SoundManager.play_hard_drop()
    elseif idx == 2 then
        run_active = true; run_col = 1; run_timer = 0.0
    elseif idx == 3 then
        SoundManager.play_rotate(5)
    elseif idx == 4 then
        SoundManager.play_hold()
    elseif idx == 5 then
        SoundManager.play_line_clear(1)
    elseif idx == 6 then
        SoundManager.play_line_clear(2)
    elseif idx == 7 then
        SoundManager.play_line_clear(3)
    elseif idx == 8 then
        SoundManager.play_line_clear(4)
    elseif idx == 9 then
        SoundManager.play_tspin()
    end
end

local function auditionChip(col)
    scene.led.chip_glow[col] = 1.0
    scene.led.mix_glow[2]    = 1.0
    SoundManager.play_move_column(col)
    scene.led.spectrum[math.min(24, math.floor(col * 2.3))] = 1.0
end

local function setDanger(pct)
    local s = scene.state
    s.danger_pct = math.max(0, math.min(100, pct))
    OscClient.send_danger(s.danger_pct / 100.0)
    s.status_toast = string.format("DANGER FILTER: %d%%", math.floor(s.danger_pct))
    s.toast_timer = 1.0
end

--================================================================
-- INPUT HANDLING
--================================================================
function scene.keypressed(key)
    local s = scene.state

    -- MODE SWITCH (TAB)
    if key == "tab" then
        s.active_tab = (s.active_tab == 1) and 2 or 1
        applySelection()
        s.status_toast = (s.active_tab == 1) and "VIEW: GLOBAL TRACKS" or "VIEW: STORY STAGE BUILDER"
        s.toast_timer = 1.5
        return
    end

    -- MUTE INTERNAL SFX (I)
    if key == "i" then
        s.mute_internal = not s.mute_internal
        SoundManager.sfx_enabled = not s.mute_internal
        s.status_toast = s.mute_internal and "INTERNAL AUDIO: MUTED (REAPER ONLY)" or "INTERNAL AUDIO: ACTIVE"
        s.toast_timer = 2.0
        return
    end

    -- DAW TRANSPORT (P / SPACE: Play, R: Record)
    if key == "p" or key == "space" then
        s.is_playing = not s.is_playing
        if s.is_playing then OscClient.transport_play(); s.status_toast = "REAPER: >> PLAYING <<"
        else OscClient.transport_stop(); s.status_toast = "REAPER: [] STOPPED" end
        s.toast_timer = 1.5
        return
    elseif key == "r" then
        s.is_recording = not s.is_recording
        OscClient.transport_record()
        s.status_toast = s.is_recording and "REAPER: ● RECORDING ACTIVE" or "REAPER: RECORD OFF"
        s.toast_timer = 2.0
        return
    end

    -- TRACK / STAGE PARAMS
    if s.active_tab == 1 then
        local t = SoundtrackDB.tracks[s.sel_track_idx]
        if key == "up" then
            s.sel_track_idx = ((s.sel_track_idx - 2 + #SoundtrackDB.tracks) % #SoundtrackDB.tracks) + 1
            applySelection()
        elseif key == "down" then
            s.sel_track_idx = (s.sel_track_idx % #SoundtrackDB.tracks) + 1
            applySelection()
        elseif key == "left" and t then
            t.camelot_index = ((t.camelot_index - 2 + #SoundtrackDB.CAMELOT_KEYS) % #SoundtrackDB.CAMELOT_KEYS) + 1
            applySelection()
        elseif key == "right" and t then
            t.camelot_index = (t.camelot_index % #SoundtrackDB.CAMELOT_KEYS) + 1
            applySelection()
        elseif key == "m" and t then
            t.scale_mode_index = (t.scale_mode_index % #SoundtrackDB.SCALE_MODES) + 1
            applySelection()
        elseif key == "o" and t then
            t.octave_offset = ((t.octave_offset + 2) % 3) - 1
            applySelection()
        elseif key == "g" and t then
            t.scale_mode_index = math.random(1, #SoundtrackDB.SCALE_MODES)
            t.octave_offset = math.random(-1, 1)
            applySelection()
            s.status_toast = "HARMONIC SOUNDSET GENERATED!"
            s.toast_timer = 1.5
        end
    else
        local stg = SoundtrackDB.stages[s.sel_stage_idx]
        if key == "up" then
            s.sel_stage_idx = ((s.sel_stage_idx - 2 + #SoundtrackDB.stages) % #SoundtrackDB.stages) + 1
            applySelection()
        elseif key == "down" then
            s.sel_stage_idx = (s.sel_stage_idx % #SoundtrackDB.stages) + 1
            applySelection()
        elseif key == "t" and stg then
            stg.track_index = (stg.track_index % #SoundtrackDB.tracks) + 1
            applySelection()
        elseif key == "left" and stg then
            stg.camelot_index = ((stg.camelot_index - 2 + #SoundtrackDB.CAMELOT_KEYS) % #SoundtrackDB.CAMELOT_KEYS) + 1
            applySelection()
        elseif key == "right" and stg then
            stg.camelot_index = (stg.camelot_index % #SoundtrackDB.CAMELOT_KEYS) + 1
            applySelection()
        elseif key == "m" and stg then
            stg.scale_mode_index = (stg.scale_mode_index % #SoundtrackDB.SCALE_MODES) + 1
            applySelection()
        elseif key == "o" and stg then
            stg.octave_offset = ((stg.octave_offset + 2) % 3) - 1
            applySelection()
        elseif key == "g" and stg then
            stg.track_index = math.random(1, #SoundtrackDB.tracks)
            stg.scale_mode_index = math.random(1, #SoundtrackDB.SCALE_MODES)
            stg.octave_offset = math.random(-1, 1)
            applySelection()
            s.status_toast = "STAGE SOUNDSET GENERATED!"
            s.toast_timer = 1.5
        end
    end

    -- DANGER (D / F)
    if key == "d" then setDanger(s.danger_pct - 10)
    elseif key == "f" then setDanger(s.danger_pct + 10)

    -- PADS 1..9
    elseif key == "1" then triggerPad(1)
    elseif key == "2" then triggerPad(2)
    elseif key == "3" then triggerPad(3)
    elseif key == "4" then triggerPad(4)
    elseif key == "5" then triggerPad(5)
    elseif key == "6" then triggerPad(6)
    elseif key == "7" then triggerPad(7)
    elseif key == "8" then triggerPad(8)
    elseif key == "9" then triggerPad(9)

    -- SAVE (S)
    elseif key == "s" then
        SoundtrackDB.save()
        s.status_toast = "CONFIG SAVED PERMANENTLY (soundtrack_config.json)"
        s.toast_timer = 2.5
        SoundManager.play_hard_drop()

    -- EXIT TO MENU (SAFE ROBUST TRANSITION)
    elseif key == "escape" then
        local ok, sm = pcall(require, "core.scene_manager")
        if not ok or not sm then ok, sm = pcall(require, "scene_manager") end
        if not ok or not sm then sm = _G.SceneManager end
        if sm and sm.setState then sm.setState("menu")
        elseif sm and sm.switch then sm.switch("menu")
        elseif sm and sm.changeScene then sm.changeScene("scene_menu") end
    end
end

function scene.mousepressed(x, y, button)
    if button ~= 1 then return end
    local s = scene.state

    -- Tabs
    if x >= 40 and x <= 270 and y >= 58 and y <= 88 then
        s.active_tab = 1; applySelection(); return
    end
    if x >= 280 and x <= 560 and y >= 58 and y <= 88 then
        s.active_tab = 2; applySelection(); return
    end

    -- Transport Buttons
    if y >= 58 and y <= 88 then
        if x >= 580 and x <= 660 then
            s.is_playing = not s.is_playing
            if s.is_playing then OscClient.transport_play(); s.status_toast = "REAPER: >> PLAY"
            else OscClient.transport_stop(); s.status_toast = "REAPER: [] STOP" end
            s.toast_timer = 1.5; return
        elseif x >= 670 and x <= 745 then
            s.is_recording = not s.is_recording
            OscClient.transport_record()
            s.status_toast = s.is_recording and "REAPER: ● RECORD ACTIVE" or "REAPER: RECORD OFF"
            s.toast_timer = 2.0; return
        end
    end

    -- Channel Mute/Solo
    if y >= 58 and y <= 88 and x >= 760 and x <= 1240 then
        for ch = 1, 4 do
            local bx = 760 + (ch - 1) * 120
            if x >= bx + 16 and x <= bx + 60 then
                scene.mix.mute[ch] = not scene.mix.mute[ch]
                OscClient.toggle_track_mute(ch, scene.mix.mute[ch])
                s.status_toast = string.format("CH %d MUTE: %s", ch, scene.mix.mute[ch] and "ON" or "OFF")
                s.toast_timer = 1.0; return
            elseif x >= bx + 64 and x <= bx + 108 then
                scene.mix.solo[ch] = not scene.mix.solo[ch]
                OscClient.toggle_track_solo(ch, scene.mix.solo[ch])
                s.status_toast = string.format("CH %d SOLO: %s", ch, scene.mix.solo[ch] and "ON" or "OFF")
                s.toast_timer = 1.0; return
            end
        end
    end

    -- 50-Stage Matrix (Mode 2)
    if s.active_tab == 2 and x >= 55 and x <= 605 and y >= 115 and y <= 215 then
        local grid_w, grid_h = 52, 18
        local gap_x, gap_y = 3, 2
        for st = 1, 50 do
            local col = (st - 1) % 10
            local row = math.floor((st - 1) / 10)
            local bx = 55 + col * (grid_w + gap_x)
            local by = 124 + row * (grid_h + gap_y)
            if x >= bx and x <= bx + grid_w and y >= by and y <= by + grid_h then
                s.sel_stage_idx = st
                applySelection()
                s.status_toast = string.format("LOADED: STAGE %02d", st)
                s.toast_timer = 1.2; return
            end
        end
    end

    -- DNA Chips (Mode 1)
    if s.active_tab == 1 and x >= 55 and x <= 605 and y >= 190 and y <= 224 then
        local chip_w, chip_h, chip_gap = 50, 24, 6
        for c = 1, 10 do
            local cx = 55 + (c - 1) * (chip_w + chip_gap)
            if x >= cx and x <= cx + chip_w and y >= 194 and y <= 194 + chip_h then
                auditionChip(c); return
            end
        end
    end

    -- Danger Slider
    if x >= 660 and x <= 1240 and y >= 98 and y <= 236 then
        if y >= 140 and y <= 174 then
            local rel_x = math.max(0.0, math.min(1.0, (x - 675) / 550))
            setDanger(rel_x * 100)
            return
        end
    end

    -- Audition Pads 1..9
    local start_x, start_y = 40, 245
    local pad_w, pad_h = 386, 122
    local gap_x, gap_y = 20, 16
    for i = 1, 9 do
        local row = math.floor((i - 1) / 3)
        local col = (i - 1) % 3
        local px = start_x + col * (pad_w + gap_x)
        local py = start_y + row * (pad_h + gap_y)
        if x >= px and x <= px + pad_w and y >= py and y <= py + pad_h then
            triggerPad(i); return
        end
    end
end

--================================================================
-- DRAW HELPERS
--================================================================
local function setColor(c) love.graphics.setColor(c[1], c[2], c[3], c[4]) end

local function drawPanelFrame(x, y, w, h, border, filled)
    if filled then
        setColor(COLOR.panel)
        love.graphics.rectangle("fill", x, y, w, h, 4, 4)
    end
    setColor(border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h, 4, 4)
    local b_len = 8
    love.graphics.setLineWidth(2)
    love.graphics.line(x, y + b_len, x, y, x + b_len, y)
    love.graphics.line(x + w - b_len, y, x + w, y, x + w, y + b_len)
    love.graphics.line(x, y + h - b_len, x, y + h, x + b_len, y + h)
    love.graphics.line(x + w - b_len, y + h, x + w, y + h, x + w, y + h - b_len)
    love.graphics.setLineWidth(1)
end

local function drawLED(x, y, r, color, glow)
    setColor(color)
    love.graphics.circle("fill", x, y, r)
    if glow > 0.05 then
        love.graphics.setColor(color[1], color[2], color[3], 0.35 * glow)
        love.graphics.circle("fill", x, y, r * 2.2 * glow)
    end
end

--================================================================
-- DRAW MAIN RENDER LOOP
--================================================================
function scene.draw()
    local lg = love.graphics
    local s  = scene.state

    -- RESET COMPLETO DE PIPELINE GRÁFICO (Elimina el salto de coordenadas)
    lg.origin()
    lg.setShader()
    lg.setBlendMode("alpha")
    lg.setLineWidth(1)
    lg.setColor(1, 1, 1, 1)

    -- Background
    setColor(COLOR.bg)
    lg.rectangle("fill", 0, 0, VW, VH)

    -- 1. Top Header
    setColor(COLOR.cyan)
    lg.rectangle("fill", 40, 12, 1200, 2)
    lg.print("MUTRIS", 45, 18)
    setColor(COLOR.text)
    lg.print(" // PRO SINESTESIA WORKSTATION 4.0", 95, 18)
    setColor(COLOR.text_dim)
    lg.print("[TAB] Mode  [UP/DN] Select  [LT/RT] Key  [M] Mode  [O] Oct  [I] Mute SFX  [P] Play  [R] Rec  [S] Save  [ESC] Exit", 45, 36)

    -- 2. Mode Selector Tabs & DAW Mixer
    local is_tracks = (s.active_tab == 1)
    
    -- Tab 1
    setColor(is_tracks and COLOR.panel_top or COLOR.panel)
    lg.rectangle("fill", 40, 58, 230, 30, 4, 4)
    setColor(is_tracks and COLOR.cyan or COLOR.border_dim)
    lg.setLineWidth(is_tracks and 2 or 1)
    lg.rectangle("line", 40, 58, 230, 30, 4, 4)
    setColor(is_tracks and COLOR.cyan or COLOR.text_dim)
    lg.print(is_tracks and "[ 1 ] GLOBAL TRACKS" or "  [ 1 ] GLOBAL TRACKS", 50, 65)

    -- Tab 2
    setColor(not is_tracks and COLOR.panel_top or COLOR.panel)
    lg.rectangle("fill", 280, 58, 280, 30, 4, 4)
    setColor(not is_tracks and COLOR.magenta or COLOR.border_dim)
    lg.setLineWidth(not is_tracks and 2 or 1)
    lg.rectangle("line", 280, 58, 280, 30, 4, 4)
    setColor(not is_tracks and COLOR.magenta or COLOR.text_dim)
    lg.print(not is_tracks and "[ 2 ] STORY STAGES (1..50)" or "  [ 2 ] STORY STAGE BUILDER", 295, 65)
    lg.setLineWidth(1)

    -- Transport Play/Stop
    setColor(s.is_playing and COLOR.green_dim or COLOR.panel)
    lg.rectangle("fill", 580, 58, 80, 30, 3, 3)
    setColor(s.is_playing and COLOR.green or COLOR.border_dim)
    lg.rectangle("line", 580, 58, 80, 30, 3, 3)
    setColor(s.is_playing and COLOR.green or COLOR.text)
    if s.is_playing then
        lg.polygon("fill", 595, 66, 595, 80, 608, 73)
        lg.print("PLAY", 615, 65)
    else
        lg.rectangle("fill", 595, 66, 13, 13, 1, 1)
        lg.print("STOP", 615, 65)
    end

    -- Transport Record
    setColor(s.is_recording and COLOR.red_dim or COLOR.panel)
    lg.rectangle("fill", 670, 58, 75, 30, 3, 3)
    setColor(s.is_recording and COLOR.red or COLOR.border_dim)
    lg.rectangle("line", 670, 58, 75, 30, 3, 3)
    drawLED(688, 73, 5, COLOR.red, s.is_recording and (0.6 + 0.4 * math.sin(s.t * 8)) or 0)
    setColor(s.is_recording and COLOR.red or COLOR.text)
    lg.print("REC", 702, 65)

    -- Channel Mixer Strips (CH 1..4)
    for ch = 1, 4 do
        local bx = 760 + (ch - 1) * 120
        local chan = MIX_CHANNELS[ch]
        setColor(COLOR.panel)
        lg.rectangle("fill", bx, 58, 114, 30, 2, 2)
        setColor(chan.dim)
        lg.rectangle("line", bx, 58, 114, 30, 2, 2)

        drawLED(bx + 8, 73, 3, chan.color, scene.led.mix_glow[ch])

        -- Mute
        local is_m = scene.mix.mute[ch]
        setColor(is_m and COLOR.red or COLOR.panel_top)
        lg.rectangle("fill", bx + 16, 61, 44, 24, 2, 2)
        setColor(is_m and COLOR.red or COLOR.border_dim)
        lg.rectangle("line", bx + 16, 61, 44, 24, 2, 2)
        setColor(is_m and COLOR.black or COLOR.text)
        lg.print("M", bx + 33, 65)

        -- Solo
        local is_s = scene.mix.solo[ch]
        setColor(is_s and COLOR.gold or COLOR.panel_top)
        lg.rectangle("fill", bx + 64, 61, 44, 24, 2, 2)
        setColor(is_s and COLOR.gold or COLOR.border_dim)
        lg.rectangle("line", bx + 64, 61, 44, 24, 2, 2)
        setColor(is_s and COLOR.black or COLOR.text)
        lg.print("S", bx + 82, 65)
    end

    -- 3. Left Card: Harmonic DNA or 50 Stages
    drawPanelFrame(40, 98, 580, 138, is_tracks and COLOR.cyan_dim or COLOR.magenta_dim, true)

    if is_tracks then
        local t = SoundtrackDB.tracks[s.sel_track_idx]
        setColor(COLOR.text_dim)
        lg.print(scene.cache.profile_str, 55, 106)
        setColor(COLOR.text)
        lg.print(t and t.name or "N/A", 55, 122)

        -- Pills
        setColor(COLOR.cyan_dim)
        lg.rectangle("fill", 55, 142, 130, 20, 3, 3)
        setColor(COLOR.cyan)
        lg.print(scene.cache.key_str, 62, 145)

        setColor(COLOR.gold_dim)
        lg.rectangle("fill", 195, 142, 210, 20, 3, 3)
        setColor(COLOR.gold)
        lg.print(scene.cache.mode_str, 202, 145)

        setColor(COLOR.purple_dim)
        lg.rectangle("fill", 415, 142, 190, 20, 3, 3)
        setColor(COLOR.purple)
        lg.print(scene.cache.oct_str, 422, 145)

        -- DNA Chips
        setColor(COLOR.text_dim)
        lg.print("PENTATONIC SCALE DNA (CLICK TO AUDITION NOTE):", 55, 170)

        local chip_x, chip_y, chip_w, chip_h, gap = 55, 190, 50, 26, 6
        for c = 1, 10 do
            local st = SoundManager.active_intervals and SoundManager.active_intervals[c] or 0
            local note_num = (SoundManager.root_midi or 54) + st
            local note_idx = (note_num % 12) + 1
            local note_txt = NOTE_NAMES[note_idx] or "??"
            local cx = chip_x + (c - 1) * (chip_w + gap)

            local glow = scene.led.chip_glow[c]
            local is_root = (c == 1 or c == 6)

            setColor(is_root and COLOR.cyan_dim or COLOR.panel_top)
            lg.rectangle("fill", cx, chip_y, chip_w, chip_h, 3, 3)

            if glow > 0.05 then
                lg.setColor(COLOR.cyan[1], COLOR.cyan[2], COLOR.cyan[3], glow)
            else
                setColor(is_root and COLOR.cyan or COLOR.border_dim)
            end
            lg.rectangle("line", cx, chip_y, chip_w, chip_h, 3, 3)

            setColor(is_root and COLOR.cyan or COLOR.text)
            lg.print(note_txt, cx + 8, chip_y + 4)
            setColor(COLOR.text_faint)
            lg.print(string.format("%02d", c), cx + chip_w - 18, chip_y + 11)
        end
    else
        -- 50 Stages Grid
        local stg, t = SoundtrackDB.get_stage_info(s.sel_stage_idx)
        setColor(COLOR.magenta)
        lg.print(scene.cache.profile_str, 55, 104)
        setColor(COLOR.green)
        lg.print("SONG: " .. (t and t.name or "") .. "  [Key 'T']", 340, 104)

        local grid_w, grid_h = 52, 18
        local gap_x, gap_y = 3, 2
        for st = 1, 50 do
            local col = (st - 1) % 10
            local row = math.floor((st - 1) / 10)
            local bx = 55 + col * (grid_w + gap_x)
            local by = 124 + row * (grid_h + gap_y)

            local is_sel = (st == s.sel_stage_idx)
            local is_boss = (st == 50)
            local is_colossus = (st % 10 == 0 and st ~= 50)

            if is_sel then setColor(COLOR.cyan)
            elseif is_boss then setColor(COLOR.red)
            elseif is_colossus then setColor(COLOR.gold)
            else setColor(COLOR.panel_top) end
            lg.rectangle("fill", bx, by, grid_w, grid_h, 2, 2)

            setColor(is_sel and COLOR.black or COLOR.text)
            lg.print(string.format("%02d", st), bx + 16, by + 2)
        end
    end

    -- 4. Right Card: Danger & Spectrum
    drawPanelFrame(660, 98, 580, 138, COLOR.red_dim, true)
    setColor(COLOR.red)
    lg.print("REAPER DANGER MODULATOR (/mutris/danger)", 675, 106)
    setColor(COLOR.text_faint)
    lg.print("[D] -10%  |  [F] +10%  (Or Drag Fader)", 675, 122)

    -- Telemetry
    setColor(COLOR.green_dim)
    lg.rectangle("fill", 985, 104, 240, 20, 3, 3)
    setColor(COLOR.green)
    lg.print(OscClient.get_telemetry(), 992, 107)

    -- Danger Fader Rail
    local gauge_x, gauge_y, gauge_w, gauge_h = 675, 144, 550, 18
    setColor(COLOR.panel_top)
    lg.rectangle("fill", gauge_x, gauge_y, gauge_w, gauge_h, 2, 2)
    setColor(COLOR.border_dim)
    lg.rectangle("line", gauge_x, gauge_y, gauge_w, gauge_h, 2, 2)

    local segs = 32
    local active_segs = math.floor(s.danger_pct / 100 * segs)
    local seg_w = (gauge_w - (segs - 1) * 2) / segs
    for i = 1, segs do
        local sx = gauge_x + (i - 1) * (seg_w + 2)
        local ratio = i / segs
        if i <= active_segs then
            if ratio < 0.45 then setColor(COLOR.cyan)
            elseif ratio < 0.75 then setColor(COLOR.gold)
            else setColor(COLOR.red) end
            lg.rectangle("fill", sx, gauge_y + 2, seg_w, gauge_h - 4)
        else
            setColor(COLOR.panel)
            lg.rectangle("fill", sx, gauge_y + 2, seg_w, gauge_h - 4)
        end
    end

    setColor(COLOR.cyan)
    lg.print(scene.cache.danger_str, gauge_x, gauge_y + 20)
    setColor(COLOR.gold)
    lg.print(scene.cache.danger_atk_str, gauge_x + gauge_w * 0.45, gauge_y + 20)
    setColor(COLOR.red)
    lg.print(scene.cache.danger_pk_str, gauge_x + gauge_w - 75, gauge_y + 20)

    -- 24-Band Spectrum Analyzer
    local spec_x, spec_y, spec_w, spec_h = 675, 192, 550, 28
    local bar_w = (spec_w - 23 * 2) / 24
    for b = 1, 24 do
        local bx = spec_x + (b - 1) * (bar_w + 2)
        local lvl = math.max(0.05, scene.led.spectrum[b])
        local bh = spec_h * lvl
        local by = spec_y + spec_h - bh

        local ratio = b / 24
        if ratio < 0.5 then setColor(COLOR.cyan) else setColor(COLOR.magenta) end
        lg.rectangle("fill", bx, by, bar_w, bh, 1, 1)

        local pk = scene.led.spec_peaks[b] or 0.0
        if pk > 0.05 then
            local pky = spec_y + spec_h - (spec_h * pk)
            setColor(COLOR.text)
            lg.rectangle("fill", bx, pky - 1, bar_w, 2)
        end
    end

    -- 5. 3x3 Sound Matrix (Hardware Launchpad Grid)
    local start_x, start_y = 40, 245
    local pad_w, pad_h = 386, 122
    local gap_x, gap_y = 20, 16

    for i = 1, 9 do
        local p = PADS[i]
        local row = math.floor((i - 1) / 3)
        local col = (i - 1) % 3
        local px = start_x + col * (pad_w + gap_x)
        local py = start_y + row * (pad_h + gap_y)

        local glow = scene.led.pad_glow[i]
        local is_sel = (s.selected_pad == i)

        setColor(COLOR.panel)
        lg.rectangle("fill", px, py, pad_w, pad_h, 4, 4)

        -- Top Neon Bar
        setColor(p.color)
        lg.rectangle("fill", px + 4, py + 2, pad_w - 8, 3, 1, 1)

        -- Neon Rim
        if glow > 0.05 then
            lg.setColor(p.color[1], p.color[2], p.color[3], math.min(1, 0.4 + glow))
            lg.setLineWidth(2)
        elseif is_sel then
            setColor(p.color)
            lg.setLineWidth(2)
        else
            setColor(p.dim)
            lg.setLineWidth(1)
        end
        lg.rectangle("line", px, py, pad_w, pad_h, 4, 4)
        lg.setLineWidth(1)

        -- Title & Key
        setColor(COLOR.text_dim)
        lg.print(string.format("[%s]", p.key), px + 12, py + 14)
        setColor(COLOR.text)
        lg.print(p.name, px + 46, py + 14)

        -- Channel Badge
        local badge_w = 124
        setColor(p.dim)
        lg.rectangle("fill", px + pad_w - badge_w - 12, py + 12, badge_w, 18, 2, 2)
        setColor(p.color)
        lg.print(p.chan, px + pad_w - badge_w - 6, py + 14)

        -- VST Target & Description
        setColor(COLOR.cyan)
        lg.print(p.vst, px + 14, py + 52)
        setColor(COLOR.text_dim)
        lg.print(p.desc, px + 14, py + 78)

        if glow > 0.05 then
            lg.setColor(p.color[1], p.color[2], p.color[3], 0.20 * glow)
            lg.rectangle("fill", px + 2, py + 2, pad_w - 4, pad_h - 4, 3, 3)
        end
    end

    -- 6. Toast Feedback
    if s.toast_timer > 0 then
        setColor(COLOR.green)
        lg.print(">> " .. s.status_toast, 40, 656)
    end
end

-- Export scene with standard LÖVE2D lifecycle methods
scene.load          = scene.enter
scene.mousemoved    = function(x, y) end
scene.mousereleased = function(x, y, button) end

return scene
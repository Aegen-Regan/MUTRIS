-- ============================================================================
-- FILE: network/osc_client.lua
-- MUTRIS ENGINE: 4-CHANNEL MULTI-TIMBRAL REAPER MIDI & OSC CLIENT (Zero-GC)
-- TARGET: Intel Pentium G3250 Haswell / Multi-Track VST Performance
-- ============================================================================
---@diagnostic disable: undefined-global

local socket = require("socket")
local OscClient = {}

local HOST = "127.0.0.1"
local PORT = 8000

local udp = nil
local is_connected = false
local packet_count = 0

-- BINARY OSC CONSTANTS
local VEL_ON_BYTES  = string.char(0x3F, 0x80, 0x00, 0x00) -- Float 1.0 (Note ON)
local VEL_OFF_BYTES = string.char(0x00, 0x00, 0x00, 0x00) -- Float 0.0 (Note OFF)
local TYPETAG_FLOAT = ",f\0\0"

-- PRE-BAKED MULTI-CHANNEL MIDI PACKETS (Channels 0..3, Notes 20..100)
-- REAPER VKB Namespace: /vkb_midi/<channel_0_indexed>/note/<note_id>
local NOTE_ON_PKTS  = {} -- [ch][note]
local NOTE_OFF_PKTS = {} -- [ch][note]

local function build_vkb_pkt(ch, note_num, vel_bytes)
    local addr = string.format("/vkb_midi/%d/note/%d", ch, note_num)
    local pad = (4 - (#addr % 4)) % 4
    if pad == 0 then pad = 4 end
    addr = addr .. string.rep("\0", pad)
    return addr .. TYPETAG_FLOAT .. vel_bytes
end

for ch = 0, 3 do
    NOTE_ON_PKTS[ch]  = {}
    NOTE_OFF_PKTS[ch] = {}
    for note = 20, 100 do
        NOTE_ON_PKTS[ch][note]  = build_vkb_pkt(ch, note, VEL_ON_BYTES)
        NOTE_OFF_PKTS[ch][note] = build_vkb_pkt(ch, note, VEL_OFF_BYTES)
    end
end

-- CUSTOM OSC HEADERS
local OSC_DROP_CUSTOM   = "/mutris/drop\0\0\0\0,\0\0\0"
local OSC_TSPIN_CUSTOM  = "/mutris/tspin\0\0\0,\0\0\0"
local OSC_TETRIS_CUSTOM = "/mutris/tetris\0\0,\0\0\0"
local OSC_DANGER_HEADER = "/mutris/danger\0\0,f\0\0"

-- NOTE-OFF SCHEDULER QUEUE (Zero-GC Ring Buffer, 48 slots for 4-channel chords)
local MAX_QUEUE = 48
local queue_ch    = {}
local queue_note  = {}
local queue_timer = {}
local queue_count = 0

for i = 1, MAX_QUEUE do
    queue_ch[i]    = 0
    queue_note[i]  = 0
    queue_timer[i] = 0.0
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================
function OscClient.init(target_host, target_port)
    HOST = target_host or HOST
    PORT = target_port or PORT

    udp = socket.udp()
    if udp then
        udp:settimeout(0)
        local success = udp:setpeername(HOST, PORT)
        is_connected = success and true or false
        packet_count = 0
        queue_count = 0
    end
end

-- ============================================================================
-- MULTI-CHANNEL NOTE DISPATCH & RETRIGGERING (Zero-GC)
-- ============================================================================
local function trigger_note(ch, note_num, duration)
    if not is_connected or not udp or not NOTE_ON_PKTS[ch] then return end
    local on_pkt  = NOTE_ON_PKTS[ch][note_num]
    local off_pkt = NOTE_OFF_PKTS[ch][note_num]

    if on_pkt and off_pkt then
        -- 1. Voice Envelope Retrigger
        udp:send(off_pkt)
        -- 2. Note On
        udp:send(on_pkt)
        packet_count = packet_count + 2

        -- 3. Enqueue Note-Off
        if queue_count < MAX_QUEUE then
            queue_count = queue_count + 1
            queue_ch[queue_count]    = ch
            queue_note[queue_count]  = note_num
            queue_timer[queue_count] = duration or 0.08
        end
    end
end

-- ============================================================================
-- MULTI-TIMBRAL GAMEPLAY DISPATCHERS
-- ============================================================================

-- CH 0 | MIDI Ch 1: BASS (`TB_Lowtone`)
function OscClient.send_drop(midi_note)
    if not is_connected or not udp then return end
    udp:send(OSC_DROP_CUSTOM)
    packet_count = packet_count + 1
    trigger_note(0, midi_note or 42, 0.09)
end

function OscClient.send_tetris(midi_note)
    if not is_connected or not udp then return end
    udp:send(OSC_TETRIS_CUSTOM)
    packet_count = packet_count + 1
    trigger_note(0, midi_note or 30, 0.28) -- MIDI Ch 1 Sub Drop
end
OscClient.send_tetris_bass = OscClient.send_tetris -- Safety alias

-- CH 1 | MIDI Ch 2: PLUCKS & ARPS (`TB_Flowtones`)
function OscClient.send_move_pentatonic(midi_note)
    trigger_note(1, midi_note, 0.05)
end

function OscClient.send_rotate_note(midi_note)
    trigger_note(1, midi_note, 0.07)
end

function OscClient.send_hold_note(midi_note)
    trigger_note(1, midi_note, 0.12)
end

-- CH 2 | MIDI Ch 3: FM / LEAD (`Genny` / `Vital`)
function OscClient.send_tspin(midi_note)
    if not is_connected or not udp then return end
    udp:send(OSC_TSPIN_CUSTOM)
    packet_count = packet_count + 1
    trigger_note(2, midi_note or 66, 0.16)
end

-- CH 3 | MIDI Ch 4: CHORDS (`TB_Flowtones` / `Pocket Strings`)
function OscClient.send_chord(notes_array, duration)
    if not is_connected or not udp or not notes_array then return end
    local dur = duration or 0.22
    for i = 1, #notes_array do
        trigger_note(3, notes_array[i], dur)
    end
end

function OscClient.send_camelot(key_id) end -- Reserved for key sync

-- ============================================================================
-- CONTINUOUS DANGER LEVEL OSC [0.0 = safe, 1.0 = top-out]
-- ============================================================================
local last_sent_danger = -1.0

local function pack_float32_be(val)
    if val <= 0.0 then return string.char(0x00, 0x00, 0x00, 0x00) end
    if val >= 1.0 then return string.char(0x3F, 0x80, 0x00, 0x00) end
    local mantissa = math.floor(val * 8388608)
    local b1 = 0x3F
    local b2 = math.floor(mantissa / 65536) % 128
    local b3 = math.floor(mantissa / 256) % 256
    local b4 = mantissa % 256
    return string.char(b1, b2, b3, b4)
end

function OscClient.send_danger(normalized_val)
    if not is_connected or not udp then return end
    local clamped = math.max(0.0, math.min(1.0, normalized_val))
    if math.abs(clamped - last_sent_danger) >= 0.02 then
        last_sent_danger = clamped
        udp:send(OSC_DANGER_HEADER .. pack_float32_be(clamped))
        packet_count = packet_count + 1
    end
end

-- ============================================================================
-- UPDATE: FLUSH EXPIRED NOTE-OFFS (Zero-GC Swap-Back O(1))
-- ============================================================================
function OscClient.update(dt)
    if queue_count == 0 or not is_connected or not udp then return end

    local i = 1
    while i <= queue_count do
        queue_timer[i] = queue_timer[i] - dt
        if queue_timer[i] <= 0.0 then
            local ch   = queue_ch[i]
            local note = queue_note[i]
            local off_pkt = NOTE_OFF_PKTS[ch] and NOTE_OFF_PKTS[ch][note]
            if off_pkt then
                udp:send(off_pkt)
                packet_count = packet_count + 1
            end

            local last = queue_count
            if i ~= last then
                queue_ch[i]    = queue_ch[last]
                queue_note[i]  = queue_note[last]
                queue_timer[i] = queue_timer[last]
            end
            queue_count = queue_count - 1
        else
            i = i + 1
        end
    end
end

-- ============================================================================
-- TELEMETRY
-- ============================================================================
function OscClient.get_telemetry()
    if is_connected then
        return string.format("OSC_NET: CONNECTED [%s:%d | TX:%d]", HOST, PORT, packet_count)
    else
        return "OSC_NET: DISCONNECTED"
    end
end

function OscClient.is_active() return is_connected end

return OscClient
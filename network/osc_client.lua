-- ============================================================================
-- FILE: network/osc_client.lua
-- MUTRIS ENGINE: REAPER VIRTUAL MIDI KEYBOARD (VKB) OSC CLIENT (Zero-GC)
-- TARGET: Intel Pentium G3250 Haswell / REAPER VST Live Performance
-- ============================================================================
---@diagnostic disable: undefined-global

local socket = require("socket")
local OscClient = {}

local HOST = "127.0.0.1"
local PORT = 8000

local udp = nil
local is_connected = false
local packet_count = 0

-- BINARY CONSTANTS
local VEL_ON_BYTES  = string.char(0x3F, 0x80, 0x00, 0x00) -- Float32: 1.0
local VEL_OFF_BYTES = string.char(0x00, 0x00, 0x00, 0x00) -- Float32: 0.0
local TYPETAG_FLOAT = ",f\0\0"

-- PRE-BAKED MIDI NOTE PACKETS (Notes 20 to 100)
local NOTE_ON_PACKETS  = {}
local NOTE_OFF_PACKETS = {}

local function build_vkb_packet(note_num, vel_bytes)
    local addr = string.format("/vkb_midi/0/note/%d", note_num)
    local pad = (4 - (#addr % 4)) % 4
    if pad == 0 then pad = 4 end
    addr = addr .. string.rep("\0", pad)
    return addr .. TYPETAG_FLOAT .. vel_bytes
end

for note = 20, 100 do
    NOTE_ON_PACKETS[note]  = build_vkb_packet(note, VEL_ON_BYTES)
    NOTE_OFF_PACKETS[note] = build_vkb_packet(note, VEL_OFF_BYTES)
end

-- CUSTOM OSC PACKETS
local OSC_DROP_CUSTOM   = "/mutris/drop\0\0\0\0,\0\0\0"
local OSC_TSPIN_CUSTOM  = "/mutris/tspin\0\0\0,\0\0\0"
local OSC_TETRIS_CUSTOM = "/mutris/tetris\0\0,\0\0\0"

-- NOTE-OFF RELEASE QUEUE (Zero-GC Ring Buffer)
local MAX_QUEUE = 16
local note_queue_note = {}
local note_queue_timer = {}
local queue_count = 0

for i = 1, MAX_QUEUE do
    note_queue_note[i] = 0
    note_queue_timer[i] = 0.0
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
-- NOTE DISPATCH & NOTE-OFF SCHEDULER
-- ============================================================================
local function trigger_midi_note(note_num, duration)
    if not is_connected or not udp then return end

    local on_pkt  = NOTE_ON_PACKETS[note_num]
    local off_pkt = NOTE_OFF_PACKETS[note_num]

    if on_pkt and off_pkt then
        -- 1. Force instant voice release to retrigger attack envelope cleanly
        udp:send(off_pkt)

        -- 2. Send Note On
        udp:send(on_pkt)
        packet_count = packet_count + 2

        -- 3. Enqueue scheduled Note-Off release
        if queue_count < MAX_QUEUE then
            queue_count = queue_count + 1
            note_queue_note[queue_count] = note_num
            note_queue_timer[queue_count] = duration or 0.09
        end
    end
end

-- ============================================================================
-- GAMEPLAY TRIGGERS
-- ============================================================================

function OscClient.send_drop(midi_note)
    if not is_connected or not udp then return end
    udp:send(OSC_DROP_CUSTOM)
    packet_count = packet_count + 1
    trigger_midi_note(midi_note or 42, 0.06) -- F#1 / Bass Impact
end

function OscClient.send_tspin(midi_note)
    if not is_connected or not udp then return end
    udp:send(OSC_TSPIN_CUSTOM)
    packet_count = packet_count + 1
    trigger_midi_note(midi_note or 66, 0.12) -- F#4 High Stab
end

function OscClient.send_tetris()
    if not is_connected or not udp then return end
    udp:send(OSC_TETRIS_CUSTOM)
    packet_count = packet_count + 1
    trigger_midi_note(30, 0.20) -- Sub Drop F#0
end

function OscClient.send_camelot_chord(root_midi, scale_type)
    if not is_connected or not udp then return end
    local r = root_midi or 54 -- F#3
    local third_interval = (scale_type == "major") and 4 or 3
    
    trigger_midi_note(r, 0.10)
    trigger_midi_note(r + third_interval, 0.10)
    trigger_midi_note(r + 7, 0.10)
end

function OscClient.send_camelot(key_id)
    -- Reserved for key updates
end

-- ============================================================================
-- UPDATE: PROCESS NOTE-OFF RELEASES (Strict Zero-GC)
-- ============================================================================
function OscClient.update(dt)
    if queue_count == 0 or not is_connected or not udp then return end

    local i = 1
    while i <= queue_count do
        note_queue_timer[i] = note_queue_timer[i] - dt
        if note_queue_timer[i] <= 0.0 then
            local note = note_queue_note[i]
            local off_pkt = NOTE_OFF_PACKETS[note]
            if off_pkt then
                udp:send(off_pkt)
                packet_count = packet_count + 1
            end

            local last = queue_count
            if i ~= last then
                note_queue_note[i] = note_queue_note[last]
                note_queue_timer[i] = note_queue_timer[last]
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

function OscClient.is_active()
    return is_connected
end

return OscClient
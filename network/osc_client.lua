-- ============================================================================
-- FILE: network/osc_client.lua
-- MUTRIS ENGINE: ZERO-GC OSC CLIENT (FFI BUFFERING)
-- ============================================================================
---@diagnostic disable: undefined-global

local ffi = require("ffi")
local socket = require("socket")

local OscClient = {
    telemetry = "OSC_NET: DISCONNECTED"
}

local udp = nil

function OscClient.init(ip, p)
    udp = socket.udp()
    if udp then
        udp:setpeername(ip or "127.0.0.1", p or 8000)
        udp:settimeout(0)
        OscClient.telemetry = "OSC_NET: CONNECTED"
    end
end

-- FFI Zero-GC buffer logic for standard Mutris OSC commands
-- Since commands are fixed length, we can preallocate them to avoid string/GC allocation on hot-loops.
local function create_osc_buffer(address)
    local len = #address
    local pad = 4 - (len % 4)
    local total = len + pad
    local buf = ffi.new("uint8_t[?]", total)
    for i = 1, len do
        buf[i-1] = string.byte(address, i)
    end
    for i = len, total - 1 do
        buf[i] = 0
    end
    return ffi.string(buf, total) -- Stored as a pure Lua string for socket.udp(), avoids runtime string.pack
end

local cmd_drop = create_osc_buffer("/mutris/drop")
local cmd_tetris = create_osc_buffer("/mutris/tetris")
local cmd_tspin = create_osc_buffer("/mutris/tspin")

-- Pre-allocate Camelot ID paths (1 to 12)
local cmd_camelot = {}
for i = 1, 12 do
    cmd_camelot[i] = create_osc_buffer("/mutris/camelot/" .. tostring(i))
end

function OscClient.is_active()
    return udp ~= nil
end

function OscClient.send_drop()
    if udp then udp:send(cmd_drop) end
end

function OscClient.send_tetris()
    if udp then udp:send(cmd_tetris) end
end

function OscClient.send_tspin()
    if udp then udp:send(cmd_tspin) end
end

function OscClient.send_camelot(id)
    if udp and cmd_camelot[id] then
        udp:send(cmd_camelot[id])
    end
end

function OscClient.get_telemetry()
    return OscClient.telemetry
end

return OscClient

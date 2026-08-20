---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: NATIVE LUAJIT GIF89a ANIMATED ENCODER
-- Arquitectura: Compresión LZW por Bits / Paleta Cuántica / Ultra-Liviano
-- ============================================================================
local GIFEncoder = {}
local bit = require("bit")

-- 🎨 Paleta Global Optimizada de 256 Colores (Cubo 6x6x6 + Grises + Neones MUTRIS)
local PALETTE = {}
local PALETTE_BYTES = {}

local function initPalette()
    local idx = 1
    -- 1. Cubo RGB 6x6x6 (216 Colores)
    for r = 0, 5 do
        for g = 0, 5 do
            for b = 0, 5 do
                PALETTE[idx] = { r * 51, g * 51, b * 51 }
                PALETTE_BYTES[#PALETTE_BYTES + 1] = string.char(r * 51, g * 51, b * 51)
                idx = idx + 1
            end
        end
    end
    -- 2. Escala de Grises Pura (16 Tonos)
    for i = 0, 15 do
        local v = math.floor(i * 17)
        PALETTE[idx] = { v, v, v }
        PALETTE_BYTES[#PALETTE_BYTES + 1] = string.char(v, v, v)
        idx = idx + 1
    end
    -- 3. Neones Específicos MUTRIS (24 Colores)
    local neons = {
        {0, 240, 255}, {255, 30, 180}, {255, 215, 0}, {180, 20, 255},
        {30, 255, 60}, {255, 120, 0}, {255, 40, 60}, {5, 15, 35},
        {0, 30, 60}, {10, 45, 80}, {20, 80, 130}, {0, 180, 220},
        {130, 200, 255}, {255, 160, 220}, {220, 255, 100}, {255, 90, 120},
        {10, 20, 30}, {15, 25, 45}, {2, 6, 12}, {1, 2, 4},
        {0, 0, 0}, {255, 255, 255}, {80, 90, 110}, {40, 50, 65}
    }
    for _, clr in ipairs(neons) do
        PALETTE[idx] = clr
        PALETTE_BYTES[#PALETTE_BYTES + 1] = string.char(clr[1], clr[2], clr[3])
        idx = idx + 1
    end
end
initPalette()

-- ⚡ Mapeo O(1) de Color RGB a Índice de Paleta
local function colorToIndex(r, g, b)
    local ir = math.floor(r / 51 + 0.5)
    local ig = math.floor(g / 51 + 0.5)
    local ib = math.floor(b / 51 + 0.5)
    ir = math.max(0, math.min(5, ir))
    ig = math.max(0, math.min(5, ig))
    ib = math.max(0, math.min(5, ib))
    return (ir * 36) + (ig * 6) + ib
end

-- 📦 Empaquetador de Bits para Flujo LZW
local function newBitWriter()
    local chunks = {}
    local cur_byte = 0
    local cur_bits = 0
    local sub_block = {}

    local function flushSubBlock()
        if #sub_block > 0 then
            chunks[#chunks + 1] = string.char(#sub_block)
            chunks[#chunks + 1] = table.concat(sub_block)
            sub_block = {}
        end
    end

    local function emitByte(b)
        sub_block[#sub_block + 1] = string.char(b)
        if #sub_block == 254 then
            flushSubBlock()
        end
    end

    local function writeBits(val, num_bits)
        cur_byte = cur_byte + bit.lshift(val, cur_bits)
        cur_bits = cur_bits + num_bits
        while cur_bits >= 8 do
            emitByte(bit.band(cur_byte, 0xFF))
            cur_byte = bit.rshift(cur_byte, 8)
            cur_bits = cur_bits - 8
        end
    end

    local function finish()
        if cur_bits > 0 then
            emitByte(bit.band(cur_byte, 0xFF))
        end
        flushSubBlock()
        chunks[#chunks + 1] = "\x00"
        return table.concat(chunks)
    end

    return { writeBits = writeBits, finish = finish }
end

-- 🗜️ Compresor LZW Estándar GIF89a
local function compressLZW(pixels, count)
    local writer = newBitWriter()
    local clear_code = 256
    local eoi_code = 257
    local code_size = 9
    local max_code = 511
    local next_code = 258

    local dict = {}
    writer.writeBits(clear_code, code_size)

    local prefix = pixels[1]
    for i = 2, count do
        local k = pixels[i]
        local key = bit.bor(bit.lshift(prefix, 8), k)
        local code = dict[key]

        if code then
            prefix = code
        else
            writer.writeBits(prefix, code_size)
            if next_code < 4096 then
                dict[key] = next_code
                next_code = next_code + 1
                if next_code > max_code + 1 and code_size < 12 then
                    code_size = code_size + 1
                    max_code = bit.lshift(1, code_size) - 1
                end
            else
                writer.writeBits(clear_code, code_size)
                dict = {}
                code_size = 9
                max_code = 511
                next_code = 258
            end
            prefix = k
        end
    end

    writer.writeBits(prefix, code_size)
    writer.writeBits(eoi_code, code_size)
    return writer.finish()
end

-- 🎬 Codificador Maestro GIF Animado (Salida en String Binario)
function GIFEncoder.encode(frames_imgdata, out_w, out_h, delay_cs)
    if #frames_imgdata == 0 then return nil end

    local w = out_w or 480
    local h = out_h or 270
    local delay = delay_cs or 6 -- 6 centésimas de segundo (~16 FPS)

    local out = {}

    -- 1. Encabezado GIF89a
    out[#out + 1] = "GIF89a"
    out[#out + 1] = string.char(bit.band(w, 0xFF), bit.rshift(w, 8))
    out[#out + 1] = string.char(bit.band(h, 0xFF), bit.rshift(h, 8))
    out[#out + 1] = "\xF7\x00\x00" -- Global Color Table (256 colores, 8-bit)
    out[#out + 1] = table.concat(PALETTE_BYTES)

    -- 2. Extensión de Bucle Infinito (Netscape 2.0)
    out[#out + 1] = "\x21\xFF\x0B" .. "NETSCAPE2.0" .. "\x03\x01\x00\x00\x00"

    -- Buffer estático para píxeles muestreados
    local pixel_buffer = {}

    -- 3. Codificación de cada Fotograma
    for _, imgData in ipairs(frames_imgdata) do
        local src_w, src_h = imgData:getDimensions()
        local scale_x = src_w / w
        local scale_y = src_h / h

        local p_idx = 1
        for y = 0, h - 1 do
            local sy = math.min(src_h - 1, math.floor(y * scale_y))
            for x = 0, w - 1 do
                local sx = math.min(src_w - 1, math.floor(x * scale_x))
                local r, g, b = imgData:getPixel(sx, sy)
                pixel_buffer[p_idx] = colorToIndex(r * 255, g * 255, b * 255)
                p_idx = p_idx + 1
            end
        end

        -- Control de Tiempo (Graphics Control Extension)
        local d_lo = bit.band(delay, 0xFF)
        local d_hi = bit.rshift(delay, 8)
        out[#out + 1] = "\x21\xF9\x04" .. string.char(0x00, d_lo, d_hi, 0x00) .. "\x00"

        -- Descriptor de Imagen
        out[#out + 1] = "\x2C\x00\x00\x00\x00"
        out[#out + 1] = string.char(bit.band(w, 0xFF), bit.rshift(w, 8))
        out[#out + 1] = string.char(bit.band(h, 0xFF), bit.rshift(h, 8))
        out[#out + 1] = "\x00" -- Sin paleta local (usa la global)

        -- LZW Min Code Size
        out[#out + 1] = "\x08"
        out[#out + 1] = compressLZW(pixel_buffer, w * h)
    end

    -- 4. Terminador GIF
    out[#out + 1] = ";"
    return table.concat(out)
end

return GIFEncoder
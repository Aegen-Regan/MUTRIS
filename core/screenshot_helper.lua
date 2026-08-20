---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: LOSSLESS SCREENSHOT & DIRECT CLIPBOARD COPIER
-- Arquitectura: FFI Nativo Win32 (CF_DIB) / Zero-Delay / Auto-PNG Saver
-- ============================================================================
local ScreenshotHelper = {}

local ffi = require("ffi")
local Blackbox = require "core.blackbox"

-- 🪟 Definición de la API Win32 para interactuar con el Portapapeles de Windows
local is_windows = (love.system.getOS() == "Windows")
if is_windows then
    pcall(ffi.cdef, [[
        void* GlobalAlloc(uint32_t uFlags, size_t dwBytes);
        void* GlobalLock(void* hMem);
        int   GlobalUnlock(void* hMem);
        void* GlobalFree(void* hMem);
        int   OpenClipboard(void* hWndNewOwner);
        int   CloseClipboard(void);
        int   EmptyClipboard(void);
        void* SetClipboardData(uint32_t uFormat, void* hMem);
        void* GetActiveWindow(void);
    ]])
end

local function copyImageDataToWindowsClipboard(imgData)
    if not is_windows then return false end

    local w, h = imgData:getDimensions()
    local dib_header_size = 40
    local pixel_data_size = w * h * 4
    local total_size = dib_header_size + pixel_data_size

    -- GMEM_MOVEABLE = 0x0002
    local hMem = ffi.C.GlobalAlloc(0x0002, total_size)
    if hMem == nil then return false end

    local ptr = ffi.cast("uint8_t*", ffi.C.GlobalLock(hMem))
    if ptr == nil then
        ffi.C.GlobalFree(hMem)
        return false
    end

    -- 📋 Estructura BITMAPINFOHEADER (DIB estándar para portapapeles)
    local header_ptr = ffi.cast("uint32_t*", ptr)
    header_ptr[0] = dib_header_size    -- biSize
    header_ptr[1] = w                  -- biWidth
    header_ptr[2] = h                  -- biHeight (positivo = bottom-up)
    
    local header_u16 = ffi.cast("uint16_t*", ptr + 12)
    header_u16[0] = 1                  -- biPlanes
    header_u16[1] = 32                 -- biBitCount (RGBA)

    header_ptr[4] = 0                  -- biCompression (BI_RGB)
    header_ptr[5] = pixel_data_size    -- biSizeImage
    header_ptr[6] = 0                  -- biXPelsPerMeter
    header_ptr[7] = 0                  -- biYPelsPerMeter
    header_ptr[8] = 0                  -- biClrUsed
    header_ptr[9] = 0                  -- biClrImportant

    -- 🔄 Copia y conversión de píxeles (LÖVE RGBA Top-Down -> Win32 BGRA Bottom-Up)
    local raw_ptr = imgData.getFFIPointer and imgData:getFFIPointer() or imgData:getPointer()
    local src_pixels = ffi.cast("const uint8_t*", raw_ptr)
    local dst_pixels = ptr + dib_header_size

    for y = 0, h - 1 do
        local src_row = y
        local dst_row = h - 1 - y
        local src_offset = src_row * w * 4
        local dst_offset = dst_row * w * 4

        for x = 0, w - 1 do
            local so = src_offset + x * 4
            local doff = dst_offset + x * 4
            dst_pixels[doff + 0] = src_pixels[so + 2] -- Blue
            dst_pixels[doff + 1] = src_pixels[so + 1] -- Green
            dst_pixels[doff + 2] = src_pixels[so + 0] -- Red
            dst_pixels[doff + 3] = src_pixels[so + 3] -- Alpha
        end
    end

    ffi.C.GlobalUnlock(hMem)

    local hwnd = ffi.C.GetActiveWindow()
    if ffi.C.OpenClipboard(hwnd) ~= 0 then
        ffi.C.EmptyClipboard()
        -- CF_DIB = 8
        ffi.C.SetClipboardData(8, hMem)
        ffi.C.CloseClipboard()
        return true
    else
        ffi.C.GlobalFree(hMem)
        return false
    end
end

-- 📸 DISPARADOR MAESTRO DE CAPTURA
function ScreenshotHelper.capture(callback_feedback)
    love.graphics.captureScreenshot(function(imgData)
        local w, h = imgData:getDimensions()

        -- 1. Copiar directamente al Portapapeles (para Ctrl+V instantáneo)
        local copied = copyImageDataToWindowsClipboard(imgData)

        -- 2. Guardar archivo físico .PNG con fecha y hora
        if not love.filesystem.getInfo("screenshots") then
            love.filesystem.createDirectory("screenshots")
        end

        local timestamp = os.date("%Y%m%d_%H%M%S")
        local filename = "screenshots/MUTRIS_" .. timestamp .. ".png"
        
        local file_data = imgData:encode("png")
        love.filesystem.write(filename, file_data)

        -- Guardar también en la carpeta raíz del proyecto
        local local_file = io.open(filename, "wb")
        if local_file then
            local_file:write(file_data:getString())
            local_file:close()
        end

        Blackbox.log("SYSTEM", "SCREENSHOT COPIED TO CLIPBOARD", w, h)

        if callback_feedback then
            callback_feedback(copied, filename)
        end
    end)
end

return ScreenshotHelper
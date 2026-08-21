-- ================================================================
-- FILE: core/clip_recorder.lua
-- ================================================================
---@diagnostic disable: undefined-global, inject-field, undefined-field
-- ============================================================================
-- MUTRIS ENGINE: DUAL RECORDER (WIN32 MP4 60FPS & LUAJIT GIF ENCODER)
-- ============================================================================
local ClipRecorder = {}

local ffi             = require("ffi")
local FontCache       = require "tetris.font_cache"
local Blackbox        = require "core.blackbox"
local SettingsManager = require "settings_manager"
local GIFEncoder      = require "core.gif_encoder"

local is_windows = (love.system.getOS() == "Windows")
if is_windows then
    pcall(ffi.cdef, [[
        typedef void* HANDLE;
        typedef int BOOL;
        typedef uint32_t DWORD;
        typedef uint16_t WORD;
        typedef uint8_t BYTE;

        typedef struct _SECURITY_ATTRIBUTES {
            DWORD nLength;
            void* lpSecurityDescriptor;
            BOOL bInheritHandle;
        } SECURITY_ATTRIBUTES, *LPSECURITY_ATTRIBUTES;

        typedef struct _STARTUPINFOA {
            DWORD cb;
            char* lpReserved;
            char* lpDesktop;
            char* lpTitle;
            DWORD dwX;
            DWORD dwY;
            DWORD dwXSize;
            DWORD dwYSize;
            DWORD dwXCountChars;
            DWORD dwYCountChars;
            DWORD dwFillAttribute;
            DWORD dwFlags;
            WORD  wShowWindow;
            WORD  cbReserved2;
            BYTE* lpReserved2;
            HANDLE hStdInput;
            HANDLE hStdOutput;
            HANDLE hStdError;
        } STARTUPINFOA, *LPSTARTUPINFOA;

        typedef struct _PROCESS_INFORMATION {
            HANDLE hProcess;
            HANDLE hThread;
            DWORD  dwProcessId;
            DWORD  dwThreadId;
        } PROCESS_INFORMATION, *LPPROCESS_INFORMATION;

        BOOL CreatePipe(HANDLE* hReadPipe, HANDLE* hWritePipe, LPSECURITY_ATTRIBUTES lpPipeAttributes, DWORD nSize);
        BOOL SetHandleInformation(HANDLE hObject, DWORD dwMask, DWORD dwFlags);
        BOOL CreateProcessA(const char* lpApplicationName, char* lpCommandLine, LPSECURITY_ATTRIBUTES lpProcessAttributes, LPSECURITY_ATTRIBUTES lpThreadAttributes, BOOL bInheritHandles, DWORD dwCreationFlags, void* lpEnvironment, const char* lpCurrentDirectory, LPSTARTUPINFOA lpStartupInfo, LPPROCESS_INFORMATION lpProcessInformation);
        HANDLE CreateFileA(const char* lpFileName, DWORD dwDesiredAccess, DWORD dwShareMode, LPSECURITY_ATTRIBUTES lpSecurityAttributes, DWORD dwCreationDisposition, DWORD dwFlagsAndAttributes, HANDLE hTemplateFile);
        BOOL WriteFile(HANDLE hFile, const void* lpBuffer, DWORD nNumberOfBytesToWrite, DWORD* lpNumberOfBytesWritten, void* lpOverlapped);
        BOOL CloseHandle(HANDLE hObject);
        DWORD WaitForSingleObject(HANDLE hHandle, DWORD dwMilliseconds);
        BOOL CreateDirectoryA(const char* lpPathName, void* lpSecurityAttributes);
    ]])
end

ClipRecorder.is_recording = false
ClipRecorder.mode = "mp4" -- "mp4" o "gif"
ClipRecorder.record_time = 0.0
ClipRecorder.frame_count = 0
ClipRecorder.h_write_pipe = nil
ClipRecorder.h_process = nil
ClipRecorder.h_thread = nil
ClipRecorder.current_output_path = nil

-- Buffer en memoria para fotogramas GIF
ClipRecorder.gif_frames = {}
ClipRecorder.gif_frame_timer = 0.0

local function getFFmpegPath()
    local custom = "C:\\Users\\Mati\\Documents\\YT DLP\\ffmpeg.exe"
    local f = io.open(custom, "r")
    if f then
        f:close()
        return custom
    end
    return "ffmpeg.exe"
end

function ClipRecorder.init()
    ClipRecorder.is_recording = false
    ClipRecorder.record_time = 0.0
    ClipRecorder.frame_count = 0
    ClipRecorder.h_write_pipe = nil
    ClipRecorder.h_process = nil
    ClipRecorder.h_thread = nil
    ClipRecorder.current_output_path = nil
    ClipRecorder.gif_frames = {}
    ClipRecorder.gif_frame_timer = 0.0
end

function ClipRecorder.toggle(callback_feedback)
    if ClipRecorder.is_recording then
        ClipRecorder.stopAndSave(callback_feedback)
    else
        ClipRecorder.start()
    end
end

function ClipRecorder.start()
    if ClipRecorder.is_recording then return end

    local project_dir = (love.filesystem.getSource() .. "/recordings"):gsub("/", "\\")
    local appdata_dir = (love.filesystem.getSaveDirectory() .. "/recordings"):gsub("/", "\\")

    if is_windows then
        ffi.C.CreateDirectoryA(project_dir, nil)
        ffi.C.CreateDirectoryA(appdata_dir, nil)
    else
        love.filesystem.createDirectory("recordings")
    end

    local mode = SettingsManager.get("capture_mode") or "mp4"
    ClipRecorder.mode = mode
    ClipRecorder.record_time = 0.0
    ClipRecorder.frame_count = 0
    ClipRecorder.gif_frames = {}
    ClipRecorder.gif_frame_timer = 0.0

    local timestamp = os.date("%Y%m%d_%H%M%S")

    -- 🔴 MODO 1: GRABACIÓN GIF ANIMADO
    if mode == "gif" then
        ClipRecorder.current_output_path = project_dir .. "\\MUTRIS_CLIP_" .. timestamp .. ".gif"
        ClipRecorder.is_recording = true
        Blackbox.log("RECORDER", "GIF CAPTURE ARMED", 0, 0)
        print("🎬 Grabación GIF iniciada: " .. ClipRecorder.current_output_path)
        return
    end

    -- 🔴 MODO 2: GRABACIÓN MP4 60FPS POR TUBERÍA WIN32
    if not is_windows then return end

    local final_mp4 = project_dir .. "\\MUTRIS_CLIP_" .. timestamp .. ".mp4"
    local log_path  = project_dir .. "\\ffmpeg_log.txt"
    ClipRecorder.current_output_path = final_mp4

    local sa = ffi.new("SECURITY_ATTRIBUTES", {
        nLength = ffi.sizeof("SECURITY_ATTRIBUTES"),
        bInheritHandle = 1,
        lpSecurityDescriptor = nil
    })

    local h_read = ffi.new("HANDLE[1]")
    local h_write = ffi.new("HANDLE[1]")

    if ffi.C.CreatePipe(h_read, h_write, sa, 0) == 0 then return end
    ffi.C.SetHandleInformation(h_write[0], 1, 0)

    local h_log = ffi.C.CreateFileA(log_path, 0x40000000, 3, sa, 2, 0x80, nil)

    local si = ffi.new("STARTUPINFOA", {
        cb = ffi.sizeof("STARTUPINFOA"),
        dwFlags = 0x00000100 + 0x00000001,
        wShowWindow = 0,
        hStdInput = h_read[0],
        hStdOutput = h_log,
        hStdError = h_log
    })

    local pi = ffi.new("PROCESS_INFORMATION")
    local ffmpeg_bin = getFFmpegPath()
    local cmd_str = string.format(
        '"%s" -y -f rawvideo -vcodec rawvideo -s 1280x720 -pix_fmt rgba -r 60 -i - -c:v libx264 -preset ultrafast -crf 26 -pix_fmt yuv420p "%s"',
        ffmpeg_bin,
        final_mp4
    )

    local cmd_buf = ffi.new("char[?]", #cmd_str + 1)
    ffi.copy(cmd_buf, cmd_str)

    local success = ffi.C.CreateProcessA(nil, cmd_buf, nil, nil, 1, 0x08000000, nil, nil, si, pi)

    ffi.C.CloseHandle(h_read[0])
    if h_log ~= nil then ffi.C.CloseHandle(h_log) end

    if success ~= 0 then
        ClipRecorder.h_write_pipe = h_write[0]
        ClipRecorder.h_process = pi.hProcess
        ClipRecorder.h_thread = pi.hThread
        ClipRecorder.is_recording = true
        Blackbox.log("RECORDER", "SILENT FFMPEG 60FPS RUNNING", 0, 0)
        print("🎬 FFmpeg iniciado en silencio: " .. final_mp4)
    else
        ffi.C.CloseHandle(h_write[0])
    end
end

function ClipRecorder.captureFrame(canvas)
    if not ClipRecorder.is_recording or not canvas then return end

    if ClipRecorder.mode == "mp4" then
        if not ClipRecorder.h_write_pipe then return end
        local ok, img_data = pcall(function() return canvas:newImageData() end)
        if ok and img_data then
            ClipRecorder.frame_count = ClipRecorder.frame_count + 1
            local raw_ptr = img_data.getFFIPointer and img_data:getFFIPointer() or img_data:getPointer()
            local written = ffi.new("DWORD[1]")
            ffi.C.WriteFile(ClipRecorder.h_write_pipe, raw_ptr, 1280 * 720 * 4, written, nil)
        end

    elseif ClipRecorder.mode == "gif" then
        -- Muestreo a ~20 FPS para mantener el GIF ultra liviano
        ClipRecorder.gif_frame_timer = ClipRecorder.gif_frame_timer + (1.0 / 60.0)
        if ClipRecorder.gif_frame_timer >= 0.050 then
            ClipRecorder.gif_frame_timer = 0.0
            local ok, img_data = pcall(function() return canvas:newImageData() end)
            if ok and img_data then
                ClipRecorder.frame_count = ClipRecorder.frame_count + 1
                table.insert(ClipRecorder.gif_frames, img_data)
                -- Límite de seguridad de 300 fotogramas (~15s)
                if #ClipRecorder.gif_frames > 300 then
                    table.remove(ClipRecorder.gif_frames, 1)
                end
            end
        end
    end
end

function ClipRecorder.update(dt)
    if ClipRecorder.is_recording then
        ClipRecorder.record_time = ClipRecorder.record_time + dt
    end
end

function ClipRecorder.stopAndSave(callback_feedback)
    if not ClipRecorder.is_recording then return end
    ClipRecorder.is_recording = false

    local total_frames = ClipRecorder.frame_count
    local total_time   = ClipRecorder.record_time
    local path         = ClipRecorder.current_output_path or "recordings/clip"

    if ClipRecorder.mode == "mp4" then
        if ClipRecorder.h_write_pipe then
            ffi.C.CloseHandle(ClipRecorder.h_write_pipe)
            ClipRecorder.h_write_pipe = nil
        end
        if ClipRecorder.h_process then
            ffi.C.WaitForSingleObject(ClipRecorder.h_process, 4000)
            ffi.C.CloseHandle(ClipRecorder.h_process)
            ffi.C.CloseHandle(ClipRecorder.h_thread)
            ClipRecorder.h_process = nil
            ClipRecorder.h_thread = nil
        end
        Blackbox.log("RECORDER", "SAVED MP4: " .. path, total_frames, math.floor(total_time))
        print(string.format("✅ Video MP4 guardado: %s (%d frames @ 60 FPS)", path, total_frames))

    elseif ClipRecorder.mode == "gif" then
        local preset = SettingsManager.get("gif_resolution") or 1
        local out_w = (preset == 2) and 640 or 480
        local out_h = (preset == 2) and 360 or 270
        local delay_cs = 5 -- 5 centésimas = 20 FPS

        local encoded_gif = GIFEncoder.encode(ClipRecorder.gif_frames, out_w, out_h, delay_cs)
        if encoded_gif then
            local file = io.open(path, "wb")
            if file then
                file:write(encoded_gif)
                file:close()
            end
            love.filesystem.write("recordings/" .. path:match("([^/\\]+)$"), encoded_gif)
            Blackbox.log("RECORDER", "SAVED GIF: " .. path, total_frames, math.floor(total_time))
            print(string.format("✅ GIF animado guardado: %s (%d frames, %dx%d)", path, total_frames, out_w, out_h))
        end
        ClipRecorder.gif_frames = {}
    end

    if callback_feedback then
        callback_feedback(total_frames, path, ClipRecorder.mode)
    end
end

function ClipRecorder.drawHUDIndicator()
    if not ClipRecorder.is_recording then return end

    local time = love.timer.getTime()
    local pulse = math.sin(time * 6) * 0.5 + 0.5

    love.graphics.push("all")
    local bx, by, bw, bh = 1080, 48, 180, 32
    love.graphics.setColor(0.02, 0.01, 0.04, 0.90)
    love.graphics.rectangle("fill", bx, by, bw, bh, 6)

    local is_gif = (ClipRecorder.mode == "gif")
    local border_color = is_gif and {1.0, 0.85, 0.2} or {1.0, 0.1, 0.2}

    love.graphics.setLineWidth(1.5)
    love.graphics.setColor(border_color[1], border_color[2], border_color[3], 0.85)
    love.graphics.rectangle("line", bx, by, bw, bh, 6)

    love.graphics.setColor(border_color[1], border_color[2], border_color[3], 0.3 + pulse * 0.7)
    love.graphics.circle("fill", bx + 16, by + 16, 6)

    love.graphics.setFont(FontCache.get(10))
    love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
    local mins = math.floor(ClipRecorder.record_time / 60)
    local secs = ClipRecorder.record_time % 60
    local label = is_gif and "GIF REC" or "REC 60FPS"
    local rec_str = string.format("%s %02d:%04.1f", label, mins, secs)
    love.graphics.print(rec_str, bx + 28, by + 9)

    love.graphics.pop()
end

return ClipRecorder
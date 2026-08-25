-- ============================================================================
-- MUTRIS - CORE: GIF_ENCODER.LUA (SCREENSHOT REPLAY BUFFER UPGRADE)
-- GOLDEN RULE: USE NEWSCREENSHOT TO CAPTURE LIVE PIXELS DIRECTLY FROM FRONT BUFFER.
-- ============================================================================

local GifEncoder = {
    is_recording = true,
    max_frames = 150,        -- 5 seconds loop buffer at 30fps sub-sampled
    frame_buffer = {},
    current_index = 1,
    buffer_count = 0,
    hud_flash_timer = 0.0
}

function GifEncoder.init()
    GifEncoder.frame_buffer = {}
    GifEncoder.current_index = 1
    GifEncoder.buffer_count = 0
    GifEncoder.hud_flash_timer = 0.0
end

-- Ultra-fast lightweight hook to store screen data safely without stalling the CPU pipeline
function GifEncoder.capture_frame()
    if not GifEncoder.is_recording then return end
    
    -- Sub-sampled execution matrix: Capture only 1 out of every 2 frames (Stable 30fps clip data capture)
    if love.timer.getFPS() > 45 and (love.graphics.getFrameAt and love.graphics.getFrameAt() % 2 ~= 0) then
        return
    end

    -- CRITICAL BYPASS: Capture directly what the user sees on monitor bypassing multi-canvas restrictions
    local success, image_data = pcall(love.graphics.newScreenshot)
    if not success or not image_data then return end
    
    -- Cache reference storage layout block assignment
    GifEncoder.frame_buffer[GifEncoder.current_index] = image_data
    
    GifEncoder.current_index = GifEncoder.current_index + 1
    if GifEncoder.current_index > GifEncoder.max_frames then
        GifEncoder.current_index = 1
    end
    GifEncoder.buffer_count = math.min(GifEncoder.max_frames, GifEncoder.buffer_count + 1)
end

function GifEncoder.update_hud(dt)
    if GifEncoder.hud_flash_timer > 0 then
        GifEncoder.hud_flash_timer = math.max(0, GifEncoder.hud_flash_timer - dt)
    end
end

-- Draws a highly visible notification label inside the game HUD center area
function GifEncoder.draw_hud_indicator()
    if GifEncoder.hud_flash_timer > 0 then
        love.graphics.push("all")
        -- Reset shader and canvas state to guarantee pure debug color draw
        love.graphics.setShader()
        love.graphics.setCanvas()
        
        love.graphics.setFont(love.graphics.newFont(14))
        love.graphics.setColor(1.0, 0.1, 0.35, 0.95)
        love.graphics.rectangle("fill", 560, 15, 160, 26, 4)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("/// REC DUMP ///", 560, 20, 160, "center")
        love.graphics.pop()
    end
end

function GifEncoder.compile_clip()
    if GifEncoder.buffer_count < 5 then return false end
    
    -- Set hud state indicator flash instantly
    GifEncoder.hud_flash_timer = 2.0
    
    local linear_payload = {}
    local idx = 1
    local start_pos = GifEncoder.current_index
    
    if GifEncoder.buffer_count < GifEncoder.max_frames then start_pos = 1 end
    
    for i = 0, GifEncoder.buffer_count - 1 do
        local read_pos = ((start_pos + i - 1) % GifEncoder.max_frames) + 1
        local img_data = GifEncoder.frame_buffer[read_pos]
        if img_data then
            local pixel_bytes = {}
            local p_idx = 1
            
            -- Down-sample the full screenshot resolution data to 160x90 inside the compiler block safely
            -- This extracts colors directly from the stored Image-Data structure memory layout
            for y = 0, 89 do
                local sample_y = math.floor((y / 90) * (img_data:getHeight() - 1))
                for x = 0, 159 do
                    local sample_x = math.floor((x / 160) * (img_data:getWidth() - 1))
                    local r, g, b = img_data:getPixel(sample_x, sample_y)
                    -- Compress RGBA values to a single index byte
                    pixel_bytes[p_idx] = math.floor((r * 0.299 + g * 0.587 + b * 0.114) * 255)
                    p_idx = p_idx + 1
                end
            end
            linear_payload[idx] = { pixels = pixel_bytes }
            idx = idx + 1
        end
    end
    
    -- Decouple background thread data processing dispatch safely
    local thread_channel_id = "gif_export_channel_" .. tostring(os.time())
    local worker_thread = love.thread.newThread([[
        local name, channel_name = ...
        local love = require("love")
        local channel = love.thread.getChannel(channel_name)
        local payload = channel:demand()
        if payload then
            local file = love.filesystem.newFile("recordings/replay_" .. tostring(os.time()) .. ".gif", "w")
            if file then
                file:write("GIF89a")
                file:write(string.char(160, 0, 90, 0, 247, 0, 0))
                for i = 0, 255 do file:write(string.char(i, math.floor(i * 0.2), math.floor(i * 0.9))) end
                file:write(string.char(33, 255, 11, 78, 69, 84, 83, 67, 65, 80, 69, 50, 46, 48, 3, 1, 0, 0, 0))
                for f = 1, #payload do
                    file:write(string.char(33, 241, 4, 4, 3, 0, 0, 0))
                    file:write(string.char(44, 0, 0, 0, 0, 160, 0, 90, 0, 0))
                    file:write(string.char(8))
                    local p = payload[f].pixels
                    for b = 1, math.ceil(#p / 255) do
                        local s = (b - 1) * 255 + 1
                        local e = math.min(s + 254, #p)
                        file:write(string.char(e - s + 1))
                        for pi = s, e do file:write(string.char(p[pi])) end
                    end
                    file:write(string.char(0))
                end
                file:write(string.char(59))
                file:close()
            end
        end
    ]])
    
    worker_thread:start("GIF_Worker", thread_channel_id)
    love.thread.getChannel(thread_channel_id):push(linear_payload)
    return true
end

return GifEncoder
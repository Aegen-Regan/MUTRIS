local TrackManager = require "track_manager" 
local FontCache = require "tetris.font_cache"

local GameStates = {}

function GameStates.drawMenu(timer, selected, diffs)
    local mx, my = love.mouse.getPosition()
    local title_scale = 2 + math.sin(timer * 12) * 0.05
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.printf("TETRIS VERSUS OPT", 0, 60, 800 / title_scale, "center", 0, title_scale, title_scale)
    
    local current_track = TrackManager.getCurrentTrack() or {
        name = "SYSTEM EMPTY", file_path = "", bpm = 120, root_note = "C", mode = "MINOR"
    }
    love.graphics.setFont(FontCache.get(12))
    love.graphics.setColor(0, 0.8, 1, 0.8)
    love.graphics.printf("< PREV TRACK  |  DRAG & DROP MP3 TO BATCH  |  NEXT TRACK >", 0, 160, 800, "center")
    
    love.graphics.setFont(FontCache.get(16))
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.printf(current_track.name, 0, 185, 800, "center")
    
    love.graphics.setFont(FontCache.get(12))
    love.graphics.setColor(0.5, 0.5, 0.6)
    if current_track.file_path ~= "" then
        love.graphics.printf("BPM: " .. current_track.bpm .. "   |   KEY: " .. current_track.root_note .. " (" .. current_track.mode .. ")", 0, 215, 800, "center")
        
        local hover_lab = (mx >= 275 and mx <= 525 and my >= 245 and my <= 280)
        love.graphics.setColor(hover_lab and {0, 0.7, 1, 0.35} or {0, 0.4, 0.6, 0.12})
        love.graphics.rectangle("fill", 275, 245, 250, 35, 4)
        love.graphics.setColor(0, 0.8, 1, hover_lab and 0.9 or (0.5 + math.sin(timer * 8) * 0.15) + 0.3)
        love.graphics.rectangle("line", 275, 245, 250, 35, 4)
        love.graphics.setColor(1, 1, 1, hover_lab and 1.0 or 0.8)
        love.graphics.printf("CONFIG SOUNDTRACK (LAB)", 275, 256, 250, "center")
    else
        love.graphics.printf("SYSTEM EMPTY", 0, 215, 800, "center")
    end

    for i, d in ipairs(diffs) do
        local sel = (i == selected)
        local y_pos = 300 + (i * 42)
        local hover = (mx >= 300 and mx <= 500 and my >= y_pos and my <= y_pos + 30)
        if sel then
            love.graphics.setColor(d.color[1], d.color[2], d.color[3], 0.8 + math.sin(timer * 20) * 0.2)
            love.graphics.push()
            love.graphics.translate(400, 305 + (i * 42))
            love.graphics.scale(1 + math.sin(timer * 15) * 0.05, 1 + math.sin(timer * 15) * 0.05)
            love.graphics.printf(">> " .. d.name .. " <<", -400, -7, 800, "center")
            love.graphics.pop()
        else
            love.graphics.setColor(d.color[1], d.color[2], d.color[3], hover and 0.7 or 0.22)
            love.graphics.printf(d.name, 0, 305 + (i * 42), 800, "center")
        end
    end

    local hover_start = (mx >= 275 and mx <= 525 and my >= 485 and my <= 530)
    love.graphics.setColor(hover_start and {0, 0.9, 0.4, 0.45} or {0.04, 0.25, 0.1, 0.22})
    love.graphics.rectangle("fill", 275, 485, 250, 45, 4)
    love.graphics.setColor(0, 1, 0.5, hover_start and 1.0 or 0.5)
    love.graphics.rectangle("line", 275, 485, 250, 45, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(FontCache.get(14))
    love.graphics.printf("START MATCH", 275, 499, 250, "center")
end

function GameStates.drawGameOver()
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", 0, 0, 800, 600)
    
    local winner = _G.Winner or "UNKNOWN"
    local pulse = _G.AudioBeatPulse or 0
    
    love.graphics.setFont(FontCache.get(32))
    if winner == "PLAYER" then
        love.graphics.setColor(0, 0.8, 1, 0.7 + pulse * 0.3)
        love.graphics.printf("VICTORY", 0, 200, 800, "center")
    else
        love.graphics.setColor(1, 0.2, 0.2, 0.7 + pulse * 0.3)
        love.graphics.printf("DEFEAT", 0, 200, 800, "center")
    end

    love.graphics.setFont(FontCache.get(14))
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.printf("PRESS R TO RESTART", 0, 320, 800, "center")
end

return GameStates
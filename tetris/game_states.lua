---@diagnostic disable: undefined-global
local TrackManager = require "track_manager" 
local FontCache = require "tetris.font_cache"
local SettingsManager = require "settings_manager"

local GameStates = {}

function GameStates.drawMenu(timer, selected, diffs)
    local mx, my = love.mouse.getPosition()
    local title_scale = 2 + math.sin(timer * 12) * 0.05
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.printf("MUTRIS", 0, 42, 800 / title_scale, "center", 0, title_scale, title_scale)
    
    love.graphics.setFont(FontCache.get(11))
    love.graphics.setColor(0, 0.8, 1, 0.7)
    love.graphics.printf(_G.ENGINE_VERSION or "ETHEREAL ENGINE", 0, 105, 800, "center")

    local current_track = TrackManager.getCurrentTrack() or {
        name = "SYSTEM EMPTY", file_path = "", bpm = 120, root_note = "C", mode = "MINOR"
    }
    love.graphics.setFont(FontCache.get(12))
    love.graphics.setColor(0, 0.8, 1, 0.8)
    love.graphics.printf("< PREV TRACK  |  DRAG & DROP MP3 TO BATCH  |  NEXT TRACK >", 0, 145, 800, "center")
    
    love.graphics.setFont(FontCache.get(15))
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.printf(current_track.name, 0, 168, 800, "center")
    
    love.graphics.setFont(FontCache.get(12))
    love.graphics.setColor(0.5, 0.5, 0.6)
    if current_track.file_path ~= "" then
        love.graphics.printf("BPM: " .. current_track.bpm .. "   |   KEY: " .. current_track.root_note .. " (" .. current_track.mode .. ")", 0, 195, 800, "center")
        
        local hover_lab = (mx >= 275 and mx <= 525 and my >= 222 and my <= 254)
        love.graphics.setColor(hover_lab and {0, 0.7, 1, 0.35} or {0, 0.4, 0.6, 0.12})
        love.graphics.rectangle("fill", 275, 222, 250, 32, 4)
        love.graphics.setColor(0, 0.8, 1, hover_lab and 0.9 or (0.5 + math.sin(timer * 8) * 0.15) + 0.3)
        love.graphics.rectangle("line", 275, 222, 250, 32, 4)
        love.graphics.setColor(1, 1, 1, hover_lab and 1.0 or 0.8)
        love.graphics.printf("CONFIG SOUNDTRACK (LAB)", 275, 230, 250, "center")
    else
        love.graphics.printf("SYSTEM EMPTY", 0, 195, 800, "center")
    end

    for i, d in ipairs(diffs) do
        local sel = (i == selected)
        local y_pos = 270 + (i * 38)
        local hover = (mx >= 300 and mx <= 500 and my >= y_pos and my <= y_pos + 30)
        if sel then
            love.graphics.setColor(d.color[1], d.color[2], d.color[3], 0.8 + math.sin(timer * 20) * 0.2)
            love.graphics.push()
            love.graphics.translate(400, 275 + (i * 38))
            love.graphics.scale(1 + math.sin(timer * 15) * 0.05, 1 + math.sin(timer * 15) * 0.05)
            love.graphics.printf(">> " .. d.name .. " <<", -400, -7, 800, "center")
            love.graphics.pop()
        else
            love.graphics.setColor(d.color[1], d.color[2], d.color[3], hover and 0.7 or 0.22)
            love.graphics.printf(d.name, 0, 275 + (i * 38), 800, "center")
        end
    end

    -- BOTÓN SETTINGS (CALIBRACIÓN DAS/ARR)
    local hover_opt = (mx >= 275 and mx <= 525 and my >= 435 and my <= 470)
    love.graphics.setColor(hover_opt and {0.1, 0.4, 0.7, 0.35} or {0.03, 0.08, 0.15, 0.25})
    love.graphics.rectangle("fill", 275, 435, 250, 35, 4)
    love.graphics.setColor(0, 0.7, 1, hover_opt and 0.9 or 0.4)
    love.graphics.rectangle("line", 275, 435, 250, 35, 4)
    love.graphics.setColor(1, 1, 1, hover_opt and 1.0 or 0.8)
    love.graphics.setFont(FontCache.get(12))
    love.graphics.printf("DAS / ARR SETTINGS", 275, 444, 250, "center")

    -- BOTÓN START MATCH
    local hover_start = (mx >= 275 and mx <= 525 and my >= 485 and my <= 530)
    love.graphics.setColor(hover_start and {0, 0.9, 0.4, 0.45} or {0.04, 0.25, 0.1, 0.22})
    love.graphics.rectangle("fill", 275, 485, 250, 45, 4)
    love.graphics.setColor(0, 1, 0.5, hover_start and 1.0 or 0.5)
    love.graphics.rectangle("line", 275, 485, 250, 45, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(FontCache.get(14))
    love.graphics.printf("START MATCH", 275, 499, 250, "center")
end

function GameStates.drawSettings(timer)
    local mx, my = love.mouse.getPosition()
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.setFont(FontCache.get(22))
    love.graphics.printf("CALIBRATION & SETTINGS", 0, 50, 800, "center")
    
    love.graphics.setFont(FontCache.get(12))
    love.graphics.setColor(0.5, 0.7, 0.9, 0.7)
    love.graphics.printf("COMPETITIVE DAS / ARR & AUDIO ENGINE TUNING", 0, 85, 800, "center")

    local s = SettingsManager.settings
    local rows = {
        { id = "das", label = "DAS (Delayed Auto-Shift)", val = string.format("%d ms", math.floor(s.das * 1000 + 0.5)), min = 50, max = 200, cur = s.das * 1000 },
        { id = "arr", label = "ARR (Auto-Repeat Rate)", val = string.format("%d ms", math.floor(s.arr * 1000 + 0.5)), min = 0, max = 25, cur = s.arr * 1000 },
        { id = "sfx", label = "SFX Volume", val = string.format("%d%%", math.floor(s.sfx_vol * 100)), min = 0, max = 100, cur = s.sfx_vol * 100 },
        { id = "bgm", label = "BGM Volume", val = string.format("%d%%", math.floor(s.bgm_vol * 100)), min = 0, max = 100, cur = s.bgm_vol * 100 }
    }

    for i, r in ipairs(rows) do
        local y = 145 + (i - 1) * 75
        love.graphics.setFont(FontCache.get(13))
        love.graphics.setColor(0.8, 0.9, 1, 0.9)
        love.graphics.print(r.label, 200, y)

        love.graphics.setColor(0.02, 0.05, 0.1, 0.8)
        love.graphics.rectangle("fill", 200, y + 25, 400, 18, 3)
        love.graphics.setColor(0, 0.6, 1, 0.3)
        love.graphics.rectangle("line", 200, y + 25, 400, 18, 3)

        local pct = (r.cur - r.min) / (r.max - r.min)
        pct = math.max(0, math.min(1, pct))
        love.graphics.setColor(0, 0.85, 1, 0.75)
        love.graphics.rectangle("fill", 202, y + 27, 396 * pct, 14, 2)

        love.graphics.setFont(FontCache.get(11))
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.printf(r.val, 200, y + 26, 400, "center")
    end

    -- BOTÓN VOLVER
    local hover_back = (mx >= 300 and mx <= 500 and my >= 490 and my <= 535)
    love.graphics.setColor(hover_back and {0, 0.7, 1, 0.35} or {0.04, 0.1, 0.2, 0.3})
    love.graphics.rectangle("fill", 300, 490, 200, 45, 4)
    love.graphics.setColor(0, 0.8, 1, hover_back and 0.9 or 0.4)
    love.graphics.rectangle("line", 300, 490, 200, 45, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(FontCache.get(13))
    love.graphics.printf("SAVE & RETURN", 300, 504, 200, "center")
end

function GameStates.handleSettingsMouse(mx, my)
    local s = SettingsManager.settings
    local rows = {
        { id = "das", min = 50, max = 200, setter = function(v) s.das = v / 1000 end },
        { id = "arr", min = 0, max = 25, setter = function(v) s.arr = v / 1000 end },
        { id = "sfx", min = 0, max = 100, setter = function(v) s.sfx_vol = v / 100 end },
        { id = "bgm", min = 0, max = 100, setter = function(v) s.bgm_vol = v / 100 end }
    }

    for i, r in ipairs(rows) do
        local y = 145 + (i - 1) * 75 + 25
        if mx >= 200 and mx <= 600 and my >= y and my <= y + 18 then
            local pct = (mx - 200) / 400
            local val = r.min + pct * (r.max - r.min)
            r.setter(val)
            SettingsManager.save()
            return
        end
    end

    if mx >= 300 and mx <= 500 and my >= 490 and my <= 535 then
        SettingsManager.save()
        _G.SetGameState("menu")
    end
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
    love.graphics.printf("PRESS R OR START TO RESTART", 0, 320, 800, "center")
end

return GameStates
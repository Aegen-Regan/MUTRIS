---@diagnostic disable: undefined-global
local TrackManager = require "track_manager" 
local FontCache = require "tetris.font_cache"
local SettingsManager = require "settings_manager"

local GameStates = {}

function GameStates.drawMenu(timer, selected, diffs)
    local mx, my = love.mouse.getPosition()
    local title_scale = 2 + math.sin(timer * 12) * 0.05
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.printf("MUTRIS", 0, 32, 800 / title_scale, "center", 0, title_scale, title_scale)
    
    love.graphics.setFont(FontCache.get(11))
    love.graphics.setColor(0, 0.8, 1, 0.7)
    love.graphics.printf(_G.ENGINE_VERSION or "ETHEREAL ENGINE", 0, 95, 800, "center")

    local current_track = TrackManager.getCurrentTrack() or {
        name = "SYSTEM EMPTY", file_path = "", bpm = 120, root_note = "C", mode = "MINOR"
    }
    love.graphics.setFont(FontCache.get(12))
    love.graphics.setColor(0, 0.8, 1, 0.8)
    love.graphics.printf("< PREV TRACK  |  DRAG & DROP MP3  |  NEXT TRACK >", 0, 130, 800, "center")
    
    love.graphics.setFont(FontCache.get(15))
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.printf(current_track.name, 0, 152, 800, "center")
    
    love.graphics.setFont(FontCache.get(11))
    love.graphics.setColor(0.5, 0.5, 0.6)
    if current_track.file_path ~= "" then
        love.graphics.printf("BPM: " .. current_track.bpm .. "   |   KEY: " .. current_track.root_note .. " (" .. current_track.mode .. ")", 0, 175, 800, "center")
    end

    -- 🎮 SELECTOR DE MODO (VERSUS AI / SPRINT 40L)
    local modes = {
        { id = "versus", name = "VERSUS ADAPTIVE AI", desc = "Combate eSports con IA adaptativa DDA" },
        { id = "sprint", name = "SPRINT 40 LINES", desc = "Time Attack en solitario para medir velocidad pura" }
    }

    for i, m in ipairs(modes) do
        local is_sel = (_G.CURRENT_GAME_MODE == m.id)
        local btn_y = 210 + (i - 1) * 60
        local hover = (mx >= 240 and mx <= 560 and my >= btn_y and my <= btn_y + 48)

        love.graphics.setColor(is_sel and {0.05, 0.4, 0.7, 0.4} or (hover and {0.03, 0.2, 0.35, 0.3} or {0.02, 0.05, 0.1, 0.25}))
        love.graphics.rectangle("fill", 240, btn_y, 320, 48, 4)
        love.graphics.setColor(is_sel and {0, 0.9, 1, 0.9} or (hover and {0, 0.7, 1, 0.6} or {0, 0.5, 0.8, 0.3}))
        love.graphics.rectangle("line", 240, btn_y, 320, 48, 4)

        love.graphics.setFont(FontCache.get(13))
        love.graphics.setColor(is_sel and {1, 1, 1, 1} or {0.7, 0.85, 1, 0.8})
        love.graphics.printf((is_sel and "► " or "") .. m.name, 240, btn_y + 8, 320, "center")
        
        love.graphics.setFont(FontCache.get(10))
        love.graphics.setColor(0.5, 0.6, 0.7)
        love.graphics.printf(m.desc, 240, btn_y + 28, 320, "center")
    end

    -- Récord Personal Sprint (si existe)
    if _G.CURRENT_GAME_MODE == "sprint" and _G.SprintBestTime and _G.SprintBestTime > 0 then
        love.graphics.setFont(FontCache.get(11))
        love.graphics.setColor(1.0, 0.85, 0.2, 0.9)
        love.graphics.printf(string.format("🏆 PERSONAL BEST: %.2fs", _G.SprintBestTime), 0, 335, 800, "center")
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
    love.graphics.printf("START MATCH [SPACE / ENTER]", 275, 499, 250, "center")
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
    love.graphics.setColor(0, 0, 0, 0.92)
    love.graphics.rectangle("fill", 0, 0, 800, 600)
    
    local winner = _G.Winner or "UNKNOWN"
    local pulse = _G.AudioBeatPulse or 0
    
    love.graphics.setFont(FontCache.get(32))
    if _G.CURRENT_GAME_MODE == "sprint" then
        love.graphics.setColor(0, 0.9, 1, 0.9 + pulse * 0.1)
        love.graphics.printf("SPRINT 40L COMPLETE!", 0, 180, 800, "center")
        
        love.graphics.setFont(FontCache.get(20))
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.printf(string.format("FINAL TIME: %.2fs", _G.RealMatchTimer or 0), 0, 240, 800, "center")
        
        if _G.SprintBestTime then
            love.graphics.setFont(FontCache.get(15))
            love.graphics.setColor(1.0, 0.85, 0.2, 0.9)
            love.graphics.printf(string.format("BEST TIME: %.2fs", _G.SprintBestTime), 0, 280, 800, "center")
        end
    else
        if winner == "PLAYER" then
            love.graphics.setColor(0, 0.8, 1, 0.7 + pulse * 0.3)
            love.graphics.printf("VICTORY", 0, 200, 800, "center")
        else
            love.graphics.setColor(1, 0.2, 0.2, 0.7 + pulse * 0.3)
            love.graphics.printf("DEFEAT", 0, 200, 800, "center")
        end
    end

    love.graphics.setFont(FontCache.get(14))
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.printf("PRESS R OR SPACE TO RESTART", 0, 350, 800, "center")
end

return GameStates
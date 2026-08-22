-- ================================================================
-- FILE: scenes/scene_pause.lua
-- ================================================================
---@diagnostic disable: undefined-global
local ScenePause = {}
local ThemeManager = require "tetris.theme_manager"
local AudioManager = require "audio_manager"
local MusicManager = require "music_manager"
local TrackManager = require "track_manager"
local FontCache = require "tetris.font_cache"

ScenePause.selection = 1

ScenePause.items = {
    "RESUME MATCH",
    "RESTART & NEXT TRACK",
    "SETTINGS & CALIBRATION",
    "QUIT TO MAIN MENU"
}

ScenePause.subtitles = {
    "RETURN TO COMBAT IMMEDIATELY [ESC]",
    "RELOAD MATRIX & ROTATE SOUNDTRACK [R]",
    "CALIBRATE DAS, ARR, FX & CAPTURE MODES",
    "ABORT CURRENT MATCH AND RETURN TO TITLE"
}

function ScenePause.draw()
    love.graphics.setColor(0.0, 0.0, 0.0, 0.82)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    local t = ThemeManager.getCurrent()
    local card_w = 500
    local card_h = 440
    local card_x = 640 - (card_w / 2)
    local card_y = 140

    ThemeManager.drawPanel(card_x, card_y, card_w, card_h, "", false)

    love.graphics.setFont(FontCache.get(28))
    love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.95)
    love.graphics.printf("MATCH PAUSED", card_x, card_y + 20, card_w, "center")

    local track_info = TrackManager.getCurrentTrack()
    local track_title = track_info and track_info.name or "UNKNOWN TRACK"
    local track_bpm = track_info and track_info.bpm or 120
    love.graphics.setFont(FontCache.get(11))
    love.graphics.setColor(0.5, 0.65, 0.85, 0.85)
    love.graphics.printf("TRACK: " .. track_title .. " (" .. track_bpm .. " BPM)", card_x, card_y + 58, card_w, "center")

    local btn_w = 420
    local btn_h = 52
    local start_y = card_y + 90
    local spacing = 64

    for i, item in ipairs(ScenePause.items) do
        local is_sel = (i == ScenePause.selection)
        local btn_x = 640 - (btn_w / 2)
        local btn_y = start_y + (i - 1) * spacing

        ThemeManager.drawPanel(btn_x, btn_y, btn_w, btn_h, "", is_sel)

        if is_sel then
            love.graphics.setColor(t.secondary[1], t.secondary[2], t.secondary[3], 0.95)
            love.graphics.rectangle("fill", btn_x + 4, btn_y + 6, 4, btn_h - 12, 2)
            love.graphics.rectangle("fill", btn_x + btn_w - 8, btn_y + 6, 4, btn_h - 12, 2)

            love.graphics.setFont(FontCache.get(15))
            love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
            love.graphics.printf(">  " .. item .. "  <", btn_x, btn_y + 10, btn_w, "center")

            love.graphics.setFont(FontCache.get(9))
            love.graphics.setColor(t.secondary[1], t.secondary[2], t.secondary[3], 0.85)
            love.graphics.printf(ScenePause.subtitles[i] or "", btn_x, btn_y + 32, btn_w, "center")
        else
            love.graphics.setFont(FontCache.get(14))
            love.graphics.setColor(0.7, 0.8, 0.9, 0.8)
            love.graphics.printf(item, btn_x, btn_y + 11, btn_w, "center")

            love.graphics.setFont(FontCache.get(9))
            love.graphics.setColor(0.4, 0.5, 0.6, 0.65)
            love.graphics.printf(ScenePause.subtitles[i] or "", btn_x, btn_y + 32, btn_w, "center")
        end
    end

    love.graphics.setFont(FontCache.get(10))
    love.graphics.setColor(0.45, 0.55, 0.65, 0.8)
    love.graphics.printf("[ ESC ] REANUDAR  |  [ R ] REINICIAR Y CAMBIAR CANCION  |  [ ENTER ] SELECCIONAR", 0, card_y + card_h + 20, 1280, "center")
end

function ScenePause.executeSelection(index)
    local SceneManager = require "core.scene_manager"
    local SceneSettings = require "scenes.scene_settings"

    ScenePause.selection = index
    AudioManager.playMenuClick()

    if index == 1 then
        SceneManager.setState(_G.CURRENT_GAME_MODE or "versus")
        MusicManager.resume()
    elseif index == 2 then
        _G.GlobalRestart(false)
        SceneManager.setState(_G.CURRENT_GAME_MODE or "versus")
    elseif index == 3 then
        SceneSettings.return_state = "pause"
        SceneSettings.active_tab_index = 1
        SceneSettings.active_item_index = 1
        SceneManager.setState("settings")
    elseif index == 4 then
        SceneManager.setState("menu")
        MusicManager.stop()
        MusicManager.start()
    end
end

function ScenePause.keypressed(key)
    if key == "up" then
        ScenePause.selection = (ScenePause.selection == 1) and #ScenePause.items or (ScenePause.selection - 1)
        AudioManager.playMenuHover()
        return true
    elseif key == "down" then
        ScenePause.selection = (ScenePause.selection % #ScenePause.items) + 1
        AudioManager.playMenuHover()
        return true
    elseif key == "return" or key == "space" then
        ScenePause.executeSelection(ScenePause.selection)
        return true
    elseif key == "escape" then
        local SceneManager = require "core.scene_manager"
        SceneManager.setState(_G.CURRENT_GAME_MODE or "versus")
        MusicManager.resume()
        AudioManager.playMenuClick()
        return true
    end
    return false
end

function ScenePause.mousepressed(adj_x, adj_y, button)
    if button ~= 1 then return false end
    local btn_w = 420
    local btn_h = 52
    local start_y = 140 + 90
    local spacing = 64
    for i = 1, #ScenePause.items do
        local bx = 640 - (btn_w / 2)
        local by = start_y + (i - 1) * spacing
        if adj_x >= bx and adj_x <= bx + btn_w and adj_y >= by and adj_y <= by + btn_h then
            ScenePause.executeSelection(i)
            return true
        end
    end
    return false
end

function ScenePause.gamepadpressed(joystick, button)
    if button == "start" or button == "b" then
        local SceneManager = require "core.scene_manager"
        SceneManager.setState(_G.CURRENT_GAME_MODE or "versus")
        MusicManager.resume()
        AudioManager.playMenuClick()
    elseif button == "dpup" then
        ScenePause.selection = (ScenePause.selection == 1) and #ScenePause.items or (ScenePause.selection - 1)
        AudioManager.playMenuHover()
    elseif button == "dpdown" then
        ScenePause.selection = (ScenePause.selection % #ScenePause.items) + 1
        AudioManager.playMenuHover()
    elseif button == "a" then
        ScenePause.executeSelection(ScenePause.selection)
    end
end

return ScenePause
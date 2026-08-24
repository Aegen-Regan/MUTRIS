-- ================================================================
-- FILE: scenes/scene_menu.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: MAIN MENU SCENE
-- Dispatches to Versus, Boss Hunt, Forge, Benchmark, Trainer Lab, Gauntlet, DAW & Settings
-- ============================================================================
local SceneMenu = {}
local ThemeManager = require "tetris.theme_manager"
local AudioManager = require "audio_manager"
local MetaBalancer = require "core.meta_balancer"

SceneMenu.selection = 1

SceneMenu.items = {
    "CAMPAÑA: EL DESCENSO",
    "VS BOT DUEL",
    "CYBER-BEAST HUNT",
    "THE HUNTER'S FORGE",
    "PILOT BENCHMARK",
    "TRAINER LAB & FINESSE",
    "SOUNDTRACK & FX LAB",
    "SETTINGS & CALIBRATION",
    "LOGICAL EDITOR"
}

SceneMenu.subtitles = {
    "50-STAGE ROGUELIKE MAINFRAME VS T.U.N.E.R. AI",
    "CLASSIC 1v1 DUEL VS ADAPTIVE DDA BOT",
    "3-PHASE COLOSSUS ASSAULT & HUNTER'S FORGE",
    "ARMOR JEWEL CRAFTING & CYBER-PALICO BAY",
    "OFFICIAL 3-STAGE PILOT CALIBRATION TRIAL",
    "HOLOGRAPHIC OPENING BOOK, TIME-TRAVEL & KPP COACH",
    "DAW TIMELINE, CUE PLACEMENT & SFX AUDITION",
    "MASTER CALIBRATION SUITE, DAS / ARR & PIPELINE",
    "CUSTOMIZE MATRICES AND GAME RULES DYNAMICALLY"
}

function SceneMenu.draw()
    ThemeManager.drawMenu(SceneMenu.items, SceneMenu.subtitles, SceneMenu.selection, MetaBalancer)
end

function SceneMenu.executeSelection(index)
    local SceneManager = require "core.scene_manager"
    local TrackEditor = require "track_editor"
    local SceneSettings = require "scenes.scene_settings"

    SceneMenu.selection = index
    AudioManager.playMenuClick()

    if index == 1 then
        SceneManager.setState("game", { mode = "campaign" })
    elseif index == 2 then
        SceneManager.setState("game", { mode = "versus" })
    elseif index == 3 then
        SceneManager.setState("game", { mode = "boss_hunt" })
    elseif index == 4 then
        SceneManager.setState("forge")
    elseif index == 5 then
        SceneManager.setState("game", { mode = "benchmark" })
    elseif index == 6 then
        SceneManager.setState("trainer")
    elseif index == 7 then
        TrackEditor.active = true
        SceneManager.setState("editor")
    elseif index == 8 then
        SceneSettings.return_state = "menu"
        SceneSettings.active_tab_index = 1
        SceneSettings.active_item_index = 1
        SceneManager.push("settings")
    elseif index == 9 then
        SceneManager.setState("editor")
    end
end

function SceneMenu.keypressed(key)
    if key == "up" then
        SceneMenu.selection = (SceneMenu.selection == 1) and #SceneMenu.items or (SceneMenu.selection - 1)
        AudioManager.playMenuHover()
        return true
    elseif key == "down" then
        SceneMenu.selection = (SceneMenu.selection % #SceneMenu.items) + 1
        AudioManager.playMenuHover()
        return true
    elseif key == "return" or key == "space" then
        SceneMenu.executeSelection(SceneMenu.selection)
        return true
    elseif key == "escape" then
        love.event.quit()
        return true
    end
    return false
end

function SceneMenu.mousepressed(adj_x, adj_y, button)
    if button ~= 1 then return false end
    local start_y = (ThemeManager.current_theme == 1) and 115 or ((ThemeManager.current_theme == 3) and 95 or 125)
    local spacing = (ThemeManager.current_theme == 1) and 80 or ((ThemeManager.current_theme == 3) and 88 or 74)
    
    for i = 1, #SceneMenu.items do
        local by = start_y + (i - 1) * spacing
        if adj_y >= by and adj_y <= by + 70 and adj_x >= 80 and adj_x <= 750 then
            SceneMenu.executeSelection(i)
            return true
        end
    end
    return false
end

function SceneMenu.gamepadpressed(joystick, button)
    if button == "dpup" then
        SceneMenu.selection = (SceneMenu.selection == 1) and #SceneMenu.items or (SceneMenu.selection - 1)
        AudioManager.playMenuHover()
    elseif button == "dpdown" then
        SceneMenu.selection = (SceneMenu.selection % #SceneMenu.items) + 1
        AudioManager.playMenuHover()
    elseif button == "a" or button == "start" then
        SceneMenu.executeSelection(SceneMenu.selection)
    elseif button == "b" or button == "back" then
        love.event.quit()
    end
end

return SceneMenu
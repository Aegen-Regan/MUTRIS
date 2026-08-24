-- ================================================================
-- FILE: scenes/scene_editor.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: LOGICAL EDITOR MENU
-- Selects configurations from editor_config.lua to pass to scene_game.lua
-- ============================================================================
local SceneEditor = {}

local FontCache = require "tetris.font_cache"
local EditorConfig = require "core.editor_config"
local SceneManager = require "core.scene_manager"
local AudioManager = require "audio_manager"
local ThemeManager = require "tetris.theme_manager"

SceneEditor.selection = 1

function SceneEditor.init()
end

function SceneEditor.enter()
    SceneEditor.selection = 1
end

function SceneEditor.update(dt)
    if ThemeManager.update then ThemeManager.update(dt) end
end

function SceneEditor.draw()
    if ThemeManager.drawBackground then ThemeManager.drawBackground() end

    love.graphics.setFont(FontCache.get(36))
    love.graphics.setColor(1, 0.8, 0, 1)
    love.graphics.printf("LOGICAL EDITOR", 0, 80, 1280, "center")

    love.graphics.setFont(FontCache.get(20))
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.printf("Select a preset payload to load into the Engine:", 0, 140, 1280, "center")

    local y_offset = 240
    for i, preset in ipairs(EditorConfig.presets) do
        if i == SceneEditor.selection then
            love.graphics.setColor(0, 1, 1, 1)
            love.graphics.printf("> " .. preset.name .. " <", 0, y_offset, 1280, "center")
        else
            love.graphics.setColor(0.5, 0.5, 0.5, 1)
            love.graphics.printf(preset.name, 0, y_offset, 1280, "center")
        end
        y_offset = y_offset + 50
    end

    local selected_preset = EditorConfig.presets[SceneEditor.selection]
    if selected_preset then
        love.graphics.setFont(FontCache.get(16))
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        love.graphics.printf(selected_preset.description, 0, y_offset + 50, 1280, "center")
        
        -- Display boards info
        local info = string.format("Mode: %s | Entities: %d", selected_preset.mode, #selected_preset.boards)
        love.graphics.setColor(0.4, 0.8, 1.0, 1)
        love.graphics.printf(info, 0, y_offset + 80, 1280, "center")
    end
end

function SceneEditor.keypressed(key)
    if key == "up" or key == "w" then
        SceneEditor.selection = SceneEditor.selection - 1
        if SceneEditor.selection < 1 then
            SceneEditor.selection = #EditorConfig.presets
        end
        AudioManager.playImmediateSFX("menu_move", false)
    elseif key == "down" or key == "s" then
        SceneEditor.selection = SceneEditor.selection + 1
        if SceneEditor.selection > #EditorConfig.presets then
            SceneEditor.selection = 1
        end
        AudioManager.playImmediateSFX("menu_move", false)
    elseif key == "return" or key == "space" then
        AudioManager.playImmediateSFX("menu_select", false)
        local selected_preset = EditorConfig.presets[SceneEditor.selection]
        SceneManager.setState("game", selected_preset)
    elseif key == "escape" then
        SceneManager.setState("menu")
    end
end

function SceneEditor.exit()
end

return SceneEditor
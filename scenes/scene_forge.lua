-- ================================================================
-- FILE: scenes/scene_forge.lua
-- ================================================================
---@diagnostic disable: undefined-global
local SceneForge = {}
local HuntingForge = require "combat.hunting_forge"
local SceneManager = require "core.scene_manager"
local AudioManager = require "audio_manager"

function SceneForge.draw()
    HuntingForge.drawScreen()
end

function SceneForge.keypressed(key)
    if key == "escape" or key == "b" then
        SceneManager.setState("menu")
        AudioManager.playMenuBack()
        return true
    end

    if HuntingForge.keypressed then
        HuntingForge.keypressed(key)
        return true
    end
    return false
end

function SceneForge.mousepressed(adj_x, adj_y, button)
    if HuntingForge.mousepressed then
        HuntingForge.mousepressed(adj_x, adj_y, button)
        return true
    end
    return false
end

function SceneForge.gamepadpressed(joystick, button)
    if button == "b" or button == "back" then
        SceneManager.setState("menu")
        AudioManager.playMenuBack()
        return true
    end
    return false
end

return SceneForge
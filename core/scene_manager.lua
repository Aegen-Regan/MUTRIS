-- ================================================================
-- FILE: core/scene_manager.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: MASTER SCENE & STATE ORCHESTRATOR
-- Unified lifecycle dispatching with defensive fallback
-- ============================================================================
local SceneManager = {}
local Blackbox = require "core.blackbox"

local current_state = "menu"
local previous_state = "menu"
local scenes = {}

local function safeRequireScene(mod_name)
    local ok, mod = pcall(require, "scenes." .. mod_name)
    if ok and type(mod) == "table" then return mod end

    local ok2, mod2 = pcall(require, "core.scenes." .. mod_name)
    if ok2 and type(mod2) == "table" then return mod2 end

    error("\n\n[MUTRIS CRITICAL ERROR]: No se encontro la escena 'scenes/" .. mod_name .. ".lua'\n")
end

function SceneManager.init()
    scenes["menu"]             = safeRequireScene("scene_menu")
    scenes["settings"]         = safeRequireScene("scene_settings")
    scenes["pause"]            = safeRequireScene("scene_pause")
    scenes["gameover"]         = safeRequireScene("scene_gameover")
    scenes["forge"]            = safeRequireScene("scene_forge")
    scenes["editor"]           = safeRequireScene("scene_editor")
    scenes["benchmark_result"] = safeRequireScene("scene_benchmark")
    scenes["trainer"] = safeRequireScene("scene_trainer")
    
    for _, scene in pairs(scenes) do
        if scene and scene.init then scene.init() end
    end
end

function SceneManager.setState(new_state)
    if current_state == new_state then return end
    
    local old_scene = scenes[current_state]
    if old_scene and old_scene.onExit then
        old_scene.onExit()
    end

    previous_state = current_state
    current_state = new_state

    local next_scene = scenes[current_state]
    if next_scene and next_scene.onEnter then
        next_scene.onEnter()
    end

    Blackbox.log("STATE", "SCENE SWITCH: " .. new_state, 0, 0)
end

function SceneManager.getState()
    return current_state
end

function SceneManager.getPreviousState()
    return previous_state
end

function SceneManager.getScene(name)
    return scenes[name or current_state]
end

function SceneManager.update(dt)
    local scene = scenes[current_state]
    if scene and scene.update then
        scene.update(dt)
    end
end

function SceneManager.draw()
    local scene = scenes[current_state]
    if scene and scene.draw then
        scene.draw()
    end
end

function SceneManager.keypressed(key)
    local scene = scenes[current_state]
    if scene and scene.keypressed then
        return scene.keypressed(key)
    end
    return false
end

function SceneManager.mousepressed(x, y, button)
    local scene = scenes[current_state]
    if scene and scene.mousepressed then
        return scene.mousepressed(x, y, button)
    end
    return false
end

function SceneManager.gamepadpressed(joystick, button)
    local scene = scenes[current_state]
    if scene and scene.gamepadpressed then
        return scene.gamepadpressed(joystick, button)
    end
    return false
end

return SceneManager
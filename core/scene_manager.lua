-- ================================================================
-- FILE: core/scene_manager.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: MASTER SCENE & STATE ORCHESTRATOR
-- Unified lifecycle dispatching with dynamic registration & defensive fallback
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

    return nil
end

function SceneManager.init()
    -- Carga perezosa de escenas base
    scenes["menu"]             = safeRequireScene("scene_menu")
    scenes["campaign"]         = safeRequireScene("scene_campaign")
    scenes["versus"]           = safeRequireScene("scene_bot_vs_bot")
    scenes["bot_vs_bot"]       = scenes["versus"]
    scenes["boss_hunt"]        = safeRequireScene("scene_boss_hunt")
    scenes["settings"]         = safeRequireScene("scene_settings")
    scenes["pause"]            = safeRequireScene("scene_pause")
    scenes["gameover"]         = safeRequireScene("scene_gameover")
    scenes["forge"]            = safeRequireScene("scene_forge")
    scenes["editor"]           = safeRequireScene("scene_soundtrack") or safeRequireScene("scene_editor")
    scenes["soundtrack"]       = scenes["editor"]
    scenes["benchmark_result"] = safeRequireScene("scene_benchmark")
    scenes["benchmark"]        = scenes["benchmark_result"]
    scenes["trainer"]          = safeRequireScene("scene_trainer")
    scenes["sandbox"]          = safeRequireScene("scene_sandbox")

    for _, scene in pairs(scenes) do
        if scene and scene.init then scene.init() end
    end
end

function SceneManager.register(name, scene_obj)
    if not name then return end
    scenes[name] = scene_obj
    if scene_obj and scene_obj.init then
        scene_obj.init()
    end
end

function SceneManager.setState(new_state)
    if current_state == new_state then return end
    
    local old_scene = scenes[current_state]
    if old_scene then
        if old_scene.onExit then old_scene.onExit() end
        if old_scene.exit then old_scene.exit() end
    end

    previous_state = current_state
    current_state = new_state

    local next_scene = scenes[current_state]
    if next_scene then
        if next_scene.onEnter then next_scene.onEnter() end
        if next_scene.enter then next_scene.enter() end
    end

    Blackbox.log("STATE", "SCENE SWITCH: " .. tostring(new_state), 0, 0)
end

-- ALIASES DE COMPATIBILIDAD
SceneManager.switch = SceneManager.setState
SceneManager.switchState = SceneManager.setState

function SceneManager.getState()
    return current_state
end

function SceneManager.getCurrentName()
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
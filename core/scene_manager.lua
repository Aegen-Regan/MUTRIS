-- ================================================================
-- FILE: core/scene_manager.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: MASTER SCENE & STATE ORCHESTRATOR (V2)
-- Stack-based architecture for nested sub-scenes & dynamic registration
-- ============================================================================
local SceneManager = {}
local Blackbox = require "core.blackbox"

local scenes = {}
local stack = {} -- Array of active scenes: { id = string, instance = table, data = table }

local function safeRequireScene(mod_name)
    local ok, mod = pcall(require, "scenes." .. mod_name)
    if ok and type(mod) == "table" then return mod end

    local ok2, mod2 = pcall(require, "core.scenes." .. mod_name)
    if ok2 and type(mod2) == "table" then return mod2 end

    return nil
end

function SceneManager.init()
    -- Base scenes dynamic loading (can be expanded easily)
    local base_scenes = {
        "menu", "campaign", "boss_hunt", "settings", "pause", 
        "gameover", "forge", "sandbox", "trainer"
    }

    for _, name in ipairs(base_scenes) do
        local s = safeRequireScene("scene_" .. name)
        if s then
            SceneManager.register(name, s)
        end
    end
    
    -- Legacy aliases and fallbacks
    local bot_vs_bot = safeRequireScene("scene_bot_vs_bot")
    if bot_vs_bot then
        SceneManager.register("versus", bot_vs_bot)
        SceneManager.register("bot_vs_bot", bot_vs_bot)
    end
    
    local editor = safeRequireScene("scene_soundtrack") or safeRequireScene("scene_editor")
    if editor then
        SceneManager.register("editor", editor)
        SceneManager.register("soundtrack", editor)
    end
    
    local bench = safeRequireScene("scene_benchmark")
    if bench then
        SceneManager.register("benchmark", bench)
        SceneManager.register("benchmark_result", bench)
    end
end

function SceneManager.register(name, scene_obj)
    if not name or not scene_obj then return end
    scenes[name] = scene_obj
    if scene_obj.init then
        scene_obj.init()
    end
    Blackbox.log("SCENE", "Registered scene: " .. name, 0, 0)
end

-- Completely replaces the stack with a single new scene
function SceneManager.setState(new_state, data)
    -- Exit all currently active scenes from top to bottom
    for i = #stack, 1, -1 do
        local s = stack[i].instance
        if s.onExit then s.onExit() end
        if s.exit then s.exit() end
        stack[i] = nil
    end

    local next_scene = scenes[new_state]
    if next_scene then
        table.insert(stack, { id = new_state, instance = next_scene, data = data or {} })
        if next_scene.onEnter then next_scene.onEnter(data) end
        if next_scene.enter then next_scene.enter(data) end
        Blackbox.log("STATE", "SCENE SWITCH: " .. tostring(new_state), 0, 0)
    else
        Blackbox.log("ERROR", "Attempted to set unknown state: " .. tostring(new_state), 0, 0)
    end
end

-- Pushes a sub-scene on top of the current one
function SceneManager.push(new_state, data)
    local next_scene = scenes[new_state]
    if next_scene then
        table.insert(stack, { id = new_state, instance = next_scene, data = data or {} })
        if next_scene.onEnter then next_scene.onEnter(data) end
        if next_scene.enter then next_scene.enter(data) end
        Blackbox.log("STATE", "SCENE PUSHED: " .. tostring(new_state), 0, 0)
    else
        Blackbox.log("ERROR", "Attempted to push unknown sub-scene: " .. tostring(new_state), 0, 0)
    end
end

-- Pops the top sub-scene, returning focus to the previous one
function SceneManager.pop()
    if #stack <= 1 then return end -- Don't pop the base scene
    local top = table.remove(stack)
    if top.instance.onExit then top.instance.onExit() end
    if top.instance.exit then top.instance.exit() end
    Blackbox.log("STATE", "SCENE POPPED: " .. tostring(top.id), 0, 0)
    
    -- Notify the newly exposed top scene that it has resumed (optional hook)
    if #stack > 0 then
        local current = stack[#stack].instance
        if current.resume then current.resume() end
    end
end

-- ALIASES DE COMPATIBILIDAD
SceneManager.switch = SceneManager.setState
SceneManager.switchState = SceneManager.setState

function SceneManager.getState()
    if #stack > 0 then return stack[#stack].id end
    return "none"
end

function SceneManager.getCurrentName()
    return SceneManager.getState()
end

-- Helper to get the previous state name for legacy support
function SceneManager.getPreviousState()
    if #stack > 1 then
        return stack[#stack - 1].id
    end
    return "menu"
end

function SceneManager.getScene(name)
    return scenes[name] or (#stack > 0 and stack[#stack].instance or nil)
end

function SceneManager.update(dt)
    -- Typically only the top scene updates, but you could iterate if needed.
    -- For now, update ONLY the top scene to pause background logic.
    if #stack > 0 then
        local scene = stack[#stack].instance
        if scene.update then
            scene.update(dt)
        end
    end
end

function SceneManager.draw()
    -- Draw all scenes in the stack from bottom to top (backgrounds first)
    for i = 1, #stack do
        local scene = stack[i].instance
        if scene.draw then
            scene.draw()
        end
    end
end

function SceneManager.keypressed(key)
    if #stack > 0 then
        local scene = stack[#stack].instance
        if scene.keypressed then
            return scene.keypressed(key)
        end
    end
    return false
end

function SceneManager.keyreleased(key)
    if #stack > 0 then
        local scene = stack[#stack].instance
        if scene.keyreleased then
            return scene.keyreleased(key)
        end
    end
    return false
end

function SceneManager.mousepressed(x, y, button)
    if #stack > 0 then
        local scene = stack[#stack].instance
        if scene.mousepressed then
            return scene.mousepressed(x, y, button)
        end
    end
    return false
end

function SceneManager.gamepadpressed(joystick, button)
    if #stack > 0 then
        local scene = stack[#stack].instance
        if scene.gamepadpressed then
            return scene.gamepadpressed(joystick, button)
        end
    end
    return false
end

return SceneManager
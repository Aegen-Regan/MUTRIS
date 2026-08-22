-- ================================================================
-- FILE: scenes/scene_benchmark.lua
-- ================================================================
---@diagnostic disable: undefined-global
local SceneBenchmark = {}
local BenchmarkManager = require "core.benchmark_manager"
local SceneManager = require "core.scene_manager"
local AudioManager = require "audio_manager"

function SceneBenchmark.draw()
    BenchmarkManager.drawResultModal()
end

function SceneBenchmark.keypressed(key)
    if key == "escape" or key == "return" or key == "space" then
        BenchmarkManager.is_active = false
        SceneManager.setState("menu")
        AudioManager.playMenuBack()
        return true
    end
    return false
end

function SceneBenchmark.mousepressed(adj_x, adj_y, button)
    if button == 1 then
        BenchmarkManager.is_active = false
        SceneManager.setState("menu")
        AudioManager.playMenuBack()
        return true
    end
    return false
end

function SceneBenchmark.gamepadpressed(joystick, button)
    if button == "a" or button == "start" or button == "b" then
        BenchmarkManager.is_active = false
        SceneManager.setState("menu")
        AudioManager.playMenuBack()
        return true
    end
    return false
end

return SceneBenchmark
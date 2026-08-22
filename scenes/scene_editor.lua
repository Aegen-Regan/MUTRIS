-- ================================================================
-- FILE: scenes/scene_editor.lua
-- ================================================================
---@diagnostic disable: undefined-global
local SceneEditor = {}
local TrackEditor = require "track_editor"

function SceneEditor.onEnter()
    TrackEditor.active = true
end

function SceneEditor.onExit()
    TrackEditor.active = false
end

function SceneEditor.update(dt)
    TrackEditor.update(dt)
end

function SceneEditor.draw()
    TrackEditor.draw()
end

function SceneEditor.keypressed(key)
    TrackEditor.keypressed(key)
    return true
end

function SceneEditor.mousepressed(adj_x, adj_y, button)
    TrackEditor.mousepressed(adj_x, adj_y, button)
    return true
end

return SceneEditor
-- ================================================================
-- FILE: tetris/fog_layer.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: VOLUMETRIC FOG LAYER (1280x720 WIDESCREEN)
-- Arquitectura: Zero-GC / Niebla Reactiva a Camelot & Beat
-- ============================================================================
local FogLayer = {}
local TrackManager    = require "track_manager"
local SettingsManager = require "settings_manager"

local NUM_FOG_NODES = 16
local nodes = {}

function FogLayer.init()
    for i = 1, NUM_FOG_NODES do
        nodes[i] = {
            x = (i / NUM_FOG_NODES) * 1280,
            y = 200 + math.sin(i * 1.5) * 150,
            radius = 160 + math.random(50, 110),
            speed = 0.2 + (i % 3) * 0.15,
            phase = i * 0.5
        }
    end
end

function FogLayer.update(dt)
    local energy = _G.TrackEnergyPunch or 0
    for i = 1, NUM_FOG_NODES do
        local n = nodes[i]
        n.phase = n.phase + dt * n.speed * (1.0 + energy * 2.0)
        n.y = 360 + math.sin(n.phase) * (100 + energy * 50)
    end
end

function FogLayer.draw()
    local fog_setting = SettingsManager.get("fog_mode")
    if fog_setting == 0 or fog_setting == false then return end

    local track = TrackManager.getCurrentTrack()
    local base_color = {0.1, 0.4, 0.9}
    if track and TrackManager.NOTE_COLORS and track.root_note then
        base_color = TrackManager.NOTE_COLORS[track.root_note] or base_color
    end

    local pulse = _G.AudioBeatPulse or 0
    local energy = _G.TrackEnergyPunch or 0

    love.graphics.push("all")
    love.graphics.setBlendMode("add")

    for i = 1, NUM_FOG_NODES do
        local n = nodes[i]
        local dynamic_rad = n.radius * (1.0 + pulse * 0.15 * (0.5 + energy * 0.5))
        local alpha = (0.035 + pulse * 0.04 + energy * 0.05)

        love.graphics.setColor(base_color[1], base_color[2], base_color[3], alpha)
        love.graphics.circle("fill", n.x, n.y, dynamic_rad)
    end

    if energy > 0.05 then
        love.graphics.setColor(base_color[1] * 1.2, base_color[2] * 0.8, base_color[3] * 1.3, energy * 0.10 * (0.7 + pulse * 0.3))
        love.graphics.rectangle("fill", 0, 0, 1280, 720)
    end

    love.graphics.setBlendMode("alpha")
    love.graphics.pop()
end

return FogLayer
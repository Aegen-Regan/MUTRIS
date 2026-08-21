-- ================================================================
-- FILE: tetris/fog_layer.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: VOLUMETRIC FOG & ATMOSPHERIC VIGNETTE (1280x720)
-- Arquitectura: Zero-GC / Vignette Dinámica Reactiva al Beat y Skin
-- ============================================================================
local FogLayer = {}
local SettingsManager = require "settings_manager"
local ThemeManager    = require "tetris.theme_manager"

local NUM_FOG_NODES = 12
local nodes = {}

function FogLayer.init()
    for i = 1, NUM_FOG_NODES do
        nodes[i] = {
            x = (i / NUM_FOG_NODES) * 1280,
            y = 360 + math.sin(i * 1.5) * 180,
            radius = 180 + (i % 4) * 40,
            speed = 0.15 + (i % 3) * 0.1,
            phase = i * 0.5
        }
    end
end

function FogLayer.update(dt)
    local energy = _G.TrackEnergyPunch or 0
    for i = 1, NUM_FOG_NODES do
        local n = nodes[i]
        n.phase = n.phase + dt * n.speed * (1.0 + energy * 1.8)
        n.y = 360 + math.sin(n.phase) * (80 + energy * 40)
    end
end

function FogLayer.draw()
    local fog_setting = SettingsManager.get("fog_mode")
    if fog_setting == 0 or fog_setting == false then return end

    local t = ThemeManager.getCurrent()
    local pulse = _G.AudioBeatPulse or 0
    local energy = _G.TrackEnergyPunch or 0
    local base_color = t.primary or {0.0, 0.8, 1.0}

    love.graphics.push("all")
    love.graphics.setBlendMode("add")

    -- Resplandor ambiental suave en laterales
    for i = 1, NUM_FOG_NODES do
        local n = nodes[i]
        local dynamic_rad = n.radius * (1.0 + pulse * 0.10)
        local alpha = (0.015 + pulse * 0.02 + energy * 0.025)

        love.graphics.setColor(base_color[1], base_color[2], base_color[3], alpha)
        love.graphics.circle("fill", n.x, n.y, dynamic_rad)
    end

    -- Flash de energía en Beat Drop
    if energy > 0.1 then
        love.graphics.setColor(base_color[1], base_color[2], base_color[3], energy * 0.04 * (0.8 + pulse * 0.2))
        love.graphics.rectangle("fill", 0, 0, 1280, 720)
    end

    love.graphics.setBlendMode("alpha")
    love.graphics.pop()
end

return FogLayer
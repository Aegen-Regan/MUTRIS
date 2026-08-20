---@diagnostic disable: undefined-global
local FogLayer = {}
local TrackManager = require "track_manager"

local NUM_FOG_NODES = 12
local nodes = {}

function FogLayer.init()
    for i = 1, NUM_FOG_NODES do
        nodes[i] = {
            x = (i / NUM_FOG_NODES) * 800,
            y = 150 + math.sin(i * 1.5) * 120,
            radius = 120 + math.random(40, 90),
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
        n.y = 300 + math.sin(n.phase) * (80 + energy * 40)
    end
end

function FogLayer.draw()
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
        local alpha = (0.04 + pulse * 0.05 + energy * 0.06)

        love.graphics.setColor(base_color[1], base_color[2], base_color[3], alpha)
        love.graphics.circle("fill", n.x, n.y, dynamic_rad)
    end

    if energy > 0.05 then
        love.graphics.setColor(base_color[1] * 1.2, base_color[2] * 0.8, base_color[3] * 1.3, energy * 0.12 * (0.7 + pulse * 0.3))
        love.graphics.rectangle("fill", 0, 0, 800, 600)
    end

    love.graphics.setBlendMode("alpha")
    love.graphics.pop()
end

return FogLayer
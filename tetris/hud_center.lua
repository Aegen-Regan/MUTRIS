-- ================================================================
-- FILE: tetris/hud_center.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: CENTER VS BADGE & PPS COMPARATOR (1280x720 WIDESCREEN)
-- 4 Estilos: CRT Mini-Oscilloscope / Arcade Versus / Esports Board / Mandala
-- ============================================================================
local HUDCenter = {}
local FontCache    = require "tetris.font_cache"
local ThemeManager = require "tetris.theme_manager"

function HUDCenter.draw(player, bot)
    local t = ThemeManager.getCurrent()
    local theme_idx = ThemeManager.current_theme
    local pulse = _G.AudioBeatPulse or 0
    local energy = _G.TrackEnergyPunch or 0
    local time = love.timer.getTime()

    local p1_val = (player and player.current_pps_display) or 0.0
    local bot_val = (bot and bot.current_pps_display) or 0.0
    local p1_better = p1_val >= bot_val

    love.graphics.push("all")
    love.graphics.translate(640, 145)

    -- ────────────────────────────────────────────────────────────────────────
    -- SKIN 1: CYBER-DAW (Mini-Monitor CRT con Onda de Audio Activa)
    -- ────────────────────────────────────────────────────────────────────────
    if theme_idx == 1 then
        love.graphics.setColor(0.015, 0.025, 0.04, 0.95)
        love.graphics.rectangle("fill", -65, -24, 130, 48, 2)
        love.graphics.setLineWidth(1.5)
        love.graphics.setColor(0, 1.0, 0.55, 0.5 + pulse * 0.3)
        love.graphics.rectangle("line", -65, -24, 130, 48, 2)

        -- Mini traza senoidal central
        love.graphics.setBlendMode("add")
        love.graphics.setColor(0, 1.0, 0.55, 0.3 + pulse * 0.4)
        for x = -20, 20, 4 do
            local y = math.sin(time * 8 + x * 0.2) * (4 + pulse * 6)
            love.graphics.rectangle("fill", x, y, 2, 2)
        end
        love.graphics.setBlendMode("alpha")

        love.graphics.setFont(FontCache.get(12))
        love.graphics.setColor(0, 1.0, 0.55, 0.95)
        love.graphics.printf(string.format("%.1f", p1_val), -62, -10, 36, "center")

        love.graphics.setColor(1, 0.8, 0.0, 0.95)
        love.graphics.printf(string.format("%.1f", bot_val), 26, -10, 36, "center")

        love.graphics.setFont(FontCache.get(8))
        love.graphics.setColor(0.6, 0.8, 0.7, 0.7)
        love.graphics.printf("PPS GAIN", -30, 12, 60, "center")

    -- ────────────────────────────────────────────────────────────────────────
    -- SKIN 2: NEO-KINETIC (Emblema Arcade Fighting VS con Picos Slashed)
    -- ────────────────────────────────────────────────────────────────────────
    elseif theme_idx == 2 then
        love.graphics.setColor(0.08, 0.08, 0.12, 0.96)
        love.graphics.polygon("fill", -70, -22, 70, -22, 55, 26, -85, 26)
        love.graphics.setColor(1.0, 0.08, 0.25, 0.9)
        love.graphics.setLineWidth(2.5)
        love.graphics.polygon("line", -70, -22, 70, -22, 55, 26, -85, 26)

        love.graphics.setFont(FontCache.get(14))
        love.graphics.setColor(1.0, 0.85, 0.0, 1.0)
        love.graphics.printf("VS", -15, -9, 30, "center")

        love.graphics.setFont(FontCache.get(13))
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(string.format("%.1f", p1_val), -65, -9, 36, "center")
        love.graphics.setColor(1.0, 0.15, 0.3, 1)
        love.graphics.printf(string.format("%.1f", bot_val), 25, -9, 36, "center")

        love.graphics.setFont(FontCache.get(8))
        love.graphics.setColor(1, 0.85, 0, 0.8)
        love.graphics.printf("SPEED", -20, 12, 40, "center")

    -- ────────────────────────────────────────────────────────────────────────
    -- SKIN 3: ESPORTS GLASS (Marcador Broadcast de Precisión)
    -- ────────────────────────────────────────────────────────────────────────
    elseif theme_idx == 3 then
        love.graphics.setColor(0.01, 0.02, 0.05, 0.88)
        love.graphics.rectangle("fill", -60, -20, 120, 40, 6)
        love.graphics.setLineWidth(1.4)
        love.graphics.setColor(0.0, 0.9, 1.0, 0.35 + pulse * 0.3)
        love.graphics.rectangle("line", -60, -20, 120, 40, 6)

        love.graphics.setFont(FontCache.get(9))
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.printf("VS", -15, -7, 30, "center")

        love.graphics.setFont(FontCache.get(13))
        love.graphics.setColor(p1_better and {0, 0.95, 1, 0.95} or {1, 0.35, 0.35, 0.85})
        love.graphics.printf(string.format("%.1f", p1_val), -55, -8, 36, "center")

        love.graphics.setColor(not p1_better and {1, 0.3, 0.4, 0.95} or {0.5, 0.65, 0.8, 0.8})
        love.graphics.printf(string.format("%.1f", bot_val), 20, -8, 36, "center")

        love.graphics.setFont(FontCache.get(8))
        love.graphics.setColor(0.0, 0.9, 1.0, 0.7)
        love.graphics.printf("PPS", -20, 10, 40, "center")

    -- ────────────────────────────────────────────────────────────────────────
    -- SKIN 4: SINESTESIA CÓSMICA (Mandala Sagrado Pulsante)
    -- ────────────────────────────────────────────────────────────────────────
    elseif theme_idx == 4 then
        love.graphics.setBlendMode("add")
        local mandala_rad = 36 + pulse * 14
        love.graphics.setColor(0.6, 0.35, 1.0, 0.25 + pulse * 0.25)
        love.graphics.circle("line", 0, 0, mandala_rad)
        love.graphics.setColor(0.1, 0.9, 1.0, 0.20)
        love.graphics.circle("line", 0, 0, mandala_rad * 1.3)
        love.graphics.setBlendMode("alpha")

        love.graphics.setColor(0.01, 0.01, 0.03, 0.90)
        love.graphics.rectangle("fill", -54, -18, 108, 36, 6)
        love.graphics.setColor(0.6, 0.35, 1.0, 0.6)
        love.graphics.rectangle("line", -54, -18, 108, 36, 6)

        love.graphics.setFont(FontCache.get(12))
        love.graphics.setColor(0.1, 0.9, 1.0, 0.95)
        love.graphics.printf(string.format("%.1f", p1_val), -50, -8, 34, "center")
        love.graphics.setColor(0.6, 0.35, 1.0, 0.95)
        love.graphics.printf(string.format("%.1f", bot_val), 16, -8, 34, "center")

        love.graphics.setFont(FontCache.get(8))
        love.graphics.setColor(1.0, 0.85, 0.25, 0.8)
        love.graphics.printf("HARMONY", -25, 8, 50, "center")
    end

    love.graphics.pop()
end

return HUDCenter
-- ================================================================
-- FILE: scenes/scene_editor.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: LOGICAL EDITOR & PRESET PAYLOAD SELECTOR
-- ============================================================================
local SceneEditor = {}

local ThemeManager = require "tetris.theme_manager"
local FontCache    = require "tetris.font_cache"
local AudioManager = require "audio_manager"
local SceneManager = require "core.scene_manager"
local Blackbox     = require "core.blackbox"

SceneEditor.selection = 1

SceneEditor.PRESETS = {
    {
        id = "versus_1v1",
        title = "Classic Versus 1v1",
        desc = "Standard 10x40 matrix duel against a normal AI.",
        info = "Mode: versus | Entities: 2",
        payload = {
            mode = "versus",
            return_scene = "editor",
            layout_style = "versus",
            boards = {
                { type = "human", cols = 10, rows = 40, ai_profile = nil },
                { type = "bot",   cols = 10, rows = 40, ai_profile = "normal" }
            }
        }
    },
    {
        id = "tiny_blitz",
        title = "Tiny Matrix Blitz",
        desc = "Ultra-narrow 6x24 speed matrices for micro-reflex testing.",
        info = "Mode: versus | Entities: 2 (Compact 6x24)",
        payload = {
            mode = "versus",
            return_scene = "editor",
            layout_style = "tiny",
            boards = {
                { type = "human", cols = 6, rows = 24, ai_profile = nil },
                { type = "bot",   cols = 6, rows = 24, ai_profile = "normal" }
            }
        }
    },
    {
        id = "gigantic_boss",
        title = "Gigantic Boss Raid",
        desc = "David vs Goliath: Compact player matrix against a Colossal Titan Boss.",
        info = "Mode: boss_hunt | Entities: 2 (Asymmetric Scale)",
        payload = {
            mode = "boss_hunt",
            return_scene = "editor",
            layout_style = "gigantic_boss",
            boards = {
                { type = "human", cols = 10, rows = 40, scale_tier = "human" },
                { type = "bot",   cols = 18, rows = 40, scale_tier = "titan_boss", ai_profile = "boss" }
            }
        }
    },
    {
        id = "multibot_1v2",
        title = "Multi-Bot Deathmatch (1v2)",
        desc = "Survive against two simultaneous AI bots with clean multi-grid view.",
        info = "Mode: multibot | Entities: 3 (1v2 Tri-Board)",
        payload = {
            mode = "multibot",
            return_scene = "editor",
            layout_style = "multibot",
            boards = {
                { type = "human", cols = 10, rows = 40, ai_profile = nil },
                { type = "bot",   cols = 10, rows = 40, ai_profile = "easy" },
                { type = "bot",   cols = 10, rows = 40, ai_profile = "normal" }
            }
        }
    }
}

function SceneEditor.init()
    SceneEditor.selection = 1
end

function SceneEditor.enter()
    Blackbox.log("SCENE", "Entered Logical Editor Selector", 0, 0)
end

function SceneEditor.update(dt)
end

function SceneEditor.draw()
    ThemeManager.drawBackground()
    local t = ThemeManager.getCurrent()
    local time = love.timer.getTime()
    local pulse = _G.AudioBeatPulse or 0

    love.graphics.push("all")

    -- Título
    love.graphics.setFont(FontCache.get(28))
    love.graphics.setColor(1.0, 0.85, 0.0, 0.98)
    love.graphics.printf("LOGICAL EDITOR", 0, 45, 1280, "center")

    love.graphics.setFont(FontCache.get(11))
    love.graphics.setColor(1, 1, 1, 0.75)
    love.graphics.printf("Select a preset payload to load into the Engine:", 0, 85, 1280, "center")

    -- Opciones de Presets
    local total = #SceneEditor.PRESETS
    local start_y = 175
    local spacing = 65

    for i = 1, total do
        local p = SceneEditor.PRESETS[i]
        local is_sel = (i == SceneEditor.selection)
        local y = start_y + (i - 1) * spacing

        if is_sel then
            local flash = math.sin(time * 6) * 0.15 + 0.85
            love.graphics.setFont(FontCache.get(16))
            love.graphics.setColor(0.1, 0.95, 1.0, flash)
            love.graphics.printf(string.format(">  %s  <", p.title), 0, y, 1280, "center")
        else
            love.graphics.setFont(FontCache.get(14))
            love.graphics.setColor(0.5, 0.6, 0.7, 0.65)
            love.graphics.printf(p.title, 0, y, 1280, "center")
        end
    end

    -- Tarjeta de Detalles del Preset Seleccionado
    local cur = SceneEditor.PRESETS[SceneEditor.selection]
    if cur then
        local bx, by, bw, bh = 340, 480, 600, 110
        ThemeManager.drawPanel(bx, by, bw, bh, "", true)

        love.graphics.setFont(FontCache.get(11))
        love.graphics.setColor(1, 1, 1, 0.95)
        love.graphics.printf(cur.desc, bx + 16, by + 22, bw - 32, "center")

        love.graphics.setFont(FontCache.get(10))
        love.graphics.setColor(0.1, 0.95, 1.0, 0.90)
        love.graphics.printf(cur.info, bx + 16, by + 68, bw - 32, "center")
    end

    -- Footer de Controles
    love.graphics.setFont(FontCache.get(9))
    love.graphics.setColor(0.5, 0.6, 0.7, 0.75)
    love.graphics.printf("[ UP / DOWN ] NAVEGAR   |   [ ENTER / SPACE ] CARGAR MODO   |   [ ESC ] SALIR AL MENÚ", 0, 635, 1280, "center")

    love.graphics.pop()
end

function SceneEditor.keypressed(key)
    if key == "up" then
        SceneEditor.selection = (SceneEditor.selection == 1) and #SceneEditor.PRESETS or (SceneEditor.selection - 1)
        AudioManager.playImmediateSFX("move", false)
    elseif key == "down" then
        SceneEditor.selection = (SceneEditor.selection % #SceneEditor.PRESETS) + 1
        AudioManager.playImmediateSFX("move", false)
    elseif key == "return" or key == "space" then
        local p = SceneEditor.PRESETS[SceneEditor.selection]
        if p and p.payload then
            AudioManager.playImmediateSFX("rotate", false)
            SceneManager.setState("game", p.payload)
        end
    elseif key == "escape" then
        AudioManager.playMenuBack()
        SceneManager.setState("menu")
    end
end

return SceneEditor
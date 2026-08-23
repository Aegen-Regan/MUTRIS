-- ================================================================
-- FILE: scenes/scene_gameover.lua
-- ================================================================
---@diagnostic disable: undefined-global
local SceneGameOver = {}

local ThemeManager = require("tetris.theme_manager")
local AudioManager = require("audio_manager")
local MusicManager = require("music_manager")
local PartBreaking = require("combat.part_breaking")
local PoiseSystem  = require("combat.poise_system")
local BossPhases   = require("combat.boss_phases")
local FontCache    = require("tetris.font_cache")
local SceneManager = require("core.scene_manager")
local TrackManager = require("track_manager")

function SceneGameOver.init() end
function SceneGameOver.enter()
    AudioManager.playImmediateSFX("death", false)
end
function SceneGameOver.onEnter() SceneGameOver.enter() end
function SceneGameOver.update(dt) ThemeManager.update(dt) end

function SceneGameOver.draw()
    local PlayerBoard = _G.LAST_PLAYER_BOARD
    local BotBoard    = _G.LAST_BOT_BOARD

    local t = ThemeManager.getCurrent()
    local is_victory = (BotBoard and (BotBoard.is_dying or BotBoard.is_dead))
                    or (_G.CURRENT_GAME_MODE == "boss_hunt" and BossPhases.current_phase == 3 and PoiseSystem.hp <= 0)

    -- Fondo semitransparente oscuro
    love.graphics.setColor(0.01, 0.015, 0.03, 0.92)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    local modal_w, modal_h = 560, 300
    local modal_x = 640 - (modal_w / 2)
    local modal_y = 200

    ThemeManager.drawPanel(modal_x, modal_y, modal_w, modal_h, "", is_victory)

    love.graphics.setFont(FontCache.get(28))
    if is_victory then
        local win_title = (_G.CURRENT_GAME_MODE == "boss_hunt") and "CYBER-BEAST SLAIN" or "VICTORY ACHIEVED"
        love.graphics.setColor(0.1, 1.0, 0.5, 0.98)
        love.graphics.printf(win_title, 0, modal_y + 24, 1280, "center")
    else
        love.graphics.setColor(1.0, 0.2, 0.3, 0.98)
        love.graphics.printf("ANNIHILATED", 0, modal_y + 24, 1280, "center")
    end

    -- Estadísticas del Combate
    love.graphics.setFont(FontCache.get(11))
    love.graphics.setColor(0.7, 0.85, 0.95, 0.9)
    local match_stat = string.format("MATCH TIME: %.1fs  |  P1 PPS: %.2f  |  OPPONENT PPS: %.2f", 
        _G.RealMatchTimer or 0, 
        (PlayerBoard and PlayerBoard.current_pps_display) or 0,
        (BotBoard and BotBoard.current_pps_display) or 0
    )
    love.graphics.printf(match_stat, 0, modal_y + 80, 1280, "center")

    if _G.CURRENT_GAME_MODE == "boss_hunt" and is_victory and #PartBreaking.match_carves > 0 then
        love.graphics.setFont(FontCache.get(10))
        love.graphics.setColor(1.0, 0.85, 0.0, 0.95)
        local carves_text = "CARVES: " .. table.concat(PartBreaking.match_carves, " + ")
        love.graphics.printf(carves_text, 0, modal_y + 115, 1280, "center")
    end

    -- Botones / Hotkeys
    love.graphics.setFont(FontCache.get(13))
    love.graphics.setColor(1.0, 0.95, 0.4, 0.95)
    love.graphics.printf("PRESS [ R ] TO REMATCH & ROTATE SOUNDTRACK", 0, modal_y + 165, 1280, "center")

    love.graphics.setFont(FontCache.get(10))
    love.graphics.setColor(0.55, 0.65, 0.75, 0.8)
    love.graphics.printf("[ ESC ] RETURN TO MAIN MENU", 0, modal_y + 215, 1280, "center")

    love.graphics.setFont(FontCache.get(9))
    love.graphics.setColor(0.0, 0.85, 1.0, 0.65)
    love.graphics.print((_G.ENGINE_VERSION or "MUTRIS v1.0.0") .. " | SKIN: " .. t.name, 16, 698)
end

function SceneGameOver.keypressed(key)
    if key == "return" or key == "space" or key == "r" then
        TrackManager.nextTrack()
        ThemeManager.triggerRestartHalo()
        local target = _G.CURRENT_GAME_MODE or "versus"
        SceneManager.setState(target)
        return true
    elseif key == "escape" then
        SceneManager.setState("menu")
        return true
    end
    return false
end

function SceneGameOver.gamepadpressed(joystick, button)
    if button == "start" or button == "a" then
        TrackManager.nextTrack()
        ThemeManager.triggerRestartHalo()
        local target = _G.CURRENT_GAME_MODE or "versus"
        SceneManager.setState(target)
    elseif button == "b" or button == "back" then
        SceneManager.setState("menu")
    end
end

return SceneGameOver
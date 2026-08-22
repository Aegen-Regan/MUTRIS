-- ================================================================
-- FILE: scenes/scene_gameover.lua
-- ================================================================
---@diagnostic disable: undefined-global
local SceneGameOver = {}
local ThemeManager = require "tetris.theme_manager"
local AudioManager = require "audio_manager"
local MusicManager = require "music_manager"
local PartBreaking = require "combat.part_breaking"
local PoiseSystem  = require "combat.poise_system"
local BossPhases   = require "combat.boss_phases"
local FontCache    = require "tetris.font_cache"

function SceneGameOver.draw(PlayerBoard, BotBoard)
    local t = ThemeManager.getCurrent()
    local is_victory = (BotBoard and BotBoard.is_dying) or (_G.CURRENT_GAME_MODE == "boss_hunt" and BossPhases.current_phase == 3 and PoiseSystem.hp <= 0)
    local modal_w, modal_h = 480, 240
    local modal_x = 640 - (modal_w / 2)
    local modal_y = 225

    love.graphics.setColor(0.0, 0.0, 0.0, 0.90)
    love.graphics.rectangle("fill", modal_x - 6, modal_y - 6, modal_w + 12, modal_h + 12, 10)

    love.graphics.setColor(0.01, 0.015, 0.03, 1.0)
    love.graphics.rectangle("fill", modal_x, modal_y, modal_w, modal_h, 8)

    local border_color = is_victory and (t.secondary or {0.1, 1.0, 0.5}) or {1.0, 0.2, 0.3}
    love.graphics.setLineWidth(2.5)
    love.graphics.setColor(border_color[1], border_color[2], border_color[3], 0.98)
    love.graphics.rectangle("line", modal_x, modal_y, modal_w, modal_h, 8)

    love.graphics.setFont(FontCache.get(28))
    if is_victory then
        local win_title = (_G.CURRENT_GAME_MODE == "boss_hunt") and "CYBER-BEAST SLAIN" or "VICTORY ACHIEVED"
        love.graphics.setColor(0.1, 1.0, 0.5, 0.98)
        love.graphics.printf(win_title, 0, modal_y + 18, 1280, "center")
    else
        love.graphics.setColor(1.0, 0.2, 0.3, 0.98)
        love.graphics.printf("ANNIHILATED", 0, modal_y + 18, 1280, "center")
    end

    love.graphics.setFont(FontCache.get(10))
    love.graphics.setColor(0.7, 0.85, 0.95, 0.85)
    local match_stat = string.format("MATCH TIME: %.1fs  |  P1 PPS: %.2f  |  BOT PPS: %.2f", 
        _G.RealMatchTimer or 0, 
        (PlayerBoard and PlayerBoard.current_pps_display) or 0,
        (BotBoard and BotBoard.current_pps_display) or 0
    )
    love.graphics.printf(match_stat, 0, modal_y + 60, 1280, "center")

    if _G.CURRENT_GAME_MODE == "boss_hunt" and is_victory and #PartBreaking.match_carves > 0 then
        love.graphics.setFont(FontCache.get(9))
        love.graphics.setColor(1.0, 0.85, 0.0, 0.95)
        local carves_text = "CARVES: " .. table.concat(PartBreaking.match_carves, " + ")
        love.graphics.printf(carves_text, 0, modal_y + 88, 1280, "center")
    end

    love.graphics.setFont(FontCache.get(12))
    love.graphics.setColor(1.0, 0.95, 0.4, 0.95)
    love.graphics.printf("PRESS [R] OR [START] TO REMATCH WITH NEXT TRACK", 0, modal_y + 130, 1280, "center")

    love.graphics.setFont(FontCache.get(10))
    love.graphics.setColor(0.55, 0.65, 0.75, 0.8)
    love.graphics.printf("[ESC] RETURN TO MAIN MENU", 0, modal_y + 175, 1280, "center")
end

function SceneGameOver.keypressed(key)
    local SceneManager = require "core.scene_manager"
    if key == "return" or key == "space" or key == "r" then
        _G.GlobalRestart(false)
        SceneManager.setState(_G.CURRENT_GAME_MODE or "versus")
        return true
    elseif key == "escape" then
        SceneManager.setState("menu")
        MusicManager.stop()
        MusicManager.start()
        AudioManager.playMenuBack()
        return true
    end
    return false
end

function SceneGameOver.gamepadpressed(joystick, button)
    local SceneManager = require "core.scene_manager"
    if button == "start" or button == "a" then
        _G.GlobalRestart(false)
        SceneManager.setState(_G.CURRENT_GAME_MODE or "versus")
    elseif button == "b" or button == "back" then
        SceneManager.setState("menu")
        MusicManager.stop()
        MusicManager.start()
        AudioManager.playMenuBack()
    end
end

return SceneGameOver
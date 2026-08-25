-- ================================================================
-- FILE: scenes/scene_game.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: DYNAMIC GAMEPLAY SCENE & BATTLE ROYALE MULTI-LAYOUT
-- Clean 240Hz, LayoutSolver Integration, Track Rotation on 'R' Restart
-- ============================================================================
local SceneGame = {}

local Board          = require "tetris.board"
local AIBot          = require "tetris.ai_bot"
local Input          = require "input"
local EventBus       = require "core.event_bus"
local ThemeManager   = require "tetris.theme_manager"
local FogLayer       = require "tetris.fog_layer"
local HUDPanels      = require "tetris.hud_panels"
local HUDCenter      = require "tetris.hud_center"
local AnomalyManager = require "tetris.anomaly_manager"
local Telemetry      = require "tetris.telemetry"
local Blackbox       = require "core.blackbox"
local FontCache      = require "tetris.font_cache"
local AudioManager   = require "audio_manager"
local MusicManager   = require "music_manager"
local TrackManager   = require "track_manager"
local MetaBalancer   = require "core.meta_balancer"
local SceneManager   = require "core.scene_manager"
local PartBreaking   = require "combat.part_breaking"
local LayoutSolver   = require "core.layout_solver"

SceneGame.boards = {}
SceneGame.bots = {}
SceneGame.mode = "versus"
SceneGame.last_config = nil
SceneGame.return_scene = "menu"
SceneGame.layout_style = "versus"
SceneGame.layout_data = nil

-- Estado de Fin de Partida
SceneGame.match_over = false
SceneGame.human_won = false
SceneGame.winner_name = ""
SceneGame.victory_flash = 0.0
SceneGame.final_match_time = 0.0

function SceneGame.init()
end

function SceneGame.enter(data)
    local ok, err = pcall(function()
        data = data or {}
        SceneGame.last_config = data
        SceneGame.mode = data.mode or "versus"
        SceneGame.return_scene = data.return_scene or "menu"
        SceneGame.layout_style = data.layout_style or (data.mode == "boss_hunt" and "gigantic_boss" or (#(data.boards or {}) > 2 and "multibot" or "versus"))
        SceneGame.boards = {}
        SceneGame.bots = {}

        _G.RealMatchTimer = 0.0
        SceneGame.final_match_time = 0.0
        SceneGame.match_over = false
        SceneGame.human_won = false
        SceneGame.winner_name = ""
        SceneGame.victory_flash = 0.0

        local boards_config = data.boards or {
            { type = "human", cols = 10, rows = 40, ai_profile = nil },
            { type = "bot",   cols = 10, rows = 40, ai_profile = "normal" }
        }

        local sw, sh = love.graphics.getDimensions()
        local layout = LayoutSolver.solve(SceneGame.layout_style, boards_config, sw, sh)
        SceneGame.layout_data = layout

        local human_board = nil
        for i, b_info in ipairs(layout.boards) do
            local b = Board.new(b_info.x, b_info.y, b_info.type, b_info.cols, b_info.rows, b_info.block_size)
            b.layout_info = b_info
            table.insert(SceneGame.boards, b)

            if b_info.type == "human" then
                human_board = b
                if Input and Input.init then Input.init(b) end
            elseif b_info.type == "bot" then
                local bot = AIBot.new(b, b_info.ai_profile or "normal")
                table.insert(SceneGame.bots, bot)
            end
        end

        SceneGame.relinkOpponents()

        if SceneGame.mode == "boss_hunt" then
            PartBreaking.init()
        end
        
        EventBus.emit("on_match_restart")
        Blackbox.log("SCENE", "Game Scene entered in mode: " .. SceneGame.mode .. " [Layout: " .. SceneGame.layout_style .. "]", 0, 0)
    end)
    
    if not ok then
        local log_f = io.open("debug_log.txt", "a")
        if log_f then
            log_f:write(tostring(os.date()) .. " - SceneGame.enter ERROR: " .. tostring(err) .. "\n" .. debug.traceback() .. "\n")
            log_f:close()
        end
        error(err)
    end
end

-- ============================================================================
-- 🔄 REINICIO DINÁMICO CON ROTACIÓN DE MÚSICA & HALO VISUAL (TECLA 'R')
-- ============================================================================
function SceneGame.restartMatch()
    -- 1. Rotar pista musical
    if TrackManager and TrackManager.nextTrack then
        TrackManager.nextTrack()
    end
    if MusicManager and MusicManager.start then
        MusicManager.start()
    end

    -- 2. Disparar halo de impacto visual de reinicio
    if ThemeManager and ThemeManager.triggerRestartHalo then
        ThemeManager.triggerRestartHalo()
    end

    -- 3. Notificación de nueva pista en pantalla
    local cur_track = TrackManager and TrackManager.getCurrentTrack()
    if cur_track and ThemeManager and ThemeManager.showToast then
        ThemeManager.showToast("TRACK: " .. (cur_track.name or "DEFAULT THEME"), {0.1, 0.95, 1.0})
    end

    AudioManager.playImmediateSFX("rotate", false)
    SceneManager.setState("game", SceneGame.last_config)
end

function SceneGame.relinkOpponents()
    local alive_boards = {}
    for i = 1, #SceneGame.boards do
        if not SceneGame.boards[i].is_dying then
            table.insert(alive_boards, SceneGame.boards[i])
        end
    end
    if #alive_boards >= 2 then
        for i, b in ipairs(alive_boards) do
            local opp_index = (i % #alive_boards) + 1
            b.opponent = alive_boards[opp_index]
        end
    end
end

function SceneGame.update(dt)
    local ok, err = pcall(function()
        if not SceneGame.match_over then
            if Input and Input.update then
                Input.update(dt)
            end

            for i = 1, #SceneGame.boards do
                SceneGame.boards[i]:update(dt)
            end
            
            for i = 1, #SceneGame.bots do
                SceneGame.bots[i]:update(dt)
            end

            if SceneGame.mode == "boss_hunt" then
                PartBreaking.update(dt)
            end

            -- Vigilante Battle Royale / Last Man Standing
            local total_boards = #SceneGame.boards
            local alive_count = 0
            local human_alive = false

            for i = 1, total_boards do
                local b = SceneGame.boards[i]
                if not b.is_dying then
                    alive_count = alive_count + 1
                    if b.player_type == "human" then
                        human_alive = true
                    end
                end
            end

            if total_boards == 2 then
                for i = 1, total_boards do
                    local b = SceneGame.boards[i]
                    if b.is_dying and b.death_timer <= 0.35 then
                        SceneGame.match_over = true
                        SceneGame.victory_flash = 1.0
                        SceneGame.final_match_time = _G.RealMatchTimer or 0.0

                        local human_lost = (b.player_type == "human")
                        SceneGame.human_won = not human_lost
                        SceneGame.winner_name = SceneGame.human_won and "PLAYER 1" or "BOT AI"

                        if SceneGame.human_won then
                            AudioManager.playImmediateSFX("ultimatris", false)
                            AudioManager.playVoiceAnnounce("victory")
                        else
                            AudioManager.playImmediateSFX("death", false)
                            AudioManager.playVoiceAnnounce("danger")
                        end

                        local p1 = SceneGame.boards[1]
                        local bot = SceneGame.boards[2]
                        local p1_pps = (p1 and p1.current_pps_display) or 1.0
                        local bot_pps = (bot and bot.current_pps_display) or 1.4

                        MetaBalancer.registerMatchOutcome(SceneGame.human_won, SceneGame.final_match_time, p1_pps, bot_pps)
                        AIBot.registerMatchOutcome(SceneGame.human_won, p1_pps)

                        Blackbox.log("MATCH_END", SceneGame.human_won and "VICTORY: PLAYER 1" or "DEFEAT: BOT WON", math.floor(p1_pps * 10), math.floor(SceneGame.final_match_time))
                        break
                    end
                end
            else
                -- Multi-Bot Battle Royale (3+ Tableros)
                if not human_alive then
                    local p1 = SceneGame.boards[1]
                    if p1 and p1.is_dying and p1.death_timer <= 0.35 then
                        SceneGame.match_over = true
                        SceneGame.human_won = false
                        SceneGame.winner_name = "BOT AI"
                        SceneGame.victory_flash = 1.0
                        SceneGame.final_match_time = _G.RealMatchTimer or 0.0

                        AudioManager.playImmediateSFX("death", false)
                        AudioManager.playVoiceAnnounce("danger")

                        Blackbox.log("MATCH_END", "MULTI-BOT DEFEAT: P1 ELIMINATED", 0, math.floor(SceneGame.final_match_time))
                    end
                elseif alive_count <= 1 and human_alive then
                    SceneGame.match_over = true
                    SceneGame.human_won = true
                    SceneGame.winner_name = "PLAYER 1"
                    SceneGame.victory_flash = 1.0
                    SceneGame.final_match_time = _G.RealMatchTimer or 0.0

                    AudioManager.playImmediateSFX("ultimatris", false)
                    AudioManager.playVoiceAnnounce("victory")

                    local p1 = SceneGame.boards[1]
                    local p1_pps = (p1 and p1.current_pps_display) or 1.0
                    MetaBalancer.registerMatchOutcome(true, SceneGame.final_match_time, p1_pps, 1.5)
                    AIBot.registerMatchOutcome(true, p1_pps)

                    Blackbox.log("MATCH_END", "MULTI-BOT VICTORY: LAST MAN STANDING", math.floor(p1_pps * 10), math.floor(SceneGame.final_match_time))
                else
                    SceneGame.relinkOpponents()
                end
            end
        else
            if SceneGame.victory_flash > 0 then
                SceneGame.victory_flash = math.max(0, SceneGame.victory_flash - dt * 2.5)
            end
        end
    end)
    
    if not ok then
        local log_f = io.open("debug_log.txt", "a")
        if log_f then
            log_f:write(tostring(os.date()) .. " - SceneGame.update ERROR: " .. tostring(err) .. "\n" .. debug.traceback() .. "\n")
            log_f:close()
        end
        error(err)
    end
end

function SceneGame.draw()
    local ok, err = pcall(function()
        if ThemeManager.drawBackground then ThemeManager.drawBackground() end
        if FogLayer.draw then FogLayer.draw() end

        local layout = SceneGame.layout_data or {}
        local num_b = #SceneGame.boards
        local is_multibot = layout.is_multibot or (num_b > 2)
        local is_boss = layout.is_boss or false
        local cx = layout.center_hud_x or 640

        -- 1. Renderizado de Tableros y Paneles
        for i = 1, num_b do
            local b = SceneGame.boards[i]
            b:draw()
            if HUDPanels.draw then HUDPanels.draw(b, is_multibot, is_boss) end
        end

        -- 2. HUD Central: En 1v1 y Gigantic Boss se dibuja en cx paramétrico sin solapamiento
        if num_b == 2 and not is_multibot then
            local p1 = SceneGame.boards[1]
            local p2 = SceneGame.boards[2]
            if HUDCenter.draw then HUDCenter.draw(p1, p2, cx) end
            if AnomalyManager.draw then AnomalyManager.draw(p1, p2) end
            if Telemetry.draw then Telemetry.draw(p1, p2, cx, is_boss) end
            if Blackbox.drawPermanentHUD then Blackbox.drawPermanentHUD(p1, p2, cx, is_boss) end
        elseif is_multibot then
            if Telemetry.drawMultiBot then
                Telemetry.drawMultiBot(SceneGame.boards)
            end
        end

        -- 3. Modal de Victoria / Derrota
        if SceneGame.match_over then
            local t = ThemeManager.getCurrent()
            local mx, my = 640 - 280, 360 - 170
            local mw, mh = 560, 340

            love.graphics.push("all")
            love.graphics.setColor(0.01, 0.015, 0.025, 0.88)
            love.graphics.rectangle("fill", 0, 0, 1280, 720)

            love.graphics.setColor(0.02, 0.025, 0.04, 0.98)
            love.graphics.rectangle("fill", mx, my, mw, mh, 8)

            local border_clr = SceneGame.human_won and {0.1, 0.95, 0.55} or {1.0, 0.15, 0.25}
            love.graphics.setLineWidth(2.5)
            love.graphics.setColor(border_clr[1], border_clr[2], border_clr[3], 0.98)
            love.graphics.rectangle("line", mx, my, mw, mh, 8)

            love.graphics.setFont(FontCache.get(22))
            love.graphics.setColor(border_clr[1], border_clr[2], border_clr[3], 1.0)
            local title_txt = SceneGame.human_won and (is_multibot and "/// VICTORY // LAST MAN STANDING ///" or "/// VICTORY // TRANSCENDENCE ///") or "/// DEFEAT // MATRIX OVERFLOW ///"
            love.graphics.printf(title_txt, mx, my + 24, mw, "center")

            love.graphics.setFont(FontCache.get(10))
            love.graphics.setColor(1, 1, 1, 0.75)
            local sub_txt = SceneGame.human_won and "ALL OPPONENT MATRICES ELIMINATED // ARENA CONQUERED" or "CRITICAL STRUCTURAL COLLAPSE // REBOOT REQUIRED"
            love.graphics.printf(sub_txt, mx, my + 56, mw, "center")

            local p1 = SceneGame.boards[1]
            local p1_pps = (p1 and p1.current_pps_display) or 1.0
            local p1_lines = (p1 and p1.lines_cleared) or 0
            local p1_combo = (p1 and p1.max_combo) or 0
            local p1_sent = (p1 and p1.garbage_sent) or 0

            local sy = my + 105
            love.graphics.setFont(FontCache.get(12))
            love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.95)
            love.graphics.printf(string.format("MATCH DURATION: %05.1fs", SceneGame.final_match_time), mx, sy, mw, "center")

            love.graphics.setFont(FontCache.get(10))
            love.graphics.setColor(0.85, 0.90, 1.0, 0.90)
            love.graphics.printf(string.format("P1 SPEED: %.2f PPS   |   LINES CLEARED: %d", p1_pps, p1_lines), mx, sy + 32, mw, "center")
            love.graphics.printf(string.format("MAX COMBO: %d HITS   |   GARBAGE SENT: %d LINES", p1_combo, p1_sent), mx, sy + 58, mw, "center")

            local prof = _G.AI_ADAPTIVE_PROFILE
            if prof then
                love.graphics.setFont(FontCache.get(9))
                love.graphics.setColor(0.1, 1.0, 0.55, 0.85)
                love.graphics.printf(string.format("OVERALL RECORD: %d WINS - %d LOSSES (AVG: %.2f PPS)", prof.player_wins or 0, prof.bot_wins or 0, prof.player_avg_pps or 1.0), mx, sy + 90, mw, "center")
            end

            love.graphics.setFont(FontCache.get(11))
            love.graphics.setColor(1.0, 0.90, 0.35, 0.98)
            love.graphics.printf("[ ENTER / SPACE / R ] JUGAR DE NUEVO   |   [ ESC ] SALIR", mx, my + mh - 38, mw, "center")

            love.graphics.pop()
        end
    end)
    
    if not ok then
        local log_f = io.open("debug_log.txt", "a")
        if log_f then
            log_f:write(tostring(os.date()) .. " - SceneGame.draw ERROR: " .. tostring(err) .. "\n" .. debug.traceback() .. "\n")
            log_f:close()
        end
        love.graphics.setColor(1,0,0,1)
        love.graphics.print("RENDER ERROR: " .. tostring(err), 10, 10)
    end
end

function SceneGame.keypressed(key)
    if SceneGame.match_over then
        if key == "return" or key == "space" or key == "r" then
            SceneGame.restartMatch()
            return true
        elseif key == "escape" then
            SceneManager.setState(SceneGame.return_scene or "menu")
            AudioManager.playMenuBack()
            return true
        end
        return true
    end

    if key == "escape" then
        SceneManager.setState(SceneGame.return_scene or "menu")
        AudioManager.playMenuBack()
        return true
    end

    if key == "r" then
        SceneGame.restartMatch()
        return true
    end

    if Input and Input.keypressed then
        Input.keypressed(key)
    end
end

function SceneGame.gamepadpressed(joystick, button)
    if SceneGame.match_over then
        if button == "a" or button == "start" then
            SceneGame.restartMatch()
            return true
        elseif button == "b" or button == "back" then
            SceneManager.setState(SceneGame.return_scene or "menu")
            AudioManager.playMenuBack()
            return true
        end
        return true
    end

    if button == "start" then
        SceneGame.restartMatch()
        return true
    elseif button == "back" then
        SceneManager.setState(SceneGame.return_scene or "menu")
        AudioManager.playMenuBack()
        return true
    end

    if Input and Input.gamepadpressed then
        Input.gamepadpressed(joystick, button)
    end
end

function SceneGame.exit()
    SceneGame.boards = {}
    SceneGame.bots = {}
    SceneGame.match_over = false
    SceneGame.final_match_time = 0.0
    Blackbox.log("SCENE", "Game Scene exited", 0, 0)
    collectgarbage("collect")
end

return SceneGame

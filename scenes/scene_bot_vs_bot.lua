-- ================================================================
-- FILE: scenes/scene_bot_vs_bot.lua
-- ================================================================
---@diagnostic disable: undefined-global
local SceneBotVsBot = {}

local Board          = require("tetris.board")
local Input          = require("input")
local AIBot          = require("tetris.ai_bot")
local ThemeManager   = require("tetris.theme_manager")
local FontCache      = require("tetris.font_cache")
local Telemetry      = require("tetris.telemetry")
local HUDCenter      = require("tetris.hud_center")
local HUDPanels      = require("tetris.hud_panels")
local Blackbox       = require("core.blackbox")
local SceneManager   = require("core.scene_manager")
local EmoteSystem    = require("tetris.emote_system")
local ClashSystem    = require("combat.clash_system")
local AnomalyManager = require("tetris.anomaly_manager")
local FogLayer       = require("tetris.fog_layer")
local TrackManager   = require("track_manager")
local ParticleSystem = require("tetris.particle_system")

local player_board = nil
local bot_board    = nil

local function drawSideTelemetry(bx, by, bw, bh, board, title)
    local theme = ThemeManager.getCurrent()
    ThemeManager.drawPanel(bx, by, bw, bh, title, false)

    local height = 0
    if board and board.grid then
        for r = 21, 40 do
            for c = 1, 10 do
                if board.grid[r][c] ~= 0 then
                    height = 41 - r
                    break
                end
            end
            if height > 0 then break end
        end
    end

    local total_garbage = 0
    if board and board.garbage_queue then
        for _, g in ipairs(board.garbage_queue) do
            total_garbage = total_garbage + (type(g) == "table" and g.lines or g or 0)
        end
    end

    love.graphics.setFont(FontCache.get(8))
    love.graphics.setColor(1.0, 0.25, 0.45, 0.95)
    love.graphics.print(string.format("HEIGHT: %02d/20", height), bx + 16, by + 30)

    love.graphics.setColor(0.65, 0.75, 0.85, 0.85)
    love.graphics.print(string.format("GARBAGE: %d", total_garbage), bx + 16, by + 46)

    if board and board.player_type == "human" then
        local stance_name = (board.current_stance == 1 and "RUSH") or (board.current_stance == 2 and "BASTION") or "RESONANCE"
        love.graphics.setColor(0.1, 0.95, 0.6, 0.9)
        love.graphics.print("ST: " .. stance_name, bx + 16, by + 62)
    else
        love.graphics.setColor(1.0, 0.85, 0.2, 0.9)
        love.graphics.print(string.format("AI: %.2f PPS", (AIBot and AIBot.pps) or 1.45), bx + 16, by + 62)
    end

    love.graphics.setColor(theme.border)
    love.graphics.line(bx + 12, by + 82, bx + bw - 12, by + 82)
    love.graphics.setColor(0.5, 0.65, 0.8, 0.8)
    love.graphics.print("EVENT LOG", bx + 16, by + 90)

    local log_str = (board and board.last_event_text) or "STD_LOCK"
    local log_time = (board and board.last_event_time) or (_G.RealMatchTimer or 0.0)
    love.graphics.setColor(0.85, 0.9, 1.0, 0.75)
    love.graphics.print(string.format("%s\nT: %04.1fs", log_str:sub(1, 12), log_time), bx + 16, by + 108)
end

local function drawBottomTimeline(time)
    local theme = ThemeManager.getCurrent()
    local y_base = 670
    local playhead_x = ((time * 85) % 1200) + 40
    
    local pulse = _G.AudioBeatPulse or 0
    local energy = _G.TrackEnergyPunch or 0
    local amp1 = 12 + (pulse * 16) + (energy * 20)
    local amp2 = 8 + (pulse * 12) + (energy * 15)

    love.graphics.setBlendMode("add")
    for i = 0, 78 do
        local x1 = 40 + i * 15
        local w1 = math.sin(time * 4.0 + i * 0.22) * amp1 + math.cos(time * 2.0 + i * 0.08) * (amp1 * 0.4)
        local w2 = math.cos(time * 3.2 + i * 0.15) * amp2

        love.graphics.setColor(theme.secondary[1], theme.secondary[2], theme.secondary[3], 0.35 + pulse * 0.35)
        love.graphics.line(x1, y_base + w1, x1 + 15, y_base + w1)

        love.graphics.setColor(theme.primary[1], theme.primary[2], theme.primary[3], 0.30 + energy * 0.4)
        love.graphics.line(x1, y_base + w2, x1 + 15, y_base + w2)

        if i % 3 == 0 then
            local tri_scale = 1.0 + (pulse * 0.6)
            love.graphics.setColor(1.0, 0.15, 0.65, 0.75 + pulse * 0.25)
            love.graphics.polygon("fill", 
                x1, y_base + 12 * tri_scale, 
                x1 + 5 * tri_scale, y_base + 4, 
                x1 + 10 * tri_scale, y_base + 12 * tri_scale
            )
        end
    end

    love.graphics.setColor(0.1, 1.0, 0.8, 0.95)
    love.graphics.setLineWidth(2.5)
    love.graphics.line(playhead_x, y_base - 22, playhead_x, y_base + 22)
    love.graphics.setBlendMode("alpha")
end

function SceneBotVsBot.init()
    -- main.lua handles board initialization for versus mode via GlobalRestart
    -- We do not create duplicate boards here to prevent hijacking the Input singleton
    if not SceneBotVsBot._events_bound then
        local EventBus = require("core.event_bus")
        EventBus.on(EventBus.ON_LINE_CLEAR, function(cleared, tspin, ptype)
            local player_id = (ptype == 1) and "p1" or "bot"
            if SceneBotVsBot.clash_system and SceneBotVsBot.clash_system.active then
                SceneBotVsBot.clash_system:onLineClear(player_id)
            end
            if ptype == 2 and SceneBotVsBot.emote_system and AIBot then
                AIBot:onGarbageSent(cleared, SceneBotVsBot.emote_system)
            end
        end)
        
        EventBus.on(EventBus.ON_MATCH_RESTART, function()
            SceneBotVsBot.game_over = false
            SceneBotVsBot.match_time = 0
        end)
        SceneBotVsBot._events_bound = true
    end
end

function SceneBotVsBot.enter()
    SceneBotVsBot.init()
    SceneBotVsBot.emote_system = EmoteSystem.new()
    SceneBotVsBot.clash_system = ClashSystem.new()
    
    -- Estructura fija pre-alocada para stats del Game Over (Zero-GC)
    SceneBotVsBot.stats_snapshot = {
        winner = "none", -- "p1", "bot", "draw"
        match_time = 0,
        p1 = { pps = 0, apm = 0, pieces = 0, lines = 0, garbage_sent = 0, garbage_recv = 0, max_combo = 0 },
        bot = { pps = 0, apm = 0, pieces = 0, lines = 0, garbage_sent = 0, garbage_recv = 0, max_combo = 0 }
    }
    SceneBotVsBot.game_over = false
    SceneBotVsBot.match_time = 0

    _G.RealMatchTimer = 0.0
    _G.CURRENT_GAME_MODE = "versus"
    Blackbox.log("MATCH", "VERSUS 1v1 ENGAGED", 0, 0)
end

function SceneBotVsBot.onEnter()
    SceneBotVsBot.enter()
end

function SceneBotVsBot.updateOverlay(dt, p_board, b_board)
    if SceneBotVsBot.game_over then return end

    _G.RealMatchTimer = (_G.RealMatchTimer or 0.0) + dt
    SceneBotVsBot.match_time = _G.RealMatchTimer
    
    player_board = p_board or _G.PlayerBoard
    bot_board = b_board or _G.BotBoard

    if SceneBotVsBot.clash_system then
        local clash_loser, clash_damage = SceneBotVsBot.clash_system:update(dt)
        if clash_loser then
            if clash_loser == "p1" and player_board then
                player_board:receiveGarbage(clash_damage)
                SceneBotVsBot.emote_system:triggerPreset("PANIC", player_board.x + 100, player_board.y + 40, 1.0, 0.3, 0.3, true)
            elseif bot_board then
                bot_board:receiveGarbage(clash_damage)
                SceneBotVsBot.emote_system:triggerPreset("PANIC", bot_board.x + 100, bot_board.y + 40, 1.0, 0.8, 0.2, true)
            end
        end
    end

    if SceneBotVsBot.emote_system then
        if AIBot and player_board then
            AIBot:updateEmoteLogic(dt, player_board, SceneBotVsBot.emote_system)
        end
        SceneBotVsBot.emote_system:update(dt)
    end

    SceneBotVsBot.checkGameOver()
end

function SceneBotVsBot.checkGameOver()
    if SceneBotVsBot.game_over then return end
    
    local p1_dead = false
    if player_board then
        p1_dead = player_board.is_dying or player_board.is_dead or player_board.game_over or (player_board.isGameOver and player_board:isGameOver()) or (player_board.stack_height and player_board.stack_height >= 20)
    end
    
    local bot_dead = false
    if bot_board then
        bot_dead = bot_board.is_dying or bot_board.is_dead or bot_board.game_over or (bot_board.isGameOver and bot_board:isGameOver()) or (bot_board.stack_height and bot_board.stack_height >= 20)
    end
    
    if (p1_dead or bot_dead) and not SceneBotVsBot.game_over then
        SceneBotVsBot.game_over = true
        local duration = math.max(0.1, SceneBotVsBot.match_time)
        local snap = SceneBotVsBot.stats_snapshot
        
        -- DETERMINACIÓN RIGUROSA DEL RESULTADO:
        if bot_dead and not p1_dead then
            snap.winner = "p1"      -- ¡VICTORIA DEL JUGADOR!
        elseif p1_dead and not bot_dead then
            snap.winner = "bot"     -- DERROTA (ANNIHILATED)
        else
            snap.winner = "draw"    -- EMPATE
        end
        
        snap.match_time = duration
        
        -- Métricas Congeladas P1
        local pb = player_board
        if pb then
            snap.p1.pieces = pb.pieces_placed or pb.stats_pieces or 0
            snap.p1.lines = pb.lines_cleared or pb.stats_lines or 0
            snap.p1.garbage_sent = pb.garbage_sent or pb.stats_attack or 0
            snap.p1.garbage_recv = pb.garbage_received or 0
            snap.p1.max_combo = pb.max_combo or 0
            snap.p1.pps = snap.p1.pieces / duration
            snap.p1.apm = (snap.p1.garbage_sent * 60) / duration
        end
        
        -- Métricas Congeladas BOT
        local bb = bot_board
        if bb then
            snap.bot.pieces = bb.pieces_placed or bb.stats_pieces or 0
            snap.bot.lines = bb.lines_cleared or bb.stats_lines or 0
            snap.bot.garbage_sent = bb.garbage_sent or bb.stats_attack or 0
            snap.bot.garbage_recv = bb.garbage_received or 0
            snap.bot.max_combo = bb.max_combo or 0
            snap.bot.pps = snap.bot.pieces / duration
            snap.bot.apm = (snap.bot.garbage_sent * 60) / duration
        end
        
        if AIBot and snap.p1.pps then
            AIBot.registerMatchOutcome(bot_dead, snap.p1.pps)
        end
    end
end

function SceneBotVsBot.drawOverlay()
    -- RESET OBLIGATORIO DE SCISSOR (Para evitar que recorte los emotes o efectos)
    love.graphics.setScissor()

    if SceneBotVsBot.clash_system and SceneBotVsBot.clash_system.active then
        -- Setear las posiciones de los centros de los tableros para el clash system
        if player_board and bot_board then
            local p1_cx = player_board.x + (player_board.cols * player_board.cell_size) / 2
            local p1_cy = player_board.y + (player_board.rows * player_board.cell_size) / 2
            local bot_cx = bot_board.x + (bot_board.cols * bot_board.cell_size) / 2
            local bot_cy = bot_board.y + (bot_board.rows * bot_board.cell_size) / 2
            SceneBotVsBot.clash_system:setBoardPositions(p1_cx, p1_cy, bot_cx, bot_cy)
            
            local p1_rect = { x = player_board.x, y = player_board.y, w = player_board.cols * player_board.cell_size, h = player_board.rows * player_board.cell_size }
            local bot_rect = { x = bot_board.x, y = bot_board.y, w = bot_board.cols * bot_board.cell_size, h = bot_board.rows * bot_board.cell_size }
            SceneBotVsBot.clash_system:draw(p1_rect, bot_rect)
        end
    end

    if SceneBotVsBot.emote_system then
        SceneBotVsBot.emote_system:draw()
    end

    if SceneBotVsBot.game_over then
        SceneBotVsBot.drawGameOverModal()
    end
end



function SceneBotVsBot.drawGameOverModal()
    if not SceneBotVsBot.game_over then return end
    
    local snap = SceneBotVsBot.stats_snapshot
    local screen_w, screen_h = love.graphics.getDimensions()
    
    -- Fondo Oscurecido
    love.graphics.setColor(0, 0, 0, 0.82)
    love.graphics.rectangle("fill", 0, 0, screen_w, screen_h)
    
    local box_w, box_h = 620, 440
    local box_x = (screen_w - box_w) / 2
    local box_y = (screen_h - box_h) / 2
    
    -- Fondo del Panel
    love.graphics.setColor(0.02, 0.02, 0.05, 0.98)
    love.graphics.rectangle("fill", box_x, box_y, box_w, box_h, 8, 8)
    
    local is_win = snap.winner == "p1"
    local is_draw = snap.winner == "draw"
    
    -- Borde y Título Dinámico
    if is_win then
        love.graphics.setColor(0.1, 0.95, 0.65, 1.0) -- Neón Esmeralda
    elseif is_draw then
        love.graphics.setColor(0.95, 0.85, 0.2, 1.0)  -- Neón Ámbar
    else
        love.graphics.setColor(1.0, 0.15, 0.25, 1.0)  -- Neón Rojo Carmín
    end
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", box_x, box_y, box_w, box_h, 8, 8)
    
    local title_font = FontCache.get(22)
    love.graphics.setFont(title_font)
    local title_text = is_win and "VICTORY - TARGET TRANSCENDED" or (is_draw and "STALEMATE" or "ANNIHILATED")
    local title_w = title_font:getWidth(title_text)
    love.graphics.print(title_text, box_x + (box_w - title_w) / 2, box_y + 24)
    
    -- Tiempo
    love.graphics.setColor(0.6, 0.6, 0.7, 1.0)
    local time_font = FontCache.get(14)
    love.graphics.setFont(time_font)
    local time_str = string.format("MATCH DURATION: %.1fs", snap.match_time)
    love.graphics.print(time_str, box_x + (box_w - time_font:getWidth(time_str)) / 2, box_y + 54)
    
    love.graphics.setColor(0.2, 0.2, 0.35, 0.8)
    love.graphics.line(box_x + 24, box_y + 80, box_x + box_w - 24, box_y + 80)
    
    -- Tabla Comparativa
    local col_metric_x = box_x + 40
    local col_p1_x     = box_x + 300
    local col_bot_x    = box_x + 470
    local start_y      = box_y + 96
    local row_h        = 32
    
    local header_font = FontCache.get(16)
    love.graphics.setFont(header_font)
    love.graphics.setColor(0.5, 0.5, 0.6, 1.0)
    love.graphics.print("METRIC", col_metric_x, start_y)
    love.graphics.setColor(0.2, 0.85, 1.0, 1.0)
    love.graphics.print("PLAYER 1", col_p1_x, start_y)
    love.graphics.setColor(1.0, 0.4, 0.4, 1.0)
    love.graphics.print("AI BOT", col_bot_x, start_y)
    
    local row_font = FontCache.get(14)
    
    local function drawStatRow(row_idx, label, p1_val, bot_val, is_float)
        local y = start_y + (row_idx * row_h)
        if row_idx % 2 == 1 then
            love.graphics.setColor(0.06, 0.06, 0.12, 0.5)
            love.graphics.rectangle("fill", box_x + 24, y - 4, box_w - 48, row_h - 2)
        end
        love.graphics.setFont(row_font)
        love.graphics.setColor(0.8, 0.8, 0.85, 1.0)
        love.graphics.print(label, col_metric_x, y)
        love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
        local p1_str = is_float and string.format("%.2f", p1_val) or tostring(p1_val)
        local bot_str = is_float and string.format("%.2f", bot_val) or tostring(bot_val)
        love.graphics.print(p1_str, col_p1_x, y)
        love.graphics.print(bot_str, col_bot_x, y)
    end
    
    drawStatRow(1, "Pieces Placed", snap.p1.pieces, snap.bot.pieces, false)
    drawStatRow(2, "Speed (PPS)", snap.p1.pps, snap.bot.pps, true)
    drawStatRow(3, "Attack (APM)", snap.p1.apm, snap.bot.apm, true)
    drawStatRow(4, "Lines Cleared", snap.p1.lines, snap.bot.lines, false)
    drawStatRow(5, "Garbage Sent", snap.p1.garbage_sent, snap.bot.garbage_sent, false)
    drawStatRow(6, "Garbage Received", snap.p1.garbage_recv, snap.bot.garbage_recv, false)
    drawStatRow(7, "Max Combo", snap.p1.max_combo, snap.bot.max_combo, false)
    
    -- Botones / Teclas
    love.graphics.setColor(0.95, 0.85, 0.2, 1.0)
    local btn_font = FontCache.get(12)
    love.graphics.setFont(btn_font)
    local r_text = "PRESS [ R ] TO REMATCH & ROTATE SOUNDTRACK"
    love.graphics.print(r_text, box_x + (box_w - btn_font:getWidth(r_text)) / 2, box_y + box_h - 52)
    
    love.graphics.setColor(0.5, 0.5, 0.6, 1.0)
    local esc_text = "[ ESC ] RETURN TO MAIN MENU"
    love.graphics.print(esc_text, box_x + (box_w - btn_font:getWidth(esc_text)) / 2, box_y + box_h - 26)
end

function SceneBotVsBot.triggerBoardEmote(target, category, r, g, b, is_heavy)
    if not SceneBotVsBot.emote_system then 
        if Blackbox then Blackbox.log("DEBUG", "EMOTE SYSTEM IS NIL", 0, 0) end
        return 
    end
    
    local is_p1 = (target == "p1")
    local board = is_p1 and player_board or bot_board
    
    -- Aparecen en el medio de la pantalla (área de telemetría/vuelo) y no sobre las fichas
    local center_x = is_p1 and 540 or 740
    local center_y = 340 + love.math.random(-40, 40)
    
    if Blackbox then Blackbox.log("DEBUG", "SPAWNING EMOTE", center_x, center_y) end
    SceneBotVsBot.emote_system:triggerPreset(category, center_x, center_y, r, g, b, is_heavy)
end

function SceneBotVsBot.keypressed(key)
    if key == "t" then
        if Blackbox then Blackbox.log("DEBUG", "T KEY PRESSED", 0, 0) end
        SceneBotVsBot.triggerBoardEmote("bot", "BM_WINNING", 1.0, 0.2, 0.2, true)
        SceneBotVsBot.triggerBoardEmote("p1", "TEST", 0.2, 0.9, 1.0, false)
        return true
    elseif key == "r" then
        TrackManager.nextTrack()
        ThemeManager.triggerRestartHalo()
        SceneBotVsBot.enter()
        return true
    elseif key == "f6" then
        ThemeManager.cyclePrev()
        return true
    elseif key == "escape" then
        SceneManager.setState("menu")
        return true
    end
    return false
end

function SceneBotVsBot.gamepadpressed(joystick, button)
    Input.gamepadpressed(joystick, button)
end

return SceneBotVsBot

-- ================================================================
-- FILE: scenes/scene_trainer.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS TRAINER LAB 2.0: CYBER TACTICAL ACADEMY
-- ============================================================================
local SceneTrainer = {}

local Board           = require "tetris.board"
local Input           = require "input"
local ThemeManager    = require "tetris.theme_manager"
local AudioManager    = require "audio_manager"
local MusicManager    = require "music_manager"
local FontCache       = require "tetris.font_cache"
local HUDPanels       = require "tetris.hud_panels"
local TrainerDatabase = require "core.trainer_database"
local TrainerManager  = require "core.trainer_manager"
local SceneManager    = require "core.scene_manager"
local EventBus        = require "core.event_bus"

local TrainerBoard = nil

function SceneTrainer.onEnter()
    TrainerBoard = Board.new(200, 130, "human")
    if Input and Input.init then Input.init(TrainerBoard) end
    TrainerManager.init(TrainerBoard, false)

    EventBus.on(EventBus.ON_PIECE_LOCK, function(piece_id, px, py, prot, player_id)
        if player_id == 1 and TrainerBoard then
            TrainerManager.onPieceLocked(TrainerBoard, piece_id, px, py, prot)
        end
    end)

    MusicManager.start()
end

function SceneTrainer.update(dt)
    if TrainerBoard then
        -- 🎮 MISMO BUCLE DE ENTRADA Y FÍSICAS QUE EN VERSUS
        Input.update(dt)
        TrainerBoard:update(dt)
    end
end

function SceneTrainer.draw()
    ThemeManager.drawBackground()
    local t = ThemeManager.getCurrent()

    -- 🏷️ PESTAÑAS DE APERTURAS (CLICKEABLES)
    local tab_w = 190
    local tab_h = 32
    local total_tabs_w = #TrainerDatabase.OPENERS * (tab_w + 6) - 6
    local start_tabs_x = 640 - (total_tabs_w / 2)
    local tabs_y = 52

    for i, op in ipairs(TrainerDatabase.OPENERS) do
        local tx = start_tabs_x + (i - 1) * (tab_w + 6)
        local is_sel = (i == TrainerManager.selected_opener_idx)

        ThemeManager.drawPanel(tx, tabs_y, tab_w, tab_h, "", is_sel)
        
        love.graphics.setFont(FontCache.get(10))
        love.graphics.setColor(is_sel and {1, 1, 1, 1} or {0.6, 0.75, 0.85, 0.75})
        love.graphics.printf(op.tag .. " // " .. op.name:gsub(" — .*$", ""), tx, tabs_y + 9, tab_w, "center")
    end

    -- Tablero, Holograma y Paneles
    if TrainerBoard then
        TrainerBoard:draw()
        TrainerManager.drawHologram(TrainerBoard)
        HUDPanels.draw(TrainerBoard)
    end

    -- 📋 PANEL DERECHO TÁCTICO
    local px = 550
    local py = 130
    local pw = 530
    local ph = 480

    ThemeManager.drawPanel(px, py, pw, ph, "", false)

    local opener = TrainerDatabase.getOpener(TrainerManager.selected_opener_idx)

    -- TARJETA 1: FICHA DE LA APERTURA
    love.graphics.setFont(FontCache.get(17))
    love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.98)
    love.graphics.print(opener.name, px + 20, py + 16)

    love.graphics.setFont(FontCache.get(10))
    love.graphics.setColor(0.1, 0.95, 0.55, 0.95)
    love.graphics.print("RECOMPENSA: " .. opener.reward .. "  |  DIFICULTAD: " .. opener.difficulty, px + 20, py + 40)

    love.graphics.setColor(0.7, 0.8, 0.9, 0.85)
    love.graphics.printf(opener.desc, px + 20, py + 58, pw - 40, "left")

    -- TARJETA 2: PROGRESO DEL PLANO
    local prog_y = py + 105
    love.graphics.setFont(FontCache.get(11))
    love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.9)
    love.graphics.print(string.format("PROGRESO DEL PLANO: PASO %d DE %d", TrainerManager.current_step, #opener.steps), px + 20, prog_y)

    local bar_w = pw - 40
    local step_count = #opener.steps
    for i = 1, step_count do
        local sw = (bar_w - (step_count - 1) * 6) / step_count
        local sx = (px + 20) + (i - 1) * (sw + 6)
        local is_done = (i < TrainerManager.current_step)
        local is_cur = (i == TrainerManager.current_step)

        if is_done then
            love.graphics.setColor(0.1, 0.95, 0.45, 0.85)
        elseif is_cur then
            love.graphics.setColor(t.secondary[1], t.secondary[2], t.secondary[3], 0.95)
        else
            love.graphics.setColor(0.1, 0.15, 0.25, 0.6)
        end
        love.graphics.rectangle("fill", sx, prog_y + 20, sw, 12, 2)
    end

    -- TARJETA 3: ESTADÍSTICAS Y RACHA
    local stats_y = py + 165
    love.graphics.setColor(0.015, 0.03, 0.06, 0.85)
    love.graphics.rectangle("fill", px + 20, stats_y, pw - 40, 110, 4)
    love.graphics.setColor(t.border)
    love.graphics.rectangle("line", px + 20, stats_y, pw - 40, 110, 4)

    love.graphics.setFont(FontCache.get(11))
    love.graphics.setColor(0.5, 0.7, 0.9, 0.9)
    love.graphics.print("TELEMETRIA DE ENTRENAMIENTO:", px + 34, stats_y + 14)

    love.graphics.setFont(FontCache.get(11))
    love.graphics.setColor(0.7, 0.85, 0.95, 0.9)
    love.graphics.print(string.format("REPETICIONES COMPLETADAS: %d", TrainerManager.completed_reps), px + 34, stats_y + 38)
    love.graphics.print(string.format("RACHA ACTUAL (STREAK): %d", TrainerManager.current_streak), px + 34, stats_y + 60)
    love.graphics.print(string.format("ERRORES / FAULTS: %d", TrainerManager.finesse_faults), px + 34, stats_y + 82)

    -- AYUDA DE TECLADO INFERIOR
    local foot_y = py + 395
    love.graphics.setFont(FontCache.get(10))
    love.graphics.setColor(0.3, 0.85, 1.0, 0.9)
    love.graphics.printf("[ CLIC EN PESTANAS ] CAMBIAR APERTURA  |  [ BACKSPACE ] REBOBINAR", px + 20, foot_y, pw - 40, "center")
    love.graphics.setFont(FontCache.get(9))
    love.graphics.setColor(0.5, 0.65, 0.75, 0.8)
    love.graphics.printf("[ F4 / H ] HOLOGRAMA  |  [ ESC ] MENU PRINCIPAL", px + 20, foot_y + 20, pw - 40, "center")
end

function SceneTrainer.keypressed(key)
    -- 1. Atajo de Rebobinado Seguro (BACKSPACE)
    if key == "backspace" then
        TrainerManager.undo(TrainerBoard)
        return true
    end

    -- 2. Utilidades del Trainer (F4/H, ESC)
    if key == "f4" or key == "h" then
        TrainerManager.hologram_active = not TrainerManager.hologram_active
        AudioManager.playSliderTick()
        return true
    elseif key == "escape" then
        SceneManager.setState("menu")
        AudioManager.playMenuBack()
        return true
    end

    -- 3. 🎮 TUS CONTROLES ORIGINALES (A, Z, D, X, UP, S, C, Q, E, TAB, SPACE, FLECHAS) PASAN 100% LIMPIOS
    Input.keypressed(key)
    return true
end

function SceneTrainer.mousepressed(adj_x, adj_y, button)
    if button ~= 1 then return false end

    -- Cambiar de apertura haciendo clic en las pestañas superiores
    local tab_w = 190
    local tab_h = 32
    local total_tabs_w = #TrainerDatabase.OPENERS * (tab_w + 6) - 6
    local start_tabs_x = 640 - (total_tabs_w / 2)
    local tabs_y = 52

    for i = 1, #TrainerDatabase.OPENERS do
        local tx = start_tabs_x + (i - 1) * (tab_w + 6)
        if adj_x >= tx and adj_x <= tx + tab_w and adj_y >= tabs_y and adj_y <= tabs_y + tab_h then
            TrainerManager.selected_opener_idx = i
            TrainerManager.init(TrainerBoard, false)
            AudioManager.playMenuClick()
            return true
        end
    end
    return false
end

function SceneTrainer.gamepadpressed(joystick, button)
    if button == "b" or button == "back" then
        SceneManager.setState("menu")
        AudioManager.playMenuBack()
    elseif button == "y" then
        TrainerManager.undo(TrainerBoard)
    else
        Input.gamepadpressed(joystick, button)
    end
end

return SceneTrainer
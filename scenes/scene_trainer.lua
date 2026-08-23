-- ================================================================
-- FILE: scenes/scene_trainer.lua
-- ================================================================
---@diagnostic disable: undefined-global
local SceneTrainer = {}

local Board           = require("tetris.board")
local Input           = require("input")
local TrainerManager  = require("core.trainer_manager")
local TrainerDatabase = require("core.trainer_database")
local ThemeManager    = require("tetris.theme_manager")
local RulesetManager  = require("core.ruleset_manager")
local FontCache       = require("tetris.font_cache")
local SceneManager    = require("core.scene_manager")
local FogLayer        = require("tetris.fog_layer")

local board = nil

local function drawMiniMino(pid, cx, cy, cell_size, colors)
    if not pid or pid <= 0 or pid > 7 then return end
    local shapes = RulesetManager.getShapes(pid)
    local shape = shapes and shapes[1] or {{{1}}}
    local clr = colors and colors[pid] or {1, 1, 1}
    local cs = cell_size or 12

    local rows = #shape
    local cols = #shape[1]
    local start_x = cx - (cols * cs) / 2
    local start_y = cy - (rows * cs) / 2

    for r = 1, rows do
        for c = 1, cols do
            if shape[r][c] ~= 0 then
                local rx = start_x + (c - 1) * cs
                local ry = start_y + (r - 1) * cs

                love.graphics.setColor(clr[1], clr[2], clr[3], 0.95)
                love.graphics.rectangle("fill", rx + 1, ry + 1, cs - 2, cs - 2, 2)
                love.graphics.setColor(1, 1, 1, 0.4)
                love.graphics.rectangle("line", rx + 1, ry + 1, cs - 2, cs - 2, 2)
            end
        end
    end
end

local function drawTrainerHoldAndNext(b)
    if not b then return end

    -- HOLD BOX (X = 45, Y = 130)
    local hx, hy, hw, hh = 45, 130, 75, 75
    ThemeManager.drawPanel(hx, hy, hw, hh, "HOLD", false)
    if b.hold_piece then
        drawMiniMino(b.hold_piece.id, hx + hw / 2, hy + hh / 2 + 6, 12, b.colors)
    end

    -- NEXT BOX (X = 395, Y = 130)
    local nx, ny, nw, nh = 395, 130, 75, 150
    ThemeManager.drawPanel(nx, ny, nw, nh, "NEXT", false)
    if b.bag and b.bag.peek then
        local previews = b.bag:peek(2)
        for idx, pid in ipairs(previews) do
            local py = ny + 38 + (idx - 1) * 55
            drawMiniMino(pid, nx + nw / 2, py, 12, b.colors)
        end
    end
end

function SceneTrainer.init()
    board = Board.new(140, 120, "human")
    Input.init(board)
    TrainerManager.init(board, false)
    FogLayer.init()
end

function SceneTrainer.enter()
    SceneTrainer.init()
    _G.CURRENT_GAME_MODE = "trainer"
end

function SceneTrainer.onEnter()
    SceneTrainer.enter()
end

function SceneTrainer.update(dt)
    _G.RealMatchTimer = (_G.RealMatchTimer or 0.0) + dt
    Input.update(dt)
    if board then board:update(dt) end
    FogLayer.update(dt)
    ThemeManager.update(dt)
end

function SceneTrainer.draw()
    local theme = ThemeManager.getCurrent()
    local time = _G.RealMatchTimer or 0.0

    ThemeManager.drawBackground()
    FogLayer.draw()

    -- 1. Pestañas Superiores Compactas
    local openers = TrainerDatabase.OPENERS
    local tab_w = 175
    local start_tab_x = 640 - (#openers * (tab_w + 6)) / 2

    for i, op in ipairs(openers) do
        local is_sel = (i == TrainerManager.selected_opener_idx)
        local tx = start_tab_x + (i - 1) * (tab_w + 6)
        ThemeManager.drawPanel(tx, 38, tab_w, 32, "", is_sel)
        love.graphics.setFont(FontCache.get(8))
        love.graphics.setColor(is_sel and {1, 1, 1, 1} or {0.6, 0.7, 0.8, 0.7})
        love.graphics.printf(op.tab_label or op.name, tx, 48, tab_w, "center")
    end

    -- 2. Tablero de Juego (X = 140) + HOLD/NEXT Reales
    if board then
        board:draw()
        TrainerManager.drawHologram(board)
        drawTrainerHoldAndNext(board)
    end

    -- 3. Panel de la Academia (X = 490, W = 740, H = 540)
    local opener = TrainerDatabase.getOpener(TrainerManager.selected_opener_idx)
    local cur_step_idx = TrainerManager.current_step
    local step_data = opener.steps[cur_step_idx] or opener.steps[#opener.steps]

    local px, py, pw, ph = 490, 110, 740, 540
    ThemeManager.drawPanel(px, py, pw, ph, "", false)

    -- Título de la Apertura
    love.graphics.setFont(FontCache.get(18))
    love.graphics.setColor(theme.primary[1], theme.primary[2], theme.primary[3], 0.98)
    love.graphics.print(opener.name, px + 28, py + 18)

    love.graphics.setFont(FontCache.get(9))
    love.graphics.setColor(0.1, 0.95, 0.5, 0.95)
    love.graphics.print("RECOMPENSA: " .. opener.reward .. "  |  DIFICULTAD: " .. opener.difficulty, px + 28, py + 46)

    -- Resumen Táctico
    love.graphics.setFont(FontCache.get(9))
    love.graphics.setColor(0.75, 0.85, 0.95, 0.85)
    love.graphics.printf(opener.summary, px + 28, py + 66, pw - 56, "left")

    -- 4. Barra de Progreso de Pasos
    local total_steps = #opener.steps
    love.graphics.setFont(FontCache.get(10))
    love.graphics.setColor(1.0, 0.85, 0.2, 0.95)
    love.graphics.print(string.format("PROGRESO DEL PLANO: PASO %d DE %d", cur_step_idx, total_steps), px + 28, py + 120)

    local bar_start_x = px + 28
    local seg_w = (pw - 56 - (total_steps - 1) * 8) / total_steps
    for s = 1, total_steps do
        local sx = bar_start_x + (s - 1) * (seg_w + 8)
        if s < cur_step_idx then
            love.graphics.setColor(0.1, 0.95, 0.5, 0.95)
            love.graphics.rectangle("fill", sx, py + 138, seg_w, 10, 2)
        elseif s == cur_step_idx then
            local pulse = 0.5 + math.sin(time * 8.0) * 0.4
            love.graphics.setColor(theme.secondary[1], theme.secondary[2], theme.secondary[3], 0.6 + pulse * 0.4)
            love.graphics.rectangle("fill", sx, py + 138, seg_w, 10, 2)
        else
            love.graphics.setColor(0.15, 0.20, 0.30, 0.7)
            love.graphics.rectangle("fill", sx, py + 138, seg_w, 10, 2)
        end
    end

    -- 5. Tarjeta Didáctica del Paso Activo
    local step_box_y = py + 168
    love.graphics.setColor(0.02, 0.04, 0.08, 0.9)
    love.graphics.rectangle("fill", px + 28, step_box_y, pw - 56, 90, 4)
    love.graphics.setColor(theme.border)
    love.graphics.rectangle("line", px + 28, step_box_y, pw - 56, 90, 4)

    love.graphics.setFont(FontCache.get(9))
    love.graphics.setColor(theme.primary[1], theme.primary[2], theme.primary[3], 0.95)
    love.graphics.print(string.format("INSTRUCCION TACTICA (PASO %d):", cur_step_idx), px + 40, step_box_y + 12)

    love.graphics.setFont(FontCache.get(10))
    love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
    love.graphics.printf(step_data.desc or "Coloca la pieza segun el holograma.", px + 40, step_box_y + 32, pw - 80, "left")

    -- 6. KEYSTROKE COACH
    local coach_y = py + 276
    love.graphics.setFont(FontCache.get(9))
    love.graphics.setColor(1.0, 0.85, 0.2, 0.95)
    love.graphics.print("SECUENCIA DE ENTRADA RECOMENDADA (KEYSTROKE COACH):", px + 28, coach_y)

    local keys_list = step_data.keys or {"[ SPACE DROP ]"}
    local key_btn_x = px + 28
    for _, k_label in ipairs(keys_list) do
        local kw = FontCache.get(9):getWidth(k_label) + 20
        love.graphics.setColor(0.04, 0.15, 0.25, 0.9)
        love.graphics.rectangle("fill", key_btn_x, coach_y + 18, kw, 28, 3)
        love.graphics.setColor(0.1, 0.9, 1.0, 0.85)
        love.graphics.rectangle("line", key_btn_x, coach_y + 18, kw, 28, 3)
        love.graphics.setColor(1, 1, 1, 0.98)
        love.graphics.print(k_label, key_btn_x + 10, coach_y + 25)
        key_btn_x = key_btn_x + kw + 12
    end

    -- 7. Telemetría de Maestría
    local telem_y = py + 350
    love.graphics.setColor(0.02, 0.03, 0.06, 0.85)
    love.graphics.rectangle("fill", px + 28, telem_y, pw - 56, 95, 4)
    love.graphics.setColor(theme.border)
    love.graphics.rectangle("line", px + 28, telem_y, pw - 56, 95, 4)

    love.graphics.setFont(FontCache.get(8))
    love.graphics.setColor(0.6, 0.7, 0.8, 0.9)
    love.graphics.print("TELEMETRIA DE RENDIMIENTO:", px + 40, telem_y + 12)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print(string.format("REPETICIONES COMPLETADAS : %d", TrainerManager.completed_reps), px + 40, telem_y + 32)
    love.graphics.print(string.format("RACHA ACTUAL (STREAK)    : %d", TrainerManager.current_streak), px + 40, telem_y + 52)
    love.graphics.setColor(TrainerManager.finesse_faults > 0 and {1.0, 0.3, 0.3} or {0.1, 0.95, 0.5})
    love.graphics.print(string.format("ERRORES DE FINESSE / FAULTS: %d", TrainerManager.finesse_faults), px + 40, telem_y + 72)

    -- 8. Atajos Inferiores
    love.graphics.setFont(FontCache.get(8))
    love.graphics.setColor(0.4, 0.5, 0.6, 0.8)
    love.graphics.printf("[ 1..5 ] SELECCIONAR APERTURA | [ BACKSPACE ] TIME-TRAVEL UNDO | [ F4 / H ] TOGGLE HOLOGRAMA | [ ESC ] MENU", px, py + ph - 24, pw, "center")
end

function SceneTrainer.keypressed(key)
    if key == "1" or key == "2" or key == "3" or key == "4" or key == "5" then
        local idx = tonumber(key)
        TrainerManager.selected_opener_idx = idx
        TrainerManager.init(board, false)
        return true
    elseif key == "backspace" then
        TrainerManager.undo(board)
        return true
    elseif key == "f4" or key == "h" then
        TrainerManager.hologram_active = not TrainerManager.hologram_active
        return true
    elseif key == "escape" then
        SceneManager.setState("menu")
        return true
    end

    if key == "r" then
        SceneTrainer.init()
    end
    return false
end

function SceneTrainer.mousepressed(mx, my, button)
    if button ~= 1 then return false end
    local openers = TrainerDatabase.OPENERS
    local tab_w = 175
    local start_tab_x = 640 - (#openers * (tab_w + 6)) / 2

    for i = 1, #openers do
        local tx = start_tab_x + (i - 1) * (tab_w + 6)
        if mx >= tx and mx <= tx + tab_w and my >= 38 and my <= 70 then
            TrainerManager.selected_opener_idx = i
            TrainerManager.init(board, false)
            return true
        end
    end
    return false
end

function SceneTrainer.gamepadpressed(joystick, button)
    if button == "leftshoulder" then
        TrainerManager.selected_opener_idx = (TrainerManager.selected_opener_idx == 1) and #TrainerDatabase.OPENERS or (TrainerManager.selected_opener_idx - 1)
        TrainerManager.init(board, false)
    elseif button == "rightshoulder" then
        TrainerManager.selected_opener_idx = (TrainerManager.selected_opener_idx % #TrainerDatabase.OPENERS) + 1
        TrainerManager.init(board, false)
    elseif button == "b" or button == "back" then
        SceneManager.setState("menu")
    else
        Input.gamepadpressed(joystick, button)
    end
end

return SceneTrainer
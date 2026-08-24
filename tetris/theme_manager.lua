-- ================================================================
-- FILE: tetris/theme_manager.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: THEME & SKIN MASTER CONTROLLER (ZERO-GC)
-- 01: Cyber-DAW | 02: Neo-Kinetic | 03: Esports Glass | 04: Cosmic Synesthesia
-- ============================================================================
local ThemeManager = {}
local FontCache = require "tetris.font_cache"

ThemeManager.current_theme = 4 -- 1: DAW, 2: Strike, 3: Glass, 4: Cosmic

ThemeManager.THEMES = {
    [1] = {
        id = 1,
        name = "01 // CYBER-DAW RACK",
        primary   = {1.0, 0.60, 0.10}, -- Ámbar Analógico
        secondary = {0.2, 0.90, 1.00}, -- Vúmetro Cyan
        accent    = {1.0, 0.20, 0.30},
        border    = {0.4, 0.25, 0.10, 0.8},
        bg_color  = {0.02, 0.015, 0.01, 1.0}
    },
    [2] = {
        id = 2,
        name = "02 // NEO-KINETIC STRIKE",
        primary   = {1.0, 0.15, 0.25}, -- Carmesí Persona 5
        secondary = {1.0, 0.95, 0.10}, -- Amarillo Impacto
        accent    = {0.1, 1.00, 0.50},
        border    = {0.8, 0.10, 0.20, 0.9},
        bg_color  = {0.03, 0.01, 0.015, 1.0}
    },
    [3] = {
        id = 3,
        name = "03 // HYPER-CLEAN GLASS",
        primary   = {0.15, 0.85, 1.00}, -- Esports Cyan
        secondary = {0.90, 0.95, 1.00}, -- Blanco Glaciar
        accent    = {0.40, 0.60, 1.00},
        border    = {0.20, 0.50, 0.80, 0.6},
        bg_color  = {0.01, 0.02, 0.04, 1.0}
    },
    [4] = {
        id = 4,
        name = "04 // SINESTESIA COSMICA",
        primary   = {0.70, 0.30, 1.00}, -- Violeta Astral
        secondary = {0.10, 0.95, 0.90}, -- Cyan Nebular
        accent    = {1.00, 0.80, 0.20}, -- Dorado Sagrado
        border    = {0.45, 0.20, 0.70, 0.75},
        bg_color  = {0.01, 0.005, 0.02, 1.0}
    }
}

-- Búfer de Estrellas Zero-GC para Sinestesia Cósmica
local STARS_COUNT = 90
local stars = {}
for i = 1, STARS_COUNT do
    stars[i] = {
        x = math.random(0, 1280),
        y = math.random(0, 720),
        size = math.random(1, 3),
        alpha = math.random() * 0.7 + 0.2,
        speed = math.random() * 8 + 4
    }
end

-- Halos y Notificaciones Pre-alocadas
local restart_halo_timer = 0.0
local toast_text = ""
local toast_timer = 0.0
local toast_color = {1, 1, 1}

-- Función auxiliar para dibujar diamantes procedimentales nítidos (sin cajas ▯)
local function drawDiamond(cx, cy, size, is_filled)
    local s = size or 5
    if is_filled then
        love.graphics.polygon("fill", cx, cy - s, cx + s, cy, cx, cy + s, cx - s, cy)
    else
        love.graphics.polygon("line", cx, cy - s, cx + s, cy, cx, cy + s, cx - s, cy)
    end
end

function ThemeManager.init()
    restart_halo_timer = 0.0
    toast_timer = 0.0
end

function ThemeManager.getCurrent()
    return ThemeManager.THEMES[ThemeManager.current_theme] or ThemeManager.THEMES[1]
end

function ThemeManager.setTheme(id_or_name)
    if type(id_or_name) == "number" then
        ThemeManager.current_theme = math.max(1, math.min(4, id_or_name))
    elseif type(id_or_name) == "string" then
        for i, t in ipairs(ThemeManager.THEMES) do
            if t.name == id_or_name or tostring(i) == id_or_name then
                ThemeManager.current_theme = i
                break
            end
        end
    end
end

function ThemeManager.cycleNext()
    ThemeManager.current_theme = (ThemeManager.current_theme % #ThemeManager.THEMES) + 1
    ThemeManager.showToast("SKIN: " .. ThemeManager.getCurrent().name, {0.1, 0.9, 1.0})
end

function ThemeManager.cyclePrev()
    ThemeManager.current_theme = (ThemeManager.current_theme == 1) and #ThemeManager.THEMES or (ThemeManager.current_theme - 1)
    ThemeManager.showToast("SKIN: " .. ThemeManager.getCurrent().name, {0.1, 0.9, 1.0})
end

function ThemeManager.triggerRestartHalo()
    restart_halo_timer = 0.28
end

function ThemeManager.showToast(text, color)
    toast_text = text or ""
    toast_color = color or {1, 1, 1}
    toast_timer = 1.6
end

function ThemeManager.update(dt)
    if restart_halo_timer > 0 then
        restart_halo_timer = math.max(0, restart_halo_timer - dt)
    end
    if toast_timer > 0 then
        toast_timer = math.max(0, toast_timer - dt)
    end

    if ThemeManager.current_theme == 4 then
        for i = 1, STARS_COUNT do
            local s = stars[i]
            s.y = s.y + s.speed * dt
            if s.y > 720 then
                s.y = 0
                s.x = math.random(0, 1280)
            end
        end
    end
end

function ThemeManager.drawBackground()
    local t = ThemeManager.getCurrent()
    love.graphics.setColor(t.bg_color[1], t.bg_color[2], t.bg_color[3], 1.0)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    if ThemeManager.current_theme == 4 then
        for i = 1, STARS_COUNT do
            local s = stars[i]
            love.graphics.setColor(t.secondary[1], t.secondary[2], t.secondary[3], s.alpha * 0.45)
            if s.size == 1 then
                love.graphics.points(s.x, s.y)
            else
                love.graphics.rectangle("fill", s.x, s.y, s.size, s.size)
            end
        end

        local time = love.timer.getTime() * 0.25
        love.graphics.push()
        love.graphics.translate(640, 360)
        love.graphics.rotate(time)
        love.graphics.setLineWidth(1.0)
        love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.035)
        love.graphics.circle("line", 0, 0, 240, 32)
        love.graphics.circle("line", 0, 0, 380, 48)
        love.graphics.pop()

    elseif ThemeManager.current_theme == 1 then
        love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.02)
        for y = 0, 720, 24 do
            love.graphics.line(0, y, 1280, y)
        end

    elseif ThemeManager.current_theme == 2 then
        love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.025)
        for x = -200, 1400, 60 do
            love.graphics.polygon("fill", x, 0, x + 40, 0, x - 120, 720, x - 160, 720)
        end
    end
end

function ThemeManager.drawPanel(x, y, w, h, title, is_selected)
    local t = ThemeManager.getCurrent()

    if is_selected then
        love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.14)
        love.graphics.rectangle("fill", x, y, w, h, 6)

        love.graphics.setLineWidth(1.6)
        love.graphics.setColor(t.secondary[1], t.secondary[2], t.secondary[3], 0.95)
        love.graphics.rectangle("line", x, y, w, h, 6)
    else
        love.graphics.setColor(0.015, 0.02, 0.035, 0.85)
        love.graphics.rectangle("fill", x, y, w, h, 6)

        love.graphics.setLineWidth(1.0)
        love.graphics.setColor(t.border[1], t.border[2], t.border[3], t.border[4] or 0.6)
        love.graphics.rectangle("line", x, y, w, h, 6)
    end

    if title and title ~= "" then
        love.graphics.setFont(FontCache.get(10))
        love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.90)
        love.graphics.print(title, x + 10, y + 6)
    end
end

-- ================================================================
-- AURA DE COMBATE Y POSTURAS (RUSH, BASTION, RESONANCE)
-- ================================================================
function ThemeManager.drawStanceAura(board, stance_id)
    if not board or not stance_id or stance_id <= 0 then return end

    local colors = {
        [1] = {1.0, 0.15, 0.25}, -- 1: RUSH (Carmesí)
        [2] = {0.1, 0.85, 1.00}, -- 2: BASTION (Cyan)
        [3] = {0.8, 0.40, 1.00}, -- 3: RESONANCE (Violeta)
    }

    local clr = colors[stance_id] or {1, 1, 1}
    local pulse = 0.25 + math.sin(love.timer.getTime() * 4.0) * 0.10

    love.graphics.push("all")
    love.graphics.setBlendMode("add")
    love.graphics.setLineWidth(2.5)
    love.graphics.setColor(clr[1], clr[2], clr[3], pulse)
    love.graphics.rectangle("line", board.x - 3, board.y - 3, 246, 486, 6)
    love.graphics.pop()
end

-- ================================================================
-- MENÚ PRINCIPAL: DIBUJADO DINÁMICO SIN GLIFOS ROTOS
-- ================================================================
function ThemeManager.drawMenu(menuItems, menuSubtitles, menuSelection, MetaBalancer)
    ThemeManager.drawBackground()
    local t = ThemeManager.getCurrent()

    -- Título Central
    love.graphics.setFont(FontCache.get(34))
    love.graphics.setColor(1.0, 1.0, 1.0, 0.98)
    love.graphics.printf("MUTRIS", 0, 22, 1280, "center")

    -- Subtítulo con diamantes procedimentales
    local sub_text = t.name
    local tw = FontCache.get(11):getWidth(sub_text)
    love.graphics.setFont(FontCache.get(11))
    love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.90)
    love.graphics.printf(sub_text, 0, 62, 1280, "center")

    love.graphics.setColor(t.secondary[1], t.secondary[2], t.secondary[3], 0.85)
    drawDiamond(640 - (tw / 2) - 16, 68, 4, true)
    drawDiamond(640 + (tw / 2) + 16, 68, 4, true)

    local total_items = #menuItems
    local btn_w = 440

    -- Geometría Dinámica: 8 botones perfectamente proporcionados
    local menu_start_y = 90
    local available_h = 480
    local menu_spacing = math.min(64, math.floor(available_h / total_items))
    local btn_h = math.min(48, menu_spacing - 7)

    for i = 1, total_items do
        local is_sel = (i == menuSelection)
        local bx = 640 - (btn_w / 2)
        local by = menu_start_y + (i - 1) * menu_spacing

        ThemeManager.drawPanel(bx, by, btn_w, btn_h, "", is_sel)

        if is_sel then
            -- Diamantes laterales procedurales
            love.graphics.setColor(t.accent[1], t.accent[2], t.accent[3], 0.98)
            drawDiamond(bx + 18, by + math.floor(btn_h / 2), 5, true)
            drawDiamond(bx + btn_w - 18, by + math.floor(btn_h / 2), 5, true)

            love.graphics.setFont(FontCache.get(13))
            love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
            love.graphics.printf(menuItems[i], bx, by + 6, btn_w, "center")

            love.graphics.setFont(FontCache.get(8))
            love.graphics.setColor(t.secondary[1], t.secondary[2], t.secondary[3], 0.95)
            love.graphics.printf(menuSubtitles[i] or "", bx, by + 26, btn_w, "center")
        else
            love.graphics.setFont(FontCache.get(12))
            love.graphics.setColor(0.70, 0.80, 0.90, 0.78)
            love.graphics.printf(menuItems[i], bx, by + 7, btn_w, "center")

            love.graphics.setFont(FontCache.get(8))
            love.graphics.setColor(0.40, 0.50, 0.60, 0.60)
            love.graphics.printf(menuSubtitles[i] or "", bx, by + 26, btn_w, "center")
        end
    end

    -- Barra de Atajos
    local footer_y = 595
    love.graphics.setFont(FontCache.get(9))
    love.graphics.setColor(0.45, 0.55, 0.65, 0.75)
    love.graphics.printf("[ ARRIBA / ABAJO ] NAVEGAR  |  [ ENTER ] SELECCIONAR  |  [ F5 / F6 ] CAMBIAR SKIN  |  [ F9 ] REC  |  [ F12 ] CAPTURA", 0, footer_y, 1280, "center")
end

function ThemeManager.drawMatrixFrame(board)
    local t = ThemeManager.getCurrent()
    local bx, by = board.x, board.y
    local bs = board.block_size
    local bw, bh = board.cols * bs, board.visible_rows * bs

    love.graphics.setColor(0.01, 0.015, 0.025, 0.88)
    love.graphics.rectangle("fill", bx, by, bw, bh, 4)

    love.graphics.setLineWidth(2.0)
    love.graphics.setColor(t.border[1], t.border[2], t.border[3], 0.85)
    love.graphics.rectangle("line", bx - 1, by - 1, bw + 2, bh + 2, 4)

    love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.95)
    love.graphics.setLineWidth(2.5)
    love.graphics.line(bx - 3, by + 12, bx - 3, by - 3, bx + 12, by - 3)
    love.graphics.line(bx + bw + 3, by + 12, bx + bw + 3, by - 3, bx + bw - 12, by - 3)
    love.graphics.line(bx - 3, by + bh - 12, bx - 3, by + bh + 3, bx + 12, by + bh + 3)
    love.graphics.line(bx + bw + 3, by + bh - 12, bx + bw + 3, by + bh + 3, bx + bw - 12, by + bh + 3)
end

function ThemeManager.drawGarbageBar(board)
    if not board.garbage_queue or #board.garbage_queue == 0 then return end

    local total_lines = 0
    for _, g in ipairs(board.garbage_queue) do
        local l = type(g) == "table" and g.lines or g
        total_lines = total_lines + (l or 0)
    end
    if total_lines <= 0 then return end

    local bs = board.block_size
    local max_h = board.visible_rows * bs
    local bar_h = math.min(max_h, total_lines * bs)
    local bar_x = board.x - 10
    local bar_y = board.y + max_h - bar_h

    love.graphics.setColor(1.0, 0.15, 0.25, 0.95)
    love.graphics.rectangle("fill", bar_x, bar_y, 5, bar_h, 2)
end

function ThemeManager.drawGhostPiece(piece, bx, by, shape, gy, alpha)
    local t = ThemeManager.getCurrent()
    love.graphics.setColor(t.secondary[1], t.secondary[2], t.secondary[3], alpha or 0.35)

    local bs = piece.board and piece.board.block_size or 24
    for r = 1, #shape do
        for c = 1, #shape[r] do
            if shape[r][c] ~= 0 then
                local rx = bx + (piece.x + c - 2) * bs
                local ry = by + (gy + r - (piece.board.visible_rows + 2)) * bs
                love.graphics.setLineWidth(1.4)
                love.graphics.rectangle("line", rx + 2, ry + 2, bs - 4, bs - 4, 2)
            end
        end
    end
end

function ThemeManager.drawRestartHalo()
    if restart_halo_timer <= 0 then return end
    local progress = restart_halo_timer / 0.28
    local alpha = progress * 0.75
    local radius = (1.0 - progress) * 640

    love.graphics.push("all")
    love.graphics.setBlendMode("add")
    love.graphics.setColor(1.0, 1.0, 1.0, alpha * 0.4)
    love.graphics.circle("fill", 640, 360, radius * 0.4)
    love.graphics.setLineWidth(4.0)
    love.graphics.setColor(0.2, 0.9, 1.0, alpha)
    love.graphics.circle("line", 640, 360, radius)
    love.graphics.pop()
end

function ThemeManager.drawEngageTransition(timer, duration)
    local progress = timer / (duration or 0.35)
    love.graphics.setColor(0.0, 0.0, 0.0, progress * 0.85)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)
end

function ThemeManager.drawToast()
    if toast_timer <= 0 or toast_text == "" then return end
    local alpha = math.min(1.0, toast_timer * 2.0)
    local tw = FontCache.get(11):getWidth(toast_text) + 32
    local tx = 640 - (tw / 2)
    local ty = 660

    love.graphics.setColor(0.02, 0.03, 0.06, 0.92 * alpha)
    love.graphics.rectangle("fill", tx, ty, tw, 28, 4)
    love.graphics.setLineWidth(1.2)
    love.graphics.setColor(toast_color[1], toast_color[2], toast_color[3], 0.85 * alpha)
    love.graphics.rectangle("line", tx, ty, tw, 28, 4)

    love.graphics.setFont(FontCache.get(10))
    love.graphics.setColor(1, 1, 1, 0.98 * alpha)
    love.graphics.printf(toast_text, tx, ty + 7, tw, "center")
end

return ThemeManager
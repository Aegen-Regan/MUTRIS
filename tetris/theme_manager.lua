-- ============================================================================
-- MUTRIS ENGINE: DYNAMIC THEME & SKIN SWITCHER ENGINE (1280x720 WIDESCREEN)
-- Arquitectura: Zero-GC / 4 Universos Visuales / Solid Punchy Restart Halos
-- ============================================================================
local ThemeManager = {}

local FontCache       = require "tetris.font_cache"
local SettingsManager = require "settings_manager"
local Blackbox        = nil

ThemeManager.SKINS = {
    CYBER_DAW     = 1,
    NEO_KINETIC   = 2,
    ESPORTS_GLASS = 3,
    COSMIC_VOID   = 4
}

ThemeManager.current_theme = 1
ThemeManager.toast_timer = 0.0
ThemeManager.toast_text = ""

-- Búfer de física elástica para el menú (Zero-GC)
ThemeManager.menu_offsets = {0, 0, 0, 0}

-- Temporizador del Halo Sólido de Reinicio (0.28s ultra-punchy)
ThemeManager.restart_halo_timer = 0.0
ThemeManager.restart_halo_max_time = 0.28

-- ============================================================================
-- 📦 BUFFERS ESTÁTICOS ZERO-GC
-- ============================================================================
local OSC_SAMPLES = 48
local osc_points = {}
for i = 1, OSC_SAMPLES * 2 do osc_points[i] = 0 end

local NUM_STARS = 95
local stars = {}
for i = 1, NUM_STARS do
    stars[i] = {
        x = math.random() * 1280,
        y = math.random() * 720,
        speed = 12 + math.random() * 30,
        size = 1.0 + math.random() * 2.2,
        phase = math.random() * math.pi * 2,
        brightness = 0.3 + math.random() * 0.7
    }
end

local vu_meters = {0, 0, 0, 0}

-- ============================================================================
-- 🎨 DEFINICIÓN DE LOS 4 TEMAS
-- ============================================================================
ThemeManager.THEMES = {
    [1] = {
        id = "cyber_daw",
        name = "01 // CYBER-DAW HARDWARE RACK",
        subtitle = "MODULAR STUDIO CONSOLE // LED VU-METERS & CRT OSCILLOSCOPE",
        bg_clear = {0.012, 0.016, 0.024, 1.0},
        primary = {0.0, 1.0, 0.55},
        secondary = {0.0, 0.85, 1.0},
        accent = {1.0, 0.75, 0.0},
        dark_panel = {0.03, 0.04, 0.07, 0.94},
        border = {0.0, 0.8, 0.4, 0.45},
        matrix_bg = {0.01, 0.02, 0.03, 0.95},
        ghost_color = {0.0, 1.0, 0.55}
    },
    [2] = {
        id = "neo_kinetic",
        name = "02 // NEO-KINETIC STRIKE",
        subtitle = "AGGRESSIVE 12° SLASH GEOMETRY // HALFTONES & ACTION STRIKE",
        bg_clear = {0.04, 0.04, 0.06, 1.0},
        primary = {1.0, 0.08, 0.25},
        secondary = {1.0, 0.85, 0.0},
        accent = {1.0, 1.0, 1.0},
        dark_panel = {0.07, 0.07, 0.10, 0.94},
        border = {1.0, 0.15, 0.3, 0.65},
        matrix_bg = {0.03, 0.03, 0.05, 0.96},
        ghost_color = {1.0, 0.2, 0.35}
    },
    [3] = {
        id = "esports_glass",
        name = "03 // HYPER-CLEAN ESPORTS GLASS",
        subtitle = "PRECISION GLASSMORPHISM // ULTRA-SLIM 1px LASER BORDERS",
        bg_clear = {0.01, 0.015, 0.03, 1.0},
        primary = {0.0, 0.9, 1.0},
        secondary = {0.0, 1.0, 0.65},
        accent = {0.5, 0.6, 0.8},
        dark_panel = {0.02, 0.03, 0.07, 0.82},
        border = {0.0, 0.8, 1.0, 0.35},
        matrix_bg = {0.01, 0.02, 0.04, 0.90},
        ghost_color = {0.0, 0.9, 1.0}
    },
    [4] = {
        id = "cosmic_void",
        name = "04 // SINESTESIA COSMICA",
        subtitle = "ETHEREAL CELESTIAL VOID // SUB-BASS RESONANCE SACRED RINGS",
        bg_clear = {0.005, 0.005, 0.015, 1.0},
        primary = {0.60, 0.35, 1.0},
        secondary = {0.10, 0.90, 1.0},
        accent = {1.0, 0.85, 0.25},
        dark_panel = {0.02, 0.02, 0.05, 0.88},
        border = {0.6, 0.35, 1.0, 0.40},
        matrix_bg = {0.01, 0.01, 0.03, 0.92},
        ghost_color = {0.7, 0.4, 1.0}
    }
}

function ThemeManager.init()
    local saved = SettingsManager.get("theme_skin")
    ThemeManager.current_theme = (type(saved) == "number" and saved >= 1 and saved <= 4) and saved or 1
    ThemeManager.toast_timer = 0.0
    ThemeManager.restart_halo_timer = 0.0
    ThemeManager.menu_offsets = {0, 0, 0, 0}
end

function ThemeManager.getCurrent()
    return ThemeManager.THEMES[ThemeManager.current_theme] or ThemeManager.THEMES[1]
end

function ThemeManager.setTheme(idx)
    if idx < 1 then idx = 4 end
    if idx > 4 then idx = 1 end
    ThemeManager.current_theme = idx
    
    local t = ThemeManager.getCurrent()
    ThemeManager.toast_text = t.name
    ThemeManager.toast_timer = 2.2

    SettingsManager.settings.theme_skin = idx
    SettingsManager.save()

    if not Blackbox then
        Blackbox = require "core.blackbox"
    end
    Blackbox.log("THEME", "SWITCHED TO: " .. t.id, idx, 0)
end

function ThemeManager.cycleNext()
    ThemeManager.setTheme(ThemeManager.current_theme + 1)
end

function ThemeManager.cyclePrev()
    ThemeManager.setTheme(ThemeManager.current_theme - 1)
end

function ThemeManager.triggerRestartHalo()
    ThemeManager.restart_halo_timer = ThemeManager.restart_halo_max_time
    _G.AudioBeatPulse = 1.0
end

function ThemeManager.update(dt)
    if ThemeManager.toast_timer > 0 then
        ThemeManager.toast_timer = math.max(0, ThemeManager.toast_timer - dt)
    end

    if ThemeManager.restart_halo_timer > 0 then
        ThemeManager.restart_halo_timer = math.max(0, ThemeManager.restart_halo_timer - dt)
    end

    local energy = _G.TrackEnergyPunch or 0
    local pulse  = _G.AudioBeatPulse or 0

    for i = 1, 4 do
        local target = (i == _G.MenuSelectionIndex) and 18.0 or 0.0
        ThemeManager.menu_offsets[i] = ThemeManager.menu_offsets[i] + (target - ThemeManager.menu_offsets[i]) * 14.0 * dt
    end

    if ThemeManager.current_theme == 4 then
        for i = 1, NUM_STARS do
            local s = stars[i]
            s.y = s.y + s.speed * dt * (1.0 + energy * 2.5)
            s.phase = s.phase + dt * 2.5
            if s.y > 720 then
                s.y = -5
                s.x = math.random() * 1280
            end
        end
    end

    if ThemeManager.current_theme == 1 then
        for i = 1, 4 do
            local target = (energy * 0.75) + (pulse * 0.25) + math.sin(love.timer.getTime() * 8 + i * 1.5) * 0.15
            vu_meters[i] = vu_meters[i] + (target - vu_meters[i]) * 16 * dt
            vu_meters[i] = math.max(0.05, math.min(1.0, vu_meters[i]))
        end
    end
end

-- ============================================================================
-- 🌟 RENDERIZADO DEL HALO SÓLIDO DE REINICIO (IMPACTO VISCERAL)
-- ============================================================================
function ThemeManager.drawRestartHalo()
    if ThemeManager.restart_halo_timer <= 0 then return end

    local p = ThemeManager.restart_halo_timer / ThemeManager.restart_halo_max_time
    local alpha = p * p -- Decaimiento cuadrático rápido
    local exp = 1.0 - (p * p * p) -- Expansión explosiva no-lineal
    local cx, cy = 640, 360

    love.graphics.push("all")
    love.graphics.setBlendMode("add")

    -- 1. Núcleo Blanco Sólido de Impacto Central
    local core_rad = (1.0 - p) * 220
    love.graphics.setColor(1.0, 1.0, 1.0, alpha * 0.85)
    love.graphics.circle("fill", cx, cy, core_rad)

    -- 2. Disco de Onda Sólida Tematizado
    if ThemeManager.current_theme == 1 then
        -- Ráfaga Sólida Fósforo Esmeralda & Cian CRT
        local rad = exp * 920
        love.graphics.setColor(0.0, 1.0, 0.55, alpha * 0.65)
        love.graphics.circle("fill", cx, cy, rad)
        love.graphics.setColor(0.0, 0.85, 1.0, alpha * 0.40)
        love.graphics.circle("fill", cx, cy, rad * 0.72)

    elseif ThemeManager.current_theme == 2 then
        -- Romboide Sólido Oro Solar & Carmesí (Fighter Strike Blast)
        local d_size = exp * 880
        love.graphics.setColor(1.0, 0.08, 0.25, alpha * 0.70)
        love.graphics.polygon("fill", cx, cy - d_size, cx + d_size * 1.35, cy, cx, cy + d_size, cx - d_size * 1.35, cy)
        love.graphics.setColor(1.0, 0.85, 0.0, alpha * 0.85)
        love.graphics.polygon("fill", cx, cy - d_size * 0.55, cx + d_size * 0.75, cy, cx, cy + d_size * 0.55, cx - d_size * 0.75, cy)

    elseif ThemeManager.current_theme == 3 then
        -- Disco Sólido de Refracción Holográfica Cian Láser
        local rad = exp * 900
        love.graphics.setColor(0.0, 0.95, 1.0, alpha * 0.65)
        love.graphics.circle("fill", cx, cy, rad)
        love.graphics.setColor(0.0, 1.0, 0.65, alpha * 0.40)
        love.graphics.circle("fill", cx, cy, rad * 0.68)

    elseif ThemeManager.current_theme == 4 then
        -- Onda de Singularidad Supernova Sólida Violeta / Astral
        local rad = exp * 950
        love.graphics.setColor(0.60, 0.35, 1.0, alpha * 0.70)
        love.graphics.circle("fill", cx, cy, rad)
        love.graphics.setColor(0.10, 0.90, 1.0, alpha * 0.45)
        love.graphics.circle("fill", cx, cy, rad * 0.70)
    end

    love.graphics.setBlendMode("alpha")
    love.graphics.pop()
end

function ThemeManager.drawEngageTransition(timer, duration)
    if timer <= 0 then return end
    local progress = timer / duration

    love.graphics.push("all")

    if ThemeManager.current_theme == 1 then
        local scan_y = (1.0 - progress) * 720
        love.graphics.setColor(0, 1.0, 0.55, progress * 0.85)
        love.graphics.rectangle("fill", 0, scan_y - 20, 1280, 40)
        love.graphics.setLineWidth(3)
        love.graphics.setColor(1, 1, 1, progress)
        love.graphics.line(0, scan_y, 1280, scan_y)

    elseif ThemeManager.current_theme == 2 then
        local offset = (1.0 - progress) * 900
        love.graphics.setColor(1.0, 0.08, 0.25, 0.95)
        love.graphics.polygon("fill", -100, 0, 740 - offset, 0, 540 - offset, 720, -100, 720)
        love.graphics.setColor(1.0, 0.85, 0.0, 0.95)
        love.graphics.polygon("fill", 1380, 720, 540 + offset, 720, 740 + offset, 0, 1380, 0)

    elseif ThemeManager.current_theme == 3 then
        local aperture = (1.0 - progress) * 640
        love.graphics.setColor(0.0, 0.9, 1.0, progress * 0.7)
        love.graphics.rectangle("fill", 0, 0, 640 - aperture, 720)
        love.graphics.rectangle("fill", 640 + aperture, 0, 640 - aperture, 720)

    elseif ThemeManager.current_theme == 4 then
        local rad = progress * 600
        love.graphics.setBlendMode("add")
        love.graphics.setColor(0.6, 0.35, 1.0, progress * 0.6)
        love.graphics.circle("fill", 640, 360, rad)
        love.graphics.setColor(0.1, 0.9, 1.0, progress * 0.8)
        love.graphics.circle("line", 640, 360, rad * 1.2)
        love.graphics.setBlendMode("alpha")
    end

    love.graphics.pop()
end

function ThemeManager.drawGarbageBar(board)
    if not board or not board.garbage_queue then return end
    local q_count = #board.garbage_queue
    if q_count <= 0 then return end

    local total_lines = 0
    for i = 1, q_count do
        local item = board.garbage_queue[i]
        if type(item) == "number" then
            total_lines = total_lines + item
        elseif type(item) == "table" then
            total_lines = total_lines + (item.lines or item.amount or item[1] or 0)
        end
    end
    if total_lines <= 0 then return end

    local pulse = _G.AudioBeatPulse or 0
    local is_human = (board.player_type == "human")
    local gx = is_human and (board.x - 6) or (board.x + 242)
    local gy = board.y + 480
    local max_h = 480
    local cur_h = math.min(max_h, total_lines * 24)

    love.graphics.push("all")
    love.graphics.setBlendMode("add")

    local flash = 0.7 + pulse * 0.3
    love.graphics.setColor(1.0, 0.15, 0.20, flash * 0.9)
    love.graphics.rectangle("fill", gx, gy - cur_h, 4, cur_h)

    love.graphics.setColor(1.0, 0.85, 0.2, flash)
    love.graphics.rectangle("fill", gx - 1, gy - cur_h - 4, 6, 4)

    love.graphics.setBlendMode("alpha")
    love.graphics.pop()
end

function ThemeManager.drawStanceAura(board)
    local st = board.current_stance or 0
    if st == 0 then return end

    local pulse = _G.AudioBeatPulse or 0
    local time = love.timer.getTime()
    local bx, by, bw, bh = board.x, board.y, 240, 480

    love.graphics.push("all")
    love.graphics.setBlendMode("add")

    if st == 1 then
        love.graphics.setColor(1.0, 0.15, 0.25, 0.25 + pulse * 0.25)
        for i = 1, 6 do
            local wave = math.sin(time * 12 + i) * 6
            love.graphics.line(bx - 3, by + bh - i * 75, bx - 3 + wave, by + bh - (i + 1) * 75)
            love.graphics.line(bx + bw + 3, by + bh - i * 75, bx + bw + 3 - wave, by + bh - (i + 1) * 75)
        end

    elseif st == 2 then
        local is_parry_active = (board.parry_active_timer and board.parry_active_timer > 0)
        local shield_alpha = is_parry_active and 0.8 or (0.15 + pulse * 0.15)
        love.graphics.setColor(0.1, 0.85, 1.0, shield_alpha)
        love.graphics.setLineWidth(is_parry_active and 3.0 or 1.5)
        love.graphics.rectangle("line", bx - 6, by - 6, bw + 12, bh + 12, 6)

    elseif st == 3 then
        love.graphics.setColor(0.65, 0.3, 1.0, 0.20 + pulse * 0.25)
        local ring_y = by + ((time * 220) % bh)
        love.graphics.line(bx - 12, ring_y, bx + bw + 12, ring_y)
    end

    love.graphics.setBlendMode("alpha")
    love.graphics.pop()
end

function ThemeManager.drawBackground()
    local t = ThemeManager.getCurrent()
    local energy = _G.TrackEnergyPunch or 0
    local pulse  = _G.AudioBeatPulse or 0
    local time   = love.timer.getTime()

    love.graphics.push("all")

    if ThemeManager.current_theme == 1 then
        love.graphics.setColor(0, 0.8, 0.4, 0.04 + energy * 0.03)
        for x = 0, 1280, 40 do love.graphics.line(x, 0, x, 720) end
        for y = 0, 720, 40  do love.graphics.line(0, y, 1280, y) end

    elseif ThemeManager.current_theme == 2 then
        love.graphics.setBlendMode("add")
        love.graphics.setColor(1.0, 0.08, 0.25, 0.06 + pulse * 0.08)
        love.graphics.setLineWidth(4)
        for offset = -400, 1600, 100 do
            love.graphics.line(offset + (pulse * 25), 0, offset - 220 + (pulse * 25), 720)
        end

        love.graphics.setColor(1.0, 0.85, 0.0, 0.04 + energy * 0.05)
        for gx = 50, 1230, 90 do
            for gy = 50, 670, 90 do
                love.graphics.circle("fill", gx, gy, 2.5 + pulse * 3.0)
            end
        end

    elseif ThemeManager.current_theme == 3 then
        love.graphics.setColor(0, 0.9, 1.0, 0.03 + pulse * 0.02)
        for x = 0, 1280, 80 do love.graphics.line(x, 0, x, 720) end
        for y = 0, 720, 80  do love.graphics.line(0, y, 1280, y) end

    elseif ThemeManager.current_theme == 4 then
        love.graphics.setBlendMode("add")
        for i = 1, NUM_STARS do
            local s = stars[i]
            local twinkle = 0.4 + math.sin(s.phase) * 0.5
            love.graphics.setColor(0.7, 0.5, 1.0, s.brightness * twinkle * (0.6 + energy * 0.4))
            love.graphics.circle("fill", s.x, s.y, s.size)
        end

        local ring_rad = 200 + pulse * 60 + energy * 40
        love.graphics.setColor(0.6, 0.2, 1.0, 0.07 + pulse * 0.12)
        love.graphics.setLineWidth(2.0)
        love.graphics.circle("line", 640, 360, ring_rad)
        love.graphics.setColor(0.1, 0.9, 1.0, 0.05 + energy * 0.10)
        love.graphics.circle("line", 640, 360, ring_rad * 1.5)
    end

    love.graphics.pop()
end

function ThemeManager.drawPanel(x, y, w, h, title, is_active, custom_accent)
    local t = ThemeManager.getCurrent()
    local pulse = _G.AudioBeatPulse or 0
    love.graphics.push("all")

    if ThemeManager.current_theme == 1 then
        love.graphics.setColor(t.dark_panel)
        love.graphics.rectangle("fill", x, y, w, h, 2)
        love.graphics.setLineWidth(is_active and 2.0 or 1.0)
        local c = custom_accent or (is_active and t.primary or t.border)
        love.graphics.setColor(c[1], c[2], c[3], is_active and 0.95 or 0.45)
        love.graphics.rectangle("line", x, y, w, h, 2)

        love.graphics.setColor(1, 1, 1, 0.3)
        love.graphics.rectangle("fill", x + 3, y + 3, 2, 2)
        love.graphics.rectangle("fill", x + w - 5, y + 3, 2, 2)
        love.graphics.rectangle("fill", x + 3, y + h - 5, 2, 2)
        love.graphics.rectangle("fill", x + w - 5, y + h - 5, 2, 2)

    elseif ThemeManager.current_theme == 2 then
        love.graphics.setColor(t.dark_panel)
        love.graphics.rectangle("fill", x, y, w, h, 0)
        if is_active then
            love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.9)
            love.graphics.setLineWidth(3.0)
            love.graphics.rectangle("line", x - 2, y - 2, w + 4, h + 4)
            love.graphics.setColor(t.secondary[1], t.secondary[2], t.secondary[3], 0.95)
            love.graphics.polygon("fill", x - 2, y - 2, x + 16, y - 2, x - 2, y + 16)
        else
            love.graphics.setColor(t.border[1], t.border[2], t.border[3], 0.4)
            love.graphics.setLineWidth(1.5)
            love.graphics.rectangle("line", x, y, w, h)
        end

    elseif ThemeManager.current_theme == 3 then
        love.graphics.setColor(t.dark_panel)
        love.graphics.rectangle("fill", x, y, w, h, 6)
        love.graphics.setLineWidth(is_active and 1.8 or 1.0)
        local c = custom_accent or (is_active and t.primary or t.border)
        love.graphics.setColor(c[1], c[2], c[3], is_active and (0.8 + pulse * 0.2) or 0.35)
        love.graphics.rectangle("line", x, y, w, h, 6)

    elseif ThemeManager.current_theme == 4 then
        love.graphics.setColor(t.dark_panel)
        love.graphics.rectangle("fill", x, y, w, h, 4)
        if is_active then
            love.graphics.setBlendMode("add")
            love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.35 + pulse * 0.25)
            love.graphics.rectangle("line", x - 2, y - 2, w + 4, h + 4, 6)
            love.graphics.setBlendMode("alpha")
        end
        love.graphics.setColor(t.border)
        love.graphics.setLineWidth(1.2)
        love.graphics.rectangle("line", x, y, w, h, 4)
    end

    if title and title ~= "" then
        love.graphics.setFont(FontCache.get(9))
        love.graphics.setColor(1, 1, 1, 0.75)
        love.graphics.print(title, x + 10, y + 5)
    end

    love.graphics.pop()
end

function ThemeManager.drawMatrixFrame(board)
    local t = ThemeManager.getCurrent()
    local pulse = _G.AudioBeatPulse or 0
    local energy = _G.TrackEnergyPunch or 0

    local bx, by, bw, bh = board.x, board.y, 240, 480

    love.graphics.push("all")

    if ThemeManager.current_theme == 1 then
        love.graphics.setColor(0.015, 0.025, 0.04, 0.95)
        love.graphics.rectangle("fill", bx, by, bw, bh, 2)

        love.graphics.setLineWidth(1.8)
        love.graphics.setColor(0, 0.9, 0.45, 0.40 + pulse * 0.30)
        love.graphics.rectangle("line", bx, by, bw, bh, 2)

        love.graphics.setColor(0, 1.0, 0.55, 0.9)
        love.graphics.rectangle("fill", bx - 3, by - 3, 10, 3)
        love.graphics.rectangle("fill", bx - 3, by - 3, 3, 10)
        love.graphics.rectangle("fill", bx + bw - 7, by - 3, 10, 3)
        love.graphics.rectangle("fill", bx + bw, by - 3, 3, 10)
        love.graphics.rectangle("fill", bx - 3, by + bh, 10, 3)
        love.graphics.rectangle("fill", bx - 3, by + bh - 7, 3, 10)
        love.graphics.rectangle("fill", bx + bw - 7, by + bh, 10, 3)
        love.graphics.rectangle("fill", bx + bw, by + bh - 7, 3, 10)

    elseif ThemeManager.current_theme == 2 then
        love.graphics.setColor(0.03, 0.03, 0.05, 0.96)
        love.graphics.rectangle("fill", bx, by, bw, bh)

        love.graphics.setLineWidth(2.5)
        love.graphics.setColor(1.0, 0.08, 0.25, 0.85 + pulse * 0.15)
        love.graphics.rectangle("line", bx - 2, by - 2, bw + 4, bh + 4)

        love.graphics.setColor(1.0, 0.85, 0.0, 1.0)
        love.graphics.polygon("fill", bx - 2, by - 2, bx + 18, by - 2, bx - 2, by + 18)
        love.graphics.polygon("fill", bx + bw + 2, by + bh + 2, bx + bw - 18, by + bh + 2, bx + bw + 2, by + bh - 18)

    elseif ThemeManager.current_theme == 3 then
        love.graphics.setColor(0.01, 0.02, 0.04, 0.90)
        love.graphics.rectangle("fill", bx, by, bw, bh, 6)

        love.graphics.setLineWidth(1.5)
        love.graphics.setColor(0.0, 0.9, 1.0, 0.40 + pulse * 0.25)
        love.graphics.rectangle("line", bx, by, bw, bh, 6)

        love.graphics.setFont(FontCache.get(8))
        love.graphics.setColor(0.0, 0.9, 1.0, 0.7)
        local tag = (board.player_type == "human") and "[P1 // MATRIX 10x20]" or "[AI // MATRIX 10x20]"
        love.graphics.print(tag, bx + 6, by - 12)

    elseif ThemeManager.current_theme == 4 then
        love.graphics.setColor(0.01, 0.01, 0.03, 0.92)
        love.graphics.rectangle("fill", bx, by, bw, bh, 4)

        love.graphics.setBlendMode("add")
        love.graphics.setColor(0.6, 0.35, 1.0, 0.30 + pulse * 0.25)
        love.graphics.rectangle("line", bx - 2, by - 2, bw + 4, bh + 4, 6)

        love.graphics.setColor(0.1, 0.9, 1.0, 0.20 + energy * 0.20)
        love.graphics.line(bx - 6, by, bx - 6, by + bh)
        love.graphics.line(bx + bw + 6, by, bx + bw + 6, by + bh)
        love.graphics.setBlendMode("alpha")
    end

    love.graphics.pop()
end

function ThemeManager.drawGhostPiece(piece, bx, by, shape, gy, ghost_alpha)
    local t = ThemeManager.getCurrent()
    local pulse = _G.AudioBeatPulse or 0
    local clr = piece.board.colors[piece.id] or {1, 1, 1}

    love.graphics.push("all")

    if ThemeManager.current_theme == 1 then
        for r = 1, #shape do
            for c = 1, #shape[r] do
                if shape[r][c] ~= 0 then
                    local gx, g_y = bx + (piece.x + c - 2) * 24, by + (gy + r - 22) * 24
                    love.graphics.setColor(0, 1.0, 0.55, ghost_alpha * 0.25)
                    love.graphics.rectangle("fill", gx + 2, g_y + 2, 20, 20, 1)
                    love.graphics.setColor(0, 1.0, 0.55, ghost_alpha * (0.8 + pulse * 0.2))
                    love.graphics.setLineWidth(1.5)
                    love.graphics.rectangle("line", gx + 2, g_y + 2, 20, 20, 1)
                    love.graphics.line(gx + 4, g_y + 12, gx + 20, g_y + 12)
                end
            end
        end

    elseif ThemeManager.current_theme == 2 then
        for r = 1, #shape do
            for c = 1, #shape[r] do
                if shape[r][c] ~= 0 then
                    local gx, g_y = bx + (piece.x + c - 2) * 24, by + (gy + r - 22) * 24
                    love.graphics.setColor(1.0, 0.08, 0.25, ghost_alpha * 0.35)
                    love.graphics.rectangle("fill", gx + 2, g_y + 2, 20, 20)
                    love.graphics.setColor(1.0, 0.85, 0.0, ghost_alpha * 0.95)
                    love.graphics.setLineWidth(2.0)
                    love.graphics.rectangle("line", gx + 1, g_y + 1, 22, 22)
                end
            end
        end

    elseif ThemeManager.current_theme == 3 then
        for r = 1, #shape do
            for c = 1, #shape[r] do
                if shape[r][c] ~= 0 then
                    local gx, g_y = bx + (piece.x + c - 2) * 24, by + (gy + r - 22) * 24
                    love.graphics.setColor(clr[1], clr[2], clr[3], ghost_alpha * 0.20)
                    love.graphics.rectangle("fill", gx + 2, g_y + 2, 20, 20, 2)
                    love.graphics.setColor(clr[1], clr[2], clr[3], ghost_alpha * (0.85 + pulse * 0.2))
                    love.graphics.setLineWidth(1.4)
                    love.graphics.rectangle("line", gx + 2, g_y + 2, 20, 20, 2)
                end
            end
        end

    elseif ThemeManager.current_theme == 4 then
        love.graphics.setBlendMode("add")
        for r = 1, #shape do
            for c = 1, #shape[r] do
                if shape[r][c] ~= 0 then
                    local gx, g_y = bx + (piece.x + c - 2) * 24, by + (gy + r - 22) * 24
                    love.graphics.setColor(0.6, 0.35, 1.0, ghost_alpha * 0.40)
                    love.graphics.rectangle("fill", gx + 3, g_y + 3, 18, 18, 4)
                    love.graphics.setColor(0.1, 0.9, 1.0, ghost_alpha * (0.9 + pulse * 0.2))
                    love.graphics.setLineWidth(1.8)
                    love.graphics.rectangle("line", gx + 2, g_y + 2, 20, 20, 4)
                end
            end
        end
        love.graphics.setBlendMode("alpha")
    end

    love.graphics.pop()
end

function ThemeManager.drawMenu(menuItems, menuSubtitles, menuSelection, MetaBalancer)
    _G.MenuSelectionIndex = menuSelection
    local t = ThemeManager.getCurrent()
    local pulse = _G.AudioBeatPulse or 0
    local energy = _G.TrackEnergyPunch or 0
    local time = love.timer.getTime()

    love.graphics.push("all")

    if ThemeManager.current_theme == 1 then
        love.graphics.setFont(FontCache.get(28))
        love.graphics.setColor(1, 1, 1, 0.98)
        love.graphics.print("MUTRIS // DIGITAL AUDIO WORKSTATION", 80, 50)
        love.graphics.setFont(FontCache.get(10))
        love.graphics.setColor(0, 1, 0.55, 0.9)
        love.graphics.print("MASTER SYNTHESIZER CONSOLE  |  CAMELOT MODAL ENGINE  |  144/240Hz ZERO-GC", 80, 88)

        local start_x, start_y = 80, 130
        local fader_w, fader_h = 580, 78

        for i, item in ipairs(menuItems) do
            local off_x = ThemeManager.menu_offsets[i] or 0
            local fy = start_y + (i - 1) * 92
            local is_sel = (i == menuSelection)

            love.graphics.setColor(0.02, 0.04, 0.08, 0.92)
            love.graphics.rectangle("fill", start_x + off_x, fy, fader_w, fader_h, 3)
            love.graphics.setColor(is_sel and {0, 1, 0.55, 0.95} or {0, 0.6, 0.4, 0.35})
            love.graphics.setLineWidth(is_sel and 2.0 or 1.0)
            love.graphics.rectangle("line", start_x + off_x, fy, fader_w, fader_h, 3)

            love.graphics.setColor(0.04, 0.08, 0.15, 0.9)
            love.graphics.rectangle("fill", start_x + off_x + 10, fy + 12, 64, 22, 2)
            love.graphics.setFont(FontCache.get(9))
            love.graphics.setColor(0, 1, 0.55, 0.9)
            love.graphics.printf(string.format("CH.0%d", i), start_x + off_x + 10, fy + 17, 64, "center")

            love.graphics.setFont(FontCache.get(15))
            love.graphics.setColor(is_sel and {1, 1, 1, 1} or {0.7, 0.8, 0.9, 0.8})
            love.graphics.print(item, start_x + off_x + 85, fy + 14)

            love.graphics.setFont(FontCache.get(9))
            love.graphics.setColor(0.4, 0.8, 0.7, is_sel and 0.9 or 0.5)
            love.graphics.print(menuSubtitles[i] or "", start_x + off_x + 85, fy + 42)

            local vu_val = vu_meters[i] or 0.2
            for seg = 1, 8 do
                local seg_x = start_x + off_x + fader_w - 90 + (seg - 1) * 9
                local seg_on = (seg / 8) <= vu_val
                if seg <= 5 then
                    love.graphics.setColor(seg_on and {0, 1, 0.3, 0.95} or {0, 0.25, 0.1, 0.4})
                elseif seg <= 7 then
                    love.graphics.setColor(seg_on and {1, 0.8, 0.0, 0.95} or {0.3, 0.25, 0.0, 0.4})
                else
                    love.graphics.setColor(seg_on and {1, 0.1, 0.2, 0.95} or {0.3, 0.05, 0.05, 0.4})
                end
                love.graphics.rectangle("fill", seg_x, fy + 26, 6, 26, 1)
            end
        end

        local osc_x, osc_y, osc_w, osc_h = 700, 130, 500, 240
        love.graphics.setColor(0.01, 0.03, 0.06, 0.95)
        love.graphics.rectangle("fill", osc_x, osc_y, osc_w, osc_h, 4)
        love.graphics.setColor(0, 0.8, 0.4, 0.6)
        love.graphics.rectangle("line", osc_x, osc_y, osc_w, osc_h, 4)

        love.graphics.setFont(FontCache.get(10))
        love.graphics.setColor(0, 1, 0.55, 0.9)
        love.graphics.print("LIVE CRT OSCILLOSCOPE MONITOR", osc_x + 16, osc_y + 12)

        love.graphics.setBlendMode("add")
        love.graphics.setColor(0, 1.0, 0.55, 0.85 + pulse * 0.15)
        love.graphics.setLineWidth(2.5)
        local base_y = osc_y + (osc_h / 2) + 15
        local idx = 1
        for i = 1, OSC_SAMPLES do
            local px = osc_x + 20 + (i - 1) * ((osc_w - 40) / (OSC_SAMPLES - 1))
            local freq = 5.0 + energy * 6.0
            local amp = 30.0 + pulse * 45.0 + energy * 30.0
            local py = base_y + math.sin(time * freq + (i * 0.3)) * amp * math.cos(i * 0.1)
            osc_points[idx] = px
            osc_points[idx + 1] = py
            idx = idx + 2
        end
        love.graphics.line(osc_points)
        love.graphics.setBlendMode("alpha")

        local arc_y = osc_y + osc_h + 20
        love.graphics.setColor(0.02, 0.04, 0.08, 0.92)
        love.graphics.rectangle("fill", osc_x, arc_y, osc_w, 106, 4)
        love.graphics.setColor(0.0, 0.7, 0.4, 0.5)
        love.graphics.rectangle("line", osc_x, arc_y, osc_w, 106, 4)

        love.graphics.setFont(FontCache.get(10))
        love.graphics.setColor(0, 1, 0.55, 0.95)
        love.graphics.print("ARCHON AUTO-TUNER TELEMETRY", osc_x + 16, arc_y + 14)
        love.graphics.setFont(FontCache.get(9))
        love.graphics.setColor(0.7, 0.85, 0.9, 0.8)
        love.graphics.print(MetaBalancer.patch_notes or "SYSTEM EQUILIBRIUM OPTIMAL", osc_x + 16, arc_y + 36)
        love.graphics.print("HARDWARE TIMEBASE: 0.0ms DRIFT | SAMPLING: 144/240Hz", osc_x + 16, arc_y + 56)

    elseif ThemeManager.current_theme == 2 then
        love.graphics.setFont(FontCache.get(44))
        love.graphics.setColor(1, 0.08, 0.25, 0.98)
        love.graphics.print("MUTRIS", 100, 42)
        love.graphics.setFont(FontCache.get(14))
        love.graphics.setColor(1, 0.85, 0.0, 0.95)
        love.graphics.print("/// SYNTHETIC TRANSCENDENCE /// [ OVERDRIVE ]", 100, 94)

        local start_y = 145
        local ribbon_w, ribbon_h = 620, 68

        for i, item in ipairs(menuItems) do
            local off_x = ThemeManager.menu_offsets[i] or 0
            local ry = start_y + (i - 1) * 88
            local is_sel = (i == menuSelection)
            local slant = 35

            if is_sel then
                love.graphics.setColor(1.0, 0.08, 0.25, 0.95)
                love.graphics.polygon("fill", 100 + off_x + slant, ry, 100 + off_x + ribbon_w + slant, ry, 100 + off_x + ribbon_w, ry + ribbon_h, 100 + off_x, ry + ribbon_h)

                love.graphics.setColor(1, 0.85, 0, 1.0)
                love.graphics.polygon("fill", 100 + off_x, ry, 100 + off_x + 18, ry, 100 + off_x + 18 - slant, ry + ribbon_h, 100 + off_x - slant, ry + ribbon_h)

                love.graphics.setFont(FontCache.get(18))
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.print(string.format("/// 0%d.  %s", i, item), 130 + off_x, ry + 12)

                love.graphics.setFont(FontCache.get(9))
                love.graphics.setColor(1, 0.9, 0.3, 0.95)
                love.graphics.print(menuSubtitles[i] or "", 130 + off_x, ry + 40)
            else
                love.graphics.setColor(0.08, 0.08, 0.12, 0.88)
                love.graphics.polygon("fill", 100 + slant, ry, 100 + ribbon_w + slant, ry, 100 + ribbon_w, ry + ribbon_h, 100, ry + ribbon_h)
                love.graphics.setColor(1.0, 0.15, 0.3, 0.4)
                love.graphics.setLineWidth(1.5)
                love.graphics.polygon("line", 100 + slant, ry, 100 + ribbon_w + slant, ry, 100 + ribbon_w, ry + ribbon_h, 100, ry + ribbon_h)

                love.graphics.setFont(FontCache.get(16))
                love.graphics.setColor(0.8, 0.8, 0.85, 0.85)
                love.graphics.print(string.format("    0%d.  %s", i, item), 130, ry + 13)

                love.graphics.setFont(FontCache.get(9))
                love.graphics.setColor(0.5, 0.5, 0.6, 0.6)
                love.graphics.print(menuSubtitles[i] or "", 130, ry + 40)
            end
        end

        local ac_x, ac_y, ac_w, ac_h = 780, 145, 420, 350
        love.graphics.setColor(0.08, 0.08, 0.12, 0.92)
        love.graphics.rectangle("fill", ac_x, ac_y, ac_w, ac_h)
        love.graphics.setColor(1.0, 0.08, 0.25, 0.8)
        love.graphics.setLineWidth(2.5)
        love.graphics.rectangle("line", ac_x, ac_y, ac_w, ac_h)

        love.graphics.setFont(FontCache.get(14))
        love.graphics.setColor(1.0, 0.85, 0.0, 1.0)
        love.graphics.print("RHYTHMIC STRIKE MATRIX", ac_x + 20, ac_y + 20)

        love.graphics.setFont(FontCache.get(10))
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.print("• GROOVE WINDOW: ±35ms (RESONANCE ±45ms)", ac_x + 20, ac_y + 60)
        love.graphics.print("• KINETIC PARRY: 3 FRAMES (50% COUNTER)", ac_x + 20, ac_y + 90)
        love.graphics.print("• STANCES: RUSH (1.5x) | BASTION | RESONANCE", ac_x + 20, ac_y + 120)

        love.graphics.setColor(1.0, 0.08, 0.25, 0.2)
        love.graphics.rectangle("fill", ac_x + 20, ac_y + 160, ac_w - 40, 160)
        love.graphics.setColor(1.0, 0.08, 0.25, 0.9)
        love.graphics.rectangle("line", ac_x + 20, ac_y + 160, ac_w - 40, 160)

        love.graphics.setFont(FontCache.get(11))
        love.graphics.setColor(1, 0.85, 0, 1.0)
        love.graphics.print("[ ARCHON DDA ENGINE ]", ac_x + 35, ac_y + 175)
        love.graphics.setFont(FontCache.get(9))
        love.graphics.setColor(1, 1, 1, 0.85)
        love.graphics.print(MetaBalancer.patch_notes or "APEX AGGRESSION BALANCED", ac_x + 35, ac_y + 205)

    elseif ThemeManager.current_theme == 3 then
        love.graphics.setFont(FontCache.get(20))
        love.graphics.setColor(0.0, 0.9, 1.0, 0.98)
        love.graphics.print("MUTRIS ESPORTS", 100, 48)
        love.graphics.setFont(FontCache.get(10))
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.print("PRECISION GLASSMORPHISM // MATCH ARENA", 280, 55)

        local start_y = 115
        local card_w, card_h = 520, 95

        for i, item in ipairs(menuItems) do
            local off_x = ThemeManager.menu_offsets[i] or 0
            local cy = start_y + (i - 1) * 110
            local is_sel = (i == menuSelection)

            love.graphics.setColor(0.02, 0.03, 0.07, 0.85)
            love.graphics.rectangle("fill", 100 + off_x, cy, card_w, card_h, 6)
            love.graphics.setLineWidth(is_sel and 1.8 or 1.0)
            love.graphics.setColor(is_sel and {0, 0.9, 1.0, 0.95} or {0, 0.6, 0.8, 0.3})
            love.graphics.rectangle("line", 100 + off_x, cy, card_w, card_h, 6)

            love.graphics.setColor(is_sel and {0, 0.9, 1.0, 0.25} or {0.1, 0.15, 0.25, 0.4})
            love.graphics.rectangle("fill", 100 + off_x + card_w - 110, cy + 16, 95, 22, 10)
            love.graphics.setFont(FontCache.get(8))
            love.graphics.setColor(is_sel and {0, 0.95, 1.0, 1.0} or {0.5, 0.6, 0.7, 0.7})
            love.graphics.printf(is_sel and "ENGAGE [A]" or "READY", 100 + off_x + card_w - 110, cy + 22, 95, "center")

            love.graphics.setFont(FontCache.get(16))
            love.graphics.setColor(is_sel and {1, 1, 1, 1} or {0.7, 0.8, 0.9, 0.85})
            love.graphics.print(item, 125 + off_x, cy + 18)

            love.graphics.setFont(FontCache.get(9))
            love.graphics.setColor(0.0, 0.9, 1.0, is_sel and 0.9 or 0.5)
            love.graphics.print(menuSubtitles[i] or "", 125 + off_x, cy + 50)
        end

        local p_x, p_w = 660, 520
        love.graphics.setColor(0.02, 0.03, 0.07, 0.85)
        love.graphics.rectangle("fill", p_x, 115, p_w, 200, 6)
        love.graphics.setColor(0, 0.9, 1.0, 0.35)
        love.graphics.rectangle("line", p_x, 115, p_w, 200, 6)

        love.graphics.setFont(FontCache.get(12))
        love.graphics.setColor(0, 0.95, 1.0, 0.95)
        love.graphics.print("PLAYER PERFORMANCE PASSPORT", p_x + 20, 135)

        love.graphics.setFont(FontCache.get(10))
        love.graphics.setColor(1, 1, 1, 0.85)
        love.graphics.print("• TARGET ENGINE PPS: 1.45 - 2.50 PPS", p_x + 20, 175)
        love.graphics.print("• BEAT-LOCK GROOVE ACCURACY: 92.4%", p_x + 20, 205)
        love.graphics.print("• HARDWARE LATENCY: 0.00ms DETERMINISTIC", p_x + 20, 235)

        love.graphics.setColor(0.02, 0.03, 0.07, 0.85)
        love.graphics.rectangle("fill", p_x, 335, p_w, 210, 6)
        love.graphics.setColor(0, 1.0, 0.65, 0.35)
        love.graphics.rectangle("line", p_x, 335, p_w, 210, 6)

        love.graphics.setFont(FontCache.get(12))
        love.graphics.setColor(0, 1.0, 0.65, 0.95)
        love.graphics.print("ARCHON AUTO-BALANCE LIVE NODES", p_x + 20, 355)
        love.graphics.setFont(FontCache.get(9))
        love.graphics.setColor(0.7, 0.85, 0.9, 0.8)
        love.graphics.print(MetaBalancer.patch_notes or "SYSTEM EQUILIBRIUM CALIBRATED", p_x + 20, 395)
        love.graphics.print("ADAPTIVE DIFFICULTY ADJUSTMENT: ON", p_x + 20, 425)

    elseif ThemeManager.current_theme == 4 then
        love.graphics.setFont(FontCache.get(34))
        love.graphics.setColor(1, 1, 1, 0.98)
        love.graphics.printf("MUTRIS", 0, 55, 1280, "center")
        love.graphics.setFont(FontCache.get(12))
        love.graphics.setColor(0.6, 0.35, 1.0, 0.95)
        love.graphics.printf("✦  S I N E S T E S I A   C O S M I C A  ✦", 0, 100, 1280, "center")

        love.graphics.setColor(0.6, 0.35, 1.0, 0.25)
        love.graphics.setLineWidth(1.5)
        love.graphics.line(640, 130, 640, 520)

        local start_y = 150
        local node_w, node_h = 560, 64
        local node_x = 640 - (node_w / 2)

        for i, item in ipairs(menuItems) do
            local off_x = ThemeManager.menu_offsets[i] or 0
            local cy = start_y + (i - 1) * 88
            local is_sel = (i == menuSelection)

            if is_sel then
                love.graphics.setBlendMode("add")
                love.graphics.setColor(0.6, 0.35, 1.0, 0.35 + pulse * 0.25)
                love.graphics.circle("fill", 640 + off_x, cy + node_h/2, 45 + pulse * 15)
                love.graphics.setBlendMode("alpha")

                love.graphics.setColor(0.03, 0.02, 0.08, 0.94)
                love.graphics.rectangle("fill", node_x + off_x, cy, node_w, node_h, 8)
                love.graphics.setColor(1.0, 0.85, 0.25, 0.95)
                love.graphics.setLineWidth(2.0)
                love.graphics.rectangle("line", node_x + off_x, cy, node_w, node_h, 8)

                love.graphics.setColor(1.0, 0.85, 0.25, 0.95)
                love.graphics.polygon("fill", node_x + off_x + 35, cy + 22, node_x + off_x + 41, cy + 32, node_x + off_x + 35, cy + 42, node_x + off_x + 29, cy + 32)
                love.graphics.polygon("fill", node_x + off_x + node_w - 35, cy + 22, node_x + off_x + node_w - 29, cy + 32, node_x + off_x + node_w - 35, cy + 42, node_x + off_x + node_w - 41, cy + 32)

                love.graphics.setFont(FontCache.get(16))
                love.graphics.setColor(1, 1, 1, 1.0)
                love.graphics.printf(item, node_x + off_x, cy + 12, node_w, "center")

                love.graphics.setFont(FontCache.get(9))
                love.graphics.setColor(0.1, 0.9, 1.0, 0.95)
                love.graphics.printf(menuSubtitles[i] or "", node_x + off_x, cy + 36, node_w, "center")
            else
                love.graphics.setColor(0.01, 0.01, 0.04, 0.80)
                love.graphics.rectangle("fill", node_x, cy, node_w, node_h, 8)
                love.graphics.setColor(0.6, 0.35, 1.0, 0.35)
                love.graphics.setLineWidth(1.0)
                love.graphics.rectangle("line", node_x, cy, node_w, node_h, 8)

                love.graphics.setFont(FontCache.get(15))
                love.graphics.setColor(0.75, 0.70, 0.85, 0.85)
                love.graphics.printf(item, node_x, cy + 12, node_w, "center")

                love.graphics.setFont(FontCache.get(9))
                love.graphics.setColor(0.5, 0.45, 0.65, 0.6)
                love.graphics.printf(menuSubtitles[i] or "", node_x, cy + 36, node_w, "center")
            end
        end

        love.graphics.setFont(FontCache.get(10))
        love.graphics.setColor(0.6, 0.35, 1.0, 0.9)
        love.graphics.printf("[ ARCHON COSMIC HARMONY LOCKED ]", 0, 525, 1280, "center")
    end

    love.graphics.setFont(FontCache.get(9))
    love.graphics.setColor(1, 1, 1, 0.50)
    love.graphics.printf("[ UP / DOWN ] NAVEGAR   |   [ ENTER ] SELECCIONAR   |   [ F5 ] CAMBIAR SKIN   |   [ F9 ] REC   |   [ F12 ] CAPTURA", 0, 620, 1280, "center")

    love.graphics.pop()
end

function ThemeManager.drawToast()
    if ThemeManager.toast_timer <= 0 then return end

    local progress = ThemeManager.toast_timer / 2.2
    local alpha = math.min(1.0, progress * 2.5)
    local t = ThemeManager.getCurrent()

    love.graphics.push("all")
    local bx, by, bw, bh = 850, 655, 410, 44

    love.graphics.setColor(0.02, 0.03, 0.06, 0.95 * alpha)
    love.graphics.rectangle("fill", bx, by, bw, bh, 4)

    love.graphics.setLineWidth(1.5)
    love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.90 * alpha)
    love.graphics.rectangle("line", bx, by, bw, bh, 4)

    love.graphics.setFont(FontCache.get(9))
    love.graphics.setColor(t.secondary[1], t.secondary[2], t.secondary[3], 0.90 * alpha)
    love.graphics.print("THEME SWITCHER [F5] ACTIVE SKIN:", bx + 12, by + 6)

    love.graphics.setFont(FontCache.get(11))
    love.graphics.setColor(1, 1, 1, 0.98 * alpha)
    love.graphics.print(ThemeManager.toast_text, bx + 12, by + 21)

    love.graphics.pop()
end

return ThemeManager
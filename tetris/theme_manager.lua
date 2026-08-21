-- ============================================================================
-- MUTRIS ENGINE: DYNAMIC THEME & SKIN SWITCHER ENGINE (1280x720 WIDESCREEN)
-- Arquitectura: Zero-GC / 4 Universos Visuales Únicos / Switch al Vuelo [F5]
-- ============================================================================
local ThemeManager = {}

local FontCache       = require "tetris.font_cache"
local SettingsManager = require "settings_manager"
local Blackbox        = require "core.blackbox"

ThemeManager.SKINS = {
    CYBER_DAW     = 1, -- 01 // CYBER-DAW HARDWARE RACK
    NEO_KINETIC   = 2, -- 02 // NEO-KINETIC STRIKE (Fighter/Persona Style)
    ESPORTS_GLASS = 3, -- 03 // HYPER-CLEAN ESPORTS GLASSMORPHISM
    COSMIC_VOID   = 4  -- 04 // SINESTESIA COSMICA / PRISMATIC VOID
}

ThemeManager.current_theme = 1
ThemeManager.toast_timer = 0.0
ThemeManager.toast_text = ""

-- ============================================================================
-- 📦 BUFFERS ESTÁTICOS ZERO-GC PARA EFECTOS PROCEDURALES
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

    Blackbox.log("THEME", "SWITCHED TO: " .. t.id, idx, 0)
end

function ThemeManager.cycleNext()
    ThemeManager.setTheme(ThemeManager.current_theme + 1)
end

function ThemeManager.cyclePrev()
    ThemeManager.setTheme(ThemeManager.current_theme - 1)
end

function ThemeManager.update(dt)
    if ThemeManager.toast_timer > 0 then
        ThemeManager.toast_timer = math.max(0, ThemeManager.toast_timer - dt)
    end

    local energy = _G.TrackEnergyPunch or 0
    local pulse  = _G.AudioBeatPulse or 0

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
-- 🖌️ FONDOS AMBIENTALES POR TEMA (Zero-GC)
-- ============================================================================
function ThemeManager.drawBackground()
    local t = ThemeManager.getCurrent()
    local energy = _G.TrackEnergyPunch or 0
    local pulse  = _G.AudioBeatPulse or 0
    local time   = love.timer.getTime()

    love.graphics.push("all")

    -- 1. CYBER-DAW: Grilla de Precisión
    if ThemeManager.current_theme == 1 then
        love.graphics.setColor(0, 0.8, 0.4, 0.04 + energy * 0.03)
        for x = 0, 1280, 40 do love.graphics.line(x, 0, x, 720) end
        for y = 0, 720, 40  do love.graphics.line(0, y, 1280, y) end

    -- 2. NEO-KINETIC: Rayas Diagonales 12° y Trama de Semitonos
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

    -- 3. ESPORTS GLASS: Líneas Láser Horizontales
    elseif ThemeManager.current_theme == 3 then
        love.graphics.setColor(0, 0.9, 1.0, 0.03 + pulse * 0.02)
        for x = 0, 1280, 80 do love.graphics.line(x, 0, x, 720) end
        for y = 0, 720, 80  do love.graphics.line(0, y, 1280, y) end

    -- 4. SINESTESIA CÓSMICA: Polvo Estelar y Anillos de Resonancia
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

-- ============================================================================
-- 📦 RENDERIZADO GENÉRICO DE PANELES (Para Settings, Pausa y HUD)
-- ============================================================================
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

-- ============================================================================
-- 🏛️ RENDERIZADOR DE MENÚ PRINCIPAL DIVERGENTE (4 ESTRUCTURAS ÚNICAS)
-- ============================================================================
function ThemeManager.drawMenu(menuItems, menuSubtitles, menuSelection, MetaBalancer)
    local t = ThemeManager.getCurrent()
    local pulse = _G.AudioBeatPulse or 0
    local energy = _G.TrackEnergyPunch or 0
    local time = love.timer.getTime()

    love.graphics.push("all")

    -- ────────────────────────────────────────────────────────────────────────
    -- ESTRUCTURA 1: CYBER-DAW HARDWARE RACK (Faders + Vúmetros LED + Osciloscopio)
    -- ────────────────────────────────────────────────────────────────────────
    if ThemeManager.current_theme == 1 then
        -- Encabezado Consola
        love.graphics.setFont(FontCache.get(28))
        love.graphics.setColor(1, 1, 1, 0.98)
        love.graphics.print("MUTRIS // DIGITAL AUDIO WORKSTATION", 80, 50)
        love.graphics.setFont(FontCache.get(10))
        love.graphics.setColor(0, 1, 0.55, 0.9)
        love.graphics.print("MASTER SYNTHESIZER CONSOLE  |  CAMELOT MODAL ENGINE  |  144/240Hz ZERO-GC", 80, 88)

        -- Ala Izquierda: 4 Faders de Canal con Vúmetros
        local start_x, start_y = 80, 130
        local fader_w, fader_h = 580, 78

        for i, item in ipairs(menuItems) do
            local fy = start_y + (i - 1) * 92
            local is_sel = (i == menuSelection)

            love.graphics.setColor(0.02, 0.04, 0.08, 0.92)
            love.graphics.rectangle("fill", start_x, fy, fader_w, fader_h, 3)
            love.graphics.setColor(is_sel and {0, 1, 0.55, 0.95} or {0, 0.6, 0.4, 0.35})
            love.graphics.setLineWidth(is_sel and 2.0 or 1.0)
            love.graphics.rectangle("line", start_x, fy, fader_w, fader_h, 3)

            -- Badge de Canal
            love.graphics.setColor(0.04, 0.08, 0.15, 0.9)
            love.graphics.rectangle("fill", start_x + 10, fy + 12, 64, 22, 2)
            love.graphics.setFont(FontCache.get(9))
            love.graphics.setColor(0, 1, 0.55, 0.9)
            love.graphics.printf(string.format("CH.0%d", i), start_x + 10, fy + 17, 64, "center")

            -- Título y Subtítulo
            love.graphics.setFont(FontCache.get(15))
            love.graphics.setColor(is_sel and {1, 1, 1, 1} or {0.7, 0.8, 0.9, 0.8})
            love.graphics.print(item, start_x + 85, fy + 14)

            love.graphics.setFont(FontCache.get(9))
            love.graphics.setColor(0.4, 0.8, 0.7, is_sel and 0.9 or 0.5)
            love.graphics.print(menuSubtitles[i] or "", start_x + 85, fy + 42)

            -- LED VU-Meter de 8 segmentos
            local vu_val = vu_meters[i] or 0.2
            for seg = 1, 8 do
                local seg_x = start_x + fader_w - 90 + (seg - 1) * 9
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

        -- Ala Derecha: Pantalla de Osciloscopio CRT
        local osc_x, osc_y, osc_w, osc_h = 700, 130, 500, 240
        love.graphics.setColor(0.01, 0.03, 0.06, 0.95)
        love.graphics.rectangle("fill", osc_x, osc_y, osc_w, osc_h, 4)
        love.graphics.setColor(0, 0.8, 0.4, 0.6)
        love.graphics.rectangle("line", osc_x, osc_y, osc_w, osc_h, 4)

        love.graphics.setFont(FontCache.get(10))
        love.graphics.setColor(0, 1, 0.55, 0.9)
        love.graphics.print("LIVE CRT OSCILLOSCOPE MONITOR", osc_x + 16, osc_y + 12)

        -- Traza Senoidal Viva
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

        -- Tarjeta Inferior ARCHON
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

    -- ────────────────────────────────────────────────────────────────────────
    -- ESTRUCTURA 2: NEO-KINETIC STRIKE (Cortes Diagonales 12° + Action Comic)
    -- ────────────────────────────────────────────────────────────────────────
    elseif ThemeManager.current_theme == 2 then
        love.graphics.setFont(FontCache.get(44))
        love.graphics.setColor(1, 0.08, 0.25, 0.98)
        love.graphics.print("MUTRIS", 100, 42)
        love.graphics.setFont(FontCache.get(14))
        love.graphics.setColor(1, 0.85, 0.0, 0.95)
        love.graphics.print("/// SYNTHETIC TRANSCENDENCE /// [ OVERDRIVE ]", 100, 94)

        -- Ala Izquierda: Cintas Trapezoidales Diagonales
        local start_y = 145
        local ribbon_w, ribbon_h = 620, 68

        for i, item in ipairs(menuItems) do
            local ry = start_y + (i - 1) * 88
            local is_sel = (i == menuSelection)
            local slant = 35

            if is_sel then
                -- Cinta seleccionada roja y blanca
                love.graphics.setColor(1.0, 0.08, 0.25, 0.95)
                love.graphics.polygon("fill", 100 + slant, ry, 100 + ribbon_w + slant, ry, 100 + ribbon_w, ry + ribbon_h, 100, ry + ribbon_h)

                love.graphics.setColor(1, 0.85, 0, 1.0)
                love.graphics.polygon("fill", 100, ry, 100 + 18, ry, 100 + 18 - slant, ry + ribbon_h, 100 - slant, ry + ribbon_h)

                love.graphics.setFont(FontCache.get(18))
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.print(string.format("/// 0%d.  %s", i, item), 130, ry + 12)

                love.graphics.setFont(FontCache.get(9))
                love.graphics.setColor(1, 0.9, 0.3, 0.95)
                love.graphics.print(menuSubtitles[i] or "", 130, ry + 40)
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

        -- Ala Derecha: Tarjeta de Acción / Stance Status
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

    -- ────────────────────────────────────────────────────────────────────────
    -- ESTRUCTURA 3: HYPER-CLEAN ESPORTS GLASS (Dashboard de Torneo 2 Columnas)
    -- ────────────────────────────────────────────────────────────────────────
    elseif ThemeManager.current_theme == 3 then
        -- Barra Superior Limpia
        love.graphics.setFont(FontCache.get(20))
        love.graphics.setColor(0.0, 0.9, 1.0, 0.98)
        love.graphics.print("MUTRIS ESPORTS", 100, 48)
        love.graphics.setFont(FontCache.get(10))
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.print("PRECISION GLASSMORPHISM // MATCH ARENA", 280, 55)

        -- Columna 1: Tarjetas de Modo
        local start_y = 115
        local card_w, card_h = 520, 95

        for i, item in ipairs(menuItems) do
            local cy = start_y + (i - 1) * 110
            local is_sel = (i == menuSelection)

            love.graphics.setColor(0.02, 0.03, 0.07, 0.85)
            love.graphics.rectangle("fill", 100, cy, card_w, card_h, 6)
            love.graphics.setLineWidth(is_sel and 1.8 or 1.0)
            love.graphics.setColor(is_sel and {0, 0.9, 1.0, 0.95} or {0, 0.6, 0.8, 0.3})
            love.graphics.rectangle("line", 100, cy, card_w, card_h, 6)

            -- Badge de Estado
            love.graphics.setColor(is_sel and {0, 0.9, 1.0, 0.25} or {0.1, 0.15, 0.25, 0.4})
            love.graphics.rectangle("fill", 100 + card_w - 110, cy + 16, 95, 22, 10)
            love.graphics.setFont(FontCache.get(8))
            love.graphics.setColor(is_sel and {0, 0.95, 1.0, 1.0} or {0.5, 0.6, 0.7, 0.7})
            love.graphics.printf(is_sel and "ENGAGE [A]" or "READY", 100 + card_w - 110, cy + 22, 95, "center")

            love.graphics.setFont(FontCache.get(16))
            love.graphics.setColor(is_sel and {1, 1, 1, 1} or {0.7, 0.8, 0.9, 0.85})
            love.graphics.print(item, 125, cy + 18)

            love.graphics.setFont(FontCache.get(9))
            love.graphics.setColor(0.0, 0.9, 1.0, is_sel and 0.9 or 0.5)
            love.graphics.print(menuSubtitles[i] or "", 125, cy + 50)
        end

        -- Columna 2: Player Passport y ARCHON Monitor
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

        -- ARCHON Monitor
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

    -- ────────────────────────────────────────────────────────────────────────
    -- ESTRUCTURA 4: SINESTESIA CÓSMICA (Constelaciones + Diamantes Flotantes)
    -- ────────────────────────────────────────────────────────────────────────
    elseif ThemeManager.current_theme == 4 then
        love.graphics.setFont(FontCache.get(34))
        love.graphics.setColor(1, 1, 1, 0.98)
        love.graphics.printf("MUTRIS", 0, 55, 1280, "center")
        love.graphics.setFont(FontCache.get(12))
        love.graphics.setColor(0.6, 0.35, 1.0, 0.95)
        love.graphics.printf("✦  S I N E S T E S I A   C O S M I C A  ✦", 0, 100, 1280, "center")

        -- Línea vertical de constelación central
        love.graphics.setColor(0.6, 0.35, 1.0, 0.25)
        love.graphics.setLineWidth(1.5)
        love.graphics.line(640, 130, 640, 520)

        local start_y = 150
        local node_w, node_h = 560, 64
        local node_x = 640 - (node_w / 2)

        for i, item in ipairs(menuItems) do
            local cy = start_y + (i - 1) * 88
            local is_sel = (i == menuSelection)

            if is_sel then
                love.graphics.setBlendMode("add")
                love.graphics.setColor(0.6, 0.35, 1.0, 0.35 + pulse * 0.25)
                love.graphics.circle("fill", 640, cy + node_h/2, 45 + pulse * 15)
                love.graphics.setBlendMode("alpha")

                love.graphics.setColor(0.03, 0.02, 0.08, 0.94)
                love.graphics.rectangle("fill", node_x, cy, node_w, node_h, 8)
                love.graphics.setColor(1.0, 0.85, 0.25, 0.95)
                love.graphics.setLineWidth(2.0)
                love.graphics.rectangle("line", node_x, cy, node_w, node_h, 8)

                love.graphics.setFont(FontCache.get(16))
                love.graphics.setColor(1, 1, 1, 1.0)
                love.graphics.printf("◇  " .. item .. "  ◇", node_x, cy + 12, node_w, "center")

                love.graphics.setFont(FontCache.get(9))
                love.graphics.setColor(0.1, 0.9, 1.0, 0.95)
                love.graphics.printf(menuSubtitles[i] or "", node_x, cy + 36, node_w, "center")
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

    -- Controles y Ayuda
    love.graphics.setFont(FontCache.get(9))
    love.graphics.setColor(1, 1, 1, 0.50)
    love.graphics.printf("[ UP / DOWN ] NAVEGAR   |   [ ENTER ] SELECCIONAR   |   [ F5 ] CAMBIAR SKIN   |   [ F9 ] REC   |   [ F12 ] CAPTURA", 0, 620, 1280, "center")

    love.graphics.pop()
end

-- ============================================================================
-- 🏷️ NOTIFICACIÓN TOAST DE CAMBIO DE SKIN
-- ============================================================================
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
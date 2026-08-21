-- ================================================================
-- FILE: tetris/game_states.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: MAIN MENU & CALIBRATION SUITE (1280x720 WIDESCREEN)
-- Conexión Directa con ThemeManager (4 Skins en Vivo [F5])
-- ============================================================================
local GameStates = {}

local FontCache       = require "tetris.font_cache"
local SettingsManager = require "settings_manager"
local AudioManager    = require "audio_manager"
local ThemeManager    = require "tetris.theme_manager"
local MetaBalancer    = require "core.meta_balancer"

GameStates.menu_selection = 1
GameStates.active_tab = 1
GameStates.selected_item = 1
GameStates.key_held_timer = 0
GameStates.key_repeat_timer = 0

local MENU_OPTIONS = {
    { title = "VS BOT DUEL",           desc = "CLASSIC 1v1 DUEL VS ADAPTIVE DDA BOT",   mode = "versus" },
    { title = "GAUNTLET RUSH",         desc = "ENDLESS SURVIVAL AGAINST FREQUENT ANOMALIES", mode = "gauntlet" },
    { title = "SOUNDTRACK & FX LAB",   desc = "DAW TIMELINE, CUE PLACEMENT & SFX AUDITION", mode = "editor" },
    { title = "SETTINGS & CALIBRATION",desc = "MASTER CALIBRATION SUITE, DAS / ARR & SKINS", mode = "settings" }
}

-- ============================================================================
-- 🏠 MENÚ PRINCIPAL MULTI-TEMA
-- ============================================================================
function GameStates.drawMenu()
    love.graphics.push("all")
    ThemeManager.drawBackground()

    local t = ThemeManager.getCurrent()
    local pulse = _G.AudioBeatPulse or 0
    local energy = _G.TrackEnergyPunch or 0
    local time = love.timer.getTime()

    -- Encabezado y Título
    love.graphics.setFont(FontCache.get(34))
    love.graphics.setColor(1, 1, 1, 0.98)
    love.graphics.printf("MUTRIS", 0, 75, 1280, "center")

    love.graphics.setFont(FontCache.get(12))
    love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.90 + pulse * 0.10)
    love.graphics.printf("SYNTHETIC TRANSCENDENCE", 0, 118, 1280, "center")

    -- Badge de motor
    love.graphics.setFont(FontCache.get(9))
    love.graphics.setColor(1, 1, 1, 0.50)
    love.graphics.printf("ZERO-GC ENGINE  |  144/240Hz TARGET  |  SINESTHETIC COMBAT", 0, 138, 1280, "center")

    -- ────────────────────────────────────────────────────────────────────────
    -- OPCIONES DEL MENÚ (Renderizadas según la geometría del Tema Activo)
    -- ────────────────────────────────────────────────────────────────────────
    local start_y = 190
    local btn_w, btn_h = 580, 68
    local btn_x = 640 - (btn_w / 2)

    for i, opt in ipairs(MENU_OPTIONS) do
        local cy = start_y + (i - 1) * 82
        local is_sel = (i == GameStates.menu_selection)

        -- Panel por Tema
        ThemeManager.drawPanel(btn_x, cy, btn_w, btn_h, "", is_sel)

        -- Indicador de selección lateral
        if is_sel then
            love.graphics.setColor(t.secondary[1], t.secondary[2], t.secondary[3], 0.95)
            love.graphics.rectangle("fill", btn_x + 6, cy + 12, 4, btn_h - 24, 2)
            love.graphics.rectangle("fill", btn_x + btn_w - 10, cy + 12, 4, btn_h - 24, 2)
        end

        -- Título del Botón
        love.graphics.setFont(FontCache.get(15))
        if is_sel then
            love.graphics.setColor(1, 1, 1, 1.0)
            love.graphics.printf("> " .. opt.title .. " <", btn_x, cy + 14, btn_w, "center")
        else
            love.graphics.setColor(0.65, 0.70, 0.80, 0.85)
            love.graphics.printf(opt.title, btn_x, cy + 14, btn_w, "center")
        end

        -- Descripción
        love.graphics.setFont(FontCache.get(9))
        love.graphics.setColor(t.secondary[1], t.secondary[2], t.secondary[3], is_sel and 0.85 or 0.45)
        love.graphics.printf(opt.desc, btn_x, cy + 38, btn_w, "center")
    end

    -- ────────────────────────────────────────────────────────────────────────
    -- BANNER ARCHON META-BALANCER (Pie de Menú)
    -- ────────────────────────────────────────────────────────────────────────
    local banner_y = 540
    local bw, bh = 640, 36
    local bx = 640 - (bw / 2)

    ThemeManager.drawPanel(bx, banner_y, bw, bh, "", false)
    love.graphics.setFont(FontCache.get(10))
    love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.95)
    local patch_text = string.format("[ ARCHON ] %s", MetaBalancer.patch_notes or "BASELINE BALANCE LOADED")
    love.graphics.printf(patch_text, bx, banner_y + 11, bw, "center")

    -- Controles inferiores
    love.graphics.setFont(FontCache.get(9))
    love.graphics.setColor(1, 1, 1, 0.50)
    love.graphics.printf("[ UP / DOWN ] NAVEGAR   |   [ ENTER ] SELECCIONAR   |   [ F5 ] CAMBIAR SKIN EN VIVO   |   [ F12 ] CAPTURA", 0, 615, 1280, "center")

    -- Directiva permanente obligatoria
    love.graphics.setFont(FontCache.get(9))
    love.graphics.setColor(0, 0.8, 1, 0.6)
    love.graphics.print(_G.ENGINE_VERSION or "MUTRIS v1.0.0", 15, 695)

    -- Toast de cambio de skin (si está activo)
    ThemeManager.drawToast()

    love.graphics.pop()
end

-- ============================================================================
-- ⌨️ ENTRADA DEL MENÚ PRINCIPAL
-- ============================================================================
function GameStates.menuKeypressed(key)
    if key == "up" then
        GameStates.menu_selection = GameStates.menu_selection - 1
        if GameStates.menu_selection < 1 then GameStates.menu_selection = #MENU_OPTIONS end
        AudioManager.playImmediateSFX("move", false)
    elseif key == "down" then
        GameStates.menu_selection = GameStates.menu_selection + 1
        if GameStates.menu_selection > #MENU_OPTIONS then GameStates.menu_selection = 1 end
        AudioManager.playImmediateSFX("move", false)
    elseif key == "return" or key == "space" then
        local opt = MENU_OPTIONS[GameStates.menu_selection]
        if opt then
            AudioManager.playImmediateSFX("rotate", false)
            if opt.mode == "versus" then
                _G.CURRENT_GAME_MODE = "versus"
                _G.SetGameState("playing")
            elseif opt.mode == "gauntlet" then
                _G.CURRENT_GAME_MODE = "gauntlet"
                _G.SetGameState("playing")
            elseif opt.mode == "editor" then
                _G.SetGameState("editor")
                local TrackEditor = require "track_editor"
                TrackEditor.active = true
            elseif opt.mode == "settings" then
                _G.SetGameState("settings")
            end
        end
    end
end

-- ============================================================================
-- ⚙️ PANTALLA DE AJUSTES & CALIBRACIÓN (Widescreen 1280x720)
-- ============================================================================
function GameStates.drawSettings()
    love.graphics.push("all")
    ThemeManager.drawBackground()

    local t = ThemeManager.getCurrent()
    local tabs = SettingsManager.tabs
    local cur_tab = tabs[GameStates.active_tab]

    -- Título de la Suite (Bajado a Y=55 para nunca chocar con banners)
    love.graphics.setFont(FontCache.get(22))
    love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.95)
    love.graphics.printf("MASTER CALIBRATION SUITE", 0, 48, 1280, "center")

    love.graphics.setFont(FontCache.get(10))
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.printf(cur_tab and cur_tab.title or "", 0, 78, 1280, "center")

    -- Pestañas superiores (6 Tabs centradas)
    local tab_w, tab_h = 160, 30
    local tab_start_x = 640 - (#tabs * (tab_w + 8)) / 2

    for i, tab in ipairs(tabs) do
        local tx = tab_start_x + (i - 1) * (tab_w + 8)
        local is_sel = (i == GameStates.active_tab)

        ThemeManager.drawPanel(tx, 105, tab_w, tab_h, "", is_sel)
        love.graphics.setFont(FontCache.get(9))
        love.graphics.setColor(is_sel and {1, 1, 1, 1} or {0.6, 0.65, 0.75, 0.7})
        love.graphics.printf(tab.name, tx, 114, tab_w, "center")
    end

    -- Contenedor Principal de Ajustes
    local panel_x, panel_y, panel_w, panel_h = 160, 148, 960, 470
    ThemeManager.drawPanel(panel_x, panel_y, panel_w, panel_h, "", false)

    -- Items de la Pestaña Activa
    if cur_tab and cur_tab.items then
        local item_y = panel_y + 25
        for i, item in ipairs(cur_tab.items) do
            local is_sel = (i == GameStates.selected_item)
            local val = SettingsManager.get(item.id)

            -- Resaltado de fila
            if is_sel then
                love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.12)
                love.graphics.rectangle("fill", panel_x + 10, item_y - 4, panel_w - 20, 38, 4)
                love.graphics.setColor(t.secondary[1], t.secondary[2], t.secondary[3], 0.9)
                love.graphics.rectangle("fill", panel_x + 10, item_y - 4, 3, 38)
            end

            -- Nombre del Parámetro
            love.graphics.setFont(FontCache.get(11))
            love.graphics.setColor(is_sel and {1, 1, 1, 1} or {0.7, 0.75, 0.85, 0.85})
            love.graphics.print(item.label, panel_x + 24, item_y + 7)

            -- Control Deslizante / Toggle / Enum
            local ctrl_x = panel_x + 380

            if item.is_toggle then
                local on = (val == 1 or val == true)
                love.graphics.setColor(on and {0, 0.8, 0.4, 0.9} or {0.2, 0.25, 0.3, 0.8})
                love.graphics.rectangle("fill", ctrl_x, item_y + 4, 70, 24, 3)
                love.graphics.setFont(FontCache.get(10))
                love.graphics.setColor(1, 1, 1)
                love.graphics.printf(on and "ON" or "OFF", ctrl_x, item_y + 9, 70, "center")

            elseif item.is_enum then
                local opt_idx = 1
                for idx, opt_val in ipairs(item.options) do
                    if opt_val == val then opt_idx = idx break end
                end
                local label_str = item.labels[opt_idx] or tostring(val)
                love.graphics.setColor(0.04, 0.06, 0.12, 0.9)
                love.graphics.rectangle("fill", ctrl_x, item_y + 4, 280, 24, 3)
                love.graphics.setColor(t.border)
                love.graphics.rectangle("line", ctrl_x, item_y + 4, 280, 24, 3)
                love.graphics.setFont(FontCache.get(9))
                love.graphics.setColor(t.primary)
                love.graphics.printf("<  " .. label_str .. "  >", ctrl_x, item_y + 9, 280, "center")

            else
                -- Slider Numérico
                local min_v = item.min or 0
                local max_v = item.max or 100
                local cur_v = val or min_v
                local frac = math.max(0, math.min(1, (cur_v - min_v) / (max_v - min_v)))
                local bar_w = 260

                love.graphics.setColor(0.05, 0.08, 0.14, 0.9)
                love.graphics.rectangle("fill", ctrl_x, item_y + 11, bar_w, 10, 2)
                love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.85)
                love.graphics.rectangle("fill", ctrl_x, item_y + 11, bar_w * frac, 10, 2)
                love.graphics.setColor(1, 1, 1, 0.95)
                love.graphics.rectangle("fill", ctrl_x + bar_w * frac - 3, item_y + 7, 6, 18, 1)

                -- Texto del Valor
                love.graphics.setFont(FontCache.get(10))
                love.graphics.setColor(1, 1, 1, 0.95)
                local val_str = item.is_ms and string.format("%d ms", math.floor(cur_v * 1000 + 0.5))
                             or item.is_pct and string.format("%d %%", math.floor(cur_v * 100 + 0.5))
                             or tostring(cur_v) .. " " .. (item.unit or "")
                love.graphics.print(val_str, ctrl_x + bar_w + 20, item_y + 7)
            end

            item_y = item_y + 44
        end
    end

    -- Botones Inferiores de Acción
    local btn_rst_x, btn_sav_x = panel_x + 20, panel_x + panel_w - 240
    local btn_y = panel_y + panel_h - 48

    love.graphics.setColor(0.3, 0.05, 0.08, 0.85)
    love.graphics.rectangle("fill", btn_rst_x, btn_y, 200, 32, 4)
    love.graphics.setColor(1, 0.3, 0.4, 0.5)
    love.graphics.rectangle("line", btn_rst_x, btn_y, 200, 32, 4)
    love.graphics.setFont(FontCache.get(9))
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("RESTABLECER PESTAÑA", btn_rst_x, btn_y + 10, 200, "center")

    love.graphics.setColor(0.04, 0.35, 0.15, 0.85)
    love.graphics.rectangle("fill", btn_sav_x, btn_y, 220, 32, 4)
    love.graphics.setColor(0, 0.9, 0.4, 0.5)
    love.graphics.rectangle("line", btn_sav_x, btn_y, 220, 32, 4)
    love.graphics.setFont(FontCache.get(9))
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("GUARDAR Y SALIR [ESC / ENTER]", btn_sav_x, btn_y + 10, 220, "center")

    -- Directiva Permanente
    love.graphics.setFont(FontCache.get(9))
    love.graphics.setColor(0, 0.8, 1, 0.6)
    love.graphics.print(_G.ENGINE_VERSION or "MUTRIS v1.0.0", 15, 695)

    -- Toast de cambio de skin (si está activo)
    ThemeManager.drawToast()

    love.graphics.pop()
end

-- ============================================================================
-- ⌨️ ENTRADA DE AJUSTES & CALIBRACIÓN
-- ============================================================================
function GameStates.settingsKeypressed(key)
    local tabs = SettingsManager.tabs
    local cur_tab = tabs[GameStates.active_tab]

    if key == "escape" then
        SettingsManager.save()
        _G.SetGameState("menu")
        return
    end

    if key == "q" then
        GameStates.active_tab = (GameStates.active_tab - 2 + #tabs) % #tabs + 1
        GameStates.selected_item = 1
        AudioManager.playImmediateSFX("move", false)
    elseif key == "e" or key == "tab" then
        GameStates.active_tab = (GameStates.active_tab % #tabs) + 1
        GameStates.selected_item = 1
        AudioManager.playImmediateSFX("move", false)
    elseif key == "up" then
        if cur_tab and cur_tab.items then
            GameStates.selected_item = (GameStates.selected_item - 2 + #cur_tab.items) % #cur_tab.items + 1
            AudioManager.playImmediateSFX("move", false)
        end
    elseif key == "down" then
        if cur_tab and cur_tab.items then
            GameStates.selected_item = (GameStates.selected_item % #cur_tab.items) + 1
            AudioManager.playImmediateSFX("move", false)
        end
    elseif key == "left" or key == "right" then
        if cur_tab and cur_tab.items then
            local item = cur_tab.items[GameStates.selected_item]
            if item then
                local val = SettingsManager.get(item.id)
                if item.is_toggle then
                    SettingsManager.settings[item.id] = (val == 1 or val == true) and 0 or 1
                elseif item.is_enum then
                    local cur_idx = 1
                    for idx, opt in ipairs(item.options) do
                        if opt == val then cur_idx = idx break end
                    end
                    if key == "left" then
                        cur_idx = (cur_idx - 2 + #item.options) % #item.options + 1
                    else
                        cur_idx = (cur_idx % #item.options) + 1
                    end
                    SettingsManager.settings[item.id] = item.options[cur_idx]
                    if item.id == "theme_skin" then
                        ThemeManager.setTheme(item.options[cur_idx])
                    end
                else
                    local step = item.step or 1
                    if key == "left" then
                        SettingsManager.settings[item.id] = math.max(item.min, val - step)
                    else
                        SettingsManager.settings[item.id] = math.min(item.max, val + step)
                    end
                end
                SettingsManager.save()
                AudioManager.playImmediateSFX("rotate", false)
            end
        end
    end
end

return GameStates
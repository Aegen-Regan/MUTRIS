-- ================================================================
-- FILE: scenes/scene_settings.lua
-- ================================================================
---@diagnostic disable: undefined-global
local SceneSettings = {}
local SettingsManager = require "settings_manager"
local ThemeManager = require "tetris.theme_manager"
local RulesetManager = require "core.ruleset_manager"
local AudioManager = require "audio_manager"
local MusicManager = require "music_manager"
local FontCache = require "tetris.font_cache"

SceneSettings.active_tab_index = 1
SceneSettings.active_item_index = 1
SceneSettings.return_state = "menu"
SceneSettings.awaiting_key = nil

function SceneSettings.adjustActiveSetting(delta)
    local tab = SettingsManager.tabs[SceneSettings.active_tab_index]
    if not tab then return end
    local item = tab.items[SceneSettings.active_item_index]
    if not item then return end

    local s = SettingsManager.settings
    local cur = s[item.id]

    if item.is_toggle then
        if item.id == "mute_all" then
            SettingsManager.toggleMute()
            AudioManager.playMuteToggle(s.mute_all and s.mute_all >= 0.5)
        else
            s[item.id] = (cur == 1 or cur == true) and 0 or 1
            AudioManager.playSliderTick()
        end

    elseif item.is_enum then
        local opt_idx = 1
        for idx, opt in ipairs(item.options) do
            if opt == cur then opt_idx = idx break end
        end
        opt_idx = ((opt_idx + delta - 1) % #item.options) + 1
        s[item.id] = item.options[opt_idx]
        
        if item.id == "theme_skin" then
            ThemeManager.setTheme(item.options[opt_idx])
        elseif item.id == "active_ruleset" then
            RulesetManager.setRuleset(item.options[opt_idx])
        elseif item.id == "control_preset" then
            local preset = item.options[opt_idx]
            if preset == 1 then -- ARROWS + A/D/S/C
                s.key_left = "left"
                s.key_right = "right"
                s.key_soft_drop = "down"
                s.key_hard_drop = "space"
                s.key_rot_cw = "d"
                s.key_rot_ccw = "a"
                s.key_rot_180 = "s"
                s.key_hold = "c"
                s.key_zone = "v"
                s.key_stance = "tab"
            elseif preset == 2 then -- GUIDELINE (Z/X/A/C)
                s.key_left = "left"
                s.key_right = "right"
                s.key_soft_drop = "down"
                s.key_hard_drop = "space"
                s.key_rot_cw = "x"
                s.key_rot_ccw = "z"
                s.key_rot_180 = "a"
                s.key_hold = "c"
                s.key_zone = "v"
                s.key_stance = "tab"
            elseif preset == 3 then -- WASD + NUMPAD
                s.key_left = "a"
                s.key_right = "d"
                s.key_soft_drop = "s"
                s.key_hard_drop = "w"
                s.key_rot_cw = "kp8"
                s.key_rot_ccw = "kp7"
                s.key_rot_180 = "kp5"
                s.key_hold = "kp0"
                s.key_zone = "v"
                s.key_stance = "tab"
            end
        end
        AudioManager.playSliderTick()

    elseif item.is_key then
        -- En mapeos de teclas, los presets son el switch principal
        AudioManager.playSliderTick()

    else
        local num_v = tonumber(cur) or 0
        if item.is_ms then num_v = num_v * 1000 end
        if item.is_pct then num_v = num_v * 100 end

        num_v = math.max(item.min, math.min(item.max, num_v + delta * item.step))

        if item.is_ms then s[item.id] = num_v / 1000.0
        elseif item.is_pct then s[item.id] = num_v / 100.0
        else s[item.id] = num_v end
        AudioManager.playSliderTick()
    end

    SettingsManager.save()
end

function SceneSettings.close()
    local SceneManager = require "core.scene_manager"
    SettingsManager.save()
    local target = SceneSettings.return_state or "menu"
    SceneManager.setState(target)
    if target == "pause" then
        MusicManager.pause()
    elseif target == "menu" then
        MusicManager.start()
    else
        MusicManager.resume()
    end
    AudioManager.playMenuBack()
end

function SceneSettings.draw()
    ThemeManager.drawBackground()
    local t = ThemeManager.getCurrent()

    love.graphics.setFont(FontCache.get(26))
    love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.95)
    love.graphics.printf("MASTER CALIBRATION SUITE", 0, 26, 1280, "center")

    local current_tab = SettingsManager.tabs[SceneSettings.active_tab_index]
    love.graphics.setFont(FontCache.get(11))
    love.graphics.setColor(0.5, 0.7, 0.9, 0.85)
    love.graphics.printf(current_tab.title or "SYSTEM TUNING", 0, 58, 1280, "center")

    local tab_count = #SettingsManager.tabs
    local total_available_w = 980
    local tab_gap = 6
    local tab_w = math.min(145, math.floor((total_available_w - (tab_count - 1) * tab_gap) / tab_count))
    local tab_h = 32
    local total_tabs_w = tab_count * (tab_w + tab_gap) - tab_gap
    local tabs_start_x = 640 - (total_tabs_w / 2)
    local tabs_y = 82

    for i, tab in ipairs(SettingsManager.tabs) do
        local tx = tabs_start_x + (i - 1) * (tab_w + tab_gap)
        local is_active_tab = (i == SceneSettings.active_tab_index)

        ThemeManager.drawPanel(tx, tabs_y, tab_w, tab_h, "", is_active_tab)

        love.graphics.setFont(FontCache.get(9))
        love.graphics.setColor(is_active_tab and {1,1,1,1} or {0.65, 0.75, 0.85, 0.75})
        love.graphics.printf(tab.name, tx, tabs_y + 9, tab_w, "center")
    end

    local card_x = 180
    local card_y = 126
    local card_w = 920
    local card_h = 450

    ThemeManager.drawPanel(card_x, card_y, card_w, card_h, "", false)

    local row_start_y = card_y + 16
    local row_spacing = 49
    local sel_h = 43
    local usable_h = card_h - 90
    if #current_tab.items * row_spacing > usable_h then
        row_spacing = usable_h / #current_tab.items
        sel_h = row_spacing - 4
    end

    for i, item in ipairs(current_tab.items) do
        local is_sel = (i == SceneSettings.active_item_index)
        local ry = row_start_y + (i - 1) * row_spacing

        if is_sel then
            love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.15)
            love.graphics.rectangle("fill", card_x + 12, ry - 4, card_w - 24, sel_h, 4)
            love.graphics.setLineWidth(1.2)
            love.graphics.setColor(t.secondary[1], t.secondary[2], t.secondary[3], 0.85)
            love.graphics.rectangle("line", card_x + 12, ry - 4, card_w - 24, sel_h, 4)
        end

        local text_y = ry + math.floor((row_spacing - 12) / 2)
        love.graphics.setFont(FontCache.get(11))
        love.graphics.setColor(is_sel and {1.0, 1.0, 1.0, 1.0} or {0.75, 0.85, 0.95, 0.85})
        love.graphics.print(item.label, card_x + 28, text_y)

        local slider_x = card_x + 360
        local slider_h = 16
        local slider_y = ry + math.floor((row_spacing - slider_h) / 2)
        local slider_w = 260

        local cur_val = SettingsManager.get(item.id)
        local def_val = SettingsManager.defaults[item.id]

        if item.is_toggle then
            local is_on = (cur_val and (cur_val == 1 or cur_val == true or (type(cur_val) == "number" and cur_val >= 0.5)))
            love.graphics.setColor(is_on and {0.1, 0.85, 0.45, 0.85} or {0.8, 0.15, 0.25, 0.85})
            love.graphics.rectangle("fill", slider_x, slider_y - 2, 80, 20, 3)
            love.graphics.setFont(FontCache.get(10))
            love.graphics.setColor(1, 1, 1, 0.95)
            love.graphics.printf(is_on and "ON" or "OFF", slider_x, slider_y + 2, 80, "center")

        elseif item.is_enum then
            local opt_idx = 1
            for idx, opt in ipairs(item.options) do
                if opt == cur_val then opt_idx = idx break end
            end
            local label_text = item.labels[opt_idx] or tostring(cur_val)
            love.graphics.setColor(0.0, 0.35, 0.55, 0.75)
            love.graphics.rectangle("fill", slider_x, slider_y - 2, 220, 22, 3)
            love.graphics.setColor(t.border)
            love.graphics.rectangle("line", slider_x, slider_y - 2, 220, 22, 3)
            love.graphics.setFont(FontCache.get(10))
            love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
            love.graphics.printf("< " .. label_text .. " >", slider_x, slider_y + 3, 220, "center")

        elseif item.is_key or type(cur_val) == "string" then
            love.graphics.setColor(0.02, 0.12, 0.22, 0.85)
            love.graphics.rectangle("fill", slider_x, slider_y - 2, 170, 22, 3)
            love.graphics.setColor(t.border)
            love.graphics.rectangle("line", slider_x, slider_y - 2, 170, 22, 3)
            love.graphics.setFont(FontCache.get(10))
            
            if SceneSettings.awaiting_key == item.id then
                love.graphics.setColor(1.0, 0.8, 0.2, 0.95)
                love.graphics.printf("[ PRESIONA TECLA ]", slider_x, slider_y + 3, 170, "center")
            else
                love.graphics.setColor(0.2, 0.95, 0.7, 0.95)
                love.graphics.printf("[ TECLA: " .. tostring(cur_val):upper() .. " ]", slider_x, slider_y + 3, 170, "center")
            end

        else
            love.graphics.setColor(0.02, 0.04, 0.08, 0.9)
            love.graphics.rectangle("fill", slider_x, slider_y, slider_w, slider_h, 3)
            love.graphics.setColor(t.border)
            love.graphics.rectangle("line", slider_x, slider_y, slider_w, slider_h, 3)

            local num_v = tonumber(cur_val) or 0
            if item.is_ms then num_v = num_v * 1000 end
            if item.is_pct then num_v = num_v * 100 end

            local pct = (num_v - item.min) / math.max(0.001, (item.max - item.min))
            pct = math.max(0, math.min(1, pct))

            love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.85)
            love.graphics.rectangle("fill", slider_x + 2, slider_y + 2, (slider_w - 4) * pct, slider_h - 4, 2)

            love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
            love.graphics.rectangle("fill", slider_x + (slider_w - 4) * pct - 2, slider_y - 2, 5, slider_h + 4, 1)

            love.graphics.setFont(FontCache.get(10))
            love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
            local val_str = item.is_pct and string.format("%d%%", math.floor(num_v + 0.5))
                         or (item.is_ms and string.format("%d ms", math.floor(num_v + 0.5))
                         or (item.is_int and string.format("%d %s", math.floor(num_v + 0.5), item.unit or "")
                         or string.format("%.2f %s", num_v, item.unit or "")))
            love.graphics.print(val_str, slider_x + slider_w + 14, slider_y)
        end

        local reset_btn_x = card_x + card_w - 120
        local reset_btn_y = ry + math.floor((row_spacing - 22) / 2)
        love.graphics.setColor(0.03, 0.06, 0.12, 0.85)
        love.graphics.rectangle("fill", reset_btn_x, reset_btn_y, 44, 22, 3)
        love.graphics.setColor(t.border)
        love.graphics.rectangle("line", reset_btn_x, reset_btn_y, 44, 22, 3)
        love.graphics.setFont(FontCache.get(9))
        love.graphics.setColor(t.primary)
        love.graphics.printf("RST", reset_btn_x, reset_btn_y + 4, 44, "center")

        if not item.is_key then
            love.graphics.setFont(FontCache.get(8))
            love.graphics.setColor(0.45, 0.55, 0.65, 0.75)
            local def_str = item.is_ms and string.format("%dms", def_val * 1000)
                         or (item.is_pct and string.format("%d%%", def_val * 100)
                         or (item.is_int and string.format("%d", def_val)
                         or tostring(def_val)))
            love.graphics.print("BASE: " .. def_str, reset_btn_x + 52, reset_btn_y + 5)
        end
    end

    if current_tab.id == "handling" then
        local das_ms = (SettingsManager.get("das") or 0.094) * 1000
        local arr_ms = (SettingsManager.get("arr") or 0.008) * 1000
        local f60_das = das_ms / (1000 / 60)
        local f144_das = das_ms / (1000 / 144)
        local f240_das = das_ms / (1000 / 240)

        love.graphics.setColor(0.0, 0.05, 0.1, 0.88)
        love.graphics.rectangle("fill", card_x + 12, card_y + card_h - 68, card_w - 24, 24, 3)
        love.graphics.setFont(FontCache.get(9))
        love.graphics.setColor(0.2, 0.95, 0.6, 0.9)
        local telemetry_line = string.format(
            "FRAME-DATA LIVE MONITOR: DAS %.0fms = %.1ff @ 60Hz | %.1ff @ 144Hz | %.1ff @ 240Hz   --   ARR %.1fms",
            das_ms, f60_das, f144_das, f240_das, arr_ms
        )
        love.graphics.printf(telemetry_line, card_x + 12, card_y + card_h - 62, card_w - 24, "center")
    elseif current_tab.id == "controls" then
        love.graphics.setColor(0.0, 0.05, 0.1, 0.88)
        love.graphics.rectangle("fill", card_x + 12, card_y + card_h - 68, card_w - 24, 24, 3)
        love.graphics.setFont(FontCache.get(9))
        love.graphics.setColor(0.2, 0.95, 0.6, 0.9)
        local controls_line = "MAPEO UNIVERSAL: Usa ENTER para reasignar cualquier tecla a tu gusto. Evita solapar teclas."
        love.graphics.printf(controls_line, card_x + 12, card_y + card_h - 62, card_w - 24, "center")
    end

    local btn_reset_w = 200
    local btn_reset_h = 32
    local btn_reset_x = card_x + 20
    local btn_reset_y = card_y + card_h - 38

    love.graphics.setColor(0.25, 0.05, 0.08, 0.8)
    love.graphics.rectangle("fill", btn_reset_x, btn_reset_y, btn_reset_w, btn_reset_h, 4)
    love.graphics.setColor(1.0, 0.2, 0.3, 0.5)
    love.graphics.rectangle("line", btn_reset_x, btn_reset_y, btn_reset_w, btn_reset_h, 4)
    love.graphics.setFont(FontCache.get(10))
    love.graphics.setColor(1.0, 0.4, 0.5, 0.95)
    love.graphics.printf("RESTABLECER PESTANA", btn_reset_x, btn_reset_y + 8, btn_reset_w, "center")

    local btn_save_w = 260
    local btn_save_h = 32
    local btn_save_x = card_x + card_w - btn_save_w - 20
    local btn_save_y = card_y + card_h - 38

    love.graphics.setColor(0.0, 0.45, 0.25, 0.85)
    love.graphics.rectangle("fill", btn_save_x, btn_save_y, btn_save_w, btn_save_h, 4)
    love.graphics.setColor(0.1, 1.0, 0.5, 0.7)
    love.graphics.rectangle("line", btn_save_x, btn_save_y, btn_save_w, btn_save_h, 4)
    love.graphics.setFont(FontCache.get(11))
    love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
    love.graphics.printf("GUARDAR Y SALIR [ESC / ENTER]", btn_save_x, btn_save_y + 7, btn_save_w, "center")

    love.graphics.setFont(FontCache.get(9))
    love.graphics.setColor(0.45, 0.55, 0.65, 0.75)
    love.graphics.printf("[ Q / E ] CAMBIAR PESTANA  |  [ FLECHAS ] AJUSTAR  |  [ BACKSPACE / DEL ] RESET INDIVIDUAL  |  [ ESC ] REGRESAR", 0, 595, 1280, "center")
end

function SceneSettings.keypressed(key)
    if SceneSettings.awaiting_key then
        if key == "escape" then
            SceneSettings.awaiting_key = nil
            AudioManager.playMenuBack()
            return true
        end
        SettingsManager.settings[SceneSettings.awaiting_key] = key
        SettingsManager.save()
        SceneSettings.awaiting_key = nil
        AudioManager.playSliderTick()
        return true
    end

    local current_tab = SettingsManager.tabs[SceneSettings.active_tab_index]

    if key == "q" then
        SceneSettings.active_tab_index = (SceneSettings.active_tab_index == 1) and #SettingsManager.tabs or (SceneSettings.active_tab_index - 1)
        SceneSettings.active_item_index = 1
        AudioManager.playMenuHover()
        return true
    elseif key == "e" or key == "tab" then
        SceneSettings.active_tab_index = (SceneSettings.active_tab_index % #SettingsManager.tabs) + 1
        SceneSettings.active_item_index = 1
        AudioManager.playMenuHover()
        return true
    elseif key == "up" then
        SceneSettings.active_item_index = (SceneSettings.active_item_index == 1) and #current_tab.items or (SceneSettings.active_item_index - 1)
        AudioManager.playMenuHover()
        return true
    elseif key == "down" then
        SceneSettings.active_item_index = (SceneSettings.active_item_index % #current_tab.items) + 1
        AudioManager.playMenuHover()
        return true
    elseif key == "left" then
        SceneSettings.adjustActiveSetting(-1)
        return true
    elseif key == "right" then
        SceneSettings.adjustActiveSetting(1)
        return true
    elseif key == "backspace" or key == "delete" then
        local item = current_tab.items[SceneSettings.active_item_index]
        if item then
            SettingsManager.resetKey(item.id)
            if item.id == "theme_skin" then
                ThemeManager.setTheme(SettingsManager.get("theme_skin"))
            elseif item.id == "active_ruleset" then
                RulesetManager.setRuleset(SettingsManager.get("active_ruleset"))
            end
            AudioManager.playImmediateSFX("rotate", false)
        end
        return true
    elseif key == "return" or key == "space" then
        local item = current_tab.items[SceneSettings.active_item_index]
        if item and (item.is_toggle or item.is_enum) then
            SceneSettings.adjustActiveSetting(1)
        elseif item and (item.is_key or type(SettingsManager.get(item.id)) == "string") then
            SceneSettings.awaiting_key = item.id
            AudioManager.playMenuHover()
        else
            SceneSettings.close()
        end
        return true
    elseif key == "escape" then
        SceneSettings.close()
        return true
    end
    return false
end

function SceneSettings.mousepressed(adj_x, adj_y, button)
    if button ~= 1 then return false end

    local tab_w = 172
    local tab_h = 32
    local total_tabs_w = #SettingsManager.tabs * (tab_w + 8) - 8
    local tabs_start_x = 640 - (total_tabs_w / 2)
    local tabs_y = 82

    for i = 1, #SettingsManager.tabs do
        local tx = tabs_start_x + (i - 1) * (tab_w + 8)
        if adj_x >= tx and adj_x <= tx + tab_w and adj_y >= tabs_y and adj_y <= tabs_y + tab_h then
            SceneSettings.active_tab_index = i
            SceneSettings.active_item_index = 1
            AudioManager.playMenuHover()
            return true
        end
    end

    local card_x = 180
    local card_y = 126
    local card_w = 920
    local card_h = 450
    local row_start_y = card_y + 16
    local current_tab = SettingsManager.tabs[SceneSettings.active_tab_index]
    local usable_h = card_h - 90
    local row_spacing = 49
    if #current_tab.items * row_spacing > usable_h then
        row_spacing = usable_h / #current_tab.items
    end

    for i, item in ipairs(current_tab.items) do
        local ry = row_start_y + (i - 1) * row_spacing
        local slider_x = card_x + 360
        local slider_y = ry + 8
        local slider_w = 260
        local slider_h = 16
        local reset_btn_x = card_x + card_w - 120

        if adj_x >= reset_btn_x and adj_x <= reset_btn_x + 44 and adj_y >= ry + 4 and adj_y <= ry + 26 then
            SceneSettings.active_item_index = i
            SettingsManager.resetKey(item.id)
            if item.id == "theme_skin" then
                ThemeManager.setTheme(SettingsManager.get("theme_skin"))
            elseif item.id == "active_ruleset" then
                RulesetManager.setRuleset(SettingsManager.get("active_ruleset"))
            end
            AudioManager.playImmediateSFX("rotate", false)
            return true
        end

        if item.is_toggle then
            if adj_x >= slider_x and adj_x <= slider_x + 80 and adj_y >= slider_y - 2 and adj_y <= slider_y + 18 then
                SceneSettings.active_item_index = i
                SceneSettings.adjustActiveSetting(1)
                return true
            end
        elseif item.is_enum then
            if adj_x >= slider_x and adj_x <= slider_x + 220 and adj_y >= slider_y - 2 and adj_y <= slider_y + 20 then
                SceneSettings.active_item_index = i
                SceneSettings.adjustActiveSetting(1)
                return true
            end
        elseif item.is_key or type(SettingsManager.get(item.id)) == "string" then
            -- Mapeos de teclas (ahora entra en modo rebind)
            if adj_x >= slider_x and adj_x <= slider_x + 170 and adj_y >= slider_y - 2 and adj_y <= slider_y + 20 then
                SceneSettings.active_item_index = i
                SceneSettings.awaiting_key = item.id
                AudioManager.playMenuHover()
                return true
            end
        else
            if adj_x >= slider_x and adj_x <= slider_x + slider_w and adj_y >= slider_y - 4 and adj_y <= slider_y + slider_h + 4 then
                SceneSettings.active_item_index = i
                local pct = math.max(0, math.min(1, (adj_x - slider_x) / slider_w))
                local val = item.min + pct * (item.max - item.min)
                local s = SettingsManager.settings
                if item.is_ms then s[item.id] = val / 1000.0
                elseif item.is_pct then s[item.id] = val / 100.0
                else s[item.id] = val end
                SettingsManager.save()
                AudioManager.playSliderTick()
                return true
            end
        end
    end

    local btn_reset_x = card_x + 20
    local btn_reset_y = card_y + card_h - 38
    if adj_x >= btn_reset_x and adj_x <= btn_reset_x + 200 and adj_y >= btn_reset_y and adj_y <= btn_reset_y + 32 then
        SettingsManager.resetTab(SceneSettings.active_tab_index)
        if SceneSettings.active_tab_index == 1 then
            RulesetManager.setRuleset(SettingsManager.get("active_ruleset"))
        elseif SceneSettings.active_tab_index == 5 then
            ThemeManager.setTheme(SettingsManager.get("theme_skin"))
        end
        AudioManager.playImmediateSFX("rotate", false)
        return true
    end

    local btn_save_w = 260
    local btn_save_x = card_x + card_w - btn_save_w - 20
    local btn_save_y = card_y + card_h - 38
    if adj_x >= btn_save_x and adj_x <= btn_save_x + btn_save_w and adj_y >= btn_save_y and adj_y <= btn_save_y + 32 then
        SceneSettings.close()
        return true
    end

    return false
end

function SceneSettings.gamepadpressed(joystick, button)
    if button == "leftshoulder" then
        SceneSettings.active_tab_index = (SceneSettings.active_tab_index == 1) and #SettingsManager.tabs or (SceneSettings.active_tab_index - 1)
        SceneSettings.active_item_index = 1
        AudioManager.playMenuHover()
    elseif button == "rightshoulder" then
        SceneSettings.active_tab_index = (SceneSettings.active_tab_index % #SettingsManager.tabs) + 1
        SceneSettings.active_item_index = 1
        AudioManager.playMenuHover()
    elseif button == "dpup" then
        local current_tab = SettingsManager.tabs[SceneSettings.active_tab_index]
        SceneSettings.active_item_index = (SceneSettings.active_item_index == 1) and #current_tab.items or (SceneSettings.active_item_index - 1)
        AudioManager.playMenuHover()
    elseif button == "dpdown" then
        local current_tab = SettingsManager.tabs[SceneSettings.active_tab_index]
        SceneSettings.active_item_index = (SceneSettings.active_item_index % #current_tab.items) + 1
        AudioManager.playMenuHover()
    elseif button == "dpleft" then
        SceneSettings.adjustActiveSetting(-1)
    elseif button == "dpright" or button == "a" then
        SceneSettings.adjustActiveSetting(1)
    elseif button == "b" or button == "start" then
        SceneSettings.close()
    end
end

return SceneSettings
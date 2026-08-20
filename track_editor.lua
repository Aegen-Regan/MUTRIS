---@diagnostic disable: undefined-global
local TrackEditor = {}
local love = love

local TrackManager = require "track_manager"
local AudioManager = require "audio_manager"

TrackEditor.active = false
TrackEditor.batch_queue = {}
TrackEditor.current_file_path = nil
TrackEditor.track_name = "NO TRACK LOADED"
TrackEditor.bpm = 120
TrackEditor.root_note = "A"
TrackEditor.mode = "MINOR"
TrackEditor.drop_second = 0

TrackEditor.spectrogram_bars = {}
for i = 1, 32 do TrackEditor.spectrogram_bars[i] = 0 end

TrackEditor.dropdowns = {
    note = { active = false, x = 320, y = 245, w = 120, h = 22 },
    mode = { active = false, x = 320, y = 295, w = 120, h = 22 }
}
TrackEditor.selected_field = 1

TrackEditor.preview_source = nil
TrackEditor.is_playing = false
TrackEditor.flash_alpha = 0
TrackEditor.tap_times = {}

local key_held_timer = 0
local key_repeat_timer = 0
TrackEditor.CHROMATIC_NOTES = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
local note_index = 10

function TrackEditor.enterBatch(file_paths_list)
    TrackEditor.batch_queue = file_paths_list
    TrackEditor.processNextInQueue()
end

function TrackEditor.processNextInQueue()
    if #TrackEditor.batch_queue == 0 then
        TrackEditor.close()
        return
    end
    
    TrackEditor.active = true
    _G.SetGameState("editor")
    
    local next_file = table.remove(TrackEditor.batch_queue, 1)
    TrackEditor.current_file_path = next_file
    
    local name = next_file:match("([^/\\]+)%.[^%.]+$") or "UNKNOWN"
    TrackEditor.track_name = name:sub(1, 24):upper()
    
    TrackEditor.bpm = 120
    TrackEditor.mode = "MINOR"
    TrackEditor.drop_second = 0
    TrackEditor.selected_field = 1
    TrackEditor.dropdowns.note.active = false
    TrackEditor.dropdowns.mode.active = false
    TrackEditor.tap_times = {}
    TrackEditor.flash_alpha = 0
    note_index = 10
    TrackEditor.root_note = TrackEditor.CHROMATIC_NOTES[note_index]
    
    if TrackEditor.preview_source then TrackEditor.preview_source:stop() end

    local success, src = pcall(love.audio.newSource, next_file, "stream")
    if success then
        TrackEditor.preview_source = src
        TrackEditor.preview_source:setLooping(true)
        TrackEditor.preview_source:setVolume(0.75)
        TrackEditor.preview_source:play()
        TrackEditor.is_playing = true
    else
        TrackEditor.track_name = "ENVELOPE LOADING ERROR"
    end
end

function TrackEditor.markDropSecond()
    if TrackEditor.preview_source and TrackEditor.is_playing then
        local sec = TrackEditor.preview_source:tell("seconds")
        TrackEditor.drop_second = math.floor(sec * 10 + 0.5) / 10
        TrackEditor.flash_alpha = 0.95
        AudioManager.playImmediateSFX("tetris", false)
    end
end

function TrackEditor.tap()
    local now = love.timer.getTime()
    table.insert(TrackEditor.tap_times, now)
    if #TrackEditor.tap_times > 5 then table.remove(TrackEditor.tap_times, 1) end
    if #TrackEditor.tap_times >= 2 then
        local total = 0
        for i = 2, #TrackEditor.tap_times do total = total + (TrackEditor.tap_times[i] - TrackEditor.tap_times[i-1]) end
        local avg = total / (#TrackEditor.tap_times - 1)
        if avg > 0 then
            local calculated = math.floor((60 / avg) + 0.5)
            if calculated >= 60 and calculated <= 240 then TrackEditor.bpm = calculated end
        end
    end
    TrackEditor.flash_alpha = 0.65
end

function TrackEditor.update(dt)
    if not TrackEditor.active then return end
    
    if TrackEditor.flash_alpha > 0 then
        TrackEditor.flash_alpha = TrackEditor.flash_alpha - dt * 4
    end
    
    if TrackEditor.selected_field == 1 and not TrackEditor.dropdowns.note.active and not TrackEditor.dropdowns.mode.active then
        if love.keyboard.isDown("left") then
            key_held_timer = key_held_timer + dt
            if key_held_timer >= 0.25 then
                key_repeat_timer = key_repeat_timer + dt
                if key_repeat_timer >= 0.02 then
                    key_repeat_timer = 0
                    TrackEditor.bpm = math.max(60, TrackEditor.bpm - 1)
                end
            end
        elseif love.keyboard.isDown("right") then
            key_held_timer = key_held_timer + dt
            if key_held_timer >= 0.25 then
                key_repeat_timer = key_repeat_timer + dt
                if key_repeat_timer >= 0.02 then
                    key_repeat_timer = 0
                    TrackEditor.bpm = math.min(240, TrackEditor.bpm + 1)
                end
            end
        else
            key_held_timer, key_repeat_timer = 0, 0
        end
    end
    
    if TrackEditor.is_playing and TrackEditor.preview_source then
        local play_time = TrackEditor.preview_source:tell("seconds")
        local beat_duration = 60 / TrackEditor.bpm
        local current_beat = play_time / beat_duration
        local fraction = current_beat - math.floor(current_beat)
        
        if fraction < 0.08 and TrackEditor.flash_alpha <= 0.1 then
            TrackEditor.flash_alpha = 0.45
            AudioManager.playHatClosed(0.08)
        end
        
        for i = 1, 32 do
            local wave_sync = math.sin(play_time * 8 + i * 0.3) * math.cos(play_time * 3 - i * 0.5)
            local impulse = (fraction < 0.25) and (1 - fraction / 0.25) * 0.6 or 0.1
            local target_height = math.max(5, (0.3 + wave_sync * 0.3 + impulse) * 110)
            TrackEditor.spectrogram_bars[i] = TrackEditor.spectrogram_bars[i] + (target_height - TrackEditor.spectrogram_bars[i]) * 15 * dt
        end
    else
        for i = 1, 32 do
            TrackEditor.spectrogram_bars[i] = math.max(2, TrackEditor.spectrogram_bars[i] - dt * 120)
        end
    end
end

function TrackEditor.mousepressed(mx, my, button)
    if not TrackEditor.active or button ~= 1 then return end
    
    local dn = TrackEditor.dropdowns.note
    if mx >= dn.x and mx <= dn.x + dn.w and my >= dn.y and my <= dn.y + dn.h then
        dn.active = not dn.active
        TrackEditor.dropdowns.mode.active = false
        AudioManager.playImmediateSFX("move", false)
        return
    end
    
    if dn.active then
        for i, n in ipairs(TrackEditor.CHROMATIC_NOTES) do
            local item_y = dn.y + dn.h + (i - 1) * 20
            if mx >= dn.x and mx <= dn.x + dn.w and my >= item_y and my <= item_y + 20 then
                TrackEditor.root_note = n
                note_index = i
                dn.active = false
                AudioManager.playImmediateSFX("rotate", false)
                return
            end
        end
        dn.active = false
    end

    local dm = TrackEditor.dropdowns.mode
    if mx >= dm.x and mx <= dm.x + dm.w and my >= dm.y and my <= dm.y + dm.h then
        dm.active = not dm.active
        TrackEditor.dropdowns.note.active = false
        AudioManager.playImmediateSFX("move", false)
        return
    end
    
    if dm.active then
        local modes_opt = {"MINOR", "MAJOR"}
        for i, m in ipairs(modes_opt) do
            local item_y = dm.y + dm.h + (i - 1) * 20
            if mx >= dm.x and mx <= dm.x + dm.w and my >= item_y and my <= item_y + 20 then
                TrackEditor.mode = m
                dm.active = false
                AudioManager.playImmediateSFX("rotate", false)
                return
            end
        end
        dm.active = false
    end

    -- BOTÓN MARCADOR DROP [D]
    if mx >= 320 and mx <= 520 and my >= 340 and my <= 368 then
        TrackEditor.markDropSecond()
        return
    end

    -- BOTÓN PLAY / PAUSA
    if mx >= 200 and mx <= 380 and my >= 440 and my <= 475 then
        if TrackEditor.preview_source then
            if TrackEditor.is_playing then
                TrackEditor.preview_source:pause()
                TrackEditor.is_playing = false
            else
                TrackEditor.preview_source:play()
                TrackEditor.is_playing = true
            end
            AudioManager.playImmediateSFX("hold", false)
        end
    end

    -- BOTÓN CONFIRMAR E INYECTAR
    if mx >= 420 and mx <= 600 and my >= 440 and my <= 475 then
        TrackEditor.saveAndInject()
    end
end

function TrackEditor.draw()
    if not TrackEditor.active then return end
    
    love.graphics.push("all")
    love.graphics.clear(0.01, 0.01, 0.04)
    
    local grid_alpha = 0.02 + TrackEditor.flash_alpha * 0.02
    love.graphics.setColor(0, 0.8, 1, grid_alpha)
    for i = 0, 800, 40 do 
        love.graphics.line(i, 0, i, 600)
        love.graphics.line(0, i, 800, i) 
    end

    if TrackEditor.flash_alpha > 0 then
        love.graphics.setLineWidth(4)
        love.graphics.setColor(0, 0.8, 1, TrackEditor.flash_alpha * 0.5)
        love.graphics.rectangle("line", 2, 2, 796, 596)
        love.graphics.setLineWidth(1)
    end

    love.graphics.setColor(0, 0.8, 1, 0.15)
    for i = 1, 32 do
        local bar_x = 75 + (i - 1) * 20
        local bar_h = TrackEditor.spectrogram_bars[i]
        love.graphics.rectangle("fill", bar_x, 530 - bar_h, 16, bar_h)
        love.graphics.setColor(0, 0.6, 1, 0.3)
        love.graphics.rectangle("line", bar_x, 530 - bar_h, 16, bar_h)
        love.graphics.setColor(0, 0.8, 1, 0.15)
    end

    love.graphics.setFont(love.graphics.newFont(22))
    love.graphics.setColor(0, 0.8, 1, 0.9)
    love.graphics.printf("SOUNDTRACK INJECTION LAB", 0, 20, 800, "center")
    love.graphics.setFont(love.graphics.newFont(12))
    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.printf("HYBRID PHRASE & DROP OVERRIDE SYSTEM", 0, 50, 800, "center")

    love.graphics.setColor(0.03, 0.04, 0.08, 0.8)
    love.graphics.rectangle("fill", 150, 75, 500, 45, 4)
    love.graphics.setColor(0, 0.8, 1, 0.2)
    love.graphics.rectangle("line", 150, 75, 500, 45, 4)
    
    love.graphics.setFont(love.graphics.newFont(10))
    love.graphics.setColor(0.4, 0.6, 0.8)
    love.graphics.print("TARGET TRACK:", 170, 81)
    love.graphics.setFont(love.graphics.newFont(12))
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(TrackEditor.track_name, 170, 96)

    -- Fila 1: BPM
    love.graphics.setFont(love.graphics.newFont(11))
    love.graphics.setColor(0.6, 0.7, 0.8)
    love.graphics.print("BPM (BEATS PER MINUTE):", 170, 155)
    love.graphics.setColor(0.05, 0.07, 0.12, 0.9)
    love.graphics.rectangle("fill", 320, 150, 200, 24, 2)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(tostring(TrackEditor.bpm) .. " BPM", 320, 155, 200, "center")

    -- Fila 2: Tonalidad
    love.graphics.setColor(0.6, 0.7, 0.8)
    love.graphics.print("ROOT KEY (CHROMATIC):", 170, 248)
    love.graphics.setColor(0.05, 0.07, 0.12, 0.9)
    love.graphics.rectangle("fill", TrackEditor.dropdowns.note.x, TrackEditor.dropdowns.note.y, TrackEditor.dropdowns.note.w, TrackEditor.dropdowns.note.h, 2)
    love.graphics.setColor(0, 0.8, 1)
    love.graphics.rectangle("line", TrackEditor.dropdowns.note.x, TrackEditor.dropdowns.note.y, TrackEditor.dropdowns.note.w, TrackEditor.dropdowns.note.h, 2)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(TrackEditor.root_note .. "  v", TrackEditor.dropdowns.note.x, TrackEditor.dropdowns.note.y + 3, TrackEditor.dropdowns.note.w, "center")

    -- Fila 3: Modo
    love.graphics.setColor(0.6, 0.7, 0.8)
    love.graphics.print("HARMONIC MODE (CAMELOT):", 170, 298)
    love.graphics.setColor(0.05, 0.07, 0.12, 0.9)
    love.graphics.rectangle("fill", TrackEditor.dropdowns.mode.x, TrackEditor.dropdowns.mode.y, TrackEditor.dropdowns.mode.w, TrackEditor.dropdowns.mode.h, 2)
    love.graphics.setColor(0, 0.8, 1)
    love.graphics.rectangle("line", TrackEditor.dropdowns.mode.x, TrackEditor.dropdowns.mode.y, TrackEditor.dropdowns.mode.w, TrackEditor.dropdowns.mode.h, 2)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(TrackEditor.mode .. "  v", TrackEditor.dropdowns.mode.x, TrackEditor.dropdowns.mode.y + 3, TrackEditor.dropdowns.mode.w, "center")

    -- Fila 4: MARCADOR DROP [D]
    love.graphics.setColor(0.6, 0.7, 0.8)
    love.graphics.print("DROP SECOND OVERRIDE:", 170, 348)
    love.graphics.setColor(0.05, 0.07, 0.15, 0.9)
    love.graphics.rectangle("fill", 320, 340, 200, 26, 2)
    love.graphics.setColor(0, 0.8, 1, 0.4)
    love.graphics.rectangle("line", 320, 340, 200, 26, 2)
    love.graphics.setColor(1.0, 0.85, 0.2)
    local drop_str = (TrackEditor.drop_second > 0) and (string.format("%.1fs", TrackEditor.drop_second) .. " (CLICK OR [D])") or "AUTO (PRESS [D] ON DROP)"
    love.graphics.printf(drop_str, 320, 346, 200, "center")

    -- BOTONES
    local mx, my = love.mouse.getPosition()
    local hover_play = (mx >= 200 and mx <= 380 and my >= 440 and my <= 475)
    love.graphics.setColor(hover_play and {0, 0.4, 0.7, 0.8} or {0.05, 0.08, 0.15, 0.8})
    love.graphics.rectangle("fill", 200, 440, 180, 35, 4)
    love.graphics.setColor(0, 0.8, 1, 0.4)
    love.graphics.rectangle("line", 200, 440, 180, 35, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(TrackEditor.is_playing and "MUTED MONITOR" or "PLAY AUDITION", 200, 451, 180, "center")

    local hover_confirm = (mx >= 420 and mx <= 600 and my >= 440 and my <= 475)
    love.graphics.setColor(hover_confirm and {0, 0.6, 0.4, 0.9} or {0.04, 0.15, 0.08, 0.8})
    love.graphics.rectangle("fill", 420, 440, 180, 35, 4)
    love.graphics.setColor(0, 1, 0.5, 0.4)
    love.graphics.rectangle("line", 420, 440, 180, 35, 4)
    love.graphics.setColor(1, 1, 1)
    local label_save = (#TrackEditor.batch_queue > 0) and "INJECT & NEXT TRACK" or "INJECT SOUNDTRACK"
    love.graphics.printf(label_save, 420, 451, 180, "center")

    -- Overlays de dropdowns
    if TrackEditor.dropdowns.note.active then
        local dn = TrackEditor.dropdowns.note
        love.graphics.setColor(0.02, 0.03, 0.06, 0.95)
        love.graphics.rectangle("fill", dn.x, dn.y + dn.h, dn.w, #TrackEditor.CHROMATIC_NOTES * 20, 2)
        love.graphics.setColor(0, 0.8, 1, 0.5)
        love.graphics.rectangle("line", dn.x, dn.y + dn.h, dn.w, #TrackEditor.CHROMATIC_NOTES * 20, 2)
        for i, n in ipairs(TrackEditor.CHROMATIC_NOTES) do
            local item_y = dn.y + dn.h + (i - 1) * 20
            local h_item = (mx >= dn.x and mx <= dn.x + dn.w and my >= item_y and my <= item_y + 20)
            love.graphics.setColor(h_item and {0, 0.8, 1, 0.2} or {0,0,0,0})
            love.graphics.rectangle("fill", dn.x + 1, item_y, dn.w - 2, 20)
            love.graphics.setColor(h_item and {1, 1, 1, 1} or {0.7, 0.7, 0.8, 0.9})
            love.graphics.print("  " .. n, dn.x + 5, item_y + 3)
        end
    end

    if TrackEditor.dropdowns.mode.active then
        local dm = TrackEditor.dropdowns.mode
        local modes_opt = {"MINOR", "MAJOR"}
        love.graphics.setColor(0.02, 0.03, 0.06, 0.95)
        love.graphics.rectangle("fill", dm.x, dm.y + dm.h, dm.w, #modes_opt * 20, 2)
        love.graphics.setColor(0, 0.8, 1, 0.5)
        love.graphics.rectangle("line", dm.x, dm.y + dm.h, dm.w, #modes_opt * 20, 2)
        for i, m in ipairs(modes_opt) do
            local item_y = dm.y + dm.h + (i - 1) * 20
            local h_item = (mx >= dm.x and mx <= dm.x + dm.w and my >= item_y and my <= item_y + 20)
            love.graphics.setColor(h_item and {0, 0.8, 1, 0.2} or {0,0,0,0})
            love.graphics.rectangle("fill", dm.x + 1, item_y, dm.w - 2, 20)
            love.graphics.setColor(h_item and {1, 1, 1, 1} or {0.7, 0.7, 0.8, 0.9})
            love.graphics.print("  " .. m, dm.x + 5, item_y + 3)
        end
    end

    love.graphics.pop()
end

function TrackEditor.keypressed(key)
    if not TrackEditor.active then return end
    if key == "escape" then
        TrackEditor.close()
        return
    end
    if key == "d" then
        TrackEditor.markDropSecond()
        return
    end
    if key == "space" then
        TrackEditor.tap()
        return
    end
    if key == "left" then TrackEditor.bpm = math.max(60, TrackEditor.bpm - 1)
    elseif key == "right" then TrackEditor.bpm = math.min(240, TrackEditor.bpm + 1)
    elseif key == "return" then TrackEditor.saveAndInject()
    end
end

function TrackEditor.saveAndInject()
    if TrackEditor.current_file_path then
        local success, msg = TrackManager.injectCustomTrack(
            TrackEditor.current_file_path, 
            TrackEditor.track_name, 
            TrackEditor.bpm, 
            TrackEditor.root_note,
            TrackEditor.mode,
            TrackEditor.drop_second or 0,
            0
        )
        if success then
            TrackEditor.processNextInQueue()
        end
    end
end

function TrackEditor.close()
    TrackEditor.active = false
    if TrackEditor.preview_source then
        TrackEditor.preview_source:stop()
        TrackEditor.preview_source = nil
    end
    _G.SetGameState("menu")
    local MusicManager = require "music_manager"
    MusicManager.stop()
    MusicManager.start()
end

return TrackEditor
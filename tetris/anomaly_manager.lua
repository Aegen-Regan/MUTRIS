---@diagnostic disable: undefined-global
local AnomalyManager = {}
local FontCache = require "tetris.font_cache"
local AudioManager = require "audio_manager"

AnomalyManager.current_anomaly = nil
AnomalyManager.timer = 0
AnomalyManager.duration = 0
AnomalyManager.warning_timer = 0
AnomalyManager.cooldown = 45.0
AnomalyManager.time_until_next = 35.0

AnomalyManager.step_timer = 0
AnomalyManager.laser_x = 0
AnomalyManager.laser_dir = 1

local ANOMALY_POOL = {
    { id = "torus_belt", name = "TORUS CONVEYOR (LOCAL)", dur = 12.0 },
    { id = "global_wormhole", name = "GLOBAL WORMHOLE (CROSS-MATRIX)", dur = 10.0 },
    { id = "laser_scan", name = "QUANTUM LASER SCANNER", dur = 12.0 },
    { id = "matrix_swap", name = "SUDDEN MATRIX SWAP", dur = 3.0 }
}

function AnomalyManager.init()
    AnomalyManager.current_anomaly = nil
    AnomalyManager.timer = 0
    AnomalyManager.duration = 0
    AnomalyManager.warning_timer = 0
    AnomalyManager.time_until_next = 35.0
    AnomalyManager.step_timer = 0
    AnomalyManager.laser_x = 80
    AnomalyManager.laser_dir = 1
end

function AnomalyManager.triggerRandomAnomaly(track_bpm)
    local idx = math.random(1, #ANOMALY_POOL)
    local selected = ANOMALY_POOL[idx]
    
    AnomalyManager.current_anomaly = selected.id
    AnomalyManager.duration = selected.dur
    AnomalyManager.timer = selected.dur
    AnomalyManager.warning_timer = 0
    AnomalyManager.step_timer = 0
    
    AudioManager.playImmediateSFX("phantom_attack", false)
    AudioManager.triggerGlitch(0.4)
end

function AnomalyManager.update(dt, player, bot)
    local bpm = AudioManager.current_bpm or 120
    local beat_duration = 60 / bpm

    -- Control de Cooldown / Aviso Previo
    if not AnomalyManager.current_anomaly then
        AnomalyManager.time_until_next = AnomalyManager.time_until_next - dt
        
        -- Aviso de 3 segundos antes
        if AnomalyManager.time_until_next <= 3.0 and AnomalyManager.warning_timer <= 0 then
            AnomalyManager.warning_timer = 3.0
            AudioManager.triggerGlitch(0.2)
        end
        
        if AnomalyManager.warning_timer > 0 then
            AnomalyManager.warning_timer = AnomalyManager.warning_timer - dt
        end

        if AnomalyManager.time_until_next <= 0 then
            AnomalyManager.triggerRandomAnomaly(bpm)
        end
        return
    end

    -- Ejecución activa de la Anomalía
    AnomalyManager.timer = AnomalyManager.timer - dt
    local id = AnomalyManager.current_anomaly

    if id == "torus_belt" then
        -- Desplazamiento local de columnas al ritmo de cada compás
        AnomalyManager.step_timer = AnomalyManager.step_timer + dt
        if AnomalyManager.step_timer >= (beat_duration * 1.5) then
            AnomalyManager.step_timer = 0
            if player and not player.is_dying then player:shiftColumnsLocal(1) end
            if bot and not bot.is_dying then bot:shiftColumnsLocal(1) end
            AudioManager.playImmediateSFX("move", false)
        end

    elseif id == "global_wormhole" then
        -- Desplazamiento global continuo entre ambos tableros (anillo de 20 columnas)
        AnomalyManager.step_timer = AnomalyManager.step_timer + dt
        if AnomalyManager.step_timer >= (beat_duration * 0.8) then
            AnomalyManager.step_timer = 0
            if player and bot and not player.is_dying and not bot.is_dying then
                player:shiftColumnsGlobal(bot, 1)
            end
            AudioManager.playImmediateSFX("move", true)
        end

    elseif id == "laser_scan" then
        -- Escáner láser continuo
        AnomalyManager.laser_x = AnomalyManager.laser_x + AnomalyManager.laser_dir * 180 * dt
        if AnomalyManager.laser_x > 720 then
            AnomalyManager.laser_x = 720
            AnomalyManager.laser_dir = -1
        elseif AnomalyManager.laser_x < 80 then
            AnomalyManager.laser_x = 80
            AnomalyManager.laser_dir = 1
        end

    elseif id == "matrix_swap" then
        -- Cuenta regresiva y SWAP súbito de tableros
        if AnomalyManager.timer <= 0.1 and not AnomalyManager.swapped then
            AnomalyManager.swapped = true
            if player and bot and not player.is_dying and not bot.is_dying then
                player:swapGrids(bot)
                _G.HitStopTimer = 0.35
                AudioManager.playImmediateSFX("ultimatris", false)
            end
        end
    end

    if AnomalyManager.timer <= 0 then
        AnomalyManager.current_anomaly = nil
        AnomalyManager.swapped = false
        AnomalyManager.time_until_next = AnomalyManager.cooldown
        AnomalyManager.warning_timer = 0
        AudioManager.triggerGlitch(0.2)
    end
end

function AnomalyManager.draw(player, bot)
    love.graphics.push("all")
    local time = love.timer.getTime()
    local pulse = _G.AudioBeatPulse or 0

    -- 1. AVISO PREVIO EN EL HUD CENTRAL (3 Segundos antes)
    if AnomalyManager.warning_timer > 0 and not AnomalyManager.current_anomaly then
        local flash = 0.5 + math.sin(time * 18) * 0.5
        love.graphics.setColor(1.0, 0.2, 0.1, 0.85 * flash)
        love.graphics.setFont(FontCache.get(11))
        love.graphics.printf("⚠ ANOMALY IMMINENT IN " .. string.format("%.1fs", AnomalyManager.warning_timer), 0, 205, 800, "center")
    end

    -- 2. HUD DE ANOMALÍA ACTIVA
    if AnomalyManager.current_anomaly then
        local name = "ACTIVE ANOMALY"
        for _, a in ipairs(ANOMALY_POOL) do
            if a.id == AnomalyManager.current_anomaly then name = a.name break end
        end

        local flash = 0.7 + math.sin(time * 12) * 0.3
        love.graphics.setColor(1.0, 0.85, 0.2, 0.9 * flash)
        love.graphics.setFont(FontCache.get(10))
        love.graphics.printf("⚡ ANOMALY: " .. name .. " (" .. string.format("%.1fs", AnomalyManager.timer) .. ")", 0, 205, 800, "center")

        -- 3. RENDERIZADO DEL PUENTE LÁSER EN GLOBAL WORMHOLE
        if AnomalyManager.current_anomaly == "global_wormhole" then
            love.graphics.setBlendMode("add")
            love.graphics.setLineWidth(2 + pulse * 2)
            love.graphics.setColor(0.9, 0.2, 1.0, 0.6 + pulse * 0.3)
            
            -- Raíles de conexión a través del pasillo central (x: 320 a 480)
            for r = 0, 10 do
                local line_y = 50 + 240 + (r * 24)
                love.graphics.line(320, line_y, 480, line_y)
            end
            love.graphics.setBlendMode("alpha")
        end

        -- 4. RENDERIZADO DEL LÁSER EN QUANTUM SCANNER
        if AnomalyManager.current_anomaly == "laser_scan" then
            love.graphics.setBlendMode("add")
            love.graphics.setLineWidth(3 + pulse * 3)
            love.graphics.setColor(0.2, 0.95, 1.0, 0.85 + pulse * 0.15)
            love.graphics.line(AnomalyManager.laser_x, 40, AnomalyManager.laser_x, 540)
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.line(AnomalyManager.laser_x, 40, AnomalyManager.laser_x, 540)
            love.graphics.setBlendMode("alpha")
        end
    end

    love.graphics.pop()
end

return AnomalyManager
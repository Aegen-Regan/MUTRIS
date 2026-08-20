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

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  🎨  PANEL DE CONTROL: COLORES Y ESTILOS DE ANOMALÍAS            ║
-- ╚══════════════════════════════════════════════════════════════════════╝
ANOMALY_THEMES = {
    torus_belt       = { c1 = {0.55, 0.20, 1.0}, c2 = {0.80, 0.45, 1.0}, label = "TORUS" },
    global_wormhole  = { c1 = {0.95, 0.15, 0.85}, c2 = {1.00, 0.55, 0.90}, label = "WORM" },
    laser_scan       = { c1 = {0.15, 0.65, 1.0}, c2 = {0.45, 0.90, 1.0}, label = "LASER" },
    matrix_swap      = { c1 = {1.00, 0.08, 0.15}, c2 = {1.00, 0.55, 0.35}, label = "SWAP!" },
    gravity_flip     = { c1 = {0.85, 0.15, 0.25}, c2 = {0.95, 0.45, 0.75}, label = "ANTIG" },
    lock_drain       = { c1 = {1.00, 0.45, 0.05}, c2 = {1.00, 0.75, 0.20}, label = "DRAIN" },
    hyper_speed      = { c1 = {0.10, 0.85, 0.95}, c2 = {0.55, 1.00, 0.95}, label = "SPEED" }
}
DEFAULT_THEME = { c1 = {1.0, 0.85, 0.2}, c2 = {1.0, 1.0, 0.5}, label = "ANOM" }

local ANOMALY_POOL = {
    { id = "torus_belt",      name = "TORUS CONVEYOR (LOCAL)",         dur = 12.0 },
    { id = "global_wormhole", name = "GLOBAL WORMHOLE (CROSS-MATRIX)",  dur = 10.0 },
    { id = "laser_scan",     name = "QUANTUM LASER SCANNER",          dur = 12.0 },
    { id = "matrix_swap",    name = "SUDDEN MATRIX SWAP",             dur =  3.0 },
    { id = "gravity_flip",   name = "ANTI-GRAVITY REVERSE",           dur = 10.0 },
    { id = "lock_drain",     name = "LOCK DRAIN OVERLOAD",             dur = 12.0 },
    { id = "hyper_speed",    name = "HYPER SPEED RUN BOOST",         dur = 15.0 }
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
    AnomalyManager.swapped = false
    AnomalyManager.lock_drain_active = false
    AnomalyManager.hyper_speed_active = false
end

function AnomalyManager.triggerRandomAnomaly(track_bpm)
    local idx = math.random(1, #ANOMALY_POOL)
    local selected = ANOMALY_POOL[idx]

    AnomalyManager.current_anomaly = selected.id
    AnomalyManager.duration = selected.dur
    AnomalyManager.timer = selected.dur
    AnomalyManager.warning_timer = 0
    AnomalyManager.step_timer = 0
    AnomalyManager.swapped = false
    AnomalyManager.lock_drain_active = false
    AnomalyManager.hyper_speed_active = false

    AudioManager.playImmediateSFX("phantom_attack", false)
    if selected.id == "gravity_flip" or selected.id == "matrix_swap" or selected.id == "hyper_speed" then
        AudioManager.triggerGlitch(0.6)
    else
        AudioManager.triggerGlitch(0.4)
    end
end

function AnomalyManager.update(dt, player, bot)
    local bpm = AudioManager.current_bpm or 120
    local beat_duration = 60 / bpm

    if not AnomalyManager.current_anomaly then
        AnomalyManager.time_until_next = AnomalyManager.time_until_next - dt

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

    AnomalyManager.timer = AnomalyManager.timer - dt
    local id = AnomalyManager.current_anomaly

    if id == "torus_belt" then
        AnomalyManager.step_timer = AnomalyManager.step_timer + dt
        if AnomalyManager.step_timer >= (beat_duration * 1.5) then
            AnomalyManager.step_timer = 0
            if player and not player.is_dying then player:shiftColumnsLocal(1) end
            if bot and not bot.is_dying then bot:shiftColumnsLocal(1) end
            AudioManager.playImmediateSFX("move", false)
        end

    elseif id == "global_wormhole" then
        AnomalyManager.step_timer = AnomalyManager.step_timer + dt
        if AnomalyManager.step_timer >= (beat_duration * 0.8) then
            AnomalyManager.step_timer = 0
            if player and bot and not player.is_dying and not bot.is_dying then
                player:shiftColumnsGlobal(bot, 1)
            end
            AudioManager.playImmediateSFX("move", true)
        end

    elseif id == "laser_scan" then
        AnomalyManager.laser_x = AnomalyManager.laser_x + AnomalyManager.laser_dir * 180 * dt
        if AnomalyManager.laser_x > 720 then
            AnomalyManager.laser_x = 720
            AnomalyManager.laser_dir = -1
        elseif AnomalyManager.laser_x < 80 then
            AnomalyManager.laser_x = 80
            AnomalyManager.laser_dir = 1
        end

    elseif id == "matrix_swap" then
        if AnomalyManager.timer <= 0.1 and not AnomalyManager.swapped then
            AnomalyManager.swapped = true
            if player and bot and not player.is_dying and not bot.is_dying then
                player:swapGrids(bot)
                _G.HitStopTimer = 0.35
                AudioManager.playImmediateSFX("ultimatris", false)
            end
        end

    elseif id == "gravity_flip" then
        AnomalyManager.step_timer = AnomalyManager.step_timer + dt
        if AnomalyManager.step_timer >= (beat_duration * 0.5) then
            AnomalyManager.step_timer = 0
            if player and not player.is_dying then
                local pp = player.active_piece
                if pp and not pp.locked then
                    while pp:canMove(pp.x, pp.y - 1, pp.rotation) do
                        pp.y = pp.y - 1
                    end
                end
            end
            if bot and not bot.is_dying then
                local bp = bot.active_piece
                if bp and not bp.locked then
                    while bp:canMove(bp.x, bp.y - 1, bp.rotation) do
                        bp.y = bp.y - 1
                    end
                end
            end
            AudioManager.playImmediateSFX("rotate", false)
        end

    elseif id == "lock_drain" then
        AnomalyManager.lock_drain_active = true
        if player and player.active_piece and not player.is_dying then
            player.active_piece.lock_delay = 0.08
        end
        if bot and bot.active_piece and not bot.is_dying then
            bot.active_piece.lock_delay = 0.08
        end

    elseif id == "hyper_speed" then
        AnomalyManager.hyper_speed_active = true
        if player and not player.is_dying then
            local pp = player.active_piece
            if pp and not pp.locked then pp.spawn_timer = 0 end
        end
        if bot and bot.ai and not bot.is_dying then
            local active_punch = _G.TrackEnergyPunch or 0
            bot.ai.pps = bot.ai.base_pps + (active_punch * 8.0) + 5.2
        end
        AudioManager.playHatClosed(0.25)
    end

    if AnomalyManager.timer <= 0 then
        if AnomalyManager.lock_drain_active then
            if player and player.active_piece then player.active_piece.lock_delay = 0.5 end
            if bot and bot.active_piece then bot.active_piece.lock_delay = 0.5 end
        end
        AnomalyManager.lock_drain_active = false
        AnomalyManager.hyper_speed_active = false

        AnomalyManager.current_anomaly = nil
        AnomalyManager.swapped = false
        AnomalyManager.time_until_next = AnomalyManager.cooldown
        AnomalyManager.warning_timer = 0
        AudioManager.triggerGlitch(0.2)
    end
end

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  🎨  DRAW: HUD REDISEÑADO — PELIGRO VISUAL EXTREMO               ║
-- ╚══════════════════════════════════════════════════════════════════════╝
function AnomalyManager.draw(player, bot)
    love.graphics.push("all")
    local time = love.timer.getTime()
    local pulse = _G.AudioBeatPulse or 0
    local energy = _G.TrackEnergyPunch or 0

    -- ─────────────────────────────────────────────────────────────────
    -- 1) ⚠️ WARNING INMINENTE (3 segundos antes) — PELIGRO EXTREMO
    -- ─────────────────────────────────────────────────────────────────
    if AnomalyManager.warning_timer > 0 and not AnomalyManager.current_anomaly then
        local wt = AnomalyManager.warning_timer
        local urgency = 1.0 - (wt / 3.0)  -- 0 al principio → 1 al final
        local flash = 0.45 + math.sin(time * (14 + urgency * 32)) * 0.55
        local count_sec = math.max(0, math.ceil(wt))

        love.graphics.setBlendMode("add")

        -- A) Gradiente radial oscuro de tensión (más oscuro en los bordes)
        local steps = 24
        for i = steps, 1, -1 do
            local p = i / steps
            local alpha = (1.0 - p) * urgency * 0.32
            love.graphics.setColor(0.9, 0.05, 0.1, alpha)
            local pad = p * 240
            love.graphics.rectangle("line", pad, pad, 800 - pad * 2, 600 - pad * 2, 16)
        end

        -- B) MARCO GIGANTE PARPADEANTE (8px) en los bordes de la pantalla completa
        local frame_w = 8 + pulse * 8
        love.graphics.setColor(1.0, 0.10, 0.12, flash * (0.65 + urgency * 0.35))
        love.graphics.rectangle("fill", 0, 0, 800, frame_w)                                   -- top
        love.graphics.rectangle("fill", 0, 600 - frame_w, 800, frame_w)                       -- bottom
        love.graphics.rectangle("fill", 0, 0, frame_w, 600)                                   -- left
        love.graphics.rectangle("fill", 800 - frame_w, 0, frame_w, 600)                       -- right

        -- Esquinas afiladas más gruesas
        love.graphics.setColor(1.0, 0.5, 0.2, flash * 0.9)
        local cor = 38 + pulse * 8
        love.graphics.line(0, cor, cor, 0)                            -- top-left
        love.graphics.line(800, cor, 800 - cor, 0)                    -- top-right
        love.graphics.line(0, 600 - cor, cor, 600)                    -- bottom-left
        love.graphics.line(800, 600 - cor, 800 - cor, 600)            -- bottom-right

        -- C) SCANLINES HORIZONTALES ROJAS
        love.graphics.setColor(1.0, 0.15, 0.15, urgency * 0.28)
        for y = 0, 599, 4 do
            local scan_alpha = urgency * (0.18 + ((math.sin(time * 60 + y * 0.1) + 1) * 0.5) * 0.35)
            love.graphics.setColor(1.0, 0.08, 0.12, scan_alpha)
            love.graphics.rectangle("fill", 0, y, 800, 2)
        end

        -- D) RAYOS DIAGONALES que salen de las 4 esquinas
        love.graphics.setColor(1.0, 0.25, 0.2, flash * (0.35 + urgency * 0.5))
        love.graphics.setLineWidth(1 + pulse * 3)
        for i = 1, 7 do
            local len = 120 + i * 45 + pulse * 60
            local ang = (i * 0.13) + math.sin(time * 8 + i) * 0.2
            -- Top-left
            love.graphics.line(0, 0, math.cos(ang) * len, math.sin(ang) * len)
            -- Top-right
            love.graphics.line(800, 0, 800 - math.cos(ang) * len, math.sin(ang) * len)
            -- Bot-left
            love.graphics.line(0, 600, math.cos(ang) * len, 600 - math.sin(ang) * len)
            -- Bot-right
            love.graphics.line(800, 600, 800 - math.cos(ang) * len, 600 - math.sin(ang) * len)
        end

        love.graphics.setBlendMode("alpha")

        -- E) TÍTULO: "⚠ ANOMALY INCOMING ⚠" con glitch RGB
        local title_txt = "⚠  ANOMALY INCOMING  ⚠"
        love.graphics.setFont(FontCache.get(18))
        local tw = FontCache.get(18):getWidth(title_txt)
        local tx = 400 - tw / 2

        -- Glitch de color rojo/azul
        local gx_off = (math.random() - 0.5) * (3 + urgency * 10)
        local gy_off = (math.random() - 0.5) * 2
        love.graphics.setColor(1.0, 0.1, 0.1, flash * 0.7)
        love.graphics.print(title_txt, tx - 4 + gx_off, 140 + gy_off)
        love.graphics.setColor(0.1, 0.2, 1.0, flash * 0.7)
        love.graphics.print(title_txt, tx + 4 - gx_off, 140 - gy_off)
        -- Texto central blanco opaco
        love.graphics.setColor(1.0, 1.0, 1.0, flash * (0.8 + urgency * 0.2))
        love.graphics.print(title_txt, tx, 140)

        -- F) CONTADOR GIGANTE 3-2-1 (tamaño 52)
        love.graphics.setFont(FontCache.get(52))
        local cstr = tostring(count_sec)
        local cw = FontCache.get(52):getWidth(cstr)
        local cx = 400 - cw / 2
        local cy = 230

        -- Halo creciente del número
        local halo = (urgency * 18) + pulse * 16
        love.graphics.setColor(1.0, 0.2, 0.25, urgency * 0.35)
        love.graphics.print(cstr, cx - halo / 2, cy - halo / 4, 0, 1 + halo / 200, 1 + halo / 200)
        -- Número central con glitch
        love.graphics.setColor(1.0, 0.2, 0.2, 0.7)
        love.graphics.print(cstr, cx - 3, cy + 2)
        love.graphics.setColor(0.3, 0.4, 1.0, 0.7)
        love.graphics.print(cstr, cx + 3, cy - 2)
        love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
        love.graphics.print(cstr, cx, cy)

        -- G) Tiempo exacto debajo con fuente pequeña
        love.graphics.setFont(FontCache.get(11))
        local tstr = string.format("%.2fs", wt)
        local w2 = FontCache.get(11):getWidth(tstr)
        love.graphics.setColor(1.0, 0.7, 0.3, flash * 0.85)
        love.graphics.print(tstr, 400 - w2 / 2, 345)

        -- H) Barra de progreso de advertencia (se llena hacia 0)
        local bw = 480
        local bx = 400 - bw / 2
        local by = 370
        love.graphics.setColor(0.2, 0.05, 0.05, 0.85)
        love.graphics.rectangle("fill", bx, by, bw, 14, 8)
        love.graphics.setColor(1.0, 0.25, 0.2, 0.9)
        love.graphics.rectangle("fill", bx, by, bw * (1.0 - urgency), 14, 8)
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.rectangle("line", bx, by, bw, 14, 8)
    end

    -- ─────────────────────────────────────────────────────────────────
    -- 2) ⚡ ANOMALÍA ACTIVA — Barras laterales + barra superior/inferior
    -- ─────────────────────────────────────────────────────────────────
    if AnomalyManager.current_anomaly then
        local id = AnomalyManager.current_anomaly
        local theme = ANOMALY_THEMES[id] or DEFAULT_THEME
        local c1, c2 = theme.c1, theme.c2
        local t = AnomalyManager.timer
        local dur = AnomalyManager.duration
        local progress = math.max(0, math.min(1, t / dur))  -- 1 = recién empieza, 0 = termina
        local flash2 = 0.65 + math.sin(time * 10 + energy * 14) * 0.35

        local name = "ACTIVE ANOMALY"
        for _, a in ipairs(ANOMALY_POOL) do
            if a.id == id then name = a.name break end
        end

        love.graphics.setBlendMode("add")

        -- A) BARRAS LATERALES DE COLOR (22px de ancho) — gradiente vertical
        local barw = 22
        for y = 0, 599, 6 do
            local p = y / 600
            local r = c1[1] + (c2[1] - c1[1]) * p
            local g = c1[2] + (c2[2] - c1[2]) * p
            local b = c1[3] + (c2[3] - c1[3]) * p
            local a2 = (0.55 + pulse * 0.35 + math.sin(time * 2 + y * 0.05) * 0.1) * flash2
            love.graphics.setColor(r, g, b, a2 * 0.85)
            -- Left bar
            love.graphics.rectangle("fill", 0, y, barw, 7)
            -- Right bar
            love.graphics.rectangle("fill", 800 - barw, y, barw, 7)
        end

        -- B) BARRA SUPERIOR con nombre de la anomalía
        local top_h = 32
        love.graphics.setColor(c1[1], c1[2], c1[3], 0.7 + pulse * 0.3)
        love.graphics.rectangle("fill", 0, 0, 800, top_h)
        love.graphics.setColor(c2[1], c2[2], c2[3], 0.9)
        love.graphics.rectangle("fill", 0, top_h - 3, 800, 3)

        -- C) BARRA INFERIOR con BARRA DE PROGRESO de la anomalía
        local bot_h = 26
        love.graphics.setColor(c1[1], c1[2], c1[3], 0.55 + pulse * 0.25)
        love.graphics.rectangle("fill", 0, 600 - bot_h, 800, bot_h)
        love.graphics.setColor(c2[1], c2[2], c2[3], 0.85)
        love.graphics.rectangle("fill", 0, 600 - bot_h, 800, 2)

        -- Barra de progreso que se reduce
        local pbx = 60
        local pbw = 800 - pbx * 2
        local pby = 600 - bot_h + 11
        love.graphics.setColor(0, 0, 0, 0.45)
        love.graphics.rectangle("fill", pbx, pby, pbw, 8, 6)
        love.graphics.setColor(c2[1], c2[2], c2[3], 0.95)
        love.graphics.rectangle("fill", pbx, pby, pbw * progress, 8, 6)

        -- Etiqueta SHORT arriba a la izquierda
        love.graphics.setBlendMode("alpha")
        love.graphics.setFont(FontCache.get(11))
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.print("ANOMALY: " .. theme.label, 10, 9)

        -- Tiempo numérico arriba derecha
        local tstr2 = string.format("%.1fs", t)
        love.graphics.setFont(FontCache.get(11))
        local tw2 = FontCache.get(11):getWidth(tstr2)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.print(tstr2, 800 - tw2 - 10, 9)

        -- Nombre completo CENTRO ARRIBA
        love.graphics.setFont(FontCache.get(13))
        local nw = FontCache.get(13):getWidth(name)
        love.graphics.setColor(1, 1, 1, 0.95)
        love.graphics.print(name, 400 - nw / 2, 7)

        love.graphics.setBlendMode("add")

        -- ── RENDER ESPECÍFICO DE CADA ANOMALÍA (mantenido intacto) ──

        if id == "global_wormhole" then
            love.graphics.setLineWidth(2 + pulse * 2)
            love.graphics.setColor(0.9, 0.2, 1.0, 0.6 + pulse * 0.3)
            for r = 0, 10 do
                local line_y = 50 + 240 + (r * 24)
                love.graphics.line(320, line_y, 480, line_y)
            end
            love.graphics.setBlendMode("alpha")

        elseif id == "laser_scan" then
            love.graphics.setLineWidth(3 + pulse * 3)
            love.graphics.setColor(0.2, 0.95, 1.0, 0.85 + pulse * 0.15)
            love.graphics.line(AnomalyManager.laser_x, 40, AnomalyManager.laser_x, 540)
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.line(AnomalyManager.laser_x, 40, AnomalyManager.laser_x, 540)
            love.graphics.setBlendMode("alpha")

        elseif id == "gravity_flip" then
            love.graphics.setColor(0.8, 0.3, 1.0, 0.55 + pulse * 0.35)
            love.graphics.setFont(FontCache.get(14))
            local arrow_y = 260 + math.sin(time * 6) * 6
            love.graphics.printf("▲ ▲ ▲  ANTI-GRAV ACTIVE  ▲ ▲ ▲", 0, arrow_y, 800, "center")
            love.graphics.setBlendMode("alpha")

        elseif id == "lock_drain" then
            love.graphics.setColor(1.0, 0.35, 0.2, 0.7 + pulse * 0.3)
            love.graphics.setFont(FontCache.get(11))
            love.graphics.printf("⏱ LOCK DELAY = 0.08s OVERLOAD", 0, 560, 800, "center")
            for i = 1, 6 do
                local bar_y = 55 + (i * 72)
                love.graphics.rectangle("fill", 310, bar_y, 180, 2)
            end
            love.graphics.setBlendMode("alpha")

        elseif id == "hyper_speed" then
            love.graphics.setColor(0.2, 0.9, 1.0, 0.6 + pulse * 0.4)
            love.graphics.setLineWidth(2)
            local offset = (time * 600) % 60
            for i = -2, 16 do
                local bx = (i * 60) + offset
                love.graphics.line(bx, 50, bx + 80, 530)
            end
            love.graphics.setFont(FontCache.get(12))
            love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
            love.graphics.printf("⚡ HYPER SPEED RUN x2.6", 0, 30, 800, "center")
            love.graphics.setBlendMode("alpha")
        end
    end

    love.graphics.pop()
end

return AnomalyManager
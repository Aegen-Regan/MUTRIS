---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: ANOMALY MANAGER V2 (1280x720 WIDESCREEN)
-- ============================================================================
local AnomalyManager = {}
local FontCache = require "tetris.font_cache"
local AudioManager = require "audio_manager"
local Blackbox = require "core.blackbox"

AnomalyManager.current_anomaly = nil
AnomalyManager.timer = 0
AnomalyManager.duration = 0
AnomalyManager.warning_timer = 0
AnomalyManager.cooldown = 32.0
AnomalyManager.time_until_next = 20.0

AnomalyManager.step_timer = 0
AnomalyManager.laser_x = 220
AnomalyManager.laser_dir = 1
AnomalyManager.swapped = false
AnomalyManager.lock_drain_active = false
AnomalyManager.hyper_speed_active = false
AnomalyManager.blackout_flash = 0.0

ANOMALY_THEMES = {
    torus_belt       = { c1 = {0.55, 0.20, 1.0}, c2 = {0.80, 0.45, 1.0}, label = "TORUS" },
    global_wormhole  = { c1 = {0.95, 0.15, 0.85}, c2 = {1.00, 0.55, 0.90}, label = "WORM" },
    laser_scan       = { c1 = {0.15, 0.65, 1.0}, c2 = {0.45, 0.90, 1.0}, label = "LASER" },
    matrix_swap      = { c1 = {1.00, 0.08, 0.15}, c2 = {1.00, 0.55, 0.35}, label = "SWAP!" },
    gravity_flip     = { c1 = {0.85, 0.15, 0.25}, c2 = {0.95, 0.45, 0.75}, label = "ANTIG" },
    lock_drain       = { c1 = {1.00, 0.45, 0.05}, c2 = {1.00, 0.75, 0.20}, label = "DRAIN" },
    hyper_speed      = { c1 = {0.10, 0.85, 0.95}, c2 = {0.55, 1.00, 0.95}, label = "SPEED" },
    blackout_strobe  = { c1 = {0.05, 0.05, 0.12}, c2 = {0.20, 0.85, 1.00}, label = "ECLIPSE" }
}
DEFAULT_THEME = { c1 = {1.0, 0.85, 0.2}, c2 = {1.0, 1.0, 0.5}, label = "ANOM" }

local ANOMALY_POOL = {
    { id = "blackout_strobe", name = "ECLIPSE BLACKOUT (2-BAR STROBE)", dur = 12.0 },
    { id = "torus_belt",      name = "TORUS CONVEYOR (LOCAL)",         dur = 10.0 },
    { id = "global_wormhole", name = "GLOBAL WORMHOLE (CROSS-MATRIX)", dur = 10.0 },
    { id = "laser_scan",     name = "QUANTUM LASER SCANNER",          dur = 10.0 },
    { id = "matrix_swap",    name = "SUDDEN MATRIX SWAP",             dur =  3.0 },
    { id = "gravity_flip",   name = "ANTI-GRAVITY REVERSE",           dur = 10.0 },
    { id = "lock_drain",     name = "LOCK DRAIN OVERLOAD",             dur = 10.0 },
    { id = "hyper_speed",    name = "HYPER SPEED RUN BOOST",         dur = 12.0 }
}

function AnomalyManager.init()
    AnomalyManager.current_anomaly = nil
    AnomalyManager.timer = 0
    AnomalyManager.duration = 0
    AnomalyManager.warning_timer = 0
    AnomalyManager.time_until_next = (_G.IS_DEMO_MODE or _G.CURRENT_GAME_MODE == "gauntlet") and 8.0 or 25.0
    AnomalyManager.step_timer = 0
    AnomalyManager.laser_x = 220
    AnomalyManager.laser_dir = 1
    AnomalyManager.swapped = false
    AnomalyManager.lock_drain_active = false
    AnomalyManager.hyper_speed_active = false
    AnomalyManager.blackout_flash = 0.0
    _G.IsBlackoutActive = false
    _G.BlackoutStrobeVisibility = 1.0
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

    Blackbox.log("ANOMALY", "TRIGGER: " .. selected.name, idx, math.floor(selected.dur))

    if selected.id == "blackout_strobe" then
        _G.IsBlackoutActive = true
        AudioManager.playVoiceAnnounce("danger")
    else
        _G.IsBlackoutActive = false
    end

    AudioManager.playImmediateSFX("phantom_attack", false)
    AudioManager.triggerGlitch(0.35)
end

function AnomalyManager.update(dt, player, bot)
    local bpm = AudioManager.current_bpm or 120
    local beat_duration = 60 / bpm
    local two_bars_duration = beat_duration * 8

    if not AnomalyManager.current_anomaly then
        AnomalyManager.time_until_next = AnomalyManager.time_until_next - dt

        if AnomalyManager.time_until_next <= 2.5 and AnomalyManager.warning_timer <= 0 then
            AnomalyManager.warning_timer = 2.5
            AudioManager.triggerGlitch(0.20)
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

    if id == "blackout_strobe" then
        _G.IsBlackoutActive = true
        AnomalyManager.step_timer = (AnomalyManager.step_timer + dt) % two_bars_duration
        local strobe_fraction = AnomalyManager.step_timer / two_bars_duration
        
        if strobe_fraction < 0.12 then
            local flash_p = 1.0 - (strobe_fraction / 0.12)
            _G.BlackoutStrobeVisibility = flash_p * flash_p
        else
            _G.BlackoutStrobeVisibility = 0.0
        end

    elseif id == "torus_belt" then
        AnomalyManager.step_timer = AnomalyManager.step_timer + dt
        if AnomalyManager.step_timer >= (beat_duration * 1.2) then
            AnomalyManager.step_timer = 0
            if player and not player.is_dying then player:shiftColumnsLocal(1) end
            if bot and not bot.is_dying then bot:shiftColumnsLocal(1) end
            AudioManager.playImmediateSFX("move", false)
        end

    elseif id == "global_wormhole" then
        AnomalyManager.step_timer = AnomalyManager.step_timer + dt
        if AnomalyManager.step_timer >= (beat_duration * 0.7) then
            AnomalyManager.step_timer = 0
            if player and bot and not player.is_dying and not bot.is_dying then
                player:shiftColumnsGlobal(bot, 1)
            end
            AudioManager.playImmediateSFX("move", true)
        end

    elseif id == "laser_scan" then
        AnomalyManager.laser_x = AnomalyManager.laser_x + AnomalyManager.laser_dir * 300 * dt
        if AnomalyManager.laser_x > 1060 then
            AnomalyManager.laser_x = 1060
            AnomalyManager.laser_dir = -1
        elseif AnomalyManager.laser_x < 220 then
            AnomalyManager.laser_x = 220
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
        if AnomalyManager.step_timer >= (beat_duration * 0.4) then
            AnomalyManager.step_timer = 0
            if player and not player.is_dying then
                local pp = player.active_piece
                if pp and not pp.locked then
                    local steps = 0
                    while pp:canMove(pp.x, pp.y - 1, pp.rotation) do 
                        pp.y = pp.y - 1 
                        steps = steps + 1
                        if steps > 40 then break end
                    end
                end
            end
            if bot and not bot.is_dying then
                local bp = bot.active_piece
                if bp and not bp.locked then
                    local steps = 0
                    while bp:canMove(bp.x, bp.y - 1, bp.rotation) do 
                        bp.y = bp.y - 1 
                        steps = steps + 1
                        if steps > 40 then break end
                    end
                end
            end
            AudioManager.playImmediateSFX("rotate", false)
        end

    elseif id == "lock_drain" then
        AnomalyManager.lock_drain_active = true
        if player and player.active_piece and not player.is_dying then player.active_piece.lock_delay = 0.08 end
        if bot and bot.active_piece and not bot.is_dying then bot.active_piece.lock_delay = 0.08 end

    elseif id == "hyper_speed" then
        AnomalyManager.hyper_speed_active = true
        if player and not player.is_dying then
            local pp = player.active_piece
            if pp and not pp.locked then pp.spawn_timer = 0 end
        end
        if bot and bot.ai and not bot.is_dying then
            bot.ai.pps = bot.ai.base_pps + 3.0
        end
        AudioManager.playHatClosed(0.20)
    end

    if AnomalyManager.timer <= 0 then
        if AnomalyManager.lock_drain_active then
            if player and player.active_piece then player.active_piece.lock_delay = 0.5 end
            if bot and bot.active_piece then bot.active_piece.lock_delay = 0.5 end
        end
        AnomalyManager.lock_drain_active = false
        AnomalyManager.hyper_speed_active = false
        _G.IsBlackoutActive = false
        _G.BlackoutStrobeVisibility = 1.0

        AnomalyManager.current_anomaly = nil
        AnomalyManager.swapped = false
        AnomalyManager.time_until_next = (_G.IS_DEMO_MODE or _G.CURRENT_GAME_MODE == "gauntlet") and 9.0 or AnomalyManager.cooldown
        AnomalyManager.warning_timer = 0
        AudioManager.triggerGlitch(0.15)
    end
end

function AnomalyManager.draw(player, bot)
    love.graphics.push("all")
    local time = love.timer.getTime()
    local pulse = _G.AudioBeatPulse or 0

    if AnomalyManager.warning_timer > 0 and not AnomalyManager.current_anomaly then
        local wt = AnomalyManager.warning_timer
        local urgency = 1.0 - (wt / 2.5)
        local flash = 0.45 + math.sin(time * (16 + urgency * 32)) * 0.55
        local count_sec = math.max(0, math.ceil(wt))

        love.graphics.setBlendMode("add")
        local frame_w = 10 + pulse * 8
        love.graphics.setColor(1.0, 0.10, 0.12, flash * (0.65 + urgency * 0.35))
        love.graphics.rectangle("fill", 0, 0, 1280, frame_w)
        love.graphics.rectangle("fill", 0, 720 - frame_w, 1280, frame_w)
        love.graphics.rectangle("fill", 0, 0, frame_w, 720)
        love.graphics.rectangle("fill", 1280 - frame_w, 0, frame_w, 720)

        love.graphics.setBlendMode("alpha")
        local title_txt = "!  ANOMALY INCOMING  !"
        love.graphics.setFont(FontCache.get(22))
        local tw = FontCache.get(22):getWidth(title_txt)
        love.graphics.setColor(1.0, 1.0, 1.0, flash * (0.8 + urgency * 0.2))
        love.graphics.print(title_txt, 640 - tw / 2, 170)

        love.graphics.setFont(FontCache.get(64))
        local cstr = tostring(count_sec)
        local cw = FontCache.get(64):getWidth(cstr)
        love.graphics.setColor(1.0, 0.25, 0.2, 0.95)
        love.graphics.print(cstr, 640 - cw / 2, 240)
    end

    if AnomalyManager.current_anomaly then
        local id = AnomalyManager.current_anomaly
        local theme = ANOMALY_THEMES[id] or DEFAULT_THEME
        local c1, c2 = theme.c1, theme.c2
        local t = AnomalyManager.timer

        love.graphics.setBlendMode("add")
        local top_h = 36
        love.graphics.setColor(c1[1], c1[2], c1[3], 0.7 + pulse * 0.3)
        love.graphics.rectangle("fill", 0, 0, 1280, top_h)
        love.graphics.setColor(c2[1], c2[2], c2[3], 0.95)
        love.graphics.rectangle("fill", 0, top_h - 2, 1280, 2)

        love.graphics.setBlendMode("alpha")
        love.graphics.setFont(FontCache.get(12))
        love.graphics.setColor(1, 1, 1, 0.95)
        love.graphics.print("ANOMALY: " .. theme.label, 20, 10)

        local tstr2 = string.format("%.1fs", t)
        local tw2 = FontCache.get(12):getWidth(tstr2)
        love.graphics.print(tstr2, 1280 - tw2 - 20, 10)

        local name = "ACTIVE ANOMALY"
        for _, a in ipairs(ANOMALY_POOL) do
            if a.id == id then name = a.name break end
        end
        love.graphics.setFont(FontCache.get(13))
        local nw = FontCache.get(13):getWidth(name)
        love.graphics.print(name, 640 - nw / 2, 10)

        if id == "blackout_strobe" then
            love.graphics.setFont(FontCache.get(15))
            local vis_alpha = _G.BlackoutStrobeVisibility or 0
            love.graphics.setColor(0, 0.9, 1.0, 0.4 + vis_alpha * 0.6)
            love.graphics.printf("! 2-BAR STROBE ACTIVE !", 0, 660, 1280, "center")
        end
    end

    love.graphics.pop()
end

return AnomalyManager
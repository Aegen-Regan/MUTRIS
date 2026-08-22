-- ================================================================
-- FILE: combat/poise_system.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: BOSS POISE, HP & VISCERAL STUN SYSTEM (FASE 16)
-- Arquitectura: Zero-GC / Souls Posture Bar / Posture Decay / Clean ASCII
-- ============================================================================
local PoiseSystem = {}

local FontCache    = require "tetris.font_cache"
local AudioManager = require "audio_manager"
local BloomShader  = require "tetris.bloom_shader"
local ThemeManager = require "tetris.theme_manager"
local Blackbox     = require "core.blackbox"

PoiseSystem.boss_name = "ARCHON-LEVIATHAN [COLOSSUS]"
PoiseSystem.max_hp = 1000
PoiseSystem.hp = 1000
PoiseSystem.max_poise = 280
PoiseSystem.poise = 0

PoiseSystem.is_stunned = false
PoiseSystem.stun_timer = 0.0
PoiseSystem.stun_duration = 6.0

PoiseSystem.is_enraged = false
PoiseSystem.rage_threshold = 0.50
PoiseSystem.rage_flash = 0.0

PoiseSystem.poise_decay_timer = 0.0
PoiseSystem.visceral_flash = 0.0

function PoiseSystem.init()
    PoiseSystem.max_hp = 1000
    PoiseSystem.hp = 1000
    PoiseSystem.max_poise = 280
    PoiseSystem.poise = 0
    PoiseSystem.is_stunned = false
    PoiseSystem.stun_timer = 0.0
    PoiseSystem.is_enraged = false
    PoiseSystem.rage_flash = 0.0
    PoiseSystem.visceral_flash = 0.0
    PoiseSystem.poise_decay_timer = 0.0
end

function PoiseSystem.dealDamage(damage, is_critical)
    if PoiseSystem.hp <= 0 then return 0 end

    local PartBreaking = require "combat.part_breaking"

    local raw_dmg = damage
    if not PartBreaking.parts.core.broken then
        raw_dmg = raw_dmg * 0.75
    end

    local mult = PoiseSystem.is_stunned and 2.5 or 1.0
    if is_critical then mult = mult * 1.35 end

    local final_damage = math.floor(raw_dmg * mult)
    PoiseSystem.hp = math.max(0, PoiseSystem.hp - final_damage)
    PoiseSystem.poise_decay_timer = 3.5

    if PoiseSystem.is_stunned then
        PoiseSystem.visceral_flash = 1.0
        _G.HitStopTimer = 0.12
        AudioManager.playImmediateSFX("tetris", false)
        AudioManager.playSubBassThud(3)
        Blackbox.log("VISCERAL", "2.5x VISCERAL STRIKE", final_damage, PoiseSystem.hp)
    end

    if (PoiseSystem.hp / PoiseSystem.max_hp) <= PoiseSystem.rage_threshold and not PoiseSystem.is_enraged then
        PoiseSystem.is_enraged = true
        PoiseSystem.rage_flash = 1.0
        AudioManager.playVoiceAnnounce("danger")
        AudioManager.playImmediateSFX("death", true)
        BloomShader.triggerShockwave(640, 360)
        Blackbox.log("BOSS_RAGE", "ARCHON-LEVIATHAN ENRAGED", PoiseSystem.hp, 0)
    end

    if not PoiseSystem.is_stunned then
        local poise_dmg = math.max(12, math.floor(damage * 0.40))
        PoiseSystem.addPoise(poise_dmg)
    end

    return final_damage
end

function PoiseSystem.addPoise(amount)
    if PoiseSystem.is_stunned then return end
    PoiseSystem.poise = math.min(PoiseSystem.max_poise, PoiseSystem.poise + amount)

    if PoiseSystem.poise >= PoiseSystem.max_poise then
        PoiseSystem.triggerStun()
    end
end

function PoiseSystem.triggerStun()
    PoiseSystem.is_stunned = true
    PoiseSystem.stun_timer = PoiseSystem.stun_duration
    PoiseSystem.poise = 0
    _G.HitStopTimer = 0.35
    
    AudioManager.playImmediateSFX("ultimatris", false)
    AudioManager.playSubBassThud(4)
    BloomShader.triggerShockwave(640, 180)

    Blackbox.log("POISE_BREAK", "BOSS POSTURE COLLAPSED", 0, 0)
end

function PoiseSystem.update(dt)
    if PoiseSystem.is_stunned then
        PoiseSystem.stun_timer = math.max(0, PoiseSystem.stun_timer - dt)
        if PoiseSystem.stun_timer <= 0 then
            PoiseSystem.is_stunned = false
            PoiseSystem.poise = 0
            Blackbox.log("POISE_RECOVER", "BOSS RECOVERED POSTURE", 0, 0)
        end
    else
        if PoiseSystem.poise_decay_timer > 0 then
            PoiseSystem.poise_decay_timer = math.max(0, PoiseSystem.poise_decay_timer - dt)
        elseif PoiseSystem.poise > 0 then
            PoiseSystem.poise = math.max(0, PoiseSystem.poise - 25.0 * dt)
        end
    end

    if PoiseSystem.visceral_flash > 0 then
        PoiseSystem.visceral_flash = math.max(0, PoiseSystem.visceral_flash - dt * 3.5)
    end

    if PoiseSystem.rage_flash > 0 then
        PoiseSystem.rage_flash = math.max(0, PoiseSystem.rage_flash - dt * 2.0)
    end
end

function PoiseSystem.drawHUD()
    if _G.CURRENT_GAME_MODE ~= "boss_hunt" then return end

    local t = ThemeManager.getCurrent()
    local pulse = _G.AudioBeatPulse or 0
    local time = love.timer.getTime()

    love.graphics.push("all")

    local bx, by, bw, bh = 420, 30, 440, 56
    ThemeManager.drawPanel(bx, by, bw, bh, "", PoiseSystem.is_enraged, PoiseSystem.is_enraged and {1.0, 0.1, 0.25})

    love.graphics.setFont(FontCache.get(10))
    if PoiseSystem.is_stunned then
        local flash = math.sin(time * 18) * 0.5 + 0.5
        love.graphics.setColor(1.0, 0.85, 0.0, 0.95 + flash * 0.05)
        love.graphics.printf("/// POSTURE BROKEN // 2.5x VISCERAL STUN ///", bx, by + 6, bw, "center")
    elseif PoiseSystem.is_enraged then
        local flash = math.sin(time * 16) * 0.5 + 0.5
        love.graphics.setColor(1.0, 0.15, 0.25, 0.95 + flash * 0.05)
        love.graphics.printf("! ENRAGED OVERDRIVE // SPEED & ATK UP !", bx, by + 6, bw, "center")
    else
        love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.95)
        love.graphics.printf(PoiseSystem.boss_name, bx, by + 6, bw, "center")
    end

    local hp_pct = math.max(0, math.min(1, PoiseSystem.hp / PoiseSystem.max_hp))
    local bar_x, bar_y, bar_w, bar_h = bx + 16, by + 22, bw - 32, 12
    love.graphics.setColor(0.03, 0.05, 0.09, 0.95)
    love.graphics.rectangle("fill", bar_x, bar_y, bar_w, bar_h, 2)

    love.graphics.setColor(PoiseSystem.is_enraged and {1.0, 0.15, 0.25, 0.95} or {0.1, 0.95, 0.5, 0.95})
    love.graphics.rectangle("fill", bar_x, bar_y, bar_w * hp_pct, bar_h, 2)
    love.graphics.setColor(t.border)
    love.graphics.rectangle("line", bar_x, bar_y, bar_w, bar_h, 2)

    love.graphics.setFont(FontCache.get(8))
    love.graphics.setColor(1, 1, 1, 0.90)
    love.graphics.printf(string.format("%d / %d HP", PoiseSystem.hp, PoiseSystem.max_hp), bar_x, bar_y + 1, bar_w, "center")

    local poise_pct = PoiseSystem.is_stunned and (PoiseSystem.stun_timer / PoiseSystem.stun_duration) or (PoiseSystem.poise / PoiseSystem.max_poise)
    local pbar_y = by + 38
    love.graphics.setColor(0.03, 0.05, 0.09, 0.95)
    love.graphics.rectangle("fill", bar_x, pbar_y, bar_w, 7, 1)

    if PoiseSystem.is_stunned then
        love.graphics.setColor(1.0, 0.85, 0.0, 0.95)
        love.graphics.rectangle("fill", bar_x, pbar_y, bar_w * poise_pct, 7, 1)
    else
        love.graphics.setColor(1.0, 0.65, 0.1, 0.85)
        love.graphics.rectangle("fill", bar_x, pbar_y, bar_w * poise_pct, 7, 1)
    end
    love.graphics.setColor(1, 1, 1, 0.25)
    love.graphics.rectangle("line", bar_x, pbar_y, bar_w, 7, 1)

    if PoiseSystem.visceral_flash > 0 then
        love.graphics.setBlendMode("add")
        love.graphics.setColor(1.0, 0.85, 0.0, PoiseSystem.visceral_flash * 0.35)
        love.graphics.rectangle("fill", 0, 0, 1280, 720)
        love.graphics.setBlendMode("alpha")
    end

    love.graphics.pop()
end

return PoiseSystem
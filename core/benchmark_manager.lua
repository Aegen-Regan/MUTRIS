-- ================================================================
-- FILE: core/benchmark_manager.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: PILOT BENCHMARK & PLACEMENT ENGINE (FASE 12 & 13)
-- Arquitectura: Zero-GC / Interactive Briefings / Auto-Tuning Persistence
-- ============================================================================
local BenchmarkManager = {}

local FontCache       = require "tetris.font_cache"
local SettingsManager = require "settings_manager"
local AudioManager    = require "audio_manager"
local BloomShader     = require "tetris.bloom_shader"
local ThemeManager    = require "tetris.theme_manager"
local MetaBalancer    = require "core.meta_balancer"
local AIBot           = require "tetris.ai_bot"
local Blackbox        = require "core.blackbox"

BenchmarkManager.STAGE_1_BRIEFING = 1
BenchmarkManager.STAGE_1_PLAY     = 2
BenchmarkManager.STAGE_2_BRIEFING = 3
BenchmarkManager.STAGE_2_PLAY     = 4
BenchmarkManager.STAGE_3_BRIEFING = 5
BenchmarkManager.STAGE_3_PLAY     = 6
BenchmarkManager.STAGE_RESULT     = 7

BenchmarkManager.state = 1
BenchmarkManager.stage_timer = 0.0
BenchmarkManager.is_active = false

-- Métricas Etapa 1 (Sprint)
BenchmarkManager.sprint_lines_target = 20
BenchmarkManager.sprint_lines_cleared = 0
BenchmarkManager.sprint_time = 0.0
BenchmarkManager.sprint_pps = 0.0

-- Métricas Etapa 2 (Duelo)
BenchmarkManager.duel_duration = 35.0
BenchmarkManager.duel_parries = 0
BenchmarkManager.duel_lines_sent = 0
BenchmarkManager.duel_pps = 0.0

-- Métricas Etapa 3 (Presión)
BenchmarkManager.pressure_duration = 25.0
BenchmarkManager.pressure_survived_time = 0.0
BenchmarkManager.pressure_clears = 0

-- Resultado Final CPR
BenchmarkManager.cpr_score = 0
BenchmarkManager.tier_name = "UNRANKED"
BenchmarkManager.tier_desc = ""
BenchmarkManager.tier_color = {1, 1, 1}

local function serializeJSON(t)
    local s = "{\n"
    for k, v in pairs(t) do
        if type(v) == "number" then
            s = s .. string.format('  "%s": %.4f,\n', k, v)
        elseif type(v) == "string" then
            s = s .. string.format('  "%s": "%s",\n', k, v)
        end
    end
    s = s:sub(1, -3) .. "\n}"
    return s
end

function BenchmarkManager.init()
    BenchmarkManager.state = BenchmarkManager.STAGE_1_BRIEFING
    BenchmarkManager.stage_timer = 0.0
    BenchmarkManager.is_active = true

    BenchmarkManager.sprint_lines_cleared = 0
    BenchmarkManager.sprint_time = 0.0
    BenchmarkManager.sprint_pps = 0.0

    BenchmarkManager.duel_parries = 0
    BenchmarkManager.duel_lines_sent = 0
    BenchmarkManager.duel_pps = 0.0

    BenchmarkManager.pressure_survived_time = 0.0
    BenchmarkManager.pressure_clears = 0

    BenchmarkManager.cpr_score = 0
    BenchmarkManager.tier_name = "UNRANKED"

    Blackbox.log("BENCHMARK", "PILOT BENCHMARK TRIAL INITIALIZED", 1, 0)
end

function BenchmarkManager.isWaitingBriefing()
    return BenchmarkManager.state == BenchmarkManager.STAGE_1_BRIEFING
        or BenchmarkManager.state == BenchmarkManager.STAGE_2_BRIEFING
        or BenchmarkManager.state == BenchmarkManager.STAGE_3_BRIEFING
        or BenchmarkManager.state == BenchmarkManager.STAGE_RESULT
end

function BenchmarkManager.advanceFromBriefing()
    if BenchmarkManager.state == BenchmarkManager.STAGE_1_BRIEFING then
        BenchmarkManager.state = BenchmarkManager.STAGE_1_PLAY
        BenchmarkManager.stage_timer = 0.0
        BenchmarkManager.sprint_lines_cleared = 0
        if _G.BenchmarkResetBoards then _G.BenchmarkResetBoards() end
        AudioManager.playImmediateSFX("rotate", false)

    elseif BenchmarkManager.state == BenchmarkManager.STAGE_2_BRIEFING then
        BenchmarkManager.state = BenchmarkManager.STAGE_2_PLAY
        BenchmarkManager.stage_timer = 0.0
        BenchmarkManager.duel_parries = 0
        BenchmarkManager.duel_lines_sent = 0
        if _G.BenchmarkResetBoards then _G.BenchmarkResetBoards() end
        AudioManager.playImmediateSFX("rotate", false)

    elseif BenchmarkManager.state == BenchmarkManager.STAGE_3_BRIEFING then
        BenchmarkManager.state = BenchmarkManager.STAGE_3_PLAY
        BenchmarkManager.stage_timer = 0.0
        BenchmarkManager.pressure_survived_time = 0.0
        BenchmarkManager.pressure_clears = 0
        if _G.BenchmarkResetBoards then _G.BenchmarkResetBoards() end
        AudioManager.playImmediateSFX("rotate", false)

    elseif BenchmarkManager.state == BenchmarkManager.STAGE_RESULT then
        _G.SetGameState("menu")
    end
end

function BenchmarkManager.registerPlayerLineClear(lines_count, is_tspin)
    if not BenchmarkManager.is_active or lines_count <= 0 then return end

    if BenchmarkManager.state == BenchmarkManager.STAGE_1_PLAY then
        BenchmarkManager.sprint_lines_cleared = BenchmarkManager.sprint_lines_cleared + lines_count
    elseif BenchmarkManager.state == BenchmarkManager.STAGE_2_PLAY then
        BenchmarkManager.duel_lines_sent = BenchmarkManager.duel_lines_sent + lines_count
    elseif BenchmarkManager.state == BenchmarkManager.STAGE_3_PLAY then
        BenchmarkManager.pressure_clears = BenchmarkManager.pressure_clears + lines_count
    end
end

function BenchmarkManager.registerParry()
    if BenchmarkManager.is_active and BenchmarkManager.state == BenchmarkManager.STAGE_2_PLAY then
        BenchmarkManager.duel_parries = BenchmarkManager.duel_parries + 1
    end
end

function BenchmarkManager.update(dt, player_board, bot_board)
    if not BenchmarkManager.is_active or BenchmarkManager.isWaitingBriefing() then return end

    BenchmarkManager.stage_timer = BenchmarkManager.stage_timer + dt

    -- ────────────────────────────────────────────────────────────────────────
    -- ETAPA 1 EN JUEGO: KINETIC SPRINT (20 Líneas)
    -- ────────────────────────────────────────────────────────────────────────
    if BenchmarkManager.state == BenchmarkManager.STAGE_1_PLAY then
        if BenchmarkManager.sprint_lines_cleared >= BenchmarkManager.sprint_lines_target then
            BenchmarkManager.sprint_time = math.max(0.5, BenchmarkManager.stage_timer)
            BenchmarkManager.sprint_pps = (player_board and player_board.current_pps_display and player_board.current_pps_display > 0.3)
                                          and player_board.current_pps_display
                                          or (20.0 / BenchmarkManager.sprint_time)

            BenchmarkManager.state = BenchmarkManager.STAGE_2_BRIEFING
            _G.HitStopTimer = 0.30
            AudioManager.playImmediateSFX("tetris", false)
            AudioManager.playSubBassThud(3)
            BloomShader.triggerShockwave(640, 360)
            Blackbox.log("BENCHMARK", "STAGE 1 SPRINT COMPLETE", math.floor(BenchmarkManager.sprint_pps * 10), math.floor(BenchmarkManager.sprint_time))
        end

    -- ────────────────────────────────────────────────────────────────────────
    -- ETAPA 2 EN JUEGO: DUELO TÁCTICO (35s)
    -- ────────────────────────────────────────────────────────────────────────
    elseif BenchmarkManager.state == BenchmarkManager.STAGE_2_PLAY then
        if BenchmarkManager.stage_timer >= BenchmarkManager.duel_duration or (bot_board and bot_board.is_dying) then
            BenchmarkManager.duel_pps = (player_board and player_board.current_pps_display and player_board.current_pps_display > 0.3)
                                       and player_board.current_pps_display
                                       or BenchmarkManager.sprint_pps

            BenchmarkManager.state = BenchmarkManager.STAGE_3_BRIEFING
            _G.HitStopTimer = 0.30
            AudioManager.playImmediateSFX("ultimatris", false)
            AudioManager.playSubBassThud(4)
            BloomShader.triggerShockwave(640, 360)
            Blackbox.log("BENCHMARK", "STAGE 2 DUEL COMPLETE", math.floor(BenchmarkManager.duel_pps * 10), BenchmarkManager.duel_parries)
        end

    -- ────────────────────────────────────────────────────────────────────────
    -- ETAPA 3 EN JUEGO: TITAN PRESSURE (25s)
    -- ────────────────────────────────────────────────────────────────────────
    elseif BenchmarkManager.state == BenchmarkManager.STAGE_3_PLAY then
        BenchmarkManager.pressure_survived_time = BenchmarkManager.stage_timer

        -- Inyección periódica de 2 líneas de basura cada 4 segundos
        if (math.floor(BenchmarkManager.stage_timer) % 4 == 0) and (BenchmarkManager.stage_timer - math.floor(BenchmarkManager.stage_timer) < dt) then
            if player_board and not player_board.is_dying then
                local GarbageManager = require "tetris.garbage_manager"
                GarbageManager.sendGarbage(bot_board, player_board, 2)
            end
        end

        if BenchmarkManager.stage_timer >= BenchmarkManager.pressure_duration or (player_board and player_board.is_dying) then
            BenchmarkManager.finishBenchmark(player_board)
        end
    end
end

-- ============================================================================
-- 🧠 CÁLCULO DE RATING CPR & AUTO-CALIBRACIÓN EN DISCO
-- ============================================================================
function BenchmarkManager.finishBenchmark(player_board)
    BenchmarkManager.state = BenchmarkManager.STAGE_RESULT
    BenchmarkManager.is_active = false

    local p1_pps = math.max(0.6, math.max(BenchmarkManager.sprint_pps, BenchmarkManager.duel_pps))
    local surv_ratio = math.min(1.0, BenchmarkManager.pressure_survived_time / BenchmarkManager.pressure_duration)

    BenchmarkManager.cpr_score = math.floor((p1_pps * 650) + (BenchmarkManager.duel_parries * 60) + (surv_ratio * 450) + (BenchmarkManager.pressure_clears * 25))

    local target_bot_pps = 1.45
    local parry_frames = 3
    local beat_window = 0.035
    local defense_mult = 0.50

    if BenchmarkManager.cpr_score >= 1700 or p1_pps >= 2.10 then
        BenchmarkManager.tier_name = "APEX PILOT [TIER S+]"
        BenchmarkManager.tier_desc = "MAXIMUM REFLEXES // TOURNAMENT HARDCORE APPLIED"
        BenchmarkManager.tier_color = {1.0, 0.85, 0.0}
        target_bot_pps = math.min(3.8, p1_pps * 1.15)
        parry_frames = 3
        beat_window = 0.030
        defense_mult = 0.55

    elseif BenchmarkManager.cpr_score >= 1300 or p1_pps >= 1.55 then
        BenchmarkManager.tier_name = "ELITE PILOT [TIER A]"
        BenchmarkManager.tier_desc = "ADVANCED HANDLING // AGGRESSIVE DDA TUNING"
        BenchmarkManager.tier_color = {0.1, 0.95, 0.5}
        target_bot_pps = math.min(2.8, p1_pps * 1.12)
        parry_frames = 3
        beat_window = 0.035
        defense_mult = 0.50

    elseif BenchmarkManager.cpr_score >= 950 or p1_pps >= 1.10 then
        BenchmarkManager.tier_name = "VETERAN PILOT [TIER B]"
        BenchmarkManager.tier_desc = "SOLID FOUNDATION // BALANCED COMPETITIVE DDA"
        BenchmarkManager.tier_color = {0.0, 0.90, 1.0}
        target_bot_pps = math.min(2.0, p1_pps * 1.08)
        parry_frames = 4
        beat_window = 0.040
        defense_mult = 0.45

    else
        BenchmarkManager.tier_name = "CADET PILOT [TIER C]"
        BenchmarkManager.tier_desc = "ASSISTED DEFENSE // EXTENDED PARRY & FORGIVING PACING"
        BenchmarkManager.tier_color = {0.6, 0.6, 0.7}
        target_bot_pps = math.max(0.9, p1_pps * 1.05)
        parry_frames = 5
        beat_window = 0.045
        defense_mult = 0.40
    end

    -- Persistencia atómica en disco
    _G.AI_ADAPTIVE_PROFILE.player_avg_pps = p1_pps
    _G.AI_ADAPTIVE_PROFILE.ai_target_pps  = target_bot_pps
    AIBot.saveProfile()

    SettingsManager.settings.bot_target_pps = target_bot_pps
    SettingsManager.settings.parry_window   = parry_frames
    SettingsManager.settings.beat_window    = beat_window
    SettingsManager.save()

    MetaBalancer.balance.beat_window_ms      = beat_window
    MetaBalancer.balance.parry_window_frames = parry_frames
    MetaBalancer.balance.bastion_intake_mult = defense_mult
    MetaBalancer.patch_notes = string.format("BENCHMARK APPLIED: %s (AI %.2f PPS)", BenchmarkManager.tier_name, target_bot_pps)
    MetaBalancer.save()

    if not love.filesystem.getInfo("saves") then love.filesystem.createDirectory("saves") end
    local report = {
        tier_name = BenchmarkManager.tier_name,
        cpr_score = BenchmarkManager.cpr_score,
        measured_pps = p1_pps,
        calibrated_bot_pps = target_bot_pps,
        timestamp = os.date("%Y-%m-%d %H:%M:%S")
    }
    love.filesystem.write("saves/pilot_profile.json", serializeJSON(report))

    AudioManager.playImmediateSFX("ultimatris", false)
    AudioManager.playSubBassThud(4)
    BloomShader.triggerShockwave(640, 360)

    Blackbox.log("BENCHMARK_END", BenchmarkManager.tier_name, BenchmarkManager.cpr_score, math.floor(target_bot_pps * 10))
end

-- ============================================================================
-- 🎨 RENDERIZADO DE HUD DE ETAPA & MODALES INTERACTIVOS DE BRIEFING
-- ============================================================================
function BenchmarkManager.drawHUD()
    if not BenchmarkManager.is_active and BenchmarkManager.state ~= BenchmarkManager.STAGE_RESULT then return end

    local t = ThemeManager.getCurrent()
    local pulse = _G.AudioBeatPulse or 0
    love.graphics.push("all")

    -- 1. Barra Superior durante el juego
    if not BenchmarkManager.isWaitingBriefing() then
        local bx, by, bw, bh = 420, 28, 440, 48
        ThemeManager.drawPanel(bx, by, bw, bh, "", true)

        love.graphics.setFont(FontCache.get(10))
        love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.95)

        if BenchmarkManager.state == BenchmarkManager.STAGE_1_PLAY then
            love.graphics.printf("/// STAGE 1/3: KINETIC SPRINT ///", bx, by + 6, bw, "center")
            love.graphics.setFont(FontCache.get(12))
            love.graphics.setColor(1, 1, 1, 0.95)
            local count_text = string.format("LINES: %d / %d  |  TIME: %.1fs", BenchmarkManager.sprint_lines_cleared, BenchmarkManager.sprint_lines_target, BenchmarkManager.stage_timer)
            love.graphics.printf(count_text, bx, by + 22, bw, "center")

        elseif BenchmarkManager.state == BenchmarkManager.STAGE_2_PLAY then
            love.graphics.printf("/// STAGE 2/3: TACTICAL DUEL ///", bx, by + 6, bw, "center")
            love.graphics.setFont(FontCache.get(12))
            love.graphics.setColor(1, 1, 1, 0.95)
            local rem_time = math.max(0, BenchmarkManager.duel_duration - BenchmarkManager.stage_timer)
            local duel_text = string.format("REMAINING: %.1fs  |  PARRIES: %d", rem_time, BenchmarkManager.duel_parries)
            love.graphics.printf(duel_text, bx, by + 22, bw, "center")

        elseif BenchmarkManager.state == BenchmarkManager.STAGE_3_PLAY then
            love.graphics.setColor(1.0, 0.15, 0.25, 0.95 + pulse * 0.05)
            love.graphics.printf("! STAGE 3/3: TITAN PRESSURE TEST !", bx, by + 6, bw, "center")
            love.graphics.setFont(FontCache.get(12))
            love.graphics.setColor(1, 1, 1, 0.95)
            local rem_time = math.max(0, BenchmarkManager.pressure_duration - BenchmarkManager.stage_timer)
            local press_text = string.format("SURVIVE SPIKES: %.1fs  |  CLEARS: %d", rem_time, BenchmarkManager.pressure_clears)
            love.graphics.printf(press_text, bx, by + 22, bw, "center")
        end
    end

    -- 2. Modales de Briefing Explicativo
    if BenchmarkManager.isWaitingBriefing() then
        local cx, cy = 640, 360
        local mw, mh = 560, 320
        local mx, my = cx - mw/2, cy - mh/2

        -- Telón oscuro
        love.graphics.setColor(0.0, 0.0, 0.0, 0.88)
        love.graphics.rectangle("fill", 0, 0, 1280, 720)

        love.graphics.setColor(0.01, 0.015, 0.03, 1.0)
        love.graphics.rectangle("fill", mx, my, mw, mh, 8)
        love.graphics.setLineWidth(2.5)
        love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.98)
        love.graphics.rectangle("line", mx, my, mw, mh, 8)

        if BenchmarkManager.state == BenchmarkManager.STAGE_1_BRIEFING then
            love.graphics.setFont(FontCache.get(20))
            love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 1.0)
            love.graphics.printf("STAGE 1/3: KINETIC SPRINT", mx, my + 24, mw, "center")

            love.graphics.setFont(FontCache.get(11))
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.printf("OBJECTIVE: CLEAR 20 LINES AS FAST AS POSSIBLE", mx, my + 70, mw, "center")

            love.graphics.setFont(FontCache.get(9))
            love.graphics.setColor(0.7, 0.8, 0.9, 0.85)
            love.graphics.printf("• EVALUATES: RAW PPS, DAS/ARR HANDLING & PIECE PLACEMENT\n• NO GARBAGE WILL BE SENT DURING THIS STAGE\n• FOCUS ON CONTINUOUS HARD DROPS", mx + 30, my + 115, mw - 60, "center")

            love.graphics.setFont(FontCache.get(12))
            love.graphics.setColor(1.0, 0.95, 0.4, 0.95)
            love.graphics.printf("PRESS [ENTER] OR [SPACE] TO START SPRINT", mx, my + mh - 44, mw, "center")

        elseif BenchmarkManager.state == BenchmarkManager.STAGE_2_BRIEFING then
            love.graphics.setFont(FontCache.get(20))
            love.graphics.setColor(t.secondary[1], t.secondary[2], t.secondary[3], 1.0)
            love.graphics.printf("STAGE 2/3: TACTICAL DUEL", mx, my + 20, mw, "center")

            love.graphics.setFont(FontCache.get(10))
            love.graphics.setColor(1.0, 0.85, 0.0, 0.95)
            local p1_str = string.format("STAGE 1 RESULT: 20 LINES IN %.1fs (%.2f PPS)", BenchmarkManager.sprint_time, BenchmarkManager.sprint_pps)
            love.graphics.printf(p1_str, mx, my + 56, mw, "center")

            love.graphics.setFont(FontCache.get(11))
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.printf("OBJECTIVE: COMBAT DDA BOT & EXECUTE PARRIES (35s)", mx, my + 90, mw, "center")

            love.graphics.setFont(FontCache.get(9))
            love.graphics.setColor(0.7, 0.8, 0.9, 0.85)
            love.graphics.printf("• EVALUATES: DOWNSTACK SURVIVAL, APM & KINETIC PARRIES\n• CANCEL INCOMING GARBAGE OR DEVOUR WITH BASTION STANCE\n• BOARDS WILL RESET CLEANLY", mx + 30, my + 130, mw - 60, "center")

            love.graphics.setFont(FontCache.get(12))
            love.graphics.setColor(1.0, 0.95, 0.4, 0.95)
            love.graphics.printf("PRESS [ENTER] OR [SPACE] TO ENGAGE DUEL", mx, my + mh - 44, mw, "center")

        elseif BenchmarkManager.state == BenchmarkManager.STAGE_3_BRIEFING then
            love.graphics.setFont(FontCache.get(20))
            love.graphics.setColor(1.0, 0.15, 0.25, 1.0)
            love.graphics.printf("STAGE 3/3: TITAN PRESSURE TEST", mx, my + 20, mw, "center")

            love.graphics.setFont(FontCache.get(10))
            love.graphics.setColor(1.0, 0.85, 0.0, 0.95)
            local p2_str = string.format("STAGE 2 RESULT: %.2f DUEL PPS | %d PARRIES", BenchmarkManager.duel_pps, BenchmarkManager.duel_parries)
            love.graphics.printf(p2_str, mx, my + 56, mw, "center")

            love.graphics.setFont(FontCache.get(11))
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.printf("OBJECTIVE: SURVIVE 25s UNDER CONTINUOUS GARBAGE SPIKES", mx, my + 90, mw, "center")

            love.graphics.setFont(FontCache.get(9))
            love.graphics.setColor(0.7, 0.8, 0.9, 0.85)
            love.graphics.printf("• EVALUATES: RECOVERY UNDER PRESSURE & CEILING AVOIDANCE\n• 2 SOLID GARBAGE LINES INJECTED EVERY 4 SECONDS\n• DO NOT TOP-OUT", mx + 30, my + 130, mw - 60, "center")

            love.graphics.setFont(FontCache.get(12))
            love.graphics.setColor(1.0, 0.95, 0.4, 0.95)
            love.graphics.printf("PRESS [ENTER] OR [SPACE] TO SURVIVE", mx, my + mh - 44, mw, "center")

        elseif BenchmarkManager.state == BenchmarkManager.STAGE_RESULT then
            BenchmarkManager.drawResultModal()
        end
    end

    love.graphics.pop()
end

function BenchmarkManager.drawResultModal()
    local t = ThemeManager.getCurrent()
    local cx, cy = 640, 360
    local card_w, card_h = 560, 340
    local px, py = cx - card_w/2, cy - card_h/2

    love.graphics.push("all")
    love.graphics.setColor(0.0, 0.0, 0.0, 0.88)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    love.graphics.setColor(0.01, 0.015, 0.03, 1.0)
    love.graphics.rectangle("fill", px, py, card_w, card_h, 8)
    love.graphics.setLineWidth(2.5)
    love.graphics.setColor(BenchmarkManager.tier_color[1], BenchmarkManager.tier_color[2], BenchmarkManager.tier_color[3], 0.98)
    love.graphics.rectangle("line", px, py, card_w, card_h, 8)

    love.graphics.setFont(FontCache.get(22))
    love.graphics.setColor(BenchmarkManager.tier_color[1], BenchmarkManager.tier_color[2], BenchmarkManager.tier_color[3], 1.0)
    love.graphics.printf(BenchmarkManager.tier_name, px, py + 22, card_w, "center")

    love.graphics.setFont(FontCache.get(10))
    love.graphics.setColor(1, 1, 1, 0.75)
    love.graphics.printf(BenchmarkManager.tier_desc, px, py + 52, card_w, "center")

    local stat_y = py + 95
    love.graphics.setFont(FontCache.get(12))
    love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.95)
    love.graphics.printf(string.format("CPR COMBAT RATING: %d PTS", BenchmarkManager.cpr_score), px, stat_y, card_w, "center")

    love.graphics.setFont(FontCache.get(10))
    love.graphics.setColor(0.8, 0.85, 0.95, 0.85)
    love.graphics.printf(string.format("SPRINT PPS: %.2f  |  DUEL PPS: %.2f  |  PARRIES: %d", BenchmarkManager.sprint_pps, BenchmarkManager.duel_pps, BenchmarkManager.duel_parries), px, stat_y + 30, card_w, "center")
    
    local target_pps = (_G.AI_ADAPTIVE_PROFILE and _G.AI_ADAPTIVE_PROFILE.ai_target_pps) or 1.45
    love.graphics.setColor(0.1, 1.0, 0.55, 0.95)
    love.graphics.printf(string.format("AUTO-CALIBRATED BOT SPEED: %.2f PPS (DIFFICULTY APPLIED)", target_pps), px, stat_y + 60, card_w, "center")

    love.graphics.setColor(t.secondary[1], t.secondary[2], t.secondary[3], 0.85)
    love.graphics.printf("ALL FUTURE MODES, DUELS & BOSSES SYNCED TO YOUR SKILL", px, stat_y + 85, card_w, "center")

    love.graphics.setFont(FontCache.get(12))
    love.graphics.setColor(1.0, 0.95, 0.4, 0.95)
    love.graphics.printf("PRESS [ENTER] OR [ESC] TO ENGAGE GAME MODES", px, py + card_h - 38, card_w, "center")

    love.graphics.pop()
end

return BenchmarkManager
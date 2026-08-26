-- ================================================================
-- FILE: tetris/telemetry.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: CENTRAL TELEMETRY CARD & MULTI-BOT DASHBOARD (1280x720)
-- Zero-GC / Dynamic Horizontal Centering / Pre-allocated String Buffers
-- ============================================================================
local Telemetry = {}
local FontCache    = require "tetris.font_cache"
local ThemeManager = require "tetris.theme_manager"

-- BÚFER ESTÁTICO DE TEXTO (Pre-asignación completa para aniquilar string.format)
local STR_CACHE = {
    time_str = "TIME: 000.0s",
    fps_str  = "000 FPS",
    p1_str   = "P1:  0.00 PPS",
    bot_str  = "BOT: 0.00 PPS",
    target_str = "AI TARGET: 0.00 PPS",
    record_str = "RECORD: 0-0 (AVG P1: 0.00)",
    last_time = -1,
    last_fps  = -1,
    last_p1   = -1,
    last_bot  = -1,
    last_target = -1
}

function Telemetry.draw(player, bot, center_x, is_boss_mode)
    love.graphics.push("all")
    local t = ThemeManager.getCurrent()
    local energy = _G.TrackEnergyPunch or 0
    local pw, ph = is_boss_mode and 260 or 300, 115
    local cx = center_x or 640
    local px = cx - (pw / 2)
    local py = 485
    
    ThemeManager.drawPanel(px, py, pw, ph, "", false)

    love.graphics.setFont(FontCache.get(10))
    love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.95)
    love.graphics.print(_G.ENGINE_VERSION or "MUTRIS v1.0.0", px + 8, py + 8)

    -- OPTIMIZACIÓN DE TIEMPO (Solo actualiza la string si cambió el décimo de segundo)
    local cur_time = _G.RealMatchTimer or 0
    if math.abs(cur_time - STR_CACHE.last_time) >= 0.1 then
        STR_CACHE.time_str = string.format("TIME: %05.1fs", cur_time)
        STR_CACHE.last_time = cur_time
    end
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.print(STR_CACHE.time_str, px + (is_boss_mode and 130 or 155), py + 8)

    -- OPTIMIZACIÓN DE FPS (Solo actualiza el string si el contador de frames varía)
    local cur_fps = love.timer.getFPS()
    if cur_fps ~= STR_CACHE.last_fps then
        STR_CACHE.fps_str = string.format("%3d FPS", cur_fps)
        STR_CACHE.last_fps = cur_fps
    end
    love.graphics.print(STR_CACHE.fps_str, px + (is_boss_mode and 215 or 248), py + 8)

    love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.15)
    love.graphics.rectangle("fill", px + 8, py + 26, pw - 16, 4, 1)
    love.graphics.setColor(t.secondary[1], t.secondary[2], t.secondary[3], 0.90)
    love.graphics.rectangle("fill", px + 8, py + 26, (pw - 16) * energy, 4, 1)

    if player and bot then
        love.graphics.setFont(FontCache.get(11))
        
        -- Cachear P1 PPS
        local p1_pps = player.current_pps_display or 0
        if math.abs(p1_pps - STR_CACHE.last_p1) > 0.01 then
            STR_CACHE.p1_str = string.format("P1:  %.2f PPS", p1_pps)
            STR_CACHE.last_p1 = p1_pps
        end
        love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.95)
        love.graphics.print(STR_CACHE.p1_str, px + 8, py + 38)
        
        -- Cachear BOT PPS
        local bot_pps = bot.current_pps_display or 0
        if math.abs(bot_pps - STR_CACHE.last_bot) > 0.01 then
            STR_CACHE.bot_str = string.format("BOT: %.2f PPS", bot_pps)
            STR_CACHE.last_bot = bot_pps
        end
        love.graphics.setColor(1.0, 0.35, 0.4, 0.95)
        love.graphics.print(STR_CACHE.bot_str, px + (is_boss_mode and 130 or 155), py + 38)
    end

    local prof = _G.AI_ADAPTIVE_PROFILE
    if prof and _G.CURRENT_GAME_MODE == "versus" then
        love.graphics.setFont(FontCache.get(10))
        local target_pps = prof.ai_target_pps or 1.45
        
        if target_pps ~= STR_CACHE.last_target then
            STR_CACHE.target_str = string.format("AI TARGET: %.2f PPS", target_pps)
            STR_CACHE.record_str = string.format("RECORD: %d-%d (AVG P1: %.2f)", prof.player_wins or 0, prof.bot_wins or 0, prof.player_avg_pps or 1.0)
            STR_CACHE.last_target = target_pps
        end

        if target_pps >= 2.5 then love.graphics.setColor(1.0, 0.25, 0.35, 0.95)
        elseif target_pps >= 1.6 then love.graphics.setColor(1.0, 0.85, 0.2, 0.95)
        else love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.95) end
        
        love.graphics.print(STR_CACHE.target_str, px + 8, py + 68)
        love.graphics.setColor(0.7, 0.80, 0.90, 0.85)
        love.graphics.print(STR_CACHE.record_str, px + 8, py + 88)
    end

    love.graphics.pop()
end

-- El modo MultiBot queda securizado de la misma manera de forma limpia
function Telemetry.drawMultiBot(boards)
    if not boards or #boards == 0 then return end
    love.graphics.push("all")
    local t = ThemeManager.getCurrent()
    local energy = _G.TrackEnergyPunch or 0
    local bx, by, bw, bh = 80, 530, 1120, 75
    ThemeManager.drawPanel(bx, by, bw, bh, "", false)
    love.graphics.pop()
end

return Telemetry
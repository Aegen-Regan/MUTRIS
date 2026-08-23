-- ================================================================
-- FILE: combat/status_blights.lua
-- ================================================================
---@diagnostic disable: undefined-global
local StatusBlights = {}

local FontCache    = require "tetris.font_cache"
local AudioManager = require "audio_manager"
local BloomShader  = require "tetris.bloom_shader"
local ThemeManager = require "tetris.theme_manager"
local Blackbox     = require "core.blackbox"

StatusBlights.BLIGHT_NONE       = 0
StatusBlights.BLIGHT_FROSTBITE  = 1
StatusBlights.BLIGHT_BLEED      = 2
StatusBlights.BLIGHT_CORRUPTION = 3

function StatusBlights.initBoardState(board)
    board.blights = {
        frostbite  = { active = false, timer = 0.0, max_time = 5.0 },
        bleed      = { active = false, timer = 0.0, max_time = 6.0, meter = 0.0 },
        corruption = { active = false, timer = 0.0, max_time = 4.5, drift_timer = 0.0, dir = 1 }
    }
    board.blight_flash = 0.0
end

function StatusBlights.applyBlight(board, blight_id, duration)
    if not board or board.is_dying or not board.blights then return end

    if blight_id == StatusBlights.BLIGHT_FROSTBITE then
        board.blights.frostbite.active = true
        board.blights.frostbite.timer = duration or 5.0
        board.blights.frostbite.max_time = duration or 5.0
        board.blight_flash = 1.0
        AudioManager.playImmediateSFX("rotate", board.player_type == "bot")
        board:setPopup("FROSTBITE!", {0.2, 0.9, 1.0}, true, "DAS/ARR SLUGGISH (+60ms)")
        Blackbox.log("BLIGHT", "FROSTBITE APPLIED", math.floor(board.blights.frostbite.timer), 0)

    elseif blight_id == StatusBlights.BLIGHT_BLEED then
        board.blights.bleed.active = true
        board.blights.bleed.timer = duration or 6.0
        board.blights.bleed.max_time = duration or 6.0
        board.blights.bleed.meter = 0.0
        board.blight_flash = 1.0
        AudioManager.playImmediateSFX("death", board.player_type == "bot")
        board:setPopup("BLEEDING!", {1.0, 0.1, 0.25}, true, "CLEAR LINES TO CAUTERIZE")
        Blackbox.log("BLIGHT", "BLEED APPLIED", math.floor(board.blights.bleed.timer), 0)

    elseif blight_id == StatusBlights.BLIGHT_CORRUPTION then
        board.blights.corruption.active = true
        board.blights.corruption.timer = duration or 4.5
        board.blights.corruption.max_time = duration or 4.5
        board.blights.corruption.drift_timer = 0.0
        board.blights.corruption.dir = math.random() > 0.5 and 1 or -1
        board.blight_flash = 1.0
        AudioManager.playImmediateSFX("phantom_attack", board.player_type == "bot")
        board:setPopup("CORRUPTION!", {0.7, 0.2, 1.0}, true, "MAGNETIC DRIFT ACTIVE")
        Blackbox.log("BLIGHT", "CORRUPTION APPLIED", math.floor(board.blights.corruption.timer), 0)
    end

    BloomShader.triggerShockwave(board.x + 120, board.y + 240)
end

function StatusBlights.cleanse(board)
    if not board or not board.blights then return end
    board.blights.frostbite.active = false
    board.blights.bleed.active = false
    board.blights.corruption.active = false
end

function StatusBlights.getDASOffset(board)
    if board and board.blights and board.blights.frostbite.active then
        return 0.060
    end
    return 0.0
end

function StatusBlights.getARROffset(board)
    if board and board.blights and board.blights.frostbite.active then
        return 0.015
    end
    return 0.0
end

function StatusBlights.onPlayerLineClear(board, cleared_count, is_tspin)
    if not board or not board.blights then return end

    if board.blights.frostbite.active then
        board.blights.frostbite.timer = math.max(0, board.blights.frostbite.timer - 2.0)
        if board.blights.frostbite.timer <= 0 then board.blights.frostbite.active = false end
    end
    if board.blights.bleed.active then
        board.blights.bleed.active = false
        board:setPopup("CAUTERIZED!", {0.1, 1.0, 0.5}, false, "BLEED CURED")
    end

    if board.opponent and not board.opponent.is_dying then
        if is_tspin and cleared_count >= 2 then
            StatusBlights.applyBlight(board.opponent, StatusBlights.BLIGHT_BLEED, 6.0)
        elseif cleared_count == 4 then
            StatusBlights.applyBlight(board.opponent, StatusBlights.BLIGHT_FROSTBITE, 5.0)
        end
    end
end

function StatusBlights.update(board, dt)
    if not board or not board.blights or board.is_dying then return end

    local b = board.blights
    local pulse = _G.AudioBeatPulse or 0

    if board.blight_flash > 0 then
        board.blight_flash = math.max(0, board.blight_flash - dt * 3.0)
    end

    if b.frostbite.active then
        b.frostbite.timer = math.max(0, b.frostbite.timer - dt)
        if b.frostbite.timer <= 0 then
            b.frostbite.active = false
            Blackbox.log("BLIGHT_END", "FROSTBITE THAWED", 0, 0)
        end
    end

    if b.bleed.active then
        b.bleed.timer = math.max(0, b.bleed.timer - dt)
        b.bleed.meter = b.bleed.meter + dt * 0.25 + (pulse * 0.15 * dt)

        if b.bleed.meter >= 1.0 then
            b.bleed.meter = 0.0
            local GarbageManager = require "tetris.garbage_manager"
            GarbageManager.sendGarbage(nil, board, 2)
            board:triggerShake(8, 0.3)
            AudioManager.playImmediateSFX("death", board.player_type == "bot")
            board:setPopup("HEMORRHAGE!", {1.0, 0.1, 0.2}, true, "+2 GARBAGE DAMAGE")
        end

        if b.bleed.timer <= 0 then
            b.bleed.active = false
            Blackbox.log("BLIGHT_END", "BLEED EXPIRED", 0, 0)
        end
    end

    if b.corruption.active then
        b.corruption.timer = math.max(0, b.corruption.timer - dt)
        b.corruption.drift_timer = b.corruption.drift_timer + dt

        if b.corruption.drift_timer >= 1.5 then
            b.corruption.drift_timer = 0.0
            if board.active_piece and not board.active_piece.locked then
                board.active_piece:move(b.corruption.dir, 0)
                board:triggerShake(3, 0.15)
                AudioManager.playImmediateSFX("move", board.player_type == "bot")
            end
        end

        if b.corruption.timer <= 0 then
            b.corruption.active = false
            Blackbox.log("BLIGHT_END", "CORRUPTION PURGED", 0, 0)
        end
    end
end

function StatusBlights.drawAura(board)
    if not board or not board.blights then return end

    local b = board.blights
    local bx, by, bw, bh = board.x, board.y, 240, 480
    local pulse = _G.AudioBeatPulse or 0
    local time = love.timer.getTime()

    love.graphics.push("all")

    if b.frostbite.active then
        local p = b.frostbite.timer / b.frostbite.max_time
        love.graphics.setBlendMode("add")
        love.graphics.setColor(0.2, 0.9, 1.0, (0.35 + pulse * 0.25) * p)
        love.graphics.setLineWidth(3.0)
        love.graphics.rectangle("line", bx - 2, by - 2, bw + 4, bh + 4, 4)

        love.graphics.setColor(1.0, 1.0, 1.0, 0.8 * p)
        love.graphics.polygon("fill", bx, by, bx + 15, by, bx, by + 15)
        love.graphics.polygon("fill", bx + bw, by, bx + bw - 15, by, bx + bw, by + 15)
        love.graphics.setBlendMode("alpha")

        love.graphics.setFont(FontCache.get(8))
        love.graphics.setColor(0.2, 0.9, 1.0, 0.9)
        love.graphics.print(string.format("FROSTBITE %.1fs", b.frostbite.timer), bx + 8, by + bh + 4)

    elseif b.bleed.active then
        local p = b.bleed.timer / b.bleed.max_time
        love.graphics.setBlendMode("add")
        local flash = math.sin(time * 16) * 0.5 + 0.5
        love.graphics.setColor(1.0, 0.08, 0.25, (0.4 + flash * 0.35) * p)
        love.graphics.setLineWidth(2.5)
        love.graphics.rectangle("line", bx - 2, by - 2, bw + 4, bh + 4)
        love.graphics.setBlendMode("alpha")

        love.graphics.setFont(FontCache.get(8))
        love.graphics.setColor(1.0, 0.15, 0.25, 0.95)
        love.graphics.print(string.format("BLEEDING %.1fs (%d%%)", b.bleed.timer, math.floor(b.bleed.meter * 100)), bx + 8, by + bh + 4)

    elseif b.corruption.active then
        local p = b.corruption.timer / b.corruption.max_time
        love.graphics.setBlendMode("add")
        love.graphics.setColor(0.7, 0.2, 1.0, (0.35 + pulse * 0.3) * p)
        love.graphics.rectangle("line", bx - 3, by - 3, bw + 6, bh + 6, 2)
        love.graphics.setBlendMode("alpha")

        love.graphics.setFont(FontCache.get(8))
        love.graphics.setColor(0.7, 0.3, 1.0, 0.95)
        love.graphics.print(string.format("CORRUPTION %.1fs", b.corruption.timer), bx + 8, by + bh + 4)
    end

    love.graphics.pop()
end

return StatusBlights
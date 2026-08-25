-- ================================================================
-- FILE: tetris/garbage_manager.lua
-- ================================================================
---@diagnostic disable: undefined-global
local GarbageManager = {}

local KineticParry = require "combat.kinetic_parry"
local MetaBalancer = require "core.meta_balancer"

local COMBO_ATTACK_TABLE = { 0, 1, 1, 2, 2, 3, 3, 4, 4, 4, 5, 5 }

function GarbageManager.calculateAttack(lines_cleared, is_tspin, is_b2b, combo)
    if not lines_cleared or lines_cleared <= 0 then return 0 end

    local base_attack = 0

    if is_tspin then
        if lines_cleared == 1 then
            base_attack = 2
        elseif lines_cleared == 2 then
            base_attack = 4
        elseif lines_cleared == 3 then
            base_attack = 6
        else
            base_attack = 1
        end
    else
        if lines_cleared == 1 then
            base_attack = 0
        elseif lines_cleared == 2 then
            base_attack = 1
        elseif lines_cleared == 3 then
            base_attack = 2
        elseif lines_cleared >= 4 then
            base_attack = 4
        end
    end

    if is_b2b and base_attack > 0 then
        base_attack = base_attack + 1
    end

    local combo_bonus = 0
    if combo and combo > 1 then
        local c_idx = math.min(#COMBO_ATTACK_TABLE, combo)
        combo_bonus = COMBO_ATTACK_TABLE[c_idx] or 5
    end

    return base_attack + combo_bonus
end

function GarbageManager.calculateZoneBurst(lines_cleared, is_pc, is_hyper)
    local count = lines_cleared or 0
    local base = count
    
    if count >= 20 then base = 25
    elseif count >= 16 then base = 18
    elseif count >= 12 then base = 12
    elseif count >= 8 then base = 7
    elseif count >= 4 then base = 3
    end

    if is_hyper then base = math.floor(base * 1.5) end
    if is_pc then base = base + 10 end

    local text = (count >= 16 and "SUPERNOVA BURST!") or (count >= 10 and "HYPER BURST!") or "ZONE BURST!"
    local color = is_hyper and {1.0, 0.85, 0.2} or {0.1, 0.9, 1.0}

    return base, text, color
end

function GarbageManager.sendGarbage(sender, receiver, lines, is_counter)
    if not receiver or lines <= 0 then return end

    local parried, remaining = KineticParry.attemptParry(receiver, lines)
    if parried then
        return
    end

    if remaining <= 0 then return end

    if receiver.receiveGarbage then
        receiver:receiveGarbage(remaining)
    elseif receiver.garbage_queue then
        table.insert(receiver.garbage_queue, { lines = remaining, timer = 0.5 })
    end
end

function GarbageManager.cancelGarbage(board, lines_cleared)
    if not board or not board.garbage_queue or #board.garbage_queue == 0 or lines_cleared <= 0 then
        return lines_cleared
    end

    local remaining_clears = lines_cleared
    local i = 1
    while i <= #board.garbage_queue and remaining_clears > 0 do
        local entry = board.garbage_queue[i]
        local entry_lines = type(entry) == "table" and entry.lines or entry

        if entry_lines <= remaining_clears then
            remaining_clears = remaining_clears - entry_lines
            table.remove(board.garbage_queue, i)
        else
            if type(entry) == "table" then
                entry.lines = entry_lines - remaining_clears
            else
                board.garbage_queue[i] = entry_lines - remaining_clears
            end
            remaining_clears = 0
            break
        end
    end

    return remaining_clears
end

return GarbageManager
---@diagnostic disable: undefined-global
local GarbageManager = {}

local ATTACK_TABLE = {
    single = 0, double = 1, triple = 2, tetris = 4,
    t_spin_single = 2, t_spin_double = 4, t_spin_triple = 6
}
local COMBO_TABLE = {0, 0, 1, 1, 1, 2, 2, 3, 3, 4, 4, 4, 5}

local ZONE_ATTACK_TIERS = {
    [1] = 1, [2] = 2, [3] = 3, [4] = 5,
    [5] = 7, [6] = 9, [7] = 11, [8] = 13,       -- Octoris
    [9] = 15, [10] = 17, [11] = 19, [12] = 21,   -- Dodecatris
    [13] = 23, [14] = 25, [15] = 27, [16] = 30,   -- Decahexatris
    [18] = 36, [20] = 44, [21] = 50              -- Ultimatris
}

function GarbageManager.calculateAttack(lines, is_tspin, is_mini, combo, b2b, board)
    local attack = 0
    local message = ""
    local color = {1, 1, 1}

    local charge_boost = (lines / 4) * 0.4
    if is_tspin or lines == 4 then 
        charge_boost = 1.0 
        board.eq_power = 1.0
        board.eq_flash = 1.0
    end

    if combo > 0 then
        charge_boost = charge_boost + (combo * 0.18)
        board.eq_power = math.max(board.eq_power, 0.5)
    end

    board.eq_charge = math.min(1.0, board.eq_charge + charge_boost)

    if not board.is_zone_active then
        local zone_gain = lines * 0.038
        if is_tspin then zone_gain = zone_gain + 0.06 end
        if lines == 4 then zone_gain = zone_gain + 0.05 end
        board.zone_meter = math.min(1.0, board.zone_meter + zone_gain)
    end

    if is_tspin then
        if lines == 1 then attack, message, color = 2, "T-SPIN SINGLE", {0.8, 0.2, 1}
        elseif lines == 2 then attack, message, color = 4, "T-SPIN DOUBLE", {0.8, 0.2, 1}
        elseif lines == 3 then attack, message, color = 6, "T-SPIN TRIPLE", {0.8, 0.2, 1}
        end
    else
        if lines == 2 then attack, message = 1, "DOUBLE"
        elseif lines == 3 then attack, message = 2, "TRIPLE"
        elseif lines == 4 then attack, message, color = 4, "TETRIS!", {0, 0.8, 1}
        end
    end

    if b2b > 0 and (lines == 4 or is_tspin) then 
        attack = attack + 1 
        if message ~= "" then message = "B2B " .. message end
    end

    if combo > 0 then 
        attack = attack + (COMBO_TABLE[math.min(combo, #COMBO_TABLE)] or 5)
        if combo >= 2 then board:setPopup("COMBO " .. combo, {1, 0.8, 0}) end
    end

    -- DETONACIÓN DE PHANTOM DUEL (Interferencia Espectral al Rival)
    if (lines == 4 or is_tspin or (b2b > 0 and lines >= 2)) and board.opponent and board.active_piece then
        local p = board.active_piece
        board.opponent:spawnPhantom(p.x, math.random(22, 34), p.id, p.shape[p.rotation])
        local AudioManager = require "audio_manager"
        AudioManager.playImmediateSFX("phantom_attack", board.player_type == "bot")
    end

    if message ~= "" then board:setPopup(message, color) end
    return attack
end

function GarbageManager.calculateZoneBurst(lines_cleared, is_perfect_clear, is_hyper_zone)
    if is_perfect_clear then
        return 50, "PERFECT CLEAR ZONE!", {1.0, 0.85, 0.2}
    end

    if lines_cleared <= 0 then 
        return 0, "ZONE END", {0.5, 0.8, 1} 
    end

    local base = ZONE_ATTACK_TIERS[lines_cleared] or math.floor(lines_cleared * 2.3)
    
    if is_hyper_zone then
        base = base + 3
    end

    local name = "ZONE " .. lines_cleared
    local color = {0, 0.9, 1}

    if lines_cleared >= 20 then 
        name, color = "ULTIMATRIS (" .. lines_cleared .. ")", {1.0, 0.85, 0.2}
    elseif lines_cleared >= 16 then 
        name, color = "DECAHEXATRIS (" .. lines_cleared .. ")", {1, 0.2, 0.8}
    elseif lines_cleared >= 12 then 
        name, color = "DODECATRIS (" .. lines_cleared .. ")", {0.8, 0.2, 1}
    elseif lines_cleared >= 8 then 
        name, color = "OCTORIS (" .. lines_cleared .. ")", {0.2, 1, 0.5}
    elseif lines_cleared >= 4 then 
        name, color = "TETRIS ZONE (" .. lines_cleared .. ")", {0, 0.8, 1}
    end

    if is_hyper_zone then
        name = "★ HYPER " .. name
        color = {1.0, 0.9, 0.3}
    end

    return base, name, color
end

function GarbageManager.sendGarbage(sender, receiver, amount)
    if amount <= 0 then return end
    
    if receiver and receiver.is_zone_active then
        return
    end

    local rem = amount
    while rem > 0 and #sender.garbage_queue > 0 do
        if sender.garbage_queue[1] <= rem then 
            rem = rem - table.remove(sender.garbage_queue, 1)
        else 
            sender.garbage_queue[1] = sender.garbage_queue[1] - rem
            rem = 0 
        end
    end

    if rem > 0 and receiver then 
        table.insert(receiver.garbage_queue, rem)
        receiver:triggerShake(rem * 4, 0.25)
        receiver.eq_charge = math.min(1.0, receiver.eq_charge + 0.4)
    end
end

function GarbageManager.pushToGrid(board)
    if board.is_zone_active or #board.garbage_queue == 0 then return end
    
    local lines = math.min(table.remove(board.garbage_queue, 1), 8)
    local hole = math.random(1, 10)
    for i = 1, lines do
        table.remove(board.grid, 1)
        local row = {}
        for c = 1, 10 do row[c] = (c == hole) and 0 or 8 end
        table.insert(board.grid, row)
    end
    
    local AudioManager = require "audio_manager"
    if AudioManager and AudioManager.triggerGlitch then
        AudioManager.triggerGlitch(lines * 0.08)
    end
    board:triggerShake(lines * 5, 0.3)
end

return GarbageManager
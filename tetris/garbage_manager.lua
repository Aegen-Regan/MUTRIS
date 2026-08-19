local GarbageManager = {}

local ATTACK_TABLE = {
    single = 0, double = 1, triple = 2, tetris = 4,
    t_spin_single = 2, t_spin_double = 4, t_spin_triple = 6
}
local COMBO_TABLE = {0, 0, 1, 1, 1, 2, 2, 3, 3, 4, 4, 4, 5}

function GarbageManager.calculateAttack(lines, is_tspin, is_mini, combo, b2b, board)
    local attack = 0
    local message = ""
    local color = {1, 1, 1}

    -- HEAT SYSTEM (VISUAL)
    local charge_boost = (lines / 4) * 0.4
    if is_tspin or lines == 4 then 
        charge_boost = 1.0 
        board.eq_power = 1.0  -- Activa paleta Hyper-Attack
        board.eq_flash = 1.0  -- Impacto visual
    end

    -- Los combos disparan pequeñas ráfagas de brillo
    if combo > 0 then
        charge_boost = charge_boost + (combo * 0.18)
        board.eq_power = math.max(board.eq_power, 0.5)
    end

    board.eq_charge = math.min(1.0, board.eq_charge + charge_boost)

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

    if message ~= "" then board:setPopup(message, color) end
    return attack
end

function GarbageManager.sendGarbage(sender, receiver, amount)
    if amount <= 0 then return end
    local rem = amount
    while rem > 0 and #sender.garbage_queue > 0 do
        if sender.garbage_queue[1] <= rem then rem = rem - table.remove(sender.garbage_queue, 1)
        else sender.garbage_queue[1] = sender.garbage_queue[1] - rem; rem = 0 end
    end
    if rem > 0 then 
        table.insert(receiver.garbage_queue, rem)
        receiver:triggerShake(rem * 4, 0.25)
        -- Cuando recibimos ataque, la energía se vuelve "inestable" (Rojo Danger)
        receiver.eq_charge = math.min(1.0, receiver.eq_charge + 0.4)
    end
end

function GarbageManager.pushToGrid(board)
    if #board.garbage_queue == 0 then return end
    local lines = math.min(table.remove(board.garbage_queue, 1), 8)
    local hole = math.random(1, 10)
    for i = 1, lines do
        table.remove(board.grid, 1)
        local row = {}
        for c = 1, 10 do row[c] = (c == hole) and 0 or 8 end
        table.insert(board.grid, row)
    end
    local AudioManager = require "audio_manager"
    AudioManager.triggerGlitch(lines * 0.08)
    board:triggerShake(lines * 5, 0.3)
end

return GarbageManager
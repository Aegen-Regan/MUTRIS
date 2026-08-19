-- tetris/garbage_manager.lua
local GarbageManager = {}

local ATTACK_TABLE = {
    single = 0, double = 1, triple = 2, tetris = 4,
    t_spin_single = 2, t_spin_double = 4, t_spin_triple = 6
}
local COMBO_TABLE = {0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 4, 5}

function GarbageManager.calculateAttack(lines, is_tspin, is_mini, combo, b2b)
    local attack = 0
    if lines == 0 then return 0 end
    if is_tspin then
        if lines == 1 then attack = ATTACK_TABLE.t_spin_single
        elseif lines == 2 then attack = ATTACK_TABLE.t_spin_double
        elseif lines == 3 then attack = ATTACK_TABLE.t_spin_triple end
    else
        if lines == 1 then attack = ATTACK_TABLE.single
        elseif lines == 2 then attack = ATTACK_TABLE.double
        elseif lines == 3 then attack = ATTACK_TABLE.triple
        elseif lines == 4 then attack = ATTACK_TABLE.tetris end
    end
    if b2b > 0 and (lines == 4 or is_tspin) then attack = attack + 1 end
    if combo > 0 then attack = attack + (COMBO_TABLE[math.min(combo, #COMBO_TABLE)] or 5) end
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
        receiver:triggerShake(rem * 2, 0.2)
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
        -- CORRECCIÓN: Inserción directa al final absoluto para que la grilla no crezca a 41 filas
        table.insert(board.grid, row)
    end
    
    local AudioManager = require "audio_manager"
    AudioManager.triggerGlitch(lines * 0.06)
    
    board:triggerShake(lines * 2.5, 0.2)
end

return GarbageManager

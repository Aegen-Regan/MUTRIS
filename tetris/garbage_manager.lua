-- ================================================================
-- FILE: tetris/garbage_manager.lua
-- ================================================================
---@diagnostic disable: undefined-global
local GarbageManager = {}

local KineticParry = require "combat.kinetic_parry"
local MetaBalancer = require "core.meta_balancer"

-- Tabla estática Zero-GC de bonificación por Combo
local COMBO_ATTACK_TABLE = { 0, 1, 1, 2, 2, 3, 3, 4, 4, 4, 5, 5 }

function GarbageManager.calculateAttack(lines_cleared, is_tspin, is_b2b, combo)
    if not lines_cleared or lines_cleared <= 0 then return 0 end

    local base_attack = 0

    if is_tspin then
        if lines_cleared == 1 then
            base_attack = 2  -- T-Spin Single
        elseif lines_cleared == 2 then
            base_attack = 4  -- T-Spin Double
        elseif lines_cleared == 3 then
            base_attack = 6  -- T-Spin Triple
        else
            base_attack = 1
        end
    else
        if lines_cleared == 1 then
            base_attack = 0  -- Single
        elseif lines_cleared == 2 then
            base_attack = 1  -- Double
        elseif lines_cleared == 3 then
            base_attack = 2  -- Triple
        elseif lines_cleared >= 4 then
            base_attack = 4  -- Tetris (Quad)
        end
    end

    -- Bonificación por Back-to-Back (+1 línea)
    if is_b2b and base_attack > 0 then
        base_attack = base_attack + 1
    end

    -- Bonificación por Combo en cadena
    local combo_bonus = 0
    if combo and combo > 1 then
        local c_idx = math.min(#COMBO_ATTACK_TABLE, combo)
        combo_bonus = COMBO_ATTACK_TABLE[c_idx] or 5
    end

    return base_attack + combo_bonus
end

function GarbageManager.sendGarbage(sender, receiver, lines, is_counter)
    if not receiver or lines <= 0 then return end

    local final_lines = lines

    -- 1. Si hay un emisor real, calcular bonificaciones de postura/ataque
    if sender then
        if sender.current_stance == 1 then -- Rush
            final_lines = math.floor(final_lines * (MetaBalancer.get("rush_atk_mult") or 1.5))
        elseif sender.current_stance == 2 then -- Bastion
            final_lines = math.floor(final_lines * (MetaBalancer.get("bastion_atk_mult") or 0.5))
        end
    end

    -- 2. Si el receptor está en Bastion, mitigar daño entrante
    if receiver.current_stance == 2 then
        local mit = MetaBalancer.get("bastion_intake_mult") or 0.5
        final_lines = math.max(1, math.floor(final_lines * mit))
    end

    -- 3. Intentar Kinetic Parry (si la ventana de 3 frames está activa)
    local parried, remaining = KineticParry.attemptParry(receiver, final_lines)
    if parried then
        return
    end

    final_lines = remaining
    if final_lines <= 0 then return end

    -- 4. Inyección a la cola de basura del receptor
    if receiver.receiveGarbage then
        receiver:receiveGarbage(final_lines)
    elseif receiver.garbage_queue then
        table.insert(receiver.garbage_queue, { lines = final_lines, timer = 0.5 })
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
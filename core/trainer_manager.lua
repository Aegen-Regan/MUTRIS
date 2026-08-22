-- ================================================================
-- FILE: core/trainer_manager.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS TRAINER LAB: ADAPTIVE ENGINE WITH FORCED DETERMINISTIC QUEUE
-- ============================================================================
local TrainerManager = {}
local TrainerDatabase = require "core.trainer_database"
local AudioManager    = require "audio_manager"
local Piece           = require "tetris.piece"
local RulesetManager  = require "core.ruleset_manager"

TrainerManager.selected_opener_idx = 1
TrainerManager.current_step = 1
TrainerManager.completed_reps = 0
TrainerManager.current_streak = 0
TrainerManager.finesse_faults = 0
TrainerManager.hologram_active = true

-- Búfer de Snapshots Zero-GC (32 slots)
local MAX_SNAPSHOTS = 32
local snapshots = {}
local snapshot_head = 0
local snapshot_count = 0

for i = 1, MAX_SNAPSHOTS do
    local grid_copy = {}
    for r = 1, 40 do
        grid_copy[r] = {}
        for c = 1, 10 do grid_copy[r][c] = 0 end
    end
    snapshots[i] = {
        grid = grid_copy,
        step = 1,
        hold_id = 0,
        can_hold = true,
        faults = 0
    }
end

-- 🎯 Inyección de Bolsa Determinista que cumple el contrato exacto de 7bag.lua
local function attachDeterministicBag(board, opener)
    local contents = {}
    local preview = {}

    local function refillContents()
        for _, pid in ipairs(opener.queue) do
            table.insert(contents, pid)
        end
    end

    refillContents()
    for i = 1, 5 do
        if #contents == 0 then refillContents() end
        table.insert(preview, table.remove(contents, 1))
    end

    board.bag = {
        contents = contents,
        preview = preview,
        next = function(self)
            local np = table.remove(self.preview, 1)
            if #self.contents == 0 then
                refillContents()
            end
            table.insert(self.preview, table.remove(self.contents, 1))
            return np
        end,
        peek = function(self, count)
            local p = {}
            for i = 1, (count or 1) do
                table.insert(p, self.preview[i])
            end
            return p
        end
    }

    local first_piece = board.bag:next()
    board.active_piece = Piece.new(first_piece, board)
    board.hold_piece = nil
    board.can_hold = true
end

function TrainerManager.init(board, keep_stats)
    TrainerManager.current_step = 1
    if not keep_stats then
        TrainerManager.finesse_faults = 0
    end
    snapshot_head = 0
    snapshot_count = 0

    if board then
        for r = 1, 40 do
            for c = 1, 10 do board.grid[r][c] = 0 end
        end

        local opener = TrainerDatabase.getOpener(TrainerManager.selected_opener_idx)
        attachDeterministicBag(board, opener)
        TrainerManager.saveSnapshot(board)
    end
end

function TrainerManager.saveSnapshot(board)
    snapshot_head = (snapshot_head % MAX_SNAPSHOTS) + 1
    snapshot_count = math.min(MAX_SNAPSHOTS, snapshot_count + 1)

    local snap = snapshots[snapshot_head]
    snap.step = TrainerManager.current_step
    snap.hold_id = board.hold_piece and board.hold_piece.id or 0
    snap.can_hold = board.can_hold
    snap.faults = TrainerManager.finesse_faults

    for r = 1, 40 do
        for c = 1, 10 do
            snap.grid[r][c] = board.grid[r][c]
        end
    end
end

function TrainerManager.undo(board)
    if snapshot_count <= 1 then
        AudioManager.playTone(150, 0.08, 0.3, "sine", true, 0, 40, true)
        return false
    end

    snapshot_head = (snapshot_head - 2 + MAX_SNAPSHOTS) % MAX_SNAPSHOTS + 1
    snapshot_count = snapshot_count - 1

    local snap = snapshots[snapshot_head]
    TrainerManager.current_step = math.max(1, snap.step)
    TrainerManager.finesse_faults = snap.faults

    for r = 1, 40 do
        for c = 1, 10 do
            board.grid[r][c] = snap.grid[r][c]
        end
    end

    if snap.hold_id > 0 then
        board.hold_piece = { id = snap.hold_id }
    else
        board.hold_piece = nil
    end
    board.can_hold = snap.can_hold

    local opener = TrainerDatabase.getOpener(TrainerManager.selected_opener_idx)
    local target = opener.steps[TrainerManager.current_step]
    if target then
        board.active_piece = Piece.new(target.piece, board)
    end

    AudioManager.playSliderTick()
    board:setPopup("PASO REBOBINADO", {0.2, 0.9, 1.0}, false, "MODO TIME-TRAVEL")
    return true
end

function TrainerManager.onPieceLocked(board, piece_id, px, py, prot)
    local opener = TrainerDatabase.getOpener(TrainerManager.selected_opener_idx)
    local target = opener.steps[TrainerManager.current_step]

    if target then
        local is_correct_piece = (piece_id == target.piece)
        local is_correct_pos = (px == target.x and (py == target.y or py == target.y + 1) and (prot == target.rot or (piece_id == 4)))

        if is_correct_piece and is_correct_pos then
            TrainerManager.current_step = TrainerManager.current_step + 1

            if TrainerManager.current_step > #opener.steps then
                TrainerManager.completed_reps = TrainerManager.completed_reps + 1
                TrainerManager.current_streak = TrainerManager.current_streak + 1
                board:setPopup("PLANO COMPLETADO! +1 RACHA", {0.1, 1.0, 0.5}, true, "REPETICION AUTOMATICA")
                AudioManager.playImmediateSFX("zone_enter_hyper", false)

                TrainerManager.init(board, true)
                return
            else
                board:setPopup(string.format("PASO %d/%d OK!", TrainerManager.current_step - 1, #opener.steps), {0.2, 0.95, 0.6})
            end
        else
            TrainerManager.finesse_faults = TrainerManager.finesse_faults + 1
            TrainerManager.current_streak = 0
            board:setPopup("ERROR DE COLOCACION", {1.0, 0.3, 0.3}, false, "[BACKSPACE] PARA REBOBINAR")
            AudioManager.playTone(160, 0.12, 0.4, "triangle", true, 0, 50, true)
        end
    end

    TrainerManager.saveSnapshot(board)
end

function TrainerManager.drawHologram(board)
    if not TrainerManager.hologram_active or not board then return end

    local opener = TrainerDatabase.getOpener(TrainerManager.selected_opener_idx)
    local target = opener.steps[TrainerManager.current_step]
    if not target then return end

    local shapes = RulesetManager.getShapes(target.piece)
    local shape = shapes and shapes[target.rot] or {{{1}}}
    local clr = board.colors[target.piece] or {0.0, 0.9, 1.0}

    love.graphics.push("all")
    love.graphics.setBlendMode("add")
    
    local pulse = 0.45 + math.sin(love.timer.getTime() * 6.0) * 0.18

    for r = 1, #shape do
        for c = 1, #shape[r] do
            if shape[r][c] ~= 0 then
                local rx = board.x + (target.x + c - 2) * 24
                local ry = board.y + (target.y + r - 22) * 24

                love.graphics.setColor(clr[1], clr[2], clr[3], pulse * 0.50)
                love.graphics.rectangle("fill", rx + 2, ry + 2, 20, 20, 3)

                love.graphics.setLineWidth(2.0)
                love.graphics.setColor(1.0, 1.0, 1.0, pulse * 0.95)
                love.graphics.rectangle("line", rx + 2, ry + 2, 20, 20, 3)
            end
        end
    end

    love.graphics.pop()
end

return TrainerManager
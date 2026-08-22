-- ================================================================
-- FILE: tetris/piece.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: TETROMINO PIECE PHYSICS & MULTI-RULESET INTEGRATION
-- SRS / ARS / NES / Status Blights Corruption / Ghost Filtering
-- ============================================================================
local Piece = {}
Piece.__index = Piece

local AudioManager    = require "audio_manager"
local SettingsManager = require "settings_manager"
local PPSCounter      = require "tetris.pps_counter"
local BeatLock        = require "tetris.beat_lock"
local CombatStances   = require "combat.combat_stances"
local KineticParry    = require "combat.kinetic_parry"
local BloomShader     = require "tetris.bloom_shader"
local ThemeManager    = require "tetris.theme_manager"
local RulesetManager  = require "core.ruleset_manager"
local StatusBlights   = require "combat.status_blights"
local Blackbox        = require "core.blackbox"

function Piece.new(id, board)
    local self = setmetatable({}, Piece)
    self.id, self.board = id, board

    local shapes = RulesetManager.getShapes(id)
    self.shape = shapes or { {{1,1,1,1}} }
    self.rotation = 1
    self.x, self.y = 4, 21
    self.locked, self.gravity_timer, self.lock_timer = false, 0, 0

    self.lock_delay = RulesetManager.getLockDelay()
    self.move_count = 0
    self.max_resets = RulesetManager.getCurrent().max_lock_resets

    self.spawn_timer = 0.2
    self.last_move_was_rotate = false

    if self.board then
        CombatStances.applyPieceModifiers(self.board, self)
    end

    if RulesetManager.is20G() then
        while self:move(0, 1, true) do end
    end

    return self
end

function Piece:resetLock()
    if RulesetManager.shouldResetLockOnMove() then
        if self.move_count < self.max_resets then 
            self.lock_timer = 0
            self.move_count = self.move_count + 1 
        end
    end
end

function Piece:move(dx, dy, is_gravity)
    if self.board:canMove(self.x + dx, self.y + dy, self.rotation) then
        self.x, self.y = self.x + dx, self.y + dy
        if not is_gravity then 
            AudioManager.playImmediateSFX("move", self.board.player_type == "bot") 
            self:resetLock() 
            self.last_move_was_rotate = false
        end
        return true
    end
    return false
end

function Piece:rotate(dir)
    local max_rot = #self.shape
    local old_rot = self.rotation
    local next_rot = ((self.rotation + dir - 1) % max_rot) + 1
    
    local kicks = RulesetManager.getKicks(self.id, old_rot, next_rot)
    if kicks then
        for _, kick in ipairs(kicks) do
            if self.board:canMove(self.x + kick[1], self.y - kick[2], next_rot) then
                self.x, self.y, self.rotation = self.x + kick[1], self.y - kick[2], next_rot
                AudioManager.playImmediateSFX("rotate", self.board.player_type == "bot")
                self:resetLock()
                self.last_move_was_rotate = true
                return true
            end
        end
    end
    return false
end

function Piece:checkTSpin()
    if self.id ~= 6 or not self.last_move_was_rotate then return false end
    local occupied = 0
    local corners = {{x=0,y=0}, {x=2,y=0}, {x=0,y=2}, {x=2,y=2}}
    for _, c in ipairs(corners) do
        local tx, ty = self.x + c.x, self.y + c.y
        if tx < 1 or tx > 10 or ty > 40 or (ty >= 1 and self.board.grid[ty][tx] ~= 0) then
            occupied = occupied + 1
        end
    end
    return occupied >= 3
end

function Piece:canMove(px, py, pr)
    return self.board:canMove(px, py, pr)
end

function Piece:update(dt, gravity_speed)
    if self.locked then return end
    if self.spawn_timer > 0 then self.spawn_timer = self.spawn_timer - dt end

    CombatStances.applyPieceModifiers(self.board, self)
    local effective_gravity = CombatStances.getGravitySpeed(self.board, gravity_speed)

    if RulesetManager.is20G() then
        effective_gravity = 0.001
    end

    self.gravity_timer = self.gravity_timer + dt
    local limit = self.board.is_zone_active and 999.0 or effective_gravity

    local loop_count = 0
    while self.gravity_timer >= limit do
        loop_count = loop_count + 1
        if not Blackbox.guardLoop("GRAVITY_DROP", 40, loop_count) then break end

        if self:move(0, 1, true) then 
            self.gravity_timer = self.gravity_timer - limit
        else 
            self.gravity_timer = 0
            break 
        end
    end

    if not self.board:canMove(self.x, self.y + 1, self.rotation) then
        self.lock_timer = self.lock_timer + dt
        if self.lock_timer >= self.lock_delay then self:lock() end
    else 
        self.lock_timer = 0 
    end
end

function Piece:lock()
    if self.locked then return end
    self.board.can_hold, self.board.lock_impact = true, 1.0

    KineticParry.openWindow(self.board)

    local is_resonance = (self.board.current_stance == 3)
    local groove_hit, bonus_lines = BeatLock.evaluate(self.board, is_resonance)
    self.board.pending_groove_bonus = bonus_lines

    local is_tspin = self:checkTSpin()
    local shape = self.shape[self.rotation]
    local has_mino_in_buffer = false

    for r = 1, #shape do
        for c = 1, #shape[r] do
            if shape[r][c] ~= 0 then
                local tx, ty = self.x + c - 1, self.y + r - 1
                if ty >= 1 and ty <= 40 then 
                    self.board.grid[ty][tx] = self.id
                    if ty <= 20 then
                        has_mino_in_buffer = true
                    end
                end
            end
        end
    end

    self.locked = true
    PPSCounter.register(self.board)
    AudioManager.playImmediateSFX("drop", self.board.player_type == "bot", self.y)

    Blackbox.log(
        (self.board.player_type == "human") and "P1_LOCK" or "BOT_LOCK",
        (is_tspin and "TSPIN LOCK" or "STD LOCK"),
        self.id,
        self.y
    )

    if is_tspin then
        self.board.tspin_flash = 1.0
        self.board:triggerShake(10, 0.35)
        BloomShader.triggerShockwave(self.board.x + 120, self.board.y + 240)
        AudioManager.playSubBassThud(3)
        AudioManager.playVoiceAnnounce("tspin")
    end

    if has_mino_in_buffer and not self.board.is_zone_active then
        Blackbox.log(
            (self.board.player_type == "human") and "P1_DEATH" or "BOT_DEATH",
            "LOCK OUT (MINO IN BUFFER Y<=20)",
            self.id, self.y
        )
        self.board:triggerDeath()
        return
    end

    self.board:checkLines(is_tspin)
end

function Piece:draw(bx, by)
    local shape = self.shape[self.rotation]
    love.graphics.push("all")

    if self.board and bx == self.board.x and by == self.board.y and RulesetManager.allowGhost() then
        local gy = self.y
        local loop_g = 0
        while self.board:canMove(self.x, gy + 1, self.rotation) do 
            gy = gy + 1 
            loop_g = loop_g + 1
            if not Blackbox.guardLoop("GHOST_CALC", 40, loop_g) then break end
        end

        local ghost_alpha_setting = SettingsManager.get("ghost_alpha") or 0.35
        if ghost_alpha_setting > 1.0 then ghost_alpha_setting = ghost_alpha_setting / 100.0 end
        
        ThemeManager.drawGhostPiece(self, bx, by, shape, gy, ghost_alpha_setting)
    end

    for r = 1, #shape do 
        for c = 1, #shape[r] do 
            if shape[r][c] ~= 0 then
                self.board:drawBlock(bx + (self.x + c - 2) * 24, by + (self.y + r - 22) * 24, self.id)
            end 
        end 
    end
    love.graphics.pop()
end

return Piece
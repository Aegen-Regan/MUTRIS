-- ================================================================
-- FILE: tetris/piece.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: TETROMINO PIECE PHYSICS & MULTI-RULESET INTEGRATION
-- ============================================================================
local Piece = {}
Piece.__index = Piece

local AudioManager    = require "audio_manager"
local SettingsManager = require "settings_manager"
local PPSCounter      = require "tetris.pps_counter"
local BeatLock        = require "tetris.beat_lock"
local KineticParry    = require "combat.kinetic_parry"
local BloomShader     = require "tetris.bloom_shader"
local ThemeManager    = require "tetris.theme_manager"
local RulesetManager  = require "core.ruleset_manager"
local Blackbox        = require "core.blackbox"
local EventBus        = require "core.event_bus"

function Piece.new(id, board)
    local self = setmetatable({}, Piece)
    self.id, self.board = id, board

    local shapes = RulesetManager.getShapes(id)
    self.shape = shapes or { {{1,1,1,1}} }
    self.rotation = 1
    self.x = board and (math.floor(board.cols / 2) - 1) or 4
    self.y = board and (board.visible_rows + 1) or 21
    self.locked, self.gravity_timer, self.lock_timer = false, 0, 0

    self.lock_delay = RulesetManager.getLockDelay() or 0.50
    self.move_count = 0
    self.max_resets = RulesetManager.getCurrent().max_lock_resets

    self.spawn_timer = 0.2
    self.last_move_was_rotate = false

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
            EventBus.emit(EventBus.ON_PIECE_MOVE, self.id, dx, dy, self.board.player_type == "human" and 1 or 2)
            
            if self.board.is_boss then
                self.board:triggerShake(6, 0.15)
                AudioManager.playSubBassThud(1)
            end
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
                EventBus.emit(EventBus.ON_PIECE_ROTATE, self.id, next_rot, self.board.player_type == "human" and 1 or 2)
                
                if self.board.is_boss then
                    self.board:triggerShake(8, 0.20)
                    AudioManager.playSubBassThud(2)
                end
                
                return true
            end
        end
    end
    return false
end

function Piece:checkTSpin()
    if self.id ~= 6 or not self.last_move_was_rotate or not self.board then return false end
    
    local occupied = 0
    local b = self.board
    local g = b.grid
    local cols, rows = b.cols, b.rows
    local px, py = self.x, self.y

    local x1, y1 = px, py
    local x2, y2 = px + 2, py
    local x3, y3 = px, py + 2
    local x4, y4 = px + 2, py + 2

    if x1 < 1 or x1 > cols or y1 > rows or (y1 >= 1 and g[y1][x1] ~= 0) then occupied = occupied + 1 end
    if x2 < 1 or x2 > cols or y2 > rows or (y2 >= 1 and g[y2][x2] ~= 0) then occupied = occupied + 1 end
    if x3 < 1 or x3 > cols or y3 > rows or (y3 >= 1 and g[y3][x3] ~= 0) then occupied = occupied + 1 end
    if x4 < 1 or x4 > cols or y4 > rows or (y4 >= 1 and g[y4][x4] ~= 0) then occupied = occupied + 1 end

    return occupied >= 3
end

function Piece:canMove(px, py, pr)
    return self.board:canMove(px, py, pr)
end

function Piece:update(dt, gravity_speed)
    if self.locked then return end
    if self.spawn_timer > 0 then self.spawn_timer = self.spawn_timer - dt end

    local effective_gravity = gravity_speed or 0.8
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

    local groove_hit, bonus_lines = BeatLock.evaluate(self.board)
    self.board.pending_groove_bonus = bonus_lines

    local is_tspin = self:checkTSpin()
    local shape = self.shape[self.rotation]
    local has_mino_in_buffer = false

    local lock_x = self.x
    local lock_y = self.y
    local lock_rot = self.rotation

    for r = 1, #shape do
        for c = 1, #shape[r] do
            if shape[r][c] ~= 0 then
                local tx, ty = self.x + c - 1, self.y + r - 1
                if ty >= 1 and ty <= self.board.rows then 
                    self.board.grid[ty][tx] = self.id
                    if ty <= self.board.visible_rows then
                        has_mino_in_buffer = true
                    end
                end
            end
        end
    end

    self.locked = true
    self.board.pieces_placed = self.board.pieces_placed + 1
    PPSCounter.register(self.board)
    AudioManager.playImmediateSFX("drop", self.board.player_type == "bot", self.y)

    if self.board.is_boss then
        _G.HitStopTimer = 0.20
        self.board:triggerShake(22, 0.60)
        AudioManager.playSubBassThud(4)
    end

    Blackbox.log(
        (self.board.player_type == "human") and "P1_LOCK" or "BOT_LOCK",
        (is_tspin and "TSPIN LOCK" or "STD LOCK"),
        self.id,
        self.y
    )

    EventBus.emit(EventBus.ON_PIECE_LOCK, self.id, lock_x, lock_y, lock_rot, self.board.player_type == "human" and 1 or 2)

    if is_tspin then
        self.board.tspin_flash = 1.0
        self.board:triggerShake(10, 0.35)
        local bs = self.board.block_size or 24
        BloomShader.triggerShockwave(self.board.x + (self.board.cols * bs * 0.5), self.board.y + (self.board.visible_rows * bs * 0.5))
        AudioManager.playSubBassThud(3)
        AudioManager.playVoiceAnnounce("tspin")
    end

    if has_mino_in_buffer and not self.board.is_zone_active then
        Blackbox.log(
            (self.board.player_type == "human") and "P1_DEATH" or "BOT_DEATH",
            "LOCK OUT (MINO IN BUFFER Y<=" .. tostring(self.board.visible_rows) .. ")",
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

    local bs = self.board and self.board.block_size or 24
    for r = 1, #shape do 
        for c = 1, #shape[r] do 
            if shape[r][c] ~= 0 then
                self.board:drawBlock(bx + (self.x + c - 2) * bs, by + (self.y + r - (self.board.visible_rows + 2)) * bs, self.id)
            end 
        end 
    end
    love.graphics.pop()
end

return Piece
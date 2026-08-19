---@diagnostic disable: undefined-global
local Piece = {}
Piece.__index = Piece

local AudioManager = require "audio_manager"
local PPSCounter = require "tetris.pps_counter"

function Piece.new(id, board)
    local self = setmetatable({}, Piece)
    self.id = id
    self.board = board

    local SRS = require "tetris.rotation_systems.srs"
    if SRS and SRS.shapes and SRS.shapes[id] then
        self.shape = SRS.shapes[id]
    else
        self.shape = { {{1,1,1,1}} }
    end

    self.rotation = 1
    self.x = 4
    self.y = 21
    self.locked = false

    self.gravity_timer = 0
    self.lock_timer = 0
    self.lock_delay = 0.5
    self.move_count = 0
    self.max_resets = 15
    self.spawn_timer = 0.1 -- Duración del destello al aparecer

    return self
end

function Piece:resetLock()
    if self.move_count < self.max_resets then
        self.lock_timer = 0
        self.move_count = self.move_count + 1
    end
end

function Piece:move(dx, dy, is_gravity)
    if self:canMove(self.x + dx, self.y + dy, self.rotation) then
        self.x = self.x + dx
        self.y = self.y + dy
        if not is_gravity then
            AudioManager.playImmediateSFX("move", self.board.player_type == "bot")
            self:resetLock()
        end
        return true
    end
    return false
end

function Piece:rotate(dir)
    local SRS = require "tetris.rotation_systems.srs"
    local max_rot = #self.shape
    local old_rot = self.rotation
    local next_rot = ((self.rotation + dir - 1) % max_rot) + 1

    local kicks = SRS.getKicks(self.id, old_rot, next_rot)
    if kicks then
        for _, kick in ipairs(kicks) do
            if self:canMove(self.x + kick[1], self.y - kick[2], next_rot) then
                self.x = self.x + kick[1]
                self.y = self.y - kick[2]
                self.rotation = next_rot
                AudioManager.playImmediateSFX("rotate", self.board.player_type == "bot")
                self:resetLock()
                return true
            end
        end
    end
    return false
end

function Piece:canMove(px, py, pr)
    return self.board:canMove(px, py, pr)
end

function Piece:update(dt, gravity_speed)
    if self.locked then return end
    
    if self.spawn_timer > 0 then self.spawn_timer = self.spawn_timer - dt end

    self.gravity_timer = self.gravity_timer + dt
    local limit = gravity_speed or 0.8
    while self.gravity_timer >= limit do
        if self:move(0, 1, true) then 
            self.gravity_timer = self.gravity_timer - limit
        else
            self.gravity_timer = 0
            break
        end
    end

    if not self:canMove(self.x, self.y + 1, self.rotation) then
        self.lock_timer = self.lock_timer + dt
        if self.lock_timer >= self.lock_delay then self:lock() end
    else
        self.lock_timer = 0
    end
end

function Piece:lock()
    if self.locked then return end
    self.board.can_hold = true
    self.board.lock_impact = 1.0 -- Dispara la reacción de los bloques fijos

    local shape = self.shape[self.rotation]
    for r = 1, #shape do
        for c = 1, #shape[r] do
            if shape[r][c] ~= 0 then
                local tx = self.x + c - 1
                local ty = self.y + r - 1
                if ty >= 1 and ty <= 40 then
                    self.board.grid[ty][tx] = self.id
                end
            end
        end
    end
    self.locked = true

    PPSCounter.register(self.board)
    AudioManager.playImmediateSFX("drop", self.board.player_type == "bot", self.y)
    if _G.NotifyPieceLock then _G.NotifyPieceLock() end
    self.board:checkLines()
end

function Piece:draw(bx, by)
    local shape = self.shape[self.rotation]
    local energy = _G.TrackEnergyPunch or 0
    local pulse = _G.AudioBeatPulse or 0
    love.graphics.push("all")

    -- 1. EFECTO DE SPAWN (Bloom)
    if self.spawn_timer > 0 then
        love.graphics.setBlendMode("add")
        local spawn_a = (self.spawn_timer / 0.1) * 0.5
        love.graphics.setColor(1, 1, 1, spawn_a)
        for r = 1, #shape do
            for c = 1, #shape[r] do
                if shape[r][c] ~= 0 then
                    love.graphics.circle("fill", bx + (self.x + c - 2) * 24 + 12, by + (self.y + r - 22) * 24 + 12, 18)
                end
            end
        end
        love.graphics.setBlendMode("alpha")
    end

    -- 2. GHOST PIECE AURA (Tetris Effect Style)
    if self.board and bx == self.board.x and by == self.board.y then
        local gy = self.y
        while self.board:canMove(self.x, gy + 1, self.rotation) do gy = gy + 1 end
        local clr = self.board.colors[self.id] or {1, 1, 1}
        
        love.graphics.setBlendMode("add")
        for r = 1, #shape do
            for c = 1, #shape[r] do
                if shape[r][c] ~= 0 then
                    local px = bx + (self.x + c - 2) * 24 + 12
                    local py = by + (gy + r - 22) * 24 + 12
                    local aura = 0.05 + (energy * 0.15) + (pulse * 0.1)
                    love.graphics.setColor(clr[1], clr[2], clr[3], aura * 0.4)
                    love.graphics.circle("fill", px, py, 14 + pulse * 6)
                    love.graphics.setColor(1, 1, 1, aura * 0.8)
                    love.graphics.rectangle("fill", px-2, py-2, 4, 4)
                end
            end
        end
        love.graphics.setBlendMode("alpha")
    end

    -- 3. PIEZA REAL
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
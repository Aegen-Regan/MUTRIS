---@diagnostic disable: undefined-global, param-type-mismatch
local Board = {}
Board.__index = Board

local Piece = require "tetris.piece"
local GarbageManager = require "tetris.garbage_manager"
local AudioManager = require "audio_manager"
local SRS = require "tetris.rotation_systems.srs"

local PPSCounter = require "tetris.pps_counter"
local Shaker = require "tetris.shaker"
local HUDPanels = require "tetris.hud_panels"
local ParticleSystem = require "tetris.particle_system"

function Board.new(x, y, player_type, colors)
    local self = setmetatable({}, Board)
    self.x, self.y, self.player_type = x, y, player_type

    self.colors = colors or {
        {0, 0.9, 0.9}, {0, 0.4, 0.9}, {0.9, 0.5, 0}, {0.9, 0.9, 0},
        {0, 0.9, 0}, {0.6, 0, 0.9}, {0.9, 0, 0}, {0.5, 0.5, 0.5}
    }

    self.grid = {}
    for i = 1, 40 do
        self.grid[i] = {0,0,0,0,0,0,0,0,0,0}
    end

    self.spawn_blocked = false
    self.combo = -1
    self.b2b = 0
    self.zone_meter = 0
    self.is_zone_active = false
    self.zone_lines = 0

    self.drop_flash = { x = 0, timer = 0 }
    self.line_clear_flash = {}
    self.garbage_queue = {}
    
    self.hold_piece = nil
    self.can_hold = true
    
    ParticleSystem.init(self)
    PPSCounter.init(self)
    return self
end

function Board:update(dt)
    Shaker.update(self, dt)
    ParticleSystem.update(self, dt)
    
    if self.drop_flash.timer > 0 then self.drop_flash.timer = self.drop_flash.timer - dt end
    for r, t in pairs(self.line_clear_flash) do
        if t > 0 then self.line_clear_flash[r] = t - dt else self.line_clear_flash[r] = nil end
    end

    if self.is_zone_active then
        self.zone_meter = self.zone_meter - dt * 20
        if self.zone_meter <= 0 then self:exitZone() end
    end

    -- FIX: Limpieza estricta de variables de diagnóstico sin dt redundante
    PPSCounter.update(self)
end

function Board:enterZone()
    if self.zone_meter >= 25 and not self.is_zone_active then
        self.is_zone_active = true
        self.zone_lines = 0
    end
end

function Board:exitZone()
    if self.zone_lines > 0 then
        local attack = math.floor(self.zone_lines * 1.5)
        GarbageManager.sendGarbage(self, self.opponent, attack)
        self:triggerShake(12, 0.6)
    end
    self.is_zone_active = false
    self.zone_lines, self.zone_meter = 0, 0
end

function Board:canMove(px, py, pr)
    if not self.active_piece or not self.active_piece.shape then return false end
    local shape = self.active_piece.shape[pr]
    if not shape then return false end
    
    for r = 1, #shape do
        for c = 1, #shape[r] do
            if shape[r][c] ~= 0 then
                local tx = px + c - 1
                local ty = py + r - 1
                if tx < 1 or tx > 10 or ty > 40 then return false end
                if ty >= 1 and self.grid[ty] and self.grid[ty][tx] ~= 0 then return false end
            end
        end
    end
    return true
end
function Board:checkLines()
    local lines = {}
    local start_scan = self.is_zone_active and 1 or 21
    for r = start_scan, 40 do
        local full = true
        for c = 1, 10 do
            if self.grid[r][c] == 0 then full = false; break end
        end
        if full then table.insert(lines, r) end
    end

    if #lines > 0 then
        if self.is_zone_active then
            self.zone_lines = self.zone_lines + #lines
            for _, r in ipairs(lines) do
                self.line_clear_flash[r] = 0.15
                self.grid[r] = {8,8,8,8,8,8,8,8,8,8}
            end
            AudioManager.playImmediateSFX("line_clear", (self.player_type == "bot"))
        else
            self.combo = self.combo + 1
            self.zone_meter = math.min(100, self.zone_meter + #lines * 6)
            local attack = GarbageManager.calculateAttack(#lines, false, false, self.combo, self.b2b)
            if #lines == 4 then self.b2b = self.b2b + 1 else self.b2b = 0 end
            GarbageManager.sendGarbage(self, self.opponent, attack)
            
            for _, r in ipairs(lines) do
                local sample_id = 1
                if self.grid[r] and self.grid[r] ~= 0 then sample_id = self.grid[r] end
                ParticleSystem.spawnLineBlast(self, r, sample_id)
                table.remove(self.grid, r)
                table.insert(self.grid, 1, {0,0,0,0,0,0,0,0,0,0})
            end
            self:triggerShake(#lines * 4, 0.2)
        end
    else
        if not self.is_zone_active then self.combo = -1 end
    end
end

function Board:hold()
    if not self.can_hold then return end
    local current_id = self.active_piece.id
    if not self.hold_piece then
        self.hold_piece = Piece.new(current_id, self)
        self.active_piece = Piece.new(self.bag:next(), self)
    else
        local next_id = self.hold_piece.id
        self.hold_piece = Piece.new(current_id, self)
        self.active_piece = Piece.new(next_id, self)
    end
    self.can_hold = false
end

function Board:triggerShake(mag, dur)
    self.shake_mag = mag
    self.shake_time = dur
end

function Board:drawBlock(bx, by, id, alpha)
    local clr = self.colors[id] or {1.0, 1.0, 1.0}
    local pulse = _G.AudioBeatPulse or 0
    local a = alpha or 1.0
    
    local r_mod = math.min(1.0, (clr[1] or 1.0) + pulse * 0.15)
    local g_mod = math.min(1.0, (clr[2] or 1.0) + pulse * 0.15)
    local b_mod = math.min(1.0, (clr[3] or 1.0) + pulse * 0.15)
    
    love.graphics.setColor(r_mod, g_mod, b_mod, a)
    love.graphics.rectangle("fill", bx, by, 24, 24)
    love.graphics.setColor(1, 1, 1, a * 0.28)
    love.graphics.rectangle("fill", bx + 1, by + 1, 22, 4)
    love.graphics.rectangle("fill", bx + 1, by + 1, 4, 22)
    love.graphics.setColor(0, 0, 0, a * 0.35)
    love.graphics.rectangle("line", bx, by, 24, 24)
end

function Board:draw()
    local active_punch = _G.TrackEnergyPunch or 0
    local pulse = _G.AudioBeatPulse or 0
    
    love.graphics.push("all")
    Shaker.apply(self)
    
    love.graphics.setColor(0.005, 0.005, 0.01, 0.93)
    love.graphics.rectangle("fill", self.x, self.y, 240, 480)
    
    local grid_alpha = 0.02 + (active_punch * 0.04) + (pulse * 0.04)
    love.graphics.setColor(0, 0.8, 1, grid_alpha)
    for c = 1, 9 do love.graphics.line(self.x + c * 24, self.y, self.x + c * 24, self.y + 480) end
    for r = 1, 19 do love.graphics.line(self.x, self.y + r * 24, self.x + 240, self.y + r * 24) end

    for r = 21, 40 do
        for c = 1, 10 do
            local id = self.grid[r][c]
            if id and id ~= 0 then 
                self:drawBlock(self.x + (c - 1) * 24, self.y + (r - 21) * 24, id) 
            end
        end
    end

    if self.drop_flash.timer > 0 then
        love.graphics.setColor(1, 1, 1, self.drop_flash.timer * 0.45)
        love.graphics.rectangle("fill", self.x + (self.drop_flash.x - 1) * 24, self.y, 24, 480)
    end

    local frame_pulse = 1 + (pulse * 0.12)
    if active_punch >= 0.50 then
        frame_pulse = frame_pulse + (pulse * 0.08) * ((active_punch - 0.50) / 0.50)
    end
    
    love.graphics.setLineWidth(2.2 * frame_pulse)
    
    if self.is_zone_active then
        love.graphics.setColor(0, 0.8, 1, 0.85 + math.sin(love.timer.getTime() * 15) * 0.1)
    elseif active_punch >= 0.95 then
        local hue = love.timer.getTime() * 4
        love.graphics.setColor(0.5+0.5*math.sin(hue), 0.5+0.5*math.sin(hue+2), 0.5+0.5*math.sin(hue+4), 0.85)
    else
        love.graphics.setColor(0.12 * pulse, 0.3 * pulse, 0.5 + (pulse * 0.5), 0.3 + (pulse * 0.5))
    end
    
    local offset = (frame_pulse - 1) * 3
    love.graphics.rectangle("line", self.x - 2 - offset, self.y - 2 - offset, 244 + offset*2, 484 + offset*2)
    love.graphics.setLineWidth(1)

    -- INDICADOR DE BASURA NEÓN INTERNO (ESTILO JSTRIS VISIBLE)
    local total_garbage = 0
    if self.garbage_queue then
        for _, amt in ipairs(self.garbage_queue) do total_garbage = total_garbage + amt end
    end

    if total_garbage > 0 then
        local gauge_w = 6
        local gauge_x = (self.player_type == "human") and (self.x + 2) or (self.x + 240 - 8)
        local max_visible_lines = 20
        local fill_height = math.min(480, (total_garbage / max_visible_lines) * 480)
        
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", gauge_x, self.y, gauge_w, 480)
        
        local flash_alert = 0.65 + math.sin(love.timer.getTime() * 22) * 0.35
        love.graphics.setColor(1, 0.05, 0.1, flash_alert)
        love.graphics.rectangle("fill", gauge_x, self.y + 480 - fill_height, gauge_w, fill_height)
    end

    if self.zone_meter then
        local bar_w = (self.zone_meter / 100) * 240
        love.graphics.setColor(0.1, 0.1, 0.15, 0.5)
        love.graphics.rectangle("fill", self.x, self.y + 488, 240, 4)
        love.graphics.setColor(self.is_zone_active and {1,1,1} or {0, 0.7, 1, 0.8})
        love.graphics.rectangle("fill", self.x, self.y + 488, bar_w, 4)
    end

    HUDPanels.draw(self)
    ParticleSystem.draw(self)
    love.graphics.pop()
end

return Board

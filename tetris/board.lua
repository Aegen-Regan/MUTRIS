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
        {0, 1, 1}, {0, 0.5, 1}, {1, 0.5, 0}, {1, 1, 0},
        {0, 1, 0}, {0.8, 0, 1}, {1, 0, 0}, {0.5, 0.5, 0.5}
    }
    self.grid = {}
    for i = 1, 40 do self.grid[i] = {0,0,0,0,0,0,0,0,0,0} end
    self.combo, self.b2b = -1, 0
    self.zone_meter, self.is_zone_active, self.zone_lines = 0, false, 0
    self.drop_flash = { x = 0, timer = 0 }
    self.garbage_queue = {}
    self.hold_piece, self.can_hold = nil, true
    self.popup_text, self.popup_timer, self.popup_color = "", 0, {1, 1, 1}
    ParticleSystem.init(self)
    PPSCounter.init(self)
    return self
end

function Board:update(dt)
    Shaker.update(self, dt)
    ParticleSystem.update(self, dt)
    if self.drop_flash.timer > 0 then self.drop_flash.timer = self.drop_flash.timer - dt end
    if self.popup_timer > 0 then self.popup_timer = self.popup_timer - dt end
    if self.is_zone_active then
        self.zone_meter = self.zone_meter - dt * 20
        if self.zone_meter <= 0 then self:exitZone() end
    end
    PPSCounter.update(self)
end

function Board:setPopup(text, color)
    self.popup_text, self.popup_timer, self.popup_color = text, 1.3, color or {1, 1, 1}
end

function Board:triggerShake(mag, dur)
    local energy = _G.TrackEnergyPunch or 0
    self.shake_mag = mag * (1 + energy * 1.5)
    self.shake_time = dur
end

function Board:drawBlock(bx, by, id, alpha)
    local clr = self.colors[id] or {1, 1, 1}
    local pulse = _G.AudioBeatPulse or 0
    local energy = _G.TrackEnergyPunch or 0
    local a = alpha or 1.0
    
    -- ESTILO DISCO: Cuerpo más oscuro para que la Ghost resalte
    local r, g, b = clr[1] * 0.35, clr[2] * 0.35, clr[3] * 0.35
    local neon_boost = pulse * (0.05 + energy * 0.45)
    
    love.graphics.setColor(r + neon_boost, g + neon_boost, b + neon_boost, a)
    love.graphics.rectangle("fill", bx, by, 24, 24)
    
    -- Brillo Neón Sutil
    local shine = a * (0.1 + pulse * 0.2 + energy * 0.1)
    love.graphics.setColor(1, 1, 1, shine)
    love.graphics.rectangle("fill", bx + 2, by + 2, 20, 2)
    
    -- Borde Neon Eléctrico (Este es el que da el color de la pieza activa)
    love.graphics.setColor(clr[1], clr[2], clr[3], a * (0.4 + pulse * 0.5))
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", bx, by, 24, 24)
end

function Board:draw()
    local energy = _G.TrackEnergyPunch or 0
    local pulse = _G.AudioBeatPulse or 0
    
    love.graphics.push("all")
    Shaker.apply(self)
    
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", self.x, self.y, 240, 480)
    
    -- Grilla Progresiva
    local grid_a = 0.02 + (energy * 0.05) + (pulse * 0.03)
    love.graphics.setColor(0, 0.8, 1, grid_a)
    for c = 0, 10 do love.graphics.line(self.x + c*24, self.y, self.x + c*24, self.y + 480) end
    for r = 0, 20 do love.graphics.line(self.x, self.y + r*24, self.x + 240, self.y + r*24) end

    for r = 21, 40 do
        for c = 1, 10 do
            local id = self.grid[r][c]
            if id ~= 0 then self:drawBlock(self.x + (c-1)*24, self.y + (r-21)*24, id) end
        end
    end

    -- Marco Neon Dinámico
    local thick = 1 + (energy * 2.5) + (pulse * 2)
    love.graphics.setLineWidth(thick)
    if energy >= 0.95 then
        local t = love.timer.getTime() * 5
        love.graphics.setColor(math.abs(math.sin(t)), math.abs(math.sin(t+2)), math.abs(math.sin(t+4)), 0.8)
    else
        love.graphics.setColor(0, 0.6, 1, 0.4 + pulse * 0.4)
    end
    love.graphics.rectangle("line", self.x - 2, self.y - 2, 244, 484)
    love.graphics.setLineWidth(1)

    -- Popups Punch Centrados
    if self.popup_timer > 0 then
        local alpha = math.min(1, self.popup_timer * 3)
        love.graphics.setColor(self.popup_color[1], self.popup_color[2], self.popup_color[3], alpha)
        local size = (self.popup_text:find("!") or self.popup_text:find("T-SPIN")) and 22 or 16
        love.graphics.setFont(love.graphics.newFont(size + energy * 5))
        local ty = self.y + 180 - (1.3 - self.popup_timer) * 60
        love.graphics.printf(self.popup_text, self.x, ty, 240, "center")
    end

    -- Alerta Basura
    local total_g = 0
    for _, amt in ipairs(self.garbage_queue) do total_g = total_g + amt end
    if total_g > 0 then
        love.graphics.setColor(1, 0, 0, 0.4 + math.sin(love.timer.getTime()*18)*0.4)
        local h = math.min(480, total_g * 24)
        local gx = (self.player_type == "human") and (self.x - 12) or (self.x + 244)
        love.graphics.rectangle("fill", gx, self.y + 480 - h, 8, h)
    end

    HUDPanels.draw(self)
    ParticleSystem.draw(self)
    love.graphics.pop()
end

function Board:canMove(px, py, pr)
    if not self.active_piece or not self.active_piece.shape then return false end
    local shape = self.active_piece.shape[pr]
    for r = 1, #shape do
        for c = 1, #shape[r] do
            if shape[r][c] ~= 0 then
                local tx, ty = px + c - 1, py + r - 1
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
        for c = 1, 10 do if self.grid[r][c] == 0 then full = false; break end end
        if full then table.insert(lines, r) end
    end
    if #lines > 0 then
        if self.is_zone_active then
            self.zone_lines = self.zone_lines + #lines
            for _, r in ipairs(lines) do self.grid[r] = {8,8,8,8,8,8,8,8,8,8} end
        else
            self.combo = self.combo + 1
            self.zone_meter = math.min(100, self.zone_meter + #lines * 6)
            local attack = GarbageManager.calculateAttack(#lines, false, false, self.combo, self.b2b, self)
            if #lines == 4 then self.b2b = self.b2b + 1 else self.b2b = 0 end
            GarbageManager.sendGarbage(self, self.opponent, attack)
            for _, r in ipairs(lines) do
                local color_id = self.grid[r][1] or 1
                ParticleSystem.spawnLineBlast(self, r, color_id)
                table.remove(self.grid, r)
                table.insert(self.grid, 1, {0,0,0,0,0,0,0,0,0,0})
            end
            self:triggerShake(#lines * 5, 0.25)
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
    self.can_hold, self.active_piece.spawn_timer = false, 0
end

return Board
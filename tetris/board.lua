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
    self.garbage_queue = {}
    self.hold_piece, self.can_hold = nil, true
    self.popup_text, self.popup_timer, self.popup_color = "", 0, {1, 1, 1}

    self.lock_impact = 0
    self.trail_duration = 0.45
    self.trails = {}
    for i = 1, 8 do 
        self.trails[i] = { active = false, x = 0, y_start = 0, y_end = 0, id = 0, timer = 0, shape = nil, particles = {} }
        for p=1, 12 do self.trails[i].particles[p] = {y = 0, speed = 0, offset = 0, size = 0} end
    end

    ParticleSystem.init(self)
    PPSCounter.init(self)
    return self
end

function Board:spawnTrail(x, y_start, y_end, id, shape)
    for i = 1, #self.trails do
        if not self.trails[i].active then
            local t = self.trails[i]
            t.active, t.x, t.y_start, t.y_end = true, x, y_start, y_end
            t.id, t.shape, t.timer = id, shape, self.trail_duration
            for p=1, #t.particles do
                t.particles[p].y = math.random(y_start * 24, y_end * 24)
                t.particles[p].speed = math.random(100, 300)
                t.particles[p].offset = math.random(-10, 10)
                t.particles[p].size = math.random(1, 2)
            end
            break
        end
    end
end

function Board:update(dt)
    Shaker.update(self, dt)
    ParticleSystem.update(self, dt)
    if self.popup_timer > 0 then self.popup_timer = self.popup_timer - dt end
    if self.lock_impact > 0 then self.lock_impact = math.max(0, self.lock_impact - dt * 4) end

    for i = 1, #self.trails do
        local t = self.trails[i]
        if t.active then
            t.timer = t.timer - dt
            for p=1, #t.particles do t.particles[p].y = t.particles[p].y + t.particles[p].speed * dt end
            if t.timer <= 0 then t.active = false end
        end
    end
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

-- DISEÑO DE BLOQUE DEFINIDO Y CRISTALINO
function Board:drawBlock(bx, by, id, alpha)
    local clr = self.colors[id] or {1, 1, 1}
    local pulse = _G.AudioBeatPulse or 0
    local energy = _G.TrackEnergyPunch or 0
    local a = alpha or 1.0
    
    local scale = 1 + (self.lock_impact * 0.1) + (pulse * 0.03 * energy)
    local ds = 24 * scale
    local off = (ds - 24) / 2

    -- 1. Fondo del bloque (Sólido y oscuro para legibilidad)
    love.graphics.setColor(clr[1]*0.3, clr[2]*0.3, clr[3]*0.3, a)
    love.graphics.rectangle("fill", bx - off, by - off, ds, ds)
    
    -- 2. Brillo tipo "Cristal" (Líneas internas fijas)
    love.graphics.setColor(1, 1, 1, a * (0.2 + pulse * 0.3))
    love.graphics.rectangle("fill", bx + 2 - off, by + 2 - off, ds - 4, 2)
    love.graphics.rectangle("fill", bx + 2 - off, by + 2 - off, 2, ds - 4)

    -- 3. Borde Eléctrico (Define la pieza)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(clr[1], clr[2], clr[3], a * (0.6 + pulse * 0.4))
    love.graphics.rectangle("line", bx - off, by - off, ds, ds)
end

function Board:draw()
    local energy = _G.TrackEnergyPunch or 0
    local pulse = _G.AudioBeatPulse or 0
    
    love.graphics.push("all")
    Shaker.apply(self)
    
    love.graphics.setColor(0, 0, 0, 0.95)
    love.graphics.rectangle("fill", self.x, self.y, 240, 480)
    
    -- --- ESTELAS ADITIVAS ---
    love.graphics.setBlendMode("add")
    for i = 1, #self.trails do
        local t = self.trails[i]
        if t.active then
            local clr = self.colors[t.id] or {1, 1, 1}
            local progress = t.timer / self.trail_duration
            local alpha = progress * progress
            for row = 1, #t.shape do
                for col = 1, #t.shape[row] do
                    if t.shape[row][col] ~= 0 then
                        local dx = self.x + (t.x + col - 2) * 24 + 12
                        local sy = self.y + (t.y_start + row - 22) * 24
                        local ey = self.y + (t.y_end + row - 22) * 24
                        if ey > sy then
                            love.graphics.setColor(clr[1], clr[2], clr[3], alpha * 0.1)
                            love.graphics.rectangle("fill", dx-10, sy, 20, ey-sy)
                            love.graphics.setLineWidth(1)
                            love.graphics.setColor(1, 1, 1, alpha * 0.5)
                            love.graphics.line(dx, sy, dx, ey)
                        end
                    end
                end
            end
        end
    end
    love.graphics.setBlendMode("alpha")

    -- Grilla
    love.graphics.setColor(0, 0.8, 1, 0.02 + energy * 0.03)
    for c = 0, 10 do love.graphics.line(self.x + c*24, self.y, self.x + c*24, self.y + 480) end
    for r = 0, 20 do love.graphics.line(self.x, self.y + r*24, self.x + 240, self.y + r*24) end

    -- Bloques
    for r = 21, 40 do
        for c = 1, 10 do
            local id = self.grid[r][c]
            if id ~= 0 then self:drawBlock(self.x + (c-1)*24, self.y + (r-21)*24, id) end
        end
    end

    -- Marco
    love.graphics.setLineWidth(1 + pulse * 2)
    love.graphics.setColor(0, 0.6, 1, 0.4 + energy * 0.4)
    love.graphics.rectangle("line", self.x - 1, self.y - 1, 242, 482)
    love.graphics.setLineWidth(1)

    -- Popups
    if self.popup_timer > 0 then
        local alpha = math.min(1, self.popup_timer * 3)
        love.graphics.setColor(self.popup_color[1], self.popup_color[2], self.popup_color[3], alpha)
        local size = (self.popup_text:find("!") or self.popup_text:find("T-SPIN")) and 24 or 18
        love.graphics.setFont(love.graphics.newFont(size + energy * 6))
        love.graphics.printf(self.popup_text, self.x, self.y + 200 - (1.3 - self.popup_timer) * 100, 240, "center")
    end

    HUDPanels.draw(self)
    ParticleSystem.draw(self)
    love.graphics.pop()
end

-- (Funciones canMove, checkLines, hold, exitZone, enterZone iguales)
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

function Board:exitZone()
    if self.zone_lines > 0 then
        local attack = math.floor(self.zone_lines * 1.5)
        GarbageManager.sendGarbage(self, self.opponent, attack)
        self:triggerShake(12, 0.6)
    end
    self.is_zone_active, self.zone_lines, self.zone_meter = false, 0, 0
end

function Board:enterZone()
    if self.zone_meter >= 25 and not self.is_zone_active then
        self.is_zone_active, self.zone_lines = true, 0
    end
end

return Board
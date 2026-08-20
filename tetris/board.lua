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
local FontCache = require "tetris.font_cache"

function Board.new(x, y, player_type, colors)
    local self = setmetatable({}, Board)
    self.x, self.y, self.player_type = x, y, player_type
    
    -- PALETA "VIBRANT CANDY" (Agradable y Clara)
    self.colors = colors or {
        {0.1, 0.9, 1.0}, -- I: Cyan
        {0.2, 0.4, 1.0}, -- J: Blue
        {1.0, 0.6, 0.1}, -- L: Orange
        {1.0, 0.9, 0.2}, -- O: Yellow
        {0.3, 1.0, 0.5}, -- S: Green
        {0.8, 0.3, 1.0}, -- T: Purple
        {1.0, 0.2, 0.4}, -- Z: Red
        {0.6, 0.6, 0.7}  -- Garbage: Grey
    }
    
    self.grid = {}
    for i = 1, 40 do self.grid[i] = {0,0,0,0,0,0,0,0,0,0} end
    self.combo, self.b2b = -1, 0
    self.zone_meter, self.is_zone_active, self.zone_lines = 0, false, 0
    self.garbage_queue = {}
    self.hold_piece, self.can_hold = nil, true
    self.popup_text, self.popup_timer, self.popup_color = "", 0, {1, 1, 1}

    self.lock_impact = 0
    self.trail_duration = 0.5
    self.trails = {}
    for i = 1, 8 do 
        self.trails[i] = { active = false, x = 0, y_start = 0, y_end = 0, id = 0, timer = 0, shape = nil }
    end

    self.eq_charge = 0 
    self.eq_power = 0  
    self.eq_flash = 0  
    self.eq_bars = {} 
    for i = 1, 10 do self.eq_bars[i] = 0 end

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
            break
        end
    end
end

function Board:update(dt)
    Shaker.update(self, dt)
    ParticleSystem.update(self, dt)
    if self.popup_timer > 0 then self.popup_timer = self.popup_timer - dt end
    if self.lock_impact > 0 then self.lock_impact = math.max(0, self.lock_impact - dt * 4.0) end

    self.eq_charge = math.max(0, self.eq_charge - dt * 0.35)
    self.eq_power = math.max(0, self.eq_power - dt * 0.4)
    self.eq_flash = math.max(0, self.eq_flash - dt * 2.5)

    local pulse = _G.AudioBeatPulse or 0
    for i = 1, 10 do
        local target = (0.1 + pulse * 0.6 + math.random()*0.2) * self.eq_charge
        self.eq_bars[i] = self.eq_bars[i] + (target - self.eq_bars[i]) * 10 * dt
    end

    for i = 1, #self.trails do
        local t = self.trails[i]
        if t.active then t.timer = t.timer - dt if t.timer <= 0 then t.active = false end end
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

function Board:drawEQBackground()
    local garbage_count = 0
    for _, lines in ipairs(self.garbage_queue) do garbage_count = garbage_count + lines end
    if self.eq_charge <= 0.01 and garbage_count == 0 then return end

    local pulse = _G.AudioBeatPulse or 0
    local time = love.timer.getTime()
    local is_danger = garbage_count > 0
    local is_attacking = self.eq_power > 0.1

    love.graphics.push("all")
    love.graphics.setBlendMode("add")
    
    for c = 1, 10 do
        local bar_val = self.eq_bars[c] * 19
        if is_danger then bar_val = math.max(bar_val, math.min(garbage_count * 2.0, 18)) end
        local bx = self.x + (c - 1) * 24 + 4
        
        for s = 0, 18 do
            if s <= bar_val then
                local sy = self.y + 480 - (s * 25) - 22
                -- EQ más sutil para no tapar las piezas
                local alpha = (0.15 + pulse * 0.25)
                
                if is_danger then
                    local r_pulse = 0.6 + math.sin(time * 12 + c) * 0.4
                    love.graphics.setColor(1.0, 0.1 * r_pulse, 0.1, alpha * 0.7)
                elseif is_attacking then
                    love.graphics.setColor(0.9, 0.2, 1.0, alpha)
                else
                    love.graphics.setColor(0.2, 0.6, 1.0, alpha * self.eq_charge)
                end

                love.graphics.rectangle("fill", bx, sy, 16, 8, 2)
            end
        end
    end
    love.graphics.setBlendMode("alpha")
    love.graphics.pop()
end

function Board:drawBlock(bx, by, id, alpha)
    local clr = self.colors[id] or {1, 1, 1}
    local pulse = _G.AudioBeatPulse or 0
    local energy = _G.TrackEnergyPunch or 0
    local a = alpha or 1.0
    
    local scale = 1 + (self.lock_impact * 0.1) + (pulse * 0.02 * energy)
    local ds = 24 * scale
    local off = (ds - 24) / 2

    -- BLOQUE CRYSTAL (Legibilidad Máxima)
    -- Capa 1: Relleno con el color de la pieza (suave)
    love.graphics.setColor(clr[1], clr[2], clr[3], a * 0.35)
    love.graphics.rectangle("fill", bx - off, by - off, ds, ds, 4)
    
    -- Capa 2: Borde Neón fuerte
    love.graphics.setLineWidth(2)
    love.graphics.setColor(clr[1], clr[2], clr[3], a * (0.8 + pulse * 0.2))
    love.graphics.rectangle("line", bx - off, by - off, ds, ds, 4)

    -- Capa 3: Brillo de cristal superior
    love.graphics.setColor(1, 1, 1, a * (0.2 + pulse * 0.2))
    love.graphics.rectangle("fill", bx + 3 - off, by + 3 - off, ds - 6, 4, 2)
end

function Board:draw()
    local energy = _G.TrackEnergyPunch or 0
    local pulse = _G.AudioBeatPulse or 0
    
    love.graphics.push("all")
    Shaker.apply(self)
    
    love.graphics.setColor(0.01, 0.01, 0.03, 0.95)
    love.graphics.rectangle("fill", self.x, self.y, 240, 480, 4)
    
    self:drawEQBackground()

    -- Grilla sutil
    love.graphics.setColor(1, 1, 1, 0.03 + pulse * 0.03)
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
    love.graphics.setLineWidth(2)
    love.graphics.setColor(0, 0.5, 1, 0.4 + pulse * 0.3)
    love.graphics.rectangle("line", self.x - 2, self.y - 2, 244, 484, 4)

    if self.popup_timer > 0 then
        local alpha = math.min(1, self.popup_timer * 3)
        love.graphics.setColor(self.popup_color[1], self.popup_color[2], self.popup_color[3], alpha)
        love.graphics.setFont(FontCache.get(20 + energy * 8))
        love.graphics.printf(self.popup_text, self.x, self.y + 180, 240, "center")
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

function Board:checkLines(is_tspin)
    local lines = {}
    for r = 21, 40 do
        local full = true
        for c = 1, 10 do if self.grid[r][c] == 0 then full = false; break end end
        if full then table.insert(lines, r) end
    end
    if #lines > 0 then
        self.combo = self.combo + 1
        local attack = GarbageManager.calculateAttack(#lines, is_tspin, false, self.combo, self.b2b, self)
        if #lines == 4 or is_tspin then self.b2b = self.b2b + 1 else self.b2b = 0 end
        GarbageManager.sendGarbage(self, self.opponent, attack)
        for _, r in ipairs(lines) do
            ParticleSystem.spawnLineBlast(self, r, self.grid[r][1] or 1)
            table.remove(self.grid, r)
            table.insert(self.grid, 1, {0,0,0,0,0,0,0,0,0,0})
        end
        self:triggerShake(#lines * 7, 0.3)
    else self.combo = -1 end
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

    -- Chequeo de Game Over: si la pieza recién intercambiada no entra al
    -- spawnear, avisamos a main.lua igual que se hace tras el spawn normal
    -- post-lock (antes el Hold podía dejar una pieza inválida sin detectar derrota).
    if not self.active_piece:canMove(self.active_piece.x, self.active_piece.y, 1) then
        _G.GameOverPending = self.player_type
    end
end

return Board
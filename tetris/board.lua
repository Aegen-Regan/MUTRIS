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
    self.zone_meter = 0.0
    self.is_zone_active = false
    self.zone_tier = 1
    self.zone_timer = 0.0
    self.zone_max_time = 6.0
    self.zone_lines = 0
    self.zone_wave_timer = 0
    self.ultimatris_halo = 0
    
    self.highest_row = 40
    self.danger_level = 0.0
    
    -- SISTEMA DE INTERFERENCIA ESPECTRAL (PHANTOM DUEL - 4 FASES)
    self.phantoms = {}
    for i = 1, 4 do
        self.phantoms[i] = { 
            active = false, x = 4, y = 26, 
            origin_x = 400, origin_y = 260,
            id = 1, shape = nil, timer = 0, max_timer = 2.8, 
            glitch_phase = 0 
        }
    end

    -- SISTEMA DE DESTRUCCIÓN CINEMÁTICA EN CRISTAL
    self.is_dying = false
    self.death_timer = 0.0
    self.death_duration = 1.45
    
    self.shatter_shards = {}
    for i = 1, 350 do
        self.shatter_shards[i] = { 
            active = false, x = 0, y = 0, 
            vx = 0, vy = 0, rot = 0, vrot = 0, 
            w = 10, h = 10, shard_type = 1, id = 1, 
            alpha = 1.0, life = 1.0 
        }
    end
    self.shatter_head = 1

    self.cracks = {}
    for i = 1, 40 do
        self.cracks[i] = { active = false, x1 = 0, y1 = 0, x2 = 0, y2 = 0, alpha = 1.0 }
    end
    
    self.garbage_queue = {}
    self.hold_piece, self.can_hold = nil, true
    self.popup_text, self.popup_timer, self.popup_color = "", 0, {1, 1, 1}

    self.lock_impact = 0
    self.trail_duration = 0.45
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

function Board:shiftColumnsLocal(dir)
    -- Cinta Torus Local: Rota columnas 1 a 10 horizontalmente sin generar basura
    for r = 21, 40 do
        if dir > 0 then
            local last = self.grid[r][10]
            for c = 10, 2, -1 do self.grid[r][c] = self.grid[r][c - 1] end
            self.grid[r][1] = last
        else
            local first = self.grid[r][1]
            for c = 1, 9 do self.grid[r][c] = self.grid[r][c + 1] end
            self.grid[r][10] = first
        end
    end
end

function Board:shiftColumnsGlobal(target_board, dir)
    -- Cinta Global Cruzada: Anillo continuo de 20 columnas compartido entre ambos jugadores
    for r = 21, 40 do
        if dir > 0 then
            local p_last = self.grid[r][10]
            local b_last = target_board.grid[r][10]
            
            for c = 10, 2, -1 do self.grid[r][c] = self.grid[r][c - 1] end
            for c = 10, 2, -1 do target_board.grid[r][c] = target_board.grid[r][c - 1] end
            
            target_board.grid[r][1] = p_last
            self.grid[r][1] = b_last
        end
    end
end

function Board:swapGrids(target_board)
    -- Intercambio completo de matrices en la anomalía Matrix Swap
    for r = 1, 40 do
        for c = 1, 10 do
            local temp = self.grid[r][c]
            self.grid[r][c] = target_board.grid[r][c]
            target_board.grid[r][c] = temp
        end
    end
    self:setPopup("⚠ MATRIX SWAP!", {1.0, 0.85, 0.2})
    target_board:setPopup("⚠ MATRIX SWAP!", {1.0, 0.85, 0.2})
end

function Board:spawnPhantom(x, y, id, shape, origin_x, origin_y)
    for i = 1, #self.phantoms do
        local ph = self.phantoms[i]
        if not ph.active then
            ph.active = true
            ph.x = math.max(1, math.min(7, x or 4))
            ph.y = math.max(22, math.min(34, y or 28))
            ph.origin_x = origin_x or (self.opponent and (self.opponent.x + 120) or 400)
            ph.origin_y = origin_y or (self.opponent and (self.opponent.y + 240) or 260)
            ph.id = id or 1
            ph.shape = shape or SRS.shapes[ph.id][1]
            ph.timer = ph.max_timer
            ph.glitch_phase = math.random() * 10
            
            self:setPopup("⚠ GHOST INTRUSION!", {0.9, 0.2, 1.0})
            self:triggerShake(10, 0.35)
            AudioManager.triggerGlitch(0.25)
            break
        end
    end
end

function Board:dispelOnePhantom()
    -- Regla de Juego Justo: Limpiar líneas disipa 1 fantasma de tu pantalla
    for i = 1, #self.phantoms do
        local ph = self.phantoms[i]
        if ph.active then
            ph.active = false
            self:setPopup("PHANTOM DISPELLED!", {0.2, 0.95, 1.0})
            break
        end
    end
end

function Board:enterZone()
    if self.is_dying then return end
    if self.zone_meter >= 0.25 and not self.is_zone_active then
        self.zone_tier = (self.zone_meter >= 0.999) and 2 or 1
        self.is_zone_active = true
        
        -- FASE 0: PHANTOM EXORCISM (Purga defensiva que absorbe energía)
        local purged_count = 0
        for i = 1, #self.phantoms do
            if self.phantoms[i].active then
                self.phantoms[i].active = false
                purged_count = purged_count + 1
            end
        end
        
        local bonus_time = purged_count * 0.8
        self.zone_timer = (self.zone_max_time * self.zone_meter) + bonus_time
        self.zone_lines = 0
        self.zone_wave_timer = 0
        AudioManager.zone_active = true
        
        if self.zone_tier == 2 then
            AudioManager.playImmediateSFX("zone_enter_hyper", self.player_type == "bot")
            self:setPopup("HYPER ZONE (100%)", {1.0, 0.9, 0.3})
            self:triggerShake(12, 0.45)
            ParticleSystem.spawnSupernova(self, {1.0, 0.9, 0.3})
        else
            AudioManager.playImmediateSFX("zone_enter", self.player_type == "bot")
            local msg = (purged_count > 0) and ("ZONE EXORCISM +" .. string.format("%.1fs", bonus_time)) or "ZONE ACTIVE"
            self:setPopup(msg, {0.1, 0.9, 1.0})
            self:triggerShake(8, 0.3)
        end
    end
end

function Board:checkPerfectClear()
    for r = 21, 40 do
        for c = 1, 10 do
            if self.grid[r][c] ~= 0 then return false end
        end
    end
    return true
end

function Board:exitZone()
    local was_hyper = (self.zone_tier == 2)
    self.is_zone_active = false
    self.zone_tier = 1
    self.zone_meter = 0.0
    self.zone_timer = 0.0
    AudioManager.zone_active = false

    local is_pc = self:checkPerfectClear()
    local attack, title, col = GarbageManager.calculateZoneBurst(self.zone_lines, is_pc, was_hyper)
    
    if attack > 0 and self.opponent then
        GarbageManager.sendGarbage(self, self.opponent, attack)
        self:setPopup(title, col)
        
        -- FASE 2: PHANTOM STORM (Enjambre según el rango de Zone)
        local storm_count = 1
        if self.zone_lines >= 16 or was_hyper or is_pc then
            storm_count = 4
        elseif self.zone_lines >= 12 then
            storm_count = 3
        elseif self.zone_lines >= 8 then
            storm_count = 2
        end

        for s = 1, storm_count do
            self.opponent:spawnPhantom(math.random(1, 7), math.random(22, 34), math.random(1, 7))
        end
        
        if is_pc or self.zone_lines >= 20 or was_hyper then
            self.ultimatris_halo = 1.0
            _G.HitStopTimer = 0.22
            ParticleSystem.spawnSupernova(self, col)
            AudioManager.playImmediateSFX("ultimatris", self.player_type == "bot")
            self:triggerShake(22, 0.6)
        else
            self:triggerShake(14, 0.4)
            AudioManager.playImmediateSFX("tetris", self.player_type == "bot")
        end
    end
    self.zone_lines = 0
end

function Board:triggerDeath()
    if self.is_dying then return end
    self.is_dying = true
    self.death_timer = self.death_duration
    self.is_zone_active = false
    
    for i = 1, 40 do
        local c = self.cracks[i]
        c.active = true
        c.x1 = self.x + math.random(10, 230)
        c.y1 = self.y + math.random(80, 470)
        c.x2 = c.x1 + math.random(-45, 45)
        c.y2 = c.y1 + math.random(-55, 55)
        c.alpha = 1.0
    end

    self.shatter_head = 1
    for r = 21, 40 do
        for col = 1, 10 do
            local id = self.grid[r][col]
            if id ~= 0 then
                local bx = self.x + (col - 1) * 24 + 12
                local by = self.y + (r - 21) * 24 + 12
                
                for shard_idx = 1, 3 do
                    local s = self.shatter_shards[self.shatter_head]
                    s.active = true
                    s.x = bx + math.random(-6, 6)
                    s.y = by + math.random(-6, 6)
                    
                    local angle = math.random() * math.pi * 2
                    local speed = math.random(160, 520)
                    s.vx = math.cos(angle) * speed + math.random(-60, 60)
                    s.vy = math.sin(angle) * speed - math.random(120, 320)
                    s.rot = math.random() * math.pi * 2
                    s.vrot = (math.random() - 0.5) * 18.0
                    s.w = math.random(6, 14)
                    s.h = math.random(8, 18)
                    s.shard_type = math.random(1, 4)
                    s.id = id
                    s.alpha = 1.0
                    s.life = 1.0

                    self.shatter_head = (self.shatter_head % 350) + 1
                end
                self.grid[r][col] = 0
            end
        end
    end

    _G.HitStopTimer = 0.35
    self:triggerShake(32, 0.8)
    AudioManager.playImmediateSFX("death", self.player_type == "bot")
    AudioManager.triggerGlitch(0.9)
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
    if self.ultimatris_halo > 0 then self.ultimatris_halo = math.max(0, self.ultimatris_halo - dt * 2.0) end

    for i = 1, #self.phantoms do
        local ph = self.phantoms[i]
        if ph.active then
            ph.timer = ph.timer - dt
            ph.glitch_phase = ph.glitch_phase + dt * 12.0
            if ph.timer <= 0 then ph.active = false end
        end
    end

    if self.is_dying then
        self.death_timer = self.death_timer - dt
        local prog = math.max(0, self.death_timer / self.death_duration)
        
        for i = 1, 40 do
            local c = self.cracks[i]
            if c.active then c.alpha = prog end
        end

        for i = 1, 350 do
            local s = self.shatter_shards[i]
            if s.active then
                s.x = s.x + s.vx * dt
                s.y = s.y + s.vy * dt
                s.vy = s.vy + 720 * dt
                s.vx = s.vx * (1.0 - 0.4 * dt)
                s.rot = s.rot + s.vrot * dt
                s.alpha = prog * prog
                if s.y > 660 then s.active = false end
            end
        end
        return
    end

    local top_r = 40
    for r = 21, 40 do
        for c = 1, 10 do
            if self.grid[r][c] ~= 0 then
                top_r = math.min(top_r, r)
                break
            end
        end
    end
    self.highest_row = top_r
    local danger_stack = math.max(0, (28 - top_r) / 8.0)
    self.danger_level = math.min(1.0, danger_stack)

    if self.danger_level > 0.75 and math.random() < 0.04 then
        AudioManager.triggerGlitch(0.06)
    end

    if self.is_zone_active then
        self.zone_wave_timer = self.zone_wave_timer + dt
        self.zone_timer = self.zone_timer - dt
        if self.zone_timer <= 0 then
            self:exitZone()
        end
    end

    self.eq_charge = math.max(0, self.eq_charge - dt * 0.35)
    self.eq_power = math.max(0, self.eq_power - dt * 0.4)
    self.eq_flash = math.max(0, self.eq_flash - dt * 2.5)

    local pulse = _G.AudioBeatPulse or 0
    for i = 1, 10 do
        local target = (0.1 + pulse * 0.6 + math.random() * 0.2) * self.eq_charge
        self.eq_bars[i] = self.eq_bars[i] + (target - self.eq_bars[i]) * 10 * dt
    end

    for i = 1, #self.trails do
        local t = self.trails[i]
        if t.active then 
            t.timer = t.timer - dt 
            if t.timer <= 0 then t.active = false end 
        end
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

function Board:drawPhantoms()
    local time = love.timer.getTime()
    local pulse = _G.AudioBeatPulse or 0
    love.graphics.push("all")
    love.graphics.setBlendMode("add")

    for i = 1, #self.phantoms do
        local ph = self.phantoms[i]
        if ph.active and ph.shape then
            local progress = ph.timer / ph.max_timer
            local alpha = progress * (0.65 + math.sin(time * 28 + ph.glitch_phase) * 0.25)
            local target_cx = self.x + (ph.x + 1) * 24
            local target_cy = self.y + (ph.y - 21) * 24

            -- RAYO LÁSER CONECTOR
            if progress > 0.4 then
                local beam_alpha = (progress - 0.4) / 0.6
                love.graphics.setLineWidth(2 + pulse * 3)
                love.graphics.setColor(0.9, 0.2, 1.0, beam_alpha * 0.7)
                love.graphics.line(ph.origin_x, ph.origin_y, target_cx, target_cy)
                love.graphics.setColor(1.0, 1.0, 1.0, beam_alpha * 0.9)
                love.graphics.setLineWidth(1)
                love.graphics.line(ph.origin_x, ph.origin_y, target_cx, target_cy)
            end

            -- FANTASMA HOLOGRÁFICO CON TRANSPARENCIA TRANSPARENTE FAIR-PLAY
            for r = 1, #ph.shape do
                for c = 1, #ph.shape[r] do
                    if ph.shape[r][c] ~= 0 then
                        local jitter_x = (math.random() - 0.5) * 8 * progress
                        local jitter_y = (math.random() - 0.5) * 4 * progress
                        local px = self.x + (ph.x + c - 2) * 24 + jitter_x
                        local py = self.y + (ph.y + r - 22) * 24 + jitter_y

                        love.graphics.setColor(0.9, 0.1, 1.0, alpha * 0.5)
                        love.graphics.rectangle("fill", px - 2, py - 2, 28, 28, 4)

                        love.graphics.setLineWidth(2.2)
                        love.graphics.setColor(0.2, 0.95, 1.0, alpha * 0.9)
                        love.graphics.rectangle("line", px + 1, py + 1, 22, 22, 3)

                        love.graphics.setColor(1, 1, 1, alpha * 0.75)
                        love.graphics.rectangle("fill", px + 4, py + 4, 16, 16, 2)
                    end
                end
            end
        end
    end

    love.graphics.setBlendMode("alpha")
    love.graphics.pop()
end

function Board:drawDangerAtmosphere()
    if self.danger_level <= 0.05 then return end
    
    local pulse = _G.AudioBeatPulse or 0
    local time = love.timer.getTime()
    local intensity = self.danger_level
    
    love.graphics.push("all")
    love.graphics.setBlendMode("add")

    local laser_y = self.y + 2
    local alpha_laser = (0.4 + math.sin(time * 16) * 0.35 + pulse * 0.25) * intensity
    love.graphics.setColor(1.0, 0.1, 0.15, alpha_laser)
    love.graphics.setLineWidth(2 + pulse * 2)
    love.graphics.line(self.x + 2, laser_y, self.x + 238, laser_y)

    love.graphics.setColor(1.0, 0.05, 0.1, (0.1 + pulse * 0.15) * intensity)
    love.graphics.rectangle("fill", self.x, self.y, 240, 110 * intensity, 4)

    if intensity > 0.5 and math.random() < (intensity * 0.5) then
        local glitch_y = self.y + math.random(0, 160)
        local shift_x = (math.random() - 0.5) * 14 * intensity
        love.graphics.setColor(1.0, 0.15, 0.3, 0.45)
        love.graphics.rectangle("fill", self.x + shift_x, glitch_y, 240, math.random(2, 6))
    end

    love.graphics.setBlendMode("alpha")
    love.graphics.pop()
end

function Board:drawShatterAnimation()
    if not self.is_dying then return end
    love.graphics.push("all")
    love.graphics.setBlendMode("add")

    love.graphics.setLineWidth(1.5)
    for i = 1, 40 do
        local c = self.cracks[i]
        if c.active and c.alpha > 0 then
            love.graphics.setColor(1.0, 0.25, 0.3, c.alpha * 0.85)
            love.graphics.line(c.x1, c.y1, c.x2, c.y2)
            love.graphics.setColor(1, 1, 1, c.alpha * 0.6)
            love.graphics.circle("fill", c.x1, c.y1, 2)
        end
    end
    
    for i = 1, 350 do
        local s = self.shatter_shards[i]
        if s.active and s.alpha > 0 then
            local clr = self.colors[s.id] or {1, 1, 1}
            local w, h = s.w, s.h
            
            love.graphics.push()
            love.graphics.translate(s.x, s.y)
            love.graphics.rotate(s.rot)
            
            if s.shard_type == 1 then
                love.graphics.setColor(clr[1], clr[2], clr[3], s.alpha * 0.4)
                love.graphics.polygon("fill", -w/2, -h/2, w/2, -h/4, 0, h/2)
                love.graphics.setLineWidth(1.5)
                love.graphics.setColor(clr[1] * 1.2, clr[2] * 1.2, clr[3] * 1.2, s.alpha * 0.9)
                love.graphics.polygon("line", -w/2, -h/2, w/2, -h/4, 0, h/2)
                love.graphics.setColor(1, 1, 1, s.alpha * 0.7)
                love.graphics.line(-w/4, -h/3, 0, h/3)
            elseif s.shard_type == 2 then
                love.graphics.setColor(clr[1], clr[2], clr[3], s.alpha * 0.45)
                love.graphics.polygon("fill", 0, -h/2, w/2, 0, 0, h/2, -w/2, 0)
                love.graphics.setLineWidth(1.5)
                love.graphics.setColor(1.0, 1.0, 1.0, s.alpha * 0.95)
                love.graphics.polygon("line", 0, -h/2, w/2, 0, 0, h/2, -w/2, 0)
                love.graphics.setColor(clr[1], clr[2], clr[3], s.alpha * 0.8)
                love.graphics.line(0, -h/2, 0, h/2)
            elseif s.shard_type == 3 then
                love.graphics.setColor(clr[1] * 0.8, clr[2] * 0.8, clr[3] * 0.8, s.alpha * 0.5)
                love.graphics.polygon("fill", -w/2, -h/3, w/3, -h/2, w/2, h/2, -w/3, h/3)
                love.graphics.setLineWidth(1.5)
                love.graphics.setColor(clr[1], clr[2], clr[3], s.alpha * 0.85)
                love.graphics.polygon("line", -w/2, -h/3, w/3, -h/2, w/2, h/2, -w/3, h/3)
                love.graphics.setColor(1, 1, 1, s.alpha * 0.6)
                love.graphics.circle("fill", 0, 0, 1.5)
            else
                love.graphics.setColor(clr[1], clr[2], clr[3], s.alpha * 0.6)
                love.graphics.rectangle("fill", -w/4, -h/2, w/2, h, 1)
                love.graphics.setColor(1, 1, 1, s.alpha * 0.9)
                love.graphics.line(0, -h/2, 0, h/2)
            end

            love.graphics.pop()
        end
    end
    
    love.graphics.setBlendMode("alpha")
    love.graphics.pop()
end

function Board:drawEQBackground()
    local garbage_count = 0
    for _, lines in ipairs(self.garbage_queue) do garbage_count = garbage_count + lines end
    if self.eq_charge <= 0.01 and garbage_count == 0 and not self.is_zone_active then return end

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
                local alpha = (0.12 + pulse * 0.2)
                
                if self.is_zone_active then
                    if self.zone_tier == 2 then
                        love.graphics.setColor(0.9, 0.7, 0.1, 0.15)
                    else
                        love.graphics.setColor(0.0, 0.5, 0.8, 0.12)
                    end
                elseif is_danger then
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

function Board:drawTrails()
    local pulse = _G.AudioBeatPulse or 0
    local energy = _G.TrackEnergyPunch or 0
    love.graphics.push("all")
    love.graphics.setBlendMode("add")

    for i = 1, #self.trails do
        local t = self.trails[i]
        if t.active and t.shape then
            local progress = t.timer / self.trail_duration
            local clr = self.colors[t.id] or {0.5, 0.8, 1}
            local alpha = (progress * progress) * (0.35 + energy * 0.35 + pulse * 0.15)
            
            for r = 1, #t.shape do
                for c = 1, #t.shape[r] do
                    if t.shape[r][c] ~= 0 then
                        local col_x = self.x + (t.x + c - 2) * 24
                        local top_y = self.y + (t.y_start + r - 22) * 24
                        local bot_y = self.y + (t.y_end + r - 22) * 24
                        local beam_h = math.max(0, bot_y - top_y)
                        
                        if beam_h > 0 then
                            love.graphics.setColor(clr[1], clr[2], clr[3], alpha * 0.4)
                            love.graphics.rectangle("fill", col_x + 2, top_y, 20, beam_h)
                            
                            love.graphics.setColor(1, 1, 1, alpha * 0.6)
                            love.graphics.rectangle("fill", col_x + 8, top_y, 8, beam_h)
                        end
                    end
                end
            end
        end
    end

    love.graphics.setBlendMode("alpha")
    love.graphics.pop()
end

function Board:drawBlock(bx, by, id, alpha, col_idx, row_idx)
    local clr = self.colors[id] or {1, 1, 1}
    local pulse = _G.AudioBeatPulse or 0
    local energy = _G.TrackEnergyPunch or 0
    local a = alpha or 1.0
    
    local scale = 1 + (self.lock_impact * 0.08) + (pulse * 0.02 * energy)
    local ds = 24 * scale
    local off = (ds - 24) / 2

    if self.is_zone_active and col_idx and row_idx then
        local w_time = self.zone_wave_timer or 0
        local diag_phase = (col_idx + (row_idx - 20)) * 0.55 - w_time * 8.0
        local wave = 0.5 + 0.5 * math.sin(diag_phase)
        local beam_wave = 0.5 + 0.5 * math.sin((col_idx - (row_idx - 20)) * 0.4 + w_time * 6.0)

        if self.zone_tier == 2 then
            local chroma_r = 0.5 + 0.5 * math.sin(diag_phase)
            local chroma_g = 0.5 + 0.5 * math.sin(diag_phase + 2.094)
            local chroma_b = 0.5 + 0.5 * math.sin(diag_phase + 4.188)

            love.graphics.setColor(0.15 + chroma_r * 0.2, 0.12 + chroma_g * 0.15, 0.05 + chroma_b * 0.1, a * (0.4 + wave * 0.35))
            love.graphics.rectangle("fill", bx - off, by - off, ds, ds, 4)

            love.graphics.setLineWidth(1.8)
            love.graphics.setColor(1.0, 0.85 + chroma_g * 0.15, 0.3 + chroma_b * 0.5, a * (0.5 + wave * 0.5))
            love.graphics.line(bx - off + 2, by - off + ds - 2, bx - off + ds - 2, by - off + 2)
            love.graphics.line(bx - off + 2, by - off + 2, bx - off + ds - 2, by - off + ds - 2)

            love.graphics.setLineWidth(2.2)
            love.graphics.setColor(chroma_r, chroma_g, chroma_b, a * (0.85 + wave * 0.15))
            love.graphics.rectangle("line", bx - off, by - off, ds, ds, 4)

            love.graphics.setColor(1, 1, 1, a * (0.45 + wave * 0.5))
            love.graphics.rectangle("fill", bx + 4 - off, by + 4 - off, ds - 8, 4, 2)
        else
            love.graphics.setColor(clr[1] * 0.35 + 0.05, clr[2] * 0.5 + 0.15, clr[3] * 0.7 + 0.2, a * (0.35 + wave * 0.35))
            love.graphics.rectangle("fill", bx - off, by - off, ds, ds, 4)

            love.graphics.setLineWidth(1.5)
            love.graphics.setColor(0.2, 0.95, 1.0, a * (0.4 + wave * 0.55))
            love.graphics.line(bx - off + 2, by - off + ds - 2, bx - off + ds - 2, by - off + 2)

            love.graphics.setLineWidth(2)
            local shimmer_r = clr[1] * (0.6 + wave * 0.4)
            local shimmer_g = clr[2] * (0.6 + beam_wave * 0.4)
            local shimmer_b = clr[3] * (0.7 + wave * 0.3)
            love.graphics.setColor(shimmer_r, shimmer_g, shimmer_b, a * (0.8 + wave * 0.2))
            love.graphics.rectangle("line", bx - off, by - off, ds, ds, 4)

            love.graphics.setColor(1, 1, 1, a * (0.3 + wave * 0.4))
            love.graphics.rectangle("fill", bx + 3 - off, by + 3 - off, ds - 6, 4, 2)
        end
    else
        love.graphics.setColor(clr[1], clr[2], clr[3], a * 0.38)
        love.graphics.rectangle("fill", bx - off, by - off, ds, ds, 4)
        
        love.graphics.setLineWidth(2)
        love.graphics.setColor(clr[1], clr[2], clr[3], a * (0.85 + pulse * 0.25))
        love.graphics.rectangle("line", bx - off, by - off, ds, ds, 4)

        love.graphics.setColor(1, 1, 1, a * (0.25 + pulse * 0.25))
        love.graphics.rectangle("fill", bx + 3 - off, by + 3 - off, ds - 6, 4, 2)
    end
end

function Board:draw()
    local energy = _G.TrackEnergyPunch or 0
    local pulse = _G.AudioBeatPulse or 0
    
    love.graphics.push("all")
    Shaker.apply(self)
    
    if self.is_dying then
        love.graphics.setColor(0.01, 0.01, 0.02, 0.92)
        love.graphics.rectangle("fill", self.x, self.y, 240, 480, 4)
        love.graphics.setColor(0.5, 0.1, 0.15, math.max(0, self.death_timer / self.death_duration))
        love.graphics.rectangle("line", self.x - 2, self.y - 2, 244, 484, 4)
        self:drawShatterAnimation()
        ParticleSystem.draw(self)
        love.graphics.pop()
        return
    end

    if self.is_zone_active then
        if self.zone_tier == 2 then
            love.graphics.setColor(0.04, 0.02, 0.01, 0.98)
        else
            love.graphics.setColor(0.01, 0.03, 0.07, 0.96)
        end
    else
        love.graphics.setColor(0.01, 0.01, 0.03, 0.95)
    end
    love.graphics.rectangle("fill", self.x, self.y, 240, 480, 4)
    
    self:drawEQBackground()
    self:drawTrails()
    self:drawPhantoms()
    self:drawDangerAtmosphere()

    love.graphics.setColor(1, 1, 1, 0.03 + pulse * 0.03)
    for c = 0, 10 do love.graphics.line(self.x + c*24, self.y, self.x + c*24, self.y + 480) end
    for r = 0, 20 do love.graphics.line(self.x, self.y + r*24, self.x + 240, self.y + r*24) end

    for r = 21, 40 do
        for c = 1, 10 do
            local id = self.grid[r][c]
            if id ~= 0 then 
                self:drawBlock(self.x + (c-1)*24, self.y + (r-21)*24, id, 1.0, c, r) 
            end
        end
    end

    love.graphics.setLineWidth(2 + pulse * 1.5 * energy)
    if self.danger_level > 0.5 then
        local flash_danger = 0.6 + math.sin(love.timer.getTime() * 12) * 0.4
        love.graphics.setColor(1.0, 0.15 * flash_danger, 0.2, 0.9)
    elseif self.ultimatris_halo > 0 then
        love.graphics.setColor(1.0, 0.85, 0.2, 0.9 + pulse * 0.1)
    elseif self.is_zone_active then
        if self.zone_tier == 2 then
            love.graphics.setColor(1.0, 0.85, 0.25, 0.95 + pulse * 0.05)
        else
            love.graphics.setColor(0.1, 0.85, 1.0, 0.85 + pulse * 0.15)
        end
    elseif energy >= 0.9 then
        local t = love.timer.getTime() * 5
        local r = 0.5 + 0.5 * math.sin(t)
        local g = 0.5 + 0.5 * math.sin(t + 2.094)
        local b = 0.5 + 0.5 * math.sin(t + 4.188)
        love.graphics.setColor(r, g, b, 0.8 + pulse * 0.2)
    else
        love.graphics.setColor(0, 0.5, 1, 0.4 + pulse * 0.3)
    end
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
    if self.is_dying then return false end
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
        -- REGLA DE JUEGO JUSTO: Limpiar líneas disipa la interferencia de 1 Phantom
        self:dispelOnePhantom()

        if self.is_zone_active then
            self.zone_lines = self.zone_lines + #lines
            local col = (self.zone_tier == 2) and {1.0, 0.9, 0.3} or {0.2, 1.0, 0.8}
            self:setPopup("ZONE " .. self.zone_lines, col)
            
            -- FASE 1: ASTRAL MIRAGE (Proyección de eco en vivo sobre el rival)
            if self.opponent and self.active_piece then
                local p = self.active_piece
                self.opponent:spawnPhantom(p.x, p.y, p.id, p.shape[p.rotation], self.x + 120, self.y + 240)
            end

            for _, r in ipairs(lines) do
                ParticleSystem.spawnLineBlast(self, r, self.grid[r][1] or 1)
                table.remove(self.grid, r)
                table.insert(self.grid, 1, {0,0,0,0,0,0,0,0,0,0})
            end
            self:triggerShake(#lines * 4, 0.2)
            AudioManager.playImmediateSFX("line_clear", self.player_type == "bot")
            return
        end

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
    else 
        if not self.is_zone_active then self.combo = -1 end
    end
end

function Board:hold()
    if self.is_dying or not self.can_hold then return end
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

    if not self.is_zone_active and not self.active_piece:canMove(self.active_piece.x, self.active_piece.y, 1) then
        _G.GameOverPending = self.player_type
    end
end

return Board
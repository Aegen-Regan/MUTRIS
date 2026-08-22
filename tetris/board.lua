-- ================================================================
-- FILE: tetris/board.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: THE MATRIX GRID BOARD (10x40)
-- Zero-GC / Status Blights Integration / Boss Dynamics / Palico Drone
-- ============================================================================
local Board = {}
Board.__index = Board

local Piece            = require "tetris.piece"
local Bag              = require "tetris.randomizers.7bag"
local GarbageManager   = require "tetris.garbage_manager"
local ParticleSystem   = require "tetris.particle_system"
local Shaker           = require "tetris.shaker"
local PPSCounter       = require "tetris.pps_counter"
local FontCache        = require "tetris.font_cache"
local AudioManager     = require "audio_manager"
local BloomShader      = require "tetris.bloom_shader"
local BeatLock         = require "tetris.beat_lock"
local CombatStances    = require "combat.combat_stances"
local KineticParry     = require "combat.kinetic_parry"
local ThemeManager     = require "tetris.theme_manager"
local PoiseSystem      = require "combat.poise_system"
local PartBreaking     = require "combat.part_breaking"
local BenchmarkManager = require "core.benchmark_manager"
local HuntingForge     = require "combat.hunting_forge"
local StatusBlights    = require "combat.status_blights"
local Blackbox         = require "core.blackbox"
local EventBus         = require "core.event_bus"

Board.colors = {
    [1] = {0.0, 0.9, 1.0},
    [2] = {0.1, 0.3, 1.0},
    [3] = {1.0, 0.5, 0.0},
    [4] = {1.0, 0.9, 0.0},
    [5] = {0.1, 1.0, 0.2},
    [6] = {0.8, 0.1, 1.0},
    [7] = {1.0, 0.1, 0.2},
    [8] = {0.5, 0.5, 0.55}
}

function Board.new(x, y, player_type)
    local self = setmetatable({}, Board)
    self.x, self.y = x, y
    self.player_type = player_type or "human"
    self.opponent = nil

    self.grid = {}
    for r = 1, 40 do
        self.grid[r] = {}
        for c = 1, 10 do self.grid[r][c] = 0 end
    end

    self.bag = Bag.new()
    self.active_piece = nil
    self.hold_piece = nil
    self.can_hold = true
    self.garbage_queue = {}
    self.combo_count = -1
    self.b2b_count = 0

    self.zone_meter = 0.0
    self.is_zone_active = false
    self.zone_timer = 0.0
    self.zone_max_time = 6.0
    self.zone_tier = 1
    self.zone_lines_cleared = 0

    self.eq_charge = 0.0
    self.eq_power = 0.0
    self.eq_flash = 0.0
    self.tspin_flash = 0.0

    self.shake_mag = 0
    self.shake_time = 0
    self.lock_impact = 0.0

    self.popup_text = ""
    self.popup_sub = ""
    self.popup_color = {1, 1, 1}
    self.popup_timer = 0.0
    self.popup_max_time = 1.2
    self.popup_scale = 1.0
    self.popup_is_high_tier = false

    self.is_dying = false
    self.death_timer = 0.0
    self.pending_groove_bonus = 0

    self.trail_pool = {}
    for i = 1, 16 do
        self.trail_pool[i] = { active = false, x = 0, startY = 0, endY = 0, id = 1, timer = 0, shape = nil }
    end

    self.phantom_pool = {}
    for i = 1, 8 do
        self.phantom_pool[i] = { active = false, x = 0, y = 0, id = 1, timer = 0, shape = nil }
    end

    ParticleSystem.init(self)
    PPSCounter.init(self)
    BeatLock.initBoardState(self)
    CombatStances.initBoardState(self)
    KineticParry.initBoardState(self)
    StatusBlights.initBoardState(self)

    self:spawnPiece()
    return self
end

function Board:spawnPiece()
    if self.is_dying then return end
    local next_id = self.bag:next()
    self.active_piece = Piece.new(next_id, self)

    -- 🪝 HOOK ZERO-GC: Spawn de Pieza
    EventBus.emit(EventBus.ON_PIECE_SPAWN, next_id, self.player_type == "human" and 1 or 2)

    if not self:canMove(self.active_piece.x, self.active_piece.y, self.active_piece.rotation) then
        Blackbox.log(
            (self.player_type == "human") and "P1_BLOCK_OUT" or "BOT_BLOCK_OUT",
            "SPAWN OVERLAP (4, 21)",
            next_id, 0
        )
        self:triggerDeath()
    end
end

function Board:hold()
    if not self.can_hold or self.is_dying or not self.active_piece then return end

    local BossPhases = require "combat.boss_phases"
    if BossPhases.isHoldLocked() and self.player_type == "human" then
        AudioManager.playImmediateSFX("death", false)
        return
    end

    local cur_id = self.active_piece.id
    if not self.hold_piece then
        self.hold_piece = { id = cur_id }
        self:spawnPiece()
    else
        local swap_id = self.hold_piece.id
        self.hold_piece.id = cur_id
        self.active_piece = Piece.new(swap_id, self)
    end
    self.can_hold = false
    AudioManager.playImmediateSFX("hold", self.player_type == "bot")
end

function Board:enterZone()
    if self.is_zone_active or self.zone_meter < 0.25 or self.is_dying then return end
    self.is_zone_active = true
    self.zone_tier = (self.zone_meter >= 0.999) and 2 or 1
    self.zone_timer = self.zone_max_time * self.zone_meter
    self.zone_lines_cleared = 0

    StatusBlights.cleanse(self)
    EventBus.emit(EventBus.ON_ZONE_ENTER, self.player_type == "human" and 1 or 2, self.zone_tier)

    if self.zone_tier == 2 then
        AudioManager.playImmediateSFX("zone_enter_hyper", self.player_type == "bot")
        ParticleSystem.spawnSupernova(self, {1.0, 0.85, 0.2})
        BloomShader.triggerShockwave(self.x + 120, self.y + 240)
    else
        AudioManager.playImmediateSFX("zone_enter", self.player_type == "bot")
        ParticleSystem.spawnSupernova(self, {0.0, 0.9, 1.0})
    end
end

function Board:exitZone()
    if not self.is_zone_active then return end
    self.is_zone_active = false
    local is_pc = self:isGridEmpty()
    local is_hyper = (self.zone_tier == 2)
    local attack, msg, clr = GarbageManager.calculateZoneBurst(self.zone_lines_cleared, is_pc, is_hyper)

    self.zone_meter = 0.0
    self:setPopup(msg, clr, true, "BURST DETONATION")

    if _G.CURRENT_GAME_MODE == "boss_hunt" and self.player_type == "human" then
        PoiseSystem.dealDamage(attack * 90, true)
    elseif self.opponent and attack > 0 then
        GarbageManager.sendGarbage(self, self.opponent, attack)
    end

    self:clearCompletedLinesInZone()
    AudioManager.playImmediateSFX("ultimatris", self.player_type == "bot")
    EventBus.emit(EventBus.ON_ZONE_EXIT, self.player_type == "human" and 1 or 2, attack)
end

function Board:isGridEmpty()
    for r = 21, 40 do
        for c = 1, 10 do
            if self.grid[r][c] ~= 0 then return false end
        end
    end
    return true
end

function Board:clearCompletedLinesInZone()
    local r = 40
    while r >= 21 do
        local full = true
        for c = 1, 10 do
            if self.grid[r][c] == 0 then full = false break end
        end
        if full then
            local row = table.remove(self.grid, r)
            for c = 1, 10 do row[c] = 0 end
            table.insert(self.grid, 1, row)
        else
            r = r - 1
        end
    end
end

function Board:canMove(px, py, pr)
    local RulesetManager = require "core.ruleset_manager"
    local shapes = RulesetManager.getShapes(self.active_piece.id)
    local shape = shapes and shapes[pr] or {{{1}}}
    for r = 1, #shape do
        for c = 1, #shape[r] do
            if shape[r][c] ~= 0 then
                local tx, ty = px + c - 1, py + r - 1
                if tx < 1 or tx > 10 or ty < 1 or ty > 40 then 
                    return false 
                end
                if self.grid[ty][tx] ~= 0 then 
                    return false 
                end
            end
        end
    end
    return true
end

function Board:checkLines(is_tspin)
    local cleared = 0
    local r = 40

    while r >= 1 do
        local full = true
        for c = 1, 10 do
            if self.grid[r][c] == 0 then full = false break end
        end

        if full then
            cleared = cleared + 1
            ParticleSystem.spawnLineBlast(self, r, (is_tspin and 6) or (cleared == 4 and 1) or 4)

            if not self.is_zone_active then
                local removed_row = table.remove(self.grid, r)
                for c = 1, 10 do removed_row[c] = 0 end
                table.insert(self.grid, 1, removed_row)
            else
                r = r - 1
            end
        else
            r = r - 1
        end
    end

    if cleared > 0 then
        self.combo_count = self.combo_count + 1
        if cleared == 4 or is_tspin then 
            self.b2b_count = self.b2b_count + 1
        else 
            self.b2b_count = 0 
        end

        if self.player_type == "human" and _G.CURRENT_GAME_MODE == "benchmark" then
            BenchmarkManager.registerPlayerLineClear(cleared, is_tspin)
        end

        StatusBlights.onPlayerLineClear(self, cleared, is_tspin)
        
        -- 🪝 HOOK ZERO-GC: Limpieza de Líneas
        EventBus.emit(EventBus.ON_LINE_CLEAR, cleared, is_tspin and 1 or 0, self.player_type == "human" and 1 or 2, self.combo_count)

        if self.is_zone_active then
            self.zone_lines_cleared = self.zone_lines_cleared + cleared
        else
            if _G.CURRENT_GAME_MODE == "boss_hunt" and self.player_type == "human" then
                PartBreaking.registerLineClear(self, cleared, is_tspin)
            elseif _G.CURRENT_GAME_MODE ~= "benchmark" or BenchmarkManager.state == BenchmarkManager.STAGE_2_PLAY then
                local attack = GarbageManager.calculateAttack(cleared, is_tspin, false, self.combo_count, self.b2b_count, self)
                if self.opponent and attack > 0 then
                    if _G.CURRENT_GAME_MODE == "boss_hunt" and self.player_type == "bot" and PartBreaking.parts.tail.broken then
                        attack = math.max(1, math.floor(attack * 0.5))
                    end
                    GarbageManager.sendGarbage(self, self.opponent, attack)
                end
            end

            AudioManager.playImmediateSFX((cleared == 4) and "tetris" or "line_clear", self.player_type == "bot")
        end
    else
        self.combo_count = -1
        if not self.is_zone_active then
            GarbageManager.pushToGrid(self)
        end
    end

    if not self.is_zone_active then
        local ceiling_breach = false
        for row_idx = 1, 20 do
            for c = 1, 10 do
                if self.grid[row_idx][c] ~= 0 then
                    ceiling_breach = true
                    break
                end
            end
            if ceiling_breach then break end
        end

        if ceiling_breach then
            Blackbox.log(
                (self.player_type == "human") and "P1_DEATH" or "BOT_DEATH",
                "CEILING OVERFLOW (MINOS IN R<=20)",
                0, 0
            )
            self:triggerDeath()
            return
        end
    end

    self:spawnPiece()
end

function Board:spawnTrail(x, startY, endY, id, shape)
    for i = 1, #self.trail_pool do
        local t = self.trail_pool[i]
        if not t.active then
            t.active = true
            t.x, t.startY, t.endY, t.id, t.shape = x, startY, endY, id, shape
            t.timer = 0.25
            break
        end
    end
end

function Board:spawnPhantom(x, y, id, shape)
    for i = 1, #self.phantom_pool do
        local p = self.phantom_pool[i]
        if not p.active then
            p.active = true
            p.x, p.y, p.id, p.shape = x, y, id, shape
            p.timer = 0.50
            break
        end
    end
end

function Board:swapGrids(other)
    local temp = self.grid
    self.grid = other.grid
    other.grid = temp
    self:triggerShake(12, 0.4)
    other:triggerShake(12, 0.4)
end

function Board:shiftColumnsLocal(dir)
    for r = 1, 40 do
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
    self:triggerShake(4, 0.15)
end

function Board:shiftColumnsGlobal(other, dir)
    for r = 21, 40 do
        local p_edge = self.grid[r][10]
        local o_edge = other.grid[r][1]
        for c = 10, 2, -1 do self.grid[r][c] = self.grid[r][c - 1] end
        self.grid[r][1] = o_edge
        for c = 1, 9 do other.grid[r][c] = other.grid[r][c + 1] end
        other.grid[r][10] = p_edge
    end
    self:triggerShake(6, 0.2)
    other:triggerShake(6, 0.2)
end

function Board:setPopup(text, color, is_high_tier, subtext)
    local raw_t = tostring(text or "")
    local raw_s = tostring(subtext or "")
    local clean_t = raw_t:gsub("[^\32-\126]", ""):gsub("^%s*(.-)%s*$", "%1")
    local clean_s = raw_s:gsub("[^\32-\126]", ""):gsub("^%s*(.-)%s*$", "%1")

    self.popup_text = clean_t
    self.popup_sub = clean_s
    self.popup_color = color or {1, 1, 1}
    self.popup_timer = 1.2
    self.popup_max_time = 1.2
    self.popup_scale = is_high_tier and 1.65 or 1.35
    self.popup_is_high_tier = is_high_tier or false
end

function Board:triggerShake(mag, dur)
    self.shake_mag = mag
    self.shake_time = dur
end

function Board:triggerDeath()
    if self.is_dying then return end

    if _G.CURRENT_GAME_MODE == "boss_hunt" and self.player_type == "bot" then
        local BossPhases = require "combat.boss_phases"
        if BossPhases.current_phase < 3 then
            BossPhases.triggerPhaseAdvance(self.opponent, self)
            return
        end
    end

    self.is_dying = true
    self.death_timer = 1.5
    _G.HitStopTimer = 0.25
    AudioManager.playImmediateSFX("death", self.player_type == "bot")
    BloomShader.triggerShockwave(self.x + 120, self.y + 240)
    self:triggerShake(16, 0.6)

    -- 🪝 HOOK ZERO-GC: Muerte del Tablero
    EventBus.emit(EventBus.ON_BOARD_DEATH, self.player_type == "human" and 1 or 2)
end

function Board:drawBlock(x, y, id, alpha)
    local clr = self.colors[id] or {0.6, 0.6, 0.6}
    local a = alpha or 1.0
    love.graphics.setColor(clr[1], clr[2], clr[3], a * 0.92)
    love.graphics.rectangle("fill", x + 1, y + 1, 22, 22, 2)
    love.graphics.setColor(1, 1, 1, a * 0.40)
    love.graphics.rectangle("fill", x + 2, y + 2, 20, 3)
    love.graphics.setColor(0, 0, 0, a * 0.45)
    love.graphics.rectangle("fill", x + 2, y + 19, 20, 3)
end

function Board:update(dt)
    Shaker.update(self, dt)
    ParticleSystem.update(self, dt)
    PPSCounter.update(self)
    BeatLock.update(self, dt)
    CombatStances.update(self, dt)
    KineticParry.update(self, dt)
    StatusBlights.update(self, dt)

    if self.player_type == "human" then
        HuntingForge.updatePalico(dt, self)
    end

    if self.is_dying then
        self.death_timer = math.max(0, self.death_timer - dt)
    end

    if self.popup_timer > 0 then
        self.popup_timer = self.popup_timer - dt
        self.popup_scale = self.popup_scale + (1.0 - self.popup_scale) * 12.0 * dt
    end

    if self.tspin_flash > 0 then
        self.tspin_flash = math.max(0, self.tspin_flash - dt * 3.5)
    end

    if self.lock_impact > 0 then self.lock_impact = math.max(0, self.lock_impact - dt * 4.0) end
    if self.eq_flash > 0 then self.eq_flash = math.max(0, self.eq_flash - dt * 3.0) end

    if self.is_zone_active then
        self.zone_timer = self.zone_timer - dt
        if self.zone_timer <= 0 then self:exitZone() end
    end

    for i = 1, #self.trail_pool do
        local t = self.trail_pool[i]
        if t.active then
            t.timer = t.timer - dt
            if t.timer <= 0 then t.active = false end
        end
    end

    for i = 1, #self.phantom_pool do
        local p = self.phantom_pool[i]
        if p.active then
            p.timer = p.timer - dt
            if p.timer <= 0 then p.active = false end
        end
    end

    if not self.is_dying and self.active_piece then
        if not (_G.CURRENT_GAME_MODE == "boss_hunt" and self.player_type == "bot" and PoiseSystem.is_stunned) then
            local Input = require "input"
            local gravity = (self.player_type == "human") and Input.getSoftDropFactor() or 0.8
            self.active_piece:update(dt, gravity)
        end
    end
end

function Board:draw()
    love.graphics.push("all")
    Shaker.apply(self)

    ThemeManager.drawMatrixFrame(self)

    local t = ThemeManager.getCurrent()
    love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.04)
    for r = 1, 20 do
        love.graphics.line(self.x, self.y + r * 24, self.x + 240, self.y + r * 24)
    end
    for c = 1, 10 do
        love.graphics.line(self.x + c * 24, self.y, self.x + c * 24, self.y + 480)
    end

    local block_alpha = self.is_dying and math.max(0.2, self.death_timer / 1.5) or 1.0
    for r = 21, 40 do
        for c = 1, 10 do
            local id = self.grid[r][c]
            if id ~= 0 then
                self:drawBlock(self.x + (c - 1) * 24, self.y + (r - 21) * 24, id, block_alpha)
            end
        end
    end

    love.graphics.setBlendMode("add")
    for i = 1, #self.trail_pool do
        local tr = self.trail_pool[i]
        if tr.active and tr.shape then
            local a = (tr.timer / 0.25) * 0.35
            local clr = self.colors[tr.id] or {1, 1, 1}
            love.graphics.setColor(clr[1], clr[2], clr[3], a)
            for r = 1, #tr.shape do
                for c = 1, #tr.shape[r] do
                    if tr.shape[r][c] ~= 0 then
                        local rx = self.x + (tr.x + c - 2) * 24
                        local ry1 = self.y + (tr.startY + r - 22) * 24
                        local ry2 = self.y + (tr.endY + r - 22) * 24
                        love.graphics.rectangle("fill", rx + 4, ry1, 16, math.max(4, ry2 - ry1 + 24))
                    end
                end
            end
        end
    end

    if self.active_piece and not self.is_dying then
        self.active_piece:draw(self.x, self.y)
    end

    if self.lock_impact > 0 then
        love.graphics.setBlendMode("add")
        love.graphics.setColor(t.secondary[1], t.secondary[2], t.secondary[3], self.lock_impact * 0.5)
        love.graphics.rectangle("fill", self.x, self.y + 474, 240, 6, 2)
        love.graphics.setBlendMode("alpha")
    end

    ParticleSystem.draw(self)
    BeatLock.drawFeedback(self)
    CombatStances.drawAura(self)
    KineticParry.draw(self)
    ThemeManager.drawGarbageBar(self)

    StatusBlights.drawAura(self)

    if self.player_type == "human" then
        HuntingForge.drawPalico(self)
    end

    if self.player_type == "bot" and _G.CURRENT_GAME_MODE == "boss_hunt" then
        PartBreaking.drawIndicators(self)
    end

    if self.tspin_flash > 0 then
        love.graphics.push("all")
        love.graphics.setBlendMode("add")
        love.graphics.setColor(0.85, 0.15, 1.0, self.tspin_flash * 0.35)
        love.graphics.rectangle("fill", self.x, self.y, 240, 480, 4)
        love.graphics.pop()
    end

    if self.popup_timer > 0 then
        local progress = self.popup_timer / self.popup_max_time
        local alpha = math.min(1.0, progress * 1.9)
        local float_y = (1.0 - progress) * 45.0
        local cx = self.x + 120
        local cy = self.y + 135 - float_y
        local sc = self.popup_scale
        local clr = self.popup_color

        love.graphics.push()
        love.graphics.translate(cx, cy)
        love.graphics.scale(sc, sc)

        love.graphics.setBlendMode("add")
        if self.popup_is_high_tier then
            love.graphics.setFont(FontCache.get(17))
            love.graphics.setColor(0.1, 0.9, 1.0, alpha * 0.60)
            love.graphics.printf(self.popup_text, -142, -10, 280, "center")
            love.graphics.setColor(1.0, 0.1, 0.5, alpha * 0.60)
            love.graphics.printf(self.popup_text, -138, -10, 280, "center")
        else
            love.graphics.setFont(FontCache.get(15))
            love.graphics.setColor(clr[1], clr[2], clr[3], alpha * 0.45)
            love.graphics.printf(self.popup_text, -140, -10, 280, "center")
        end

        love.graphics.setBlendMode("alpha")
        love.graphics.setFont(FontCache.get(self.popup_is_high_tier and 17 or 15))
        love.graphics.setColor(1.0, 1.0, 1.0, alpha * 0.98)
        love.graphics.printf(self.popup_text, -140, -10, 280, "center")

        if self.popup_sub ~= "" then
            love.graphics.setFont(FontCache.get(9))
            love.graphics.setColor(clr[1], clr[2], clr[3], alpha * 0.90)
            love.graphics.printf(self.popup_sub, -140, 13, 280, "center")
        end

        love.graphics.pop()
    end

    love.graphics.pop()
end

return Board
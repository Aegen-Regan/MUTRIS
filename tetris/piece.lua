---@diagnostic disable: undefined-global
local Piece = {}
Piece.__index = Piece

local AudioManager = require "audio_manager"
local PPSCounter = require "tetris.pps_counter"

function Piece.new(id, board)
    local self = setmetatable({}, Piece)
    self.id = id
    self.board = board

    -- Cargamos el sistema de rotación SRS nativo que nos pasaste
    local SRS = require "tetris.rotation_systems.srs"
    if SRS and SRS.shapes and SRS.shapes[id] then
        self.shape = SRS.shapes[id]
    else
        self.shape = { {{1,1,1,1}} } -- Red de seguridad
    end

    self.rotation = 1
    self.x = (id == 1) and 4 or 4 -- Centrado Guideline estándar
    self.y = 21
    self.locked = false

    -- Gravedad / lock delay stas
    self.gravity_timer = 0
    self.lock_timer = 0
    self.lock_delay = 0.5
    self.move_count = 0
    self.max_resets = 15
    self.spawn_timer = 0.12

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
        local old_x = self.x
        self.x = self.x + dx
        self.y = self.y + dy
        if not is_gravity then
            AudioManager.playImmediateSFX("move", self.board.player_type == "bot")
            -- CORRECCIÓN DAS/ARR: Solo resetear si la pieza realmente cambió de columna
            if dx ~= 0 and self.x ~= old_x then
                self:resetLock()
            end
        end
        return true
    end
    return false
end

function Piece:rotate(dir)
    local max_rot = #self.shape
    local old_rot = self.rotation
    local next_rot = self.rotation + dir
    
    if next_rot > max_rot then next_rot = 1 end
    if next_rot < 1 then next_rot = max_rot end

    -- SOLUCIÓN CRÍTICA: Inyección del sistema de Wall-Kicks SRS
    local SRS = require "tetris.rotation_systems.srs"
    if SRS and SRS.getKicks then
        -- Le pedimos a srs.lua la lista de 5 pruebas de posición para esta rotación
        local kicks = SRS.getKicks(self.id, old_rot, next_rot)
        if kicks then
            for _, kick in ipairs(kicks) do
                local test_x = self.x + kick[1]
                -- En Tetris Guideline, las tablas de kick asumen Y positivo hacia arriba, 
                -- como nuestra grilla va hacia abajo, invertimos el signo de kick[2]
                local test_y = self.y - kick[2] 
                
                -- Si alguna de las 5 pruebas de posición es válida, la pieza patea y rota con éxito
                if self:canMove(test_x, test_y, next_rot) then
                    self.x = test_x
                    self.y = test_y
                    self.rotation = next_rot
                    AudioManager.playImmediateSFX("rotate", self.board.player_type == "bot")
                    self:resetLock()
                    return true
                end
            end
        end
    else
        -- Fallback plano si el módulo SRS no está disponible
        if self:canMove(self.x, self.y, next_rot) then
            self.rotation = next_rot
            self:resetLock()
            return true
        end
    end
    return false
end

function Piece:canMove(px, py, pr)
    return self.board:canMove(px, py, pr)
end

function Piece:update(dt, gravity_speed)
    if self.locked then return end
    gravity_speed = gravity_speed or 0.8

    if self.spawn_timer > 0 then self.spawn_timer = self.spawn_timer - dt end

    self.gravity_timer = self.gravity_timer + dt
    if self.gravity_timer >= gravity_speed then
        if self:move(0, 1, true) then self.gravity_timer = 0 end
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
    
    -- CORRECCIÓN CRÍTICA: Le devolvemos el permiso de Hold al tablero 
    -- justo en el momento exacto en que la pieza se congela en la grilla.
    if self.board then
        self.board.can_hold = true
    end

    local shape = self.shape[self.rotation]
    for r = 1, #shape do
        for c = 1, #shape[r] do
            if shape[r][c] ~= 0 then
                local tx = self.x + c - 1
                local ty = self.y + r - 1
                if ty >= 1 and ty <= 40 and tx >= 1 and tx <= 10 then
                    self.board.grid[ty][tx] = self.id
                end
            end
        end
    end
    self.locked = true

    PPSCounter.register(self.board)
    AudioManager.playImmediateSFX("drop", self.board.player_type == "bot", self.y)
    if _G.NotifyPieceLock then _G.NotifyPieceLock() end

    if self.board.checkLines then self.board:checkLines()
    elseif self.board.clearLines then self.board:clearLines() end
end

function Piece:drawBlock(bx, by, id, alpha)
    if self.board and self.board.drawBlock then
        self.board:drawBlock(bx, by, id, alpha)
    end
end

function Piece:draw(bx, by)
    local shape = self.shape[self.rotation]
    love.graphics.push("all")

    if self.board and bx == self.board.x and by == self.board.y then
        local gy = self.y
        while self:canMove(self.x, gy + 1, self.rotation) do gy = gy + 1 end
        for r = 1, #shape do
            for c = 1, #shape[r] do
                if shape[r][c] ~= 0 then
                    self:drawBlock(bx + (self.x + c - 2) * 24, by + (gy + r - 22) * 24, self.id, 0.22)
                end
            end
        end
    end

    for r = 1, #shape do
        for c = 1, #shape[r] do
            if shape[r][c] ~= 0 then
                self:drawBlock(bx + (self.x + c - 2) * 24, by + (self.y + r - 22) * 24, self.id, 1.0)
            end
        end
    end
    love.graphics.pop()
end

function Piece:drawMini()
    local shape = self.shape[self.rotation] or self.shape[1]
    if not shape or type(shape) ~= "table" then return end
    for r = 1, #shape do
        for c = 1, #shape[r] do
            if shape[r][c] ~= 0 then
                self:drawBlock((c - 1) * 24, (r - 1) * 24, self.id, 1.0)
            end
        end
    end
end

return Piece

---@diagnostic disable: undefined-global
local AIBot = {}
AIBot.__index = AIBot

function AIBot.new(board, profile)
    local self = setmetatable({}, AIBot)
    self.board = board
    self.base_pps = profile.pps == 6.0 and 12.0 or (profile.pps or 3.0)
    self.pps = self.base_pps
    self.move_timer = 0
    self.target_x, self.target_rot = nil, nil
    self.is_thinking = false
    self.just_locked = false 

    -- Buffers reutilizables para evaluate() (política Zero-GC: nada de tablas
    -- nuevas dentro del loop de búsqueda, que corre hasta ~56 veces por think()).
    self._overlay = {}
    for i = 1, 400 do self._overlay[i] = false end
    self._heights = {}
    self._top_found = {}
    for i = 1, 10 do self._heights[i], self._top_found[i] = 0, false end

    return self
end

function AIBot:update(dt)
    -- Seguridad: Si no hay pieza o está bloqueada, no hacer nada
    if not self.board.active_piece or self.board.active_piece.locked or self.just_locked then 
        if self.board.active_piece and not self.board.active_piece.locked then
            self.just_locked = false 
        end
        return 
    end
    
    local active_punch = _G.TrackEnergyPunch or 0
    self.pps = self.base_pps + (active_punch * 8.0)

    self.move_timer = self.move_timer + dt
    if self.move_timer >= (1 / self.pps) then
        if not self.is_thinking then self:think() else self:executeMove() end
        self.move_timer = 0
    end
end

function AIBot:think()
    local p = self.board.active_piece
    -- Doble comprobación de seguridad para evitar el error 'canMove' nil
    if not p or p.locked or type(p.canMove) ~= "function" then return end
    
    local best_score = -2000000
    local max_rot = #p.shape
    
    for r = 1, max_rot do
        for x = -2, 11 do
            if p:canMove(x, p.y, r) then
                local gy = p.y
                while p:canMove(x, gy + 1, r) do gy = gy + 1 end
                local score = self:evaluate(x, gy, r)
                
                -- Bonus agresivo: Si es una pieza T, intentar buscar T-Spins
                if p.id == 6 and score > -500000 then
                    -- Simulamos la rotación para ver si activaría el T-Spin
                    local old_x, old_y, old_r = p.x, p.y, p.rotation
                    p.x, p.y, p.rotation = x, gy, r
                    if p:checkTSpin() then score = score + 1500 end
                    p.x, p.y, p.rotation = old_x, old_y, old_r
                end

                if score > best_score then
                    best_score = score
                    self.target_x, self.target_rot = x, r
                end
            end
        end
    end
    self.is_thinking = true
end

-- Evalúa qué tan buena es la posición (px, py, pr) para la pieza activa.
-- Produce EXACTAMENTE los mismos puntajes que la versión original (misma
-- fórmula de altura/holes/bumpiness/líneas), pero evita:
--   1. Recorrer la forma completa de la pieza (hasta 16 celdas) por cada una
--      de las 400 celdas del tablero -- ahora la posición de la pieza se
--      "estampa" una sola vez en un buffer plano reutilizable.
--   2. Escanear el tablero dos veces (una para heights/holes, otra para
--      líneas completas) -- ahora se hace en un único recorrido.
function AIBot:evaluate(px, py, pr)
    local grid = self.board.grid
    local shape = self.board.active_piece.shape[pr]

    local overlay = self._overlay
    for i = 1, 400 do overlay[i] = false end
    for sr = 1, #shape do
        local srow = shape[sr]
        for sc = 1, #srow do
            if srow[sc] ~= 0 then
                local tr, tc = py + sr - 1, px + sc - 1
                if tr >= 1 and tr <= 40 and tc >= 1 and tc <= 10 then
                    overlay[(tr - 1) * 10 + tc] = true
                end
            end
        end
    end

    local heights = self._heights
    local top_found = self._top_found
    for c = 1, 10 do heights[c], top_found[c] = 0, false end

    local holes = 0
    local lines_cleared = 0

    for r = 1, 40 do
        local row_full = true
        local base = (r - 1) * 10
        for c = 1, 10 do
            local occupied = (grid[r][c] ~= 0) or overlay[base + c]
            if occupied then
                if not top_found[c] then
                    heights[c] = 41 - r
                    top_found[c] = true
                end
            else
                row_full = false
                if top_found[c] then holes = holes + 1 end
            end
        end
        if row_full then lines_cleared = lines_cleared + 1 end
    end

    local max_h, bumpiness = 0, 0
    for i = 1, 10 do
        if heights[i] > max_h then max_h = heights[i] end
        if i < 10 then bumpiness = bumpiness + math.abs(heights[i] - heights[i + 1]) end
    end

    local score = 0
    score = score - (max_h * max_h * 5.0)    -- Penalizar altura
    score = score - (holes * 250.0)         -- Penalizar huecos (MUCHO)
    score = score - (bumpiness * 15.0)      -- Penalizar irregularidad

    if lines_cleared == 4 then
        score = score + 1000.0              -- Prioridad a Tetris
    elseif lines_cleared > 0 then
        score = score + (lines_cleared * 50.0)
    end

    return score
end

function AIBot:executeMove()
    local p = self.board.active_piece
    if not p or p.locked or not self.target_x then 
        self.is_thinking = false
        return 
    end
    
    local max_rot = #p.shape
    local real_target_rot = ((self.target_rot - 1) % max_rot) + 1
    
    -- Ejecutar rotación
    if p.rotation ~= real_target_rot then
        p:rotate(1)
    -- Ejecutar movimiento lateral
    elseif p.x < self.target_x then
        p:move(1, 0)
    elseif p.x > self.target_x then
        p:move(-1, 0)
    -- Si está en posición, Hard Drop
    else
        local startY = p.y
        while p:move(0, 1, true) do end
        local endY = p.y
        self.board:spawnTrail(p.x, startY, endY, p.id, p.shape[p.rotation])
        p:lock()
        self.is_thinking = false
        self.just_locked = true 
    end
end

return AIBot
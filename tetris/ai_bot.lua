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

function AIBot:evaluate(px, py, pr)
    local grid = self.board.grid
    local shape = self.board.active_piece.shape[pr]
    
    local heights = {}
    local holes = 0
    local wells_depth = 0
    
    for c = 1, 10 do
        local h = 0
        for r = 1, 40 do
            local occupied = (grid[r][c] ~= 0)
            if not occupied then
                for sr=1, #shape do
                    for sc=1, #shape[sr] do
                        if shape[sr][sc] ~= 0 and (px+sc-1 == c) and (py+sr-1 == r) then occupied = true end
                    end
                end
            end
            if occupied then 
                if h == 0 then h = 41 - r end
            elseif h > 0 then 
                holes = holes + 1
            end
        end
        heights[c] = h
    end
    
    local max_h, bumpiness = 0, 0
    for i=1, 10 do
        if heights[i] > max_h then max_h = heights[i] end
        if i < 10 then bumpiness = bumpiness + math.abs(heights[i] - heights[i+1]) end
    end

    local lines_cleared = 0
    for r = 1, 40 do
        local row_full = true
        for c = 1, 10 do
            local cell_occupied = (grid[r][c] ~= 0)
            for sr=1, #shape do
                for sc=1, #shape[sr] do
                    if shape[sr][sc] ~= 0 and (px+sc-1 == c) and (py+sr-1 == r) then cell_occupied = true end
                end
            end
            if not cell_occupied then row_full = false; break end
        end
        if row_full then lines_cleared = lines_cleared + 1 end
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
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

    -- Buffers planos pre-alocados para evaluación Zero-GC
    self._overlay = {}
    for i = 1, 400 do self._overlay[i] = false end
    
    self._heights = {}
    self._top_found = {}
    self._hole_depths = {}
    for i = 1, 10 do 
        self._heights[i] = 0
        self._top_found[i] = false
        self._hole_depths[i] = 0
    end

    return self
end

function AIBot:update(dt)
    if not self.board.active_piece or self.board.active_piece.locked or self.just_locked then 
        if self.board.active_piece and not self.board.active_piece.locked then
            self.just_locked = false 
        end
        return 
    end
    
    local active_punch = _G.TrackEnergyPunch or 0
    self.pps = self.base_pps + (active_punch * 8.0)

    -- Activación inteligente de Zone Mode para la IA
    if not self.board.is_zone_active and self.board.zone_meter >= 0.5 then
        local in_danger = #self.board.garbage_queue > 2
        local high_stack = false
        for c = 1, 10 do
            if self.board.grid[27][c] ~= 0 then high_stack = true break end
        end
        
        if (in_danger or high_stack or active_punch >= 0.95) then
            self.board:enterZone()
        end
    end

    self.move_timer = self.move_timer + dt
    if self.move_timer >= (1 / self.pps) then
        if not self.is_thinking then 
            self:think() 
        else 
            self:executeMove() 
        end
        self.move_timer = 0
    end
end

function AIBot:findGarbageHoleColumn()
    local grid = self.board.grid
    -- Escanear desde el fondo visible hacia arriba para ubicar el agujero de basura
    for r = 40, 21, -1 do
        local hole_col = nil
        local garbage_count = 0
        for c = 1, 10 do
            if grid[r][c] == 8 or grid[r][c] ~= 0 then
                garbage_count = garbage_count + 1
            elseif grid[r][c] == 0 then
                hole_col = c
            end
        end
        if garbage_count >= 8 and hole_col then
            return hole_col, r
        end
    end
    return nil, nil
end

function AIBot:think()
    local p = self.board.active_piece
    if not p or p.locked or type(p.canMove) ~= "function" then return end
    
    local best_score = -20000000
    local max_rot = #p.shape
    
    -- Detección de peligro
    local max_board_h = 0
    for r = 21, 40 do
        for c = 1, 10 do
            if self.board.grid[r][c] ~= 0 then
                local h = 41 - r
                if h > max_board_h then max_board_h = h end
            end
        end
    end
    
    local danger_mode = (max_board_h >= 9) or (#self.board.garbage_queue > 0)
    local target_hole_col, target_hole_row = self:findGarbageHoleColumn()

    for r = 1, max_rot do
        for x = -2, 11 do
            if p:canMove(x, p.y, r) then
                local gy = p.y
                while p:canMove(x, gy + 1, r) do gy = gy + 1 end
                local score = self:evaluate(x, gy, r, danger_mode, target_hole_col, target_hole_row)
                
                -- Si es pieza T y no estamos en peligro extremo, buscar T-Spins
                if p.id == 6 and not danger_mode and score > -500000 then
                    local old_x, old_y, old_r = p.x, p.y, p.rotation
                    p.x, p.y, p.rotation = x, gy, r
                    if p:checkTSpin() then 
                        score = score + 3500 
                    end
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

function AIBot:evaluate(px, py, pr, danger_mode, target_hole_col, target_hole_row)
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
    local hole_depths = self._hole_depths
    for c = 1, 10 do 
        heights[c] = 0
        top_found[c] = false 
        hole_depths[c] = 0
    end

    local holes = 0
    local covered_holes = 0
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
                if top_found[c] then 
                    holes = holes + 1 
                    hole_depths[c] = hole_depths[c] + 1
                    if hole_depths[c] > 1 then
                        covered_holes = covered_holes + 1
                    end
                end
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

    if danger_mode then
        -- MODO DOWNSTACKING QUIRÚRGICO DE ÉLITE
        score = score - (max_h * max_h * 16.0)     -- Penalización extrema a la altura
        score = score - (holes * 600.0)             -- Cero tolerancia a nuevos huecos
        score = score - (covered_holes * 850.0)     -- Bloquear huecos previos = muerte
        score = score - (bumpiness * 24.0)          -- Forzar grilla 100% plana

        -- Si conocemos la columna del pozo de basura, penalizar poner bloques encima si NO limpian línea
        if target_hole_col and lines_cleared == 0 then
            local shape_occupies_hole_col = false
            for sr = 1, #shape do
                for sc = 1, #shape[sr] do
                    if shape[sr][sc] ~= 0 and (px + sc - 1) == target_hole_col then
                        shape_occupies_hole_col = true
                        break
                    end
                end
            end
            if shape_occupies_hole_col then
                score = score - 1500.0 -- Castigo por obstruir la vía de escape
            end
        end

        -- Prioridad absoluta a despejar cualquier número de líneas para bajar el techo
        if lines_cleared > 0 then
            score = score + (lines_cleared * 450.0)
            if lines_cleared == 4 then score = score + 800.0 end
        end
    else
        -- MODO CONSTRUCCIÓN TETRIS ESTÁNDAR
        score = score - (max_h * max_h * 4.5)
        score = score - (holes * 320.0)
        score = score - (covered_holes * 250.0)
        score = score - (bumpiness * 14.0)

        if heights[10] < heights[9] - 1 then
            score = score + 90.0
        end

        if lines_cleared == 4 then
            score = score + 1300.0
        elseif lines_cleared > 0 then
            score = score + (lines_cleared * 30.0)
        end
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
    
    if p.rotation ~= real_target_rot then
        p:rotate(1)
    elseif p.x < self.target_x then
        p:move(1, 0)
    elseif p.x > self.target_x then
        p:move(-1, 0)
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
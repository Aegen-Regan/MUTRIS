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
    if not p or p.locked then return end
    
    local best_score = -2000000
    for r = 1, 4 do
        for x = -2, 11 do
            if p:canMove(x, p.y, r) then
                local gy = p.y
                while p:canMove(x, gy + 1, r) do gy = gy + 1 end
                local score = self:evaluate(x, gy, r)
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
    
    for c = 1, 9 do
        local l_height = (c == 1) and 40 or heights[c-1]
        local r_height = heights[c+1]
        local depth = math.min(l_height, r_height) - heights[c]
        if depth > 2 then wells_depth = wells_depth + depth end
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
    score = score - (max_h * max_h * 4.5)
    score = score - (holes * 200.0)         
    score = score - (bumpiness * 12.0)      
    score = score - (wells_depth * 10.0)    

    if lines_cleared == 4 then
        score = score + 800.0 
    elseif lines_cleared > 0 then
        score = score + (lines_cleared * 60.0)
    else
        if max_h < 8 and heights == 0 then score = score + 40.0 end
    end
    
    return score
end
function AIBot:executeMove()
    local p = self.board.active_piece
    if not p or p.locked then 
        self.is_thinking = false
        return 
    end
    
    -- CORRECCIÓN: Modulamos el target según cuántas rotaciones reales tiene indexadas esta pieza
    local max_rot = #p.shape
    local real_target_rot = ((self.target_rot - 1) % max_rot) + 1
    
    -- Contador de seguridad de hardware para forzar salida si la pieza se traba
    local safety_counter = 0
    while p.rotation ~= real_target_rot and safety_counter < 4 do
        if not p:rotate(1) then break end
        safety_counter = safety_counter + 1
    end
    
    if p.x < self.target_x then
        while p.x < self.target_x and p:move(1, 0) do end
    elseif p.x > self.target_x then
        while p.x > self.target_x and p:move(-1, 0) do end
    end
    
    if p.x ~= self.target_x or p.rotation ~= real_target_rot then
        return
    end
    
    self.board.drop_flash = {x = p.x, timer = 0.25}
    while p:move(0, 1) do end
    p:lock()
    
    self.is_thinking = false
    self.just_locked = true 
end

return AIBot

local Bag = {}
Bag.__index = Bag

function Bag.new()
    local self = setmetatable({}, Bag)
    self.contents = {}
    self.preview = {}
    self:refill()
    -- Llenar la previsualización inicial (5 piezas)
    for i = 1, 5 do table.insert(self.preview, self:pull_internal()) end
    return self
end

function Bag:refill()
    local temp = {1, 2, 3, 4, 5, 6, 7}
    for i = #temp, 2, -1 do
        local j = math.random(i)
        temp[i], temp[j] = temp[j], temp[i]
    end
    for i = 1, 7 do table.insert(self.contents, temp[i]) end
end

function Bag:pull_internal()
    if #self.contents == 0 then self:refill() end
    return table.remove(self.contents, 1)
end

function Bag:next()
    local next_piece = table.remove(self.preview, 1)
    table.insert(self.preview, self:pull_internal())
    return next_piece
end

function Bag:peek(count)
    local p = {}
    for i = 1, count do table.insert(p, self.preview[i]) end
    return p
end

return Bag
local ClashSystem = {}
ClashSystem.__index = ClashSystem

function ClashSystem.new()
    local self = setmetatable({}, ClashSystem)
    self.active = false
    self.target = "none" -- "p1" o "bot"
    self.timer = 0.0
    self.max_time = 1.3
    self.stacked_garbage = 0
    self.rally_count = 0
    self.center_x = 0
    self.center_y = 0
    self.p1_x = 0
    self.p1_y = 0
    self.bot_x = 0
    self.bot_y = 0
    self.pulse = 0.0
    self.flash_alpha = 0.0
    return self
end

function ClashSystem:setBoardPositions(p1_x, p1_y, bot_x, bot_y)
    self.p1_x = p1_x
    self.p1_y = p1_y
    self.bot_x = bot_x
    self.bot_y = bot_y
    self.center_x = (p1_x + bot_x) / 2
    self.center_y = (p1_y + bot_y) / 2
end

function ClashSystem:startClash(p1_atk, bot_atk, first_defender)
    self.active = true
    self.stacked_garbage = math.max(2, p1_atk + bot_atk)
    self.rally_count = 0
    self.target = first_defender or "bot"
    self.max_time = 1.3
    self.timer = self.max_time
    self.flash_alpha = 1.0
end

function ClashSystem:onLineClear(player_id)
    if not self.active or self.target ~= player_id then return false end
    
    -- Vanish Parry
    self.rally_count = self.rally_count + 1
    self.stacked_garbage = self.stacked_garbage + 1
    self.target = (player_id == "p1") and "bot" or "p1"
    self.max_time = math.max(0.5, 1.3 - (self.rally_count * 0.09))
    self.timer = self.max_time
    self.flash_alpha = 1.0
    return true
end

function ClashSystem:update(dt)
    if not self.active then return nil end
    
    self.pulse = self.pulse + dt * 12
    if self.flash_alpha > 0 then
        self.flash_alpha = math.max(0, self.flash_alpha - dt * 4)
    end
    
    self.timer = self.timer - dt
    if self.timer <= 0 then
        self.active = false
        local loser = self.target
        local dmg = math.floor(self.stacked_garbage * (1.0 + self.rally_count * 0.2))
        return loser, dmg
    end
    return nil
end

function ClashSystem:draw(p1_board_rect, bot_board_rect)
    if not self.active then return end
    
    local font = love.graphics.getFont()
    local is_p1_turn = (self.target == "p1")
    local target_x = is_p1_turn and self.p1_x or self.bot_x
    local target_y = is_p1_turn and self.p1_y or self.bot_y
    local source_x = is_p1_turn and self.bot_x or self.p1_x
    local source_y = is_p1_turn and self.bot_y or self.p1_y
    
    -- 1. Destello de Vanish Parry en pantalla
    if self.flash_alpha > 0 then
        love.graphics.setColor(1, 1, 1, self.flash_alpha * 0.3)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    end
    
    -- 2. RAYO LÁSER DE ENERGÍA CONECTOR ENTRE TABLEROS
    local beam_w = 6 + math.sin(self.pulse) * 3
    love.graphics.setLineWidth(beam_w + 6)
    love.graphics.setColor(0.9, 0.1, 0.9, 0.4) -- Aura exterior violeta
    love.graphics.line(source_x, source_y, target_x, target_y)
    
    love.graphics.setLineWidth(beam_w)
    if is_p1_turn then
        love.graphics.setColor(0.2, 0.9, 1.0, 0.95) -- Rayo Cyan
    else
        love.graphics.setColor(1.0, 0.2, 0.3, 0.95) -- Rayo Rojo
    end
    love.graphics.line(source_x, source_y, target_x, target_y)
    
    -- Núcleo blanco del láser
    love.graphics.setLineWidth(math.max(2, beam_w - 4))
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.line(source_x, source_y, target_x, target_y)
    
    -- 3. MARCO DE PELIGRO PULSANTE SOBRE EL TABLERO QUE DEBE DEFENDER
    local active_rect = is_p1_turn and p1_board_rect or bot_board_rect
    if active_rect then
        local alert_pulse = math.abs(math.sin(self.pulse * 0.8))
        love.graphics.setColor(1.0, 0.2, 0.2, 0.6 + alert_pulse * 0.4)
        love.graphics.setLineWidth(4 + alert_pulse * 3)
        love.graphics.rectangle("line", active_rect.x - 6, active_rect.y - 6, active_rect.w + 12, active_rect.h + 12, 6, 6)
        
        -- Cartel flotante sobre el tablero en peligro
        local alert_msg = is_p1_turn and "⚡ ¡HACÉ LÍNEA PARA HACER PARRY! ⚡" or "🤖 BOT DEFENDIENDO..."
        local alert_w = font:getWidth(alert_msg)
        love.graphics.setColor(0.05, 0.05, 0.1, 0.9)
        love.graphics.rectangle("fill", active_rect.x + (active_rect.w - alert_w) / 2 - 12, active_rect.y - 40, alert_w + 24, 28, 6, 6)
        love.graphics.setColor(1.0, 0.9, 0.1, 1.0)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", active_rect.x + (active_rect.w - alert_w) / 2 - 12, active_rect.y - 40, alert_w + 24, 28, 6, 6)
        love.graphics.print(alert_msg, active_rect.x + (active_rect.w - alert_w) / 2, active_rect.y - 34)
    end
    
    -- 4. ORBE DE ENERGÍA CENTRAL (Centro de la pantalla)
    local radius = 28 + math.sin(self.pulse) * 6
    love.graphics.push()
    love.graphics.translate(self.center_x, self.center_y)
    
    -- Aura
    love.graphics.setColor(0.9, 0.2, 0.9, 0.5)
    love.graphics.circle("fill", 0, 0, radius + 12)
    
    -- Núcleo
    if is_p1_turn then
        love.graphics.setColor(0.2, 0.9, 1.0, 1.0)
    else
        love.graphics.setColor(1.0, 0.25, 0.25, 1.0)
    end
    love.graphics.circle("fill", 0, 0, radius)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", 0, 0, radius)
    
    -- Timer Radial
    local progress = math.max(0, self.timer / self.max_time)
    love.graphics.setLineWidth(5)
    love.graphics.setColor(1.0, 0.9, 0.1, 1.0)
    love.graphics.arc("line", 0, 0, radius + 8, -math.pi / 2, -math.pi / 2 + (math.pi * 2 * progress))
    
    -- Texto de Daño Acumulado
    local dmg_txt = string.format("%d DMG", self.stacked_garbage)
    local rally_txt = string.format("RALLY x%d", self.rally_count)
    love.graphics.print(dmg_txt, math.floor(-font:getWidth(dmg_txt) / 2), -8)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print(rally_txt, math.floor(-font:getWidth(rally_txt) / 2), radius + 14)
    
    love.graphics.pop()
end

return ClashSystem

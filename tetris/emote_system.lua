local EmoteSystem = {}
EmoteSystem.__index = EmoteSystem

local MAX_EMOTES = 16

-- Generador de SFX Sintético Zero-Allocation (Beep de 8-bits)
local function createBeepSound()
    local rate = 44100
    local length = 0.08
    local data = love.sound.newSoundData(math.floor(rate * length), rate, 16, 1)
    for i = 0, data:getSampleCount() - 1 do
        local t = i / rate
        local freq = 880 + math.sin(t * 120) * 200 -- Tono ascendente
        local sample = math.sin(2 * math.pi * freq * t) * (1 - (i / data:getSampleCount()))
        data:setSample(i, sample * 0.4)
    end
    return love.audio.newSource(data, "static")
end

EmoteSystem.PRESETS = {
    BM_WINNING = { "< ¿TE DORMISTE? >", "[ SKILL ISSUE ]", "* GG WP *", "? ¿ESO ES TODO ?!", "! MUY LENTO !", "[ EZ PZ ]" },
    ATTACK_SPIKE = { ">> ¡TOMÁ! <<", "** ¡BOOM! **", "!! ATAJÁ ESTA !!", "[ PARSEADO ]", ">> PAQUETE EXPRESS" },
    PANIC = { "!! ¡PARÁ UN POCO! !!", "** ¡NOOO! **", "X_X FATAL ERROR", "!! ¡AUXILIO! !!" },
    CLUTCH = { "[ OUTPLAYED ]", ">> NI CERCA <<", "* ZEN *", "[ LIMPITO ]" },
    TEST = { "[ PROBANDO EMOTE ]", ">> FUNCIONA PERFECTO", "** EN TU CARA **" }
}

function EmoteSystem.new()
    local self = setmetatable({}, EmoteSystem)
    
    self.beep_sfx = nil
    pcall(function() self.beep_sfx = createBeepSound() end)
    
    self.pool = {}
    for i = 1, MAX_EMOTES do
        self.pool[i] = {
            active = false,
            text = "",
            x = 0, y = 0, origin_y = 0,
            timer = 0, duration = 2.5,
            scale = 1.0, alpha = 1.0,
            r = 1.0, g = 1.0, b = 1.0,
            shake = 0.0
        }
    end
    return self
end

function EmoteSystem:trigger(text, x, y, r, g, b, is_heavy)
    r = r or 1.0
    g = g or 1.0
    b = b or 1.0
    
    -- Reproducir SFX sintético si está disponible
    if self.beep_sfx then
        self.beep_sfx:stop()
        self.beep_sfx:setPitch(is_heavy and 0.85 or 1.2)
        self.beep_sfx:play()
    end
    
    for i = 1, MAX_EMOTES do
        local e = self.pool[i]
        if not e.active then
            e.active = true
            e.text = text
            e.x = x
            e.y = y
            e.origin_y = y
            e.timer = 0
            e.duration = is_heavy and 3.0 or 2.0
            e.base_scale = is_heavy and love.math.random(250, 300)/100 or love.math.random(180, 220)/100
            e.scale = 0
            e.pop_scale = 0
            e.rotation = (x < 640) and -0.08 or 0.08
            e.alpha = 0
            e.r, e.g, e.b = r, g, b
            e.shake = is_heavy and 1.0 or 0.0
            return e
        end
    end
    return nil
end

function EmoteSystem:triggerPreset(category, x, y, r, g, b, is_heavy)
    local list = self.PRESETS[category]
    if not list or #list == 0 then return nil end
    local text = list[love.math.random(1, #list)]
    return self:trigger(text, x, y, r, g, b, is_heavy)
end

function EmoteSystem:update(dt)
    for i = 1, MAX_EMOTES do
        local e = self.pool[i]
        if e.active then
            e.timer = e.timer + dt
            
            -- Alpha In/Out smooth
            if e.timer < 0.2 then
                e.alpha = e.timer / 0.2
            elseif e.timer > e.duration - 0.5 then
                e.alpha = math.max(0, (e.duration - e.timer) / 0.5)
            else
                e.alpha = 1.0
            end
            
            -- Animación Pop (Bounce elástico inicial)
            if e.timer < 0.4 then
                local t = e.timer / 0.4
                -- Función de rebote elástico (overshoot)
                local bounce = 1.0 + math.sin(t * math.pi * 1.5) * (1.0 - t) * 0.5
                e.scale = e.base_scale * bounce
            else
                e.scale = e.base_scale
            end
            
            -- Flotación suave hacia arriba y deriva lateral
            e.y = e.origin_y - (e.timer * 40)
            e.x = e.x + math.sin(e.timer * 3) * 0.5
            
            if e.shake > 0 then
                e.shake = math.max(0, e.shake - dt * 10)
            end
            
            if e.timer >= (e.duration - 0.5) then
                local p = (e.timer - (e.duration - 0.5)) / 0.5
                e.alpha = math.max(0.0, 1.0 - p)
            else
                e.alpha = 1.0
            end
            
            if e.timer >= e.duration then
                e.active = false
            end
        end
    end
end

function EmoteSystem:draw()
    local FontCache = require("tetris.font_cache")
    -- Tamaño masivo para impacto "EN LA FRENTE"
    love.graphics.setFont(FontCache.get(32))
    
    local font = love.graphics.getFont()
    local prev_r, prev_g, prev_b, prev_a = love.graphics.getColor()
    
    for i = 1, MAX_EMOTES do
        local e = self.pool[i]
        if e.active then
            local text_w = font:getWidth(e.text)
            local text_h = font:getHeight()
            local box_w = text_w + 36
            local box_h = text_h + 20
            
            local off_x = (e.shake > 0) and (love.math.random(-3, 3)) or 0
            local off_y = (e.shake > 0) and (love.math.random(-3, 3)) or 0
            
            love.graphics.push()
            love.graphics.translate(math.floor(e.x + off_x), math.floor(e.y + off_y))
            love.graphics.rotate(e.rotation)
            love.graphics.scale(e.scale, e.scale)
            
            -- 1. Glow Exterior
            love.graphics.setColor(e.r, e.g, e.b, 0.45 * e.alpha)
            love.graphics.rectangle("fill", -box_w / 2 - 8, -box_h / 2 - 8, box_w + 16, box_h + 16, 10, 10)
            
            -- 2. Fondo Negro Puro de Alto Contraste
            love.graphics.setColor(0.01, 0.01, 0.03, 0.98 * e.alpha)
            love.graphics.rectangle("fill", -box_w / 2, -box_h / 2, box_w, box_h, 8, 8)
            
            -- 3. Borde Neón Súper Grueso (3.5px)
            love.graphics.setColor(e.r, e.g, e.b, 1.0 * e.alpha)
            love.graphics.setLineWidth(3.5)
            love.graphics.rectangle("line", -box_w / 2, -box_h / 2, box_w, box_h, 8, 8)
            
            -- 4. Texto
            love.graphics.setColor(1.0, 1.0, 1.0, e.alpha)
            love.graphics.print(e.text, math.floor(-text_w / 2), math.floor(-text_h / 2))
            
            love.graphics.pop()
        end
    end
    
    love.graphics.setColor(prev_r, prev_g, prev_b, prev_a)
end

return EmoteSystem

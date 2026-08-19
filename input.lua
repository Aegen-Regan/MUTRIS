local Input = {}

-- DAS y ARR de nivel competitivo (Jstris/Tetrio style)
local DAS, ARR = 0.094, 0.008 

function Input.init(player_ref)
    Input.player = player_ref
    Input.timers = { left = 0, right = 0 }
    Input.das_active = { left = false, right = false }
end

function Input.getSoftDropFactor()
    if Input.player and Input.player.active_piece then
        if love.keyboard.isDown("kp5") and Input.player.active_piece.spawn_timer <= 0 then 
            return 0.005 -- Velocidad casi instantánea
        end
    end
    return 0.8 -- Gravedad normal
end

function Input.update(dt)
    if not Input.player or not Input.player.active_piece then return end
    local p = Input.player.active_piece
    if p.locked then return end

    -- MOVER IZQUIERDA (Numpad 4)
    if love.keyboard.isDown("kp4") then
        if not Input.das_active.left then
            p:move(-1, 0)
            Input.das_active.left = true
            Input.timers.left = 0
        else
            Input.timers.left = Input.timers.left + dt
            if Input.timers.left >= DAS then
                if ARR == 0 then 
                    while p:move(-1, 0) do end 
                    Input.timers.left = DAS
                else 
                    -- CORRECCIÓN: Restamos el ARR de forma acumulativa para un ritmo perfecto
                    while Input.timers.left >= DAS do
                        p:move(-1, 0)
                        Input.timers.left = Input.timers.left - ARR
                    end
                end
            end
        end
    else 
        Input.das_active.left = false 
    end

    -- MOVER DERECHA (Numpad 6)
    if love.keyboard.isDown("kp6") then
        if not Input.das_active.right then
            p:move(1, 0)
            Input.das_active.right = true
            Input.timers.right = 0
        else
            Input.timers.right = Input.timers.right + dt
            if Input.timers.right >= DAS then
                if ARR == 0 then 
                    while p:move(1, 0) do end 
                    Input.timers.right = DAS
                else 
                    -- CORRECCIÓN: Consumo matemático de tiempo idéntico para el lateral derecho
                    while Input.timers.right >= DAS do
                        p:move(1, 0)
                        Input.timers.right = Input.timers.right - ARR
                    end
                end
            end
        end
    else 
        Input.das_active.right = false 
    end
end

function Input.keypressed(key)
    if key == "r" then 
        if GlobalRestart then GlobalRestart() end 
        return 
    end
    
    if not Input.player or not Input.player.active_piece then return end
    local p = Input.player.active_piece
    if p.locked then return end

    if key == "a" then 
        p:rotate(1)
    elseif key == "d" then 
        p:rotate(-1)
    elseif key == "kp8" then 
        p:rotate(2)
    elseif key == "s" then 
        Input.player:hold()
    elseif key == "q" then 
        Input.player:enterZone()
    elseif key == "space" then 
        if Input.player then
            Input.player.drop_flash = {x = p.x, timer = 0.25}
            while p:move(0, 1) do end
            p:lock()
        end
    end
end

return Input

local Input = {}

local DAS, ARR = 0.094, 0.008 

function Input.init(player_ref)
    Input.player = player_ref
    Input.timers = { left = 0, right = 0 }
    Input.das_active = { left = false, right = false }
end

function Input.getSoftDropFactor()
    if Input.player and Input.player.active_piece then
        -- Detecta 5 (teclado normal), kp5 (numérico), down (flecha) y clear (5 sin numlock)
        if love.keyboard.isDown("kp5") or love.keyboard.isDown("5") or 
           love.keyboard.isDown("down") or love.keyboard.isDown("clear") then 
            return 0.001 -- Velocidad de caída casi instantánea
        end
    end
    return 0.8 
end

function Input.update(dt)
    if not Input.player or not Input.player.active_piece then return end
    local p = Input.player.active_piece
    if p.locked then return end

    -- Mover Izquierda
    if love.keyboard.isDown("kp4") or love.keyboard.isDown("left") then
        if not Input.das_active.left then
            p:move(-1, 0)
            Input.das_active.left = true
            Input.timers.left = 0
        else
            Input.timers.left = Input.timers.left + dt
            while Input.timers.left >= DAS do
                p:move(-1, 0)
                Input.timers.left = Input.timers.left - ARR
            end
        end
    else Input.das_active.left = false end

    -- Mover Derecha
    if love.keyboard.isDown("kp6") or love.keyboard.isDown("right") then
        if not Input.das_active.right then
            p:move(1, 0)
            Input.das_active.right = true
            Input.timers.right = 0
        else
            Input.timers.right = Input.timers.right + dt
            while Input.timers.right >= DAS do
                p:move(1, 0)
                Input.timers.right = Input.timers.right - ARR
            end
        end
    else Input.das_active.right = false end
end

function Input.keypressed(key)
    if key == "r" then GlobalRestart() return end
    if not Input.player or not Input.player.active_piece then return end
    local p = Input.player.active_piece
    if p.locked then return end

    if key == "a" or key == "z" then p:rotate(1)
    elseif key == "d" or key == "x" then p:rotate(-1)
    elseif key == "kp8" or key == "up" then p:rotate(2)
    elseif key == "s" or key == "c" then Input.player:hold()
    elseif key == "q" then Input.player:enterZone()
    elseif key == "space" then 
        Input.player.drop_flash = {x = p.x, timer = 0.25}
        while p:move(0, 1) do end
        p:lock()
    end
end

return Input
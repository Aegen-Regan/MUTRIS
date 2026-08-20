---@diagnostic disable: undefined-global
local Input = {}

local DAS, ARR = 0.094, 0.008 

function Input.init(player_ref)
    Input.player = player_ref
    Input.timers = { left = 0, right = 0 }
    Input.das_active = { left = false, right = false }
    Input.gamepad_btn_prev = {}
end

local function isGamepadDown(button_name)
    local joysticks = love.joystick.getJoysticks()
    for _, js in ipairs(joysticks) do
        if js:isGamepad() and js:isGamepadDown(button_name) then
            return true
        end
    end
    return false
end

local function isGamepadAxisDown(axis_name, threshold, greater_than)
    local joysticks = love.joystick.getJoysticks()
    for _, js in ipairs(joysticks) do
        if js:isGamepad() then
            local val = js:getGamepadAxis(axis_name)
            if greater_than and val > threshold then return true end
            if not greater_than and val < threshold then return true end
        end
    end
    return false
end

function Input.getSoftDropFactor()
    if Input.player and Input.player.active_piece then
        if love.keyboard.isDown("kp5") or love.keyboard.isDown("5") or 
           love.keyboard.isDown("down") or love.keyboard.isDown("clear") or
           isGamepadDown("dpdown") or isGamepadAxisDown("lefty", 0.5, true) then 
            return 0.001
        end
    end
    return 0.8 
end

function Input.update(dt)
    if not Input.player or not Input.player.active_piece then return end
    local p = Input.player.active_piece
    if p.locked then return end

    local move_left_held = love.keyboard.isDown("kp4") or love.keyboard.isDown("left") or 
                           isGamepadDown("dpleft") or isGamepadAxisDown("leftx", -0.5, false)
    if move_left_held then
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
    else
        Input.das_active.left = false
    end

    local move_right_held = love.keyboard.isDown("kp6") or love.keyboard.isDown("right") or 
                            isGamepadDown("dpright") or isGamepadAxisDown("leftx", 0.5, true)
    if move_right_held then
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
    else
        Input.das_active.right = false
    end
end

function Input.handleAction(action)
    if action == "restart" then GlobalRestart() return end
    if not Input.player or not Input.player.active_piece then return end
    local p = Input.player.active_piece
    if p.locked then return end

    if action == "rot_cw" then p:rotate(1)
    elseif action == "rot_ccw" then p:rotate(-1)
    elseif action == "rot_180" then p:rotate(2)
    elseif action == "hold" then Input.player:hold()
    elseif action == "zone" then Input.player:enterZone()
    elseif action == "hard_drop" then
        if Input.player then
            local startY = p.y
            while p:move(0, 1, true) do end
            local endY = p.y
            Input.player:spawnTrail(p.x, startY, endY, p.id, p.shape[p.rotation])
            p:lock()
        end
    end
end

function Input.keypressed(key)
    if key == "r" then Input.handleAction("restart")
    elseif key == "a" or key == "z" then Input.handleAction("rot_cw")
    elseif key == "d" or key == "x" then Input.handleAction("rot_ccw")
    elseif key == "kp8" or key == "up" then Input.handleAction("rot_180")
    elseif key == "s" or key == "c" then Input.handleAction("hold")
    elseif key == "q" then Input.handleAction("zone")
    elseif key == "space" then Input.handleAction("hard_drop")
    end
end

function Input.gamepadpressed(joystick, button)
    if button == "start" or button == "back" then Input.handleAction("restart")
    elseif button == "a" or button == "b" then Input.handleAction("rot_cw")
    elseif button == "x" or button == "y" then Input.handleAction("rot_ccw")
    elseif button == "dpup" then Input.handleAction("rot_180")
    elseif button == "leftshoulder" or button == "lefttrigger" then Input.handleAction("hold")
    elseif button == "rightshoulder" or button == "righttrigger" then Input.handleAction("hard_drop")
    end
end

return Input
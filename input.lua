-- ================================================================
-- FILE: input.lua
-- ================================================================
---@diagnostic disable: undefined-global
local Input = {}

local SettingsManager = require "settings_manager"
local ThemeManager    = require "tetris.theme_manager"
local RulesetManager  = require "core.ruleset_manager"
local HuntingForge    = require "combat.hunting_forge"

INPUT_CONFIG = {
    TIMEBASE_MODE           = "gpu",
    FALLBACK_DAS            = 0.096,
    FALLBACK_ARR            = 0.008,
    ARR_ABSOLUTE_MIN        = 0.001,
    JOY_DEADZONE_LEFT_RIGHT = 0.5,
    JOY_DEADZONE_DOWN       = 0.5,
    JOY_CACHE_POOL_SIZE     = 8,
    SOFT_DROP_SPEED         = 0.001,
    NORMAL_GRAVITY          = 0.8,
    MAX_AUDIO_DT_SAFETY     = 0.1,
    MAX_ARR_STEPS_PER_FRAME = 32
}

function Input.init(player_ref)
    Input.player = player_ref

    Input.joystick_pool = {}
    for i = 1, INPUT_CONFIG.JOY_CACHE_POOL_SIZE do
        Input.joystick_pool[i] = false
    end
    Input.joystick_count = 0

    Input.timers = { left = 0, right = 0 }
    Input.das_active = { left = false, right = false }
    Input.last_audio_time = 0.0
    Input.drop_lock_frames = 0

    Input._refreshJoystickCache()
end

function Input._refreshJoystickCache()
    local list = love.joystick.getJoysticks()
    Input.joystick_count = 0
    for i = 1, INPUT_CONFIG.JOY_CACHE_POOL_SIZE do
        if i <= #list then
            Input.joystick_pool[i] = list[i]
            Input.joystick_count = Input.joystick_count + 1
        else
            Input.joystick_pool[i] = false
        end
    end
end

local function _isGamepadDown(button_name)
    for i = 1, Input.joystick_count do
        local js = Input.joystick_pool[i]
        if js and js ~= false and js:isGamepad() then
            if js:isGamepadDown(button_name) then return true end
        end
    end
    return false
end

local function _isGamepadAxisDown(axis_name, threshold, greater_than)
    for i = 1, Input.joystick_count do
        local js = Input.joystick_pool[i]
        if js and js ~= false and js:isGamepad() then
            local val = js:getGamepadAxis(axis_name)
            if greater_than and val > threshold then return true end
            if not greater_than and val < threshold then return true end
        end
    end
    return false
end

function Input.getSoftDropFactor()
    if (Input.drop_lock_frames or 0) > 0 then
        return 0.8
    end

    if Input.player and Input.player.active_piece then
        local custom_down = SettingsManager.get("key_soft_drop") or "down"
        local down_held = love.keyboard.isDown(custom_down) or
                          _isGamepadDown("dpdown") or _isGamepadAxisDown("lefty", INPUT_CONFIG.JOY_DEADZONE_DOWN, true)

        if down_held then
            local sdf_mult = SettingsManager.get("sdf") or 40.0
            if sdf_mult >= 40.0 then return 0.001 end
            return 0.8 / math.max(1.0, sdf_mult)
        end
    end
    return 0.8
end

function Input.update(dt)
    if (Input.drop_lock_frames or 0) > 0 then
        Input.drop_lock_frames = Input.drop_lock_frames - 1
    end

    if not Input.player or not Input.player.active_piece then return end
    local p = Input.player.active_piece
    if p.locked then return end

    local t = dt
    local das = (SettingsManager.get("das") or INPUT_CONFIG.FALLBACK_DAS) + HuntingForge.getDASOffset()
    local arr = math.max(INPUT_CONFIG.ARR_ABSOLUTE_MIN, SettingsManager.get("arr") or INPUT_CONFIG.FALLBACK_ARR)

    -- Mover Izquierda
    local custom_left = SettingsManager.get("key_left") or "left"
    local move_left_held = love.keyboard.isDown(custom_left) or
                           _isGamepadDown("dpleft") or _isGamepadAxisDown("leftx", -INPUT_CONFIG.JOY_DEADZONE_LEFT_RIGHT, false)
    if move_left_held then
        if not Input.das_active.left then
            p:move(-1, 0)
            Input.das_active.left = true
            Input.timers.left = 0
        else
            Input.timers.left = Input.timers.left + t
            while Input.timers.left >= das do
                if not p:move(-1, 0) then
                    Input.timers.left = 0
                    break
                end
                Input.timers.left = Input.timers.left - arr
            end
        end
    else
        Input.das_active.left = false
    end

    -- Mover Derecha
    local custom_right = SettingsManager.get("key_right") or "right"
    local move_right_held = love.keyboard.isDown(custom_right) or
                            _isGamepadDown("dpright") or _isGamepadAxisDown("leftx", INPUT_CONFIG.JOY_DEADZONE_LEFT_RIGHT, true)
    if move_right_held then
        if not Input.das_active.right then
            p:move(1, 0)
            Input.das_active.right = true
            Input.timers.right = 0
        else
            Input.timers.right = Input.timers.right + t
            while Input.timers.right >= das do
                if not p:move(1, 0) then
                    Input.timers.right = 0
                    break
                end
                Input.timers.right = Input.timers.right - arr
            end
        end
    else
        Input.das_active.right = false
    end
end

function Input.handleAction(action)
    if action == "restart" then
        if _G.GlobalRestart then _G.GlobalRestart(false) end
        return
    end

    if action == "theme_next" then
        ThemeManager.cycleNext()
        return
    elseif action == "theme_prev" then
        ThemeManager.cyclePrev()
        return
    end

    if not Input.player or not Input.player.active_piece then return end
    local p = Input.player.active_piece
    if p.locked then return end

    if action == "rot_cw" then 
        p:rotate(1)
    elseif action == "rot_ccw" then 
        p:rotate(-1)
    elseif action == "rot_180" then
        local srs_180 = SettingsManager.get("srs_180")
        if srs_180 == 1 or srs_180 == true or (type(srs_180) == "number" and srs_180 >= 0.5) then
            p:rotate(2)
        end
    elseif action == "hold" then
        local can_hold = not RulesetManager.allowHold or RulesetManager.allowHold()
        if can_hold then
            Input.player:hold()
            Input.drop_lock_frames = 2
            if Input.player.active_piece then
                Input.player.active_piece.gravity_timer = 0.0
                Input.player.active_piece.lock_timer = 0.0
            end
        end
    elseif action == "zone" then 
        Input.player:enterZone()
    elseif action == "hard_drop" then
        local can_hd = not RulesetManager.allowHardDrop or RulesetManager.allowHardDrop()
        if can_hd and (Input.drop_lock_frames or 0) == 0 then
            Input.drop_lock_frames = 2
            local startY = p.y
            while p:canMove(p.x, p.y + 1, p.rotation) do
                p.y = p.y + 1
            end
            local endY = p.y
            if Input.player.spawnTrail then
                Input.player:spawnTrail(p.x, startY, endY, p.id, p.shape[p.rotation])
            end
            p:lock()
        end
    end
end

function Input.keypressed(key)
    if key == "r" then 
        Input.handleAction("restart")
        return
    elseif key == "f5" then 
        Input.handleAction("theme_next")
        return
    elseif key == "f6" then 
        Input.handleAction("theme_prev")
        return
    end

    local k_cw     = SettingsManager.get("key_rot_cw")
    local k_ccw    = SettingsManager.get("key_rot_ccw")
    local k_180    = SettingsManager.get("key_rot_180")
    local k_hold   = SettingsManager.get("key_hold")
    local k_hd     = SettingsManager.get("key_hard_drop")
    local k_zone   = SettingsManager.get("key_zone")

    if k_ccw and key == k_ccw then
        Input.handleAction("rot_ccw")
    elseif k_cw and key == k_cw then
        Input.handleAction("rot_cw")
    elseif k_180 and key == k_180 then
        Input.handleAction("rot_180")
    elseif k_hold and key == k_hold then
        Input.handleAction("hold")
    elseif k_hd and key == k_hd then
        Input.handleAction("hard_drop")
    elseif k_zone and key == k_zone then
        Input.handleAction("zone")
    end
end

function Input.gamepadpressed(joystick, button)
    if button == "start" then Input.handleAction("restart")
    elseif button == "a" or button == "b" then Input.handleAction("rot_cw")
    elseif button == "x" or button == "y" then Input.handleAction("rot_ccw")
    elseif button == "dpup" then Input.handleAction("rot_180")
    elseif button == "leftshoulder" or button == "lefttrigger" then Input.handleAction("hold")
    elseif button == "rightshoulder" or button == "righttrigger" then Input.handleAction("hard_drop")
    end
end

return Input
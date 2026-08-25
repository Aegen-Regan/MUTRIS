-- ================================================================
-- FILE: input.lua (SISTEMA DE CONTROL DE BAJO IMPACTO ZERO-GC)
-- ================================================================
---@diagnostic disable: undefined-global
local Input = {
    -- Pools estáticas pre-asignadas en la carga inicial
    keys_pressed = {},
    keys_down = {},
    
    -- Configuración competitiva milimétrica (Estilo Jstris / TETR.IO)
    das_setting = 0.120, -- Delayed Auto Shift (120 milisegundos)
    arr_setting = 0.006, -- Auto Repeat Rate (6 milisegundos por iteración)
    sdf_setting = 40,    -- Soft Drop Factor (Multiplicador de gravedad x40)
}

local SettingsManager = require "settings_manager"
local ThemeManager    = require "tetris.theme_manager"
local RulesetManager  = require "core.ruleset_manager"
local HuntingForge    = require "combat.hunting_forge"
local BlackBox        = require "core.blackbox"
local AnomalyManager  = require "tetris.anomaly_manager"
local AudioManager    = require "audio_manager"
local SoundManager    = require "audio.sound_manager"

-- Mapeo inmediato de índices fijos para evitar que LuaJIT altere el hash-map
local common_keys = {
    "left", "right", "up", "down",   -- Movimiento y Drop
    "z", "x", "c",                   -- Rotación e inversión
    "a", "s",                        -- Sockets de la forja / Habilidades
    "r"                              -- Reinicio rápido / Halo nuclear
}

for i = 1, #common_keys do
    local key = common_keys[i]
    Input.keys_pressed[key] = false
    Input.keys_down[key] = false
end

function Input.init(player_ref)
    Input.player = player_ref

    Input.joystick_pool = {}
    Input.joystick_count = 0
    local list = love.joystick.getJoysticks()
    for i = 1, 8 do
        if i <= #list then
            Input.joystick_pool[i] = list[i]
            Input.joystick_count = Input.joystick_count + 1
        else
            Input.joystick_pool[i] = false
        end
    end

    Input.timers = { left = 0, right = 0 }
    Input.das_active = { left = false, right = false }
    Input.drop_lock_frames = 0
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
        local down_held = Input.keys_down[custom_down] or love.keyboard.isDown(custom_down) or
                          _isGamepadDown("dpdown") or _isGamepadAxisDown("lefty", 0.5, true)

        if down_held then
            local sdf_mult = SettingsManager.get("sdf") or Input.sdf_setting
            if sdf_mult >= 40.0 then return 0.001 end
            return 0.8 / math.max(1.0, sdf_mult)
        end
    end
    return 0.8
end

-- Ciclo de actualización de estados físicos
function Input.update(dt)
    -- Refresh baseline physical states dynamically
    for i = 1, #common_keys do
        local key = common_keys[i]
        Input.keys_down[key] = love.keyboard.isDown(key)
    end
    
    if (Input.drop_lock_frames or 0) > 0 then
        Input.drop_lock_frames = Input.drop_lock_frames - 1
    end

    if not Input.player or not Input.player.active_piece then return end
    local p = Input.player.active_piece
    if p.locked then return end

    local t = dt
    local das = (SettingsManager.get("das") or Input.das_setting) + HuntingForge.getDASOffset()
    local arr = math.max(0.001, SettingsManager.get("arr") or Input.arr_setting)

    -- --- 1. LEFT MOVEMENT INTERCEPTION (PASSED THROUGH ANOMALY FILTER) ---
    local raw_left = SettingsManager.get("key_left") or "left"
    local custom_left = (AnomalyManager and AnomalyManager.filter_direction) and AnomalyManager.filter_direction(raw_left) or raw_left

    local move_left_held = Input.keys_down[custom_left] or love.keyboard.isDown(custom_left) or
                           _isGamepadDown("dpleft") or _isGamepadAxisDown("leftx", -0.5, false)
    if move_left_held then
        if not Input.das_active.left then
            if p:move(-1, 0) then
                SoundManager.play_move_column(p.x)
            end
            Input.das_active.left = true
            Input.timers.left = 0
        else
            Input.timers.left = Input.timers.left + t
            while Input.timers.left >= das do
                if not p:move(-1, 0) then
                    Input.timers.left = 0
                    break
                end
                SoundManager.play_move_column(p.x)
                Input.timers.left = Input.timers.left - arr
            end
        end
    else
        Input.das_active.left = false
    end

    -- --- 2. RIGHT MOVEMENT INTERCEPTION (PASSED THROUGH ANOMALY FILTER) ---
    local raw_right = SettingsManager.get("key_right") or "right"
    local custom_right = (AnomalyManager and AnomalyManager.filter_direction) and AnomalyManager.filter_direction(raw_right) or raw_right

    local move_right_held = Input.keys_down[custom_right] or love.keyboard.isDown(custom_right) or
                            _isGamepadDown("dpright") or _isGamepadAxisDown("leftx", 0.5, true)
    if move_right_held then
        if not Input.das_active.right then
            if p:move(1, 0) then
                SoundManager.play_move_column(p.x)
            end
            Input.das_active.right = true
            Input.timers.right = 0
        else
            Input.timers.right = Input.timers.right + t
            while Input.timers.right >= das do
                if not p:move(1, 0) then
                    Input.timers.right = 0
                    break
                end
                SoundManager.play_move_column(p.x)
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

    if action == "theme_next" then ThemeManager.cycleNext(); return end
    if action == "theme_prev" then ThemeManager.cyclePrev(); return end

    if not Input.player or not Input.player.active_piece then return end
    local p = Input.player.active_piece
    if p.locked then return end

    if action == "rot_cw" then
        p:rotate(1)
        SoundManager.play_rotate(p.x)
    elseif action == "rot_ccw" then
        p:rotate(-1)
        SoundManager.play_rotate(p.x)
    elseif action == "rot_180" then
        local srs_180 = SettingsManager.get("srs_180")
        if srs_180 == 1 or srs_180 == true or (type(srs_180) == "number" and srs_180 >= 0.5) then
            p:rotate(2)
            SoundManager.play_rotate(p.x)
        end
    elseif action == "hold" then
        local can_hold = not RulesetManager.allowHold or RulesetManager.allowHold()
        if can_hold then
            Input.player:hold()
            SoundManager.play_hold()
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
            
            local EventBus = package.loaded["core.event_bus"] or require("core.event_bus")
            EventBus.emit("on_hard_drop", Input.player.player_type == "human" and 1 or 2)
        end
    end
end

-- Captura directa de flancos (Presión inicial). 
-- Integrado en el framework existente para ser llamado desde scene_game.lua
function Input.keypressed(key)
    -- Cerrojo estático contra repeticiones del SO (Zero-GC)
    if Input.keys_pressed[key] == true then return end 

    -- 1. Evaluamos de forma paramétrica si los controles están sufriendo una anomalía rítmica
    local effective_key = key
    if key == "left" or key == "right" then
        if AnomalyManager and AnomalyManager.filter_direction then
            effective_key = AnomalyManager.filter_direction(key)
        end
    end

    -- 2. Modificación directa de la bandera física efectiva
    Input.keys_pressed[effective_key] = true

    -- 3. --- TELEMETRÍA SONORA ACTIVADA ---
    if effective_key ~= key then
        if AudioManager and AudioManager.trigger_debug_ping then
            AudioManager.trigger_debug_ping(1200.0, -0.5) -- Alerta de inversión de mando
        end
    else
        if AudioManager and AudioManager.trigger_debug_ping then
            AudioManager.trigger_debug_ping(600.0, 0.5)  -- Input normal verificado
        end
    end

    -- --- TELEMETRÍA DE DATOS ACTIVADA ---
    BlackBox.record(BlackBox.TYPES.INPUT, effective_key == key and 1.0 or -1.0, effective_key)

    if effective_key == "r" then Input.handleAction("restart"); return end
    if effective_key == "f5" then Input.handleAction("theme_next"); return end
    if effective_key == "f6" then Input.handleAction("theme_prev"); return end

    local k_cw     = SettingsManager.get("key_rot_cw")
    local k_ccw    = SettingsManager.get("key_rot_ccw")
    local k_180    = SettingsManager.get("key_rot_180")
    local k_hold   = SettingsManager.get("key_hold")
    local k_hd     = SettingsManager.get("key_hard_drop")
    local k_zone   = SettingsManager.get("key_zone")

    if k_ccw and effective_key == k_ccw then Input.handleAction("rot_ccw")
    elseif k_cw and effective_key == k_cw then Input.handleAction("rot_cw")
    elseif k_180 and effective_key == k_180 then Input.handleAction("rot_180")
    elseif k_hold and effective_key == k_hold then Input.handleAction("hold")
    elseif k_hd and effective_key == k_hd then Input.handleAction("hard_drop")
    elseif k_zone and effective_key == k_zone then Input.handleAction("zone")
    end
end

function Input.keyreleased(key)
    if Input.keys_pressed[key] ~= nil then
        Input.keys_pressed[key] = false
    end

    -- --- TELEMETRÍA ACTIVADA ---
    BlackBox.record(BlackBox.TYPES.INPUT, 0.0, key)
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
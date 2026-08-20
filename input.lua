---@diagnostic disable: undefined-global
local Input = {}
local SettingsManager = require "settings_manager"

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  🎛️  PANEL DE CONTROL DE INPUT COMPETITIVO MUTRIS v0.9.5          ║
-- ║  Edita SOLO estos valores si querés calibrar sin tocar la lógica. ║
-- ║  MODOS DE TIMEBASE:                                                ║
-- ║    • "gpu"  → dt del render (feeling ESTILO JSTRIS — por defecto) ║
-- ║    • "audio" → anclado a placa de sonido (sync musical más fiel)  ║
-- ╚══════════════════════════════════════════════════════════════════════╝
INPUT_CONFIG = {
    -- ⏱️ Timebase (CAMBIÁ ESTO SI QUERÉS PROBAR AMBOS FEELINGS)
    TIMEBASE_MODE = "gpu",

    -- ⏱️ Tiempos (en SEGUNDOS). Pueden ser overridden por SettingsManager.settings.
    FALLBACK_DAS = 0.094,
    FALLBACK_ARR = 0.008,
    ARR_ABSOLUTE_MIN = 0.001,

    -- 🎮 Gamepad
    JOY_DEADZONE_LEFT_RIGHT = 0.5,
    JOY_DEADZONE_DOWN = 0.5,
    JOY_CACHE_POOL_SIZE = 8,

    -- ⬇️ Caída (mismos valores que el original)
    SOFT_DROP_SPEED = 0.001,
    NORMAL_GRAVITY = 0.8,

    -- 🛡️ Anti-glitch
    MAX_AUDIO_DT_SAFETY = 0.1,
    MAX_ARR_STEPS_PER_FRAME = 32
}

function Input.init(player_ref)
    Input.player = player_ref

    -- ── Pool estático de joysticks (Zero-GC — se mantiene del refactor) ──
    Input.joystick_pool = {}
    for i = 1, INPUT_CONFIG.JOY_CACHE_POOL_SIZE do
        Input.joystick_pool[i] = false
    end
    Input.joystick_count = 0

    -- ── Timers DAS/ARR (mismos nombres que ORIGINAL para 100% compatibilidad) ──
    Input.timers = { left = 0, right = 0 }
    Input.das_active = { left = false, right = false }

    -- ── Timebase ──
    Input.last_audio_time = 0.0

    -- ── Snapshot (Zero-GC) ──
    Input.btn_snapshot = {
        k_left  = false, k_right = false, k_down  = false,
        g_left  = false, g_right = false, g_down  = false
    }

    Input._refreshJoystickCache()
end

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  🔄  REFRESH CACHÉ JOYSTICKS (Zero-GC, solo por eventos)          ║
-- ╚══════════════════════════════════════════════════════════════════════╝
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

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  ⬇️  SOFT DROP FACTOR (igual al ORIGINAL — valores exactos)      ║
-- ╚══════════════════════════════════════════════════════════════════════╝
function Input.getSoftDropFactor()
    if Input.player and Input.player.active_piece then
        if love.keyboard.isDown("kp5") or love.keyboard.isDown("5") or
           love.keyboard.isDown("down") or love.keyboard.isDown("clear") or
           _isGamepadDown("dpdown") or _isGamepadAxisDown("lefty", INPUT_CONFIG.JOY_DEADZONE_DOWN, true) then
            return 0.001
        end
    end
    return 0.8
end

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  ⏱️  MOTOR DAS / ARR — FEELING JSTRIS RESTAURADO 100%             ║
-- ║  Regla matemática EXACTA del original:                             ║
-- ║    while timers[dir] >= DAS do                                      ║
-- ║        move()                                                        ║
-- ║        timers[dir] = timers[dir] - ARR                              ║
-- ║    end                                                              ║
-- ╚══════════════════════════════════════════════════════════════════════╝
function Input.update(dt)
    if not Input.player or not Input.player.active_piece then return end
    local p = Input.player.active_piece
    if p.locked then return end

    -- ⏱️ 1. TIMEBASE (switch configurable para probar ambos sentimientos)
    local t
    if INPUT_CONFIG.TIMEBASE_MODE == "audio" then
        local audio_now = 0
        if MusicManager and MusicManager.getTime then audio_now = MusicManager.getTime() end
        t = audio_now - Input.last_audio_time
        Input.last_audio_time = audio_now
        if t <= 0 or t > INPUT_CONFIG.MAX_AUDIO_DT_SAFETY then t = dt end
    else
        -- MODO GPU = JSTRIS FEELING (por defecto — restaurado)
        t = dt
    end

    local das = SettingsManager.settings.das or INPUT_CONFIG.FALLBACK_DAS
    local arr = math.max(INPUT_CONFIG.ARR_ABSOLUTE_MIN, SettingsManager.settings.arr or INPUT_CONFIG.FALLBACK_ARR)

    -- ⬅️ ── LADO IZQUIERDO (LÓGICA EXACTA DEL ORIGINAL) ──
    local move_left_held = love.keyboard.isDown("kp4") or love.keyboard.isDown("left") or
                           _isGamepadDown("dpleft") or _isGamepadAxisDown("leftx", -INPUT_CONFIG.JOY_DEADZONE_LEFT_RIGHT, false)
    if move_left_held then
        if not Input.das_active.left then
            p:move(-1, 0)                              -- ← TAP inicial (igual original: sin if extra)
            Input.das_active.left = true
            Input.timers.left = 0
        else
            Input.timers.left = Input.timers.left + t
            -- 🔑 REGLA MATEMÁTICA JSTRIS: while >= DAS, restar ARR. No restar DAS primero.
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

    -- ➡️ ── LADO DERECHO (LÓGICA EXACTA DEL ORIGINAL) ──
    local move_right_held = love.keyboard.isDown("kp6") or love.keyboard.isDown("right") or
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

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  🎮  ACCIONES PUNTUALES — IGUALES AL ORIGINAL 100%               ║
-- ╚══════════════════════════════════════════════════════════════════════╝
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
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: ARCHON META-BALANCER (FASE 12)
-- Arquitectura: Zero-GC / Serialización Atómica / Auto-Tuning Autónomo
-- ============================================================================
local MetaBalancer = {}

-- ⚙️ TABLA MAESTRA DE PARÁMETROS (Valores por Defecto Deterministas)
MetaBalancer.balance = {
    -- Beat-Lock (Fase 7)
    beat_window_ms       = 0.035,  -- Ventana estándar ±35ms
    beat_bonus_attack    = 1,      -- Líneas extra por Groove Strike
    
    -- Combat Stances (Fase 8)
    rush_atk_mult        = 1.50,   -- Multiplicador daño en Rush
    rush_lock_delay      = 0.12,   -- Lock delay ultrarrápido en Rush
    rush_arr             = 0.001,  -- ARR instantáneo en Rush
    bastion_atk_mult     = 0.50,   -- Daño reducido en Bastion
    bastion_intake_mult  = 0.50,   -- Basura entrante reducida en Bastion
    resonance_zone_mult  = 2.00,   -- Carga de Zone duplicada en Resonance
    resonance_window_ms  = 0.045,  -- Ventana Beat-Lock ampliada en Resonance
    
    -- Kinetic Parry (Fase 9)
    parry_window_frames  = 3,      -- Ventana de Parry (~0.050s a 60 FPS)
    parry_counter_ratio  = 0.50,   -- 50% de la basura devuelta como Counter-Spike
    
    -- Dynamic Difficulty Adjustment (DDA)
    ai_aggression_factor = 1.00,
    match_count_total    = 0,
    human_wins           = 0,
    bot_wins             = 0
}

MetaBalancer.patch_notes = "ARCHON v1.0: BASELINE BALANCE LOADED"
MetaBalancer.active_adjustment_flag = false

-- Serializador plano Zero-GC para evitar allocs dinámicos
local function serializeBalanceJSON(tbl)
    local s = "{\n"
    for k, v in pairs(tbl) do
        if type(v) == "number" then
            s = s .. string.format('  "%s": %.4f,\n', k, v)
        elseif type(v) == "string" then
            s = s .. string.format('  "%s": "%s",\n', k, v)
        end
    end
    s = s:sub(1, -3) .. "\n}"
    return s
end

local function parseBalanceJSON(str)
    local data = {}
    for k, v in str:gmatch('"([%w_]+)":%s*([%-%d%.]+)') do
        data[k] = tonumber(v)
    end
    for k, v in str:gmatch('"([%w_]+)":%s*"([^"]+)"') do
        data[k] = v
    end
    return data
end

function MetaBalancer.init()
    if not love.filesystem.getInfo("saves") then
        love.filesystem.createDirectory("saves")
    end

    if love.filesystem.getInfo("saves/game_balance.json") then
        local content = love.filesystem.read("saves/game_balance.json")
        if content then
            local loaded = parseBalanceJSON(content)
            for k, v in pairs(loaded) do
                if MetaBalancer.balance[k] ~= nil then
                    MetaBalancer.balance[k] = v
                end
            end
        end
    else
        MetaBalancer.save()
    end
end

function MetaBalancer.save()
    love.filesystem.write("saves/game_balance.json", serializeBalanceJSON(MetaBalancer.balance))
end

-- 🧠 ALGORITMO DE AUTO-EQUILIBRIO (Evaluado al terminar cada partida)
function MetaBalancer.registerMatchOutcome(human_won, match_duration, human_pps, bot_pps)
    local b = MetaBalancer.balance
    b.match_count_total = b.match_count_total + 1
    if human_won then
        b.human_wins = b.human_wins + 1
    else
        b.bot_wins = b.bot_wins + 1
    end

    local win_rate = b.human_wins / math.max(1, b.match_count_total)

    -- Si el jugador pierde más del 65% de las partidas: compensar defensa y ventana de ritmo
    if win_rate < 0.35 and b.match_count_total >= 3 then
        b.beat_window_ms = math.min(0.055, b.beat_window_ms + 0.002)
        b.bastion_intake_mult = math.max(0.35, b.bastion_intake_mult - 0.02)
        b.parry_counter_ratio = math.min(0.70, b.parry_counter_ratio + 0.02)
        MetaBalancer.patch_notes = "ARCHON AUTO-PATCH: DEFENSIVE GRACE BUFFED"
        MetaBalancer.active_adjustment_flag = true

    -- Si el jugador gana más del 75% de las partidas: elevar exigencia y agresividad
    elseif win_rate > 0.75 and b.match_count_total >= 3 then
        b.beat_window_ms = math.max(0.025, b.beat_window_ms - 0.001)
        b.bastion_intake_mult = math.min(0.65, b.bastion_intake_mult + 0.02)
        b.parry_counter_ratio = math.max(0.40, b.parry_counter_ratio - 0.02)
        MetaBalancer.patch_notes = "ARCHON AUTO-PATCH: APEX AGGRESSION TUNED"
        MetaBalancer.active_adjustment_flag = true
    else
        MetaBalancer.active_adjustment_flag = false
    end

    MetaBalancer.save()
end

function MetaBalancer.get(key)
    return MetaBalancer.balance[key]
end

return MetaBalancer
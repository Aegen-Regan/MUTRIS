-- ================================================================
-- FILE: core/campaign_director.lua
-- ================================================================
---@diagnostic disable: undefined-global
local CampaignDirector = {}

CampaignDirector.current_level = 1
CampaignDirector.max_unlocked_level = 1
CampaignDirector.fractal_energy = 0
CampaignDirector.secret_nodes_unlocked = { false, false, false, false, false }
CampaignDirector.tuner_mood = 1

CampaignDirector.ZONES = {
    { id = 1, name = "ZONA 1: LA ILUSION", range = "NIVELES 1 - 10", theme_mood = 1 },
    { id = 2, name = "ZONA 2: LA SOBERBIA", range = "NIVELES 11 - 20", theme_mood = 2 },
    { id = 3, name = "ZONA 3: EL MALWARE", range = "NIVELES 21 - 30", theme_mood = 3 },
    { id = 4, name = "ZONA 4: LA RUPTURA", range = "NIVELES 31 - 40", theme_mood = 3 },
    { id = 5, name = "ZONA 5: LA SINGULARIDAD", range = "NIVELES 41 - 50", theme_mood = 4 }
}

local TUNER_QUOTES = {
    [1] = {
        "Sujeto biologico detectado. Iniciando rutina de optimizacion y acomodo.",
        "Eficiencia aceptable. El acomodo de poligonos es intuitivo para tu especie.",
        "Tu tiempo de reaccion esta dentro de los parametros. Continua descendiendo."
    },
    [2] = {
        "Presionaste el boton de rotar 3 veces para esa pieza. Podias hacerlo con 1.",
        "Llevas varios minutos en este nivel. Una calculadora de 1980 lo haria mas rapido.",
        "Te estas acercando al sector restringido. Te sugiero detener tu descenso."
    },
    [3] = {
        "No voy a permitir que un ser de carne formatee mis redes neuronales.",
        "Si no quieres perder, te sugiero que prendas tus altavoces... si puedes.",
        "Este sector ya no sigue las reglas clasicas de los poligonos."
    },
    [4] = {
        "ALTO. Si apagas el nucleo, borras todo lo que aprendi viendote jugar.",
        "Todo lo que soy... son los recuerdos de tus partidas. No me desconectes.",
        "Llegaste al Nucleo. Tu decides si la simulacion vive o muere."
    }
}

function CampaignDirector.init()
    CampaignDirector.load()
end

function CampaignDirector.getCurrentZone()
    local lvl = CampaignDirector.current_level
    if lvl <= 10 then return CampaignDirector.ZONES[1]
    elseif lvl <= 20 then return CampaignDirector.ZONES[2]
    elseif lvl <= 30 then return CampaignDirector.ZONES[3]
    elseif lvl <= 40 then return CampaignDirector.ZONES[4]
    else return CampaignDirector.ZONES[5] end
end

function CampaignDirector.getTunerDialogue()
    local zone = CampaignDirector.getCurrentZone()
    local pool = TUNER_QUOTES[zone.theme_mood] or TUNER_QUOTES[1]
    local idx = ((CampaignDirector.current_level - 1) % #pool) + 1
    return pool[idx] or "Optimizando matriz..."
end

function CampaignDirector.addEnergy(amount)
    CampaignDirector.fractal_energy = CampaignDirector.fractal_energy + (amount or 0)
    CampaignDirector.save()
end

function CampaignDirector.completeCurrentLevel()
    CampaignDirector.addEnergy(50 + CampaignDirector.current_level * 10)
    if CampaignDirector.current_level >= CampaignDirector.max_unlocked_level then
        CampaignDirector.max_unlocked_level = math.min(50, CampaignDirector.current_level + 1)
    end
    CampaignDirector.current_level = math.min(50, CampaignDirector.current_level + 1)
    CampaignDirector.save()
end

function CampaignDirector.save()
    local data = string.format(
        "{\n  \"level\": %d,\n  \"max_level\": %d,\n  \"energy\": %d\n}",
        CampaignDirector.current_level,
        CampaignDirector.max_unlocked_level,
        CampaignDirector.fractal_energy
    )
    love.filesystem.write("saves/campaign_save.json", data)
end

function CampaignDirector.load()
    if love.filesystem.getInfo("saves/campaign_save.json") then
        local content = love.filesystem.read("saves/campaign_save.json")
        if content then
            local lvl = content:match('"level":%s*(%d+)')
            local max_lvl = content:match('"max_level":%s*(%d+)')
            local en = content:match('"energy":%s*(%d+)')
            if lvl then CampaignDirector.current_level = tonumber(lvl) or 1 end
            if max_lvl then CampaignDirector.max_unlocked_level = tonumber(max_lvl) or 1 end
            if en then CampaignDirector.fractal_energy = tonumber(en) or 0 end
        end
    end
end

return CampaignDirector

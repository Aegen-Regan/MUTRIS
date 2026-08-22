-- ================================================================
-- FILE: combat/hunting_forge.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: THE HUNTER'S FORGE & CYBER-PALICO DRONE (FASE 20)
-- Arquitectura: Zero-GC / Persistent Inventory / Jewel Sockets & Support Drone
-- ============================================================================
local HuntingForge = {}

local FontCache       = require "tetris.font_cache"
local AudioManager    = require "audio_manager"
local BloomShader     = require "tetris.bloom_shader"
local ThemeManager    = require "tetris.theme_manager"
local Blackbox        = require "core.blackbox"

-- Inventario de materiales
HuntingForge.materials = {
    chrono_horn    = 0,
    leviathan_core = 0,
    severed_tail   = 0
}

-- Catálogo de Joyas Pasivas
HuntingForge.JEWELS = {
    {
        id = "reflex_jewel",
        name = "01 // REFLEX JEWEL",
        desc = "+1 FRAME KINETIC PARRY WINDOW (TOTAL: 4 FRAMES)",
        cost = { chrono_horn = 2, leviathan_core = 0, severed_tail = 0 }
    },
    {
        id = "groove_jewel",
        name = "02 // GROOVE JEWEL",
        desc = "+1 BONUS ATTACK LINE ON BEAT-LOCK GROOVE STRIKES",
        cost = { chrono_horn = 2, leviathan_core = 1, severed_tail = 0 }
    },
    {
        id = "breaker_jewel",
        name = "03 // BREAKER JEWEL",
        desc = "+35% DIRECT DAMAGE TO BOSS COLUMNS & PART BREAKING",
        cost = { chrono_horn = 0, leviathan_core = 2, severed_tail = 1 }
    },
    {
        id = "ironclad_jewel",
        name = "04 // IRONCLAD JEWEL",
        desc = "-25% INCOMING GARBAGE INTAKE DEFENSIVE MITIGATION",
        cost = { chrono_horn = 0, leviathan_core = 0, severed_tail = 2 }
    },
    {
        id = "accelerator_jewel",
        name = "05 // ACCELERATOR JEWEL",
        desc = "-10ms DAS INPUT TIMING FOR ULTRA-FAST HANDLING",
        cost = { chrono_horn = 1, leviathan_core = 0, severed_tail = 1 }
    }
}

-- Joyas fabricadas por el jugador
HuntingForge.crafted = {
    reflex_jewel      = false,
    groove_jewel      = false,
    breaker_jewel     = false,
    ironclad_jewel    = false,
    accelerator_jewel = false
}

-- 3 Sockets de Armadura
HuntingForge.sockets = {
    [1] = "none",
    [2] = "none",
    [3] = "none"
}

-- Estado del Dron Palico
HuntingForge.palico_active = true
HuntingForge.palico_cooldown = 0.0
HuntingForge.palico_rescue_flash = 0.0

-- Navegación en el Taller
HuntingForge.selected_jewel = 1
HuntingForge.selected_socket = 1
HuntingForge.active_column = 1 -- 1: Recetas, 2: Sockets

local function serializeForgeJSON()
    local s = "{\n"
    for k, v in pairs(HuntingForge.materials) do
        s = s .. string.format('  "%s": %d,\n', k, v)
    end
    for k, v in pairs(HuntingForge.crafted) do
        s = s .. string.format('  "%s": %s,\n', k, tostring(v))
    end
    for i = 1, 3 do
        s = s .. string.format('  "socket_%d": "%s",\n', i, HuntingForge.sockets[i])
    end
    s = s .. string.format('  "palico_active": %s\n}', tostring(HuntingForge.palico_active))
    return s
end

local function parseForgeJSON(str)
    for k, v in str:gmatch('"([%w_]+)":%s*(%d+)') do
        if HuntingForge.materials[k] ~= nil then
            HuntingForge.materials[k] = tonumber(v)
        end
    end
    for k, v in str:gmatch('"([%w_]+)":%s*(true)') do
        if HuntingForge.crafted[k] ~= nil then HuntingForge.crafted[k] = true end
    end
    for k, v in str:gmatch('"([%w_]+)":%s*(false)') do
        if HuntingForge.crafted[k] ~= nil then HuntingForge.crafted[k] = false end
    end
    for idx = 1, 3 do
        local key = string.format("socket_%d", idx)
        local val = str:match('"' .. key .. '":%s*"([^"]+)"')
        if val then HuntingForge.sockets[idx] = val end
    end
end

function HuntingForge.init()
    if love.filesystem.getInfo("saves/hunter_forge.json") then
        local contents = love.filesystem.read("saves/hunter_forge.json")
        if contents then
            pcall(parseForgeJSON, contents)
        end
    else
        HuntingForge.save()
    end

    HuntingForge.palico_cooldown = 0.0
    HuntingForge.palico_rescue_flash = 0.0
end

function HuntingForge.save()
    if not love.filesystem.getInfo("saves") then love.filesystem.createDirectory("saves") end
    love.filesystem.write("saves/hunter_forge.json", serializeForgeJSON())
end

-- ============================================================================
-- 💎 CONSULTAS DE PASIVAS EQUIPADAS
-- ============================================================================
function HuntingForge.hasJewel(jewel_id)
    for i = 1, 3 do
        if HuntingForge.sockets[i] == jewel_id then return true end
    end
    return false
end

function HuntingForge.getParryBonusFrames()
    return HuntingForge.hasJewel("reflex_jewel") and 1 or 0
end

function HuntingForge.getGrooveBonusLines()
    return HuntingForge.hasJewel("groove_jewel") and 1 or 0
end

function HuntingForge.getPartDamageMultiplier()
    return HuntingForge.hasJewel("breaker_jewel") and 1.35 or 1.0
end

function HuntingForge.getGarbageIntakeMultiplier()
    return HuntingForge.hasJewel("ironclad_jewel") and 0.75 or 1.0
end

function HuntingForge.getDASOffset()
    return HuntingForge.hasJewel("accelerator_jewel") and -0.010 or 0.0
end

-- ============================================================================
-- 🔨 FABRICACIÓN Y EQUIPAMIENTO
-- ============================================================================
function HuntingForge.craftJewel(jewel_idx)
    local j = HuntingForge.JEWELS[jewel_idx]
    if not j or HuntingForge.crafted[j.id] then return false end

    -- Comprobar materiales
    local mats = HuntingForge.materials
    local cost = j.cost
    if mats.chrono_horn >= cost.chrono_horn and
       mats.leviathan_core >= cost.leviathan_core and
       mats.severed_tail >= cost.severed_tail then

        mats.chrono_horn    = mats.chrono_horn - cost.chrono_horn
        mats.leviathan_core = mats.leviathan_core - cost.leviathan_core
        mats.severed_tail   = mats.severed_tail - cost.severed_tail

        HuntingForge.crafted[j.id] = true
        HuntingForge.save()

        AudioManager.playImmediateSFX("tetris", false)
        AudioManager.playSubBassThud(3)
        BloomShader.triggerShockwave(640, 360)
        Blackbox.log("FORGE", "CRAFTED: " .. j.name, 0, 0)
        return true
    end
    return false
end

function HuntingForge.toggleEquipJewel(jewel_id, socket_idx)
    if not HuntingForge.crafted[jewel_id] then return end

    -- Si ya está equipada en otro socket, desequiparla primero
    for i = 1, 3 do
        if HuntingForge.sockets[i] == jewel_id then
            HuntingForge.sockets[i] = "none"
        end
    end

    if HuntingForge.sockets[socket_idx] == jewel_id then
        HuntingForge.sockets[socket_idx] = "none"
    else
        HuntingForge.sockets[socket_idx] = jewel_id
    end

    HuntingForge.save()
    AudioManager.playImmediateSFX("rotate", false)
end

-- ============================================================================
-- 🤖 DRON CYBER-PALICO (Rescate de Emergencia)
-- ============================================================================
function HuntingForge.updatePalico(dt, player_board)
    if not HuntingForge.palico_active or not player_board or player_board.is_dying then return end

    if HuntingForge.palico_cooldown > 0 then
        HuntingForge.palico_cooldown = math.max(0, HuntingForge.palico_cooldown - dt)
    end

    if HuntingForge.palico_rescue_flash > 0 then
        HuntingForge.palico_rescue_flash = math.max(0, HuntingForge.palico_rescue_flash - dt * 3.0)
    end

    -- Trigger de Rescate si la matriz supera altura 14/20
    local p_height = 0
    if player_board.grid then
        for r = 21, 40 do
            for c = 1, 10 do
                if player_board.grid[r][c] ~= 0 then
                    p_height = math.max(p_height, 41 - r)
                end
            end
        end
    end

    if p_height >= 14 and HuntingForge.palico_cooldown <= 0 then
        local q_len = (player_board.garbage_queue and #player_board.garbage_queue) or 0
        if q_len > 0 then
            -- Cancela 3 líneas de basura entrante
            local canceled = 0
            for i = q_len, 1, -1 do
                local item = player_board.garbage_queue[i]
                local lines = type(item) == "number" and item or (type(item) == "table" and (item.lines or 1) or 1)
                table.remove(player_board.garbage_queue, i)
                canceled = canceled + lines
                if canceled >= 3 then break end
            end

            HuntingForge.palico_cooldown = 45.0
            HuntingForge.palico_rescue_flash = 1.0
            _G.HitStopTimer = 0.20

            AudioManager.playImmediateSFX("zone_enter", false)
            AudioManager.playSubBassThud(3)
            BloomShader.triggerShockwave(player_board.x - 30, player_board.y + 180)

            player_board:setPopup("PALICO RESCUE!", {0.1, 0.95, 1.0}, true, "EMERGENCY BARRIER (-3 LINES)")
            Blackbox.log("PALICO", "EMERGENCY RESCUE DEPLOYED", canceled, 0)
        end
    end
end

function HuntingForge.drawPalico(player_board)
    if not HuntingForge.palico_active or not player_board or player_board.is_dying then return end

    local time = love.timer.getTime()
    local pulse = _G.AudioBeatPulse or 0
    local t = ThemeManager.getCurrent()

    -- Posición flotante orbital a la izquierda de la matriz
    local px = player_board.x - 42
    local py = player_board.y + 180 + math.sin(time * 3.5) * 10

    love.graphics.push("all")
    love.graphics.setBlendMode("add")

    -- Propulsor y destello
    love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.4 + pulse * 0.4)
    love.graphics.circle("fill", px, py + 8, 5 + pulse * 3)

    -- Cuerpo mecánico del Dron
    love.graphics.setColor(0.04, 0.08, 0.15, 0.95)
    love.graphics.circle("fill", px, py, 10)
    love.graphics.setColor(t.secondary[1], t.secondary[2], t.secondary[3], 0.95)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", px, py, 10)

    -- Ojo / Sensor Central
    local ready = (HuntingForge.palico_cooldown <= 0)
    love.graphics.setColor(ready and {0.1, 1.0, 0.5, 0.95} or {1.0, 0.3, 0.3, 0.7})
    love.graphics.circle("fill", px, py, 4)

    if HuntingForge.palico_rescue_flash > 0 then
        love.graphics.setColor(0.1, 0.95, 1.0, HuntingForge.palico_rescue_flash * 0.8)
        love.graphics.circle("line", px, py, (1.0 - HuntingForge.palico_rescue_flash) * 80)
    end

    love.graphics.setBlendMode("alpha")
    love.graphics.pop()
end

-- ============================================================================
-- 🎨 PANTALLA INTERACTIVA DEL TALLER DE FORJA (1280x720 WIDESCREEN)
-- ============================================================================
function HuntingForge.drawScreen()
    love.graphics.push("all")
    ThemeManager.drawBackground()

    local t = ThemeManager.getCurrent()
    local pulse = _G.AudioBeatPulse or 0

    -- Encabezado Widescreen
    love.graphics.setFont(FontCache.get(26))
    love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.98)
    love.graphics.printf("THE HUNTER'S FORGE", 0, 36, 1280, "center")

    love.graphics.setFont(FontCache.get(10))
    love.graphics.setColor(1, 1, 1, 0.70)
    love.graphics.printf("ARMOR JEWEL CRAFTING & CYBER-PALICO COMPANION BAY", 0, 68, 1280, "center")

    -- ────────────────────────────────────────────────────────────────────────
    -- ALA 1: ALMACÉN DE MATERIALES & DRON PALICO (x: 80..380)
    -- ────────────────────────────────────────────────────────────────────────
    local m_x, m_y, m_w, m_h = 80, 110, 300, 480
    ThemeManager.drawPanel(m_x, m_y, m_w, m_h, "MATERIAL STORAGE", false)

    love.graphics.setFont(FontCache.get(11))
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print("CARVED TITAN LOOT:", m_x + 20, m_y + 35)

    -- Materiales
    local mat_items = {
        { name = "CHRONO-HORN",    count = HuntingForge.materials.chrono_horn,    clr = {1.0, 0.2, 0.3} },
        { name = "LEVIATHAN-CORE",  count = HuntingForge.materials.leviathan_core,  clr = {0.1, 0.9, 1.0} },
        { name = "SEVERED-TAIL",    count = HuntingForge.materials.severed_tail,    clr = {1.0, 0.85, 0.0} }
    }

    for i, mat in ipairs(mat_items) do
        local my = m_y + 70 + (i - 1) * 45
        love.graphics.setColor(0.02, 0.04, 0.08, 0.9)
        love.graphics.rectangle("fill", m_x + 16, my, m_w - 32, 34, 3)
        love.graphics.setColor(mat.clr[1], mat.clr[2], mat.clr[3], 0.6)
        love.graphics.rectangle("line", m_x + 16, my, m_w - 32, 34, 3)

        love.graphics.setFont(FontCache.get(10))
        love.graphics.setColor(mat.clr[1], mat.clr[2], mat.clr[3], 0.95)
        love.graphics.print(mat.name, m_x + 26, my + 10)

        love.graphics.setFont(FontCache.get(12))
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(string.format("x%d", mat.count), m_x + 16, my + 8, m_w - 48, "right")
    end

    -- Dron Palico Status
    local d_y = m_y + 240
    ThemeManager.drawPanel(m_x + 16, d_y, m_w - 32, 210, "CYBER-PALICO DRONE", false)

    love.graphics.setFont(FontCache.get(10))
    love.graphics.setColor(0.1, 0.95, 1.0, 0.95)
    love.graphics.print("PROTOCOL: EMERGENCY BARRIER", m_x + 30, d_y + 35)

    love.graphics.setFont(FontCache.get(8))
    love.graphics.setColor(0.7, 0.8, 0.9, 0.85)
    love.graphics.printf("• AUTOMATICALLY CANCELS 3 GARBAGE LINES WHEN MATRIX REACHES DANGER HEIGHT (14/20)\n• 45s RECHARGE COOLDOWN", m_x + 30, d_y + 65, m_w - 60, "left")

    love.graphics.setColor(0, 0.8, 0.4, 0.85)
    love.graphics.rectangle("fill", m_x + 30, d_y + 150, m_w - 60, 28, 3)
    love.graphics.setFont(FontCache.get(9))
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.printf("SYSTEM ACTIVE // READY", m_x + 30, d_y + 158, m_w - 60, "center")

    -- ────────────────────────────────────────────────────────────────────────
    -- ALA 2: CATÁLOGO DE JOYAS Y CRAFTEO (x: 410..880)
    -- ────────────────────────────────────────────────────────────────────────
    local c_x, c_y, c_w, c_h = 410, 110, 470, 480
    ThemeManager.drawPanel(c_x, c_y, c_w, c_h, "JEWEL CRAFTING STATION", false)

    for i, j in ipairs(HuntingForge.JEWELS) do
        local jy = c_y + 30 + (i - 1) * 86
        local is_sel = (i == HuntingForge.selected_jewel and HuntingForge.active_column == 1)
        local is_crafted = HuntingForge.crafted[j.id]

        ThemeManager.drawPanel(c_x + 16, jy, c_w - 32, 76, "", is_sel)

        -- Título de la Joya
        love.graphics.setFont(FontCache.get(11))
        love.graphics.setColor(is_crafted and {0.1, 1.0, 0.55} or {1.0, 0.85, 0.0})
        love.graphics.print(j.name .. (is_crafted and " [CRAFTED]" or ""), c_x + 28, jy + 8)

        -- Descripción
        love.graphics.setFont(FontCache.get(8))
        love.graphics.setColor(0.8, 0.85, 0.95, 0.85)
        love.graphics.print(j.desc, c_x + 28, jy + 28)

        -- Coste en Materiales
        local cost_str = string.format("COST: %d Horns | %d Cores | %d Tails", j.cost.chrono_horn, j.cost.leviathan_core, j.cost.severed_tail)
        love.graphics.setColor(0.5, 0.65, 0.8, 0.75)
        love.graphics.print(cost_str, c_x + 28, jy + 48)

        -- Botón Craftear / Equipar
        local btn_w = 90
        local btn_x = c_x + c_w - 32 - btn_w - 12
        local btn_y = jy + 22
        love.graphics.setColor(is_crafted and {0.05, 0.25, 0.15, 0.9} or {0.25, 0.15, 0.05, 0.9})
        love.graphics.rectangle("fill", btn_x, btn_y, btn_w, 28, 3)
        love.graphics.setColor(is_crafted and {0.1, 1.0, 0.5, 0.5} or {1.0, 0.85, 0.0, 0.5})
        love.graphics.rectangle("line", btn_x, btn_y, btn_w, 28, 3)

        love.graphics.setFont(FontCache.get(8))
        love.graphics.setColor(1, 1, 1, 0.95)
        love.graphics.printf(is_crafted and "EQUIP [1-3]" or "CRAFT [ENTER]", btn_x, btn_y + 8, btn_w, "center")
    end

    -- ────────────────────────────────────────────────────────────────────────
    -- ALA 3: SOCKETS DE ARMADURA EQUIPADOS (x: 910..1200)
    -- ────────────────────────────────────────────────────────────────────────
    local s_x, s_y, s_w, s_h = 910, 110, 290, 480
    ThemeManager.drawPanel(s_x, s_y, s_w, s_h, "ACTIVE LOADOUT (3 SLOTS)", false)

    for slot = 1, 3 do
        local sy = s_y + 40 + (slot - 1) * 115
        local is_sel_sock = (slot == HuntingForge.selected_socket and HuntingForge.active_column == 2)
        local eq_id = HuntingForge.sockets[slot]

        ThemeManager.drawPanel(s_x + 16, sy, s_w - 32, 95, string.format("SOCKET 0%d", slot), is_sel_sock)

        if eq_id ~= "none" then
            local j_info = nil
            for _, j in ipairs(HuntingForge.JEWELS) do
                if j.id == eq_id then j_info = j break end
            end
            if j_info then
                love.graphics.setFont(FontCache.get(9))
                love.graphics.setColor(0.1, 1.0, 0.55, 0.95)
                love.graphics.print(j_info.name, s_x + 28, sy + 30)

                love.graphics.setFont(FontCache.get(7))
                love.graphics.setColor(1, 1, 1, 0.75)
                love.graphics.printf(j_info.desc, s_x + 28, sy + 50, s_w - 56, "left")
            end
        else
            love.graphics.setFont(FontCache.get(10))
            love.graphics.setColor(0.4, 0.5, 0.6, 0.6)
            love.graphics.printf("[ EMPTY SOCKET ]", s_x + 16, sy + 45, s_w - 32, "center")
        end
    end

    -- Controles y Leyenda
    love.graphics.setFont(FontCache.get(9))
    love.graphics.setColor(1, 1, 1, 0.50)
    love.graphics.printf("[ UP / DOWN ] SELECCIONAR   |   [ ENTER ] FORJAR JOYA   |   [ 1 / 2 / 3 ] ASIGNAR A SOCKET   |   [ ESC ] SALIR", 0, 625, 1280, "center")

    love.graphics.pop()
end

-- ============================================================================
-- ⌨️ ENTRADAS DE TECLADO Y RATÓN EN EL TALLER
-- ============================================================================
function HuntingForge.keypressed(key)
    if key == "escape" then
        _G.SetGameState("menu")
        return
    end

    if key == "up" then
        HuntingForge.selected_jewel = (HuntingForge.selected_jewel == 1) and #HuntingForge.JEWELS or (HuntingForge.selected_jewel - 1)
        AudioManager.playImmediateSFX("move", false)
    elseif key == "down" then
        HuntingForge.selected_jewel = (HuntingForge.selected_jewel % #HuntingForge.JEWELS) + 1
        AudioManager.playImmediateSFX("move", false)
    elseif key == "return" or key == "space" then
        local j = HuntingForge.JEWELS[HuntingForge.selected_jewel]
        if j then
            if not HuntingForge.crafted[j.id] then
                HuntingForge.craftJewel(HuntingForge.selected_jewel)
            else
                -- Si ya está crafteada, auto-equipar en el primer socket libre
                local equipped = false
                for s = 1, 3 do
                    if HuntingForge.sockets[s] == "none" then
                        HuntingForge.toggleEquipJewel(j.id, s)
                        equipped = true
                        break
                    end
                end
                if not equipped then
                    HuntingForge.toggleEquipJewel(j.id, 1)
                end
            end
        end
    elseif key == "1" or key == "2" or key == "3" then
        local slot_idx = tonumber(key)
        local j = HuntingForge.JEWELS[HuntingForge.selected_jewel]
        if j and HuntingForge.crafted[j.id] then
            HuntingForge.toggleEquipJewel(j.id, slot_idx)
        end
    end
end

function HuntingForge.mousepressed(mx, my, button)
    if button ~= 1 then return end

    -- Clic en botón Craftear/Equipar
    local c_x, c_y, c_w = 410, 110, 470
    for i, j in ipairs(HuntingForge.JEWELS) do
        local jy = c_y + 30 + (i - 1) * 86
        local btn_w = 90
        local btn_x = c_x + c_w - 32 - btn_w - 12
        local btn_y = jy + 22

        if mx >= btn_x and mx <= btn_x + btn_w and my >= btn_y and my <= btn_y + 28 then
            HuntingForge.selected_jewel = i
            if not HuntingForge.crafted[j.id] then
                HuntingForge.craftJewel(i)
            else
                HuntingForge.toggleEquipJewel(j.id, 1)
            end
            return
        end
    end

    -- Clic en Sockets para desequipar
    local s_x, s_y, s_w = 910, 110, 290
    for slot = 1, 3 do
        local sy = s_y + 40 + (slot - 1) * 115
        if mx >= s_x + 16 and mx <= s_x + s_w - 16 and my >= sy and my <= sy + 95 then
            HuntingForge.sockets[slot] = "none"
            HuntingForge.save()
            AudioManager.playImmediateSFX("rotate", false)
            return
        end
    end
end

return HuntingForge
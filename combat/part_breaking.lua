-- ================================================================
-- FILE: combat/part_breaking.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: COLUMN-BASED PART BREAKING & HUNTER'S FORGE (FASE 18 & 20)
-- Columnas 1-3: Cuernos (600 HP) | Cols 4-7: Núcleo (1400 HP) | Cols 8-10: Cola (800 HP)
-- ============================================================================
local PartBreaking = {}

local FontCache    = require "tetris.font_cache"
local AudioManager = require "audio_manager"
local BloomShader  = require "tetris.bloom_shader"
local ThemeManager = require "tetris.theme_manager"
local Blackbox     = require "core.blackbox"

PartBreaking.parts = {
    horns = { name = "HORNS (COLS 1-3)", max_hp = 600,  hp = 600,  broken = false, cols = {1, 2, 3}, loot = "CHRONO-HORN" },
    core  = { name = "CORE (COLS 4-7)",  max_hp = 1400, hp = 1400, broken = false, cols = {4, 5, 6, 7}, loot = "LEVIATHAN-CORE" },
    tail  = { name = "TAIL (COLS 8-10)", max_hp = 800,  hp = 800,  broken = false, cols = {8, 9, 10}, loot = "SEVERED-TAIL" }
}

-- Inventario persistente de Caza (The Hunter's Forge)
PartBreaking.inventory = {
    chrono_horn    = 0,
    leviathan_core = 0,
    severed_tail   = 0
}

-- Recompensas obtenidas en la partida actual
PartBreaking.match_carves = {}

-- Pool estático de escombros de ruptura (Zero-GC)
local MAX_DEBRIS = 36
local debris = {}
for i = 1, MAX_DEBRIS do
    debris[i] = { active = false, x = 0, y = 0, vx = 0, vy = 0, life = 0, max_life = 0, r = 1, g = 1, b = 1, size = 4 }
end
local debris_head = 1

local function serializeJSON(t)
    local s = "{\n"
    for k, v in pairs(t) do
        s = s .. string.format('  "%s": %d,\n', k, v)
    end
    s = s:sub(1, -3) .. "\n}"
    return s
end

local function parseJSON(str)
    local t = {}
    for k, v in str:gmatch('"([%w_]+)":%s*(%d+)') do
        t[k] = tonumber(v)
    end
    return t
end

function PartBreaking.loadInventory()
    if love.filesystem.getInfo("saves/hunter_forge.json") then
        local contents = love.filesystem.read("saves/hunter_forge.json")
        if contents then
            local data = parseJSON(contents)
            for k, v in pairs(data) do
                PartBreaking.inventory[k] = v
            end
        end
    end
end

function PartBreaking.saveInventory()
    if not love.filesystem.getInfo("saves") then
        love.filesystem.createDirectory("saves")
    end
    love.filesystem.write("saves/hunter_forge.json", serializeJSON(PartBreaking.inventory))
end

function PartBreaking.init()
    PartBreaking.parts.horns.hp = 600
    PartBreaking.parts.horns.broken = false
    PartBreaking.parts.core.hp = 1400
    PartBreaking.parts.core.broken = false
    PartBreaking.parts.tail.hp = 800
    PartBreaking.parts.tail.broken = false

    PartBreaking.match_carves = {}
    PartBreaking.loadInventory()
end

function PartBreaking.spawnDebris(x, y, count, clr)
    for i = 1, count do
        local d = debris[debris_head]
        d.active = true
        d.x, d.y = x + math.random(-20, 20), y
        d.vx = math.random(-120, 120)
        d.vy = math.random(-160, -40)
        d.life = 0.8
        d.max_life = 0.8
        d.r, d.g, d.b = clr[1], clr[2], clr[3]
        d.size = math.random(3, 6)

        debris_head = (debris_head % MAX_DEBRIS) + 1
    end
end

function PartBreaking.update(dt)
    for i = 1, MAX_DEBRIS do
        local d = debris[i]
        if d.active then
            d.x = d.x + d.vx * dt
            d.y = d.y + d.vy * dt
            d.vy = d.vy + 360 * dt
            d.life = d.life - dt
            if d.life <= 0 then d.active = false end
        end
    end
end

function PartBreaking.registerLineClear(player_board, cleared_count, is_tspin)
    if _G.CURRENT_GAME_MODE ~= "boss_hunt" then return end
    if not player_board or cleared_count <= 0 then return end

    local PoiseSystem = require "combat.poise_system"

    -- Escalado de daño rebalanceado para Boss de 2800 HP
    local base_damage = (cleared_count == 1 and 50)
                     or (cleared_count == 2 and 120)
                     or (cleared_count == 3 and 220)
                     or (cleared_count == 4 and 380)
                     or 60

    if is_tspin then base_damage = base_damage * 1.6 end
    if PartBreaking.parts.core.broken then base_damage = base_damage * 1.5 end -- Bonus Core

    local final_dmg = PoiseSystem.dealDamage(base_damage, is_tspin)
    local part_dmg = math.floor(final_dmg * 0.40)

    for part_id, part in pairs(PartBreaking.parts) do
        if not part.broken then
            part.hp = math.max(0, part.hp - part_dmg)
            if part.hp <= 0 then
                part.broken = true
                PartBreaking.triggerPartBreak(player_board, part_id, part.name, part.loot)
            end
        end
    end
end

function PartBreaking.triggerPartBreak(player_board, part_id, part_name, loot_name)
    _G.HitStopTimer = 0.25
    AudioManager.playImmediateSFX("ultimatris", false)
    AudioManager.playSubBassThud(4)
    BloomShader.triggerShockwave(820 + 120, 120 + 240)

    -- Spawn de escombros sobre la columna rota
    local col_center_x = 820 + (part_id == "horns" and 36 or (part_id == "core" and 120 or 204))
    local clr = (part_id == "horns" and {1.0, 0.2, 0.3}) or (part_id == "core" and {0.1, 0.9, 1.0}) or {1.0, 0.85, 0.0}
    PartBreaking.spawnDebris(col_center_x, 120, 18, clr)

    -- Guardar material en el botín
    if part_id == "horns" then
        PartBreaking.inventory.chrono_horn = (PartBreaking.inventory.chrono_horn or 0) + 1
    elseif part_id == "core" then
        PartBreaking.inventory.leviathan_core = (PartBreaking.inventory.leviathan_core or 0) + 1
    elseif part_id == "tail" then
        PartBreaking.inventory.severed_tail = (PartBreaking.inventory.severed_tail or 0) + 1
    end
    PartBreaking.saveInventory()
    table.insert(PartBreaking.match_carves, loot_name)

    local alert_text = (part_id == "horns" and "HORN BROKEN! +1 CHRONO-HORN")
                    or (part_id == "core"  and "CORE EXPOSED! +1 LEVIATHAN-CORE")
                    or "TAIL SEVERED! +1 SEVERED-TAIL"

    player_board:setPopup("PART BROKEN!", {1.0, 0.85, 0.0}, true, alert_text)
    Blackbox.log("PART_BREAK", part_name .. " CARVED", 0, 0)
end

-- ============================================================================
-- 🎯 CORCHETES ANATÓMICOS PROCEDURALES Y ESCOMBROS DE RUPTURA
-- ============================================================================
function PartBreaking.drawIndicators(boss_board)
    if _G.CURRENT_GAME_MODE ~= "boss_hunt" or not boss_board then return end

    local bx, by = boss_board.x, boss_board.y
    love.graphics.push("all")

    -- 1. Cuernos (Cols 1-3)
    local h_broken = PartBreaking.parts.horns.broken
    local h_pct = PartBreaking.parts.horns.hp / PartBreaking.parts.horns.max_hp
    love.graphics.setColor(h_broken and {0.4, 0.4, 0.4, 0.3} or {1.0, 0.2, 0.3, 0.8})
    love.graphics.setLineWidth(1.5)
    love.graphics.line(bx, by - 4, bx + 70, by - 4)
    love.graphics.line(bx, by - 4, bx, by)
    love.graphics.line(bx + 70, by - 4, bx + 70, by)
    love.graphics.setFont(FontCache.get(7))
    love.graphics.print(h_broken and "[BROKEN]" or string.format("HORNS %d%%", math.floor(h_pct * 100)), bx + 8, by - 14)

    -- 2. Núcleo (Cols 4-7)
    local c_broken = PartBreaking.parts.core.broken
    local c_pct = PartBreaking.parts.core.hp / PartBreaking.parts.core.max_hp
    love.graphics.setColor(c_broken and {0.4, 0.4, 0.4, 0.3} or {0.1, 0.9, 1.0, 0.8})
    love.graphics.line(bx + 74, by - 4, bx + 166, by - 4)
    love.graphics.line(bx + 74, by - 4, bx + 74, by)
    love.graphics.line(bx + 166, by - 4, bx + 166, by)
    love.graphics.print(c_broken and "[EXPOSED]" or string.format("CORE %d%%", math.floor(c_pct * 100)), bx + 95, by - 14)

    -- 3. Cola (Cols 8-10)
    local t_broken = PartBreaking.parts.tail.broken
    local t_pct = PartBreaking.parts.tail.hp / PartBreaking.parts.tail.max_hp
    love.graphics.setColor(t_broken and {0.4, 0.4, 0.4, 0.3} or {1.0, 0.85, 0.0, 0.8})
    love.graphics.line(bx + 170, by - 4, bx + 240, by - 4)
    love.graphics.line(bx + 170, by - 4, bx + 170, by)
    love.graphics.line(bx + 240, by - 4, bx + 240, by)
    love.graphics.print(t_broken and "[SEVERED]" or string.format("TAIL %d%%", math.floor(t_pct * 100)), bx + 180, by - 14)

    -- Renderizado de escombros de ruptura
    love.graphics.setBlendMode("add")
    for i = 1, MAX_DEBRIS do
        local d = debris[i]
        if d.active then
            local a = d.life / d.max_life
            love.graphics.setColor(d.r, d.g, d.b, a * 0.9)
            love.graphics.rectangle("fill", d.x - d.size/2, d.y - d.size/2, d.size, d.size, 1)
        end
    end
    love.graphics.setBlendMode("alpha")

    love.graphics.pop()
end

return PartBreaking
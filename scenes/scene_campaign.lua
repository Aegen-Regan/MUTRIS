-- ================================================================
-- FILE: scenes/scene_campaign.lua
-- ================================================================
---@diagnostic disable: undefined-global
local SceneCampaign = {}

local CampaignDirector = require("core.campaign_director")
local ThemeManager     = require("tetris.theme_manager")
local FontCache        = require("tetris.font_cache")
local SceneManager     = require("core.scene_manager")
local AudioManager     = require("audio_manager")

local selected_node = 1
local map_scroll_x = 0

function SceneCampaign.init()
    CampaignDirector.init()
    selected_node = CampaignDirector.current_level
end

function SceneCampaign.enter()
    SceneCampaign.init()
    _G.CURRENT_GAME_MODE = "campaign"
end

function SceneCampaign.onEnter()
    SceneCampaign.enter()
end

function SceneCampaign.update(dt)
    ThemeManager.update(dt)
    local target_scroll = -(selected_node - 3) * 110
    map_scroll_x = map_scroll_x + (target_scroll - map_scroll_x) * 10 * dt
end

function SceneCampaign.draw()
    local theme = ThemeManager.getCurrent()
    local time = love.timer.getTime()

    ThemeManager.drawBackground()

    -- 1. Encabezado de Zona & Moneda Fractal
    local zone = CampaignDirector.getCurrentZone()
    love.graphics.setFont(FontCache.get(20))
    love.graphics.setColor(theme.primary[1], theme.primary[2], theme.primary[3], 0.98)
    love.graphics.printf("CAMPAÑA: EL DESCENSO AL MAINFRAME", 0, 24, 1280, "center")

    love.graphics.setFont(FontCache.get(10))
    love.graphics.setColor(0.1, 0.95, 0.6, 0.95)
    love.graphics.printf(string.format("%s  |  %s", zone.name, zone.range), 0, 52, 1280, "center")

    -- Badge de Energía Fractal
    love.graphics.setFont(FontCache.get(11))
    love.graphics.setColor(1.0, 0.85, 0.2, 0.95)
    love.graphics.print(string.format("ENERGIA FRACTAL: %d EF", CampaignDirector.fractal_energy), 980, 28)

    -- 2. T.U.N.E.R. Neural Avatar & Caja de Diálogo
    local bx, by, bw, bh = 180, 85, 920, 95
    ThemeManager.drawPanel(bx, by, bw, bh, "T.U.N.E.R. // ENTIDAD IA NEURAL", false)

    local eye_pulse = math.sin(time * 6.0) * 4
    love.graphics.setBlendMode("add")
    love.graphics.setColor(1.0, 0.25, 0.45, 0.8)
    love.graphics.circle("fill", bx + 45, by + 50, 16 + eye_pulse)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.circle("fill", bx + 45, by + 50, 6)
    love.graphics.setBlendMode("alpha")

    love.graphics.setFont(FontCache.get(11))
    love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
    love.graphics.printf(string.format("\"%s\"", CampaignDirector.getTunerDialogue()), bx + 80, by + 36, bw - 100, "left")

    -- 3. Mapa Topológico de Nodos
    love.graphics.push()
    love.graphics.translate(map_scroll_x, 0)

    local start_node_x = 240
    local node_y = 360

    for i = 1, 50 do
        local nx = start_node_x + (i - 1) * 110
        local is_unlocked = (i <= CampaignDirector.max_unlocked_level)
        local is_curr = (i == selected_node)
        local is_boss = (i % 10 == 0)

        if i < 50 then
            love.graphics.setColor(is_unlocked and {0.1, 0.85, 1.0, 0.4} or {0.2, 0.25, 0.35, 0.3})
            love.graphics.setLineWidth(2)
            love.graphics.line(nx, node_y, nx + 110, node_y)
        end

        local node_rad = is_boss and 24 or 18
        if is_curr then
            local pulse = math.sin(time * 8.0) * 4
            love.graphics.setColor(1.0, 0.85, 0.2, 0.95)
            love.graphics.circle("line", nx, node_y, node_rad + 6 + pulse)
        end

        if is_boss then
            love.graphics.setColor(is_unlocked and {1.0, 0.2, 0.35, 0.95} or {0.3, 0.1, 0.15, 0.8})
        else
            love.graphics.setColor(is_unlocked and {0.1, 0.9, 1.0, 0.95} or {0.15, 0.2, 0.25, 0.8})
        end
        love.graphics.circle("fill", nx, node_y, node_rad)
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.circle("line", nx, node_y, node_rad)

        love.graphics.setFont(FontCache.get(9))
        love.graphics.setColor(1, 1, 1, is_unlocked and 1.0 or 0.5)
        love.graphics.printf(tostring(i), nx - 15, node_y - 5, 30, "center")
    end

    love.graphics.pop()

    -- 4. Tarjeta del Nivel Seleccionado
    local lx, ly, lw, lh = 340, 480, 600, 150
    ThemeManager.drawPanel(lx, ly, lw, lh, "", false)

    local is_boss_level = (selected_node % 10 == 0)
    love.graphics.setFont(FontCache.get(14))
    love.graphics.setColor(is_boss_level and {1.0, 0.2, 0.35, 0.98} or {0.1, 0.95, 1.0, 0.98})
    love.graphics.printf(string.format("NIVEL %02d: %s", selected_node, is_boss_level and "JEFE DEL SECTOR // ANOMALIA" or "DESAFIO DE OPTIMIZACION"), lx + 20, ly + 20, lw - 40, "center")

    love.graphics.setFont(FontCache.get(9))
    love.graphics.setColor(0.75, 0.85, 0.95, 0.85)
    love.graphics.printf(is_boss_level and "Enfrenta al Guardian del Sector. Sobrevive a sus ataques de interferencia." or "Completa la matriz manteniendo un ritmo fluido para avanzar.", lx + 40, ly + 52, lw - 80, "center")

    -- Botón Iniciar
    love.graphics.setColor(0.04, 0.40, 0.25, 0.9)
    love.graphics.rectangle("fill", lx + 180, ly + 90, 240, 36, 4)
    love.graphics.setColor(0.1, 1.0, 0.5, 0.8)
    love.graphics.rectangle("line", lx + 180, ly + 90, 240, 36, 4)
    love.graphics.setFont(FontCache.get(11))
    love.graphics.setColor(1, 1, 1, 0.98)
    love.graphics.printf("ENGAGE LEVEL [SPACE / ENTER]", lx + 180, ly + 100, 240, "center")

    -- 5. Footer
    love.graphics.setFont(FontCache.get(8))
    love.graphics.setColor(0.4, 0.5, 0.6, 0.8)
    love.graphics.printf("[ IZQ / DER ] SELECCIONAR NODO | [ ENTER ] INICIAR | [ ESC ] REGRESAR AL MENU", 0, 670, 1280, "center")
end

function SceneCampaign.keypressed(key)
    if key == "left" then
        selected_node = math.max(1, selected_node - 1)
        AudioManager.playImmediateSFX("move", false)
        return true
    elseif key == "right" then
        selected_node = math.min(CampaignDirector.max_unlocked_level, selected_node + 1)
        AudioManager.playImmediateSFX("move", false)
        return true
    elseif key == "return" or key == "space" then
        CampaignDirector.current_level = selected_node
        if selected_node % 10 == 0 then
            SceneManager.setState("boss_hunt")
        else
            SceneManager.setState("versus")
        end
        return true
    elseif key == "escape" then
        SceneManager.setState("menu")
        return true
    end
    return false
end

return SceneCampaign

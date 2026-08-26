-- ============================================================================
-- FILE: scenes/scene_menu.lua
-- MUTRIS ENGINE: CYBERPUNK MISSION SELECT & MODE MATRIX (1280x720 / Zero-GC)
-- TARGET: Intel Pentium G3250 Haswell / Intel HD Graphics (Zero Allocation Draw)
-- ============================================================================
---@diagnostic disable: undefined-global

local ok_sm, SceneManager = pcall(require, "core.scene_manager")
if not ok_sm or not SceneManager then
    local ok_sm2, SM2 = pcall(require, "scene_manager")
    SceneManager = ok_sm2 and SM2 or _G.SceneManager
end

local SoundManager = nil
pcall(function() SoundManager = require("audio.sound_manager") end)

local SoundtrackDB = nil
pcall(function() SoundtrackDB = require("audio.soundtrack_db") end)

local ThemeManager = nil
pcall(function() ThemeManager = require("tetris.theme_manager") end)

local OscClient = nil
pcall(function() OscClient = require("network.osc_client") end)

-- Vinculación dura y obligatoria al FontCache para evitar fugas silenciosas por fallback inline
local FontCache = require "tetris.font_cache"

local scene = {}

local VW, VH = 1280, 720

local COLOR = {
    bg          = {0.020, 0.031, 0.063, 1.00}, -- #050810
    panel       = {0.055, 0.065, 0.105, 0.95},
    panel_hov   = {0.075, 0.090, 0.140, 0.98},
    panel_feat  = {0.060, 0.095, 0.115, 0.98},
    border_dim  = {0.20, 0.16, 0.34, 0.80},

    cyan        = {0.25, 0.92, 1.00, 1.00},
    cyan_dim    = {0.10, 0.30, 0.36, 1.00},
    magenta     = {1.00, 0.32, 0.82, 1.00},
    magenta_dim = {0.34, 0.11, 0.28, 1.00},
    red         = {1.00, 0.28, 0.32, 1.00},
    red_dim     = {0.32, 0.10, 0.12, 1.00},
    gold        = {1.00, 0.82, 0.22, 1.00},
    gold_dim    = {0.34, 0.27, 0.09, 1.00},
    green       = {0.35, 1.00, 0.58, 1.00},
    green_dim   = {0.10, 0.32, 0.20, 1.00},
    purple      = {0.76, 0.48, 1.00, 1.00},
    purple_dim  = {0.24, 0.15, 0.34, 1.00},
    steel       = {0.55, 0.62, 0.72, 1.00},
    steel_dim   = {0.20, 0.24, 0.32, 1.00},

    text        = {0.88, 0.93, 0.97, 1.00},
    text_dim    = {0.50, 0.56, 0.64, 1.00},
    text_faint  = {0.30, 0.35, 0.42, 1.00},
    black       = {0.00, 0.00, 0.00, 0.60},
}

local CHAMFER = 8

-- STATIC MENU ITEMS DEFINITIONS
local ITEMS = {
    { title = "CAMPAÑA: EL DESCENSO",     sub = "50-STAGE ROGUELIKE MAINFRAME VS T.U.N.E.R. AI",
      badge = "50-STAGE ROGUELIKE", color = COLOR.cyan,    dim = COLOR.cyan_dim,    featured = true,
      mode_id = "campaign", target = "game" },
    { title = "VS BOT DUEL",              sub = "CLASSIC 1v1 DUEL VS ADAPTIVE DDA BOT",
      badge = "1v1 DDA",            color = COLOR.magenta, dim = COLOR.magenta_dim, featured = false,
      mode_id = "versus",   target = "versus" },
    { title = "CYBER-BEAST HUNT",         sub = "3-PHASE COLOSSUS ASSAULT & HUNTER'S FORGE",
      badge = "BOSS RAID",          color = COLOR.red,     dim = COLOR.red_dim,     featured = false,
      mode_id = "boss_hunt",target = "boss_hunt" },
    { title = "THE HUNTER'S FORGE",       sub = "ARMOR JEWEL CRAFTING & CYBER-PALICO COMPANION BAY",
      badge = "CRAFTING",           color = COLOR.gold,    dim = COLOR.gold_dim,    featured = false,
      mode_id = "forge",    target = "forge" },
    { title = "PILOT BENCHMARK",          sub = "OFFICIAL 3-STAGE PILOT CALIBRATION TRIAL",
      badge = "CALIBRATION",        color = COLOR.green,   dim = COLOR.green_dim,   featured = false,
      mode_id = "benchmark",target = "benchmark" },
    { title = "TRAINER LAB & FINESSE",    sub = "HOLOGRAPHIC OPENING BOOK, TIME-TRAVEL & KPF COACH",
      badge = "COACHING",           color = COLOR.purple,  dim = COLOR.purple_dim,  featured = false,
      mode_id = "trainer",  target = "trainer" },
    { title = "SOUNDTRACK & FX LAB",      sub = "DAW TIMELINE, CUE PLACEMENT & SFX AUDITION",
      badge = "DAW TOOLS",          color = COLOR.cyan,    dim = COLOR.cyan_dim,    featured = false,
      mode_id = "soundtrack",target = "soundtrack_lab" },
    { title = "SETTINGS & CALIBRATION",   sub = "MASTER CALIBRATION SUITE, DAS / ARR & PIPELINE",
      badge = "SYSTEM",             color = COLOR.steel,   dim = COLOR.steel_dim,   featured = false,
      mode_id = "settings", target = "settings" },
    { title = "LOGICAL EDITOR",           sub = "CUSTOMIZE MATRICES AND GAME RULES DYNAMICALLY",
      badge = "RULES ENGINE",       color = COLOR.gold,    dim = COLOR.gold_dim,    featured = false,
      mode_id = "editor",   target = "editor" },
}
local ITEM_COUNT = #ITEMS

local SKIN_LIST = { "01 // NEON GRID", "02 // ARCTIC MONO", "03 // BLOOD IRON",
                     "04 // SINESTESIA COSMICA", "05 // AMBER TERMINAL" }

-- STATE
scene.state = {
    selected      = 1,
    hover         = 0,
    skin_index    = 4,
    t             = 0.0,
    rec_flash     = 0.0,
}

scene.led = {
    glow = {0,0,0,0,0,0,0,0,0},
}

-- STRING CACHE (Zero-GC)
scene.cache = {
    skin_str   = "",
    footer_str = "",
}

local function refreshSkinCache()
    if ThemeManager and ThemeManager.getCurrent then
        local cur = ThemeManager.getCurrent()
        scene.cache.skin_str = cur and cur.name or SKIN_LIST[scene.state.skin_index]
    else
        scene.cache.skin_str = SKIN_LIST[scene.state.skin_index]
    end
end

-- LAYOUT
local L = {}
local function buildLayout()
    -- El setup inicial es estático y limpio. El desplazamiento dinámico se computa por hardware en el draw frame.
    L.title_y       = 26
    L.subtitle_y    = 60
    L.list_x        = 420
    L.list_w        = 440
    L.list_top      = 88
    L.item_h_norm   = 40
    L.item_h_feat   = 56
    L.item_gap      = 10
    L.legend_y      = VH - 108
    L.footer_h      = 20
    L.footer_y      = VH - L.footer_h
end

local CHAMFER_BUF = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
local DIAMOND_BUF = {0,0,0,0,0,0,0,0}

local function fillChamferBuf(x, y, w, h, c)
    local p = CHAMFER_BUF
    p[1]=x+c;   p[2]=y
    p[3]=x+w-c; p[4]=y
    p[5]=x+w;   p[6]=y+c
    p[7]=x+w;   p[8]=y+h-c
    p[9]=x+w-c; p[10]=y+h
    p[11]=x+c;  p[12]=y+h
    p[13]=x;    p[14]=y+h-c
    p[15]=x;    p[16]=y+c
    return p
end

local function setColor(c) love.graphics.setColor(c[1], c[2], c[3], c[4]) end

local function drawChamferedPanel(x, y, w, h, fillColor, borderColor, lineWidth)
    local pts = fillChamferBuf(x, y, w, h, CHAMFER)
    if fillColor then
        setColor(fillColor)
        love.graphics.polygon("fill", pts)
    end
    setColor(borderColor)
    love.graphics.setLineWidth(lineWidth or 1.5)
    love.graphics.polygon("line", pts)
end

local function drawDiamond(cx, cy, r, color, alpha)
    local p = DIAMOND_BUF
    p[1]=cx;   p[2]=cy-r
    p[3]=cx+r; p[4]=cy
    p[5]=cx;   p[6]=cy+r
    p[7]=cx-r; p[8]=cy
    love.graphics.setColor(color[1], color[2], color[3], alpha or color[4])
    love.graphics.polygon("fill", p)
end

--================================================================
-- LIFECYCLE
--================================================================
function scene.enter()
    love.graphics.origin()
    love.graphics.setShader()
    love.graphics.setBlendMode("alpha")
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)

    buildLayout()
    refreshSkinCache()

    if SoundManager and SoundManager.set_active_track then
        SoundManager.set_active_track("base_fondo")
    end
end

function scene.load()
    scene.enter()
end

function scene.update(dt)
    local s = scene.state
    s.t = s.t + dt

    if SoundManager and SoundManager.update then SoundManager.update(dt) end
    if OscClient and OscClient.update then OscClient.update(dt) end

    local glow = scene.led.glow
    for i = 1, ITEM_COUNT do
        local target = (s.selected == i) and 1.0 or 0.0
        if glow[i] < target then
            glow[i] = math.min(target, glow[i] + dt * 6)
        elseif glow[i] > target then
            glow[i] = math.max(target, glow[i] - dt * 4)
        end
    end

    if s.rec_flash > 0 then
        s.rec_flash = math.max(0, s.rec_flash - dt * 2)
    end
end
--================================================================
-- ACTIONS
--================================================================
local function moveSelection(dir)
    local s = scene.state
    s.selected = ((s.selected - 1 + dir) % ITEM_COUNT) + 1
    if SoundManager and SoundManager.play_move_column then
        SoundManager.play_move_column(s.selected)
    end
end

local function confirmSelection()
    local item = ITEMS[scene.state.selected]
    if not item then return end

    if SoundManager and SoundManager.play_hard_drop then
        SoundManager.play_hard_drop()
    end

    _G.CURRENT_GAME_MODE = item.mode_id or "versus"

    if SceneManager and SceneManager.setState then
        SceneManager.setState(item.target)
    elseif SceneManager and SceneManager.switch then
        SceneManager.switch(item.target)
    end
end

local function cycleSkin(dir)
    if ThemeManager and ThemeManager.cycleNext then
        if dir > 0 then ThemeManager.cycleNext() else ThemeManager.cyclePrev() end
    end
    refreshSkinCache()
end

--================================================================
-- INPUT
--================================================================
function scene.keypressed(key)
    if key == "up" then
        moveSelection(-1)
    elseif key == "down" then
        moveSelection(1)
    elseif key == "return" or key == "kpenter" or key == "space" then
        confirmSelection()
    elseif key == "f5" then
        cycleSkin(-1)
    elseif key == "f6" then
        cycleSkin(1)
    elseif key == "f9" then
        scene.state.rec_flash = 1.0
        if _G.ToggleRecording then _G.ToggleRecording() end
    elseif key == "f12" or key == "printscreen" then
        if _G.TakeScreenshot then _G.TakeScreenshot() end
    elseif key == "escape" then
        if love and love.event then love.event.quit() end
    end
end

local function itemRectY(i)
    local y = L.list_top
    for idx = 1, i - 1 do
        y = y + (ITEMS[idx].featured and L.item_h_feat or L.item_h_norm) + L.item_gap
    end
    return y
end

function scene.mousemoved(x, y)
    local s = scene.state
    
    -- Ajuste dinámico de las hitboxes físicas del mouse: resta el desfase si la pantalla bajó por alerta
    local Sentinel = package.loaded["core.sentinel"]
    local shift = Sentinel and Sentinel.getLayoutShift() or 0
    local adjusted_y = y - shift

    s.hover = 0
    if x < L.list_x or x > L.list_x + L.list_w then return end
    for i = 1, ITEM_COUNT do
        local iy = itemRectY(i)
        local ih = ITEMS[i].featured and L.item_h_feat or L.item_h_norm
        if adjusted_y >= iy and adjusted_y <= iy + ih then
            s.hover = i
            return
        end
    end
end

function scene.mousepressed(x, y, button)
    if button ~= 1 then return end
    local s = scene.state
    if s.hover > 0 then
        s.selected = s.hover
        confirmSelection()
    end
end

--================================================================
-- DRAW SUB-ROUTINES
--================================================================
local function drawTitle()
    local lg = love.graphics
    lg.setFont(FontCache.get(28)) -- Lookup puro sin allocations
    setColor(COLOR.text)
    lg.printf("MUTRIS", 0, L.title_y, VW, "center")

    lg.setFont(FontCache.get(11)) -- Lookup puro sin allocations
    setColor(COLOR.cyan)
    drawDiamond(VW / 2 - 110, L.subtitle_y + 6, 4, COLOR.gold, 1)
    lg.printf(scene.cache.skin_str, 0, L.subtitle_y, VW, "center")
    drawDiamond(VW / 2 + 110, L.subtitle_y + 6, 4, COLOR.gold, 1)
end

local function drawItem(i)
    local lg = love.graphics
    local item = ITEMS[i]
    local s = scene.state
    local glow = scene.led.glow[i]
    local selected = (s.selected == i)
    local hovered  = (s.hover == i)

    local h = item.featured and L.item_h_feat or L.item_h_norm
    local y = itemRectY(i)
    local x, w = L.list_x, L.list_w

    local fill = item.featured and COLOR.panel_feat or (hovered and COLOR.panel_hov or COLOR.panel)
    local borderW = 1.5 + glow * 1.5
    drawChamferedPanel(x, y, w, h, fill, item.dim, borderW)

    if glow > 0.02 then
        lg.setColor(item.color[1], item.color[2], item.color[3], 0.65 * glow)
        lg.setLineWidth(2.5)
        lg.polygon("line", fillChamferBuf(x, y, w, h, CHAMFER))
    end

    -- 3px Neon Accent Bar
    setColor(item.color)
    lg.rectangle("fill", x, y + 4, 3, h - 8)

    -- Featured Diamonds (Campaign)
    if item.featured then
        local pulse = 0.6 + 0.4 * math.sin(s.t * 3)
        drawDiamond(x + 14, y + h / 2, 5, COLOR.gold, pulse)
        drawDiamond(x + w - 14, y + h / 2, 5, COLOR.gold, pulse)
    end

    -- Activity LED
    local ledx = item.featured and x + 30 or x + 14
    lg.setColor(item.color[1], item.color[2], item.color[3], selected and 1 or 0.35)
    lg.circle("fill", ledx, y + h / 2, 3)

    -- Title
    lg.setFont(FontCache.get(13)) -- Lookup puro sin allocations
    setColor(selected and COLOR.text or COLOR.text_dim)
    lg.printf(item.title, x, y + (item.featured and 10 or 7), w, "center")

    -- Subtitle
    lg.setFont(FontCache.get(9)) -- Lookup puro sin allocations
    setColor(item.color)
    lg.printf(item.sub, x, y + (item.featured and 30 or 22), w, "center")

    -- Tactical Badge Pill
    local badge_w = 14 + #item.badge * 5
    local bx, by = x + w - badge_w - 10, y + 5
    setColor(item.dim)
    lg.rectangle("fill", bx, by, badge_w, 12, 2, 2)
    setColor(item.color)
    lg.rectangle("line", bx, by, badge_w, 12, 2, 2)
    lg.print(item.badge, bx + 7, by + 1)
end

local function drawLegend()
    local lg = love.graphics
    lg.setFont(FontCache.get(9)) -- Lookup puro sin allocations
    setColor(COLOR.text_faint)
    lg.printf(
        "[ ARRIBA / ABAJO ] NAVEGAR  |  [ ENTER ] SELECCIONAR  |  [ F5 / F6 ] CAMBIAR SKIN  |  [ F9 ] REC  |  [ F12 ] CAPTURA",
        0, L.legend_y, VW, "center"
    )

    if scene.state.rec_flash > 0 then
        lg.setColor(COLOR.red[1], COLOR.red[2], COLOR.red[3], scene.state.rec_flash)
        lg.circle("fill", VW - 24, L.footer_y - 10, 5)
    end
end

--================================================================
-- MAIN MASTER DRAW PIPELINE
--================================================================
function scene.draw()
    local lg = love.graphics

    -- Reset de pipeline para evitar fugas de estados OpenGL
    lg.origin()
    lg.setShader()
    lg.setBlendMode("alpha")
    lg.setLineWidth(1)
    lg.setColor(1, 1, 1, 1)

    setColor(COLOR.bg)
    lg.rectangle("fill", 0, 0, VW, VH)

    -- Inversión de Control de Hardware via Sentinel Exposer
    local Sentinel = package.loaded["core.sentinel"]
    local active_leak = Sentinel and Sentinel.is_breach_active
    local shift = Sentinel and Sentinel.getLayoutShift() or 0

    -- Si hay alerta de telemetría activa en menú, empujamos el render un bloque entero abajo
    if active_leak and shift > 0 then
        lg.push()
        lg.translate(0, shift)
    end

    -- Los componentes se renderizan protegidos dentro de la traslación de la matriz gráfica
    drawTitle()
    for i = 1, ITEM_COUNT do drawItem(i) end
    drawLegend()

    -- Cierre de la traslación y renderizado directo del banner de alto contraste invertido
    if active_leak and shift > 0 then
        lg.pop() -- Restauramos coordenadas absolutas de pantalla (0,0)

        -- Geometría calibrada milimétricamente para el canal negro libre debajo de MUTRIS
        local bx, by, bw, bh = 360, 92, 560, 60

        -- Asignación de bloque sólido opaco (alpha = 1.0) para legibilidad quirúrgica aeroespacial
        if Sentinel.current_type == "PERF" then
            lg.setColor(1.0, 0.45, 0.0, 1.0) -- Naranja sólido
        elseif Sentinel.current_type == "LEAK" then
            lg.setColor(1.0, 0.82, 0.22, 1.0) -- Ámbar/Dorado sólido
        else
            lg.setColor(1.0, 0.15, 0.15, 1.0) -- Rojo crítico sólido
        end

        -- Renderizar el contenedor sólido
        lg.rectangle("fill", bx, by, bw, bh, 4)

        -- Borde fino charcoal anti-empaste
        lg.setLineWidth(1.5)
        lg.setColor(0.02, 0.03, 0.06, 1.0)
        lg.rectangle("line", bx, by, bw, bh, 4)

        -- Strobe a 8Hz sin allocations operando sobre la tipografía negra invertida MASIVA
        local strobe = math.floor((_G.RealMatchTimer or love.timer.getTime()) * 8) % 2 == 0
        if strobe then
            -- ENCABEZADO MASIVO EN NEGRO (Font 14)
            lg.setFont(FontCache.get(14))
            lg.setColor(0.02, 0.03, 0.06, 1.0) -- TEXTO NEGRO SÓLIDO
            lg.printf("[ SYSTEM EXCEPTION / METRIC BREACH ]", bx, by + 8, bw, "center")

            -- TELEMETRÍA DETALLADA EN NEGRO (Font 12) - Formateo asíncrono de variables numéricas fijas
            lg.setFont(FontCache.get(12))
            if Sentinel.current_type == "LEAK" then
                lg.printf(string.format("RAM DELTA  +%.4f KB  total=%.2f KB  frame=#%d", Sentinel.val_delta, Sentinel.val_total, Sentinel.val_frame), bx + 8, by + 32, bw - 16, "center")
            else
                lg.printf(string.format("PERF DROP  dt=%.2fms  overbudget=+%.1fus  frame=#%d", Sentinel.val_delta, Sentinel.val_total, Sentinel.val_frame), bx + 8, by + 32, bw - 16, "center")
            end
        end

    end

    lg.setColor(1, 1, 1, 1)
end

scene.mousemoved_drag = function(_) end
scene.mousereleased   = function(_, _, _) end

return scene

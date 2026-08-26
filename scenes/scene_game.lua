-- ================================================================
-- FILE: scenes/scene_game.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: DYNAMIC GAMEPLAY SCENE & BATTLE ROYALE MULTI-LAYOUT
-- Clean 240Hz, LayoutSolver Integration, Meteor Projectile Orchestration
-- ============================================================================
local SceneGame = {}

local Board           = require "tetris.board"
local AIBot           = require "tetris.ai_bot"
local Input           = require "input"
local EventBus        = require "core.event_bus"
local ThemeManager    = require "tetris.theme_manager"
local FogLayer        = require "tetris.fog_layer"
local HUDPanels       = require "tetris.hud_panels"
local HUDCenter       = require "tetris.hud_center"
local AnomalyManager  = require "tetris.anomaly_manager"
local Telemetry       = require "tetris.telemetry"
local Blackbox        = require "core.blackbox"
local FontCache       = require "tetris.font_cache"
local AudioManager    = require "audio_manager"
local MusicManager    = require "music_manager"
local TrackManager    = require "track_manager"
local MetaBalancer    = require "core.meta_balancer"
local SceneManager    = require "core.scene_manager"
local PartBreaking    = require "combat.part_breaking"
local BossProjectiles = require "combat.boss_projectiles"
local LayoutSolver    = require "core.layout_solver"
local SoundManager    = require "audio.sound_manager"
local OscClient       = require "network.osc_client"

SceneGame.boards = {}
SceneGame.bots = {}
SceneGame.mode = "versus"
SceneGame.last_config = nil
SceneGame.return_scene = "menu"
SceneGame.layout_style = "versus"
SceneGame.layout_data = nil

-- Estado de Fin de Partida
SceneGame.match_over = false
SceneGame.human_won = false
SceneGame.winner_name = ""
SceneGame.victory_flash = 0.0
SceneGame.final_match_time = 0.0

-- ============================================================================
-- PAUSA: Máquina de estados multi-nivel (Zero-GC)
-- ============================================================================
SceneGame.is_paused       = false
SceneGame.pause_selected  = 1
SceneGame.pause_menu_state = "MAIN"  -- "MAIN" | "HANDLING" | "AUDIO" | "GRAPHICS"

-- Menú PRINCIPAL (tabla estática inmutable de módulo)
local PAUSE_MAIN = {
    { text = "RESUME GAME",          action = "resume"    },
    { text = "CONTROLS & HANDLING",  action = "HANDLING"  },
    { text = "AUDIO & SYNTH",        action = "AUDIO"     },
    { text = "GRAPHICS & INTERFACE", action = "GRAPHICS"  },
    { text = "RESTART MATCH",        action = "restart"   },
    { text = "QUIT TO MAIN MENU",    action = "menu"      },
}

-- Sub-menú HANDLING — lee/escribe SettingsManager en caliente
local PAUSE_HANDLING = {
    { text = "DAS (AUTO-SHIFT)",   key = "das",  min = 0.050, max = 0.200, step = 0.004, unit = "ms", scale = 1000 },
    { text = "ARR (REPEAT RATE)",  key = "arr",  min = 0.000, max = 0.025, step = 0.0005,unit = "ms", scale = 1000 },
    { text = "SDF (SOFT DROP)",    key = "sdf",  min = 5,     max = 40,    step = 5,     unit = "x",  scale = 1    },
    { text = "LOCK DELAY",         key = "lock_delay", min = 0.05, max = 1.0, step = 0.05, unit = "s", scale = 1  },
    { text = "\226\151\132 BACK TO MAIN",   action = "back"   },
}
-- Sub-menú AUDIO
local PAUSE_AUDIO = {
    { text = "MASTER VOLUME",   key = "master_vol",    min = 0.0, max = 1.0, step = 0.05, unit = "%", scale = 100 },
    { text = "BGM VOLUME",      key = "bgm_vol",       min = 0.0, max = 1.0, step = 0.05, unit = "%", scale = 100 },
    { text = "SFX VOLUME",      key = "sfx_vol",       min = 0.0, max = 1.0, step = 0.05, unit = "%", scale = 100 },
    { text = "SUB-BASS POWER",  key = "subbass_power", min = 1,   max = 4,   step = 1,    unit = "",  scale = 1   },
    { text = "\226\151\132 BACK TO MAIN",   action = "back" },
}
-- Sub-menú GRAPHICS
local PAUSE_GRAPHICS = {
    { text = "THEME SKIN",      key = "theme_skin",     min = 1, max = 5, step = 1, unit = "", scale = 1, is_skin = true },
    { text = "BLOOM INTENSITY", key = "bloom_intensity", min = 0.0, max = 1.0, step = 0.1, unit = "%", scale = 100 },
    { text = "GHOST ALPHA",     key = "ghost_alpha",    min = 0.0, max = 1.0, step = 0.05, unit = "%", scale = 100 },
    { text = "SCREEN SHAKE",    key = "screen_shake",   min = 0.0, max = 1.0, step = 0.1, unit = "%", scale = 100 },
    { text = "\226\151\132 BACK TO MAIN",   action = "back" },
}

-- Referencia al sub-menú activo (sin tabla nueva — apunta a las estáticas)
local _PAUSE_ACTIVE_MENU  = PAUSE_MAIN
local _PAUSE_ACTIVE_COUNT = #PAUSE_MAIN

-- Telemetría de pausa: última tecla registrada (debug persistente on-screen)
local _pause_last_key = "---"

-- Strings cacheados del panel
local _PAUSE_TITLE = "GAME PAUSED"
local _PAUSE_HINT  = "Las partidas pausadas mantienen el determinismo de frame exacto"

-- Barra de slider (24 chars fija, sin alloc): reutilizada in-place
local _SLIDER_BUF = {}
for _i = 1, 24 do _SLIDER_BUF[_i] = 0 end

local SettingsManager = require "settings_manager"

-- Actualiza la referencia al menú activo (Zero-GC: sin tabla nueva)
local function _pauseSyncMenu(state)
    SceneGame.pause_menu_state = state
    SceneGame.pause_selected   = 1
    if     state == "MAIN"     then _PAUSE_ACTIVE_MENU = PAUSE_MAIN;     _PAUSE_ACTIVE_COUNT = #PAUSE_MAIN
    elseif state == "HANDLING" then _PAUSE_ACTIVE_MENU = PAUSE_HANDLING; _PAUSE_ACTIVE_COUNT = #PAUSE_HANDLING
    elseif state == "AUDIO"    then _PAUSE_ACTIVE_MENU = PAUSE_AUDIO;    _PAUSE_ACTIVE_COUNT = #PAUSE_AUDIO
    elseif state == "GRAPHICS" then _PAUSE_ACTIVE_MENU = PAUSE_GRAPHICS; _PAUSE_ACTIVE_COUNT = #PAUSE_GRAPHICS
    end
end

-- Ajusta el valor de un slider (+1 step = right, -1 step = left) in-place
local function _pauseSliderAdjust(opt, dir)
    local cur = SettingsManager.get(opt.key)
    if cur == nil then cur = SettingsManager.defaults[opt.key] or opt.min end
    local nv = cur + opt.step * dir
    -- Clamp con redondeo para evitar float drift
    nv = math.floor(nv * 10000 + 0.5) / 10000
    nv = math.max(opt.min, math.min(opt.max, nv))
    SettingsManager.set(opt.key, nv)
    -- Aplicar en vivo si es tema de skin
    if opt.is_skin and ThemeManager then
        if dir > 0 then ThemeManager.cycleNext() else ThemeManager.cyclePrev() end
    end
end

-- Renderiza una línea de slider: "[\u25c4 \u2588\u2588\u2588\u2588\u2591\u2591 \u25ba]" (bloque sólido/vacío, 8 segmentos)
local function _renderSliderBar(opt, cur_val)
    local filled = math.floor(((cur_val - opt.min) / (opt.max - opt.min)) * 8 + 0.5)
    -- Build string without table alloc: manual concat on 12-char buffer
    local s = "["
    for seg = 1, 8 do
        s = s .. (seg <= filled and "\xe2\x96\x88" or "\xe2\x96\x91")
    end
    s = s .. "]"
    return s
end


function SceneGame.init()
    -- NOTE: play_move_column and play_rotate are now driven directly from input.lua
    -- with real column position for pentatonic pitch mapping.
    EventBus.on(EventBus.ON_LINE_CLEAR, function(lines, is_tspin, p_id, combo)
        if p_id == 1 then
            if lines > 0 then
                SoundManager.play_line_clear(lines, combo)
                if lines == 4 and OscClient.send_tetris then
                    OscClient.send_tetris(SoundManager.bass_midi)
                end
            end
            if is_tspin == 1 then
                SoundManager.play_tspin()
                OscClient.send_tspin()
            end
        end
    end)
    EventBus.on("on_hard_drop", function(p_id)
        if p_id == 1 then
            SoundManager.play_hard_drop()
            OscClient.send_drop()
        end
    end)
end

function SceneGame.enter(data)
    local ok, err = pcall(function()
        data = data or {}
        SceneGame.last_config = data
        SceneGame.mode = data.mode or _G.CURRENT_GAME_MODE or "versus"
        _G.CURRENT_GAME_MODE = SceneGame.mode -- ⚡ SINCRONIZACIÓN GLOBAL CRÍTICA

        SceneGame.return_scene = data.return_scene or "menu"
        SceneGame.layout_style = data.layout_style or (SceneGame.mode == "boss_hunt" and "gigantic_boss" or (#(data.boards or {}) > 2 and "multibot" or "versus"))
        SceneGame.boards = {}
        SceneGame.bots = {}

        SoundManager.init()
        OscClient.init("127.0.0.1", 8000)

        _G.RealMatchTimer = 0.0
        SceneGame.final_match_time = 0.0
        SceneGame.match_over = false
        SceneGame.human_won = false
        SceneGame.winner_name = ""
        SceneGame.victory_flash = 0.0

        local boards_config = data.boards or {
            { type = "human", cols = 10, rows = 40, ai_profile = nil },
            { type = "bot",   cols = 10, rows = 40, ai_profile = "normal" }
        }

        local sw, sh = love.graphics.getDimensions()
        local layout = LayoutSolver.solve(SceneGame.layout_style, boards_config, sw, sh)
        SceneGame.layout_data = layout

        local human_board = nil
        for i, b_info in ipairs(layout.boards) do
            local b = Board.new(b_info.x, b_info.y, b_info.type, b_info.cols, b_info.rows, b_info.block_size)
            b.layout_info = b_info
            b.is_boss = (b_info.type == "bot" and (SceneGame.mode == "boss_hunt" or b_info.ai_profile == "boss"))
            table.insert(SceneGame.boards, b)

            if b_info.type == "human" then
                human_board = b
                if Input and Input.init then Input.init(b) end
            elseif b_info.type == "bot" then
                local bot = AIBot.new(b, b_info.ai_profile or "normal")
                table.insert(SceneGame.bots, bot)
            end
        end

        SceneGame.relinkOpponents()

        if SceneGame.mode == "boss_hunt" or SceneGame.layout_style == "gigantic_boss" then
            PartBreaking.init()
            BossProjectiles.init()
        end
        
        EventBus.emit("on_match_restart")
        Blackbox.log("SCENE", "Game Scene entered in mode: " .. SceneGame.mode .. " [Layout: " .. SceneGame.layout_style .. "]", 0, 0)
    end)
    
    if not ok then
        local log_f = io.open("debug_log.txt", "a")
        if log_f then
            log_f:write(tostring(os.date()) .. " - SceneGame.enter ERROR: " .. tostring(err) .. "\n" .. debug.traceback() .. "\n")
            log_f:close()
        end
        error(err)
    end
end

function SceneGame.restartMatch()
    if TrackManager and TrackManager.nextTrack then
        TrackManager.nextTrack()
    end
    if MusicManager and MusicManager.start then
        MusicManager.start()
    end

    if ThemeManager and ThemeManager.triggerRestartHalo then
        ThemeManager.triggerRestartHalo()
    end

    local cur_track = TrackManager and TrackManager.getCurrentTrack()
    if cur_track and ThemeManager and ThemeManager.showToast then
        ThemeManager.showToast("TRACK: " .. (cur_track.name or "DEFAULT THEME"), {0.1, 0.95, 1.0})
    end

    AudioManager.playImmediateSFX("rotate", false)
    
    local SoundManager = require("audio.sound_manager")
    -- Ironclad 'R' sync: detect the actual playing BGM and re-sync tonality + HUD watermark
    local bgm_id = cur_track and (cur_track.id or cur_track.file) or nil
    SoundManager.sync_with_current_bgm(bgm_id)
    SoundManager.reset()
    
    SceneManager.setState("game", SceneGame.last_config)
end

function SceneGame.relinkOpponents()
    local alive_boards = {}
    for i = 1, #SceneGame.boards do
        if not SceneGame.boards[i].is_dying then
            table.insert(alive_boards, SceneGame.boards[i])
        end
    end
    if #alive_boards >= 2 then
        for i, b in ipairs(alive_boards) do
            local opp_index = (i % #alive_boards) + 1
            b.opponent = alive_boards[opp_index]
        end
    end
end

function SceneGame.update(dt)
    -- PAUSA: cortocircuito total — ni physics ni input se procesan
    if SceneGame.is_paused then return end

    local ok, err = pcall(function()
        if not SceneGame.match_over then
            -- --- CRITICAL REFACTOR: RUN THE PARAMETRIC TIMER DIRECTLY INSIDE THE SCENE GAME LOOP ---
            local AnomalyManager = require "tetris.anomaly_manager"
            if AnomalyManager and AnomalyManager.update then
                AnomalyManager.update(dt)
            end

            -- Main core input pipeline integration
            local Input = require "input"
            if Input and Input.update then
                Input.update(dt)
            end

            SoundManager.update(dt)
            OscClient.update(dt)

            -- Continuous danger level: normalized stack height [0.0..1.0]
            local p1_board = SceneGame.boards and SceneGame.boards[1]
            if p1_board and p1_board.get_highest_block_y then
                local highest_y   = p1_board:get_highest_block_y()
                local visible_rows = p1_board.visible_rows or 20
                local danger_level = 1.0 - (highest_y / visible_rows)
                OscClient.send_danger(danger_level)
            end

            -- Update all active matrices grids on screen
            for i = 1, #SceneGame.boards do
                SceneGame.boards[i]:update(dt)
            end
            
            -- Update competitive Rust-driven IA simulation frames
            for i = 1, #SceneGame.bots do
                SceneGame.bots[i]:update(dt)
            end

            if SceneGame.mode == "boss_hunt" or SceneGame.layout_style == "gigantic_boss" then
                PartBreaking.update(dt)
                BossProjectiles.update(dt)
            end

            local total_boards = #SceneGame.boards
            local alive_count = 0
            local human_alive = false

            for i = 1, total_boards do
                local b = SceneGame.boards[i]
                if not b.is_dying then
                    alive_count = alive_count + 1
                    if b.player_type == "human" then
                        human_alive = true
                    end
                end
            end

            if total_boards == 2 then
                for i = 1, total_boards do
                    local b = SceneGame.boards[i]
                    if b.is_dying and b.death_timer <= 0.35 then
                        SceneGame.match_over = true
                        SceneGame.victory_flash = 1.0
                        SceneGame.final_match_time = _G.RealMatchTimer or 0.0

                        local human_lost = (b.player_type == "human")
                        SceneGame.human_won = not human_lost
                        SceneGame.winner_name = SceneGame.human_won and "PLAYER 1" or "BOT AI"

                        if SceneGame.human_won then
                            AudioManager.playImmediateSFX("ultimatris", false)
                            AudioManager.playVoiceAnnounce("victory")
                        else
                            AudioManager.playImmediateSFX("death", false)
                            AudioManager.playVoiceAnnounce("danger")
                        end

                        local p1 = SceneGame.boards[1]
                        local bot = SceneGame.boards[2]
                        local p1_pps = (p1 and p1.current_pps_display) or 1.0
                        local bot_pps = (bot and bot.current_pps_display) or 1.4

                        MetaBalancer.registerMatchOutcome(SceneGame.human_won, SceneGame.final_match_time, p1_pps, bot_pps)
                        AIBot.registerMatchOutcome(SceneGame.human_won, p1_pps)

                        Blackbox.log("MATCH_END", SceneGame.human_won and "VICTORY: PLAYER 1" or "DEFEAT: BOT WON", math.floor(p1_pps * 10), math.floor(SceneGame.final_match_time))
                        break
                    end
                end
            else
                if not human_alive then
                    local p1 = SceneGame.boards[1]
                    if p1 and p1.is_dying and p1.death_timer <= 0.35 then
                        SceneGame.match_over = true
                        SceneGame.human_won = false
                        SceneGame.winner_name = "BOT AI"
                        SceneGame.victory_flash = 1.0
                        SceneGame.final_match_time = _G.RealMatchTimer or 0.0

                        AudioManager.playImmediateSFX("death", false)
                        AudioManager.playVoiceAnnounce("danger")

                        Blackbox.log("MATCH_END", "MULTI-BOT DEFEAT: P1 ELIMINATED", 0, math.floor(SceneGame.final_match_time))
                    end
                elseif alive_count <= 1 and human_alive then
                    SceneGame.match_over = true
                    SceneGame.human_won = true
                    SceneGame.winner_name = "PLAYER 1"
                    SceneGame.victory_flash = 1.0
                    SceneGame.final_match_time = _G.RealMatchTimer or 0.0

                    AudioManager.playImmediateSFX("ultimatris", false)
                    AudioManager.playVoiceAnnounce("victory")

                    local p1 = SceneGame.boards[1]
                    local p1_pps = (p1 and p1.current_pps_display) or 1.0
                    MetaBalancer.registerMatchOutcome(true, SceneGame.final_match_time, p1_pps, 1.5)
                    AIBot.registerMatchOutcome(true, p1_pps)

                    Blackbox.log("MATCH_END", "MULTI-BOT VICTORY: LAST MAN STANDING", math.floor(p1_pps * 10), math.floor(SceneGame.final_match_time))
                else
                    SceneGame.relinkOpponents()
                end
            end
        else
            if SceneGame.victory_flash > 0 then
                SceneGame.victory_flash = math.max(0, SceneGame.victory_flash - dt * 2.5)
            end
        end
    end)
    
    if not ok then
        local log_f = io.open("debug_log.txt", "a")
        if log_f then
            log_f:write(tostring(os.date()) .. " - SceneGame.update ERROR: " .. tostring(err) .. "\n" .. debug.traceback() .. "\n")
            log_f:close()
        end
        error(err)
    end
end

function SceneGame.draw()
    local ok, err = pcall(function()
        if ThemeManager.drawBackground then ThemeManager.drawBackground() end
        if FogLayer.draw then FogLayer.draw() end

        local layout = SceneGame.layout_data or {}
        local num_b = #SceneGame.boards
        local is_multibot = layout.is_multibot or (num_b > 2)
        local is_boss = layout.is_boss or (SceneGame.mode == "boss_hunt")
        local cx = layout.center_hud_x or 640

        -- 1. Renderizado de Tableros y Paneles
        for i = 1, num_b do
            local b = SceneGame.boards[i]
            b:draw()
            if HUDPanels.draw then HUDPanels.draw(b, is_multibot, is_boss) end
        end

        -- 2. Meteoritos Balísticos
        BossProjectiles.draw()

        -- 3. HUD Central
        if num_b == 2 and not is_multibot then
            local p1 = SceneGame.boards[1]
            local p2 = SceneGame.boards[2]
            if HUDCenter.draw then HUDCenter.draw(p1, p2, cx) end
            if AnomalyManager.draw then AnomalyManager.draw(p1, p2) end
            if Telemetry.draw then Telemetry.draw(p1, p2, cx, is_boss) end
            if Blackbox.drawPermanentHUD then Blackbox.drawPermanentHUD(p1, p2, cx, is_boss) end
        elseif is_multibot then
            if Telemetry.drawMultiBot then
                Telemetry.drawMultiBot(SceneGame.boards)
            end
        end

        -- 4. Overlay de Pausa — Menú multi-nivel (Zero-GC)
        if SceneGame.is_paused then
            local lg    = love.graphics
            local sel   = SceneGame.pause_selected
            local pmenu = _PAUSE_ACTIVE_MENU
            local pcount = _PAUSE_ACTIVE_COUNT
            local pstate = SceneGame.pause_menu_state
            local t_px  = _G.RealMatchTimer or 0
            local blink = (math.floor(t_px * 2) % 2 == 0)

            lg.push("all")

            -- Fondo atenuado
            lg.setColor(0, 0, 0, 0.80)
            lg.rectangle("fill", 0, 0, 1280, 720)

            -- Panel adaptativo
            local px, py = 360, 175
            local pw     = 560
            local ph     = 58 + pcount * 46 + 38

            lg.setColor(0.04, 0.06, 0.10, 0.97)
            lg.rectangle("fill", px, py, pw, ph, 8)
            lg.setColor(0.25, 0.90, 1.00, 0.85)
            lg.setLineWidth(2)
            lg.rectangle("line", px, py, pw, ph, 8)
            lg.setLineWidth(1)

            -- Acento neón (3 px)
            lg.setColor(0.25, 0.90, 1.00, 1.0)
            lg.rectangle("fill", px + 8, py + 2, pw - 16, 3, 1)

            -- Título + breadcrumb del sub-menú
            lg.setFont(FontCache.get(16))
            lg.setColor(1, 1, 1, 1)
            local title_str = (pstate == "MAIN") and _PAUSE_TITLE
                or (_PAUSE_TITLE .. " │ " .. pstate)
            lg.printf(title_str, px, py + 14, pw, "center")
            -- LED parpadeante
            if blink then
                lg.setColor(0.25, 0.90, 1.00, 1.0)
                lg.circle("fill", px + 20, py + 22, 4)
            end

            -- Separador
            lg.setColor(0.25, 0.90, 1.00, 0.28)
            lg.rectangle("fill", px + 16, py + 46, pw - 32, 1)
            -- Opciones del menú de pausa
            for i = 1, pcount do
                local opt     = pmenu[i]
                local is_sel  = (sel == i)
                local item_y  = py + 52 + (i - 1) * 46
                local is_back = (opt.action == "back")

                if is_sel then
                    -- Fondo de selección
                    lg.setColor(0.10, 0.28, 0.36, 0.82)
                    lg.rectangle("fill", px + 10, item_y - 4, pw - 20, 36, 4)
                    lg.setColor(0.25, 0.90, 1.00, 0.88)
                    lg.setLineWidth(1.5)
                    lg.rectangle("line", px + 10, item_y - 4, pw - 20, 36, 4)
                    lg.setLineWidth(1)
                    -- LED cian
                    lg.setColor(0.25, 0.90, 1.00, 1.0)
                    lg.circle("fill", px + 26, item_y + 14, 4)
                    -- Diamante dorado
                    if not is_back then
                        local dx, dy, dr = px + pw - 26, item_y + 14, 5
                        lg.setColor(1.0, 0.82, 0.22, 0.90)
                        lg.polygon("fill", dx, dy-dr, dx+dr, dy, dx, dy+dr, dx-dr, dy)
                    end
                    lg.setFont(FontCache.get(12))
                    lg.setColor(is_back and 0.80 or 0.25, is_back and 0.85 or 0.90, is_back and 0.90 or 1.00, 1.0)
                else
                    lg.setFont(FontCache.get(11))
                    lg.setColor(is_back and 0.55 or 0.42, is_back and 0.60 or 0.50, 0.62, 0.78)
                end

                -- Texto de la opción
                if opt.key then
                    -- Es un slider: renderizar label + valor + barra
                    local cur = SettingsManager.get(opt.key)
                    if cur == nil then cur = SettingsManager.defaults[opt.key] or opt.min end
                    local displayed = math.floor(cur * opt.scale * 10 + 0.5) / 10
                    local bar_str   = _renderSliderBar(opt, cur)
                    local line_str  = string.format("%s: %.0f%s  %s",
                        opt.text, displayed, opt.unit, bar_str)
                    lg.printf(line_str, px + 38, item_y + 6, pw - 56, "left")
                    -- Flechas laterales si está seleccionado
                    if is_sel then
                        lg.setColor(0.25, 0.90, 1.00, 0.70)
                        lg.print("\226\151\132", px + 14, item_y + 6)
                        lg.print("\226\151\186", px + pw - 26, item_y + 6)
                    end
                else
                    -- Es una acción normal
                    lg.printf(opt.text, px, item_y + 6, pw, "center")
                end
            end

            -- Hint inferior
            lg.setFont(FontCache.get(8))
            lg.setColor(0.35, 0.40, 0.50, 0.65)
            lg.printf(_PAUSE_HINT, px, py + ph - 20, pw, "center")

            -- Barra de controles
            lg.setFont(FontCache.get(8))
            lg.setColor(0.50, 0.56, 0.66, 0.68)
            local ctrl_str = (pstate == "MAIN")
                and "[UP/DN] NAV   [ENTER] SELECT   [ESC] RESUME   [M] MENU"
                or  "[UP/DN] NAV   [LT/RT] ADJUST   [ESC] BACK     [M] MENU"
            lg.printf(ctrl_str, px, py + ph + 8, pw, "center")

            -- ── TELEMETRÍA DE PAUSA (debug on-screen permanente) ──────────
            local ty = py + ph + 24
            lg.setFont(FontCache.get(8))
            lg.setColor(0.02, 0.04, 0.06, 0.90)
            lg.rectangle("fill", px, ty, pw, 36, 4)
            lg.setColor(0.20, 0.70, 0.30, 0.60)
            lg.setLineWidth(1)
            lg.rectangle("line", px, ty, pw, 36, 4)
            lg.setColor(0.20, 0.90, 0.40, 0.95)
            lg.printf(
                string.format("PAUSE DBG | is_paused=%-5s  selected=%d/%d  state=%s",
                    tostring(SceneGame.is_paused),
                    SceneGame.pause_selected,
                    _PAUSE_ACTIVE_COUNT,
                    tostring(SceneGame.pause_menu_state)
                ),
                px + 6, ty + 4, pw - 12, "left"
            )
            lg.setColor(0.60, 0.95, 0.60, 0.85)
            lg.printf(
                string.format("LAST_KEY=%-10s  match_over=%-5s  count=%d",
                    _pause_last_key,
                    tostring(SceneGame.match_over),
                    _PAUSE_ACTIVE_COUNT
                ),
                px + 6, ty + 18, pw - 12, "left"
            )
            lg.pop()
        end
        -- 5. Modal de Victoria / Derrota
        if SceneGame.match_over then
            local t = ThemeManager.getCurrent()
            local mx, my = 640 - 280, 360 - 170
            local mw, mh = 560, 340

            love.graphics.push("all")
            love.graphics.setColor(0.01, 0.015, 0.025, 0.88)
            love.graphics.rectangle("fill", 0, 0, 1280, 720)

            love.graphics.setColor(0.02, 0.025, 0.04, 0.98)
            love.graphics.rectangle("fill", mx, my, mw, mh, 8)

            local border_clr = SceneGame.human_won and {0.1, 0.95, 0.55} or {1.0, 0.15, 0.25}
            love.graphics.setLineWidth(2.5)
            love.graphics.setColor(border_clr[1], border_clr[2], border_clr[3], 0.98)
            love.graphics.rectangle("line", mx, my, mw, mh, 8)

            love.graphics.setFont(FontCache.get(22))
            love.graphics.setColor(border_clr[1], border_clr[2], border_clr[3], 1.0)
            local title_txt = SceneGame.human_won and (is_multibot and "/// VICTORY // LAST MAN STANDING ///" or "/// VICTORY // TRANSCENDENCE ///") or "/// DEFEAT // MATRIX OVERFLOW ///"
            love.graphics.printf(title_txt, mx, my + 24, mw, "center")

            love.graphics.setFont(FontCache.get(10))
            love.graphics.setColor(1, 1, 1, 0.75)
            local sub_txt = SceneGame.human_won and "ALL OPPONENT MATRICES ELIMINATED // ARENA CONQUERED" or "CRITICAL STRUCTURAL COLLAPSE // REBOOT REQUIRED"
            love.graphics.printf(sub_txt, mx, my + 56, mw, "center")

            local p1 = SceneGame.boards[1]
            local p1_pps = (p1 and p1.current_pps_display) or 1.0
            local p1_lines = (p1 and p1.lines_cleared) or 0
            local p1_combo = (p1 and p1.max_combo) or 0
            local p1_sent = (p1 and p1.garbage_sent) or 0

            local sy = my + 105
            love.graphics.setFont(FontCache.get(12))
            love.graphics.setColor(t.primary[1], t.primary[2], t.primary[3], 0.95)
            love.graphics.printf(string.format("MATCH DURATION: %05.1fs", SceneGame.final_match_time), mx, sy, mw, "center")

            love.graphics.setFont(FontCache.get(10))
            love.graphics.setColor(0.85, 0.90, 1.0, 0.90)
            love.graphics.printf(string.format("P1 SPEED: %.2f PPS   |   LINES CLEARED: %d", p1_pps, p1_lines), mx, sy + 32, mw, "center")
            love.graphics.printf(string.format("MAX COMBO: %d HITS   |   GARBAGE SENT: %d LINES", p1_combo, p1_sent), mx, sy + 58, mw, "center")

            local prof = _G.AI_ADAPTIVE_PROFILE
            if prof then
                love.graphics.setFont(FontCache.get(9))
                love.graphics.setColor(0.1, 1.0, 0.55, 0.85)
                love.graphics.printf(string.format("OVERALL RECORD: %d WINS - %d LOSSES (AVG: %.2f PPS)", prof.player_wins or 0, prof.bot_wins or 0, prof.player_avg_pps or 1.0), mx, sy + 90, mw, "center")
            end

            love.graphics.setFont(FontCache.get(11))
            love.graphics.setColor(1.0, 0.90, 0.35, 0.98)
            love.graphics.printf("[ ENTER / SPACE / R ] JUGAR DE NUEVO   |   [ ESC ] SALIR", mx, my + mh - 38, mw, "center")

            love.graphics.pop()
        end

        -- ── 🛡️ INYECCIÓN NATIVA DEL BANNER DEL SENTINEL EN PARTIDA (CALIBRADO CENTRAL ANTI-BLOQUEO) ──
        local Sentinel = package.loaded["core.sentinel"]
                if Sentinel and Sentinel.is_breach_active and not SceneGame.is_paused then
            -- Calibración horizontal expandida anti-wrap (Ancho = 420px, Alto = 52px)
            local bx, by, bw, bh = 430, 620, 420, 52

            love.graphics.push("all")

            -- Asignación de bloque sólido opaco (alpha = 1.0) para contraste militar puro
            if Sentinel.current_type == "PERF" then
                love.graphics.setColor(1.0, 0.45, 0.0, 1.0)  -- Naranja sólido brillante
            elseif Sentinel.current_type == "LEAK" then
                love.graphics.setColor(1.0, 0.82, 0.22, 1.0) -- Dorado/Ámbar sólido brillante
            else
                love.graphics.setColor(1.0, 0.15, 0.15, 1.0)  -- Rojo crítico sólido
            end

            -- Renderizar el contenedor sólido de la alerta
            love.graphics.rectangle("fill", bx, by, bw, bh, 4)

            -- Contorno fino de terminación oscuro anti-empaste
            love.graphics.setLineWidth(1.5)
            love.graphics.setColor(0.02, 0.03, 0.06, 1.0)
            love.graphics.rectangle("line", bx, by, bw, bh, 4)

            -- Strobe a 8Hz sin allocations operando en tipografía invertida MASIVA e inmune a variables locales
            local strobe = math.floor((_G.RealMatchTimer or love.timer.getTime()) * 8) % 2 == 0
            if strobe then
                -- ENCABEZADO MASIVO EN NEGRO (Font 14)
                love.graphics.setFont(FontCache.get(14))
                love.graphics.setColor(0.02, 0.03, 0.06, 1.0)
                love.graphics.printf("[ SYSTEM EXCEPTION ]", bx, by + 6, bw, "center")

                -- TELEMETRÍA DETALLADA EN UNA SOLA LÍNEA (Font 12) - Espacio de sobra horizontal
                love.graphics.setFont(FontCache.get(12))
                love.graphics.setColor(0.02, 0.03, 0.06, 1.0)
                love.graphics.printf(Sentinel.current_msg or "", bx + 10, by + 28, bw - 20, "center")
            end

            love.graphics.pop()
        end
        -- ─────────────────────────────────────────────────────────────────────────────
    end)
    
    if not ok then
        local log_f = io.open("debug_log.txt", "a")
        if log_f then
            log_f:write(tostring(os.date()) .. " - SceneGame.draw ERROR: " .. tostring(err) .. "\n" .. debug.traceback() .. "\n")
            log_f:close()
        end
        love.graphics.setColor(1,0,0,1)
        love.graphics.print("RENDER ERROR: " .. tostring(err), 10, 10)
    end
end



function SceneGame.keypressed(key)
    -- Telemetría: registra la última tecla recibida (visible en el overlay de pausa)
    _pause_last_key = key

    -- ── PANTALLA DE FIN DE PARTIDA ────────────────────────────────────────
    if SceneGame.match_over then
        if key == "return" or key == "space" or key == "r" then
            SceneGame.is_paused = false
            SceneGame.restartMatch()
            return true
        elseif key == "escape" then
            SceneGame.is_paused = false
            _pauseSyncMenu("MAIN")
            SceneManager.setState(SceneGame.return_scene or "menu")
            if AudioManager and AudioManager.playMenuBack then AudioManager.playMenuBack() end
            return true
        end
        return true
    end

    -- ── [ESC] TOGGLE MAESTRO (evaluado ANTES de cualquier otra rama) ──────
    if key == "escape" then
        if SceneGame.is_paused then
            if SceneGame.pause_menu_state ~= "MAIN" then
                _pauseSyncMenu("MAIN")
                if AudioManager and AudioManager.playImmediateSFX then AudioManager.playImmediateSFX("rotate", false) end
            else
                SceneGame.is_paused = false
                _pauseSyncMenu("MAIN")
                if AudioManager and AudioManager.playImmediateSFX then AudioManager.playImmediateSFX("rotate", false) end
            end
        else
            SceneGame.is_paused = true
            _pauseSyncMenu("MAIN")
            if AudioManager and AudioManager.playImmediateSFX then AudioManager.playImmediateSFX("hold", false) end
        end
        return true
    end

    -- ── PIPELINE EXCLUSIVO DE PAUSA ───────────────────────────────────────
    if SceneGame.is_paused then

        -- [M] Atajo de pánico: salida inmediata al menú principal
        if key == "m" then
            SceneGame.is_paused = false
            _pauseSyncMenu("MAIN")
            if AudioManager and AudioManager.playMenuBack then AudioManager.playMenuBack() end
            SceneManager.setState(SceneGame.return_scene or "menu")
            return true
        end

        -- [UP] Navegación vertical: sube (circular)
        if key == "up" then
            SceneGame.pause_selected = ((SceneGame.pause_selected - 2 + _PAUSE_ACTIVE_COUNT) % _PAUSE_ACTIVE_COUNT) + 1
            if AudioManager and AudioManager.playImmediateSFX then AudioManager.playImmediateSFX("move", false) end
            return true
        end

        -- [DOWN] Navegación vertical: baja (circular)
        if key == "down" then
            SceneGame.pause_selected = (SceneGame.pause_selected % _PAUSE_ACTIVE_COUNT) + 1
            if AudioManager and AudioManager.playImmediateSFX then AudioManager.playImmediateSFX("move", false) end
            return true
        end

        -- [LEFT / RIGHT] Ajuste de sliders in-place (solo en sub-menús)
        if key == "left" or key == "right" then
            if SceneGame.pause_menu_state ~= "MAIN" then
                local opt = _PAUSE_ACTIVE_MENU[SceneGame.pause_selected]
                if opt and opt.key then
                    _pauseSliderAdjust(opt, key == "right" and 1 or -1)
                    if AudioManager and AudioManager.playImmediateSFX then AudioManager.playImmediateSFX("move", false) end
                end
            end
            return true
        end

        -- [RETURN / SPACE / KPENTER] Ejecutar acción del ítem seleccionado
        if key == "return" or key == "space" or key == "kpenter" then
            local opt = _PAUSE_ACTIVE_MENU[SceneGame.pause_selected]
            if opt then
                local act = opt.action
                if act == "resume" then
                    SceneGame.is_paused = false
                    _pauseSyncMenu("MAIN")
                    if AudioManager and AudioManager.playImmediateSFX then AudioManager.playImmediateSFX("rotate", false) end
                elseif act == "restart" then
                    SceneGame.is_paused = false
                    _pauseSyncMenu("MAIN")
                    SceneGame.restartMatch()
                elseif act == "menu" then
                    SceneGame.is_paused = false
                    _pauseSyncMenu("MAIN")
                    if AudioManager and AudioManager.playMenuBack then AudioManager.playMenuBack() end
                    SceneManager.setState(SceneGame.return_scene or "menu")
                elseif act == "back" then
                    _pauseSyncMenu("MAIN")
                    if AudioManager and AudioManager.playImmediateSFX then AudioManager.playImmediateSFX("rotate", false) end
                elseif act == "HANDLING" or act == "AUDIO" or act == "GRAPHICS" then
                    _pauseSyncMenu(act)
                    if AudioManager and AudioManager.playImmediateSFX then AudioManager.playImmediateSFX("hold", false) end
                end
            end
            return true
        end

        -- BLOQUEO ABSOLUTO EN PAUSA: Ningún input residual pasa al juego
        return true
    end

    -- ── LÓGICA DEL JUEGO ACTIVO ───────────────────────────────────────────
    if key == "r" then
        SceneGame.restartMatch()
        return true
    end

    if Input and Input.keypressed then
        Input.keypressed(key)
    end
end

function SceneGame.keyreleased(key)
    -- Enrutamiento directo al pipeline de juego de baja latencia
    if Input and Input.keyreleased then
        Input.keyreleased(key)
    end
end

function SceneGame.gamepadpressed(joystick, button)
    if SceneGame.match_over then
        if button == "a" or button == "start" then
            SceneGame.restartMatch()
            return true
        elseif button == "b" or button == "back" then
            SceneManager.setState(SceneGame.return_scene or "menu")
            AudioManager.playMenuBack()
            return true
        end
        return true
    end

    if button == "back" then
        SceneManager.setState(SceneGame.return_scene or "menu")
        AudioManager.playMenuBack()
        return true
    end

    if Input and Input.gamepadpressed then
        Input.gamepadpressed(joystick, button)
    end
end

function SceneGame.exit()
    SceneGame.boards = {}
    SceneGame.bots = {}
    SceneGame.match_over = false
    SceneGame.final_match_time = 0.0
    Blackbox.log("SCENE", "Game Scene exited", 0, 0)
    collectgarbage("collect")
end



return SceneGame

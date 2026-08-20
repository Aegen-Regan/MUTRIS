---@diagnostic disable: undefined-global
_G.ENGINE_VERSION = "MUTRIS v1.0.0"

local Piece = require "tetris.piece"
local Board = require "tetris.board"
local Input = require "input"
local AudioManager = require "audio_manager"
local MusicManager = require "music_manager"
local TrackManager = require "track_manager"
local TrackEditor = require "track_editor"
local GameStates = require "tetris.game_states"
local FogLayer = require "tetris.fog_layer"
local FontCache = require "tetris.font_cache"
local BloomShader = require "tetris.bloom_shader"
local SettingsManager = require "settings_manager"
local AnomalyManager = require "tetris.anomaly_manager"

_G.RestartHalo = 0
_G.Winner = nil
_G.GameOverPending = nil
_G.HitStopTimer = 0
_G.RealMatchTimer = 0
_G.TrackEnergyPunch = 0
_G.AudioBeatPulse = 0

-- Modos de juego
_G.CURRENT_GAME_MODE = "versus"
_G.IS_DEMO_MODE = false
_G.SprintBestTime = nil
_G.UltraBestScore = nil
_G.LastUltraScore = 0

_G.IsBlackoutActive = false
_G.BlackoutStrobeVisibility = 1.0

_G.SetGameState = function(state) game_state = state end

local player, bot, game_state, selected_diff = nil, nil, "menu", 1
local difficulties = { { name = "MASTER", pps = 6.0, color = {1, 0.2, 0.3} } }
local _singleton_batch = {""}

-- ⏱️ Temporizador de Inactividad en Menú (5 segundos)
local menu_inactivity_timer = 0.0

-- 🚀 Pool Estático de Proyectiles de Ataque (Zero-GC)
local projectiles = {}
for i = 1, 30 do
    projectiles[i] = {
        active = false, x = 0, y = 0, tx = 0, ty = 0, t = 0, dur = 0.45,
        power = 1, proj_type = "normal",
        trail = { {0,0}, {0,0}, {0,0}, {0,0}, {0,0}, {0,0}, {0,0}, {0,0} },
        trail_head = 1
    }
end

-- 💥 Pool de Impactos
local impacts = {}
for i = 1, 24 do
    impacts[i] = {
        active = false, x = 0, y = 0, t = 0, max_t = 0.40,
        r = 1, g = 0.8, b = 0.2, power = 1,
        sparks = {}
    }
    for s = 1, 12 do
        impacts[i].sparks[s] = { vx = 0, vy = 0, rot = 0 }
    end
end

-- 🔢 Pool de Números de Daño Flotantes
local damage_nums = {}
for i = 1, 20 do
    damage_nums[i] = {
        active = false, x = 0, y = 0, vy = 0, t = 0, max_t = 1.0,
        text = "", r = 1, g = 1, b = 1, scale = 1.5, rot = 0
    }
end

local function spawnImpact(x, y, power, proj_type)
    for i = 1, 24 do
        local imp = impacts[i]
        if not imp.active then
            imp.active = true
            imp.x, imp.y = x, y
            imp.t, imp.max_t = 0, 0.38 + power * 0.04
            imp.power = power
            if proj_type == "tspin" then imp.r, imp.g, imp.b = 0.9, 0.2, 1.0
            elseif proj_type == "tetris" then imp.r, imp.g, imp.b = 1.0, 0.85, 0.2
            elseif proj_type == "zone" then imp.r, imp.g, imp.b = 0.2, 0.95, 1.0
            else imp.r, imp.g, imp.b = 0.1, 0.8, 1.0 end

            for s = 1, 12 do
                local ang = math.random() * math.pi * 2
                local spd = math.random(80, 260) + power * 20
                imp.sparks[s].vx = math.cos(ang) * spd
                imp.sparks[s].vy = math.sin(ang) * spd - math.random(40, 100)
            end
            break
        end
    end
end

local function spawnDamageNumber(x, y, text, r, g, b)
    for i = 1, 20 do
        local dn = damage_nums[i]
        if not dn.active then
            dn.active = true
            dn.x = x
            dn.y = y - 30
            dn.vy = -65
            dn.t = 0
            dn.max_t = 1.0
            dn.text = text
            dn.r = r or 1
            dn.g = g or 1
            dn.b = b or 1
            dn.scale = 1.8
            dn.rot = (math.random() - 0.5) * 0.15
            break
        end
    end
end

_G.SpawnAttackProjectile = function(from_x, from_y, to_x, to_y, power, proj_type, label)
    for i = 1, 30 do
        local p = projectiles[i]
        if not p.active then
            p.active = true
            p.x, p.y = from_x, from_y
            p.tx, p.ty = to_x, to_y
            p.t, p.dur, p.power = 0, 0.40, power or 1
            p.proj_type = proj_type or "normal"
            p.trail_head = 1
            for tr = 1, 8 do p.trail[tr][1], p.trail[tr][2] = from_x, from_y end

            local col = (proj_type == "tspin" and {0.9, 0.2, 1.0}) or (proj_type == "tetris" and {1.0, 0.85, 0.2}) or {0.2, 0.9, 1.0}
            spawnDamageNumber(400, 250, label or ("⚔️ +" .. power .. " LINES"), col[1], col[2], col[3])
            break
        end
    end
end

local bg_spectrogram = {}
for i = 1, 32 do bg_spectrogram[i] = 0 end

local function loadAllRecords()
    if love.filesystem.getInfo("records.json") then
        local c = love.filesystem.read("records.json")
        if c then
            local pb_sp = c:match('"sprint_pb":%s*([%d%.]+)')
            if pb_sp then _G.SprintBestTime = tonumber(pb_sp) end
            local pb_ul = c:match('"ultra_pb":%s*([%d%.]+)')
            if pb_ul then _G.UltraBestScore = tonumber(pb_ul) end
        end
    end
end

local function saveSprintRecord(time_sec)
    if not _G.SprintBestTime or time_sec < _G.SprintBestTime then
        _G.SprintBestTime = time_sec
        love.filesystem.write("records.json", string.format('{\n  "sprint_pb": %.2f,\n  "ultra_pb": %d\n}', _G.SprintBestTime or 0, _G.UltraBestScore or 0))
    end
end

local function saveUltraRecord(score_pts)
    _G.LastUltraScore = score_pts
    if not _G.UltraBestScore or score_pts > _G.UltraBestScore then
        _G.UltraBestScore = score_pts
        love.filesystem.write("records.json", string.format('{\n  "sprint_pb": %.2f,\n  "ultra_pb": %d\n}', _G.SprintBestTime or 0, _G.UltraBestScore or 0))
    end
end

-- 🤖 ACTIVACIÓN DEL MODO DEMO A VELOCIDAD eSPORTS ULTRA ALTA
function StartDemoMode()
    _G.IS_DEMO_MODE = true
    _G.RestartHalo, _G.Winner, _G.GameOverPending = 1.0, nil, nil
    _G.HitStopTimer = 0
    _G.RealMatchTimer = 0

    -- Canción aleatoria en cada pelea
    if TrackManager.tracks and #TrackManager.tracks > 1 then
        TrackManager.current_track_index = math.random(1, #TrackManager.tracks)
        TrackManager.applyTrackAudioSettings()
    end

    player = Board.new(80, 50, "bot")
    bot = Board.new(480, 50, "bot")
    player.opponent, bot.opponent = bot, player

    local Bag = require "tetris.randomizers.7bag"
    player.bag, bot.bag = Bag.new(), Bag.new()

    local AIBot = require "tetris.ai_bot"
    -- ⚡ Velocidades de torneo agresivas (3.8 vs 4.2 PPS)
    player.ai = AIBot.new(player, {pps = 3.8})
    bot.ai = AIBot.new(bot, {pps = 4.2})

    player.active_piece = Piece.new(player.bag:next(), player)
    bot.active_piece = Piece.new(bot.bag:next(), bot)

    AnomalyManager.init()
    MusicManager.stop()
    MusicManager.start()
    game_state = "play"
end

function ExitDemoMode()
    if _G.IS_DEMO_MODE then
        _G.IS_DEMO_MODE = false
        game_state = "menu"
        menu_inactivity_timer = 0.0
        MusicManager.stop()
        MusicManager.start()
        AudioManager.playMenuBack()
    end
end

function love.load()
    love.window.setTitle("MUTRIS - " .. _G.ENGINE_VERSION)
    love.window.setMode(800, 600, {resizable = false, vsync = true})
    SettingsManager.init()
    AudioManager.init()
    TrackManager.init()
    FogLayer.init()
    BloomShader.init()
    AnomalyManager.init()
    loadAllRecords()

    _G.RealMatchTimer, _G.TrackEnergyPunch, _G.AudioBeatPulse = 0, 0, 0
    _G.HitStopTimer = 0
    _G.Stars = {}
    for i = 1, 150 do
        _G.Stars[i] = { x = math.random(800), y = math.random(600), s = math.random(1, 2), v = math.random(10, 40) }
    end
end

function GlobalRestart()
    _G.IS_DEMO_MODE = false
    _G.RestartHalo, _G.Winner, _G.GameOverPending = 1.0, nil, nil
    _G.HitStopTimer = 0
    _G.RealMatchTimer = 0
    local Bag = require "tetris.randomizers.7bag"

    if _G.CURRENT_GAME_MODE == "sprint" or _G.CURRENT_GAME_MODE == "ultra" or _G.CURRENT_GAME_MODE == "zen" then
        player = Board.new(280, 50, "human")
        player.bag = Bag.new()
        player.active_piece = Piece.new(player.bag:next(), player)
        bot = nil
        Input.init(player)
    else
        local d = difficulties[selected_diff]
        player = Board.new(80, 50, "human")
        bot = Board.new(480, 50, "bot")
        player.opponent, bot.opponent = bot, player
        player.bag, bot.bag = Bag.new(), Bag.new()
        local AIBot = require "tetris.ai_bot"
        bot.ai = AIBot.new(bot, {pps = d.pps})
        player.active_piece = Piece.new(player.bag:next(), player)
        bot.active_piece = Piece.new(bot.bag:next(), bot)
        Input.init(player)
        AnomalyManager.init()
    end

    MusicManager.stop()
    MusicManager.start()
    game_state = "play"
end

function love.filedropped(file)
    local path = file:getFilename()
    if path and (path:match("%.mp3$") or path:match("%.ogg$")) then
        _singleton_batch[1] = path
        TrackEditor.enterBatch(_singleton_batch)
    end
end

function love.directorydropped(path)
    local files = love.filesystem.getDirectoryItems(path)
    local batch = {}
    for _, f in ipairs(files) do
        if f:match("%.mp3$") or f:match("%.ogg$") then table.insert(batch, path .. "/" .. f) end
    end
    if #batch > 0 then TrackEditor.enterBatch(batch) end
end

function love.update(dt)
    BloomShader.update(dt)
    if _G.RestartHalo > 0 then _G.RestartHalo = math.max(0, _G.RestartHalo - dt * 2.0) end
    if _G.HitStopTimer > 0 then
        _G.HitStopTimer = math.max(0, _G.HitStopTimer - dt)
        if player then player:update(dt) end
        if bot then bot:update(dt) end
        return
    end

    local energy = _G.TrackEnergyPunch or 0
    for i = 1, #_G.Stars do
        local s = _G.Stars[i]
        s.y = s.y + s.v * dt * (1 + energy * 8)
        if s.y > 600 then s.y, s.x = 0, math.random(800) end
    end

    FogLayer.update(dt)

    if game_state == "menu" then
        menu_inactivity_timer = menu_inactivity_timer + dt
        if menu_inactivity_timer >= 5.0 then
            menu_inactivity_timer = 0.0
            StartDemoMode()
            return
        end
    end

    local song_time = MusicManager.getTime()
    local pulse = _G.AudioBeatPulse or 0
    for i = 1, 32 do
        local wave = math.sin(song_time * 6 + i * 0.4) * math.cos(song_time * 2.5 - i * 0.3)
        local target_h = math.max(10, (0.35 + wave * 0.35 + pulse * 0.3) * (80 + energy * 90))
        bg_spectrogram[i] = bg_spectrogram[i] + (target_h - bg_spectrogram[i]) * 12 * dt
    end

    for i = 1, 30 do
        local p = projectiles[i]
        if p.active then
            p.t = p.t + dt
            local prog = p.t / p.dur
            local cur_x = p.x + (p.tx - p.x) * prog
            local cur_y = p.y + (p.ty - p.y) * prog - math.sin(prog * math.pi) * 85
            
            p.trail[p.trail_head][1] = cur_x
            p.trail[p.trail_head][2] = cur_y
            p.trail_head = (p.trail_head % 8) + 1

            if p.t >= p.dur then
                p.active = false
                spawnImpact(p.tx, p.ty, p.power, p.proj_type)
            end
        end
    end

    for i = 1, 24 do
        local imp = impacts[i]
        if imp.active then
            imp.t = imp.t + dt
            for s = 1, 12 do
                local sp = imp.sparks[s]
                sp.vy = sp.vy + 420 * dt
                sp.vx = sp.vx * (1.0 - 1.2 * dt)
            end
            if imp.t >= imp.max_t then imp.active = false end
        end
    end

    for i = 1, 20 do
        local dn = damage_nums[i]
        if dn.active then
            dn.t = dn.t + dt
            dn.y = dn.y + dn.vy * dt
            dn.vy = dn.vy + 50 * dt
            local p = dn.t / dn.max_t
            dn.scale = 1.0 + math.sin((1.0 - p) * 12.0) * math.exp(-3.0 * p) * 0.8
            if dn.t >= dn.max_t then dn.active = false end
        end
    end

    if game_state == "editor" then
        TrackEditor.update(dt)
        return
    end

    if game_state == "play" then
        _G.RealMatchTimer = (_G.RealMatchTimer or 0) + dt
        if not _G.IS_DEMO_MODE then Input.update(dt) end

        local player_danger = (player and player.danger_level) or 0
        local bot_danger = (bot and bot.danger_level) or 0
        AudioManager.update(dt, { danger_level = math.max(player_danger, bot_danger), drop_intensity = 0 })
        MusicManager.update(dt)
        
        if _G.CURRENT_GAME_MODE == "versus" or _G.CURRENT_GAME_MODE == "gauntlet" or _G.IS_DEMO_MODE then
            AnomalyManager.update(dt, player, bot)
        end

        if _G.IS_DEMO_MODE then
            if (player and player.is_dying and player.death_timer <= 0) or
               (bot and bot.is_dying and bot.death_timer <= 0) then
                StartDemoMode()
                return
            end
        end

        if not _G.IS_DEMO_MODE then
            if _G.CURRENT_GAME_MODE == "sprint" and player and player.lines_cleared_total >= 40 then
                saveSprintRecord(_G.RealMatchTimer)
                AudioManager.playVoiceAnnounce("victory")
                game_state = "over"
                return
            end

            if _G.CURRENT_GAME_MODE == "ultra" and _G.RealMatchTimer >= 120.0 then
                saveUltraRecord(player and player.score or 0)
                AudioManager.playVoiceAnnounce("victory")
                game_state = "over"
                return
            end
        end

        if _G.GameOverPending then
            local loser = _G.GameOverPending
            _G.GameOverPending = nil
            if loser == "human" and player and not player.is_dying then
                player:triggerDeath()
                _G.Winner = "BOT"
            elseif loser == "bot" and bot and not bot.is_dying then
                bot:triggerDeath()
                _G.Winner = "PLAYER"
            end
        end

        if not _G.IS_DEMO_MODE then
            if player and player.is_dying and player.death_timer <= 0 then
                game_state = "over"
            elseif bot and bot.is_dying and bot.death_timer <= 0 then
                game_state = "over"
            end
        end

        if game_state == "play" and player and player.active_piece and not player.is_dying then
            player:update(dt)
            if _G.IS_DEMO_MODE and player.ai then player.ai:update(dt) end
            player.active_piece:update(dt, _G.IS_DEMO_MODE and 0.8 or Input.getSoftDropFactor())
            if player.active_piece.locked then
                require("tetris.garbage_manager").pushToGrid(player)
                player.active_piece = Piece.new(player.bag:next(), player)
                if not player.is_zone_active and not player.active_piece:canMove(player.active_piece.x, player.active_piece.y, 1) then
                    player:triggerDeath()
                    _G.Winner = "BOT"
                end
            end
        elseif player and player.is_dying then
            player:update(dt)
        end

        if game_state == "play" and bot and bot.active_piece and not bot.is_dying then
            bot:update(dt)
            if bot.ai then bot.ai:update(dt) end
            bot.active_piece:update(dt, 0.8)
            if bot.active_piece.locked then
                require("tetris.garbage_manager").pushToGrid(bot)
                bot.active_piece = Piece.new(bot.bag:next(), bot)
                if not bot.is_zone_active and not bot.active_piece:canMove(bot.active_piece.x, bot.active_piece.y, 1) then
                    bot:triggerDeath()
                    _G.Winner = "PLAYER"
                end
            end
        elseif bot and bot.is_dying then
            bot:update(dt)
        end
    end
end

function love.draw()
    BloomShader.beginDraw()
    local pulse = _G.AudioBeatPulse or 0
    love.graphics.clear(0.002, 0.002, 0.008)

    FogLayer.draw()

    love.graphics.push("all")
    love.graphics.setBlendMode("add")
    for i = 1, 32 do
        local bar_x = 40 + (i - 1) * 23
        local bar_h = bg_spectrogram[i]
        love.graphics.setColor(0.1, 0.6, 1.0, 0.08 + pulse * 0.08)
        love.graphics.rectangle("fill", bar_x, 560 - bar_h, 18, bar_h, 2)
    end
    love.graphics.pop()

    for i = 1, #_G.Stars do
        local s = _G.Stars[i]
        love.graphics.setColor(0.5, 0.7, 1.0, 0.2 + pulse * 0.2)
        love.graphics.circle("fill", s.x, s.y, s.s)
    end

    if game_state == "menu" then
        GameStates.drawMenu(love.timer.getTime(), selected_diff, difficulties)
    elseif game_state == "settings" then
        GameStates.drawSettings(love.timer.getTime())
    elseif game_state == "editor" then
        TrackEditor.draw()
    elseif game_state == "play" then
        if player then
            player:draw()
            if player.active_piece and not player.is_dying then
                player.active_piece:draw(player.x, player.y)
            end
        end
        if bot then
            bot:draw()
            if bot.active_piece and not bot.is_dying then
                bot.active_piece:draw(bot.x, bot.y)
            end
        end

        love.graphics.push("all")
        love.graphics.setBlendMode("add")
        for i = 1, 30 do
            local p = projectiles[i]
            if p.active then
                local prog = p.t / p.dur
                local cur_x = p.x + (p.tx - p.x) * prog
                local cur_y = p.y + (p.ty - p.y) * prog - math.sin(prog * math.pi) * 85
                
                for tr = 1, 8 do
                    local trail_idx = ((p.trail_head - tr - 1) % 8) + 1
                    local tx, ty = p.trail[trail_idx][1], p.trail[trail_idx][2]
                    local alpha_tr = (1.0 - tr / 8) * (1.0 - prog) * 0.7
                    if p.proj_type == "tspin" then love.graphics.setColor(0.9, 0.2, 1.0, alpha_tr)
                    elseif p.proj_type == "tetris" then love.graphics.setColor(1.0, 0.8, 0.2, alpha_tr)
                    else love.graphics.setColor(0.1, 0.85, 1.0, alpha_tr) end
                    love.graphics.circle("fill", tx, ty, (8 - tr) * 0.9)
                end

                if p.proj_type == "tspin" then
                    love.graphics.setColor(0.9, 0.2, 1.0, 0.95)
                    love.graphics.circle("fill", cur_x, cur_y, 7 + p.power * 1.5)
                elseif p.proj_type == "tetris" then
                    love.graphics.setColor(1.0, 0.85, 0.2, 0.95)
                    love.graphics.circle("fill", cur_x, cur_y, 8 + p.power * 1.8)
                    local orb_ang = prog * 24
                    local ox1 = cur_x + math.cos(orb_ang) * 14
                    local oy1 = cur_y + math.sin(orb_ang) * 14
                    love.graphics.setColor(1, 1, 1, 0.9)
                    love.graphics.circle("fill", ox1, oy1, 3)
                else
                    love.graphics.setColor(0.2, 0.9, 1.0, 0.95)
                    love.graphics.circle("fill", cur_x, cur_y, 5 + p.power * 1.2)
                end
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.circle("fill", cur_x, cur_y, 3)
            end
        end

        for i = 1, 24 do
            local imp = impacts[i]
            if imp.active then
                local prog = imp.t / imp.max_t
                local alpha = (1.0 - prog)
                love.graphics.setLineWidth(2)
                love.graphics.setColor(imp.r, imp.g, imp.b, alpha * 0.8)
                love.graphics.circle("line", imp.x, imp.y, prog * (40 + imp.power * 8))
                
                for s = 1, 12 do
                    local sp = imp.sparks[s]
                    local sx = imp.x + sp.vx * imp.t
                    local sy = imp.y + sp.vy * imp.t
                    love.graphics.setColor(imp.r, imp.g, imp.b, alpha * 0.9)
                    love.graphics.rectangle("fill", sx - 2, sy - 2, 4, 4)
                    love.graphics.setColor(1, 1, 1, alpha)
                    love.graphics.rectangle("fill", sx - 1, sy - 1, 2, 2)
                end
            end
        end

        for i = 1, 20 do
            local dn = damage_nums[i]
            if dn.active then
                local alpha = (1.0 - dn.t / dn.max_t)
                love.graphics.push()
                love.graphics.translate(dn.x, dn.y)
                love.graphics.scale(dn.scale, dn.scale)
                love.graphics.rotate(dn.rot)

                love.graphics.setFont(FontCache.get(20))
                local tw = FontCache.get(20):getWidth(dn.text)
                local bw = tw + 24

                love.graphics.setColor(0.01, 0.02, 0.05, 0.85 * alpha)
                love.graphics.rectangle("fill", -bw / 2, -15, bw, 30, 4)
                love.graphics.setLineWidth(2)
                love.graphics.setColor(dn.r, dn.g, dn.b, 0.9 * alpha)
                love.graphics.rectangle("line", -bw / 2, -15, bw, 30, 4)

                love.graphics.setColor(0, 0, 0, 0.95 * alpha)
                love.graphics.printf(dn.text, -120 + 2, -10 + 2, 240, "center")

                love.graphics.setColor(dn.r, dn.g, dn.b, alpha)
                love.graphics.printf(dn.text, -120, -10, 240, "center")
                love.graphics.pop()
            end
        end
        love.graphics.pop()

        if _G.IS_DEMO_MODE then
            local time = love.timer.getTime()
            local alpha_banner = 0.7 + math.sin(time * 8) * 0.3
            love.graphics.setFont(FontCache.get(12))
            love.graphics.setColor(1.0, 0.85, 0.2, alpha_banner)
            love.graphics.printf("► ATTRACT DEMO MODE (AI VS AI)  -  PRESS SPACE/ESC TO RETURN ◄", 0, 16, 800, "center")
            require("tetris.hud_center").draw(player, bot)
            AnomalyManager.draw(player, bot)
        elseif _G.CURRENT_GAME_MODE == "versus" or _G.CURRENT_GAME_MODE == "gauntlet" then
            AnomalyManager.draw(player, bot)
            require("tetris.hud_center").draw(player, bot)
        elseif _G.CURRENT_GAME_MODE == "sprint" then
            local remaining = math.max(0, 40 - ((player and player.lines_cleared_total) or 0))
            love.graphics.setFont(FontCache.get(13))
            love.graphics.setColor(0, 0.9, 1, 0.95)
            love.graphics.printf("LINES LEFT: " .. remaining, 0, 18, 800, "center")
        elseif _G.CURRENT_GAME_MODE == "ultra" then
            local time_left = math.max(0, 120.0 - (_G.RealMatchTimer or 0))
            love.graphics.setFont(FontCache.get(13))
            love.graphics.setColor(1.0, 0.85, 0.2, 0.95)
            love.graphics.printf(string.format("TIME: %.1fs  |  SCORE: %d", time_left, player and player.score or 0), 0, 18, 800, "center")
        elseif _G.CURRENT_GAME_MODE == "zen" then
            love.graphics.setFont(FontCache.get(12))
            love.graphics.setColor(0.4, 0.9, 1.0, 0.75 + pulse * 0.2)
            love.graphics.printf("ZEN INFINITE FLOW  -  LINES: " .. tostring(player and player.lines_cleared_total or 0), 0, 18, 800, "center")
        end

        local success, Telemetry = pcall(require, "tetris.telemetry")
        if success then Telemetry.draw(player, bot) end
    elseif game_state == "over" then
        GameStates.drawGameOver()
    end

    love.graphics.setFont(FontCache.get(10))
    love.graphics.setColor(1, 1, 1, 0.35 + pulse * 0.15)
    love.graphics.print(_G.ENGINE_VERSION, 10, 582)

    if _G.RestartHalo > 0 then
        love.graphics.setColor(1, 1, 1, _G.RestartHalo * 0.5)
        love.graphics.rectangle("fill", 0, 0, 800, 600)
    end

    local is_any_zone = (player and player.is_zone_active) or (bot and bot.is_zone_active)
    BloomShader.endDraw(is_any_zone)
end

function love.mousemoved(x, y, dx, dy) end

function love.mousepressed(x, y, button)
    if _G.IS_DEMO_MODE then
        ExitDemoMode()
        return
    end

    menu_inactivity_timer = 0.0

    if game_state == "editor" then
        TrackEditor.mousepressed(x, y, button)
    elseif game_state == "settings" and button == 1 then
        GameStates.handleSettingsMouse(x, y)
    elseif game_state == "menu" and button == 1 then
        local modes_keys = { "versus", "sprint", "ultra", "zen", "gauntlet" }
        for idx, m_id in ipairs(modes_keys) do
            local by = 175 + (idx - 1) * 52
            if x >= 220 and x <= 580 and y >= by and y <= by + 44 then
                _G.CURRENT_GAME_MODE = m_id
                AudioManager.playMenuClick()
                return
            end
        end

        if x >= 275 and x <= 525 and y >= 450 and y <= 485 then
            AudioManager.playMenuClick()
            game_state = "settings"
            return
        end
        if x >= 275 and x <= 525 and y >= 498 and y <= 542 then
            AudioManager.playMenuClick()
            GlobalRestart()
            return
        end
    end
end

function love.mousereleased(x, y, button)
    if game_state == "settings" then SettingsManager.save() end
end

function love.keypressed(key)
    if _G.IS_DEMO_MODE then
        ExitDemoMode()
        return
    end

    menu_inactivity_timer = 0.0

    if key == "escape" then
        if game_state == "settings" then
            AudioManager.playMenuBack()
            SettingsManager.save()
            game_state = "menu"
        else
            AudioManager.playMenuClick()
            game_state = "settings"
        end
        return
    end

    if key == "m" and game_state == "settings" then
        SettingsManager.toggleMute()
        local is_muted = SettingsManager.settings.mute_all and SettingsManager.settings.mute_all >= 0.5
        AudioManager.playMuteToggle(is_muted)
        SettingsManager.save()
        return
    end

    if game_state == "editor" then
        TrackEditor.keypressed(key)
    elseif game_state == "settings" then
        if key == "return" then
            AudioManager.playMenuBack()
            SettingsManager.save()
            game_state = "menu"
        end
    elseif game_state == "menu" then
        local modes_keys = { "versus", "sprint", "ultra", "zen", "gauntlet" }
        local cur_idx = 1
        for i, mk in ipairs(modes_keys) do if mk == _G.CURRENT_GAME_MODE then cur_idx = i break end end

        if key == "up" then
            cur_idx = math.max(1, cur_idx - 1)
            _G.CURRENT_GAME_MODE = modes_keys[cur_idx]
            AudioManager.playMenuHover()
        elseif key == "down" then
            cur_idx = math.min(#modes_keys, cur_idx + 1)
            _G.CURRENT_GAME_MODE = modes_keys[cur_idx]
            AudioManager.playMenuHover()
        elseif key == "left" then TrackManager.prevTrack()
        elseif key == "right" then TrackManager.nextTrack()
        elseif key == "return" or key == "space" then GlobalRestart() end
    elseif game_state == "play" then
        Input.keypressed(key)
    elseif game_state == "over" and (key == "r" or key == "space" or key == "return") then
        GlobalRestart()
    end
end

function love.gamepadpressed(joystick, button)
    if _G.IS_DEMO_MODE then
        ExitDemoMode()
        return
    end

    menu_inactivity_timer = 0.0

    if game_state == "play" then
        Input.gamepadpressed(joystick, button)
    elseif game_state == "settings" then
        if button == "b" or button == "start" then
            AudioManager.playMenuBack()
            SettingsManager.save()
            game_state = "menu"
        end
    elseif game_state == "menu" or game_state == "over" then
        if button == "start" or button == "a" then GlobalRestart() end
    end
end

function love.joystickadded()
    if Input and Input._refreshJoystickCache then Input._refreshJoystickCache() end
end

function love.joystickremoved()
    if Input and Input._refreshJoystickCache then Input._refreshJoystickCache() end
end
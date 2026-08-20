---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: DDA HEURISTIC BOT ENGINE 2.0 (FASE 13)
-- Arquitectura: Zero-GC / Buffer Plano / Anti-Stall / Radar Downstacking
-- ============================================================================
local AIBot = {}

local SRS = require "tetris.rotation_systems.srs"
local MetaBalancer = require "core.meta_balancer"
local Blackbox = require "core.blackbox"

_G.AI_ADAPTIVE_PROFILE = {
    player_avg_pps = 1.20,
    ai_target_pps  = 1.45,
    player_wins    = 0,
    bot_wins       = 0,
    total_matches  = 0
}

AIBot.board = nil
AIBot.base_pps = 1.45
AIBot.pps = 1.45
AIBot.step_timer = 0.0
AIBot.has_target = false
AIBot.target_x = 4
AIBot.target_rot = 1
AIBot.hole_seeking_col = 5

local _sim_grid = {}
for r = 1, 40 do
    _sim_grid[r] = {}
    for c = 1, 10 do _sim_grid[r][c] = 0 end
end

local function serializeJSON(tbl)
    local s = "{\n"
    for k, v in pairs(tbl) do
        if type(v) == "number" then
            s = s .. string.format('  "%s": %.4f,\n', k, v)
        end
    end
    s = s:sub(1, -3) .. "\n}"
    return s
end

local function parseJSON(str)
    local data = {}
    for k, v in str:gmatch('"([%w_]+)":%s*([%-%d%.]+)') do
        data[k] = tonumber(v)
    end
    return data
end

function AIBot.loadProfile()
    if love.filesystem.getInfo("saves/ai_profile.json") then
        local contents = love.filesystem.read("saves/ai_profile.json")
        if contents then
            local loaded = parseJSON(contents)
            for k, v in pairs(loaded) do
                _G.AI_ADAPTIVE_PROFILE[k] = v
            end
        end
    elseif love.filesystem.getInfo("ai_profile.json") then
        local contents = love.filesystem.read("ai_profile.json")
        if contents then
            local loaded = parseJSON(contents)
            for k, v in pairs(loaded) do
                _G.AI_ADAPTIVE_PROFILE[k] = v
            end
        end
    end
    AIBot.base_pps = _G.AI_ADAPTIVE_PROFILE.ai_target_pps or 1.45
    AIBot.pps = AIBot.base_pps
end

function AIBot.saveProfile()
    if not love.filesystem.getInfo("saves") then
        love.filesystem.createDirectory("saves")
    end
    love.filesystem.write("saves/ai_profile.json", serializeJSON(_G.AI_ADAPTIVE_PROFILE))
end

function AIBot.init(self_or_board, maybe_board)
    local board = (type(self_or_board) == "table" and self_or_board.grid) and self_or_board or maybe_board
    AIBot.board = board
    if board then board.ai = AIBot end

    AIBot.loadProfile()
    AIBot.has_target = false
    AIBot.step_timer = 0.0
end

local function findGarbageHoleColumn(board)
    for r = 40, 21, -1 do
        local hole_col = 0
        local solid_count = 0
        for c = 1, 10 do
            if board.grid[r][c] == 8 then
                solid_count = solid_count + 1
            elseif board.grid[r][c] == 0 then
                hole_col = c
            end
        end
        if solid_count >= 8 and hole_col > 0 then
            return hole_col
        end
    end
    return 10
end

local function evaluatePlacement(board, piece, target_rot, target_x)
    local shape = piece.shape[target_rot]
    if not shape then return -999999 end

    for r = 1, #shape do
        for c = 1, #shape[r] do
            if shape[r][c] ~= 0 then
                local tx = target_x + c - 1
                if tx < 1 or tx > 10 then return -999999 end
                if board.grid[21][tx] ~= 0 then return -999999 end
            end
        end
    end

    local drop_y = 21
    while true do
        local collision = false
        for r = 1, #shape do
            for c = 1, #shape[r] do
                if shape[r][c] ~= 0 then
                    local tx = target_x + c - 1
                    local ty = drop_y + r
                    if ty > 40 or (ty >= 1 and board.grid[ty][tx] ~= 0) then
                        collision = true
                        break
                    end
                end
            end
            if collision then break end
        end
        if collision then break end
        drop_y = drop_y + 1
    end

    for r = 1, 40 do
        for c = 1, 10 do _sim_grid[r][c] = board.grid[r][c] end
    end

    for r = 1, #shape do
        for c = 1, #shape[r] do
            if shape[r][c] ~= 0 then
                local tx = target_x + c - 1
                local ty = drop_y + r - 1
                if ty >= 1 and ty <= 40 and tx >= 1 and tx <= 10 then
                    _sim_grid[ty][tx] = piece.id
                end
            end
        end
    end

    local lines_cleared = 0
    for r = 40, 21, -1 do
        local full = true
        for c = 1, 10 do
            if _sim_grid[r][c] == 0 then full = false break end
        end
        if full then lines_cleared = lines_cleared + 1 end
    end

    local agg_height = 0
    local holes = 0
    local bumpiness = 0
    local prev_h = 0

    for c = 1, 10 do
        local h = 0
        local found_block = false
        for r = 21, 40 do
            if _sim_grid[r][c] ~= 0 then
                if not found_block then
                    h = 41 - r
                    found_block = true
                end
            elseif found_block then
                holes = holes + 1
            end
        end
        agg_height = agg_height + h
        if c > 1 then bumpiness = bumpiness + math.abs(h - prev_h) end
        prev_h = h
    end

    local hole_col = AIBot.hole_seeking_col or 10
    local hole_penalty = 0
    if _sim_grid[40][hole_col] ~= 0 and lines_cleared == 0 then
        hole_penalty = 120
    end

    local score = (-0.51 * agg_height) + (0.85 * lines_cleared * lines_cleared) - (0.95 * holes * 12) - (0.28 * bumpiness) - hole_penalty
    return score
end

function AIBot.findBestMove(board)
    if not board or not board.active_piece then return end
    local p = board.active_piece
    AIBot.hole_seeking_col = findGarbageHoleColumn(board)

    local best_score = -9999999
    local best_rot = p.rotation
    local best_x = p.x

    local max_rot = (p.shape and #p.shape) or 4
    for rot = 1, max_rot do
        for x = -2, 10 do
            local score = evaluatePlacement(board, p, rot, x)
            if score > best_score then
                best_score = score
                best_rot = rot
                best_x = x
            end
        end
    end

    AIBot.target_rot = best_rot
    AIBot.target_x = best_x
    AIBot.has_target = true
end

-- ⚡ BUCLE ANTI-BLOQUEO (Desatasca y fuerza el Hard Drop cuando el techo está saturado)
function AIBot.update(self_or_dt, maybe_dt)
    local dt = (type(self_or_dt) == "number") and self_or_dt or maybe_dt
    local board = AIBot.board
    if not board or board.is_dying or not board.active_piece then return end

    local p = board.active_piece
    if p.locked then
        AIBot.has_target = false
        return
    end

    local punch = _G.TrackEnergyPunch or 0
    AIBot.base_pps = _G.AI_ADAPTIVE_PROFILE.ai_target_pps or 1.45
    AIBot.pps = AIBot.base_pps + (punch * 0.40)

    if not AIBot.has_target then
        AIBot.findBestMove(board)
    end

    local step_interval = 1.0 / math.max(0.5, AIBot.pps * 4.0)
    AIBot.step_timer = AIBot.step_timer + dt

    while AIBot.step_timer >= step_interval do
        AIBot.step_timer = AIBot.step_timer - step_interval

        -- 1. Orientación con Fallback Anti-Atasco
        if p.rotation ~= AIBot.target_rot then
            local dir = (AIBot.target_rot > p.rotation) and 1 or -1
            if not p:rotate(dir) then
                -- Si no puede rotar por falta de espacio en el techo, acepta la rotación actual
                AIBot.target_rot = p.rotation
            else
                return
            end
        end

        -- 2. Alineación Horizontal con Fallback Anti-Atasco
        if p.x < AIBot.target_x then
            if not p:move(1, 0) then
                AIBot.target_x = p.x -- Si está bloqueado por bloques altos, se adapta a la X actual
            else
                return
            end
        elseif p.x > AIBot.target_x then
            if not p:move(-1, 0) then
                AIBot.target_x = p.x
            else
                return
            end
        end

        -- 3. Hard Drop garantizado (Dispara la muerte por desborde si el techo fue alcanzado)
        local startY = p.y
        while p:move(0, 1, true) do end
        local endY = p.y
        board:spawnTrail(p.x, startY, endY, p.id, p.shape[p.rotation])
        p:lock()
        AIBot.has_target = false
        break
    end
end

function AIBot.registerMatchOutcome(human_won, player_pps)
    local prof = _G.AI_ADAPTIVE_PROFILE
    prof.total_matches = (prof.total_matches or 0) + 1
    if human_won then
        prof.player_wins = (prof.player_wins or 0) + 1
    else
        prof.bot_wins = (prof.bot_wins or 0) + 1
    end

    local valid_player_pps = math.max(0.5, math.min(5.0, player_pps or 1.2))
    prof.player_avg_pps = (prof.player_avg_pps * 0.70) + (valid_player_pps * 0.30)
    prof.ai_target_pps = math.max(0.9, math.min(4.5, prof.player_avg_pps * 1.10))

    AIBot.base_pps = prof.ai_target_pps
    AIBot.saveProfile()
end

return AIBot
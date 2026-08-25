-- ================================================================
-- FILE: tetris/ai_bot.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: DDA HEURISTIC BOT ENGINE 3.0 (INSTANTIABLE)
-- Fully decoupled for multi-bot duels and boss fights
-- ============================================================================
local AIBot = {}
AIBot.__index = AIBot

local SRS          = require "tetris.rotation_systems.srs"
local MetaBalancer = require "core.meta_balancer"
local Blackbox     = require "core.blackbox"
local EditorConfig = require "core.editor_config"

_G.AI_ADAPTIVE_PROFILE = _G.AI_ADAPTIVE_PROFILE or {
    player_avg_pps = 1.20,
    ai_target_pps  = 1.45,
    player_wins    = 0,
    bot_wins       = 0,
    total_matches  = 0
}

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

function AIBot.loadGlobalProfile()
    if love.filesystem.getInfo("saves/ai_profile.json") then
        local contents = love.filesystem.read("saves/ai_profile.json")
        if contents then
            local loaded = parseJSON(contents)
            for k, v in pairs(loaded) do
                _G.AI_ADAPTIVE_PROFILE[k] = v
            end
        end
    end
end

function AIBot.saveGlobalProfile()
    if not love.filesystem.getInfo("saves") then
        love.filesystem.createDirectory("saves")
    end
    love.filesystem.write("saves/ai_profile.json", serializeJSON(_G.AI_ADAPTIVE_PROFILE))
end

function AIBot.new(board, profile_name)
    local self = setmetatable({}, AIBot)
    self.board = board
    self.board.ai = self

    self.profile_name = profile_name or "normal"
    local config = EditorConfig.ai_profiles[self.profile_name] or EditorConfig.ai_profiles["normal"]
    
    self.base_pps = config.target_pps or _G.AI_ADAPTIVE_PROFILE.ai_target_pps or 1.45
    self.pps = self.base_pps
    self.error_rate = config.error_rate or 0.05

    self.step_timer = 0.0
    self.has_target = false
    self.target_x = math.floor(board.cols / 2)
    self.target_rot = 1
    self.hole_seeking_col = math.floor(board.cols / 2)
    
    self.emote_cooldown = 0.0
    self.EMOTE_INTERVAL = 3.5

    -- Dedicated sim grid for this instance to avoid race conditions in multi-bot
    self._sim_grid = {}
    for r = 1, board.rows do
        self._sim_grid[r] = {}
        for c = 1, board.cols do self._sim_grid[r][c] = 0 end
    end
    
    return self
end

function AIBot:findGarbageHoleColumn()
    for r = self.board.rows, 1, -1 do
        local hole_col = 0
        local solid_count = 0
        for c = 1, self.board.cols do
            if self.board.grid[r][c] == 8 then
                solid_count = solid_count + 1
            elseif self.board.grid[r][c] == 0 then
                hole_col = c
            end
        end
        if solid_count >= (self.board.cols - 2) and hole_col > 0 then
            return hole_col
        end
    end
    return math.floor(self.board.cols / 2)
end

function AIBot:evaluatePlacement(piece, target_rot, target_x)
    local shape = piece.shape[target_rot]
    if not shape then return -999999 end

    local b_rows = self.board.rows
    local b_cols = self.board.cols
    local spawn_r = self.board.visible_rows + 1

    for r = 1, #shape do
        for c = 1, #shape[r] do
            if shape[r][c] ~= 0 then
                local tx = target_x + c - 1
                local ty = spawn_r + r - 1
                if tx < 1 or tx > b_cols then return -999999 end
                if ty >= 1 and ty <= b_rows and self.board.grid[ty][tx] ~= 0 then return -999999 end
            end
        end
    end

    local drop_y = spawn_r
    while true do
        local collision = false
        for r = 1, #shape do
            for c = 1, #shape[r] do
                if shape[r][c] ~= 0 then
                    local tx = target_x + c - 1
                    local ty = drop_y + r
                    if ty > b_rows or (ty >= 1 and self.board.grid[ty][tx] ~= 0) then
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

    for r = 1, b_rows do
        for c = 1, b_cols do self._sim_grid[r][c] = self.board.grid[r][c] end
    end

    for r = 1, #shape do
        for c = 1, #shape[r] do
            if shape[r][c] ~= 0 then
                local tx = target_x + c - 1
                local ty = drop_y + r - 1
                if ty >= 1 and ty <= b_rows and tx >= 1 and tx <= b_cols then
                    self._sim_grid[ty][tx] = piece.id
                end
            end
        end
    end

    local lines_cleared = 0
    for r = b_rows, 1, -1 do
        local full = true
        for c = 1, b_cols do
            if self._sim_grid[r][c] == 0 then full = false break end
        end
        if full then lines_cleared = lines_cleared + 1 end
    end

    local agg_height = 0
    local holes = 0
    local bumpiness = 0
    local prev_h = 0
    local top_out = false

    for c = 1, b_cols do
        local h = 0
        local found_block = false
        for r = 1, b_rows do
            if self._sim_grid[r][c] ~= 0 then
                if r == 1 then top_out = true end
                if not found_block then
                    h = (b_rows + 1) - r
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

    if top_out then return -999999 end

    local hole_col = self.hole_seeking_col or b_cols
    local hole_penalty = 0
    if self._sim_grid[b_rows][hole_col] ~= 0 and lines_cleared == 0 then
        hole_penalty = 120
    end

    local score = (-0.51 * agg_height) + (0.85 * lines_cleared * lines_cleared) - (0.95 * holes * 12) - (0.28 * bumpiness) - hole_penalty
    
    -- Introduce error based on profile
    if love.math.random() < self.error_rate then
        score = score - love.math.random(50, 200)
    end
    
    return score
end

function AIBot:findBestMove()
    if not self.board or not self.board.active_piece then return end
    local p = self.board.active_piece
    self.hole_seeking_col = self:findGarbageHoleColumn()

    local best_score = -9999999
    local best_rot = p.rotation
    local best_x = p.x

    local max_rot = (p.shape and #p.shape) or 4
    for rot = 1, max_rot do
        for x = -2, self.board.cols do
            local score = self:evaluatePlacement(p, rot, x)
            if score > best_score then
                best_score = score
                best_rot = rot
                best_x = x
            end
        end
    end

    self.target_rot = best_rot
    self.target_x = best_x
    self.has_target = true
end

function AIBot:update(dt)
    if not self.board or self.board.is_dying or not self.board.active_piece then return end

    local p = self.board.active_piece
    if p.locked then
        self.has_target = false
        return
    end

    local punch = _G.TrackEnergyPunch or 0
    self.pps = self.base_pps + (punch * 0.40)

    if not self.has_target then
        self:findBestMove()
    end

    local step_interval = 1.0 / math.max(0.5, self.pps * 4.0)
    
    if self.board.is_boss then
        step_interval = step_interval * 1.85 -- Slower, deliberate steps
    end

    self.step_timer = self.step_timer + dt

    while self.step_timer >= step_interval do
        self.step_timer = self.step_timer - step_interval

        if p.rotation ~= self.target_rot then
            local dir = (self.target_rot > p.rotation) and 1 or -1
            if not p:rotate(dir) then
                self.target_rot = p.rotation
            else
                return
            end
        end

        if p.x < self.target_x then
            if not p:move(1, 0) then
                self.target_x = p.x
            else
                return
            end
        elseif p.x > self.target_x then
            if not p:move(-1, 0) then
                self.target_x = p.x
            else
                return
            end
        end

        local startY = p.y
        while p:move(0, 1, true) do end
        local endY = p.y
        self.board:spawnTrail(p.x, startY, endY, p.id, p.shape[p.rotation])
        p:lock()
        self.has_target = false
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

    AIBot.saveGlobalProfile()
end

function AIBot:updateEmoteLogic(dt, opponent_board, emote_system)
    if self.emote_cooldown > 0 then
        self.emote_cooldown = self.emote_cooldown - dt
        return
    end

    if not self.board or not opponent_board then return end
    local my_height = self.board:getStackHeight()
    local opp_height = opponent_board:getStackHeight()
    
    local emote_x = self.board.x + (self.board.cols * 12)
    local emote_y = self.board.y + 40 + love.math.random(-20, 20)

    if opp_height >= math.floor(opponent_board.rows * 0.7) and my_height < math.floor(self.board.rows * 0.4) then
        emote_system:triggerPreset("BM_WINNING", emote_x, emote_y, 1.0, 0.25, 0.25)
        self.emote_cooldown = 4.5
        return
    end

    if my_height >= math.floor(self.board.rows * 0.75) then
        emote_system:triggerPreset("PANIC", emote_x, emote_y, 1.0, 0.85, 0.2)
        self.emote_cooldown = 3.5
        return
    end
end

function AIBot:onGarbageSent(lines, emote_system)
    if lines >= 4 and self.emote_cooldown <= 0 then
        local emote_x = self.board.x + (self.board.cols * 12)
        local emote_y = self.board.y + 35
        emote_system:triggerPreset("ATTACK_SPIKE", emote_x, emote_y, 0.2, 0.9, 1.0)
        self.emote_cooldown = 3.5
    end
end

return AIBot
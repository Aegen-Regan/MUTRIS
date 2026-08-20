---@diagnostic disable: undefined-global
local AIBot = {}
AIBot.__index = AIBot

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  🧠 SISTEMA DE PERFIL ADAPTATIVO PERSISTENTE (ai_profile.json)     ║
-- ╚══════════════════════════════════════════════════════════════════════╝
local PROFILE_FILE = "ai_profile.json"

local function loadAdaptiveProfile()
    local profile = {
        player_avg_pps = 1.30,
        ai_target_pps = 1.45,
        player_wins = 0,
        bot_wins = 0,
        player_streak = 0,
        bot_streak = 0,
        matches_played = 0
    }
    if love.filesystem.getInfo(PROFILE_FILE) then
        local content = love.filesystem.read(PROFILE_FILE)
        if content then
            for k, v in content:gmatch('"([%w_]+)":%s*([%d%.]+)') do
                profile[k] = tonumber(v)
            end
        end
    end
    return profile
end

local function saveAdaptiveProfile(p)
    local json = string.format(
        '{\n  "player_avg_pps": %.2f,\n  "ai_target_pps": %.2f,\n  "player_wins": %d,\n  "bot_wins": %d,\n  "player_streak": %d,\n  "bot_streak": %d,\n  "matches_played": %d\n}',
        p.player_avg_pps, p.ai_target_pps, p.player_wins, p.bot_wins, p.player_streak, p.bot_streak, p.matches_played
    )
    love.filesystem.write(PROFILE_FILE, json)
end

function AIBot.recordMatch(winner, player_pps, match_duration)
    local p = loadAdaptiveProfile()
    p.matches_played = p.matches_played + 1

    -- Si el PPS de esa partida fue muy bajo por morir de golpe, toma el histórico
    local valid_pps = (player_pps and player_pps > 0.3) and player_pps or p.player_avg_pps
    p.player_avg_pps = math.max(0.6, (p.player_avg_pps * 0.70) + (valid_pps * 0.30))

    if winner == "PLAYER" then
        p.player_wins = p.player_wins + 1
        p.player_streak = p.player_streak + 1
        p.bot_streak = 0
        -- El jugador ganó: la IA sube su velocidad para la próxima
        local boost = 0.15 + (math.min(p.player_streak, 5) * 0.05)
        p.ai_target_pps = p.player_avg_pps + boost
    else
        p.bot_wins = p.bot_wins + 1
        p.bot_streak = p.bot_streak + 1
        p.player_streak = 0
        -- El bot ganó: si lleva racha, afloja un poco
        if p.bot_streak >= 2 then
            p.ai_target_pps = math.max(0.7, p.player_avg_pps + 0.05)
        else
            p.ai_target_pps = p.player_avg_pps + 0.12
        end
    end

    -- Límite de velocidad
    p.ai_target_pps = math.max(0.8, math.min(6.0, p.ai_target_pps))
    saveAdaptiveProfile(p)
end

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  🎛️  PANEL DE CONTROL DE IA MASTER (HEURÍSTICA DE SUPERVIVENCIA)  ║
-- ╚══════════════════════════════════════════════════════════════════════╝
AI_CONFIG = {
    -- ⚠️ Umbrales de Peligro Ultra-Sensibles (altura en bloques)
    PANIC_LIGHT_HEIGHT = 4,
    PANIC_EXTREME_HEIGHT = 8,
    PANIC_ANY_GARBAGE_LINES = 1,

    -- 👁️ Anticipación y Defensa
    OPPONENT_THREAT_HEIGHT_LIGHT = 6,
    OPPONENT_THREAT_HEIGHT_EXTREME = 10,
    OPPONENT_CLEAN_SURFACE_BUMP = 40,
    THREAT_ZONE_MIN_METER = 0.25,
    THREAT_BUILD_ZONE_PRIORITY = 2500,
    THREAT_SAVE_LINE_FOR_OFFSET = 3500,

    -- 🛡️ Offsetting Agresivo (cancelar basura antes de que entre)
    GARBAGE_OFFSET_LINE_BONUS = 4000,
    GARBAGE_OFFSET_BIG_QUEUE_BONUS = 2000,

    -- 💥 PESOS CALM (prioriza superficie ultra-plana y cero huecos)
    CALM_HEIGHT_PENALTY   = 18.0,
    CALM_HOLES_PENALTY    = 4500.0,
    CALM_COVERED_PENALTY  = 6000.0,
    CALM_BUMP_PENALTY     = 45.0,
    CALM_WELL_BONUS       = 20.0,
    CALM_SINGLE_DOUBLE_BONUS = 400.0,
    CALM_TETRIS_BONUS     = 1200.0,

    -- 🚨 PESOS PÁNICO LEVE
    PANIC_HEIGHT_PENALTY  = 45.0,
    PANIC_HOLES_PENALTY   = 8500.0,
    PANIC_COVERED_PENALTY = 11000.0,
    PANIC_BUMP_PENALTY    = 70.0,
    PANIC_HOLE_BLOCK_PENALTY = 14000,
    PANIC_LINE_BONUS      = 3500.0,
    PANIC_TETRIS_BONUS    = 3600.0,

    -- 🔥 PESOS PÁNICO EXTREMO (Downstack quirúrgico)
    EXTREME_HEIGHT_PENALTY  = 95.0,
    EXTREME_HOLES_PENALTY   = 18000.0,
    EXTREME_COVERED_PENALTY = 25000.0,
    EXTREME_BUMP_PENALTY    = 120.0,
    EXTREME_HOLE_BLOCK_PENALTY = 35000,
    EXTREME_LINE_BONUS      = 6000.0,
    EXTREME_TETRIS_BONUS    = 6000.0,

    -- 🎯 Prioridad máxima a despejar el pozo de basura
    HOLE_CLEAR_ALIGNMENT_BONUS = 3000,
    ZONE_MIN_METER = 0.25,
    ZONE_GARBAGE_TRIGGER = 1,
}

function AIBot.new(board, profile)
    local self = setmetatable({}, AIBot)
    self.board = board

    -- Lee el perfil adaptativo guardado
    local adapt = loadAdaptiveProfile()
    self.base_pps = adapt.ai_target_pps or 1.45
    self.pps = self.base_pps
    self.move_timer = 0
    self.target_x, self.target_rot = nil, nil
    self.is_thinking = false
    self.just_locked = false

    -- Buffers planos pre-alocados para evaluación Zero-GC
    self._overlay = {}
    for i = 1, 400 do self._overlay[i] = false end

    self._heights = {}
    self._top_found = {}
    self._hole_depths = {}
    for i = 1, 10 do
        self._heights[i] = 0
        self._top_found[i] = false
        self._hole_depths[i] = 0
    end

    return self
end

function AIBot:scanOpponentThreat()
    local opp = self.board.opponent
    if not opp then return 0, 0 end

    local opp_max_h = 0
    local opp_heights = {0,0,0,0,0,0,0,0,0,0}
    for c = 1, 10 do
        for r = 21, 40 do
            if opp.grid[r][c] ~= 0 then
                local h = 41 - r
                opp_heights[c] = h
                if h > opp_max_h then opp_max_h = h end
                break
            end
        end
    end

    local opp_bump = 0
    for i = 1, 9 do
        opp_bump = opp_bump + math.abs(opp_heights[i] - opp_heights[i+1])
    end

    local is_clean_setup = (opp_bump <= AI_CONFIG.OPPONENT_CLEAN_SURFACE_BUMP)
    local threat = 0
    if opp_max_h >= AI_CONFIG.OPPONENT_THREAT_HEIGHT_EXTREME then
        threat = 2
    elseif opp_max_h >= AI_CONFIG.OPPONENT_THREAT_HEIGHT_LIGHT then
        threat = 1
    end

    if is_clean_setup and opp_max_h >= 7 then
        threat = math.min(2, threat + 1)
    end

    return threat, opp_bump
end

function AIBot:update(dt)
    if not self.board.active_piece or self.board.active_piece.locked or self.just_locked then
        if self.board.active_piece and not self.board.active_piece.locked then
            self.just_locked = false
        end
        return
    end

    local active_punch = _G.TrackEnergyPunch or 0
    -- Escalado proporcional según su PPS base
    local pps_punch = active_punch * (self.base_pps * 0.35)

    local max_h = 0
    for c = 1, 10 do
        for r = 21, 40 do
            if self.board.grid[r][c] ~= 0 then
                local h = 41 - r
                if h > max_h then max_h = h end
                break
            end
        end
    end

    local panic_pps = 0
    if max_h >= AI_CONFIG.PANIC_EXTREME_HEIGHT then
        panic_pps = self.base_pps * 0.25
    elseif max_h >= AI_CONFIG.PANIC_LIGHT_HEIGHT then
        panic_pps = self.base_pps * 0.12
    end

    self.pps = self.base_pps + pps_punch + panic_pps

    -- Detección de amenaza y activación Zone
    local opp_threat = self:scanOpponentThreat()
    local zone_meter_min = AI_CONFIG.ZONE_MIN_METER
    if opp_threat >= 2 then
        zone_meter_min = AI_CONFIG.THREAT_ZONE_MIN_METER
    elseif opp_threat == 1 then
        zone_meter_min = 0.28
    end

    if not self.board.is_zone_active and self.board.zone_meter >= zone_meter_min then
        local in_danger = #self.board.garbage_queue >= AI_CONFIG.ZONE_GARBAGE_TRIGGER
        local high_stack = false
        local extreme_stack = false
        for c = 1, 10 do
            if self.board.grid[26][c] ~= 0 then high_stack = true end
            if self.board.grid[24][c] ~= 0 then extreme_stack = true; break end
        end
        if (in_danger or high_stack or extreme_stack or active_punch >= 0.85 or opp_threat >= 2) then
            self.board:enterZone()
        end
    end

    self.move_timer = self.move_timer + dt
    if self.move_timer >= (1 / self.pps) then
        if not self.is_thinking then
            self:think()
        else
            self:executeMove()
        end
        self.move_timer = 0
    end
end

function AIBot:findGarbageHoleColumn()
    local grid = self.board.grid
    for r = 40, 21, -1 do
        local hole_col = nil
        local garbage_count = 0
        for c = 1, 10 do
            if grid[r][c] == 8 or grid[r][c] ~= 0 then
                garbage_count = garbage_count + 1
            elseif grid[r][c] == 0 then
                hole_col = c
            end
        end
        if garbage_count >= 8 and hole_col then
            return hole_col, r
        end
    end
    return nil, nil
end

function AIBot:think()
    local p = self.board.active_piece
    if not p or p.locked or type(p.canMove) ~= "function" then return end

    local best_score = -20000000
    local max_rot = #p.shape

    local max_board_h = 0
    for r = 21, 40 do
        for c = 1, 10 do
            if self.board.grid[r][c] ~= 0 then
                local h = 41 - r
                if h > max_board_h then max_board_h = h end
            end
        end
    end

    local has_garbage_queue = #self.board.garbage_queue >= AI_CONFIG.PANIC_ANY_GARBAGE_LINES
    local panic_level = 0
    if max_board_h >= AI_CONFIG.PANIC_EXTREME_HEIGHT then
        panic_level = 2
    elseif max_board_h >= AI_CONFIG.PANIC_LIGHT_HEIGHT or has_garbage_queue then
        panic_level = 1
    end

    local opp_threat_level = self:scanOpponentThreat()

    local garbage_queue_size = #self.board.garbage_queue
    local total_garbage_incoming = 0
    for i = 1, garbage_queue_size do
        total_garbage_incoming = total_garbage_incoming + self.board.garbage_queue[i]
    end

    local target_hole_col, target_hole_row = self:findGarbageHoleColumn()

    for r = 1, max_rot do
        for x = -2, 11 do
            if p:canMove(x, p.y, r) then
                local gy = p.y
                while p:canMove(x, gy + 1, r) do gy = gy + 1 end

                local score = self:evaluate(
                    x, gy, r,
                    panic_level,
                    target_hole_col, target_hole_row,
                    opp_threat_level,
                    garbage_queue_size, total_garbage_incoming
                )

                if p.id == 6 and panic_level < 2 and opp_threat_level < 2 and score > -500000 then
                    local old_x, old_y, old_r = p.x, p.y, p.rotation
                    p.x, p.y, p.rotation = x, gy, r
                    if p:checkTSpin() then
                        score = score + 3500
                    end
                    p.x, p.y, p.rotation = old_x, old_y, old_r
                end

                if score > best_score then
                    best_score = score
                    self.target_x, self.target_rot = x, r
                end
            end
        end
    end
    self.is_thinking = true
end

function AIBot:evaluate(px, py, pr, panic_level, target_hole_col, target_hole_row, opp_threat_level, garbage_queue_size, total_garbage_incoming)
    local grid = self.board.grid
    local shape = self.board.active_piece.shape[pr]

    local overlay = self._overlay
    for i = 1, 400 do overlay[i] = false end
    for sr = 1, #shape do
        local srow = shape[sr]
        for sc = 1, #srow do
            if srow[sc] ~= 0 then
                local tr, tc = py + sr - 1, px + sc - 1
                if tr >= 1 and tr <= 40 and tc >= 1 and tc <= 10 then
                    overlay[(tr - 1) * 10 + tc] = true
                end
            end
        end
    end

    local heights = self._heights
    local top_found = self._top_found
    local hole_depths = self._hole_depths
    for c = 1, 10 do
        heights[c] = 0
        top_found[c] = false
        hole_depths[c] = 0
    end

    local holes = 0
    local covered_holes = 0
    local lines_cleared = 0

    local hole_col_covered_before = 0
    local hole_col_covered_after = 0
    if target_hole_col and target_hole_row then
        for r = 21, target_hole_row do
            if grid[r][target_hole_col] ~= 0 then
                hole_col_covered_before = hole_col_covered_before + 1
            end
        end
        for r = 21, target_hole_row do
            local occ = (grid[r][target_hole_col] ~= 0) or overlay[(r - 1) * 10 + target_hole_col]
            if occ then
                hole_col_covered_after = hole_col_covered_after + 1
            end
        end
    end

    for r = 1, 40 do
        local row_full = true
        local base = (r - 1) * 10
        for c = 1, 10 do
            local occupied = (grid[r][c] ~= 0) or overlay[base + c]
            if occupied then
                if not top_found[c] then
                    heights[c] = 41 - r
                    top_found[c] = true
                end
            else
                row_full = false
                if top_found[c] then
                    holes = holes + 1
                    hole_depths[c] = hole_depths[c] + 1
                    if hole_depths[c] > 1 then
                        covered_holes = covered_holes + 1
                    end
                end
            end
        end
        if row_full then lines_cleared = lines_cleared + 1 end
    end

    local max_h, bumpiness = 0, 0
    for i = 1, 10 do
        if heights[i] > max_h then max_h = heights[i] end
        if i < 10 then bumpiness = bumpiness + math.abs(heights[i] - heights[i + 1]) end
    end

    local score = 0

    -- Offsetting & Defensa Proactiva
    if lines_cleared > 0 and total_garbage_incoming > 0 then
        local offset_effect = math.min(lines_cleared, total_garbage_incoming)
        score = score + (offset_effect * AI_CONFIG.GARBAGE_OFFSET_LINE_BONUS)
        if garbage_queue_size >= 3 then
            score = score + AI_CONFIG.GARBAGE_OFFSET_BIG_QUEUE_BONUS
        end
    end

    if opp_threat_level >= 1 and not self.board.is_zone_active then
        if lines_cleared == 1 or lines_cleared == 2 then
            score = score + (lines_cleared * AI_CONFIG.THREAT_BUILD_ZONE_PRIORITY)
        end
        if opp_threat_level >= 2 and lines_cleared == 0 then
            score = score - 2500
        end
    end

    if total_garbage_incoming >= 4 and lines_cleared >= 2 and lines_cleared < 4 then
        score = score + AI_CONFIG.THREAT_SAVE_LINE_FOR_OFFSET
    end

    -- Ponderación por Niveles de Pánico
    if panic_level == 2 then
        score = score - (max_h * max_h * AI_CONFIG.EXTREME_HEIGHT_PENALTY)
        score = score - (holes * AI_CONFIG.EXTREME_HOLES_PENALTY)
        score = score - (covered_holes * AI_CONFIG.EXTREME_COVERED_PENALTY)
        score = score - (bumpiness * AI_CONFIG.EXTREME_BUMP_PENALTY)

        if target_hole_col and lines_cleared == 0 then
            local shape_occupies_hole_col = false
            for sr = 1, #shape do
                for sc = 1, #shape[sr] do
                    if shape[sr][sc] ~= 0 and (px + sc - 1) == target_hole_col then
                        shape_occupies_hole_col = true
                        break
                    end
                end
            end
            if shape_occupies_hole_col then
                score = score - AI_CONFIG.EXTREME_HOLE_BLOCK_PENALTY
            end
        end

        if target_hole_col and lines_cleared > 0 then
            local delta = hole_col_covered_before - hole_col_covered_after
            if delta > 0 then
                score = score + (delta * AI_CONFIG.HOLE_CLEAR_ALIGNMENT_BONUS)
            end
        end

        if lines_cleared > 0 then
            score = score + (lines_cleared * AI_CONFIG.EXTREME_LINE_BONUS)
            if lines_cleared == 4 then score = score + AI_CONFIG.EXTREME_TETRIS_BONUS end
        end

    elseif panic_level == 1 then
        score = score - (max_h * max_h * AI_CONFIG.PANIC_HEIGHT_PENALTY)
        score = score - (holes * AI_CONFIG.PANIC_HOLES_PENALTY)
        score = score - (covered_holes * AI_CONFIG.PANIC_COVERED_PENALTY)
        score = score - (bumpiness * AI_CONFIG.PANIC_BUMP_PENALTY)

        if target_hole_col and lines_cleared == 0 then
            local shape_occupies_hole_col = false
            for sr = 1, #shape do
                for sc = 1, #shape[sr] do
                    if shape[sr][sc] ~= 0 and (px + sc - 1) == target_hole_col then
                        shape_occupies_hole_col = true
                        break
                    end
                end
            end
            if shape_occupies_hole_col then
                score = score - AI_CONFIG.PANIC_HOLE_BLOCK_PENALTY
            end
        end

        if target_hole_col and lines_cleared > 0 then
            local delta = hole_col_covered_before - hole_col_covered_after
            if delta > 0 then
                score = score + (delta * AI_CONFIG.HOLE_CLEAR_ALIGNMENT_BONUS)
            end
        end

        if lines_cleared > 0 then
            score = score + (lines_cleared * AI_CONFIG.PANIC_LINE_BONUS)
            if lines_cleared == 4 then score = score + AI_CONFIG.PANIC_TETRIS_BONUS end
        end

    else
        score = score - (max_h * max_h * AI_CONFIG.CALM_HEIGHT_PENALTY)
        score = score - (holes * AI_CONFIG.CALM_HOLES_PENALTY)
        score = score - (covered_holes * AI_CONFIG.CALM_COVERED_PENALTY)
        score = score - (bumpiness * AI_CONFIG.CALM_BUMP_PENALTY)

        if heights[10] < heights[9] - 1 then
            score = score + AI_CONFIG.CALM_WELL_BONUS
        end

        if lines_cleared == 4 then
            score = score + AI_CONFIG.CALM_TETRIS_BONUS
        elseif lines_cleared > 0 then
            score = score + (lines_cleared * AI_CONFIG.CALM_SINGLE_DOUBLE_BONUS)
        end
    end

    return score
end

function AIBot:executeMove()
    local p = self.board.active_piece
    if not p or p.locked or not self.target_x or not self.target_rot then
        self.is_thinking = false
        return
    end

    local max_rot = #p.shape
    local real_target_rot = ((self.target_rot - 1) % max_rot) + 1

    -- Colocación precisa y fluida al ritmo de self.pps
    p.rotation = real_target_rot
    p.x = self.target_x

    local startY = p.y
    while p:move(0, 1, true) do end
    local endY = p.y
    
    -- Blindaje seguro contra nil
    if self.board and self.board.spawnTrail then
        self.board:spawnTrail(p.x, startY, endY, p.id, p.shape[p.rotation])
    end
    
    p:lock()

    self.is_thinking = false
    self.just_locked = true
end

return AIBot
-- ================================================================
-- FILE: core/layout_solver.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: ZERO-GC CONSTRAINT & ANCHOR LAYOUT SOLVER
-- Parametric screen positioning, dynamic anchors & safe-zone calculations
-- ============================================================================
local LayoutSolver = {}

function LayoutSolver.solve(layout_style, boards_config, sw, sh)
    local sw = sw or 1280
    local sh = sh or 720
    local num_boards = #boards_config
    local result = {
        boards = {},
        center_hud_x = 640,
        center_hud_width = 300,
        center_hud_mode = "full", -- "full", "compact", "none"
        is_multibot = (num_boards > 2 or layout_style == "multibot"),
        is_boss = (layout_style == "gigantic_boss")
    }

    -- ────────────────────────────────────────────────────────────────────────
    -- 1. GIGANTIC BOSS RAID (David vs Goliat - Escala Asimétrica)
    -- ────────────────────────────────────────────────────────────────────────
    if layout_style == "gigantic_boss" then
        -- P1: Compacto y Ágil (10x20 visible -> 190x380px)
        local p1_bs = 19
        local p1_w = (boards_config[1].cols or 10) * p1_bs
        local p1_h = math.floor((boards_config[1].rows or 40) / 2) * p1_bs
        local p1_x = 100
        local p1_y = math.floor((sh - p1_h) / 2) + 20

        result.boards[1] = {
            x = p1_x, y = p1_y, block_size = p1_bs, cols = boards_config[1].cols or 10, rows = boards_config[1].rows or 40,
            type = boards_config[1].type or "human", ai_profile = boards_config[1].ai_profile,
            panel_hold_x = p1_x - 56 - 8,
            panel_next_x = p1_x + p1_w + 8,
            panel_w = 56, panel_h = 56, scale = 0.46,
            draw_hold = true
        }

        -- Boss Titán: Coloso Descomunal (10x24 (12 visibles) -> 450x540px)
        local boss_bs = 45
        local boss_cols = 10
        local boss_rows = 24
        local boss_w = boss_cols * boss_bs
        local boss_h = math.floor(boss_rows / 2) * boss_bs
        local boss_x = 700
        local boss_y = math.floor((sh - boss_h) / 2) + 15

        result.boards[2] = {
            x = boss_x, y = boss_y, block_size = boss_bs, cols = boss_cols, rows = boss_rows,
            type = boards_config[2].type or "bot", ai_profile = boards_config[2].ai_profile or "boss",
            panel_hold_x = boss_x + boss_w + 10,
            panel_next_x = boss_x - 56 - 8,
            panel_w = 56, panel_h = 56, scale = 0.46,
            draw_hold = false -- El Jefe NO dibuja Hold
        }

        -- Centro del canal libre: P1 Next termina en x=354, Boss Next empieza en x=636 -> Centro en x=495
        result.center_hud_x = 495
        result.center_hud_width = 260
        result.center_hud_mode = "compact"

    -- ────────────────────────────────────────────────────────────────────────
    -- 2. MULTI-BOT (3 TABLEROS - BATTLE ROYALE)
    -- ────────────────────────────────────────────────────────────────────────
    elseif result.is_multibot then
        local bs = 18
        local bw = 10 * bs -- 180px
        local bh = 20 * bs -- 360px
        local by = math.floor((sh - bh) / 2) - 25
        local pos_x = { 70, 490, 910 }

        for i, cfg in ipairs(boards_config) do
            local bx = pos_x[i] or (70 + (i - 1) * 420)
            local is_human = (cfg.type == "human")

            result.boards[i] = {
                x = bx, y = by, block_size = bs, cols = cfg.cols or 10, rows = cfg.rows or 40,
                type = cfg.type, ai_profile = cfg.ai_profile or "normal",
                panel_hold_x = is_human and (bx - 48 - 6) or (bx + bw + 6),
                panel_next_x = is_human and (bx + bw + 6) or (bx - 48 - 6),
                panel_w = 48, panel_h = 48, scale = 0.38,
                draw_hold = true
            }
        end

        result.center_hud_mode = "none" -- Reemplazado por el Dashboard inferior

    -- ────────────────────────────────────────────────────────────────────────
    -- 3. TINY MATRIX BLITZ (6x24)
    -- ────────────────────────────────────────────────────────────────────────
    elseif layout_style == "tiny" then
        local bs = 26
        local bw = 6 * bs -- 156px
        local bh = 12 * bs -- 312px
        local by = math.floor((sh - bh) / 2)
        local pos_x = { 240, 880 }

        for i, cfg in ipairs(boards_config) do
            local bx = pos_x[i] or 240
            local is_human = (cfg.type == "human")

            result.boards[i] = {
                x = bx, y = by, block_size = bs, cols = cfg.cols or 6, rows = cfg.rows or 24,
                type = cfg.type, ai_profile = cfg.ai_profile or "normal",
                panel_hold_x = is_human and (bx - 56 - 8) or (bx + bw + 8),
                panel_next_x = is_human and (bx + bw + 8) or (bx - 56 - 8),
                panel_w = 56, panel_h = 56, scale = 0.46,
                draw_hold = true
            }
        end

        result.center_hud_x = 640
        result.center_hud_width = 300
        result.center_hud_mode = "full"

    -- ────────────────────────────────────────────────────────────────────────
    -- 4. VERSUS 1v1 ESTÁNDAR (10x40 - 24px)
    -- ────────────────────────────────────────────────────────────────────────
    else
        local bs = 24
        local bw = 10 * bs -- 240px
        local bh = 20 * bs -- 480px
        local by = math.floor((sh - bh) / 2)
        local pos_x = { 180, 860 }

        for i, cfg in ipairs(boards_config) do
            local bx = pos_x[i] or 180
            local is_human = (cfg.type == "human")

            result.boards[i] = {
                x = bx, y = by, block_size = bs, cols = cfg.cols or 10, rows = cfg.rows or 40,
                type = cfg.type, ai_profile = cfg.ai_profile or "normal",
                panel_hold_x = is_human and (bx - 56 - 8) or (bx + bw + 8),
                panel_next_x = is_human and (bx + bw + 8) or (bx - 56 - 8),
                panel_w = 56, panel_h = 56, scale = 0.48,
                draw_hold = true
            }
        end

        result.center_hud_x = 640
        result.center_hud_width = 300
        result.center_hud_mode = "full"
    end

    return result
end

return LayoutSolver

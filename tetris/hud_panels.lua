-- ================================================================
-- FILE: tetris/hud_panels.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: DYNAMIC HUD PANELS (NEXT / HOLD / ZONE BAR) (1280x720)
-- ============================================================================
local HUDPanels = {}
local SRS          = require "tetris.rotation_systems.srs"
local FontCache    = require "tetris.font_cache"
local ThemeManager = require "tetris.theme_manager"

local PREVIEW_CONFIG = {
    [1] = { ox = 11, oy = 14, scale = 0.50 }, -- I piece (4x4)
    [2] = { ox = 15, oy = 18, scale = 0.55 }, -- J piece (3x3)
    [3] = { ox = 15, oy = 18, scale = 0.55 }, -- L piece (3x3)
    [4] = { ox = 22, oy = 24, scale = 0.55 }, -- O piece (2x2)
    [5] = { ox = 15, oy = 18, scale = 0.55 }, -- S piece (3x3)
    [6] = { ox = 15, oy = 18, scale = 0.55 }, -- T piece (3x3)
    [7] = { ox = 15, oy = 18, scale = 0.55 }  -- Z piece (3x3)
}

function HUDPanels.draw(board)
    local t = ThemeManager.getCurrent()
    local theme_idx = ThemeManager.current_theme
    local pulse = _G.AudioBeatPulse or 0
    local is_human = (board.player_type == "human")
    
    local bw = board.cols * (board.block_size or 24)
    local hold_x = is_human and (board.x - 78) or (board.x + bw + 10)
    local next_x = is_human and (board.x + bw + 10) or (board.x - 78)
    local panel_y = board.y + 10
    local p_w, p_h = 70, 70

    love.graphics.push("all")

    local function drawThemedPanel(x, y, label)
        if theme_idx == 1 then
            love.graphics.setColor(0.02, 0.03, 0.06, 0.94)
            love.graphics.rectangle("fill", x, y, p_w, p_h, 2)
            love.graphics.setLineWidth(1.5)
            love.graphics.setColor(0, 0.9, 0.45, 0.45 + pulse * 0.25)
            love.graphics.rectangle("line", x, y, p_w, p_h, 2)

            love.graphics.setColor(1, 1, 1, 0.3)
            love.graphics.rectangle("fill", x + 2, y + 2, 2, 2)
            love.graphics.rectangle("fill", x + p_w - 4, y + 2, 2, 2)

            love.graphics.setFont(FontCache.get(8))
            love.graphics.setColor(0, 1.0, 0.55, 0.9)
            love.graphics.printf(label, x, y + 4, p_w, "center")

        elseif theme_idx == 2 then
            love.graphics.setColor(0.06, 0.06, 0.09, 0.96)
            love.graphics.rectangle("fill", x, y, p_w, p_h)
            love.graphics.setLineWidth(2.5)
            love.graphics.setColor(1.0, 0.08, 0.25, 0.9)
            love.graphics.rectangle("line", x, y, p_w, p_h)

            love.graphics.setColor(1.0, 0.85, 0.0, 1.0)
            love.graphics.polygon("fill", x, y, x + 12, y, x, y + 12)

            love.graphics.setFont(FontCache.get(8))
            love.graphics.setColor(1, 0.9, 0.2, 1.0)
            love.graphics.printf(label, x, y + 3, p_w, "center")

        elseif theme_idx == 3 then
            love.graphics.setColor(0.01, 0.02, 0.05, 0.85)
            love.graphics.rectangle("fill", x, y, p_w, p_h, 6)
            love.graphics.setLineWidth(1.2)
            love.graphics.setColor(0.0, 0.9, 1.0, 0.4 + pulse * 0.3)
            love.graphics.rectangle("line", x, y, p_w, p_h, 6)

            love.graphics.setFont(FontCache.get(8))
            love.graphics.setColor(0.0, 0.95, 1.0, 0.85)
            love.graphics.printf(label, x, y + 4, p_w, "center")

        elseif theme_idx == 4 then
            love.graphics.setColor(0.01, 0.01, 0.03, 0.80)
            love.graphics.rectangle("fill", x, y, p_w, p_h, 8)
            love.graphics.setBlendMode("add")
            love.graphics.setColor(0.6, 0.35, 1.0, 0.35 + pulse * 0.2)
            love.graphics.circle("line", x + p_w/2, y + p_h/2, 32)
            love.graphics.setBlendMode("alpha")

            love.graphics.setFont(FontCache.get(8))
            love.graphics.setColor(0.6, 0.35, 1.0, 0.95)
            love.graphics.printf(label, x, y + 3, p_w, "center")
        end
    end

    drawThemedPanel(hold_x, panel_y, (theme_idx == 2 and "RESERVE") or "HOLD")
    if board.hold_piece then
        local pid = board.hold_piece.id
        local cfg = PREVIEW_CONFIG[pid] or { ox = 15, oy = 18, scale = 0.55 }
        local shape = SRS.shapes[pid] and SRS.shapes[pid][1] or {{{1}}}
        
        love.graphics.push()
        love.graphics.translate(hold_x + cfg.ox, panel_y + cfg.oy)
        love.graphics.scale(cfg.scale, cfg.scale)
        love.graphics.setBlendMode("add")
        for r = 1, #shape do
            for c = 1, #shape[r] do
                if shape[r][c] ~= 0 then
                    board:drawBlock((c - 1) * 24, (r - 1) * 24, pid, 0.92, 24)
                end
            end
        end
        love.graphics.setBlendMode("alpha")
        love.graphics.pop()
    end

    drawThemedPanel(next_x, panel_y, (theme_idx == 2 and "INCOMING") or "NEXT")
    if board.bag and board.bag.peek then
        -- 🛡️ Resolución defensiva de tipo para soportar tanto {id} como números planos
        local peek_res = board.bag:peek(1)
        local next_id = type(peek_res) == "table" and (peek_res[1] or peek_res.id) or peek_res

        if next_id and type(next_id) == "number" then
            local cfg = PREVIEW_CONFIG[next_id] or { ox = 15, oy = 18, scale = 0.55 }
            local shape = SRS.shapes[next_id] and SRS.shapes[next_id][1] or {{{1}}}
            
            love.graphics.push()
            love.graphics.translate(next_x + cfg.ox, panel_y + cfg.oy)
            love.graphics.scale(cfg.scale, cfg.scale)
            love.graphics.setBlendMode("add")
            for r = 1, #shape do
                for c = 1, #shape[r] do
                    if shape[r][c] ~= 0 then
                        board:drawBlock((c - 1) * 24, (r - 1) * 24, next_id, 0.92, 24)
                    end
                end
            end
            love.graphics.setBlendMode("alpha")
            love.graphics.pop()
        end
    end

    -- ────────────────────────────────────────────────────────────────────────
    -- 2. BARRA DE ZONE METER
    -- ────────────────────────────────────────────────────────────────────────
    local bw = board.cols * (board.block_size or 24)
    local zone_x = is_human and (board.x - 16) or (board.x + bw + 6)
    local zone_y = board.y + 90
    local zone_h = 300
    local zone_w = 10

    local fill_val = board.is_zone_active and (board.zone_timer / (board.zone_max_time * math.max(0.1, board.zone_meter))) or board.zone_meter
    fill_val = math.max(0, math.min(1, fill_val or 0))
    local current_h = zone_h * fill_val

    if theme_idx == 1 then
        love.graphics.setColor(0.01, 0.02, 0.04, 0.9)
        love.graphics.rectangle("fill", zone_x, zone_y, zone_w, zone_h, 1)
        love.graphics.setColor(0, 0.8, 0.4, 0.3)
        love.graphics.rectangle("line", zone_x, zone_y, zone_w, zone_h, 1)

        local num_segs = 15
        for seg = 1, num_segs do
            local seg_y = zone_y + zone_h - (seg * 20)
            local is_lit = (seg / num_segs) <= fill_val
            if seg <= 9 then
                love.graphics.setColor(is_lit and {0, 1, 0.3, 0.95} or {0, 0.2, 0.08, 0.3})
            elseif seg <= 13 then
                love.graphics.setColor(is_lit and {1, 0.8, 0.0, 0.95} or {0.25, 0.2, 0.0, 0.3})
            else
                love.graphics.setColor(is_lit and {1, 0.1, 0.2, 0.95} or {0.25, 0.05, 0.05, 0.3})
            end
            love.graphics.rectangle("fill", zone_x + 1, seg_y + 2, zone_w - 2, 16, 1)
        end

    elseif theme_idx == 2 then
        love.graphics.setColor(0.06, 0.06, 0.09, 0.95)
        love.graphics.rectangle("fill", zone_x, zone_y, zone_w + 2, zone_h)
        love.graphics.setLineWidth(1.8)
        love.graphics.setColor(1.0, 0.08, 0.25, 0.8)
        love.graphics.rectangle("line", zone_x, zone_y, zone_w + 2, zone_h)

        if current_h > 0 then
            love.graphics.setColor(1.0, 0.85, 0.0, 0.95)
            love.graphics.rectangle("fill", zone_x + 1, zone_y + zone_h - current_h, zone_w, current_h)
        end

        if board.zone_meter >= 0.999 and not board.is_zone_active then
            love.graphics.setFont(FontCache.get(8))
            love.graphics.setColor(1, 0.08, 0.25, 0.95 + pulse * 0.05)
            love.graphics.printf("BURST", zone_x - 18, zone_y + zone_h + 6, 48, "center")
        end

    elseif theme_idx == 3 then
        love.graphics.setColor(0.01, 0.02, 0.05, 0.85)
        love.graphics.rectangle("fill", zone_x, zone_y, zone_w, zone_h, 4)
        love.graphics.setColor(0.0, 0.9, 1.0, 0.35)
        love.graphics.rectangle("line", zone_x, zone_y, zone_w, zone_h, 4)

        if current_h > 0 then
            love.graphics.setColor(0.0, 0.95, 1.0, 0.95)
            love.graphics.rectangle("fill", zone_x + 1, zone_y + zone_h - current_h + 1, zone_w - 2, current_h - 2, 3)
        end

    elseif theme_idx == 4 then
        love.graphics.setColor(0.01, 0.01, 0.03, 0.85)
        love.graphics.rectangle("fill", zone_x, zone_y, zone_w, zone_h, 5)
        love.graphics.setBlendMode("add")
        love.graphics.setColor(0.6, 0.35, 1.0, 0.40)
        love.graphics.rectangle("line", zone_x, zone_y, zone_w, zone_h, 5)

        if current_h > 0 then
            love.graphics.setColor(0.6, 0.35, 1.0, 0.85)
            love.graphics.rectangle("fill", zone_x + 1, zone_y + zone_h - current_h + 1, zone_w - 2, current_h - 2, 4)
        end
        love.graphics.setBlendMode("alpha")
    end

    love.graphics.pop()
end

return HUDPanels
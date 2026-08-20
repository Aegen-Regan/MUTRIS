---@diagnostic disable: undefined-global
local HUDPanels = {}
local SRS = require "tetris.rotation_systems.srs"
local FontCache = require "tetris.font_cache"

local PREVIEW_CONFIG = {
    [1] = { ox = 6,  oy = 18, scale = 0.55 },
    [2] = { ox = 12, oy = 18, scale = 0.55 },
    [3] = { ox = 12, oy = 18, scale = 0.55 },
    [4] = { ox = 19, oy = 24, scale = 0.55 },
    [5] = { ox = 12, oy = 18, scale = 0.55 },
    [6] = { ox = 12, oy = 18, scale = 0.55 },
    [7] = { ox = 12, oy = 18, scale = 0.55 }
}

function HUDPanels.draw(board)
    love.graphics.push("all")
    local is_human = (board.player_type == "human")
    
    local hold_x = is_human and (board.x - 72) or (board.x + 248)
    local next_x = is_human and (board.x + 244) or (board.x - 68)
    local panel_y = board.y + 10
    
    local pulse = _G.AudioBeatPulse or 0
    
    local function drawNeonPanel(x, y, label)
        local p_w = 64
        local p_h = 64
        
        love.graphics.setColor(0.02, 0.03, 0.06, 0.88)
        love.graphics.rectangle("fill", x, y, p_w, p_h, 4)
        
        love.graphics.setLineWidth(1.5)
        love.graphics.setColor(0, 0.6, 1, 0.35 + pulse * 0.3)
        love.graphics.rectangle("line", x, y, p_w, p_h, 4)
        
        love.graphics.setFont(FontCache.get(9))
        love.graphics.setColor(1, 1, 1, 0.65)
        love.graphics.printf(label, x, y + 4, p_w, "center")
    end

    -- PANEL HOLD
    drawNeonPanel(hold_x, panel_y, "HOLD")
    if board.hold_piece then
        local pid = board.hold_piece.id
        local cfg = PREVIEW_CONFIG[pid] or { ox = 12, oy = 18, scale = 0.55 }
        local shape = SRS.shapes[pid][1]
        
        love.graphics.push()
        love.graphics.translate(hold_x + cfg.ox, panel_y + cfg.oy)
        love.graphics.scale(cfg.scale, cfg.scale)
        love.graphics.setBlendMode("add")
        for r = 1, #shape do
            for c = 1, #shape[r] do
                if shape[r][c] ~= 0 then
                    board:drawBlock((c - 1) * 24, (r - 1) * 24, pid, 0.85)
                end
            end
        end
        love.graphics.setBlendMode("alpha")
        love.graphics.pop()
    end

    -- PANEL NEXT
    drawNeonPanel(next_x, panel_y, "NEXT")
    if board.bag then
        local next_id = board.bag:peek(1)[1]
        if next_id then
            local cfg = PREVIEW_CONFIG[next_id] or { ox = 12, oy = 18, scale = 0.55 }
            local shape = SRS.shapes[next_id][1]
            
            love.graphics.push()
            love.graphics.translate(next_x + cfg.ox, panel_y + cfg.oy)
            love.graphics.scale(cfg.scale, cfg.scale)
            love.graphics.setBlendMode("add")
            for r = 1, #shape do
                for c = 1, #shape[r] do
                    if shape[r][c] ~= 0 then
                        board:drawBlock((c - 1) * 24, (r - 1) * 24, next_id, 0.85)
                    end
                end
            end
            love.graphics.setBlendMode("alpha")
            love.graphics.pop()
        end
    end

    -- BARRA LATERAL ZONE METER (REACTIVA Y DISTINCIÓN 100%)
    local zone_x = is_human and (board.x - 14) or (board.x + 246)
    local zone_y = board.y + 120
    local zone_h = 240
    
    love.graphics.setColor(0.01, 0.02, 0.05, 0.8)
    love.graphics.rectangle("fill", zone_x, zone_y, 8, zone_h, 2)
    love.graphics.setColor(0, 0.6, 1, 0.3)
    love.graphics.rectangle("line", zone_x, zone_y, 8, zone_h, 2)

    local fill_val = board.is_zone_active and (board.zone_timer / (board.zone_max_time * math.max(0.1, board.zone_meter))) or board.zone_meter
    fill_val = math.max(0, math.min(1, fill_val))
    local current_h = zone_h * fill_val

    if current_h > 0 then
        local is_full_100 = board.zone_meter >= 0.999
        local time = love.timer.getTime()
        
        if board.is_zone_active then
            if board.zone_tier == 2 then
                love.graphics.setColor(1.0, 0.85, 0.2, 0.95 + pulse * 0.05)
            else
                love.graphics.setColor(0.1, 0.9, 1.0, 0.9 + pulse * 0.1)
            end
        elseif is_full_100 then
            -- Indicador 100% clavado (Hyper Oro/Diamante)
            local flash = 0.6 + math.sin(time * 16) * 0.4
            love.graphics.setColor(1.0, 0.85 * flash, 0.2, 0.95)
        elseif board.zone_meter >= 0.25 then
            local shimmer = 0.7 + math.sin(time * 10) * 0.3
            love.graphics.setColor(0.1 * shimmer, 0.95, 0.8 * shimmer, 0.9)
        else
            love.graphics.setColor(0.0, 0.7, 0.5, 0.75)
        end
        love.graphics.rectangle("fill", zone_x + 1, zone_y + zone_h - current_h + 1, 6, current_h - 2, 2)
    end

    -- Indicador [Q]
    if not board.is_zone_active and is_human then
        local time = love.timer.getTime()
        if board.zone_meter >= 0.999 then
            local alpha = 0.7 + math.sin(time * 14) * 0.3
            love.graphics.setFont(FontCache.get(8))
            love.graphics.setColor(1.0, 0.85, 0.2, alpha)
            love.graphics.printf("[Q] 100%", zone_x - 22, zone_y + zone_h + 6, 52, "center")
        elseif board.zone_meter >= 0.25 then
            local alpha = 0.5 + math.sin(time * 8) * 0.4
            love.graphics.setFont(FontCache.get(8))
            love.graphics.setColor(0.1, 0.95, 1.0, alpha)
            love.graphics.printf("[Q]", zone_x - 16, zone_y + zone_h + 6, 40, "center")
        end
    end

    love.graphics.pop()
end

return HUDPanels
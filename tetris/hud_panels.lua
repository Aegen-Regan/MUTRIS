local HUDPanels = {}
local SRS = require "tetris.rotation_systems.srs"
local FontCache = require "tetris.font_cache"

function HUDPanels.draw(board)
    love.graphics.push("all")
    local is_human = (board.player_type == "human")
    local hold_x = is_human and (board.x - 75) or (board.x + 255)
    local next_x = is_human and (board.x + 255) or (board.x - 75)
    local panel_y = board.y + 10
    
    local energy = _G.TrackEnergyPunch or 0
    local pulse = _G.AudioBeatPulse or 0
    
    -- Configuración de estilo Neón para los paneles
    local function drawNeonPanel(x, y, label)
        local p_size = 65 + (pulse * 2 * energy)
        local offset = (p_size - 65) / 2
        
        -- Fondo
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", x - offset, y - offset, p_size, p_size, 4)
        
        -- Borde Neón
        love.graphics.setLineWidth(1 + pulse * 2)
        love.graphics.setColor(0, 0.6, 1, 0.3 + pulse * 0.4)
        love.graphics.rectangle("line", x - offset, y - offset, p_size, p_size, 4)
        
        -- Etiqueta
        love.graphics.setFont(FontCache.get(10))
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.printf(label, x, y + 4, 65, "center")
    end

    -- --- PANEL HOLD ---
    drawNeonPanel(hold_x, panel_y, "HOLD")
    if board.hold_piece then
        local shape = SRS.shapes[board.hold_piece.id][1]
        love.graphics.push()
        love.graphics.translate(hold_x + 12, panel_y + 20)
        love.graphics.scale(0.6, 0.6)
        love.graphics.setBlendMode("add")
        for r=1, #shape do
            for c=1, #shape[r] do
                if shape[r][c] ~= 0 then
                    board:drawBlock((c-1)*24, (r-1)*24, board.hold_piece.id, 0.8)
                end
            end
        end
        love.graphics.setBlendMode("alpha")
        love.graphics.pop()
    end

    -- --- PANEL NEXT ---
    drawNeonPanel(next_x, panel_y, "NEXT")
    if board.bag then
        local next_id = board.bag:peek(1)[1]
        if next_id then
            local shape = SRS.shapes[next_id][1]
            love.graphics.push()
            love.graphics.translate(next_x + 12, panel_y + 20)
            love.graphics.scale(0.6, 0.6)
            love.graphics.setBlendMode("add")
            for r=1, #shape do
                for c=1, #shape[r] do
                    if shape[r][c] ~= 0 then
                        board:drawBlock((c-1)*24, (r-1)*24, next_id, 0.8)
                    end
                end
            end
            love.graphics.setBlendMode("alpha")
            love.graphics.pop()
        end
    end
    love.graphics.pop()
end

return HUDPanels
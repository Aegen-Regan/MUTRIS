local HUDPanels = {}
local SRS = require "tetris.rotation_systems.srs"

function HUDPanels.draw(board)
    love.graphics.push("all")
    local is_human = (board.player_type == "human")
    local hold_x = is_human and (board.x - 75) or (board.x + 255)
    local next_x = is_human and (board.x + 255) or (board.x - 75)
    local panel_y = board.y + 10
    
    -- --- PANEL HOLD ---
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", hold_x, panel_y, 65, 65, 4)
    love.graphics.setColor(1, 1, 1, 0.2)
    love.graphics.rectangle("line", hold_x, panel_y, 65, 65, 4)
    love.graphics.printf("HOLD", hold_x, panel_y + 4, 65, "center")

    if board.hold_piece then
        local shape = SRS.shapes[board.hold_piece.id][1]
        love.graphics.push()
        love.graphics.translate(hold_x + 12, panel_y + 20)
        love.graphics.scale(0.6, 0.6)
        for r=1, #shape do
            for c=1, #shape[r] do
                if shape[r][c] ~= 0 then
                    board:drawBlock((c-1)*24, (r-1)*24, board.hold_piece.id)
                end
            end
        end
        love.graphics.pop()
    end

    -- --- PANEL NEXT ---
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", next_x, panel_y, 65, 65, 4)
    love.graphics.setColor(1, 1, 1, 0.2)
    love.graphics.rectangle("line", next_x, panel_y, 65, 65, 4)
    love.graphics.printf("NEXT", next_x, panel_y + 4, 65, "center")

    if board.bag then
        local next_data = board.bag:peek(1)
        local next_id = next_data[1]
        if next_id then
            local shape = SRS.shapes[next_id][1]
            love.graphics.push()
            love.graphics.translate(next_x + 12, panel_y + 20)
            love.graphics.scale(0.6, 0.6)
            for r=1, #shape do
                for c=1, #shape[r] do
                    if shape[r][c] ~= 0 then
                        board:drawBlock((c-1)*24, (r-1)*24, next_id)
                    end
                end
            end
            love.graphics.pop()
        end
    end
    love.graphics.pop()
end

return HUDPanels
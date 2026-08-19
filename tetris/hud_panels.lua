---@diagnostic disable: undefined-global
local HUDPanels = {}
-- CORRECCIÓN: Requerimos el módulo una sola vez al inicio del archivo
local Piece = require "tetris.piece"

-- Pool estático de previsualización para evitar recolector de basura (Zero-GC)
local preview_piece = {
    shape = {},
    rotation = 1,
    id = 0,
    board = nil,
    drawMini = Piece.drawMini,
    drawBlock = function(self, bx, by, id, alpha)
        if self.board and self.board.drawBlock then
            self.board:drawBlock(bx, by, id, alpha)
        end
    end
}

function HUDPanels.draw(board)
    love.graphics.push("all")
    local is_human = (board.player_type == "human")
    local hold_x = is_human and (board.x - 75) or (board.x + 255)
    local next_x = is_human and (board.x + 255) or (board.x - 75)
    local panel_y = board.y + 10
    
    -- CONTENEDOR HOLD NATIVO
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", hold_x, panel_y, 65, 65, 4)
    love.graphics.setColor(1, 1, 1, 0.15)
    love.graphics.rectangle("line", hold_x, panel_y, 65, 65, 4)
    love.graphics.setFont(love.graphics.newFont(9))
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.print("HOLD", hold_x + 8, panel_y + 4)
    
    if board.hold_piece then
        love.graphics.push()
        love.graphics.translate(hold_x + 10, panel_y + 18)
        love.graphics.scale(0.65, 0.65)
        if board.hold_piece.drawMini then board.hold_piece:drawMini() end
        love.graphics.pop()
    end
    
    -- CONTENEDOR NEXT NATIVO
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", next_x, panel_y, 65, 65, 4)
    love.graphics.setColor(1, 1, 1, 0.15)
    love.graphics.rectangle("line", next_x, panel_y, 65, 65, 4)
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.print("NEXT", next_x + 8, panel_y + 4)
    
       if board.bag and board.active_piece then
        local next_id = nil
        local success, result = pcall(function() return board.bag:peek(1) end)
        -- CORRECCIÓN: Como result es una tabla { id }, extraemos explícitamente el índice [1]
        if success and type(result) == "table" and result[1] then
            next_id = result[1]
        end
        
        if next_id then
            love.graphics.push()
            love.graphics.translate(next_x + 10, panel_y + 18)
            love.graphics.scale(0.65, 0.65)
            
            -- CORRECCIÓN: Reutilizamos la tabla estática inyectando los datos de este frame
            preview_piece.id = next_id
            preview_piece.board = board
            
            local SRS = require "tetris.rotation_systems.srs"
            if type(SRS) == "function" then preview_piece.shape = SRS(next_id)
            elseif type(SRS) == "table" and SRS.getShape then preview_piece.shape = SRS.getShape(next_id)
            else preview_piece.shape = SRS[next_id] end
            
            if preview_piece.shape and preview_piece.drawMini then 
                preview_piece:drawMini() 
            end
            love.graphics.pop()
        end
    end
    
    love.graphics.pop()
end

return HUDPanels

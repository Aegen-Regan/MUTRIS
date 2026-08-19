local PPSCounter = {}

function PPSCounter.init(board)
    board.pps_buffer = {}
    for i = 1, 60 do board.pps_buffer[i] = 0 end
    board.pps_head = 1
    board.current_pps_display = 0.0
end

function PPSCounter.register(board)
    local now = love.timer.getTime()
    board.pps_buffer[board.pps_head] = now
    board.pps_head = (board.pps_head % 60) + 1
end

function PPSCounter.update(board)
    local now = love.timer.getTime()
    local window = 5.0
    local valid_pieces = 0
    
    for i = 1, 60 do
        local timestamp = board.pps_buffer[i]
        -- CORRECCIÓN: Si el timestamp es 0, significa que la ranura está vacía. 
        -- La ignoramos por completo y pasamos a la siguiente para evitar cálculos desfasados.
        if timestamp and timestamp > 0 then
            if (now - timestamp) <= window then
                valid_pieces = valid_pieces + 1
            end
        end
    end
    board.current_pps_display = valid_pieces / window
end

return PPSCounter

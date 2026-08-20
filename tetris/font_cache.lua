---@diagnostic disable: undefined-global
-- FontCache: evita crear una Font nueva (costosa, genera basura) en cada frame.
-- love.graphics.newFont() rasteriza glifos y aloja memoria cada vez que se llama;
-- llamarlo dentro de love.draw() (que corre 60 veces por segundo) era la causa
-- principal de presión sobre el GC y micro-tirones, algo que rompe la filosofía
-- Zero-GC que ya se aplica en particle_system.lua / board.lua trails.
local FontCache = {}
local cache = {}

-- Devuelve (y crea una sola vez) la fuente para el tamaño pedido.
-- Redondea el tamaño para que valores continuos (ej: 20 + energy * 8) no generen
-- una fuente nueva por cada variación mínima de frame a frame -- visualmente es
-- imperceptible y mantiene exactamente la misma tipografía/tamaño de antes.
function FontCache.get(size)
    size = math.floor(size + 0.5)
    local font = cache[size]
    if not font then
        font = love.graphics.newFont(size)
        cache[size] = font
    end
    return font
end

return FontCache

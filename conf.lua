-- conf.lua
-- Configuración del motor LÖVE2D optimizada para hardware limitado

function love.conf(t)
    t.window.title = "Tetris OPT - Versus"
    t.window.width = 800
    t.window.height = 600
    t.window.vsync = 1
    t.window.resizable = false
    
    t.identity = "tetris_opt"
    t.version = "11.4" -- Compatible con LÖVE 11.x y superiores
    
    t.modules.joystick = true
    t.modules.physics = false
    t.modules.touch = false
end

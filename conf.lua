-- ============================================================================
-- MUTRIS ENGINE: LÖVE2D CONFIGURATION (16:9 WIDESCREEN NATIVO)
-- ============================================================================

function love.conf(t)
    t.window.title = "MUTRIS: SYNTHETIC TRANSCENDENCE"
    t.window.width = 1280
    t.window.height = 720
    t.window.vsync = 1
    t.window.resizable = true
    t.window.minwidth = 960
    t.window.minheight = 540
    
    t.identity = "tetris_opt"
    t.version = "11.4"
    
    t.modules.joystick = true
    t.modules.physics = false
    t.modules.touch = false
end
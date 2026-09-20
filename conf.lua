function love.conf(t)
    t.identity = "rhyme"
    t.version = "11.5"
    t.window.title = "Rhyme"
    t.window.width = 880
    t.window.height = 760
    t.window.resizable = false
    t.window.vsync = 1
    t.modules.joystick = false
    t.modules.physics = false
end

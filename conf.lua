function love.conf(t)
  t.identity = "rhyme"
  t.version = "11.5"
  t.console = false
  t.accelerometerjoystick = false
  t.window.title = "Rhyme"
  t.window.icon = nil
  t.window.width = 430
  t.window.height = 932
  t.window.minwidth = 320
  t.window.minheight = 568
  t.window.resizable = true
  t.window.vsync = 1
  t.window.highdpi = true
  t.window.msaa = 0
  t.window.usedpiscale = true
  t.modules.joystick = false
  t.modules.physics = false
  t.modules.video = false
  t.modules.thread = false
end

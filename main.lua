-- Rhyme: portrait LÖVE station campaign. `love .` from the repo root.
local sim = require("sim")
local levels = require("levels")
local saveMod = require("save")
local render = require("render")
local ui = require("ui")
local audio = require("audio")

local G = {
  screen = "title",
  save = nil,
  worldId = 1,
  chosen = nil,
  match = nil,
  speed = 1,
  ghost = nil,
  ended = false,
  paused = false,
  hint = "",
  fonts = nil,
  w = 430,
  h = 932,
  ox = 0,
  oy = 0,
}

local SIM_DT = 1 / 60
local simAcc = 0
local lastShootAt = 0
local clock = 0
local shotPending = false
local shotFrames = 0
local shotName = nil

local function setScreen(name)
  G.screen = name
  local bed = "title"
  if name == "play" then bed = "play"
  elseif name == "how" then bed = "how"
  elseif name == "worlds" or name == "levels" then bed = "worlds"
  end
  audio.setBed(bed)
end

local function layoutPhone()
  local sw, sh = love.graphics.getDimensions()
  local ox, oy, w, h = ui.letterbox(sw, sh)
  G.ox, G.oy, G.w, G.h = ox, oy, w, h
  ui.safe(G)
end

local function dockHeight(match)
  local tools = sim.paletteFor(match.level)
  local rows = math.ceil(math.max(1, #tools) / 7)
  return 8 + rows * 54 + 52
end

local function remapPlay()
  local match = G.match
  if not match then return end
  local bag = (match.mechanics.pieceQueue and match.piece) and 44 or 0
  local top = (G.safeTop or 18) + 64 + bag + 8
  local bottom = (G.safeBottom or 18) + dockHeight(match) + 28
  local layout = sim.computeLayout(G.w, G.h, match.cols, match.rows, {
    top = top, bottom = bottom, left = 8, right = 8,
  })
  sim.remapLayout(match, layout)
end

local function openBrief(level)
  G.chosen = level
  setScreen("brief")
end

local function startLevel(level)
  G.chosen = level
  G.ended = false
  G.paused = false
  G.speed = 1
  G.ghost = nil
  G.match = sim.createMatch(level, { seed = (os.time() % 9999) + 1 })
  remapPlay()
  setScreen("play")
  local look = levels.worldLook(level.world)
  audio.play(look.stinger)
  G.hint = sim.coachText(G.match) or level.hint or level.lesson or ""
end

local function consumeEvents()
  local match = G.match
  if not match then return end
  local now = clock
  for _, ev in ipairs(match.events) do
    if ev.type == "place" then audio.play("place")
    elseif ev.type == "assign" then audio.play("assign")
    elseif ev.type == "dock" then audio.play("seat")
    elseif ev.type == "tick" then audio.play("tick")
    elseif ev.type == "built" then audio.play("built")
    elseif ev.type == "incoming" then audio.play("incoming")
    elseif ev.type == "wave" then audio.play("wave")
    elseif ev.type == "flare" then audio.play("flare")
    elseif ev.type == "shoot" then
      if now - lastShootAt > 0.11 then
        audio.play("shoot")
        lastShootAt = now
      end
    elseif ev.type == "kill" then audio.play("kill")
    elseif ev.type == "cleared" then audio.play("cleared")
    elseif ev.type == "win" then audio.play("win")
    elseif ev.type == "recruit" then audio.play("recruit")
    elseif ev.type == "grow" then audio.play("grow")
    elseif ev.type == "mine" then audio.play("mine")
    elseif ev.type == "cook" then audio.play("cook")
    elseif ev.type == "haul" then audio.play("haul")
    elseif ev.type == "hold" then audio.play("hold")
    elseif ev.type == "relic" then audio.play("relic")
    elseif ev.type == "go" then audio.play("go")
    end
  end
  match.events = {}
end

local function finish()
  local match = G.match
  if not match or G.ended then return end
  if match.status ~= "won" and match.status ~= "lost" then return end
  G.ended = true
  if match.status == "won" then
    local nxt = levels.nextLevel(G.chosen.id)
    saveMod.completeLevel(G.save, G.chosen.id, match.stars, nxt and nxt.id)
    saveMod.write(G.save)
  else
    audio.play("over")
  end
end

local function toLocal(x, y)
  return x - G.ox, y - G.oy
end

local function onStageTap(lx, ly)
  local match = G.match
  if not match or match.status ~= "playing" then return end
  local g = sim.gridAt(match, lx, ly)
  local ok = sim.tapCell(match, g.x, g.y)
  if not ok and sim.ROOMS[match.tool] and match.tool ~= "core" then
    local best, bestD = nil, 2
    for yy = 0, match.rows - 1 do
      for xx = 0, match.cols - 1 do
        if sim.canPlace(match, match.tool, xx, yy, match.rot) then
          local d = math.abs(xx - g.x) + math.abs(yy - g.y)
          if d > 0 and d < bestD then
            best = { x = xx, y = yy }
            bestD = d
          end
        end
      end
    end
    if best then ok = sim.tapCell(match, best.x, best.y) end
  end
  if not ok and match.tool ~= "assign" then audio.play("error") end
  G.ghost = nil
end

local function onStageMove(lx, ly)
  local match = G.match
  if not match then return end
  local g = sim.gridAt(match, lx, ly)
  if sim.ROOMS[match.tool] and match.tool ~= "core" then
    local shape = sim.rotateShape(sim.playerShape(match, match.tool), match.rot)
    local cells = {}
    for _, p in ipairs(shape) do
      cells[#cells + 1] = { x = g.x + (p[1] or 0), y = g.y + (p[2] or 0) }
    end
    G.ghost = { cells = cells, ok = sim.canPlace(match, match.tool, g.x, g.y, match.rot) }
  else
    G.ghost = nil
  end
end

local function handleHit(h)
  audio.unlock()
  local id = h.id
  if id == "playCampaign" then
    openBrief(levels.levelById(G.save.last) or levels.LEVELS[1])
    audio.play("tap")
  elseif id == "openWorlds" then
    setScreen("worlds")
    audio.play("tap")
  elseif id == "openHow" then
    G.save.seenHow = true
    saveMod.write(G.save)
    setScreen("how")
    audio.play("tap")
  elseif id == "worldsBack" then
    setScreen("title")
  elseif id == "world" then
    G.worldId = h.data
    setScreen("levels")
    audio.play("tap")
  elseif id == "levelsBack" then
    setScreen("worlds")
  elseif id == "level" then
    openBrief(levels.levelById(h.data))
    audio.play("tap")
  elseif id == "briefBack" then
    G.worldId = G.chosen.world
    setScreen("levels")
  elseif id == "briefStart" then
    startLevel(G.chosen)
  elseif id == "howBack" then
    setScreen("title")
  elseif id == "pause" then
    if G.match then
      sim.pause(G.match)
      G.paused = G.match.status == "paused"
    end
  elseif id == "resume" then
    if G.match and G.match.status == "paused" then sim.pause(G.match) end
    if G.match then sim.resumeThink(G.match) end
    G.paused = false
  elseif id == "restart" then
    startLevel(G.chosen)
  elseif id == "pauseMap" or id == "endMap" then
    G.match = nil
    setScreen("worlds")
  elseif id == "speed" then
    if G.match and G.match.thinkLocked then
      sim.resumeThink(G.match)
      G.speed = 1
    else
      G.speed = G.speed == 1 and 2 or (G.speed == 2 and 3 or 1)
    end
  elseif id == "tool" then
    if G.match then
      if G.match.tutorial and G.match.tutorial.needAssign and h.data ~= "assign" then return end
      sim.setTool(G.match, h.data)
      audio.play("tap")
    end
  elseif id == "rotate" then
    if G.match then sim.rotate(G.match) audio.play("tap") end
  elseif id == "hold" then
    if G.match then
      if sim.holdPiece(G.match) then audio.play("hold") else audio.play("error") end
    end
  elseif id == "recall" then
    if G.match and sim.recall(G.match) then audio.play("assign") end
  elseif id == "mute" then
    audio.setMuted(not audio.isMuted())
  elseif id == "endPrimary" then
    if G.match and G.match.status == "won" then
      local nxt = levels.nextLevel(G.chosen.id)
      if nxt then openBrief(nxt) else setScreen("title") end
    else
      startLevel(G.chosen)
    end
  elseif id == "endRetry" then
    startLevel(G.chosen)
  end
end

function love.load()
  love.graphics.setBackgroundColor(5 / 255, 5 / 255, 6 / 255)
  love.math.setRandomSeed(os.time())
  if love.system and love.system.getOS() == "iOS" then
    pcall(function()
      love.window.setMode(0, 0, { fullscreen = true, highdpi = true, vsync = 1, resizable = false })
    end)
  end
  G.fonts = {
    big = love.graphics.newFont(40),
    ui = love.graphics.newFont(16),
    small = love.graphics.newFont(13),
    tiny = love.graphics.newFont(10),
    brand = love.graphics.newFont(11),
  }
  G.save = saveMod.load()
  G.chosen = levels.LEVELS[1]
  layoutPhone()
  audio.unlock()
  local v1, v2, v3 = love.getVersion()
  print(string.format("Rhyme LÖVE %s.%s.%s boot  love .", tostring(v1), tostring(v2), tostring(v3)))
  local shot = os.getenv("RHYME_SHOT")
  local demo = os.getenv("RHYME_DEMO")
  if shot == "play" or shot == "spine" then
    startLevel(levels.LEVELS[1])
    local m = G.match
    sim.setTool(m, "corridor")
    sim.tapCell(m, 4, 4)
    sim.assignTo(m, sim.roomAt(m, 4, 4))
    sim.setTool(m, "corridor")
    sim.tapCell(m, 4, 8)
    sim.tapCell(m, 2, 6)
    for _ = 1, 120 do sim.step(m, 1 / 60) end
    consumeEvents()
    shotPending = true
    shotName = "pass18_spine.png"
  elseif shot == "title" then
    shotPending = true
    shotName = "pass18_title.png"
  elseif shot == "worlds" then
    setScreen("worlds")
    shotPending = true
    shotName = "pass18_worlds.png"
  elseif shot == "finale" then
    local lg = levels.levelById("7-06")
    startLevel(lg)
    shotPending = true
    shotName = "pass18_finale.png"
  elseif demo == "spine" or demo == "1" then
    startLevel(levels.LEVELS[1])
    local m = G.match
    sim.setTool(m, "corridor")
    sim.tapCell(m, 4, 4)
    sim.assignTo(m, sim.roomAt(m, 4, 4))
    sim.setTool(m, "corridor")
    sim.tapCell(m, 4, 8)
    sim.tapCell(m, 2, 6)
    sim.setTool(m, "assign")
    consumeEvents()
  end
end

function love.resize()
  layoutPhone()
  if G.match then remapPlay() end
end

function love.update(dt)
  dt = math.min(dt or 0, 0.05)
  clock = clock + dt
  audio.update(dt)
  if G.screen ~= "play" or not G.match then
    simAcc = 0
    return
  end
  remapPlay()
  if G.match.status == "playing" then
    simAcc = simAcc + dt
    while simAcc >= SIM_DT do
      for _ = 1, G.speed do sim.step(G.match, SIM_DT) end
      simAcc = simAcc - SIM_DT
    end
    consumeEvents()
  else
    simAcc = 0
  end
  local coach = sim.coachText(G.match)
  if G.match.tutorial and G.match.tutorial.needAssign then
    G.hint = G.match.mechanics.teachStaff
      and "The garden is built. Tap it — not the kapsel."
      or (G.match.mechanics.teachScan
        and "The scanner is built. Tap Scan so it can see cloaked scouts."
        or "Tap the blueprint to send a kapsel. That is the whole game.")
    if G.match.tool ~= "assign" then sim.setTool(G.match, "assign") end
  elseif coach then
    G.hint = coach
  elseif G.match.time > 7 and not G.match.mechanics.coach then
    G.hint = ""
  end
  finish()
end

function love.draw()
  layoutPhone()
  love.graphics.push()
  love.graphics.translate(G.ox, G.oy)
  love.graphics.setScissor(G.ox, G.oy, G.w, G.h)
  ui.beginFrame()
  ui.drawSky(G)
  if G.screen == "title" then
    ui.title(G)
  elseif G.screen == "worlds" then
    ui.worlds(G)
  elseif G.screen == "levels" then
    ui.levels(G)
  elseif G.screen == "brief" then
    ui.brief(G)
  elseif G.screen == "how" then
    ui.how(G)
  elseif G.screen == "play" and G.match then
    render.drawWorld(G.match, G.w, G.h, clock * 1000, G.ghost, G.fonts)
    ui.play(G)
  end
  -- home indicator bar on desktop chrome
  love.graphics.setColor(243 / 255, 240 / 255, 232 / 255, 0.28)
  love.graphics.rectangle("fill", G.w / 2 - 64, G.h - 10, 128, 4, 2, 2)
  love.graphics.setScissor()
  love.graphics.pop()
  if shotName and love.graphics.captureScreenshot then
    shotFrames = shotFrames + 1
    if shotPending and shotFrames >= 3 then
      love.graphics.captureScreenshot(shotName)
      shotPending = false
    elseif shotFrames >= 5 then
      love.event.quit(0)
    end
  end
end

local function pointer(x, y, moving)
  local lx, ly = toLocal(x, y)
  if lx < 0 or ly < 0 or lx > G.w or ly > G.h then return end
  if moving and G.screen == "play" and G.match and not G.paused and not G.ended then
    onStageMove(lx, ly)
    return
  end
  local h = ui.pick(lx, ly)
  if h then
    handleHit(h)
    return
  end
  if G.screen == "play" and G.match and not G.paused and not G.ended then
    onStageTap(lx, ly)
  end
end

function love.mousepressed(x, y, button)
  if button ~= 1 then return end
  pointer(x, y, false)
end

function love.mousemoved(x, y, _, _, istouch)
  if istouch then return end
  if love.mouse.isDown(1) or G.screen == "play" then
    local lx, ly = toLocal(x, y)
    if G.screen == "play" then onStageMove(lx, ly) end
  end
end

function love.touchpressed(_, x, y)
  pointer(x, y, false)
end

function love.touchmoved(_, x, y)
  local lx, ly = toLocal(x, y)
  if G.screen == "play" then onStageMove(lx, ly) end
end

function love.keypressed(key)
  if key == "escape" then
    if G.screen == "play" and G.match then
      sim.pause(G.match)
      G.paused = G.match.status == "paused"
    elseif G.screen ~= "title" then
      setScreen("title")
    else
      love.event.quit()
    end
  elseif key == "r" and G.match then
    sim.rotate(G.match)
  elseif key == "h" and G.match then
    sim.holdPiece(G.match)
  elseif key == "space" and G.match and G.match.thinkLocked then
    sim.resumeThink(G.match)
  end
end

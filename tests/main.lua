-- Headless campaign + sim tests. Run: love tests
local root = love.filesystem.getSourceBaseDirectory()
package.path = root .. "/?.lua;" .. package.path

local levels = require("levels")
local sim = require("sim")
local overlay = require("overlay")
local saveMod = require("save")

local fails, passes = 0, 0

local function ok(cond, msg)
  if cond then
    passes = passes + 1
  else
    fails = fails + 1
    print("FAIL " .. (msg or "?"))
  end
end

local function eq(a, b, msg)
  ok(a == b, (msg or "eq") .. " got " .. tostring(a) .. " expected " .. tostring(b))
end

local function tick(match, seconds)
  local dt = 0.05
  local n = math.ceil(seconds / dt)
  for _ = 1, n do sim.step(match, dt) end
end

local function mini(over)
  over = over or {}
  local start = { minerals = 20, food = 10, crew = 3 }
  if over.start then
    for k, v in pairs(over.start) do start[k] = v end
  end
  return sim.createMatch({
    id = over.id or "test",
    world = 1,
    name = "Test",
    cols = 9,
    rows = 13,
    core = { x = 4, y = 6 },
    start = start,
    allowed = over.allowed or { "corridor", "garden", "extractor", "weapons", "quarters", "kitchen" },
    deposits = over.deposits or { { x = 1, y = 6 } },
    ice = over.ice or {},
    blocked = over.blocked or {},
    wells = over.wells or {},
    relics = over.relics or {},
    prebuilt = over.prebuilt or {},
    mechanics = over.mechanics or {},
    waves = over.waves or { first = 9999, interval = 40, count = 1 },
    eatRate = over.eatRate ~= nil and over.eatRate or 0,
    win = over.win or { corridors = 99 },
  }, { seed = over.seed or 7 })
end

function love.load()
  print("campaign data")
  eq(#levels.WORLDS, 7, "seven worlds")
  ok(#levels.LEVELS >= 42, "42 levels got " .. #levels.LEVELS)
  eq(levels.LEVELS[1].id, "1-01", "first is Spine")
  eq(levels.nextLevel("1-01").id, "1-02", "next 1-01")
  eq(levels.nextLevel("1-06").id, "2-01", "world gate")
  ok(levels.nextLevel("7-06") == nil, "campaign end")
  for _, w in ipairs(levels.WORLDS) do
    eq(#levels.levelsInWorld(w.id), 6, w.name .. " has 6")
  end

  local ids = {}
  for _, level in ipairs(levels.LEVELS) do
    ok(level.id and not ids[level.id], "unique " .. tostring(level.id))
    ids[level.id] = true
    ok(level.win and next(level.win) ~= nil, "win " .. level.id)
    ok(level.allowed and #level.allowed >= 1, "allowed " .. level.id)
  end

  print("level boot")
  for _, level in ipairs(levels.LEVELS) do
    local m = sim.createMatch(level, { seed = 3 })
    eq(m.status, "playing", level.id .. " status")
    ok(#m.kapsels >= 1, level.id .. " crew")
    sim.step(m, 0.05)
    ok(m.status ~= "won", level.id .. " not won at t0")
    eq(m.status, "playing", level.id .. " after tick")
  end

  print("geometry")
  do
    local t = sim.SHAPES.garden
    local r1 = sim.rotateShape(t, 1)
    eq(r1[1][1], -t[1][2], "rot x")
    eq(r1[1][2], t[1][1], "rot y")
    local m = mini()
    eq(m.rooms[1].type, "core", "core first")
    eq(#m.rooms[1].cells, 5, "plus core")
    ok(m.walkable(4, 6), "core center walkable")
    ok(m.walkable(4, 5), "core north walkable")
    ok(m.walkable(3, 6), "core west walkable")
    sim.setTool(m, "corridor")
    eq(sim.tapCell(m, 4, 6), false, "no overlap")
    eq(sim.tapCell(m, 0, 0), false, "no float")
    eq(sim.tapCell(m, 4, 4), true, "place corridor")
    local room = sim.roomAt(m, 4, 4)
    eq(room.type, "corridor", "corridor type")
    eq(room.built, false, "blueprint")
    eq(m.walkable(4, 4), false, "unbuilt not walkable")
  end

  print("assignment")
  do
    local m = mini({ prebuilt = { { type = "garden", x = 4, y = 8, rot = 0, built = true } } })
    sim.setTool(m, "assign")
    local garden
    for _, r in ipairs(m.rooms) do if r.type == "garden" then garden = r end end
    ok(sim.assignTo(m, garden), "assign garden")
    local n = 0
    for _, k in ipairs(m.kapsels) do if k.assignment == garden.id then n = n + 1 end end
    eq(n, 1, "one assigned")
  end

  print("economy")
  do
    local m = mini({ start = { minerals = 8, food = 0, crew = 2 } })
    sim.setTool(m, "corridor")
    sim.tapCell(m, 4, 4)
    local site = sim.roomAt(m, 4, 4)
    sim.assignTo(m, site)
    tick(m, 0.2)
    eq(site.built, false, "not instant")
    tick(m, 20)
    eq(site.built, true, "built after haul")
    eq(sim.coreStock(m, "mineral"), 7, "paid 1 mineral")
  end

  print("palette")
  eq(table.concat(sim.paletteFor(levels.levelById("1-01")), ","), "assign,corridor,salvage", "spine dock")
  do
    local p = sim.paletteFor(levels.levelById("7-06"))
    local set = {}
    for _, t in ipairs(p) do set[t] = true end
    for _, t in ipairs({ "assign", "corridor", "scanner", "weapons", "shield", "garden", "kitchen", "extractor", "salvage" }) do
      ok(set[t], "finale has " .. t)
    end
    for _, t in ipairs({ "heater", "gate", "quarters", "beacon", "overload" }) do
      ok(not set[t], "finale dump " .. t)
    end
  end

  print("portrait layout")
  do
    local L = sim.computeLayout(430, 932, 9, 13, { top = 110, bottom = 210, left = 8, right = 8 })
    ok(L.cell <= 44, "cell <= 44pt got " .. tostring(L.cell))
    ok(L.cell >= 24, "cell readable got " .. tostring(L.cell))
    ok(L.gridW <= 430, "grid fits width")
  end

  print("overlay")
  do
    local won = overlay.endOverlaySpec("won", { hasNext = true })
    eq(won.title, "Stable", "won title")
    eq(won.primary, "Next station", "won primary")
    ok(won.retry, "won retry")
    local gate = overlay.endOverlaySpec("won", { hasNext = true, worldGate = "Fold" })
    eq(gate.primary, "Enter Fold", "world gate")
    local lost = overlay.endOverlaySpec("lost")
    eq(lost.title, "Unstitched", "lost title")
    eq(lost.retry, false, "lost no second retry row")
  end

  print("save")
  do
    local s = saveMod.empty()
    ok(s.unlocked["1-01"], "1-01 open")
    saveMod.completeLevel(s, "1-01", 3, "1-02")
    eq(s.stars["1-01"], 3, "stars")
    ok(s.unlocked["1-02"], "unlock next")
    ok(saveMod.worldUnlocked(s, 1, levels.LEVELS), "w1 open")
    ok(not saveMod.worldUnlocked(s, 2, levels.LEVELS), "w2 locked")
  end

  print("deposits / ice keys")
  do
    local m = mini({ ice = { { x = 4, y = 4 } }, deposits = { { x = 1, y = 6 } } })
    local n = 0
    for _ in pairs(m.ice) do n = n + 1 end
    eq(n, 1, "one ice")
    sim.setTool(m, "heater")
    -- heater may or may not place; thaw path must not crash on key split
    sim.step(m, 0.05)
    ok(m.status == "playing", "ice step")
  end

  print("spine win")
  do
    local m = sim.createMatch(levels.levelById("1-01"), { seed = 1 })
    sim.setTool(m, "corridor")
    ok(sim.tapCell(m, 4, 4), "hall 1")
    ok(sim.assignTo(m, sim.roomAt(m, 4, 4)), "assign hall")
    sim.setTool(m, "corridor")
    ok(sim.tapCell(m, 4, 8), "hall 2")
    ok(sim.tapCell(m, 2, 6), "hall 3")
    for _ = 1, 500 do sim.step(m, 0.05) end
    eq(m.status, "won", "spine won " .. tostring(m.status) .. " " .. tostring(m.loseReason))
    ok(m.stars >= 1, "stars")
  end

  print("captain spine")
  do
    local m = sim.createMatch(levels.levelById("1-01"), { seed = 1 })
    for _ = 1, 800 do
      sim.captainBeat(m)
      sim.step(m, 0.05)
      if m.status ~= "playing" then break end
    end
    eq(m.status, "won", "captain spine " .. tostring(m.status) .. " t=" .. tostring(m.time))
  end

  print("relic road")
  do
    local m = sim.createMatch(levels.levelById("7-06"), { seed = 11 })
    sim.setTool(m, "corridor")
    local placed = false
    for rot = 0, 3 do
      m.rot = rot
      for y = 0, m.rows - 1 do
        for x = 0, m.cols - 1 do
          if sim.canPlace(m, "corridor", x, y, rot) then
            placed = sim.tapCell(m, x, y)
            break
          end
        end
        if placed then break end
      end
      if placed then break end
    end
    ok(placed, "finale can place a hall")
    ok(#m.rooms >= 2, "room after place")
  end

  print(string.format("%d passed, %d failed", passes, fails))
  if fails > 0 then
    love.event.quit(1)
  else
    love.event.quit(0)
  end
end

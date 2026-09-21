-- Pure simulation for Rhyme. Port of js/sim.js. Deterministic when seeded.
local levels = require("levels")
local roomLabel = levels.roomLabel

local M = {}

local function hypot(a, b)
  return math.sqrt((a or 0) * (a or 0) + (b or 0) * (b or 0))
end

local function u32(n)
  n = n % 4294967296
  if n < 0 then n = n + 4294967296 end
  return n
end

local function imul(a, b)
  return u32(a * b)
end

local function truthy(v)
  if v == nil or v == false then return false end
  if type(v) == "number" then return v ~= 0 end
  if type(v) == "string" then return v ~= "" end
  return true
end

local function js_or(a, b)
  if truthy(a) then return a else return b end
end

local function js_and(a, b)
  if truthy(a) then return b else return a end
end

local function js_coalesce(a, b)
  if a == nil then return b else return a end
end

local function tern(c, a, b)
  if truthy(c) then return a else return b end
end

local function jsType(v)
  local t = type(v)
  if t == "table" then
    if v.__fn then return "function" end
    return "object"
  end
  if t == "nil" then return "undefined" end
  return t
end

local function idx(t, k)
  if t == nil then return nil end
  if type(k) == "number" then return t[k + 1] end
  return t[k]
end

local function optget(t, k)
  if t == nil then return nil end
  if type(k) == "number" then return t[k + 1] end
  return t[k]
end

local function setidx(t, k, v)
  if type(k) == "number" then t[k + 1] = v else t[k] = v end
  return v
end

local function postidx(t, k, delta, prefix)
  local cur = idx(t, k) or 0
  local nv = cur + delta
  setidx(t, k, nv)
  if prefix then return nv end
  return cur
end

local function copyList(t)
  local o = {}
  if type(t) ~= "table" then return o end
  for i, v in ipairs(t) do o[i] = v end
  return o
end

local function sliceList(t, a, b)
  t = t or {}
  a = a or 0
  local start = a + 1
  local stop = b ~= nil and b or #t
  local o = {}
  for i = start, stop do o[#o + 1] = t[i] end
  return o
end

local function concatLists(...)
  local o = {}
  for i = 1, select("#", ...) do
    local t = select(i, ...)
    if type(t) == "table" then
      for _, v in ipairs(t) do o[#o + 1] = v end
    end
  end
  return o
end

local function appendAll(dst, src)
  for _, v in ipairs(src or {}) do table.insert(dst, v) end
  return dst
end

local function listContains(t, x)
  for _, v in ipairs(t or {}) do if v == x then return true end end
  return false
end

local function listIndexOf(t, x)
  for i, v in ipairs(t or {}) do if v == x then return i - 1 end end
  return -1
end

local function countKeys(t)
  local n = 0
  for _ in pairs(t or {}) do n = n + 1 end
  return n
end

local function splitKey(k)
  if type(k) ~= "string" then return 0, 0 end
  local a, b = k:match("^([^,]+),([^,]+)$")
  return tonumber(a) or 0, tonumber(b) or 0
end

local function setKeys(t)
  local o = {}
  for k in pairs(t or {}) do o[#o + 1] = k end
  return o
end

local function keyList(t)
  local o = {}
  for k in pairs(t or {}) do o[#o + 1] = k end
  return o
end

local function assign(a, ...)
  a = a or {}
  for i = 1, select("#", ...) do
    local b = select(i, ...)
    if type(b) == "table" then
      for k, v in pairs(b) do a[k] = v end
    end
  end
  return a
end

local function listFilter(t, fn)
  local o = {}
  for _, v in ipairs(t or {}) do if truthy(fn(v)) then o[#o + 1] = v end end
  return o
end

local function listMap(t, fn)
  local o = {}
  for i, v in ipairs(t or {}) do o[i] = fn(v, i - 1, t) end
  return o
end

local function listFind(t, fn)
  for _, v in ipairs(t or {}) do if truthy(fn(v)) then return v end end
  return nil
end

local function listSome(t, fn)
  for _, v in ipairs(t or {}) do if truthy(fn(v)) then return true end end
  return false
end

local function listEvery(t, fn)
  for _, v in ipairs(t or {}) do if not truthy(fn(v)) then return false end end
  return true
end

local function listSort(t, fn)
  table.sort(t, function(a, b)
    local r = fn(a, b)
    if type(r) == "number" then return r < 0 end
    return r
  end)
  return t
end

local function listForEach(t, fn)
  for i, v in ipairs(t or {}) do fn(v, i - 1) end
end

local function setFrom(list)
  local s = {}
  if type(list) ~= "table" then return s end
  local n = #list
  if n > 0 then
    for _, v in ipairs(list) do
      s[v] = true
    end
  else
    for k, v in pairs(list) do
      if v == true then s[k] = true else s[v] = true end
    end
  end
  return s
end

local F = {}

M.PIECES = { I = { { 0, 0 }, { 1, 0 }, { 2, 0 }, { 3, 0 } }, O = { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }, T = { { 0, 0 }, { (-1), 0 }, { 1, 0 }, { 0, 1 } }, L = { { 0, 0 }, { 0, 1 }, { 0, 2 }, { 1, 2 } }, J = { { 0, 0 }, { 0, 1 }, { 0, 2 }, { (-1), 2 } }, S = { { 0, 0 }, { 1, 0 }, { 0, 1 }, { (-1), 1 } }, Z = { { 0, 0 }, { (-1), 0 }, { 0, 1 }, { 1, 1 } } }

local BAG_ORDER = { "I", "O", "T", "L", "J", "S", "Z" }

local CHIP_LABELS = { wait = "Wait", haul = "Haul", build = "Build", grow = "Grow", mine = "Mine", cook = "Cook", berth = "Berth", gun = "Gun", heat = "Heat", scan = "Scan", walk = "Walk" }

F.chipId = function(k)
local j = k.job
if not truthy(j) then
do return (function() if truthy(k.carry) then return "haul" else return "wait" end end)() end
end
if (j.kind == "haul") then
do return "haul" end
end
if (j.kind == "build") then
do return "build" end
end
if (j.kind == "produce") then
do return (function() if truthy((function() local __a = j.target; if not truthy(__a) then return __a end; return (j.target.type == "extractor") end)()) then return "mine" else return "grow" end end)() end
end
if (j.kind == "cook") then
do return "cook" end
end
if (j.kind == "recruit") then
do return "berth" end
end
if (j.kind == "staff") then
if (truthy(j.target)) and ((j.target.type == "heater")) then
do return "heat" end
end
if (truthy(j.target)) and ((j.target.type == "scanner")) then
do return "scan" end
end
do return "gun" end
end
if (j.kind == "idlewalk") then
do return "walk" end
end
if ((j.kind == "wait")) and ((k.state == "walking")) then
do return "walk" end
end
do return (function() if truthy(k.carry) then return "haul" else return "wait" end end)() end
end

F.jobChips = function(match)
local counts = {}
for _, k in ipairs(match.kapsels) do
local id = F.chipId(k)
setidx(counts, id, ((function() local __a = idx(counts, id); if truthy(__a) then return __a end; return 0 end)() + 1))
::c1::
end
do return listMap(listFilter(keyList(CHIP_LABELS), function(id)
return idx(counts, id)
end), function(id)
return { id = id, n = idx(counts, id), label = idx(CHIP_LABELS, id) }
end) end
end

F.playerShape = function(match, type)
if (((truthy(match.mechanics)) and (truthy(match.mechanics.pieceQueue))) and (truthy(match.piece))) and (truthy(idx(M.PIECES, match.piece))) then
do return idx(M.PIECES, match.piece) end
end
do return (function() local __a = idx(M.SHAPES, type); if truthy(__a) then return __a end; return M.SHAPES.corridor end)() end
end

F.fitPiece = function(name, size)
  if size == nil then size = 4 end
local cells = (function() local __a = idx(M.PIECES, name); if truthy(__a) then return __a end; return {  } end)()
if not truthy(#cells) then
do return {  } end
end
local minX = math.huge
local minY = math.huge
local maxX = (-math.huge)
local maxY = (-math.huge)
for _, __p in ipairs(cells) do
local x, y = idx(__p, 0), idx(__p, 1)
minX = math.min(minX, x)
minY = math.min(minY, y)
maxX = math.max(maxX, x)
maxY = math.max(maxY, y)
::c2::
end
local ox = (math.floor(((size - ((maxX - minX) + 1)) / 2)) - minX)
local oy = (math.floor(((size - ((maxY - minY) + 1)) / 2)) - minY)
do return listMap(cells, function(__p0)
local x = idx(__p0, 0)
local y = idx(__p0, 1)
return { (x + ox), (y + oy) }
end) end
end

M.SHAPES = { corridor = { { 0, 0 } }, weapons = { { 0, 0 } }, gate = { { 0, 0 } }, heater = { { 0, 0 } }, scanner = { { 0, 0 } }, beacon = { { 0, 0 } }, garden = { { 0, 0 }, { 1, 0 }, { (-1), 0 }, { 0, 1 } }, extractor = { { 0, 0 }, { 0, 1 }, { 0, 2 }, { 1, 2 } }, kitchen = { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }, quarters = { { 0, 0 }, { 1, 0 }, { 1, 1 }, { 2, 1 } }, shield = { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } }

M.ROOMS = { corridor = { name = "Corridor", cost = 1, hp = 22, hue = "#8d6b4a" }, garden = { name = "Garden", cost = 4, hp = 44, hue = "#5ea86a" }, extractor = { name = "Extractor", cost = 4, hp = 44, hue = "#d56b8c" }, weapons = { name = "Weapons", cost = 6, hp = 70, hue = "#7b88a3" }, kitchen = { name = "Kitchen", cost = 4, hp = 44, hue = "#d4b14a" }, quarters = { name = "Quarters", cost = 5, hp = 52, hue = "#d4844a" }, shield = { name = "Shield", cost = 6, hp = 60, hue = "#6ec3c9" }, gate = { name = "Gate", cost = 3, hp = 36, hue = "#9b7ad4" }, heater = { name = "Heater", cost = 3, hp = 36, hue = "#e07a4a" }, scanner = { name = "Scanner", cost = 4, hp = 40, hue = "#70b4e0" }, beacon = { name = "Beacon", cost = 5, hp = 48, hue = "#e8d9a0" }, core = { name = "Core", cost = 0, hp = 300, hue = "#3c445c" } }

local BUILD_SEC = 0.72

local PICK_SEC = 0.32

local FOOD_SEC = 3.4

local MINERAL_SEC = 4.0

local COOK_SEC = 2.0

local RECRUIT_SEC = 3.4

local MEALS_PER_BIO = 3

local MEALS_PER_RECRUIT = 3

local RECRUITS_PER_Q = 2

local STOCK_CAP = 8

local PANTRY_CAP = 24

local CORE_MINERAL_CAP = 36

M.TURRET_RANGE = 250

local TURRET_CD = 1.05

local TURRET_DMG = 12

M.SHIELD_R = 4.2

local HEATER_R = 3.3

M.SCAN_R = 200

local OVERCLOCK_SEC = 5

local OVERCLOCK_HURT = 9

F.gunRange = function(match)
do return math.max(M.TURRET_RANGE, (match.layout.cell * 7.4)) end
end

F.scanRange = function(match)
do return math.max(M.SCAN_R, (match.layout.cell * 6.4)) end
end

F.rotateShape = function(cells, turns)
local out = listMap(cells, function(__p0)
local x = idx(__p0, 0)
local y = idx(__p0, 1)
return { x, y }
end)
local n = (((turns % 4) + 4) % 4)
for i = 0, (n) - 1, 1 do
out = listMap(out, function(__p0)
local x = idx(__p0, 0)
local y = idx(__p0, 1)
return { (-y), x }
end)
::c3::
end
do return out end
end

F.key = function(x, y)
do return (x .. (",")) .. y end
end

F.makeRng = function(seed)
local s = (function() local __a = u32(seed); if truthy(__a) then return __a end; return 1 end)()
do return function()
s = u32((imul(s, 1664525) + 1013904223))
do return (s / 4294967296) end
end end
end

F.clamp = function(v, a, b)
do return math.max(a, math.min(b, v)) end
end

F.dist = function(ax, ay, bx, by)
do return hypot((ax - bx), (ay - by)) end
end

F.remapLayout = function(match, layout)
local old = match.layout
local map = function(x, y)
return { x = (layout.ox + (((x - old.ox) / old.cell) * layout.cell)), y = (layout.oy + (((y - old.oy) / old.cell) * layout.cell)) }
end
for _, k in ipairs(match.kapsels) do
local p = map(k.x, k.y)
k.x = p.x
k.y = p.y
::c4::
end
for _, e in ipairs(match.enemies) do
local p = map(e.x, e.y)
e.x = p.x
e.y = p.y
::c5::
end
for _, s in ipairs(match.shots) do
local p = map(s.x, s.y)
s.x = p.x
s.y = p.y
::c6::
end
match.layout = layout
for _, room in ipairs(match.rooms) do
F.roomCenter(match, room)
::c7::
end
end

F.computeLayout = function(vw, vh, cols, rows, insets)
  if insets == nil then insets = {  } end
local padL = (function() local __a = insets.left; if truthy(__a) then return __a end; return 16 end)()
local padR = (function() local __a = insets.right; if truthy(__a) then return __a end; return 16 end)()
local top = (function() local __a = insets.top; if truthy(__a) then return __a end; return 118 end)()
local bottom = (function() local __a = insets.bottom; if truthy(__a) then return __a end; return 210 end)()
local availW = math.max(120, ((vw - padL) - padR))
local availH = math.max(160, ((vh - top) - bottom))
local cell = math.floor(math.min((availW / cols), (availH / rows), 44))
local gridW = (cols * cell)
local gridH = (rows * cell)
do return { cell = cell, ox = math.floor(((vw - gridW) / 2)), oy = (top + math.floor(((availH - gridH) / 2))), gridW = gridW, gridH = gridH, width = vw, height = vh, top = top, bottom = bottom } end
end

F.defaultLayout = function(cols, rows)
do return F.computeLayout(390, 844, cols, rows, { top = 72, bottom = 200, left = 16, right = 16 }) end
end

F.cellsOf = function(type, x, y, rot, shape)
do return listMap(F.rotateShape((function() local __a = (function() local __a = shape; if truthy(__a) then return __a end; return idx(M.SHAPES, type) end)(); if truthy(__a) then return __a end; return M.SHAPES.corridor end)(), rot), function(__p0)
local dx = idx(__p0, 0)
local dy = idx(__p0, 1)
return { x = (x + dx), y = (y + dy) }
end) end
end

F.footprint = function(match, type, x, y, rot)
local cells = F.cellsOf(type, x, y, rot, F.playerShape(match, type))
for _, c in ipairs(cells) do
if (((((tonumber(c.x) or 0) < (tonumber(0) or 0))) or (((tonumber(c.y) or 0) < (tonumber(0) or 0)))) or (((tonumber(c.x) or 0) >= (tonumber(match.cols) or 0)))) or (((tonumber(c.y) or 0) >= (tonumber(match.rows) or 0))) then
do return nil end
end
if (idx(match.blocked, F.key(c.x, c.y)) ~= nil) then
do return nil end
end
if (idx(match.deposits, F.key(c.x, c.y)) ~= nil) then
do return nil end
end
if (truthy(match.relicCells)) and ((idx(match.relicCells, F.key(c.x, c.y)) ~= nil)) then
do return nil end
end
if (idx(match.grid, F.key(c.x, c.y)) ~= nil) then
do return nil end
end
::c8::
end
do return cells end
end

F.touchesStation = function(match, cells)
local dirs = { { 1, 0 }, { (-1), 0 }, { 0, 1 }, { 0, (-1) } }
for _, c in ipairs(cells) do
for _, __p in ipairs(dirs) do
local dx, dy = idx(__p, 0), idx(__p, 1)
if (idx(match.grid, F.key((c.x + dx), (c.y + dy))) ~= nil) then
do return true end
end
::c10::
end
::c9::
end
do return false end
end

F.nearDeposit = function(match, cells)
local dirs = { { 0, 0 }, { 1, 0 }, { (-1), 0 }, { 0, 1 }, { 0, (-1) } }
for _, c in ipairs(cells) do
for _, __p in ipairs(dirs) do
local dx, dy = idx(__p, 0), idx(__p, 1)
if (idx(match.deposits, F.key((c.x + dx), (c.y + dy))) ~= nil) then
do return true end
end
::c12::
end
::c11::
end
do return false end
end

F.roomCenter = function(match, room)
local sx = 0
local sy = 0
for _, c in ipairs(room.cells) do
sx = (sx + c.x)
sy = (sy + c.y)
::c13::
end
local n = #room.cells
room.cx = (match.layout.ox + (((sx / n) + 0.5) * match.layout.cell))
room.cy = (match.layout.oy + (((sy / n) + 0.5) * match.layout.cell))
end

F.pixelCenter = function(match, x, y)
do return { x = (match.layout.ox + ((x + 0.5) * match.layout.cell)), y = (match.layout.oy + ((y + 0.5) * match.layout.cell)) } end
end

F.roomAt = function(match, x, y)
local cell = idx(match.grid, F.key(x, y))
do return (function() if truthy(cell) then return cell.room else return nil end end)() end
end

F.coreStock = function(match, resource)
do return (function() local __a = idx(match.core.stock, resource); if truthy(__a) then return __a end; return 0 end)() end
end

F.staffed = function(match, room)
local n = 0
for _, k in ipairs(match.kapsels) do
if ((k.assignment == room.id)) and (truthy(F.kapselInRoom(match, k, room))) then
n = (n + 1)
end
::c14::
end
do return n end
end

F.kapselInRoom = function(match, k, room)
local g = F.atPixel(match, k.x, k.y)
do return listSome(room.cells, function(c)
return (function() local __a = (c.x == g.x); if not truthy(__a) then return __a end; return (c.y == g.y) end)()
end) end
end

F.atPixel = function(match, px, py)
do return { x = math.floor(((px - match.layout.ox) / match.layout.cell)), y = math.floor(((py - match.layout.oy) / match.layout.cell)) } end
end

F.walkable = function(match, x, y)
local cell = idx(match.grid, F.key(x, y))
do return not truthy(not truthy((function() local __a = (function() local __a = cell; if not truthy(__a) then return __a end; return cell.room.built end)(); if not truthy(__a) then return __a end; return not truthy(cell.room.dead) end)())) end
end

F.iceAt = function(match, x, y)
do return (idx(match.ice, F.key(x, y)) ~= nil) end
end

F.gateCells = function(match)
local cells = {  }
for _, room in ipairs(match.rooms) do
if (((room.type == "gate")) and (truthy(room.built))) and (not truthy(room.dead)) then
for _, c in ipairs(room.cells) do
table.insert(cells, c)
::c16::
end
end
::c15::
end
do return cells end
end

F.neighborsOf = function(match, x, y)
local out = {  }
local dirs = { { 1, 0 }, { (-1), 0 }, { 0, 1 }, { 0, (-1) } }
for _, __p in ipairs(dirs) do
local dx, dy = idx(__p, 0), idx(__p, 1)
local nx = (x + dx)
local ny = (y + dy)
if truthy(F.walkable(match, nx, ny)) then
table.insert(out, { x = nx, y = ny })
end
::c17::
end
local here = F.roomAt(match, x, y)
if ((truthy(here)) and ((here.type == "gate"))) and (truthy(here.built)) then
for _, g in ipairs(F.gateCells(match)) do
if ((g.x == x)) and ((g.y == y)) then
goto c18
end
table.insert(out, { x = g.x, y = g.y })
::c18::
end
end
do return out end
end

F.path = function(match, sx, sy, tx, ty)
if (not truthy(F.walkable(match, sx, sy))) or (not truthy(F.walkable(match, tx, ty))) then
do return nil end
end
if ((sx == tx)) and ((sy == ty)) then
do return {  } end
end
local q = { { sx, sy } }
local head = 0
local prev = {}
setidx(prev, F.key(sx, sy), false)
while ((tonumber(head) or 0) < (tonumber(#q) or 0)) do
local cx, cy
do
  local __p = idx(q, (function() local __v = head head = head + 1 return __v end)())
  cx = idx(__p, 0)
  cy = idx(__p, 1)
end
for _, n in ipairs(F.neighborsOf(match, cx, cy)) do
local k = F.key(n.x, n.y)
if (idx(prev, k) ~= nil) then
goto c20
end
setidx(prev, k, { cx, cy })
if ((n.x == tx)) and ((n.y == ty)) then
local route = {  }
local x = tx
local y = ty
while truthy(idx(prev, F.key(x, y))) do
table.insert(route, 1, { x = x, y = y })
local p = idx(prev, F.key(x, y))
x = idx(p, 0)
y = idx(p, 1)
::c21::
end
do return route end
end
table.insert(q, { n.x, n.y })
::c20::
end
::c19::
end
do return nil end
end

F.pathLength = function(match, sx, sy, tx, ty)
local p = F.path(match, sx, sy, tx, ty)
do return (function() if truthy(p) then return #p else return math.huge end end)() end
end

F.reachableBuilt = function(match)
local from = idx(match.core.cells, 0)
local seen = {}
if (not truthy(from)) or (not truthy(F.walkable(match, from.x, from.y))) then
do return seen end
end
local q = { { x = from.x, y = from.y } }
setidx(seen, F.key(from.x, from.y), true)
for i = 0, (#q) - 1, 1 do
for _, n in ipairs(F.neighborsOf(match, (idx(q, i)).x, (idx(q, i)).y)) do
local k = F.key(n.x, n.y)
if ((idx(seen, k) ~= nil)) or (not truthy(F.walkable(match, n.x, n.y))) then
goto c23
end
setidx(seen, k, true)
table.insert(q, n)
::c23::
end
::c22::
end
do return seen end
end

F.routeToRoom = function(match, sx, sy, room)
if (not truthy(room)) or (truthy(room.dead)) then
do return nil end
end
local best = nil
local consider = function(x, y)
local p = F.path(match, sx, sy, x, y)
if (truthy(p)) and ((not truthy(best)) or (((tonumber(#p) or 0) < (tonumber(#best) or 0)))) then
best = p
end
end
for _, c in ipairs(room.cells) do
if truthy(room.built) then
consider(c.x, c.y)
else
consider((c.x - 1), c.y)
consider((c.x + 1), c.y)
consider(c.x, (c.y - 1))
consider(c.x, (c.y + 1))
end
::c24::
end
do return best end
end

F.change = function(t, k, n)
setidx(t, k, math.max(0, ((function() local __a = idx(t, k); if truthy(__a) then return __a end; return 0 end)() + n)))
end

F.capacity = function(match, room, resource)
if (truthy(room.dead)) or ((((room.type ~= "core")) and (not truthy(room.built))) and ((resource ~= "mineral"))) then
do return 0 end
end
if (room.type == "core") then
if (resource == "food") then
do return PANTRY_CAP end
end
if (resource == "mineral") then
do return CORE_MINERAL_CAP end
end
if (resource == "biomass") then
do return STOCK_CAP end
end
do return 0 end
end
if not truthy(room.built) then
do return (function() if truthy((resource == "mineral")) then return math.max(0, (room.def.cost - room.materials)) else return 0 end end)() end
end
if ((room.type == "garden")) and (((resource == "food")) or ((resource == "biomass"))) then
do return STOCK_CAP end
end
if ((room.type == "extractor")) and ((resource == "mineral")) then
do return STOCK_CAP end
end
if (room.type == "kitchen") then
if (resource == "biomass") then
do return 4 end
end
if (resource == "food") then
do return (STOCK_CAP + MEALS_PER_BIO) end
end
end
if (((room.type == "quarters")) and ((resource == "food"))) and (((tonumber(room.recruited) or 0) < (tonumber(RECRUITS_PER_Q) or 0))) then
do return MEALS_PER_RECRUIT end
end
do return 0 end
end

F.available = function(room, resource)
if (truthy(room.dead)) or (not truthy(room.built)) then
do return 0 end
end
do return math.max(0, ((function() local __a = idx(room.stock, resource); if truthy(__a) then return __a end; return 0 end)() - (function() local __a = idx(room.outgoing, resource); if truthy(__a) then return __a end; return 0 end)())) end
end

F.need = function(match, room, resource)
if truthy(room.dead) then
do return 0 end
end
local incoming = (function() local __a = idx(room.incoming, resource); if truthy(__a) then return __a end; return 0 end)()
if not truthy(room.built) then
do return (function() if truthy((resource == "mineral")) then return math.max(0, ((room.def.cost - room.materials) - incoming)) else return 0 end end)() end
end
do return math.max(0, ((F.capacity(match, room, resource) - (function() local __a = idx(room.stock, resource); if truthy(__a) then return __a end; return 0 end)()) - incoming)) end
end

F.addStock = function(room, resource, amount)
if truthy(room.dead) then
do return end
end
if (not truthy(room.built)) and ((resource == "mineral")) then
room.materials = (room.materials + amount)
else
setidx(room.stock, resource, ((function() local __a = idx(room.stock, resource); if truthy(__a) then return __a end; return 0 end)() + amount))
end
end

F.extractorValid = function(match, room)
do return F.nearDeposit(match, room.cells) end
end

F.shielded = function(match, room)
if (room.type == "shield") then
do return true end
end
for _, s in ipairs(match.rooms) do
if (((s.type ~= "shield")) or (not truthy(s.built))) or (truthy(s.dead)) then
goto c25
end
local dx = ((s.cx - room.cx) / match.layout.cell)
local dy = ((s.cy - room.cy) / match.layout.cell)
if ((tonumber(hypot(dx, dy)) or 0) <= (tonumber(M.SHIELD_R) or 0)) then
do return true end
end
::c25::
end
do return false end
end

F.attachMethods = function(match)
match.walkable = function(x, y)
return F.walkable(match, x, y)
end
match.iceAt = function(x, y)
return F.iceAt(match, x, y)
end
match.ghostCells = function()
if (not truthy(idx(M.ROOMS, match.tool))) or ((match.tool == "core")) then
do return {  } end
end
do return F.rotateShape(F.playerShape(match, match.tool), match.rot) end
end
end

F.makeRoom = function(match, type, x, y, rot, instant, shape)
local def = idx(M.ROOMS, type)
local cells = F.cellsOf(type, x, y, rot, shape)
local cost = (function() if truthy((function() local __a = shape; if not truthy(__a) then return __a end; return match.mechanics.pieceQueue end)()) then return #cells else return def.cost end end)()
local room = { id = (function() local __v = match.nextId match.nextId = match.nextId + 1 return __v end)(), type = type, def = { name = def.name, cost = cost, hp = def.hp, hue = def.hue }, x = x, y = y, rot = rot, cells = cells, hp = def.hp, maxhp = def.hp, dead = false, hit = 0, built = (instant == true), materials = (function() if truthy(instant) then return cost else return 0 end end)(), progress = (function() if truthy(instant) then return 1 else return 0 end end)(), production = 0, recruited = 0, cooldown = 0, aim = ((-math.pi) / 2), overclock = 0, stunned = 0, stock = {  }, incoming = {  }, outgoing = {  }, busy = {  }, cx = 0, cy = 0, ring = 0 }
for _, c in ipairs(cells) do
local cell = { x = c.x, y = c.y, room = room }
setidx(match.grid, F.key(c.x, c.y), cell)
::c26::
end
table.insert(match.rooms, room)
F.roomCenter(match, room)
do return room end
end

F.spawnKapsel = function(match, room)
local cells = ((function() local __a = room; if truthy(__a) then return __a end; return match.core end)()).cells
local c = idx(cells, math.floor((match.rng() * #cells)))
local p = F.pixelCenter(match, c.x, c.y)
local k = { id = (function() local __v = match.nextId match.nextId = match.nextId + 1 return __v end)(), x = p.x, y = p.y, speed = (26 + (match.rng() * 6)), bob = ((match.rng() * math.pi) * 2), state = "idle", label = "Waiting", assignment = nil, job = nil, path = nil, carry = nil, workTimer = 0, retry = 0, ox = 0, oy = 0, trailT = 0, facing = 0, docked = 0 }
table.insert(match.kapsels, k)
do return k end
end

F.shuffleBag = function(rng)
local bag = copyList(BAG_ORDER)
for i = (#bag - 1), (0) + 1, -1 do
local j = math.floor((rng() * (i + 1)))
local tmp = idx(bag, i)
setidx(bag, i, idx(bag, j))
setidx(bag, j, tmp)
::c27::
end
do return bag end
end

F.pieceHasLanding = function(match)
if (not truthy(match.piece)) or (not truthy(idx(M.PIECES, match.piece))) then
do return false end
end
local types = listFilter((function() local __a = match.level.allowed; if truthy(__a) then return __a end; return { "corridor" } end)(), function(t)
return (function() local __a = idx(M.ROOMS, t); if not truthy(__a) then return __a end; return (t ~= "core") end)()
end)
match._scanLanding = true
do
local __try1 = { did = false, rv = nil }
local function __try1_fn()
for _, type in ipairs(types) do
for rot = 0, (4) - 1, 1 do
for y = 0, (match.rows) - 1, 1 do
for x = 0, (match.cols) - 1, 1 do
if truthy(F.canPlace(match, type, x, y, rot)) then
__try1.did = true
__try1.rv = true
return
end
::c31::
end
::c30::
end
::c29::
end
::c28::
end
__try1.did = true
__try1.rv = false
return
end
__try1_fn()
match._scanLanding = false
if __try1.did then do return __try1.rv end end
end
end

F.dealPiece = function(match)
if not truthy(match.bag) then
match.bag = {  }
end
for n = 0, (14) - 1, 1 do
if ((tonumber(#match.bag) or 0) < (tonumber(4) or 0)) then
appendAll(match.bag, F.shuffleBag(match.rng))
end
match.piece = table.remove(match.bag, 1)
match.queue = sliceList(match.bag, 0, 3)
if truthy(F.pieceHasLanding(match)) then
do return end
end
::c32::
end
end

F.holdPiece = function(match)
if (not truthy(match.mechanics)) or (not truthy(match.mechanics.pieceQueue)) then
do return false end
end
if not truthy(match.piece) then
do return false end
end
local cur = match.piece
if truthy(match.held) then
match.piece = match.held
match.held = cur
match.queue = sliceList((function() local __a = match.bag; if truthy(__a) then return __a end; return {  } end)(), 0, 3)
else
match.held = cur
F.dealPiece(match)
end
table.insert(match.events, { type = "hold" })
match.pulse = 0.12
do return true end
end

F.emitFx = function(match, kind, x, y, hue)
local life = (function() if truthy((kind == "muzzle")) then return 0.22 else return (function() if truthy((kind == "spark")) then return 0.9 else return (function() if truthy((kind == "pulse")) then return 0.55 else return (function() if truthy((kind == "burst")) then return 0.42 else return (function() if truthy((kind == "kiss")) then return 1.15 else return (function() if truthy((kind == "assign")) then return 0.45 else return 0.7 end end)() end end)() end end)() end end)() end end)() end end)()
table.insert(match.fx, { kind = kind, x = x, y = y, t = 0, life = life, hue = (function() local __a = hue; if truthy(__a) then return __a end; return "#f3f0e8" end)() })
end

F.gardenResource = function(match)
if not truthy(match.mechanics.kitchenChain) then
do return "food" end
end
local kitchen = listFind(match.rooms, function(r)
return (function() local __a = (function() local __a = (r.type == "kitchen"); if not truthy(__a) then return __a end; return r.built end)(); if not truthy(__a) then return __a end; return not truthy(r.dead) end)()
end)
if (truthy(kitchen)) and (((tonumber(F.staffed(match, kitchen)) or 0) >= (tonumber(1) or 0))) then
do return "biomass" end
end
do return "food" end
end

F.kitchenCooking = function(match)
local kitchen = listFind(match.rooms, function(r)
return (function() local __a = (function() local __a = (r.type == "kitchen"); if not truthy(__a) then return __a end; return r.built end)(); if not truthy(__a) then return __a end; return not truthy(r.dead) end)()
end)
do return not truthy(not truthy((function() local __a = kitchen; if not truthy(__a) then return __a end; return ((tonumber(F.staffed(match, kitchen)) or 0) >= (tonumber(1) or 0)) end)())) end
end

F.placePrebuilt = function(match, spec)
local type = spec.type
local rot = (function() local __a = spec.rot; if truthy(__a) then return __a end; return 0 end)()
local cells = F.cellsOf(type, spec.x, spec.y, rot)
for _, c in ipairs(cells) do
if (((((tonumber(c.x) or 0) < (tonumber(0) or 0))) or (((tonumber(c.y) or 0) < (tonumber(0) or 0)))) or (((tonumber(c.x) or 0) >= (tonumber(match.cols) or 0)))) or (((tonumber(c.y) or 0) >= (tonumber(match.rows) or 0))) then
do return nil end
end
if (idx(match.grid, F.key(c.x, c.y)) ~= nil) then
do return nil end
end
::c33::
end
local room = F.makeRoom(match, type, spec.x, spec.y, rot, (spec.built ~= false))
if truthy(spec.stock) then
assign(room.stock, spec.stock)
end
do return room end
end

F.createMatch = function(level, opts)
  if opts == nil then opts = {  } end
local cols = (function() local __a = level.cols; if truthy(__a) then return __a end; return 9 end)()
local rows = (function() local __a = level.rows; if truthy(__a) then return __a end; return 13 end)()
local layout = (function() local __a = opts.layout; if truthy(__a) then return __a end; return F.defaultLayout(cols, rows) end)()
local match = { levelId = level.id, level = level, name = level.name, status = "playing", loseReason = "", winReason = "", time = 0, cols = cols, rows = rows, layout = layout, rng = F.makeRng((function() local __a = (function() local __a = opts.seed; if __a == nil then return level.seed end; return __a end)(); if __a == nil then return 1 end; return __a end)()), nextId = 1, grid = {}, rooms = {  }, kapsels = {  }, enemies = {  }, shots = {  }, fx = {  }, floats = {  }, trails = {  }, core = nil, tool = "assign", rot = 0, selected = nil, hover = nil, deposits = setFrom(listMap((function() local __a = level.deposits; if truthy(__a) then return __a end; return {  } end)(), function(d)
return F.key(d.x, d.y)
end)), ice = setFrom(listMap((function() local __a = level.ice; if truthy(__a) then return __a end; return {  } end)(), function(d)
return F.key(d.x, d.y)
end)), blocked = setFrom(listMap((function() local __a = level.blocked; if truthy(__a) then return __a end; return {  } end)(), function(d)
return F.key(d.x, d.y)
end)), wells = listMap((function() local __a = level.wells; if truthy(__a) then return __a end; return {  } end)(), function(w)
return assign({}, {  }, w)
end), relics = listMap((function() local __a = level.relics; if truthy(__a) then return __a end; return {  } end)(), function(r)
return assign({}, { linked = false }, r)
end), relicCells = setFrom(listMap((function() local __a = level.relics; if truthy(__a) then return __a end; return {  } end)(), function(d)
return F.key(d.x, d.y)
end)), mechanics = assign({}, { kitchenChain = false, wormholes = false, cloak = false, overload = false }, (function() local __a = level.mechanics; if truthy(__a) then return __a end; return {  } end)()), thinkLocked = not truthy(not truthy((function() local __a = level.mechanics; if not truthy(__a) then return __a end; return level.mechanics.thinkStart end)())), waves = { index = 0, timer = (function() local __a = (function() local __a = level.waves; if not truthy(__a) then return __a end; return level.waves.first end)(); if truthy(__a) then return __a end; return 9999 end)(), interval = (function() local __a = (function() local __a = level.waves; if not truthy(__a) then return __a end; return level.waves.interval end)(); if truthy(__a) then return __a end; return 48 end)(), spec = (function() local __a = level.waves; if truthy(__a) then return __a end; return { first = 9999, interval = 48, count = 0 } end)(), incoming = false, warned = false }, wavesCleared = 0, flaresCleared = 0, folds = 0, overloads = 0, hadEnemies = false, kills = 0, shotsFired = 0, deaths = 0, flare = nil, starve = 0, shake = 0, pulse = 0, eatRate = (function() local __a = level.eatRate; if __a == nil then return 0.028 end; return __a end)(), win = (function() local __a = level.win; if truthy(__a) then return __a end; return {  } end)(), stars = 0, hint = (function() local __a = level.hint; if truthy(__a) then return __a end; return "" end)(), events = {  }, bag = {  }, piece = nil, held = nil, queue = {  }, tutorial = { needAssign = false, assigned = false, staffed = false, roomId = nil } }
local cx = (function() local __a = (function() local __a = level.core; if not truthy(__a) then return __a end; return level.core.x end)(); if truthy(__a) then return __a end; return math.floor((cols / 2)) end)()
local cy = (function() local __a = (function() local __a = level.core; if not truthy(__a) then return __a end; return level.core.y end)(); if truthy(__a) then return __a end; return math.floor((rows / 2)) end)()
local core = { id = (function() local __v = match.nextId match.nextId = match.nextId + 1 return __v end)(), type = "core", def = { name = "Core", cost = 0, hp = M.ROOMS.core.hp, hue = M.ROOMS.core.hue }, x = cx, y = cy, rot = 0, cells = { { x = cx, y = cy }, { x = (cx - 1), y = cy }, { x = (cx + 1), y = cy }, { x = cx, y = (cy - 1) }, { x = cx, y = (cy + 1) } }, hp = (function() local __a = (function() local __a = level.core; if not truthy(__a) then return __a end; return level.core.hp end)(); if truthy(__a) then return __a end; return M.ROOMS.core.hp end)(), maxhp = (function() local __a = (function() local __a = level.core; if not truthy(__a) then return __a end; return level.core.hp end)(); if truthy(__a) then return __a end; return M.ROOMS.core.hp end)(), dead = false, hit = 0, built = true, materials = 0, progress = 1, production = 0, recruited = 0, cooldown = 0, aim = 0, overclock = 0, stunned = 0, stock = { mineral = (function() local __a = (function() local __a = level.start; if not truthy(__a) then return __a end; return level.start.minerals end)(); if truthy(__a) then return __a end; return 0 end)(), food = (function() local __a = (function() local __a = level.start; if not truthy(__a) then return __a end; return level.start.food end)(); if truthy(__a) then return __a end; return 0 end)() }, incoming = {  }, outgoing = {  }, busy = {  }, cx = 0, cy = 0 }
for _, c in ipairs(core.cells) do
setidx(match.grid, F.key(c.x, c.y), { x = c.x, y = c.y, room = core })
::c34::
end
table.insert(match.rooms, core)
match.core = core
F.roomCenter(match, core)
for _, spec in ipairs((function() local __a = level.prebuilt; if truthy(__a) then return __a end; return {  } end)()) do
F.placePrebuilt(match, spec)
::c35::
end
local crew = (function() local __a = (function() local __a = level.start; if not truthy(__a) then return __a end; return level.start.crew end)(); if truthy(__a) then return __a end; return 2 end)()
for i = 0, (crew) - 1, 1 do
F.spawnKapsel(match)
::c36::
end
if truthy(match.mechanics.flares) then
local f = match.mechanics.flares
match.flare = { timer = f.first, telegraph = (function() local __a = f.telegraph; if truthy(__a) then return __a end; return 2.4 end)(), warning = 0, damage = f.damage, interval = f.interval }
end
if truthy(match.mechanics.pieceQueue) then
F.dealPiece(match)
end
if truthy(match.mechanics.teachAssign) then
match.tutorial = { needAssign = false, assigned = false, staffed = false, roomId = nil }
elseif (truthy(match.mechanics.teachStaff)) or (truthy(match.mechanics.teachScan)) then
match.tutorial = { needAssign = false, assigned = true, staffed = false, roomId = nil }
else
match.tutorial.assigned = true
match.tutorial.staffed = true
end
F.attachMethods(match)
do return match end
end

F.setTool = function(match, tool)
match.tool = tool
if ((tool ~= "assign")) and ((tool ~= "salvage")) then
match.selected = nil
end
end

F.rotate = function(match)
match.rot = ((match.rot + 1) % 4)
end

F.canPlace = function(match, type, x, y, rot)
  if rot == nil then rot = match.rot end
if ((truthy(match.tutorial)) and (truthy(match.tutorial.needAssign))) and (not truthy(match._scanLanding)) then
do return false end
end
if (not truthy(idx(M.ROOMS, type))) or ((type == "core")) then
do return false end
end
if (truthy(match.level.allowed)) and (((tonumber(listIndexOf(match.level.allowed, type)) or 0) < (tonumber(0) or 0))) then
do return false end
end
local cells = F.footprint(match, type, x, y, rot)
if not truthy(cells) then
do return false end
end
if ((type == "extractor")) and (not truthy(F.nearDeposit(match, cells))) then
do return false end
end
if ((type == "gate")) and (not truthy(match.mechanics.wormholes)) then
do return false end
end
local gates = #(listFilter(match.rooms, function(r)
return (r.type == "gate")
end))
if ((type == "gate")) and (((tonumber(gates) or 0) >= (tonumber(1) or 0))) then
do return true end
end
if not truthy(F.touchesStation(match, cells)) then
do return false end
end
do return true end
end

F.reconcileClaims = function(match)
for _, room in ipairs(match.rooms) do
room.incoming = {  }
room.outgoing = {  }
room.busy = {  }
::c37::
end
for _, k in ipairs(match.kapsels) do
local j = k.job
if (not truthy(j)) or (not truthy(j.target)) then
goto c38
end
if (j.kind == "haul") then
if (truthy(j.source)) and (not truthy(j.picked)) then
F.change(j.source.outgoing, j.resource, 1)
end
F.change(j.target.incoming, j.resource, 1)
else
if ((((truthy(j.kind)) and ((j.kind ~= "wait"))) and ((j.kind ~= "staff"))) and ((j.kind ~= "produce"))) and ((j.kind ~= "idlewalk")) then
setidx(j.target.busy, j.kind, true)
end
if truthy(j.resource) then
F.change(j.target.outgoing, j.resource, (function() local __a = j.amount; if truthy(__a) then return __a end; return 1 end)())
end
if (j.kind == "cook") then
F.change(j.target.incoming, "food", MEALS_PER_BIO)
end
end
::c38::
end
end

F.tryPlace = function(match, type, x, y)
if not truthy(F.canPlace(match, type, x, y, match.rot)) then
do return false end
end
local shape = F.playerShape(match, type)
local room = F.makeRoom(match, type, x, y, match.rot, false, shape)
if truthy(match.mechanics.pieceQueue) then
F.dealPiece(match)
end
F.emitFx(match, "spark", room.cx, room.cy, room.def.hue)
if ((truthy(match.mechanics.teachAssign)) and (truthy(match.tutorial))) and (not truthy(match.tutorial.assigned)) then
match.tutorial.needAssign = true
match.tutorial.roomId = room.id
match.tool = "assign"
else
F.assignTo(match, room)
end
table.insert(match.events, { type = "place", x = x, y = y })
match.pulse = 0.18
do return true end
end

F.nearestKapsel = function(match, room, assignedToThis)
  if assignedToThis == nil then assignedToThis = false end
local best = nil
local bestD = math.huge
for _, k in ipairs(match.kapsels) do
if (truthy(assignedToThis)) and ((k.assignment == room.id)) then
goto c39
end
if (not truthy(assignedToThis)) and ((k.assignment == room.id)) then
goto c39
end
local d = F.dist(k.x, k.y, room.cx, room.cy)
if ((tonumber(d) or 0) < (tonumber(bestD) or 0)) then
best = k
bestD = d
end
::c39::
end
do return best end
end

F.sendKapsel = function(match, k, room)
local job = F.chooseJob(match, k)
if truthy(job) then
F.startJob(k, job)
do return end
end
local from = F.atPixel(match, k.x, k.y)
local p = F.routeToRoom(match, from.x, from.y, room)
if not truthy(p) then
do return end
end
k.job = { kind = "wait", target = room, path = p }
k.path = p
k.state = (function() if truthy(#p) then return "walking" else return "working" end end)()
k.label = (function() if truthy(#p) then return "Walking" else return "Waiting" end end)()
end

F.assignTo = function(match, room)
if (not truthy(room)) or (truthy(room.dead)) then
do return false end
end
if (room.type == "core") then
do return false end
end
if (truthy(room.built)) and (((room.type == "corridor")) or ((room.type == "gate"))) then
do return false end
end
if (((truthy(match.tutorial)) and (truthy(match.tutorial.needAssign))) and ((match.tutorial.roomId ~= nil))) and ((room.id ~= match.tutorial.roomId)) then
do return false end
end
local idle = (function() local __a = listFind(match.kapsels, function(k)
return (k.assignment == nil)
end); if truthy(__a) then return __a end; return listFind(match.kapsels, function(k)
return (k.assignment == match.core.id)
end) end)()
local k = (function() local __a = idle; if truthy(__a) then return __a end; return F.nearestKapsel(match, room, true) end)()
if not truthy(k) then
do return false end
end
if not truthy((function() local __a = (function() local __a = k.job; if not truthy(__a) then return __a end; return (k.job.kind == "haul") end)(); if not truthy(__a) then return __a end; return k.carry end)()) then
F.release(k)
end
k.assignment = room.id
k.retry = 0
match.selected = room.id
room.ring = 1
k.facing = math.atan2((room.cy - k.y), (room.cx - k.x))
table.insert(match.events, { type = "assign", room = room.id })
F.emitFx(match, "assign", k.x, k.y, "#f3f0e8")
F.emitFx(match, "pulse", room.cx, room.cy, room.def.hue)
F.sendKapsel(match, k, room)
if (truthy(match.tutorial)) and (truthy(match.tutorial.needAssign)) then
match.tutorial.needAssign = false
match.tutorial.assigned = true
match.tutorial.staffed = true
end
do return true end
end

F.recallOne = function(match, room)
local k = listFind(match.kapsels, function(w)
return (w.assignment == room.id)
end)
if not truthy(k) then
do return false end
end
F.release(k)
k.assignment = nil
do return true end
end

F.recall = function(match)
local room = listFind(match.rooms, function(r)
return (r.id == match.selected)
end)
if (truthy(room)) and ((room.type ~= "core")) then
do return F.recallOne(match, room) end
end
local k = listFind(match.kapsels, function(w)
return (function() local __a = w.assignment; if not truthy(__a) then return __a end; return (w.assignment ~= match.core.id) end)()
end)
if not truthy(k) then
do return false end
end
F.release(k)
k.assignment = nil
do return true end
end

F.overloadRoom = function(match, room)
if not truthy(match.mechanics.overload) then
do return false end
end
if (not truthy(room)) or (((room.type ~= "extractor")) and ((room.type ~= "garden"))) then
do return false end
end
if ((tonumber(F.staffed(match, room)) or 0) < (tonumber(1) or 0)) then
do return false end
end
if (((tonumber(room.overclock) or 0) > (tonumber(0) or 0))) or (((tonumber(room.stunned) or 0) > (tonumber(0) or 0))) then
do return false end
end
room.overclock = OVERCLOCK_SEC
match.overloads = ((function() local __a = match.overloads; if truthy(__a) then return __a end; return 0 end)() + 1)
table.insert(match.events, { type = "overload", room = room.id })
do return true end
end

F.tapCell = function(match, gx, gy)
if (match.status ~= "playing") then
do return false end
end
if (((((tonumber(gx) or 0) < (tonumber(0) or 0))) or (((tonumber(gy) or 0) < (tonumber(0) or 0)))) or (((tonumber(gx) or 0) >= (tonumber(match.cols) or 0)))) or (((tonumber(gy) or 0) >= (tonumber(match.rows) or 0))) then
do return false end
end
local room = F.roomAt(match, gx, gy)
if (match.tool == "assign") then
if not truthy(room) then
do return false end
end
if ((match.selected == room.id)) and (((tonumber((F.staffed(match, room) + #(listFilter(match.kapsels, function(k)
return (k.assignment == room.id)
end)))) or 0) > (tonumber(0) or 0))) then
if (room.type == "core") then
do return F.recallOne(match, (function() local __a = listFind(match.rooms, function(r)
return (r.id == match.selected)
end); if truthy(__a) then return __a end; return room end)()) end
end
end
do return F.assignTo(match, room) end
end
if (match.tool == "salvage") then
if (not truthy(room)) or ((room.type == "core")) then
do return false end
end
F.salvage(match, room)
do return true end
end
if (match.tool == "overload") then
if not truthy(room) then
do return false end
end
do return F.overloadRoom(match, room) end
end
if truthy(room) then
do return F.assignTo(match, room) end
end
if (match.tool == "assign") then
do return false end
end
do return F.tryPlace(match, match.tool, gx, gy) end
end

F.salvage = function(match, room)
local salvageAmt = (function() if truthy(room.built) then return math.floor((room.def.cost / 2)) else return room.materials end end)()
F.addStock(match.core, "mineral", (salvageAmt + (function() local __a = room.stock.mineral; if truthy(__a) then return __a end; return 0 end)()))
F.addStock(match.core, "food", (function() local __a = room.stock.food; if truthy(__a) then return __a end; return 0 end)())
F.removeRoom(match, room)
table.insert(match.events, { type = "salvage" })
end

F.removeRoom = function(match, room)
if truthy(room.dead) then
do return end
end
room.dead = true
for _, c in ipairs(room.cells) do
setidx(match.grid, F.key(c.x, c.y), nil)
::c40::
end
match.rooms = listFilter(match.rooms, function(r)
return (r ~= room)
end)
for _, k in ipairs(match.kapsels) do
if (k.assignment == room.id) then
k.assignment = nil
end
if (truthy(k.job)) and ((k.job.target == room)) then
F.release(k)
end
::c41::
end
end

F.release = function(k)
local j = k.job
if truthy(j) then
if (j.kind == "haul") then
if (truthy(j.source)) and (not truthy(j.picked)) then
F.change(j.source.outgoing, j.resource, (-1))
end
F.change(j.target.incoming, j.resource, (-1))
elseif truthy(j.target) then
if truthy(j.kind) then
setidx(j.target.busy, j.kind, nil)
end
if truthy(j.resource) then
F.change(j.target.outgoing, j.resource, (-((function() local __a = j.amount; if truthy(__a) then return __a end; return 1 end)())))
end
if (j.kind == "cook") then
F.change(j.target.incoming, "food", (-MEALS_PER_BIO))
end
end
end
k.job = nil
k.path = nil
k.state = "idle"
k.label = (function() if truthy(k.carry) then return "Carrying" else return "Waiting" end end)()
end

F.assignedRoom = function(match, k)
if (k.assignment == nil) then
do return nil end
end
do return (function() local __a = listFind(match.rooms, function(r)
return (r.id == k.assignment)
end); if truthy(__a) then return __a end; return nil end)() end
end

F.findHaul = function(match, k, resource, target)
if ((tonumber(F.need(match, target, resource)) or 0) < (tonumber(1) or 0)) then
do return nil end
end
for _, source in ipairs(match.rooms) do
if (source == target) then
goto c42
end
if ((source.type == "quarters")) and ((resource == "food")) then
goto c42
end
if ((source.type == "kitchen")) and ((resource == "biomass")) then
goto c42
end
local reserve = (function() if truthy((function() local __a = (function() local __a = (source.type == "core"); if not truthy(__a) then return __a end; return (resource == "food") end)(); if not truthy(__a) then return __a end; return (target.type == "quarters") end)()) then return 0 else return 0 end end)()
if ((tonumber(F.available(source, resource)) or 0) >= (tonumber((1 + reserve)) or 0)) then
local from = F.atPixel(match, k.x, k.y)
local pickup = F.routeToRoom(match, from.x, from.y, source)
if not truthy(pickup) then
goto c42
end
local _end = (function() if truthy(#pickup) then return idx(pickup, (#pickup - 1)) else return from end end)()
local drop = F.routeToRoom(match, _end.x, _end.y, target)
if truthy(drop) then
do return { kind = "haul", source = source, target = target, resource = resource, picked = false, phase = "pickup", path = pickup } end
end
end
::c42::
end
do return nil end
end

F.startJob = function(k, job)
k.job = job
k.path = (function() local __a = job.path; if truthy(__a) then return __a end; return {  } end)()
k.state = (function() if truthy(#k.path) then return "walking" else return "working" end end)()
k.workTimer = 0
if (job.kind == "haul") then
if (truthy(job.source)) and (not truthy(job.picked)) then
F.change(job.source.outgoing, job.resource, 1)
end
F.change(job.target.incoming, job.resource, 1)
k.label = (function() if truthy(job.picked) then return "Delivering" else return "Collecting" end end)()
else
if truthy(job.kind) then
setidx(job.target.busy, job.kind, true)
end
if truthy(job.resource) then
F.change(job.target.outgoing, job.resource, (function() local __a = job.amount; if truthy(__a) then return __a end; return 1 end)())
end
if (job.kind == "cook") then
F.change(job.target.incoming, "food", MEALS_PER_BIO)
end
k.label = (function() local __a = job.kind; if truthy(__a) then return __a end; return "Working" end)()
end
end

F.chooseJob = function(match, k)
local room = F.assignedRoom(match, k)
local from = F.atPixel(match, k.x, k.y)
if truthy(k.carry) then
local target = (function() if truthy((function() local __a = room; if not truthy(__a) then return __a end; return ((tonumber(F.need(match, room, k.carry)) or 0) >= (tonumber(1) or 0)) end)()) then return room else return match.core end end)()
local p = F.routeToRoom(match, from.x, from.y, target)
if not truthy(p) then
do return nil end
end
do return { kind = "haul", source = nil, target = target, resource = k.carry, picked = true, phase = "delivery", path = p } end
end
if not truthy(room) then
local p = F.routeToRoom(match, from.x, from.y, match.core)
if (truthy(p)) and (truthy(#p)) then
do return { kind = "idlewalk", target = match.core, path = p } end
end
do return nil end
end
if not truthy(room.built) then
local haul = F.findHaul(match, k, "mineral", room)
if truthy(haul) then
do return haul end
end
if (((tonumber(room.materials) or 0) >= (tonumber(room.def.cost) or 0))) and (not truthy(room.busy.build)) then
local p = F.routeToRoom(match, from.x, from.y, room)
if truthy(p) then
do return { kind = "build", target = room, path = p } end
end
end
local wait = F.routeToRoom(match, from.x, from.y, room)
if truthy(wait) then
do return { kind = "wait", target = room, path = wait } end
end
do return nil end
end
if (room.type == "garden") then
local res = F.gardenResource(match)
local dest = (function() if truthy((res == "biomass")) then return (function() local __a = listFind(match.rooms, function(r)
return (function() local __a = (function() local __a = (r.type == "kitchen"); if not truthy(__a) then return __a end; return r.built end)(); if not truthy(__a) then return __a end; return ((tonumber(F.need(match, r, "biomass")) or 0) >= (tonumber(1) or 0)) end)()
end); if truthy(__a) then return __a end; return match.core end)() else return match.core end end)()
if (((tonumber(F.available(room, res)) or 0) >= (tonumber(1) or 0))) and (((tonumber(F.need(match, dest, res)) or 0) >= (tonumber(1) or 0))) then
local haul = F.findHaul(match, k, res, dest)
if truthy(haul) then
do return haul end
end
end
local p = F.routeToRoom(match, from.x, from.y, room)
if truthy(p) then
do return { kind = "produce", target = room, path = p } end
end
end
if (room.type == "extractor") then
if (((tonumber(F.available(room, "mineral")) or 0) >= (tonumber(1) or 0))) and (((tonumber(F.need(match, match.core, "mineral")) or 0) >= (tonumber(1) or 0))) then
local haul = F.findHaul(match, k, "mineral", match.core)
if truthy(haul) then
do return haul end
end
end
local p = F.routeToRoom(match, from.x, from.y, room)
if truthy(p) then
do return { kind = "produce", target = room, path = p } end
end
end
if (room.type == "kitchen") then
if (((tonumber(F.available(room, "food")) or 0) >= (tonumber(1) or 0))) and (((tonumber(F.need(match, match.core, "food")) or 0) >= (tonumber(1) or 0))) then
local haul = F.findHaul(match, k, "food", match.core)
if truthy(haul) then
do return haul end
end
end
if ((not truthy(room.busy.cook)) and (((tonumber(F.available(room, "biomass")) or 0) >= (tonumber(1) or 0)))) and (((tonumber(F.need(match, room, "food")) or 0) >= (tonumber(MEALS_PER_BIO) or 0))) then
local p = F.routeToRoom(match, from.x, from.y, room)
if truthy(p) then
do return { kind = "cook", target = room, resource = "biomass", amount = 1, path = p } end
end
end
if ((tonumber(F.need(match, room, "biomass")) or 0) >= (tonumber(1) or 0)) then
local haul = F.findHaul(match, k, "biomass", room)
if truthy(haul) then
do return haul end
end
end
local p = F.routeToRoom(match, from.x, from.y, room)
if truthy(p) then
do return { kind = "wait", target = room, path = p } end
end
end
if (room.type == "quarters") then
if ((not truthy(room.busy.recruit)) and (((tonumber(room.recruited) or 0) < (tonumber(RECRUITS_PER_Q) or 0)))) and (((tonumber(F.available(room, "food")) or 0) >= (tonumber(MEALS_PER_RECRUIT) or 0))) then
local p = F.routeToRoom(match, from.x, from.y, room)
if truthy(p) then
do return { kind = "recruit", target = room, resource = "food", amount = MEALS_PER_RECRUIT, path = p } end
end
end
if ((tonumber(F.need(match, room, "food")) or 0) >= (tonumber(1) or 0)) then
local haul = F.findHaul(match, k, "food", room)
if truthy(haul) then
do return haul end
end
end
local p = F.routeToRoom(match, from.x, from.y, room)
if truthy(p) then
do return { kind = "wait", target = room, path = p } end
end
end
if ((((room.type == "weapons")) or ((room.type == "heater"))) or ((room.type == "scanner"))) or ((room.type == "beacon")) then
local p = F.routeToRoom(match, from.x, from.y, room)
if truthy(p) then
do return { kind = "staff", target = room, path = p } end
end
end
if (truthy(room.built)) and ((((room.type == "corridor")) or ((room.type == "gate"))) or ((room.type == "shield"))) then
k.assignment = nil
local home = F.routeToRoom(match, from.x, from.y, match.core)
if (truthy(home)) and (truthy(#home)) then
do return { kind = "idlewalk", target = match.core, path = home } end
end
do return nil end
end
local p = F.routeToRoom(match, from.x, from.y, room)
if truthy(p) then
do return { kind = "wait", target = room, path = p } end
end
do return nil end
end

F.stepAlong = function(match, k, dt)
local node = (function() local __a = k.path; if not truthy(__a) then return __a end; return idx(k.path, 0) end)()
if not truthy(node) then
do return true end
end
local here = F.atPixel(match, k.x, k.y)
local man = (math.abs((here.x - node.x)) + math.abs((here.y - node.y)))
if ((tonumber(man) or 0) > (tonumber(1) or 0)) then
local p = F.pixelCenter(match, node.x, node.y)
k.facing = math.atan2((p.y - k.y), (p.x - k.x))
k.x = p.x
k.y = p.y
table.remove(k.path, 1)
match.folds = ((function() local __a = match.folds; if truthy(__a) then return __a end; return 0 end)() + 1)
table.insert(match.events, { type = "fold" })
F.emitFx(match, "pulse", p.x, p.y, "#9b7ad4")
do return (#k.path == 0) end
end
local p = F.pixelCenter(match, node.x, node.y)
local dx = (p.x - k.x)
local dy = (p.y - k.y)
if (truthy(dx)) or (truthy(dy)) then
k.facing = math.atan2(dy, dx)
end
local d = hypot(dx, dy)
local speed = k.speed
local g = F.atPixel(match, k.x, k.y)
if truthy(F.iceAt(match, g.x, g.y)) then
speed = (speed * 0.38)
end
local step = (speed * dt)
if ((tonumber(d) or 0) <= (tonumber(step) or 0)) then
k.x = p.x
k.y = p.y
table.remove(k.path, 1)
table.insert(match.events, { type = "tick" })
do return (#k.path == 0) end
end
k.x = (k.x + ((dx / d) * step))
k.y = (k.y + ((dy / d) * step))
do return false end
end

F.produceRate = function(room)
local mul = 1
if ((tonumber(room.overclock) or 0) > (tonumber(0) or 0)) then
mul = 2.4
end
if ((tonumber(room.stunned) or 0) > (tonumber(0) or 0)) then
mul = 0
end
do return mul end
end

F.work = function(match, k, dt)
local j = k.job
if not truthy(j) then
do return end
end
local room = j.target
k.workTimer = (k.workTimer + dt)
if (j.kind == "haul") then
if ((tonumber(k.workTimer) or 0) < (tonumber(PICK_SEC) or 0)) then
do return end
end
if (j.phase == "pickup") then
if ((tonumber((function() local __a = idx(j.source.stock, j.resource); if truthy(__a) then return __a end; return 0 end)()) or 0) < (tonumber(1) or 0)) then
F.release(k)
do return end
end
F.change(j.source.stock, j.resource, (-1))
F.change(j.source.outgoing, j.resource, (-1))
j.picked = true
k.carry = j.resource
j.phase = "delivery"
local from = F.atPixel(match, k.x, k.y)
k.path = (function() local __a = F.routeToRoom(match, from.x, from.y, room); if truthy(__a) then return __a end; return {  } end)()
k.state = "walking"
k.label = "Delivering"
k.workTimer = 0
else
F.addStock(room, j.resource, 1)
k.carry = nil
table.insert(match.events, { type = "haul", resource = j.resource })
F.emitFx(match, "dust", room.cx, room.cy, (function() if truthy((j.resource == "mineral")) then return "#e07898" else return "#f0c24a" end end)())
F.release(k)
end
elseif (j.kind == "build") then
room.progress = math.min(1, (room.progress + (dt / (BUILD_SEC * math.max(1, room.def.cost)))))
if ((tonumber(room.progress) or 0) >= (tonumber(1) or 0)) then
room.built = true
F.roomCenter(match, room)
table.insert(match.events, { type = "built", room = room.id })
F.emitFx(match, "dust", room.cx, room.cy, room.def.hue)
if ((room.type == "corridor")) or ((room.type == "gate")) then
k.assignment = nil
end
local teachGarden = (function() local __a = match.mechanics.teachStaff; if not truthy(__a) then return __a end; return (room.type == "garden") end)()
local teachScan = (function() local __a = match.mechanics.teachScan; if not truthy(__a) then return __a end; return (room.type == "scanner") end)()
if (((truthy(teachGarden)) or (truthy(teachScan))) and (truthy(match.tutorial))) and (not truthy(match.tutorial.staffed)) then
for _, w in ipairs(match.kapsels) do
if (w.assignment == room.id) then
F.release(w)
w.assignment = nil
end
::c43::
end
match.tutorial.needAssign = true
match.tutorial.roomId = room.id
match.tool = "assign"
end
F.release(k)
end
elseif (j.kind == "wait") then
if ((tonumber(k.workTimer) or 0) > (tonumber(0.35) or 0)) then
F.release(k)
end
elseif (j.kind == "produce") then
if ((tonumber(room.stunned) or 0) > (tonumber(0) or 0)) then
do return end
end
local resource = (function() if truthy((room.type == "extractor")) then return "mineral" else return F.gardenResource(match) end end)()
local dest = (function() if truthy((resource == "biomass")) then return (function() local __a = listFind(match.rooms, function(r)
return (function() local __a = (function() local __a = (r.type == "kitchen"); if not truthy(__a) then return __a end; return r.built end)(); if not truthy(__a) then return __a end; return not truthy(r.dead) end)()
end); if truthy(__a) then return __a end; return match.core end)() else return match.core end end)()
if ((((tonumber(F.available(room, resource)) or 0) >= (tonumber(1) or 0))) and (truthy(dest))) and (((tonumber(F.need(match, dest, resource)) or 0) >= (tonumber(1) or 0))) then
F.release(k)
do return end
end
if ((room.type == "extractor")) and (not truthy(F.extractorValid(match, room))) then
do return end
end
local duration = (function() if truthy((resource == "mineral")) then return MINERAL_SEC else return FOOD_SEC end end)()
room.production = (room.production + (dt * F.produceRate(room)))
if (((tonumber(room.production) or 0) >= (tonumber(duration) or 0))) and (((tonumber(F.need(match, room, resource)) or 0) >= (tonumber(1) or 0))) then
F.addStock(room, resource, 1)
room.production = (room.production - duration)
table.insert(match.floats, { x = room.cx, y = room.cy, text = "+", life = 0.7, t = 0, color = resource })
local hue = (function() if truthy((resource == "mineral")) then return "#e07898" else return "#5ea86a" end end)()
F.emitFx(match, "dust", room.cx, room.cy, hue)
F.emitFx(match, "pulse", room.cx, room.cy, hue)
table.insert(match.events, { type = (function() if truthy((resource == "mineral")) then return "mine" else return "grow" end end)() })
F.release(k)
end
elseif (j.kind == "cook") then
if ((tonumber(k.workTimer) or 0) >= (tonumber(COOK_SEC) or 0)) then
F.change(room.stock, "biomass", (-1))
F.addStock(room, "food", MEALS_PER_BIO)
table.insert(match.events, { type = "cook" })
F.emitFx(match, "pulse", room.cx, room.cy, "#f0c24a")
F.release(k)
end
elseif (j.kind == "recruit") then
if ((tonumber(k.workTimer) or 0) >= (tonumber(RECRUIT_SEC) or 0)) then
F.spawnKapsel(match, room)
F.change(room.stock, "food", (-MEALS_PER_RECRUIT))
room.recruited = (room.recruited + 1)
table.insert(match.events, { type = "recruit" })
F.release(k)
end
end
end

F.validJob = function(match, k)
local j = k.job
if not truthy(j) then
do return false end
end
if (truthy(j.target)) and (truthy(j.target.dead)) then
do return false end
end
if ((((j.kind == "haul")) and (not truthy(j.picked))) and (truthy(j.source))) and (truthy(j.source.dead)) then
do return false end
end
if ((j.kind == "build")) and (truthy(j.target.built)) then
do return false end
end
for _, n in ipairs((function() local __a = j.path; if truthy(__a) then return __a end; return {  } end)()) do
if not truthy(F.walkable(match, n.x, n.y)) then
do return false end
end
::c44::
end
do return true end
end

F.loseKapsel = function(match, index, reason)
local k = idx(match.kapsels, index)
F.release(k)
if truthy(k.carry) then
F.addStock(match.core, k.carry, 1)
end
table.remove(match.kapsels, (index) + 1)
match.deaths = (match.deaths + 1)
match.loseReason = reason
table.insert(match.events, { type = "death" })
match.shake = 0.25
end

F.updateKapsels = function(match, dt)
F.reconcileClaims(match)
for i = (#match.kapsels - 1), 0, -1 do
local k = idx(match.kapsels, i)
k.bob = (k.bob + (dt * 8))
local g = F.atPixel(match, k.x, k.y)
if not truthy(F.walkable(match, g.x, g.y)) then
local best = nil
local bestD = math.huge
for kk, cell in pairs(match.grid) do
if not truthy(cell.room.built) then
goto c46
end
local p = F.pixelCenter(match, cell.x, cell.y)
local d = (math.abs((p.x - k.x)) + math.abs((p.y - k.y)))
if (((tonumber(d) or 0) <= (tonumber((match.layout.cell * 1.15)) or 0))) and (((tonumber(d) or 0) < (tonumber(bestD) or 0))) then
best = cell
bestD = d
end
::c46::
end
F.release(k)
if truthy(best) then
local p = F.pixelCenter(match, best.x, best.y)
k.x = p.x
k.y = p.y
else
local home = idx(match.core.cells, 0)
local p = F.pixelCenter(match, home.x, home.y)
k.x = p.x
k.y = p.y
k.assignment = nil
k.path = {  }
k.job = nil
end
end
if (truthy(k.job)) and (not truthy(F.validJob(match, k))) then
F.release(k)
end
if not truthy(k.job) then
k.retry = (k.retry - dt)
if ((tonumber(k.retry) or 0) <= (tonumber(0) or 0)) then
local job = F.chooseJob(match, k)
if truthy(job) then
F.startJob(k, job)
else
k.retry = 0.28
end
end
elseif (k.state == "walking") then
if truthy(k.carry) then
k.trailT = ((function() local __a = k.trailT; if truthy(__a) then return __a end; return 0 end)() + dt)
if ((tonumber(k.trailT) or 0) >= (tonumber(0.16) or 0)) then
k.trailT = 0
table.insert(match.trails, { x = k.x, y = k.y, resource = k.carry, t = 0, life = 0.85 })
if ((tonumber(#match.trails) or 0) > (tonumber(40) or 0)) then
table.remove(match.trails, 1)
end
end
end
if truthy(F.stepAlong(match, k, dt)) then
k.state = "working"
k.workTimer = 0
local dest = (function() local __a = k.job; if not truthy(__a) then return __a end; return k.job.target end)()
if (truthy(dest)) and ((k.assignment == dest.id)) then
table.insert(match.events, { type = "dock", room = dest.id })
F.emitFx(match, "pulse", dest.cx, dest.cy, dest.def.hue)
dest.ring = math.max((function() local __a = dest.ring; if truthy(__a) then return __a end; return 0 end)(), 0.85)
k.docked = 1
end
end
else
F.work(match, k, dt)
end
::c45::
end
F.applyCrowd(match)
end

F.applyCrowd = function(match)
local groups = {}
for _, k in ipairs(match.kapsels) do
local g = F.atPixel(match, k.x, k.y)
local id = (g.x .. (",")) .. g.y
if not truthy((idx(groups, id) ~= nil)) then
setidx(groups, id, {  })
end
table.insert(idx(groups, id), k)
::c47::
end
for _, pack in pairs(groups) do
listSort(pack, function(a, b)
return (a.id - b.id)
end)
local n = #pack
listForEach(pack, function(k, i)
if ((tonumber(n) or 0) <= (tonumber(1) or 0)) then
k.ox = 0
k.oy = 0
do return end
end
local ang = ((((i / n) * math.pi) * 2) - (math.pi / 2))
local r = math.min((match.layout.cell * 0.26), 12)
k.ox = (math.cos(ang) * r)
k.oy = (math.sin(ang) * r)
end)
::c48::
end
end

F.waveCount = function(spec, n)
if (jsType(spec.count) == "function") then
do return spec.count(n) end
end
if (spec.count == nil) then
do return (1 + n) end
end
do return spec.count end
end

F.spawnWave = function(match)
local spec = match.waves.spec
match.waves.index = (match.waves.index + 1)
local n = match.waves.index
local count = F.waveCount(spec, n)
local hp = (function() if truthy((jsType(spec.hp) == "function")) then return spec.hp(n) else return (function() local __a = spec.hp; if truthy(__a) then return __a end; return (22 + (n * 14)) end)() end end)()
local speed = (function() if truthy((spec.speed ~= nil)) then return spec.speed else return math.min(48, (18 + (n * 1.7))) end end)()
local sides = (function() local __a = spec.sides; if truthy(__a) then return __a end; return { "n", "s", "e", "w" } end)()
local cloak = (function() local __a = not truthy(not truthy(match.mechanics.cloak)); if not truthy(__a) then return __a end; return (function() local __a = (function() local __a = spec.cloak; if truthy(__a) then return __a end; return ((tonumber(n) or 0) >= (tonumber((function() local __a = spec.cloakFrom; if truthy(__a) then return __a end; return 99 end)()) or 0)) end)(); if truthy(__a) then return __a end; return match.mechanics.cloakAll end)() end)()
for i = 0, (count) - 1, 1 do
local side = idx(sides, math.floor((match.rng() * #sides)))
local x
local y
local L = match.layout
if (side == "n") then
x = (L.ox + (match.rng() * L.gridW))
y = (L.oy - 28)
elseif (side == "s") then
x = (L.ox + (match.rng() * L.gridW))
y = ((L.oy + L.gridH) + 28)
elseif (side == "w") then
x = (L.ox - 28)
y = (L.oy + (match.rng() * L.gridH))
else
x = ((L.ox + L.gridW) + 28)
y = (L.oy + (match.rng() * L.gridH))
end
table.insert(match.enemies, { x = x, y = y, hp = hp, maxhp = hp, speed = (speed + (match.rng() * 5)), dps = (function() local __a = spec.dps; if truthy(__a) then return __a end; return (4.2 + (n * 0.7)) end)(), r = 8, cloaked = (function() local __a = cloak; if truthy(__a) then return __a end; return not truthy(not truthy(spec.cloaked)) end)(), vx = 0, vy = 0, dir = 0, target = nil, state = "walking", hitTimer = 0, wobble = ((match.rng() * math.pi) * 2) })
::c49::
end
table.insert(match.events, { type = "wave", n = n })
match.pulse = 0.4
end

F.nearestCell = function(match, px, py)
local best = nil
local bestD = math.huge
for _, cell in pairs(match.grid) do
local p = F.pixelCenter(match, cell.x, cell.y)
local d = F.dist(p.x, p.y, px, py)
if ((tonumber(d) or 0) < (tonumber(bestD) or 0)) then
best = cell
bestD = d
end
::c50::
end
do return best end
end

F.applyGravity = function(match, e, dt)
for _, well in ipairs(match.wells) do
local p = F.pixelCenter(match, well.x, well.y)
local dx = (p.x - e.x)
local dy = (p.y - e.y)
local d = (function() local __a = hypot(dx, dy); if truthy(__a) then return __a end; return 1 end)()
local str = (function() local __a = well.strength; if truthy(__a) then return __a end; return 40 end)()
e.vx = (e.vx + (((dx / d) * str) * dt))
e.vy = (e.vy + (((dy / d) * str) * dt))
::c51::
end
e.x = (e.x + (e.vx * dt))
e.y = (e.y + (e.vy * dt))
e.vx = (e.vx * 0.98)
e.vy = (e.vy * 0.98)
end

F.updateEnemies = function(match, dt)
match.waves.timer = (match.waves.timer - dt)
if ((((not truthy(match.waves.warned)) and (((tonumber(match.waves.timer) or 0) <= (tonumber(8) or 0)))) and (((tonumber(match.waves.timer) or 0) > (tonumber(0) or 0)))) and (((tonumber(match.waves.timer) or 0) < (tonumber(900) or 0)))) and ((match.status == "playing")) then
local spec = match.waves.spec
local maxW = (function() local __a = (function() local __a = spec.max; if truthy(__a) then return __a end; return spec["until"] end)(); if truthy(__a) then return __a end; return 99 end)()
if (((tonumber(match.waves.index) or 0) < (tonumber(maxW) or 0))) and (((tonumber(F.waveCount(spec, (match.waves.index + 1))) or 0) > (tonumber(0) or 0))) then
match.waves.warned = true
table.insert(match.events, { type = "incoming", n = (match.waves.index + 1) })
end
end
if (((tonumber(match.waves.timer) or 0) <= (tonumber(0) or 0))) and ((match.status == "playing")) then
local spec = match.waves.spec
local maxW = (function() local __a = (function() local __a = spec.max; if truthy(__a) then return __a end; return spec["until"] end)(); if truthy(__a) then return __a end; return 99 end)()
if (((tonumber(match.waves.index) or 0) < (tonumber(maxW) or 0))) and (((tonumber(F.waveCount(spec, (match.waves.index + 1))) or 0) > (tonumber(0) or 0))) then
F.spawnWave(match)
match.waves.timer = match.waves.interval
match.waves.warned = false
else
match.waves.timer = 9999
end
end
for i = (#match.enemies - 1), 0, -1 do
local e = idx(match.enemies, i)
e.wobble = (e.wobble + (dt * 3))
e.hitTimer = math.max(0, ((function() local __a = e.hitTimer; if truthy(__a) then return __a end; return 0 end)() - dt))
F.applyGravity(match, e, dt)
if (((not truthy(e.target)) or (not truthy(e.target.room))) or (truthy(e.target.room.dead))) or (not truthy(idx(match.grid, F.key(e.target.x, e.target.y)))) then
e.target = F.nearestCell(match, e.x, e.y)
e.state = "walking"
end
if truthy(e.target) then
local p = F.pixelCenter(match, e.target.x, e.target.y)
local dx = (p.x - e.x)
local dy = (p.y - e.y)
local d = (function() local __a = hypot(dx, dy); if truthy(__a) then return __a end; return 1 end)()
if (e.state == "walking") then
if ((tonumber(d) or 0) < (tonumber(4) or 0)) then
e.state = "attacking"
else
e.x = (e.x + (((dx / d) * e.speed) * dt))
e.y = (e.y + (((dy / d) * e.speed) * dt))
e.dir = math.atan2(dy, dx)
end
end
if (e.state == "attacking") then
local room = e.target.room
if (not truthy(room)) or (truthy(room.dead)) then
e.target = nil
else
e.cloaked = false
room.hp = (room.hp - (e.dps * dt))
room.hit = 0.16
if ((tonumber(room.hp) or 0) <= (tonumber(0) or 0)) then
match.shake = 0.4
table.insert(match.events, { type = "destroy", room = room.type })
if (room.type == "core") then
room.dead = true
match.status = "lost"
match.loseReason = "The core came apart"
else
F.removeRoom(match, room)
end
e.target = nil
end
end
end
end
if ((tonumber(e.hp) or 0) <= (tonumber(0) or 0)) then
match.kills = (match.kills + 1)
F.emitFx(match, "burst", e.x, e.y, "#e24b52")
F.emitFx(match, "pulse", e.x, e.y, "#f3f0e8")
match.pulse = math.max(match.pulse, 0.28)
match.shake = math.max(match.shake, 0.18)
table.remove(match.enemies, (i) + 1)
table.insert(match.events, { type = "kill" })
end
::c52::
end
for _, room in ipairs(match.rooms) do
if (((room.type ~= "weapons")) or (not truthy(room.built))) or (truthy(room.dead)) then
goto c53
end
if ((tonumber(F.staffed(match, room)) or 0) < (tonumber(1) or 0)) then
goto c53
end
room.cooldown = (room.cooldown - dt)
if ((tonumber(room.cooldown) or 0) > (tonumber(0) or 0)) then
goto c53
end
local best = nil
local bestD = math.huge
for _, e in ipairs(match.enemies) do
if truthy(e.cloaked) then
goto c54
end
local d = F.dist(e.x, e.y, room.cx, room.cy)
if (((tonumber(d) or 0) < (tonumber(F.gunRange(match)) or 0))) and (((tonumber(d) or 0) < (tonumber(bestD) or 0))) then
best = e
bestD = d
end
::c54::
end
if truthy(best) then
room.cooldown = TURRET_CD
room.aim = math.atan2((best.y - room.cy), (best.x - room.cx))
table.insert(match.shots, { x = room.cx, y = room.cy, target = best, speed = 340 })
match.shotsFired = (match.shotsFired + 1)
match.pulse = math.max(match.pulse, 0.16)
F.emitFx(match, "muzzle", room.cx, room.cy, "#f8f4e8")
table.insert(match.events, { type = "shoot" })
end
::c53::
end
for i = (#match.shots - 1), 0, -1 do
local s = idx(match.shots, i)
local e = s.target
if ((not truthy(e)) or (((tonumber(e.hp) or 0) <= (tonumber(0) or 0)))) or (((tonumber(listIndexOf(match.enemies, e)) or 0) < (tonumber(0) or 0))) then
table.remove(match.shots, (i) + 1)
goto c55
end
local dx = (e.x - s.x)
local dy = (e.y - s.y)
local d = (function() local __a = hypot(dx, dy); if truthy(__a) then return __a end; return 1 end)()
local step = (s.speed * dt)
if ((tonumber(d) or 0) <= (tonumber((step + e.r)) or 0)) then
e.hp = (e.hp - TURRET_DMG)
e.hitTimer = 0.2
F.emitFx(match, "spark", e.x, e.y, "#f3f0e8")
table.remove(match.shots, (i) + 1)
else
s.x = (s.x + ((dx / d) * step))
s.y = (s.y + ((dy / d) * step))
end
::c55::
end
if ((tonumber(#match.enemies) or 0) > (tonumber(0) or 0)) then
match.hadEnemies = true
elseif truthy(match.hadEnemies) then
match.hadEnemies = false
match.wavesCleared = match.waves.index
table.insert(match.events, { type = "cleared" })
end
end

F.updateHeaters = function(match, dt)
for _, room in ipairs(match.rooms) do
if (((room.type ~= "heater")) or (not truthy(room.built))) or (truthy(room.dead)) then
goto c56
end
for iceKey in pairs(match.ice) do
local x, y = splitKey(iceKey)
local warm = listSome(room.cells, function(c)
return ((tonumber(hypot((x - c.x), (y - c.y))) or 0) <= (tonumber(HEATER_R) or 0))
end)
if truthy(warm) then
setidx(match.ice, iceKey, nil)
end
::c57::
end
::c56::
end
end

F.updateScanners = function(match)
for _, room in ipairs(match.rooms) do
if (((room.type ~= "scanner")) or (not truthy(room.built))) or (truthy(room.dead)) then
goto c58
end
if ((tonumber(F.staffed(match, room)) or 0) < (tonumber(1) or 0)) then
goto c58
end
for _, e in ipairs(match.enemies) do
if ((tonumber(F.dist(e.x, e.y, room.cx, room.cy)) or 0) <= (tonumber(F.scanRange(match)) or 0)) then
e.cloaked = false
end
::c59::
end
::c58::
end
end

F.updateFlares = function(match, dt)
local f = match.flare
if not truthy(f) then
do return end
end
f.timer = (f.timer - dt)
if ((((tonumber(f.telegraph) or 0) > (tonumber(0) or 0))) and (((tonumber(f.timer) or 0) <= (tonumber(f.telegraph) or 0)))) and (((tonumber(f.timer) or 0) > (tonumber(0) or 0))) then
f.warning = (1 - (f.timer / f.telegraph))
else
f.warning = 0
end
if ((tonumber(f.timer) or 0) <= (tonumber(0) or 0)) then
for _, room in ipairs(match.rooms) do
if (truthy(room.dead)) or (not truthy(room.built)) then
goto c60
end
if truthy(F.shielded(match, room)) then
goto c60
end
room.hp = (room.hp - f.damage)
room.hit = 0.35
if ((tonumber(room.hp) or 0) <= (tonumber(0) or 0)) then
if (room.type == "core") then
match.status = "lost"
match.loseReason = "A flare unstitched the core"
room.dead = true
else
F.removeRoom(match, room)
end
end
::c60::
end
table.insert(match.events, { type = "flare" })
match.flaresCleared = ((function() local __a = match.flaresCleared; if truthy(__a) then return __a end; return 0 end)() + 1)
match.shake = 0.35
f.timer = f.interval
f.warning = 0
end
end

F.updateOverclock = function(match, dt)
for _, room in ipairs(match.rooms) do
if ((tonumber(room.overclock) or 0) > (tonumber(0) or 0)) then
room.overclock = (room.overclock - dt)
if ((tonumber(room.overclock) or 0) <= (tonumber(0) or 0)) then
room.overclock = 0
room.hp = (room.hp - OVERCLOCK_HURT)
room.stunned = 3.2
room.hit = 0.4
if ((tonumber(room.hp) or 0) <= (tonumber(0) or 0)) then
F.removeRoom(match, room)
end
end
end
if ((tonumber(room.stunned) or 0) > (tonumber(0) or 0)) then
room.stunned = (room.stunned - dt)
end
if ((tonumber(room.hit) or 0) > (tonumber(0) or 0)) then
room.hit = math.max(0, (room.hit - dt))
end
::c61::
end
end

F.updateRelics = function(match)
for _, relic in ipairs(match.relics) do
if truthy(relic.linked) then
goto c62
end
local dirs = { { 0, 0 }, { 1, 0 }, { (-1), 0 }, { 0, 1 }, { 0, (-1) } }
for _, __p in ipairs(dirs) do
local dx, dy = idx(__p, 0), idx(__p, 1)
local cell = idx(match.grid, F.key((relic.x + dx), (relic.y + dy)))
if (truthy(cell)) and (truthy(cell.room.built)) then
local from = idx(match.core.cells, 0)
if truthy(F.path(match, from.x, from.y, cell.x, cell.y)) then
relic.linked = true
table.insert(match.events, { type = "relic" })
local px = (match.layout.ox + ((relic.x + 0.5) * match.layout.cell))
local py = (match.layout.oy + ((relic.y + 0.5) * match.layout.cell))
F.emitFx(match, "kiss", px, py, "#e8d9a0")
F.emitFx(match, "pulse", px, py, "#e8d9a0")
match.pulse = math.max(match.pulse, 0.4)
table.insert(match.floats, { x = px, y = py, text = "★", life = 0.9, t = 0, color = "food" })
break
end
end
::c63::
end
::c62::
end
end

F.beaconActive = function(match)
local b = listFind(match.rooms, function(r)
return (function() local __a = (function() local __a = (r.type == "beacon"); if not truthy(__a) then return __a end; return r.built end)(); if not truthy(__a) then return __a end; return not truthy(r.dead) end)()
end)
do return not truthy(not truthy((function() local __a = b; if not truthy(__a) then return __a end; return ((tonumber(F.staffed(match, b)) or 0) >= (tonumber(1) or 0)) end)())) end
end

F.checkWin = function(match)
local w = match.win
if (not truthy(w)) or ((#(keyList(w)) == 0)) then
do return false end
end
if ((w.corridors ~= nil)) and (((tonumber(#(listFilter(match.rooms, function(r)
return (function() local __a = (function() local __a = (r.type == "corridor"); if not truthy(__a) then return __a end; return r.built end)(); if not truthy(__a) then return __a end; return not truthy(r.dead) end)()
end))) or 0) < (tonumber(w.corridors) or 0))) then
do return false end
end
if ((w.food ~= nil)) and (((tonumber(F.coreStock(match, "food")) or 0) < (tonumber(w.food) or 0))) then
do return false end
end
if ((w.mineral ~= nil)) and (((tonumber(F.coreStock(match, "mineral")) or 0) < (tonumber(w.mineral) or 0))) then
do return false end
end
if ((w.crew ~= nil)) and (((tonumber(#match.kapsels) or 0) < (tonumber(w.crew) or 0))) then
do return false end
end
if ((w.surviveWaves ~= nil)) and (not truthy((function() local __a = ((tonumber(match.wavesCleared) or 0) >= (tonumber(w.surviveWaves) or 0)); if not truthy(__a) then return __a end; return (#match.enemies == 0) end)())) then
do return false end
end
if ((w.kills ~= nil)) and (((tonumber(match.kills) or 0) < (tonumber(w.kills) or 0))) then
do return false end
end
if truthy(w.rooms) then
for type, n in pairs(w.rooms) do
local have = #(listFilter(match.rooms, function(r)
return (function() local __a = (function() local __a = (r.type == type); if not truthy(__a) then return __a end; return r.built end)(); if not truthy(__a) then return __a end; return not truthy(r.dead) end)()
end))
if ((tonumber(have) or 0) < (tonumber(n) or 0)) then
do return false end
end
::c64::
end
end
if ((w.relics ~= nil)) and (((tonumber(#(listFilter(match.relics, function(r)
return r.linked
end))) or 0) < (tonumber(w.relics) or 0))) then
do return false end
end
if (truthy(w.beacon)) and (not truthy(F.beaconActive(match))) then
do return false end
end
if (truthy(w.thaw)) and (((tonumber(countKeys(match.ice)) or 0) > (tonumber(0) or 0))) then
do return false end
end
if ((w.flares ~= nil)) and (((tonumber((function() local __a = match.flaresCleared; if truthy(__a) then return __a end; return 0 end)()) or 0) < (tonumber(w.flares) or 0))) then
do return false end
end
if ((w.folds ~= nil)) and (((tonumber((function() local __a = match.folds; if truthy(__a) then return __a end; return 0 end)()) or 0) < (tonumber(w.folds) or 0))) then
do return false end
end
if ((w.overloads ~= nil)) and (((tonumber((function() local __a = match.overloads; if truthy(__a) then return __a end; return 0 end)()) or 0) < (tonumber(w.overloads) or 0))) then
do return false end
end
if (w.reachY ~= nil) then
local ok = false
for _, room in ipairs(match.rooms) do
if (((room.type == "core")) or (not truthy(room.built))) or (truthy(room.dead)) then
goto c65
end
if truthy(listSome(room.cells, function(c)
return ((tonumber(c.y) or 0) <= (tonumber(w.reachY) or 0))
end)) then
ok = true
break
end
::c65::
end
if not truthy(ok) then
do return false end
end
end
do return true end
end

F.scoreStars = function(match)
local s = 1
if ((tonumber((match.core.hp / match.core.maxhp)) or 0) >= (tonumber(0.55) or 0)) then
s = 2
end
if ((match.deaths == 0)) and (((tonumber((match.core.hp / match.core.maxhp)) or 0) >= (tonumber(0.8) or 0))) then
s = 3
end
if (truthy(match.level.par)) and (((tonumber(match.time) or 0) <= (tonumber(match.level.par) or 0))) then
s = math.max(s, 2)
end
match.stars = s
end

F.cookRations = function(match, dt)
if truthy(F.kitchenCooking(match)) then
do return end
end
if ((tonumber((function() local __a = match.core.stock.biomass; if truthy(__a) then return __a end; return 0 end)()) or 0) < (tonumber(1) or 0)) then
do return end
end
match.rationCook = ((function() local __a = match.rationCook; if truthy(__a) then return __a end; return 0 end)() + dt)
local sec = 1.2
while ((((tonumber(match.rationCook) or 0) >= (tonumber(sec) or 0))) and (((tonumber((function() local __a = match.core.stock.biomass; if truthy(__a) then return __a end; return 0 end)()) or 0) >= (tonumber(1) or 0)))) and (((tonumber(F.need(match, match.core, "food")) or 0) >= (tonumber(1) or 0))) do
match.rationCook = (match.rationCook - sec)
F.change(match.core.stock, "biomass", (-1))
F.addStock(match.core, "food", MEALS_PER_BIO)
table.insert(match.events, { type = "cook" })
F.emitFx(match, "pulse", match.core.cx, match.core.cy, "#f0c24a")
table.insert(match.floats, { x = match.core.cx, y = match.core.cy, text = "+", life = 0.7, t = 0, color = "food" })
::c66::
end
end

F.eat = function(match, dt)
if ((tonumber(match.eatRate) or 0) <= (tonumber(0) or 0)) then
do return end
end
F.cookRations(match, dt)
local n = #match.kapsels
match.core.stock.food = math.max(0, ((function() local __a = match.core.stock.food; if truthy(__a) then return __a end; return 0 end)() - ((match.eatRate * n) * dt)))
if ((tonumber((function() local __a = match.core.stock.food; if truthy(__a) then return __a end; return 0 end)()) or 0) <= (tonumber(0) or 0)) then
F.cookRations(match, 0)
if ((tonumber((function() local __a = match.core.stock.food; if truthy(__a) then return __a end; return 0 end)()) or 0) > (tonumber(0) or 0)) then
match.starve = math.max(0, (match.starve - (dt * 2)))
do return end
end
match.starve = (match.starve + dt)
if (((tonumber(match.starve) or 0) >= (tonumber(9) or 0))) and (truthy(#match.kapsels)) then
match.starve = 0
F.loseKapsel(match, math.floor((match.rng() * #match.kapsels)), "Your crew starved")
end
else
match.starve = math.max(0, (match.starve - (dt * 2)))
end
end

F.decayAssignJuice = function(match, dt)
for _, room in ipairs(match.rooms) do
if ((tonumber(room.ring) or 0) > (tonumber(0) or 0)) then
room.ring = math.max(0, (room.ring - (dt / 0.7)))
end
::c67::
end
for _, k in ipairs(match.kapsels) do
if ((tonumber(k.docked) or 0) > (tonumber(0) or 0)) then
k.docked = math.max(0, (k.docked - (dt / 0.4)))
end
::c68::
end
end

F.step = function(match, dt)
dt = math.min(dt, 0.05)
if (match.status == "paused") then
do return end
end
if ((match.status == "won")) or ((match.status == "lost")) then
match.shake = math.max(0, (match.shake - dt))
do return end
end
if truthy(match.thinkLocked) then
match.shake = math.max(0, (match.shake - dt))
match.pulse = math.max(0, (match.pulse - dt))
F.decayAssignJuice(match, dt)
for i = (#match.fx - 1), 0, -1 do
(idx(match.fx, i)).t = ((idx(match.fx, i)).t + dt)
if ((tonumber((idx(match.fx, i)).t) or 0) >= (tonumber((idx(match.fx, i)).life) or 0)) then
table.remove(match.fx, (i) + 1)
end
::c69::
end
do return end
end
match.time = (match.time + dt)
match.shake = math.max(0, (match.shake - dt))
match.pulse = math.max(0, (match.pulse - dt))
F.decayAssignJuice(match, dt)
F.updateKapsels(match, dt)
F.updateEnemies(match, dt)
F.updateHeaters(match, dt)
F.updateScanners(match)
F.updateFlares(match, dt)
F.updateOverclock(match, dt)
F.updateRelics(match)
F.eat(match, dt)
for i = (#match.floats - 1), 0, -1 do
(idx(match.floats, i)).t = ((idx(match.floats, i)).t + dt)
if ((tonumber((idx(match.floats, i)).t) or 0) >= (tonumber((idx(match.floats, i)).life) or 0)) then
table.remove(match.floats, (i) + 1)
end
::c70::
end
for i = (#((function() local __a = match.trails; if truthy(__a) then return __a end; return {  } end)()) - 1), 0, -1 do
(idx(match.trails, i)).t = ((idx(match.trails, i)).t + dt)
if ((tonumber((idx(match.trails, i)).t) or 0) >= (tonumber((idx(match.trails, i)).life) or 0)) then
table.remove(match.trails, (i) + 1)
end
::c71::
end
for i = (#match.fx - 1), 0, -1 do
(idx(match.fx, i)).t = ((idx(match.fx, i)).t + dt)
if ((tonumber((idx(match.fx, i)).t) or 0) >= (tonumber((idx(match.fx, i)).life) or 0)) then
table.remove(match.fx, (i) + 1)
end
::c72::
end
if (truthy(match.core.dead)) or ((#match.kapsels == 0)) then
match.status = "lost"
match.loseReason = (function() local __a = match.loseReason; if truthy(__a) then return __a end; return (function() if truthy((#match.kapsels == 0)) then return "No kapsels remain" else return "The core came apart" end end)() end)()
do return end
end
if truthy(F.checkWin(match)) then
match.status = "won"
match.winReason = "Station stable"
F.scoreStars(match)
table.insert(match.events, { type = "win" })
end
match.events = sliceList(match.events, (-12))
end

F.pause = function(match)
if (match.status == "playing") then
match.status = "paused"
elseif (match.status == "paused") then
match.status = "playing"
end
end

F.resumeThink = function(match)
if not truthy(match.thinkLocked) then
do return false end
end
match.thinkLocked = false
match.pulse = 0.4
table.insert(match.events, { type = "go" })
do return true end
end

F.unpaidCount = function(match)
do return #(listFilter(match.rooms, function(r)
return (function() local __a = not truthy(r.built); if not truthy(__a) then return __a end; return (r.type ~= "core") end)()
end)) end
end

F.hasJob = function(match, type)
do return listSome(match.rooms, function(r)
return (function() local __a = (r.type == type); if not truthy(__a) then return __a end; return not truthy(r.dead) end)()
end) end
end

F.coachText = function(match)
if not truthy(match) then
do return "" end
end
if not truthy((function() local __a = match.mechanics; if not truthy(__a) then return __a end; return match.mechanics.coach end)()) then
do return (function() local __a = (function() local __a = match.hint; if truthy(__a) then return __a end; return (function() local __a = match.level; if not truthy(__a) then return __a end; return match.level.lesson end)() end)(); if truthy(__a) then return __a end; return "" end)() end
end
local jam = ((tonumber(F.unpaidCount(match)) or 0) >= (tonumber(2) or 0))
local idleN = #(listFilter(match.kapsels, function(k)
return (function() local __a = not truthy(k.assignment); if truthy(__a) then return __a end; return (k.assignment == match.core.id) end)()
end))
if ((truthy(jam)) and (not truthy(match.thinkLocked))) and (((tonumber(idleN) or 0) < (tonumber(1) or 0))) then
do return "Recall a gunner. Dashed rooms need haulers." end
end
if (truthy(jam)) and (not truthy(match.thinkLocked)) then
do return "Two unpaid blueprints jam the hull. Let haulers finish one." end
end
if not truthy(F.hasJob(match, "scanner")) then
do return "Scan first. Cloaked scouts ignore guns they cannot see." end
end
if not truthy(F.hasJob(match, "weapons")) then
do return "Staff a Gun on the hull before the first wave." end
end
if not truthy(F.hasJob(match, "shield")) then
do return "Aegis before the star. Flares cook an empty scanner." end
end
if truthy(jam) then
do return "Two unpaid blueprints jam the hull. Let haulers finish one." end
end
if truthy(match.thinkLocked) then
do return "Hull kit down. TAP GO when the geometry feels right." end
end
local needRelics = (function() local __a = (function() local __a = match.win; if not truthy(__a) then return __a end; return match.win.relics end)(); if truthy(__a) then return __a end; return 0 end)()
local linked = #(listFilter(match.relics, function(r)
return r.linked
end))
if ((truthy(needRelics)) and (((tonumber(linked) or 0) < (tonumber(needRelics) or 0)))) and (truthy(match.mechanics.kitchenChain)) then
local garden = F.hasJob(match, "garden")
local kitchenOk = (function() local __a = not truthy(listContains((function() local __a = match.level.allowed; if truthy(__a) then return __a end; return {  } end)(), "kitchen")); if truthy(__a) then return __a end; return F.hasJob(match, "kitchen") end)()
if (not truthy(garden)) or (not truthy(kitchenOk)) then
do return "Garden and kitchen before monuments. Relics do not feed anyone." end
end
end
if (truthy(needRelics)) and (((tonumber(linked) or 0) < (tonumber(needRelics) or 0))) then
do return "Kiss the four monuments. One I off the plus. Two dashed rooms is a jam." end
end
local needWaves = (function() local __a = (function() local __a = match.win; if not truthy(__a) then return __a end; return match.win.surviveWaves end)(); if truthy(__a) then return __a end; return 0 end)()
if (truthy(needWaves)) and (((tonumber(match.wavesCleared) or 0) < (tonumber(needWaves) or 0))) then
do return "Hold the hull. Scan sees, Gun shoots, Aegis eats the star." end
end
do return "Quiet geometry. Finish the survey." end
end

F.scoreNearCoreCells = function(match, cells)
local plus = match.core.cells
local min = math.huge
local kiss = 0
for _, cell in ipairs(cells) do
for _, p in ipairs(plus) do
local man = (math.abs((cell.x - p.x)) + math.abs((cell.y - p.y)))
min = math.min(min, man)
if ((tonumber(man) or 0) <= (tonumber(1) or 0)) then
kiss = (kiss + 1)
end
::c74::
end
::c73::
end
do return ((kiss * 50) - min) end
end

F.scoreTowardSpots = function(cells, spots)
local min = math.huge
for _, s in ipairs(spots) do
for _, c in ipairs(cells) do
min = math.min(min, (math.abs((c.x - s.x)) + math.abs((c.y - s.y))))
::c76::
end
::c75::
end
do return (-min) end
end

F.cellsFor = function(match, type, x, y, rot)
do return listMap(F.rotateShape(F.playerShape(match, type), rot), function(__p0)
local dx = idx(__p0, 0)
local dy = idx(__p0, 1)
return { x = (x + dx), y = (y + dy) }
end) end
end

F.scoreIceCover = function(cells, ice, radius)
local cover = 0
local min = math.huge
for _, s in ipairs(ice) do
local d = math.huge
for _, c in ipairs(cells) do
d = math.min(d, hypot((s.x - c.x), (s.y - c.y)))
::c78::
end
if ((tonumber(d) or 0) <= (tonumber(radius) or 0)) then
cover = (cover + 1)
end
min = math.min(min, d)
::c77::
end
do return ((cover * 100) - min) end
end

F.bestPlacement = function(match, type, scoreFn)
local best = nil
local saved = match.rot
for rot = 0, (4) - 1, 1 do
match.rot = rot
for y = 0, (match.rows) - 1, 1 do
for x = 0, (match.cols) - 1, 1 do
if not truthy(F.canPlace(match, type, x, y, rot)) then
goto c81
end
local sc = scoreFn(match, F.cellsFor(match, type, x, y, rot))
if (not truthy(best)) or (((tonumber(sc) or 0) > (tonumber(best.sc) or 0))) then
best = { x = x, y = y, rot = rot, sc = sc }
end
::c81::
end
::c80::
end
::c79::
end
match.rot = saved
do return best end
end

F.placeBest = function(match, type, scoreFn)
F.setTool(match, type)
local best = F.bestPlacement(match, type, scoreFn)
if (not truthy(best)) or (((tonumber(best.sc) or 0) <= (tonumber((-9000)) or 0))) then
do return false end
end
match.rot = best.rot
do return F.tapCell(match, best.x, best.y) end
end

F.placeNearCore = function(match, type)
do return F.placeBest(match, type, F.scoreNearCoreCells) end
end

F.idleKapsels = function(match)
do return listFilter(match.kapsels, function(k)
return (function() local __a = not truthy(k.assignment); if truthy(__a) then return __a end; return (k.assignment == match.core.id) end)()
end) end
end

F.assignedCount = function(match, room)
do return #(listFilter(match.kapsels, function(k)
return (k.assignment == room.id)
end)) end
end

F.keepHaulers = function(match)
local haulersWanted = (function() if truthy(((tonumber(F.unpaidCount(match)) or 0) > (tonumber(0) or 0))) then return 2 else return 1 end end)()
local guard = 0
while (((tonumber(#(F.idleKapsels(match))) or 0) < (tonumber(haulersWanted) or 0))) and (((tonumber((function() local __v = guard guard = guard + 1 return __v end)()) or 0) < (tonumber(12) or 0))) do
local over = idx(listSort(listFilter(match.rooms, function(r)
return (function() local __a = (r.type ~= "core"); if not truthy(__a) then return __a end; return ((tonumber(F.assignedCount(match, r)) or 0) > (tonumber(1) or 0)) end)()
end), function(a, b)
return (F.assignedCount(match, b) - F.assignedCount(match, a))
end), 0)
if not truthy(over) then
break
end
match.selected = over.id
if not truthy(F.recall(match)) then
break
end
::c82::
end
end

F.staffCombat = function(match)
local haulersWanted = (function() if truthy(((tonumber(F.unpaidCount(match)) or 0) > (tonumber(0) or 0))) then return 2 else return 1 end end)()
for _, type in ipairs({ "scanner", "weapons", "shield" }) do
local room = listFind(match.rooms, function(r)
return (function() local __a = (r.type == type); if not truthy(__a) then return __a end; return not truthy(r.dead) end)()
end)
if (not truthy(room)) or (((tonumber(F.assignedCount(match, room)) or 0) >= (tonumber(1) or 0))) then
goto c83
end
local idle = #(F.idleKapsels(match))
local must = (function() local __a = not truthy(room.built); if truthy(__a) then return __a end; return (function() local __a = (function() local __a = (type == "scanner"); if not truthy(__a) then return __a end; return match.mechanics.cloak end)(); if not truthy(__a) then return __a end; return ((tonumber(#match.enemies) or 0) > (tonumber(0) or 0)) end)() end)()
if (truthy(room.built)) and ((type == "shield")) then
goto c83
end
if (((tonumber(idle) or 0) <= (tonumber(haulersWanted) or 0))) and (not truthy(must)) then
goto c83
end
if ((tonumber(idle) or 0) < (tonumber(1) or 0)) then
if not truthy(must) then
goto c83
end
local donor = listFind(match.rooms, function(r)
return (function() local __a = (function() local __a = (r.type == "garden"); if truthy(__a) then return __a end; return (r.type == "kitchen") end)(); if not truthy(__a) then return __a end; return ((tonumber(F.assignedCount(match, r)) or 0) >= (tonumber(1) or 0)) end)()
end)
if not truthy(donor) then
goto c83
end
match.selected = donor.id
F.recall(match)
end
F.assignTo(match, room)
::c83::
end
end

F.staffJobs = function(match, order)
F.staffCombat(match)
local combat = setFrom({ "scanner", "weapons", "shield" })
local haulersWanted = (function() if truthy(((tonumber(F.unpaidCount(match)) or 0) > (tonumber(0) or 0))) then return 2 else return 1 end end)()
for _, type in ipairs(order) do
if (idx(combat, type) ~= nil) then
goto c84
end
if ((tonumber(#(F.idleKapsels(match))) or 0) <= (tonumber(haulersWanted) or 0)) then
break
end
local room = listFind(match.rooms, function(r)
return (function() local __a = (r.type == type); if not truthy(__a) then return __a end; return not truthy(r.dead) end)()
end)
if not truthy(room) then
goto c84
end
if ((tonumber(F.assignedCount(match, room)) or 0) < (tonumber(1) or 0)) then
F.assignTo(match, room)
end
::c84::
end
end

F.staffFinale = function(match)
F.setTool(match, "assign")
F.keepHaulers(match)
local order = { "scanner", "weapons", "shield", "heater", "garden", "kitchen", "extractor", "gate", "quarters" }
F.staffJobs(match, order)
end

F.thumbBeat = function(match)
if (not truthy(match)) or ((match.status ~= "playing")) then
do return false end
end
if truthy(match.thinkLocked) then
do return false end
end
F.setTool(match, "assign")
F.keepHaulers(match)
F.staffJobs(match, { "scanner", "weapons", "shield", "heater", "garden", "kitchen" })
if (((tonumber(F.unpaidCount(match)) or 0) >= (tonumber(2) or 0))) or (((tonumber(F.coreStock(match, "mineral")) or 0) < (tonumber(4) or 0))) then
do return false end
end
local allowed = setFrom((function() local __a = (function() local __a = match.level; if not truthy(__a) then return __a end; return match.level.allowed end)(); if truthy(__a) then return __a end; return {  } end)())
local need = (function() local __a = match.win; if truthy(__a) then return __a end; return {  } end)()
if ((idx(allowed, "garden") ~= nil)) and (not truthy(F.hasJob(match, "garden"))) then
do return F.placeBest(match, "garden", F.scoreNearCoreCells) end
end
if ((truthy(match.mechanics.kitchenChain)) and ((idx(allowed, "kitchen") ~= nil))) and (not truthy(F.hasJob(match, "kitchen"))) then
do return F.placeBest(match, "kitchen", F.scoreNearCoreCells) end
end
if (truthy(need.relics)) and (((tonumber(#(listFilter(match.relics, function(r)
return r.linked
end))) or 0) < (tonumber(need.relics) or 0))) then
local spots = listFilter(match.relics, function(r)
return not truthy(r.linked)
end)
if truthy(F.placeBest(match, "corridor", function(_, cells)
return F.scoreTowardSpots(cells, spots)
end)) then
do return true end
end
end
local guns = #(listFilter(match.rooms, function(r)
return (function() local __a = (r.type == "weapons"); if not truthy(__a) then return __a end; return not truthy(r.dead) end)()
end))
if (((idx(allowed, "weapons") ~= nil)) and (((tonumber(#match.enemies) or 0) >= (tonumber(3) or 0)))) and (((tonumber(guns) or 0) < (tonumber(2) or 0))) then
do return F.placeBest(match, "weapons", F.scoreNearCoreCells) end
end
do return false end
end

F.hullDist = function(match, spot)
local live = F.reachableBuilt(match)
local min = math.huge
for _, cell in pairs(match.grid) do
if not truthy((idx(live, F.key(cell.x, cell.y)) ~= nil)) then
goto c85
end
local d = (math.abs((cell.x - spot.x)) + math.abs((cell.y - spot.y)))
if ((tonumber(d) or 0) < (tonumber(min) or 0)) then
min = d
end
::c85::
end
if (min == math.huge) then
local home = idx(match.core.cells, 0)
do return (math.abs((spot.x - home.x)) + math.abs((spot.y - home.y))) end
end
do return min end
end

F.nearestUnlinkedRelics = function(match)
do return listSort(copyList(listFilter(match.relics, function(r)
return not truthy(r.linked)
end)), function(a, b)
return (F.hullDist(match, a) - F.hullDist(match, b))
end) end
end

F.kissNearestRelic = function(match)
local spots = F.nearestUnlinkedRelics(match)
if not truthy(#spots) then
do return false end
end
do return F.roadTowardSpots(match, { idx(spots, 0) }) end
end

F.depositSpots = function(match)
do return listMap(setKeys(match.deposits), function(k)
local x, y = splitKey(k)
do return { x = x, y = y } end
end) end
end

F.roadTowardSpots = function(match, spots)
if not truthy(#spots) then
do return false end
end
local live = F.reachableBuilt(match)
do return F.placeBest(match, "corridor", function(_, cells)
local touchLive = false
for _, c in ipairs(cells) do
for _, __p in ipairs({ { 1, 0 }, { (-1), 0 }, { 0, 1 }, { 0, (-1) } }) do
local dx, dy = idx(__p, 0), idx(__p, 1)
if (idx(live, F.key((c.x + dx), (c.y + dy))) ~= nil) then
touchLive = true
end
::c87::
end
::c86::
end
if not truthy(touchLive) then
do return (-9999) end
end
do return F.scoreTowardSpots(cells, spots) end
end) end
end

F.placeExtractorOrRoad = function(match, allowRoad)
local deposits = F.depositSpots(match)
if truthy(F.placeBest(match, "extractor", function(_, cells)
return (function() if truthy(#deposits) then return F.scoreTowardSpots(cells, deposits) else return F.scoreNearCoreCells(match, cells) end end)()
end)) then
do return true end
end
if ((truthy(allowRoad)) and (truthy(#deposits))) and (truthy(F.roadTowardSpots(match, deposits))) then
do return true end
end
do return false end
end

F.bagHold = function(match)
if (truthy(match.mechanics)) and (truthy(match.mechanics.pieceQueue)) then
do return F.holdPiece(match) end
end
do return false end
end

F.captainBeat = function(match)
if (not truthy(match)) or ((match.status ~= "playing")) then
do return false end
end
local allowed = setFrom((function() local __a = (function() local __a = match.level; if not truthy(__a) then return __a end; return match.level.allowed end)(); if truthy(__a) then return __a end; return {  } end)())
local need = (function() local __a = match.win; if truthy(__a) then return __a end; return {  } end)()
if ((truthy(match.tutorial)) and (truthy(match.tutorial.needAssign))) and ((match.tutorial.roomId ~= nil)) then
local room = listFind(match.rooms, function(r)
return (r.id == match.tutorial.roomId)
end)
if truthy(room) then
do return F.assignTo(match, room) end
end
end
if truthy(match.thinkLocked) then
if ((idx(allowed, "scanner") ~= nil)) and (not truthy(F.hasJob(match, "scanner"))) then
do return F.placeBest(match, "scanner", F.scoreNearCoreCells) end
end
if ((idx(allowed, "weapons") ~= nil)) and (not truthy(F.hasJob(match, "weapons"))) then
do return F.placeBest(match, "weapons", F.scoreNearCoreCells) end
end
if (((idx(allowed, "shield") ~= nil)) and (not truthy(F.hasJob(match, "shield")))) and ((truthy(optget(need.rooms, "shield"))) or (truthy(match.mechanics.flares))) then
do return F.placeBest(match, "shield", F.scoreNearCoreCells) end
end
do return F.resumeThink(match) end
end
F.staffFinale(match)
local unpaid = F.unpaidCount(match)
local mineral = F.coreStock(match, "mineral")
local waveSoon = (function() local __a = ((tonumber(#match.enemies) or 0) > (tonumber(0) or 0)); if truthy(__a) then return __a end; return (function() local __a = match.waves; if not truthy(__a) then return __a end; return ((tonumber(match.waves.timer) or 0) < (tonumber(18) or 0)) end)() end)()
local linked = #(listFilter(match.relics, function(r)
return r.linked
end))
local needRelics = (function() local __a = need.relics; if not truthy(__a) then return __a end; return ((tonumber(linked) or 0) < (tonumber(need.relics) or 0)) end)()
local wantGuns = not truthy(not truthy((function() local __a = (function() local __a = need.surviveWaves; if truthy(__a) then return __a end; return need.kills end)(); if truthy(__a) then return __a end; return optget(need.rooms, "weapons") end)()))
local wantGarden = (function() local __a = (function() local __a = (function() local __a = need.food; if truthy(__a) then return __a end; return need.crew end)(); if truthy(__a) then return __a end; return match.mechanics.kitchenChain end)(); if truthy(__a) then return __a end; return (function() local __a = need.rooms; if not truthy(__a) then return __a end; return need.rooms.garden end)() end)()
local guns = #(listFilter(match.rooms, function(r)
return (function() local __a = (r.type == "weapons"); if not truthy(__a) then return __a end; return not truthy(r.dead) end)()
end))
local needGunNow = (function() local __a = (function() local __a = (idx(allowed, "weapons") ~= nil); if not truthy(__a) then return __a end; return ((tonumber(guns) or 0) < (tonumber(1) or 0)) end)(); if not truthy(__a) then return __a end; return ((tonumber(#match.enemies) or 0) > (tonumber(0) or 0)) end)()
local mealsReady = (function() local __a = not truthy((function() local __a = (function() local __a = wantGarden; if not truthy(__a) then return __a end; return (idx(allowed, "garden") ~= nil) end)(); if not truthy(__a) then return __a end; return not truthy(F.hasJob(match, "garden")) end)()); if not truthy(__a) then return __a end; return not truthy((function() local __a = (function() local __a = match.mechanics.kitchenChain; if not truthy(__a) then return __a end; return (idx(allowed, "kitchen") ~= nil) end)(); if not truthy(__a) then return __a end; return not truthy(F.hasJob(match, "kitchen")) end)()) end)()
local wantExtract = (function() local __a = (function() local __a = (function() local __a = (idx(allowed, "extractor") ~= nil); if not truthy(__a) then return __a end; return not truthy(F.hasJob(match, "extractor")) end)(); if not truthy(__a) then return __a end; return mealsReady end)(); if not truthy(__a) then return __a end; return (function() local __a = (function() local __a = (function() local __a = ((tonumber((function() local __a = need.overloads; if truthy(__a) then return __a end; return 0 end)()) or 0) > (tonumber((function() local __a = match.overloads; if truthy(__a) then return __a end; return 0 end)()) or 0)); if truthy(__a) then return __a end; return (function() local __a = needRelics; if not truthy(__a) then return __a end; return ((tonumber(countKeys(match.deposits)) or 0) > (tonumber(0) or 0)) end)() end)(); if truthy(__a) then return __a end; return (function() local __a = not truthy(needRelics); if not truthy(__a) then return __a end; return ((tonumber(mineral) or 0) < (tonumber(14) or 0)) end)() end)(); if truthy(__a) then return __a end; return (function() local __a = needRelics; if not truthy(__a) then return __a end; return ((tonumber(mineral) or 0) < (tonumber(16) or 0)) end)() end)() end)()
if ((tonumber(unpaid) or 0) >= (tonumber(2) or 0)) then
do return false end
end
if (truthy(wantExtract)) and (((tonumber(unpaid) or 0) >= (tonumber(1) or 0))) then
do return false end
end
if truthy(listSome(match.rooms, function(r)
return (function() local __a = (function() local __a = (r.type == "extractor"); if not truthy(__a) then return __a end; return not truthy(r.built) end)(); if not truthy(__a) then return __a end; return not truthy(r.dead) end)()
end)) then
do return false end
end
if (((tonumber(mineral) or 0) < (tonumber(4) or 0))) and (((tonumber(unpaid) or 0) > (tonumber(0) or 0))) then
do return false end
end
if (truthy(needGunNow)) and (truthy(F.placeBest(match, "weapons", F.scoreNearCoreCells))) then
do return true end
end
if (truthy(wantExtract)) and (truthy(F.placeExtractorOrRoad(match, (need.mineral ~= nil)))) then
do return true end
end
if (((truthy(needRelics)) and (not truthy((function() local __a = match.mechanics.kitchenChain; if not truthy(__a) then return __a end; return (function() local __a = need.food; if truthy(__a) then return __a end; return need.crew end)() end)()))) and (not truthy((function() local __a = wantGuns; if not truthy(__a) then return __a end; return waveSoon end)()))) and (truthy(F.kissNearestRelic(match))) then
do return true end
end
if ((idx(allowed, "scanner") ~= nil)) and (not truthy(F.hasJob(match, "scanner"))) then
do return F.placeBest(match, "scanner", F.scoreNearCoreCells) end
end
if (((idx(allowed, "shield") ~= nil)) and (not truthy(F.hasJob(match, "shield")))) and ((truthy(optget(need.rooms, "shield"))) or (truthy(match.mechanics.flares))) then
do return F.placeBest(match, "shield", F.scoreNearCoreCells) end
end
local gunsWanted = (function() local __a = optget(need.rooms, "weapons"); if truthy(__a) then return __a end; return 0 end)()
if (truthy(wantGuns)) and ((truthy(waveSoon)) or (((tonumber(#match.enemies) or 0) > (tonumber(0) or 0)))) then
gunsWanted = math.max(gunsWanted, 1)
end
if (((tonumber(#match.enemies) or 0) >= (tonumber(3) or 0))) and ((not truthy(needRelics)) or (((tonumber(mineral) or 0) >= (tonumber(18) or 0)))) then
gunsWanted = math.max(gunsWanted, 2)
end
if (not truthy(wantGuns)) and (((tonumber(#match.enemies) or 0) > (tonumber(0) or 0))) then
gunsWanted = math.max(gunsWanted, 1)
end
if ((idx(allowed, "weapons") ~= nil)) and (((tonumber(guns) or 0) < (tonumber(gunsWanted) or 0))) then
if truthy(F.placeBest(match, "weapons", F.scoreNearCoreCells)) then
do return true end
end
do return F.bagHold(match) end
end
if (((idx(allowed, "garden") ~= nil)) and (not truthy(F.hasJob(match, "garden")))) and (truthy(wantGarden)) then
do return F.placeBest(match, "garden", F.scoreNearCoreCells) end
end
if ((truthy(match.mechanics.kitchenChain)) and ((idx(allowed, "kitchen") ~= nil))) and (not truthy(F.hasJob(match, "kitchen"))) then
do return F.placeBest(match, "kitchen", F.scoreNearCoreCells) end
end
if (((truthy(need.crew)) and (((tonumber(#match.kapsels) or 0) < (tonumber(need.crew) or 0)))) and ((idx(allowed, "quarters") ~= nil))) and (not truthy(F.hasJob(match, "quarters"))) then
do return F.placeBest(match, "quarters", F.scoreNearCoreCells) end
end
if (truthy(needRelics)) and (truthy(F.kissNearestRelic(match))) then
do return true end
end
if (truthy(need.thaw)) and (((tonumber(countKeys(match.ice)) or 0) > (tonumber(0) or 0))) then
local ice = listMap(setKeys(match.ice), function(k)
local x, y = splitKey(k)
do return { x = x, y = y } end
end)
if (idx(allowed, "heater") ~= nil) then
local cover = F.bestPlacement(match, "heater", function(_, cells)
return F.scoreIceCover(cells, ice, HEATER_R)
end)
if (truthy(cover)) and (((tonumber(cover.sc) or 0) >= (tonumber(100) or 0))) then
F.setTool(match, "heater")
match.rot = cover.rot
do return F.tapCell(match, cover.x, cover.y) end
end
end
if (idx(allowed, "corridor") ~= nil) then
local road = F.bestPlacement(match, "corridor", function(_, cells)
if truthy(listSome(cells, function(c)
return (idx(match.ice, F.key(c.x, c.y)) ~= nil)
end)) then
do return (-999) end
end
do return F.scoreTowardSpots(cells, ice) end
end)
if (truthy(road)) and (((tonumber(road.sc) or 0) > (tonumber((-900)) or 0))) then
F.setTool(match, "corridor")
match.rot = road.rot
do return F.tapCell(match, road.x, road.y) end
end
end
if ((idx(allowed, "heater") ~= nil)) and (truthy(F.placeBest(match, "heater", function(_, cells)
return F.scoreTowardSpots(cells, ice)
end))) then
do return true end
end
do return F.bagHold(match) end
end
local gateNeed = math.max((function() local __a = optget(need.rooms, "gate"); if truthy(__a) then return __a end; return 0 end)(), (function() if truthy(((tonumber((function() local __a = need.folds; if truthy(__a) then return __a end; return 0 end)()) or 0) > (tonumber(0) or 0))) then return 2 else return 0 end end)())
local gatesHave = #(listFilter(match.rooms, function(r)
return (function() local __a = (r.type == "gate"); if not truthy(__a) then return __a end; return not truthy(r.dead) end)()
end))
if ((idx(allowed, "gate") ~= nil)) and (((tonumber(gatesHave) or 0) < (tonumber(gateNeed) or 0))) then
local builtGate = listFind(match.rooms, function(r)
return (function() local __a = (function() local __a = (r.type == "gate"); if not truthy(__a) then return __a end; return r.built end)(); if not truthy(__a) then return __a end; return not truthy(r.dead) end)()
end)
local spots = listMap((function() local __a = match.level.prebuilt; if truthy(__a) then return __a end; return {  } end)(), function(p)
return { x = p.x, y = p.y }
end)
if (gatesHave == 0) then
do return F.placeBest(match, "gate", F.scoreNearCoreCells) end
end
if (truthy(builtGate)) and (truthy(#spots)) then
do return F.placeBest(match, "gate", F.scoreNearCoreCells) end
end
if truthy(#spots) then
do return F.placeBest(match, "gate", function(_, cells)
return F.scoreTowardSpots(cells, spots)
end) end
end
do return F.placeBest(match, "gate", F.scoreNearCoreCells) end
end
if ((((idx(allowed, "extractor") ~= nil)) and (not truthy(F.hasJob(match, "extractor")))) and (truthy(mealsReady))) and (((((tonumber(F.coreStock(match, "mineral")) or 0) < (tonumber(10) or 0))) or (((tonumber((function() local __a = need.overloads; if truthy(__a) then return __a end; return 0 end)()) or 0) > (tonumber((function() local __a = match.overloads; if truthy(__a) then return __a end; return 0 end)()) or 0)))) or ((need.mineral ~= nil))) then
if truthy(F.placeExtractorOrRoad(match, (function() local __a = (need.mineral ~= nil); if truthy(__a) then return __a end; return ((tonumber((function() local __a = need.overloads; if truthy(__a) then return __a end; return 0 end)()) or 0) > (tonumber((function() local __a = match.overloads; if truthy(__a) then return __a end; return 0 end)()) or 0)) end)())) then
do return true end
end
do return F.bagHold(match) end
end
if ((tonumber((function() local __a = need.overloads; if truthy(__a) then return __a end; return 0 end)()) or 0) > (tonumber((function() local __a = match.overloads; if truthy(__a) then return __a end; return 0 end)()) or 0)) then
local ex = listFind(match.rooms, function(r)
return (function() local __a = (function() local __a = (function() local __a = (r.type == "extractor"); if truthy(__a) then return __a end; return (r.type == "garden") end)(); if not truthy(__a) then return __a end; return r.built end)(); if not truthy(__a) then return __a end; return not truthy(r.dead) end)()
end)
if (truthy(ex)) and (((tonumber(F.staffed(match, ex)) or 0) >= (tonumber(1) or 0))) then
do return F.overloadRoom(match, ex) end
end
end
if ((need.reachY ~= nil)) or ((need.corridors ~= nil)) then
local north = (function() if truthy((need.reachY ~= nil)) then return listSome(match.rooms, function(r)
return (function() local __a = (function() local __a = (function() local __a = (r.type ~= "core"); if not truthy(__a) then return __a end; return r.built end)(); if not truthy(__a) then return __a end; return not truthy(r.dead) end)(); if not truthy(__a) then return __a end; return listSome(r.cells, function(c)
return ((tonumber(c.y) or 0) <= (tonumber(need.reachY) or 0))
end) end)()
end) else return true end end)()
local roads = #(listFilter(match.rooms, function(r)
return (function() local __a = (function() local __a = (r.type == "corridor"); if not truthy(__a) then return __a end; return r.built end)(); if not truthy(__a) then return __a end; return not truthy(r.dead) end)()
end))
local wantRoad = (function() local __a = (idx(allowed, "corridor") ~= nil); if not truthy(__a) then return __a end; return (function() local __a = not truthy(north); if truthy(__a) then return __a end; return (function() local __a = (need.corridors ~= nil); if not truthy(__a) then return __a end; return ((tonumber(roads) or 0) < (tonumber(need.corridors) or 0)) end)() end)() end)()
if truthy(wantRoad) then
local spots = (function() if truthy((need.reachY ~= nil)) then return { { x = (function() local __a = (function() local __a = match.level.core; if not truthy(__a) then return __a end; return match.level.core.x end)(); if truthy(__a) then return __a end; return 4 end)(), y = need.reachY } } else return nil end end)()
if truthy(F.placeBest(match, "corridor", (function() if truthy(spots) then return function(_, cells)
return F.scoreTowardSpots(cells, spots)
end else return F.scoreNearCoreCells end end)())) then
do return true end
end
end
end
if truthy(needRelics) then
do return F.bagHold(match) end
end
do return F.bagHold(match) end
end

F.gridAt = function(match, px, py)
do return F.atPixel(match, px, py) end
end

F.objectiveText = function(match)
local w = (function() local __a = match.win; if truthy(__a) then return __a end; return {  } end)()
local parts = {  }
if (w.corridors ~= nil) then
local n = #(listFilter(match.rooms, function(r)
return (function() local __a = (r.type == "corridor"); if not truthy(__a) then return __a end; return r.built end)()
end))
table.insert(parts, "Corridors " .. tostring(n) .. "/" .. tostring(w.corridors))
end
if (w.food ~= nil) then
table.insert(parts, "Pantry " .. tostring(math.floor(F.coreStock(match, "food"))) .. "/" .. tostring(w.food))
end
if (w.mineral ~= nil) then
table.insert(parts, "Minerals " .. tostring(math.floor(F.coreStock(match, "mineral"))) .. "/" .. tostring(w.mineral))
end
if (w.crew ~= nil) then
table.insert(parts, "Crew " .. tostring(#match.kapsels) .. "/" .. tostring(w.crew))
end
if (w.surviveWaves ~= nil) then
table.insert(parts, "Waves " .. tostring(match.wavesCleared) .. "/" .. tostring(w.surviveWaves))
end
if truthy(w.rooms) then
for type, n in pairs(w.rooms) do
local have = #(listFilter(match.rooms, function(r)
return (function() local __a = (r.type == type); if not truthy(__a) then return __a end; return r.built end)()
end))
table.insert(parts, tostring(roomLabel(type, match.level.world)) .. " " .. tostring(have) .. "/" .. tostring(n))
::c88::
end
end
if (w.relics ~= nil) then
table.insert(parts, "Relics " .. tostring(#(listFilter(match.relics, function(r)
return r.linked
end))) .. "/" .. tostring(w.relics))
end
if truthy(w.beacon) then
table.insert(parts, (function() if truthy(F.beaconActive(match)) then return "Beacon live" else return "Staff the beacon" end end)())
end
if truthy(w.thaw) then
table.insert(parts, (function() if truthy(countKeys(match.ice)) then return "Thaw " .. tostring(countKeys(match.ice)) else return "Ice clear" end end)())
end
if (w.kills ~= nil) then
table.insert(parts, "Kills " .. tostring(match.kills) .. "/" .. tostring(w.kills))
end
if (w.flares ~= nil) then
table.insert(parts, "Flares " .. tostring((function() local __a = match.flaresCleared; if truthy(__a) then return __a end; return 0 end)()) .. "/" .. tostring(w.flares))
end
if (w.folds ~= nil) then
table.insert(parts, "Folds " .. tostring((function() local __a = match.folds; if truthy(__a) then return __a end; return 0 end)()) .. "/" .. tostring(w.folds))
end
if (w.overloads ~= nil) then
table.insert(parts, "Over " .. tostring((function() local __a = match.overloads; if truthy(__a) then return __a end; return 0 end)()) .. "/" .. tostring(w.overloads))
end
if (w.reachY ~= nil) then
local best = 99
for _, room in ipairs(match.rooms) do
if (((room.type == "core")) or (not truthy(room.built))) or (truthy(room.dead)) then
goto c89
end
for _, c in ipairs(room.cells) do
best = math.min(best, c.y)
::c90::
end
::c89::
end
table.insert(parts, (function() if truthy(((tonumber(best) or 0) <= (tonumber(w.reachY) or 0))) then return "North shore" else return "North y " .. tostring((function() if truthy((best == 99)) then return "—" else return best end end)()) .. "→" .. tostring(w.reachY) end end)())
end
do return (function() local __a = table.concat(parts, "  ·  "); if truthy(__a) then return __a end; return "Hold the station" end)() end
end

F.paletteFor = function(level)
local allowed = (function() local __a = level.allowed; if truthy(__a) then return __a end; return { "corridor", "garden", "extractor", "weapons", "quarters" } end)()
local tools = concatLists({"assign"}, allowed)
local win = (function() local __a = level.win; if truthy(__a) then return __a end; return {  } end)()
local mech = (function() local __a = level.mechanics; if truthy(__a) then return __a end; return {  } end)()
if (truthy(mech.overload)) and ((((tonumber((function() local __a = win.overloads; if truthy(__a) then return __a end; return 0 end)()) or 0) > (tonumber(0) or 0))) or (truthy(listContains(allowed, "heater")))) then
table.insert(tools, "overload")
end
table.insert(tools, "salvage")
do return tools end
end

M.chipId = F.chipId
M.jobChips = F.jobChips
M.playerShape = F.playerShape
M.fitPiece = F.fitPiece
M.gunRange = F.gunRange
M.scanRange = F.scanRange
M.rotateShape = F.rotateShape
M.remapLayout = F.remapLayout
M.computeLayout = F.computeLayout
M.roomAt = F.roomAt
M.coreStock = F.coreStock
M.staffed = F.staffed
M.pathLength = F.pathLength
M.pieceHasLanding = F.pieceHasLanding
M.holdPiece = F.holdPiece
M.createMatch = F.createMatch
M.setTool = F.setTool
M.rotate = F.rotate
M.canPlace = F.canPlace
M.assignTo = F.assignTo
M.recall = F.recall
M.overloadRoom = F.overloadRoom
M.tapCell = F.tapCell
M.step = F.step
M.pause = F.pause
M.resumeThink = F.resumeThink
M.coachText = F.coachText
M.placeNearCore = F.placeNearCore
M.thumbBeat = F.thumbBeat
M.captainBeat = F.captainBeat
M.gridAt = F.gridAt
M.objectiveText = F.objectiveText
M.paletteFor = F.paletteFor

return M

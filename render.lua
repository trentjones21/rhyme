-- Station world: Grapefrukt-ish hulls, facing dashes, quiet void.
local sim = require("sim")
local levels = require("levels")

local M = {}
local stars, motes
local PI2 = math.pi * 2

local function hex(c)
  if type(c) == "table" then
    return c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1
  end
  if type(c) ~= "string" then return 1, 1, 1, 1 end
  local rs, gs, bs, as = c:match("rgba%(%s*([%d.]+)%s*,%s*([%d.]+)%s*,%s*([%d.]+)%s*,%s*([%d.]+)%s*%)")
  if rs then
    return (tonumber(rs) or 0) / 255, (tonumber(gs) or 0) / 255, (tonumber(bs) or 0) / 255, tonumber(as) or 1
  end
  local h = c:gsub("#", "")
  if #h == 3 then
    h = h:sub(1, 1) .. h:sub(1, 1) .. h:sub(2, 2) .. h:sub(2, 2) .. h:sub(3, 3) .. h:sub(3, 3)
  end
  if #h < 6 then return 1, 1, 1, 1 end
  return tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255, 1
end

local function col(c, a)
  local r, g, b, al = hex(c)
  love.graphics.setColor(r, g, b, a or al or 1)
end

local function rr(mode, x, y, w, h, r)
  r = math.max(0, math.min(r or 0, w / 2, h / 2))
  love.graphics.rectangle(mode, x, y, w, h, r, r)
end

local function seedStars(n)
  stars, motes = {}, {}
  local s = 1337
  local function rnd()
    s = (s * 1664525 + 1013904223) % 4294967296
    return s / 4294967296
  end
  for _ = 1, n do
    stars[#stars + 1] = { x = rnd(), y = rnd(), r = rnd() * 1.05 + 0.2, a = rnd() * 0.42 + 0.1, p = rnd() * PI2 }
  end
  for _ = 1, 8 do
    motes[#motes + 1] = {
      x = rnd(), y = rnd(), r = rnd() * 1.1 + 0.5, a = rnd() * 0.08 + 0.03,
      p = rnd() * PI2, s = 0.008 + rnd() * 0.012,
    }
  end
end

local function cellRect(match, x, y, inset)
  local L = match.layout
  local pad = inset or 0
  return L.ox + x * L.cell + pad, L.oy + y * L.cell + pad, L.cell - pad * 2, L.cell - pad * 2
end

local function liveSet(room)
  local live = {}
  for _, c in ipairs(room.cells) do
    live[c.x .. "," .. c.y] = true
  end
  return live
end

local function hullR(live, x, y)
  local n = live[x .. "," .. (y - 1)]
  local e = live[(x + 1) .. "," .. y]
  local s = live[x .. "," .. (y + 1)]
  local w = live[(x - 1) .. "," .. y]
  local isolated = not (n or e or s or w)
  local edge = (not n) or (not e) or (not s) or (not w)
  if isolated then return 6.5 end
  if edge then return 4 end
  return 1.5
end

local function drawTerrain(match, now)
  for _, d in ipairs(match.level.deposits or {}) do
    local x, y, w, h = cellRect(match, d.x, d.y, 6)
    local pulse = 0.55 + math.sin(now * 0.005) * 0.2
    col("#e07898", pulse)
    local cx, cy = x + w / 2, y + h / 2
    love.graphics.rectangle("fill", cx - 2, y + 2, 4, h - 4)
    love.graphics.rectangle("fill", x + 2, cy - 2, w - 4, 4)
  end
  for _, b in ipairs(match.level.blocked or {}) do
    local x, y, w, h = cellRect(match, b.x, b.y, 3)
    col("#0b0c10")
    rr("fill", x, y, w, h, 4)
    col({ 1, 1, 1, 0.08 })
    rr("line", x, y, w, h, 4)
  end
  for key in pairs(match.ice or {}) do
    local gx, gy = key:match("^([^,]+),([^,]+)$")
    gx, gy = tonumber(gx), tonumber(gy)
    if gx then
      local x, y, w, h = cellRect(match, gx, gy, 4)
      col({ 186 / 255, 220 / 255, 1, 0.28 })
      rr("fill", x, y, w, h, 5)
      col({ 220 / 255, 236 / 255, 1, 0.45 })
      rr("line", x, y, w, h, 5)
      col({ 1, 1, 1, 0.18 + math.sin(now * 0.004 + gx + gy) * 0.12 })
      love.graphics.rectangle("fill", x + w * 0.2, y + 3, 3, 3)
    end
  end
  for _, well in ipairs(match.wells or {}) do
    local L = match.layout
    local x = L.ox + (well.x + 0.5) * L.cell
    local y = L.oy + (well.y + 0.5) * L.cell
    for i = 3, 1, -1 do
      col({ 160 / 255, 150 / 255, 1, 0.08 * i })
      love.graphics.setLineWidth(1.5)
      love.graphics.circle("line", x, y, 8 + i * 10 + (now * 0.02) % 10)
    end
  end
  for _, relic in ipairs(match.relics or {}) do
    local x, y, w, h = cellRect(match, relic.x, relic.y, 7)
    local cx, cy = x + w / 2, y + h / 2
    local hum = 0.1 + math.sin(now * 0.004 + relic.x) * 0.05
    if relic.linked then
      col({ 232 / 255, 217 / 255, 160 / 255, 0.35 + hum })
    else
      col({ 180 / 255, 190 / 255, 210 / 255, 0.16 + hum })
    end
    love.graphics.setLineWidth(relic.linked and 2 or 1.2)
    love.graphics.circle("line", cx, cy + 2, 16 + math.sin(now * 0.003 + relic.y) * 2)
    if relic.linked then
      col({ 232 / 255, 217 / 255, 160 / 255, 0.12 + math.sin(now * 0.005) * 0.06 })
      love.graphics.circle("fill", cx, cy + 4, 14)
    end
    col(relic.linked and "#e8d9a0" or "#9aa0ae")
    love.graphics.polygon("fill", x + w / 2, y - 6, x + w, y + h, x, y + h)
  end
end

local function drawFoldRibbon(match, now)
  local gates = {}
  for _, r in ipairs(match.rooms) do
    if r.type == "gate" and r.built and not r.dead then gates[#gates + 1] = r end
  end
  if #gates < 2 then return end
  love.graphics.setLineWidth(2.2)
  for i = 1, #gates do
    for j = i + 1, #gates do
      local a, b = gates[i], gates[j]
      col({ 196 / 255, 170 / 255, 240 / 255, 0.22 + math.sin(now * 0.005) * 0.1 })
      love.graphics.line(a.cx, a.cy, (a.cx + b.cx) / 2, (a.cy + b.cy) / 2 - 28, b.cx, b.cy)
      local t = (now * 0.0018 + a.id + b.id) % 1
      local mx = (a.cx + b.cx) / 2
      local my = (a.cy + b.cy) / 2 - 28
      local px = (1 - t) * (1 - t) * a.cx + 2 * (1 - t) * t * mx + t * t * b.cx
      local py = (1 - t) * (1 - t) * a.cy + 2 * (1 - t) * t * my + t * t * b.cy
      col({ 232 / 255, 217 / 255, 1, 0.45 + math.sin(now * 0.01) * 0.2 })
      love.graphics.circle("fill", px, py, 3.2)
    end
  end
end

local function drawRoomGlow(match, now)
  for _, room in ipairs(match.rooms) do
    if not room.built or room.dead then goto cont end
    local staff = false
    for _, k in ipairs(match.kapsels) do
      if k.assignment == room.id then staff = true break end
    end
    if room.type == "garden" then
      col({ 94 / 255, 168 / 255, 106 / 255, 0.1 + math.sin(now * 0.004) * 0.04 })
    elseif room.type == "kitchen" then
      col({ 240 / 255, 194 / 255, 74 / 255, 0.1 + math.sin(now * 0.005) * 0.04 })
    elseif room.type == "gate" then
      col({ 155 / 255, 122 / 255, 212 / 255, 0.12 + math.sin(now * 0.006 + room.id) * 0.05 })
    elseif room.type == "core" then
      col({ 243 / 255, 240 / 255, 232 / 255, 0.1 + math.sin(now * 0.003) * 0.04 })
    else
      col({ 243 / 255, 240 / 255, 232 / 255, staff and 0.11 or 0.05 })
    end
    love.graphics.circle("fill", room.cx, room.cy, match.layout.cell * (room.type == "core" and 2.1 or 1.15))
    ::cont::
  end
end

local function drawValid(match)
  if not match.tool or match.tool == "assign" or match.tool == "salvage" or match.tool == "overload" then return end
  col({ 94 / 255, 168 / 255, 106 / 255, 0.12 })
  for y = 0, match.rows - 1 do
    for x = 0, match.cols - 1 do
      if sim.canPlace(match, match.tool, x, y, match.rot) then
        local rx, ry, rw, rh = cellRect(match, x, y, 4)
        rr("fill", rx, ry, rw, rh, 4)
      end
    end
  end
end

local function drawHull(match, room, now)
  local live = liveSet(room)
  local color = room.def and room.def.hue or "#888888"
  local teach = match.tutorial and match.tutorial.needAssign and match.tutorial.roomId == room.id
  for _, c in ipairs(room.cells) do
    local x, y, w, h = cellRect(match, c.x, c.y, 1.5)
    local rad = hullR(live, c.x, c.y)
    local r, g, b = hex(color)
    love.graphics.setColor(r, g, b, room.built and 1 or 0.3)
    rr("fill", x, y, w, h, rad)
    love.graphics.setColor(1, 1, 1, 0.14)
    love.graphics.rectangle("fill", x + 2, y + 1.4, math.max(2, w - 4), 1.3)
    if not room.built then
      local a = 0.28 + math.sin(now * 0.008 + room.id) * 0.2
      if teach then a = 0.55 + math.sin(now * 0.01) * 0.35 end
      col({ 255 / 255, 220 / 255, 170 / 255, a })
      love.graphics.setLineWidth(teach and 2 or 1.4)
      love.graphics.setLineStyle("rough")
      rr("line", x, y, w, h, rad)
      love.graphics.setLineStyle("smooth")
    end
  end
end

local function glyph(room, now)
  love.graphics.push()
  love.graphics.translate(room.cx, room.cy)
  col({ 243 / 255, 240 / 255, 232 / 255, 0.72 })
  love.graphics.setLineWidth(1.6)
  if room.type == "garden" then
    local sway = math.sin(now * 0.004 + room.id) * 1.2
    for i = -1, 1 do
      love.graphics.line(i * 7, 4, i * 7 + sway, -6)
      love.graphics.ellipse("fill", i * 7 + sway - 3, -5, 3.2, 1.6)
    end
  elseif room.type == "extractor" then
    love.graphics.polygon("fill", 0, -8, 6, -1, 0, 6, -6, -1)
  elseif room.type == "kitchen" then
    love.graphics.rectangle("line", -10, -7, 20, 12)
    love.graphics.circle("line", -4, -1, 3)
    love.graphics.circle("line", 4, -1, 3)
  elseif room.type == "weapons" then
    love.graphics.circle("fill", 0, 0, (room.cooldown or 0) > 0.7 and 4.4 or 3.2)
  elseif room.type == "shield" then
    love.graphics.circle("line", 0, 0, 7)
    love.graphics.circle("line", 0, 0, 3)
  elseif room.type == "quarters" then
    love.graphics.rectangle("line", -7, -5, 14, 10, 3, 3)
  elseif room.type == "heater" then
    love.graphics.arc("line", "open", 0, 2, 7, math.pi, 0)
  elseif room.type == "scanner" then
    love.graphics.circle("line", 0, 0, 7)
    love.graphics.circle("fill", 0, 0, 1.6)
    local sweep = (now * 0.003) % PI2
    col({ 112 / 255, 180 / 255, 224 / 255, 0.55 })
    love.graphics.line(0, 0, math.cos(sweep) * 10, math.sin(sweep) * 10)
  elseif room.type == "beacon" then
    for i = 0, 3 do
      love.graphics.line(0, 0, math.cos(i * math.pi / 2) * 8, math.sin(i * math.pi / 2) * 8)
    end
    love.graphics.circle("fill", 0, 0, 2.2)
  elseif room.type == "gate" then
    love.graphics.rectangle("line", -6, -6, 12, 12)
    love.graphics.circle("line", 0, 0, 3.2)
  else
    love.graphics.line(-5, 0, 5, 0)
    love.graphics.line(0, -5, 0, 5)
  end
  love.graphics.pop()
end

local function drawRooms(match, now, fonts)
  for _, room in ipairs(match.rooms) do
    drawHull(match, room, now)
    if match.selected == room.id then
      col({ 243 / 255, 240 / 255, 232 / 255, 0.85 })
      love.graphics.setLineWidth(2)
      for _, c in ipairs(room.cells) do
        local x, y, w, h = cellRect(match, c.x, c.y, 1.2)
        rr("line", x, y, w, h, 6)
      end
    end
    if room.type == "core" then
      local breath = 0.55 + math.sin(now * 0.003) * 0.2
      col({ 243 / 255, 240 / 255, 232 / 255, 0.12 + breath * 0.08 })
      love.graphics.circle("fill", room.cx, room.cy, 11 + breath * 2)
      col({ 243 / 255, 240 / 255, 232 / 255, 0.88 })
      if fonts and fonts.tiny then
        love.graphics.setFont(fonts.tiny)
        love.graphics.printf("CORE", room.cx - 20, room.cy - 6, 40, "center")
      end
    elseif room.built and not room.dead then
      glyph(room, now)
    end
  end
end

local function drawKapsel(k, x, y, facing)
  local bob = k.state == "idle" and 0 or math.sin(k.bob or 0) * 0.7
  love.graphics.push()
  love.graphics.translate(x, y + bob)
  love.graphics.rotate(facing or 0)
  col({ 0, 0, 0, 0.28 })
  love.graphics.ellipse("fill", 0.4, 4.6, 6, 1.8)
  col("#f3f0e8")
  rr("fill", -6.8, -3.25, 13.6, 6.5, 3.25)
  col({ 1, 1, 1, 0.55 })
  rr("fill", -5.4, -2.4, 6.4, 2.1, 1)
  local j = k.job
  local pip
  if j and j.kind == "build" then pip = "#8d6b4a"
  elseif j and j.kind == "produce" and j.target and j.target.type == "extractor" then pip = "#d56b8c"
  elseif j and j.kind == "produce" then pip = "#5ea86a"
  elseif j and j.kind == "staff" then pip = "#7b88a3"
  elseif j and j.kind == "cook" then pip = "#f0c24a"
  elseif j and j.kind == "haul" then pip = "#e07898"
  end
  if pip then
    col(pip)
    love.graphics.circle("fill", -6.8 + 2.4, 0, 1.35)
  end
  love.graphics.pop()
  if k.carry then
    local c = k.carry == "mineral" and "#e07898" or (k.carry == "food" and "#f0c24a" or "#6fbf6a")
    col(c)
    love.graphics.rectangle("fill", x - 3.2, y - 11 + bob, 6.4, 4.4)
  end
end

local function drawKapsels(match)
  for _, k in ipairs(match.kapsels) do
    local x = k.x + (k.ox or 0)
    local y = k.y + (k.oy or 0)
    local facing = k.facing or 0
    if k.path and k.path[1] then
      local L = match.layout
      local tx = L.ox + (k.path[1].x + 0.5) * L.cell
      local ty = L.oy + (k.path[1].y + 0.5) * L.cell
      facing = math.atan2(ty - y, tx - x)
    end
    drawKapsel(k, x, y, facing)
  end
end

local function drawBeams(match)
  col({ 243 / 255, 240 / 255, 232 / 255, 0.28 })
  love.graphics.setLineWidth(1)
  for _, k in ipairs(match.kapsels) do
    if k.assignment and k.state == "walking" then
      local room
      for _, r in ipairs(match.rooms) do
        if r.id == k.assignment then room = r break end
      end
      if room and room.type ~= "core" and not room.dead then
        love.graphics.line(k.x + (k.ox or 0), k.y + (k.oy or 0), room.cx, room.cy)
      end
    end
  end
end

local function drawEnemies(match, now)
  for _, e in ipairs(match.enemies) do
    if e.cloaked then
      love.graphics.setColor(1, 1, 1, 0.12 + math.abs(math.sin((now or 0) * 0.008)) * 0.08)
    end
    love.graphics.push()
    love.graphics.translate(e.x, e.y)
    love.graphics.rotate((e.dir or 0) + math.pi / 2)
    col({ 0, 0, 0, 0.35 })
    love.graphics.polygon("fill", 0, -e.r + 2, e.r - 1, e.r * 0.75, -e.r + 1, e.r * 0.75)
    col("#e24b52")
    love.graphics.polygon("fill", 0, -e.r, e.r, e.r * 0.75, 0, e.r * 0.28, -e.r, e.r * 0.75)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
    if e.hp < e.maxhp then
      col({ 1, 1, 1, 0.35 })
      love.graphics.rectangle("fill", e.x - 8, e.y - e.r - 7, 16, 2)
      col("#e24b52")
      love.graphics.rectangle("fill", e.x - 8, e.y - e.r - 7, 16 * (e.hp / e.maxhp), 2)
    end
  end
end

local function drawShots(match)
  for _, s in ipairs(match.shots) do
    local dx = s.target and (s.target.x - s.x) or 0
    local dy = s.target and (s.target.y - s.y) or 0
    local d = math.sqrt(dx * dx + dy * dy)
    if d < 1 then d = 1 end
    col({ 243 / 255, 240 / 255, 232 / 255, 0.7 })
    love.graphics.setLineWidth(1.6)
    love.graphics.line(s.x, s.y, s.x - (dx / d) * 10, s.y - (dy / d) * 10)
    col("#fff8e8")
    love.graphics.circle("fill", s.x, s.y, 2.8)
  end
end

local function drawFx(match)
  for _, f in ipairs(match.fx or {}) do
    local a = math.max(0, 1 - f.t / f.life)
    if f.kind == "spark" or f.kind == "pulse" or f.kind == "kiss" or f.kind == "assign" then
      col(f.hue or "#f3f0e8", a)
      love.graphics.setLineWidth(2)
      love.graphics.circle("line", f.x, f.y, 4 + f.t * 24)
    elseif f.kind == "burst" then
      col(f.hue or "#e24b52", a)
      for i = 0, 7 do
        local ang = (i / 8) * PI2 + f.t * 6
        local r = 3 + f.t * 22
        love.graphics.circle("fill", f.x + math.cos(ang) * r, f.y + math.sin(ang) * r, 1.8 * a)
      end
    else
      col(f.hue or "#fff6d8", 0.55 * a)
      love.graphics.circle("fill", f.x, f.y, 7 + f.t * 18)
    end
  end
end

local function drawGhost(match, ghost)
  if not ghost or not ghost.cells or #ghost.cells == 0 then return end
  if ghost.ok then col({ 94 / 255, 168 / 255, 106 / 255, 0.38 }) else col({ 226 / 255, 75 / 255, 82 / 255, 0.35 }) end
  for _, c in ipairs(ghost.cells) do
    local x, y, w, h = cellRect(match, c.x, c.y, 3)
    rr("fill", x, y, w, h, 5)
  end
end

local function drawFloats(match, fonts)
  for _, f in ipairs(match.floats or {}) do
    local a = 1 - f.t / f.life
    local c = f.color == "mineral" and "#e07898" or (f.color == "biomass" and "#6fbf6a" or "#f0c24a")
    col(c, a)
    if fonts and fonts.tiny then
      love.graphics.setFont(fonts.tiny)
      love.graphics.printf(f.text or "+", f.x - 20, f.y - f.t * 18, 40, "center")
    end
  end
end

local function drawAuras(match, now)
  for _, room in ipairs(match.rooms) do
    if room.type == "shield" and room.built and not room.dead then
      local pulse = 0.12 + math.sin(now * 0.004 + room.id) * 0.05
      col({ 110 / 255, 195 / 255, 201 / 255, 0.22 + pulse })
      love.graphics.setLineWidth(1.4)
      love.graphics.circle("line", room.cx, room.cy, match.layout.cell * 4.2 + math.sin(now * 0.003) * 2)
    elseif room.type == "scanner" and room.built and not room.dead then
      local staff = false
      for _, k in ipairs(match.kapsels) do
        if k.assignment == room.id then staff = true break end
      end
      if staff then
        local sweep = (now * 0.0024 + room.id) % PI2
        local r = sim.scanRange(match)
        col({ 112 / 255, 180 / 255, 224 / 255, 0.12 })
        love.graphics.arc("fill", "pie", room.cx, room.cy, r, sweep - 0.55, sweep + 0.55)
      end
    end
  end
end

function M.drawWorld(match, w, h, now, ghost, fonts)
  if not stars then seedStars(88) end
  local look = levels.worldLook(match.level and match.level.world)
  col(look.void or "#040406")
  love.graphics.rectangle("fill", 0, 0, w, h)
  col(look.nebula0 or "#22283a", 0.28)
  love.graphics.circle("fill", w * 0.42, h * 0.38, math.min(w, h) * 0.42)
  col(look.haze, 0.55)
  love.graphics.ellipse("fill", w * 0.28, h * 0.22, w * 0.38, 48)
  for _, st in ipairs(stars) do
    local tw = 0.55 + math.sin(now * 0.0018 + st.p) * 0.45
    col({ 236 / 255, 234 / 255, 226 / 255, st.a * tw })
    love.graphics.circle("fill", st.x * w, st.y * h, st.r)
  end
  for _, m in ipairs(motes) do
    local x = ((m.x + now * 0.00002 * m.s) % 1) * w
    local y = ((m.y + math.sin(now * 0.0004 + m.p) * 0.02) % 1) * h
    col({ 243 / 255, 240 / 255, 232 / 255, m.a })
    love.graphics.circle("fill", x, y, m.r)
  end

  local L = match.layout
  col(look.grid or { 1, 1, 1, 0.045 })
  love.graphics.setLineWidth(1)
  for i = 0, match.cols do
    local x = L.ox + i * L.cell + 0.5
    love.graphics.line(x, L.oy, x, L.oy + L.gridH)
  end
  for j = 0, match.rows do
    local y = L.oy + j * L.cell + 0.5
    love.graphics.line(L.ox, y, L.ox + L.gridW, y)
  end

  local ox, oy = 0, 0
  if (match.shake or 0) > 0 then
    ox = (math.random() - 0.5) * match.shake * 10
    oy = (math.random() - 0.5) * match.shake * 10
    love.graphics.push()
    love.graphics.translate(ox, oy)
  end

  drawTerrain(match, now)
  drawFoldRibbon(match, now)
  drawRoomGlow(match, now)
  drawValid(match)
  drawAuras(match, now)
  drawRooms(match, now, fonts)
  drawBeams(match)
  drawKapsels(match)
  drawEnemies(match, now)
  drawShots(match)
  drawFx(match)
  drawGhost(match, ghost)
  drawFloats(match, fonts)

  if (match.shake or 0) > 0 then love.graphics.pop() end

  love.graphics.setColor(0, 0, 0, 0.28)
  love.graphics.rectangle("fill", 0, 0, w, 10)
  love.graphics.rectangle("fill", 0, h - 10, w, 10)
  if match.thinkLocked then
    col({ 70 / 255, 110 / 255, 160 / 255, 0.1 })
    love.graphics.rectangle("fill", 0, 0, w, h)
    local beat = math.sin(now * 0.003)
    col({ 160 / 255, 200 / 255, 240 / 255, 0.18 + beat * 0.08 })
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", w / 2, h * 0.42, 52 + beat * 4)
  end
  if match.flare and (match.flare.warning or 0) > 0 then
    col({ 224 / 255, 122 / 255, 74 / 255, 0.12 * match.flare.warning })
    love.graphics.rectangle("fill", 0, 0, w, h)
  end
  if match.pulse and match.pulse > 0 then
    col({ 243 / 255, 240 / 255, 232 / 255, math.min(0.16, match.pulse * 0.35) })
    love.graphics.rectangle("fill", 0, 0, w, h)
  end
end

M.hex = hex
M.col = col

return M

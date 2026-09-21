-- Station world: quiet void, readable jobs, Grapefrukt-ish hulls.
local sim = require("sim")
local levels = require("levels")

local M = {}
local stars
local PI2 = math.pi * 2

local ROOM_TAG = {
  corridor = "HALL", garden = "GROW", extractor = "MINE", weapons = "GUN",
  kitchen = "COOK", quarters = "BERTH", shield = "AEGIS", gate = "GATE",
  heater = "HEAT", scanner = "SCAN", beacon = "BEAC", core = "CORE",
}

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

local function dashLine(x1, y1, x2, y2, on, off)
  local dx, dy = x2 - x1, y2 - y1
  local len = math.sqrt(dx * dx + dy * dy)
  if len < 1 then return end
  local ux, uy = dx / len, dy / len
  local d, draw = 0, true
  on, off = on or 4, off or 5
  while d < len do
    local n = math.min(draw and on or off, len - d)
    if draw then
      love.graphics.line(x1 + ux * d, y1 + uy * d, x1 + ux * (d + n), y1 + uy * (d + n))
    end
    d = d + n
    draw = not draw
  end
end

local function seedStars(n)
  stars = {}
  local s = 1337
  local function rnd()
    s = (s * 1664525 + 1013904223) % 4294967296
    return s / 4294967296
  end
  for _ = 1, n do
    stars[#stars + 1] = { x = rnd(), y = rnd(), r = rnd() * 0.7 + 0.2, a = rnd() * 0.22 + 0.05, p = rnd() * PI2 }
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

local function staffCount(match, room)
  local n = 0
  for _, k in ipairs(match.kapsels) do
    if k.assignment == room.id then n = n + 1 end
  end
  return n
end

local function jobHue(k)
  if k.carry == "mineral" then return "#e07898" end
  if k.carry == "food" then return "#f0c24a" end
  if k.carry == "biomass" then return "#6fbf6a" end
  local j = k.job
  if not j then return "#f3f0e8" end
  if j.kind == "build" then return "#8d6b4a" end
  if j.kind == "produce" and j.target and j.target.type == "extractor" then return "#d56b8c" end
  if j.kind == "produce" then return "#5ea86a" end
  if j.kind == "cook" then return "#f0c24a" end
  if j.kind == "haul" then return "#e07898" end
  if j.kind == "recruit" then return "#d4844a" end
  if j.kind == "staff" then
    if j.target and j.target.type == "scanner" then return "#70b4e0" end
    if j.target and j.target.type == "heater" then return "#e07a4a" end
    return "#7b88a3"
  end
  return "#f3f0e8"
end

local function nodePix(match, node)
  local L = match.layout
  return L.ox + (node.x + 0.5) * L.cell, L.oy + (node.y + 0.5) * L.cell
end

local function drawTerrain(match, now)
  for _, d in ipairs(match.level.deposits or {}) do
    local x, y, w, h = cellRect(match, d.x, d.y, 7)
    col("#e07898", 0.55)
    local cx, cy = x + w / 2, y + h / 2
    love.graphics.rectangle("fill", cx - 1.6, y + 3, 3.2, h - 6)
    love.graphics.rectangle("fill", x + 3, cy - 1.6, w - 6, 3.2)
  end
  for _, b in ipairs(match.level.blocked or {}) do
    local x, y, w, h = cellRect(match, b.x, b.y, 3)
    col("#0b0c10")
    rr("fill", x, y, w, h, 4)
    col({ 1, 1, 1, 0.05 })
    rr("line", x, y, w, h, 4)
  end
  for key in pairs(match.ice or {}) do
    local gx, gy = key:match("^([^,]+),([^,]+)$")
    gx, gy = tonumber(gx), tonumber(gy)
    if gx then
      local x, y, w, h = cellRect(match, gx, gy, 4)
      col({ 186 / 255, 220 / 255, 1, 0.2 })
      rr("fill", x, y, w, h, 5)
      col({ 220 / 255, 236 / 255, 1, 0.32 })
      rr("line", x, y, w, h, 5)
    end
  end
  for _, well in ipairs(match.wells or {}) do
    local L = match.layout
    local x = L.ox + (well.x + 0.5) * L.cell
    local y = L.oy + (well.y + 0.5) * L.cell
    col({ 160 / 255, 150 / 255, 1, 0.16 })
    love.graphics.setLineWidth(1.2)
    love.graphics.circle("line", x, y, 16)
  end
  for _, relic in ipairs(match.relics or {}) do
    local x, y, w, h = cellRect(match, relic.x, relic.y, 7)
    local cx, cy = x + w / 2, y + h / 2
    if relic.linked then
      col({ 232 / 255, 217 / 255, 160 / 255, 0.28 })
      love.graphics.setLineWidth(1.6)
    else
      col({ 180 / 255, 190 / 255, 210 / 255, 0.16 })
      love.graphics.setLineWidth(1.1)
    end
    love.graphics.circle("line", cx, cy + 2, 15)
    col(relic.linked and "#e8d9a0" or "#9aa0ae")
    love.graphics.polygon("fill", x + w / 2, y - 6, x + w, y + h, x, y + h)
  end
end

local function drawFoldRibbon(match)
  local gates = {}
  for _, r in ipairs(match.rooms) do
    if r.type == "gate" and r.built and not r.dead then gates[#gates + 1] = r end
  end
  if #gates < 2 then return end
  love.graphics.setLineWidth(1.4)
  for i = 1, #gates do
    for j = i + 1, #gates do
      local a, b = gates[i], gates[j]
      col({ 196 / 255, 170 / 255, 240 / 255, 0.22 })
      dashLine(a.cx, a.cy, b.cx, b.cy, 5, 7)
    end
  end
end

local function drawValid(match)
  if not match.tool or match.tool == "assign" or match.tool == "salvage" or match.tool == "overload" then return end
  col({ 94 / 255, 168 / 255, 106 / 255, 0.08 })
  for y = 0, match.rows - 1 do
    for x = 0, match.cols - 1 do
      if sim.canPlace(match, match.tool, x, y, match.rot) then
        local rx, ry, rw, rh = cellRect(match, x, y, 5)
        rr("fill", rx, ry, rw, rh, 3)
      end
    end
  end
end

local function drawHull(match, room, now)
  local live = liveSet(room)
  local color = room.def and room.def.hue or "#888888"
  local teach = match.tutorial and match.tutorial.needAssign and match.tutorial.roomId == room.id
  local r, g, b = hex(color)
  local fillA = room.built and 1 or 0.28
  if room.dead then fillA = 0.18 end
  for _, c in ipairs(room.cells) do
    local x, y, w, h = cellRect(match, c.x, c.y, 1.5)
    local rad = hullR(live, c.x, c.y)
    love.graphics.setColor(r, g, b, fillA)
    rr("fill", x, y, w, h, rad)
    love.graphics.setColor(1, 1, 1, room.built and 0.1 or 0.06)
    love.graphics.rectangle("fill", x + 2, y + 1.4, math.max(2, w - 4), 1.1)
    if not room.built then
      local a = teach and (0.5 + math.sin(now * 0.008) * 0.25) or 0.32
      col({ 255 / 255, 220 / 255, 170 / 255, a })
      love.graphics.setLineWidth(teach and 2 or 1.3)
      rr("line", x, y, w, h, rad)
    end
  end
  if not room.built then
    local cost = math.max(1, (room.def and room.def.cost) or 1)
    local p = math.max(0, math.min(1, (room.materials or 0) / cost))
    if (room.progress or 0) > 0 then p = math.max(p, room.progress) end
    if p > 0 then
      local x, y, w, h = cellRect(match, room.cells[1].x, room.cells[1].y, 4)
      col({ 243 / 255, 240 / 255, 232 / 255, 0.14 })
      love.graphics.rectangle("fill", x, y + h - 3, w, 3, 1, 1)
      col({ 243 / 255, 240 / 255, 232 / 255, 0.7 })
      love.graphics.rectangle("fill", x, y + h - 3, w * p, 3, 1, 1)
    end
  end
end

local function glyph(room, now, staffed)
  love.graphics.push()
  love.graphics.translate(room.cx, room.cy)
  col({ 243 / 255, 240 / 255, 232 / 255, staffed and 0.82 or 0.38 })
  love.graphics.setLineWidth(1.5)
  if room.type == "garden" then
    for i = -1, 1 do
      love.graphics.line(i * 7, 4, i * 7, -6)
      love.graphics.ellipse("fill", i * 7 - 3, -5, 3.2, 1.6)
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
    if staffed then
      local sweep = (now * 0.002) % PI2
      col({ 112 / 255, 180 / 255, 224 / 255, 0.5 })
      love.graphics.line(0, 0, math.cos(sweep) * 10, math.sin(sweep) * 10)
    end
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

local function drawStock(room)
  local items = {}
  for _, res in ipairs({ "mineral", "food", "biomass" }) do
    local n = math.floor(room.stock and room.stock[res] or 0)
    for _ = 1, math.min(n, 6) do items[#items + 1] = res end
  end
  for i, res in ipairs(items) do
    local c = res == "mineral" and "#e07898" or (res == "food" and "#f0c24a" or "#6fbf6a")
    col(c, 0.9)
    local ix = room.cx - 10 + ((i - 1) % 3) * 7
    local iy = room.cy - 16 + math.floor((i - 1) / 3) * 6
    love.graphics.rectangle("fill", ix, iy, 5, 5, 1, 1)
  end
end

local function drawRooms(match, now, fonts)
  for _, room in ipairs(match.rooms) do
    drawHull(match, room, now)
    local nStaff = staffCount(match, room)
    if match.selected == room.id then
      col({ 243 / 255, 240 / 255, 232 / 255, 0.9 })
      love.graphics.setLineWidth(2)
      for _, c in ipairs(room.cells) do
        local x, y, w, h = cellRect(match, c.x, c.y, 1.2)
        rr("line", x, y, w, h, 6)
      end
    end
    if (room.ring or 0) > 0.05 and not room.dead then
      col({ 243 / 255, 240 / 255, 232 / 255, 0.45 * room.ring })
      love.graphics.setLineWidth(1.6)
      love.graphics.circle("line", room.cx, room.cy, match.layout.cell * (0.7 + (1 - room.ring) * 0.55))
    end
    if room.type == "core" then
      col({ 243 / 255, 240 / 255, 232 / 255, 0.16 })
      love.graphics.circle("fill", room.cx, room.cy, 10)
      col({ 243 / 255, 240 / 255, 232 / 255, 0.88 })
      if fonts and fonts.tiny then
        love.graphics.setFont(fonts.tiny)
        love.graphics.printf("CORE", room.cx - 20, room.cy - 6, 40, "center")
      end
    elseif room.built and not room.dead then
      glyph(room, now, nStaff > 0)
      if nStaff > 0 then
        col({ 243 / 255, 240 / 255, 232 / 255, 0.22 })
        love.graphics.setLineWidth(1.1)
        love.graphics.circle("line", room.cx, room.cy, match.layout.cell * 0.48)
        for i = 1, math.min(nStaff, 4) do
          col("#f3f0e8")
          love.graphics.circle("fill", room.cx - 6 + (i - 1) * 4, room.cy + match.layout.cell * 0.38, 1.6)
        end
      end
      drawStock(room)
    elseif not room.built then
      if fonts and fonts.tiny then
        love.graphics.setFont(fonts.tiny)
        col({ 255 / 255, 220 / 255, 170 / 255, 0.8 })
        love.graphics.printf("BUILD", room.cx - 22, room.cy - 6, 44, "center")
      end
    end
    if room.built and not room.dead and room.type ~= "core" and nStaff == 0 then
      local needs = room.type == "weapons" or room.type == "scanner" or room.type == "heater"
        or room.type == "garden" or room.type == "extractor" or room.type == "kitchen" or room.type == "quarters"
      if needs and fonts and fonts.tiny then
        love.graphics.setFont(fonts.tiny)
        col({ 243 / 255, 240 / 255, 232 / 255, 0.28 })
        love.graphics.printf(ROOM_TAG[room.type] or "", room.cx - 22, room.cy + 10, 44, "center")
      end
    end
  end
end

local function drawKapsel(k, x, y, facing)
  local idle = k.state == "idle" and not k.job
  local bob = idle and 0 or math.sin(k.bob or 0) * 0.5
  love.graphics.push()
  love.graphics.translate(x, y + bob)
  love.graphics.rotate(facing or 0)
  col({ 0, 0, 0, 0.22 })
  love.graphics.ellipse("fill", 0.4, 4.6, 6, 1.6)
  col("#f3f0e8", idle and 0.62 or 1)
  rr("fill", -7.2, -3.4, 14.4, 6.8, 3.4)
  col({ 1, 1, 1, 0.5 })
  rr("fill", -5.6, -2.5, 6.6, 2.1, 1)
  local pip = jobHue(k)
  if k.job or k.carry then
    col(pip)
    love.graphics.circle("fill", -7.2 + 2.6, 0, 2.1)
  end
  love.graphics.pop()
  if k.carry then
    local c = k.carry == "mineral" and "#e07898" or (k.carry == "food" and "#f0c24a" or "#6fbf6a")
    col(c)
    love.graphics.rectangle("fill", x - 3.4, y - 12 + bob, 6.8, 4.6, 1, 1)
  end
end

local function drawPaths(match)
  love.graphics.setLineWidth(1.35)
  for _, k in ipairs(match.kapsels) do
    if k.state == "walking" and k.path and #k.path > 0 then
      local x = k.x + (k.ox or 0)
      local y = k.y + (k.oy or 0)
      col(jobHue(k), 0.42)
      local px, py = x, y
      for _, node in ipairs(k.path) do
        local nx, ny = nodePix(match, node)
        dashLine(px, py, nx, ny, 4, 4)
        px, py = nx, ny
      end
      col(jobHue(k), 0.7)
      love.graphics.circle("line", px, py, 4)
    end
  end
end

local function drawKapsels(match)
  for _, k in ipairs(match.kapsels) do
    local x = k.x + (k.ox or 0)
    local y = k.y + (k.oy or 0)
    local facing = k.facing or 0
    if k.path and k.path[1] then
      local tx, ty = nodePix(match, k.path[1])
      facing = math.atan2(ty - y, tx - x)
    end
    drawKapsel(k, x, y, facing)
  end
end

local function drawTrails(match)
  for _, t in ipairs(match.trails or {}) do
    local a = math.max(0, 1 - t.t / t.life)
    local c = t.resource == "mineral" and "#e07898" or (t.resource == "food" and "#f0c24a" or "#6fbf6a")
    col(c, 0.4 * a)
    love.graphics.circle("fill", t.x, t.y, 2.2 * a + 0.5)
  end
end

local function drawEnemies(match, now)
  for _, e in ipairs(match.enemies) do
    if e.cloaked then
      love.graphics.setColor(1, 1, 1, 0.16 + math.abs(math.sin((now or 0) * 0.006)) * 0.1)
    end
    love.graphics.push()
    love.graphics.translate(e.x, e.y)
    love.graphics.rotate((e.dir or 0) + math.pi / 2)
    col({ 0, 0, 0, 0.3 })
    love.graphics.polygon("fill", 0, -e.r + 2, e.r - 1, e.r * 0.75, -e.r + 1, e.r * 0.75)
    col("#e24b52")
    love.graphics.polygon("fill", 0, -e.r, e.r, e.r * 0.75, 0, e.r * 0.28, -e.r, e.r * 0.75)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
    col({ 1, 1, 1, 0.35 })
    love.graphics.rectangle("fill", e.x - 8, e.y - e.r - 7, 16, 2)
    col("#e24b52")
    love.graphics.rectangle("fill", e.x - 8, e.y - e.r - 7, 16 * (e.hp / e.maxhp), 2)
    if e.target then
      col({ 226 / 255, 75 / 255, 82 / 255, 0.28 })
      love.graphics.setLineWidth(1)
      local p = e.target
      local L = match.layout
      local tx = L.ox + (p.x + 0.5) * L.cell
      local ty = L.oy + (p.y + 0.5) * L.cell
      dashLine(e.x, e.y, tx, ty, 3, 6)
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
      col(f.hue or "#f3f0e8", a * 0.7)
      love.graphics.setLineWidth(1.4)
      love.graphics.circle("line", f.x, f.y, 4 + f.t * 18)
    elseif f.kind == "burst" then
      col(f.hue or "#e24b52", a)
      for i = 0, 5 do
        local ang = (i / 6) * PI2 + f.t * 4
        local r = 3 + f.t * 16
        love.graphics.circle("fill", f.x + math.cos(ang) * r, f.y + math.sin(ang) * r, 1.4 * a)
      end
    else
      col(f.hue or "#fff6d8", 0.35 * a)
      love.graphics.circle("fill", f.x, f.y, 5 + f.t * 12)
    end
  end
end

local function drawGhost(match, ghost)
  if not ghost or not ghost.cells or #ghost.cells == 0 then return end
  if ghost.ok then col({ 94 / 255, 168 / 255, 106 / 255, 0.32 }) else col({ 226 / 255, 75 / 255, 82 / 255, 0.32 }) end
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
      col({ 110 / 255, 195 / 255, 201 / 255, 0.16 })
      love.graphics.setLineWidth(1.2)
      love.graphics.circle("line", room.cx, room.cy, match.layout.cell * 4.2)
    elseif room.type == "scanner" and room.built and not room.dead then
      if staffCount(match, room) > 0 then
        local sweep = (now * 0.0016 + room.id) % PI2
        local r = sim.scanRange(match)
        col({ 112 / 255, 180 / 255, 224 / 255, 0.08 })
        love.graphics.arc("fill", "pie", room.cx, room.cy, r, sweep - 0.4, sweep + 0.4)
      end
    end
  end
end

local function drawThreatRim(match)
  local L = match.layout
  local warn = false
  if match.waves and match.waves.timer and match.waves.timer < 8 and match.waves.timer < 900 then
    warn = true
  end
  if #match.enemies > 0 then warn = true end
  if not warn then return end
  local a = #match.enemies > 0 and 0.45 or 0.28
  col({ 226 / 255, 75 / 255, 82 / 255, a })
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", L.ox - 3, L.oy - 3, L.gridW + 6, L.gridH + 6, 4, 4)
end

function M.drawWorld(match, w, h, now, ghost, fonts)
  if not stars then seedStars(28) end
  local look = levels.worldLook(match.level and match.level.world)
  col(look.void or "#040406")
  love.graphics.rectangle("fill", 0, 0, w, h)
  col(look.nebula0 or "#22283a", 0.12)
  love.graphics.circle("fill", w * 0.45, h * 0.36, math.min(w, h) * 0.34)
  col(look.haze, 0.28)
  love.graphics.ellipse("fill", w * 0.3, h * 0.16, w * 0.32, 36)
  for _, st in ipairs(stars) do
    local tw = 0.78 + math.sin(now * 0.0007 + st.p) * 0.22
    col({ 236 / 255, 234 / 255, 226 / 255, st.a * tw })
    love.graphics.circle("fill", st.x * w, st.y * h, st.r)
  end

  local L = match.layout
  col(look.grid or { 1, 1, 1, 0.028 })
  love.graphics.setLineWidth(1)
  for i = 0, match.cols do
    local x = L.ox + i * L.cell + 0.5
    love.graphics.line(x, L.oy, x, L.oy + L.gridH)
  end
  for j = 0, match.rows do
    local y = L.oy + j * L.cell + 0.5
    love.graphics.line(L.ox, y, L.ox + L.gridW, y)
  end

  if (match.shake or 0) > 0 then
    love.graphics.push()
    love.graphics.translate((math.random() - 0.5) * match.shake * 6, (math.random() - 0.5) * match.shake * 6)
  end

  drawTerrain(match, now)
  drawFoldRibbon(match)
  drawValid(match)
  drawAuras(match, now)
  drawRooms(match, now, fonts)
  drawTrails(match)
  drawPaths(match)
  drawKapsels(match)
  drawEnemies(match, now)
  drawShots(match)
  drawFx(match)
  drawGhost(match, ghost)
  drawFloats(match, fonts)
  drawThreatRim(match)

  if (match.shake or 0) > 0 then love.graphics.pop() end

  if match.thinkLocked then
    col({ 70 / 255, 110 / 255, 160 / 255, 0.05 })
    love.graphics.rectangle("fill", 0, 0, w, h)
  end
  if match.flare and (match.flare.warning or 0) > 0 then
    col({ 224 / 255, 122 / 255, 74 / 255, 0.1 * match.flare.warning })
    love.graphics.rectangle("fill", 0, 0, w, h)
  end
  if match.pulse and match.pulse > 0 then
    col({ 243 / 255, 240 / 255, 232 / 255, math.min(0.1, match.pulse * 0.22) })
    love.graphics.rectangle("fill", 0, 0, w, h)
  end
end

M.hex = hex
M.col = col

return M

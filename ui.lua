-- Portrait iPhone HUD: safe area, 44pt targets, wrapping thumb dock.
local sim = require("sim")
local levels = require("levels")
local saveMod = require("save")
local overlay = require("overlay")
local render = require("render")
local audio = require("audio")

local M = {}

local PAPER = { 243 / 255, 240 / 255, 232 / 255, 1 }
local MUTED = { 243 / 255, 240 / 255, 232 / 255, 0.55 }
local LINE = { 243 / 255, 240 / 255, 232 / 255, 0.12 }
local VOID = { 7 / 255, 8 / 255, 13 / 255, 1 }
local MINERAL = { 224 / 255, 120 / 255, 152 / 255, 1 }
local FOOD = { 240 / 255, 194 / 255, 74 / 255, 1 }
local DANGER = { 226 / 255, 75 / 255, 82 / 255, 1 }

local TOOL_LABELS = {
  assign = "Tap", salvage = "Wreck", overload = "Over", corridor = "Hall",
  garden = "Grow", extractor = "Mine", weapons = "Gun", kitchen = "Cook",
  quarters = "Berth", shield = "Aegis", gate = "Gate", heater = "Heat",
  scanner = "Scan", beacon = "Beac",
}

local CHIP_HUE = {
  wait = "#8d93a3", haul = "#e07898", build = "#8d6b4a", grow = "#5ea86a",
  mine = "#d56b8c", cook = "#f0c24a", berth = "#d4844a", gun = "#7b88a3",
  heat = "#e07a4a", scan = "#70b4e0", walk = "#c8c2b4",
}

local function starText(n)
  n = tonumber(n) or 0
  if n <= 0 then return "---" end
  return string.rep("*", n) .. string.rep("-", math.max(0, 3 - n))
end

local hits = {}
local layout = {}

local function hit(id, x, y, w, h, data)
  hits[#hits + 1] = { id = id, x = x, y = y, w = w, h = h, data = data }
end

local function inside(h, px, py)
  return px >= h.x and py >= h.y and px <= h.x + h.w and py <= h.y + h.h
end

function M.letterbox(sw, sh)
  local aspect = 9 / 19.5
  local w, h = sw, sh
  if w / h > aspect then
    w = h * aspect
  else
    h = w / aspect
  end
  return (sw - w) / 2, (sh - h) / 2, w, h
end

function M.safe(g)
  local top, bottom, left, right = 18, 18, 16, 16
  if love.window and love.window.getSafeArea then
    local ok, sx, sy, sw, sh = pcall(love.window.getSafeArea)
    if ok and sx then
      local ww, hh = love.graphics.getDimensions()
      top = math.max(top, sy)
      left = math.max(left, sx)
      right = math.max(right, ww - (sx + sw))
      bottom = math.max(bottom, hh - (sy + sh))
    end
  end
  -- Convert window-safe to letterboxed local by clamping to the phone frame.
  top = math.max(18, math.min(top, 54))
  bottom = math.max(18, math.min(bottom, 40))
  left = math.max(12, math.min(left, 24))
  right = math.max(12, math.min(right, 24))
  if g then
    g.safeTop, g.safeBottom, g.safeLeft, g.safeRight = top, bottom, left, right
  end
  return top, bottom, left, right
end

local function btn(fonts, x, y, w, h, label, on, ghost)
  w = math.max(w, 44)
  h = math.max(h, 44)
  if on then
    love.graphics.setColor(PAPER)
    love.graphics.rectangle("fill", x, y, w, h, 14, 14)
    love.graphics.setColor(22 / 255, 24 / 255, 34 / 255, 1)
  else
    love.graphics.setColor(243 / 255, 240 / 255, 232 / 255, ghost and 0.06 or 0.12)
    love.graphics.rectangle("fill", x, y, w, h, 14, 14)
    love.graphics.setColor(PAPER)
  end
  love.graphics.setFont(fonts.ui)
  love.graphics.printf(label, x, y + h / 2 - 8, w, "center")
  return x, y, w, h
end

local function brand(fonts, text, x, y, w)
  love.graphics.setFont(fonts.brand)
  love.graphics.setColor(MUTED)
  love.graphics.printf(text, x, y, w, "center")
end

function M.title(g)
  local w, h = g.w, g.h
  local pad = g.safeLeft
  brand(g.fonts, "GRAPEFRUKT, REMEMBERED", 0, g.safeTop + 8, w)
  -- plus-core mark
  do
    local cx, cy, s = w / 2, g.safeTop + 78, 11
    love.graphics.setColor(60 / 255, 68 / 255, 92 / 255, 1)
    for _, p in ipairs({ { 0, 0 }, { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }) do
      love.graphics.rectangle("fill", cx + p[1] * (s + 2) - s / 2, cy + p[2] * (s + 2) - s / 2, s, s, 2, 2)
    end
    love.graphics.setColor(PAPER)
    love.graphics.rectangle("fill", cx - 2.5, cy - 2.5, 5, 5, 1, 1)
  end
  love.graphics.setFont(g.fonts.big)
  love.graphics.setColor(PAPER)
  love.graphics.printf("RHYME", 0, g.safeTop + 118, w, "center")
  love.graphics.setFont(g.fonts.small)
  love.graphics.setColor(MUTED)
  love.graphics.printf("Forty-two stations. Quiet geometry, white kapsels, and a long campaign that ends in Last Geometry.", pad + 8, g.safeTop + 178, w - pad * 2 - 16, "center")
  local st = saveMod.campaignStats(g.save, levels.LEVELS)
  love.graphics.setFont(g.fonts.tiny)
  love.graphics.printf(st.cleared .. "/" .. st.total .. " stations  ·  " .. st.starTotal .. "/" .. st.starMax .. " stars", 0, h - g.safeBottom - 210, w, "center")
  local by = h - g.safeBottom - 188
  local bw = w - pad * 2
  local bx = pad
  local _, y1, _, h1 = btn(g.fonts, bx, by, bw, 48, "Play", true)
  hit("playCampaign", bx, y1, bw, h1)
  local _, y2, _, h2 = btn(g.fonts, bx, by + 56, bw, 48, "Stations", false, true)
  hit("openWorlds", bx, y2, bw, h2)
  local _, y3, _, h3 = btn(g.fonts, bx, by + 112, bw, 48, "How to play", false, true)
  hit("openHow", bx, y3, bw, h3)
end

function M.worlds(g)
  local pad = g.safeLeft
  local y = g.safeTop + 8
  btn(g.fonts, pad, y, 72, 44, "Back", false, true)
  hit("worldsBack", pad, y, 72, 44)
  brand(g.fonts, "WORLDS", 0, y + 12, g.w)
  y = y + 56
  for _, world in ipairs(levels.WORLDS) do
    local open = saveMod.worldUnlocked(g.save, world.id, levels.LEVELS)
    local pack = levels.levelsInWorld(world.id)
    local done, stars = 0, 0
    for _, l in ipairs(pack) do
      if g.save.stars[l.id] then
        done = done + 1
        stars = stars + g.save.stars[l.id]
      end
    end
    local look = levels.worldLook(world.id)
    local r, gb, b = render.hex(look.accent)
    love.graphics.setColor(243 / 255, 240 / 255, 232 / 255, open and 0.08 or 0.04)
    love.graphics.rectangle("fill", pad, y, g.w - pad * 2, 64, 16, 16)
    love.graphics.setColor(r, gb, b, 1)
    love.graphics.rectangle("fill", pad, y + 8, 3, 48)
    love.graphics.setColor(PAPER)
    love.graphics.setFont(g.fonts.ui)
    love.graphics.print(world.id .. "  ·  " .. world.name, pad + 16, y + 10)
    love.graphics.setFont(g.fonts.tiny)
    love.graphics.setColor(MUTED)
    local blurb = open and (world.blurb .. "  " .. done .. "/6  ·  " .. stars .. "/18*") or "Clear the previous shore first."
    love.graphics.printf(blurb, pad + 16, y + 34, g.w - pad * 2 - 24, "left")
    if open then hit("world", pad, y, g.w - pad * 2, 64, world.id) end
    y = y + 72
  end
end

function M.levels(g)
  local pad = g.safeLeft
  local y = g.safeTop + 8
  btn(g.fonts, pad, y, 72, 44, "Back", false, true)
  hit("levelsBack", pad, y, 72, 44)
  local world = nil
  for _, w in ipairs(levels.WORLDS) do
    if w.id == g.worldId then world = w end
  end
  brand(g.fonts, (world and world.name or "WORLD"):upper(), 0, y + 12, g.w)
  y = y + 56
  for _, level in ipairs(levels.levelsInWorld(g.worldId)) do
    local open = g.save.unlocked[level.id]
    love.graphics.setColor(243 / 255, 240 / 255, 232 / 255, open and 0.08 or 0.04)
    love.graphics.rectangle("fill", pad, y, g.w - pad * 2, 48, 14, 14)
    love.graphics.setFont(g.fonts.small)
    love.graphics.setColor(PAPER)
    local stars = g.save.stars[level.id]
    local star = g.save.stars[level.id] and starText(g.save.stars[level.id]) or "---"
    love.graphics.print(level.id, pad + 12, y + 16)
    love.graphics.print(level.name, pad + 58, y + 16)
    love.graphics.printf(star, pad, y + 16, g.w - pad * 2 - 12, "right")
    if open then hit("level", pad, y, g.w - pad * 2, 48, level.id) end
    y = y + 56
  end
end

function M.brief(g)
  local pad = g.safeLeft
  local y = g.safeTop + 8
  local level = g.chosen
  btn(g.fonts, pad, y, 72, 44, "Back", false, true)
  hit("briefBack", pad, y, 72, 44)
  brand(g.fonts, level.id, 0, y + 12, g.w)
  y = y + 64
  love.graphics.setFont(g.fonts.tiny)
  love.graphics.setColor(MUTED)
  love.graphics.printf((level.lesson or ""):upper(), pad, y, g.w - pad * 2, "left")
  y = y + 28
  local world = nil
  for _, w in ipairs(levels.WORLDS) do
    if w.id == level.world then world = w end
  end
  local pack = levels.levelsInWorld(level.world)
  local idx = 1
  for i, l in ipairs(pack) do if l.id == level.id then idx = i end end
  local earned = g.save.stars[level.id] or 0
  local best = earned > 0 and starText(earned) or "unplayed"
  love.graphics.printf((world and world.name or "") .. "  ·  " .. idx .. " of 6  ·  par " .. tostring(level.par) .. "s  ·  " .. best, pad, y, g.w - pad * 2, "left")
  y = y + 28
  love.graphics.setFont(g.fonts.ui)
  love.graphics.setColor(PAPER)
  love.graphics.printf(level.name, pad, y, g.w - pad * 2, "left")
  y = y + 36
  love.graphics.setFont(g.fonts.small)
  love.graphics.setColor(MUTED)
  love.graphics.printf(level.briefing or "", pad, y, g.w - pad * 2, "left")
  local bw = g.w - pad * 2
  local by = g.h - g.safeBottom - 64
  btn(g.fonts, pad, by, bw, 48, "Begin", true)
  hit("briefStart", pad, by, bw, 48)
end

function M.how(g)
  local pad = g.safeLeft
  local y = g.safeTop + 8
  btn(g.fonts, pad, y, 72, 44, "Back", false, true)
  hit("howBack", pad, y, 72, 44)
  brand(g.fonts, "MANUAL", 0, y + 12, g.w)
  y = y + 56
  local articles = {
    { "Place", "Pick a room from the thumb strip, rotate if you need to, then tap empty floor that kisses the station. Blueprints are not yet walkable." },
    { "Assign", "White kapsels work where you point them. Tap a room to send the nearest idle kapsel. Tap Recall to pull one home." },
    { "Feed & mine", "Gardens grow. Extractors only bite pink fields. Later kitchens cook sludge into pantry meals." },
    { "Hold", "Waves come from the void. Weapons are mute until staffed. New worlds add flares, relics, gates, ice, cloaks, gravity, and overclocks." },
    { "The bag", "Late stations deal a random tetromino. You still pick the room’s job. Rotate, or Hold to park a stubborn I or O." },
  }
  love.graphics.setFont(g.fonts.small)
  for _, a in ipairs(articles) do
    love.graphics.setColor(PAPER)
    love.graphics.print(a[1], pad, y)
    y = y + 18
    love.graphics.setColor(MUTED)
    love.graphics.printf(a[2], pad, y, g.w - pad * 2, "left")
    y = y + 58
  end
end

local function drawMini(fonts, name, x, y, next)
  local cells = sim.fitPiece(name)
  local on = {}
  for _, p in ipairs(cells) do
    on[(p[1] or 0) .. "," .. (p[2] or 0)] = true
  end
  local s = 6
  love.graphics.setColor(243 / 255, 240 / 255, 232 / 255, next and 0.08 or 0.14)
  love.graphics.rectangle("fill", x, y, s * 4 + 4, s * 4 + 4, 4, 4)
  for yy = 0, 3 do
    for xx = 0, 3 do
      if on[xx .. "," .. yy] then
        love.graphics.setColor(PAPER)
        love.graphics.rectangle("fill", x + 2 + xx * s, y + 2 + yy * s, s - 1, s - 1, 1, 1)
      end
    end
  end
end

function M.play(g)
  local match = g.match
  if not match then return end
  local padL, padR = g.safeLeft, g.safeRight
  local top = g.safeTop
  local hy = top + 4
  love.graphics.setColor(7 / 255, 8 / 255, 13 / 255, 0.82)
  love.graphics.rectangle("fill", 0, 0, g.w, hy + 78)
  btn(g.fonts, padL, hy, 44, 44, "II", false, true)
  hit("pause", padL, hy, 44, 44)
  local speedLabel = match.thinkLocked and "GO" or (tostring(g.speed) .. "x")
  btn(g.fonts, g.w - padR - 56, hy, 56, 44, speedLabel, match.thinkLocked)
  hit("speed", g.w - padR - 56, hy, 56, 44)

  local mineral = math.floor(sim.coreStock(match, "mineral"))
  local food = math.floor(sim.coreStock(match, "food"))
  local function stat(x, color, n, label)
    love.graphics.setColor(color)
    love.graphics.circle("fill", x, hy + 12, 4)
    love.graphics.setFont(g.fonts.ui)
    love.graphics.setColor(PAPER)
    love.graphics.print(tostring(n), x + 8, hy + 2)
    love.graphics.setFont(g.fonts.tiny)
    love.graphics.setColor(MUTED)
    love.graphics.print(label, x + 8, hy + 22)
  end
  stat(padL + 54, MINERAL, mineral, "ORE")
  stat(padL + 122, FOOD, food, "MEALS")
  stat(padL + 196, PAPER, #match.kapsels, "CREW")

  local goX = g.w - padR - 56
  love.graphics.setFont(g.fonts.tiny)
  if match.thinkLocked then
    love.graphics.setColor(PAPER)
    love.graphics.rectangle("fill", goX - 78, hy + 6, 70, 32, 10, 10)
    love.graphics.setColor(22 / 255, 24 / 255, 34 / 255, 1)
    love.graphics.setFont(g.fonts.small)
    love.graphics.printf("THINK", goX - 78, hy + 14, 70, "center")
  else
    local wave = "QUIET"
    love.graphics.setColor(MUTED)
    if #match.enemies > 0 then
      wave = "THREAT " .. tostring(#match.enemies)
      love.graphics.setColor(DANGER)
    elseif match.waves.timer < 900 then
      local s = math.max(0, math.ceil(match.waves.timer))
      wave = (match.waves.index == 0 and ("IN " .. s .. "s") or ("W" .. (match.waves.index + 1) .. " " .. s .. "s"))
      if s <= 8 then love.graphics.setColor(DANGER) end
    end
    love.graphics.setFont(g.fonts.small)
    love.graphics.printf(wave, goX - 108, hy + 14, 100, "right")
  end

  -- job chips
  local chips = sim.jobChips(match)
  local cx = padL
  local cy = hy + 50
  love.graphics.setFont(g.fonts.tiny)
  for _, c in ipairs(chips) do
    local label = (c.n or 1) .. " " .. string.upper(c.label or "")
    local tw = math.max(52, 14 + #label * 6)
    love.graphics.setColor(243 / 255, 240 / 255, 232 / 255, 0.07)
    love.graphics.rectangle("fill", cx, cy, tw, 18, 8, 8)
    local r, gb, b = render.hex(render.JOB_HUE[c.id] or CHIP_HUE[c.id] or "#f3f0e8")
    love.graphics.setColor(r, gb, b, 1)
    love.graphics.circle("fill", cx + 8, cy + 9, 3)
    love.graphics.setColor(PAPER)
    love.graphics.print(label, cx + 14, cy + 4)
    cx = cx + tw + 4
  end

  -- bag
  local bagY = cy + 22
  local bagH = 0
  if match.mechanics.pieceQueue and match.piece then
    bagH = 42
    local bx = padL
    love.graphics.setFont(g.fonts.tiny)
    love.graphics.setColor(MUTED)
    love.graphics.print("HOLD", bx, bagY)
    if match.held then
      drawMini(g.fonts, match.held, bx, bagY + 12, true)
    else
      love.graphics.setColor(243 / 255, 240 / 255, 232 / 255, 0.06)
      love.graphics.rectangle("fill", bx, bagY + 12, 28, 28, 4, 4)
    end
    bx = bx + 40
    love.graphics.setColor(PAPER)
    love.graphics.print("NOW", bx, bagY)
    drawMini(g.fonts, match.piece, bx, bagY + 12, false)
    bx = bx + 40
    love.graphics.setColor(MUTED)
    love.graphics.print("NEXT", bx, bagY)
    for i = 1, math.min(2, #(match.queue or {})) do
      drawMini(g.fonts, match.queue[i], bx, bagY + 12, true)
      bx = bx + 34
    end
  end

  -- dock at thumb
  local tools = sim.paletteFor(match.level)
  local maxPerRow = 7
  local gap = 6
  local inner = g.w - padL - padR
  local btnW = math.max(44, math.min(56, math.floor((inner - gap * (maxPerRow - 1)) / maxPerRow)))
  local rows = math.ceil(#tools / maxPerRow)
  local toolH = 48
  local row2h = 44
  local dockH = 8 + rows * (toolH + gap) + row2h + 8
  local dockY = g.h - g.safeBottom - dockH
  love.graphics.setColor(7 / 255, 8 / 255, 13 / 255, 0.35)
  love.graphics.rectangle("fill", 0, dockY - 8, g.w, dockH + g.safeBottom + 8)

  local locked = match.tutorial and match.tutorial.needAssign
  for i, tool in ipairs(tools) do
    local coln = ((i - 1) % maxPerRow)
    local row = math.floor((i - 1) / maxPerRow)
    local x = padL + coln * (btnW + gap)
    local y = dockY + row * (toolH + gap)
    local on = match.tool == tool
    local disabled = locked and tool ~= "assign"
    if on and not disabled then
      love.graphics.setColor(PAPER)
      love.graphics.rectangle("fill", x, y, btnW, toolH, 14, 14)
    else
      love.graphics.setColor(243 / 255, 240 / 255, 232 / 255, disabled and 0.04 or 0.08)
      love.graphics.rectangle("fill", x, y, btnW, toolH, 14, 14)
    end
    local hue = (sim.ROOMS[tool] and sim.ROOMS[tool].hue) or (tool == "assign" and "#f3f0e8" or "#e24b52")
    local r, gb, b = render.hex(hue)
    love.graphics.setColor(r, gb, b, disabled and 0.3 or 1)
    love.graphics.rectangle("fill", x + btnW / 2 - 9, y + 8, 18, 10, 3, 3)
    love.graphics.setFont(g.fonts.tiny)
    if on and not disabled then
      love.graphics.setColor(22 / 255, 24 / 255, 34 / 255, 1)
    else
      love.graphics.setColor(PAPER[1], PAPER[2], PAPER[3], disabled and 0.32 or 0.85)
    end
    love.graphics.printf(TOOL_LABELS[tool] or tool, x, y + 24, btnW, "center")
    if not disabled then hit("tool", x, y, btnW, toolH, tool) end
  end
  local row2y = dockY + rows * (toolH + gap)
  local rw = math.floor((inner - 24) / 4)
  local labels = { "Rotate", match.held and "Hold" or "Hold", "Recall", audio.isMuted() and "Muted" or "Sound" }
  local ids = { "rotate", "hold", "recall", "mute" }
  for i = 1, 4 do
    local x = padL + (i - 1) * (rw + 8)
    local on = i == 2 and match.held
    btn(g.fonts, x, row2y, rw, row2h, labels[i], on, true)
    hit(ids[i], x, row2y, rw, row2h)
  end

  -- objective
  love.graphics.setFont(g.fonts.tiny)
  love.graphics.setColor(MUTED)
  love.graphics.printf(sim.objectiveText(match), padL, dockY - 22, g.w - padL - padR, "center")

  -- hint
  local hint = g.hint
  if hint and hint ~= "" then
    local hx, hy2, hw, hh = padL, dockY - 78, g.w - padL - padR, 50
    love.graphics.setColor(8 / 255, 9 / 255, 14 / 255, 0.72)
    love.graphics.rectangle("fill", hx, hy2, hw, hh, 12, 12)
    love.graphics.setFont(g.fonts.small)
    love.graphics.setColor(PAPER)
    love.graphics.printf(hint, hx + 10, hy2 + 8, hw - 20, "left")
  end

  -- overlays
  if g.paused then
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, g.w, g.h)
    love.graphics.setFont(g.fonts.ui)
    love.graphics.setColor(PAPER)
    love.graphics.printf("Paused", 0, g.h / 2 - 80, g.w, "center")
    love.graphics.setFont(g.fonts.small)
    love.graphics.setColor(MUTED)
    love.graphics.printf("The station holds its breath.", 0, g.h / 2 - 48, g.w, "center")
    local bw = g.w - padL * 2
    btn(g.fonts, padL, g.h / 2, bw, 48, "Resume", true)
    hit("resume", padL, g.h / 2, bw, 48)
    btn(g.fonts, padL, g.h / 2 + 56, bw, 48, "Restart", false, true)
    hit("restart", padL, g.h / 2 + 56, bw, 48)
    btn(g.fonts, padL, g.h / 2 + 112, bw, 48, "Stations", false, true)
    hit("pauseMap", padL, g.h / 2 + 112, bw, 48)
  elseif g.ended and match.status ~= "playing" then
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, g.w, g.h)
    local nxt = match.status == "won" and levels.nextLevel(g.chosen.id) or nil
    local worldGate
    if nxt and g.chosen and nxt.world ~= g.chosen.world then
      for _, w in ipairs(levels.WORLDS) do
        if w.id == nxt.world then worldGate = w.name end
      end
    end
    local spec = overlay.endOverlaySpec(match.status, { hasNext = nxt ~= nil, worldGate = worldGate })
    love.graphics.setFont(g.fonts.ui)
    love.graphics.setColor(PAPER)
    love.graphics.printf(spec.title, 0, g.h / 2 - 90, g.w, "center")
    love.graphics.setFont(g.fonts.small)
    love.graphics.setColor(MUTED)
    local body = match.status == "won"
      and (starText(match.stars) .. "  ·  " .. math.ceil(match.time) .. "s")
      or (match.loseReason or "The station failed.")
    love.graphics.printf(body, padL, g.h / 2 - 56, g.w - padL * 2, "center")
    local bw = g.w - padL * 2
    btn(g.fonts, padL, g.h / 2, bw, 48, spec.primary, true)
    hit("endPrimary", padL, g.h / 2, bw, 48)
    if spec.retry then
      btn(g.fonts, padL, g.h / 2 + 56, bw, 48, "Retry", false, true)
      hit("endRetry", padL, g.h / 2 + 56, bw, 48)
    end
    btn(g.fonts, padL, g.h / 2 + (spec.retry and 112 or 56), bw, 48, "Stations", false, true)
    hit("endMap", padL, g.h / 2 + (spec.retry and 112 or 56), bw, 48)
  end

  layout.stage = {
    x = 0,
    y = hy + 52 + bagH + 8,
    w = g.w,
    h = (dockY - 28) - (hy + 52 + bagH + 8),
  }
  layout.hudTop = hy + 52 + bagH
  layout.dockY = dockY
end

function M.stageRect()
  return layout.stage
end

function M.beginFrame()
  hits = {}
end

function M.pick(px, py)
  for i = #hits, 1, -1 do
    local h = hits[i]
    if inside(h, px, py) then return h end
  end
  return nil
end

function M.drawSky(g)
  love.graphics.setColor(VOID)
  love.graphics.rectangle("fill", 0, 0, g.w, g.h)
  love.graphics.setColor(110 / 255, 130 / 255, 190 / 255, 0.1)
  love.graphics.ellipse("fill", g.w * 0.5, -28, g.w * 0.55, 90)
end

return M

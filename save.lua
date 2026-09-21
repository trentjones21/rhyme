-- Campaign save. LÖVE filesystem, not localStorage.
local M = {}
local KEY = "rhyme-save-v1.txt"

local function empty()
  return {
    unlocked = { ["1-01"] = true },
    stars = {},
    last = "1-01",
    seenHow = false,
  }
end

local function encode(save)
  local u, s = {}, {}
  for id in pairs(save.unlocked or {}) do
    if save.unlocked[id] then u[#u + 1] = id end
  end
  table.sort(u)
  for id, n in pairs(save.stars or {}) do
    s[#s + 1] = id .. ":" .. tostring(n)
  end
  table.sort(s)
  return table.concat({
    "last=" .. tostring(save.last or "1-01"),
    "seenHow=" .. (save.seenHow and "1" or "0"),
    "unlocked=" .. table.concat(u, ","),
    "stars=" .. table.concat(s, ","),
  }, "\n")
end

local function decode(raw)
  local save = empty()
  if not raw or raw == "" then return save end
  for line in (raw .. "\n"):gmatch("(.-)\n") do
    local k, v = line:match("^([^=]+)=(.*)$")
    if k == "last" and v ~= "" then
      save.last = v
    elseif k == "seenHow" then
      save.seenHow = v == "1"
    elseif k == "unlocked" then
      for id in (v or ""):gmatch("[^,]+") do
        save.unlocked[id] = true
      end
    elseif k == "stars" then
      for pair in (v or ""):gmatch("[^,]+") do
        local id, n = pair:match("^(.-):(%d+)$")
        if id then save.stars[id] = tonumber(n) or 1 end
      end
    end
  end
  save.unlocked["1-01"] = true
  return save
end

function M.load()
  if not love.filesystem.getInfo(KEY) then return empty() end
  local raw = love.filesystem.read(KEY)
  local ok, save = pcall(decode, raw)
  if not ok or type(save) ~= "table" then return empty() end
  return save
end

function M.write(save)
  love.filesystem.write(KEY, encode(save))
  return save
end

function M.completeLevel(save, levelId, stars, nextId)
  save.stars[levelId] = math.max(save.stars[levelId] or 0, stars or 1)
  save.last = levelId
  if nextId then save.unlocked[nextId] = true end
  return save
end

function M.isUnlocked(save, levelId)
  return save.unlocked[levelId] and true or false
end

function M.worldUnlocked(save, world, levels)
  if world <= 1 then return true end
  for _, l in ipairs(levels) do
    if l.world == world - 1 and not save.stars[l.id] then return false end
  end
  return true
end

function M.campaignStats(save, levels)
  local cleared, starTotal = 0, 0
  for _, l in ipairs(levels) do
    local n = save.stars[l.id]
    if n then
      cleared = cleared + 1
      starTotal = starTotal + n
    end
  end
  return { cleared = cleared, total = #levels, starTotal = starTotal, starMax = #levels * 3 }
end

function M.empty()
  return empty()
end

return M

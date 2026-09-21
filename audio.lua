-- Sparse sine beds and UI ticks, ported from the web tone sheet.
local M = {}

local muted = false
local started = false
local bedScene = "title"
local voices = {}
local lastVoice = {}
local dripT = 0
local rate = 44100

local BEDS = {
  title = { a = 0.012, freqs = { 49, 73.4 } },
  worlds = { a = 0.011, freqs = { 55, 82.4 } },
  how = { a = 0.01, freqs = { 43.65, 65.4 } },
  play = { a = 0.018, freqs = { 46.25, 69.3 } },
}

local TONES = {
  place = { freq = 1680, dur = 0.032, vol = 0.026 },
  tick = { freq = 1860, dur = 0.018, vol = 0.012 },
  assign = { freq = 540, dur = 0.06, vol = 0.032 },
  error = { freq = 180, dur = 0.12, vol = 0.028, slide = 120 },
  built = { freq = 420, dur = 0.1, vol = 0.03, slide = 560 },
  shoot = { freq = 880, dur = 0.03, vol = 0.014, slide = 1400 },
  kill = { freq = 1320, dur = 0.06, vol = 0.028, slide = 880 },
  wave = { freq = 196, dur = 0.16, vol = 0.03, slide = 118 },
  incoming = { freq = 240, dur = 0.14, vol = 0.028, slide = 320 },
  flare = { freq = 98, dur = 0.24, vol = 0.03, slide = 64 },
  win = { freq = 520, dur = 0.16, vol = 0.04, slide = 780 },
  over = { freq = 200, dur = 0.4, vol = 0.036, slide = 70 },
  tap = { freq = 700, dur = 0.035, vol = 0.022 },
  recruit = { freq = 660, dur = 0.14, vol = 0.032, slide = 880 },
  grow = { freq = 392, dur = 0.09, vol = 0.028, slide = 523 },
  mine = { freq = 196, dur = 0.08, vol = 0.028, slide = 262 },
  cook = { freq = 494, dur = 0.08, vol = 0.028, slide = 392 },
  haul = { freq = 330, dur = 0.05, vol = 0.018, slide = 220 },
  hold = { freq = 440, dur = 0.05, vol = 0.024, slide = 330 },
  go = { freq = 392, dur = 0.12, vol = 0.036, slide = 620 },
  relic = { freq = 523, dur = 0.18, vol = 0.036, slide = 784 },
  dock = { freq = 262, dur = 0.16, vol = 0.032, slide = 392 },
  seat = { freq = 494, dur = 0.045, vol = 0.018 },
  supply = { freq = 330, dur = 0.16, vol = 0.032, slide = 494 },
  solar = { freq = 110, dur = 0.24, vol = 0.03, slide = 196 },
  fold = { freq = 415, dur = 0.16, vol = 0.03, slide = 622 },
  frost = { freq = 784, dur = 0.14, vol = 0.028, slide = 988 },
  ghost = { freq = 196, dur = 0.2, vol = 0.028, slide = 147 },
  drip = { freq = 523, dur = 0.07, vol = 0.01 },
  cleared = { freq = 620, dur = 0.14, vol = 0.032, slide = 880 },
}

local VOICE_GAP = {
  shoot = 0.12, wave = 0.28, flare = 0.28, incoming = 0.22, haul = 0.09, tick = 0.08, seat = 0.09,
}

local function audioOk()
  return love.audio and love.sound and love.sound.newSoundData
end

local function beep(freq, dur, vol, slide)
  if muted or not started or not audioOk() then return end
  dur = dur or 0.08
  vol = vol or 0.08
  local n = math.max(8, math.floor(rate * (dur + 0.02)))
  local ok, sd = pcall(love.sound.newSoundData, n, rate, 16, 1)
  if not ok or not sd then return end
  for i = 0, n - 1 do
    local t = i / rate
    local f = freq
    if slide then
      local k = math.min(1, t / dur)
      f = freq + (slide - freq) * k
    end
    local env = (vol or 0.08) * math.exp(-t * (6.5 / math.max(dur, 0.03)))
    if t > dur then env = env * math.max(0, 1 - (t - dur) / 0.02) end
    sd:setSample(i, math.sin(2 * math.pi * f * t) * env)
  end
  local src = love.audio.newSource(sd, "static")
  src:setVolume(1)
  src:play()
end

local function startDrone()
  if not audioOk() then return end
  voices = {}
end

function M.bedFor(scene)
  return BEDS[scene] or BEDS.play
end

function M.setBed(scene)
  bedScene = scene or "title"
  return M.bedFor(bedScene)
end

function M.isMuted()
  return muted
end

function M.setMuted(v)
  muted = not not v
end

function M.unlock()
  started = true
  if #voices == 0 then startDrone() end
end

function M.play(name)
  if not name then return false end
  local now = love.timer and love.timer.getTime() or 0
  local gap = VOICE_GAP[name]
  if gap then
    local prev = lastVoice[name] or 0
    if now - prev < gap then return false end
    lastVoice[name] = now
  end
  local tone = TONES[name]
  if not tone then
    if name == "win" then beep(520, 0.16, 0.04, 780) end
    return true
  end
  beep(tone.freq, tone.dur, tone.vol, tone.slide)
  if name == "win" then beep(780, 0.18, 0.03) end
  if name == "incoming" then beep(168, 0.14, 0.022, 118) end
  if name == "kill" then beep(990, 0.04, 0.018) end
  if name == "go" then beep(523, 0.12, 0.028, 784) end
  if name == "dock" then beep(392, 0.12, 0.022, 523) end
  if name == "supply" then beep(494, 0.12, 0.022, 392) end
  if name == "solar" then beep(165, 0.16, 0.022, 98) end
  if name == "fold" then beep(622, 0.14, 0.022, 311) end
  if name == "frost" then beep(988, 0.1, 0.02, 784) end
  if name == "ghost" then beep(147, 0.16, 0.02, 98) end
  return true
end

function M.update(dt)
  if not started or muted then return end
  dripT = dripT - (dt or 0)
  if dripT <= 0 then
    dripT = 7.2 + math.random() * 1.4
    local spec = M.bedFor(bedScene)
    local f = spec.freqs[2] or spec.freqs[1] * 1.5
    beep(f, 0.07, 0.008)
  end
end

return M

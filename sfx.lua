local SFX = {}
local sources = {}

local function make(name, freq, freq2, dur, decay, vol)
    local rate = 22050
    local samples = math.max(1, math.floor(rate * dur))
    local data = love.sound.newSoundData(samples, rate, 16, 1)
    local k = (freq2 - freq) / (2 * dur)
    for i = 0, samples - 1 do
        local t = i / rate
        local phase = 2 * math.pi * (freq * t + k * t * t)
        local env = math.exp(-t * decay)
        data:setSample(i, math.sin(phase) * env * vol)
    end
    sources[name] = love.audio.newSource(data, "static")
end

function SFX.load()
    make("place", 320, 480, 0.10, 24, 0.35)
    make("error", 180, 140, 0.16, 18, 0.35)
    make("demolish", 300, 150, 0.18, 16, 0.35)
    make("shoot", 900, 1300, 0.05, 40, 0.16)
    make("boom", 140, 60, 0.30, 14, 0.5)
    make("chime", 520, 780, 0.35, 9, 0.35)
    make("starve", 240, 160, 0.30, 10, 0.4)
    make("over", 200, 90, 0.7, 5, 0.5)
end

function SFX.play(name, pitch, vol)
    local src = sources[name]
    if not src then return end
    local s = src:clone()
    if pitch then s:setPitch(pitch) end
    if vol then s:setVolume(vol) end
    s:play()
end

return SFX

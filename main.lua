local C = require("constants")
local Grid = require("grid")
local Workers = require("workers")
local Enemies = require("enemies")
local FX = require("fx")
local SFX = require("sfx")
local Economy = require("economy")
local UI = require("ui")

local state
local starvation, selected, wavesCleared
local overReason
local fonts
local gameTime

local function newGame()
    Grid.reset()
    Economy.reset()
    local garden = Grid.place("garden", 13, 6, true)
    garden.stock.crop = 3
    Grid.place("kitchen", 13, 8, true)
    local extractor = Grid.place("extractor", 10, 9, true)
    extractor.stock.mineral = 3
    Grid.place("turret", 12, 9, true)
    Grid.place("quarters", 8, 6)
    Workers.reset()
    Enemies.reset()
    FX.reset()
    starvation = 0
    selected = "corridor"
    gameTime = 0
    wavesCleared = 0
    overReason = nil
    state = "playing"
end

local function tryBuild(gx, gy)
    local def = C.rooms[selected]
    if not def or not Grid.inBounds(gx, gy) then return end
    if not Grid.canPlace(selected, gx, gy) then
        SFX.play("error")
        return
    end
    Grid.place(selected, gx, gy)
    local cx, cy = Grid.center(gx + (def.w - 1) / 2, gy + (def.h - 1) / 2)
    FX.burst(cx, cy, C.colors.corridor, 10, 0.8)
    SFX.play("place")
end

local function demolishAt(gx, gy)
    local room = Grid.roomAt(gx, gy)
    if not room or room.type == "core" then return end
    -- Salvage and unused on-site materials return to the emergency stockpile.
    local salvage = room.built and math.floor(room.def.cost / 2) or room.materials
    Economy.add(Grid.coreRoom, "mineral", salvage + (room.stock.mineral or 0))
    Economy.add(Grid.coreRoom, "food", room.stock.food or 0)
    Economy.add(Grid.coreRoom, "crop", room.stock.crop or 0)
    local rx, ry = Grid.center(room.x + (room.def.w - 1) / 2, room.y + (room.def.h - 1) / 2)
    FX.burst(rx, ry, C.colors.corridor, 12, 0.9)
    SFX.play("demolish")
    Grid.remove(room)
end


function love.load()
    love.graphics.setBackgroundColor(C.colors.bg)
    love.math.setRandomSeed(os.time())
    fonts = {
        big = love.graphics.newFont(42),
        ui = love.graphics.newFont(18),
        small = love.graphics.newFont(13),
        tiny = love.graphics.newFont(10),
    }
    SFX.load()
    newGame()
end

function love.update(dt)
    dt = math.min(dt, 0.05)
    if state == "paused" then return end

    if state == "playing" then
        gameTime = gameTime + dt
    end

    FX.update(dt)
    for _, room in ipairs(Grid.rooms) do
        if room.hit > 0 then room.hit = math.max(0, room.hit - dt) end
    end
    if state ~= "playing" then return end

    Economy.update(dt)
    Workers.setAlert(#Enemies.list > 0 or Enemies.timer <= C.warnSeconds)
    Workers.update(dt)
    Enemies.update(dt)

    local pantry = Grid.coreRoom.stock
    pantry.food = math.max(0, (pantry.food or 0) - C.foodEatRate * Workers.count() * dt)
    local food = pantry.food
    if food <= 0 then
        starvation = starvation + dt
        if starvation >= C.starveSeconds then
            starvation = 0
            Workers.killOne()
        end
    else
        starvation = math.max(0, starvation - dt * 2)
    end

    local cleared = Enemies.takeCleared()
    if cleared then
        wavesCleared = wavesCleared + 1
        SFX.play("chime")
    end

    if Grid.coreRoom.dead or #Grid.cellList == 0 then
        state = "gameover"
        overReason = "Your station was destroyed"
        SFX.play("over")
    elseif Workers.count() == 0 then
        state = "gameover"
        overReason = Workers.lossReason or "Your crew was lost"
        SFX.play("over")
    end
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "r" then
        newGame()
    elseif key == "p" and state ~= "gameover" then
        state = state == "paused" and "playing" or "paused"
    elseif state == "playing" then
        local n = tonumber(key)
        if n and C.buildOrder[n] then
            selected = C.buildOrder[n]
        elseif key == "tab" then
            for i, priority in ipairs(C.priorities) do
                if Workers.priority == priority then
                    Workers.setPriority(C.priorities[i % #C.priorities + 1])
                    break
                end
            end
        elseif key == "m" then
            Economy.add(Grid.coreRoom, "mineral", 10)
        elseif key == "f" then
            Economy.add(Grid.coreRoom, "food", 10)
        elseif key == "n" then
            Enemies.timer = 0.01
        end
    end
end

function love.mousepressed(x, y, button)
    if state ~= "playing" then return end
    if button == 1 then
        if y >= C.BAR_Y then
            local choice = UI.click(x, y)
            if choice then selected = choice end
            return
        end
        local gx, gy = Grid.atPixel(x, y)
        if Grid.inBounds(gx, gy) then
            tryBuild(gx, gy)
        end
    elseif button == 2 then
        local gx, gy = Grid.atPixel(x, y)
        demolishAt(gx, gy)
    end
end

local function drawPlanets()
    love.graphics.setColor(C.colors.planet)
    love.graphics.circle("fill", 70, C.H - 40, 130)
    love.graphics.circle("fill", C.W - 60, 110, 80)
end

local function drawGridLayer()
    love.graphics.setColor(C.colors.gridLine)
    love.graphics.setLineWidth(1)
    for i = 0, C.COLS do
        local x = C.OX + i * C.CELL
        love.graphics.line(x, C.OY, x, C.OY + C.GRID_H)
    end
    for j = 0, C.ROWS do
        local y = C.OY + j * C.CELL
        love.graphics.line(C.OX, y, C.OX + C.GRID_W, y)
    end
end

local function drawGhost()
    if state ~= "playing" then return end
    local mx, my = love.mouse.getPosition()
    if my >= C.BAR_Y then return end
    local gx, gy = Grid.atPixel(mx, my)
    if not Grid.inBounds(gx, gy) or Grid.get(gx, gy) then return end
    local def = C.rooms[selected]
    if not def then return end

    local ok = Grid.canPlace(selected, gx, gy)
    local x = C.OX + gx * C.CELL + 3
    local y = C.OY + gy * C.CELL + 3
    local w = def.w * C.CELL - 6
    local h = def.h * C.CELL - 6

    love.graphics.setColor(ok and C.colors.ghostOk or C.colors.ghostBad)
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)
    love.graphics.setColor(ok and { 0.25, 0.60, 0.35 } or { 0.70, 0.25, 0.25 })
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h, 6, 6)
end

local function drawPause()
    love.graphics.setColor(0.82, 0.855, 0.90, 0.75)
    love.graphics.rectangle("fill", 0, 0, C.W, C.H)
    love.graphics.setFont(fonts.big)
    love.graphics.setColor(C.colors.text)
    love.graphics.printf("PAUSED", 0, C.H / 2 - 70, C.W, "center")
    love.graphics.setFont(fonts.ui)
    love.graphics.setColor(C.colors.textSoft)
    love.graphics.printf("Press P to resume", 0, C.H / 2, C.W, "center")
end

local function drawGameOver()
    love.graphics.setColor(0.82, 0.855, 0.90, 0.85)
    love.graphics.rectangle("fill", 0, 0, C.W, C.H)
    love.graphics.setFont(fonts.big)
    love.graphics.setColor(0.83, 0.30, 0.33)
    love.graphics.printf(overReason or "GAME OVER", 0, C.H / 2 - 110, C.W, "center")
    love.graphics.setFont(fonts.ui)
    love.graphics.setColor(C.colors.text)
    love.graphics.printf("Waves cleared: " .. wavesCleared, 0, C.H / 2 - 20, C.W, "center")
    love.graphics.printf("Enemies destroyed: " .. Enemies.kills, 0, C.H / 2 + 10, C.W, "center")
    love.graphics.setColor(C.colors.textSoft)
    love.graphics.printf("Press R to play again", 0, C.H / 2 + 70, C.W, "center")
end

function love.draw()
    love.graphics.clear(C.colors.bg)
    drawPlanets()
    drawGridLayer()
    UI.drawRooms(fonts, gameTime)
    FX.draw()
    Workers.draw()
    Enemies.draw()
    drawGhost()
    UI.drawHud(fonts, starvation, gameTime)
    UI.drawBar(fonts, selected)
    UI.drawTooltip(fonts)
    if state == "paused" then
        drawPause()
    elseif state == "gameover" then
        drawGameOver()
    end
end

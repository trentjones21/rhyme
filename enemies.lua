local C = require("constants")
local Grid = require("grid")
local FX = require("fx")
local SFX = require("sfx")
local Workers = require("workers")

local Enemies = {
    list = {},
    shots = {},
    wave = 0,
    timer = C.waveFirst,
    hadEnemies = false,
    cleared = nil,
    kills = 0,
}

function Enemies.reset()
    Enemies.list = {}
    Enemies.shots = {}
    Enemies.wave = 0
    Enemies.timer = C.waveFirst
    Enemies.hadEnemies = false
    Enemies.cleared = nil
    Enemies.kills = 0
end

function Enemies.takeCleared()
    local w = Enemies.cleared
    Enemies.cleared = nil
    return w
end

local function spawnWave(n)
    local count = 1 + n
    for _ = 1, count do
        local side = love.math.random(4)
        local x, y
        if side == 1 then
            x = C.OX + love.math.random() * C.GRID_W
            y = C.OY - 30
        elseif side == 2 then
            x = C.OX + love.math.random() * C.GRID_W
            y = C.OY + C.GRID_H + 30
        elseif side == 3 then
            x = C.OX - 30
            y = C.OY + love.math.random() * C.GRID_H
        else
            x = C.OX + C.GRID_W + 30
            y = C.OY + love.math.random() * C.GRID_H
        end

        local hp = 24 + n * 16
        Enemies.list[#Enemies.list + 1] = {
            x = x,
            y = y,
            hp = hp,
            maxhp = hp,
            speed = math.min(46, 20 + n * 1.6) + love.math.random() * 6,
            dps = 4.5 + n * 0.8,
            r = 9,
            dir = 0,
            target = nil,
            state = "walking",
            hitTimer = 0,
            wobble = love.math.random() * math.pi * 2,
        }
    end
    SFX.play("chime", 0.6, 0.5)
end

local function damageEnemy(e, amount)
    e.hp = e.hp - amount
end

function Enemies.update(dt)
    Enemies.timer = Enemies.timer - dt
    if Enemies.timer <= 0 then
        Enemies.wave = Enemies.wave + 1
        spawnWave(Enemies.wave)
        Enemies.timer = C.waveInterval
    end

    for i = #Enemies.list, 1, -1 do
        local e = Enemies.list[i]
        e.wobble = e.wobble + dt * 3

        if not e.target or e.target.room.dead or not Grid.get(e.target.x, e.target.y) then
            e.target = Grid.nearestCell(e.x, e.y)
            e.state = "walking"
        end

        if e.target then
            local tx, ty = Grid.center(e.target.x, e.target.y)
            local dx, dy = tx - e.x, ty - e.y
            local dist = math.sqrt(dx * dx + dy * dy)

            if e.state == "walking" then
                if dist < 3 then
                    e.state = "attacking"
                else
                    local step = e.speed * dt
                    e.x = e.x + dx / dist * step
                    e.y = e.y + dy / dist * step
                    e.dir = math.atan2(dy, dx)
                end
            end

            if e.state == "attacking" then
                local room = e.target.room
                if room.dead then
                    e.target = nil
                else
                    room.hp = room.hp - e.dps * dt
                    room.hit = 0.15
                    e.hitTimer = e.hitTimer - dt
                    if e.hitTimer <= 0 then
                        e.hitTimer = 0.8
                        local hx, hy = Grid.center(e.target.x, e.target.y)
                        FX.burst(hx + love.math.random(-8, 8), hy + love.math.random(-8, 8), C.colors.enemy, 3, 0.7)
                    end
                    if room.hp <= 0 then
                        local rx, ry = Grid.center(room.x + (room.def.w - 1) / 2, room.y + (room.def.h - 1) / 2)
                        local col = room.type == "core" and C.colors.core or C.colors.corridor
                        FX.burst(rx, ry, col, 22, 1.6)
                        SFX.play("demolish")
                        Grid.remove(room)
                        e.target = nil
                    end
                end
            end
        end

        if e.hp <= 0 then
            FX.burst(e.x, e.y, C.colors.enemy, 12, 1.3)
            SFX.play("boom", 1.2, 0.7)
            Enemies.kills = Enemies.kills + 1
            table.remove(Enemies.list, i)
        end
    end

    for _, room in ipairs(Grid.rooms) do
        if room.type == "turret" and room.built and not room.dead and Workers.inRoom(room) > 0 then
            room.cooldown = room.cooldown - dt
            if room.cooldown <= 0 then
                local cx, cy = Grid.center(room.x, room.y)
                local best, bestD
                for _, e in ipairs(Enemies.list) do
                    local dx, dy = e.x - cx, e.y - cy
                    local d2 = dx * dx + dy * dy
                    if d2 < C.turretRange * C.turretRange and (not bestD or d2 < bestD) then
                        best, bestD = e, d2
                    end
                end
                if best then
                    room.cooldown = C.turretCooldown
                    room.aim = math.atan2(best.y - cy, best.x - cx)
                    Enemies.shots[#Enemies.shots + 1] = {
                        x = cx,
                        y = cy,
                        target = best,
                        speed = 320,
                    }
                    SFX.play("shoot", 0.9 + love.math.random() * 0.3, 0.5)
                end
            end
        end
    end

    for i = #Enemies.shots, 1, -1 do
        local s = Enemies.shots[i]
        local e = s.target
        if not e or e.hp <= 0 then
            table.remove(Enemies.shots, i)
        else
            local dx, dy = e.x - s.x, e.y - s.y
            local dist = math.sqrt(dx * dx + dy * dy)
            local step = s.speed * dt
            if dist <= step + e.r then
                damageEnemy(e, C.turretDamage)
                FX.burst(e.x, e.y, C.colors.shot, 4, 0.8)
                table.remove(Enemies.shots, i)
            else
                s.x = s.x + dx / dist * step
                s.y = s.y + dy / dist * step
            end
        end
    end

    if #Enemies.list > 0 then
        Enemies.hadEnemies = true
    elseif Enemies.hadEnemies then
        Enemies.hadEnemies = false
        Enemies.cleared = Enemies.wave
    end
end

function Enemies.draw()
    for _, e in ipairs(Enemies.list) do
        local r = e.r + math.sin(e.wobble) * 0.8
        love.graphics.push()
        love.graphics.translate(e.x, e.y)
        love.graphics.rotate(e.dir + math.pi / 2)
        love.graphics.setColor(C.colors.enemy)
        love.graphics.polygon("fill", 0, -r, r, r * 0.8, 0, r * 0.35, -r, r * 0.8)
        love.graphics.setColor(1, 1, 1, 0.55)
        love.graphics.circle("fill", 0, -2, 2.2)
        love.graphics.pop()

        if e.hp < e.maxhp then
            local w = 18
            love.graphics.setColor(1, 1, 1, 0.6)
            love.graphics.rectangle("fill", e.x - w / 2, e.y - e.r - 8, w, 3, 1, 1)
            love.graphics.setColor(C.colors.enemy)
            love.graphics.rectangle("fill", e.x - w / 2, e.y - e.r - 8, w * e.hp / e.maxhp, 3, 1, 1)
        end
    end

    love.graphics.setColor(C.colors.shot)
    for _, s in ipairs(Enemies.shots) do
        love.graphics.circle("fill", s.x, s.y, 3)
    end
end

return Enemies

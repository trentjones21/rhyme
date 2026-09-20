local C = require("constants")
local Grid = require("grid")
local Economy = require("economy")
local FX = require("fx")
local SFX = require("sfx")

local Workers = { list = {}, priority = "balanced", alert = false }

local function change(t, key, amount)
    t[key] = math.max(0, (t[key] or 0) + amount)
end

local function release(w)
    local j = w.job
    if j then
        if j.kind == "haul" then
            if j.source and not j.picked then change(j.source.outgoing, j.resource, -1) end
            change(j.target.incoming, j.resource, -1)
        else
            j.target.busy[j.kind] = nil
            if j.resource then change(j.target.outgoing, j.resource, -j.amount) end
            if j.kind == "cook" then change(j.target.incoming, "food", -C.mealsPerCrop) end
        end
    end
    w.job, w.path, w.homeRoom = nil, nil, nil
    w.state, w.label, w.retry = "idle", w.carry and "Returning cargo" or "Waiting for work", 0
end

function Workers.spawn(room)
    if #Workers.list >= C.maxWorkers then return false end
    room = room or Grid.coreRoom
    if not room or room.dead or not room.built then return false end
    local cell = Grid.randomCellInRoom(room)
    local x, y = Grid.center(cell.x, cell.y)
    Workers.list[#Workers.list + 1] = {
        x = x, y = y, speed = 65 + love.math.random() * 12,
        bob = love.math.random() * math.pi * 2, state = "idle",
        label = "Waiting for work", retry = 0,
    }
    return true
end

function Workers.reset()
    Workers.list, Workers.priority, Workers.alert = {}, "balanced", false
    Workers.lossReason = nil
    for _ = 1, C.startWorkers do Workers.spawn() end
end

function Workers.count() return #Workers.list end

function Workers.inRoom(room)
    local n = 0
    for _, w in ipairs(Workers.list) do
        if w.homeRoom == room and w.state == "working" and w.job and w.job.kind == "defend" then n = n + 1 end
    end
    return n
end

local function loseWorker(index, reason)
    local w = table.remove(Workers.list, index)
    release(w)
    if w.carry then
        local x, y = Grid.atPixel(w.x, w.y)
        local room = Grid.roomAt(x, y)
        if room and room.built then Economy.add(room, w.carry, 1) end
    end
    FX.burst(w.x, w.y, C.colors.worker, 14, 1.2)
    Workers.lossReason = reason
    SFX.play(reason == "Your crew starved" and "starve" or "boom")
end

function Workers.killOne()
    if #Workers.list == 0 then return end
    loseWorker(love.math.random(#Workers.list), "Your crew starved")
end

local function reconsider()
    for _, w in ipairs(Workers.list) do
        if not w.carry then release(w) end
    end
end

function Workers.setPriority(priority)
    if not C.priorityNames[priority] then return end
    if Workers.priority ~= priority then Workers.priority = priority; reconsider() end
end

function Workers.setAlert(alert)
    if Workers.alert == alert then return end
    Workers.alert = alert
    if alert then reconsider() end
end

local function defenseNeeded()
    return Workers.alert or Workers.priority == "defense"
end

local function weight(category, base)
    if Workers.priority == category then return base + 65 end
    return base
end

local function route(w, room)
    local x, y = Grid.atPixel(w.x, w.y)
    return Grid.routeToRoom(x, y, room)
end

local function endpoint(w, path)
    if #path > 0 then return path[#path].x, path[#path].y end
    return Grid.atPixel(w.x, w.y)
end

local function findJob(w)
    local best, score
    local function offer(j, path, priority, distance)
        if not path then return end
        local value = priority - (distance or #path) * 0.65
        if not score or value > score then best, score = j, value; j.path = path end
    end
    -- Cancelled deliveries retain their cargo until a reachable destination has space.
    if w.carry then
        for _, target in ipairs(Grid.rooms) do
            if Economy.need(target, w.carry) >= 1 then
                offer({ kind = "haul", target = target, resource = w.carry, picked = true }, route(w, target),
                    target.type == "core" and 90 or 70)
            end
        end
        return best
    end

    for _, target in ipairs(Grid.rooms) do
        local path = route(w, target)
        if path then
            if not target.built then
                if target.materials >= target.def.cost and not target.busy.build then
                    offer({ kind = "build", target = target }, path, weight("build", 85))
                end
            elseif target.type == "kitchen" and not target.busy.cook
                and Economy.available(target, "crop") >= 1
                and Economy.need(target, "food") >= C.mealsPerCrop then
                offer({ kind = "cook", target = target, resource = "crop", amount = 1 }, path, weight("food", 83))
            elseif target.type == "quarters" and not target.busy.recruit
                and target.recruited < C.recruitsPerQuarters and Workers.count() < C.maxWorkers
                and Economy.available(target, "food") >= C.mealsPerRecruit then
                offer({ kind = "recruit", target = target, resource = "food", amount = C.mealsPerRecruit }, path, 68)
            elseif target.type == "turret" and defenseNeeded() and not target.busy.defend then
                offer({ kind = "defend", target = target }, path, 1000)
            end

            local resource, priority
            if not target.built then resource, priority = "mineral", weight("build", 73)
            elseif target.type == "kitchen" then resource, priority = "crop", weight("food", 72)
            elseif target.type == "quarters" and Workers.count() < C.maxWorkers then resource, priority = "food", 58
            end
            local needs = {}
            if resource then needs[1] = { resource, priority } end
            if target.type == "core" then
                needs = { { "food", weight("food", (target.stock.food or 0) < 6 and 150 or 65) }, { "mineral", 30 } }
            end
            for _, need in ipairs(needs) do
                resource, priority = need[1], need[2]
                if Economy.need(target, resource) >= 1 then
                    for _, source in ipairs(Grid.rooms) do
                        -- Keep emergency meals in the pantry before expanding the population.
                        local pantryReserve = source.type == "core" and resource == "food" and 5 or 0
                        local allocated = (resource == "food" and source.type == "quarters")
                            or (resource == "crop" and source.type == "kitchen")
                        if source ~= target and not allocated and Economy.available(source, resource) >= 1 + pantryReserve then
                            local pickup = route(w, source)
                            if pickup then
                                local sx, sy = endpoint(w, pickup)
                                local delivery = Grid.routeToRoom(sx, sy, target)
                                if delivery then
                                    offer({ kind = "haul", source = source, target = target, resource = resource },
                                        pickup, priority, #pickup + #delivery)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

local labels = { build = "Building", cook = "Cooking", recruit = "Preparing quarters", defend = "Defending" }
local function start(w, j)
    w.job, w.path, w.state = j, j.path, "walking"
    if j.kind == "haul" then
        if j.source then change(j.source.outgoing, j.resource, 1) end
        change(j.target.incoming, j.resource, 1)
        j.phase = j.picked and "delivery" or "pickup"
        w.label = j.picked and ("Delivering " .. j.resource) or ("Collecting " .. j.resource)
    else
        j.target.busy[j.kind] = true
        if j.resource then change(j.target.outgoing, j.resource, j.amount) end
        if j.kind == "cook" then change(j.target.incoming, "food", C.mealsPerCrop) end
        w.label = labels[j.kind]
    end
end

local function stepAlong(w, dt)
    local node = w.path and w.path[1]
    if not node then return true end
    local tx, ty = Grid.center(node.x, node.y)
    local dx, dy = tx - w.x, ty - w.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local step = w.speed * dt
    if dist <= step then
        w.x, w.y = tx, ty
        table.remove(w.path, 1)
        return #w.path == 0
    end
    w.x, w.y = w.x + dx / dist * step, w.y + dy / dist * step
    return false
end

local function valid(w)
    local j = w.job
    if not j or j.target.dead then return false end
    if j.kind == "haul" and not j.picked and j.source.dead then return false end
    if j.kind == "defend" and not defenseNeeded() then return false end
    if j.kind == "build" and j.target.built then return false end
    for _, node in ipairs(w.path or {}) do
        if not Grid.walkable(node.x, node.y) then return false end
    end
    return true
end

local function work(w, dt)
    local j, room = w.job, w.job.target
    w.workTimer = (w.workTimer or 0) + dt
    if j.kind == "haul" then
        if w.workTimer < 0.2 then return end
        if j.phase == "pickup" then
            if (j.source.stock[j.resource] or 0) < 1 then release(w); return end
            change(j.source.stock, j.resource, -1)
            change(j.source.outgoing, j.resource, -1)
            j.picked, w.carry, j.phase = true, j.resource, "delivery"
            w.path = route(w, room)
            if not w.path then release(w); return end
            w.label, w.state = "Delivering " .. j.resource, "walking"
            w.workTimer = 0
        else
            Economy.add(room, j.resource, 1)
            w.carry = nil
            release(w)
        end
    elseif j.kind == "build" then
        room.progress = math.min(1, room.progress + dt / (C.buildSeconds * room.def.cost))
        if room.progress >= 1 then
            room.built = true
            local x, y = Grid.center(room.x, room.y)
            FX.burst(x, y, C.colors[room.type], 10, 0.7)
            SFX.play("place", 1.2, 0.35)
            release(w)
        end
    elseif j.kind == "cook" and w.workTimer >= C.cookSeconds then
        change(room.stock, "crop", -1)
        Economy.add(room, "food", C.mealsPerCrop)
        release(w)
    elseif j.kind == "recruit" and w.workTimer >= C.recruitSeconds then
        if Workers.spawn(room) then
            change(room.stock, "food", -C.mealsPerRecruit)
            room.recruited = room.recruited + 1
            SFX.play("chime", 1.3, 0.4)
        end
        release(w)
    end
end

function Workers.update(dt)
    for i = #Workers.list, 1, -1 do
        local w = Workers.list[i]
        local lost = false
        w.bob = w.bob + dt * 8
        local cx, cy = Grid.atPixel(w.x, w.y)
        if not Grid.walkable(cx, cy) then
            -- Only escape to adjacent surviving floor; never teleport across a broken bridge.
            local best, distance
            for _, cell in ipairs(Grid.cellList) do
                if cell.room.built then
                    local x, y = Grid.center(cell.x, cell.y)
                    local d = math.abs(x - w.x) + math.abs(y - w.y)
                    if d <= C.CELL * 1.1 and (not distance or d < distance) then best, distance = cell, d end
                end
            end
            release(w)
            if best then
                w.x, w.y = Grid.center(best.x, best.y)
            else
                loseWorker(i, "Your crew was lost with the station")
                lost = true
            end
        end
        if not lost then
            if w.job and not valid(w) then release(w) end
            if not w.job then
                w.retry = (w.retry or 0) - dt
                if w.retry <= 0 then
                    local job = findJob(w)
                    if job then start(w, job) else w.retry = 0.4 end
                end
            elseif w.state == "walking" then
                if stepAlong(w, dt) then
                    w.state, w.workTimer = "working", 0
                    if w.job.kind == "defend" then w.homeRoom = w.job.target end
                end
            else
                work(w, dt)
            end
        end
    end
end

function Workers.activity()
    local counts = { hauling = 0, working = 0, defending = 0, idle = 0 }
    for _, w in ipairs(Workers.list) do
        local kind = w.job and w.job.kind
        local key = kind == "haul" and "hauling" or kind == "defend" and "defending" or kind and "working" or "idle"
        counts[key] = counts[key] + 1
    end
    return counts
end

function Workers.draw()
    for _, w in ipairs(Workers.list) do
        local bobY = w.state ~= "idle" and math.sin(w.bob) * 1.2 or 0
        love.graphics.setColor(0, 0, 0, 0.10)
        love.graphics.ellipse("fill", w.x, w.y + 9, 7, 3)
        love.graphics.setColor(C.colors.worker)
        love.graphics.rectangle("fill", w.x - 5, w.y - 9 + bobY, 10, 17, 4, 4)
        love.graphics.setColor(1, 1, 1, 0.85)
        love.graphics.rectangle("fill", w.x - 3, w.y - 5 + bobY, 6, 3, 1, 1)
        if w.carry then
            love.graphics.setColor(0.18, 0.21, 0.29)
            love.graphics.rectangle("fill", w.x - 6, w.y - 20 + bobY, 12, 11, 2)
            love.graphics.setColor(C.colors[w.carry])
            love.graphics.rectangle("fill", w.x - 4, w.y - 18 + bobY, 8, 7, 1)
        elseif w.state == "working" and w.job and w.job.kind ~= "defend" then
            love.graphics.setColor(1, 1, 1, 0.85)
            love.graphics.circle("line", w.x, w.y + 2, 11 + math.sin(w.bob) * 2)
        end
    end
end

return Workers

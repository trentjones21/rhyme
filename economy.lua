local C = require("constants")
local Grid = require("grid")

local Economy = {}

function Economy.reset()
    Grid.coreRoom.stock = { mineral = C.startMinerals, food = C.startFood }
end

function Economy.available(room, resource)
    if room.dead or not room.built then return 0 end
    return math.max(0, (room.stock[resource] or 0) - (room.outgoing[resource] or 0))
end

function Economy.capacity(room, resource)
    if room.type == "core" then
        if resource == "food" then return C.pantryCapacity end
        if resource == "mineral" then return 30 end
        if resource == "crop" then return C.stockCapacity end
    elseif room.type == "kitchen" then
        if resource == "crop" then return 4 end
        if resource == "food" then return C.stockCapacity + C.mealsPerCrop end
    elseif room.type == "garden" and resource == "crop" then
        return C.stockCapacity
    elseif room.type == "extractor" and resource == "mineral" then
        return C.stockCapacity
    elseif room.type == "quarters" and resource == "food" and room.recruited < C.recruitsPerQuarters then
        return C.mealsPerRecruit
    end
    return 0
end

function Economy.need(room, resource)
    if room.dead then return 0 end
    local incoming = room.incoming[resource] or 0
    if not room.built then
        return resource == "mineral" and math.max(0, room.def.cost - room.materials - incoming) or 0
    end
    return math.max(0, Economy.capacity(room, resource) - (room.stock[resource] or 0) - incoming)
end

function Economy.add(room, resource, amount)
    if room.dead then return end
    if not room.built and resource == "mineral" then
        room.materials = room.materials + amount
    else
        room.stock[resource] = (room.stock[resource] or 0) + amount
    end
end

function Economy.total(resource)
    local total = 0
    for _, room in ipairs(Grid.rooms) do total = total + (room.stock[resource] or 0) end
    return total
end

function Economy.update(dt)
    for _, room in ipairs(Grid.rooms) do
        if room.built then
            local resource = room.type == "garden" and "crop" or room.type == "extractor" and "mineral"
            if resource then
                local duration = resource == "crop" and C.cropSeconds or C.mineralSeconds
                room.production = math.min(duration, (room.production or 0) + dt)
                if room.production >= duration and Economy.need(room, resource) >= 1 then
                    Economy.add(room, resource, 1)
                    room.production = room.production - duration
                end
            end
        end
    end
end

return Economy

local C = require("constants")

local Grid = {}

Grid.cells = {}
Grid.rooms = {}
Grid.cellList = {}
Grid.coreRoom = nil

local function key(x, y)
    return x .. "," .. y
end

function Grid.inBounds(x, y)
    return x >= 0 and y >= 0 and x < C.COLS and y < C.ROWS
end

function Grid.get(x, y)
    if not Grid.inBounds(x, y) then return nil end
    return Grid.cells[key(x, y)]
end

function Grid.atPixel(px, py)
    return math.floor((px - C.OX) / C.CELL), math.floor((py - C.OY) / C.CELL)
end

function Grid.center(x, y)
    return C.OX + (x + 0.5) * C.CELL, C.OY + (y + 0.5) * C.CELL
end

function Grid.roomAt(x, y)
    local cell = Grid.get(x, y)
    return cell and cell.room or nil
end

function Grid.rebuildCellList()
    Grid.cellList = {}
    for _, room in ipairs(Grid.rooms) do
        for _, cell in ipairs(room.cells) do
            Grid.cellList[#Grid.cellList + 1] = cell
        end
    end
end

function Grid.reset()
    Grid.cells = {}
    Grid.rooms = {}

    local cx = math.floor(C.COLS / 2)
    local cy = math.floor(C.ROWS / 2)
    local room = {
        type = "core",
        def = { name = "Core", w = 3, h = 3, cost = 0, hp = C.core.hp },
        x = cx - 1,
        y = cy - 1,
        cells = {},
        hp = C.core.hp,
        maxhp = C.core.hp,
        dead = false,
        hit = 0,
        built = true,
        stock = {}, incoming = {}, outgoing = {}, busy = {},
    }
    local shape = { { 0, 0 }, { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }
    for _, off in ipairs(shape) do
        local cell = { x = cx + off[1], y = cy + off[2], room = room }
        Grid.cells[key(cell.x, cell.y)] = cell
        room.cells[#room.cells + 1] = cell
    end
    Grid.rooms[1] = room
    Grid.coreRoom = room
    Grid.rebuildCellList()
end

local function footprintOk(def, x, y)
    for dx = 0, def.w - 1 do
        for dy = 0, def.h - 1 do
            local px, py = x + dx, y + dy
            if not Grid.inBounds(px, py) or Grid.get(px, py) then
                return false
            end
        end
    end
    return true
end

local function touchesStation(x, y, w, h)
    for dx = 0, w - 1 do
        if Grid.get(x + dx, y - 1) or Grid.get(x + dx, y + h) then
            return true
        end
    end
    for dy = 0, h - 1 do
        if Grid.get(x - 1, y + dy) or Grid.get(x + w, y + dy) then
            return true
        end
    end
    return false
end

function Grid.canPlace(type, x, y)
    local def = C.rooms[type]
    if not def then return false end
    if not footprintOk(def, x, y) then return false end
    return touchesStation(x, y, def.w, def.h)
end

function Grid.place(type, x, y, instant)
    if not Grid.canPlace(type, x, y) then return nil end
    local def = C.rooms[type]
    local room = {
        type = type,
        def = def,
        x = x,
        y = y,
        cells = {},
        hp = def.hp,
        maxhp = def.hp,
        dead = false,
        hit = 0,
        cooldown = 0,
        aim = -math.pi / 2,
        built = instant == true,
        materials = 0,
        progress = 0,
        production = 0,
        recruited = 0,
        stock = {}, incoming = {}, outgoing = {}, busy = {},
    }
    for dx = 0, def.w - 1 do
        for dy = 0, def.h - 1 do
            local cell = { x = x + dx, y = y + dy, room = room }
            Grid.cells[key(x + dx, y + dy)] = cell
            room.cells[#room.cells + 1] = cell
        end
    end
    Grid.rooms[#Grid.rooms + 1] = room
    Grid.rebuildCellList()
    return room
end

function Grid.remove(room)
    if room.dead then return end
    room.dead = true
    for _, cell in ipairs(room.cells) do
        Grid.cells[key(cell.x, cell.y)] = nil
    end
    for i, r in ipairs(Grid.rooms) do
        if r == room then
            table.remove(Grid.rooms, i)
            break
        end
    end
    Grid.rebuildCellList()
end

function Grid.walkable(x, y)
    local cell = Grid.get(x, y)
    return cell and cell.room.built and not cell.room.dead
end

function Grid.path(sx, sy, tx, ty)
    if not Grid.walkable(sx, sy) or not Grid.walkable(tx, ty) then return nil end
    if sx == tx and sy == ty then return {} end

    local queue = { { sx, sy } }
    local head = 1
    local prev = {}
    prev[key(sx, sy)] = false
    local dirs = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

    while head <= #queue do
        local cur = queue[head]
        head = head + 1
        for _, d in ipairs(dirs) do
            local nx, ny = cur[1] + d[1], cur[2] + d[2]
            local k = key(nx, ny)
            if Grid.walkable(nx, ny) and prev[k] == nil then
                prev[k] = cur
                if nx == tx and ny == ty then
                    local path = {}
                    local cx, cy = tx, ty
                    while prev[key(cx, cy)] do
                        table.insert(path, 1, { x = cx, y = cy })
                        local p = prev[key(cx, cy)]
                        cx, cy = p[1], p[2]
                    end
                    return path
                end
                queue[#queue + 1] = { nx, ny }
            end
        end
    end
    return nil
end

function Grid.routeToRoom(sx, sy, room)
    if not room or room.dead then return nil end
    local best
    local function consider(x, y)
        local path = Grid.path(sx, sy, x, y)
        if path and (not best or #path < #best) then best = path end
    end
    for _, cell in ipairs(room.cells) do
        if room.built then
            consider(cell.x, cell.y)
        else
            consider(cell.x - 1, cell.y)
            consider(cell.x + 1, cell.y)
            consider(cell.x, cell.y - 1)
            consider(cell.x, cell.y + 1)
        end
    end
    return best
end

function Grid.nearestCell(px, py)
    local best, bestD
    for _, cell in ipairs(Grid.cellList) do
        local cx, cy = Grid.center(cell.x, cell.y)
        local dx, dy = cx - px, cy - py
        local d = dx * dx + dy * dy
        if not bestD or d < bestD then
            best, bestD = cell, d
        end
    end
    return best
end

function Grid.randomCellInRoom(room)
    return room.cells[love.math.random(#room.cells)]
end

return Grid

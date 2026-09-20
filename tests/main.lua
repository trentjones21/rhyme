local root = love.filesystem.getSourceBaseDirectory()
package.path = root .. "/?.lua;" .. package.path
local C = require("constants")
local Grid = require("grid")
local passed, failed = 0, 0
local Workers = require("workers")
local Economy

local function setup(count)
    local ok, module = pcall(require, "economy")
    assert(ok, "room-local economy is missing")
    Economy = module
    Grid.reset()
    Economy.reset()
    Workers.reset()
    Workers.list = {}
    for _ = 1, count or 1 do Workers.spawn() end
end

local function run(seconds, production)
    for _ = 1, math.ceil(seconds / 0.05) do
        if production then Economy.update(0.05) end
        Workers.update(0.05)
    end
end

local function test(name, fn)
    love.math.setRandomSeed(17)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("PASS " .. name)
    else
        failed = failed + 1
        print("FAIL " .. name .. ": " .. tostring(err))
    end
end

function love.load()
    test("adjacent paths include the destination tile", function()
        Grid.reset()
        local x, y = math.floor(C.COLS / 2), math.floor(C.ROWS / 2)
        local path = Grid.path(x, y, x + 1, y)
        assert(#path == 1, "adjacent route must have exactly one step")
        assert(path[1].x == x + 1 and path[1].y == y)
    end)
    test("corner paths never skip the connecting tile", function()
        Grid.reset()
        local x, y = math.floor(C.COLS / 2), math.floor(C.ROWS / 2)
        local path = Grid.path(x - 1, y, x, y - 1)
        assert(#path == 2, "corner route must include both orthogonal steps")
        assert(path[1].x == x and path[1].y == y)
    end)
    test("blueprints cannot be used as walking shortcuts", function()
        Grid.reset()
        Grid.place("corridor", 13, 7)
        assert(Grid.path(12, 7, 13, 7) == nil, "unfinished floor must block walking")
    end)
    test("workers can reach a blueprint's completed edge", function()
        Grid.reset()
        local site = Grid.place("garden", 13, 6)
        assert(type(Grid.routeToRoom) == "function", "construction edge routing is missing")
        local route = Grid.routeToRoom(11, 7, site)
        assert(route and #route == 1 and route[1].x == 12 and route[1].y == 7)
    end)
    test("cargo is collected before meals are credited to the pantry", function()
        setup()
        local kitchen = Grid.place("kitchen", 13, 6, true)
        kitchen.stock.food = 1
        Grid.coreRoom.stock.food = 0
        local carried = false
        for _ = 1, 400 do
            Workers.update(0.05)
            if Workers.list[1].carry == "food" then
                carried = true
                assert(kitchen.stock.food == 0 and Grid.coreRoom.stock.food == 0,
                    "food must be in transit, not already credited")
            end
        end
        assert(carried, "worker must visibly carry the meal")
        assert(Grid.coreRoom.stock.food == 1, "meal must arrive at pantry")
    end)
    test("construction requires mineral deliveries and building work", function()
        setup(3)
        local room = Grid.place("garden", 13, 6)
        assert(not room.built)
        run(0.1)
        assert(not room.built and room.materials == 0)
        run(35)
        assert(room.built, "supplied room should finish construction")
        assert(Grid.coreRoom.stock.mineral == C.startMinerals - C.rooms.garden.cost)
    end)
    test("a blueprint waits when there are no construction materials", function()
        setup(3)
        Grid.coreRoom.stock.mineral = 0
        local room = Grid.place("garden", 13, 6)
        run(20)
        assert(not room.built and room.materials == 0)
    end)
    test("garden crops become cooked meals delivered to storage", function()
        setup(3)
        local garden = Grid.place("garden", 13, 6, true)
        local kitchen = Grid.place("kitchen", 13, 8, true)
        garden.stock.crop = 2
        Grid.coreRoom.stock.food = 0
        run(45)
        assert(garden.stock.crop == 0, "crops should be collected")
        assert(Grid.coreRoom.stock.food > 0, "cooked food should reach pantry")
        assert((kitchen.stock.crop or 0) == 0)
    end)
    test("workers cannot duplicate the last available resource", function()
        setup(8)
        local kitchen = Grid.place("kitchen", 13, 6, true)
        kitchen.stock.food = 1
        Grid.coreRoom.stock.food = 0
        run(25)
        assert(Grid.coreRoom.stock.food == 1 and kitchen.stock.food == 0)
        assert((kitchen.outgoing.food or 0) == 0)
        assert((Grid.coreRoom.incoming.food or 0) == 0)
    end)
    test("a destroyed destination releases claims and returns carried minerals", function()
        setup()
        local room = Grid.place("garden", 13, 6)
        local carried = false
        for _ = 1, 300 do
            Workers.update(0.05)
            if Workers.list[1].carry == "mineral" then carried = true; break end
        end
        assert(carried)
        Grid.remove(room)
        run(15)
        assert(Workers.list[1].carry == nil)
        assert(Grid.coreRoom.stock.mineral == C.startMinerals, "cancelled cargo must return")
        assert((room.incoming.mineral or 0) == 0)
    end)
    test("quarters recruit only after meals are hauled in and prepared", function()
        setup(2)
        local room = Grid.place("quarters", 13, 6, true)
        assert(Workers.count() == 2)
        run(60)
        assert(Workers.count() == 4, "quarters should recruit their two crew; crew=" .. Workers.count()
            .. " pantry=" .. Grid.coreRoom.stock.food .. " quarters=" .. (room.stock.food or 0))
        assert(room.recruited == 2)
        run(30)
        assert(Workers.count() == 4, "quarters capacity must be respected")
    end)
    test("unreachable jobs do not reserve resources forever", function()
        setup(2)
        local bridge = Grid.place("corridor", 13, 7, true)
        local room = Grid.place("garden", 14, 7)
        Grid.remove(bridge)
        run(15)
        assert(not room.built and room.materials == 0)
        assert((Grid.coreRoom.outgoing.mineral or 0) == 0)
    end)
    test("defenders man weapons on alert and resume work afterward", function()
        setup(2)
        local turret = Grid.place("turret", 13, 7, true)
        Workers.setAlert(true)
        run(8)
        assert(Workers.inRoom(turret) == 1, "weapon station needs a defender")
        Workers.setAlert(false)
        run(1)
        assert(Workers.inRoom(turret) == 0)
    end)
    test("supplied kitchens do not shuttle crops between each other", function()
        setup()
        local a = Grid.place("kitchen", 13, 6, true)
        local b = Grid.place("kitchen", 13, 8, true)
        a.stock.food, b.stock.food = 11, 11
        a.stock.crop = 1
        Grid.coreRoom.stock.food = 20
        run(20)
        assert(a.stock.crop == 1 and (b.stock.crop or 0) == 0, "allocated crops should stay put")
        assert(not Workers.list[1].job, "full kitchens must not create pointless hauling")
    end)
    test("cooking reserves output space against returning cargo", function()
        setup()
        local kitchen = Grid.place("kitchen", 13, 6, true)
        kitchen.stock.food, kitchen.stock.crop = 8, 1
        Grid.coreRoom.stock.food = 20
        for _, w in ipairs(Workers.list) do w.x, w.y = Grid.center(13, 6) end
        Workers.update(0.05)
        Workers.spawn(kitchen)
        Workers.list[2].carry = "food"
        run(4)
        assert(kitchen.stock.food <= 11, "cooking and cargo must share capacity")
        local total = kitchen.stock.food
        for _, w in ipairs(Workers.list) do if w.carry == "food" then total = total + 1 end end
        assert(total == 12, "overflow must remain safely carried")
    end)
    test("destroyed floors cannot leave permanent ghost crew", function()
        setup()
        local garden = Grid.place("garden", 13, 6, true)
        local worker = Workers.list[1]
        worker.x, worker.y = Grid.center(14, 6)
        Grid.remove(garden)
        run(1)
        assert(Workers.count() == 0, "crew with no surviving adjacent floor must be lost")
    end)
    test("room production stops at local storage capacity", function()
        setup(0)
        local garden = Grid.place("garden", 13, 6, true)
        local kitchen = Grid.place("kitchen", 13, 8, true)
        local mine = Grid.place("extractor", 10, 9, true)
        kitchen.stock.crop = 2
        run(120, true)
        assert(garden.stock.crop == 8 and mine.stock.mineral == 8)
        assert((kitchen.stock.food or 0) == 0, "a kitchen cannot cook without crew")
    end)
    test("queued corridors unlock construction beyond unfinished floor", function()
        setup(3)
        local first = Grid.place("corridor", 13, 7)
        local second = Grid.place("corridor", 14, 7)
        local garden = Grid.place("garden", 15, 6)
        run(1)
        assert(second.materials == 0 and garden.materials == 0)
        run(60)
        assert(first.built and second.built and garden.built, "workers must build a connected route in order")
    end)
    test("a broken bridge cancels cargo delivery without crossing empty space", function()
        setup()
        local bridge = Grid.place("corridor", 13, 7, true)
        local site = Grid.place("garden", 14, 7)
        local carrying = false
        for _ = 1, 300 do
            Workers.update(0.05)
            if Workers.list[1].carry then carrying = true; break end
        end
        assert(carrying)
        Grid.remove(bridge)
        run(15)
        assert(site.materials == 0 and not site.built)
        assert(Grid.coreRoom.stock.mineral == C.startMinerals)
        assert((site.incoming.mineral or 0) == 0)
    end)
    test("weapons require a worker before they can fire", function()
        setup()
        local Enemies = require("enemies")
        Enemies.reset()
        local turret = Grid.place("turret", 13, 7, true)
        local x, y = Grid.center(13, 7)
        Enemies.list[1] = { x = x + 30, y = y, hp = 100, maxhp = 100, speed = 0,
            dps = 0, r = 9, dir = 0, state = "walking", wobble = 0, hitTimer = 0 }
        Enemies.update(0.05)
        assert(#Enemies.shots == 0)
        Workers.setAlert(true)
        run(8)
        Enemies.update(0.05)
        assert(#Enemies.shots == 1, "a staffed weapon must fire at a nearby enemy")
    end)
    test("the opening station feeds and expands its crew without resource cheats", function()
        dofile(root .. "/main.lua")
        love.keypressed("r")
        for _ = 1, 1500 do love.update(0.05) end
        assert(Workers.count() == 7, "starter quarters should recruit two workers")
        assert(Grid.coreRoom.stock.food >= 5, "opening food chain must be sustainable")
        local pantry = Grid.coreRoom.stock.food
        love.keypressed("p")
        for _ = 1, 20 do love.update(0.05) end
        assert(Grid.coreRoom.stock.food == pantry, "pause must stop consumption and deliveries")
        love.keypressed("r")
        assert(Workers.count() == 5 and Grid.coreRoom.stock.food == 12, "restart must reset economy")
    end)
    test("repeated priorities and waves keep job reservations consistent", function()
        love.keypressed("r")
        for frame = 1, 5000 do
            if frame % 137 == 0 then love.keypressed("tab") end
            love.update(0.05)
            local incoming, outgoing = {}, {}
            for _, room in ipairs(Grid.rooms) do incoming[room], outgoing[room] = {}, {} end
            local function add(map, room, resource, amount)
                if map[room] then map[room][resource] = (map[room][resource] or 0) + amount end
            end
            for _, w in ipairs(Workers.list) do
                local j = w.job
                if j then
                    if j.kind == "haul" then
                        add(incoming, j.target, j.resource, 1)
                        if not j.picked then add(outgoing, j.source, j.resource, 1) end
                    elseif j.resource then
                        add(outgoing, j.target, j.resource, j.amount)
                        if j.kind == "cook" then add(incoming, j.target, "food", 3) end
                    end
                end
            end
            for _, room in ipairs(Grid.rooms) do
                for _, resource in ipairs({ "food", "crop", "mineral" }) do
                    assert((room.stock[resource] or 0) >= 0, "stock became negative")
                    assert((room.incoming[resource] or 0) == (incoming[room][resource] or 0), "leaked destination claim")
                    assert((room.outgoing[resource] or 0) == (outgoing[room][resource] or 0), "leaked pickup claim")
                end
            end
        end
    end)
    print(string.format("%d passed, %d failed", passed, failed))
    love.event.quit(failed == 0 and 0 or 1)
end

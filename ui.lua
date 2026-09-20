local C = require("constants")
local Grid = require("grid")
local Workers = require("workers")
local Economy = require("economy")
local Enemies = require("enemies")

local UI = {}
local buildWidth = 136
local priorityWidth = 138
local descriptions = {
    corridor = "Connects rooms. Workers must build the floor before anyone can cross it.",
    garden = "Grows green crops. Haulers collect them and carry them to a kitchen.",
    extractor = "Produces blue minerals. Haulers supply construction sites and storage.",
    kitchen = "Workers bring crops here and cook each crop into three yellow meals.",
    quarters = "Deliver three meals, then a worker prepares a berth for a new minion. Two berths per room.",
    turret = "One worker must man this weapon. Crew respond automatically when a wave approaches.",
    core = "Emergency stockpile and pantry. Meals only feed the crew once delivered here.",
}

local function color(c, alpha)
    love.graphics.setColor(c[1], c[2], c[3], alpha or c[4] or 1)
end

local function progress(x, y, w, amount, c)
    love.graphics.setColor(0.15, 0.18, 0.26, 0.15)
    love.graphics.rectangle("fill", x, y, w, 3, 1)
    color(c or C.colors.text)
    love.graphics.rectangle("fill", x, y, w * math.min(1, amount), 3, 1)
end

local function stacks(room, x, y, width)
    for _, resource in ipairs({ "mineral", "crop", "food" }) do
        local n = math.floor(room.stock[resource] or 0)
        if n > 0 then
            local columns = math.max(1, math.floor(width / 7))
            for i = 1, math.min(n, columns * 2) do
                local px, py = x + ((i - 1) % columns) * 7, y + math.floor((i - 1) / columns) * 7
                love.graphics.setColor(0.12, 0.16, 0.22, 0.6)
                love.graphics.rectangle("fill", px - 1, py - 1, 6, 6, 1)
                color(C.colors[resource])
                love.graphics.rectangle("fill", px, py, 4, 4)
            end
            y = y + 7 * math.min(2, math.ceil(n / columns))
        end
    end
end

function UI.drawRooms(fonts, time)
    for _, room in ipairs(Grid.rooms) do
        local def = room.def
        if room.type == "core" then
            for _, cell in ipairs(room.cells) do
                local x, y = Grid.center(cell.x, cell.y)
                color(C.colors.core)
                love.graphics.rectangle("fill", x - 16, y - 16, 32, 32, 5)
            end
            local cx, cy = Grid.center(11, 7)
            love.graphics.setFont(fonts.tiny)
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.printf("CORE", cx - 25, cy - 5, 50, "center")
            stacks({ stock = { mineral = room.stock.mineral } }, cx - 12, cy - 45, 28)
            stacks({ stock = { food = room.stock.food } }, cx - 48, cy - 9, 28)
            progress(cx - 13, cy + 43, 26, room.hp / room.maxhp, C.colors.food)
        else
            local x, y = C.OX + room.x * C.CELL + 3, C.OY + room.y * C.CELL + 3
            local width, height = def.w * C.CELL - 6, def.h * C.CELL - 6
            local cx, cy = x + width / 2, y + height / 2
            color(C.colors[room.type], room.built and 1 or 0.22)
            love.graphics.rectangle("fill", x, y, width, height, 5)
            if not room.built then
                color(C.colors.text, 0.45)
                love.graphics.setLineWidth(1)
                love.graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, height - 1, 5)
                for offset = 8, width - 4, 10 do
                    love.graphics.line(x + offset, y + 4, x + offset - 4, y + 12)
                end
                love.graphics.setFont(fonts.tiny)
                color(C.colors.text)
                if width > 36 then
                    love.graphics.printf(def.name, x, y + 17, width, "center")
                    local text = room.materials .. "/" .. def.cost .. " delivered"
                    if room.materials >= def.cost then text = "Build " .. math.floor(room.progress * 100) .. "%" end
                    love.graphics.printf(text, x, y + 36, width, "center")
                else
                    love.graphics.printf(room.materials .. "/" .. def.cost, x, y + 13, width, "center")
                end
                progress(x + 4, y + height - 7, width - 8,
                    room.materials >= def.cost and room.progress or room.materials / def.cost, C.colors.extractor)
            else
                if width > 36 then
                    love.graphics.setFont(fonts.tiny)
                    color(C.colors.text, 0.85)
                    love.graphics.printf(string.upper(def.name), x, y + 4, width, "center")
                end
                love.graphics.setColor(1, 1, 1, 0.72)
                if room.type == "garden" then
                    for i = -1, 1 do
                        local px = cx + i * 15
                        love.graphics.setLineWidth(2)
                        love.graphics.line(px, cy + 2, px, cy - 9)
                        love.graphics.ellipse("fill", px - 3, cy - 7, 4, 2)
                        love.graphics.ellipse("fill", px + 3, cy - 10, 4, 2)
                    end
                elseif room.type == "extractor" then
                    love.graphics.polygon("fill", cx, cy - 12, cx + 8, cy - 3, cx, cy + 6, cx - 8, cy - 3)
                elseif room.type == "kitchen" then
                    love.graphics.rectangle("line", cx - 15, cy - 12, 30, 17, 2)
                    love.graphics.circle("line", cx - 7, cy - 4, 4)
                    love.graphics.circle("line", cx + 7, cy - 4, 4)
                elseif room.type == "quarters" then
                    for i = 0, 1 do
                        local px = cx - 15 + i * 18
                        love.graphics.rectangle("line", px, cy - 12, 12, 17, 2)
                        love.graphics.rectangle("fill", px + 2, cy - 10, 8, 4, 1)
                        if i < room.recruited then
                            color(C.colors.worker, 0.65)
                            love.graphics.rectangle("fill", px + 3, cy - 4, 6, 7, 2)
                            love.graphics.setColor(1, 1, 1, 0.72)
                        end
                    end
                elseif room.type == "turret" then
                    color(C.colors.worker, Workers.inRoom(room) > 0 and 1 or 0.35)
                    love.graphics.circle("fill", cx, cy, 6)
                    love.graphics.setLineWidth(3)
                    love.graphics.line(cx, cy, cx + math.cos(room.aim) * 11, cy + math.sin(room.aim) * 11)
                    if Workers.inRoom(room) > 0 then
                        color(C.colors.food)
                        love.graphics.circle("fill", x + width - 5, y + 5, 2.5)
                    end
                end
                if width > 36 then stacks(room, x + 6, y + height - 20, width - 12) end
                for _, worker in ipairs(Workers.list) do
                    if worker.job and worker.job.target == room and worker.state == "working" then
                        local kind = worker.job.kind
                        local duration = kind == "cook" and C.cookSeconds or kind == "recruit" and C.recruitSeconds
                        if duration then progress(x + 4, y + height - 5, width - 8, worker.workTimer / duration) end
                    end
                end
                if room.hp < room.maxhp then progress(x + 3, y + height - 3, width - 6, room.hp / room.maxhp, C.colors.enemy) end
            end
            if room.hit > 0 then
                love.graphics.setColor(1, 1, 1, math.min(0.8, room.hit * 3))
                love.graphics.rectangle("fill", x, y, width, height, 5)
            end
        end
    end
end

function UI.drawHud(fonts, starvation, time)
    love.graphics.setFont(fonts.small)
    local resources = {
        { "mineral", math.floor(Economy.total("mineral")), "MINERALS", 26 },
        { "crop", math.floor(Economy.total("crop")), "CROPS", 161 },
        { "food", math.floor(Grid.coreRoom.stock.food or 0), "PANTRY", 275 },
    }
    for _, item in ipairs(resources) do
        color(C.colors[item[1]])
        love.graphics.rectangle("fill", item[4], 22, 11, 11, 2)
        love.graphics.setFont(fonts.ui)
        color(C.colors.text)
        love.graphics.print(item[2], item[4] + 19, 17)
        love.graphics.setFont(fonts.tiny)
        color(C.colors.textSoft)
        love.graphics.print(item[3], item[4], 43)
    end
    color(C.colors.text)
    love.graphics.setFont(fonts.ui)
    love.graphics.print(Workers.count() .. " crew", 403, 17)
    love.graphics.setFont(fonts.tiny)
    color(C.colors.textSoft)
    love.graphics.print("MEALS IN TRANSIT FEED NO ONE", 403, 43)
    love.graphics.setFont(fonts.ui)
    color(Workers.alert and C.colors.enemy or C.colors.text)
    local seconds = math.max(0, math.ceil(Enemies.timer))
    local text = "Wave " .. Enemies.wave .. "  /  " .. math.floor(seconds / 60) .. ":" .. string.format("%02d", seconds % 60)
    if #Enemies.list > 0 then text = "DEFEND THE STATION"
    elseif Workers.alert then text = "WAVE INCOMING  " .. seconds .. "s" end
    love.graphics.printf(text, 605, 17, C.W - 628, "right")
    love.graphics.setFont(fonts.tiny)
    color(C.colors.textSoft)
    love.graphics.printf("CREW AUTO-MAN WEAPONS ON ALERT", 605, 43, C.W - 628, "right")
    if starvation > 0 then
        color(C.colors.enemy, 0.7 + math.sin(time * 8) * 0.3)
        love.graphics.printf("PANTRY EMPTY - PRIORITIZE FOOD SERVICE", 0, 59, C.W, "center")
    end
end

function UI.click(x, y)
    if y >= C.BAR_Y + 10 and y <= C.BAR_Y + 47 then
        for i, kind in ipairs(C.buildOrder) do
            local bx = 12 + (i - 1) * (buildWidth + 8)
            if x >= bx and x <= bx + buildWidth then return kind end
        end
    elseif y >= C.BAR_Y + 61 and y <= C.BAR_Y + 91 then
        for i, priority in ipairs(C.priorities) do
            local bx = 93 + (i - 1) * (priorityWidth + 7)
            if x >= bx and x <= bx + priorityWidth then Workers.setPriority(priority); return end
        end
    end
end

function UI.drawBar(fonts, selected)
    love.graphics.setColor(0.76, 0.80, 0.86)
    love.graphics.rectangle("fill", 0, C.BAR_Y, C.W, C.BAR_H)
    for i, kind in ipairs(C.buildOrder) do
        local x, y = 12 + (i - 1) * (buildWidth + 8), C.BAR_Y + 10
        local chosen = selected == kind
        color(chosen and C.colors.core or { 0.95, 0.96, 0.98 })
        love.graphics.rectangle("fill", x, y, buildWidth, 37, 5)
        color(C.colors[kind])
        love.graphics.rectangle("fill", x + 6, y + 8, 3, 21, 1)
        love.graphics.setFont(fonts.small)
        color(chosen and { 1, 1, 1 } or C.colors.text)
        love.graphics.print(i .. " " .. C.rooms[kind].name, x + 14, y + 11)
        love.graphics.setFont(fonts.tiny)
        love.graphics.print(C.rooms[kind].cost, x + buildWidth - 13, y + 3)
    end
    love.graphics.setFont(fonts.small)
    color(C.colors.text)
    love.graphics.print("CREW", 19, C.BAR_Y + 69)
    for i, priority in ipairs(C.priorities) do
        local x, y = 93 + (i - 1) * (priorityWidth + 7), C.BAR_Y + 61
        local chosen = Workers.priority == priority
        color(chosen and C.colors.core or { 0.86, 0.89, 0.93 })
        love.graphics.rectangle("fill", x, y, priorityWidth, 30, 4)
        color(chosen and { 1, 1, 1 } or C.colors.text)
        love.graphics.printf(C.priorityNames[priority], x, y + 7, priorityWidth, "center")
    end
    local counts = Workers.activity()
    color(C.colors.text)
    love.graphics.print(counts.hauling .. " hauling   " .. counts.working .. " working   " .. counts.defending .. " defending   " .. counts.idle .. " waiting", 19, C.BAR_Y + 105)
    color(C.colors.textSoft)
    love.graphics.setFont(fonts.tiny)
    love.graphics.printf("Tab: crew priority  /  P: pause  /  R: restart", 520, C.BAR_Y + 109, 341, "right")
    love.graphics.print("1-6: choose room  /  Click: queue construction  /  Right-click: salvage  /  Hover: inspect jobs and stockpiles", 19, C.BAR_Y + 131)
end

function UI.drawTooltip(fonts)
    local mx, my = love.mouse.getPosition()
    if my >= C.BAR_Y then return end
    local text
    for _, w in ipairs(Workers.list) do
        if math.abs(mx - w.x) < 11 and math.abs(my - w.y) < 14 then
            text = w.label
            if w.job then text = text .. " - " .. w.job.target.def.name end
            if w.path and #w.path > 0 then
                color(C.colors.text, 0.4)
                love.graphics.setLineWidth(1)
                local x, y = w.x, w.y
                for _, node in ipairs(w.path) do
                    local nx, ny = Grid.center(node.x, node.y)
                    love.graphics.line(x, y, nx, ny)
                    x, y = nx, ny
                end
            end
            break
        end
    end
    local gx, gy = Grid.atPixel(mx, my)
    local room = Grid.roomAt(gx, gy)
    if not text and room then
        if not room.built then
            text = room.def.name .. ": " .. room.materials .. "/" .. room.def.cost .. " minerals delivered. "
                .. (room.materials < room.def.cost and "Waiting for haulers and a connected route." or "Builder required to finish construction.")
        else
            text = room.def.name .. ": " .. descriptions[room.type]
            if room.type == "turret" then
                text = text .. (Workers.inRoom(room) > 0 and " MANNED" or " UNMANNED")
                local x, y = Grid.center(room.x, room.y)
                color(C.colors.text, 0.18)
                love.graphics.setLineWidth(1)
                love.graphics.circle("line", x, y, C.turretRange)
            end
        end
    end
    if text then
        love.graphics.setColor(0.17, 0.20, 0.28, 0.94)
        love.graphics.rectangle("fill", 16, C.BAR_Y - 38, C.W - 32, 29, 5)
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(text, 25, C.BAR_Y - 31, C.W - 50, "center")
    end
end

return UI

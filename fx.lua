local FX = { list = {} }

function FX.reset()
    FX.list = {}
end

function FX.burst(x, y, color, n, speed)
    speed = speed or 1
    for _ = 1, n do
        local a = love.math.random() * math.pi * 2
        local sp = (30 + love.math.random() * 90) * speed
        FX.list[#FX.list + 1] = {
            x = x,
            y = y,
            vx = math.cos(a) * sp,
            vy = math.sin(a) * sp,
            life = 0.35 + love.math.random() * 0.45,
            t = 0,
            r = 1.5 + love.math.random() * 2,
            color = color,
        }
    end
end

function FX.update(dt)
    for i = #FX.list, 1, -1 do
        local p = FX.list[i]
        p.t = p.t + dt
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        local drag = math.max(0, 1 - 2.4 * dt)
        p.vx = p.vx * drag
        p.vy = p.vy * drag
        if p.t >= p.life then table.remove(FX.list, i) end
    end
end

function FX.draw()
    for _, p in ipairs(FX.list) do
        local a = 1 - p.t / p.life
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], a)
        love.graphics.circle("fill", p.x, p.y, p.r * (0.4 + 0.6 * a))
    end
end

return FX

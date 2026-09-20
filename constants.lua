local C = {}

C.W, C.H = 880, 760
C.CELL = 36
C.COLS, C.ROWS = 22, 15
C.OX = (C.W - C.COLS * C.CELL) / 2
C.OY = 70
C.GRID_W = C.COLS * C.CELL
C.GRID_H = C.ROWS * C.CELL
C.BAR_Y = C.OY + C.GRID_H
C.BAR_H = C.H - C.BAR_Y

C.startMinerals = 12
C.startFood = 12
C.startWorkers = 5
C.maxWorkers = 80

C.foodEatRate = 0.045
C.starveSeconds = 10
C.cropSeconds = 3
C.mineralSeconds = 4
C.cookSeconds = 1.8
C.mealsPerCrop = 3
C.mealsPerRecruit = 3
C.recruitSeconds = 4
C.recruitsPerQuarters = 2
C.buildSeconds = 0.65
C.stockCapacity = 8
C.pantryCapacity = 20

C.waveFirst = 90
C.waveInterval = 60
C.warnSeconds = 12

C.turretRange = 130
C.turretCooldown = 1.1
C.turretDamage = 11

C.core = { hp = 300 }

C.rooms = {
    corridor = { name = "Corridor", w = 1, h = 1, cost = 1, hp = 18 },
    garden = { name = "Garden", w = 2, h = 2, cost = 4, hp = 44 },
    extractor = { name = "Extractor", w = 2, h = 2, cost = 4, hp = 44 },
    turret = { name = "Weapons", w = 1, h = 1, cost = 6, hp = 65 },
    kitchen = { name = "Kitchen", w = 2, h = 2, cost = 4, hp = 44 },
    quarters = { name = "Quarters", w = 2, h = 2, cost = 5, hp = 50 },
}
C.buildOrder = { "corridor", "garden", "extractor", "turret", "kitchen", "quarters" }
C.priorities = { "balanced", "build", "food", "defense" }
C.priorityNames = { balanced = "Balanced", build = "Construction", food = "Food service", defense = "Defense" }

C.colors = {
    bg = { 0.82, 0.855, 0.90 },
    planet = { 0.78, 0.81, 0.87 },
    gridLine = { 1, 1, 1, 0.35 },
    corridor = { 0.94, 0.94, 0.95 },
    core = { 0.36, 0.40, 0.52 },
    garden = { 0.55, 0.80, 0.62 },
    extractor = { 0.42, 0.62, 0.85 },
    kitchen = { 0.91, 0.76, 0.35 },
    quarters = { 0.90, 0.59, 0.40 },
    turret = { 0.70, 0.70, 0.78 },
    worker = { 0.16, 0.18, 0.26 },
    enemy = { 0.83, 0.30, 0.33 },
    shot = { 0.25, 0.25, 0.35 },
    mineral = { 0.42, 0.62, 0.85 },
    food = { 0.96, 0.78, 0.27 },
    crop = { 0.35, 0.70, 0.43 },
    text = { 0.20, 0.23, 0.32 },
    textSoft = { 0.20, 0.23, 0.32, 0.55 },
    ghostOk = { 0.35, 0.75, 0.45, 0.45 },
    ghostBad = { 0.85, 0.30, 0.30, 0.40 },
}

return C

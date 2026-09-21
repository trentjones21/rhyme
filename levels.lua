-- Campaign: seven worlds, forty-two short stations. Generated from the web design source.
local M = {}

M.WORLDS = {
  {
    id = 1,
    name = "Quiet Dock",
    blurb = "Lay geometry. Tap rooms. Feed the white dashes."
  },
  {
    id = 2,
    name = "Supply Lines",
    blurb = "Galley meals over green sludge. Distance is a tax."
  },
  {
    id = 3,
    name = "Solar Weather",
    blurb = "The star bites anything an umbrella does not cover."
  },
  {
    id = 4,
    name = "Relic Shore",
    blurb = "Mute monuments on the sand. The bag starts handing you shapes."
  },
  {
    id = 5,
    name = "Fold",
    blurb = "Two pads, one violet step. The floor itself walks."
  },
  {
    id = 6,
    name = "Ice Belt",
    blurb = "Frost holds kapsels. A hearth writes water back."
  },
  {
    id = 7,
    name = "Ghost Current",
    blurb = "What you cannot see still eats geometry."
  }
}

M.ROOM_DEFAULT = {
  corridor = "Corridor",
  garden = "Garden",
  extractor = "Extractor",
  weapons = "Weapons",
  kitchen = "Kitchen",
  quarters = "Quarters",
  shield = "Shield",
  gate = "Gate",
  heater = "Heater",
  scanner = "Scanner",
  beacon = "Beacon",
  core = "Core"
}

M.WORLD_LOOK = {
  [1] = {
    accent = "#8d6b4a",
    stinger = "dock",
    nebula0 = "#22283a",
    nebula1 = "#151826",
    nebula2 = "#0c0f16",
    void = "#040406",
    haze = "rgba(90,120,170,0.16)",
    haze2 = "rgba(110,55,80,0.12)",
    mote = "rgba(243,240,232,0.07)",
    grid = "rgba(255,255,255,0.045)",
    rooms = {}
  },
  [2] = {
    accent = "#5ea86a",
    stinger = "supply",
    nebula0 = "#1c2e22",
    nebula1 = "#121a16",
    nebula2 = "#0a100c",
    void = "#040605",
    haze = "rgba(94,168,106,0.2)",
    haze2 = "rgba(212,177,74,0.12)",
    mote = "rgba(240,194,74,0.08)",
    grid = "rgba(94,168,106,0.08)",
    rooms = {
      kitchen = "Galley",
      garden = "Plot",
      extractor = "Vein"
    }
  },
  [3] = {
    accent = "#e07a4a",
    stinger = "solar",
    nebula0 = "#3a2218",
    nebula1 = "#1c120e",
    nebula2 = "#100806",
    void = "#070302",
    haze = "rgba(224,122,74,0.22)",
    haze2 = "rgba(226,75,82,0.1)",
    mote = "rgba(224,122,74,0.1)",
    grid = "rgba(224,122,74,0.08)",
    rooms = {
      shield = "Umbrella",
      garden = "Glass plot"
    }
  },
  [4] = {
    accent = "#e8d9a0",
    stinger = "relic",
    nebula0 = "#2a2618",
    nebula1 = "#18160e",
    nebula2 = "#0c0b08",
    void = "#050504",
    haze = "rgba(232,217,160,0.16)",
    haze2 = "rgba(155,122,212,0.08)",
    mote = "rgba(232,217,160,0.1)",
    grid = "rgba(232,217,160,0.07)",
    rooms = {
      corridor = "Shore road"
    }
  },
  [5] = {
    accent = "#9b7ad4",
    stinger = "fold",
    nebula0 = "#22182e",
    nebula1 = "#14101c",
    nebula2 = "#0a0810",
    void = "#05040a",
    haze = "rgba(155,122,212,0.22)",
    haze2 = "rgba(110,195,201,0.08)",
    mote = "rgba(155,122,212,0.1)",
    grid = "rgba(155,122,212,0.09)",
    rooms = {
      gate = "Fold"
    }
  },
  [6] = {
    accent = "#70b4e0",
    stinger = "frost",
    nebula0 = "#18242e",
    nebula1 = "#101820",
    nebula2 = "#080c12",
    void = "#04060a",
    haze = "rgba(112,180,224,0.2)",
    haze2 = "rgba(243,240,232,0.08)",
    mote = "rgba(200,230,245,0.1)",
    grid = "rgba(112,180,224,0.08)",
    rooms = {
      heater = "Hearth",
      corridor = "Ice road"
    }
  },
  [7] = {
    accent = "#7b88a3",
    stinger = "ghost",
    nebula0 = "#161822",
    nebula1 = "#101218",
    nebula2 = "#08090d",
    void = "#030306",
    haze = "rgba(123,136,163,0.18)",
    haze2 = "rgba(226,75,82,0.08)",
    mote = "rgba(123,136,163,0.08)",
    grid = "rgba(243,240,232,0.05)",
    rooms = {
      scanner = "Eye"
    }
  }
}

function M.worldLook(worldId)
  return M.WORLD_LOOK[worldId] or M.WORLD_LOOK[1]
end

function M.roomLabel(type, worldId)
  local look = M.worldLook(worldId)
  return (look.rooms and look.rooms[type]) or M.ROOM_DEFAULT[type] or type
end

M.LEVELS = {
  {
    id = "1-01",
    world = 1,
    name = "Spine",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 8,
      food = 0,
      crew = 3
    },
    deposits = {},
    ice = {},
    blocked = {},
    wells = {},
    relics = {},
    prebuilt = {},
    allowed = { "corridor" },
    mechanics = {
      teachAssign = true
    },
    waves = {
      first = 9999,
      interval = 48,
      count = 0,
      max = 0
    },
    eatRate = 0,
    par = 50,
    hint = "Select Corridor, tap a tile touching the core, then tap the blueprint.",
    lesson = "Rooms must kiss the station. Corridors are bone.",
    briefing = "The core is a plus of dark tiles. Place one corridor, then tap that blueprint. Assignment is the whole game; later halls send themselves.",
    win = {
      corridors = 3
    }
  },
  {
    id = "1-02",
    world = 1,
    name = "Garden Duty",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 8,
      food = 0,
      crew = 3
    },
    deposits = {},
    ice = {},
    blocked = {},
    wells = {},
    relics = {},
    prebuilt = {},
    allowed = { "corridor", "garden" },
    mechanics = {
      teachStaff = true
    },
    waves = {
      first = 9999,
      interval = 48,
      count = 0,
      max = 0
    },
    eatRate = 0,
    par = 70,
    hint = "After it is built, tap the garden — not the kapsel.",
    lesson = "A garden grows meals. Tap it to send a kapsel.",
    briefing = "Place a garden, assign a kapsel, and let them carry pale food back to the core pantry. Assignment is not optional here either.",
    win = {
      rooms = {
        garden = 1
      },
      food = 4
    }
  },
  {
    id = "1-03",
    world = 1,
    name = "The Vein",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 8,
      food = 4,
      crew = 3
    },
    deposits = {
      {
        x = 1,
        y = 6
      }
    },
    ice = {},
    blocked = {},
    wells = {},
    relics = {},
    prebuilt = {},
    allowed = { "corridor", "extractor" },
    mechanics = {},
    waves = {
      first = 9999,
      interval = 48,
      count = 0,
      max = 0
    },
    eatRate = 0,
    par = 80,
    hint = "The L-piece must touch a pink field.",
    lesson = "Extractors only bite pink mineral fields.",
    briefing = "A deposit glitters west of the core. Seat an extractor against it and bank six minerals in the pantry.",
    win = {
      rooms = {
        extractor = 1
      },
      mineral = 14
    }
  },
  {
    id = "1-04",
    world = 1,
    name = "Watchpost",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 12,
      food = 6,
      crew = 3
    },
    deposits = {},
    ice = {},
    blocked = {},
    wells = {},
    relics = {},
    prebuilt = {},
    allowed = { "corridor", "weapons" },
    mechanics = {},
    waves = {
      first = 18,
      interval = 40,
      count = 2,
      hp = 28,
      speed = 22,
      max = 1
    },
    eatRate = 0,
    par = 55,
    hint = "Assign before the rim turns red.",
    lesson = "Weapons are mute until a kapsel stands in them.",
    briefing = "Something sharp is coming from the dark. Build a gun, tap it, and keep the core intact.",
    win = {
      rooms = {
        weapons = 1
      },
      surviveWaves = 1
    }
  },
  {
    id = "1-05",
    world = 1,
    name = "Berths",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 12,
      food = 12,
      crew = 3
    },
    deposits = {},
    ice = {},
    blocked = {},
    wells = {},
    relics = {},
    prebuilt = {},
    allowed = { "corridor", "quarters" },
    mechanics = {},
    waves = {
      first = 9999,
      interval = 48,
      count = 0,
      max = 0
    },
    eatRate = 0,
    par = 70,
    hint = "Tap quarters. They will fetch food themselves.",
    lesson = "Quarters eat pantry meals and mint new kapsels.",
    briefing = "Grow the crew to five. Three meals, a little waiting, a new white dash.",
    win = {
      rooms = {
        quarters = 1
      },
      crew = 5
    }
  },
  {
    id = "1-06",
    world = 1,
    name = "Station Hands",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 16,
      food = 10,
      crew = 4
    },
    deposits = {
      {
        x = 1,
        y = 6
      },
      {
        x = 7,
        y = 6
      }
    },
    ice = {},
    blocked = {},
    wells = {},
    relics = {},
    prebuilt = {},
    allowed = { "corridor", "garden", "extractor", "weapons", "quarters" },
    mechanics = {},
    waves = {
      first = 24,
      interval = 28,
      count = function(n) return 1 + n end,
      hp = function(n) return 24 + n * 10 end,
      max = 2
    },
    eatRate = 0.018,
    par = 90,
    hint = "Two guns on opposite sides beat one fancy spine.",
    lesson = "A living station feeds, mines, and shoots.",
    briefing = "You have the whole quiet kit. Grow past the opening pantry, staff a gun, and hold two waves.",
    win = {
      surviveWaves = 2,
      food = 12,
      rooms = {
        garden = 1,
        extractor = 1,
        weapons = 1
      }
    }
  },
  {
    id = "2-01",
    world = 2,
    name = "Sludge",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 16,
      food = 6,
      crew = 4
    },
    deposits = {},
    ice = {},
    blocked = {},
    wells = {},
    relics = {},
    prebuilt = {},
    allowed = { "corridor", "garden", "kitchen" },
    mechanics = {
      kitchenChain = true
    },
    waves = {
      first = 9999,
      interval = 48,
      count = 0,
      max = 0
    },
    eatRate = 0.01,
    par = 85,
    hint = "Tap both rooms. Food is yellow; sludge is green.",
    lesson = "Plots grow sludge. The galley cooks it into meals.",
    briefing = "The old direct harvest is gone. Staff a plot and a galley until the pantry climbs past the opening six.",
    win = {
      rooms = {
        kitchen = 1,
        garden = 1
      },
      food = 9
    }
  },
  {
    id = "2-02",
    world = 2,
    name = "Long Haul",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 3
    },
    start = {
      minerals = 28,
      food = 8,
      crew = 4
    },
    deposits = {
      {
        x = 4,
        y = 10
      }
    },
    ice = {},
    blocked = {},
    wells = {},
    relics = {},
    prebuilt = {},
    allowed = { "corridor", "garden", "extractor", "kitchen" },
    mechanics = {
      kitchenChain = true
    },
    waves = {
      first = 9999,
      interval = 48,
      count = 0,
      max = 0
    },
    eatRate = 0.012,
    par = 110,
    hint = "Build the road first. Production without a path is sculpture.",
    lesson = "Every empty tile is a tax on time.",
    briefing = "The only vein sits far south. Lay the haul road, sit an extractor on it, and bank six minerals past the opening twenty-eight.",
    win = {
      mineral = 34,
      food = 10,
      rooms = {
        extractor = 1,
        kitchen = 1
      }
    }
  },
  {
    id = "2-03",
    world = 2,
    name = "Two Kitchens",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 18,
      food = 6,
      crew = 4
    },
    deposits = {},
    ice = {},
    blocked = {},
    wells = {},
    relics = {},
    prebuilt = {},
    allowed = { "corridor", "garden", "kitchen", "quarters" },
    mechanics = {
      kitchenChain = true
    },
    waves = {
      first = 9999,
      interval = 48,
      count = 0,
      max = 0
    },
    eatRate = 0.014,
    par = 90,
    hint = "",
    lesson = "Two galleys are not twice as fast if sludge is scarce.",
    briefing = "Climb to twelve pantry meals. A second galley is optional; a second plot is usually not. Someone still has to cook.",
    win = {
      food = 12,
      rooms = {
        kitchen = 1
      }
    }
  },
  {
    id = "2-04",
    world = 2,
    name = "Narrow Dock",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 16,
      food = 8,
      crew = 4
    },
    deposits = {
      {
        x = 0,
        y = 9
      }
    },
    ice = {},
    blocked = {
      {
        x = 4,
        y = 4
      },
      {
        x = 4,
        y = 8
      },
      {
        x = 2,
        y = 6
      },
      {
        x = 6,
        y = 6
      }
    },
    wells = {},
    relics = {},
    prebuilt = {},
    allowed = { "corridor", "garden", "extractor", "kitchen", "weapons" },
    mechanics = {
      kitchenChain = true
    },
    waves = {
      first = 32,
      interval = 30,
      count = 3,
      hp = 32,
      max = 1
    },
    eatRate = 0.016,
    par = 95,
    hint = "",
    lesson = "The void has already claimed tiles. Thread the station through.",
    briefing = "Asteroids block the obvious spine. Survive one wave after you have a gun.",
    win = {
      rooms = {
        weapons = 1
      },
      surviveWaves = 1
    }
  },
  {
    id = "2-05",
    world = 2,
    name = "Hungry Shift",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 16,
      food = 14,
      crew = 6
    },
    deposits = {},
    ice = {},
    blocked = {},
    wells = {},
    relics = {},
    prebuilt = {},
    allowed = { "corridor", "garden", "kitchen", "quarters" },
    mechanics = {
      kitchenChain = true
    },
    waves = {
      first = 9999,
      interval = 48,
      count = 0,
      max = 0
    },
    eatRate = 0.016,
    par = 100,
    hint = "Garden and galley first. Then tap Quarters — three meals mint a seventh kapsel.",
    lesson = "Crew is a furnace. Too many mouths before the galley sings.",
    briefing = "You start with six kapsels and a thinning pantry. Stabilize food, tap a berth, then mint one more dash.",
    win = {
      food = 8,
      crew = 7,
      rooms = {
        quarters = 1
      }
    }
  },
  {
    id = "2-06",
    world = 2,
    name = "Convoy",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 20,
      food = 12,
      crew = 5
    },
    deposits = {
      {
        x = 1,
        y = 3
      },
      {
        x = 7,
        y = 10
      }
    },
    ice = {},
    blocked = {},
    wells = {},
    relics = {},
    prebuilt = {},
    allowed = { "corridor", "garden", "extractor", "kitchen", "weapons", "quarters" },
    mechanics = {
      kitchenChain = true
    },
    waves = {
      first = 26,
      interval = 24,
      count = function(n) return 1 + n end,
      hp = function(n) return 26 + n * 12 end,
      max = 3
    },
    eatRate = 0.016,
    par = 120,
    hint = "Two guns, one galley. Do not let the pantry hit zero between waves.",
    lesson = "Hold the line while the chain still moves.",
    briefing = "Three waves. Keep a galley hot and at least two weapons staffed when the rim reddens.",
    win = {
      surviveWaves = 3,
      food = 1,
      rooms = {
        weapons = 2,
        kitchen = 1
      }
    }
  },
  {
    id = "3-01",
    world = 3,
    name = "First Flare",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 16,
      food = 2,
      crew = 4
    },
    deposits = {},
    ice = {},
    blocked = {},
    wells = {},
    relics = {},
    prebuilt = {},
    allowed = { "corridor", "garden", "shield" },
    mechanics = {
      flares = {
        first = 18,
        interval = 18,
        damage = 40,
        telegraph = 3
      }
    },
    waves = {
      first = 9999,
      interval = 48,
      count = 0,
      max = 0
    },
    eatRate = 0,
    par = 80,
    hint = "Aegis is passive. Cover the garden before the rim goes white.",
    lesson = "Unshielded rooms scorch when the star inhales.",
    briefing = "The star is already winding up. Raise an umbrella, keep a garden alive through the first breath, and grow past the opening pantry.",
    win = {
      rooms = {
        shield = 1,
        garden = 1
      },
      food = 4,
      flares = 1
    }
  },
  {
    id = "3-02",
    world = 3,
    name = "Umbrella",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 18,
      food = 6,
      crew = 4
    },
    deposits = {
      {
        x = 1,
        y = 9
      }
    },
    ice = {},
    blocked = {},
    wells = {},
    relics = {},
    prebuilt = {},
    allowed = { "corridor", "garden", "extractor", "shield" },
    mechanics = {
      flares = {
        first = 18,
        interval = 16,
        damage = 12,
        telegraph = 2.6
      }
    },
    waves = {
      first = 9999,
      interval = 48,
      count = 0,
      max = 0
    },
    eatRate = 0,
    par = 90,
    hint = "",
    lesson = "One umbrella cannot cover a sprawling station.",
    briefing = "Keep both a glass plot and an extractor alive through two flares, then bank food past the opening six.",
    win = {
      rooms = {
        shield = 1,
        extractor = 1
      },
      food = 8,
      flares = 2
    }
  },
  {
    id = "3-03",
    world = 3,
    name = "Exposed Vein",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 18,
      food = 8,
      crew = 4
    },
    deposits = {
      {
        x = 1,
        y = 3
      }
    },
    ice = {},
    blocked = {},
    wells = {},
    relics = {},
    prebuilt = {},
    allowed = { "corridor", "extractor", "shield", "garden" },
    mechanics = {
      flares = {
        first = 16,
        interval = 16,
        damage = 9,
        telegraph = 2.4
      }
    },
    waves = {
      first = 9999,
      interval = 48,
      count = 0,
      max = 0
    },
    eatRate = 0,
    par = 85,
    hint = "",
    lesson = "Sometimes the deposit sits outside the umbrella on purpose.",
    briefing = "Mine the far field until the bank is past the opening eighteen. Stretch a second umbrella or finish before the extractor dies.",
    win = {
      mineral = 24,
      rooms = {
        extractor = 1
      }
    }
  },
  {
    id = "3-04",
    world = 3,
    name = "Double Pulse",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 20,
      food = 10,
      crew = 5
    },
    deposits = {
      {
        x = 7,
        y = 2
      }
    },
    ice = {},
    blocked = {},
    wells = {},
    relics = {},
    prebuilt = {},
    allowed = { "corridor", "garden", "extractor", "weapons", "shield", "quarters" },
    mechanics = {
      flares = {
        first = 18,
        interval = 16,
        damage = 12,
        telegraph = 2.5
      }
    },
    waves = {
      first = 22,
      interval = 26,
      count = function(n) return 2 end,
      hp = function(n) return 30 + n * 8 end,
      max = 2
    },
    eatRate = 0.016,
    par = 110,
    hint = "",
    lesson = "Flares and scouts share a calendar.",
    briefing = "Survive two waves while the star keeps biting. Guns on the rim, umbrella on the pantry.",
    win = {
      surviveWaves = 2,
      rooms = {
        shield = 1
      }
    }
  },
  {
    id = "3-05",
    world = 3,
    name = "Glass House",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 18,
      food = 8,
      crew = 4
    },
    deposits = {},
    ice = {},
    blocked = {},
    wells = {},
    relics = {},
    prebuilt = {},
    allowed = { "corridor", "garden", "kitchen", "shield" },
    mechanics = {
      kitchenChain = true,
      flares = {
        first = 16,
        interval = 16,
        damage = 12,
        telegraph = 2.2
      }
    },
    waves = {
      first = 9999,
      interval = 48,
      count = 0,
      max = 0
    },
    eatRate = 0.014,
    par = 100,
    hint = "",
    lesson = "A glass plot far from the umbrella is a dare.",
    briefing = "Produce ten meals with a station that wants to sprawl. The star will punish sprawl.",
    win = {
      food = 10,
      rooms = {
        shield = 1
      }
    }
  },
  {
    id = "3-06",
    world = 3,
    name = "Storm Season",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 26,
      food = 14,
      crew = 5
    },
    deposits = {
      {
        x = 1,
        y = 6
      },
      {
        x = 8,
        y = 11
      }
    },
    ice = {},
    blocked = {},
    wells = {},
    relics = {},
    prebuilt = {},
    allowed = { "corridor", "garden", "extractor", "kitchen", "weapons", "quarters", "shield" },
    mechanics = {
      kitchenChain = true,
      flares = {
        first = 22,
        interval = 16,
        damage = 9,
        telegraph = 2.4
      }
    },
    waves = {
      first = 26,
      interval = 22,
      count = function(n) return 1 + n end,
      hp = function(n) return 24 + n * 10 end,
      max = 3
    },
    eatRate = 0.016,
    par = 130,
    hint = "",
    lesson = "Weather plus war. Compact geometry wins.",
    briefing = "Three waves, regular flares. If the core is bare, it will unstitch.",
    win = {
      surviveWaves = 3
    }
  },
  {
    id = "4-01",
    world = 4,
    name = "First Relic",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 8,
      food = 6,
      crew = 3
    },
    deposits = {},
    ice = {},
    blocked = {},
    wells = {},
    relics = {
      {
        x = 8,
        y = 6
      }
    },
    prebuilt = {},
    allowed = { "corridor" },
    mechanics = {},
    waves = {
      first = 9999,
      interval = 48,
      count = 0,
      max = 0
    },
    eatRate = 0,
    par = 40,
    hint = "You do not build on the relic. You kiss it.",
    lesson = "A relic counts when built floor can walk to it.",
    briefing = "The pale obelisk east of the core is mute until a corridor touches it.",
    win = {
      relics = 1
    }
  },
  {
    id = "4-02",
    world = 4,
    name = "Opposite Shore",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 20,
      food = 6,
      crew = 3
    },
    deposits = {},
    ice = {},
    blocked = {},
    wells = {},
    relics = {
      {
        x = 4,
        y = 0
      },
      {
        x = 4,
        y = 12
      }
    },
    prebuilt = {},
    allowed = { "corridor" },
    mechanics = {},
    waves = {
      first = 9999,
      interval = 48,
      count = 0,
      max = 0
    },
    eatRate = 0,
    par = 55,
    hint = "",
    lesson = "Two relics, two directions. Do not spend the whole bank on one road.",
    briefing = "North and south monuments. Link both.",
    win = {
      relics = 2
    }
  },
  {
    id = "4-03",
    world = 4,
    name = "Guarded Archive",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 32,
      food = 8,
      crew = 4
    },
    deposits = {},
    ice = {},
    blocked = {},
    wells = {},
    relics = {
      {
        x = 0,
        y = 2
      },
      {
        x = 8,
        y = 10
      }
    },
    prebuilt = {},
    allowed = { "corridor", "weapons", "garden" },
    mechanics = {},
    waves = {
      first = 40,
      interval = 30,
      count = 3,
      hp = 34,
      max = 1
    },
    eatRate = 0,
    par = 90,
    hint = "",
    lesson = "Scouts smell new floor.",
    briefing = "Link two relics and hold one wave. A gun on the new road is not vanity.",
    win = {
      relics = 2,
      surviveWaves = 1
    }
  },
  {
    id = "4-04",
    world = 4,
    name = "Four Corners",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 44,
      food = 8,
      crew = 5
    },
    deposits = {
      {
        x = 2,
        y = 6
      }
    },
    ice = {},
    blocked = {},
    wells = {},
    relics = {
      {
        x = 0,
        y = 1
      },
      {
        x = 8,
        y = 1
      },
      {
        x = 0,
        y = 11
      },
      {
        x = 8,
        y = 11
      }
    },
    prebuilt = {},
    allowed = { "corridor", "garden", "extractor", "weapons" },
    mechanics = {
      pieceQueue = true
    },
    waves = {
      first = 160,
      interval = 48,
      count = 1,
      hp = 16,
      max = 1
    },
    eatRate = 0,
    par = 120,
    hint = "Hold parks a bad piece. Rotate the bag. Kiss every corner.",
    lesson = "The bag hands you a shape. You still choose the room's job.",
    briefing = "Four relics. Each placement is a random tetromino. Hold a stubborn I, rotate the rest, kiss every monument.",
    win = {
      relics = 4
    }
  },
  {
    id = "4-05",
    world = 4,
    name = "Living Archive",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 32,
      food = 10,
      crew = 4
    },
    deposits = {},
    ice = {},
    blocked = {},
    wells = {},
    relics = {
      {
        x = 0,
        y = 6
      },
      {
        x = 8,
        y = 2
      },
      {
        x = 8,
        y = 10
      }
    },
    prebuilt = {},
    allowed = { "corridor", "garden", "kitchen", "weapons" },
    mechanics = {
      kitchenChain = true
    },
    waves = {
      first = 30,
      interval = 26,
      count = 3,
      hp = 32,
      max = 1
    },
    eatRate = 0.016,
    par = 120,
    hint = "",
    lesson = "Relics do not feed anyone. Someone still has to eat.",
    briefing = "Link three relics while the pantry stays honest. Kitchen chain is back. Garden, then kitchen, then the shore.",
    win = {
      relics = 3,
      food = 4,
      surviveWaves = 1
    }
  },
  {
    id = "4-06",
    world = 4,
    name = "Surveyors",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 48,
      food = 16,
      crew = 5
    },
    deposits = {},
    ice = {},
    blocked = {},
    wells = {},
    relics = {
      {
        x = 2,
        y = 2
      },
      {
        x = 6,
        y = 2
      },
      {
        x = 2,
        y = 10
      },
      {
        x = 6,
        y = 10
      }
    },
    prebuilt = {},
    allowed = { "corridor", "garden", "extractor", "kitchen", "weapons", "shield", "quarters" },
    mechanics = {
      kitchenChain = true,
      flares = {
        first = 16,
        interval = 18,
        damage = 12,
        telegraph = 2.6
      }
    },
    waves = {
      first = 32,
      interval = 24,
      count = function(n) return 2 + n end,
      hp = function(n) return 28 + n * 10 end,
      max = 2
    },
    eatRate = 0.018,
    par = 140,
    hint = "",
    lesson = "Four relics, two waves, a star that does not care about archaeology.",
    briefing = "The shore remembers weather. Bring a shield. Touch every monument. Hold.",
    win = {
      relics = 4,
      surviveWaves = 2
    }
  },
  {
    id = "5-01",
    world = 5,
    name = "Shortcut",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 16,
      food = 2,
      crew = 3
    },
    deposits = {},
    ice = {},
    blocked = {
      {
        x = 0,
        y = 8
      },
      {
        x = 1,
        y = 8
      },
      {
        x = 2,
        y = 8
      },
      {
        x = 3,
        y = 8
      },
      {
        x = 4,
        y = 8
      },
      {
        x = 5,
        y = 8
      },
      {
        x = 6,
        y = 8
      },
      {
        x = 7,
        y = 8
      },
      {
        x = 8,
        y = 8
      }
    },
    wells = {},
    relics = {},
    prebuilt = {
      {
        type = "gate",
        x = 4,
        y = 10,
        rot = 0,
        built = true
      },
      {
        type = "garden",
        x = 4,
        y = 11,
        rot = 0,
        built = true
      }
    },
    allowed = { "corridor", "gate" },
    mechanics = {
      wormholes = true
    },
    waves = {
      first = 9999,
      interval = 48,
      count = 0,
      max = 0
    },
    eatRate = 0,
    par = 70,
    hint = "One pad is already on the island. Pair it from the plus, then tap the garden.",
    lesson = "Two gates are one step. The far garden is not.",
    briefing = "One pad already sits on the island garden. Pair it from the plus, fold a kapsel across, and grow past the opening pantry.",
    win = {
      rooms = {
        gate = 2
      },
      folds = 1,
      food = 4
    }
  },
  {
    id = "5-02",
    world = 5,
    name = "Island Core",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 16,
      food = 2,
      crew = 3
    },
    deposits = {},
    ice = {},
    blocked = {
      {
        x = 0,
        y = 9
      },
      {
        x = 1,
        y = 9
      },
      {
        x = 2,
        y = 9
      },
      {
        x = 3,
        y = 9
      },
      {
        x = 4,
        y = 9
      },
      {
        x = 5,
        y = 9
      },
      {
        x = 6,
        y = 9
      },
      {
        x = 7,
        y = 9
      },
      {
        x = 8,
        y = 9
      }
    },
    wells = {},
    relics = {},
    prebuilt = {
      {
        type = "gate",
        x = 4,
        y = 10,
        rot = 0,
        built = true
      },
      {
        type = "garden",
        x = 4,
        y = 11,
        rot = 0,
        built = true
      }
    },
    allowed = { "corridor", "gate" },
    mechanics = {
      wormholes = true
    },
    waves = {
      first = 9999,
      interval = 48,
      count = 0,
      max = 0
    },
    eatRate = 0,
    par = 70,
    hint = "One pad is already on the island. Pair it from the plus, then tap the garden.",
    lesson = "Some rooms will never touch. Fold is the only road.",
    briefing = "A garden island sits behind void. Pair the island pad from the plus, fold a kapsel across, and grow four meals.",
    win = {
      food = 4,
      rooms = {
        gate = 2
      },
      folds = 1
    }
  },
  {
    id = "5-03",
    world = 5,
    name = "Ambush Fold",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 24,
      food = 8,
      crew = 4
    },
    deposits = {},
    ice = {},
    blocked = {},
    wells = {},
    relics = {},
    prebuilt = {},
    allowed = { "corridor", "gate", "weapons", "garden" },
    mechanics = {
      wormholes = true
    },
    waves = {
      first = 20,
      interval = 24,
      count = function(n) return 2 + n end,
      hp = function(n) return 30 + n * 10 end,
      max = 2
    },
    eatRate = 0,
    par = 90,
    hint = "",
    lesson = "You can fold guns to a rim you never walked.",
    briefing = "Hold two waves. A gate-pair next to a weapon is a cheap turret truck.",
    win = {
      rooms = {
        gate = 2,
        weapons = 1
      },
      surviveWaves = 2
    }
  },
  {
    id = "5-04",
    world = 5,
    name = "Three Nodes",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 16,
      food = 8,
      crew = 4
    },
    deposits = {
      {
        x = 8,
        y = 11
      }
    },
    ice = {},
    blocked = {
      {
        x = 3,
        y = 0
      },
      {
        x = 3,
        y = 1
      },
      {
        x = 3,
        y = 2
      },
      {
        x = 3,
        y = 3
      },
      {
        x = 3,
        y = 4
      },
      {
        x = 5,
        y = 8
      },
      {
        x = 5,
        y = 9
      },
      {
        x = 5,
        y = 10
      },
      {
        x = 5,
        y = 11
      },
      {
        x = 5,
        y = 12
      }
    },
    wells = {},
    relics = {},
    prebuilt = {
      {
        type = "gate",
        x = 7,
        y = 11,
        rot = 0,
        built = true
      }
    },
    allowed = { "corridor", "gate", "extractor" },
    mechanics = {
      wormholes = true
    },
    waves = {
      first = 9999,
      interval = 48,
      count = 0,
      max = 0
    },
    eatRate = 0,
    par = 100,
    hint = "",
    lesson = "Any built gate talks to every other built gate.",
    briefing = "Three islands. Link them. Bank minerals from the far deposit.",
    win = {
      rooms = {
        gate = 3
      },
      mineral = 22
    }
  },
  {
    id = "5-05",
    world = 5,
    name = "Fragile Bridge",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 32,
      food = 8,
      crew = 4
    },
    deposits = {},
    ice = {},
    blocked = {
      {
        x = 4,
        y = 3
      },
      {
        x = 4,
        y = 4
      },
      {
        x = 4,
        y = 8
      },
      {
        x = 4,
        y = 9
      }
    },
    wells = {},
    relics = {
      {
        x = 1,
        y = 1
      },
      {
        x = 7,
        y = 11
      }
    },
    prebuilt = {},
    allowed = { "corridor", "gate", "weapons" },
    mechanics = {
      wormholes = true
    },
    waves = {
      first = 36,
      interval = 24,
      count = 4,
      hp = 36,
      max = 1
    },
    eatRate = 0,
    par = 95,
    hint = "",
    lesson = "A corridor spine is honest. A fold is fast and brittle.",
    briefing = "Relics sit just off two far shores. Fold or walk. Bank a gun after the survey, then hold one wave.",
    win = {
      relics = 2,
      surviveWaves = 1
    }
  },
  {
    id = "5-06",
    world = 5,
    name = "Folded War",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 28,
      food = 14,
      crew = 5
    },
    deposits = {
      {
        x = 0,
        y = 11
      }
    },
    ice = {},
    blocked = {},
    wells = {},
    relics = {},
    prebuilt = {},
    allowed = { "corridor", "gate", "weapons", "shield", "garden", "kitchen", "extractor", "quarters" },
    mechanics = {
      wormholes = true,
      kitchenChain = true,
      flares = {
        first = 24,
        interval = 18,
        damage = 11,
        telegraph = 2.6
      },
      pieceQueue = true
    },
    waves = {
      first = 26,
      interval = 24,
      count = function(n) return 1 + n end,
      hp = function(n) return 28 + n * 10 end,
      max = 2
    },
    eatRate = 0.018,
    par = 130,
    hint = "",
    lesson = "Weather, fold, and war on one small board.",
    briefing = "Two waves, flares, gates legal. Compact stations still win.",
    win = {
      surviveWaves = 2,
      rooms = {
        gate = 2
      }
    }
  },
  {
    id = "6-01",
    world = 6,
    name = "Frost",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 10,
      food = 6,
      crew = 3
    },
    deposits = {},
    ice = {
      {
        x = 4,
        y = 4
      },
      {
        x = 4,
        y = 3
      },
      {
        x = 4,
        y = 2
      }
    },
    blocked = {},
    wells = {},
    relics = {},
    prebuilt = {},
    allowed = { "corridor" },
    mechanics = {},
    waves = {
      first = 9999,
      interval = 48,
      count = 0,
      max = 0
    },
    eatRate = 0,
    par = 50,
    hint = "",
    lesson = "Ice is floor you already own, only slower.",
    briefing = "The northern arm is frozen. Cross it anyway and lay two corridors beyond the frost.",
    win = {
      corridors = 2,
      reachY = 1
    }
  },
  {
    id = "6-02",
    world = 6,
    name = "Thaw",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 18,
      food = 6,
      crew = 3
    },
    deposits = {},
    ice = {
      {
        x = 0,
        y = 0
      },
      {
        x = 1,
        y = 0
      },
      {
        x = 2,
        y = 0
      },
      {
        x = 3,
        y = 0
      },
      {
        x = 4,
        y = 0
      },
      {
        x = 5,
        y = 0
      },
      {
        x = 6,
        y = 0
      },
      {
        x = 7,
        y = 0
      },
      {
        x = 8,
        y = 0
      },
      {
        x = 0,
        y = 1
      },
      {
        x = 8,
        y = 1
      }
    },
    blocked = {},
    wells = {},
    relics = {},
    prebuilt = {},
    allowed = { "corridor", "heater" },
    mechanics = {},
    waves = {
      first = 9999,
      interval = 48,
      count = 0,
      max = 0
    },
    eatRate = 0,
    par = 80,
    hint = "The hearth thaws as soon as it is built. A plus hearth cannot reach the belt.",
    lesson = "A built hearth writes water back into the tile.",
    briefing = "Frost sits on the far rim. Walk a shore road north, then place a hearth; once it is built it radiates without a babysitter.",
    win = {
      thaw = true,
      rooms = {
        heater = 1
      }
    }
  },
  {
    id = "6-03",
    world = 6,
    name = "Slow Patrol",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 14,
      food = 8,
      crew = 4
    },
    deposits = {},
    ice = {
      {
        x = 5,
        y = 6
      },
      {
        x = 6,
        y = 6
      },
      {
        x = 7,
        y = 6
      },
      {
        x = 4,
        y = 4
      },
      {
        x = 4,
        y = 3
      }
    },
    blocked = {},
    wells = {},
    relics = {},
    prebuilt = {},
    allowed = { "corridor", "weapons", "heater", "garden" },
    mechanics = {},
    waves = {
      first = 22,
      interval = 30,
      count = 3,
      hp = 32,
      speed = 26,
      max = 1
    },
    eatRate = 0,
    par = 70,
    hint = "",
    lesson = "A gun on ice still shoots. The kapsel just arrives late.",
    briefing = "Hold one wave. Pre-assign the weapon; frost will delay anyone you send after the alarm.",
    win = {
      rooms = {
        weapons = 1
      },
      surviveWaves = 1
    }
  },
  {
    id = "6-04",
    world = 6,
    name = "Frozen Garden",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 16,
      food = 8,
      crew = 4
    },
    deposits = {},
    ice = {
      {
        x = 3,
        y = 8
      },
      {
        x = 4,
        y = 8
      },
      {
        x = 5,
        y = 8
      },
      {
        x = 4,
        y = 9
      },
      {
        x = 4,
        y = 7
      }
    },
    blocked = {},
    wells = {},
    relics = {},
    prebuilt = {},
    allowed = { "corridor", "garden", "kitchen", "heater" },
    mechanics = {
      kitchenChain = true
    },
    waves = {
      first = 9999,
      interval = 48,
      count = 0,
      max = 0
    },
    eatRate = 0.016,
    par = 90,
    hint = "",
    lesson = "You can grow on ice. You will hate the commute.",
    briefing = "Cook past the opening eight, then thaw. The galley chain is on.",
    win = {
      food = 10,
      thaw = true
    }
  },
  {
    id = "6-05",
    world = 6,
    name = "Black Ice",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 26,
      food = 10,
      crew = 4
    },
    deposits = {},
    ice = {
      {
        x = 2,
        y = 6
      },
      {
        x = 3,
        y = 6
      },
      {
        x = 5,
        y = 6
      },
      {
        x = 6,
        y = 6
      },
      {
        x = 4,
        y = 3
      },
      {
        x = 4,
        y = 2
      }
    },
    blocked = {},
    wells = {},
    relics = {},
    prebuilt = {},
    allowed = { "corridor", "heater", "shield", "weapons", "garden" },
    mechanics = {
      flares = {
        first = 18,
        interval = 16,
        damage = 12,
        telegraph = 2.5
      }
    },
    waves = {
      first = 22,
      interval = 24,
      count = 3,
      hp = 34,
      max = 1
    },
    eatRate = 0,
    par = 100,
    hint = "",
    lesson = "Flares do not thaw ice. They just hurt you while you slip.",
    briefing = "Thaw the belt, shield the pantry, hold a wave.",
    win = {
      thaw = true,
      surviveWaves = 1,
      rooms = {
        shield = 1
      }
    }
  },
  {
    id = "6-06",
    world = 6,
    name = "Icebreaker",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 28,
      food = 20,
      crew = 5
    },
    deposits = {
      {
        x = 0,
        y = 11
      }
    },
    ice = {
      {
        x = 2,
        y = 6
      },
      {
        x = 3,
        y = 6
      },
      {
        x = 5,
        y = 6
      },
      {
        x = 6,
        y = 6
      },
      {
        x = 4,
        y = 3
      },
      {
        x = 4,
        y = 4
      },
      {
        x = 4,
        y = 8
      },
      {
        x = 4,
        y = 9
      }
    },
    blocked = {},
    wells = {},
    relics = {},
    prebuilt = {},
    allowed = { "corridor", "heater", "weapons", "garden", "kitchen", "extractor", "gate", "quarters" },
    mechanics = {
      wormholes = true,
      kitchenChain = true,
      pieceQueue = true
    },
    waves = {
      first = 26,
      interval = 24,
      count = function(n) return 1 + n end,
      hp = function(n) return 28 + n * 10 end,
      max = 2
    },
    eatRate = 0.018,
    par = 130,
    hint = "",
    lesson = "The belt wants you slow when the scouts want you fast.",
    briefing = "Two waves, frost on the rim, a fold is legal if you earned it in world five. Use a heater.",
    win = {
      surviveWaves = 2,
      thaw = true
    }
  },
  {
    id = "7-01",
    world = 7,
    name = "Unseen",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 16,
      food = 8,
      crew = 4
    },
    deposits = {},
    ice = {},
    blocked = {},
    wells = {},
    relics = {},
    prebuilt = {},
    allowed = { "corridor", "scanner", "weapons" },
    mechanics = {
      cloak = true,
      cloakAll = true,
      teachScan = true
    },
    waves = {
      first = 18,
      interval = 24,
      count = 3,
      hp = 28,
      speed = 24,
      max = 1,
      cloaked = true
    },
    eatRate = 0,
    par = 80,
    hint = "After Scan is built, tap it — weapons will not lead what they cannot see.",
    lesson = "Cloaked scouts are invisible until a scanner sings, or until they bite.",
    briefing = "Build a scanner, then tap Scan. Cloaked scouts ignore guns they cannot see. Hold the first quiet wave.",
    win = {
      rooms = {
        scanner = 1,
        weapons = 1
      },
      surviveWaves = 1
    }
  },
  {
    id = "7-02",
    world = 7,
    name = "Well Trap",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 16,
      food = 8,
      crew = 4
    },
    deposits = {},
    ice = {},
    blocked = {},
    wells = {
      {
        x = 7,
        y = 6,
        strength = 70
      }
    },
    relics = {},
    prebuilt = {},
    allowed = { "corridor", "weapons", "garden" },
    mechanics = {},
    waves = {
      first = 16,
      interval = 22,
      count = 4,
      hp = 30,
      speed = 20,
      max = 1
    },
    eatRate = 0,
    par = 80,
    hint = "The well will not ask. Put the gun on the current, not on the plus.",
    lesson = "Gravity pulls scouts into a kill lane — and will not ask your permission.",
    briefing = "A well sits east. Place a gun where the current bunches bodies, then let the gravity do the herding.",
    win = {
      surviveWaves = 1,
      kills = 3,
      rooms = {
        weapons = 1
      }
    }
  },
  {
    id = "7-03",
    world = 7,
    name = "Overclock",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 8,
      food = 8,
      crew = 3
    },
    deposits = {
      {
        x = 1,
        y = 6
      }
    },
    ice = {},
    blocked = {},
    wells = {},
    relics = {},
    prebuilt = {},
    allowed = { "corridor", "extractor" },
    mechanics = {
      overload = true
    },
    waves = {
      first = 9999,
      interval = 48,
      count = 0,
      max = 0
    },
    eatRate = 0,
    par = 70,
    hint = "Select Overload, then tap a staffed extractor. Idle mining will not count as an overload.",
    lesson = "Double-tap overload on a staffed extractor. It screams, then it injures itself.",
    briefing = "Bank sixteen minerals. Pull the Over tool on a staffed extractor. Do not burn the vein to death.",
    win = {
      mineral = 16,
      overloads = 1
    }
  },
  {
    id = "7-04",
    world = 7,
    name = "Eclipse",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 22,
      food = 10,
      crew = 5
    },
    deposits = {},
    ice = {},
    blocked = {},
    wells = {},
    relics = {},
    prebuilt = {},
    allowed = { "corridor", "scanner", "shield", "weapons", "garden" },
    mechanics = {
      cloak = true,
      cloakAll = true,
      flares = {
        first = 18,
        interval = 16,
        damage = 12,
        telegraph = 2.4
      }
    },
    waves = {
      first = 18,
      interval = 22,
      count = 4,
      hp = 32,
      max = 1,
      cloaked = true
    },
    eatRate = 0,
    par = 90,
    hint = "Scan sees. Aegis covers. Gun shoots what Scan reveals.",
    lesson = "Cloak plus flare. See, cover, shoot.",
    briefing = "Scanner, then Aegis, then a gun. One wave in bad light. Cover before the star inhales.",
    win = {
      surviveWaves = 1,
      rooms = {
        scanner = 1,
        shield = 1
      }
    }
  },
  {
    id = "7-05",
    world = 7,
    name = "All Hands",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 28,
      food = 14,
      crew = 5
    },
    deposits = {
      {
        x = 0,
        y = 1
      }
    },
    ice = {
      {
        x = 4,
        y = 4
      },
      {
        x = 4,
        y = 3
      },
      {
        x = 5,
        y = 6
      }
    },
    blocked = {},
    wells = {
      {
        x = 2,
        y = 10,
        strength = 55
      }
    },
    relics = {},
    prebuilt = {},
    allowed = { "corridor", "scanner", "weapons", "garden", "shield", "heater", "gate", "kitchen", "extractor", "quarters" },
    mechanics = {
      cloak = true,
      cloakAll = true,
      wormholes = true,
      kitchenChain = true,
      overload = true,
      pieceQueue = true
    },
    waves = {
      first = 26,
      interval = 24,
      count = function(n) return 2 + n end,
      hp = function(n) return 28 + n * 10 end,
      max = 2,
      cloaked = true
    },
    eatRate = 0.016,
    par = 140,
    hint = "",
    lesson = "Every toy on one board. Spend attention, not tiles.",
    briefing = "Well, frost, fold, cloak. Two waves. Leave with the pantry still yellow.",
    win = {
      surviveWaves = 2,
      food = 4
    }
  },
  {
    id = "7-06",
    world = 7,
    name = "Last Geometry",
    cols = 9,
    rows = 13,
    core = {
      x = 4,
      y = 6
    },
    start = {
      minerals = 36,
      food = 18,
      crew = 6
    },
    deposits = {
      {
        x = 1,
        y = 6
      },
      {
        x = 7,
        y = 6
      }
    },
    ice = {
      {
        x = 4,
        y = 2
      },
      {
        x = 4,
        y = 10
      }
    },
    blocked = {},
    wells = {
      {
        x = 7,
        y = 5,
        strength = 36
      }
    },
    relics = {
      {
        x = 2,
        y = 3
      },
      {
        x = 6,
        y = 3
      },
      {
        x = 2,
        y = 9
      },
      {
        x = 6,
        y = 9
      }
    },
    prebuilt = {},
    allowed = { "corridor", "scanner", "weapons", "shield", "garden", "kitchen", "extractor" },
    mechanics = {
      cloak = true,
      cloakAll = true,
      wormholes = true,
      kitchenChain = true,
      overload = true,
      flares = {
        first = 28,
        interval = 20,
        damage = 9,
        telegraph = 2.8
      },
      pieceQueue = true,
      thinkStart = true,
      coach = true
    },
    waves = {
      first = 40,
      interval = 24,
      count = function(n) return math.min(4, 1 + n) end,
      hp = function(n) return 24 + n * 7 end,
      speed = 20,
      max = 4,
      cloaked = true
    },
    eatRate = 0.012,
    par = 200,
    hint = "Scan first. Then Gun. Then Aegis. Food before monuments. Never keep two unpaid blueprints.",
    lesson = "Scan, then Gun, then Aegis. Garden and kitchen before monuments.",
    briefing = "Time holds while you place the hull kit. Scan sees cloaks, Gun shoots, Aegis eats flares. Plant a garden and kitchen before you kiss relics — monuments do not feed anyone. Two dashed rooms starve construction. Four waves. TAP GO when the geometry feels right.",
    win = {
      relics = 4,
      surviveWaves = 4
    }
  }
}

function M.levelById(id)
  for _, level in ipairs(M.LEVELS) do
    if level.id == id then return level end
  end
  return nil
end

function M.levelsInWorld(world)
  local out = {}
  for _, level in ipairs(M.LEVELS) do
    if level.world == world then out[#out + 1] = level end
  end
  return out
end

function M.nextLevel(id)
  for i, level in ipairs(M.LEVELS) do
    if level.id == id then return M.LEVELS[i + 1] end
  end
  return nil
end

return M

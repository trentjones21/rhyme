// Pure simulation for Rhyme. No DOM. Deterministic when seeded.

export const PIECES = {
  I: [
    [0, 0],
    [1, 0],
    [2, 0],
    [3, 0],
  ],
  O: [
    [0, 0],
    [1, 0],
    [0, 1],
    [1, 1],
  ],
  T: [
    [0, 0],
    [-1, 0],
    [1, 0],
    [0, 1],
  ],
  L: [
    [0, 0],
    [0, 1],
    [0, 2],
    [1, 2],
  ],
  J: [
    [0, 0],
    [0, 1],
    [0, 2],
    [-1, 2],
  ],
  S: [
    [0, 0],
    [1, 0],
    [0, 1],
    [-1, 1],
  ],
  Z: [
    [0, 0],
    [-1, 0],
    [0, 1],
    [1, 1],
  ],
};

const BAG_ORDER = ["I", "O", "T", "L", "J", "S", "Z"];

const CHIP_LABELS = {
  wait: "Wait",
  haul: "Haul",
  build: "Build",
  grow: "Grow",
  mine: "Mine",
  cook: "Cook",
  berth: "Berth",
  gun: "Gun",
  heat: "Heat",
  scan: "Scan",
  walk: "Walk",
};

function chipId(k) {
  const j = k.job;
  if (!j) return k.carry ? "haul" : "wait";
  if (j.kind === "haul") return "haul";
  if (j.kind === "build") return "build";
  if (j.kind === "produce") return j.target && j.target.type === "extractor" ? "mine" : "grow";
  if (j.kind === "cook") return "cook";
  if (j.kind === "recruit") return "berth";
  if (j.kind === "staff") {
    if (j.target && j.target.type === "heater") return "heat";
    if (j.target && j.target.type === "scanner") return "scan";
    return "gun";
  }
  if (j.kind === "idlewalk") return "walk";
  return k.carry ? "haul" : "wait";
}

export function jobChips(match) {
  const counts = new Map();
  for (const k of match.kapsels) {
    const id = chipId(k);
    counts.set(id, (counts.get(id) || 0) + 1);
  }
  return Object.keys(CHIP_LABELS)
    .filter((id) => counts.get(id))
    .map((id) => ({ id, n: counts.get(id), label: CHIP_LABELS[id] }));
}

export function playerShape(match, type) {
  if (match.mechanics && match.mechanics.pieceQueue && match.piece && PIECES[match.piece]) {
    return PIECES[match.piece];
  }
  return SHAPES[type] || SHAPES.corridor;
}

export function fitPiece(name, size = 4) {
  const cells = PIECES[name] || [];
  if (!cells.length) return [];
  let minX = Infinity;
  let minY = Infinity;
  let maxX = -Infinity;
  let maxY = -Infinity;
  for (const [x, y] of cells) {
    minX = Math.min(minX, x);
    minY = Math.min(minY, y);
    maxX = Math.max(maxX, x);
    maxY = Math.max(maxY, y);
  }
  const ox = Math.floor((size - (maxX - minX + 1)) / 2) - minX;
  const oy = Math.floor((size - (maxY - minY + 1)) / 2) - minY;
  return cells.map(([x, y]) => [x + ox, y + oy]);
}

export const SHAPES = {
  corridor: [[0, 0]],
  weapons: [[0, 0]],
  gate: [[0, 0]],
  heater: [[0, 0]],
  scanner: [[0, 0]],
  beacon: [[0, 0]],
  garden: [
    [0, 0],
    [1, 0],
    [-1, 0],
    [0, 1],
  ],
  extractor: [
    [0, 0],
    [0, 1],
    [0, 2],
    [1, 2],
  ],
  kitchen: [
    [0, 0],
    [1, 0],
    [0, 1],
    [1, 1],
  ],
  quarters: [
    [0, 0],
    [1, 0],
    [1, 1],
    [2, 1],
  ],
  shield: [
    [0, 0],
    [1, 0],
    [0, 1],
    [1, 1],
  ],
};

export const ROOMS = {
  corridor: { name: "Corridor", cost: 1, hp: 22, hue: "#8d6b4a" },
  garden: { name: "Garden", cost: 4, hp: 44, hue: "#5ea86a" },
  extractor: { name: "Extractor", cost: 4, hp: 44, hue: "#d56b8c" },
  weapons: { name: "Weapons", cost: 6, hp: 70, hue: "#7b88a3" },
  kitchen: { name: "Kitchen", cost: 4, hp: 44, hue: "#d4b14a" },
  quarters: { name: "Quarters", cost: 5, hp: 52, hue: "#d4844a" },
  shield: { name: "Shield", cost: 6, hp: 60, hue: "#6ec3c9" },
  gate: { name: "Gate", cost: 3, hp: 36, hue: "#9b7ad4" },
  heater: { name: "Heater", cost: 3, hp: 36, hue: "#e07a4a" },
  scanner: { name: "Scanner", cost: 4, hp: 40, hue: "#70b4e0" },
  beacon: { name: "Beacon", cost: 5, hp: 48, hue: "#e8d9a0" },
  core: { name: "Core", cost: 0, hp: 300, hue: "#3c445c" },
};

const BUILD_SEC = 0.55;
const PICK_SEC = 0.18;
const FOOD_SEC = 2.6;
const MINERAL_SEC = 3.2;
const COOK_SEC = 1.6;
const RECRUIT_SEC = 3.4;
const MEALS_PER_BIO = 3;
const MEALS_PER_RECRUIT = 3;
const RECRUITS_PER_Q = 2;
const STOCK_CAP = 8;
const PANTRY_CAP = 24;
const CORE_MINERAL_CAP = 36;
export const TURRET_RANGE = 250;
const TURRET_CD = 1.05;
const TURRET_DMG = 12;
export const SHIELD_R = 4.2;
const HEATER_R = 3.3;
export const SCAN_R = 200;
const OVERCLOCK_SEC = 5;
const OVERCLOCK_HURT = 9;

export function gunRange(match) {
  return Math.max(TURRET_RANGE, match.layout.cell * 7.4);
}

export function scanRange(match) {
  return Math.max(SCAN_R, match.layout.cell * 6.4);
}

export function rotateShape(cells, turns) {
  let out = cells.map(([x, y]) => [x, y]);
  const n = ((turns % 4) + 4) % 4;
  for (let i = 0; i < n; i++) out = out.map(([x, y]) => [-y, x]);
  return out;
}

function key(x, y) {
  return x + "," + y;
}

function makeRng(seed) {
  let s = (seed >>> 0) || 1;
  return () => {
    s = (Math.imul(s, 1664525) + 1013904223) >>> 0;
    return s / 4294967296;
  };
}

function clamp(v, a, b) {
  return Math.max(a, Math.min(b, v));
}

function dist(ax, ay, bx, by) {
  return Math.hypot(ax - bx, ay - by);
}

export function remapLayout(match, layout) {
  const old = match.layout;
  const map = (x, y) => ({
    x: layout.ox + ((x - old.ox) / old.cell) * layout.cell,
    y: layout.oy + ((y - old.oy) / old.cell) * layout.cell,
  });
  for (const k of match.kapsels) {
    const p = map(k.x, k.y);
    k.x = p.x;
    k.y = p.y;
  }
  for (const e of match.enemies) {
    const p = map(e.x, e.y);
    e.x = p.x;
    e.y = p.y;
  }
  for (const s of match.shots) {
    const p = map(s.x, s.y);
    s.x = p.x;
    s.y = p.y;
  }
  match.layout = layout;
  for (const room of match.rooms) roomCenter(match, room);
}

export function computeLayout(vw, vh, cols, rows, insets = {}) {
  const padL = insets.left || 16;
  const padR = insets.right || 16;
  const top = insets.top || 118;
  const bottom = insets.bottom || 210;
  const availW = Math.max(120, vw - padL - padR);
  const availH = Math.max(160, vh - top - bottom);
  const cell = Math.floor(Math.min(availW / cols, availH / rows, 44));
  const gridW = cols * cell;
  const gridH = rows * cell;
  return {
    cell,
    ox: Math.floor((vw - gridW) / 2),
    oy: top + Math.floor((availH - gridH) / 2),
    gridW,
    gridH,
    width: vw,
    height: vh,
    top,
    bottom,
  };
}

function defaultLayout(cols, rows) {
  return computeLayout(390, 844, cols, rows, { top: 72, bottom: 200, left: 16, right: 16 });
}

function cellsOf(type, x, y, rot, shape) {
  return rotateShape(shape || SHAPES[type] || SHAPES.corridor, rot).map(([dx, dy]) => ({
    x: x + dx,
    y: y + dy,
  }));
}

function footprint(match, type, x, y, rot) {
  const cells = cellsOf(type, x, y, rot, playerShape(match, type));
  for (const c of cells) {
    if (c.x < 0 || c.y < 0 || c.x >= match.cols || c.y >= match.rows) return null;
    if (match.blocked.has(key(c.x, c.y))) return null;
    if (match.deposits.has(key(c.x, c.y))) return null;
    if (match.relicCells && match.relicCells.has(key(c.x, c.y))) return null;
    if (match.grid.has(key(c.x, c.y))) return null;
  }
  return cells;
}

function touchesStation(match, cells) {
  const dirs = [
    [1, 0],
    [-1, 0],
    [0, 1],
    [0, -1],
  ];
  for (const c of cells) {
    for (const [dx, dy] of dirs) {
      if (match.grid.has(key(c.x + dx, c.y + dy))) return true;
    }
  }
  return false;
}

function nearDeposit(match, cells) {
  const dirs = [
    [0, 0],
    [1, 0],
    [-1, 0],
    [0, 1],
    [0, -1],
  ];
  for (const c of cells) {
    for (const [dx, dy] of dirs) {
      if (match.deposits.has(key(c.x + dx, c.y + dy))) return true;
    }
  }
  return false;
}

function roomCenter(match, room) {
  let sx = 0;
  let sy = 0;
  for (const c of room.cells) {
    sx += c.x;
    sy += c.y;
  }
  const n = room.cells.length;
  room.cx = match.layout.ox + ((sx / n) + 0.5) * match.layout.cell;
  room.cy = match.layout.oy + ((sy / n) + 0.5) * match.layout.cell;
}

function pixelCenter(match, x, y) {
  return {
    x: match.layout.ox + (x + 0.5) * match.layout.cell,
    y: match.layout.oy + (y + 0.5) * match.layout.cell,
  };
}

export function roomAt(match, x, y) {
  const cell = match.grid.get(key(x, y));
  return cell ? cell.room : null;
}

export function coreStock(match, resource) {
  return match.core.stock[resource] || 0;
}

export function staffed(match, room) {
  let n = 0;
  for (const k of match.kapsels) {
    if (k.assignment === room.id && kapselInRoom(match, k, room)) n += 1;
  }
  return n;
}

function kapselInRoom(match, k, room) {
  const g = atPixel(match, k.x, k.y);
  return room.cells.some((c) => c.x === g.x && c.y === g.y);
}

function atPixel(match, px, py) {
  return {
    x: Math.floor((px - match.layout.ox) / match.layout.cell),
    y: Math.floor((py - match.layout.oy) / match.layout.cell),
  };
}

function walkable(match, x, y) {
  const cell = match.grid.get(key(x, y));
  return !!(cell && cell.room.built && !cell.room.dead);
}

function iceAt(match, x, y) {
  return match.ice.has(key(x, y));
}

function gateCells(match) {
  const cells = [];
  for (const room of match.rooms) {
    if (room.type === "gate" && room.built && !room.dead) {
      for (const c of room.cells) cells.push(c);
    }
  }
  return cells;
}

function neighborsOf(match, x, y) {
  const out = [];
  const dirs = [
    [1, 0],
    [-1, 0],
    [0, 1],
    [0, -1],
  ];
  for (const [dx, dy] of dirs) {
    const nx = x + dx;
    const ny = y + dy;
    if (walkable(match, nx, ny)) out.push({ x: nx, y: ny });
  }
  const here = roomAt(match, x, y);
  if (here && here.type === "gate" && here.built) {
    for (const g of gateCells(match)) {
      if (g.x === x && g.y === y) continue;
      out.push({ x: g.x, y: g.y });
    }
  }
  return out;
}

function path(match, sx, sy, tx, ty) {
  if (!walkable(match, sx, sy) || !walkable(match, tx, ty)) return null;
  if (sx === tx && sy === ty) return [];
  const q = [[sx, sy]];
  let head = 0;
  const prev = new Map();
  prev.set(key(sx, sy), false);
  while (head < q.length) {
    const [cx, cy] = q[head++];
    for (const n of neighborsOf(match, cx, cy)) {
      const k = key(n.x, n.y);
      if (prev.has(k)) continue;
      prev.set(k, [cx, cy]);
      if (n.x === tx && n.y === ty) {
        const route = [];
        let x = tx;
        let y = ty;
        while (prev.get(key(x, y))) {
          route.unshift({ x, y });
          const p = prev.get(key(x, y));
          x = p[0];
          y = p[1];
        }
        return route;
      }
      q.push([n.x, n.y]);
    }
  }
  return null;
}

export function pathLength(match, sx, sy, tx, ty) {
  const p = path(match, sx, sy, tx, ty);
  return p ? p.length : Infinity;
}

function routeToRoom(match, sx, sy, room) {
  if (!room || room.dead) return null;
  let best = null;
  const consider = (x, y) => {
    const p = path(match, sx, sy, x, y);
    if (p && (!best || p.length < best.length)) best = p;
  };
  for (const c of room.cells) {
    if (room.built) consider(c.x, c.y);
    else {
      consider(c.x - 1, c.y);
      consider(c.x + 1, c.y);
      consider(c.x, c.y - 1);
      consider(c.x, c.y + 1);
    }
  }
  return best;
}

function change(t, k, n) {
  t[k] = Math.max(0, (t[k] || 0) + n);
}

function capacity(match, room, resource) {
  if (room.dead || (room.type !== "core" && !room.built && resource !== "mineral")) return 0;
  if (room.type === "core") {
    if (resource === "food") return PANTRY_CAP;
    if (resource === "mineral") return CORE_MINERAL_CAP;
    if (resource === "biomass") return STOCK_CAP;
    return 0;
  }
  if (!room.built) return resource === "mineral" ? Math.max(0, room.def.cost - room.materials) : 0;
  if (room.type === "garden" && (resource === "food" || resource === "biomass")) return STOCK_CAP;
  if (room.type === "extractor" && resource === "mineral") return STOCK_CAP;
  if (room.type === "kitchen") {
    if (resource === "biomass") return 4;
    if (resource === "food") return STOCK_CAP + MEALS_PER_BIO;
  }
  if (room.type === "quarters" && resource === "food" && room.recruited < RECRUITS_PER_Q) {
    return MEALS_PER_RECRUIT;
  }
  return 0;
}

function available(room, resource) {
  if (room.dead || !room.built) return 0;
  return Math.max(0, (room.stock[resource] || 0) - (room.outgoing[resource] || 0));
}

function need(match, room, resource) {
  if (room.dead) return 0;
  const incoming = room.incoming[resource] || 0;
  if (!room.built) {
    return resource === "mineral" ? Math.max(0, room.def.cost - room.materials - incoming) : 0;
  }
  return Math.max(0, capacity(match, room, resource) - (room.stock[resource] || 0) - incoming);
}

function addStock(room, resource, amount) {
  if (room.dead) return;
  if (!room.built && resource === "mineral") room.materials += amount;
  else room.stock[resource] = (room.stock[resource] || 0) + amount;
}

function extractorValid(match, room) {
  return nearDeposit(match, room.cells);
}

function shielded(match, room) {
  if (room.type === "shield") return true;
  for (const s of match.rooms) {
    if (s.type !== "shield" || !s.built || s.dead) continue;
    const dx = (s.cx - room.cx) / match.layout.cell;
    const dy = (s.cy - room.cy) / match.layout.cell;
    if (Math.hypot(dx, dy) <= SHIELD_R) return true;
  }
  return false;
}

function attachMethods(match) {
  match.walkable = (x, y) => walkable(match, x, y);
  match.iceAt = (x, y) => iceAt(match, x, y);
  match.ghostCells = () => {
    if (!ROOMS[match.tool] || match.tool === "core") return [];
    return rotateShape(playerShape(match, match.tool), match.rot);
  };
}

function makeRoom(match, type, x, y, rot, instant, shape) {
  const def = ROOMS[type];
  const cells = cellsOf(type, x, y, rot, shape);
  const cost = shape && match.mechanics.pieceQueue ? cells.length : def.cost;
  const room = {
    id: match.nextId++,
    type,
    def: { name: def.name, cost, hp: def.hp, hue: def.hue },
    x,
    y,
    rot,
    cells,
    hp: def.hp,
    maxhp: def.hp,
    dead: false,
    hit: 0,
    built: instant === true,
    materials: instant ? cost : 0,
    progress: instant ? 1 : 0,
    production: 0,
    recruited: 0,
    cooldown: 0,
    aim: -Math.PI / 2,
    overclock: 0,
    stunned: 0,
    stock: {},
    incoming: {},
    outgoing: {},
    busy: {},
    cx: 0,
    cy: 0,
  };
  for (const c of cells) {
    const cell = { x: c.x, y: c.y, room };
    match.grid.set(key(c.x, c.y), cell);
  }
  match.rooms.push(room);
  roomCenter(match, room);
  return room;
}

function spawnKapsel(match, room) {
  const cells = (room || match.core).cells;
  const c = cells[Math.floor(match.rng() * cells.length)];
  const p = pixelCenter(match, c.x, c.y);
  const k = {
    id: match.nextId++,
    x: p.x,
    y: p.y,
    speed: 62 + match.rng() * 14,
    bob: match.rng() * Math.PI * 2,
    state: "idle",
    label: "Waiting",
    assignment: null,
    job: null,
    path: null,
    carry: null,
    workTimer: 0,
    retry: 0,
  };
  match.kapsels.push(k);
  return k;
}

function shuffleBag(rng) {
  const bag = BAG_ORDER.slice();
  for (let i = bag.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    const tmp = bag[i];
    bag[i] = bag[j];
    bag[j] = tmp;
  }
  return bag;
}

export function pieceHasLanding(match) {
  if (!match.piece || !PIECES[match.piece]) return false;
  const types = (match.level.allowed || ["corridor"]).filter((t) => ROOMS[t] && t !== "core");
  match._scanLanding = true;
  try {
    for (const type of types) {
      for (let rot = 0; rot < 4; rot++) {
        for (let y = 0; y < match.rows; y++) {
          for (let x = 0; x < match.cols; x++) {
            if (canPlace(match, type, x, y, rot)) return true;
          }
        }
      }
    }
    return false;
  } finally {
    match._scanLanding = false;
  }
}

function dealPiece(match) {
  if (!match.bag) match.bag = [];
  for (let n = 0; n < 14; n++) {
    if (match.bag.length < 4) match.bag.push(...shuffleBag(match.rng));
    match.piece = match.bag.shift();
    match.queue = match.bag.slice(0, 3);
    if (pieceHasLanding(match)) return;
  }
}

export function holdPiece(match) {
  if (!match.mechanics || !match.mechanics.pieceQueue) return false;
  if (!match.piece) return false;
  const cur = match.piece;
  if (match.held) {
    match.piece = match.held;
    match.held = cur;
    match.queue = (match.bag || []).slice(0, 3);
  } else {
    match.held = cur;
    dealPiece(match);
  }
  match.events.push({ type: "hold" });
  match.pulse = 0.12;
  return true;
}

function emitFx(match, kind, x, y, hue) {
  const life =
    kind === "muzzle"
      ? 0.22
      : kind === "spark"
        ? 0.9
        : kind === "pulse"
          ? 0.55
          : kind === "burst"
            ? 0.42
            : kind === "kiss"
              ? 1.15
              : 0.7;
  match.fx.push({ kind, x, y, t: 0, life, hue: hue || "#f3f0e8" });
}

function gardenResource(match) {
  if (!match.mechanics.kitchenChain) return "food";
  const kitchen = match.rooms.find((r) => r.type === "kitchen" && r.built && !r.dead);
  if (kitchen && staffed(match, kitchen) >= 1) return "biomass";
  return "food";
}

function kitchenCooking(match) {
  const kitchen = match.rooms.find((r) => r.type === "kitchen" && r.built && !r.dead);
  return !!(kitchen && staffed(match, kitchen) >= 1);
}

function placePrebuilt(match, spec) {
  const type = spec.type;
  const rot = spec.rot || 0;
  const cells = cellsOf(type, spec.x, spec.y, rot);
  for (const c of cells) {
    if (c.x < 0 || c.y < 0 || c.x >= match.cols || c.y >= match.rows) return null;
    if (match.grid.has(key(c.x, c.y))) return null;
  }
  const room = makeRoom(match, type, spec.x, spec.y, rot, spec.built !== false);
  if (spec.stock) Object.assign(room.stock, spec.stock);
  return room;
}

export function createMatch(level, opts = {}) {
  const cols = level.cols || 9;
  const rows = level.rows || 13;
  const layout = opts.layout || defaultLayout(cols, rows);
  const match = {
    levelId: level.id,
    level,
    name: level.name,
    status: "playing",
    loseReason: "",
    winReason: "",
    time: 0,
    cols,
    rows,
    layout,
    rng: makeRng(opts.seed ?? level.seed ?? 1),
    nextId: 1,
    grid: new Map(),
    rooms: [],
    kapsels: [],
    enemies: [],
    shots: [],
    fx: [],
    floats: [],
    core: null,
    tool: "assign",
    rot: 0,
    selected: null,
    hover: null,
    deposits: new Set((level.deposits || []).map((d) => key(d.x, d.y))),
    ice: new Set((level.ice || []).map((d) => key(d.x, d.y))),
    blocked: new Set((level.blocked || []).map((d) => key(d.x, d.y))),
    wells: (level.wells || []).map((w) => ({ ...w })),
    relics: (level.relics || []).map((r) => ({ ...r, linked: false })),
    relicCells: new Set((level.relics || []).map((d) => key(d.x, d.y))),
    mechanics: { kitchenChain: false, wormholes: false, cloak: false, overload: false, ...(level.mechanics || {}) },
    thinkLocked: !!(level.mechanics && level.mechanics.thinkStart),
    waves: {
      index: 0,
      timer: (level.waves && level.waves.first) || 9999,
      interval: (level.waves && level.waves.interval) || 48,
      spec: level.waves || { first: 9999, interval: 48, count: 0 },
      incoming: false,
      warned: false,
    },
    wavesCleared: 0,
    hadEnemies: false,
    kills: 0,
    shotsFired: 0,
    deaths: 0,
    flare: null,
    starve: 0,
    shake: 0,
    pulse: 0,
    eatRate: level.eatRate ?? 0.028,
    win: level.win || {},
    stars: 0,
    hint: level.hint || "",
    events: [],
    bag: [],
    piece: null,
    held: null,
    queue: [],
    tutorial: { needAssign: false, assigned: false, staffed: false, roomId: null },
  };

  const cx = (level.core && level.core.x) || Math.floor(cols / 2);
  const cy = (level.core && level.core.y) || Math.floor(rows / 2);
  const core = {
    id: match.nextId++,
    type: "core",
    def: { name: "Core", cost: 0, hp: ROOMS.core.hp, hue: ROOMS.core.hue },
    x: cx,
    y: cy,
    rot: 0,
    cells: [
      { x: cx, y: cy },
      { x: cx - 1, y: cy },
      { x: cx + 1, y: cy },
      { x: cx, y: cy - 1 },
      { x: cx, y: cy + 1 },
    ],
    hp: (level.core && level.core.hp) || ROOMS.core.hp,
    maxhp: (level.core && level.core.hp) || ROOMS.core.hp,
    dead: false,
    hit: 0,
    built: true,
    materials: 0,
    progress: 1,
    production: 0,
    recruited: 0,
    cooldown: 0,
    aim: 0,
    overclock: 0,
    stunned: 0,
    stock: {
      mineral: (level.start && level.start.minerals) || 0,
      food: (level.start && level.start.food) || 0,
    },
    incoming: {},
    outgoing: {},
    busy: {},
    cx: 0,
    cy: 0,
  };
  for (const c of core.cells) match.grid.set(key(c.x, c.y), { x: c.x, y: c.y, room: core });
  match.rooms.push(core);
  match.core = core;
  roomCenter(match, core);

  for (const spec of level.prebuilt || []) placePrebuilt(match, spec);

  const crew = (level.start && level.start.crew) || 2;
  for (let i = 0; i < crew; i++) spawnKapsel(match);

  if (match.mechanics.flares) {
    const f = match.mechanics.flares;
    match.flare = { timer: f.first, telegraph: f.telegraph || 2.4, warning: 0, damage: f.damage, interval: f.interval };
  }

  if (match.mechanics.pieceQueue) dealPiece(match);
  if (match.mechanics.teachAssign) {
    match.tutorial = { needAssign: false, assigned: false, staffed: false, roomId: null };
  } else if (match.mechanics.teachStaff) {
    match.tutorial = { needAssign: false, assigned: true, staffed: false, roomId: null };
  } else {
    match.tutorial.assigned = true;
    match.tutorial.staffed = true;
  }

  attachMethods(match);
  return match;
}

export function setTool(match, tool) {
  match.tool = tool;
  if (tool !== "assign" && tool !== "salvage") match.selected = null;
}

export function rotate(match) {
  match.rot = (match.rot + 1) % 4;
}

export function canPlace(match, type, x, y, rot = match.rot) {
  if (match.tutorial && match.tutorial.needAssign && !match._scanLanding) return false;
  if (!ROOMS[type] || type === "core") return false;
  if (match.level.allowed && match.level.allowed.indexOf(type) < 0) return false;
  const cells = footprint(match, type, x, y, rot);
  if (!cells) return false;
  if (type === "extractor" && !nearDeposit(match, cells)) return false;
  if (type === "gate" && !match.mechanics.wormholes) return false;
  const gates = match.rooms.filter((r) => r.type === "gate").length;
  if (type === "gate" && gates >= 1) return true;
  if (!touchesStation(match, cells)) return false;
  return true;
}

function reconcileClaims(match) {
  for (const room of match.rooms) {
    room.incoming = {};
    room.outgoing = {};
    room.busy = {};
  }
  for (const k of match.kapsels) {
    const j = k.job;
    if (!j || !j.target) continue;
    if (j.kind === "haul") {
      if (j.source && !j.picked) change(j.source.outgoing, j.resource, 1);
      change(j.target.incoming, j.resource, 1);
    } else {
      if (j.kind && j.kind !== "wait" && j.kind !== "staff" && j.kind !== "produce" && j.kind !== "idlewalk") {
        j.target.busy[j.kind] = true;
      }
      if (j.resource) change(j.target.outgoing, j.resource, j.amount || 1);
      if (j.kind === "cook") change(j.target.incoming, "food", MEALS_PER_BIO);
    }
  }
}

function tryPlace(match, type, x, y) {
  if (!canPlace(match, type, x, y, match.rot)) return false;
  const shape = playerShape(match, type);
  const room = makeRoom(match, type, x, y, match.rot, false, shape);
  if (match.mechanics.pieceQueue) dealPiece(match);
  emitFx(match, "spark", room.cx, room.cy, room.def.hue);
  if (match.mechanics.teachAssign && match.tutorial && !match.tutorial.assigned) {
    match.tutorial.needAssign = true;
    match.tutorial.roomId = room.id;
    match.tool = "assign";
  } else {
    assignTo(match, room);
  }
  match.events.push({ type: "place", x, y });
  match.pulse = 0.18;
  return true;
}

function nearestKapsel(match, room, assignedToThis = false) {
  let best = null;
  let bestD = Infinity;
  for (const k of match.kapsels) {
    if (assignedToThis && k.assignment === room.id) continue;
    if (!assignedToThis && k.assignment === room.id) continue;
    const d = dist(k.x, k.y, room.cx, room.cy);
    if (d < bestD) {
      best = k;
      bestD = d;
    }
  }
  return best;
}

export function assignTo(match, room) {
  if (!room || room.dead) return false;
  if (room.type === "core") return false;
  if (room.built && (room.type === "corridor" || room.type === "gate")) return false;
  if (match.tutorial && match.tutorial.needAssign && match.tutorial.roomId != null && room.id !== match.tutorial.roomId) {
    return false;
  }
  const idle = match.kapsels.find((k) => k.assignment == null) || match.kapsels.find((k) => k.assignment === match.core.id);
  const k = idle || nearestKapsel(match, room, true);
  if (!k) return false;
  if (!(k.job && k.job.kind === "haul" && k.carry)) release(k);
  k.assignment = room.id;
  k.retry = 0;
  match.selected = room.id;
  match.events.push({ type: "assign", room: room.id });
  if (match.tutorial && match.tutorial.needAssign) {
    match.tutorial.needAssign = false;
    match.tutorial.assigned = true;
    match.tutorial.staffed = true;
  }
  return true;
}

function recallOne(match, room) {
  const k = match.kapsels.find((w) => w.assignment === room.id);
  if (!k) return false;
  release(k);
  k.assignment = null;
  return true;
}

export function recall(match) {
  const room = match.rooms.find((r) => r.id === match.selected);
  if (room && room.type !== "core") return recallOne(match, room);
  const k = match.kapsels.find((w) => w.assignment && w.assignment !== match.core.id);
  if (!k) return false;
  release(k);
  k.assignment = null;
  return true;
}

export function overloadRoom(match, room) {
  if (!match.mechanics.overload) return false;
  if (!room || (room.type !== "extractor" && room.type !== "garden")) return false;
  if (staffed(match, room) < 1) return false;
  if (room.overclock > 0 || room.stunned > 0) return false;
  room.overclock = OVERCLOCK_SEC;
  match.events.push({ type: "overload", room: room.id });
  return true;
}

export function tapCell(match, gx, gy) {
  if (match.status !== "playing") return false;
  if (gx < 0 || gy < 0 || gx >= match.cols || gy >= match.rows) return false;
  const room = roomAt(match, gx, gy);
  if (match.tool === "assign") {
    if (!room) return false;
    if (match.selected === room.id && staffed(match, room) + match.kapsels.filter((k) => k.assignment === room.id).length > 0) {
      // second mode: extra tap still assigns more, unless it's core (recall)
      if (room.type === "core") return recallOne(match, match.rooms.find((r) => r.id === match.selected) || room);
    }
    return assignTo(match, room);
  }
  if (match.tool === "salvage") {
    if (!room || room.type === "core") return false;
    salvage(match, room);
    return true;
  }
  if (match.tool === "overload") {
    if (!room) return false;
    return overloadRoom(match, room);
  }
  return tryPlace(match, match.tool, gx, gy);
}

function salvage(match, room) {
  const salvageAmt = room.built ? Math.floor(room.def.cost / 2) : room.materials;
  addStock(match.core, "mineral", salvageAmt + (room.stock.mineral || 0));
  addStock(match.core, "food", room.stock.food || 0);
  removeRoom(match, room);
  match.events.push({ type: "salvage" });
}

function removeRoom(match, room) {
  if (room.dead) return;
  room.dead = true;
  for (const c of room.cells) match.grid.delete(key(c.x, c.y));
  match.rooms = match.rooms.filter((r) => r !== room);
  for (const k of match.kapsels) {
    if (k.assignment === room.id) k.assignment = null;
    if (k.job && k.job.target === room) release(k);
  }
}

function release(k) {
  const j = k.job;
  if (j) {
    if (j.kind === "haul") {
      if (j.source && !j.picked) change(j.source.outgoing, j.resource, -1);
      change(j.target.incoming, j.resource, -1);
    } else if (j.target) {
      if (j.kind) j.target.busy[j.kind] = null;
      if (j.resource) change(j.target.outgoing, j.resource, -(j.amount || 1));
      if (j.kind === "cook") change(j.target.incoming, "food", -MEALS_PER_BIO);
    }
  }
  k.job = null;
  k.path = null;
  k.state = "idle";
  k.label = k.carry ? "Carrying" : "Waiting";
}

function assignedRoom(match, k) {
  if (k.assignment == null) return null;
  return match.rooms.find((r) => r.id === k.assignment) || null;
}

function findHaul(match, k, resource, target) {
  if (need(match, target, resource) < 1) return null;
  for (const source of match.rooms) {
    if (source === target) continue;
    if (source.type === "quarters" && resource === "food") continue;
    if (source.type === "kitchen" && resource === "biomass") continue;
    const reserve = source.type === "core" && resource === "food" && target.type === "quarters" ? 0 : 0;
    if (available(source, resource) >= 1 + reserve) {
      const from = atPixel(match, k.x, k.y);
      const pickup = routeToRoom(match, from.x, from.y, source);
      if (!pickup) continue;
      const end = pickup.length ? pickup[pickup.length - 1] : from;
      const drop = routeToRoom(match, end.x, end.y, target);
      if (drop) {
        return { kind: "haul", source, target, resource, picked: false, phase: "pickup", path: pickup };
      }
    }
  }
  return null;
}

function startJob(k, job) {
  k.job = job;
  k.path = job.path || [];
  k.state = k.path.length ? "walking" : "working";
  k.workTimer = 0;
  if (job.kind === "haul") {
    if (job.source && !job.picked) change(job.source.outgoing, job.resource, 1);
    change(job.target.incoming, job.resource, 1);
    k.label = job.picked ? "Delivering" : "Collecting";
  } else {
    if (job.kind) job.target.busy[job.kind] = true;
    if (job.resource) change(job.target.outgoing, job.resource, job.amount || 1);
    if (job.kind === "cook") change(job.target.incoming, "food", MEALS_PER_BIO);
    k.label = job.kind || "Working";
  }
}

function chooseJob(match, k) {
  const room = assignedRoom(match, k);
  const from = atPixel(match, k.x, k.y);
  if (k.carry) {
    const target = room && need(match, room, k.carry) >= 1 ? room : match.core;
    const p = routeToRoom(match, from.x, from.y, target);
    if (!p) return null;
    return { kind: "haul", source: null, target, resource: k.carry, picked: true, phase: "delivery", path: p };
  }
  if (!room) {
    const p = routeToRoom(match, from.x, from.y, match.core);
    if (p && p.length) return { kind: "idlewalk", target: match.core, path: p };
    return null;
  }

  if (!room.built) {
    const haul = findHaul(match, k, "mineral", room);
    if (haul) return haul;
    if (room.materials >= room.def.cost && !room.busy.build) {
      const p = routeToRoom(match, from.x, from.y, room);
      if (p) return { kind: "build", target: room, path: p };
    }
    const wait = routeToRoom(match, from.x, from.y, room);
    if (wait) return { kind: "wait", target: room, path: wait };
    return null;
  }

  if (room.type === "garden") {
    const res = gardenResource(match);
    const dest = res === "biomass"
      ? match.rooms.find((r) => r.type === "kitchen" && r.built && need(match, r, "biomass") >= 1) || match.core
      : match.core;
    if (available(room, res) >= 1 && need(match, dest, res) >= 1) {
      const haul = findHaul(match, k, res, dest);
      if (haul) return haul;
    }
    const p = routeToRoom(match, from.x, from.y, room);
    if (p) return { kind: "produce", target: room, path: p };
  }

  if (room.type === "extractor") {
    if (available(room, "mineral") >= 1 && need(match, match.core, "mineral") >= 1) {
      const haul = findHaul(match, k, "mineral", match.core);
      if (haul) return haul;
    }
    const p = routeToRoom(match, from.x, from.y, room);
    if (p) return { kind: "produce", target: room, path: p };
  }

  if (room.type === "kitchen") {
    if (available(room, "food") >= 1 && need(match, match.core, "food") >= 1) {
      const haul = findHaul(match, k, "food", match.core);
      if (haul) return haul;
    }
    if (!room.busy.cook && available(room, "biomass") >= 1 && need(match, room, "food") >= MEALS_PER_BIO) {
      const p = routeToRoom(match, from.x, from.y, room);
      if (p) return { kind: "cook", target: room, resource: "biomass", amount: 1, path: p };
    }
    if (need(match, room, "biomass") >= 1) {
      const haul = findHaul(match, k, "biomass", room);
      if (haul) return haul;
    }
    const p = routeToRoom(match, from.x, from.y, room);
    if (p) return { kind: "wait", target: room, path: p };
  }

  if (room.type === "quarters") {
    if (!room.busy.recruit && room.recruited < RECRUITS_PER_Q && available(room, "food") >= MEALS_PER_RECRUIT) {
      const p = routeToRoom(match, from.x, from.y, room);
      if (p) return { kind: "recruit", target: room, resource: "food", amount: MEALS_PER_RECRUIT, path: p };
    }
    if (need(match, room, "food") >= 1) {
      const haul = findHaul(match, k, "food", room);
      if (haul) return haul;
    }
    const p = routeToRoom(match, from.x, from.y, room);
    if (p) return { kind: "wait", target: room, path: p };
  }

  if (room.type === "weapons" || room.type === "heater" || room.type === "scanner" || room.type === "beacon") {
    const p = routeToRoom(match, from.x, from.y, room);
    if (p) return { kind: "staff", target: room, path: p };
  }

  if (room.built && (room.type === "corridor" || room.type === "gate" || room.type === "shield")) {
    k.assignment = null;
    const home = routeToRoom(match, from.x, from.y, match.core);
    if (home && home.length) return { kind: "idlewalk", target: match.core, path: home };
    return null;
  }

  const p = routeToRoom(match, from.x, from.y, room);
  if (p) return { kind: "wait", target: room, path: p };
  return null;
}

function stepAlong(match, k, dt) {
  const node = k.path && k.path[0];
  if (!node) return true;
  const p = pixelCenter(match, node.x, node.y);
  const dx = p.x - k.x;
  const dy = p.y - k.y;
  const d = Math.hypot(dx, dy);
  let speed = k.speed;
  const g = atPixel(match, k.x, k.y);
  if (iceAt(match, g.x, g.y)) speed *= 0.38;
  const step = speed * dt;
  if (d <= step) {
    k.x = p.x;
    k.y = p.y;
    k.path.shift();
    return k.path.length === 0;
  }
  k.x += (dx / d) * step;
  k.y += (dy / d) * step;
  return false;
}

function produceRate(room) {
  let mul = 1;
  if (room.overclock > 0) mul = 2.4;
  if (room.stunned > 0) mul = 0;
  return mul;
}

function work(match, k, dt) {
  const j = k.job;
  if (!j) return;
  const room = j.target;
  k.workTimer += dt;
  if (j.kind === "haul") {
    if (k.workTimer < PICK_SEC) return;
    if (j.phase === "pickup") {
      if ((j.source.stock[j.resource] || 0) < 1) {
        release(k);
        return;
      }
      change(j.source.stock, j.resource, -1);
      change(j.source.outgoing, j.resource, -1);
      j.picked = true;
      k.carry = j.resource;
      j.phase = "delivery";
      const from = atPixel(match, k.x, k.y);
      k.path = routeToRoom(match, from.x, from.y, room) || [];
      k.state = "walking";
      k.label = "Delivering";
      k.workTimer = 0;
    } else {
      addStock(room, j.resource, 1);
      k.carry = null;
      match.events.push({ type: "haul", resource: j.resource });
      emitFx(match, "dust", room.cx, room.cy, j.resource === "mineral" ? "#e07898" : "#f0c24a");
      release(k);
    }
  } else if (j.kind === "build") {
    room.progress = Math.min(1, room.progress + dt / (BUILD_SEC * Math.max(1, room.def.cost)));
        if (room.progress >= 1) {
          room.built = true;
          roomCenter(match, room);
          match.events.push({ type: "built", room: room.id });
          emitFx(match, "dust", room.cx, room.cy, room.def.hue);
          if (room.type === "corridor" || room.type === "gate") k.assignment = null;
          if (match.mechanics.teachStaff && match.tutorial && !match.tutorial.staffed && room.type === "garden") {
            for (const w of match.kapsels) {
              if (w.assignment === room.id) {
                release(w);
                w.assignment = null;
              }
            }
            match.tutorial.needAssign = true;
            match.tutorial.roomId = room.id;
            match.tool = "assign";
          }
          release(k);
        }
  } else if (j.kind === "wait") {
    if (k.workTimer > 0.35) release(k);
  } else if (j.kind === "produce") {
    if (room.stunned > 0) return;
    const resource = room.type === "extractor" ? "mineral" : gardenResource(match);
    const dest = resource === "biomass"
      ? match.rooms.find((r) => r.type === "kitchen" && r.built && !r.dead) || match.core
      : match.core;
    if (available(room, resource) >= 1 && dest && need(match, dest, resource) >= 1) {
      release(k);
      return;
    }
    if (room.type === "extractor" && !extractorValid(match, room)) return;
    const duration = resource === "mineral" ? MINERAL_SEC : FOOD_SEC;
    room.production += dt * produceRate(room);
    if (room.production >= duration && need(match, room, resource) >= 1) {
      addStock(room, resource, 1);
      room.production -= duration;
      match.floats.push({ x: room.cx, y: room.cy, text: "+", life: 0.7, t: 0, color: resource });
      const hue = resource === "mineral" ? "#e07898" : "#5ea86a";
      emitFx(match, "dust", room.cx, room.cy, hue);
      emitFx(match, "pulse", room.cx, room.cy, hue);
      match.events.push({ type: resource === "mineral" ? "mine" : "grow" });
      release(k);
    }
  } else if (j.kind === "cook") {
    if (k.workTimer >= COOK_SEC) {
      change(room.stock, "biomass", -1);
      addStock(room, "food", MEALS_PER_BIO);
      match.events.push({ type: "cook" });
      emitFx(match, "pulse", room.cx, room.cy, "#f0c24a");
      release(k);
    }
  } else if (j.kind === "recruit") {
    if (k.workTimer >= RECRUIT_SEC) {
      spawnKapsel(match, room);
      change(room.stock, "food", -MEALS_PER_RECRUIT);
      room.recruited += 1;
      match.events.push({ type: "recruit" });
      release(k);
    }
  }
}

function validJob(match, k) {
  const j = k.job;
  if (!j) return false;
  if (j.target && j.target.dead) return false;
  if (j.kind === "haul" && !j.picked && j.source && j.source.dead) return false;
  if (j.kind === "build" && j.target.built) return false;
  for (const n of j.path || []) {
    if (!walkable(match, n.x, n.y)) return false;
  }
  return true;
}

function loseKapsel(match, index, reason) {
  const k = match.kapsels[index];
  release(k);
  if (k.carry) addStock(match.core, k.carry, 1);
  match.kapsels.splice(index, 1);
  match.deaths += 1;
  match.loseReason = reason;
  match.events.push({ type: "death" });
  match.shake = 0.25;
}

function updateKapsels(match, dt) {
  reconcileClaims(match);
  for (let i = match.kapsels.length - 1; i >= 0; i--) {
    const k = match.kapsels[i];
    k.bob += dt * 8;
    const g = atPixel(match, k.x, k.y);
    if (!walkable(match, g.x, g.y)) {
      let best = null;
      let bestD = Infinity;
      for (const [kk, cell] of match.grid) {
        if (!cell.room.built) continue;
        const p = pixelCenter(match, cell.x, cell.y);
        const d = Math.abs(p.x - k.x) + Math.abs(p.y - k.y);
        if (d <= match.layout.cell * 1.15 && d < bestD) {
          best = cell;
          bestD = d;
        }
      }
      release(k);
      if (best) {
        const p = pixelCenter(match, best.x, best.y);
        k.x = p.x;
        k.y = p.y;
      } else {
        loseKapsel(match, i, "Your crew was lost with the station");
        continue;
      }
    }
    if (k.job && !validJob(match, k)) release(k);
    if (!k.job) {
      k.retry -= dt;
      if (k.retry <= 0) {
        const job = chooseJob(match, k);
        if (job) startJob(k, job);
        else k.retry = 0.28;
      }
    } else if (k.state === "walking") {
      if (stepAlong(match, k, dt)) {
        k.state = "working";
        k.workTimer = 0;
      }
    } else {
      work(match, k, dt);
    }
  }
}

function waveCount(spec, n) {
  if (typeof spec.count === "function") return spec.count(n);
  if (spec.count == null) return 1 + n;
  return spec.count;
}

function spawnWave(match) {
  const spec = match.waves.spec;
  match.waves.index += 1;
  const n = match.waves.index;
  const count = waveCount(spec, n);
  const hp = typeof spec.hp === "function" ? spec.hp(n) : spec.hp || 22 + n * 14;
  const speed = spec.speed != null ? spec.speed : Math.min(48, 18 + n * 1.7);
  const sides = spec.sides || ["n", "s", "e", "w"];
  const cloak = !!match.mechanics.cloak && (spec.cloak || n >= (spec.cloakFrom || 99) || match.mechanics.cloakAll);
  for (let i = 0; i < count; i++) {
    const side = sides[Math.floor(match.rng() * sides.length)];
    let x;
    let y;
    const L = match.layout;
    if (side === "n") {
      x = L.ox + match.rng() * L.gridW;
      y = L.oy - 28;
    } else if (side === "s") {
      x = L.ox + match.rng() * L.gridW;
      y = L.oy + L.gridH + 28;
    } else if (side === "w") {
      x = L.ox - 28;
      y = L.oy + match.rng() * L.gridH;
    } else {
      x = L.ox + L.gridW + 28;
      y = L.oy + match.rng() * L.gridH;
    }
    match.enemies.push({
      x,
      y,
      hp,
      maxhp: hp,
      speed: speed + match.rng() * 5,
      dps: spec.dps || 4.2 + n * 0.7,
      r: 8,
      cloaked: cloak || !!spec.cloaked,
      vx: 0,
      vy: 0,
      dir: 0,
      target: null,
      state: "walking",
      hitTimer: 0,
      wobble: match.rng() * Math.PI * 2,
    });
  }
  match.events.push({ type: "wave", n });
  match.pulse = 0.4;
}

function nearestCell(match, px, py) {
  let best = null;
  let bestD = Infinity;
  for (const [, cell] of match.grid) {
    const p = pixelCenter(match, cell.x, cell.y);
    const d = dist(p.x, p.y, px, py);
    if (d < bestD) {
      best = cell;
      bestD = d;
    }
  }
  return best;
}

function applyGravity(match, e, dt) {
  for (const well of match.wells) {
    const p = pixelCenter(match, well.x, well.y);
    const dx = p.x - e.x;
    const dy = p.y - e.y;
    const d = Math.hypot(dx, dy) || 1;
    const str = well.strength || 40;
    e.vx += (dx / d) * str * dt;
    e.vy += (dy / d) * str * dt;
  }
  e.x += e.vx * dt;
  e.y += e.vy * dt;
  e.vx *= 0.98;
  e.vy *= 0.98;
}

function updateEnemies(match, dt) {
  match.waves.timer -= dt;
  if (
    !match.waves.warned &&
    match.waves.timer <= 8 &&
    match.waves.timer > 0 &&
    match.waves.timer < 900 &&
    match.status === "playing"
  ) {
    const spec = match.waves.spec;
    const maxW = spec.max || spec.until || 99;
    if (match.waves.index < maxW && waveCount(spec, match.waves.index + 1) > 0) {
      match.waves.warned = true;
      match.events.push({ type: "incoming", n: match.waves.index + 1 });
    }
  }
  if (match.waves.timer <= 0 && match.status === "playing") {
    const spec = match.waves.spec;
    const maxW = spec.max || spec.until || 99;
    if (match.waves.index < maxW && waveCount(spec, match.waves.index + 1) > 0) {
      spawnWave(match);
      match.waves.timer = match.waves.interval;
      match.waves.warned = false;
    } else {
      match.waves.timer = 9999;
    }
  }

  for (let i = match.enemies.length - 1; i >= 0; i--) {
    const e = match.enemies[i];
    e.wobble += dt * 3;
    e.hitTimer = Math.max(0, (e.hitTimer || 0) - dt);
    applyGravity(match, e, dt);
    if (!e.target || !e.target.room || e.target.room.dead || !match.grid.get(key(e.target.x, e.target.y))) {
      e.target = nearestCell(match, e.x, e.y);
      e.state = "walking";
    }
    if (e.target) {
      const p = pixelCenter(match, e.target.x, e.target.y);
      const dx = p.x - e.x;
      const dy = p.y - e.y;
      const d = Math.hypot(dx, dy) || 1;
      if (e.state === "walking") {
        if (d < 4) e.state = "attacking";
        else {
          e.x += (dx / d) * e.speed * dt;
          e.y += (dy / d) * e.speed * dt;
          e.dir = Math.atan2(dy, dx);
        }
      }
      if (e.state === "attacking") {
        const room = e.target.room;
        if (!room || room.dead) e.target = null;
        else {
          e.cloaked = false;
          room.hp -= e.dps * dt;
          room.hit = 0.16;
          if (room.hp <= 0) {
            match.shake = 0.4;
            match.events.push({ type: "destroy", room: room.type });
            if (room.type === "core") {
              room.dead = true;
              match.status = "lost";
              match.loseReason = "The core came apart";
            } else removeRoom(match, room);
            e.target = null;
          }
        }
      }
    }
    if (e.hp <= 0) {
      match.kills += 1;
      emitFx(match, "burst", e.x, e.y, "#e24b52");
      emitFx(match, "pulse", e.x, e.y, "#f3f0e8");
      match.pulse = Math.max(match.pulse, 0.28);
      match.shake = Math.max(match.shake, 0.18);
      match.enemies.splice(i, 1);
      match.events.push({ type: "kill" });
    }
  }

  for (const room of match.rooms) {
    if (room.type !== "weapons" || !room.built || room.dead) continue;
    if (staffed(match, room) < 1) continue;
    room.cooldown -= dt;
    if (room.cooldown > 0) continue;
    let best = null;
    let bestD = Infinity;
    for (const e of match.enemies) {
      if (e.cloaked) continue;
      const d = dist(e.x, e.y, room.cx, room.cy);
      if (d < gunRange(match) && d < bestD) {
        best = e;
        bestD = d;
      }
    }
    if (best) {
      room.cooldown = TURRET_CD;
      room.aim = Math.atan2(best.y - room.cy, best.x - room.cx);
      match.shots.push({ x: room.cx, y: room.cy, target: best, speed: 340 });
      match.shotsFired += 1;
      match.pulse = Math.max(match.pulse, 0.16);
      emitFx(match, "muzzle", room.cx, room.cy, "#f8f4e8");
      match.events.push({ type: "shoot" });
    }
  }

  for (let i = match.shots.length - 1; i >= 0; i--) {
    const s = match.shots[i];
    const e = s.target;
    if (!e || e.hp <= 0 || match.enemies.indexOf(e) < 0) {
      match.shots.splice(i, 1);
      continue;
    }
    const dx = e.x - s.x;
    const dy = e.y - s.y;
    const d = Math.hypot(dx, dy) || 1;
    const step = s.speed * dt;
    if (d <= step + e.r) {
      e.hp -= TURRET_DMG;
      e.hitTimer = 0.2;
      emitFx(match, "spark", e.x, e.y, "#f3f0e8");
      match.shots.splice(i, 1);
    } else {
      s.x += (dx / d) * step;
      s.y += (dy / d) * step;
    }
  }

  if (match.enemies.length > 0) match.hadEnemies = true;
  else if (match.hadEnemies) {
    match.hadEnemies = false;
    match.wavesCleared = match.waves.index;
    match.events.push({ type: "cleared" });
  }
}

function updateHeaters(match, dt) {
  for (const room of match.rooms) {
    if (room.type !== "heater" || !room.built || room.dead) continue;
    for (const iceKey of [...match.ice]) {
      const [x, y] = iceKey.split(",").map(Number);
      const warm = room.cells.some((c) => Math.hypot(x - c.x, y - c.y) <= HEATER_R);
      if (warm) match.ice.delete(iceKey);
    }
  }
}

function updateScanners(match) {
  for (const room of match.rooms) {
    if (room.type !== "scanner" || !room.built || room.dead) continue;
    if (staffed(match, room) < 1) continue;
    for (const e of match.enemies) {
      if (dist(e.x, e.y, room.cx, room.cy) <= scanRange(match)) e.cloaked = false;
    }
  }
}

function updateFlares(match, dt) {
  const f = match.flare;
  if (!f) return;
  f.timer -= dt;
  if (f.telegraph > 0 && f.timer <= f.telegraph && f.timer > 0) f.warning = 1 - f.timer / f.telegraph;
  else f.warning = 0;
  if (f.timer <= 0) {
    for (const room of match.rooms) {
      if (room.dead || !room.built) continue;
      if (shielded(match, room)) continue;
      room.hp -= f.damage;
      room.hit = 0.35;
      if (room.hp <= 0) {
        if (room.type === "core") {
          match.status = "lost";
          match.loseReason = "A flare unstitched the core";
          room.dead = true;
        } else removeRoom(match, room);
      }
    }
    match.events.push({ type: "flare" });
    match.shake = 0.35;
    f.timer = f.interval;
    f.warning = 0;
  }
}

function updateOverclock(match, dt) {
  for (const room of match.rooms) {
    if (room.overclock > 0) {
      room.overclock -= dt;
      if (room.overclock <= 0) {
        room.overclock = 0;
        room.hp -= OVERCLOCK_HURT;
        room.stunned = 3.2;
        room.hit = 0.4;
        if (room.hp <= 0) removeRoom(match, room);
      }
    }
    if (room.stunned > 0) room.stunned -= dt;
    if (room.hit > 0) room.hit = Math.max(0, room.hit - dt);
  }
}

function updateRelics(match) {
  for (const relic of match.relics) {
    if (relic.linked) continue;
    const dirs = [
      [0, 0],
      [1, 0],
      [-1, 0],
      [0, 1],
      [0, -1],
    ];
    for (const [dx, dy] of dirs) {
      const cell = match.grid.get(key(relic.x + dx, relic.y + dy));
      if (cell && cell.room.built) {
        const from = match.core.cells[0];
        if (path(match, from.x, from.y, cell.x, cell.y)) {
          relic.linked = true;
          match.events.push({ type: "relic" });
          const px = match.layout.ox + (relic.x + 0.5) * match.layout.cell;
          const py = match.layout.oy + (relic.y + 0.5) * match.layout.cell;
          emitFx(match, "kiss", px, py, "#e8d9a0");
          emitFx(match, "pulse", px, py, "#e8d9a0");
          match.pulse = Math.max(match.pulse, 0.4);
          match.floats.push({ x: px, y: py, text: "★", life: 0.9, t: 0, color: "food" });
          break;
        }
      }
    }
  }
}

function beaconActive(match) {
  const b = match.rooms.find((r) => r.type === "beacon" && r.built && !r.dead);
  return !!(b && staffed(match, b) >= 1);
}

function checkWin(match) {
  const w = match.win;
  if (!w || Object.keys(w).length === 0) return false;
  if (w.corridors != null && match.rooms.filter((r) => r.type === "corridor" && r.built && !r.dead).length < w.corridors) return false;
  if (w.food != null && coreStock(match, "food") < w.food) return false;
  if (w.mineral != null && coreStock(match, "mineral") < w.mineral) return false;
  if (w.crew != null && match.kapsels.length < w.crew) return false;
  if (w.surviveWaves != null && !(match.wavesCleared >= w.surviveWaves && match.enemies.length === 0)) return false;
  if (w.kills != null && match.kills < w.kills) return false;
  if (w.rooms) {
    for (const [type, n] of Object.entries(w.rooms)) {
      const have = match.rooms.filter((r) => r.type === type && r.built && !r.dead).length;
      if (have < n) return false;
    }
  }
  if (w.relics != null && match.relics.filter((r) => r.linked).length < w.relics) return false;
  if (w.beacon && !beaconActive(match)) return false;
  if (w.thaw && match.ice.size > 0) return false;
  return true;
}

function scoreStars(match) {
  let s = 1;
  if (match.core.hp / match.core.maxhp >= 0.55) s = 2;
  if (match.deaths === 0 && match.core.hp / match.core.maxhp >= 0.8) s = 3;
  if (match.level.par && match.time <= match.level.par) s = Math.max(s, 2);
  match.stars = s;
}

function cookRations(match, dt) {
  if (kitchenCooking(match)) return;
  if ((match.core.stock.biomass || 0) < 1) return;
  match.rationCook = (match.rationCook || 0) + dt;
  const sec = 1.2;
  while (
    match.rationCook >= sec &&
    (match.core.stock.biomass || 0) >= 1 &&
    need(match, match.core, "food") >= 1
  ) {
    match.rationCook -= sec;
    change(match.core.stock, "biomass", -1);
    addStock(match.core, "food", MEALS_PER_BIO);
    match.events.push({ type: "cook" });
    emitFx(match, "pulse", match.core.cx, match.core.cy, "#f0c24a");
    match.floats.push({ x: match.core.cx, y: match.core.cy, text: "+", life: 0.7, t: 0, color: "food" });
  }
}

function eat(match, dt) {
  if (match.eatRate <= 0) return;
  cookRations(match, dt);
  const n = match.kapsels.length;
  match.core.stock.food = Math.max(0, (match.core.stock.food || 0) - match.eatRate * n * dt);
  if ((match.core.stock.food || 0) <= 0) {
    cookRations(match, 0);
    if ((match.core.stock.food || 0) > 0) {
      match.starve = Math.max(0, match.starve - dt * 2);
      return;
    }
    match.starve += dt;
    if (match.starve >= 9 && match.kapsels.length) {
      match.starve = 0;
      loseKapsel(match, Math.floor(match.rng() * match.kapsels.length), "Your crew starved");
    }
  } else match.starve = Math.max(0, match.starve - dt * 2);
}

export function step(match, dt) {
  dt = Math.min(dt, 0.05);
  if (match.status === "paused") return;
  if (match.status === "won" || match.status === "lost") {
    match.shake = Math.max(0, match.shake - dt);
    return;
  }
  if (match.thinkLocked) {
    match.shake = Math.max(0, match.shake - dt);
    match.pulse = Math.max(0, match.pulse - dt);
    for (let i = match.fx.length - 1; i >= 0; i--) {
      match.fx[i].t += dt;
      if (match.fx[i].t >= match.fx[i].life) match.fx.splice(i, 1);
    }
    return;
  }
  match.time += dt;
  match.shake = Math.max(0, match.shake - dt);
  match.pulse = Math.max(0, match.pulse - dt);
  updateKapsels(match, dt);
  updateEnemies(match, dt);
  updateHeaters(match, dt);
  updateScanners(match);
  updateFlares(match, dt);
  updateOverclock(match, dt);
  updateRelics(match);
  eat(match, dt);
  for (let i = match.floats.length - 1; i >= 0; i--) {
    match.floats[i].t += dt;
    if (match.floats[i].t >= match.floats[i].life) match.floats.splice(i, 1);
  }
  for (let i = match.fx.length - 1; i >= 0; i--) {
    match.fx[i].t += dt;
    if (match.fx[i].t >= match.fx[i].life) match.fx.splice(i, 1);
  }
  if (match.core.dead || match.kapsels.length === 0) {
    match.status = "lost";
    match.loseReason = match.loseReason || (match.kapsels.length === 0 ? "No kapsels remain" : "The core came apart");
    return;
  }
  if (checkWin(match)) {
    match.status = "won";
    match.winReason = "Station stable";
    scoreStars(match);
    match.events.push({ type: "win" });
  }
  match.events = match.events.slice(-12);
}

export function pause(match) {
  if (match.status === "playing") match.status = "paused";
  else if (match.status === "paused") match.status = "playing";
}

export function resumeThink(match) {
  if (!match.thinkLocked) return false;
  match.thinkLocked = false;
  match.pulse = 0.4;
  match.events.push({ type: "go" });
  return true;
}

function unpaidCount(match) {
  return match.rooms.filter((r) => !r.built && r.type !== "core").length;
}

function hasJob(match, type) {
  return match.rooms.some((r) => r.type === type && !r.dead);
}

export function coachText(match) {
  if (!match) return "";
  if (!(match.mechanics && match.mechanics.coach)) {
    return match.hint || (match.level && match.level.lesson) || "";
  }
  const jam = unpaidCount(match) >= 2;
  const idleN = match.kapsels.filter((k) => !k.assignment || k.assignment === match.core.id).length;
  if (jam && !match.thinkLocked && idleN < 1) {
    return "Recall a gunner. Dashed rooms need haulers.";
  }
  if (jam && !match.thinkLocked) {
    return "Two unpaid blueprints jam the hull. Let haulers finish one.";
  }
  if (!hasJob(match, "scanner")) {
    return "Scan first. Cloaked scouts ignore guns they cannot see.";
  }
  if (!hasJob(match, "weapons")) {
    return "Staff a Gun on the hull before the first wave.";
  }
  if (!hasJob(match, "shield")) {
    return "Aegis before the star. Flares cook an empty scanner.";
  }
  if (jam) {
    return "Two unpaid blueprints jam the hull. Let haulers finish one.";
  }
  if (match.thinkLocked) {
    return "Hull kit down. TAP GO when the geometry feels right.";
  }
  const needRelics = (match.win && match.win.relics) || 0;
  const linked = match.relics.filter((r) => r.linked).length;
  if (needRelics && linked < needRelics && match.mechanics.kitchenChain) {
    const garden = hasJob(match, "garden");
    const kitchenOk = !((match.level.allowed || []).includes("kitchen")) || hasJob(match, "kitchen");
    if (!garden || !kitchenOk) {
      return "Garden and kitchen before monuments. Relics do not feed anyone.";
    }
  }
  if (needRelics && linked < needRelics) {
    return "Kiss the four monuments. One I off the plus. Two dashed rooms is a jam.";
  }
  const needWaves = (match.win && match.win.surviveWaves) || 0;
  if (needWaves && match.wavesCleared < needWaves) {
    return "Hold the hull. Scan sees, Gun shoots, Aegis eats the star.";
  }
  return "Quiet geometry. Finish the survey.";
}

function scoreNearCoreCells(match, cells) {
  const plus = match.core.cells;
  let min = Infinity;
  let kiss = 0;
  for (const cell of cells) {
    for (const p of plus) {
      const man = Math.abs(cell.x - p.x) + Math.abs(cell.y - p.y);
      min = Math.min(min, man);
      if (man <= 1) kiss += 1;
    }
  }
  return kiss * 50 - min;
}

function scoreTowardSpots(cells, spots) {
  let min = Infinity;
  for (const s of spots) {
    for (const c of cells) {
      min = Math.min(min, Math.abs(c.x - s.x) + Math.abs(c.y - s.y));
    }
  }
  return -min;
}

function cellsFor(match, type, x, y, rot) {
  return rotateShape(playerShape(match, type), rot).map(([dx, dy]) => ({ x: x + dx, y: y + dy }));
}

function placeBest(match, type, scoreFn) {
  setTool(match, type);
  let best = null;
  const saved = match.rot;
  for (let rot = 0; rot < 4; rot++) {
    match.rot = rot;
    for (let y = 0; y < match.rows; y++) {
      for (let x = 0; x < match.cols; x++) {
        if (!canPlace(match, type, x, y, rot)) continue;
        const sc = scoreFn(match, cellsFor(match, type, x, y, rot));
        if (!best || sc > best.sc) best = { x, y, rot, sc };
      }
    }
  }
  match.rot = saved;
  if (!best) return false;
  match.rot = best.rot;
  return tapCell(match, best.x, best.y);
}

function idleKapsels(match) {
  return match.kapsels.filter((k) => !k.assignment || k.assignment === match.core.id);
}

function assignedCount(match, room) {
  return match.kapsels.filter((k) => k.assignment === room.id).length;
}

function keepHaulers(match) {
  const haulersWanted = unpaidCount(match) > 0 ? 2 : 1;
  let guard = 0;
  while (idleKapsels(match).length < haulersWanted && guard++ < 12) {
    const over = match.rooms
      .filter((r) => r.type !== "core" && assignedCount(match, r) > 1)
      .sort((a, b) => assignedCount(match, b) - assignedCount(match, a))[0];
    if (!over) break;
    match.selected = over.id;
    if (!recall(match)) break;
  }
}

function staffJobs(match, order) {
  const haulersWanted = unpaidCount(match) > 0 ? 2 : 1;
  for (const type of order) {
    if (idleKapsels(match).length <= haulersWanted) break;
    const room = match.rooms.find((r) => r.type === type && !r.dead);
    if (!room) continue;
    if (assignedCount(match, room) < 1) assignTo(match, room);
  }
}

function staffFinale(match) {
  setTool(match, "assign");
  keepHaulers(match);
  const order = ["scanner", "weapons", "shield", "heater", "garden", "kitchen", "extractor", "gate"];
  staffJobs(match, order);
}

export function thumbBeat(match) {
  if (!match || match.status !== "playing") return false;
  if (match.thinkLocked) return false;
  setTool(match, "assign");
  keepHaulers(match);
  staffJobs(match, ["scanner", "weapons", "shield", "heater", "garden", "kitchen"]);
  if (unpaidCount(match) >= 2 || coreStock(match, "mineral") < 4) return false;
  const allowed = new Set((match.level && match.level.allowed) || []);
  const need = match.win || {};
  if (allowed.has("garden") && !hasJob(match, "garden")) return placeBest(match, "garden", scoreNearCoreCells);
  if (match.mechanics.kitchenChain && allowed.has("kitchen") && !hasJob(match, "kitchen")) {
    return placeBest(match, "kitchen", scoreNearCoreCells);
  }
  if (need.relics && match.relics.filter((r) => r.linked).length < need.relics) {
    const spots = match.relics.filter((r) => !r.linked);
    if (placeBest(match, "corridor", (_, cells) => scoreTowardSpots(cells, spots))) return true;
  }
  const guns = match.rooms.filter((r) => r.type === "weapons" && !r.dead).length;
  if (allowed.has("weapons") && match.enemies.length >= 3 && guns < 2) {
    return placeBest(match, "weapons", scoreNearCoreCells);
  }
  return false;
}

export function captainBeat(match) {
  if (!match || match.status !== "playing") return false;
  const allowed = new Set((match.level && match.level.allowed) || []);
  const need = match.win || {};
  if (match.thinkLocked) {
    if (allowed.has("scanner") && !hasJob(match, "scanner")) return placeBest(match, "scanner", scoreNearCoreCells);
    if (allowed.has("weapons") && !hasJob(match, "weapons")) return placeBest(match, "weapons", scoreNearCoreCells);
    if (allowed.has("shield") && !hasJob(match, "shield") && (need.rooms?.shield || match.mechanics.flares)) {
      return placeBest(match, "shield", scoreNearCoreCells);
    }
    return resumeThink(match);
  }
  staffFinale(match);
  if (unpaidCount(match) >= 2 || coreStock(match, "mineral") < 4) return false;
  if (allowed.has("scanner") && !hasJob(match, "scanner")) return placeBest(match, "scanner", scoreNearCoreCells);
  const guns = match.rooms.filter((r) => r.type === "weapons" && !r.dead).length;
  if (allowed.has("weapons") && guns < (match.enemies.length >= 3 ? 2 : 1)) {
    return placeBest(match, "weapons", scoreNearCoreCells);
  }
  if (allowed.has("shield") && !hasJob(match, "shield") && (need.rooms?.shield || match.mechanics.flares)) {
    return placeBest(match, "shield", scoreNearCoreCells);
  }
  if (allowed.has("garden") && !hasJob(match, "garden")) return placeBest(match, "garden", scoreNearCoreCells);
  if (match.mechanics.kitchenChain && allowed.has("kitchen") && !hasJob(match, "kitchen")) {
    return placeBest(match, "kitchen", scoreNearCoreCells);
  }
  if (need.relics && match.relics.filter((r) => r.linked).length < need.relics) {
    const spots = match.relics.filter((r) => !r.linked);
    if (placeBest(match, "corridor", (_, cells) => scoreTowardSpots(cells, spots))) return true;
  }
  if (need.thaw && allowed.has("heater") && match.ice.size > 0) {
    const heaters = match.rooms.filter((r) => r.type === "heater" && !r.dead).length;
    if (heaters < 2) {
      const ice = [...match.ice].map((k) => {
        const [x, y] = k.split(",").map(Number);
        return { x, y };
      });
      return placeBest(match, "heater", (_, cells) => scoreTowardSpots(cells, ice));
    }
  }
  if (need.rooms?.gate && match.rooms.filter((r) => r.type === "gate" && !r.dead).length < need.rooms.gate) {
    return placeBest(match, "gate", scoreNearCoreCells);
  }
  if (coreStock(match, "mineral") < 10 && allowed.has("extractor") && !hasJob(match, "extractor")) {
    const deposits = [...match.deposits].map((k) => {
      const [x, y] = k.split(",").map(Number);
      return { x, y };
    });
    return placeBest(match, "extractor", (_, cells) =>
      deposits.length ? scoreTowardSpots(cells, deposits) : scoreNearCoreCells(match, cells)
    );
  }
  return false;
}

export function gridAt(match, px, py) {
  return atPixel(match, px, py);
}

export function objectiveText(match) {
  const w = match.win || {};
  const parts = [];
  if (w.corridors != null) {
    const n = match.rooms.filter((r) => r.type === "corridor" && r.built).length;
    parts.push(`Corridors ${n}/${w.corridors}`);
  }
  if (w.food != null) parts.push(`Pantry ${Math.floor(coreStock(match, "food"))}/${w.food}`);
  if (w.mineral != null) parts.push(`Minerals ${Math.floor(coreStock(match, "mineral"))}/${w.mineral}`);
  if (w.crew != null) parts.push(`Crew ${match.kapsels.length}/${w.crew}`);
  if (w.surviveWaves != null) parts.push(`Waves ${match.wavesCleared}/${w.surviveWaves}`);
  if (w.rooms) {
    for (const [type, n] of Object.entries(w.rooms)) {
      const have = match.rooms.filter((r) => r.type === type && r.built).length;
      parts.push(`${ROOMS[type].name} ${have}/${n}`);
    }
  }
  if (w.relics != null) parts.push(`Relics ${match.relics.filter((r) => r.linked).length}/${w.relics}`);
  if (w.beacon) parts.push(beaconActive(match) ? "Beacon live" : "Staff the beacon");
  if (w.thaw) parts.push(match.ice.size ? `Thaw ${match.ice.size}` : "Ice clear");
  if (w.kills != null) parts.push(`Kills ${match.kills}/${w.kills}`);
  return parts.join("  ·  ") || "Hold the station";
}

export function paletteFor(level) {
  const allowed = level.allowed || ["corridor", "garden", "extractor", "weapons", "quarters"];
  const tools = ["assign", ...allowed];
  if (level.mechanics && level.mechanics.overload) tools.push("overload");
  tools.push("salvage");
  return tools;
}

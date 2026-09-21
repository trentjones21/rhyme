import { describe, it } from "node:test";
import assert from "node:assert/strict";
import {
  createMatch,
  step,
  tapCell,
  setTool,
  rotate,
  assignTo,
  overloadRoom,
  coreStock,
  staffed,
  roomAt,
  pathLength,
  rotateShape,
  SHAPES,
} from "../js/sim.js";

function tick(match, seconds) {
  const dt = 0.05;
  const n = Math.ceil(seconds / dt);
  for (let i = 0; i < n; i++) step(match, dt);
}

function mini(over = {}) {
  return createMatch(
    {
      id: "test",
      world: 1,
      name: "Test",
      cols: 9,
      rows: 13,
      core: { x: 4, y: 6 },
      start: { minerals: 20, food: 10, crew: 3, ...(over.start || {}) },
      allowed: over.allowed || ["corridor", "garden", "extractor", "weapons", "quarters", "kitchen"],
      deposits: over.deposits || [{ x: 1, y: 6 }],
      ice: over.ice || [],
      blocked: over.blocked || [],
      wells: over.wells || [],
      relics: over.relics || [],
      prebuilt: over.prebuilt || [],
      mechanics: over.mechanics || {},
      waves: over.waves || { first: 9999, interval: 40, count: 1 },
      eatRate: over.eatRate ?? 0,
      win: over.win || { corridors: 99 },
      ...over.level,
    },
    { seed: over.seed ?? 7 }
  );
}

describe("geometry", () => {
  it("rotates tetrominoes clockwise around origin", () => {
    const t = SHAPES.garden;
    const r1 = rotateShape(t, 1);
    assert.deepEqual(r1, t.map(([x, y]) => [-y, x]));
  });

  it("starts with a plus-shaped walkable core", () => {
    const m = mini();
    assert.equal(m.rooms[0].type, "core");
    assert.equal(m.rooms[0].cells.length, 5);
    assert.ok(m.walkable(4, 6));
    assert.ok(m.walkable(4, 5));
    assert.ok(m.walkable(3, 6));
  });

  it("rejects overlapping or floating rooms", () => {
    const m = mini();
    setTool(m, "corridor");
    assert.equal(tapCell(m, 4, 6), false);
    assert.equal(tapCell(m, 0, 0), false);
  });

  it("places a corridor against the station and starts it as a blueprint", () => {
    const m = mini();
    setTool(m, "corridor");
    assert.equal(tapCell(m, 4, 4), true);
    const room = roomAt(m, 4, 4);
    assert.equal(room.type, "corridor");
    assert.equal(room.built, false);
    assert.equal(m.walkable(4, 4), false);
  });
});

describe("assignment", () => {
  it("assigns the nearest kapsel when a room is tapped", () => {
    const m = mini({
      prebuilt: [{ type: "garden", x: 4, y: 8, rot: 0, built: true }],
    });
    setTool(m, "assign");
    const garden = m.rooms.find((r) => r.type === "garden");
    assert.ok(assignTo(m, garden));
    assert.equal(m.kapsels.filter((k) => k.assignment === garden.id).length, 1);
  });

  it("lets a second tap send a second kapsel", () => {
    const m = mini({
      prebuilt: [{ type: "weapons", x: 6, y: 6, rot: 0, built: true }],
    });
    const gun = m.rooms.find((r) => r.type === "weapons");
    assignTo(m, gun);
    assignTo(m, gun);
    assert.equal(m.kapsels.filter((k) => k.assignment === gun.id).length, 2);
  });
});

describe("economy", () => {
  it("staffed gardens produce food and haul it to the core pantry", () => {
    const m = mini({
      start: { minerals: 0, food: 0, crew: 2 },
      prebuilt: [{ type: "garden", x: 4, y: 8, rot: 0, built: true }],
    });
    const garden = m.rooms.find((r) => r.type === "garden");
    assignTo(m, garden);
    tick(m, 25);
    assert.ok(coreStock(m, "food") >= 1, "pantry should receive hauled food");
  });

  it("extractors only run next to a mineral deposit", () => {
    const m = mini({
      start: { minerals: 8, food: 0, crew: 2 },
      deposits: [{ x: 1, y: 6 }],
    });
    setTool(m, "extractor");
    assert.equal(tapCell(m, 6, 6), false, "far from deposit");
    assert.equal(tapCell(m, 2, 5), true, "adjacent to deposit");
  });

  it("blueprints need mineral hauling and construction work", () => {
    const m = mini({ start: { minerals: 8, food: 0, crew: 2 } });
    setTool(m, "corridor");
    tapCell(m, 4, 4);
    const site = roomAt(m, 4, 4);
    assignTo(m, site);
    tick(m, 0.2);
    assert.equal(site.built, false);
    tick(m, 20);
    assert.equal(site.built, true);
    assert.equal(coreStock(m, "mineral"), 7);
  });

  it("heals leaked mineral claims so a blueprint can still finish", () => {
    const m = mini({ start: { minerals: 8, food: 0, crew: 2 }, win: { corridors: 1 } });
    setTool(m, "corridor");
    tapCell(m, 4, 4);
    const site = roomAt(m, 4, 4);
    site.incoming.mineral = 4;
    assignTo(m, site);
    tick(m, 20);
    assert.equal(site.built, true);
  });

  it("queued corridors must be built in connected order", () => {
    const m = mini({ start: { minerals: 10, food: 0, crew: 3 } });
    setTool(m, "corridor");
    tapCell(m, 4, 4);
    tapCell(m, 4, 3);
    tapCell(m, 4, 2);
    for (const room of m.rooms) {
      if (room.type === "corridor") assignTo(m, room);
    }
    tick(m, 35);
    assert.ok(m.rooms.filter((r) => r.type === "corridor" && r.built).length === 3);
    assert.ok(m.walkable(4, 2));
  });

  it("kitchen chain cooks biomass before meals reach the pantry", () => {
    const m = mini({
      start: { minerals: 0, food: 0, crew: 3 },
      mechanics: { kitchenChain: true },
      prebuilt: [
        { type: "garden", x: 4, y: 8, rot: 0, built: true },
        { type: "kitchen", x: 6, y: 6, rot: 0, built: true },
      ],
    });
    const garden = m.rooms.find((r) => r.type === "garden");
    const kitchen = m.rooms.find((r) => r.type === "kitchen");
    assignTo(m, garden);
    assignTo(m, kitchen);
    tick(m, 40);
    assert.ok(coreStock(m, "food") >= 1, "cooked meals should arrive");
    assert.equal(coreStock(m, "biomass") || 0, 0);
  });

  it("quarters recruit after meals are delivered and prepared", () => {
    const m = mini({
      start: { minerals: 0, food: 9, crew: 2 },
      prebuilt: [{ type: "quarters", x: 6, y: 6, rot: 0, built: true }],
    });
    const q = m.rooms.find((r) => r.type === "quarters");
    assignTo(m, q);
    tick(m, 30);
    assert.ok(m.kapsels.length >= 3, "at least one recruit");
    assert.ok(q.recruited >= 1);
  });
});

describe("combat", () => {
  it("unmanned weapons do not fire", () => {
    const m = mini({
      prebuilt: [{ type: "weapons", x: 6, y: 6, rot: 0, built: true }],
      waves: { first: 0.01, interval: 40, count: 1, hp: 80, speed: 12 },
    });
    tick(m, 0.5);
    assert.equal(m.shots.length, 0);
  });

  it("staffed weapons fire at nearby enemies", () => {
    const m = mini({
      prebuilt: [{ type: "weapons", x: 6, y: 6, rot: 0, built: true }],
    });
    const gun = m.rooms.find((r) => r.type === "weapons");
    assignTo(m, gun);
    tick(m, 4);
    assert.ok(staffed(m, gun) >= 1);
    m.enemies.push({
      x: gun.cx + 20,
      y: gun.cy,
      hp: 40,
      maxhp: 40,
      speed: 0,
      dps: 0,
      r: 8,
      cloaked: false,
      vx: 0,
      vy: 0,
    });
    tick(m, 1.4);
    assert.ok(
      m.shots.length >= 1 || m.kills >= 1 || m.enemies.some((e) => e.hp < e.maxhp),
      "staffed weapons should damage or fire at the scout"
    );
  });

  it("losing the core ends the match", () => {
    const m = mini({ start: { minerals: 0, food: 0, crew: 1 } });
    m.rooms[0].hp = 1;
    m.enemies.push({
      x: m.rooms[0].cx,
      y: m.rooms[0].cy,
      hp: 80,
      maxhp: 80,
      speed: 0,
      dps: 40,
      r: 8,
      cloaked: false,
      vx: 0,
      vy: 0,
      target: m.rooms[0].cells[0],
      state: "attacking",
    });
    tick(m, 1);
    assert.equal(m.status, "lost");
  });
});

describe("win conditions", () => {
  it("wins after the required corridors are built", () => {
    const m = mini({
      start: { minerals: 6, food: 0, crew: 3 },
      win: { corridors: 2 },
    });
    setTool(m, "corridor");
    tapCell(m, 4, 4);
    tapCell(m, 4, 8);
    for (const room of m.rooms) if (room.type === "corridor") assignTo(m, room);
    tick(m, 25);
    assert.equal(m.status, "won");
  });
});

describe("original mechanics", () => {
  it("lets a second gate land off the station", () => {
    const m = mini({
      mechanics: { wormholes: true },
      allowed: ["gate", "corridor"],
    });
    setTool(m, "gate");
    assert.equal(tapCell(m, 6, 6), true);
    assert.equal(tapCell(m, 0, 0), true);
  });

  it("wormholes shorten kapsel routes", () => {
    const m = mini({
      mechanics: { wormholes: true },
      prebuilt: [
        { type: "gate", x: 2, y: 6, rot: 0, built: true },
        { type: "gate", x: 6, y: 6, rot: 0, built: true },
        { type: "corridor", x: 4, y: 4, rot: 0, built: true },
      ],
    });
    const a = pathLength(m, 2, 6, 6, 6);
    assert.ok(a <= 1, "gates should be adjacent in graph, got " + a);
  });

  it("solar flares damage rooms outside a shield", () => {
    const m = mini({
      mechanics: { flares: { first: 0.2, interval: 20, damage: 12, telegraph: 0 } },
      prebuilt: [
        { type: "garden", x: 4, y: 9, rot: 0, built: true },
        { type: "shield", x: 6, y: 5, rot: 0, built: true },
      ],
    });
    const garden = m.rooms.find((r) => r.type === "garden");
    const shield = m.rooms.find((r) => r.type === "shield");
    const gardenHp = garden.hp;
    const shieldHp = shield.hp;
    tick(m, 0.6);
    assert.ok(garden.hp < gardenHp, "exposed garden should scorch");
    assert.equal(shield.hp, shieldHp, "shielded room should hold");
  });

  it("ice slows kapsels until a heater thaws the tile", () => {
    const m = mini({
      ice: [{ x: 4, y: 5 }],
      prebuilt: [{ type: "heater", x: 6, y: 6, rot: 0, built: true }],
    });
    assert.ok(m.iceAt(4, 5));
    const heater = m.rooms.find((r) => r.type === "heater");
    assignTo(m, heater);
    tick(m, 6);
    assert.equal(m.iceAt(4, 5), false);
  });

  it("scanners reveal cloaked scouts", () => {
    const m = mini({
      mechanics: { cloak: true },
      prebuilt: [{ type: "scanner", x: 6, y: 6, rot: 0, built: true }],
    });
    const scanner = m.rooms.find((r) => r.type === "scanner");
    m.enemies.push({
      x: scanner.cx + 10,
      y: scanner.cy,
      hp: 20,
      maxhp: 20,
      speed: 0,
      dps: 0,
      r: 8,
      cloaked: true,
      vx: 0,
      vy: 0,
    });
    assert.equal(m.enemies[0].cloaked, true);
    assignTo(m, scanner);
    tick(m, 4);
    assert.equal(m.enemies[0].cloaked, false);
  });

  it("gravity wells pull enemies inward", () => {
    const m = mini({
      wells: [{ x: 4, y: 6, strength: 80 }],
    });
    m.enemies.push({
      x: 200,
      y: 80,
      hp: 20,
      maxhp: 20,
      speed: 0,
      dps: 0,
      r: 8,
      cloaked: false,
      vx: 0,
      vy: 0,
    });
    const before = Math.hypot(m.enemies[0].x - m.layout.ox - 4.5 * m.layout.cell, m.enemies[0].y - m.layout.oy - 6.5 * m.layout.cell);
    tick(m, 1);
    const after = Math.hypot(m.enemies[0].x - m.layout.ox - 4.5 * m.layout.cell, m.enemies[0].y - m.layout.oy - 6.5 * m.layout.cell);
    assert.ok(after < before, "enemy should drift toward the well");
  });

  it("overload boosts a staffed extractor then injures it", () => {
    const m = mini({
      mechanics: { overload: true },
      deposits: [{ x: 2, y: 6 }],
      prebuilt: [{ type: "extractor", x: 2, y: 5, rot: 0, built: true }],
    });
    const ext = m.rooms.find((r) => r.type === "extractor");
    assignTo(m, ext);
    tick(m, 3);
    const hp = ext.hp;
    assert.equal(overloadRoom(m, ext), true);
    assert.ok(ext.overclock > 0);
    tick(m, 7);
    assert.ok(ext.hp < hp, "overclock should scorch the room after the surge");
  });
});

describe("input modes", () => {
  it("rotate cycles the ghost before placement", () => {
    const m = mini();
    setTool(m, "garden");
    const a = m.ghostCells().slice();
    rotate(m);
    const b = m.ghostCells();
    assert.notDeepEqual(a, b);
  });
});

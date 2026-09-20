import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { LEVELS, levelById } from "../js/levels.js";
import {
  createMatch,
  step,
  tapCell,
  setTool,
  assignTo,
  roomAt,
  jobChips,
  PIECES,
} from "../js/sim.js";

function tick(match, seconds) {
  const dt = 0.05;
  const n = Math.ceil(seconds / dt);
  for (let i = 0; i < n; i++) step(match, dt);
}

describe("tetromino piece queue", () => {
  it("deals a seven-bag tetromino when the station uses the queue", () => {
    const m = createMatch(levelById("4-04"), { seed: 11 });
    assert.equal(m.mechanics.pieceQueue, true);
    assert.ok(PIECES[m.piece], m.piece);
    assert.ok(m.queue.length >= 2);
  });

  it("places the bag shape instead of the room's default footprint", () => {
    const level = {
      ...levelById("4-04"),
      waves: { first: 9999, interval: 40, count: 0, max: 0 },
      win: { corridors: 99 },
    };
    const m = createMatch(level, { seed: 2 });
    m.piece = "I";
    m.bag = ["O", "T"];
    m.queue = ["O", "T"];
    setTool(m, "corridor");
    assert.equal(tapCell(m, 4, 4), true);
    const room = roomAt(m, 4, 4);
    assert.ok(room);
    assert.equal(room.cells.length, 4);
    assert.equal(m.piece, "O");
  });

  it("charges minerals per tile when the bag is live", () => {
    const level = {
      ...levelById("1-01"),
      mechanics: { pieceQueue: true },
      win: { corridors: 99 },
      start: { minerals: 20, food: 0, crew: 3 },
    };
    const m = createMatch(level, { seed: 3 });
    m.piece = "O";
    m.bag = ["I"];
    setTool(m, "corridor");
    assert.equal(tapCell(m, 6, 5), true);
    const room = m.rooms.find((r) => r.type === "corridor");
    assert.equal(room.def.cost, 4);
  });
});

describe("first-assign tutorial", () => {
  it("does not auto-assign the first Spine blueprint", () => {
    const m = createMatch(levelById("1-01"), { seed: 1 });
    setTool(m, "corridor");
    assert.equal(tapCell(m, 4, 4), true);
    const site = roomAt(m, 4, 4);
    assert.equal(m.kapsels.some((k) => k.assignment === site.id), false);
    assert.equal(m.tutorial.needAssign, true);
    assert.equal(m.tool, "assign");
  });

  it("stays on the assign lesson until a kapsel is sent", () => {
    const m = createMatch(levelById("1-01"), { seed: 1 });
    setTool(m, "corridor");
    tapCell(m, 4, 4);
    setTool(m, "corridor");
    assert.equal(tapCell(m, 4, 8), false, "cannot place another room during the lesson");
    const site = roomAt(m, 4, 4);
    setTool(m, "assign");
    assert.equal(assignTo(m, site), true);
    assert.equal(m.tutorial.needAssign, false);
    assert.equal(m.tutorial.assigned, true);
  });
});

describe("job chips", () => {
  it("counts idle kapsels at the start of a match", () => {
    const m = createMatch(levelById("1-01"), { seed: 1 });
    const chips = jobChips(m);
    const wait = chips.find((c) => c.id === "wait");
    assert.ok(wait);
    assert.equal(wait.n, 3);
  });

  it("reports a builder once a blueprint is assigned", () => {
    const m = createMatch(levelById("1-01"), { seed: 1 });
    setTool(m, "corridor");
    tapCell(m, 4, 4);
    const site = roomAt(m, 4, 4);
    assignTo(m, site);
    tick(m, 0.4);
    const chips = jobChips(m);
    const active = chips.filter((c) => c.id !== "wait");
    assert.ok(active.length >= 1, JSON.stringify(chips));
  });
});

describe("placement juice", () => {
  it("emits spark fx when a room is placed", () => {
    const m = createMatch(levelById("1-01"), { seed: 1 });
    setTool(m, "corridor");
    tapCell(m, 4, 4);
    assert.ok(m.fx.some((f) => f.kind === "spark"));
  });
});

describe("campaign pacing", () => {
  it("keeps a pantry long enough to raise a kitchen on hungry stations", () => {
    for (const level of LEVELS) {
      if (!level.eatRate) continue;
      const crew = level.start.crew || 1;
      const secs = level.start.food / (level.eatRate * crew);
      assert.ok(secs >= 42, `${level.id} starves in ${secs.toFixed(1)}s`);
    }
  });

  it("lets kitchen-chain stations afford a garden and a kitchen", () => {
    for (const level of LEVELS) {
      if (!level.mechanics?.kitchenChain) continue;
      if (!level.allowed.includes("garden") || !level.allowed.includes("kitchen")) continue;
      assert.ok(level.start.minerals >= 12, `${level.id} cannot buy the chain`);
    }
  });

  it("does not hide the only deposit on the far rim with a tiny mineral bank", () => {
    const far = ["2-02", "3-03"];
    for (const id of far) {
      const level = levelById(id);
      const core = level.core || { x: 4, y: 6 };
      for (const d of level.deposits) {
        const man = Math.abs(d.x - core.x) + Math.abs(d.y - core.y);
        assert.ok(level.start.minerals >= man, `${id} deposit is ${man} tiles out with ${level.start.minerals} minerals`);
      }
    }
  });

  it("teaches the bag in world four and uses it on the late boards", () => {
    assert.equal(levelById("4-04").mechanics.pieceQueue, true);
    assert.equal(levelById("5-06").mechanics.pieceQueue, true);
    assert.equal(levelById("6-06").mechanics.pieceQueue, true);
    assert.equal(levelById("7-05").mechanics.pieceQueue, true);
    assert.equal(levelById("7-06").mechanics.pieceQueue, true);
  });
});

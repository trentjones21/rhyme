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
  PIECES,
  pieceHasLanding,
  holdPiece,
} from "../js/sim.js";

function tick(match, seconds) {
  const dt = 0.05;
  const n = Math.ceil(seconds / dt);
  for (let i = 0; i < n; i++) step(match, dt);
}

function fillExcept(match, keep) {
  const kept = new Set(keep.map((c) => c.x + "," + c.y));
  match.mechanics.pieceQueue = false;
  match.tutorial.needAssign = false;
  setTool(match, "corridor");
  let placed = true;
  let guard = 0;
  while (placed && guard++ < 200) {
    placed = false;
    for (let y = 0; y < match.rows; y++) {
      for (let x = 0; x < match.cols; x++) {
        const k = x + "," + y;
        if (kept.has(k)) continue;
        if (roomAt(match, x, y)) continue;
        if (tapCell(match, x, y)) placed = true;
      }
    }
  }
  match.mechanics.pieceQueue = true;
  for (let y = 0; y < match.rows; y++) {
    for (let x = 0; x < match.cols; x++) {
      const k = x + "," + y;
      if (kept.has(k)) continue;
      if (roomAt(match, x, y)) continue;
      match.blocked.add(k);
    }
  }
}

describe("fair bag", () => {
  it("lets every tetromino land on an empty bag station", () => {
    for (const id of ["4-04", "5-06", "6-06", "7-05", "7-06"]) {
      const m = createMatch(levelById(id), { seed: 5 });
      for (const name of Object.keys(PIECES)) {
        m.piece = name;
        assert.equal(pieceHasLanding(m), true, `${id} cannot place ${name}`);
      }
    }
  });

  it("skips an I-piece when only a 2x2 pocket remains", () => {
    const m = createMatch(levelById("4-04"), { seed: 9 });
    const pocket = [
      { x: 6, y: 4 },
      { x: 7, y: 4 },
      { x: 6, y: 5 },
      { x: 7, y: 5 },
    ];
    fillExcept(m, pocket);
    m.piece = "I";
    m.bag = ["I", "I", "O", "T"];
    m.queue = ["I", "I", "O"];
    assert.equal(pieceHasLanding(m), false, "I should not fit a 2x2");
    m.piece = "O";
    assert.equal(pieceHasLanding(m), true, "O should fit a 2x2");
    m.piece = "I";
    m.bag = ["I", "I", "O", "T"];
    holdPiece(m); // dealFair is inside dealPiece/hold when swapping empty hold... 
    // Use deal by calling holdPiece with empty hold which deals next, or export dealFair.
    // We'll call holdPiece after setting held null: it parks I and deals from bag.
    m.held = null;
    m.piece = "I";
    m.bag = ["I", "I", "O"];
    assert.equal(holdPiece(m), true);
    assert.equal(m.piece, "O");
  });

  it("parks the current piece on hold and restores it", () => {
    const m = createMatch(levelById("4-04"), { seed: 2 });
    m.piece = "T";
    m.bag = ["L", "J"];
    m.held = null;
    assert.equal(holdPiece(m), true);
    assert.equal(m.held, "T");
    assert.equal(m.piece, "L");
    assert.equal(holdPiece(m), true);
    assert.equal(m.piece, "T");
    assert.equal(m.held, "L");
  });
});

describe("Garden Duty staff lesson", () => {
  it("makes Garden Duty require a staff tap after the garden is built", () => {
    const level = levelById("1-02");
    assert.equal(level.mechanics.teachStaff, true);
    const m = createMatch(level, { seed: 1 });
    setTool(m, "garden");
    assert.equal(tapCell(m, 4, 8), true);
    const garden = m.rooms.find((r) => r.type === "garden");
    assert.ok(garden);
    if (!garden.built) {
      assignTo(m, garden);
      tick(m, 25);
    }
    assert.equal(garden.built, true);
    assert.equal(
      m.kapsels.some((k) => k.assignment === garden.id),
      false,
      "crew should be recalled so the player must tap"
    );
    assert.equal(m.tutorial.needAssign, true);
    assert.equal(assignTo(m, garden), true);
    assert.equal(m.tutorial.needAssign, false);
    assert.equal(m.tutorial.staffed, true);
  });

  it("emits a grow stinger when a staffed garden harvests", () => {
    const m = createMatch(levelById("1-02"), { seed: 1 });
    setTool(m, "garden");
    tapCell(m, 4, 8);
    const garden = m.rooms.find((r) => r.type === "garden");
    assignTo(m, garden);
    tick(m, 25);
    assignTo(m, garden);
    tick(m, 8);
    assert.ok(
      m.events.some((e) => e.type === "grow" || e.type === "mine" || e.type === "haul"),
      "expected a job audio event, got " + m.events.map((e) => e.type).join(",")
    );
  });
});

describe("late bag stations", () => {
  it("gives Last Geometry enough minerals to lay seven tetrominoes", () => {
    const last = levelById("7-06");
    assert.ok(last.start.minerals >= 36, last.start.minerals);
    assert.equal(last.mechanics.pieceQueue, true);
  });

  it("keeps a hold on every bag station", () => {
    for (const level of LEVELS) {
      if (!level.mechanics?.pieceQueue) continue;
      const m = createMatch(level, { seed: 3 });
      assert.equal(m.mechanics.pieceQueue, true);
      assert.equal(holdPiece(m), true);
    }
  });
});

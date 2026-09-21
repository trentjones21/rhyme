import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { levelById } from "../js/levels.js";
import {
  createMatch,
  step,
  tapCell,
  setTool,
  canPlace,
  captainBeat,
  resumeThink,
  holdPiece,
  coreStock,
} from "../js/sim.js";

function tick(match, seconds) {
  if (match.thinkLocked) resumeThink(match);
  const dt = 0.05;
  const n = Math.ceil(seconds / dt);
  for (let i = 0; i < n; i++) step(match, dt);
}

function placeType(match, type) {
  setTool(match, type);
  for (let rot = 0; rot < 4; rot++) {
    match.rot = rot;
    for (let y = 0; y < match.rows; y++) {
      for (let x = 0; x < match.cols; x++) {
        if (canPlace(match, type, x, y, rot) && tapCell(match, x, y)) return true;
      }
    }
  }
  return false;
}

function captainPlay(id, limit = 220) {
  const m = createMatch(levelById(id), { seed: 11 });
  while (m.status === "playing" && m.time < limit) {
    if (!captainBeat(m) && m.mechanics.pieceQueue) holdPiece(m);
    tick(m, 0.4);
  }
  return m;
}

describe("Long Haul actually taxes the far vein", () => {
  it("gives enough mineral to lay the southern road and still mine past the bank", () => {
    const l = levelById("2-02");
    assert.ok(l.start.minerals >= 28, "2-02 start minerals " + l.start.minerals);
    assert.ok(l.win.mineral >= l.start.minerals + 6, "2-02 mineral win " + l.win.mineral);
    assert.ok(l.win.rooms && l.win.rooms.extractor >= 1);
    assert.ok(l.deposits.some((d) => d.y >= 9), "vein is not far south");
    assert.match(`${l.briefing} ${l.lesson} ${l.hint}`, /road|vein|south|haul/i);
  });

  it("lays a haul road so the extractor can sit on the far vein", () => {
    const m = createMatch(levelById("2-02"), { seed: 11 });
    const dep = [...m.deposits][0].split(",").map(Number);
    for (let i = 0; i < 90 && m.status === "playing"; i++) {
      if (!captainBeat(m) && m.mechanics.pieceQueue) holdPiece(m);
      tick(m, 0.5);
      if (m.rooms.some((r) => r.type === "extractor")) break;
    }
    const ex = m.rooms.find((r) => r.type === "extractor" && !r.dead);
    assert.ok(ex, "never placed extractor t=" + m.time.toFixed(1));
    const near = ex.cells.some((c) => Math.abs(c.x - dep[0]) + Math.abs(c.y - dep[1]) <= 2);
    assert.ok(near, "extractor not on the far vein");
    assert.ok(
      m.rooms.some((r) => r.type === "corridor" && r.cells.some((c) => c.y >= 6)),
      "never laid the southern haul road"
    );
  });
});

describe("Two Kitchens is not already won by the opening crew", () => {
  it("asks for meals well past the pantry, not a mute crew count", () => {
    const l = levelById("2-03");
    assert.ok(l.win.rooms && l.win.rooms.kitchen >= 1, "2-03 kitchen optional");
    assert.ok(l.win.food >= l.start.food + 6, "2-03 food " + l.win.food + " start " + l.start.food);
    assert.ok(!l.win.crew || l.win.crew > l.start.crew, "2-03 crew " + l.win.crew + " is the opening four");
    assert.match(`${l.briefing} ${l.lesson}`, /galley|kitchen|cook|pantry|plot/i);
  });
});

describe("Island Core is a fold puzzle, not a pantry sit", () => {
  it("requires a gate pair and a fold before four meals count", () => {
    const l = levelById("5-02");
    assert.ok(l.win.food >= 4, "5-02 food " + l.win.food);
    assert.ok((l.win.rooms && l.win.rooms.gate >= 2) || (l.win.folds || 0) >= 1, "5-02 never asks to fold");
    assert.ok((l.win.folds || 0) >= 1, "5-02 folds optional");
    assert.match(`${l.briefing} ${l.lesson} ${l.hint || ""}`, /fold|pad|island|gate/i);
  });

  it("does not let Island Core win from two gates on the plus", () => {
    const m = createMatch(levelById("5-02"), { seed: 3 });
    assert.equal(placeType(m, "gate"), true);
    assert.equal(placeType(m, "gate"), true);
    tick(m, 8);
    assert.equal(m.status, "playing", "two plus gates won Island Core at t=" + m.time.toFixed(1));
  });
});

describe("Fragile Bridge can afford both shores", () => {
  it("pulls relics off the true corners and banks a two-road gun budget", () => {
    const l = levelById("5-05");
    assert.equal(l.win.relics, 2);
    assert.ok(l.win.surviveWaves >= 1);
    assert.ok(l.start.minerals >= 32, l.start.minerals);
    assert.ok(l.waves.first >= 36, l.waves.first);
    for (const r of l.relics) {
      const corner = (r.x === 0 || r.x === 8) && (r.y === 0 || r.y === 12);
      assert.equal(corner, false, `true corner ${r.x},${r.y}`);
    }
    assert.match(`${l.briefing} ${l.lesson}`, /relic|fold|bridge|shore/i);
  });
});

describe("ship-feel: chrome, 60fps, haptics, cache", () => {
  it("shows fake notch and homebar on desktop, hides them in standalone", () => {
    const css = readFileSync(new URL("../css/rhyme.css", import.meta.url), "utf8");
    assert.match(css, /#notch,\s*#homebar\s*\{\s*display:\s*none/);
    assert.match(css, /@media\s*\(min-width:\s*520px\)/);
    assert.match(css, /html\.standalone[\s\S]{0,180}#notch[\s\S]{0,80}display:\s*none/);
    assert.match(css, /safe-area-inset-top/);
    assert.match(css, /safe-area-inset-bottom/);
  });

  it("steps the sim on a fixed 60Hz tick", () => {
    const app = readFileSync(new URL("../js/app.js", import.meta.url), "utf8");
    assert.match(app, /1\s*\/\s*60/);
  });

  it("buzzes when Begin is tapped", () => {
    const app = readFileSync(new URL("../js/app.js", import.meta.url), "utf8");
    const start = app.indexOf('$("briefStart")');
    assert.ok(start >= 0, "briefStart handler missing");
    const slice = app.slice(start, start + 280);
    assert.match(slice, /buzz\(/);
  });

  it("bumps the portrait cache so ship-feel is not stuck on v29", () => {
    const html = readFileSync(new URL("../index.html", import.meta.url), "utf8");
    const app = readFileSync(new URL("../js/app.js", import.meta.url), "utf8");
    const sw = readFileSync(new URL("../sw.js", import.meta.url), "utf8");
    assert.match(html, /app\.js\?v=35/);
    assert.match(app, /sw\.js\?v=25/);
    assert.match(sw, /rhyme-v25/);
  });
});

describe("captain can finish leftover Supply Lines, Fold, and Last Geometry", () => {
  it("wins 2-01 through 2-04, Fold interiors, and Last Geometry without startFinale", () => {
    const ids = ["2-01", "2-02", "2-03", "2-04", "5-02", "5-05", "5-06", "7-06"];
    for (const id of ids) {
      const m = captainPlay(id, 220);
      assert.equal(
        m.status,
        "won",
        `${id} ${m.status} ${m.loseReason || ""} t=${m.time.toFixed(1)} rel=${m.relics.filter((r) => r.linked).length} wav=${m.wavesCleared} folds=${m.folds || 0} food=${coreStock(m, "food").toFixed(0)} min=${coreStock(m, "mineral").toFixed(0)} deaths=${m.deaths} hp=${m.core.hp}`
      );
      assert.equal(m.deaths, 0, id + " deaths " + m.deaths);
      assert.ok(m.core.hp / m.core.maxhp >= 0.8, id + " hp " + m.core.hp);
    }
  });
});

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { levelById } from "../js/levels.js";
import {
  createMatch,
  step,
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

function captainPlay(id, limit = 200) {
  const m = createMatch(levelById(id), { seed: 11 });
  while (m.status === "playing" && m.time < limit) {
    if (!captainBeat(m) && m.mechanics.pieceQueue) holdPiece(m);
    tick(m, 0.4);
  }
  return m;
}

function pantrySecs(level) {
  const crew = level.start.crew || 1;
  return level.start.food / ((level.eatRate || 0.001) * crew);
}

describe("Hungry Shift and Convoy stay honest combo stations", () => {
  it("makes Hungry Shift mint a seventh mouth from quarters, not the opening pantry", () => {
    const l = levelById("2-05");
    assert.ok(l.win.crew > l.start.crew);
    assert.ok(l.win.rooms && l.win.rooms.quarters >= 1, "2-05 never asks for a berth");
    assert.match(`${l.hint} ${l.briefing} ${l.lesson}`, /berth|quarters|mint/i);
    assert.ok(pantrySecs(l) >= 120, pantrySecs(l));
  });

  it("makes Convoy hold with two guns and a galley, not just three quiet waves", () => {
    const l = levelById("2-06");
    assert.equal(l.win.surviveWaves, 3);
    assert.ok(l.win.rooms && l.win.rooms.weapons >= 2, "2-06 guns optional");
    assert.ok(l.win.rooms.kitchen >= 1, "2-06 galley optional");
    assert.ok(l.win.food >= 1);
    assert.ok(l.waves.first >= 24);
  });
});

describe("bag survey stations teach Hold and actually kiss monuments", () => {
  it("hands Four Corners a bag and a Hold lesson", () => {
    const l = levelById("4-04");
    assert.equal(l.mechanics.pieceQueue, true);
    assert.equal(l.win.relics, 4);
    assert.ok(l.start.minerals >= 32, l.start.minerals);
    assert.match(`${l.hint} ${l.briefing}`, /hold|rotate|bag/i);
  });

  it("lets Living Archive eat and survey without going broke", () => {
    const l = levelById("4-05");
    assert.ok(l.start.minerals >= 28, l.start.minerals);
    assert.ok(l.win.relics >= 3);
    assert.ok(l.win.food >= 4);
    assert.ok(l.mechanics.kitchenChain);
  });

  it("gives Surveyors cover before the star, then four kisses", () => {
    const l = levelById("4-06");
    assert.ok(l.mechanics.flares.first >= 16, l.mechanics.flares.first);
    assert.ok(l.start.minerals >= 30, l.start.minerals);
    assert.equal(l.win.relics, 4);
    assert.ok(l.win.surviveWaves >= 2);
  });
});

describe("late combos are reachable, not mute", () => {
  it("lets Ambush Fold afford the second pad", () => {
    const l = levelById("5-03");
    assert.ok(l.start.minerals >= 22, l.start.minerals);
    assert.ok(l.win.rooms.gate >= 2);
    assert.ok(l.win.rooms.weapons >= 1);
  });

  it("puts a pad on Three Nodes' far vein so the extractor can be built", () => {
    const l = levelById("5-04");
    assert.ok(l.prebuilt && l.prebuilt.some((p) => p.type === "gate"), "5-04 far gate missing");
    assert.ok(l.win.mineral > l.start.minerals);
    assert.ok(l.win.rooms.gate >= 3);
  });

  it("gives Eclipse time to see and cover before the first bite", () => {
    const l = levelById("7-04");
    assert.equal(l.mechanics.cloak, true);
    assert.ok(l.mechanics.flares.first >= 16, l.mechanics.flares.first);
    assert.match(`${l.hint} ${l.briefing} ${l.lesson}`, /scan|aegis|shield|cover/i);
    assert.ok(l.win.rooms.scanner >= 1 && l.win.rooms.shield >= 1);
  });

  it("keeps All Hands a two-wave pantry, not a mute sandbox", () => {
    const l = levelById("7-05");
    assert.ok(l.wells.length >= 1);
    assert.ok(l.mechanics.cloak && l.mechanics.pieceQueue);
    assert.equal(l.win.surviveWaves, 2);
    assert.ok(l.win.food >= 4);
    assert.match(`${l.briefing} ${l.lesson}`, /cloak|fold|well|frost/i);
  });
});

describe("pause, retry, and world-select feel shipped", () => {
  it("fades pause and screens instead of popping them", () => {
    const css = readFileSync(new URL("../css/rhyme.css", import.meta.url), "utf8");
    assert.match(css, /\.overlay[\s\S]{0,280}transition/);
    assert.match(css, /\.screen[\s\S]{0,220}transition/);
    assert.match(css, /@keyframes (overlayIn|screenIn|cardIn)/);
  });

  it("gives world cards a press and a staggered entrance", () => {
    const css = readFileSync(new URL("../css/rhyme.css", import.meta.url), "utf8");
    assert.match(css, /\.card:active/);
    assert.match(css, /cardIn/);
  });

  it("flashes the hull on retry from pause or the end overlay", () => {
    const app = readFileSync(new URL("../js/app.js", import.meta.url), "utf8");
    assert.match(app, /boot|retryFlash|flash/);
    assert.match(app, /restartBtn|endRetry/);
  });
});

describe("quiet in-match juice still reads Grapefrukt", () => {
  it("glints staffed rooms and kapsels without a particle storm", () => {
    const render = readFileSync(new URL("../js/render.js", import.meta.url), "utf8");
    assert.match(render, /staffGlow|occupancy|drawStaff/);
    assert.match(render, /glint|specular|shine/);
    assert.match(render, /muzzle/);
  });
});

describe("captain can still finish the combo stations", () => {
  it("wins Hungry Shift, Four Corners, Ambush Fold, Three Nodes, Eclipse, and All Hands", () => {
    for (const id of ["2-05", "2-06", "4-04", "5-03", "5-04", "7-04", "7-05"]) {
      const m = captainPlay(id, 220);
      assert.equal(m.status, "won", `${id} ${m.status} ${m.loseReason || ""} t=${m.time.toFixed(1)} rel=${m.relics.filter((r) => r.linked).length} wav=${m.wavesCleared} food=${coreStock(m, "food").toFixed(0)}`);
    }
  });
});

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { LEVELS, WORLDS, levelById } from "../js/levels.js";
import {
  createMatch,
  step,
  tapCell,
  setTool,
  captainBeat,
  resumeThink,
  holdPiece,
  coreStock,
  assignTo,
  roomAt,
} from "../js/sim.js";
import { campaignStats } from "../js/save.js";
import { endOverlaySpec } from "../js/overlay.js";

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

function plusCells(level) {
  const core = level.core || { x: 4, y: 6 };
  return [
    [0, 0],
    [-1, 0],
    [1, 0],
    [0, -1],
    [0, 1],
  ].map(([dx, dy]) => ({ x: core.x + dx, y: core.y + dy }));
}

describe("leftover interiors are not already in the pantry", () => {
  it("makes The Vein mine past the opening bank", () => {
    const l = levelById("1-03");
    assert.ok(l.win.mineral >= l.start.minerals + 4, "1-03 mineral " + l.win.mineral + " start " + l.start.minerals);
    assert.ok(l.win.rooms && l.win.rooms.extractor >= 1);
    assert.match(`${l.briefing} ${l.lesson}`, /deposit|vein|extractor|mineral/i);
  });

  it("makes Station Hands feed, mine, and shoot instead of waiting out two waves", () => {
    const l = levelById("1-06");
    assert.ok(l.win.food > l.start.food, "1-06 food " + l.win.food + " start " + l.start.food);
    assert.equal(l.win.surviveWaves, 2);
    assert.ok(l.win.rooms && l.win.rooms.garden >= 1, "1-06 garden optional");
    assert.ok(l.win.rooms.extractor >= 1, "1-06 extractor optional");
    assert.ok(l.win.rooms.weapons >= 1, "1-06 gun optional");
  });

  it("makes Umbrella wait for two flares and grow past the opening meals", () => {
    const l = levelById("3-02");
    assert.ok(l.win.flares >= 2, "3-02 never asks for weather");
    assert.ok(l.win.food > l.start.food, "3-02 pantry already meets the win");
    assert.ok(l.win.rooms && l.win.rooms.shield >= 1);
    assert.ok(l.mechanics.flares && l.mechanics.flares.first >= 16);
  });

  it("makes Frozen Garden cook past the opening eight, then thaw", () => {
    const l = levelById("6-04");
    assert.ok(l.win.food > l.start.food, "6-04 food " + l.win.food + " start " + l.start.food);
    assert.equal(l.win.thaw, true);
    assert.ok(l.mechanics.kitchenChain);
  });
});

describe("Frost actually asks you to walk north across ice", () => {
  it("keeps ice off the plus and asks for a northern tile", () => {
    const l = levelById("6-01");
    const plus = new Set(plusCells(l).map((c) => c.x + "," + c.y));
    assert.ok(l.ice.length >= 3, l.ice.length);
    for (const ice of l.ice) {
      assert.equal(plus.has(ice.x + "," + ice.y), false, `ice on plus ${ice.x},${ice.y}`);
      assert.ok(ice.y <= 4, `ice ${ice.x},${ice.y} is not a northern belt`);
    }
    assert.ok(l.win.reachY != null && l.win.reachY <= 2, "6-01 never asks you to cross");
  });

  it("does not win Frost from two corridors east of the plus", () => {
    const m = createMatch(levelById("6-01"), { seed: 3 });
    setTool(m, "corridor");
    assert.equal(tapCell(m, 6, 6), true);
    assert.equal(assignTo(m, roomAt(m, 6, 6)), true);
    setTool(m, "corridor");
    assert.equal(tapCell(m, 7, 6), true);
    tick(m, 8);
    assert.equal(m.status, "playing", "east corridors won Frost at t=" + m.time.toFixed(1));
  });
});

describe("Relic Shore interiors can still afford both roads", () => {
  it("gives Opposite Shore enough mineral for two directions", () => {
    const l = levelById("4-02");
    assert.equal(l.win.relics, 2);
    assert.ok(l.start.minerals >= 18, l.start.minerals);
    assert.ok(l.relics.length >= 2);
    const ys = l.relics.map((r) => r.y).sort((a, b) => a - b);
    assert.ok(ys[0] <= 2 && ys[ys.length - 1] >= 10, "relics are not opposite shores");
  });

  it("gives Guarded Archive a gun budget after the survey", () => {
    const l = levelById("4-03");
    assert.equal(l.win.relics, 2);
    assert.ok(l.win.surviveWaves >= 1);
    assert.ok(l.start.minerals >= 22, l.start.minerals);
    assert.ok(l.allowed.includes("weapons"));
  });

  it("pulls Surveyors' monuments off the true corners", () => {
    const l = levelById("4-06");
    assert.equal(l.win.relics, 4);
    assert.ok(l.win.surviveWaves >= 2);
    for (const r of l.relics) {
      const corner = (r.x === 0 || r.x === 8) && (r.y === 0 || r.y === 12);
      assert.equal(corner, false, `true corner ${r.x},${r.y}`);
    }
    assert.ok(l.start.minerals >= 30, l.start.minerals);
  });
});

describe("a 42-station campaign reads on title, worlds, and briefing", () => {
  it("prints star totals against the campaign max", () => {
    const app = readFileSync(new URL("../js/app.js", import.meta.url), "utf8");
    assert.match(app, /starTotal.*starMax|starMax.*starTotal/);
    assert.match(app, /progressLine/);
    const stats = campaignStats({ stars: { "1-01": 3 } }, LEVELS);
    assert.equal(stats.starMax, LEVELS.length * 3);
    assert.equal(stats.total, 42);
  });

  it("shows world cards as stations and stars, not a mute 0/6", () => {
    const app = readFileSync(new URL("../js/app.js", import.meta.url), "utf8");
    assert.match(app, /18★/);
    assert.match(app, /\$\{done\}\/6/);
  });

  it("puts world, index, par, and best stars on the briefing", () => {
    const html = readFileSync(new URL("../index.html", import.meta.url), "utf8");
    const app = readFileSync(new URL("../js/app.js", import.meta.url), "utf8");
    const css = readFileSync(new URL("../css/rhyme.css", import.meta.url), "utf8");
    assert.match(html, /briefMeta/);
    assert.match(app, /briefMeta/);
    assert.match(app, /par/);
    assert.match(app, /of 6/);
    assert.match(css, /briefmeta|brief-meta|#briefMeta/);
  });

  it("names the next shore when a world gate opens, without doubling Retry", () => {
    const shore = endOverlaySpec("won", { hasNext: true, worldGate: "Supply Lines" });
    assert.equal(shore.primary, "Enter Supply Lines");
    assert.equal(shore.retry, true);
    const mid = endOverlaySpec("won", { hasNext: true });
    assert.equal(mid.primary, "Next station");
    const last = endOverlaySpec("won", { hasNext: false });
    assert.equal(last.primary, "Campaign complete");
    const lost = endOverlaySpec("lost");
    assert.equal(lost.primary, "Retry");
    assert.equal(lost.retry, false);
  });

  it("wires finish() to pass the next world name at a shore gate", () => {
    const app = readFileSync(new URL("../js/app.js", import.meta.url), "utf8");
    assert.match(app, /worldGate/);
    assert.match(app, /WORLDS/);
  });
});

describe("captain can finish leftover interiors", () => {
  it("wins Quiet Dock, Solar Weather, Relic Shore, and Ice Belt interiors", () => {
    const ids = [
      "1-02",
      "1-03",
      "1-04",
      "1-05",
      "1-06",
      "3-02",
      "3-03",
      "3-04",
      "3-05",
      "3-06",
      "4-02",
      "4-03",
      "4-05",
      "4-06",
      "6-01",
      "6-03",
      "6-04",
      "6-05",
    ];
    for (const id of ids) {
      const m = captainPlay(id, 220);
      assert.equal(
        m.status,
        "won",
        `${id} ${m.status} ${m.loseReason || ""} t=${m.time.toFixed(1)} rel=${m.relics.filter((r) => r.linked).length} wav=${m.wavesCleared} food=${coreStock(m, "food").toFixed(0)} min=${coreStock(m, "mineral").toFixed(0)}`
      );
    }
  });
});

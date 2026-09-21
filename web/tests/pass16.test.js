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
  paletteFor,
} from "../js/sim.js";
import { bedFor } from "../js/audio.js";

function tick(match, seconds) {
  if (match.thinkLocked) resumeThink(match);
  const dt = 0.05;
  const n = Math.ceil(seconds / dt);
  for (let i = 0; i < n; i++) step(match, dt);
}

function captainPlay(id, limit = 220) {
  const m = createMatch(levelById(id), { seed: 11 });
  while (m.status === "playing" && m.time < limit) {
    if (!captainBeat(m) && m.mechanics.pieceQueue) holdPiece(m);
    tick(m, 0.4);
  }
  return m;
}

function cssBlock(css, start, end) {
  const a = css.indexOf(start);
  const b = css.indexOf(end, a + 1);
  return css.slice(a, b < 0 ? undefined : b);
}

describe("Spine dock stays TAP HALL WRECK", () => {
  it("does not grow extra toys on 1-01", () => {
    assert.deepEqual(paletteFor(levelById("1-01")), ["assign", "corridor", "salvage"]);
  });
});

describe("Last Geometry dock is only the tools the station needs", () => {
  it("drops Heat, Gate, Berth, Beacon, and Over from the finale strip", () => {
    const palette = paletteFor(levelById("7-06"));
    const need = ["assign", "corridor", "scanner", "weapons", "shield", "garden", "kitchen", "extractor", "salvage"];
    for (const tool of need) assert.ok(palette.includes(tool), "missing " + tool);
    for (const dump of ["heater", "gate", "quarters", "beacon", "overload"]) {
      assert.equal(palette.includes(dump), false, dump + " should not be on Last Geometry");
    }
    assert.equal(palette.length, need.length, palette.join(","));
    assert.ok(paletteFor(levelById("7-03")).includes("overload"), "Overclock lost Over");
    assert.ok(paletteFor(levelById("7-05")).includes("heater"), "All Hands lost Heat");
    assert.ok(paletteFor(levelById("7-05")).includes("overload"), "All Hands lost Over");

    const css = readFileSync(new URL("../css/rhyme.css", import.meta.url), "utf8");
    const tools = cssBlock(css, "#tools {", ".tool {");
    assert.match(tools, /flex-wrap:\s*wrap|grid-template-columns/);
    const tile = cssBlock(css, ".tool {", ".tool.on");
    assert.match(tile, /min-height:\s*44px/);
    assert.match(tile, /min-width:\s*44px/);
  });
});

describe("station docks do not mute Spine or Last Geometry", () => {
  it("still lets the captain finish Spine and Last Geometry", () => {
    for (const id of ["1-01", "7-06"]) {
      const m = captainPlay(id, 220);
      assert.equal(
        m.status,
        "won",
        `${id} ${m.status} ${m.loseReason || ""} t=${m.time.toFixed(1)} rel=${m.relics.filter((r) => r.linked).length} wav=${m.wavesCleared} food=${coreStock(m, "food").toFixed(0)} deaths=${m.deaths} hp=${m.core.hp}`
      );
      assert.equal(m.deaths, 0, id + " deaths");
      assert.ok(m.core.hp / m.core.maxhp >= 0.8, id + " hp " + m.core.hp);
    }
  });
});

describe("look, audio, assign, and wrap stay after station docks", () => {
  it("keeps hulls, dashes, sparse beds, walk-on-assign, and wrapping", () => {
    const title = bedFor("title");
    assert.ok(title.freqs.length <= 2);
    const render = readFileSync(new URL("../js/render.js", import.meta.url), "utf8");
    assert.match(render, /drawRoomHull/);
    assert.match(render, /drawKapselDash/);
    assert.match(render, /drawAssignRing/);
    const sim = readFileSync(new URL("../js/sim.js", import.meta.url), "utf8");
    assert.match(sim, /function sendKapsel/);
    const audio = readFileSync(new URL("../js/audio.js", import.meta.url), "utf8");
    assert.doesNotMatch(audio, /PENTATONIC/);
    const css = readFileSync(new URL("../css/rhyme.css", import.meta.url), "utf8");
    assert.match(cssBlock(css, "#tools {", ".tool {"), /flex-wrap:\s*wrap/);
  });
});

describe("station-dock cache is not stuck on v34", () => {
  it("bumps the portrait cache after the station palettes", () => {
    const html = readFileSync(new URL("../index.html", import.meta.url), "utf8");
    const app = readFileSync(new URL("../js/app.js", import.meta.url), "utf8");
    const sw = readFileSync(new URL("../sw.js", import.meta.url), "utf8");
    assert.match(html, /app\.js\?v=35/);
    assert.match(app, /sw\.js\?v=25/);
    assert.match(sw, /rhyme-v25/);
  });
});

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

describe("Last Geometry tools all fit on the 430pt thumb dock", () => {
  it("wraps the palette so Grow is not clipped off the right", () => {
    const css = readFileSync(new URL("../css/rhyme.css", import.meta.url), "utf8");
    const tools = cssBlock(css, "#tools {", ".tool {");
    assert.match(tools, /flex-wrap:\s*wrap|grid-template-columns/);
    assert.doesNotMatch(tools, /overflow-x:\s*auto/);
    const tile = cssBlock(css, ".tool {", ".tool.on");
    assert.match(tile, /min-height:\s*44px/);
    assert.match(tile, /min-width:\s*44px/);

    const palette = paletteFor(levelById("7-06"));
    assert.ok(palette.includes("garden"), "Grow missing from the finale palette");
    assert.ok(palette.includes("kitchen"));
    assert.ok(palette.length >= 12, palette.length);

    const inner = 430 - 20 - 4;
    const gap = 6;
    const min = 44;
    const cols = Math.floor((inner + gap) / (min + gap));
    assert.ok(cols >= 7, "dock cannot seat seven 44pt tools: cols=" + cols);
    assert.ok(Math.ceil(palette.length / cols) <= 2, "finale tools spill past two thumb rows");

    const app = readFileSync(new URL("../js/app.js", import.meta.url), "utf8");
    assert.match(app, /garden:\s*"Grow"/);
  });
});

describe("thumb dock does not mute Spine or Last Geometry", () => {
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

describe("look, audio, and assign language stay after the dock pass", () => {
  it("keeps hulls, dashes, sparse beds, and walk-on-assign", () => {
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
  });
});

describe("dock cache is not stuck on v33", () => {
  it("bumps the portrait cache after the thumb dock", () => {
    const html = readFileSync(new URL("../index.html", import.meta.url), "utf8");
    const app = readFileSync(new URL("../js/app.js", import.meta.url), "utf8");
    const sw = readFileSync(new URL("../sw.js", import.meta.url), "utf8");
    assert.match(html, /app\.js\?v=34/);
    assert.match(app, /sw\.js\?v=24/);
    assert.match(sw, /rhyme-v24/);
  });
});

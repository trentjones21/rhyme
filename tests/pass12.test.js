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

function captainPlay(id, limit = 220) {
  const m = createMatch(levelById(id), { seed: 11 });
  while (m.status === "playing" && m.time < limit) {
    if (!captainBeat(m) && m.mechanics.pieceQueue) holdPiece(m);
    tick(m, 0.4);
  }
  return m;
}

describe("rooms read as Grapefrukt tetromino hulls", () => {
  it("merges adjacent cells and lights them from a top-left key", () => {
    const render = readFileSync(new URL("../js/render.js", import.meta.url), "utf8");
    assert.match(render, /drawRoomHull|neighborRadii|hullRadii|cornerRadii/);
    assert.match(render, /keyLight|bevel/);
    assert.match(render, /roundRect\([^)]*\[/);
  });
});

describe("kapsels are quiet white dashes", () => {
  it("draws facing stadiums with a specular, not cartoon faces", () => {
    const render = readFileSync(new URL("../js/render.js", import.meta.url), "utf8");
    assert.match(render, /capsule|stadium|dashBody|drawKapselDash/);
    assert.match(render, /atan2|facing|heading/);
    assert.match(render, /specular|glint/);
    assert.doesNotMatch(render, /fillRect\(x - 2\.2, y - 4/);
  });
});

describe("the void stays quiet", () => {
  it("keeps a sparse starfield and no drifting mote storm", () => {
    const render = readFileSync(new URL("../js/render.js", import.meta.url), "utf8");
    const stars = render.match(/seedStars\(\s*(\d+)\s*\)/);
    assert.ok(stars, "seedStars missing");
    assert.ok(Number(stars[1]) <= 120, "starfield is still a blizzard " + stars[1]);
    const motes = render.match(/motes\.push[\s\S]{0,40}for \(let i = 0; i < (\d+)/) ||
      render.match(/for \(let i = 0; i < (\d+); i\+\+\) \{\s*motes\.push/);
    assert.ok(motes, "mote loop missing");
    assert.ok(Number(motes[1]) <= 12, "mote storm " + motes[1]);
    assert.doesNotMatch(render, /arc\(\s*-20,\s*h \+ 40/);
  });
});

describe("the title is a plus-core station", () => {
  it("builds the logo as a core plus with one garden and one vein", () => {
    const html = readFileSync(new URL("../index.html", import.meta.url), "utf8");
    const css = readFileSync(new URL("../css/rhyme.css", import.meta.url), "utf8");
    assert.match(html, /class="logo plus"|class="logo" data-plus|logo plus/);
    assert.match(html, /g"\s*><\/i>\s*<i class="c"><\/i>\s*<i class="c"><\/i>\s*<i class="c"><\/i>\s*<i class="m"/);
    assert.match(css, /#title \.logo|logo\.plus/);
    assert.match(css, /grid-template-(columns|rows):\s*repeat\(5,/);
    assert.match(css, /\.logo[\s\S]{0,80}inset/);
  });
});

describe("beauty pass does not mute Spine or Last Geometry", () => {
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

describe("look cache is not stuck on v30", () => {
  it("bumps the portrait cache after the beauty pass", () => {
    const html = readFileSync(new URL("../index.html", import.meta.url), "utf8");
    const app = readFileSync(new URL("../js/app.js", import.meta.url), "utf8");
    const sw = readFileSync(new URL("../sw.js", import.meta.url), "utf8");
    assert.match(html, /app\.js\?v=31/);
    assert.match(app, /sw\.js\?v=21/);
    assert.match(sw, /rhyme-v21/);
  });
});

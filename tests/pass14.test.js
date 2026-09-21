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
  assignTo,
  setTool,
  tapCell,
  placeNearCore,
} from "../js/sim.js";
import { toneFor, bedFor } from "../js/audio.js";

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

describe("tap-assign sends a kapsel walking", () => {
  it("paths the kapsel toward the room on the same beat", () => {
    const m = createMatch(levelById("1-02"), { seed: 1 });
    assert.equal(placeNearCore(m, "garden"), true);
    const garden = m.rooms.find((r) => r.type === "garden");
    assert.ok(garden);
    assert.equal(assignTo(m, garden), true);
    const k = m.kapsels.find((w) => w.assignment === garden.id);
    assert.ok(k, "no kapsel took the assignment");
    assert.ok(
      k.state === "walking" || (k.path && k.path.length) || (k.job && k.job.target === garden),
      `kapsel did not walk: state=${k.state} path=${(k.path || []).length} job=${k.job && k.job.kind}`
    );
    assert.ok(garden.ring > 0, "room did not ring");
  });
});

describe("tapping a room assigns without switching to TAP", () => {
  it("lets a thumb tap on geometry send a kapsel", () => {
    const m = createMatch(levelById("1-02"), { seed: 2 });
    assert.equal(placeNearCore(m, "garden"), true);
    const garden = m.rooms.find((r) => r.type === "garden");
    setTool(m, "corridor");
    const c = garden.cells[0];
    assert.equal(tapCell(m, c.x, c.y), true);
    assert.ok(
      m.kapsels.some((k) => k.assignment === garden.id),
      "room tap did not assign"
    );
  });
});

describe("kapsels dock and the room rings again", () => {
  it("emits a dock when a kapsel arrives at its assignment", () => {
    const m = createMatch(levelById("1-02"), { seed: 1 });
    assert.equal(placeNearCore(m, "garden"), true);
    const garden = m.rooms.find((r) => r.type === "garden");
    assignTo(m, garden);
    let docked = false;
    for (let i = 0; i < 240; i++) {
      step(m, 0.05);
      if (m.events.some((e) => e.type === "dock")) {
        docked = true;
        break;
      }
    }
    assert.equal(docked, true, "never docked: " + m.events.map((e) => e.type).join(","));
    const seat = toneFor("seat");
    assert.ok(seat, "seat tone missing");
    assert.equal(seat.type, "sine");
    assert.ok(seat.vol <= 0.025, seat.vol);
    const app = readFileSync(new URL("../js/app.js", import.meta.url), "utf8");
    const ev = app.slice(app.indexOf("function consumeEvents"), app.indexOf("function finish"));
    assert.match(ev, /"dock"[\s\S]{0,80}play\("seat"\)|"seat"[\s\S]{0,40}dock/);
  });
});

describe("assign language is drawn as a walk beam and a room ring", () => {
  it("keeps beams for walking kapsels and a decaying ring", () => {
    const render = readFileSync(new URL("../js/render.js", import.meta.url), "utf8");
    assert.match(render, /drawAssignBeams/);
    assert.match(render, /walking/);
    assert.match(render, /room\.ring|assignRing|drawAssignRing/);
    assert.match(render, /drawKapselDash/);
    assert.match(render, /drawRoomHull/);
  });
});

describe("assign verb does not mute Spine or Last Geometry", () => {
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

describe("look and audio language stay after the assign pass", () => {
  it("keeps sparse sine beds and dash kapsels", () => {
    const title = bedFor("title");
    assert.ok(title.freqs.length <= 2);
    const render = readFileSync(new URL("../js/render.js", import.meta.url), "utf8");
    assert.match(render, /seedStars\(88\)/);
    const audio = readFileSync(new URL("../js/audio.js", import.meta.url), "utf8");
    assert.doesNotMatch(audio, /PENTATONIC/);
  });
});

describe("assign cache is not stuck on v32", () => {
  it("bumps the portrait cache after the assign verb", () => {
    const html = readFileSync(new URL("../index.html", import.meta.url), "utf8");
    const app = readFileSync(new URL("../js/app.js", import.meta.url), "utf8");
    const sw = readFileSync(new URL("../sw.js", import.meta.url), "utf8");
    assert.match(html, /app\.js\?v=34/);
    assert.match(app, /sw\.js\?v=24/);
    assert.match(sw, /rhyme-v24/);
  });
});

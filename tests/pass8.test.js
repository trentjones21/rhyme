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
  assignTo,
  captainBeat,
  resumeThink,
  overloadRoom,
} from "../js/sim.js";
import { bedFor, dripGap, toneFor } from "../js/audio.js";

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

function captainPlay(id, limit = 180) {
  const m = createMatch(levelById(id), { seed: 11 });
  while (m.status === "playing" && m.time < limit) {
    captainBeat(m);
    tick(m, 0.4);
  }
  return m;
}

describe("opener stations are puzzles, not tap-throughs", () => {
  it("does not let First Flare win before the star breathes", () => {
    const l = levelById("3-01");
    assert.ok(l.win.flares >= 1, "3-01 must wait for a flare");
    assert.ok(l.start.food < l.win.food, "3-01 pantry already meets the win");
    const m = createMatch(l, { seed: 3 });
    assert.equal(placeType(m, "shield"), true);
    assert.equal(placeType(m, "garden"), true);
    tick(m, 8);
    assert.equal(m.status, "playing", "placed the kit and won at t=" + m.time.toFixed(1));
  });

  it("does not let Shortcut win from two gates on the plus", () => {
    const l = levelById("5-01");
    assert.ok(l.win.food >= 3 || (l.win.folds || 0) >= 1, "5-01 is still stamp-two-gates");
    assert.ok((l.blocked && l.blocked.length) || (l.prebuilt && l.prebuilt.length), "5-01 has no island");
    const m = createMatch(l, { seed: 3 });
    assert.equal(placeType(m, "gate"), true);
    assert.equal(placeType(m, "gate"), true);
    tick(m, 8);
    assert.equal(m.status, "playing", "two plus gates won Shortcut at t=" + m.time.toFixed(1));
  });

  it("does not let Thaw clear from a heater hugging the plus", () => {
    const l = levelById("6-02");
    const m = createMatch(l, { seed: 3 });
    const ice0 = m.ice.size;
    assert.ok(ice0 >= 5, ice0);
    assert.equal(placeType(m, "heater"), true);
    tick(m, 8);
    assert.equal(m.status, "playing", "plus heater won Thaw at t=" + m.time.toFixed(1));
    assert.ok(m.ice.size >= 1, "plus heater thawed the whole belt");
  });
});

describe("world 7 openers teach the new toys", () => {
  it("locks Unseen on tapping Scan after the blueprint is built", () => {
    const l = levelById("7-01");
    assert.equal(l.mechanics.teachScan, true);
    assert.match(`${l.lesson} ${l.briefing} ${l.hint}`, /cloak|scan|unseen|invisible/i);
    const m = createMatch(l, { seed: 3 });
    assert.equal(placeType(m, "scanner"), true);
    const scan = m.rooms.find((r) => r.type === "scanner");
    assignTo(m, scan);
    tick(m, 20);
    assert.equal(scan.built, true);
    assert.equal(m.tutorial.needAssign, true);
    assert.equal(
      m.kapsels.some((k) => k.assignment === scan.id),
      false,
      "crew should wait for the tap"
    );
    assert.equal(assignTo(m, scan), true);
    assert.equal(m.tutorial.needAssign, false);
  });

  it("makes Well Trap a gun-on-the-current puzzle", () => {
    const l = levelById("7-02");
    assert.ok(l.wells.length >= 1);
    assert.ok(l.win.kills >= 3);
    assert.ok(l.win.rooms && l.win.rooms.weapons >= 1);
    assert.match(`${l.lesson} ${l.briefing}`, /well|gravity|current|bunch/i);
    assert.ok(l.waves.first >= 16, l.waves.first);
  });

  it("makes Overclock require the Over tool, not idle mining", () => {
    const l = levelById("7-03");
    assert.ok(l.win.overloads >= 1, "7-03 overload optional");
    assert.ok(l.win.mineral > l.start.minerals + 2);
    assert.match(`${l.hint} ${l.briefing}`, /overload|over tool|double-tap/i);
    const m = createMatch(l, { seed: 3 });
    assert.equal(placeType(m, "extractor"), true);
    const ex = m.rooms.find((r) => r.type === "extractor");
    assignTo(m, ex);
    tick(m, 12);
    assert.equal(ex.built, true);
    assignTo(m, ex);
    tick(m, 2);
    assert.equal(overloadRoom(m, ex), true);
    assert.ok((m.overloads || 0) >= 1);
  });
});

describe("menu and Grapefrukt-like music", () => {
  it("keeps a sparse title bed different from the match drone", () => {
    const title = bedFor("title");
    const play = bedFor("play");
    assert.ok(title && play);
    assert.notEqual(title.a, play.a);
    assert.ok(dripGap() >= 3000, dripGap());
    assert.ok(toneFor("drip"));
  });

  it("names cloak, gravity, and overload in the how-to", () => {
    const html = readFileSync(new URL("../index.html", import.meta.url), "utf8");
    assert.match(html, /cloak/i);
    assert.match(html, /gravit|well/i);
    assert.match(html, /overload/i);
    assert.match(html, /Forty-two stations|last geometry/i);
  });

  it("tints world cards from the world's accent", () => {
    const app = readFileSync(new URL("../js/app.js", import.meta.url), "utf8");
    assert.match(app, /worldLook/);
    assert.match(app, /setBed|musicBed|bedFor/);
  });
});

describe("captain can still finish the slower openers", () => {
  it("wins First Flare, Shortcut, Thaw, Unseen, and Overclock", () => {
    for (const id of ["3-01", "5-01", "6-02", "7-01", "7-03"]) {
      const m = captainPlay(id, 200);
      assert.equal(m.status, "won", `${id} ${m.status} ${m.loseReason || ""} t=${m.time.toFixed(1)}`);
      assert.ok(m.time >= 10, `${id} still a tap-through at ${m.time.toFixed(1)}s`);
    }
  });
});

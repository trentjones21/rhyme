import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { LEVELS, levelById } from "../js/levels.js";
import { createMatch, step } from "../js/sim.js";
import { shouldShowInstallHint } from "../js/install.js";
import { toneFor } from "../js/audio.js";

function pantrySecs(level) {
  const crew = level.start.crew || 1;
  return level.start.food / (level.eatRate * crew);
}

function tick(match, seconds) {
  const dt = 0.05;
  const n = Math.ceil(seconds / dt);
  for (let i = 0; i < n; i++) step(match, dt);
}

describe("install hint", () => {
  it("never shows on desktop Chrome, even with an install prompt waiting", () => {
    assert.equal(
      shouldShowInstallHint({ ios: false, standalone: false, dismissed: false, canInstall: true }),
      false
    );
  });

  it("shows only on iOS Safari until dismissed or standalone", () => {
    assert.equal(shouldShowInstallHint({ ios: true, standalone: false, dismissed: false }), true);
    assert.equal(shouldShowInstallHint({ ios: true, standalone: true, dismissed: false }), false);
    assert.equal(shouldShowInstallHint({ ios: true, standalone: false, dismissed: true }), false);
  });
});

describe("Last Geometry is a finale, not a trap", () => {
  it("keeps four relic-and-wave objectives with a pantry that lasts the survey", () => {
    const last = levelById("7-06");
    assert.equal(last.win.relics, 4);
    assert.equal(last.win.surviveWaves, 4);
    assert.equal(last.waves.max, 4);
    assert.ok(last.start.minerals >= 36);
    assert.ok(pantrySecs(last) >= 160, pantrySecs(last));
    assert.ok(last.waves.first >= 28, last.waves.first);
    assert.ok(last.mechanics.flares.first >= 22, last.mechanics.flares.first);
  });

  it("does not dump a six-pack of tanks on wave four", () => {
    const last = levelById("7-06");
    assert.ok(last.waves.count(4) <= 4, last.waves.count(4));
    assert.ok(last.waves.hp(4) <= 56, last.waves.hp(4));
    assert.ok((last.waves.speed || 24) <= 22);
  });

  it("keeps ice off the relics and the core plus", () => {
    const last = levelById("7-06");
    const core = last.core || { x: 4, y: 6 };
    const blocked = new Set(last.ice.map((c) => c.x + "," + c.y));
    for (const r of last.relics) {
      assert.equal(blocked.has(r.x + "," + r.y), false, "ice on relic");
    }
    for (const [dx, dy] of [
      [0, 0],
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1],
    ]) {
      assert.equal(blocked.has(core.x + dx + "," + (core.y + dy)), false, "ice on core");
    }
  });
});

describe("late stations you can actually finish", () => {
  it("gives Folded War, Icebreaker, and All Hands a first-wave breath and a pantry", () => {
    for (const id of ["5-06", "6-06", "7-05"]) {
      const level = levelById(id);
      assert.ok(pantrySecs(level) >= 100, `${id} pantry ${pantrySecs(level).toFixed(1)}s`);
      assert.ok(level.waves.first >= 24, `${id} first wave ${level.waves.first}`);
    }
  });

  it("does not ask Icebreaker to thaw ice the core heater cannot reach without a walk", () => {
    const level = levelById("6-06");
    const core = level.core || { x: 4, y: 6 };
    for (const ice of level.ice) {
      const man = Math.abs(ice.x - core.x) + Math.abs(ice.y - core.y);
      assert.ok(man <= 5, `ice ${ice.x},${ice.y} is ${man} from core`);
    }
  });
});

describe("combat audio language", () => {
  it("gives wave, flare, shoot, kill, and incoming distinct voices", () => {
    const names = ["wave", "flare", "shoot", "kill", "incoming", "cleared"];
    for (const name of names) {
      assert.ok(toneFor(name), name);
    }
    assert.notEqual(toneFor("wave").freq, toneFor("flare").freq);
    assert.notEqual(toneFor("wave").type, "sawtooth");
    assert.notEqual(toneFor("flare").type, "sawtooth");
    assert.ok(toneFor("shoot").dur <= 0.05);
    assert.ok(toneFor("kill").freq > toneFor("shoot").freq);
  });

  it("telegraphs a wave before it lands", () => {
    const m = createMatch(
      {
        ...levelById("1-04"),
        waves: { first: 9, interval: 40, count: 2, hp: 20, speed: 18, max: 1 },
        win: { corridors: 99 },
      },
      { seed: 4 }
    );
    tick(m, 1.2);
    assert.ok(
      m.events.some((e) => e.type === "incoming"),
      m.events.map((e) => e.type).join(",")
    );
  });

  it("sparks when a scout dies", () => {
    const m = createMatch(levelById("1-04"), { seed: 2 });
    m.enemies.push({
      x: 80,
      y: 80,
      hp: 0,
      maxhp: 12,
      speed: 0,
      dps: 0,
      r: 8,
      cloaked: false,
      vx: 0,
      vy: 0,
      dir: 0,
      target: null,
      state: "walking",
      hitTimer: 0,
      wobble: 0,
    });
    step(m, 0.05);
    assert.ok(m.kills >= 1, "expected a kill");
    assert.ok(m.fx.some((f) => f.kind === "burst"));
  });
});

describe("campaign still has forty-two stations", () => {
  it("did not drop a world while retuning the finale", () => {
    assert.equal(LEVELS.length, 42);
    assert.equal(levelById("7-06").id, "7-06");
  });
});

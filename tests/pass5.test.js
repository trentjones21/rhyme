import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { LEVELS, levelById } from "../js/levels.js";
import {
  createMatch,
  step,
  tapCell,
  setTool,
  canPlace,
  coreStock,
  pause,
  assignTo,
  resumeThink,
  coachText,
} from "../js/sim.js";

function tick(match, seconds) {
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

describe("Last Geometry holds time for a slow thumb", () => {
  it("starts thinking, not paused, so placing still works", () => {
    const m = createMatch(levelById("7-06"), { seed: 11 });
    assert.equal(m.status, "playing");
    assert.equal(m.thinkLocked, true);
    assert.equal(levelById("7-06").mechanics.thinkStart, true);
    assert.equal(placeType(m, "scanner"), true);
    assert.ok(m.rooms.some((r) => r.type === "scanner"));
  });

  it("does not eat pantry or march the first wave while you think", () => {
    const m = createMatch(levelById("7-06"), { seed: 11 });
    const food0 = coreStock(m, "food");
    const wave0 = m.waves.timer;
    const flare0 = m.flare.timer;
    tick(m, 45);
    assert.equal(m.thinkLocked, true);
    assert.equal(m.time, 0);
    assert.equal(coreStock(m, "food"), food0);
    assert.equal(m.waves.timer, wave0);
    assert.equal(m.flare.timer, flare0);
    assert.equal(m.enemies.length, 0);
  });

  it("lets Resume start the clock without opening the pause overlay", () => {
    const m = createMatch(levelById("7-06"), { seed: 11 });
    assert.equal(resumeThink(m), true);
    assert.equal(m.thinkLocked, false);
    assert.equal(m.status, "playing");
    tick(m, 2);
    assert.ok(m.time >= 1.9);
    assert.ok(coreStock(m, "food") < 18);
    assert.ok(m.waves.timer < 40);
  });

  it("keeps the pause menu as a separate freeze that blocks placement", () => {
    const m = createMatch(levelById("7-06"), { seed: 11 });
    resumeThink(m);
    pause(m);
    assert.equal(m.status, "paused");
    setTool(m, "scanner");
    assert.equal(placeType(m, "scanner"), false);
    pause(m);
    assert.equal(m.status, "playing");
    assert.equal(placeType(m, "scanner"), true);
  });

  it("still has a pantry after a long think plus a hull kit", () => {
    const m = createMatch(levelById("7-06"), { seed: 11 });
    tick(m, 30);
    assert.equal(placeType(m, "scanner"), true);
    assert.equal(placeType(m, "weapons"), true);
    assert.equal(placeType(m, "shield"), true);
    resumeThink(m);
    tick(m, 3);
    assert.ok(coreStock(m, "food") >= 16, coreStock(m, "food"));
    assert.ok(m.waves.timer > 30, m.waves.timer);
  });
});

describe("in-match coaching for the finale", () => {
  it("does not mute Last Geometry with quiet geometry", () => {
    const last = levelById("7-06");
    assert.notEqual(last.lesson, "Quiet geometry. No extra advice.");
    assert.match(last.lesson, /scan/i);
    assert.match(last.lesson, /gun/i);
    assert.match(last.lesson, /aegis/i);
    assert.match(`${last.lesson} ${last.briefing} ${last.hint}`, /unpaid|blueprint|jam/i);
    assert.equal(last.mechanics.coach, true);
  });

  it("teaches Scan, then Gun, then Aegis, then the two-blueprint jam", () => {
    const m = createMatch(levelById("7-06"), { seed: 11 });
    assert.match(coachText(m), /scan/i);
    assert.equal(placeType(m, "scanner"), true);
    assert.match(coachText(m), /gun/i);
    assert.equal(placeType(m, "weapons"), true);
    assert.match(coachText(m), /aegis/i);
    assert.equal(placeType(m, "shield"), true);
    assert.equal(placeType(m, "corridor"), true);
    assert.equal(placeType(m, "corridor"), true);
    const unpaid = m.rooms.filter((r) => !r.built && r.type !== "core").length;
    assert.ok(unpaid >= 2, unpaid);
    assert.match(coachText(m), /two|unpaid|jam/i);
  });

  it("keeps coaching on screen after the first seven seconds of live time", () => {
    const hud = readFileSync(new URL("../js/app.js", import.meta.url), "utf8");
    const i = hud.indexOf("function hud(");
    const body = hud.slice(i, hud.indexOf("function renderJobs", i));
    assert.match(body, /coachText/);
    assert.equal(body.includes("if (match.time > 7) $(\"hint\").classList.remove(\"on\")"), false);
  });
});

describe("combat juice", () => {
  it("muzzle-flashes when a gun fires and sparks on impact", () => {
    const m = createMatch(levelById("1-04"), { seed: 2 });
    assert.equal(placeType(m, "weapons"), true);
    const gun = m.rooms.find((r) => r.type === "weapons");
    gun.built = true;
    gun.progress = 1;
    gun.materials = gun.def.cost;
    setTool(m, "assign");
    assignTo(m, gun);
    const gunner = m.kapsels.find((k) => k.assignment === gun.id);
    if (gunner) {
      gunner.x = gun.cx;
      gunner.y = gun.cy;
    }
    m.enemies.push({
      x: gun.cx + 40,
      y: gun.cy,
      hp: 40,
      maxhp: 40,
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
    tick(m, 0.2);
    assert.ok(m.shots.length >= 1 || m.fx.some((f) => f.kind === "muzzle" || f.kind === "spark"), "expected a shot or muzzle");
    assert.ok(
      m.fx.some((f) => f.kind === "muzzle" || f.kind === "spark"),
      m.fx.map((f) => f.kind).join(",")
    );
    tick(m, 0.4);
    assert.ok(
      m.fx.some((f) => f.kind === "spark" || f.kind === "burst" || f.kind === "impact"),
      "expected an impact spark"
    );
  });

  it("draws scanner cones, think freeze, and shot bloom", () => {
    const src = readFileSync(new URL("../js/render.js", import.meta.url), "utf8");
    assert.match(src, /drawScanCone|scanner cone|SCAN_R/);
    assert.match(src, /thinkLocked/);
    assert.match(src, /muzzle|shot bloom|impact/);
  });
});

describe("campaign still has forty-two stations", () => {
  it("did not drop a world while teaching the finale", () => {
    assert.equal(LEVELS.length, 42);
    assert.equal(levelById("7-06").id, "7-06");
  });
});

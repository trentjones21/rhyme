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
  assignTo,
  resumeThink,
  coachText,
  rotateShape,
  playerShape,
} from "../js/sim.js";

function tick(match, seconds) {
  const dt = 0.05;
  const n = Math.ceil(seconds / dt);
  for (let i = 0; i < n; i++) step(match, dt);
}

function unpaidCount(match) {
  return match.rooms.filter((r) => !r.built && r.type !== "core").length;
}

function waitUntil(match, pred, seconds = 36) {
  const t0 = match.time;
  while (!pred(match) && match.status === "playing" && match.time - t0 < seconds) tick(match, 0.5);
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

function cellsAt(match, type, x, y, rot) {
  return rotateShape(playerShape(match, type), rot).map(([dx, dy]) => ({ x: x + dx, y: y + dy }));
}

function kissScore(match, cells) {
  let score = 0;
  let minMan = Infinity;
  for (const relic of match.relics) {
    if (relic.linked) continue;
    for (const c of cells) {
      const man = Math.abs(c.x - relic.x) + Math.abs(c.y - relic.y);
      minMan = Math.min(minMan, man);
      if (man <= 1) score += 80;
    }
  }
  return score * 1000 - minMan;
}

function tryPlaceTowardRelic(match) {
  setTool(match, "corridor");
  let best = null;
  const saved = match.rot;
  for (let rot = 0; rot < 4; rot++) {
    match.rot = rot;
    for (let y = 0; y < match.rows; y++) {
      for (let x = 0; x < match.cols; x++) {
        if (!canPlace(match, "corridor", x, y, rot)) continue;
        const sc = kissScore(match, cellsAt(match, "corridor", x, y, rot));
        if (!best || sc > best.sc) best = { x, y, rot, sc };
      }
    }
  }
  match.rot = saved;
  if (!best) return false;
  match.rot = best.rot;
  return tapCell(match, best.x, best.y);
}

function surveyRelics(match) {
  for (let n = 0; n < 24; n++) {
    const linked = match.relics.filter((r) => r.linked).length;
    if (linked >= 4) return linked;
    const unpaid = match.rooms.filter((r) => !r.built && r.type !== "core").length;
    if (unpaid >= 2) {
      tick(match, 6);
      continue;
    }
    if (coreStock(match, "mineral") < 4) {
      tick(match, 4);
      continue;
    }
    if (!tryPlaceTowardRelic(match)) {
      tick(match, 4);
      continue;
    }
    tick(match, 5);
  }
  tick(match, 12);
  return match.relics.filter((r) => r.linked).length;
}

function hullKit(match) {
  assert.equal(placeType(match, "scanner"), true);
  assert.equal(placeType(match, "weapons"), true);
  assert.equal(placeType(match, "shield"), true);
}

describe("greedy survey does not starve a late kitchen", () => {
  it("turns core sludge into meals before anyone dies of hunger", () => {
    const m = createMatch(levelById("7-06"), { seed: 11 });
    hullKit(m);
    resumeThink(m);
    tick(m, 8);
    m.core.stock.food = 0;
    m.core.stock.biomass = 3;
    tick(m, 5);
    assert.ok(coreStock(m, "food") > 0, `pantry ${coreStock(m, "food")} with sludge sitting idle`);
    assert.notEqual(m.loseReason, "Your crew starved");
    assert.equal(m.kapsels.length, 6);
  });

  it("keeps a staffed garden feeding the pantry when the kitchen is still a wish", () => {
    const m = createMatch(levelById("7-06"), { seed: 11 });
    hullKit(m);
    resumeThink(m);
    waitUntil(m, (x) => unpaidCount(x) < 2, 40);
    assert.equal(placeType(m, "garden"), true);
    waitUntil(m, (x) => x.rooms.some((r) => r.type === "garden" && r.built), 40);
    const garden = m.rooms.find((r) => r.type === "garden" && r.built);
    assert.ok(garden, "garden never built");
    setTool(m, "assign");
    assignTo(m, garden);
    const food0 = coreStock(m, "food");
    tick(m, 36);
    const grown = (garden.stock.food || 0) + (garden.stock.biomass || 0);
    const hauled = coreStock(m, "food") + (m.core.stock.biomass || 0);
    assert.ok(grown + hauled > food0, `garden grew nothing; pantry ${coreStock(m, "food")} sludge ${m.core.stock.biomass || 0}`);
    m.core.stock.food = 0.4;
    tick(m, 8);
    assert.ok(coreStock(m, "food") > 0.5, `late kitchen left the pantry at ${coreStock(m, "food")}`);
    assert.notEqual(m.loseReason, "Your crew starved");
  });

  it("survives a greedy four-relic survey with no garden and no kitchen", () => {
    const m = createMatch(levelById("7-06"), { seed: 11 });
    hullKit(m);
    resumeThink(m);
    tick(m, 10);
    const linked = surveyRelics(m);
    assert.equal(linked, 4, `only ${linked} relics`);
    assert.equal(
      m.rooms.some((r) => r.type === "garden" || r.type === "kitchen"),
      false,
      "survey grew food rooms"
    );
    while (m.time < 220 && m.status === "playing") tick(m, 2);
    assert.notEqual(m.loseReason, "Your crew starved");
    assert.ok(coreStock(m, "food") > 0, `pantry empty at t=${m.time.toFixed(1)}`);
  });
});

describe("coach food before monuments", () => {
  it("tells the finale to plant meals before kissing relics", () => {
    const last = levelById("7-06");
    assert.match(`${last.lesson} ${last.briefing} ${last.hint}`, /garden|kitchen|food|meal|pantry/i);
    const m = createMatch(last, { seed: 11 });
    hullKit(m);
    resumeThink(m);
    waitUntil(m, (x) => unpaidCount(x) < 2, 40);
    const unpaid = unpaidCount(m);
    assert.ok(unpaid < 2, unpaid);
    const line = coachText(m);
    assert.match(line, /garden|kitchen|food|meal|pantry/i);
    assert.match(line, /monument|relic|survey/i);
    assert.doesNotMatch(line, /^Kiss the four monuments/i);
  });
});

describe("look and juice for mid-campaign stations", () => {
  it("rings a monument when the survey kisses it", () => {
    const m = createMatch(levelById("4-01"), { seed: 3 });
    for (let n = 0; n < 12 && m.relics.filter((r) => r.linked).length < 1; n++) {
      if (unpaidCount(m) >= 2) {
        tick(m, 2);
        continue;
      }
      tryPlaceTowardRelic(m);
      tick(m, 0.8);
    }
    assert.equal(m.relics.filter((r) => r.linked).length, 1);
    assert.ok(m.events.some((e) => e.type === "relic"));
    assert.ok(
      m.fx.some((f) => f.kind === "pulse" || f.kind === "burst" || f.kind === "kiss"),
      m.fx.map((f) => f.kind).join(",")
    );
  });

  it("draws relic halos, gate folds, and a hungry pantry", () => {
    const render = readFileSync(new URL("../js/render.js", import.meta.url), "utf8");
    const app = readFileSync(new URL("../js/app.js", import.meta.url), "utf8");
    const css = readFileSync(new URL("../css/rhyme.css", import.meta.url), "utf8");
    const audio = readFileSync(new URL("../js/audio.js", import.meta.url), "utf8");
    assert.equal(/relicHalo|kissRing/.test(render), true, "render missing relic halo");
    assert.equal(/gateFold|foldRing/.test(render), true, "render missing gate fold");
    assert.equal(app.includes("hunger"), true, "hud missing pantry hunger");
    assert.equal(css.includes("hunger"), true, "css missing pantry hunger");
    assert.equal(/relic:/.test(audio), true, "audio missing relic tone");
  });

  it("still has forty-two stations and a kitchen-chain living archive", () => {
    assert.equal(LEVELS.length, 42);
    const living = levelById("4-05");
    assert.match(living.lesson, /eat|food|kitchen|garden/i);
    assert.equal(living.win.relics, 3);
    assert.ok(living.win.food >= 4);
  });
});

function staffHull(match) {
  setTool(match, "assign");
  for (const type of ["scanner", "weapons", "shield", "garden", "kitchen"]) {
    const room = match.rooms.find((r) => r.type === type && !r.dead);
    if (!room) continue;
    if (!match.kapsels.some((k) => k.assignment === room.id)) assignTo(match, room);
  }
}

function thumbFinale() {
  const match = createMatch(levelById("7-06"), { seed: 11 });
  hullKit(match);
  resumeThink(match);
  while (match.time < 240 && match.status === "playing") {
    staffHull(match);
    if (unpaidCount(match) >= 2 || coreStock(match, "mineral") < 4) {
      tick(match, 2);
      continue;
    }
    if (!match.rooms.some((r) => r.type === "garden" && !r.dead)) {
      placeType(match, "garden");
      tick(match, 1);
      continue;
    }
    if (!match.rooms.some((r) => r.type === "kitchen" && !r.dead)) {
      placeType(match, "kitchen");
      tick(match, 1);
      continue;
    }
    if (match.relics.filter((r) => r.linked).length < 4) {
      tryPlaceTowardRelic(match);
      tick(match, 1);
      continue;
    }
    const guns = match.rooms.filter((r) => r.type === "weapons" && !r.dead).length;
    if (match.enemies.length >= 3 && guns < 2) {
      placeType(match, "weapons");
      tick(match, 1);
      continue;
    }
    tick(match, 2);
  }
  return match;
}

describe("a garden-first thumb wins Last Geometry", () => {
  it("lets a hull gun reach scouts parked on the finale well", () => {
    const m = createMatch(levelById("7-06"), { seed: 11 });
    hullKit(m);
    resumeThink(m);
    waitUntil(m, (x) => x.rooms.some((r) => r.type === "weapons" && r.built), 40);
    const gun = m.rooms.find((r) => r.type === "weapons" && r.built);
    assert.ok(gun, "gun never built");
    setTool(m, "assign");
    assignTo(m, gun);
    const gunner = m.kapsels.find((k) => k.assignment === gun.id);
    if (gunner) {
      gunner.x = gun.cx;
      gunner.y = gun.cy;
    }
    const well = m.wells[0];
    const px = m.layout.ox + (well.x + 0.5) * m.layout.cell;
    const py = m.layout.oy + (well.y + 0.5) * m.layout.cell;
    const reach = Math.hypot(px - gun.cx, py - gun.cy);
    assert.ok(reach < 250, `well is ${reach.toFixed(0)}px from the hull gun`);
    m.enemies.push({
      x: px,
      y: py,
      hp: 24,
      maxhp: 24,
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
    assert.ok(m.shots.length >= 1 || m.shotsFired >= 1, "gun cannot see the well");
  });

  it("wins 7-06 without captainBeat if meals go down before monuments", () => {
    const m = thumbFinale();
    assert.equal(
      m.status,
      "won",
      `${m.status} ${m.loseReason || m.winReason} t=${m.time.toFixed(1)} relics=${m.relics.filter((r) => r.linked).length} waves=${m.wavesCleared} food=${coreStock(m, "food")} deaths=${m.deaths}`
    );
    assert.equal(m.relics.filter((r) => r.linked).length, 4);
    assert.ok(m.wavesCleared >= 4, m.wavesCleared);
    assert.ok(m.stars >= 2, m.stars);
  });
});

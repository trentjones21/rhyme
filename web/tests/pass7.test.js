import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { LEVELS, WORLDS, levelById, worldLook, roomLabel } from "../js/levels.js";
import {
  createMatch,
  step,
  tapCell,
  setTool,
  canPlace,
  coreStock,
  assignTo,
  captainBeat,
  resumeThink,
  objectiveText,
} from "../js/sim.js";
import { toneFor } from "../js/audio.js";

function tick(match, seconds) {
  if (match.thinkLocked) resumeThink(match);
  const dt = 0.05;
  const n = Math.ceil(seconds / dt);
  for (let i = 0; i < n; i++) step(match, dt);
}

function pantrySecs(level) {
  const crew = level.start.crew || 1;
  return level.start.food / (level.eatRate * crew);
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

function captainPlay(id, limit = 160) {
  const m = createMatch(levelById(id), { seed: 11 });
  while (m.status === "playing" && m.time < limit) {
    captainBeat(m);
    tick(m, 0.4);
  }
  return m;
}

describe("mid-campaign stations are not already won by the opening pantry", () => {
  it("makes Sludge cook past the starting meals", () => {
    const l = levelById("2-01");
    assert.ok(l.win.food > l.start.food, "2-01 win food " + l.win.food + " start " + l.start.food);
    assert.ok(l.win.rooms.kitchen >= 1);
    assert.ok(l.win.rooms.garden >= 1);
  });

  it("makes Long Haul actually tax the far vein", () => {
    const l = levelById("2-02");
    assert.ok(l.win.mineral >= l.start.minerals + 6, "2-02 mineral win " + l.win.mineral);
    assert.ok(l.start.minerals >= 20, l.start.minerals);
  });

  it("makes Two Kitchens require a galley, not just waiting", () => {
    const l = levelById("2-03");
    assert.ok(l.win.rooms && l.win.rooms.kitchen >= 1, "2-03 kitchen optional");
    assert.ok(l.win.food > l.start.food + 2, l.win.food);
  });

  it("makes Exposed Vein mine, not cash the opening bank", () => {
    const l = levelById("3-03");
    assert.ok(l.win.mineral > l.start.minerals, "3-03 mineral " + l.win.mineral + " start " + l.start.minerals);
  });

  it("makes Three Nodes haul from the island, not sit on 16 minerals", () => {
    const l = levelById("5-04");
    assert.ok(l.win.mineral > l.start.minerals, "5-04 mineral " + l.win.mineral);
    assert.ok(l.win.rooms.gate >= 3);
  });
});

describe("hungry and flare stations are fair at portrait pace", () => {
  it("gives Hungry Shift time to cook before minting a seventh mouth", () => {
    const l = levelById("2-05");
    assert.ok(pantrySecs(l) >= 120, "2-05 starves in " + pantrySecs(l).toFixed(1) + "s");
    assert.ok(l.win.crew > l.start.crew);
  });

  it("lets Convoy feed three waves without a furnace eatRate", () => {
    const l = levelById("2-06");
    assert.ok(pantrySecs(l) >= 110, "2-06 starves in " + pantrySecs(l).toFixed(1) + "s");
    assert.ok(l.waves.first >= 24, l.waves.first);
    assert.equal(l.win.surviveWaves, 3);
  });

  it("gives Umbrella time to raise a shield before the first bite", () => {
    const l = levelById("3-02");
    assert.ok(l.mechanics.flares.first >= 16, l.mechanics.flares.first);
    assert.ok(l.mechanics.flares.damage <= 13, l.mechanics.flares.damage);
  });

  it("stops Glass House from cooking a compact kitchen on the first breath", () => {
    const l = levelById("3-05");
    assert.ok(l.mechanics.flares.first >= 15, l.mechanics.flares.first);
    assert.ok(pantrySecs(l) >= 110, pantrySecs(l));
    assert.ok(l.win.food > l.start.food);
  });

  it("lets Slow Patrol staff a gun before frost delays the walk", () => {
    const l = levelById("6-03");
    assert.ok(l.waves.first >= 20, l.waves.first);
  });

  it("gives Frozen Garden a pantry that outlasts the commute", () => {
    const l = levelById("6-04");
    assert.ok(pantrySecs(l) >= 90, pantrySecs(l));
    assert.ok(l.win.food >= 6);
  });
});

describe("mute lessons speak again", () => {
  it("tells Thaw that a built heater writes water, matching the sim", () => {
    const l = levelById("6-02");
    assert.doesNotMatch(`${l.hint} ${l.lesson}`, /nothing empty|does nothing empty/i);
    assert.match(`${l.lesson} ${l.briefing} ${l.hint}`, /built|once it is built|writes water/i);
  });

  it("keeps Narrow Dock threading the void, not a quiet gun drill", () => {
    const l = levelById("2-04");
    assert.ok(l.blocked.length >= 4);
    assert.ok(l.win.rooms.weapons >= 1);
    assert.match(`${l.lesson} ${l.briefing}`, /asteroid|thread|void|block/i);
  });
});

describe("world identity", () => {
  it("gives every world its own accent, sky, and stinger", () => {
    const accents = new Set();
    const stingers = new Set();
    const inners = new Set();
    for (const world of WORLDS) {
      const look = worldLook(world.id);
      assert.ok(look.accent, world.name);
      assert.ok(look.stinger, world.name);
      assert.ok(look.nebula0, world.name);
      assert.ok(look.haze, world.name);
      accents.add(look.accent);
      stingers.add(look.stinger);
      inners.add(look.nebula0);
      assert.ok(toneFor(look.stinger), "missing tone " + look.stinger);
    }
    assert.equal(accents.size, 7);
    assert.equal(stingers.size, 7);
    assert.equal(inners.size, 7);
  });

  it("names rooms in the world's tongue", () => {
    assert.equal(roomLabel("kitchen", 2), "Galley");
    assert.match(roomLabel("shield", 3), /umbrella|aegis|shade/i);
    assert.match(roomLabel("corridor", 4), /shore|road|spine/i);
    assert.match(roomLabel("gate", 5), /fold/i);
    assert.match(roomLabel("heater", 6), /hearth|brazier|thaw/i);
    assert.equal(roomLabel("kitchen", 1), "Kitchen");
  });

  it("prints Galley on a Supply Lines objective", () => {
    const m = createMatch(levelById("2-01"), { seed: 3 });
    assert.equal(placeType(m, "kitchen"), true);
    tick(m, 8);
    assert.match(objectiveText(m), /Galley/);
  });

  it("tints the play shell and renderer per world", () => {
    const css = readFileSync(new URL("../css/rhyme.css", import.meta.url), "utf8");
    assert.match(css, /#play\[data-world="2"\]/);
    assert.match(css, /#play\[data-world="6"\]/);
    const render = readFileSync(new URL("../js/render.js", import.meta.url), "utf8");
    assert.match(render, /worldLook/);
    const app = readFileSync(new URL("../js/app.js", import.meta.url), "utf8");
    assert.match(app, /dataset\.world/);
    assert.match(app, /worldLook/);
  });
});

describe("Rymdkapsel minion feel", () => {
  it("fans kapsels that share a tile into a crowd instead of a stack", () => {
    const m = createMatch(levelById("2-01"), { seed: 2 });
    const x = m.kapsels[0].x;
    const y = m.kapsels[0].y;
    for (const k of m.kapsels) {
      k.x = x;
      k.y = y;
      k.path = [];
      k.job = null;
      k.state = "idle";
    }
    step(m, 0.05);
    const slots = m.kapsels.map((k) => `${(k.ox || 0).toFixed(2)},${(k.oy || 0).toFixed(2)}`);
    assert.equal(new Set(slots).size, m.kapsels.length, slots.join(" | "));
    assert.ok(
      m.kapsels.some((k) => Math.hypot(k.ox || 0, k.oy || 0) > 4),
      "crowd radius collapsed"
    );
  });

  it("rings the room when a kapsel is assigned", () => {
    const m = createMatch(levelById("2-01"), { seed: 3 });
    assert.equal(placeType(m, "garden"), true);
    const garden = m.rooms.find((r) => r.type === "garden");
    m.fx = [];
    assert.equal(assignTo(m, garden), true);
    assert.ok(
      m.fx.some((f) => f.kind === "pulse" || f.kind === "assign"),
      "assign left no juice: " + m.fx.map((f) => f.kind).join(",")
    );
    assert.ok(m.events.some((e) => e.type === "assign"));
  });

  it("drops a haul trail while a kapsel carries meals", () => {
    const m = createMatch(levelById("1-02"), { seed: 1 });
    assert.equal(placeType(m, "garden"), true);
    const garden = m.rooms.find((r) => r.type === "garden");
    assignTo(m, garden);
    tick(m, 28);
    assignTo(m, garden);
    let trails = 0;
    for (let i = 0; i < 500; i++) {
      step(m, 0.05);
      trails = Math.max(trails, (m.trails || []).length);
      if (trails > 0) break;
    }
    assert.ok(trails > 0, "hauling left no trail after " + m.time.toFixed(1) + "s");
  });
});

describe("captain can still finish the retuned openers", () => {
  it("wins Sludge, First Flare, First Relic, Shortcut, and Thaw", () => {
    for (const id of ["2-01", "3-01", "4-01", "5-01", "6-02"]) {
      const m = captainPlay(id, 140);
      assert.equal(m.status, "won", `${id} ${m.status} ${m.loseReason || ""} t=${m.time.toFixed(1)}`);
    }
  });
});

describe("campaign still has forty-two stations", () => {
  it("did not drop a mid-world board", () => {
    assert.equal(LEVELS.length, 42);
    for (const world of WORLDS) {
      assert.equal(LEVELS.filter((l) => l.world === world.id).length, 6, world.name);
    }
  });
});

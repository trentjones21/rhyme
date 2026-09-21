import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { LEVELS, WORLDS, levelById, nextLevel, levelsInWorld } from "../js/levels.js";
import { createMatch, step, setTool, tapCell, assignTo, roomAt } from "../js/sim.js";
import { loadSave, completeLevel, worldUnlocked, campaignStats } from "../js/save.js";

describe("campaign data", () => {
  it("has seven worlds and at least thirty-six levels", () => {
    assert.equal(WORLDS.length, 7);
    assert.ok(LEVELS.length >= 36, LEVELS.length);
  });

  it("uses unique ids and a win condition on every level", () => {
    const ids = new Set();
    for (const level of LEVELS) {
      assert.ok(level.id, level.name);
      assert.equal(ids.has(level.id), false, level.id);
      ids.add(level.id);
      assert.ok(level.win && Object.keys(level.win).length > 0, level.id);
      assert.ok(level.allowed.length >= 1);
    }
  });

  it("unlocks sequentially along nextLevel", () => {
    assert.equal(LEVELS[0].id, "1-01");
    assert.equal(nextLevel("1-01").id, "1-02");
    assert.equal(nextLevel("1-06").id, "2-01");
    assert.equal(nextLevel("7-06"), null);
  });

  it("groups six levels per world", () => {
    for (const world of WORLDS) {
      assert.equal(levelsInWorld(world.id).length, 6, world.name);
    }
  });
});

describe("save", () => {
  it("starts with only the first station unlocked", () => {
    const mem = new Map();
    const storage = {
      getItem: (k) => mem.get(k) || null,
      setItem: (k, v) => mem.set(k, v),
    };
    const save = loadSave(storage);
    assert.equal(save.unlocked["1-01"], true);
    assert.equal(worldUnlocked(save, 2, LEVELS), false);
    completeLevel(save, "1-01", 2, "1-02");
    assert.equal(save.stars["1-01"], 2);
    assert.equal(save.unlocked["1-02"], true);
    const stats = campaignStats(save, LEVELS);
    assert.equal(stats.cleared, 1);
  });
});

describe("level boot", () => {
  it("creates every level without throwing", () => {
    for (const level of LEVELS) {
      const m = createMatch(level, { seed: 3 });
      assert.equal(m.status, "playing", level.id);
      assert.ok(m.kapsels.length >= 1, level.id);
      step(m, 0.05);
      assert.equal(m.status, "playing", level.id + " after tick");
    }
  });

  it("is not already won at t=0", () => {
    for (const level of LEVELS) {
      const m = createMatch(level, { seed: 3 });
      assert.notEqual(m.status, "won", level.id);
    }
  });

  it("can finish Spine by building three corridors", () => {
    const m = createMatch(levelById("1-01"), { seed: 1 });
    setTool(m, "corridor");
    assert.equal(tapCell(m, 4, 4), true);
    assert.equal(assignTo(m, roomAt(m, 4, 4)), true);
    setTool(m, "corridor");
    assert.equal(tapCell(m, 4, 8), true);
    assert.equal(tapCell(m, 2, 6), true);
    for (let i = 0; i < 500; i++) step(m, 0.05);
    assert.equal(m.status, "won");
    assert.ok(m.stars >= 1);
  });
});

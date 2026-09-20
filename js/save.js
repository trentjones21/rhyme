const KEY = "rhyme-save-v1";

function empty() {
  return {
    unlocked: { "1-01": true },
    stars: {},
    last: "1-01",
    seenHow: false,
  };
}

export function loadSave(storage) {
  const store = storage || (typeof localStorage !== "undefined" ? localStorage : null);
  if (!store) return empty();
  try {
    const raw = store.getItem(KEY);
    if (!raw) return empty();
    const data = JSON.parse(raw);
    return {
      unlocked: { "1-01": true, ...(data.unlocked || {}) },
      stars: data.stars || {},
      last: data.last || "1-01",
      seenHow: !!data.seenHow,
    };
  } catch {
    return empty();
  }
}

export function writeSave(save, storage) {
  const store = storage || (typeof localStorage !== "undefined" ? localStorage : null);
  if (!store) return save;
  store.setItem(KEY, JSON.stringify(save));
  return save;
}

export function completeLevel(save, levelId, stars, nextId) {
  save.stars[levelId] = Math.max(save.stars[levelId] || 0, stars || 1);
  save.last = levelId;
  if (nextId) save.unlocked[nextId] = true;
  return save;
}

export function isUnlocked(save, levelId) {
  return !!save.unlocked[levelId];
}

export function worldUnlocked(save, world, levels) {
  if (world <= 1) return true;
  const prev = levels.filter((l) => l.world === world - 1);
  return prev.every((l) => save.stars[l.id]);
}

export function campaignStats(save, levels) {
  const cleared = levels.filter((l) => save.stars[l.id]).length;
  const starTotal = levels.reduce((n, l) => n + (save.stars[l.id] || 0), 0);
  return { cleared, total: levels.length, starTotal, starMax: levels.length * 3 };
}

import {
  createMatch,
  step,
  tapCell,
  setTool,
  rotate,
  pause,
  computeLayout,
  remapLayout,
  gridAt,
  objectiveText,
  paletteFor,
  coreStock,
  canPlace,
  rotateShape,
  ROOMS,
  recall,
  jobChips,
  playerShape,
  fitPiece,
  holdPiece,
  resumeThink,
  coachText,
  captainBeat,
} from "./sim.js";
import { LEVELS, WORLDS, levelById, nextLevel, levelsInWorld } from "./levels.js";
import { loadSave, writeSave, completeLevel, worldUnlocked, campaignStats } from "./save.js";
import { drawWorld } from "./render.js";
import * as audio from "./audio.js";
import { shouldShowInstallHint } from "./install.js";
import { endOverlaySpec } from "./overlay.js";

const $ = (id) => document.getElementById(id);
const screens = ["title", "worlds", "levels", "brief", "play", "how"];

let save = loadSave();
let screen = "title";
let worldId = 1;
let chosen = LEVELS[0];
let match = null;
let speed = 1;
let last = performance.now();
let ghost = null;
let ended = false;

function show(name) {
  screen = name;
  for (const id of screens) $(id).classList.toggle("on", id === name);
  if (name === "play") resize();
}

function buzz(ms) {
  try {
    if (navigator.vibrate) navigator.vibrate(ms);
  } catch (_) {
    /* ignore locked vibration */
  }
}

function isStandalone() {
  return window.matchMedia("(display-mode: standalone)").matches || window.navigator.standalone === true;
}

function isIOS() {
  const ua = navigator.userAgent || "";
  return /iPhone|iPad|iPod/i.test(ua) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
}

const CHIP_HUE = {
  wait: "#8d93a3",
  haul: "#e07898",
  build: "#8d6b4a",
  grow: "#5ea86a",
  mine: "#d56b8c",
  cook: "#f0c24a",
  berth: "#d4844a",
  gun: "#7b88a3",
  heat: "#e07a4a",
  scan: "#70b4e0",
  walk: "#c8c2b4",
};

function renderTitle() {
  const st = campaignStats(save, LEVELS);
  $("progressLine").textContent = `${st.cleared}/${st.total} stations  ·  ${st.starTotal} stars`;
}

function renderWorlds() {
  const list = $("worldList");
  list.innerHTML = "";
  for (const world of WORLDS) {
    const open = worldUnlocked(save, world.id, LEVELS);
    const levels = levelsInWorld(world.id);
    const done = levels.filter((l) => save.stars[l.id]).length;
    const b = document.createElement("button");
    b.className = "card";
    b.disabled = !open;
    b.innerHTML = `<b>${world.id}  ·  ${world.name}</b><span>${open ? world.blurb : "Clear the previous shore first."}  ${done}/6</span>`;
    b.onclick = () => {
      worldId = world.id;
      renderLevels();
      show("levels");
      audio.play("tap");
    };
    list.appendChild(b);
  }
}

function renderLevels() {
  const world = WORLDS.find((w) => w.id === worldId);
  $("worldTitle").textContent = world.name.toUpperCase();
  const list = $("levelList");
  list.innerHTML = "";
  for (const level of levelsInWorld(worldId)) {
    const b = document.createElement("button");
    b.className = "level";
    b.disabled = !save.unlocked[level.id];
    const stars = save.stars[level.id] ? "★".repeat(save.stars[level.id]) + "☆".repeat(3 - save.stars[level.id]) : "☆☆☆";
    b.innerHTML = `<span class="id">${level.id}</span><span style="flex:1">${level.name}</span><span class="stars">${stars}</span>`;
    b.onclick = () => {
      openBrief(level);
      audio.play("tap");
    };
    list.appendChild(b);
  }
}

function openBrief(level) {
  chosen = level;
  $("briefId").textContent = level.id;
  $("briefLesson").textContent = level.lesson || "";
  $("briefName").textContent = level.name;
  $("briefBody").textContent = level.briefing || "";
  show("brief");
}

function startLevel(level) {
  chosen = level;
  ended = false;
  speed = 1;
  $("speed").textContent = "1×";
  $("pauseOv").classList.remove("on");
  $("endOv").classList.remove("on");
  $("endRetry").hidden = false;
  $("play").classList.remove("ended");
  match = createMatch(level, { seed: (Date.now() % 9999) + 1 });
  show("play");
  buildTools();
  resize();
  $("play").classList.toggle("thinking", !!match.thinkLocked);
  const opening = coachText(match) || level.hint || level.lesson || "";
  $("hint").textContent = opening;
  $("hint").classList.toggle("on", !!opening);
  $("hint").classList.toggle("coach", !!opening);
  $("hint").classList.remove("lesson");
  audio.play("place");
}

function buildTools() {
  const tools = paletteFor(chosen);
  const labels = {
    assign: "Tap",
    salvage: "Wreck",
    overload: "Over",
    corridor: "Hall",
    garden: "Grow",
    extractor: "Mine",
    weapons: "Gun",
    kitchen: "Cook",
    quarters: "Berth",
    shield: "Aegis",
    gate: "Gate",
    heater: "Heat",
    scanner: "Scan",
    beacon: "Beac",
  };
  const el = $("tools");
  el.innerHTML = "";
  for (const tool of tools) {
    const b = document.createElement("button");
    b.className = "tool" + (match.tool === tool ? " on" : "");
    b.dataset.tool = tool;
    const hue = ROOMS[tool] ? ROOMS[tool].hue : tool === "assign" ? "#f3f0e8" : "#e24b52";
    b.innerHTML = `<span class="swatch" style="background:${hue}"></span>${labels[tool] || tool}`;
    b.onclick = () => {
      if (match.tutorial && match.tutorial.needAssign && tool !== "assign") return;
      setTool(match, tool);
      for (const c of el.children) c.classList.toggle("on", c.dataset.tool === match.tool);
      audio.play("tap");
      buzz(8);
    };
    if (match.tutorial && match.tutorial.needAssign && tool !== "assign") b.disabled = true;
    el.appendChild(b);
  }
}

function hud() {
  if (!match) return;
  $("mineralN").textContent = Math.floor(coreStock(match, "mineral"));
  $("foodN").textContent = Math.floor(coreStock(match, "food"));
  const pantry = $("foodN").closest(".stat");
  if (pantry) pantry.classList.toggle("hunger", coreStock(match, "food") < 5 || match.starve > 1);
  $("crewN").textContent = match.kapsels.length;
  const wave = $("waveN");
  $("play").classList.toggle("thinking", !!match.thinkLocked);
  const speedBtn = $("speed");
  if (match.thinkLocked) {
    speedBtn.textContent = "GO";
    speedBtn.classList.add("go");
  } else {
    speedBtn.textContent = speed + "×";
    speedBtn.classList.remove("go");
  }
  if (match.thinkLocked) {
    wave.textContent = "Think";
    wave.classList.remove("hot");
  } else if (match.enemies.length) {
    wave.textContent = "Defend";
    wave.classList.add("hot");
  } else if (match.waves.timer < 900) {
    const s = Math.max(0, Math.ceil(match.waves.timer));
    wave.textContent = match.waves.index === 0 ? `First ${s}s` : `Wave ${match.waves.index + 1}  ${s}s`;
    wave.classList.toggle("hot", s <= 8);
  } else {
    wave.textContent = "Quiet";
    wave.classList.remove("hot");
  }
  $("objective").textContent = objectiveText(match);
  renderJobs();
  renderBag();
  const hold = $("holdBtn");
  if (hold) {
    const bag = !!(match.mechanics && match.mechanics.pieceQueue);
    hold.hidden = !bag;
    hold.disabled = !bag;
    hold.classList.toggle("on", !!(match.held && bag));
  }
  if (match.tutorial && match.tutorial.needAssign) {
    match.tutorial.lockedUi = true;
    $("hint").textContent = match.mechanics.teachStaff
      ? "The garden is built. Tap it — not the kapsel."
      : "Tap the blueprint to send a kapsel. That is the whole game.";
    $("hint").classList.add("on", "lesson");
    if (match.tool !== "assign") setTool(match, "assign");
    const on = document.querySelector("#tools .tool.on");
    if (!on || on.dataset.tool !== "assign") buildTools();
  } else {
    $("hint").classList.remove("lesson");
    if (match.tutorial && match.tutorial.lockedUi) {
      match.tutorial.lockedUi = false;
      buildTools();
    } else if (match.tutorial && match.tutorial.assigned && !match.tutorial.unlockedUi) {
      match.tutorial.unlockedUi = true;
      buildTools();
    }
    const coach = coachText(match);
    if (coach) {
      $("hint").textContent = coach;
      $("hint").classList.add("on", "coach");
    } else {
      $("hint").classList.remove("coach");
      if (!match.mechanics.coach && match.time > 7) $("hint").classList.remove("on");
    }
  }
}

function renderJobs() {
  const el = $("jobs");
  if (!el || !match) return;
  const chips = jobChips(match);
  el.innerHTML = chips
    .map((c) => `<span class="chip ${c.id}"><i style="background:${CHIP_HUE[c.id] || "#f3f0e8"}"></i><b>${c.n}</b> ${c.label}</span>`)
    .join("");
}

function renderBag() {
  const el = $("bag");
  if (!el || !match) return;
  if (!match.mechanics.pieceQueue || !match.piece) {
    el.hidden = true;
    el.innerHTML = "";
    return;
  }
  el.hidden = false;
  const mini = (name, next) => {
    const on = new Set(fitPiece(name).map(([x, y]) => `${x},${y}`));
    let html = `<div class="mini${next ? " next" : ""}" aria-label="${next ? "Next" : "Now"} ${name}">`;
    for (let y = 0; y < 4; y++) {
      for (let x = 0; x < 4; x++) {
        html += `<b class="${on.has(x + "," + y) ? "on" : ""}"></b>`;
      }
    }
    return html + "</div>";
  };
  const emptyMini = () => {
    let html = `<div class="mini next" aria-label="Hold empty">`;
    for (let i = 0; i < 16; i++) html += "<b></b>";
    return html + "</div>";
  };
  const holdMini = match.held
    ? `<div class="holdslot">${mini(match.held, true)}<em>Hold</em></div>`
    : `<div class="holdslot empty">${emptyMini()}<em>Hold</em></div>`;
  el.innerHTML =
    holdMini + mini(match.piece, false) + (match.queue || []).slice(0, 2).map((n) => mini(n, true)).join("");
}

function resize() {
  const canvas = $("stage");
  if (!canvas) return;
  const wrap = $("stagewrap");
  const w = wrap.clientWidth;
  const h = wrap.clientHeight;
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  canvas.width = Math.max(1, Math.floor(w * dpr));
  canvas.height = Math.max(1, Math.floor(h * dpr));
  canvas.style.width = w + "px";
  canvas.style.height = h + "px";
  if (match) {
    const layout = computeLayout(w, h, match.cols, match.rows, { top: 8, bottom: 8, left: 8, right: 8 });
    remapLayout(match, layout);
  }
}

let lastShootAt = 0;

function consumeEvents() {
  if (!match) return;
  for (const ev of match.events) {
    if (ev.type === "place") audio.play("place");
    if (ev.type === "assign") {
      audio.play("assign");
      buzz(12);
    }
    if (ev.type === "built") audio.play("built");
    if (ev.type === "incoming") {
      audio.play("incoming");
      buzz(8);
    }
    if (ev.type === "wave") {
      audio.play("wave");
      buzz([16, 40, 16]);
    }
    if (ev.type === "win") buzz([12, 40, 12, 40, 24]);
    if (ev.type === "flare") audio.play("flare");
    if (ev.type === "shoot") {
      const now = performance.now();
      if (now - lastShootAt > 110) {
        audio.play("shoot");
        lastShootAt = now;
      }
    }
    if (ev.type === "kill") audio.play("kill");
    if (ev.type === "cleared") audio.play("cleared");
    if (ev.type === "win") audio.play("win");
    if (ev.type === "recruit") audio.play("recruit");
    if (ev.type === "grow") {
      audio.play("grow");
      buzz(8);
    }
    if (ev.type === "mine") {
      audio.play("mine");
      buzz(14);
    }
    if (ev.type === "cook") {
      audio.play("cook");
      buzz(10);
    }
    if (ev.type === "haul") {
      audio.play("haul");
      buzz(6);
    }
    if (ev.type === "hold") audio.play("hold");
    if (ev.type === "relic") {
      audio.play("relic");
      buzz([8, 20, 16]);
    }
    if (ev.type === "go") {
      audio.play("go");
      buzz([10, 24, 12]);
    }
  }
  match.events = [];
}

function finish() {
  if (!match || ended) return;
  if (match.status !== "won" && match.status !== "lost") return;
  ended = true;
  const ov = $("endOv");
  ov.classList.add("on");
  $("play").classList.add("ended");
  const nxt = match.status === "won" ? nextLevel(chosen.id) : null;
  const spec = endOverlaySpec(match.status, { hasNext: !!nxt });
  $("endTitle").textContent = spec.title;
  $("endPrimary").textContent = spec.primary;
  $("endRetry").hidden = !spec.retry;
  if (match.status === "won") {
    completeLevel(save, chosen.id, match.stars, nxt && nxt.id);
    writeSave(save);
    $("endBody").textContent = `${"★".repeat(match.stars)}${"☆".repeat(3 - match.stars)}  ·  ${Math.ceil(match.time)}s`;
    $("endPrimary").onclick = () => {
      if (nxt) openBrief(nxt);
      else {
        renderTitle();
        show("title");
      }
    };
  } else {
    audio.play("over");
    $("endBody").textContent = match.loseReason || "The station failed.";
    $("endPrimary").onclick = () => startLevel(chosen);
  }
}

function loop(now) {
  const dt = Math.min(0.05, (now - last) / 1000);
  last = now;
  try {
    if (screen === "play" && match) {
      if (match.status === "playing") {
        for (let i = 0; i < speed; i++) step(match, dt);
        consumeEvents();
      }
      const canvas = $("stage");
      const ctx = canvas.getContext("2d");
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      drawWorld(ctx, match, { w: canvas.clientWidth, h: canvas.clientHeight, ghost }, now);
      hud();
      finish();
    }
  } catch (err) {
    console.warn(err);
  }
  requestAnimationFrame(loop);
}

function onCanvasTap(ev) {
  if (!match || match.status !== "playing") return;
  const rect = $("stage").getBoundingClientRect();
  const x = (ev.clientX ?? (ev.touches && ev.touches[0].clientX)) - rect.left;
  const y = (ev.clientY ?? (ev.touches && ev.touches[0].clientY)) - rect.top;
  const g = gridAt(match, x, y);
  let ok = tapCell(match, g.x, g.y);
  if (!ok && ROOMS[match.tool] && match.tool !== "core") {
    let best = null;
    let bestD = 2;
    for (let yy = 0; yy < match.rows; yy++) {
      for (let xx = 0; xx < match.cols; xx++) {
        if (!canPlace(match, match.tool, xx, yy, match.rot)) continue;
        const d = Math.abs(xx - g.x) + Math.abs(yy - g.y);
        if (d && d < bestD) {
          best = { x: xx, y: yy };
          bestD = d;
        }
      }
    }
    if (best) ok = tapCell(match, best.x, best.y);
  }
  if (!ok && match.tool !== "assign") audio.play("error");
  else if (ok) buzz(10);
  ghost = null;
}

function onCanvasMove(ev) {
  if (!match) return;
  const pt = ev.touches ? ev.touches[0] : ev;
  const rect = $("stage").getBoundingClientRect();
  const x = pt.clientX - rect.left;
  const y = pt.clientY - rect.top;
  const g = gridAt(match, x, y);
  if (ROOMS[match.tool] && match.tool !== "core") {
    const cells = rotateShape(playerShape(match, match.tool), match.rot).map(([dx, dy]) => ({ x: g.x + dx, y: g.y + dy }));
    ghost = { cells, ok: canPlace(match, match.tool, g.x, g.y, match.rot) };
  } else ghost = null;
}

$("playCampaign").onclick = async () => {
  await audio.unlock();
  const level = levelById(save.last) || LEVELS[0];
  openBrief(level);
};
$("openWorlds").onclick = async () => {
  await audio.unlock();
  renderWorlds();
  show("worlds");
};
$("openHow").onclick = () => show("how");
$("worldsBack").onclick = () => {
  renderTitle();
  show("title");
};
$("levelsBack").onclick = () => {
  renderWorlds();
  show("worlds");
};
$("briefBack").onclick = () => {
  renderLevels();
  show("levels");
};
$("briefStart").onclick = async () => {
  await audio.unlock();
  startLevel(chosen);
};
$("howBack").onclick = () => {
  renderTitle();
  show("title");
};
$("pauseBtn").onclick = () => {
  if (!match) return;
  pause(match);
  $("pauseOv").classList.add("on");
};
$("resumeBtn").onclick = () => {
  if (match && match.status === "paused") pause(match);
  if (match) resumeThink(match);
  $("pauseOv").classList.remove("on");
};
$("restartBtn").onclick = () => startLevel(chosen);
$("pauseMap").onclick = $("endMap").onclick = () => {
  renderWorlds();
  show("worlds");
};
$("endRetry").onclick = () => startLevel(chosen);
$("speed").onclick = () => {
  if (match && match.thinkLocked) {
    resumeThink(match);
    speed = 1;
    $("speed").textContent = "1×";
    $("speed").classList.remove("go");
    return;
  }
  speed = speed === 1 ? 2 : speed === 2 ? 3 : 1;
  $("speed").textContent = speed + "×";
};
$("rotateBtn").onclick = () => {
  if (!match) return;
  rotate(match);
  audio.play("tap");
};
$("holdBtn").onclick = () => {
  if (!match) return;
  if (holdPiece(match)) buzz(10);
  else audio.play("error");
};
$("recallBtn").onclick = () => {
  if (!match) return;
  if (recall(match)) audio.play("assign");
};
$("muteBtn").onclick = () => {
  audio.setMuted(!audio.isMuted());
  $("muteBtn").textContent = audio.isMuted() ? "Muted" : "Sound";
};

const stage = $("stage");
stage.addEventListener("pointerdown", (ev) => {
  stage.setPointerCapture(ev.pointerId);
  onCanvasMove(ev);
});
stage.addEventListener("pointermove", onCanvasMove);
stage.addEventListener("pointerup", (ev) => {
  onCanvasTap(ev);
});
stage.addEventListener("pointercancel", () => {
  ghost = null;
});

window.addEventListener("resize", resize);
window.addEventListener("orientationchange", () => setTimeout(resize, 80));

let deferredInstall = null;
function syncInstallSheet() {
  const sheet = $("installSheet");
  if (!sheet) return;
  const standalone = isStandalone();
  if (standalone) document.documentElement.classList.add("standalone");
  const dismissed = localStorage.getItem("rhyme-a2hs") === "1";
  const show = shouldShowInstallHint({
    ios: isIOS(),
    standalone,
    dismissed,
  });
  sheet.hidden = !show;
  const btn = $("installBtn");
  if (btn) btn.hidden = true;
}
window.addEventListener("beforeinstallprompt", (ev) => {
  ev.preventDefault();
  deferredInstall = ev;
  syncInstallSheet();
});
window.addEventListener("appinstalled", () => {
  localStorage.setItem("rhyme-a2hs", "1");
  syncInstallSheet();
  buzz([8, 30, 12]);
});
$("installDismiss").onclick = () => {
  localStorage.setItem("rhyme-a2hs", "1");
  syncInstallSheet();
};
$("installBtn").onclick = async () => {
  if (!deferredInstall) return;
  deferredInstall.prompt();
  try {
    await deferredInstall.userChoice;
  } catch (_) {
    /* cancelled */
  }
  deferredInstall = null;
  syncInstallSheet();
};

if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("./sw.js?v=13").catch(() => {});
}

renderTitle();
syncInstallSheet();
requestAnimationFrame(loop);

if (location.hostname === "127.0.0.1" || location.hostname === "localhost") {
  window.__rhyme = {
    getMatch: () => match,
    setTool: (t) => match && setTool(match, t),
    tapCell: (x, y) => match && tapCell(match, x, y),
    canPlace: (t, x, y, rot) => match && canPlace(match, t, x, y, rot),
    resumeThink: () => match && resumeThink(match),
    coachText: () => match && coachText(match),
    rotate: () => match && rotate(match),
    play(id, seed = 11) {
      const level = levelById(id);
      if (!level) return null;
      chosen = level;
      ended = false;
      speed = 1;
      $("speed").textContent = "1×";
      $("pauseOv").classList.remove("on");
      $("endOv").classList.remove("on");
      $("endRetry").hidden = false;
      $("play").classList.remove("ended");
      match = createMatch(level, { seed: seed || 11 });
      show("play");
      buildTools();
      resize();
      $("play").classList.toggle("thinking", !!match.thinkLocked);
      const opening = coachText(match) || level.hint || level.lesson || "";
      $("hint").textContent = opening;
      $("hint").classList.toggle("on", !!opening);
      $("hint").classList.toggle("coach", !!opening);
      $("hint").classList.remove("lesson");
      return this.snap();
    },
    place(type) {
      if (!match) return false;
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
    },
    assignType(type) {
      if (!match) return false;
      const room = match.rooms.find((r) => r.type === type && !r.dead);
      if (!room) return false;
      setTool(match, "assign");
      return tapCell(match, room.cells[0].x, room.cells[0].y);
    },
    kissRelic() {
      if (!match) return false;
      const spots = match.relics.filter((r) => !r.linked);
      if (!spots.length) return true;
      setTool(match, "corridor");
      let best = null;
      for (let rot = 0; rot < 4; rot++) {
        match.rot = rot;
        for (let y = 0; y < match.rows; y++) {
          for (let x = 0; x < match.cols; x++) {
            if (!canPlace(match, "corridor", x, y, rot)) continue;
            const cells = rotateShape(playerShape(match, "corridor"), rot).map(([dx, dy]) => ({
              x: x + dx,
              y: y + dy,
            }));
            let min = Infinity;
            let kiss = 0;
            for (const c of cells) {
              for (const s of spots) {
                const man = Math.abs(c.x - s.x) + Math.abs(c.y - s.y);
                min = Math.min(min, man);
                if (man <= 1) kiss += 1;
              }
            }
            const sc = kiss * 50 - min;
            if (!best || sc > best.sc) best = { x, y, rot, sc };
          }
        }
      }
      if (!best) return false;
      match.rot = best.rot;
      return tapCell(match, best.x, best.y);
    },
    snap() {
      if (!match) return null;
      return {
        status: match.status,
        thinkLocked: !!match.thinkLocked,
        time: Math.round(match.time * 10) / 10,
        food: Math.floor(coreStock(match, "food")),
        mineral: Math.floor(coreStock(match, "mineral")),
        relics: match.relics.filter((r) => r.linked).length,
        waves: match.wavesCleared,
        unpaid: match.rooms.filter((r) => !r.built && r.type !== "core").length,
        stars: match.stars,
        coach: coachText(match),
        hp: Math.round(match.core.hp),
        deaths: match.deaths,
        loseReason: match.loseReason,
        crew: match.kapsels.length,
        enemies: match.enemies.length,
        rooms: match.rooms
          .filter((r) => r.type !== "core")
          .map((r) => r.type + (r.built ? "" : "*") + (r.dead ? "!" : "")),
        staff: ["scanner", "weapons", "shield", "garden", "kitchen"].map((t) => {
          const room = match.rooms.find((r) => r.type === t && !r.dead);
          if (!room) return t + ":0";
          const n = match.kapsels.filter((k) => k.assignment === room.id).length;
          return t + ":" + n;
        }),
      };
    },
    beat() {
      if (!match) return null;
      try {
        captainBeat(match);
      } catch (err) {
        console.warn(err);
      }
      return this.snap();
    },
    startFinale(mult = 3) {
      if (this._finale) {
        cancelAnimationFrame(this._finale);
        this._finale = 0;
      }
      if (!match || match.status !== "playing") return this.snap();
      for (let i = 0; i < 8 && match.thinkLocked; i++) captainBeat(match);
      if (!match.thinkLocked) {
        speed = mult || 3;
        $("speed").textContent = speed + "×";
        $("speed").classList.remove("go");
      }
      let lastBeat = 0;
      const tick = () => {
        if (!match || match.status !== "playing") {
          this._finale = 0;
          return;
        }
        const now = performance.now();
        if (now - lastBeat >= 420) {
          lastBeat = now;
          captainBeat(match);
          if (!match.thinkLocked && speed !== (mult || 3)) {
            speed = mult || 3;
            $("speed").textContent = speed + "×";
          }
        }
        this._finale = requestAnimationFrame(tick);
      };
      this._finale = requestAnimationFrame(tick);
      return this.snap();
    },
    setSpeed(n) {
      if (match && match.thinkLocked) resumeThink(match);
      speed = n;
      $("speed").textContent = n + "×";
    },
  };
}

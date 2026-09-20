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
  SHAPES,
  ROOMS,
  recall,
} from "./sim.js";
import { LEVELS, WORLDS, levelById, nextLevel, levelsInWorld } from "./levels.js";
import { loadSave, writeSave, completeLevel, worldUnlocked, campaignStats } from "./save.js";
import { drawWorld } from "./render.js";
import * as audio from "./audio.js";

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
  if (navigator.vibrate) navigator.vibrate(ms);
}

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
  match = createMatch(level, { seed: (Date.now() % 9999) + 1 });
  show("play");
  buildTools();
  resize();
  $("hint").textContent = level.hint || level.lesson || "";
  $("hint").classList.toggle("on", !!(level.hint || level.lesson));
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
      setTool(match, tool);
      for (const c of el.children) c.classList.toggle("on", c.dataset.tool === tool);
      audio.play("tap");
      buzz(8);
    };
    el.appendChild(b);
  }
}

function hud() {
  if (!match) return;
  $("mineralN").textContent = Math.floor(coreStock(match, "mineral"));
  $("foodN").textContent = Math.floor(coreStock(match, "food"));
  $("crewN").textContent = match.kapsels.length;
  const wave = $("waveN");
  if (match.enemies.length) {
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
  if (match.time > 7) $("hint").classList.remove("on");
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

function consumeEvents() {
  if (!match) return;
  for (const ev of match.events) {
    if (ev.type === "place") audio.play("place");
    if (ev.type === "assign") audio.play("assign");
    if (ev.type === "built") audio.play("built");
    if (ev.type === "wave") {
      audio.play("wave");
      buzz([20, 40, 20]);
    }
    if (ev.type === "flare") audio.play("flare");
    if (ev.type === "shoot") audio.play("shoot");
    if (ev.type === "win") audio.play("win");
    if (ev.type === "recruit") audio.play("recruit");
  }
  match.events = [];
}

function finish() {
  if (!match || ended) return;
  if (match.status !== "won" && match.status !== "lost") return;
  ended = true;
  const ov = $("endOv");
  ov.classList.add("on");
  if (match.status === "won") {
    const nxt = nextLevel(chosen.id);
    completeLevel(save, chosen.id, match.stars, nxt && nxt.id);
    writeSave(save);
    $("endTitle").textContent = "Stable";
    $("endBody").textContent = `${"★".repeat(match.stars)}${"☆".repeat(3 - match.stars)}  ·  ${Math.ceil(match.time)}s`;
    $("endPrimary").textContent = nxt ? "Next station" : "Campaign complete";
    $("endPrimary").onclick = () => {
      if (nxt) openBrief(nxt);
      else {
        renderTitle();
        show("title");
      }
    };
  } else {
    audio.play("over");
    $("endTitle").textContent = "Unstitched";
    $("endBody").textContent = match.loseReason || "The station failed.";
    $("endPrimary").textContent = "Retry";
    $("endPrimary").onclick = () => startLevel(chosen);
  }
}

function loop(now) {
  const dt = Math.min(0.05, (now - last) / 1000);
  last = now;
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
  requestAnimationFrame(loop);
}

function onCanvasTap(ev) {
  if (!match || match.status !== "playing") return;
  const rect = $("stage").getBoundingClientRect();
  const x = (ev.clientX ?? (ev.touches && ev.touches[0].clientX)) - rect.left;
  const y = (ev.clientY ?? (ev.touches && ev.touches[0].clientY)) - rect.top;
  const g = gridAt(match, x, y);
  let ok = tapCell(match, g.x, g.y);
  if (!ok && SHAPES[match.tool]) {
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
  if (SHAPES[match.tool]) {
    const cells = rotateShape(SHAPES[match.tool], match.rot).map(([dx, dy]) => ({ x: g.x + dx, y: g.y + dy }));
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
  $("pauseOv").classList.remove("on");
};
$("restartBtn").onclick = () => startLevel(chosen);
$("pauseMap").onclick = $("endMap").onclick = () => {
  renderWorlds();
  show("worlds");
};
$("endRetry").onclick = () => startLevel(chosen);
$("speed").onclick = () => {
  speed = speed === 1 ? 2 : speed === 2 ? 3 : 1;
  $("speed").textContent = speed + "×";
};
$("rotateBtn").onclick = () => {
  if (!match) return;
  rotate(match);
  audio.play("tap");
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

renderTitle();
requestAnimationFrame(loop);

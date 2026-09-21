// Procedural audio: sparse Grapefrukt sines, clicks, and a quiet telegraph.

let ctx = null;
let drone = null;
let muted = false;
let started = false;
let bedScene = "title";
let dripId = 0;
let voices = [];

export function bedFor(scene) {
  if (scene === "title") return { a: 0.012, freqs: [49, 73.4] };
  if (scene === "worlds") return { a: 0.011, freqs: [55, 82.4] };
  if (scene === "how") return { a: 0.01, freqs: [43.65, 65.4] };
  return { a: 0.018, freqs: [46.25, 69.3] };
}

export function dripGap() {
  return 7200;
}

export function setBed(scene) {
  bedScene = scene || "title";
  const spec = bedFor(bedScene);
  if (drone && drone.gain) {
    drone.gain.gain.value = muted ? 0 : spec.a;
    const c = ctx;
    if (c && voices.length) {
      voices.forEach((o, i) => {
        const f = spec.freqs[i] || spec.freqs[spec.freqs.length - 1];
        try {
          o.frequency.setTargetAtTime(f, c.currentTime, 0.08);
        } catch (_) {
          o.frequency.value = f;
        }
      });
    }
  }
  ensureDrips();
  return spec;
}

export function musicBed(scene) {
  return setBed(scene);
}

function ac() {
  if (!ctx) ctx = new (window.AudioContext || window.webkitAudioContext)();
  return ctx;
}

export function isMuted() {
  return muted;
}

export function setMuted(v) {
  muted = v;
  if (drone && drone.gain) drone.gain.gain.value = muted ? 0 : bedFor(bedScene).a;
}

export async function unlock() {
  const c = ac();
  if (c.state === "suspended") await c.resume();
  started = true;
  if (!drone) startDrone();
  ensureDrips();
}

function startDrone() {
  const c = ac();
  const spec = bedFor(bedScene);
  const g = c.createGain();
  g.gain.value = muted ? 0 : spec.a;
  g.connect(c.destination);
  const make = (freq, detune, mix) => {
    const o = c.createOscillator();
    o.type = "sine";
    o.frequency.value = freq;
    o.detune.value = detune;
    const og = c.createGain();
    og.gain.value = mix;
    o.connect(og);
    og.connect(g);
    o.start();
    return o;
  };
  voices = [];
  spec.freqs.forEach((f, i) => {
    voices.push(make(f, i * 5 - 3, i === 0 ? 0.62 : 0.32));
  });
  drone = { gain: g };
}

function ensureDrips() {
  if (dripId) return;
  const tickDrip = () => {
    dripId = setTimeout(tickDrip, dripGap() + Math.floor(Math.random() * 1400));
    if (!started || muted) return;
    const spec = bedFor(bedScene);
    const f = spec.freqs[1] || spec.freqs[0] * 1.5;
    beep(f, 0.07, "sine", 0.008);
  };
  dripId = setTimeout(tickDrip, dripGap());
}

function beep(freq, dur, type, vol, slide) {
  if (muted || !started) return;
  const c = ac();
  const o = c.createOscillator();
  const g = c.createGain();
  o.type = type || "sine";
  o.frequency.setValueAtTime(freq, c.currentTime);
  if (slide) o.frequency.exponentialRampToValueAtTime(Math.max(40, slide), c.currentTime + dur);
  g.gain.setValueAtTime(vol || 0.08, c.currentTime);
  g.gain.exponentialRampToValueAtTime(0.0001, c.currentTime + dur);
  o.connect(g);
  g.connect(c.destination);
  o.start();
  o.stop(c.currentTime + dur + 0.02);
}

function telegraph() {
  beep(168, 0.14, "sine", 0.022, 118);
}

export const TONES = {
  place: { freq: 1680, dur: 0.032, type: "sine", vol: 0.026 },
  tick: { freq: 1860, dur: 0.018, type: "sine", vol: 0.012 },
  assign: { freq: 540, dur: 0.06, type: "sine", vol: 0.032 },
  error: { freq: 180, dur: 0.12, type: "sine", vol: 0.028, slide: 120 },
  built: { freq: 420, dur: 0.1, type: "sine", vol: 0.03, slide: 560 },
  shoot: { freq: 880, dur: 0.03, type: "sine", vol: 0.014, slide: 1400 },
  kill: { freq: 1320, dur: 0.06, type: "sine", vol: 0.028, slide: 880 },
  wave: { freq: 196, dur: 0.16, type: "sine", vol: 0.03, slide: 118 },
  incoming: { freq: 240, dur: 0.14, type: "sine", vol: 0.028, slide: 320 },
  flare: { freq: 98, dur: 0.24, type: "sine", vol: 0.03, slide: 64 },
  win: { freq: 520, dur: 0.16, type: "sine", vol: 0.04, slide: 780 },
  over: { freq: 200, dur: 0.4, type: "sine", vol: 0.036, slide: 70 },
  tap: { freq: 700, dur: 0.035, type: "sine", vol: 0.022 },
  recruit: { freq: 660, dur: 0.14, type: "sine", vol: 0.032, slide: 880 },
  grow: { freq: 392, dur: 0.09, type: "sine", vol: 0.028, slide: 523 },
  mine: { freq: 196, dur: 0.08, type: "sine", vol: 0.028, slide: 262 },
  cook: { freq: 494, dur: 0.08, type: "sine", vol: 0.028, slide: 392 },
  haul: { freq: 330, dur: 0.05, type: "sine", vol: 0.018, slide: 220 },
  hold: { freq: 440, dur: 0.05, type: "sine", vol: 0.024, slide: 330 },
  go: { freq: 392, dur: 0.12, type: "sine", vol: 0.036, slide: 620 },
  relic: { freq: 523, dur: 0.18, type: "sine", vol: 0.036, slide: 784 },
  dock: { freq: 262, dur: 0.16, type: "sine", vol: 0.032, slide: 392 },
  seat: { freq: 494, dur: 0.045, type: "sine", vol: 0.018 },
  supply: { freq: 330, dur: 0.16, type: "sine", vol: 0.032, slide: 494 },
  solar: { freq: 110, dur: 0.24, type: "sine", vol: 0.03, slide: 196 },
  fold: { freq: 415, dur: 0.16, type: "sine", vol: 0.03, slide: 622 },
  frost: { freq: 784, dur: 0.14, type: "sine", vol: 0.028, slide: 988 },
  ghost: { freq: 196, dur: 0.2, type: "sine", vol: 0.028, slide: 147 },
  drip: { freq: 523, dur: 0.07, type: "sine", vol: 0.01 },
  cleared: { freq: 620, dur: 0.14, type: "sine", vol: 0.032, slide: 880 },
};

export function toneFor(name) {
  return TONES[name] || null;
}

const lastVoice = new Map();
const VOICE_GAP = {
  shoot: 120,
  wave: 280,
  flare: 280,
  incoming: 220,
  haul: 90,
  tick: 80,
  seat: 90,
};

export function resetVoices() {
  lastVoice.clear();
}

function nowMs(explicit) {
  if (explicit != null) return explicit;
  if (typeof performance !== "undefined" && performance.now) return performance.now();
  return Date.now();
}

export function play(name, when) {
  const gap = VOICE_GAP[name] || 0;
  if (gap) {
    const t = nowMs(when);
    const prev = lastVoice.get(name) || 0;
    if (t - prev < gap) return false;
    lastVoice.set(name, t);
  }
  const tone = toneFor(name);
  if (!tone) {
    if (name === "win") {
      beep(520, 0.16, "sine", 0.04, 780);
      setTimeout(() => beep(780, 0.22, "sine", 0.03), 120);
    }
    return true;
  }
  beep(tone.freq, tone.dur, tone.type, tone.vol, tone.slide);
  if (name === "win") setTimeout(() => beep(780, 0.22, "sine", 0.03), 120);
  if (name === "incoming") setTimeout(telegraph, 110);
  if (name === "kill") setTimeout(() => beep(990, 0.04, "sine", 0.018), 40);
  if (name === "go") setTimeout(() => beep(523, 0.12, "sine", 0.028, 784), 90);
  if (name === "dock") setTimeout(() => beep(392, 0.12, "sine", 0.022, 523), 80);
  if (name === "supply") setTimeout(() => beep(494, 0.12, "sine", 0.022, 392), 90);
  if (name === "solar") setTimeout(() => beep(165, 0.16, "sine", 0.022, 98), 100);
  if (name === "fold") setTimeout(() => beep(622, 0.14, "sine", 0.022, 311), 80);
  if (name === "frost") setTimeout(() => beep(988, 0.1, "sine", 0.02, 784), 70);
  if (name === "ghost") setTimeout(() => beep(147, 0.16, "sine", 0.02, 98), 110);
  return true;
}

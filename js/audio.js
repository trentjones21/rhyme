// Procedural audio: a low drone and short geometric blips.

let ctx = null;
let drone = null;
let muted = false;
let started = false;

function ac() {
  if (!ctx) ctx = new (window.AudioContext || window.webkitAudioContext)();
  return ctx;
}

export function isMuted() {
  return muted;
}

export function setMuted(v) {
  muted = v;
  if (drone && drone.gain) drone.gain.gain.value = muted ? 0 : 0.024;
}

export async function unlock() {
  const c = ac();
  if (c.state === "suspended") await c.resume();
  started = true;
  if (!drone) startDrone();
}

function startDrone() {
  const c = ac();
  const g = c.createGain();
  g.gain.value = muted ? 0 : 0.024;
  g.connect(c.destination);
  const make = (freq, type, detune, mix) => {
    const o = c.createOscillator();
    o.type = type;
    o.frequency.value = freq;
    o.detune.value = detune;
    const og = c.createGain();
    og.gain.value = mix;
    o.connect(og);
    og.connect(g);
    o.start();
    return o;
  };
  make(55, "sine", 0, 0.55);
  make(82.4, "sine", 7, 0.28);
  make(164.8, "triangle", -10, 0.12);
  drone = { gain: g };
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

export const TONES = {
  place: { freq: 320, dur: 0.09, type: "triangle", vol: 0.06, slide: 480 },
  assign: { freq: 540, dur: 0.07, type: "sine", vol: 0.045 },
  error: { freq: 180, dur: 0.14, type: "square", vol: 0.035, slide: 120 },
  built: { freq: 420, dur: 0.12, type: "triangle", vol: 0.055, slide: 640 },
  shoot: { freq: 880, dur: 0.03, type: "sine", vol: 0.016, slide: 1400 },
  kill: { freq: 1320, dur: 0.07, type: "triangle", vol: 0.036, slide: 880 },
  wave: { freq: 310, dur: 0.16, type: "triangle", vol: 0.034, slide: 170 },
  incoming: { freq: 240, dur: 0.12, type: "sine", vol: 0.038, slide: 380 },
  flare: { freq: 98, dur: 0.28, type: "sine", vol: 0.038, slide: 64 },
  win: { freq: 520, dur: 0.18, type: "sine", vol: 0.055, slide: 780 },
  over: { freq: 200, dur: 0.5, type: "triangle", vol: 0.05, slide: 70 },
  tap: { freq: 700, dur: 0.04, type: "sine", vol: 0.028 },
  recruit: { freq: 660, dur: 0.16, type: "sine", vol: 0.045, slide: 880 },
  grow: { freq: 392, dur: 0.11, type: "sine", vol: 0.045, slide: 587 },
  mine: { freq: 196, dur: 0.1, type: "triangle", vol: 0.05, slide: 262 },
  cook: { freq: 494, dur: 0.09, type: "sine", vol: 0.04, slide: 392 },
  haul: { freq: 330, dur: 0.06, type: "triangle", vol: 0.03, slide: 220 },
  hold: { freq: 440, dur: 0.06, type: "triangle", vol: 0.035, slide: 330 },
  go: { freq: 392, dur: 0.14, type: "sine", vol: 0.05, slide: 620 },
  relic: { freq: 523, dur: 0.22, type: "sine", vol: 0.05, slide: 784 },
  cleared: { freq: 620, dur: 0.16, type: "sine", vol: 0.045, slide: 880 },
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
      beep(520, 0.18, "sine", 0.055, 780);
      setTimeout(() => beep(780, 0.28, "sine", 0.045), 120);
    }
    return true;
  }
  beep(tone.freq, tone.dur, tone.type, tone.vol, tone.slide);
  if (name === "win") setTimeout(() => beep(780, 0.28, "sine", 0.045), 120);
  if (name === "incoming") setTimeout(() => beep(180, 0.1, "sine", 0.03, 140), 90);
  if (name === "kill") setTimeout(() => beep(990, 0.05, "sine", 0.025), 40);
  if (name === "go") setTimeout(() => beep(523, 0.16, "sine", 0.04, 784), 90);
  return true;
}

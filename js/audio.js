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
  if (drone && drone.gain) drone.gain.gain.value = muted ? 0 : 0.027;
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
  g.gain.value = muted ? 0 : 0.027;
  g.connect(c.destination);
  const make = (freq, type, detune) => {
    const o = c.createOscillator();
    o.type = type;
    o.frequency.value = freq;
    o.detune.value = detune;
    const og = c.createGain();
    og.gain.value = 0.5;
    o.connect(og);
    og.connect(g);
    o.start();
    return o;
  };
  make(55, "sine", 0);
  make(82.4, "sine", 6);
  make(164.8, "triangle", -8);
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

export function play(name) {
  switch (name) {
    case "place":
      beep(320, 0.09, "triangle", 0.07, 480);
      break;
    case "assign":
      beep(540, 0.07, "sine", 0.05);
      break;
    case "error":
      beep(180, 0.14, "square", 0.04, 120);
      break;
    case "built":
      beep(420, 0.12, "triangle", 0.06, 640);
      break;
    case "shoot":
      beep(980, 0.04, "square", 0.03, 1400);
      break;
    case "wave":
      beep(220, 0.4, "sawtooth", 0.05, 90);
      break;
    case "flare":
      beep(140, 0.5, "sawtooth", 0.06, 60);
      break;
    case "win":
      beep(520, 0.18, "sine", 0.06, 780);
      setTimeout(() => beep(780, 0.28, "sine", 0.05), 120);
      break;
    case "over":
      beep(200, 0.55, "triangle", 0.06, 70);
      break;
    case "tap":
      beep(700, 0.04, "sine", 0.03);
      break;
    case "recruit":
      beep(660, 0.16, "sine", 0.05, 880);
      break;
    case "grow":
      beep(392, 0.12, "sine", 0.055, 587);
      break;
    case "mine":
      beep(196, 0.11, "triangle", 0.06, 262);
      break;
    case "cook":
      beep(494, 0.1, "sine", 0.05, 392);
      break;
    case "haul":
      beep(330, 0.07, "square", 0.035, 220);
      break;
    case "hold":
      beep(440, 0.06, "triangle", 0.04, 330);
      break;
    default:
      break;
  }
}

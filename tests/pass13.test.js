import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { levelById } from "../js/levels.js";
import {
  createMatch,
  step,
  captainBeat,
  resumeThink,
  holdPiece,
  coreStock,
  gridAt,
} from "../js/sim.js";
import { bedFor, dripGap, toneFor, play, resetVoices } from "../js/audio.js";

function tick(match, seconds) {
  if (match.thinkLocked) resumeThink(match);
  const dt = 0.05;
  const n = Math.ceil(seconds / dt);
  for (let i = 0; i < n; i++) step(match, dt);
}

function captainPlay(id, limit = 220) {
  const m = createMatch(levelById(id), { seed: 11 });
  while (m.status === "playing" && m.time < limit) {
    if (!captainBeat(m) && m.mechanics.pieceQueue) holdPiece(m);
    tick(m, 0.4);
  }
  return m;
}

function consumeEventsSrc() {
  const app = readFileSync(new URL("../js/app.js", import.meta.url), "utf8");
  const i = app.indexOf("function consumeEvents");
  assert.ok(i >= 0, "consumeEvents missing");
  return app.slice(i, app.indexOf("function finish", i));
}

describe("beds stay sparse Grapefrukt sines", () => {
  it("keeps title and play beds as quiet two-voice fifths", () => {
    const title = bedFor("title");
    const playBed = bedFor("play");
    assert.ok(title.freqs.length <= 2, "title bed is a chord");
    assert.ok(playBed.freqs.length <= 2, "play bed is a chord");
    assert.ok(title.a <= 0.02, title.a);
    assert.ok(playBed.a <= 0.02, playBed.a);
    assert.notEqual(title.a, playBed.a);
    assert.ok(dripGap() >= 6000, dripGap());
    const audio = readFileSync(new URL("../js/audio.js", import.meta.url), "utf8");
    const i = audio.indexOf("function startDrone");
    const drone = audio.slice(i, audio.indexOf("function ensureDrips", i));
    assert.match(drone, /sine/);
    assert.doesNotMatch(drone, /triangle|square|sawtooth/);
    assert.doesNotMatch(audio, /PENTATONIC/);
  });
});

describe("placement is a sine click", () => {
  it("plays a short click with no slide", () => {
    const tone = toneFor("place");
    assert.ok(tone);
    assert.equal(tone.type, "sine");
    assert.ok(tone.dur <= 0.05, tone.dur);
    assert.ok(!tone.slide, "place still whooshes");
    assert.ok(tone.vol <= 0.04, tone.vol);
  });
});

describe("kapsels tick when they finish a cell", () => {
  it("emits a quiet tick voice and a sim event", () => {
    const tone = toneFor("tick");
    assert.ok(tone, "tick tone missing");
    assert.equal(tone.type, "sine");
    assert.ok(tone.dur <= 0.04, tone.dur);
    assert.ok(tone.vol <= 0.02, tone.vol);
    resetVoices();
    assert.equal(play("tick", 2000), true);
    assert.equal(play("tick", 2040), false);

    const m = createMatch(levelById("1-01"), { seed: 1 });
    const k = m.kapsels[0];
    const g = gridAt(m, k.x, k.y);
    k.job = { kind: "wait", target: m.core, path: [] };
    k.path = [{ x: g.x, y: g.y }];
    k.state = "walking";
    step(m, 0.05);
    assert.ok(
      m.events.some((e) => e.type === "tick"),
      "expected a kapsel tick, got " + m.events.map((e) => e.type).join(",")
    );
  });
});

describe("waves telegraph with a sine pulse", () => {
  it("keeps incoming distinct from the land sting and sine-only", () => {
    const incoming = toneFor("incoming");
    const wave = toneFor("wave");
    assert.ok(incoming);
    assert.ok(wave);
    assert.equal(incoming.type, "sine");
    assert.equal(wave.type, "sine");
    assert.notEqual(incoming.freq, wave.freq);
    assert.ok(incoming.dur >= 0.1, incoming.dur);
    const audio = readFileSync(new URL("../js/audio.js", import.meta.url), "utf8");
    assert.match(audio, /incoming[\s\S]{0,80}setTimeout|telegraph/);
  });
});

describe("haptics stay light on place, assign, and GO", () => {
  it("buzzes those three and does not buzz every haul", () => {
    const ev = consumeEventsSrc();
    assert.match(ev, /"place"[\s\S]{0,160}buzz\(/);
    assert.match(ev, /"assign"[\s\S]{0,120}buzz\(8\)/);
    assert.match(ev, /"go"[\s\S]{0,120}buzz\(/);
    assert.doesNotMatch(ev, /"haul"[\s\S]{0,80}buzz\(/);
    assert.doesNotMatch(ev, /"grow"[\s\S]{0,80}buzz\(/);
    assert.doesNotMatch(ev, /"mine"[\s\S]{0,80}buzz\(/);
    assert.doesNotMatch(ev, /"cook"[\s\S]{0,80}buzz\(/);
    const app = readFileSync(new URL("../js/app.js", import.meta.url), "utf8");
    const canvas = app.slice(app.indexOf("if (!ok && match.tool"), app.indexOf("function onCanvasMove"));
    assert.doesNotMatch(canvas, /buzz\(/);
  });
});

describe("audio pass does not mute Spine or Last Geometry", () => {
  it("still lets the captain finish Spine and Last Geometry", () => {
    for (const id of ["1-01", "7-06"]) {
      const m = captainPlay(id, 220);
      assert.equal(
        m.status,
        "won",
        `${id} ${m.status} ${m.loseReason || ""} t=${m.time.toFixed(1)} rel=${m.relics.filter((r) => r.linked).length} wav=${m.wavesCleared} food=${coreStock(m, "food").toFixed(0)} deaths=${m.deaths} hp=${m.core.hp}`
      );
      assert.equal(m.deaths, 0, id + " deaths");
      assert.ok(m.core.hp / m.core.maxhp >= 0.8, id + " hp " + m.core.hp);
    }
  });
});

describe("look language stays after the audio pass", () => {
  it("keeps merged hulls and dash kapsels", () => {
    const render = readFileSync(new URL("../js/render.js", import.meta.url), "utf8");
    assert.match(render, /drawRoomHull/);
    assert.match(render, /drawKapselDash/);
    assert.match(render, /seedStars\(88\)/);
  });
});

describe("audio cache is not stuck on v31", () => {
  it("bumps the portrait cache after the sound pass", () => {
    const html = readFileSync(new URL("../index.html", import.meta.url), "utf8");
    const app = readFileSync(new URL("../js/app.js", import.meta.url), "utf8");
    const sw = readFileSync(new URL("../sw.js", import.meta.url), "utf8");
    assert.match(html, /app\.js\?v=33/);
    assert.match(app, /sw\.js\?v=23/);
    assert.match(sw, /rhyme-v23/);
  });
});

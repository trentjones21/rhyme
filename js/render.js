import { ROOMS, canPlace, SCAN_R, scanRange } from "./sim.js";

const VOID = "#07080d";
let stars = null;
let motes = null;

function seedStars(n) {
  stars = [];
  motes = [];
  let s = 1337;
  const rnd = () => {
    s = (Math.imul(s, 1664525) + 1013904223) >>> 0;
    return s / 4294967296;
  };
  for (let i = 0; i < n; i++) {
    stars.push({
      x: rnd(),
      y: rnd(),
      r: rnd() * 1.35 + 0.25,
      a: rnd() * 0.55 + 0.12,
      p: rnd() * Math.PI * 2,
    });
  }
  for (let i = 0; i < 36; i++) {
    motes.push({
      x: rnd(),
      y: rnd(),
      r: rnd() * 1.4 + 0.6,
      a: rnd() * 0.12 + 0.04,
      p: rnd() * Math.PI * 2,
      s: 0.012 + rnd() * 0.02,
    });
  }
}

function round(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.roundRect(x, y, w, h, r);
}

export function drawWorld(ctx, match, view, now) {
  const w = view.w;
  const h = view.h;
  if (!stars) seedStars(220);
  ctx.clearRect(0, 0, w, h);
  ctx.save();
  if (match.shake > 0) {
    ctx.translate((Math.random() - 0.5) * match.shake * 10, (Math.random() - 0.5) * match.shake * 10);
  }

  const g = ctx.createRadialGradient(w * 0.32, h * 0.18, 12, w * 0.48, h * 0.42, Math.max(w, h) * 0.78);
  g.addColorStop(0, "#22283a");
  g.addColorStop(0.28, "#151826");
  g.addColorStop(0.62, "#0c0f16");
  g.addColorStop(1, "#040406");
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, w, h);

  ctx.fillStyle = "rgba(90, 120, 170, 0.16)";
  ctx.beginPath();
  ctx.ellipse(w * 0.22, h * 0.06, w * 0.52, 82, -0.18, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "rgba(110, 55, 80, 0.12)";
  ctx.beginPath();
  ctx.ellipse(w * 0.86, h * 0.7, 140, 200, 0.42, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "rgba(110, 195, 201, 0.05)";
  ctx.beginPath();
  ctx.ellipse(w * 0.55, h * 0.22, w * 0.4, 40, 0.1, 0, Math.PI * 2);
  ctx.fill();

  ctx.fillStyle = "#1a2030";
  ctx.beginPath();
  ctx.arc(-20, h + 40, 160, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "#161822";
  ctx.beginPath();
  ctx.arc(w + 30, 90, 110, 0, Math.PI * 2);
  ctx.fill();

  for (const st of stars) {
    const tw = 0.55 + Math.sin(now * 0.0018 + st.p) * 0.45;
    ctx.fillStyle = `rgba(236,234,226,${st.a * tw})`;
    ctx.beginPath();
    ctx.arc(st.x * w, st.y * h, st.r, 0, Math.PI * 2);
    ctx.fill();
  }
  for (const m of motes) {
    const x = ((m.x + now * 0.00002 * m.s) % 1) * w;
    const y = ((m.y + Math.sin(now * 0.0004 + m.p) * 0.02) % 1) * h;
    ctx.fillStyle = `rgba(243,240,232,${m.a})`;
    ctx.beginPath();
    ctx.arc(x, y, m.r, 0, Math.PI * 2);
    ctx.fill();
  }

  const L = match.layout;
  ctx.strokeStyle = "rgba(255,255,255,0.045)";
  ctx.lineWidth = 1;
  ctx.beginPath();
  for (let i = 0; i <= match.cols; i++) {
    const x = L.ox + i * L.cell + 0.5;
    ctx.moveTo(x, L.oy);
    ctx.lineTo(x, L.oy + L.gridH);
  }
  for (let j = 0; j <= match.rows; j++) {
    const y = L.oy + j * L.cell + 0.5;
    ctx.moveTo(L.ox, y);
    ctx.lineTo(L.ox + L.gridW, y);
  }
  ctx.stroke();

  drawTerrain(ctx, match, now);
  drawRoomGlow(ctx, match, now);
  drawValidCells(ctx, match);
  drawShieldAuras(ctx, match, now);
  drawScanCones(ctx, match, now);
  drawRooms(ctx, match, now);
  drawKapsels(ctx, match);
  drawEnemies(ctx, match, now);
  drawShots(ctx, match);
  drawFx(ctx, match, now);
  drawGhost(ctx, match, view.ghost);
  drawFloats(ctx, match);
  drawVignette(ctx, match, w, h, now);
  if (match.pulse > 0) {
    ctx.fillStyle = `rgba(243,240,232,${Math.min(0.16, match.pulse * 0.35)})`;
    ctx.fillRect(0, 0, w, h);
  }
  ctx.restore();
}

function cellRect(match, x, y, inset) {
  const L = match.layout;
  const pad = inset;
  return {
    x: L.ox + x * L.cell + pad,
    y: L.oy + y * L.cell + pad,
    w: L.cell - pad * 2,
    h: L.cell - pad * 2,
  };
}

function drawRoomGlow(ctx, match, now) {
  for (const room of match.rooms) {
    if (!room.built || room.dead) continue;
    const staff = match.kapsels.some((k) => k.assignment === room.id);
    const a = room.type === "core" ? 0.16 : staff ? 0.11 : 0.05;
    if (room.type === "garden") ctx.fillStyle = `rgba(94,168,106,${0.1 + Math.sin(now * 0.004) * 0.04})`;
    else if (room.type === "kitchen") ctx.fillStyle = `rgba(240,194,74,${0.1 + Math.sin(now * 0.005) * 0.04})`;
    else if (room.type === "gate") ctx.fillStyle = `rgba(155,122,212,${0.12 + Math.sin(now * 0.006 + room.id) * 0.05})`;
    else {
      ctx.fillStyle = room.type === "core"
        ? `rgba(243,240,232,${0.1 + Math.sin(now * 0.003) * 0.04})`
        : `rgba(243,240,232,${a})`;
    }
    ctx.beginPath();
    ctx.arc(room.cx, room.cy, match.layout.cell * (room.type === "core" ? 2.1 : 1.15), 0, Math.PI * 2);
    ctx.fill();
  }
}

function drawValidCells(ctx, match) {
  if (!match.tool || match.tool === "assign" || match.tool === "salvage" || match.tool === "overload") return;
  ctx.fillStyle = "rgba(94,168,106,0.12)";
  for (let y = 0; y < match.rows; y++) {
    for (let x = 0; x < match.cols; x++) {
      if (!canPlace(match, match.tool, x, y, match.rot)) continue;
      const r = cellRect(match, x, y, 4);
      round(ctx, r.x, r.y, r.w, r.h, 4);
      ctx.fill();
    }
  }
}

function drawTerrain(ctx, match, now) {
  for (const d of match.level.deposits || []) {
    const r = cellRect(match, d.x, d.y, 6);
    const pulse = 0.55 + Math.sin(now * 0.005) * 0.2;
    ctx.fillStyle = `rgba(224,120,152,${pulse})`;
    const cx = r.x + r.w / 2;
    const cy = r.y + r.h / 2;
    ctx.fillRect(cx - 2, r.y + 2, 4, r.h - 4);
    ctx.fillRect(r.x + 2, cy - 2, r.w - 4, 4);
  }
  for (const b of match.level.blocked || []) {
    const r = cellRect(match, b.x, b.y, 3);
    ctx.fillStyle = "#0b0c10";
    round(ctx, r.x, r.y, r.w, r.h, 4);
    ctx.fill();
    ctx.strokeStyle = "rgba(255,255,255,0.08)";
    ctx.stroke();
  }
  for (const iceKey of match.ice) {
    const [x, y] = iceKey.split(",").map(Number);
    const r = cellRect(match, x, y, 4);
    ctx.fillStyle = "rgba(186,220,255,0.28)";
    round(ctx, r.x, r.y, r.w, r.h, 5);
    ctx.fill();
    ctx.strokeStyle = "rgba(220,236,255,0.45)";
    ctx.stroke();
    ctx.fillStyle = `rgba(255,255,255,${0.18 + Math.sin(now * 0.004 + x + y) * 0.12})`;
    ctx.fillRect(r.x + r.w * 0.2, r.y + 3, 3, 3);
  }
  for (const well of match.wells) {
    const L = match.layout;
    const x = L.ox + (well.x + 0.5) * L.cell;
    const y = L.oy + (well.y + 0.5) * L.cell;
    for (let i = 3; i >= 1; i--) {
      ctx.strokeStyle = `rgba(160,150,255,${0.08 * i})`;
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.arc(x, y, 8 + i * 10 + (now * 0.02) % 10, 0, Math.PI * 2);
      ctx.stroke();
    }
  }
  for (const relic of match.relics) {
    relicHalo(ctx, match, relic, now);
  }
}

function relicHalo(ctx, match, relic, now) {
    const r = cellRect(match, relic.x, relic.y, 7);
    const cx = r.x + r.w / 2;
    const cy = r.y + r.h / 2;
    const hum = 0.1 + Math.sin(now * 0.004 + relic.x) * 0.05;
    ctx.strokeStyle = relic.linked ? `rgba(232,217,160,${0.35 + hum})` : `rgba(180,190,210,${0.16 + hum})`;
    ctx.lineWidth = relic.linked ? 2 : 1.2;
    ctx.beginPath();
    ctx.arc(cx, cy + 2, 16 + Math.sin(now * 0.003 + relic.y) * 2, 0, Math.PI * 2);
    ctx.stroke();
    if (relic.linked) {
      ctx.fillStyle = `rgba(232,217,160,${0.12 + Math.sin(now * 0.005) * 0.06})`;
      ctx.beginPath();
      ctx.arc(cx, cy + 4, 14, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.fillStyle = relic.linked ? "#e8d9a0" : "#9aa0ae";
    ctx.beginPath();
    ctx.moveTo(r.x + r.w / 2, r.y - 6);
    ctx.lineTo(r.x + r.w, r.y + r.h);
    ctx.lineTo(r.x, r.y + r.h);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = relic.linked ? "rgba(255,255,255,0.35)" : "rgba(255,255,255,0.12)";
    ctx.beginPath();
    ctx.moveTo(cx, r.y - 2);
    ctx.lineTo(r.x + r.w * 0.72, r.y + r.h * 0.45);
    ctx.lineTo(cx, r.y + r.h * 0.4);
    ctx.closePath();
    ctx.fill();
    if (relic.linked) {
      ctx.strokeStyle = "rgba(232,217,160,0.55)";
      ctx.stroke();
    }
}

function gateFold(ctx, now, room) {
  const spin = now * 0.003 + room.id;
  ctx.strokeStyle = `rgba(196,170,240,${0.55 + Math.sin(now * 0.006) * 0.2})`;
  ctx.strokeRect(-6, -6, 12, 12);
  ctx.beginPath();
  ctx.arc(0, 0, 3.2, 0, Math.PI * 2);
  ctx.stroke();
  ctx.save();
  ctx.rotate(spin);
  ctx.beginPath();
  ctx.moveTo(-5, 0);
  ctx.lineTo(5, 0);
  ctx.moveTo(0, -5);
  ctx.lineTo(0, 5);
  ctx.stroke();
  ctx.restore();
  ctx.strokeStyle = `rgba(155,122,212,${0.28 + Math.sin(now * 0.008 + room.id) * 0.12})`;
  ctx.beginPath();
  ctx.arc(0, 0, 9 + Math.sin(now * 0.004) * 1.5, 0, Math.PI * 2);
  ctx.stroke();
}

function drawScanCones(ctx, match, now) {
  for (const room of match.rooms) {
    if (room.type !== "scanner" || !room.built || room.dead) continue;
    const staff = match.kapsels.some((k) => k.assignment === room.id);
    if (!staff) continue;
    const sweep = (now * 0.0024 + room.id) % (Math.PI * 2);
    const r = scanRange(match);
    ctx.save();
    ctx.translate(room.cx, room.cy);
    const cone = ctx.createRadialGradient(0, 0, 4, 0, 0, r);
    cone.addColorStop(0, "rgba(112,180,224,0.22)");
    cone.addColorStop(0.55, "rgba(112,180,224,0.08)");
    cone.addColorStop(1, "rgba(112,180,224,0)");
    ctx.fillStyle = cone;
    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.arc(0, 0, r, sweep - 0.55, sweep + 0.55);
    ctx.closePath();
    ctx.fill();
    ctx.strokeStyle = `rgba(160,210,240,${0.28 + Math.sin(now * 0.006) * 0.1})`;
    ctx.lineWidth = 1.2;
    ctx.beginPath();
    ctx.arc(0, 0, r * 0.82, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
  }
}

function drawShieldAuras(ctx, match, now) {
  for (const room of match.rooms) {
    if (room.type !== "shield" || !room.built || room.dead) continue;
    const pulse = 0.12 + Math.sin(now * 0.004 + room.id) * 0.05;
    ctx.strokeStyle = `rgba(110,195,201,${0.22 + pulse})`;
    ctx.lineWidth = 1.4;
    ctx.beginPath();
    ctx.arc(room.cx, room.cy, match.layout.cell * 4.2 + Math.sin(now * 0.003) * 2, 0, Math.PI * 2);
    ctx.stroke();
    ctx.fillStyle = `rgba(110,195,201,${0.05 + pulse * 0.4})`;
    ctx.beginPath();
    ctx.arc(room.cx, room.cy, match.layout.cell * 3.6, 0, Math.PI * 2);
    ctx.fill();
  }
}

function drawRooms(ctx, match, now) {
  for (const room of match.rooms) {
    const color = room.def.hue || "#888";
    const teach = match.tutorial && match.tutorial.needAssign && match.tutorial.roomId === room.id;
    for (const c of room.cells) {
      const r = cellRect(match, c.x, c.y, 2.4);
      ctx.globalAlpha = room.built ? 1 : 0.28;
      ctx.fillStyle = color;
      round(ctx, r.x, r.y, r.w, r.h, 5);
      ctx.fill();
      ctx.globalAlpha = 1;
      const inner = ctx.createLinearGradient(r.x, r.y, r.x, r.y + r.h);
      inner.addColorStop(0, "rgba(255,255,255,0.16)");
      inner.addColorStop(0.45, "rgba(12,14,20,0.08)");
      inner.addColorStop(1, "rgba(12,14,20,0.28)");
      ctx.fillStyle = inner;
      round(ctx, r.x + 2.2, r.y + 2.2, r.w - 4.4, r.h - 4.4, 3.5);
      ctx.fill();
      if (!room.built) {
        ctx.strokeStyle = teach
          ? `rgba(232,217,160,${0.55 + Math.sin(now * 0.01) * 0.35})`
          : "rgba(255,255,255,0.35)";
        ctx.lineWidth = teach ? 2 : 1;
        ctx.setLineDash([4, 4]);
        round(ctx, r.x, r.y, r.w, r.h, 5);
        ctx.stroke();
        ctx.setLineDash([]);
        ctx.lineWidth = 1;
      } else if (room.production > 0 && (room.type === "garden" || room.type === "extractor")) {
        const glow = 0.08 + Math.min(0.22, room.production * 0.06);
        ctx.fillStyle = room.type === "extractor" ? `rgba(213,107,140,${glow})` : `rgba(94,168,106,${glow})`;
        round(ctx, r.x - 1, r.y - 1, r.w + 2, r.h + 2, 6);
        ctx.fill();
      }
      if (room.built) {
        const staff = match.kapsels.some((k) => k.assignment === room.id);
        if (staff) {
          ctx.fillStyle = "rgba(243,240,232,0.08)";
          round(ctx, r.x + 3, r.y + 3, r.w - 6, r.h - 6, 3);
          ctx.fill();
        }
      }
      if (teach && room.built) {
        ctx.strokeStyle = `rgba(232,217,160,${0.55 + Math.sin(now * 0.01) * 0.35})`;
        ctx.lineWidth = 2;
        round(ctx, r.x, r.y, r.w, r.h, 5);
        ctx.stroke();
        ctx.lineWidth = 1;
      }
    }
    if (match.selected === room.id) {
      ctx.strokeStyle = "rgba(243,240,232,0.85)";
      ctx.lineWidth = 2;
      for (const c of room.cells) {
        const r = cellRect(match, c.x, c.y, 1.2);
        round(ctx, r.x, r.y, r.w, r.h, 6);
        ctx.stroke();
      }
    }
    if (room.type === "core") {
      const breath = 0.55 + Math.sin(now * 0.003) * 0.2;
      ctx.fillStyle = `rgba(243,240,232,${0.12 + breath * 0.08})`;
      ctx.beginPath();
      ctx.arc(room.cx, room.cy, 11 + breath * 2, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "rgba(243,240,232,0.88)";
      ctx.font = "700 11px -apple-system, sans-serif";
      ctx.textAlign = "center";
      ctx.fillText("CORE", room.cx, room.cy + 4);
    } else if (room.built) {
      ctx.save();
      ctx.translate(room.cx, room.cy);
      ctx.strokeStyle = "rgba(243,240,232,0.72)";
      ctx.fillStyle = "rgba(243,240,232,0.72)";
      ctx.lineWidth = 1.6;
      if (room.type === "garden") {
        const sway = Math.sin(now * 0.004 + room.id) * 1.2;
        for (let i = -1; i <= 1; i++) {
          ctx.beginPath();
          ctx.moveTo(i * 7, 4);
          ctx.lineTo(i * 7 + sway, -6);
          ctx.stroke();
          ctx.beginPath();
          ctx.ellipse(i * 7 + sway - 3, -5, 3.2, 1.6, -0.4 + sway * 0.08, 0, Math.PI * 2);
          ctx.fill();
        }
      } else if (room.type === "extractor") {
        ctx.beginPath();
        ctx.moveTo(0, -8);
        ctx.lineTo(6, -1);
        ctx.lineTo(0, 6);
        ctx.lineTo(-6, -1);
        ctx.closePath();
        ctx.fill();
      } else if (room.type === "kitchen") {
        ctx.strokeRect(-10, -7, 20, 12);
        ctx.beginPath();
        ctx.arc(-4, -1, 3, 0, Math.PI * 2);
        ctx.arc(4, -1, 3, 0, Math.PI * 2);
        ctx.stroke();
        ctx.strokeStyle = `rgba(240,194,74,${0.35 + Math.sin(now * 0.006) * 0.2})`;
        for (let i = 0; i < 3; i++) {
          const t = ((now * 0.001 + i * 0.3) % 1);
          ctx.beginPath();
          ctx.arc(-6 + i * 6, -10 - t * 6, 1.4, 0, Math.PI * 2);
          ctx.stroke();
        }
      } else if (room.type === "quarters") {
        ctx.strokeRect(-11, -7, 9, 13);
        ctx.strokeRect(2, -7, 9, 13);
      } else if (room.type === "shield") {
        ctx.beginPath();
        ctx.arc(0, 0, 8, 0, Math.PI * 2);
        ctx.stroke();
        ctx.beginPath();
        ctx.arc(0, 0, 4, 0, Math.PI * 2);
        ctx.stroke();
      } else if (room.type === "gate") {
        gateFold(ctx, now, room);
      } else if (room.type === "heater") {
        ctx.beginPath();
        ctx.moveTo(0, 6);
        ctx.quadraticCurveTo(-8, -2, 0, -8);
        ctx.quadraticCurveTo(8, -2, 0, 6);
        ctx.stroke();
      } else if (room.type === "scanner") {
        ctx.beginPath();
        ctx.arc(0, 0, 7, -0.2, Math.PI * 1.2);
        ctx.stroke();
        ctx.beginPath();
        ctx.arc(0, 0, 1.6, 0, Math.PI * 2);
        ctx.fill();
        const sweep = (now * 0.003) % (Math.PI * 2);
        ctx.strokeStyle = "rgba(112,180,224,0.55)";
        ctx.beginPath();
        ctx.moveTo(0, 0);
        ctx.lineTo(Math.cos(sweep) * 10, Math.sin(sweep) * 10);
        ctx.stroke();
      } else if (room.type === "beacon") {
        for (let i = 0; i < 4; i++) {
          ctx.beginPath();
          ctx.moveTo(0, 0);
          ctx.lineTo(Math.cos((i * Math.PI) / 2) * 8, Math.sin((i * Math.PI) / 2) * 8);
          ctx.stroke();
        }
        ctx.beginPath();
        ctx.arc(0, 0, 2.2, 0, Math.PI * 2);
        ctx.fill();
      } else if (room.type === "corridor") {
        ctx.beginPath();
        ctx.moveTo(-5, 0);
        ctx.lineTo(5, 0);
        ctx.moveTo(0, -5);
        ctx.lineTo(0, 5);
        ctx.stroke();
      }
      ctx.restore();
    }
    if (room.type === "weapons" && room.built) {
      const hot = room.cooldown > 0.7;
      ctx.fillStyle = hot ? "#fff6d8" : "#f3f0e8";
      ctx.beginPath();
      ctx.arc(room.cx, room.cy, hot ? 4.4 : 3.2, 0, Math.PI * 2);
      ctx.fill();
      if (hot) {
        ctx.fillStyle = "rgba(255,236,180,0.28)";
        ctx.beginPath();
        ctx.arc(room.cx, room.cy, 11, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.strokeStyle = "#f3f0e8";
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(room.cx, room.cy);
      ctx.lineTo(room.cx + Math.cos(room.aim) * 8, room.cy + Math.sin(room.aim) * 8);
      ctx.stroke();
    }
    if (room.overclock > 0) {
      ctx.strokeStyle = "rgba(224,122,74,0.8)";
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.arc(room.cx, room.cy, 10 + Math.sin(now * 0.02) * 2, 0, Math.PI * 2);
      ctx.stroke();
    }
    if (!room.built) {
      ctx.fillStyle = "rgba(243,240,232,0.8)";
      ctx.font = "600 10px -apple-system, sans-serif";
      ctx.textAlign = "center";
      ctx.fillText(`${room.materials}/${room.def.cost}`, room.cx, room.cy + 3);
    }
    drawStock(ctx, room);
    if (room.hp < room.maxhp) {
      const w = 16;
      ctx.fillStyle = "rgba(0,0,0,0.35)";
      ctx.fillRect(room.cx - w / 2, room.cy + 10, w, 2);
      ctx.fillStyle = "#e24b52";
      ctx.fillRect(room.cx - w / 2, room.cy + 10, w * (room.hp / room.maxhp), 2);
    }
    if (room.hit > 0) {
      ctx.fillStyle = `rgba(255,255,255,${Math.min(0.45, room.hit * 2)})`;
      for (const c of room.cells) {
        const r = cellRect(match, c.x, c.y, 2.4);
        round(ctx, r.x, r.y, r.w, r.h, 5);
        ctx.fill();
      }
    }
  }
}

function drawStock(ctx, room) {
  const items = [];
  for (const res of ["mineral", "food", "biomass"]) {
    const n = Math.floor(room.stock[res] || 0);
    for (let i = 0; i < Math.min(n, 6); i++) items.push(res);
  }
  items.forEach((res, i) => {
    const col = res === "mineral" ? "#e07898" : res === "food" ? "#f0c24a" : "#6fbf6a";
    ctx.fillStyle = col;
    ctx.fillRect(room.cx - 10 + (i % 3) * 7, room.cy - 16 + Math.floor(i / 3) * 6, 5, 5);
  });
}

function drawKapsels(ctx, match) {
  for (const k of match.kapsels) {
    const bob = k.state === "idle" ? 0 : Math.sin(k.bob) * 1.1;
    if (k.state === "walking" && k.path && k.path[0]) {
      const L = match.layout;
      const tx = L.ox + (k.path[0].x + 0.5) * L.cell;
      const ty = L.oy + (k.path[0].y + 0.5) * L.cell;
      const dx = tx - k.x;
      const dy = ty - k.y;
      const d = Math.hypot(dx, dy) || 1;
      ctx.strokeStyle = "rgba(243,240,232,0.18)";
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(k.x, k.y + 2);
      ctx.lineTo(k.x - (dx / d) * 10, k.y - (dy / d) * 10 + 2);
      ctx.stroke();
    }
    ctx.fillStyle = "rgba(0,0,0,0.28)";
    ctx.beginPath();
    ctx.ellipse(k.x, k.y + 7, 5.5, 2.2, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#f3f0e8";
    round(ctx, k.x - 4.5, k.y - 8 + bob, 9, 15, 4);
    ctx.fill();
    ctx.fillStyle = "rgba(20,22,28,0.55)";
    ctx.fillRect(k.x - 2.2, k.y - 4 + bob, 4.4, 2.2);
    const pip =
      k.job && k.job.kind === "build"
        ? "#8d6b4a"
        : k.job && k.job.kind === "produce" && k.job.target && k.job.target.type === "extractor"
          ? "#d56b8c"
          : k.job && k.job.kind === "produce"
            ? "#5ea86a"
            : k.job && k.job.kind === "staff"
              ? "#7b88a3"
              : k.job && k.job.kind === "cook"
                ? "#f0c24a"
                : null;
    if (pip) {
      ctx.fillStyle = pip;
      ctx.fillRect(k.x + 3.2, k.y - 9 + bob, 3.2, 3.2);
    }
    if (k.carry) {
      const col = k.carry === "mineral" ? "#e07898" : k.carry === "food" ? "#f0c24a" : "#6fbf6a";
      ctx.fillStyle = col;
      ctx.fillRect(k.x - 3.5, k.y - 16 + bob, 7, 6);
    }
  }
}

function drawEnemies(ctx, match, now) {
  for (const e of match.enemies) {
    if (e.cloaked) {
      ctx.globalAlpha = 0.12 + Math.abs(Math.sin((now || 0) * 0.008)) * 0.08;
    }
    ctx.save();
    ctx.translate(e.x, e.y);
    ctx.rotate(e.dir + Math.PI / 2);
    ctx.fillStyle = "rgba(0,0,0,0.35)";
    ctx.beginPath();
    ctx.moveTo(0, -e.r + 2);
    ctx.lineTo(e.r - 1, e.r * 0.75);
    ctx.lineTo(-e.r + 1, e.r * 0.75);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = "#e24b52";
    ctx.beginPath();
    ctx.moveTo(0, -e.r);
    ctx.lineTo(e.r, e.r * 0.75);
    ctx.lineTo(0, e.r * 0.28);
    ctx.lineTo(-e.r, e.r * 0.75);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = "rgba(255,255,255,0.22)";
    ctx.beginPath();
    ctx.moveTo(0, -e.r + 2);
    ctx.lineTo(e.r * 0.35, -e.r * 0.2);
    ctx.lineTo(0, e.r * 0.1);
    ctx.closePath();
    ctx.fill();
    if ((e.hitTimer || 0) > 0) {
      ctx.fillStyle = `rgba(243,240,232,${Math.min(0.55, e.hitTimer * 2.4)})`;
      ctx.beginPath();
      ctx.moveTo(0, -e.r);
      ctx.lineTo(e.r, e.r * 0.75);
      ctx.lineTo(-e.r, e.r * 0.75);
      ctx.closePath();
      ctx.fill();
    }
    ctx.restore();
    ctx.globalAlpha = 1;
    if (e.hp < e.maxhp) {
      ctx.fillStyle = "rgba(255,255,255,0.35)";
      ctx.fillRect(e.x - 8, e.y - e.r - 7, 16, 2);
      ctx.fillStyle = "#e24b52";
      ctx.fillRect(e.x - 8, e.y - e.r - 7, 16 * (e.hp / e.maxhp), 2);
    }
  }
}

function drawShots(ctx, match) {
  for (const s of match.shots) {
    const dx = s.target ? s.target.x - s.x : 0;
    const dy = s.target ? s.target.y - s.y : 0;
    const d = Math.hypot(dx, dy) || 1;
    ctx.fillStyle = "rgba(243,240,232,0.22)";
    ctx.beginPath();
    ctx.arc(s.x, s.y, 10, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = "rgba(255,236,180,0.28)";
    ctx.lineWidth = 5;
    ctx.beginPath();
    ctx.moveTo(s.x, s.y);
    ctx.lineTo(s.x - (dx / d) * 18, s.y - (dy / d) * 18);
    ctx.stroke();
    ctx.strokeStyle = "rgba(243,240,232,0.22)";
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(s.x, s.y);
    ctx.lineTo(s.x - (dx / d) * 16, s.y - (dy / d) * 16);
    ctx.stroke();
    ctx.strokeStyle = "rgba(243,240,232,0.7)";
    ctx.lineWidth = 1.6;
    ctx.beginPath();
    ctx.moveTo(s.x, s.y);
    ctx.lineTo(s.x - (dx / d) * 10, s.y - (dy / d) * 10);
    ctx.stroke();
    ctx.fillStyle = "#fff8e8";
    ctx.beginPath();
    ctx.arc(s.x, s.y, 2.8, 0, Math.PI * 2);
    ctx.fill();
  }
}

function drawFx(ctx, match, now) {
  for (const f of match.fx) {
    const a = Math.max(0, 1 - f.t / f.life);
    ctx.globalAlpha = a;
    if (f.kind === "spark") {
      ctx.strokeStyle = f.hue || "#f3f0e8";
      ctx.lineWidth = 1.4;
      for (let i = 0; i < 6; i++) {
        const ang = (i * Math.PI) / 3 + f.t * 9;
        const r = 5 + f.t * 26;
        ctx.beginPath();
        ctx.moveTo(f.x, f.y);
        ctx.lineTo(f.x + Math.cos(ang) * r, f.y + Math.sin(ang) * r);
        ctx.stroke();
      }
    } else if (f.kind === "muzzle") {
      ctx.fillStyle = `rgba(255,236,180,${0.55 * a})`;
      ctx.beginPath();
      ctx.arc(f.x, f.y, 7 + f.t * 18, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = `rgba(243,240,232,${0.85 * a})`;
      ctx.lineWidth = 2;
      for (let i = 0; i < 5; i++) {
        const ang = (i / 5) * Math.PI * 2 + f.t * 14;
        ctx.beginPath();
        ctx.moveTo(f.x, f.y);
        ctx.lineTo(f.x + Math.cos(ang) * (8 + f.t * 20), f.y + Math.sin(ang) * (8 + f.t * 20));
        ctx.stroke();
      }
    } else if (f.kind === "burst") {
      ctx.fillStyle = f.hue || "#e24b52";
      for (let i = 0; i < 8; i++) {
        const ang = (i / 8) * Math.PI * 2 + f.t * 6;
        const r = 3 + f.t * 22;
        ctx.beginPath();
        ctx.arc(f.x + Math.cos(ang) * r, f.y + Math.sin(ang) * r, 1.8 * a, 0, Math.PI * 2);
        ctx.fill();
      }
    } else if (f.kind === "kiss") {
      ctx.strokeStyle = f.hue || "#e8d9a0";
      ctx.lineWidth = 2.4;
      ctx.beginPath();
      ctx.arc(f.x, f.y, 6 + f.t * 38, 0, Math.PI * 2);
      ctx.stroke();
      ctx.strokeStyle = `rgba(232,217,160,${0.45 * a})`;
      ctx.lineWidth = 1.2;
      ctx.beginPath();
      ctx.arc(f.x, f.y, 14 + f.t * 22, 0, Math.PI * 2);
      ctx.stroke();
    } else if (f.kind === "pulse") {
      ctx.strokeStyle = f.hue || "#f3f0e8";
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.arc(f.x, f.y, 4 + f.t * 28, 0, Math.PI * 2);
      ctx.stroke();
    } else {
      ctx.fillStyle = f.hue || "#f3f0e8";
      for (let i = 0; i < 5; i++) {
        const ang = (i / 5) * Math.PI * 2 + now * 0.002;
        const r = 4 + f.t * 14;
        ctx.beginPath();
        ctx.arc(f.x + Math.cos(ang) * r, f.y + Math.sin(ang) * r, 1.6, 0, Math.PI * 2);
        ctx.fill();
      }
    }
    ctx.globalAlpha = 1;
  }
}

function drawGhost(ctx, match, ghost) {
  if (!ghost || !ghost.cells || !ghost.cells.length) return;
  ctx.fillStyle = ghost.ok ? "rgba(94,168,106,0.38)" : "rgba(226,75,82,0.35)";
  ctx.strokeStyle = ghost.ok ? "rgba(94,168,106,0.9)" : "rgba(226,75,82,0.9)";
  ctx.lineWidth = 1.5;
  for (const c of ghost.cells) {
    const r = cellRect(match, c.x, c.y, 3);
    round(ctx, r.x, r.y, r.w, r.h, 5);
    ctx.fill();
    ctx.stroke();
  }
}

function drawFloats(ctx, match) {
  for (const f of match.floats) {
    const a = 1 - f.t / f.life;
    ctx.globalAlpha = a;
    ctx.fillStyle = f.color === "mineral" ? "#e07898" : f.color === "biomass" ? "#6fbf6a" : "#f0c24a";
    ctx.font = "700 11px -apple-system, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText(f.text, f.x, f.y - f.t * 18);
    ctx.globalAlpha = 1;
  }
}

function drawVignette(ctx, match, w, h, clock) {
  const v = ctx.createRadialGradient(w / 2, h * 0.42, Math.min(w, h) * 0.18, w / 2, h / 2, Math.max(w, h) * 0.74);
  v.addColorStop(0, "rgba(0,0,0,0)");
  v.addColorStop(0.7, "rgba(0,0,0,0.12)");
  v.addColorStop(1, "rgba(0,0,0,0.46)");
  ctx.fillStyle = v;
  ctx.fillRect(0, 0, w, h);
  if (match.thinkLocked) {
    const beat = Math.sin((clock || 0) * 0.003);
    ctx.fillStyle = "rgba(70, 110, 160, 0.1)";
    ctx.fillRect(0, 0, w, h);
    ctx.strokeStyle = `rgba(160, 200, 240, ${0.18 + beat * 0.08})`;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(w / 2, h * 0.42, 52 + beat * 4, 0, Math.PI * 2);
    ctx.stroke();
  }
  if (match.flare && match.flare.warning > 0) {
    ctx.fillStyle = `rgba(224,122,74,${0.12 * match.flare.warning})`;
    ctx.fillRect(0, 0, w, h);
  }
  const spec = match.waves;
  if (spec.timer < 8 && spec.timer < 900) {
    const a = spec.timer <= 0 ? 0.18 : (1 - spec.timer / 8) * 0.14;
    ctx.fillStyle = `rgba(226,75,82,${a})`;
    ctx.fillRect(0, 0, w, 8);
    ctx.fillRect(0, h - 8, w, 8);
    if (spec.warned) {
      const pulse = 0.08 + Math.sin((match.time || 0) * 12) * 0.05;
      ctx.strokeStyle = `rgba(226,75,82,${0.22 + pulse})`;
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.arc(w / 2, h * 0.42, 48 + (1 - Math.max(0, spec.timer) / 8) * 70, 0, Math.PI * 2);
      ctx.stroke();
    }
  }
}

export { ROOMS };

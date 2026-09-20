import { ROOMS, canPlace } from "./sim.js";

const VOID = "#07080d";
let stars = null;

function seedStars(n) {
  stars = [];
  let s = 1337;
  const rnd = () => {
    s = (Math.imul(s, 1664525) + 1013904223) >>> 0;
    return s / 4294967296;
  };
  for (let i = 0; i < n; i++) {
    stars.push({
      x: rnd(),
      y: rnd(),
      r: rnd() * 1.2 + 0.3,
      a: rnd() * 0.55 + 0.15,
      p: rnd() * Math.PI * 2,
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
  if (!stars) seedStars(90);
  ctx.clearRect(0, 0, w, h);
  ctx.save();
  if (match.shake > 0) {
    ctx.translate((Math.random() - 0.5) * match.shake * 10, (Math.random() - 0.5) * match.shake * 10);
  }

  const g = ctx.createRadialGradient(w * 0.3, h * 0.2, 20, w * 0.45, h * 0.45, Math.max(w, h) * 0.7);
  g.addColorStop(0, "#12141c");
  g.addColorStop(0.45, VOID);
  g.addColorStop(1, "#050508");
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, w, h);

  ctx.fillStyle = "#1a2030";
  ctx.beginPath();
  ctx.arc(-20, h + 40, 160, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "#161822";
  ctx.beginPath();
  ctx.arc(w + 30, 90, 110, 0, Math.PI * 2);
  ctx.fill();

  for (const st of stars) {
    const tw = 0.6 + Math.sin(now * 0.0018 + st.p) * 0.4;
    ctx.fillStyle = `rgba(236,234,226,${st.a * tw})`;
    ctx.beginPath();
    ctx.arc(st.x * w, st.y * h, st.r, 0, Math.PI * 2);
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
  drawValidCells(ctx, match);
  drawRooms(ctx, match, now);
  drawKapsels(ctx, match);
  drawEnemies(ctx, match);
  drawShots(ctx, match);
  drawGhost(ctx, match, view.ghost);
  drawFloats(ctx, match);
  drawVignette(ctx, match, w, h);
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
    const r = cellRect(match, relic.x, relic.y, 7);
    ctx.fillStyle = relic.linked ? "#e8d9a0" : "#9aa0ae";
    ctx.beginPath();
    ctx.moveTo(r.x + r.w / 2, r.y - 6);
    ctx.lineTo(r.x + r.w, r.y + r.h);
    ctx.lineTo(r.x, r.y + r.h);
    ctx.closePath();
    ctx.fill();
    if (relic.linked) {
      ctx.strokeStyle = "rgba(232,217,160,0.55)";
      ctx.stroke();
    }
  }
}

function drawRooms(ctx, match, now) {
  for (const room of match.rooms) {
    const color = room.def.hue || "#888";
    for (const c of room.cells) {
      const r = cellRect(match, c.x, c.y, 2.4);
      ctx.globalAlpha = room.built ? 1 : 0.28;
      ctx.fillStyle = color;
      round(ctx, r.x, r.y, r.w, r.h, 5);
      ctx.fill();
      ctx.globalAlpha = 1;
      ctx.fillStyle = "rgba(255,255,255,0.14)";
      round(ctx, r.x + 2, r.y + 2, r.w - 4, Math.max(3, r.h * 0.22), 3);
      ctx.fill();
      if (!room.built) {
        ctx.strokeStyle = "rgba(255,255,255,0.35)";
        ctx.setLineDash([4, 4]);
        ctx.stroke();
        ctx.setLineDash([]);
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
        for (let i = -1; i <= 1; i++) {
          ctx.beginPath();
          ctx.moveTo(i * 7, 4);
          ctx.lineTo(i * 7, -6);
          ctx.stroke();
          ctx.beginPath();
          ctx.ellipse(i * 7 - 3, -5, 3.2, 1.6, -0.4, 0, Math.PI * 2);
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
        ctx.strokeRect(-6, -6, 12, 12);
        ctx.beginPath();
        ctx.moveTo(-3, 0);
        ctx.lineTo(3, 0);
        ctx.moveTo(0, -3);
        ctx.lineTo(0, 3);
        ctx.stroke();
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
      }
      ctx.restore();
    }
    if (room.type === "weapons" && room.built) {
      ctx.fillStyle = "#f3f0e8";
      ctx.beginPath();
      ctx.arc(room.cx, room.cy, 3.2, 0, Math.PI * 2);
      ctx.fill();
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
    ctx.fillStyle = "rgba(0,0,0,0.28)";
    ctx.beginPath();
    ctx.ellipse(k.x, k.y + 7, 5.5, 2.2, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#f3f0e8";
    round(ctx, k.x - 4.5, k.y - 8 + bob, 9, 15, 4);
    ctx.fill();
    ctx.fillStyle = "rgba(20,22,28,0.55)";
    ctx.fillRect(k.x - 2.2, k.y - 4 + bob, 4.4, 2.2);
    if (k.carry) {
      const col = k.carry === "mineral" ? "#e07898" : k.carry === "food" ? "#f0c24a" : "#6fbf6a";
      ctx.fillStyle = col;
      ctx.fillRect(k.x - 3.5, k.y - 16 + bob, 7, 6);
    }
  }
}

function drawEnemies(ctx, match) {
  for (const e of match.enemies) {
    if (e.cloaked) {
      ctx.globalAlpha = 0.16;
    }
    ctx.save();
    ctx.translate(e.x, e.y);
    ctx.rotate(e.dir + Math.PI / 2);
    ctx.fillStyle = "#e24b52";
    ctx.beginPath();
    ctx.moveTo(0, -e.r);
    ctx.lineTo(e.r, e.r * 0.75);
    ctx.lineTo(0, e.r * 0.28);
    ctx.lineTo(-e.r, e.r * 0.75);
    ctx.closePath();
    ctx.fill();
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
  ctx.fillStyle = "#f3f0e8";
  for (const s of match.shots) {
    ctx.beginPath();
    ctx.arc(s.x, s.y, 2.4, 0, Math.PI * 2);
    ctx.fill();
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
    ctx.fillStyle = f.color === "mineral" ? "#e07898" : "#f0c24a";
    ctx.font = "700 11px -apple-system, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText(f.text, f.x, f.y - f.t * 18);
    ctx.globalAlpha = 1;
  }
}

function drawVignette(ctx, match, w, h) {
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
  }
}

export { ROOMS };

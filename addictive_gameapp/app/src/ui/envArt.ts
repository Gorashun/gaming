/**
 * envArt.ts – referensrenderare för miljö, glasburk och delade effekt-sprites ("Art v3",
 * docs/ART_DIRECTION.md). Ren TS och Canvas2D, INGEN Phaser-import. Parametrar: `data/artEnv.ts`.
 *
 * PROTOTYP (art director, fas 1). Allt här är tänkt att BAKAS EN GÅNG till texturer:
 *   - renderEnvBase     → `env-{set}@{Z}`       (himmel, fjärrlager, vinjett; stilla)
 *   - renderBeam        → `fx-beam`             (en stråle; 4 instanser svajar med ADD)
 *   - renderCausticTile → `fx-caustic`          (tilebar; två TileSprite-lager scrollar mot varandra)
 *   - renderJarBack/Front → `jar-back-{set}`, `jar-front-{set}` (glaset under resp. över objekten)
 *   - renderGlow/Shock/Sparkle/Streak → `fx-glow`, `fx-shock`, `fx-sparkle`, `fx-streak` (vita, tintas)
 * Per frame flyttas bara sprites (x/y/rot/alpha/tilePosition). Inga gradienter, skuggor eller
 * filter i update(). `renderRays` och `renderMotes` ritar ett helt lager på en gång och används bara
 * för koncept-/granskningsbilder.
 *
 * Kontexten ska ha identitetstransform; `dpr` skalar logiska px till enhetspixlar.
 */

import { ENV, ENV_SETS, FX_SPRITES, GLASS, type EnvSet, type EnvSetId } from '../data/artEnv';
import { mulberry32 } from '../systems/rng';

type Ctx = CanvasRenderingContext2D | OffscreenCanvasRenderingContext2D;

// ------------------------------------------------------------------ färghjälp

function rgb(hex: string): [number, number, number] {
  const n = parseInt(hex.slice(1), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

/** `#RRGGBB` + alpha → rgba(). */
export function rgba(hex: string, a: number): string {
  const [r, g, b] = rgb(hex);
  return `rgba(${r},${g},${b},${Math.max(0, Math.min(1, a)).toFixed(3)})`;
}

function mix(a: string, b: string, t: number): string {
  const x = rgb(a);
  const y = rgb(b);
  const c = x.map((v, i) => Math.round(v + (y[i] - v) * t));
  return `#${c.map((v) => v.toString(16).padStart(2, '0')).join('')}`;
}

export function envSet(id: string): EnvSet {
  return ENV_SETS[(id in ENV_SETS ? id : 'glimtarna') as EnvSetId];
}

// ------------------------------------------------------------------ miljö (bakas en gång per set)

/**
 * Himmel + setets takljus (stilla del) + fjärrlager + vinjett, w×h logiska px.
 * Rörliga delar (strålar, kaustik, partiklar) ritas som separata lager ovanpå.
 */
export function renderEnvBase(ctx: Ctx, setId: string, w: number, h: number, dpr = 1): void {
  const s = envSet(setId);
  ctx.save();
  ctx.scale(dpr, dpr);
  // 1. Himmel
  const g = ctx.createLinearGradient(0, 0, 0, h);
  g.addColorStop(0, s.sky[0]);
  g.addColorStop(0.45, s.sky[1]);
  g.addColorStop(1, s.sky[2]);
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, w, h);

  // 2. Stilla takljus
  ctx.globalCompositeOperation = 'lighter';
  if (s.skyLight === 'nebula') {
    const rng = mulberry32(7);
    for (let i = 0; i < 5; i++) {
      const cx = w * (0.15 + rng.next() * 0.7);
      const cy = h * (0.08 + rng.next() * 0.35);
      const r = 90 + rng.next() * 110;
      const rg = ctx.createRadialGradient(cx, cy, 0, cx, cy, r);
      const c = i % 2 ? s.light : '#FF7FC8';
      rg.addColorStop(0, rgba(c, 0.12));
      rg.addColorStop(1, rgba(c, 0));
      ctx.fillStyle = rg;
      ctx.fillRect(0, 0, w, h);
    }
  } else if (s.skyLight === 'aurora') {
    for (let k = 0; k < 3; k++) {
      ctx.beginPath();
      const y0 = h * (0.06 + k * 0.05);
      ctx.moveTo(-10, y0);
      for (let x = 0; x <= w + 10; x += 12) ctx.lineTo(x, y0 + Math.sin(x / 55 + k * 1.7) * 14 + x * 0.04);
      ctx.lineWidth = 26 - k * 6;
      ctx.strokeStyle = rgba(k === 1 ? '#B69CFF' : s.light, 0.1 - k * 0.02);
      ctx.filter = 'blur(10px)';
      ctx.stroke();
      ctx.filter = 'none';
    }
  } else if (s.skyLight === 'uplight') {
    const rg = ctx.createRadialGradient(w / 2, h * 1.05, 0, w / 2, h * 1.05, h * 0.7);
    rg.addColorStop(0, rgba(s.light, 0.3));
    rg.addColorStop(0.5, rgba(s.light, 0.08));
    rg.addColorStop(1, rgba(s.light, 0));
    ctx.fillStyle = rg;
    ctx.fillRect(0, 0, w, h);
  } else {
    // 'rays': ytans ljus som en bred mjuk fläck uppe till vänster (strålarna själva rör sig).
    const rg = ctx.createRadialGradient(w * 0.3, -h * 0.05, 0, w * 0.3, -h * 0.05, h * 0.55);
    rg.addColorStop(0, rgba(s.light, 0.16));
    rg.addColorStop(1, rgba(s.light, 0));
    ctx.fillStyle = rg;
    ctx.fillRect(0, 0, w, h);
  }
  ctx.globalCompositeOperation = 'source-over';

  // 3. Fjärrlager (siluetter), två toner för djup
  renderFar(ctx, s, w, h, mix(s.sky[1], s.far, 0.5), 0.55, 11);
  renderFar(ctx, s, w, h, s.far, 1, 3);

  // 4. Vinjett
  const vg = ctx.createRadialGradient(w / 2, h * 0.48, Math.min(w, h) * ENV.vignette.inner * 0.6, w / 2, h * 0.48, Math.max(w, h) * 0.75);
  vg.addColorStop(0, 'rgba(0,0,0,0)');
  vg.addColorStop(1, `rgba(0,0,0,${ENV.vignette.alpha})`);
  ctx.fillStyle = vg;
  ctx.fillRect(0, 0, w, h);
  ctx.restore();
}

function renderFar(ctx: Ctx, s: EnvSet, w: number, h: number, color: string, scale: number, seed: number): void {
  const rng = mulberry32(seed);
  ctx.fillStyle = color;
  ctx.strokeStyle = color;
  ctx.lineCap = 'round';
  const base = h;
  switch (s.farMotif) {
    case 'kelp':
      for (let i = 0; i < 7; i++) {
        const x = rng.next() * w;
        const top = base - (120 + rng.next() * 260) * scale;
        ctx.lineWidth = (7 + rng.next() * 7) * scale;
        ctx.beginPath();
        ctx.moveTo(x, base + 10);
        const sway = (rng.next() - 0.5) * 60;
        ctx.bezierCurveTo(x + sway, base - (base - top) * 0.3, x - sway, base - (base - top) * 0.7, x + sway * 0.5, top);
        ctx.stroke();
        for (let k = 1; k < 6; k++) {
          const t = k / 6;
          const ly = base - (base - top) * t;
          ctx.beginPath();
          ctx.ellipse(x + sway * (t - 0.5) + (k % 2 ? 10 : -10) * scale, ly, 12 * scale, 5 * scale, k % 2 ? 0.5 : -0.5, 0, Math.PI * 2);
          ctx.fill();
        }
      }
      // sanddyner
      ctx.beginPath();
      ctx.moveTo(0, base);
      for (let x = 0; x <= w; x += 20) ctx.lineTo(x, base - 18 * scale - Math.sin(x / 70 + seed) * 10 * scale);
      ctx.lineTo(w, base);
      ctx.fill();
      break;
    case 'planet': {
      const cx = scale < 1 ? w * 0.82 : w * 0.12;
      const cy = scale < 1 ? h * 0.22 : h * 0.86;
      const r = scale < 1 ? 46 : 120;
      ctx.beginPath();
      ctx.arc(cx, cy, r, 0, Math.PI * 2);
      ctx.fill();
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.ellipse(cx, cy, r * 1.7, r * 0.3, -0.25, 0, Math.PI * 2);
      ctx.stroke();
      for (let i = 0; i < 90 * scale; i++) {
        ctx.fillStyle = rgba('#FFF4D6', 0.15 + rng.next() * 0.35);
        ctx.beginPath();
        ctx.arc(rng.next() * w, rng.next() * h * 0.8, 0.4 + rng.next() * 0.9, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.fillStyle = color;
      break;
    }
    case 'iceShelf':
      ctx.beginPath();
      ctx.moveTo(0, base);
      for (let x = 0; x <= w + 30; x += 30) {
        ctx.lineTo(x, base - (40 + rng.next() * 90) * scale);
        ctx.lineTo(x + 15, base - (70 + rng.next() * 130) * scale);
      }
      ctx.lineTo(w, base);
      ctx.fill();
      break;
    case 'candyHills':
      for (let i = 0; i < 5; i++) {
        const x = rng.next() * w;
        const r = (50 + rng.next() * 60) * scale;
        ctx.beginPath();
        ctx.arc(x, base - r * 0.3, r, Math.PI, 0);
        ctx.fill();
        ctx.lineWidth = 5 * scale;
        ctx.beginPath();
        ctx.moveTo(x + r * 0.2, base - r * 1.1);
        ctx.lineTo(x + r * 0.2, base - r * 2.2);
        ctx.stroke();
        ctx.beginPath();
        ctx.arc(x + r * 0.2, base - r * 2.4, r * 0.3, 0, Math.PI * 2);
        ctx.fill();
      }
      break;
    case 'rocks':
      ctx.beginPath();
      ctx.moveTo(0, base);
      for (let x = 0; x <= w + 40; x += 40) ctx.lineTo(x, base - (30 + rng.next() * 120) * scale);
      ctx.lineTo(w, base);
      ctx.fill();
      break;
  }
}

/** Strålar eller band (för granskningsbilder; i spelet: `renderBeam` × ENV.rays.count som sprites). */
export function renderRays(ctx: Ctx, setId: string, w: number, h: number, dpr = 1, t = 0): void {
  const s = envSet(setId);
  if (s.skyLight !== 'rays') return;
  const R = ENV.rays;
  const rng = mulberry32(21);
  ctx.save();
  ctx.scale(dpr, dpr);
  ctx.globalCompositeOperation = 'lighter';
  for (let i = 0; i < R.count; i++) {
    const x0 = w * (0.08 + (i / R.count) * 0.8) + Math.sin(t * Math.PI * 2 * R.swayHz + i * 1.9) * R.swayPx;
    const bw = R.widthMin + rng.next() * (R.widthMax - R.widthMin);
    const len = h * R.lengthFrac;
    ctx.save();
    ctx.translate(x0, -10);
    ctx.rotate(-R.angle);
    const g = ctx.createLinearGradient(0, 0, 0, len);
    const a = s.lightAlpha * (0.7 + rng.next() * 0.6);
    g.addColorStop(0, rgba(s.light, a));
    g.addColorStop(0.6, rgba(s.light, a * 0.35));
    g.addColorStop(1, rgba(s.light, 0));
    ctx.fillStyle = g;
    ctx.filter = 'blur(6px)';
    ctx.beginPath();
    ctx.moveTo(-bw * 0.35, 0);
    ctx.lineTo(bw * 0.35, 0);
    ctx.lineTo(bw * 0.7, len);
    ctx.lineTo(-bw * 0.7, len);
    ctx.closePath();
    ctx.fill();
    ctx.filter = 'none';
    ctx.restore();
  }
  ctx.restore();
}

/** Partiklar (snö, stjärnor, flingor, bokeh, glöd) – ett stillbildsögonblick vid tid `t` s. */
export function renderMotes(ctx: Ctx, setId: string, w: number, h: number, dpr = 1, t = 0, count: number = ENV.motes.count): void {
  const s = envSet(setId);
  const M = ENV.motes;
  const rng = mulberry32(99);
  ctx.save();
  ctx.scale(dpr, dpr);
  ctx.globalCompositeOperation = 'lighter';
  for (let i = 0; i < count; i++) {
    const x0 = rng.next() * w;
    const y0 = rng.next() * h;
    const y = (((y0 + s.moteVy * t) % h) + h) % h;
    const x = x0 + Math.sin(t * M.wobbleHz * Math.PI * 2 + i) * M.wobblePx;
    const big = s.mote === 'bokeh' ? 4 : 1;
    const r = (M.rMin + rng.next() * (M.rMax - M.rMin)) * big;
    const a = M.alphaMin + rng.next() * (M.alphaMax - M.alphaMin);
    const g = ctx.createRadialGradient(x, y, 0, x, y, r * 2.2);
    g.addColorStop(0, rgba(s.moteColor, s.mote === 'bokeh' ? a * 0.45 : a));
    g.addColorStop(0.45, rgba(s.moteColor, a * 0.35));
    g.addColorStop(1, rgba(s.moteColor, 0));
    ctx.fillStyle = g;
    ctx.fillRect(x - r * 2.2, y - r * 2.2, r * 4.4, r * 4.4);
  }
  ctx.restore();
}

// ------------------------------------------------------------------ kaustik (bakas en gång, tilebar)

/**
 * Vit kaustik på transparent botten, `tile`×`tile` logiska px, tilebar i båda led.
 * Ljus där avståndet till närmaste och näst närmaste cellpunkt nästan är lika (Voronoi-kanter),
 * vilket ger det typiska nätet. En punkt per cell och 3×3 grannar: ~40 ms vid dpr 2 på skrivbord (≈200 ms billig Android; baka i 1× om fps-vakten har utlösts), bakas en gång.
 */
export function renderCausticTile(ctx: Ctx, dpr = 1, seed = 5): void {
  const C = ENV.caustic;
  const px = Math.round(C.tile * dpr);
  const n = C.cells;
  const rng = mulberry32(seed);
  const pts: number[] = [];
  for (let i = 0; i < n * n; i++) pts.push(((i % n) + 0.15 + rng.next() * 0.7) / n, (Math.floor(i / n) + 0.15 + rng.next() * 0.7) / n);
  const img = ctx.createImageData(px, px);
  const d = img.data;
  const edge = (C.lineW / C.tile) * 1.4;
  // En punkt per cell: bara 3×3 grannceller behöver provas (tilebart via modulo).
  const TAU = Math.PI * 2;
  for (let y = 0; y < px; y++) {
    const v0 = y / px;
    for (let x = 0; x < px; x++) {
      const u0 = x / px;
      // Tilebar domänvridning (heltalsfrekvenser): kanterna blir böjda i stället för raka Voronoi-linjer.
      let u = u0 + C.warp * Math.sin(TAU * (2 * v0 + u0));
      let v = v0 + C.warp * Math.sin(TAU * (2 * u0 - v0) + 1.3);
      u -= Math.floor(u);
      v -= Math.floor(v);
      const cy = Math.floor(v * n);
      const cx = Math.floor(u * n);
      let f1 = 9;
      let f2 = 9;
      for (let oy = -1; oy <= 1; oy++) {
        const gy = cy + oy;
        const wy = ((gy % n) + n) % n;
        for (let ox = -1; ox <= 1; ox++) {
          const gx = cx + ox;
          const wx = ((gx % n) + n) % n;
          const k = (wy * n + wx) * 2;
          const dx = pts[k] + (gx - wx) / n - u;
          const dy = pts[k + 1] + (gy - wy) / n - v;
          const dd = dx * dx + dy * dy;
          if (dd < f1) {
            f2 = f1;
            f1 = dd;
          } else if (dd < f2) f2 = dd;
        }
      }
      const e = Math.sqrt(f2) - Math.sqrt(f1);
      // Ljusare där linjerna möts (nära cellens hörn = stort f1): knutpunkterna glittrar.
      const a = Math.max(0, 1 - e / edge) * Math.min(1, 0.45 + Math.sqrt(f1) * n * 0.9);
      const i = (y * px + x) * 4;
      d[i] = d[i + 1] = d[i + 2] = 255;
      d[i + 3] = Math.round(255 * a * a);
    }
  }
  ctx.putImageData(img, 0, 0);
}

// ------------------------------------------------------------------ glasburken

export interface JarRect {
  readonly x: number;
  readonly y: number;
  readonly w: number;
  readonly h: number;
}

function roundRect(ctx: Ctx, r: JarRect, rad: number, topSquare = true): void {
  const { x, y, w, h } = r;
  ctx.beginPath();
  ctx.moveTo(x, y);
  ctx.lineTo(x + w, y);
  ctx.lineTo(x + w, y + h - rad);
  ctx.quadraticCurveTo(x + w, y + h, x + w - rad, y + h);
  ctx.lineTo(x + rad, y + h);
  ctx.quadraticCurveTo(x, y + h, x, y + h - rad);
  ctx.lineTo(x, topSquare ? y : y + rad);
  ctx.closePath();
}

/**
 * Glasets bakre panel (under objekten): tonad genomskinlighet, inre djupskugga, golv.
 * `inner` = burkens inre rum (logiska px). Kaustiken läggs ovanpå som eget lager, klippt till `inner`.
 */
export function renderJarBack(ctx: Ctx, setId: string, inner: JarRect, dpr = 1): void {
  const s = envSet(setId);
  ctx.save();
  ctx.scale(dpr, dpr);
  roundRect(ctx, inner, GLASS.cornerR);
  ctx.save();
  ctx.clip();
  // mörkare, genomskinligt rum (miljön syns svagt igenom)
  ctx.fillStyle = 'rgba(4,8,18,0.38)';
  ctx.fillRect(inner.x, inner.y, inner.w, inner.h);
  const g = ctx.createLinearGradient(0, inner.y, 0, inner.y + inner.h);
  g.addColorStop(0, rgba(s.glassTint, GLASS.backAlpha[0]));
  g.addColorStop(1, rgba(s.glassTint, GLASS.backAlpha[1]));
  ctx.fillStyle = g;
  ctx.fillRect(inner.x, inner.y, inner.w, inner.h);
  // golv
  const fy = inner.y + inner.h - GLASS.floorH;
  const fg = ctx.createLinearGradient(0, fy, 0, inner.y + inner.h);
  fg.addColorStop(0, s.floor[0]);
  fg.addColorStop(1, s.floor[1]);
  ctx.fillStyle = fg;
  ctx.beginPath();
  ctx.moveTo(inner.x, fy + 6);
  ctx.quadraticCurveTo(inner.x + inner.w * 0.3, fy - 4, inner.x + inner.w * 0.55, fy + 3);
  ctx.quadraticCurveTo(inner.x + inner.w * 0.8, fy + 9, inner.x + inner.w, fy + 1);
  ctx.lineTo(inner.x + inner.w, inner.y + inner.h);
  ctx.lineTo(inner.x, inner.y + inner.h);
  ctx.fill();
  // inre djupskugga längs väggarna och golvet
  const W = GLASS.innerShadow.width;
  const sides: Array<[number, number, number, number, number, number, number, number]> = [
    [inner.x, 0, inner.x + W, 0, inner.x, inner.y, W, inner.h],
    [inner.x + inner.w, 0, inner.x + inner.w - W, 0, inner.x + inner.w - W, inner.y, W, inner.h],
  ];
  for (const [x0, y0, x1, y1, rx, ry, rw, rh] of sides) {
    const sg = ctx.createLinearGradient(x0, y0, x1, y1);
    sg.addColorStop(0, `rgba(0,0,0,${GLASS.innerShadow.alpha})`);
    sg.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = sg;
    ctx.fillRect(rx, ry, rw, rh);
  }
  ctx.restore();
  ctx.restore();
}

/**
 * Främre glaset (över objekten, under HUD): fresnelkant, reflexband, spekulär prick, kontur och läpp.
 * Allt är ljust och tunt: objekt och ansikten syns alltid igenom (max alpha 0,13 över spelytan).
 */
export function renderJarFront(ctx: Ctx, setId: string, inner: JarRect, dpr = 1): void {
  const s = envSet(setId);
  ctx.save();
  ctx.scale(dpr, dpr);
  roundRect(ctx, inner, GLASS.cornerR);
  ctx.save();
  ctx.clip();
  ctx.globalCompositeOperation = 'lighter';
  // fresnel på insidan av väggarna
  const F = GLASS.fresnel;
  for (const side of [0, 1]) {
    const x0 = side ? inner.x + inner.w : inner.x;
    const fg = ctx.createLinearGradient(x0, 0, side ? x0 - F.width * 3 : x0 + F.width * 3, 0);
    fg.addColorStop(0, rgba(s.glassTint, F.alpha));
    fg.addColorStop(0.35, rgba(s.glassTint, F.alpha * 0.25));
    fg.addColorStop(1, rgba(s.glassTint, 0));
    ctx.fillStyle = fg;
    ctx.fillRect(side ? x0 - F.width * 3 : x0, inner.y, F.width * 3, inner.h);
  }
  // reflexband (lodräta, svagt avsmalnande mot botten)
  for (const b of GLASS.bands) {
    const cx = inner.x + inner.w * b.x;
    const bg = ctx.createLinearGradient(cx - b.w / 2, 0, cx + b.w / 2, 0);
    bg.addColorStop(0, rgba('#FFFFFF', 0));
    bg.addColorStop(0.5 - b.soft / 2, rgba('#FFFFFF', b.alpha));
    bg.addColorStop(0.5 + b.soft / 2, rgba('#FFFFFF', b.alpha));
    bg.addColorStop(1, rgba('#FFFFFF', 0));
    ctx.fillStyle = bg;
    ctx.fillRect(cx - b.w / 2, inner.y, b.w, inner.h * 0.78);
  }
  // spekulär prick
  const sp = GLASS.spec;
  const sx = inner.x + inner.w * sp.x;
  const sy = inner.y + inner.h * sp.y + 14;
  const sg = ctx.createRadialGradient(sx, sy, 0, sx, sy, sp.r * 2.5);
  sg.addColorStop(0, rgba('#FFFFFF', sp.alpha));
  sg.addColorStop(0.3, rgba('#FFFFFF', sp.alpha * 0.3));
  sg.addColorStop(1, rgba('#FFFFFF', 0));
  ctx.fillStyle = sg;
  ctx.fillRect(sx - sp.r * 3, sy - sp.r * 3, sp.r * 6, sp.r * 6);
  ctx.restore();

  // kontur: mörk ytterkant + ljus innerkant = glasets tjocklek
  const E = GLASS.edge;
  ctx.lineJoin = 'round';
  roundRect(ctx, { x: inner.x - 4, y: inner.y, w: inner.w + 8, h: inner.h + 4 }, GLASS.cornerR + 4);
  ctx.strokeStyle = E.outerColor;
  ctx.lineWidth = E.outer + 2;
  ctx.stroke();
  const eg = ctx.createLinearGradient(inner.x, inner.y, inner.x + inner.w, inner.y + inner.h);
  eg.addColorStop(0, rgba(s.glassTint, 0.95));
  eg.addColorStop(0.5, rgba(s.glassTint, 0.45));
  eg.addColorStop(1, rgba(s.glassTint, 0.75));
  ctx.strokeStyle = eg;
  ctx.lineWidth = E.outer;
  ctx.stroke();
  roundRect(ctx, { x: inner.x - 1, y: inner.y, w: inner.w + 2, h: inner.h + 1 }, GLASS.cornerR + 1);
  ctx.strokeStyle = rgba('#FFFFFF', E.innerAlpha * 0.35);
  ctx.lineWidth = E.inner * 0.75;
  ctx.stroke();
  // läpp
  const L = GLASS.lip;
  const lx = inner.x - 10;
  const lw = inner.w + 20;
  const ly = inner.y - L.h / 2;
  const lg = ctx.createLinearGradient(0, ly, 0, ly + L.h);
  lg.addColorStop(0, rgba('#FFFFFF', 0.75));
  lg.addColorStop(0.35, rgba(s.glassTint, L.alpha + 0.2));
  lg.addColorStop(1, rgba(s.glassTint, L.alpha * 0.4));
  ctx.fillStyle = lg;
  ctx.beginPath();
  ctx.roundRect(lx, ly, lw, L.h, L.h / 2);
  ctx.fill();
  ctx.strokeStyle = E.outerColor;
  ctx.lineWidth = 1.5;
  ctx.stroke();
  ctx.restore();
}

// ------------------------------------------------------------------ delade effekt-sprites (vita, tintas)

/** Den enda glöden: mjuk radial med 5 stopp. `px` = FX_SPRITES.glow.px · dpr. */
export function renderGlow(ctx: Ctx, dpr = 1): void {
  const p = FX_SPRITES.glow.px * dpr;
  const g = ctx.createRadialGradient(p / 2, p / 2, 0, p / 2, p / 2, p / 2);
  for (const [o, a] of FX_SPRITES.glow.stops) g.addColorStop(o, `rgba(255,255,255,${a})`);
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, p, p);
}

/** Chockvåg: ring med mjuk insida och skarpare ytterkant. */
export function renderShock(ctx: Ctx, dpr = 1): void {
  const S = FX_SPRITES.shock;
  const p = S.px * dpr;
  const r = (p / 2) * S.ringFrac;
  const w = (p / 2) * S.width;
  const g = ctx.createRadialGradient(p / 2, p / 2, r - w * 3, p / 2, p / 2, r + w);
  g.addColorStop(0, 'rgba(255,255,255,0)');
  g.addColorStop(0.72, 'rgba(255,255,255,0.35)');
  g.addColorStop(0.9, 'rgba(255,255,255,1)');
  g.addColorStop(1, 'rgba(255,255,255,0)');
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, p, p);
}

/** Fyrudds-gnista med mjuk kärna. */
export function renderSparkle(ctx: Ctx, dpr = 1): void {
  const S = FX_SPRITES.sparkle;
  const p = S.px * dpr;
  const c = p / 2;
  const arm = p * S.armFrac;
  const waist = p * S.waist;
  ctx.save();
  ctx.fillStyle = '#FFFFFF';
  ctx.beginPath();
  ctx.moveTo(c, c - arm);
  ctx.quadraticCurveTo(c + waist * 0.4, c - waist * 0.4, c + arm, c);
  ctx.quadraticCurveTo(c + waist * 0.4, c + waist * 0.4, c, c + arm);
  ctx.quadraticCurveTo(c - waist * 0.4, c + waist * 0.4, c - arm, c);
  ctx.quadraticCurveTo(c - waist * 0.4, c - waist * 0.4, c, c - arm);
  ctx.fill();
  const g = ctx.createRadialGradient(c, c, 0, c, c, p * S.core * 2);
  g.addColorStop(0, 'rgba(255,255,255,1)');
  g.addColorStop(1, 'rgba(255,255,255,0)');
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, p, p);
  ctx.restore();
}

/** Strimma (spår bakom fallande objekt och "fart"-linjer vid kedja). */
export function renderStreak(ctx: Ctx, dpr = 1): void {
  const S = FX_SPRITES.streak;
  const w = S.w * dpr;
  const h = S.h * dpr;
  const g = ctx.createLinearGradient(0, 0, 0, h);
  g.addColorStop(0, 'rgba(255,255,255,0)');
  g.addColorStop(0.7, 'rgba(255,255,255,0.8)');
  g.addColorStop(1, 'rgba(255,255,255,0)');
  ctx.fillStyle = g;
  ctx.beginPath();
  ctx.roundRect(0, 0, w, h, w / 2);
  ctx.fill();
}

/** En ljusstråle (kil) för jackpot-solfjädern och miljöns strålar. Spetsen i (w/2, 0). */
export function renderBeam(ctx: Ctx, dpr = 1): void {
  const B = FX_SPRITES.beam;
  const w = B.w * dpr;
  const h = B.h * dpr;
  const g = ctx.createLinearGradient(0, 0, 0, h);
  g.addColorStop(0, 'rgba(255,255,255,0.9)');
  g.addColorStop(0.5, 'rgba(255,255,255,0.35)');
  g.addColorStop(1, 'rgba(255,255,255,0)');
  ctx.save();
  ctx.fillStyle = g;
  ctx.filter = `blur(${2 * dpr}px)`;
  ctx.beginPath();
  ctx.moveTo(w / 2 - w * 0.04, 0);
  ctx.lineTo(w / 2 + w * 0.04, 0);
  ctx.lineTo(w / 2 + (w / 2) * B.spread * 2.6, h);
  ctx.lineTo(w / 2 - (w / 2) * B.spread * 2.6, h);
  ctx.closePath();
  ctx.fill();
  ctx.restore();
}

// Concept frames (art director). Canvas2D only; reuses the app's pure renderers.
import { renderEnvBase, renderRays, renderMotes, renderCausticTile, renderJarBack, renderJarFront, renderGlow, renderShock, renderSparkle, renderBeam, envSet, rgba } from '../../../../app/src/ui/envArt';
import { ENV, FX_SPRITES } from '../../../../app/src/data/artEnv';
import { renderLevel, levelBakeInfo, renderAvatar, avatarBakeInfo } from '../../../../app/src/ui/artv2';
import { renderButton, buttonBakeInfo } from '../../../../app/src/ui/buttonArt';
import { THEME_SETS, BOOK_ICON } from '../../../../app/src/data/themes';
import { AVATARS } from '../../../../app/src/data/avatars';
import { ICONS } from '../../../../app/src/ui/icons';
import { SHELL_ICON } from '../../../../app/src/data/avatars';
import { PEARL_COIN_ICON, SAND_ICON, CHECK_ICON } from '../../../../app/src/data/economyUi';

const RADII = [14, 19, 25, 31, 38, 46, 55, 64, 74, 85, 97];
const W = 360;
const H = 779; // 390×844 full-bleed in logical px (Scale.EXPAND)
const OY = 69.5; // today's 360×640 play space centred
const D = 780 / 360; // device px per logical px at DPR 2
const FONT = 'Fredoka';
const HUD = '#EAF2FF';
const DIM = '#8FA3C8';
const GOLD = '#FFD75E';

type C2 = CanvasRenderingContext2D;
function canvas(w: number, h: number): HTMLCanvasElement {
  const c = document.createElement('canvas');
  c.width = Math.ceil(w);
  c.height = Math.ceil(h);
  return c;
}
function img(svg: string): Promise<HTMLImageElement> {
  return new Promise((res) => {
    const i = new Image();
    i.onload = () => res(i);
    i.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg);
  });
}
/** White sprite → tinted copy. */
function tint(src: HTMLCanvasElement, color: string): HTMLCanvasElement {
  const c = canvas(src.width, src.height);
  const x = c.getContext('2d')!;
  x.drawImage(src, 0, 0);
  x.globalCompositeOperation = 'source-in';
  x.fillStyle = color;
  x.fillRect(0, 0, c.width, c.height);
  return c;
}
const cache = new Map<string, { c: HTMLCanvasElement; logical: number }>();
function level(setIdx: number, lv: number) {
  const key = `${setIdx}-${lv}`;
  if (!cache.has(key)) {
    const set = THEME_SETS[setIdx];
    const skin = set.levels[lv];
    const info = levelBakeInfo(skin, RADII[lv], D);
    const c = canvas(info.px, info.px);
    renderLevel(c.getContext('2d')!, skin, RADII[lv], { dpr: D, spotStyle: set.spotStyle });
    cache.set(key, { c, logical: info.logical });
  }
  return cache.get(key)!;
}
function drawLevel(x: C2, setIdx: number, lv: number, cx: number, cy: number, s = 1): void {
  const t = level(setIdx, lv);
  const L = t.logical * s;
  x.drawImage(t.c, (cx - L / 2) * D, (cy - L / 2) * D, L * D, L * D);
}
function sprite(fn: (c: C2, d: number) => void, px: number): HTMLCanvasElement {
  const c = canvas(px * D, px * D);
  fn(c.getContext('2d')!, D);
  return c;
}
/** Draw a (device-px) sprite centred at logical (cx, cy) with logical size (w, h). */
function put(x: C2, s: HTMLCanvasElement, cx: number, cy: number, w: number, h = w, alpha = 1, add = true, rot = 0): void {
  x.save();
  x.globalAlpha = alpha;
  if (add) x.globalCompositeOperation = 'lighter';
  x.translate(cx * D, cy * D);
  x.rotate(rot);
  x.drawImage(s, (-w / 2) * D, (-h / 2) * D, w * D, h * D);
  x.restore();
}
function text(x: C2, s: string, cx: number, cy: number, px: number, color: string, weight = 700, align: CanvasTextAlign = 'center', spacing = 0, outline?: string): void {
  x.save();
  x.font = `${weight} ${px * D}px ${FONT}`;
  x.textAlign = align;
  x.textBaseline = 'middle';
  (x as C2 & { letterSpacing: string }).letterSpacing = `${spacing * D}px`;
  if (outline) {
    x.lineJoin = 'round';
    x.lineWidth = px * 0.22 * D;
    x.strokeStyle = outline;
    x.strokeText(s, cx * D, cy * D);
  }
  x.shadowColor = 'rgba(6,10,20,0.9)';
  x.shadowOffsetY = 2 * D;
  x.shadowBlur = 0;
  x.fillStyle = color;
  x.fillText(s, cx * D, cy * D);
  x.restore();
}
function pill(x: C2, cx: number, cy: number, w: number, h: number, fill: string, edge: string, edgeW = 2): void {
  x.save();
  x.beginPath();
  x.roundRect((cx - w / 2) * D, (cy - h / 2) * D, w * D, h * D, (h / 2) * D);
  x.fillStyle = fill;
  x.fill();
  const g = x.createLinearGradient(0, (cy - h / 2) * D, 0, (cy + h / 2) * D);
  g.addColorStop(0, 'rgba(255,255,255,0.10)');
  g.addColorStop(0.5, 'rgba(255,255,255,0)');
  x.fillStyle = g;
  x.fill();
  x.lineWidth = edgeW * D;
  x.strokeStyle = edge;
  x.stroke();
  x.restore();
}

interface Scene {
  set: number;
  balls: Array<[number, number, number]>; // level, x, y (play space coords, 360×640)
}

function settle(balls: Array<[number, number, number]>): Array<[number, number, number]> {
  const b = balls.map(([l, x, y]) => ({ l, x, y, r: RADII[l] }));
  for (let it = 0; it < 900; it++) {
    for (const p of b) p.y += 0.6;
    for (let i = 0; i < b.length; i++) for (let j = i + 1; j < b.length; j++) {
      const p = b[i], q = b[j];
      const dx = q.x - p.x, dy = q.y - p.y;
      const d = Math.hypot(dx, dy) || 0.01;
      const o = p.r + q.r - d;
      if (o > 0) {
        const wx = (dx / d) * o * 0.5, wy = (dy / d) * o * 0.5;
        p.x -= wx; p.y -= wy; q.x += wx; q.y += wy;
      }
    }
    for (const p of b) {
      p.x = Math.max(20 + p.r, Math.min(340 - p.r, p.x));
      p.y = Math.min(600 - p.r, p.y);
    }
  }
  return b.map((p) => [p.l, p.x, p.y]);
}

// ---------------------------------------------------------------- shared world
async function world(x: C2, sc: Scene, t: number, opts: { dim?: boolean } = {}) {
  const setId = THEME_SETS[sc.set].id;
  const s = envSet(setId);
  const env = canvas(W * D, H * D);
  renderEnvBase(env.getContext('2d')!, setId, W, H, D);
  x.drawImage(env, 0, 0);
  renderRays(x, setId, W, H, D, t);
  renderMotes(x, setId, W, H, D, t, ENV.motes.count);

  const inner = { x: 20, y: 24 + OY, w: 320, h: 576 };
  renderJarBack(x, setId, inner, D);
  // caustics: two layers, clipped to jar
  const tile = canvas(ENV.caustic.tile * D, ENV.caustic.tile * D);
  renderCausticTile(tile.getContext('2d')!, D, 5);
  const ct = tint(tile, s.caustic);
  // caustics: two scrolling layers into one offscreen layer, faded with depth (destination-in)
  const cl = canvas(W * D, H * D);
  const cx2 = cl.getContext('2d')!;
  cx2.filter = `blur(${0.8 * D}px)`;
  for (const [k, sc2] of [[0, 1], [1, 1.37]] as const) {
    cx2.globalAlpha = k ? 0.7 : 1;
    const T = ENV.caustic.tile * sc2;
    const ox = (t * ENV.caustic.speed[k]) % T;
    for (let yy = inner.y - T * 0.3 * k; yy < inner.y + inner.h; yy += T) for (let xx = inner.x - T + ox; xx < inner.x + inner.w; xx += T) cx2.drawImage(ct, xx * D, yy * D, T * D, T * D);
  }
  cx2.filter = 'none';
  cx2.globalAlpha = 1;
  cx2.globalCompositeOperation = 'destination-in';
  const m = cx2.createLinearGradient(0, inner.y * D, 0, (inner.y + inner.h) * D);
  m.addColorStop(0, 'rgba(0,0,0,1)');
  m.addColorStop(0.45, 'rgba(0,0,0,0.35)');
  m.addColorStop(0.8, 'rgba(0,0,0,0)');
  cx2.fillStyle = m;
  cx2.fillRect(inner.x * D, inner.y * D, inner.w * D, inner.h * D);
  x.save();
  x.globalCompositeOperation = 'lighter';
  x.globalAlpha = s.causticAlpha * 1.8;
  x.drawImage(cl, 0, 0);
  x.restore();
  // fade caustics toward bottom: darken lower jar a touch
  const fade = x.createLinearGradient(0, (inner.y + inner.h * 0.3) * D, 0, (inner.y + inner.h) * D);
  fade.addColorStop(0, 'rgba(4,8,18,0)');
  fade.addColorStop(1, 'rgba(4,8,18,0.28)');
  x.fillStyle = fade;
  x.fillRect(inner.x * D, inner.y * D, inner.w * D, inner.h * D);

  // contact shadows (one shared dark glow sprite per body)
  const glow = sprite((c, d) => renderGlow(c, d), FX_SPRITES.glow.px);
  const dark = tint(glow, '#02040A');
  for (const [lv, bx, by] of sc.balls) put(x, dark, bx, by + OY + RADII[lv] * 0.38, RADII[lv] * 2.5, RADII[lv] * 1.6, 0.55, false);
  // object glow as shared sprite (ADD), then bodies
  for (const [lv, bx, by] of sc.balls) put(x, tint(glow, THEME_SETS[sc.set].levels[lv].color), bx, by + OY, RADII[lv] * 3, RADII[lv] * 3, 0.22);
  for (const [lv, bx, by] of sc.balls) drawLevel(x, sc.set, lv, bx, by + OY);
  renderJarFront(x, setId, inner, D);
  if (opts.dim) return { glow, inner };
  return { glow, inner };
}

async function hud(x: C2, score: string, next: [number, number], hangLv: number, hangX: number, sc: Scene) {
  // top band: score pill, best chip, next bubble
  pill(x, 72, 30, 120, 44, 'rgba(11,16,32,0.72)', '#4A6194');
  text(x, score, 72, 31, 28, HUD, 700);
  pill(x, 172, 30, 76, 32, 'rgba(255,215,94,0.10)', 'rgba(255,215,94,0.45)');
  const crown = await img(ICONS.crown(GOLD));
  x.drawImage(crown, 142 * D, 20 * D, 20 * D, 20 * D);
  text(x, '2 480', 186, 31, 16, GOLD, 700);
  // next bubble: glass sphere with the next piece
  const bx = 318, by = 30;
  const g = x.createRadialGradient((bx - 8) * D, (by - 10) * D, 2 * D, bx * D, by * D, 24 * D);
  g.addColorStop(0, 'rgba(175,200,255,0.28)');
  g.addColorStop(1, 'rgba(11,16,32,0.75)');
  x.beginPath();
  x.arc(bx * D, by * D, 24 * D, 0, Math.PI * 2);
  x.fillStyle = g;
  x.fill();
  x.lineWidth = 2 * D;
  x.strokeStyle = '#6E8CC4';
  x.stroke();
  drawLevel(x, sc.set, next[0], bx, by, 0.95 * (18 / RADII[next[0]]));
  drawLevel(x, sc.set, next[1], 276, by + 4, 0.8 * (12 / RADII[next[1]]));
  // chain tray (recessed) at y 66
  x.save();
  x.beginPath();
  x.roundRect(16 * D, 56 * D, 206 * D, 22 * D, 11 * D);
  x.fillStyle = 'rgba(4,8,18,0.55)';
  x.fill();
  x.lineWidth = 1.5 * D;
  x.strokeStyle = 'rgba(110,140,196,0.35)';
  x.stroke();
  x.restore();
  for (let k = 0; k < 11; k++) {
    const cx = 27 + k * 18.2;
    if (k <= 6) drawLevel(x, sc.set, k, cx, 67, (5 + 0.35 * k) / RADII[k]);
    else {
      x.beginPath();
      x.arc(cx * D, 67 * D, (5 + 0.35 * k) * D, 0, Math.PI * 2);
      x.fillStyle = '#56688F';
      x.globalAlpha = 0.6;
      x.fill();
      x.globalAlpha = 1;
    }
  }
  // danger line: soft amber, rounded dashes, faint glow band
  const dy = 110 + OY;
  x.save();
  x.globalCompositeOperation = 'lighter';
  const dg = x.createLinearGradient(0, (dy - 6) * D, 0, (dy + 6) * D);
  dg.addColorStop(0, 'rgba(255,180,58,0)');
  dg.addColorStop(0.5, 'rgba(255,180,58,0.10)');
  dg.addColorStop(1, 'rgba(255,180,58,0)');
  x.fillStyle = dg;
  x.fillRect(24 * D, (dy - 6) * D, 312 * D, 12 * D);
  x.restore();
  x.save();
  x.setLineDash([6 * D, 8 * D]);
  x.lineCap = 'round';
  x.lineWidth = 2.5 * D;
  x.strokeStyle = 'rgba(255,180,58,0.55)';
  x.beginPath();
  x.moveTo(30 * D, dy * D);
  x.lineTo(330 * D, dy * D);
  x.stroke();
  x.restore();
  // hanging piece + buddy
  drawLevel(x, sc.set, hangLv, hangX, 64 + OY);
  const def = AVATARS.find((a) => a.id === 'siri') ?? AVATARS[0];
  const info = avatarBakeInfo(40, D);
  const ac = canvas(info.px, info.px);
  renderAvatar(ac.getContext('2d')!, def, 40, { dpr: D });
  const L = info.logical;
  x.drawImage(ac, (hangX - L / 2) * D, (64 + OY - RADII[hangLv] + 4 - L * info.originY) * D, L * D, L * D);
  // aim guide: soft dotted column of light
  x.save();
  x.globalCompositeOperation = 'lighter';
  for (let yy = 64 + OY + RADII[hangLv] + 10; yy < 540; yy += 14) {
    x.beginPath();
    x.arc(hangX * D, yy * D, 1.6 * D, 0, Math.PI * 2);
    x.fillStyle = `rgba(124,249,255,${0.28 * (1 - (yy - 140) / 500)})`;
    x.fill();
  }
  x.restore();
}

const MID: Scene = {
  set: 0,
  balls: settle([
    [8, 96, 526], [7, 236, 536], [4, 302, 562], [6, 70, 408], [5, 170, 454], [3, 250, 452], [2, 300, 470],
    [5, 290, 384], [4, 208, 390], [3, 128, 360], [1, 46, 340], [2, 92, 312], [0, 168, 318], [1, 236, 330], [3, 318, 318],
  ]),
};

// ---------------------------------------------------------------- frames
async function frameGame(x: C2) {
  await world(x, MID, 3.2);
  await hud(x, '1 284', [2, 1], 3, 150, MID);
}

async function frameJackpot(x: C2) {
  const sc: Scene = { set: 0, balls: settle([[3, 52, 568], [4, 300, 562], [2, 110, 575], [1, 250, 580], [0, 150, 590]]) };
  const { glow, inner } = await world(x, sc, 5.1);
  const cx = 180, cy = 400 + OY;
  // 1. focus: darken outside the jackpot a touch (radial)
  const vg = x.createRadialGradient(cx * D, cy * D, 60 * D, cx * D, cy * D, 420 * D);
  vg.addColorStop(0, 'rgba(0,0,0,0)');
  vg.addColorStop(1, 'rgba(0,0,0,0.35)');
  x.fillStyle = vg;
  x.fillRect(0, 0, W * D, H * D);
  // 2. warm light wash (ADD glow, not an alpha overlay)
  put(x, tint(glow, '#FFB84A'), cx, cy, 480, 480, 0.2);
  // 3. beam fan: 12 beams, slow rotation 20°/s
  const beam = tint(sprite((c, d) => renderBeam(c, d), 1), '#FFE08A');
  const bb = canvas(FX_SPRITES.beam.w * D, FX_SPRITES.beam.h * D);
  renderBeam(bb.getContext('2d')!, D);
  const beamT = tint(bb, '#FFE08A');
  void beam;
  x.save();
  x.beginPath();
  x.rect(inner.x * D, inner.y * D, inner.w * D, inner.h * D);
  x.clip();
  for (let i = 0; i < 12; i++) {
    const a = (i / 12) * Math.PI * 2 + 0.18;
    x.save();
    x.globalCompositeOperation = 'lighter';
    x.globalAlpha = i % 2 ? 0.3 : 0.5;
    x.translate(cx * D, cy * D);
    x.rotate(a);
    x.drawImage(beamT, (-FX_SPRITES.beam.w * 0.6) * D, 40 * D, FX_SPRITES.beam.w * 1.2 * D, 280 * D);
    x.restore();
  }
  x.restore();
  // 4. shockwave rings (2, gold then white-gold)
  const shock = sprite((c, d) => renderShock(c, d), FX_SPRITES.shock.px);
  put(x, tint(shock, '#FFD75E'), cx, cy, 330, 330, 0.75);
  put(x, tint(shock, '#FFF1CF'), cx, cy, 250, 250, 0.35);
  // 5. core glow + the new level 10 at punch scale 1.12
  put(x, tint(glow, '#FFE9A8'), cx, cy, 300, 300, 0.4);
  drawLevel(x, 0, 10, cx, cy, 1.12);
  // 6. sparkles (varied size, gold + white)
  const sp = sprite((c, d) => renderSparkle(c, d), FX_SPRITES.sparkle.px);
  const spG = tint(sp, '#FFD75E');
  const pts: Array<[number, number, number, boolean]> = [
    [-130, -90, 26, true], [120, -120, 34, false], [150, 20, 22, true], [-150, 40, 30, false], [60, -170, 18, true], [-70, -175, 20, false],
    [-100, 130, 16, true], [110, 120, 24, false], [0, -205, 28, true], [-160, -30, 14, true], [165, -60, 14, false], [30, 150, 12, true],
  ];
  for (const [dx, dy2, s2, g2] of pts) put(x, g2 ? spG : sp, cx + dx, cy + dy2, s2, s2, 0.95, true, (dx + dy2) * 0.01);
  // tiny ember dots
  const dot = tint(glow, '#FFE08A');
  for (let i = 0; i < 26; i++) {
    const a = i * 2.4;
    const r = 120 + ((i * 37) % 90);
    put(x, dot, cx + Math.cos(a) * r, cy + Math.sin(a) * r * 0.9, 10, 10, 0.8);
  }
  // 7. score pop: big, outlined, gold
  text(x, '+566', cx, cy - 168, 40, '#FFE9A8', 700, 'center', 1, '#6B4300');
  await hud(x, '3 046', [1, 0], 1, 250, sc);
}

async function frameGameOver(x: C2) {
  const sc = MID;
  await world(x, sc, 7.4);
  // dim + cool the world (baked once when the card opens)
  x.fillStyle = 'rgba(6,10,20,0.7)';
  x.fillRect(0, 0, W * D, H * D);
  // card
  const cw = 316, ch = 478, cxm = 180, cym = 366;
  x.save();
  x.shadowColor = 'rgba(0,0,0,0.55)';
  x.shadowBlur = 24 * D;
  x.shadowOffsetY = 10 * D;
  x.beginPath();
  x.roundRect((cxm - cw / 2) * D, (cym - ch / 2) * D, cw * D, ch * D, 28 * D);
  const cg = x.createLinearGradient(0, (cym - ch / 2) * D, 0, (cym + ch / 2) * D);
  cg.addColorStop(0, '#1B2A48');
  cg.addColorStop(1, '#111A30');
  x.fillStyle = cg;
  x.fill();
  x.restore();
  x.save();
  x.beginPath();
  x.roundRect((cxm - cw / 2) * D, (cym - ch / 2) * D, cw * D, ch * D, 28 * D);
  x.lineWidth = 2 * D;
  x.strokeStyle = '#4A6194';
  x.stroke();
  x.beginPath();
  x.roundRect((cxm - cw / 2 + 3) * D, (cym - ch / 2 + 3) * D, (cw - 6) * D, 60 * D, 25 * D);
  const hl = x.createLinearGradient(0, (cym - ch / 2) * D, 0, (cym - ch / 2 + 60) * D);
  hl.addColorStop(0, 'rgba(255,255,255,0.08)');
  hl.addColorStop(1, 'rgba(255,255,255,0)');
  x.fillStyle = hl;
  x.fill();
  x.restore();
  const top = cym - ch / 2;
  // pedestal + best piece of the round (lvl 8) with glow
  const glow = sprite((c, d) => renderGlow(c, d), FX_SPRITES.glow.px);
  put(x, tint(glow, '#6C8BFF'), 180, top + 92, 190, 190, 0.45);
  x.beginPath();
  x.ellipse(180 * D, (top + 142) * D, 58 * D, 11 * D, 0, 0, Math.PI * 2);
  const pg = x.createLinearGradient(0, (top + 131) * D, 0, (top + 153) * D);
  pg.addColorStop(0, '#2B3B5E');
  pg.addColorStop(1, '#16223C');
  x.fillStyle = pg;
  x.fill();
  x.lineWidth = 2 * D;
  x.strokeStyle = '#6E8CC4';
  x.stroke();
  drawLevel(x, 0, 8, 180, top + 96, 0.62);
  // score
  text(x, 'SCORE', 180, top + 176, 14, DIM, 600, 'center', 3);
  text(x, '1 284', 180, top + 214, 58, HUD, 700);
  // best chip
  pill(x, 180, top + 262, 132, 34, 'rgba(255,215,94,0.10)', 'rgba(255,215,94,0.45)');
  const crown = await img(ICONS.crown(GOLD));
  x.drawImage(crown, 128 * D, (top + 251) * D, 22 * D, 22 * D);
  text(x, '2 480', 192, top + 263, 20, GOLD, 700);
  // divider
  x.fillStyle = 'rgba(74,97,148,0.6)';
  x.fillRect((cxm - cw / 2 + 24) * D, (top + 296) * D, (cw - 48) * D, 1.5 * D);
  // reveal row: book + count + bar, pearls chip, shell
  const book = await img(BOOK_ICON('#7CF9FF'));
  x.drawImage(book, 42 * D, (top + 312) * D, 34 * D, 34 * D);
  text(x, '9 / 21', 106, top + 329, 18, HUD, 700);
  x.beginPath();
  x.roundRect(82 * D, (top + 346) * D, 120 * D, 8 * D, 4 * D);
  x.fillStyle = '#2B3B5E';
  x.fill();
  x.beginPath();
  x.roundRect(82 * D, (top + 346) * D, 78 * D, 8 * D, 4 * D);
  const bg = x.createLinearGradient(82 * D, 0, 160 * D, 0);
  bg.addColorStop(0, '#36C9D6');
  bg.addColorStop(1, '#B6FCFF');
  x.fillStyle = bg;
  x.fill();
  pill(x, 250, top + 331, 74, 34, 'rgba(11,16,32,0.6)', '#4A6194');
  const pearl = await img(PEARL_COIN_ICON());
  x.drawImage(pearl, 218 * D, (top + 320) * D, 22 * D, 22 * D);
  text(x, '+12', 262, top + 332, 17, HUD, 700);
  const shell = await img(SHELL_ICON());
  put(x, tint(glow, '#FFB8E6'), 314, top + 330, 64, 64, 0.35);
  x.drawImage(shell, 296 * D, (top + 312) * D, 36 * D, 36 * D);
  // primary button
  const bw = 268, bh = 76;
  const info = buttonBakeInfo('primary', bw, bh, D);
  const bc = canvas(info.pxW, info.pxH);
  renderButton(bc.getContext('2d')!, 'primary', 'normal', bw, bh, D);
  x.drawImage(bc, (180 - bw / 2 - info.pad) * D, (top + 418 - bh / 2 - info.pad) * D, info.pxW * (D / info.dpr), info.pxH * (D / info.dpr));
  const play = await img(ICONS.replay('#0B1020'));
  x.drawImage(play, 84 * D, (top + 404) * D, 28 * D, 28 * D);
  x.save();
  x.shadowColor = 'transparent';
  x.font = `700 ${28 * D}px ${FONT}`;
  x.textAlign = 'center';
  x.textBaseline = 'middle';
  (x as C2 & { letterSpacing: string }).letterSpacing = `${2 * D}px`;
  x.fillStyle = '#0B1020';
  x.fillText('AGAIN', 196 * D, (top + 419) * D);
  x.restore();
  // home + book secondary round buttons under the card
  for (const [bxp, icon, label] of [[132, ICONS.close('#7CF9FF'), 'Home'], [228, BOOK_ICON('#7CF9FF'), 'Book']] as const) {
    const ri = buttonBakeInfo('round', 52, 52, D);
    const rc = canvas(ri.pxW, ri.pxH);
    renderButton(rc.getContext('2d')!, 'round', 'normal', 52, 52, D);
    x.drawImage(rc, (bxp - 26 - ri.pad) * D, (top + ch + 40 - 26 - ri.pad) * D, ri.pxW * (D / ri.dpr), ri.pxH * (D / ri.dpr));
    const ic = await img(icon);
    x.drawImage(ic, (bxp - 14) * D, (top + ch + 26) * D, 28 * D, 28 * D);
    text(x, label, bxp, top + ch + 82, 14, DIM, 600);
  }
  // "new record"-less state; a small confetti of the round's catches rising into the book
  const sp = sprite((c, d) => renderSparkle(c, d), FX_SPRITES.sparkle.px);
  for (const [sx, sy, s] of [[60, 40, 14], [300, 30, 18], [250, 70, 10], [110, 76, 10]] as const) put(x, tint(sp, '#7CF9FF'), sx, top + sy, s, s, 0.8);
}

// ---------------------------------------------------------------- earn tokens + toast (in round)
const TROPHY = (c = '#FFD75E') => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64"><path d="M18 10 H46 V26 C46 36 40 42 32 42 C24 42 18 36 18 26 Z" fill="${c}" stroke="#14202E" stroke-width="5" stroke-linejoin="round"/><path d="M18 16 H9 C9 26 13 30 19 30 M46 16 H55 C55 26 51 30 45 30" fill="none" stroke="#14202E" stroke-width="5"/><path d="M28 42 H36 V50 H28 Z M20 50 H44 V56 H20 Z" fill="${c}" stroke="#14202E" stroke-width="4" stroke-linejoin="round"/><circle cx="26" cy="20" r="3" fill="#fff" fill-opacity=".8"/></svg>`;
const MISSION = (c = '#7CF9FF') => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64"><rect x="12" y="8" width="40" height="50" rx="8" fill="#1B2A48" stroke="${c}" stroke-width="5"/><path d="M21 24 L27 30 L39 18" fill="none" stroke="${c}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/><path d="M21 42 H43" stroke="${c}" stroke-width="5" stroke-linecap="round"/></svg>`;

function card(x: C2, l: number, t: number, w: number, h: number, edge = '#4A6194', r = 18, glowC?: string): void {
  x.save();
  x.shadowColor = 'rgba(0,0,0,0.45)';
  x.shadowBlur = 10 * D;
  x.shadowOffsetY = 4 * D;
  x.beginPath();
  x.roundRect(l * D, t * D, w * D, h * D, r * D);
  const g = x.createLinearGradient(0, t * D, 0, (t + h) * D);
  g.addColorStop(0, '#1B2A48');
  g.addColorStop(1, '#131E36');
  x.fillStyle = g;
  x.fill();
  x.restore();
  x.save();
  x.beginPath();
  x.roundRect(l * D, t * D, w * D, h * D, r * D);
  if (glowC) {
    const gg = x.createRadialGradient((l + w * 0.2) * D, (t + h / 2) * D, 0, (l + w * 0.2) * D, (t + h / 2) * D, w * 0.7 * D);
    gg.addColorStop(0, rgba(glowC, 0.22));
    gg.addColorStop(1, rgba(glowC, 0));
    x.fillStyle = gg;
    x.fill();
  }
  const hl = x.createLinearGradient(0, t * D, 0, (t + 22) * D);
  hl.addColorStop(0, 'rgba(255,255,255,0.07)');
  hl.addColorStop(1, 'rgba(255,255,255,0)');
  x.fillStyle = hl;
  x.fill();
  x.lineWidth = 2 * D;
  x.strokeStyle = edge;
  x.stroke();
  x.restore();
}
async function icon(x: C2, svg: string, cx: number, cy: number, s: number): Promise<void> {
  const i = await img(svg);
  x.drawImage(i, (cx - s / 2) * D, (cy - s / 2) * D, s * D, s * D);
}
function bar(x: C2, l: number, cy: number, w: number, h: number, f0: number, f1: number, c0 = '#36C9D6', c1 = '#B6FCFF'): void {
  x.beginPath();
  x.roundRect(l * D, (cy - h / 2) * D, w * D, h * D, (h / 2) * D);
  x.fillStyle = '#2B3B5E';
  x.fill();
  x.beginPath();
  x.roundRect(l * D, (cy - h / 2) * D, w * f1 * D, h * D, (h / 2) * D);
  x.fillStyle = rgba(c1, 0.45);
  x.fill();
  x.beginPath();
  x.roundRect(l * D, (cy - h / 2) * D, w * f0 * D, h * D, (h / 2) * D);
  const g = x.createLinearGradient(l * D, 0, (l + w) * D, 0);
  g.addColorStop(0, c0);
  g.addColorStop(1, c1);
  x.fillStyle = g;
  x.fill();
}
function star(x: C2, cx: number, cy: number, r: number, fill: string, edge = '#14202E'): void {
  x.beginPath();
  for (let i = 0; i < 10; i++) {
    const a = -Math.PI / 2 + (i * Math.PI) / 5;
    const rr = i % 2 ? r * 0.46 : r;
    x.lineTo((cx + Math.cos(a) * rr) * D, (cy + Math.sin(a) * rr) * D);
  }
  x.closePath();
  x.fillStyle = fill;
  x.fill();
  x.lineJoin = 'round';
  x.lineWidth = 2 * D;
  x.strokeStyle = edge;
  x.stroke();
}
function bez(p0: [number, number], c: [number, number], p1: [number, number], t: number): [number, number] {
  const u = 1 - t;
  return [u * u * p0[0] + 2 * u * t * c[0] + t * t * p1[0], u * u * p0[1] + 2 * u * t * c[1] + t * t * p1[1]];
}

async function frameEarn(x: C2) {
  const sc: Scene = { set: 0, balls: settle([[6, 80, 560], [5, 250, 560], [4, 170, 560], [3, 320, 540], [2, 120, 480], [3, 210, 470], [1, 290, 470], [0, 60, 440]]) };
  const { glow } = await world(x, sc, 2.2);
  await hud(x, '412', [1, 2], 2, 110, sc);
  // resource chips (row 2, right of the chain tray)
  const pearl = await img(PEARL_COIN_ICON());
  const sand = await img(SAND_ICON());
  // pearl chip punching (scale 1.12) with ADD plate glow
  put(x, tint(glow, '#EAF2FF'), 262, 67, 90, 50, 0.3);
  x.save();
  x.translate(262 * D, 67 * D);
  x.scale(1.12, 1.12);
  x.translate(-262 * D, -67 * D);
  pill(x, 262, 67, 62, 24, 'rgba(11,16,32,0.8)', '#EAF2FF', 2);
  x.drawImage(pearl, 236 * D, 58 * D, 18 * D, 18 * D);
  text(x, '14', 272, 68, 15, HUD, 700);
  x.restore();
  pill(x, 318, 67, 44, 24, 'rgba(11,16,32,0.72)', '#4A6194', 2);
  x.drawImage(sand, 299 * D, 58 * D, 18 * D, 18 * D);
  text(x, '3', 327, 68, 15, HUD, 700);
  // merge burst at the merge point + 3 pearl tokens along the arc (stagger 45 ms)
  const mx = 200, my = 548;
  put(x, tint(glow, '#FFD447'), mx, my, 150, 150, 0.35);
  const sp = sprite((c, d) => renderSparkle(c, d), FX_SPRITES.sparkle.px);
  for (const [dx, dy, s2] of [[-40, -30, 16], [38, -34, 12], [46, 20, 10], [-30, 34, 9]] as const) put(x, tint(sp, '#FFE9A8'), mx + dx, my + dy, s2, s2, 0.9);
  const p0: [number, number] = [mx, my - 20];
  const p1: [number, number] = [240, 67];
  const cp: [number, number] = [mx + 120, my - 300];
  const tokenGlow = tint(glow, '#EAF2FF');
  for (const tt of [0.28, 0.5, 0.72]) {
    for (const [lag, a] of [[0.09, 0.14], [0.06, 0.24], [0.03, 0.4]] as const) {
      const [gx, gy] = bez(p0, cp, p1, Math.max(0, tt - lag));
      put(x, tokenGlow, gx, gy, 16, 16, a);
    }
    const [tx, ty] = bez(p0, cp, p1, tt);
    put(x, tokenGlow, tx, ty, 40, 40, 0.35);
    const s2 = 20 - tt * 6;
    x.drawImage(pearl, (tx - s2 / 2) * D, (ty - s2 / 2) * D, s2 * D, s2 * D);
  }
  // a token just popped (t = 0.1 s, scale 1.15) at the merge point
  put(x, tokenGlow, mx - 6, my - 26, 40, 40, 0.4);
  x.drawImage(pearl, (mx - 6 - 11.5) * D, (my - 26 - 11.5) * D, 23 * D, 23 * D);
  // mission toast in the bottom band below the jar floor (RETENTION §10.1), composite: t ≈ 1.2 s later
  const ty0 = 600 + OY + 36;
  card(x, 180 - 116, ty0 - 16, 232, 32, '#7CF9FF', 16, '#7CF9FF');
  await icon(x, MISSION(), 180 - 96, ty0, 22);
  text(x, 'Chain of 4!', 150, ty0 + 1, 14, HUD, 600);
  await icon(x, '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64"><rect x="10" y="26" width="44" height="30" rx="5" fill="#FF9CE0" stroke="#14202E" stroke-width="5"/><rect x="6" y="16" width="52" height="12" rx="4" fill="#FFD1F2" stroke="#14202E" stroke-width="5"/><path d="M32 16 V56" stroke="#14202E" stroke-width="5"/><path d="M32 16 C22 4 14 10 22 16 M32 16 C42 4 50 10 42 16" fill="none" stroke="#14202E" stroke-width="4"/></svg>', 180 + 92, ty0, 22);
}

// ---------------------------------------------------------------- end-of-round summary (RETENTION §10.2 zones)
async function frameSummary(x: C2) {
  const setId = THEME_SETS[0].id;
  const env = canvas(W * D, H * D);
  renderEnvBase(env.getContext('2d')!, setId, W, H, D);
  x.drawImage(env, 0, 0);
  renderRays(x, setId, W, H, D, 6);
  renderMotes(x, setId, W, H, D, 6, ENV.motes.count);
  x.fillStyle = 'rgba(6,10,20,0.45)';
  x.fillRect(0, 0, W * D, H * D);
  const Y = OY; // zones are in 360×640; centred in the full-bleed screen
  const glow = sprite((c, d) => renderGlow(c, d), FX_SPRITES.glow.px);
  const sp = sprite((c, d) => renderSparkle(c, d), FX_SPRITES.sparkle.px);
  // R0 result (y 24–150)
  put(x, tint(glow, '#C77DFF'), 56, Y + 84, 110, 110, 0.4);
  drawLevel(x, 0, 7, 56, Y + 84, 0.48);
  text(x, 'SCORE', 200, Y + 36, 13, DIM, 600, 'center', 3);
  text(x, '2 916', 200, Y + 78, 54, HUD, 700);
  put(x, tint(glow, '#FFD75E'), 200, Y + 126, 200, 56, 0.3);
  pill(x, 200, Y + 126, 184, 34, 'rgba(255,215,94,0.16)', '#FFD75E', 2);
  const crown = await img(ICONS.crown(GOLD));
  x.drawImage(crown, 120 * D, (Y + 115) * D, 22 * D, 22 * D);
  text(x, 'New record!', 210, Y + 127, 17, GOLD, 700);
  for (const [sx, sy, s2] of [[112, 104, 12], [296, 110, 14], [302, 142, 9]] as const) put(x, tint(sp, '#FFD75E'), sx, Y + sy, s2, s2, 0.9);
  // rows (y 160 + i·44, h 40): a shelf of glass plates
  const rowY = (i: number) => Y + 160 + i * 44 + 20;
  const plate = (i: number, edge = '#4A6194', glowC?: string) => card(x, 16, rowY(i) - 20, 328, 40, edge, 14, glowC);
  // R1 pearls + sand (counting up)
  plate(0);
  await icon(x, PEARL_COIN_ICON(), 42, rowY(0), 24);
  text(x, '+48', 60, rowY(0) + 1, 20, HUD, 700, 'left');
  await icon(x, SAND_ICON(), 132, rowY(0), 24);
  text(x, '+4', 150, rowY(0) + 1, 20, HUD, 700, 'left');
  put(x, tint(glow, '#EAF2FF'), 42, rowY(0), 44, 44, 0.3);
  // R2 Glimmers + set bar
  plate(1);
  await icon(x, BOOK_ICON('#7CF9FF'), 40, rowY(1), 24);
  const caught = [3, 4, 5, 6, 7];
  for (let i = 0; i < caught.length; i++) {
    const cx2 = 70 + i * 26;
    drawLevel(x, 0, caught[i], cx2, rowY(1), 11 / RADII[caught[i]]);
    if (i === 2) {
      x.beginPath();
      x.arc(cx2 * D, rowY(1) * D, 14 * D, 0, Math.PI * 2);
      x.setLineDash([3 * D, 3 * D]);
      x.lineWidth = 1.8 * D;
      x.strokeStyle = GOLD;
      x.stroke();
      x.setLineDash([]);
      put(x, tint(sp, '#FFD75E'), cx2 + 11, rowY(1) - 11, 9, 9, 1);
    }
  }
  text(x, '11/21', 216, rowY(1) + 1, 15, HUD, 700);
  bar(x, 250, rowY(1), 82, 8, 0.69, 0.77);
  // R3 buddies: free shell gift
  plate(2, '#FF9CE0', '#FF9CE0');
  put(x, tint(glow, '#FFB8E6'), 42, rowY(2), 50, 50, 0.35);
  await icon(x, SHELL_ICON(), 42, rowY(2), 28);
  text(x, 'Gift!', 64, rowY(2) + 1, 17, '#FFD1F2', 700, 'left');
  text(x, 'Open it on Start', 332, rowY(2) + 1, 13, DIM, 500, 'right');
  // R4 Journey + level up (hero row, gold)
  plate(3, '#FFD75E', '#FFD75E');
  x.beginPath();
  x.arc(40 * D, rowY(3) * D, 15 * D, 0, Math.PI * 2);
  const bg2 = x.createRadialGradient(36 * D, (rowY(3) - 5) * D, 1 * D, 40 * D, rowY(3) * D, 15 * D);
  bg2.addColorStop(0, '#FFF1CF');
  bg2.addColorStop(1, '#FFB43A');
  x.fillStyle = bg2;
  x.fill();
  x.lineWidth = 2 * D;
  x.strokeStyle = '#6B4300';
  x.stroke();
  text(x, '13', 40, rowY(3) + 1, 15, '#3A2200', 700);
  put(x, tint(sp, '#FFE9A8'), 54, rowY(3) - 13, 12, 12, 1);
  bar(x, 66, rowY(3), 170, 10, 0.18, 0.18, '#FFB43A', '#FFE9A8');
  text(x, 'Level up!', 244, rowY(3) + 1, 14, GOLD, 700, 'left');
  await icon(x, PEARL_COIN_ICON(), 322, rowY(3), 20);
  // R5 missions
  plate(4, '#7CF9FF');
  await icon(x, MISSION(), 40, rowY(4), 22);
  text(x, 'Chain of 4!', 60, rowY(4) + 1, 15, HUD, 600, 'left');
  pill(x, 230, rowY(4), 58, 24, 'rgba(11,16,32,0.7)', '#4A6194', 1.5);
  await icon(x, PEARL_COIN_ICON(), 214, rowY(4), 14);
  text(x, '+20', 238, rowY(4) + 1, 13, HUD, 700);
  pill(x, 306, rowY(4), 48, 24, 'rgba(11,16,32,0.7)', '#4A6194', 1.5);
  text(x, '2/3', 306, rowY(4) + 1, 13, DIM, 700);
  // R6 trophies + mastery
  plate(5, '#FFD75E');
  put(x, tint(glow, '#FFD75E'), 40, rowY(5), 40, 40, 0.35);
  await icon(x, TROPHY(), 40, rowY(5), 24);
  text(x, 'Chain 5', 60, rowY(5) + 1, 15, HUD, 600, 'left');
  await icon(x, THEME_SETS[0].icon, 262, rowY(5), 20);
  star(x, 288, rowY(5), 8, '#FFD75E');
  star(x, 308, rowY(5), 8, '#FFD75E');
  star(x, 328, rowY(5), 8, 'rgba(143,163,200,0.25)', '#8FA3C8');
  // buttons y 552–616: Home 96×64 + Replay 216×64
  const by2 = Y + 584;
  const ri = buttonBakeInfo('card', 96, 64, D);
  const rc = canvas(ri.pxW, ri.pxH);
  renderButton(rc.getContext('2d')!, 'card', 'normal', 96, 64, D);
  x.drawImage(rc, (16 + 48 - 48 - ri.pad) * D, (by2 - 32 - ri.pad) * D, ri.pxW * (D / ri.dpr), ri.pxH * (D / ri.dpr));
  await icon(x, ICONS.close('#7CF9FF'), 64, by2 - 9, 22);
  text(x, 'Home', 64, by2 + 16, 14, HUD, 600);
  const bw = 216, bh = 64;
  const info = buttonBakeInfo('primary', bw, bh, D);
  const bc = canvas(info.pxW, info.pxH);
  renderButton(bc.getContext('2d')!, 'primary', 'normal', bw, bh, D);
  x.drawImage(bc, (236 - bw / 2 - info.pad) * D, (by2 - bh / 2 - info.pad) * D, info.pxW * (D / info.dpr), info.pxH * (D / info.dpr));
  await icon(x, ICONS.replay('#0B1020'), 168, by2, 24);
  x.save();
  x.font = `700 ${24 * D}px ${FONT}`;
  x.textAlign = 'center';
  x.textBaseline = 'middle';
  (x as C2 & { letterSpacing: string }).letterSpacing = `${2 * D}px`;
  x.fillStyle = '#0B1020';
  x.fillText('AGAIN', 248 * D, (by2 + 1) * D);
  x.restore();
}

async function main() {
  const f = new FontFace('Fredoka', `url(${(window as unknown as { FONT_URL: string }).FONT_URL})`, { weight: '300 700' });
  await f.load();
  document.fonts.add(f);
  const out: Record<string, string> = {};
  for (const [name, fn] of [['game', frameGame], ['jackpot', frameJackpot], ['gameover', frameGameOver], ['earn', frameEarn], ['summary', frameSummary]] as const) {
    const c = canvas(780, 1688);
    const x = c.getContext('2d')!;
    const t0 = performance.now();
    await fn(x);
    console.log(name, Math.round(performance.now() - t0), 'ms');
    out[name] = c.toDataURL('image/png');
  }
  // bake timings for the budget (single calls)
  const tm: Record<string, number> = {};
  const tc = canvas(256 * D, 256 * D);
  let t = performance.now();
  renderCausticTile(tc.getContext('2d')!, D, 5);
  tm.caustic = performance.now() - t;
  const ec = canvas(W * D, H * D);
  t = performance.now();
  renderEnvBase(ec.getContext('2d')!, 'glimtarna', W, H, D);
  tm.env = performance.now() - t;
  const jc = canvas(W * D, H * D);
  t = performance.now();
  renderJarFront(jc.getContext('2d')!, 'glimtarna', { x: 20, y: 93.5, w: 320, h: 576 }, D);
  renderJarBack(jc.getContext('2d')!, 'glimtarna', { x: 20, y: 93.5, w: 320, h: 576 }, D);
  tm.jar = performance.now() - t;
  t = performance.now();
  for (const k of [renderGlow, renderShock, renderSparkle, renderBeam]) k(canvas(256 * D, 256 * D).getContext('2d')!, D);
  tm.sprites = performance.now() - t;
  (window as unknown as { RESULT: unknown }).RESULT = { out, tm };
  void rgba;
}
main().catch((e) => {
  console.error(e);
  (window as unknown as { RESULT: unknown }).RESULT = { error: String(e) };
});

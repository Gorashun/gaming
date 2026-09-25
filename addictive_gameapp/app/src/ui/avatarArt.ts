import Phaser from 'phaser';
import { hexToInt } from '../data/theme';
import {
  AVATAR_BOX,
  AVATAR_GRIP,
  AVATAR_PARTICLE_GEOM,
  AVATAR_UI,
  RARITY,
  avatarById,
  type AvatarOp,
  type AvatarParticle,
  type Rarity,
} from '../data/avatarsIndex';
import { mulberry32 } from '../systems/rng';
import { particleTextureKey } from './textures';

/**
 * Generisk ritare för kompisarnas `draw`-primitiver (UI.md §13.1). Samma språk som
 * SET_DECO_GEOM/backdrop. Bakar EN textur per figur och storlek vid behov (cache i TextureManager).
 */

const EDGE_W = 2.8;
/** Pad i box-enheter runt 56-boxen, så att konturen inte klipps. */
const PAD = 2;
const FULL = AVATAR_BOX + PAD * 2;
/** Origin y i den paddade texturen: greppunkten (0, 24) i boxen. */
export const AVATAR_TEX_ORIGIN_Y = (PAD + AVATAR_BOX / 2 + AVATAR_GRIP[1]) / FULL;

type P2 = readonly [number, number];

interface Pen {
  g: Phaser.GameObjects.Graphics;
  s: number;
  ox: number;
  oy: number;
  sil: boolean;
}

const px = (p: Pen, v: number): number => p.ox + v * p.s;
const py = (p: Pen, v: number): number => p.oy + v * p.s;
const col = (p: Pen, c: string): number => (p.sil ? 0xffffff : hexToInt(c));
const alp = (p: Pen, a: number | undefined): number => (p.sil ? 1 : a ?? 1);

function ellipsePts(p: Pen, x: number, y: number, w: number, h: number, rot: number): Phaser.Types.Math.Vector2Like[] {
  const out: Phaser.Types.Math.Vector2Like[] = [];
  const c = Math.cos(rot);
  const sn = Math.sin(rot);
  for (let i = 0; i < 24; i++) {
    const a = (i / 24) * Math.PI * 2;
    const ex = (Math.cos(a) * w) / 2;
    const ey = (Math.sin(a) * h) / 2;
    out.push({ x: px(p, x + ex * c - ey * sn), y: py(p, y + ex * sn + ey * c) });
  }
  return out;
}

/** Streck med runda ändar (och runda hörn i polylinjer). */
function roundStroke(p: Pen, pts: Phaser.Types.Math.Vector2Like[], width: number, color: number, alpha: number, closed = false): void {
  const w = width * p.s;
  p.g.lineStyle(w, color, alpha);
  p.g.strokePoints(pts, closed, closed);
  p.g.fillStyle(color, alpha);
  const joints = pts.length <= 12 ? pts : [pts[0], pts[pts.length - 1]];
  for (const q of joints) p.g.fillCircle(q.x!, q.y!, w / 2);
}

function toPts(p: Pen, pts: readonly P2[]): Phaser.Types.Math.Vector2Like[] {
  return pts.map(([x, y]) => ({ x: px(p, x), y: py(p, y) }));
}

function quadPts(p: Pen, a: P2, c: P2, b: P2): Phaser.Types.Math.Vector2Like[] {
  const out: Phaser.Types.Math.Vector2Like[] = [];
  for (let i = 0; i <= 16; i++) {
    const t = i / 16;
    const u = 1 - t;
    out.push({ x: px(p, u * u * a[0] + 2 * u * t * c[0] + t * t * b[0]), y: py(p, u * u * a[1] + 2 * u * t * c[1] + t * t * b[1]) });
  }
  return out;
}

function drawOp(p: Pen, op: AvatarOp): void {
  if (p.sil && op.noSil) return;
  const g = p.g;
  switch (op.op) {
    case 'circle':
    case 'ellipse': {
      const pts =
        op.op === 'circle' ? ellipsePts(p, op.x, op.y, op.r * 2, op.r * 2, 0) : ellipsePts(p, op.x, op.y, op.w, op.h, op.rot ?? 0);
      if (op.stroke) {
        g.lineStyle(op.stroke * p.s, col(p, op.color), alp(p, op.alpha));
        g.strokePoints(pts, true, true);
        return;
      }
      g.fillStyle(col(p, op.color), alp(p, op.alpha));
      g.fillPoints(pts, true, true);
      if (op.edge) {
        g.lineStyle((op.edgeW ?? EDGE_W) * p.s, col(p, op.edge), alp(p, op.alpha));
        g.strokePoints(pts, true, true);
      }
      return;
    }
    case 'poly': {
      const pts = toPts(p, op.pts);
      if (op.stroke) {
        roundStroke(p, pts, op.stroke, col(p, op.color), alp(p, op.alpha), !op.open);
        return;
      }
      g.fillStyle(col(p, op.color), alp(p, op.alpha));
      g.fillPoints(pts, true, true);
      if (op.edge) roundStroke(p, pts, op.edgeW ?? EDGE_W, col(p, op.edge), alp(p, op.alpha), true);
      return;
    }
    case 'curve':
    case 'line': {
      const pts = op.op === 'curve' ? quadPts(p, op.from, op.ctrl, op.to) : toPts(p, [op.from, op.to]);
      if (op.edge) roundStroke(p, pts, op.width + 2 * (op.edgeW ?? EDGE_W), col(p, op.edge), alp(p, op.alpha));
      roundStroke(p, pts, op.width, col(p, op.color), alp(p, op.alpha));
      return;
    }
    case 'scatter': {
      const rng = mulberry32(op.seed);
      for (let i = 0; i < op.count; i++) {
        const x = op.x + rng.next() * op.w;
        const y = op.y + rng.next() * op.h;
        const r = op.rMin + rng.next() * (op.rMax - op.rMin);
        const a = op.alphaMin + rng.next() * (op.alphaMax - op.alphaMin);
        g.fillStyle(col(p, op.color), p.sil ? 1 : a);
        g.fillCircle(px(p, x), py(p, y), r * p.s);
      }
      return;
    }
  }
}

/** Ritar primitiverna med boxens origo i (ox, oy), skala s px per box-enhet. */
export function drawAvatarOps(g: Phaser.GameObjects.Graphics, ops: readonly AvatarOp[], s: number, ox: number, oy: number, sil = false): void {
  const pen: Pen = { g, s, ox, oy, sil };
  for (const op of ops) drawOp(pen, op);
}

/** 'full' = figur + ev. pupiller i vila; 'body' = utan pupillagret; 'pupils' = bara pupillerna (Fenjas `look`). */
export type AvatarPart = 'full' | 'body' | 'pupils';

export function avatarTextureKey(id: string, displayPx: number, sil = false, part: AvatarPart = 'full', rombs = 0): string {
  return `av-${id}-${displayPx}${sil ? '-sil' : ''}${part === 'full' ? '' : `-${part}`}${rombs ? `-r${rombs}` : ''}`;
}

/**
 * Bakar figuren i `displayPx` (boxens bredd på skärmen). Siluett: vit, alpha 1, utan `noSil`-lager.
 * Idempotent (cache i TextureManager). Returnerar texturnyckeln.
 */
export function bakeAvatar(scene: Phaser.Scene, id: string, displayPx: number, sil = false, part: AvatarPart = 'full', rombs = 0): string {
  const key = avatarTextureKey(id, displayPx, sil, part, rombs);
  if (scene.textures.exists(key)) return key;
  const def = avatarById(id);
  const s = displayPx / AVATAR_BOX;
  const size = Math.ceil(FULL * s);
  const g = scene.make.graphics({ x: 0, y: 0 }, false);
  const c = size / 2;
  if (def) {
    const pupils = def.cosmetic.look?.pupils ?? [];
    if (part !== 'pupils') drawAvatarOps(g, def.draw, s, c, c, sil);
    if (part !== 'body') drawAvatarOps(g, pupils, s, c, c, sil);
    // Uppgraderingsrombar på högra axeln (UI.md §13.5): II = 1, III = 2.
    const R = AVATAR_UI.slapparen.romb;
    for (let i = 0; i < rombs; i++) {
      drawRomb(g, c + R.x * s, c + (R.y + i * R.stepY) * s, R.w * s, R.h * s, true, 0, hexToInt(R.fill), 0, hexToInt(R.edge));
    }
  }
  g.generateTexture(key, size, size);
  g.destroy();
  return key;
}

/** En figurbild med origin i greppunkten. */
export function addAvatarImage(scene: Phaser.Scene, x: number, y: number, id: string, displayPx: number, sil = false): Phaser.GameObjects.Image {
  return scene.add.image(x, y, bakeAvatar(scene, id, displayPx, sil)).setOrigin(0.5, AVATAR_TEX_ORIGIN_Y);
}

/** Boxens överkant ligger så här många px ovanför greppunkten. */
export function gripToTop(displayPx: number): number {
  return ((AVATAR_BOX / 2 + AVATAR_GRIP[1]) * displayPx) / AVATAR_BOX;
}

/** Figurens centrum ligger så här många px ovanför greppunkten. */
export function gripToCenter(displayPx: number): number {
  return (AVATAR_GRIP[1] * displayPx) / AVATAR_BOX;
}

// ---------------------------------------------------------------- partiklar, pärlor, romber

type NewShape = keyof typeof AVATAR_PARTICLE_GEOM;

/** Texturnyckel för alla kompispartiklar (gamla former via textures.ts, nya ur AVATAR_PARTICLE_GEOM). */
export function avatarParticleKey(shape: AvatarParticle): string {
  return shape in AVATAR_PARTICLE_GEOM ? `fx-p-${shape}` : particleTextureKey(shape as Parameters<typeof particleTextureKey>[0]);
}

/** Bakar de nya partikelformerna (vita 16×16). Idempotent. */
export function bakeAvatarParticles(scene: Phaser.Scene): void {
  for (const shape of Object.keys(AVATAR_PARTICLE_GEOM) as NewShape[]) {
    const key = `fx-p-${shape}`;
    if (scene.textures.exists(key)) continue;
    const g = scene.make.graphics({ x: 0, y: 0 }, false);
    g.fillStyle(0xffffff, 1);
    for (const poly of AVATAR_PARTICLE_GEOM[shape]) g.fillPoints(poly.map(([x, y]) => ({ x, y })), true, true);
    g.generateTexture(key, 16, 16);
    g.destroy();
  }
}

/** Raritetsfärg som tal; mytisk: färg i regnbågen efter index. */
export function rarityInt(r: Rarity, i = 0): number {
  return hexToInt(r === 'mythic' ? RARITY.rainbow[i % RARITY.rainbow.length] : RARITY.color[r]);
}

/** En pärla (fylld, ink-kant, högdager). Mytisk i sex ränder. */
export function drawPearl(g: Phaser.GameObjects.Graphics, x: number, y: number, r: number, rarity: Rarity): void {
  const ink = hexToInt(RARITY.edge);
  if (rarity === 'mythic') {
    const n = RARITY.rainbow.length;
    for (let i = 0; i < n; i++) {
      g.fillStyle(rarityInt('mythic', i), 1);
      g.slice(x, y, r, (i / n) * Math.PI * 2, ((i + 1) / n) * Math.PI * 2, false);
      g.fillPath();
    }
  } else {
    g.fillStyle(rarityInt(rarity), 1);
    g.fillCircle(x, y, r);
  }
  g.lineStyle(Math.max(1, r * 0.3), ink, 1);
  g.strokeCircle(x, y, r);
  g.fillStyle(0xffffff, 0.7);
  g.fillCircle(x - r * 0.3, y - r * 0.35, r * 0.3);
}

/** Rad med `n` pärlor centrerad på x. */
export function drawPearlRow(g: Phaser.GameObjects.Graphics, x: number, y: number, n: number, r: number, pitch: number, rarity: Rarity): void {
  const x0 = x - ((n - 1) * pitch) / 2;
  for (let i = 0; i < n; i++) drawPearl(g, x0 + i * pitch, y, r, rarity);
}

/**
 * Uppgraderingsromb (UI.md §13.4/13.5). filled = uppnådd nivå (hud-vit, ink-kant, vit reflex);
 * annars kontur i `outline` som fylls nedifrån till `fillPct`.
 */
export function drawRomb(
  g: Phaser.GameObjects.Graphics,
  x: number,
  y: number,
  w: number,
  h: number,
  filled: boolean,
  fillPct = 0,
  fill = 0xeaf2ff,
  outline = 0x8fa3c8,
  edge = hexToInt(RARITY.edge),
): void {
  const pts = [
    { x, y: y - h / 2 },
    { x: x + w / 2, y },
    { x, y: y + h / 2 },
    { x: x - w / 2, y },
  ];
  if (filled) {
    g.fillStyle(fill, 1);
    g.fillPoints(pts, true);
    g.lineStyle(Math.max(1, w * 0.2), edge, 1);
    g.strokePoints(pts, true, true);
    g.lineStyle(Math.max(1, w * 0.12), 0xffffff, 0.8);
    g.lineBetween(x - w * 0.16, y - h * 0.06, x, y - h * 0.28);
    return;
  }
  if (fillPct > 0) {
    // Fylls nedifrån: klipp romben vid höjden y1.
    const y1 = y + h / 2 - h * Math.min(1, fillPct);
    const half = (yy: number): number => (w / 2) * (1 - Math.abs(yy - y) / (h / 2));
    const poly: { x: number; y: number }[] = [{ x, y: y + h / 2 }];
    if (y1 < y) {
      poly.push({ x: x + w / 2, y }, { x: x + half(y1), y: y1 }, { x: x - half(y1), y: y1 }, { x: x - w / 2, y });
    } else {
      poly.push({ x: x + half(y1), y: y1 }, { x: x - half(y1), y: y1 });
    }
    g.fillStyle(outline, 0.6);
    g.fillPoints(poly, true);
  }
  g.lineStyle(Math.max(1, w * 0.18), outline, 1);
  g.strokePoints(pts, true, true);
}

/** Ram i raritetsfärg; mytisk som sex regnbågssegment (UI.md §13.2). */
export function strokeRarityRoundRect(
  g: Phaser.GameObjects.Graphics,
  x: number,
  y: number,
  w: number,
  h: number,
  r: number,
  lw: number,
  rarity: Rarity,
): void {
  if (rarity !== 'mythic') {
    g.lineStyle(lw, rarityInt(rarity), 1);
    g.strokeRoundedRect(x, y, w, h, r);
    return;
  }
  // Sex segment runt omkretsen, medurs från övre vänstra hörnet.
  const side = [
    [x, y, x + w, y],
    [x + w, y, x + w, y + h],
    [x + w, y + h, x, y + h],
    [x, y + h, x, y],
  ];
  const n = RARITY.rainbow.length;
  const per = 4 / n;
  for (let i = 0; i < n; i++) {
    g.lineStyle(lw, rarityInt('mythic', i), 1);
    const a = i * per;
    const b = a + per;
    for (let s = Math.floor(a); s < Math.ceil(b); s++) {
      const [x0, y0, x1, y1] = side[s];
      const t0 = Math.max(0, a - s);
      const t1 = Math.min(1, b - s);
      g.lineBetween(x0 + (x1 - x0) * t0, y0 + (y1 - y0) * t0, x0 + (x1 - x0) * t1, y0 + (y1 - y0) * t1);
    }
  }
}

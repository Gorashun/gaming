import Phaser from 'phaser';
import { LEVELS } from '../data/levels';
import { THEME, hexToInt, type Deco, type Face } from '../data/theme';
import { DEFAULT_SET } from '../data/collection';
import {
  SET_DECO_GEOM,
  themeSetById,
  type DecoGeom,
  type NewDeco,
  type ParticleShape,
  type SetDeco,
  type SetLevelSkin,
  type SpotStyle,
} from '../data/themes';

/**
 * Bakar en textur per nivå (och per specialobjekt) EN gång vid boot,
 * enligt ritreceptet i docs/UI.md §3.1. Aldrig Graphics per body i update().
 */

interface Pt {
  x: number;
  y: number;
}

/** Hur långt utanför kroppsradien varje dekor sticker ut, i andel av r. */
const DECO_EXTENT: Record<Deco, number> = {
  none: 1,
  antenna: 1.45,
  tuft: 1.4,
  tentacles: 1.4,
  fins: 1.4,
  crown: 1.36,
  spikes: 1.4,
  bands: 1,
};

function decoExtent(d: SetDeco): number {
  return d in SET_DECO_GEOM ? SET_DECO_GEOM[d as NewDeco].extent : DECO_EXTENT[d as Deco];
}

/** Setet vars texturer används av `ballTextureKey(level)` utan set-argument. */
let currentSet = DEFAULT_SET;

export function activeTextureSet(): string {
  return currentSet;
}

/** Texturnyckeln har setet som prefix: `ball-{setId}-{level}` (UI.md §12.4). */
export function ballTextureKey(level: number, setId: string = currentSet): string {
  return `ball-${setId}-${level}`;
}

/** Skala så att objektets KROPP får radien `wanted` på skärmen. */
export function scaleForBodyRadius(level: number, wanted: number): number {
  return wanted / LEVELS[level].radius;
}

export const FX_DOT = 'fx-dot';
export const FX_RING = 'fx-ring';
/** Ringens radie i texturen (128×128, strokeCircle r=58). Scale = önskad radie / detta. */
export const FX_RING_R = 58;
/** Glitterring runt skimrande objekt (DESIGN §13.2). Ringradie i texturen: FX_GLITTER_R. */
export const FX_GLITTER = 'fx-glitter';
export const FX_GLITTER_R = 52;
export const SPECIAL_BOMB = 'special-bomb';

/** Siluett av nivån (kropp + dekor) i VITT, tintas vid användning. Samma pad som bolltexturen. */
export function silhouetteTextureKey(level: number, setId: string = currentSet): string {
  return `sil-${setId}-${level}`;
}

/** Vita 16×16-partiklar som tintas (UI.md §12.1.3). */
export function particleTextureKey(shape: ParticleShape): string {
  return shape === 'dot' ? FX_DOT : `fx-p-${shape}`;
}
export const SPECIAL_RAINBOW = 'special-rainbow';

// ---------------------------------------------------------------- geometri

function quad(p0: Pt, p1: Pt, p2: Pt, n: number): Pt[] {
  const out: Pt[] = [];
  for (let i = 0; i <= n; i++) {
    const t = i / n;
    const u = 1 - t;
    out.push({
      x: u * u * p0.x + 2 * u * t * p1.x + t * t * p2.x,
      y: u * u * p0.y + 2 * u * t * p1.y + t * t * p2.y,
    });
  }
  return out;
}

function shift(pts: Pt[], cx: number, cy: number): Pt[] {
  for (const p of pts) {
    p.x += cx;
    p.y += cy;
  }
  return pts;
}

/** Polylinjer för strokad dekor, i px relativt kroppens centrum. */
function decoStrokes(deco: Deco, r: number): Pt[][] {
  switch (deco) {
    case 'antenna':
      return [
        quad({ x: 0, y: -0.95 * r }, { x: 0.1 * r, y: -1.34 * r }, { x: 0.24 * r, y: -1.4 * r }, 14),
      ];
    case 'tuft':
      return [-0.34, 0, 0.34].map((a) => [
        { x: Math.sin(a) * 0.55 * r, y: -Math.cos(a) * 0.9 * r },
        { x: Math.sin(2.2 * a) * 0.8 * r, y: -Math.cos(a) * 1.34 * r },
      ]);
    case 'tentacles':
      return [-0.46, 0, 0.46].map((dx) =>
        quad(
          { x: dx * r, y: 0.8 * r },
          { x: 1.25 * dx * r, y: 1.2 * r },
          { x: 0.75 * dx * r, y: 1.34 * r },
          12,
        ),
      );
    default:
      return [];
  }
}

/** Fyllda trianglar för dekor, i px relativt kroppens centrum. */
function decoTriangles(deco: Deco, r: number): Pt[][] {
  if (deco === 'fins') {
    return [-1, 1].map((s) => [
      { x: s * 0.8 * r, y: -0.34 * r },
      { x: s * 1.34 * r, y: 0.02 * r },
      { x: s * 0.8 * r, y: 0.38 * r },
    ]);
  }
  if (deco === 'crown') {
    return [-0.4, 0, 0.4].map((a) => {
      const ux = Math.sin(a);
      const uy = -Math.cos(a);
      const tx = Math.cos(a);
      const ty = Math.sin(a);
      return [
        { x: (ux * 0.94 - tx * 0.17) * r, y: (uy * 0.94 - ty * 0.17) * r },
        { x: ux * 1.3 * r, y: uy * 1.3 * r },
        { x: (ux * 0.94 + tx * 0.17) * r, y: (uy * 0.94 + ty * 0.17) * r },
      ];
    });
  }
  if (deco === 'spikes') {
    const n = THEME.special.bomb.spikes;
    const len = 1 + THEME.special.bomb.spikeLen;
    const out: Pt[][] = [];
    for (let i = 0; i < n; i++) {
      const a = (i / n) * Math.PI * 2;
      const ux = Math.sin(a);
      const uy = -Math.cos(a);
      const tx = Math.cos(a);
      const ty = Math.sin(a);
      out.push([
        { x: (ux * 0.9 - tx * 0.17) * r, y: (uy * 0.9 - ty * 0.17) * r },
        { x: ux * len * r, y: uy * len * r },
        { x: (ux * 0.9 + tx * 0.17) * r, y: (uy * 0.9 + ty * 0.17) * r },
      ]);
    }
    return out;
  }
  return [];
}

// ---------------------------------------------------------------- ritsteg

function drawDeco(
  g: Phaser.GameObjects.Graphics,
  cx: number,
  cy: number,
  r: number,
  deco: Deco,
  light: number,
  dark: number,
): void {
  if (deco === 'none' || deco === 'bands') return;
  const lw = Math.max(2, 0.07 * r);
  const under = lw + Math.max(2.5, 0.09 * r);
  const strokes = decoStrokes(deco, r).map((p) => shift(p, cx, cy));
  const tris = decoTriangles(deco, r).map((p) => shift(p, cx, cy));

  // Pass 1: mörk understroke, gör dekoren läsbar mot den ljusa kroppen.
  g.lineStyle(under, dark, 1);
  for (const s of strokes) g.strokePoints(s, false);
  for (const t of tris) g.strokeTriangle(t[0].x, t[0].y, t[1].x, t[1].y, t[2].x, t[2].y);
  if (deco === 'antenna') {
    const end = strokes[0][strokes[0].length - 1];
    g.fillStyle(dark, 1);
    g.fillCircle(end.x, end.y, 0.15 * r + under / 2);
  }

  // Pass 2: ljus överstroke, gör den läsbar mot den mörka bakgrunden.
  for (const t of tris) {
    g.fillStyle(light, 1);
    g.fillTriangle(t[0].x, t[0].y, t[1].x, t[1].y, t[2].x, t[2].y);
  }
  g.lineStyle(lw, light, 1);
  for (const s of strokes) g.strokePoints(s, false);
  for (const t of tris) g.strokeTriangle(t[0].x, t[0].y, t[1].x, t[1].y, t[2].x, t[2].y);
  if (deco === 'antenna') {
    const end = strokes[0][strokes[0].length - 1];
    g.fillStyle(light, 1);
    g.fillCircle(end.x, end.y, 0.15 * r);
  }
}

/** Dekor ur SET_DECO_GEOM (UI.md §12.1.1). part 'back' ritas före kroppen, 'front' efter. */
function drawGeomDeco(
  g: Phaser.GameObjects.Graphics,
  cx: number,
  cy: number,
  r: number,
  geom: DecoGeom,
  part: 'back' | 'front',
  light: number,
  dark: number,
): void {
  const lw = Math.max(2, (geom.widthR ?? 0.07) * r);
  const under = lw + Math.max(2.5, 0.09 * r);
  const pts = (line: readonly (readonly [number, number])[]): Pt[] =>
    line.map(([x, y]) => ({ x: cx + x * r, y: cy + y * r }));
  const lines = (part === 'back' ? geom.back ?? [] : geom.strokes ?? []).map(pts);
  const tris = part === 'front' ? (geom.tris ?? []).map(pts) : [];
  const dots = part === 'front' ? geom.dots ?? [] : [];

  for (const [pass, w, c] of [[0, under, dark], [1, lw, light]] as const) {
    g.lineStyle(w, c, 1);
    for (const l of lines) g.strokePoints(l, false);
    for (const t of tris) {
      if (pass === 1) {
        g.fillStyle(c, 1);
        g.fillTriangle(t[0].x, t[0].y, t[1].x, t[1].y, t[2].x, t[2].y);
      }
      g.strokeTriangle(t[0].x, t[0].y, t[1].x, t[1].y, t[2].x, t[2].y);
    }
    g.fillStyle(c, 1);
    for (const d of dots) g.fillCircle(cx + d.x * r, cy + d.y * r, d.r * r + (pass === 0 ? under / 2 : 0));
  }
}

/** Dekor i rätt ritsteg, gamla (theme.ts) och nya (themes.ts) dekorer. */
function drawAnyDeco(
  g: Phaser.GameObjects.Graphics,
  cx: number,
  cy: number,
  r: number,
  deco: SetDeco,
  part: 'back' | 'front',
  light: number,
  dark: number,
): void {
  if (deco in SET_DECO_GEOM) {
    drawGeomDeco(g, cx, cy, r, SET_DECO_GEOM[deco as NewDeco], part, light, dark);
  } else if (part === 'front') {
    drawDeco(g, cx, cy, r, deco as Deco, light, dark);
  }
}

/** Steg 5 per set (UI.md §12.1.2). Positioner som i §3.1, färg alltid color2. */
function drawSpots(g: Phaser.GameObjects.Graphics, cx: number, cy: number, r: number, n: number, style: SpotStyle, c: number): void {
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2 + 0.7;
    const d = (0.46 + (i % 2 === 0 ? 0.16 : -0.16)) * r;
    const x = cx + Math.cos(a) * d;
    const y = cy + Math.sin(a) * d;
    switch (style) {
      case 'dot':
        g.fillStyle(c, 0.32);
        g.fillCircle(x, y, 0.11 * r);
        break;
      case 'crater':
        g.fillStyle(c, 0.18);
        g.fillCircle(x, y, 0.12 * r);
        g.lineStyle(0.045 * r, c, 0.45);
        g.strokeCircle(x, y, 0.12 * r);
        break;
      case 'flake':
        g.lineStyle(Math.max(1, 0.035 * r), c, 0.45);
        for (let k = 0; k < 3; k++) {
          const b = (k * Math.PI) / 3;
          const dx = Math.cos(b) * 0.1 * r;
          const dy = Math.sin(b) * 0.1 * r;
          g.lineBetween(x - dx, y - dy, x + dx, y + dy);
        }
        break;
      case 'sprinkle': {
        const w = Math.max(1.5, 0.07 * r);
        const dx = Math.cos(a + 0.9) * 0.1 * r;
        const dy = Math.sin(a + 0.9) * 0.1 * r;
        g.lineStyle(w, c, 0.5);
        g.lineBetween(x - dx, y - dy, x + dx, y + dy);
        g.fillStyle(c, 0.5);
        g.fillCircle(x - dx, y - dy, w / 2);
        g.fillCircle(x + dx, y + dy, w / 2);
        break;
      }
      case 'crack': {
        const ca = Math.cos(a);
        const sa = Math.sin(a);
        const zz: Pt[] = [
          [-0.12, 0.04],
          [-0.04, -0.04],
          [0.04, 0.04],
          [0.12, -0.04],
        ].map(([px, py]) => ({ x: x + (px * ca - py * sa) * r, y: y + (px * sa + py * ca) * r }));
        g.lineStyle(Math.max(1, 0.04 * r), c, 0.45);
        g.strokePoints(zz, false);
        break;
      }
    }
  }
}

function strokeArc(
  g: Phaser.GameObjects.Graphics,
  x: number,
  y: number,
  r: number,
  a0: number,
  a1: number,
): void {
  g.beginPath();
  g.arc(x, y, r, a0, a1, false);
  g.strokePath();
}

function fillSector(
  g: Phaser.GameObjects.Graphics,
  x: number,
  y: number,
  r: number,
  a0: number,
  a1: number,
): void {
  g.slice(x, y, r, a0, a1, false);
  g.fillPath();
}

function drawFace(
  g: Phaser.GameObjects.Graphics,
  cx: number,
  cy: number,
  r: number,
  face: Face,
  ink: number,
  accent2: number,
): void {
  const dx = 0.34 * r;
  const ey = cy - 0.1 * r;
  const er = 0.115 * r;
  const my = cy + 0.26 * r;
  const lw = Math.max(1.6, 0.075 * r);
  const P = Math.PI;
  const dots = (): void => {
    g.fillStyle(ink, 1);
    g.fillCircle(cx - dx, ey, er);
    g.fillCircle(cx + dx, ey, er);
  };

  g.fillStyle(ink, 1);
  g.lineStyle(lw, ink, 1);

  switch (face) {
    case 'dot':
      dots();
      break;
    case 'smile':
      dots();
      strokeArc(g, cx, cy + 0.02 * r, 0.34 * r, 0.15 * P, 0.85 * P);
      break;
    case 'wink':
      g.lineBetween(cx - dx - 0.13 * r, ey, cx - dx + 0.13 * r, ey);
      g.fillCircle(cx + dx, ey, er);
      strokeArc(g, cx, cy + 0.02 * r, 0.28 * r, 0.2 * P, 0.8 * P);
      break;
    case 'open':
      dots();
      g.fillEllipse(cx, my, 0.3 * r, 0.38 * r);
      break;
    case 'grin':
      dots();
      g.fillStyle(ink, 1);
      fillSector(g, cx, cy, 0.42 * r, 0.12 * P, 0.88 * P);
      g.fillStyle(accent2, 1);
      g.fillCircle(cx, cy + 0.28 * r, 0.13 * r);
      break;
    case 'sleepy':
      strokeArc(g, cx - dx, ey, 0.16 * r, 0.05 * P, 0.95 * P);
      strokeArc(g, cx + dx, ey, 0.16 * r, 0.05 * P, 0.95 * P);
      g.lineBetween(cx - 0.12 * r, my, cx + 0.12 * r, my);
      break;
    case 'starry': {
      for (const s of [-1, 1]) {
        const ex = cx + s * dx;
        for (let i = 0; i < 4; i++) {
          const a = (i / 4) * P;
          g.lineBetween(
            ex - Math.cos(a) * 0.17 * r,
            ey - Math.sin(a) * 0.17 * r,
            ex + Math.cos(a) * 0.17 * r,
            ey + Math.sin(a) * 0.17 * r,
          );
        }
      }
      g.fillStyle(ink, 1);
      fillSector(g, cx, cy, 0.36 * r, 0.15 * P, 0.85 * P);
      break;
    }
    case 'awe':
      for (const s of [-1, 1]) {
        g.strokeCircle(cx + s * dx, ey, 0.17 * r);
        g.fillCircle(cx + s * dx, ey, 0.075 * r);
      }
      g.fillEllipse(cx, my, 0.2 * r, 0.28 * r);
      break;
    case 'cool':
      g.lineStyle(0.17 * r, ink, 1);
      g.lineBetween(cx - 0.44 * r, cy - 0.12 * r, cx + 0.44 * r, cy - 0.05 * r);
      g.lineStyle(lw, ink, 1);
      strokeArc(g, cx + 0.06 * r, cy + 0.02 * r, 0.24 * r, 0.15 * P, 0.85 * P);
      break;
    case 'happy':
      strokeArc(g, cx - dx, ey, 0.16 * r, 1.15 * P, 1.85 * P);
      strokeArc(g, cx + dx, ey, 0.16 * r, 1.15 * P, 1.85 * P);
      strokeArc(g, cx, cy + 0.02 * r, 0.22 * r, 0.15 * P, 0.85 * P);
      break;
    case 'joy':
      strokeArc(g, cx - dx, ey, 0.17 * r, 1.15 * P, 1.85 * P);
      strokeArc(g, cx + dx, ey, 0.17 * r, 1.15 * P, 1.85 * P);
      g.fillStyle(ink, 1);
      fillSector(g, cx, cy + 0.06 * r, 0.34 * r, 0, P);
      g.fillStyle(accent2, 0.55);
      g.fillCircle(cx - 0.52 * r, cy + 0.1 * r, 0.15 * r);
      g.fillCircle(cx + 0.52 * r, cy + 0.1 * r, 0.15 * r);
      break;
    case 'angry':
      g.lineStyle(0.13 * r, ink, 1);
      g.lineBetween(cx - 0.48 * r, cy - 0.26 * r, cx - 0.18 * r, cy - 0.04 * r);
      g.lineBetween(cx + 0.48 * r, cy - 0.26 * r, cx + 0.18 * r, cy - 0.04 * r);
      g.strokePoints(
        quad(
          { x: cx - 0.3 * r, y: my },
          { x: cx - 0.15 * r, y: my - 0.16 * r },
          { x: cx, y: my },
          10,
        ),
        false,
      );
      g.strokePoints(
        quad(
          { x: cx, y: my },
          { x: cx + 0.15 * r, y: my + 0.16 * r },
          { x: cx + 0.3 * r, y: my },
          10,
        ),
        false,
      );
      break;
  }
}

/** Ritrecept steg 1–8 för en vanlig nivå. */
function drawSkin(
  g: Phaser.GameObjects.Graphics,
  cx: number,
  cy: number,
  r: number,
  skin: SetLevelSkin,
  spotStyle: SpotStyle,
): void {
  const color = hexToInt(skin.color);
  const color2 = hexToInt(skin.color2);
  const ink = hexToInt(THEME.palette.ink);
  const accent2 = hexToInt(THEME.palette.accent2);

  // 1. HALO – tre koncentriska cirklar, ingen ljusstyrkeväxling över tid.
  g.fillStyle(color, 0.06);
  g.fillCircle(cx, cy, r * (1 + skin.glow));
  g.fillStyle(color, 0.1);
  g.fillCircle(cx, cy, r * (1 + 0.66 * skin.glow));
  g.fillStyle(color, 0.14);
  g.fillCircle(cx, cy, r * (1 + 0.33 * skin.glow));

  // 1,5. DEKOR BAKOM KROPPEN (t.ex. saturnusringens bakre halva)
  drawAnyDeco(g, cx, cy, r, skin.deco ?? 'none', 'back', color, color2);

  // 2. KROPP
  g.fillStyle(color, 1);
  g.fillCircle(cx, cy, r);

  // 3. TOPPLJUS
  g.fillStyle(0xffffff, 0.2);
  g.fillEllipse(cx, cy - 0.44 * r, 1.12 * r, 0.56 * r);

  // 4. RING
  if (skin.ring) {
    g.lineStyle(0.08 * r, color2, 0.45);
    g.strokeCircle(cx, cy, 0.72 * r);
  }

  // 5. PRICKAR (stil per set)
  if (skin.spots) drawSpots(g, cx, cy, r, skin.spots, spotStyle, color2);

  // 6. KONTUR
  g.lineStyle(Math.max(2, 0.09 * r), color2, 1);
  g.strokeCircle(cx, cy, r);

  // 7. DEKOR
  drawAnyDeco(g, cx, cy, r, skin.deco ?? 'none', 'front', color, color2);

  // 8. ANSIKTE
  drawFace(g, cx, cy, r, skin.face, ink, accent2);
}

// ---------------------------------------------------------------- bakning

/**
 * Bakar setets 11 nivåer + vita siluetter. Idempotent och cachat per set: ett byte av set
 * kostar bara första gången. Anropas vid rundstart/boot och när boken visar en sida.
 */
export function bakeSet(scene: Phaser.Scene, setId: string): void {
  const set = themeSetById(setId);
  for (const def of LEVELS) {
    const key = ballTextureKey(def.level, set.id);
    if (scene.textures.exists(key)) continue;
    const skin = set.levels[def.level];
    const r = def.radius;
    const deco = skin.deco ?? 'none';
    const extent = Math.max(1 + skin.glow, decoExtent(deco));
    const pad = Math.ceil(r * extent + Math.max(3, 0.12 * r));
    const g = scene.make.graphics({ x: 0, y: 0 }, false);
    drawSkin(g, pad, pad, r, skin, set.spotStyle);
    g.generateTexture(key, pad * 2, pad * 2);
    g.destroy();
    const sil = scene.make.graphics({ x: 0, y: 0 }, false);
    const c = 0xffffff;
    drawAnyDeco(sil, pad, pad, r, deco, 'back', c, c);
    drawAnyDeco(sil, pad, pad, r, deco, 'front', c, c);
    sil.fillStyle(c, 1);
    sil.fillCircle(pad, pad, r);
    sil.generateTexture(silhouetteTextureKey(def.level, set.id), pad * 2, pad * 2);
    sil.destroy();
  }
}

/** Gör setet till det som `ballTextureKey(level)` pekar på. Anropas aldrig mitt i en runda. */
export function useSet(scene: Phaser.Scene, setId: string): void {
  const id = themeSetById(setId).id;
  bakeSet(scene, id);
  currentSet = id;
}

function bakeSpecials(scene: Phaser.Scene): void {
  const R = 25;

  if (!scene.textures.exists(SPECIAL_BOMB)) {
    const b = THEME.special.bomb;
    const pad = Math.ceil(R * Math.max(1 + b.glow, DECO_EXTENT.spikes) + 4);
    const g = scene.make.graphics({ x: 0, y: 0 }, false);
    const body = hexToInt(b.color);
    const edge = hexToInt(b.color2);
    const core = hexToInt(b.core);
    g.fillStyle(edge, 0.06);
    g.fillCircle(pad, pad, R * (1 + b.glow));
    g.fillStyle(edge, 0.1);
    g.fillCircle(pad, pad, R * (1 + 0.66 * b.glow));
    g.fillStyle(edge, 0.14);
    g.fillCircle(pad, pad, R * (1 + 0.33 * b.glow));
    drawDeco(g, pad, pad, R, 'spikes', body, edge);
    g.fillStyle(body, 1);
    g.fillCircle(pad, pad, R);
    g.fillStyle(core, 0.5);
    g.fillCircle(pad, pad, 0.34 * R);
    g.lineStyle(Math.max(2, 0.1 * R), edge, 1);
    g.strokeCircle(pad, pad, R);
    drawFace(g, pad, pad, R, 'angry', core, edge);
    g.generateTexture(SPECIAL_BOMB, pad * 2, pad * 2);
    g.destroy();
  }

  if (!scene.textures.exists(SPECIAL_RAINBOW)) {
    const rb = THEME.special.rainbow;
    const pad = Math.ceil(R * (1 + rb.glow) + 4);
    const g = scene.make.graphics({ x: 0, y: 0 }, false);
    g.fillStyle(0xffffff, 0.08);
    g.fillCircle(pad, pad, R * (1 + rb.glow));
    g.fillStyle(0xffffff, 0.12);
    g.fillCircle(pad, pad, R * (1 + 0.5 * rb.glow));
    const bands = rb.bands;
    for (let i = 0; i < bands.length; i++) {
      g.fillStyle(hexToInt(bands[i]), 1);
      fillSector(g, pad, pad, R, (i / bands.length) * Math.PI * 2, ((i + 1) / bands.length) * Math.PI * 2);
    }
    g.fillStyle(0xffffff, 0.45);
    g.fillCircle(pad, pad, 0.62 * R);
    g.lineStyle(0.1 * R, 0xffffff, 1);
    g.strokeCircle(pad, pad, R);
    drawFace(g, pad, pad, R, 'joy', hexToInt(rb.color2), hexToInt(THEME.palette.accent2));
    g.generateTexture(SPECIAL_RAINBOW, pad * 2, pad * 2);
    g.destroy();
  }
}

function bakeFx(scene: Phaser.Scene): void {
  if (!scene.textures.exists(FX_DOT)) {
    const g = scene.make.graphics({ x: 0, y: 0 }, false);
    g.fillStyle(0xffffff, 0.35);
    g.fillCircle(8, 8, 8);
    g.fillStyle(0xffffff, 1);
    g.fillCircle(8, 8, 4.5);
    g.generateTexture(FX_DOT, 16, 16);
    g.destroy();
  }
  if (!scene.textures.exists(FX_RING)) {
    const g = scene.make.graphics({ x: 0, y: 0 }, false);
    g.lineStyle(6, 0xffffff, 1);
    g.strokeCircle(64, 64, 58);
    g.generateTexture(FX_RING, 128, 128);
    g.destroy();
  }
  // Partikelformer per set (UI.md §12.1.3), vita 16×16.
  const shapes: Record<Exclude<ParticleShape, 'dot'>, (g: Phaser.GameObjects.Graphics) => void> = {
    star: (g) => {
      const pts: Pt[] = [];
      for (let i = 0; i < 8; i++) {
        const a = (i / 8) * Math.PI * 2 - Math.PI / 2;
        const rr = i % 2 === 0 ? 7 : 2;
        pts.push({ x: 8 + Math.cos(a) * rr, y: 8 + Math.sin(a) * rr });
      }
      g.fillPoints(pts, true);
    },
    shard: (g) => g.fillTriangle(8, 0, 10.5, 16, 5.5, 16),
    bubble: (g) => {
      g.lineStyle(1.6, 0xffffff, 1);
      g.strokeCircle(8, 8, 6);
      g.fillCircle(5.5, 5.5, 1.6);
    },
    ring: (g) => {
      g.lineStyle(2.4, 0xffffff, 1);
      g.strokeCircle(8, 8, 6.5);
    },
  };
  for (const [shape, draw] of Object.entries(shapes)) {
    const key = particleTextureKey(shape as ParticleShape);
    if (scene.textures.exists(key)) continue;
    const g = scene.make.graphics({ x: 0, y: 0 }, false);
    g.fillStyle(0xffffff, 1);
    draw(g);
    g.generateTexture(key, 16, 16);
    g.destroy();
  }
}

/** Tunn guldring med åtta fyrudds-gnistor. Ingen blixt: pulsen görs med alpha ≤1 Hz. */
function bakeGlitter(scene: Phaser.Scene): void {
  if (scene.textures.exists(FX_GLITTER)) return;
  const gold = hexToInt(THEME.palette.gold);
  const R = FX_GLITTER_R;
  const g = scene.make.graphics({ x: 0, y: 0 }, false);
  g.lineStyle(2, gold, 0.55);
  g.strokeCircle(64, 64, R);
  for (let i = 0; i < 8; i++) {
    const a = (i / 8) * Math.PI * 2;
    const x = 64 + Math.cos(a) * R;
    const y = 64 + Math.sin(a) * R;
    const big = i % 2 === 0 ? 9 : 6;
    const w = big * 0.28;
    g.fillStyle(i % 2 === 0 ? 0xffffff : gold, 1);
    g.fillTriangle(x - big, y, x, y - w, x, y + w);
    g.fillTriangle(x + big, y, x, y - w, x, y + w);
    g.fillTriangle(x, y - big, x - w, y, x + w, y);
    g.fillTriangle(x, y + big, x - w, y, x + w, y);
  }
  g.generateTexture(FX_GLITTER, 128, 128);
  g.destroy();
}

export const BG_GLOW = 'bg-glow';

function bakeBackground(scene: Phaser.Scene): void {
  if (scene.textures.exists(BG_GLOW)) return;
  const size = 256;
  const canvas = scene.textures.createCanvas(BG_GLOW, size, size);
  const ctx = canvas?.getContext();
  if (!canvas || !ctx) return;
  // Vit: tintas med setets bgGlow i ui/background.ts.
  const r = 255;
  const g = 255;
  const b = 255;
  const grad = ctx.createRadialGradient(size / 2, size / 2, 0, size / 2, size / 2, size / 2);
  grad.addColorStop(0, `rgba(${r},${g},${b},1)`);
  grad.addColorStop(0.55, `rgba(${r},${g},${b},0.45)`);
  grad.addColorStop(1, `rgba(${r},${g},${b},0)`);
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, size, size);
  canvas.refresh();
}

/** Bakar allt vid boot (nivåerna för aktivt set). Idempotent. */
export function bakeTextures(scene: Phaser.Scene, setId: string = currentSet): void {
  useSet(scene, setId);
  bakeSpecials(scene);
  bakeFx(scene);
  bakeGlitter(scene);
  bakeBackground(scene);
}

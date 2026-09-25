/**
 * artv2.ts – referensrenderare för "Art v2" (UI.md §15). Ren TS, INGEN Phaser-import.
 *
 * Tar SAMMA primitivspråk som i dag (AvatarOp i avatars.ts, SetLevelSkin/SET_DECO_GEOM i themes.ts,
 * Face/Deco i theme.ts) och ritar dem på en CanvasRenderingContext2D med ett materiallager:
 * radiell basgradient, inre skugga, kantljus, speglingsljus, varierad kontur, kontaktskugga,
 * drop shadow och "inset"-ansikten. Parametrar: `data/art.ts`.
 *
 * Koppling i Phaser (programmeraren):
 *   const info = avatarBakeInfo(displayPx, dpr);             // eller levelBakeInfo(skin, r, dpr)
 *   const tex = scene.textures.createCanvas(key, info.px, info.px)!;
 *   renderAvatar(tex.getContext(), def, displayPx, { dpr: info.dpr });
 *   tex.refresh();
 *   scene.add.image(x, y, key).setScale(1 / info.dpr).setOrigin(0.5, info.originY);
 *
 * Kontexten ska ha identitetstransform (som en ny CanvasTexture): skuggor i Canvas2D mäts i
 * enhetspixlar och ignorerar transformen, så renderaren räknar om dem själv.
 * `mode: 'v1'` ritar exakt dagens platta recept (för före/efter och som lågprestandaläge).
 */

import { THEME, type Deco, type Face } from '../data/theme';
import { SET_DECO_GEOM, type DecoGeom, type NewDeco, type SetDeco, type SetLevelSkin, type SpotStyle } from '../data/themes';
import { AVATAR_BOX, AVATAR_GRIP, AVATAR_UI, type AvatarDef, type AvatarOp } from '../data/avatarsIndex';
import { ART } from '../data/art';
import { mulberry32 } from '../systems/rng';

// ================================================================ typer

export type ArtMode = 'v1' | 'v2';

export interface ArtOpts {
  /** devicePixelRatio. Klampas till ART.maxDpr (och ART.maxTexSide för stora nivåer). Default 1. */
  readonly dpr?: number;
  /** Default 'v2'. */
  readonly mode?: ArtMode;
  /** Vit siluett utan noSil-lager, alpha 1 (alltid platt). */
  readonly sil?: boolean;
  /** Mjuk drop shadow under figuren/objektet. Default true i v2. */
  readonly shadow?: boolean;
  /** Skapar en arbetsyta (default OffscreenCanvas, annars <canvas>). */
  readonly scratch?: (w: number, h: number) => HTMLCanvasElement | OffscreenCanvas;
}

export interface AvatarOpts extends ArtOpts {
  /** 'full' = figur + pupiller; 'body' = utan pupillagret; 'pupils' = bara pupillerna (Fenja). */
  readonly part?: 'full' | 'body' | 'pupils';
  /** Uppgraderingsrombar på axeln (0–2). */
  readonly rombs?: number;
}

export interface LevelOpts extends ArtOpts {
  /** Setets prickstil. Default 'dot'. */
  readonly spotStyle?: SpotStyle;
}

export interface BakeInfo {
  /** Texturens sida i enhetspixlar (kvadratisk). */
  readonly px: number;
  /** Faktisk bakningsfaktor. Visa med setScale(1 / dpr). */
  readonly dpr: number;
  /** Texturens sida i logiska px (px / dpr). */
  readonly logical: number;
  /** Origin y för Phaser (greppunkten för avatarer, 0,5 för nivåer). */
  readonly originY: number;
}

type P2 = readonly [number, number];
type Ctx = CanvasRenderingContext2D;

const INK = THEME.palette.ink;
const WHITE = '#FFFFFF';
const EDGE_W = 2.8;
/** Pad runt 56-boxen i box-enheter: v1 som avatarArt.ts, v2 större för drop shadow. */
const PAD_V1 = 2;
const PAD_V2 = 5;

// ================================================================ färg

type RGB = readonly [number, number, number];

function hexRgb(hex: string): RGB {
  const h = hex.replace('#', '');
  const v = h.length === 3 ? h.split('').map((c) => c + c).join('') : h.slice(0, 6);
  const n = parseInt(v, 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

function rgbHex([r, g, b]: RGB): string {
  const c = (x: number): string => Math.round(Math.max(0, Math.min(255, x))).toString(16).padStart(2, '0');
  return `#${c(r)}${c(g)}${c(b)}`;
}

/** HSL med s, l i 0..100. */
function rgbHsl([r, g, b]: RGB): [number, number, number] {
  const R = r / 255;
  const G = g / 255;
  const B = b / 255;
  const max = Math.max(R, G, B);
  const min = Math.min(R, G, B);
  const l = (max + min) / 2;
  if (max === min) return [0, 0, l * 100];
  const d = max - min;
  const s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
  let h = max === R ? (G - B) / d + (G < B ? 6 : 0) : max === G ? (B - R) / d + 2 : (R - G) / d + 4;
  h *= 60;
  return [h, s * 100, l * 100];
}

function hslRgb(h: number, s: number, l: number): RGB {
  const S = Math.max(0, Math.min(100, s)) / 100;
  const L = Math.max(0, Math.min(100, l)) / 100;
  const k = (n: number): number => (n + h / 30) % 12;
  const a = S * Math.min(L, 1 - L);
  const f = (n: number): number => L - a * Math.max(-1, Math.min(k(n) - 3, Math.min(9 - k(n), 1)));
  return [f(0) * 255, f(8) * 255, f(4) * 255];
}

/** Färgderivering: HSL-lightness/saturation ± procentenheter. Mörka färger mörkas relativt. */
export function tone(hex: string, dL: number, dS = 0): string {
  const [h, s, l] = rgbHsl(hexRgb(hex));
  let L = l + dL;
  if (dL < 0 && l < ART.base.darkL) L = Math.max(L, l * ART.base.darkMul);
  return rgbHex(hslRgb(h, s + dS, L));
}

function mix(a: string, b: string, t: number): string {
  const A = hexRgb(a);
  const B = hexRgb(b);
  return rgbHex([A[0] + (B[0] - A[0]) * t, A[1] + (B[1] - A[1]) * t, A[2] + (B[2] - A[2]) * t]);
}

function rgba(hex: string, a: number): string {
  const [r, g, b] = hexRgb(hex);
  return `rgba(${r},${g},${b},${Math.max(0, Math.min(1, a))})`;
}

/** Relativ luminans (WCAG), för kontrollskript. */
export function luminance(hex: string): number {
  const f = (c: number): number => {
    const v = c / 255;
    return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
  };
  const [r, g, b] = hexRgb(hex);
  return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b);
}

/** De härledda materialfärgerna för en kulör. */
export function materialColors(color: string): { hi: string; base: string; lo: string; shade: string; rim: string } {
  const B = ART.base;
  return {
    hi: tone(color, B.hiL, B.hiS),
    base: color,
    lo: tone(color, B.loL, B.loS),
    shade: tone(color, ART.inner.dL, ART.inner.dS),
    rim: mix(tone(color, ART.rim.dL, ART.rim.dS), WHITE, ART.rim.mixWhite),
  };
}

// ================================================================ penna och geometri

interface Pen {
  readonly ctx: Ctx;
  /** Enhetspixlar per ritenhet (box-enhet resp. logisk px). Skuggor räknas om med k. */
  readonly k: number;
  readonly sil: boolean;
  readonly v2: boolean;
}

/** En fylld form med bbox (centrum + halvstorlek) i ritenheter. */
interface Shape {
  readonly path: Path2D;
  readonly cx: number;
  readonly cy: number;
  readonly hw: number;
  readonly hh: number;
}

const col = (p: Pen, c: string): string => (p.sil ? WHITE : c);
const alp = (p: Pen, a: number | undefined): number => (p.sil ? 1 : a ?? 1);

function bboxShape(path: Path2D, pts: readonly P2[]): Shape {
  let x0 = Infinity;
  let y0 = Infinity;
  let x1 = -Infinity;
  let y1 = -Infinity;
  for (const [x, y] of pts) {
    x0 = Math.min(x0, x);
    y0 = Math.min(y0, y);
    x1 = Math.max(x1, x);
    y1 = Math.max(y1, y);
  }
  return { path, cx: (x0 + x1) / 2, cy: (y0 + y1) / 2, hw: Math.max(0.5, (x1 - x0) / 2), hh: Math.max(0.5, (y1 - y0) / 2) };
}

function ellipsePts(x: number, y: number, w: number, h: number, rot: number, n = 24): P2[] {
  const out: P2[] = [];
  const c = Math.cos(rot);
  const sn = Math.sin(rot);
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2;
    const ex = (Math.cos(a) * w) / 2;
    const ey = (Math.sin(a) * h) / 2;
    out.push([x + ex * c - ey * sn, y + ex * sn + ey * c]);
  }
  return out;
}

function quadPts(a: P2, c: P2, b: P2, n = 16): P2[] {
  const out: P2[] = [];
  for (let i = 0; i <= n; i++) {
    const t = i / n;
    const u = 1 - t;
    out.push([u * u * a[0] + 2 * u * t * c[0] + t * t * b[0], u * u * a[1] + 2 * u * t * c[1] + t * t * b[1]]);
  }
  return out;
}

function polyPath(pts: readonly P2[], closed: boolean): Path2D {
  const p = new Path2D();
  pts.forEach(([x, y], i) => (i === 0 ? p.moveTo(x, y) : p.lineTo(x, y)));
  if (closed) p.closePath();
  return p;
}

/** v2: äkta ellips (v1 ritar 24-punktspolygon som avatarArt.ts). */
function ellipseShape(x: number, y: number, w: number, h: number, rot: number, smooth: boolean): Shape {
  if (!smooth) {
    const pts = ellipsePts(x, y, w, h, rot);
    return bboxShape(polyPath(pts, true), pts);
  }
  const p = new Path2D();
  p.ellipse(x, y, w / 2, h / 2, rot, 0, Math.PI * 2);
  const c = Math.abs(Math.cos(rot));
  const s = Math.abs(Math.sin(rot));
  return { path: p, cx: x, cy: y, hw: Math.max(0.5, (w / 2) * c + (h / 2) * s), hh: Math.max(0.5, (w / 2) * s + (h / 2) * c) };
}

function circleShape(x: number, y: number, r: number): Shape {
  const p = new Path2D();
  p.arc(x, y, r, 0, Math.PI * 2);
  return { path: p, cx: x, cy: y, hw: r, hh: r };
}

function strokePath(ctx: Ctx, path: Path2D, width: number, style: string | CanvasGradient, round = true): void {
  ctx.lineWidth = width;
  ctx.strokeStyle = style;
  ctx.lineCap = round ? 'round' : 'butt';
  ctx.lineJoin = round ? 'round' : 'miter';
  ctx.stroke(path);
}

function resetShadow(ctx: Ctx): void {
  ctx.shadowColor = 'rgba(0,0,0,0)';
  ctx.shadowBlur = 0;
  ctx.shadowOffsetX = 0;
  ctx.shadowOffsetY = 0;
}

function scratchCanvas(opts: ArtOpts, w: number, h: number): { canvas: HTMLCanvasElement | OffscreenCanvas; ctx: Ctx } {
  let canvas: HTMLCanvasElement | OffscreenCanvas;
  if (opts.scratch) canvas = opts.scratch(w, h);
  else if (typeof OffscreenCanvas !== 'undefined') canvas = new OffscreenCanvas(w, h);
  else {
    const c = document.createElement('canvas');
    c.width = w;
    c.height = h;
    canvas = c;
  }
  const ctx = canvas.getContext('2d') as unknown as Ctx | null;
  if (!ctx) throw new Error('artv2: ingen 2D-kontext');
  return { canvas, ctx };
}

// ================================================================ materiallagret (v2)

/**
 * Skugga av "allt utanför formen", klippt till formen: inre skugga (off uppåt) eller
 * kantljus (off ned-vänster, ljus färg). off/blur i ritenheter.
 */
function insetShadow(p: Pen, sh: Shape, color: string, alpha: number, offX: number, offY: number, blur: number): void {
  const { ctx, k } = p;
  const m = Math.abs(offX) + Math.abs(offY) + blur * 3 + 4;
  const outer = new Path2D();
  outer.rect(sh.cx - sh.hw - m, sh.cy - sh.hh - m, 2 * (sh.hw + m), 2 * (sh.hh + m));
  outer.addPath(sh.path);
  ctx.save();
  ctx.clip(sh.path);
  ctx.shadowColor = rgba(color, alpha);
  ctx.shadowBlur = blur * k;
  ctx.shadowOffsetX = offX * k;
  ctx.shadowOffsetY = offY * k;
  ctx.fillStyle = '#000';
  ctx.fill(outer, 'evenodd');
  ctx.restore();
}

/** Mjuk skugga av formen som bara landar på det som redan är ritat (source-atop). */
function contactShadow(p: Pen, path: Path2D, dx: number, dy: number, blur: number, color: string, alpha: number, stroke = 0): void {
  const { ctx, k } = p;
  const FAR = 8192 / k;
  ctx.save();
  ctx.globalCompositeOperation = 'source-atop';
  ctx.shadowColor = rgba(color, alpha);
  ctx.shadowBlur = blur * k;
  ctx.shadowOffsetX = (FAR + dx) * k;
  ctx.shadowOffsetY = dy * k;
  ctx.translate(-FAR, 0);
  if (stroke > 0) strokePath(ctx, path, stroke, '#000');
  else {
    ctx.fillStyle = '#000';
    ctx.fill(path);
  }
  ctx.restore();
}

/** Elliptisk radiell gradient i formens bbox, ljus uppe till vänster. */
function fillBase(p: Pen, sh: Shape, color: string): void {
  const { ctx } = p;
  const mc = materialColors(color);
  const L = ART.light;
  ctx.save();
  ctx.clip(sh.path);
  ctx.translate(sh.cx, sh.cy);
  ctx.scale(sh.hw, sh.hh);
  const g = ctx.createRadialGradient(L.x, L.y, 0, L.x, L.y, ART.base.radius);
  g.addColorStop(0, mc.hi);
  g.addColorStop(ART.base.mid, mc.base);
  g.addColorStop(1, mc.lo);
  ctx.fillStyle = g;
  ctx.fillRect(-4, -4, 8, 8);
  ctx.restore();
}

/** Kontur med varierad alpha/ljushet: ljusare och tunnare i ljuset, full i skuggan. */
function edgeStyle(p: Pen, sh: Shape, edge: string, alpha: number): CanvasGradient {
  const E = ART.edge;
  const g = p.ctx.createLinearGradient(sh.cx - sh.hw * 0.8, sh.cy - sh.hh * 0.8, sh.cx + sh.hw * 0.8, sh.cy + sh.hh * 0.8);
  g.addColorStop(0, rgba(tone(edge, E.dLTop), E.alphaTop * alpha));
  g.addColorStop(1, rgba(edge, E.alphaBottom * alpha));
  return g;
}

/** Hård speglingsprick uppe till vänster. */
function specDot(p: Pen, sh: Shape, alpha = 1): void {
  const D = ART.spec.dot;
  const hm = (sh.hw + sh.hh) / 2;
  p.ctx.fillStyle = rgba(WHITE, D.alpha * alpha);
  p.ctx.beginPath();
  p.ctx.arc(sh.cx + D.x * sh.hw, sh.cy + D.y * sh.hh, Math.max(0.35, D.r * hm), 0, Math.PI * 2);
  p.ctx.fill();
}

/** Inre skugga + kantljus. `edgeHalf` = halva konturbredden, så att banden syns innanför den. */
function shadeAndRim(p: Pen, sh: Shape, color: string, edgeHalf: number): void {
  const mc = materialColors(color);
  const I = ART.inner;
  const R = ART.rim;
  const hm = (sh.hw + sh.hh) / 2;
  insetShadow(p, sh, mc.shade, I.alpha, I.offX * sh.hw, -(edgeHalf + Math.abs(I.offY) * sh.hh), I.blur * hm);
  const d = edgeHalf + R.width * hm;
  insetShadow(p, sh, mc.rim, R.alpha, R.dirX * d, R.dirY * d, Math.max(0.3, R.blur * hm));
}

/** En hel materialdel (avatar): kontaktskugga, bas, skugga, kantljus, prick, kontur. */
function materialPart(p: Pen, sh: Shape, color: string, alpha: number, edge: string | undefined, edgeW: number): void {
  const { ctx } = p;
  const C = ART.contact;
  const big = Math.max(sh.hw, sh.hh);
  contactShadow(p, sh.path, C.dxU, C.dyU, C.blurU, C.color, C.alpha * alpha);
  ctx.save();
  ctx.globalAlpha = alpha;
  fillBase(p, sh, color);
  const edgeHalf = edge ? edgeW / 2 : 0;
  if (big >= ART.inner.minHalfU) shadeAndRim(p, sh, color, edgeHalf);
  if (big >= ART.spec.minHalfU) specDot(p, sh);
  if (edge) strokePath(ctx, sh.path, edgeW, edgeStyle(p, sh, edge, 1));
  ctx.restore();
}

/** Rör: mörkt underlag, färg, högdager längs röret (spröt, ben, tentakler). */
function tube(p: Pen, path: Path2D, width: number, color: string, alpha: number, under?: { color: string; width: number }): void {
  const { ctx } = p;
  const T = ART.tube;
  ctx.save();
  ctx.globalAlpha = alpha;
  if (under) {
    contactShadow(p, path, ART.contact.dxU * 0.6, ART.contact.dyU * 0.6, ART.contact.blurU * 0.6, ART.contact.color, ART.contact.alpha, under.width);
    strokePath(ctx, path, under.width, under.color);
  }
  strokePath(ctx, path, width, color);
  if (width >= T.minWidthU) {
    const o = T.hiOff * width;
    ctx.translate(-o * 0.7, -o * 0.7);
    strokePath(ctx, path, width * T.hiW, rgba(tone(color, T.hiL), T.hiAlpha));
  }
  ctx.restore();
}

// ================================================================ avatarer

const isWhite = (c: string): boolean => c.toUpperCase() === WHITE;
const isInk = (c: string): boolean => c.toUpperCase() === INK.toUpperCase() || luminance(c) < 0.02;

type AvatarShapeOp = Extract<AvatarOp, { op: 'circle' | 'ellipse' | 'poly' }>;

function avatarShape(p: Pen, op: AvatarShapeOp): Shape {
  if (op.op === 'circle') return p.v2 ? circleShape(op.x, op.y, op.r) : ellipseShape(op.x, op.y, op.r * 2, op.r * 2, 0, false);
  if (op.op === 'ellipse') return ellipseShape(op.x, op.y, op.w, op.h, op.rot ?? 0, p.v2);
  return bboxShape(polyPath(op.pts, !op.open), op.pts);
}

/** Dagens platta ritning (avatarArt.ts), 1:1. */
function avatarOpV1(p: Pen, op: AvatarOp): void {
  const { ctx } = p;
  if (op.op === 'scatter') {
    const rng = mulberry32(op.seed);
    for (let i = 0; i < op.count; i++) {
      const x = op.x + rng.next() * op.w;
      const y = op.y + rng.next() * op.h;
      const r = op.rMin + rng.next() * (op.rMax - op.rMin);
      const a = op.alphaMin + rng.next() * (op.alphaMax - op.alphaMin);
      ctx.globalAlpha = p.sil ? 1 : a;
      ctx.fillStyle = col(p, op.color);
      ctx.beginPath();
      ctx.arc(x, y, r, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalAlpha = 1;
    return;
  }
  ctx.globalAlpha = alp(p, op.alpha);
  if (op.op === 'curve' || op.op === 'line') {
    const pts = op.op === 'curve' ? quadPts(op.from, op.ctrl, op.to) : [op.from, op.to];
    const path = polyPath(pts, false);
    if (op.edge) strokePath(ctx, path, op.width + 2 * (op.edgeW ?? EDGE_W), col(p, op.edge));
    strokePath(ctx, path, op.width, col(p, op.color));
  } else {
    const sh = avatarShape(p, op);
    if (op.stroke) {
      strokePath(ctx, sh.path, op.stroke, col(p, op.color), op.op === 'poly');
    } else {
      ctx.fillStyle = col(p, op.color);
      ctx.fill(sh.path);
      if (op.edge) strokePath(ctx, sh.path, op.edgeW ?? EDGE_W, col(p, op.edge), op.op === 'poly');
    }
  }
  ctx.globalAlpha = 1;
}

/** v2: klassificera op:en och ge den rätt material. Formen är alltid densamma som v1. */
function avatarOpV2(p: Pen, op: AvatarOp): void {
  const { ctx } = p;
  if (op.op === 'scatter') return avatarOpV1(p, op);
  const a = op.alpha ?? 1;

  // Rör (ben, armar, spröt med edge) och streck.
  if (op.op === 'curve' || op.op === 'line') {
    const pts = op.op === 'curve' ? quadPts(op.from, op.ctrl, op.to, 24) : [op.from, op.to];
    const path = polyPath(pts, false);
    if (op.edge) {
      tube(p, path, op.width, op.color, a, { color: op.edge, width: op.width + 2 * (op.edgeW ?? EDGE_W) });
      return;
    }
    if (isInk(op.color)) return inkFeature(p, (c) => strokePath(ctx, path, op.width, c), a);
    ctx.save();
    ctx.globalAlpha = a;
    strokePath(ctx, path, op.width, op.color);
    ctx.restore();
    return;
  }

  const sh = avatarShape(p, op);
  if (op.stroke) {
    if (isInk(op.color)) return inkFeature(p, (c) => strokePath(ctx, sh.path, op.stroke ?? 1, c, op.op === 'poly'), a);
    ctx.save();
    ctx.globalAlpha = a;
    strokePath(ctx, sh.path, op.stroke, op.color, op.op === 'poly');
    ctx.restore();
    return;
  }

  // Topp-ljuset (`shine`): mjuk gradientellips i stället för platt.
  if (op.op === 'ellipse' && isWhite(op.color) && a <= 0.5 && !op.edge) {
    softEllipse(ctx, op.x, op.y, op.w / 2, op.h / 2, op.rot ?? 0, WHITE, ART.spec.softAlpha * (a / 0.26));
    return;
  }
  // Kinder: mjuk rodnad.
  if (op.op === 'ellipse' && !op.edge && a > 0.4 && a < 0.7 && !isWhite(op.color)) {
    softEllipse(ctx, op.x, op.y, op.w / 2, op.h / 2, op.rot ?? 0, op.color, ART.cheek.alpha * (a / 0.55));
    return;
  }
  // Ögonvita med ink-kant: sfär + ögonlockets skugga.
  if (op.op === 'circle' && isWhite(op.color) && op.edge) {
    eyeWhite(p, sh, op.edge, op.edgeW ?? EDGE_W, a);
    return;
  }
  // Glint: vit prick utan kant → mjuk gloria + hård prick.
  if (op.op === 'circle' && isWhite(op.color) && !op.edge && op.r <= 1.8) {
    softEllipse(ctx, op.x, op.y, op.r * ART.face.glintHaloMul, op.r * ART.face.glintHaloMul, 0, WHITE, ART.face.glintHaloAlpha * a);
    ctx.save();
    ctx.globalAlpha = a;
    ctx.fillStyle = WHITE;
    ctx.fill(sh.path);
    ctx.restore();
    return;
  }
  // Ansiktsdrag i ink: inset (ljus underläpp), formen oförändrad.
  if (isInk(op.color) && !op.edge) {
    inkFeature(p, (c) => {
      ctx.fillStyle = c;
      ctx.fill(sh.path);
    }, a);
    return;
  }
  // Material: alla fyllda delar med kontur.
  if (op.edge) {
    materialPart(p, sh, op.color, a, op.edge, op.edgeW ?? EDGE_W);
    return;
  }
  // Detaljer (fläckar, mage, stjärnor): platta, som tryck på materialet.
  ctx.save();
  ctx.globalAlpha = a;
  ctx.fillStyle = op.color;
  ctx.fill(sh.path);
  ctx.restore();
}

/** Mjuk radiell ellips (topp-ljus, kinder, glint-gloria). */
function softEllipse(ctx: Ctx, x: number, y: number, rx: number, ry: number, rot: number, color: string, alpha: number): void {
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(rot);
  ctx.scale(Math.max(0.01, rx), Math.max(0.01, ry));
  const g = ctx.createRadialGradient(0, 0, 0, 0, 0, 1);
  g.addColorStop(0, rgba(color, alpha));
  g.addColorStop(0.55, rgba(color, alpha * 0.55));
  g.addColorStop(1, rgba(color, 0));
  ctx.fillStyle = g;
  ctx.beginPath();
  ctx.arc(0, 0, 1, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
}

/** Ink-drag med ljus underläpp (inset). `draw(style)` ritar formen med given stil. */
function inkFeature(p: Pen, draw: (style: string) => void, alpha: number, lipDy = ART.face.lipDyU, ink = INK): void {
  const { ctx } = p;
  ctx.save();
  ctx.globalCompositeOperation = 'source-atop';
  ctx.globalAlpha = alpha;
  ctx.translate(0, lipDy);
  draw(rgba(ART.face.lipColor, ART.face.lipAlpha));
  ctx.restore();
  ctx.save();
  ctx.globalAlpha = alpha;
  draw(ink);
  ctx.restore();
}

function eyeWhite(p: Pen, sh: Shape, edge: string, edgeW: number, alpha: number): void {
  const { ctx } = p;
  ctx.save();
  ctx.globalAlpha = alpha;
  ctx.save();
  ctx.clip(sh.path);
  const g = ctx.createRadialGradient(sh.cx - sh.hw * 0.3, sh.cy - sh.hh * 0.35, 0, sh.cx - sh.hw * 0.3, sh.cy - sh.hh * 0.35, sh.hw * 1.5);
  g.addColorStop(0, WHITE);
  g.addColorStop(0.55, WHITE);
  g.addColorStop(1, ART.face.eyeWhiteLow);
  ctx.fillStyle = g;
  ctx.fillRect(sh.cx - sh.hw - 1, sh.cy - sh.hh - 1, sh.hw * 2 + 2, sh.hh * 2 + 2);
  ctx.restore();
  // Ögonlockets skugga: inre skugga uppifrån.
  insetShadow(p, sh, INK, ART.face.eyeLidAlpha, 0, edgeW / 2 + sh.hh * 0.18, sh.hh * 0.3);
  strokePath(ctx, sh.path, edgeW, edge);
  ctx.restore();
}

// ================================================================ nivåer: geometri (samma som textures.ts)

interface Pt {
  x: number;
  y: number;
}

const DECO_EXTENT: Record<Deco, number> = { none: 1, antenna: 1.45, tuft: 1.4, tentacles: 1.4, fins: 1.4, crown: 1.36, spikes: 1.4, bands: 1 };

function decoExtent(d: SetDeco): number {
  return d in SET_DECO_GEOM ? SET_DECO_GEOM[d as NewDeco].extent : DECO_EXTENT[d as Deco];
}

function quadR(p0: Pt, p1: Pt, p2: Pt, n: number): Pt[] {
  return quadPts([p0.x, p0.y], [p1.x, p1.y], [p2.x, p2.y], n).map(([x, y]) => ({ x, y }));
}

function decoStrokes(deco: Deco, r: number): Pt[][] {
  switch (deco) {
    case 'antenna':
      return [quadR({ x: 0, y: -0.95 * r }, { x: 0.1 * r, y: -1.34 * r }, { x: 0.24 * r, y: -1.4 * r }, 14)];
    case 'tuft':
      return [-0.34, 0, 0.34].map((a) => [
        { x: Math.sin(a) * 0.55 * r, y: -Math.cos(a) * 0.9 * r },
        { x: Math.sin(2.2 * a) * 0.8 * r, y: -Math.cos(a) * 1.34 * r },
      ]);
    case 'tentacles':
      return [-0.46, 0, 0.46].map((dx) => quadR({ x: dx * r, y: 0.8 * r }, { x: 1.25 * dx * r, y: 1.2 * r }, { x: 0.75 * dx * r, y: 1.34 * r }, 12));
    default:
      return [];
  }
}

function decoTriangles(deco: Deco, r: number): Pt[][] {
  const tri = (a: number, base: number, tip: number, half: number): Pt[] => {
    const ux = Math.sin(a);
    const uy = -Math.cos(a);
    const tx = Math.cos(a);
    const ty = Math.sin(a);
    return [
      { x: (ux * base - tx * half) * r, y: (uy * base - ty * half) * r },
      { x: ux * tip * r, y: uy * tip * r },
      { x: (ux * base + tx * half) * r, y: (uy * base + ty * half) * r },
    ];
  };
  if (deco === 'fins') {
    return [-1, 1].map((s) => [
      { x: s * 0.8 * r, y: -0.34 * r },
      { x: s * 1.34 * r, y: 0.02 * r },
      { x: s * 0.8 * r, y: 0.38 * r },
    ]);
  }
  if (deco === 'crown') return [-0.4, 0, 0.4].map((a) => tri(a, 0.94, 1.3, 0.17));
  if (deco === 'spikes') {
    const n = THEME.special.bomb.spikes;
    const len = 1 + THEME.special.bomb.spikeLen;
    return Array.from({ length: n }, (_, i) => tri((i / n) * Math.PI * 2, 0.9, len, 0.17));
  }
  return [];
}

interface DecoParts {
  lines: Pt[][];
  tris: Pt[][];
  dots: { x: number; y: number; r: number }[];
  lw: number;
  under: number;
}

/** Samlar dekorens delar för 'back' eller 'front', som drawAnyDeco i textures.ts. */
function decoParts(deco: SetDeco, r: number, part: 'back' | 'front'): DecoParts {
  if (deco in SET_DECO_GEOM) {
    const geom: DecoGeom = SET_DECO_GEOM[deco as NewDeco];
    const lw = Math.max(2, (geom.widthR ?? 0.07) * r);
    const pts = (line: readonly (readonly [number, number])[]): Pt[] => line.map(([x, y]) => ({ x: x * r, y: y * r }));
    return {
      lines: (part === 'back' ? geom.back ?? [] : geom.strokes ?? []).map(pts),
      tris: part === 'front' ? (geom.tris ?? []).map(pts) : [],
      dots: part === 'front' ? (geom.dots ?? []).map((d) => ({ x: d.x * r, y: d.y * r, r: d.r * r })) : [],
      lw,
      under: lw + Math.max(2.5, 0.09 * r),
    };
  }
  const d = deco as Deco;
  const lw = Math.max(2, 0.07 * r);
  const empty = part === 'back' || d === 'none' || d === 'bands';
  const lines = empty ? [] : decoStrokes(d, r);
  const dots = !empty && d === 'antenna' ? [{ ...lines[0][lines[0].length - 1], r: 0.15 * r }] : [];
  return { lines, tris: empty ? [] : decoTriangles(d, r), dots, lw, under: lw + Math.max(2.5, 0.09 * r) };
}

const ptPath = (pts: Pt[], closed: boolean): Path2D => polyPath(pts.map((q) => [q.x, q.y] as P2), closed);

function drawDecoV1(ctx: Ctx, parts: DecoParts, light: string, dark: string): void {
  const passes: [number, string][] = [
    [parts.under, dark],
    [parts.lw, light],
  ];
  passes.forEach(([w, c], pass) => {
    for (const l of parts.lines) strokePath(ctx, ptPath(l, false), w, c, false);
    for (const t of parts.tris) {
      const path = ptPath(t, true);
      if (pass === 1) {
        ctx.fillStyle = c;
        ctx.fill(path);
      }
      strokePath(ctx, path, w, c, false);
    }
    ctx.fillStyle = c;
    for (const d of parts.dots) {
      ctx.beginPath();
      ctx.arc(d.x, d.y, d.r + (pass === 0 ? parts.under / 2 : 0), 0, Math.PI * 2);
      ctx.fill();
    }
  });
}

function drawDecoV2(p: Pen, parts: DecoParts, light: string, dark: string): void {
  const { ctx } = p;
  const C = ART.contact;
  for (const l of parts.lines) tube(p, ptPath(l, false), parts.lw, light, 1, { color: dark, width: parts.under });
  for (const t of parts.tris) {
    const path = ptPath(t, true);
    const pts = t.map((q) => [q.x, q.y] as P2);
    const sh = bboxShape(path, pts);
    const hm = (sh.hw + sh.hh) / 2;
    contactShadow(p, path, C.dxU * hm * 0.1, C.dyU * hm * 0.1, C.blurU * hm * 0.12, C.color, C.alpha, parts.under);
    strokePath(ctx, path, parts.under, dark);
    const mc = materialColors(light);
    const g = ctx.createLinearGradient(sh.cx - sh.hw, sh.cy - sh.hh, sh.cx + sh.hw, sh.cy + sh.hh);
    g.addColorStop(0, mc.hi);
    g.addColorStop(0.55, mc.base);
    g.addColorStop(1, mc.lo);
    ctx.fillStyle = g;
    ctx.fill(path);
    strokePath(ctx, path, parts.lw, g);
  }
  for (const d of parts.dots) {
    ctx.fillStyle = dark;
    ctx.beginPath();
    ctx.arc(d.x, d.y, d.r + parts.under / 2, 0, Math.PI * 2);
    ctx.fill();
    const sh = circleShape(d.x, d.y, d.r);
    fillBase(p, sh, light);
    specDot(p, sh);
  }
}

// ================================================================ nivåer: prickar, ansikte

function drawSpots(ctx: Ctx, r: number, n: number, style: SpotStyle, c: string, v2: boolean, hi: string): void {
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2 + 0.7;
    const d = (0.46 + (i % 2 === 0 ? 0.16 : -0.16)) * r;
    const x = Math.cos(a) * d;
    const y = Math.sin(a) * d;
    const dot = (rr: number, fill: string): void => {
      ctx.fillStyle = fill;
      ctx.beginPath();
      ctx.arc(x, y, rr, 0, Math.PI * 2);
      ctx.fill();
    };
    const line = (x0: number, y0: number, x1: number, y1: number, w: number, s: string): void => {
      ctx.lineWidth = w;
      ctx.strokeStyle = s;
      ctx.lineCap = 'butt';
      ctx.beginPath();
      ctx.moveTo(x0, y0);
      ctx.lineTo(x1, y1);
      ctx.stroke();
    };
    switch (style) {
      case 'dot':
        if (v2) {
          ctx.save();
          ctx.translate(0, ART.dimple.lipDyR * r);
          dot(0.11 * r, rgba(hi, ART.dimple.lipAlpha));
          ctx.restore();
          dot(0.11 * r, rgba(c, ART.dimple.alpha));
        } else dot(0.11 * r, rgba(c, 0.32));
        break;
      case 'crater':
        if (v2) {
          ctx.save();
          ctx.translate(0, ART.dimple.lipDyR * r);
          ctx.lineWidth = 0.045 * r;
          ctx.strokeStyle = rgba(hi, ART.dimple.lipAlpha);
          ctx.beginPath();
          ctx.arc(x, y, 0.12 * r, 0.1 * Math.PI, 0.9 * Math.PI);
          ctx.stroke();
          ctx.restore();
        }
        dot(0.12 * r, rgba(c, 0.18));
        ctx.lineWidth = 0.045 * r;
        ctx.strokeStyle = rgba(c, 0.45);
        ctx.beginPath();
        ctx.arc(x, y, 0.12 * r, 0, Math.PI * 2);
        ctx.stroke();
        break;
      case 'flake':
        for (let kk = 0; kk < 3; kk++) {
          const b = (kk * Math.PI) / 3;
          const dx = Math.cos(b) * 0.1 * r;
          const dy = Math.sin(b) * 0.1 * r;
          line(x - dx, y - dy, x + dx, y + dy, Math.max(1, 0.035 * r), rgba(c, 0.45));
        }
        break;
      case 'sprinkle': {
        const w = Math.max(1.5, 0.07 * r);
        const dx = Math.cos(a + 0.9) * 0.1 * r;
        const dy = Math.sin(a + 0.9) * 0.1 * r;
        ctx.lineWidth = w;
        ctx.strokeStyle = rgba(c, 0.5);
        ctx.lineCap = 'round';
        ctx.beginPath();
        ctx.moveTo(x - dx, y - dy);
        ctx.lineTo(x + dx, y + dy);
        ctx.stroke();
        break;
      }
      case 'crack': {
        const ca = Math.cos(a);
        const sa = Math.sin(a);
        const zz = [
          [-0.12, 0.04],
          [-0.04, -0.04],
          [0.04, 0.04],
          [0.12, -0.04],
        ].map(([px, py]) => [x + (px * ca - py * sa) * r, y + (px * sa + py * ca) * r] as P2);
        ctx.lineWidth = Math.max(1, 0.04 * r);
        ctx.strokeStyle = rgba(c, 0.45);
        ctx.lineCap = 'butt';
        ctx.stroke(polyPath(zz, false));
        break;
      }
    }
  }
}

/**
 * Ansiktet, 1:1 med textures.ts drawFace (butt-ändar, samma mått). `ink` = stil för alla drag,
 * `accent` = tunga/kinder (null = hoppa över, används i läpp-passet).
 */
function drawFace(ctx: Ctx, r: number, face: Face, ink: string, accent: string | null, lw0?: number): void {
  const dx = 0.34 * r;
  const ey = -0.1 * r;
  const er = 0.115 * r;
  const my = 0.26 * r;
  const lw = lw0 ?? Math.max(1.6, 0.075 * r);
  const P = Math.PI;
  const fillC = (x: number, y: number, rr: number): void => {
    ctx.beginPath();
    ctx.arc(x, y, rr, 0, P * 2);
    ctx.fill();
  };
  const fillE = (x: number, y: number, w: number, h: number): void => {
    ctx.beginPath();
    ctx.ellipse(x, y, w / 2, h / 2, 0, 0, P * 2);
    ctx.fill();
  };
  const arcS = (x: number, y: number, rr: number, a0: number, a1: number): void => {
    ctx.beginPath();
    ctx.arc(x, y, rr, a0, a1, false);
    ctx.stroke();
  };
  const sector = (x: number, y: number, rr: number, a0: number, a1: number): void => {
    ctx.beginPath();
    ctx.moveTo(x, y);
    ctx.arc(x, y, rr, a0, a1, false);
    ctx.closePath();
    ctx.fill();
  };
  const lineS = (x0: number, y0: number, x1: number, y1: number): void => {
    ctx.beginPath();
    ctx.moveTo(x0, y0);
    ctx.lineTo(x1, y1);
    ctx.stroke();
  };
  const dots = (): void => {
    fillC(-dx, ey, er);
    fillC(dx, ey, er);
  };
  ctx.fillStyle = ink;
  ctx.strokeStyle = ink;
  ctx.lineWidth = lw;
  ctx.lineCap = 'butt';
  ctx.lineJoin = 'miter';
  switch (face) {
    case 'dot':
      dots();
      break;
    case 'smile':
      dots();
      arcS(0, 0.02 * r, 0.34 * r, 0.15 * P, 0.85 * P);
      break;
    case 'wink':
      lineS(-dx - 0.13 * r, ey, -dx + 0.13 * r, ey);
      fillC(dx, ey, er);
      arcS(0, 0.02 * r, 0.28 * r, 0.2 * P, 0.8 * P);
      break;
    case 'open':
      dots();
      fillE(0, my, 0.3 * r, 0.38 * r);
      break;
    case 'grin':
      dots();
      sector(0, 0, 0.42 * r, 0.12 * P, 0.88 * P);
      if (accent) {
        ctx.fillStyle = accent;
        fillC(0, 0.28 * r, 0.13 * r);
      }
      break;
    case 'sleepy':
      arcS(-dx, ey, 0.16 * r, 0.05 * P, 0.95 * P);
      arcS(dx, ey, 0.16 * r, 0.05 * P, 0.95 * P);
      lineS(-0.12 * r, my, 0.12 * r, my);
      break;
    case 'starry':
      for (const s of [-1, 1]) {
        const ex = s * dx;
        for (let i = 0; i < 4; i++) {
          const a = (i / 4) * P;
          lineS(ex - Math.cos(a) * 0.17 * r, ey - Math.sin(a) * 0.17 * r, ex + Math.cos(a) * 0.17 * r, ey + Math.sin(a) * 0.17 * r);
        }
      }
      sector(0, 0, 0.36 * r, 0.15 * P, 0.85 * P);
      break;
    case 'awe':
      for (const s of [-1, 1]) {
        ctx.beginPath();
        ctx.arc(s * dx, ey, 0.17 * r, 0, P * 2);
        ctx.stroke();
        fillC(s * dx, ey, 0.075 * r);
      }
      fillE(0, my, 0.2 * r, 0.28 * r);
      break;
    case 'cool':
      ctx.lineWidth = 0.17 * r;
      lineS(-0.44 * r, -0.12 * r, 0.44 * r, -0.05 * r);
      ctx.lineWidth = lw;
      arcS(0.06 * r, 0.02 * r, 0.24 * r, 0.15 * P, 0.85 * P);
      break;
    case 'happy':
      arcS(-dx, ey, 0.16 * r, 1.15 * P, 1.85 * P);
      arcS(dx, ey, 0.16 * r, 1.15 * P, 1.85 * P);
      arcS(0, 0.02 * r, 0.22 * r, 0.15 * P, 0.85 * P);
      break;
    case 'joy':
      arcS(-dx, ey, 0.17 * r, 1.15 * P, 1.85 * P);
      arcS(dx, ey, 0.17 * r, 1.15 * P, 1.85 * P);
      sector(0, 0.06 * r, 0.34 * r, 0, P);
      break;
    case 'angry':
      ctx.lineWidth = 0.13 * r;
      lineS(-0.48 * r, -0.26 * r, -0.18 * r, -0.04 * r);
      lineS(0.48 * r, -0.26 * r, 0.18 * r, -0.04 * r);
      ctx.stroke(polyPath(quadPts([-0.3 * r, my], [-0.15 * r, my - 0.16 * r], [0, my], 10), false));
      ctx.stroke(polyPath(quadPts([0, my], [0.15 * r, my + 0.16 * r], [0.3 * r, my], 10), false));
      break;
  }
}

/** Kinderna på 'joy' (v1: platt accent2 α 0,55; v2: mjuk rodnad). */
function joyCheeks(ctx: Ctx, r: number, accent: string, v2: boolean): void {
  for (const s of [-1, 1]) {
    if (v2) softEllipse(ctx, s * 0.52 * r, 0.1 * r, 0.17 * r, 0.17 * r, 0, accent, ART.cheek.alpha);
    else {
      ctx.fillStyle = rgba(accent, 0.55);
      ctx.beginPath();
      ctx.arc(s * 0.52 * r, 0.1 * r, 0.15 * r, 0, Math.PI * 2);
      ctx.fill();
    }
  }
}

// ================================================================ publikt API

const clampDpr = (d: number | undefined): number => Math.max(1, Math.min(ART.maxDpr, d ?? 1));

/** Storlek och origin för en avatartextur. Anropa före createCanvas. */
export function avatarBakeInfo(displayPx: number, dpr = 1, mode: ArtMode = 'v2'): BakeInfo {
  const pad = mode === 'v2' ? PAD_V2 : PAD_V1;
  const full = AVATAR_BOX + pad * 2;
  const d = clampDpr(dpr);
  const logical = Math.ceil((full * displayPx) / AVATAR_BOX);
  return { px: Math.ceil(logical * d), dpr: d, logical, originY: (pad + AVATAR_BOX / 2 + AVATAR_GRIP[1]) / full };
}

/** Halva texturens sida i logiska px (samma pad som textures.ts + plats för drop shadow i v2). */
function levelPad(skin: SetLevelSkin, r: number, mode: ArtMode): number {
  const extent = Math.max(1 + skin.glow, decoExtent(skin.deco ?? 'none'));
  const base = Math.ceil(r * extent + Math.max(3, 0.12 * r));
  if (mode === 'v1') return base;
  const D = ART.drop.level;
  return Math.max(base, Math.ceil(r * decoExtent(skin.deco ?? 'none') + (D.dyR + D.blurR * 1.5) * r + 2));
}

/** Storlek för en nivåtextur. dpr sänks för stora nivåer så att sidan ≤ ART.maxTexSide. */
export function levelBakeInfo(skin: SetLevelSkin, radius: number, dpr = 1, mode: ArtMode = 'v2'): BakeInfo {
  const logical = levelPad(skin, radius, mode) * 2;
  const d = Math.min(clampDpr(dpr), Math.max(1, ART.maxTexSide / logical));
  return { px: Math.ceil(logical * d), dpr: d, logical, originY: 0.5 };
}

/**
 * Ritar en kompis i en ny textur (identitetstransform). displayPx = boxens bredd på skärmen
 * (40 i spel, 80 på scenen, 112 i öppningen). Figuren centreras i avatarBakeInfo(...).px.
 */
export function renderAvatar(ctx: Ctx, def: AvatarDef, displayPx: number, opts: AvatarOpts = {}): BakeInfo {
  const mode: ArtMode = opts.sil ? 'v1' : opts.mode ?? 'v2';
  const info = avatarBakeInfo(displayPx, opts.dpr, mode);
  const k = (displayPx / AVATAR_BOX) * info.dpr;
  const c = info.px / 2;
  const part = opts.part ?? 'full';
  const ops = [
    ...(part !== 'pupils' ? def.draw : []),
    ...(part !== 'body' ? def.cosmetic.look?.pupils ?? [] : []),
  ].filter((op) => !(opts.sil && op.noSil));

  const paint = (target: Ctx, v2: boolean): void => {
    const pen: Pen = { ctx: target, k, sil: !!opts.sil, v2 };
    target.save();
    target.setTransform(k, 0, 0, k, c, c);
    for (const op of ops) (v2 ? avatarOpV2 : avatarOpV1)(pen, op);
    drawRombs(target, opts.rombs ?? 0, v2);
    target.restore();
  };

  if (mode === 'v1') {
    paint(ctx, false);
    return info;
  }
  const layer = scratchCanvas(opts, info.px, info.px);
  paint(layer.ctx, true);
  ctx.save();
  if (opts.shadow !== false) {
    const D = ART.drop.avatar;
    ctx.shadowColor = rgba(ART.drop.color, D.alpha);
    ctx.shadowBlur = D.blurU * k;
    ctx.shadowOffsetX = D.dxU * k;
    ctx.shadowOffsetY = D.dyU * k;
  }
  ctx.drawImage(layer.canvas, 0, 0);
  resetShadow(ctx);
  ctx.restore();
  return info;
}

function drawRombs(ctx: Ctx, n: number, v2: boolean): void {
  const R = AVATAR_UI.slapparen.romb;
  for (let i = 0; i < n; i++) {
    const x = R.x;
    const y = R.y + i * R.stepY;
    const path = polyPath(
      [
        [x, y - R.h / 2],
        [x + R.w / 2, y],
        [x, y + R.h / 2],
        [x - R.w / 2, y],
      ],
      true,
    );
    if (v2) {
      const g = ctx.createLinearGradient(x - R.w / 2, y - R.h / 2, x + R.w / 2, y + R.h / 2);
      g.addColorStop(0, WHITE);
      g.addColorStop(1, tone(R.fill, -14));
      ctx.fillStyle = g;
    } else ctx.fillStyle = R.fill;
    ctx.fill(path);
    strokePath(ctx, path, R.edgeW, R.edge, false);
    ctx.lineWidth = R.w * 0.12;
    ctx.strokeStyle = rgba(WHITE, 0.8);
    ctx.beginPath();
    ctx.moveTo(x - R.w * 0.16, y - R.h * 0.06);
    ctx.lineTo(x, y - R.h * 0.28);
    ctx.stroke();
  }
}

/**
 * Ritar en nivå (Glimtarna eller vilket set som helst) centrerad i levelBakeInfo(...).px.
 * `radius` = kroppens radie i logiska px (LEVELS[i].radius). Siluett: vit kropp + dekor.
 */
export function renderLevel(ctx: Ctx, skin: SetLevelSkin, radius: number, opts: LevelOpts = {}): BakeInfo {
  const mode: ArtMode = opts.sil ? 'v1' : opts.mode ?? 'v2';
  const info = levelBakeInfo(skin, radius, opts.dpr, mode);
  const k = info.dpr;
  const c = info.px / 2;
  const r = radius;
  const deco = skin.deco ?? 'none';
  const style = opts.spotStyle ?? 'dot';
  const accent2 = THEME.palette.accent2;

  if (opts.sil) {
    ctx.save();
    ctx.setTransform(k, 0, 0, k, c, c);
    drawDecoV1(ctx, decoParts(deco, r, 'back'), WHITE, WHITE);
    drawDecoV1(ctx, decoParts(deco, r, 'front'), WHITE, WHITE);
    ctx.fillStyle = WHITE;
    ctx.beginPath();
    ctx.arc(0, 0, r, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
    return info;
  }

  if (mode === 'v1') {
    ctx.save();
    ctx.setTransform(k, 0, 0, k, c, c);
    for (const [m, a] of [
      [1, 0.06],
      [0.66, 0.1],
      [0.33, 0.14],
    ] as const) {
      ctx.fillStyle = rgba(skin.color, a);
      ctx.beginPath();
      ctx.arc(0, 0, r * (1 + m * skin.glow), 0, Math.PI * 2);
      ctx.fill();
    }
    drawDecoV1(ctx, decoParts(deco, r, 'back'), skin.color, skin.color2);
    ctx.fillStyle = skin.color;
    ctx.beginPath();
    ctx.arc(0, 0, r, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = rgba(WHITE, 0.2);
    ctx.beginPath();
    ctx.ellipse(0, -0.44 * r, 0.56 * r, 0.28 * r, 0, 0, Math.PI * 2);
    ctx.fill();
    if (skin.ring) {
      ctx.lineWidth = 0.08 * r;
      ctx.strokeStyle = rgba(skin.color2, 0.45);
      ctx.beginPath();
      ctx.arc(0, 0, 0.72 * r, 0, Math.PI * 2);
      ctx.stroke();
    }
    if (skin.spots) drawSpots(ctx, r, skin.spots, style, skin.color2, false, WHITE);
    ctx.lineWidth = Math.max(2, 0.09 * r);
    ctx.strokeStyle = skin.color2;
    ctx.beginPath();
    ctx.arc(0, 0, r, 0, Math.PI * 2);
    ctx.stroke();
    drawDecoV1(ctx, decoParts(deco, r, 'front'), skin.color, skin.color2);
    drawFace(ctx, r, skin.face, INK, accent2);
    if (skin.face === 'joy') joyCheeks(ctx, r, accent2, false);
    ctx.restore();
    return info;
  }

  // ---------------------------------------------------------------- v2
  const mc = materialColors(skin.color);
  const lw = Math.max(2, 0.09 * r);

  // 1. HALO direkt på målet (ingen drop shadow på glöden): en mjuk radial.
  ctx.save();
  ctx.setTransform(k, 0, 0, k, c, c);
  const H = ART.halo;
  const outer = r * (1 + skin.glow);
  const hg = ctx.createRadialGradient(0, 0, r * 0.9, 0, 0, outer);
  hg.addColorStop(0, rgba(skin.color, H.alphaInner));
  hg.addColorStop(H.mid, rgba(skin.color, H.alphaMid));
  hg.addColorStop(1, rgba(skin.color, 0));
  ctx.fillStyle = hg;
  ctx.beginPath();
  ctx.arc(0, 0, outer, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();

  const layer = scratchCanvas(opts, info.px, info.px);
  const L = layer.ctx;
  const pen: Pen = { ctx: L, k, sil: false, v2: true };
  L.save();
  L.setTransform(k, 0, 0, k, c, c);

  // 1,5. Dekor bakom kroppen.
  drawDecoV2(pen, decoParts(deco, r, 'back'), skin.color, skin.color2);

  // 2. KROPP: kontaktskugga på bakre dekor, radiell basgradient.
  const body = circleShape(0, 0, r);
  contactShadow(pen, body.path, 0, 0.04 * r, 0.08 * r, ART.contact.color, ART.contact.alpha);
  fillBase(pen, body, skin.color);

  // 4. RING som graverad fåra.
  if (skin.ring) {
    const G = ART.groove;
    L.save();
    L.clip(body.path);
    L.lineWidth = 0.08 * r * G.lightW;
    L.strokeStyle = rgba(mc.hi, G.lightAlpha);
    L.beginPath();
    L.arc(0, G.lightDyR * r, 0.72 * r, 0.05 * Math.PI, 0.95 * Math.PI);
    L.stroke();
    L.restore();
    L.lineWidth = 0.08 * r;
    L.strokeStyle = rgba(skin.color2, G.darkAlpha);
    L.beginPath();
    L.arc(0, 0, 0.72 * r, 0, Math.PI * 2);
    L.stroke();
  }

  // 5. PRICKAR som gropar.
  if (skin.spots) drawSpots(L, r, skin.spots, style, skin.color2, true, mc.hi);

  // Inre skugga + kantljus.
  shadeAndRim(pen, body, skin.color, lw / 2);

  // 3. TOPPLJUS: samma ellips som v1, mjuk. Plus hård prick.
  softEllipse(L, 0, -0.44 * r, 0.56 * r, 0.28 * r, 0, WHITE, ART.spec.levelSoftAlpha);
  specDot(pen, body);

  // 6. KONTUR: tjockare nedtill (innerkanten flyttad uppåt), alpha/ljushet efter ljuset.
  const ring = new Path2D();
  ring.arc(0, 0, r + lw / 2, 0, Math.PI * 2);
  ring.moveTo(r - lw / 2, -ART.edge.levelWeight * lw * 0.5);
  ring.arc(0, -ART.edge.levelWeight * lw * 0.5, r - lw / 2, 0, Math.PI * 2);
  L.fillStyle = edgeStyle(pen, { ...body, hw: r + lw, hh: r + lw }, skin.color2, 1);
  L.fill(ring, 'evenodd');

  // 7. DEKOR framför.
  drawDecoV2(pen, decoParts(deco, r, 'front'), skin.color, skin.color2);

  // 8. ANSIKTE: ljus underläpp (source-atop) + platt ink. Formen = v1.
  L.save();
  L.globalCompositeOperation = 'source-atop';
  L.translate(0, ART.face.lipDyR * r);
  drawFace(L, r, skin.face, rgba(ART.face.lipColor, ART.face.lipAlpha), null);
  L.restore();
  drawFace(L, r, skin.face, INK, accent2);
  if (skin.face === 'joy') joyCheeks(L, r, accent2, true);
  L.restore();

  // 7. DROP SHADOW: hela lagret på målet.
  ctx.save();
  if (opts.shadow !== false) {
    const D = ART.drop.level;
    ctx.shadowColor = rgba(ART.drop.color, D.alpha);
    ctx.shadowBlur = D.blurR * r * k;
    ctx.shadowOffsetX = D.dxR * r * k;
    ctx.shadowOffsetY = D.dyR * r * k;
  }
  ctx.drawImage(layer.canvas, 0, 0);
  resetShadow(ctx);
  ctx.restore();
  return info;
}

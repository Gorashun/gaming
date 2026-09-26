/**
 * buttonArt.ts – referensrenderare för knappkomponenten (UI.md §16.3, `BUTTON_STYLE` i data/startUi.ts).
 *
 * Ren TS + Canvas2D, ingen Phaser. Ritar bara YTAN (skugga, glöd-ring, gradient, inre läpp, reflex, kant).
 * Ikon, etikett och badge läggs ovanpå i scenen, så att samma bakade yta räcker för alla texter och språk.
 *
 * Bakas en gång per (variant, läge, w, h, dpr) till en CanvasTexture, aldrig per frame. Visa med
 * setScale(1 / info.dpr) och origin 0,5 – ytans centrum ligger alltid mitt i texturen.
 * Nyckelförslag: `btn-{variant}-{state}-{w}x{h}@{dpr}`. Start v2 behöver 3 × 2 lägen för kort,
 * 2 för SPELA och 2 för den runda: totalt ≈ 0,6 MB vid dpr 2.
 */

import { BUTTON_STYLE, type ButtonLook, type ButtonState, type ButtonVariant } from '../data/startUi';

type Ctx = CanvasRenderingContext2D | OffscreenCanvasRenderingContext2D;

export interface ButtonBakeInfo {
  /** Texturens storlek i enhetspixlar. */
  readonly pxW: number;
  readonly pxH: number;
  /** Marginal runt ytan i logiska px (skugga och ring). */
  readonly pad: number;
  readonly dpr: number;
}

function radiusOf(variant: ButtonVariant, h: number): number {
  const r = BUTTON_STYLE[variant].radius;
  return r === 'pill' ? h / 2 : r;
}

/** Marginal som rymmer glöd-ring och skugga i alla lägen (samma för alla lägen, så att texturerna kan bytas rakt av). */
function padOf(variant: ButtonVariant): number {
  let p = 2;
  for (const look of Object.values(BUTTON_STYLE[variant].looks) as ButtonLook[]) {
    p = Math.max(p, look.ring.w + look.edgeW, look.shadow.blur + look.shadow.dy + 2);
  }
  return Math.ceil(p);
}

export function buttonBakeInfo(variant: ButtonVariant, w: number, h: number, dpr = 1): ButtonBakeInfo {
  const pad = padOf(variant);
  const d = Math.max(1, Math.min(3, dpr));
  return { pxW: Math.ceil((w + pad * 2) * d), pxH: Math.ceil((h + pad * 2) * d), pad, dpr: d };
}

function roundRect(ctx: Ctx, x: number, y: number, w: number, h: number, r: number): void {
  const rr = Math.max(0, Math.min(r, w / 2, h / 2));
  ctx.moveTo(x + rr, y);
  ctx.arcTo(x + w, y, x + w, y + h, rr);
  ctx.arcTo(x + w, y + h, x, y + h, rr);
  ctx.arcTo(x, y + h, x, y, rr);
  ctx.arcTo(x, y, x + w, y, rr);
  ctx.closePath();
}

function rgba(hex: string, a: number): string {
  if (hex.startsWith('rgba')) return hex;
  const n = parseInt(hex.replace('#', ''), 16);
  return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${a})`;
}

/**
 * Ritar knappytan centrerad i en ny textur med storleken buttonBakeInfo(...).
 * `ctx` ska ha identitetstransform. w/h = ytans logiska storlek (utan ring och skugga).
 */
export function renderButton(ctx: Ctx, variant: ButtonVariant, state: ButtonState, w: number, h: number, dpr = 1): ButtonBakeInfo {
  const info = buttonBakeInfo(variant, w, h, dpr);
  const L = BUTTON_STYLE[variant].looks[state];
  const r = radiusOf(variant, h);
  const x = info.pad;
  const y = info.pad;

  ctx.save();
  ctx.setTransform(info.dpr, 0, 0, info.dpr, 0, 0);

  const shape = (): void => {
    ctx.beginPath();
    roundRect(ctx, x, y, w, h, r);
  };

  // 1. Glöd-ring utanför kanten.
  if (L.ring.w > 0 && L.ring.alpha > 0) {
    ctx.beginPath();
    const o = L.ring.w / 2 + L.edgeW / 2;
    roundRect(ctx, x - o, y - o, w + o * 2, h + o * 2, r + o);
    ctx.lineWidth = L.ring.w;
    ctx.strokeStyle = rgba(L.ring.color, L.ring.alpha);
    ctx.stroke();
  }

  // 2. Yta med gradient och mjuk skugga.
  const g = ctx.createLinearGradient(0, y, 0, y + h);
  g.addColorStop(0, L.face[0]);
  g.addColorStop(L.midStop, L.face[1]);
  g.addColorStop(1, L.face[2]);
  ctx.save();
  if (L.shadow.alpha > 0) {
    ctx.shadowColor = `rgba(0,0,0,${L.shadow.alpha})`;
    ctx.shadowBlur = L.shadow.blur * info.dpr;
    ctx.shadowOffsetY = L.shadow.dy * info.dpr;
  }
  shape();
  ctx.fillStyle = g;
  ctx.fill();
  ctx.restore();

  // 3. Inre läpp: skuggan av "utsidan" förskjuten uppåt, klippt till formen (CSS inset 0 -dy 0).
  if (L.inset.dy > 0 && L.inset.alpha > 0) {
    ctx.save();
    shape();
    ctx.clip();
    ctx.beginPath();
    ctx.rect(x - 4, y - 4, w + 8, h + 8);
    roundRect(ctx, x, y - L.inset.dy, w, h, r);
    ctx.fillStyle = `rgba(0,0,0,${L.inset.alpha})`;
    ctx.fill('evenodd');
    ctx.restore();
  }

  // 4. Blank reflex i övre delen: vit, mjuk, avtar nedåt.
  if (L.gloss.alpha > 0) {
    ctx.save();
    shape();
    ctx.clip();
    const gh = h * L.gloss.h;
    const inset = L.gloss.inset;
    const gg = ctx.createLinearGradient(0, y, 0, y + gh);
    gg.addColorStop(0, `rgba(255,255,255,${L.gloss.alpha})`);
    gg.addColorStop(1, 'rgba(255,255,255,0)');
    ctx.beginPath();
    if (inset > 0) roundRect(ctx, x + inset, y + L.edgeW + 1, w - inset * 2, gh, Math.min(r, gh / 2));
    else ctx.rect(x, y, w, gh);
    ctx.fillStyle = gg;
    ctx.fill();
    ctx.restore();
  }

  // 5. Kant, innanför ytans bounds.
  ctx.beginPath();
  const e = L.edgeW / 2;
  roundRect(ctx, x + e, y + e, w - L.edgeW, h - L.edgeW, Math.max(0, r - e));
  ctx.lineWidth = L.edgeW;
  ctx.strokeStyle = L.edge;
  ctx.setLineDash(L.edgeDash ? [...L.edgeDash] : []);
  ctx.stroke();
  ctx.setLineDash([]);

  ctx.restore();
  return info;
}

/**
 * Badge: guldprick med mörk ring. Centrum relativt ytans övre högra hörn (BUTTON_STYLE[v].badge).
 * Hjälpfunktion för mockup och för den som vill baka pricken som egen textur.
 */
export function renderBadge(ctx: Ctx, cx: number, cy: number, d: number, ring: number, fill: string, ringColor: string): void {
  ctx.beginPath();
  ctx.arc(cx, cy, d / 2 + ring, 0, Math.PI * 2);
  ctx.fillStyle = ringColor;
  ctx.fill();
  ctx.beginPath();
  ctx.arc(cx, cy, d / 2, 0, Math.PI * 2);
  const g = ctx.createRadialGradient(cx - d * 0.15, cy - d * 0.2, 0, cx, cy, d / 2);
  g.addColorStop(0, '#FFF3C4');
  g.addColorStop(0.55, fill);
  g.addColorStop(1, '#E0AE2E');
  ctx.fillStyle = g;
  ctx.fill();
}

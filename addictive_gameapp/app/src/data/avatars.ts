/**
 * avatars.ts – Kompisar v1.2 (DESIGN §14, UI.md §13). Ersätter `avatars.stub.ts`.
 *
 * Ren data. Får INTE importera Phaser. Allt ritas med primitiver (samma språk som
 * `BackdropOp` i themes.ts) i en 56×56-box, origo i boxens mitt, y nedåt.
 * GREPPUNKTEN (där figuren håller det hängande objektet) är (0, 24) i boxen.
 * I Phaser: bakad textur 56×56 · skala, `setOrigin(0.5, AVATAR_ORIGIN_Y)`, så
 * position = greppunkten i världen och all rotation/squash sker kring greppet.
 *
 * Regler:
 *  - Raritetsfärger: aldrig rött (rött = fara). Raritet bärs ALLTID också av pärlor (1–6)
 *    och grupp i boken, aldrig av färg ensam.
 *  - Inga blink: alla loopar ≤1 Hz, inga vitblixtar, ingen ljusstyrkeväxling av figuren.
 *  - Vanlig/ovanlig: bara kosmetik. Sällsynt+: `ability` (programmeraren implementerar beteendet).
 */

import type { LocalizedName } from '../systems/i18n';

// ---------------------------------------------------------------- typer (stubbens form + tillägg)

export type Rarity = 'common' | 'uncommon' | 'rare' | 'epic' | 'legendary' | 'mythic';

type P2 = readonly [number, number];

/** Gemensam färgsättning. edge = kontur ovanpå fyllningen (eller underlag för streck). */
interface Paint {
  readonly color: string;
  /** 0..1, default 1 */
  readonly alpha?: number;
  /** Mörk (ibland ljus) kontur. circle/ellipse/poly: strokas OVANPÅ fyllningen. curve/line: underlag, bredd + 2·edgeW. */
  readonly edge?: string;
  /** Default EDGE_W (2,8 box-enheter) */
  readonly edgeW?: number;
  /** Tas inte med i siluetten (gnistor, glöd, ekon). */
  readonly noSil?: boolean;
}

/**
 * Ritprimitiv i 56-box-enheter. Ordning = ritordning.
 *  - circle/ellipse/poly: `stroke` satt ⇒ bara streck med den bredden (ingen fyllning).
 *  - ellipse.rot i radianer (rita som 24-punkts polygon).
 *  - poly.open + stroke ⇒ polylinje. Runda ändar och hörn överallt.
 *  - curve = kvadratisk bezier (streck), line = rakt streck.
 *  - scatter = seedad mulberry32 som i background.ts (x,y = övre vänstra hörnet).
 */
export type AvatarOp =
  | ({ readonly op: 'circle'; readonly x: number; readonly y: number; readonly r: number; readonly stroke?: number } & Paint)
  | ({
      readonly op: 'ellipse';
      readonly x: number;
      readonly y: number;
      readonly w: number;
      readonly h: number;
      readonly rot?: number;
      readonly stroke?: number;
    } & Paint)
  | ({ readonly op: 'poly'; readonly pts: readonly P2[]; readonly stroke?: number; readonly open?: boolean } & Paint)
  | ({ readonly op: 'curve'; readonly from: P2; readonly ctrl: P2; readonly to: P2; readonly width: number } & Paint)
  | ({ readonly op: 'line'; readonly from: P2; readonly to: P2; readonly width: number } & Paint)
  | {
      readonly op: 'scatter';
      readonly seed: number;
      readonly count: number;
      readonly x: number;
      readonly y: number;
      readonly w: number;
      readonly h: number;
      readonly rMin: number;
      readonly rMax: number;
      readonly color: string;
      readonly alphaMin: number;
      readonly alphaMax: number;
      readonly noSil?: boolean;
    };

/**
 * Ett tween-steg. Värden är MÅL relativt viloläget (dx/dy i box-enheter · skala, sx/sy multiplikatorer,
 * rot i grader). Utelämnat värde = vilovärdet (0 resp. 1). Ett steg med bara ms/ease = tillbaka till vila.
 * |rot| ≥ 360 = hel snurr: efter steget sätts vinkeln till 0 utan tween.
 */
export interface TweenStep {
  readonly dx?: number;
  readonly dy?: number;
  readonly sx?: number;
  readonly sy?: number;
  readonly rot?: number;
  readonly ms: number;
  readonly ease: string;
}

/** Stegen spelas i följd. loop ⇒ upprepas tills annat recept tar över (idle, danger). Loopar ≤1 Hz. */
export interface AnimRecipe {
  readonly steps: readonly TweenStep[];
  readonly loop?: boolean;
}

export interface AvatarAnims {
  /** Loop medan objektet hänger / väntar. */
  readonly idle: AnimRecipe;
  /** En gång vid drop ("kastet"). */
  readonly drop: AnimRecipe;
  /** En gång vid varje merge (hoppa över om ett merge-recept redan spelas). */
  readonly merge: AnimRecipe;
  /** En gång vid kedja ≥3. Avbryter merge. */
  readonly chain: AnimRecipe;
  /** Loop medan fara pågår. Ut: 200 ms Sine.easeOut till vila. */
  readonly danger: AnimRecipe;
}

/** Samma form som ToneDef i systems/audio.ts (strukturellt kompatibel) + delayMs. playTone(def, semitoner). */
export interface AvatarTone {
  readonly wave: 'sine' | 'triangle' | 'square' | 'sawtooth';
  readonly baseHz: number;
  readonly glideTo?: number;
  readonly attack: number;
  readonly decay: number;
  readonly gain: number;
  readonly lowpassHz?: number;
  readonly harmonicSemitones?: number;
  readonly harmonicGain?: number;
  readonly steps?: readonly number[];
  readonly stepMs?: number;
  readonly vibratoHz?: number;
  readonly vibratoCents?: number;
  readonly delayMs?: number;
}

/** Befintliga ParticleShape (themes.ts) + fem nya, geometri i AVATAR_PARTICLE_GEOM. */
export type AvatarParticle = 'dot' | 'ring' | 'shard' | 'bubble' | 'star' | 'heart' | 'note' | 'confetti' | 'drop' | 'bolt';

/** Spår efter det fallande objektet (emitteras var `everyPx` längs vägen, tills första kontakt). */
export interface TrailDef {
  readonly shape: AvatarParticle;
  /** En färg, eller flera som växlar partikel för partikel. */
  readonly tint: string | readonly string[];
  readonly everyPx: number;
  readonly lifeMs: number;
  readonly scale: readonly [number, number];
  readonly alpha: readonly [number, number];
  /** px/s², negativt = stiger */
  readonly gravityY: number;
  /** Slumpad sidodrift ±px under livstiden */
  readonly driftPx: number;
  readonly blend: 'ADD' | 'NORMAL';
}

export type GestureTrigger = 'drop' | 'land' | 'merge' | 'combo3' | 'chain' | 'record' | 'klunk' | 'newLevel';

export interface Cosmetic {
  readonly trail?: TrailDef;
  /** Byter setets partikelform vid merge (bara figurens egna partiklar, inte setets bakgrund). */
  readonly particleShape?: AvatarParticle;
  /** Hex, eller 'combo' = nyans roterar med combon (Harry), eller 'level' = objektets färg. */
  readonly particleTint?: string | 'combo' | 'level';
  /** Extra ljud ovanpå ordinarie ljud. `merge` spelas med playTone(def, combo). */
  readonly sound?: Partial<Record<GestureTrigger, AvatarTone>>;
  /** Signaturgest: extra tween-recept på en trigger (ersätter anim-receptet för den triggern). */
  readonly gesture?: { readonly on: GestureTrigger; readonly anim: AnimRecipe };
  /** Pupiller som eget lager: förskjuts max lookPx mot senast tappade objekt (Fenja). */
  readonly look?: { readonly pupils: readonly AvatarOp[]; readonly lookPx: number };
}

/** Effekt som figuren gör i öppningen och på scenen i boken (UI.md §13.3). Koordinater i box-enheter. */
export type FxCue =
  | { readonly kind: 'burst'; readonly shape: AvatarParticle; readonly tint: string | readonly string[]; readonly count: number; readonly speed: number; readonly lifeMs: number; readonly gravityY?: number }
  | { readonly kind: 'rise'; readonly shape: AvatarParticle; readonly tint: string | readonly string[]; readonly count: number; readonly risePx: number; readonly swayPx: number; readonly lifeMs: number; readonly staggerMs: number }
  | { readonly kind: 'fall'; readonly shape: AvatarParticle; readonly tint: string | readonly string[]; readonly count: number; readonly fallPx: number; readonly spreadPx: number; readonly lifeMs: number; readonly staggerMs: number }
  | { readonly kind: 'rings'; readonly color: string; readonly count: number; readonly fromR: number; readonly toR: number; readonly width: number; readonly ms: number; readonly staggerMs: number }
  | { readonly kind: 'bolts'; readonly color: string; readonly count: number; readonly len: number; readonly ms: number; readonly staggerMs: number }
  | { readonly kind: 'arc'; readonly colors: readonly string[]; readonly r: number; readonly width: number; readonly inMs: number; readonly holdMs: number; readonly outMs: number }
  | { readonly kind: 'aim'; readonly color: string; readonly len: number; readonly dotR: number; readonly ms: number }
  | { readonly kind: 'orbit'; readonly shape: AvatarParticle; readonly tint: string | readonly string[]; readonly count: number; readonly r: number; readonly turns: number; readonly ms: number };

export interface Showcase {
  /** Spelas en gång. Längd 300–1 000 ms. */
  readonly anim: AnimRecipe;
  /** Effekten startar så här långt in i gesten. */
  readonly fxAtMs: number;
  readonly fx: FxCue;
  readonly sound: AvatarTone;
}

export type AbilityParams = Readonly<Record<string, number | boolean | readonly number[]>>;

export interface Ability {
  /** Nyckel som programmeraren switchar på. Beteende enligt DESIGN §14.5 + kommentar per avatar. */
  readonly key: string;
  readonly params: { readonly I: AbilityParams; readonly II: AbilityParams; readonly III: AbilityParams };
}

export interface AvatarDef {
  readonly id: string;
  /** Visningsnamn, engelska primärt (DESIGN §15). Visas bara där text införs (bok, öppning, butik). */
  readonly names: LocalizedName;
  readonly rarity: Rarity;
  /** = RARITY.color[rarity] */
  readonly rarityColor: string;
  /** En mening: vad den ska kännas som. Visas aldrig. */
  readonly idea: string;
  readonly draw: readonly AvatarOp[];
  readonly anim: AvatarAnims;
  /** Vanlig/ovanlig bär allt här. Sällsynt+ får också ha kosmetik. */
  readonly cosmetic: Cosmetic;
  /** Sällsynt och uppåt. */
  readonly ability?: Ability;
  /** Förmågegesten: öppningen (en gång) och scenen i boken (vid tryck). */
  readonly showcase: Showcase;
}

// ---------------------------------------------------------------- raritet och uppgradering

export const RARITY = {
  order: ['common', 'uncommon', 'rare', 'epic', 'legendary', 'mythic'] as readonly Rarity[],
  /** Aldrig rött. Kontrast mot bg #0B1020: 9,1 / 12,3 / 7,7 / 7,4 / 13,6 / 10,2 :1. */
  color: {
    common: '#A9B4C8',
    uncommon: '#6EE7A0',
    rare: '#5AA9FF',
    epic: '#B98CFF',
    legendary: '#FFD75E',
    mythic: '#FF9CF0',
  } as Readonly<Record<Rarity, string>>,
  pearls: { common: 1, uncommon: 2, rare: 3, epic: 4, legendary: 5, mythic: 6 } as Readonly<Record<Rarity, number>>,
  /** Odds i procent (DESIGN §14.3), omnormeras bland rariteter med figurer kvar. */
  odds: { common: 44, uncommon: 28, rare: 16, epic: 8, legendary: 3, mythic: 1 } as Readonly<Record<Rarity, number>>,
  /** Antal per raritet (DESIGN §14.2). */
  count: { common: 16, uncommon: 12, rare: 9, epic: 6, legendary: 3, mythic: 2 } as Readonly<Record<Rarity, number>>,
  /** Mytisk ritas som regnbåge där det går (ram, pärla, ringar). `color.mythic` är reserven. */
  rainbow: ['#FF8766', '#FFD447', '#6EE7A0', '#5AA9FF', '#B98CFF', '#FF9CF0'] as readonly string[],
  /** Mörk kant till pärlor och ramar (ink). */
  edge: '#14202E',
  /** Jackpot-juice vid öppning, utan shake/zoom/hit-stop. Max 0,9. */
  juice: { common: 0.3, uncommon: 0.42, rare: 0.54, epic: 0.66, legendary: 0.78, mythic: 0.9 } as Readonly<Record<Rarity, number>>,
  /** Svenska etiketter, bara för utvecklare/föräldrasida. */
  label: { common: 'Vanlig', uncommon: 'Ovanlig', rare: 'Sällsynt', epic: 'Episk', legendary: 'Legendarisk', mythic: 'Mytisk' } as Readonly<Record<Rarity, string>>,
} as const;

/** Kumulativ XP för nivå II och III (DESIGN §14.4). */
export const UPGRADE = {
  xpII: 150,
  xpIII: 450,
  /** Kosmetik per nivå I/II/III: × antal partiklar och × spårlängd (lifeMs). */
  cosmeticParticleMul: [1, 1.15, 1.3] as readonly number[],
  cosmeticTrailMul: [1, 1.25, 1.5] as readonly number[],
} as const;

/**
 * Odds-burken: 25 pärlor fördelade efter aktuella (omnormerade) odds.
 * Varje raritet med figurer kvar får MINST en pärla (mytisk syns alltid tills den är tagen).
 * Largest remainder; överskott tas från den största gruppen. Tom pool ⇒ alla 0.
 */
export function oddsPearls(remaining: Readonly<Record<Rarity, number>>, total = 25): Record<Rarity, number> {
  const live = RARITY.order.filter((r) => remaining[r] > 0);
  const out = { common: 0, uncommon: 0, rare: 0, epic: 0, legendary: 0, mythic: 0 } as Record<Rarity, number>;
  if (live.length === 0) return out;
  const sum = live.reduce((s, r) => s + RARITY.odds[r], 0);
  const exact = live.map((r) => ({ r, v: (RARITY.odds[r] / sum) * total }));
  for (const e of exact) out[e.r] = Math.max(1, Math.floor(e.v));
  let left = total - live.reduce((s, r) => s + out[r], 0);
  const byRem = [...exact].sort((a, b) => (b.v - Math.floor(b.v)) - (a.v - Math.floor(a.v)));
  for (let i = 0; left > 0; i = (i + 1) % byRem.length, left--) out[byRem[i].r]++;
  while (left < 0) {
    const big = live.reduce((a, b) => (out[b] > out[a] ? b : a));
    out[big]--;
    left++;
  }
  return out;
}

// ---------------------------------------------------------------- ritgrammatik

export const AVATAR_BOX = 56;
/** Greppunkt i boxen och motsvarande origin för Phaser (0,5; 52/56). */
export const AVATAR_GRIP: P2 = [0, 24];
export const AVATAR_ORIGIN_Y = (AVATAR_BOX / 2 + AVATAR_GRIP[1]) / AVATAR_BOX;
const EDGE_W = 2.8;

const INK = '#14202E';
const WHITE = '#FFFFFF';
const CHEEK = '#FF8FB8';
const TONGUE = '#FF86B8';

const r2 = (v: number): number => Math.round(v * 100) / 100;

/** Ellipsbåge som punkter. Vinklar i radianer, 0 = höger, π/2 = nedåt. */
function arc(cx: number, cy: number, rx: number, ry: number, a0: number, a1: number, n = 18): P2[] {
  const out: P2[] = [];
  for (let i = 0; i <= n; i++) {
    const t = a0 + ((a1 - a0) * i) / n;
    out.push([r2(cx + Math.cos(t) * rx), r2(cy + Math.sin(t) * ry)]);
  }
  return out;
}

function roundRect(x: number, y: number, w: number, h: number, r: number): P2[] {
  const q = Math.PI / 2;
  return [
    ...arc(x + w - r, y + r, r, r, -q, 0, 4),
    ...arc(x + w - r, y + h - r, r, r, 0, q, 4),
    ...arc(x + r, y + h - r, r, r, q, 2 * q, 4),
    ...arc(x + r, y + r, r, r, 2 * q, 3 * q, 4),
  ];
}

/** Mjuk stjärna: r(θ) mellan inner och outer, `n` uddar, första udden rakt upp. */
function softStar(cx: number, cy: number, outer: number, inner: number, n: number, sharp = 1.6, steps = 60): P2[] {
  const out: P2[] = [];
  for (let i = 0; i < steps; i++) {
    const t = (i / steps) * Math.PI * 2;
    const k = Math.pow((Math.cos(n * t) + 1) / 2, sharp);
    const r = inner + (outer - inner) * k;
    out.push([r2(cx + Math.sin(t) * r), r2(cy - Math.cos(t) * r)]);
  }
  return out;
}

/** Spetsig stjärna (gnistor). */
function star(cx: number, cy: number, outer: number, inner: number, n = 4): P2[] {
  const out: P2[] = [];
  for (let i = 0; i < n * 2; i++) {
    const t = (i / (n * 2)) * Math.PI * 2;
    const r = i % 2 === 0 ? outer : inner;
    out.push([r2(cx + Math.sin(t) * r), r2(cy - Math.cos(t) * r)]);
  }
  return out;
}

function spiral(cx: number, cy: number, r0: number, r1: number, turns: number, a0 = 0, n = 40): P2[] {
  const out: P2[] = [];
  for (let i = 0; i <= n; i++) {
    const f = i / n;
    const t = a0 + f * turns * Math.PI * 2;
    const r = r0 + (r1 - r0) * f;
    out.push([r2(cx + Math.cos(t) * r), r2(cy + Math.sin(t) * r)]);
  }
  return out;
}

const mx = (pts: readonly P2[]): P2[] => pts.map(([x, y]) => [-x, y] as P2);

type Extra = { alpha?: number; edgeW?: number; noSil?: boolean };
const C = (x: number, y: number, r: number, color: string, edge?: string, o: Extra = {}): AvatarOp => ({ op: 'circle', x, y, r, color, edge, ...o });
const E = (x: number, y: number, w: number, h: number, color: string, edge?: string, rot?: number, o: Extra = {}): AvatarOp => ({
  op: 'ellipse', x, y, w, h, rot, color, edge, ...o,
});
const P = (pts: readonly P2[], color: string, edge?: string, o: Extra = {}): AvatarOp => ({ op: 'poly', pts, color, edge, ...o });
const PL = (pts: readonly P2[], width: number, color: string, o: Extra = {}): AvatarOp => ({ op: 'poly', pts, stroke: width, open: true, color, ...o });
const RING = (x: number, y: number, r: number, width: number, color: string, o: Extra = {}): AvatarOp => ({ op: 'circle', x, y, r, stroke: width, color, ...o });
const L = (from: P2, to: P2, width: number, color: string, edge?: string, o: Extra = {}): AvatarOp => ({ op: 'line', from, to, width, color, edge, ...o });
const Q = (from: P2, ctrl: P2, to: P2, width: number, color: string, edge?: string, o: Extra = {}): AvatarOp => ({
  op: 'curve', from, ctrl, to, width, color, edge, ...o,
});

/** Topp-ljus: vit ellips, alpha 0,24 (samma idé som objektens steg 3). */
const shine = (x: number, y: number, w: number, h: number, rot = 0): AvatarOp => E(x, y, w, h, WHITE, undefined, rot, { alpha: 0.26 });

type EyeKind = 'dot' | 'big' | 'happy' | 'sleepy' | 'lash';

/**
 * Ögon. Avatarer har ALLTID ett vitt ljusglint i ögat (objekten har det aldrig) – så skiljer man
 * "kompis" från "glimt" även i ögonvrån.
 */
function eyes(kind: EyeKind, xl: number, xr: number, y: number, s = 1, ink = INK): AvatarOp[] {
  const out: AvatarOp[] = [];
  for (const x of [xl, xr]) {
    if (kind === 'dot' || kind === 'lash') {
      out.push(C(x, y, 2.9 * s, ink), C(x + 1 * s, y - 1 * s, 1 * s, WHITE));
      if (kind === 'lash') out.push(L([x + (x < 0 ? -2.2 : 2.2) * s, y - 2 * s], [x + (x < 0 ? -4 : 4) * s, y - 3.6 * s], 1.4 * s, ink));
    } else if (kind === 'big') {
      out.push(C(x, y, 4.4 * s, WHITE, ink, { edgeW: 1.4 }), C(x + 0.6 * s, y + 0.5 * s, 2.5 * s, ink), C(x + 1.4 * s, y - 0.4 * s, 0.9 * s, WHITE));
    } else if (kind === 'happy') {
      out.push(Q([x - 3 * s, y + 1 * s], [x, y - 3.4 * s], [x + 3 * s, y + 1 * s], 2.1 * s, ink));
    } else {
      out.push(Q([x - 3 * s, y - 0.6 * s], [x, y + 2.6 * s], [x + 3 * s, y - 0.6 * s], 2.1 * s, ink));
    }
  }
  return out;
}

type MouthKind = 'smile' | 'open' | 'o' | 'grin' | 'cat' | 'flat' | 'smirk';

function mouth(kind: MouthKind, x: number, y: number, s = 1, ink = INK): AvatarOp[] {
  switch (kind) {
    case 'smile':
      return [Q([x - 3.6 * s, y - 0.4 * s], [x, y + 3.4 * s], [x + 3.6 * s, y - 0.4 * s], 2 * s, ink)];
    case 'open':
      return [E(x, y + 0.6 * s, 5 * s, 5.6 * s, ink), E(x, y + 2 * s, 3 * s, 2 * s, TONGUE)];
    case 'o':
      return [E(x, y, 3.6 * s, 4.2 * s, ink)];
    case 'grin':
      return [P(arc(x, y - 1 * s, 5.2 * s, 5 * s, 0, Math.PI, 10), ink), E(x, y + 2.4 * s, 4 * s, 2.2 * s, TONGUE)];
    case 'cat':
      return [
        Q([x - 3.4 * s, y], [x - 1.7 * s, y + 2.4 * s], [x, y], 1.7 * s, ink),
        Q([x, y], [x + 1.7 * s, y + 2.4 * s], [x + 3.4 * s, y], 1.7 * s, ink),
      ];
    case 'flat':
      return [L([x - 2.6 * s, y], [x + 2.6 * s, y], 1.9 * s, ink)];
    case 'smirk':
      return [Q([x - 3.6 * s, y + 0.6 * s], [x + 0.5 * s, y + 2.8 * s], [x + 3.8 * s, y - 1.2 * s], 1.9 * s, ink)];
  }
}

const cheeks = (xl: number, xr: number, y: number, s = 1): AvatarOp[] => [
  E(xl, y, 5 * s, 3 * s, CHEEK, undefined, 0, { alpha: 0.55 }),
  E(xr, y, 5 * s, 3 * s, CHEEK, undefined, 0, { alpha: 0.55 }),
];

/** Två vantar vid greppunkten. Alla figurer "håller" objektet här. */
const hands = (color: string, edge: string, dx = 9, y = 22.4, r = 3.6): AvatarOp[] => [C(-dx, y, r, color, edge, { edgeW: 2.2 }), C(dx, y, r, color, edge, { edgeW: 2.2 })];

/** Liten gnista (utanför siluetten). */
const spark = (x: number, y: number, r: number, color: string): AvatarOp => P(star(x, y, r, r * 0.34), color, undefined, { noSil: true });

// ---------------------------------------------------------------- rörelsebibliotek

const IO = 'Sine.easeInOut';
const QO = 'Quad.easeOut';
const QI = 'Quad.easeIn';
const BO = 'Back.easeOut';
const CO = 'Cubic.easeOut';
const BNC = 'Bounce.easeOut';

const loop = (...steps: TweenStep[]): AnimRecipe => ({ steps, loop: true });
const once = (...steps: TweenStep[]): AnimRecipe => ({ steps });

/** Idle-loopar. Alla ≤1 Hz (period = summan av stegen). */
const IDLE = {
  bob: (amp = 1.5, half = 900): AnimRecipe => loop({ dy: -amp, ms: half, ease: IO }, { ms: half, ease: IO }),
  float: (amp = 3, half = 1200): AnimRecipe => loop({ dy: -amp, sy: 1.03, ms: half, ease: IO }, { ms: half, ease: IO }),
  breathe: (s = 1.04, half = 1000): AnimRecipe => loop({ sy: s, sx: 2 - s, ms: half, ease: IO }, { ms: half, ease: IO }),
  sway: (deg = 4, q = 600): AnimRecipe => loop({ rot: deg, ms: q, ease: IO }, { rot: -deg, ms: q * 2, ease: IO }, { ms: q, ease: IO }),
  hover: (px = 1.6, q = 500): AnimRecipe => loop({ dx: px, ms: q, ease: IO }, { dx: -px, ms: q * 2, ease: IO }, { ms: q, ease: IO }),
};

const DROP = {
  toss: once({ sy: 0.86, sx: 1.08, ms: 60, ease: QO }, { dy: -4, sy: 1.06, sx: 0.96, ms: 110, ease: BO }, { ms: 160, ease: IO }),
  nod: once({ rot: 10, dy: 1, ms: 80, ease: QO }, { ms: 220, ease: BO }),
  dip: once({ dy: 3, ms: 110, ease: QO }, { dy: -2, ms: 240, ease: IO }, { ms: 240, ease: IO }),
  thump: once({ sy: 0.9, sx: 1.06, ms: 80, ease: QO }, { ms: 240, ease: BO }),
  dart: once({ dx: -3, rot: -6, ms: 60, ease: QO }, { dx: 2, rot: 4, ms: 90, ease: QO }, { ms: 150, ease: BO }),
  spring: once({ sy: 0.82, sx: 1.12, ms: 70, ease: QO }, { dy: -7, sy: 1.1, sx: 0.94, ms: 130, ease: QO }, { ms: 220, ease: BNC }),
};

const MERGE = {
  hop: once({ dy: -5, ms: 110, ease: QO }, { ms: 200, ease: BNC }),
  wiggle: once({ rot: 8, ms: 70, ease: QO }, { rot: -8, ms: 120, ease: IO }, { ms: 90, ease: QO }),
  puff: once({ sx: 1.14, sy: 0.9, ms: 90, ease: QO }, { ms: 260, ease: 'Elastic.easeOut' }),
  shrug: once({ sy: 1.08, dy: -2, ms: 100, ease: QO }, { ms: 200, ease: BO }),
  clap: once({ sx: 0.9, sy: 1.08, ms: 70, ease: QO }, { sx: 1.08, sy: 0.94, ms: 70, ease: QO }, { ms: 140, ease: BO }),
};

const CHAIN = {
  flip: once({ dy: -8, ms: 140, ease: QO }, { dy: -8, rot: 360, ms: 320, ease: 'Cubic.easeInOut' }, { ms: 220, ease: BNC }),
  bigHop: once({ sy: 0.85, ms: 70, ease: QO }, { dy: -10, sy: 1.1, sx: 0.94, ms: 160, ease: QO }, { ms: 260, ease: BNC }),
  spinFloat: once({ dy: -6, rot: 12, ms: 160, ease: QO }, { dy: -6, rot: -12, ms: 200, ease: IO }, { ms: 260, ease: BO }),
  glowUp: once({ dy: -6, sx: 1.12, sy: 1.12, ms: 200, ease: CO }, { ms: 360, ease: BO }),
  stomp: once({ dy: -6, ms: 120, ease: QO }, { sy: 0.84, sx: 1.12, ms: 80, ease: QI }, { ms: 240, ease: BO }),
};

/** Fara: 1 Hz eller långsammare. Rörelse, aldrig ljusstyrka. */
const DANGER = {
  brace: loop({ sy: 0.93, sx: 1.04, rot: -5, ms: 500, ease: IO }, { sy: 0.93, sx: 1.04, rot: 5, ms: 500, ease: IO }),
  peek: loop({ dy: 2, sy: 0.95, ms: 600, ease: IO }, { ms: 600, ease: IO }),
  tremble: loop({ dx: -0.8, sy: 0.96, ms: 250, ease: IO }, { dx: 0.8, sy: 0.96, ms: 250, ease: IO }),
  hunker: loop({ sy: 0.9, sx: 1.06, ms: 700, ease: IO }, { sy: 0.95, sx: 1.03, ms: 700, ease: IO }),
};

type Personality = 'bouncy' | 'floaty' | 'heavy' | 'zippy' | 'springy' | 'stately';

const ANIMS: Readonly<Record<Personality, AvatarAnims>> = {
  bouncy: { idle: IDLE.bob(), drop: DROP.toss, merge: MERGE.hop, chain: CHAIN.flip, danger: DANGER.brace },
  floaty: { idle: IDLE.float(), drop: DROP.dip, merge: MERGE.puff, chain: CHAIN.spinFloat, danger: DANGER.peek },
  heavy: { idle: IDLE.breathe(1.03, 1100), drop: DROP.thump, merge: MERGE.shrug, chain: CHAIN.stomp, danger: DANGER.hunker },
  zippy: { idle: IDLE.hover(), drop: DROP.dart, merge: MERGE.wiggle, chain: CHAIN.flip, danger: DANGER.tremble },
  springy: { idle: IDLE.breathe(1.05, 700), drop: DROP.spring, merge: MERGE.hop, chain: CHAIN.bigHop, danger: DANGER.brace },
  stately: { idle: IDLE.sway(3, 700), drop: DROP.nod, merge: MERGE.puff, chain: CHAIN.glowUp, danger: DANGER.peek },
};

const anims = (p: Personality, o: Partial<AvatarAnims> = {}): AvatarAnims => ({ ...ANIMS[p], ...o });

// ---------------------------------------------------------------- ljud (Web Audio via playTone)

const TONE = {
  plopp: { wave: 'sine', baseHz: 520, glideTo: 820, attack: 0.002, decay: 0.08, gain: 0.14 },
  click2: { wave: 'square', baseHz: 1500, glideTo: 950, attack: 0.001, decay: 0.03, gain: 0.08, steps: [0, 0], stepMs: 70, lowpassHz: 3200 },
  kvack: { wave: 'square', baseHz: 190, glideTo: 125, attack: 0.005, decay: 0.12, gain: 0.14, lowpassHz: 900, vibratoHz: 28, vibratoCents: 60 },
  pip: { wave: 'sine', baseHz: 1760, glideTo: 2240, attack: 0.002, decay: 0.05, gain: 0.08 },
  surr: { wave: 'sawtooth', baseHz: 150, attack: 0.01, decay: 0.24, gain: 0.07, lowpassHz: 600, vibratoHz: 24, vibratoCents: 60 },
  arf: { wave: 'triangle', baseHz: 360, glideTo: 270, attack: 0.004, decay: 0.09, gain: 0.14 },
  blubb: { wave: 'sine', baseHz: 300, glideTo: 620, attack: 0.002, decay: 0.07, gain: 0.13 },
  tink: { wave: 'sine', baseHz: 2093, attack: 0.001, decay: 0.2, gain: 0.08, harmonicSemitones: 7, harmonicGain: 0.4 },
  whoosh: { wave: 'sawtooth', baseHz: 620, glideTo: 200, attack: 0.01, decay: 0.18, gain: 0.07, lowpassHz: 1500 },
  robot: { wave: 'square', baseHz: 523.25, attack: 0.002, decay: 0.08, gain: 0.12, lowpassHz: 2400 },
  puff: { wave: 'triangle', baseHz: 210, glideTo: 90, attack: 0.004, decay: 0.14, gain: 0.14, lowpassHz: 800 },
  purr: { wave: 'triangle', baseHz: 70, attack: 0.03, decay: 0.5, gain: 0.14, vibratoHz: 22, vibratoCents: 80 },
  squeak: { wave: 'sine', baseHz: 900, glideTo: 1300, attack: 0.004, decay: 0.12, gain: 0.1, vibratoHz: 12, vibratoCents: 30 },
  arrr: { wave: 'sawtooth', baseHz: 110, glideTo: 88, attack: 0.02, decay: 0.42, gain: 0.12, lowpassHz: 700, vibratoHz: 8, vibratoCents: 40 },
  wooo: { wave: 'sine', baseHz: 440, glideTo: 330, attack: 0.05, decay: 0.5, gain: 0.09, vibratoHz: 5, vibratoCents: 40 },
  drum: { wave: 'sine', baseHz: 140, glideTo: 58, attack: 0.001, decay: 0.16, gain: 0.3 },
  song: { wave: 'sine', baseHz: 523.25, glideTo: 392, attack: 0.03, decay: 0.36, gain: 0.1, vibratoHz: 6, vibratoCents: 25 },
  shimmer: { wave: 'triangle', baseHz: 1046.5, attack: 0.003, decay: 0.22, gain: 0.1, steps: [0, 4, 7], stepMs: 60, harmonicSemitones: 12, harmonicGain: 0.2 },
} satisfies Record<string, AvatarTone>;

// ---------------------------------------------------------------- spår och showcase-hjälp

const trail = (shape: AvatarParticle, tint: string | readonly string[], o: Partial<TrailDef> = {}): TrailDef => ({
  shape,
  tint,
  everyPx: 16,
  lifeMs: 420,
  scale: [0.7, 0],
  alpha: [0.85, 0],
  gravityY: 0,
  driftPx: 4,
  blend: 'NORMAL',
  ...o,
});

const burst = (shape: AvatarParticle, tint: string | readonly string[], count = 12, speed = 90, lifeMs = 520, gravityY = 0): FxCue => ({
  kind: 'burst', shape, tint, count, speed, lifeMs, gravityY,
});
const rise = (shape: AvatarParticle, tint: string | readonly string[], count = 6, risePx = 60): FxCue => ({
  kind: 'rise', shape, tint, count, risePx, swayPx: 6, lifeMs: 700, staggerMs: 70,
});
const fall = (shape: AvatarParticle, tint: string | readonly string[], count = 8): FxCue => ({
  kind: 'fall', shape, tint, count, fallPx: 50, spreadPx: 30, lifeMs: 600, staggerMs: 50,
});
const rings = (color: string, count = 2, toR = 46): FxCue => ({ kind: 'rings', color, count, fromR: 20, toR, width: 3, ms: 560, staggerMs: 160 });

/** Showcase spelas alltid EN gång (loop tas bort). I öppningen tidsskalas den till fönstret 580–1 200 ms. */
const show = (anim: AnimRecipe, fx: FxCue, sound: AvatarTone, fxAtMs = 120): Showcase => ({ anim: { steps: anim.steps }, fx, sound, fxAtMs });

// ---------------------------------------------------------------- byggare

type Base = Omit<AvatarDef, 'rarityColor'>;
const def = (d: Base): AvatarDef => ({ ...d, rarityColor: RARITY.color[d.rarity] });

// ================================================================ VANLIG (16) – ren kosmetik

const COMMON: AvatarDef[] = [
  def({
    id: 'common-1',
    names: { en: 'Sheldon the Shell', sv: 'Snäckan Sigge' },
    rarity: 'common',
    idea: 'Liten havssnäcka som bär sitt hus: långsam, trygg, lämnar pärlor efter sig.',
    draw: [
      C(5, -6, 15, '#FF9F7A', '#6B2A14'),
      PL(spiral(5, -6, 1.5, 11, 1.7, 0.6), 2.4, '#6B2A14', { alpha: 0.7 }),
      P([[13, -16], [22, -26], [19, -12]], '#FF9F7A', '#6B2A14'),
      E(-4, 10, 28, 20, '#FFE6CF', '#6B3A22'),
      shine(0, -14, 12, 5, -0.3),
      ...eyes('dot', -9, -1, 8),
      ...mouth('smile', -5, 13, 0.8),
      ...cheeks(-13, 3, 12, 0.8),
      ...hands('#FFE6CF', '#6B3A22'),
    ],
    anim: anims('heavy'),
    cosmetic: {
      trail: trail('dot', ['#FFF4EA', '#FFD6E6'], { everyPx: 14, scale: [0.55, 0.2], lifeMs: 480 }),
      sound: { land: TONE.plopp },
    },
    showcase: show(DROP.thump, rise('dot', ['#FFF4EA', '#FFD6E6'], 7, 50), TONE.plopp),
  }),
  def({
    id: 'common-2',
    names: { en: 'Jilly the Jellyfish', sv: 'Maneten Molly' },
    rarity: 'common',
    idea: 'Svävande manet: allt hon gör är mjukt och långsamt, som i vatten.',
    draw: [
      Q([-11, 6], [-16, 15], [-9, 22], 3.2, '#B08CF0', '#3B2066', { edgeW: 1.6 }),
      Q([-4, 8], [-7, 15], [-3, 21], 3.2, '#B08CF0', '#3B2066', { edgeW: 1.6 }),
      Q([4, 8], [7, 15], [3, 21], 3.2, '#B08CF0', '#3B2066', { edgeW: 1.6 }),
      Q([11, 6], [16, 15], [9, 22], 3.2, '#B08CF0', '#3B2066', { edgeW: 1.6 }),
      P([...arc(0, 6, 17, 19, Math.PI, 2 * Math.PI, 20), [12, 9], [6, 6.5], [0, 9], [-6, 6.5], [-12, 9]], '#D2B4FF', '#3B2066'),
      shine(-5, -6, 11, 6, -0.3),
      C(8, -4, 1.9, '#F4ECFF', undefined, { alpha: 0.8 }),
      C(11, 1, 1.4, '#F4ECFF', undefined, { alpha: 0.8 }),
      ...eyes('dot', -5, 5, -1),
      ...mouth('smile', 0, 3, 0.8),
      ...cheeks(-9, 9, 2, 0.8),
      ...hands('#B08CF0', '#3B2066', 9, 22.6, 3.2),
    ],
    anim: anims('floaty'),
    cosmetic: { trail: trail('bubble', '#D2B4FF', { everyPx: 18, gravityY: -40, scale: [0.4, 0.9], alpha: [0.8, 0] }) },
    showcase: show(IDLE.float(5, 300), rise('bubble', '#D2B4FF', 6, 60), TONE.blubb),
  }),
  def({
    id: 'common-3',
    names: { en: 'Cody the Crab', sv: 'Krabban Krille' },
    rarity: 'common',
    idea: 'Kaxig liten krabba som klickar med klorna varje gång han släpper.',
    draw: [
      L([-12, 10], [-22, 14], 3, '#FF9A6B', '#5C2410', { edgeW: 1.6 }),
      L([-12, 13], [-21, 19], 3, '#FF9A6B', '#5C2410', { edgeW: 1.6 }),
      L([12, 10], [22, 14], 3, '#FF9A6B', '#5C2410', { edgeW: 1.6 }),
      L([12, 13], [21, 19], 3, '#FF9A6B', '#5C2410', { edgeW: 1.6 }),
      L([-12, 2], [-18, -9], 4, '#FF9A6B', '#5C2410', { edgeW: 1.6 }),
      L([12, 2], [18, -9], 4, '#FF9A6B', '#5C2410', { edgeW: 1.6 }),
      C(-19, -14, 7, '#FF9A6B', '#5C2410'),
      C(19, -14, 7, '#FF9A6B', '#5C2410'),
      L([-17, -21], [-19, -14], 2.2, '#5C2410'),
      L([17, -21], [19, -14], 2.2, '#5C2410'),
      L([-5, 0], [-6, -9], 2.6, '#5C2410'),
      L([5, 0], [6, -9], 2.6, '#5C2410'),
      E(0, 8, 34, 22, '#FF9A6B', '#5C2410'),
      shine(-4, 1, 14, 5),
      ...eyes('big', -6, 6, -11, 0.9),
      ...mouth('smile', 0, 10),
      ...cheeks(-9, 9, 11, 0.8),
      ...hands('#FF9A6B', '#5C2410'),
    ],
    anim: anims('zippy'),
    cosmetic: {
      sound: { drop: TONE.click2 },
      gesture: { on: 'drop', anim: once({ sx: 1.1, sy: 0.92, ms: 60, ease: QO }, { sx: 0.95, ms: 70, ease: QO }, { ms: 140, ease: BO }) },
    },
    showcase: show(MERGE.clap, burst('shard', '#FFB38F', 8, 70), TONE.click2),
  }),
  def({
    id: 'common-4',
    names: { en: 'Stella the Starfish', sv: 'Sjöstjärnan Stina' },
    rarity: 'common',
    idea: 'Glad sjöstjärna som gör varje merge till en liten stjärnregn.',
    draw: [
      P(softStar(0, 3, 22, 9.5, 5, 1.4), '#FFB35C', '#5C3000'),
      C(-9, -4, 1.4, '#FFE0B0'),
      C(9, -4, 1.4, '#FFE0B0'),
      C(-12, 12, 1.4, '#FFE0B0'),
      C(12, 12, 1.4, '#FFE0B0'),
      C(0, -13, 1.4, '#FFE0B0'),
      shine(-3, -4, 9, 4),
      ...eyes('happy', -4.5, 4.5, 1),
      ...mouth('open', 0, 5.5, 0.8),
      ...cheeks(-8, 8, 6, 0.7),
    ],
    anim: anims('bouncy', { idle: IDLE.sway(5, 500) }),
    cosmetic: { particleShape: 'star', particleTint: '#FFD08A' },
    showcase: show(CHAIN.flip, burst('star', ['#FFD08A', '#FFF4DC'], 12, 100), TONE.shimmer),
  }),
  def({
    id: 'common-5',
    names: { en: 'Otto the Octopus', sv: 'Bläckfisken Bosse' },
    rarity: 'common',
    idea: 'Mjuk bläckfisk med åtta armar i luften – sprutar lila bläckprickar av glädje.',
    draw: [
      Q([-11, 8], [-22, 14], [-17, 21], 4.2, '#FF86B8', '#5A1233', { edgeW: 1.8 }),
      Q([11, 8], [22, 14], [17, 21], 4.2, '#FF86B8', '#5A1233', { edgeW: 1.8 }),
      Q([-5, 10], [-10, 16], [-9, 22], 4.2, '#FF86B8', '#5A1233', { edgeW: 1.8 }),
      Q([5, 10], [10, 16], [9, 22], 4.2, '#FF86B8', '#5A1233', { edgeW: 1.8 }),
      E(0, -2, 32, 30, '#FF86B8', '#5A1233'),
      C(-8, -11, 2.4, '#FFC2DA'),
      C(7, -13, 1.8, '#FFC2DA'),
      C(11, -5, 1.5, '#FFC2DA'),
      shine(-4, -12, 12, 5),
      ...eyes('big', -6, 6, -1, 0.85),
      ...mouth('o', 0, 7, 0.9),
      ...cheeks(-10, 10, 4, 0.8),
      ...hands('#FF86B8', '#5A1233', 9, 22.6, 3),
    ],
    anim: anims('floaty', { merge: MERGE.wiggle }),
    cosmetic: { particleShape: 'drop', particleTint: '#B98CFF' },
    showcase: show(MERGE.wiggle, burst('drop', '#B98CFF', 10, 80, 560, 160), TONE.blubb),
  }),
  def({
    id: 'common-6',
    names: { en: 'Finley the Fish', sv: 'Fisken Fenja' },
    rarity: 'common',
    idea: 'Nyfiken fisk som aldrig tar ögonen från det du släpper.',
    draw: [
      P([[12, 0], [26, -11], [22, 0], [26, 11]], '#7FB2FF', '#12305C'),
      P([[-8, -10], [2, -19], [8, -10]], '#7FB2FF', '#12305C'),
      L([-5, 9], [-9, 20], 3.4, '#7FB2FF', '#12305C', { edgeW: 1.6 }),
      L([3, 10], [9, 20], 3.4, '#7FB2FF', '#12305C', { edgeW: 1.6 }),
      E(-2, 0, 36, 26, '#7FB2FF', '#12305C'),
      Q([4, -11], [8, 0], [4, 11], 2.4, '#C7DDFF'),
      Q([9, -9], [12, 0], [9, 9], 2.4, '#C7DDFF'),
      shine(-6, -8, 14, 5),
      C(-9, -2, 5.6, WHITE, INK, { edgeW: 1.4 }),
      ...mouth('smile', -15, 6, 0.7),
      E(-9, 5, 5, 3, CHEEK, undefined, 0, { alpha: 0.55 }),
      ...hands('#7FB2FF', '#12305C'),
    ],
    anim: anims('zippy'),
    cosmetic: {
      look: { pupils: [C(-9, -2, 3.1, INK), C(-8, -3, 1, WHITE)], lookPx: 2.2 },
      trail: trail('bubble', '#C7DDFF', { everyPx: 22, gravityY: -50, scale: [0.35, 0.7] }),
    },
    showcase: show(DROP.dart, rise('bubble', '#C7DDFF', 5, 50), TONE.blubb),
  }),
  def({
    id: 'common-7',
    names: { en: 'Pim the Penguin', sv: 'Pingvinen Pim' },
    rarity: 'common',
    idea: 'Pingvin i stickad mössa som nickar belåtet efter varje släpp.',
    draw: [
      Q([-13, 2], [-18, 14], [-9.5, 22], 6, '#5A6FA8', '#141E3A', { edgeW: 2 }),
      Q([13, 2], [18, 14], [9.5, 22], 6, '#5A6FA8', '#141E3A', { edgeW: 2 }),
      E(0, 4, 30, 38, '#5A6FA8', '#141E3A'),
      E(0, 9, 20, 24, '#F2F6FF'),
      ...eyes('big', -5, 5, -4, 0.75),
      P([[-3, 0], [3, 0], [0, 4]], '#FFB547', '#5C3000', { edgeW: 1.2 }),
      ...cheeks(-8, 8, 3, 0.7),
      P([...arc(0, -9, 14.5, 12, Math.PI, 2 * Math.PI, 16)], '#FF86B8', '#5A1233'),
      P(roundRect(-15, -12, 30, 5, 2), '#E0609A', '#5A1233', { edgeW: 2 }),
      C(0, -22, 4, '#FFF0F6', '#5A1233', { edgeW: 2 }),
      ...hands('#5A6FA8', '#141E3A', 9.5, 22.4, 3.2),
    ],
    anim: anims('bouncy', { drop: DROP.nod }),
    cosmetic: { sound: { drop: TONE.pip }, gesture: { on: 'drop', anim: once({ rot: 14, dy: 1.5, ms: 90, ease: QO }, { ms: 260, ease: BO }) } },
    showcase: show(once({ rot: 14, ms: 90, ease: QO }, { ms: 200, ease: BO }, { rot: 14, ms: 90, ease: QO }, { ms: 220, ease: BO }), burst('dot', '#F2F6FF', 8, 60), TONE.pip),
  }),
  def({
    id: 'common-8',
    names: { en: 'Freddie the Frog', sv: 'Grodan Gurra' },
    rarity: 'common',
    idea: 'Bred glad groda som kväker när det går bra (combo 3).',
    draw: [
      E(-14, 17, 12, 8, '#7EE06A', '#1E4A12'),
      E(14, 17, 12, 8, '#7EE06A', '#1E4A12'),
      E(0, 6, 38, 28, '#7EE06A', '#1E4A12'),
      C(-9, -8, 7.5, '#7EE06A', '#1E4A12'),
      C(9, -8, 7.5, '#7EE06A', '#1E4A12'),
      E(0, 7, 38 - 5.6, 28 - 5.6, '#7EE06A'),
      E(0, 13, 22, 9, '#D8F7B8'),
      ...eyes('big', -9, 9, -8, 0.95),
      Q([-10, 5], [0, 13], [10, 5], 2.2, INK),
      ...cheeks(-13, 13, 8, 0.8),
      ...hands('#7EE06A', '#1E4A12'),
    ],
    anim: anims('springy'),
    cosmetic: { sound: { combo3: TONE.kvack }, gesture: { on: 'combo3', anim: CHAIN.bigHop } },
    showcase: show(CHAIN.bigHop, burst('drop', '#B8F07A', 8, 70, 480, 200), TONE.kvack),
  }),
  def({
    id: 'common-9',
    names: { en: 'Selma the Seal', sv: 'Sälen Selma' },
    rarity: 'common',
    idea: 'Sälen som balanserar bollar – hon är född till att hålla saker.',
    draw: [
      E(0, 3, 30, 36, '#B8C4DC', '#2E3A56'),
      C(-9, 9, 1.6, '#8E9CBC'),
      C(10, 5, 1.3, '#8E9CBC'),
      C(7, 13, 1.8, '#8E9CBC'),
      shine(-4, -9, 12, 5),
      ...eyes('big', -5.5, 5.5, -5, 0.8),
      E(0, 2.5, 13, 8, '#E4EAF6'),
      E(0, 0, 5, 3.4, INK),
      L([-3, 3], [-11, 1], 1.1, '#2E3A56'),
      L([-3, 4.5], [-11, 5.5], 1.1, '#2E3A56'),
      L([3, 3], [11, 1], 1.1, '#2E3A56'),
      L([3, 4.5], [11, 5.5], 1.1, '#2E3A56'),
      ...mouth('smile', 0, 4.5, 0.55),
      E(-9, 21, 11, 6, '#B8C4DC', '#2E3A56', 0.45, { edgeW: 2.2 }),
      E(9, 21, 11, 6, '#B8C4DC', '#2E3A56', -0.45, { edgeW: 2.2 }),
    ],
    anim: anims('bouncy', { idle: IDLE.sway(3, 700) }),
    cosmetic: { sound: { merge: TONE.arf }, gesture: { on: 'merge', anim: MERGE.clap } },
    showcase: show(MERGE.clap, rings('#E4EAF6', 1, 36), TONE.arf),
  }),
  def({
    id: 'common-10',
    names: { en: 'Milo the Mouse', sv: 'Musen Mio' },
    rarity: 'common',
    idea: 'Pigg mus med stora öron som piper när något landar.',
    draw: [
      Q([12, 14], [27, 12], [22, -2], 2.4, '#3F3752'),
      C(-13, -13, 9, '#C9C2DA', '#3F3752'),
      C(13, -13, 9, '#C9C2DA', '#3F3752'),
      C(-13, -13, 5.4, '#FFB8D0'),
      C(13, -13, 5.4, '#FFB8D0'),
      C(0, 4, 16, '#C9C2DA', '#3F3752'),
      shine(-4, -6, 12, 5),
      ...eyes('dot', -5, 5, 1),
      C(0, 5, 2, '#FF8FB8', INK, { edgeW: 1 }),
      ...mouth('cat', 0, 7.5, 0.8),
      L([-3, 5], [-12, 3], 1, '#3F3752'),
      L([-3, 6], [-12, 8], 1, '#3F3752'),
      L([3, 5], [12, 3], 1, '#3F3752'),
      L([3, 6], [12, 8], 1, '#3F3752'),
      ...hands('#C9C2DA', '#3F3752'),
    ],
    anim: anims('springy'),
    cosmetic: { sound: { land: TONE.pip }, gesture: { on: 'land', anim: once({ sy: 1.08, dy: -2, ms: 60, ease: QO }, { ms: 160, ease: BO }) } },
    showcase: show(DROP.spring, burst('dot', '#FFB8D0', 6, 60), TONE.pip),
  }),
  def({
    id: 'common-11',
    names: { en: 'Sally the Snail', sv: 'Snigeln Sally' },
    rarity: 'common',
    idea: 'Långsam snigel som lämnar ett glittrande slemspår efter allt hon släpper.',
    draw: [
      L([-15, -2], [-19, -12], 2.4, '#BDF07A', '#2D4A0B', { edgeW: 1.4 }),
      L([-9, -2], [-8, -12], 2.4, '#BDF07A', '#2D4A0B', { edgeW: 1.4 }),
      E(-2, 16, 42, 13, '#BDF07A', '#2D4A0B'),
      E(-13, 6, 14, 20, '#BDF07A', '#2D4A0B'),
      E(-2, 16.5, 42 - 5.6, 13 - 5.6, '#BDF07A'),
      C(6, 1, 13, '#FFC96B', '#5A3D00'),
      PL(spiral(6, 1, 1.4, 9.5, 1.6, 0.4), 2.2, '#5A3D00', { alpha: 0.7 }),
      shine(2, -7, 10, 4),
      C(-19, -13, 3, WHITE, INK, { edgeW: 1.2 }),
      C(-8, -13, 3, WHITE, INK, { edgeW: 1.2 }),
      C(-18.6, -12.6, 1.6, INK),
      C(-7.6, -12.6, 1.6, INK),
      ...mouth('smile', -13, 7, 0.7),
      E(-17, 5, 4, 2.5, CHEEK, undefined, 0, { alpha: 0.55 }),
    ],
    anim: anims('heavy', { idle: IDLE.breathe(1.02, 1300) }),
    cosmetic: { trail: trail('dot', ['#D8FFA0', '#FFFFFF'], { everyPx: 8, lifeMs: 700, scale: [0.45, 0.25], alpha: [0.6, 0], driftPx: 0, blend: 'ADD' }) },
    showcase: show(IDLE.breathe(1.06, 300), fall('dot', ['#D8FFA0', '#FFFFFF'], 10), TONE.plopp),
  }),
  def({
    id: 'common-12',
    names: { en: 'Bea the Bumblebee', sv: 'Humlan Humle' },
    rarity: 'common',
    idea: 'Rund humla som surrar till när hon släpper.',
    draw: [
      E(-11, -13, 14, 20, '#EAF6FF', '#6E8CC4', -0.5, { alpha: 0.9, edgeW: 1.8 }),
      E(11, -13, 14, 20, '#EAF6FF', '#6E8CC4', 0.5, { alpha: 0.9, edgeW: 1.8 }),
      Q([-4, -9], [-6, -18], [-10, -20], 2, '#3D2A00'),
      Q([4, -9], [6, -18], [10, -20], 2, '#3D2A00'),
      C(-10, -20, 2.2, '#3D2A00'),
      C(10, -20, 2.2, '#3D2A00'),
      E(0, 5, 32, 30, '#FFD447', '#3D2A00'),
      Q([-14, 10], [0, 14], [14, 10], 3.4, '#3D2A00'),
      Q([-11, 16], [0, 19.5], [11, 16], 3.4, '#3D2A00'),
      shine(-5, -4, 12, 5),
      ...eyes('dot', -5, 5, -1),
      ...mouth('smile', 0, 3, 0.8),
      ...cheeks(-10, 10, 3, 0.8),
      ...hands('#FFD447', '#3D2A00'),
    ],
    anim: anims('zippy', { idle: IDLE.hover(1.2, 250) }),
    cosmetic: { sound: { drop: TONE.surr } },
    showcase: show(IDLE.hover(3, 90), burst('dot', '#FFE680', 8, 60), TONE.surr),
  }),
  def({
    id: 'common-13',
    names: { en: 'Puff the Pufferfish', sv: 'Blåsfisken Puff' },
    rarity: 'common',
    idea: 'Taggig blåsfisk som blåser upp sig av förtjusning vid varje merge.',
    draw: [
      ...Array.from({ length: 12 }, (_, i): AvatarOp => {
        const a = (i / 12) * Math.PI * 2 + 0.26;
        const s = Math.sin(a);
        const c = -Math.cos(a);
        const t = Math.cos(a);
        const u = Math.sin(a);
        return P(
          [[r2(s * 15 - t * 2.6), r2(1 + c * 15 - u * 2.6)], [r2(s * 21.5), r2(1 + c * 21.5)], [r2(s * 15 + t * 2.6), r2(1 + c * 15 + u * 2.6)]],
          '#FFE08A',
          '#5A4700',
          { edgeW: 2 },
        );
      }),
      C(0, 1, 16, '#FFE08A', '#5A4700'),
      E(0, 8, 20, 10, '#FFF2C4', undefined, 0, { alpha: 0.9 }),
      E(-17, 4, 7, 5, '#FFB547', '#5A4700', 0, { edgeW: 1.6 }),
      E(17, 4, 7, 5, '#FFB547', '#5A4700', 0, { edgeW: 1.6 }),
      shine(-4, -9, 12, 5),
      ...eyes('big', -6, 6, -2, 0.85),
      ...mouth('o', 0, 7, 0.8),
      ...cheeks(-10, 10, 4, 0.7),
      ...hands('#FFE08A', '#5A4700'),
    ],
    anim: anims('bouncy', { merge: MERGE.puff }),
    cosmetic: { gesture: { on: 'merge', anim: once({ sx: 1.2, sy: 1.2, ms: 110, ease: QO }, { ms: 300, ease: 'Elastic.easeOut' }) } },
    showcase: show(once({ sx: 1.25, sy: 1.25, ms: 140, ease: QO }, { ms: 360, ease: 'Elastic.easeOut' }), burst('shard', '#FFE08A', 10, 90), TONE.plopp),
  }),
  def({
    id: 'common-14',
    names: { en: 'Tess the Turtle', sv: 'Sköldpaddan Tuss' },
    rarity: 'common',
    idea: 'Lugn sköldpadda – ingenting stressar henne, inte ens fara.',
    draw: [
      E(-11, 20, 9, 8, '#C4F0A0', '#2D4A0B'),
      E(11, 20, 9, 8, '#C4F0A0', '#2D4A0B'),
      P(arc(0, 5, 21, 21, Math.PI, 2 * Math.PI, 20), '#6CD6A0', '#0B4A30'),
      P(star(0, -6, 6, 6, 3), '#6CD6A0', '#0B4A30', { edgeW: 1.8 }),
      L([-6, -3], [-15, 2], 1.8, '#0B4A30'),
      L([6, -3], [15, 2], 1.8, '#0B4A30'),
      L([0, -12], [0, -16], 1.8, '#0B4A30'),
      E(0, 5, 44, 8, '#3FAE7A', '#0B4A30'),
      C(0, 11, 9.5, '#C4F0A0', '#2D4A0B'),
      shine(-7, -9, 12, 4, -0.3),
      ...eyes('dot', -3.6, 3.6, 10, 0.8),
      ...mouth('smile', 0, 13.5, 0.6),
    ],
    anim: anims('heavy', { danger: DANGER.peek }),
    cosmetic: { sound: { land: TONE.plopp }, gesture: { on: 'drop', anim: once({ sy: 0.94, ms: 200, ease: IO }, { ms: 300, ease: IO }) } },
    showcase: show(once({ sy: 0.9, dy: 2, ms: 260, ease: IO }, { ms: 360, ease: BO }), rings('#6CD6A0', 1, 40), TONE.plopp),
  }),
  def({
    id: 'common-15',
    names: { en: 'Skip the Shrimp', sv: 'Räkan Räkel' },
    rarity: 'common',
    idea: 'Spralligt böjd räka med långa spröt som darrar av iver.',
    draw: [
      Q([-8, -12], [-16, -22], [-24, -26], 1.8, '#5C2418'),
      Q([-4, -14], [2, -24], [10, -27], 1.8, '#5C2418'),
      P([[-2, 18], [-12, 25], [-8, 16], [-14, 14]], '#FFB0A0', '#5C2418', { edgeW: 2.2 }),
      C(3, 14, 6.5, '#FFB0A0', '#5C2418'),
      C(10, 7, 7.5, '#FFB0A0', '#5C2418'),
      C(9, -3, 8.5, '#FFB0A0', '#5C2418'),
      C(-4, -7, 11, '#FFB0A0', '#5C2418'),
      Q([4, 8], [8, 12], [8, 16], 1.6, '#FFD6CC'),
      Q([12, 1], [16, 5], [15, 11], 1.6, '#FFD6CC'),
      shine(-7, -13, 10, 4),
      ...eyes('dot', -8, -1, -8, 0.95),
      ...mouth('smile', -4.5, -2.5, 0.7),
      ...cheeks(-11, 2, -4, 0.6),
      ...hands('#FFB0A0', '#5C2418'),
    ],
    anim: anims('springy', { idle: IDLE.sway(4, 500) }),
    cosmetic: { gesture: { on: 'merge', anim: once({ rot: -10, sy: 0.9, ms: 70, ease: QO }, { rot: 6, sy: 1.06, ms: 90, ease: QO }, { ms: 180, ease: BO }) } },
    showcase: show(DROP.spring, burst('dot', '#FFD6CC', 8, 70), TONE.pip),
  }),
  def({
    id: 'common-16',
    names: { en: 'Urban the Urchin', sv: 'Sjöborren Borre' },
    rarity: 'common',
    idea: 'Taggig men snäll sjöborre – ser farlig ut, är världens mjukaste.',
    draw: [
      ...Array.from({ length: 16 }, (_, i): AvatarOp => {
        const a = (i / 16) * Math.PI * 2 + 0.2;
        return L(
          [r2(Math.sin(a) * 12), r2(2 - Math.cos(a) * 12)],
          [r2(Math.sin(a) * 22), r2(2 - Math.cos(a) * 22)],
          2.4,
          '#C9B8FF',
          '#2A1650',
          { edgeW: 1.2 },
        );
      }),
      C(0, 2, 14, '#A68CE8', '#2A1650'),
      shine(-4, -6, 11, 4),
      ...eyes('happy', -5, 5, 0),
      ...mouth('open', 0, 5, 0.7),
      ...cheeks(-9, 9, 4, 0.7),
      ...hands('#A68CE8', '#2A1650'),
    ],
    anim: anims('heavy'),
    cosmetic: { particleShape: 'shard', particleTint: '#C9B8FF' },
    showcase: show(IDLE.sway(10, 120), burst('shard', '#C9B8FF', 14, 100), TONE.tink),
  }),
];

// ================================================================ OVANLIG (12) – rikare kosmetik

const UNCOMMON: AvatarDef[] = [
  def({
    id: 'uncommon-1',
    names: { en: 'Stanley the Seahorse', sv: 'Sjöhästen Harry' },
    rarity: 'uncommon',
    idea: 'Stolt sjöhäst som håller objektet med svansen; partiklarna skiftar färg med combon.',
    draw: [
      Q([1, 10], [9, 24], [-3, 22], 5, '#F7A6E0', '#551A45', { edgeW: 2.2 }),
      C(-3, 19.5, 3, '#F7A6E0', '#551A45', { edgeW: 2 }),
      P([[6, -3], [15, 1], [7, 10]], '#C77DFF', '#551A45', { edgeW: 2.2 }),
      E(0, 4, 18, 22, '#F7A6E0', '#551A45', 0.15),
      Q([-4, 0], [0, 2], [4, 0], 1.6, '#FFD6F2'),
      Q([-4, 5], [0, 7], [4, 5], 1.6, '#FFD6F2'),
      Q([-3, 10], [0, 12], [3, 10], 1.6, '#FFD6F2'),
      P([[-6, -18], [-4, -24], [-1, -19], [2, -25], [3, -18], [7, -21], [6, -14]], '#C77DFF', '#551A45', { edgeW: 2 }),
      E(-11, -7, 13, 6, '#F7A6E0', '#551A45', 0.25, { edgeW: 2.2 }),
      C(-1, -10, 9.5, '#F7A6E0', '#551A45'),
      shine(-3, -15, 8, 3.5),
      C(0.5, -11, 3.8, WHITE, INK, { edgeW: 1.2 }),
      C(1, -10.6, 2.1, INK),
      C(1.8, -11.6, 0.8, WHITE),
      E(-4, -6, 4, 2.6, CHEEK, undefined, 0, { alpha: 0.55 }),
    ],
    anim: anims('stately', { idle: IDLE.bob(2, 800) }),
    cosmetic: { particleTint: 'combo', particleShape: 'dot', trail: trail('dot', ['#F7A6E0', '#C77DFF'], { everyPx: 14 }) },
    showcase: show(IDLE.bob(4, 150), burst('dot', ['#FF8766', '#FFD447', '#6EE7A0', '#5AA9FF', '#B98CFF'], 14, 90), TONE.shimmer),
  }),
  def({
    id: 'uncommon-2',
    names: { en: 'Kit the Comet', sv: 'Kometen Kim' },
    rarity: 'uncommon',
    idea: 'En liten komet: allt han släpper får en eldsvans.',
    draw: [
      P([[-11, 3], [-15, -20], [-4, -8], [1, -27], [6, -8], [16, -21], [11, 3]], '#FFB547', '#5C3000'),
      P([[-6, 2], [-8, -11], [-1, -4], [1, -17], [4, -4], [9, -11], [6, 2]], '#FFE08A'),
      C(0, 8, 13, '#FFE9A0', '#5C4000'),
      shine(-4, 2, 10, 4),
      ...eyes('happy', -4.5, 4.5, 7),
      ...mouth('open', 0, 12, 0.7),
      ...cheeks(-8, 8, 11, 0.7),
      ...hands('#FFE9A0', '#5C4000'),
    ],
    anim: anims('zippy'),
    cosmetic: {
      trail: trail('dot', ['#FFB547', '#FFE08A', '#FF8766'], { everyPx: 7, lifeMs: 360, scale: [0.9, 0.1], gravityY: -60, blend: 'ADD' }),
      sound: { drop: TONE.whoosh },
    },
    showcase: show(once({ dy: -8, ms: 140, ease: QO }, { ms: 220, ease: BNC }), rise('dot', ['#FFB547', '#FFE08A'], 10, 50), TONE.whoosh),
  }),
  def({
    id: 'uncommon-3',
    names: { en: 'Snowy the Snowman', sv: 'Snögubben Snö' },
    rarity: 'uncommon',
    idea: 'Snögubbe som får det att snöa och frosta i kanterna vid merge.',
    draw: [
      L([-9, 9], [-11, 21], 2.2, '#8A5A3C'),
      L([9, 9], [11, 21], 2.2, '#8A5A3C'),
      L([-10, 15], [-15, 13], 1.8, '#8A5A3C'),
      L([10, 15], [15, 13], 1.8, '#8A5A3C'),
      C(0, 12, 11.5, '#F4F7FF', '#33415C'),
      C(0, -5, 10, '#F4F7FF', '#33415C'),
      E(0, 3, 21, 6, '#3FC2B0', '#0B4A40', 0, { edgeW: 2 }),
      P([[3, 4], [8, 4], [10, 12], [5, 11]], '#3FC2B0', '#0B4A40', { edgeW: 2 }),
      C(0, 10, 1.4, INK),
      C(0, 15, 1.4, INK),
      ...eyes('dot', -3.5, 3.5, -7, 0.85),
      P([[-0.5, -4.5], [1, -2.5], [9, -3]], '#FFA14A', '#5C3000', { edgeW: 1 }),
      ...mouth('smile', -1, -1, 0.55),
      E(0, -14, 22, 5, '#5A6FA8', '#1A2440', 0, { edgeW: 2 }),
      P(roundRect(-7, -27, 14, 13, 2), '#5A6FA8', '#1A2440', { edgeW: 2 }),
      P(roundRect(-7, -18, 14, 3, 1), '#3FC2B0'),
    ],
    anim: anims('heavy', { idle: IDLE.sway(3, 800) }),
    cosmetic: {
      particleShape: 'star',
      particleTint: '#EAF6FF',
      trail: trail('dot', '#EAF6FF', { everyPx: 18, gravityY: 30, driftPx: 8, lifeMs: 600, scale: [0.5, 0.3] }),
      sound: { merge: TONE.tink },
    },
    showcase: show(IDLE.sway(6, 150), fall('dot', '#EAF6FF', 14), TONE.tink),
  }),
  def({
    id: 'uncommon-4',
    names: { en: 'Bip the Bot', sv: 'Robotten Bip' },
    rarity: 'uncommon',
    idea: 'Liten robot: alla merge-ljud blir robotpip i skala.',
    draw: [
      L([0, -16], [0, -22], 2.4, '#2A3550'),
      C(0, -24, 3, '#FF86B8', '#5A1233', { edgeW: 1.6 }),
      L([-11, 13], [-9, 21], 3, '#8E9CBC', '#2A3550', { edgeW: 1.4 }),
      L([11, 13], [9, 21], 3, '#8E9CBC', '#2A3550', { edgeW: 1.4 }),
      P(roundRect(-10, 6, 20, 13, 4), '#B8C4DC', '#2A3550'),
      C(0, 12.5, 2.2, '#FFD447', '#5C4000', { edgeW: 1.2 }),
      P(roundRect(-15, -16, 30, 23, 6), '#B8C4DC', '#2A3550'),
      P(roundRect(-11, -12, 22, 15, 4), INK),
      P(roundRect(-8, -9.5, 4.4, 6, 1.6), '#8CFFC0'),
      P(roundRect(3.6, -9.5, 4.4, 6, 1.6), '#8CFFC0'),
      Q([-3.4, -1.8], [0, 0.6], [3.4, -1.8], 1.6, '#8CFFC0'),
      C(-15, -4, 2.2, '#8E9CBC', '#2A3550', { edgeW: 1.2 }),
      C(15, -4, 2.2, '#8E9CBC', '#2A3550', { edgeW: 1.2 }),
      ...hands('#8E9CBC', '#2A3550', 9, 22.4, 3.2),
    ],
    anim: anims('zippy', { idle: IDLE.bob(1, 500) }),
    cosmetic: { sound: { merge: TONE.robot }, particleShape: 'confetti', particleTint: '#8CFFC0' },
    showcase: show(once({ rot: 8, ms: 80, ease: 'Stepped' }, { rot: -8, ms: 80, ease: 'Stepped' }, { ms: 80, ease: 'Stepped' }), burst('confetti', '#8CFFC0', 10, 80), { ...TONE.robot, steps: [0, 4, 7, 12], stepMs: 80 }),
  }),
  def({
    id: 'uncommon-5',
    names: { en: 'Dexter the Dragon', sv: 'Draken Dunder' },
    rarity: 'uncommon',
    idea: 'Liten drake som puffar rök när han släpper – aldrig eld, bara puff.',
    draw: [
      P([[-9, -2], [-26, -16], [-22, -7], [-27, -2], [-18, 5]], '#6C7CF0', '#1C2266', { edgeW: 2.2 }),
      P(mx([[-9, -2], [-26, -16], [-22, -7], [-27, -2], [-18, 5]]), '#6C7CF0', '#1C2266', { edgeW: 2.2 }),
      Q([11, 14], [25, 20], [23, 8], 4, '#8C9CFF', '#1C2266', { edgeW: 1.8 }),
      P([[21, 9], [26, 3], [26, 11]], '#FFE9A0', '#5C4000', { edgeW: 1.4 }),
      P([[-9, -8], [-10, -19], [-3, -11]], '#FFE9A0', '#5C4000', { edgeW: 1.6 }),
      P([[9, -8], [10, -19], [3, -11]], '#FFE9A0', '#5C4000', { edgeW: 1.6 }),
      C(0, 4, 15, '#8C9CFF', '#1C2266'),
      E(0, 11, 16, 11, '#D6DCFF'),
      shine(-4, -5, 11, 4),
      ...eyes('dot', -5, 5, 0),
      C(-2, 5, 0.9, '#1C2266'),
      C(2, 5, 0.9, '#1C2266'),
      ...mouth('smile', 0, 7, 0.8),
      P([[1.5, 8.6], [3, 8.4], [2.3, 10.4]], WHITE),
      ...cheeks(-9, 9, 4, 0.7),
      ...hands('#8C9CFF', '#1C2266'),
    ],
    anim: anims('bouncy'),
    cosmetic: {
      sound: { drop: TONE.puff },
      gesture: { on: 'drop', anim: once({ sx: 1.1, sy: 0.9, ms: 70, ease: QO }, { dy: -3, ms: 110, ease: QO }, { ms: 180, ease: BNC }) },
      trail: trail('ring', '#B8B0D8', { everyPx: 30, lifeMs: 520, scale: [0.4, 1.2], alpha: [0.6, 0], gravityY: -30 }),
    },
    showcase: show(DROP.toss, rise('ring', '#C8C0E0', 5, 40), TONE.puff),
  }),
  def({
    id: 'uncommon-6',
    names: { en: 'Cosmo the Cat', sv: 'Katten Kurre' },
    rarity: 'uncommon',
    idea: 'Randig katt som spinner när kedjan i HUD tänds.',
    draw: [
      Q([12, 16], [27, 14], [22, -4], 4, '#FFB870', '#5A2E00', { edgeW: 1.8 }),
      P([[-15, -5], [-12, -22], [-3, -13]], '#FFB870', '#5A2E00'),
      P([[15, -5], [12, -22], [3, -13]], '#FFB870', '#5A2E00'),
      P([[-12.5, -8], [-11.5, -17], [-6, -12]], '#FFD2E0'),
      P([[12.5, -8], [11.5, -17], [6, -12]], '#FFD2E0'),
      E(0, 4, 32, 30, '#FFB870', '#5A2E00'),
      L([0, -10], [0, -6], 2.2, '#E08A3C'),
      L([-4, -10], [-3, -7], 2, '#E08A3C'),
      L([4, -10], [3, -7], 2, '#E08A3C'),
      L([-15, 2], [-11, 3], 2, '#E08A3C'),
      L([15, 2], [11, 3], 2, '#E08A3C'),
      E(0, 7, 13, 8, '#FFF0DC'),
      ...eyes('dot', -6, 6, 0),
      P([[-1.6, 4], [1.6, 4], [0, 5.8]], '#FF8FB8'),
      ...mouth('cat', 0, 6.6, 0.75),
      L([-4, 7], [-13, 5], 1, '#5A2E00'),
      L([4, 7], [13, 5], 1, '#5A2E00'),
      ...hands('#FFB870', '#5A2E00'),
    ],
    anim: anims('springy', { idle: IDLE.breathe(1.03, 1000) }),
    cosmetic: {
      sound: { newLevel: TONE.purr },
      gesture: { on: 'newLevel', anim: once({ sy: 0.94, sx: 1.05, rot: -4, ms: 300, ease: IO }, { rot: 4, ms: 300, ease: IO }, { ms: 200, ease: IO }) },
      particleShape: 'heart',
      particleTint: '#FFD2E0',
    },
    showcase: show(once({ sy: 0.94, rot: -5, ms: 250, ease: IO }, { rot: 5, ms: 250, ease: IO }, { ms: 200, ease: IO }), rise('heart', '#FFD2E0', 5, 50), TONE.purr),
  }),
  def({
    id: 'uncommon-7',
    names: { en: 'Bella the Balloon', sv: 'Ballongen Bella' },
    rarity: 'uncommon',
    idea: 'Ballong som håller objektet i snöret och släpper konfetti när rekordet närmar sig.',
    draw: [
      Q([0, 11], [-5, 17], [0, 20.5], 1.6, '#EAF2FF'),
      RING(0, 22.6, 2.4, 1.6, '#EAF2FF'),
      P([[-2.5, 12.5], [2.5, 12.5], [0, 9]], '#FF8AC8', '#5A1038', { edgeW: 1.6 }),
      E(0, -7, 30, 34, '#FF8AC8', '#5A1038'),
      E(-7, -16, 6, 10, WHITE, undefined, 0.4, { alpha: 0.45 }),
      ...eyes('dot', -5, 5, -7),
      ...mouth('smile', 0, -2.5, 0.8),
      ...cheeks(-9, 9, -3, 0.8),
    ],
    anim: anims('floaty', { idle: IDLE.sway(4, 800) }),
    cosmetic: {
      sound: { record: TONE.squeak },
      gesture: { on: 'record', anim: CHAIN.spinFloat },
      particleShape: 'confetti',
      particleTint: '#FF8AC8',
    },
    showcase: show(CHAIN.spinFloat, burst('confetti', ['#FF8AC8', '#FFD447', '#6EE7A0', '#5AA9FF'], 16, 100, 700, 120), TONE.squeak),
  }),
  def({
    id: 'uncommon-8',
    names: { en: 'Pirate Pete', sv: 'Pirat-Pelle' },
    rarity: 'uncommon',
    idea: 'Pirat med lapp för ögat: "Arrr!" och en skattkista-gest vid Klunk.',
    draw: [
      C(0, 5, 15, '#FFD2B0', '#5C3418'),
      P([[-19, -9], [-12, -22], [0, -17], [12, -22], [19, -9], [0, -5]], '#6B4E9C', '#1A1030'),
      Q([-18, -9], [0, -3], [18, -9], 2, '#FFD75E'),
      C(0, -14, 2.6, '#F4F7FF'),
      L([-12, -4], [14, 1], 1.6, INK),
      C(5, 3, 4, INK),
      C(-5, 3, 2.9, INK),
      C(-4, 2, 1, WHITE),
      P(arc(0, 10, 5, 4.4, 0, Math.PI, 10), INK),
      P(roundRect(1, 10, 2.4, 2.4, 0.6), '#FFD75E'),
      RING(-15, 10, 2.4, 1.4, '#FFD75E'),
      E(-9, 8, 4.4, 2.6, CHEEK, undefined, 0, { alpha: 0.55 }),
      ...hands('#FFD2B0', '#5C3418'),
    ],
    anim: anims('bouncy', { idle: IDLE.sway(4, 600) }),
    cosmetic: {
      sound: { klunk: TONE.arrr },
      gesture: { on: 'klunk', anim: CHAIN.bigHop },
      particleShape: 'star',
      particleTint: '#FFD75E',
    },
    showcase: show(CHAIN.bigHop, burst('star', '#FFD75E', 12, 90), TONE.arrr),
  }),
  def({
    id: 'uncommon-9',
    names: { en: 'Gracie the Ghost', sv: 'Spöket Svischa' },
    rarity: 'uncommon',
    idea: 'Snällt spöke: allt hon släpper lämnar genomskinliga efterbilder.',
    draw: [
      E(-17, 6, 8, 5, '#ECE8FF', '#4A4380', -0.5, { edgeW: 2 }),
      E(17, 6, 8, 5, '#ECE8FF', '#4A4380', 0.5, { edgeW: 2 }),
      P(
        [...arc(0, -2, 16, 16, Math.PI, 2 * Math.PI, 18), [16, 16], [11, 21.5], [6, 16], [0, 21.5], [-6, 16], [-11, 21.5], [-16, 16]],
        '#ECE8FF',
        '#4A4380',
        { alpha: 0.95 },
      ),
      shine(-5, -10, 11, 5),
      E(-5.5, -3, 5, 7, INK),
      E(5.5, -3, 5, 7, INK),
      C(-4.6, -4.6, 1.1, WHITE),
      C(6.4, -4.6, 1.1, WHITE),
      E(0, 6, 4.6, 5.6, INK),
      ...cheeks(-10, 10, 2, 0.8),
    ],
    anim: anims('floaty', { idle: IDLE.float(3.5, 1300) }),
    cosmetic: { trail: trail('dot', '#ECE8FF', { everyPx: 26, lifeMs: 380, scale: [2.2, 2.2], alpha: [0.22, 0], driftPx: 0 }), sound: { drop: TONE.wooo } },
    showcase: show(once({ dx: -6, ms: 200, ease: IO }, { dx: 6, ms: 300, ease: IO }, { ms: 200, ease: IO }), rings('#ECE8FF', 2, 40), TONE.wooo),
  }),
  def({
    id: 'uncommon-10',
    names: { en: 'Dilly the Drum', sv: 'Trumslagaren Trumma' },
    rarity: 'uncommon',
    idea: 'Levande trumma: varje drop är ett trumslag och combon bygger takten.',
    draw: [
      L([-6, -8], [-18, -24], 2.6, '#E8C48A', '#5C3418', { edgeW: 1.2 }),
      L([6, -8], [18, -24], 2.6, '#E8C48A', '#5C3418', { edgeW: 1.2 }),
      C(-18.5, -24.5, 2.6, '#FFF4DC', '#5C3418', { edgeW: 1.2 }),
      C(18.5, -24.5, 2.6, '#FFF4DC', '#5C3418', { edgeW: 1.2 }),
      L([-14, 11], [-9, 21], 3, '#8FB4FF', '#1A2F66', { edgeW: 1.4 }),
      L([14, 11], [9, 21], 3, '#8FB4FF', '#1A2F66', { edgeW: 1.4 }),
      E(0, 14, 30, 8, '#8FB4FF', '#1A2F66'),
      P([[-15, -6], [15, -6], [15, 14], [-15, 14]], '#8FB4FF'),
      L([-15, -6], [-15, 14], EDGE_W, '#1A2F66'),
      L([15, -6], [15, 14], EDGE_W, '#1A2F66'),
      PL([[-14, 12], [-10, 8], [-6, 12], [-2, 8], [2, 12], [6, 8], [10, 12], [14, 8]], 1.8, WHITE, { alpha: 0.85 }),
      E(0, -6, 30, 9, '#FFF4DC', '#5C4526'),
      ...eyes('dot', -5, 5, 2),
      ...mouth('open', 0, 5, 0.7),
      ...cheeks(-10, 10, 4, 0.7),
      ...hands('#8FB4FF', '#1A2F66'),
    ],
    anim: anims('bouncy', { idle: IDLE.bob(1.2, 500) }),
    cosmetic: { sound: { drop: TONE.drum }, gesture: { on: 'drop', anim: once({ sy: 0.88, ms: 50, ease: QO }, { ms: 150, ease: BO }) } },
    showcase: show(once({ sy: 0.88, ms: 60, ease: QO }, { ms: 120, ease: BO }, { sy: 0.88, ms: 60, ease: QO }, { ms: 200, ease: BO }), rings('#FFF4DC', 2, 38), { ...TONE.drum, steps: [0, 0], stepMs: 180 }),
  }),
  def({
    id: 'uncommon-11',
    names: { en: 'Ned the Narwhal', sv: 'Narvalen Nisse' },
    rarity: 'uncommon',
    idea: 'Narval med spiralhorn som sjunger en liten valsång vid kedjor.',
    draw: [
      P([[-2, -11], [4, -12], [13, -27]], '#FFF4DC', '#5C4526', { edgeW: 2 }),
      L([2.4, -15], [5, -15.8], 1.2, '#5C4526'),
      L([4.8, -19], [7.2, -19.8], 1.2, '#5C4526'),
      L([7.4, -22.8], [9.4, -23.6], 1.2, '#5C4526'),
      E(-13, 18, 11, 6, '#9CC8FF', '#1A3A66', 0.5, { edgeW: 2.2 }),
      E(13, 18, 11, 6, '#9CC8FF', '#1A3A66', -0.5, { edgeW: 2.2 }),
      E(0, 4, 34, 30, '#9CC8FF', '#1A3A66'),
      E(0, 11, 22, 13, '#E4F0FF'),
      C(-10, -5, 1.6, '#6C98D8'),
      C(11, -3, 1.3, '#6C98D8'),
      C(8, -9, 1.1, '#6C98D8'),
      shine(-5, -6, 12, 4),
      ...eyes('dot', -6, 6, 1),
      ...mouth('smile', 0, 5.5, 0.8),
      ...cheeks(-10, 10, 5, 0.75),
      ...hands('#9CC8FF', '#1A3A66'),
    ],
    anim: anims('floaty', { idle: IDLE.float(2, 1100) }),
    cosmetic: { sound: { chain: TONE.song }, particleShape: 'bubble', particleTint: '#C7DDFF' },
    showcase: show(CHAIN.spinFloat, rise('note', '#C7DDFF', 4, 60), TONE.song),
  }),
  def({
    id: 'uncommon-12',
    names: { en: 'Axel the Axolotl', sv: 'Axolotln Axel' },
    rarity: 'uncommon',
    idea: 'Ständigt leende axolotl vars gälar fladdrar när något landar.',
    draw: [
      ...([[-13, -5, -23, -15], [-14, -2, -24.6, -7], [-13, 1, -23, 3]] as const).flatMap(([x0, y0, x1, y1]): AvatarOp[] => [
        Q([x0, y0], [(x0 + x1) / 2, y1 - 3], [x1, y1], 2.8, '#FF6FB5', '#5C1A43', { edgeW: 1.2 }),
        C(x1, y1, 2.4, '#FF6FB5', '#5C1A43', { edgeW: 1.2 }),
        Q([-x0, y0], [-(x0 + x1) / 2, y1 - 3], [-x1, y1], 2.8, '#FF6FB5', '#5C1A43', { edgeW: 1.2 }),
        C(-x1, y1, 2.4, '#FF6FB5', '#5C1A43', { edgeW: 1.2 }),
      ]),
      E(0, 15, 18, 14, '#FFB5DF', '#5C1A43'),
      E(0, 0, 32, 24, '#FFB5DF', '#5C1A43'),
      shine(-4, -7, 12, 4),
      ...eyes('dot', -8, 8, -1),
      Q([-6, 3], [0, 8], [6, 3], 2, INK),
      ...cheeks(-11, 11, 3, 0.75),
      ...hands('#FFB5DF', '#5C1A43'),
    ],
    anim: anims('springy', { idle: IDLE.sway(3, 600) }),
    cosmetic: { sound: { land: TONE.blubb }, gesture: { on: 'land', anim: once({ sx: 1.08, ms: 80, ease: QO }, { ms: 200, ease: 'Elastic.easeOut' }) }, particleShape: 'heart', particleTint: '#FFB5DF' },
    showcase: show(MERGE.puff, burst('heart', '#FFB5DF', 8, 70), TONE.blubb),
  }),
];

// ================================================================ SÄLLSYNT (9) – känsloförmåga

/** Molnkropp: kontur-pass först, sedan fyllning ovanpå så att inre linjer försvinner. */
function cloud(parts: readonly (readonly [number, number, number])[], color: string, edge: string): AvatarOp[] {
  return [
    ...parts.map(([x, y, r]) => C(x, y, r, color, edge, { edgeW: 3.2 })),
    ...parts.map(([x, y, r]) => C(x, y, r - 0.2, color)),
  ];
}

const RARE: AvatarDef[] = [
  def({
    id: 'muller',
    names: { en: 'Theo the Thundercloud', sv: 'Åskmolnet Muller' },
    rarity: 'rare',
    idea: 'Buttert åskmoln som mullrar till och slår små blixtar när kedjan går.',
    draw: [
      P([[9, 7], [16, 7], [12.5, 13], [18, 13], [8, 26], [10.5, 17], [5.5, 17]], '#FFD447', '#5C4000', { edgeW: 2 }),
      ...cloud([[-10, 3, 10], [0, -5, 13], [11, 1, 10], [0, 7, 11], [-15, 9, 6], [15, 8, 6]], '#C4D2EE', '#2A3A5C'),
      shine(-3, -12, 12, 5),
      L([-9, -6], [-3, -4], 2, INK),
      L([9, -6], [3, -4], 2, INK),
      ...eyes('dot', -6, 6, -1, 0.9),
      PL([[-4, 6], [-2, 4.6], [0, 6], [2, 4.6], [4, 6]], 1.8, INK),
      ...cloud([[-9, 22.4, 3.8], [9, 22.4, 3.8]], '#C4D2EE', '#2A3A5C'),
    ],
    anim: anims('heavy', { chain: CHAIN.stomp }),
    cosmetic: { particleShape: 'bolt', particleTint: '#FFD447' },
    ability: {
      key: 'thunderChain',
      params: {
        // Vid kedja ≥3: shake ×mul (taket 8 px gäller; AV i Lugnt läge), N sicksack-blixtar (streck, ingen skärmblixt).
        I: { shakeMul: 1.2, bolts: 3, boltMs: 260, rumbleGain: 0.18 },
        II: { shakeMul: 1.3, bolts: 3, boltMs: 280, rumbleGain: 0.2 },
        III: { shakeMul: 1.4, bolts: 4, boltMs: 300, rumbleGain: 0.22 },
      },
    },
    showcase: show(CHAIN.stomp, { kind: 'bolts', color: '#FFD447', count: 3, len: 22, ms: 260, staggerMs: 90 }, { wave: 'sawtooth', baseHz: 55, glideTo: 40, attack: 0.01, decay: 0.5, gain: 0.2, lowpassHz: 400 }, 200),
  }),
  def({
    id: 'maestro',
    names: { en: 'Conrad the Conductor', sv: 'Dirigenten Maestro' },
    rarity: 'rare',
    idea: 'Liten fågeldirigent med taktpinne: combon spelar en riktig melodi.',
    draw: [
      L([14, 2], [25, -19], 2, '#F4F7FF', '#2F1A66', { edgeW: 0.9 }),
      C(25, -19.5, 1.6, '#F4F7FF'),
      Q([-3, -13], [-8, -24], [-13, -22], 3, '#F4F7FF', '#2F1A66', { edgeW: 1.2 }),
      Q([1, -14], [2, -26], [7, -25], 3, '#F4F7FF', '#2F1A66', { edgeW: 1.2 }),
      Q([-1, -14], [-3, -25], [-2, -27], 3, '#F4F7FF', '#2F1A66', { edgeW: 1.2 }),
      C(0, 3, 16, '#B7A6FF', '#2F1A66'),
      E(15, 0, 7, 13, '#B7A6FF', '#2F1A66', -0.7, { edgeW: 2.2 }),
      E(0, 9, 18, 12, '#E4DCFF'),
      shine(-5, -7, 12, 5),
      ...eyes('happy', -5, 5, -3),
      P([[-2.6, 0], [2.6, 0], [0, 3.6]], '#FFB547', '#5C3000', { edgeW: 1.1 }),
      ...cheeks(-9, 9, 2, 0.7),
      P([[0, 11], [-6, 8], [-6, 14]], '#FF5FA2', '#55103A', { edgeW: 1.4 }),
      P([[0, 11], [6, 8], [6, 14]], '#FF5FA2', '#55103A', { edgeW: 1.4 }),
      C(0, 11, 1.6, '#FF5FA2', '#55103A', { edgeW: 1 }),
      ...hands('#B7A6FF', '#2F1A66'),
    ],
    anim: anims('stately', { merge: once({ rot: -8, ms: 90, ease: QO }, { rot: 6, ms: 110, ease: IO }, { ms: 120, ease: BO }) }),
    cosmetic: { particleShape: 'note', particleTint: '#E4DCFF' },
    ability: {
      key: 'comboMelody',
      params: {
        // Merge-tonen ersätts av nästa ton i melodin (halvtoner över 392 Hz) för combo 1..n. Därefter börjar den om.
        // "Blinka lilla" (trad.). II: + kvint i klangen. III: + bastoner på varje tredje ton.
        I: { melody: [0, 0, 7, 7, 9, 9, 7, 5, 5, 4, 4, 2, 2, 0], harmony: false, bass: false, gain: 1 },
        II: { melody: [0, 0, 7, 7, 9, 9, 7, 5, 5, 4, 4, 2, 2, 0], harmony: true, bass: false, gain: 1 },
        III: { melody: [0, 0, 7, 7, 9, 9, 7, 5, 5, 4, 4, 2, 2, 0], harmony: true, bass: true, gain: 1 },
      },
    },
    showcase: show(
      once({ rot: -10, ms: 140, ease: IO }, { rot: 10, ms: 140, ease: IO }, { rot: -10, ms: 140, ease: IO }, { ms: 140, ease: IO }),
      rise('note', ['#E4DCFF', '#FF5FA2'], 5, 60),
      { wave: 'triangle', baseHz: 392, attack: 0.004, decay: 0.16, gain: 0.2, steps: [0, 0, 7, 7, 9, 9, 7], stepMs: 110, harmonicSemitones: 7, harmonicGain: 0.3 },
    ),
  }),
  def({
    id: 'tick',
    names: { en: 'Tick the Time Owl', sv: 'Tidsugglan Tick' },
    rarity: 'rare',
    idea: 'Uggla med klockögon: faran blir sepiatonad och tickar lugnt i stället för att brumma.',
    draw: [
      P([[-15, -7], [-14, -22], [-6, -13]], '#D6A878', '#4A3018'),
      P([[15, -7], [14, -22], [6, -13]], '#D6A878', '#4A3018'),
      E(-14, 8, 8, 16, '#B88A5A', '#4A3018', 0.25),
      E(14, 8, 8, 16, '#B88A5A', '#4A3018', -0.25),
      E(0, 3, 30, 36, '#D6A878', '#4A3018'),
      E(0, -4, 27, 16, '#F7E6CC'),
      Q([-4, 10], [-2, 12.5], [0, 10], 1.4, '#8A6040'),
      Q([0, 10], [2, 12.5], [4, 10], 1.4, '#8A6040'),
      Q([-2, 15], [0, 17.5], [2, 15], 1.4, '#8A6040'),
      C(-6.5, -4, 6, WHITE, INK, { edgeW: 1.4 }),
      C(6.5, -4, 6, WHITE, INK, { edgeW: 1.4 }),
      L([-6.5, -4], [-6.5, -8.2], 1.4, INK),
      L([-6.5, -4], [-3.6, -3], 1.4, INK),
      L([6.5, -4], [6.5, -8.2], 1.4, INK),
      L([6.5, -4], [9.4, -3], 1.4, INK),
      C(-6.5, -4, 1, INK),
      C(6.5, -4, 1, INK),
      P([[-2, 1], [2, 1], [0, 4.6]], '#FFB547', '#5C3000', { edgeW: 1.1 }),
      ...hands('#FFB547', '#5C3000', 8, 22.2, 3.2),
    ],
    anim: anims('stately', { danger: loop({ rot: -6, ms: 500, ease: 'Stepped' }, { rot: 6, ms: 500, ease: 'Stepped' }) }),
    cosmetic: {},
    ability: {
      key: 'dangerStyle',
      params: {
        // Vid fara: samma slow-mo som vanligt (0,6×), men desaturering byts mot sepia-ton (alpha på en varm overlay)
        // och den dova tonen mot ett lugnt tick-tack (2 Hz ljud, ingen bild blinkar). Klockring runt farolinjen, statisk.
        I: { sepiaAlpha: 0.22, tickGain: 0.1, clockRing: true },
        II: { sepiaAlpha: 0.25, tickGain: 0.12, clockRing: true },
        III: { sepiaAlpha: 0.28, tickGain: 0.13, clockRing: true },
      },
    },
    showcase: show(
      once({ rot: -6, ms: 250, ease: 'Stepped' }, { rot: 6, ms: 250, ease: 'Stepped' }, { rot: -6, ms: 250, ease: 'Stepped' }, { ms: 250, ease: 'Stepped' }),
      { kind: 'rings', color: '#F7E6CC', count: 1, fromR: 26, toR: 44, width: 3, ms: 1000, staggerMs: 0 },
      { wave: 'square', baseHz: 1200, attack: 0.001, decay: 0.03, gain: 0.07, lowpassHz: 2600, steps: [0, -5, 0, -5], stepMs: 250 },
      0,
    ),
  }),
  def({
    id: 'fia',
    names: { en: 'Firework Faye', sv: 'Fyrverkeri-Fia' },
    rarity: 'rare',
    idea: 'Liten rosa raket som skjuter upp egna fyrverkerier när du slår rekord.',
    draw: [
      P([[-8, 7], [-17, 20], [-8, 17]], '#C77DFF', '#2F1056'),
      P([[8, 7], [17, 20], [8, 17]], '#C77DFF', '#2F1056'),
      E(0, 3, 21, 36, '#FF8AC8', '#5A1038'),
      P([[-9.4, -8], [-5, -16], [0, -22], [5, -16], [9.4, -8], [0, -10.4]], '#FFD447', '#5C4000', { edgeW: 2.2 }),
      C(0, 2, 4.6, '#EAF2FF', '#5A1038', { edgeW: 1.6 }),
      shine(-4, -4, 5, 10),
      ...eyes('dot', -4.4, 4.4, 9, 0.8),
      ...mouth('grin', 0, 13.5, 0.55),
      ...cheeks(-7, 7, 12, 0.6),
      spark(-12, -18, 3.4, '#FFD447'),
      spark(13, -14, 2.6, '#FFD447'),
      spark(-15, -6, 2, '#FFF4DC'),
      ...hands('#FF8AC8', '#5A1038'),
    ],
    anim: anims('bouncy', { chain: CHAIN.bigHop }),
    cosmetic: { particleShape: 'star', particleTint: '#FFD447' },
    ability: {
      key: 'recordFanfare',
      params: {
        // Vid newRecord: N raketer stiger från burkens botten och slår ut i stjärnringar (partiklar, ingen vitblixt),
        // egen fanfar ersätter newRecord-ljudet. Påverkar inte poäng.
        I: { rockets: 3, starsPerRocket: 14, fanfare: [0, 4, 7, 12, 7, 12] },
        II: { rockets: 3, starsPerRocket: 16, fanfare: [0, 4, 7, 12, 7, 12, 16] },
        III: { rockets: 4, starsPerRocket: 18, fanfare: [0, 4, 7, 12, 7, 12, 16] },
      },
    },
    showcase: show(
      once({ sy: 0.85, ms: 120, ease: QO }, { dy: -14, sy: 1.1, ms: 200, ease: CO }, { ms: 300, ease: BNC }),
      burst('star', ['#FFD447', '#FF8AC8', '#C77DFF', '#FFF4DC'], 18, 110, 700, 40),
      { wave: 'triangle', baseHz: 523.25, attack: 0.004, decay: 0.24, gain: 0.22, steps: [0, 4, 7, 12], stepMs: 90, harmonicSemitones: 12, harmonicGain: 0.25 },
      260,
    ),
  }),
  def({
    id: 'vulle',
    names: { en: 'Vinnie the Volcano', sv: 'Vulkanen Vulle' },
    rarity: 'rare',
    idea: 'Varm liten vulkan: stora merges (nivå ≥8) sprutar lava och en djup bas.',
    draw: [
      C(-3, -21, 4, '#C8C0D8', undefined, { alpha: 0.85 }),
      C(3, -24.5, 3, '#C8C0D8', undefined, { alpha: 0.7 }),
      P([[-23, 20], [-8, -12], [8, -12], [23, 20]], '#C98A6A', '#3A1A0E'),
      P([[-8.6, -11], [-6, -3], [-3, -10], [0, -1], [3, -10], [5.6, -5], [8.6, -11]], '#FFB547', '#5C3000', { edgeW: 1.6 }),
      E(0, -12, 17, 5, '#FFB547', '#5C3000', 0, { edgeW: 2 }),
      L([-14, 14], [-9, 12], 1.6, '#8A5A44'),
      L([12, 10], [16, 14], 1.6, '#8A5A44'),
      shine(-7, 0, 8, 12, 0.35),
      ...eyes('dot', -6, 6, 5),
      ...mouth('open', 0, 11, 0.8),
      ...cheeks(-10, 10, 9, 0.75),
      ...hands('#C98A6A', '#3A1A0E'),
    ],
    anim: anims('heavy', { merge: MERGE.shrug }),
    cosmetic: { particleShape: 'drop', particleTint: '#FFB547' },
    ability: {
      key: 'lavaMerge',
      params: {
        // Merge som skapar nivå ≥ minLevel: lavadroppar (korall/bärnsten, aldrig mättad röd) sprutar upp och faller,
        // plus 55 Hz sub-bas under merge-ljudet.
        I: { minLevel: 8, drops: 10, subHz: 55, subGain: 0.24 },
        II: { minLevel: 8, drops: 12, subHz: 55, subGain: 0.28 },
        III: { minLevel: 8, drops: 13, subHz: 55, subGain: 0.3 },
      },
    },
    showcase: show(
      once({ dx: -1.5, ms: 60, ease: IO }, { dx: 1.5, ms: 120, ease: IO }, { dx: -1.5, ms: 120, ease: IO }, { sy: 0.9, ms: 80, ease: QO }, { dy: -5, ms: 140, ease: QO }, { ms: 200, ease: BNC }),
      burst('drop', ['#FFB547', '#FF8766'], 12, 110, 700, 260),
      { wave: 'sine', baseHz: 55, attack: 0.01, decay: 0.6, gain: 0.35 },
      380,
    ),
  }),
  def({
    id: 'disco',
    names: { en: 'Dizzy the Disco Ball', sv: 'Discokulan Disco' },
    rarity: 'rare',
    idea: 'Coolaste discokulan: bakgrunden gungar mjukt i takt med combon.',
    draw: [
      L([0, -18], [0, -27], 1.6, '#EAF2FF'),
      P(roundRect(-3.5, -20, 7, 4, 1), '#8E9CBC', '#2A3550', { edgeW: 1.4 }),
      C(0, 1, 17, '#D8E0F0', '#3A4A6B'),
      Q([-16, -5], [0, -9], [16, -5], 1.2, '#8E9CBC'),
      Q([-17, 3], [0, -1], [17, 3], 1.2, '#8E9CBC'),
      Q([-15, 10], [0, 7], [15, 10], 1.2, '#8E9CBC'),
      Q([-6, -15], [-10, 1], [-6, 17], 1.2, '#8E9CBC'),
      Q([6, -15], [10, 1], [6, 17], 1.2, '#8E9CBC'),
      P(roundRect(-14, -8, 5, 4, 1), '#8CFFC0'),
      P(roundRect(9, -10, 5, 4, 1), '#FF86B8'),
      P(roundRect(-12, 9, 5, 4, 1), '#FFD447'),
      P(roundRect(8, 11, 5, 4, 1), '#B7A6FF'),
      E(-6, -1, 10, 6.4, INK),
      E(6, -1, 10, 6.4, INK),
      L([-1, -1.4], [1, -1.4], 1.6, INK),
      L([-9, -2.4], [-5, -3], 1, WHITE, undefined, { alpha: 0.8 }),
      L([3, -2.4], [7, -3], 1, WHITE, undefined, { alpha: 0.8 }),
      ...mouth('smirk', 0, 6.5, 0.8),
      ...hands('#D8E0F0', '#3A4A6B'),
    ],
    anim: anims('zippy', { idle: IDLE.sway(6, 500), chain: CHAIN.flip }),
    cosmetic: { particleShape: 'confetti', particleTint: 'combo' },
    ability: {
      key: 'discoBg',
      params: {
        // 12–16 färgade ljusfläckar på bakgrunden (bakom burken) som roterar 20°/s. Varje merge höjer deras alpha ett
        // steg (combo) och de pulsar max 1 gång per 500 ms (≤2 Hz, flash-guard), amplitud ≤ maxAlpha.
        I: { spots: 12, maxAlpha: 0.1, stepAlpha: 0.012, minIntervalMs: 500 },
        II: { spots: 14, maxAlpha: 0.12, stepAlpha: 0.013, minIntervalMs: 500 },
        III: { spots: 16, maxAlpha: 0.13, stepAlpha: 0.014, minIntervalMs: 500 },
      },
    },
    showcase: show(
      once({ rot: 12, ms: 250, ease: IO }, { rot: -12, ms: 250, ease: IO }, { ms: 200, ease: IO }),
      { kind: 'orbit', shape: 'dot', tint: ['#8CFFC0', '#FF86B8', '#FFD447', '#B7A6FF'], count: 8, r: 36, turns: 0.5, ms: 900 },
      { wave: 'square', baseHz: 261.63, attack: 0.004, decay: 0.12, gain: 0.12, lowpassHz: 1800, steps: [0, 12, 7, 12], stepMs: 150 },
      0,
    ),
  }),
  def({
    id: 'eko',
    names: { en: 'Echo the Echo', sv: 'Ekot Eko' },
    rarity: 'rare',
    idea: 'Ropar in i en grotta: varje merge ekar tillbaka som i en katedral.',
    draw: [
      RING(-12, 2, 14, 2, '#A6B8FF', { alpha: 0.2, noSil: true }),
      RING(-6, 2, 15, 2.2, '#A6B8FF', { alpha: 0.4, noSil: true }),
      C(2, 2, 15, '#A6B8FF', '#1C2A6B'),
      shine(-2, -7, 11, 4),
      ...eyes('happy', -3, 8, -3),
      E(3, 6.5, 7, 8, INK),
      E(3, 8.6, 4, 2.4, TONGUE),
      Q([19, -4], [23, 2], [19, 8], 2, '#A6B8FF', undefined, { noSil: true }),
      Q([22.5, -8], [28, 2], [22.5, 12], 2, '#A6B8FF', undefined, { alpha: 0.5, noSil: true }),
      ...cheeks(-5, 11, 3, 0.7),
      ...hands('#A6B8FF', '#1C2A6B'),
    ],
    anim: anims('floaty'),
    cosmetic: { particleShape: 'ring', particleTint: '#A6B8FF' },
    ability: {
      key: 'echoMerge',
      params: {
        // Delay-linje på merge-ljudet (feedback-eko) + 2–3 tunna ringar som expanderar fördröjt från merge-punkten.
        I: { delayMs: 180, feedback: 0.35, wet: 0.3, rings: 2 },
        II: { delayMs: 180, feedback: 0.4, wet: 0.34, rings: 2 },
        III: { delayMs: 180, feedback: 0.45, wet: 0.38, rings: 3 },
      },
    },
    showcase: show(
      once({ sx: 1.08, sy: 0.94, ms: 100, ease: QO }, { ms: 300, ease: BO }),
      { kind: 'rings', color: '#A6B8FF', count: 3, fromR: 20, toR: 52, width: 2.4, ms: 600, staggerMs: 180 },
      { wave: 'triangle', baseHz: 523.25, attack: 0.004, decay: 0.3, gain: 0.2, steps: [0, 0, 0], stepMs: 180, harmonicSemitones: 7, harmonicGain: 0.3 },
      60,
    ),
  }),
  def({
    id: 'klick',
    names: { en: 'Clicky the Camera', sv: 'Kameran Klick' },
    rarity: 'rare',
    idea: 'Glad retrokamera som tar en polaroid av rundans största kedja.',
    draw: [
      L([-12, 14], [-9, 21], 3, '#9CD6C4', '#0E4A40', { edgeW: 1.4 }),
      L([12, 14], [9, 21], 3, '#9CD6C4', '#0E4A40', { edgeW: 1.4 }),
      P(roundRect(-12, -17, 10, 7, 2), '#9CD6C4', '#0E4A40', { edgeW: 2.2 }),
      P(roundRect(4, -16, 9, 5, 1.6), '#F4F7FF', '#0E4A40', { edgeW: 2 }),
      P(roundRect(-17, -12, 34, 27, 6), '#9CD6C4', '#0E4A40'),
      L([-17, -5], [17, -5], 1.6, '#0E4A40', undefined, { alpha: 0.5 }),
      C(4, 2, 9.6, INK, '#0E4A40'),
      C(4, 2, 6.4, '#5C8CC4'),
      C(4, 2, 3, '#2A4A7A'),
      C(1.8, -0.4, 2, WHITE, undefined, { alpha: 0.9 }),
      C(-10.5, -1, 2.6, INK),
      C(-9.6, -1.9, 0.9, WHITE),
      ...mouth('smile', -10, 5, 0.6),
      E(-13, 3, 3.6, 2.2, CHEEK, undefined, 0, { alpha: 0.55 }),
      ...hands('#9CD6C4', '#0E4A40'),
    ],
    anim: anims('bouncy'),
    cosmetic: {},
    ability: {
      key: 'polaroid',
      params: {
        // Under rundan: spara en bild (RenderTexture/snapshot av burken, 120×160) i ögonblicket då den längsta
        // kedjan toppar. I rundavslutet: polaroiden glider in snett (−6°) nere till vänster, 400 ms Back.easeOut.
        // Slutare = två svarta lameller som stängs/öppnas EN gång (120 ms), aldrig vitblixt.
        // III: två bilder (längsta kedjan + högsta nivån), bredvid varandra.
        I: { photos: 1, frameTint: false },
        II: { photos: 1, frameTint: true },
        III: { photos: 2, frameTint: true },
      },
    },
    showcase: show(
      once({ sy: 0.9, sx: 1.06, ms: 80, ease: QO }, { ms: 200, ease: BO }),
      { kind: 'burst', shape: 'confetti', tint: '#F4F7FF', count: 1, speed: 0, lifeMs: 900 },
      { wave: 'square', baseHz: 1800, glideTo: 900, attack: 0.001, decay: 0.04, gain: 0.08, lowpassHz: 3000, steps: [0, 5], stepMs: 90 },
      80,
    ),
  }),
  def({
    id: 'nora',
    names: { en: 'Aurora the Arctic Fox', sv: 'Norrsken-Nora' },
    rarity: 'rare',
    idea: 'Fjällräv med norrskenssvans: långa kedjor tänder norrsken över burken.',
    draw: [
      Q([8, 15], [30, 8], [21, -22], 5, '#6EE7A0', '#1E4A30', { edgeW: 1.4 }),
      Q([6, 13], [26, 6], [16, -20], 4, '#8FB4FF'),
      Q([5, 12], [22, 5], [12, -16], 3, '#C77DFF'),
      E(0, 15, 16, 13, '#F4F2FF', '#3A3A6B'),
      P([[-14, -3], [-12, -22], [-3, -12]], '#F4F2FF', '#3A3A6B'),
      P([[14, -3], [12, -22], [3, -12]], '#F4F2FF', '#3A3A6B'),
      P([[-11.5, -7], [-11, -17], [-6, -12]], '#C9B8FF'),
      P([[11.5, -7], [11, -17], [6, -12]], '#C9B8FF'),
      P([[-16, 4], [-12, -10], [0, -13], [12, -10], [16, 4], [8, 10], [0, 11], [-8, 10]], '#F4F2FF', '#3A3A6B'),
      E(0, 6, 12, 7, WHITE),
      shine(-4, -7, 10, 4),
      ...eyes('happy', -6, 6, -2),
      C(0, 3.6, 2, INK),
      ...mouth('smile', 0, 6.4, 0.5),
      ...cheeks(-10, 10, 2, 0.7),
      ...hands('#F4F2FF', '#3A3A6B'),
    ],
    anim: anims('stately'),
    cosmetic: { trail: trail('dot', ['#6EE7A0', '#8FB4FF', '#C77DFF'], { everyPx: 12, blend: 'ADD', alpha: [0.6, 0] }) },
    ability: {
      key: 'auroraChain',
      params: {
        // Kedja ≥3: 2–3 breda norrskensband (kurvor, grön/blå/violett, ADD) tonar in över burkens hals och vajar 0,3 Hz.
        // In 300 ms, håll, ut 600 ms. Aldrig ljusare än alpha-taket.
        I: { minChain: 3, bands: 2, holdMs: 1500, alpha: 0.3 },
        II: { minChain: 3, bands: 3, holdMs: 1800, alpha: 0.34 },
        III: { minChain: 3, bands: 3, holdMs: 1950, alpha: 0.38 },
      },
    },
    showcase: show(
      IDLE.sway(6, 250),
      { kind: 'arc', colors: ['#6EE7A0', '#8FB4FF', '#C77DFF'], r: 44, width: 7, inMs: 260, holdMs: 400, outMs: 400 },
      { wave: 'sine', baseHz: 659.25, attack: 0.08, decay: 0.7, gain: 0.14, vibratoHz: 4, vibratoCents: 20, harmonicSemitones: 7, harmonicGain: 0.5 },
      80,
    ),
  }),
];

// ================================================================ EPISK (6) – informationsförmåga

const EPIC: AvatarDef[] = [
  def({
    id: 'lisa',
    names: { en: 'Lantern Lucy', sv: 'Lykt-Lisa' },
    rarity: 'epic',
    idea: 'Marulk från djupet med en lykta på pannan: den lyser upp de som passar ihop.',
    draw: [
      Q([2, -13], [8, -27], [-8, -22], 2, '#B7A6FF', '#1A1450', { edgeW: 0.9 }),
      C(-9, -21, 7, '#FFF1A8', undefined, { alpha: 0.28, noSil: true }),
      C(-9, -21, 3.8, '#FFF1A8', '#5C4000', { edgeW: 1.3 }),
      P([[10, -10], [18, -16], [15, -6]], '#8F7CFF', '#1A1450', { edgeW: 2 }),
      E(0, 3, 36, 30, '#8F7CFF', '#1A1450'),
      shine(-6, -6, 12, 4),
      ...eyes('dot', -6, 6, -4, 0.95),
      P(arc(0, 4, 12, 9, 0, Math.PI, 14), INK),
      ...[-8, -3, 2, 7].map((x) => P([[x - 1.6, 4.4], [x + 1.6, 4.4], [x, 7.4]], WHITE)),
      ...hands('#8F7CFF', '#1A1450'),
    ],
    anim: anims('floaty', { idle: IDLE.float(2, 1000) }),
    cosmetic: {},
    ability: {
      key: 'sameLevelGlow',
      params: {
        // Medan fingret siktar: objekt i burken av samma nivå som det hängande får en svag stilla ring
        // (hud-vit, alpha 0,35, r·1,18, in 120 ms, ingen puls). Lyktan har "olja" för N sekunders siktning per runda;
        // Lisas lykta krymper synligt när oljan tar slut. (Tolkning av "6/8/10 s", se UI.md §13.8.)
        I: { seconds: 6, ringAlpha: 0.35 },
        II: { seconds: 8, ringAlpha: 0.35 },
        III: { seconds: 10, ringAlpha: 0.35 },
      },
    },
    showcase: show(IDLE.float(3, 300), { kind: 'rings', color: '#FFF1A8', count: 2, fromR: 8, toR: 40, width: 2.4, ms: 700, staggerMs: 250 }, { wave: 'sine', baseHz: 880, attack: 0.05, decay: 0.6, gain: 0.12, vibratoHz: 3, vibratoCents: 15, harmonicSemitones: 12, harmonicGain: 0.3 }, 0),
  }),
  def({
    id: 'siri',
    names: { en: 'Sybil the Seer', sv: 'Spådamen Siri' },
    rarity: 'epic',
    idea: 'Spådam som håller objektet som en kristallkula och ser två steg fram.',
    draw: [
      P([[12, 2], [21, 14], [12, 12]], '#C77DFF', '#2F1056', { edgeW: 2.2 }),
      C(0, -2, 17, '#C77DFF', '#2F1056'),
      E(0, 3, 22, 22, '#FFD9BF', '#5C3418'),
      Q([-10, -5], [0, 0], [10, -5], 3.4, '#5C3418'),
      C(-12, -10, 1.5, '#FFD75E'),
      C(-4, -15, 1.5, '#FFD75E'),
      C(5, -15, 1.5, '#FFD75E'),
      C(12, -10, 1.5, '#FFD75E'),
      C(-15, -1, 1.5, '#FFD75E'),
      ...eyes('lash', -4.4, 4.4, 3, 0.85),
      ...mouth('smile', 0, 8, 0.6),
      ...cheeks(-7, 7, 7, 0.6),
      RING(-11, 10, 2, 1.4, '#FFD75E'),
      RING(11, 10, 2, 1.4, '#FFD75E'),
      spark(-17, 19, 2.6, '#FFF1A8'),
      spark(17, 17, 2, '#FFF1A8'),
      ...hands('#FFD9BF', '#5C3418'),
    ],
    anim: anims('stately', { idle: IDLE.sway(2, 900) }),
    cosmetic: {},
    ability: {
      key: 'queuePeek',
      params: {
        // Förhandsvisningen visar också objektet EFTER nästa: mindre, till vänster om ramen (x 250, y 44),
        // streckad ram 44×44, alpha enligt nivå. Samma information i alla nivåer, bara tydligare.
        I: { steps: 2, ghostR: 12, ghostAlpha: 0.6 },
        II: { steps: 2, ghostR: 14, ghostAlpha: 0.7 },
        III: { steps: 2, ghostR: 15, ghostAlpha: 0.78 },
      },
    },
    showcase: show(
      once({ sx: 1.06, sy: 1.06, ms: 300, ease: IO }, { ms: 300, ease: IO }),
      { kind: 'orbit', shape: 'star', tint: ['#FFF1A8', '#C77DFF'], count: 5, r: 30, turns: 1, ms: 900 },
      { wave: 'sine', baseHz: 1046.5, attack: 0.02, decay: 0.4, gain: 0.12, steps: [0, 3, 7, 10], stepMs: 120, vibratoHz: 6, vibratoCents: 20 },
      0,
    ),
  }),
  def({
    id: 'sixten',
    names: { en: 'Spotter Sam', sv: 'Sikt-Sixten' },
    rarity: 'epic',
    idea: 'Keps och kikarsikte: han visar exakt var det du släpper landar.',
    draw: [
      P(roundRect(-15, -10, 30, 30, 11), '#D8F06A', '#3A4A0A'),
      P(arc(0, -6, 15.6, 13, Math.PI, 2 * Math.PI, 16), '#6C8BFF', '#14235A'),
      P([[4, -8], [22, -6.4], [20, -3], [4, -4]], '#6C8BFF', '#14235A', { edgeW: 2.2 }),
      C(0, -18, 2, '#EAF2FF', '#14235A', { edgeW: 1.2 }),
      shine(-7, 6, 6, 10),
      C(5, 3, 6.4, WHITE, INK, { edgeW: 1.8, alpha: 0.9 }),
      L([5, -2.4], [5, 8.4], 1, INK),
      L([-0.4, 3], [10.4, 3], 1, INK),
      C(5, 3, 2, INK),
      ...eyes('dot', -7, -7, 3, 0.9),
      ...mouth('smirk', -2, 12, 0.8),
      ...hands('#D8F06A', '#3A4A0A'),
    ],
    anim: anims('zippy', { idle: IDLE.hover(1, 700) }),
    cosmetic: {},
    ability: {
      key: 'landingDot',
      params: {
        // Siktlinjen (även i läge 'off') slutar i en prick där objektets underkant först träffar något
        // (raycast längs x mot bodies/golv). II–III: dessutom objektets kontur (streckad, alpha) på landningsplatsen.
        I: { dotR: 5, ghostAlpha: 0 },
        II: { dotR: 6, ghostAlpha: 0.15 },
        III: { dotR: 6.5, ghostAlpha: 0.2 },
      },
    },
    showcase: show(once({ rot: -6, dy: 1, ms: 160, ease: QO }, { ms: 200, ease: BO }), { kind: 'aim', color: '#EAF2FF', len: 56, dotR: 5, ms: 700 }, { wave: 'sine', baseHz: 1318.5, glideTo: 1760, attack: 0.002, decay: 0.12, gain: 0.12, steps: [0, 7], stepMs: 140 }, 60),
  }),
  def({
    id: 'bubbel',
    names: { en: 'Bobby the Bubble', sv: 'Bubblan Bubbel' },
    rarity: 'epic',
    idea: 'En levande såpbubbla: rundans första drop landar mjukt utan studs.',
    draw: [
      C(0, 2, 18, '#CFF4FF', '#1F4660', { alpha: 0.72, edgeW: 2 }),
      RING(0, 2, 15.8, 1.6, '#EAFBFF', { alpha: 0.8 }),
      Q([-12, -6], [-9, -13], [-2, -14], 2.4, WHITE, undefined, { alpha: 0.85 }),
      C(10, 11, 1.8, WHITE, undefined, { alpha: 0.7 }),
      ...eyes('dot', -5, 5, 1),
      ...mouth('smile', 0, 6, 0.8),
      ...cheeks(-10, 10, 5, 0.7),
      RING(-19, -12, 3, 1.4, '#CFF4FF', { noSil: true }),
      RING(20, -8, 2.2, 1.4, '#CFF4FF', { noSil: true }),
      RING(-9, 22.4, 3.2, 1.8, '#CFF4FF'),
      RING(9, 22.4, 3.2, 1.8, '#CFF4FF'),
    ],
    anim: anims('floaty', { merge: MERGE.puff }),
    cosmetic: { trail: trail('bubble', '#CFF4FF', { everyPx: 20, gravityY: -40, scale: [0.4, 0.9] }) },
    ability: {
      key: 'noBounceStart',
      params: {
        // Rundans första N drop har restitution 0 (landar dött, ingen studs). Objektet får en tunn bubbelhinna
        // (ring hud-vit alpha 0,5) tills det landat.
        I: { drops: 10 },
        II: { drops: 12 },
        III: { drops: 15 },
      },
    },
    showcase: show(once({ dy: -6, ms: 180, ease: QO }, { sy: 0.92, sx: 1.06, ms: 180, ease: QI }, { ms: 260, ease: IO }), rise('bubble', '#CFF4FF', 7, 60), TONE.blubb, 200),
  }),
  def({
    id: 'ekko',
    names: { en: 'Sonny the Sonar', sv: 'Ekolodet Ekko' },
    rarity: 'epic',
    idea: 'Liten ubåt med ekolod: när en ny nivå tänds pingar alla av den nivån.',
    draw: [
      Q([17, -18], [21, -14], [19, -9], 1.8, '#7FE3D0', undefined, { noSil: true }),
      Q([20.5, -22], [26, -14], [23, -6], 1.8, '#7FE3D0', undefined, { alpha: 0.55, noSil: true }),
      PL([[4, -10], [4, -20], [11, -20]], 3.4, '#0C4A40'),
      PL([[4, -10], [4, -20], [11, -20]], 1.6, '#7FE3D0'),
      P(roundRect(-6, -13, 15, 9, 3), '#7FE3D0', '#0C4A40'),
      E(-23, 4, 5, 10, '#FFD75E', '#5C4300', 0, { edgeW: 1.6 }),
      E(0, 4, 44, 24, '#7FE3D0', '#0C4A40'),
      shine(-4, -3, 18, 4),
      C(-10, 3, 4.6, '#EAF6FF', INK, { edgeW: 1.8 }),
      C(1, 3, 4.6, '#EAF6FF', INK, { edgeW: 1.8 }),
      C(-9.4, 3.6, 2.2, INK),
      C(1.6, 3.6, 2.2, INK),
      C(-8.6, 2.6, 0.8, WHITE),
      C(2.4, 2.6, 0.8, WHITE),
      C(12, 3, 3.4, '#BFEFE6', '#0C4A40', { edgeW: 1.6 }),
      ...mouth('smile', -4.5, 10, 0.7),
      ...hands('#7FE3D0', '#0C4A40'),
    ],
    anim: anims('floaty', { idle: IDLE.bob(2, 1000) }),
    cosmetic: {},
    ability: {
      key: 'sonarNewLevel',
      params: {
        // När en nivå tänds i HUD-kedjan första gången i rundan: alla objekt av den nivån i burken får en
        // expanderande ring (r → r·1,5, 500 ms), N gånger med 1 000 ms mellanrum (1 Hz, flash-guard). Ping-ljud.
        I: { pulses: 2, periodMs: 1000, ringScale: 1.5 },
        II: { pulses: 2, periodMs: 1000, ringScale: 1.6 },
        III: { pulses: 3, periodMs: 1000, ringScale: 1.6 },
      },
    },
    showcase: show(IDLE.bob(3, 250), { kind: 'rings', color: '#7FE3D0', count: 2, fromR: 18, toR: 52, width: 2.4, ms: 700, staggerMs: 500 }, { wave: 'sine', baseHz: 1567.98, glideTo: 1400, attack: 0.002, decay: 0.3, gain: 0.12, steps: [0, 0], stepMs: 500 }, 0),
  }),
  def({
    id: 'kajsa',
    names: { en: 'Mira the Meerkat', sv: 'Kikaren Kajsa' },
    rarity: 'epic',
    idea: 'Surikat på utkik med kikare: hon ser nästan-träffar långt innan du gör det.',
    draw: [
      C(-10, -14, 3.6, '#E8C48A', '#4A3418', { edgeW: 2.2 }),
      C(10, -14, 3.6, '#E8C48A', '#4A3418', { edgeW: 2.2 }),
      E(0, 12, 20, 21, '#E8C48A', '#4A3418'),
      E(0, 14, 11, 13, '#F7E6CC'),
      E(0, -6, 25, 20, '#E8C48A', '#4A3418'),
      shine(-4, -12, 10, 3.5),
      L([-8, 6], [-8, -2], 4, '#E8C48A', '#4A3418', { edgeW: 1.6 }),
      L([8, 6], [8, -2], 4, '#E8C48A', '#4A3418', { edgeW: 1.6 }),
      P(roundRect(-3, -9.4, 6, 3.6, 1.2), '#4A5A8C', INK, { edgeW: 1.4 }),
      C(-6, -7.5, 5.6, '#5A6FA8', INK, { edgeW: 1.8 }),
      C(6, -7.5, 5.6, '#5A6FA8', INK, { edgeW: 1.8 }),
      C(-6, -7.5, 3, '#AFC8FF', INK, { edgeW: 1 }),
      C(6, -7.5, 3, '#AFC8FF', INK, { edgeW: 1 }),
      C(-7, -8.6, 1, WHITE),
      C(5, -8.6, 1, WHITE),
      E(0, -0.6, 3.4, 2.2, INK),
      ...mouth('smile', 0, 1.6, 0.5),
      ...hands('#E8C48A', '#4A3418'),
    ],
    anim: anims('zippy', { idle: loop({ rot: -8, ms: 600, ease: IO }, { rot: -8, ms: 400, ease: 'Linear' }, { rot: 8, ms: 800, ease: IO }, { rot: 8, ms: 400, ease: 'Linear' }, { ms: 600, ease: IO }) }),
    cosmetic: {},
    ability: {
      key: 'nearMissFrom',
      params: {
        // Near-miss-pulsen (DESIGN §5, äkta, aldrig fejkad) visas från lägre nivå.
        I: { minLevel: 6 },
        II: { minLevel: 5 },
        III: { minLevel: 4 },
      },
    },
    showcase: show(
      once({ rot: -12, ms: 220, ease: IO }, { rot: -12, ms: 160, ease: 'Linear' }, { rot: 12, ms: 300, ease: IO }, { ms: 220, ease: IO }),
      { kind: 'rings', color: '#AFC8FF', count: 2, fromR: 10, toR: 16, width: 2, ms: 500, staggerMs: 0 },
      { wave: 'sine', baseHz: 987.77, attack: 0.01, decay: 0.18, gain: 0.1, steps: [0, 5], stepMs: 380 },
      400,
    ),
  }),
];

// ================================================================ LEGENDARISK (3) – mild spelförmåga

const magnetU: P2[] = [
  [-20, 22],
  [-20, 2],
  ...arc(0, 2, 20, 20, Math.PI, 2 * Math.PI, 18).slice(1, -1),
  [20, 2],
  [20, 22],
  [9, 22],
  [9, 2],
  ...arc(0, 2, 9, 9, 2 * Math.PI, Math.PI, 12).slice(1, -1),
  [-9, 2],
  [-9, 22],
];

const LEGENDARY: AvatarDef[] = [
  def({
    id: 'maja',
    names: { en: 'Magnet Maya', sv: 'Magnet-Maja' },
    rarity: 'legendary',
    idea: 'Hästskomagnet som håller objektet mellan polerna och en gång per runda drar ihop två lika.',
    draw: [
      P(magnetU, '#FF6FA8', '#5A1030'),
      P([[-20, 14], [-9, 14], [-9, 22], [-20, 22]], '#EAF2FF', '#3A4A6B', { edgeW: 2.4 }),
      P([[20, 14], [9, 14], [9, 22], [20, 22]], '#EAF2FF', '#3A4A6B', { edgeW: 2.4 }),
      Q([-15, -5], [-12, -13], [-4, -16], 2.4, WHITE, undefined, { alpha: 0.35 }),
      ...eyes('dot', -5, 5, -12.5, 0.8),
      ...mouth('smile', 0, -9.4, 0.55),
      ...cheeks(-9, 9, -9, 0.55),
      PL([[-25, 6], [-23, 9], [-26, 11], [-24, 14]], 1.6, '#FFD75E', { noSil: true }),
      PL([[25, 6], [23, 9], [26, 11], [24, 14]], 1.6, '#FFD75E', { noSil: true }),
    ],
    anim: anims('stately', { chain: CHAIN.bigHop }),
    cosmetic: { particleShape: 'bolt', particleTint: '#FFD75E' },
    ability: {
      key: 'magnetPull',
      params: {
        // N gånger per runda: när två fria objekt av samma nivå (ej nivå 10) ligger stilla med gap < rangePx i 400 ms,
        // dras de ihop med en kraft under 300 ms (fält-linjer ritas mellan dem). Aldrig under fara-slow-mo.
        I: { uses: 1, rangePx: 40 },
        II: { uses: 1, rangePx: 46 },
        III: { uses: 2, rangePx: 46 },
      },
    },
    showcase: show(
      once({ sy: 1.06, ms: 200, ease: IO }, { sy: 0.94, ms: 160, ease: QI }, { ms: 260, ease: BO }),
      { kind: 'orbit', shape: 'dot', tint: ['#FFD75E', '#EAF2FF'], count: 2, r: 34, turns: -0.5, ms: 600 },
      { wave: 'sine', baseHz: 220, glideTo: 880, attack: 0.01, decay: 0.45, gain: 0.16, vibratoHz: 9, vibratoCents: 30 },
      0,
    ),
  }),
  def({
    id: 'rut',
    names: { en: 'Rainbow Rosie', sv: 'Regnbågs-Rut' },
    rarity: 'legendary',
    idea: 'En regnbåge med molnfötter som alltid har en regnbåge med sig till rundan.',
    draw: [
      PL(arc(0, 16, 16, 16, Math.PI, 2 * Math.PI, 20), 21, '#2F1056'),
      PL(arc(0, 16, 22, 22, Math.PI, 2 * Math.PI, 20), 4.4, '#FF8766'),
      PL(arc(0, 16, 18, 18, Math.PI, 2 * Math.PI, 20), 4.4, '#FFD447'),
      PL(arc(0, 16, 14, 14, Math.PI, 2 * Math.PI, 20), 4.4, '#6EE7A0'),
      PL(arc(0, 16, 10, 10, Math.PI, 2 * Math.PI, 20), 4.4, '#6C8BFF'),
      C(0, -5, 8, '#FFF4DC', '#5C4526', { edgeW: 2.2 }),
      ...eyes('happy', -3, 3, -5.6, 0.8),
      ...mouth('smile', 0, -2.2, 0.55),
      ...cheeks(-5.4, 5.4, -2.4, 0.5),
      ...cloud([[-17, 19, 5], [-12, 21, 4.4], [-21, 21, 3.8]], '#F4F7FF', '#33415C'),
      ...cloud([[17, 19, 5], [12, 21, 4.4], [21, 21, 3.8]], '#F4F7FF', '#33415C'),
      spark(-22, -8, 3, '#FFF4DC'),
      spark(23, -4, 2.4, '#FFF4DC'),
    ],
    anim: anims('stately', { idle: IDLE.bob(1.5, 1000) }),
    cosmetic: { particleShape: 'star', particleTint: 'combo' },
    ability: {
      key: 'startRainbow',
      params: {
        // Regnbågsobjektet (DESIGN §4) läggs i kön som drop nr `rainbowAtDrop` (efter onboarding-flödet).
        // III: dessutom en bomb som drop nr `bombAtDrop`. Påverkar inte regissörens Kick-räknare.
        I: { rainbowAtDrop: 3, bomb: false, bombAtDrop: 0 },
        II: { rainbowAtDrop: 2, bomb: false, bombAtDrop: 0 },
        III: { rainbowAtDrop: 2, bomb: true, bombAtDrop: 12 },
      },
    },
    showcase: show(
      once({ dy: -6, ms: 200, ease: QO }, { ms: 300, ease: BNC }),
      { kind: 'arc', colors: ['#FF8766', '#FFD447', '#6EE7A0', '#6C8BFF', '#B98CFF'], r: 42, width: 5, inMs: 240, holdMs: 400, outMs: 360 },
      { wave: 'sine', baseHz: 440, glideTo: 1760, attack: 0.01, decay: 0.5, gain: 0.16, vibratoHz: 6, vibratoCents: 35 },
      100,
    ),
  }),
  def({
    id: 'vala',
    names: { en: 'Willow the Whale', sv: 'Andrums-Vala' },
    rarity: 'legendary',
    idea: 'Stor lugn val som blåser en fontän: ger dig ett extra andetag när burken blir full.',
    draw: [
      Q([0, -12], [-3, -20], [-9, -24], 2.6, '#BFEFFF', '#1F4660', { edgeW: 0.9 }),
      Q([0, -12], [3, -20], [9, -24], 2.6, '#BFEFFF', '#1F4660', { edgeW: 0.9 }),
      L([0, -12], [0, -24], 2.6, '#BFEFFF', '#1F4660', { edgeW: 0.9 }),
      C(-11, -24.6, 1.8, '#BFEFFF', undefined, { noSil: true }),
      C(11, -24.6, 1.8, '#BFEFFF', undefined, { noSil: true }),
      C(0, -26, 1.6, '#BFEFFF', undefined, { noSil: true }),
      E(-15, 17, 12, 6, '#7CA6FF', '#14235A', 0.55, { edgeW: 2.2 }),
      E(15, 17, 12, 6, '#7CA6FF', '#14235A', -0.55, { edgeW: 2.2 }),
      E(0, 4, 42, 30, '#7CA6FF', '#14235A'),
      E(0, 11, 28, 14, '#DCE6FF'),
      L([-6, 8], [-6, 16], 1.2, '#9CB4E8'),
      L([0, 8], [0, 17], 1.2, '#9CB4E8'),
      L([6, 8], [6, 16], 1.2, '#9CB4E8'),
      E(0, -9, 5, 2, '#14235A'),
      shine(-7, -5, 14, 4),
      ...eyes('dot', -9, 9, 0),
      ...mouth('smile', 0, 4, 1),
      ...cheeks(-13, 13, 4, 0.8),
      ...hands('#7CA6FF', '#14235A'),
    ],
    anim: anims('heavy', { idle: IDLE.breathe(1.03, 1500), danger: loop({ sy: 1.06, sx: 0.98, ms: 1000, ease: IO }, { ms: 1000, ease: IO }) }),
    cosmetic: { particleShape: 'drop', particleTint: '#BFEFFF' },
    ability: {
      key: 'breath',
      params: {
        // N gånger per runda: förlustgränsen över farolinjen är graceMs i stället för 1 500 ms. Syns som att Vala
        // andas in (danger-receptet) och en blå fontän i burkens hals. Räknaren "andetag kvar" visas aldrig.
        I: { uses: 1, graceMs: 2500 },
        II: { uses: 2, graceMs: 2500 },
        III: { uses: 2, graceMs: 2800 },
      },
    },
    showcase: show(
      once({ sy: 1.08, sx: 0.97, ms: 400, ease: IO }, { sy: 0.94, ms: 120, ease: QO }, { ms: 300, ease: BO }),
      { kind: 'rise', shape: 'drop', tint: '#BFEFFF', count: 10, risePx: 70, swayPx: 14, lifeMs: 700, staggerMs: 30 },
      { wave: 'triangle', baseHz: 180, glideTo: 520, attack: 0.25, decay: 0.5, gain: 0.14, lowpassHz: 1200 },
      420,
    ),
  }),
];

// ================================================================ MYTISK (2) – förmåga + spektakel

const MYTHIC: AvatarDef[] = [
  def({
    id: 'havsdrottningen',
    names: { en: 'The Sea Queen', sv: 'Havsdrottningen' },
    rarity: 'mythic',
    idea: 'Havets drottning med pärlhalsband och krona: hela burken blir guld och orkestern spelar.',
    draw: [
      P([...arc(0, 0, 19, 19, Math.PI * 1.05, Math.PI * 1.95, 14), [19, 10], [16, 20], [12, 15], [6, 20], [0, 16], [-6, 20], [-12, 15], [-16, 20], [-19, 10]], '#B98CFF', '#2F1056'),
      C(0, 0, 11, '#FFE0C8', '#5C3418'),
      Q([-10, -3], [-4, -9], [2, -6], 3.4, '#B98CFF'),
      Q([10, -3], [5, -8], [0, -6], 3.4, '#B98CFF'),
      P([[-10, -9], [-11, -21], [-5, -15], [0, -24.6], [5, -15], [11, -21], [10, -9]], '#FFD75E', '#6B4300', { edgeW: 2.2 }),
      C(-11, -21, 1.8, '#7FE3D0'),
      C(0, -24.6, 2.2, '#FF86B8'),
      C(11, -21, 1.8, '#8FB4FF'),
      C(0, -12, 1.8, '#7FE3D0'),
      ...eyes('lash', -4, 4, 0, 0.8),
      ...mouth('smile', 0, 5, 0.55),
      ...cheeks(-6.4, 6.4, 4.4, 0.55),
      ...[-7, -3.5, 0, 3.5, 7].map((x) => C(x, 12 + Math.abs(x) * -0.2, 1.7, '#F4F7FF', '#5C4526', { edgeW: 0.8 })),
      spark(-22, -14, 3, '#FFD75E'),
      spark(22, -8, 2.4, '#FFF4DC'),
      spark(-23, 8, 2, '#FFF4DC'),
      ...hands('#FFE0C8', '#5C3418'),
    ],
    anim: anims('stately', { chain: CHAIN.glowUp }),
    cosmetic: { particleShape: 'star', particleTint: '#FFD75E', trail: trail('star', ['#FFD75E', '#FFF4DC'], { everyPx: 14, blend: 'ADD' }) },
    ability: {
      key: 'queenRound',
      params: {
        // Burken ritas i guld (jarEdge #FFD75E, jarShine #FFF1C4), merge-klangen får ett stråklager
        // (sågtand genom lågpass 1 800 Hz, +12 halvtoner, gain 0,15). En regnbåge kommer i VARJE runda
        // (som Rut I, drop 3) + `extraSpecials` extra specialobjekt (regissörens Kick-tabell) per runda.
        I: { rainbow: true, extraSpecials: 1, goldJar: true, orchestra: true },
        II: { rainbow: true, extraSpecials: 1, goldJar: true, orchestra: true },
        III: { rainbow: true, extraSpecials: 2, goldJar: true, orchestra: true },
      },
    },
    showcase: show(
      once({ dy: -6, sx: 1.1, sy: 1.1, ms: 260, ease: CO }, { dy: -6, sx: 1.1, sy: 1.1, rot: 6, ms: 200, ease: IO }, { ms: 360, ease: BO }),
      { kind: 'rings', color: '#FFD75E', count: 3, fromR: 22, toR: 56, width: 3, ms: 640, staggerMs: 120 },
      { wave: 'triangle', baseHz: 392, attack: 0.02, decay: 0.6, gain: 0.2, steps: [0, 4, 7, 12, 16, 19], stepMs: 90, harmonicSemitones: 12, harmonicGain: 0.3, vibratoHz: 5, vibratoCents: 12 },
      60,
    ),
  }),
  def({
    id: 'stjärnvalen',
    names: { en: 'The Star Whale', sv: 'Stjärnvalen' },
    rarity: 'mythic',
    idea: 'En val gjord av natthimmel: stjärnor i kroppen, månskära på huvudet, allt i burken glöder.',
    draw: [
      P([[12, -2], [20, -16], [27, -14], [22, -8], [27, -1]], '#5A5FD0', '#E8E4FF', { edgeW: 2 }),
      E(-15, 17, 12, 6, '#5A5FD0', '#E8E4FF', 0.55, { edgeW: 2 }),
      E(15, 17, 12, 6, '#5A5FD0', '#E8E4FF', -0.55, { edgeW: 2 }),
      E(0, 4, 42, 30, '#5A5FD0', '#E8E4FF', 0, { edgeW: 2.4 }),
      E(0, 12, 26, 12, '#8C8CF0'),
      P(star(-12, -3, 2.4, 0.9), '#FFF4C0'),
      P(star(11, 11, 2, 0.8), '#FFF4C0'),
      P(star(13, -4, 1.6, 0.6), '#FFF4C0'),
      C(-6, 12, 0.9, '#FFF4C0'),
      C(4, -7, 0.8, '#FFF4C0'),
      C(-15, 8, 0.8, '#FFF4C0'),
      C(7, 14, 0.8, '#FFF4C0'),
      P([...arc(0, -15, 6.4, 6.4, (285 * Math.PI) / 180, (15 * Math.PI) / 180, 16), ...arc(2.4, -18, 5, 5, Math.PI / 4, (260 * Math.PI) / 180, 12)], '#FFE9A0', '#6B4300', { edgeW: 1.4 }),
      ...eyes('happy', -8, 8, 1, 1, '#FFF4C0'),
      ...mouth('smile', 0, 5, 0.9, '#FFF4C0'),
      ...cheeks(-12, 12, 5, 0.8),
      spark(-22, -12, 3, '#FFF4C0'),
      spark(-6, -24, 2.2, '#FFF4C0'),
      ...hands('#5A5FD0', '#E8E4FF'),
    ],
    anim: anims('floaty', { idle: IDLE.float(2.5, 1400), chain: CHAIN.glowUp }),
    cosmetic: { particleShape: 'star', particleTint: '#FFF4C0', trail: trail('star', '#FFF4C0', { everyPx: 12, blend: 'ADD', lifeMs: 600 }) },
    ability: {
      key: 'starWhale',
      params: {
        // Bakgrund: stjärnhimmel (scatter 60 st, stilla) i stället för setets backdrop. Alla objekt får +0,1 glow.
        // Sannolikheten för skimrande × shinyMul (garantin i DESIGN §13.2 oförändrad).
        I: { shinyMul: 2, starSky: true, glowBonus: 0.1 },
        II: { shinyMul: 2.5, starSky: true, glowBonus: 0.1 },
        III: { shinyMul: 3, starSky: true, glowBonus: 0.12 },
      },
    },
    showcase: show(
      IDLE.float(5, 300),
      { kind: 'orbit', shape: 'star', tint: ['#FFF4C0', '#FFE9A0', '#E8E4FF'], count: 7, r: 40, turns: 0.6, ms: 1000 },
      { wave: 'sine', baseHz: 523.25, attack: 0.05, decay: 0.9, gain: 0.18, steps: [0, 7, 12, 19, 24], stepMs: 110, harmonicSemitones: 12, harmonicGain: 0.25, vibratoHz: 4, vibratoCents: 15 },
      0,
    ),
  }),
];

// ---------------------------------------------------------------- export

export const AVATARS: readonly AvatarDef[] = [...COMMON, ...UNCOMMON, ...RARE, ...EPIC, ...LEGENDARY, ...MYTHIC];

export function avatarById(id: string): AvatarDef | undefined {
  return AVATARS.find((a) => a.id === id);
}

// ---------------------------------------------------------------- partikelformer (vita 16×16, tintas)

/** Nya partikelformer som polygoner i 16×16 (fylls vita, tintas). De gamla finns i textures.ts. */
export const AVATAR_PARTICLE_GEOM: Readonly<Record<'heart' | 'note' | 'confetti' | 'drop' | 'bolt', readonly (readonly P2[])[]>> = {
  heart: [[[8, 14], [2, 8], [1.4, 4.6], [3, 2.4], [5.6, 2.2], [8, 4.4], [10.4, 2.2], [13, 2.4], [14.6, 4.6], [14, 8]]],
  note: [arc(6, 12, 3.6, 2.8, 0, Math.PI * 2, 12), [[8.6, 12], [8.6, 2], [10.4, 2], [10.4, 12]], [[10.4, 2], [14.4, 4.6], [14.4, 7.4], [10.4, 5]]],
  confetti: [[[3, 5], [13, 3], [13.6, 7], [3.6, 9]]],
  drop: [[[8, 1.4], [12.4, 8.6], ...arc(8, 10, 4.6, 4.6, 0, Math.PI, 8).slice(1, -1), [3.6, 8.6]]],
  bolt: [[[9.6, 1], [4, 9], [7.6, 9], [6, 15], [12, 6.6], [8.4, 6.6]]],
};

// ---------------------------------------------------------------- layout, tider, ljud (UI.md §13)

/**
 * Allt i logiska px (360×640). Spec och motivering: UI.md §13. Ersätter platshållarna i `BOX_FX` (boxes.ts)
 * – mappningen står i UI.md §13.9.
 */
export const AVATAR_UI = {
  /** Släpparen i spel (UI.md §13.5). */
  slapparen: {
    displayPx: 40,
    /** Greppunkten ligger så här långt under det hängande objektets ovankant. */
    gripBelowTop: 4,
    /** Över hängande objekt (6) och HUD-kedjan (5,5), under HUD (10). */
    depth: 6.5,
    /** Följer x exakt som det hängande objektet (samma lerp, THEME.anim.aim). */
    leanDegPerPxPerFrame: 0.35,
    leanMaxDeg: 8,
    leanReturnMs: 180,
    /** Byte av greppunktens y när nytt objekt hängs upp (samma som queueSlide). */
    respawnMs: 220,
    respawnEase: 'Back.easeOut',
    /** Andel av pacing-vickningen (±4°) som figuren vickar med. */
    wobbleShare: 0.5,
    /** Lugnt läge: alla dy/rot i recepten ×0,5, chain spelas som merge. */
    calmScale: 0.5,
    /** Uppgraderingsrombar på axeln: II = 1, III = 2. Box-koordinater (56). */
    romb: { x: 18, y: -18, stepY: 10, w: 9, h: 12, fill: '#EAF2FF', edge: '#14202E', edgeW: 2 },
    /** När figuren överlappar poängen/förhandsvisningen: alpha. HUD ligger alltid överst. */
    underHudAlpha: 1,
  },
  /** Hyllan på startskärmen (UI.md §13.6). Ersätter META.shelf.best/book/hit/badge. */
  shelf: {
    line: { x0: 48, x1: 312, y: 470 },
    best: { x: 166, y: 436, r: 34 },
    book: { x: 246, y: 444, size: 48 },
    badge: { x: 266, y: 422, r: 6 },
    /** Musslor (eller vald kompis om inga musslor väntar). */
    box: { x: 92, y: 450, size: 48, hit: { x: 60, y: 408, w: 64, h: 76 }, maxShown: 3, dx: -9, dy: -7, backScale: 0.86, backAlpha: 0.8 },
    boxPulse: { scale: 1.06, halfCycleMs: 1000, ease: 'Sine.easeInOut' },
    /** Boken: hela hyllan till höger om musselzonen. */
    bookHit: { x: 132, y: 396, w: 180, h: 88 },
    /** Vald kompis sitter på hyllan (greppunkt på hyllinjen) när ingen mussla väntar. */
    buddy: { x: 92, gripY: 470, displayPx: 48 },
    /** Rekordets avatar till vänster om kronan. */
    recordAvatar: { x: 110, y: 496, displayPx: 30, ringR: 17, ringW: 2 },
  },
  /** Öppningen (UI.md §13.3). Tider i ms från trycket. Totalt 1 200. */
  open: {
    scrim: { alpha: 0.86, inMs: 200 },
    center: { x: 180, y: 300 },
    fly: { ms: 280, ease: 'Cubic.easeOut', ctrlX: 150, ctrlY: 360, toScale: 2.6, wobbleDeg: 6 },
    shellOpenAt: 280,
    /** Övre halvan tippar bakåt kring gångjärnet (scaleY, origin i gångjärnet) och byter till insidan vid swapAtScaleY. */
    shellOpen: { ms: 180, ease: 'Back.easeOut', toScaleY: 0.45, swapAtScaleY: 0.75, inside: { fill: '#FFF3F8', rib: '#F4C8DA' } },
    glowAt: 300,
    glow: { r: 96, alpha: 0.42, ms: 260, ease: 'Cubic.easeOut' },
    figureAt: 320,
    /** Figurens CENTRUM (inte greppet) under öppningen. */
    figure: { fromY: 300, toY: 228, displayPx: 112, ms: 260, ease: 'Back.easeOut', overshoot: 1.8, fromScale: 0.35 },
    pearls: { y: 374, r: 7, pitch: 20, ms: 200, ease: 'Back.easeOut' },
    rombs: { y: 398, w: 10, h: 13, pitch: 18 },
    ringsAt: 320,
    /** Antal guldringar per raritet (samma som ringarna i rundavslutet). */
    rings: { common: 0, uncommon: 1, rare: 2, epic: 3, legendary: 3, mythic: 3 } as Readonly<Record<Rarity, number>>,
    ring: { fromR: 56, toR: 128, width: 4, ms: 640, stepMs: 120, alpha: 0.85, ease: 'Cubic.easeOut' },
    /** Legendarisk och mytisk: 8/12 statiska strålar bakom figuren som roterar 12°/s. */
    rays: { legendary: 8, mythic: 12, innerR: 44, outerR: 132, alpha: 0.18, degPerSec: 12 } as const,
    /** Showcase börjar när figuren landat och tidsskalas så att den slutar senast vid doneAt. */
    showcaseAt: 580,
    doneAt: 1200,
    /** Tryck efter doneAt: figuren flyger till bokikonen och scrimmen tonas ut. */
    close: { ms: 320, ease: 'Cubic.easeIn', scrimOutMs: 200 },
    haptic: { common: 10, uncommon: 10, rare: 30, epic: 30, legendary: 60, mythic: 60 } as Readonly<Record<Rarity, number>>,
  },
  /** Fliken Kompisar i boken (UI.md §13.4). */
  book: {
    tabs: {
      set: { x: 32, y: 36 },
      friends: { x: 96, y: 36 },
      w: 48,
      hActive: 72,
      hIdle: 58,
      icon: 32,
      hit: { w: 56, h: 72 },
    },
    stage: { x: 104, gripY: 152, displayPx: 80, objR: 18, glowR: 46, hit: { x: 16, y: 80, w: 176, h: 116 } },
    jar: { x: 268, y: 134, w: 88, h: 96, lidH: 10, pearlR: 6.5, rows: [6, 5, 6, 5, 3] as readonly number[], bottomY: 172, pitchX: 13.6, pitchY: 11.8 },
    grid: {
      top: 204,
      bottom: 632,
      fadePx: 12,
      cols: 6,
      x0: 40,
      pitchX: 56,
      cell: 48,
      cellR: 12,
      avatarPx: 40,
      rowPitch: 72,
      headerH: 28,
      groupGap: 8,
      /** Rarast överst, samma riktning som pärlorna i burken. */
      order: ['mythic', 'legendary', 'epic', 'rare', 'uncommon', 'common'] as readonly Rarity[],
      frameW: 3,
      ownedFillAlpha: 0.14,
      silAlpha: 0.25,
      emptyFrameAlpha: 0.35,
      selected: { pad: 4, width: 3, badgeR: 8, badgeDx: 22, badgeDy: -22 },
      rombY: 32,
      rombPitch: 14,
      rombW: 8,
      rombH: 10,
      header: { pearlR: 4.5, pearlPitch: 12, x0: 22, lineX1: 300, countX: 340, countPx: 16 },
    },
    scroll: { rubber: 0.35, friction: 0.94, tapMaxPx: 12, tapMaxMs: 350, peekPx: 40, peekMs: 700 },
    freshPulse: { scale: 1.1, halfCycleMs: 1000 },
  },
  /** Rundavslutet: musslan dyker upp i stripen och flyger till hyllan (UI.md §13.7). */
  reveal: { x: 304, y: 56, size: 40, popMs: 140, flyMs: 260, toX: 92, toY: 640 },
} as const;

/** Ljud för musslor och fliken. Form som ToneDef → playTone(def). */
export const AVATAR_SOUND = {
  /** Samma för alla rariteter: musslan öppnas (ingen föraning om vad som finns i). */
  shellOpen: { wave: 'triangle', baseHz: 220, glideTo: 330, attack: 0.002, decay: 0.12, gain: 0.22, delayMs: 280 },
  /** Raritetens ton i samma ögonblick som figuren syns (t = 320 ms). Rikare, inte högre. */
  reveal: {
    common: { wave: 'triangle', baseHz: 659.25, attack: 0.004, decay: 0.22, gain: 0.24, harmonicSemitones: 7, harmonicGain: 0.3 },
    uncommon: { wave: 'triangle', baseHz: 659.25, attack: 0.004, decay: 0.22, gain: 0.26, steps: [0, 7], stepMs: 90, harmonicSemitones: 12, harmonicGain: 0.2 },
    rare: { wave: 'triangle', baseHz: 523.25, attack: 0.004, decay: 0.26, gain: 0.28, steps: [0, 4, 7], stepMs: 90, harmonicSemitones: 12, harmonicGain: 0.25 },
    epic: { wave: 'triangle', baseHz: 523.25, attack: 0.004, decay: 0.3, gain: 0.3, steps: [0, 4, 7, 12], stepMs: 85, harmonicSemitones: 12, harmonicGain: 0.25, vibratoHz: 5, vibratoCents: 10 },
    legendary: { wave: 'triangle', baseHz: 523.25, attack: 0.004, decay: 0.34, gain: 0.32, steps: [0, 4, 7, 12, 16], stepMs: 80, harmonicSemitones: 12, harmonicGain: 0.3, vibratoHz: 6, vibratoCents: 14 },
    mythic: { wave: 'triangle', baseHz: 523.25, attack: 0.006, decay: 0.42, gain: 0.34, steps: [0, 4, 7, 11, 14, 19], stepMs: 75, harmonicSemitones: 12, harmonicGain: 0.35, vibratoHz: 6, vibratoCents: 16 },
  } as Readonly<Record<Rarity, AvatarTone>>,
  /** Mussla dyker upp i rundavslutet. */
  boxEarned: { wave: 'sine', baseHz: 784, glideTo: 1046.5, attack: 0.004, decay: 0.16, gain: 0.16 },
  /** Kompis väljs i boken (sedan dess showcase-ljud). */
  equip: { wave: 'sine', baseHz: 880, glideTo: 1200, attack: 0.001, decay: 0.06, gain: 0.12 },
  /** Flikbyte. */
  tab: { wave: 'sine', baseHz: 900, glideTo: 620, attack: 0.001, decay: 0.07, gain: 0.12 },
} as const satisfies Record<string, AvatarTone | Readonly<Record<Rarity, AvatarTone>>>;

// ---------------------------------------------------------------- ikoner (SVG, viewBox 64, UI.md §9-stil)

const ACCENT = '#7CF9FF';

/** Stängd mussla. Tryckbar på hyllan ⇒ accent-kontur. Alla musslor ser likadana ut (ingen föraning). */
export const SHELL_ICON = (edge = ACCENT, fill = '#FFD9E8', rib = '#E79AC0'): string =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" stroke-linecap="round" stroke-linejoin="round">` +
  `<path d="M7 38 C9 52 20 58 32 58 C44 58 55 52 57 38 Z" fill="${fill}" stroke="${edge}" stroke-width="4"/>` +
  `<path d="M7 38 C5 20 18 10 32 10 C46 10 59 20 57 38 C52 41 47 36 42 39 C37 42 35 37 32 39 C29 37 27 42 22 39 C17 36 12 41 7 38 Z" fill="${fill}" stroke="${edge}" stroke-width="4"/>` +
  `<path d="M32 38 L32 15 M32 38 L20 18 M32 38 L44 18 M32 38 L12 27 M32 38 L52 27" fill="none" stroke="${rib}" stroke-width="3"/>` +
  `<path d="M26 58 L32 50 L38 58" fill="none" stroke="${rib}" stroke-width="3"/></svg>`;

/** Öppen mussla (tom, pärlemor inuti). Används efter öppningen och som "allt öppnat". */
export const SHELL_OPEN_ICON = (edge = '#5C2A43', fill = '#FFD9E8', nacre = '#FFF3F8'): string =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" stroke-linecap="round" stroke-linejoin="round">` +
  `<path d="M8 30 C6 14 18 5 32 5 C46 5 58 14 56 30 Z" fill="${fill}" stroke="${edge}" stroke-width="4"/>` +
  `<path d="M13 28 C13 17 22 10 32 10 C42 10 51 17 51 28 Z" fill="${nacre}"/>` +
  `<path d="M7 40 C9 54 20 60 32 60 C44 60 55 54 57 40 Z" fill="${fill}" stroke="${edge}" stroke-width="4"/>` +
  `<ellipse cx="32" cy="41" rx="21" ry="5" fill="${nacre}"/></svg>`;

/** Musslans två halvor för öppningsanimationen (samma ritning som SHELL_ICON, gångjärn vid y 38). */
export const SHELL_TOP_SVG = (edge = ACCENT, fill = '#FFD9E8', rib = '#E79AC0'): string =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" stroke-linecap="round" stroke-linejoin="round">` +
  `<path d="M7 38 C5 20 18 10 32 10 C46 10 59 20 57 38 C52 41 47 36 42 39 C37 42 35 37 32 39 C29 37 27 42 22 39 C17 36 12 41 7 38 Z" fill="${fill}" stroke="${edge}" stroke-width="4"/>` +
  `<path d="M32 38 L32 15 M32 38 L20 18 M32 38 L44 18 M32 38 L12 27 M32 38 L52 27" fill="none" stroke="${rib}" stroke-width="3"/></svg>`;
export const SHELL_BOTTOM_SVG = (edge = ACCENT, fill = '#FFD9E8', nacre = '#FFF3F8', rib = '#E79AC0'): string =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" stroke-linecap="round" stroke-linejoin="round">` +
  `<path d="M7 38 C9 52 20 58 32 58 C44 58 55 52 57 38 Z" fill="${fill}" stroke="${edge}" stroke-width="4"/>` +
  `<ellipse cx="32" cy="39" rx="22" ry="4.5" fill="${nacre}"/>` +
  `<path d="M26 58 L32 50 L38 58" fill="none" stroke="${rib}" stroke-width="3"/></svg>`;

/** Flik: Set (2×2 samling, en fylld). Aktiv = accent, inaktiv = hudDim. */
export const TAB_SET_ICON = (c = ACCENT): string =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" fill="none" stroke="${c}" stroke-width="6" stroke-linecap="round">` +
  `<circle cx="20" cy="20" r="9" fill="${c}"/><circle cx="44" cy="20" r="9"/><circle cx="20" cy="44" r="9"/><circle cx="44" cy="44" r="9"/></svg>`;

/** Flik: Kompisar (figur som håller en boll – Släpparen). */
export const TAB_FRIENDS_ICON = (c = ACCENT): string =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" fill="none" stroke="${c}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round">` +
  `<circle cx="32" cy="22" r="13"/><circle cx="27" cy="21" r="2.6" fill="${c}" stroke="none"/><circle cx="37" cy="21" r="2.6" fill="${c}" stroke="none"/>` +
  `<path d="M22 32 Q16 40 24 47 M42 32 Q48 40 40 47"/><circle cx="32" cy="51" r="8" fill="${c}"/></svg>`;

/** Pärla i raritetsfärg (fylld, mörk kant, högdager). Mytisk: regnbågsränder via PEARL_MYTHIC_ICON. */
export const PEARL_ICON = (c: string): string =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">` +
  `<circle cx="32" cy="32" r="24" fill="${c}" stroke="#14202E" stroke-width="6"/>` +
  `<circle cx="24" cy="23" r="7" fill="#FFFFFF" fill-opacity="0.7"/></svg>`;

export const PEARL_MYTHIC_ICON = (): string =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">` +
  `<clipPath id="p"><circle cx="32" cy="32" r="24"/></clipPath><g clip-path="url(#p)">` +
  RARITY.rainbow.map((c, i) => `<rect x="${8 + i * 8}" y="0" width="8" height="64" fill="${c}"/>`).join('') +
  `</g><circle cx="32" cy="32" r="24" fill="none" stroke="#14202E" stroke-width="6"/>` +
  `<circle cx="24" cy="23" r="7" fill="#FFFFFF" fill-opacity="0.75"/></svg>`;

/** Uppgraderingsromb. filled = uppnådd nivå, annars kontur. fillPct (0..1) = XP mot nästa, fylls nedifrån. */
export const ROMB_ICON = (c = '#EAF2FF', filled = true, fillPct = 0): string =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" stroke-linejoin="round">` +
  `<clipPath id="r"><path d="M32 6 L54 32 L32 58 L10 32 Z"/></clipPath>` +
  (filled
    ? `<path d="M32 6 L54 32 L32 58 L10 32 Z" fill="${c}"/>`
    : `<rect x="0" y="${r2(58 - 52 * fillPct)}" width="64" height="64" fill="${c}" fill-opacity="0.6" clip-path="url(#r)"/>`) +
  `<path d="M32 6 L54 32 L32 58 L10 32 Z" fill="none" stroke="${filled ? '#14202E' : c}" stroke-width="6"/>` +
  (filled ? `<path d="M22 30 L32 16" stroke="#FFFFFF" stroke-opacity="0.8" stroke-width="4" stroke-linecap="round"/>` : '') +
  `</svg>`;

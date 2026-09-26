/**
 * artEnv.ts – "Art v3": miljö, glas, ljus och delade effekt-sprites (docs/ART_DIRECTION.md).
 *
 * Ren data. Får INTE importera Phaser. Referensrenderare: `ui/envArt.ts` (Canvas2D, bakas en gång).
 * Status: PROTOTYP från art director (fas 1). Scenerna rörs inte; programmeraren kopplar in enligt
 * backloggen i ART_DIRECTION.md §12.
 *
 * Koordinater: logiska px (360 bred). Höjden `h` är skärmens logiska höjd (640 i dag, upp till ~780
 * med Scale.EXPAND på 19,5:9-telefoner, se ART_DIRECTION P1). Allt som ritas i banden ovanför/under
 * spelytan är ren miljö: ingen information bor där.
 *
 * Ljusmodell (samma som Art v2): nyckelljus uppe till vänster (ytan/solen), kallt kantljus uppe till
 * höger, setets "upplyse" nedifrån (bara Glöden och Godis). Burken är det ljusaste rummet i bilden.
 */

export type EnvSetId = 'glimtarna' | 'planeterna' | 'frostisarna' | 'godisarna' | 'gloden';

/** Motiv i fjärrlagret (bakas som siluetter i `far`-färgen). */
export type FarMotif = 'kelp' | 'planet' | 'iceShelf' | 'candyHills' | 'rocks';
/** Rörligt partikellager (poolat, max `count`). */
export type MoteKind = 'snow' | 'star' | 'flake' | 'bokeh' | 'ember';
/** Takljusets form: strålar från ytan, eller norrsken/nebulosa som mjuka band. */
export type SkyLight = 'rays' | 'aurora' | 'nebula' | 'uplight';

export interface EnvSet {
  /** Vertikal gradient: topp (ytans ljus) → mitt → botten. */
  readonly sky: readonly [string, string, string];
  /** Fjärrlagrets siluettfärg (lite ljusare än `sky[1]`, luminans ≤ 0,03). */
  readonly far: string;
  readonly farMotif: FarMotif;
  readonly skyLight: SkyLight;
  /** Ljusets färg (strålar/norrsken/uppljus), ritas ADD. */
  readonly light: string;
  /** Strålarnas/bandens max-alpha i ADD. Håll kontrasten: summan över burken ≤ 0,10. */
  readonly lightAlpha: number;
  /** Kaustikens färg och alpha (ADD, bara i burkens bakre glas). 0 = ingen kaustik. */
  readonly caustic: string;
  readonly causticAlpha: number;
  readonly mote: MoteKind;
  readonly moteColor: string;
  /** Riktning i logiska px/s (negativ = uppåt). */
  readonly moteVy: number;
  /** Glasets ton: tint på glasets bakre panel och fresnelkant. */
  readonly glassTint: string;
  /** Burkens golv (sand/snö/sten), toppfärg → botten. */
  readonly floor: readonly [string, string];
}

export const ENV_SETS: Record<EnvSetId, EnvSet> = {
  glimtarna: {
    sky: ['#12305A', '#0B1A38', '#050A16'],
    far: '#0F2244',
    farMotif: 'kelp',
    skyLight: 'rays',
    light: '#7CD8FF',
    lightAlpha: 0.075,
    caustic: '#8FE8FF',
    causticAlpha: 0.06,
    mote: 'snow',
    moteColor: '#BFE6FF',
    moteVy: 6,
    glassTint: '#9CC8FF',
    floor: ['#1E2E52', '#0E1830'],
  },
  planeterna: {
    sky: ['#2A1C5C', '#130E30', '#07051A'],
    far: '#1D1542',
    farMotif: 'planet',
    skyLight: 'nebula',
    light: '#B69CFF',
    lightAlpha: 0.09,
    caustic: '#C9B8FF',
    causticAlpha: 0.035,
    mote: 'star',
    moteColor: '#FFF4D6',
    moteVy: 0,
    glassTint: '#C8BEFF',
    floor: ['#2A2352', '#141030'],
  },
  frostisarna: {
    sky: ['#0E3A4E', '#0A1E30', '#040B14'],
    far: '#11304A',
    farMotif: 'iceShelf',
    skyLight: 'aurora',
    light: '#7CFFD2',
    lightAlpha: 0.08,
    caustic: '#CFF4FF',
    causticAlpha: 0.05,
    mote: 'flake',
    moteColor: '#EAF8FF',
    moteVy: 8,
    glassTint: '#CFEFFF',
    floor: ['#2A4A66', '#16304A'],
  },
  godisarna: {
    sky: ['#4A1A52', '#241030', '#100614'],
    far: '#33163F',
    farMotif: 'candyHills',
    skyLight: 'rays',
    light: '#FF9CE0',
    lightAlpha: 0.07,
    caustic: '#FFC8EC',
    causticAlpha: 0.045,
    mote: 'bokeh',
    moteColor: '#FFB8E6',
    moteVy: -10,
    glassTint: '#FFD1F2',
    floor: ['#4A2356', '#26102E'],
  },
  gloden: {
    sky: ['#1A0C0A', '#1E0E0B', '#3A140C'],
    far: '#2A120D',
    farMotif: 'rocks',
    skyLight: 'uplight',
    light: '#FF8A4C',
    lightAlpha: 0.1,
    caustic: '#FFB070',
    causticAlpha: 0.04,
    mote: 'ember',
    moteColor: '#FFB45E',
    moteVy: -12,
    glassTint: '#FFD8B8',
    floor: ['#3A2018', '#1A0C08'],
  },
};

/** Globala miljöparametrar (gäller alla set). */
export const ENV = {
  /** Fjärrlagrets parallax mot kamerans skak/zoom (0 = står still, 1 = följer spelytan). */
  farParallax: 0.35,
  /** Strålar: antal, bredd (logiska px vid toppen), vinkel (rad, lutar åt höger nedåt), svaj. */
  rays: { count: 4, widthMin: 36, widthMax: 70, angle: 0.22, swayPx: 14, swayHz: 0.05, lengthFrac: 0.85 },
  /** Kaustiktextur: 256 logiska px kvadrat, tilebar, domänvriden (`warp`), scrollas `speed` px/s i två lager mot varandra. */
  caustic: { tile: 256, cells: 7, lineW: 1.6, warp: 0.035, blur: 3, speed: [7, -5] as const, scale: [1, 1.35] as const },
  /** Partiklar: antal på skärmen samtidigt (hela skärmen), radie, vaggning. Lugnt läge: stilla, hälften. */
  motes: { count: 28, rMin: 0.8, rMax: 2.2, alphaMin: 0.18, alphaMax: 0.5, wobblePx: 6, wobbleHz: 0.25 },
  /** Vinjett: radial från mitten, alpha i kant. Bakas i miljötexturen. */
  vignette: { inner: 0.55, alpha: 0.55 },
  /** Andning: ljusets alpha pendlar ±`amp` av sitt värde, `hz` (≤0,1 Hz, långt under flash-guard). */
  breathe: { amp: 0.25, hz: 0.07 },
} as const;

/** Glasburken i tre lager: bakre panel (under objekten), främre glas (över objekten), läpp. */
export const GLASS = {
  /** Bakre panel: vertikal gradient i glassTint, alpha topp → botten. */
  backAlpha: [0.1, 0.04] as const,
  /** Inre mörkning i kanterna (djup), bredd i px och alpha. */
  innerShadow: { width: 26, alpha: 0.35 },
  /** Fresnel: ljus kant på insidan av väggen, bredd px, alpha. */
  fresnel: { width: 5, alpha: 0.32 },
  /** Främre glas: två vertikala reflexband (x-andel av burkens bredd, bredd px, alpha, mjukhet). */
  bands: [
    { x: 0.07, w: 14, alpha: 0.13, soft: 0.6 },
    { x: 0.13, w: 5, alpha: 0.1, soft: 0.3 },
    { x: 0.9, w: 9, alpha: 0.07, soft: 0.6 },
  ],
  /** Hård spekulär prick nära överkanten (nyckelljuset), vänster. */
  spec: { x: 0.08, y: 0.03, r: 7, alpha: 0.55 },
  /** Kontur: yttre mörk kant + ljus innerkant (glasets tjocklek). */
  edge: { outer: 3, outerColor: '#060A14', inner: 2, innerAlpha: 0.55 },
  /** Läppen överst: en tjock rundad list i glassTint med toppljus. */
  lip: { h: 12, alpha: 0.5 },
  /** Golv: höjd, kontaktskugga under objekt (fake AO) bakas inte; se VFX.contact. */
  floorH: 22,
  cornerR: 22,
} as const;

/** Delade effekt-sprites (bakas en gång, vita, tintas). ART_DIRECTION §7. */
export const FX_SPRITES = {
  /** Den ENDA glöden i spelet: radial med 5 stopp (ingen trappning). Tintas och skalas. */
  glow: { px: 128, stops: [[0, 1], [0.18, 0.72], [0.42, 0.3], [0.7, 0.08], [1, 0]] as const },
  /** Chockvåg: ring med mjuk insida, hård utsida. */
  shock: { px: 256, ringFrac: 0.86, width: 0.09 },
  /** Gnista: fyrudd med mjuk kärna. */
  sparkle: { px: 64, armFrac: 0.48, waist: 0.07, core: 0.16 },
  /** Strimma för spår/"speed lines": vertikal kapsel, mjuk i ändarna. */
  streak: { w: 8, h: 64 },
  /** Ljusstråle för jackpot-solfjädern: kilformad, mjuk kant. */
  beam: { w: 64, h: 256, spread: 0.32 },
} as const;

/**
 * Samlarbok, skimrande och kedjan i HUD (DESIGN §13.1–13.2). Ren data, ingen Phaser.
 */

/** Antal nivåer per boksida (0–10). */
export const LEVEL_COUNT = 11;

/** Enda setet tills temaseten (src/data/themes.ts) pluggas in. */
export const DEFAULT_SET = 'glimtarna';

export interface CollectionConfig {
  /** Sannolikhet för skimrande per skapad nivå (index = nivå). */
  readonly shinyP: readonly number[];
  /** Garanti: skimrande senast vid den (pityFactor/p):e skapade i rad utan träff. */
  readonly pityFactor: number;
  /** Första skimrande någonsin garanteras senast i denna runda … */
  readonly firstShinyByRun: number;
  /** … på första skapade nivå ≥ detta. */
  readonly firstShinyMinLevel: number;
}

const P_LOW = 1 / 60;
const P_MID = 1 / 30;
const P_HIGH = 1 / 12;
const P_TOP = 1 / 5;

export const COLLECTION: CollectionConfig = {
  shinyP: [P_LOW, P_LOW, P_LOW, P_LOW, P_LOW, P_MID, P_MID, P_HIGH, P_HIGH, P_TOP, P_TOP],
  pityFactor: 3,
  firstShinyByRun: 3,
  firstShinyMinLevel: 2,
};

/** Hur skimrande och kedjan ser ut och låter. */
export const COLLECTION_FX = {
  /** Juice-intensitet läggs på merge när det nya objektet är skimrande. */
  shinyIntensityBonus: 0.2,
  glitter: {
    /** Ringens radie som andel av kroppsradien. */
    ringRadius: 1.28,
    /** Halvcykel för alpha/skal-pulsen: 600 ms ⇒ 0,83 Hz (flash-guard ≤1 Hz). */
    halfCycleMs: 600,
    alphaMin: 0.55,
    alphaMax: 1,
    scaleAmp: 0.06,
    spinDegPerSec: 30,
  },
  chain: {
    /** Rad centrerad under poängen (reserv tills UI.md §12 finns). */
    cx: 180,
    y: 88,
    size: 20,
    gap: 4,
    /** Kroppsradie i px för tänd siluett (dekor ryms inom size). */
    bodyR: 8,
    unlitAlpha: 0.35,
    punch: 0.3,
    punchMs: 220,
  },
  book: {
    litAlpha: 1,
    lockedAlpha: 0.25,
    cols: 6,
    pitch: 56,
    bodyR: 20,
    normalY: 222,
    shinyY: 372,
    iconY: 88,
    iconR: 34,
    meterY: 150,
    dotsY: 528,
    closeX: 316,
    closeY: 44,
    /** Svep: minsta förflyttning i px för att räknas. */
    swipePx: 60,
    pageMs: 260,
  },
  sound: {
    /** Kvint upp över merge-tonen (392 Hz · 2^(7/12)). */
    shiny: {
      wave: 'triangle',
      baseHz: 587.33,
      attack: 0.004,
      decay: 0.42,
      gain: 0.22,
      harmonicSemitones: 12,
      harmonicGain: 0.3,
      delayMs: 70,
    },
    /** Kort pling när en nivå tänds i kedjan, stiger en halvton per nivå. */
    chain: { wave: 'sine', baseHz: 1046.5, attack: 0.002, decay: 0.09, gain: 0.1, delayMs: 0 },
  },
} as const;

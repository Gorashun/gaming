/**
 * All balansering av game feel. DESIGN.md §5–6, UI.md §5–6.
 * Ingen Phaser-import: ren data så att den kan testas utan rendering.
 */
import { THEME } from './theme';
import { MAX_LEVEL } from './levels';
import { SPECIALS } from './director';
import { META } from './themes';
import { AVATAR_UI } from './avatarsIndex';
import { ECONOMY_UI } from './economyUi';
import { START_UI } from './startUi';

export type JuiceEvent =
  | 'drop'
  | 'land'
  | 'merge'
  | 'chain'
  | 'special'
  | 'specialDrop'
  | 'bomb'
  | 'jackpot'
  | 'danger'
  | 'loss'
  | 'newRecord'
  | 'record';

export interface EventChannels {
  /** Andel av full screen shake (0 = av). */
  shake: number;
  /** Andel av fullt partikelantal (0 = av). */
  particles: number;
  zoom: boolean;
  hitStop: boolean;
  scorePop: boolean;
  haptics: boolean;
}

/**
 * Kanalkombinationen per ögonblick är designen (UI.md §6):
 * vanlig merge = 3 kanaler, kedja = 6, jackpot = 8.
 */
export const EVENTS: Readonly<Record<JuiceEvent, EventChannels>> = {
  drop: { shake: 0, particles: 0, zoom: false, hitStop: false, scorePop: false, haptics: false },
  land: { shake: 0.12, particles: 0.15, zoom: false, hitStop: false, scorePop: false, haptics: true },
  merge: { shake: 0.4, particles: 1, zoom: false, hitStop: true, scorePop: true, haptics: true },
  chain: { shake: 0.75, particles: 1, zoom: true, hitStop: true, scorePop: true, haptics: true },
  special: { shake: 1, particles: 1, zoom: true, hitStop: true, scorePop: true, haptics: true },
  // Sällsynt drop (UI.md §6): bara ljud, gnistor och haptik – ingen shake eller zoom.
  specialDrop: { shake: 0, particles: 0.3, zoom: false, hitStop: false, scorePop: false, haptics: true },
  bomb: { shake: 1, particles: 1, zoom: true, hitStop: true, scorePop: true, haptics: true },
  jackpot: { shake: 1, particles: 1, zoom: true, hitStop: true, scorePop: true, haptics: true },
  danger: { shake: 0, particles: 0, zoom: false, hitStop: false, scorePop: false, haptics: false },
  loss: { shake: 0.4, particles: 0, zoom: false, hitStop: false, scorePop: false, haptics: true },
  newRecord: { shake: 0.6, particles: 1, zoom: false, hitStop: true, scorePop: false, haptics: true },
  record: { shake: 0, particles: 0, zoom: false, hitStop: false, scorePop: false, haptics: false },
};

export const JUICE = {
  /** Partiklar: 6 + 24·i, tak 40 (DESIGN §6). */
  particles: {
    base: 6,
    perIntensity: 24,
    max: 40,
    speedMin: 30,
    speedMax: 170,
    lifespanMs: 520,
    /** Andel av objektets hastighet som partiklarna ärver. */
    inheritVelocity: 0.5,
    scaleStart: 0.9,
    scaleEnd: 0,
    poolSize: 64,
  },
  /** Dämpad riktad shake: amp·e^(−t/tau)·sin(2π·f·t), tak 8 px, borta inom 300 ms. */
  shake: { maxPx: THEME.anim.shake.maxPx, durationMs: THEME.anim.shake.durationMs, tauMs: THEME.anim.shake.tauMs, freqHz: THEME.anim.shake.freqHz },
  /** Hit-stop: 0–6 frames vid intensity ≥0,3, tak 100 ms. */
  hitStop: {
    minIntensity: THEME.anim.hitStop.minIntensity,
    maxFrames: THEME.anim.hitStop.maxFrames,
    frameMs: 1000 / 60,
    maxMs: THEME.anim.hitStop.maxMs,
  },
  /** Kamerazoom, endast chain och special. */
  zoom: { peak: THEME.anim.zoom.peak, durationMs: THEME.anim.zoom.durationMs, ease: THEME.anim.zoom.ease },
  /** Scale-punch på det NYA objektet: 1,0 → 1,0 + 0,35·i → 1,0. */
  punch: { peak: THEME.anim.mergePunch.peak - 1, durationMs: THEME.anim.mergePunch.durationMs, ease: THEME.anim.mergePunch.ease },
  scorePop: {
    durationMs: THEME.anim.scorePop.durationMs,
    risePx: THEME.anim.scorePop.risePx,
    poolSize: 8,
    ease: THEME.anim.scorePop.ease,
  },
  /** Antal återanvända ringbilder. */
  ringPoolSize: 4,
  /**
   * Jackpot (UI.md §6): guldton över burken + slow-mo. Den enda effekten utöver
   * faran som får röra tiden.
   */
  jackpot: {
    slowmoMs: 600,
    timeScale: THEME.anim.slowmoIn.timeScale,
    tintAlpha: 0.22,
    /** Hel upp-och-ner-tonning, dvs EN ljusstyrkeväxling – inte en blixt. */
    tintMs: 520,
  },
  /** Lugnt läge: intensitet ×0,5, shake och zoom av. */
  calm: {
    intensityScale: THEME.a11y.calm.intensityScale,
    shake: THEME.a11y.calm.shake,
    zoom: THEME.a11y.calm.zoom,
  },
  /**
   * Flash-guard (WCAG 2.3.1): varje loopande puls anges som halvcykel i ms.
   * Frekvens = 500/ms Hz och måste vara ≤ THEME.a11y.maxFlashesPerSec.
   */
  pulseHalfCycleMs: {
    danger: THEME.anim.dangerPulse.durationMs,
    record: THEME.anim.recordPulse.durationMs,
    preview: THEME.anim.previewPulse.durationMs,
    nearMiss: THEME.anim.nearMiss.durationMs,
    restart: THEME.anim.recordPulse.durationMs,
    // Meta-lagret (UI.md §12.8)
    chainGoal: META.chain.goalPulse.halfCycleMs,
    bookFresh: META.book.freshPulse.halfCycleMs,
    shiny: META.shiny.halfCycleMs,
    // Kompisar (UI.md §13.12)
    boxPulse: AVATAR_UI.shelf.boxPulse.halfCycleMs,
    friendFresh: AVATAR_UI.book.freshPulse.halfCycleMs,
    // Ekonomi (UI.md §14.9)
    shopWake: ECONOMY_UI.wake.breath.halfCycleMs,
    // Start v2 (UI.md §16.10): SPELA-pulsen, kortens "nytt"-andning (badge), musslans studs (cykel 2 s), Glimtens gupp.
    playPulse: START_UI.play.pulse.halfCycleMs,
    cardFresh: START_UI.cards.freshBreath.halfCycleMs,
    shellPeek: (START_UI.cards.shop.peek.upMs + START_UI.cards.shop.peek.downMs + START_UI.cards.shop.peek.restMs) / 2,
    heroBob: START_UI.hero.bob.halfCycleMs,
  },
  /**
   * Alla färger som ingår i en ljusstyrkeväxling. Ingen mättad röd, ingen ren vit blixt.
   */
  pulseColors: [
    THEME.palette.danger,
    THEME.palette.dangerHot,
    THEME.palette.gold,
    THEME.palette.accent,
  ] as readonly string[],
} as const;

export interface RingWave {
  /** Antal ringar. */
  count: number;
  /** Startradie i px (utelämnad = nästan 0). */
  fromR?: number;
  /** Radie i px som ringen växer till. */
  maxR: number;
  durationMs: number;
  /** Fördröjning mellan ringarna. */
  stepMs: number;
  color: string;
  alpha: number;
}

/**
 * Expanderande strokade ringar i stället för vitblixtar (UI.md §6, §10.3).
 * Events som saknas här ritar ingen ring.
 */
export const RINGS: Partial<Record<JuiceEvent, RingWave>> = {
  bomb: {
    count: 1,
    maxR: SPECIALS.bomb.blastRadius,
    durationMs: 420,
    stepMs: 0,
    color: THEME.palette.accent2,
    alpha: 0.9,
  },
  jackpot: {
    count: 3,
    maxR: 210,
    durationMs: 640,
    stepMs: 120,
    color: THEME.palette.gold,
    alpha: 0.85,
  },
};

/** Events utan egen post i ljudkartan lånar ett annat ljud (UI.md §8). */
export const SOUND_ALIAS: Partial<Record<JuiceEvent, JuiceEvent>> = {
  jackpot: 'newRecord',
  specialDrop: 'special',
};

/** Combo, kedja, fara och rekordjakt (DESIGN §5). */
export const FEEL = {
  combo: { windowMs: 1200, maxDots: 12 },
  /** En merge som direkt orsakar nästa räknas som kedja. */
  chain: { windowMs: 450, minLength: 3, intensity: 0.8 },
  danger: {
    /** Objektets centrum inom så här många px UNDER farolinjen. */
    marginPx: 40,
    timeScale: THEME.anim.slowmoIn.timeScale,
    inMs: THEME.anim.slowmoIn.durationMs,
    outMs: THEME.anim.slowmoOut.durationMs,
    maxTriggers: 3,
    windowMs: 10_000,
    /** Minsta tid i lugn innan faran räknas som över. */
    releaseMs: 400,
  },
  record: { thresholdPct: 0.9, intensity: 0.5, newRecordIntensity: 0.9 },
  /**
   * Near-miss (DESIGN §5): två objekt av nivå ≥ minLevel med gap i (minGapPx, maxGapPx).
   * minGapPx > 0 gör att objekt som nuddar aldrig ger puls.
   */
  nearMiss: {
    minLevel: 8,
    minGapPx: 1,
    maxGapPx: 20,
    /** Kontrollen körs var N:e frame (throttlad, O(n²) bara på nivå ≥8). */
    checkEveryFrames: 10,
    scale: THEME.anim.nearMiss.scale,
    halfCycleMs: THEME.anim.nearMiss.durationMs,
  },
  onboarding: { idleMs: 5000, handY: 80, handSpanX: 80 },
} as const;

/** Intensitet för en vanlig merge: 0,25–0,45 från nivå, + combo-bonus (UI.md §6). */
export function mergeIntensity(level: number, combo: number): number {
  const byLevel = 0.25 + (level / MAX_LEVEL) * 0.2;
  const byCombo = Math.min(combo, 4) * 0.07;
  return Math.min(1, byLevel + byCombo);
}

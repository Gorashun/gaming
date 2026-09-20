/**
 * All balansering av game feel. DESIGN.md §5–6, UI.md §5–6.
 * Ingen Phaser-import: ren data så att den kan testas utan rendering.
 */
import { THEME } from './theme';
import { MAX_LEVEL } from './levels';

export type JuiceEvent =
  | 'drop'
  | 'land'
  | 'merge'
  | 'chain'
  | 'special'
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
  onboarding: { idleMs: 5000 },
} as const;

/** Intensitet för en vanlig merge: 0,25–0,45 från nivå, + combo-bonus (UI.md §6). */
export function mergeIntensity(level: number, combo: number): number {
  const byLevel = 0.25 + (level / MAX_LEVEL) * 0.2;
  const byCombo = Math.min(combo, 4) * 0.07;
  return Math.min(1, byLevel + byCombo);
}

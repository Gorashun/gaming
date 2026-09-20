/**
 * Mjuk auto-drop (DESIGN.md §11). Ren logik: in går tid och tillstånd, ut går fas och
 * vickningsvinkel. Ingen Phaser, inga scener – testbar utan rendering.
 *
 * Villkor för att pacing ska vara aktiv alls:
 * bara mode 'flow', bara regissörens Flöde-läge, aldrig på specialobjekt,
 * aldrig under fara/slow-mo/hit-stop, aldrig i Lugnt läge, och inte förrän spelaren
 * gjort sitt första egna drop i rundan (beslut 2026-09-20).
 */
import { PACING, type PacingConfig } from '../data/pacing';

export type PacingPhase = 'idle' | 'nudge' | 'autodrop';

/** Allt som kan blockera pacing. Tidsoberoende. */
export interface PacingConditions {
  mode: PacingConfig['mode'];
  /** Regissörens läge för det objekt som hänger nu: 'drought' | 'flow' | 'kick'. */
  directorMode: string;
  isSpecial: boolean;
  isDanger: boolean;
  /** Hit-stop eller slow-mo pågår. */
  isTimeStopped: boolean;
  calm: boolean;
  /** Spelaren har gjort minst ett eget drop i den här rundan. */
  hasDroppedThisRun: boolean;
}

export interface PacingInput extends PacingConditions {
  nowMs: number;
  /** När det hängande objektet blev släppbart (cooldown klar). null = inget att släppa. */
  readySinceMs: number | null;
}

export interface PacingResult {
  phase: PacingPhase;
  /** Grader, |vinkel| ≤ cfg.wobbleDeg. 0 när fasen är 'idle'. */
  wobbleAngleDeg: number;
}

const TAU = Math.PI * 2;

/** Är pacing blockerad av tillståndet just nu? (Säger inget om timern.) */
export function isPacingBlocked(c: PacingConditions): boolean {
  return (
    c.mode !== 'flow' ||
    c.directorMode !== 'flow' ||
    c.isSpecial ||
    c.isDanger ||
    c.isTimeStopped ||
    c.calm ||
    !c.hasDroppedThisRun
  );
}

/**
 * Räknar ut fas och vickning. `out` återanvänds av anroparen så att update() inte allokerar.
 */
export function evaluatePacing(
  input: PacingInput,
  out: PacingResult = { phase: 'idle', wobbleAngleDeg: 0 },
  cfg: PacingConfig = PACING,
): PacingResult {
  out.phase = 'idle';
  out.wobbleAngleDeg = 0;

  if (isPacingBlocked(input)) return out;
  if (input.readySinceMs === null) return out;

  const elapsed = input.nowMs - input.readySinceMs;
  if (elapsed < cfg.nudgeAtMs) return out;

  out.phase = elapsed >= cfg.autoDropAtMs ? 'autodrop' : 'nudge';
  out.wobbleAngleDeg =
    cfg.wobbleDeg * Math.sin((TAU * cfg.wobbleHz * (elapsed - cfg.nudgeAtMs)) / 1000);
  return out;
}

export interface PacerInput extends PacingConditions {
  nowMs: number;
}

/**
 * Pacern äger timern så att övergångarna går att testa utan rendering:
 * timern startar när objektet blir släppbart, nollställs vid drop, och nollställs igen
 * i det ögonblick ett blockerande villkor upphör (objektet får aldrig falla direkt när
 * faran släpper). Inga allokeringar efter skapandet.
 */
export interface Pacer {
  /** Anropas varje frame. Returnerar pacerns återanvända result-objekt. */
  update(input: PacerInput): PacingResult;
  /** Objektet blev släppbart (cooldown klar): timern startar. */
  ready(nowMs: number): void;
  /** Objektet släpptes: timern stoppas. */
  drop(): void;
  /** Ny runda. */
  reset(): void;
  /** Tidpunkten timern räknar från, eller null. */
  readonly readySinceMs: number | null;
  readonly result: PacingResult;
}

export function createPacer(cfg: PacingConfig = PACING): Pacer {
  const out: PacingResult = { phase: 'idle', wobbleAngleDeg: 0 };
  const input: PacingInput = {
    mode: 'off',
    nowMs: 0,
    readySinceMs: null,
    directorMode: 'flow',
    isSpecial: false,
    isDanger: false,
    isTimeStopped: false,
    calm: false,
    hasDroppedThisRun: false,
  };
  let readySince: number | null = null;
  let wasBlocked = true;

  return {
    get readySinceMs(): number | null {
      return readySince;
    },
    get result(): PacingResult {
      return out;
    },

    update(c: PacerInput): PacingResult {
      const blocked = isPacingBlocked(c);
      // Blockerad → fri: börja om från noll, aldrig ett auto-drop i samma andetag.
      if (wasBlocked && !blocked && readySince !== null) readySince = c.nowMs;
      wasBlocked = blocked;

      input.mode = c.mode;
      input.nowMs = c.nowMs;
      input.readySinceMs = readySince;
      input.directorMode = c.directorMode;
      input.isSpecial = c.isSpecial;
      input.isDanger = c.isDanger;
      input.isTimeStopped = c.isTimeStopped;
      input.calm = c.calm;
      input.hasDroppedThisRun = c.hasDroppedThisRun;
      return evaluatePacing(input, out, cfg);
    },

    ready(nowMs: number): void {
      readySince = nowMs;
    },

    drop(): void {
      readySince = null;
      out.phase = 'idle';
      out.wobbleAngleDeg = 0;
    },

    reset(): void {
      readySince = null;
      wasBlocked = true;
      out.phase = 'idle';
      out.wobbleAngleDeg = 0;
    },
  };
}

/**
 * Fara och slow-mo (DESIGN.md §5). Ren logik: in går "är något objekt nära linjen",
 * ut går 'start' | 'end' | null. Max N triggers per tidsfönster.
 */
import { FEEL } from '../data/juice';

export type DangerSignal = 'start' | 'end' | null;

export interface DangerTracker {
  /** Anropas varje frame. `near` = minst ett objekt inom marginalen. */
  update(nowMs: number, near: boolean): DangerSignal;
  readonly active: boolean;
  reset(): void;
}

export function createDangerTracker(
  cfg: { maxTriggers: number; windowMs: number; releaseMs: number } = {
    maxTriggers: FEEL.danger.maxTriggers,
    windowMs: FEEL.danger.windowMs,
    releaseMs: FEEL.danger.releaseMs,
  },
): DangerTracker {
  let active = false;
  let safeSince = 0;
  const triggers: number[] = [];

  return {
    get active() {
      return active;
    },
    update(nowMs, near) {
      if (near) {
        safeSince = 0;
        if (active) return null;
        while (triggers.length > 0 && nowMs - triggers[0] > cfg.windowMs) triggers.shift();
        if (triggers.length >= cfg.maxTriggers) return null;
        triggers.push(nowMs);
        active = true;
        return 'start';
      }
      if (!active) return null;
      if (safeSince === 0) safeSince = nowMs;
      if (nowMs - safeSince < cfg.releaseMs) return null;
      active = false;
      safeSince = 0;
      return 'end';
    },
    reset() {
      active = false;
      safeSince = 0;
      triggers.length = 0;
    },
  };
}

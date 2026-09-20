/**
 * Combo och kedja (DESIGN.md §5). Ren logik, ingen rendering.
 * Combo: merges inom `windowMs` efter föregående merge ökar combo.
 * Kedja: en merge som direkt orsakas av en tidigare merge.
 */
import { FEEL } from '../data/juice';

export interface ComboState {
  /** 0 = ingen pågående combo. */
  combo: number;
  /** Längden på den pågående kedjan (1 = fristående merge). */
  chain: number;
  /** Sann när kedjan just nådde `minLength`. */
  chainTriggered: boolean;
}

export interface ComboTracker {
  /** Registrera en merge. `causedByMerge` = minst ett objekt skapades av en merge. */
  merge(nowMs: number, causedByMerge: boolean): ComboState;
  /** Nollställ combo om fönstret gått ut. Returnerar true om något nollställdes. */
  tick(nowMs: number): boolean;
  reset(): void;
  readonly state: ComboState;
}

export function createComboTracker(
  cfg: { windowMs: number; chainWindowMs: number; chainMin: number } = {
    windowMs: FEEL.combo.windowMs,
    chainWindowMs: FEEL.chain.windowMs,
    chainMin: FEEL.chain.minLength,
  },
): ComboTracker {
  const state: ComboState = { combo: 0, chain: 0, chainTriggered: false };
  let lastMs = -Infinity;

  return {
    state,
    merge(nowMs, causedByMerge) {
      const dt = nowMs - lastMs;
      state.combo = dt <= cfg.windowMs ? state.combo + 1 : 1;
      const isChain = causedByMerge && dt <= cfg.chainWindowMs;
      state.chain = isChain ? state.chain + 1 : 1;
      state.chainTriggered = state.chain === cfg.chainMin;
      lastMs = nowMs;
      return state;
    },
    tick(nowMs) {
      if (state.combo === 0) return false;
      if (nowMs - lastMs <= cfg.windowMs) return false;
      state.combo = 0;
      state.chain = 0;
      state.chainTriggered = false;
      return true;
    },
    reset() {
      state.combo = 0;
      state.chain = 0;
      state.chainTriggered = false;
      lastMs = -Infinity;
    },
  };
}

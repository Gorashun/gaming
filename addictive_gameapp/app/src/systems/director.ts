import { QUEUE_LEVELS } from '../data/levels';
import type { Rng } from './rng';

/**
 * Regissören bestämmer ENDAST nivån på nästa köobjekt (DESIGN.md §4).
 * Lägena torka/flöde/kick implementeras i fas 3 – gränssnittet finns redan nu.
 */
export interface DirectorState {
  /** Antal drops i rundan hittills. */
  dropIndex: number;
  /** Nivåerna på objekten som just nu ligger i burken. */
  board: readonly number[];
}

export interface Director {
  next(state: DirectorState): number;
  reset(): void;
}

export function createDirector(rng: Rng): Director {
  return {
    // Fas 1: likformigt bland köbara nivåer (0–4).
    next(_state: DirectorState): number {
      return rng.pick(QUEUE_LEVELS);
    },
    reset(): void {
      /* fas 3 */
    },
  };
}

import { QUEUE_LEVELS } from '../data/levels';
import { DIRECTOR, type SpecialType } from '../data/director';
import type { Rng } from './rng';

/**
 * Regissören bestämmer ENDAST vad nästa köobjekt blir (DESIGN.md §4).
 * Rör aldrig fysiken, importerar aldrig en scen, är seedbar och testbar utan rendering.
 * Lägen: Torka → Flöde → Torka → Flöde …, avbrutna av Kick (ett specialobjekt).
 */

export type DirectorMode = 'drought' | 'flow' | 'kick';

export type DirectorPick =
  | { kind: 'level'; level: number }
  | { kind: 'special'; type: SpecialType };

/** Sammanfattning av burken. Scenen räknar ut den enligt DESIGN §4. */
export interface DirectorState {
  /** Nivåer som just nu kan mergea direkt. */
  mergeableLevels: ReadonlySet<number>;
}

export interface Director {
  next(state: DirectorState): DirectorPick;
  /** Läget som senaste `next()` använde (HUD/debug). */
  readonly mode: DirectorMode;
  /** Antal drops sedan senaste Kick. */
  readonly dropsSinceKick: number;
  reset(): void;
}

/** Likformigt bland köbara nivåer där `mergeable.has(level) === want`. Inga allokeringar. */
function pickLevel(rng: Rng, mergeable: ReadonlySet<number>, want: boolean): number {
  let n = 0;
  for (let i = 0; i < QUEUE_LEVELS.length; i++) {
    if (mergeable.has(QUEUE_LEVELS[i]) === want) n++;
  }
  if (n === 0) return rng.pick(QUEUE_LEVELS);
  let k = Math.floor(rng.next() * n);
  for (let i = 0; i < QUEUE_LEVELS.length; i++) {
    if (mergeable.has(QUEUE_LEVELS[i]) !== want) continue;
    if (k-- === 0) return QUEUE_LEVELS[i];
  }
  return QUEUE_LEVELS[QUEUE_LEVELS.length - 1];
}

export function createDirector(rng: Rng): Director {
  let mode: DirectorMode = 'flow';
  let modeLeft: number = DIRECTOR.openingFlowDrops;
  let dropsSinceKick = 0;
  let kickTarget = rng.int(DIRECTOR.kickEvery.min, DIRECTOR.kickEvery.max);

  return {
    get mode(): DirectorMode {
      return mode;
    },
    get dropsSinceKick(): number {
      return dropsSinceKick;
    },

    next(state: DirectorState): DirectorPick {
      dropsSinceKick++;
      if (dropsSinceKick >= kickTarget) {
        // Kick: ett specialobjekt, sedan tillbaka till Torka.
        mode = 'kick';
        modeLeft = 0;
        dropsSinceKick = 0;
        kickTarget = rng.int(DIRECTOR.kickEvery.min, DIRECTOR.kickEvery.max);
        return { kind: 'special', type: rng.pick(DIRECTOR.specials) };
      }

      if (modeLeft <= 0) {
        mode = mode === 'drought' ? 'flow' : 'drought';
        const d = mode === 'drought' ? DIRECTOR.drought : DIRECTOR.flow;
        modeLeft = rng.int(d.min, d.max);
      }
      modeLeft--;

      const m = state.mergeableLevels;
      if (mode === 'flow') {
        const prefer = rng.next() < DIRECTOR.flow.preferMergeableP;
        return { kind: 'level', level: prefer ? pickLevel(rng, m, true) : rng.pick(QUEUE_LEVELS) };
      }
      const avoid = rng.next() < DIRECTOR.drought.avoidMergeableP;
      return { kind: 'level', level: avoid ? pickLevel(rng, m, false) : rng.pick(QUEUE_LEVELS) };
    },

    reset(): void {
      mode = 'flow';
      modeLeft = DIRECTOR.openingFlowDrops;
      dropsSinceKick = 0;
      kickTarget = rng.int(DIRECTOR.kickEvery.min, DIRECTOR.kickEvery.max);
    },
  };
}

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

/**
 * Förbeställt specialobjekt (förmågor, DESIGN §14.5): läggs som drop nr `atDrop` (1 = första
 * objektet i rundan). `type: null` = regissörens Kick-tabell. Påverkar inte Kick-räknaren.
 */
export interface SeedEntry {
  atDrop: number;
  type: SpecialType | null;
}

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
  /** Förbeställda specialobjekt för rundan (ersätter tidigare). */
  setSeedQueue(entries: readonly SeedEntry[]): void;
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
  let picks = 0;
  let seeded: readonly SeedEntry[] = [];

  return {
    get mode(): DirectorMode {
      return mode;
    },
    get dropsSinceKick(): number {
      return dropsSinceKick;
    },

    next(state: DirectorState): DirectorPick {
      picks++;
      for (let i = 0; i < seeded.length; i++) {
        if (seeded[i].atDrop === picks) return { kind: 'special', type: seeded[i].type ?? rng.pick(DIRECTOR.specials) };
      }
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
      picks = 0;
      kickTarget = rng.int(DIRECTOR.kickEvery.min, DIRECTOR.kickEvery.max);
    },

    setSeedQueue(entries: readonly SeedEntry[]): void {
      seeded = entries.slice();
    },
  };
}

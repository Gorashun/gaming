/** Objektnivåer enligt DESIGN.md §2. All balansering sker här, aldrig i scener. */
export interface LevelDef {
  /** 0..10 */
  level: number;
  /** Radie i px vid logisk burkbredd 360. */
  radius: number;
  /** Poäng när objektet skapas (triangulärt tal). */
  score: number;
  /** Extra poäng utöver `score` när objektet skapas (endast högsta nivån). */
  bonus: number;
  /** Får nivån dyka upp i kön? */
  inQueue: boolean;
}

export const LEVELS: readonly LevelDef[] = [
  { level: 0, radius: 14, score: 1, bonus: 0, inQueue: true },
  { level: 1, radius: 19, score: 3, bonus: 0, inQueue: true },
  { level: 2, radius: 25, score: 6, bonus: 0, inQueue: true },
  { level: 3, radius: 31, score: 10, bonus: 0, inQueue: true },
  { level: 4, radius: 38, score: 15, bonus: 0, inQueue: true },
  { level: 5, radius: 46, score: 21, bonus: 0, inQueue: false },
  { level: 6, radius: 55, score: 28, bonus: 0, inQueue: false },
  { level: 7, radius: 64, score: 36, bonus: 0, inQueue: false },
  { level: 8, radius: 74, score: 45, bonus: 0, inQueue: false },
  { level: 9, radius: 85, score: 55, bonus: 0, inQueue: false },
  { level: 10, radius: 97, score: 66, bonus: 500, inQueue: false },
];

export const MAX_LEVEL = LEVELS.length - 1;

/** Poäng när två nivå-10 möts och båda försvinner. */
export const TOP_PAIR_SCORE = 1000;

/** Nivåer som regissören får lägga i kön. */
export const QUEUE_LEVELS: readonly number[] = LEVELS.filter((l) => l.inQueue).map((l) => l.level);

export function radiusOf(level: number): number {
  return LEVELS[level].radius;
}

/** Poäng för att skapa ett objekt av given nivå (inkl. bonus). */
export function scoreForCreating(level: number): number {
  const def = LEVELS[level];
  return def.score + def.bonus;
}

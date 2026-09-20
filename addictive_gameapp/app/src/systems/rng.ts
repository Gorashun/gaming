/** Seedbar RNG (mulberry32). Används av regissören och alla belöningsberäkningar. */
export interface Rng {
  /** [0,1) */
  next(): number;
  /** Heltal i [min, max] inklusive. */
  int(min: number, max: number): number;
  /** Slumpat element ur en lista. */
  pick<T>(items: readonly T[]): T;
}

export function mulberry32(seed: number): Rng {
  let a = seed >>> 0;
  const next = (): number => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  return {
    next,
    int: (min, max) => min + Math.floor(next() * (max - min + 1)),
    pick: (items) => items[Math.floor(next() * items.length)],
  };
}

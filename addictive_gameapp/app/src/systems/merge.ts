/** Ren merge-logik, utan Phaser. Se DESIGN.md §3. */

export interface MergeCandidate {
  /** Unikt id för body A. */
  a: number;
  /** Unikt id för body B. */
  b: number;
  levelA: number;
  levelB: number;
}

export interface MergePair {
  a: number;
  b: number;
  /** Nivån de båda har. */
  level: number;
}

/**
 * Avgör vilka kollisionspar som ska mergeas denna frame.
 * Regler: samma nivå, inte samma body, och ingen body får ingå i mer än ett par.
 * Första giltiga paret för en body vinner (kollisionsordningen från Matter).
 */
export function resolveMerges(pairs: readonly MergeCandidate[]): MergePair[] {
  const used = new Set<number>();
  const out: MergePair[] = [];
  for (let i = 0; i < pairs.length; i++) {
    const p = pairs[i];
    if (p.a === p.b) continue;
    if (p.levelA !== p.levelB) continue;
    if (used.has(p.a) || used.has(p.b)) continue;
    used.add(p.a);
    used.add(p.b);
    out.push({ a: p.a, b: p.b, level: p.levelA });
  }
  return out;
}

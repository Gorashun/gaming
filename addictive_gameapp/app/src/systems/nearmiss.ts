/**
 * Äkta near-miss (DESIGN.md §5): två objekt av nivå ≥ minLevel som har mindre än
 * maxGapPx mellan sig men INTE nuddar. Ren geometri, ingen rendering, inga allokeringar
 * (skriver index i `out`, som återanvänds av anroparen). Aldrig falsk positiv:
 * gapet måste vara strikt större än minGapPx, så objekt som ligger an räknas aldrig.
 */

export interface NearMissItem {
  /** Nivå, eller < 0 för objekt som aldrig ska räknas (specialobjekt). */
  level: number;
  x: number;
  y: number;
  r: number;
}

export interface NearMissCfg {
  readonly minLevel: number;
  readonly minGapPx: number;
  readonly maxGapPx: number;
}

/**
 * Fyller `out` med index på objekt som ingår i minst ett near-miss-par (kan förekomma
 * flera gånger). Returnerar antalet index.
 */
export function findNearMiss(
  items: readonly NearMissItem[],
  count: number,
  cfg: NearMissCfg,
  out: number[],
): number {
  out.length = 0;
  for (let i = 0; i < count; i++) {
    const a = items[i];
    if (a.level < cfg.minLevel) continue;
    for (let j = i + 1; j < count; j++) {
      const b = items[j];
      if (b.level < cfg.minLevel) continue;
      const dx = b.x - a.x;
      const dy = b.y - a.y;
      const gap = Math.sqrt(dx * dx + dy * dy) - a.r - b.r;
      if (gap <= cfg.minGapPx || gap >= cfg.maxGapPx) continue;
      out.push(i);
      out.push(j);
    }
  }
  return out.length;
}

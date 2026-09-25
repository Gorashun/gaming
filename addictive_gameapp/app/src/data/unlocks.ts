/**
 * Upplåsning av temaset (DESIGN §13.3). Ren data. Det spår som når sitt k:e steg först
 * låser upp set nummer k; vilket set det blir dras slumpvis (seedat) bland återstående.
 */
export const UNLOCKS = {
  /** Tidsspår: ackumulerade merges. Startvärden, mät `merges per runda`. */
  mergeThresholds: [200, 600, 1500, 3000] as readonly number[],
  /** Skicklighetsspår: varje uppfyllt villkor räknas som ett steg. */
  skill: {
    /** Första gången nivån nås (stats.maxLevelEver). */
    levels: [8, 10] as readonly number[],
    /** Första dubbel-Klunk (två nivå 10 slås ihop). */
    doubleKlunks: 1,
    /** Första fulla boksida (x/21). */
    fullPage: true,
  },
} as const;

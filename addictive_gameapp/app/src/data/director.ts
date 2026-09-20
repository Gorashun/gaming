/**
 * Regissörens balansering (DESIGN.md §4). Ren data, ingen logik, ingen Phaser.
 * Allt som ska justeras efter speltest bor här.
 */

export type SpecialType = 'bomb' | 'rainbow';

export const DIRECTOR = {
  /** De första dropsen i en runda är alltid Flöde (onboarding, DESIGN §4). */
  openingFlowDrops: 10,
  /** Torka: likformigt 0–4, undviker mergebara nivåer med sannolikhet `avoidMergeableP`. */
  drought: { min: 15, max: 40, avoidMergeableP: 0.7 },
  /** Flöde: väljer en mergebar nivå med sannolikhet `preferMergeableP`, annars likformigt. */
  flow: { min: 8, max: 20, preferMergeableP: 0.6 },
  /** Kick: ett specialobjekt när så här många drops gått sedan förra kicken. */
  kickEvery: { min: 25, max: 60 },
  specials: ['bomb', 'rainbow'] as const satisfies readonly SpecialType[],
  /**
   * "Kan mergea direkt" (DESIGN §4): objektets ovansida ligger inom så här många px
   * från farolinjen, ELLER objektet är översta objektet i sin kolumn.
   */
  mergeableWithinPx: 120,
  /** Antal kolumner när "översta objektet i sin kolumn" uppskattas. */
  columns: 8,
} as const;

/** Specialobjekten (DESIGN §4). Radie 25 för båda. */
export const SPECIALS = {
  radius: 25,
  /** Ligger de kvar utan att ha träffat något så här länge efter landning aktiveras de ändå. */
  fallbackMs: 3000,
  bomb: {
    /** Förstör allt inom denna radie vid första kontakt. */
    blastRadius: 110,
    /** Poäng = summan av förstörda nivåers poäng × detta. */
    scoreMultiplier: 2,
    intensity: 1,
  },
  rainbow: {
    intensity: 0.8,
    /** Hur nära ett vanligt objekt måste ligga vid nödaktivering (extra gap i px). */
    reachPx: 10,
  },
} as const;

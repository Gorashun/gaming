/**
 * Mjuk auto-drop (DESIGN.md §11) med ramp (DESIGN.md §12). Ren data, ingen logik, ingen Phaser.
 * "Ingen synlig nedräkning och inget tidsbaserat straff" – objektet vickar och faller själv.
 */

export type PacingMode = 'off' | 'flow';

export interface PacingConfig {
  /** 'off' = helt av. 'flow' = aktiv, men bara i regissörens Flöde-läge. */
  mode: PacingMode;
  /** Auto-drop-tid vid rundans första drop. */
  rampStartMs: number;
  /** Auto-drop-tid vid `rampDrops` drops och därefter (golv). */
  rampEndMs: number;
  /** Antal drops i rundan innan golvet nås. */
  rampDrops: number;
  /** Vickningens amplitud i grader (±). Ingen ljusstyrkeändring. */
  wobbleDeg: number;
  /** Vickningens frekvens i Hz. Hålls långt under flash-gränsen (3 Hz). */
  wobbleHz: number;
}

export const PACING: PacingConfig = {
  mode: 'flow',
  rampStartMs: 6000,
  rampEndMs: 3500,
  rampDrops: 60,
  wobbleDeg: 4,
  wobbleHz: 0.8,
};

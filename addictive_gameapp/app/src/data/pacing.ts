/**
 * Mjuk auto-drop (DESIGN.md §11). Ren data, ingen logik, ingen Phaser.
 * "Ingen synlig nedräkning och inget tidsbaserat straff" – objektet vickar och faller själv.
 */

export type PacingMode = 'off' | 'flow';

export interface PacingConfig {
  /** 'off' = helt av. 'flow' = aktiv, men bara i regissörens Flöde-läge. */
  mode: PacingMode;
  /** Efter så här lång tid utan drop börjar objektet vicka. */
  nudgeAtMs: number;
  /** Efter så här lång tid faller objektet själv, rakt ner där det hänger. */
  autoDropAtMs: number;
  /** Vickningens amplitud i grader (±). Ingen ljusstyrkeändring. */
  wobbleDeg: number;
  /** Vickningens frekvens i Hz. Hålls långt under flash-gränsen (3 Hz). */
  wobbleHz: number;
}

export const PACING: PacingConfig = {
  mode: 'flow',
  nudgeAtMs: 3000,
  autoDropAtMs: 6000,
  wobbleDeg: 4,
  wobbleHz: 0.8,
};

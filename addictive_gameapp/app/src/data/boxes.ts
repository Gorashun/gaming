/** Musslor (DESIGN §14.3). Ren data: intjäning och hur öppningen ser ut. */
import type { Rarity } from './avatarsIndex';

export interface BoxConfig {
  /** Mussla nummer k vid round(base·k^exp) ackumulerade merges ⇒ 50, 123, 209 … */
  readonly base: number;
  readonly exp: number;
  /** Skicklighetsmusslor: första gången nivån nås (stats.maxLevelEver). */
  readonly skillLevels: readonly number[];
  /** Första musslan är alltid denna raritet (onboarding). */
  readonly firstRarity: Rarity;
}

export const BOXES: BoxConfig = {
  base: 50,
  exp: 1.3,
  skillLevels: [7, 8, 9, 10],
  firstRarity: 'rare',
};

// Grafik, layout och tider för musslorna: AVATAR_UI i avatars.ts (UI.md §13.9 ersatte BOX_FX).

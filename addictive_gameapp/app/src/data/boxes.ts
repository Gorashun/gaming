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

/** Platshållargrafik och tider tills UI-specen (UI.md §13) finns. */
export const BOX_FX = {
  shellColor: '#FFE3C2',
  shellEdge: '#C9A27E',
  /** Mussla på hyllan: första position, max antal ritade, förskjutning mellan dem. */
  shelf: { x: 104, y: 454, size: 30, maxShown: 3, dx: 8, dy: -6, hit: 72 },
  /** Puls på hyllan: halvcykel 1 000 ms ⇒ 0,5 Hz (≤1 Hz). */
  pulse: { scale: 1.1, halfCycleMs: 1000 },
  /** Rundavslutet: musslan poppar in och flyger till hyllan. Totalt ≤400 ms. */
  fly: { x: 180, y: 130, toX: 104, toY: 640, popMs: 140, flyMs: 260, size: 34 },
  /** Öppning på startskärmen, fast tid. */
  /** Fast tid 1 200 ms: musslan 0–200, figuren poppar vid 200, ringarna klingar ut före 1 200. */
  open: {
    x: 180,
    y: 300,
    shellMs: 200,
    shellScale: 2.4,
    avatarR: 48,
    popMs: 320,
    pearlsY: 378,
    pearlR: 6,
    pearlPitch: 18,
    scrimAlpha: 0.82,
    /** Jackpot-juice utan shake/zoom, intensitet per raritet. */
    intensity: { common: 0.3, uncommon: 0.42, rare: 0.54, epic: 0.66, legendary: 0.78, mythic: 0.9 } as Readonly<
      Record<Rarity, number>
    >,
    ring: { count: 2, fromR: 50, maxR: 110, durationMs: 640, stepMs: 140, alpha: 0.85 },
  },
  /** Fliken Kompisar i boken (UI.md §13 ersätter). */
  friends: {
    tabs: { y: 40, xSet: 40, xFriends: 120, icon: 36, hit: 72 },
    headerH: 84,
    cols: 6,
    cell: 48,
    gap: 8,
    avatarR: 17,
    ringW: 3,
    levelPearlR: 3,
    levelPearlPitch: 9,
    groupGap: 14,
    jar: { x: 180, y: 150, w: 104, h: 104, pearls: 25, pearlR: 6, pitch: 15, cols: 5 },
    gridTop: 232,
    silhouetteAlpha: 0.25,
    bottomPad: 24,
  },
} as const;

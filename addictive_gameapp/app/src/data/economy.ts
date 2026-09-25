/**
 * Ekonomi (DESIGN §16): pärlor, stjärnsand, musslor i butik och uppgradering.
 * Ren data. Logiken ligger i systems/economy.ts.
 */
import type { Rarity } from './avatarsIndex';

export type ShellType = 'common' | 'silver' | 'gold';
export type ShopMode = 'random' | 'pick3';

export interface Price {
  readonly pearls?: number;
  readonly sand?: number;
}

export interface ShellDef {
  readonly price: Price;
  /** Lägsta raritet musslan kan ge. */
  readonly floor: Rarity;
  /** Vikter i RARITY.order-ordning (vanlig … mytisk), omnormeras bland rariteter ≥ golvet med figurer kvar. */
  readonly odds: readonly number[];
}

export const ECONOMY = {
  pearlsPerMerge: 1,
  sand: {
    /** Per skimrande som skapas. */
    shiny: 1,
    /** Per kedja ≥3, högst `chain3MaxPerRun` per runda. */
    chain3: 1,
    chain3MaxPerRun: 3,
    /** Per nivå 10 som skapas. */
    level10: 2,
    /** Engångs: första nivå 7, 8, 9, 10, första skimrande, första dubbel-Klunk. */
    milestone: 3,
    /** Per full boksida (engångs per set). */
    fullPage: 10,
  },
  /** Nivåer som ger engångsmilstolpe första gången de nås. */
  milestoneLevels: [7, 8, 9, 10] as readonly number[],
  shells: {
    common: { price: { pearls: 300 }, floor: 'common', odds: [50, 30, 13, 5, 1.5, 0.5] },
    silver: { price: { pearls: 700 }, floor: 'uncommon', odds: [0, 50, 30, 14, 4.5, 1.5] },
    gold: { price: { sand: 50 }, floor: 'rare', odds: [0, 0, 50, 32, 13, 5] },
  } as Readonly<Record<ShellType, ShellDef>>,
  /** Gratismusslor (vanlig) räknat från `mergesBaseline`: vid 120 och 400, sedan var 750:e. */
  free: { at: [120, 400] as readonly number[], every: 750, sandWhenComplete: 10 },
  /** [I→II i pärlor, II→III i pärlor + sand] per raritet. */
  upgrade: {
    common: [80, { pearls: 200, sand: 4 }],
    uncommon: [100, { pearls: 250, sand: 6 }],
    rare: [150, { pearls: 400, sand: 10 }],
    epic: [200, { pearls: 550, sand: 15 }],
    legendary: [250, { pearls: 700, sand: 20 }],
    mythic: [300, { pearls: 800, sand: 24 }],
  } as Readonly<Record<Rarity, readonly [number, { pearls: number; sand: number }]>>,
  /** Första musslan i spelarens liv är alltid sällsynt, oavsett typ (onboarding). */
  firstShellRare: true,
  firstRarity: 'rare' as Rarity,
  /** Reservflagga (DESIGN §16): 'pick3' = välj 1 av 3 synliga. */
  shopMode: 'random' as ShopMode,
};

/**
 * STUB för Kompisar (DESIGN §14.2–14.4) tills UI-designerns `avatars.ts` finns.
 * Samma exportnamn. Importeras bara via `avatarsIndex.ts`. Inga ritrecept här.
 * Vanlig/ovanlig har platshållarnamn; sällsynt och uppåt enligt DESIGN §14.5.
 */
export type Rarity = 'common' | 'uncommon' | 'rare' | 'epic' | 'legendary' | 'mythic';

export interface AvatarDef {
  readonly id: string;
  readonly name: string;
  readonly rarity: Rarity;
}

const named = (rarity: Rarity, names: readonly string[]): AvatarDef[] =>
  names.map((name) => ({ id: name.toLowerCase().replace(/[^a-zåäö]+/g, '-'), name, rarity }));
const numbered = (rarity: Rarity, prefix: string, n: number): AvatarDef[] =>
  Array.from({ length: n }, (_, i) => ({ id: `${rarity}-${i + 1}`, name: `${prefix}${i + 1}`, rarity }));

export const AVATARS: readonly AvatarDef[] = [
  ...numbered('common', 'V', 16),
  ...numbered('uncommon', 'O', 12),
  ...named('rare', ['Muller', 'Maestro', 'Tick', 'Fia', 'Vulle', 'Disco', 'Eko', 'Klick', 'Nora']),
  ...named('epic', ['Lisa', 'Siri', 'Sixten', 'Bubbel', 'Ekko', 'Kajsa']),
  ...named('legendary', ['Maja', 'Rut', 'Vala']),
  ...named('mythic', ['Havsdrottningen', 'Stjärnvalen']),
];

export const RARITY = {
  order: ['common', 'uncommon', 'rare', 'epic', 'legendary', 'mythic'] as readonly Rarity[],
  /** Aldrig rött (rött = fara). Mytisk är regnbåge i K1; här en enda färg. */
  color: {
    common: '#A9B4C8',
    uncommon: '#6EE7A0',
    rare: '#5AA9FF',
    epic: '#B98CFF',
    legendary: '#FFD75E',
    mythic: '#FF9CF0',
  } as Readonly<Record<Rarity, string>>,
  pearls: { common: 1, uncommon: 2, rare: 3, epic: 4, legendary: 5, mythic: 6 } as Readonly<Record<Rarity, number>>,
  /** Odds i procent (DESIGN §14.3), omnormeras bland rariteter med figurer kvar. */
  odds: { common: 44, uncommon: 28, rare: 16, epic: 8, legendary: 3, mythic: 1 } as Readonly<Record<Rarity, number>>,
} as const;

/** Kumulativ XP för nivå II och III (DESIGN §14.4). */
export const UPGRADE = { xpII: 150, xpIII: 450 } as const;

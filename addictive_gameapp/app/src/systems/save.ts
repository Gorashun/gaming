/** Persistens. localStorage nu, Capacitor Preferences senare via adaptern. */

export interface SaveData {
  highscore: number;
  bestLevel: number;
  settings: { sound: boolean; haptics: boolean; calm: boolean; aimLine: boolean };
  stats: { runs: number; merges: number; autoDrops: number };
}

export interface StorageAdapter {
  get(key: string): Promise<string | null>;
  set(key: string, value: string): Promise<void>;
}

const KEY = 'klunk.save.v1';

export const DEFAULT_SAVE: SaveData = {
  highscore: 0,
  bestLevel: 0,
  settings: { sound: true, haptics: true, calm: false, aimLine: true },
  stats: { runs: 0, merges: 0, autoDrops: 0 },
};

const localStorageAdapter: StorageAdapter = {
  async get(key) {
    try {
      return globalThis.localStorage?.getItem(key) ?? null;
    } catch {
      return null;
    }
  },
  async set(key, value) {
    try {
      globalThis.localStorage?.setItem(key, value);
    } catch {
      /* full eller blockerad storage: tappa hellre en skrivning än krascha */
    }
  },
};

let adapter: StorageAdapter = localStorageAdapter;

/** Bytespunkt för Capacitor Preferences i fas 4. */
export function setStorageAdapter(next: StorageAdapter): void {
  adapter = next;
}

/** Cache så att spelet kan läsa synkront i HUD utan att vänta. */
let cache: SaveData = { ...DEFAULT_SAVE, settings: { ...DEFAULT_SAVE.settings }, stats: { ...DEFAULT_SAVE.stats } };

export function cached(): SaveData {
  return cache;
}

export async function load(): Promise<SaveData> {
  const raw = await adapter.get(KEY);
  if (raw) {
    try {
      const parsed = JSON.parse(raw) as Partial<SaveData>;
      cache = {
        ...DEFAULT_SAVE,
        ...parsed,
        settings: { ...DEFAULT_SAVE.settings, ...parsed.settings },
        stats: { ...DEFAULT_SAVE.stats, ...parsed.stats },
      };
    } catch {
      /* korrupt data: behåll default */
    }
  }
  return cache;
}

export async function save(patch: Partial<SaveData>): Promise<void> {
  cache = {
    ...cache,
    ...patch,
    settings: { ...cache.settings, ...patch.settings },
    stats: { ...cache.stats, ...patch.stats },
  };
  await adapter.set(KEY, JSON.stringify(cache));
}

/** Skriver highscore/bestLevel om de är bättre. Returnerar true vid nytt rekord. */
export async function submitRun(score: number, bestLevel: number): Promise<boolean> {
  const record = score > cache.highscore;
  await save({
    highscore: Math.max(cache.highscore, score),
    bestLevel: Math.max(cache.bestLevel, bestLevel),
  });
  return record;
}

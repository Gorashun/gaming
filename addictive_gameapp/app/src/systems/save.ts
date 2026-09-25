/** Persistens. localStorage nu, Capacitor Preferences senare via adaptern. */
import { DEFAULT_SET } from '../data/collection';
import { countArray, emptyPage, normalizeCollection, type Collection } from './collection';

export interface SaveData {
  highscore: number;
  bestLevel: number;
  settings: { sound: boolean; haptics: boolean; calm: boolean; aimLine: boolean };
  stats: {
    runs: number;
    merges: number;
    autoDrops: number;
    /** Skapade (merge/regnbåge) per nivå, alla rundor (DESIGN §13.2). */
    createdPerLevel: number[];
    /** Skapade i rad utan skimrande, per nivå. */
    shinyPity: number[];
  };
  /** Samlarboken, en sida per temaset (DESIGN §13.2). */
  collection: Collection;
  activeSet: string;
}

/** Patch där settings/stats får vara delvisa. */
export type SavePatch = Partial<Omit<SaveData, 'settings' | 'stats'>> & {
  settings?: Partial<SaveData['settings']>;
  stats?: Partial<SaveData['stats']>;
};

export interface StorageAdapter {
  get(key: string): Promise<string | null>;
  set(key: string, value: string): Promise<void>;
}

const KEY = 'klunk.save.v1';

/** Ny default varje gång: arrayer och sidor får aldrig delas mellan instanser. */
export function defaultSave(): SaveData {
  return {
    highscore: 0,
    bestLevel: 0,
    settings: { sound: true, haptics: true, calm: false, aimLine: true },
    stats: {
      runs: 0,
      merges: 0,
      autoDrops: 0,
      createdPerLevel: countArray(null),
      shinyPity: countArray(null),
    },
    collection: { [DEFAULT_SET]: emptyPage() },
    activeSet: DEFAULT_SET,
  };
}

/** Defaults-merge: gamla sparfiler får nya fält utan att tappa något. */
export function mergeWithDefaults(parsed: Partial<SaveData>): SaveData {
  const d = defaultSave();
  const activeSet = typeof parsed.activeSet === 'string' ? parsed.activeSet : d.activeSet;
  return {
    ...d,
    ...parsed,
    settings: { ...d.settings, ...parsed.settings },
    stats: {
      ...d.stats,
      ...parsed.stats,
      createdPerLevel: countArray(parsed.stats?.createdPerLevel),
      shinyPity: countArray(parsed.stats?.shinyPity),
    },
    collection: normalizeCollection(parsed.collection, [DEFAULT_SET, activeSet]),
    activeSet,
  };
}

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
let cache: SaveData = defaultSave();

export function cached(): SaveData {
  return cache;
}

export async function load(): Promise<SaveData> {
  const raw = await adapter.get(KEY);
  if (raw) {
    try {
      cache = mergeWithDefaults(JSON.parse(raw) as Partial<SaveData>);
    } catch {
      /* korrupt data: behåll default */
    }
  }
  return cache;
}

export async function save(patch: SavePatch = {}): Promise<void> {
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

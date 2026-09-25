/** Persistens. localStorage nu, Capacitor Preferences senare via adaptern. */
import { DEFAULT_SET } from '../data/collection';
import { THEME_SET_IDS } from '../data/themes';
import { countArray, emptyPage, normalizeCollection, type Collection } from './collection';
import { defaultAvatars, normalizeAvatars, type AvatarState } from './avatars';
import { defaultDebug, normalizeDebug, type DebugState } from './debug';
import { defaultEconomy, milestoneFlags, normalizeEconomy, reachedMilestones, type EconomyState } from './economy';

export interface SaveData {
  highscore: number;
  bestLevel: number;
  settings: {
    sound: boolean;
    haptics: boolean;
    calm: boolean;
    aimLine: boolean;
    /** Bokens svep-ledtråd har visats (en gång, UI.md §12.4). */
    bookHintSeen: boolean;
    /** Kompisar-flikens scroll-ledtråd: spelaren har scrollat en gång (UI.md §13.4). */
    friendsHintSeen: boolean;
  };
  stats: {
    runs: number;
    merges: number;
    autoDrops: number;
    /** Skapade (merge/regnbåge) per nivå, alla rundor (DESIGN §13.2). */
    createdPerLevel: number[];
    /** Skapade i rad utan skimrande, per nivå. */
    shinyPity: number[];
    /** Två nivå 10 som slagits ihop (skicklighetsspåret, DESIGN §13.3). */
    doubleKlunks: number;
    /** Högsta nivå någonsin i burken. */
    maxLevelEver: number;
  };
  /** Samlarboken, en sida per upplåst temaset (DESIGN §13.2). */
  collection: Collection;
  activeSet: string;
  /** Upplåsta set i upplåsningsordning, grundsetet först. */
  unlockedSets: string[];
  /** Nyupplåst set som inte visats (rundavslut eller bok). */
  freshSet: string | null;
  /** Kompisar och musslor (DESIGN §14.7). */
  avatars: AvatarState;
  /** Avataren som var vald när rekordet sattes, '' om ingen. */
  highscoreAvatar: string;
  /** Pärlor, stjärnsand, gratismusslor och milstolpar (DESIGN §16). */
  economy: EconomyState;
  /** Rundlogg och A/B-växlar för speltest (debugpanelen, PLAYTEST.md §3). */
  debug: DebugState;
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
    settings: { sound: true, haptics: true, calm: false, aimLine: true, bookHintSeen: false, friendsHintSeen: false },
    stats: {
      runs: 0,
      merges: 0,
      autoDrops: 0,
      createdPerLevel: countArray(null),
      shinyPity: countArray(null),
      doubleKlunks: 0,
      maxLevelEver: 0,
    },
    collection: { [DEFAULT_SET]: emptyPage() },
    activeSet: DEFAULT_SET,
    unlockedSets: [DEFAULT_SET],
    freshSet: null,
    avatars: defaultAvatars(),
    highscoreAvatar: '',
    economy: defaultEconomy(),
    debug: defaultDebug(),
  };
}

function nonNegInt(v: unknown): number {
  return typeof v === 'number' && Number.isFinite(v) && v > 0 ? Math.floor(v) : 0;
}

/** Bara kända set, inga dubbletter, grundsetet alltid först. */
function normalizeUnlocked(raw: unknown): string[] {
  const out = [DEFAULT_SET];
  if (Array.isArray(raw)) {
    for (const id of raw) if (typeof id === 'string' && THEME_SET_IDS.includes(id) && !out.includes(id)) out.push(id);
  }
  return out;
}

/** Defaults-merge: gamla sparfiler får nya fält utan att tappa något. */
export function mergeWithDefaults(parsed: Partial<SaveData>): SaveData {
  const d = defaultSave();
  const unlockedSets = normalizeUnlocked(parsed.unlockedSets);
  const activeSet =
    typeof parsed.activeSet === 'string' && unlockedSets.includes(parsed.activeSet) ? parsed.activeSet : d.activeSet;
  const freshSet =
    typeof parsed.freshSet === 'string' && unlockedSets.includes(parsed.freshSet) ? parsed.freshSet : null;
  const stats: SaveData['stats'] = {
    ...d.stats,
    ...parsed.stats,
    createdPerLevel: countArray(parsed.stats?.createdPerLevel),
    shinyPity: countArray(parsed.stats?.shinyPity),
    doubleKlunks: nonNegInt(parsed.stats?.doubleKlunks),
    // Gamla sparfiler: bästa objektet är den högsta nivå som funnits.
    maxLevelEver: Math.max(nonNegInt(parsed.stats?.maxLevelEver), nonNegInt(parsed.bestLevel)),
  };
  const collection = normalizeCollection(parsed.collection, unlockedSets);
  return {
    ...d,
    ...parsed,
    settings: { ...d.settings, ...parsed.settings },
    stats,
    collection,
    activeSet,
    unlockedSets,
    freshSet,
    avatars: normalizeAvatars(parsed.avatars),
    highscoreAvatar: typeof parsed.highscoreAvatar === 'string' ? parsed.highscoreAvatar : '',
    // Före §16: baseline = nuvarande merges, nådda milstolpar räknas som utbetalda (ingen retroaktiv utbetalning).
    economy: normalizeEconomy(parsed.economy, {
      merges: nonNegInt(stats.merges),
      reached: reachedMilestones(milestoneFlags(stats, collection)),
    }),
    debug: normalizeDebug(parsed.debug),
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

/** Debugpanelens "Nollställ sparfil": allt tillbaka till en ny sparfil. */
export async function resetSave(): Promise<void> {
  cache = defaultSave();
  await adapter.set(KEY, JSON.stringify(cache));
}

/** Skriver highscore/bestLevel (och rekordets avatar) om de är bättre. Returnerar true vid nytt rekord. */
export async function submitRun(score: number, bestLevel: number, avatar?: string): Promise<boolean> {
  const record = score > cache.highscore;
  await save({
    highscore: Math.max(cache.highscore, score),
    bestLevel: Math.max(cache.bestLevel, bestLevel),
    ...(record && avatar !== undefined ? { highscoreAvatar: avatar } : {}),
  });
  return record;
}

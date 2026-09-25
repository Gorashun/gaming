/**
 * Fångst och skimrande (DESIGN §13.2). Ren logik, ingen Phaser: seedbar och testbar.
 * Anropas en gång per nivå som SKAPAS (merge eller regnbåge), aldrig för drop från kön.
 */
import type { Rng } from './rng';
import { LEVEL_COUNT, SLOTS_PER_PAGE, type CollectionConfig } from '../data/collection';

/** En boksida: 11 vanliga + 10 skimrande platser (shiny[0] används aldrig). */
export interface CollectionPage {
  caught: boolean[];
  shiny: boolean[];
  /** Nytt sedan sist, per plats (index enligt `slotIndex`). Nollställs när sidan visats. */
  fresh: boolean[];
}

/** Platsindex 0–20: vanliga nivå 0–10 = 0–10, skimrande nivå 1–10 = 11–20. */
export function slotIndex(level: number, shiny: boolean): number {
  return shiny ? LEVEL_COUNT - 1 + level : level;
}

export type Collection = Record<string, CollectionPage>;

export interface CollectionState {
  /** Aktiva setets sida. Muteras. */
  page: CollectionPage;
  /** Muteras. */
  createdPerLevel: number[];
  /** Skapade i rad utan skimrande, per nivå. Muteras. */
  shinyPity: number[];
  /** 1-baserat index för rundan som pågår. */
  run: number;
  /** Har spelaren någonsin fått ett skimrande (i något set)? Muteras. */
  everShiny: boolean;
  /** Multiplikator på chansen (Stjärnvalen). Garantin (pity) är oförändrad. Default 1. */
  shinyMul?: number;
}

export interface CreatedResult {
  /** Nivån fångades nu för första gången på sidan. */
  caught: boolean;
  /** Det skapade objektet är skimrande. */
  shiny: boolean;
  /** Första skimrande av nivån på sidan. */
  newShiny: boolean;
}

/** Garantin: den N:e skapade i rad utan träff är alltid skimrande, N = pityFactor / p. */
export function pityThreshold(level: number, cfg: CollectionConfig): number {
  return Math.round(cfg.pityFactor / cfg.shinyP[level]);
}

export function onLevelCreated(
  level: number,
  state: CollectionState,
  rng: Rng,
  cfg: CollectionConfig,
): CreatedResult {
  state.createdPerLevel[level]++;
  const caught = !state.page.caught[level];
  state.page.caught[level] = true;
  // Nytt sedan sist tills rundavslutet eller boken har visat det (DESIGN §13.4).
  if (caught) state.page.fresh[level] = true;
  // Nivå 0 skapas aldrig genom merge; den blir aldrig skimrande.
  if (level < 1) return { caught, shiny: false, newShiny: false };

  const roll = rng.next() < cfg.shinyP[level] * (state.shinyMul ?? 1);
  const pity = state.shinyPity[level] + 1 >= pityThreshold(level, cfg);
  const first =
    !state.everShiny && state.run >= cfg.firstShinyByRun && level >= cfg.firstShinyMinLevel;
  const shiny = roll || pity || first;
  const newShiny = shiny && !state.page.shiny[level];
  if (shiny) {
    state.shinyPity[level] = 0;
    state.everShiny = true;
    state.page.shiny[level] = true;
    if (newShiny) state.page.fresh[slotIndex(level, true)] = true;
  } else {
    state.shinyPity[level]++;
  }
  return { caught, shiny, newShiny };
}

/** Ny sida: nivå 0 vanlig är ifylld från start (endowed progress). */
export function emptyPage(): CollectionPage {
  const caught = new Array<boolean>(LEVEL_COUNT).fill(false);
  caught[0] = true;
  return {
    caught,
    shiny: new Array<boolean>(LEVEL_COUNT).fill(false),
    fresh: new Array<boolean>(SLOTS_PER_PAGE).fill(false),
  };
}

function boolArray(raw: unknown, n = LEVEL_COUNT): boolean[] {
  const out = new Array<boolean>(n).fill(false);
  if (Array.isArray(raw)) for (let i = 0; i < n; i++) out[i] = raw[i] === true;
  return out;
}

/** Tål gamla/korrupta sparfiler: rätt längd, bara booleans, nivå 0 alltid fångad. */
export function normalizeCollection(raw: unknown, sets: readonly string[]): Collection {
  const src = (raw && typeof raw === 'object' ? raw : {}) as Record<string, Partial<CollectionPage>>;
  const out: Collection = {};
  for (const id of Object.keys(src)) {
    const p = src[id] ?? {};
    const page = {
      caught: boolArray(p.caught),
      shiny: boolArray(p.shiny),
      fresh: boolArray(p.fresh, SLOTS_PER_PAGE),
    };
    page.caught[0] = true;
    page.shiny[0] = false;
    out[id] = page;
  }
  for (const id of sets) if (!out[id]) out[id] = emptyPage();
  return out;
}

/** Tal-array med rätt längd (createdPerLevel, shinyPity). */
export function countArray(raw: unknown): number[] {
  const out = new Array<number>(LEVEL_COUNT).fill(0);
  if (Array.isArray(raw)) {
    for (let i = 0; i < LEVEL_COUNT; i++) {
      const v = raw[i];
      if (typeof v === 'number' && Number.isFinite(v) && v > 0) out[i] = Math.floor(v);
    }
  }
  return out;
}

/** Ifyllda platser på sidan, 1–21. */
export function filledSlots(page: CollectionPage): number {
  let n = 0;
  for (let i = 0; i < LEVEL_COUNT; i++) {
    if (page.caught[i]) n++;
    if (i > 0 && page.shiny[i]) n++;
  }
  return n;
}

export function hasAnyShiny(c: Collection): boolean {
  for (const id of Object.keys(c)) if (c[id].shiny.some(Boolean)) return true;
  return false;
}

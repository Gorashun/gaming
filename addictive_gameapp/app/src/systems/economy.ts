/**
 * Ekonomi (DESIGN §16): pärlor, stjärnsand, gratismusslor, butik och uppgradering.
 * Ren logik, ingen Phaser: seedbar och testbar. Funktionerna tar de delar av sparfilen de behöver
 * (SaveData passar) och muterar dem; anroparen sparar.
 */
import type { Rng } from './rng';
import { AVATARS, RARITY, type AvatarDef, type Rarity } from '../data/avatarsIndex';
import { SLOTS_PER_PAGE } from '../data/collection';
import { ECONOMY, type Price, type ShellType, type ShopMode } from '../data/economy';
import { addOwned, currentOdds, drawShell, shellOdds, type BoxResult } from './boxes';
import { filledSlots, hasAnyShiny, type Collection } from './collection';
import type { AvatarState } from './avatars';

export interface EconomyState {
  pearls: number;
  sand: number;
  /** stats.merges när ekonomin infördes: gratismusslor räknas härifrån (ingen retroaktiv utbetalning). */
  mergesBaseline: number;
  freeShellsClaimed: number;
  /** Utbetalda engångsmilstolpar: 'level7'…'level10', 'shiny', 'doubleKlunk', 'page:<setId>'. */
  milestones: string[];
}

export function defaultEconomy(mergesBaseline = 0): EconomyState {
  return { pearls: 0, sand: 0, mergesBaseline, freeShellsClaimed: 0, milestones: [] };
}

function nonNegInt(v: unknown): number {
  return typeof v === 'number' && Number.isFinite(v) && v > 0 ? Math.floor(v) : 0;
}

/**
 * Tål gamla/korrupta sparfiler. Saknas `economy` (sparfil från före §16) migreras den:
 * baseline = nuvarande merges och redan nådda milstolpar räknas som utbetalda (de gav musslor förut).
 */
export function normalizeEconomy(raw: unknown, migrate: { merges: number; reached: readonly string[] }): EconomyState {
  if (!raw || typeof raw !== 'object') {
    const e = defaultEconomy(nonNegInt(migrate.merges));
    e.milestones = migrate.reached.slice();
    return e;
  }
  const src = raw as Partial<EconomyState>;
  const milestones: string[] = [];
  if (Array.isArray(src.milestones)) {
    for (const m of src.milestones) if (typeof m === 'string' && !milestones.includes(m)) milestones.push(m);
  }
  return {
    pearls: nonNegInt(src.pearls),
    sand: nonNegInt(src.sand),
    mergesBaseline: nonNegInt(src.mergesBaseline),
    freeShellsClaimed: nonNegInt(src.freeShellsClaimed),
    milestones,
  };
}

// ---------------------------------------------------------------- intjäning (§16.1)

/** Livstidsvärden efter rundan: avgör engångsmilstolpar. */
export interface MilestoneFlags {
  maxLevelEver: number;
  doubleKlunks: number;
  anyShiny: boolean;
  /** Set vars boksida är full (21 av 21). */
  fullPages: readonly string[];
}

/** Rundans räknare plus livstidsvärdena efter rundan. */
export interface RunSummary extends MilestoneFlags {
  merges: number;
  /** Skimrande som skapats i rundan. */
  shinies: number;
  /** Kedjor som nått längd ≥3 i rundan. */
  chains3: number;
  /** Nivå 10 som skapats i rundan. */
  level10s: number;
}

export interface Earned {
  pearls: number;
  sand: number;
  /** Milstolpar som betalades ut nu. */
  milestones: string[];
}

/** Livstidsflaggor ur statistik och samlarbok. */
export function milestoneFlags(stats: { maxLevelEver: number; doubleKlunks: number }, collection: Collection): MilestoneFlags {
  return {
    maxLevelEver: stats.maxLevelEver,
    doubleKlunks: stats.doubleKlunks,
    anyShiny: hasAnyShiny(collection),
    fullPages: Object.keys(collection).filter((id) => filledSlots(collection[id]) >= SLOTS_PER_PAGE),
  };
}

/** Alla milstolpar som är nådda enligt flaggorna (utbetalda eller ej). */
export function reachedMilestones(f: MilestoneFlags): string[] {
  const out: string[] = [];
  for (const lvl of ECONOMY.milestoneLevels) if (f.maxLevelEver >= lvl) out.push(`level${lvl}`);
  if (f.anyShiny) out.push('shiny');
  if (f.doubleKlunks >= 1) out.push('doubleKlunk');
  for (const id of f.fullPages) out.push(`page:${id}`);
  return out;
}

/** Sand för rundans räknare, utan milstolpar. */
function runSand(run: RunSummary): number {
  const S = ECONOMY.sand;
  return (
    nonNegInt(run.shinies) * S.shiny +
    Math.min(nonNegInt(run.chains3), S.chain3MaxPerRun) * S.chain3 +
    nonNegInt(run.level10s) * S.level10
  );
}

/**
 * Betalar ut rundan (muterar `state.economy`). Kan anropas flera gånger under samma runda
 * (t.ex. när appen läggs i bakgrunden): `paid` håller vad rundan redan fått, så bara skillnaden
 * betalas. Milstolpar betalas en gång i livet.
 */
export function earnForRun(
  run: RunSummary,
  state: { economy: EconomyState },
  paid: { pearls: number; sand: number } = { pearls: 0, sand: 0 },
): Earned {
  const e = state.economy;
  const pearlsTotal = nonNegInt(run.merges) * ECONOMY.pearlsPerMerge;
  const sandTotal = runSand(run);
  const pearls = Math.max(0, pearlsTotal - paid.pearls);
  let sand = Math.max(0, sandTotal - paid.sand);
  paid.pearls = Math.max(paid.pearls, pearlsTotal);
  paid.sand = Math.max(paid.sand, sandTotal);
  const milestones: string[] = [];
  for (const m of reachedMilestones(run)) {
    if (e.milestones.includes(m)) continue;
    e.milestones.push(m);
    milestones.push(m);
    sand += m.startsWith('page:') ? ECONOMY.sand.fullPage : ECONOMY.sand.milestone;
  }
  e.pearls += pearls;
  e.sand += sand;
  return { pearls, sand, milestones };
}

// ---------------------------------------------------------------- gratismusslor (§16.2)

/** Totalt antal gratismusslor efter `m` merges räknat från baseline: 120, 400, sedan var 750:e. */
export function freeShellsFor(m: number): number {
  const F = ECONOMY.free;
  let n = 0;
  for (const t of F.at) if (m >= t) n++;
  const last = F.at[F.at.length - 1];
  if (m >= last) n += Math.floor((m - last) / F.every);
  return n;
}

export function freeShellsDue(state: { economy: EconomyState; stats: { merges: number } }): number {
  const e = state.economy;
  return Math.max(0, freeShellsFor(state.stats.merges - e.mergesBaseline) - e.freeShellsClaimed);
}

/**
 * Lägger förfallna gratismusslor på hyllan (`avatars.pendingBoxes`). Med full bok (alla figurer
 * ägs eller ligger redan i en mussla på hyllan) ger varje gratismussla stjärnsand i stället.
 */
export function claimFreeShells(
  state: { economy: EconomyState; stats: { merges: number }; avatars: AvatarState },
  total = AVATARS.length,
): { shells: number; sand: number } {
  const due = freeShellsDue(state);
  const av = state.avatars;
  let shells = 0;
  let sand = 0;
  for (let i = 0; i < due; i++) {
    if (av.owned.length + av.pendingBoxes < total) {
      av.pendingBoxes++;
      shells++;
    } else {
      sand += ECONOMY.free.sandWhenComplete;
    }
  }
  state.economy.freeShellsClaimed += due;
  state.economy.sand += sand;
  return { shells, sand };
}

// ---------------------------------------------------------------- butik (§16.2)

function affordable(e: EconomyState, p: Price): boolean {
  return e.pearls >= (p.pearls ?? 0) && e.sand >= (p.sand ?? 0);
}

function pay(e: EconomyState, p: Price): void {
  e.pearls -= p.pearls ?? 0;
  e.sand -= p.sand ?? 0;
}

/** Figurer musslan kan ge: ej ägda, raritet ≥ golvet (första musslan i livet: bara sällsynt). */
function eligible(owned: readonly string[], type: ShellType, avatars: readonly AvatarDef[]): AvatarDef[] {
  if (ECONOMY.firstShellRare && owned.length === 0) return avatars.filter((a) => a.rarity === ECONOMY.firstRarity);
  const floor = RARITY.order.indexOf(ECONOMY.shells[type].floor);
  return avatars.filter((a) => RARITY.order.indexOf(a.rarity) >= floor && !owned.includes(a.id));
}

/** Finns något kvar över typens golv? (Annars visas musslan grå med bock.) */
export function shellAvailable(av: AvatarState, type: ShellType, avatars: readonly AvatarDef[] = AVATARS): boolean {
  return eligible(av.owned, type, avatars).length > 0 && av.owned.length + av.pendingBoxes < avatars.length;
}

export function canBuy(state: { economy: EconomyState; avatars: AvatarState }, type: ShellType): boolean {
  return affordable(state.economy, ECONOMY.shells[type].price) && shellAvailable(state.avatars, type);
}

/** Köper och öppnar en mussla. null = räcker inte eller ospelbar, och då ändras ingenting. */
export function buyShell(
  state: { economy: EconomyState; avatars: AvatarState },
  type: ShellType,
  rng: Rng,
): BoxResult | null {
  if (!canBuy(state, type)) return null;
  const r = drawShell(state.avatars, rng, type);
  if (!r) return null;
  pay(state.economy, ECONOMY.shells[type].price);
  return r;
}

// ---- reservläget pick3: välj 1 av 3 synliga (DESIGN §16, bakom flaggan)

let mode: ShopMode = ECONOMY.shopMode;

export function shopMode(): ShopMode {
  return mode;
}

export function setShopMode(m: ShopMode): void {
  mode = m === 'pick3' ? 'pick3' : 'random';
}

/** Upp till tre unika, ej ägda figurer dragna med typens odds och golv. Ändrar ingenting. */
export function offerPick3(
  state: { avatars: AvatarState },
  type: ShellType,
  rng: Rng,
  avatars: readonly AvatarDef[] = AVATARS,
): AvatarDef[] {
  const pool = eligible(state.avatars.owned, type, avatars);
  const taken = [...state.avatars.owned];
  const out: AvatarDef[] = [];
  while (out.length < 3) {
    const odds = currentOdds(taken, pool, shellOdds(type));
    const roll = rng.next();
    let acc = 0;
    let rarity: Rarity | null = null;
    for (const r of RARITY.order) {
      if (odds[r] <= 0) continue;
      acc += odds[r];
      rarity = r;
      if (roll < acc) break;
    }
    if (!rarity) break;
    const a = rng.pick(pool.filter((x) => x.rarity === rarity && !taken.includes(x.id)));
    taken.push(a.id);
    out.push(a);
  }
  return out;
}

/** Köper den valda figuren. null = räcker inte eller figuren går inte att få ur typen. */
export function buyPick(
  state: { economy: EconomyState; avatars: AvatarState },
  type: ShellType,
  id: string,
): BoxResult | null {
  if (!canBuy(state, type)) return null;
  const a = eligible(state.avatars.owned, type, AVATARS).find((x) => x.id === id);
  if (!a) return null;
  pay(state.economy, ECONOMY.shells[type].price);
  addOwned(state.avatars, a.id);
  return { avatarId: a.id, rarity: a.rarity };
}

// ---------------------------------------------------------------- uppgradering (§16.3)

/** Priset från nivå `fromLevel` (1 eller 2) till nästa. null på nivå III. */
export function upgradeCost(rarity: Rarity, fromLevel: number): { pearls: number; sand: number } | null {
  const [toII, toIII] = ECONOMY.upgrade[rarity];
  if (fromLevel === 1) return { pearls: toII, sand: 0 };
  if (fromLevel === 2) return { pearls: toIII.pearls, sand: toIII.sand };
  return null;
}

function costFor(av: AvatarState, id: string): { pearls: number; sand: number } | null {
  if (!av.owned.includes(id)) return null;
  const def = AVATARS.find((a) => a.id === id);
  return def ? upgradeCost(def.rarity, av.level[id] ?? 1) : null;
}

export function canUpgrade(state: { economy: EconomyState; avatars: AvatarState }, id: string): boolean {
  const c = costFor(state.avatars, id);
  return c !== null && affordable(state.economy, c);
}

/** Drar priset och höjer nivån. false = räcker inte / redan III / ej ägd, och då ändras ingenting. */
export function upgrade(state: { economy: EconomyState; avatars: AvatarState }, id: string): boolean {
  const c = costFor(state.avatars, id);
  if (!c || !affordable(state.economy, c)) return false;
  pay(state.economy, c);
  const lv = state.avatars.level[id] ?? 1;
  state.avatars.level[id] = lv >= 2 ? 3 : 2;
  return true;
}

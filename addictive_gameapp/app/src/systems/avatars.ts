/**
 * Kompisarnas inventarie och nivåer (DESIGN §14.7, §16.3). Ren logik, ingen Phaser.
 * Nivåer köps med pärlor/sand (systems/economy.ts); XP finns inte längre.
 */
import { AVATARS } from '../data/avatarsIndex';

export type AvatarLevel = 1 | 2 | 3;

export interface AvatarState {
  owned: string[];
  level: Record<string, AvatarLevel>;
  /** Vald avatar, '' innan första musslan. */
  equipped: string;
  boxesEarned: number;
  boxesOpened: number;
  pendingBoxes: number;
  /** Nyöppnade kompisar som inte visats i boken (puls tills fliken synts i 2 s). */
  fresh: string[];
}

export function defaultAvatars(): AvatarState {
  return { owned: [], level: {}, equipped: '', boxesEarned: 0, boxesOpened: 0, pendingBoxes: 0, fresh: [] };
}

/** Gamla sparfiler (före DESIGN §16): nivån följde XP, II vid 150 och III vid 450 (§14.4). Bara migrering. */
const LEGACY_XP = { xpII: 150, xpIII: 450 } as const;
function legacyLevel(xp: number): AvatarLevel {
  return xp >= LEGACY_XP.xpIII ? 3 : xp >= LEGACY_XP.xpII ? 2 : 1;
}

/** Väljer en ägd avatar. Gäller från nästa runda. */
export function equip(state: AvatarState, id: string): boolean {
  if (!state.owned.includes(id)) return false;
  state.equipped = id;
  return true;
}

/** Debugpanelen: ger och väljer en kompis (samma väg som testhooken `equipForTest`, nivå I). */
export function giveAvatar(state: AvatarState, id: string): void {
  if (!state.owned.includes(id)) {
    state.owned.push(id);
    state.level[id] = 1;
    state.fresh.push(id);
    state.pendingBoxes = Math.min(state.pendingBoxes, AVATARS.length - state.owned.length);
  }
  state.equipped = id;
}

/** Kompisar-fliken har synts i 2 s: inget är nytt längre. Returnerar true om något ändrades. */
export function markFriendsSeen(state: AvatarState): boolean {
  if (state.fresh.length === 0) return false;
  state.fresh.length = 0;
  return true;
}

function nonNegInt(v: unknown): number {
  return typeof v === 'number' && Number.isFinite(v) && v > 0 ? Math.floor(v) : 0;
}

/**
 * Tål gamla/korrupta sparfiler: bara kända id, inga dubbletter, nivå 1–3. Gamla filer med `xp`
 * behåller sin nivå (den högsta av sparad nivå och nivån XP gav); `xp` tas bort (DESIGN §16.3).
 */
export function normalizeAvatars(raw: unknown): AvatarState {
  const src = (raw && typeof raw === 'object' ? raw : {}) as Partial<AvatarState>;
  const out = defaultAvatars();
  const known = new Set(AVATARS.map((a) => a.id));
  if (Array.isArray(src.owned)) {
    for (const id of src.owned) if (typeof id === 'string' && known.has(id) && !out.owned.includes(id)) out.owned.push(id);
  }
  const legacy = src as { xp?: unknown };
  const xpSrc = (legacy.xp && typeof legacy.xp === 'object' ? legacy.xp : {}) as Record<string, unknown>;
  const lvSrc = (src.level && typeof src.level === 'object' ? src.level : {}) as Record<string, unknown>;
  for (const id of out.owned) {
    const stored = Math.min(3, Math.max(1, nonNegInt(lvSrc[id])));
    out.level[id] = Math.max(stored, legacyLevel(nonNegInt(xpSrc[id]))) as AvatarLevel;
  }
  out.equipped = typeof src.equipped === 'string' && out.owned.includes(src.equipped) ? src.equipped : (out.owned[0] ?? '');
  out.boxesEarned = nonNegInt(src.boxesEarned);
  out.boxesOpened = Math.max(nonNegInt(src.boxesOpened), out.owned.length);
  out.pendingBoxes = Math.min(nonNegInt(src.pendingBoxes), AVATARS.length - out.owned.length);
  if (Array.isArray(src.fresh)) {
    for (const id of src.fresh) if (out.owned.includes(id) && !out.fresh.includes(id)) out.fresh.push(id);
  }
  return out;
}

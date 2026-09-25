/**
 * Kompisarnas inventarie, XP och nivåer (DESIGN §14.4, §14.7). Ren logik, ingen Phaser.
 */
import { AVATARS, UPGRADE } from '../data/avatarsIndex';

export type AvatarLevel = 1 | 2 | 3;

export interface AvatarState {
  owned: string[];
  level: Record<string, AvatarLevel>;
  xp: Record<string, number>;
  /** Vald avatar, '' innan första musslan. */
  equipped: string;
  boxesEarned: number;
  boxesOpened: number;
  pendingBoxes: number;
  /** Nyöppnade kompisar som inte visats i boken (puls tills fliken synts i 2 s). */
  fresh: string[];
}

export function defaultAvatars(): AvatarState {
  return { owned: [], level: {}, xp: {}, equipped: '', boxesEarned: 0, boxesOpened: 0, pendingBoxes: 0, fresh: [] };
}

export function levelFor(xp: number, cfg: { xpII: number; xpIII: number } = UPGRADE): AvatarLevel {
  return xp >= cfg.xpIII ? 3 : xp >= cfg.xpII ? 2 : 1;
}

/** XP = merges medan avataren är vald. Returnerar nivån efteråt (0 om avataren inte ägs). */
export function addXp(state: AvatarState, id: string, merges: number): AvatarLevel | 0 {
  if (!state.owned.includes(id)) return 0;
  const xp = (state.xp[id] ?? 0) + Math.max(0, Math.floor(merges));
  state.xp[id] = xp;
  state.level[id] = levelFor(xp);
  return state.level[id];
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
    state.xp[id] = 0;
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

/** Tål gamla/korrupta sparfiler: bara kända id, inga dubbletter, nivå följer XP. */
export function normalizeAvatars(raw: unknown): AvatarState {
  const src = (raw && typeof raw === 'object' ? raw : {}) as Partial<AvatarState>;
  const out = defaultAvatars();
  const known = new Set(AVATARS.map((a) => a.id));
  if (Array.isArray(src.owned)) {
    for (const id of src.owned) if (typeof id === 'string' && known.has(id) && !out.owned.includes(id)) out.owned.push(id);
  }
  const xpSrc = (src.xp && typeof src.xp === 'object' ? src.xp : {}) as Record<string, unknown>;
  for (const id of out.owned) {
    out.xp[id] = nonNegInt(xpSrc[id]);
    out.level[id] = levelFor(out.xp[id]);
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

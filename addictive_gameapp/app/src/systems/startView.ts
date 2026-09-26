/**
 * Startskärmens tillstånd (UI.md §16.6) ur sparfilen. Ren logik, ingen Phaser: testbar.
 */
import { AVATARS } from '../data/avatars';
import { SLOTS_PER_PAGE } from '../data/collection';
import { filledSlots, type Collection } from './collection';
import { nextSetCount, nextSetProgress } from './unlocks';

export interface StartSource {
  activeSet: string;
  freshSet: string | null;
  unlockedSets: readonly string[];
  collection: Collection;
  stats: { runs: number; merges: number };
  avatars: { owned: readonly string[]; fresh: readonly string[]; pendingBoxes: number };
}

export interface StartView {
  /** Bok: fångade platser i aktivt set av 21. Badge: nytt set eller någon ny plats. */
  book: { n: number; m: number; badge: boolean };
  /** Kompisar: ägda av alla. Badge: nyöppnade som inte visats. */
  buddies: { n: number; m: number; badge: boolean };
  /** Butik: badge BARA när en gratismussla väntar (DESIGN §18), aldrig för "har råd". */
  shop: { pending: number; badge: boolean };
  /** Set-stapeln, null när alla set är upplåsta. */
  setBar: { n: number; m: number; v: number } | null;
  /** Inga rundor spelade: handen visar SPELA. */
  newPlayer: boolean;
}

export function startView(d: StartSource, totalAvatars = AVATARS.length): StartView {
  const page = d.collection[d.activeSet];
  const bookFresh = d.freshSet !== null || Object.values(d.collection).some((p) => p.fresh.some(Boolean));
  const pending = Math.max(0, d.avatars.pendingBoxes);
  const count = nextSetCount(d.stats.merges, d.unlockedSets.length);
  return {
    book: { n: page ? filledSlots(page) : 0, m: SLOTS_PER_PAGE, badge: bookFresh },
    buddies: { n: d.avatars.owned.length, m: totalAvatars, badge: d.avatars.fresh.length > 0 },
    shop: { pending, badge: pending > 0 },
    setBar: count ? { ...count, v: nextSetProgress(d.stats.merges, d.unlockedSets.length) ?? 0 } : null,
    newPlayer: d.stats.runs === 0,
  };
}

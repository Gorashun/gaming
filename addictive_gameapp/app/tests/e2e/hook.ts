/** Testhooken som Game-scenen installerar på `window.__game` (bara med ?test=1 eller i dev). */
export interface GameHook {
  readonly bodyCount: number;
  readonly score: number;
  readonly over: boolean;
  readonly combo: number;
  /** Regissörens läge: 'drought' | 'flow' | 'kick'. */
  readonly mode: string;
  readonly dropsSinceKick: number;
  /** Vad som ligger i förhandsvisningen: 'level' | 'bomb' | 'rainbow'. */
  readonly nextKind: string;
  readonly specialsActivated: number;
  readonly nearMissCount: number;
  drop(x: number): void;
  /** Tömmer burken. */
  clear(): void;
  /** Placerar ett objekt direkt (near-miss- och jackpot-scenarier). */
  spawn(level: number, x: number, y: number): void;
  forceLoss(): void;
  /** Fast seed + omstart av rundan. */
  seed(n: number): void;
  /** Antal auto-drops i rundan (DESIGN §11). */
  readonly autoDrops: number;
  /** ms från släppbar till drop, senaste 500. */
  readonly dropLatencies: number[];
  /** 'idle' | 'nudge' | 'autodrop'. */
  readonly pacingPhase: string;
  /** Slår av/på mjuk auto-drop: 'off' | 'flow'. */
  setPacing(mode: string): void;
  /** Auto-drop-tiden för objektet som hänger nu, efter rampen (DESIGN §12). */
  readonly autoDropAtMs: number;
  /** Siktlinjens läge: 'always' | 'aiming' | 'off'. */
  readonly aimLineMode: string;
  /** Siktlinjen är synlig (alpha > 0,05). */
  readonly aimLineVisible: boolean;
  setAimLine(mode: string): void;
  /** Kopia av samlarboken: { [setId]: { caught: boolean[11], shiny: boolean[11] } }. */
  readonly collection: Record<string, { caught: boolean[]; shiny: boolean[] }>;
  /** Kedjan i HUD: nivåer som tänts i rundan (DESIGN §13.1). */
  readonly chainLit: boolean[];
  /** Antal skimrande objekt i burken vars glitterring syns. */
  readonly glitterVisible: number;
  /** Nästa skapade objekt av nivån blir skimrande. */
  forceShiny(level: number): void;
}

/** Testhooken som Book-scenen installerar på `window.__book`. */
export interface BookHook {
  readonly page: number;
  readonly pages: number;
  /** Ifyllda platser (x av 22) på sidan som visas. */
  readonly filled: number;
}

declare global {
  interface Window {
    __game?: GameHook;
    __book?: BookHook;
  }
}

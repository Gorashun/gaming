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
}

declare global {
  interface Window {
    __game?: GameHook;
  }
}

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
  /** Kopia av samlarboken: { [setId]: { caught: boolean[11], shiny: boolean[11], fresh: boolean[21] } }. */
  readonly collection: Record<string, { caught: boolean[]; shiny: boolean[]; fresh: boolean[] }>;
  /** Kedjan i HUD: nivåer som tänts i rundan (DESIGN §13.1). */
  readonly chainLit: boolean[];
  /** Antal skimrande objekt i burken vars glitterring syns. */
  readonly glitterVisible: number;
  /** Nästa skapade objekt av nivån blir skimrande. */
  forceShiny(level: number): void;
  /** Temaset (DESIGN §13.3). */
  readonly activeSet: string;
  readonly unlockedSets: string[];
  readonly freshSet: string | null;
  /** Lägger till merges på tidsspåret (räknas vid rundavslutet). */
  grantMerges(n: number): void;
  /** Väljer aktivt set (bara upplåsta), gäller från nästa runda. */
  setActiveSet(id: string): boolean;
  /** Texturnyckel för objektet som hänger nu, t.ex. 'ball-planeterna-2'. */
  readonly textureKey: string;
  /** Antal spelade merge-klanger (ljudvägen per set). */
  readonly timbrePlays: number;
  /** Kompisar (DESIGN §14.7), kopia av sparat läge. */
  readonly avatars: {
    owned: string[];
    level: Record<string, number>;
    xp: Record<string, number>;
    equipped: string;
    boxesEarned: number;
    boxesOpened: number;
    pendingBoxes: number;
  };
  readonly pendingBoxes: number;
  /** Öppnar en mussla direkt och sparar. null när alla ägs. */
  openBox(): { avatarId: string; rarity: string } | null;
}

/** Testhooken som Book-scenen installerar på `window.__book`. */
export interface BookHook {
  readonly page: number;
  readonly pages: number;
  /** Ifyllda platser (x av 21) på sidan som visas. */
  readonly filled: number;
  /** Låst per sida, i THEME_SETS-ordning. */
  readonly locked: boolean[];
  /** Bläddrar till sidan och trycker på den (väljer aktivt set om upplåst). */
  selectPage(i: number): void;
  /** 'sets' | 'friends'. */
  readonly tab: string;
  selectTab(t: string): void;
  /** Väljer en ägd avatar (samma väg som ett tryck). */
  equip(id: string): boolean;
  /** Mitten av avatarens cell i logiska koordinater (med aktuell scroll), null om okänd. */
  cellOf(id: string): { x: number; y: number } | null;
}

/** Rundavslutet (GameOver-overlayen) på `window.__reveal`. */
export interface RevealHook {
  /** Fångster som hunnit landa i boken. */
  readonly landed: number;
  /** Speltid (ms) sedan overlayen skapades. */
  readonly elapsed: number;
}

/** Startskärmen på `window.__start`. */
export interface StartHook {
  /** Senast öppnade musslan. */
  readonly lastBox: { avatarId: string; rarity: string } | null;
  /** Öppningen visas (ett tryck stänger). */
  readonly opening: boolean;
}

declare global {
  interface Window {
    __start?: StartHook;
    __game?: GameHook;
    __book?: BookHook;
    __reveal?: RevealHook;
  }
}

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
    equipped: string;
    boxesEarned: number;
    boxesOpened: number;
    pendingBoxes: number;
    fresh: string[];
  };
  readonly pendingBoxes: number;
  /** Öppnar en mussla direkt och sparar. null när alla ägs. */
  openBox(): { avatarId: string; rarity: string } | null;
  /** Ekonomin (DESIGN §16), kopia av sparat läge. */
  readonly economy: {
    pearls: number;
    sand: number;
    mergesBaseline: number;
    freeShellsClaimed: number;
    milestones: string[];
    pick3Offer: Record<string, string[]>;
  };
  grantPearls(n: number): void;
  grantSand(n: number): void;
  /** Köper och öppnar en mussla ('common' | 'silver' | 'gold'). null = räcker inte eller ospelbar. */
  buyShell(type: string): { avatarId: string; rarity: string } | null;
  /** Uppgraderar en ägd kompis ett steg. false = räcker inte / redan III. */
  upgrade(id: string): boolean;
  /** 'random' | 'pick3' (reservflaggan). */
  readonly shopMode: string;
  setShopMode(m: string): void;
  /** pick3: tre erbjudna id (ändrar ingenting). */
  offerPick3(type: string): string[];
  buyPick(type: string, id: string): { avatarId: string; rarity: string } | null;
  /** Äger och väljer kompisen på nivån (1–3, default 1) och startar om rundan. */
  equipForTest(id: string, level?: number): void;
  /** Förmågans tillstånd i rundan (DESIGN §14.5). */
  readonly abilityState: AbilityState;
  /** Släpparen (null = ingen kompis vald). */
  readonly buddy: { id: string; x: number; y: number; visible: boolean } | null;
  /** Nivån på det hängande objektet (-1 = specialobjekt). */
  readonly hangingLevel: number;
  /** Fps-vakten (DESIGN §17). null = inaktiv (Z = 1 eller tak redan satt). */
  readonly perf: { windows: number[]; low: number; tripped: boolean; z: number; zoomCap: number | null } | null;
  /** Matar vakten med `ms` ms frames i `fps`. */
  perfSimulate(fps: number, ms: number): void;
  /** Det hängande objektets x i logiska px (-1 utan objekt). */
  readonly hangingX: number;
  /** Nivåset i full upplösning i TextureManager, t.ex. ['glimtarna']. */
  readonly ballSets: string[];
  /** Antal objekt med synlig lyktring (Lykt-Lisa). */
  readonly lampsVisible: number;
  /** Lisas oljemätare vid Släpparen syns. */
  readonly lanternMeterVisible: boolean;
  /** Utbrott i rundan: guldstjärnor (skimrande skapas) och "?"-tändningar i kedjan. */
  readonly fxCounts: { stars: number; chainFirst: number };
  /** Ett objekt med statisk kropp (sitter fast), för farogräns-scenarier. */
  pin(level: number, x: number, y: number): void;
}

export interface AbilityState {
  id: string;
  key: string;
  level: number;
  lisa: { active: boolean; oilMs: number };
  maja: { usesLeft: number; pulling: boolean };
  vala: { usesLeft: number; breathing: boolean; graceMs: number };
  bubbel: { left: number };
  siri: { afterKind: string | null };
  nearMissMinLevel: number;
  /** Skimrande-chansens multiplikator i samlarboken (Stjärnvalen). */
  shinyMul: number;
  chainShakeMul: number;
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
  /** Scrollar cellen till mitten av rutnätet; returnerar dess mitt i logiska koordinater, null om okänd. */
  cellOf(id: string): { x: number; y: number } | null;
  /** Nivåset i full upplösning i TextureManager. */
  readonly ballSets: string[];
  /** Kompisen på bokens scen ('' = ingen). */
  readonly stageId: string;
  /** Nyöppnade kompisar som pulsar just nu. */
  readonly pulsingFriends: number;
  /** Svep-ledtråden visades i den här öppningen av boken. */
  readonly hintShown: boolean;
  /** Svep-ledtrådens hand syns just nu. */
  readonly hintActive: boolean;
  /** Scroll-ledtrådens pil i Kompisar syns. */
  readonly scrollHint: boolean;
  /** Butiken i Kompisar (UI.md §14.3). */
  readonly shop: ShopSnapshot;
  /** Köper musslan (samma väg som andra trycket). pick3: öppnar erbjudandet och returnerar null. */
  buy(type: string): { avatarId: string; rarity: string } | null;
  /** pick3: väljer kort i och trycker på köpknappen. */
  pick(i: number): { avatarId: string; rarity: string } | null;
  /** Uppgraderar vald kompis (samma väg som andra trycket). */
  upgradeSelected(): boolean;
  /** Scenen: vald kompis, null utan kompis. */
  readonly stage: {
    id: string;
    level: number;
    rombs: number;
    name: string;
    desc: string;
    hints: string[];
    button: 'ok' | 'awake' | 'poor' | 'max';
    cost: { pearls: number; sand: number } | null;
  } | null;
}

export interface ShopSnapshot {
  mode: string;
  pearls: number;
  sand: number;
  full: boolean;
  slots: { type: string; price: { pearls?: number; sand?: number }; state: 'ok' | 'poor' | 'empty' }[];
  awake: string | null;
  offer: string[] | null;
  picked: string | null;
  opening: boolean;
  openPhase: string | null;
  lastBuy: { avatarId: string; rarity: string } | null;
}

/** Rundavslutet (GameOver-overlayen) på `window.__reveal`. */
export interface RevealHook {
  /** Fångster som hunnit landa i boken. */
  readonly landed: number;
  /** Speltid (ms) sedan overlayen skapades. */
  readonly elapsed: number;
  /** Resursräkningen (UI.md §14.6): visade värden, antal rader och om den är klar. */
  readonly tally: { pearls: number; sand: number; done: boolean; rows: number };
}

/** Startskärmen på `window.__start`. */
export interface StartHook {
  /** Senast öppnade musslan. */
  readonly lastBox: { avatarId: string; rarity: string } | null;
  /** Öppningen visas (ett tryck stänger). */
  readonly opening: boolean;
  /** 'play' före 1 200 ms (tryck hoppar över), 'done' efter (tryck stänger). */
  readonly openPhase: string;
  /** Debugpanelen är öppen (långtryck 2 s på logotypen). */
  readonly debugOpen: boolean;
  /** JSON från panelens "Kopiera JSON", null innan knappen tryckts. */
  readonly debugExport: string | null;
}

declare global {
  interface Window {
    __start?: StartHook;
    __game?: GameHook;
    __book?: BookHook;
    __reveal?: RevealHook;
  }
}

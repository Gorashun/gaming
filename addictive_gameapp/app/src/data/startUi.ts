/**
 * startUi.ts – "Start v2" (UI.md §16). Ägare: ui-designer.
 *
 * Ren data och SVG-strängar. Får INTE importera Phaser. Logisk yta 360×640 (FIT, samma som övriga scener).
 * Förlaga: projektledarens designduk, förslag A (ritad i CSS-px på 390 bredd). Alla mått är omräknade
 * till logiska px med 360/390 ≈ 0,923 och avrundade till jämna tal. Text är aldrig under 14 logiska px.
 *
 * Knappkomponenten (`BUTTON_STYLE`) är gemensam för startskärmen, boken och förlustskärmen.
 * Referensrenderare för knappytan: `ui/buttonArt.ts` (Canvas2D, bakas en gång per storlek och läge).
 *
 * Flash-guard: tre loopar, SPELA-pulsen 0,56 Hz, den tittande musslans studs 0,5 Hz och "nytt"-andningen
 * 0,5 Hz. Ingen ljusstyrkeväxling över 1 Hz, inga vitblixtar. Lägg alla tre i JUICE.pulseHalfCycleMs.
 *
 * Kontrast (WCAG, uträknat mot respektive yta):
 *   etikett hud mot kort 14,0:1 · underrad hudDim mot kort 6,2:1 · SPELA-text #0B1020 mot ytan 9,5–16,5:1
 *   Bok-ikon accent 12,7:1 · Kompisar-ikon gold 11,4:1 · Butik-ikon rosa 8,5:1 (badge-kort 7,9:1)
 *   kortkant #4A6194 mot bg 3,1:1 (WCAG 1.4.11) · "Gratis!" gold mot badge-kort 10,6:1 · arkets text 15,2:1
 */

import type { AvatarTone } from './avatars';
import type { LocalizedName } from '../systems/i18n';

// ---------------------------------------------------------------- färger

const ACCENT = '#7CF9FF';
const HUD = '#EAF2FF';
const HUD_DIM = '#8FA3C8';
const INK = '#14202E';
const BG = '#0B1020';
const BG_DEEP = '#060A14';
const GOLD = '#FFD75E';
const PINK = '#FF9CF0';
const JAR_EDGE = '#6E8CC4';
const JAR_WALL = '#2B3B5E';
const JAR_GLASS = '#16223C';
const SILHOUETTE = '#56688F';

export const START_COLORS = {
  accent: ACCENT,
  hud: HUD,
  hudDim: HUD_DIM,
  gold: GOLD,
  /** Butikens egen färg (ikon). Rosa som musslan, aldrig röd. */
  shop: PINK,
  /** Resurspillren: glas, inte tryckbara. */
  pillFill: JAR_GLASS,
  pillEdge: JAR_WALL,
  /** Rekordchippet. */
  recordFill: 'rgba(255,215,94,0.10)',
  recordEdge: 'rgba(255,215,94,0.45)',
  /** Scenen under hjälten: vertikal gradient + glaskant. */
  stageTop: JAR_WALL,
  stageBottom: JAR_GLASS,
  stageEdge: JAR_EDGE,
  /** Scrim bakom inställningsarket. */
  scrim: BG,
  sheet: '#121B33',
  sheetEdge: JAR_WALL,
  sheetHandle: HUD_DIM,
  /** Ikonrutan i arkets rader. */
  sheetIconBox: JAR_GLASS,
  sheetIconBoxEdge: JAR_WALL,
  /** Strömbrytare. PÅ: cyan spår, mörk knopp med bock. AV: mörkt spår, hudDim-kant, hudDim-knopp. */
  switchOnTrack: ACCENT,
  switchOnKnob: BG,
  switchOffTrack: '#1A2744',
  switchOffEdge: HUD_DIM,
  switchOffKnob: HUD_DIM,
  /** Badge: guldprick med mörk ring. Aldrig röd. */
  badge: GOLD,
  badgeRing: BG,
  /** Set-stapeln: spår + cyan gradient. */
  barTrack: JAR_WALL,
  barFill: ['#B6FCFF', ACCENT, '#36C9D6'] as readonly string[],
  /** Logotypens hårda textskugga (0, 4). */
  logoShadow: BG_DEEP,
} as const;

// ---------------------------------------------------------------- typsnitt

/**
 * Fredoka (SIL OFL 1.1), variabel vikt 300–700, latin-subset (inkl. å ä ö), 29 kB.
 * Buntad: `app/public/fonts/Fredoka-latin.woff2` + licensen `Fredoka-OFL.txt`. Inga nätanrop.
 *
 * Laddning (Boot, före första Text): `new FontFace(family, 'url(fonts/Fredoka-latin.woff2)', { weight: '300 700' })`,
 * `document.fonts.add(f)`, `await Promise.race([f.load(), timeout(loadTimeoutMs)])`. Phaser-Text rastreras när
 * den skapas, så fonten MÅSTE vara laddad innan Start ritas. Misslyckas den: systemfonten (fallback) används.
 * Siffror: Fredoka har proportionella siffror – räknare som ändras (pillren) ritas med fast bredd per siffra
 * (`tabularAdvance` × px), se UI.md §2.2.
 */
export const START_FONT = {
  family: "Fredoka, system-ui, -apple-system, 'Segoe UI', Roboto, Arial, sans-serif",
  face: 'Fredoka',
  file: 'fonts/Fredoka-latin.woff2',
  weightRange: '300 700',
  loadTimeoutMs: 1500,
  /** Fast siffersteg för räknare, andel av px (uppmätt: bredaste siffran i Fredoka 600 ≈ 0,60 em). */
  tabularAdvance: 0.6,
} as const;

// ---------------------------------------------------------------- knappkomponent

export type ButtonVariant = 'primary' | 'card' | 'round';
export type ButtonState = 'normal' | 'pressed' | 'disabled' | 'badge';

/** En knapps utseende i ett läge. Logiska px. Ytan bakas av ui/buttonArt.ts; ikon och text läggs ovanpå i scenen. */
export interface ButtonLook {
  /** Vertikal gradient: topp → mitt (vid `midStop`) → botten. Art v2: ljus uppe, mättad nere. */
  readonly face: readonly [top: string, mid: string, bottom: string];
  readonly midStop: number;
  readonly edge: string;
  readonly edgeW: number;
  /** Streckad kant (disabled): formen bär "går inte", inte färgen. */
  readonly edgeDash?: readonly [on: number, off: number];
  /**
   * Inre läpp (CSS `inset 0 -dy 0 rgba(0,0,0,alpha)`): mörkt band längs nederkanten innanför kanten.
   * Det är den som gör att knappen ser tjock och tryckbar ut. Trycket krymper bandet.
   */
  readonly inset: { readonly dy: number; readonly alpha: number };
  /**
   * Blank reflex: vit, avtar nedåt över andelen `h` av höjden. `inset` = sidmarginal i px (0 = hela bredden,
   * mjukt över hela ytan; > 0 = en egen blank "kapsel" som på SPELA). alpha 0 = ingen.
   */
  readonly gloss: { readonly alpha: number; readonly h: number; readonly inset: number };
  /** Yttre ring (glöd-ring), ritas utanför kanten. w 0 = ingen. */
  readonly ring: { readonly w: number; readonly color: string; readonly alpha: number };
  /** Mjuk skugga under hela knappen (bakas, aldrig per frame). */
  readonly shadow: { readonly alpha: number; readonly blur: number; readonly dy: number };
  /** Text- och ikonfärg (kort: ikonen har egen färg, se START_UI.cards). */
  readonly ink: string;
}

export interface ButtonStyle {
  /** Hörnradie. 'pill' = h/2. */
  readonly radius: number | 'pill';
  readonly looks: Readonly<Record<ButtonState, ButtonLook>>;
  /**
   * Tryck (pointerdown inne i träffytan): hela knappen skalas till `scale` och byter till `pressed`
   * (80 ms Quad.easeOut = THEME.anim.buttonPress). Släpp: tillbaka på 160 ms Back.easeOut (buttonRelease).
   * Handlingen körs på pointerup inne i träffytan. Glider fingret ut släpps knappen tyst.
   * Trycket får aldrig flytta ikonen/texten relativt ytan (de skalas med containern).
   */
  readonly press: { readonly scale: number; readonly inMs: number; readonly inEase: string; readonly outMs: number; readonly outEase: string };
  readonly label: { readonly px: number; readonly weight: '500' | '600' | '700'; readonly letterSpacing: number; readonly upper: boolean };
  /** Badge: guldprick uppe till höger (centrum dx från högerkant, dy från överkant). Poppar in, pulsar inte. */
  readonly badge: { readonly d: number; readonly ring: number; readonly dx: number; readonly dy: number; readonly popMs: number; readonly popEase: string };
  /** Ljud (BUTTON_SOUND) och haptik. press = pointerdown, confirm = giltigt släpp, denied = disabled tryckt. */
  readonly sound: { readonly press: keyof typeof BUTTON_SOUND; readonly confirm: keyof typeof BUTTON_SOUND; readonly denied: keyof typeof BUTTON_SOUND };
  readonly hapticMs: { readonly confirm: number; readonly denied: number };
}

const PRESS = { scale: 0.94, inMs: 80, inEase: 'Quad.easeOut', outMs: 160, outEase: 'Back.easeOut' } as const;
const NO_RING = { w: 0, color: ACCENT, alpha: 0 } as const;

/**
 * Kort (sekundär): mörkt havsglas. Designdukens kant #2B3B5E har bara 1,7:1 mot bakgrunden, så kanten
 * är ljusad till #4A6194 (3,1:1, WCAG 1.4.11). Det är den enda avvikelsen från duken.
 */
const CARD_NORMAL: ButtonLook = {
  face: ['#1B2A48', JAR_GLASS, '#131E36'],
  midStop: 0.5,
  edge: '#4A6194',
  edgeW: 2,
  inset: { dy: 5, alpha: 0.28 },
  gloss: { alpha: 0.07, h: 0.5, inset: 0 },
  ring: NO_RING,
  shadow: { alpha: 0.4, blur: 10, dy: 4 },
  ink: HUD,
};

export const BUTTON_STYLE: Readonly<Record<ButtonVariant, ButtonStyle>> = {
  /**
   * Primär (SPELA, förlustskärmens "igen"): blank cyan kapsel med mörk text och en svag glöd-ring.
   * Den enda fyllda accentytan på skärmen, så ögat och tummen hittar den först.
   */
  primary: {
    radius: 'pill',
    looks: {
      normal: {
        face: ['#B6FCFF', ACCENT, '#36C9D6'],
        midStop: 0.5,
        edge: '#EAFEFF',
        edgeW: 3,
        inset: { dy: 6, alpha: 0.2 },
        gloss: { alpha: 0.35, h: 0.45, inset: 14 },
        ring: { w: 7, color: ACCENT, alpha: 0.14 },
        shadow: { alpha: 0.5, blur: 16, dy: 6 },
        ink: BG,
      },
      pressed: {
        face: ['#94E6EA', '#5FDDE6', '#2AA9B6'],
        midStop: 0.5,
        edge: '#C9F4F6',
        edgeW: 3,
        inset: { dy: 3, alpha: 0.26 },
        gloss: { alpha: 0.18, h: 0.45, inset: 14 },
        ring: { w: 7, color: ACCENT, alpha: 0.22 },
        shadow: { alpha: 0.5, blur: 8, dy: 2 },
        ink: BG,
      },
      disabled: { ...CARD_NORMAL, face: ['#1A2744', '#1A2744', '#1A2744'], edge: HUD_DIM, edgeDash: [8, 6], gloss: { alpha: 0, h: 0.5, inset: 0 }, ink: HUD_DIM },
      /** Primären får aldrig badge. Samma som normal. */
      badge: {
        face: ['#B6FCFF', ACCENT, '#36C9D6'],
        midStop: 0.5,
        edge: '#EAFEFF',
        edgeW: 3,
        inset: { dy: 6, alpha: 0.2 },
        gloss: { alpha: 0.35, h: 0.45, inset: 14 },
        ring: { w: 7, color: ACCENT, alpha: 0.14 },
        shadow: { alpha: 0.5, blur: 16, dy: 6 },
        ink: BG,
      },
    },
    press: PRESS,
    label: { px: 32, weight: '700', letterSpacing: 3, upper: true },
    badge: { d: 24, ring: 3, dx: 22, dy: 10, popMs: 200, popEase: 'Back.easeOut' },
    sound: { press: 'press', confirm: 'play', denied: 'denied' },
    hapticMs: { confirm: 20, denied: 10 },
  },
  /** Kort (kortknapparna på Start, bokens och förlustskärmens övriga knappar). */
  card: {
    radius: 22,
    looks: {
      normal: CARD_NORMAL,
      pressed: { ...CARD_NORMAL, face: ['#15223C', '#111C33', '#0E172B'], edge: ACCENT, inset: { dy: 2, alpha: 0.28 }, gloss: { alpha: 0.03, h: 0.5, inset: 0 }, shadow: { alpha: 0.4, blur: 6, dy: 2 } },
      disabled: { ...CARD_NORMAL, face: ['#141E34', '#141E34', '#141E34'], edge: HUD_DIM, edgeDash: [6, 5], inset: { dy: 0, alpha: 0 }, gloss: { alpha: 0, h: 0.5, inset: 0 }, shadow: { alpha: 0, blur: 0, dy: 0 }, ink: HUD_DIM },
      /** Något väntar: varmare yta och guldkant (plus guldprick). Formen (pricken) bär informationen. */
      badge: { ...CARD_NORMAL, face: ['#322B4C', '#2A2440', '#221D36'], edge: GOLD },
    },
    press: PRESS,
    label: { px: 17, weight: '600', letterSpacing: 0.3, upper: false },
    badge: { d: 24, ring: 3, dx: 12, dy: 12, popMs: 200, popEase: 'Back.easeOut' },
    sound: { press: 'press', confirm: 'confirm', denied: 'denied' },
    hapticMs: { confirm: 10, denied: 10 },
  },
  /** Rund ikonknapp (kugghjulet, stäng i arket). Samma glas, mindre vikt. */
  round: {
    radius: 'pill',
    looks: {
      normal: { ...CARD_NORMAL, inset: { dy: 4, alpha: 0.28 } },
      pressed: { ...CARD_NORMAL, face: ['#15223C', '#111C33', '#0E172B'], edge: ACCENT, inset: { dy: 2, alpha: 0.28 } },
      disabled: { ...CARD_NORMAL, edge: HUD_DIM, edgeDash: [5, 4], ink: HUD_DIM },
      badge: { ...CARD_NORMAL, edge: GOLD },
    },
    press: PRESS,
    label: { px: 14, weight: '600', letterSpacing: 0, upper: false },
    badge: { d: 14, ring: 2, dx: 6, dy: 6, popMs: 200, popEase: 'Back.easeOut' },
    sound: { press: 'press', confirm: 'confirm', denied: 'denied' },
    hapticMs: { confirm: 10, denied: 10 },
  },
};

/**
 * Knappljud (ToneDef → playTone). Ett kort, dovt "tock" redan vid pointerdown, så att knappen svarar
 * direkt fast handlingen sker vid släpp. SPELA har en egen stigande "klunk".
 */
export const BUTTON_SOUND = {
  /** Fingret ned: litet trä-tock, nästan omärkligt. */
  press: { wave: 'sine', baseHz: 520, glideTo: 440, attack: 0.001, decay: 0.035, gain: 0.08 },
  /** Giltigt släpp (kort, rund): samma som THEME.sound.ui. */
  confirm: { wave: 'sine', baseHz: 880, glideTo: 1200, attack: 0.001, decay: 0.05, gain: 0.2 },
  /** SPELA: "klunk" uppåt, kvint, som ett lock som öppnas. */
  play: { wave: 'triangle', baseHz: 392, attack: 0.002, decay: 0.12, gain: 0.22, steps: [0, 7], stepMs: 60, harmonicSemitones: 12, harmonicGain: 0.25 },
  /** Disabled tryckt: samma mjuka "hm-m" som ECONOMY_SOUND.notEnough. */
  denied: { wave: 'sine', baseHz: 392, attack: 0.006, decay: 0.12, gain: 0.1, steps: [0, -3], stepMs: 90, lowpassHz: 1400 },
  /** Inställningsarket upp/ned. */
  sheetOpen: { wave: 'sine', baseHz: 620, glideTo: 900, attack: 0.001, decay: 0.07, gain: 0.12 },
  sheetClose: { wave: 'sine', baseHz: 900, glideTo: 620, attack: 0.001, decay: 0.07, gain: 0.12 },
  /** Strömbrytare: på = uppåt, av = nedåt. */
  switchOn: { wave: 'sine', baseHz: 740, glideTo: 988, attack: 0.001, decay: 0.05, gain: 0.14 },
  switchOff: { wave: 'sine', baseHz: 740, glideTo: 554, attack: 0.001, decay: 0.05, gain: 0.12 },
  /** Musslan på Butik-kortet landar efter sitt hopp: pyttelitet "plopp" (bara första hoppet efter att skärmen visats). */
  shellPeek: { wave: 'sine', baseHz: 988, glideTo: 1318.5, attack: 0.002, decay: 0.06, gain: 0.08 },
} as const satisfies Record<string, AvatarTone>;

// ---------------------------------------------------------------- layout (UI.md §16)

export type StartCard = 'book' | 'buddies' | 'shop';
export type SettingKey = 'sound' | 'haptics' | 'calm' | 'aimLine';

export const START_UI = {
  /** Toppbar: två resurspiller vänster (inte tryckbara), kugghjul höger. Centrum y 36. */
  topbar: {
    y: 36,
    pill: {
      h: 40,
      r: 20,
      edgeW: 2,
      padL: 8,
      padR: 14,
      gap: 6,
      textPx: 20,
      textWeight: '600' as const,
      /** Minsta bredd, så att "0" inte ger ett litet piller. Växer med siffran. */
      minW: 80,
    },
    /** Pärlan är lite större än sanden (designduken: 30 / 26 CSS-px). */
    pearls: { x: 16, iconPx: 28 },
    sand: { gapAfterPearls: 8, minX: 104, iconPx: 24 },
    /** Kugghjul: rund knapp 48, ikon 28, träffyta 64×64 (x 288–352, y 4–68). */
    gear: { x: 320, y: 36, d: 48, iconPx: 28, hit: 64 },
  },

  /** Logotyp: samma burk-U som förut. Fredoka 700, hård textskugga (0, 4) i bgDeep. */
  logo: { baseline: 116, px: 60, weight: '700' as const, letterSpacing: 6, shadow: { dx: 0, dy: 4, color: BG_DEEP }, jarStroke: 8 },

  /**
   * Hjälte: vald kompis sitter på sitt bästa objekt (samma grepp som i spel) på en elliptisk scen,
   * med en mjuk cyan halo bakom. Utan kompis: bara bästa objektet (nivå 0-Glimten för en ny spelare).
   * Aktivt sets skinn. Tryck på hjälten = kompisens showcase en gång (leksak, ingen navigering).
   * Utan kompis: objektet gör mergePunch 1,10 och sitt pling. Tryck under pågående showcase ignoreras.
   */
  hero: {
    cx: 180,
    /** Objektet visas alltid i samma storlek, oavsett nivå, så att layouten står still. */
    ball: { cy: 244, r: 24 },
    /** Greppet = objektets ovankant + gripBelowTop (samma proportion som i spel: 4 px vid 40 px). Idle-loop via AvatarRig. */
    buddy: { displayPx: 104, gripBelowTop: 10 },
    /** Utan kompis: objektet guppar (dy −4, halvcykel 1 400 ms = 0,36 Hz). */
    bob: { dy: -4, halfCycleMs: 1400, ease: 'Sine.easeInOut' },
    /** Scen: ellips (rx 80, ry 16) med 8 px tjocklek nedåt, vertikal gradient, kant 2 px jarEdge, mjuk skugga under. */
    stage: { cy: 268, rx: 80, ry: 16, depth: 8, edgeW: 2, shadowAlpha: 0.4 },
    /** Halo bakom: radial accent, stilla. Med kompis blandas raritetsfärgen in (30 %). */
    halo: { cy: 206, r: 96, alpha: 0.2, rarityMix: 0.3 },
    hit: { x: 90, y: 126, w: 180, h: 160 },
  },

  /**
   * Rekord som guldchip under scenen: krona + siffra, centrerat. Rekordets kompis (26 px) i ring till
   * vänster inne i chippet om den skiljer sig från vald kompis. Chippet växer med innehållet.
   */
  record: {
    y: 312,
    h: 40,
    r: 20,
    edgeW: 2,
    padX: 16,
    crownPx: 24,
    textPx: 26,
    textWeight: '700' as const,
    gap: 8,
    avatar: { displayPx: 26, ringR: 13, ringW: 2 },
  },

  /** Primärknapp SPELA (BUTTON_STYLE.primary). 290×96 CSS-px → 268×88. */
  play: {
    cx: 180,
    cy: 390,
    w: 268,
    h: 88,
    /** Träffyta: knappen + 8 px runt om (284×104). */
    slop: 8,
    iconPx: 30,
    /** ▶ + 10 px + etikett, centrerat som grupp. */
    gap: 10,
    /** Mjuk puls: skala 1,00 ↔ 1,03, halvcykel 900 ms = 0,56 Hz (≤ 1 Hz). Glöd-ringen följer med. Pausas medan knappen hålls ned. */
    pulse: { scale: 1.03, halfCycleMs: 900, ease: 'Sine.easeInOut' },
    /**
     * Onboarding utan text: före allra första rundan trycker handen (ICONS.hand, 56 px) på SPELA var 2,2 s
     * (ned 1,00 → 0,9 och knappen själv gör sitt tryckläge synkront). Försvinner efter första rundan.
     */
    hint: { handPx: 56, dx: 70, dy: 34, loopMs: 2200, pressAtMs: 700, pressMs: 240 },
  },

  /** Tre kort i rad (BUTTON_STYLE.card). x 16–344, 12 px mellanrum, bredd 101. */
  cards: {
    top: 454,
    w: 101,
    h: 104,
    gap: 12,
    /** Träffyta = kortet + 4 px runt om (109×112). Mellanrum mellan träffytor: 4 px. */
    slop: 4,
    order: ['book', 'buddies', 'shop'] as readonly StartCard[],
    cx: [66.5, 180, 293.5] as readonly number[],
    /** Radernas centrum, mätt från kortets överkant. */
    iconY: 32,
    iconPx: 40,
    labelY: 66,
    labelColor: HUD,
    subY: 88,
    subPx: 14,
    subWeight: '500' as const,
    subColor: HUD_DIM,
    /** Nytt i boken / nya kompisar: kortets ikon andas 1,00 ↔ 1,08, 0,5 Hz, och kortet får badge. */
    freshBreath: { scale: 1.08, halfCycleMs: 1000, ease: 'Sine.easeInOut' },
    book: {
      /** BOOK_ICON i accent. Underrad: fångade platser i aktivt set, "8 / 21". */
      iconColor: ACCENT,
      sub: 'setCaught' as const,
      /** Badge: freshSet eller någon fresh-plats i collection. */
      badge: 'setFresh' as const,
      /** Tryck: boken på fliken Set, aktivt set (tvingat, även om det finns nya kompisar). */
      go: { scene: 'Book', data: { tab: 'sets' } },
    },
    buddies: {
      /** BUDDIES_ICON i guld. Underrad: ägda, "5 / 48". */
      iconColor: GOLD,
      sub: 'owned' as const,
      /** Badge: avatars.fresh.length > 0. */
      badge: 'avatarFresh' as const,
      /** Tryck: boken på fliken Kompisar, startposition enligt §13.4. */
      go: { scene: 'Book', data: { tab: 'friends' } },
    },
    shop: {
      /** SHOP_ICON i rosa (markis + mussla). Underrad: "Musslor"; med väntande gratismussla: "Gratis!" i guld. */
      iconColor: PINK,
      sub: 'shells' as const,
      subFree: 'free' as const,
      subFreeColor: GOLD,
      /**
       * Badge (kortets läge 'badge' + guldprick): gratismussla väntar (pendingBoxes > 0) ELLER
       * pärlor ≥ vanlig musslas pris och en vanlig finns kvar. "Gratis!" och den tittande musslan bara vid väntande.
       */
      badge: 'shopReady' as const,
      /**
       * Väntande gratismussla: en liten mussla (SHELL_ICON, 36 px) tittar upp över kortets övre vänstra hörn,
       * lutad −14°. Studs: dy 0 → −6 (180 ms Quad.easeOut) → 0 (240 ms Bounce.easeOut), vila 1 580 ms
       * = ett studs var 2:a sekund (0,5 Hz). Squash 1,10 × 0,90 vid landning. Ingen siffra. Fler än en: en
       * andra mussla skymtar bakom (dx −6, dy 2, skala 0,86, alpha 0,8), aldrig fler än två synliga.
       */
      peek: { x: 20, y: 0, px: 36, rotDeg: -14, dy: -6, upMs: 180, downMs: 240, restMs: 1580, squash: [1.1, 0.9] as readonly [number, number], back: { dx: -6, dy: 2, scale: 0.86, alpha: 0.8 } },
      /**
       * Tryck med väntande mussla: öppningen (§13.3) startar direkt på startskärmen, från den tittande
       * musslans plats. Vid stängning flyger figuren till Kompisar-kortet. Annars: boken på Kompisar, scroll 0
       * (butikshyllan överst, `focus: 'shop'` är ny parameter i Book).
       */
      go: { scene: 'Book', data: { tab: 'friends', focus: 'shop' } },
    },
  },

  /**
   * Set-stapeln längst ned: aktivt sets ikon → stapel → nästa set (streckad cirkel med siluett och lås).
   * Text under: "412 / 600 till nästa set". Bara tidsspåret. Döljs när alla 5 set är upplåsta.
   * Inte tryckbar. Nästa set dras först vid upplåsningen, så siluetten är samma för alla låsta set.
   */
  setBar: {
    y: 580,
    from: { x: 32, px: 30 },
    bar: { x0: 56, x1: 294, h: 13, r: 6.5 },
    to: { x: 322, d: 36, dash: [4, 4] as readonly [number, number], edgeW: 2, iconPx: 22, lock: { dx: 12, dy: 12, px: 16 } },
    text: { y: 604, px: 14, weight: '500' as const, color: HUD_DIM },
    /** Stapeln fylls inte animerat här (det gör rundavslutet). Nyss upplåst set syns i boken. */
  },

  /** Lugnt läge: halv amplitud på startskärmens två rörelser. Handen i onboardingen är kvar. */
  calm: { playPulseScale: 1.015, peekDy: -3, bobDy: -2 },

  /** Inställningsarket (bottenark). Öppnas av kugghjulet. Stängs med X, tryck på scrimmen eller bakåt. */
  settings: {
    scrimAlpha: 0.72,
    top: 300,
    radius: 28,
    edgeW: 2,
    inMs: 260,
    inEase: 'Cubic.easeOut',
    outMs: 200,
    outEase: 'Cubic.easeIn',
    handle: { y: 312, w: 40, h: 5 },
    /** Rubrik: kugghjulet i hudDim (inte tryckbart) + stäng-X som rund knapp. Ingen rubriktext. */
    header: { y: 342, gearX: 40, gearPx: 28, close: { x: 320, d: 48, iconPx: 24, hit: 64 } },
    /** Fyra rader à 64, hela raden är träffyta (x 16–344). Sista raden slutar på y 628 (inom 640). */
    rows: {
      y0: 404,
      pitch: 64,
      x0: 16,
      x1: 344,
      /** Ikonruta 40×40, radie 12, ikon 30 px inuti. */
      iconBox: { x: 44, size: 40, r: 12, iconPx: 30 },
      labelX: 76,
      labelPx: 18,
      labelWeight: '600' as const,
      /** Hjälptext under etiketten (min 14 px). */
      helpPx: 14,
      helpWeight: '500' as const,
      labelDy: -10,
      helpDy: 11,
      divider: { color: JAR_WALL, w: 1, x0: 28, x1: 332 },
      order: ['sound', 'haptics', 'calm', 'aimLine'] as readonly SettingKey[],
    },
    /** Strömbrytare 58×34 (62×36 CSS-px). Knoppens läge + bocken bär informationen, ikonen kryssas vid AV. */
    switch: { cx: 300, w: 58, h: 34, knobR: 13, edgeW: 2, ms: 140, ease: 'Cubic.easeOut', checkPx: 16 },
  },
} as const;

// ---------------------------------------------------------------- texter (EN primärt, SV lokalisering)

/**
 * Knappetiketter ≤ 10 tecken (`START_LABEL_MAX`). Underrader och arkets hjälptexter är längre och har eget tak.
 * Ligger här i stället för i `STRINGS` (i18n.ts), eftersom `tests/unit/i18n.test.ts` kräver att STRINGS är tom.
 * Programmeraren flyttar dem dit och tar bort den kontrollen (eller re-exporterar). `{n}` och `{m}` ersätts.
 */
export const START_STRINGS = {
  play: { en: 'Play', sv: 'Spela' },
  book: { en: 'Book', sv: 'Bok' },
  buddies: { en: 'Buddies', sv: 'Kompisar' },
  shop: { en: 'Shop', sv: 'Butik' },
  shells: { en: 'Shells', sv: 'Musslor' },
  free: { en: 'Free!', sv: 'Gratis!' },
  sound: { en: 'Sound', sv: 'Ljud' },
  haptics: { en: 'Vibration', sv: 'Vibration' },
  calm: { en: 'Calm mode', sv: 'Lugnt läge' },
  aimLine: { en: 'Aim line', sv: 'Siktlinje' },
  /** Hjälptexter i arket (≤ 26 tecken, en rad i 240 px vid 14 px). */
  soundHelp: { en: 'Music and effects', sv: 'Musik och effekter' },
  hapticsHelp: { en: 'Buzz on merges', sv: 'Surr vid sammanslagning' },
  calmHelp: { en: 'Less shake and flash', sv: 'Mindre skak och ljus' },
  aimLineHelp: { en: 'Line where it falls', sv: 'Linje där den faller' },
  /** Set-stapelns text. */
  nextSet: { en: '{n} / {m} to next set', sv: '{n} / {m} till nästa set' },
  /** Underrad med räknare (Bok, Kompisar). */
  count: { en: '{n} / {m}', sv: '{n} / {m}' },
} as const satisfies Record<string, LocalizedName>;

export type StartStringKey = keyof typeof START_STRINGS;

/** Knappetiketter (play, book, buddies, shop, shells, free, och arkets rader) får vara högst så här långa. */
export const START_LABEL_MAX = 10;
export const START_LABEL_KEYS: readonly StartStringKey[] = ['play', 'book', 'buddies', 'shop', 'shells', 'free', 'sound', 'haptics', 'calm', 'aimLine'];

/** Fyller i `{n}` och `{m}`. Siffror formateras med formatAmount (smalt mellanslag). */
export function fillString(s: string, n: string, m: string): string {
  return s.replace('{n}', n).replace('{m}', m);
}

// ---------------------------------------------------------------- ikoner (viewBox 64, stil som UI.md §9)

const svg = (body: string): string =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" stroke-linecap="round" stroke-linejoin="round">${body}</svg>`;

const f1 = (n: number): string => n.toFixed(1);

/** Kugghjul: 8 rundade kuggar, hål i mitten. */
export const GEAR_ICON = (c: string = ACCENT): string => {
  const n = 8;
  const w = (Math.PI * 2) / n;
  const pts: string[] = [];
  for (let i = 0; i < n; i++) {
    const a = i * w - Math.PI / 2;
    const seq: [number, number][] = [
      [a - w * 0.5, 19.5],
      [a - w * 0.2, 26],
      [a + w * 0.2, 26],
      [a + w * 0.5, 19.5],
    ];
    for (const [ang, r] of seq) pts.push(`${f1(32 + Math.cos(ang) * r)} ${f1(32 + Math.sin(ang) * r)}`);
  }
  return svg(`<path d="M${pts.join(' L')} Z" fill="none" stroke="${c}" stroke-width="6"/><circle cx="32" cy="32" r="7" fill="none" stroke="${c}" stroke-width="6"/>`);
};

/** Hänglås. Kropp fylld, bygel som streck, nyckelhål i ink. */
export const LOCK_ICON = (c: string = HUD, ink: string = INK): string =>
  svg(
    `<path d="M20 30 V22 a12 12 0 0 1 24 0 V30" fill="none" stroke="${c}" stroke-width="7"/>` +
      `<rect x="12" y="28" width="40" height="30" rx="8" fill="${c}" stroke="${ink}" stroke-width="4"/>` +
      `<circle cx="32" cy="40" r="4.5" fill="${ink}"/><path d="M32 42 V50" stroke="${ink}" stroke-width="5"/>`,
  );

/**
 * Nästa sets siluett: en okänd Glimt (rund kropp med två ögon och en liten tofs) i siluettfärg.
 * Ritas inuti setBar.to:s streckade cirkel. Alla låsta set ser likadana ut (DESIGN §13.3).
 */
export const NEXT_SET_ICON = (fill: string = SILHOUETTE, eye: string = BG): string =>
  svg(
    `<path d="M32 14 Q30 6 36 4" fill="none" stroke="${fill}" stroke-width="5"/>` +
      `<circle cx="32" cy="36" r="22" fill="${fill}"/>` +
      `<circle cx="24" cy="34" r="3.6" fill="${eye}"/><circle cx="40" cy="34" r="3.6" fill="${eye}"/>` +
      `<path d="M27 44 Q32 48 37 44" fill="none" stroke="${eye}" stroke-width="3.5"/>`,
  );

/**
 * Butik: markis med bågad kant, två stolpar och en mussla på disken. En färg (rosa), så att ikonen
 * skiljer sig från Bok (cyan) och Kompisar (guld) även i form: markis, bok och figurer.
 */
export const SHOP_ICON = (c: string = PINK): string =>
  svg(
    `<path d="M8 22 L12 8 H52 L56 22 Z" fill="${c}" fill-opacity="0.25"/>` +
      `<path d="M22 8 L20 22 M32 8 V22 M42 8 L44 22" stroke="${c}" stroke-width="4" fill="none"/>` +
      `<path d="M8 22 L12 8 H52 L56 22" fill="none" stroke="${c}" stroke-width="5"/>` +
      `<path d="M8 22 a6 6 0 0 0 12 0 a6 6 0 0 0 12 0 a6 6 0 0 0 12 0 a6 6 0 0 0 12 0" fill="none" stroke="${c}" stroke-width="5"/>` +
      `<path d="M12 32 V57 M52 32 V57 M6 57 H58" fill="none" stroke="${c}" stroke-width="5"/>` +
      `<path d="M22 50 C22 41 42 41 42 50 Z" fill="${c}"/><path d="M22 50 H42" stroke="${c}" stroke-width="4"/>` +
      `<path d="M32 49 V43 M27 49 L25 44 M37 49 L39 44" stroke="${BG}" stroke-width="2"/>`,
  );

/** Kompisar: två figurer, den främre håller en boll som Släpparen. Guld på startkortet. */
export const BUDDIES_ICON = (c: string = GOLD): string =>
  svg(
    `<circle cx="19" cy="24" r="9" fill="none" stroke="${c}" stroke-width="5"/>` +
      `<circle cx="16" cy="23" r="1.9" fill="${c}"/><circle cx="22" cy="23" r="1.9" fill="${c}"/>` +
      `<path d="M11 33 Q8 42 14 48 M27 33 Q29 38 28 42" fill="none" stroke="${c}" stroke-width="5"/>` +
      `<circle cx="40" cy="22" r="12" fill="none" stroke="${c}" stroke-width="6"/>` +
      `<circle cx="35.5" cy="21" r="2.4" fill="${c}"/><circle cx="44.5" cy="21" r="2.4" fill="${c}"/>` +
      `<path d="M31 32 Q26 40 33 46 M49 32 Q54 40 47 46" fill="none" stroke="${c}" stroke-width="6"/>` +
      `<circle cx="40" cy="50" r="8" fill="${c}"/>`,
  );

/** SPELA-ikonen på primärknappen: ▶ i mörk text-färg. */
export const PLAY_GLYPH = (c: string = BG): string =>
  svg(`<path d="M22 14 L50 32 L22 50 Z" fill="${c}" stroke="${c}" stroke-width="8"/>`);

/** Bock för strömbrytarens knopp (cyan på mörk knopp). */
export const SWITCH_CHECK = (c: string = ACCENT): string => svg(`<path d="M16 33 L27 44 L48 21" fill="none" stroke="${c}" stroke-width="9"/>`);

/** Texturnycklar. Ladda med loadIcons (64-box, 2×). */
export const START_ICON_KEYS = {
  gear: 'st-gear',
  gearDim: 'st-gear-dim',
  lock: 'st-lock',
  nextSet: 'st-next-set',
  shop: 'st-shop',
  buddies: 'st-buddies',
  playGlyph: 'st-play',
  playGlyphDim: 'st-play-dim',
  switchCheck: 'st-check',
} as const;

/** Alla ikoner för loadIcons: [nyckel, svg]. */
export function startIcons(): [string, string][] {
  const K = START_ICON_KEYS;
  return [
    [K.gear, GEAR_ICON()],
    [K.gearDim, GEAR_ICON(HUD_DIM)],
    [K.lock, LOCK_ICON()],
    [K.nextSet, NEXT_SET_ICON()],
    [K.shop, SHOP_ICON()],
    [K.buddies, BUDDIES_ICON()],
    [K.playGlyph, PLAY_GLYPH()],
    [K.playGlyphDim, PLAY_GLYPH(HUD_DIM)],
    [K.switchCheck, SWITCH_CHECK()],
  ];
}

/** Checklista (UI.md §16.8): det här tas bort ur nuvarande Start.ts. Används inte i koden. */
export const START_V1_REMOVED = [
  'play-cirkeln (180, 330) r 56 och dess ikonpuls',
  'hyllan (AVATAR_UI.shelf.line + konsoler) och bästa objektet på hyllan',
  'bok-ikonen på hyllan (AVATAR_UI.shelf.book, badge, bookHit)',
  'musslorna på hyllan (AVATAR_UI.shelf.box) – flyttar till Butik-kortet',
  'kompisen på hyllan (AVATAR_UI.shelf.buddy) – flyttar till hjälten',
  'rekordets kompis vid (110, 496) och krona/siffra vid (140/172, 498) – flyttar till rekordchippet',
  'set-stapeln META.shelf.bar med qmark – ersätts av START_UI.setBar',
  'ikonraden y 580 (ljud, haptik, lugnt, siktlinje) – flyttar till inställningsarket',
  'regeln "tryck var som helst = spela" – bara SPELA-knappen startar en runda',
  'Counters på y 30 på startskärmen – ersätts av pillren (boken behåller Counters)',
] as const;

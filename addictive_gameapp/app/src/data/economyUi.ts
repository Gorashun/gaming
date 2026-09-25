/**
 * economyUi.ts – UI-delen av ekonomin (DESIGN §16, UI.md §14). Ägare: ui-designer.
 *
 * PRISER, ODDS, GOLV OCH INTJÄNING ligger i `data/economy.ts` (`ECONOMY`, programmeraren) och dupliceras
 * INTE här. Allt nedan är layout (logiska px, 360×640), tider, färger, ikoner och ljud.
 * Programmeraren slår ihop filen med economy.ts (eller `export * from './economyUi'`).
 *
 * Ren data, ingen Phaser. Flash-guard: inga loopar över 0,5 Hz, ingen ljusstyrkeväxling, inga vitblixtar.
 */

import type { AvatarTone } from './avatars';
import type { ShellType } from './economy';

// ---------------------------------------------------------------- färger

/** Kontrast mot bg #0B1020 inom parentes (WCAG). */
export const ECONOMY_COLORS = {
  /** Valutapärlan: pärlemorrosa med gradient (16,5 / 11,6:1). Skiljs från raritetspärlorna (platta, en färg). */
  pearl: '#FFEAF3',
  pearlShade: '#F3BBD3',
  /** Stjärnsand: ljus aprikos (13,6:1), mörkare korn (9,3:1). Form: tre femuddiga stjärnor på en liten hög. */
  sand: '#FFD39B',
  sandShade: '#E8A95C',
  /** Förmågetext (12,9:1). Namnet är `hud`. */
  desc: '#C9D6EE',
  ink: '#14202E',
  shell: {
    common: { fill: '#FFD9E8', rib: '#E79AC0' },
    silver: { fill: '#E3EAF5', rib: '#9DAECB' },
    gold: { fill: '#FFE39A', rib: '#D9A441' },
    /** Tomt (inget kvar över golvet): grå, 3,3:1, bär en bock. Formen och bocken bär informationen. */
    empty: { fill: '#5B6780', rib: '#46526B' },
  } as Readonly<Record<ShellType | 'empty', { readonly fill: string; readonly rib: string }>>,
} as const;

const ACCENT = '#7CF9FF';
const HUD_DIM = '#8FA3C8';
const INK = ECONOMY_COLORS.ink;
const WHITE = '#FFFFFF';

// ---------------------------------------------------------------- layout och tider (UI.md §14)

export const ECONOMY_UI = {
  /**
   * Resursräknare. Samma plats och utseende i bokens överkant och på startskärmen (UI.md §14.2).
   * Inte tryckbara (därför inte accent). Tusental med smalt mellanslag ("1 240").
   */
  counters: {
    y: 30,
    iconPx: 20,
    textPx: 16,
    pearls: { iconX: 148, textX: 161 },
    sand: { iconX: 232, textX: 245 },
    /** Vid köp/uppgradering: siffran räknas ned. */
    countDownMs: 300,
    /** "Räcker inte": ikonen för det som fattas punchar en gång. */
    lackPunch: { scale: 1.18, ms: 220, ease: 'Back.easeOut' },
  },

  /** Butikshyllan högst upp i fliken Kompisar (UI.md §14.3). */
  shop: {
    top: 76,
    bottom: 172,
    shelf: { x0: 16, x1: 344, y: 140, w: 3, consoleX: [28, 332] as readonly number[], consoleH: 8 },
    /** Mittpunkt per plats, vänster till höger: vanlig, silver, guld. */
    order: ['common', 'silver', 'gold'] as readonly ShellType[],
    slotX: [66, 180, 294] as readonly number[],
    /** Träffyta per plats: cx ± 53 (8 px mellanrum), y top+4 … bottom. */
    hit: { halfW: 53, y0: 80, y1: 172 },
    shell: { dx: -20, y: 116, px: 48 },
    /** Mini-oddsburk: 25 pärlor, rader 6-5-6-5-3 nedifrån, vanlig längst ner (som AVATAR_UI.book.jar). */
    jar: { dx: 27, y: 118, w: 40, h: 42, lidH: 5, edgeW: 2, pearlR: 2.9, pitchX: 5.9, pitchY: 5.4, rows: [6, 5, 6, 5, 3] as readonly number[], bottomPad: 5 },
    /** Pris: resursikon + siffra, centrerat på cx. */
    price: { y: 158, iconPx: 16, textPx: 15, gap: 7 },
    /** Räcker inte: ring runt prisikonen visar hur långt man har kommit (have/price). */
    progressRing: { r: 10.5, w: 2.5, trackAlpha: 0.35, startDeg: -90 },
    /** Räcker inte: musslan tonas, kanten blir hudDim. */
    poorAlpha: 0.55,
    /** Tomt: grå mussla + bockbricka, tom burk (bara locket och glaset), inget pris. */
    doneBadge: { dx: 16, dy: -16, r: 8 },
    /** Full bok (alla 48): hyllan visar gul bok-ikon med tre stilla gnistor i stället för musslorna. */
    fullBook: { x: 180, y: 112, px: 48, sparks: [[-40, -12, 12], [38, -18, 10], [44, 10, 8]] as readonly (readonly [number, number, number])[] },
  },

  /**
   * Köp i två tryck (UI.md §14.4). Första trycket väcker musslan, andra köper.
   * Tryck någon annanstans (eller 3 s) = somna. Tryck på en annan mussla = den vaknar i stället.
   */
  wake: {
    ms: 300,
    ease: 'Back.easeOut',
    dy: -6,
    scale: 1.12,
    /** Överhalvan glipar (SHELL_TOP_SVG scaleY), så att man ser pärlemor. */
    lidScaleY: 0.82,
    /** Prisets kant och siffra blir accent (nu är det en knapp). */
    priceChip: { padX: 8, h: 24, r: 12, w: 2, fillAlpha: 0.16 },
    /** Övriga musslor tonas medan en är vaken. */
    othersAlpha: 0.45,
    /** Vaken mussla andas 0,5 Hz (under flash-guard-gränsen). */
    breath: { scale: 1.15, halfCycleMs: 1000, ease: 'Sine.easeInOut' },
    sleepAfterMs: 3000,
    sleepMs: 200,
    /** Andra trycket räknas bara efter att väckningen syns (skydd mot dubbeltryck). */
    minGapMs: 250,
  },

  /** Köpet: pärlor/sand flyger från räknaren till musslan, sedan öppningen i AVATAR_UI.open (1 200 ms). */
  buy: {
    fly: { count: 6, staggerMs: 20, ms: 240, ease: 'Cubic.easeIn', px: 12 },
    /** Öppningsceremonin startar när sista pärlan landat. Musslan flyger från sin plats på hyllan. */
    openAt: 360,
    /** Efter stängningen: figuren flyger mot rutnätets överkant och rutnätet scrollar till dess rad. */
    close: { toY: 346, scrollMs: 240, ease: 'Cubic.easeOut' },
  },

  /** Räcker inte (mussla eller uppgraderingsknapp): mjuk skakning, inget rött, inget kryss. */
  poor: { shakePx: 4, shakes: 2, ms: 240 },

  /** Scenen: vald kompis med namn, förmågetext, stapel och uppgraderingsknapp (UI.md §14.5). */
  stage: {
    top: 180,
    separator: { y: 176, x0: 16, x1: 344, w: 2 },
    figure: { x: 52, cy: 214, displayPx: 60, glowR: 38, glowAlpha: 0.25, objLevel: 1, objR: 10 },
    hit: { x: 8, y: 180, w: 88, h: 100 },
    rarityPearls: { y: 274, r: 3.5, pitch: 10 },
    name: { x: 104, y: 194, px: 17, minPx: 14, maxW: 240 },
    desc: { x: 104, y: 212, px: 14, lineH: 17, maxW: 240, maxLines: 2 },
    bar: { x0: 104, x1: 344, y: 262, h: 10, gap: 6, r: 5, outlineW: 2 },
    hint: { y: 278, px: 11, maxChars: 9, arrowPx: 10, levelIconR: 7 },
    button: { cx: 224, cy: 314, w: 240, h: 48, r: 14, hit: { h: 56 }, iconPx: 24, priceIconPx: 16, textPx: 16, gap: 7 },
    /** Uppgradering klar: segmentet fylls, figuren gör showcase, rombarna poppar. */
    upgraded: { fillMs: 280, fillEase: 'Cubic.easeOut', particles: 12, particleSpeed: 70, lifeMs: 460, rombPopMs: 200 },
  },

  /** Rutnätet flyttas ned (ersätter AVATAR_UI.book.grid.top 204). Den gamla stora burken tas bort. */
  grid: { top: 346 },

  /**
   * Rundavslutet (UI.md §14.6): pärlor och sand räknas upp i stripens vänsterkant, ≤ 600 ms,
   * med start när mätaren är klar (sista flygaren landat + 80 ms), eller vid 420 ms utan fångster.
   */
  tally: {
    pearls: { iconX: 30, textX: 44, y: 56 },
    sand: { iconX: 30, textX: 44, y: 94 },
    iconPx: 22,
    textPx: 20,
    popMs: 140,
    countMs: 600,
    countEase: 'Quad.easeOut',
    /** Högst så många tick-ljud per räknare, minst 45 ms isär. Tonen stiger 0 → 12 halvtoner. */
    maxTicks: 12,
    minTickGapMs: 45,
    /** Sand börjar 120 ms efter pärlorna (två hörbara lager). */
    sandDelayMs: 120,
    endPunch: { scale: 1.2, ms: 180 },
    /** Om pärlorna precis räckte till en vanlig mussla: liten mussla poppar in bredvid. Ingen text, ingen puls. */
    affordHint: { x: 104, y: 56, px: 24, popMs: 160 },
  },

  /** Reservläget SHOP.mode = 'pick3': välj 1 av 3 synliga (UI.md §14.8). */
  pick3: {
    scrimAlpha: 0.86,
    close: { x: 320, y: 44, px: 48, hit: 72 },
    shell: { x: 180, y: 120, px: 72 },
    cards: { cx: [72, 180, 288] as readonly number[], y0: 176, w: 100, h: 164, r: 16, frameW: 3, figurePx: 72, figureY: 236, pearlsY: 292, nameY: 314, namePx: 13 },
    riseMs: 260,
    staggerMs: 90,
    selected: { dy: -8, frameW: 4, badgeR: 9 },
    /** Vald figurs text under korten. */
    info: { y: 366, px: 15, lineH: 19, maxW: 312, maxLines: 2 },
    /** Köpknapp (två tryck: välj kort, tryck köp). */
    buy: { cx: 180, cy: 448, w: 200, h: 64, r: 18 },
  },
} as const;

// ---------------------------------------------------------------- ljud (ToneDef-kompatibla, playTone)

export const ECONOMY_SOUND = {
  /** Första trycket: musslan (eller knappen) vaknar. Uppåt, nyfiket. */
  wake: { wave: 'sine', baseHz: 660, glideTo: 990, attack: 0.002, decay: 0.1, gain: 0.12 },
  /** Köp: pärlor läggs i skålen, två toner. Därefter AVATAR_SOUND.shellOpen i ceremonin. */
  buy: { wave: 'triangle', baseHz: 1046.5, attack: 0.002, decay: 0.09, gain: 0.16, steps: [0, 7], stepMs: 60, harmonicSemitones: 12, harmonicGain: 0.2 },
  /** Uppgradering: stigande fyrklang, varm. */
  upgrade: { wave: 'triangle', baseHz: 587.33, attack: 0.004, decay: 0.24, gain: 0.26, steps: [0, 4, 7, 12], stepMs: 70, harmonicSemitones: 12, harmonicGain: 0.25, vibratoHz: 5, vibratoCents: 8 },
  /** Räcker inte: mjukt "hm-m", liten ters nedåt, lågpass. Aldrig surr eller buzzer. */
  notEnough: { wave: 'sine', baseHz: 392, attack: 0.006, decay: 0.12, gain: 0.1, steps: [0, -3], stepMs: 90, lowpassHz: 1400 },
  /** Rundavslut: ett tick per steg. playTone(def, 12 · andel). */
  tallyPearl: { wave: 'sine', baseHz: 1318.5, attack: 0.001, decay: 0.035, gain: 0.07 },
  tallySand: { wave: 'triangle', baseHz: 1760, attack: 0.002, decay: 0.06, gain: 0.08, harmonicSemitones: 7, harmonicGain: 0.4 },
  /** När räkningen är klar. */
  tallyEnd: { wave: 'sine', baseHz: 1046.5, glideTo: 1568, attack: 0.002, decay: 0.12, gain: 0.12 },
} as const satisfies Record<string, AvatarTone>;

// ---------------------------------------------------------------- ikoner (SVG, viewBox 64, stil som UI.md §9)

const svg = (body: string): string =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" stroke-linecap="round" stroke-linejoin="round">${body}</svg>`;

/**
 * Valutapärla. Skiljs från raritetspärlan (PEARL_ICON: platt, en färg) genom pärlemorgradient,
 * dubbel högdager och en liten gnista. Står alltid bredvid en siffra.
 */
export const PEARL_COIN_ICON = (fill: string = ECONOMY_COLORS.pearl, shade: string = ECONOMY_COLORS.pearlShade): string =>
  svg(
    `<defs><radialGradient id="pc" cx="0.36" cy="0.32" r="0.75"><stop offset="0" stop-color="${WHITE}"/><stop offset="0.45" stop-color="${fill}"/><stop offset="1" stop-color="${shade}"/></radialGradient></defs>` +
      `<circle cx="30" cy="34" r="22" fill="url(#pc)" stroke="${INK}" stroke-width="5"/>` +
      `<ellipse cx="22" cy="25" rx="7" ry="4.5" fill="${WHITE}" fill-opacity="0.9" transform="rotate(-30 22 25)"/>` +
      `<circle cx="38" cy="44" r="2.6" fill="${WHITE}" fill-opacity="0.6"/>` +
      `<path d="M52 6 C52.8 11 54 12.2 59 13 C54 13.8 52.8 15 52 20 C51.2 15 50 13.8 45 13 C50 12.2 51.2 11 52 6 Z" fill="${WHITE}"/>`,
  );

/** Rundad femuddig stjärna som path (används av stjärnsand och guldmusslan). */
function starPath(cx: number, cy: number, R: number, r: number): string {
  const pts: string[] = [];
  for (let i = 0; i < 10; i++) {
    const a = -Math.PI / 2 + (i * Math.PI) / 5;
    const rr = i % 2 === 0 ? R : r;
    pts.push(`${(cx + Math.cos(a) * rr).toFixed(1)} ${(cy + Math.sin(a) * rr).toFixed(1)}`);
  }
  return `M${pts.join(' L')} Z`;
}

/** Stjärnsand: liten hög med tre stjärnkorn (verklig stjärnsand är stjärnformade korn). */
export const SAND_ICON = (fill: string = ECONOMY_COLORS.sand, shade: string = ECONOMY_COLORS.sandShade): string =>
  svg(
    `<path d="M6 54 C12 42 22 38 32 38 C42 38 52 42 58 54 Z" fill="${shade}" stroke="${INK}" stroke-width="5"/>` +
      `<path d="${starPath(32, 26, 18, 8.5)}" fill="${fill}" stroke="${INK}" stroke-width="5"/>` +
      `<path d="${starPath(13, 44, 8.5, 4)}" fill="${fill}" stroke="${INK}" stroke-width="4"/>` +
      `<path d="${starPath(51, 45, 7.5, 3.5)}" fill="${fill}" stroke="${INK}" stroke-width="4"/>` +
      `<circle cx="27" cy="21" r="3" fill="${WHITE}" fill-opacity="0.8"/>`,
  );

/**
 * Mussla per typ och tillstånd. Samma silhuett som SHELL_ICON (avatars.ts) så att "mussla" känns igen.
 * Typen syns i FORM, inte bara färg: vanlig = slät, silver = två glintar, guld = stjärna (köps med stjärnsand).
 *  - state 'ok'    : accent-kant (tryckbar, det finns råd)
 *  - state 'poor'  : hudDim-kant (tonas med ECONOMY_UI.shop.poorAlpha i scenen)
 *  - state 'empty' : grå + bock, inget kvar över golvet
 */
export const SHELL_TYPE_ICON = (type: ShellType, state: 'ok' | 'poor' | 'empty' = 'ok'): string => {
  const c = state === 'empty' ? ECONOMY_COLORS.shell.empty : ECONOMY_COLORS.shell[type];
  const edge = state === 'ok' ? ACCENT : HUD_DIM;
  const top =
    `<path d="M7 38 C9 52 20 58 32 58 C44 58 55 52 57 38 Z" fill="${c.fill}" stroke="${edge}" stroke-width="4"/>` +
    `<path d="M7 38 C5 20 18 10 32 10 C46 10 59 20 57 38 C52 41 47 36 42 39 C37 42 35 37 32 39 C29 37 27 42 22 39 C17 36 12 41 7 38 Z" fill="${c.fill}" stroke="${edge}" stroke-width="4"/>` +
    `<path d="M32 38 L32 15 M32 38 L20 18 M32 38 L44 18 M32 38 L12 27 M32 38 L52 27" fill="none" stroke="${c.rib}" stroke-width="3"/>` +
    `<path d="M26 58 L32 50 L38 58" fill="none" stroke="${c.rib}" stroke-width="3"/>`;
  const mark =
    type === 'silver'
      ? `<path d="M19 16 C19.6 20 20.5 21 24 21.5 C20.5 22 19.6 23 19 27 C18.4 23 17.5 22 14 21.5 C17.5 21 18.4 20 19 16 Z" fill="${WHITE}"/>` +
        `<path d="M46 25 C46.4 27.6 47 28.2 49.5 28.6 C47 29 46.4 29.6 46 32.2 C45.6 29.6 45 29 42.5 28.6 C45 28.2 45.6 27.6 46 25 Z" fill="${WHITE}"/>`
      : type === 'gold'
        ? `<path d="${starPath(32, 25, 10, 4.6)}" fill="${state === 'empty' ? c.rib : ECONOMY_COLORS.sand}" stroke="${INK}" stroke-width="3"/>`
        : '';
  const done =
    state === 'empty'
      ? `<circle cx="50" cy="14" r="11" fill="${HUD_DIM}" stroke="${INK}" stroke-width="3"/><path d="M44.5 14.5 L48.5 18.5 L55.5 10.5" fill="none" stroke="${INK}" stroke-width="4"/>`
      : '';
  return svg(top + mark + done);
};

/** Uppgraderingspil (tryckbar ⇒ accent). Pil upp över en liten romb, samma romb som i boken. */
export const UPGRADE_ICON = (c: string = ACCENT): string =>
  svg(
    `<path d="M32 40 V10 M18 24 L32 10 L46 24" fill="none" stroke="${c}" stroke-width="7"/>` +
      `<path d="M32 44 L41 52 L32 60 L23 52 Z" fill="${c}"/>`,
  );

/** Bock i cirkel (klar / nivå III / tomt). */
export const CHECK_ICON = (c: string = HUD_DIM, ink: string = INK): string =>
  svg(`<circle cx="32" cy="32" r="24" fill="${c}"/><path d="M21 33 L29 41 L44 24" fill="none" stroke="${ink}" stroke-width="7"/>`);

/** Nycklar för texturladdning (samma mönster som ICON_KEYS). */
export const ECONOMY_ICON_KEYS = {
  pearlCoin: 'eco-pearl',
  sand: 'eco-sand',
  upgrade: 'eco-upgrade',
  check: 'eco-check',
  shell: (type: ShellType, state: 'ok' | 'poor' | 'empty'): string => `eco-shell-${type}-${state}`,
} as const;

/** Tusental med smalt mellanslag (UI.md §2.2): 1240 → "1 240". */
export function formatAmount(n: number): string {
  return Math.max(0, Math.floor(n))
    .toString()
    .replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
}

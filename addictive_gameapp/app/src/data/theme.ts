/**
 * theme.ts – KLUNK designtokens ("Glimtarna")
 *
 * Ren data. Får INTE importera Phaser. Spec: docs/UI.md.
 * Index 0–10 i `levels` motsvarar nivåindex 0–10 i data/levels.ts
 * (radie och poäng ägs av levels.ts, färg/ansikte/dekor ägs här).
 *
 * Allt ritas med Phaser.Graphics-primitiver: cirkel, båge, linje, triangel.
 * Inga bildfiler. Ljud genereras med Web Audio. Ikoner är SVG-strängar i ui/icons.ts.
 */

import type { LocalizedName } from '../systems/i18n'

/** Ansiktsuttryck – ett unikt per nivå, så färg aldrig är enda informationsbäraren. */
export type Face =
  | 'dot' // två små prickar, ingen mun
  | 'smile' // två prickar + mjuk leendebåge
  | 'wink' // ett streck-öga, en prick, kort leende
  | 'open' // två prickar + rund öppen mun
  | 'grin' // brett fyllt leende med tunga
  | 'sleepy' // två nedåtbågar (halvslutna ögon) + kort rak mun
  | 'starry' // fyrstråliga stjärnögon + brett leende
  | 'awe' // ringögon (cirkel + pupill) + liten oval mun
  | 'cool' // en lång visirlinje som ögon + snett leende
  | 'happy' // två uppåtbågar (^^) + liten mun
  | 'joy' // uppåtbågar + bred öppen mun + kinder
  | 'angry' // två sneda streck + vågig mun (bomben)

/** Dekor utöver ansikte. Ritas med samma primitiver. */
export type Deco =
  | 'none'
  | 'antenna' // ett böjt spröt uppåt med kula i toppen
  | 'tuft' // tre korta streck som en tofs i toppen
  | 'tentacles' // tre små bågar längs nederkanten
  | 'fins' // två triangelfenor i sidled
  | 'crown' // tre taggar i en båge över hjässan
  | 'spikes' // 12 taggar runt om (bomben)
  | 'bands' // roterande färgband (regnbågen)

export interface LevelSkin {
  /** Nivåindex 0–10, samma som levels.ts */
  readonly id: number
  /** Namn { en, sv }, visas inte i UI:t i v1 (DESIGN §15) */
  readonly name: LocalizedName
  /** Kroppens fyllning */
  readonly color: string
  /** Mörk kontur + dekorfärg, samma kulör som color men mörk */
  readonly color2: string
  readonly face: Face
  /** Inre ring innanför konturen */
  readonly ring?: boolean
  /** Antal små prickar utspridda på kroppen */
  readonly spots?: number
  readonly deco?: Deco
  /** Glödradie i andel av kroppsradien (yttre mjuk halo) */
  readonly glow: number
}

export const THEME = {
  name: { en: 'The Glimmers', sv: 'Glimtarna' },
  /** Kort designidé, för den som läser koden först */
  idea:
    'Lysande djuphavsvarelser i en glasburk. Mörkt hav bakom, burken är det enda ljusa rummet. ' +
    'Kulörresa i tre akter: kalla (0–2), varma (3–5), elektriska (6–9), guld (10).',

  palette: {
    bg: '#0B1020', // djuphavsnatt, hela skärmen
    bgDeep: '#060A14', // vinjett i hörnen, botten av burken
    bgGlow: '#132043', // mjuk radial bakom burken
    jarGlass: '#16223C', // burkens innerfält
    jarWall: '#2B3B5E', // väggfyllning
    jarEdge: '#6E8CC4', // glaskant, 3 px
    jarShine: '#AFC8FF', // diagonal reflex, alpha 0.14
    floor: '#1E2B49', // burkens botten
    danger: '#FFB43A', // farolinje (bärnsten, aldrig mättad röd)
    dangerHot: '#FFF1CF', // farolinjens pulstopp
    hud: '#EAF2FF', // poäng och HUD-text
    hudDim: '#8FA3C8', // sekundär HUD
    accent: '#7CF9FF', // interaktiva element, siktlinje
    accent2: '#FF5FA2', // specialobjekt, gnistor
    gold: '#FFD75E', // rekord, hylla, nivå 10
    ink: '#14202E', // ansikten och konturer ovanpå ljusa kroppar
    shadow: '#000000', // alpha 0.35
    scrim: '#0B1020', // förlust-overlay, alpha 0.82
  },

  type: {
    /** Systemtypsnitt, inga filer att ladda */
    family:
      "system-ui, -apple-system, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif",
    weightHeavy: '800',
    weightBold: '700',
    /** Storlekar i logiska px (ytan 360×640) */
    logo: 64,
    scoreBig: 64, // förlustskärmens poäng
    score: 34, // HUD under spel
    sub: 24, // highscore på förlustskärmen
    hudSmall: 16, // highscore-markör i HUD
    pop: 20, // scorepop
    letterSpacingLogo: 8,
    /** Siffror är tabulära: rita alltid med fast teckenbredd-offset så HUD inte hoppar */
    tabularNumbers: true,
  },

  space: { xs: 4, s: 8, m: 12, l: 16, xl: 24, xxl: 32 },

  touch: {
    /** Logiska px. 72 logiska px ⇒ ≥64 dp även på 320 dp-skärmar. */
    minLogical: 72,
    minDp: 64,
    /** Osynlig extra marginal runt varje ikon */
    slop: 8,
  },

  /** Logisk spelyta och burkens geometri (referens, fysiken ägs av scenen) */
  layout: {
    width: 360,
    height: 640,
    jar: {
      innerLeft: 20,
      innerRight: 340,
      innerWidth: 320,
      wallThickness: 20,
      floorY: 600,
      topY: 24,
      cornerRadius: 18,
    },
    dangerLineY: 110,
    dropLineY: 64,
    hud: { scoreX: 16, scoreY: 18, recordX: 16, recordY: 56 },
    preview: { cx: 302, cy: 44, boxW: 72, boxH: 72 },
    safeTop: 16,
    safeBottom: 24,
  },

  levels: [
    { id: 0, name: { en: 'Speck', sv: 'Gnutt' }, color: '#7CF9FF', color2: '#0B4A57', face: 'dot', glow: 0.55 },
    { id: 1, name: { en: 'Blip', sv: 'Blipp' }, color: '#4FE0B0', color2: '#064032', face: 'smile', deco: 'antenna', glow: 0.5 },
    { id: 2, name: { en: 'Sprout', sv: 'Grodd' }, color: '#B9F05A', color2: '#2D4A0B', face: 'wink', spots: 3, glow: 0.45 },
    { id: 3, name: { en: 'Ping', sv: 'Pling' }, color: '#FFD447', color2: '#5A3D00', face: 'open', ring: true, glow: 0.42 },
    { id: 4, name: { en: 'Squiggle', sv: 'Knorr' }, color: '#FF9F3C', color2: '#5C2A00', face: 'grin', deco: 'tentacles', glow: 0.4 },
    { id: 5, name: { en: 'Blot', sv: 'Kludd' }, color: '#FF6B6B', color2: '#59161B', face: 'sleepy', spots: 5, glow: 0.38 },
    { id: 6, name: { en: 'Bubble', sv: 'Bubbel' }, color: '#FF5FA2', color2: '#55103A', face: 'starry', deco: 'tuft', glow: 0.36 },
    { id: 7, name: { en: 'Dream', sv: 'Drömmen' }, color: '#C77DFF', color2: '#2F1056', face: 'awe', ring: true, spots: 2, glow: 0.34 },
    { id: 8, name: { en: 'Wave', sv: 'Vågen' }, color: '#6C8BFF', color2: '#14235A', face: 'cool', deco: 'fins', glow: 0.32 },
    { id: 9, name: { en: 'Pearl', sv: 'Pärlan' }, color: '#E8F1FF', color2: '#3A4A6B', face: 'happy', ring: true, spots: 4, glow: 0.3 },
    { id: 10, name: { en: 'Klunk', sv: 'Klunken' }, color: '#FFD75E', color2: '#6B4300', face: 'joy', ring: true, deco: 'crown', glow: 0.28 },
  ] as const satisfies readonly LevelSkin[],

  special: {
    bomb: {
      name: { en: 'Bomb', sv: 'Bomben' },
      color: '#2A3350',
      color2: '#FF5FA2',
      core: '#FFF1CF', // vitglödande kärna, alpha-puls
      face: 'angry',
      deco: 'spikes',
      spikes: 12,
      spikeLen: 0.34, // andel av radien
      glow: 0.6,
      /** Silhuetten roterar långsamt, ingen blinkning */
      spinDegPerSec: 8,
      /** Skalpuls, halvcykel i ms ⇒ 0,96 cykler/s */
      pulseMs: 520,
      pulseScale: 1.08,
    },
    rainbow: {
      name: { en: 'Rainbow', sv: 'Regnbågen' },
      color: '#FFFFFF',
      color2: '#14202E',
      face: 'joy',
      deco: 'bands',
      /** Sex band ritas som fyllda bågar, 60° var, hela skivan roterar */
      bands: ['#FF6B6B', '#FF9F3C', '#FFD447', '#4FE0B0', '#7CF9FF', '#C77DFF'],
      bandSpinDegPerSec: 150, // ett varv / 2,4 s
      glow: 0.7,
      pulseMs: 640,
      pulseScale: 1.05,
    },
  },

  anim: {
    /** Förhandsvisning glider in i drop-läget efter en drop */
    queueSlide: { ease: 'Back.easeOut', durationMs: 220 },
    /** Objektet följer fingret i sidled */
    aim: { ease: 'Sine.easeOut', durationMs: 90 },
    /** Släpp: objektet krymper lite och "spottas" nedåt innan fysiken tar över */
    drop: { ease: 'Quad.easeIn', durationMs: 90, scaleFrom: 1, scaleTo: 0.92 },
    /** Landning: kroppen plattas till och studsar tillbaka */
    landSquash: { ease: 'Back.easeOut', durationMs: 180, squashY: 0.86 },
    /** Scale-punch på det nya objektet vid merge. peak skalas av juice-intensitet. */
    mergePunch: { ease: 'Back.easeOut', durationMs: 220, from: 1, peak: 1.35, overshoot: 2.2 },
    /** Grannarna knuffas visuellt (utöver fysikimpulsen) */
    neighborNudge: { ease: 'Sine.easeOut', durationMs: 160 },
    /** Poängsiffran flyger till HUD */
    scorePop: { ease: 'Cubic.easeIn', durationMs: 500, riseMs: 120, fadeMs: 140, risePx: 18 },
    /** Dämpad screen shake: amplitud × e^(-t/tau) × sin(2π·f·t) */
    shake: { ease: 'Sine.easeOut', durationMs: 300, freqHz: 28, maxPx: 8, tauMs: 90 },
    /** Hit-stop */
    hitStop: { maxMs: 100, minIntensity: 0.3, maxFrames: 6 },
    /** Slow-mo vid fara */
    slowmoIn: { ease: 'Quart.easeOut', durationMs: 260, timeScale: 0.6 },
    slowmoOut: { ease: 'Quart.easeIn', durationMs: 420, timeScale: 1 },
    /** Knapptryck */
    buttonPress: { ease: 'Quad.easeOut', durationMs: 80, scale: 0.92 },
    buttonRelease: { ease: 'Back.easeOut', durationMs: 160, scale: 1 },
    /** Kamerazoom, endast chain och special */
    zoom: { ease: 'Sine.easeInOut', durationMs: 400, peak: 1.06 },
    /** Loopande pulser. durationMs = halvcykel med yoyo ⇒ frekvens = 500/durationMs Hz. */
    previewPulse: { ease: 'Sine.easeInOut', durationMs: 520, yoyo: true, scale: 1.08 },
    dangerPulse: { ease: 'Sine.easeInOut', durationMs: 500, yoyo: true, alphaFrom: 0.55, alphaTo: 1 },
    recordPulse: { ease: 'Sine.easeInOut', durationMs: 700, yoyo: true, scale: 1.12 },
    nearMiss: { ease: 'Sine.easeInOut', durationMs: 600, yoyo: true, scale: 1.03 },
    /** Onboarding-handen: hela gesten på en loop */
    handLoop: { durationMs: 2200, ease: 'Sine.easeInOut' },
    /** Förlust-overlay och omstart */
    overlayIn: { ease: 'Quad.easeOut', durationMs: 260 },
    restart: { ease: 'Quad.easeIn', durationMs: 180 },
  },

  /**
   * Ljudkarta. Allt genereras med oscillator + gain-envelope i Web Audio.
   * attack/decay i sekunder. gain är toppvolym före mastergain.
   * glideTo = frekvens i slutet av decay (portamento), utelämnas = konstant.
   */
  sound: {
    master: { gain: 0.5, calmGain: 0.3, limiterThreshold: -6 },
    drop: { wave: 'triangle', baseHz: 240, glideTo: 180, attack: 0.002, decay: 0.09, gain: 0.25 },
    land: { wave: 'sine', baseHz: 180, glideTo: 90, attack: 0.001, decay: 0.14, gain: 0.35, lowpassHz: 900 },
    merge: {
      wave: 'triangle',
      baseHz: 392, // G4
      attack: 0.004,
      decay: 0.18,
      gain: 0.4,
      /** Pitch = baseHz × 2^(combo/12), combo kapas vid 12 (en oktav) */
      semitonePerCombo: 1,
      comboCap: 12,
      /** Andra oscillatorn en kvint upp ger "klunk-pling" i stället för ren ton */
      harmonicSemitones: 7,
      harmonicGain: 0.4,
    },
    chain: {
      wave: 'square',
      baseHz: 523, // C5
      attack: 0.003,
      decay: 0.16,
      gain: 0.3,
      lowpassHz: 2600,
      /** Arpeggio uppåt, halvtoner från baseHz, ett steg var stepMs */
      steps: [0, 4, 7, 12],
      stepMs: 70,
    },
    special: {
      wave: 'sine',
      baseHz: 440,
      glideTo: 1760,
      attack: 0.01,
      decay: 0.5,
      gain: 0.35,
      vibratoHz: 6,
      vibratoCents: 35,
    },
    bomb: {
      wave: 'noise',
      baseHz: 60, // sub-sinus som läggs under bruset
      attack: 0.001,
      decay: 0.45,
      gain: 0.5,
      /** Lågpass sveper nedåt = "whump" i stället för vitt brusfräs */
      filterFromHz: 3200,
      filterToHz: 200,
    },
    danger: {
      wave: 'sawtooth',
      baseHz: 55,
      attack: 0.25,
      decay: 0.6,
      gain: 0.12,
      lowpassHz: 300,
      tremoloHz: 4,
      /** Loopar så länge faran pågår */
      sustain: true,
    },
    loss: { wave: 'triangle', baseHz: 330, glideTo: 110, attack: 0.01, decay: 0.9, gain: 0.4 },
    newRecord: {
      wave: 'triangle',
      baseHz: 659, // E5
      attack: 0.004,
      decay: 0.28,
      gain: 0.45,
      steps: [0, 5, 9],
      stepMs: 110,
      harmonicSemitones: 12,
      harmonicGain: 0.25,
    },
    /** Rekordjakt: diskret puls när poängen är ≥90 % av highscore */
    record: { wave: 'sine', baseHz: 1568, attack: 0.002, decay: 0.07, gain: 0.14 },
    /** Alla UI-tryck */
    ui: { wave: 'sine', baseHz: 880, glideTo: 1200, attack: 0.001, decay: 0.05, gain: 0.2 },
  },

  /** Haptik i ms, trösklar på juice-intensitet */
  haptics: { light: 10, medium: 30, heavy: 60, mediumAt: 0.3, heavyAt: 0.7 },

  /** Tillgänglighet */
  a11y: {
    /** Max ljusstyrkeväxlingar per sekund för ett enskilt element (WCAG 2.3.1) */
    maxFlashesPerSec: 3,
    /** Vitblixtar per sekund */
    maxWhiteFlashPerSec: 2,
    /** Mättad röd får aldrig blinka. Farolinjen är bärnsten + streckmönster. */
    forbidRedStrobe: true,
    /** Lugnt läge */
    calm: { intensityScale: 0.5, shake: false, zoom: false, hitStop: true, slowmo: true },
    /** Minsta kontrast mot bakgrund för HUD och objektkroppar */
    minContrastRatio: 4.5,
  },
} as const

export type Theme = typeof THEME
export type ThemePalette = Theme['palette']
export type ThemeAnim = Theme['anim']
export type ThemeSound = Theme['sound']

export default THEME

/* ------------------------------------------------------------------ *
 * Phaser-brygga. Ingen Phaser-import – bara tal i stället för strängar.
 * Ersätter `theme.fallback.ts` rakt av (COLORS, EYE_COLOR, ... ).
 * ------------------------------------------------------------------ */

/** '#7CF9FF' -> 0x7CF9FF */
export const hexToInt = (hex: string): number => parseInt(hex.slice(1), 16)

/** Kroppsfärger per nivå 0–10, som Phaser-tal. */
export const LEVEL_COLORS: readonly number[] = THEME.levels.map((l) => hexToInt(l.color))
/** Konturfärger per nivå 0–10, som Phaser-tal. */
export const LEVEL_COLORS2: readonly number[] = THEME.levels.map((l) => hexToInt(l.color2))

/** Hela paletten som Phaser-tal. Textfärger används som strängar direkt ur THEME.palette. */
export const INT = {
  bg: hexToInt(THEME.palette.bg),
  bgDeep: hexToInt(THEME.palette.bgDeep),
  bgGlow: hexToInt(THEME.palette.bgGlow),
  jarGlass: hexToInt(THEME.palette.jarGlass),
  jarWall: hexToInt(THEME.palette.jarWall),
  jarEdge: hexToInt(THEME.palette.jarEdge),
  jarShine: hexToInt(THEME.palette.jarShine),
  floor: hexToInt(THEME.palette.floor),
  danger: hexToInt(THEME.palette.danger),
  dangerHot: hexToInt(THEME.palette.dangerHot),
  hud: hexToInt(THEME.palette.hud),
  hudDim: hexToInt(THEME.palette.hudDim),
  accent: hexToInt(THEME.palette.accent),
  accent2: hexToInt(THEME.palette.accent2),
  gold: hexToInt(THEME.palette.gold),
  ink: hexToInt(THEME.palette.ink),
  scrim: hexToInt(THEME.palette.scrim),
} as const

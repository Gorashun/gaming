/**
 * themes.ts – temaset för meta-lagret v1.1 (DESIGN §13.3, UI.md §12).
 *
 * Ren data. Får INTE importera Phaser. Index 0 = Glimtarna (återanvänder THEME.levels).
 * Regler som gäller alla set:
 *  - Ansiktet per nivå är IDENTISKT med Glimtarna (kopieras ur THEME.levels via `skin()`).
 *  - Nivå 10 har alltid krona och ring (universell "toppen"-signal).
 *  - Interaktionsfärger (accent, danger, hud, gold, ink) byts aldrig – bara burk och bakgrund.
 *  - Kroppens relativa luminans ≥ 0,24 ⇒ ansiktet (ink) har ≥ 4,5:1 mot kroppen.
 *    Kontroll: `node` + skriptet i UI.md §12.9 (tester kan göra samma sak).
 */
import { THEME, type Deco, type LevelSkin } from './theme'
import type { LocalizedName } from '../systems/i18n'

// ---------------------------------------------------------------- typer

/** Nya dekorer utöver theme.ts. Geometri i `SET_DECO_GEOM` (enheter i r). */
export type NewDeco = 'orbit' | 'moon' | 'shards' | 'icicles' | 'wrapper' | 'stick' | 'flames'
export type SetDeco = Deco | NewDeco

/** Hur `spots` ritas. 'dot' = dagens recept (UI.md §3.1 steg 5). */
export type SpotStyle = 'dot' | 'crater' | 'flake' | 'sprinkle' | 'crack'

export type ParticleShape = 'dot' | 'ring' | 'shard' | 'bubble' | 'star'

export type Wave = 'sine' | 'triangle' | 'square' | 'sawtooth'

export interface SetLevelSkin extends Omit<LevelSkin, 'deco'> {
  readonly deco?: SetDeco
}

/** Exakt 11 nivåer, index = nivå. */
export type Levels11 = readonly [
  SetLevelSkin, SetLevelSkin, SetLevelSkin, SetLevelSkin, SetLevelSkin, SetLevelSkin,
  SetLevelSkin, SetLevelSkin, SetLevelSkin, SetLevelSkin, SetLevelSkin,
]

/** Det ett set får byta i paletten. Allt annat läses ur THEME.palette. */
export interface SetPalette {
  readonly bg: string
  readonly bgDeep: string
  readonly bgGlow: string
  readonly jarGlass: string
  readonly jarWall: string
  readonly jarEdge: string
  readonly jarShine: string
  readonly floor: string
}

/** Ett oscillatorlager. Första lagret är grundtonen. */
export interface SoundLayer {
  readonly wave: Wave
  /** Transponering mot merge-tonen (392 Hz · 2^(combo/12)). */
  readonly semitones: number
  readonly detuneCents?: number
  /** Relativ volym i lagret, 0..1 */
  readonly gain: number
}

/**
 * Klangfärg för merge-ljudet. Pitch-logiken (bas 392 Hz, +1 halvton per combo, tak 12)
 * är oförändrad – bara klangen byts. Kedja: lager → (lågpass) → envelope → master.
 */
export interface SetSound {
  readonly layers: readonly SoundLayer[]
  /** Toppvolym före master. Normaliserad så att seten låter lika starka. */
  readonly gain: number
  readonly attack: number
  readonly decay: number
  readonly lowpassHz?: number
  readonly lowpassQ?: number
  /** Lågpassets frekvens i slutet av decay (filtersvep). Utelämnad = konstant. */
  readonly lowpassToHz?: number
  /** Tonen börjar så här många halvtoner under och glider upp på bendMs ("blopp"). */
  readonly bendSemitones?: number
  readonly bendMs?: number
  readonly vibratoHz?: number
  readonly vibratoCents?: number
  /** Kort brusklick ovanpå (knaster). */
  readonly noise?: { readonly gain: number; readonly decay: number; readonly lowpassHz: number }
  /** En mening: hur det ska låta. */
  readonly timbre: string
}

export interface SetParticles {
  readonly shape: ParticleShape
  /** × antalet ur JUICE.particles (6 + 24·i, tak 40 gäller fortfarande). */
  readonly countScale: number
  /** × JUICE.particles.speedMin/Max */
  readonly speedScale: number
  readonly lifespanMs: number
  /** px/s², positivt = nedåt */
  readonly gravityY: number
  readonly spinDegPerSec: number
  readonly scale: { readonly start: number; readonly end: number }
  readonly alpha: { readonly start: number; readonly end: number }
  readonly blend: 'ADD' | 'NORMAL'
  /** 'level' = nivåns color. 'levelLight' = varannan partikel i hud-vit. */
  readonly tint: 'level' | 'levelLight'
  /** Andra partikeltyp i samma utbrott. share = andel av antalet. */
  readonly mix?: {
    readonly shape: ParticleShape
    readonly share: number
    readonly gravityY: number
    readonly tint: string
  }
}

type P2 = readonly [number, number]

/** Bakgrundsprimitiv i logiska px (360×640). Ritas EN gång till en RenderTexture. */
export type BackdropOp =
  | { readonly op: 'circle'; readonly x: number; readonly y: number; readonly r: number; readonly color: string; readonly alpha: number; readonly stroke?: number }
  | { readonly op: 'ellipse'; readonly x: number; readonly y: number; readonly w: number; readonly h: number; readonly color: string; readonly alpha: number; readonly stroke?: number }
  | { readonly op: 'poly'; readonly pts: readonly P2[]; readonly color: string; readonly alpha: number }
  | { readonly op: 'curve'; readonly from: P2; readonly ctrl: P2; readonly to: P2; readonly width: number; readonly color: string; readonly alpha: number }
  | { readonly op: 'line'; readonly from: P2; readonly to: P2; readonly width: number; readonly color: string; readonly alpha: number }
  | {
      /** Seedad spridning (mulberry32) av prickar/ringar. stroke ⇒ ringar i stället för fyllda. */
      readonly op: 'scatter'
      readonly seed: number
      readonly count: number
      readonly x: number
      readonly y: number
      readonly w: number
      readonly h: number
      readonly rMin: number
      readonly rMax: number
      readonly color: string
      readonly alphaMin: number
      readonly alphaMax: number
      readonly stroke?: number
      /** Rörelse: px/s (negativt = uppåt), wrap i y. Då ritas lagret som eget objekt, inte i RT. */
      readonly vy?: number
      /** Sidvaggning, amplitud px och Hz (≤0,5 Hz). */
      readonly swayPx?: number
      readonly swayHz?: number
    }

export interface SetBackdrop {
  readonly idea: string
  readonly ops: readonly BackdropOp[]
}

export interface ThemeSet {
  readonly id: string
  /** Namn { en, sv }, visas inte i UI:t i v1 (DESIGN §15) */
  readonly name: LocalizedName
  /** En mening: varför setet känns annorlunda */
  readonly idea: string
  /** Setets signaturfärg: ikon, sidindikator, partiklar i rundavslut */
  readonly signature: string
  readonly levels: Levels11
  readonly spotStyle: SpotStyle
  /** Utelämnad = THEME.palette */
  readonly palette?: SetPalette
  readonly sound: SetSound
  readonly particle: SetParticles
  readonly backdrop: SetBackdrop
  /** SVG 64×64 viewBox, visas 48 px i 72 px träffyta (UI.md §12.7) */
  readonly icon: string
}

// ---------------------------------------------------------------- hjälp

/** Bygger en nivå. Ansiktet kopieras ALLTID ur Glimtarna. */
function skin(
  id: number,
  name: LocalizedName,
  color: string,
  color2: string,
  glow: number,
  extra: { deco?: SetDeco; ring?: boolean; spots?: number } = {},
): SetLevelSkin {
  return { id, name, color, color2, face: THEME.levels[id].face, glow, ...extra }
}

// ---------------------------------------------------------------- dekorgeometri

/**
 * Nya dekorer som data, enheter i r, origo i kroppens centrum (y nedåt).
 * Ritas med samma tvåpass som §3.1 steg 7: mörk understroke i color2 (bredd lw + max(2,5; 0,09r)),
 * sedan fyllning/överstroke i color (bredd lw = max(2; widthR·r)).
 *  - back: ritas FÖRE kroppen (steg 1,5), resten efter (steg 7).
 */
export interface DecoGeom {
  /** Hur långt utanför kroppen dekoren når, i r (för texturens pad) */
  readonly extent: number
  readonly tris?: readonly (readonly P2[])[]
  readonly strokes?: readonly (readonly P2[])[]
  readonly back?: readonly (readonly P2[])[]
  readonly dots?: readonly { readonly x: number; readonly y: number; readonly r: number }[]
  /** Linjebredd i r (default 0,07) */
  readonly widthR?: number
}

/** Tagg ut från kroppen. a = vinkel från rakt upp (medurs), base = avstånd till basen, tip = spetsens avstånd. */
function spike(a: number, base: number, tip: number, half: number, lean = 0): P2[] {
  const ux = Math.sin(a)
  const uy = -Math.cos(a)
  const tx = Math.cos(a)
  const ty = Math.sin(a)
  return [
    [ux * base - tx * half, uy * base - ty * half],
    [ux * tip + tx * lean, uy * tip + ty * lean],
    [ux * base + tx * half, uy * base + ty * half],
  ]
}

/** Lutad ellips som polylinje, t0→t1 i radianer (0 = höger, π/2 = nedåt). */
function ellipseArc(cx: number, cy: number, rx: number, ry: number, tilt: number, t0: number, t1: number, n = 24): P2[] {
  const out: P2[] = []
  const c = Math.cos(tilt)
  const s = Math.sin(tilt)
  for (let i = 0; i <= n; i++) {
    const t = t0 + ((t1 - t0) * i) / n
    const x = Math.cos(t) * rx
    const y = Math.sin(t) * ry
    out.push([cx + x * c - y * s, cy + x * s + y * c])
  }
  return out
}

export const SET_DECO_GEOM: Readonly<Record<NewDeco, DecoGeom>> = {
  /** Saturnusring. Främre halvan passerar under munnen (y ≥ 0,54r vid kroppskanten). */
  orbit: {
    extent: 1.46,
    back: [ellipseArc(0, 0.3, 1.42, 0.34, -0.16, Math.PI, 2 * Math.PI)],
    strokes: [ellipseArc(0, 0.3, 1.42, 0.34, -0.16, 0, Math.PI)],
    widthR: 0.08,
  },
  /** Liten måne snett ovanför + en ännu mindre. */
  moon: {
    extent: 1.5,
    dots: [
      { x: 0.92, y: -0.9, r: 0.2 },
      { x: -1.08, y: -0.5, r: 0.1 },
    ],
  },
  /** Tre iskristaller på hjässan, olika längd. */
  shards: {
    extent: 1.48,
    tris: [spike(-0.42, 0.9, 1.3, 0.1), spike(0, 0.9, 1.46, 0.11), spike(0.38, 0.9, 1.34, 0.1)],
  },
  /** Tre istappar under. */
  icicles: {
    extent: 1.38,
    tris: [spike(Math.PI - 0.45, 0.92, 1.28, 0.09), spike(Math.PI - 0.08, 0.92, 1.36, 0.1), spike(Math.PI + 0.32, 0.92, 1.24, 0.09)],
  },
  /** Karamellpapper: två fliksnurrar i sidled. */
  wrapper: {
    extent: 1.44,
    tris: [
      [[-0.9, 0], [-1.42, -0.38], [-1.42, 0.38]],
      [[0.9, 0], [1.42, -0.38], [1.42, 0.38]],
    ],
  },
  /** Klubbpinne rakt ned. */
  stick: {
    extent: 1.5,
    strokes: [[[0, 0.96], [0, 1.48]]],
    widthR: 0.16,
  },
  /** Tre lågor som lutar åt samma håll. */
  flames: {
    extent: 1.46,
    tris: [spike(-0.46, 0.88, 1.28, 0.16, 0.12), spike(0, 0.88, 1.44, 0.18, 0.14), spike(0.46, 0.88, 1.3, 0.16, 0.12)],
  },
}

// ---------------------------------------------------------------- set 0: Glimtarna

const GLIMTARNA: ThemeSet = {
  id: 'glimtarna',
  name: { en: 'The Glimmers', sv: 'Glimtarna' },
  idea: 'Lysande djuphavsvarelser: neon mot svart hav, mjuk glöd – basen alla andra set jämförs med.',
  signature: '#7CF9FF',
  levels: THEME.levels,
  spotStyle: 'dot',
  sound: {
    layers: [
      { wave: 'triangle', semitones: 0, gain: 1 },
      { wave: 'triangle', semitones: 7, gain: 0.4 },
    ],
    gain: 0.4,
    attack: 0.004,
    decay: 0.18,
    timbre: 'Rent "pling" med kvint – som idag (UI.md §8).',
  },
  particle: {
    shape: 'dot',
    countScale: 1,
    speedScale: 1,
    lifespanMs: 520,
    gravityY: 0,
    spinDegPerSec: 0,
    scale: { start: 0.9, end: 0 },
    alpha: { start: 1, end: 0 },
    blend: 'ADD',
    tint: 'level',
  },
  backdrop: {
    idea: 'Oförändrad: gradient bg→bgDeep + radial bgGlow (UI.md §7.1). Inga extra primitiver.',
    ops: [],
  },
  icon:
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">' +
    '<path d="M20 40 q-4 8 1 16 M32 40 q-4 8 1 16 M44 40 q-4 8 1 16" fill="none" stroke="#0B4A57" stroke-width="9" stroke-linecap="round"/>' +
    '<path d="M20 40 q-4 8 1 16 M32 40 q-4 8 1 16 M44 40 q-4 8 1 16" fill="none" stroke="#7CF9FF" stroke-width="5" stroke-linecap="round"/>' +
    '<path d="M10 38 A22 22 0 0 1 54 38 Z" fill="#7CF9FF" stroke="#0B4A57" stroke-width="4" stroke-linejoin="round"/>' +
    '<circle cx="24" cy="29" r="3.5" fill="#14202E"/><circle cx="40" cy="29" r="3.5" fill="#14202E"/></svg>',
}

// ---------------------------------------------------------------- set 1: Planeterna (rymd)

const PLANETERNA: ThemeSet = {
  id: 'planeterna',
  name: { en: 'The Planets', sv: 'Planeterna' },
  idea: 'Små matta planeter och månar i ett violett stjärnmörker: dammiga pastellkulörer, kratrar och ringar i stället för neon – lugnt och svävande.',
  signature: '#E8C45C',
  levels: [
    skin(0, { en: 'Stardust', sv: 'Stoftet' }, '#D9D4F0', '#2E2A4F', 0.2, { spots: 2 }),
    skin(1, { en: 'Comet', sv: 'Kometen' }, '#8FE8DC', '#0E4A44', 0.2, { deco: 'moon' }),
    skin(2, { en: 'Sand', sv: 'Sanden' }, '#E8DA8A', '#5A3E12', 0.18, { spots: 3 }),
    skin(3, { en: 'Peach', sv: 'Persikan' }, '#F7A08C', '#5C2A16', 0.18, { ring: true }),
    skin(4, { en: 'Nebula', sv: 'Nebulosan' }, '#C4A6F5', '#33195C', 0.18, { deco: 'antenna' }),
    skin(5, { en: 'Ice Giant', sv: 'Isjätten' }, '#80C8F5', '#0F3A5C', 0.16, { spots: 4 }),
    skin(6, { en: 'Saturn', sv: 'Saturnus' }, '#E8C45C', '#4F3A06', 0.16, { deco: 'orbit' }),
    skin(7, { en: 'Greenie', sv: 'Grönisen' }, '#A3E89C', '#1E4A18', 0.16, { ring: true, spots: 2 }),
    skin(8, { en: 'Rocket', sv: 'Raketen' }, '#F59CC8', '#5A1638', 0.16, { deco: 'fins' }),
    skin(9, { en: 'White Star', sv: 'Vitstjärnan' }, '#C4E0FF', '#2A3F5E', 0.2, { ring: true, spots: 3 }),
    skin(10, { en: 'Sun', sv: 'Solen' }, '#FFD36B', '#6B4300', 0.3, { ring: true, deco: 'crown' }),
  ],
  spotStyle: 'crater',
  palette: {
    bg: '#0E0B1F',
    bgDeep: '#070512',
    bgGlow: '#211A46',
    jarGlass: '#1A1735',
    jarWall: '#2F2A58',
    jarEdge: '#8C82D6',
    jarShine: '#D2C8FF',
    floor: '#231E45',
  },
  sound: {
    layers: [
      { wave: 'sine', semitones: 0, gain: 1 },
      { wave: 'sine', semitones: 0, detuneCents: 9, gain: 0.7 },
      { wave: 'sine', semitones: 12, gain: 0.18 },
    ],
    gain: 0.36,
    attack: 0.008,
    decay: 0.3,
    lowpassHz: 2400,
    vibratoHz: 5,
    vibratoCents: 10,
    timbre: 'Mjukt svävande "uuu-blopp": två sinus med 9 cent chorus, längre svans.',
  },
  particle: {
    shape: 'star',
    countScale: 0.8,
    speedScale: 0.8,
    lifespanMs: 700,
    gravityY: 0,
    spinDegPerSec: 180,
    scale: { start: 1, end: 0 },
    alpha: { start: 1, end: 0.2 },
    blend: 'ADD',
    tint: 'levelLight',
  },
  backdrop: {
    idea: 'Stilla stjärnfält + en stor ringplanet som sjunker in bakom burkens botten.',
    ops: [
      { op: 'circle', x: -30, y: 640, r: 170, color: '#1B1640', alpha: 1 },
      { op: 'ellipse', x: -20, y: 610, w: 460, h: 72, color: '#2F2A58', alpha: 0.9, stroke: 6 },
      { op: 'circle', x: 300, y: 170, r: 22, color: '#1F1A42', alpha: 1 },
      { op: 'scatter', seed: 7, count: 46, x: 0, y: 0, w: 360, h: 600, rMin: 0.8, rMax: 1.8, color: '#D2C8FF', alphaMin: 0.2, alphaMax: 0.6 },
    ],
  },
  icon:
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">' +
    '<ellipse cx="32" cy="34" rx="28" ry="9" transform="rotate(-18 32 34)" fill="none" stroke="#D9D4F0" stroke-width="5"/>' +
    '<circle cx="32" cy="32" r="17" fill="#E8C45C" stroke="#4F3A06" stroke-width="4"/>' +
    '<path d="M4 34 A28 9 0 0 0 60 34" transform="rotate(-18 32 34)" fill="none" stroke="#D9D4F0" stroke-width="5" stroke-linecap="round"/>' +
    '<circle cx="54" cy="10" r="3" fill="#D9D4F0"/></svg>',
}

// ---------------------------------------------------------------- set 2: Frostisarna (is + norrsken)

const FROSTISARNA: ThemeSet = {
  id: 'frostisarna',
  name: { en: 'The Frosties', sv: 'Frostisarna' },
  idea: 'Iskristaller under norrsken: nästan vita pastelltoner med skarpa mörkblå konturer och istaggar – kallt, krispigt, klingar som glas.',
  signature: '#BFEFFF',
  levels: [
    skin(0, { en: 'Flake', sv: 'Flingan' }, '#E3F6FF', '#1F4660', 0.5),
    skin(1, { en: 'Crystal', sv: 'Kristallen' }, '#9DEFE6', '#0C4A45', 0.46, { deco: 'shards' }),
    skin(2, { en: 'Frost Sprout', sv: 'Frostgrodd' }, '#BDF2A6', '#25501A', 0.44, { spots: 3 }),
    skin(3, { en: 'Winter Sun', sv: 'Vintersol' }, '#FFF0A6', '#5A4A0C', 0.42, { ring: true }),
    skin(4, { en: 'Icicle', sv: 'Istappen' }, '#FFCBAA', '#5C2E14', 0.4, { deco: 'icicles' }),
    skin(5, { en: 'Alpenglow', sv: 'Alpglöd' }, '#FFBBDA', '#5A1E3C', 0.38, { spots: 5 }),
    skin(6, { en: 'Aurora', sv: 'Norrskenet' }, '#DDB4FF', '#34205E', 0.36, { deco: 'shards' }),
    skin(7, { en: 'Glacier', sv: 'Glaciären' }, '#94B6FF', '#1A3263', 0.34, { ring: true, spots: 2 }),
    skin(8, { en: 'Ice Wing', sv: 'Isvingen' }, '#7FE3FF', '#0A4458', 0.34, { deco: 'fins' }),
    skin(9, { en: 'Snowball', sv: 'Snöbollen' }, '#F4F7FF', '#33415C', 0.32, { ring: true, spots: 4 }),
    skin(10, { en: 'Frost King', sv: 'Frostkungen' }, '#FFE08A', '#6B4A00', 0.32, { ring: true, deco: 'crown' }),
  ],
  spotStyle: 'flake',
  palette: {
    bg: '#081624',
    bgDeep: '#040B14',
    bgGlow: '#0F2E45',
    jarGlass: '#12263A',
    jarWall: '#23405C',
    jarEdge: '#7FB8E0',
    jarShine: '#D8F2FF',
    floor: '#16324A',
  },
  sound: {
    layers: [
      { wave: 'sine', semitones: 0, gain: 1 },
      { wave: 'sine', semitones: 24, gain: 0.22 },
      { wave: 'triangle', semitones: 31, gain: 0.08 },
    ],
    gain: 0.4,
    attack: 0.001,
    decay: 0.38,
    lowpassHz: 8000,
    timbre: 'Glasklart "ting": sinus + två höga deltoner, direkt attack, lång klang.',
  },
  particle: {
    shape: 'shard',
    countScale: 1,
    speedScale: 1.1,
    lifespanMs: 600,
    gravityY: 320,
    spinDegPerSec: 360,
    scale: { start: 1, end: 0.4 },
    alpha: { start: 1, end: 0 },
    blend: 'NORMAL',
    tint: 'levelLight',
  },
  backdrop: {
    idea: 'Tre norrskensband över burkens hals + snödrivor vid botten + långsamt snöfall (8 px/s).',
    ops: [
      { op: 'curve', from: [-20, 150], ctrl: [180, 60], to: [380, 180], width: 46, color: '#15564F', alpha: 0.35 },
      { op: 'curve', from: [-20, 200], ctrl: [160, 130], to: [380, 240], width: 30, color: '#2E2C66', alpha: 0.35 },
      { op: 'curve', from: [-20, 110], ctrl: [200, 40], to: [380, 120], width: 20, color: '#174A60', alpha: 0.3 },
      { op: 'ellipse', x: 70, y: 600, w: 200, h: 44, color: '#16324A', alpha: 1 },
      { op: 'ellipse', x: 270, y: 604, w: 240, h: 38, color: '#16324A', alpha: 1 },
      { op: 'scatter', seed: 23, count: 30, x: 0, y: 0, w: 360, h: 640, rMin: 0.8, rMax: 1.8, color: '#D8F2FF', alphaMin: 0.2, alphaMax: 0.45, vy: 8, swayPx: 6, swayHz: 0.25 },
    ],
  },
  icon:
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" fill="none" stroke-linecap="round" stroke-linejoin="round">' +
    [0, 60, 120, 180, 240, 300]
      .map(
        (a) =>
          `<g transform="rotate(${a} 32 32)"><path d="M32 32 V7 M25 13 L32 20 L39 13" stroke="#1F4660" stroke-width="9"/></g>`,
      )
      .join('') +
    [0, 60, 120, 180, 240, 300]
      .map(
        (a) =>
          `<g transform="rotate(${a} 32 32)"><path d="M32 32 V7 M25 13 L32 20 L39 13" stroke="#BFEFFF" stroke-width="5"/></g>`,
      )
      .join('') +
    '</svg>',
}

// ---------------------------------------------------------------- set 3: Godisarna (godis + läsk)

const GODISARNA: ThemeSet = {
  id: 'godisarna',
  name: { en: 'The Candies', sv: 'Godisarna' },
  idea: 'Karameller och klubbor i en plommonfärgad godisburk: mättade sockerfärger, strössel, papperssnurrar och läskbubblor – glatt, poppigt, studsigt.',
  signature: '#FF80B5',
  levels: [
    skin(0, { en: 'Bubblegum', sv: 'Tuggummit' }, '#FFB5DF', '#5C1A43', 0.24),
    skin(1, { en: 'Mint Pop', sv: 'Mintklubban' }, '#74F0C4', '#0A4A35', 0.24, { deco: 'stick' }),
    skin(2, { en: 'Lemon Drop', sv: 'Citronen' }, '#FFE35A', '#5A4700', 0.22, { spots: 4 }),
    skin(3, { en: 'Grape Toffee', sv: 'Druvkolan' }, '#B79BFF', '#2F1A66', 0.22, { deco: 'wrapper' }),
    skin(4, { en: 'Orange', sv: 'Apelsinen' }, '#FF9D5C', '#5C2800', 0.22, { ring: true }),
    skin(5, { en: 'Blue Raspberry', sv: 'Blåhallonet' }, '#6ED6FF', '#083F5C', 0.2, { spots: 5 }),
    skin(6, { en: 'Strawberry', sv: 'Jordgubben' }, '#FF80B5', '#5A0F37', 0.2, { deco: 'wrapper' }),
    skin(7, { en: 'Sour Apple', sv: 'Suräpplet' }, '#C3EE68', '#37500A', 0.2, { deco: 'stick' }),
    skin(8, { en: 'Blueberry', sv: 'Blåbäret' }, '#A2B5FF', '#1C2A6B', 0.2, { ring: true, spots: 3 }),
    skin(9, { en: 'Marshmallow', sv: 'Marshmallow' }, '#FFF0D8', '#5C4526', 0.22, { ring: true, spots: 5 }),
    skin(10, { en: 'Toffee King', sv: 'Kolakungen' }, '#FFCC57', '#6B4300', 0.28, { ring: true, deco: 'crown' }),
  ],
  spotStyle: 'sprinkle',
  palette: {
    bg: '#1A0B1F',
    bgDeep: '#0E0512',
    bgGlow: '#3A1545',
    jarGlass: '#2A1433',
    jarWall: '#4A2356',
    jarEdge: '#D38AD9',
    jarShine: '#FFD1F2',
    floor: '#36193F',
  },
  sound: {
    layers: [
      { wave: 'square', semitones: 0, gain: 0.6 },
      { wave: 'triangle', semitones: 12, gain: 0.35 },
    ],
    gain: 0.3,
    attack: 0.002,
    decay: 0.12,
    lowpassHz: 1900,
    bendSemitones: -4,
    bendMs: 45,
    timbre: 'Poppigt "blopp": filtrerad fyrkant som glider upp 4 halvtoner på 45 ms, kort.',
  },
  particle: {
    shape: 'bubble',
    countScale: 0.8,
    speedScale: 0.6,
    lifespanMs: 820,
    gravityY: -120,
    spinDegPerSec: 0,
    scale: { start: 0.4, end: 1.1 },
    alpha: { start: 1, end: 0 },
    blend: 'NORMAL',
    tint: 'level',
  },
  backdrop: {
    idea: 'Diagonala godisrand-band + en stor klubbspiral nere till höger + långsamt stigande läskbubblor.',
    ops: [
      { op: 'line', from: [-60, 120], to: [200, -30], width: 26, color: '#2A1030', alpha: 1 },
      { op: 'line', from: [-60, 260], to: [360, 18], width: 26, color: '#2A1030', alpha: 1 },
      { op: 'line', from: [-60, 400], to: [420, 123], width: 26, color: '#2A1030', alpha: 1 },
      { op: 'line', from: [-60, 540], to: [420, 263], width: 26, color: '#2A1030', alpha: 1 },
      { op: 'circle', x: 300, y: 560, r: 92, color: '#3A1545', alpha: 0.8, stroke: 10 },
      { op: 'circle', x: 300, y: 560, r: 66, color: '#3A1545', alpha: 0.8, stroke: 10 },
      { op: 'circle', x: 300, y: 560, r: 40, color: '#3A1545', alpha: 0.8, stroke: 10 },
      { op: 'scatter', seed: 41, count: 18, x: 20, y: 120, w: 320, h: 480, rMin: 3, rMax: 9, color: '#FFD1F2', alphaMin: 0.12, alphaMax: 0.25, stroke: 2, vy: -12, swayPx: 4, swayHz: 0.4 },
    ],
  },
  icon:
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" stroke-linejoin="round">' +
    '<path d="M20 32 L6 19 V45 Z M44 32 L58 19 V45 Z" fill="#FFE35A" stroke="#5A4700" stroke-width="4"/>' +
    '<circle cx="32" cy="32" r="15" fill="#FF80B5" stroke="#5A0F37" stroke-width="4"/>' +
    '<path d="M24 28 q8 -6 16 0 M24 36 q8 -6 16 0" fill="none" stroke="#FFF0D8" stroke-width="3.5" stroke-linecap="round"/></svg>',
}

// ---------------------------------------------------------------- set 4: Glöden (vulkan)

const GLODEN: ThemeSet = {
  id: 'gloden',
  name: { en: 'The Embers', sv: 'Glöden' },
  idea: 'Stenar och kristaller ur en vulkan: kolsvart bakgrund med kopparglas, lågor, sprickor och glödringar – varmt, tungt, knastrande (ingen mättad röd, magma är korall/bärnsten).',
  signature: '#FFBE55',
  levels: [
    skin(0, { en: 'Ash', sv: 'Askan' }, '#D5CFE0', '#3A3348', 0.18, { spots: 2 }),
    skin(1, { en: 'Sulfur', sv: 'Svavlet' }, '#E2EE6C', '#46500A', 0.24, { deco: 'tuft' }),
    skin(2, { en: 'Patina', sv: 'Patinan' }, '#6CDEC6', '#0B4A3E', 0.22, { spots: 3 }),
    skin(3, { en: 'Ember', sv: 'Glödkolet' }, '#FFBE55', '#5C3500', 0.44, { deco: 'flames' }),
    skin(4, { en: 'Magma', sv: 'Magman' }, '#FF8766', '#5C1F0E', 0.44, { ring: true }),
    skin(5, { en: 'Rose Quartz', sv: 'Rosenkvartsen' }, '#FF9FC6', '#5A1838', 0.3, { spots: 4 }),
    skin(6, { en: 'Amethyst', sv: 'Ametisten' }, '#C69CFF', '#2F1760', 0.3, { deco: 'shards' }),
    skin(7, { en: 'Blue Flame', sv: 'Blålågan' }, '#82A9FF', '#16296B', 0.44, { deco: 'flames' }),
    skin(8, { en: 'Opal', sv: 'Opalen' }, '#B5F2D6', '#1B4A38', 0.3, { ring: true, spots: 3 }),
    skin(9, { en: 'White Heat', sv: 'Vitglöden' }, '#FFF2DC', '#5C4028', 0.5, { ring: true, spots: 4 }),
    skin(10, { en: 'Gold Nugget', sv: 'Guldklumpen' }, '#FFD75E', '#6B4300', 0.4, { ring: true, deco: 'crown' }),
  ],
  spotStyle: 'crack',
  palette: {
    bg: '#150C0B',
    bgDeep: '#0A0605',
    bgGlow: '#3A1A12',
    jarGlass: '#25140F',
    jarWall: '#4A2A1F',
    jarEdge: '#D08A5C',
    jarShine: '#FFD8B8',
    floor: '#3A2018',
  },
  sound: {
    layers: [
      { wave: 'sawtooth', semitones: 0, gain: 0.55 },
      { wave: 'sine', semitones: -12, gain: 0.7 },
    ],
    gain: 0.34,
    attack: 0.004,
    decay: 0.22,
    lowpassHz: 2400,
    lowpassToHz: 600,
    lowpassQ: 3,
    noise: { gain: 0.1, decay: 0.04, lowpassHz: 5000 },
    timbre: 'Varmt dovt "vomp": sågtand + sub-oktav genom nedåtsvepande lågpass, litet knaster.',
  },
  particle: {
    shape: 'ring',
    countScale: 0.4,
    speedScale: 0.4,
    lifespanMs: 720,
    gravityY: -60,
    spinDegPerSec: 0,
    scale: { start: 0.3, end: 1.4 },
    alpha: { start: 0.8, end: 0 },
    blend: 'NORMAL',
    tint: 'level',
    mix: { shape: 'dot', share: 0.6, gravityY: -40, tint: '#FFBE55' },
  },
  backdrop: {
    idea: 'Två vulkansiluetter bakom burkens botten, svag kraterglöd, glöd som stiger långsamt (10 px/s).',
    ops: [
      { op: 'poly', pts: [[-20, 640], [90, 500], [140, 510], [250, 640]], color: '#2A1510', alpha: 1 },
      { op: 'poly', pts: [[180, 640], [300, 530], [330, 535], [400, 640]], color: '#221009', alpha: 1 },
      { op: 'circle', x: 115, y: 505, r: 60, color: '#5A2412', alpha: 0.35 },
      { op: 'scatter', seed: 59, count: 22, x: 20, y: 140, w: 320, h: 460, rMin: 1, rMax: 2, color: '#FFB547', alphaMin: 0.25, alphaMax: 0.55, vy: -10, swayPx: 5, swayHz: 0.3 },
    ],
  },
  icon:
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" stroke-linejoin="round">' +
    '<path d="M32 6 C40 18 50 24 50 38 A18 18 0 0 1 14 38 C14 28 21 24 24 14 C28 22 30 24 32 26 C34 20 34 14 32 6 Z" fill="#FFBE55" stroke="#5C3500" stroke-width="4"/>' +
    '<path d="M32 30 C36 36 40 38 40 44 A8 8 0 0 1 24 44 C24 38 28 36 32 30 Z" fill="#FFF2DC"/></svg>',
}

// ---------------------------------------------------------------- export

/** Index 0 = Glimtarna (bas, alltid upplåst). Ordningen här är INTE upplåsningsordningen (den slumpas). */
export const THEME_SETS: readonly ThemeSet[] = [GLIMTARNA, PLANETERNA, FROSTISARNA, GODISARNA, GLODEN]

export const THEME_SET_IDS: readonly string[] = THEME_SETS.map((s) => s.id)

export function themeSetById(id: string): ThemeSet {
  return THEME_SETS.find((s) => s.id === id) ?? GLIMTARNA
}

/** Setets palett, med THEME.palette som fallback. */
export function setPalette(set: ThemeSet): SetPalette {
  return set.palette ?? THEME.palette
}

// ---------------------------------------------------------------- meta-UI (UI.md §12)

/** Färger för meta-lagret. Ingen av dem blinkar. */
export const META_COLORS = {
  /** Mörk siluett i HUD-kedjan och boken (3,1:1 mot bg) */
  silhouette: '#56688F',
  /** "?" ovanpå siluetten (4,9:1 mot silhouette), 1 px kant i bg */
  qmark: '#EAF2FF',
  /** Glitterring (skimrande) – ljus guld, vita gnistor */
  shiny: '#FFD75E',
  shinySpark: '#FFFFFF',
  /** Stapel mot nästa set */
  barTrack: '#2B3B5E',
  barFill: '#EAF2FF',
} as const

/**
 * Siluett-ikon ("?"). f = fyllning, e = kant, m = frågetecken.
 * Används för låsta set (bok, sidindikator, stapelns ände).
 */
export const QMARK_ICON = (f: string = META_COLORS.silhouette, e = '#8FA3C8', m: string = META_COLORS.qmark): string =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64"><circle cx="32" cy="32" r="24" fill="${f}" stroke="${e}" stroke-width="4"/><path d="M24 25 a8 8 0 1 1 11 7.4 c-2 .9 -3 2.4 -3 4.6 v2" fill="none" stroke="${m}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/><circle cx="32" cy="47" r="3.6" fill="${m}"/></svg>`

/** Bok (interaktiv ⇒ accent). Öppen bok med en glimt på högersidan. */
export const BOOK_ICON = (c = '#7CF9FF'): string =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" fill="none" stroke="${c}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"><path d="M32 18 C24 12 14 12 7 14 V50 C14 48 24 48 32 54 C40 48 50 48 57 50 V14 C50 12 40 12 32 18 Z"/><path d="M32 18 V52"/><circle cx="45" cy="31" r="5" fill="${c}" stroke="none"/></svg>`

/** Stäng (interaktiv ⇒ accent). Samma som ICONS.close i ui/icons.ts. */
export const CLOSE_ICON = (c = '#7CF9FF'): string =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" fill="none" stroke="${c}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"><path d="M18 18 L46 46 M46 18 L18 46"/></svg>`

/** Skimrande-markör (fyrudds-gnista, fylld). Avdelare i boken. */
export const SPARKLE_ICON = (c: string = META_COLORS.shiny): string =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64"><path d="M32 4 C34 23 41 30 60 32 C41 34 34 41 32 60 C30 41 23 34 4 32 C23 30 30 23 32 4 Z" fill="${c}"/></svg>`

/** Layout och animation, logiska px (360×640). Spec: UI.md §12.2–12.6. */
export const META = {
  chain: {
    /** Vänsterställd under poängen, samma x-kant som poängen. */
    x0: 25,
    y: 78,
    pitch: 18,
    /** Kroppsradie per nivå: r0 + rStep·k ⇒ 5,0 … 8,5 px */
    r0: 5,
    rStep: 0.35,
    qmarkPx: 10,
    /** Combo-prickarna flyttas från y 86 till y 97 för att ge plats. */
    comboDotsY: 97,
    lightDelayMs: 80,
    staggerMs: 90,
    punch: { peak: 1.3, upMs: 90, downMs: 160, easeUp: 'Quad.easeOut', easeDown: 'Back.easeOut' },
    ring: { toR: 2.4, ms: 320, alpha: 0.9, ease: 'Cubic.easeOut' },
    /** Målpuls på nästa "?" ovanför högsta tända nivå. 0,5 Hz. */
    goalPulse: { scale: 1.12, halfCycleMs: 1000, ease: 'Sine.easeInOut' },
    /** Undanflyttning: hängande objekt vars x ≤ right + r tonar ned raden (siktet går före). */
    dim: { right: 213, alpha: 0.35, inMs: 120, outMs: 200 },
    /** Allra första rundan: raden tonas in vid första merge. */
    firstRunFadeMs: 300,
    /** "?" krymper bort när nivån tänds första gången. */
    qmarkOutMs: 120,
    /** "?" tänds första gången: ringen dubbleras (andra 100 ms senare) + 3 partiklar i setets form. */
    first: { rings: 2, ringStepMs: 100, particles: 3, speedMin: 20, speedMax: 45, lifeMs: 420, scale: 0.55 },
  },
  book: {
    close: { x: 320, y: 44, icon: 48, hit: 72 },
    setIcon: { x: 180, y: 58, size: 56, ringR: 38 },
    meter: { x: 180, y: 118, px: 24 },
    colsX: [72, 144, 216, 288] as readonly number[],
    lastRowX: [108, 180, 252] as readonly number[],
    normalRowsY: [178, 246, 314] as readonly number[],
    separatorY: 354,
    shinyRowsY: [394, 462, 530] as readonly number[],
    /** Kroppsradie i boken: 14 + 1·k ⇒ 14 … 24 */
    r0: 14,
    rStep: 1,
    lockedAlpha: 0.25,
    dots: { y: 574, pitch: 22, rCurrent: 6, r: 4 },
    bar: { x0: 64, x1: 282, y: 604, h: 8, iconX: 304, iconSize: 28 },
    swipe: { minPx: 60, minVelocity: 0.45, pageMs: 240, snapMs: 180, rubber: 0.35, tapMaxPx: 12, tapMaxMs: 350 },
    /** Första öppningen någonsin: sidan glider 36 px och tillbaka (svep-ledtråd). */
    peek: {
      px: 36,
      ms: 600,
      delayMs: 500,
      /** Handen som visar svepet: tonas in, följer sidan åt vänster, tonas ut. En gång. */
      hand: { x: 236, y: 300, size: 56, dx: -84, inMs: 150, outMs: 250 },
    },
    /** "Nytt sedan sist": skalpuls 0,5 Hz tills platsen synts i 2 s. */
    freshPulse: { scale: 1.1, halfCycleMs: 1000 },
    glitterSpinDegPerSec: 20,
  },
  shelf: {
    best: { x: 156, y: 436, r: 34 },
    book: { x: 238, y: 444, size: 48 },
    hit: { x: 80, y: 396, w: 200, h: 88 },
    badge: { x: 258, y: 422, r: 6 },
    bar: { x0: 110, x1: 250, y: 526, h: 6, iconX: 268, iconSize: 22 },
  },
  reveal: {
    /** Tider i ms från GameOver.create. Max 2 500 totalt. */
    startMs: 200,
    book: { x: 148, y: 56, size: 56, inMs: 220 },
    meter: { x: 178, y: 56, px: 24 },
    bar: { x0: 110, x1: 250, y: 94, h: 6, iconX: 268, iconSize: 20 },
    flyStartMs: 420,
    flyers: { max: 6, staggerMs: 160, flightMs: 420, midR: 16, endR: 6, ctrlY: 18 },
    /** Komprimerat när ett nytt set låses upp, så att allt ryms i 2,5 s. */
    flyersFast: { staggerMs: 110, flightMs: 340 },
    bookPunch: { peak: 1.18, ms: 180 },
    barFillMs: 360,
    barFillFastMs: 200,
    newSet: { x: 180, y: 76, size: 72, inMs: 300, rings: 3, ringFromR: 36, ringMaxR: 80, ringMs: 640, ringStepMs: 120, intensity: 0.9, stripFadeMs: 200 },
    totalMaxMs: 2500,
  },
  shiny: {
    ringRadius: 1.28,
    halfCycleMs: 600,
    alphaMin: 0.55,
    alphaMax: 1,
    scaleAmp: 0.06,
    spinDegPerSec: 30,
    popInMs: 260,
    sparks: 6,
    /** Guldstjärnorna (`fx-p-star`) när en skimrande skapas: varannan guld, varannan vit. Lugnt läge: hälften. */
    stars: { speedMin: 40, speedMax: 90, lifeMs: 560, scale: 0.9, spinDeg: 120 },
  },
} as const

/**
 * Ljud för meta-lagret. Samma form som ToneDef i systems/audio.ts (playTone).
 * semitones-argumentet till playTone anges i kommentaren.
 */
export const META_SOUND = {
  /** Kedjan tänds. playTone(def, CHAIN_STEPS[level]). Pentatoniskt uppåt, tyst under merge-ljudet. */
  chainLight: { wave: 'sine', baseHz: 523.25, attack: 0.002, decay: 0.09, gain: 0.1, delayMs: 60 },
  /** Nivå som aldrig skapats förut ("?" tänds): kvint ovanpå, längre. */
  chainFirst: { wave: 'sine', baseHz: 523.25, attack: 0.002, decay: 0.16, gain: 0.12, harmonicSemitones: 7, harmonicGain: 0.5, delayMs: 60 },
  /** Skimrande skapas i spel: kvint över merge-tonen. playTone(def, combo). */
  shinyCreate: { wave: 'triangle', baseHz: 587.33, attack: 0.004, decay: 0.42, gain: 0.22, harmonicSemitones: 12, harmonicGain: 0.3, vibratoHz: 7, vibratoCents: 15, delayMs: 70 },
  /** Rundavslut: en Glimt landar i boken. playTone(def, CATCH_STEPS[i]). */
  catch: { wave: 'triangle', baseHz: 1046.5, attack: 0.003, decay: 0.12, gain: 0.2, harmonicSemitones: 12, harmonicGain: 0.2 },
  /** Rundavslut: skimrande landar. playTone(def, CATCH_STEPS[i]). */
  shinyCatch: { wave: 'triangle', baseHz: 1046.5, attack: 0.003, decay: 0.3, gain: 0.22, harmonicSemitones: 7, harmonicGain: 0.55, vibratoHz: 7, vibratoCents: 15 },
  /** Nytt set: fanfar, sedan setets eget merge-ljud på 392 och 587 Hz (120 ms isär). */
  newSet: { wave: 'triangle', baseHz: 523.25, attack: 0.004, decay: 0.32, gain: 0.4, steps: [0, 4, 7, 12, 16], stepMs: 90, harmonicSemitones: 12, harmonicGain: 0.25 },
  newSetPreviewAtMs: 520,
  /** Sida bläddras: kort nedåtglid. */
  pageTurn: { wave: 'sine', baseHz: 900, glideTo: 620, attack: 0.001, decay: 0.07, gain: 0.12 },
  /** Låst sida trycks: dov nedåt, aldrig bestraffande. */
  locked: { wave: 'triangle', baseHz: 330, glideTo: 247, attack: 0.004, decay: 0.14, gain: 0.16 },
} as const

/** Pentatonisk trappa per nivå (halvtoner). */
export const CHAIN_STEPS: readonly number[] = [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24]
/** Stigande trappa per landad Glimt i rundavslutet. */
export const CATCH_STEPS: readonly number[] = [0, 2, 4, 7, 9, 12]

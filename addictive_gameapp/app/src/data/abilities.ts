/**
 * Implementationsvärden för förmågorna (DESIGN §14.5, UI.md §13.8) som inte är parametrar per nivå.
 * Parametrarna I/II/III ligger i `avatars.ts` (`ability.params`); här står bara det som kommentarerna
 * i avatars.ts och UI.md §13.8 beskriver i text (färger, tider, positioner). Ren data, ingen Phaser.
 */

export const ABILITY_FX = {
  /** Muller: sicksackblixtar som streck (ingen skärmblixt). Mullret = showcase-ljudet med rumbleGain. */
  thunder: { color: '#FFD447', len: 26, width: 3, zigs: 4, spreadPx: 60 },
  /** Maestro: melodin i halvtoner över merge-tonen (392 Hz). II: + kvint, III: + bas var tredje ton. */
  melody: { harmonySemitones: 7, harmonyGain: 0.35, bassEvery: 3, bassSemitones: -12, bassGain: 0.6 },
  /** Tick: sepia-overlay och klockring vid farolinjen, tick-tack 2 Hz. */
  tick: {
    sepia: '#B07A3C',
    inMs: 250,
    outMs: 250,
    ring: { x: 316, r: 14, width: 3, color: '#F7E6CC', ticks: 12 },
    /** Två klick per sekund (tick, tack) i Hz. */
    tickHz: [1200, 900] as readonly number[],
    clickMs: 30,
  },
  /** Fia: raketer stiger från burkens botten och slår ut i stjärnringar. */
  fanfare: { riseMs: 520, staggerMs: 140, topY: [150, 230] as readonly number[], colors: ['#FFD447', '#FF9CF0', '#7CF9FF'] as readonly string[], speed: 110 },
  /** Vulle: lavadroppar (korall/bärnsten, aldrig mättad röd). */
  lava: { colors: ['#FF8766', '#FFB547'] as readonly string[], speed: 220, gravityY: 520, lifeMs: 900 },
  /** Disco: färgfläckar bakom burken som roterar 20°/s. */
  disco: { degPerSec: 20, radius: 150, spotPx: 90, colors: ['#FF8766', '#FFD447', '#6EE7A0', '#5AA9FF', '#B98CFF', '#FF9CF0'] as readonly string[], decayMs: 900 },
  /** Eko: antal upprepningar av merge-tonen och ringarnas färg. */
  echo: { repeats: 3, ringColor: '#A6B8FF', ringMaxR: 70, ringMs: 560 },
  /** Klick: polaroid i rundavslutet. */
  polaroid: { w: 120, h: 160, border: 8, bottom: 22, x: 78, y: 520, rotDeg: -6, inMs: 400, shutterMs: 120, pitchX: 118, frameTint: '#5AA9FF' },
  /** Nora: norrskensband över burkens hals (ADD), vajar 0,3 Hz. */
  aurora: { colors: ['#6EE7A0', '#5AA9FF', '#B98CFF'] as readonly string[], y: 150, spacing: 34, width: 22, swayPx: 14, swayHz: 0.3, inMs: 300, outMs: 600 },
  /** Lisa: stilla ring runt objekt av samma nivå medan man siktar. */
  lisa: {
    ringR: 1.18,
    inMs: 120,
    color: '#EAF2FF',
    /**
     * Oljemätaren: båge runt lyktan (box-koordinater i 56-boxen) som krymper medan siktningen
     * förbrukar oljan och försvinner vid 0. Ritas om högst `steps` gånger per runda.
     */
    meter: { box: [-9, -21] as readonly [number, number], r: 8, width: 3, color: '#FFF1A8', trackAlpha: 0.25, steps: 48, outMs: 250 },
  },
  /** Siri: objektet efter nästa, till vänster om förhandsvisningen. */
  siri: { x: 250, y: 44, frame: 44 },
  /** Sixten: prickens och konturens färg. */
  sixten: { color: '#7CF9FF' },
  /** Bubbel: bubbelhinna tills landning. */
  bubbel: { color: '#EAF2FF', alpha: 0.5, rMul: 1.15 },
  /** Ekko: ringen per ping. */
  ekko: { ms: 500, color: '#7FE3D0', alpha: 0.8 },
  /** Maja: villkor och drag (UI.md §13.8). */
  maja: { stillMs: 400, pullMs: 300, maxLevel: 9, stillSpeed: 0.6, lineColor: '#FFD75E', checkEveryFrames: 6 },
  /** Andrums-Vala: blå fontän i burkens hals när ett andetag används. */
  vala: { color: '#BFEFFF' },
  /** Havsdrottningen: guldburk, stråklager, regnbåge som drop 3 och extra specialobjekt. */
  queen: {
    jarEdge: '#FFD75E',
    jarShine: '#FFF1C4',
    rainbowAtDrop: 3,
    /** Extra specialobjekt ur regissörens Kick-tabell läggs på dessa drop (så många som `extraSpecials`). */
    extraAtDrops: [22, 44] as readonly number[],
    strings: { wave: 'sawtooth', baseHz: 392, attack: 0.02, decay: 0.3, gain: 0.15, lowpassHz: 1800 },
    stringsSemitones: 12,
  },
  /** Stjärnvalen: stjärnhimmel (scatter 60 st, stilla) i stället för setets backdrop. */
  starWhale: { op: 'scatter', seed: 4711, count: 60, x: 0, y: 0, w: 360, h: 640, color: '#FFF4C0', rMin: 0.6, rMax: 1.8, alphaMin: 0.3, alphaMax: 0.9 },
} as const;

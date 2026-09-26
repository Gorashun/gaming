/**
 * Debugpanelen för speltest (PLAYTEST.md §3, P5.1a). Ren data. Panelen är för testledaren,
 * inte för barn: den öppnas bara med ett långtryck på logotypen.
 */
import type { Rarity } from './avatarsIndex';

export const DEBUG = {
  /** Ringbuffer: så många rundor sparas i `debug.runs`. */
  maxRuns: 20,
  /** Långtryck på logotypen. */
  longPressMs: 2000,
  /** Fingret rör sig mer än så: inget långtryck. */
  moveCancelPx: 12,
  /** Logotypens träffyta (logisk yta 360×640). */
  /** Start v2: logotypen har baslinje y 116 (START_UI.logo), hjälten börjar på y 126. */
  logoHit: { x: 40, y: 60, w: 280, h: 66 },
  /** Regissörens lägen i den ordning de räknas (index = kod). */
  modes: ['drought', 'flow', 'kick'] as const,
  /** "Ge kompis" cyklar genom rariteterna med förmågor. */
  giftOrder: ['rare', 'epic', 'legendary', 'mythic'] as readonly Rarity[],
  /** Nollställ kräver ett andra tryck inom så här lång tid. */
  confirmMs: 3000,
  panel: {
    depth: 100,
    bg: '#05080F',
    bgAlpha: 0.96,
    text: '#EAF2FF',
    dim: '#8FA3C8',
    accent: '#7CF9FF',
    font: 'monospace',
    px: 10,
    lineH: 13,
    listY: 40,
    /** Raden "Zoom: 2 (auto)" ovanför statusraden. */
    zoomY: 336,
    statusY: 356,
    /** Byggversionen (RELEASE.md §Versioning), en rad under knapparna. */
    versionY: 596,
    /** Knappar 160×52 i två kolumner. */
    buttons: [
      { id: 'copy', label: 'Kopiera JSON', x: 94, y: 410 },
      { id: 'reset', label: 'Nollställ sparfil', x: 266, y: 410 },
      { id: 'gift', label: 'Ge kompis', x: 94, y: 474 },
      { id: 'autodrop', label: 'Auto-drop', x: 266, y: 474 },
      { id: 'zoom', label: 'Zoom: auto', x: 94, y: 538 },
      { id: 'close', label: 'Stäng', x: 266, y: 538 },
    ] as const,
    buttonW: 160,
    buttonH: 52,
  },
} as const;

export type DebugButton = (typeof DEBUG.panel.buttons)[number]['id'];

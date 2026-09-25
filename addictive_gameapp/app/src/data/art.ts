/**
 * art.ts – "Art v2": materiallagret ovanpå primitivspråket (UI.md §15).
 *
 * Ren data. Får INTE importera Phaser. Renderaren är `ui/artv2.ts` (Canvas2D).
 * Allt bakas EN gång per textur (aldrig per frame) i devicePixelRatio, max `maxDpr`.
 *
 * Enheter:
 *  - `h` = delens halvstorlek (halva bredden/höjden på dess bbox). För nivåer är h = r.
 *    Parametrar i h gör att samma material ser likadant ut på en hand, en kropp och Klunken.
 *  - `u` = absoluta box-enheter (avatarens 56-box) resp. andel av r för nivåer (`...R`).
 *  - dL/dS = procentenheter i HSL (lightness/saturation), relativt delens `color`.
 *
 * Ljus: ett nyckelljus uppe till vänster (samma håll som burkens reflexer och §3.1 steg 3),
 * ett kallt kantljus uppe till höger (havets glöd), skugga nedåt.
 */

export const ART = {
  /**
   * Spelets zoom Z = min(devicePixelRatio, maxZoom) (DESIGN §17): canvas 360·Z × 640·Z, kamerazoom Z,
   * nivåer och kompisar bakas i Z. `?zoom=1` sänker (aldrig höjer), t.ex. för fps-jämförelse.
   */
  maxZoom: 2,
  /** 'v2' = material (Canvas2D, bakat i Z). 'v1' = gamla Graphics-vägen i 1× (lågprestandaläge, `?art=v1`). */
  mode: 'v2' as 'v1' | 'v2',
  /** Högst så här många nivåset (11 nivåer + siluetter) i full upplösning samtidigt. Det aktiva frigörs aldrig. */
  maxSets: 2,
  /** Bakningsupplösning: min(devicePixelRatio, maxDpr). Texturen visas med setScale(1/dpr). */
  maxDpr: 3,
  /** Stora nivåer: sänk dpr så att texturens sida aldrig överstiger detta (px). */
  maxTexSide: 1024,

  /** Nyckelljusets centrum relativt delens centrum, i h. */
  light: { x: -0.38, y: -0.46 },

  /** 1. Radiell basgradient: ljus topp-vänster → mättad kant. Elliptisk (följer delens h). */
  base: {
    /** Gradientens radie från ljuscentrum, i h. */
    radius: 1.55,
    /** Färgstopp: hi vid 0, color vid `mid`, lo vid 1. */
    mid: 0.66,
    hiL: 16,
    hiS: -6,
    loL: -12,
    loS: 10,
    /** Mörka kroppar (L < darkL) mörkas relativt: L' = L · darkMul i stället för L + loL. */
    darkL: 30,
    darkMul: 0.7,
  },

  /**
   * 2. Inre skugga i nederkant (skugga av "utsidan" förskjuten uppåt, klippt till delen).
   * Förskjutning = halva konturbredden + off·h, så att skuggan alltid syns innanför konturen.
   */
  inner: {
    dL: -22,
    dS: 6,
    alpha: 0.5,
    /** i h (negativ y = skuggan hamnar i nederkanten) */
    offX: 0.03,
    offY: -0.16,
    blur: 0.2,
    /** Delar mindre än så här (h i box-enheter) hoppar över steget. Nivåer: alltid. */
    minHalfU: 5,
  },

  /**
   * 3. Kantljus uppe till höger. Tunt, kallt, blandat mot vitt. Samma teknik som inre skuggan men
   * utsidan flyttas ned-vänster, så att ett ljust band hamnar längs övre högra kanten.
   * Förskjutning = halva konturbredden + width·h längs (dirX, dirY).
   */
  rim: {
    dL: 30,
    dS: -10,
    mixWhite: 0.35,
    alpha: 0.72,
    dirX: -0.62,
    dirY: 0.78,
    width: 0.08,
    blur: 0.05,
    minHalfU: 5,
  },

  /** 4. Speglingsljus: mjuk ellips + liten hård prick. */
  spec: {
    /** Avatarernas `shine`-op (vit ellips α 0,26) ritas som mjuk gradient med denna toppalpha. */
    softAlpha: 0.55,
    /** Nivåernas topp-ljus (§3.1 steg 3): samma ellips, men mjuk. */
    levelSoftAlpha: 0.42,
    /** Hård prick: position och radie i h, alpha. */
    dot: { x: -0.44, y: -0.54, r: 0.075, alpha: 0.9 },
    /** Avatardelar får pricken först från denna storlek (h i box-enheter). */
    minHalfU: 7.5,
  },

  /** 5. Kontur: samma bredd som v1, men alpha/ljushet varierar längs ljusriktningen. */
  edge: {
    /** Toppen-vänster (mot ljuset) lite ljusare och genomskinligare, botten full. */
    alphaTop: 0.8,
    alphaBottom: 1,
    dLTop: 10,
    /** Nivåernas kontur blir tjockare nedtill: innercirkeln flyttas upp så här mycket (andel av linjebredd). */
    levelWeight: 0.45,
  },

  /** 6. Kontaktskugga: när en del ritas ovanpå en annan faller en mjuk skugga på den undre (source-atop). */
  contact: {
    color: '#0A1020',
    alpha: 0.3,
    dxU: 0.3,
    dyU: 1.2,
    blurU: 1.6,
  },

  /** 7. Mjuk drop shadow under hela figuren/objektet. */
  drop: {
    color: '#02050C',
    avatar: { alpha: 0.55, dxU: 0.4, dyU: 1.6, blurU: 2.4 },
    /** Nivåer: i r. */
    level: { alpha: 0.42, dxR: 0.02, dyR: 0.07, blurR: 0.1 },
  },

  /** 8. Ansikten: formen är IDENTISK med v1. Bara "inset"-känsla. */
  face: {
    /** Ljus underläpp under varje ink-drag (ljuset studsar på nedre kanten av en fördjupning). */
    lipColor: '#FFFFFF',
    lipAlpha: 0.3,
    /** Förskjutning nedåt: avatarer i box-enheter, nivåer i r. */
    lipDyU: 0.55,
    lipDyR: 0.022,
    /** Ink är FORTFARANDE platt #14202E: en ljusare ink-gradient sänker kontrasten (nivå 5 → 3,8:1). */
    /** Ögonvita (avatarernas `big`-ögon): sfärisk gradient och skugga från ögonlocket. */
    eyeWhiteLow: '#CFDBEF',
    eyeLidAlpha: 0.28,
    /** Glint (bara avatarer – objekten har aldrig glint, UI.md §13.1): mjuk gloria runt pricken. */
    glintHaloMul: 2.0,
    glintHaloAlpha: 0.4,
  },

  /** Kinder: mjuk radiell rodnad i stället för platt ellips. Toppalpha (v1: 0,55 platt). */
  cheek: { alpha: 0.72 },

  /** Halo (nivåer): en radiell gradient i stället för tre ringar. Alpha vid kroppskanten → 0. */
  halo: { alphaInner: 0.34, mid: 0.4, alphaMid: 0.14 },

  /** Inre ring (nivåer, §3.1 steg 4): graverad fåra = mörk linje + ljus underkant. */
  groove: { darkAlpha: 0.42, lightAlpha: 0.32, lightW: 0.4, lightDyR: 0.028 },

  /** Prickar stil 'dot': små gropar = mörk fyllning + ljus underkant. */
  dimple: { alpha: 0.34, lipAlpha: 0.3, lipDyR: 0.018 },

  /** Rör (spröt, tentakler, avatarernas ben med edge): högdager längs röret. */
  tube: { hiW: 0.34, hiL: 22, hiAlpha: 0.6, hiOff: 0.22, minWidthU: 2.4 },
} as const;

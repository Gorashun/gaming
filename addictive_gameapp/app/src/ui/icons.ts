/** Ikoner enligt docs/UI.md §9. En stil: viewBox 64×64, stroke 6, rundade ändar. */

export const ICONS = {
  play: (c = '#7CF9FF') =>
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64"><path d="M24 16 L48 32 L24 48 Z" fill="${c}" stroke="${c}" stroke-width="8" stroke-linejoin="round"/></svg>`,

  soundOn: (c = '#EAF2FF') =>
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" fill="none" stroke="${c}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"><path d="M12 25 H21 L32 15 V49 L21 39 H12 Z"/><path d="M41 24 a11 11 0 0 1 0 16"/><path d="M48 17 a20 20 0 0 1 0 30"/></svg>`,

  soundOff: (c = '#8FA3C8') =>
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" fill="none" stroke="${c}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"><path d="M12 25 H21 L32 15 V49 L21 39 H12 Z"/><path d="M42 25 L56 39 M56 25 L42 39"/></svg>`,

  hapticOn: (c = '#EAF2FF') =>
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" fill="none" stroke="${c}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"><rect x="23" y="12" width="18" height="40" rx="5"/><path d="M12 24 a12 12 0 0 0 0 16"/><path d="M52 24 a12 12 0 0 1 0 16"/></svg>`,

  hapticOff: (c = '#8FA3C8') =>
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" fill="none" stroke="${c}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"><rect x="23" y="12" width="18" height="40" rx="5"/><path d="M10 26 L18 38 M18 26 L10 38 M46 26 L54 38 M54 26 L46 38"/></svg>`,

  // Lugnt läge AV = taggig våg (full juice). PÅ = mjuk våg. Formen bär informationen.
  calmOff: (c = '#8FA3C8') =>
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" fill="none" stroke="${c}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"><circle cx="32" cy="32" r="22"/><path d="M14 32 L22 20 L28 42 L36 18 L42 40 L50 32"/></svg>`,

  calmOn: (c = '#7CF9FF') =>
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" fill="none" stroke="${c}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"><circle cx="32" cy="32" r="22"/><path d="M14 32 q 9 -12 18 0 q 9 12 18 0"/></svg>`,

  crown: (c = '#FFD75E') =>
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64"><path d="M10 46 L14 18 L26 30 L32 14 L38 30 L50 18 L54 46 Z" fill="${c}" stroke="${c}" stroke-width="6" stroke-linejoin="round"/></svg>`,

  replay: (c = '#7CF9FF') =>
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" fill="none" stroke="${c}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"><path d="M50 32 a18 18 0 1 1 -6.2 -13.6"/><path d="M52 12 V22 H42"/></svg>`,

  // Onboarding: hand med pekfinger. Rörelsen görs i tween, inte i ikonen.
  hand: (c = '#EAF2FF', ink = '#14202E') =>
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64"><path d="M26 40 V14 a5 5 0 0 1 10 0 v18 l4 1 a10 10 0 0 1 7 9 v6 a10 10 0 0 1 -10 10 h-8 a10 10 0 0 1 -8 -4 l-8 -11 a4 4 0 0 1 6 -5 l7 6 Z" fill="${c}" stroke="${ink}" stroke-width="4" stroke-linejoin="round"/></svg>`,

  // Rörelsespår under handen
  swipe: (c = '#7CF9FF') =>
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" fill="none" stroke="${c}" stroke-width="5" stroke-linecap="round" stroke-dasharray="2 9"><path d="M8 32 H56"/></svg>`,
};

export type IconKey = keyof typeof ICONS;

/** Alla ikoner som ska bakas till texturer vid boot, med sin nyckel. */
export const ICON_KEYS: readonly IconKey[] = [
  'play',
  'soundOn',
  'soundOff',
  'hapticOn',
  'hapticOff',
  'calmOn',
  'calmOff',
  'crown',
  'replay',
  'hand',
  'swipe',
];

/** Rastrerar SVG-strängen till en HTMLImageElement (2× för skärpa). */
function toImage(svg: string, scale: number): Promise<HTMLImageElement> {
  const sized = svg.replace('width="64" height="64"', `width="${64 * scale}" height="${64 * scale}"`);
  const uri = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(sized);
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error('icon load failed'));
    img.src = uri;
  });
}

export function iconTextureKey(key: IconKey): string {
  return `icon-${key}`;
}

/** Laddar alla ikoner som texturer. Anropas en gång i Boot. */
export async function loadIcons(
  textures: { exists(k: string): boolean; addImage(k: string, img: HTMLImageElement): unknown },
  scale = 2,
): Promise<void> {
  await Promise.all(
    ICON_KEYS.map(async (k) => {
      const key = iconTextureKey(k);
      if (textures.exists(key)) return;
      try {
        const img = await toImage(ICONS[k](), scale);
        textures.addImage(key, img);
      } catch {
        /* ikonen saknas hellre än att hela boot fastnar */
      }
    }),
  );
}

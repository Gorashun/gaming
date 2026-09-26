import { START_FONT } from '../data/startUi';

/**
 * Laddar Fredoka (UI.md §16.4) före första Text: Phaser rastrerar text när objektet skapas.
 * Buntad fil, inga nätanrop. Timeout eller fel ⇒ systemfonten (START_FONT.family har fallbacks).
 */
export async function loadFonts(): Promise<boolean> {
  if (typeof FontFace === 'undefined' || typeof document === 'undefined' || !document.fonts) return false;
  try {
    const face = new FontFace(START_FONT.face, `url(${START_FONT.file})`, { weight: START_FONT.weightRange });
    (document.fonts as unknown as { add(f: FontFace): void }).add(face);
    const timeout = new Promise<boolean>((r) => window.setTimeout(() => r(false), START_FONT.loadTimeoutMs));
    return await Promise.race([face.load().then(() => true), timeout]);
  } catch {
    return false;
  }
}

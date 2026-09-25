/**
 * Spelets zoom Z (DESIGN §17, UI.md §15.2): min(devicePixelRatio, maxZoom), aldrig under 1,
 * avrundat nedåt till steg om 0,25 så att 360·Z × 640·Z blir hela pixlar.
 * `override` (URL `?zoom=`) kan bara sänka Z.
 */
export function zoomFor(dpr: number | undefined, maxZoom: number, override?: string | null): number {
  let z = Math.min(maxZoom, dpr && dpr > 0 ? dpr : 1);
  const o = override ? Number(override) : NaN;
  if (o > 0) z = Math.min(z, o);
  return Math.max(1, Math.floor(z * 4) / 4);
}

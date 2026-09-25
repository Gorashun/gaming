/**
 * Spelets zoom Z (DESIGN §17, UI.md §15.2): min(devicePixelRatio, maxZoom), aldrig under 1,
 * avrundat nedåt till steg om 0,25 så att 360·Z × 640·Z blir hela pixlar.
 * `override` (URL `?zoom=`, bara testbygget) och `cap` (`settings.zoomCap`, fps-vakten) kan bara sänka Z.
 */
export function zoomFor(dpr: number | undefined, maxZoom: number, override?: string | null, cap?: number | null): number {
  let z = Math.min(maxZoom, dpr && dpr > 0 ? dpr : 1);
  const o = override ? Number(override) : NaN;
  if (o > 0) z = Math.min(z, o);
  if (cap && cap > 0) z = Math.min(z, cap);
  return Math.max(1, Math.floor(z * 4) / 4);
}

/** Debugpanelens rad: "Zoom: 2 (auto)", "Zoom: 1 (vakt)", eller taket satt men inte tillämpat än. */
export function zoomLine(z: number, zAuto: number, cap: number | null): string {
  if (cap === null) return `Zoom: ${z} (auto)`;
  const capped = Math.min(zAuto, cap);
  return capped === z ? `Zoom: ${z} (vakt)` : `Zoom: ${z} → ${capped} (vakt, från nästa appstart)`;
}

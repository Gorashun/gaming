/**
 * Haptik enligt DESIGN.md §6: 10 / 30 / 60 ms efter juice-intensitet.
 * Capacitor på mobil, navigator.vibrate på webb, helt tyst om inget finns.
 */
import { Capacitor } from '@capacitor/core';
import { Haptics } from '@capacitor/haptics';
import { THEME } from '../data/theme';

let enabled = true;
const native = (() => {
  try {
    return Capacitor.isNativePlatform();
  } catch {
    return false;
  }
})();

export function setHapticsEnabled(on: boolean): void {
  enabled = on;
}

export function vibrate(durationMs: number): void {
  if (!enabled || durationMs <= 0) return;
  if (native) {
    void Haptics.vibrate({ duration: durationMs }).catch(() => undefined);
    return;
  }
  const nav = globalThis.navigator as Navigator & { vibrate?: (p: number) => boolean };
  try {
    nav?.vibrate?.(durationMs);
  } catch {
    /* tyst fallback */
  }
}

/** 10 ms vid i<0,3, 30 ms vid i<0,7, 60 ms annars. */
export function msForIntensity(i: number): number {
  const h = THEME.haptics;
  if (i < h.mediumAt) return h.light;
  if (i < h.heavyAt) return h.medium;
  return h.heavy;
}

export function hapticForIntensity(i: number): void {
  vibrate(msForIntensity(i));
}

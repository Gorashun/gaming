/** Väljer lagring: Capacitor Preferences på mobil, localStorage i webb. */
import { Capacitor } from '@capacitor/core';
import { Preferences } from '@capacitor/preferences';
import { setStorageAdapter } from './save';

export function installStorageAdapter(): void {
  let native = false;
  try {
    native = Capacitor.isNativePlatform();
  } catch {
    native = false;
  }
  if (!native) return; // localStorage-adaptern i save.ts är default
  setStorageAdapter({
    async get(key) {
      const { value } = await Preferences.get({ key });
      return value ?? null;
    },
    async set(key, value) {
      await Preferences.set({ key, value });
    },
  });
}

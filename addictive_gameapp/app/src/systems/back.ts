/**
 * Bakåtknappen (Android): scenen som visar något stängbart registrerar en hanterare.
 * Ingen hanterare, eller hanteraren returnerar false: standardbeteendet (webbhistorik, annars
 * stäng appen). I webben är Escape en fallback i testbygget.
 */
import { Capacitor } from '@capacitor/core';
import { App } from '@capacitor/app';

type BackHandler = () => boolean;

let handler: BackHandler | null = null;

export function setBackHandler(h: BackHandler): void {
  handler = h;
}

/** Tar bara bort hanteraren om den fortfarande är den aktiva (nästa scen kan redan ha satt sin). */
export function clearBackHandler(h: BackHandler): void {
  if (handler === h) handler = null;
}

export function installBackButton(webFallback: boolean): void {
  let native = false;
  try {
    native = Capacitor.isNativePlatform();
  } catch {
    native = false;
  }
  if (native) {
    void App.addListener('backButton', ({ canGoBack }) => {
      if (handler?.()) return;
      if (canGoBack) window.history.back();
      else void App.exitApp();
    });
    return;
  }
  if (!webFallback) return;
  window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') handler?.();
  });
}

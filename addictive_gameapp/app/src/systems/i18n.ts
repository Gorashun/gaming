/**
 * i18n.ts – språk (DESIGN §15). Engelska är primärspråk, svenska är lokalisering.
 * UI:t är textfritt; namn i data lagras som `LocalizedName` och slås upp med `t()`.
 * Ingen Phaser, inga sidoeffekter vid import.
 */

export type Locale = 'en' | 'sv';

export interface LocalizedName {
  readonly en: string;
  readonly sv: string;
}

/** Strängtabell för framtida UI-text. Tom i v1 (UI:t är textfritt). Mönster: `hello: { en: 'Hello', sv: 'Hej' }`. */
export const STRINGS = {} as const satisfies Record<string, LocalizedName>;

/** sv* → sv, allt annat (även tomt) → en. */
export function localeFrom(language: string | null | undefined): Locale {
  return language?.toLowerCase().startsWith('sv') ? 'sv' : 'en';
}

/**
 * Enhetens språk. I testbygget (DEV eller `?test`) kan `?lang=sv|en` tvinga språket.
 * Argumenten finns för att kunna testas utan webbläsare.
 */
export function getLocale(
  language: string | null | undefined = typeof navigator !== 'undefined' ? navigator.language : undefined,
  search: string = typeof location !== 'undefined' ? location.search : '',
): Locale {
  const q = new URLSearchParams(search);
  const testBuild = import.meta.env.DEV || q.has('test');
  const forced = q.get('lang');
  if (testBuild && forced) return localeFrom(forced);
  return localeFrom(language);
}

export function t(name: LocalizedName, locale: Locale = getLocale()): string {
  return name[locale];
}

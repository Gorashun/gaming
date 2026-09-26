/**
 * i18n.ts – språk (DESIGN §15). Engelska är primärspråk, svenska är lokalisering.
 * Namn i data lagras som `LocalizedName` och slås upp med `t()`. Startskärmens korta etiketter
 * (UI.md §16.2, DESIGN §18) ligger i `STRINGS` och slås upp med `str()`.
 * Ingen Phaser, inga sidoeffekter vid import.
 */

export type Locale = 'en' | 'sv';

export interface LocalizedName {
  readonly en: string;
  readonly sv: string;
}

/**
 * UI-text (EN primärt, SV lokalisering). Knappetiketter ≤ 10 tecken (`START_LABEL_MAX`, UI.md §16.2).
 * Underrader och arkets hjälptexter är längre men ryms på en rad. `{n}` och `{m}` ersätts med fillString.
 */
export const STRINGS = {
  play: { en: 'Play', sv: 'Spela' },
  book: { en: 'Book', sv: 'Bok' },
  buddies: { en: 'Buddies', sv: 'Kompisar' },
  shop: { en: 'Shop', sv: 'Butik' },
  shells: { en: 'Shells', sv: 'Musslor' },
  free: { en: 'Free!', sv: 'Gratis!' },
  sound: { en: 'Sound', sv: 'Ljud' },
  haptics: { en: 'Vibration', sv: 'Vibration' },
  calm: { en: 'Calm mode', sv: 'Lugnt läge' },
  aimLine: { en: 'Aim line', sv: 'Siktlinje' },
  /** Hjälptexter i arket (≤ 26 tecken, en rad i 240 px vid 14 px). */
  soundHelp: { en: 'Music and effects', sv: 'Musik och effekter' },
  hapticsHelp: { en: 'Buzz on merges', sv: 'Surr vid sammanslagning' },
  calmHelp: { en: 'Less shake and flash', sv: 'Mindre skak och ljus' },
  aimLineHelp: { en: 'Line where it falls', sv: 'Linje där den faller' },
  /** Set-stapelns text. */
  nextSet: { en: '{n} / {m} to next set', sv: '{n} / {m} till nästa set' },
  /** Underrad med räknare (Bok, Kompisar). */
  count: { en: '{n} / {m}', sv: '{n} / {m}' },
} as const satisfies Record<string, LocalizedName>;

export type StringKey = keyof typeof STRINGS;

/** sv* → sv, allt annat (även tomt) → en. */
export function localeFrom(language: string | null | undefined): Locale {
  return language?.toLowerCase().startsWith('sv') ? 'sv' : 'en';
}

/** Spelarens val (settings.lang). null = standard, som alltid är engelska (DESIGN §15, beslut 2026-09-26). */
let preferred: Locale | null = null;

/** Sätts vid Boot från sparfilen och när spelaren byter språk i inställningarna. */
export function setPreferredLocale(locale: Locale | null): void {
  preferred = locale;
}

/**
 * Spelets språk. Engelska är alltid standard; enhetens språk styr inte längre.
 * Svenska bara om spelaren valt det (`setPreferredLocale('sv')`).
 * I testbygget (DEV eller `?test`) kan `?lang=sv|en` tvinga språket.
 * `language` finns kvar i signaturen för bakåtkompatibilitet men används inte.
 */
export function getLocale(
  _language?: string | null,
  search: string = typeof location !== 'undefined' ? location.search : '',
): Locale {
  const q = new URLSearchParams(search);
  const testBuild = import.meta.env.DEV || q.has('test');
  const forced = q.get('lang');
  if (testBuild && forced) return localeFrom(forced);
  return preferred ?? 'en';
}

export function t(name: LocalizedName, locale: Locale = getLocale()): string {
  return name[locale];
}

/** Slår upp en UI-sträng. */
export function str(key: StringKey, locale: Locale = getLocale()): string {
  return STRINGS[key][locale];
}

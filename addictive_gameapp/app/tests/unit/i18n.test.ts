import { describe, expect, it } from 'vitest';
import { AVATARS } from '../../src/data/avatars';
import { THEME_SETS } from '../../src/data/themes';
import { THEME } from '../../src/data/theme';
import { getLocale, localeFrom, str, STRINGS, t, type LocalizedName } from '../../src/systems/i18n';
import { START_LABEL_KEYS, START_LABEL_MAX } from '../../src/data/startUi';

function expectLocalized(group: readonly LocalizedName[], count: number): void {
  expect(group).toHaveLength(count);
  for (const lang of ['en', 'sv'] as const) {
    const vals = group.map((n) => n[lang]);
    for (const v of vals) expect(v.trim().length, `${lang}: tomt namn`).toBeGreaterThan(0);
    expect(new Set(vals).size, `${lang}: dubbletter i ${vals.join(', ')}`).toBe(count);
  }
}

describe('i18n: namn i data (DESIGN §15)', () => {
  it('48 avatarer har unika en/sv-namn', () => {
    expectLocalized(AVATARS.map((a) => a.names), 48);
  });

  it('5 temaset har unika en/sv-namn', () => {
    expectLocalized(THEME_SETS.map((s) => s.name), 5);
  });

  it('11 nivåer har unika en/sv-namn (Glimtarna och varje set)', () => {
    expectLocalized(THEME.levels.map((l) => l.name), 11);
    for (const s of THEME_SETS) expectLocalized(s.levels.map((l) => l.name), 11);
  });
});

describe('i18n: språkval', () => {
  it('sv* → sv, annars en', () => {
    expect(getLocale('sv-SE', '')).toBe('sv');
    expect(getLocale('sv', '')).toBe('sv');
    expect(getLocale('en-US', '')).toBe('en');
    expect(getLocale('de', '')).toBe('en');
    expect(localeFrom(undefined)).toBe('en');
  });

  it('?lang= tvingar språket i testbygget', () => {
    expect(getLocale('en-US', '?test&lang=sv')).toBe('sv');
    expect(getLocale('sv-SE', '?test&lang=en')).toBe('en');
  });

  it('t() väljer rätt språk', () => {
    const n = { en: 'The Glimmers', sv: 'Glimtarna' };
    expect(t(n, 'en')).toBe('The Glimmers');
    expect(t(n, 'sv')).toBe('Glimtarna');
  });
});

describe('i18n: UI-strängar (UI.md §16.2)', () => {
  it('alla nycklar har icke-tomma en/sv', () => {
    expect(Object.keys(STRINGS).length).toBeGreaterThan(0);
    for (const [k, v] of Object.entries(STRINGS)) {
      for (const lang of ['en', 'sv'] as const) expect(v[lang].trim().length, `${k}.${lang}`).toBeGreaterThan(0);
    }
  });

  it(`knappetiketterna är högst ${START_LABEL_MAX} tecken, övriga ryms på en rad (≤ 26)`, () => {
    for (const k of START_LABEL_KEYS) {
      for (const lang of ['en', 'sv'] as const) expect(STRINGS[k][lang].length, `${k}.${lang}`).toBeLessThanOrEqual(START_LABEL_MAX);
    }
    for (const [k, v] of Object.entries(STRINGS)) {
      for (const lang of ['en', 'sv'] as const) expect(v[lang].length, `${k}.${lang}`).toBeLessThanOrEqual(26);
    }
  });

  it('str() slår upp i STRINGS', () => {
    expect(str('play', 'en')).toBe('Play');
    expect(str('play', 'sv')).toBe('Spela');
  });
});

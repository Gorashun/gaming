import { describe, expect, it } from 'vitest';
import { AVATARS } from '../../src/data/avatars';
import { THEME_SETS } from '../../src/data/themes';
import { THEME } from '../../src/data/theme';
import { getLocale, localeFrom, STRINGS, t, type LocalizedName } from '../../src/systems/i18n';

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
    expect(Object.keys(STRINGS)).toHaveLength(0);
  });
});

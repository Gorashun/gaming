import { expect, test, type Page } from '@playwright/test';
import './hook';

/**
 * QA-hjälpare för de utforskande spec-filerna (qa-*.spec.ts). Ingen testfil: Playwright kör bara *.spec.ts.
 * Koordinater är logiska (360×640); canvasen är Scale.FIT, så boundingBox motsvarar hela ytan.
 */

export const KEY = 'klunk.save.v1';
/** Skärmdumpar från utforskningen (gitignorerad; buggbilder kopieras till docs/qa/). */
export const SHOTS = 'test-results/qa-shots';

// Start v2 (UI.md §16.5)
export const PLAY = [180, 390] as const;
export const BOOK = [66.5, 506] as const;
export const BUDDIES = [180, 506] as const;
export const SHOP = [293.5, 506] as const;
export const GEAR = [320, 36] as const;
export const SHEET_CLOSE = [320, 342] as const;
export const SHEET_ROWS = [404, 468, 532, 596] as const;
// Boken
export const BOOK_CLOSE = [320, 44] as const;
export const TAB_SETS = [32, 36] as const;
export const TAB_FRIENDS = [96, 36] as const;
export const SHOP_SLOTS = { common: [66, 120], silver: [180, 120], gold: [294, 120] } as const;
export const UPGRADE_BTN = [224, 314] as const;

/** pageerror (inkl. ohanterade rejections) och console.error. */
export function collectErrors(page: Page): string[] {
  const errors: string[] = [];
  page.on('pageerror', (e) => errors.push(`pageerror: ${e.message}`));
  page.on('console', (m) => {
    if (m.type() === 'error') errors.push(`console: ${m.text()}`);
  });
  return errors;
}

export function expectNoErrors(errors: string[]): void {
  expect(errors, errors.join('\n')).toEqual([]);
}

export async function toCanvas(page: Page, wx: number, wy: number): Promise<{ x: number; y: number }> {
  const box = (await page.locator('canvas').boundingBox())!;
  return { x: box.x + (wx * box.width) / 360, y: box.y + (wy * box.height) / 640 };
}

export async function tap(page: Page, [wx, wy]: readonly [number, number]): Promise<void> {
  const p = await toCanvas(page, wx, wy);
  await page.mouse.move(p.x, p.y);
  await page.mouse.down();
  await page.mouse.up();
}

/** Riktigt drag: ned vid `from`, flytta i steg till `toX`, släpp. */
export async function drag(page: Page, fromX: number, toX: number, y = 300, steps = 6): Promise<void> {
  const a = await toCanvas(page, fromX, y);
  const b = await toCanvas(page, toX, y);
  await page.mouse.move(a.x, a.y);
  await page.mouse.down();
  await page.mouse.move(b.x, b.y, { steps });
  await page.mouse.up();
}

/** Skriver sparfilen före första laddningen (bara om ingen finns). */
export function seed(page: Page, save: Record<string, unknown>): Promise<void> {
  return page.addInitScript(
    ([k, x]) => {
      if (localStorage.getItem(k)) return;
      localStorage.setItem(k, JSON.stringify(x));
    },
    [KEY, save] as const,
  );
}

export async function open(page: Page, query = ''): Promise<void> {
  await page.goto(`/?test=1${query}`);
  await page.waitForFunction(() => window.__start !== undefined, undefined, { timeout: 20_000 });
  await page.waitForTimeout(1000);
}

export async function waitStart(page: Page): Promise<void> {
  await page.waitForFunction(() => window.__start !== undefined && window.__game === undefined && window.__book === undefined, undefined, {
    timeout: 20_000,
  });
  await page.waitForTimeout(300);
}

export async function startRound(page: Page): Promise<void> {
  await tap(page, PLAY);
  await page.waitForFunction(() => window.__game !== undefined && !window.__game.over, undefined, { timeout: 20_000 });
  await page.waitForTimeout(300);
}

export interface Saved {
  highscore: number;
  bestLevel: number;
  settings: Record<string, unknown>;
  stats: { runs: number; merges: number; maxLevelEver: number; doubleKlunks: number };
  economy: { pearls: number; sand: number; mergesBaseline: number; freeShellsClaimed: number; milestones: string[] };
  avatars: { owned: string[]; level: Record<string, number>; equipped: string; pendingBoxes: number; boxesOpened: number; fresh: string[] };
  collection: Record<string, { caught: boolean[]; shiny: boolean[]; fresh: boolean[] }>;
  unlockedSets: string[];
  activeSet: string;
  debug: { runs: { merges: number; maxLevel: number; ended: string; score: number }[] };
  schema: number;
  highscoreAvatar: string;
}

export const saved = (page: Page): Promise<Saved> => page.evaluate((k) => JSON.parse(localStorage.getItem(k)!), KEY);

/** DESIGN §16.2: gratismusslor vid 120 och 400 merges från baseline, sedan var 750:e. */
export function freeShellsFor(m: number): number {
  let n = 0;
  for (const t of [120, 400]) if (m >= t) n++;
  if (m >= 400) n += Math.floor((m - 400) / 750);
  return n;
}

/** Ekonomins invarianter som alltid ska hålla i en sparfil (DESIGN §16). */
export function checkInvariants(s: Saved): void {
  expect(s.economy.pearls, 'pärlor ≥ 0').toBeGreaterThanOrEqual(0);
  expect(s.economy.sand, 'sand ≥ 0').toBeGreaterThanOrEqual(0);
  expect(Number.isInteger(s.economy.pearls) && Number.isInteger(s.economy.sand)).toBe(true);
  expect(new Set(s.avatars.owned).size, 'inga dubbletter').toBe(s.avatars.owned.length);
  expect(s.avatars.owned.length + s.avatars.pendingBoxes).toBeLessThanOrEqual(48);
  expect(s.avatars.pendingBoxes).toBeGreaterThanOrEqual(0);
  expect(new Set(s.economy.milestones).size).toBe(s.economy.milestones.length);
  for (const id of s.avatars.owned) expect([1, 2, 3]).toContain(s.avatars.level[id]);
  if (s.avatars.equipped) expect(s.avatars.owned).toContain(s.avatars.equipped);
}

/** Pixlar ur en skärmdump (CSS-px), som [r,g,b] per punkt i logiska koordinater. */
export async function pixels(page: Page, pts: readonly (readonly [number, number])[]): Promise<number[][]> {
  const buf = await page.screenshot();
  const css = await Promise.all(pts.map(([x, y]) => toCanvas(page, x, y)));
  return page.evaluate(
    async ({ b64, css }) => {
      const img = await createImageBitmap(await (await fetch(`data:image/png;base64,${b64}`)).blob());
      const c = new OffscreenCanvas(img.width, img.height);
      const g = c.getContext('2d')!;
      g.drawImage(img, 0, 0);
      const k = img.width / window.innerWidth;
      return css.map(({ x, y }) => Array.from(g.getImageData(Math.round(x * k), Math.round(y * k), 1, 1).data.slice(0, 3)));
    },
    { b64: buf.toString('base64'), css },
  );
}

/** Ser pixeln guldig ut (THEME gold #FFD166-ish)? */
export const goldish = ([r, g, b]: number[]): boolean => r > 170 && g > 130 && b < 140 && r - b > 80;

/**
 * Känd bugg (docs/BUGS.md): testet beskriver rätt beteende och förväntas falla tills buggen är rättad.
 * Playwright larmar när det börjar passera. `QA_RAW=1` kör det som vanligt test (visar själva felet).
 */
export function knownBug(id: string, what: string): void {
  test.fail(!process.env.QA_RAW, `${id}: ${what}`);
}

/**
 * Trycker tills villkoret gäller (högst `tries` tryck), som en spelare som trycker igen när inget händer.
 * Returnerar antalet tryck. Boken tappar tryck när en frame tar >350 ms (BUG-010), vilket händer under CPU-last.
 */
export async function tapUntil(page: Page, pt: readonly [number, number], cond: () => boolean, tries = 3): Promise<number> {
  for (let i = 1; i <= tries; i++) {
    if (i < tries) await tap(page, pt);
    else await quickTap(page, pt);
    if (await page.waitForFunction(cond, undefined, { timeout: 3_000 }).then(() => true, () => false)) {
      if (i > 1) test.info().annotations.push({ type: 'BUG-010', description: `tap (${pt.join(', ')}) krävde ${i} tryck` });
      return i;
    }
  }
  throw new Error(`tap (${pt.join(', ')}): ingen effekt efter ${tries} tryck`);
}

/** Ned och upp i samma JS-uppgift (ett mycket snabbt tryck): båda hanteras före nästa frame. */
export async function quickTap(page: Page, [wx, wy]: readonly [number, number]): Promise<void> {
  const p = await toCanvas(page, wx, wy);
  await page.evaluate(({ x, y }) => {
    const c = document.querySelector('canvas')!;
    const at = { clientX: x, clientY: y, bubbles: true };
    c.dispatchEvent(new MouseEvent('mousedown', at));
    c.dispatchEvent(new MouseEvent('mouseup', at));
  }, p);
}

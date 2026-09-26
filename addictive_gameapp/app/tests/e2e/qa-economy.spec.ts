import { test, expect, type Page } from '@playwright/test';
import {
  BUDDIES,
  SHOP,
  SHOP_SLOTS,
  SHOTS,
  UPGRADE_BTN,
  checkInvariants,
  collectErrors,
  expectNoErrors,
  freeShellsFor,
  open,
  saved,
  seed,
  startRound,
  tap,
  waitStart,
} from './qa-util';

/** QA: ekonomin (DESIGN §16) över många rundor och köp, kontrollerad mot formlerna i designen. */

const RARITIES = ['common', 'uncommon', 'rare', 'epic', 'legendary', 'mythic'];
const FLOOR: Record<string, string> = { common: 'common', silver: 'uncommon', gold: 'rare' };
const PRICE: Record<string, { pearls: number; sand: number }> = {
  common: { pearls: 300, sand: 0 },
  silver: { pearls: 700, sand: 0 },
  gold: { pearls: 0, sand: 50 },
};
/** §16.3: [I→II pärlor, II→III pärlor, II→III sand]. */
const UPGRADE: Record<string, [number, number, number]> = {
  common: [80, 200, 4],
  uncommon: [100, 250, 6],
  rare: [150, 400, 10],
  epic: [200, 550, 15],
  legendary: [250, 700, 20],
  mythic: [300, 800, 24],
};

/** Merges i burken: par av nivå `level` på golvet, isär i x. */
async function mergePairs(page: Page, level: number, xs: number[]): Promise<void> {
  for (const x of xs) {
    await page.evaluate(([l, px]) => {
      window.__game!.spawn(l, px, 560);
      window.__game!.spawn(l, px + 4, 520);
    }, [level, x] as const);
    await page.waitForTimeout(250);
  }
  await page.waitForTimeout(900);
}

test('(QA) tio rundor via hookarna: pärlor, stjärnsand och gratismusslor följer §16', async ({ page }) => {
  test.setTimeout(180_000);
  const errors = collectErrors(page);
  await open(page, '&lang=en');
  await startRound(page);
  let prev = await saved(page);
  let openedFree = 0;
  for (let round = 1; round <= 10; round++) {
    await page.evaluate((r) => {
      window.__game!.seed(1000 + r);
      window.__game!.clear();
    }, round);
    await page.waitForTimeout(200);
    await mergePairs(page, round % 3, [70, 150, 230, 290].slice(0, 1 + (round % 4)));
    // Runda 4: nivå 10 skapas (sand +2, och engångsmilstolparna 7–10 ger +3 var).
    if (round === 4) {
      await page.evaluate(() => {
        window.__game!.clear();
        window.__game!.spawn(9, 110, 520);
        window.__game!.spawn(9, 250, 520);
      });
      await page.waitForTimeout(1200);
    }
    const granted = [0, 60, 30, 250, 0, 700, 10, 800, 0, 400][round - 1];
    await page.evaluate((n) => window.__game!.grantMerges(n), granted);
    const stars = await page.evaluate(() => window.__game!.fxCounts.stars);
    const level10 = round === 4 ? 1 : 0;
    await page.evaluate(() => window.__game!.forceLoss());
    await page.waitForFunction(() => window.__reveal?.tally.done === true, undefined, { timeout: 10_000 });
    const s = await saved(page);
    const run = s.debug.runs[s.debug.runs.length - 1];
    const tally = await page.evaluate(() => window.__reveal!.tally);
    const newMs = s.economy.milestones.filter((m) => !prev.economy.milestones.includes(m));
    const msSand = newMs.reduce((a, m) => a + (m.startsWith('page:') ? 10 : 3), 0);
    const dPearls = s.economy.pearls - prev.economy.pearls;
    const dSand = s.economy.sand - prev.economy.sand;
    const note = `round ${round}: merges ${run.merges} (+${granted} granted), pearls +${dPearls}, sand +${dSand} (milestones ${newMs.join(',') || '-'}, stars ${stars}, l10 ${level10}), free ${s.economy.freeShellsClaimed}`;
    test.info().annotations.push({ type: 'economy', description: note });
    expect(run.merges, note).toBeGreaterThan(0);
    expect(s.stats.merges - prev.stats.merges, note).toBe(run.merges + granted);
    expect(dPearls, note).toBe(run.merges);
    const rest = dSand - msSand - stars - 2 * level10;
    expect(rest, note).toBeGreaterThanOrEqual(0);
    expect(rest, note).toBeLessThanOrEqual(3); // kedjor ≥3, högst 3 per runda
    expect(tally.pearls, note).toBe(dPearls);
    expect(tally.sand, note).toBe(dSand);
    expect(s.economy.freeShellsClaimed, note).toBe(freeShellsFor(s.stats.merges - s.economy.mergesBaseline));
    expect(s.avatars.pendingBoxes + openedFree, note).toBe(s.economy.freeShellsClaimed);
    if (round === 4) expect(newMs, note).toEqual(expect.arrayContaining(['level7', 'level8', 'level9', 'level10']));
    checkInvariants(s);
    // Öppna varannan gratismussla direkt (samma väg som startskärmen).
    if (round % 2 === 0 && s.avatars.pendingBoxes > 0) {
      const r = await page.evaluate(() => window.__game!.openBox());
      expect(r).not.toBeNull();
      if (openedFree === 0) expect(r!.rarity).toBe('rare'); // första musslan i livet
      openedFree++;
    }
    prev = await saved(page);
    await tap(page, [180, 580]);
    await page.waitForFunction(() => window.__game !== undefined && !window.__game.over && window.__reveal === undefined, undefined, { timeout: 5_000 });
    await page.waitForTimeout(200);
  }
  // 60+30+250+700+10+800+400 = 2 250 beviljade + riktiga merges: minst 120, 400, 1 150, 1 900.
  expect(prev.economy.freeShellsClaimed).toBeGreaterThanOrEqual(4);
  expectNoErrors(errors);
});

test('(QA) butiken: varje musseltyp köpt med riktiga tryck, sedan hela poolen: golv, priser, inga dubbletter', async ({ page }) => {
  test.setTimeout(180_000);
  const errors = collectErrors(page);
  await seed(page, {
    schema: 2,
    economy: { pearls: 60000, sand: 3000 },
    stats: { runs: 1, merges: 0 },
    settings: { bookHintSeen: true, friendsHintSeen: true },
  });
  await open(page, '&lang=en');
  await tap(page, SHOP);
  await page.waitForFunction(() => window.__book?.tab === 'friends', undefined, { timeout: 10_000 });
  await page.waitForTimeout(600);
  await page.screenshot({ path: `${SHOTS}/economy-shop-rich.png` });
  const owned: string[] = [];
  for (const type of ['common', 'silver', 'gold'] as const) {
    const before = await page.evaluate(() => ({ p: window.__book!.shop.pearls, s: window.__book!.shop.sand }));
    await tap(page, SHOP_SLOTS[type]); // väcker
    await page.waitForTimeout(350);
    expect(await page.evaluate(() => window.__book!.shop.awake)).toBe(type);
    await page.screenshot({ path: `${SHOTS}/economy-shop-awake-${type}.png` });
    await tap(page, SHOP_SLOTS[type]); // köper
    await page.waitForFunction(() => window.__book!.shop.opening, undefined, { timeout: 5_000 });
    await page.waitForTimeout(700);
    await page.screenshot({ path: `${SHOTS}/economy-shop-open-${type}.png` });
    const r = await page.evaluate(() => window.__book!.shop.lastBuy!);
    if (owned.length === 0) expect(r.rarity).toBe('rare');
    expect(RARITIES.indexOf(r.rarity)).toBeGreaterThanOrEqual(RARITIES.indexOf(FLOOR[type]));
    expect(owned).not.toContain(r.avatarId);
    owned.push(r.avatarId);
    await page.waitForFunction(() => window.__book!.shop.openPhase === 'done', undefined, { timeout: 10_000 });
    await tap(page, [180, 320]);
    await page.waitForFunction(() => !window.__book!.shop.opening, undefined, { timeout: 5_000 });
    await page.waitForTimeout(500);
    const after = await page.evaluate(() => ({ p: window.__book!.shop.pearls, s: window.__book!.shop.sand }));
    expect(before.p - after.p).toBe(PRICE[type].pearls);
    expect(before.s - after.s).toBe(PRICE[type].sand);
  }
  await page.keyboard.press('Escape');
  await waitStart(page);
  await startRound(page);
  // Resten av poolen via samma kodväg (buyShell): guld tills tomt, sedan silver, sedan vanlig.
  const byRarity: Record<string, string> = {};
  for (const type of ['gold', 'silver', 'common'] as const) {
    for (let i = 0; i < 60; i++) {
      const b = await page.evaluate(() => window.__game!.economy);
      const r = await page.evaluate((t) => window.__game!.buyShell(t), type);
      const a = await page.evaluate(() => window.__game!.economy);
      if (!r) {
        expect(a).toEqual(b); // inget dras när det inte går
        break;
      }
      expect(RARITIES.indexOf(r.rarity), `${type} gav ${r.rarity}`).toBeGreaterThanOrEqual(RARITIES.indexOf(FLOOR[type]));
      expect(owned).not.toContain(r.avatarId);
      owned.push(r.avatarId);
      byRarity[r.rarity] ??= r.avatarId;
      expect(b.pearls - a.pearls).toBe(PRICE[type].pearls);
      expect(b.sand - a.sand).toBe(PRICE[type].sand);
    }
  }
  const s = await saved(page);
  expect(owned.length).toBe(48);
  expect(new Set(s.avatars.owned).size).toBe(48);
  checkInvariants(s);
  // Uppgradering I → II → III för en av varje raritet, exakta priser, sedan stopp på III.
  for (const r of RARITIES) {
    const id = byRarity[r] ?? s.avatars.owned.find((x) => x);
    if (!byRarity[r]) continue;
    for (const step of [0, 1]) {
      const b = await page.evaluate(() => window.__game!.economy);
      expect(await page.evaluate((x) => window.__game!.upgrade(x), id)).toBe(true);
      const a = await page.evaluate(() => window.__game!.economy);
      expect(b.pearls - a.pearls, `${r} steg ${step}`).toBe(UPGRADE[r][step]);
      expect(b.sand - a.sand, `${r} steg ${step}`).toBe(step === 0 ? 0 : UPGRADE[r][2]);
    }
    expect(await page.evaluate((x) => window.__game!.upgrade(x), id)).toBe(false);
    expect(await page.evaluate((x) => window.__game!.avatars.level[x], id)).toBe(3);
  }
  // Full bok: gratismusslan ger 10 stjärnsand, ingen mussla på hyllan.
  const e0 = await page.evaluate(() => window.__game!.economy);
  await page.evaluate(() => {
    window.__game!.grantMerges(130);
    window.__game!.forceLoss();
  });
  await page.waitForFunction(() => window.__reveal !== undefined, undefined, { timeout: 10_000 });
  await page.waitForTimeout(500);
  const f = await saved(page);
  expect(f.avatars.pendingBoxes).toBe(0);
  expect(f.economy.sand - e0.sand).toBeGreaterThanOrEqual(10);
  checkInvariants(f);
  await page.keyboard.press('Escape');
  await waitStart(page);
  await page.screenshot({ path: `${SHOTS}/economy-start-full.png` });
  await tap(page, SHOP);
  await page.waitForFunction(() => window.__book?.tab === 'friends', undefined, { timeout: 10_000 });
  await page.waitForTimeout(600);
  expect(await page.evaluate(() => window.__book!.shop.full)).toBe(true);
  await page.screenshot({ path: `${SHOTS}/economy-shop-full.png` });
  expectNoErrors(errors);
});

test('(QA) uppgradering till III med riktiga tryck; räcker inte ger skakning och ingen ändring', async ({ page }) => {
  const errors = collectErrors(page);
  // Lykt-Lisa (episk): 200, sedan 550 + 15. Precis nog för båda.
  await seed(page, {
    schema: 2,
    economy: { pearls: 750, sand: 15 },
    avatars: { owned: ['lisa'], equipped: 'lisa' },
    settings: { bookHintSeen: true, friendsHintSeen: true },
  });
  await open(page, '&lang=en');
  await tap(page, BUDDIES);
  await page.waitForFunction(() => window.__book?.stage?.id === 'lisa', undefined, { timeout: 10_000 });
  await page.waitForTimeout(600);
  await page.screenshot({ path: `${SHOTS}/economy-upgrade-I.png` });
  for (const [lvl, pearls, sand] of [[2, 550, 15], [3, 0, 0]] as const) {
    await tap(page, UPGRADE_BTN);
    await page.waitForTimeout(350);
    if ((await page.evaluate(() => window.__book!.stage!.level)) !== lvl) {
      expect(await page.evaluate(() => window.__book!.stage!.button)).toBe('awake');
      await tap(page, UPGRADE_BTN);
      await page.waitForTimeout(600);
    }
    expect(await page.evaluate(() => window.__book!.stage!.level)).toBe(lvl);
    expect(await page.evaluate(() => [window.__book!.shop.pearls, window.__book!.shop.sand])).toEqual([pearls, sand]);
  }
  expect(await page.evaluate(() => window.__book!.stage!.button)).toBe('max');
  await page.screenshot({ path: `${SHOTS}/economy-upgrade-III.png` });
  await tap(page, UPGRADE_BTN);
  await tap(page, UPGRADE_BTN);
  await page.waitForTimeout(400);
  const s = await saved(page);
  expect(s.avatars.level.lisa).toBe(3);
  expect(s.economy).toMatchObject({ pearls: 0, sand: 0 });
  checkInvariants(s);
  expectNoErrors(errors);
});

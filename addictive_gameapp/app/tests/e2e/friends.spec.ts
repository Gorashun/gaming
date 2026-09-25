import { test, expect, type Page } from '@playwright/test';
import './hook';

function collectErrors(page: Page): string[] {
  const errors: string[] = [];
  page.on('pageerror', (e) => errors.push(`pageerror: ${e.message}`));
  page.on('console', (m) => {
    if (m.type() === 'error') errors.push(`console: ${m.text()}`);
  });
  return errors;
}

async function tap(page: Page, wx: number, wy: number): Promise<void> {
  const box = (await page.locator('canvas').boundingBox())!;
  await page.mouse.move(box.x + (wx * box.width) / 360, box.y + (wy * box.height) / 640);
  await page.mouse.down();
  await page.mouse.up();
}

async function startGame(page: Page): Promise<void> {
  await page.waitForTimeout(1200);
  await tap(page, 180, 330);
  await page.waitForFunction(() => window.__game !== undefined, undefined, { timeout: 10_000 });
}

/** Sparfil förbi onboardingen. Skrivs bara första gången, så reload behåller progressionen. */
function seedSave(page: Page): Promise<void> {
  return page.addInitScript(() => {
    if (localStorage.getItem('klunk.save.v1')) return;
    localStorage.setItem('klunk.save.v1', JSON.stringify({ highscore: 500, bestLevel: 4, stats: { runs: 4, merges: 0 } }));
  });
}

interface SavedAvatars {
  owned: string[];
  equipped: string;
  pendingBoxes: number;
  boxesOpened: number;
}
const saved = (page: Page): Promise<SavedAvatars> =>
  page.evaluate(() => JSON.parse(localStorage.getItem('klunk.save.v1')!).avatars);

test('mussla: 120 merges ger en gratismussla på hyllan, öppning ger sällsynt, fliken Kompisar väljer avatar', async ({ page }) => {
  const errors = collectErrors(page);
  await seedSave(page);
  await page.goto('/?test=1');
  await startGame(page);

  // (a) 120 merges från baseline + förlust ⇒ en oöppnad gratismussla (DESIGN §16.2).
  await page.evaluate(() => {
    window.__game!.grantMerges(120);
    window.__game!.forceLoss();
  });
  await page.waitForFunction(() => window.__game!.pendingBoxes === 1, undefined, { timeout: 10_000 });
  await page.waitForTimeout(2500); // rundavslutet med musslan som flyger till hyllan
  expect(await page.evaluate(() => window.__game!.avatars.owned.length)).toBe(0);

  await page.reload();
  await page.waitForFunction(() => window.__start !== undefined, undefined, { timeout: 10_000 });
  await page.waitForTimeout(1200);
  await page.screenshot({ path: 'tests/e2e/screenshots/shelf-box.png' });

  await tap(page, 92, 450);
  // Fast 1,2 s i speltid; vänta tills öppningen är klar (headless kan gå långsammare).
  await page.waitForFunction(() => window.__start?.openPhase === 'done', undefined, { timeout: 10_000 });
  await page.screenshot({ path: 'tests/e2e/screenshots/box-open.png' });
  const first = await page.evaluate(() => window.__start!.lastBox);
  expect(first?.rarity).toBe('rare');
  let av = await saved(page);
  expect(av.owned).toEqual([first!.avatarId]);
  expect(av.equipped).toBe(first!.avatarId);
  expect(av.pendingBoxes).toBe(0);
  expect(await page.evaluate(() => window.__start!.opening)).toBe(true);

  // Ett tryck stänger öppningen.
  await tap(page, 180, 330);
  await page.waitForFunction(() => window.__start !== undefined && !window.__start.opening);

  // En andra avatar via hooken, så att det finns något att byta till.
  await startGame(page);
  const second = await page.evaluate(() => window.__game!.openBox()!.avatarId);
  expect(second).not.toBe(first!.avatarId);
  await page.reload();
  await page.waitForFunction(() => window.__start !== undefined, undefined, { timeout: 10_000 });
  await page.waitForTimeout(800);

  // (b) Boken öppnar på Kompisar (nya kompisar som inte visats) → tryck på den andra = vald, sparad.
  await tap(page, 238, 444);
  await page.waitForFunction(() => window.__book !== undefined, undefined, { timeout: 5_000 });
  expect(await page.evaluate(() => window.__book!.tab)).toBe('friends');
  await tap(page, 32, 40);
  expect(await page.evaluate(() => window.__book!.tab)).toBe('sets');
  await tap(page, 120, 40);
  expect(await page.evaluate(() => window.__book!.tab)).toBe('friends');
  const cell = await page.evaluate((id) => window.__book!.cellOf(id), second);
  expect(cell).not.toBeNull();
  await tap(page, cell!.x, cell!.y);
  av = await saved(page);
  expect(av.equipped).toBe(second);
  await page.waitForTimeout(300);
  await page.screenshot({ path: 'tests/e2e/screenshots/book-friends.png' });

  // Tillbaka till Set-fliken med hooken, sedan persistens efter omladdning.
  await page.evaluate(() => window.__book!.selectTab('sets'));
  expect(await page.evaluate(() => window.__book!.tab)).toBe('sets');
  await page.reload();
  await page.waitForTimeout(800);
  av = await saved(page);
  expect(av.equipped).toBe(second);
  expect(av.owned.length).toBe(2);
  expect(errors).toEqual([]);
});

test('48 öppningar via hooken ger 48 unika, sedan null', async ({ page }) => {
  const errors = collectErrors(page);
  await seedSave(page);
  await page.goto('/?test=1');
  await startGame(page);
  const res = await page.evaluate(() => {
    const ids: string[] = [];
    const rarities: string[] = [];
    for (let i = 0; i < 48; i++) {
      const r = window.__game!.openBox()!;
      ids.push(r.avatarId);
      rarities.push(r.rarity);
    }
    return { ids, rarities, extra: window.__game!.openBox(), owned: window.__game!.avatars.owned.length };
  });
  expect(new Set(res.ids).size).toBe(48);
  expect(res.rarities[0]).toBe('rare');
  expect(res.extra).toBeNull();
  expect(res.owned).toBe(48);

  // Boken med allt ägt: odds-burken är tom, inga fel vid rendering.
  await page.reload();
  await page.waitForTimeout(1200);
  await tap(page, 238, 444);
  await page.waitForFunction(() => window.__book !== undefined, undefined, { timeout: 5_000 });
  await page.evaluate(() => window.__book!.selectTab('friends'));
  await page.waitForTimeout(200);
  expect(errors).toEqual([]);
});

test('ekonomi via hooken: pärlor/sand, köp, uppgradering och pick3 sparas (DESIGN §16)', async ({ page }) => {
  const errors = collectErrors(page);
  await seedSave(page);
  await page.goto('/?test=1');
  await startGame(page);
  const res = await page.evaluate(() => {
    const g = window.__game!;
    const start = g.economy;
    const poor = g.buyShell('common');
    g.grantPearls(1000);
    g.grantSand(60);
    const first = g.buyShell('gold')!;
    const common = g.buyShell('common')!;
    const up = g.upgrade(first.avatarId);
    const upIII = g.upgrade(first.avatarId); // kräver 10 sand, finns 10
    g.setShopMode('pick3');
    g.grantPearls(300);
    const offer = g.offerPick3('common');
    const picked = g.buyPick('common', offer[0]);
    return { start, poor, first, common, up, upIII, offer, picked, mode: g.shopMode, eco: g.economy, av: g.avatars };
  });
  expect(res.start).toEqual({ pearls: 0, sand: 0, mergesBaseline: 0, freeShellsClaimed: 0, milestones: [] });
  expect(res.poor).toBeNull();
  expect(res.first.rarity).toBe('rare');
  expect(res.common).not.toBeNull();
  expect(res.up && res.upIII).toBe(true);
  expect(res.av.level[res.first.avatarId]).toBe(3);
  expect(res.mode).toBe('pick3');
  expect(new Set(res.offer).size).toBe(3);
  expect(res.picked?.avatarId).toBe(res.offer[0]);
  // Pärlor: 1000 − 300 (vanlig) − 150 (II) − 400 (III) + 300 − 300 (pick3) = 150. Sand: 60 − 50 (guld) − 10 (III) = 0.
  expect(res.eco).toMatchObject({ pearls: 150, sand: 0 });
  await page.reload();
  await page.waitForTimeout(800);
  const saved = await page.evaluate(() => JSON.parse(localStorage.getItem('klunk.save.v1')!));
  expect(saved.economy).toMatchObject({ pearls: 150, sand: 0 });
  expect(saved.avatars.level[res.first.avatarId]).toBe(3);
  expect(saved.avatars).not.toHaveProperty('xp');
  expect(errors).toEqual([]);
});

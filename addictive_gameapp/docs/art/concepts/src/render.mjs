import { createRequire } from 'node:module';
import fs from 'node:fs';
import { execSync } from 'node:child_process';
const require = createRequire('/home/user/gaming/addictive_gameapp/app/package.json');
const { chromium } = require('@playwright/test');
const here = new URL('.', import.meta.url).pathname;
const tmp = (await import('node:os')).tmpdir();
// Usage: node docs/art/concepts/src/render.mjs  → writes after-*.png to the OS temp dir (compose before/after by hand).
execSync(`/home/user/gaming/addictive_gameapp/app/node_modules/.bin/esbuild ${here}concepts.ts --bundle --format=iife --target=es2022 --outfile=${tmp}/klunk-concepts.js --log-level=warning`, { stdio: 'inherit' });
const font = fs.readFileSync('/home/user/gaming/addictive_gameapp/app/public/fonts/Fredoka-latin.woff2').toString('base64');
const html = `<!doctype html><html><body style="margin:0;background:#000"><script>window.FONT_URL='data:font/woff2;base64,${font}';</script><script>${fs.readFileSync(tmp + '/klunk-concepts.js', 'utf8')}</script></body></html>`;
const browser = await chromium.launch();
const page = await browser.newPage();
page.on('console', (m) => console.log('  [page]', m.text()));
page.on('pageerror', (e) => console.log('  [err]', e.message));
await page.setContent(html);
await page.waitForFunction(() => window.RESULT !== undefined, undefined, { timeout: 120000 });
const r = await page.evaluate(() => window.RESULT);
if (r.error) { console.log(r.error); process.exit(1); }
for (const [k, v] of Object.entries(r.out)) fs.writeFileSync(`${tmp}/after-${k}.png`, Buffer.from(v.split(',')[1], 'base64'));
console.log('bake ms', JSON.stringify(r.tm));
await browser.close();

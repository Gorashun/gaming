#!/usr/bin/env node
/**
 * Static release checks on a built dist (docs/RELEASE.md §Budgets). Cheap enough for every CI run.
 *
 *   node scripts/check-dist.mjs [dist]
 *
 * - JS gzip (level 9) against the size budget: fail above `fail`, warn above `warn`.
 * - The build version from scripts/version.mjs is baked into the bundle (`__APP_VERSION__`).
 * - No http(s) URL to a remote host in index.html (the app is offline: no INTERNET permission).
 */
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { gzipSync } from 'node:zlib';
import { appVersion } from './version.mjs';

/** KB (1024 B), gzip level 9. Keep in sync with the table in docs/RELEASE.md. */
export const BUDGETS = {
  jsGzipKB: { warn: 450, fail: 480 },
  distKB: { warn: 1900, fail: 2200 },
};

const dir = resolve(process.argv[2] ?? 'dist');
const walk = (d) => readdirSync(d).flatMap((f) => (statSync(join(d, f)).isDirectory() ? walk(join(d, f)) : [join(d, f)]));
const files = walk(dir);
const js = files.filter((f) => f.endsWith('.js'));
const kb = (b) => Math.round(b / 102.4) / 10;
const jsGzip = js.reduce((s, f) => s + gzipSync(readFileSync(f), { level: 9 }).length, 0);
const dist = files.reduce((s, f) => s + statSync(f).size, 0);

let failed = false;
const gh = !!process.env.GITHUB_ACTIONS;
function check(name, valueKB, b) {
  const tag = valueKB > b.fail ? 'FAIL' : valueKB > b.warn ? 'WARN' : 'ok';
  const line = `${name}: ${valueKB} KB (warn ${b.warn}, fail ${b.fail}) ${tag}`;
  if (tag === 'FAIL') {
    failed = true;
    console.error(gh ? `::error::${line}` : line);
  } else console.log(tag === 'WARN' && gh ? `::warning::${line}` : line);
}
check('JS gzip', kb(jsGzip), BUDGETS.jsGzipKB);
check('dist total', kb(dist), BUDGETS.distKB);

const version = appVersion().name;
const baked = js.some((f) => readFileSync(f, 'utf8').includes(version));
console.log(`version ${version}: ${baked ? 'baked into bundle' : 'MISSING from bundle'}`);
if (!baked) failed = true;

const html = readFileSync(join(dir, 'index.html'), 'utf8');
const remote = [...html.matchAll(/(?:src|href)="(https?:\/\/[^"]+)"/g)].map((m) => m[1]);
if (remote.length) {
  failed = true;
  console.error(`remote URLs in index.html: ${remote.join(', ')}`);
}
process.exit(failed ? 1 : 0);

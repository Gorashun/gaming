#!/usr/bin/env node
/**
 * The one source of the build version (docs/RELEASE.md §Versioning).
 *
 *   versionName = <major>.<minor from package.json>.<commit count>+<short sha>   e.g. 0.8.47+e4fe0b0
 *   versionCode = <commit count>                                                (Android, monotonic on main)
 *
 * Used by vite.config.ts (`__APP_VERSION__`) and by the Android workflow:
 *   node scripts/version.mjs            prints the JSON
 *   node scripts/version.mjs --github   appends name=… and code=… to $GITHUB_OUTPUT
 * CI must check out with full history (fetch-depth: 0), otherwise the count is 1.
 * Outside git (e.g. a source tarball) the version is <major>.<minor>.0+nogit and code 1.
 */
import { execFileSync } from 'node:child_process';
import { appendFileSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const appDir = join(dirname(fileURLToPath(import.meta.url)), '..');

function git(...args) {
  try {
    return execFileSync('git', args, { cwd: appDir, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
  } catch {
    return null;
  }
}

export function appVersion() {
  const pkg = JSON.parse(readFileSync(join(appDir, 'package.json'), 'utf8'));
  const [major, minor] = String(pkg.version).split('.');
  const count = Number(git('rev-list', '--count', 'HEAD'));
  const sha = git('rev-parse', '--short=7', 'HEAD');
  if (!count || !sha) return { name: `${major}.${minor}.0+nogit`, code: 1 };
  return { name: `${major}.${minor}.${count}+${sha}`, code: count };
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const v = appVersion();
  if (process.argv.includes('--github')) {
    appendFileSync(process.env.GITHUB_OUTPUT, `name=${v.name}\ncode=${v.code}\n`);
  }
  console.log(JSON.stringify(v));
}

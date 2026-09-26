# RELEASE.md: versioning, budgets and release checklists

Owner: release-engineer. Updated 2026-09-26 (test version 8, phase 1 release hygiene).
Related: `STUDIO_PLAN.md` (definition of done, items 5 and 7), `TEAM.md` (gates before a test release), `TECH.md` (stack).

---

## 1. Versioning

One source, `app/scripts/version.mjs`:

| Field | Rule | Example |
|---|---|---|
| `versionName` | `<major>.<minor from package.json>.<commit count>+<short sha>` | `0.8.52+fedf027` |
| `versionCode` (Android) | commit count of `HEAD` | `52` |

- The web bundle gets the name through Vite `define` (`__APP_VERSION__`, declared in `src/env.d.ts`, read via `src/data/version.ts`). Vitest has no define, so it sees `dev`.
- The workflow runs `node scripts/version.mjs --github` and passes `-PklunkVersionCode` / `-PklunkVersionName` to Gradle (`android/app/build.gradle`). A local Gradle build without these flags gets `1` / `0.0.0-local`.
- The version shows on one line at the bottom of the debug panel (long-press the logo for 2 s) and is included in the debug JSON export (`version`), so playtest logs say which build they came from.
- **Minor = test version.** Bump `package.json` `version` (and the two root entries in `package-lock.json`) from `0.8.0` to `0.9.0` when test version 9 starts. Patch is always the commit count, never edited by hand.
- CI checks out with `fetch-depth: 0`; with a shallow clone the count would be 1.
- `versionCode` only increases along one branch. Store builds must come from one branch (main), see §7.

## 2. CI (`.github/workflows/android.yml`)

On every push that touches `addictive_gameapp/app/**` or the workflow:

| Step | What it does | Fails the build when |
|---|---|---|
| Version | `scripts/version.mjs --github` | no git |
| Unit tests | `npm test` (Vitest) | any test fails |
| Build web | `npm run build` (`tsc --noEmit` + Vite) | type or build error |
| Size budget and version check | `scripts/check-dist.mjs dist` | JS gzip or dist over the fail budget, version missing from bundle, remote URL in `index.html` |
| Smoke test | `scripts/smoke.mjs --channel chrome`: boots `/?test=1` in the runner's Google Chrome, taps PLAY, drops one object | no body in the jar, any page or console error, over 2 min |
| Web artifact | uploads `dist` as `klunk-web-<version>` (30 days) | |
| APK | `cap sync`, `assembleDebug` with the version flags | Gradle error |
| Manifest permissions | reads the merged debug manifest | any `uses-permission` except `VIBRATE` (androidx's signature-level `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` is ignored) |
| Release | rolling `test-latest` prerelease with `klunk-debug.apk`; title and body carry the version, versionCode, APK size, link to the web artifact and the last 15 commits touching the app | |

The smoke step takes about 10 s (5 s locally). If the runner's Chrome ever becomes flaky, replace `--channel chrome` with a `npx playwright install chromium` step (about 30 s more). The full e2e suite stays with QA and is not run in CI.

## 3. App identity

- Sources: `app/assets-src/icon-background.svg`, `icon-foreground.svg` (jar from the logo's U, glowing level-0 Glimmer, cyan rim `#7CF9FF` on `#0B1020`), `icon-monochrome.svg` (Android 13 themed icon). The art director edits these. Everything else is generated.
- Generator: `node scripts/gen-icons.mjs [--preview <png>]` renders with Playwright's Chromium from `/opt/pw-browsers`. It writes:
  - adaptive layers `mipmap-*/ic_launcher_{foreground,background,monochrome}.png` (108 dp, mdpi to xxxhdpi) and `mipmap-anydpi-v26/ic_launcher{,_round}.xml`
  - legacy `ic_launcher.png` / `ic_launcher_round.png` (48 dp) for API 24–25
  - `drawable-*/splash_icon.png` for the Android 12+ system splash (288 dp canvas, art inside the 192 dp circle)
  - `drawable/splash.xml` for API 24–30: radial sea gradient plus the splash icon, as a layer-list, so the APK carries no full-screen bitmaps
- `values/styles.xml` launch theme: `windowSplashScreenBackground` `#0B1020`, `windowSplashScreenAnimatedIcon` `@drawable/splash_icon`. Before this change, Android 12+ showed the default icon on the default background.
- The review sheet is `docs/ui-preview-app-icon.png` (safe circle, circle/squircle/square masks, themed icon, both splashes, legacy icons). **The art director's sign-off is pending.**
- App name `KLUNK`, portrait lock, no `INTERNET` permission: unchanged, now checked in CI.

## 4. Budgets

### 4.1 Method (`node scripts/measure.mjs --dir <build> --port 4191`)

- Headless Chromium 1194 (`/opt/pw-browsers`), viewport 390×844, touch, DPR 1 and 2. WebGL runs on **SwiftShader (CPU)**, so absolute fps is far below a phone's GPU. Use these numbers to spot regressions between builds on the same machine. They do not predict fps on a device.
- **Cold start**: fresh context (empty cache), `/?test=1`, from navigation start to the first animation frame after the Start scene installed `window.__start` (the first frame that accepts a tap). Median of 5 to 8 runs, with CPU throttling at 1× and 4× (4× is roughly a mid-range phone).
- **Texture memory**: live WebGL `texImage2D` allocations at that frame, w·h·4 bytes. Render targets (framebuffers) are counted separately.
- **Bench fps**: `/?bench=1` (about 2000 additive particles), 3 s warm-up, then 5 s of frames. Only measured at 1×.
- **Bundle**: gzip level 9 of every JS file (Vite's report uses a lower level and shows about 3 % more).

### 4.2 Measured, build 0.8.50+991b5a7 (2026-09-26)

The container had load 8–11 on 4 cores during the runs because QA's e2e was running in parallel. The ranges below are real spread.

| Metric | DPR 1 | DPR 2 | Notes |
|---|---|---|---|
| JS gzip, all loaded at startup | 419.6 KB (1504 KB raw) | same | Phaser ≈ 307 KB gzip, game code ≈ 111 KB, Capacitor web shims 1.3 KB (lazy) |
| dist total | 1541 KB | same | includes Fredoka woff2 29 KB |
| Debug APK | 4.68 MB (CI, 25a855f) | | expected about +0.85 MB from the new icon and splash PNGs |
| Cold start → interactive, 1× CPU | **729 ms** (659–967) | **1143 ms** (880–1440) | interleaved run, 8 runs. Sequential runs under higher load: 1059–1107 / 1438–1826 ms |
| Cold start → interactive, 4× CPU | **2082 ms** (2032–2309) | **2825 ms** (2643–3433) | sequential runs: 2195–2455 / 3152–3299 ms |
| First contentful paint | 230–420 ms | 220–410 ms | black page with canvas |
| Texture memory after Boot | **24.8 MB** (177 textures) | **99.2 MB** (210) | render targets are 15.9 MB of DPR 1 and **84.5 MB** of DPR 2, see §5.1 |
| JS heap after Boot | 20 MB | 23–28 MB | |
| Bench fps (SwiftShader) | 10.7–12.0 fps, p95 frame 150 ms | 2.9–5.1 fps, p95 300–720 ms | CPU-rendered, regression tracking only |

### 4.3 Proposed budgets

| Metric | Warn | Fail | Enforced |
|---|---|---|---|
| JS gzip (all chunks) | 450 KB | 480 KB | CI (`check-dist.mjs`) |
| dist total | 1900 KB | 2200 KB | CI |
| Debug APK | 6.5 MB | 8 MB | release checklist (size is in the release body) |
| Cold start, headless 1× | DPR 1 900 ms / DPR 2 1400 ms (median) | +25 % vs the last release on the same machine | release checklist (`measure.mjs`) |
| Cold start, headless 4× | DPR 1 2500 ms / DPR 2 3500 ms | +25 % vs last release | release checklist |
| Cold start on a phone (tap icon → PLAY tappable) | 3 s | 4 s | manual, on the reference phone |
| Texture memory after Boot | DPR 1 16 MB / DPR 2 48 MB | DPR 2 64 MB | release checklist. **Over budget today (99 MB), fix known, see §5.1** |
| Bench fps headless | −15 % vs last release | −25 % | release checklist |
| Game fps on device | ≥ 55 fps at Z=2 | the fps guard trips (45 fps) | manual, debug panel zoom line |

## 5. Findings

### 5.1 Phaser FX render targets (P2, texture budget): for game-programmer

Phaser 3.90 allocates a pool of render targets at boot for the built-in Pre-FX and Post-FX pipelines. There are 3 square targets per 32 px step up to the canvas's short side, plus full-screen targets. KLUNK uses no `preFX`/`postFX`: a grep of `src/` finds nothing. At DPR 2 that is 66 squares of 32² to 704² plus 11 full-screen 720×1280 targets, **84.5 MB** in total.

Tested on a scratch copy with `disablePreFX: true, disablePostFX: true` in the `Phaser.Game` config (`src/main.ts`):

| | Textures DPR 1 | Textures DPR 2 | Cold start 1× DPR 1 / DPR 2 | 4× DPR 1 / DPR 2 |
|---|---|---|---|---|
| now | 24.8 MB | 99.2 MB | 729 / 1143 ms | 2082 / 2825 ms |
| FX disabled | **15.0 MB** | **39.4 MB** | 714 / 1045 ms | 2015 / 2688 ms |

That is −60 % texture memory at DPR 2 and 2–9 % faster cold start. The change is two lines in `main.ts` (owned by game-programmer) and needs a QA e2e pass. A future `postFX` (bloom, glow) would have to turn them back on and pay for it.

### 5.2 Phaser in its own chunk: tried, not kept

With the split (`phaser` chunk 1197 KB raw, game chunk 342 KB, `modulepreload`), 3-way interleaved runs over 8 rounds gave these medians (unsplit → split):

| | 1× DPR 1 | 1× DPR 2 | 4× DPR 1 | 4× DPR 2 |
|---|---|---|---|---|
| cold start | 729 → 699 ms | 1143 → 1090 ms | 2082 → 2121 ms | 2825 → 2800 ms |

The differences are −4 % to +2 %, well inside the spread (±300 ms). Earlier sequential runs looked better for the split, but load drifted between them. In the APK, files load from local assets, so a separate Phaser chunk would not bring a cache win either. Revisit only if the web test link gets returning players, where an unchanged Phaser chunk would stay cached.

### 5.3 Other notes
- The whole game is in one startup chunk. The next cold-start gain, if needed, is lazy-loading the Book and Game scenes. That is not worth it at today's numbers.
- The `test-latest` tag is never moved by `action-gh-release`, so it still points at an old commit. The release body names the right commit. And pushes from any branch overwrite the rolling release, see §8.

## 6. Test-release checklist

Copy into `STATUS.md` for each test version and tick every line.

- [ ] **Gates (TEAM.md):** QA three green full e2e runs in a row, no open P1 in `BUGS.md`; art sign-off on changed screens; child-safety review for retention, reward or randomness changes; legal review for new names, characters, sets, sounds or store text.
- [ ] **Build:** CI run green on the release commit: unit tests, size budget, smoke, APK, manifest permissions.
- [ ] **Tests:** `npm test` green locally; QA's e2e runs are logged with the commit.
- [ ] **Manifest permissions:** CI step says `permissions: android.permission.VIBRATE`, and there is no `INTERNET`.
- [ ] **Size:** `check-dist` shows ok or warn with a reason; the APK size in the release body is under 6.5 MB, or the reason is logged.
- [ ] **Performance:** `node scripts/measure.mjs --dir <build>` compared with §4.2; any budget in §4.3 over warn is reported to the producer.
- [ ] **Version:** the release title shows `0.<test version>.<count>+<sha>`, the debug panel shows the same string on the phone, versionCode is higher than the previous release, and `package.json` minor = test version.
- [ ] **Device check** (reference phone): install over the previous build (the save survives), fresh install, icon on the home screen (adaptive mask, themed icon on Android 13+), splash is dark with the jar and has no white flash, portrait lock, back button, sound and vibration toggles, no network permission prompt.
- [ ] **Changelog:** the release body lists the commits. The producer writes the human changelog ("what's new for testers") in `PLAYTEST.md`/`STATUS.md`.
- [ ] **Web build:** the `klunk-web-<version>` artifact exists; the test link is updated.

## 7. Store-release checklist (Google Play, later)

- [ ] **Account** (Anders: money and accounts): Play Console developer account. New personal accounts must run a **closed test with at least 12 testers for 14 days in a row** before production access.
- [ ] **Signing:** Play App Signing with an upload key. Anders creates the keystore locally and keeps it outside the repo. CI gets it only through GitHub secrets `KEYSTORE_B64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`. `build.gradle` reads them from the environment in a `signingConfigs.release` block. Never commit a keystore, `.jks` or passwords.
- [ ] **AAB:** `./gradlew bundleRelease` with the version flags, uploaded as a workflow artifact (not attached to a public release). Only from `main`, so versionCode stays monotonic.
- [ ] **Target API:** `targetSdkVersion` 36 (already meets Play's current requirement); `minSdk` 24.
- [ ] **Data safety form:** no data collected or shared, no network access. The save lives only on the device (Capacitor Preferences). `android:allowBackup="true"` means Android Auto Backup may copy the save to the user's own Google backup. That is not collection by us; decide whether to keep it (§8).
- [ ] **Families / target audience:** the audience includes children under 13, so the Families Policy applies: no ads SDK, no third-party SDKs that collect data, appropriate content. Declare "no ads".
- [ ] **Content rating (IARC):** fill in the questionnaire in Play Console. The shell mechanic is random items **without real money**; answer accordingly (no in-app purchases, no gambling with real money). The child-safety reviewer checks the answers against `docs/reviews/`. PEGI 7 is already accepted for the daily-return lanes.
- [ ] **Privacy policy URL:** required for apps whose audience includes children, even when nothing is collected. The text says no data collected, no network, local save only, how to delete (uninstall or the reset button). It needs a public host (GitHub Pages or similar). Legal review.
- [ ] **Store listing:** title, short and long description (legal review), 512×512 icon and 1024×500 feature graphic (can be rendered from `assets-src/` with the same generator), phone screenshots. Contact e-mail (Anders).
- [ ] **Release build hardening:** decide `minifyEnabled`/R8 for the release type; remove `?test` hooks from the release web build or confirm they are inert.

## 8. Open decisions (producer)

1. Route §5.1 (`disablePreFX`/`disablePostFX`) to game-programmer. It is the only item over budget.
2. Rolling release trigger: today, pushes from **any** branch overwrite `test-latest`. Restrict publishing to the team branch or `main`, and let other branches build artifacts only?
3. Moving the `test-latest` tag to the released commit needs a `git push --force` of the tag from CI. Accept that, or keep relying on the release body?
4. Minor-bump convention (`package.json` minor = test version): confirm.
5. Keep `android:allowBackup="true"` (the save survives phone changes) or turn it off (simpler data-safety story)?
6. APK growth of about 0.85 MB for crisp icons and splash at five densities: accept, or ship `splash_icon` only at xhdpi and up (saves about 80 KB)?
7. Store items that need Anders: Play account, privacy-policy hosting, 12-tester closed test.

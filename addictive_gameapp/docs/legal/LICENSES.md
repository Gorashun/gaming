# KLUNK: licence inventory

Owner: legal-reviewer. Last checked 2026-09-26 against `app/package-lock.json` (app version 0.8.0), `app/android/*.gradle`, `app/public/fonts/` and the built `app/dist/`. Findings and risk ratings are in [`ip-review-2026-09-26.md`](ip-review-2026-09-26.md). This inventory is not legal advice.

## 1. Status in one line

**Not compliant yet.** The Fredoka OFL text ships ✓. The MIT/ISC/BSD notices for the JavaScript that ships, and the Apache-2.0 notices for the Android libraries, are **not** in the app. The committed launcher icon and splash are still Capacitor's logo; a replacement from our own SVGs is in progress but uncommitted. Fixes are in §5.

## 2. What actually ships in the APK

| Component | Version | Licence | Copyright / notice holder | How it ships |
|---|---|---|---|---|
| **phaser** | 3.90.0 | MIT | © 2024 Richard Davey, Phaser Studio Inc. | Minified into `dist/assets/index-*.js` |
| ↳ matter-js (embedded in Phaser, `src/physics/matter-js`) | Phaser's fork | MIT | © Liam Brummitt and contributors | Same bundle (the game uses Matter physics) |
| ↳ earcut (embedded, `geom/polygon/Earcut.js`) | – | ISC | © 2016 Mapbox | Same bundle |
| ↳ rbush / quickselect / simplify-js (embedded: `structs/RTree.js`, `utils/array/QuickSelect.js`, `geom/polygon/Simplify.js`) | – | MIT / ISC / BSD-2-Clause | © Vladimir Agafonkin | Same bundle (full Phaser build) |
| ↳ AudioContextMonkeyPatch (`polyfills/`) | – | Apache-2.0 | © 2013 Chris Wilson | Present in Phaser's source. Probably not reached in the bundle; list it anyway to be safe. |
| **eventemitter3** (Phaser dependency) | 5.0.4 | MIT | © 2014 Arnout Kazemier | Same bundle |
| **@capacitor/core** | 8.5.2 | MIT | © 2017-present Drifty Co. (Ionic) | Same bundle |
| **@capacitor/app** | 8.1.1 | MIT | © 2020-present Ionic | JS + Android native plugin |
| **@capacitor/haptics** | 8.0.2 | MIT | © 2020-present Ionic | JS + Android native plugin (adds the `VIBRATE` permission) |
| **@capacitor/preferences** | 8.0.1 | MIT | © 2020-present Ionic | JS + Android native plugin |
| **@capacitor/android** | 8.5.2 | MIT | © 2017-present Drifty Co. | Native bridge (Java) + `native-bridge.js` |
| androidx.appcompat:appcompat | 1.7.1 | Apache-2.0 | The Android Open Source Project | Gradle (not in package-lock) |
| androidx.core:core | 1.17.0 | Apache-2.0 | AOSP | Gradle |
| androidx.activity:activity | 1.11.0 | Apache-2.0 | AOSP | Gradle |
| androidx.fragment:fragment | 1.8.9 | Apache-2.0 | AOSP | Gradle |
| androidx.coordinatorlayout:coordinatorlayout | 1.3.0 | Apache-2.0 | AOSP | Gradle |
| androidx.webkit:webkit | 1.14.0 | Apache-2.0 | AOSP | Gradle |
| androidx.core:core-splashscreen | 1.2.0 | Apache-2.0 | AOSP | Gradle |
| org.apache.cordova:framework | 14.0.1 | Apache-2.0 **with NOTICE** | The Apache Software Foundation | Gradle (Capacitor's Cordova compatibility layer) |
| Transitive AndroidX / Kotlin stdlib / annotation libraries | various | Apache-2.0 | AOSP / JetBrains | Gradle. Generate the exact list with `./gradlew :app:dependencies --configuration releaseRuntimeClasspath` or a licence plugin (§5). |
| **Fredoka** (font, latin subset, variable weight 300–700, v2.001) | 2.001 | SIL OFL 1.1 | © 2016 The Fredoka Project Authors (github.com/hafontia/Fredoka-One). **No Reserved Font Name**, so the subset may keep the name "Fredoka" | `public/fonts/Fredoka-latin.woff2` + `Fredoka-OFL.txt` → `dist/fonts/` → APK assets ✓ |

### Own and generated assets (ship, owned by the project)

| Asset | Source | Licence / status |
|---|---|---|
| All 48 buddies, 55 level skins (5 sets × 11), bomb, rainbow, shells, pearls, icons | Drawn at runtime from primitives in `app/src/data/avatars.ts`, `theme.ts`, `themes.ts`, `art.ts`, the Canvas2D renderers and inline SVG in `app/src/ui/icons.ts` | Original to KLUNK. No third-party art. See the AI-authorship note in the IP review §9.8. |
| All sounds | Synthesized with WebAudio from parameters in the data files | Original. No samples. The Maestro melody is the traditional tune *Ah! vous dirai-je, maman* (1761), which is public domain. |
| UI text, store text, names | The team | Original. Renames pending (IP review §1). |
| **Launcher icon and splash**: committed version (`android/app/src/main/res/mipmap-*`, `drawable*/splash.png`) | **Capacitor template default (Ionic/Capacitor logo)** | **Not ours (HIGH).** Being replaced; see the next row. |
| Launcher icon and splash: replacement in the working tree (uncommitted 2026-09-26) | `app/assets-src/icon-background.svg`, `icon-foreground.svg`, `icon-monochrome.svg`, rendered to PNG by `scripts/gen-icons.mjs` (Playwright/Chromium, build tool only) | Original to KLUNK, with no fonts or external references in the SVGs. OK once committed. |
| `docs/ui-preview-*.png` | Generated review images | Not shipped |

## 3. Build-time only (do not ship)

`@capacitor/cli` is listed under `dependencies` in `package.json`, so npm marks it and its ~90 transitive packages as non-dev. They are **CLI tooling for `cap sync`** and are not bundled into the web build or the APK. No notice is required in the app for them. Recommendation: move `@capacitor/cli` to `devDependencies` (release-engineer) so the lockfile tells the truth.

Dev dependencies (not shipped, 137 packages in the lock): `@playwright/test` 1.56.1 (Apache-2.0), `typescript` 5.9.3 (Apache-2.0), `vite` 8.3.0 (MIT), `vitest` 3.2.7 (MIT), `rolldown` 1.2.9 (MIT), `esbuild` 0.28.2 (MIT), `lightningcss` 1.33.0 (**MPL-2.0**, build tool only; fine unless modified and distributed). Licence totals: MIT 116, MPL-2.0 12, Apache-2.0 6, ISC 2, BSD-3-Clause 1.

## 4. Full non-dev inventory from `package-lock.json` (103 packages)

Licence totals: MIT 77, ISC 11, BlueOak-1.0.0 10, Unlicense 2, Apache-2.0 2, 0BSD 1. There are no copyleft (GPL/LGPL/AGPL) or non-commercial licences.

| Package | Version | Licence | Ships in app? |
|---|---|---|---|
| @capacitor/android | 8.5.2 | MIT | **yes** |
| @capacitor/app | 8.1.1 | MIT | **yes** |
| @capacitor/cli | 8.5.2 | MIT | no (CLI, build time) |
| @capacitor/core | 8.5.2 | MIT | **yes** |
| @capacitor/haptics | 8.0.2 | MIT | **yes** |
| @capacitor/preferences | 8.0.1 | MIT | **yes** |
| @ionic/cli-framework-output | 2.2.8 | MIT | no (build tool) |
| @ionic/utils-array | 2.1.6 | MIT | no (build tool) |
| @ionic/utils-fs | 3.1.7 | MIT | no (build tool) |
| fs-extra (nested) | 9.1.0 | MIT | no (build tool) |
| @ionic/utils-object | 2.1.6 | MIT | no (build tool) |
| @ionic/utils-process | 2.1.12 | MIT | no (build tool) |
| @ionic/utils-stream | 3.1.7 | MIT | no (build tool) |
| @ionic/utils-subprocess | 3.0.1 | MIT | no (build tool) |
| @ionic/utils-terminal | 2.3.5 | MIT | no (build tool) |
| @isaacs/fs-minipass | 4.0.1 | ISC | no (build tool) |
| @types/fs-extra | 8.1.5 | MIT | no (build tool) |
| @types/node | 26.6.2 | MIT | no (build tool) |
| @types/slice-ansi | 4.0.0 | MIT | no (build tool) |
| @xmldom/xmldom | 0.9.12 | MIT | no (build tool) |
| ansi-regex | 5.0.1 | MIT | no (build tool) |
| ansi-styles | 4.3.0 | MIT | no (build tool) |
| astral-regex | 2.0.0 | MIT | no (build tool) |
| at-least-node | 1.0.0 | ISC | no (build tool) |
| balanced-match | 4.0.4 | MIT | no (build tool) |
| base64-js | 1.5.1 | MIT | no (build tool) |
| big-integer | 1.6.52 | Unlicense | no (build tool) |
| bplist-creator | 0.1.0 | MIT | no (build tool) |
| bplist-parser | 0.3.2 | MIT | no (build tool) |
| brace-expansion | 5.0.12 | MIT | no (build tool) |
| buffer-crc32 | 0.2.13 | MIT | no (build tool) |
| chownr | 3.0.0 | BlueOak-1.0.0 | no (build tool) |
| color-convert | 2.0.1 | MIT | no (build tool) |
| color-name | 1.1.4 | MIT | no (build tool) |
| commander | 12.1.0 | MIT | no (build tool) |
| cross-spawn | 7.0.6 | MIT | no (build tool) |
| debug | 4.4.3 | MIT | no (build tool) |
| define-lazy-prop | 2.0.0 | MIT | no (build tool) |
| elementtree | 0.1.7 | Apache-2.0 | no (build tool) |
| emoji-regex | 8.0.0 | MIT | no (build tool) |
| env-paths | 2.2.1 | MIT | no (build tool) |
| eventemitter3 | 5.0.4 | MIT | **yes** |
| fd-slicer | 1.1.0 | MIT | no (build tool) |
| fs-extra | 11.4.0 | MIT | no (build tool) |
| glob | 13.0.6 | BlueOak-1.0.0 | no (build tool) |
| graceful-fs | 4.2.11 | ISC | no (build tool) |
| inherits | 2.0.4 | ISC | no (build tool) |
| ini | 4.1.3 | ISC | no (build tool) |
| is-docker | 2.2.1 | MIT | no (build tool) |
| is-fullwidth-code-point | 3.0.0 | MIT | no (build tool) |
| is-wsl | 2.2.0 | MIT | no (build tool) |
| isexe | 2.0.0 | ISC | no (build tool) |
| jsonfile | 6.2.1 | MIT | no (build tool) |
| kleur | 4.1.5 | MIT | no (build tool) |
| lru-cache | 11.5.3 | BlueOak-1.0.0 | no (build tool) |
| minimatch | 10.2.6 | BlueOak-1.0.0 | no (build tool) |
| minipass | 7.1.3 | BlueOak-1.0.0 | no (build tool) |
| minizlib | 3.1.0 | MIT | no (build tool) |
| ms | 2.1.3 | MIT | no (build tool) |
| native-run | 2.0.3 | MIT | no (build tool) |
| open | 8.4.2 | MIT | no (build tool) |
| package-json-from-dist | 1.0.1 | BlueOak-1.0.0 | no (build tool) |
| path-key | 3.1.1 | MIT | no (build tool) |
| path-scurry | 2.0.2 | BlueOak-1.0.0 | no (build tool) |
| pend | 1.2.0 | MIT | no (build tool) |
| phaser | 3.90.0 | MIT | **yes** |
| plist | 3.1.1 | MIT | no (build tool) |
| prompts | 2.4.2 | MIT | no (build tool) |
| kleur (nested) | 3.0.3 | MIT | no (build tool) |
| readable-stream | 3.6.2 | MIT | no (build tool) |
| rimraf | 6.1.3 | BlueOak-1.0.0 | no (build tool) |
| safe-buffer | 5.2.1 | MIT | no (build tool) |
| sax | 1.1.4 | ISC | no (build tool) |
| semver | 7.8.5 | ISC | no (build tool) |
| shebang-command | 2.0.0 | MIT | no (build tool) |
| shebang-regex | 3.0.0 | MIT | no (build tool) |
| signal-exit | 3.0.7 | ISC | no (build tool) |
| simple-plist | 1.3.1 | MIT | no (build tool) |
| bplist-parser (nested) | 0.3.1 | MIT | no (build tool) |
| sisteransi | 1.0.5 | MIT | no (build tool) |
| slice-ansi | 4.0.0 | MIT | no (build tool) |
| split2 | 4.2.0 | ISC | no (build tool) |
| stream-buffers | 2.2.0 | Unlicense | no (build tool) |
| string_decoder | 1.3.0 | MIT | no (build tool) |
| string-width | 4.2.3 | MIT | no (build tool) |
| strip-ansi | 6.0.1 | MIT | no (build tool) |
| tar | 7.5.22 | BlueOak-1.0.0 | no (build tool) |
| through2 | 4.0.2 | MIT | no (build tool) |
| tree-kill | 1.2.2 | MIT | no (build tool) |
| tslib | 2.8.1 | 0BSD | no (build tool) |
| undici-types | 8.9.0 | MIT | no (build tool) |
| universalify | 2.0.1 | MIT | no (build tool) |
| untildify | 4.0.0 | MIT | no (build tool) |
| util-deprecate | 1.0.2 | MIT | no (build tool) |
| uuid | 7.0.3 | MIT | no (build tool) |
| which | 2.0.2 | ISC | no (build tool) |
| wrap-ansi | 7.0.0 | MIT | no (build tool) |
| xcode | 3.0.1 | Apache-2.0 | no (build tool) |
| xml2js | 0.6.2 | MIT | no (build tool) |
| xmlbuilder (nested) | 11.0.1 | MIT | no (build tool) |
| xmlbuilder | 15.1.1 | MIT | no (build tool) |
| yallist | 5.0.0 | BlueOak-1.0.0 | no (build tool) |
| yauzl | 2.10.0 | MIT | no (build tool) |
"yes" = in the web bundle or the Android build. eventemitter3 ships because Phaser imports it. Everything else under `@ionic/*`, `native-run`, `xcode`, `plist`, `tar`, `glob` and so on is pulled in by `@capacitor/cli`.

## 5. Does the app ship the required notices? What to do

| Licence family | What it requires when shipping | Today | Needed |
|---|---|---|---|
| MIT / ISC / BSD-2 / 0BSD | Include the copyright line and licence text "in all copies or substantial portions" (0BSD: nothing) | ✗ The minified bundle has no licence comments (checked: 0 `@license`/`Copyright` strings in `dist/assets/index-*.js`) | A notices file plus an in-app screen |
| Apache-2.0 (AndroidX, Cordova, Kotlin) | Give a copy of the licence, keep NOTICE texts (Cordova: "Apache Cordova · Copyright 2012 The Apache Software Foundation · This product includes software developed at The Apache Software Foundation"), and mark any modified files | ✗ | Include the Apache-2.0 text once, plus Cordova's NOTICE |
| SIL OFL 1.1 (Fredoka) | Ship the copyright notice and licence with the font. Don't sell the font by itself. Reserved names: none | ✓ `fonts/Fredoka-OFL.txt` ships next to the font | Also show it in the Licenses screen (good practice) |

### Recommended implementation (owners in brackets; no code was changed in this review)

1. **Generate notices at build time** [release-engineer]:
   - JS: add `rollup-plugin-license` (MIT) or run `npx license-checker-rseidelsohn --production --customPath` in CI. Write `dist/THIRD_PARTY_NOTICES.txt` with each shipped package's copyright and licence text. Add Phaser's embedded components by hand (matter-js, earcut, rbush/quickselect/simplify, the AudioContext patch).
   - Android: use the AboutLibraries Gradle plugin (Apache-2.0) or a hand-maintained list of the eight direct libraries plus the resolved transitive list. Include the Apache-2.0 text once and Cordova's NOTICE.
   - Fail CI if a new dependency has a licence outside the allowlist: MIT, ISC, BSD-2/3-Clause, 0BSD, Apache-2.0, Unlicense, BlueOak-1.0.0, OFL-1.1 (MPL-2.0 dev only). Block GPL/LGPL/AGPL/SSPL/CC-BY-NC.
2. **In-app "Licenses" screen** [game-ui-designer + game-programmer]:
   - A row at the bottom of the settings bottom sheet (the cog on Start v2) labelled **"Licenses" / "Licenser"** (≤ 10 characters ✓), opening a plain scrollable text page. It needs no network. Close with the usual ×.
   - Content, in this order: "KLUNK © 2026 Anders Ferrer. All rights reserved." → "Font: Fredoka, SIL Open Font License 1.1" (full OFL text) → the JS libraries (from `THIRD_PARTY_NOTICES.txt`) → the Android libraries plus the Apache-2.0 text and Cordova NOTICE → "Melody: 'Twinkle, Twinkle' (traditional)".
   - Keep it text only, readable in Calm mode, EN/SV headings, licence texts in English (the original language).
3. **Finish replacing the launcher icon and splash** [release-engineer + art-director]. The work in progress (`assets-src/` + `scripts/gen-icons.mjs`) is the right approach. Commit it and check the APK before any build leaves internal testing.
4. **Store listing:** no licence text is needed in the listing. A privacy-policy URL is needed (IP review §6).
5. **Keep this file current:** update §2 and §4 on every dependency bump (for example the CI job prints a diff), and re-verify before each store release.

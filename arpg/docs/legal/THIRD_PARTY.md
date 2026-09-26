# THIRD_PARTY: licenses, attribution and asset sourcing

> Owner: legal-counsel. Date: 2026-09-26. Not legal advice. Have a lawyer review this before commercial launch.
> Rule: **nothing third-party enters `arpg/game/` unless it is listed here (tools/code/fonts) or in `ASSET_SOURCES.md` (art/audio assets).**

## 1. Summary table

| Component | License | Shipped in the app? | Obligation |
|---|---|---|---|
| Godot Engine 4.7.x runtime and export templates | MIT | Yes | Include the Godot MIT text in-app (§2) |
| Godot's bundled third-party libs (FreeType, HarfBuzz, ICU, mbedTLS, ENet, Jolt, libpng, zlib, Zstd, Basis Universal, ThorVG, etc., roughly 100 entries) | MIT / BSD / Apache-2.0 / FTL / zlib / Unicode / OFL (fonts) | Yes | Include `GODOT_COPYRIGHT.txt` or `Engine.get_copyright_info()` output in-app (§2) |
| Android: AndroidX fragment, core-splashscreen, documentfile, Kotlin stdlib (pulled in by Godot's Gradle template) | Apache-2.0 | Yes (Android) | List them with the Apache-2.0 text in the licenses screen |
| iOS runtime extras (e.g. MoltenVK, if the Vulkan path is used) | Apache-2.0 | Possibly | **UNVERIFIED.** Check the iOS export template contents at M6 |
| Fonts (Google Fonts, SIL OFL 1.1) | OFL-1.1 | Yes | Ship OFL.txt + copyright line, keep Reserved Font Names (§3) |
| jsfxr / jfxr / Bfxr (sound generators) | Tools: Unlicense / BSD-3 / Apache-2.0 or MIT. Output: ours | Output only | None in-app. Keep parameter files as provenance (§4) |
| Python, numpy (asset/sim scripts) | PSF / BSD-3 | No (build-time) | None. Optional "Tools" credit (§5) |
| Blender (headless `bpy` asset pipeline) | GPL-2.0-or-later | No, only its output | Output is ours. `bpy` scripts are GPL if we *publish* them (§5) |
| GitHub Actions, Android SDK, JDK, Gradle, Xcode | Various | No (build-time) | Accept each SDK license properly (§6) |
| CC0 art/audio packs (KayKit etc.) | CC0-1.0 | Yes | No legal obligation; the provenance log is mandatory for us (§8) |

## 2. Godot Engine
- **Engine license.** Godot is MIT. The only requirement is to make the license text available to the user. Godot's docs list a credits screen or a separate "Third-party Licenses" menu as acceptable ([godot-docs: Complying with licenses](https://github.com/godotengine/godot-docs/blob/master/about/complying_with_licenses.rst)). **Printing to the log does not work on iOS**, so we use an in-game screen.
- **Third-party notices.** Godot bundles about 100 third-party components that are "compatible with, but not covered by" MIT. The recommended practice is to ship Godot's `COPYRIGHT.txt`, e.g. renamed to `GODOT_COPYRIGHT.txt` ([COPYRIGHT.txt](https://github.com/godotengine/godot/blob/master/COPYRIGHT.txt)). The FreeType license (FTL) specifically requires a credit in the documentation.
- **Implementation (required).** The licenses screen pulls text from the engine binary so it cannot go stale:
  - `Engine.get_license_text()` for the Godot MIT text
  - `Engine.get_copyright_info()` + `Engine.get_license_info()` for the third-party components and their license texts
- **Version.** 4.7-stable to 4.7.2-stable exist (tags checked on GitHub, 2026-09-26). Re-run this check whenever the engine is upgraded.
- **Godot trademark.** GODOT, GODOT ENGINE and the logo are registered marks of the Godot Foundation. Uses beyond the policy need written permission ([Godot trademark policy](https://godot.foundation/policies-and-procedures/trademark-policy)). A plain-text "Made with Godot Engine" line is fine. **Do not use the Godot logo in the splash screen, store listing or marketing until someone has read that policy and confirmed the use is covered** (logo terms not fully verified here).

## 3. Fonts (SIL Open Font License 1.1)
OFL fonts **are allowed** for commercial games. Bundling them in software is permitted as long as the **license file and copyright notice travel with the font**, the font is not sold on its own, and **Reserved Font Names (RFN)** are not used for modified versions.

**Recommended set (all on Google Fonts, OFL-1.1; OFL.txt checked in [google/fonts](https://github.com/google/fonts/tree/main/ofl)):**

| Role | Font | Why | RFN |
|---|---|---|---|
| Headings / logo-type (large sizes only) | **Cinzel** (Natanael Gama) | Carved-stone fantasy feel, readable in caps at large sizes | None in the current OFL.txt. *Cinzel Decorative* reserves "Cinzel" |
| Body / UI (default) | **Nunito** | Rounded, friendly, very legible for children on small screens | None |
| Accessibility option ("Easy-read font" toggle) | **Andika** (SIL) | Designed for beginning readers, with distinct letterforms (l/I/1, a/ɑ) | **"Andika", "SIL"**: ship the files unmodified |

Alternates: *Almendra* (headings; RFN "Almendra") and *Lexend* (body; RFN "RevReading Lexend").

Rules:
1. Store each font at `game/assets/fonts/<Family>/` together with its `OFL.txt`, and log it in `ASSET_SOURCES.md`.
2. Bundle the files. **Never load fonts from the Google Fonts API at runtime** (the game is offline-first and makes no third-party requests, which matters for a child audience).
3. Do not subset, rename or alter fonts that have an RFN. If a smaller file is needed, use Nunito or Cinzel, or ask legal. Whether Godot's import step counts as "modification" under the OFL is **UNVERIFIED**; the import keeps the original font data, and we assume embedding is fine.
4. List every font with its copyright line and the OFL text on the licenses screen.

## 4. Sound generators: jsfxr, jfxr, Bfxr
| Tool | Tool license | Output ownership | Source |
|---|---|---|---|
| jsfxr (chr15m) | Unlicense (public domain), per `package.json` | Ours. The generator outputs raw synthesized audio | [github.com/chr15m/jsfxr](https://github.com/chr15m/jsfxr) |
| jfxr (Thomas ten Cate) | BSD-3-Clause | "Any sound effects you make are entirely yours … without any restrictions whatsoever." | [README](https://github.com/ttencate/jfxr) |
| Bfxr (increpare) | v1: Apache-2.0; Bfxr2: MIT | "Full rights to all sounds made with bfxr … commercial or otherwise." | [bfxr.net](https://www.bfxr.net/v1/), [bfxr2 LICENSE](https://github.com/increpare/bfxr2) |

Obligations: none in-app. **Provenance rule:** commit the parameter/preset file (`.sfxr`/`.jfxr`/`.bfxrsound` or JSON) next to each exported `.wav`/`.ogg` so every sound can be regenerated and shown to be our own. Do not use any tool's bundled sample libraries or imported third-party WAVs without logging them.

## 5. Asset-generation tooling (build-time only)
- **Python** (PSF License) and **numpy** (BSD-3). Not shipped, so no in-app notice is required. An optional "Built with" credit is fine.
- **Blender.** "What you create with Blender is your sole property", including `.blend` and exported files ([blender.org/about/license](https://www.blender.org/about/license/)). **Caveat:** Blender states that Python scripts using the Blender API must be GPL-licensed *if shared or published*. Our `bpy` scripts are fine internally. If the repo goes public, license the `bpy` scripts GPL-2.0-or-later (a separate `tools/blender/LICENSE`) and keep them separate from game runtime code. **Never copy GPL code into `game/`.**
- Keep generator seeds and scripts in the repo. Together they are our proof of independent creation.

## 6. CI/CD and platform SDKs (build-time)
- **GitHub Actions.** Use first-party `actions/*` (MIT). **Pin third-party actions to a commit SHA** and check each one's license before use.
- **Android SDK / build-tools / NDK.** Governed by the Android SDK License Agreement. `sdkmanager --licenses` in CI accepts it on the studio's behalf, so the account owner must have read and accepted it. JDK 17 (OpenJDK, GPLv2 + Classpath Exception) and Gradle (Apache-2.0) are build-time only.
- **iOS / Xcode.** The Xcode & Apple SDKs Agreement and the Apple Developer Program License Agreement apply. Build only on Apple-branded hardware. GitHub's macOS hosted runners are commonly treated as compliant, but this is **UNVERIFIED** here; confirm before M6.
- Signing keys and keystores never go in the repo.

## 7. In-game "Credits & Licenses" screen (REQUIRED before any store build)
Reachable from **Settings → About → Credits & Licenses** (and the title screen). Kids and parents can find it without a network connection.
1. **Credits:** team/studio, tools used (optional), optional CC0 thank-yous (e.g. "3D assets by Kay Lousberg (KayKit), CC0").
2. **Godot Engine:** `Engine.get_license_text()`, full text.
3. **Third-party engine components:** generated from `Engine.get_copyright_info()` / `get_license_info()` (scrollable, grouped by license).
4. **Android libraries:** AndroidX and Kotlin with the Apache-2.0 text, generated at build time from the Gradle dependency report (to verify: `./gradlew :app:dependencies`).
5. **Fonts:** name, copyright, OFL-1.1 text.
6. **Assets:** generated from `ASSET_SOURCES.md` (name, author, license).

Acceptance test: a CI check fails if a file under `game/assets/thirdparty/` or `game/assets/fonts/` has no row in `ASSET_SOURCES.md`.

## 8. Asset sourcing policy (CC0 third-party assets)
**Allowed:** third-party **models, animations, textures, HDRIs, sounds and fonts** under **CC0-1.0**, and **fonts under OFL-1.1** (with license file, §3), provided that:
1. **We download and integrate them ourselves** (no agent-generated "look-alikes" of third-party packs, and no re-uploads from mirror sites).
2. **We verify the license on the provider's own page at download time** and save the pack's own LICENSE file next to the asset, under `game/assets/thirdparty/<provider>/<pack>/LICENSE.txt`.
3. **Every item is logged in [`ASSET_SOURCES.md`](ASSET_SOURCES.md) before it is merged.**
4. The asset contains **no third-party trademarks, logos, real brands, readable text from real products, or likenesses**. CC0 waives copyright only: "No trademark or patent rights held by Affirmer are waived" ([CC0 1.0 legal code §4a](https://creativecommons.org/publicdomain/zero/1.0/legalcode.en)).
5. The asset does not make us look like another game (no Diablo-style icons or UI kits, even if CC0; see BLOCKLIST).

**Not allowed without written legal-counsel approval:** CC-BY (attribution bookkeeping), and custom "royalty-free", "free for commercial use" or store-EULA assets (Unity Asset Store, Fab/Unreal, Sketchfab standard license, itch.io custom terms). **Never allowed:** CC-BY-SA, CC-BY-NC, CC-BY-ND, GPL/LGPL art, "personal use only", unknown or unstated license, ripped game assets, AI-generated assets of unknown training provenance.

### Preferred CC0 providers (license terms checked 2026-09-26 via web search; provider pages were blocked for direct fetch, so each pack must be re-verified at download)

| Provider | License | Attribution | Caveats |
|---|---|---|---|
| **Kenney** (kenney.nl) | CC0 1.0 | Not required; "Kenney"/"kenney.nl" appreciated ([Kenney support](https://kenney.nl/support), [@KenneyNL](https://x.com/KenneyNL/status/1939336549684183078)) | "Kenney" is the provider's brand. No implied endorsement in marketing |
| **Quaternius** | CC0 per the Quaternius FAQ ("no need for attribution … commercial") ([quaternius.com](https://quaternius.com/packs/3dcardkitfantasy.html), [@quaternius](https://x.com/quaternius/status/1559299393177747456)) | Not required | Patreon/"source" bundles may differ. Check each pack's included license |
| **KayKit / Kay Lousberg** | CC0 1.0 in each pack's LICENSE.txt (verified locally for 4 packs) ([itch.io](https://kaylousberg.itch.io/kaykit-adventurers)) | Not mandatory ("Support me by crediting Kay Lousberg") | Kay asks people not to resell unmodified copies or claim the assets as their own. This is a courtesy request, and we honor it: no standalone redistribution, no "made by us" claims. EXTRA packs are also stated as CC0; verify per pack. "KayKit" is the provider's brand |
| **Poly Haven** | CC0, all HDRIs/textures/models ([polyhaven.com/license](https://polyhaven.com/license)) | Not required | Photo-scanned content: check for visible brands or labels |
| **ambientCG** | CC0 1.0 ([docs.ambientcg.com/license](https://docs.ambientcg.com/license/)) | Optional (suggested credit text available) | As Poly Haven, check scans for brands |
| **OpenGameArt** | **Mixed.** Filter to CC0 only | Not required for CC0 | The uploader may not be the true author, and OGA says "all bets are off" in that case ([OGA forum](https://opengameart.org/forumtopic/cc0-licence-doubt)). Prefer known authors; save OGA's credits file (download while signed in); record the original source link if it is a re-upload. **Highest-risk provider; legal review required per asset** |

Provider names (Kenney, Quaternius, KayKit, Poly Haven, ambientCG) are their brands. Use them only in factual credits, never in our title, store listing or marketing in a way that implies partnership.

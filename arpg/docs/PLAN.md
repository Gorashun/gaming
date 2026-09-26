# Production Plan — M0 to "Ready for External Playtest"

Owner: `studio-producer`. Source of truth for design is `GDD.md`, for tech `ARCHITECTURE.md`; test detail lives in `QA.md`.
All durations are **estimates**. Every exit criterion is meant to be checked by a script or a CI job unless marked *(manual)*.

## 0. Playtest scope (the slice we ship to external testers)

The full GDD (5 classes, 5 acts, level 200, 4 professions, Starmap, Deepdark) is **not** the playtest target. The playtest build proves the core loop and the extension seams.

| In scope (playtest) | Explicitly deferred (post-playtest) |
|---|---|
| Act 1 *Wickmire*: hub + 3 generated zones + boss *The Sunken Bellringer* | Acts 2–5, Deepdark/Lightwells, weekly boss, leaderboard |
| 3 classes: Lanternbearer (melee), Stargazer (ranged caster), Roofrunner (agile/traps) | Bellstriker, Stitcher (summoner AI is costly), Rootweaver |
| Levels 1–30, skill tree (3 branches, ~6 skills/class), Pact choice at 30 | Levels 31–200, Starmap, glyphs |
| Tiers 1–2 (Twilight, Nightfall) with playtest level bands; Hardcore "Last Flame" + Hall of Embers | Abyss, Eclipse I–X, Mythic drops |
| Rarities Common → Legendary + 1 Unique per boss; smart loot; visible Legendary pity | Mythic, Named weapons (1 recipe stub max) |
| Inventory 40 + 1 stash tab, auto-salvage, quick compare, loot filter presets | Extra stash tabs |
| Smith profession (1–15) + Kindling + salvage; Cauldron with 5 discoverable recipes | Alchemist, Jeweler, Runecarver |
| 2 surprises: Gilded Gremlin, elite packs with affixes; 1 secret (Tea Party) | Remaining surprises |
| Accessibility: text scale, shake slider, colour-blind/high-contrast, auto-attack | Full localisation |
| 1 test DLC pack `content/dlc_test` (1 zone + 1 monster family + 5 items), data-only | Real paid DLC / store entitlement |
| Save v1 + migration framework, per-character, hardcore isolated | Cloud save |
| Multiplayer seams (intents, authority functions, net_ids, seeded streams) verified by replay test | Networking, lobby, server |

## 1. Milestones

### M0 — Foundation ("it boots, it's tested, it's measured") — est. 1 week

| # | Exit criterion (automatable) | Owner |
|---|---|---|
| M0.1 | `godot --headless --quit` on the project exits 0 with **zero** errors (all autoloads in `project.godot` exist — `game_state.gd`, `sfx.gd`, `scenes/main.tscn` are currently missing). | gameplay-programmer |
| M0.2 | `godot --headless -s res://tests/run_tests.gd` runs, prints JUnit-style summary, exits non-zero on any failure. ≥ 20 unit tests for `StatBlock`, `Progression`, `Rng`, `ContentDB` merge/override. | gameplay-programmer, qa-tester |
| M0.3 | Content validator (`tests/validate_content.gd`) runs in CI: unique ids, all references resolve, JSON schema per table, weights sum > 0, no unknown fields. Fails the build on error. | qa-tester, arpg-systems-designer |
| M0.4 | GitHub Actions: workflow `ci.yml` on every PR runs tests + validator + sims + 60 s bot smoke + screenshot capture (Xvfb) and uploads artifacts; `android.yml` builds a debug APK on `main`. Both green. | gameplay-programmer |
| M0.5 | Determinism lint in CI: grep fails on `randf()`, `randi()`, `randomize()` or `RandomNumberGenerator.new()` outside `scripts/core/rng_service.gd`. | qa-tester |
| M0.6 | CLI flags parsed by `Game`: `--seed`, `--class`, `--tier`, `--zone`, `--bot=<profile>`, `--duration`, `--metrics-out`, `--screenshot-dir`, `--hardcore`. Bot writes JSONL metrics (schema in QA.md §4). | gameplay-programmer |
| M0.7 | `PLAN.md`, `QA.md`, `BACKLOG.md`, `DECISIONS.md` exist; every M1 backlog item has an owner and DoD. | studio-producer |

### M1 — Core loop prototype ("one class, one zone, fun for 5 minutes") — est. 2–3 weeks

| # | Exit criterion | Owner |
|---|---|---|
| M1.1 | Lanternbearer: basic attack + 4 skills + potion on touch arc; floating joystick; tap auto-aim / hold manual aim. Screenshot test shows all buttons ≥ 56 dp at 1280×720 and 2400×1080. | gameplay-programmer, ui-ux-designer |
| M1.2 | One generated Wickmire zone from seeded room graph: same seed ⇒ identical layout hash (100/100 seeds); 100 random seeds all reachable start→exit (flood-fill test). | gameplay-programmer |
| M1.3 | 4 monster types + 1 elite pack affix set + mini-boss with telegraphed ground markers. | arpg-systems-designer, art-3d-designer |
| M1.4 | Loot: rarities Common→Legendary, affix rolling by item level, smart loot 75%, beams + rarity SFX ladder; equip changes stats (unit tested). `sim_loot.py` 1M rolls within ±5% relative of configured weights. | arpg-systems-designer, audio-designer |
| M1.5 | Juice pass v1: hitstop, shake (respects slider), damage numbers, death "rekindle" sparks (no gore). Screenshot checklist §6 passes for combat frames. | art-3d-designer, gameplay-programmer |
| M1.6 | Bot (`competent` profile) clears the zone on Tier 1 in 3–6 min, 0 crashes, in 10/10 seeds. TTK for fodder within QA.md targets. | qa-tester |
| M1.7 | Replay test: recorded intents + seed replayed headless ⇒ identical final state hash (HP, inventory, net_ids). | gameplay-programmer, qa-tester |
| M1.8 | Owner hands-on *(manual)*: 10-minute session on Pixel 8 Pro, rates "fun" ≥ 3/5 on the feel checklist in QA.md §6.3. | studio-producer |

### M2 — Vertical slice ("Act 1, three classes, two tiers, hardcore, one DLC") — est. 4–6 weeks

| # | Exit criterion | Owner |
|---|---|---|
| M2.1 | Act 1 complete: hub (vendor, stash, smith, Cauldron), 3 zones, boss with ≥ 2 phases, quests granting the 10 quest skill points design (scaled to slice). | arpg-systems-designer, game-writer, gameplay-programmer |
| M2.2 | 3 classes playable, each with ~6 skills over 3 branches + Pact at 30. Bot clears Act 1 on Tier 1 with each class; per-class clear time within ±20% of mean. | arpg-systems-designer, gameplay-programmer |
| M2.3 | Tiers 1–2 via `difficulties` table with playtest level bands; Tier 2 unlocks after Act 1 boss on Tier 1. Bot metrics per tier within QA.md §5 targets (TTK, deaths/h, drops/min). | arpg-systems-designer, qa-tester |
| M2.4 | Hardcore: separate stash, gold frame, entombment in Hall of Embers; test: hardcore death ⇒ character read-only, stash isolated, softcore unaffected. App backgrounding pauses the game (no death while paused). | gameplay-programmer, qa-tester |
| M2.5 | Crafting: Smith 1–15, Kindling with deterministic odds preview (preview == actual distribution over 100k sim crafts, ±2 pp), salvage, 5 Cauldron recipes with journal. | arpg-systems-designer |
| M2.6 | Save v1: atomic write (tmp + rename), 3 rolling backups, migration test v0→v1 fixture; kill-during-save test never produces an unloadable save (100 iterations). | gameplay-programmer |
| M2.7 | Extensibility proof: `content/dlc_test` adds a zone, monster family and 5 items with **zero** changes under `scripts/`; CI loads base, base+dlc, and verifies a save made with DLC loads without DLC (unknown ids become placeholders, no crash). | gameplay-programmer, qa-tester |
| M2.8 | All screens (inventory, character, skills, crafting, map, settings, menus) pass screenshot checklist at 3 resolutions; colour-blind mode keeps rarity distinguishable by shape (automated: frame-shape asset per rarity is unique). | ui-ux-designer, qa-tester |
| M2.9 | Perf proxies in CI within budget (QA.md §7): draw calls, visible objects, script frame time with 60 actors. | gameplay-programmer, art-3d-designer |
| M2.10 | Player-welfare review of all reward/pity/rested systems signed off in `docs/design/PLAYER_WELFARE.md`. | player-safety-advisor |

### M3 — Playtest candidate ("polished, stable, measurable") — est. 3–4 weeks

| # | Exit criterion | Owner |
|---|---|---|
| M3.1 | Balance: every metric in QA.md §5 inside target band for all 3 classes × 2 tiers × 3 bot profiles over ≥ 20 seeds each. Deviations logged in `DECISIONS.md`. | arpg-systems-designer, qa-tester |
| M3.2 | Stability soak: bot plays 4 h continuous (Xvfb) with 0 crashes, 0 script errors in log, memory growth ≤ 5% after first 30 min. | qa-tester |
| M3.3 | Onboarding: new-player bot (`novice` profile) reaches Act 1 boss on Tier 1 without dying more than QA.md novice target; first 3 minutes have ≤ 3 tutorial prompts. | ui-ux-designer, qa-tester |
| M3.4 | Device *(manual, owner)*: Pixel 8 Pro 30-min session, perf overlay log exported: p95 frame time ≤ 16.7 ms, cold start ≤ 6 s, no thermal throttling warnings in 30 min. Mid-range floor device ≥ 30 fps p95 if available. | studio-producer, gameplay-programmer |
| M3.5 | Release-signed APK/AAB built by Actions from a tag, version code + build id shown on title screen and in bug export; AAB ≤ 150 MB. | gameplay-programmer |
| M3.6 | In-game feedback screen exports a share file (build id, seed, settings, last 500 log lines, screenshot, save copy). No network telemetry. | ui-ux-designer, gameplay-programmer, player-safety-advisor |
| M3.7 | Legal: working title and all class/tier/boss names cleared or marked placeholder; `docs/legal/ASSET_SOURCES.md` covers 100% of files in `assets/thirdparty/` (CI check). | legal-counsel |
| M3.8 | Bug gate: 0 open S0/S1, ≤ 5 open S2 each with known-issue note in the tester brief. | qa-tester, studio-producer |
| M3.9 | Tester brief + consent text (adult testers or parent-supervised children only) ready. | studio-producer, player-safety-advisor |

## 2. Dependencies (critical path)

1. M0.1 boot fix → everything.
2. Item/affix schema (arpg-systems-designer) → inventory UI (ui-ux-designer) and loot sim (qa-tester).
3. CLI flags + metrics schema (M0.6) → all bot-based exit criteria.
4. `difficulties` table with level bands → Tier 2 balance (M2.3).
5. Save format v1 → hardcore (M2.4) and DLC-removal test (M2.7).

## 3. Risk register (top 8)

| # | Risk | Prob. | Impact | Mitigation | Owner |
|---|---|---|---|---|---|
| R1 | Scope explosion: GDD describes a multi-year game; agents build breadth instead of a polished slice. | High | High | Playtest scope table (§0) is binding; anything else needs a `DECISIONS.md` entry. | studio-producer |
| R2 | "Fun" and game feel cannot be judged by agents without hands. | High | High | Feel checklist + owner hands-on at M1.8/M3.4; bot metrics as proxy (TTK, time between rewards); external playtest is the real measurement. | studio-producer, qa-tester |
| R3 | Real Android performance is unverifiable in the container (llvmpipe ≠ Adreno/Mali; Pixel 8 Pro is high-end). | High | High | Renderer-independent budgets in CI (draw calls, objects, script ms); perf overlay + log export; shader pre-warm; name a mid-range floor device; optional Firebase Test Lab game-loop run. | gameplay-programmer |
| R4 | Determinism breaks silently (RNG outside streams, dict iteration order, frame-rate-dependent logic), killing reproducible bug reports and the multiplayer seam. | Medium | High | RNG lint (M0.5), replay hash test (M1.7) on every PR, fixed-tick combat. | gameplay-programmer, qa-tester |
| R5 | Content pack drift: schema changes break packs/DLC; `.pck` with scripts may conflict with Play policy on downloaded code. | Medium | High | JSON schemas + validator in CI; data-only packs; DLC load/unload test (M2.7). | gameplay-programmer, legal-counsel |
| R6 | Save corruption or bug-caused hardcore death destroys tester trust. | Medium | High | Atomic writes, backups, migration fixtures, pause on focus loss; playtest builds allow restoring a hardcore char from backup on confirmed bug. | gameplay-programmer, qa-tester |
| R7 | Balance off by an order of magnitude (double scaling tier × level, XP curve estimates). | High | Medium | Sims (`tools/sim_*.py`) + bot metrics gated in CI against QA.md §5 bands. | arpg-systems-designer |
| R8 | Legal/compliance: unresolved title and names, CC0 provenance gaps, PEGI 7 / Families policy, testing with minors. | Medium | High | Legal gate M3.7, provenance CI check, consent/brief M3.9, welfare review M2.10. | legal-counsel, player-safety-advisor |

## 4. Definition of Done — "Polished & ready for external game testing"

A build is ready when **all** of the following hold:

**Stable**
- [ ] 0 open S0/S1 bugs; ≤ 5 S2 documented as known issues.
- [ ] 4 h bot soak: 0 crashes, 0 script errors, memory growth ≤ 5%.
- [ ] Save/load, kill-during-save, migration and DLC add/remove tests green.

**Tested**
- [ ] CI green on the tagged commit: unit tests, content validation, RNG lint, replay hash, sims, bot matrix (3 classes × 2 tiers × 3 profiles × 20 seeds), screenshot suite.
- [ ] Every balance metric in QA.md §5 inside its band (or waived in `DECISIONS.md`).

**Polished**
- [ ] Screenshot checklist (QA.md §6) passes on every screen at 3 resolutions; no placeholder textures, no untranslated keys, no clipped text.
- [ ] Juice checklist complete: hitstop, shake, damage numbers, loot beams, rarity audio ladder, golden-moment card for Legendary+.
- [ ] Owner hands-on on Pixel 8 Pro rates feel ≥ 4/5 and perf targets met (p95 ≤ 16.7 ms, cold start ≤ 6 s).
- [ ] Accessibility: text scale, shake slider, colour-blind/high-contrast, auto-attack all functional (screenshot + unit tests).

**Extensible**
- [ ] `content/dlc_test` works with zero script changes; new difficulty tier can be added by data only (CI test adds a fake tier 3 record and a bot runs it).
- [ ] Replay test proves intents + seed ⇒ identical state (multiplayer seam intact).

**Shippable to testers**
- [ ] Release-signed APK/AAB from Actions, build id visible, AAB ≤ 150 MB.
- [ ] In-game feedback export works offline; no telemetry leaves the device.
- [ ] Names cleared or marked placeholder; asset provenance 100%; welfare sign-off; tester brief + consent text ready.

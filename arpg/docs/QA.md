# QA Strategy

Owner: `qa-tester`. Applies to the playtest slice defined in `PLAN.md` §0. Numbers marked *(est.)* are starting targets to be tuned by `arpg-systems-designer`; any change is logged in `DECISIONS.md`.

## 1. Test pyramid

| Layer | What | Tool | When | Gate |
|---|---|---|---|---|
| Lint | RNG only via `Rng` streams; no `print` spam; GDScript warnings-as-errors for `scripts/rpg/` | grep + `godot --headless --check-only` | every PR | fail |
| Unit | Rules engine (`scripts/rpg/*`), pure, headless | `godot --headless -s res://tests/run_tests.gd` | every PR | fail |
| Content | Schema + references for every pack combination | `tests/validate_content.gd` | every PR | fail |
| Simulation | Loot, XP pacing, crafting economy (Monte-Carlo) | `tools/sim_*.py` | every PR (fast), nightly (full) | fail if outside §5 bands |
| Replay | Intents log + seed ⇒ identical state hash | `tests/replay_test.gd` | every PR | fail |
| Bot playtest | Autonomous play per class × tier × profile | `tests/playtest_bot.gd` under Xvfb | PR: 1 smoke run; nightly: full matrix | fail on crash; §5 bands nightly |
| Screenshot | Fixed camera/scene set at 3 resolutions | Xvfb + `--screenshot-dir` | every PR (capture), review per milestone | auto checks fail; human/agent review per §6 |
| Perf proxy | Draw calls, objects, script ms, memory | bot + `Performance` monitors | nightly | fail on budget breach |
| Device | Pixel 8 Pro hands-on + perf overlay log | owner *(manual)* | M1, M3 | milestone exit |

## 2. Unit tests — rules engine (minimum set)

- **StatBlock:** flat / `_pct` / `more_` math; `more_` sources must multiply each other (currently summed — see Known defects). Source add/remove/clear_prefix invalidates cache.
- **Progression:** `xp_to_next` monotonic 1–200, continuous at 59→60→61; points granted: 60 skill (+10 quest) and 280 star total; `monster_xp` floor at 0.1 for grey monsters, cap +25% for higher.
- **Rng:** same master seed ⇒ same sequence per stream; streams independent (drawing from `loot` does not change `combat`); `weighted()` distribution within ±1 pp over 100k; zero-weight entries never picked.
- **ContentDB:** load order, override by id, `_merge` patching, `requires` missing ⇒ pack skipped, duplicate id inside one pack ⇒ error.
- **Loot:** rarity rolls, item-level→affix tier, smart loot 75% ±2 pp, Legendary pity triggers at threshold and resets, Unique ~1/40 per boss kill.
- **Combat:** damage formula, resist penalty per tier (−15/−35), crit, clamps (no negative damage, resist cap), damage over time tick count independent of frame rate.
- **Crafting:** Kindling cost, preview odds equal empirical odds (±2 pp, 100k), salvage returns.
- **Save:** round-trip equality, migration fixtures for every past `save_version`, hardcore flag isolation, unknown content ids preserved as placeholders.

## 3. Content validation

For base, base+`dlc_test`, and every pack alone where `requires` allows:
- Every record has unique `id` within table; every foreign key (skill→effect primitive, monster→biome, recipe→material, item→affix pool…) resolves.
- JSON schema per table (required fields, types, ranges); unknown fields are errors (catches typos in data).
- Rarity weights > 0 and sum within 100 ± 0.01 per tier; level bands contiguous, non-overlapping; each zone has ≥ 1 spawnable monster at every level in its band.
- Every `model_path`/icon/audio path exists; every player-facing string ≤ max length for its UI slot.
- Effect primitives referenced by data exist in `skill_effects.gd` (name registry exported by a test).

## 4. Bot playtests

Profiles: `novice` (slow reaction 600 ms, no potion before 30% HP, random skills), `competent` (250 ms, potions at 50%, priority rotation), `expert` (100 ms, dodges telegraphs). Matrix: 3 classes × tiers {1, 2} × 3 profiles × softcore/hardcore × N seeds (PR: 1 run; nightly: 20 seeds).

Metrics JSONL, one line per event + one summary per run:
```
{"t":12.3,"ev":"kill","mon":"bog_skel","elite":false,"ttk":0.8}
{"t":14.0,"ev":"drop","rarity":"magic","ilvl":7}
{"t":90.1,"ev":"death","cause":"boss_slam","tier":1}
{"ev":"summary","build":"…","seed":123,"class":"lanternbearer","tier":1,"profile":"competent","minutes":30.0,"level_start":1,"level_end":9,"deaths":0,"kills":412,"drops":{"common":50,…},"errors":0,"fps_p95":…}
```
The bot also asserts: no stuck state > 20 s (no position change and no combat), no error lines in log, every zone exit reachable.

## 5. Balance targets (playtest slice)

TTK is measured with **on-level, rarity-appropriate gear the bot equipped itself**.

### 5.1 Time-to-kill (seconds)
| Target | Tier 1 Twilight | Tier 2 Nightfall |
|---|---|---|
| Fodder | 0.3–1.2 | 0.5–1.8 |
| Elite / champion (each) | 3–8 | 5–12 |
| Rare with affixes | 6–15 | 10–22 |
| Zone mini-boss | 20–45 | 30–60 |
| Act 1 boss | 60–150 | 90–180 |
| Player time-to-death, standing in on-level fodder pack, no potions | ≥ 10 | ≥ 6 |

### 5.2 Deaths per hour (bot, full Act 1 run)
| Profile | Tier 1 | Tier 2 |
|---|---|---|
| novice | ≤ 2.0 | ≤ 5.0 |
| competent | ≤ 0.5 | 0.5–2.0 |
| expert | 0 (≤ 0.1) | ≤ 0.5 |
| Boss first-attempt win rate (competent) | ≥ 80% | 50–75% |

Hardcore uses the same numbers; additionally **0** hardcore deaths attributed to bugs (stuck, invisible attacks, un-telegraphed one-shots). No single hit from a non-boss may exceed 40% of on-level max HP on Tier 1 (unit-simulated).

### 5.3 Drops per minute (competent bot, Tier 1; Tier 2 in brackets) *(est.)*
| Rarity | Per minute | Per hour |
|---|---|---|
| All items | 2.5–4.0 (3.0–4.5) | 150–270 |
| Common | 1.4–2.2 | — |
| Magic | 0.75–1.2 | — |
| Rare | 0.15–0.26 (owner retune 2026-09-26) | 9–16 |
| Epic | 0.03–0.06 (↑ with Tier 2 bonus; min monster lvl 4) | 2–3.6 |
| Legendary | 0.012–0.03 incl. pity (×2 on Tier 2; min monster lvl 6) | 0.7–1.8 |
| Unique (boss) | — | ~1 per 40 boss kills (sim: 30–50) |
| Mythic | 0 | 0 |

Plus: Legendary gap p95 ≤ 60 min of active play (owner decision 2026-09-26: pity 60 min, data 3540 s; `sim_loot.py --check` enforces it); gold/min and materials/min tracked, target set by economy sim. Observed rarity shares over 1M sim rolls within ±5% relative of `rarities` weights.

### 5.4 Time-to-level (competent bot, playing Act 1 in order, rested bonus off) *(est.)*
| Level | Cumulative play time |
|---|---|
| 2 | 1–3 min |
| 5 | 8–15 min |
| 10 | 35–60 min |
| 20 | 2.0–3.0 h |
| 30 (slice cap) | 4.5–7.0 h |

No level may take > 2× the previous level's time (no walls). Act 1 story completion on Tier 1 lands at level 14–18 *(est.)*. Zone clear 3–6 min. Rested Glow: +100% XP never lasts > 20 min of play per accrual.

## 6. Screenshot review checklist

Captured per PR at 1280×720 (16:9), 2400×1080 (20:9, Pixel 8 Pro aspect) and 2048×1536 (4:3 tablet): title, hub, each zone (start, combat, elite, boss telegraph), every UI screen, golden-moment card, death/Hall of Embers, settings with each accessibility mode.

### 6.1 Automated checks
- No magenta/checkerboard pixels (missing texture) and no fully black/white frames.
- Mean luminance of gameplay frames 0.12–0.45 (dark but readable); player silhouette contrast vs. local background ≥ 3:1.
- Golden-image diff for UI screens: > 2% changed pixels flags for review (not failure).
- UI nodes: all touch controls ≥ 56 dp, inside safe area, no Control overflows its parent, no raw string keys visible.

### 6.2 Review checklist (per milestone, qa-tester + ui-ux-designer + art-3d-designer)
- [ ] Rarity readable by colour **and** frame shape **and** icon; holds in colour-blind modes.
- [ ] Attacks/telegraphs brighter than the world; ground markers visible on every biome floor.
- [ ] Damage numbers readable, not covering the player; crits distinct.
- [ ] Chibi proportions consistent; no z-fighting, floating props, clipped weapons.
- [ ] Text: no clipping at text-scale max; icons-first for 7+ readers.
- [ ] No gore; defeats read as "rekindle" sparks. Tone PEGI 7.
- [ ] HUD does not hide the player's thumbs area threats (bottom corners clear of enemies' attack markers).

### 6.3 Feel checklist (owner hands-on, 1–5 each)
Responsiveness (input → action < 100 ms), hit weight (hitstop/shake/sound), loot excitement (beam + sound + card), movement flow, clarity in crowds, "one more run" desire.

## 7. Performance

| Metric | Budget | Where measured |
|---|---|---|
| Frame time p95 | ≤ 16.7 ms Pixel 8 Pro; ≤ 33 ms mid-range floor | device *(manual)*, perf overlay log |
| Draw calls per frame | ≤ 250 *(est.)* | CI (renderer-independent) |
| Skinned actors on screen | ≤ 60 | CI |
| Visible omni lights | ≤ 8 | CI |
| Script/physics time per frame, 60 actors | ≤ 4 ms on CI runner *(proxy)* | CI |
| Memory (static + video) | ≤ 800 MB | CI + device |
| Cold start to title | ≤ 6 s Pixel 8 Pro | device |
| AAB size | ≤ 150 MB | CI |
| Hitches > 50 ms in 30 min | ≤ 3 (shader pre-warm required) | device |
| Soak memory growth after 30 min | ≤ 5% | CI 4 h soak |

## 8. Bug severity scale

| Sev | Name | Definition | Examples | Playtest gate |
|---|---|---|---|---|
| S0 | Blocker | Crash, data loss, cannot progress, or safety/compliance breach | crash on boss; save corrupted; hardcore character lost to a bug; any external network call / data collection; gore or inappropriate content | 0 open |
| S1 | Critical | Core loop badly broken, no reasonable workaround | loot never drops; skill does nothing; soft-lock requiring app restart; balance metric off by > 2× band | 0 open |
| S2 | Major | Significant problem with a workaround | wrong stat tooltip; elite affix not applied; UI overlap on one resolution; memory leak < 5%/h | ≤ 5, documented |
| S3 | Minor | Noticeable, small impact | misaligned icon; SFX missing on one skill; typo | allowed |
| S4 | Polish | Cosmetic or wish | colour tweak; animation timing | allowed |

Bug report template: title · build id · seed · class/tier/zone · steps · expected · actual · frequency (x/10) · severity · attachments (screenshot, JSONL, save copy, log). Bot-found bugs must include the reproducing CLI command.

## 9. Known defects found during doc review (pre-M0)
- `project.godot` autoloads `game_state.gd` and `sfx.gd` and main scene `scenes/main.tscn` do not exist ⇒ project cannot boot (S0).
- `StatBlock.total()` adds all `more_<stat>` sources together instead of multiplying them, contradicting its own comment and the GDD "more" semantics (S1 for balance).
- `Rng` reseeds from wall-clock time in `_ready()` and stream state is not serialisable ⇒ runs not reproducible after save/load (S2).
- Rules code (`Progression`) reads the `Content` autoload directly ⇒ not pure/injectable, harder to unit-test and to run server-side (S2).

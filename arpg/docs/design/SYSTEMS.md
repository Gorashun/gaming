# Wickwright — Systems Design (loot, progression, crafting, content tables)

Owner: arpg-systems-designer · 2026-09-26 · Implements GDD v2/v2.1–v2.5 binding items and research `research/player_wants.md` P0 recommendations.
Data: `game/content/base/*.json` (schema: `docs/CONTENT_SCHEMA.md`, "Wave 2 additions"). Tools: `game/tools/validate_content.py`, `sim_loot.py`, `sim_xp.py`, `sim_upgrade.py`.
All numbers below are simulation outputs (reproduce with the commands in §10). Nothing here is purchasable with real money.

## 1. What is in the data (counts)

| Area | Count | Notes |
|---|---|---|
| Weapon types | 12 | sword, greatsword, axe, axe2h, staff, wand, dagger, crossbow, arbalest (2H crossbow), shield, tome, quiver. No mace/bow/spear/orb: no props exist. |
| Item bases | 630 | 15 tiers (ilvl 1…190) per weapon line, 5 variant weapon lines (skeleton props, gilded greatsword), 9 off-hand lines, light/medium/heavy armour per slot (6 slots × 3 × 15), 7 jewellery lines, 17 starter/vendor bases. All legacy ids kept. |
| Affixes | 125 | 65 stat affixes (8 tiers each, ilvl 1/10/22/38/58/82/115/165) + 60 `skill_rank:<skill>` affixes (class-hinted). |
| Legendary powers | 49 | random pool (15 class-flavoured), + 40 Unique powers, + 9 Named powers (kept out of the random pool with `slots: ["__unique"/"__named"]`). |
| Uniques | 42 | the writer's `legendary_ideas` ids and flavour, each with one one-line build verb; sources: 6 bosses, 10 mini-bosses, elites, Magpie Imp. |
| Named | 9 | 5 from the pitch/writer + Tea Party Guestbook, Answering Letter-Opener, Magpie's Last Coin, Toffee Cleaver. Each needs one "impossible" material from a secret. |
| Materials | 90 | 5 salvage, 3 upgrade (Glowcoal, Starmote, Echo of a Lost Bell), 15 act mats (3/act), 5 boss fragments, 11 quest items, 9 named mats, 40 gems (8 types × 5 grades), Hushmark, Warm Egg. |
| Recipes | 106 | Smith 27 (incl. 9 Named, 5 relics, upgrade), Alchemist 30, Jeweler 38 (32 gem combines), Runecarver 7, Cauldron 4 secret. Levels 1–50. |
| Skills | 65 | per class: 1 basic + 12 actives in 3 branches (4 each), unlocks 1–40, every active has rank-2 and rank-4 modifier tiers × 3 options + 20-rank mastery with milestones at 5/10/15/20. |
| Passives | 70 | per class 11 passives (2 general, 3 per branch incl. 1 capstone at 25 branch points) + 3 Pacts (level 30). |
| Monsters | 62 | 5 families × 9–12 types (6+ spawnable each), 10 mini-bosses, 5 act bosses + weekly Long Shadow, 6 event monsters, 7 player minions. |
| World | 5 acts, 30 zones | town + 3 zones + boss per act (writer names), 5 special zones (Deepdark, Lightwell, Magpie's Hoard, Candy Crypt, Tea Party); ≥1 secret per story zone (Act 1 has 7). |
| Surprises | 12 events, 7 Hushfalls | 5 live events (Magpie, Goblets, Cursed Shrine, Mystery Egg, Lantern Moth); portal/act-filtered events wait for code. |
| People & quests | 71 NPCs, 91 side quests (15 bounties), 43 main-quest chapters, 7 puzzles, 6 escorts | aligned 1:1 with `npc_text.json` / `main_quest_text.json`; plus a Curio peddler per town. |
| Collections | 23 pets, 10 mounts, 103 deeds, 45 cosmetics, 6 deed milestones | deeds = writer ids; 9 skill points from deeds in total (cap 10). |
| Starmap | 46 constellations, 457 stars | 36 shared (3 rings) + 2 per class; a player sees 377 stars, 280 points = 74 % coverage. |
| Difficulties | 13 | Twilight, Nightfall, Abyss, Eclipse I–X. |

## 2. Loot

### 2.1 Pipeline (as coded in `loot.gd` / `items.gd`)
Kill → item count by `config.loot.kinds[kind]` → rarity roll (weights × MF with diminishing returns × tier bonus × source bonus) → visible pity → base (smart loot 75 %) → affixes by ilvl tier → power for Legendary+.

Rarity weights (sum 100): Common 63.4 · Magic 30 · Rare 4.8 · Epic 1.5 · Legendary 0.9 · Mythic 0.1 (monster level ≥ 60, Nightfall+ only).
Pity: Rare 5 min, Legendary 45 min, Mythic soft 8 h / hard 20 h — play-time only, never reduced by absence.
Affix hygiene (research #2): Rare 3–4, Epic 4 (one greater ✦), Legendary 4 + power, Mythic 5 greater + power. No conditional affixes anywhere.

Kinds (item chance / count / notable bonus): normal 12 % ×2 rolls; champion 25 % ×0–2 (rare+ ×1.5); rare leader 1 + 2×50 % (rare+ ×2); boss 3 + 2×70 % (min Magic, rare ×2.5, epic/legendary ×3); chest / golden chest; magpie; goblet; shrine; egg; moth; hushfall_cache.

### 2.2 Simulation results — Tier 1 Twilight, Act 1, competent pace (`sim_loot.py --check`, 2 000 players × 3 h)
Model: zones cleared in order with content packs/elites; 4.5 min per zone, 3 min boss zone (QA zone clear 3–6 min) → **8.4 kills/min**; 1.5 chests/zone; events as coded.

| Rarity | /min | /h | QA §5.3 band |
|---|---|---|---|
| All items | 3.34 | 200 | 2.5–4.0 ✔ |
| Common | 1.64 | 99 | 1.4–2.2 ✔ |
| Magic | 1.18 | 71 | 0.75–1.2 ✔ |
| Rare | 0.34 | 20.6 | 0.24–0.38 ✔ |
| Epic | 0.106 | 6.3 | 0.07–0.11 ✔ |
| Legendary | 0.068 | 4.1 | 0.04–0.07 ✔ |
| Mythic | 0 | 0 | 0 ✔ |

- First Legendary: p50 6.8 min (natural drop), p90 11.1 min, p99 11.1 min **with** the scripted golden moment at 11 min (`config.hooks.first_legendary_s = 660`, main quest `mq_a1_04`). Without the hook: p90 32.8, p99 45.5 min (pity cap).
- Legendary gap: mean 13.9 min, **p95 45 min**, max 48 min (pity only fires on the next item roll after 45:00).
- First Magic: p50 1.1 min, p90 3.2 min → code hook `config.hooks.first_magic_s = 120` must force it to meet "≤ 2 min".
- Uniques: act bosses total 2.5 % per kill (= 1/40, QA). Including mini-bosses, elites and the Magpie Imp the player sees one Unique per ~9.6 boss-zone clears in Act 1 loops. Boss fragments give a deterministic path: 10 fragments (≈ 7 boss kills) forge a guaranteed relic Unique.
- Gold (drops only): 125 /min at monster level 8.

Tier 2 (Nightfall, Act 5, level 60, 60 MF): 3.6 items/min, Legendary 0.17/min (≈ ×2.5 of Tier 1), Epic 0.20/min, **Mythic 0.43/h**, Legendary gap p95 17 min.
Abyss (level 90, 100 MF): Legendary 0.27/min, Mythic 0.46/h.

### 2.3 Hushmarks (Curio Cart currency; never sold, never bought)
Random drops only: normal 0.15 %, champion 1.2 %, rare leader 4 %, boss 25 % (1–3), chests 0.5 % / 1.5 %, Magpie 20 %, Lantern Moth 8 %, Cursed Shrine 10 %, Hushfalls 15–50 %.
Sim: **4.1 Hushmarks per hour on Twilight** (4.3 on Nightfall) → one mid-price (5 Hushmarks) mystery item every **~1.2 h** (target 1–2 h). Prices: armour 3, one-hand weapons/shields/tomes 4, two-handers/charms 6, rings 8, amulets 10, gem pouch 2. Curio items use the same drop rules at player level (pity applies) and reveal their true rarity instantly.

### 2.4 Uniques and powers
Every Unique has one power line a 7-year-old can read ("Every hit heals you 40 life", "+1 Rag Doll"). Unique stats carry `scale_with_ilvl: true` so an Act 1 Unique stays usable when re-found at higher levels (code: scale by the base damage curve). The Codex of Light (`config/codex`) learns every power on salvage/equip, account-wide; the Runecarver's Rune of Remembering (lvl 30) imprints a learned power onto a Legendary.

## 3. Items and bases
Damage/armour curve f(ilvl): 1 → 1.0, 12 → 1.9, 28 → 3.4, 48 → 5.6, 70 → 8.6, 100 → 13, 140 → 19, then +0.15/level (190 → 26.5). Legacy ids keep their numbers.
Weapon feel: sword 1.35 aps (+crit), greatsword 1.0 (+area), axe 1.3 (+flat dmg), great axe 1.0 (+dmg %), staff 1.2 (+Wisdom), wand 1.4 (+resource regen), dagger 1.6 (+crit dmg), crossbow 1.45 (+Agility), arbalest 0.95 (+projectile dmg).
Armour lines: light (×0.6 armour; cdr / resource / cast speed / resist / move speed), medium (×1.0; crit / dodge / attack speed / move speed), heavy (×1.45; life / armour % / thorns / damage reduction). Tints are provided for the hero preview (GDD item 20).
Slot drop budget per tier: main hand 16, off hand 8, each armour slot 8, belt 6, ring 10, amulet 6, charm 5.

Class affinities (bonus with the favoured main hand; all classes can use everything):
Lanternbearer sword 15/5, greatsword 10/0, axe 8/5 · Bellstriker great axe 15/5, greatsword 12/5, axe 8/10 · Stargazer staff 15/5, wand 10/10 · Stitcher dagger 12/8, wand 12/5, staff 8/0 · Roofrunner crossbow 15/8, arbalest 12/0, dagger 8/10 (damage % / attack speed %).
Weapon proficiency 1–50 per type: `60 × 1.09^(L−1)` kills per level → level 10 ≈ 1 h, 50 ≈ 70 h with one type.

## 4. Progression 1–200

`xp_to_next(L) = 116·1.131^(L−1) + 442·L` (L < 60); after 60 × 1.0375 per level + 1768·(L−60). Monster XP `= base·(1 + 0.08·ml)`.

| Level | Cumulative (sim) | Target |
|---|---|---|
| 2 | 1.8 min | 1–3 min ✔ |
| 5 | 14 min | 8–15 min ✔ |
| 10 | 51 min | 35–60 min ✔ |
| 20 | 2.5 h | 2–3 h ✔ |
| 30 | 4.6 h | 4.5–7 h ✔ |
| 60 | 19.1 h | 15–20 h ✔ |
| 100 | 59.7 h | ≈ 56 h (GDD) |
| 200 | 434 h | ≈ 370 h (GDD est.) |

No level takes more than 2× the previous one. Model: kill stream from content, Twilight monsters at player level − 1, quests/bounties +15 % XP, rested off; after 60 the player moves Nightfall (to 75) → Abyss (to 100) → Eclipse tiers.
**Code change required:** `Progression.monster_xp()` must read `config.progression.monster_xp_level_scale` (0.08) instead of the constant 0.35. With the constant, the same curve gives level 60 in ~5.7 h and level 30 in 1.7 h (too fast). No other formula needed to change.

Skill points: 60 from levels + 10 from quests/main quest + 9 from deeds (cap 10). Sinks: 12 actives × 5 ranks + ~27 passive ranks ≈ 87 > 79, so choices matter. Respec is free forever (research #8), 3 loadouts.

## 5. Skills

- 12 actives per class in 3 branches (4 each), unlocks 1, 1, 4, 8, 10, 12, 15, 18, 22, 27, 32, 36, 40 (basic at 1). Only the effect primitives in `skill_effects.gd` are used. Minions: `ragdoll`, `patch_bear`, `pin_archer`, `scarecrow`, `puppet_knight`, `roof_decoy`, `clock_sparrow` (all `summon_only`).
- Each active: rank 2 and rank 4 each offer 3 behaviour options (bigger/longer/cheaper at rank 2; a new visible effect at rank 4 — extra wave, zone, pull, element swap, stun…). Patch format in CONTENT_SCHEMA.
- Cross-branch synergies are built in via tags: e.g. Stargazer Rime slows + *Absolute Zero* capstone (bonus vs slowed/frozen), Stitcher Hexes zones + *The Unraveller* (dolls deal more inside), Bellstriker Storm spins + *Great Carillon* (every 5th spin hit rings Ring Out).
- Capstones (15, one per branch at 25 points) change play via a `hook` and also give stats that work today. Pacts at 30: tank / damage / tempo per class.
- Hero animations only use clips present in the hero .glb files (validator enforces).

### Skill mastery (GDD v2.2, research #10)
XP from using the skill: rank r needs `180·1.34^(r−1)`; +2 % damage per rank; milestones: 5 = first visible change (wider / faster projectiles / +1 jump / lasting / sturdier summons), 10 = cheaper or faster, 15 = +1 projectile / longer zone / +1 summon / +25 %, 20 = "Echo" (signature effect repeats at half power).
At ~55 usage XP/min: rank 1 in 6 min, 5 in 0.5 h, 10 in 2.8 h, 15 in 12.8 h, 20 in 55.7 h (weeks). Costs: ranks 1–5 soot + gold (1 140 g total), 6–10 wickthread + act materials (7 700 g), 11–15 dusk essence + act mats + glowcoal (45 570 g), 16–20 Ember Hearts, Starmotes, Glowcoal, rank 20 an Echo of a Lost Bell (264 k gold total). Starmote / Echo can also be made the slow, certain way (60 Glowcoal; 3 of each boss fragment). Mastery is never lost or refunded.

## 6. Crafting & upgrade

Professions 1–50 (XP from crafting; Smith also from salvage), one station per act (Smith A1 … Runecarver A4, Cauldron A5). Guided first crafts: Upgrade, Minor Potion, Ruby combine, Rune of Tides.
- Smith: upgrade, forges (rare/epic/legendary), reforge implicit, second socket, 5 boss relics (10 fragments → guaranteed Unique), 9 Named forges (level 50).
- Alchemist: 5 potion grades, 8 elixirs (30 min of *play* time), pet treats, mount feed, 15 deterministic transmutes (salvage ladder up/down, Glowcoal → Starmote, fragments → Echo, act-material trades both ways).
- Jeweler: 3→1 gem combines for 8 gems × 4 steps, unsocket (gem returned), jewellery socket, recut, rare/epic jewellery.
- Runecarver: reroll values, remove, seal, reroll all, imprint (Codex), make greater (✦), restore Kindle.
- Cauldron: 4 secret recipes (egg, Hushmark, Toffee Key, Star Soup). Never destroys items.

Item upgrade +0…+15 (never fails, costs shown): gold `gold[L]·(1+0.03·ilvl)^1.9`, `gold[L] = 180·1.55^(L−1)`; +4 % base stats and +3 % affixes per level.

| ilvl | +1 | +5 | +10 | +15 (one item) |
|---|---|---|---|---|
| 10 | 296 g | 0.3 h | 3.2 h | 29 h of income |
| 60 | 1 273 g | 0.2 h | 2.1 h | 18.6 h |
| 100 | 2 507 g | 0.2 h | 1.8 h | 16.5 h |
| 190 | 6 681 g | 0.1 h | 1.1 h | 9.7 h |

+1 always costs well under a minute of income; a full 12-slot set to +15 at ilvl 60 ≈ 223 h of gold plus 60 Starmotes and 12 Lanternglass — a multi-week goal. Income model: drop gold (sim) + selling half of Common/Magic/Rare drops.

## 7. Monsters & bosses

Families (soul/eye colour): Rattlebones `#8fd9a0` (Act 1, unchanged polished core + mud frog, mist snail, lily ghost), Thicket-kin `#7fb8e0`, Echoes `#cfe8f0`, Frozen Court `#9cc8e0`, Hushed `#f4f4f8` (only colour in Act 5 = meaning). All built from KayKit skeletons with tint/scale/props/attachment whitelists; abilities only `slam, volley, nova_ring, summon, charge, heal_allies, teleport`.
Bosses (3.0–3.2 scale, 4–5 abilities, 2 phases each via `life_below` today + `phases[]` for code): Sunken Bellringer, Mother Bark (roots, thorn ring, twiglings, jar-step), Great Echo (copy volley, rumble, rush, bats, reverb — stand-still secret), King Who Forgot (decree, frost ring, guards, charge, toast-heal), Grey Guest (Knight model; snuff ring, grey step, quiet slam, hushlings, last volley; ends in *rekindle*). Weekly: Long Shadow. Every boss telegraph ≥ 1.0 s (validator).
Mini-bosses (2 per act, `summon_only`, placed by `zones.minibosses` / Hushfalls / quests), each with materials and 1–2 Uniques.

## 8. World, surprises, people

- Zone levels: Act 1 1–7, Act 2 14–20, Act 3 26–32, Act 4 38–44, Act 5 50–58 (floors; Twilight scales monsters to the player). Deepdark/Lightwell at 60+. The Act 1 boss now continues to Act 2's town.
- Surprise cadence: live events ≈ 24 % per zone load (Magpie always in Bellcrypt Halls); Hushfalls sum ≈ 0.26 per zone → one every ~4 zone visits, never in towns, partial reward on leave.
- 71 NPCs (12 roles + board per town, Pell, a Curio peddler per town), names/barks from `npc_text.json`. Vendors sell basic supplies only (potions, elixirs, free Homeward Wick, treats, feed, plain starter gear).
- Side quests: 91 (18–19 per act, 3 repeatable bounties per act refilling every 30 min of active play, bank 3, never expire). Rewards include 7 pets, 6 mounts and recipes. Main quest: 43 chapters with gating `requires`; first-Legendary hook on `mq_a1_04`.
- Secrets per zone (research #18): Tenth Lantern & grey cat (town), Frog (z1), Candy Crypt wall & mailbox (z2), sunken choir pew (z3), quiet bell (boss) … every story zone has at least one.

## 9. Collections, difficulty, welfare

- Pets (23; perks fetch/dig/glow/lucky/ferry; combat help only for Stitchers), mounts (10), deeds (103 with the writer's ids; counter keys in CONTENT_SCHEMA), cosmetics (45), deed milestones 100…3 500 points.
- Difficulties: Twilight 1–60 (×1, resist 0) · Nightfall 40–90 (life ×2.5, dmg ×1.9, −20) · Abyss 70–120 (×5/×3, −45) · Eclipse I–X 100…190–200 (life 7→60×, dmg 4.5→33×, −60, Starmote/Echo drops scale with tier). Mythic only from monster level 60 on Nightfall+.
- Lantern's Blessing assist (−20 % damage taken, +2 %/defeat up to 60 %, no badge, off in Last Flame). In-game moon (8 nights of active play) replaces every real-clock idea from the pitch (the 03:00 cat thread became the in-game full-moon Moonthread).

## 10. Reproduce

```
cd arpg/game
python3 tools/validate_content.py                 # 0 errors, 0 warnings
python3 tools/sim_loot.py --check                 # Tier 1 bands (exit 1 if outside QA §5.3)
python3 tools/sim_loot.py --tier nightfall --act 5 --level 60 --mf 60
python3 tools/sim_xp.py --check                   # QA §5.4 + GDD targets (needs monster_xp_level_scale in code)
python3 tools/sim_xp.py --fit                     # refit the curve after changing monster XP
python3 tools/sim_upgrade.py                      # gold/material sinks
```

## 11. Open items for code (not data)
1. `Progression.monster_xp` → read `monster_xp_level_scale` (else levelling is ~3× too fast).
2. `InventoryOps.can_equip` still enforces `classes`; `TWO_HANDED` constant → read `two_handed` from the base.
3. Affix pool: honour `affixes[].classes` (skill-rank affixes) and `config.loot.affix_rules.max_affixes`; `pick_base` should prefer the top `prefer_recent_tiers` tiers.
4. Unique stat scaling (`scale_with_ilvl`), `forge_named` and the new recipe kinds, `hooks.first_magic_s` / `first_legendary_s`.
5. Events: `count`, `portal`, act/zone filters (`*_future` fields); zone `minibosses`.
6. Passive/capstone `hook`s and future stats (`hook: "future"` in stats.json).

## Changelog — gameplay-programmer tuning (2026-09-26, Wave 2 integration)
- **Sunken Bellringer (Twilight a1_boss):** bot runs had a level-8 Stitcher going down ~13×/60 s (≈80 dps incoming vs ~290 life).
  `dmg_mult` 1.5 → 1.15, basic `attack.mult` 1.4 → 1.2, `toll` 2.2 → 1.8, `peal` 0.9 → 0.6 (14 projectiles), `lunge` 1.8 → 1.5,
  `raise` count 5 → 3. Telegraphs unchanged (≥1.0 s). Nightfall+ still scale via difficulty multipliers.
- **hearth_charge** price 0 → 150 gold (vendors + consumables): a free charge skipped the 5-min Homeward Wick cooldown entirely.
- Code notes: open items 2–6 above are implemented (see ARCHITECTURE/CONTENT_SCHEMA); implemented passive hooks:
  crit_gain_resource, low_life_buff, bonus_vs_status, chain_bonus_jumps, dodge_next_crit, aoe_repeat_chance,
  quake_stun_bonus, minion_death_burst, block_casts, holy_area_leaves_zone, zone_expire_burst.

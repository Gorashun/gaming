# Game Design Document — v2 · WICKWRIGHT (working title)

> **v2 = Gate 1 resolutions (binding).** All reviewers (producer, QA, systems, UI/UX, art, player-safety, legal) returned APPROVE WITH CHANGES; the changes below were accepted by the lead and override anything later in this document.
>
> 1. **Title:** *Wickwright* (store: "Wickwright: Carry the Light"); backup *Lumenholm*. "Lanterna"/"Glimmerfall" dropped (conflicts). Formal attorney clearance required before launch (docs/legal/TITLE_CHECK.md).
> 2. **Scope:** the owner requires the full feature set (5 classes, 5 acts, lvl 200, all tiers, hardcore, crafting). Order of work: polish Act 1 + all 5 classes to playtest quality first (PLAN.md M2), then extend acts 2–5 via data + generation. Breadth never ships unpolished.
> 3. **Welfare (binding: design/PLAYER_WELFARE.md):** no near-miss/slot reveals (outcome decided before any animation; true rarity from frame 1; skippable); no ads incl. rewarded; no accounts/third-party analytics/open chat/idle auto-play; no purchase prompts in gameplay; single store screen behind parental gate, purchase lock on by default; parental menu (opt-in play-time reminder, graceful daily limit, hide Hardcore/leaderboards); no notification permission; zone/boss summary screens = natural stopping points; next run never auto-starts; autosave + auto-pause on focus loss; interrupted Lightwells give partial reward; Rested Glow accrues ~5 %/h up to 1 level (fills 8–24 h), framed positively only; pity counts active play only; weekly-boss bonus banks up to 3 (no expiring lockouts); in-game moon cycle within normal play time.
> 4. **Hardcore ("Last Flame"):** softcore pre-selected; Last Flame unlocks after first story completion (or via parental toggle), illustrated warning + hold-to-confirm; backgrounding/crash/call/low battery never kills (auto-pause, no damage while paused); on death offer "Carry the ember on" (continue as softcore copy) — memorial remains in Hall of Embers. Playtest builds can restore bug-caused deaths.
> 5. **Rarity colours:** Common grey · Magic blue · Rare yellow `#FFD23F` · Epic purple · Legendary orange · Mythic crimson + white core · **Unique green `#3DDC84` (crown)** · Named cyan-white (sun). Threat red `#FF2B2B` reserved for enemy telegraphs/projectiles. Mythic drops from monster level 60 on Nightfall+.
> 6. **First-session hook (scripted):** first kill ≤30 s, first Magic ≤2 min, lvl 2 ≤3 min, first elite = guaranteed Rare, scripted first Legendary w/ golden moment at ~10–12 min, Magpie Imp always in zone 2. HUD "Lantern meter" shows pity. Session end → "Next goal" card.
> 7. **Builds:** each active skill has 2 behaviour modifiers picked at rank 2 and 4 (from 3 options each) + tags (element, Melee/Projectile/Area/Minion) that affixes and powers hook into. Glow builds on block/taking damage (distinct from Fury). Target ≥3 viable builds per class by lvl 60 (bot-verified). Free respec until lvl 20, then cheap gold respec; starmap respec free.
> 8. **Class↔model:** Knight=Lanternbearer, Barbarian=Bellstriker (bell-head 2H), Mage=Stargazer, Rogue=Stitcher (warm patchwork palette, open spellbook + needle dagger; dolls = 0.6× patchwork Skeleton_Minion), Rogue_Hooded=Roofrunner (dark slate, crossbow). All share a 41-joint rig → any animation on any model.
> 9. **Monsters:** roster per design/ART_BIBLE.md + Gate 1 art review (5 families × 6 types, bosses as scaled composites). Min telegraph: 1.0 s Twilight, 0.8 s other tiers, bosses 1.0–1.6 s.
> 10. **Difficulty:** tier table owns level bands, life/damage multipliers and resist penalty (Twilight 0, Nightfall −20, Abyss −45, Eclipse −60), applied once on top of level scaling; packs may override. Monster level = max(zone base, tier band min) scaled toward player level within band.
> 11. **Controls/UI:** dedicated Dodge button; Attack 160 px, skills/dodge/potion 112 px at 1280×720; "Simple mode" (auto-attack, auto-pickup, auto-equip clear upgrades with Undo, auto-spend points); layout editor + left-hand mirror; every screen ≤2 taps from HUD; loot filter defaults to Hide Common after lvl 15; "Best gear" button; Legendary+ overflow → mailbox.
> 12. **Crafting staged:** one station per act (Smith A1, Alchemist A2, Jeweler A3, Runecarver A4, Cauldron A5/endgame) with a 30 s guided first craft; Kindle odds shown as a range; Epic+ crafts & salvage hold-to-confirm; Cauldron never destroys items.
> 13. **Renamed (legal):** Gilded Gremlin/Vault → **Magpie Imp** / **Magpie's Hoard**; timed endgame = **Lightwells**, ranked = **Lightwell Trials** (never "rift"); starmap = **Brightness** (never "Paragon"/"Light Level"); crafting potential = **Kindle** (never "Forging Potential"). All names pass docs/legal/BLOCKLIST.md.
> 14. **Tech:** packs are data + assets only (no scripts); DLC ships bundled/Play Asset Delivery and unlocks by entitlement; `pack.json` gets `format_version`, `engine_min`, versioned `requires`; unknown ids in saves become placeholders. RNG seeded per character/run (`--seed` override), stream state saved. Saves atomic + 3 rolling backups. Light budget: hero light + 3 nearest real lights; other torches = emissive + halo. Outlines only on hero/elites/bosses/loot. CLI test flags + JSONL metrics per QA.md; balance contract = QA.md §5. Build id on screen, gated debug menu, offline feedback export.


Language: **English** (UI, lore, all player-facing text). Platform: **Android first** (reference device: Pixel 8 Pro), iOS later from the same codebase. Engine: Godot 4.7 (GDScript). Audience: 7+ (PEGI 7 target).

This GDD is the single source of truth. Research inputs (Swedish) live in `research/` and `lore/UNIVERSUM-PITCH.md`.

> **v2.1 — Owner additions (binding):**
> 15. **Big loot tables:** many bases per slot and tier, large affix pools, 40+ legendary powers, 30+ uniques, named set pieces, gems — drops must feel varied every session.
> 16. **One art style only:** the older repo files (pixel item icons, hand-painted wall textures) are not used. All assets must match the chibi 3D style and animate smoothly.
> 17. **Item upgrading (gold/material sink):** every item has an Upgrade level +0…+15 (Smith). Each step costs gold + materials (rising steeply), boosts base damage/armour and all affixes; success is guaranteed (no break/fail — welfare), costs are shown up front.
> 18. **Many NPCs:** each town has 6+ named NPCs (smith, alchemist, jeweler, runecarver, trader, stash keeper, stablemaster, pet keeper, quest-giver, storyteller) with barks and small side quests.
> 19. **Any class, any weapon:** all classes can equip all weapon types. Each class has weapon affinities (+damage/+speed bonus with favoured types). **Weapon proficiency** levels 1–50 per weapon type rise with kills using that type, granting permanent bonuses — build freedom.
> 20. **Gear is visible:** the in-game hero model shows the equipped weapon/off-hand prop and gear colours; the Hero screen shows a live 3D preview of the character.
> 21. **Pets (non-combat for most classes):** collectible companions (found as rare drops, events, quests, crafted), with levels 1–30 gained by adventuring. Pets auto-collect loot, add magic/gold find, find bonus materials, and occasionally dig up treasure. Only minion classes (Stitcher) get combat help from them.
> 22. **Mounts:** unlocked from the Stablemaster (gold + quest), faster travel in zones and towns; dismount on attack/hit.
> 23. **Fast travel:** waypoints unlocked by visiting; travel between any unlocked waypoints from the map for a small gold fee (free to town).
> 24. **Homeward Wick (hearth):** return to your bound town from anywhere (3 s channel, 5 min cooldown, free); bind to any visited town at its innkeeper.

> **v2.2 — Owner additions (binding):**
> 25. **Skill mastery:** every skill earns usage XP; each mastery rank (1–20) unlocks only after reaching its XP threshold AND paying gold + materials (cheap common mats early; super-rare mats or large volumes late). Milestones at 5/10/15/20 change how the skill plays.
> 26. **Long rewarding grind:** late progression (item +15, mastery 20, starmap, professions 50, pets 30) takes weeks, always with visible progress bars and milestone rewards; early ranks arrive in the first sessions.
> 27. **Fun skill trees:** meaningful choices, cross-branch synergies, behaviour-changing passives, capstones; decisions informed by docs/research/player_wants.md.

> **v2.3 — Owner additions (binding):**
> 28. **Merchants:** each town has several merchants selling BASIC supplies only (potions, elixirs, Homeward Wick charges, pet treats, mount feed, plain Common starter gear, salvage-to-buy basics). No powerful gear for sale.
> 29. **Curio Cart (mystery merchant, owner's "black market"):** spend **Hushmarks** (rare RANDOM drop — hard to come by; ~1 mid-price mystery item per 1–2 h of play — NEVER purchasable with real money) to buy a mystery item of a chosen category (weapon type or armour slot, e.g. "Mystery Sword", "Mystery Helm", "Mystery Ring"). Result is rolled with the SAME loot tables, rarity weights, item level and pity as monster drops. Welfare: result decided before any animation, true rarity shown instantly, no reels/near-miss, cost shown up front, no timers or limited offers. Price scales by slot (jewelry costs more).

> **v2.4 — Owner addition (binding):**
> 30. **Hushfalls (random world events):** occasionally (≈1 per 3–5 zone visits, rarer in towns: never) a tear of Hush opens at a random spot in a zone: screen-edge glow + sound + minimap marker. Entering starts 2–4 escalating stages of themed waves (sometimes a different act's family, sometimes an elite pack or a "cursed" modifier), ending with a mini-boss; reward = cache chest with boosted rarity + Hushmark chance + materials. Variants: Invasion (waves), Cursed Shrine (survive modifier), Treasure Swarm (Magpie Imps), Lost Wisp escort, Echo Duel (mirror of your class). Optional, no real-time timers, no penalty for ignoring; progress bar per stage. Name never uses "rift".

> **v2.5 — Owner additions (binding):**
> 31. **Main questline:** long, chaptered story campaign (Act 1–5 + Deepdark epilogue), ≥6 chapters per act with varied objectives (reach, rekindle, collect, escort wisp, talk, solve, boss), story beats, twists and short dialogue scenes; completing chapters gives skill points/rewards; replayable on higher tiers for bonus rewards.
> 32. **Many more side quests:** ≥15 per act (incl. repeatable bounty boards that bank, never expire).
> 33. **Achievements ("Deeds"):** tiered (e.g. Rekindle 100 → 1,000 → 10,000 → 100,000 skeletons), categories: combat, exploration (zones, secrets, waypoints), crafting (crafts, upgrades, mastery), collection (uniques, Codex, pets, mounts), story, difficulty tiers, bosses, economy, Hushfalls, Last Flame. Rewards: titles (shown under name), cosmetics (cape/aura/name-frame/pet hat/mount tint), occasional skill point or small permanent stat (account-wide where sensible), Deed points with milestone rewards. No time-limited achievements (welfare).

## 1. Pillars
1. **Every kill can surprise you.** Loot, events and secrets are variable and frequent — rewards come from *play*, never from a shop.
2. **Juicy, readable combat.** Chibi heroes, dark world, bright attacks. Every hit feels good on a phone.
3. **Deep but friendly.** Builds, crafting and 200 levels for the veteran; icons-first, auto-everything options for a 7-year-old.
4. **Built to grow.** Everything is data. New acts, classes, items, monsters and difficulty tiers are content packs — no engine changes.
5. **Fair and healthy.** No loot boxes, no energy, no FOMO, no punishing streaks, no retention push notifications. Rested bonus rewards breaks.

## 2. Premise
The World-Lantern has been blown out by the Grey Guest. The Hush spreads, eating colour, sound and memory. Monsters are the **Snuffed** — creatures that forgot who they were. Defeat one and its light is rekindled: it bursts into sparks and flees home (no gore). The player is a Wickbearer carrying the last flame.

## 3. Core loop
Fight (seconds) → loot (seconds–minutes) → equip/salvage/craft (minutes) → clear zone / rift (3–6 min) → level up, spend points (session) → push difficulty tier (days) → chase Mythic/Named & constellation (weeks–years).

## 4. Classes (5 at launch, 6th = first expansion)
| Class (working names, legal review) | Model (KayKit CC0) | Role | Resource |
|---|---|---|---|
| Lanternbearer | Knight | Tank / holy-fire melee | Glow (builds on hit) |
| Bellstriker | Barbarian | Berserker, AoE melee | Fury (builds on hit, decays) |
| Stargazer | Mage | Ranged caster, elements | Mana (regenerates) |
| Stitcher | Rogue | Summoner: sews cloth-doll minions | Thread (regenerates, spent on dolls) |
| Roofrunner | Rogue_Hooded | Agile assassin, traps, crossbow | Energy (fast regen) + combo points |
| *Rootweaver (exp.)* | TBD | Shapeshifter druid | Sap |

Each class: 1 basic attack, 12+ active skills across 3 branches, passives, 1 **Pact** choice at level 30.

## 5. Progression (level 1–200)
- **Levels 1–60 — Skill Tree:** 1 skill point per level + 10 from quests (70 total). 3 branches per class; skills rank 1–5; branch passives unlock at 5/15/25 points.
- **Levels 61–200 — Starmap ("Brightness"):** 2 star points per level (280 total). ~40 constellations shared by all classes plus class-specific clusters; completing a constellation grants a bonus. Glyph sockets from endgame.
- XP curve target (estimate, to be simulated): L60 ≈ 17 h, L100 ≈ 56 h, L200 ≈ 370 h. Level bar has 4 sub-ticks.
- **Rested Glow:** offline time accrues up to +100% XP for the next ~20 min of play (rewards breaks).

## 6. Difficulty (story tiers + endgame tiers)
Names are working titles pending legal check; do not use Normal/Nightmare/Hell.
| Tier | Name | Unlock | Monster lvl | HP/Dmg × | Loot bonus |
|---|---|---|---|---|---|
| 1 | Twilight | start | 1–40 | 1.0 | base |
| 2 | Nightfall | finish story on Twilight | 40–70 | 2.5 | +Epic chance, Legendary ×2 |
| 3 | Abyss | finish story on Nightfall | 70–100 | 6 | Mythic can drop |
| 4+ | Eclipse I–X | finish Abyss | 100–200 | scaling | +Mythic, Named materials |

Players can replay acts at any unlocked tier. Monster level scales inside tier bands. Resistance penalty per tier (−15/−35/−60) forces gearing, like the genre's classic model.

**Hardcore mode — "Last Flame":** chosen at character creation, one life, separate stash, gold name frame; on death character is entombed in the Hall of Embers (read-only memorial). Softcore = respawn at checkpoint, lose nothing (7+ friendly).

## 7. Items
Rarities (drop weights are starting values, simulated in `tools/sim_loot.py`):
| Rarity | Colour + frame shape | Affixes | Base weight |
|---|---|---|---|
| Common | grey, square | 0 | 56% |
| Magic | blue, rounded | 1–2 | 30% |
| Rare | yellow, diamond | 3–4 | 9.5% |
| Epic | purple, hexagon | 4–5 (+1 greater) | 2.8% |
| Legendary | orange, star + beam | 4 + legendary power | 1.6% |
| Mythic | red-white, flame + beam + stinger | 5 greater + power | 0.1% (Abyss+) |
| Unique | gold, crown | fixed identity, boss-specific | per boss ~1/40 |
| Named | cyan-white, sun | crafted only, build-defining | recipe |

- Item level drives affix tiers. Smart loot: 75% for active class.
- **Pity (visible):** Legendary guaranteed within ~45 min of play; Mythic soft pity at 8 h, hard at 20 h. Boss fragments: 10 = guaranteed boss material.
- Slots: head, chest, hands, legs, feet, main hand, off-hand, amulet, 2 rings, belt, charm (12).
- Inventory: grid of slots (1 cell per item), 40 slots + stash tabs; auto-salvage by rarity; quick-compare arrows; loot filter presets.

## 8. Crafting
Four professions, each level 1–50, gain XP by crafting/salvaging: **Smith** (weapons/armour, reforging), **Alchemist** (potions, elixirs, material transmutes), **Jeweler** (gems, sockets, rings/amulets), **Runecarver** (runes, enchant/reroll affixes).
- **Kindling (forge potential):** each item has Kindle points; each craft (add/upgrade/reroll affix) costs points with a chance to spend extra. Deterministic preview of odds.
- Material tiers per act + difficulty. Salvaging returns materials.
- **The Cauldron:** combine any items/materials to discover secret recipes (journal records discoveries).
- **Named weapons:** 5+ recipes at launch, each needing "impossible" materials tied to secrets (e.g. *Echo of Stillness*: stand still 30 s during a boss fight; *Moonthread*: from the Tenth Lantern, which appears on in-game full moon nights). No real-world clock gates.

## 9. World
5 acts, each a hub + 3–5 generated zones + boss arena. Zones are generated from seeded room graphs using the dungeon kit and biome palettes (lighting, fog, props, monster families).
1. **Wickmire** (bog / graveyard) — boss: The Sunken Bellringer
2. **Whisperwood** (dead forest) — boss: Mother Bark
3. **Echo Mines** — boss: The Great Echo
4. **Rimehall** (frozen castle) — boss: The King Who Forgot His Name
5. **Well of Hush** — final boss: The Grey Guest (rekindled, not destroyed)
Endgame: **Deepdark** — timed "Lightwells" (rift-like, 3–6 min), keyed Deepdark runs with modifiers, weekly boss, leaderboard (local only until online).

Surprises (random, frequent enough to expect but not predict): Gilded Gremlin (runs, drops gold, rare portal to the Gilded Vault), Candy Crypt secret level, Tea Party behind the waterfall, cursed shrines, treasure goblets, mystery eggs that hatch after N kills, elite packs with affixes.

## 10. Monsters
Families per act (5 × 6–10 types) + elites (champion packs, rare with 2–4 affixes) + bosses (multi-phase, telegraphed ground markers). Skeleton models (CC0) cover undead families; other families use recoloured/scaled models plus procedural creatures (wisps, slimes, ghosts, bats, lanterns) built in-engine.

## 11. Controls & UI
Floating joystick left; attack + 4 skills + potion in an arc right (≥56 dp). Tap = auto-aim, hold = manual aim. Optional auto-attack mode. Rarity always shown by colour + frame shape + icon. Text scale, screen-shake slider, colour-blind/high-contrast modes. Full-screen "golden moment" card for Legendary+ shows after combat ends.

## 12. Monetisation
Premium (one-time purchase) or free demo + one unlock. Expansions (acts/classes) as paid DLC packs. No ads, no random paid rewards, no premium currency. Cosmetics only with known contents, behind parental gate.

## 13. Technical direction (see ARCHITECTURE.md)
Data-driven content packs; multiplayer-ready authority layer (not implemented at launch); seeded RNG streams; offline-first local saves with versioned migration; Android AAB via GitHub Actions.

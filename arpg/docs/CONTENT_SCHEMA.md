# Content schema (contract between data and code)

All tables live in `game/content/<pack>/<table>.json` as arrays of records with a unique `id`. Code reads via `Content.get_rec(table, id)`, `Content.all(table)`, `Content.where(table, key, value)`, `Content.cfg(config_id, key, default)`. Existing tables and their fields are defined by current files in `content/base/` — keep them backward compatible. New tables/fields for Wave 1 are below. **Code must tolerate missing optional fields.**

## Items
- `item_bases`: `id, name, slot (head|chest|hands|legs|feet|belt|main_hand|off_hand|ring|amulet|charm), type, type_name, min_ilvl, model (res:// path to .gltf/.glb prop), weight, dmg[min,max], aps, armor, implicit{stat:[min,max]}, sockets, two_handed(bool)`. `classes` is now only a **drop-weight hint** (smart loot), never an equip restriction.
- `weapon_types`: `id (sword|axe|axe2h|mace|staff|wand|dagger|crossbow|bow|spear|shield|tome|quiver|orb), name, hand ("main"|"off"|"two"), prop (default model), attach ("handslot.r"|"handslot.l"), anim_set ("1h"|"2h"|"ranged"|"caster"|"dual"), proficiency_bonus{stat: per_level}`.
- `classes[].affinities`: `{weapon_type: {"damage_pct": n, "attack_speed_pct": n}}` — bonus when the equipped main-hand matches.
- `config/proficiency`: `{max_level: 50, xp_per_kill: n, curve: {base, growth}}`. Character stores `proficiency{weapon_type: {level, xp}}`.
- `config/upgrade`: `{max: 15, stat_per_level_pct: n, gold: [cost per level...], materials: [{mat: count} per level...]}`. Items store `upgrade:int`. Upgrading never fails.
- `uniques`: `id, name, base, rarity ("unique"), flavor, stats[{stat,min,max}], power, drop{monster|act|any, chance}`.
- `named`: `id, name, base, flavor, stats[...], power, recipe` (recipe id in `recipes`).
- `powers`: `id, name, desc, class ("" = any), slots [], stats{}, hook (optional code hook name), params{}`.
- `sets` (optional later): `id, name, items[], bonuses{2:{},4:{}}`.

## Pets (non-combat unless class minion synergy)
- `pets`: `id, name, model (res:// path), scale, tint, rarity, source ("drop"|"event"|"quest"|"craft"|"vendor"), drop_chance, max_level (30), bonuses_per_level{magic_find, gold_find, pickup_radius, material_find, xp_pct}, perk ("dig"|"fetch"|"glow"|"lucky"...), perk_params{}, desc`.
- Character: `pets_owned{pet_id: {level, xp}}`, `active_pet`.

## Mounts
- `mounts`: `id, name, model, scale, tint, speed_pct, source, cost_gold, requires (quest/achievement id), desc`.
- Character: `mounts_owned[]`, `active_mount`. Mount only outside combat; dismount on attack/hit.

## NPCs & quests
- `npcs`: `id, name, role (smith|alchemist|jeweler|runecarver|trader|stash|stablemaster|petkeeper|innkeeper|questgiver|storyteller|waypoint), town (zone id), model, attachments[], tint, anim, screen (UI screen to open), barks[], greeting, quest_ids[]`.
- Zones with `town: true` list `npcs: [npc ids]` (replaces `stations`).
- `quests`: `id, name, giver (npc id), act, type ("kill"|"collect"|"explore"|"boss"|"talk"), target (monster/zone/material id), count, reward{gold, xp, item_rarity, pet, mount, recipe, skill_points}, text_offer, text_done, repeatable(bool)`.

## Travel
- `config/travel`: `{fee_per_act_distance: n, town_free: true, hearth_cooldown_s: 300, hearth_channel_s: 3}`. Character: `bound_town` (zone id), `hearth_ready_unix`.

## Skills (extension)
- `skills[].modifiers`: `[{rank: 2|4, options: [{id, name, desc, patch: {effects index or key: value}, stats: {}}]}]`. Character stores `skill_mods{skill_id: [option ids]}`.
- `skills[].weapon_req` optional list of weapon types (e.g. crossbow skills prefer ranged; if missing any weapon works).

## Starmap (Brightness, levels 61–200)
- `starmap`: nodes `id, name, kind ("star"|"constellation"), pos[x,y], links[], stats{}, class ("" any)`; constellations: `id, kind "constellation", name, nodes[], bonus{}`.

## Monsters (extension)
- `monsters[]`: add `act`, `tier_min` optional; `boss: true` for act bosses; `phases: [{life_below, abilities_add[], speed_mult}]` for bosses.

---
# Wave 2 additions (systems designer, 2026-09-26). Data lives in `content/base/`; generator-free JSON is the source of truth. Validate with `python3 tools/validate_content.py`.

## Items (additions)
- `item_bases`: `two_handed` is authoritative (types greatsword, axe2h, staff, arbalest); code should stop using the `InventoryOps.TWO_HANDED` constant. `armor_class` (light|medium|heavy), `tint` (gear colour for the hero model), `variant` (alternate prop line), `starter` (vendor/starting gear, `weight: 0` = never drops). Weapon `classes` is a smart-loot hint only; armour/jewellery have none.
- `affixes`: optional `classes` (drop hint: only roll on items for those classes; used by `skill_rank:*` affixes), stat ids may be `skill_rank:<skill_id>` (+N ranks to that skill; a stat record with `hook: "skill_rank"` exists for each). Tiers: 8 ilvl steps `1,10,22,38,58,82,115,165`.
- `stats`: records with `hook: "future"` are valid affix/power stats that code does not read yet (pickup_radius, pet_xp_pct, potion_effect_pct, potion_charges, material_find, proficiency_xp_pct, mastery_xp_pct, life_per_kill, resource_on_kill, elite_damage_pct, boss_damage_pct, mount_speed_pct, minion_life_pct, all_skill_rank, hushmark_find).
- `powers`: `pool` ("legendary"|"unique"|"named"), `codex` bool, `codex_category`. Unique/Named powers have `slots: ["__unique"]` / `["__named"]` so the random-Legendary filter never picks them. Optional `hook` + `hook_desc` = future behaviour; `stats` always work today.
- `uniques`: `class` (hint), `drop {monster|boss|event: id, chance}` (mirrored into `monsters[].uniques`), `scale_with_ilvl` (code should scale stat ranges by `f(ilvl)/f(source level)`), `codex`.
- `named`: `secret` (lore id), `grows {echoes, boss_kills_per_echo, stat_per_echo_pct}`; recipe kind `forge_named` (`named` = id).
- `rarities`: `pity_soft_seconds` (Mythic), `codex`.
- `config/upgrade`: `gold[L-1] * (1 + ilvl*gold_ilvl_mult) ^ gold_ilvl_exp`, `stat_per_level_pct` (base dmg/armour), `affix_per_level_pct`, `materials[L-1]`, `never_fails`.
- `config/loot.affix_rules`: `max_affixes` per rarity (hygiene: 4 on Rare/Epic/Legendary), `class_weighting`, `unique_duplicate_protection`, `wish`.

## Codex of Light
- `config/codex {learn_on, kinds, account_wide, upgrade_entry_on_better_roll, imprint_recipe}`. Records with `codex: true` are collectable. Imprint = recipe kind `imprint_power`.

## Skill modifiers (patch format)
- `skills[].modifiers[{rank: 2|4, options[3]: {id, name, desc, patch?, add_effects?, stats?}}]`.
- `patch` keys: a top-level skill key (`cooldown`, `cost`, `element`, `targeted`) or `effects.<i>.<key>` (replace that effect field). `add_effects`: effect records appended to `effects`. `stats`: stat source active while the skill is on the bar. Only the effect primitives in `skill_effects.gd` are used.
- `skills[].branch_name`; `classes[].branches[{id, name, passive_tiers:[5,15,25]}]`, `classes[].pacts[]`, `pact_level: 30`, `classes[].affinities`.

## Skill mastery
- `skills[].mastery {per_rank {stat: v}, milestones[{rank: 5|10|15|20, name, desc, patch?, add_effects?, stats?}]}` — milestone patches use the modifier patch format and stack after modifiers.
- `config/skill_mastery {max_rank: 20, xp_base, xp_growth, xp_per_hit, xp_per_kill, xp_per_cast_utility, per_rank_default, milestone_ranks, costs[{rank_from, rank_to, gold, materials{id|"act_material": n}}], never_refunded_or_lost}`. XP to go from r-1 to r = `xp_base * xp_growth^(r-1)`. `act_material` = player's choice of any common act material.
- Character: `skill_mastery{skill_id: {rank, xp}}`.

## Passives
- `passives`: `id, name, class, branch ("" = general), kind ("passive"|"capstone"|"pact"), max_rank, stats (per rank), requires_branch_points (5/15/25), unlock_level, desc, hook?, params?`. Capstones carry a `hook` (behaviour change) plus stats that work today. Pacts: kind "pact", unlock 30, stored in `character.pact`.

## Weapon proficiency
- `config/proficiency {max_level 50, xp_per_kill, xp_per_elite, xp_per_boss, curve{base, growth}}`; bonus = `weapon_types[].proficiency_bonus[stat] * level`.

## Materials, recipes, consumables
- `materials`: `category` (salvage|upgrade|act|boss_fragment|quest|currency|egg|named|gem), `act`, gems `gem_type`, `grade` 1–5 (grade-2 id = plain gem id, e.g. `ruby`), `quest_item`, `drop_while_quest_active`, named materials `secret`, `hushmark` `never_sold`.
- `recipes.kind`: existing + `upgrade_item`, `forge` (`slot` may be `main_hand|ring|amulet|choose_armor|choose_jewelry`), `reroll_implicit`, `brew`, `transmute`, `combine`, `unsocket`, `gem_convert`, `reroll_values`, `remove_affix`, `seal_affix`, `reroll_all`, `imprint_power`, `make_greater`, `restore_kindle`, `cauldron` (secret, `discovery: true`), `forge_named`. `output {id: count}` = material or consumable ids. Profession `cauldron` (max_level 1).
- `consumables`: `id, name, kind (potion|elixir|hearth|pet_treat|mount_feed|key), min_level, effect{heal_pct|stats+duration_s(counts play time)|pet_xp|opens}, price_gold, stack_max, desc`.

## Vendors & Curio Cart
- `vendors`: `{id, npc, town, stock[{kind: item_base|material|consumable|pet, id, price_gold, rarity?, ilvl?: "player_level"}]}` — basic supplies only, never random items, never Hushmarks.
- `curio_offers`: `{id, name, category {weapon_type|slot|material}, price_hushmarks, min_level, roll: "standard_drop"}` — rolled with normal drop rules at player level (pity applies), instant true-rarity reveal. `config/curio`.
- Hushmark sources: `config/loot.kinds.*.materials` (normal 0.15 %, champion 1.2 %, rare 4 %, boss 25 % ×1–3, chests 0.5–1.5 %, events), Hushfall rewards, cauldron. Never purchasable.

## Hushfalls
- `world_events`: `{id, name, kind (invasion|cursed_shrine|treasure_swarm|escort|echo_duel), chance_per_zone, min_level, never_in_towns, stages[{waves[{monsters: [id|"family:<f>"|"any_family"], count, elite_chance}], modifier (monster_affix id)?, curse {stat: v}?, survive_s?, timer_s?, escort?}], boss, reward{loot_kind, materials[{id, chance, min, max}], bonus_rarity{}, pet_chance?, mount_chance?}, announce, color}`. Loot kind `hushfall_cache` in config/loot.

## Events (additions)
- `events`: `count` (pack events), `portal`/`portal_chance`, `reward_material`; fields `chance_future`, `acts_future`, `zones_future` are inactive until code filters by act/zone (their `chance` is 0). Loot kinds `goblet, shrine, egg, moth` exist in config/loot.

## Zones (additions)
- `secrets[{id, lore?, kind, hint?, reward{material|pet|mount|lore|portal|deed|gold|item_rarity|title}}]` (≥1 per story zone), `minibosses[]`, `miniboss_chance`, `waypoint`, `hearth_bind`, `lore`, `special` (not in act progression), `endgame`, `key`, `peaceful`. Towns keep legacy `stations` and add `npcs`.

## Main quest, puzzles, escorts
- `main_quest`: `{id, act ("act1".."act5"|"deepdark"), order, objectives[{type reach|rekindle|collect|escort|talk|solve|boss, target, count, zone, drop_while_active?}], rewards{xp_levels, gold, skill_points?, item_rarity?, unlock? ("act:<id>"|"profession:<id>"|"feature:<id>"|"difficulty:<id>"|"waypoint:<zone>"), hook?, title?, cosmetic?}, requires, next, text_ref}`. Targets: zone/monster/npc/material/lore id, puzzle, escort, `"brightness"` (count = level), `"deepdark"`/`"lightwell"` (count = runs completed).
- `puzzles`: `{id, zone, kind (sequence|find_one|riddle|order|path), desc, ...params}`. `escorts`: `{id, zone|"any", creature{name, model, scale, tint}, path, speed, waits_for_player, can_fail}`.
- `quests` (side): `type` kill|collect|explore|boss|talk; `reward {gold, xp_levels (fraction of current level), item_rarity, pet, mount, recipe, skill_points, material{}, consumable{}}`; bounties: `bounty: true, repeatable: true, refill{per_active_play_minutes: 30, bank_max: 3, expires: false}`.

## Deeds (counter keys the programmer emits)
- `deeds`: `{id, category, stat (counter key), tiers[{goal, points, reward{title?, cosmetic?, skill_points?, stats?, mount?}}], hidden, text_ref}`; `deed_milestones {id "dm_<points>", points, reward}`; `cosmetics {id, kind cape_tint|aura|name_frame|pet_hat|mount_tint|title_color, color, desc}`. Skill points from deeds total 9 (cap 10 in config/deeds).
- Counter keys (increment via `stats_tracking[key]`; `flag:*`/`secret:*` set to 1; `level`/`*_max`/`prof_level:*` are set to the current value):
  `kills`, `kills:family:<family>`, `kills:elite`, `kills:elite_3plus_affixes`, `kills:monster:<id>`, `kills:boss:<id>`, `dodges`, `telegraphs_avoided`, `crits`, `potions_used`, `combo10`, `minion_kills`, `stuns`, `hits:skill:<skill_id>`, `hits:tag:<tag>`, `blocks`, `proficiency_types_at_50`, `skills_at_mastery_20`, `waypoints`, `zones_cleared`, `secrets`, `secret:<secret_id>`, `mailbox_letters`, `zone_entered:<zone>`, `riddles_answered`, `mount_distance_m`, `hearth_uses`, `journal_pages`, `deepdark_runs`, `lightwells_completed`, `lightwell_trial_depth_max`, `crafts`, `items_at_plus15`, `kindle_spent`, `salvages`, `prof_level:<prof>`, `cauldron_discoveries`, `gems_socketed`, `named_forged`, `uniques_found_distinct`, `legendaries_found`, `mythics_found`, `codex_entries`, `monster_kinds_met`, `pets_owned`, `pets_at_level_30`, `mounts_owned`, `eggs_hatched`, `cosmetic_hats_owned`, `main_quest_chapters`, `side_quests_completed`, `bounties_completed`, `story_complete_classes`, `story_complete:<tier>`, `level`, `eclipse_boss_tier_max`, `boss_kills_no_hit`, `boss_fragments_collected`, `gold_earned`, `items_sold`, `curio_bought`, `hushmarks_earned`, `respecs`, `hushfalls_completed`, `hushfalls:<kind>` (invasion, treasure_swarm_perfect, escort, echo_duel, cursed_shrine), `lastflame_level`, `lastflame_story_complete`, `flag:hall_of_embers_visited`, `flag:pell_name_before_act5`, `flag:bran_moth`, `flag:ada_sat`, `rested_full_returns`, `summary_return_to_town`, `emote:hat_tip:nobody_hat`, `thank_you_squeaks`.

## Pets / mounts (additions)
- `pets`: `source_ref` (monster|event|zone|quest|recipe|npc id), `combat_for[]` (classes that get combat help: stitcher), `price_gold` (vendor), `tricks[{level, trick}]`, `codex`. Perks: `fetch{radius}`, `dig{chance}`, `glow{light_radius}`, `lucky{double_gold_chance|extra_affix_chance}`, `ferry{trip_seconds}` (carries salvage/sell loads to town). `config/pets`.
- `mounts`: `source` quest|vendor|deed|secret|hushfall, `requires` (quest/deed/lore/world_event id), `art_needed` (placeholder skeleton models).

## Assist, respec, hooks, moon
- `config/assist` (Lantern's Blessing: −20 % damage taken, +2 %/death, cap 60, off in Last Flame, no badge), `config/respec` (free skills + starmap, 3 loadouts, mastery never refunded), `config/hooks` (first-session script: first_legendary_s 660; main quest `mq_a1_04` carries `hook: "first_legendary"`), `config/moon` (in-game 8-night cycle counted in active play; never device clock), `config/bounties`, `config/merchants`, `config/mounts`, `config/world_events`, `config/hushfall`, `config/deeds`.

## Progression
- `config/progression.monster_xp_level_scale` (0.08) replaces the `0.35` constant in `Progression.monster_xp()`: `base_xp * (1 + S*ml)`. The tuned curve (xp_base 116, growth 1.131, linear 442, post60 1.0375) assumes S is read from config — with the old constant players reach 60 in ~6 h instead of ~19 h.

## Wave 3 additions (QA_REPORT tuning)
- `monster_affixes[].min_level`: the elite affix is only rolled when the monster level ≥ this (mender 5, huge 3, frozen 4, vampiric 5, teleporter 6, molten 8). Code must filter the affix roll (and roll per pack without replacement).
- `difficulties[].max_hit_pct_non_boss` (40, Eclipse): cap for a single non-boss hit as a fraction of max life (code clamp / sim check).
- `curio_offers[].min_rarity` ("magic") and `source_kind` ("champion"): `Merchants.curio_buy` should roll with the `champion` loot-kind bonus and reroll/raise below `min_rarity` using the normal weights above it (true odds, instant reveal).
- `config/upgrade.stat_per_level_pct` 5 and `milestone_bonus_pct {"5":10,"10":10,"15":10}` (also in `milestones[L].bonus_pct`): extra base damage/armour % added at +5/+10/+15 → +105 % at +15.
- `pets[].drop_chance_from_source`: per-kill chance when only the `source_ref` monster rolls it (use this if `Pets.roll_drop` starts honouring `source_ref`; `drop_chance` is tuned for today's "every kill rolls every drop pet").
- `rarities.legendary.pity_note`; legendary `pity_seconds` 3540.

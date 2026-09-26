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

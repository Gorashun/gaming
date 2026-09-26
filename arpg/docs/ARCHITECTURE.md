# Architecture

Godot 4.7.2, GDScript, renderer **GL Compatibility** (GLES3 — runs on every Android device incl. Pixel 8 Pro, and is the renderer we can render/screenshot in CI with Mesa llvmpipe, so what we test is what ships).

```
arpg/game/
  project.godot
  content/<pack>/pack.json + *.json     ← ALL game data (base game = content/base)
  scripts/core/     autoloads: Events, Content, Rng, Settings, Game, Sfx
  scripts/rpg/      pure rules engine (RefCounted, no scene tree): stats, items, loot, combat, progression, crafting
  scripts/actors/   Actor base, Player, Monster, Boss, AI, skill execution
  scripts/world/    zone generation, biomes, spawning, town, events
  scripts/fx/       juice: hitstop, shake, damage numbers, loot beams, VFX
  scripts/ui/       HUD, touch controls, screens (inventory, character, skills, starmap, crafting, map, menus)
  scenes/           minimal .tscn; most scene graphs are built in code (agent-friendly, diffable)
  assets/thirdparty/ CC0 packs (provenance in docs/legal/ASSET_SOURCES.md)
  assets/generated/ our generated audio/textures (tools/ scripts regenerate them)
  tests/            headless test runner (godot --headless -s tests/run_tests.gd)
  tools/            Python simulations (loot, xp, economy), asset generators
```

## Content packs (expansions / DLC)
- A pack = folder with `pack.json` (`id`, `name`, `version`, `load_order`, `requires`, `tables`).
- Tables: `config, stats, rarities, classes, skills, passives, item_bases, affixes, uniques, named, powers, materials, recipes, professions, monsters, monster_affixes, bosses, biomes, acts, zones, difficulties, events, starmap, quests, lore`.
- Records are keyed by `id`. Later packs add records or override by id; `"_merge": true` patches fields.
- DLC ships as `.pck` in `user://dlc/`, mounted before content loads. Adding an act = new pack with `acts/zones/monsters/biomes` records; adding a class = `classes/skills/passives` records + model path. **No engine code changes required** for new content that uses existing effect primitives.
- New mechanics = new effect primitive (`scripts/actors/skill_effects.gd`) or power hook, referenced by name from data.

## Rules engine vs. presentation (multiplayer-ready)
- `scripts/rpg/*` is deterministic, pure logic over Dictionaries. It never touches nodes. Tests run it headless.
- All randomness via `Rng.stream("<system>")` (loot, affix, crafting, world, combat). A future server owns the seeds.
- Gameplay state changes go through **authority functions** on `GameWorld` (`apply_damage`, `spawn_drop`, `grant_item`, `kill`). Today they run locally; for multiplayer they become server-side with the same signatures, and clients receive results.
- Every actor/drop has a `net_id` (monotonic int from GameWorld). Player input is expressed as **intents** (`move_dir`, `cast(skill, target_pos)`, `pickup(net_id)`), so the same controller can later be fed by network input.
- Saves are per character, versioned (`save_version`) with migration functions; hardcore characters flagged and isolated.
- **Not implemented now:** networking, lobby, server. Designed seams: intents, authority functions, net_ids, seeded streams, no singleton player assumption in rules code (functions take the character as a parameter).

## Performance budget (Pixel 8 Pro target 60 fps, mid-range floor 30 fps)
- ≤ 60 skinned actors on screen; fodder beyond that uses cheaper LOD/animation throttling.
- 1 directional light + ≤ 8 omni lights (torches) visible; fog; no real-time GI.
- Object pooling for projectiles, damage numbers, drops. Particles: CPUParticles3D (compat-safe).

## Testing
- `godot --headless -s res://tests/run_tests.gd` — unit tests for rules engine + content validation (every reference resolves, every id unique, rarity weights sane).
- `tools/sim_*.py` — Monte-Carlo loot, XP pacing, crafting economy.
- `tests/playtest_bot.gd` — autonomous bot plays zones on each difficulty, logs time-to-kill, deaths, drops per minute; screenshot capture under Xvfb for visual review.

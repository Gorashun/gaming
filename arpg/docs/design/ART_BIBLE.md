# Art Bible — v2
Owner: art-3d-designer. Look: chibi toys lost in a dark storybook. Cute meets eerie. Renderer: GL Compatibility (Godot 4.7).
Source art: KayKit CC0 (heroes, skeletons, dungeon, halloween). All 9 characters share **one 41-joint rig**, so every animation plays on every model and heroes can be recoloured as enemies.

## 1. Core rules
1. **Value hierarchy.** Environment is dark with low contrast and ≤ 60 % saturation. Actors are mid-to-light. Player VFX, loot and threats are the only fully saturated, brightest things on screen.
2. **Colour ownership.** A pure rarity hue (§3) belongs to loot and is never used at full saturation in the environment. Orange pumpkins get a muted palette row.
3. **Light = safety.** Warm light marks the player, hubs, checkpoints and shrines. The Hush is cold, grey and desaturated.
4. **No gore.** Defeated Snuffed pop: squash 0.08 s → spark burst → a small ember flies to the player (XP/gold). Skeletons never shatter into limbs.
5. **Silhouette test.** Every actor must read as a black silhouette at 70 px tall from the game camera.

## 2. Palettes per act (hex = fog / ambient / key light / accent)
| Act | Mood | Fog | Ambient | Key light | Accent (env only) |
|---|---|---|---|---|---|
| Hub (every act) | warm, safe | `#2A1E16` far | `#4A3A2C` | lanterns `#FFB54A` | candle `#FFD9A0` |
| 1 Wickmire | bog, graveyard, moonlit | `#22363A` | `#1C2A2E` | moon `#9FB8C8` 0.6 | wisp green `#8FD9A0` (desat) |
| 2 Whisperwood | dead forest, violet mist | `#3B3450` | `#241F30` | pale sky `#B8A8D8` 0.5 | fungus blue `#7FB8E0` |
| 3 Echo Mines | deep stone, echoing | `#1E1916` dense | `#2A221C` | none; miner lamps `#FFC070` | crystal `#CFE8F0` (white-blue) |
| 4 Rimehall | frozen court | `#AFC4D6` **bright** fog, dark silhouettes | `#5A6E80` | cold sun `#E0F0FF` 0.9 | frost `#9CC8E0` (desat) |
| 5 Well of Hush | colour drained | `#18181C` | `#202024` | none; only the player lantern | none. Env is greyscale; colour = player, loot, threats |
| Deepdark | remix of act palettes + ink | act fog × 0.7 | act | act | modifier tint on fog |

- Environment textures use the KayKit atlas plus **one palette row per act** (a hue/value remap LUT in the shared shader), not new textures.
- Act 5 turns the "colour = meaning" rule into story: the world is grey and every colour you see matters.

## 3. Rarity language (colour + frame shape + beam + sound; never colour alone)
| Rarity | Colour | Frame shape | On ground | Beam |
|---|---|---|---|---|
| Common | grey `#C8C8C8` | square | label only | none |
| Magic | blue `#4A90FF` | rounded square | soft glow disc | none |
| Rare | yellow `#FFD23F` | diamond | glow disc + sparkle | 1.5 m, thin |
| Epic | purple `#A64DFF` | hexagon | disc + rising motes | 3 m |
| Legendary | orange `#FF8C1A` | 5-point star | ground ring + minimap icon | 8 m, wide |
| Mythic | crimson `#FF3355`, white core | flame | ring + screen-edge glow | 12 m, pulsing, stinger |
| Unique | **green `#3DDC84`** (proposed; GDD says gold, which clashes with Rare and Legendary) | crown | ring + minimap icon | 8 m |
| Named | cyan-white `#35E0D0` | sun | sun rays spin on ground | 12 m, halo rings |
- Beams are unshaded, additive, **fog-disabled** cylinder meshes with a scrolling gradient. They are not particles and are always vertical and static. Threats are never vertical beams.
- Colour-blind modes swap hues only. Shape, beam height and sound stay fixed, so the ladder still reads with no colour at all.

## 4. Lighting rules (GL Compatibility)
- **1 DirectionalLight** per zone (moon or sun). Real shadows are cast only by the hero, elites, bosses and props taller than 2 m (`cast_shadow` off elsewhere). Shadow distance is 25 m with 2 splits max.
- **The Wick:** the player always carries a warm OmniLight (`#FFB54A`, range 6 m, energy 1.2). It is the signature light of the game.
- **Real omni lights:** the Wick plus **at most 3** others, picked each frame by distance from the torches. Compatibility renders each extra light as an extra pass per lit object, so a torch outside the budget is an emissive mesh plus a halo billboard plus a vertex-baked floor glow.
- Blob shadows for fodder are an unshaded dark quad (Decal nodes are not supported in Compatibility).
- Fog is depth fog plus height fog in the ground 0–1.5 m for bogs and mines. No volumetric fog, SSAO, SSR or SDFGI. A cheap vignette in the post shader is fine; bloom must be verified on device, otherwise use additive halo sprites.
- Hubs: 2–3 warm omni lights, fog pushed far, music warm. Boss arenas: the key light dims 30 % and a rim light is tinted to the boss colour.

## 5. Shading
- **Toon shader** (one shared `ShaderMaterial` for all characters): 3-step ramp (dark 0.35 / mid 0.7 / lit 1.0) + Fresnel rim `pow(1-NdotV, 3)` × 0.5 in the key-light colour, and a `palette_row` uniform for recolouring families. Hit flash is a `flash` uniform (white, 2 frames).
- **Outlines:** inverted hull through `next_pass` (cull front, vertex push 0.015–0.025 m by distance). Only on the hero, elites, bosses and loot on the ground. Fodder gets the rim only. Outline colour is the darkest tone of the act palette, never pure black.
- The environment gets no outline: flat ramp plus vertex AO.
- Budgets (measure on device): hero ≤ 3k tris *after merge/decimate*, fodder ≤ 1.5k (LOD1), boss ≤ 10k. KayKit sources are 4.6–7k tris split over 9–15 mesh parts, so **merge each character into one skinned mesh at import** and generate LOD1 at about 45 %.

## 6. VFX rules
| Source | Shape | Colour | Life |
|---|---|---|---|
| Player attacks | sharp arcs, stars, sparks | warm white / gold, skill element tint | 0.15–0.4 s |
| Enemy attacks | round blobs, dark core | **threat red `#FF2B2B` rim**, dark core | projectiles until hit |
| Telegraphs | ground mesh, hatched fill growing inward to outward | threat red, 40 % alpha, solid edge | 0.8 s min (Twilight 1.0 s), boss 1.0–1.6 s |
| Heal / pickups | soft pulse, rising | green-white | 0.5 s |
| Death pop | 8–12 sparks + 1 ember | family accent | 0.35 s |
- Threat red is reserved: never in the environment, never on loot. Mythic crimson stays apart from it through beam and flame shape and its white core.
- Mobile overdraw: ≤ 40 particles per effect and ≤ 400 on screen. Prefer mesh swooshes with a scrolling gradient over particle clouds. Use CPUParticles3D only.
- Elite marker: a pulsing ground ring in the affix colour, plus an icon above the head.

## 7. Readability & scale
- Scale on screen: fodder 0.9–1.0, heroes 1.0, elites 1.25 plus a ring, mini-boss 1.6, bosses 2.5–4.
- Every enemy has **emissive eyes** (family accent). They read in fog and at low brightness.
- Walls and props between the camera and the player: dither-fade (alpha-scissor noise) within 3 m of the camera→player ray. Never hide the player.
- Loot labels are drawn in screen space with rarity colour, frame icon and a 1 px dark outline. They collapse to icons when more than 8 are on screen.
- Damage numbers: white normal, yellow-orange crit (+30 % size), red when the player takes damage (not threat red: `#FF6B6B`).

## 8. Camera (mobile landscape)
- Perspective camera. Vertical FOV **38°** (keep height, so 20:9 phones get wider sight, not a crop). Pitch **−52°**, fixed yaw **45°** to the dungeon grid.
- Distance to the player is **22 m (zone), 19 m (hub) and 26 m (boss arena)** (v2: raised from 13/11/16 so phones see the room, hero ≈ 13 % of screen height), eased over 0.6 s. The player setting `camera_zoom` allows ±15 %.
- The player sits at **54 % of screen height** (a little below centre, so thumbs cover less of the view ahead). Camera follow uses critical damping at 0.12 s with 1.5 m of look-ahead in the move direction.
- Screen shake is applied as a camera offset only (trauma model, see UI_UX.md). It never rotates more than 1.5°.

## 9. Monster families from the kit (summary)
Families are built from recolour (palette row) + scale + prop sockets (`handslot.l/r`, `head`) + hidden mesh parts + procedural creatures (wisps, slimes, moths, bats, ghosts). Family accent = eye colour + death sparks. The roster lives in the design review / SYSTEMS.md.

## 10. UI icon style
- Flat shapes with a 2-tone gradient and a 2 px dark outline, on the frame shape of their rarity. Read at 48 px. One idea per icon, no text inside icons.


## 11. Biomes (v2, `content/base/biomes.json`, built by `scripts/world/zone_builder.gd`)
All kit meshes render through ONE shader, `shaders/env_kit.gdshader` (MultiMesh `material_override`), so the same KayKit dungeon/halloween/medieval-hexagon pieces read as different places. A biome `tint` block (`color, saturation, brightness, hue, top_color, top_amount, top_scale, emission`) plus optional `floor_tint / wall_tint / boundary_tint` and per-prop `tint` drive it; `top_*` paints snow/moss/ash on up-facing surfaces with world-space noise. All 203 dungeon texture copies are remapped to the single atlas (VRAM + fewer materials). Hexagon-pack models get an intrinsic ×4 scale.
| Biome id | Act | Look |
|---|---|---|
| town | Hub A1/A2 | warm lantern hub, tents, muted pumpkins, cats/crows, embers |
| town_mines / town_frost / town_hush | Hubs A3/A4/A5 | mine camp · snowy hearth · the last lit refuge in a grey world |
| graveyard | A1 | moonlit mossy slabs, graves, crypts, crows, green fireflies |
| bog | A1 | heavy mist + height fog, lily pads, reeds, frogs, wisps |
| crypt | A1 dungeon | cold stone, torches, coffins, bats, spiders |
| whisperwood | A2 | violet dead forest, moss floors, glowing blue fungus (proc), muted pumpkins, root arches, owls, lantern moths |
| rootcellar | A2 dungeon | moss-hued crypt, roots, fungus, spores |
| echo_mines / echo_caverns | A3 | dark rock, scaffold walls, mine carts + rails, emissive crystals (proc), bats, dust |
| rimehall / rime_court | A4 | icy blue-white kit, snow top layer, ice shards (proc), bright fog, snow particles |
| well_of_hush / hush_wastes | A5 | fully desaturated grey, obelisks, white motes; only the Wick and loot carry colour |
| deepdark | Endgame | ink-tinted kit, violet/cyan crystals; zone `fog_tint` modifies fog per Lightwell modifier |
Each biome also sets `music`, `ambience`, `ambient` particle layers (≤48 each), `critters` (CreatureFactory ambience), `backdrop` silhouettes beyond the bounds and `env` (fog colour/depth range, height fog, mist, glow, outline colour). Dev zones for every biome live in `content/dev_art/` (load_order 98, not in acts).

## 12. Occlusion & camera side
- Near (+X/+Z, camera-side) dungeon edges use the low `barrier` (1.1 m); outdoor near edges use only low props (graves, fences, mounds).
- Everything tall (far walls, pillars, trees, tents, obelisks) has `occlude`: env_kit dithers it away within ~2.4 m of the camera→hero ray, keeping the wall base so the room edge still reads. The hero position is a global shader uniform `wick_player_pos` set by CameraRig each frame.

## 13. Lighting v2
- Depth fog (begins just behind the hero plane) + optional height fog; mist plane thins out around the hero.
- The Wick: hero light `#FFB869`, 1.25 energy, 9 m, placed high behind; carried by a tiny flame spirit (CreatureFactory "wick"). 3 nearest torches are real lights (GameWorld), all torches have flickering additive halos. Stations have no real lights.
- Blob shadows under every actor; real shadows only hero/elite/boss/tall props. Outlines only hero/elite/boss/loot. Toon shader `toon_actor.gdshader` (3-step ramp + rim) replaces KayKit materials on all actors (Fx director).
- Boss: key light −30 %, rim light in boss soul colour.

## 14. VFX kit (`scripts/fx/fx.gd`, autoload Fx)
Element colours: physical `#FFF1D6`, fire `#FF7A2E`, cold `#8FE3FF`, lightning `#C3CCFF`, shadow `#9B6BFF`, holy `#FFE08A`, poison `#8CFF6B`, hush `#D0D0DC`.
Melee = 2-layer arc with hot edge + sparks · aoe/nova = ring + flash disc + vertical shockwave · projectiles = element heads (ember glow, ice shard, spinning star, dark-violet orb, arrow streak) + ribbon trails · enemy shots = dark core + threat-red rim + red smoke · chain lightning = thick jagged flickering ribbons · ground zones = swirling noise shader · buff = rotating sigil + rising sparks · heal = green-white rising sparks · dash/leap = double ribbon + dust · summon = smoke + spark ring · level-up = 12 m gold pillar + sun rays + shockwave · death "rekindle" = pop, soul rises and flies away with a trail, ember homes to the hero · telegraphs = hatched threat-red fill growing outward · loot per §3 (Legendary star ring, Mythic pulsing white-core beam + flame motes, Unique crown ring, Named sun rays + climbing halo rings) · `Fx.hush_tear(parent)` Hushfall rift · `Fx.event_cache_spawn(pos)`. Damage numbers merge hits on the same spot within 0.3 s, max 24 live. Particles: pooled CPUParticles3D, ≤40 per effect, max 3 transient lights.

## 15. CreatureFactory (`scripts/fx/creature_factory.gd`)
`CreatureFactory.build(kind: String, color: Color, scale := 1.0, opts := {}) -> Node3D` (a `CreatureAnim` node, faces +Z). opts: `eyes: "cute"|"glow"`, `eye_color`, `glow`, `outline`. Methods: `set_moving(bool)` (also auto-detected), `attack()`, `hurt()`, `set_wander(radius, fly)`, `get_saddle()` (mounts).
- Small (pets, critters, monster stand-ins): wisp, wick, bat, moth, lantern_moth, slime, ghost, crow, spider, frog, cat, owl, fox, snail, bunny.
- Mounts (saddle marker): wolf, boar, stag, giant_snail, lantern_beetle.
- Animation styles: float, fly (wing flaps), hop, walk (4-leg gait, tail sway, head look), skitter, slide, squash, perch. 300–1500 tris each, shared toon materials per colour. Showcase: dev zone `dev_menagerie`.

# Art Bible — v1
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
- Distance to the player is 13 m (zone), 11 m (hub) and 16 m (boss arena), eased over 0.6 s. The player setting "Zoom" allows ±15 %.
- The player sits at **54 % of screen height** (a little below centre, so thumbs cover less of the view ahead). Camera follow uses critical damping at 0.12 s with 1.5 m of look-ahead in the move direction.
- Screen shake is applied as a camera offset only (trauma model, see UI_UX.md). It never rotates more than 1.5°.

## 9. Monster families from the kit (summary)
Families are built from recolour (palette row) + scale + prop sockets (`handslot.l/r`, `head`) + hidden mesh parts + procedural creatures (wisps, slimes, moths, bats, ghosts). Family accent = eye colour + death sparks. The roster lives in the design review / SYSTEMS.md.

## 10. UI icon style
- Flat shapes with a 2-tone gradient and a 2 px dark outline, on the frame shape of their rarity. Read at 48 px. One idea per icon, no text inside icons.

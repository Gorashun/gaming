# UI / UX Spec — v1
Owner: ui-ux-designer. Audience: 7+ through veterans. Rule: **icon first, number second, word last**. Landscape only.

## 1. Reference canvas & scaling
- Reference resolution is **1280×720**, `stretch_mode = canvas_items`, `aspect = expand` (20:9 phones get extra width at the sides, and all HUD anchors hug the corners).
- **Touch-size maths.** On the worst case (a 360 dp-tall landscape phone), 1 ref px ≈ 0.5 dp. So 48 dp = 96 px, 56 dp = 112 px and 80 dp = 160 px (**hit area**; the art may be drawn smaller). Pixel 8 Pro (448 dp) gets extra margin.
- **Safe area:** read `DisplayServer.get_display_safe_area()` each resize and inset the HUD root by it, with a minimum of 24 px on every side (48 px on the side with a camera cutout). Nothing that can be tapped goes in the outer 24 px.
- UI scale setting 85–125 %. Text setting 100–200 %. Minimum body text is 22 px (≈ 11 sp at the worst case, 14 sp on Pixel 8 Pro), labels 26 px, numbers in combat 30 px.

## 2. HUD layout (1280×720 ref, inside the safe area)
```
┌───────────────────────────────────────────────────────────────┐
│[Portrait+Lv] HP ████████░░  (360×28)        [Boss bar 640×24]  [Minimap 190²][☰]│
│             Res ██████░░░░  (300×18)        zone/objective toast                │
│             XP  ▪▪▪▪ 4 sub-ticks (300×8)                         [Lantern meter]  │
│ pickup feed (≤4 lines, fades 2.5 s)                                               │
│                                                                                  │
│                        (player at 54 % height)                                   │
│                                                              [S3]  [S4]           │
│  ╭joystick zone╮                                          [S2]                    │
│  │ left 40 % of │                                   [Dodge]      (ATTACK 160)     │
│  ╰ lower 65 %  ╯                           [Potion]      [S1]                     │
└───────────────────────────────────────────────────────────────┘
```
- **Top-left:** portrait (96 px, level badge, tap opens the Character sheet), HP bar in red plus a heart icon, resource bar in the class colour plus a resource icon, XP bar with 4 sub-ticks.
- **Top-centre:** boss bar (name, phase pips, shield layer) and objective toast (icon + ≤ 5 words, 3 s).
- **Top-right:** minimap 190×190 (tap opens the full map), menu ☰ (96 px, badge dot when something new) and the **Lantern meter** under it. The meter is the visible pity: a small lantern that fills toward a guaranteed Legendary. Tap it to see "Legendary guaranteed within 12 min".
- **Bottom-right thumb arc:** Attack centre at (1160, 610), hit 160 px. S1–S4 on a 190 px radius arc from 180° to 90°, hit 112 px, with the icon, a cooldown sweep and a resource-cost tint. Dodge at (985, 540), hit 112 px. Potion at (880, 650), hit 112 px, with a charges counter.
- **Bottom-left:** floating joystick (see §3). Bottom-centre stays empty so the thumbs never cover the hero.
- Layout editor in Settings: drag any button, resize 80–130 %, reset. **Left-handed mirror** swaps the sides.

## 3. Controls
| Input | Behaviour |
|---|---|
| Joystick | Floating, anchored where the thumb lands inside the zone. Radius 90 px, dead zone 12 %, full speed at 70 %. A "Fixed" option places it at (190, 560). |
| Attack tap | Auto-target: the nearest enemy in a 70° cone of the move/facing direction within range, otherwise the nearest one. Target sticks for 1.2 s. |
| Attack hold | Keeps attacking (no tap spam). |
| Skill tap | Auto-aim (same rules; ground skills land on the target, or on the densest cluster for AoE). |
| Skill hold + drag | Manual aim: a ground reticle or cone preview. Release casts; drag back onto the button cancels. |
| Dodge | Dash 4 m in the joystick direction (facing if idle), 0.25 s i-frames, 2 charges. |
| Tap ground loot | Walk to it and pick up. Gold, materials and potions auto-pickup within 2.5 m. |
| Two-finger pinch | Camera zoom within ±15 % (can be disabled). |
- **Auto-attack mode** (Settings; on in Simple mode): while the stick is released, the hero attacks the nearest enemy in range. Skills stay manual.
- Controllers: Godot Input actions for everything, so a gamepad works from day one.
- **Simple mode** (preset offered at first launch as "Play it easy"): auto-attack, auto-pickup of upgrades, auto-equip of clear upgrades (with an undo toast), auto-spend of skill and star points along the recommended path, icon-only item cards. Every piece can be turned off one by one.

## 4. Screen list & flows (max 2 taps from the HUD to anything)
```
Title → Save slots → [New: Class pick (5 turntables) → Name → Softcore/Last Flame → Simple mode?] → Hub
Hub ⇄ Zone (portal/waypoint) ; Zone → Boss → Victory card → Session summary (optional) → Hub/Continue
HUD ☰ → Bag hub: [Gear] [Skills] [Stars] [Craft*] [Codex] [Map] [Settings]   (*craft in hub or after Act 2 anywhere)
Death (softcore) → "Rekindle" card (checkpoint / town) ; Death (Last Flame) → memorial → Hall of Embers
```
- The Bag hub opens on the last tab used. Tabs are icon + short word on a bottom tab rail (hit 96 px). **Back** is always top-left at the same spot, and the Android back gesture maps to it.
- The game pauses in every menu (single player). No timers in menus.
- The **session summary** (after a boss, or when the player taps Leave) shows the 3 best finds, levels and sub-ticks gained, pity progress and **one "Next goal" card** (e.g. "Egg hatches in 14 kills"). This gives a reason to return without notifications.

## 5. Inventory & compare
- Left: paperdoll with 12 slot tiles (96 px) around the 3D hero turntable. Right: 40-cell grid (8×5, 96 px cells), sort ▾ (rarity, slot, new) and filter chips per rarity (colour + shape).
- **On every item tile:** rarity frame shape, item icon, a green ▲ or red ▼ badge (power vs. equipped), a new-dot and a lock icon if locked.
- **Tap item → Detail card** (bottom sheet, 60 % height): item on the left, **equipped on the right**. Each stat line is `icon  value  (+12 ▲ green / −5 ▼ red)`, always sign + arrow + colour. Top line is a big "Power +84 ▲". Buttons: **Equip** (primary, 160×96), Salvage, Lock, Compare-ring-2 (rings/one-hand weapons).
- **Double-tap tile = equip.** Long-press = Lock/Salvage radial.
- **Best gear** button: one tap equips the highest-power item per slot and shows a diff toast with Undo (5 s).
- **Salvage-all** button: choose a rarity ceiling (defaults to Magic). Epic+ always needs **hold-to-confirm 0.8 s**. Locked items and items better than equipped are never auto-salvaged.
- **Loot filter** (one slider in Settings/Gear): Show all → Hide Common → Upgrades + Rare+ → Epic+. Hidden drops auto-salvage into materials, and a "+3 Iron" line appears in the pickup feed.
- Full bag: the pickup feed shows a bag icon + "Bag full: tap to salvage". Legendary+ always go to an overflow mailbox and are never lost.

## 6. Crafting
- Hub stations: Smith, Alchemist, Jeweler, Runecarver, Cauldron. Each one unlocks in the story, one at a time with a 30-second guided first craft.
- **Profession screen:** left is the item picker (grid filtered to valid items), centre the item card, right the operation list (Add affix, Upgrade, Reroll, Seal …). Each operation shows material icons with have/need counts. Missing materials are greyed with a "where to find" icon that opens the Codex.
- **Kindle preview:** a bar shows the item's Kindle points and the cost range as a bracket (e.g. "costs 3–6"), plus "Crit! 7 %". The outcome preview shows exact new value ranges, so there are no hidden odds.
- **Forge button:** 160×96, hold 0.4 s (0.8 s for Epic+). Result: hammer shake 0.3 s → flash → value counts up. A crit gets a gold burst and a double chime.
- **Cauldron:** 3 slots in a circle. Tap an item to drop it in the next free slot, then tap **Stir**. The journal page flips on a discovery. An unknown combo returns the items plus a "Nothing happened… yet" bubble and never destroys anything. Hint fragments show as silhouettes in the journal.
- **Named recipes:** a pinned tracker card lists requirements with ✓ checks and "where from" icons.

## 7. Skill tree & loadout
- 3 vertical branch columns, 4–5 rows each, nodes 112 px, ranks as pips under the node. Branch passives sit at row gates (5/15/25 points) with a lock icon and the point count.
- **Tap node → preview card:** looping 3-second in-engine preview clip, 3 numbers max (damage, cost, cooldown) with icons, a **+** button (hit 112) and a − button (respec). Modifier choices (if any) appear as two big icon cards; pick one.
- Loadout bar (bottom, 4 slots + basic): tap a slot, then tap a skill, or drag. Changes apply instantly in the hub; in the field they are free but cause a 2 s cooldown on all skills.
- "Recommended" toggle: the tree glows the next suggested node. Simple mode spends automatically.
- Respec: free until level 20, then cheap gold cost per point in the hub.

## 8. Starmap (level 61+)
- Full-screen pannable canvas: pinch zoom 0.6–2.0×, double-tap to recentre on the latest star. 3 rings of constellations. Locked stars are dim outlines; stars you can afford glow.
- **Tap constellation → side sheet:** list of stars (icon + number), completion bonus, **Fill** button (spends points along the path, previewing the cost first) and Clear.
- Stars show a count badge ("3/7"). Affinity bars sit at the top.
- Recommended path overlay (dotted gold) matches the equipped class/Pact. Respec in the hub is free (per research).

## 9. Accessibility (Settings, all on day one)
- Text size 100–200 %. UI scale. High-contrast HUD (solid backgrounds, thicker outlines).
- Colour-blind modes: protanopia, deuteranopia, tritanopia (hue swaps). **Rarity, threat and status are also shape + icon**, so every mode is safe.
- Screen shake 0–100 %. Hitstop on/off. Flash reduction (caps full-screen flashes to 20 % alpha and turns off the Mythic edge pulse). Reduced motion (no camera zoom punch or slow-mo).
- Hold ↔ toggle for held inputs. Auto-attack. Layout editor. Left-handed mirror. Haptics 0–100 %.
- Subtitles for every voiced/story line, **visual cue for every audio cue** (drop chime → beam and edge arrow; off-screen elite → edge indicator).
- Optional read-aloud (Android TTS) for item names and quest text, for early readers.
- No time pressure in menus, no FOMO timers and no nag popups (see PLAYER_WELFARE.md).

## 10. Juice spec (timings in ms unless noted)
| Event | Spec |
|---|---|
| Hit (normal) | target flash white 2 frames; hitstop **50** (attacker + target only); knockback 0.3 m over 80; squash 0.9/1.1 for 100 |
| Hit (heavy / crit) | hitstop **80**; shake trauma +0.25; crit number +30 % size, yellow-orange, 120 overshoot pop |
| Multi-hit / AoE | hitstop scales `min(80, 30 + 5·n)`, applied once; numbers merge into one rising total per target |
| Damage number | spawn scale 1.4 → 1.0 in 120 (ease-out-back), rise 40 px over 600, fade last 200; max 24 on screen |
| Player hurt | red vignette 150; controller rumble 40; shake +0.15; no hitstop on the player |
| Screen shake | trauma 0–1, offset = trauma² × 0.35 m, Perlin 18 Hz, decay 1.6/s; levels S 0.2 · M 0.45 · L 0.8 (boss) |
| Death pop | squash to 0.6 y in 80 → 12 sparks → ember flies to player 450 (ease-in), +XP tick |
| Level up | ring shockwave 400, 1 s golden column, "LEVEL 23" banner 1.5 s, heal full; no gameplay pause |
| Sub-tick fill | XP bar tick flashes 200 + soft chime |
| Loot spill | items arc 0.5–1.5 m, 350 flight + 2 bounces; gold/materials magnetise after 300 |
| Chest | anticipation shake 250 → lid pop → spill; elite chest adds glow 150 before the pop |
| Rare / Epic drop | chime (2 / 3 notes); beam rise 200 |
| Legendary drop | slow-mo 0.3× for 350 (reduced motion: off); music duck −8 dB for 1.2 s; beam shoots up 250; clang; minimap ping; edge arrow if off-screen |
| Mythic drop | Legendary + sub thump + white core flash 100 + pulsing crimson screen edge 2 s |
| Golden moment card | queued until **no enemy within 12 m for 1.5 s**. Card slides in 300: item rotates, name types on 400, 1 highlight stat, big **Equip** + "Later". Skippable from 500 |
| UI tap | scale 0.94 for 60 → 1.0 over 90; tick sound; haptic 10 |
| Button unavailable | shake 3 px × 3 in 180; low thud; show reason icon (no mana / cooldown) |

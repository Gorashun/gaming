# ART_DIRECTION.md: KLUNK look and feel

Owner: art director. Version 1.0, 2026-09-26 (phase 1: audit and direction). Parent docs: `STUDIO_PLAN.md` (definition of done, point 2), `DESIGN.md` §17–18, `UI.md` §15–16, `RETENTION.md` §10.
Evidence: audit shots in `docs/art/audit/` (390×844, DPR 2, test version 8, captured with `docs/art/audit/capture.mjs`). Concept frames in `docs/art/concepts/` (Canvas2D in Chromium, source `docs/art/concepts/src/`). Prototype renderers: `app/src/data/artEnv.ts`, `app/src/ui/envArt.ts` (pure, no Phaser, typechecked, not wired into any scene).

**The goal in one sentence:** a glowing glass jar of toys in a living, lit underwater world, where every reward lands with weight and every screen feels like the same place.

---

## 1. Audit summary (test version 8)

The objects and buddies are already at a premium level (Art v2 materials). Almost everything *around* them is not. The game reads as "nice toys in a debug frame".

**The five biggest problems, in order of damage**
1. **18 % of the phone is black.** At 390×844 the 360×640 canvas is letterboxed: 150 CSS px of pure black above and below on every screen (`01-start.png`, `03-game-early.png`). No premium mobile game shows its edges.
2. **There is no world.** The background is a flat navy gradient. The jar is a flat rectangle with two diagonal lines; it reads as a phone frame, not glass (`05-game-crowded.png`). Set backdrops are so faint (luminance cap 0.03) that sets differ mainly by jar edge colour (`20-set-*.png`).
3. **Two type systems.** Start and the settings sheet use Fredoka; the game HUD, score pops, game over, book, shop and reveal still use `system-ui` 800 (DejaVu in the WebView). The HUD score "0" and "2480" look like a debug overlay.
4. **Big moments do not look big.** The jackpot tint is a grey-brown alpha wash that makes the whole screen muddy instead of golden (`10-jackpot-tint.png`). Bomb and rainbow are still v1 flat art; the bomb detonation is a small pink puff (`08b-bomb-detonation.png`). Chain ≥3 is visually indistinguishable from a normal merge except for a small cyan "+15". Danger has no visible state change besides the line pulse (`11-danger-slowmo.png`). An upgrade has no celebration at all (`19-upgrade.png`).
5. **The round end is a pile of floating parts.** Game over is a scrim over the jar with a v1 outline replay ring, the HUD score still visible under the scrim (the score shows twice), a reveal strip crammed into the HUD band, and a shell icon popping at the top right (`12-gameover.png`, `13-reveal-done.png`).

**Layering bugs seen in the shots** (for QA and programmer):
- Shell opening: the dimmed "PLAY" label shows through the pearls and rombs ("PL◇◇AY", `18-shell-opening.png`).
- Game over: the HUD score, best and chain row remain visible under the scrim.
- HUD chain "?" row sits under the hanging piece and buddy (y 78) and is low contrast even when not dimmed.
- The next-piece frames (dashed boxes) look broken when Sybil's second preview is shown (`03-game-early.png`).

### 1.1 Scores against the premium bar

Scale 1–5. 5 = on par with Royal Match / Monument Valley / Alto's Odyssey / Crossy Road / Paper.io 2 menus. 3 = competent casual. "–" = not applicable. **Kids** = readable and understandable for a 7-year-old without reading.

| Screen / moment | Light & depth | Materials | Background | VFX | Motion | Type & hierarchy | UI consistency | Kids | Shot |
|---|---|---|---|---|---|---|---|---|---|
| Start (returning player) | 3 | 4 | 2 | 2 | 3 | 4 | 4 | 5 | `01-start` |
| Start (new player) | 3 | 4 | 2 | – | 3 | 4 | 4 | 5 | `01b-start-new-player` |
| Settings sheet | 3 | 3 | 2 | – | 3 | 4 | 4 | 5 | `02-settings-sheet` |
| Game early / mid | 2 | 3 (objects 5, jar 1) | 1 | – | 3 | 2 | 2 | 4 | `03`, `04` |
| Game crowded | 2 | 3 | 1 | – | 3 | 2 | 2 | 4 | `05-game-crowded` |
| Merge | 2 | – | 1 | 2 | 3 | 2 | – | 4 | `06-merge` |
| Chain ≥3 | 2 | – | 1 | 2 | 2 | 1 | – | 3 | `07-chain` |
| Bomb (held, detonation) | 2 | 1 | 1 | 1 | 2 | – | 2 | 4 | `08`, `08b` |
| Rainbow | 2 | 1 | 1 | 2 | 3 | – | 2 | 4 | `09`, `09b` |
| Jackpot | 1 | – | 1 | 2 | 3 | 1 | – | 4 | `10`, `10b` |
| Danger / slow-mo | 1 | – | 1 | 1 | 2 | – | – | 3 | `11-danger-slowmo` |
| Game over | 2 | 2 | 1 | – | 2 | 2 | 1 | 4 | `12-gameover` |
| Reveal (strip) | 2 | 2 | 1 | 2 | 3 | 2 | 2 | 3 | `13-reveal-done` |
| Book: sets | 2 | 3 | 2 | – | 3 | 3 | 3 | 4 | `14-book-sets` |
| Book: locked page | 2 | 2 | 2 | – | 3 | 3 | 3 | 3 | `15-book-locked` |
| Buddies + shop | 3 | 3 | 2 | – | 3 | 3 | 3 | 3 | `16-buddies-shop` |
| Shell opening | 3 | 4 | 2 | 2 | 3 | – | 2 | 5 | `17`, `18`, `18b` |
| Upgrade | 2 | 3 | 2 | 1 | 2 | 3 | 3 | 3 | `19-upgrade` |
| Sets in play (4 alt.) | 2 | 4 | 2 | – | – | 2 | 3 | 4 | `20-set-*` |

**Overall: 2.4 / 5.** Start v2 is the best screen (3.6). The game screen, where players spend 90 % of their time, is the weakest (2.1). Where the effort goes follows from that: the world, the jar, the HUD and the big moments first; menus second.

What works and must be kept: Art v2 objects and buddies (glossy moulded toys, faces with inset lips); the Start v2 button component and card language; the colour journey cold → warm → electric → gold; shape + colour + face redundancy; the flash guard and calm mode discipline.

---

## 2. Visual pillars

1. **The jar is a lit glass room.** The jar is the brightest, most tactile object on screen: real glass (tinted back panel, caustic light, fresnel edge, front reflections, a thick lip). Everything the player controls lives inside it or on its rim.
2. **A living world, not a backdrop.** Every set is a place with depth: sky gradient, a slow light source, a far silhouette layer and drifting motes. It moves slowly enough to feel alive (≤0.1 Hz breathing, ≤12 px/s drift) and never competes with the jar.
3. **Toys with weight.** Everything the player touches squashes, overshoots and settles. Nothing appears or disappears without an anticipation, a pop or a fade. Rewards travel: they fly from where they were earned to where they are kept.
4. **Rewards are light, not noise.** Bigger moments add *layers of light* (glow, shockwave, beams) and *time* (hit-stop, slow-mo), not more particles or brightness flashes. The channel count table in UI.md §6 stays the design; this document gives it a look.
5. **One family.** One font (Fredoka), one button component, one card material, one glow sprite, one easing vocabulary. A child should feel Start, the jar, the book and the summary are the same place.

---

## 3. Palette and lighting model

**Lighting (all screens):** key light upper left (the water surface), a cool rim light upper right (the sea's glow), and per set an optional uplight from below (Glöden magma, Godis). Shadows fall down and slightly right. Art v2 materials already follow this; the environment, glass, buttons and cards must too.

**Value structure (relative luminance, keeps contrast):**
| Layer | Luminance | Notes |
|---|---|---|
| Environment far / sky | 0.005–0.04 | never above 0.04 behind any HUD text |
| Environment light (rays, aurora, nebula) | +0.02–0.06 locally, ADD | sums to ≤ +0.10 over the jar interior |
| Jar interior | 0.01–0.05 | darker than its surroundings at the top, so objects pop |
| Objects | 0.24–0.85 | unchanged (UI.md §12.1 rule ≥0.24) |
| HUD chrome (pills, cards) | 0.02–0.05 | `#16223C`–`#1B2A48` family |
| HUD text | ≥0.8 | `hud` `#EAF2FF`; gold `#FFD75E` |

**Tokens.** The existing `THEME.palette` tokens stay (bg, accent, accent2, gold, danger, hud, hudDim, ink). New per-set environment tokens live in `data/artEnv.ts` (`ENV_SETS`): `sky[3]`, `far`, `farMotif`, `skyLight`, `light`, `lightAlpha`, `caustic`, `causticAlpha`, `mote`, `moteColor`, `moteVy`, `glassTint`, `floor[2]`.

| Set | Sky (top → mid → bottom) | Light | Far motif | Motes | Glass tint |
|---|---|---|---|---|---|
| Glimtarna | `#12305A` → `#0B1A38` → `#050A16` | rays `#7CD8FF` | kelp + dunes | marine snow ↓ 6 px/s | `#9CC8FF` |
| Planeterna | `#2A1C5C` → `#130E30` → `#07051A` | nebula `#B69CFF` + `#FF7FC8` | ringed planet, stars | still stars (twinkle via scale only) | `#C8BEFF` |
| Frostisarna | `#0E3A4E` → `#0A1E30` → `#040B14` | aurora `#7CFFD2` | ice shelf | flakes ↓ 8 px/s | `#CFEFFF` |
| Godisarna | `#4A1A52` → `#241030` → `#100614` | rays `#FF9CE0` | candy hills + lollipops | bokeh bubbles ↑ 10 px/s | `#FFD1F2` |
| Glöden | `#1A0C0A` → `#1E0E0B` → `#3A140C` (hot at bottom) | uplight `#FF8A4C` | rocks | embers ↑ 12 px/s | `#FFD8B8` |

Contrast check (computed, WCAG): `hud` on the proposed HUD pill over the brightest sky top: 14.3:1 (Glimtarna), 15.3–16.9:1 other sets; `hud` directly on the lit sky: ≥8.0:1; gold on gold chip: 5.3:1; `hudDim` on card: 5.6:1. All HUD text ≥4.5:1.

**Rules:** no saturated red anywhere (unchanged). `accent` only on tappable things (unchanged). Gold means reward/record, pink `accent2` means special/gift. Colour is never the only carrier of meaning.

---

## 4. Materials

| Material | Where | Recipe (baked once) |
|---|---|---|
| **Soft glossy plastic** (Art v2) | objects, buddies | UI.md §15.3, unchanged. Specials, pearls, rombs, shells and particles move to it (DESIGN §17 step 2) |
| **Glass** | jar, next-piece bubble, shop jars, book sockets, odds jar | three layers: back panel (tint 0.10 → 0.04 alpha, inner edge shadow 26 px @0.35, floor), caustics (ADD, only upper 80 %), front (fresnel 5 px @0.32, 2–3 vertical reflection bands ≤0.13 alpha, specular dot r 7 @0.55, dark outer edge 3 px `#060A14` + tinted inner edge, a lip 12 px). `envArt.renderJarBack/Front`, `GLASS` in `artEnv.ts` |
| **Enamel card** | cards, pills, sheets, summary plates | Start v2 `card` (UI.md §16.3): `#1B2A48` → `#131E36`, edge `#4A6194` 2 px, top highlight 0.07, drop shadow 10/4. Reward variants: gold edge `#FFD75E` + gold radial inner glow 0.22; gift variant pink `#FF9CE0` |
| **Candy button** | primary actions | Start v2 `primary`, unchanged |
| **Metal gold** | crowns, trophies, record chip, level badge | radial `#FFF1CF` → `#FFB43A`, ink edge `#6B4300`, white glint top-left |
| **Pearl** | pearl coin, shells | existing PEARL_COIN_ICON; move to Art v2 material (radial nacre, rim light, specular dot) |

A material is always lit from the top left. Never draw a flat rectangle that is not a material.

---

## 5. Motion principles

**Named easings** (map to Phaser names; add as `MOTION` in `data/artEnv.ts` or `THEME.anim` when wiring):
| Name | Phaser | Use |
|---|---|---|
| `pop` | `Back.easeOut`, overshoot 2.2 | things appearing: merge result, badges, icons, tokens popping |
| `snap` | `Back.easeOut`, overshoot 1.4 | cards and panels settling, buttons released |
| `settle` | `Cubic.easeOut` | fades in, slides in, rings expanding |
| `glide` | `Sine.easeInOut` | flights (tokens, flyers), idle loops, breathing |
| `sink` | `Cubic.easeIn` | exits, things flying *into* a container |
| `press` | `Quad.easeOut` | press down (80 ms) |
| `drop` | `Quad.easeIn` | anticipation before a release |
| `spring` | `Elastic.easeOut` (amp 1, period 0.45) | only for a counter landing punch on big rewards (≤1 per second) |

**Timing scale:** micro 80–120 ms (press, punch), small 160–240 ms (pop, fade), medium 280–420 ms (panel, flight), large 500–800 ms (ceremony beats). Nothing interactive waits longer than 240 ms to respond.

**Anticipation:** every pop of a *big* item starts with 60–90 ms of `drop` to 0.92 (squash 1.06 × 0.92), then `pop` to 1.12–1.30, then `snap` to 1.0. Small items skip anticipation.

**Overshoot budget:** scale overshoot ≤1.30 (merge punch already 1.00 + 0.35·i, capped), position overshoot ≤8 px, rotation ≤6°.

**Stagger:** lists 40 ms, icons in a row 60 ms, flyers 90–140 ms, summary rows (next row starts 100 ms before the previous main motion ends, RETENTION §10.2). Never more than 6 staggered items animate; the rest appear as a group.

**Exits are faster than entrances** (≈0.7×). **Loops** ≤1 Hz (most 0.36–0.83 Hz), scale/position only, never brightness.

**Calm mode:** overshoot capped at 1.10, no anticipation, loops at half amplitude, no camera motion, flights replaced by fades where RETENTION says so.

---

## 6. VFX rules

**Layer order (Phaser depth, low → high).** Today depths run −10…31 ad hoc; adopt this table when wiring:
| Depth | Layer | Blend |
|---|---|---|
| −100 | environment base (sky, far, vignette), one baked texture | normal |
| −90 | far parallax layer (optional separate texture) | normal |
| −80 | light: 4 ray sprites / aurora band / nebula | ADD |
| −70 | motes (pooled, ≤28) | ADD |
| −12 | jar back panel + floor | normal |
| −11 | caustics: 2 TileSprites, jar interior rect only | ADD |
| −10 | contact shadows: shared glow sprite tinted `#02040A`, 0.55, under each body (follows body) | normal |
| −5 | object glow: shared glow sprite tinted per level, 0.22 (replaces baked halo, UI.md §15.8 Q3) | ADD |
| 0 | objects | normal |
| 2 | merge FX under-layer: shock rings | ADD |
| 3 | particles, sparkles | ADD |
| 4 | jar front glass (as strips, see §12 P3) | normal + ADD bands |
| 5–5.6 | HUD chain, glitter, lamps (existing) | – |
| 6–6.5 | hanging piece, buddy (existing) | – |
| 8 | score pops, tokens | normal |
| 10 | HUD | normal |
| 20 | toasts | normal |
| 30 | overlays (summary, sheets) | normal |
| 40 | scene transition layer | normal |

**Shared sprites** (all white, tinted, baked once at boot, `FX_SPRITES` in `artEnv.ts`, renderers in `envArt.ts`):
- `fx-glow` 128 px radial with 5 stops (no banding). **The only glow in the game**: object glow, contact shadow (tinted dark), token glow, light washes, badge halos, button focus.
- `fx-shock` 256 px ring, soft inside, crisp outside.
- `fx-sparkle` 64 px four-point star with soft core.
- `fx-streak` 8×64 capsule for trails and speed lines.
- `fx-beam` 64×256 soft wedge for jackpot fans, rarity rays, environment rays.
Existing particle shapes per set (`fx-p-star`, `shard`, `bubble`, `ring`, `dot`) stay.

**Layering recipe for any reward burst** (the "light sandwich"): (1) a glow wash under the event, (2) a shockwave ring, (3) the object pop, (4) sparkles and particles, (5) a score pop. Small events use 1+3+4 lite; big events use all five plus time (hit-stop, slow-mo).

**Max counts:** particles ≤40 per burst (unchanged), ≤90 alive; sparkles ≤12 per event; shock rings ≤2 per event, ≤4 alive; beams 12 only at jackpot/new set/legendary+; trails ≤3 ghosts, only for specials in flight and sand tokens (pearl tokens have no trail, RETENTION §10.1).

**Brightness and the flash guard:** no full-screen overlay brighter than +10 % luminance; ADD washes are local (radius ≤260 px), one per event, ≥1 s apart; no white fills; white cores ≤0.9 alpha and ≤120 ms. Brightness changes ≤3 per second everywhere (DESIGN §6), ≤2 Hz for ability FX (TECH). Everything that loops is scale/rotation/position.

---

## 7. Background and environment

Each set is an **animated scene behind the jar** in five layers (see §6 depths −100…−70 and concept `c1`):
1. **Sky**: 3-stop vertical gradient (`ENV_SETS[set].sky`), plus the set's static light (surface glow, nebula clouds, aurora bands, magma uplight) and vignette 0.55 at the edges. Baked once per set: `renderEnvBase(ctx, set, w, h, dpr)`, ~4 ms at DPR 2 on desktop.
2. **Far layer**: silhouettes in two tones (kelp and dunes; planet and stars; ice shelf; candy hills; rocks) baked into the same texture. Parallax 0.35 against camera shake/zoom (only when the camera moves; no idle motion).
3. **Light**: Glimtarna/Godis: 4 `fx-beam` sprites tinted `light`, alpha `lightAlpha` 0.07–0.075, angle 0.22 rad, sway ±14 px at 0.05 Hz, alpha breathing ±25 % at 0.07 Hz. Frost: aurora band sprite that drifts 6 px/s horizontally. Planets: nebula static; 6 stars twinkle by scale 0.8↔1.0 at 0.3 Hz. Glöden: uplight breathing only.
4. **Caustics**: `renderCausticTile` (256 logical px, tileable, domain-warped Voronoi, ~40–50 ms at DPR 2) as two TileSprites inside the jar, scales 1.0 and 1.37, scrolling 7 and −5 px/s, ADD at `causticAlpha` 0.035–0.06, faded out over the upper 80 % of the jar (bake the fade into a second 1×256 alpha mask texture or use two vertically stacked sprites with alpha; no GPU masks).
5. **Motes**: pool of 28 `fx-glow` sprites (bokeh: 8 larger) drifting at `moteVy`, wobble ±6 px at 0.25 Hz, alpha 0.18–0.5, wrap in y.

**Calm mode:** rays still (no sway), caustics scroll at 30 % speed, motes still and halved. **Book and summary:** environment still (no rays sway, no caustics).
**Where the environment lives:** see §12 P1. The world must fill the whole phone (no letterbox) and must *persist across scenes* so Start → Game → Summary → Book never cut to black.

---

## 8. Scene transition language

**Principle: one continuous place.** The environment never cuts. Only the foreground changes, and it always moves along the vertical "tide" axis: going *into* play = things rise from below; going *back out* = things sink.

| From → to | Choreography (logical px) | Total |
|---|---|---|
| Boot → Start | splash icon position = Start logo "U" position. Env fades in under the splash colour (200 ms `settle`); logo scales 1.06 → 1.0 (`snap` 260 ms); cards rise 24 px + fade, stagger 60 ms, `snap` 280 ms | ≤700 ms |
| Start → Game | PLAY presses (existing). Logo, pills, cards sink 40 px + fade (`sink` 180 ms, stagger 30 ms). The stage glow expands into the jar glow. The jar rises from y +120 to 0 (`snap` 360 ms) with its lip catching a glint (one `fx-sparkle` sweep 240 ms). First piece drops in from above (existing `queueSlide`) | ≤520 ms to input |
| Game → Summary | loss slow-mo (existing). HUD fades out 160 ms (fixes the double score). Env dims to 0.45 black over 240 ms (`settle`). Jar sinks 24 px and desaturates 30 % (overlay of `bg` at 0.3, not a filter). R0 result drops in (`snap` 280 ms) | ≤400 ms, replay tap live from t = 0 |
| Summary → Game (Replay) | summary plates sink + fade 160 ms; jar clears with a single soft shock ring from the floor (0.3 alpha); new round starts <500 ms (DESIGN §1) | <500 ms |
| Summary/Start → Book | book rises as a sheet from the bottom (y +640 → 0, `snap` 320 ms), env stays visible behind (dim 0.35) | 320 ms |
| Book → Start | sheet sinks (`sink` 220 ms) | 220 ms |
| Tabs / pages | crossfade 160 ms (tabs, existing); page swipe 1:1, far layer parallax 0.35 during the swipe | – |
| Sheets (settings) | existing: y 640 → 300, 260 ms `settle` in, 200 ms `sink` out | – |
| Shell opening | Start UI fades to 0 in 160 ms (not a 0.86 scrim over it: removes the ghost "PLAY"), env dims to 0.5 | – |

No white or black flashes; the dim layer never changes by more than 0.5 alpha in 200 ms.

---

## 9. Typography scale

**One font: Fredoka** (bundled, OFL). Weights 700 display/buttons, 600 labels and numbers, 500 body and captions. **Action for all scenes: `THEME.type.family` must become the Fredoka stack (`START_FONT.family`)**; today Game HUD, score pops (`systems/juice.ts`), GameOver, Book, shop and counters render in system-ui.

| Role | Size (logical px) / weight | Colour | Notes |
|---|---|---|---|
| Display (summary score) | 54–58 / 700 | `hud` | hard shadow (0, 3) `#060A14` |
| Logo | 60 / 700, spacing 6 | `hud` | existing |
| HUD score | 28–30 / 700 | `hud` | in a pill, tabular steps 0.6 em |
| Title | 22–24 / 700 | `hud` | sheets, summary headings |
| Button | primary 24–32 / 700 caps, spacing 2–3; card 17 / 600 | ink on primary, `hud` on card | existing |
| Label | 15–17 / 600 | `hud` | rows, chips |
| Body | 15 / 500 | `hud` / `hudDim` | ability text |
| Caption | 14 / 500 (minimum anywhere) | `hudDim` | sub-labels |
| Score pop | 18 (merge) / 24 (chain) / 40 (jackpot) / 700 | `accent` / `accent` / gold | **ink outline 0.22 em** so it reads over any object; rises 18 px, `settle` |
| Numbers in counters | 15–20 / 700 | `hud` | thin space thousands separator (`1 284`) |

Numbers always use fixed 0.6 em steps (UI.md §2.2). No text below 14 px (the shop's 13 px captions today must go to 14).

---

## 10. Iconography rules

- **Two families, never mixed in one role:**
  - **Action icons** (nav, settings, close, play, replay, book, tabs): outline, viewBox 64, stroke 6, round caps; `accent` when tappable, `hudDim` when not.
  - **Thing icons** (pearl, sand, shell, trophy, gift, crown, mission, set icons): filled, two-tone, ink outline 4–5, a white glint dot upper left at 0.8. They are *objects* and follow the lighting model.
- Sizes: 14 / 20 / 24 / 28 / 40 / 48 px. Icons sit in a 72 px target (64 on Start v2 per UI.md §16.10).
- Every reward icon has one silhouette that differs from its neighbours at 20 px (pearl = circle + glint, sand = star pile, shell = fan, trophy = cup, gift = box with bow, mission = clipboard + tick).
- New icons needed for RETENTION: **trophy, mission (clipboard), gift (closed/open), Journey level badge, mastery star, Aquarium**. Draw them in the "thing" family; the concept harness has reference trophy and mission SVGs (`docs/art/concepts/src/concepts.ts`, `TROPHY`, `MISSION`).
- Currency icons are **thing** icons in both HUD and summary; the pearl coin moves to Art v2 material (flat white disc reads as "empty circle" at 14 px today, see `c5`).

---

## 11. HUD direction

(Concept `c1`.) With the full-bleed screen (P1) the HUD moves to a **top band above the jar lip** and stops overlapping play:
- **Score pill** (x 12–132, y 8–52): enamel pill `rgba(11,16,32,0.72)` + `#4A6194` edge, Fredoka 28/700, tabular.
- **Best chip** (next to it, 76×32): gold 0.10 fill, gold 0.45 edge, crown 20 px + number 16/700 gold. Record chase: the chip pulses 1.00↔1.06 at 0.71 Hz (existing `recordPulse`); on passing: chip flips to solid gold edge + `pop`.
- **Next bubble** (right, r 24): a glass sphere (radial `#AFC8FF` 0.28 → bg 0.75, edge `#6E8CC4` 2 px) with the next piece inside; Sybil's second preview as a smaller piece outside it (no dashed frames). Special in queue: the bubble edge becomes `accent2` and rotates a dashed ring (existing signal, restyled).
- **Chain tray** (x 16–222, y 56–78): recessed glass tray (`rgba(4,8,18,0.55)`, 1.5 px `#6E8CC4` 0.35). Lit pieces sit in it; unknown slots are dark sockets (not "?" glyphs: the "?" moves to a single goal socket that breathes at 0.5 Hz).
- **Round pouch** (RETENTION §10.1): with the P1 layout it sits right of the chain tray (x 232–344, y 56–78) as two small pills (pearl, sand). Before P1 lands use RETENTION's positions (x 178–260, y 20).
- **Danger line**: rounded dashes 6/8 px, 2.5 px, `danger` 0.55, with a soft ADD band ±6 px at 0.10 (0.25 in danger). Remove the tick "teeth".
- **Aim guide**: dotted column of light (1.6 px dots every 14 px, `accent` 0.28 fading down) instead of a solid line.
Until P1 ships, the same restyle applies inside today's 360×640 layout at the current positions.

---

## 12. Prioritised polish backlog

Impact 1–5 × effort S (≤1 day) / M (2–4 days) / L (≥5 days). **fps cost** = estimated GPU/CPU cost per frame on a mid Android WebView at Z = 2 (720×1280 ≈ 0.92 MP; 1 "screen" of overdraw ≈ 0.4–0.7 ms on Adreno 6xx-class GPUs; estimates, to be measured in phase 4 with the fps guard and `?bench`).

| # | Item | Impact | Effort | fps cost | Files |
|---|---|---|---|---|---|
| **P1** | Full-bleed world (no letterbox) + persistent environment | 5 | M | +0.3–0.6 ms | `index.html`, `main.ts`, `ui/background.ts`, new `ui/envLayer.ts` |
| **P2** | Animated environment per set | 5 | M | +0.5–0.9 ms | `data/artEnv.ts`, `ui/envArt.ts`, env layer |
| **P3** | Jar glass material + caustics | 5 | M | +0.4–0.8 ms | `scenes/Game.ts` (`buildCan`), `ui/envArt.ts`, `ui/textures.ts` |
| **P4** | HUD polish + Fredoka everywhere | 5 | S–M | ≈0 | `data/theme.ts` (`type.family`), `scenes/Game.ts`, `systems/juice.ts`, `ui/counters.ts` |
| **P5** | Shared glow + VFX kit; merge/chain VFX upgrade | 4 | M | +0.2 ms avg, +0.6 ms peak | `ui/textures.ts`, `systems/juice.ts`, `data/juice.ts` |
| **P6** | Jackpot choreography | 4 | M | +0.8 ms for 1.2 s | `systems/juice.ts`, `scenes/Game.ts`, `data/juice.ts` |
| **P7** | Round summary + game-over card (RETENTION §10.2) | 5 | L | ≈0 (static after 3.5 s) | `scenes/GameOver.ts`, new `ui/summary.ts`, `data/summary.ts` |
| **P8** | In-round pickup tokens, pouch, toasts (RETENTION §10.1) | 4 | M | +0.1 ms | new `ui/pickup.ts`, `data/pickup.ts`, `scenes/Game.ts` |
| **P9** | Scene transitions (§8) | 4 | M | ≈0 | all scenes, env layer |
| **P10** | Specials v2 (bomb, rainbow) + detonation | 3 | M | +0.3 ms peak | `ui/artv2.ts` (`bands`), `ui/textures.ts`, `systems/juice.ts` |
| **P11** | Danger state | 3 | S | +0.1 ms | `scenes/Game.ts`, `data/juice.ts` |
| **P12** | Book and shop polish | 3 | M | ≈0 | `scenes/Book.ts`, `ui/friendsShop.ts` |
| **P13** | Shell opening polish | 3 | S–M | +0.3 ms for 1.2 s | `ui/shellOpening.ts` |
| **P14** | Upgrade celebration | 3 | S | +0.2 ms for 0.8 s | `scenes/Book.ts`, `ui/friendsShop.ts` |
| **P15** | Launcher icon + splash | 3 | S | 0 | `assets-src/*.svg`, `scripts/gen-icons.mjs`, `res/values` |
| **P16** | Loading / first frame | 3 | S | 0 | `scenes/Boot.ts`, `index.html` |

Sequencing (avoids file conflicts): P4 + P16 + P15 first (small, independent). Then P1 → P2 → P3 as one batch (env layer). P5 → P6 → P10 → P11 (juice batch). P7 + P8 with the retention build (same files as RETENTION §10). P9, P12–P14 last.

### P1 Full-bleed world
- **Problem:** 150 CSS px black bars top and bottom at 390×844 (all shots).
- **Spec (recommended, option A):** render the environment into a DOM `<canvas id="env">` *behind* the Phaser canvas (`position: fixed; inset: 0`), full window size × min(DPR, 2). Phaser gets `transparent: true`, and each scene stops painting its own full-screen background (Start, Game, Book, GameOver keep only their foreground). Moving env layers (4 beams, motes) are small canvases/`div`s animated with CSS `transform` + `opacity` (compositor thread, no main-thread cost). Calm mode = `animation-play-state: paused`. Set changes crossfade the env canvas (240 ms). Books pages get the per-page env as today.
- **Option B:** `Scale.EXPAND` on height (UI.md §16.11 Q1): logical height 640–800, play space centred with `OY = (H − 640)/2`. Gives the HUD a real top band (§11). Needs every scene's layout to read `OY`; do it after option A.
- **Colours:** body/`theme-color` = the set's `sky[1]` (Glimtarna `#0B1A38`), never `#000`.
- **Acceptance:** no pixel of pure black on 390×844, 360×800, 412×915 at DPR 2 and 3; screenshots in e2e updated.

### P2 Animated environment per set
- **Spec:** §7 layers, values in `ENV_SETS` / `ENV`. Bake `renderEnvBase` once per active set at boot and at set change (≈4 ms desktop, ≈20 ms low-end). Beams from one `fx-beam` texture (4 instances). Motes: 28 pooled sprites (12 when the fps guard has tripped). Breathing 0.07 Hz, sway 0.05 Hz.
- **Memory:** env texture 780×1688 RGBA ≈ 5.3 MB at DPR 2 (one set at a time; 1× = 1.3 MB when the guard trips). Beam 64×256 ×Z, motes share `fx-glow`.
- **Per-set checks:** local background luminance behind HUD ≤0.04 (all five pass in the prototype); jar interior ADD sum ≤ +0.10.

### P3 Jar glass material and caustics
- **Spec:** replace `buildCan` Graphics with three baked textures from `envArt`:
  - `jar-back-{set}@Z` (depth −12): `renderJarBack(ctx, set, inner, Z)`, inner = (20, 24, 320, 576).
  - caustics (depth −11): `renderCausticTile` → `fx-caustic@Z` 256² ×Z, two `TileSprite`s sized to the jar interior top 460 px, `tilePositionX += 7/−5 px/s · dt`, alpha `causticAlpha × (1, 0.7)`, plus a baked vertical fade (1×256 alpha texture multiplied via a third `Image` set to `ERASE` is expensive; instead bake the caustic tile *with* no fade and draw two stacked sprite rows with alpha 1.0 and 0.45 so it fades in steps under the objects).
  - `jar-front-{set}@Z` (depth 4): **bake as strips, not one full quad**: left wall strip 44 px, right wall strip 36 px, lip 360×16, spec dot 32×32. Full-jar transparent quads cost fill for nothing.
- **Level 8/9/10 decorations** that cross the wall now pass *under* the front glass: good, it reads as depth.
- **Acceptance:** faces keep contrast (front glass alpha ≤0.13 over any object; bands only on the outer 15 % each side); v1 mode keeps the old flat jar.

### P4 HUD polish and one font
- `THEME.type.family` → `"Fredoka, system-ui, …"` (same stack as `START_FONT.family`). Check Boot has loaded the font before `Game` creates Text (it does for Start).
- HUD layout as §11 (inside 360×640 until P1 option B).
- Score pops: 18/24/40 px by event, Fredoka 700, ink outline 0.22 em (`stroke: '#14202E', strokeThickness: 4` at Z), rise 18 px `settle` 500 ms (existing path).
- Remove the dashed next-piece frames; add the next bubble.
- **Acceptance:** contrast ≥4.5:1 for every HUD text on every set; HUD never overlaps the hanging piece at y ≥ 40.

### P5 Shared glow and merge/chain VFX
- Bake `fx-glow`, `fx-shock`, `fx-sparkle`, `fx-streak`, `fx-beam` at boot (all together ≈3–9 ms desktop).
- Object glow moves out of level textures to `fx-glow` tinted per level at 0.22, scale r·3 (UI.md §15.8 Q3; −35 % level texture memory, ≈ −4 MB per set at Z = 2).
- **Merge** (i 0.25–0.45): glow wash r·2.4 alpha 0.30→0 in 260 ms `settle`; one `fx-shock` r → 2.2r, alpha 0.6→0, 280 ms `settle`, tinted level colour; 8–12 particles (unchanged); 3 sparkles (12–16 px, gold/white, 0→1→0 in 240 ms, rot 0→45°); score pop 18 px.
- **Combo 2–4:** as merge + second shock ring 80 ms later at 0.4 alpha; sparkles 5; pop 20 px.
- **Chain ≥3** (i 0.8): as combo + 6 `fx-streak` speed lines radiating from the merge point (length 28→64 px, alpha 0.5→0, 220 ms), score pop 24 px with ink outline and `pop` 1.3; camera zoom 1.06 (existing, now visible because the world has depth). Chain count badge "×3" next to the pop (Fredoka 700 20, gold) for 600 ms.
- Counts stay within §6.

### P6 Jackpot choreography
(Concept `c2`.) Replaces the grey `tintAlpha 0.22` overlay (`data/juice.ts` `jackpot.tint*`).
| t (ms) | Event |
|---|---|
| 0 | hit-stop 6 frames (existing). The two level 9s pull together 6 px (anticipation) |
| 100 | new level 10 `pop` 0 → 1.12 → 1.0 (anticipation 80 ms at 0.92). Slow-mo 0.6× for 600 ms (existing) |
| 100 | focus vignette: radial dark 0 → 0.35 at the edges (260 ms `settle`) |
| 100 | warm ADD wash: `fx-glow` tinted `#FFB84A`, 480 px, alpha 0 → 0.20 → 0 over 700 ms (one brightness change) |
| 120 | beam fan: 12 `fx-beam` tinted `#FFE08A`, radius 40–320 px, alpha 0.30/0.50 alternating, rotating 20°/s, fade out at 1 200–1 600 ms. Clipped to the jar by construction (radius ≤ distance to walls; else skip beams that exit) |
| 140, 260 | two `fx-shock` rings: gold 0.75 (r 60 → 165) and pale gold 0.35 (r 40 → 125), 520 ms `settle` |
| 160 | 12 sparkles (gold + white, 12–34 px) + 26 ember dots on a ring r 120–210, drifting out 30 px, 800 ms |
| 200 | score pop "+566" 40 px gold `#FFE9A8`, ink outline `#6B4300`, `pop` 1.3, holds 700 ms, flies to the score pill (`sink` 380 ms), pill punches 1.15 (`spring`) |
| 1 600 | all gone; the crown glints once (existing) |
- Calm: no beams, one ring, wash 0.10, no vignette.
- **Flash check:** one warm wash per event (1 brightness change), everything else is local and rotating/expanding.

### P7 Round summary and game-over card
(Concepts `c3` style, `c5` layout.) Content, order, timing and budgets are RETENTION §10.2 (designer). Art direction owns the look:
- **Background:** the world stays (dimmed 0.45); the jar sinks 24 px and is desaturated with a `bg` overlay 0.3. HUD fades out first (160 ms).
- **R0 result** (y 24–150): best piece of the round on a small glow (`fx-glow` 110 px, level colour 0.4); "SCORE" caption 13/600 `hudDim` spacing 3; score 54/700; record chip (pill 184×34, gold 0.16 fill, gold edge 2 px); "New record!" adds 3 static sparkles + one `fx-glow` gold 0.3 behind the chip (no loop). R0 drops in with `snap` 280 ms.
- **Rows R1–R6** (y 160 + i·44, h 40, x 16–344): **glass plates** = enamel card radius 14. Variants: default (`#4A6194` edge), gift (pink edge + pink inner glow: R3), hero (gold edge + gold inner glow: R4 level-up, R6 trophy), mission (accent edge: R5). Icon 20–28 px at x 40, value/label from x 60, secondary info right-aligned to x 332.
- **Row entry:** plate slides up 12 px + fades in (`snap` 220 ms), contents stagger 60 ms. Numbers count up (≤12 ticks, ≥45 ms apart). Currency from later rows flies into R1 along a quadratic arc (control point 80 px above the midpoint, `glide` 420 ms, ≤3 in flight), R1 icon punches 1.15 on each arrival.
- **Flyers (R2):** existing flyers keep their path logic but land into the plate's book icon (punch 1.18), shiny flyers keep their glitter ring.
- **Level-up (R4):** badge anticipation 80 ms → `pop` 1.25 → `snap`; one gold `fx-shock` from the badge; reward icon rises from the badge 16 px and flies to R1 (currency) or stays with a "new" tag (item). Feature unlocks: icon 28 px + label, `pop`.
- **Mission (R5):** gift icon: lid pops 6 px up with 20° tilt (`pop` 200 ms), reward flies to R1.
- **Trophy (R6):** trophy `pop` with a gold `fx-glow` 0.35; hidden ones get the gold plate edge. Mastery stars fill left to right, 60 ms stagger, each `pop` 1.3.
- **Buttons** (y 552–616): Home = `card` 96×64 with close icon + "Home"; Replay = `primary` 216×64 "AGAIN" + replay glyph (existing pulse 3 cycles). Stop moment (R7, y 474–526): buddy wave + one line 15/500, plates stay. Both buttons 164×64 then.
- **Hidden rows are not drawn**; the remaining rows close up from the top. The empty zone below reads as calm, not as missing content.
- **Remove** the reveal strip in the HUD band and the v1 outline replay ring.

### P8 In-round pickup feedback
(Concept `c4`.) Cadence and rules are RETENTION §10.1. Look:
- **Pearl token:** the pearl coin icon at 10 → 8 px, with an `fx-glow` white 0.35 at 3.5× its size. Pops at the burst's last merge point (`pop` 0 → 1.15 → 1.0, 120 ms), then flies a quadratic arc (control point = merge point + (120, −300), mirrored when the pouch is to the left) in 420 ms `glide`, shrinking to 8 px. No trail, no sound.
- **Sand token:** sand icon 12 px, glow gold 0.35, 3 ghost trail (`fx-glow` 16 px at 0.40/0.24/0.14, lagging 3/6/9 % of the path), 520 ms.
- **Pouch** (compact counter): pills 24 px high, `rgba(11,16,32,0.72)` fill, `#4A6194` 2 px edge; icon 18 px + "+N" 15/700 `hud`. On arrival: pill scale 1.15 (pearl) / 1.25 (sand), `press`-up 60 ms + `snap` 120 ms; edge flashes to `hud` for 120 ms (edge colour only, no fill brightness); one `fx-glow` 90×50 behind at 0.3 → 0. The number rolls (old digit slides up 8 px and fades, new slides in, 120 ms).
- **Toast chip:** enamel card 232×32 (radius 16), below the jar floor at (180, 620) (RETENTION §10.1; full-bleed: centre of the bottom band). Edge by type: mission `accent`, trophy gold, level-up gold, mastery gold. Inner glow in the edge colour 0.22 on the icon side. Icon 20–22 px at the left, text 14/600 `hud` centred, reward thing-icon (gift) at the right. In: rise 12 px + fade 180 ms `settle`; hold 1 600 ms; out: fade 240 ms `sink`. Calm: fade only.
- **Pool:** 6 token sprites + their 6 glow sprites + 1 toast container. No particles.

### P9 Scene transitions
§8 table. Implementation note: with P1 option A the env is outside Phaser and never cuts; each scene only needs an `enter()`/`exit()` tween on its root container (depth 40 transition layer not needed). Budget: no scene change blocks input for more than 240 ms, except Start → Game (520 ms, hidden behind the jar rising).

### P10 Specials v2
- **Bomb:** Art v2 material: dark glossy body `#2A3350` with rim light `accent2`, 12 spikes as tapered dark-glass cones with pink tips, glowing core `#FFF1CF` as `fx-glow` 0.6 (not baked). The v1 look reads as a gear/virus at 50 px.
- **Rainbow:** `bands` in `artv2.ts`: 6 sectors with the material gradient per sector, a clear glass dome over them (spec dot, fresnel), rotating 150°/s (existing).
- **Detonation:** 60 ms anticipation (bomb scale 0.9), then `fx-shock` pink r 25 → 140 (320 ms) + second white-pink ring 0.4, 14 `fx-streak` radiating, 40 particles in pieces' colours, glow wash `accent2` 300 px 0.25 → 0, shake 8 px (existing). Everything cleared pops out with `sink` to 0 in 120 ms, stagger 20 ms from the centre outwards.
- **Rainbow merge:** a `fx-shock` in the target level's colour + 6 sparkles in the six band colours.

### P11 Danger state
- On danger enter: amber edge vignette (baked 360×640 radial, transparent centre, `danger` at the edges) 0 → 0.30 in 260 ms `settle`; danger line ADD band 0.10 → 0.25 pulsing at 1 Hz (existing `dangerPulse` drives it); environment motes and rays at 0.6× speed (follows `timeScale`); world desaturation 15 % via a `bg` overlay 0.15 on the env layer (not on the jar). Exit reverses in 420 ms (`slowmoOut`).
- Calm mode: vignette 0.15, no pulse on the band.

### P12 Book and shop
- Book page: environment of that set (still) behind a glass sheet (enamel, radius 28, inset 12 px) so rows sit on a surface, not on the sky.
- **Sockets instead of ghost silhouettes:** each slot is a recessed glass socket (dark inset circle r+6, inner shadow top, rim light bottom-right). Caught items sit in the socket with a contact shadow; uncaught show the silhouette at 0.25 *inside* the socket. Shiny slots have a thin gold socket ring.
- Locked page: frosted glass panel (enamel 0.9) with a lock thing-icon 56 px and the Glimt silhouette; not an empty grid of circles.
- Page turn: far layer parallax 0.35; new catch "fresh" pulse unchanged.
- Shop: shelf as a glass shelf (lighting, contact shadows under shells and jars); price pills as enamel pills; the "awake" state = `fx-glow` in the shell's colour 0.35 + `snap` scale 1.08 (instead of only a button outline). Captions 13 → 14 px. Ability text in a plate.
- Tabs: keep the ribbon bookmarks; give them the enamel material and a 2 px drop shadow.

### P13 Shell opening
- Replace the 0.86 scrim over Start with: Start UI fades out (160 ms), env dims to 0.5.
- Lid: rotate open around the hinge with a skew (scaleY 1 → 0.45 plus skewX 0.15) and show the nacre inside (existing texture).
- Light by rarity (channel count, not suspense): common 1 `fx-shock`; uncommon + 4 sparkles; rare + second ring; epic + 6 beams; legendary + 8 beams; mythic + 12 beams in 6 rainbow segments. Beams rotate 12°/s (existing rule).
- The pearls and rombs sit on an enamel plate under the figure (no text bleeding through).

### P14 Upgrade celebration
- On the second tap: the cost pills count down into the button (200 ms), the button `press`; a romb thing-icon flies from the button to the buddy's shoulder (`glide` 360 ms), shoulder romb `pop` 1.4; one `fx-shock` in the rarity colour from the buddy + 8 sparkles; the next ability bar segment fills with a light sweep (a `fx-streak` crossing it, 240 ms); buddy plays its showcase (existing). Sound: existing upgrade sound.

### P15 Launcher icon and splash
- Current icon (`assets-src/icon-*.svg`) is clean but flat: white U-jar outline, small cyan Glimt, dark bg with faint stripes.
- **Direction:** background = Glimtarna env (sky gradient + 3 soft beams + 6 motes) as SVG gradients; foreground = a *glass* jar (tinted fill 0.18, fresnel edges, thick lip in `#7CF9FF`) holding a large Art v2 Glimt (level 0) at 58 % of the safe zone, with a level 3 Pling peeking at the back right. Keep within the 66 dp adaptive safe zone; monochrome = jar + Glimt silhouette. No text in the icon.
- **Splash:** Android 12+ system splash = the new foreground on `sky[1]` `#0B1A38` (not `#0B1020`), so it matches the first frame. Pre-12: `splash.xml` radial `#12305A` → `#0B1A38`.
- Regenerate with `scripts/gen-icons.mjs` (release engineer owns the pipeline).

### P16 Loading and first frame
- `index.html`: `body` background = `#0B1A38` (not `#000`) and a CSS radial gradient matching the env, so the first paint already matches the splash.
- Boot: bake the env base *first* (≈4–20 ms) and show it, then load the font (existing 1.5 s timeout) and bake the level set. The logo appears at the splash icon's position and scale, then settles into place (§8 Boot → Start).
- Never show a black or white frame between splash, WebView and Start. Measure with a screen recording on device (phase 4).

---

## 13. Top 10 polish items (for the producer)

1. **P1 Full-bleed world** (5 × M): kills the letterbox, the single most visible "unfinished" signal.
2. **P3 Glass jar + caustics** (5 × M): the jar becomes the hero object.
3. **P2 Animated environment per set** (5 × M): sets become places.
4. **P4 HUD polish + Fredoka everywhere** (5 × S–M): cheapest big win; removes the debug look.
5. **P7 Round summary card** (5 × L): Anders' requirement; replaces the weakest screen.
6. **P6 Jackpot choreography** (4 × M): the biggest moment finally looks like one.
7. **P8 In-round pickup tokens + toasts** (4 × M): Anders' requirement; rewards travel.
8. **P5 Shared glow + merge/chain VFX** (4 × M): consistent light, lower texture memory.
9. **P9 Scene transitions** (4 × M): one continuous place.
10. **P10 Specials v2** (3 × M): bomb and rainbow are the last v1 art in play.

---

## 14. Performance budget and fps risks

**Budget for all Art v3 layers together at Z = 2:** ≤2.0 extra screens of overdraw and ≤1.5 ms GPU per frame on a mid Android; zero allocations per frame; all textures baked once. Measured bake times (desktop Chromium, DPR 2.17): env base 3.7 ms, jar back+front 3.6 ms, 4 FX sprites 3.4 ms, caustic tile 38–50 ms (≈200 ms on a cheap Android: bake after first frame, or in 1× when the guard has tripped).

| Risk | Why | Mitigation |
|---|---|---|
| **Fill rate of full-screen ADD layers** (rays, caustics, washes) | mobile GPUs are fill-bound; a transparent full-screen quad costs as much as an opaque one | beams as narrow sprites (≈12 % of screen each), caustics only over the jar's upper 460 px, jar front as strips, jackpot wash ≤480 px |
| **Two caustic TileSprites** | ≈0.9 screen of overdraw at Z = 2 | guard tripped → one layer, 1× texture; calm mode → 30 % speed (no cost change) |
| **Env texture memory** | 780×1688 RGBA ≈ 5.3 MB at DPR 2 (8 MB at DPR 3 if uncapped) | cap env at Z (≤2); one set at a time; count it in the Art v2 budget (≤24 MB total) |
| **Caustic bake time** | ≈200 ms on low-end at boot | bake after the first frame; show the jar without caustics until ready (fade in 400 ms) |
| **Per-body glow + contact shadow sprites** | 2 extra sprites per body (up to ≈40 bodies ⇒ 80 sprites) | same texture ⇒ one batch; small quads; drop contact shadows when the guard trips |
| **Jackpot peak** (12 beams + 2 rings + 38 sparks) | ≈1 ms extra for 1.2 s | during slow-mo physics is cheaper; skip beams when the guard has tripped |
| **Canvas2D `filter: blur`** in bakes | slow on some WebViews, unsupported on older Safari | only at bake time; renderers fall back gracefully (blur is cosmetic) |
| **DOM env canvas behind Phaser** (P1 option A) | an extra composited layer | compositor-only CSS animations; test on a low-end device before committing to it |
| **Text re-rasterisation** (score pops with stroke) | Phaser Text re-renders on change | pool pop texts; set text once per pop; keep the pouch number as a bitmap-digit strip if profiling shows cost |

**Fps guard integration:** when the guard trips (Z → 1), also: motes 28 → 12, caustics 2 → 1 layer, contact shadows off, jackpot beams off, env baked in 1×. Add these to the guard's "quality level" so QA can force it (`perfSimulate`).

---

## 15. Guardrails (checked for every item above)

- Everything drawn in code (Canvas2D bakes, SVG strings, Phaser primitives). No bitmap assets from outside the team.
- Flash guard: ≤3 brightness changes per second anywhere, no white flashes, one warm wash per jackpot/new set, loops scale/position only (§6).
- Calm mode: specified per item (§5, §7, P6, P8, P11, P13).
- HUD contrast ≥4.5:1 on every set (§3 numbers).
- Textures baked once; nothing heavy per frame; respects `ART.perfGuard` (§14).
- Readability for a 7-year-old: shape + colour + face for pieces; icons + short labels; no information by colour only; no text under 14 px.

---

## 16. Artefacts produced in phase 1

| Path | What |
|---|---|
| `docs/art/audit/*.png` (29) | audit shots, 390×844 @2x, test version 8, quantised PNG |
| `docs/art/audit/capture.mjs` | Playwright capture script (own server on :4190; uses `?test=1`, `__game`, `__book`, `__start`) |
| `docs/art/concepts/c1-game-environment-glass-hud.png` | before/after: world, glass, caustics, HUD |
| `docs/art/concepts/c2-jackpot-vfx.png` | before/after: jackpot light sandwich |
| `docs/art/concepts/c3-gameover-results-card.png` | before/after: game-over card style |
| `docs/art/concepts/c4-resource-earn-tokens-toast.png` | before/after: pickup tokens, pouch punch, toast (composite of two moments) |
| `docs/art/concepts/c5-round-summary.png` | before/after: round summary in RETENTION §10.2 zones |
| `docs/art/concepts/src/{concepts.ts,render.mjs}` | concept harness (imports the real renderers; `node render.mjs`) |
| `app/src/data/artEnv.ts` | env, glass and FX-sprite parameters (pure data) |
| `app/src/ui/envArt.ts` | pure Canvas2D renderers: env base, rays, motes, caustic tile, jar back/front, glow, shock, sparkle, streak, beam |

Concept frames are 360×779 logical (the full 390×844 screen, P1 option B layout). Values in them are the values in this document.

---

## Reviews

Sign-off log. A change ships only with a line here ("PASS", "PASS with conditions" or "NOT SIGNED OFF").

| Date | Build / change | Verdict | Notes |
|---|---|---|---|
| 2026-09-26 | Test version 8, whole game (phase 1 audit) | **NOT SIGNED OFF** | Overall 2.4/5. Blocking for "premium": P1 letterbox, P3 jar, P4 font/HUD, P6 jackpot tint, P7 round end. See §1 |
| 2026-09-26 | Art v2 materials (objects, buddies) | **PASS** | Premium level; keep. Specials, pearls, rombs, shells still v1 (P10) |
| 2026-09-26 | Start v2 (UI.md §16) | **PASS with conditions** | Conditions: full-bleed (P1), env behind the stage (P2), shell opening layering bug (P13) |
| 2026-09-26 | Settings sheet | **PASS** | Consistent with Start v2 |
| 2026-09-26 | RETENTION §10 pickup + summary (design) | **Direction set** | Look and motion in P7 and P8; concepts `c4`, `c5`. Pouch position follows RETENTION until P1 option B moves it to the top band |

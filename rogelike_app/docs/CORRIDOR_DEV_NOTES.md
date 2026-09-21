# Korridoren (M5) – utvecklaranteckningar

*Dev, 2026-09-21. Dag 1–2 av 3 i vertical slice "Korridoren". Normativa källor:
`docs/design/CORRIDOR_DESIGN.md` (innehåll och känsla), `docs/research/05_fps_korridor.md`
(teknik), `docs/UI_GUIDE.md §17` (krit-lagret). Den här filen beskriver bara
**vad som byggts, hur det hänger ihop och var dev 1 kopplar in det**.*

Levererat i tre commits: kartmodellen, texturerna, vyn + rökprovet.

---

## 1. Filer

| Fil | Ansvar |
|---|---|
| `src/core/corridor_map.gd` | Ren data. `RunGraph` → rutnät. Seedad, deterministisk, serialiserbar. Inga Node-beroenden. |
| `src/game/corridor/corridor_mesh.gd` | Statisk byggare: våningen som en `ArrayMesh` med tre ytor + listor med dörrar/facklor/skyltar. |
| `src/game/corridor/corridor_camera.gd` | `Camera3D` med steg-/vridningstween, absolut yaw, reducerad rörelse. |
| `src/game/corridor/corridor_hud.gd` | Krit-HUD: HP, rum, Pips, kritstråk, character sheet-knapp, kugghjul. |
| `src/game/corridor/direction_buttons.tscn/.gd` | Tumzonens tre knappar. |
| `src/game/corridor/corridor_view.tscn/.gd` | Orkestrering: `SubViewport`, rekvisita, fiender, splitar, signaler. |
| `tools/gen_tileable.py` | Sömkontroll av UI:s kakelbara texturer + `sign_plate.png`. |
| `tools/smoke_corridor.gd` | Rökprov + skärmdumpar + stoppregelns två siffror. |
| `tests/test_corridor_map.gd` (17 fall) · `tests/test_corridor_view.gd` (14 fall) | |

`project.godot` är **orörd**. Korridoren är en scen, ingen autoload.

---

## 2. Scenträd

```
CorridorView (Control)                     ← src/game/corridor/corridor_view.tscn
├── Background (ColorRect, #0E1216)
├── ViewportBox (SubViewportContainer, stretch, stretch_shrink = 2, Nearest)
│   └── SubViewport (own_world_3d, UPDATE_ALWAYS)
│       └── World (Node3D)
│           ├── Environment (WorldEnvironment)   depth fog, #0E1216, 2–11 m
│           ├── Geometry (MeshInstance3D)        hela våningen, 3 ytor
│           ├── Props (Node3D)                   dörrar, facklor, skyltar
│           ├── Encounter (Node3D)               fiendebillboards, 2+2
│           └── Camera (CorridorCamera)          fov 75, KEEP_WIDTH
├── Hud (CorridorHud)
└── Steer (DirectionButtons)
```

**Upplösning:** `stretch_shrink = 2`. I stridssplitten är containern 1080×864 ⇒
`SubViewport` **540×432**, exakt talet ur research 05. I utforskningssplitten är
containern 1080×1668 ⇒ 540×834. Bredden — och därmed det horisontella
bildutsnittet — är densamma i båda, vilket är hela skälet till `KEEP_WIDTH`
(UI_GUIDE §17.1). Den vertikala vinkeln växer till ~100° i utforskning; det ser
dramatiskt ut i korridoren men är för vidvinkligt för fiender, därför visas
möten i stridssplitten.

---

## 3. Signaler (allt dev 1 behöver lyssna på)

```gdscript
signal cell_changed(cell: Dictionary, map_state: Dictionary)
signal encounter_reached(node_id: String, enemy_ids: Array)
signal trap_choice(trap: Dictionary)
signal treasure_found(treasure: Dictionary)
signal boss_door_reached()
signal fate_door_reached()
signal floor_cleared(floor_index: int)
signal character_sheet_requested()
signal settings_requested()
```

Publikt API:

```gdscript
setup(map: CorridorMap, ctx := {"hp":, "max_hp":, "room":, "pips":})
set_status(hp, max_hp, room, pips)
set_next_enemies(enemy_ids: Array)     # innan spelaren ser silhuetten
clear_encounter()                      # när striden är slut
resolve_trap(option_index: int) -> Dictionary
open_door()                            # await:bar, 420 ms
show_combat_split() / show_explore_split() / set_split(ratio)
set_reduced_motion(bool) / set_speed_scale(float)
step(action: String) -> bool           # await:bar, samma väg som en knapptryckning
max_steps_without_event() -> int
enemy_anchor(index: int) -> Vector2    # för HP-chipsen i krit-lagret
```

---

## 4. Integrationspunkter för dev 1 (GameController)

Inget av det här är byggt än — det är dag 3 och ligger i `game_controller.gd`,
som jag inte rör.

1. **Ny skärm `SCREEN_CORRIDOR`** → `res://src/game/corridor/corridor_view.tscn`.
   Vyn är ett `Control`, inte en `GameScreen`: den har inget `world_scene` och
   monterar ingenting i `World/WorldRoot`. Enklast är att låta en tunn
   `CorridorScreen extends GameScreen` instansiera den, eller att lägga vyn
   direkt i `ScreenRoot`.
2. **Flödet:** `town → corridor → (combat overlay 45/55) → corridor → … → boss`.
   * `encounter_reached(node_id, enemy_ids)` ⇒ `show_combat_split()` på vyn,
     lägg stridsskärm v2 i de nedre 55 %, kör striden som idag.
   * När striden är vunnen: `clear_encounter()`, `set_status(...)`,
     `show_explore_split()`, och låt spelaren gå vidare.
   * `boss_door_reached()` ⇒ visa `OPEN`-knappen. **Ett eget tapp**, aldrig
     automatiskt (CORRIDOR_DESIGN §3.3). Tappet kallar `await view.open_door()`
     och sedan M2:s befintliga boss-intro.
   * `floor_cleared(floor)` ⇒ trappan ner, ny `RunGraph.generate_floor(floor+1)`,
     ny `CorridorMap.build(...)`, `setup()` igen.
3. **Fienderna måste stå på plats innan spelaren ser dem.** Lyssna på
   `cell_changed`, läs `view.map.available_actions()`, ta `leads_to_node` ur
   någon av posterna och gör `view.set_next_enemies(ids)` med
   `Content.encounter(node["room"], node["variant"])`. `tools/smoke_corridor.gd`
   `_prime_enemies()` är en färdig förlaga.
4. **Autosave per ruta.** `cell_changed(cell, map_state)` ⇒
   `SaveIO.save_run(run, {"corridor": map_state, "node": current_node_id})`.
   `map_state` är `CorridorMap.to_dict()` och går rakt in i JSON. Vid
   återupptagning: `CorridorMap.from_dict(...)` och `view.setup(map, ctx)` —
   kameran hamnar på rätt ruta med rätt vinkel, och händelseloggen töms så att
   inga gamla händelser spelas om. **Spärren gäller oförändrat:** aldrig spara
   mitt i en kedja; ett steg i korridoren är däremot alltid en rundgräns.
5. **Fällan.** `trap_choice(trap)` ⇒ visa två knappar med `trap.options[i]`.
   Varje option är `{id, cost: "hp"|"cracked_face", amount}`. Rita **båda
   prislapparna före tappet** (§6 gäller i korridoren också). Svara med
   `view.resolve_trap(index)`; kartan släpper spärren och vyn ritar om
   knapparna. `cost == "hp"` ⇒ dra HP. `cost == "cracked_face"` ⇒ spräck en
   slumpad uppåtsida till nästa rum, samma regel som `SLAGJAW`s `CRACK_BITE`.
   **Korridoren äger ingen regel och drar inget själv.**
6. **Skatten.** `treasure_found(treasure)` ⇒ `{id: FORGE_FACE|PIPS|RELIC|CODEX,
   amount?, pool?}`. Altarpresentationen (CORRIDOR_DESIGN §3.5) är inte byggd.
7. **Character sheet-knappen** är en stubb: `character_sheet_requested()`.
   `settings_requested()` kan kopplas rakt till `open_settings()`.
8. **Reducerad rörelse och kedjetempo** speglas in med
   `set_reduced_motion(Settings.reduced_motion)` och
   `set_speed_scale(...)` (0,5 = Blixt). Vyn läser **inte** `Settings` själv,
   med flit: den ska gå att instansiera ur ett `-s`-skript utan autoloadarna.
9. **Rng.** `CorridorMap.build(graph, rng.fork("corridor"))`. Forken hindrar att
   korridorformen rör stridsströmmen, så en sparfil från före M5 fortfarande
   ger samma strider.

---

## 5. i18n-nycklar som saknas

Alla går via `Tokens.translate_or(key, english_source)` och visar
källsträngen tills UI-agenten lagt in raderna i
`assets/i18n/translations.csv`. **Jag har inte rört CSV:n.**

| Nyckel | Engelsk källsträng | Var |
|---|---|---|
| `CORRIDOR_LEFT` | `LEFT` | riktningsknapp |
| `CORRIDOR_FORWARD` | `FORWARD` | riktningsknapp |
| `CORRIDOR_RIGHT` | `RIGHT` | riktningsknapp |
| `CORRIDOR_SIGN_FIGHT` | `fight` | knappens underetikett + skylt |
| `CORRIDOR_SIGN_ELITE` | `elite` | – |
| `CORRIDOR_SIGN_REST` | `rest` | – |
| `CORRIDOR_SIGN_MARKET` | `market` | – |
| `CORRIDOR_SIGN_FATE` | `fate roll` | – |
| `CORRIDOR_SIGN_UNKNOWN` | `unknown` | – |
| `CORRIDOR_SIGN_BOSS` | `boss` | – |
| `CORRIDOR_ROOM` | `ROOM %d` | HUD-chip |
| `CORRIDOR_FLOOR_TILES` | `FLOOR %d · %d TILES` | kritstråkets etikett |

Dessa behövs när dev 1 bygger fäll-, dörr- och skattpanelerna (inte mina):
`CORRIDOR_OPEN_DOOR` (`OPEN`), `CORRIDOR_WAY_BACK` (`THE WAY BACK IS GONE`),
`TRAP_WEB` / `TRAP_EMBERS` / `TRAP_COLLAPSE` + en rad per alternativ-id
(`PUSH_THROUGH`, `CUT_FREE`, `RUN_ACROSS`, `SMOTHER`, `SQUEEZE`, `DIG_OUT`).

---

## 6. Avvikelser från underlaget, och varför

1. **Kantlängder 2–3 steg, inte 2–4** (`ENTRY/MID/JUNCTION/BRANCH_STEPS`).
   Stegbudgeten styr: en våning kostar `entry+mid+junction+branch+silent+4`, en
   run är tre våningar plus upp till tre återvändsgränder à 4 steg. Med 2–4 rakt
   igenom blev värsta fallet 75 steg, alltså över PM:s 40–70. Nu:
   `min 45, max 69`. Uträkningen står i en docstring i `corridor_map.gd`.
2. **Ett tapp åt vänster/höger vrider OCH går.** Mockupen säger `VÄND`, men
   CORRIDOR_DESIGN §1.2 säger "ett tapp = ett steg = en ruta" och två tapp per
   gren är en tapp för mycket i en 15-minutersrun. Vyn vrider 160 ms och går
   sedan 180 ms, så känslan av vridning finns kvar. **Följd:** att vända sig om
   och titta bakåt (§3.4:s "lugnande tomma korridor") finns inte. Ligger i
   BACKLOG som en ren vy-funktion; kartan behöver inte ändras.
3. **Hörn vrids när man kommer fram, inte vid nästa tapp.** Utan det står
   spelaren och tittar in i en vägg tills hen trycker FRAM igen — en bild där
   ingenting går att läsa. §2.2 säger att hörn kostar noll steg och all sikt.
4. **Man står 1,35 m bakom mitten i en T-korsning** (och 1,10 m framför en
   dörr). En 3 m gång med 75° horisontellt visar bara 2,3 m på 1,5 m avstånd:
   den som står mitt i korsningen ser en vägg och inga mynningar. Se
   `docs/screenshots/m5/vulkan_02_junction.png`.
5. **Bakre ledet står på x = ±0,40, inte ±0,75.** Research 05 §3 föreslog samma
   sidled i båda leden, men då döljs de bakre helt av de främre och "antal
   fiender läses av silhuetterna" (§3.1) faller.
6. **Skyltarna hänger på korsningens bortre vägg, vända mot den som kommer** —
   inte i mynningen. En skylt i mynningen syns inte förrän man redan vänt sig
   dit, och då är valet gjort.
7. **Återvändsgränden vänder spelaren på plats** (`turn_around`, 260 ms) i
   stället för att låta hen backa. Det är §2.3 regel 4:s fyra steg, och det
   enda undantaget från "inget bakom spelaren".
8. **Ödeskastets dörr byggs bara med `allow_fate = true`** (default false).
   DECISIONS säger att `FATE_ROLL` inte kommer före M3; dörren finns i modellen
   och i `--allow-fate` i rökprovet så att M3 kostar noll ny teknik.
9. **En yta per textur, inte en atlas.** Research 05 §1 skrev "en atlas ⇒ 1–3
   draw calls". Mipmaps på en atlas blöder mellan regionerna på de låga
   nivåerna; tre draw calls i stället för en är billigare än den artefakten och
   fortfarande långt under 100-taket.
10. **Mipmaparna genereras vid inläsning**, inte i `.import`-filerna:
    `assets/` ägs av UI-agenten. `CorridorMesh.tile_texture()` gör
    `get_image() → generate_mipmaps() → ImageTexture`. Kostnaden är tre 64×64
    bilder en gång per start. **Önskemål till UI/PM:** sätt
    `mipmaps/generate=true` på `wall_stone`, `floor_stone` och `ceiling_stone`,
    så kan funktionen bli ett rakt `ResourceLoader.load()`.

---

## 7. Renderarunderlag (PM:s beslut)

Kört under Xvfb, 1080×1920, seed 7, samma väg genom våningen i båda.

| | Vulkan / **Forward Mobile** | OpenGL / **Compatibility** |
|---|---|---|
| Depth fog | **fungerar** | **fungerar** |
| Texturer, mipmaps | identiska | identiska |
| Bildruta p50 | 31,8 / 33,9 ms | 29,8 / 28,4 ms |
| Bildruta p95 | 57,8 / 59,8 ms | 39,2 / 36,1 ms |
| Skärmdumpar | `docs/screenshots/m5/vulkan_*.png` | `docs/screenshots/m5/gl_*.png` |

* **Fog behövdes inte falla tillbaka på per-vertex-mörkning.** Reserven finns
  ändå: meshen skriver `COLOR` per hörn och materialen har
  `vertex_color_use_as_albedo`, så en djupmörkning kan läggas in utan att röra
  geometrin.
* **Bilderna är i praktiken identiska.** Medelavvikelse **1,4/255** per kanal
  över hela bilden. ~25 % av pixlarna skiljer mer än 8 i någon kanal, och det
  är uteslutande enstaka texelgränser: de två renderarna avrundar
  nearest-samplingen olika på en halv texel. Ingen skillnad i dimma, ljusstyrka
  eller geometri (luminansprofilen ner genom korridoren är 17–24 i båda).
* **Siffrorna är INTE enhetsrepresentativa.** Den här maskinen har ingen GPU;
  allt renderas av `llvmpipe` i programvara. Det enda de säger är att
  Compatibility är billigare *för en mjukvarurasteriserare*, vilket följer av
  att den gör mindre per bildruta. **Måste mätas på Anders telefon innan
  beslut** — det är M4-rutinen, inte den här.
* **Observation som bör med i CI:** `--rendering-driver vulkan` ensamt gav
  **Forward+**, trots `renderer/rendering_method="mobile"` i `project.godot`.
  Först med `--rendering-method mobile` skrev motorn "Forward Mobile". Alla
  desktop-mätningar av mobilrenderaren måste alltså skicka flaggan explicit.

---

## 8. Stoppregelns siffror (CORRIDOR_DESIGN §8.1)

Seed 7, våning 1, 180/160 ms-tweens, normalt tempo:

* **17 steg** på våning 1, **5,0–5,5 s** korridortid ⇒ **15,5–16,7 s per run**
  (×3 våningar). Budget 90 s. **Klarad med stor marginal.**
* **Max 3 steg utan händelse.** Taket är 3. **Precis klarad** — och det är rätt
  siffra att vakta: den blir 4 så fort någon vidgar en kantlängd utan att lägga
  till en skylt eller en silhuett. Rökprovet fäller körningen om det händer.
* Testet `test_a_run_stays_inside_the_step_budget` håller 40–70 steg per run för
  40 seeds, både med och utan återvändsgränder.

---

## 9. Öppna frågor

1. **Ljud saknas helt.** De sex cuerna i §7.2 (`step_stone`, `turn_scuff`,
   `door_open`, `monster_far`, `torch_draft`, `descend_stairs`) är inte
   genererade och inte kopplade. `tools/gen_sfx.py` ägs av UI. Vem tar dem?
2. **Fäll-, skatt- och dörrpaneler** är signaler utan UI. Dev 1 eller UI?
3. **Hemliga dörrar (§2.5) och tellet** är inte byggda. Medvetet: de är dag 3+
   och kräver en tapbar yta i 3D (`Area3D` + `input_event`), vilket är ny
   teknik i vyn.
4. **Kritstråket** ritar ett streck per gången ruta men har ingen glyf vid
   passerade korsningar och inget kryss där man vände (§2.7). Behöver UI:s ord
   om hur de ska se ut.
5. **Kameran har ingen "titta bakåt"**, se avvikelse 2.
6. **Våningstonen** är `albedo_color` per våning (tre toner i
   `CorridorView.FLOOR_TINTS`). Research föreslog `palette_lut` i 3D-variant.
   Tonen räcker för tre våningar; LUT:en är en uppgradering, inte ett krav.
7. **`Engine.max_fps`** sätts inte av korridoren. Om PM vill ha 60 som tak hör
   det hemma i `project.godot`, som jag inte rör.

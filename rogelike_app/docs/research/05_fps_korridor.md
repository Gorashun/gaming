# 05 – First-person-korridor: teknikval, kartmodell, strid, character sheet

*R&D, 2026-09-21. Underlag för DECISIONS 2026-09-21 ("Presentationsskifte: old
school first-person dungeon crawler"). Alla webbkällor hämtade 2026-09-21.*

## Fråga

Hur bygger en solo-dev utan grafiker en Eye of the Beholder-/Grimrock-känsla i
PIPWRECK, i Godot 4.6, portrait 1080×1920, med befintliga 2D-pixelsprites,
befintligt `World`/`ChalkUI`-lagerbygge och befintlig `RunGraph` — utan att
tappa 60 fps på mid-range Android eller bygga om `src/core/`?

---

## Slutsats (först)

1. **Bygg alternativ A: riktig 3D i Godot, men minimal.** Korridoren är
   **en enda procedurellt byggd `ArrayMesh`** (inte GridMap), unlit, med 5–10
   kakelbara 64×64-texturer i en atlas ⇒ **1–3 draw calls för hela våningen**.
   Fiender är `AnimatedSprite3D`-billboards som återanvänder de **befintliga**
   arken (4 idle + 3 death) utan en enda ny bildfil. Ljuset är **depth fog**,
   inte lampor. Detta är samma recept som Etrian Odyssey: *"a combination of
   relatively simple 3D computer graphics for environments and single-frame 2D
   sprites for enemies"* (Wikipedia, hämtad 2026-09-21).
2. **Alternativ B (EOB-lagren) faller på art-mängden, inte på tekniken.**
   EOB ritade varje väggbit i **varje** djup och **varje** kombination av
   cell/+1/+2 och skalade dessutom ned varje väggbit två gånger (GameDev.net,
   hämtad 2026-09-21). Perspektivritad konst är exakt det en procedurell
   pixelgenerator *inte* kan göra. B kräver en grafiker. **Avråds.**
3. **Alternativ C (shader/Polygon2D-perspektiv) är en tredje motor att
   underhålla** för en effekt 3D ger gratis. Avråds, men **krit-look på
   korridoren löses ändå i shader** — som en unlit `ShaderMaterial` på
   ArrayMesh:en (3D-variant av `palette_lut.gdshader`), inte som egen renderare.
4. **Korridoren renderas i en `SubViewport` under `ChalkUI`.** Det bevarar hela
   `ARCHITECTURE.md`-uppdelningen: 3D ersätter `WorldRoot`-innehållet, krit-UI:t
   ovanpå är orört. Lågupplöst 3D (t.ex. 540×432 uppskalat till 1080×864) ger
   dessutom både pixellook och stor prestandamarginal — "at 50 % scaling on a 3D
   game, you could potentially get 200 % to 300 % of native performance"
   (godot-super-scaling, hämtad 2026-09-21).
5. **Renderarvalet bör omprövas.** CLAUDE.md säger mobile renderer, men vår 3D
   är unlit och trivial och `gl_compatibility` når fler enheter. Se §7.

---

## 1. Teknikjämförelse

| Kriterium | **A. Godot 3D (ArrayMesh + Sprite3D)** | B. 2D-lager à la EOB | C. Polygon2D/shader-perspektiv |
|---|---|---|---|
| Nya bildfiler | **~8–10 kakelbara 64×64** | ~20 väggbitar × djup × våning ⇒ **60–180**, perspektivritade | 0 bilder, men all form i shaderkod |
| Kan `gen_pixel_assets.py` göra dem? | **Ja** (kakelbar brick/stone-noise, §5) | Nej – kräver handritat perspektiv | Delvis |
| Draw calls | **1–3** (en atlas, ett material) + 1/fiende | 20–40 `Sprite2D` | 5–15 `Polygon2D` |
| Fiender | Befintliga ark rakt in som `AnimatedSprite3D` | Kräver 3–4 skalsteg per fiende | Samma som B |
| ChalkUI ovanpå | Oförändrat, `SubViewportContainer` i `World` | Oförändrat | Oförändrat |
| Steg/vridningskänsla | `Tween` på `Camera3D` – äkta parallax gratis | Hård cross-fade eller 4–6 mellanlägen per vridning | Svår att få stabil |
| LLM-genererad GDScript | **Bäst** – SurfaceTool + Tween är rakt, välkänt API | Mycket bokföring av lager/z-index | Matematiktung shader, dyrast att felsöka |
| Headless-testbarhet | Kartlogik i `src/core/`, `unproject_position()` är ren matematik | Samma | Sämre (allt i fragment shader) |
| **Omdöme** | **Rekommenderas** | Avråds | Avråds |

### Noder och API:er (Godot 4.6)

`SubViewport` · `SubViewportContainer` · `Camera3D` (`fov`, `keep_aspect`,
`unproject_position()`) · `MeshInstance3D` + `ArrayMesh` byggd med
`SurfaceTool` · `StandardMaterial3D` med `shading_mode = SHADING_MODE_UNSHADED`
och `texture_filter = TEXTURE_FILTER_NEAREST_WITH_MIPMAPS` ·
`WorldEnvironment` + `Environment.fog_enabled` / `fog_mode = FOG_MODE_DEPTH` ·
`AnimatedSprite3D` (ärver `SpriteBase3D`) · `Tween` · `OmniLight3D` (valfri,
en enda, "kritlyktan") · `GridMap` **används inte**.

`SpriteBase3D`-egenskaperna vi sätter (Godot-dokumentationen, hämtad
2026-09-21): `billboard` (`BaseMaterial3D.BILLBOARD_FIXED_Y`), `alpha_cut`
(`ALPHA_CUT_DISCARD` = 1 — *"useful for pixel art since it avoids transparency
sorting issues"*), `pixel_size` (default 0.01), `texture_filter`, `shaded`
(default `false` — behåll så), `double_sided`, `render_priority`, `modulate`
(träffblixten), `no_depth_test` (håll `false`).

### Kodskiss – steg och vridning

```gdscript
class_name CorridorView
extends Node3D
## Kameran är den enda rörliga noden. Rutnätet är heltal; världen är
## tile * TILE_M. All rörelse går genom step_forward()/turn() så att
## "upptagen"-spärren och reducerad rörelse bara finns på ett ställe.

signal tile_entered(tile: Vector2i)

const TILE_M: float = 3.0
const EYE_M: float = 1.7
const STEP_MS: int = 180      # DECISIONS-kandidat, se §7 (åksjuka)
const TURN_MS: int = 160

const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

@export var reduced_motion: bool = false

@onready var _cam: Camera3D = %Camera3D

var _map: CorridorMap                 # ren data ur src/core/
var _tile: Vector2i = Vector2i.ZERO
var _facing: int = 0                  # 0=N 1=E 2=S 3=W
var _yaw: float = 0.0                 # OINSKRÄNKT vinkel, aldrig wrappad
var _busy: bool = false


func _world_pos(tile: Vector2i) -> Vector3:
	return Vector3(float(tile.x) * TILE_M, EYE_M, float(tile.y) * TILE_M)


func step_forward() -> void:
	if _busy:
		return
	var target: Vector2i = _tile + DIRS[_facing]
	if not _map.is_walkable(target):
		return
	_busy = true
	_tile = target
	if reduced_motion:
		_cam.position = _world_pos(_tile)
	else:
		var t: Tween = create_tween()
		t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(_cam, "position", _world_pos(_tile), float(STEP_MS) / 1000.0)
		await t.finished
	_busy = false
	tile_entered.emit(_tile)


## delta = -1 vänster, +1 höger. Absolut yaw undviker att Tween tar
## "kortaste vägen" och snurrar åt fel håll vid 270 -> 0 grader.
func turn(delta: int) -> void:
	if _busy:
		return
	_busy = true
	_facing = posmod(_facing + delta, 4)
	_yaw -= PI * 0.5 * float(delta)
	if reduced_motion:
		_cam.rotation.y = _yaw
	else:
		var t: Tween = create_tween()
		t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(_cam, "rotation:y", _yaw, float(TURN_MS) / 1000.0)
		await t.finished
	_busy = false
```

### Kodskiss – korridorsegmentgenerator

```gdscript
class_name CorridorMesh
extends RefCounted
## Hela våningen blir EN yta med ETT material. Väggkvad emitteras bara där
## grannrutan inte är gångbar, så insidan av korridoren kostar noll trianglar.

const TILE_M: float = 3.0
const CEIL_M: float = 3.2
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


static func build(map: CorridorMap, atlas: Dictionary) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tile: Vector2i in map.tiles():
		var o: Vector3 = Vector3(float(tile.x) * TILE_M, 0.0, float(tile.y) * TILE_M)
		_quad(st, o + Vector3(-1.5, 0, 1.5), o + Vector3(1.5, 0, 1.5), o + Vector3(1.5, 0, -1.5), o + Vector3(-1.5, 0, -1.5), atlas["floor"])
		_quad(st, o + Vector3(-1.5, CEIL_M, -1.5), o + Vector3(1.5, CEIL_M, -1.5), o + Vector3(1.5, CEIL_M, 1.5), o + Vector3(-1.5, CEIL_M, 1.5), atlas["ceiling"])
		for facing: int in 4:
			if map.is_walkable(tile + DIRS[facing]):
				continue
			var region: Rect2 = atlas[map.wall_key(tile, facing)]   # "stone", "door", "sign_COMBAT"
			_wall_quad(st, o, facing, region)
	st.generate_normals()
	st.index()
	return st.commit()


## En kvad med UV ur atlasregionen. UV skalas med rutans storlek i meter så
## att 64 px kaklas exakt en gång per 1,5 m (jfr Art.fit_scale i 2D).
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, region: Rect2) -> void:
	var uv: Array[Vector2] = [region.position, Vector2(region.end.x, region.position.y), region.end, Vector2(region.position.x, region.end.y)]
	var v: Array[Vector3] = [a, b, c, d]
	for i: int in [0, 1, 2, 0, 2, 3]:
		st.set_uv(uv[i])
		st.add_vertex(v[i])
```

---

## 2. Kartmodell: `RunGraph` → korridor

`RunGraph` är oförändrad. Ett **nytt rent core-objekt** `src/core/corridor_map.gd`
översätter grafen till rutor. Regeln:

* **Nod = kammare**, en ruta med fackla på sidoväggen och ett golvmärke.
* **Kant = N steg korridor.** Förslag: `N = 2` för raka kanter, `N = 1` fram
  till T-korsningen och `N = 2` ut i respektive gren. Hela våning 1 blir då
  **13 rutor** och ca **9 steg** ⇒ ~2,5 s gång per våning vid 180 ms/steg
  (uppskattning). Mer än så blir tomgång på mobil.
* **Förgrening = T-korsning.** `RunGraph.is_branch(id)` är sant ⇒ rutan får
  öppningar åt vänster och höger och **skyltplattor ovanför varje öppning**
  med den befintliga 16 px-nodikonen (`ui/node_*.png`, redan i `Art`) som
  texturregion. Precis Etrian/EOB-idiomet: man ser vad som väntar innan man
  väljer, men bara som ikon.
* **Inga fria rörelser.** Tre knappar i ChalkUI: `◀ VÄNSTER`, `▲ FRAM`,
  `HÖGER ▶`. Knappar som inte är giltiga i rutan dimmas. Tap på själva skylten
  = samma sak som riktningsknappen (större träffyta).
* **Autosave per ruta.** `tile_entered` → `RunState` får `corridor_tile`
  (`Vector2i` som två int) och `facing` (int). Spärren från `ARCHITECTURE.md`
  gäller oförändrat: aldrig spara mitt i en kedja.

### Fog of war och oväntade möten

* **Dimman gör jobbet.** `Environment.fog_mode = FOG_MODE_DEPTH` med täthet
  inställd så sikten tar slut vid ~3 rutor (9 m). Ingen extra geometri, ingen
  extra kostnad, och det är **samma svarta som krit-UI:ts botten** (`#0E1216`)
  så lagren smälter ihop.
* **Monstret som stiger ur mörkret:** billboarden finns redan på 9 m med alpha
  ≈ 0 ur dimman. Vid `combat_start` tweenas den från 6 m till 3 m på 400 ms med
  `TRANS_CUBIC/EASE_OUT` samtidigt som `modulate.a` går 0→1. Skräcken är gratis
  eftersom perspektivet gör skalan åt oss.
* **Ödeskast = dörr.** En återvändsgränd med dörrtextur i en sidogång. Dörren
  är ett tapbart `Area3D`/skyltquad; bakom den ligger M3-innehållet. En ruta,
  en textur, noll ny teknik.

---

## 3. Stridspresentation

**Vertikal split, portrait 1080×1920 (rekommendation):**

| Zon | px | Innehåll |
|---|---|---|
| Korridor-`SubViewportContainer` | y 0–864 (**45 %**) | 3D, renderad i 540×432 och uppskalad ×2 |
| Topp-HUD (ChalkUI, ovanpå korridoren) | y 0–120 | HP, rum, Pips, ⚙, `?` |
| Fiendechips (ChalkUI, ovanpå korridoren) | y ~620–860 | ankrade via `unproject_position()` |
| Räknestycke / kvitto (strid v2) | y 864–1060 | oförändrat från `COMBAT_READABILITY.md` |
| Slot-rad (5) | y 1060–1450 | oförändrat |
| Bricka (6 tärningar à ~50 dp = 150 px) | y 1450–1700 | 6×150 = 900 px + marginal ryms på 1080 |
| Knappar + safe area | y 1700–1920 | oförändrat |

Under **utforskning** är splitten i stället **100 % korridor** med bara HUD och
de tre riktningsknapparna. Splitten är alltså dynamisk, inte fast. Faller strid
v2 inte inom 352 dp vid textstorlek 130 %, sänk korridoren till **40 %** (768 px)
— testa mot `design/mockup_combat_v2.html` innan det låses.

**Kamera:** `Camera3D.fov = 75`, `keep_aspect = KEEP_WIDTH`. Med `KEEP_WIDTH` är
75° *horisontellt* oavsett att subviewporten är 1080×864 ⇒ vertikalt
2·atan(tan 37,5° · 864/1080) ≈ **63°**, tillräckligt för att golv och tak möts
synligt två rutor fram. `KEEP_HEIGHT` (default) skulle ge olika bildutsnitt i
strid och utforskning när splitten ändras — **fel**.

**Fiender, 1–4 st:** korridoren är 3 m bred; fyra i bredd blir soppa. Ställ dem
som Wizardry-formering: **front 2 st på z = −3,0 m, x = ±0,75; bak 2 st på
z = −4,5 m, x = ±0,75**. Djupet gör dem självklart åtskilda och löser samtidigt
problem #8 i `COMBAT_READABILITY.md` (kort ↔ varelse).

* `pixel_size = 0.055` ⇒ en 32 px-fiende är 1,76 m, en 48 px-boss 2,64 m. Samma
  värde för alla, så relativ storlek bevaras från 2D.
* **HP-chipsen är ChalkUI** och ankras varje frame:
  `chip.position = container_rect.position + cam.unproject_position(sprite.global_position + Vector3.UP * 1.2) * upscale - chip.size * 0.5`.
  Ett 2 px kritstreck (`Line2D`) från chipets underkant till billboardens hjässa.
* **Träffblixt:** `AnimatedSprite3D.modulate = Color(3, 3, 3)` i 60 ms (samma
  tidslinje som idag). **Skak:** tweena `sprite.position.x` ±0,08 m, inte
  kameran — kameraskak i förstaperson är åksjuka.
* **Death:** befintliga 3 death-frames + `modulate.a` → 0 och `position.y` −0,3 m
  på 300 ms.
* **Reducerad rörelse:** ingen inmarsch (billboarden är på plats direkt), ingen
  skak, blixten kvar. Tidslinjen ändras inte (DECISIONS 2026-09-21).

---

## 4. Character sheet (Diablo-stil)

Karaktären syns **aldrig** i korridoren. Paperdollen (nio `Sprite2D`-lager,
48×48, redan byggd) flyttar till en egen skärm — det är faktiskt en förenkling
jämfört med idag, där `HeroFigure` måste samsas med stridens World-lager.

```
┌ THE SMITH ─────────────── lvl/floor ┐
│  [HUVUD]                  [AMULETT] │   slot 64×64 px ram, ikon 16 px ×4
│  [VAPEN]   ███ paperdoll  [RELIK 1] │   paperdoll 48 px ×8 = 384 px hög
│  [HÄNDER]  ███ 384 px     [RELIK 2] │
│  [BRÖST]                  [RELIK 3] │
├─────────────────────────────────────┤
│  ⚀ ⚁ ⚂ ⚃ ⚄ ⚅   "vapenraden"        │   sex tärningar, tap = se sidorna
├─────────────────────────────────────┤
│  HP 100  ·  Pips 0  ·  Ward 0       │
└─────────────────────────────────────┘
```

**Mappning av de sex relikerna (`src/data/content.gd`) till slots:**

| Slot | Relik | Motivering |
|---|---|---|
| Vapen | `BLOOD_PRICE` | offrar HP för slagkraft |
| Bröst | `BROKEN_SCALE` | rustningsrelaterad |
| Händer | `THE OCTOPUS` (`OCTOPUS`) | fler händer = fler tärningar |
| Huvud | `CHEAT_CUBE` | manipulation, "tanken" |
| Amulett | `ECHO_MIRROR` | speglingen bärs på bröstet |
| Relik/talisman | `DOMINO` | kedjereaktionen |
| (klassrelik, fast) | `ANVIL_BLESSING` | egen sockel under paperdollen |

Slotten är **inte** en generisk inventering — det finns exakt en plats per
relik, så "byt relik → syns direkt" betyder: nytt paperdoll-lager tänds i
`Art`:s relik→lager-tabell (finns redan sedan M2) och slotramen får kritblixt.
Ingen drag-and-drop-inventering behövs för MVP.

**Referenser (sidor, inte direktlänkade bildfiler — kontrollera licens innan
skärmdump används i dokumentation):**
* Diablo II, Character Screen / Equipment: https://diablo.fandom.com/wiki/Character_Screen och https://diablo.fandom.com/wiki/Equipment (hämtade 2026-09-21). Slots i D2: huvud, kropp, bälte, handskar, stövlar, 2 ringar, amulett, vapen i vardera hand.
* Diablo Wiki (community), Inventory: https://www.diablowiki.net/Inventory (hämtad 2026-09-21).
* Darkest Dungeon, trinkets: två slots längst ned på hjältens character sheet, drag-and-drop — https://darkestdungeon.wiki.gg/wiki/Trinkets_(Darkest_Dungeon) (hämtad 2026-09-21). **Lånas: två slots räcker för att känna sig laddad; fler blir bokföring.**
* Slay the Spire: relikerna ligger som en **rad** högst upp, alltid synliga, aldrig i en meny. **Lånas till vapenraden**: relikerna får en mini-rad i strids-HUD:en (`show_relics`-flaggan finns redan i `COMBAT_READABILITY.md` §7), medan character sheet är den fullständiga vyn.

---

## 5. Assets: antal, tid och procedurell generering

| Fil | Storlek | Kommentar |
|---|---|---|
| `wall_stone.png`, `wall_scrap.png`, `wall_brick.png` | 3 × 64×64 | tre bastyper |
| `wall_torch.png` | 64×64 | vägg med konsol |
| `wall_sign.png` | 64×64 | tom skyltplatta; nodikonen läggs ovanpå som eget quad |
| `floor.png`, `ceiling.png` | 2 × 64×64 | |
| `door.png` | 64×64 | Ödeskast/boss |
| `boss_banner.png` | 64×64 | bossarenans enda extra |
| `torch_flame.png` | 16×16 ×4 frames | `AnimatedSprite3D`, 1 ark |
| **Summa nya bildfiler** | **≈10 PNG (+1 ark)** | |
| `palette_lut_3d.gdshader` | – | 3D-variant av befintlig shader |

**Tre våningsvarianter kostar noll nya filer:** samma atlas körs genom
`lut_world.png` med olika LUT-rad, exakt som `palette_lut.gdshader` redan gör i
2D. Det är den enskilt största besparingen i hela planen.

**Ja, `tools/gen_pixel_assets.py`-metoden klarar kakelbara texturer.**
`pixel_png.Canvas` är ren Python, så kaklingen blir en **konstruktionsregel**,
inte en efterbehandling. Föreslagen algoritm:

1. **Tegellattice.** Radhöjd `h = 8`, tegelbredd `w = 16`, varannan rad
   förskjuten `w/2`. Kakelbar per konstruktion eftersom `64 % w == 0` och
   `64 % (2*h) == 0`. 1 px murbruk i `out`-tokenen.
2. **Tegelvis ton.** `hash((bx, by, seed))` väljer ett av tre steg i rampen ⇒
   varje sten har egen valör utan att bryta paletten.
3. **Kakelbart value-noise.** Lattice `L ∈ {8, 16}`, gradvärden indexeras
   `grid[(i + 1) % L]` — **modulon är hela tricket**, ingen 4D-noise behövs.
   Två oktaver, amplitud 0,6/0,4, kvantiserat till 4 palettsteg.
4. **Skadepass.** Seedade flisor i tegelhörn, koordinater `% 64`.
5. **INGEN inbakad ljusgradient.** Ljuset kommer från dimman och (ev.) lyktan.
   En inbakad gradient upprepar sig synligt var 1,5:e meter.

Alternativet `NoiseTexture2D` + `FastNoiseLite.seamless = true` finns i Godot,
men dokumentationen noterar att seamless-noise *"may take longer to generate and
can have lower contrast"* (Godot-dokumentationen, hämtad 2026-09-21) — och en
runtime-genererad textur får ingen rad i `ASSET_LICENSES.csv`. **Generera i
Python, committa PNG:n.**

**Tidsuppskattning (solo + agentstöd, uppskattning):** generatorscript för
kakelbara texturer 0,5 dag · `CorridorMap` + tester 0,5 dag · `CorridorMesh` +
kamera + dimma 1 dag · billboards, chips och `unproject`-ankring 1 dag ·
character sheet 1 dag · staden 0,5 dag · rivning av `src/game/march/` och
`combat_world` 0,5 dag ⇒ **≈5 arbetsdagar** till en komplett ersättning av
presentationen.

---

## 6. Staden Chalkrim i FPS-format

**Rekommendation: en statisk förstapersonsvy, inga vridningar, inga steg.**
Torget byggs med **samma** `CorridorMesh`-kod som en 3×2-ruteskammare, kameran
står still, och de tre platserna (Gropens mun, Skrotmarknaden, Kritväggen) är
tre **upplysta dörröppningar** i väggen framför. Tap på en dörr går direkt in i
respektive platsskärm.

Varför inte "vänd dig vänster/mitt/höger": det lägger 2 × 160 ms vridning
mellan spelaren och varje meny i en skärm hen besöker efter *varje* run. Fiktion
vinner över friktion bara första gången.
Varför inte "statisk målning + tre knappar": det kräver **en ny stor
handritad bild** — precis det vi inte har grafiker till — och bryter
presentationen mot resten av spelet.
Kostnad för rekommendationen: **1 extra väggtextur (`wall_town.png`) och noll ny
kod.**

---

## 7. Risker

| Risk | Bedömning | Åtgärd |
|---|---|---|
| **Renderarval / enhetsräckvidd** | Öppen Godot-bugg #111729 (rapporterad 2025-10-16, fortfarande öppen): *"Exporting an Android project with the rendering method set to mobile leads to a significant drop in supported devices on Play Store"* — https://github.com/godotengine/godot/issues/111729 (hämtad 2026-09-21) | **Beslut till PM:** vår 3D är unlit, <2 000 trianglar, 1–3 draw calls. `gl_compatibility` (OpenGL ES 3.0) räcker och når budgettelefoner. Bygg båda i CI och jämför Play Consoles enhetsantal innan release |
| **Åksjuka** | Verifierat problem i genren: Grimrock-spelare begär "classic mode" med **omedelbar** vy efter vridning, uttryckligen mot åksjuka — https://steamcommunity.com/app/251730/discussions/0/154644349172040230/ (hämtad 2026-09-21) | Vridning **160 ms**, steg **180 ms**, `TRANS_SINE`. Ingen head-bob, ingen kameraskak, aldrig. **Reducerad rörelse = omedelbar vy** (inställningen finns redan) |
| **Mobilprestanda** | "Targeting under 100 draw calls per frame is a safe rule of thumb for mid-range devices" (slicker.me, hämtad 2026-09-21). GridMap kan ge 500+ draw calls i verkliga nivåer (godot-proposals #12110, hämtad 2026-09-21) | Därför **ArrayMesh, inte GridMap**. Rendera 3D i 540×432 SubViewport. `Engine.max_fps = 60`. Mät på Anders telefon i M4-stil, inte i editorn |
| **Shimmer på golv/tak** | Nearest utan mipmaps kokar vid snedvinkel — *"Nearest Mipmap ... uses mipmaps that are themselves blurred but still uses nearest neighbor for interpolation"* (godotforums, hämtad 2026-09-21) | **Undantag från research 04:s regel "Mipmaps: Off":** den gäller 2D-sprites. 3D-atlasen importeras med **mipmaps PÅ** och filter `Nearest Mipmap Linear`. Kompression förblir **Lossless** (10 små filer) |
| **APK-storlek** | Nuvarande debug-APK är 61 MB (STATUS.md). 10 st 64×64 lossless-PNG ≈ 30–80 KB totalt (uppskattning) ⇒ **< 0,2 % ökning**. Motorns 3D-moduler är redan med i standardtemplaten | Ingen åtgärd. Överväg custom build med avskalade moduler först i M5+ |
| **Arbetsmängd / kastad kod** | `src/game/march/` (~26 KB GDScript) utgår helt, `combat_world.gd` skrivs om | Core, resolver, `EventPlayer`, juice-motor och hela strid v2-specen är **oberörda**. Endast presentationslagret byts |
| **Headless-testning av 3D** | `godot --headless` renderar inte | Håll topologin i `src/core/corridor_map.gd` (ren data, gdUnit4). `Camera3D.unproject_position()` är ren matematik på kameratransformen och går att asserta headless: "fiende 3:s chip hamnar inom korridorrektangeln". Visuellt fortsätter smoke-runnern under Xvfb |

---

## Osäkerhet

* **Draw-call- och fps-siffrorna är uppskattningar**, inte mätta på hårdvara.
  Ingen mätning finns förrän APK:n körts på Anders telefon.
* **Depth fog i Mobile-renderaren** antas fungera (volumetrisk dimma är
  Forward+-exklusivt, vanlig depth fog ska finnas i Mobile) — **verifiera i
  editorn innan dimman görs bärande för "fog of war"**. Fallback: per-vertex
  mörkning i `palette_lut_3d.gdshader`, som ändå fungerar överallt.
* **`SurfaceTool.commit()` i headless-läge** är inte verifierat; det bör vara ren
  resurskonstruktion men RenderingServer är en dummy. Testa tidigt.
* **`fov = 75` är ett designval, inte en mätning.** Kör 65 / 75 / 85 sida vid
  sida på telefon i vertical slice-dagen och låt Anders välja.
* **godotengine.org och docs.godotengine.org blockeras av miljöns egress-proxy**
  (2026-09-21). Godot-dokumentationens innehåll är hämtat via
  `raw.githubusercontent.com/godotengine/godot-docs`. Citat om Godot 4.6:s
  rendering kommer från tredjepartsartiklar, inte från officiella release notes.
* **Bild-URL:er till Diablo/Darkest Dungeon är sidlänkar, inte filer.** Alla
  bilderna är upphovsrättsskyddade och får **inte** läggas i repot; de är
  referenser för UI-agenten att titta på.

---

## Rekommendation till PM

1. **Godkänn alternativ A** (Godot 3D: `ArrayMesh`-korridor, unlit atlas,
   `AnimatedSprite3D`-billboards, depth fog som lykta) och skriv in i DECISIONS
   att **GridMap inte används** och att korridoren renderas i en `SubViewport`
   under det oförändrade `ChalkUI`-lagret.
2. **Lås rörelsekonstanterna nu**: steg 180 ms, vridning 160 ms, `TRANS_SINE`,
   ingen head-bob, ingen kameraskak, och **reducerad rörelse = omedelbar vy**.
   Det är den enda designparametern med dokumenterad hälsokoppling i genren.
3. **Ta upp renderarfrågan som ett eget beslut.** CLAUDE.md säger mobile
   renderer; öppen bugg #111729 säger att det kostar enheter på Play, och vår
   3D behöver inte Vulkan. Bygg båda i CI och jämför innan release.
4. **Kör en vertical slice på 3 dagar**, i denna ordning:
   * **Dag 1** – `src/core/corridor_map.gd` (RunGraph → rutor, T-korsningar,
     skyltnycklar) med gdUnit4-tester, plus `tools/gen_tileable.py` som spottar
     ut 5 texturer (sten, tegel, golv, tak, dörr) med rad i `ASSET_LICENSES.csv`.
   * **Dag 2** – `corridor_view.tscn`: SubViewport 540×432, `Camera3D` fov 75 /
     KEEP_WIDTH, `CorridorMesh.build()`, dimma, steg- och vridningstween, tre
     ChalkUI-riktningsknappar, autosave per ruta. Går att gå våning 1 från rum 1
     till bossdörren.
   * **Dag 3** – strid: 4 billboards i front/bak-formering, HP-chips ankrade med
     `unproject_position()`, träffblixt/skak/död, splitten 45/55 mot befintlig
     strid v2. Skärmdumpar under Xvfb + en APK till Anders telefon.
5. **Behåll strid v2 och tutorialvåning 0 som de är specade.** Presentations-
   skiftet rör `src/game/`; `src/core/`, resolvern, `EventPlayer` och hela
   `COMBAT_READABILITY.md` överlever oförändrade. Riv `src/game/march/` först
   när dag 2 är grön.

---

## Källor (alla hämtade 2026-09-21)

1. Etrian Odyssey, Wikipedia – "simple 3D graphics for environments and single-frame 2D sprites for enemies": https://en.wikipedia.org/wiki/Etrian_Odyssey_(video_game)
2. Eye of the Beholder-tekniken (väggbitar per cell/+1/+2, nedskalning ×2): https://www.gamedev.net/forums/topic/681077-pseudo-3d-and-eye-of-the-beholder-or-bard39s-tale/5304190/ och https://gamedev.net/forums/topic/351186-eye-of-the-beholder-style-games/3298863/
3. Godot-bugg #111729, mobile renderer minskar Play-enhetsstöd (öppen, rapporterad 2025-10-16): https://github.com/godotengine/godot/issues/111729
4. Godot-proposal #12110, GridMap och draw calls (512 tiles ⇒ 512 draw calls): https://github.com/godotengine/godot-proposals/issues/12110
5. Optimizing Godot for Mobile – "under 100 draw calls per frame", `Engine.max_fps = 60`, profilera på riktig hårdvara: https://slicker.me/godot/mobile-optimization.html
6. `SpriteBase3D`-klassdokumentation (billboard, alpha_cut, pixel_size, shaded, render_priority): https://raw.githubusercontent.com/godotengine/godot-docs/master/classes/class_spritebase3d.rst
7. Pixel art i Sprite3D, mipmap-problemet: https://godotforums.org/d/37595-pixel-art-in-sprite3d-godot-4
8. Pixel art-uppsättning i Godot 4 (Nearest, viewport-läge, lågupplöst rendering): https://www.gdquest.com/library/pixel_art_setup_godot4/
9. Godot super scaling – 50 % renderskala ⇒ 200–300 % prestanda: https://github.com/cybereality/godot-super-scaling
10. `NoiseTexture2D` / `FastNoiseLite` seamless, lägre kontrast: https://docs.godotengine.org/en/stable/classes/class_noisetexture2d.html (sidan blockerad av proxyn; uppgiften kommer från sökresultatets utdrag 2026-09-21)
11. Grimrock 2, begäran om omedelbar vridning mot åksjuka: https://steamcommunity.com/app/251730/discussions/0/154644349172040230/ och https://steamcommunity.com/app/207170/discussions/0/613937942911710978/
12. Grid-baserad förstapersonsrörelse i Godot 4, PoC i Grimrock-stil: https://github.com/derekhsu/WizardTutorial
13. Grid movement utan jitter i Godot 4 (rotate_toward, exakt 90°), devlog april 2026: https://sidhant-majumder.itch.io/the-hidden-totem-in-the-dungeon/devlog/1473529/turbodev-day-1-fixing-grid-movement-jitter-in-godot-4-smooth-90-snap-with-move-and-slide
14. Dungeon Crawler Turn Based Godot Template (90°-vridning kostar ingen tur): https://rnb-games.itch.io/dungeon-crawler-godot-template
15. Diablo Wiki, Character Screen / Equipment: https://diablo.fandom.com/wiki/Character_Screen , https://diablo.fandom.com/wiki/Equipment , https://www.diablowiki.net/Inventory
16. Darkest Dungeon, trinket-slots på character sheet: https://darkestdungeon.wiki.gg/wiki/Trinkets_(Darkest_Dungeon)
17. Godot 4.6, rendering och releasetidpunkt (tredjepart, officiell sida blockerad): https://www.strayspark.studio/blog/godot-46-rendering-deep-dive-ssr-lightmapper-performance , https://www.gdquest.com/library/godot_4_6_workflow_changes/
18. Renderarval Forward+/Mobile/Compatibility: https://godotlearning.com/blog/godot-renderers-forward-mobile-compatibility

**Interna källor:** `docs/DECISIONS.md` (2026-09-21, presentationsskiftet),
`docs/ARCHITECTURE.md` (§"M1: scenträdet", safe area, autosave-spärr),
`docs/UI_GUIDE.md` §8 (pixel/krit-hybriden, två CanvasLayers),
`docs/research/04_pixelgrafik_pipeline.md` §5–6, `docs/design/COMBAT_READABILITY.md`
§1.2 och §8, `src/core/run_graph.gd`, `src/data/content.gd` (de sex relikerna),
`docs/screenshots/m2/04_combat_mid_chain.png`.

# assets/sprites – M1-spriteregister

**Ägare:** UI/UX · **Uppdaterad:** 2026-09-21 · Gäller M2 (våning 1 + juice).

Alla sprites här är 16 px-baserad pixelgrafik i `docs/UI_GUIDE.md` §2-paletten.
Varje fil har en rad i `assets/ASSET_LICENSES.csv` och CI failar annars
(`tools/check_asset_licenses.py`).

---

## 0. Hur sprites kommer till (och hur de byts ut)

| Fil | Roll |
|---|---|
| `tools/pixel_png.py` | PNG-skrivare + pixelcanvas + palett. Inget Pillow i miljön. |
| `tools/gen_pixel_assets.py` | Hjälte, fiender, ikoner, parallax |
| `tools/gen_dice_sprites.py` | Tärningar (kropp, pips, glypher, sprickor, LUT) |
| `tools/build_asset_csv.py` | Skriver om `ASSET_LICENSES.csv` från generatorerna + handtabellen |

Generatorn är källan, PNG:erna är byggresultat. Vill du ändra en sprite:
ändra kompositionen i generatorn, kör `python3 tools/gen_pixel_assets.py`
(eller `gen_dice_sprites.py`), kör sedan `python3 tools/build_asset_csv.py`.

**Ingen generativ AI har rört dessa filer.** Varje silhuett är hand­placerade
primitiver (ellips, platta, tagg, lem) med explicita koordinater – det är
skisspennan i kod, inte en bildmodell. Beslutet i `DECISIONS.md`
(2026-09-21, "AI-genererad grafik") är alltså uppfyllt: `own-work` i CSV:n.

### Status för de CC0-källor DECISIONS pekar ut

M1-beslutet var att hämta **0x72 DungeonTileset II**, **Kenney Tiny Dungeon /
1-Bit Pack** och **Pixel Frog / Szadi art**. Alla fyra värdarna avvisas av
sessionens egress-policy (HTTP 403 `connect_rejected` på `0x72.itch.io`,
`kenney.nl`, `www.kenney.nl`, `pixelfrog-assets.itch.io`, `szadiart.itch.io`,
`penusbmic.itch.io`, `kenney-assets.itch.io`, `itch.io`, `static.itch.io`,
`opengameart.org`; även `codeload.github.com` och `github.com` HTML är
blockerade). Endast `raw.githubusercontent.com` och
`media.githubusercontent.com` går igenom, och där finns bara spridda
tutorial-kopior utan egen licensfil – de importerades **inte**, eftersom CSV:n
kräver verifierbar proveniens.

**Utbytesplan när nätet öppnas:** filerna nedan har samma namn, rutnät och
cellstorlek som motsvarande 0x72/Kenney-sprites. Byt PNG, lägg in rätt rad i
`ASSET_LICENSES.csv` (`CC0-1.0` + käll-URL + hämtdatum), kör
`tools/check_asset_licenses.py`. Inget i `src/game/` behöver röras, eftersom
paperdoll-kontraktet (§2) och tärningskompositionen (§3) är oförändrade.

---

## 1. Fiender – mappning mot `src/data/content.gd`

Alla fiendeark är **`hframes = 4`, `vframes = 2`** (ändrat i M2):

| Rad | Animation | Authorade frames | Not |
|---|---|---|---|
| 0 | `default` (idle) | 4 (kol 0–3) | oförändrad från M1 |
| 1 | `death` | **3 (kol 0–2)** | kol 3 upprepar sista authorade framen |

Alla figurer **tittar åt vänster** (hjälten marscherar åt höger in i dem).

### Death-animationen (M2)

Tre slag, identiska för varje fiende – poängen är att spelaren ska kunna läsa
"den där är död" på 120 ms utan att titta:

| Frame | Beat | Vad som händer |
|---|---|---|
| 0 | `RECOIL` | kroppen klipps ihop 12 % mot golvlinjen och breddas, **ögonljuset slocknar**, dammpuff längs golvet |
| 1 | `COLLAPSE` | halv höjd, en tredjedel av kroppen upplöst (biasad mot huvudet), spillror kastas upp och ut |
| 2 | `REMAINS` | platt hög på golvlinjen + sista dammet som driver uppåt |

Frames härleds ur fiendens **egen idle-frame 0** genom omsampling, så en
omritad fiende får en matchande död gratis och silhuetten kan aldrig glida
isär. Spillrornas färg är fiendens egen mörka ramp (`DEATH_TOKENS` i
`tools/gen_pixel_assets.py`), gnistan dess semantiska accent.

"Ögonljuset slocknar" gäller bara **små kluster** (≤ 8 px) av ett
ögon-token. Flera fiender använder samma heta tokens som kroppsskuggning
(Rostråttans ljusa kant är `rust4`, Slaggkäftens ugn `rust3`/`rust5`) och att
svärta dem hade ätit silhuetten i stället för ögat.

**Vad dev behöver göra:** `Art.ENEMIES` behöver `"rows": 2` (eller
`"death_frames": 3`) och `Art.enemy_frames()` behöver lägga till animationen
`&"death"` från rad 1 med `loop = false`. `EnemyActor.death_reaction()` spelar
den då automatiskt enligt ARCHITECTURE; ingen annan kod berörs.
Föreslagen frametakt: **10 fps** (3 frames ≈ 300 ms), vilket ligger inom
`enemy_killed`-budgeten på 360 ms i UI_GUIDE §5.5.

| `content.gd`-id | Namn | Fil | Cell | Visuell tell |
|---|---|---|---|---|
| `RUST_RAT` | Rostråttan | `enemies/rust_rat.png` | 32×32 | Låg silhuett, lång svans, rostgropar. Svärmfoder. |
| `SLAG_MOTH` | Slaggmalen | `enemies/slag_moth.png` | 32×32 | Vingslag i 4 frames, **gul rullad snabel** = `DRAIN_CHARGE` |
| `THORN_IMP` | Taggimpen | `enemies/thorn_imp.png` | 32×32 | **Ryggtaggar** = `thorns 2`, röda ögon |
| `PIP_THIEF` | Ögontjuven | `enemies/pip_thief.png` | 32×32 | Huva utan ansikte + **stulen tärning i klon** = `STEAL` |
| `IRON_TICK` | Järnfästingen | `enemies/iron_tick.png` | 32×32 | Nitad pansarkupa, plåtsömmar = `armor 6`, muren |
| `GRAVE_HAND` | Gravhanden | `enemies/grave_hand.png` | 32×32 | Fem fingrar; **ytterfingrarna kröker sig** frame 2–3 = `GRAB` |
| `SLAGJAW` | Slaggkäften (boss) | `enemies/slagjaw.png` | **48×48** | Käft med ugn bakom tänderna; **ögonen slår om till eldorange på frame 2** = `HARDEN`-fönstret |

Regel: varje fiendes specialregel ska gå att se i silhuetten innan den
aktiveras. En spelare ska kunna lära sig `STEAL` av att titta, inte av att bli
bestulen.

## 2. Hjälten – Smeden (paperdoll)

Se `hero/PAPERDOLL.md` för lagerordning, relikmappning och frame-tabell.
Kontrakt: **48×48 cell, `hframes = 8`, `vframes = 4`, samma origo i alla lager.**

Namnkontrakt: `smith_<lager>_<id i gemener>.png`. 17 ark i M2.

| Fil | Lager | Alltid synlig |
|---|---|---|
|  `hero/smith_body_a.png` | `body` | ja |
| `hero/smith_cape_ember.png` | `cape` | nej (utrustning) |
| `hero/smith_helm_iron.png` | `helm` | nej (utrustning) |
| `hero/smith_legs_iron.png` | `legs` | nej (utrustning, **ny i M2**) |
| `hero/smith_weapon_hammer.png` | `weapon` | vapenvariant A |
| `hero/smith_weapon_tongs.png` | `weapon` | vapenvariant B |
| `hero/smith_fx_blood_price.png` | `fx` | `BLOOD_PRICE` primär |
| `hero/smith_torso_broken_scale.png` | `torso` | `BROKEN_SCALE` primär |
| `hero/smith_offhand_broken_scale.png` | `offhand` | `BROKEN_SCALE` reserv |
| `hero/smith_cape_octopus.png` | `cape` | `OCTOPUS` primär |
| `hero/smith_fx_octopus.png` | `fx` | `OCTOPUS` reserv |
| `hero/smith_cape_echo_mirror.png` | `cape` | `ECHO_MIRROR` primär |
| `hero/smith_torso_echo_mirror.png` | `torso` | `ECHO_MIRROR` reserv |
| `hero/smith_offhand_cheat_cube.png` | `offhand` | `CHEAT_CUBE` primär |
| `hero/smith_torso_cheat_cube.png` | `torso` | `CHEAT_CUBE` reserv |
| `hero/smith_helm_domino.png` | `helm` | `DOMINO` primär |
| `hero/smith_head_domino.png` | `head` | `DOMINO` reserv (den som tänds i praktiken) |

## 3. Tärningar – komposition, inte färdiga bilder

45 kombinationer (3 material × 15 sidmotiv) + sprickor skulle naivt bli ~90
sprites. Här är det **25 filer**.

```
Die (Node2D, scale = 5, position = heltal * 5)
 └─ Body   (Sprite2D, z = 0)  texture = dice/die_body_gray.png
 │                            material = palette_lut.gdshader
 │                            shader_parameter/lut = dice/lut_<material>.png
 ├─ Glyph  (Sprite2D, z = 1)  texture = dice/pips_<0..6>.png
 │                            ELLER  dice/glyph_<gift|eld|frost|blod|tomrum>.png
 │                            modulate = semantisk token (UI_GUIDE §2.3)
 ├─ Rim    (Sprite2D, z = 2)  texture = dice/glass_highlight.png
 │                            visible = material == GLASS, blend_mode = Add
 └─ Crack  (Sprite2D, z = 3)  texture = dice/crack_<1..3>.png
                              visible = die.cracked, variant seedad per tärning
```

* **Rullning:** `Body.texture = dice/die_tumble_gray.png` (`hframes = 6`),
  `Glyph.visible = false` under tumlingen, glyphen poppar in på landningsframen
  med 80 ms squash-tween. Animera **aldrig** glyphen (research 04 §3).
* **Ny smidbar sida i M2 = en ny `glyph_*.png`.** Inte tre sprites, inte 
  tre material­varianter.
* `pips_0.png` är en ihålig ring, inte en tom bild – `HOLLOW` och `TWIN_EYE`
  har värde 0 och ska se avsiktliga ut.

### Shaderfixen 2026-09-21: gråskala + LUT är den vägen som gäller igen

`palette_lut.gdshader` var trasig i M1/M1.5 och tvingade fram de **förtintade**
kropparna (`die_body_{iron,bone,glass}.png`). Felet är fixat och uppmätt:

| Väg | Före fixen | Efter fixen |
|---|---|---|
| `lut_strength = 0` (passthrough) | `#C2451D` → `#941303`, 14/16 svatcher fel | byte-identisk, 0/16 fel |
| `lut_strength = 1` (LUT) | `#C2451D` → `#210E07`, 15/16 fel | `#C2451D` → `#2C353F`, 0/16 fel |
| `modulate` ovanpå shadern | 14/16 fel (dubbelmultiplicerad) | 0/16 fel |

Samma siffror i **båda** renderarna (`mobile`/Vulkan och `gl_compatibility`/
OpenGL3), så DECISIONS-noten "tappar sRGB i GL Compatibility" var en
feldiagnos: den gamla raden `COLOR = vec4(rgb, a) * COLOR;` multiplicerade in
källfärgen en andra gång (kvadrering ser ut som en gammakurva). Modulate
plockas nu i vertex-steget i stället.

**Dev kan alltså gå tillbaka till gråskala + LUT för tärningskroppar.**
Det är en rad i `Art.die_body()`: byt `DIE_BODIES[material]` mot
[`DIE_BODY_GRAY`](../../src/game/ui/art.gd) och sätt
`Art.palette_material(Art.die_lut(material), 1.0)` på `Body`-noden.
Då fungerar även `lut_strength`-tweenen vid materialbyte (UI_GUIDE §9.2),
som är hela poängen med att kroppen är gråskala. De förtintade kropparna
behålls för HTML-mockupen och editorförhandsvisningen.

**Regressionstest:** `design/shader_probe.tscn` + `tools/shader_probe.gd`
renderar en 16-färgers ramp till en `SubViewport` och läser tillbaka pixlarna.
Exit 0 = alla rader stämmer.

```
xvfb-run -a godot --path . design/shader_probe.tscn --rendering-method mobile
xvfb-run -a godot --path . design/shader_probe.tscn --rendering-driver opengl3 \
    --rendering-method gl_compatibility
```

| Fil | Innehåll |
|---|---|
| `dice/die_body_gray.png` | Gråskalemaster 32×32. Körs genom `palette_lut.gdshader`. **Standardvägen igen efter shaderfixen.** |
| `dice/die_body_{iron,bone,glass}.png` | Förtintade kroppar (HTML-mockup, editorförhandsvisning) |
| `dice/die_tumble_gray.png` | 192×32, 6 frames, tom kropp |
| `dice/lut_{iron,bone,glass}.png` | 16×1 palett-LUT per material (`Rules.DieMaterial`) |
| `dice/lut_world.png` | 16×1 LUT som tvingar **importerade** sprites till paletten |
| `dice/pips_0..6.png` | Pip-overlay, värde 0–6 (`PIP_1`…`PIP_6`, `CRACKED`=0) |
| `dice/glyph_gift.png` | `POISON_DROP` (Giftdroppe) – droppe, `sem/poison` |
| `dice/glyph_eld.png` | `EMBER` (Glöd) – triangel, `sem/fire` |
| `dice/glyph_frost.png` | Frost-sidor (M2) – romb, `sem/frost` |
| `dice/glyph_blod.png` | `VAMP_FANG` (Vampyrtand) – halvcirkel, `sem/blood` |
| `dice/glyph_tomrum.png` | `HOLLOW` / `VOID`-sidor – kryssad kvadrat, `sem/shield` |
| `dice/crack_1..3.png` | Sprickoverlay, tre mönster |
| `dice/glass_highlight.png` | Additiv glaskant |

Sidor som inte har egen glyph i M1 (`SNOWBALL`, `TWIN_EYE`, `HAMMER_FACE`,
`LEAD_SIX`) ritas som pip-overlay för sitt värde plus krit-UI-badge tills
M2 ger dem varsin glyph. Det är ett medvetet val: glyphar är billiga men
läsbarheten på 32 px tål bara en form åt gången.

## 4. Ikoner

| Fil | `content.gd`-id | Not |
|---|---|---|
| `items/relic_blood_price.png` | `BLOOD_PRICE` | droppe, lager `fx` |
| `items/relic_broken_scale.png` | `BROKEN_SCALE` | kluven våg, lager `offhand` |
| `items/relic_octopus.png` | `OCTOPUS` | armar som når slot 1↔3, lager `cape` |
| `items/relic_echo_mirror.png` | `ECHO_MIRROR` | spegel + skärva, lager `cape` |
| `items/relic_cheat_cube.png` | `CHEAT_CUBE` | tärning med samma sida två gånger, lager `offhand` |
| `items/relic_domino.png` | `DOMINO` | bricka i fall, lager `head` |
| `ui/slot_{plain,fire,mirror,anvil,charge,void}.png` | `Rules.SlotType` | formkoder enligt UI_GUIDE §2.4 |
| `ui/node_{combat,elite,forge,rest,boss,mystery}.png` | marschens förgreningar | 16×16 + ram ritas i krita |
| `ui/icon_armor.png` | fiendens `armor` | 16×16, sköld. Ersätter `⬟` som betyder Ward |
| `ui/icon_attack.png` | intent `ATTACK` | 16×16, svärd som pekar mot spelaren |
| `ui/icon_help.png` | `?`-lagret (COMBAT_READABILITY §6) | 16×16, gul |
| `ui/icon_charge.png` | Laddning i HUD | 16×16, bank som fylls. `slot_charge.png` betyder *sloten*, den här *banken* |
| `ui/icon_overflow.png` | spill/överflöd | 16×16, knäpil höger–ned |
| `ui/icon_tutorial_pointer.png` | tutorialvåning 0 | 16×16 kritpil, pekar NED vid 0°, roteras i 90°-steg |

## 5. Miljö (marschremsan, våning 1)

| Fil | Storlek | Parallaxhastighet |
|---|---|---|
| `env/floor1_parallax_far.png` | 320×120, kaklingsbar | **0,15** |
| `env/floor1_parallax_mid.png` | 320×120, kaklingsbar | **0,45** |
| `env/floor1_parallax_near.png` | 320×64, kaklingsbar | **1,20** |
| `env/floor1_tile.png` | 32×32, kaklingsbar | 1,00 (golvet) |

`ParallaxBackground` + tre `ParallaxLayer` med `motion_mirroring = (320*ART_SCALE, 0)`.
Se `docs/UI_GUIDE.md` §10 för remsans höjd i portrait.

---

## 6. Godot-importinställningar för pixelsprites

Enligt research 04 §5. Gäller **allt** under `assets/sprites/`.

```ini
[remap]
importer="texture"
type="CompressedTexture2D"

[params]
compress/mode=0              ; Lossless. ALDRIG VRAM Compressed/ETC2 -
                             ; blockkomprimering förstör hårda pixelkanter.
compress/high_quality=false
compress/lossy_quality=0.7
compress/hdr_compression=0
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false       ; ingen mipmap: skapar suddiga pixlar vid skalning
mipmaps/limit=-1
roughness/mode=0
process/fix_alpha_border=true    ; annars mörk halo runt transparenta kanter
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0      ; hindra Godot från att auto-byta till VRAM
```

Filter och repeat sätts **inte** per fil utan ärvs från noden:

* `project.godot` → `rendering/textures/canvas_textures/default_texture_filter = 0` (Nearest)
* `CanvasLayer "World"` → `texture_filter = TEXTURE_FILTER_NEAREST` (ärvs nedåt)
* `CanvasLayer "ChalkUI"` → `texture_filter = TEXTURE_FILTER_LINEAR`

**Skala:** tärningar 32 px i ×5 = 160 px (6 st = 960 px + marginal på 1080).
Karaktärsceller 48 px i ×4 = 192 px. Positionera alltid i heltalsmultiplar av
`ART_SCALE`; de globala `snap_2d_*`-flaggorna snappar mot viewportpixlar och
hjälper inte (research 04 §5).

Ett `.import`-block enligt ovan finns i `assets/sprites/pixel_default.import.txt`
som klipp-och-klistra-mall. Godot genererar riktiga `.import`-filer vid
`godot --headless --import`.

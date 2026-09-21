# 04 – Pixelgrafik-pipeline: assets, licenser, paperdoll, tärningar, AI och Godot-setup

**Ägare:** rnd-roguelike · **Datum:** 2026-09-21 · **Status:** underlag till PM
Källor `[n]` med URL + hämtdatum sist. **Fakta** = källbelagt. **Uppskattning** = egen bedömning. **Branschkonsensus** = vanlig praxis utan enskild auktoritativ källa.

---

## Fråga
Hur får en solo-dev utan grafiker markant bättre grafik i PIPWRECK – pixelgrafik för karaktär, monster och tärningar med *synlig utrustning* (paperdoll) – utan licensfällor, utan att spräcka tidsbudgeten, och utan att krit-UI:t (riktning A) blir suddigt i samma viewport?

## Slutsats (först)

1. **Licensregel: bara CC0, OGA-BY, CC-BY 4.0 eller köpt royalty-free.** CC-BY-SA och GPL förbjuds hårt i projektet. Det diskvalificerar **Universal LPC Spritesheet Generator som helhet** – LPC:s lager är split-licensierade (CC0 / CC-BY / CC-BY-SA 3.0+4.0 / OGA-BY / GPL 3.0), och LPC:s egen README varnar uttryckligen för att CC-BY-SA är tvetydig på DRM-plattformar som Steam och iOS App Store och rekommenderar CC0 eller OGA-BY där [1]. Att filtrera generatorn lager-för-lager är möjligt men ger ett sönderplockat urval och en pågående compliance-skuld i varje uppdatering. **LPC används inte.**
2. **Bas för M1: 0x72 DungeonTileset II (CC0) + Kenney (CC0) + Pixel Frog (CC0).** Noll attribution, noll juridisk risk, noll kostnad. Kompletteras vid behov med **Oryx Ultimate Fantasy** (köpt kommersiell licens, ≈25 USD Mega Pack, kräver credit till oryxdesignlab.com) [2] om vi behöver fler unika monster i enhetlig stil.
3. **Paperdoll: flera `Sprite2D` med delat `hframes/vframes`-rutnät, drivna av *en* `AnimationPlayer` på föräldern via en `frame_index`-setter.** Inte flera `AnimatedSprite2D` (de desynkar), inte shader-masker (bryter silhuetten när vapen sticker ut), inte Skeleton2D/cutout (rotation förstör pixelrutnätet).
4. **Tärningar komponeras, ritas inte ut.** Naivt behövs ~90 sprites (15 sidmotiv × 3 material × spricka). Med kropp + glyph-overlay + palett-tint blir det **20 filer**. Rulla inte animerade sidmotiv – tumla en tom kropp och poppa in glyphen på sista framen.
5. **AI-pixelgrafik: ja som skisshjälp och för härledda vinklar av *egna* sprites, nej som slutgiltig karaktärsart.** 62,7 % av 1,75 M spelare i Quantic Foundry-undersökningen är negativa till generativ AI i spel [3], och Steam kräver deklaration (20,9 % av 2025 års släpp deklarerade AI) [3][4]. Ett litet indiespel har inget att vinna på den stridsfrågan.
6. **Viewport: `canvas_items` på 1080×1920, INTE integer scale mode.** Pixelsprites läggs på egen `CanvasLayer` med `texture_filter = Nearest` och exakt heltalsskala ×4; krit-UI ligger på en annan `CanvasLayer` med `Linear` och behåller mjuka kurvor. Integer scale mode skulle tvinga ned hela krit-UI:t i lågupplösning – fel för ett hybridprojekt.

---

## 1. Asset-källor med licens

| Källa | Vad som ingår | Upplösning | Licens | Pris | Kommersiellt i betald mobilapp? | Attribution |
|---|---|---|---|---|---|---|
| **0x72 DungeonTileset II** [5] | Animerade hjältar (4 st), ~20 monster, vapen som separata sprites, kistor, miljötiles, dekor | 16×16 (vapen/stora fiender upp till 32×32) | **CC0** | Gratis (pay-what-you-want) | **Ja** | Nej |
| **Kenney – Tiny Dungeon (130 assets), 1-Bit Pack (1078 assets), Micro Roguelike** [6][7] | Tiles, vapen, items, karaktärer, UI-ikoner | 16×16 (1-bit: 16×16) | **CC0** | Gratis | **Ja** | Nej |
| **Pixel Frog – Pixel Adventure, Kings & Pigs** [8] | Sidovy-karaktärer med gång-/hopp-/attackcykler, fiender, tilesets, bakgrunder | 32×32 | **CC0** | Gratis (PWYW) | **Ja** | Nej |
| **Szadi art** [9] | Sidovy-tilesets, parallaxbakgrunder (skog, grotta, ruiner), props | 16/32 px | Egen licens: kommersiellt OK, modifiering OK, försäljning av verk OK | Gratis + betalda pack | **Ja** | **Nej** ("appreciated") |
| **Penusbmic – Sci-fi/Dark Series Character Packs** [10] | Animerade fiender och bossar i sidovy (idle/run/attack/death), 1 gratis karaktär per pack | 32–48 px, "low-res" | Fri för kommersiellt bruk, **får ej säljas vidare som asset** | ~3–8 USD/pack | **Ja** | Ombeds, ej krav |
| **Elthen (Ahmet Avci)** [11] | Animerade karaktärer/monster, sidovy + top-down, hög kvalitet | 32–64 px | *Elthen's Common Sense License 1.0* (fr.o.m. 2025-11-01): kommersiellt OK, **ingen** vidareförsäljning, **förbud mot blockchain/NFT och mot LLM/AI-träning** | Patreon ~5–15 USD/mån, itch-pack | **Ja** | Ej krav |
| **Oryx Design Lab – Ultimate Fantasy / Mega Pack** [2] | Komplett enhetlig värld: hjältar, ~hundratals monster, utrustning, tiles, UI | 16/24/32 px | Kommersiell, icke-exklusiv, royalty-free, **ej överlåtbar**, får ej återpubliceras som art | ≈25 USD (Mega Pack, livstidsuppdateringar) | **Ja** | **Ja** – "www.oryxdesignlab.com" i spelet eller dokumentationen |
| **Anokolisa** | Sidovy-tilesets, parallax, "Legacy"-serien | 16/32 px | **Ej verifierad** – varje pack har egen readme | Gratis + betalt | Kontrolleras per pack | Kontrolleras per pack |
| **OpenGameArt** | Blandat | Blandat | **Blandat per inlägg**: CC0, CC-BY, CC-BY-SA, GPL, OGA-BY | Gratis | Endast CC0/CC-BY/OGA-BY-poster | Varierar |
| **Universal LPC Spritesheet Generator** [1] | Kropp, hår, **rustning, hjälm, sköld, vapen som separata lager** – exakt paperdoll-funktionen vi vill ha. Animationer: walk, slash, thrust, spellcast, shoot, hurt, inkl. oversize-frames för stora vapen | **64×64** (oversize-frames större) | **Split**: CC0 / CC-BY 4.0 / CC-BY-SA 3.0 & 4.0 / OGA-BY / GPL 3.0 – *per lager* | Gratis | **Ja, men villkorat** – se riskflagga | **Ja**: CREDITS.csv eller egen creditlista måste vara **nåbar inifrån appen** |

### Riskflagga: CC-BY-SA och GPL i en proprietär app

- **CC-BY-SA:s ShareAlike smittar det modifierade *konstverket*, inte spelkoden.** Recolor, ompaketering till atlas eller omritad frame = *Adapted Material* ⇒ måste släppas under CC-BY-SA. För ett spel där paperdoll-lagren *är* kärnvärdet betyder det att vi måste publicera våra egna spritesheets fritt. (Branschkonsensus; juridiskt oprövat i spelkontext.)
- **CC:s anti-DRM/TPM-klausul.** Creative Commons står fast vid att DRM/TPM inte får användas för att begränsa det licensen tillåter [12]. App Store-distribution är FairPlay-DRM. LPC:s egen dokumentation erkänner tvetydigheten och rekommenderar CC0/OGA-BY för Steam och iOS [1]. **OGA-BY finns just för att lösa detta** – den tillåter uttryckligen DRM-skyddade spel [1].
- **GPL 3.0 på grafik** är värst: den strikta läsningen kräver att verk som distribueras tillsammans som ett samlat program släpps under GPL. Oprövat för assets, men **risken är asymmetrisk** – vi vinner ingenting på att ta den.
- **Fit-problem oavsett licens:** LPC är 4-riktad 3/4-top-down. Bara east/west-raderna duger i en sidoscrollande marsch, och 3/4-perspektivet läser fel mot platta parallaxlager. **Uppskattning:** vi kastar 50–75 % av arket och får ändå fel vinkel.

---

## 2. Paperdoll i Godot 4

**Tre alternativ, vägda:**

| Metod | För | Emot | Dom |
|---|---|---|---|
| N× `AnimatedSprite2D` i z-ordning | Enklast att sätta upp | Varje nod har **egen** frame-räknare och `frame_progress`; byter man utrustning mitt i en animation startar det nya lagret på frame 0 ⇒ synlig desync. Kräver manuell `set_frame_and_progress()` varje gång | Nej |
| En `Sprite2D` + shader-masker / kanalindexerad atlas | 1 draw call, snabbt | Kan inte ändra **silhuetten** – ett svärd, en kappa eller en hjälmfjäder som sticker utanför kroppens bounding box går inte att rita. Alla varianter måste ligga i samma atlas ⇒ ny utrustning = ny atlas-export | Nej |
| `Skeleton2D` / cutout med `Polygon2D` | Procedurell utrustning, få bilder | Rotation ger icke-heltalsvinklar ⇒ pixelrutnätet vrids och "kryper". Är i praktiken oförenligt med krispiga sprites | Nej |
| **`Sprite2D` per lager + en `AnimationPlayer` på föräldern** | Delat rutnät ⇒ ingen desync per konstruktion. `AnimationPlayer` ger **Call Method-spår på exakt frame** – passar arkitekturen där UI spelar upp en händelselogg på en överlappande tidslinje (DECISIONS 2026-09-21). Utrustningsbyte kan ske mitt i en animation utan artefakt | Alla lagerark måste dela exakt samma rutnät och frame-ordning (ett "kontrakt") | **Ja** |

**Kontrakt för alla lagerark:** samma cellstorlek (48×48 inkl. oversize-marginal), samma `hframes × vframes`, samma frame-ordning, samma origo. Bryts kontraktet ska importen misslyckas, inte se konstig ut.

```gdscript
# src/game/visual/paperdoll.gd
class_name Paperdoll
extends Node2D

const HFRAMES: int = 8
const VFRAMES: int = 4
const LAYERS: Array[StringName] = [&"cape", &"body", &"armor", &"head", &"offhand", &"weapon", &"fx"]

## Enda sanningskällan för vilken frame alla lager visar.
## AnimationPlayer animerar DENNA property, aldrig lagrens egna.
@export var frame_index: int = 0:
	set(value):
		frame_index = value
		for s: Sprite2D in _sprites:
			s.frame = value

@onready var _anim: AnimationPlayer = $AnimationPlayer
var _sprites: Array[Sprite2D] = []

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # ärvs av alla barn
	for layer_name: StringName in LAYERS:
		var s := get_node_or_null(NodePath(String(layer_name))) as Sprite2D
		if s == null:
			continue
		s.hframes = HFRAMES
		s.vframes = VFRAMES
		s.centered = true
		_sprites.append(s)

## Utrustningsbyte: nya lagret hoppar direkt in på rätt frame, ingen desync.
func equip(layer_name: StringName, tex: Texture2D) -> void:
	var s := get_node(NodePath(String(layer_name))) as Sprite2D
	s.texture = tex
	s.visible = tex != null
	s.frame = frame_index

func play(anim: StringName) -> void:
	_anim.play(anim)   # spåren sätter bara "frame_index"
```

Kostnad: 7 lager × max 4 aktörer på skärmen = 28 draw calls. **Uppskattning:** försumbart även på armv7 – Godots 2D-batchning slår ändå ihop dem per textur, och vi är långt under de ~200 draw calls där mid-range Android börjar svettas.

Reliker som ska synas (GAME_DESIGN §4.6) mappas till lager: `BLOOD_PRICE` → `fx` (droppande rött), `BROKEN_SCALE` → `offhand` (kluven våg), `ECHO_MIRROR` → `cape` (spegelskärvor), `CHEAT_CUBE` → `offhand`, `DOMINO` → `head`, `OCTOPUS` → `cape`. Sex reliker = **sex sprites**, inte sex animationer.

---

## 3. Tärningar som pixelgrafik

**Naiv kostnad:** 15 sidmotiv (PIP_1…6, CRACKED, plus 8 smidbara sidor) × 3 material (järn/ben/glas) × 2 (hel/sprucken) = **90 sprites**. Med rullanimation × 8 frames = 720. Orimligt.

**Komponerad kostnad – 20 filer:**

| Del | Antal | Hur |
|---|---|---|
| Tärningskropp, gråskala, 32×32 | 1 | Målas av palett-LUT-shader per material |
| Materialpaletter (järn, ben, glas) | 3 | 4×N px PNG, LUT-textur (`KoBeWi/Godot-Palette-Swap-Shader`-mönstret [13]) |
| Sidglypher, 1-bit alpha, i ett ark | 15 (1 fil) | `AtlasTexture` ur ett 8×2-ark; färgas med `modulate` = semantisk token (`chalk/gift #B77FFF`, `eld #FF6A2C`, `frost #6ED2F5`, blod, tomrum) |
| Sprickoverlay | 3 | Tre slumpvalda sprickmönster ovanpå vilken kropp som helst |
| Glaskant/highlight | 1 | Additiv overlay endast för glastärning |
| Tumla-frames (tom kropp) | 6 | Återanvänds av *alla* 45 kombinationer |

Nodstruktur: `Die (Sprite2D, kropp + ShaderMaterial{palette_lut}) → Glyph (Sprite2D, AtlasTexture, modulate) → Crack (Sprite2D, visible=false)`.

**Rullanimationen:** animera aldrig glyphen. Kroppen tumlar 6 frames med `Glyph.visible = false`, sedan poppar rätt glyph in på landningsframen med en 80 ms squash-tween. Det är samma trick Balatro använder på kort (interiören är statisk, kortet rör sig) och det sparar ~90 % av frames. **Uppskattning:** hela tärningspaketet = 2–3 arbetsdagar inkl. shader.

Detta bygger dessutom in nya sidor gratis: en ny smidbar sida i M2 är **en glyph**, inte tre sprites.

---

## 4. AI-assisterad pixelgrafik 2025–2026

**Verktyg och licensvillkor (fakta):**

| Verktyg | Vad den gör | Output-licens |
|---|---|---|
| **PixelLab** [14] | Webb + **Aseprite-plugin** och MCP-server. Skelettstyrd animation, riktningsvyer från en referenssprite, konsistensverktyg baserat på referensbild. ~9 USD/mån tier 1, ~22 USD tier 2 | **Du äger outputen**, fri kommersiell användning, enda undantaget: får ej användas för att träna andra modeller |
| **Retro Diffusion** [15] | Text-till-pixelart, palettkontroll, batch. ~0,015 USD/bild, 50 gratis credits | Kommersiella rättigheter ingår i **betalda** planer; "allt du genererar är ditt" |
| **Aseprite + plugins** | PixelLab-pluginen är den mest mogna; ren Aseprite förblir det som faktiskt gör assets shippbara | – |

**Kvalitet (uppskattning, baserat på verktygens egen dokumentation och testrapporter [16]):** enskilda stillbilder är idag bra. **Konsistens över en hel gångcykel och över 6 fiender i samma stil är fortfarande svag punkt** – skelettstyrd animation i PixelLab producerar användbara *mellanframes* men kräver städning i Aseprite. För paperdoll är det värre: lagren måste dela pixelrutnät och silhuett exakt, och det gör ingen generator pålitligt.

**Community och plattform (fakta):**
- Steam kräver AI-deklaration; **20,9 % av 2025 års Steam-släpp deklarerade AI**, ~19,5 % av Next Fest-demos [3][4].
- Quantic Foundry, >1,75 M spelare: **62,7 % mycket negativa** till generativ AI i spel [3]. En annan undersökning (≈1 800 spelare, Q4 2025): 85 % under neutral, 63 % valde mest negativa alternativet – **men 68,6 % säger sig ändå köpa ett spel med deklaration** [4].
- Konkreta backlash-fall 2025–2026: Project Zomboid (menyart), Call of Duty: Black Ops 6 (laddningsskärm), Clair Obscur (diskvalificerad från Indie Game Awards 2025 för några affischer), Larian (backade om AI-konceptart) [17].
- Google Play och App Store kräver **inte** AI-deklaration för grafik (per 2026-09-21). Risken är renommé, inte butiksavslag.

**Ärlig rekommendation:** **Skisshjälp ja, slutliga assets nej.**
- **Gör:** använd PixelLab/Retro Diffusion för kompositionsmockups, färgprover, och för att generera *härledda vinklar/mellanframes av en sprite vi redan äger* (CC0-bas eller egenritad). Städa alltid i Aseprite. Detta lämnar inga spårbara AI-artefakter.
- **Gör inte:** skeppa rå genererad karaktärsart. Clair Obscur-fallet visar att **"några affischer" räckte** för diskvalificering. Vårt spel siktar dessutom på en community (r/roguelikes, r/roguelites) som research 03 redan visat är ovanligt känslig för att bli "lurad".
- **Juridisk osäkerhet:** rent AI-genererat material har tveksamt upphovsrättsskydd i USA, vilket innebär att vi i praktiken inte kan stoppa en asset-flippare som kopierar våra sprites. Handritat/handstädat material har det. (Branschkonsensus, ej källbelagt här.)
- **Om vi någonsin lägger PIPWRECK på Steam:** kryssa deklarationsrutan om AI rört slutassets. Att inte göra det är den enda garanterat katastrofala utgången.

---

## 5. Godot-importinställningar och viewport för pixel + krit-UI i samma skärm

**Projektinställningar (Godot 4.6):**

```
display/window/size/viewport_width  = 1080
display/window/size/viewport_height = 1920
display/window/stretch/mode         = canvas_items     # INTE viewport, INTE integer
display/window/stretch/aspect       = expand
display/window/stretch/scale_mode   = fractional       # integer skulle låsa hela UI:t
rendering/textures/canvas_textures/default_texture_filter = Nearest
rendering/2d/snap/snap_2d_transforms_to_pixel = false  # se not nedan
rendering/2d/snap/snap_2d_vertices_to_pixel   = false
```

**Varför INTE integer scale mode:** integer scale kräver en låg basupplösning (t.ex. 360×640) och skalar allt med heltal. Då renderas krit-shadern, kritstrecken (`Line2D`) och Anton-siffrorna i 360 px bredd och skalas upp ⇒ krit-UI:t blir kantigt och tappar exakt den handdragna mjukheten som *är* riktning A. **Fel kompromiss för ett hybridprojekt.**

**Rätt lösning – två CanvasLayers, olika filter:**
- `CanvasLayer "World"` (layer 0): `texture_filter = TEXTURE_FILTER_NEAREST`. Pixelsprites läggs här. Filtret **ärvs nedåt** till alla barn via `CanvasItem.texture_filter = Inherit` [18], så det räcker att sätta det på rotnoden.
- `CanvasLayer "ChalkUI"` (layer 10): `texture_filter = TEXTURE_FILTER_LINEAR`. Krit-shader, `Line2D`, partiklar, fonter. Mjuka kanter behålls.

**Skala och snapping:** 32 px-sprites visas i **exakt ×4** (128 px) eller ×5 (160 px) på 1080-viewporten. Sex tärningar i en rad: 6 × 160 = 960 px + marginaler ⇒ **32 px-tärning i ×5 passar 1080 portrait perfekt**. Karaktärer (48 px-celler) i ×4 = 192 px hög figur – läsbar med utrustningsdetaljer i handen.

De globala `snap_2d_*`-flaggorna snappar till *viewport*-pixel (1080-rutnätet), inte till konstrutnätet. Med ×5 betyder ett steg på 1 viewportpixel 1/5 konstpixel ⇒ kantkrypning ändå. **Snappa i stället i kod:**

```gdscript
const ART_SCALE: int = 5

func place_pixel_node(n: Node2D, art_pos: Vector2i) -> void:
	n.scale = Vector2(ART_SCALE, ART_SCALE)
	n.position = Vector2(art_pos * ART_SCALE)   # alltid heltalsmultipel
```

Kameror/tweens på pixelnoder måste också kvantiseras till `ART_SCALE`; annars får vi shimmer under sidoscroll-marschen.

**Importinställningar per sprite (spara som standardpreset för 2D-textur):**
`Filter: Nearest` · `Mipmaps: Off` · `Repeat: Disabled` · `Fix Alpha Border: On` (annars mörk halo runt transparent kant) · `Compress Mode: Lossless` – **aldrig VRAM Compressed/ETC2**, blockkomprimering förstör hårda pixelkanter. Prisbilden: **uppskattning** ~1,5–3 MB extra APK för hela M1-assetmängden – acceptabelt.

---

## 6. Sidescroll-marsch mellan rum

**Referenser (vad vi lånar, inte kopierar):**
- **Darkest Dungeon** – korridor i sidovy, fast kamera, partiet marscherar vänster→höger mellan rum; korridorer är 1–8 tiles långa och varje tile är en "runda" [19]. Lånas: *korridoren som pacing-verktyg mellan strider, inte som utforskning.*
- **Loop Hero** – hjälten går helt automatiskt, spelaren har noll rörelseinput. Lånas: **ingen joystick** – vi behåller en-tumme-kravet (DECISIONS: fri gång avråds).
- **Kingdom: Two Crowns** – en rörelseaxel, silhuettbaserade parallaxlager. Lånas: *silhuettdjup snarare än detaljrikedom*, vilket är exakt vad krit-estetiken redan gör.

**Minimum som faktiskt behövs:**
1. Gångcykel 8 frames + idle 4 frames + "stanna/ankomst" 4 frames, i paperdoll-rutnätet (alla utrustningslager ärver detta gratis).
2. **2–3 parallaxlager per våning**: fjärran silhuett (hastighet 0,15), mitt struktur (0,45), nära förgrund (1,2). `ParallaxBackground` + `ParallaxLayer` med `motion_mirroring` – varje lager är **en** horisontellt kaklingsbar bild.
3. Golvremsa (tileable, 1 tile per våning).
4. Förgreningsikoner: `COMBAT`, `ELITE`, `FORGE`, `REST`, `BOSS`, `MYSTERY` = 6 ikoner à 32×32 + en vald/ovald-ram. Förgrening = figuren stannar, två vägar ritas ut i krita (befintlig `Line2D`-teknik), spelaren tappar en.

**Uppskattad assetmängd, 3 våningar (uppskattning):**

| Post | Antal | Källa |
|---|---|---|
| Parallaxbilder (3 lager × 3 våningar) | 9 | Szadi art / Anokolisa (CC0-verifierat) eller tintade CC0-tiles |
| Golv-tiles | 3 | 0x72 / Kenney |
| Prop-sprites (fackla, vrak, ben, ånga) | 9–12 | 0x72 (CC0) |
| Nodikoner + ram | 7 | Kenney 1-Bit / egenritat |
| Hjälte gång/idle/stopp | 0 nya | Ingår i paperdoll |
| Fiende-idle för 6 fiender + SLAGJAW | 7 | 0x72 + Penusbmic |
| **Summa nya bildfiler** | **≈37** | |

**Uppskattad tid (solo, med AI-agentstöd):** parallaxrigg 1 dag · paperdoll-system + kontrakt 2 dagar · tärningskomponering + shader 2–3 dagar · assetkurering, omfärgning och atlasexport 3–4 dagar · Godot-pixelsetup och krit-UI-samexistens 1 dag ⇒ **9–11 arbetsdagar för M1:s grafikpipeline.**

---

## Osäkerhet

- **CC-BY-SA på DRM-plattformar är juridiskt oprövat.** LPC:s README erkänner tvetydigheten [1]; ingen dom finns. Vår regel är medvetet strängare än vad lagen kanske kräver, eftersom kostnaden att undvika CC-BY-SA är nära noll när CC0-alternativ finns.
- **Oryx-priset (≈25 USD) kommer från sökresultat, inte från hämtad prislista** – oryxdesignlab.com gick inte att hämta via proxyn 2026-09-21. Verifiera före köp.
- **Anokolisas licensvillkor är inte verifierade.** Får inte användas förrän varje packs readme lästs.
- **Draw-call- och batteripåverkan av 7 paperdoll-lager är uppskattad, inte mätt.** Mät på referenstelefonen innan M2.
- Spelarattityd till AI mäts olika i olika undersökningar (62,7 % "mycket negativa" [3] vs 68,6 % "köper ändå" [4]) – **uttryckt attityd och köpbeteende skiljer sig**. Vår rekommendation bygger därför på renomméskyddet, inte på förväntad försäljningsförlust.

---

## Rekommendation till PM

1. **Anta "PIPWRECK-licensregeln" som bindande beslut:** endast **CC0, OGA-BY, CC-BY 4.0 eller köpt royalty-free** får in i repot. **CC-BY-SA (alla versioner) och GPL är förbjudna.** Varje asset loggas i `assets/ASSET_LICENSES.csv` (fil, käll-URL, upphovsperson, licens, hämtdatum, attributionstext) och ett CI-steg failar bygget om en fil saknar rad. En "Credits"-skärm byggs i M2 för CC-BY/Oryx-attribution.
2. **Stryk Universal LPC Spritesheet Generator.** Den löser paperdoll-problemet tekniskt men kostar oss split-licenser, en CREDITS.csv-plikt inifrån appen, DRM-tvetydighet på App Store, och fel perspektiv (3/4 top-down i en sidoscroll). Beslutet bör skrivas in i DECISIONS.md.
3. **M1-assetlista (allt CC0, 0 kr, ingen attribution):** hjältebas + 6 fiender + SLAGJAW från **0x72 DungeonTileset II**; utrustnings- och reliksprites från **Kenney Tiny Dungeon/1-Bit**; sidovy-gångcykel och parallaxbas från **Pixel Frog** och **Szadi art**; tärningar, sidglypher och sprickor ritas själva i Aseprite (~20 filer). **M2:** överväg **Oryx Mega Pack (≈25 USD)** om stilenhetligheten mellan 0x72 och Kenney skaver – då byts hela monsteruppsättningen på en gång, aldrig halvvägs.
4. **Bygg paperdoll som `Sprite2D`-lager under en `AnimationPlayer` med en `frame_index`-setter**, med ett hårt rutnätskontrakt (48×48, 8×4 frames) och ett gdUnit4-test som failar om ett lagerark bryter kontraktet. Tärningar komponeras (kropp + glyph + palett-LUT + spricka), aldrig ritas per kombination.
5. **AI: skisshjälp och mellanframes av egna sprites, aldrig råa slutassets.** Om något AI-rört material någonsin hamnar i slutbygget ska Steam-deklarationen kryssas. Kostnaden att avstå är låg (PixelLab ~9 USD/mån används ändå i skissläget), risken att inte avstå är hela communityns förtroende – och vi säljer just till den community som research 03 visade är mest känslig.

**Grafikpipeline för M1: 9–11 arbetsdagar (uppskattning).** Största enskilda risken är inte tid utan att stilspret mellan tre CC0-källor gör spelet ihopplockat; mitigering är en obligatorisk gemensam palett (UI_GUIDE §2.2) som alla importerade sprites tvångsomfärgas till via palett-LUT-shadern – samma shader som tärningsmaterialen redan behöver.

---

## Källor (alla hämtade 2026-09-21)

1. Universal LPC Spritesheet Character Generator, README (licenser CC0/CC-BY/CC-BY-SA/OGA-BY/GPL-3.0, CREDITS.csv-krav, DRM-varning för Steam/iOS, 64×64, animationer walk/slash/thrust/spellcast/shoot/hurt + oversize-frames) – https://github.com/liberatedpixelcup/Universal-LPC-Spritesheet-Character-Generator/blob/master/README.md · generator: https://liberatedpixelcup.github.io/Universal-LPC-Spritesheet-Character-Generator/
2. Oryx Design Lab, Licensing Information – https://www.oryxdesignlab.com/license · https://www.oryxdesignlab.com/ultimatefantasy
3. The Conversation, "Are video game developers using AI? Players want to know, but the rules are patchy" (20,9 % av 2025 års Steam-släpp deklarerade AI; Quantic Foundry 1,75 M spelare, 62,7 % mycket negativa) – https://theconversation.com/are-video-game-developers-using-ai-players-want-to-know-but-the-rules-are-patchy-274850
4. Engadget, "Around a fifth of Steam Next Fest demos have a generative AI disclosure" (1 704 av 8 700 = 19,5 %) – https://www.engadget.com/2195840/around-a-fifth-of-steam-next-fest-demos-have-a-generative-ai-disclosure/ · XDA, "68.6% of Steam users disagree" – https://www.xda-developers.com/dislike-ai-content-in-your-games-68-of-steam-users-disagree-with-you-says-survey/
5. 0x72, "16x16 DungeonTileset II" (CC0) – https://0x72.itch.io/dungeontileset-ii
6. Kenney, "Tiny Dungeon" (130 assets, CC0) – https://kenney.nl/assets/tiny-dungeon
7. Kenney, "1-Bit Pack" (1078 assets, CC0) – https://kenney.nl/assets/1-bit-pack · "Micro Roguelike" – https://kenney-assets.itch.io/micro-roguelike
8. Pixel Frog, "Pixel Adventure" (CC0) – https://pixelfrog-assets.itch.io/pixel-adventure-1 · profil: https://pixelfrog-assets.itch.io/
9. Szadi art, itch.io-profil och licensvillkor – https://szadiart.itch.io/
10. Penusbmic, Sci-fi Character Packs – https://penusbmic.itch.io/ · t.ex. https://penusbmic.itch.io/sci-fi-character-pack-12
11. Elthen, "Licensing" (Common Sense License 1.0, gäller köp fr.o.m. 2025-11-01) – https://www.patreon.com/elthen/posts/licensing-27430241 · https://elthen.itch.io/
12. Creative Commons, "We're Against Digital Rights Management. Here's Why." (2020-12-04) – https://creativecommons.org/2020/12/04/were-against-digital-rights-management-heres-why/
13. KoBeWi, Godot Palette Swap Shader (LUT-baserad, animationsstöd) – https://github.com/KoBeWi/Godot-Palette-Swap-Shader · Asset Library: https://godotengine.org/asset-library/asset/1444
14. PixelLab, Terms of Service (output ägs av användaren, kommersiellt OK, ej modellträning) – https://www.pixellab.ai/termsofservice · produkt: https://www.pixellab.ai/ · MCP: https://github.com/pixellab-code/pixellab-mcp
15. Retro Diffusion, Terms – https://www.retrodiffusion.ai/terms · https://retrodiffusion.ai/
16. Sprite-AI, "Best pixel art generators 2026, tested for game devs" – https://www.sprite-ai.art/blog/best-pixel-art-generators-2026
17. Creative Bloq, "How should game developers respond to AI art accusations?" (Project Zomboid, Clair Obscur, Larian) – https://www.creativebloq.com/3d/video-game-design/how-should-game-developers-respond-to-ai-art-accusations · GameRant – https://gamerant.com/ai-game-developer-interview/
18. Godot Engine docs, CanvasItem – `texture_filter` (Inherit/Nearest/Linear, ärvs nedåt; projektstandard i Rendering → Textures → Canvas Textures → Default Texture Filter) – https://docs.godotengine.org/en/stable/classes/class_canvasitem.html · pixel-setup: https://www.gdquest.com/library/pixel_art_setup_godot4/
19. Darkest Dungeon Wiki, "Dungeon Map" (korridorer 1–8 tiles, varje tile = en runda) – https://darkestdungeon.wiki.gg/wiki/Dungeon_Map

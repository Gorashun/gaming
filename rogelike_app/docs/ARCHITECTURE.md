# Arkitektur – PIPWRECK

*Uppdaterad 2026-09-21 (M1.5). Normativ källa för reglerna är `GAME_DESIGN.md`;
det här dokumentet beskriver hur koden är organiserad och hur man kör den.*

## Lagerregeln: core → game, aldrig tvärtom

```
src/core/     ren spellogik. RefCounted/statiska klasser. INGA Node-beroenden.
src/data/     innehåll som data (sidor, reliker, fiender, möten, belöningspool).
src/game/     Node-världen. Spelar upp händelseloggen. Läser core, aldrig tvärtom.
src/platform/ haptik, filsystem, senare butiks-API:er.
tools/        headless-verktyg (run_simulator.gd, smoke_play.gd).
tests/        gdUnit4-sviter. tests/support/ innehåller testhjälpmedel.
```

`src/game/shaders/` och `assets/` ägs av UI-agenten. `src/game/` i övrigt,
`src/platform/`, `tests/` och det här dokumentet ägs av dev.

`src/core/` importerar **aldrig** något från `src/game/`. Core tar data in och
returnerar en händelselogg. Det är regeln som gör både juice och tester möjliga:
uppspelningen kan pausas, snabbspolas och testas utan att reglerna rörs.

`src/data/content.gd` är innehåll, inte regler. Simulatorn får ändra siffrorna
där fritt (GAME_DESIGN §4.8); reglerna i `src/core/` är låsta och kräver en rad i
`DECISIONS.md`.

## Händelselogg-kontraktet

```gdscript
Resolver.resolve(state: CombatState, placement: PackedInt32Array) -> ResolveResult
# ResolveResult.events: Array[Dictionary], ResolveResult.state_after: CombatState
```

Fyra egenskaper som hela designen vilar på (GAME_DESIGN §6):

1. **Ingen RNG.** `resolve()` tar ingen slumpkälla och har inte tillgång till en.
   All slump för nästa runda dras i `Resolver.begin_combat()` / `advance()`, som
   körs **innan** spelaren bekräftar, så att allt som dragits syns i UI:t.
2. **Ren funktion.** Samma `state` + `placement` ger byte-identisk `events`.
   Förhandsvisningen ÄR utfallet.
3. **Muterar inte indata.** Resolvern arbetar på en djup kopia och returnerar
   `state_after`.
4. **Loggen är komplett.** UI får aldrig hoppa över ett event utan att ändå
   applicera dess tillståndseffekt. Snabbspolning = samma logg med `ms_hint = 0`.

Varje event har kuvertet `{t: String, seq: int, ms_hint: int}` plus typspecifika
fält. `seq` är `0..n-1` utan hål. Full eventkatalog: `GAME_DESIGN.md §3`.

Fasordningen är normativ: `P0 ROUND_START → P1 VALUE PASS → P2 COMBO PASS →
P3 STRIKE PASS → P4 ENEMY PASS → P5 ROUND_END`.

## Slump och sparfiler

All slump går genom `Rng` (`src/core/rng.gd`), en wrapper runt
`RandomNumberGenerator`. Samma seed ger samma run. `Rng.state()` / `restore()`
sparar och återupptar strömmens exakta position, så en autosave mitt i en strid
fortsätter på samma tärningskast. Seed och state lagras som `String` eftersom
JSON-tal är float64 och skulle tappa precision för 64-bitars värden.

Rendering och UI får aldrig dra ur den här strömmen. Visuell slump (partiklar,
skakning) använder en egen, osparad källa.

`RunState.to_dict()` / `from_dict()` är sparfilen. `RunState.SAVE_VERSION` höjs
när formatet ändras på ett sätt som kräver migrering.

### Prestandanot: copy-on-write-sidor
`Die.copy()` delar `Face`-objekt med originalet, eftersom `CombatState.copy()`
körs en gång per `resolve()` och därmed hundratusentals gånger i simulatorn.
Muteras en sida måste den först hämtas med `Die.mutable_face(index)`.
`Die.deep_copy()` finns för anropare som vill ha full isolering.

## M1: scenträdet

```
Main (Node, game_controller.gd)
├── Backdrop   CanvasLayer  layer = -10   skifferfärgad ColorRect
├── World      CanvasLayer  layer = 0
│   └── WorldRoot (Node2D, texture_filter = Nearest)
│       └── <skärmens world_scene>   pixelsprites, parallax, paperdoll
└── ChalkUI    CanvasLayer  layer = 10
    └── UiRoot (Control, texture_filter = Linear)
        └── ScreenRoot
            └── <en GameScreen åt gången>
```

Uppdelningen kommer från `research/04_pixelgrafik_pipeline.md §5`: pixelsprites
ska renderas `Nearest` i heltalsskala, krit-UI `Linear` så att kurvor och fonter
förblir mjuka. **Bakgrunden ligger under `World`**, annars döljer den hela
pixellagret — det var den första buggen rökprovet hittade.

Båda lagren delar samma 1080×1920-koordinatrymd. En sprite placeras därför
bakom sin kritpanel med `GameScreen.world_anchor(panel)`; ingen av dem behöver
känna till den andras layout.

| Skärm | Scen | World-innehåll |
|---|---|---|
| Marsch | `src/game/march/march_screen.tscn` | `march_world.tscn`: tre parallaxlager, golvremsa, `HeroFigure` |
| Strid | `src/game/combat/combat_screen.tscn` | `combat_world.tscn`: parallaxband, golv, Smeden, en `EnemyActor` per fiende |
| Belöning | `src/game/reward/reward_screen.tscn` | – |
| Död/vinst | `src/game/gameover/gameover_screen.tscn` | – |

`GameController` byter skärm **alltid uppskjutet en bildruta**. Skärmbytet
utlöses av en signal som emitteras inifrån `EventPlayer._process`, och att riva
ned stridsscenen mitt i motorns process-iteration kraschade Godot 4.6
reproducerbart.

## Pixelgrafiken (M1.5)

### `src/game/ui/art.gd` är enda uppslagsplatsen

Ingen annan fil i `src/game/` känner ett filnamn under `assets/sprites/`.
`Art` håller fiendearken och deras rutnät, paperdoll-lagren, relik→lager-
tabellen, tärningskroppar och LUT:ar, slot-, nod- och relikikoner samt
parallaxlagren med sina normativa hastigheter. Byts en sprite ut (utbytesplanen
i `assets/sprites/README.md` när CC0-paketen går att hämta) ändras en rad där.

`Art` äger också de tre reglerna som hela pipen vilar på:

1. **Nearest, alltid.** `project.godot` sätter `default_texture_filter = 0`, men
   `ChalkUI` står på Linear och ärver nedåt. Sprites som ligger *inuti* krit-UI:t
   (tärningsbrickan, slot-ikoner, kortikoner) måste sätta Nearest själva –
   `Art.pixel_sprite()` gör det.
2. **Heltalsskala.** `Art.fit_scale(box, cell)` ger största heltal som får plats.
3. **Heltalspositioner.** `Art.snap(point, scale)`. De globala `snap_2d_*`-
   flaggorna snappar mot viewportpixlar, inte mot konstrutnätet.

### Var sprajterna sitter

| Nod | Lager | Innehåll |
|---|---|---|
| `EnemyActor.sprite` | World | `AnimatedSprite2D`, 4 idle-frames, boss 48×48 övriga 32×32, ×4 |
| `CombatWorld` → `Backdrop` | World | två parallaxremsor + golvkakel bakom fienderna |
| `HeroFigure` | World | paperdoll, nio `Sprite2D`-lager, 48×48-celler, 8×4 frames |
| `MarchWorld` | World | tre parallaxlager (0,15 / 0,45 / 1,20) + golv (1,00) + figur |
| `DieView.art_root()` → `DieArt` | ChalkUI | kropp + pips/glyph + glaskant + spricka |
| `SlotView.art_root()` + `DieArt` | ChalkUI | slot-ikon och den placerade tärningen |
| `RewardCard.art_root()` | ChalkUI | relikikon, slot-ikon eller komponerad sida |
| `MarchScreen` förgreningsknapp | ChalkUI | nodikon (`ui/node_*.png`, 16 px × 4) |

`EnemyPanel` → `ArtSlot` är fortfarande ett **genomskinligt hål**: panelen är
krit-UI, sprajten ligger i World bakom den. `ArtSlot`:s underkant är dessutom
**golvlinjen** – `EnemyPanel.art_bottom()` skickas till `CombatWorld.set_band()`
så att en 48 px-boss och en 32 px-råtta står på samma mark. Smeden får en egen
tom kolumn längst till vänster i fiendezonen (`HeroSlot`), så att krit-UI:t
reserverar plats åt en figur som ritas i ett annat lager.

### Tärningen är komponerad, inte målad

3 material × 15 sidmotiv vore ~90 sprites. `DieArt` staplar i stället fyra
`Sprite2D` och klarar sig på 25 filer:

```
DieArt (Control, Nearest, heltalsskala ur fit_scale)
 └─ Die (Node2D)
     ├─ Body   z 0   die_body_<material>.png
     ├─ Glyph  z 1   pips_<0-6>.png (egen färg) ELLER glyph_<namn>.png (tintas)
     ├─ Rim    z 2   glass_highlight.png, endast GLASS
     └─ Crack  z 3   crack_<1-3>.png, variant seedad på tärningens id
```

Pip-arken är **redan** tintade i `bone/pip`; ett `modulate` ovanpå skulle
kvadrera färgen och göra ögonen svarta. Glypherna är vita och **ska** tintas av
sin semantiska token. `Art.face_overlay()` returnerar därför `color_token`
`"NONE"` för pips. Ritas sidan som ögon döljer `DieView` och `SlotView` sin
siffra – konsten bär värdet. Glyph-sidor visar värdet i effektraden ("⬬ psn 2").

**Avvikelse från `assets/sprites/README.md` §3, uppmätt:** den dokumenterade
vägen är gråskalemastern `die_body_gray.png` genom `palette_lut.gdshader` med en
16×1-LUT per material. I GL Compatibility skriver den shadern ut sitt resultat
utan sRGB-konvertering: en sprite med `lut_strength = 0` renderas som
`srgb_to_linear(källan)` (uppmätt `#C2451D` → `#941203`) och LUT-vägen landar
~24 % för mörkt. Tills shadern är fixad används de förtintade kropparna, som
renderas 1:1. Shadern används fortfarande för **träffblixten**, där mörkningen
inte syns eftersom bilden ändå lerpas mot vitt – materialet sätts på noden när
blixten börjar och tas bort när den slutar.

### Paperdoll-riggen

`HeroFigure` följer `assets/sprites/hero/PAPERDOLL.md`: **ett `Sprite2D` per
lager, en `AnimationPlayer` på föräldern, en enda `frame_index` som
sanningskälla.** Lagerordningen är barnordningen (cape, legs, body, torso, head,
helm, offhand, weapon, fx). Varje animation har exakt ett spår – ett
`Value`-spår på `Paperdoll:frame_index` med `UPDATE_DISCRETE`, eftersom
interpolation mellan heltalsframes ger halva poser.

| Animation | Rad | Frames | s/frame | Loop |
|---|---|---|---|---|
| `idle` | 0 | 4 | 0,16 | ja |
| `walk` | 1 | 8 | 0,08 | ja |
| `attack` | 2 | 6 | 0,06 | nej |
| `hit` | 3 | 4 | 0,08 | nej |

`strike()` emitterar `attack_contact` 180 ms in, vilket sammanfaller med
kedjestegets `damage_dealt` (UI_GUIDE §5.3). `set_chain_speed()` skalar
`AnimationPlayer.speed_scale` så att Blixt-tempo komprimerar figuren lika mycket
som siffrorna.

`apply_relics()` implementerar kollisionsregeln i PAPERDOLL §3 som en sortering:
högst rarity först, vid lika rarity senast plockad först; utrustningslagren är
upptagna från start eftersom **utrustning slår relik**. `fx` stackar och
avslutar därför alltid reservkedjan. **M1.5-status:** reliklagren är
specificerade men inte ritade, så upplösningen körs men inget lager tänds.
Figuren visar kropp, glödkappa, järnhjälm och smideshammare.

### Kedjan på riktiga sprites

| Event | Vad som händer |
|---|---|
| `die_activated` | tärningen i sloten OCH i brickan blixtrar (shaderns `flash`), Smeden svingar |
| `damage_dealt` | fiendesprajten blixtrar vitt och rycker bakåt |
| `enemy_killed` | squash + uttoning. **M1.5-assets har ingen death-frame**; finns en `death`-animation i `SpriteFrames` spelas den i stället |
| `player_damaged` | Smeden spelar `hit` |

Tidsbudgeten är orörd: kedjan (P0–P3) ≤ 2 500 ms, hela rundan ≤ 3 200 ms.

## Spelartext: engelska i källan, svenska i CSV

CLAUDE.md: **all spelartext är engelska i källan och går via `tr()`.** Svenskan
är en rad i `assets/i18n/translations.csv` (`keys,en,sv`), registrerad i
`project.godot` under `internationalization/locale/translations` med
`locale/fallback = "en"`.

```
Content (engelska källnamn + id)        assets/i18n/translations.csv
        │                                        │
        │ Content.enemy_key("RUST_RAT")          │ ENEMY_RUST_RAT,Rust Rat,Rostråttan
        ▼                                        ▼
    Tokens.translate_or(key, källnamn) ──► "Rust Rat" / "Rostråttan"
```

Tre regler:

1. **Nyckeln härleds ur id:t.** `Content.face_key()`, `relic_key()`,
   `enemy_key()`, `slot_swap_key()`, `class_key()`. Innehåll läggs till som data
   och kan aldrig glida ifrån sin översättning; `tests/test_i18n.gd` kontrollerar
   att varje id i `Content` har en rad.
2. **`Tokens.translate_or(key, fallback)`** faller tillbaka på det engelska
   källnamnet när raden saknas, så ett nytt innehålls-id syns som text och aldrig
   som en rå nyckel. Statiska funktioner kan inte anropa `Object.tr()` och går
   via `TranslationServer.translate()` – samma uppslagning, samma fallback.
3. **Core innehåller ingen prosa.** `Intent.note` är en översättningsnyckel med
   `Intent.note_args` som formatargument; `RewardApply.describe()` bygger sin
   mening av nycklar. `TranslationServer` är en Engine-singleton, inte en Node,
   så lagerregeln håller. (`note_args` tvättas med `int()` vid inläsning: JSON-tal
   är float64 och `3` skulle annars komma tillbaka som `3.0`.)

`tests/test_i18n.gd` skannar `src/game/`, `src/data/` och `src/core/` med `RegEx`
efter `tr("KEY")`, `translate("KEY")` och `_t("KEY")` och fäller bygget på en
nyckel utan CSV-rad, en tom `en`- eller `sv`-cell eller en dubblett.

Rökprovet kan köras på båda språken: `--locale=sv` efter `--`.

## Uppspelaren: en överlappande tidslinje

`src/game/juice/event_player.gd` tar `ResolveResult.events` och lägger dem på en
tidslinje i stället för i en kö (DECISIONS 2026-09-21). Varje event hamnar i en
av tre banor:

| Bana | Vad | Markören flyttas |
|---|---|---|
| `CHAIN` | tärning aktiveras, skada, död fiende, fiendeattack | `ms_hint × 0,6` (40 % överlapp) |
| `BEAT` | combo, kåk, rundans början och slut, spruckna tärningar | `ms_hint` |
| `SIDE` | Charge, Ward, överflöd, `strike`, `slot_modifier`, statusar | inget – spelas parallellt, 60 ms stagger |

Okända eventtyper hamnar i `SIDE`, så en ny eventtyp i M2 kan aldrig spräcka
budgeten.

Två tak gäller samtidigt och det hårdaste vinner: **kedjan** (P0–P3) mot
`BUDGET_MS = 2500` (normativt, UI_GUIDE §5) och **hela rundan** inklusive
fiendepasset mot `ROUND_BUDGET_MS = 3200` (dev-tolkning, §5 sätter inget tak för
P4). Överskrids något skalas hela tidslinjen linjärt en gång.

`build_timeline()`, `chain_ms()`, `total_ms()` och `apply_event()` är **rena
statiska funktioner** och testas utan scenträd. Uppspelningen ändrar aldrig
utfallet: varje event bär absoluta eftervärden (`target_hp_after`, `pool_after`),
så vyn efter N event är oberoende av hur snabbt de spelades. Det är därför
snabbspolning bevisligen ger samma slutläge (`tests/test_event_player.gd`).

Tapp under uppspelning: första tappet kör resten på 35 % av längden, andra tappet
hoppar till slutet (UI_GUIDE §5.9).

## Run-loopen

```
start_new_run(seed)
  → RunGraph.generate_floor(1, rng)      4 rum, förgrening i rum 3
  → MARCH  (går åt höger; vid förgrening två knappar)
  → COMBAT (RunFlow.start_room → rundor → RunFlow.finish_room)
  → REWARD (Rewards.generate → RewardApply.apply)
  → MARCH → … → BOSS → GAMEOVER (MetaScore)
```

Ingen av pilarna innehåller en regel. Möten, Andrum, belöningsnyckel,
belöningstillämpning och meta-poäng ligger i `src/core/run_flow.gd`,
`reward_apply.gd` och `meta_score.gd` och har egna tester.

### Autosave

`src/platform/save_io.gd` skriver `user://save.json` efter varje runda och efter
varje belöningsval. Skrivningen går via en temporärfil som byter namn sist:
antingen finns den gamla filen orörd eller den nya kompletta, aldrig en halv.
En trasig, avhuggen eller framtida sparfil ger `null` och en ny run — aldrig en
krasch. Sparfilen skrivs alltid vid en rundgräns (efter `Resolver.advance`), så
en återupptagen run börjar på ett kast som redan är draget och synligt
(GAME_DESIGN §1).

Run-nivådata som inte ligger i `RunState` (nodgrafen, rensade rum, största kedja,
tagna belöningar) läggs i `RunState.meta`, som går genom JSON. Heltal blir float
där, så allt tvättas med `int()` vid inläsning.

## Köra rökprovet

`tools/smoke_play.gd` spelar en hel run på våning 1 genom det riktiga UI:t med
`Policy.lookahead`, tar skärmdumpar och avslutar med exit code 0.

```bash
cd rogelike_app

# Med fönster och skärmdumpar (kräver xvfb-run):
xvfb-run -a -s "-screen 0 1080x1920x24" "$GODOT_BIN" \
  --resolution 1080x1920 --audio-driver Dummy \
  -s tools/smoke_play.gd -- --pipwreck-seed=7 --shots=res://docs/screenshots/m1_5

# Bara logiken, ingen rendering:
"$GODOT_BIN" --headless -s tools/smoke_play.gd -- --pipwreck-seed=7
```

Flaggor: `--pipwreck-seed=N` (läses även av `GameController` och tvingar en känd
run), `--shots=DIR` (tomt = inga skärmdumpar), `--max-seconds=N`,
`--locale=xx` (tvingar språk, t.ex. `sv`).

Skärmdumparna hamnar i `docs/screenshots/m1_5/`. `docs/screenshots/` har en
`.gdignore` så att Godot inte importerar dem.

## Köra tester lokalt

Kräver en Godot 4.6-binär. Sätt `GODOT_BIN` till den.

```bash
cd rogelike_app

# Första gången, och varje gång en ny class_name lagts till:
"$GODOT_BIN" --headless --import

# Hela sviten
"$GODOT_BIN" --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --ignoreHeadlessMode --continue --report-directory reports -a tests

# En enskild svit
"$GODOT_BIN" --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --ignoreHeadlessMode -a tests/test_resolver_examples.gd
```

`--ignoreHeadlessMode` krävs: gdUnit4 vägrar annars köra headless eftersom
`InputEvent` inte fungerar där. Vi testar bara logik, så det är ofarligt.
Rapporten hamnar i `reports/report_N/results.xml` (JUnit XML) och `index.html`.

## Köra balanssimulatorn

```bash
# M0-grinden: 1 000 seedade strider per policy
"$GODOT_BIN" --headless -s tools/run_simulator.gd -- --battles=1000 --room=1

# Hela runs på våning 1
"$GODOT_BIN" --headless -s tools/run_simulator.gd -- --battles=0 --runs=200

# Djupare sökning och JSON för regressionsjämförelse
"$GODOT_BIN" --headless -s tools/run_simulator.gd -- \
  --battles=500 --room=4 --width=32 --json=reports/balance.json
```

Simulatorn kör två policyer (`src/core/policy.gd`):

- **GreedyPolicy** – golvet. Slänger de fem högsta tärningarna i slot 0–4 och
  ignorerar slot-typer, combos, Charge och Ward.
- **LookaheadPolicy** – taket. Provar en begränsad kandidatmängd med `resolve()`
  och väljer högst `skada + 0.5 × Charge + 1.0 × Ward`, inklusive placeringar
  som lämnar slots tomma för att banka Charge.

**Skillnaden mellan dem är projektets viktigaste balansmått** (GAME_DESIGN §5).
Vinner greedy lika ofta som lookahead är placeringen meningslös och spelet är
Luck be a Landlord. Målet är minst 10 procentenheters skillnad; simulatorn
skriver ut en varning om den inte nås.

## CI

`.github/workflows/test.yml` i repo-roten körs på varje push och PR som rör
`rogelike_app/**`. Den laddar ner och cachar Godot 4.6-stable, importerar
projektet, kör gdUnit4 med JUnit-output och kör sedan simulatorn för både
1 000 strider och 200 hela runs per policy. Testrapport och balansstatistik
laddas upp som artefakter.

## Fallgropar i GDScript som redan bitit oss

- **`as <Enum>` är ogiltigt.** Enum-typade fält deklareras som `int` med enumen
  som namngivna konstanter. Annars vägrar klassen ladda med "Invalid cast".
- **Enum-namn får inte skugga en inbyggd klass.** `enum Material` gav
  "The member Material shadows a native class"; den heter nu `DieMaterial`.
- **`--import` måste köras innan något skript kan referera en ny `class_name`.**
  Utan det blir felet "Could not resolve external class member", vilket ser ut
  som ett syntaxfel men inte är det.
- **`for … else` finns inte.** Loopen måste skriva ut sitt flaggvärde själv.
- **En `Label` rapporterar sin textbredd som containerns minsta bredd.** En enda
  lång sträng kan därför trycka hela kolumnen utanför skärmen. Allt som inte
  radbryter ska ha `clip_text = true`; detsamma gäller `Button`.
  Motsatsen gäller också: klipper man BÅDA etiketterna i en rad med
  `SIZE_EXPAND_FILL` på den ena försvinner värdet helt.
- **`PRESET_BOTTOM_WIDE` ger en rect med höjd 0 vid underkanten**, så texten
  ritas nedanför noden. Sätt `grow_vertical = GROW_DIRECTION_BEGIN`.
- **En statiskt typad `Node`-referens kontrolleras inte.** Anropar man en metod
  på en frigjord nod blir det segfault, inte ett skriptfel. Vänta-loopar som
  håller en skärmreferens måste använda `is_instance_valid()`.
- **Att byta ut en scen inifrån `_process` kraschar.** Riv ned och bygg upp
  skärmar med `call_deferred`.
- **`await` i `SceneTree._initialize` återupptas utanför motorns träditeration**
  och kraschade reproducerbart. Lägg drivrutinen i en `Node` i stället.

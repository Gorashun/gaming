# Arkitektur – PIPWRECK

*Uppdaterad 2026-09-21 (M1). Normativ källa för reglerna är `GAME_DESIGN.md`; det
här dokumentet beskriver hur koden är organiserad och hur man kör den.*

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
| Marsch | `src/game/march/march_screen.tscn` | `march_world.tscn`: två parallaxlager, golvremsa, `HeroFigure` |
| Strid | `src/game/combat/combat_screen.tscn` | `combat_world.tscn`: en `EnemyActor` per fiende |
| Belöning | `src/game/reward/reward_screen.tscn` | – |
| Död/vinst | `src/game/gameover/gameover_screen.tscn` | – |

`GameController` byter skärm **alltid uppskjutet en bildruta**. Skärmbytet
utlöses av en signal som emitteras inifrån `EventPlayer._process`, och att riva
ned stridsscenen mitt i motorns process-iteration kraschade Godot 4.6
reproducerbart.

### Bytesplatser för pixelgrafik

Allt M1-innehåll är `ColorRect`/`Polygon2D`/`Label`. Dessa noder är avsedda att
bytas ut utan att röra logiken:

| Nod | Var | Vad som ska in |
|---|---|---|
| `DieView.art_root()` | tumzonen | kropp + glyph + palett-LUT + spricka (research 04 §3) |
| `SlotView.art_root()` | brädet | slot-ram per typ |
| `EnemyPanel` → `ArtSlot` | fiendezonen | genomskinligt hål; sprajten ligger i `EnemyActor` i World |
| `EnemyActor.sprite` | World | fiendesprite; sätt `silhouette.visible = false` |
| `HeroFigure` | World | sju `Sprite2D`-lager, 48×48-celler, 8×4 frames |
| `RewardCard.art_root()` | belöningskort | relik-/sidikon |

`HeroFigure` följer paperdoll-kontraktet i research 04 §2: **ett `Sprite2D` per
lager och en enda `frame_index`-setter**. Lagren kan alltså bytas mitt i en
gångcykel utan desync.

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
  -s tools/smoke_play.gd -- --pipwreck-seed=7 --shots=res://docs/screenshots/m1

# Bara logiken, ingen rendering:
"$GODOT_BIN" --headless -s tools/smoke_play.gd -- --pipwreck-seed=7
```

Flaggor: `--pipwreck-seed=N` (läses även av `GameController` och tvingar en känd
run), `--shots=DIR` (tomt = inga skärmdumpar), `--max-seconds=N`.

Skärmdumparna hamnar i `docs/screenshots/m1/`. Katalogen har en `.gdignore` så
att Godot inte importerar dem.

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

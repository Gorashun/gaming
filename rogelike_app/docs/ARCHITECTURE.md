# Arkitektur – PIPWRECK

*Uppdaterad 2026-09-21 (M0). Normativ källa för reglerna är `GAME_DESIGN.md`; det
här dokumentet beskriver hur koden är organiserad och hur man kör den.*

## Lagerregeln: core → game, aldrig tvärtom

```
src/core/     ren spellogik. RefCounted/statiska klasser. INGA Node-beroenden.
src/data/     innehåll som data (sidor, reliker, fiender, möten, belöningspool).
src/game/     Node-världen. Spelar upp händelseloggen. Läser core, aldrig tvärtom.
src/platform/ haptik, filsystem, senare butiks-API:er.
tools/        headless-verktyg (run_simulator.gd).
tests/        gdUnit4-sviter. tests/support/ innehåller testhjälpmedel.
```

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

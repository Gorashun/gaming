# Arkitektur – PIPWRECK

*Uppdaterad 2026-09-21 (M2). Normativ källa för reglerna är `GAME_DESIGN.md`;
det här dokumentet beskriver hur koden är organiserad och hur man kör den.*

## Lagerregeln: core → game, aldrig tvärtom

```
src/core/     ren spellogik. RefCounted/statiska klasser. INGA Node-beroenden.
src/data/     innehåll som data (sidor, reliker, fiender, möten, belöningspool).
src/game/     Node-världen. Spelar upp händelseloggen. Läser core, aldrig tvärtom.
src/platform/ inställningar, haptiknivåer, filsystem, skärmurtag, senare butiks-API:er.
tools/        headless-verktyg (run_simulator.gd, smoke_play.gd + smoke_driver.gd).
tests/        gdUnit4-sviter. tests/support/ innehåller testhjälpmedel.
```

## Autoloads (M2)

| Namn | Fil | Ansvar |
|---|---|---|
| `Settings` | `src/platform/settings.gd` | `user://settings.cfg`: språk, volym, haptik, reducerad rörelse, hög kontrast |
| `Juice` | `src/game/juice/juice.gd` | ljud, haptik, hit-stop, skärmskak, blixt, number pops |

`Settings` ligger **först**: `Juice` läser den vid varje anrop.

> **Fallgrop som kostade en halv dag:** ett skript som körs med `-s`
> (`tools/smoke_play.gd`, `addons/gdUnit4/bin/GdUnitCmdTool.gd`) kompileras
> **innan motorn registrerat autoloadarna**, och allt det typar mot kompileras
> med det. En skärm som nämner `Juice` fäller då hela körningen med
> `Compile Error: Identifier not found: Juice` – ett fel som ser ut som en
> trasig skärm men är en startordning. Därför är `smoke_play.gd` tunn och
> laddar `tools/smoke_driver.gd` först på första bildrutan. Testsviterna går
> fria eftersom gdUnit4 laddar dem i drift, efter att trädet startat.

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
| Titel | `src/game/title/title_screen.tscn` | – |
| Marsch | `src/game/march/march_screen.tscn` | `march_world.tscn`: tre parallaxlager, golvremsa, `HeroFigure` |
| Strid | `src/game/combat/combat_screen.tscn` | `combat_world.tscn`: parallaxband, golv, Smeden, en `EnemyActor` per fiende |
| Belöning | `src/game/reward/reward_screen.tscn` | – |
| Död/vinst | `src/game/gameover/gameover_screen.tscn` | – |

`ChalkUI/UiRoot/ModalRoot` ligger ovanpå `ScreenRoot` och bär
`settings_screen.tscn`. Inställningarna är en **modal, inte en skärm**: de ska
gå att öppna mitt i en runda (UI_GUIDE §6.4 – ljudet ska gå att stänga av just
när det stör), och ett skärmbyte skulle kasta bort spelarens placering.

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
| `EnemyActor.sprite` | World | `AnimatedSprite2D`, 4 idle-frames + 3 death-frames (ark 4×2), boss 48×48 övriga 32×32, ×4 |
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

**M2: LUT-vägen är tillbaka.** M1.5 ritade förtintade kroppar därför att
`palette_lut.gdshader` mörkade bilden ~24 %; diagnosen "sRGB tappas i GL
Compatibility" var fel. Rotorsaken (fixad av UI-agenten) var att fragmentets
inbyggda `COLOR` redan innehåller `modulate`, så shadern multiplicerade in
källfärgen en andra gång. `DieArt` ritar nu gråskalemastern med ett eget
`ShaderMaterial` per tärning – **ett eget**, eftersom `flash`-uniformen är per
tärning och ett delat material hade blixtrat alla sex samtidigt.
`Art.die_body()` faller tillbaka på de förtintade kropparna om gråskalan eller
LUT:en saknas.

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
| `enemy_killed` | `death`-animationen ur arkets rad 1 (3 frames, 10 fps = 300 ms). Saknas raden: squash + uttoning som i M1.5 |
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

### M2: tjugo nycklar väntar på en CSV-rad

`assets/i18n/translations.csv` ligger under `assets/` och ägs av UI-agenten;
dev fick inte röra den i M2. Titel-, inställnings- och de nya
slutskärmssträngarna går därför via `Tokens.translate_or(nyckel, engelsk
källsträng)`, vilket **inte** fångas av `tr()`-skannern – med flit: en nyckel
utan rad visas som engelsk text i stället för som en rå nyckel, och blir
tvåspråkig i samma sekund raden läggs in, utan kodändring.

**Att lägga in (nyckel · engelsk källsträng):**

| Nyckel | `en` |
|---|---|
| `TITLE_TAGLINE` | `Six dice. Five slots. One chain.` |
| `TITLE_CONTINUE` | `CONTINUE` |
| `TITLE_NEW_RUN` | `NEW RUN` |
| `TITLE_SETTINGS` | `SETTINGS` |
| `SETTINGS_TITLE` | `Settings` |
| `SETTINGS_LANGUAGE` | `Language` |
| `SETTINGS_SOUND` | `Sound` |
| `SETTINGS_HAPTICS` | `Haptics` |
| `SETTINGS_REDUCED_MOTION` | `Reduced motion` |
| `SETTINGS_HIGH_CONTRAST` | `High contrast` |
| `SETTINGS_RESET` | `Reset save` |
| `SETTINGS_RESET_ACTION` | `ERASE` |
| `SETTINGS_RESET_CONFIRM` | `TAP AGAIN` |
| `SETTINGS_CLOSE` | `CLOSE` |
| `SETTINGS_ON` | `ON` |
| `SETTINGS_OFF` | `OFF` |
| `COMBAT_NEW_BEST` | `NEW BEST` |
| `COMBAT_BOSS` | `BOSS` |
| `GAMEOVER_YOUR_CALL` | `It was your call.` |
| `GAMEOVER_KILLED_BY` | `Killed by %s.` |

`tests/test_i18n.gd` skannar `src/game/`, `src/data/` och `src/core/` med `RegEx`
efter `tr("KEY")`, `translate("KEY")` och `_t("KEY")` och fäller bygget på en
nyckel utan CSV-rad, en tom `en`- eller `sv`-cell eller en dubblett.

Rökprovet kan köras på båda språken: `--locale=sv` efter `--`.

## Juice: motorn som gör kedjan kännbar (M2)

`Juice` är en autoload och medvetet den **enda** noden som rör
`AudioStreamPlayer`, `Input.vibrate_handheld` och `Engine.time_scale`. Skälet är
tillgänglighet: UI_GUIDE §6.1/§6.4 kräver att skak, hit-stop och haptik ska gå
att stänga av, och en avstängning som ligger på tjugo anropsställen är ingen
avstängning.

| API | Vad | Tillgänglighet |
|---|---|---|
| `sfx(name, pitch, volume_db)` | 8 kanaler, lat laddning ur `assets/sfx/<name>.wav`, cachad. Saknad fil ⇒ tyst + räknad + en varning | `Settings.sfx_volume`, 0 = helt tyst men loggad |
| `ui_tap(pitch)` | UI-tryck på −14 dB (`assets/sfx/README.md` §2) | – |
| `haptic(level)` | `Input.vibrate_handheld`, 15/30/60 ms | `Settings.haptics`, `Haptics.level_floor`, 90 ms sammanslagning (§12.5) |
| `hit_stop(ms)` | `Engine.time_scale`, **tak 90 ms, aldrig staplat** | halveras vid reducerad rörelse |
| `shake(strength, ms)` | `CanvasLayer.offset` med avklingning på World + ChalkUI | **helt av** vid reducerad rörelse |
| `shake_node(node, dp, s)` | lokal skak av en panel | blir en uttoning vid reducerad rörelse |
| `flash(node, color, ms)` | `palette_lut`-shaderns `flash`-uniform, annars modulate | blir en 2 dp kontur (§12.6) |
| `number_pop(parent, text, color, at, size)` | poolad etikett i Juices eget `CanvasLayer` (layer 20) | ingen overshoot vid reducerad rörelse |
| `chain_pitch(step, multiplier)` | `pow(2, min(step + bonus, 12)/12)` | – |

**Inga allokeringar i uppspelningsloopen.** Number pops (24) och blixtkonturer
(8) är förinstansierade och animeras i `Juice._process` mot `PackedFloat32Array`
/ `PackedVector2Array`. Ingen `Tween` och inget `Label.new()` per event. Mätt i
rökprovet: bildrutetiden under en kedja är **densamma** som på en stillastående
skärm (p50 26,3 ms mot 26,2 ms under Xvfb/llvmpipe; se "Köra rökprovet").

Ljudnamnen är ett kontrakt mot `assets/sfx/README.md` §2. Tabellen i
`EventPlayer.feedback()` får bara peka på cues som finns där –
`tests/test_event_player.gd` kontrollerar det per fil.

### Settings

`src/platform/settings.gd` skriver `user://settings.cfg` med `ConfigFile`, inte
i sparfilen: inställningar ska överleva att en run tar slut och att sparfilen
nollställs. En trasig fil, eller en fil utan vår sektion, ger standardvärden –
aldrig en halvläst uppsättning (samma kontrakt som `SaveIO`).

| Fält | Standard | Effekt |
|---|---|---|
| `locale` | `""` (rör inte språket) | `TranslationServer.set_locale` |
| `sfx_volume` | 80 | `Juice.sfx` volym, 0 = tyst |
| `haptics` | true | `Haptics.enabled` |
| `reduced_motion` | false | skak av, hit-stop halverad, blixt → kontur, ingen overshoot |
| `high_contrast` | false | `Tokens.apply_high_contrast()` – hela tokentabellen (UI_GUIDE §2.11) |

**Hög kontrast+ är en token-override, inte ett andra tema.** Färgerna i `Tokens`
är därför `static var` och inte `const`: tabellen byts på ett ställe och inget
anropsställe ändras. Priset är att en redan byggd skärm behåller sina färger
tills den byggs om – modalen bygger om sig själv direkt, övriga skärmar nästa
gång de visas.

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
hoppar till slutet (UI_GUIDE §5.9). Vid tapp nollas dessutom hit-stoppen och all
kvarvarande haptik slås ihop till ett enda `MEDIUM` i slutet (§12.7).

### Feedback-tabellen är en ren funktion

`EventPlayer.feedback(event, step_index, hop)` returnerar ljudfil, tonhöjd,
mix-dB, haptiknivå, hit-stop och skak för ETT event. Den är statisk och ren, så
hela UI_GUIDE §5/§12 går att testa utan ljudkort och utan scenträd. Uppspelaren
spelar den själv (ljud och haptik behöver ingen nod); skärmen ritar bara det som
kräver en nod – vilken tärning som pulsar, vilken fiende som blixtrar.

Tre regler ur tabellen som är lätta att råka optimera bort:

1. **`enemy_killed` sänks två halvtoner** mot kedjans aktuella ton. Döden är en
   punkt, inte ännu en höjning (§5.5).
2. **`die_cracked` stiger inte alls.** Mönsterbrottet ska höras (§5.6).
3. **Ett överflödshopp byter cue** till `damage_overflow` och ligger i `SIDE`,
   inte i `CHAIN` (§12.2/§12.3 rad 7). Hoppet flyttar alltså inte markören.

### Hit-stoppen ligger INUTI eventets ms_hint

UI_GUIDE §12.2 är normativ: *"hit-stop räknas in i eventets `ms_hint`, inte
ovanpå"*. `Juice.hit_stop` fryser `Engine.time_scale`, vilket kryper in i
`delta`, så uppspelaren räknar sin tidslinje i **oskalad** tid
(`delta / Engine.time_scale`). Utan den divisionen skulle varje frysning
förlänga tidslinjen och tre combos spräcka budgeten utan att en enda rad i
tabellen ändrats. `EventPlayer.hit_stop_ms(events, reduced_motion)` mäter hur
stor del av uppspelningen som är frysta bildrutor; reducerad rörelse halverar
den siffran och flyttar inte ett enda event (§12.6: "timingen ändras inte").

`tests/test_event_player.gd` spelar upp referensrundan i §12.3 (par + överflöd +
kill) och kräver **exakt 2 400 ms**. Rör sig den siffran har antingen banorna
eller överlappet ändrats.

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
  -s tools/smoke_play.gd -- --pipwreck-seed=7 --shots=res://docs/screenshots/m2

# Bara logiken, ingen rendering:
"$GODOT_BIN" --headless -s tools/smoke_play.gd -- --pipwreck-seed=7
```

Flaggor: `--pipwreck-seed=N` (läses även av `GameController` och tvingar en känd
run), `--shots=DIR` (tomt = inga skärmdumpar), `--max-seconds=N`,
`--locale=xx` (tvingar språk, t.ex. `sv`), `--reduced-motion`,
`--policy=lookahead|greedy|none`.

`--policy=none` placerar ingen tärning och dör därför garanterat. Det är enda
sättet att få en **deterministisk dödsskärmdump**: Lookahead vinner våning 1 i
~94 % av fallen (DECISIONS 2026-09-21).

Rökprovet börjar på titelskärmen, tar en skärmdump av inställningsmodalen och
trycker sedan NEW RUN. Sparfilen rensas först, så körningen är oberoende av vad
som hände förra gången.

### Prestandamätningen

Rökprovet mäter bildrutetid som **väggklocka mellan två på varandra följande
bildrutor**, både under kedjorna och mellan dem.

> `Performance.get_monitor(Performance.TIME_PROCESS)` **duger inte** som
> per-bildrutemått: den uppdateras ungefär en gång per sekund. Uppmätt i den här
> miljön ger den exakt samma värde 200 bildrutor i rad (156,71 ms på en
> titelskärm med 67 noder) medan ett tomt projekt ger 0,06 ms. Monitorn skrivs
> ändå ut som trend.

Jämförelsen kedja mot tomgång är hela poängen: är de lika är det inte juicen som
kostar. Uppmätt 2026-09-21 (Xvfb 1080×1920, llvmpipe, 4 kärnor):
kedja p50 26,3 ms / p95 33,5 ms mot tomgång p50 26,2 ms / p95 37,1 ms. Headless
utan rendering: 6,90 ms i båda fallen, 0,1 % av bildrutorna över 16,6 ms.
**Slutsats: kostnaden är programvarurasterisering av en 1080×1920-yta, inte
uppspelningen.** En riktig GPU- och mobilmätning görs i M4 enligt planen.

Skärmdumparna hamnar i `docs/screenshots/m2/` (plus `sv/`, `reduced/` och
`death/` för de andra körningarna). `docs/screenshots/` har en `.gdignore` så
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

## Android (M4)

Allt som rör paketering, signering, CI-bygget och sidoladdning ligger i
**`docs/ANDROID.md`** – den är normativ för det. Tre saker hör hemma här
därför att de är arkitektur och inte bygge:

- **`src/platform/safe_area.gd`.** `DisplayServer.get_display_safe_area()`
  svarar i skärmpixlar, UI:t ritas i viewport-enheter (1080 brett,
  `aspect=expand` gör en hög telefon högre än 1920). Omräkningen är en **ren
  funktion av tre värden** och testas därför utan telefon.
  `GameScreen.apply_safe_area()` lägger insetet på skärmens `Margin` **efter**
  `enter()`, eftersom varje skärm sätter sin egen `margin_top` i `_style()`.
- **`GameController.back_action()`.** Androids bakåtknapp som ren funktion:
  skärmnamn + modal-läge + uppspelningsläge in, en av fem `BACK_*`-strängar ut.
  Ingen gren returnerar "avsluta", och `application/config/quit_on_go_back` är
  avstängd i `project.godot` – annars stänger `SceneTree` appen själv och
  funktionen blir aldrig anropad.
- **Paus-autosaven har en spärr.** `NOTIFICATION_APPLICATION_PAUSED` sparar
  bara när `GameController.can_autosave()` säger ja, och den frågar
  `CombatScreen.is_safe_to_autosave()`. Sparfilen är stridsläget vid rundans
  början **plus slumpströmmens position**, och de två måste höra ihop; ett
  omkast har redan rullat strömmen vidare utan att det sparade läget följt med.
  Samma regel som GAME_DESIGN §1: aldrig spara mitt i en kedja.

## CI

`.github/workflows/test.yml` i repo-roten körs på varje push och PR som rör
`rogelike_app/**`. Den laddar ner och cachar Godot 4.6-stable, importerar
projektet, kör gdUnit4 med JUnit-output och kör sedan simulatorn för både
1 000 strider och 200 hela runs per policy. Testrapport och balansstatistik
laddas upp som artefakter.

`.github/workflows/android-debug.yml` bygger en sidoladdningsbar debug-APK av
varje push som rör `rogelike_app/**`, på alla grenar, och laddar upp den som
artefakten `pipwreck-debug-apk`. Ett andra jobb bygger en signerad release-AAB
på `workflow_dispatch`. Bygget ligger i CI därför att agentmiljön inte når
`dl.google.com` och alltså inte kan ha en Android SDK (DECISIONS 2026-09-21).
Detaljerna står i `docs/ANDROID.md` §5.

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
- **Ett `-s`-skript kan inte referera en autoload.** Det kompileras före
  autoload-registreringen, och felet blir `Identifier not found: Juice` i en fil
  som inte ens nämner rökprovet. Ladda drivrutinen på första bildrutan.
- **`set_anchors_preset()` sätter inte offsets.** En kodskapad `Control` med
  `PRESET_FULL_RECT` blir då så stor som sitt innehåll, inte som sin förälder –
  inställningsmodalen blev 70 % bred och klippte varje etikett. Använd
  `set_anchors_and_offsets_preset()`.
- **Ett runtime-fel inuti en `await`-kedja avbryter hela anropsstacken tyst.**
  Rökprovet snurrade ett varv per bildruta på titelskärmen därför att en
  ombyggd skärm frigjordes under fötterna på coroutinen som höll den. Vakta med
  `is_instance_valid()` och hämta om noden efter varje `await`.

# Backlog (parkerat, ej MVP)

- Leaderboard via Google Play Games / Game Center (kräver Data safety + GDPR-genomgång)
- Dagliga utmaningar med delad seed
- Kodex-delning (skärmdump av rekordkedja)
- Tema "Risotryck" (UI-riktning B) som upplåsning i Kodex
- Molnsparning mellan enheter
- Fler tärningsmaterial efter de tre första (ben, glas, järn)

## Noterat under M0 (dev)

- Smartare LookaheadPolicy: nuvarande sökning provar bara ett begränsat urval av
  de 720 permutationerna (default `--width=8`, satt för att klara M0-grinden
  1 000 strider < 5 s). En beam search eller heuristisk kandidatgenerering ger
  bättre tak utan att kosta mer tid.
- `resolve()` kostar ~244 µs i GDScript, varav ~40 µs är eventloggen. Om
  simulatorn ska köra 10 000 runs enligt §5 behövs antingen en tyst
  scoring-variant eller att `CombatState.copy()` blir billigare.
- `LookaheadPolicy` väljer belöningar slumpmässigt i simulatorn. En riktig
  belöningspolicy behövs innan relik-/sidnärvaro i vinster (§5) kan mätas.
- Balansregression: spara simulatorns JSON till `docs/balance/<datum>.json` och
  jämför automatiskt mellan körningar (§5 "Regressionstest").
- `avoidable_death_rate` (§5) är inte implementerad i simulatorn.

## Noterat under M1 (dev)

- **Manuell smedja.** `RewardApply.default_target()` väljer plats deterministiskt
  (lägsta sidan, vänstraste PLAIN-sloten). UI_GUIDE §3 vill ha en smedjeskärm
  där spelaren väljer tärning → sida → ny sida. `apply()` tar redan ett
  `target`, så skärmen är allt som saknas.
- **Låsa tärningar inför omkast** (UI_GUIDE §4.5). `Reroll.apply()` tar
  `locked_ids`, men stridsskärmen har ingen knapp som fyller listan.
- **Kedjepilar och multiplikator-klamrar** mellan slots (UI_GUIDE §4.4). M1
  visar effektivt värde och multiplikator i sloten i stället.
- **Kedjetempo-inställningen** (Lugn/Normal/Snabb/Blixt). `EventPlayer.speed_scale`
  finns och fungerar, men inget UI sätter den och den sparas inte.
- **Reducerad rörelse** (UI_GUIDE §6.1) är inte kopplad till juice-funktionerna.
- **Ödeskast efter boss** (`FATE_ROLL`, GAME_DESIGN §1). M1 går direkt till
  vinstskärmen efter våning 1:s boss; ingen belöning ges efter bossen.
- **`ROUND_BUDGET_MS = 3200`** är dev:s tolkning. UI_GUIDE §5 sätter tak bara
  för kedjan (2 500 ms) och säger inget om fiendepasset. Behöver UI-beslut.
- ~~**M1.5 i18n-pass.**~~ Levererat 2026-09-21, se CHANGELOG M1.5.
- **`palette_lut.gdshader` tappar sRGB-konverteringen i GL Compatibility.**
  Uppmätt: en sprite med `lut_strength = 0` renderas som
  `srgb_to_linear(källan)` (`#C2451D` → `#941203`), LUT-vägen ~24 % för mörkt.
  Tärningarna använder därför de förtintade kropparna i M1.5. Fixas shadern är
  det en rad i `Art.die_body()` för att gå tillbaka till gråskala + LUT, och då
  kan även `lut_strength`-tweenen vid materialbyte (UI_GUIDE §9.2) användas.
  **UI-agenten.**
- **Reliklagren på paperdollen saknar PNG.** `smith_legs/torso/offhand/fx_*.png`
  är specificerade i PAPERDOLL §5 men inte ritade, så `HeroFigure.apply_relics()`
  kör kollisionsregeln utan att tända något lager. Reliker syns bara som ikoner.
- **Fienderna saknar death-frames.** Arken är fyra idle-frames;
  `EnemyActor.death_reaction()` tonar ut i stället. Läggs en `death`-animation
  till i `SpriteFrames` spelas den automatiskt.
- **Tärningens rullning (`die_rolled`, UI_GUIDE §9.4)** ritas inte:
  `dice/die_tumble_gray.png` finns och är registrerad i `Art.DIE_TUMBLE`, men
  `DieArt` byter bara sida direkt.
- **Krit-effekterna på World-lagret** (kritdamm, kedjepilar, skärvor) är
  fortfarande number pops och skalpulser.
- **Fiendezonen rymmer fyra fiender**, inte tre som M1-briefen antog: rum 1 är
  fyra Rostråttor (§4.4). Panelerna fördelar bredden dynamiskt.

## M4 Android – noterat, inte byggt

- **Debug-APK:n ligger på target SDK 35, inte 36.** Godot tillåter inte att
  min/target SDK skrivs över utan gradle-bygge, och gradle-vägen kostar ~10 min
  extra i CI. Play ser bara AAB:n (target 36), så det är inte en spärr. Vill vi
  ha 36 även i debug: sätt `use_gradle_build=true` i `Android Debug` och lägg
  NDK + platforms i `apk-debug`-jobbet. `docs/ANDROID.md` §3.
- **`screen/edge_to_edge` är av.** Androids 15-läge kräver att även botten
  kompenseras för navigeringsfältet; `SafeArea` räknar bara toppen i dag.
- **Butiksikon 512×512 och feature graphic 1024×500** är inte gjorda.
  `tools/gen_icons.py:draw_die()` ritar i valfri storlek, så 512 är en rad;
  feature graphic behöver komposition och är en UI-uppgift.
- **Haptiknivåerna 15/30/60 ms är inte kännselprövade** på en riktig telefon.
  Det var villkoret när de sattes (DECISIONS 2026-09-21) och hör till M4:s
  telefontest.
- **Kedjetempo-inställningen** (Lugn/Normal/Snabb/Blixt) finns i `Settings` men
  har fortfarande ingen kontroll i inställningsskärmen (DECISIONS: M4).
- **Ingen bekräftelsedialog när bakåtknappen lämnar en run.** I dag svarar
  bakåt med pausmenyn på march/belöning; en "avsluta run?"-fråga kan behövas
  när meta-progression finns.
- **iOS.** Presetfilen har bara Android. iOS kräver Xcode och moln-Mac
  (research/02 §"Plattformskrav").
- tests/test_i18n.gd: utöka KEY_PATTERN till `(?:tr|translate|translate_or|_t)\(\s*"KEY"` och lägg innehållstest för DEATH_LINES/Tutorial-nycklar (UI hittade 53 luckor som sviten missade). Dev, i nästa pass som rör tests/.

## M5 Korridoren – noterat, inte byggt

- **"Titta bakåt" i korridoren.** CORRIDOR_DESIGN §3.4 lovar att en tom, tyst
  korridor bakom en ska vara lugnande. Ett tapp åt vänster/höger vrider och går
  i ett svep, så vändningen utan steg finns inte. Det är en ren vy-funktion
  (`CorridorCamera.turn_to` + en knapp); kartan behöver inte ändras.
- **Hemliga dörrar och tellet** (§2.5: facklan fladdrar åt fel håll, kritstreck
  in i väggen, råttan som springer in i stenen). Kräver en tapbar yta i 3D
  (`Area3D` + `input_event`) som vyn inte har i dag.
- **De sex korridorljuden** (§7.2) är varken genererade eller kopplade.
  `tools/gen_sfx.py` ägs av UI.
- **Kritstråket** ritar ett streck per ruta men saknar glyf vid passerade
  korsningar och kryss där man vände (§2.7).
- **`palette_lut` i 3D-variant** för våningsvarianter. I dag är det ett
  `albedo_color` per våning, vilket räcker för tre våningar.
- **Mipmaps i `.import`.** `wall_stone`, `floor_stone` och `ceiling_stone`
  behöver `mipmaps/generate=true`; tills dess genereras de vid inläsning.
  Filerna ligger under `assets/` och ägs av UI-agenten.
- **Altar-, kist- och belöningspresentation i rummet** (§3.5) är inte byggd;
  korridoren emitterar bara `treasure_found`.


## Noterat under M5 dag 3 (dev)

- **Korridorens ljud saknas fortfarande.** De sex cuerna i CORRIDOR_DESIGN §7.2
  (`step_stone`, `turn_scuff`, `door_open`, `monster_far`, `torch_draft`,
  `descend_stairs`) är varken genererade eller kopplade. `tools/gen_sfx.py` ägs
  av UI. Korridoren är just nu helt tyst mellan striderna.
- **Kritstråket** ritar ett streck per gången ruta men saknar glyf vid passerade
  korsningar och kryss där man vände (§2.7).
- **Hemliga dörrar, Sexdörren och "titta bakåt"** (§2.5, §3.4, moment 3) är inte
  byggda. Alla tre kräver en tapbar yta i 3D (`Area3D` + `input_event`).
- **Altaret är en kritpanel, inte ett altare.** §3.5 vill ha en kista för eliter
  och ett föremål som lyfts ur den; M5 visar en panel med ett tapp. Belöningen i
  en vunnen kammare är däremot tre riktiga kort i rummet, som specat.
- **Belöningskorten kan inte "sjunka ner och plockas upp"** (§3.5). Kortet väljs
  med ett tapp, utan handen som tar upp det.
- **Character sheetets Run-Kodex** (§4.1 punkt 5: rum rensade, största kedjan,
  högsta multiplikatorn, bästa slot, antal `house_bonus`) är inte byggd, och
  badge-pulsen (§4.4) tänds men animeras inte.
- **`FORGE_FACE`- och `SLOT_SWAP`-animationerna** på sheeten (§4.3) saknas; bara
  ett nytt reliklager kritas på.
- **Smedjans sidbyte är fortfarande MVP:n från M2.5** (roterar 1↔6 på tärning 1).
  Sheeten visar alla sex tärningars sidor, men byter dem inte.
- **Torget har ingen Marrow och ingen kärra.** §5.1 vill ha honom vid trappan,
  och efter en död ska kärran skramla in bakom honom. M5 visar bara hans replik
  som text under torget.
- **Splitgolvet 36 % är mätt mot vår text, inte mot 130 % textstorlek.** Faller
  kvittot utanför även där behöver [ReceiptPanel] en kompakt variant.
- **`Engine.max_fps`** sätts fortfarande inte av spelet (PM-fråga från dag 2).

## Noterat under webbverifieringen (dev, 2026-09-22)

- ~~**Symbolglyfer blir tofu i webbexporten.**~~ **Löst 2026-09-22 (M5.6).**
  Båda de föreslagna vägarna togs: `assets/fonts/` buntar nu Familjen Grotesk,
  Anton och Caveat Brush (fulla OFL-original) plus `pipwreck_symbols.ttf` som
  fallback för formkoderna, och glyferna som ingen buntad font har (`◀ ▲ ▶ ◫ ⚙
  ↩ ⚔`) ritas som 16×16-sprites. `gui/theme/custom_font` sätter standardfonten
  och alla fyra .ttf importeras med `allow_system_fallback=false`.
  `tests/test_fonts.gd` fäller bygget om en oritbar symbol smyger tillbaka.
  Skärmdumpar: `docs/screenshots/web_verify/{corridor,combat}.png`.
- **Ny efter M5.6: spelet har ingen credits-/licensskärm.** Nu när fyra OFL-fonter
  ligger i bygget kräver licensen (OFL §2) att copyrightnoteringen följer med
  kopian. `assets/fonts/OFL-*.txt` är `.txt` och hamnar därför inte i pck:en –
  de finns bara i repot. Behövs innan första publicerade build: en enkel
  Kodex/Om-sida som listar `assets/ASSET_LICENSES.csv` och OFL-texterna. Ägare:
  PM prioriterar, UI bygger.

## Noterat under M5.5 (dev, 2026-09-22)

- **Föräldralösa parallax-PNG:er.** `assets/sprites/env/floor1_parallax_{far,mid,near}.png`
  och `floor1_tile.png` användes bara av den borttagna 2D-sidovyn. Ingen kod
  refererar dem längre; de ligger kvar i pck:en tills UI-agenten städar
  `assets/` (dev rör inte assets utan undantag).
- **UI:t växer inte på plats i källaren.** CORRIDOR_DESIGN §5.2 punkt 3 vill att
  `◀ VÄND ▶` kommer in först vid rum 0.4, kritstråket vid 0.5 och character
  sheet-knappen vid 0.6. M5.5 flyttade källaren in i korridoren men visar hela
  HUD:en från rum 0.1. Kräver en `Reveal`-flagga per HUD-element.

## Noterat under M5.8 (dev)

- **Rum 0.6 är fortfarande dyrt för den som inte hittar lektionen.** M5.8 tog
  bort fällan (porten blockar en gång, inte två, så rustningen stannar på 12),
  men **≤ 4 rundor för den uppenbara linjen går inte att nå utan ett
  designbeslut.** Mätserie ur `tests/test_tutorial.gd` och
  `tools/run_simulator`-liknande körningar, porten är `hp 44 / armor 8 / attack 6`:

  | Variant | Avsedd linje | "Banka, dumpa i slot 1" | "Fyll alltid alla fem" |
  |---|---|---|---|
  | M5.7 (BLOCK runda 1+2) | 2 rundor, 0 HP | **vinner aldrig** | vinner aldrig |
  | **M5.8 (BLOCK runda 1)** | 2 rundor, 0 HP | 12 rundor, 60 HP | vinner aldrig |
  | hp 24 | 2, 0 | 8, 36 | vinner aldrig |
  | hp 15 | 2, 0 | **4, 12** | vinner aldrig |
  | hp 24, armor 4, ingen BLOCK | 2, 6 | 5, 24 | 5, 24 |

  Två saker att besluta, båda rpg-nerd + PM:
  1. **"Fyll alltid alla fem" kan aldrig vinna** så länge rustningen är ≥ 7.
     Brädet ger som mest ett par 3:or (6 per slag), och den ende oplacerade
     tärningen bankar 1 per runda som direkt äts av slot 1. Spelaren blir inte
     dödad (kärran kommer), hen loopar. Enda utvägen är `armor ≤ 5`, och då
     behövs inte Laddningen för att komma igenom – lektionen försvinner.
  2. **Vill vi ha ≤ 4 rundor** för den uppenbara linjen måste portens HP ned till
     ~15, vilket gör källarens näst sista rum svagare än rum 0.4 (26 HP).

  Dev:s förslag: behåll 44 HP, behåll lektionen, och lös loopen med
  presentation i stället för balans – tipset kommer tillbaka efter två rundor
  utan skada. Det är en UI-uppgift och ett PM-beslut, inte en regeländring.

- **Kritpilen har aldrig testats mot sitt ankare förrän nu.** `tests/test_combat_layout.gd`
  täcker rum 0.6 (`slot_0`). De andra sex rummens ankare (`tray`, `receipt`,
  `arcs`, `slot_2`, `slot_4`) har bara namnkontrollen i `test_tutorial.gd`.

- **Källaren har ingen "ge upp"-väg.** Nu när våning 0 autosparas kan en spelare
  ligga kvar i rum 0.6 hur länge som helst. SKIP THE LESSON finns bara på
  titelskärmen, inte i pausmenyn under källaren.

## Noterat under M5.7 (dev, från webbtestet av 9b8d569)

- ~~**Källaren är inte återupptagbar.**~~ **Löst 2026-09-22 (M5.8).** Våning 0 autosparas med flit
  (`ARCHITECTURE`, "Tre skillnader"), men på web är en omladdning billig och
  vanlig: sker den före trappan startar tutorialen om på rum 0.1 och spelaren
  ser aldrig torget. Kandidat till Anders "det finns ingen stad". Kräver ett
  PM-beslut, eftersom det är samma mekanism som hindrar CONTINUE från att landa
  mitt i en tutorial.
- ~~**Rum 0.6 straffar den uppenbara linjen hårt.**~~ **Delvis löst (M5.8),
  resten är ett designbeslut – se "Noterat under M5.8" ovan.** `LookaheadPolicy` klarar
  porten på två rundor genom att lämna slot 1 tom så att banken hamnar i
  ×4-trippeln. Spelas rummet som en människa spelar det (dumpa banken i slot 1)
  blir det elva rundor och −78 HP, eftersom `BLOCK +4` runda 1–2 höjer portens
  rustning permanent 8 → 16 (`Resolver`: `enemy.armor += intent.value`) och
  `Rules.CHARGE_CAP` är 20. Design + regler, alltså rpg-nerd och PM, inte dev.
- ~~**`CORRIDOR_REWARD_TITLE` klipps på en 480 px-skärm.**~~ **Löst 2026-09-22 (M5.8).** "THE ROOM LEAVES YOU
  SOMETHING" går utanför båda kanterna i webbläsaren (`_heading.clip_text`).
  Belöningskortets namnrad klipps på samma sätt.

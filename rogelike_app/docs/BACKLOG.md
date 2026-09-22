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

- **Symbolglyfer blir tofu i webbexporten.** Projektet har ingen egen font och
  lutar sig på Godots inbyggda standardfont. Tecken den saknar (`◀ ▲ ▶` på
  riktningsknapparna, `◫` sheet-ikonen, `⚙` kugghjulet, `⬬`/`◉` i chip och
  effektrader) hämtas på Linux/Android från **systemfonten** via TextServerns
  OS-fallback. Webbexporten har ingen systemfont: där ritas de som tomma rutor
  med hexkod. Verifierat: `docs/screenshots/m5/gl_02_junction.png` (native, rätt)
  mot `docs/screenshots/web_verify/corridor.png` (web, tofu). Fix: bunta en font
  med täckning (t.ex. DejaVu Sans eller Noto Symbols) som `fallback` i temat,
  eller byt glyferna mot texturer i `Art`. Ägare: UI (assets/).

## Noterat under M5.5 (dev, 2026-09-22)

- **Föräldralösa parallax-PNG:er.** `assets/sprites/env/floor1_parallax_{far,mid,near}.png`
  och `floor1_tile.png` användes bara av den borttagna 2D-sidovyn. Ingen kod
  refererar dem längre; de ligger kvar i pck:en tills UI-agenten städar
  `assets/` (dev rör inte assets utan undantag).
- **UI:t växer inte på plats i källaren.** CORRIDOR_DESIGN §5.2 punkt 3 vill att
  `◀ VÄND ▶` kommer in först vid rum 0.4, kritstråket vid 0.5 och character
  sheet-knappen vid 0.6. M5.5 flyttade källaren in i korridoren men visar hela
  HUD:en från rum 0.1. Kräver en `Reveal`-flagga per HUD-element.

# Changelog

Format: en rad per leverans. Nyast överst.

## M6 spår A – art-manifest, målade battlers, stilskikt, character sheet v2, credits (2026-09-23)

- **Steg 1, art-manifest.** `Art.tex(id)` slår upp `assets/art/manifest.json` (cachat) i ordningen manifest → fiendealias → gammal sprite → platshållare; en saknad fil ger platshållare + en varning, aldrig null för fiender/ikoner och aldrig krasch. `Art.reload_manifest()` är hot-swap, `Art.validate_manifest()` fäller bygget på trasiga poster. Korridorens väggar/golv/tak/dörr/fackla/skylt, slot-, nod- och relikikoner och porträtten går via manifestet. Takets reserv lånar golvkaklet (se steg 3). `tests/test_manifest.gd` (17 tester).
- **Steg 2, målade battlers.** `EnemyBattler` (`src/game/corridor/enemy_battler.gd`) ritar EN PNG ur manifestet som Y-billboard (QuadMesh + `battler.gdshader`, en 3D-port av palette_lut med LUT/flash plus silhuett, kantljus, tilt och alpha; linear + mipmaps, `battler_pixel.gdshader` med Nearest bara för `pixel: true` och gamla sprites). Fast skala per pixel (256 px = 1,76 m) inpassad i en ruta per nivå, fötterna på golvet, bossen 1,6× under taket. Formering efter antal (1 i mitten, 2, 2+1, 2+2), främre ledet sorteras över det bakre, kastskugga som Sprite3D-ellips, andning via tween, träff = palettblixt + ryck, död = tona + falla omkull. Reducerad rörelse: ingen andning, inget ryck, inget fall. `tests/test_corridor_view_battlers.gd` (14 tester).
- **Steg 3, stilskiktet (ART_DIRECTION_V2 steg 0).** Korridorens ljus är vertexbakat (`CorridorLight`: kall blå fyllnad + varma pooler runt varje väggfackla med avståndsfalloff, kvaderna delade 3×3, taket 0,3×, hörnskugga) plus en handfackla i `corridor_surface.gdshader` (varm nära, faller av med avståndet, flimrar ur en visuell RNG) – inga Light3D, 8-ljusgränsen berörs inte. Målade väggar/golv/tak/dörr ur manifestet ritas linear + mipmaps. Dimman är void #07090B. Vinjett + statiskt korn + varmt fackelsken nere till höger + kall ton uppe till vänster i EN premultiplicerad shader i krit-lagret under HUD:en; glest damm (GPUParticles2D, 22 korn); fienderna får ljuset vid sina fötter. Skadesiffran är 88 dp Anton med 6 dp svart kontur och 4° lutning; narratorn talar i Caveat Brush vid möte, boss, tomt rum och ny våning. UI-bruset ned: slots är ikon + färgad underlinje utan låda, kvittot står på svart utan panel, chip och HUD utan ramar, tärningarna är det enda med skugga. **Buggfix:** röda scanlines i taket (två helröda pixelrader i `ceiling_stone.png`; reserven lånar golvkaklet och ett test fäller varje takstruktur med en röd rad), bossnamnet ritades ovanpå tutorialtipset (nu 0,94-scrim, tipset göms under introt, namnet på ett eget ogenomskinligt band som krymper i stället för att gå utanför). Reducerad rörelse: inget damm, inget flimmer, ingen andning. `tests/test_corridor_view_style.gd` (11), `tests/test_art_style_ui.gd` (5).

## M5.8 – källaren går att återuppta, rum 0.6 är inte längre en fälla (2026-09-22)

Tre riktade fixar ur `docs/BACKLOG.md`, "Noterat under M5.7".

**1. Autosave i källaren.** Våning 0 sparas nu per rum och per runda, precis som
våning 1. Sparfilen bär `meta.tutorial_room`; tärningar, HP och Laddning låg
redan i `RunState.combat`, kartans ruta i `meta.corridor` och `Reveal`-flaggorna
i profilen. Titeln erbjuder därför CONTINUE efter en omladdning, och den leder
till **rummet man stod i** – inte till 0.1. `_finish_tutorial()` rensar filen, så
trappan upp lämnar inget kvar. `RunState.SAVE_VERSION` 2 → 3; en v2-fil är per
definition en riktig run och **migreras** med `tutorial_room = -1` i stället för
att kasseras. Webbverifierat: spelat till rum 0.4, laddat om sidan, CONTINUE →
rum 0.4 med samma tärningar, samma 92/100 HP och samma Tick Pup
(`docs/screenshots/web_tutorial2/`).
- Sidoeffekt som måste med: en återupptagen strid fick aldrig sitt
  `EVENT_ENCOUNTER_REACHED`, så korridoren stod tom bakom stridsbrädet.
  `CorridorView.restore_encounter()` ställer monstren på plats utan att spela om
  avslöjandet. Felet fanns sedan M5 för riktiga runs; källaren gjorde det synligt.

**2. Rum 0.6 är inte längre en fälla.** Porten blockade runda 1 **och** 2, och
`Resolver` gör `enemy.armor += intent.value` – höjningen är permanent, så
rustningen stod på 16 för resten av striden. Nu blockar den **exakt en gång**
(runda 2 är en uttalad ATTACK). Ren data, regeln är orörd. Tipset och kritpilen
säger dessutom exakt vad lektionen är: `TUT_06_CHARGE` = *"Leave slot 1 empty.
The charge goes to the Mirror."* (en + sv) och pilen pekar på `slot_0`.
- **Pilen pekade fel i hela tutorialen.** `TutorialPointer` satte en global punkt
  som lokal position; i korridoren ligger FxLayer i de nedre 55 %, så pilen
  hamnade 864 px under sitt ankare – i rum 0.4 nedanför bekräfta-knappen.
  Rättad med `global_position`, med ett test som fäller den igen.
- **Öppen fråga till PM, inte fixad här:** den uppenbara linjen (banka, dumpa
  banken i slot 1) går nu att spela klart men kostar **12 rundor och 60 HP**;
  den avsedda linjen är 2 rundor och 0 HP. Se `docs/BACKLOG.md`, "Noterat under
  M5.8", för mätserien och varför ≤ 4 rundor kräver ett designbeslut.

**3. Klippta texter.** `CORRIDOR_REWARD_TITLE` gick utanför båda kanterna:
viewporten är alltid 1080 enheter bred, så felet fanns på varje skärm.
Källsträngen är kortad till `"THE ROOM LEAVES SOMETHING"` (sv: `"RUMMET LÄMNAR
NÅGOT"`) och rubriken bryter rad i stället för att klippas. Belöningskortets
namnrad **krymper** i stället för att klippas – `Tokens.fit_font_size()` är en
ren funktion och `Tokens.shrink_to_fit()` kopplar den till en etikett.
Verifierat i webbläsaren på 480×900 och 360×640, `?start=corridor` och källaren.

Tester: 427/427 gröna (20 nya). Rökprov en + sv: `SMOKE OK`.

## M5.7 – riktigt loot i källaren (2026-09-22)

**Anders webbtest av `9b8d569`: (1) "det finns ingen stad", (2) "hittade inget
loot i tutorial level".**

**(1) gick inte att återskapa.** Hela Grundstigen spelades igenom i Chromium
mot `build/web/` (rum 0.1–0.7, boss nedlagd, `FORWARD · stairs up`) och torget
Chalkrim kom upp som det ska – `docs/screenshots/web_tutorial/`. Profilen
överlever en omladdning (IndexedDB), och titeln visar då `CHALKRIM`. Två saker
som kan förklara upplevelsen, båda verkliga och båda rapporterade till PM i
stället för fixade här: källaren autosparas inte (en omladdning före trappan
startar om på rum 0.1), och rum 0.6 är en fälla för en människa – den optimala
linjen är att lämna slot 1 tom så att banken hamnar i ×4-trippeln, och spelas
den uppenbara vägen tar rummet elva rundor och 78 HP.

**(2) fixad.** Rum 0.3 lämnar nu, efter sitt berättande `+1 slot`-kort, **tre
riktiga belöningskort** ur den vanliga poolen (`FORGE_FACE`, samma kort och
samma vikter som i en run) under rubriken `TUT_LOOT_TITLE` = `"Loot. Pick one."`
(en + sv). Rum 0.5 och 0.7 är orörda.
- `Tutorial.has_loot/loot_options/loot_title/loot_target`, `"loot": true` på rum 0.3.
- `CorridorReward.show_options()` tar valfri rubrik och färdiga mål; `CorridorScreen.show_reward()` skickar vidare.
- `GameController._show_tutorial_loot()` + flaggorna `_tutorial_loot_pending` / `_tutorial_loot_open`. Loot-kortet är det enda i våning 0 som går genom `RewardApply.apply()`.
- **Invarianten:** `loot_target()` pinnar sidan som byts ut till den lägsta som
  inget senare rum tvingar upp på just den tärningen. `default_target()` hade
  tagit tärning 1:s etta, som rum 0.5 och 0.6 behöver, och rum 0.5:s lektion
  ("inget naturligt par") hade gått sönder tyst. Fyra nya tester i
  `tests/test_tutorial.gd` applicerar varje alternativ och kräver att rum
  0.4–0.7 fortfarande visar exakt sina fasta värden.

Tester: 407/407 gröna. Rökprov en + sv: `SMOKE OK`.

## M5.6 – projektet har en egen font (2026-09-22)

**Symbolglyferna var tofu i webbexporten.** Projektet hade ingen egen font.
Godot ritade allt med sin inbyggda och hämtade tecken den saknade – `◀ ▲ ▶`
på riktningsknapparna, `◫` på character sheetet, `⚙` på inställningarna – ur
**systemfonten**. Det fungerade på Linux och Android och gav tomma rutor på web
(`docs/screenshots/m5/gl_02_junction.png` mot den gamla
`docs/screenshots/web_verify/corridor.png`). Samma risk fanns för å/ä/ö.

**1. Fyra OFL-fonter i `assets/fonts/`**
- `familjen_grotesk_variable.ttf` (UI, wght 400–700), `anton_regular.ttf`
  (display), `caveat_brush_regular.ttf` (scrawl) – fulla originalfiler från
  google/fonts, inte subset. Alla täcker å/ä/ö och siffror.
- `pipwreck_symbols.ttf` – Noto Sans Symbols 2 som symbolfallback för
  formkoderna i UI_GUIDE §2.3–2.5 (`⬬ ❖ ⬟ ✦ ✚ ⬣ ⬤ ⬚ ▭ ◣ ▤ ◉ ◖ ⛊ ➤`). Orörd
  gjorde den varje etikett 36 % högre – Godot storlekssätter ur
  `Font.get_height()`, som är maximum över fallbackkedjan, och Notos radlåda är
  1,70 em mot Familjen Grotesks 1,25 em. Stridsskärmen växte 127 px förbi
  tumzonen. `tools/make_symbol_font.py` skalar om metrikerna och bara dem.
- `ui_regular.tres` / `ui_bold.tres` / `display.tres` / `scrawl.tres` binder
  bastypsnitt + fallback. `project.godot: gui/theme/custom_font` pekar på den
  första. Alla fyra .ttf importeras med `allow_system_fallback=false`: spelet
  får aldrig låna en systemfont igen.
- `Tokens.font_ui/_bold/_display/_scrawl()` och `Tokens.apply_type()` – §2.8 är
  en tabell och läses nu som en: storlek OCH typsnitt på samma anropsställe.
  Anton sitter på display-xl/display-l (number pop, titel, bossnamn).

**2. Sex nya 16×16-ikoner ersätter glyfer som ingen font har**
- `icon_arrow_{left,forward,right}`, `icon_sheet`, `icon_settings`, `icon_undo`
  ur `tools/gen_pixel_assets.py` (own-work).
- `Art.apply_button_icon()` / `Art.icon_rect()` / `Art.scaled_ui_icon()` –
  ikonen förstoras i texturen med nearest och heltalsfaktor. `icon_max_width`
  kan bara krympa, så en 16 px-sprite blev annars en prick i en 102 px-knapp.
- Bytt till sprite: riktningsknapparna, character sheet-knappen (torg + korridor),
  inställningar (torg, korridor, strid), ångra, "?", laddningspillret samt
  rustning och attack i fiendechipet.
- Kvar som text, men ur en **buntad** font: `◉ ◖ ✕ ⬬ ❖ ⬟ ✦ ✚ ⬣ ⬤ ⬚ ▭ ◣ ▤`.
  Utbytta i CSV:n: `↩ → (inget)`, `↳ → ⮡`, `↻ → ⭮`. `卌` blev `||||/` och
  `①②③` blev rena siffror i brickan – ringen är brickans ram.

**3. `tests/test_fonts.gd`** – 12 tester: filerna finns, OFL-texten följer med,
`gui/theme/custom_font` pekar rätt, fallbacken finns, **fallbacken får inte
blåsa upp radlådan**, varje tecken i `translations.csv`, i `Art.UI_ICON_GLYPHS`
och i `Tokens`-tabellerna har en glyf, de nio ikonerna finns och är 16×16, och
ikonstorlekarna ligger på heltalsskala.

**Körningar:** hela sviten 403 test, 0 fel. Rökprovet grönt i `en` och `sv`.
Webbexport + Playwright: ingen tofu i korridoren eller striden.

## M5.5 – en enda stridspresentation (2026-09-22)

**Anders fick "sidescroll" i webbversionen.** Det var inte ett webbfel: det var
tutorialvåning 0, som fortfarande spelades i M1:s platta 2D-sidovy medan resten
av spelet hade flyttat in i korridoren. Två presentationer av samma strid, och
den första en ny spelare mötte var den gamla.

**1. Källaren är en korridor** (CORRIDOR_DESIGN §5.2)
- `CorridorMap.straight_floor()` – ny. Rak våning, kammare på rad, en
  `KIND_STAIRS`-ruta sist. Ingen graf, ingen seed, ingen regel – som
  `town_square()`.
- `Tutorial.corridor_map()` / `Tutorial.room_index_for()` – sju kammare, två
  steg emellan (§5.2 punkt 2), trappa upp bakom bossen. Kammarens `node_id` är
  hela kopplingen mellan karta och tutorialdata.
- `EVENT_STAIRS_UP` → `CorridorView.stairs_reached` → `_finish_tutorial()` →
  torget. "Spelet börjar i mörker och första saken du gör är att gå upp ur det."
- Rum 0.1–0.7 kör nu samma 45/55-strid, samma chip, samma kvitto och samma
  `Reveal`-flaggor som en riktig run. Tips och kritpil ligger kvar i ChalkUI.
- Källaren autosparas aldrig och applicerar ingen belöning: korten är
  berättande, förändringen ligger i nästa rums data (§B.2).
- `--pipwreck-start=tutorial` och `index.html?start=tutorial` lades till.

**2. Den platta sidovyn är borta**
- Borttaget: `combat_world.gd/.tscn`, `enemy_actor.gd`, `enemy_panel.gd`,
  `route_strip.gd`, `Art.PARALLAX`, `Art.FLOOR_TILE`, `GameScreen.world_scene`,
  `GameScreen.world`, `GameScreen.world_anchor()` och hela `World`-CanvasLayern
  i `main.tscn`.
- `CombatScreen` har inte längre ett korridorläge – den ÄR korridorens.
  `readout_host` är alltid `CorridorScreen/Chips`; saknas den är det ett fel.
- Figuren (`HeroFigure`) syns nu **bara** i character sheetet.
- Rum 0.2:s kritpil pekade på leveransremsan; den pekar nu på kvittot, där
  överskottet står i ord.
- Krit-radens rumsnummer uppdateras innan striden monteras – det låg ett rum
  efter i både källaren och en riktig run.

**Körningar:** hela sviten 391 test, 0 fel. Rökprovet grönt i `en` och `sv`
(`SMOKE OK`, 29 skärmdumpar vardera) med flödet kroppsval → källaren 0.1–0.7 →
torget → korridor → strid → belöning → bossdörr → boss → vinst → torget. Nya
skärmdumpar i `docs/screenshots/m5_tut/` och `docs/screenshots/m5_tut/sv/`.
Webbexporten verifierad i Chromium/WebGL2 på `?start=tutorial`
(`docs/screenshots/web_verify/tutorial_room_1.png`).

## Webbverifiering: korridoren i WebGL2 (2026-09-22)

- **`CorridorScreen/Chips` och `CorridorScreen/Overlay` svalde varje tapp i
  korridoren.** Två tomma helskärmslager låg överst på `MOUSE_FILTER_PASS`, och
  PASS stoppar Godots träffsökning precis som STOP – eventet bubblar sedan till
  *föräldern*, aldrig till syskonet under. FORWARD, character sheetet,
  inställningarna och fällprompten var otryckbara på alla plattformar. Båda står
  nu på `IGNORE`; barnen sätter STOP själva.
  (`src/game/corridor/corridor_screen.tscn`, `src/game/corridor/enemy_chips.gd`)
- `tests/test_corridor_flow.gd` – tre nya test som speglar Godots träffsökning
  och kräver att varje synlig korridorknapp är översta kontrollen under sin egen
  mittpunkt. De fäller den gamla scenen med rätt meddelande.
- `--pipwreck-start=town|corridor|sheet` i `GameController.boot()`, läst bara ur
  `OS.get_cmdline_user_args()` som `--pipwreck-seed`. Kvitterar kroppsval och
  tutorial i stället för att kringgå dem. `tests/test_debug_start.gd`, 6 test.
- `tools/web/index.html` läser `?start=…&seed=…` och skickar vidare som
  `args: ['--', …]`. Utan query-parametrar startar spelet exakt som förut.
- Verifierat i Chromium/SwiftShader, WebGL 2.0 (OpenGL ES 3.0), 480×900:
  torget, korridoren (depth fog, `AnimatedSprite3D`, SubViewport) och character
  sheetet renderar, och tre tapp på FORWARD går två rutor in i ett möte med
  stridssplitten monterad. Skärmdumpar i `docs/screenshots/web_verify/`.
- Känt, ej åtgärdat: symbolglyfer (`◀ ▲ ▶ ◫ ⚙`) blir tofu i webbexporten –
  ingen systemfont att falla tillbaka på. Se `docs/BACKLOG.md`.

## M5 – Korridoren, dag 3: integrationen (2026-09-21)

Korridoren blev spelet. Flödet är nu **stad → korridor → strid i korridoren →
belöning på golvet → bossdörr → boss → vinst → stad**, och `src/game/march/` är
borta. **Ingen regel är ändrad**: `src/core/resolver.gd`, `run_graph.gd` och
stridsspecen är orörda; det enda nya i core är fällans prislapp
(`RunFlow.pay_trap`), som DECISIONS 2026-09-21 redan beslutat om.

**1. Flödet**
- `src/game/corridor/corridor_screen.gd/.tscn` – ny. Korridoren som skärm.
  Striden monteras som ett **barn** i de nedre 55 % i stället för att byta
  skärm, så 3D-världen och kamerans plats i rutnätet överlever hela våningen.
- `src/game/game_controller.gd` – `SCREEN_MARCH` → `SCREEN_CORRIDOR`. Autosave
  per ruta med hela kartan (`map_state`), återupptagning mitt i korridoren och
  mitt i en strid, och `--pipwreck-seed` ger fortfarande samma run.
- `RunState.SAVE_VERSION` **1 → 2**. En v1-fil beskriver en marsch som inte
  finns och går inte att översätta (korridorens fork har redan rullat), så
  `SaveIO.migrate` kasserar den och spelaren hamnar i staden. Aldrig en krasch.
- Tutorialvåning 0 kör oförändrat som platt stridsskärm i källaren.

**2. Striden i korridoren (45/55)**
- Fienderna står kvar som `AnimatedSprite3D` i 2+2-formering; träffblixt, ryck
  och död spelas på billboarden, aldrig på kameran.
- `src/game/combat/enemy_readout.gd` – ny gemensam bas. `EnemyPanel` (källaren)
  och `EnemyChip` (korridoren) delar namn, intent-text och prognosfält.
- `src/game/corridor/enemy_chip.gd` + `enemy_chips.gd` – HP-chip ankrade med
  `Camera3D.unproject_position()`, kritstreck ner till varelsens hjässa, tapp på
  chipet = tapp på fienden.
- **Arenan betalar** (COMBAT_READABILITY §8): toppfältets knappar flyttade till
  krit-raden, leveransremsan till chipen, brickans rubrik till pillerraden. Med
  ett fullt kvitto faller korridoren till **36 %** i stället för 45 – mätt, se
  `CorridorView.SPLIT_COMBAT_MIN`.
- `src/game/corridor/corridor_reward.gd` – belöningen som tre kort **i rummet**,
  med korridoren synlig bakom.

**3. Character sheet** – `src/game/sheet/character_sheet.gd/.tscn`, ny. Porträtt,
HP, Pips, paperdoll ×8, sju slots med relikernas slot-mappning
(`Content.RELIC_SLOTS`), smedjans slotordning (aktiv bara i staden), sex
tärningar med sidor, reliker, CHANGE LOOK och GO DOWN. Öppnas från HUD-knappen
och automatiskt efter runnens första belöning.

**4. Staden i förstaperson** – `src/game/town/town_view.gd/.tscn`, ny. Torget är
`CorridorMap.town_square()` genom samma `CorridorMesh`: tre upplysta mynningar
med skyltar ankrade i 3D. Smedjan är en knapp, `GO DOWN` ligger kvar i tumzonen.

**5. i18n** – 47 nya rader (en + sv) för `CORRIDOR_*`, `CHARSHEET_*`, `TOWN_*`,
fälltyperna och deras prislappar. `tests/test_i18n.gd` skannar nu även
`Tokens.translate_or(...)`, plus innehållstester för Marrows dödsrepliker,
tutorialens nycklar och korridorens datadrivna nycklar.

**6. Verifiering** – hela sviten **380 fall, 0 fel, 0 fallerade**. Rökprovet
spelar könsval → tutorial → torget → korridor → strid → belöning → bossdörr →
boss → vinst → torget i både `en` och `sv`; 28 skärmdumpar per språk i
`docs/screenshots/m5_int/` (+ `sv/`). **Stoppregeln:** 17 steg och 4,6 s
korridortid per våning ⇒ **13,8 s per run** mot budgeten 90 s, och **3 steg utan
händelse** mot taket 3.

## M5 – Korridoren, dag 1–2: kartmodell, 3D-vy, rökprov (2026-09-21)

Presentationsskiftet till förstaperson (DECISIONS 2026-09-21). **Ingen regel är
ändrad**; `src/core/resolver.gd`, `run_graph.gd` och stridsspecen är orörda.
Korridoren är ett lager ovanpå grafen och instansieras som en scen — ingen ny
autoload, `project.godot` orörd.

- `src/core/corridor_map.gd` – ny. Översätter en `RunGraph` till ett rutnät:
  kammare på noderna, 2–3 stegs kanter, T-korsning med en skyltnyckel per
  utgång, en fälla som ett val med två prislappar, en sällsynt återvändsgränd
  med skatt, en tyst sträcka och en bossdörr. Seedad, deterministisk, går rakt
  in i sparfilen. Rörelsen är framåtlåst: `available_actions()` erbjuder aldrig
  vägen tillbaka, och hörn vrids när man kommer fram.
- `src/game/corridor/` – ny. Våningen som EN `ArrayMesh` med tre ytor, unlit,
  depth fog i krit-UI:ts egen bottenfärg. Kameran är den enda rörliga noden:
  180 ms steg, 160 ms vridning, absolut yaw, ingen head-bob, ingen kameraskak,
  reducerad rörelse = omedelbar vy. Skyltar som `Sprite3D` av `node_*.png`,
  fiender som `AnimatedSprite3D` i 2+2-formering, silhuett på två rutors håll.
  Tre riktningsknappar i tumzonen och krit-HUD med HP, rum, Pips och kritstråk.
- `tools/gen_tileable.py` – ny. Sömkontroll av de kakelbara texturerna (alla tre
  godkända) + `assets/sprites/env/corridor/sign_plate.png`.
- `tools/smoke_corridor.gd` – ny. Går våning 1 till bossdörren, dumpar sex
  bilder per renderare till `docs/screenshots/m5/` och fäller körningen om
  korridortiden eller "steg utan händelse" spricker.
- **Stoppregelns siffror (seed 7):** 17 steg, 5,0–5,5 s per våning ⇒ **15,5–16,7 s
  per run** mot budgeten 90 s; **max 3 steg utan händelse** mot taket 3.
- **Renderarunderlag:** depth fog fungerar i både Forward Mobile och
  Compatibility, bilderna är i praktiken identiska (medelavvikelse 1,4/255).
  Siffrorna i `docs/CORRIDOR_DEV_NOTES.md` §7 är mätta på `llvmpipe` och är
  inte enhetsrepresentativa.
- Tester: `tests/test_corridor_map.gd` (17 fall) och `tests/test_corridor_view.gd`
  (14 fall). Hela sviten **353 fall, 0 fel, 0 fallerade**.
- Integrationspunkter, i18n-nycklar och avvikelser: `docs/CORRIDOR_DEV_NOTES.md`.

## M2.5 – Begriplighet: stridsskärm v2, våning 0, Chalkrim, smedjan, kroppsval (2026-09-21)

Utlöst av speltest 1: *"det är svårt att fatta mekaniken"*. **Ingen regel är
ändrad.** `src/core/resolver.gd` är orörd; allt nedan är presentation, data och
profil.

**A. Stridsskärm v2** (`docs/design/COMBAT_READABILITY.md`)

- `src/game/combat/chain_receipt.gd` – ny, ren läsmodell över händelseloggen.
  Ger meningen (`2 + 10 + 10 + 6 + 12 = 40`), rustningsraden
  (`40 − 12 rustning (2 per träff × 6 träffar) = 28`), en leveransrad per
  skadeinstans med numrerad fiende, dödsmarkering och spill, bågarnas orsak och
  per-slot-orsakskoder. Inga Node-beroenden, ingen prosa.
- `receipt_panel.gd`, `arc_row.gd`, `route_strip.gd`, `help_layer.gd` – nya vyer.
  Bågen bär sitt varför (`×2 PAR · BÅDA 5`), `?` tänder sex callouts samtidigt.
- `slot_view.gd`: namn + **regel** + räkning (`5 ×2 = 10`) + varför
  (`par med 3`). `slot_modifier_failed` syns som `för lågt`. Spegelns tärning
  ritas på 55 % och räkningen skrivs `←5 ×2 = 10`.
- `die_view.gd`: brickan är en sann modell – en placerad tärning lämnar en tom
  sockel med slotnummer; vald tärning lyfts; tomma slots pulsar fasförskjutet.
- `enemy_panel.gd`: `🛡 Rustning 2` och `⚔ Slår 3` som ord + ikon, prognosfält
  (diagonalskraffering) i HP-stapeln, numrerade dubbletter.
- Knappen och kvittot visar **samma** tal: `BEKRÄFTA · 28 SKADA`.

**B. Progressiv avslöjning** – `src/core/reveal.gd`

Åtta flaggor, sparade i profilen. Ett element som inte lärts ut är *frånvarande*,
inte nedtonat – och får bara döljas när det är tomt eller overksamt
(`Reveal.may_hide`), så att UI aldrig ljuger om tillståndet.

**C. Tutorialvåning 0** – `src/data/tutorial.gd`

Sju rum som ren data (bräde, fasta tärningsvärden, fiender, tvingade intents).
Spelas en gång, hoppbar från titeln. Man kan inte dö: HP 0 ger 1 HP kvar och
kärrans replik. Varje rum tänder sin `Reveal`-flagga; hela våningen spelas
igenom headless av `Policy.lookahead` i testet.

**D. Chalkrim** – `src/core/meta.gd` + `src/game/town/`

Pips, Skrotmarknaden (fast prislista, köper **innehåll** till belöningspoolen,
aldrig en statsiffra), Kritväggen (kodex, rekord, ett kritstreck per död som
suddas vid vinst), Marrows 20 dödsrepliker, `GO DOWN` alltid i tumzonen.
Profilen ligger i `user://meta.json`, skild från sparfilen: "Reset save" suddar
aldrig kritväggen. **Presentationen är en tillfällig meny** – sidoscroll-remsan
utgick när riktningen bytte till first person (PM 2026-09-21).

**E. Smedjan** – `src/core/forge.gd`

`swap_faces()` och `reorder_slots()`, byte och omordning, **aldrig tillägg**.
Invarianten (multimängden av sidor respektive slot-typer är oförändrad) är
testad, liksom att en ogiltig ordning lämnar brädet orört.

**F. Kroppsval** – `src/game/smith/choose_smith_screen.tscn`

Två porträtt sida vid sida, inga könsord i texten, valet sparas i `Settings` och
kan bytas i staden. `HeroFigure` fick lagret `hair` under all gear;
`smith_body_<a|b>` + `smith_hair_<a|b>` byts som ett par. Porträttramen är
byggd för att återanvändas i ett character sheet.

**G. Språk** (PM/Anders 2026-09-21)

`Settings.locale` defaultar till `"en"` och `GameController.boot()` sätter det
före första skärmen. Godot valde annars OS-språket, och en svensk telefon
startade spelet på svenska. Svenska är ett val, inte ett utfall.

**Mätvärden vid leverans** (Godot 4.6.stable):

| Mätning | Resultat |
|---|---|
| gdUnit4 | **339/339 gröna**, 0 fel, 0 orphans |
| Rökprov en/sv | SMOKE OK, 24 skärmdumpar vardera, kroppsval → våning 0 → staden → run → staden |
| Kvittots invariant | 50 seedade lägen: `RÅ = skada + rustning + ward + laddning + spill` |
| Kolumnhöjd, stridsskärm | 1 797 av 1 848 px (testad grind, `tests/test_combat_layout.gd`) |

## M4 – Android: APK ur CI, sidoladdning, mobil-livscykel (2026-09-21)

Milstolpen som gör spelet till en app. Ingenting i spelreglerna ändras.

**A. Projekt och paket**

- `project.godot`: version 0.1.0, boot splash i `surface/pit` (`#0E1216`) utan
  Godot-logga, `emulate_mouse_from_touch` på och `emulate_touch_from_mouse` av,
  och `quit_on_go_back=false` – standardvärdet stänger appen tyst på Androids
  bakåtknapp.
- `export_presets.cfg` (handskriven): **Android Debug** (APK, förbyggd mall,
  arm64-v8a + armeabi-v7a, `se.pipwreck.game`, immersive, enda behörigheten
  VIBRATE) och **Android Release** (AAB, gradle, min 24 / **target 36**,
  signerad ur `GODOT_ANDROID_KEYSTORE_RELEASE_*`). Varje icke-självklar rad är
  motiverad i `docs/ANDROID.md` §3.
- `tools/gen_icons.py`: adaptive foreground/background 432×432, monokrom layer
  för Android 13+ och legacy 192×192, PIPWRECK-tärningen i krit-stil ur
  UI_GUIDE-paletten. Deterministisk SDF-rastrering ovanpå `tools/pixel_png.py`.
  Utan den monokroma layern skickar Godot med sin egen Godot-logga.
- `tools/godot_editor_settings.sh`: skapar debug-keystoren med `keytool` och
  skriver `editor_settings-4.6.tres`. Keystores committas aldrig.

**B. CI (`.github/workflows/android-debug.yml`, `test.yml` orörd)**

- `apk-debug` på varje push som rör `rogelike_app/**`, alla grenar: JDK 17,
  bara `platform-tools` + `build-tools;35.0.1` (utan gradle-bygge behövs inte
  mer), cachad Godot-binär och cachade export templates (~1 GB), artefakt
  `pipwreck-debug-apk` i 30 dagar, storlek/sha256/paketnamn i job summary.
- `aab-release` bara på `workflow_dispatch`, med NDK 28.1.13356709 och
  platforms 35/36. Hoppas över med en tydlig notis när signerings-secrets
  saknas.

**C. Mobilanpassningar i koden**

- `src/platform/safe_area.gd`: skärmurtag räknat från skärmpixlar till
  viewport-enheter. Ren funktion, takad, nonsenssäker. `GameScreen` lägger
  insetet på `Margin` efter `enter()`.
- `GameController.back_action()`: ren funktion för bakåtknappen. Stäng modal >
  hoppa till kedjans slut > öppna inställningar > tillbaka till titeln.
  **Ingen gren avslutar appen**, och ett test går igenom alla kombinationer.
- `NOTIFICATION_APPLICATION_PAUSED` → autosave + `Juice.suspend_audio(true)`.
  Sparningen hoppas över mitt i en runda: ett omkast har redan rullat
  slumpströmmen förbi det sparade stridsläget. Pausen släpper också en
  pågående hit-stop, annars vaknar appen med `time_scale` 0,04.

**D. Verifierat**

- 247 tester gröna (`+20` i `tests/test_android.gd`), 0 fel.
- Rökprov under Xvfb: `SMOKE OK`, seed 7, WIN, 4 rum, bästa kedja 102.
- `godot --headless --export-debug "Android Debug"` med templates 4.6.stable
  installerade faller **bara** på saknad Android SDK (`Missing 'platform-tools'
  directory`, `Missing 'build-tools' directory`) – inte på preset, mallar,
  ikoner eller projekt.
- Licenscheck 93/93.
- **Inte verifierat här:** att APK:n byggs och signeras, gradle/AAB-vägen,
  haptik och bildfrekvens på riktig telefon. Kräver runnern respektive Anders
  telefon.


## M2 – Juice: kedjan ska kännas (2026-09-21)

Milstolpen som avgör dopaminloopen. Ljud, haptik, hit-stop, skak, blixt och
siffror är inte längre stubbar, och de två skärmar som saknades (titel och
inställningar) finns.

**A. Juice-motorn (`src/game/juice/juice.gd`, autoload)**

- Enda stället i projektet som rör `AudioStreamPlayer`,
  `Input.vibrate_handheld` och `Engine.time_scale`. Åtta ljudkanaler, lat
  laddning ur `assets/sfx/<namn>.wav` med cache, **ett saknat ljud är tyst,
  räknat och varnar en gång** – aldrig en krasch.
- `hit_stop(ms)` taket 90 ms, aldrig staplat, halverat i reducerad rörelse.
  `shake(strength, ms)` på `CanvasLayer.offset` med avklingning, helt av i
  reducerad rörelse. `flash()` byts mot en 2 dp kontur i samma läge.
- **Number pops är poolade** (24 etiketter + 8 konturer i ett eget
  `CanvasLayer`) och animeras i `_process` mot `PackedArray`-fält: noll
  allokeringar per bildruta i uppspelningen.
- Tonhöjdsregeln `pow(2, min(step, 12)/12)`, ±2 % variation på de cues som
  spelas flera gånger per runda (`assets/sfx/README.md` §3.4), ur en visuell
  slumpström som aldrig rör den seedade `Rng`.
- Haptik 15/30/60 ms (PM:s M2-brief; UI_GUIDE §5 sa 10/20/30, vilket ligger
  under vibratorns tröskel). Två pulser inom 90 ms slås ihop (§12.5).

**B. Feedback per event (`event_player.gd`)**

- `EventPlayer.feedback(event, step, hop)` är en **ren statisk funktion** och
  hela §5/§12-tabellen: ljudfil, tonhöjd, mix-dB, haptiknivå, hit-stop och
  skak. Uppspelaren spelar den själv; skärmen ritar bara det som kräver en nod.
- Överflödshopp är en **sidokanal** (§12.2) och byter cue till
  `damage_overflow`, +2 halvtoner per hopp. Döden sänks två halvtoner.
  `die_cracked` stiger inte alls – mönsterbrottet i §5.6 är hörbart.
- Tidslinjen går i **oskalad tid**: hit-stoppen ligger inuti eventets `ms_hint`
  (§12.2) i stället för ovanpå, annars spräcker tre combos budgeten.
- Ett test spelar upp referensrundan i §12.3 och kräver **exakt 2 400 ms**.

**C. Krit-UI, ögonblick och tillgänglighet**

- `ChalkFx` lägger `chalk.gdshader` på paneler, knappar och display-siffror.
  Reducerad rörelse ⇒ `jitter_speed = 0`; hög kontrast ⇒ `erosion = 0.10`.
- Kedjetexten dras vänster→höger medan kedjan spelas (synlig kausalitet).
- Bossintro (namnskylt, ≤ 1,2 s, tappbar), vinst (kritkonfetti + uppräkning),
  död ("It was your call." + vad som dödade dig + meta-poäng + 72 dp
  EN RUN TILL), och **NEW BEST** när en kedja slår runnens rekord.
- **Hög kontrast+ är en riktig token-override** (UI_GUIDE §2.11), inte en stubb:
  `Tokens`-färgerna är statiska variabler, så tabellen byts utan att ett enda
  anropsställe ändras.

**D. Titel, inställningar och sparat**

- `title_screen.tscn` (CONTINUE / NEW RUN / SETTINGS) och
  `settings_screen.tscn` som **modal** – den öppnas mitt i en runda utan att
  placeringen kastas. Språkbytet är live.
- `src/platform/settings.gd` (autoload `Settings`) skriver `user://settings.cfg`.
  En trasig fil ger standardvärden, aldrig en halvläst uppsättning.

**E. Assets från UI-agenten, inkopplade**

- Fiendearken har två rader: `Art.enemy_frames()` skär ut en icke-loopande
  `death`-animation (3 frames, 10 fps = 300 ms, inom §5.5:s 360 ms).
- Reliklagren i paperdollen tänds (alla sex reliker), `legs` tillkom.
- Tärningarna ritas åter som **gråskalemaster + 16×1-LUT** sedan shaderns
  dubbelmultiplikation mot modulate är fixad.

**Verifierat:** 227 gdUnit4-tester gröna. Rökprov under Xvfb i `en`, `sv` och
med `reduced_motion = true` plus en dödskörning; 14 ljud laddade, 0 saknade;
skärmdumpar i `docs/screenshots/m2/`.

## M1.5 – Engelskt källspråk och pixelgrafik (2026-09-21)

Två leveranser i en: all spelartext är engelska i källan och går via `tr()`, och
platshållarna i `World`-lagret är utbytta mot de riktiga sprajterna.

**A. i18n**

- **Källspråk engelska.** Fem skärmar, `ui/tokens.gd`, `src/data/content.gd`,
  `src/core/reward_apply.gd` och `tools/smoke_play.gd` skriver engelska. Namn är
  spelengelska, inte ordagrant översatta: Giftdroppe → Venom Drop, Slaggmal →
  Slag Moth, Ögontjuven → Pip Thief, Smeden → The Smith.
- **`assets/i18n/translations.csv`** (`keys,en,sv`, 118 rader) registrerad i
  `project.godot` med `locale/fallback = "en"`.
- **Innehåll översätts på id.** `Content.enemy_key()` / `face_key()` /
  `relic_key()` / `slot_swap_key()` / `class_key()` ger nyckeln;
  `Tokens.translate_or()` faller tillbaka på det engelska källnamnet om raden
  saknas, så ett nytt innehålls-id aldrig visas som rå nyckel.
- **Core innehåller inte längre prosa.** `Intent.note` är en nyckel plus
  `note_args`; `RewardApply.describe()` bygger sin mening av nycklar.
- **`tests/test_i18n.gd`** skannar `src/` med RegEx och fäller bygget på en
  `tr()`-nyckel utan CSV-rad, en tom `en`- eller `sv`-cell eller en dubblett.

**B. Sprites**

- **`src/game/ui/art.gd`** är enda stället i `src/game/` som känner ett filnamn:
  fiendeark, paperdoll-lager, relik→lager-tabellen, tärningskroppar, LUT:ar,
  slot- och nodikoner, parallax. Plus heltalsmatematiken (`fit_scale`, `snap`).
- **Strid:** `EnemyActor` är en `AnimatedSprite2D` med fyra idle-frames (boss
  48×48, övriga 32×32, ×4), parallax och golvkakel bakom, Smeden som paperdoll
  till vänster. Fienderna står på panelernas konsthåll-underkant, så alla delar
  golvlinje oavsett cellstorlek.
- **`DieArt`:** kropp + pips/glyph + glaskant + spricka, heltalsskala, både i
  brickan och i sloten. `SlotView` och `RewardCard` fick slot-, nod- och
  relikikoner; belöningskortet komponerar den smidda sidan.
- **Paperdoll:** `HeroFigure` har nio lager i PAPERDOLL §2:s z-ordning och en
  `AnimationPlayer` som driver `frame_index` (idle/walk/attack/hit, Discrete).
  `apply_relics()` implementerar kollisionsregeln i §3 (högst rarity vinner,
  sedan senast plockad; utrustning slår relik).
- **Kedjan:** `die_activated` blixtrar den riktiga tärningen i sloten och i
  brickan och låter Smeden svinga, `damage_dealt` blixtrar fiendesprajten,
  `enemy_killed` tonar ut. Tidsbudgeten (2 500 / 3 200 ms) är orörd.
- **Skärmdumpar:** `docs/screenshots/m1_5/`, samma sex vyer, engelska.

Mätvärden vid leverans (Godot 4.6.stable, x86_64):

| Mätning | Resultat |
|---|---|
| gdUnit4 | 188 tester, 0 fel, 0 failures |
| Rökprov (default, en) | SMOKE OK, 6 skärmdumpar, vinst på seed 7 |
| Rökprov (`--locale=sv`) | SMOKE OK |
| Licenscheck | 60/60 registrerade, own-work |

**Avvikelse (rapporterad):** `palette_lut.gdshader` skriver i GL Compatibility
ut sitt resultat utan sRGB-konvertering. En sprite med `lut_strength = 0`
renderas som `srgb_to_linear(källan)` (uppmätt: `#C2451D` → `#941203`) och
LUT-vägen landar ~24 % för mörkt. Tärningarna ritas därför med de förtintade
kropparna (`die_body_{iron,bone,glass}.png`), som renderas 1:1, i stället för
gråskalemastern + LUT. Shadern används fortfarande för träffblixten, där
mörkningen inte syns eftersom bilden ändå lerpas mot vitt. Kompositionen och
filuppsättningen är oförändrade; när shadern är fixad är det en rad i `Art`.

## M1 – Vertical slice (2026-09-21)

Våning 1 går att spela igenom i portrait med platshållargrafik: marsch → strid →
belöning → marsch → boss → död/vinst → ny run.

- **Scenarkitektur:** `src/game/main.tscn` med `Backdrop` (−10), `World`
  (Nearest, pixelsprites) och `ChalkUI` (Linear, krit-UI) enligt research 04 §5.
  `GameController` äger `RunState`, byter skärm uppskjutet och autosparar.
- **Autosave:** `src/platform/save_io.gd` → `user://save.json`, versionerad,
  skriven via temporärfil + namnbyte. Trasig fil ⇒ ny run, aldrig krasch.
  Återupptagning sker alltid vid en rundgräns, med RNG-strömmens position.
- **Ny core (ren, testad):** `run_graph.gd` (nodgraf per våning, seedad,
  förgrening i rum 3), `run_flow.gd` (rumsstart, Andrum, belöningsnyckel),
  `reward_apply.gd` (deterministiskt målval + beskrivning + tillämpning),
  `reroll.gd` (roll-fasen: `LOCKED`, `REFUND_REROLL`, `rerolls_left`),
  `meta_score.gd` (meta-poäng och kedjeskada per runda).
- **Stridsskärm:** fiendezon, fem slots med typ/värde/multiplikator, tumzon med
  sex tärningar, OMKAST · ÅNGRA · BEKRÄFTA. Drag och tapp-tapp likvärdiga, fri
  ångra, bekräfta med tomma slots tillåtet (§7 fråga 4). Förhandsvisningen körs
  med en riktig `Resolver.resolve()` på en kopia och asserteras byte-identisk
  mot utfallet vid bekräftelse (§6.3).
- **Uppspelare:** `event_player.gd` som överlappande tidslinje i tre banor
  (CHAIN/BEAT/SIDE), inte en kö. Placeholder-juice: skalpuls, number pop, skak,
  combo-blink. `Juice.sfx()` och `Juice.haptic()` är stubbar som loggar.
- **Belöning, marsch, död/vinst:** 1 av 3 med sällsynthetsfärg + ramform + ord;
  sidoscroll-marsch med två parallaxlager och paperdoll-riggad figur, två stora
  knappar vid förgrening; slutskärm med rum nått, största kedja, meta-poäng och
  "EN RUN TILL".
- **Rökprov:** `tools/smoke_play.gd` spelar en hel run genom UI:t med
  Lookahead-policyn, tar fem skärmdumpar och avslutar 0.
- **Dokumentation:** `docs/ARCHITECTURE.md` (scenträd, bytesplatser för
  pixelgrafik, uppspelarens tidslinje, run-loop, autosave, rökprov).

Mätvärden vid leverans (Godot 4.6.stable, x86_64):

| Mätning | Resultat |
|---|---|
| gdUnit4 | 160/160 gröna, 0 fel, 0 orphans, 1 929 ms |
| Rökprov headless, seed 7 | VINST, 4 rum, 13 rundor, största kedja 102, exit 0 |
| Rökprov xvfb 1080×1920, seed 7 | 6 skärmdumpar, exit 0, inga fel eller varningar |
| Kedjan (P0–P3) för sex tärningar, okomprimerad | 2 348 ms (tak 2 500) |
| Naiv FIFO-kö för samma runda | 6 360 ms |

Buggar som rökprovet hittade och som inget logiktest kunde hitta: skärmbyte
inifrån `_process` (segfault), `World`-lagret helt dolt bakom krit-bakgrunden,
och etiketter som tryckte hela kolumnen utanför 1080 px.

## M0 – Setup (2026-09-21)

Godot 4.6-projekt, seedad och testbar core, headless-CI.

- **Projekt:** `project.godot` (PIPWRECK, portrait 1080×1920, mobile renderer,
  `canvas_items`/`expand`), `.gitignore` för Godot, mappstruktur enligt
  `research/02_tech_stack.md`, minimal `src/game/main.tscn`.
- **Testramverk:** gdUnit4 v6.2.1 vendorerad i `addons/gdUnit4/`, körs headless.
- **Core:** `rng.gd` (seedad ström med `state()`/`restore()`), datamodellerna ur
  GAME_DESIGN §2.1 (`Rules`, `Face`, `Die`, `Slot`, `Board`, `Intent`, `Enemy`,
  `Relic`, `CombatState`, `RunState`) med `to_dict()`/`from_dict()`,
  `resolver.gd` (faserna P0–P5, ingen RNG, muterar inte indata),
  `rewards.gd` (3 alternativ, vikter och garantier ur §4.7),
  `policy.gd` (Greedy + Lookahead).
- **Innehåll:** `src/data/content.gd` med M1:s sidor, reliker, slot-byten,
  fiender, möten och Smedens startuppsättning.
- **Tester:** 85 gdUnit4-fall i 5 sviter – determinism, renhet, RNG-state,
  serialisering, de åtta räkneexemplen i §2.4, eventlogg-invarianterna i §3 och
  belöningsgarantierna i §4.7.
- **Simulator:** `tools/run_simulator.gd` kör N seedade strider och/eller hela
  runs per policy och skriver vinst%, rundor/strid, combo-, överflöds- och
  Charge-frekvens, kåkar, explosionsfrekvens samt greedy-vs-lookahead-deltat.
- **CI:** `.github/workflows/test.yml` – Godot 4.6 headless, gdUnit4 med
  JUnit-output, simulatorn, artefakter.
- **Dokumentation:** `docs/ARCHITECTURE.md`.

Mätvärden vid leverans (Godot 4.6.stable, headless, x86_64):

| Mätning | Resultat |
|---|---|
| gdUnit4 | 85/85 gröna, 0 fel, 0 orphans, 916 ms |
| 1 000 strider, GreedyPolicy | 0,55 s |
| 1 000 strider, LookaheadPolicy (width 8) | 4,66 s |
| 200 hela runs, greedy → lookahead vinst% | 80,5 % → 94,5 % (+14,0 p.e.) |
| 300 bossstrider, greedy → lookahead vinst% | 63,0 % → 100,0 % (+37,0 p.e.) |
| `resolve()` | 244 µs (efter copy-on-write-optimering, från 319 µs) |

## 2026-09-21 – Balanspass våning 1 (GAME_DESIGN §4.9)

Rum 1–3 vanns på en runda av båda policyerna; hela beslutssignalen låg i bossen.
Endast tuningbara siffror ändrade (§4.8): spelarens HP 60 → 100, `BREATHER_HEAL`
4 → 10, fiende-HP ×1,7–2,0, `armor` höjd på nästan alla (`IRON_TICK` 2 → 6 som
rustningsmur), rum 1 och 2 fick fler fiender, boss 150/2/7 → 210/3/7.
Simulatorn fick andrumsläkningen från §1 (saknades) och rapporterar nu HP kvar.

| Mätning | Före | Efter |
|---|---|---|
| Rundor per `COMBAT` (lookahead, rum 1/2/3) | 1,15 / 1,62 / 1,83 | 3,06 / 3,10 / 3,36 |
| Rundor mot boss (lookahead) | 3,72 | 5,62 |
| HP kvar efter rum 2, greedy → lookahead | 0 p.e. skillnad | 72,4 → 84,7 |
| Hel run (våning 1), greedy → lookahead | 63,3 % → 77,3 % (+14,0 p.e.) | 48,7 % → 94,0 % (+45,3 p.e.) |
| gdUnit4 | 85/85 | 85/85 gröna, 0 fel, 0 orphans, 919 ms |

Kvarstående avvikelser mot §5 (`house_bonus`/run, combo-andel, explosionsfrekvens)
är mätinstrument, inte innehåll: se §4.9 sista stycket.

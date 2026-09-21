# Changelog

Format: en rad per leverans. Nyast överst.

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

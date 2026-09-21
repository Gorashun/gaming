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

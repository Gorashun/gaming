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
- **M1.5 i18n-pass.** Beslutet "engelska som källspråk, svenska via `tr()`"
  (DECISIONS 2026-09-21) fattades efter att M1:s skärmar byggts. All spelartext
  i `src/game/` är därför svenska literaler. Konverteringen är mekanisk och rör
  fem filer plus `ui/tokens.gd` (slot- och sällsynthetsnamn) — inga strängar är
  utspridda i logiken, och kedjetexten byggs redan på ett ställe
  (`CombatScreen.chain_text`).
- **Fiendezonen rymmer fyra fiender**, inte tre som M1-briefen antog: rum 1 är
  fyra Rostråttor (§4.4). Panelerna fördelar bredden dynamiskt.

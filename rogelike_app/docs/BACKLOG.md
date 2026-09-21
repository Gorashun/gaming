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

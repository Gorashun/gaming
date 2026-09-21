# Beslutslogg

Format: datum · beslut · varför · alternativ som valdes bort · beslutad av

| Datum | Beslut | Varför | Bortvalt | Av |
|---|---|---|---|---|
| 2026-09-21 | Projektstruktur i `rogelike_app/`, agentteam i `.claude/agents/` | Anders begäran | – | Anders |
| 2026-09-21 | Regler: inga lootboxar för pengar, inga timers, inga statboost-meta, offline-first, seedad testbar core | Communitykrav + kommande EU-reglering (research 01, 03) | F2P-stat-grind (Archero-modell) | PM (förslag, i linje med Anders krav) |
| 2026-09-21 | Koncept B (tärnings-autobattler med agens) | Se PROPOSAL.md §2 | A Handen (deckbuilder), C Grottan (grid-crawler) | Anders |
| 2026-09-21 | Titel: **PIPWRECK** (arbetstitel, engelsk) | Pip = tärningsprick, wreck = haveri. Inga sökträffar 2026-09-21. "Dicefall" (Steam) och "Pipfall" (brädspel, Fallout) är tagna. Varumärkes- och butiksnamnskontroll krävs före lansering. Notera konkurrent: brädspelet "Rolling Deep" (Bitewing, 2027) är Balatro-inspirerad tärningsroguelike | Kastgropen, Dicefall, Pipfall, Rolldeep, Deadroll | Anders (titel vald av PM på Anders uppdrag) |
| 2026-09-21 | Godot 4.6 + typed GDScript, plan B Flutter + Flame. Omprövas vid vecka-1-retro | Se PROPOSAL.md §5 | Unity, RN/Expo, Capacitor + PixiJS | Anders |
| 2026-09-21 | **VÄNTAR:** Affärsmodell (premium vs gratis utan annonser) | Kan vänta till M4 | Annonser, IAP | Anders |
| 2026-09-21 | Resolutionsordning P0 ROUND_START → P1 VALUE → P2 COMBO → P3 STRIKE → P4 ENEMY → P5 ROUND_END; `resolve()` tar ingen RNG, slump ligger i `advance()` | Gör kedjan 100 % förutsägbar före bekräftelse (helig regel) och testbar | Slump i resolve | Rollspelsnörd (GAME_DESIGN.md §2), godkänt av PM |
| 2026-09-21 | `VOID`-slot = sköld (ger Ward), inte "död slot" | M1 saknade annars defensivt verktyg | Void som tar bort slot (research 03) | Rollspelsnörd, godkänt av PM |
| 2026-09-21 | Kåk = 3-grupp + 2-grupp med olika värden, brädbonus ×2; två par ger ingen bonus i v1 | Enkelhet, läsbarhet | Yatzy-kåk | Rollspelsnörd, godkänt av PM |
| 2026-09-21 | Stoppregel: GreedyPolicy ska vinna ≥ 10 procentenheter sämre än LookaheadPolicy i simulatorn. Annars är placeringen meningslös och designen görs om före M2 | Mäter om spelet är ett beslutsspel eller ett slot-spel | – | PM |
| 2026-09-21 | **VÄNTAR:** Ska sprickor på glastärningar vara run-permanenta? (M3, brutalaste regeln) | Se GAME_DESIGN.md §7 | – | Anders |
| 2026-09-21 | Visuell riktning A "Kritgropen" (krita på skiffer, en shader bär identiteten). B "Risotryck" parkeras som upplåsningsbart tema, C avfärdas | Högst kontrast (14,8:1 text), kritstreck vänster→höger = synlig kausalitet, billigast utan grafiker, ingen kasino-estetik | B, C (se UI_GUIDE.md) | UI, godkänt av PM. Anders kan veto:a efter att ha sett wireframes |
| 2026-09-21 | Reducerad rörelse-läge och färgblindspalett flyttas in hårt i M2 (var "om tid finns") | Billigt från start, dyrt att retrofitta | Backlog | PM |
| 2026-09-21 | Uppspelaren av händelseloggen byggs som överlappande tidslinje, inte FIFO-kö | Naiv summering ger 3,1 s per runda, taket är 2,5 s | FIFO | UI, godkänt av PM |

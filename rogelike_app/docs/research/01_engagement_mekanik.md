# 01 – Engagemangsmekanik i roguelikes: vad skapar "en run till"?

**Ägare:** rnd-roguelike · **Datum:** 2026-09-21 · **Status:** underlag till PM (beslut fattas i DECISIONS.md)

Källor anges som `[n]` med URL och datum i slutet. Fakta = källbelagt. **Uppskattning** = egen bedömning, markerad.

---

## Fråga
Vilka konkreta mekaniker gör Balatro, Slay the Spire, Vampire Survivors, Hades, Dead Cells, Shattered Pixel Dungeon, Brotato, Luck be a Landlord och Dicey Dungeons så svåra att lägga ifrån sig – och vad av det överlever på mobil, för 13+, utan dark patterns?

## Slutsats (först)
1. **Dopaminkicken sitter i belöningsvalet, inte i loot.** Alla nio spelen levererar sin "kick" som ett *val mellan 3–4 slumpade alternativ* var 30–90:e sekund (kort, joker, vapen, boon, symbol). Variationen är variable-ratio i praktiken, men spelaren äger beslutet → ingen gambling-känsla, inga loot boxes.
2. **Synergiexplosionen är toppen på kurvan.** Balatro, LBaL och Vampire Survivors bygger på att 2–3 vanliga delar plötsligt multiplicerar varandra. Det är "ibland segt, plötsligt askul"-känslan Anders beskriver. Den kräver *synligt orsakssamband* (Balatro pulsar varje joker i tur och ordning, ~300 ms per steg [1]).
3. **Run-längd på mobil: 5–15 min, med "checkpoints" var 60–90 s.** Median-session på mobil är 3,1–3,5 min; topp-10 %-spel når ~8 min [10]. Brotato (15–20 min, 20 vågor à 20–90 s) och Hoplite/Card Crawl (3–8 min) är mobil-vinnarnas format. Slay the Spire (45–90 min per run) fungerar på mobil bara för att den *pausar perfekt* mellan varje beslut.
4. **Meta-progression ska ge nytt *innehåll*, inte stat-boosts.** Dead Cells (cells → nya items i poolen), Hades (Mirror + berättelse), Balatro (jokers/decks låses upp av *prestationer*) belönar förlust med *mer variation nästa run*. Stat-boosts (Archero, Survivor.io) fungerar kommersiellt men leder rakt in i pay-to-win-logik vi valt bort.
5. **Mobil-vinnare är byggda för tummen, inte portade.** Premium-porter säljer (Dead Cells 5 M ex på mobil [17], Balatro ~4,4 M USD på två månader [14]) när UI:t görs om. StS-porten kritiserades för avklippt korttext och "inscrutable icons" [16] – samma spel, sämre mottagande.
6. **Juridik är hanterbar för ett offline-spel utan köp:** Apple 13+ tillåter "infrequent simulated gambling" och "frequent cartoon/fantasy violence" [21]; Google Play kräver IARC-enkät + Data safety + privacy policy oavsett [24][25]; GDPR blir relevant först med leaderboard (samtyckesålder 13–16 beroende på land) [27].

---

## Evidens

### A. Mekaniker per spel (namngivna)

| Spel | Kärn-kick | Frekvens | Meta-progression | Run-längd | Lärdom för oss |
|---|---|---|---|---|---|
| **Balatro** | Poängexplosion: joker-kedja pulsar sekventiellt, siffror hoppar, ljudets tonhöjd stiger med poängen [1][2] | Varje spelad hand (10–20 s); shop efter varje blind | 150 jokers/decks/vouchers låses upp via *utmaningar*, inte grind [3] | ~30–60 min per run (uppskattning); första vinst ~4 h [4] | Visa orsakssambandet visuellt. Belöna *hur* du vann, inte att du vann. |
| **Slay the Spire** | Kortval 1 av 3 efter varje strid; relics som byter spelregler | Var 1–3 min | Poäng från *både* vunna och förlorade runs låser upp kort/relics/karaktärer [5] | 45–90 min, men naturliga pauser varje beslut | Förlust ska ge unlock-poäng. Balans via metrics (GDC 2019: intern metric-server, veckovisa uppdateringar) [6]. |
| **Vampire Survivors** | Level-up-val 1 av 3–4 var 20–40 s; kistor med slot-animation; evolutions | Extremt tät (sek) | Guld → permanenta stats + karaktärer/kartor | 30 min hård gräns → near-miss varje gång du dör på 27 min [7] | Poncle kom från spelautomat-industrin och använde "near-miss" och kist-slot medvetet [7][8]. Vi använder near-miss-*strukturen* (tidsgräns, "en våg kvar") men inte pengainsats. |
| **Hades** | Boon-val från en gud var 1–2 min; narrativ belöning vid *död* | Var 1–2 min + återkomst till hubb | Mirror of Night (Darkness + Chthonic Keys), Death Defiance = extra liv; berättelsen fortsätter *för att* du dog [9] | 25–40 min | "Ta bort smärtan i att dö" (Kasavin). Ge något *nytt* efter varje död, även om det bara är en textrad. |
| **Dead Cells** | Vapen/mutation-val, flow-baserad strid | Var 1–2 min | Cells → items läggs i poolen (mer variation, inte mer styrka); Boss Cells = frivillig svårighet [11] | 30–60 min | Unlock = *variation*, inte *makt*. Synligt "rum som fylls" ger fysisk känsla av framsteg. Varning: "awkward middle" när poolen är halvfylld [11]. |
| **Shattered Pixel Dungeon** | Identifiera okända items (potions/scrolls), risk/belöning per våning | Var 30–60 s (turbaserat) | Badges + klasser/subklasser; inga stat-boosts | 30–90 min, men turbaserat → pausbart var som helst | 5 M nedladdningar, ~150 k sålda, solo-dev heltid [12]. Transparent patch-kommunikation bygger community [13]. Portrait, en hand. |
| **Brotato** | Shop efter *varje* våg; item-synergier | Våg 20–90 s → belöning var ~1 min | 44+ karaktärer och svårighetsnivåer låses upp av att vinna [15] | 15–20 min | Perfekt mobilformat: kort våg, shop = naturlig paus. Brotato är byggt i Godot. |
| **Luck be a Landlord** | Slot-spin med egna symboler; symbol-synergier | Varje spin (5–10 s) | Nya symboler/items låses upp | 15–30 min | Balatros "largest influence" [18]. Visar att slot-*estetik* utan pengar går bra (PEGI 12 för Balatro efter överklagan) [19]. Kritik: låg agens ("inflexible") [20] → vi behöver mer beslut per spin än LBaL. |
| **Dicey Dungeons** | Tärningar som *resurs* man manipulerar, inte slump som styr | Varje strid | Nya karaktärer/episoder | 20–40 min | RNG-mitigering: ge spelaren verktyg att "hacka" slumpen så förlust känns som eget fel, inte otur [22]. |

**Gemensam nämnare (branschkonsensus):** täta *val* (inte täta *drops*), synlig kausalitet i synergier, och att förlust konverterar till något permanent (unlock-poäng, story, ny variation).

### B. Psykologi – vad forskningen faktiskt säger
- **Variable ratio (VR)**: belöning efter oförutsägbart antal handlingar ger högst svarsfrekvens och störst motstånd mot utsläckning (Skinner; översikt i [23]). I roguelikes är det *kvaliteten* på belöningen som varierar (vanligt/sällsynt kort), inte om du får en.
- **Near-miss**: "nästan vinst" aktiverar samma belöningskretsar som vinst och ökar motivationen att fortsätta; effekten är robust i spelautomat-studier [8]. I VS uppstår den naturligt av 30-minutersgränsen [7]. **Etisk gräns (egen bedömning):** near-miss får uppstå ur *spelarens* prestation (dog med bossen på 5 % HP), aldrig ur en manipulerad slump.
- **Losses disguised as wins** och pity-timers är gambling-mekaniker som *inte* behövs när belöningen är ett val.

### C. Mobil: sessioner, retention, unlock-takt
- **Retention (GameAnalytics, 11 600 spel, 2025):** median D1 ≈ 22 %, D7 < 4 %, D30 ≈ 0,7–0,8 %; topp-1 % har D1 64–68 % och D30 13–15 %; topp-25 % D1 26–28 % [10]. iOS topp-25 % D1 31–33 % vs Android 25–27 % [10]. Bästa genrer för lång retention: brädspel, kort, pussel, casino [10]. **Inga publika roguelike-specifika benchmarks hittades** – uppskattning: ett premium/offline-roguelike utan LiveOps bör sikta på D1 ≥ 35 %, D7 ≥ 12 %, D30 ≥ 5 % (jämför "top 25 %").
- **Sessionslängd:** median 3,1–3,5 min; topp-25 % 5,2 min; topp-10 % ~8 min; topp-25 % spelar 5,3–5,7 sessioner/dag [10][26]. Konsekvens: en run måste kunna *avbrytas och återupptas* utan förlust (autosave varje tur/våg), och ge en tydlig belöning inom 60–90 s.
- **Unlock-takt (uppskattning från spelen ovan):** något nytt permanent var 1–2 run de första 10 runs, sedan glesare men större (ny karaktär/deck). Dead Cells "awkward middle" [11] undviks genom att unlock-poolen är liten från start (~40 items) och växer i *paket* som byter spelstil.
- **Kommersiella bevis på mobil:** Balatro 1 M USD första veckan, ~4,4 M USD efter två månader, premium 9,99 USD utan IAP [14]; Dead Cells > 5 M sålda på mobil [17]; Vampire Survivors mobil gratis med annonser, 5,1 M nedladdningar på tre månader [28]; Soul Knight > 100 M installationer, 4,59/5 på 1,6 M betyg [29]; Archero ~35 M USD IAP på tre månader [30]; Survivor.io > 500 M USD IAP, 80 M+ installationer [31]. De två sista är F2P-stat-grind med IAP – kommersiellt starkast, men utanför våra regler.

### D. Mobil-vinnare vs floppade PC-porter
| Vinner på mobil | Varför |
|---|---|
| Hoplite (7DRL 2013, hex-arena, fast storlek) | Hela brädet syns på en skärm, ett tryck = ett drag, ingen "bump-to-attack"-spam [32] |
| Card Crawl / Dungeon Cards | 3×3-grid, portrait, en tumme, 3–5 min |
| Shattered Pixel Dungeon | Portrait, stora tryckytor, turbaserat = pausbart |
| Brotato / Soul Knight | Auto-aim eller auto-attack – en joystick räcker |
| Balatro / Dead Cells (porter som lyckats) | UI omgjort för touch, premium utan IAP, autosave |
| **Kritiserat:** StS mobil | Avklippt korttext, små ikoner, ingen save-sync mellan enheter vid lansering [16] |

**Mönster:** vinnarna har (a) ett bräde/en arena som ryms på en portrait-skärm, (b) max ett beslut per tryck, (c) ingen precisionsinput, (d) autosave var tur. Porter floppar när text/ikoner designats för 1080p-monitor.

### E. Etik och juridik (kort)
- **Apple App Store:** nya nivåer 4+/9+/13+/16+/18+ (juli 2025, obligatorisk enkät senast 2026-01-31) [21]. 13+ tillåter *infrequent* simulated gambling och *frequent* cartoon/fantasy violence; *frequent* simulated gambling ⇒ 18+ [21]. **Konsekvens:** slot-liknande visuell estetik (à la LBaL) riskerar 18+. Balatro fick PEGI 18 → sänkt till PEGI 12 efter överklagan; PEGI ser nu över policyn [19]. Vi bör undvika hjul/spakar/"777" och istället använda kort/tärning/synergier.
- **Google Play:** IARC-enkät obligatorisk (ger PEGI/ESRB/USK samtidigt) [24]. Families-policyn gäller bara om målgruppen *inkluderar* barn < 13 [33]; vi deklarerar 13+ och undviker barnriktad grafik/terminologi. Data safety-formulär + länkad privacy policy krävs för *alla* appar, även offline utan datainsamling [25]. Nya personliga dev-konton: 12 testare i 14 dagar innan produktion, 25 USD engångsavgift [34].
- **Loot boxes i EU:** Belgien förbjuder betalda loot boxes som spel om pengar; Nederländerna backade 2022 och reglerar via konsumentlag; EU-parlamentets IMCO-utskott antog i slutet av 2025 (32–5–9) en rapport som kräver att Digital Fairness Act förbjuder loot boxes, in-app-valutor och pay-to-win i spel som minderåriga sannolikt använder [35]. **Konsekvens:** vår regel "inga lootboxar för pengar, inga energitimers" är redan i linje med kommande krav – behåll den.
- **GDPR:** samtyckesålder 16 som default, medlemsstater får sänka till 13 (Sverige: 13) [27]. Offline-spel utan konton = ingen personuppgiftsbehandling utöver ev. kraschrapporter. Leaderboard via Google Play Games Services / Game Center låter plattformen hantera identitet, men måste deklareras i Data safety och privacy policy. Egen backend-leaderboard ⇒ personuppgiftsansvar, rekommenderas inte för MVP.

## Osäkerhet
- Inga publika D1/D7/D30 för roguelike-genren specifikt; målen ovan är uppskattningar.
- Sessionslängd per genre varierar kraftigt mellan källor (Udonis anger 50+ min för kort/strategi [26], GameAnalytics 3–8 min median över alla spel [10]); GameAnalytics har störst dataset.
- Balatros joker-animationstid (300 ms) kommer från en designanalys, inte från LocalThunk.
- **Run-längd, avvikelse mot 03_koncept_och_community.md:** communityt anger ~30 min som ideal run (PC-perspektiv), medan mobil-sessionsdata [10] och mobil-vinnarna pekar på 5–15 min. Förslag till förening: runs på 8–15 min *aktiv* speltid uppdelade i vågor/rum à 60–90 s med autosave – turbaserat spel kan då sträckas till 20–30 min utan att bryta mot sessionsmönstret.

## Rekommendation till PM – 5 designprinciper
1. **Ett belöningsval var 60–90 s, alltid 3 alternativ, minst ett "spännande".** Motivering: det är gemensam nämnare för alla nio spelen och matchar median-sessionen på 3–5 min [10]. Valet ger agens (Dicey Dungeons-lärdomen) och gör VR-belöningen etiskt ren.
2. **Designa för synergiexplosioner och visa kausaliteten.** Motivering: Balatros och LBaL:s kick är multiplikation av vanliga delar; kicken uppstår bara om spelaren *ser* kedjan (sekventiell aktivering, stigande ljud, siffror som hoppar) [1][2]. Kräver att spellogiken exponerar en händelselogg per beräkning – bör in i arkitekturen från dag 1.
3. **Run-längd 8–15 min i 8–12 "vågor/rum", autosave varje tur.** Motivering: Brotato-formatet [15] fungerar på mobil; StS visar att längre runs bara överlever med perfekt pausbarhet [16]. Near-miss uppstår naturligt av en känd slutpunkt (VS 30 min-lärdomen [7]).
4. **Förlust ger alltid något permanent – innehåll, inte styrka.** Motivering: StS ger unlock-poäng även för förlorade runs [5], Hades ger berättelse vid död [9], Dead Cells ger nya items i poolen [11]. Stat-boost-meta (Archero) leder till pay-to-win-logik och strider mot CLAUDE.md. Sikta på "något nytt var 1–2 run" de första 10 runs.
5. **Bygg för tummen och 13+ från start: portrait, en hand, inget slot-maskineri.** Motivering: mobil-vinnarna (Hoplite, Card Crawl, SPD, Brotato) delar formatet [32]; StS-porten straffades för PC-UI [16]. Undvik hjul/spakar/"777" för att hålla Apple 13+ (frequent simulated gambling ⇒ 18+) [21] och slippa Balatros PEGI-strid [19].

---

## Källor (alla hämtade 2026-09-21)
1. Blake Crosley, "Balatro: Juicy Feedback in a Poker Roguelike" – https://blakecrosley.com/guides/design/balatro
2. cccChoice, "Balatro Design Analysis: Visual Packaging and Interactive Feedback", Medium – https://medium.com/@yyh19971004/balatro-design-analysis-visual-packaging-and-interactive-feedback-cc6fa6a65370
3. TouchArcade, LocalThunk-intervju, 2024-03-18 – https://toucharcade.com/2024/03/18/balatro-interview-mobile-port-localthunk-dlc-plans-updates-new-jokers-demo-feedback/
4. Steam Community-trådar om tid till första vinst (spelarrapporter, ej officiellt) – https://steamcommunity.com/app/2379780/discussions/
5. Wikipedia, "Slay the Spire" (unlock-poäng från vunna och förlorade runs) – https://en.wikipedia.org/wiki/Slay_the_Spire
6. A. Giovannetti, "'Slay the Spire': Metrics Driven Design and Balance", GDC 2019-03-20 – https://www.gdcvault.com/play/1025731/-Slay-the-Spire-Metrics ; slides: https://media.gdcvault.com/gdc2019/presentations/Giovannetti_Anthony_SlayTheSpire.pdf
7. The Conversation / Univ. of Portsmouth, "Vampire Survivors: how developers used gambling psychology…", 2023 – https://theconversation.com/vampire-survivors-how-developers-used-gambling-psychology-to-create-a-bafta-winning-game-203613
8. Near-miss-effekten, översikt: PMC7214505 (2020) – https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7214505/ ; Wikipedia – https://en.wikipedia.org/wiki/Near-miss_effect
9. Game Developer, "How Supergiant weaves narrative rewards into Hades' cycle of perpetual death" och GDC Podcast ep. 16 med Greg Kasavin – https://www.gamedeveloper.com/design/how-supergiant-weaves-narrative-rewards-into-i-hades-i-cycle-of-perpetual-death ; https://gdconf.com/article/roguelikes-and-narrative-design-with-hades-creative-director-greg-kasavin-gdc-podcast-ep-16/
10. GameAnalytics, "2025 Mobile Gaming Benchmarks" och "2026 Mobile & PC Gaming Benchmarks" – https://www.gameanalytics.com/reports/2025-mobile-gaming-benchmarks ; https://www.gameanalytics.com/reports/2026-mobile-pc-gaming-benchmarks ; sammanfattning: https://gamedevreports.substack.com/p/gameanalytics-mobile-gaming-benchmarks
11. Kokutech, "Studying Dead Cells' Excellent Platforming and Combat Mechanics" och Steam-diskussioner om permanent progression – https://www.kokutech.com/blog/gamedev/design-patterns/flow-state/dead-cells
12. Evan Debenham, "Ten Years of Shattered Pixel Dungeon!" (5 M nedladdningar, ~150 k sålda) – https://shatteredpixel.com/blog/ten-years-of-shattered-pixel-dungeon.html
13. TouchArcade, "Game of the Week: Shattered Pixel Dungeon", 2021-08-20 – https://toucharcade.com/2021/08/20/toucharcade-game-of-the-week-shattered-pixel-dungeon/
14. PocketGamer.biz, "Balatro approaches $1 million in seven days on mobile" och "Balatro nears $4.4m on mobile", 2024-11 – https://www.pocketgamer.biz/balatro-nears-44m-on-mobile-amid-a-sudden-spending-surge/ ; 5 M ex: https://www.gamedeveloper.com/business/balatro-sells-5-million-copies-after-end-of-year-spike
15. Wikipedia, "Brotato" (20 vågor, 20–90 s) + Brotato Wiki "Waves" – https://en.wikipedia.org/wiki/Brotato ; https://brotato.wiki.spellsandguns.com/Waves
16. TouchArcade, StS iOS-recension 2020-06-15; CBR, Android-recension – https://toucharcade.com/2020/06/15/slay-the-spire-ios-review-iphone-ipad-performance-icloud-megacrit-humble-games/ ; https://www.cbr.com/slay-spire-android-review/
17. Playdigious/TouchArcade, "Dead Cells has sold over 5 million copies on mobile", 2023-01-24 – https://toucharcade.com/2023/01/24/dead-cells-mobile-sales-numbers-ios-android-5-million-playdigious-apple-arcade/
18. GamesRadar, "The roguelike that was Balatro's 'largest influence'…", 2024 – https://www.gamesradar.com/games/roguelike/the-roguelike-that-was-balatros-largest-influence-has-had-its-own-minor-sales-spike-thanks-to-the-hit-indies-upcoming-mobile-release/
19. TechRadar/Gamereactor, Balatro PEGI 18 → PEGI 12, 2024; PEGI ser över policy – https://www.techradar.com/gaming/balatro-has-had-its-pegi-18-age-rating-overturned-following-appeal-i-hope-this-change-will-allow-developers-to-create-without-being-unfairly-punished ; https://focusgn.com/pegi-reviews-policy-on-simulated-gambling-after-balatro-age-rating-overturned
20. Wikipedia, "Luck Be a Landlord" (mottagande, mobil 2023-07-21, 4,99 USD) – https://en.wikipedia.org/wiki/Luck_Be_a_Landlord
21. Apple Developer, "Updated age ratings in App Store Connect" / "Age Rating Updates", 2025-07-24 – https://developer.apple.com/news/upcoming-requirements/?id=07242025a ; https://developer.apple.com/news/?id=ks775ehf
22. Game Developer, "Witch-craft: How Dicey Dungeons balances chance and predictability" – https://www.gamedeveloper.com/design/witch-craft-how-i-dicey-dungeons-i-balances-chance-and-predictability
23. Milijana Komad, "Variable Ratio Reinforcement Beyond the Skinner Box", Medium – https://medium.com/design-bootcamp/variable-ratio-reinforcement-beyond-the-skinner-box-191d3e86d86f
24. Google Play Console Help, "Content ratings" (IARC) – https://support.google.com/googleplay/android-developer/answer/9898843
25. Google Play Console Help, "Provide information for Google Play's Data safety section" – https://support.google.com/googleplay/android-developer/answer/10787469
26. Udonis, "Mobile Game Session Length" (genre-siffror, sekundärkälla) – https://www.blog.udonis.co/mobile-marketing/mobile-games/session-length
27. iubenda, "Minors and the GDPR" (art. 8, 13–16 år) – https://www.iubenda.com/en/help/11429-minors-and-the-gdpr/
28. Mobilegamer.biz, "Vampire Survivors mobile hits 5m downloads", 2023 – https://mobilegamer.biz/vampire-survivors-mobile-hits-5m-downloads/
29. Google Play / AppBrain, Soul Knight (100 M+ installationer) – https://play.google.com/store/apps/details?id=com.ChillyRoom.DungeonShooter
30. Deconstructor of Fun, "How Archero Shot to the Top…", 2019-08-09 – https://www.deconstructoroffun.com/blog/2019/8/9/why-archero-banked-25m-but-leaves-25m-hanging-hlx9n
31. WN Hub / Mobilegamer.biz, Survivor.io > 500 M USD IAP; Habby 2 mdr USD – https://wnhub.io/news/finance/item-43301 ; https://mobilegamer.biz/data-digest-savvys-moonton-swoop-liftoff-kills-ipo-habby-hits-2bn-fallout-shelter-more/
32. Wikipedia, "Hoplite (video game)"; Magma Fortress – https://en.wikipedia.org/wiki/Hoplite_(video_game) ; http://www.magmafortress.com/p/hoplite.html
33. Google Play Console Help, "Google Play Families Policies" och "Manage target audience and app content settings" – https://support.google.com/googleplay/android-developer/answer/9893335 ; https://support.google.com/googleplay/android-developer/answer/9867159
34. Google Play Console Help, "App testing requirements for new personal developer accounts" – https://support.google.com/googleplay/android-developer/answer/14151465
35. Promise Legal, "Lootbox Regulation 2026: EU, UK & US Compliance"; Wikipedia "Digital Fairness Act"; Esports Legal News 2025-12-11 – https://blog.promise.legal/lootbox-regulation-2026-game-studios/ ; https://en.wikipedia.org/wiki/Digital_Fairness_Act ; https://esportslegal.news/2025/12/11/us-uk-and-eu-loot-box-strategies/

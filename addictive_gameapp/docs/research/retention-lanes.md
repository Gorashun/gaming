# R&D: Retentionsbanor för KLUNK ("lanes" per kadens)

Författare: game-researcher · 2026-09-26 · Underlag för `RETENTION.md` (fas 2). Utgår från DESIGN.md §1–18, TEAM.md skyddsräcken och tidigare research (game-design, meta-layer, avatar-box, economy, urgency).

**Metodnot:** WebFetch var blockerad för nästan alla domäner (pegi.info, reedsmith, twobirds, ico.org.uk, support.google.com, arxiv, gamedeveloper). Bara Apples App Review Guidelines och Apples sida om barnappar kunde läsas i original. Allt annat bygger på sökmotorns sammanfattningar och är märkt *(sek.)*. Siffror för KLUNK är **uppskattningar**. Rapporten är inte juridisk rådgivning.

---

## 1. TL;DR

1. **Kärnan och sessionen är redan starka.** Inom rundan finns combo, kedja, near-miss, rekordjakt och skimrande. I sessionen finns rundavslutet med "nytt!", musslor och set-stapeln. **Det som saknas är banor på timmar, dagar och veckor.** Dessutom tar samlingen slut efter 12–16 h (economy-research §5.4). Då behövs ett långsiktigt spår.
2. **Starkast för "kom tillbaka i morgon" utan straff:** (a) **Dagens burk**, en seedad daglig utmaning som är likadan för alla, (b) **Tidvattenpölen**, som fylls medan man är borta och sedan står stilla vid ett tak, och (c) **Presentsnäckan**, en daglig gåva som staplas upp till 3 och aldrig försvinner. Alla tre bygger på system vi redan har (seedbar regissör, pärlor och stjärnsand, startskärmskort).
3. **Viktigt regelfynd: PEGI (från juni 2026).** Mekaniker som ger periodiska belöningar för att man återvänder (dagsuppdrag, inloggningsbelöningar, eventbelöningar) ger **minst PEGI 7 och en egen innehållsbeskrivning ("play by appointment")**. Straff för frånvaro ger PEGI 12 *(sek.)*. Butikstexten förutsätter idag PEGI 3. Dagliga belöningar flyttar alltså KLUNK till PEGI 7. Det matchar målgruppen 7+, men det är ett **publiceringsbeslut**.
4. **För barn 7–10:** belöningar som annonseras i förväg sänker inre motivation mer hos barn än hos vuxna. Oväntade belöningar gör det inte (Deci m.fl. 1999). Barn i åldern har stark rättvisekänsla och vill ha lika chanser. Samlande toppar i åldern. Barnet bestämmer oftast inte själv när det får spela. Slutsats: **överraskningar och synlig progress före kontrakt**, och en **tydlig "bra ställe att sluta"-punkt**.
5. **Notiser: inte i v1.** Om de införs senare ska de vara avstängda som standard, slås på av en förälder i inställningar, skickas högst 1 per dag och ha neutral text. ICO:s barnkod och EU:s DSA-riktlinjer avråder från notiser som förlänger engagemanget *(sek.)*.

---

## 2. Rekommendation

Bygg **tre "kom tillbaka"-banor först**: Dagens burk, Tidvattenpölen och Presentsnäckan. Bygg dem **i en och samma release**, så att PEGI-bedömningen bara ändras en gång. Parallellt byggs **Resan** (spelarnivå med belöningar med några nivåers mellanrum), eftersom samlingen annars tar slut efter cirka två veckors spel. Därefter kommer uppdrag, troféer, mästerskap per set och akvariet (§7).

**Beslut som behövs före bygget (producent, eventuellt Anders enligt TEAM.md regel 1, "publicering"):** acceptera PEGI 7 med beskrivningen "play by appointment", eller bara bygga banor utan periodisk belöning (Resan, uppdrag, troféer, mästerskap, akvarium, stoppunkt).

---

## 3. Taxonomi: banor per kadens och vad toppspelen gör

| Kadens | Vad banan gör | Benchmark (mekanik) | KLUNK idag |
|---|---|---|---|
| **I rundan (sekunder)** | Variabel belöning i varje handling | Candy Crush/Royal Match: kaskader och specialpjäser. Subway Surfers: mynt, power-ups och undanmanövrar. Crossy Road: varje steg är poäng. Paper.io 2: procenten stiger hela tiden. | Combo, kedja, near-miss, rekordjakt, skimrande, bomb/regnbåge. **Mättat.** |
| **Session (minuter, "en runda till")** | Varje runda flyttar något synligt framåt | Royal Match: 1 stjärna per bana går till en uppgift i ett rum ([sek.](https://www.gamigion.com/royal-match-feature-stack/)). Subway Surfers: 3 uppdrag åt gången, klar uppsättning ger +1 permanent multiplikator ([wiki, sek.](https://subwaysurf.fandom.com/wiki/Missions)). Crossy Road: gåva och prisautomat efter rundan. Monument Valley: kapitel med naturligt slut, "no grind" ([sek.](https://en.wikipedia.org/wiki/Monument_Valley_(video_game))). | Rundavslut "nytt!", pärlor, musslor, set-stapel. |
| **Mellan sessioner (timmar)** | Något hände medan du var borta | Pocket Camp: frukt och uppdrag var 3:e timme ([sek.](https://animalcrossingpocketcamp.fandom.com/wiki/Daily_Timed_Goals)). Crossy Road: gåvotimer med ökande intervall, tak några timmar ([wiki, sek.](https://crossyroad.fandom.com/wiki/Free_Gift)). Idle-spel: offline-inkomst med tak. Pokémon Sleep: bär samlas under dagen. Candy Crush: liv (**förbjudet för oss**). | **Saknas.** |
| **Dagligen** | En ny sak per dag | Wordle: exakt ett pussel per dag, samma för alla ([sek.](https://en.wikipedia.org/wiki/Wordle)). Sudoku.com: daglig utmaning i månadskalender med pokal för full månad ([sek.](https://sudoku.com/challenges/daily-sudoku)). Subway Surfers: Word Hunt, bättre belöning för dagar i följd ([sek.](https://subwaysurf.fandom.com/wiki/Word_Hunt)). Brawl Stars: Daily Wins och Daily Streak ([sek.](https://brawlstars.fandom.com/wiki/Daily_Streak)). Pokémon Sleep: morgonens forskning. Duolingo: streak. | **Saknas.** |
| **Veckovis** | En rytm som förnyas | Toca Boca World: gåva varje fredag som försvinner efter en vecka ([sek.](https://toca-life-world.fandom.com/wiki/Post_Office)) (**förbjudet för oss**). Pokémon Sleep: veckocykel för Snorlax. Subway Surfers: Season Hunt cirka var 3:e vecka. Brawl Stars: roterande lägen. | **Saknas.** |
| **Långsiktigt (veckor)** | Ett projekt man äger | Royal Match: renovera slottet rum för rum, låsta rum syns ([sek.](https://www.gamigion.com/royal-match-feature-stack/)). Candy Crush: kartan i episoder. Brawl Stars: Trophy Road. Crossy Road och Paper.io 2: figur- och skinnsamling ([sek.](https://play.google.com/store/apps/details?id=io.voodoo.paper2)). Toca och Animal Crossing: bygga och inreda. | Samlarbok (5 × 21), 48 kompisar, uppgradering I–III. **Tar slut efter cirka 12–16 h.** |

**Mönster:** de spel som håller länge har *både* ett ägt projekt (slott, karta, samling) *och* en daglig rytm. Barnvänliga förebilder (Monument Valley, Toca) klarar sig utan daglig rytm, men då är de premium eller sandlåda.

---

## 4. Mekaniker utan straff för frånvaro: belägg, barnrisk och PEGI

**Allmänt om belägg:** jag hittade **inga publicerade A/B-siffror för D1/D7/D30 per mekanik** från någon av de namngivna titlarna. Det som finns är genresnitt, till exempel pussel D1 31,9 %, D7 12,2 % och D30 5,4 % ([GameAnalytics 2025, sek.](https://www.gameanalytics.com/reports/2025-mobile-gaming-benchmarks)), plus forskning på underliggande mekanismer. Påståenden som "dagliga belöningar ger +X % D30" kommer från SEO-bloggar utan metod och används inte här.

| Mekanik | Förväntad effekt (belägg) | Risk för barn | PEGI 2026 (tolkning, *sek.*) |
|---|---|---|---|
| **Dagens burk** (samma seed för alla den dagen) | Wordles modell: *en* sak per dag skapar vana. Sessionen blir kort och avslutad ([sek.](https://en.wikipedia.org/wiki/Wordle)). Effekten landar främst på D7 och D30 (uppskattning). Samma burk för alla ger något att prata om på skolgården utan nätverk. | Låg, så länge det inte finns streak. Sudoku.coms "full månad ger pokal" är ett dolt straff och ska undvikas. | Med belöning: sannolikt PEGI 7 och beskrivning. Utan annan belöning än själva spelet: oklart. |
| **Tidvattenpöl** (fylls medan man är borta, tak, ingen förlust) | Idle-genren hade enligt Kongregate "some of the best retention" ([Pecorella GDC 2015, sek.](https://www.gdcvault.com/play/1022065/Idle-Games-The-Mechanics-and)). Påverkar främst sessioner per dag och D1 (uppskattning). | **Medel.** Branschens egna guider säger att taket ska ge "a feeling of lost opportunity" ([sek.](https://games.themindstudios.com/post/idle-clicker-game-design-and-monetization/)). Det motverkas genom att taket nås först efter cirka ett dygn och att en full pöl beskrivs som "full och glad", aldrig som "slöseri". | PEGI 7 och beskrivning (belöning för att återvända). Taket är inte förlust av innehåll, så inte PEGI 12. |
| **Daglig gåva som staplas till N** | Nästan alla F2P-spel har en ([sek.](https://www.juegostudio.com/blog/how-to-increase-user-retention-and-increase-your-games-lifetime)). Separat effekt är inte belagd. | Låg när gåvan staplas och aldrig försvinner. N = 3 täcker en helg borta. | PEGI 7 och beskrivning. |
| **Resa/spelarnivå** (XP av merges, belöning med några nivåers mellanrum) | Goal-gradient: man anstränger sig mer ju närmare belöningen man är. Efter belöningen sjunker takten ("post-reward resetting") ([Kivetz m.fl. 2006, sek.](https://journals.sagepub.com/doi/abs/10.1509/jmkr.43.1.39)). Endowed progress ger snabbare slutförande. Långsiktigt verktyg (D30+). | Låg. Nästa belöning ska synas redan när förra tas ut, så att tappet efter belöningen blir kort. | Ingen (inte tidsbunden). |
| **Troféer/prestationer** | Märken ökade aktiviteten signifikant i ett tvåårigt fältexperiment ([Hamari 2017, sek.](https://www.sciencedirect.com/science/article/abs/pii/S0747563215002265)). Vuxna, inte spel. | Låg. Dolda troféer fungerar som överraskning. | Ingen. |
| **Akvarium/hem att inreda** | Royal Match och Toca: ett ägt projekt är den tyngsta långtidsmotorn ([sek.](https://www.gamigion.com/royal-match-feature-stack/)). Investering i Eyals mening. | Låg. Autonomi och kreativitet. | Ingen, om inga timers finns. |
| **Uppdrag som aldrig går ut** (3 aktiva, byts när de klaras) | Subway Surfers kärnmotor för session och progression ([sek.](https://subwaysurf.fandom.com/wiki/Missions)). | **Medel:** villkorad och förväntad belöning ger risk för överjustifiering (§5). Belöningen ska vara liten och uppdrag frivilliga. | Ingen, om de inte är dagliga. "Dagliga uppdrag" nämns uttryckligen som PEGI 7. |
| **Mästerskap per set** (3 stjärnor per set) | Förlänger de 5 seten. Goal-gradient per sida. | Låg. | Ingen. |
| **Roterande veckoset** (inget exklusivt) | Variation. Brawl Stars roterar lägen. Inga siffror hittade. | Låg om ingenting försvinner. | Om setet ger bonusbelöning under veckan är det sannolikt "event-based", alltså PEGI 7. Rekommendation: bara variation, ingen bonus. |
| **Säsongs- och "KLUNK-dags"-kosmetik som går att låsa upp senare** | Säsongsfönster ger nyhet. Inga siffror. | Låg om den går att låsa upp senare. **Använd installationsdagen, inte födelsedag**, så att vi inte frågar efter personuppgifter. | "Event-based rewards" ger PEGI 7 och beskrivning. Försvinner de inte blir det inte PEGI 12. |
| **"Bra ställe att sluta"** | Barn som upplever sessionen som *avslutad* är mindre frustrerade när de slutar ([Designing for Disengagement, sek.](https://www.researchgate.net/publication/369557369_Designing_for_Disengagement_Challenges_and_Opportunities_for_Game_Design_to_Support_Children's_Exit_From_Play)). Mekanik som hjälper barn att förutse slutet testades på 4–11-åringar. Ibland väckte den i stället nyfikenhet att fortsätta ([CHI 2026, sek.](https://dl.acm.org/doi/10.1145/3772318.3790564)). Autoplay efter planerat slut minskade barns självreglering ([Hiniker m.fl. CHI 2018, sek.](https://dl.acm.org/doi/10.1145/3173574.3173828)). | Positiv. ICO rekommenderar "checkpoints" och pausuppmaningar för barn ([sek.](https://www.insideprivacy.com/childrens-privacy/uk-information-commissioners-office-publishes-guidance-for-video-game-developers-and-designers-to-improve-data-protection-in-their-services/)). | Ingen. |

**Varför banorna inte ska straffa frånvaro (belägg från motsatsen):** Duolingo uppger att streaks höjer retentionen kraftigt och att streak freeze minskade avhoppen för användare i riskzonen med 21 % ([sek.](https://blog.duolingo.com/how-streaks-keep-duolingo-learners-committed-to-their-language-goals/)). Mekanismen är förlustaversion från cirka dag 7. Den verkar alltså, men den är exakt vad TEAM.md och PEGI 12-kriteriet förbjuder. Vi tar vanan (en sak per dag, synlig kalender) men inte förlusten.

---

## 5. Barn 7–10: vad forskningen säger

- **Överjustifiering.** Barn som *förväntade sig* ett pris för att rita ritade mindre efteråt. Barn som fick priset *oväntat* påverkades inte ([Lepper m.fl. 1973, sek.](https://bingschool.stanford.edu/sites/bingschool/files/1975_leppergreene.pdf)). Metaanalysen av 128 studier visar att förväntade, konkreta och villkorade belöningar sänker inre motivation (d −0,28 till −0,40), mer hos barn än hos studenter. Positiv återkoppling höjer den (d +0,33) ([Deci, Koestner & Ryan 1999, sek.](https://www.researchgate.net/publication/12712628_A_Meta-Analytic_Review_of_Experiments_Examining_the_Effects_of_Extrinsic_Rewards_on_Intrinsic_Motivation)). **För KLUNK:** Presentsnäckan, pölen och troféerna kan överraska. Uppdrag och Resan är kontrakt och ska därför ge små belöningar och fira *vad barnet gjorde* ("kedja på 5!"), inte bara ge ut priset.
- **Rättvisa.** Olikhetsaversion växer kraftigt mellan 3 och 8 år, och de flesta 7–8-åringar föredrar jämlika fördelningar ([Fehr m.fl. 2008, sek.](https://www.nature.com/articles/nature07155)). 8-åringar föredrar ett rättvist lyckohjul framför ett riggat tydligare än 6-åringar gör ([Shaw & Olson 2014, sek.](https://sciencedirect.com/science/article/abs/pii/S0022096513002142)). **För KLUNK:** "samma burk för alla i dag" är ett rättviseargument som barn förstår. Regissörens anpassning får aldrig kunna upplevas som att "spelet fuskar". Proportionella resonemang med diskreta mängder (som pärlor i en burk) klarar barn ofta först vid 10–12 år, kontinuerliga mängder redan vid cirka 6 ([Boyer m.fl. 2008, sek.](https://pubmed.ncbi.nlm.nih.gov/18793078/)). Oddsburken kan därför behöva kompletteras med fyllnadsnivå (hypotes, speltesta).
- **Autonomi.** Upplevd autonomi och kompetens förutsäger njutning och framtida spelande ([Ryan, Rigby & Przybylski 2006, sek.](https://www.researchgate.net/publication/225998888_The_Motivational_Pull_of_Video_Games_A_Self-Determination_Theory_Approach)). Val (vilket set, vilken kompis, var i akvariet) och valfria uppdrag stöder det. Tvingade dagliga sysslor gör det inte.
- **Samlande.** Samlande börjar ofta vid 6–8 år och toppar före puberteten ([Psychology Today, sek.](https://www.psychologytoday.com/us/blog/the-mind-of-a-collector/202311/children-who-collect-are-not-uncommon)). Samlarboken och kompisarna träffar rätt. Akvariet ger samlingen en *plats* att visas upp på.
- **Dagliga vanor.** Knappt 1 av 4 amerikanska barn har egen mobil vid 8 års ålder ([Common Sense 2025, sek.](https://www.commonsensemedia.org/research/the-2025-common-sense-census-media-use-by-kids-zero-to-eight)). Barnets speltid delas oftast ut av föräldern i fönster. **Slutsats (uppskattning):** den dagliga banan ska vara klar på 5–10 minuter och ge ett naturligt slut, så att den passar ett föräldrastyrt fönster. Den ska inte kräva en viss tid på dygnet.
- **Mörka mönster.** 4 av 5 appar som 3–5-åringar använde hade manipulativ design. Vanligast var figurer som tjatar och belöningar som blinkar till precis när barnet vill sluta ([Radesky m.fl. JAMA Netw Open 2022, sek.](https://www.michiganmedicine.org/health-lab/design-tricks-commonly-used-monetize-young-childrens-app-use)). **För KLUNK:** kompisen får aldrig se ledsen ut när barnet går. Ingen belöning dyker upp i utgångsögonblicket för att hålla kvar barnet.

---

## 6. Lokala notiser

**Regler:**
- **Apple:** 4.5.4 säger att push inte får krävas och att marknadsföring kräver uttryckligt samtycke i appens UI och en väg att avstå ([primär](https://developer.apple.com/app-store/review/guidelines/)). 1.3 Kids Category förbjuder "distractions" utanför föräldraspärr men nämner inte notiser särskilt. iOS kräver att användaren godkänner notiser.
- **Google Play Families:** jag hittade **ingen notisspecifik regel** (belägg saknas). Families förbjuder "emotionally manipulative tactics", men i kontexten annonser och köp ([sek.](https://support.google.com/googleplay/android-developer/answer/9893335?hl=en)). Android 13+ kräver runtime-behörigheten POST_NOTIFICATIONS, så notiser är avstängda tills användaren säger ja ([sek.](https://source.android.com/docs/core/display/notification-perm)).
- **PEGI:** notiser finns inte som eget kriterium i det jag hittade (belägg saknas).
- **ICO:s barnkod (UK):** notiser och nudges ska inte användas för att förlänga barns engagemang. Pausuppmaningar rekommenderas ([sek.](https://www.insideprivacy.com/childrens-privacy/uk-information-commissioners-office-publishes-guidance-for-video-game-developers-and-designers-to-improve-data-protection-in-their-services/)). Koden gäller tjänster som behandlar personuppgifter, vilket KLUNK knappt gör, men den är en tydlig norm.
- **EU:s DSA-riktlinjer (juli 2025):** push-notiser och streaks ska vara avstängda som standard för minderåriga ([sek.](https://digital-strategy.ec.europa.eu/en/library/commission-publishes-guidelines-protection-minors)). De gäller onlineplattformar, inte offlinespel, men visar vart normen rör sig.

**Rekommendation:** **inga notiser i v1.** Om de byggs senare gäller följande:
- Avstängda som standard.
- Påslag bara i inställningsarket bakom en enkel föräldraspärr, där föräldern också väljer tid på dagen, inte senare än kl. 19.
- Högst 1 per dag och högst 3 per vecka.
- Bara när något faktiskt väntar (pölen är full, en gåva ligger kvar).
- Tystnar helt efter 2 obesvarade.
- Text i föräldraton utan skuld och utan figur som ber: *"The tide pool in KLUNK is full. Maybe a round today?"* / *"Tidvattenpölen i KLUNK är full. Kanske en runda i dag?"* Aldrig "we miss you", aldrig förlust, aldrig nedräkning.

---

## 7. Rangordnade banor för KLUNK

★ = starkast "kom tillbaka i morgon". Byggstorlek: S ≈ 1–2 d, M ≈ 3–5 d, L ≈ 6–10 d (uppskattning, inklusive UI och test).

| # | Bana | Kadens | Trigger | Belöning | Investering | Storlek | Varför den passar KLUNK |
|---|---|---|---|---|---|---|---|
| 1 ★ | **Dagens burk** | Daglig | Nytt kort på Start med dagens set och en "dagens Glimt"-ikon. Datum från enhetens klocka. | Första försöket per dag ger en stämpel i en kalender och lite stjärnsand (t.ex. 3, simuleras). Eget bästa för dagen. | Kalendern fylls. Tomma dagar är neutrala, ingen streak. Pokal efter N stämplar *totalt*, inte i följd. | M | Regissören är redan seedbar (mulberry32). **OBS:** Flöde/Torka läser brädet, så köerna glider isär mellan spelare. "Samma burk" kräver ett dagläge med fast kö och specialschema. Dagens set roterar de 5 seten. Det ersätter roterande veckoset (#11). |
| 2 ★ | **Tidvattenpölen** | Timmar och dagar | Pöl på Start där små Glimtar simmar in medan man är borta. | Pärlor (t.ex. tak ≈ 1 vanlig mussla per dygn, simuleras). Ett tryck ger jackpot-juice med låg intensitet. | Senare: uppgradera pölens tak eller utseende med pärlor. | S–M | Återanvänder pärlekonomin och juice. Taket nås efter cirka 20–24 h, så man tappar inget på att komma en gång om dagen. Går att fuska med klockan, vilket är ofarligt offline. |
| 3 ★ | **Presentsnäckan** | Daglig | En snäcka per kalenderdag ligger på hyllan. Staplas upp till 3 och försvinner aldrig. | Liten *känd* typ (pärlor eller sand) med en överraskning ibland (kosmetisk dekor till akvariet). Inga rullhjul. | Ingen. | S | Hyllan och öppningsceremonin finns redan (§14.3). Staplingen gör att en helg borta aldrig kostar något. **Överlappar #2.** Välj en av dem om budgeten är tight. #2 har mer premiumkänsla. |
| 4 ★ | **Resan** (spelarnivå) | Session till veckor | Stapel på Start med nästa 3 belöningar synliga. XP från merges plus bonus för första gången. | Var 2–3:e nivå: pärlor, sand, akvariedekor, burkskal, ramar. | Nivån syns vid hjälten. | M | Löser problemet att **samlingen tar slut efter 12–16 h**. Den nuvarande set-stapeln kan gå upp i Resan. Goal-gradient och endowed start (nivå 1 halvfylld). |
| 5 | **Akvariet** | Långsiktigt | Kort på Start (eller byte mot Bok-kortet). | Fångade Glimtar och skimrande simmar. Kompisar hälsar på. Dekor från #3, #4 och #7. | Placera dekor och välja vilka Glimtar som visas. | L | Ger samlarboken och 48 kompisar en plats att visas upp på (Royal Match- och Toca-modellen). Hög premiumkänsla, men dyr art. |
| 6 | **Tre uppdrag** (går aldrig ut) | Session | Tre ikonkort i rundavslutet och på Start, med ikon och siffra och ingen text. | Lite sand eller pärlor. Byts direkt när ett klaras. Ett gratis byte per uppdrag. | Ingen. | M | Kedjan i HUD, nivåikoner och set ger färdiga ikonuppdrag (skjutna till v1.2 i §13.5). Frivilliga, små belöningar, beröm av handlingen. |
| 7 | **Troféväggen** | Långsiktigt | Flik i Boken. En del troféer är dolda tills de klaras. | Trofé med egen animation, ibland dekor. | Väggen fylls. | S–M | Ersätter och utökar engångs-milstolparna i §16.1. Dolda troféer är överraskningar och har låg överjustifieringsrisk. |
| 8 | **Mästerskap per set** | Veckor | Tre stjärnor per boksida (full sida, nivå 10 i setet, dubbel-Klunk i setet). | Guldram på sidan, setets burkskal. | Sidan blir "färdig". | S | Förlänger de 5 seten utan nytt innehåll. |
| 9 | **"Bra ställe att sluta"** | Sessionens slut | Efter att dagens burk är klar, eller efter cirka 20 min, somnar Glimtarna i pölen i rundavslutet. | Lugn avslutning ("pölen fylls tills nästa gång"). Ett tryck startar ändå en ny runda. | Ingen. | S | Hjälper föräldrar, följer ICO och CHI-forskningen och stärker förtroendet (premiumkänsla). Blockerar aldrig. |
| 10 | **Säsongsdekor och KLUNK-dag** | Årlig | Enhetens datum (vinter, vår, höst) och installationsdagen. | Kosmetik (burkskal, snö och löv i bakgrunden). **Går att låsa upp senare** via Resan. | Dekor i akvariet. | S–M | Nyhet utan exklusivitet. Installationsdagen kräver inga personuppgifter. |
| 11 | **Veckans set** | Veckovis | Dagens burk väljer oftare veckans set. | Ingen extra belöning (undviker "event-based"). | Ingen. | S | Rytm och variation. Går upp i #1. |

**I rundan:** inga nya banor föreslås. Den kadensen är redan mättad, och mer blir brus och risk för flash-guard.

**Ordning (förslag):** #1–#4 och #9 i ett paket (PEGI-beslut). Därefter #7, #8, #6, sedan #5 och #10.

---

## 8. Osäkerheter

- **PEGI-texten är bara läst via sammanfattningar.** Jag vet inte om en daglig utmaning *utan* extra belöning, eller en pöl med tak, räknas som "play by appointment". Jag vet inte heller om IARC-enkäten (som Google Play använder) redan har de nya frågorna. Det måste bekräftas i enkäten före release.
- **Inga D1/D7/D30-siffror per mekanik** kunde beläggas. Allt om effekt bygger på mekanismforskning och benchmark-mönster.
- Duolingos siffror (21 %) kommer från Duolingos egen blogg via sammanfattning *(sek.)*, och gäller vuxna och språkinlärning.
- Deci 1999:s effektstorlekar är lästa via abstrakt *(sek.)*.
- Tak och belöningsnivåer i §7 är uppskattningar och måste simuleras av balance-analyst mot `merges per runda`.
- Klockfusk (barn som ändrar datum) är ofarligt offline, men kan göra Dagens burk "olika för alla". Acceptera det och stoppa det inte.
- Akvariet (#5) är art-tungt. Premiumribban kan göra det till L+.

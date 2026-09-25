# R&D: Avatarer ur lådor, med raritet och effekter (underlag för v1.2)

game-researcher · 2026-09-25 · Bygger på DESIGN.md §13 och meta-layer-research.md §3, §6c och §7.

**Metodnot:** WebFetch var blockerad för nästan alla domäner, bland annat Voodoo, Steam, PEGI, gov.uk och Nature. Bara Apples riktlinjer kunde läsas i original. Allt annat kommer från sökmotorns sammanfattningar och är märkt *(sek.)*. Rapporten är **inte juridisk rådgivning**.

## 1. TL;DR

1. **Paper.io 2** har "Heroes" i fyra rariteter: Common, Rare, Epic och Legendary. Uncommon och Mythical finns inte. Hjältarna har uppgraderbara krafter: fart, sköld, färgexplosion, stenhale, sikt och radar. Lådor och kort säljs för gems. Odds, dubbletthantering och öppningsceremoni är **ej belagda**.
2. **Juridiskt** faller lådor som bara tjänas in, aldrig kan köpas och inte kan bytas utanför allt jag hittade: BE, NL, UK, Apple, Google, PEGI 2026 och AU. Undantaget är att **Play Families förbjuder simulerat spel om pengar**. Öppningen får alltså inte likna en spelautomat, ett lyckohjul eller en kapselautomat.
3. **Forskningen:** mekanismen verkar oberoende av pengar. Sällsyntare fynd ger mer arousal och mer lust att öppna en till. Belägg för skada av *enbart intjänade* lådor hos barn saknas, men belägg för att de är ofarliga saknas också.
4. **Brawl Stars:** när lådorna togs bort 2022 kändes spelet platt. Slump som bara tjänas in kom tillbaka 2023 och ytterligare slump 2026. Slumpen i *vad* man får är en stor del av glädjen.
5. **Rekommendation:** en ändlig pool med 36 avatarer och inga dubbletter. Skalen tjänas in vid fasta merge-milstolpar. Oddsen visas som pärlor i en burk, med garanti per raritet. Kraften ligger i information och samlande, inte i poäng. 12–16 dagar (uppskattning).

## 2. Paper.io 2 på mekaniknivå

| Del | Belägg |
|---|---|
| Figurer | Skins ersattes av Heroes som har stats. 16 nya figurer med egna krafter ([Gamigion](https://www.gamigion.com/1-hour-analysis-paper-io-2-by-voodoo/), App Store *(sek.)*) |
| Rariteter | Common, Rare, Epic, Legendary (Gamigion *(sek.)*) |
| Lådor | En "Common Box" låser upp figuren Cubey. Butiken har flikarna "Card Offers" och "Chests", och kortutbudet kan uppdateras (Gamigion, App Store *(sek.)*) |
| Lådor genom spel | Den som tar ett helt land i ett försök får ett bonusspel på 6 s med mynt, gems och kistor ([Voodoo](https://paper2-help.freshdesk.com/support/solutions/articles/202000095753-how-to-progress-in-paper-io-2-) *(sek.)*). Dessutom dagsbonus med figurfragment och uppdrag ([guide](https://hub.lifeplan.co.uk/lifeplan-news/unlock-all-skins-in-paper-io-2-the-ultimate-guide-1764804551) *(sek.)*) |
| Krafter | En ring fylls automatiskt medan man spelar och kraften aktiveras när den är full. Krafterna är antingen *direkta* eller *varaktiga*. Kända exempel: fart, färgexplosion eller färgkanon, sköld, stenhale, större sikt, radar. Alla är uppgraderbara ([Voodoo](https://support.paper.io/support/solutions/articles/202000102994-what-are-character-powers-), [lista](https://paper2-help.freshdesk.com/support/solutions/articles/202000102996-all-character-powers-listed) *(sek., hela listan gick inte att läsa)*) |
| Effektstorlek | Siffror för krafterna saknas. *Power-ups på kartan* (stjärna, sköld) ger osårbarhet i mer än 10 s, upp till 21 s på maxnivå. Spelare menar att den som plockar dem "har vunnit" ([Steam](https://steamcommunity.com/app/2751310/discussions/0/596260925367942444/) *(sek., oklart om det är samma system)*) |

**Det här kopierar vi inte, eftersom det bygger på pengar eller annonser:** gems, butikslådor, kortutbud, belöningsvideo, cirka 28 mellanannonser per timme (meta-layer §3), dagsbonus och event.
**Det här lånar vi:** figurer som *gör* något, raritet som ordningsprincip och siluetter.

## 3. Raritetssystem med intjänad slump

| System | Mekanik | Lärdom |
|---|---|---|
| **Brawl Stars** | Lådorna togs bort i december 2022 för att bli "fair and predictable" ([GWO](https://gameworldobserver.com/2022/12/13/brawl-stars-loot-boxes-removed-supercell)). Förut tog det cirka 10 månader att få en Legendary ([mobilegamer](https://mobilegamer.biz/supercell-explains-brawl-stars-big-comeback-from-an-all-time-low-to-8-8x-revenue/)). Efteråt: intäkterna −14 % ([DoF](https://www.deconstructoroffun.com/blog/why-removing-loot-boxes-in-brawlstars-failed)), och 30,9 % av spelarna tappade intresset ([T&F 2025](https://www.tandfonline.com/doi/full/10.1080/10447318.2025.2496031) *(sek.)*). 2023 kom **Starr Drops**, som bara tjänas in genom vinster. I september 2026 ersattes Starr Road av slumpade **Brawler Blast** ([timesaver](https://timesaver.gg/blog/brawl-stars-brawler-blast-explained) *(sek.)*) | Helt deterministiskt kändes platt |
| **Starr Drops** | Oddsen är 50/28/15/5/2 ([Supercell](https://support.supercell.com/brawl-stars/en/articles/starr-drops-chances-2.html) *(sek.)*). Varje tryck "uppgraderar" rariteten, men den är **bestämd i förväg**. Dubbletter blir valuta ([wiki](https://brawlstars.fandom.com/wiki/Starr_Drops) *(sek.)*) | Tryck-uppgraderingen är teater. Kopiera inte |
| **Crossy Road** | En prisautomat som kostar 100 mynt. Chansen till dubbletter ökar ju fler figurer man har. I Disney-versionen blir dubbletter mynt, och efter 10 dubbletter i rad kommer en ny figur ([wiki](https://crossyroad.fandom.com/wiki/Prize_Machine), [Disney](https://disneycrossyroad.fandom.com/wiki/Prize_Machine)) | Garantin är bra, men en kapselautomat är just den estetik vi ska undvika |
| **Pokémon TCG** | Minst en Rare per paket ([Pokémon](https://support.pokemon.com/hc/en-us/articles/360000981613-What-can-I-expect-in-a-Pok%C3%A9mon-Trading-Card-Game-booster-pack)). TCG Pocket visar raritet med **antal symboler** och ger poäng per paket som räcker till valfritt kort efter högst 500 paket ([ptcgpocket](https://ptcgpocket.gg/pokemon-tcg-pocket-rarity-explained-every-diamond-star-and-crown/) *(sek.)*) | Raritet utan text, garanterad plats |
| **Hearthstone** | Garanterad Epic inom 10 paket och Legendary inom 40. Ingen andra Legendary innan man har alla ([esports.gg](https://esports.gg/news/hearthstone/hearthstone-pity-timer/) *(sek.)*) | Så ser **garanti** (pity) och **dubblettskydd** ut i praktiken |
| **Färgkoder** | Diablo och WoW: grå, vit, grön, blå, lila, orange ([Wikipedia](https://en.wikipedia.org/wiki/Loot_(video_games))). Fortnite tog bort sina raritetsfärger 2024 ([PC Gamer](https://www.pcgamer.com/games/battle-royale/epic-removes-the-item-rarity-system-from-fortnite-but-some-fans-aint-happy-and-think-its-trying-to-gouge-players/)) | Barn känner igen stegen, men rött och grönt fungerar dåligt vid färgblindhet |

## 4. Regelverk och etik

| Regel | Gäller den intjänade lådor som inte kan bytas? |
|---|---|
| Belgien | Nej, eftersom hasardspel kräver en *insats* ([Collabra](https://online.ucpress.edu/collabra/article/9/1/57641/195100/Breaking-Ban-Belgium-s-Ineffective-Gambling-Law) *(sek.)*) |
| Nederländerna | Nej. KSA:s gräns är att innehållet kan överlåtas ([KSA](https://kansspelautoriteit.nl/publish/library/17/study_into_loot_boxes_-_a_treasure_or_a_burden_-_eng.pdf)). Raad van State 2022 bedömde att inte ens FIFA-paket är hasardspel ([CMS](https://cms.law/en/nld/legal-updates/Dutch-court-rules-FIFA-loot-boxes-not-a-game-of-chance-revokes-EA-penalty) *(sek.)*) |
| UK DCMS 2022 | Nej. Utgår från köpta lådor. Spellagen utvidgas inte. Ett samband finns men ingen visad orsak ([PDF](https://data.parliament.uk/DepositedPapers/Files/DEP2022-0616/Evidence_on_loot_boxes_in_video_games.pdf) *(sek.)*) |
| Apple 3.1.1 och 1.3 | Nej. Gäller "randomized virtual items **for purchase**". I Kids-kategorin får köp bara ligga bakom en föräldraspärr ([Apple](https://developer.apple.com/app-store/review/guidelines/)) |
| Google Play, oddskrav | Nej. Gäller "from a **purchase**" ([Fenwick](https://www.fenwick.com/insights/publications/google-play-now-requires-disclosure-of-loot-box-odds) *(sek.)*) |
| **Play Families** | **Ja, indirekt.** Verkligt *eller simulerat* spel om pengar är inte tillåtet ([Google](https://support.google.com/googleplay/android-developer/answer/9893335) *(sek.)*) |
| PEGI, juni 2026 | Nej. Betalda slumpobjekt ger PEGI 16, gratis gör det inte. Belöning för att *komma tillbaka* ger PEGI 7 och straff för frånvaro PEGI 12 ([Lewis Silkin](https://www.lewissilkin.com/insights/2026/03/18/pegi-announces-major-update-to-age-rating-criteria-what-games-businesses-need-to-102mn9y) *(sek.)*) |
| Australien 2024 | Nej. Slump som inte kan kopplas till riktiga pengar är uttryckligen undantagen ([Classification](https://www.classification.gov.au/about-us/media-and-news/news/new-classifications-for-gambling-content-video-games) *(sek.)*) |
| EU:s Digital Fairness Act | **Okänt.** Förslaget väntas Q4 2026. Ett totalförbud mot slumpbelöningar har nämnts som möjligt ([Freshfields](https://www.freshfields.com/en/our-thinking/blogs/technology-quotient/the-eus-proposed-digital-fairness-act-a-game-developers-guide-to-potential-imp-102ltio) *(sek.)*) |

**Forskning:**
- **Zendle & Cairns 2018** (n = 7 422): η² 0,054 mellan köp av lådor och spelproblem ([PLOS One](https://journals.plos.org/plosone/article?id=10.1371%2Fjournal.pone.0206767)).
- **Zendle m.fl. 2019** (16–18 år): η² 0,120. Gratislådor i spelet förstärkte sambandet med bara r² 0,007 ([RSOS](https://royalsocietypublishing.org/rsos/article/6/6/190049/94826/Adolescents-and-loot-boxes-links-with-problem) *(sek.)*).
- **Drummond & Sauer 2018:** lådorna i 45 % av 22 spel uppfyllde psykologiska kriterier för spel om pengar ([Nature HB](https://www.nature.com/articles/s41562-018-0360-1) *(sek.)*).
- **Oberoende av pengar:**
  - Sällsyntare fynd gav högre hudkonduktans och större lust att öppna en till ([Larche 2019](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7882574/)).
  - I Overwatch hade de som *tjänade in* lådor mer spelproblem än de som köpte dem. Studien var korrelationell och gjordes på vuxna ([Larche 2022](https://link.springer.com/article/10.1007/s10899-022-10127-5) *(sek.)*).
- **Barn:**
  - 22 barn i åldern 7–14 år kallade slumpbelöningar för "scams", även när de var gratis ([CHI 2025](https://dl.acm.org/doi/10.1145/3706598.3713611) *(sek.)*).
  - Slumpmekanik är normaliserad i appar för 4–8-åringar ([J Gambl Stud](https://link.springer.com/article/10.1007/s10899-023-10273-4) *(sek.)*).
- **Etisk design:** minska komplexiteten, jämna ut chanserna och gör lådorna **uttömbara**, så att man garanterat har allt efter ett visst antal ([Xiao & Newall 2022](https://research-information.bris.ac.uk/en/publications/probability-disclosures-are-not-enough-reducing-loot-box-reward-c/) *(sek.)*).

**Bedömning:**
- **Det kan vi göra:** skal som bara tjänas in och som aldrig kan köpas, bytas eller kopplas till valuta, annonser eller nätverk. Visa oddsen frivilligt.
- **Det bör vi undvika**, eftersom det är där Families-risken och den pengaoberoende mekanismen sitter:
  - hjul, rullar eller kandidater som rullar förbi
  - raritet som uppgraderas stegvis
  - att visa vad man *nästan* fick
  - myntklang och blixtar
  - "öppna alla" och räknare på oöppnade skal
  - timrar och belöningar för att komma tillbaka
  - dubbletter
  - köp, någonsin
- **Kvarvarande risk:** att barn upplever slumpen som orättvis. Motmedlen är uttömbar pool, synliga odds och garanti.

## 5. Avatarer för KLUNK: idébank med 44 st

HS = påverkan på highscore, uppskattad: **0** ingen, **L** liten (under ca 2 %), **M** medel. Kostnaden avser effekten: S ≤ 2 h, M ≤ 1 d, L > 1 d.

| # | Namn | Raritet | Effekt | HS | Kostnad |
|---|---|---|---|---|---|
| 1 | Snäckan Sigge | Vanlig | Pärlspår efter fallande objekt | 0 | S |
| 2 | Maneten Molly | Vanlig | Bubbelspår | 0 | S |
| 3 | Krabban Krille | Vanlig | Kastanjettklick vid drop | 0 | S |
| 4 | Sjöstjärnan Stina | Vanlig | Merge-partiklar formade som stjärnor | 0 | S |
| 5 | Bläckfisken Bosse | Vanlig | Bläckprickar i egen färg | 0 | S |
| 6 | Fisken Fia | Vanlig | Ögonen följer det fallande objektet | 0 | S |
| 7 | Pingvinen Pim | Vanlig | Mössa, nickar vid drop | 0 | S |
| 8 | Grodan Grim | Vanlig | "Kvack" vid combo 3 | 0 | S |
| 9 | Ugglan Ulla | Vanlig | Blinkar vid merge | 0 | S |
| 10 | Musen Mio | Vanlig | Pip vid landning | 0 | S |
| 11 | Snigeln Sally | Vanlig | Glittrande slemspår | 0 | S |
| 12 | Humlan Humle | Vanlig | Surrar medan objektet hänger | 0 | S |
| 13 | Sjöhästen Harry | Ovanlig | Partikelfärgen skiftar med combon | 0 | S |
| 14 | Kometen Kim | Ovanlig | Eldsvans | 0 | S |
| 15 | Snögubben Snö | Ovanlig | Snöflingor och frostkant | 0 | M |
| 16 | Robotten Bip | Ovanlig | Merge-ljuden blir robotpip i skala | 0 | S |
| 17 | Draken Dunder | Ovanlig | Rökpuff vid drop | 0 | S |
| 18 | Katten Kurre | Ovanlig | Spinner när kedjan tänds | 0 | S |
| 19 | Ballongen Bella | Ovanlig | Konfetti vid rekordjakt | 0 | S |
| 20 | Pirat-Pelle | Ovanlig | "Arrr" och skattkista vid Klunk | 0 | S |
| 21 | Spöket Svischa | Ovanlig | Genomskinliga efterbilder | 0 | S |
| 22 | Trumslagaren Trumma | Ovanlig | Varje drop blir ett trumslag, combon bygger takt | 0 | M |
| 23 | Åskmolnet Muller | Sällsynt | Större skak och blixtar vid kedja (inom taket för Lugnt läge) | 0 | S |
| 24 | Dirigenten Maestro | Sällsynt | Combon spelar en melodi | 0 | M |
| 25 | Tidsugglan Tick | Sällsynt | Egen slow-mo-stil vid fara, sepia och tickande | 0 | M |
| 26 | Fyrverkeri-Fia | Sällsynt | Egen fanfar vid rekord | 0 | S |
| 27 | Vulkanen Vulle | Sällsynt | Lava och bas vid merge på nivå 8 och uppåt | 0 | S |
| 28 | Discokulan Disco | Sällsynt | Bakgrunden pulserar med combon (blinkskydd) | 0 | M |
| 29 | Ekot Eko | Sällsynt | Katedraleko på merge | 0 | S |
| 30 | Kameran Klick | Sällsynt | Polaroid av största kedjan i rundavslutet | 0 | L |
| 31 | **Lykt-Lisa** | Episk | Medan man siktar lyser objekt av samma nivå svagt | L | M |
| 32 | **Spådamen Siri** | Episk | Ser två steg fram i kön | L–M | M |
| 33 | **Sikt-Sixten** | Episk | Siktlinjen slutar i en landningsprick | L | M |
| 34 | Bubblan Bubbel | Episk | De första 10 dropen studsar inte | L | S |
| 35 | **Ekolodet Ekko** | Episk | När en ny nivå tänds blinkar alla objekt av den nivån | L | S |
| 36 | Magnet-Maja | Legendarisk | En gång per runda dras två lika objekt inom 40 px ihop | L | M |
| 37 | **Regnbågs-Rut** | Legendarisk | Rundan börjar med en regnbåge i kön | L | S |
| 38 | Bombmästaren Boom | Legendarisk | Första specialobjektet kommer efter 15–25 drop i stället för 25–60 | L–M | S |
| 39 | Andrums-Vala | Legendarisk | En gång per runda: farogränsen är 2,5 s i stället för 1,5 s | M | S |
| 40 | **Guldvalen Gyllene** | Legendarisk | Dubbel chans på skimrande (garantin oförändrad) | 0 | S |
| 41 | Havsdrottningen | Mytisk | Guldburk, orkester och en regnbåge i varje runda | L | M |
| 42 | **Stjärnvalen** | Mytisk | Stjärnhimmel, glödande objekt och dubbel chans på skimrande | 0 | M |
| 43 | Klunk-Kungen | Mytisk | Varje Klunk ger en kröningsshow och en krona | 0 | M |
| 44 | Bomb-Bettan | Mytisk | En extra bomb per runda som ger **0 poäng** | M | S |

**Så förblir highscore jämförbar (förslag):**
1. **Lägg det som känns absurt värdefullt i meta, inte i poäng.** Nr 40, 42 och 43 känns mytiska för ett barn som samlar, men poängen påverkas inte.
2. **Hjälp med information, inte med fysik.** Lisa, Siri, Sixten och Ekko hjälper den som inte redan ser mergarna, alltså barn. Toppspelare vinner lite. Det är en uppskattning som ska mätas.
3. **Två rekord, inte 40 tavlor.** `highscore.pure` gäller avatarer med HS = 0. `highscore.helped` gäller övriga och visas med avatarikonen på hyllan. Rekordjakten jämför inom samma klass.

## 6. Lådmekanik inom skyddsräckena

| Fråga | Förslag |
|---|---|
| **Hur man tjänar skal** | Skal nummer *k* vid `50·k^1,3` merges totalt (50, 123, 209 … 5 274). Samma räknare som temaseten, så *när* är deterministiskt. Dessutom 6 överraskningar på skicklighetsspåret: första nivå 7, 8, 9 och 10, första dubbel-Klunk, första skimrande |
| **Skal per timme** (uppskattning med 60 merges per runda och 5 min per runda, **inte mätt**) | Cirka 7 första timmen, därefter cirka 4 per timme, alltså ungefär ett per tre rundor. Alla 36 efter 6–7 h |
| **Innehåll** | Rariteten dras med 40/26/17/10/5/2 %, omnormerat bland rariteter som har figurer kvar. Inom rariteten dras jämnt. Inga dubbletter: N skal ger N nya figurer |
| **Garanti** | Episk eller bättre senast skal 8, legendarisk eller bättre senast skal 15, mytisk senast skal 28. Första skalet är alltid Sällsynt. Min simulering (20 000 körningar) gav median för första episk 7, legendarisk 11 och mytisk 21. Garantin utlöses i 18–31 % av körningarna |
| **Öppning** | Skalet flyger till hyllan i rundavslutet (omstart fortfarande under 0,5 s). Det öppnas med ett tryck på startskärmen. Musslan öppnar sig på fast tid, 1,2 s, och visar på en gång figur, färg och antal pärlor. Figuren visar sin effekt en gång. Jackpot-juice utan skak och zoom, som mest 0,9 för mytisk. Ett tryck hoppar över |
| **Oöppnade skal** | Ligger som föremål på hyllan, utan siffra och utan röd prick. Pulserar högst 1 Hz. Öppnas ett i taget |
| **Odds utan text** | Högst upp i fliken Kompisar: en glasburk med 20 pärlor i raritetsfärgerna, i proportion till aktuella odds. Siluetter per rad. Procentsatser på en föräldrasida. En urna är begriplig från cirka 8 år (meta-layer §5) |
| **Raritetskod** | 1–6 pärlor **plus** färgerna grå, grön, blå, lila, guld och regnbåge. Inget rött, eftersom rött är fara |

**Jämförelse med Starr Road** (fast ordning, välj 1 av 3 synliga): valet ger autonomi och nästan inga spelliknande drag, men mindre spänning, och Supercell har övergett modellen. Om speltestet visar frustration eller jakt kan vi byta till **välj 1 av 3 ur poolen**. Ekonomin blir densamma.

## 7. Rekommendation för v1.2

- **36 avatarer:** 12 Vanlig, 10 Ovanlig, 7 Sällsynt, 4 Episk (de fetstilta), 2 Legendarisk (Rut och Gyllene) och 1 Mytisk (Stjärnvalen). Ingen av dem påverkar HS mer än L. "Klassisk" ägs från start.
- **Avataren är Släpparen:** figuren på burkkanten som håller objektet och reagerar på drop och merge. Objekt och ansikten ändras aldrig.
- **Odds, garanti, frekvens och öppning** enligt §6.
- **Boken** får en ny flik, **Kompisar**, efter setsidorna: sex rader och en pärlburk. Man väljer avatar genom att trycka. Temaset och skimrande objekt påverkas inte. Stapeln visar nästa belöning, skal eller set.
- **Beslut för teamet:** DESIGN §13 säger att upplåsningar "aldrig ger poäng". Antingen mjukas regeln upp till "högst liten påverkan, med eget rekord", eller så begränsas epic och uppåt till HS = 0.
- **Byggtid (uppskattning):**

| Del | Dagar |
|---|---|
| Avatarsystem och Släpparen | 1,5–2 |
| Skalspår, pool, garanti och tester | 1 |
| Öppning | 1–1,5 |
| Fliken Kompisar | 1,5 |
| Modulära figurer | 2–3 |
| 30 kosmetik- och feel-effekter | 3–4 |
| 6 spel- och meta-effekter | 1,5–2 |
| Två rekord | 0,5 |
| **Totalt** | **12–16** |

  Ett första steg med 24 avatarer (9/6/4/3/1/1) tar 8–10 dagar.
- **Mät i speltest** (lokalt):
  1. merges per runda och rundor per timme, för att kalibrera formeln
  2. tid från intjänat till öppnat skal (kort tid plus tjat är en varning, ignorerade skal betyder lågt värde)
  3. latens vid omstart
  4. vilka avatarer barnen bär: favorit eller högsta raritet
  5. HS per klass
  6. om barnet kan peka ut den sällsyntaste raden i burken
  7. "Är det rättvist?" till barnet och "Liknar det spel om pengar?" till föräldern
  8. rundor per session före och efter

## 8. Osäkerheter

- Paper.io 2:s odds, dubbletter, öppning och siffror för krafterna är **ej belagda**.
- Nästan alla källor är sekundära.
- Merges per runda och rundlängd är **omätta**.
- Det finns ingen studie av enbart intjänade slumplådor hos barn i åldern 7–10.
- EU:s Digital Fairness Act kan ändra läget.

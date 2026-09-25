# Ekonomi: musslor, pärlor och stjärnsand (research, 2026-09-25)

Underlag till DESIGN §14 efter Anders speltest ("verkar för enkelt att få"). WebFetch var blockerat i miljön, så **alla webbkällor är lästa via sökresultatens sammanfattningar (sek.)**. Allt som gäller KLUNK:s intjäning är **uppskattning** tills `merges per runda` är mätt (PLAYTEST.md).

## 1. TL;DR
- **Felet är framtungt, inte en enda parameter.** Anders fick troligen allt på en gång eftersom musslor betalades ut **retroaktivt** på `stats.merges` från v1.0–v1.1: 2 000 merges gav 17 musslor, 3 000 gav 23, plus 6 skicklighetsmusslor. Dessutom ger kurvan 10–14 musslor på de 10 första rundorna.
- **Paper.io 2:s priser och lådfrekvens gick inte att belägga.** Fakta som finns: mynt och gems, fyra rariteter, kistor i butik, nycklar och annonser för kistor. Kalibreringen görs därför mot Brawl Stars och Crossy Road.
- **Förslag:** två resurser (pärlor = 1 per merge, stjärnsand ≈ 2–3 per runda), tre musslor (vanlig 300 pärlor, silver 700 pärlor, guld 50 stjärnsand) med raritetsgolv och inga dubbletter, gratis mussla per 750 merges, och uppgradering med pärlor (+ stjärnsand till III).
- **Simulerat (60 merges per runda, 5 min per runda, uppskattning):** 1 mussla per 3,0–4,1 rundor, 24 kompisar efter 6–8 h, alla 48 efter 12–16 h, favoriten på III efter cirka 1 h och topp 3 på III efter cirka 5 h.
- **Ny regelrisk:** att *spendera* en intjänad valuta på slump skapar en insats. PEGI:s definition av "paid random items" nämner virtuell valuta (sek.). Det måste bekräftas innan release. Reservplan: köpta musslor blir "välj 1 av 3 synliga".

## 2. Rekommendation
Inför systemet i §5 i `data/boxes.ts` (alla siffror i data). Ta bort merge-kurvan och de sex skicklighetsmusslorna. Skicklighet ger i stället stjärnsand. Betala **inte** ut retroaktivt: befintliga figurer behålls, oöppnade musslor behålls och gamla merges ger ingenting. Kalibrera priserna med en faktor `60 / uppmätt median merges per runda` när speltestdata finns.

## 3. Belägg

### 3.1 Diagnos av nuvarande kurva
Mussla k kommer vid `round(50·k^1,3)` merges: 50, 123, 209, 405 (k=5), 998 (k=10), 2 456 (k=20), 6 445 (k=42). Skicklighetsmusslorna (nivå 7–10, första skimrande, första dubbel-Klunk) kommer enligt UI.md §6 (nivå 10 "var 3–5 min") och den garanterade skimrande senast runda 3 **troligen under de första 3–5 rundorna (uppskattning)**.

| Rundor | Kurva, 40 merges/r | Kurva, 80 merges/r | + skicklighet (uppskattning) | Totalt 40 / 80 |
|---|---|---|---|---|
| 1 | 0 | 1 | 1–2 | 1–2 / 2–3 |
| 3 | 1 | 3 | 3–4 | 4–5 / 6–7 |
| 10 | 4 | 8 | 5–6 | 9–10 / 13–14 |
| 30 | 11 | 19 | 6 | 17 / 25 |

- **Exponenten 1,3** är nästan linjär. Takten sjunker bara från cirka 1 per runda till cirka 1 per 2 rundor. Mål: 1 per 3–4.
- **Basen 50** gör de tre första tröskelvärdena (50/123/209) till en eller två rundor.
- **Skicklighetsmusslorna** hamnar alla i första timmen. Det dubblar starttakten.
- **Retroaktiviteten** (`grantBoxes` jämför mot `boxesEarned = 0` i en ny sparfil) är den mest sannolika förklaringen till just Anders upplevelse. Han hade spelat v1.0–1.1. Hans `stats.merges` kan läsas i debugpanelen.
- Med 48 musslor och 1 per 3–4 rundor räcker poolen i 144–192 rundor (12–16 h). Idag räcker den i cirka 107 rundor vid 60 merges per runda, och kortare med retroaktiv utbetalning.

### 3.2 Paper.io 2 (Voodoo)
| Fråga | Fakta (sek.) | Saknas |
|---|---|---|
| Valutor | Mynt och gems. Nycklar ("3 keys") öppnar kistor. Recensioner uppger att gyllene nycklar togs bort cirka maj 2026 och att man i stället betalar gems för slumpkistor ([Gamigion](https://www.gamigion.com/1-hour-analysis-paper-io-2-by-voodoo/), [MWM/App Store-recensioner](https://mwm.ai/apps/paper-io-2/1423046460)) | Mynt per match och per procent yta |
| Figurer | Heroes: Common/Rare/Epic/Legendary. Butiken har "Card Offers" och "Chests". Kortutbudet kan uppdateras ([Gamigion](https://www.gamigion.com/1-hour-analysis-paper-io-2-by-voodoo/)) | Kistpriser, odds |
| Gratis kistor | Den som tar hela kartan får ett bonusspel på 6 s med kistor som kan låsa upp figurer ([Voodoo-support](https://paper2-help.freshdesk.com/support/solutions/articles/202000095753-how-to-progress-in-paper-io-2-)). Dagliga och veckovisa uppdrag finns | Hur ofta en vanlig spelare får en kista |
| Uppgradering | Krafter är uppgraderbara. Supportsidan listar "what improves when you upgrade" ([Voodoo-support](https://paper2-help.freshdesk.com/support/solutions/articles/202000102996-all-character-powers-listed)) | Kostnad per nivå, effektsiffror |
| Annonser (kopieras inte) | Cirka 28 mellanannonser per timme, belöningsvideo för återupplivning och blå kistor, köp för att ta bort annonser ([Gamigion](https://www.gamigion.com/1-hour-analysis-paper-io-2-by-voodoo/)) | |

**Slutsats:** en kalibrering "som Paper.io 2" går inte att belägga numeriskt. Det enda vi säkert kan låna är strukturen: flera kisttyper med olika rariteter, köpta för intjänad valuta, och figurer vars förmåga blir bättre per nivå. Tiden till "allt" i Paper.io 2 är okänd.

### 3.3 Benchmark
| Spel | Valuta per runda | Pris per låda | Tid per ny figur (uppskattning) | Uppgraderingskurva |
|---|---|---|---|---|
| **Crossy Road** | Mynt: 1 per mynt och 5 per rött. Videoklipp visar 43–94 mynt per runda ([YouTube](https://www.youtube.com/watch?v=c45VhvPjKgY)). Gåva med ökande intervall (tak 3–6 h) på 20–1 020 mynt, och 20 mynt per annons ([wiki](https://crossyroad.fandom.com/wiki/Coins)) | 100 mynt per dragning ([wiki](https://crossyroad.fandom.com/wiki/Prize_Machine)). Dubbletter förekom i originalet: 26 800 mynt för 95 % säkerhet på allt ([Sharp 2015](https://www.robertsharp.co.uk/2015/02/25/how-many-coins-do-i-need-to-get-all-the-characters-in-crossy-road/)). En källa anger att dubbletter numera ger 100 mynt tillbaka ([guide](https://eathealthy365.com/unlocking-every-crossy-road-character-a-complete-walkthrough/), motstridigt) | 1 dragning per cirka 1–2 rundor, alltså några minuter. Nya figurer blir sällsynta mot slutet på grund av dubbletter | Ingen |
| **Brawl Stars** (2024–26) | Daily Wins: 6 belöningar på dagens 6 första vinster, varav cirka 3 Starr Drops (vinst 1, 4 och 8 enligt en källa). Chaos Drop på vinst 6 sedan dec 2025 ([Fandom](https://brawlstars.fandom.com/wiki/Starr_Drops), [After Strategy](https://after-strategy.com/en/brawl-stars-free-rewards-complete-guide/)) | Intjänas och köps inte. Odds: rare 50 %, super rare 28 %, epic 15 %, mythic 5 %, legendary 2 % ([Supercell](https://support.supercell.com/brawl-stars/en/articles/starr-drops-chances-2.html)) | 1 drop per cirka 3 vinster. De flesta drops ger mynt eller power points, inte figurer | Power 1→11: 3 740 PP + 7 765 mynt ([sports360](https://sports360news.com/en/esports/brawl-stars-upgrade-costs-explained/11143150)). Per nivå (ur minnet, **stämmer med totalsumman men är obekräftat**) 20, 35, 75, 140, 290, 480, 800, 1 250, 1 875, 2 800 mynt, alltså cirka ×1,6 per steg |
| **Subway Surfers** | Mynt i banan. Mysterielådor hittas i banan (ofta 2–3 per runda) ([wiki](https://subwaysurf.fandom.com/wiki/Mystery_Box)) | Mysterielåda 500 mynt, ger 200–1 500 mynt, nycklar eller sällan jackpot ([Theria](https://theriagames.com/guide/subway-surfers-mystery-box/)) | Figurer köps direkt. Begränsade figurer kostar 95 000 mynt ([wiki](https://subwaysurf.fandom.com/wiki/Coin)) | Power-ups uppgraderas med mynt |
| **Royal Match** (pussel) | Mynt per klarad bana (50 för svåra, sek.) plus mynt för överblivna drag. Områdeskista när ett område är klart ([help center](https://dreamgames.helpshift.com/hc/en/3-royal-match/faq/21-how-can-i-obtain-and-use-coins/)) | Kistan är deterministisk och kommer vid milstolpar | Exakta siffror saknas | Ingen |

**Mönster:**
1. Den vanliga valutan tjänas varje runda och syns direkt.
2. Lådor kommer ofta, men de flesta innehåller "fyllnad" (mynt eller PP) eller dubbletter.
3. Uppgraderingar växer ungefär geometriskt (×1,5–2,5 per steg).

KLUNK saknar fyllnad och dubbletter: varje mussla är en ny figur. Därför är 1 mussla per 15–20 min (3–4 rundor à 5 min, uppskattning) ungefär lika mycket *nytt* som i Brawl Stars. Det är långsammare per låda men inte per figur (bedömning, inte mätt).

### 3.4 Etik och regler när en intjänad valuta införs
| Område | Vad ändras |
|---|---|
| Play Families | Fortfarande inget simulerat spel om pengar. Att satsa virtuell valuta på slump liknar dock social casino mer än att få en mussla gratis ([Google](https://support.google.com/googleplay/android-developer/answer/9893335)). **Risken ökar något (bedömning).** |
| PEGI (juni 2026) | Betalda slumpobjekt ger PEGI 16 och definieras som köp med riktiga pengar "and/or exchanged for an in-game virtual currency" ([Reed Smith](https://www.reedsmith.com/articles/pegi-launches-interactive-risk-categories-overhauls-age-ratings-for-loot-boxes-in-game-spending-and-communication-features/)). Tidsbegränsade erbjudanden ger PEGI 12 och belöning för att återvända PEGI 7 ([PEGI](https://pegi.info/news/pegi-expands-age-rating-criteria-interactive-risk-categories)). **Oklart om en valuta som aldrig kan köpas räknas. Måste bekräftas i IARC-enkäten eller med PEGI.** |
| Apple 3.1.1 / Google oddskrav | Gäller köp med pengar. Ingen ändring |
| Forskning | Barn 7–14 kallade slumpbelöningar "scams" (CHI 2025, avatar-box §4). Xiao & Newall: minska komplexiteten och gör lådorna uttömbara. Två valutor är den klassiska mjuk/hård-strukturen för att dölja värde ([Game Developer](https://www.gamedeveloper.com/business/types-of-game-currencies-in-mobile-free-to-play)). Här är syftet bara att skilja tid från skicklighet |
| Goal-gradient | Kaffekort: köpen kom cirka 20 % tätare nära målet, och förifyllda stämplar snabbade upp ([Kivetz m.fl. 2006](https://journals.sagepub.com/doi/abs/10.1509/jmkr.43.1.39)). En stapel mot nästa mussla motiverar. Press uppstår först med tidsgräns, förlust eller påminnelser |

## 4. Osäkerheter
- Merges per runda, rundlängd, skimrande och kedjor per runda är **omätta**. Stjärnsand per runda (2,4 i simuleringen) bygger på antaganden.
- Siffror för Paper.io 2 saknas helt. Brawl Stars nivåtabell kommer ur minnet och har bara kontrollerats mot totalsumman.
- PEGI-tolkningen av intjänad valuta är obekräftad.
- Om barn 7+ förstår två valutor och tre musslor är inte testat. Reservplan: bara pärlor, guldmusslan kostar 1 500 pärlor.
- Simuleringen köper bara vanliga musslor för pärlor. Silver är värdeneutral per figur men ger högre raritet.

## 5. Förslag för KLUNK

### 5.1 Resurser (per runda, visas i rundavslutet och räknas upp på ≤0,6 s)
- **Pärlor** (vanlig): **1 per merge**. Cirka 60 per runda (uppskattning).
- **Stjärnsand** (sällsynt): **+1** per skimrande som skapas, **+1** per kedja ≥3 (max 3 per runda), **+2** per nivå 10. Engångsbonusar på **+3** vardera för första nivå 7, 8, 9, 10, första skimrande och första dubbel-Klunk (ersätter skicklighetsmusslorna), och **+10** per full boksida. Cirka 2–3 per runda (uppskattning).

### 5.2 Musslor (inga dubbletter, vikter omnormeras bland rariteter ≥ golvet som har figurer kvar)
| Mussla | Pris | Golv | Vanlig/Ovanl./Sällsynt/Episk/Leg./Mytisk |
|---|---|---|---|
| Vanlig (sandfärgad) | 300 pärlor | vanlig | 50 / 30 / 13 / 5 / 1,5 / 0,5 % |
| Silver | 700 pärlor | ovanlig | – / 50 / 30 / 14 / 4,5 / 1,5 % |
| Guld | 50 stjärnsand | sällsynt | – / – / 50 / 32 / 13 / 5 % |
| **Gratis** (vanlig) | vid 120 och 400 merges, sedan var **750:e** merge (platt) | | som vanlig |

- Första musslan (runda 1) är alltid sällsynt, som idag.
- Tomt golv: silver och guld går inte att välja (grå med bock).
- **När alla 48 ägs:** butiken visar full bok. Gratismusslan ger 10 stjärnsand, och pärlor och sand går bara till uppgraderingar. När allt är på III står räknarna still och ingen ny sink införs (ärligt slut, beslut för teamet).

### 5.3 Uppgradering (ersätter XP i §14.4)
| Raritet | I→II | II→III |
|---|---|---|
| Vanlig | 80 pärlor | 200 + 4 sand |
| Ovanlig | 100 | 250 + 6 |
| Sällsynt | 150 | 400 + 10 |
| Episk | 200 | 500 + 14 |
| Legendarisk | 250 | 650 + 18 |
| Mytisk | 300 | 800 + 24 |

Steget är ×2,5–2,7 (Brawl Stars cirka ×1,6 per steg men över 10 steg). Effekttaket på +30 % mellan I och III behålls.

### 5.4 Simulering (`docs/research/economy-sim.py`, 300 körningar, median, 5 min per runda)
| Merges/r | Spelare | Kompisar efter 1/3/10/30/60/100 r | 24 st | 48 st | Favorit III | Topp 3 III | Allt III |
|---|---|---|---|---|---|---|---|
| 40 | samlare | 1/1/3/8/15/24 | 8,2 h | 17,0 h | – | – | – |
| 40 | blandad | 1/1/2/7/10/16 | 12,2 h | 23,4 h | 1,9 h | 8,8 h | – |
| 60 | samlare | 1/2/4/11/21/34 | 5,8 h | 11,9 h | 42 h | 44 h | 44 h |
| 60 | blandad | 1/2/4/8/14/24 | 8,3 h | 16,2 h | 1,2 h | 5,4 h | 41 h |
| 60 | uppgraderare | 1/2/3/7/16/28 | 7,1 h | 14,2 h | 0,8 h | 42 h | 43 h |
| 80 | samlare | 1/2/5/14/26/44 | 4,4 h | 9,1 h | 32 h | 33 h | 33 h |
| 80 | blandad | 1/2/4/10/18/32 | 6,3 h | 12,4 h | 0,9 h | 4,0 h | 31 h |

Med 60 merges per runda kommer musslorna från (blandad spelare): 17 gratis, 23 köpta för pärlor, 7–8 guld och 1 onboarding. Takten blir 1 per 3,0 (samlare) till 4,1 (blandad) rundor.

### 5.5 Boken (fliken Kompisar, text tillåten här)
- Per kompis: namn, **förmågetext på högst 60 tecken** från `ability.text: { en, sv }` och en **stapel i tre segment** (I/II/III, fyllda i raritetsfärg) som ersätter romberna. Därunder parametervärdet per nivå med nästa värde markerat, till exempel "6 s → **8 s** → 10 s", och en knapp med pärl-ikon och pris. Knappen är grå med en fyllnadsring om pengarna inte räcker. Ringen är goal-gradient utan press.
- Exempel: Lykt-Lisa EN "Lights up matching pieces while you aim." / SV "Lyser upp likadana medan du siktar." Spådamen Siri EN "See two pieces ahead in the queue." / SV "Se två steg fram i kön." Vanlig: EN "Leaves a trail of bubbles." / SV "Lämnar ett spår av bubblor."
- Butikshyllan: tre musslor med pris och en egen oddsburk (25 pärlor) per mussla.

## 6. Skyddsräcken
- Inga köp med pengar och inga annonser. Valutorna går aldrig att köpa, byta eller överföra.
- Ingen timer, inga dagsbonusar, inga tidsbegränsade eller roterande erbjudanden. Priserna ändras aldrig.
- Inga dubbletter. Varje mussla ger en ny figur, så det finns inget "förlust"-utfall. Raritetsgolv per mussla. Oddsen syns per mussla (burk) och i procent på föräldrasidan.
- Ingen spelautomatestetik: ingen rullning, ingen myntklang, inget "nästan", ingen "öppna alla". Öppningen tar fast 1,2 s och ett tryck hoppar över.
- Ingen påminnelse om att "du har råd". Stapeln syns bara i boken och kort i rundavslutet (omstart <0,5 s).
- Om PEGI eller IARC klassar köp av slump för intjänad valuta som "paid random items": gör köpta musslor till **välj 1 av 3 synliga figurer** (Starr Road-modellen) och låt bara gratismusslan vara slump. Ekonomin blir densamma.

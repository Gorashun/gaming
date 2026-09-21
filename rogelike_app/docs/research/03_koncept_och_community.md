# 03 – Community-röst och konceptkandidater

*Författare: rpg-nerd-roguelike · 2026-09-21 · Status: underlag för beslut (ej beslut)*

Märkning: **[FAKTA]** = källbelagt via sökning, **[BEDÖMNING]** = min egen tolkning som rollspelsnörd. Källor listas i slutet med datum där det gick att fastställa.

---

## 1. Vad communityt älskar och hatar (2024–2026)

### Vad de älskar
- **"Det var mitt fel"-död.** Shattered Pixel Dungeon (SPD) hyllas för att vara "brutal, honest" där "every death is your fault because you were too greedy or didn't check your inventory" [FAKTA, Steam-recensioner via Steambase, 95/100, ~1 770 recensioner]. Slice & Dice prisas för att partyt "dör oförutsägbart men aldrig orättvist" [FAKTA, neverplaythis.com-recension, odaterad 2025].
- **Få enkla regler som kombineras explosivt.** Balatro-analyser (Goomba Stomp, ejaw.net, 2024–2026) pekar ut samma sak: varje Joker är läsbar ensam, tre tillsammans ger kedjor från hundratal till miljoner. Belöningen är variabel på tre nivåer (hand, blind, ante) [FAKTA]. Det är exakt den "TikTok-dragning" Anders vill åt [BEDÖMNING].
- **Predictable randomness.** StS:s kortlek känns rättvis för att spelaren kan räkna på omblandning ("marble bag") [FAKTA, Medium/JeongHyeonUk 2025; GMTK "Two Types of Random"]. Input-slump (vad du får) + full agens över output (vad du gör med det) är den formel communityt accepterar.
- **Nollmonetisering på mobil.** SPD:s mest citerade beröm är inte spelet utan "no ads, no energy bars, no 'buy 500 gems'" [FAKTA]. Rogueliker.com:s Android-lista har som *inklusionskrav* att spelet saknar exploaterande monetisering [FAKTA].
- **Korta, täta runs.** Konsensus i utvecklar- och spelartrådar: ~30 min är idealt, >1 h tröttar innan man låst upp hälften [FAKTA, itch.io/Steam-trådar]. Hoplite hyllas för att vara "ideal to chain-die on the bus" [FAKTA, ResetEra/TouchArcade 2014].

### Vad de hatar
- **RNG utan utväg.** Dicey Dungeons-klagomål: "rolls badly, can't deal damage, nothing you can do except lose" [FAKTA, Pocket Gamer]. Luck be a Landlord: "if the right items don't show up you simply won't win"; Push Square 6/10 för "inflexible design, hard to build momentum" [FAKTA, 2025]. Slay the Spire 2 fick 8 000+ negativa recensioner 17–18 april 2026 och tappade till "Mixed"; huvudklagomål var att fiender "completely kill you for using certain strategies" och att förlust kändes som ren RNG [FAKTA, GameRant 2026].
- **"Every run feels the same".** Återkommande Steam-kritik: samma rum, mediokra powers, "limited synergies". Även Balatro får kritiken "identify garbage jokers from ok jokers" och att den belönar enkelspåriga builds [FAKTA, Steam negativa recensioner 2025].
- **Meta-progression som ersätter skicklighet.** Debatten är delad: en falang säger att meta-progression är enda skälet de ger roguelites en chans, en annan vill att bara skicklighet står mellan dem och segern [FAKTA, ResetEra-tråd, Steam-forum]. [BEDÖMNING]: den lösning båda läger accepterar är *horisontella* upplåsningar (nya klasser, items, modifierare) i stället för +5 % skada-staplar.
- **Mobilspecifikt:** (1) Annonser – även *frivilliga* revive-ads i Vampire Survivors får "feels bad to constantly be offered them" [FAKTA, App Store-recension]. (2) Energi/timers och gem-butiker är diskvalificerande i alla kuraterade listor [FAKTA]. (3) Kontroller – dubbeltapp-krav, tap-vs-drag-förväxling och feltryck i täta lägen är de vanligaste buggrapporterna [FAKTA, DiceBound issue #352 m.fl.]. (4) Läsbarhet – till och med Balatros hyllade port får kritik för att kort är svåra att skilja åt på små skärmar; High Contrast-läget lyfts som räddningen [FAKTA, Engadget/TouchArcade sept 2024]. (5) För lite djup – autobattlers på Google Play får "unplayable past a point"/"shallow" och pris-klagomål [FAKTA, Despot's Game-recensioner]. (6) Offline är ett uttalat krav i varje "best Android roguelikes"-lista [FAKTA].

**[BEDÖMNING] Sammanfattad kravbild:** input-slump + total agens, läsbar synergi, 15–30 min runs, horisontell meta, noll dark patterns, enkeltapp-kontroller med ångra, hög kontrast som standard, offline.

---

## 2. Tre konceptkandidater

### Kandidat A – "HANDEN" (kompakt kortbaserad deckbuilder)
**Pitch:** Slay the Spire krympt till en tumme: fem kort i handen, vertikal skärm, strider på 3–5 drag. Varje run bygger du en lek av max 20 kort där kortens *position i handen* avgör effekt.
**Kärnloop:** 30 s = spela en hand, se skada räknas upp. 5 min = en strid + ett kortval + en händelse. 1 h = 2–3 runs, en ny arketyp upplåst.
**Täta kickar:** kortdrag är redan en beprövad variabel belöning; positionsregeln ger "åh, det där kortet HÄR" varje drag.
**Synergiregler (5):** (1) Kort längst till vänster spelas gratis. (2) Kort med samma färg bredvid varandra länkar: effekt ×antal i kedjan. (3) "Eko"-kort upprepar föregående korts effekt. (4) Övertalig skada blir "Glöd" som laddar nästa kort. (5) Leken blandas *synligt* – spelaren ser draghögen.
**Meta:** nya arketyper, kortpooler och "förbannelser" (svårighetsmodifierare) – inga statboostar.
**Oväntat/segt/askul:** "Tyst våning" med bara händelser (segt) → "Kortsmedjan" som låter dig svetsa två kort till ett (askul).
**Genomförbarhet:** 8/10 – kort = rektangel + text + ikon, ingen animation krävs. **Risk:** genren är mättad; StS mobil, Balatro och Peglin finns redan; läsbarhet av 5 kort + fiende-intents på 6" skärm är exakt det Balatro-porten kritiseras för.

### Kandidat B – "KASTGROPEN" (tärnings-autobattler med agens) – hybrid Slice & Dice × Luck be a Landlord × Balatro
**Pitch:** Ditt lag är sex tärningar. Varje runda rullar du, *placerar* tärningarna i fem slots på ett bräde, och ser en kedjereaktion spela upp sig vänster→höger. Din "lek" är tärningarnas sidor, som du smider om mellan striderna.
**Kärnloop:** 30 s = rulla, placera, se kedjan explodera (eller inte). 5 min = en strid (3–6 rundor) + ett smidesval + en relik. 1 h = 2–4 runs om 15–25 min, ny tärningstyp eller startklass upplåst.
**Täta kickar:** varje *runda* är ett slot-drag med synligt utfall, men med Slice & Dice-agens (du väljer var varje öga hamnar, du har 1–2 omkast) så förlusten känns som ditt val. Kedjan animeras med stigande siffror och ljud – Balatro-effekten utan att kopiera poker.
**Synergiregler (5):**
1. **Par/triss/kåk:** identiska ögon i angränsande slots multiplicerar (×2, ×4, ×8).
2. **Överflöd rullar över:** skada över fiendens HP går vidare till nästa fiende; oanvända ögon blir "Laddning" som läggs på nästa rundas första tärning.
3. **Slotarna har egenskaper:** slot 1 "Eld" (bränn), slot 3 "Spegel" (kopiera grannen), slot 5 "Amboss" (dubblar om tärningen är ≥5). Slotar byts via reliker.
4. **Sidor är permanenta items:** du smider om enskilda sidor ("byt en 1:a mot en Giftdroppe"). Tärningen är din build.
5. **Kedjan går alltid vänster→höger** och visas *innan* du bekräftar. Ingen dold slump i utfallet.
**Meta:** horisontell: nya tärningsmaterial (ben, glas, järn) med egna regler, startklasser, "Gropens djup" (ascension-liknande modifierare), en samling ("Kodex") av sett kedjor med rekordskada. Inga permanenta statboostar.
**Oväntat/segt/askul med avsikt:** *Glasvåningar* där tärningar kan spricka (segt, tvingar försiktighet) → *Ödeskast* var 4:e våning där ett kast ändrar en spelregel för resten av runden ("alla 1:or räknas som 6:or", "slot 5 triggar två gånger"). Sällsynta "Jackpot"-tärningar (1/40 runs) med sju sidor. Fiender som *stjäl* en tärning och rullar den mot dig.
**Genomförbarhet:** 9/10 – tärningar och slots är geometri; fiender kan vara emoji/silhuetter; hela striden är en deterministisk vänster→höger-simulering som testas utan UI (uppfyller CLAUDE.md-kravet direkt). **Risk:** upplevs som "slot-passivt" om agensen är för liten (LBaL-kritiken), eller som Slice & Dice-klon om tärningarna är för lika. Ren tärnings-RNG kan trigga Dicey Dungeons-ilskan om omkast saknas.

### Kandidat C – "GROTTAN" (enskärms-grid-crawler, Hoplite-riktning)
**Pitch:** Varje våning är ett 7×7-rum som får plats på en skärm. Deterministiska strider (inga missar), all slump i layout, fiendeplacering och loot. Du dör aldrig av en tärning – bara av en felflytt.
**Kärnloop:** 30 s = ett drag, en fiende död eller en fälla undviken. 5 min = en våning + ett altarval. 1 h = en full run (12–15 våningar) eller 2 korta.
**Täta kickar:** pusselkänsla per drag, "Hoplite-klick" när en förflyttning dödar tre fiender. Kickarna är tätare *kognitivt* men glesare *visuellt*.
**Synergiregler (5):** (1) Rörelse triggar effekt (hopp, dash, knuff). (2) Fiender som knuffas in i varandra tar skada. (3) Terräng är aktiv (lava, is, vatten). (4) Föremål har laddningar som fylls av kills. (5) Altare ger kraft mot permanent nackdel.
**Meta:** horisontell (nya altare, startföremål, "eder"), som Hoplite.
**Oväntat/segt/askul:** "Mörka våningar" med begränsad sikt (segt) → "Arenavåning" där hela rummet är knuffbart (askul).
**Genomförbarhet:** 5/10 – kräver tileset, fiendesprites med riktning, förflyttningsanimation, pathfinding, sikt. Utan grafiker landar det i ASCII/emoji, vilket begränsar marknaden. SPD är dessutom gratis och nästan perfekt – vi konkurrerar med det bästa i genren. **Risk:** kick-kadensen är för låg för TikTok-kravet; läsbarhet av 49 rutor + UI på telefon; lång utvecklingstid innan det är kul.

---

## 3. Betyg och vinnare

| Kriterium (1–10) | A Handen | B Kastgropen | C Grottan |
|---|---|---|---|
| Roligt (kick-kadens, "en till") | 7 | **9** | 7 |
| Djup | 8 | 7 | **9** |
| Läsbarhet liten skärm | 5 | **9** | 6 |
| Replayability | 8 | **8** | 7 |
| Genomförbarhet solo utan grafiker | 8 | **9** | 5 |
| **Totalt** | 36 | **42** | 34 |

**Vinnare: B – Kastgropen.** Skoningslöst ärligt:
- A är det tryggaste konceptet och det tråkigaste beslutet. Det blir "StS fast sämre" oavsett hur bra vi gör det, och läsbarhetsproblemet är dokumenterat även hos branschens bästa port. Ingen på r/roguelites väntar på deckbuilder nr 400.
- C är det spel *jag* helst vill spela, men det är fel spel för kravet. Kickarna kommer var femte minut, inte var trettionde sekund, och utan grafiker ser det ut som ett hobbyprojekt bredvid SPD. Djupet räddar inte ett spel man inte öppnar på bussen.
- B vinner för att *varje runda är en belöningshändelse* som spelaren ändå äger. Det är den enda kandidaten där "oväntat, ibland segt, plötsligt askul" är inbyggt i själva mekaniken (kastet) och inte i innehållet runt om. Det är också den billigaste att göra vacker: tärningar, siffror, skakningar, partiklar. Och det är genuint testbart: hela striden är en funktion `resolve(board, dice, relics) -> events`.
- **B:s svaghet är djupet (7).** Om vi inte lyckas med sidsmidet (regel 4) blir det LBaL: ett slot-spel man tittar på. Djupet måste komma från placering + omsmide + slot-egenskaper, inte från fler tärningar.

---

## 4. Vinnaren fördjupad: Kastgropen

### Moment-katalog (10 situationer)
1. **Överflödskedjan.** Du dödar en råtta med 40 skada för mycket; överflödet rullar genom fyra fiender bakom den. Skärmen skakar fyra gånger. *Skrik.*
2. **Den envisa 1:an.** Samma tärning visar 1 tre rundor i rad. Fjärde rundan sätter du den i Amboss-sloten ändå – och en relik gör "1:or räknas som 6:or". *Skratt.*
3. **Glasskärvan.** Din bästa tärning spricker på en glasvåning för att du blev girig och kastade om. *Svordom* – men du vet varför.
4. **Spegelkåken.** Spegel-sloten kopierar en triss till en kåk och multiplikatorn går ×8 → ×32. Siffran får inte plats i rutan. *Skrik.*
5. **Tjuven.** En fiende stjäl din Giftdroppe-tärning och rullar den mot dig. Du dödar honom med hans egen tärning nästa runda när den ramlar tillbaka. *Skratt/skrik.*
6. **Ödeskastet som sabbar.** "Slot 5 triggar två gånger" – och där står din självskade-tärning. Resten av runden är ett pussel om att vända en nackdel. *Svordom → tillfredsställelse.*
7. **Sista ögat.** Bossen har 3 HP. Du har en tärning kvar, omkastet är slut. Den visar 3. *Tystnad, sedan skrik.*
8. **Jackpot-tärningen.** Sjunde sidan dyker upp för första gången efter 40 runs. Kodexen låser upp en post. *Skrik + skärmdump.*
9. **Fällan du byggde själv.** Du smidde alla sidor till höga ögon – nu triggar inte "låga ögon läker". Du dör med 60 skada per runda och 0 läkning. *Svordom, "mitt fel".*
10. **Den sega våningen som lönar sig.** Tre "tysta" våningar med bara skräp-loot. Sedan ett altare: "Offra tre värdelösa reliker → en Mytisk". Du har exakt tre. *Skratt.*

### Tre startklasser/arketyper
- **Smeden** – 6 järntärningar (1–6). Startrelik: "Amboss-slot ger +1 öga permanent till tärningen efter varje kåk". Spelstil: bygg få, enorma tärningar. Kick: långsam start, exponentiell slut.
- **Spelaren** – 8 bentärningar (0–5, fler tärningar, lägre värden), 2 omkast/runda. Startrelik: "Varje par ger +1 omkast". Spelstil: fiska efter kombos varje runda. Kick: högsta variansen, flest "sista ögat"-ögonblick.
- **Alkemisten** – 5 glastärningar med symbolsidor (Gift, Eld, Frost, Blod, Tomrum). Startrelik: "Två olika symboler bredvid varandra reagerar". Spelstil: element-reaktioner i stället för siffror. Kick: kedjor som ser annorlunda ut varje gång.

### 15 items/effekter som visar synergiexplosioner
| # | Item | Effekt | Exploderar med |
|---|---|---|---|
| 1 | Blytärning | Låst på 6, kan ej kastas om | Spegel-slot (gratis kåk-grund) |
| 2 | Giftdroppe (sida) | 3 gift/runda i stället för skada | Överflöd: gift rullar över som gift |
| 3 | Ekospegel (relik) | Slot 3 kopierar även *effekt*, inte bara öga | Amboss (dubbel dubbling) |
| 4 | Snöbollen (sida) | +1 öga varje runda den inte används | Spelarens omkast (spara den) |
| 5 | Domino (relik) | När en tärning triggar, triggar grannen till höger igen | Regel 5: kedjan blir ×2 lång |
| 6 | Trasig våg | Alla udda ögon räknas som jämna | Par-jakt: 1/3/5 blir 2/4/6 |
| 7 | Vampyrtand (sida) | Läk = skada/2 | Överflöd (läkning skalar med overkill) |
| 8 | Fuskkuben (relik) | Första kastet varje strid är alltid en triss | Smedens Amboss (garanterad start) |
| 9 | Tomrumssida | Tar bort sloten den ligger i – och dess nackdel | Glasvåningar (offra sprucken tärning) |
| 10 | Kedjebrytaren | Kedjan går höger→vänster i stället | Ladda-slot hamnar sist: bank hela rundan |
| 11 | Bläckfisk (relik) | Slot 2 och 4 räknas som angränsande | Kåk med hål i |
| 12 | Blodpris | −5 HP/runda, alla multiplikatorer +1 | Vampyrtand (nettoläkning) |
| 13 | Magnet | Efter kastet dras identiska ögon ihop automatiskt | Sparar placeringstid; Domino förlänger |
| 14 | Falskt öga | En tärning visar alltid grannen +1 | Raka: 3-4-5-6 = "Stege"-bonus |
| 15 | Kodexens sista sida | Varje kedja du aldrig sett förut ger +50 % | Alkemistens symbolreaktioner |

---

## 5. Fem saker som får communityt att hata spelet
1. **En enda annons, timer eller gem-valuta.** Rogueliker/SPD-recensionerna visar att detta är binärt: finns det, är vi ute ur varje kuraterad lista [FAKTA].
2. **Dold slump i utfallet.** Om kedjan kan avvika från förhandsvisningen, eller om fiender har dolda missfaktorer, får vi Dicey Dungeons-kritiken. Regel 5 (visa kedjan innan bekräftelse) är helig.
3. **Meta-progression som statboost.** "+10 % skada efter 50 runs" gör att veteranerna kallar det pay-to-win-utan-pengar och nybörjarna känner sig tvingade att grinda. Bara horisontella upplåsningar.
4. **Dubbeltapp, feltryck och ingen ångra.** Placering måste vara ett drag eller ett tapp, med "Ångra placering" fram till bekräftelse [FAKTA om klagomålstyp].
5. **Enkelspårig meta där en tärningstyp alltid vinner.** Balatros svagaste kritik ("identify garbage jokers") blir vår om Smeden alltid är bäst. Varje arketyp måste ha ett eget kedjeutrymme och Kodexen måste belöna *variation*, inte högsta siffra.

---

### Källor (hämtade 2026-09-21)
- Steambase, SPD-recensioner (95/100): https://steambase.io/games/shattered-pixel-dungeon/reviews
- TouchArcade GotW SPD, 2021-08-20: https://toucharcade.com/2021/08/20/toucharcade-game-of-the-week-shattered-pixel-dungeon/
- Rogueliker, Best Android/iOS roguelikes (inklusionskrav utan exploaterande monetisering): https://rogueliker.com/android-roguelikes/
- GameRant, StS2 review-bombed (april 2026): https://gamerant.com/slay-the-spire-2-review-bombed-why/
- Pocket Gamer, Dicey Dungeons-recension: https://www.pocketgamer.com/dicey-dungeons/review/
- TouchArcade, LBaL mobilrecension 2023-07-25: https://toucharcade.com/2023/07/25/luck-be-a-landlord-mobile-review-iphone-ipad-android/
- Push Square, LBaL 6/10 (2025): https://www.pushsquare.com/reviews/ps4/luck-be-a-landlord
- Engadget, Balatro "almost perfect mobile port" (sept 2024): https://www.engadget.com/gaming/balatro-is-an-almost-perfect-mobile-port-163050971.html
- Goomba Stomp / ejaw.net, Balatro-designanalyser (2024–2026): https://goombastomp.com/how-balatro-became-one-of-the-most-addictive-roguelikes/ , https://ejaw.net/balatro/
- Steam, Balatro negativa recensioner (inkl. dec 2025): https://steamcommunity.com/app/2379780/negativereviews/?browsefilter=toprated
- ResetEra, "Do you like meta progression…" (odaterad): https://www.resetera.com/threads/do-you-like-meta-progression-in-your-roguelikes-roguelites.1341955/
- Kotaku, Vampire Survivors mobil och "non-predatory" monetisering, 2022-12: https://kotaku.com/vampire-survivors-free-iphone-steam-mobile-smartphone-1849955308
- neverplaythis.com, Slice & Dice-recension: https://www.neverplaythis.com/reviews/slice-dice-roguelike-dice-tactics-review
- Medium/JeongHyeonUk, Designing Fair RNG in Roguelikes: https://medium.com/@JeongHyeonUk/designing-fair-rng-in-roguelikes-balancing-luck-and-skill-7b967230e961
- GMTK, The Two Types of Random: https://www.youtube.com/watch?v=dwI5b-wRLic
- DiceBound issue #352 (dubbeltapp-klagomål): https://github.com/Krtz/DiceBound/issues/352
- TouchArcade/ResetEra om Hoplite (2014): https://toucharcade.com/2014/01/08/hoplite-review/
- Google Play, Despot's Game-recensioner: https://play.google.com/store/apps/details?id=com.KonfaGames.DespotsGame

*Begränsning: rogueliker.com, resetera.com och gamerant.com kunde inte hämtas i fulltext (proxyblock); uppgifterna därifrån bygger på sökmotorutdrag.*

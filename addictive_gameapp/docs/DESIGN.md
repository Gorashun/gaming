# DESIGN.md – KLUNK (sanningskälla för spelet)

Version 1.0 · 2026-09-20 · Ägare: projektledare. Ändringar loggas i STATUS.md.

## 1. Kärnloop
1. Ett objekt hänger i toppen av burken. Spelaren drar fingret i sidled för att sikta, släpper för att tappa.
2. Objektet faller med fysik. Två objekt av **samma nivå** som nuddar smälter ihop till **ett objekt av nästa nivå** i kontaktpunktens mittpunkt, med en liten utåtriktad impuls på grannarna.
3. Nästa objekt kommer från kön (se Regissören). Förhandsvisning av nästa objekt syns hela tiden.
4. Förlust när något objekt (som inte är det senast tappade) har sitt centrum ovanför **farolinjen** i mer än 1,5 s sammanhängande.
5. Ett tryck på förlustskärmen startar ny runda på under 0,5 s. Ingen bekräftelse, ingen meny.

## 2. Objektnivåer
11 nivåer, index 0–10. Tema bestäms av UI-designern (INTE frukter). Data ligger i `app/src/data/levels.ts`.

| Nivå | Radie (px vid burkbredd 360) | Poäng vid skapande | Får ligga i kön |
|---|---|---|---|
| 0 | 14 | 1 | ja |
| 1 | 19 | 3 | ja |
| 2 | 25 | 6 | ja |
| 3 | 31 | 10 | ja |
| 4 | 38 | 15 | ja |
| 5 | 46 | 21 | nej |
| 6 | 55 | 28 | nej |
| 7 | 64 | 36 | nej |
| 8 | 74 | 45 | nej |
| 9 | 85 | 55 | nej |
| 10 | 97 | 66 + bonus 500 | nej |

Två nivå 10 som möts försvinner båda (poäng 1000, stor kick). Poäng är triangulära tal; balansering sker i data, inte i kod.

## 3. Burk och fysik
- Logisk spelyta 360×640, skalas till skärmen (Phaser Scale.FIT, porträtt). Burken är 320 bred, väggar 20 px, botten vid y=600, farolinjen vid y=110.
- Matter.js. Restitution 0,1, friktion 0,3, densitet proportionell mot radie². Gravitation 1,0 (Phaser-standard) justerbar i data.
- Dropp-cooldown: nästa objekt får släppas när det förra har nuddat något ELLER efter 600 ms, vad som kommer först.
- Merge-regel: kollisionsevent mellan två bodies med samma nivå och som inte redan är markerade för merge denna frame. Aldrig merga fler än ett par per body per frame.

## 4. Regissören (`app/src/systems/director.ts`)
Styr endast **vilken nivå nästa köobjekt får**. Rör aldrig fysiken. Seedbar (mulberry32) och testbar utan rendering. All balansering i `app/src/data/director.ts`.

| Läge | Varaktighet (drops) | Val av nivå |
|---|---|---|
| **Torka** | 15–40 slumpat | Likformigt 0–4, men **undviker** nivåer som just nu kan mergea direkt (finns fritt liggande objekt av den nivån nära toppen) med sannolikhet 0,7 |
| **Flöde** | 8–20 slumpat | Väljer med sannolikhet 0,6 en nivå som **kan** mergea direkt, annars likformigt 0–4 |
| **Kick** | 1 drop | Ett specialobjekt, sedan tillbaka till Torka |

- Lägesordning: Torka → Flöde → Torka → Flöde … Kick avfyras när räknaren `dropsSinceKick` passerar ett slumpat mål i intervallet 25–60. Målet dras om efter varje Kick.
- Första 10 dropsen i en runda är alltid Flöde (onboarding: spelaren ska få en merge inom 10 s).
- "Kan mergea direkt" = det finns minst ett fritt objekt av samma nivå vars ovansida ligger inom 120 px från farolinjen eller är översta objektet i sin kolumn (uppskattning, justeras).

### Specialobjekt (v1: två stycken)
- **Bomb** (radie 25): vid första kontakt med något: förstör alla objekt inom radie 110 px, poäng = summan av förstörda nivåers poäng ×2. Juice-intensitet 1,0.
- **Regnbåge** (radie 25): vid första kontakt med ett vanligt objekt av nivå n: de två blir ett objekt av nivå n+1. Juice-intensitet 0,8.
- Magnet skjuts till v1.1.
- Specialobjekt visas i förhandsvisningen med en tydligt annorlunda form och puls så spelaren hinner planera.

## 5. Combo och near-miss
- **Combo**: merges inom 1,2 s efter föregående merge ökar `combo` med 1. Reset när fönstret går ut. Pitch på merge-ljudet = bas × 2^(combo/12), tak vid combo 12.
- **Kedjemerge**: en merge som direkt orsakar nästa räknas som kedja; kedjelängd ≥3 ger kamerazoom och "kaskad"-ljud.
- **Near-miss (äkta)**: två objekt av nivå ≥8 som har mindre än 20 px gap men inte nuddar får en svag synkron puls. Aldrig fejkad. Försvinner när gapet ändras.
- **Rekordjakt**: när poäng ≥ 90 % av highscore visas highscore-markören som pulserande i HUD. När den passeras: newRecord-kick (intensitet 0,9).
- **Fara**: när något objekt har centrum inom 40 px under farolinjen: slow-mo till 0,6× tidsfaktor och dov ton. Tillbaka till 1,0× när faran är över. Max 3 slow-mo-triggers per 10 s.

## 6. Juice (`app/src/systems/juice.ts`)
En ingång: `juice.trigger(event, intensity: 0..1, x?, y?)`. Alla effekter skalas linjärt från intensity. Events: `drop`, `land`, `merge`, `chain`, `special`, `danger`, `loss`, `newRecord`, `record`.

| Effekt | Skalning | Tak |
|---|---|---|
| Ljud, pitch-stegring | pitch från combo, volym från intensity | – |
| Hit-stop | 0–6 frames vid intensity ≥0,3 | 100 ms |
| Scale-punch på det nya objektet | 1,0 → 1,0+0,35·i → 1,0, Back.easeOut, 220 ms | – |
| Partiklar | 6 + 24·i stycken, ärver hastighet, färg från objektets tema | 40 |
| Screen shake | amplitud 0–8 px, dämpas till 0 inom 300 ms | 8 px |
| Scorepop | siffra flyger från (x,y) till HUD på 500 ms | – |
| Haptik | 10 ms vid i<0,3, 30 ms vid i<0,7, 60 ms annars | – |
| Kamerazoom | endast `chain` och `special`, 1,0 → 1,06 → 1,0 på 400 ms | – |

**Lugnt läge** (ikon på startskärmen): alla intensiteter ×0,5, shake och zoom av.
**Flash-guard**: inget element får växla ljusstyrka mer än 3 gånger per sekund. Vitblixtar max 2 per sekund. Aldrig mättad röd blinkning. Testas i Playwright.

## 7. Skärmar
1. **Start**: ersatt av Start v2, se §18 och UI.md §16.
2. **Spel**: burk, nästa-förhandsvisning uppe till höger, poäng uppe till vänster, highscore-markör.
3. **Förlust**: overlay med poäng, highscore, bästa objekt denna runda. Hela ytan är en knapp: tryck = ny runda.
Onboarding: en animerad hand visar drag+släpp tills spelaren gjort sin första drop.

## 8. Sparning
`app/src/systems/save.ts`: `{ highscore, bestLevel, settings: { sound, haptics, calm }, stats: { runs, merges } }`. Capacitor Preferences på mobil, localStorage i webb. Skriv efter varje runda och vid inställningsändring. Aldrig tappa progression: skriv även vid `visibilitychange`.

## 9. Inte i v1
Konton, nätverk, annonser, köp, push, dagliga belöningar, timers, magnet-objekt, kosmetiska teman (v1.1), ledartavlor.

## 10. Acceptans för "testversion"
- Körs i webbläsare på mobilviewport 390×844, 60 fps på laptop, ≥50 fps på mellanklass-Android (mäts i fas 4).
- En 7-åring kan starta, tappa, mergea och starta om utan att läsa.
- Highscore överlever omstart av appen.
- APK byggd i GitHub Actions kan installeras på en Android-telefon.

## Förtydliganden (2026-09-20, projektledare)
- Burkgeometri: inre öppning 320 px (x 20→340), väggarna ritas utanför (x 0–20 och 340–360), botten y=600. Fysikkropparna följer detta.
- `record` = diskret rekordjakt-puls när poäng ≥90 % av highscore. `newRecord` = själva passeringen.
- Tema: "Glimtarna", lysande djuphavsvarelser (se UI.md). Alla nivåer bakas till texturer vid boot.

## 11. Pacing: mjuk auto-drop (beslut 2026-09-20, källa: research/urgency-research.md)
Regeln "ingen tidspress i UI:t" omformuleras till: **ingen synlig nedräkning och inget tidsbaserat straff.**
- Gäller endast i regissörens **Flöde**-läge. Aldrig i Torka, aldrig på specialobjekt, aldrig under fara/slow-mo/hit-stop. Av i Lugnt läge.
- Efter 3,0 s utan drop börjar det hängande objektet vicka (±4°, 0,8 Hz, ingen ljusstyrkeändring). Efter 6,0 s faller det själv, rakt ner där det hänger.
- Timern startar när objektet blir släppbart (cooldown klar) och nollställs vid varje drop.
- Konfig i `app/src/data/pacing.ts`: `PACING.mode: 'off' | 'flow'` (default `flow`), `rampStartMs`, `rampEndMs`, `rampDrops` (se §12), `wobbleDeg`, `wobbleHz`.
- Mätning i testhook: `autoDrops`, `dropLatencies` (ms från släppbar till drop) för att räkna P50/P90 och andel auto-drop. Mål: <10 % auto-drop hos vuxna, <20 % hos barn.

## 12. Ramp och siktlinje (beslut 2026-09-20)
- **Ramp**: auto-drop-tiden minskar med antal drops i rundan. `autoDropAtMs` går linjärt från 6000 ms vid drop 0 till 3500 ms vid drop 60, sedan konstant (golv). `nudgeAtMs` är alltid halva auto-drop-tiden. Övriga regler i §11 gäller oförändrat (bara Flöde, efter första egna drop, aldrig fara/slow-mo/special/Lugnt läge). Konfig i `data/pacing.ts`: `rampStartMs`, `rampEndMs`, `rampDrops`.
- **Siktlinje**: tre lägen i `data/aim.ts`: `always` | `aiming` | `off`. Default `aiming`: linjen visas bara medan fingret är nere och siktar, tonar in på 80 ms och ut på 120 ms. Inställning på startskärmen: en fjärde ikon (siktlinje) med två lägen, på = `aiming`, av = `off`. Av-läge ritas överkryssat i hudDim enligt UI.md. Sparas i `settings.aimLine`. `always` finns bara som konfig för test.

## 13. Meta-lager v1.1 (beslut 2026-09-25, källa: research/meta-layer-research.md)
Mål: "mer att komma tillbaka till" utan timers, streaks, notiser, dubbletter eller köp. Slumpen avgör bara *vad*, aldrig *om* eller *när*. Upplåsningar ger aldrig poäng.

### 13.1 Kedjan i HUD
- 11 små siluetter i en rad under poängen. Nivåer som skapats i rundan tänds (fylld, egen färg). Nivåer som aldrig skapats i något spel visas som mörk siluett med "?". Övriga: mörk siluett utan "?".
- Tänds med scale-punch 0,3 och ett kort pling när ny nivå skapas i rundan. Ingen text.

### 13.2 Samlarbok
- En sida per temaset (v1.1: 5 sidor). **21 platser per sida: 11 vanliga + 10 skimrande (nivå 1–10).** Nivå 0 skapas aldrig genom merge och kan därför inte bli skimrande. Nivå 0 vanlig är ifylld från start på varje sida (endowed progress). "Full sida" = 21/21.
- **Fångst**: en Glimt fångas när nivån *skapas* genom merge (eller regnbåge) i det aktiva setet. Drop från kön räknas inte.
- **Skimrande**: avgörs med seedad RNG vid skapande. Ren kosmetik: glittrande ring runt objektet + egen ton (kvint upp), inga poäng. Sannolikhet per nivå i `data/collection.ts`: nivå 0–4: 1/60, 5–6: 1/30, 7–8: 1/12, 9–10: 1/5. **Garanti**: räknare per nivå, garanterad skimrande efter 3/p skapade utan träff. Första skimrande garanteras senast i runda 3 på nivå ≥2.
- Tolkningar (bekräftade 2026-09-25): pity slår till på den 3/p:e skapade i rad utan träff; ett skimrande objekt fyller även den vanliga platsen; nivå 0 i kedjan är tänd från rundans start; drop från kön tänder inte kedjan.
- Boken öppnas från hyllan på startskärmen. Bläddring mellan sidor med svep. Låsta platser syns som siluetter med alpha 0,25. Ingen text utöver siffror.
- Sparformat: `collection: { [setId]: { caught: number[11 bitmask eller boolean[]], shiny: boolean[11] } }`, `stats.createdPerLevel: number[11]`, `stats.shinyPity: number[11]`.

### 13.3 Temaset
- 5 set: Glimtarna (bas) + 4 nya. Varje set: egen palett per nivå, egen dekorstil, egen klangfärg på merge-ljudet (vågform/filter), egen partikelform, egen bakgrundsdetalj. **Ansikten per nivå är samma i alla set** (färg får inte vara enda informationsbärare). Reglerna ändras aldrig.
- **Upplåsning**, det som kommer först:
  - Tidsspår: ackumulerade merges 200 / 600 / 1 500 / 3 000 (startvärden, mät `merges per runda`).
  - Skicklighetsspår: första nivå 8, första nivå 10, första dubbel-Klunk, första fulla boksida.
- Vilket set som låses upp dras slumpvis bland återstående, inga dubbletter. Stapel mot nästa set visas på startskärmen och i rundavslutet.
- Aktivt set väljs i boken (tryck på sidan). Byte av set byter texturer, ljud och partiklar vid nästa runda.

### 13.4 Rundavslut "nytt!"
- Spelas ovanpå förlustskärmen, aldrig i stället för. Ett tryck var som helst startar om direkt (<0,5 s), och avbryter animationen.
- Sekvens (max 2,5 s totalt): poäng → nyfångade Glimtar flyger en i taget in i en bok-ikon (skimrande med glitter) → sidans mätare (x/22) → stapel mot nästa set → om nytt set: setets ikon med guldringar (`jackpot`-juice, intensitet 0,9).
- Nytt set eller ny skimrande som hoppas över visas i boken nästa gång med en puls (≤1 Hz).

### 13.5 Skjuts till v1.2
Ikonuppdrag, funktionella Glimtar ("Lyktan"). Beslut efter speltest.

### 13.6 Förtydliganden (2026-09-25)
- Kedjan tänds bara av merge/regnbåge. Nivå 0 alltid tänd. Position enligt UI.md §12 (`META.chain`), combo-prickar flyttas till y 97.
- Sparformat utökas: `collection[setId].fresh: boolean[21]` (nytt sedan sist, per plats) och `freshSet: string | null` (nyupplåst set som inte visats i boken).
- Stapeln mot nästa set visar bara tidsspåret (merges). Skicklighetsspåret är en överraskning.
- Nytt set i rundavslutet: `jackpot`-juice utan shake, zoom och hit-stop.
- Frostisarna nivå 0/1 har ΔE 23, speltestas med barn.
- Set: Glimtarna, Planeterna, Frostisarna, Godisarna, Glöden (`app/src/data/themes.ts`).

## 14. Kompisar: avatarer, musslor och uppgradering (v1.2, beslut 2026-09-25)
Källa: research/avatar-box-research.md. Beslut av Anders: ingen garanti på episk och uppåt, uppgraderingsbara avatarer med små förbättringar, fler avatarer, unika förmågor från sällsynt och uppåt, vanlig/ovanlig rent kosmetiska.

### 14.1 Avataren "Släpparen"
Figuren som sitter på burkkanten och håller det hängande objektet. Syns hela rundan. Ritas med Graphics-primitiver per avatar (ingen bildfil). Reagerar på drop/merge/kedja/fara enligt sin egen animationsrecept.

### 14.2 Antal och rariteter (48 st)
| Raritet | Antal | Färg/pärlor | Innehåll |
|---|---|---|---|
| Vanlig | 16 | grå, 1 pärla | ren kosmetik: spår, ljud, små gester |
| Ovanlig | 12 | grön, 2 | ren kosmetik, lite rikare |
| Sällsynt | 9 | blå, 3 | **unik känsloförmåga** (ändrar juice/ljud/bakgrund, aldrig poäng) |
| Episk | 6 | lila, 4 | **unik informationsförmåga** (visar något spelaren annars måste se själv) |
| Legendarisk | 3 | guld, 5 | **unik mild spelförmåga** (en gång per runda eller små parametrar) |
| Mytisk | 2 | regnbåge, 6 | unik förmåga + spektakel |
Aldrig rött (rött = fara). Vanlig/ovanlig namnges och ritas av UI-designern med fritt tema (havsdjur och vänner). Sällsynt och uppåt enligt 14.5.

### 14.3 Musslor (lådor)
- **Intjäning**: mussla nummer k vid `50·k^1,3` ackumulerade merges (samma räknare som temaseten) + sex överraskningsmusslor för skicklighet: första nivå 7, 8, 9, 10, första dubbel-Klunk, första skimrande. Ingen timer, ingen valuta, inga köp, inga annonser.
- **Odds per raritet**: vanlig 44 %, ovanlig 28 %, sällsynt 16 %, episk 8 %, legendarisk 3 %, mytisk 1 %. Omnormeras bland rariteter som har figurer kvar. Inom rariteten dras jämnt. **Inga dubbletter**: poolen är ändlig, 48 musslor ger alla 48. **Ingen garanti (pity) för episk och uppåt.** Första musslan är alltid sällsynt (onboarding: spelaren ser att förmågor finns).
- **Öppning**: musslan flyger till hyllan i rundavslutet (omstart <0,5 s). Öppnas med ett tryck på startskärmen, fast tid 1,2 s, visar direkt figur, raritetsfärg och pärlor, figuren visar sin förmåga en gång. Jackpot-juice utan shake/zoom, max 0,9 för mytisk. Ett tryck hoppar över. Ingen rullning, ingen stegvis uppgradering, aldrig "nästan". Oöppnade musslor ligger på hyllan, utan siffra, puls ≤1 Hz, öppnas en i taget. Ingen "öppna alla".
- **Odds utan text**: i fliken Kompisar en glasburk med 25 pärlor i raritetsfärgerna i proportion till aktuella odds.

### 14.4 Uppgradering
- Tre nivåer: I, II, III. XP = merges gjorda medan avataren är vald. Nivå II vid 150 XP, nivå III vid 450 XP (kumulativt). Ingen valuta, inga dubbletter.
- Effekt per nivå: kosmetik blir rikare (fler partiklar, längre spår), förmågor får **små** parametersteg definierade per avatar i data (t.ex. Lyktan: 6 s → 8 s → 10 s). Aldrig mer än ~+30 % på förmågans parameter mellan I och III.
- Visas som pärlor under avataren i boken och en liten romb på Släpparen.

### 14.5 Förmågor (sällsynt och uppåt)
**Sällsynt (känsla, 9):** Åskmolnet Muller (större skak och blixtar vid kedja, inom Lugnt läge-tak), Dirigenten Maestro (combon spelar en melodi), Tidsugglan Tick (egen slow-mo-stil vid fara), Fyrverkeri-Fia (egen fanfar vid rekord), Vulkanen Vulle (lava och bas vid merge nivå ≥8), Discokulan Disco (bakgrund pulserar med combon, flash-guard), Ekot Eko (katedraleko på merge), Kameran Klick (polaroid av största kedjan i rundavslutet), Norrsken-Nora (norrsken över burken vid kedja ≥3).
**Episk (information, 6):** Lykt-Lisa (medan man siktar lyser objekt av samma nivå svagt, 6/8/10 s), Spådamen Siri (ser två steg fram i kön), Sikt-Sixten (siktlinjen slutar i en landningsprick), Bubblan Bubbel (första 10/12/15 dropen studsar inte), Ekolodet Ekko (när ny nivå tänds blinkar alla av den nivån, ≤1 Hz), Kikaren Kajsa (near-miss visas från nivå ≥6/5/4).
**Legendarisk (mild spel, 3):** Magnet-Maja (1/1/2 gånger per runda dras två lika inom 40 px ihop), Regnbågs-Rut (rundan börjar med en regnbåge i kön; III: även en bomb), Andrums-Vala (1/2/2 gånger per runda: farogräns 2,5 s i stället för 1,5).
**Mytisk (2):** Havsdrottningen (guldburk, orkester-klang, en regnbåge i varje runda + I/II/III: 1/1/2 extra specialobjekt), Stjärnvalen (stjärnhimmel, glödande objekt, dubbel/2,5×/3× chans på skimrande).

### 14.6 Highscore och regler
- Regeln "upplåsningar ger aldrig poäng" ändras till: **ger aldrig poäng direkt**. Förmågor är små (uppskattning <5 % på poäng) och ett enda rekord behålls. Avataren som satte rekordet visas vid rekordet på hyllan.
- Avatar väljs i fliken Kompisar i boken. Byte gäller från nästa runda.

### 14.7 Sparformat
`avatars: { owned: string[], level: Record<id, 1|2|3>, xp: Record<id, number>, equipped: string, boxesEarned: number, boxesOpened: number, pendingBoxes: number }`, `stats.merges` återanvänds för intjäning. `highscoreAvatar: string`.

### 14.8 Förtydliganden (2026-09-25)
- Uppgraderingsnivå visas med romber (0–2), pärlor betyder bara raritet.
- Ingen startkompis; objektet hänger som förut tills första musslan (alltid sällsynt), som väljs automatiskt. Senare öppnade väljs inte automatiskt.
- Lykt-Lisa: parametern är antal sekunders siktning per runda som lyktan räcker.
- Rundavslut med mussla + nytt set + många fångster: flygarna körs i snabbläge så budgeten 2,5 s håller.
- Data: `app/src/data/avatars.ts` (ersätter stubben), spec UI.md §13.

## 15. Språk (beslut 2026-09-25)
- **Engelska är primärspråk** för allt en spelare eller butik kan se. **Svenska är lokalisering.**
- UI:t förblir textfritt. Namn på avatarer, set och förmågor lagras som `{ en, sv }` i data och visas bara där text införs senare (bok, öppning, butik).
- Appnamn: KLUNK (samma på båda språk). `index.html` lang="en".
- Butikstext (Play/App Store) skrivs på engelska med svensk översättning i `docs/store/`.
- ~~Enkel `i18n`-modul väljer språk från enhetens språk.~~ **Ändrat 2026-09-26 (Anders): spelet är alltid på engelska som standard, oavsett enhetens språk. Svenska bara som eget val i inställningarna (`settings.lang`).**

## 16. Ekonomi: pärlor, stjärnsand, musslor i butik (v1.3, beslut 2026-09-25)
Källa: research/economy-research.md §5. Ersätter §14.3 (intjäning) och §14.4 (XP). Inga köp för riktiga pengar, inga annonser, ingen timer, inga dubbletter, odds synliga, ingen spelautomat-estetik. Reservflagga `SHOP.mode: 'random' | 'pick3'` (välj 1 av 3 synliga) om regelverk kräver.

### 16.1 Resurser
- **Pärlor**: 1 per merge. Visas i rundavslutet (räknas upp ≤0,6 s) och i boken.
- **Stjärnsand**: +1 per skimrande, +1 per kedja ≥3 (max 3/runda), +2 per nivå 10, engångs +3 för första nivå 7, 8, 9, 10, första skimrande, första dubbel-Klunk (ersätter skicklighetsmusslorna), +10 per full boksida.
- Konfig i `data/economy.ts`. Sparformat: `economy: { pearls, sand, mergesBaseline, freeShellsClaimed, milestones: string[] }`.

### 16.2 Musslor
| Typ | Pris | Raritetsgolv | Odds vanlig/ovanlig/sällsynt/episk/legendarisk/mytisk |
|---|---|---|---|
| Vanlig | 300 pärlor | vanlig | 50 / 30 / 13 / 5 / 1,5 / 0,5 |
| Silver | 700 pärlor | ovanlig | – / 50 / 30 / 14 / 4,5 / 1,5 |
| Guld | 50 stjärnsand | sällsynt | – / – / 50 / 32 / 13 / 5 |
| Gratis (vanlig) | vid 120 och 400 merges räknat från `mergesBaseline`, sedan var 750:e | vanlig | som vanlig |
- Odds omnormeras bland rariteter ≥ golvet som har figurer kvar. Inga dubbletter. Ingen pity. Första musslan i spelarens liv är alltid sällsynt.
- Silver/guld visas grå med bock när inget finns kvar över golvet.
- **Ingen retroaktiv utbetalning**: vid migrering sätts `mergesBaseline = stats.merges`, befintliga kompisar och oöppnade musslor behålls, pärlor/sand startar på 0.
- När alla 48 ägs: gratismusslan ger 10 stjärnsand; butiken visar "full bok". Inga nya sinks.
- Köpta musslor öppnas direkt i butiken med samma öppningsceremoni (1,2 s, tryck hoppar över).

### 16.3 Uppgradering (ersätter XP)
| Raritet | I→II | II→III |
|---|---|---|
| Vanlig | 80 pärlor | 200 pärlor + 4 sand |
| Ovanlig | 100 | 250 + 6 |
| Sällsynt | 150 | 400 + 10 |
| Episk | 200 | 550 + 15 |
| Legendarisk | 250 | 700 + 20 |
| Mytisk | 300 | 800 + 24 |
- Knapp under kompisen i boken med pris; grå när det inte räcker. Effekterna per nivå oförändrade (§14.5).
- `avatars.xp` tas bort ur sparformatet (migrering: befintliga nivåer behålls).

### 16.4 Boken
- Fliken Kompisar får en **butikshylla** högst upp: tre musslor med pris och en liten oddsburk var (25 pärlor), resursräknare för pärlor och sand.
- Vald kompis: **förmågetext** ≤60 tecken per språk (EN/SV via i18n), för alla 48 (kosmetik beskrivs också, kort). **Uppgraderingsstapel** i tre segment med värdet per nivå där det finns en parameter, annars bara segment.
- Oddsburken per mussla ersätter den gamla gemensamma burken.

### 16.5 Förtydliganden (2026-09-25)
- UI-data i `data/economyUi.ts`. Resursräknare i överkanten på startskärmen (y 30), inte på hyllan.
- pick3-erbjudandet sparas i `economy.pick3Offer[type]` så det inte kan dras om.
- Rundavslut: snabbläge för flygare när det finns sand och ≥5 flygare.
- Mini-oddsburk: minst en pärla per raritet som finns kvar, även om det överdriver mytisk. Raritetsmarkeringen kallas "stjärnor" om den någonsin behöver benämnas i text; "pärlor" är valutan.
- **Schemaversion**: `save.schema = 2`. Sparfiler med lägre/saknad version raderas helt en gång (beslut Anders: nystart för testversion 7). Därefter migreras normalt.

## 17. Art v2 (beslut 2026-09-25, spec UI.md §15)
- Canvas2D-bakning med material (basgradient, inre skugga, kantljus, spegling, kontaktskugga, mjuk drop shadow, inset-ansikten). Samma ritrecept och former som förut.
- **Spelet ritar i skärmens upplösning med tak 2×** (bredd/höjd × Z, kamerazoom Z, pointer.worldX, setResolution på text). Texturer bakas i Z.
- Aktivt set bakas vid start, övriga vid behov. Budget: max 2 set i full upplösning (≤ ~11 MB vid 2×). `mode: 'v1'` som fallback för svaga enheter.
- Bomb, regnbåge, pärlor, romber, musslor och partiklar får v2 i steg två. Glöd som gemensam sprite: backlog.

## 18. Start v2 (beslut 2026-09-26, spec UI.md §16, duk https://claude.ai/artifact/3bdoh7692uJDrXsGBk9cD1)
- Förslag A: resurspiller + kugghjul, hjälte med kompis och rekord, bred SPELA-knapp, tre kort (Bok, Kompisar, Butik), set-stapel med låst nästa set. Inställningar i bottenark.
- **Korta etiketter** på knappar (≤10 tecken, ≥14 px, EN/SV). Principen "ingen text" gäller inte längre för navigering.
- Typsnitt Fredoka (OFL), buntat i `app/public/fonts/`.
- Kortkant #4A6194 (3,1:1 mot bakgrund) i stället för dukens #2B3B5E.
- Butik-badge **bara** när en gratismussla väntar, aldrig för "har råd".
- Nästa sets siluett är en generisk okänd Glimt med lås (setet lottas först vid upplåsning).
- Hjälten är en leksak: tryck ger kompisens uppvisning.
- Mått skalade till 360×640 (SPELA 268×88, kort 101×104).

## 19. Return lanes and rating (decision 2026-09-26, producer)
- Anders asked for lanes that bring players back often. Daily return rewards put the game at **PEGI 7** (with the "play by appointment"-type descriptor) under the June 2026 criteria. The target audience is 7+, so PEGI 7 is accepted. **Penalties for absence (PEGI 12) remain forbidden.**
- Daily lanes ship together in one release so the rating and store text change once. Store text is updated from PEGI 3 assumptions to PEGI 7.
- No notifications in v1.
- Source: `docs/research/retention-lanes.md`, safety patterns: `docs/reviews/2026-09-26-baseline.md`.

## 21. Audio decisions (2026-09-26, producer; source docs/AUDIO.md)
- §5 combo pitch rule changes to the **pentatonic ladder capped at combo 7, then "sparkle"** as proposed in AUDIO.md §2 (musical, never shrill, no endless climb).
- Shell reveals get **richer, not louder**: loudness equal across rarities (±1 LU), rarity shown by timbre and layers. Needs child-safety sign-off with the audio batch.
- Adaptive generative music: **on by default at low level**, separate Music toggle in the settings sheet, ducks under big moments, off in calm mode's quiet variant only if the player turns it off. Generative from rules, no stored melodies (legal check with the batch).
- Master bus with working limiter, voice cap, one AudioContext (disable Phaser's), suspend on background.

## 20. Retention lanes v1 (proposal 2026-09-26, game-designer; spec in `docs/RETENTION.md`)
Status: **proposed**. Waiting for simulation (balance-analyst, RETENTION §6), child-safety gate and legal gate (all new names pending legal). Producer decides and logs the decision here.
- **Nine lanes:** N1 Daily Jar, N2 Pearl Pool (inside the Aquarium; renamed from Tide Pool, legal LG9), N3 Daily Present, N4 Journey, N5 Trophies (40, 8 hidden), N6 Set mastery (3 stars × 5 sets), N7 Missions (3 slots, 26 in the pool, never expire), N8 Aquarium, N9 Good place to stop (= CS4). All numbers are in RETENTION §3 and go to new data files (RETENTION §8.1).
- **Differences from the brief, set by the baseline review's PASS rows:** the present banks to **7**, not 3, and has deterministic content. The pool is capped at **40 pearls over 24 h** (≤ 1 round). Past Daily Jars stay playable, with the same one-time reward. No stamp-count rewards. The daily lane is called "Present" so it is not confused with the "Gift!" free shell (CS5).
- **Economy guards:** XP comes only from merges. No lane grants shells, random items or new sinks. The legacy sand milestones move into trophies and are paid once. Target: daily lanes ≤ 35 % of rewards for every profile, and return-only value per day below one round of play (inv. 3).
- **Proposed change to §16.2:** first free shell at **90** merges (was 120), as the CS6 "choose 1 of 3" gift. Pending simulation.
- **Release plan:** Batch A (CS1–7, N9, N4, N5, N6, N7) first, with no rating change. Then Batch B (N8+N2, N3, N1) as one release with PEGI 7 and a listing update (§19, inv. 10).
- **Save schema 3**, migrated from 2 without wiping and without retroactive currency (RETENTION §8.2).
- **Weekly cadence:** none on purpose. The 5-set Daily Jar rotation gives the rhythm without event rewards.

## 22. Release decisions (2026-09-26, producer; source docs/RELEASE.md)
- Phaser pre/post FX disabled (unused): ~60 % less texture memory at DPR 2.
- Only this branch publishes the rolling `test-latest` release.
- `package.json` minor = test version (0.8.x now; 0.9.0 for test version 9).
- APK growth of ~0.85 MB for own icon/splash accepted. Art director signs off icon/splash in the art batch.
- `android:allowBackup` stays on so a child's save survives a phone change; store text drops "only" (LG6).
- **In-round pickup feedback and round summary (Anders, via producer; RETENTION §10):**
  - In the round, one pearl token per merge burst (≤2/s) and one sand token per sand event fly to a compact "this round" pouch between the score and the preview.
  - Level-up, mission, trophy and mastery-star toasts sit **below the jar floor**, one at a time, ≥3 s apart. Everything else waits for the summary.
  - The round summary replaces the §13.4/§16 round-end with 7 grouped rows: result, Daily, pearls and sand, Glimmers and sets, buddies, Journey, missions, trophies and mastery. Empty rows are hidden and the stop moment comes last. Buttons are Home and Replay.
  - Timing: typical ≈2.5 s, hard cap 3.5 s. Everything is granted and saved at t = 0. A tap restarts in <0.5 s, and anything skipped becomes a fresh marker.
  - No "collect all" button: collection is automatic, so the button would only add friction.
- **Reviews applied (2026-09-26):**
  - Child-safety review `reviews/2026-09-26-retention.md` (PASS WITH CHANGES): R1–R18 are folded into RETENTION.md and marked "applied (Rn)".
  - Batch B is gated on a simulated casual-profile check: T8 ≤ 35 % and T9 ≤ 0.8 at 4/7 and 7/7 days played (R12).
  - Legal renames: Pearl Pool / Pärlpölen, never "Journey Pass", Captain Anchor / Kapten Ankare, The Snowglows / Isbitarna, Vera the Seer / Spådamen Vera, Figgy the Frog (RETENTION §9).

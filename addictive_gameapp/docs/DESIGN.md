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
1. **Start**: logotyp, stor "spela"-ikon (▶), hylla med bästa objekt + highscore, tre små ikoner: ljud, haptik, lugnt läge. Ingen text utöver logotypen.
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

# PLAYTEST.md – speltest hemma (P5.1)

Version 1.0 · 2026-09-25 · Gäller testversion 5 (DESIGN §1–14). Mätpunkterna kommer från research/urgency-research.md §5, meta-layer-research.md §7 och avatar-box-research.md §7.

**Upplägg:** 2–4 barn (7–10 år) och 2–3 vuxna. En person i taget, 15–20 min spel och 5 min frågor.

## 1. Förberedelser

- **Enhet:** helst samma Android-telefon för alla, med APK från `test-latest`. Webbversionen fungerar som reserv. Batteri över 50 %, Stör ej på och ljudet på halv volym. Ljud och haptik på, Lugnt läge av.
- **Färsk sparfil före varje person:**
  - *Android:* gå till Inställningar → Appar → KLUNK → Lagring → **Rensa data**. Avinstallera inte appen. Den har `allowBackup="true"`, så Androids backup kan läsa tillbaka gammal data vid ny installation.
  - *Webb:* öppna ett nytt privat fönster per person och stäng alla privata fönster mellan personerna. Med devtools går det också att köra `localStorage.removeItem('klunk.save.v1')`.
  - *Kontroll:* hyllan ska vara tom, highscore 0 och ingen kompis ska sitta på burkkanten.
- **Ordning:** låt barnen spela innan de sett någon annan spela. Övriga väntar i ett annat rum.
- **Samtycke:** fråga föräldern till varje barn, även dina egna. Barnet ska dessutom själv säga ja och veta att hen får sluta när som helst utan att förklara varför. Använd koder (B1, B2, V1), aldrig namn. Filma bara händer och skärm, och radera filmen efter sammanställningen. Spelet skickar inget över nätet.
- **Testledarens regler:** förklara aldrig spelet. Säg bara: *"Jag vill se hur spelet funkar. Det är spelet som testas, inte du."*
  - Om barnet frågar något, svara *"Vad tror du?"* och vänta.
  - Hjälp först när barnet suttit fast i 60 s, och notera att du hjälpte.
  - Undvik ledande frågor som "Visst var det kul?" eller "Såg du boken?".
  - Säg "tack", inte "bra!".

## 2. Session per person (15–20 min)

| Tid | Vad |
|---|---|
| 0:00 | Lämna över telefonen med startskärmen framme och starta klockan. |
| 0–12 min | Fri spelning utan instruktioner. |
| 12 min | *Om debugpanelen finns (§3):* ge Lykt-Lisa utan att säga något. |
| 12–18 min | Fri spelning. |
| senast 20 min | Avsluta när pågående runda tar slut. Starta aldrig en ny runda åt personen. |

**Minutprotokoll:** kryssa i rutan om beteendet förekommer någon gång under minuten.

| Min | Ler/skrattar | Frustration (suck, "orättvist", slår) | Tittar bort >3 s | Säger "en gång till" | Frågar vad något är (skriv vad) |
|---|---|---|---|---|---|
| 1 | ☐ | ☐ | ☐ | ☐ | |
| 2 | ☐ | ☐ | ☐ | ☐ | |
| … | | | | | |
| 20 | ☐ | ☐ | ☐ | ☐ | |

**Engångshändelser:** skriv tiden (mm:ss) eller "nej".

- ☐ Förstår merge utan hjälp inom 10 s. Det räknas när personen gör en merge och sedan medvetet siktar mot en likadan (flyttar och väntar).
- ☐ Hittar boken själv via hyllan: ____
- ☐ Hittar fliken Kompisar själv: ____
- ☐ Förstår musslan. Det räknas när personen trycker på den utan hjälp och efteråt kan peka ut sin kompis: ____
- ☐ Byter kompis själv: ____
- ☐ Säger "den föll själv" eller "jag var inte klar". Antal: ____ Tider: ____
- ☐ Reagerar på ett skimrande objekt (pekar eller säger något): ____

## 3. Automatisk mätning

`window.__game` finns bara i dev-läge eller med `?test=1`, alltså **inte i APK:n**. Den ger dessutom bara värden för pågående runda. Beställning till programmeraren (föreslaget ID P5.1a, cirka 2–3 h, uppskattning):

- Ett **långtryck i 2 s på logotypen** öppnar en debugpanel som barn inte hittar av en slump. Panelen har fyra knappar:
  - **Kopiera JSON** till urklipp (Capacitor Clipboard eller `navigator.clipboard`).
  - **Nollställ sparfil.**
  - **Ge Lykt-Lisa I.** Samma väg som `equipForTest`.
  - **Auto-drop av/på**, för A/B med vuxna.
- En **rundlogg** sparas lokalt som en ringbuffer med högst 200 rundor. Inget skickas över nätet.
  - *Per runda:* `startMs`, `durationMs`, `drops`, `autoDrops`, `dropLatencies` med regissörens läge per drop, `merges`, `score`, `maxLevel`, `firstMergeMs`, `restartMs` (tid från förlustskärm till tryck), `newCaught`, `shinyCreated`, `boxesEarned`, `activeSet`, `equipped`, `calm`, `pacingMode`.
  - *Per session:* `firstBoxEarnedMs`, `firstBoxOpenedMs`, `firstBookOpenMs`, `firstFriendsTabMs`.

Efter varje person: kopiera, klistra in i en anteckning och spara som `B1.json` osv.

**Nyckeltal:**

| Mått | Beräkning | Mål / tolkning | Källa |
|---|---|---|---|
| Andel auto-drop | autoDrops / drops | **<10 % vuxna, <20 % barn**. Över 30 % betyder att tiden är för kort. | urgency §5 |
| Droplatens P50/P90 | per läge (Flöde/Torka) | Ingen målsiffra. Används för att bedöma rampen. | urgency §5 |
| Drops/min | per läge | Ska stiga i Flöde men inte i Torka. Stiger den i båda läcker auto-drop. | urgency §5 |
| Rundlängd | sekunder och drops | Ingen målsiffra. Färre sekunder med lika många drops är önskat. | urgency §5 |
| Återstart inom 3 s | andel förlustskärmar | Ingen absolut siffra. Ska inte sjunka mellan versioner. | urgency §5 |
| Tid till första merge | `firstMergeMs`, runda 1 | **<10 s** | DESIGN §4 |
| Merges per runda | median | Researchen antog cirka 60 (uppskattning). Kalibrerar set och musslor. | meta §7 |
| Tid till första mussla | intjänad och öppnad | Kort tid plus tjat är en varning. En ignorerad mussla betyder lågt värde. | avatar §7 |
| Första skimrande | rundnummer | Senast runda 3 | DESIGN §13.2 |
| "Den föll själv" | antal barn | **Fler än 1 av 4 barn** betyder att auto-drop ska stängas av. | urgency §5 |

**A/B med vuxna (valfritt):** spela 2 rundor med auto-drop av och 2 med auto-drop på, i slumpad ordning.

## 4. Frågor efteråt

Låt barnet peka på skärmen. Upprepa barnets ord i stället för att tolka dem.

1. **"Vad var det roligaste som hände?"** Följ upp med *"Visa mig."*
2. **"Vad var tråkigast eller jobbigast?"**
3. **"Om du fick välja vilken kompis som helst, vilken skulle det vara? Varför den?"** Öppna boken och låt barnet peka.
4. **"Vad gör Lyktan?"** Ställ bara frågan om Lisa har varit med. Annars: *"Vad gör din kompis?"*
5. **"Om du fick spela imorgon, hur gärna skulle du vilja?"** Visa tre ritade ansikten (inte alls / kanske / jättegärna). Barnet pekar och säger varför.

Fråga 5 är ett Again-Again-mått. Väg ihop svaret med observationen: 7–9-åringar ger ofta allt samma, höga betyg ([Read & MacFarlane 2006](https://dl.acm.org/doi/10.1145/1139073.1139096)).

- **Extra för barn:** *"Vad tror du bestämmer vad som finns i musslan?"* och *"Visa vilken pärla i burken som är mest sällsynt."*
- **Extra för vuxna:** *"Vad, om något, påminde om spel om pengar?"* och *"Vad kändes orättvist?"*

## 5. Avbrytskriterier och etik

- **Pausa** vid gråt eller om barnet slår på telefonen eller säger "jag vill inte". Pausa också om frustration kryssats två minuter i rad. Fråga om barnet vill fortsätta och försök aldrig övertala.
- **Om auto-drop ger frustration** (barnet säger "jag var inte klar" två gånger): slå av auto-drop i debugpanelen och notera det. Använd inte Lugnt läge, eftersom det även ändrar juice.
- **Max 20 min speltid** och en session per person och dag.
- **Inga belöningar** kopplade till speltid, poäng eller antal rundor. Om ni tackar med något får alla samma sak oavsett insats. Ingen tävling mellan syskon, och visa aldrig någon annans highscore.
- **Data:** bara koder, minsta möjliga, radera efter sammanställningen. Ingen juridisk bedömning är gjord.

## 6. Sammanställning

**Per person:**

| ID | Ålder | Enhet | Rundor | Median längd (s/drops) | Auto-drop % | P50/P90 Flöde | Drops/min F/T | Återstart ≤3 s | 1:a merge (s) | Mussla intj./öppn. | Bok själv | Mussla förstådd | "Föll själv" | Min ler / frustr. / bort | Again |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| B1 | | | | | | | | | | | | | | | |
| V1 | | | | | | | | | | | | | | | |

**Beslutspunkter.** Tabellen är underlag. Teamet beslutar.

| Om | Fil | Parameter att pröva |
|---|---|---|
| Auto-drop över 30 %, eller fler än 1 av 4 barn säger "föll själv" | `data/pacing.ts` | Höj `rampStartMs` (t.ex. 8000) och `rampEndMs`, eller sätt `mode: 'off'`. Att behålla bara vickningen kräver ett nytt läge i koden. |
| Första merge över 10 s hos fler än hälften | `data/director.ts` | Höj `openingFlowDrops` och `flow.preferMergeableP`. |
| Frustration i långa torrperioder, eller drops/min faller i Torka | `data/director.ts` | Sänk `drought.max` och `drought.avoidMergeableP`. |
| Specialobjekt märks inte eller känns för vanliga | `data/director.ts` | `kickEvery` |
| Merges per runda avviker mycket från 60 | `data/boxes.ts`, `data/unlocks.ts` | `base`, `exp`, `mergeThresholds` |
| Musslan ignoreras, eller barnet tjatar om nästa | `data/boxes.ts` | `base`, `exp` |
| Ingen skimrande före runda 3, eller ingen reaktion på skimrande | `data/collection.ts` | `firstShinyByRun`, `shinyP` |
| Lyktan förstås inte | `data/abilities.ts`, `data/avatars.ts` | Lisa-effektens tydlighet (se även backlog U6) |
| Frostisarna nivå 0/1 förväxlas | `data/themes.ts` | Palett (DESIGN §13.6) |

**Osäkerheter:** 2–4 barn räcker för att hitta tydliga problem men inte för att fastställa procentsatser. Siffrorna är riktvärden. Gränserna 10/20/30 % och 60 merges per runda är uppskattningar från researchen, inte uppmätta värden.

# Urgency i KLUNK – behövs tidspress?

game-researcher · 2026-09-20 · Underlag för beslut, inte ett beslut.
Fråga från Anders: *"Behöver vi inte någon sorts urgency, att nästa boll faller efter ett visst antal sekunder?"*
Konflikt att lösa: DESIGN.md §9 och research §5.1 säger "ingen tidspress i UI:t" (barn 7+).

> **Källbegränsning:** WebFetch var blockerad av containerns egress-proxy under hela arbetet. Allt nedan bygger på sökmotorns sammanfattningar av källorna plus länkarna. Fulltext för de två flow-studierna har **inte** kunnat verifieras av mig. Behandla citat som andrahandsuppgifter tills någon öppnar PDF:erna.

---

## 1. TL;DR

1. **Flow kräver inte tidspress.** Csikszentmihalyis nio komponenter innehåller tydliga mål, omedelbar feedback och balans utmaning/skicklighet – **inte** en klocka. KLUNK har redan alla tre. Tidspress är ett *sätt* att höja utmaningen, inte ett krav.
2. **Däremot: konstant balans är inte optimalt.** Baumann, Lürig & Engeser (2016) fann att *dynamiskt* varierande krav gav mer flow och mer njutning än konstant skill–demand-balans. Det talar för att Anders känsla är rätt – men att lösningen är **variation i tempo**, inte en fast nedräkning. Regissören är redan byggd för exakt det.
3. **De bästa jämförelseobjekten löser urgency per *handling*, inte per *sekund*.** Drop7 har inget tidslimit alls men skjuter upp en ny rad efter N drag. Suika har ingen timer – trycket är att burken fylls. Tetris/Puyo använder gravitation, men det är arv från arkadmyntslogik, och Tetris NES:s egen "kill screen" (nivå 29) visar exakt var tidspress slutar skapa flow och börjar skapa avhopp.
4. **För barn är evidensen om tidspress svagare i spel än i skola – men entydig i skola.** Jag hittade ingen studie på tidspress i spel för 7–10-åringar. Det finns däremot etablerad forskning på att tidspress i skoluppgifter blockerar arbetsminne och skapar ångest (Boaler m.fl.), och NN/g:s barn-UX visar att 6–8-åringar har låg tolerans för allt som blockerar dem. **Det gör en hård, oundviklig timer olämplig; det förbjuder inte en mjuk knuff.**
5. **Regelverket förbjuder inget här.** ACM:s böter mot Epic och CMA:s riktlinjer gäller *kommersiell* tidspress (nedräkning i butik, köp), inte speltempo. Google Play Families reglerar integritet, annonser och monetisering – jag hittade ingen regel om speltempo. Risken är alltså **upplevelse, inte compliance**.

---

## 2. Rekommendation (kort)

Bygg **"mjuk auto-drop", aktiv endast i Flöde-läget**, bakom en flagga i `data/`:
otålighetsvickning vid 3,0 s → auto-drop vid 6,0 s → aldrig på specialobjekt, aldrig under fara/slow-mo, aldrig i Torka. Ingen klocka, ingen siffra, inget ljud. Fullständiga parametrar i §5.

---

## 3. Belägg

### 3.1 Flow: vad som faktiskt krävs
Csikszentmihalyis nio komponenter: utmaning/skicklighet i balans, handling och medvetande smälter samman, tydliga mål, otvetydig feedback, koncentration, kontrollkänsla, förlorad självmedvetenhet, förändrad tidsupplevelse, autotelisk upplevelse. En klocka finns inte med. ([Flow theory – översikt, Yu-kai Chou](https://yukaichou.com/gamification-analysis/flow-theory-complete-guide-csikszentmihalyi-optimal-experience/) · [Investigating the "Flow" Experience, PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC7033418/))

**Men** konstant balans är inte optimum. Baumann, Lürig & Engeser (2016) jämförde konstant balans mot två dynamiska pacing-kurvor och fann `balans ≤ dynamisk medel < dynamisk hög` för flow, och `balans ≤ dynamisk hög < dynamisk medel` för njutning. ([Springer](https://link.springer.com/article/10.1007/s11031-016-9549-7) · [PDF, Uni Trier](https://www.uni-trier.de/fileadmin/fb1/prof/PSY/PGA/unterlagen/BaumannL%C3%BCrigEngeser_Flow_MOEM_2016.pdf))

Motvikt som måste nämnas: en förregistrerad studie med AI-styrd svårighet fann **ingen** effekt av svårighet–skicklighetsbalans på engagemang och njutning. ([Royal Society Open Science 2023](https://royalsocietypublishing.org/rsos/article/10/2/220274/91884/Difficulty-skill-balance-does-not-affect)) Fältet är alltså inte avgjort.

### 3.2 När tidspress höjer respektive sänker prestation
Yerkes–Dodson bekräftad för realtidsspel: låg till måttlig fysiologisk arousal ger bäst prestation, därefter kollaps. ([Cortisol, flow och ångest i e-sport, PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC7008303/) · [Arousal and performance, Trends in Cognitive Sciences 2024](https://www.cell.com/trends/cognitive-sciences/fulltext/S1364-6613(24)00078-0))
Tetris NES är den rena illustrationen: hastigheten ökar stegvis och slutar öka vid nivå 29, där bitarna faller 1 cell/frame – i praktiken ospelbart och känt som "kill screen". Utvecklarna byggde in taket för att de bedömde att snabbare vore för snabbt. ([Tom's Hardware](https://www.tomshardware.com/video-games/retro-gaming/tetris-was-finally-beaten-after-34-years-game-kill-screen-pops-up-at-level-157-hypertapping-and-rolling-were-key-techniques) · [Tetris Guideline / speed curve, TetrisWiki](https://tetris.wiki/Tetris_Guideline))

### 3.3 Benchmark: vem har auto-drop och vem har inte

| Spel | Tidspress i kärnloopen | Anmärkning |
|---|---|---|
| **Suika Game** | **Nej.** Ingen timer. Trycket = burken fylls | Timer/Attack-lägen kom först som betald DLC 2024, som *separata* lägen ([Wikipedia](https://en.wikipedia.org/wiki/Suika_Game)) |
| **Drop7** | **Nej, ingen klocka.** Ny rad trycks upp efter N drag | Urgency **per handling**, inte per sekund. Snabbläge är ett eget läge ([Wikipedia](https://en.wikipedia.org/wiki/Drop7) · [ihobo: volatilitet i pusselspel](https://blog.ihobo.com/2011/10/drop7-and-volatility-in-puzzle-games/)) |
| **Tetris** | **Ja** (gravitation + lock delay 0,5 s) | Tempot stiger med nivå; lock delay ger alltid en sista chans ([TetrisWiki](https://tetris.wiki/Marathon)) |
| **Puyo Puyo** | **Ja** (auto-drop) + "margin time" som krymper målpoängen efter ~96 s | Margin time infördes för att matcher inte skulle bli för långa – ett **matchlängdsverktyg**, inte ett flow-verktyg ([Puyo Nexus: Margin time](https://puyonexus.com/wiki/Margin_time)) |
| **Stack (Ketchapp)** | **Ja**, blocket rör sig av sig självt; tempot ökar ca var 15–20 poäng | Men det är ett *timing*-spel – rörelsen ÄR utmaningen ([Level Winner](https://www.levelwinner.com/stack-ketchapp-tips-tricks-cheats-to-get-a-high-score/)) |
| **2048** | Nej | Ren turbaserad |
| **My Suika (mobil)** | **Valbart**: Classic = eget tempo, Speed = automatiskt snabba drops. Speed låses upp först vid 3000 p i Classic | Starkaste enskilda belägget för min rekommendation: urgency som **upplåst, valfritt** läge ([App Store](https://apps.apple.com/us/app/my-suika-kyos-fruit-merge/id6470134069)) |

**Mönster:** inget högretentionsspel i merge/stack-familjen använder en synlig nedräkning som grundinställning. De som har tidspress har den inbakad i objektets egen rörelse (Tetris, Puyo, Stack) eller som separat läge (My Suika, Suika-DLC). Jag hittade **inga** publicerade A/B-data på vad som hände när ett merge-spel la till eller tog bort auto-drop – den siffran finns inte offentligt.

### 3.4 Barn 7–10
- Ingen studie hittad på tidspress i *spel* för 7–10-åringar. Det är en lucka, inte ett stöd för någondera sidan.
- Närmaste evidens: tidspress i skoluppgifter. Boaler m.fl. kopplar tidsatta prov till matematikångest och pekar på att hastighetspress blockerar arbetsminnet. ([NCTM/Teaching Children Mathematics 2014](https://pubs.nctm.org/view/journals/tcm/20/8/article-p469.xml) · [Stanford GSE](https://ed.stanford.edu/news/boaler-timed-tests-and-development-math-anxiety) · [Hechinger Report](https://hechingerreport.org/opinion-time-stop-clock-math-anxiety-heres-latest-research/)) Överföringen skola→spel är **min tolkning, inte ett etablerat resultat** – i spel saknas betyget och den sociala exponeringen som driver en stor del av ångesten.
- NN/g: barn 6–8 har låg tolerans för allt som blockerar dem och behöver omedelbar tillfredsställelse. ([NN/g: UX Design for Children](https://www.nngroup.com/reports/children-on-the-web/) · [Designing for Kids: Cognitive Considerations](https://www.nngroup.com/articles/kids-cognition/))
- Relevant precedens för *mjuk* knuff: match-3-spel visar ett hint-/vickningsmönster efter ca 5 s inaktivitet – utan att tvinga fram ett drag. Notera att spelare klagar på att 5 s är för kort. ([Candy Crush Hint Moves](https://candycrush.fandom.com/wiki/Hint_Moves) · [King Community: "Hints too fast"](https://community.king.com/en/candy-crush-saga/discussion/509578/hints-too-fast))

### 3.5 Regelverk – gäller inte speltempo
ACM bötfällde Epic 1 125 000 € för bl.a. vilseledande nedräkningstimers i Fortnites **butik** riktad mot barn. ([ACM](https://www.acm.nl/en/publications/acm-imposes-fine-epic-unfair-commercial-practices-aimed-children-fortnite-game)) CMA:s position gäller "urgency claims" i **försäljning**. ([Bird & Bird](https://www.twobirds.com/en/insights/2023/uk/taking-the-pressure-off)) Forbrukerrådet beskriver "temporal dark patterns" som mönster som får användaren att lägga *mer tid* i spelet än hen velat. ([Insert Coin](https://www.forbrukerradet.no/report-on-loot-boxes-insert-coin/))
**Slutsats:** en auto-drop utan pengar, utan siffra och utan att förlänga sessionen mot spelarens vilja ligger utanför det som regleras. Google Play Families reglerar integritet/annonser/monetisering, inte pacing ([Play Console Help](https://support.google.com/googleplay/android-developer/answer/9893335?hl=en)). Formuleringen i DESIGN.md bör därför preciseras från "ingen tidspress" till **"ingen synlig nedräkning och inget tidsbaserat straff"**.

---

## 4. Designalternativ

Kostnader är **uppskattningar** givet nuvarande arkitektur. Not: `FEEL.onboarding.idleMs = 5000` och `showHand()` i `Game.update()` är redan en inaktivitetsdetektor – grunden finns.

| # | Alternativ | Fördel | Nackdel | Kostnad (uppsk.) | Barnrisk |
|---|---|---|---|---|---|
| **a** | Auto-drop efter fast X s inaktivitet + subtil vickning, ingen klocka | Tar bort den analytiska dödpunkten; osynlig för den som spelar snabbt | Straffar den långsamma planeraren lika hårt som den obeslutsamma; kan kännas som tappad kontroll (Crossy Road-lärdomen) | 3–5 h (`data/pacing.ts`, ren timerfunktion + unit-test, tween, e2e) | Medel |
| **b** | **Samma, men bara i Flöde** (regissörsstyrt) | Tempot varierar av sig självt = Baumann-effekten; Torka förblir tankeläge; ingen ny "svårighetsaxel" | Inkonsekvent regel – går att upptäcka; kräver att `director.mode` läses i scenen | a + 1–2 h (`mode` finns redan exponerad i debug-hooken) | Låg |
| **c** | Stigande tempo med poäng/nivå (Tetris-modellen) | Beprövat; höjer skill-taket för vuxna | Kräver en balanserad kurva och flera speltestrundor; bygger in ett garanterat avhoppstak för barn | a + 2–3 h kod, men **flera dagar balansering** | Hög |
| **d** | Bara combo-fönstret (1,2 s) som tidspress – synliggör det | Nästan gratis, `updateComboDots()` finns; ren belöning | Påverkar inte alls den som står still mellan drops – löser inte Anders problem | 2–3 h | Mycket låg |
| **e** | "Hetta": snabba drops ger multiplikator, långsamma ger inget straff | Positiv urgency, formellt inget straff | Ett straff i praktiken (poäng man går miste om); lär barn att slarva; poängsystemet blir svårläst utan text | 4–6 h + balansering | Medel (dolt straff) |
| **f** | Ingen urgency – Suika-linjen | Noll risk, noll kostnad, matchar bevisad förlaga | Löser inte det Anders faktiskt upplevde | 0 h | Ingen |

**Varför Suika (f) fungerar utan timer:** trycket är *rumsligt och monotont stigande* – varje drop gör burken fullare och utrymmet mindre, oåterkalleligt. Spelaren betalar i yta i stället för i sekunder. KLUNK har samma egenskap. Men Suika saknar också det Anders vill ha, och Suikas eget ekosystem har svarat med Speed-lägen (§3.3).

---

## 5. Rekommendation #1: mjuk auto-drop, endast i Flöde

Kombinera **b** (var) med **a** (hur), håll **d** som gratis förstärkning, parkera **c** tills mätdata finns.

**Parametrar (startvärden, ska A/B-testas – alla är uppskattningar):**

| Parameter | Värde | Motiv |
|---|---|---|
| `impatienceMs` | 3000 | Vickning startar. Match-3 använder ~5 s och spelare tycker det är för kort – men där avbryter hinten inget, så KLUNK kan starta tidigare med en svagare signal |
| `autoDropMs` | 6000 | Dubbla otålighetsfönstret = tydlig förvarning innan något händer |
| Vickning | rotation ±4°, 0,8 Hz, **ingen ljusstyrkeändring** | Under flash-guardens 3 Hz; färg/ljus rörs inte alls, så WCAG 2.3.1-testet påverkas inte |
| Läge | auto-drop endast när `director.mode === 'flow'` | Urgency som belöning, aldrig som straff |
| Specialobjekt | **aldrig** auto-drop | Bomb/regnbåge måste få siktas – annars äkta orättvisa |
| Paus av timern | pekaren nere, fara/slow-mo aktiv, hit-stop pågår, `visibilitychange` | Aldrig auto-drop när spelaren redan är stressad |
| Torka | vickning ja (vid 4500 ms), auto-drop nej | Torka ska förbli tankeläge |
| Lugnt läge | auto-drop av, vickning halverad | Konsekvent med `calm`-flaggan |

**Flagga för A/B:** ny fil `app/src/data/pacing.ts` med `PACING = { mode: 'off' | 'flowOnly' | 'always', impatienceMs, autoDropMs, ... }`. Ren data, ingen Phaser, timerlogiken som ren funktion i `systems/` så den kan unit-testas utan rendering – samma mönster som `combo.ts`. Default i repo: `'off'` tills speltestet talat.

**Total kostnad: 4–7 h (uppskattning)**, inklusive unit-test, e2e-test och flagga.

**Vad som ska mätas i speltest** (logga per runda, lokalt, ingen nätverkssändning):

1. **Tid från spawn till drop** – P50 och P90, uppdelat per regissörsläge. Nyckeltalet.
2. **Andel drops som faktiskt auto-droppades.** Mitt förslag på tolkningsgräns (uppskattning): <10 % hos vuxna och <20 % hos barn = fungerar som knuff. >30 % = `autoDropMs` är för kort, höj till 8 s.
3. **Drops/minut** – ska stiga i Flöde utan att stiga i Torka. Gör den det i båda har flaggan läckt.
4. **Rundlängd** i både sekunder och drops. Om sekunderna faller men dropsen är konstanta är det bara komprimerat tempo, inte kortare spel – det är önskat.
5. **Återstartsfrekvens**: andel förlustskärmar som trycks bort inom 3 s ("one more try"). Ska inte försämras.
6. **Merges/minut och poäng/runda** – kontroll att urgency inte sänker kvaliteten på spelet.
7. **Kvalitativt hos barn (7–10):** säger barnet att bollen "föll själv" / "jag var inte klar"? **Avbrytskriterium:** uppträder det i fler än 1 av 4 barntester → stäng av auto-drop och behåll bara vickningen.

Testet ska köras som A/B på samma barn/vuxen i två rundor per läge, seed låst så regissören ger samma kö.

---

## 6. Osäkerheter

- **WebFetch blockerad.** Ingen fulltext lästes; de två flow-studiernas exakta metod är overifierad av mig. Bör kontrolleras innan siffror citeras utåt.
- **Ingen evidens alls** om tidspress i spel för barn 7–10. Överföringen från skolforskning (Boaler) till spel är min tolkning och kan vara fel – i spel saknas betyg och klassrum.
- **Ingen publik A/B-data** på merge-spel som lagt till eller tagit bort auto-drop. Att My Suika gör Speed till ett separat, upplåsbart läge är en indikation på designintention, inte ett bevis på retention.
- **Alla sekundvärden i §5 är startgissningar**, inte härledda ur data. De ska betraktas som något som mäts fram i fas 5, inte som ett beslut.
- **Royal Society-studien motsäger** premissen att svårighetsbalans styr engagemang. Om den har rätt kan hela urgency-frågan vara mindre viktig än både Anders och jag tror.
- Jag har **inte** verifierat Google Play Families-policyns fulltext (egress blockerad); slutsatsen "reglerar inte pacing" bygger på sökträffarnas sammanfattning och bör dubbelkollas inför butikssubmission.

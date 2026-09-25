# R&D: Meta-lager för KLUNK (samlande, upplåsningar, "mer att komma tillbaka till")

Författare: game-researcher · 2026-09-25 · Underlag för v1.1. Utgår från DESIGN.md §5, §9, §11–12, PROPOSAL.md §5 och game-design-research.md §2.5–2.6.

**Metodnot:** WebFetch var blockerad för alla domäner jag provade (apps.apple.com, play.google.com, Voodoos supportsida, gamedeveloper.com, gamigion.com, wikipedia). Allt nedan bygger på sökmotorns sammanfattningar av de länkade sidorna. Det gäller särskilt Paper.io 2, där flera källor är fan- eller SEO-sajter. Uppgifter som bara finns i sekundärkällor är märkta *(sekundär)*.

---

## 1. TL;DR

1. **Paper.io 2:s "dopamin" kommer från tre lager:** en synlig samling med låsta figurer som mörka siluetter, upplåsning via prestation i en enda runda ("ta 50 % av kartan") och nyare *Character Powers*, alltså figurer som faktiskt gör något i spelet. Den tyngsta retentionsmotorn utanför spelet (dagsstreaks, eventfigurer, valuta, annonser) är samtidigt den del vi inte får kopiera.
2. **Mönstret i alla benchmarks:** en synlig samling med tomma platser, *två spår* för upplåsning (skicklighet i en runda plus ackumulerad tid) och kosmetik som ändrar *känslan* (ljud, värld, spår, dödsanimation) oftare än reglerna. Crossy Road visar att det här fungerar helt utan pengar.
3. **Forskningen säger:** synlig delprogress drar (endowed progress 34 % mot 19 %; goal-gradient). Den *förväntade, villkorade* belöningen ("gör X, få Y") kan dock sänka inre motivation, och effekten är starkare hos barn (Deci m.fl. 1999). Överraskningar och milstolpar ger därför bättre stöd än uppdragskontrakt.
4. **Bäst kick × retention per byggdag för KLUNK:** rundavslut med "nytt!" (1–1,5 d), en nivåkedja i HUD med siluetter (0,5–1 d), en samlarbok med skimrande varianter (2–2,5 d) och temaset som låses upp på milstolpar och också låter och sprakar annorlunda (2–3 d).
5. **Ingen timer, ingen streak, ingen notis, inga dubbletter, ingen spelautomatsestetik.** Slumpen avgör *vad* man får, aldrig *om* eller *när*.

## 2. Rekommendation (paket v1.1, cirka 6–8 dagar, uppskattning)

| # | Del | Dagar (uppskattning) |
|---|---|---|
| 1 | **Rundavslut "nytt!"** – nyfångade Glimtar flyger in i en bok-ikon, procentmätare för sidan, stapel mot nästa set | 1–1,5 |
| 2 | **Kedjan i HUD** – 11 små siluetter. Nivåer du skapat i rundan tänds. Nivåer du aldrig nått är mörka "?" | 0,5–1 |
| 3 | **Samlarbok** – en sida per temaset, 11 vanliga + 11 skimrande platser. Hyllan på startskärmen blir en ingång | 2–2,5 |
| 4 | **Temaset med egen känsla** – 4 nya set (totalt 5). Varje set har egen palett, dekor, klangfärg på merge-ljudet och partikelform | 2–3 |

Skjut upp till v1.2 och utvärdera efter speltest: ikonuppdrag (d) och funktionella Glimtar (c). Motivering och siffror finns i §6–7.

---

## 3. Dekonstruktion: Paper.io 2

| Element | Mekanik | Belönar |
|---|---|---|
| Figursamling, "100+ unique skins" enligt butikstexten | Låsta figurer visas som **mörka skuggor** i menyn *(sekundär)* | – (samlingsvisning) |
| Upplåsning i en runda | Ta 10/25/50/80/100 % av kartan i en runda, eller döda 50 spelare i en runda *(sekundär)* | **Skicklighet** |
| Ackumulerad upplåsning | "spela 50 rundor", "täck 500 000 rutor" *(sekundär)* | **Tid** |
| Länder | Yta du tagit räknas mot landet även om du dör. Ett helt land ger bonusar, power-ups och figurer ([Voodoo support](https://paper2-help.freshdesk.com/support/solutions/articles/202000095753-how-do-i-unlock-new-countries-and-progress-)) | Tid plus skicklighet |
| 100 % i ett försök | Du kommer till ett 6 s bonusspel med belöningar (samma källa) | Skicklighet |
| **Character Powers** | Alla figurer utom Classic har en egen kraft: fart, färgexplosion, sköld, större sikt. En cirkel fylls, sedan dubbeltrycker man ([Voodoo support](https://paper2-help.freshdesk.com/support/solutions/articles/202000102996-all-character-powers-listed)) | Funktionell kosmetik |
| Utseende | Figurer byter form, textur och spår (t.ex. lila spår) *(sekundär)* | – |
| Dagsstreak | Figurer för 3 respektive 7 dagar i rad *(sekundär, [guide](https://hub.lifeplan.co.uk/lifeplan-news/unlock-all-skins-in-paper-io-2-the-ultimate-guide-1764804551))* | **Tid/inloggning** |
| Event och valuta | Tidsbegränsade figurer, dagsbonus med mynt och figur-fragment, gems att köpa *(sekundär)* | Tid, **pengar** |
| Annonser | Belöningsvideo för power-up och extraliv *([recensioner](https://appsupports.co/1423046460/paper-io-2/negative-reviews))* | **Annons** |
| Procentmätare och liveranking | Omedelbar, kontinuerlig kvittens på skicklighet i rundan | Skicklighet |

Rundslutsskärmen ("du blev #3") och notiser hittade jag inga källor för. **Ej belagt.**

**Det här kopierar vi INTE (mörka mönster, med källor):**
- **Falsk multiplayer.** Motståndarna är bottar med riktiga användarnamn från en databas, men spelet ser ut som onlinespel ([Tiny Warrior Games](https://tinywarriorgames.com/2019/12/20/creating-a-fake-multiplayer-experience-in-paper-io-2/)).
- **Täta mellanannonser.** En analys räknade cirka 28 per timme *(sekundär, via sammanfattning av [Gamigion](https://www.gamigion.com/1-hour-analysis-paper-io-2-by-voodoo/))*. Recensenter uppger att "Nej" ändå visar en annons.
- **"No ads" tar inte bort alla videor.** Extraliv kräver fortfarande video ([Voodoos FAQ](https://paper2-help.freshdesk.com/support/solutions/articles/202000071538-why-do-i-still-see-videos-after-purchasing-no-ads-)).
- **Köppuffar som barn trycker på.** Föräldrar rapporterar oavsiktliga köp av "Fistful of Gems" ([Bark](https://www.bark.us/app-overview/paper-io-2/)).
- **Dagsstreaks och tidsbegränsade figurer**, alltså FOMO.

## 4. Benchmark i korthet

| Spel | Samling | Hur man låser upp | Gör figuren något? | Pengar/annons |
|---|---|---|---|---|
| **Crossy Road** | Över 100 figurer | Prisautomat för 100 mynt (slump, **dubbletter möjliga**). Hemliga figurer via handlingar, t.ex. hoppa på valen i stället för stocken ([wiki](https://crossyroad.fandom.com/wiki/Prize_Machine), [Pocket Gamer](https://www.pocketgamer.com/crossy-road/unlock-every-mystery-character/)) | Byter **värld, musik och dödsanimation** (sepia och ragtime, disco), sällan regler ([GameSkinny](https://www.gameskinny.com/tips/crossy-road-all-characters-unique-effects/)) | Gåvotimer (var 3:e h efter 7 gåvor), frivilliga köp. Hall ville undvika exploaterande f2p eftersom målgruppen var barn ([Thumbsticks](https://www.thumbsticks.com/crossy-road-how-hipster-whale-reinvented-free-to-play/)) |
| **Subway Surfers** | Karaktärer och brädor | 3 uppdrag per set. Ett klart set ger multiplikator +1, tak ×30 ([wiki](https://subwaysurf.fandom.com/wiki/Missions)) | Brädor har krafter: dubbelhopp, superhopp, glid ([SYBO](https://sybo.helpshift.com/hc/en/5-subway-surfers/faq/208-hoverboards-their-powers/)) | Uppdrag kan hoppas över med mynt eller annons. Krafter köps med nycklar |
| **Suika (Switch) / My Suika** | Skinset | Suika: betal-DLC, 1,19–1,79 USD per set ([Nintendo Life](https://www.nintendolife.com/news/2024/07/switch-eshop-hit-suika-game-adds-four-new-dlc-skins-heres-a-look)). My Suika: frön som tjänas i spel, 500–1500 per skin ([Steam](https://store.steampowered.com/news/app/2671970/view/3878226811922373511)) | Nej, bara utseende | DLC och köp |
| **Stack** | 22 blocktyper | Gems för perfekt-serier (skicklighet) plus gåvoikon med annons *(sekundär)* | Nej | Annons |
| **Slither.io** | 66 skins | Tidigare låsta bakom delning i sociala medier ([wiki](https://slitherio.fandom.com/wiki/Skins)) | Nej | Köp på Steam |

**Gemensamt:** (1) samlingen syns, och tomma platser syns. (2) Upplåsning sker på två spår, skicklighet i en runda och ackumulerad tid. (3) Det billigaste sättet att få "den gör annat" är ny värld, nytt ljud och ny animation (Crossy Road). Äkta krafter (Paper.io 2, Subway) finns i spel med valuta, där krafterna också säljs. (4) Suika-klonerna har tunnast meta, bara köpta paletter. Där finns vår differentiering.

## 5. Belägg

- **Endowed progress.** Ett stämpelkort med 10 platser där 2 var ifyllda löstes in av 34 %, mot 19 % för ett tomt kort med 8 platser (Nunes & Drèze 2006, *sekundär* [sammanfattning](https://learningloop.io/plays/psychology/endowed-progress-effect)). → En ny boksida ska starta med nivå 0 redan ifylld.
- **Goal-gradient och återställning efter belöning.** Kunder köper tätare ju närmare belöningen de kommer och saktar in direkt efter den ([Kivetz, Urminsky & Zheng 2006, PDF](https://home.uchicago.edu/ourminsky/Goal-Gradient_Illusionary_Goal_Progress.pdf)). → Visa en stapel mot nästa set, och öppna en ny tom sida samma sekund som ett set blir klart.
- **Zeigarnik är svagt, Ovsiankina håller.** En metaanalys från 2025 fann ingen minnesfördel för oavslutade uppgifter, men en allmän tendens att *återuppta* dem ([Ghibellini & Meier, Nature HSSC](https://www.nature.com/articles/s41599-025-05000-w)). → En halvfull sida lockar tillbaka, men sälj inte in det som ett "minneskrok".
- **Överjustifiering.** Förväntade, villkorade och materiella belöningar sänkte fri inre motivation (d ≈ −0,28 till −0,40), och effekten var starkare hos barn ([Deci, Koestner & Ryan 1999](https://pubmed.ncbi.nlm.nih.gov/10589297/)). → Använd överraskningar (skimrande) och milstolpar som *kvitterar* spel, inte uppdragskontrakt. Det är huvudskälet till att uppdrag hamnar lägre här.
- **Anpassning minskar avhopp.** 250 deltagare som anpassade sin avatar hoppade av mindre under 3 veckor ([Birk & Mandryk, CHI 2018](https://dl.acm.org/doi/10.1145/3173574.3174234)). Vuxet urval, så det är en analogi för barn, inte ett belägg.
- **Barn samlar.** Upp till 90 % av barn samlar något, med topp runt 10 år *(sekundär, [Psychology Today](https://www.psychologytoday.com/us/blog/the-mind-of-a-collector/202311/children-who-collect-are-not-uncommon))*. Förståelsen av sannolikhet växer mest mellan 5–6 och 8–9 år ([ScienceDirect](https://www.sciencedirect.com/science/article/abs/pii/S0885201486800090)). Barn har svårare att värdera sannolikheter ([Forbrukerrådet, Insert Coin](https://storage02.forbrukerradet.no/media/2022/05/2022-05-31-insert-coin-publish.pdf)).
- **Juridik.** Belgisk hasardlag kräver *insats*. Gratis slumpbelöningar från spelande räknas inte som hasard ([Collabra 2023](https://online.ucpress.edu/collabra/article/9/1/57641/195100/Breaking-Ban-Belgium-s-Ineffective-Gambling-Law)). ICO:s Children's Code avråder från belöningsloopar som exploaterar barn, men den gäller behandling av personuppgifter, som vi inte har. Vi använder den som riktlinje ([ICO std 13](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/childrens-information/childrens-code-guidance-and-resources/age-appropriate-design-a-code-of-practice-for-online-services/13-nudge-techniques/)). Streaks pekas ut av [5Rights](https://5rightsfoundation.com/wp-content/uploads/2024/08/5rights_DisruptedChildhood_G.pdf).
- **Samlarkortslogik för 7–10 år, min syntes:** synlig pärm med tomma rutor, sällsynta glansiga varianter och tydligt "ny!". Dubbletter fungerar i fysiska kort eftersom de kan bytas. Vi har inget nätverk, så **inga dubbletter**.

## 6. Förslag rankade efter (kick × retention) / kostnad

Kick och retention bedöms på skalan 1–3. Allt i tabellen är uppskattningar.

| Förslag | Kick | Frekvens | Investment-steget (Hook) | Dagar | Barnrisk | Poäng |
|---|---|---|---|---|---|---|
| **g) Kedjan i HUD** (egen idé; Suikas "circle of evolution" plus Paper.io-skuggorna) | 2 (liten–medel) | Varje ny nivå i rundan | Svag. Visar mål som "?" | 0,5–1 | Låg | **5,3** |
| **e) Rundavslut "nytt!"** | 2 (medel) | När något är nytt, uppskattningsvis 1 gång på 2–3 rundor i början | **Stark.** Där investeringen syns | 1–1,5 | Låg, om det inte bromsar omstart | **4,8** |
| **b) Temaset med egen känsla** | 3 (stor) | Glest, en gång på ~5–25 rundor | Stark. Val av set är autonomi | 2–3 | Låg utan pengar och dubbletter | **3,6** |
| **a) Samlarbok + skimrande** | 2 (medel), 3 första gången | ~1 skimrande var 1–3:e runda | **Stark.** Fyllda sidor | 2–2,5 | Medel: slump. Kräver skyddsräcken | **2,7** |
| **f) Rank-stege** | 1 (liten) | Mycket gles | Svag. Dubblerar hyllan | 0,5 | Låg | **2,0** |
| **d) Ikonuppdrag** | 2 | 1 per 2–5 rundor | Medel | 2–3 | Medel: överjustifiering, text-/sifferkrav | **1,6** |
| **c) Funktionella Glimtar** | 2 | Rundstart | Medel | 3–5 + balans | Låg för barn. Risk: highscore blir ojämförbar | **1,0** |

**Kommentarer:**
- **(e) Rundavslut.** DESIGN §1.5 kräver omstart på under 0,5 s. "Nytt!" måste därför spelas *ovanpå* förlustskärmen, och ett tryck startar alltid om direkt. Det som hoppas över sparas och visas i boken nästa gång.
- **(g) Kedjan.** Motsvarar Paper.io:s procentmätare i rundan. Den ger ett mål mitt i rundan ("två kvar till en ny"). Siluetterna ger nyfikenhet utan text.
- **(b) Temaset.** Ett milstolpsspår gör *när* deterministiskt och synligt. *Vilket* set man får dras från de återstående, alltså utan dubbletter. Det är Crossy Roads variabla belöning utan prisautomatens insats och dubbletter. "Gör annat" levereras som Crossy Road gör: egen klangfärg på merge-ljudet, egen partikelform och en egen bakgrundsvarelse. Reglerna ändras inte. Ansikten per nivå är desamma i alla set (UI.md: färg får inte vara enda informationsbärare). Kostnaden är låg eftersom texturerna redan bakas procedurellt från `THEME.levels` (UI.md §381).
- **(a) Samlarbok.** "Fångst" sker när en nivå *skapas*, alltså genom en skicklig handling. Skimrande avgörs med seedad RNG vid merge och är ren kosmetik: glittrande ring och egen ton. Blinkskyddet (flash-guard) gäller.
- **(d) Ikonuppdrag.** Om de byggs: 3 aktiva åt gången, de löper aldrig ut och byts bara när de är klara (Subway-modellen utan hoppa-över-knappar). Siffror 1–5 plus nivåikon. Belöningen ska vara en klistermärkesruta i boken, inte ett kontrakt om en figur.
- **(c) Funktionella Glimtar.** Den enda med äkta "Paper.io-kraft". Om den prövas: börja med **Lyktan**, en startglimt som får mergebara grannar att lysa svagt i 10 s. Den hjälper barn och gör inte fysiken sämre. Kräver separat highscore per kraft eller en markering. Speltesta först.

## 7. Förslag på siffror för v1.1

**Skimrande (per skapad nivå k, bara via merge):**
- Formel: `p_k = 1 / (T_k · c_k)`. `c_k` är det uppmätta snittet av skapade nivå k per runda. `T_k` är målet för antal rundor till första skimrande av nivån. **Mät `c_k` först** med räknare per nivå i `stats`, cirka 1 h arbete.
- Startvärden (uppskattning, justeras i `data/`): nivå 1–4: 1/60, nivå 5–6: 1/30, nivå 7–8: 1/12, nivå 9–10: 1/5.
- **Garanti ("pity"):** räknare per nivå, med garanterad skimrande efter 3/p skapade utan träff.
- Första skimrande garanteras senast i runda 3, på nivå ≥2, så att barnet lär sig att de finns.

**Samlarbok:**
- 5 sidor, en per set, med 22 platser var (11 vanliga + 11 skimrande). Totalt 110.
- En ny sida startar med nivå 0 ifylld (endowed progress).

**Temaset (5 set: Glimtarna + 4). Två spår, det som kommer först låser upp nästa set:**
- *Tidsspår* (ackumulerade merges, `stats.merges` finns redan): cirka 3, 10, 25 och 50 rundors spelande. Omräknat med uppskattningsvis 60 merges per runda (**måste mätas**) blir det 200 / 600 / 1 500 / 3 000 merges.
- *Skicklighetsspår:* första nivå 8, första nivå 10 (Klunken), första dubbel-Klunk och en full sida i boken.
- Stapeln mot nästa set visas på startskärmen och i rundavslutet.

**Skyddsräcken (checklista):**
- Ingen timer, streak, notis eller utgångsdatum.
- Inga dubbletter.
- Inga snurrande hjul eller rullar, och ingen "nästan"-animation på upplåsningar. Near-miss får bara vara äkta, enligt DESIGN §5.
- Allt kan nås av alla med tillräckligt spelande.
- Alla platser syns som siluetter (transparens).
- Upplåsning ger aldrig mer poäng.

## 8. Osäkerheter

- Paper.io 2-detaljer som upplåsningsprocent, streak-figurer, antal figurer och annonsfrekvens kommer främst från sekundärkällor och sammanfattningar. WebFetch var blockerad. Voodoos egen support bekräftar länder, bonusspel, Character Powers och "No ads"-undantaget. Spelet uppdateras ofta, så detaljerna kan ha ändrats.
- Jag hittade ingen kontrollerad studie av meta-lagrets effekt på retention i *casualspel för barn*. Rankningen är en syntes och ska valideras i speltest (P5.1). Mät D1 och D7, rundor per session och andel som öppnar boken.
- `c_k`, merges per runda och därmed alla sannolikheter och milstolpar är okända tills de mäts. Siffrorna i §7 är startvärden.
- Endowed progress och goal-gradient är studerade på vuxna konsumenter. Anpassningsstudien har vuxet urval.
- Juridiken är inte rådgivning. Slumpbelöningar utan insats bedöms vara oproblematiska, men gör en ny bedömning om monetisering någonsin införs.

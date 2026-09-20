# R&D-rapport: Enkelt mobilspel med hög "kicktäthet" (7+ år)

Författare: game-researcher (R&D-agent) · Datum: 2026-09-20
Scope: Android först, iOS sedan. Ingen monetisering i v1. Inga mörka mönster mot barn.

---

## 1. TL;DR

1. **Oförutsägbarhet slår frekvens.** Variabel kvot (variable ratio) ger den mest uthålliga och svårast släckta beteendekurvan – det är den enda "algoritm-liknande" mekanik du faktiskt behöver kopiera från TikTok. Den kan byggas helt utan pengar, loot boxes eller timers.
2. **Near-miss är gratis retention.** "Nästan!" aktiverar samma belöningskretsar som vinst och ökar spelsuget (Clark et al., *Neuron* 2009). Designa så att förlust alltid ser ut som *nästan-vinst*.
3. **Juice ger mest kick per kodtimme.** Hit-stop, screen shake, partiklar och stigande ljudpitch är några timmars arbete vardera och är den enskilt bästa ROI:n på upplevd tillfredsställelse.
4. **Friktionsfri omstart är kärnan i "one more try".** Flappy Bird-loopen fungerar för att retry-kostnaden är nära noll. Mål: <0,5 s från död till ny körning, noll knapptryck utöver ett.
5. **Barnkraven är i praktiken enkla när spelet är offline.** Utan konton, annonser och nätverk faller större delen av COPPA/GDPR-K bort – men Play Console-deklarationen, integritetspolicyn och Data safety-formuläret måste ändå fyllas i korrekt.
6. **Min #1: "KLUNK" – fysikbaserat merge-spel i en burk** (Suika-familjen) med semi-slumpad kö och sällsynta specialobjekt. Högst kicktäthet per byggd dag, kräver ingen text, och fungerar bevisat för både 7-åringar och vuxna. MVP ~8–12 dagar (uppskattning).

---

## 2. Psykologi och mekanik – med belägg

### 2.1 Variabel kvot (variable/random ratio)
Belöning efter ett *oförutsägbart* antal försök ger högst svarsfrekvens och störst motståndskraft mot utsläckning – dvs. spelaren slutar inte när belöningen uteblir. Experimentell forskning på just videospel visar att ratio-förstärkning både förlänger speltiden och ökar uthålligheten *efter misslyckande* jämfört med kontroll, och att random-ratio ger mer perseverativt beteende än fixed-ratio, särskilt vid långa intervall.

- [The influence of ratio-reinforcement on video-gaming behaviour (avhandling, UTas)](https://figshare.utas.edu.au/articles/thesis/The_influence_of_ratio-reinforcement_on_video-gaming_behaviour/23239106)
- [Why are Some Games More Addictive than Others: Timing and Payoff (PMC)](https://pmc.ncbi.nlm.nih.gov/articles/PMC4735408/)

**Designregel:** låt belöningens *storlek* variera, inte spelarens *chans att få spela*. Kicken ska komma av spelarens handling, inte av en dragning.

### 2.2 Near-miss-effekten
Clark, Lawrence, Astley-Jones & Gray (2009), *Neuron* 61:481–490: near-miss upplevs som *mindre* trevligt men *ökar* lusten att spela igen, och aktiverar ventrala striatum, insula, rACC och ett mellanhjärneområde nära dopaminerga celler – alltså vinstkretsarna. Effekten fanns bara när försökspersonen själv hade kontroll över insatsen.

- [Gambling near-misses enhance motivation to gamble (ScienceDirect)](https://www.sciencedirect.com/science/article/pii/S0896627309000373) · [PubMed](https://pubmed.ncbi.nlm.nih.gov/19217383/)
- [Gambling Severity Predicts Midbrain Response to Near-Miss (J Neurosci)](https://www.jneurosci.org/content/30/18/6180)

**Designregel (etisk variant):** near-miss ska vara *äkta* – spelaren var faktiskt nära, och skärmen ska visa det tydligt ("2 px från rekordet", en frukt som nästan slogs ihop). Fejkade near-miss är mörkt mönster; äkta near-miss är bara bra feedback.

### 2.3 "One more try"-loopen
Flappy Bird är standardexemplet: brutal svårighet + nära noll retry-kostnad + score som kryper uppåt ett poäng i taget. Kombinationen gör att frustrationen omedelbart kanaliseras till ett nytt försök i stället för till att stänga appen.

- [Why Flappy Bird is so Addicting – The Flow Behind the Game](https://bcgavel.com/2014/02/20/why-is-flappy-bird-so-addicting-the-flow-behind-the-game/)
- [What makes games like Flappy Bird so addictive? (The Week)](https://theweek.com/articles/450939/what-makes-games-like-flappy-bird-addictive)

### 2.4 Flow och kompetenskurva
Självbestämmandeteorin: upplevd **autonomi** och **kompetens** i spelet förutsäger njutning, framtida spelande och välbefinnande – och kompetensupplevelsen hänger ihop med hur *intuitiv* kontrollen är. För ett enfingerspel betyder det: kontrollen får aldrig kännas orättvis.

- [Ryan, Rigby & Przybylski (2006), *Motivation and Emotion* (PDF)](https://selfdeterminationtheory.org/SDT/documents/2006_RyanRigbyPrzybylski_MandE.pdf)
- [Przybylski, Rigby & Ryan (2010), A Motivational Model of Video Game Engagement (PDF)](https://selfdeterminationtheory.org/SDT/documents/2010_PrzybylskiRigbyRyan_ROGP.pdf)

### 2.5 Hook-modellen (Eyal)
Trigger → Action → Variable Reward → Investment. Investeringssteget är det som gör en engångsspelare till återvändare: spelaren lägger in något (highscore, upplåst figur, ett halvfärdigt bygge) som gör nästa session mer värd.

- [Nir Eyal, *Hooked* – översikt (Amplitude)](https://amplitude.com/blog/the-hook-model) · [Kritik: Hook Model skapar beroenden, inte vanor (Yu-kai Chou)](https://yukaichou.com/gamification-analysis/hook-model-octalysis-habit-addiction/)

**Etisk gräns för barn:** använd *interna* triggers (tristess, "jag kan slå mitt rekord") och undvik push-notiser, dagliga login-belöningar och räknare som går ut. Chous kritik är värd att läsa innan man tillämpar modellen på 7-åringar.

### 2.6 Korta sessioner och "burst of fun"
Hypercasual-sessioner ligger typiskt kring 30–60 sekunder, med D1-retention ~27 % och D30 ~2 % enligt branschbenchmarks – dvs. genren är extremt bra på "en gång till" men dålig på "imorgon igen". Det är i *meta-lagret* (små permanenta upplåsningar) retention byggs.

- [GameAnalytics – 2025 Mobile Gaming Benchmarks](https://www.gameanalytics.com/reports/2025-mobile-gaming-benchmarks)
- [Sammanfattning av hypercasual-benchmarks](https://gamedevreports.substack.com/p/gameanalytics-mobile-gaming-benchmarks)

### 2.7 GDC-postmortem: Crossy Road
Hipster Whale byggde Crossy Road på 12 veckor, utgick från en analys av vad som gör mobilspel delbara, och bytte från ett-tapp-kontroll (Flappy-stil) till svep när spelarna inte kände sig i kontroll. Deras retentionsdefinition: "spela så länge som möjligt *och* vilja komma tillbaka imorgon".

- [GDC Vault: Crossy Road – A Whale of a Time](https://gdcvault.com/play/1021897/Crossy-Road-A-Whale-of) · [Game Developer-sammanfattning](https://www.gamedeveloper.com/business/video-deconstructing-the-successful-design-of-i-crossy-road-i-)

---

## 3. Game feel / juice – mest kick per implementerad timme

Grundkällor: [Juice it or lose it – Jonasson & Purho, GDC Europe 2012](https://www.youtube.com/watch?v=Fy0aCDmgnxg) ([GDC Vault](https://www.gdcvault.com/play/1016487/juice-it-or-lose)) · [The Art of Screenshake – Jan Willem Nijman, Vlambeer, INDIGO 2013](https://www.youtube.com/watch?v=AJdEqssNZ-U) · Steve Swink, *Game Feel* (2008) ([Game feel, Wikipedia](https://en.wikipedia.org/wiki/Game_feel)).

Rangordnad efter uppskattad kick-per-timme (mina uppskattningar, byggtid antar Godot 4 eller motsvarande):

| # | Teknik | Byggtid (uppskattning) | Effekt |
|---|---|---|---|
| 1 | **Ljud med pitch-stegring** (samma pling, +semiton per combo-steg, reset vid miss) | 1–2 h | Enormt. Gör combo hörbar utan text – funkar för icke-läsare. |
| 2 | **Hit-stop / frame freeze** (2–6 frames paus vid träff/merge) | 1–2 h | Vlambeers #1-tips. Ger tyngd åt varje träff. |
| 3 | **Scale-punch + easing** (objekt skalas 1.0→1.25→1.0 med back/elastic-ease) | 2–3 h | Jonasson/Purhos första steg. Gör allt levande. |
| 4 | **Partiklar vid varje händelse** (5–20 små bitar, ärver hastighet) | 2–4 h | Hög upplevd rikedom, låg kostnad. |
| 5 | **Screen shake – dämpad, riktad, skalad efter event** | 2–3 h | Kraftfull men måste begränsas (se 5.4). Kapa amplituden hårt. |
| 6 | **Combo-/scorepop som flyger ut från händelsen** och tweenar mot HUD | 2–4 h | Ger "numbers go up"-känslan även utan siffervana. |
| 7 | **Haptik** (Android `VibrationEffect`, korta 10–30 ms pulser, längre vid stor kick) | 2–3 h | Underskattad på mobil; ger fysisk kick utan ljud. Måste gå att stänga av. |
| 8 | **Kamera-zoom/tilt vid stora events** | 3–5 h | Reserveras för "askul"-ögonblicken så de sticker ut. |
| 9 | **Slow-mo på sista sekunderna före förlust** | 2–4 h | Förstärker near-miss enormt. |

**Regel från båda talks:** juice ska vara *proportionell* mot händelsens storlek. Om allt skakar maximalt blir inget speciellt. Bygg en enda `Juice.trigger(event, intensity 0–1)`-funktion och skala alla nio effekterna från den – då kan du finjustera hela spelkänslan från ett ställe.

---

## 4. Benchmark: 8 enkla spel på mekaniknivå

Sessionslängder och kicktäthet nedan är **uppskattningar** baserade på mekanikanalys, om inte annat anges.

| Spel | Kärnloop (1 mening) | Sessionslängd | Kicktäthet | Varför man kommer tillbaka | Vad vi kan låna |
|---|---|---|---|---|---|
| **Flappy Bird** | Tappa för att flaxa mellan rör, dö, starta om direkt. | 10–60 s/körning | Låg under körning, hög vid varje passerat rör | Near-miss + noll retry-kostnad + rekord som kryper 1 poäng i taget | **Instant restart**, rekord-delta som primär belöning |
| **Crossy Road** | Svep framåt genom oändlig trafik tills du blir träffad. | 30–90 s | Medel (varje risktagen korsning) | Slumpad figurupplåsning + mycket kort återhämtning; bytte bort tap till svep för kontrollkänsla ([GDC](https://gdcvault.com/play/1021897/Crossy-Road-A-Whale-of)) | **Kosmetiska upplåsningar som variabel belöning** utan pengar |
| **Stack** | Tappa ett block så det överlappar det förra; överskottet faller bort. | 20–60 s | Hög (1 kick/sekund) | Perfekt-träff-streak med stigande ljudpitch; känns som musik | **Pitch-stegring på streak** – billigaste kicken i hela rapporten |
| **Helix Jump** | Släpp bollen genom luckor i en roterande spiral. | 30–120 s | Låg-medel, med sällsynta "genombrott" genom flera plan | Genombrottsögonblicket (flera våningar i rad) är den stora kicken | **Sällsynt kaskad** som bryter av en annars lugn loop |
| **Suika / Watermelon Game** | Släpp frukter i en burk; två lika smälter till nästa storlek, undvik överfyllnad. | 3–10 min | Små kickar var 2–5 s, kaskader var 20–60 s | Fysikens oförutsägbarhet + växande press mot brädets kant; varje nästan-vattenmelon är en near-miss | **Kärnkandidat** – se #6 |
| **2048** | Svep för att slå ihop lika brickor tills brädet är fullt. | 3–15 min | Låg-medel; kicken är kedjemergar | Rent kompetensbaserat, en slumpad ny bricka per drag ger variabilitet | **Slumpad kö** som enda RNG-källa |
| **Ballz / Bounce-brickbrytare** | Sikta en gång, se 1–80 bollar studsa och rasera block, upprepa. | 5–20 min | Mycket låg under skottet, explosiv vid ett lyckat skott | Klassisk variabel kvot: samma insats ger 2 eller 40 block | **Turbaserad spänning + oförutsägbar utdelning** |
| **Vampire Survivors (och lookalikes)** | Rör dig med ett finger, vapnen skjuter själva, level-upp var 20–40 s. | 15–30 min | Extremt hög i sena skeden | "Level up → välj → omedelbar feedback"; magnet-pickupen ger ett kedjelevelupp = ren dopaminexplosion ([analys](https://www.port.ac.uk/news-events-and-blogs/blogs/popular-culture/vampire-survivors-how-developers-used-gambling-psychology-to-create-a-bafta-winning-game)) | **Valfritt uppgraderingsval** som variabel belöning; **magnet-momentet** |
| *(Bonus)* **Idle/incremental** | Klicka/vänta, siffror stiger, köp uppgradering som får siffror att stiga snabbare. | 30 s × många/dag | Låg men konstant | Synlig progression + mikroprestationer med minuters mellanrum ([DiVA-studie, PDF](https://www.diva-portal.org/smash/get/diva2:1481219/FULLTEXT01.pdf)) | **Mikro-meta mellan körningar**, inte som huvudloop |

**Mönstret:** de mest beroendeframkallande är de som kombinerar en *lugn, nästan tråkig* baslinje med *sällsynta kaskader*. Det är exakt beställarens TikTok-liknelse, uttryckt i mekanik.

---

## 5. Barn 7+ – designkrav och regelverk

### 5.1 Designkrav (ingen text behövs)
- **Noll obligatorisk text.** Ikoner, färg, ljud och animation ska bära all information. Tutorial = en animerad hand som visar gesten, loopad tills spelaren gör den.
- **Touchmål:** Material Design-minimum är 48×48 dp (~9 mm fysiskt); rekommenderat spann för touchytor är 7–10 mm. För barn med outvecklad finmotorik bör målen göras **större** – jag föreslår ≥64 dp för alla knappar (uppskattning, extrapolerad från Googles egen skrivning om barn). Källa: [Material Design – Accessibility](https://m1.material.io/usability/accessibility.html), [Android: Touch target size](https://support.google.com/accessibility/android/answer/7101858).
- **Läsbarhet:** hög kontrast (WCAG AA, 4.5:1), inga tunna typsnitt, aldrig färg som enda informationsbärare (färgblindhet ~8 % av pojkar).
- **Kontroll:** ett finger, en gest. Crossy Road-lärdomen: om spelaren inte känner sig i kontroll spelar det ingen roll hur juicy det är.
- **Ingen tidspress i UI:t.** Nedräkningar mot barn är precis det beställaren vill undvika.

### 5.2 Google Play – Families
Kraven för det gamla "Designed for Families" har slagits ihop i den bredare **Families Policy**; alla appar som uppfyller den är numera kvalificerade för Kids-fliken och för "Teacher Approved"-granskning av Googles panel (200+ amerikanska lärare). Märket går inte att köpa – det kräver opt-in, godkänd teknisk/integritetsmässig granskning och manuell bedömning.

- [Google Play Families Policies (Play Console Help)](https://support.google.com/googleplay/android-developer/answer/9893335?hl=en)
- [Android Developers Blog: Helping families find high-quality apps for kids (2022)](https://android-developers.googleblog.com/2022/11/helping-kids-and-families-find-high-quality-apps-for-kids.html)
- [Android Developers Blog: Teacher Approved (2020)](https://android-developers.googleblog.com/2020/04/promoting-high-quality-teacher-approved.html)

**Praktiskt för oss:** deklarera målgrupp korrekt i Play Console ("Target audience and content"), åldersmärk via IARC-formuläret, publicera integritetspolicy (krävs även utan datainsamling), fyll i Data safety-formuläret ärligt (för oss: "ingen data samlas in, ingen data delas"). Ingen annons-SDK behövs → [Families Self-Certified Ads SDK-programmet](https://support.google.com/googleplay/android-developer/answer/9900633?hl=en) blir irrelevant i v1. Ingen precis platsdata, inga enhetsidentifierare från barn.

### 5.3 Apple – Kids Category
Guideline 1.3 (ordagrant från [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)): appar i Kids Category **får inte** innehålla länkar ut ur appen, köpmöjligheter eller andra distraktioner "unless reserved for a designated area behind a parental gate"; får **inte** skicka PII eller enhetsinformation till tredje part; och **bör inte** innehålla tredjeparts-analys eller tredjepartsannonser. Åldersband: 5 och yngre / 6–8 / 9–11. När appen väl publicerats i Kids Category gäller kraven för alla framtida uppdateringar, även om kategorin tas bort.

### 5.4 COPPA / GDPR-K när spelet saknar konton, annonser och nätverk
- **COPPA** gäller bara tjänster som *samlar in, använder eller lämnar ut* personuppgifter från barn. En helt offline-app utan identifierare, utan analys-SDK och utan nätverksanrop hamnar utanför regelns krav. Observera att *persistent identifier* (t.ex. reklam-ID, enhets-ID) räknas som personuppgift – alltså: inga sådana. FTC:s uppdaterade regel (april 2025) ger 365 dagar för efterlevnad av de ändrade delarna. Källor: [FTC COPPA FAQ](https://www.ftc.gov/business-guidance/resources/complying-coppa-frequently-asked-questions), [FTC Six-Step Compliance Plan](https://www.ftc.gov/business-guidance/resources/childrens-online-privacy-protection-rule-six-step-compliance-plan-your-business), [Federal Register: final rule 2025](https://www.federalregister.gov/documents/2025/04/22/2025-05904/childrens-online-privacy-protection-rule).
- **GDPR (art. 8, "GDPR-K")** aktualiseras vid behandling av personuppgifter baserad på samtycke i informationssamhällets tjänster. Ingen behandling → ingen rättslig grund behövs. Lokalt sparad highscore i appens sandlåda som aldrig lämnar enheten är i praktiken inte en behandling som utlöser art. 8-krav (**min bedömning, inte juridisk rådgivning** – låt någon läsa på inför lansering).
- **Konkret teknisk checklista v1:** ingen `INTERNET`-permission i manifestet alls (det är det starkaste och mest verifierbara påståendet du kan göra), inga tredjeparts-SDK:er, ingen crash reporting, ingen Firebase, ingen Ad ID. Spara state i lokal fil. Då blir Data safety-formuläret trivialt och Teacher Approved-granskningen enkel.

### 5.5 Fotosensitiv epilepsi
WCAG 2.3.1 (nivå A): inget får blinka mer än **tre gånger per sekund**, om inte blinkningen ligger under general flash- och red flash-tröskeln. Röd blinkning är särskilt farlig och har ett eget test. Källa: [W3C – Understanding SC 2.3.1](https://www.w3.org/WAI/WCAG22/Understanding/three-flashes-or-below-threshold.html).

**Praktiskt:** vitblixtar vid explosioner max 2/s, aldrig mättad röd stroboskop, screen shake med amplitud som klingar av inom 0,3 s, och en tillgänglighetsswitch "Lugnt läge" som halverar all juice. Lägg switchen på startskärmen som en ikon, inte i en textmeny.

---

## 6. Tre konkreta spelidéer

### Kandidat A — **"KLUNK"** (fysik-merge i burk) ★ #1

**Kärnloop:** Du tappar ett objekt i en glasburk; två likadana som nuddar varandra smälter ihop till nästa storlek, med en fet pop och ett ljud ett halvt tonsteg högre. Burken fylls obönhörligen, fysiken flyttar allt du trodde du hade kontroll över, och målet är den största frukten innan det svämmar över.

**Variabel belöning:**
- *Små kickar (var 2–5 s, uppskattning):* enstaka merge – partiklar, scale-punch, pitch +1.
- *Medel (var 20–60 s):* kedjemerge där en sammanslagning utlöser 3–6 till på raken – hit-stop, kamerazoom, stigande arpeggio.
- *Stora (var 2–5 min):* ett sällsynt specialobjekt i kön (bomb / regnbågsklot / magnet) som rensar en fjärdedel av burken i en kaskad. **Frekvensen är variabel kvot: objektet dyker upp efter 25–60 drops, slumpat.** Ingen dragning, inga pengar – bara kön.
- *Near-miss inbyggd:* två näst-största frukter som ligger bredvid varandra utan att röras är en *synlig, äkta* near-miss. Markera dem med en svag puls.

**Varför både 7-åring och vuxen fastnar:** 7-åringen förstår "lika + lika = större" utan ett ord text och älskar kaskaderna. Vuxna ser ett spatialt optimeringsproblem med perfekt skill-ceiling. Suika bevisade exakt den bredden.

**Byggkomplexitet:** **8–12 dagar MVP** (uppskattning) med Godot 4:s inbyggda 2D-fysik. Riskfri teknik, ingen nätverkskod, inga assets utöver ~11 cirkelsprites.

**Risker:** (a) Genren är välfylld – differentiering måste ligga i juice och specialobjekten. (b) Fysikinställningarna är kritiska och kräver ren speltestning, inte kod. (c) Sessionerna (3–10 min) är längre än hypercasual-normen – bra för engagemang, sämre för "snabbt en runda".

---

### Kandidat B — **"STUDS"** (turbaserad studsbrytare, Ballz-familjen)

**Kärnloop:** Du siktar en gång per tur och släpper lös en svärm bollar som studsar runt bland block; sedan sitter du bara och tittar medan blocken sprängs, tills raden når botten. Varje tur lägger till en boll, så svärmen växer från 1 till 80.

**Variabel belöning:** Samma insats (ett sikte) ger radikalt olika utdelning – ibland 2 block, ibland en 15-sekunders kaskad där bollarna fastnar i en ficka och river allt. Det är ren variable ratio utan någon RNG-generator: *fysiken själv är slumpgeneratorn*, vilket känns rättvist. Små kickar var ~2 s (blockträff), medel var ~30 s (bra tur), stora var ~3–5 min (fick-kaskaden) – uppskattningar.

**Varför båda fastnar:** Väntan mellan skott är den "ibland lite tråkiga" fasen som gör kaskaderna euforiska. Barn gillar att bara titta på bollarna; vuxna räknar vinklar.

**Byggkomplexitet:** **10–15 dagar MVP** (uppskattning). Studskollision med många objekt kräver optimering, och "bollen fastnar i horisontell loop" är en klassisk bugg som måste hanteras.

**Risker:** Långa turer kan bli genuint tråkiga (inte "produktivt tråkiga"). Behöver snabbspolning. Sifferbaserad feedback passar 7-åringar sämre.

---

### Kandidat C — **"MYRARMÉN"** (bullet-heaven lite för barn)

**Kärnloop:** Du drar fingret för att flytta en liten figur; figuren anfaller helt automatiskt, och fiender strömmar in i allt tätare vågor. Var 20–40 sekunder får du välja mellan tre uppgraderingar som ritas som bilder, aldrig som text.

**Variabel belöning:** *Små* – varje besegrad fiende poppar (var ~1 s). *Medel* – level-upp med tre slumpade val (var 20–40 s). *Stora* – magnetpickupen som suger in alla kristaller och utlöser 3–4 level-upp i rad, plus sällsynta vapenkombinationer som fyller skärmen (var 2–4 min, uppskattning).

**Varför båda fastnar:** Renodlad power fantasy: du börjar svag och slutar som en gående explosion. Uppgraderingsvalen ger autonomi (SDT), fienderna ger kompetens.

**Byggkomplexitet:** **15–25 dagar MVP** (uppskattning) – kräver spawnsystem, uppgraderingsträd, balansering, objektpooling för hundratals entiteter, och betydligt mer konst.

**Risker:** Störst scope. Balansering är veckor av arbete, inte dagar. Skärmkaoset krockar med WCAG 2.3.1 om det inte tyglas. Våldstema måste hållas ofarligt (myror/bubblor, inte vapen).

---

### Rankning och motivering

**#1 KLUNK · #2 STUDS · #3 MYRARMÉN**

KLUNK vinner på fyra punkter som alla är direkt kopplade till beställningen:

1. **Högst kicktäthet per byggd dag.** Den små-medel-stora belöningstrappan finns nästan gratis i fysiken; du behöver inte koda en belöningsalgoritm, du behöver bara juice:a den som redan finns.
2. **Oförutsägbarheten känns rättvis.** Fysik som slumpgenerator ger variable-ratio-effekten utan att någonsin kännas som en dragning – avgörande när vi medvetet undviker gambling-mekanik för barn.
3. **Noll text.** "Lika + lika = större" är begripligt för en 7-åring på två sekunder, och därmed också för Teacher Approved-panelen.
4. **Lägst teknisk risk för en webbutvecklare.** 2D-fysik, en scen, inget nätverk, inga konton. Rimligt att ha något spelbart i handen inom två veckor.

Rekommenderad v1-avgränsning: en burk, elva objektnivåer, ett specialobjekt, lokal highscore, "Lugnt läge"-switch, ingen INTERNET-permission. Bygg `Juice.trigger()` först, innan spelmekaniken är klar – juice:en *är* produkten.

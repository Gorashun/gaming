# Marknad, engagemang och regelverk – mobil chibi-ARPG för 7+

*Roller: R&D-lead + Player Safety Advisor. Datum: 2026-09-26.*
*Metod: WebSearch. Flera primärkällor (pegi.info, support.google.com, konsumentverket.se) var blockerade för WebFetch i vår miljö, så en del påståenden bygger på sökresultatens sammanfattningar och sekundärkällor. **Stämma av mot primärtext innan butikspublicering.** "Uppskattning" = vår egen bedömning.*

---

## 0. Slutsats först (TL;DR)

- Beställarens önskan att spelet ska vara "extremt svårt att lägga ifrån sig" med "TikTok-lika variabla belöningar" **går inte att uppfylla ordagrant för en 7+-publik i EU**. DSA:s riktlinjer för minderåriga pekar ut "intermittent or random rewards, scarcity or persuasive design techniques that can lead to excessive or addictive behaviours" som något som inte ska användas mot minderåriga ([Freshfields/Lexology-sammanfattning](https://www.lexology.com/library/detail.aspx?g=93b2f843-a50a-4d0a-bc90-966bbdb90ff2), [EU-kommissionen](https://digital-strategy.ec.europa.eu/en/library/commission-publishes-guidelines-protection-minors)).
- Det vi **kan** och **ska** bygga: ett spel man *vill* återvända till (kompetens, upptäckt, överraskande loot som man *spelar* sig till), inte ett spel man *har svårt att sluta* med. Variabel loot från fiender (Diablo-kärnan) är ok; slump som kan köpas för pengar är inte ok.
- Rekommenderad affärsmodell: **premium (engångsköp) eller gratis demo + engångsupplåsning**, ev. kosmetiska paket med fast innehåll bakom föräldraspärr. Inga loot boxes, ingen virtuell premiumvaluta, inga nedräkningserbjudanden, inga annonser (eller endast certifierade, kontextuella – avrådes).
- Nya PEGI-kriterier från juni 2026 gör dåliga mekaniker dyra: betalslump ⇒ minst PEGI 16, tidsbegränsade erbjudanden ⇒ minst PEGI 12 (7 om köp är avstängda som standard) ([Wccftech](https://wccftech.com/games-with-loot-boxes-now-get-pegi-16-rating-starting-june-2026-ea-sports-fc/), [Two Birds via sökning](https://mediawrites.twobirds.com/post/102mn2b/pegi-age-rating-classification-update)).

---

## 1. Konkurrenter på mobil

| Spel | Vad driver retention | Vad kritiseras | Lärdom för oss |
|---|---|---|---|
| **Diablo Immortal** | Stark Diablo-känsla i strid, dagliga aktiviteter, klaner/socialt, säsonger | Legendary Gems via betalslump; uppskattat ~110 000 USD för att maxa en karaktär ([VGC](https://www.videogameschronicle.com/news/maxing-out-a-diablo-immortal-character-could-reportedly-cost-up-to-110000/)); 5-stjärniga crests ~0,0045 % enligt spelarberäkning ([Here & Now/WBUR](https://www.wbur.org/hereandnow/2022/06/28/diablo-immortal-controversy)); släpptes inte i Belgien/Nederländerna p.g.a. loot box-regler ([CBR](https://www.cbr.com/diablo-immortal-banned-in-two-countries-belgium-netherlands/)) | Kommersiell succé (~525 MUSD år 1, [data.ai via GameDev Reports](https://gamedevreports.substack.com/p/dataai-diablo-immortal-earned-525m)) men varumärkesskada. Modellen är **otillåten** för oss. |
| **Torchlight: Infinite** | Buildbredd (hero traits), säsonger/ligor | Gacha kopplad till hero traits trots löfte om "bara kosmetik"; betalväggar på lagerplatser ([Wikipedia](https://en.wikipedia.org/wiki/Torchlight:_Infinite), [Android Police](https://www.androidpolice.com/torchlight-infinite-review/)); säsongstoppar som snabbt faller ([Steam-diskussion](https://steamcommunity.com/app/1974050/discussions/0/600770973001636224/)) | Brutna löften om "ingen P2W" straffas hårt i recensioner. Säsongsmodell ger spikar, inte lojalitet. |
| **Archero / Archero 2** | Kort run (2–5 min, uppskattning), val mellan 3 slumpade förmågor vid varje level-up, synergier ([Game Developer](https://www.gamedeveloper.com/design/finding-the-fun-archero-part-1---gameplay)); förmågor presenteras som snurrande "slot-hjul" för förväntan ([GameRefinery](https://www.gamerefinery.com/archero-excels-in-engagement-by-creating-an-anticipation-for-rewards/)) | Archero 2: tidsbegränsade event som kräver köp, flera säsongspass, "mer P2W än ettan" ([Game400](https://game400.com/reviews/archero-2-a-worthy-sequel-or-just-an-upgrade), [JustUseApp](https://justuseapp.com/en/app/6502820653/archero-2/reviews)) | **Ta:** 3-val-förmågor, korta runs, stutter-step-känsla. **Undvik:** slot-maskin-presentationen (near-miss-estetik) och tidsbegränsade betalevent. |
| **Grim Soul** | Överlevnad/crafting, svårighet | Energimätare som bromsar spel tills man väntar eller betalar ([Medium-recension](https://medium.com/@anjerosan/grim-soul-survival-7fc5b12493a8)) | Energisystem = tvångsmekanik; inte för barn. |
| **Eternium** | Klassisk ARPG-loop, ingen energi, "never pay to win", >90 % spelar gratis ([MiniReview](https://minireview.io/action/eternium)); 4,8 i betyg på Google Play | Gems för uppgraderingar droppar sällan ([App Store-recensioner](https://apps.apple.com/us/app/eternium/id579931356?see-all=reviews)) | Visar att en rättvis mobil-ARPG kan hålla i över 10 år. Närmaste förebilden för oss. |
| **Undecember** | Djup PoE-lik buildfrihet | Tung P2W, dyra QoL-köp (lagerplatser upp till 75 USD), förvirrande valutor ([MMOHuts](https://mmohuts.com/review/undecember), [Loot and Grind](https://lootandgrind.com/undecember-worth-playing/)) | Förvirrande multi-valuta = exakt det CPC-nätverket nu angriper (se §3). |
| **Soul Knight** | Offline-roguelite, samlande av hjältar/vapen, kosmetik ([MiniReview](https://minireview.io/action/soul-knight)) | Borttaget offline-läge upprörde spelarna ([Marlvel intel](https://marlvel.ai/intel-report/games/soul-knight)) | Offline och "rättvist" rykte är en tillgång. |
| **Vampire Survivors (mobil)** | Extrem juice, eskalerande power-fantasy, upplåsningar; frivilliga annonsknappar som "aldrig avbryter" ([PocketGamer.biz](https://www.pocketgamer.biz/vampire-survivors-developer-takes-new-approach-to-monetisation/), [Kotaku](https://kotaku.com/vampire-survivors-free-iphone-steam-mobile-smartphone-1849955308)) | Lite kritik mot monetisering | Bevis på att "dopaminkickar" kan komma från **spelmekanik och juice** i stället för från butiken. |

**Mönster (uppskattning utifrån ovan):** De högst omtyckta titlarna (Eternium, Vampire Survivors, Soul Knight) har rättvis monetisering och stark "game feel". De mest inkomstbringande (Diablo Immortal) tjänar på val/"whales" och betalslump – en modell som är otillåten eller åldersgränsbelastad för 7+.

---

## 2. Psykologin bakom engagemang

### 2.1 Variabelt kvotschema (variable ratio reinforcement)
- En handling ger belöning med viss sannolikhet; ger jämn, hög svarsfrekvens utan pauser – därför är det kärnan i både loot drops och spelautomater ([Hopson, "Behavioral Game Design", Game Developer](https://www.gamedeveloper.com/design/behavioral-game-design)).
- **Bedömning:** Mekanismen är neutral; skadan uppstår när den kopplas till **pengar**, **tid-gating** eller **obegränsade sessioner**. Slumpad loot från fiender i ett spel man betalat för är branschstandard och uttryckligen ok enligt vår policy.

### 2.2 Near-miss
- Nästan-vinster upplevs som mindre trevliga än rena förluster men **ökar lusten att spela igen** och aktiverar vinstrelaterade hjärnområden (ventral striatum, insula) ([Clark m.fl. 2009, Neuron](https://pubmed.ncbi.nlm.nih.gov/19217383/)); effekten är starkare hos personer med spelproblem ([Chase & Clark 2010](https://pubmed.ncbi.nlm.nih.gov/20445043/)).
- **Bedömning:** Vi ska **inte** designa konstgjorda near-misses (hjul som stannar precis bredvid legendariskt, "nästan!"-texter). Ett naturligt nära boss-nederlag är ok – det är kompetensfeedback, inte manipulerad slump.

### 2.3 "Juice"
- "Juicy" = spelet svarar på allt med kaskader av feedback: partiklar, skärmskak, squash/stretch, ljud ([Jonasson & Purho, GDC Europe 2012](https://www.youtube.com/watch?v=Fy0aCDmgnxg); [sammanfattning](https://roblog.co.uk/2024/03/juicy-games/)).
- **Bedömning:** Juice är det etiska svaret på beställarens "dopaminkickar": intensiva, överraskande ögonblick som är **knutna till spelarens egna handlingar** och tar slut när spelaren slutar. Ingen tvångskomponent.

### 2.4 Compulsion loop vs. core loop
- Core loop = den primära aktivitetskedjan (slåss → loot → bli starkare → svårare område). Compulsion loop = en designad vana (förväntan → handling → belöning) som upprepas för att få belöning eller slippa obehag ([Hopson](https://www.gamedeveloper.com/design/behavioral-game-design), [Wikipedia: Compulsion loop](https://en.wikipedia.org/wiki/Compulsion_loop), [GameAnalytics](https://www.gameanalytics.com/blog/the-compulsion-loop-explained)).
- Varningssignal: när retention drivs av *obehag vid frånvaro* (tappad streak, missat event, energi som "slösas") är det tvång, inte lust.

### 2.5 Self-Determination Theory (SDT)
- Upplevd **kompetens** och **autonomi** i spelet förutsäger njutning, fortsatt spelande och *förbättrat* välbefinnande efter spel; **samhörighet** förutsäger oberoende detsamma i flerspelarspel ([Ryan, Rigby & Przybylski 2006](https://link.springer.com/article/10.1007/s11031-006-9051-8); [PDF](https://selfdeterminationtheory.org/SDT/documents/2006_RyanRigbyPrzybylski_MandE.pdf)). Intuitiv styrning bidrar till kompetens och närvarokänsla (samma källa).

### 2.6 Långsiktig lust vs. kortsiktigt tvång

| Långsiktig lust (bygg detta) | Kortsiktigt tvång (undvik) |
|---|---|
| Kompetens: tydlig skicklighetskurva, rättvisa bossar | Energi/stamina, väntetimers |
| Autonomi: fria builds, val av mål | Tvingande dagliga checklistor med straff |
| Samhörighet: soffko-op/familj, dela builds | Social skuld ("din klan behöver dig") |
| Överraskning i spelet (loot, hemliga rum, sällsynta fiender) | Köpbar slump, near-miss-presentation |
| Naturliga stopp-punkter | Oändliga sessioner, "bara en till"-cliffhangers designade att förhindra avslut |

**Forskningskontext:** Gaming disorder är sedan ICD-11 en diagnos (nedsatt kontroll, prioritering av spel, fortsättning trots negativa följder) ([PMC-översikt](https://pmc.ncbi.nlm.nih.gov/articles/PMC12640003/)). Predatorisk monetisering döljer långsiktiga kostnader tills spelaren är ekonomiskt och psykologiskt investerad ([King & Delfabbro](https://www.researchgate.net/profile/Daniel-King-36/publication/325479259_Predatory_monetization_features_in_video_games_eg_'loot_boxes'_and_Internet_gaming_disorder/links/5e1cf3e292851c8364cbc468/Predatory-monetization-features-in-video-games-eg-loot-boxes-and-Internet-gaming-disorder.pdf)). Loot box-köp korrelerar med problemspelande (n=7 422) ([Zendle & Cairns 2018, PLOS ONE](https://journals.plos.org/plosone/article?id=10.1371%2Fjournal.pone.0206767)); ungdomar har högre belöningskänslighet och svagare självreglering ([systematisk översikt 2026](https://www.sciencedirect.com/science/article/abs/pii/S0306460326001486)).

---

## 3. Regelverk för ett 7+-spel i EU/Sverige och butiker

### 3.1 Google Play Families Policy
- Spel med barn i målgruppen ska följa Families-kraven; annonser endast via **Families Self-Certified Ads SDK**; blandad målgrupp kräver **neutral åldersskärm** ([Google Play Families Policies](https://support.google.com/googleplay/android-developer/answer/9893335?hl=en), [Self-Certified Ads SDK Program](https://support.google.com/googleplay/android-developer/answer/9900633?hl=en)).
- Ingen personaliserad/intressebaserad reklam eller remarketing mot barn ([AdMob-hjälp](https://support.google.com/admob/answer/6223431?hl=en)).
- All insamling av personuppgifter från barn – även via SDK:er/API:er – ska redovisas; integritetspolicy krävs ([Data practices in Families apps](https://support.google.com/googleplay/android-developer/answer/11043825?hl=en)).
- Riktlinjerna för annonser/monetisering gäller **all** kommersiell content (IAP-erbjudanden, korspromotion). Simulerat spel om pengar är inte tillåtet i Families-programmet ([Playwire-sammanfattning](https://www.playwire.com/blog/what-is-google-plays-families-ads-program)).
- Juli 2026-uppdatering: förbud för anonyma chattappar att rikta sig till barn ([Preview](https://support.google.com/googleplay/android-developer/answer/17122218)).

### 3.2 Apple – Kids Category & allmänna regler
- Kids Category: inga köpmöjligheter, externa länkar eller behörighetsfrågor utanför en **föräldraspärr** (parental gate) ([Apple Developer News](https://developer.apple.com/news/?id=091202019a), [App Review Guidelines 1.3](https://developer.apple.com/app-store/review/guidelines/)).
- Tredjepartsanalys/-reklam bara i begränsade fall: ingen IDFA, inga identifierande uppgifter, inga platsuppgifter; reklam endast kontextuell med mänsklig granskning ([Guidelines 1.3](https://developer.apple.com/app-store/review/guidelines/)).
- Alla appar: loot boxes måste visa oddsen innan köp (3.1.1) ([Fenwick](https://www.fenwick.com/insights/publications/apple-now-requires-disclosure-of-loot-box-odds)).
- **Bedömning:** Kids Category är valfritt; ett mörkt fantasy-ARPG kan välja vanlig kategori med 9+ men ska ändå uppfylla Kids-nivån i praktiken om vi marknadsför till 7-åringar.

### 3.3 GDPR – barns samtycke
- Sverige: barn ≥13 år kan själva samtycka till informationssamhällets tjänster; under 13 krävs vårdnadshavares samtycke (dataskyddslagen 2018:218, 2 kap. 4 §) ([Chambers 2026](https://practiceguides.chambers.com/practice-guides/data-protection-privacy-2026/sweden)). Andra EU-länder har 13–16 år ([GDPR art. 8](https://www.gdprsummary.com/gdpr-definitions/article-8/)).
- IMY har en vägledning om barns rättigheter på digitala plattformar ([IMY](https://www.imy.se/globalassets/dokument/rapporter/the-rights-of-children-and-young-people-on-digital-platforms_accessible.pdf)).
- **Bedömning:** Enklast och säkrast = **inget konto, ingen samtyckesbaserad behandling**, lokal sparfil, ingen tredjepartsanalys. Då behövs inget föräldrasamtycke-flöde.

### 3.4 DSA art. 28 (skydd av minderåriga)
- Kommissionens riktlinjer (14 juli 2025) är formellt frivilliga men används som **måttstock** för efterlevnad ([EU-kommissionen](https://digital-strategy.ec.europa.eu/en/library/commission-publishes-guidelines-protection-minors), [Hunton](https://www.hunton.com/privacy-and-cybersecurity-law-blog/european-commission-issues-guidelines-on-the-protection-of-minors)).
- Innehåll: undvik monetisering som döljer verkligt värde (tokens, loot boxes), priser i nationell valuta, köp får inte krävas för kärnfunktioner i "gratis"-tjänster ([NatLawReview](https://natlawreview.com/article/european-commission-issues-guidelines-protection-minors)); streaks, push-notiser (särskilt nattetid) och autoplay **av som standard**; inga brådskesignaler; inga slumpbelöningar/knapphetsdesign som kan leda till överdrivet bruk; tidshanteringsverktyg ska erbjudas ([Lexology/HLC](https://www.lexology.com/library/detail.aspx?g=93b2f843-a50a-4d0a-bc90-966bbdb90ff2), [Knight-Georgetown](https://kgi.georgetown.edu/research-and-commentary/europe-unveils-new-evidence-based-guidelines-to-advance-safer-platform-design-for-minors/)).
- **Bedömning:** DSA art. 28 gäller "onlineplattformar". Ett rent singelspelarspel utan användarinnehåll är sannolikt **inte** en plattform – men lägger vi till chatt, UGC eller delade builds kan vi hamna inom. Riktlinjerna speglar dessutom vart konsumentskyddet (UCPD/DFA) är på väg, så vi följer dem ändå.

### 3.5 PEGI (nya kriterier från juni 2026)
- Betalslump (loot boxes, gacha, kortpaket, nycklar) ⇒ **minst PEGI 16**, upp till 18 om det är centralt ([Wccftech](https://wccftech.com/games-with-loot-boxes-now-get-pegi-16-rating-starting-june-2026-ea-sports-fc/), [Flux](https://www.fluxdigitalpolicy.com/fluxexplains/pegi-announcement-on-loot-box-age-ratings)).
- Tids- eller antalsbegränsade erbjudanden (t.ex. betalt battle pass med nedräkning) ⇒ **minst PEGI 12**; kan sänkas till **PEGI 7** om köp är avstängda som standard och förälder måste aktivt slå på dem ([Two Birds](https://mediawrites.twobirds.com/post/102mn2b/pegi-age-rating-classification-update), [PEGI-nyhet](https://pegi.info/news/pegi-expands-age-rating-criteria-interactive-risk-categories)).
- Login-streaks och betalda battle passes nämns bland de nya riskkategorierna ([Two Birds](https://mediawrites.twobirds.com/post/102mn2b/pegi-age-rating-classification-update)) – exakt åldersnivå **ej verifierad**, kontrollera mot pegi.info.
- NFT/blockkedja som krävs för spel ⇒ PEGI 18 (samma källa).
- **Obs:** Innehåll (våld, skräck) i dark fantasy kan i sig ge PEGI 12 – se till att chibi-stilen och icke-realistiskt våld håller oss på PEGI 7 (uppskattning; kräver innehållsgenomgång).

### 3.6 Loot box-lagstiftning
- **Belgien:** Spelkommissionen anser att betal-loot boxes är hasardspel ⇒ i praktiken förbud; dålig efterlevnad – 82 % av topp-100 iPhone-spel hade fortfarande loot boxes ([Xiao 2023, Collabra](https://online.ucpress.edu/collabra/article/9/1/57641/195100/Breaking-Ban-Belgium-s-Ineffective-Gambling-Law)).
- **Nederländerna:** Raad van State (mars 2022) fann att FIFA Ultimate Team-paket inte bröt mot spellagen ([Xiao & Declerck](https://journals.sagepub.com/doi/10.1089/glr2.2023.0020)); men ACM bötfällde Epic 1,1 MEUR för Fortnite (direkta köpuppmaningar + missvisande nedräkningstimers mot barn), fastställt av Rotterdams domstol jan 2026 ([NL Times](https://nltimes.nl/2026/01/14/rotterdam-court-upholds-eu11-million-fine-fortnite-developer-epic-games), [ACM](https://www.acm.nl/en/publications/acm-imposes-fine-epic-unfair-commercial-practices-aimed-children-fortnite-game)); grupptalan >100 MEUR pågår ([Aroged](https://www.aroged.com/2026/09/25/fortnite-dutch-class-action-seeks-damages-of-over-e100-million/)).
- **Sverige:** Spelmarknadsutredningen föreslog ingen särreglering ([SweClockers](https://www.sweclockers.com/nyhet/30976-utredning-om-spelmarknaden-foreslar-ingen-reglering-av-lootlador)); regeringen 2022 ville inte utvidga spellagen; riksdagen har efterfrågat åtgärder för minderåriga ([Riksdagen motion 2024/25:76](https://www.riksdagen.se/sv/dokument-och-lagar/dokument/motion/atgarder-mot-lootlador-och-andra-lotteriliknande_hc0276/)). Läget 2026 **oklart i våra källor** – bevaka.
- **EU:** CPC-nätverkets 7 "Key principles on in-game virtual currencies" (mars 2025): tydliga priser, inga dolda kostnader, hänsyn till barns sårbarhet ([EU-kommissionen](https://commission.europa.eu/news-and-media/news/european-commission-hosts-stakeholders-talks-application-cpc-networks-key-principles-games-virtual-2025-06-03_en), [Sheppard](https://www.sheppard.com/insights/blogs/eu-new-european-consumer-protection-guidelines-for-virtual-currencies-in-video-games)). **Digital Fairness Act** väntas Q4 2026; EP:s IMCO-utskott vill förbjuda loot boxes, in-app-valutor, pay-to-progress och pay-to-win i spel som minderåriga sannolikt använder ([Freshfields](https://technologyquotient.freshfields.com/post/102ltio/the-eus-proposed-digital-fairness-act-a-game-developers-guide-to-potential-imp), [Chambers](https://chambers.com/articles/digital-fairness-act-what-the-public-consultation-tells-the-video-game-industry)). Innehållet är ännu **inte beslutat**.

### 3.7 Konsumentverket / marknadsföring till barn
- Direkta köpuppmaningar till barn är **alltid förbjudna** (UCPD bilaga I p. 28); Konsumentverket tillämpar detta på uppmaningar att köpa virtuell valuta/föremål i spel ([Konsumentverket – marknadsföring till barn](https://www.konsumentverket.se/marknadsratt-foretag/marknadsforing-till-barn-regler-for-foretag/), [Lexology](https://www.lexology.com/library/detail.aspx?g=3be825cf-d1d0-4bf6-b883-ab5832801813)).
- Konsumentverket ledde (med norska motsvarigheten) CPC-åtgärden mot svenska **Star Stable** (mars 2025): köpuppmaningar till barn, tidspressade köp, prisdöljande valuta (Star Coins) ([Konsumentverket](https://www.konsumentverket.se/aktuellt/konsumentverket-agerar-for-att-skydda-barn-mot-otillborliga-affarsmetoder-i-onlinespel/), [EU-kommissionen IP/25/831](https://ec.europa.eu/commission/presscorner/api/files/document/print/en/ip_25_831/IP_25_831_EN.pdf)).

### 3.8 Konkret lista

**Förbjudet / mycket riskabelt för oss**
1. Köpbara slumpbelöningar (loot boxes, gacha, "mystery chests" för pengar eller premiumvaluta) – PEGI 16+, Belgien, DFA-risk, Star Stable-prejudikat.
2. Direkta köpuppmaningar ("Köp nu!", "Be mamma om...") – UCPD p. 28.
3. Nedräkningstimers/FOMO-erbjudanden, tidsbegränsade betalevent – ACM/Fortnite, CPC, PEGI 12.
4. Premiumvaluta som döljer verkligt pris – CPC-principerna, DSA-riktlinjerna.
5. Personaliserad reklam, IDFA/AAID, platsdata, icke-certifierade SDK:er – Google/Apple.
6. Konton/datainsamling från <13 år utan föräldrasamtycke – dataskyddslagen.
7. Pay-to-win / pay-to-progress – DFA-förslag, recensionsrisk.
8. Push-notiser som lockar tillbaka, streaks som nollställs – DSA-riktlinjer (av som standard), PEGI.
9. Konstgjorda near-misses och slot-maskin-presentation av belöningar – etiskt (Clark 2009), sannolikt "persuasive design" enligt DSA-riktlinjerna (uppskattning).
10. Öppen chatt med främlingar – Google juli 2026, DSA-standardinställningar.

**Ok**
1. Slumpmässiga loot drops från fiender/kistor som man *spelar* sig till.
2. Överraskningar: sällsynta "guldfiender", hemliga rum, oväntade bossvarianter.
3. Engångsköp av spelet eller expansioner med fast, tydligt innehåll, i kronor, bakom föräldraspärr.
4. Kosmetik med **känt innehåll** och fast pris (ingen slump, ingen valuta).
5. Dagliga/veckovisa mål **utan straff** vid missad dag.
6. Offline-spel, lokal sparfil, ingen analys eller endast egen, anonym, aggregerad telemetri (bedömning: verifiera mot Apple 1.3/Google Families).

---

## 4. Rekommendationer

### 4.1 Omformulering av beställarens mål
Byt "extremt svårt att lägga ifrån sig" mot **"barnet längtar tillbaka – och kan sluta när det är dags"**. Mät *återkomst över veckor* och *självrapporterad glädje*, inte sessionslängd. Detta är både lagligt hållbart och sannolikt bättre för varumärket (se Eternium vs. Torchlight: Infinite, §1).

### 4.2 Engagemangsmekaniker vi ska bygga (effektiva + hållbara)
| Mekanik | Varför den fungerar | Skyddsräcke |
|---|---|---|
| **Juice-tung strid** (hit-stop, partiklar, loot-"fontäner", ljud per sällsynthet) | Dopaminkick knuten till egen handling ([Jonasson & Purho](https://www.youtube.com/watch?v=Fy0aCDmgnxg)) | Tillgänglighetsläge: mindre skak/blink |
| **Slumpad loot från fiender** med tydliga sällsynthetsnivåer | Variabelt kvotschema i spelet, Diablo-kärnan ([Hopson](https://www.gamedeveloper.com/design/behavioral-game-design)) | Aldrig köpbar; "bad luck protection" (garanterad legendarisk efter X kills) |
| **3-val-förmågor per run** (Archero) | Autonomi + variation ([Game Developer](https://www.gamedeveloper.com/design/finding-the-fun-archero-part-1---gameplay)) | Visa valen direkt, inte som slot-hjul |
| **Korta runs/dungeons (5–10 min, uppskattning)** | Passar mobil; naturliga stopp-punkter | Slutskärm "Bra spelat! Bra ställe att pausa" |
| **Build-synergier & samlarbok (bestiarium, set-föremål)** | Kompetens + långsiktiga mål ([SDT](https://link.springer.com/article/10.1007/s11031-006-9051-8)) | Inga tidsbegränsade föremål |
| **Överraskningsögonblick** (guldgoblin-lik fiende, hemliga rum, sällsynt väder-event) | Oväntad positiv variation = "kick" utan pengar | Frekvens designad, inte personaliserad för att maximera speltid |
| **Vilad XP / "lägereld"** | Belönar pauser i stället för att straffa dem | Taket för bonusen nås efter ~1 dygn (uppskattning) |
| **Dagliga utmaningar utan straff** | Ger anledning att återvända | Ackumuleras (t.ex. 3 sparade), ingen streak-nollställning |
| **Lokal co-op / familjeläge** | Samhörighet ([SDT](https://link.springer.com/article/10.1007/s11031-006-9051-8)) | Ingen öppen chatt; ev. förinställda emotes |
| **Föräldrapanel** (speltidsgräns, köpspärr av som standard) | Förtroende hos köparen (föräldern) | Krävs för PEGI 7 om köp finns |

### 4.3 Mekaniker vi ska undvika (veto från Player Safety)
Loot boxes/gacha för pengar eller premiumvaluta · premiumvaluta överhuvudtaget · energi/stamina · FOMO-timers och tidsbegränsade butiksobjekt · battle pass med nedräkning · streaks som nollställs · push-notiser för återengagemang · near-miss/slot-hjul-UI · "revive för pengar/annons" mitt i en boss · rewarded ads riktade till barn · social skuld/klanplikter · personaliserad svårighet eller erbjudanden baserade på beteendedata.

### 4.4 Monetisering för 7+

| Alternativ | För | Emot | Rekommendation |
|---|---|---|---|
| **A. Premium (t.ex. 49–99 kr, uppskattning)** | Enklast juridiskt; inget köpflöde för barn; PEGI 7 möjligt | Lägre nedladdningar på mobil | **Förstahandsval** |
| **B. Gratis demo + engångsupplåsning ("free to start")** | Låg tröskel; en tydlig, prissatt transaktion | Kräver föräldraspärr; köp i appen ⇒ kontrollera PEGI-effekt | **Starkt alternativ** |
| **C. Premium + betalda expansioner (nya akter/klasser)** | Långsiktig intäkt, fast innehåll | Innehållskostnad | Komplement till A/B |
| **D. Kosmetiska paket med känt innehåll, pris i kronor** | Etiskt om utan slump/timer | Risk att glida mot "butikstryck"; köpflöde för barn | Möjligt senare, bakom föräldraspärr, inga banners i spelet |
| **E. Familjeabonnemang (Apple Arcade/Google Play Pass)** | Ingen IAP alls; plattformarna söker barnvänligt innehåll | Förhandling, intäktsdelning | Utred |
| F. Reklam (även certifierad) | Intäkt från gratisanvändare | Families-SDK-krav, dataskydd, dålig upplevelse | **Avråds** |
| G. F2P med valuta/gacha/pass | Högst intäkt i genren | Otillåtet enligt vår policy; PEGI 12–18; DFA-risk | **Nej** |

### 4.5 Nästa steg
1. Beslut hos beställaren om omformulerat mål (4.1) och affärsmodell A/B.
2. Verifiera PEGI-kriterier (streaks, dagliga belöningar) och Google Families-text direkt på pegi.info och support.google.com.
3. Player Safety skriver `arpg/docs/design/PLAYER_WELFARE.md` med listan i 3.8/4.3 som checklista.
4. Prototyp: juice + loot-sällsynthetsfeedback + 3-val-förmågor i en 5-minuters dungeon; mät "vill spela igen imorgon" hos testbarn (med föräldrasamtycke).

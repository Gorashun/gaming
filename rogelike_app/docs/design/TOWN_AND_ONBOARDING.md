# PIPWRECK – Staden och lärkurvan

*Författare: rpg-nerd-roguelike · 2026-09-21 · Status: **designförslag**, kräver Anders beslut på punkterna i §C innan dev bygger.*
*Utlöst av: speltest 1 (Anders, webb, 2026-09-21): "(1) spelet ska ha en stad att utgå ifrån, (2) det är svårt att fatta mekaniken." Se `docs/DECISIONS.md` sista raden.*

**Läsanvisning.** Del A (staden) är nytt innehåll och rör inte `GAME_DESIGN.md §2/§6`. Del B (lärkurvan) rör **inte heller** regelspecen: hela tutorialen byggs av *data* (bräden, tärningar, fiender, belöningar) plus *presentation*. Ingen normativ regel ändras. Det är avsiktligt – begriplighet ska aldrig lösas genom att göra spelet enklare.

All spelartext nedan står som **engelsk källsträng** i `backticks` med föreslagen i18n-nyckel, enligt `CLAUDE.md`. Svenskan är översättning.

---

## 0. Betyg på nuläget (webbversionen, M2)

Underlag: `docs/screenshots/m2/03_combat_before_confirm.png` och `04_combat_mid_chain.png`.

| Axel | Betyg | Motivering |
|---|---|---|
| **Roligt** | 7/10 | Kärnan bär. Överflödskedjan och multiplikatorerna är en riktig Balatro-motor, och `armor` per skadeinstans gör placeringen till ett faktiskt beslut (simulatorn: +45,3 p.e. lookahead över greedy, `GAME_DESIGN §4.9`). Det som saknas är inte mekanik utan *ceremoni*: ingen stad, inga NPC-röster, ingen anledning att gå ner. |
| **Djup** | 8/10 | Två pass före skadan (värde → kombo → slag) ger äkta emergens: Spegeln bygger kombon, Ambossen förstör dem. Det är Into the Breach-nivå av "reglerna är få och kombinerar oväntat". |
| **Läsbarhet** | **3/10** | Se §B.1. Spelet visar sitt facit men inte sin uträkning. En ny spelare kan inte härleda totalen från det som står på skärmen – jag kunde det inte heller förrän jag läste `resolver.gd`. Det är en 3:a, inte en 2:a, bara för att förhandsvisningen faktiskt är sann (helig regel 6). |
| **Replayability** | 5/10 | Bara en klass, ingen meta, ingen upplåsning, ingen Kodex. Det finns inget skäl att starta run 2 utom att man tyckte om run 1. Den siffran är förväntad i M2 och är exakt vad del A ska fixa. |

**Skoningslöst sammanfattat:** motorn är bättre än gränssnittet och gränssnittet är bättre än ramen. Vi har byggt ett bra spel som inte berättar för någon vad det gör, i en värld som inte finns.

---

# DEL A – STADEN

## A.1 Namn och ton

**Stadens namn:** `CHALKRIM` (sv **Kritkanten**). Nyckel `TOWN_NAME`.
**Gropen:** `THE PIT` (sv **Gropen**). **Mynningen:** `THE PIT MOUTH` (sv **Gropens mun**).

**Vad staden är, narrativt (en paragraf som får stå på laddskärmen):**

> Foundry Row rasade och tog turen med sig ner. Sedan dess rullar ingenting rätt på ytan: skulder faller ut fel, lotter går tomma, väder kommer i fel ordning. Ögonen – *pips* – ligger kvar där nere i skrotet. Kritkanten är ringen av skjul, tak och rostade kranar som byggts runt hålet av dem som inte kunde gå någon annanstans. Ingen här är en hjälte. Alla är skyldiga någon något.

**Kritmärkena (stadens bärande bild).** Hela kanten runt mynningen är täckt av kritstreck. Ett streck per person som gått ner. Kommer du upp suddar du ditt eget streck med tummen. Kommer du inte upp står det kvar.
Mekaniskt: **varje död lägger ett streck på Kritväggen, varje vunnen run suddar ett.** Det är hela vår dödsräknare, det kostar en `Line2D` och en räknare att implementera, och det är spelets enda monument.

**Ton (13+, inte 18+):** torr, sliten, respektlös. Galghumor, ingen gore, ingen sexualisering, ingen spelautomat-estetik (inga hjul, spakar eller "777" – `research/01 §E`, Apple 13+ tål *infrequent* simulated gambling, inte frekvent). Folk i Kritkanten pratar som folk på ett skrotupplag: kort, sarkastiskt, ibland oväntat vänligt. Tärningar är *arbetsredskap*, inte magi.

**Tre röster (NPC:er), inte fler i MVP:**

| NPC | Nyckel | Var | Funktion |
|---|---|---|---|
| **Hob**, smed, saknar två fingrar | `NPC_HOB` | Smedjan | Förklarar sidor och slots utan att vara en tutorial-pil. Den enda som är glad. |
| **Marrow**, kärrföraren | `NPC_MARROW` | Gropens mun | Möter dig när du dör. Säger en rad om *hur* du dog. Hades-modellen: berättelsen fortsätter för att du dog. |
| **Tallow**, som håller räkningen | `NPC_TALLOW` | Kritväggen | Kommenterar rekord och statistik. Bryr sig mer om siffrorna än om dig. |

**Marrows dödsrepliker är den viktigaste texten i spelet.** Regel: varje replik namnger *dödsorsaken* (vi har den redan i `player_died{killed_by}`) och lägger till en rad värld. 20 repliker i MVP, aldrig samma två gånger i rad.
Exempel (`DEATH_LINE_SLAGJAW_01`): `"Slagjaw again. It has all the time in the world and you had eleven minutes."`
(`DEATH_LINE_THORNS_01`): `"You hit a thorn imp four times. It hit you back four times. That is what four means."`

---

## A.2 Platser

Sex platser. Sju hade blivit en meny-labyrint.

| # | Plats | Nyckel | Funktion, exakt | Låses upp |
|---|---|---|---|---|
| 1 | **The Pit Mouth** (Gropens mun) | `PLACE_PIT_MOUTH` | Startar run. Visar seed, vald klass, valt djup. Marrow står här. **Alltid längst till höger i remsan** så "gå ner" är en riktning, inte en knapp i en meny. | Från start |
| 2 | **The Scrap Market** (Skrotmarknaden) | `PLACE_MARKET` | Spendera `Pips` på **horisontella upplåsningar**: nya sidor och reliker som läggs i *runens belöningspool*. Aldrig stats. 3–5 synliga varor åt gången, resten är kritsilhuetter med pris. | Efter run 1 |
| 3 | **The Tally Wall** (Kritväggen) | `PLACE_TALLY_WALL` | Kodex/arkiv: sedda kedjor, rekordskada, rekordmultiplikator, fiendeposter du mött, dödsorsaksstatistik, **fullständig regelreferens** (den enda platsen med lång text, pushas aldrig). Plus kritstrecken. | Efter run 1 |
| 4 | **The Notice Board** (Anslagstavlan) | `PLACE_NOTICE_BOARD` | 3 roterande kontrakt, t.ex. `"Win a room using exactly one die"`, `"Form a HOUSE"`, `"Kill three enemies with one slot"`. Klarat kontrakt = en upplåsning gratis. Senare hem för daglig utmaning (ligger i `BACKLOG.md`). | Efter run 3 |
| 5 | **The Snapped Tooth** (Brutna tanden, tavernan) | `PLACE_TAVERN` | Klassval. Låsta klasser står som **kritsilhuetter med sitt upplåsningsvillkor läsbart** (Balatro-modellen: du ser alltid vad som finns kvar och exakt hur du får det). Tre stolar, två tomma i början. | Efter run 5 *eller* när klass 2 finns i koden – det som kommer sist |
| 6 | **The Forge** (Smedjan) | `PLACE_FORGE` | **Loadout, inte uppgradering.** Två operationer: (a) *byt* en startsida mot en upplåst sida – alltid byte, aldrig tillägg; (b) *ordna om* dina fem slot-typer inbördes – samma typer, ny ordning. Hobs verkstad. | Efter run 6 |

**Smedjan – ställningstagande (svar på PM:s fråga "mellan runs eller bara i run?").**
Smide *under* runen stannar som det är (`FORGE_FACE`-belöningen). Smedjan i staden får **aldrig** lägga till kraft. Den får bara **byta** och **ordna om**. Skälet är inte fromhet, det är att byggdiversiteten dör annars: om man kan välja startsidor fritt väljer alla samma tre efter 20 runs och run-till-run-variationen kollapsar. Att ordna om slot-typerna är däremot en *enorm* spelstilsknapp utan en enda extra siffra – `[MIRROR, PLAIN, PLAIN, ANVIL, PLAIN]` spelar helt annorlunda än standardbrädet, för Spegeln på slot 0 fizzlar (`GAME_DESIGN §2.3`). Det är rep att hänga sig i, och det är precis vad OSR-publiken vill ha.

---

## A.3 Meta-loopen

**En valuta. Inte två.** `Pips` (sv **Ögon**), nyckel `CURRENCY_PIPS`. "Skrot" som andra valuta låter mysigt och skapar en meny-labyrint; vi säger nej.

**Intjäning (körs på `MetaScore`, som redan finns i `src/core/meta_score.gd`):**

| Källa | Pips |
|---|---|
| Rum rensat | 1 |
| Boss dödad | 3 |
| **Första gången** du ser en `QUAD` | 2 |
| **Första gången** du ser en `PENTA` | 3 |
| **Första gången** du ser `house_bonus` | 2 |
| **Första gången** du dödar ≥3 fiender med ett enda slot | 2 |
| Vunnen run | 5 |

En förlorad run på våning 1 ger 3–7 pips. En vinst ger ~20. **Förlust betalar alltid** (StS-modellen, `research/01 §A`), och "första gången"-bonusarna gör att en *spektakulär* förlust betalar bättre än en trist överlevnad. Det är rätt incitament: vi belönar att spelaren försökte något.

**Utgifter (Skrotmarknaden), fast prislista:**

| Vara | Pris | Effekt |
|---|---|---|
| Ny smidbar sida i poolen | 5 | +1 `FORGEABLE_FACES`-post i `reward_pool()` |
| Ny relik i poolen | 8 | +1 `RELICS`-post |
| Ny slot-typ i `SLOT_SWAP`-poolen | 10 | +1 `SLOT_SWAPS`-post |

**Gratis, låses av prestation (köps aldrig):** klasser, Gropens djup (ascension), Kodex-poster, kontrakt-belöningar, kosmetik.

**Den heliga regeln för metan:** *aldrig* en statsiffra. Ingen `+HP`, ingen `+skada`, ingen `+omkast`, ingen `+startcharge`. Bryter vi det blir vi Archero och `CLAUDE.md` säger nej (`research/01 §A`, Dead Cells-modellen: upplåsning = variation, inte makt).

**Takt de första 10 runsen (målet: något nytt var 1–2 run, `research/01 §C`):**

| Efter run | Nytt |
|---|---|
| 1 (tutorialrunen) | Staden öppnar. Marknad + Kritvägg. **En gratis sidupplåsning** (välj 1 av 3). |
| 2 | Första köpta sidan (5 pips räcker). Marrow får sin andra replikbank. |
| 3 | Anslagstavlan öppnar med 3 kontrakt. |
| 4 | Första reliken i poolen blir köpbar. Kontrakt 1 klart ≈ här. |
| 5 | Tavernan öppnar. Klass 2 syns som silhuett med villkor. |
| 6 | Smedjan öppnar (ordna om slots – största spelstilsändringen hittills). |
| 7–10 | En upplåsning per run ur startpoolen (12 st), plus kontrakt som ger de udda. |
| Första vinsten | Gropens djup 1 låses upp. |

Startpoolen ska vara **liten från början och växa i paket som byter spelstil**, inte droppa enstaka skräp – det är Dead Cells "awkward middle"-varningen i `research/01 §A`.

---

## A.4 Hur staden inte får döda "en run till"

Det här är den enda delen av del A som kan förstöra spelet. En hubb som är en menylabyrint bromsar exakt den impuls vi bygger hela spelet för, och det är en känd invändning mot hubb-strukturen – till och med Hades, som gör det bäst, kritiseras för att berättelsens tempo lider av att man *måste* tillbaka till huset varje gång ([GamingBolt, Hades review](https://gamingbolt.com/hades-review-there-and-back-again)).

**Sex regler, normativa för stadens UI:**

1. **`GO DOWN` är alltid synlig.** 56 dp, full bredd, botten, tumzonen, från första framen i staden. Nyckel `TOWN_GO_DOWN`, `"GO DOWN"` / sv `"GÅ NER"`. Den är aldrig inaktiv och aldrig bakom en dialog.
2. **Max två tapp från stadsingång till ny run.** `GO DOWN` → `CONFIRM`. Det är taket. Mäts i test.
3. **Menydjup = 1.** En plats öppnar *ett* kritpanel. Ett panel öppnar aldrig ett till. Vill vi ha en tredje nivå har vi designat fel.
4. **Tidsbudget 20–40 s.** En stadsbesök som tar > 40 s för en spelare som vet vad hen vill är en bugg. Dev mäter `town_dwell_ms` i telemetri-loggen lokalt (ingen backend).
5. **Nytt innehåll skriker, gammalt är tyst.** En plats med något nytt får en pulsande kritring + badge. Finns inget nytt någonstans hoppar kameran direkt till Gropens mun.
6. **Ingen timer, ingen daglig bonus, ingen inloggningsbelöning, ingen energimätare.** Någonsin. (`CLAUDE.md`.)

**Flödet efter död (Hades-modellen, ~15 s):**
Kärran skramlar in från höger → Marrow säger *en* rad om din dödsorsak → belöningsrutan flyger upp: `+6 PIPS` → om något låstes upp: en kritbadge tänds på rätt byggnad → `GO DOWN` är redan tryckbar. Spelaren får gå till badgen om hen vill. Hen *måste* aldrig.

---

## A.5 Presentation: staden i sidescroll-remsan

Staden är **samma marschremsa som mellan rummen** (`UI_GUIDE §10`), inte en ny skärmtyp. Det sparar en hel scen, återanvänder parallaxen, och gör att staden känns som den *översta* delen av samma värld i stället för en meny utanför spelet.

- **Lager (samma hastigheter som §10.2):** fjärran = kranarmar och skorstenar mot himlen; mellan = byggnadsfasaderna; mark = hjälten som går; förgrund = kritdamm och kabelstumpar.
- **Riktning:** staden scrollar **vänster → höger** mot mynningen. Gropens mun ligger alltid i högerkanten och lyser svagt. Att gå mot spelet är en fysisk riktning.
- **Skyltar:** byggnaderna är pixlar (substantiv), skyltar och priser är krita (verb) – `UI_GUIDE §8`, regeln hålls.
- **Interaktion:** tapp på en byggnad → hjälten går dit (max 600 ms, avbrytbar med ett nytt tapp) → kritpanelen glider upp från botten, 300 ms. Tapp utanför panelen stänger. Tapp på `GO DOWN` var som helst: hjälten springer höger, kritsvep, run startar.
- **Reducerad rörelse (`UI_GUIDE §6.1`):** ingen parallax, hjälten teleporterar till byggnaden, panelen fadear i stället för att glida. Tidslinjen ändras inte.
- **Ljud:** stadens ambience är den enda loopen i spelet – lågt vindbrus + avlägset metall, −24 dB. Den ska kontrastera mot Gropens torrhet.

---

## A.6 MVP-scope

**MVP (byggs nu, tre platser):**

1. `PLACE_PIT_MOUTH` – starta/fortsätt run, seed, Marrows dödsreplik (20 rader).
2. `PLACE_MARKET` – `Pips`, tre varutyper, fast prislista, 12 startupplåsningar.
3. `PLACE_TALLY_WALL` – kritstrecken, rekord, sedda fiender, regelreferens.

Motiv: de tre täcker hela meta-loopen (tjäna → spendera → se framsteg) och kräver inget innehåll som inte redan finns i `content.gd`. Tavernan utan en andra klass är ett tomt rum, och Smedjan utan upplåsta sidor är en tom bänk.

**Fullt (M3+):** Anslagstavlan, Tavernan, Smedjan, Gropens djup-väljare vid mynningen, fler NPC-repliker, kosmetiska stadsuppgraderingar som *syns i remsan* när man låser upp saker (Dead Cells "rummet som fylls" – fysisk känsla av framsteg, `research/01 §A`).

---

# DEL B – LÄRKURVAN

## B.1 Vad en ny spelare faktiskt inte förstår

Bevisföring från `docs/screenshots/m2/03_combat_before_confirm.png`. Jag räknar högt vad skärmen påstår:

```
slot 1 PLAIN   tärning 2 pip   "= 2"
slot 2 PLAIN   tärning 5 pip   "5 ×2"
slot 3 MIRROR  tärning 1 pip   "5 ×2"
slot 4 FIRE    tärning 6 pip   "= 6"
slot 5 ANVIL   tärning 6 pip   "= 12"
                               TOTALT: 28
```

**2 + 10 + 10 + 6 + 12 = 40. Skärmen säger 28.** Differensen är `armor 2` som dras av *per skadeinstans*, plus att överflödet armor-beskattas igen hos nästa råtta. Det är spelets djupaste och bästa regel och den är **helt osynlig**. En spelare som försöker räkna själv får fel svar och slutar räkna. Då är spelet slump.

Hela listan, rangordnad efter skada:

| # | Problem | Varför det dödar förståelsen |
|---|---|---|
| 1 | **Totalen går inte att härleda.** 40 på brädet, 28 på knappen. | Spelaren lär sig att siffrorna ljuger. Efter det läser hen dem inte. Värsta felet i spelet. |
| 2 | **Spegelsloten visar en 1:a och påstår 5.** | Ser ut som en bugg. Ingenstans står det att tärningens egna ögon kastas bort. |
| 3 | **Två olika grammatiker i samma rad:** `= 2` (resultat) och `5 ×2` (värde + multiplikator, produkten visas aldrig). | Spelaren kan inte veta om `5 ×2` betyder 5 eller 10. |
| 4 | **Ambossen visar `= 12` utan att visa 6:an den kom ifrån.** | Dubblingen är osynlig, alltså oförutsägbar, alltså inte ett verktyg. |
| 5 | **Kombon har ingen synlig källa.** Slot 2 och 3 har båda `×2` men inget ritat band mellan dem. | Multiplikator-klamrarna i `UI_GUIDE §4.4` är inte byggda (står i `BACKLOG.md` under M1). Utan dem är par ett mysterium. |
| 6 | **Eldsloten visar `= 6` och nämner inte Burn.** | Slot-typens hela poäng är osynlig i förhandsvisningen. |
| 7 | **`2 arm` på fiendekortet.** | Spelets viktigaste balansknapp, förkortad till tre tecken, utan att "per träff" nämns någonstans. |
| 8 | **Tärningar syns dubbelt.** Brickan visar sex tärningar med etiketten `IN 1`, `IN 2`, `IN 4`, `DRAG →`, `IN 5`, `IN 3` samtidigt som samma tärningar ligger i sloten ovanför. Texten säger `"6 dice in the tray"` när fem är placerade. | Spelaren vet inte vad hen har kvar. Källa: `translations.csv:61 DIE_IN_SLOT,IN %d`. |
| 9 | **`0/20`-pillret högst upp.** | Charge nämns aldrig. Regeln "oplacerade tärningar blir Charge" är osynlig tills den plötsligt lägger en bonus på en slot. |
| 10 | **Kedjeraden trunkeras:** `8 → Rust Rat 8 → Rust Rat 4 → Rust Rat …` | Ingen separator mellan träffar, oklart om talet är skada eller HP, och sista träffen syns inte. |

**Begrepp som måste läras, i exakt denna ordning (åtta st):**

1. Placera en tärning → bekräfta → skada.
2. Kedjan går vänster→höger, och skada över en fiendes HP **rullar vidare** (överflöd).
3. **Lika värden bredvid varandra multiplicerar** (2→×2, 3→×4, 4→×8, 5→×16).
4. **Rustning dras av per träff** – en stor träff slår fyra små.
5. **Spegel** kopierar värdet till vänster → du kan *tillverka* par.
6. **Oplacerade tärningar blir Charge**, som läggs på din vänstraste tärning nästa runda.
7. **Amboss** dubblar ≥5 – och kan därmed **bryta ditt par**.
8. Resten (Eld/Burn, Tomrum/Ward, omkast, fiendens intent och specials) – lärs av belöningskort och av intent-raden, aldrig av en tutorial.

Regel: **en ny idé per rum. Ingen idé introduceras förrän den föregående har använts minst en gång.**

---

## B.2 Första runen: `THE SHALLOW CUT` (Grundstigen)

En handskriven **våning 0** på sju rum, seedad och fast, som spelas **exakt en gång** (spara-flagga `tutorial_done`). Därefter är våning 1 precis som specad i `GAME_DESIGN §1`. Inga regler ändras – bara data.

**Progressiv avslöjning, normativ för tutorialrunen:** UI-element som ännu inte lärts är **frånvarande**, inte nedtonade. En nedtonad knapp är en fråga; en frånvarande knapp är ingen fråga alls. Varje element kommer in med en 220 ms kritstreck-animation så att spelaren ser att skärmen *växte*.

**Träningshjulsregeln, uttalad för spelaren:** i våning 0 kan man inte dö. Skulle HP nå 0 kommer Marrow med kärran, rummet startas om från samma seed, och texten säger rakt ut:
`TUTORIAL_CART_LINE` = `"The cart still comes for you down here. After this, it doesn't."` (sv `"Här uppe kommer kärran fortfarande. Efter det här gör den inte det."`)
Att ljuga om det vore värre än att dö.

### Rum-för-rum

| Rum | Ny idé | Bräde vid start | Tärningar | Fiender | Synligt UI som tillkommer | Belöning efteråt (fast, inte 1 av 3) |
|---|---|---|---|---|---|---|
| **0.1** | Placera + bekräfta = skada | `3 × PLAIN` | 3 | `CHALK_DUMMY` hp 12, armor 0, intent `ATTACK 0` runda 1, sedan `ATTACK 2` | Slots, bricka, total, `CONFIRM` | – |
| **0.2** | Överflöd | `3 × PLAIN` | 3 (seed ger 6, 4, 2) | `RUST_MITE` hp 3 fram, `RUST_MITE` hp 9 bak, båda `ATTACK 2` | Överflödspilen mellan fiendekorten + per-mål-raden | **+1 slot** → `4 × PLAIN` |
| **0.3** | Par = ×2 | `4 × PLAIN` | 4 (seed ger 5, 5, 2, 1) | `SLAG_PUP` hp 24, armor 0, `ATTACK 8` | Multiplikator-klammern under två lika grannar, **live medan man drar** | **+1 slot** → `5 × PLAIN` |
| **0.4** | Rustning per träff | `5 × PLAIN` | 5 (seed ger 3, 3, 5, 5, 1) | `TICK_PUP` hp 26, **armor 3**, `ATTACK 4` | `− arm 3`-kolumnen i kvittot (§B.3) + rustningsikonen på fiendekortet | `SLOT_SWAP` → **MIRROR på slot 3** (enda valet, kortet förklarar) |
| **0.5** | Spegel | `P, P, MIRROR, P, P` | 5 (seed ger **inget naturligt par**) | `SLAG_MOTH` hp 34, armor 1, `ATTACK 4` | Kopieringspilen från vänstergrannen in i Spegeln | **Omkast** låses upp (`REROLL 1`) |
| **0.6** | Oplacerade tärningar → Charge | samma | **6** (den sjätte tärningen ges här) | `SCRAP_GATE` hp 44, armor 8, `BLOCK +4` runda 1–2, sedan `ATTACK 6` | Charge-pillret + kritpilen från den oplacerade tärningen till pillret | `SLOT_SWAP` → **ANVIL på slot 5** (enda valet) |
| **0.7** | Amboss dubblar ≥5 – och bryter par | `P, P, MIRROR, P, ANVIL` | 6 | **BOSS** `SLAGJAW'S RUNT` hp 110, armor 2, `ATTACK 6`, `HARDEN +4` var tredje runda | Boss-intro (finns i M2) | Run slut → **staden öppnar** |

**Varför just den här ordningen:**

- **0.1 kan inte gå fel.** Dummyn attackerar inte första rundan. Det enda misstaget som är möjligt är att inte göra något, och då står tooltipen kvar.
- **0.2 tvingar fram överflödet utan att säga det.** Framråttan har 3 HP. Vilken tärning som helst dödar den. Överskottet *måste* gå någonstans, och pilen visar vart. Lärdomen kommer av handling, inte av text.
- **0.3 gör paret till enda vägen.** 4 tärningar utan par ≤ 13 skada; med paret 23. Fienden har 24 HP och slår för 8. Utan paret tar man två träffar, med paret en. Spelaren straffas mjukt men känner det.
- **0.4 lär rustning genom aritmetik som syns.** Två par i handen (3,3 och 5,5) mot `armor 3`: `5×2 − 3 = 7` per träff är bra, `1 − 3 = 0` är ett slag som gör **ingenting**. Det är första gången spelaren ser en nolla, och kvittot förklarar varför.
- **0.5 låter tärningskastet göra jobbet.** Seeden ger sex olika värden. Det finns inget par att hitta. Spegeln är enda sättet att göra ett, och en kritpil pekar på den med `TUTORIAL_TRY_MIRROR` = `"Put any die here. Watch what it copies."`
- **0.6 gör bankandet till det rationella draget.** Porten har `armor 8` och blockar två rundor. Varje enskild tärning studsar. Det enda vettiga är att inte placera – och då dyker Charge-pillret upp med en förklaring som spelaren *redan har efterfrågat med sitt eget spel*. Det här är rummet jag är mest nöjd med.
- **0.7 lär fällan, inte verktyget.** Bossen har `armor 2` så Ambossen är frestande. Första gången spelaren lägger en 6:a i Ambossen bredvid en annan 6:a försvinner klammern **live medan tärningen fortfarande hänger i fingret**, och en kritnotis säger `TUTORIAL_ANVIL_BREAKS` = `"12 and 6 are not a pair."` Spelaren kan ångra utan kostnad. Det är skillnaden mellan Into the Breach och Darkest Dungeon: visa fällan innan den smäller, låt spelaren gå i den ändå.

**Tooltips: max en per rum, max en mening, försvinner vid handling.** Det ersätter `UI_GUIDE §7` (tre tooltips i första striden) och är förenligt med dess filosofi – det är samma "lightweight, almost invisible" ansats som Balatros titelkort, som är den enda onboarding-modellen i genren som konsekvent hyllas ([GamesHub om Balatro](https://www.gameshub.com/news/features/balatro-roguelike-deckbuilder-2637397/)).

| Rum | Nyckel | Källsträng | Svenska |
|---|---|---|---|
| 0.1 | `TUT_01_PLACE` | `"Drag a die into a slot. The button shows the damage."` | `"Dra en tärning till en ruta. Knappen visar skadan."` |
| 0.2 | `TUT_02_OVERFLOW` | `"Damage left over rolls on to the next enemy."` | `"Skada som blir över rullar vidare till nästa fiende."` |
| 0.3 | `TUT_03_PAIR` | `"Equal values side by side: ×2. Three in a row: ×4."` | `"Lika värden bredvid varandra: ×2. Tre i rad: ×4."` |
| 0.4 | `TUT_04_ARMOR` | `"Armor is subtracted from every hit. One big hit beats four small."` | `"Rustning dras av från varje träff. En stor träff slår fyra små."` |
| 0.5 | `TUT_05_MIRROR` | `"Mirror copies the value on its left. Its own pips do nothing."` | `"Spegeln kopierar värdet till vänster. Dess egna ögon gör inget."` |
| 0.6 | `TUT_06_CHARGE` | `"Dice you don't place go in the bank."` | `"Tärningar du inte placerar hamnar i banken."` |
| 0.7 | `TUT_07_ANVIL` | `"Anvil doubles 5 or more. A doubled 6 no longer pairs with a 6."` | `"Ambossen dubblar 5 eller mer. En dubblad 6:a parar sig inte längre med en 6:a."` |

---

## B.3 "Varför fick jag 28?" – kvittot

Ersätt den ensamma stora siffran med något en människa kan addera. Tre nivåer, alla tre alltid sanna (helig regel: förhandsvisningen **är** utfallet, `GAME_DESIGN §6`).

### Nivå 1 – per slot, alltid synlig

En rad liten krita under varje tärning, **alltid i formen `bas → modifierare → bidrag`**. Aldrig `= x` utan härkomst.

```
slot 1 PLAIN    2            → 2
slot 2 PLAIN    5   ×2       → 10
slot 3 MIRROR   ←5  ×2       → 10
slot 4 FIRE     6   +burn 2  → 6
slot 5 ANVIL    6   ⬣×2      → 12
```

- `←5` med en ritad kritpil till vänstergrannen. Spegelns egen tärning ritas **halvgenomskinlig** – den betyder ingenting och ska se ut så.
- `⬣×2` (Amboss) och `×2` (kombo) är **olika symboler och olika färger** (`Tokens` har redan `SEM_*`), eftersom de är olika saker som råkar ha samma siffra. Färgblindsäkerhet: formen skiljer, inte bara färgen (`UI_GUIDE §2.4`).
- Kombon ritas som **en klammer under de slots som ingår**, med multiplikatorn i mitten. Det är `UI_GUIDE §4.4` som redan är specad men inte byggd. Den är inte valfri – utan den är punkt 5 i §B.1 olöst.

### Nivå 2 – kedjekvittot, hopfällt till två rader, expanderas med ett tapp

```
                    28  DAMAGE
              40 rolled − 12 armor            ← alltid synlig andra rad
─────────────────────────────────────────  ← tapp expanderar
 1   2  − arm 2  =  0
 2  10  − arm 2  =  8   Rust Rat  28→20
 3  10  − arm 2  =  8   Rust Rat  20→12
 4   6  − arm 2  =  4   Rust Rat  12→ 8   ▲burn 2
 5  12  − arm 2  = 10   Rust Rat   8→ 0  ✕
         ↳ 2 over − arm 2 =  0   Rust Rat  28
─────────────────────────────────────────
                 TOTAL     28
```

**Raden `40 rolled − 12 armor` är den enskilt viktigaste ändringen i hela det här dokumentet.** Den kostar en `Label` och den är skillnaden mellan "spelet är slump" och "jag förstår vad som hände". Är `armor`-avdraget 0 visas raden inte alls.

Expansionen sker **på plats** (panelen växer, listan scrollar), aldrig i en modal – en modal mellan spelaren och bekräfta-knappen är ett tempomord.

### Nivå 3 – uppspelningen (finns redan i M2, behöver en rättelse)

Under kedjan poppar redan `ARMOR 2` som siffra (syns i `04_combat_mid_chain.png`). Behåll, men flytta poppen så att den står **vid fiendekortet**, inte över halva skärmen, och låt raden i kvittot lysa upp synkront med `damage_dealt`. Då binds förhandsvisning och uppspelning ihop till samma berättelse.

### Följdändringar

- `CONFIRM CHAIN · 28` → `CONFIRM · 28 DAMAGE` (`COMBAT_CONFIRM_CHAIN` = `"CONFIRM · %d DAMAGE"`). Siffran på knappen och `TOTAL` i kvittot måste vara samma tal, alltid, och det ska vara uppenbart att de är det.
- `"6 dice in the tray"` → `"%d dice left"` (`COMBAT_DICE_LEFT`), räknar **oplacerade** tärningar.
- Placerade tärningar ska **inte** ligga kvar i brickan som fullstora tärningar med `IN 3`. De lämnar brickan och efterlämnar en tom kritkontur. `DIE_IN_SLOT` kan då tas bort helt ur `translations.csv`.
- Kedjeraden `8 → Rust Rat 8 → Rust Rat 4 → Rust Rat …` ersätts av kvittot och tas bort. Ingen trunkering någonstans i stridens sifferlager.

---

## B.4 Långtryck på en slot: en mening + ett exempel

350 ms långtryck (samma gest som "plocka tillbaka tärning" i `UI_GUIDE §4.3` – den gesten flyttas till långtryck på *tärningen*, långtryck på *sloten* ger hjälp). Kritlapp, en mening, ett exempel, stängs av vad som helst.

| Slot | Nyckel | Källsträng |
|---|---|---|
| PLAIN | `HELP_SLOT_PLAIN` | `"No effect. The value counts as it is. A 4 deals 4."` |
| MIRROR | `HELP_SLOT_MIRROR` | `"Copies the value on its left; its own pips are ignored. Left slot shows 5, so this counts as 5 too — and that's a pair: ×2."` |
| ANVIL | `HELP_SLOT_ANVIL` | `"Doubles a value of 5 or more. A 6 becomes 12 — which no longer pairs with a 6."` |
| FIRE | `HELP_SLOT_FIRE` | `"Every hit from here adds Burn 2. Burn deals its number at the end of each round, then drops by 1."` |
| CHARGE | `HELP_SLOT_CHARGE` | `"Damage from here goes to the bank instead of the enemy. 8 damage becomes 8 in the bank."` |
| VOID | `HELP_SLOT_VOID` | `"Damage from here becomes Ward. Ward soaks the enemy attack this round, then it's gone."` |

Samma gest på andra element:

| Element | Nyckel | Källsträng |
|---|---|---|
| Rustning på fiendekort | `HELP_ARMOR` | `"Subtracted from each hit separately. Four hits of 5 against armor 2 deal 12. One hit of 20 deals 18."` |
| Charge-pillret | `HELP_CHARGE_POOL` | `"Dice you don't place go in the bank. Next round the whole bank is added to your leftmost die."` |
| Ward-pillret | `HELP_WARD` | `"Soaks damage this round only. It does not carry over."` |
| Intent-raden | `HELP_INTENT` | `"What the enemy will do after your chain. It never changes after you see it."` |

Den sista är viktigare än den ser ut. Att säga rakt ut att intent inte ändras är hur vi *säljer* den heliga regeln till spelaren.

---

## B.5 Spelets idé i en mening

På titelskärmen, under logotypen, och på kritskylten vid Gropens mun:

**`ROLL SIX. PLACE FIVE. THE ORDER IS THE DAMAGE.`**
sv: **`KASTA SEX. LÄGG FEM. ORDNINGEN ÄR SKADAN.`**
Nyckel: `TAGLINE`.

Andra raden, bara vid mynningen (mindre, `TAGLINE_SUB`):
`"Equal neighbours multiply."` / `"Lika grannar multiplicerar."`

Motiv: den namnger input (sex), beslutet (fem, alltså ett urval) och att *ordningen* är det som räknas – vilket är den enda sak som skiljer oss från Luck be a Landlord. Ingen metafor, inga adjektiv, inget "epic".

---

## B.6 Begriplighetstestet

**Metod.** 5 personer som aldrig sett spelet. Ingen hjälp, ingen förklaring, telefon i handen. Testledaren avbryter efter rum 0.3 och efter rum 0.7 och ställer frågorna muntligt. Svar antecknas ordagrant.

**Efter rum 0.3 (godkänt: 4 av 5 rätt på samtliga):**

| # | Fråga | Godkänt svar |
|---|---|---|
| 1 | Hur gör du skada? | Lägger tärningar i rutor och bekräftar |
| 2 | Spelar det roll i vilken ordning de ligger? | Ja – vänster till höger; överskott rullar vidare till nästa fiende |
| 3 | Hur får du ×2? | Två lika värden bredvid varandra |
| 4 | Hur skulle du få ×4? | Tre lika i rad |
| 5 | Visa mig var totalen kommer ifrån. | Pekar på kvittot och läser minst två rader |

**Efter rum 0.7 (godkänt: 4 av 5 på samtliga):**

| # | Fråga | Godkänt svar |
|---|---|---|
| 6 | Vad gör Spegeln? | Kopierar värdet till vänster; den används för att skapa par |
| 7 | Varför skulle du låta bli att placera en tärning? | Den går till banken/Charge och läggs på nästa runda |
| 8 | Vad är nackdelen med Ambossen? | Den ändrar värdet och kan förstöra ett par |
| 9 | Varför gjorde det slaget bara 4 när tärningen visade 6? | Rustning drogs av |
| 10 | Kan kedjan bli annorlunda än förhandsvisningen? | Nej |

**Fråga 10 är en kvalitetsgrind, inte en förståelsefråga.** Svarar någon "vet inte" har vi misslyckats med att kommunicera vårt viktigaste löfte.

**Automatiska proxymått (loggas lokalt, ingen backend):** `rooms_to_first_intentional_pair` (mål ≤ 3), antal `CONFIRM` med noll placerade tärningar (mål 0 efter rum 0.1), antal `UNDO` per runda i rum 0.7 (mål ≥ 1 – ångrar man aldrig experimenterar man inte), och `tutorial_abandon_room` (vilket rum folk stänger appen i).

---

## C. Vad som kräver Anders beslut

| # | Fråga | Mitt förslag | Konsekvens om nej |
|---|---|---|---|
| 1 | Bygger vi en **tutorialvåning 0** på sju rum som spelas en gång, eller löser vi begripligheten enbart med UI? | **Bygg våning 0.** UI ensamt räcker inte – punkt 1–10 i §B.1 är till hälften pedagogik, inte layout. | Vi behåller `UI_GUIDE §7`:s tre tooltips och accepterar en brantare första timme. |
| 2 | Får **Smedjan i staden** byta startsidor och ordna om slots mellan runs? | **Ja, men bara byte och omordning. Aldrig tillägg.** | Smedjan blir ren kosmetik eller stryks ur MVP. |
| 3 | **Staden före eller efter M3-innehåll?** | **Begripligheten (del B) före allt. Stadens MVP direkt därefter, före nya klasser.** Ett spel som inte förstås behöver inte mer innehåll. | M3-innehåll först, och vi testar på nästa speltest om problemet löste sig av sig självt. (Det gör det inte.) |
| 4 | **En valuta (`Pips`) eller två (pips + skrot)?** | **En.** Två valutor är en menylabyrint och köper oss ingenting. | Två valutor kräver en till skärm och en till prislista. |
| 5 | Träningshjulen i våning 0: **kan man dö där?** | **Nej, och vi säger det rakt ut.** | Man kan dö, och vi riskerar att tappa spelaren i rum 0.4. |
| 6 | Namnet **`CHALKRIM` / Kritkanten** och kritstrecks-dödsräknaren. | Ja. | Behöver alternativ innan dev bygger skyltarna. |

---

## Källor (hämtade 2026-09-21)

- GamingBolt, *Hades Review – There and Back Again* (hubbens tempokostnad): https://gamingbolt.com/hades-review-there-and-back-again
- GameRant, *Hades 2 Needs a Hub as Rich as the First Game's House of Hades*: https://gamerant.com/hades-2-underworld-house-hub-area-relaxation-character-relationships-customization/
- TheGamer, *Hades 2 Has A Hub World That I Never Want To Leave* (NPC-repliker som meta-belöning): https://www.thegamer.com/hades-2-hub-world-characters-story-mechanics/
- GamesHub, *Balatro is pushing the roguelike deckbuilder to new territory* ("lightweight and almost invisible tutorial system"): https://www.gameshub.com/news/features/balatro-roguelike-deckbuilder-2637397/
- Steam Community, *A New Player's Primer to Balatro* (att communityt skriver egna primers är i sig ett mått på onboarding-glapp): https://steamcommunity.com/sharedfiles/filedetails/?id=3166946815
- ResetEra, *Games with this specific structure (free-movement hub + roguelike nodes)* (spelare som vill hoppa förbi hubben): https://www.resetera.com/threads/games-with-this-specific-structure-free-movement-hub-roguelike-nodes.1021917/
- Internt: `docs/research/01_engagement_mekanik.md` §A/§C (Hades-hubb, Dead Cells-poolmodell, unlock-takt), `docs/research/03_koncept_och_community.md` §5 (fem saker som får communityt att hata spelet), `docs/GAME_DESIGN.md` §2/§4/§6, `docs/UI_GUIDE.md` §3/§4.4/§7/§10.

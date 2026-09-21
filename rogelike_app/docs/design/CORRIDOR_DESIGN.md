# PIPWRECK – Korridoren: förstapersonspresentation

*Författare: rpg-nerd-roguelike · 2026-09-21 · Status: **designspec för M5**, normativ för spelkänsla och innehåll, förslag för teknik.*
*Utlöst av `docs/DECISIONS.md` sista raden (2026-09-21): presentationsskifte till old school first-person dungeon crawler. Tekniken utreds parallellt i `docs/research/05_fps_korridor.md` (R&D). Det här dokumentet äger **vad som ska kännas**, inte hur det renderas.*

**Vad som INTE ändras:** `GAME_DESIGN.md §2` (regelspec), `§6` (heliga regeln), resolvern, `run_graph.gd` som datamodell, tutorialvåning 0:s *innehåll* (`TOWN_AND_ONBOARDING.md §B`), stadens funktioner, smedjan, könsvalet. Korridoren är ett **presentationslager ovanpå grafen**. Core får inte veta att den finns.

**Ägarskap:** §1–§3 och §6–§7 är mina (spelkänsla, innehåll). §4 delas med UI (layout). §5 ersätter `TOWN_AND_ONBOARDING.md §A.5` (sidescroll-remsan) — resten av del A står kvar oförändrad.

---

## 1. Vad genren lovar, och vad vi måste leverera

### 1.1 Vad fansen faktiskt älskar

Genren (Dungeon Master 1987 → Eye of the Beholder → Wizardry → Etrian Odyssey → Grimrock → *Vampire Crawlers* 2026) säljer **fem** saker. Jag rangordnar dem efter hur mycket de bär upplevelsen:

| # | Löfte | Vad källorna säger | Vad det kostar oss |
|---|---|---|---|
| 1 | **Mörkret och vad som står i det** | Grimrock säljs uttryckligen på "oldschool challenge … deadly traps and horrible monsters" och ett rutnät "riddled with hidden switches and secrets" ([Steam-butikssidan](https://store.steampowered.com/app/207170/Legend_of_Grimrock/), läst 2026-09-21) | Billigt. Mörker är frånvaro av ritning. |
| 2 | **Utforskningslusten: "varje skrymsle"** | "The appeal of these dungeon crawlers lies in exploration … Grimrock successfully tickles that desire to find every nook, cranny, and secret on each level" ([dungeoncrawlers.org](https://www.dungeoncrawlers.org/game/legend-of-grimrock/), läst 2026-09-21) | Måttligt: kräver återvändsgränder och hemligheter som är *värda* omvägen. |
| 3 | **Kartkänslan** | Etrian Odyssey bygger hela sin identitet på att spelaren ritar kartan själv, och periodiska warp-punkter gör en korrekt karta nödvändig ([Wikipedia: Etrian Odyssey](https://en.wikipedia.org/wiki/Etrian_Odyssey_(video_game)), läst 2026-09-21) | **Dyrt.** Se §1.3 – vi köper känslan, inte aktiviteten. |
| 4 | **Stegets fysik** | Rutbaserad rörelse gör varje steg till ett *beslut* med en kostnad, inte till en analog förflyttning | Gratis, och det är vår största vinst: ett steg = ett tapp = mobilvänligt. |
| 5 | **Blobber + turbaserat funkar 2026** | *Vampire Crawlers* (poncle, full release 2026-04-21) är en förstapersons-blobber med turbaserad kortstrid och roguelite-struktur, och togs emot väl: "easy to pick up and play, but brimming with depth" ([Windows Central-recension](https://www.windowscentral.com/gaming/xbox/vampire-crawlers-review), [Game Informer](https://gameinformer.com/review/vampire-crawlers/dazzling-dungeons), lästa 2026-09-21) | Bevisbördan är lyft. Exakt vår form – förstaperson utanför striden, brädspel inuti – har precis validerats kommersiellt av Vampire Survivors-studion. |

**Detta är den viktigaste raden i dokumentet:** punkt 5 betyder att Anders instinkt inte är nostalgi, den är marknadsläsning. Vi gör inte något udda. Vi gör det som 2026 visade fungerar, i mobilformat.

### 1.2 Vad som funkar i en 5–15-minutersrun på mobil

`research/01 §C`: median mobilsession 3,1–3,5 min, topp-10 % ≈ 8 min; ett belöningsval var 60–90 s. Konsekvenser, normativa:

- **Korridoren är aldrig innehållet. Den är sluttningen upp till innehållet.** Budget: hela runnens korridortid ≤ **90 sekunder** av 15 minuter (≈ 10 %). Per rumsövergång **4–8 s**.
- **Ett tapp = ett steg = en ruta.** Ingen swipe, ingen joystick, ingen precision (`research/01 §D`: vinnarna har "max ett beslut per tryck, ingen precisionsinput").
- **Treställningsregeln:** max 3 steg i rad utan händelse. En händelse är: en skylt, ett ljud, ett hörn med sikt som ändras, en silhuett, ett val. Fyra steg genom tom korridor på en telefon är en avinstallation.
- **Pausbart var som helst.** Autosave per ruta, inte per rum. Att kliva ett steg är en transaktion.
- **Ingen backtracking.** Se §1.3.

### 1.3 Vad vi INTE gör, och varför

| Nej till | Motivering |
|---|---|
| **Tryckplattor och ställ-sten-på-knapp-pussel** | Det är genrens mest kritiserade del. Spelare "grew sick of the same pressure plate and hidden button puzzles, and grew frustrated every time they needed to backtrack to find another rock or torch" ([Michael Iantorno, Grimrock-recension](https://michaeliantorno.com/legend-of-grimrock-review/), läst 2026-09-21). Ett pussel som tar 90 s äter hela vår korridorbudget för en run. |
| **Realtidsstrid** | Bryter `§6` (kedjan visas före bekräftelse) och `research/01 §D` (ingen precisionsinput). Striden är oförändrad: brädet, tärningarna, förhandsvisningen. |
| **Handritad karta / stor kartskärm** | Etrian-kartritning är 5 minuter per våning. Vår run är 15 minuter totalt. Vi köper kartkänslan med **kritstråket** (§2.6) och **runkartan som trofé** (§2.7) i stället. |
| **Söka hemligheter genom att peta på väggar** | Wizardry/EOB-fansen tolererar det; mobilspelare gör inte det, och det är en osynlig tidsskatt. Vi **belönar att märka, inte att skrubba** (§2.5). |
| **Att gå bakåt / labyrinter** | Se §3.4. Framåt är beslutet. |
| **Inventarie-Tetris, fackeltimer, matsvält, vikt** | Alla fyra är genretradition och alla fyra är resursbokföring utan beslut i ett 15-minutersformat. |
| **Ljuskälla som resurs** | Frestande (mörker = spänning) men det gör mörkret till en mätare i stället för till en stämning. Mörkret är gratis och konstant. |

---

## 2. Kartgrammatik: från `run_graph` till korridor

### 2.1 Grundprincip

`RunGraph` är sanningen om **vad som väntar**. Korridoren är sanningen om **hur det känns att gå dit**. Den enda kopplingen är:

```
nod            → ett rum (en kammare i änden av en korridor)
kant (next)    → en korridor på 3–6 rutor, 0–2 hörn
is_branch()    → en T-korsning med skyltar
is_boss()      → en dörr, inte en öppning
```

Ingen ny data i `src/core/`. Korridorens form genereras i presentationslagret ur **samma seed** och nodens id — samma seed ⇒ samma korridor, vilket är ett `§6`-krav (seeden visas i pausmenyn och måste ge identisk run).

### 2.2 Kantlängd och hörn (normativt)

Hörn kostar **noll steg** men ~220 ms och all sikt. Det är gratis spänning: en korridor med två hörn känns dubbelt så lång och tre gånger så farlig som en rak av samma längd. Använd hörn i stället för steg.

| Kant | Steg | Hörn | Avsikt |
|---|---|---|---|
| Start → rum 1 | **3** | 1 | Lärkanten. Kort, ett hörn så spelaren lär sig att sikten ändras. |
| Rum 1 → 2 | **4** | 1 | Normal. |
| Rum 2 → T-korsning | **4** | 2 | Bygger upp till valet. Skylten syns först efter sista hörnet. |
| T-korsning → rum 3 | **3** | 0 | Rak. Du har valt; nu går du mot konsekvensen och ser den komma. |
| Rum 3 → bossdörr | **5** | 0 | **Den tysta sträckan.** Se §2.4. Bossdörren är synlig från steg 1 och växer. |
| Bossrum → trappa | **2** | 0 | Nedstigning. |

Total per våning: 21 steg. Tre våningar ≈ 63 steg. Vid 260 ms per steg plus tapp-latens ≈ 75–85 s. **Inom budget på 90 s.** Detta är den siffra som ska mätas i M5, inte gissas.

**Steg-input:** tre knappar i tumzonen, botten: `◀ VÄND` · `▲ FRAM` · `VÄND ▶`. Att hålla `▲` auto-repeterar var 220:e ms. Vändning är ett tapp, 220 ms, kostar inget steg. Att vända sig om helt = två tapp (och är tillåtet — se §3.4 om vad det *inte* ger dig).

### 2.3 T-korsningen: skyltar och max tre val

Vid en T-korsning står spelaren still och ser tre mynningar: vänster, rakt, höger. Över varje mynning finns en **kritskylt** — samma krit-grammatik som resten av spelet (`UI_GUIDE §8`: pixelobjekt = substantiv, krita = verb).

| Glyf | Betydelse | Nyckel | Finns i |
|---|---|---|---|
| **Svärd** | `COMBAT` | `SIGN_COMBAT` | M5 |
| **Krona** | Elitmöte (hårdare variant, bättre belöning) | `SIGN_ELITE` | M5 (som skylt), innehåll i M3 |
| **Eld** | Vila / lägereld | `SIGN_REST` | M3 |
| **Våg** | Marknad i gropen | `SIGN_MARKET` | M3 |
| **Tärning** | Ödeskast (`FATE_ROLL`) | `SIGN_FATE` | M3 (`DECISIONS`: inte före M3) |
| **?** | Okänt | `SIGN_UNKNOWN` | M5 |
| **Dörr med käftar** | Boss | `SIGN_BOSS` | M5 |

**Regler (normativa):**

1. **Max 3 val, minst 2.** En korsning med ett val är en korridor och ska ritas som en korridor.
2. **Skylten ljuger aldrig.** Svärd betyder strid. `?` betyder att vi *inte visat* vad det är, inte att vi får byta åsikt efteråt. Det är `§6` applicerad på kartan.
3. **Exakt ett `?` per våning.** Mer än ett och skyltarna slutar betyda något; noll och det finns ingen nyfikenhet.
4. **`run_graph` ger två stridsgrenar** (rum 3 har två specade möten, `GAME_DESIGN §4.4`). De renderas som **vänster** och **höger**. `branch_index 0` = vänster. Det tredje valet, **rakt fram**, är när det finns en **återvändsgränd** (§2.5) — aldrig en strid, aldrig en genväg. Att gå rakt fram och tillbaka kostar 4 steg och ingenting annat.
5. **Ingen gren får hoppa över en strid.** Grafen garanterar `reaches_boss()` för alla noder; korridoren får inte skapa en väg som grafen inte har.

### 2.4 Tempo-grammatiken: tyst, tyst, *smäll*

Det här är hela poängen med presentationsskiftet, och det är det enda korridoren kan göra som sidescroll-remsan aldrig kunde.

**Tystnadsregeln (normativ):** exakt **en** kant per våning är avsiktligt händelselös och ett steg längre än sina grannar. Det är kanten **rum 3 → bossdörr** (5 steg, 0 hörn). Under den kanten:
- inga skyltar, inga silhuetter, inget nytt ljud
- ambiensen sjunker från −30 till −38 dB över de tre första stegen
- stegljudets efterklang blir längre (rummet öppnar sig, fast du ser det inte)
- bossdörren växer i bild men gör inget ljud

Sedan öppnar du dörren och M2:s boss-intro smäller till. **Kontrast är instrumentet.** Ett spel som är högt hela tiden har ingen kulmen; `research/01 §A` beskriver Balatros kick som stigande ton *från en baslinje*. Korridoren ger oss baslinjen gratis.

**Motsatt regel:** de tre första stegen på varje ny våning har **ett extra ljud** (droppande vatten, en sten som faller, ett avlägset läte) så att "ny våning" hörs innan den syns.

### 2.5 Återvändsgränder och hemligheter

**Frekvens:** en återvändsgränd per run i snitt. Seedat: 35 % chans per våning, max en per våning. Det ska kännas som tur, inte som en checklista. (Dead Cells "awkward middle"-varningen, `research/01 §A`: gles och betydelsefull slår tät och skräpig.)

**Innehåll, viktad dragning:**

| Vikt | Innehåll |
|---|---|
| 40 | `FORGE_FACE` gratis (byt en sida, inget val mellan tre — bara en gåva) |
| 25 | 3 `Pips` i en spilld påse |
| 20 | En `RELIC` ur `uncommon`-poolen, på ett altare |
| 15 | **Ingenting materiellt:** en Kodex-post (en rad värld, ett fiendenamn du inte mött, en av Marrows anteckningar) + 1 Pip |

De 15 % "ingenting" är obligatoriska. En återvändsgränd som **alltid** lönar sig är inte nyfikenhet, den är en skattkammare med extra steg. OSR-regeln: belöna nyfikenhet ofta, garantera den aldrig — men straffa den aldrig heller (därför 1 Pip även i tomma fall, plus att raden alltid är rolig att läsa).

**Hemliga dörrar — vår version.** Max en per våning, 50 % chans. Den **annonserar sig** med ett *tell* under 1,2 sekunder när du går förbi rutan:
- facklan fladdrar åt fel håll (drag)
- ett kritstreck på golvet pekar in i väggen
- en råtta springer rakt in i stenen och är borta

Tellet är en **tappbar yta** medan det syns, plus tre sekunder efteråt. Missar du det är det borta — och det är rätt. Vi belönar **uppmärksamhet**, inte **systematik**. Ingen "sök"-knapp, ingen väggpetning, ingen backtracking. Bakom dörren: alltid en återvändsgränd ur tabellen ovan, alltid med vikten flyttad mot altaret (relik 40 %).

### 2.6 Fällor som val, aldrig som slump

En fälla i PIPWRECK är **ett val med två prislappar, båda läsbara före tappet**. `§6` gäller i korridoren också: ingen dold tärning avgör om du tar skada.

**Mallen (normativ):**

```
SPINDELNÄTET spänner över gången.
[ GÅ IGENOM   −5 HP ]        [ SKÄR DIG LOSS   en tärningssida blir CRACKED till nästa rum ]
```

Regler:
1. **Två kostnader, aldrig en gratis utväg.** Ett val där ett alternativ är gratis är inte ett val — det är en knapp med extra text. (Undantag: **tutorialfällan i våning 0**, där tredje alternativet `GÅ RUNT (+2 steg)` finns *enbart* för att lära ut att man får välja. Sedan aldrig mer.)
2. **Valutorna är HP och tärningssidor.** Aldrig Pips (metavaluta i en run = fel signal), aldrig tid ensamt.
3. **Max en fälla per våning. Aldrig på kanten rum 3 → boss.** Att gå in i bossen skadad ska vara *ditt* fel från stridsrummen, inte en fällas.
4. **`CRACKED` återställs vid nästa rums början** — samma regel som `SLAGJAW`s `CRACK_BITE` (`GAME_DESIGN §4.5`), ingen ny mekanik.

**Fälltyper (M5, tre stycken, en per våning):**

| Fälla | Alt. A | Alt. B |
|---|---|---|
| `TRAP_WEB` Spindelnätet | −5 HP | en slumpad tärnings uppåtsida → `CRACKED` till nästa rum |
| `TRAP_EMBERS` Glödgolvet | −8 HP | börja nästa strid med `charge = 0` **och** slot 0 `blocked` runda 1 |
| `TRAP_COLLAPSE` Raset | −3 HP och 2 extra steg | offra 4 Pips till gropen |

### 2.7 Kartkänslan utan kartritning

Två mekanismer, båda gratis för spelaren:

1. **Kritstråket.** En 8 dp hög remsa högst upp som ritar sig själv **bakom** dig: en krit-linje per gången ruta, en glyf vid varje korsning du passerat, en kryssmarkering där du vände. Den visar **bara det du sett**. Den går inte att zooma, panorera eller rita i. Den är en kvittens, inte ett verktyg.
2. **Runkartan som trofé.** När runnen slutar — vinst eller död — ritas hela din väg upp som en kritkarta med dina val, dina fällor, dina återvändsgränder och ett kryss där du dog. Den hängs på **Kritväggen** (`PLACE_TALLY_WALL`) och sparas. *Det* är Etrian-belöningen: kartan som artefakt, utan att någon behövde rita den. Marrows handstil i marginalen ("here" med en pil vid dödsrutan) är den billigaste och bästa berättelsen i spelet.

---

## 3. Möten

### 3.1 Presentationen av ett vanligt monster

Fyra takter, totalt ~1,9 s. Varje takt har ett ljud och ingen text.

| Takt | Avstånd | Vad som händer | Ljud |
|---|---|---|---|
| 1 | 2 rutor | **Silhuett i mörkret.** Ingen färg, ingen detalj — en form mot en aning ljusare vägg. Den rör sig knappt. | `monster_far`, lågpassat, 600 ms |
| 2 | 2 rutor | Spelaren tar sitt sista steg (eget tapp — vi tar aldrig steget åt hen) | `step_stone` |
| 3 | 1 ruta | **Den kliver fram en ruta och blir sedd.** Silhuetten fylls med färg och pixlar på 180 ms. Hit-stop 60 ms, haptik medium. | `monster_reveal` (= `boss_intro` nedpitchad 5 halvtoner) |
| 4 | 1 ruta | Stridsskärmen glider upp underifrån över korridorbilden. Korridoren ligger kvar synlig i toppen. | – |

**Varför silhuett först:** det är genrens hela lockelse ("något står bakom hörnet") och det kostar oss noll nya sprites — det är fiendespriten i svart. Det ger också spelaren **en halv sekund av dåliga föraningar**, vilket är den känsla sidescroll-remsan aldrig kunde ge, eftersom man där såg hela raden av rum på en gång.

**Antal fiender läses av silhuetterna.** Rum 1 (`RUST_RAT ×4`) visar fyra små former i djupled — en bakom en bakom en. Det säger "överflödskedja" utan ett ord. `IRON_TICK` visar en silhuett som är **bredare än korridoren** och skymmer allt bakom sig: "muren". Det är fiendedesignen från `§4.4` uttryckt i siluettspråk, gratis.

### 3.2 Elit

Eliten har **ett ljus**. En lykta, ett brinnande öga, en glödande spricka — något som syns *runt hörnet innan den själv syns*, som en orange skimmer på stenen. Det är den enda varningen som kommer före silhuetten, och den är avsiktligt tidig: eliten ska kännas som ett val du gick *mot* (du såg kronskylten, du tog den grenen, du såg ljuset, du fortsatte). Tre bekräftelser. Då är döden ditt fel, vilket är hela community-kontraktet.

### 3.3 Boss

Dörr, inte öppning. Dörren är synlig hela den tysta sträckan (§2.4) och växer i bild. Vid dörren: **ett tapp för att öppna** — aldrig automatiskt. Det tappet är runnens viktigaste tapp och ska kännas så.
Sedan M2:s befintliga boss-intro, oförändrat, spelat **i korridoren** med dörren öppen bakom bossen.

Slagjaws dörr **buktar**: den andas utåt i takt, ~1,4 s per andetag, medan du går de fem stegen. Inget ljud. Det är den billigaste skräcken i spelet.

### 3.4 Kan man backa? Nej.

**Beslut för M5: rörelse är framåtriktad. Du kan vända dig om och titta bakåt, men `▲ FRAM` i motsatt riktning är blockerad med ett mjukt `wall_bump` och texten `THE WAY BACK IS GONE`.**

Motivering, tre skäl:
1. **Backtracking är genrens mest kritiserade egenskap** (Grimrock-recensionerna, §1.3) och det enda som skulle spränga 15-minutersbudgeten.
2. **Att gå framåt *är* beslutet.** Om reträtt fanns skulle varje korsning bli "prova och ångra", och skylten skulle sluta betyda något. Hela `§6`-filosofin bygger på att information ges före valet, inte att valet kan tas tillbaka.
3. Den sparar en hel kategori teknik (tillståndsåterställning i korridoren).

**Priset vi betalar, och som är obligatoriskt att betala:**

> **Ingenting dyker någonsin upp bakom dig. Aldrig. Inga bakhåll, inga dörrar som slår igen med något på din sida, inga fiender som flankerar.**

Får man inte fly måste man få se allt som kan döda en. Bryter vi den regeln en enda gång blir varje död otur i stället för misstag, och då är vi Rune Dice (`GAME_DESIGN` källförteckningen). Att vända sig om och se en tom, tyst korridor **ska vara lugnande** — det är den belöningen spelaren får för att ha gett upp reträtten.

### 3.5 Belöningsvalet i korridoren

Belöningen efter vunnen strid presenteras **i rummet du just vann**, inte på en egen skärm. Kameran sjunker 12° mot golvet och tre saker ligger där, upplysta av kritdamm, jämnt fördelade över bredden.

| Typ | Presentation |
|---|---|
| Vanlig strid (1 av 3) | **Tre föremål på golvet.** En sida = en glödande tärningssida; en relik = ett objekt; ett `SLOT_SWAP` = en ritning i krita på stengolvet. Tapp på ett = nedsjunkande hand som tar upp det. |
| Elit | **En kista.** Öppnas med ett tapp, de tre alternativen lyfter ur den. Samma val, mer ceremoni. |
| Boss | Inget belöningsval (`DECISIONS 2026-09-21`). I stället: **trappan ner**, och ett Kodex-uppslag som fälls upp. |
| Återvändsgränd / hemlig dörr | **Ett altare** med en enda sak på. Ingen valsituation — belöningen var att du gick dit. |

Andrummet (`BREATHER_HEAL`, +10 HP) spelas som att **facklan tänds starkare** i två sekunder innan föremålen syns. Läkningen får en synlig orsak i rummet i stället för en siffra som bara dyker upp.

---

## 4. Character sheet (Diablo-modellen)

Figuren syns aldrig i korridoren. Den finns här, och bara här — och det är därför den blir värd något att öppna.

### 4.1 Innehåll, uppifrån och ner (portrait 1080×1920)

1. **Topprad:** `Pips`-räknare · seed · HP-stapel · stäng-kryss.
2. **Figuren, centrerad, ~52 % av höjden.** Vald kroppsvariant (`DECISIONS`: två varianter av The Smith), 48×48-grunden uppskalad, med **ett lager per utrustad relik**. Smedens `ANVIL_BLESSING` är inte utrustning — den är ett brännmärke på underarmen, alltid synligt, och markerar klassen.
3. **Sex slots, tre till vänster och tre till höger**, var och en förbunden med figuren med ett kritstreck till rätt kroppsdel. Tomma slots är en kritad kontur, inte en grå ruta.
4. **Tärningsraden, botten:** sex tärningar i `IN`-ordning. Tapp på en tärning fäller ut alla sex sidorna med värde, effekt och magnitud. **Detta är den enda platsen i spelet där man kan läsa hela sin tärningsuppsättning**, och därmed den viktigaste sidan för en spelare som börjar planera på riktigt.
5. **Run-Kodex, hopfällbar remsa:** rum rensade, största kedjan, högsta multiplikatorn, bästa enskilda slot, antal `house_bonus`, fiender mötta denna run. Rekord som slås under runnen **tänds med en kritram** som ligger kvar tills man öppnat sheeten.

### 4.2 De sex relikerna → utrustningsslots

Presentation-data, hör hemma i `src/data/` (eller UI-lagret), **aldrig i `src/core/`**. Core vet inte vad en axel är.

| Slot | Nyckel | Relik (`content.gd`) | Varför just där |
|---|---|---|---|
| **Huvud** | `SLOT_HEAD` | `ECHO_MIRROR` | En spegelvisir. Speglar kopierar — det sitter över ögonen. |
| **Bröst** | `SLOT_CHEST` | `BLOOD_PRICE` | En sele med en pigg mot bröstbenet. Du betalar med kroppen. |
| **Händer** | `SLOT_HANDS` | `OCTOPUS` | Handskar med för många fingrar. Reliken handlar om *räckvidd* (slot 1 ↔ 3). |
| **Vapen** | `SLOT_WEAPON` | `DOMINO` | En hammare med dominohuvud. Reliken slår en gång till — den hör hemma i handen som slår. |
| **Amulett** | `SLOT_AMULET` | `BROKEN_SCALE` | En knäckt våg i en kedja. Bokstavligt, och det är rätt: den vägar upp udda till jämnt. |
| **Reserv/bälte** | `SLOT_SPARE` | `CHEAT_CUBE` | En riggad tärning i en bältespung. Man visar inte fusket, man har det nära. |

Tapp på en utrustad slot: regeltexten i krita, ordagrant samma sträng som på belöningskortet. **Samma ord på båda ställena.** Olika formuleringar för samma regel är `TOWN_AND_ONBOARDING §B.1`-problemet om igen.

### 4.3 Hur förändringar syns

| Händelse | Animation |
|---|---|
| **Ny relik** | Lagret **kritas på figuren** vänster→höger på 520 ms, 120 ms vit flash, haptik medium (30 ms), slotens kritstreck skriver ut namnet. Totalt 900 ms. |
| **Smidd sida** (`FORGE_FACE`) | Tärningen i raden roterar till den nya sidan, den gamla sidan **smular sönder** och faller ur bild. 600 ms. |
| **`SLOT_SWAP`** | Inte på figuren (brädet är inte kropp) — ett litet brädschema under tärningsraden där sloten byter glyf med en 300 ms kritsudd. |
| **Spricka** (`die_cracked`) | Tärningen i raden får en spricka och `die_cracked.wav`. Ligger kvar tills nästa rum. |

### 4.4 När den öppnas

- **Knapp i HUD:** paperdoll-ikon, 48 dp, uppe till vänster, synlig i korridoren och i staden. Under strid **endast via pausmenyn** — sheeten får aldrig täcka brädet i ett läge där `CONFIRM` finns.
- **Öppnas automatiskt:** exakt **en gång per spelare, någonsin** — första gången en `RELIC` plockas. Då vill vi att spelaren ser att figuren ändrades; efter det vet hen det.
- **Öppnas aldrig automatiskt för `FORGE_FACE`.** Det händer minst 50 % av alla belöningar (`GAME_DESIGN §4.7`) och skulle bli en modal man lär sig stänga utan att titta.
- **Badge:** ikonen får en pulsande kritring när något ändrats och inte setts. Precis som stadens regel (`TOWN §A.4.5`): nytt skriker, gammalt är tyst.

---

## 5. Staden i förstaperson

Ersätter `TOWN_AND_ONBOARDING.md §A.5`. Allt annat i del A (NPC:er, platser, Pips, prislista, de sex reglerna i §A.4) står oförändrat.

### 5.1 Torget är en T-korsning

Chalkrim är **ett torg där du står still**, och det är medvetet *samma kontroller och samma grammatik som korridoren*. Staden lär ut dungeon-inputen utan att kalla det tutorial.

```
                    [ GROPENS MUN ]
                    trappan ner · Marrow står här
                           ▲
  [ SKROTMARKNADEN ] ◀     ●     ▶ [ KRITVÄGGEN ]
                        (du står)
```

- **Fram = Gropens mun.** Trappan ner är **alltid i bild när du står i utgångsläget**, alltid upplyst nedifrån. `TOWN §A.4.1` ("`GO DOWN` alltid synlig") uppfylls fysiskt i stället för med en knapp — men knappen finns kvar i botten ändå, 56 dp, för att tvåtappsregeln (`§A.4.2`) ska hålla även när spelaren råkat vända sig.
- **Vänster = Skrotmarknaden.** En bod med kritpriser på en tavla. Ett tapp vänder dig dit, ett till öppnar panelen.
- **Höger = Kritväggen.** En vägg full av kritstreck, rekord och nu även **runkartorna** (§2.7), hängda som löv.
- **Marrow står vid trappan** och är den enda figuren du ser i tredje person i hela spelet, eftersom han står framför dig. Efter en död: kärran skramlar in bakom honom, han säger sin rad om din dödsorsak (`TOWN §A.1`), och trappan ner är redan tryckbar.
- **Senare platser** (Anslagstavlan, Tavernan, Smedjan) läggs i en **andra vändning**: två tapp åt vänster = Smedjan bortom marknaden. Menydjupet är fortfarande 1 (`TOWN §A.4.3`) — det är *riktningsdjup*, inte menydjup.
- **Reducerad rörelse:** vändningen sker som en 120 ms tvärklipp i stället för en 220 ms svep. Tidslinjen ändras inte (`DECISIONS 2026-09-21`).

### 5.2 Tutorialvåning 0 = källaren under smedjan

Våning 0 (`TOWN_AND_ONBOARDING §B.2`, `THE SHALLOW CUT`, sju rum) flyttar **under jord, före torget**. Hela spelet börjar så här:

1. Du vaknar i **källaren under Hobs smedja**. Låg takhöjd, ett städ i bakgrunden, en glugg med dagsljus i fjärran. Två kontroller syns: `▲ FRAM` och inget annat.
2. Rum 0.1–0.7 spelas som specat. **Korridoren mellan dem är två steg lång och helt rak** — det är den enda platsen i spelet där korridoren får vara mager, eftersom allt uppmärksamhetsutrymme går till brädet.
3. UI växer på plats: `◀ VÄND ▶` kommer in först vid rum 0.4 (första gången det finns något att titta på åt sidan), kritstråket vid 0.5, character sheet-knappen vid 0.6 när den första `SLOT_SWAP`-belöningen faktiskt ändrar något.
4. Efter bossen (`SLAGJAW'S RUNT`): **du går uppför trappan och kliver ut på torget.** Ljuset stiger, ambiensen byter från gropens torrhet till stadens vind (`TOWN §A.5`), Hob står i dörren bakom dig och säger sin enda rad. Staden öppnar.

Det är hela onboardingen uttryckt som en fysisk resa: **spelet börjar i mörker och första saken du gör är att gå upp ur det.** Sedan går du ner igen, frivilligt, resten av ditt liv. Det är temat, gratis, utan en rad exposition.

Träningshjulsregeln och `TUTORIAL_CART_LINE` står oförändrade — men i källaren är kärran en *ljudeffekt ovanför taket*, inte en synlig kärra, vilket gör raden "efter det här kommer den inte" konkret när du sedan ser kärran på riktigt vid Gropens mun.

---

## 6. Moment-katalog för korridoren

Åtta konkreta ögonblick. Kriteriet för att stå här: en spelare ska kunna **berätta om det för en kompis i en mening**. Det är det enda testet som betyder något.

| # | Moment | Vad som byggs | Känsla |
|---|---|---|---|
| 1 | **Tärningarna i mörkret.** Du hör små tärningar rulla och studsa framför dig, två rutor bort, innan du ser någonting. Ljudet är `die_activate` nedpitchad och rumsklangad. Sedan syns `PIP_THIEF`s silhuett — den satt och spelade. | `monster_far` med per-fiende-variant | Skratt, sedan oro. Man vet direkt att den vill ha ens tärningar. |
| 2 | **Glastärningen i nischen.** En återvändsgränd, en nisch i väggen i ögonhöjd, en `GLASS`-tärning som lyser svagt. Att ta den är att välja att bära något som kan gå sönder. | Återvändsgränd, altar-variant | Ren OSR: föremålet är en fråga, inte ett tillägg. |
| 3 | **Sexdörren.** En dörr med sex ingraverade ögon. Den öppnas **bara om någon av dina tärningar har en sida med värdet 6**. Är den låst står ögonen tomma; är den öppningsbar fylls de i ett i taget när du går nära. Bakom: alltid ett altare. | Ny dörrtyp, villkor läses ur `state.dice` | Den första gången man tänker "mina tärningar är *vem jag är*, inte bara vad jag slår". |
| 4 | **Muren fyller gången.** `IRON_TICK`s silhuett är bredare än korridoren och du ser ingenting bakom den. Du vet att det står något där. Du vet inte vad. | Siluettbredd per fiende | Exakt den information `armor 6` borde ha gett men aldrig gav i en siffra. |
| 5 | **Slagjaws dörr andas.** Fem tysta steg, ingen musik, ambiensen sjunker, och dörren framför dig buktar utåt i takt, ~1,4 s per andetag. Inget ljud alls. | §2.4 + dörranimation | Den bästa skräcken är den som inte låter. |
| 6 | **Facklan fladdrar åt fel håll.** Ett drag från en vägg som inte borde ha ett drag. 1,2 s + 3 s nådetid att trycka. Bakom: hemlig dörr. Missar du den får du aldrig veta vad som fanns där. | §2.5 | "Vänta — såg du det?" Det är hela genren i en sekund. |
| 7 | **Spindelnätet.** `−5 HP` eller `en tärningssida blir CRACKED`. Två prislappar, ingen gratis väg, båda synliga. Du står still tills du bestämt dig. | §2.6 | Två sekunders äkta tvekan mitt i en korridor. Gratis spänning. |
| 8 | **Kritstrecket i återvändsgränden.** Ingen skatt. Bara ett kritstreck på väggen i Marrows handstil och en rad: `"Someone stood here and thought it was the end. It was."` Plus 1 Pip. | Tom-återvändsgränd-varianten | Att ingenting ibland är det bästa som kan ligga där är vad som gör de andra sju momenten värda något. |

*Reserv, om något ovan faller på teknik:* **elitens ljus runt hörnet** (§3.2) och **fyra råttsilhuetter i djupled** (§3.1) är båda starka nog att flyttas upp i listan.

---

## 7. Ljud och tempo

### 7.1 Grundregel

**Korridoren är tyst så att striden kan vara hög.** Ambiensen ligger på −30 dB (−38 på den tysta sträckan) mot stadens −24. Det är det enda stället i spelet där vi avsiktligt sänker. All juice-motorns befintliga cue-familj ("krita + metall", `assets/sfx/README.md §1`) gäller oförändrat — de nya cuerna byggs av samma två lager i `tools/gen_sfx.py` så CI-diffen förblir deterministisk.

### 7.2 Sex nya cues

| Namn | Längd | Mix-dB (rel. `damage_hit` = 0) | Pitchas? | Anmärkning |
|---|---|---|---|---|
| `step_stone` | 70 ms | **−18** | ja, ±1 halvton växelvis | Vänster/höger fot alternerar. Efterklangen förlängs 25 % på den tysta sträckan (§2.4). Spelas ~63 ggr per run — får aldrig bli påträngande. |
| `turn_scuff` | 90 ms | **−20** | nej | Kortare och torrare än steget, annars låter vändningen som förflyttning. |
| `door_open` | 420 ms | **−6** | nej | Bossdörr och hemlig dörr. Mest metall, minimalt krita. |
| `monster_far` | 600 ms | **−10** | ja, per fiendetyp | Lågpassat 800 Hz, panorerat mot silhuettens ruta. **Enda ljudet i spelet som får panoreras.** |
| `torch_draft` | 300 ms | **−16** | nej | Hemlig dörr-tellet. Nästan bara krita, rent brus — det ska knappt registreras medvetet. |
| `descend_stairs` | 700 ms | **−8** | nej, −3 halvtoner per våning | Går nedåt i tonhöjd för varje våning. Våning 3 låter märkbart tyngre än våning 1. Det är hela progressionen i ett ljud. |

Sjunde, valfri: `wall_bump`, 80 ms, −24 dB, mjuk och tonlös. Ett "nej" får aldrig låta som ett straff.

`monster_reveal` är **ingen ny fil** — det är `boss_intro.wav` nedpitchad 5 halvtoner (`Juice` gör redan pitch-skift). Vi lägger inte till en fil vi kan låna.

### 7.3 Tempotak

| Moment | Tak |
|---|---|
| Ett steg | 260 ms (auto-repeat vid håll: 220 ms) |
| En vändning | 220 ms |
| Silhuett → strid | 1 900 ms |
| Dörröppning → boss-intro | 800 ms + M2:s befintliga intro |
| Belöningsuppställning i rummet | 600 ms innan de tre föremålen är tappbara |
| **Hela korridortiden per run** | **≤ 90 s** (mäts som `corridor_ms` i den lokala telemetriloggen, samma väg som `town_dwell_ms`) |

Alla tak ska kunna skalas av kedjetempo-inställningen (Lugn/Normal/Snabb/Blixt, `DECISIONS 2026-09-21`) med samma faktor som kedjan. **Blixt-läge halverar stegtiden.** En spelare på sin tjugonde run ska kunna gå igenom en korridor på fem sekunder utan att slåss mot animationer — genren tappar folk där, inte på svårighetsgraden.

---

## 8. Betyg: hur mycket roligare blir spelet?

Jämförelse mot sidescroll-marschen som den ser ut i M2 (`docs/screenshots/m2/`).

| Axel | Sidescroll | Korridor | Motivering |
|---|---|---|---|
| **Roligt** | 5/10 | **8/10** | Remsan var transport. Korridoren producerar en kick sidescroll är fysiskt oförmögen till: att *inte veta* vad som står två rutor bort. Det är samma gratis spänning som Darkest Dungeons korridorer mellan rum, och `Vampire Crawlers` (april 2026) bevisade att formen bär ett roguelite kommersiellt. |
| **Djup** | 4/10 | **6/10** | +2, inte mer: djupet sitter i brädet och det rör vi inte. Korridoren lägger till tre riktiga beslut per våning (gren, fälla, återvändsgränd) — inte trettio. Into the Breach-regeln: få regler, tydliga konsekvenser. |
| **Läsbarhet** | 7/10 | **6/10** | **Detta är en regression och den är priset.** I remsan såg man hela våningen på en gång. I förstaperson ser man en ruta. Kritstråket (§2.7) och skyltarna (§2.3) får tillbaka det mesta — men inte allt, och den som påstår något annat ljuger. |
| **Replayability** | 5/10 | **7/10** | Seedad korridorform + återvändsgränder + hemliga dörrar ger "vad missade jag?" — en fråga sidescroll aldrig kunde ställa. Runkartan på Kritväggen gör frågan permanent. |

**Sammanvägt: korridoren gör spelet ungefär `+3` roligare på en tiogradig skala, och det är stort.** Men vinsten är inte gratis:

### 8.1 Var risken ligger, rangordnad

1. **Tempo — den enda risken som kan döda projektet.** 63 steg per run är 63 tillfällen att tråka ut någon. Skyddet är tre siffror som **måste mätas i M5, inte uppskattas**: `corridor_ms ≤ 90 s per run`, `max 3 steg utan händelse`, `Blixt-läget halverar stegtiden`. Faller någon av dem har vi bytt en tråkig remsa mot en tråkigare korridor. Det här är stoppregeln för M5.
2. **Läsbarhetsregressionen ovanpå en befintlig läsbarhetsskuld.** `TOWN_AND_ONBOARDING §B.1` satte stridens läsbarhet till **3/10** och M2.5 skulle fixa det. Att lägga en förstapersonspresentation ovanpå en strid man ännu inte förstår är att bygga två våningar på en sviktande grund. **Ordningen är inte förhandlingsbar: `COMBAT_READABILITY.md` levereras först, korridoren sedan.**
3. **Att korridoren börjar vilja bli ett eget spel.** Fällor, hemliga dörrar och återvändsgränder är kul att designa och det finns alltid en till att lägga till. Taket är hårt: **tre beslut per våning, max en fälla, max en återvändsgränd, max en hemlig dörr.** Allt utöver det stjäl sekunder från brädet, som är där spelet faktiskt bor.
4. **Presentationsprestanda på billiga Android-enheter.** R&D:s fråga (`docs/research/05_fps_korridor.md`), men den är min också: tappar vi bildfrekvens i korridoren blir steget grötigt, och ett grötigt steg upprepat 63 gånger är värre än ingen korridor alls. **Golvet: 60 fps på referenstelefonen, annars sänker vi stegets ambition, inte bildfrekvensen.**

---

## 9. Vad jag behöver beslut på

| # | Fråga | Mitt förslag |
|---|---|---|
| 1 | Låser vi rörelsen framåtriktad i M5 (§3.4)? | **Ja**, tillsammans med regeln "ingenting dyker upp bakom dig". De hör ihop och den ena utan den andra är oärlig. |
| 2 | Får korridoren lägga till innehåll (fällor, återvändsgränder) som `run_graph` inte känner till? | **Ja**, som presentationslager med samma seed, men **aldrig** en väg grafen inte har och aldrig en väg förbi en strid. |
| 3 | Sexdörren (moment 3) läser `state.dice` utanför strid. OK? | **Ja.** Ren läsning, ingen mutation, ingen RNG. Bryter inte `§6`. |
| 4 | Budget: tre nya sprite-behov (dörr, altare, kista) + sex WAV. | Dörr och altare är obligatoriska för M5. Kistan kan vänta till eliterna i M3. |

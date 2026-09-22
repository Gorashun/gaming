# PIPWRECK – Progressionsredesign: gear, roster och en stad som syns

*Författare: rpg-nerd-roguelike · 2026-09-22 · Status: **designförslag**, kräver Anders beslut. Inget bygge förrän dess (`DECISIONS.md` 2026-09-22, STOPP).*
*Utlöst av speltest 4: "Det känns inte som progression. Kolla på Darkest Dungeon. Gillar träningsidén men det behöver finnas gear man kan tappa."*

**Ingenting i `GAME_DESIGN.md §2` (regelspec) eller `§6` (heliga regeln) ändras av detta dokument.** Allt nedan är innehåll, ägande och ceremoni. Två saker i §4/`TOWN_AND_ONBOARDING §A.3` föreslås däremot **strykas** – se §6. De kräver nya beslut.

---

## 1. Diagnos: varför känns det inte som progression?

### 1.1 Vad spelaren faktiskt får i dag

| Tidsenhet | Vad spelaren får | Är det ett föremål? | Syns det? | Kan det förloras? |
|---|---|---|---|---|
| Runda (~30 s) | Ingenting permanent. Siffror på skärmen. | Nej | – | – |
| Strid (3–4 min) | 1 av 3: `FORGE_FACE` (byt en sida) / `RELIC` / `SLOT_SWAP` | Nej – valet **konsumeras direkt** | Som en ändrad siffra på en tärningssida | Nej |
| Run (~15 min) | 3–7 Pips vid död, ~20 vid vinst. Ett kritstreck. Ev. Kodexrad. | Nej | En siffra i staden | Nej |
| Session (2–4 runs) | Ett köp på marknaden: "+1 post i belöningspoolen" (`meta.gd:buy`) | Nej | **Ingenting alls i nästa run** | Nej |

### 1.2 Sju glapp, rangordnade efter hur mycket de kostar oss

1. **Ingen ägandekänsla. Vi har noll `Item`-objekt i spelet.** Allt som "droppar" är en regeländring som appliceras i samma ögonblick den ges. Det går inte att plocka upp, titta på, jämföra, spara, byta ut eller stoltsera med. Diablos hela genre bygger på motsatsen: ett föremål med namn, ikon, färg och ägare ([Diablo tog färgkodningen från Angband, Wikipedia: Loot](https://en.wikipedia.org/wiki/Loot_(video_games))).
2. **Metan är en lotterisedel, inte en ägodel.** Att betala 5 Pips för "ny sida i poolen" ger **noll observerbar skillnad** i nästa run – i bästa fall dyker kortet upp som 1 av 19 poster. Dead Cells-modellen fungerar bara med stor, **synlig** pool (ritningslistan som fylls). Vår pool har 19 poster och ingen visualisering. Det är ett kvitto på ingenting.
3. **Inget tal går upp. Någonsin.** Ingen nivå, ingen XP, ingen HP-stege, inget gear score. Vi förbjöd det i `TOWN §A.3` ("aldrig en statsiffra"). Regeln var rätt mot *köpbar* styrka och fel som absolut regel. Varje spel Anders nämner har minst ett monotont stigande tal som han *äger*.
4. **Det finns ingenting att tappa.** Vid död förlorar spelaren 15 minuter och en tärningskonfiguration hen aldrig hann uppleva som "sin". Kritstrecket är symbolisk förlust utan materiell insats. Roguelike-spänning = insats × risk. Vår insats är noll, alltså är spänningen noll, alltså känns döden som en omstart och inte som en förlust.
5. **Inga sällsynthetsögonblick.** `Rules.Rarity` finns i koden men yttrar sig **bara som en vikt i en dragning**. Ingen färg, inget ljud, ingen stråle, ingen paus. Ett sällsynthetsögonblick är 200 ms lång och är hela genrens signaturkick.
6. **Bygget är för abstrakt för att kunna berättas.** Bygget bärs av sidor på tärningar plus slottyper. Ingen spelare kan säga "jag är en X" efter en run. Jämför Balatro (jag körde Fibonacci-bygget) eller Diablo (jag är en blixt-sorc).
7. **Vi har redan ritat garderoben och lagt ingenting i den.** `content.gd` har sju utrustningsslots (`SLOT_HEAD` … `SLOT_AMULET`) och en tabell `RELIC_SLOTS` som hänger sex reliker på kroppen **enbart som kosmetik**. Character sheetet lovar loot. Spelet levererar inte. Det är projektets största självmål – och samtidigt den billigaste fixen, för halva datamodellen finns.

### 1.3 Vad andra spel ger per samma tidsenhet

| Spel | Per strid/rum | Per run/expedition | Per session |
|---|---|---|---|
| **Darkest Dungeon** | 3–8 loot-objekt (guld, ädelstenar, **trinkets med sällsynthet**), XP till fyra namngivna hjältar | Hjältar går upp i nivå, trinkets behålls, guld till Hamlet | En byggnad uppgraderas **synligt**, ny hjälte rekryteras, någon dör för alltid |
| **Slay the Spire** | 1 kortval + guld + potion-chans; elit = relik | Relikrad som växer visuellt längst upp | Unlock-poäng även vid förlust |
| **Hades** | Boon var 1–2 min, Obols, Darkness | Darkness + nycklar + **ny berättelse just för att du dog** | Mirror-noder, vapenaspekter |
| **Dead Cells** | Vapen/mutation var 1–2 min, celler hela tiden | Ritningar (synlig lista som fylls) | Nya items i poolen + Boss Cell |
| **Diablo** | Föremål var 20–60 s, **sällsynthetsögonblick** (färg + ljud) var par minuter | Nivå, gear score, paperdoll som byts ut | Karaktären ser annorlunda ut |
| **Shattered Pixel Dungeon** | Okänt föremål att identifiera var 30–60 s | 11–13 uppgraderingsrullar per run = konkreta +1 på **ditt** vapen ([Pixel Dungeon Wiki](https://pixeldungeon.fandom.com/wiki/Scroll_of_Upgrade)) | Badges, klasser |
| **Vampire Crawlers** (poncle 2026) | Kort + mynt per möte | Crawlers till värdshuset, uppgraderingar | Nya sittplatser på Inn ([PC Gamer, unlock-ordning](https://www.pcgamer.com/games/roguelike/vampire-crawlers-best-upgrades-unlock-order/)) |
| **PIPWRECK i dag** | 1 abstrakt regelval var 3–4 min | En siffra | En osynlig poolpost |

**Slutsats:** vi har inte för få belöningar, vi har **fel sorts belöningar**. Alla våra belöningar är av samma typ (regeländring), samma format (kort), samma tempo (efter varje rum) och samma varaktighet (en run). Progression uppstår ur **flera parallella spår med olika tempo** – kort tempo (taktiskt val), medellångt (föremål man äger), långt (hjälte och stad). Vi har bara det korta.

---

## 2. Darkest Dungeon som referens – vad vi tar, vad vi lämnar

### 2.1 Vad i DD som faktiskt skapar dragningen

| DD-system | Vad det gör psykologiskt | Passar oss? |
|---|---|---|
| **Hamlet med byggnader som uppgraderas** | Guld → **synlig** permanent förändring av basen. Stagecoachens Hero Barracks är det första alla uppgraderar ([GameFAQs: Your Hamlet](https://gamefaqs.gamespot.com/pc/804193-darkest-dungeon/faqs/76087/your-hamlet), [TheGamer: bästa Hamlet-uppgraderingarna](https://www.thegamer.com/darkest-dungeon-best-hamlet-upgrades/)) | **JA.** Direkt. Vi har redan staden. |
| **Roster med namngivna hjältar och nivåer** | Investering får ett ansikte. Att skicka *Reynauld* ner är inte samma sak som att skicka "spelaren" | **JA**, i liten skala (2–4 platser, inte 28) |
| **Trinkets med sällsynthet, droppade i dungeon** | Föremålet är objektet. Färg + namn + effekt. Trinkets **överlever hjältens död** om striden vinns, men går förlorade vid reträtt ([DD Wiki: Trinkets](https://darkestdungeon.wiki.gg/wiki/Trinkets_(Darkest_Dungeon))) | **JA.** Det är exakt det Anders ber om. |
| **Permadöd som förlust av investering** | "Heroes will die. And when they die, they stay dead." Smärtan kommer av *investeringen*, inte av döden ([Wikipedia: Darkest Dungeon](https://en.wikipedia.org/wiki/Darkest_Dungeon)) | **JA**, men bara om vi först bygger något att investera i |
| **Quirks** | Karaktären får en personlighet du inte valde | **Delvis** – 1 quirk per hjälte, som smak, inte som bokföring |
| **Stress / afflictions** | Andra hälsomätaren, tvingar rotation | **NEJ.** Kräver 20+ hjältar och 40-minuterssessioner. Dessutom är DD:s tavernabehandlingar (bar/hasard/bordell) fel för 13+ enligt `research/01 §E`. |
| **Förnödenheter före expedition** | Förberedelse som beslut | **NEJ.** `CORRIDOR_DESIGN §1.3` har redan sagt nej till inventarie-bokföring, och det står fast. |
| **Expeditioner med mål + veckoekonomi** | Struktur | **NEJ.** Vi har Anslagstavlan; det räcker. |

### 2.2 Kritiken mot DD – de fyra fällor vi måste undvika

- **Tempo och grind.** "efter 12 timmar hade jag slagit 4 bossar"; "kul i 10 timmar men för grunt för de 50+ runs som krävs" ([Metacritic, användarrecensioner](https://www.metacritic.com/game/darkest-dungeon/user-reviews/)). *Vår motmedicin:* run = 15 min, hjältenivå 1–5 (inte 1–6 med resolve-tak), inga väntetider, inga helgkurer.
- **Rostret urvattnar karaktärerna.** "a larger roster means individual characters are diminished in importance" och sent i spelet kan man bara bygga alla till optimala hjältar ([The Gemsbok: A Mechanical Critique of Darkest Dungeon](https://thegemsbok.com/art-reviews-and-articles/darkest-dungeon-red-hook-critique-mechanics-design/)). *Vår motmedicin:* **max 4 platser, någonsin.** Fyra namn man minns slår 28 man sorterar.
- **Stressrotationen blir tjat.** Communityt: stressmekaniken tvingar rotation och blir "tedious after a while" ([Steam-diskussioner](https://steamcommunity.com/app/262060/discussions/0/1836811737981213706)). *Vår motmedicin:* ingen stress. Hjältens enda kostnad är dödsrisk.
- **Loot-förlusten kan bli grym på fel sätt.** I DD kan förlorade unika trinkets svida värre än den döde hjälten ([DD Wiki: Trinkets](https://darkestdungeon.wiki.gg/wiki/Trinkets_(Darkest_Dungeon))). *Vår motmedicin:* **räddningsregeln i §3.4** – du förlorar aldrig *allt*, och du vet exakt hur mycket du riskerar innan du går ner.

> DD-lärdomen på en rad: **smärtan vid död ska stå i proportion till investeringen, och investeringen ska vara synlig innan du går ner.**

---

## 3. Gear: föremål som droppar, syns, bärs och kan tappas

### 3.1 Grundgreppet: reliker **blir** gear

Vi har redan `Relic`, resolvern konsumerar den, och `RELIC_SLOTS` hänger sex av dem på kroppen. Förslag: gör den kosmetiska kopplingen till den riktiga datamodellen.

```
Gear:
  id: StringName
  slot: HEAD|CHEST|HANDS|WEAPON|LEGS|BACK|AMULET
  rarity: COMMON|UNCOMMON|RARE|EPIC      # EPIC är ny
  effect: <samma hook-familj som Relic i dag>
  level: int                             # 0–3, smedjan höjer
```

`Relic` som separat begrepp **utgår**. Kategorin `RELIC` i belöningspoolen utgår. Resolvern rör vi inte – den läser fortfarande `state.relics`, som nu fylls av utrustade `Gear`. **Detta är en datamodellsändring, inte en regeländring.**

### 3.2 Gear-effekter måste vara regler, inte staplar

Tre lagar, normativa:

1. **Effekten måste synas i förhandsvisningen** (`§6`). "+2 skada ibland" är förbjudet. "Slot 4 ignorerar 2 rustning" är tillåtet, för kvittot kan visa det.
2. **Max en ren stat-effekt per plagg, och bara på `COMMON`.** (+HP, +Ward, +omkast.) Allt över `COMMON` ska ändra *hur brädet fungerar*.
3. **All gear-styrka är dödlig.** Den bärs av en hjälte och riskeras varje run. Ingenting köps för pengar, ingenting är permanent säkert utan att spelaren aktivt valt att banka det. Därmed bryter vi inte `CLAUDE.md` (inget pay-to-win) trots att siffror nu går upp.

### 3.3 Droppar: var, hur ofta, och ceremonin

| Källa | Droppchans | Sällsynthetsgolv |
|---|---|---|
| Vanlig fiende (`RUST_RAT`, `SLAG_MOTH`) | 12 % | `COMMON` |
| Tåligare fiende (`THORN_IMP`, `PIP_THIEF`, `IRON_TICK`, `GRAVE_HAND`) | 22 % | `COMMON`, 25 % chans `UNCOMMON` |
| Elit (skylt `SIGN_ELITE`) | 100 % | `UNCOMMON` |
| Altare i återvändsgränd | 100 % | `UNCOMMON`, 20 % `RARE` |
| Boss (`SLAGJAW`) | 100 % | `RARE`, 15 % `EPIC`. **Första gången garanterat unikt boss-plagg.** |

**Ceremonin (200–900 ms beroende på sällsynthet).** Detta är halva värdet.

| Sällsynthet | Färg | Ljud | Presentation |
|---|---|---|---|
| `COMMON` | Benvitt | Kort klink | Faller i korridoren, plockas med ett tapp |
| `UNCOMMON` | Kopparn/grön | Två toner upp | Kort glimt |
| `RARE` | Blå | Ackord + lågt brummande | Kameran stannar 400 ms, kritring runt föremålet |
| `EPIC` | Lila | Klocka + tystnad efter | Korridorens ljus slocknar utom över föremålet, 900 ms. **Max 2 gånger per run.** |

Ceremonin är också läsbarhet: färgen säger värdet på 200 ms, precis som Diablo etablerade ([Wikipedia: Loot](https://en.wikipedia.org/wiki/Loot_(video_games))).

### 3.4 Vad tas med upp, vad förloras, vad räddas (den viktigaste regeln i dokumentet)

```
UTRUSTAT GEAR ÄR DITT DIREKT – men osäkrat.
TRAPPAN mellan våningar är en BANK: "Skicka upp med kärran".
  → du väljer valfritt antal föremål att skicka upp. De är säkra för alltid.
  → men du bär dem inte resten av runen.
VINST (rum 12) → allt du bär säkras automatiskt.
DÖD → allt osäkrat går förlorat, OCH hjälten dör permanent.
  → UTOM: Kistan (byggnad) räddar N föremål. N = kistans nivå (0 → 1 → 2 → 3).
  → Räddningen är spelarens VAL bland det burna, presenterat av Marrow vid kärran.
```

Varför just så:
- **Trappan som bank är ett äkta, läsbart risk/belöning-beslut** – exakt DD:s "retreat and you lose the trinkets", men frivilligt och begripligt. Det är också vårt enda "press your luck"-ögonblick, och det ligger på de två platser i runen (rum 4 och 8) där `FATE_ROLL` redan finns.
- **Kistans nivå gör en byggnadsuppgradering fysiskt kännbar.** Man *märker* skillnaden mellan kista 0 och kista 1 första gången man dör.
- **Marrow presenterar räddningen.** Den vackraste 10-sekundersscenen i spelet: kärran, en rad text om hur du dog, och en hand som håller fram tre föremål: *välj ett.*

### 3.5 Tjugo gear-exempel

*(Effekter formulerade så att kvittot i `TOWN §B.3` kan visa dem. Alla siffror tuningbara enligt `GAME_DESIGN §4.8`.)*

| # | `id` | Namn | Slot | Sällsynthet | Effekt | Dropkälla |
|---|---|---|---|---|---|---|
| 1 | `SCRAP_CAP` | Skrothjälm | HEAD | common | +6 max HP | `RUST_RAT` |
| 2 | `TALLOW_HOOD` | Talgkåpan | HEAD | uncommon | +1 omkast första rundan i varje strid | `SLAG_MOTH` |
| 3 | `PIPSIGHT_LENS` | Ögonlinsen | HEAD | rare | **Alla 1:or räknas som 2:or** i P1 | `PIP_THIEF` |
| 4 | `SLAG_PLATE` | Slaggplåten | CHEST | common | Spelaren har rustning 2: varje fiendeattack minskas med 2 | `IRON_TICK` |
| 5 | `TICK_CARAPACE` | Fästingskalet | CHEST | uncommon | Ward nollställs inte vid `round_end` – hälften (floor) ligger kvar | `IRON_TICK`, elit |
| 6 | `KILN_VEST` | Ugnsvästen | CHEST | rare | Varje runda du tar 0 skada: +4 Charge | Altare |
| 7 | `GRIP_WRAPS` | Grepplindorna | HANDS | common | +1 omkast per strid | `RUST_RAT` |
| 8 | `TONG_GLOVES` | Tånghandskarna | HANDS | uncommon | **Ambosströskeln 5 → 4** | `GRAVE_HAND` |
| 9 | `THIEFS_MITTS` | Tjuvvantarna | HANDS | rare | Första tärningen du placerar varje runda får +2 | `PIP_THIEF`, elit |
| 10 | `CHIPPED_HAMMER` | Flisade hammaren | WEAPON | common | Slot 4 ignorerar 2 rustning | `RUST_RAT` |
| 11 | `SPIKE_MAUL` | Spikklubban | WEAPON | uncommon | Rundans största träff ignorerar 3 rustning | `THORN_IMP` |
| 12 | `MOTH_EDGE` | Malbettet | WEAPON | uncommon | Varje `enemy_killed` ger +3 Charge | `SLAG_MOTH` |
| 13 | `SLAGJAW_TOOTH` | Slaggkäftens tand | WEAPON | epic | **Överflöd beskattas inte av rustning** | `SLAGJAW`, första kill garanterad |
| 14 | `RUST_GREAVES` | Rostbenskenorna | LEGS | common | +2 Ward vid varje `round_start` | `RUST_RAT` |
| 15 | `CART_BOOTS` | Kärrstövlarna | LEGS | uncommon | Du börjar varje strid med 5 Charge | `GRAVE_HAND` |
| 16 | `PIT_STRIDERS` | Gropskridarna | LEGS | rare | Stridens första runda: du rullar **7** tärningar | Boss |
| 17 | `DICE_POUCH` | Tärningspungen | BACK | common | Varje oplacerad tärning ger +1 extra Charge | `SLAG_MOTH` |
| 18 | `CHALK_SATCHEL` | Kritväskan | BACK | uncommon | `CHARGE_CAP` 20 → 32 | Altare |
| 19 | `MARROWS_TARP` | Marrows presenning | BACK | rare | **Vid din död räddas ett föremål extra** (staplar med Kistan) | `GRAVE_HAND`, elit |
| 20 | `BONE_TALLY` | Benräkningen | AMULET | common | +1 skada per fiende du redan dödat denna strid | `THORN_IMP` |
| 21 | `TWIN_PIP` | Tvillingögat | AMULET | rare | **`HOUSE` utlöses även av två par** (löser `GAME_DESIGN §7` fråga 1 som ett föremål i stället för en regel) | Boss |
| 22 | `SIXTH_SEAT` | Sjätte platsen | AMULET | epic | **+1 slot: brädet har 6 slots** | Boss, 15 % |

*(22 rader – de två extra är avsiktliga: 13 och 22 är "drömdropparna" och systemet behöver minst två av dem för att ryktet ska sprida sig.)*

**Sällsynthetsbalans:** common 7, uncommon 6, rare 6, epic 2. Epic får aldrig droppa före våning 2.

---

## 4. Meta-progression som syns

### 4.1 Byggnader som uppgraderas för Pips

| Byggnad | Nivå 1 | Nivå 2 | Nivå 3 | Pris (Pips) |
|---|---|---|---|---|
| **Kistan** (i smedjan) | 1 föremål räddas vid död | 2 föremål | 3 föremål | 10 / 25 / 60 |
| **Smedjan** | Uppgradera gear `+1` (max lvl 1) | max lvl 2, kan uppgradera `rare` | max lvl 3, **omslipning**: byt effekt inom samma slot | 15 / 35 / 80 |
| **Tavernan** | 2 hjälteplatser | 3 platser | 4 platser + rekryter startar på nivå 2 | 20 / 45 / 90 |
| **Skrotmarknaden** | 3 varor per run, upp till `uncommon` | 4 varor, upp till `rare` | 5 varor + ett omval | 15 / 40 / 85 |
| **Kritväggen** | Gratis. Samlingen: alla gear-silhuetter, låsta i krita | – | – | – |

**Varje uppgradering måste synas i staden.** Kistan nivå 2 är en större kista i bild. Tavernan nivå 3 har tre stolar upptagna. Det är Dead Cells "rummet som fylls" och DD:s Hamlet, och det kostar oss sprites, inte systemarbete.

### 4.2 Hjälteroster

- **2–4 hjältar**, aldrig fler. Varje har **namn** (genererat ur en namnlista), **klass**, **nivå 1–5**, **ett quirk** och **sin egen gear-uppsättning**.
- **XP per run:** 1 per rensat rum, 3 per boss, 5 för vinst. Nivå 2 vid 10, 3 vid 25, 4 vid 50, 5 vid 90.
- **Vad nivån ger – och detta är kärnan i hela dokumentet:** nivån låser upp **hur många gear-slots hjälten får bära**.

| Hjältenivå | Aktiva gear-slots |
|---|---|
| 1 | 2 (WEAPON, CHEST) |
| 2 | 3 (+HEAD) |
| 3 | 4 (+HANDS) |
| 4 | 6 (+LEGS, BACK) |
| 5 | 7 (+AMULET) |

Varför: talet går upp och **känns** (fler plagg på figuren, mer kraft), men det är **intjänat, inte köpt**, och det **dör med hjälten**. Ingen permanent stat-inflation, ingen pay-to-win, ingen power creep mellan runs. Det är DD:s modell exakt, och det är svaret på `TOWN §A.3`:s "aldrig en statsiffra": regeln ska vara **"aldrig köpbar permanent styrka"**, inte "inga siffror".

- **Död = hjälten är borta för alltid.** Namnet går till Gravlunden bredvid Kritväggen (kritstrecken behålls, men får sällskap av namn). Gear räddas enligt §3.4.
- **Quirks (1 per hjälte, smak inte bokföring):** `HEAVY_HANDED` (+1 på alla 6:or, −1 på alla 1:or), `SUPERSTITIOUS` (första omkastet varje strid är gratis, men du måste kasta om minst en tärning), `HOARDER` (+2 Charge per runda, `CHARGE_CAP` −5), `RIGHT_HANDED` (slot 4 +2, slot 0 −1).

### 4.3 Synlig samling

Kritväggen visar **alla 22 gear-föremål** som krittecknade silhuetter med namn dolda tills de hittats – Balatro-modellen: du ser alltid hur mycket som finns kvar. "17 / 22" är en progressionssiffra som kostar oss noll balansarbete.

### 4.4 Dagliga mål

**Nej.** `CLAUDE.md` förbjuder inloggningsmekanik och `TOWN §A.4` regel 6 står fast. Anslagstavlans tre kontrakt roterar **per run**, inte per dygn. Samma kick, ingen klocka.

### 4.5 Byggordning

1. Gear + dropptabeller + ceremoni (utan stad – gear fungerar redan inom en run).
2. Kistan + räddningsscenen (gör döden meningsfull).
3. Roster + nivåer + slot-upplåsning.
4. Smedjan nivå 1–3 och marknaden som säljer gear i stället för poolposter.
5. Kritväggens samling.

---

## 5. Progressionskurva, run 1–10

| Run | Låses upp | Droppar (förväntat) | Vad spelaren ser som är nytt |
|---|---|---|---|
| 0 (tutorial) | Staden, hjälte #1 nivå 1 (2 slots) | **1 garanterad `COMMON`** i rum 0.3 – ett föremål som syns på figuren | Loot existerar. Character sheet får sitt första plagg. |
| 1 | Kistan nivå 0 (**du förlorar allt om du dör – uttalat**) | 2–3 common | Första gången ett föremål går förlorat vid död. Marrow säger det rakt ut. |
| 2 | Kistan nivå 1 (10 Pips) köpbar | 2–4, första `UNCOMMON` ≈ nu | **Räddningsscenen.** Marrow håller fram tre föremål: välj ett. |
| 3 | Hjälte #1 → nivå 2 (3 slots) | 3–5 | Ett tredje plagg på figuren. Anslagstavlan öppnar. |
| 4 | Smedjan nivå 1: uppgradera gear `+1` | 3–5, första boss-drop om bossen fälls | Ett föremål **du redan äger** blir bättre. |
| 5 | Tavernan: hjälte #2 | 4–6 | Två namn på rostret. Första gången valet "vem skickar jag ner?" finns. |
| 6 | Trappbanken förklaras (första `FATE_ROLL` nås konsekvent) | 5–7, första `RARE` ≈ nu | **Blått ljus i korridoren.** Första riktiga sällsynthetsögonblicket. |
| 7 | Marknaden nivå 2: `rare` i handeln | 5–8 | Man kan köpa det man drömt om men inte fått. |
| 8 | Hjälte #1 → nivå 4 (6 slots) | 6–9 | Figuren är nästan helt utrustad. Silhuetten har ändrats. |
| 9 | Kistan nivå 2 | 6–9 | Att gå ner djupt blir rationellt. |
| 10 | Första `EPIC` möjlig; klass 2 som silhuett | 7–10 | Lila ljus, korridoren slocknar. Det är kvällens historia. |

**Kicktäthet, mål:** en "kick" = loot-drop, belöningsval, nivåhöjning, upplåsningsbadge, sällsynthetsögonblick eller räddningsscen.

| | I dag | Mål |
|---|---|---|
| Kickar per 15-minutersrun | 4–5 (ett belöningsval per rum) | **12–16** |
| Kickar per minut | 0,3 | **0,9–1,1** |
| Sällsynthetsögonblick (`rare`+) per run | 0 | 0,6 (≈ vartannat run) |

---

## 6. Vad som ska bort eller ändras – ärligt

| Vad | Dom | Motivering |
|---|---|---|
| **`RELIC` som eget begrepp** | **Bort.** Blir gear med slot och sällsynthet. | Vi har två system som gör samma sak, och det ena är osynligt. Sammanslagningen kostar en dags refaktor och fördubblar den upplevda belöningen. |
| **Marknadsköp = "+1 post i belöningspoolen"** | **Bort.** | Den enda mekanik i spelet som ger **noll** observerbar effekt. Pips köper byggnader, uppgraderingar och gear i stället. |
| **"Aldrig en statsiffra"** (`TOWN §A.3`) | **Ändras** till "aldrig köpbar permanent styrka". | Den nuvarande formuleringen är orsaken till att spelet inte känns som progression. Kräver nytt beslut i `DECISIONS.md`. |
| **Sidor på tärningar som byggets bärare** | **Behålls, men underordnas.** | Sidsmide är fortfarande det taktiska, deterministiska bygget och spelets själ – men det är **för abstrakt för att bära progressionskänslan ensamt**. Ny rollfördelning: **sidor = taktik** (val var 3–4 min, konsumeras), **gear = ägodel** (drop, slumpmässig, syns, kan tappas). Två spår i olika tempo. `FORGE_FACE` blir kvar som belöningskategori och får **ökad vikt** (50 → 65) när `RELIC` lämnar poolen. |
| **Pips ersatt av guld?** | **Nej.** Behåll Pips, byt vad de köper. | Två valutor är en menylabyrint (`TOWN §A.3`, det argumentet står). Att byta namn löser ingenting; att byta *utgift* löser allt. |
| **`MetaScore` (poängsiffran)** | **Bort ur UI.** | Vi har två parallella "belöningstal" (score och Pips). Ett räcker. Score kan bo kvar i koden som rekordmått på Kritväggen. |
| **Kritstrecken** | **Behålls + utökas.** | Lägg namnen på de döda hjältarna bredvid. Ett streck är statistik; ett namn är en historia. |
| **`SLOT_SWAP` som belöning** | **Behålls.** | Den är den mest underskattade belöningen vi har – den ändrar faktiskt spelstil. Vikten höjs 20 → 25. |

---

## 7. Prioritering och betyg

### 7.1 De tre ändringarna med bäst effekt per byggdag

| # | Ändring | Byggdagar (est.) | Progressionskänsla per dag |
|---|---|---|---|
| **1** | **Gear-drops:** `Relic` → `Gear` med 7 slots + 22 föremål + dropptabeller + sällsynthetsceremoni + paperdoll som fylls | ~3 | **Högst.** Halva datamodellen finns (`RELIC_SLOTS`, character sheet). Ger ägande, sällsynthetsögonblick, synligt bygge och något att tappa – fyra av sju glapp i §1.2 på en gång. |
| **2** | **Kistan + räddningsscenen + trappbanken** | ~1,5 | Gör döden till en förlust och nedstigningen till ett beslut. Detta är vad som saknas mest av allt: **insats**. Billigt, för det är UI + en sparfil. |
| **3** | **Roster med nivåer som låser upp gear-slots** | ~2 | Ger det stigande talet, ger hjälten ett namn, och gör permadöden till DD:s permadöd. Kan inte byggas före 1 och 2. |

*(4:a, om tid finns: byggnadsnivåer som syns i stadens bild. ~1 dag, rent presentationsarbete, mycket hög känsla per krona.)*

### 7.2 Betyg

| Axel | I dag | Efter 1–3 | Kommentar |
|---|---|---|---|
| **Roligt** | 6 | **8** | Kärnan var redan 7 i `TOWN §0`; den har inte blivit sämre, men avsaknaden av belöning har dragit ner den. Loot-ceremonin är ren vinst. |
| **Djup** | 8 | **8** | Oförändrat, medvetet. Gear får inte lägga till nya regelsystem, bara nya regel*varianter*. Risken att gå till 6 om vi släpper in stat-plagg – se §3.2 lag 2. |
| **Läsbarhet** | 6 | **7** | Kvittot (`TOWN §B.3`) gör grovjobbet. Gear-effekter måste in i kvittot, annars **faller läsbarheten till 5** – det är den enda riktiga risken i förslaget. |
| **Replayability** | 3 | **7** | 22 föremål × 7 slots × 4 hjältar × slumpad droptur = runs som skiljer sig innan de börjar. Samlingsräknaren "17 / 22" är en egen anledning att starta om. |
| **Progressionskänsla** | **2** | **8** | Från "en osynlig poolpost per session" till fyra parallella spår: sida (per rum), gear (per strid), hjältenivå (per run), byggnad (per session). |

---

## 8. Beslut som behövs av Anders

| # | Fråga | Mitt förslag |
|---|---|---|
| 1 | Blir reliker gear i 7 kroppsslots? | **Ja.** Billigast möjliga väg till loot. |
| 2 | Får gear ge stigande siffror (HP, omkast, rustning)? | **Ja, men bara `COMMON`, och all styrka dör med hjälten.** Ändrar `TOWN §A.3`. |
| 3 | Förlorar man osäkrat gear vid död? | **Ja**, med Kistan som räddar 1–3 föremål efter spelarens val. |
| 4 | Hjälteroster med permadöd, max 4 platser? | **Ja.** Färre platser, starkare band (Gemsbok-kritiken). |
| 5 | Ska Pips sluta köpa poolposter? | **Ja.** De köper byggnader, uppgraderingar och gear. |
| 6 | Stress/quirks? | **Quirks ja (1 per hjälte), stress nej.** |

---

## Källor (hämtade 2026-09-22)

- The Gemsbok, *A Mechanical Critique of Darkest Dungeon* (rostrets storlek urvattnar karaktärerna; sent spel blir optimeringsgrind): https://thegemsbok.com/art-reviews-and-articles/darkest-dungeon-red-hook-critique-mechanics-design/
- Metacritic, *Darkest Dungeon* användarrecensioner (grind, tempo, "för grunt för 50+ runs"): https://www.metacritic.com/game/darkest-dungeon/user-reviews/
- Steam Community, DD-diskussioner om stressrotationens tjatighet: https://steamcommunity.com/app/262060/discussions/0/1836811737981213706
- Darkest Dungeon Wiki, *Trinkets* (sällsynthet, tappas vid död, förloras vid reträtt): https://darkestdungeon.wiki.gg/wiki/Trinkets_(Darkest_Dungeon)
- Darkest Dungeon Wiki, *Hamlet* (byggnadsuppgraderingar, Stage Coach/Hero Barracks): https://darkestdungeon.wiki.gg/wiki/Hamlet · GameFAQs, *Your Hamlet*: https://gamefaqs.gamespot.com/pc/804193-darkest-dungeon/faqs/76087/your-hamlet
- TheGamer, *Top 10 Hamlet Upgrades In Darkest Dungeon* (vad spelare uppgraderar först): https://www.thegamer.com/darkest-dungeon-best-hamlet-upgrades/
- Wikipedia, *Darkest Dungeon* ("Heroes will die. And when they die, they stay dead."): https://en.wikipedia.org/wiki/Darkest_Dungeon
- Wikipedia, *Loot (video games)* (Diablo tog färgkodad sällsynthet från Angband; färg = omedelbar värdeavläsning): https://en.wikipedia.org/wiki/Loot_(video_games)
- indieklem, *What you can learn from the UI design of World of Warcraft* (färgkodad loot och dopaminspiken): https://indieklem.com/12-what-you-can-learn-from-the-ui-design-of-world-of-warcraft/
- Pixel Dungeon Wiki, *Scroll of Upgrade* (11–13 per run; knapp resurs gör +1 på *ditt* vapen till ett beslut): https://pixeldungeon.fandom.com/wiki/Scroll_of_Upgrade
- PC Gamer, *Unlock these Vampire Crawlers upgrades first* (Inn-platser som första prioritet; poncle 2026): https://www.pcgamer.com/games/roguelike/vampire-crawlers-best-upgrades-unlock-order/
- GameDev.net, *Avoiding grinding in a Darkest Dungeon-like game* (utvecklardiskussion om DD:s grindfälla): https://gamedev.net/forums/topic/687015-avoiding-grinding-in-darkest-dungeon-like-game/
- Internt: `docs/GAME_DESIGN.md §4/§7`, `docs/design/TOWN_AND_ONBOARDING.md §A.3/§B.3`, `docs/design/CORRIDOR_DESIGN.md §1.3/§2.5`, `docs/research/01_engagement_mekanik.md §A/§C/§E`, `src/core/meta.gd`, `src/data/content.gd`.

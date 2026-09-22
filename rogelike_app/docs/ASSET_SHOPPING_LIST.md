# PIPWRECK – Inköpslista för assets (allt gratis, kommersiellt OK)

**För:** Anders, som laddar ner manuellt · **Sammanställd av:** rnd-roguelike · **Datum:** 2026-09-22
**Alla länkar hämtade/verifierade via sökning 2026-09-22.** Proxyn i utvecklingsmiljön blockerar fulltext från `opengameart.org`, `itch.io`, `kenney.nl`, `ambientcg.com` och `screamingbrainstudios.com` — licenserna nedan kommer därför i många fall från sökutdrag. Varje sådan rad är märkt **[verifiera på sidan]**. Läs licensrutan på sidan innan du laddar ner.

---

## 0. LICENSREGELN – läs denna först

### ✅ OK att ta in i repot
| Licens | Vad det kräver av oss |
|---|---|
| **CC0 1.0** / "public domain" / "Public Domain (CC0)" | Ingenting. Får ändå loggas i `assets/ASSET_LICENSES.csv`. |
| **CC-BY 3.0** och **CC-BY 4.0** | Namn + källa + licens i vår credits-skärm (beslutad i `DECISIONS.md` 2026-09-22, byggs i M6). |
| **OFL 1.1** (fonter) | Copyrightnotisen ska följa med kopian; fontfilen får inte säljas separat. Vi gör redan detta för Anton/Familjen Grotesk. |

### ⛔ ALDRIG in i repot
| Licens | Varför |
|---|---|
| **CC-BY-SA** (alla versioner) | ShareAlike smittar bearbetat konstverk; vi ompaletterar allt via palett-LUT ⇒ blir *Adapted Material*. Dessutom DRM-tvetydigheten mot App Store (`docs/research/04 §1`). |
| **GPL 2/3 på grafik** | Oprövat men asymmetrisk risk. Wesnoth är typexemplet — se §1.9. |
| **CC-BY-NC / "free for non-commercial"** | Vi kör annonser + eventuell betalversion = kommersiellt. |
| **"Free, credit the itch page"** utan skriven licenstext | Otydliga villkor = nej. Undantag: sidor som *skriver ut* att kommersiellt bruk är tillåtet (se §0.1). |

### 0.1 Gråzon som jag listar men flaggar
Flera itch-skapare använder **egen licenstext** i stil med *"free for commercial use, do not redistribute the assets themselves"*. Det är juridiskt fullt användbart men är varken CC0 eller CC-BY. De raderna är märkta **[egen licens – ej CC]** och kräver att du **sparar en skärmdump/kopia av licenstexten** i `KÄLLA.txt`, eftersom itch-sidor kan ändras.

### 0.2 En sak PM måste besluta
`docs/research/04 §Rekommendation 1` och `assets/incoming/README.md` tillåter redan **OGA-BY 3.0** (OpenGameArts egen BY-licens, skapad just för att tillåta DRM-plattformar). Briefen till mig listar bara CC0/CC-BY/OFL. Flera bra monsterpaket (Redshrike, CraftPix på OGA) är CC-BY 3.0 **eller** OGA-BY 3.0 — dubbel-licensierade, så vi kan alltid välja CC-BY-grenen. **Jag har därför valt CC-BY-grenen överallt och behöver inget nytt beslut.** Men om ett paket är *enbart* OGA-BY är det tillåtet enligt vår egen regel och otillåtet enligt briefen — se §1.10.

---

## 1. Monster frontalt (viktigast, svårast)

**Problemet:** nästan all gratis fantasy-pixelgrafik är 3/4 top-down (roguelike-tiles) eller sidovy (plattformare). Äkta *frontala battlers* i Etrian/Wizardry-anda finns nästan bara som (a) 1-bit/monokroma roguelike-silhuetter, (b) RPG-Maker-battlers med CC-BY-SA, eller (c) betalpaket. Den enda källan som är både frontal, CC0 och stor nog är **Hexany Ives**.

Kom ihåg `CORRIDOR_DESIGN §3.1`: vi visar monstret som **silhuett först**, sedan fyller vi den med färg. Ett 1-bit-monster är en *färdig silhuett* — det är därför kandidat 1.1 är så mycket bättre för oss än den ser ut på papperet.

| # | Paket & länk | Skapare | Licens (som källan skriver den) | Upplösning/stil | Vad som ingår | Passform PIPWRECK |
|---|---|---|---|---|---|---|
| 1.1 ★ | [Hexany's Monster Menagerie](https://hexany-ives.itch.io/hexanys-monster-menagerie) | Hexany Ives | "CC0 1.0 Universal license, so you are free to use it for any commercial and non-commercial projects" **[verifiera på sidan]** | 32×32, monokrom 1-bit, **statiska** | **64 varelser**; sidan säger uttryckligen att de kan användas som "JRPG/First Person Dungeon Crawl battlers" | **Bästa träffen i hela listan.** 1-bit = ren silhuett ⇒ silhuett-takten i §3.1 blir gratis, och färgen sätts av vår palett-LUT-shader så stilen blir vår, inte deras. 64 fiender täcker M5–M8 utan nytt inköp. |
| 1.2 ★ | [Hexany's Roguelike Tiles](https://hexany-ives.itch.io/hexanys-roguelike-tiles) | Hexany Ives | "CC0 1.0 Universal license … free to use it for any commercial and non-commercial projects" **[verifiera på sidan]** | 16×16, monokrom 1-bit | 60+ generella tiles, 70+ item-tiles, **150+ varelse-tiles**, autotile-väggar/vätskor/gropar | Samma hand som 1.1 ⇒ **stilenhet gratis**. 150 varelser till i mindre format = ikoner, kodex-bilder, fjärrsilhuetter i korridoren. Ta båda eller ingen. |
| 1.3 | [Dungeon Crawl 32x32 tiles](https://opengameart.org/content/dungeon-crawl-32x32-tiles) | DCSS-teamet (många konstnärer, uppladdat av Medicine Storm/Chris Hamons m.fl.) | "CC0" **[verifiera på sidan]** | 32×32, färg, **3/4 snett uppifrån** | 3000+ tiles ur Dungeon Crawl Stone Soup: monster, items, effekter, GUI, terräng | Enormt monsterbibliotek, noll attribution. **Men vinkeln är fel** — ett DCSS-monster tittar snett nedåt-höger och läser inte som "den står framför dig". Användbart för *ikoner, kodex, item-art*, inte som stridsmonster utan ommålning. |
| 1.4 | [Dungeon Crawl 32x32 tiles supplemental](https://opengameart.org/content/dungeon-crawl-32x32-tiles-supplemental) | DCSS-teamet | "CC0" **[verifiera på sidan]** | 32×32 | ytterligare 3000+ tiles (spells, effekter, monster, items, spelaravatarer) | Samma som 1.3. Ta bara om 1.3 inte räcker. |
| 1.5 | [Snowdrama/CC0-Dungeon-Pack (GitHub)](https://github.com/Snowdrama/CC0-Dungeon-Pack) | Snowdrama (bundling av DCSS) | "CC0 applies to all assets… If you want to give credit just link to the Dungeon Crawl Stone Soup open game art, or the DCSS site" (läst direkt 2026-09-22) | 32×32 | Samma DCSS-tiles men **sorterade i mappar** (dungeon/effects/player/monsters/item/gui) | **Ladda ner den här i stället för 1.3/1.4** om proxyn eller OGA krånglar — `git clone` funkar, innehållet är identiskt och redan sorterat. |
| 1.6 | [DENZI's public domain art](https://opengameart.org/content/denzis-public-domain-art) | DENZI | "CC0" / public domain **[verifiera på sidan]** | mest 32×32, 3/4 ortogonal | Dungeon-tiles, monster, items, förmågeikoner | Bra kompletteringsbank. **Varning:** DENZIs *andra* inlägg, [32x32 orthogonal tilesets](https://opengameart.org/content/denzis-32x32-orthogonal-tilesets), är **CC-BY-SA** enligt sökutdrag ⇒ ta inte fel sida. |
| 1.7 | [6 More RPG Enemies](https://opengameart.org/content/6-more-rpg-enemies) | Redshrike (Stephen Challener), m. LordNeo & Blarumyrran | "CC-BY 3.0 och OGA-BY 3.0" **[verifiera på sidan]** — välj **CC-BY 3.0** | pixel, RPG-battler-format | 6 fiender: orch, troll, tentakelvidunder m.m. | Färgad JRPG-fiendestil, rätt "monster står framför dig"-läsning. Liten mängd, men **bra bosskandidater** (`SLAGJAW`). Kräver credits-rad. |
| 1.8 | [More RPG enemies!](https://opengameart.org/content/more-rpg-enemies) | Redshrike | "CC-BY 3.0, CC-BY-SA 3.0, OGA-BY 3.0" — **licenserna är fristående, välj CC-BY 3.0** (OGA-kommentar i sökutdrag) **[verifiera på sidan]** | pixel | fler fiender i samma hand som 1.7 | Samma som 1.7. Se till att du i `KÄLLA.txt` skriver "vi använder CC-BY 3.0-grenen". |
| 1.9 | [Roguelike Tiles (large collection)](https://opengameart.org/content/roguelike-tiles-large-collection) | David E. Gervais | "Creative Commons v3 CC-BY" (enl. RogueBasins beskrivning) **[verifiera på sidan]** | 32×32 (+ 54×54 isometriskt) | Vapen, rustning, items, **monster**, stads- och dungeon-tiles från Angband/ToME | Väldigt komplett och gammaldags i tonen. 3/4-vinkel som 1.3. Bäst till **gear-art för de 22 föremålen**, näst bäst till monster. |
| 1.10 | [Pixel Art RPG Monster Sprites](https://opengameart.org/content/pixel-art-rpg-monster-sprites) | CraftPix.net 2D Game Assets | **"OGA-BY 3.0"** **[verifiera på sidan]** | pixel | monsterset | Tillåten enligt `research/04` men **inte** enligt briefens lista — se §0.2. Ta bara efter PM-OK. |
| 1.11 | [Ninja Adventure – Asset Pack](https://pixel-boy.itch.io/ninja-adventure-asset-pack) | Pixel-Boy & AAA (Sparklin Labs) | "released under the Creative Commons Zero (CC0) license… even commercial ones. Attribution is not required but appreciated" **[verifiera på sidan]** | 16×16-ish, färgglad top-down | 50+ karaktärer, **30+ monster**, **9 bossar**, 60+ items, tilesets, 100+ SFX, 37 musikspår | Fel ton (ljus/söt anime) men **gratis komplett värld** — bra som reservbank för items/SFX/musik. Monstren skulle behöva mörkas rejält. |
| 1.12 | [Openmon Monster Sprites Set 1](https://screensmith.itch.io/openmon-monster-sprites-set-1) | Screen Smith | "released under a CC0 License… full rights transferred" **[verifiera på sidan]** | **64×64 battle sprites, frontalvy** | 18 monster (starter-linje) | Rätt format och rätt vinkel, men Pokémon-söt stil. Listas för fullständighet; passar PIPWRECK dåligt utan ommålning. |
| 1.13 | [0x72 – 16x16 DungeonTileset II](https://0x72.itch.io/dungeontileset-ii) | 0x72 | CC0 (redan verifierad i `research/04 §1`) | 16×16 (vapen/stora fiender upp till 32×32) | ~20 animerade monster, 4 hjältar, vapen som separata sprites, kistor, dekor | Redan vårt beslutade M1-underlag. Sidovy/frontal-blandat — **animerade** monster är dess styrka. |
| 1.14 | [RPG Fantasy Battlers](https://limezu.itch.io/fantasy-battlers) | LimeZu | Oklart: sökutdrag säger både "CC-BY … credit LimeZu" och "the free version doesn't allow you to use assets for commercial projects" **[verifiera på sidan — RÖD FLAGGA]** | pixel, **frontala battlers** | 31 battlers + recolor + gråskala + skugga | Formatet är exakt vad vi vill ha (*"a collection of frontal enemies for your turn-based RPG"*). **Ladda inte ner förrän licensrutan lästs.** Om gratisversionen är icke-kommersiell: hoppa över. |

### 1.9b ⛔ Fällor i den här kategorin – ladda INTE ner
| Paket | Licens | Varför nej |
|---|---|---|
| [First Person Dungeon Crawl Art Pack](https://opengameart.org/content/first-person-dungeon-crawl-art-pack) (Heroine Dusk) | **CC-BY-SA 3.0** — Heroine Dusks README: *"The visual art for Heroine Dusk is released under CC-BY-SA 3.0, with later versions permitted"* (läst direkt på [github.com/clintbellanger/heroine-dusk](https://github.com/clintbellanger/heroine-dusk), 2026-09-22) | Detta är tekniskt sett **det perfekta paketet** (Clint Bellanger, 160×120-tiles i kon-form, DawnBringer-16-palett, fiender som stillbilder för turbaserad strid). Och det är förbjudet enligt vår regel. Sorgligt men klart. |
| [First Person Dungeon Crawl Enemies Remixed](https://opengameart.org/content/first-person-dungeon-crawl-enemies-remixed) | **CC-BY-SA 3.0** **[verifiera på sidan]** | Derivat av ovan, ärver SA. |
| [Old School Front Battle Enemy Sprites](https://opengameart.org/content/old-school-front-battle-enemy-sprites) | **CC-BY-SA 3.0** **[verifiera på sidan]** | Frontala battlers med idle/hit/special/die — men SA. |
| [First Person Dungeon Crawl – More Tilesets](https://opengameart.org/content/first-person-dungeon-crawl-more-tilesets) / [Industrial Pack](https://opengameart.org/content/first-person-dungeon-crawl-industrial-pack) / [Protagonist](https://opengameart.org/content/first-person-dungeon-crawl-protagonist) | Sannolikt CC-BY-SA (Heroine Dusk-derivat) **[verifiera på sidan]** | Kontrollera varje sida; är den SA så nej. |
| Battle for Wesnoth-grafik | "Most art and music … is licensed under the GNU GPL v2+, however new contributions are now licensed under the Creative Commons BY-SA v4.0" ([wiki.wesnoth.org/Wesnoth:Copyrights](https://wiki.wesnoth.org/Wesnoth:Copyrights), 2026-09-22) | GPL **eller** CC-BY-SA. Båda förbjudna. Samma källa noterar att App Store-distribution av Wesnoth i sig anses GPL-stridig — precis vår risk. |
| Universal LPC Spritesheet Generator | Split CC0/CC-BY/CC-BY-SA/OGA-BY/GPL | Redan struket i `research/04 §Rek. 2`. |

---

## 2. Hjälte, porträtt och paperdoll

Behovet enligt `CORRIDOR_DESIGN §4.1`: **en figur centrerad på ~52 % av skärmhöjden**, plus ett lager per utrustad slot (7 slots i `PROGRESSION_REDESIGN §3.1`: HEAD/CHEST/HANDS/WEAPON/LEGS/BACK/AMULET), plus **porträtt vid könsvalet** (vi har i dag egna 96×96).

| # | Paket & länk | Skapare | Licens (källans ordalydelse) | Upplösning/stil | Ingår | Passform |
|---|---|---|---|---|---|---|
| 2.1 ★ | [Fantasy Portrait Pack](https://opengameart.org/content/fantasy-portrait-pack-by-ravenmore) | Ravenmore (Daniel Kvarfordt) | "CC-BY 3.0" **[verifiera på sidan]** | **256×256, 128×128, 64×64**, handmålat | 4 porträtt: människa, alv, dvärg, gnom | Handmålad, mörk, "Darkest Dungeon-nära" ton. Bara 4 st ⇒ räcker till könsvalet + Marrow/Hob, inte mer. Kräver credits. |
| 2.2 | [Paperdoll Characters (template)](https://opengameart.org/content/paperdoll-characters-template) | (OGA-användare) | "CC0" **[verifiera på sidan]** | pixel | Man- och kvinnomall för paperdoll | **Mall, inte färdig konst** — men exakt rätt idé för vårt `Sprite2D`-per-lager-kontrakt (48×48, 8×4). Bra utgångspunkt att rita gear-lager ovanpå. |
| 2.3 | [Simple 2D Human Paperdoll / Ragdoll / Rider Character](https://opengameart.org/content/simple-2d-human-paperdoll-ragdoll-rider-character) | (OGA-användare) | "CC0" **[verifiera på sidan]** | pixel | Kompositkropp + klädlager + backwear | Visar hur lagren ska separeras. Motivet (motorcykelförare) är fel, tekniken rätt. |
| 2.4 | [Cute Heroes](https://opengameart.org/content/cute-heroes) | Justin Nichol | "CC-BY 4.0" **[verifiera på sidan]** | illustrationer | 16 hjälteklass-ikoner, del av en serie på 90+ figurer | Justin Nichols **enda** breda serie som inte är SA. Stilen är "cute", alltså fel för PIPWRECK — listad eftersom briefen bad om honom. |
| 2.5 | [CC0 Portraits (samling)](https://opengameart.org/content/cc0-portraits) | OGA-samling | CC0 (samlingsfilter) **[verifiera per post]** | blandat | Samlingssida med enbart CC0-porträtt | **Använd denna som bläddringsyta.** Varje post har egen licens — samlingen påstår CC0, kontrollera ändå. |
| 2.6 | [Character portrait kit](https://opengameart.org/content/character-portrait-kit) | (OGA-användare) | **[verifiera på sidan]** | modulärt | Byggbart porträtt (ansikte + hår + utrustning) | Modulärt porträtt matchar paperdoll-tanken: porträttet kan spegla utrustad gear. |
| 2.7 | [Free – 12 Fantasy Character Portraits (pixel art)](https://apyryon.itch.io/fantasyportraits) | ApyrYon | "use in any game project, personal or commercial. Credit is not required but appreciated… you can modify" **[egen licens – ej CC]** **[verifiera på sidan]** | pixelporträtt | 12 karaktärer | Pixel, passar vår sprite-sida bättre än 2.1. Spara licenstexten. |
| 2.8 | [Fantasy Character Portraits Pack](https://magory.itch.io/fantasy-portraits) | Magory | **[verifiera på sidan]** | porträtt | porträttpack | Verifiera först; listad som alternativ. |

**⛔ Nej i denna kategori:** [Flare Portrait Pack 1](https://opengameart.org/content/flare-portrait-pack-number-one), [4](https://opengameart.org/content/flare-portrait-pack-number-four), [5](https://opengameart.org/content/flare-portrait-pack-number-five) av Justin Nichol — "CC-BY-SA 3.0, GPL 3.0, GPL 2.0" **[verifiera på sidan]**. Det är de snyggaste porträtten på hela OGA och vi får inte använda dem.

---

## 3. Korridor- och dungeon-texturer

Detta är kategorin där vi har **tur**: det finns ett CC0-paket byggt exakt för 2D-förstapersonskorridorer, med väggar renderade i flera storlekar så att man kan bygga djupled utan 3D.

| # | Paket & länk | Skapare | Licens (källans ordalydelse) | Upplösning/stil | Ingår | Passform |
|---|---|---|---|---|---|---|
| 3.1 ★★ | [Old School Dungeon Crawler Pack](https://screamingbrainstudios.itch.io/dungeon-crawler-pack) (även på [OpenGameArt](https://opengameart.org/content/old-school-dungeon-crawler-pack) och [egen sida](https://screamingbrainstudios.com/dl-first-person-dungeon-crawler/)) | Screaming Brain Studios | "All assets in this pack have been released under the Public Domain (CC0) license, and are free to use however you like in any project, commercial or non-commercial" **[verifiera på sidan]** | renderad sten, flera storlekar per tile | **189 delar**: ljus/mellan/mörk tegelvägg (4 väggar + 2 golv + 2 tak vardera), dörr, stort fönster, 2 små fönster per variant | **Ladda ner den här först.** Den är gjord för *"2D First Person Dungeon Crawlers"*, tiles är renderade med minimal ljussättning så vi kan mörklägga dem själva — exakt `CORRIDOR_DESIGN §2.4` ("mörkret är frånvaro av ritning"). Tre tegelvarianter = tre våningar utan att stilen bryts. |
| 3.2 ★ | [Cave Walls Addon (samma sida)](https://screamingbrainstudios.itch.io/dungeon-crawler-pack) | Screaming Brain Studios | Samma CC0 **[verifiera på sidan]** | samma | 9 grottvarianter (rå sten, kalksten, marmor, svavel, orange sten, koppar, sandsten, öken, skiffer), var och en 4 väggar + 2 golv + 2 tak | Gropen-djupet i `GAME_DESIGN`. Svavel/koppar/slagg-tonerna är rätt för PIPWRECKs smedjetema. |
| 3.3 | [ambientCG](https://ambientcg.com/list?q=stone) | Lennart Demes | "CC0 … free for personal and commercial use" **[verifiera på sidan]** | riktiga PBR-texturer, upp till 8K | 2000+ material; sök "Bricks", "Rock", "Ground", "Metal" | Om vi vill ha en **riktig** väggtextur med normalmap i korridoren i stället för renderad tile. Ladda 1K/2K — 8K är meningslöst på mobil. |
| 3.4 | [Poly Haven – Stone Brick Wall 001](https://polyhaven.com/a/stone_brick_wall_001) · [alla vägg-texturer](https://polyhaven.com/textures/brick/wall) | Poly Haven | "All our assets are released under the CC0 license… You can use them for absolutely any purpose, including commercial work. You do not need to give credit" ([polyhaven.com/license](https://polyhaven.com/license), 2026-09-22) | PBR upp till 16K | grov väderbiten sten med djupa fogar | Enskilda, mycket högkvalitativa texturer. Perfekt till **bossdörren** och till skyltplattan. |
| 3.5 | [3dtextures.me](https://3dtextures.me/) | João Paulo (3DTextures) | "You can use the textures for any purpose, including commercial. You do not need to give credit… all of their textures and 3D models are currently available to use under CC0" ([3dtextures.me/about](https://3dtextures.me/about/), 2026-09-22) | seamless PBR | t.ex. [Wall Stone 037](https://3dtextures.me/2026/05/12/wall-stone-037-free-seamless-pbr-texture/) | Bra komplement till 3.3/3.4, ofta mindre filer. |
| 3.6 | [ShareTextures](https://www.sharetextures.com/) | ShareTextures | "custom CC0-based license… free for personal, educational, or commercial projects. No attribution required" men **"No asset redistribution … without written permission"** ([sharetextures.com/p/license](https://www.sharetextures.com/p/license), 2026-09-22) | PBR | sten, trä, metall | **[egen licens – ej rent CC0]**. OK för oss (vi distribuerar inte texturen, vi visar den), men spara licenstexten. |
| 3.7 | [Kenney – Tiny Dungeon](https://kenney.nl/assets/tiny-dungeon) · [1-Bit Pack](https://kenney.nl/assets/1-bit-pack) | Kenney | CC0 1.0 Universal (verifierat i `research/04 §1`) | 16×16 | tiles, vapen, items, karaktärer, UI | Redan i vår plan. **1-Bit Pack matchar Hexany-monstren (§1.1) stilmässigt** — samma monokroma grund. |
| 3.8 | [JS FPRPG Texture Pack 01](https://opengameart.org/content/js-fprpg-texture-pack-01) | (OGA-användare) | **[verifiera på sidan]** | texturer för förstapersons-RPG | väggar/golv | Nischad exakt mot vår användning; licens okänd i sökutdrag. |
| 3.9 | [0x72 – DungeonTileset II](https://0x72.itch.io/dungeontileset-ii) | 0x72 | CC0 (verifierad i `research/04`) | 16×16 | miljötiles, dekor, kistor | Redan beslutad. Bäst till **props** i korridoren (fackla, vrak, ben). |

---

## 4. Gear- och item-ikoner (vi behöver ~22 + slots + rariteter)

`PROGRESSION_REDESIGN §3.5` listar 22 föremål över 7 slots med 4 rariteter. Vi behöver alltså **22 distinkta ikoner + 7 slot-glyfer + 4 raritetsramar**. Det billigaste och mest stilenhetliga sättet: ett vektor-ikonbibliotek som vi färgar själva.

| # | Paket & länk | Skapare | Licens (källans ordalydelse) | Upplösning/stil | Ingår | Passform |
|---|---|---|---|---|---|---|
| 4.1 ★★ | [game-icons.net](https://game-icons.net/) · [licens/om](https://game-icons.net/about.html) | Lorc, Delapouite, Skoll, m.fl. | "The icons are provided under the terms of the Creative Commons 3.0 BY license"; attribution: *"Icons made by [author]. Available on https://game-icons.net"* **[verifiera på sidan]** | **4180 SVG + PNG**, vit/svart/transparent | Vapen, rustning, smycken, monster, statustillstånd, GUI | **Vinnaren för gear.** SVG ⇒ vi kan rendera i exakt vår upplösning och färga per raritet (benvit/koppar/blå/lila enligt §3.3) med en enda `modulate`. Alla 22 föremål går att täcka från en och samma hand ⇒ noll stilspret. En rad i credits räcker för hela biblioteket. |
| 4.2 | [700+ RPG Icons](https://opengameart.org/content/700-rpg-icons) | Lorc | "CC-BY 3.0" **[verifiera på sidan]** | svartvita, skalbara | 789 ikoner, mest traditionell fantasy | Ursprunget till 4.1. Ta denna om du vill ha en offline-zip i stället för att klicka i webbläsaren. |
| 4.3 ★ | [Fantasy Icon Pack 2.0](https://opengameart.org/content/fantasy-icon-pack-by-ravenmore-0) | Ravenmore (Daniel Kvarfordt) | "CC-BY 3.0", särskild instruktion: *"drop a link to ravenmore.itch.io"* **[verifiera på sidan]** | **512×512, 128×128, 64×64 PNG + PSD-källa** | 29 handmålade ikoner (yxa, båge, pilar, rustning, verktyg, hammare…) | Handmålade, mörka, hög kvalitet. **Rätt ton för "gear som känns värdefullt"** i belöningsceremonin (`§3.3`). Bara 29 st ⇒ använd till de 8 bästa dropparna (t.ex. `SLAGJAW_TOOTH`, `SIXTH_SEAT`), resten från 4.1. |
| 4.4 | [Kenney – Game Icons](https://kenney.nl/assets/game-icons) + [Game Icons (Expansion)](https://kenney.nl/assets/game-icons-expansion) | Kenney | CC0 **[verifiera på sidan]** | vektor/PNG | 105 + 60 ikoner | Systemikoner (ljud, paus, inställningar), inte fantasy-gear. Komplement till vårt befintliga UI. |
| 4.5 | [Shikashi's Fantasy Icons Pack (FREE)](https://cheekyinkling.itch.io/shikashis-fantasy-icons-pack) · [600+-versionen](https://shikashipx.itch.io/shikashis-600-icon-pack) | Matt Firth (cheekyinkling / Shikashi) | "You can use and edit these icons for commercial games and projects"; många ikoner bygger på game-icons.net (CC BY 4.0) ⇒ kräver credit till **"Matt Firth (cheekyinkling)"** *och* **"game-icons.net"** **[verifiera på sidan]** | **32×32 pixel**, spritesheet | 229 unika + 55 recolors = 284 ikoner | **Pixelvarianten av 4.1** och därmed stilmässigt närmare våra egna 16×16-ikoner. Bra kandidat om vi vill hålla allt i pixel. |
| 4.6 | [FREE RPG Icon Pack – 100 accessories & armor](https://clockworkraven.itch.io/free-rpg-icon-pack-100-accessories-and-armor-clockwork-raven-studios) | Clockwork Raven Studios | "use on any project (commercial or personal)… without needing attribution. You cannot distribute a modified or original copy of this product" **[egen licens – ej CC]** **[verifiera på sidan]** | pixel | 100 tillbehörs- och rustningsikoner | **Exakt vår kategori** (accessories + armor = AMULET/CHEST/HEAD). Spara licenstexten i `KÄLLA.txt`. |
| 4.7 | [Basic RPG Item Icons (Free)](https://opengameart.org/content/basic-rpg-item-icons-free) | (OGA-användare) | **[verifiera på sidan]** | pixelikoner | grundläggande items | Verifiera först. |
| 4.8 | [RPG icons Asset pack](https://opengameart.org/content/rpg-icons-asset-pack) · [Fantasy RPG Icons](https://opengameart.org/content/fantasy-rpg-icons) | (OGA-användare) | **[verifiera på sidan]** | blandat | ikonsamlingar | Reserv. |

---

## 5. UI-ramar, knappar, paneler

Vi har redan ett krit-UI (`UI_GUIDE`). Behovet är smalt: **9-slice-ramar för belöningskort och character sheet**, plus slot-konturer.

| # | Paket & länk | Skapare | Licens | Ingår | Passform |
|---|---|---|---|---|---|
| 5.1 ★ | [Fantasy UI Borders](https://kenney.nl/assets/fantasy-ui-borders) ([itch-spegel](https://kenney-assets.itch.io/fantasy-ui-borders)) | Kenney | CC0 1.0 Universal **[verifiera på sidan]** | **140 assets**, 130+ sprites, uttryckligen gjorda för **9-slice** | Exakt det vi behöver till belöningskortens raritetsramar (`§3.3`) och slot-rutorna i character sheet. |
| 5.2 | [UI Pack (RPG Expansion)](https://kenney.nl/assets/ui-pack-rpg-expansion) ([OGA-spegel](https://opengameart.org/content/ui-pack-rpg-extension)) | Kenney | CC0 **[verifiera på sidan]** | 85 assets, RPG/fantasy-element | Knappar, paneler, ikonramar i samma hand som 5.1. |
| 5.3 | [UI Pack](https://kenney.nl/assets/ui-pack) | Kenney | CC0 **[verifiera på sidan]** | **430 assets** | Grundbiblioteket: knappar, reglage, kryssrutor, staplar (HP-chips). |
| 5.4 | [UI Pack – Adventure](https://kenney.nl/assets/ui-pack-adventure) | Kenney | CC0 **[verifiera på sidan]** | 130 assets | Äventyrston, alternativ till 5.2. |
| 5.5 | [Parchment – 2D vector-based UI for fantasy games](https://denizen-games.itch.io/parchment-2d-vector-based-ui-for-fantasy-games) | Denizen Games | "CC BY 4.0" **[verifiera på sidan — kontrollera även om paketet är gratis]** | vektor-UI för fantasyspel | Vektor ⇒ skalar till 1080×1920 utan artefakter. Pergamenttonen ligger nära vår krit/ben-palett. |
| 5.6 | [UI Pack (OGA-spegel)](https://opengameart.org/content/ui-pack) | Kenney (uppladdad till OGA) | CC0 **[verifiera på sidan]** | samma som 5.3 | Använd om kenney.nl är segt. |

---

## 6. Ljud (SFX)

Vi genererar i dag alla 22 ljud med `tools/gen_sfx.py`. Behovet nu är **materialljud** som ett syntverktyg inte gör bra: steg på sten, dörrar, monsterläten, metall mot metall.

| # | Källa & länk | Skapare | Licens (källans ordalydelse) | Ingår | Passform |
|---|---|---|---|---|---|
| 6.1 ★ | [Kenney – RPG Audio](https://kenney.nl/assets/rpg-audio) | Kenney | "CC0 1.0 Universal… Kenney has waived all copyright, so no credit is legally required even in a commercial, paid game" **[verifiera på sidan]** | 50 ljud | Svärdshugg, bågskott, handelsljud. Rakt in i `enemy_attack` / `damage_hit`. |
| 6.2 ★ | [Kenney – Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney | CC0 **[verifiera på sidan]** | 130 ljud | Träffar och nedslag — `SLAGJAW`s käftar, `IRON_TICK`s mur. |
| 6.3 | [Kenney – Interface Sounds](https://kenney.nl/assets/interface-sounds) | Kenney | CC0 **[verifiera på sidan]** | 100 ljud (klick, snaps, bekräftelser) | Alternativ till vårt `ui_tap.wav` om det känns torrt. |
| 6.4 ★ | [RPG Sound Pack](https://opengameart.org/content/rpg-sound-pack) | artisticdude | "CC0 … basically the same as public domain" **[verifiera på sidan]** | Klassiskt OGA-paket: 37 hits/punches, monsterläten, miljöljud | **Monsterlätena** är det vi saknar mest. `monster_far` och `monster_reveal` (§3.1) ska komma härifrån. |
| 6.5 | [80 CC0 RPG SFX](https://opengameart.org/content/80-cc0-rpg-sfx) · [50 RPG sound effects](https://opengameart.org/content/50-rpg-sound-effects) · [Battle Sound Effects](https://opengameart.org/content/battle-sound-effects) | div. OGA | **[verifiera per post]** | 80 / 50 / div. | Bank att plocka ur. Kontrollera licens per post — OGA blandar. |
| 6.6 ★ | [Freesound – CC0-filtrerad sökning](https://freesound.org/search/?q=dungeon+ambience&f=license%3A%22Creative+Commons+0%22) | community | CC0 per ljud (filtret garanterar det) **[verifiera per ljud]** | 700 000+ ljud totalt | **Sökord att använda:** `dungeon ambience`, `footsteps stone`, `stone door`, `chain rattle`, `anvil hammer`, `dice roll`, `torch fire loop`, `water drip cave`, `cart wheels wood`. Lägg alltid till filtret `license:"Creative Commons 0"` i URL:en. Exempel på post: [Creepy Dungeon Ambience (DrMinky)](https://freesound.org/people/DrMinky/sounds/166187/) **[verifiera licensen på just den posten]**. |
| 6.7 | [Sonniss GDC Game Audio Bundle](https://gdc.sonniss.com/) · [licenstexten](https://sonniss.com/gdc-bundle-license/) | Sonniss + deltagande ljudbibliotek | "worldwide, non-exclusive, royalty-free license … personal and commercial projects … no attribution required"; **"Use for AI/ML training is strictly prohibited"**; individuella ljud får ej säljas vidare. Licensversion **2.0, i kraft 2026-08-27** **[verifiera på sidan]** | 7,47 GB+ i 2026-bundeln | Professionell foley i hög kvalitet, gratis. Tung nedladdning — ta 2026-bunten och plocka `Footsteps`, `Metal`, `Doors`. |

---

## 7. Musik

Vi har ingen musik alls i dag. `CORRIDOR_DESIGN §2.4` kräver en **ambiens som kan sjunka från −30 till −38 dB** — alltså loopbar ambient, inte melodi.

| # | Källa & länk | Skapare | Licens | Ingår | Passform |
|---|---|---|---|---|---|
| 7.1 ★ | [Incompetech – all musik](https://incompetech.com/music/royalty-free/music.html) · [FAQ/licens](https://incompetech.com/music/royalty-free/faq.html) | Kevin MacLeod | "Creative Commons: By Attribution 4.0" — exakt attributionsformat i §B nedan **[verifiera på sidan]** | 2000+ spår, sökbara på stämning ("Dark", "Creepy", "Mysterious") | Den säkraste musikkällan som finns: enhetlig licens, tydlig attributionsmall, enorm katalog. Ta 1 stadstema + 1 korridorambiens + 1 bosstema. |
| 7.2 ★ | [Alexander Nakarada – Serpent Sound Studios](https://serpentsoundstudios.com/) | Alexander Nakarada (CreatorChords) | "CC BY 4.0 (Attribution 4.0 International)" **[verifiera på sidan]** | Fantasy/mörk orkestral, t.ex. "Dungeons and Dragons", "Vopna" | Mörkare och mer orkestral än MacLeod. Passar `SLAGJAW`-bossen. |
| 7.3 | [Loopable Dungeon Ambience](https://opengameart.org/content/loopable-dungeon-ambience) | (OGA) | CC0 **[verifiera på sidan]** | `dungeon_ambient_1.ogg` — lågfrekvent vind + vattendropp | **Exakt** korridorens baslinje i §2.4. Vattendroppet är dessutom vårt "ny våning"-ljud (§2.4, motsatta regeln). |
| 7.4 | [Dark Cavern Ambient](https://opengameart.org/content/dark-cavern-ambient) · [Dungeon Ambience](https://opengameart.org/content/dungeon-ambience) | (OGA) | "CC0" **[verifiera per post]** | fade-in/out- och loopversioner | Två extra våningsambienser så att alla tre våningar låter olika. |
| 7.5 | [CC0 Fantasy Music & Sounds](https://opengameart.org/content/cc0-fantasy-music-sounds) | OGA-samling | "licensed unter CC0" **[verifiera per post]** | "High quality music for fantasy RPGs (no 8-bit music, chiptunes or similar)" | Bläddringsyta. Ingen attribution ⇒ minst administration. |
| 7.6 | [Open World — Dark Fantasy Ambient Music Pack](https://decaz.itch.io/open-world-ambient-music-pack) | Decaz | **[verifiera på sidan]** | dark fantasy ambient | Rätt genre i namnet; licens okänd i sökutdrag. |
| 7.7 | [FREE Music Pack 12: Ambient](https://arkeiamusic.itch.io/music-pack-12) | Arkeia (tid. Retro Indie Josh) | "Creative Commons Attribution 4.0 International", attributionsexempel: *"Contains music ©2026 Arkeia (https://arkeiamusic.itch.io/)"* **[verifiera på sidan]** | ambientpaket | Färdigt gratis ambientpaket med tydlig CC-BY 4.0. |
| 7.8 | [Free Music Archive – genre Ambient](https://freemusicarchive.org/genre/Ambient) | blandat | **Blandat per spår — många är CC BY-NC (förbjuden för oss)** **[verifiera per spår]** | stor katalog | **Varning:** FMA:s "dark ambient"-träffar är ofta Attribution-**NonCommercial** 4.0. Filtrera hårt på ren CC BY, annars hoppa över källan. |

---

## 8. Partiklar och effekter

`PROGRESSION_REDESIGN §3.3` kräver raritetsceremonier (glimt, kritring, ljuset som slocknar) och `§4.3` kräver vit flash + kritning på figuren.

| # | Paket & länk | Skapare | Licens | Ingår | Passform |
|---|---|---|---|---|---|
| 8.1 ★ | [Kenney – Particle Pack](https://kenney.nl/assets/particle-pack) ([Godot Asset Library](https://godotengine.org/asset-library/asset/783), [OGA](https://opengameart.org/content/particle-pack-80-sprites)) | Kenney | CC0 **[verifiera på sidan]** | **80 sprites** för partiklar, light cookies och shaders; exempel på eld, rök, magi, hjärtan, gnistor, elektricitet | Grunden för alla fyra raritetsceremonier. Finns i Godot Asset Library ⇒ enklast tänkbara import. |
| 8.2 | [Kenney – Smoke Particles](https://kenney.nl/assets/smoke-particles) | Kenney | CC0 **[verifiera på sidan]** | rökpartiklar | Facklan, `EPIC`-ceremonins mörkläggning. |
| 8.3 | [Pixel FX Pack](https://opengameart.org/content/pixel-fx-pack) | (OGA) | **[verifiera på sidan]** | effekter gjorda i Pixel FX Designer | Pixelstil som matchar §1.1/3.7. |
| 8.4 | [Free Pixel Effects Pack](https://codemanu.itch.io/pixelart-effect-pack) | CodeManu | Listas i itch-samlingar som "free for commercial and non-commercial use" **[verifiera på sidan — licenstexten syns inte i sökutdrag]** | FX-pack för pixelspel | Klassikern. Ladda inte ner förrän licensrutan är läst. |
| 8.5 | [cc0 special effects (samling)](https://opengameart.org/content/cc0-special-effects) | OGA-samling | CC0 (samlingsfilter) **[verifiera per post]** | Free Pixel Effects Pack, Hit Animation, Pixel FX Pack, Animated Explosions, Free VFX asset pack | Bläddringsyta för slash/hit. |
| 8.6 | [Explosions, Bullets, Fire etc (Pixel art)](https://opengameart.org/content/explosions-bullets-fire-etc-pixel-art) | OGA-samling | **[verifiera per post]** | bl.a. "Slash hit 01 Animation VFX" | **Slash-effekten** till kedjeresolvningen. |

---

## 9. Fonter

Vi är redan klara: Familjen Grotesk, Anton, Caveat Brush och PIPWRECK Symbols, alla OFL-1.1 (`DECISIONS.md` 2026-09-22). **Rekommendationen är att inte lägga till fler** — fyra typsnitt är redan ett i överkant för en mobilskärm.

Om PM ändå vill ha en mörk-fantasy-display-font *enbart till titelskärmen och boss-introt*, är dessa tre OFL och finns redan i Google Fonts-pipelinen vi använder:

| # | Font & länk | Skapare | Licens | Karaktär | Kommentar |
|---|---|---|---|---|---|
| 9.1 | [Pirata One](https://fonts.google.com/specimen/Pirata+One) | Rodrigo Fuenzalida & Nicolas Massi | SIL Open Font License 1.1 **[verifiera på specimen-sidan]** | Gotisk textura, "förenklad och optimerad för skärm och pixeldisplayer" | **Den enda jag faktiskt rekommenderar** om vi ska ha en. Pixel-optimeringen gör att den inte mosas på 1080 px portrait, och blackletter är genrekoden (MÖRK BORG, D&D-supplement). |
| 9.2 | [Metamorphous](https://fonts.google.com/specimen/Metamorphous) | James Grieshaber / Sorkin Type Co | SIL Open Font License, "free for personal and commercial use" **[verifiera på specimen-sidan]** | Romanskt/gotiskt/renässans-hybrid | Mjukare än 9.1, läsbar i brödtextstorlek. Alternativ om Pirata One är för spetsig. |
| 9.3 | [IM Fell English](https://fonts.google.com/specimen/IM+Fell+English) | Igino Marini | OFL **[verifiera på specimen-sidan]** | Autentiskt 1600-talstryck | Passar Kodex/Marrows anteckningar, inte knappar. Låg x-höjd ⇒ dålig på mobil i små storlekar. |

Ladda via samma väg som i dag: `https://raw.githubusercontent.com/google/fonts/main/ofl/<fontnamn>/<Fil>.ttf` + `OFL.txt` från samma mapp.

---

## A. Rekommenderad minimikorg (ladda ner dessa 7 först)

Vald för **maximal stilsammanhållning**, inte för maximal mängd. Röd tråd: *monokrom/1-bit grafik som vi färgar själva via den palett-LUT-shader `research/04 §3` redan kräver* + *renderad sten i korridoren* + *ett enda vektor-ikonbibliotek*. Då kan inget "se ihopplockat ut", eftersom nästan inget kommer med egen färg.

| Ordning | Paket | Licens | Varför just denna | Storlek/insats |
|---|---|---|---|---|
| 1 | **Screaming Brain Studios – Old School Dungeon Crawler Pack** (+ Cave Walls Addon) | CC0 | Hela korridoren: väggar, golv, tak, dörrar, i flera storlekar för djupled. Byggd för exakt vår presentationsform. 189 delar. | ~10 min |
| 2 | **Hexany's Monster Menagerie** | CC0 | 64 frontala monstersilhuetter. Löser den svåraste kategorin i ett svep, och 1-bit-formatet *är* silhuett-takten i `CORRIDOR_DESIGN §3.1`. | ~5 min |
| 3 | **Hexany's Roguelike Tiles** | CC0 | Samma konstnär ⇒ 150+ varelser till, 70+ items, autotile-väggar. Stilgarantin. | ~5 min |
| 4 | **game-icons.net** (hela SVG-zipen) | CC-BY 3.0 | Alla 22 gear-ikoner + 7 slot-glyfer ur en och samma hand, i vektor så vi kan färga per raritet. | ~10 min |
| 5 | **Kenney – Fantasy UI Borders + UI Pack (RPG Expansion)** | CC0 | 9-slice-ramar för belöningskort, raritetsramar och character sheet-slots. | ~5 min |
| 6 | **Kenney – RPG Audio + Impact Sounds + Interface Sounds** | CC0 | 280 ljud, noll attribution, täcker allt `gen_sfx.py` inte kan göra bra. | ~5 min |
| 7 | **Incompetech / Kevin MacLeod** – 3 spår (stad, korridor, boss) + **OGA Loopable Dungeon Ambience** | CC-BY 4.0 / CC0 | Musikens minimum. Ambiensen är CC0, bara de tre spåren kräver credits. | ~15 min |

**Summa: 7 nedladdningar, 0 kronor, 1 attributionsrad i credits (game-icons.net) + 3 musikrader.**
Allt annat i listan är expansion, inte start.

**Uppskattning (min, ej källbelagd):** minimikorgen ger material för hela M6–M8 utan nytt inköp. Om stilen ändå skaver efter M6 är nästa steg **Ravenmore Fantasy Icon Pack** (§4.3) för handmålade hero-ikoner, inte fler monster.

---

## B. credits.txt – mall med exakt attributionstext

Lägg filen som `assets/credits.txt` och rendera den ordagrant i credits-skärmen (M6). **Ta bort rader för paket vi inte använder.** CC0-rader är frivilliga men vi tar med dem ändå — det kostar ingenting och det är rätt att göra.

```text
PIPWRECK – Credits and asset licenses
=====================================

FONTS
-----
Familjen Grotesk — (c) Familjen STHLM AB. SIL Open Font License 1.1.
Anton — (c) Vernon Adams / Cyreal. SIL Open Font License 1.1.
Caveat Brush — (c) Impallari Type. SIL Open Font License 1.1.
PIPWRECK Symbols — Modified version of Noto Sans Symbols 2,
  (c) The Noto Project Authors. SIL Open Font License 1.1.
  Modification: vertical metrics rescaled from 1.699 em to 1.250 em.
  No outlines or code points were changed.

ICONS  (CC BY 3.0 — attribution required)
-----------------------------------------
Icons made by Lorc, Delapouite and contributors.
  Available on https://game-icons.net
  Licensed under Creative Commons Attribution 3.0
  https://creativecommons.org/licenses/by/3.0/

Fantasy Icon Pack 2.0 by Ravenmore (Daniel Kvarfordt).
  https://ravenmore.itch.io
  Licensed under Creative Commons Attribution 3.0
  https://creativecommons.org/licenses/by/3.0/

ART  (CC BY 3.0 / 4.0 — attribution required)
---------------------------------------------
Fantasy Portrait Pack by Ravenmore (Daniel Kvarfordt).
  https://opengameart.org/content/fantasy-portrait-pack-by-ravenmore
  https://ravenmore.itch.io
  Licensed under Creative Commons Attribution 3.0
  https://creativecommons.org/licenses/by/3.0/

"6 More RPG Enemies" by Redshrike (Stephen Challener),
  with LordNeo and Blarumyrran.
  https://opengameart.org/content/6-more-rpg-enemies
  Licensed under Creative Commons Attribution 3.0
  https://creativecommons.org/licenses/by/3.0/

Roguelike tile set by David E. Gervais.
  https://opengameart.org/content/roguelike-tiles-large-collection
  Licensed under Creative Commons Attribution 3.0
  https://creativecommons.org/licenses/by/3.0/

Shikashi's Fantasy Icons Pack by Matt Firth (cheekyinkling),
  based in part on designs from game-icons.net.
  https://cheekyinkling.itch.io/shikashis-fantasy-icons-pack
  https://game-icons.net
  Licensed under Creative Commons Attribution 4.0
  https://creativecommons.org/licenses/by/4.0/

MUSIC  (CC BY 4.0 — attribution required)
-----------------------------------------
"<EXAKT SPÅRTITEL>" Kevin MacLeod (incompetech.com)
  Licensed under Creative Commons: By Attribution 4.0
  https://creativecommons.org/licenses/by/4.0/
(Upprepa raden per spår. Ersätt <EXAKT SPÅRTITEL> med styckets faktiska titel —
 incompetech.com/music/royalty-free/faq.html kräver just det.)

"<EXAKT SPÅRTITEL>" by Alexander Nakarada (CreatorChords)
  https://creatorchords.com
  Licensed under Creative Commons: By Attribution 4.0
  https://creativecommons.org/licenses/by/4.0/

Contains music (c) 2026 Arkeia (https://arkeiamusic.itch.io/)
  Licensed under Creative Commons Attribution 4.0 International
  https://creativecommons.org/licenses/by/4.0/

PUBLIC DOMAIN  (CC0 1.0 — no attribution required, credited anyway)
-------------------------------------------------------------------
Old School Dungeon Crawler Pack — Screaming Brain Studios (CC0 1.0)
  https://screamingbrainstudios.itch.io/dungeon-crawler-pack
Hexany's Monster Menagerie — Hexany Ives (CC0 1.0)
  https://hexany-ives.itch.io/hexanys-monster-menagerie
Hexany's Roguelike Tiles — Hexany Ives (CC0 1.0)
  https://hexany-ives.itch.io/hexanys-roguelike-tiles
UI, audio and particle packs — Kenney (kenney.nl) (CC0 1.0)
16x16 DungeonTileset II — 0x72 (CC0 1.0)
Dungeon Crawl Stone Soup tiles — the DCSS contributors (CC0 1.0)
RPG Sound Pack — artisticdude (CC0 1.0)
Loopable Dungeon Ambience — OpenGameArt (CC0 1.0)
Textures — Poly Haven, ambientCG, 3DTextures (CC0 1.0)

SOUND LIBRARY
-------------
Contains sound effects from the Sonniss #GameAudioGDC Bundle,
  used under the Sonniss GDC Bundle License v2.0.
```

**Regler för credits-skärmen (normativa):**
1. Skärmen ska vara **nåbar utan konto och utan nätverk** (offline-first, `CLAUDE.md`).
2. Varje CC-BY-rad ska innehålla **verkets namn, upphovspersonens namn, källänk och licenslänk** — det är CC-BY 4.0 §3(a)(1). Att bara skriva "tack till OpenGameArt" är inte attribution.
3. Musikrader måste ha **den faktiska spårtiteln**, inte en platshållare.
4. Raden läggs in samtidigt som assetet importeras, aldrig efteråt. `assets/ASSET_LICENSES.csv` är sanningen; `credits.txt` genereras ur den.

---

## C. Så här lägger du filerna

```
rogelike_app/assets/incoming/<skapare>-<paket>/
├── <originalzipen orörd, t.ex. dungeon-crawler-pack.zip>
├── <uppackat innehåll>
├── LICENSE.txt          ← paketets egen licensfil om den finns
└── KÄLLA.txt            ← skriver DU, se mall nedan
```

**Namnstandard (gemener, bindestreck, inga å/ä/ö, inga mellanslag):**

```
assets/incoming/screamingbrainstudios-old-school-dungeon-crawler-pack/
assets/incoming/hexany-ives-monster-menagerie/
assets/incoming/hexany-ives-roguelike-tiles/
assets/incoming/game-icons-net-all-svg/
assets/incoming/kenney-fantasy-ui-borders/
assets/incoming/kenney-ui-pack-rpg-expansion/
assets/incoming/kenney-rpg-audio/
assets/incoming/kenney-impact-sounds/
assets/incoming/kenney-interface-sounds/
assets/incoming/incompetech-kevin-macleod/
assets/incoming/opengameart-loopable-dungeon-ambience/
```

**Mall för `KÄLLA.txt`** (kopiera, fyll i, en per mapp):

```text
Paket:        Old School Dungeon Crawler Pack
Skapare:      Screaming Brain Studios
URL:          https://screamingbrainstudios.itch.io/dungeon-crawler-pack
Hämtad:       2026-09-2X
Licens:       CC0 1.0 (Public Domain)
Licenstext (klistrad ordagrant från sidan den dag jag laddade ner):
"All assets in this pack have been released under the Public Domain (CC0)
 license, and are free to use however you like in any project, commercial
 or non-commercial."
Attribution krävs:  NEJ
Skärmdump av licensrutan:  license-screenshot.png
Anteckning:   Huvudpack + Cave Walls Addon i samma zip.
```

**Tre saker som är lätta att slarva med:**
1. **Ta en skärmdump av licensrutan** (`license-screenshot.png` i mappen). itch- och OGA-sidor kan redigeras i efterhand; skärmdumpen är vårt enda bevis på vad som stod den dag vi laddade ner.
2. **Packa inte upp i `assets/sprites/` själv.** `incoming/` har `.gdignore` och importeras inte av Godot. UI-agenten skalar om, ompaletterar och registrerar varje fil i `assets/ASSET_LICENSES.csv`.
3. **Ladda inget som är märkt [verifiera på sidan] utan att faktiskt läsa rutan.** Om det står CC-BY-**SA**, GPL eller NC: stäng fliken. Hellre en tom kategori än en licensskuld i en publicerad app.

---

## Osäkerhet

- **Licenserna i §1–§8 kommer i huvudsak från sökutdrag, inte från hämtade sidor.** Proxyn blockerar `opengameart.org`, `itch.io`, `kenney.nl`, `ambientcg.com` och `screamingbrainstudios.com`. De enda licenser jag läst i primärkälla är Heroine Dusk (GitHub, CC-BY-SA 3.0), Snowdrama CC0-Dungeon-Pack (GitHub, CC0) och Poly Haven (polyhaven.com/license, CC0). **Allt annat måste kontrolleras vid nedladdning.**
- **LimeZu RPG Fantasy Battlers (§1.14)** har motstridiga uppgifter i sökutdragen (CC-BY vs. "free version not for commercial projects"). Behandla som osäker tills sidan lästs.
- **CodeManu Free Pixel Effects Pack (§8.4)** och flera OGA-poster i §4.7–4.8, §6.5 och §7.6 saknar licensuppgift helt i sökutdrag.
- **Kategori 1 är fortfarande vår svagaste.** Det finns ingen stor, gratis, kommersiellt användbar samling frontala *färglagda* dark-fantasy-monster. Vi kompenserar med 1-bit-silhuetter + egen palett. **Uppskattning:** det blir snyggare än det låter, men det är ett stilbeslut och inte en ren asset-fråga — PM bör titta på 1.1 innan resten av korgen laddas ner.
- **Om vi någon gång vill ha fler unika monster i enhetlig stil** är de två realistiska vägarna Oryx Mega Pack (~25 USD) eller Clockwork Ravens "Roguelike Raven – RPG Enemies Battlers"-serie (10 USD/pack, frontala battlers). Båda är betalda och ligger utanför den här listans uppdrag.

---

## Rekommendation till PM

1. **Godkänn minimikorgen i §A (7 nedladdningar, 0 kr) och låt Anders ladda ner i den ordningen.** Kategorierna 1 och 3 är blockerande för korridorbygget; resten kan vänta.
2. **Titta på Hexany's Monster Menagerie innan något annat laddas ner.** Hela stilriktningen (1-bit-silhuetter som färgas av vår palett-LUT) står och faller med om du tycker att de ser ut som PIPWRECK. Säger du nej där måste vi budgetera för köpt art i stället, och det beslutet bör tas nu och inte i M7.
3. **Bekräfta att OGA-BY 3.0 gäller (§0.2).** Vår egen regel i `research/04` tillåter den, briefen gjorde inte det. Jag har undvikit rena OGA-BY-paket, men ett formellt ja öppnar CraftPix-monstren och några Redshrike-set.
4. **Skriv in i `DECISIONS.md` att Heroine Dusk / First Person Dungeon Crawl-paketen är förbjudna** (CC-BY-SA 3.0), trots att de är genrens självklara val. Annars kommer någon — agent eller människa — att föreslå dem igen om tre veckor.
5. **Credits-skärmen (M6) blir liten:** med minimikorgen är det **1 ikon-rad + 3–4 musikrader**. Bygg den ändå nu, innan fler CC-BY-paket kommer in — det är billigare att ha kärlet klart än att fylla på i efterhand.

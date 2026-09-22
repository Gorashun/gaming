# PIPWRECK – Inköpslista för assets i **målad stil** (art direction v3)

**För:** Anders, som laddar ner manuellt · **Sammanställd av:** rnd-roguelike · **Datum:** 2026-09-22
**Ersätter grafikdelen av** `docs/ASSET_SHOPPING_LIST.md` (pixel). Den listans **ljud, musik, fonter, partiklar och licensregel** gäller fortfarande — se §7 här.
**Ankare:** [Fantasy Icon Pack by Ravenmore](https://opengameart.org/content/fantasy-icon-pack-by-ravenmore-0), CC-BY 3.0, 29 handmålade ikoner i 512/128/64 px + PSD (`DECISIONS.md` 2026-09-22).

**Om verifiering:** utvecklingsmiljöns proxy blockerar fulltext från `opengameart.org`, `itch.io`, `akashics.moe`, `kenney.nl` och `craftpix.net` (testat igen i dag: `CONNECT tunnel failed, 403`). Licenserna nedan kommer därför **i huvudsak från sökutdrag**. Varje sådan rad är märkt **[verifiera på sidan]**. Läs licensrutan innan du laddar ner. Ingen rad i det här dokumentet är läst i primärkälla av mig.

---

## 0. LICENSREGELN – oförändrad från förra listan

### ✅ OK att ta in i repot
| Licens | Vad det kräver av oss |
|---|---|
| **CC0 1.0** / "public domain" | Ingenting. Loggas ändå i `assets/ASSET_LICENSES.csv`. |
| **CC-BY 3.0** och **CC-BY 4.0** | Namn + verk + källänk + licenslänk i credits-skärmen (M6). |
| **OFL 1.1** (fonter) | Copyrightnotisen följer med kopian. |
| **OGA-BY 3.0** | Tillåten enligt `research/04 §Rek. 1`. Välj ändå CC-BY-grenen när paketet är dubbel-licensierat. |

### ⛔ ALDRIG in i repot
**CC-BY-SA** (alla versioner) · **GPL 2/3 på grafik** · **CC-BY-NC / "non-commercial"** · **"gratis, credita itch-sidan"** utan skriven licenstext.

### 0.1 Gråzon: [egen licens – ej CC]
I målad stil är detta **regel, inte undantag**. De två största och bästa källorna i hela det här dokumentet (Ækashics, Ravenmores itch-sida) kör **egen licenstext** av typen *"free for commercial use, credit appreciated, do not redistribute the assets themselves"*. Juridiskt fullt användbart. Krav från oss: **spara skärmdump av licenstexten** i `KÄLLA.txt` (se §C), eftersom sidorna kan redigeras i efterhand.

### 0.2 Ny regel i v3: **AI-deklarationsfällan**
Flera av de bäst rankade "gratis handmålade battlers" som dyker upp i sökningar 2026 är **AI-assisterade och deklarerade som sådana av skaparen**. Exempel i den här listan: AssetSmithy, Studio NIK, EnchantedTranquility, Kalponic Studio. Konsekvens om vi tar in dem:

1. itch.io kräver sedan 2024 att **allt** som innehåller generativ AI-output taggas `AI Generated` — **även handretuscherat** ([itch.io Developer Updates](https://itch.io/t/4309690/generative-ai-disclosure-tagging), refererat av [Engadget](https://www.engadget.com/ai/itchio-marketplace-now-requires-asset-creators-to-disclose-their-use-of-generative-ai-130031999.html) och [Game Developer](https://www.gamedeveloper.com/production/itch-wants-asset-creators-to-disclose-when-they-ve-used-generative-ai), hämtat 2026-09-22). Vi ärver deklarationsplikten uppåt.
2. Ren AI-output är enligt US Copyright Office **inte upphovsrättsskyddad** — konkurrenter får kopiera den ([Promise Legal, 2026](https://blog.promise.legal/ai-game-assets-what-studios-own-2026/), [Ashurst/Perkins Coie](https://www.ashurstperkinscoie.com/en/insights/copyright-for-ai-generated-visual-content-in-video-games/), hämtat 2026-09-22).

**Regel:** paket som är AI-genererade eller AI-assisterade listas här med **⚠️ AI** och får inte tas in utan uttryckligt PM-beslut. Se §9.

### 0.3 Ärligheten först: hur knapp den här kategorin är
> **Handmålade, frontala monster som är gratis OCH kommersiellt fria OCH i mörk fantasy-ton är praktiskt taget en tom mängd.**

Det finns tre kluster och inget av dem träffar mitt i prick:

| Kluster | Vad som finns | Varför det inte räcker |
|---|---|---|
| **RPG-Maker-battlers** (Ækashics, Pipoya) | Tusentals frontala målade fiender, gratis, kommersiellt OK | Tonen är JRPG: mättad, glansig, färgrik. Inte Ravenmores dova gouache. **Löses med efterbehandling, inte med val.** |
| **OGA-illustratörer** (Justin Nichol, "The Free Monsters") | Riktigt vackra målade varelser | De bästa är **CC-BY-SA 3.0 + GPL** ⇒ förbjudna för oss. Det som är CC-BY är "cute". |
| **itch-mikro­paket 2025–26** (Juan Art, dodoillustra) | Exakt rätt ton, dark fantasy, handmålat, 1024 px | **2–9 varelser per paket**, ofta 3–5 USD. Räcker till en boss, inte till en bestiarium. |

Konsekvensen är §8 och §B: **8 monster + 1 boss i Ravenmore-ton kommer att kosta pengar.** Allt annat i spelet går att få gratis.

---

## 1. Monster frontalt, målade

Behov enligt `CORRIDOR_DESIGN §3.1`: en frontal figur som först visas som **ren silhuett** och sedan "fylls med färg" på 180 ms. Det betyder två tekniska krav som styr urvalet: **(a) transparent bakgrund** (annars ingen silhuett), **(b) en enda stark pose** (vi behöver ingen animation — fyra takter och hit-stop bär mötet).

| # | Paket & länk | Skapare | Licens (som källan skriver den) | Upplösning/stil | Ingår | Passform PIPWRECK |
|---|---|---|---|---|---|---|
| 1.1 ★★ | [Ækashics Librarium – Bundle Ultrapack](https://aekashics.itch.io/aekashics-librarium-librarium-static-batch-megapack) · [akashics.moe](http://www.akashics.moe/) · [terms](http://www.akashics.moe/terms-of-use/) | Ækashics (illustratör, Dragonbones/Spine-animatör) | **[egen licens – ej CC]** "available for usage in any game engine and any game project… commercial projects without the need to pay extra royalties or hidden fees"; **"credit Aekashics/Ækashics and link back to www.akashics.moe"**; **redistribution av innehållet (även redigerat) är förbjuden**; **NFT-projekt förbjudna**; edits tillåtna **[verifiera på sidan – jag har bara sökutdrag]** | Handmålade **statiska frontala battlers**, hög upplösning, transparent PNG; även animerade varianter | **900+ gratis battlers**, betyg 4,9/5 på 143 omdömen | **Den enda källan i världen som ensam kan fylla hela vårt bestiarium.** Frontalvy, transparent, en pose per fiende = exakt vårt silhuett-kontrakt. **Tonen är ljusare och mer mättad än Ravenmore** ⇒ måste köras genom `ART_DIRECTION_V2 §4`-behandlingen (desaturera, rim-light från facklan, 85 % svart på fjärran). Credits-rad krävs. |
| 1.2 ★ | [HD Dark Fantasy RPG Undead Battlers](https://juan-art.itch.io/hd-dark-fantasy-rpg-undead-battlers-2-monster-sprites) | Juan Art | **[egen licens – ej CC]** "can be used in both non-commercial and commercial game projects… free to modify… no resale or redistribution of the raw files" **[verifiera på sidan]** | Handritat/målat, **halvfigur**, transparent PNG, uttryckligen *"first-person dungeon crawlers"* | **2** skelettbattlers (svärd, hillebard), **3,99 USD** | **Närmast Ravenmore + Darkest Dungeon av allt jag hittat.** Uttryckligen "No AI" i skaparens devlog. Bara 2 figurer ⇒ **köp den som ton-referens och som `GRAVE_HAND`**, inte som bestiarium. |
| 1.3 | [free rpg hand drawn monster pack](https://dodoillustra.itch.io/free-rpg-hand-drawn-monster-pack) | dodoillustra | **[egen licens – ej CC]** "personal and commercial use… cannot redistribute this asset pack" **[verifiera på sidan]** | **720×1280 PNG**, handritad stil | 9 varelser: drake, minotaur, mandrake, cyklop/troll, rock, enhörning, amfisbena, siren, kraken | Gratis, "name your own price". Hög upplösning, mytologiska motiv. **Fel register** (grekisk mytologi mot vårt smedje-/slagg-tema) men två–tre av dem kan omdöpas. |
| 1.4 | [FREE RPG Monster Pack](https://pipoya.itch.io/free-rpg-monster-pack) | Pipoya | **[egen licens – ej CC]** "commercial or personal use… can use and edit freely… cannot redistribute or resell" **[verifiera på sidan]** | Små målade monster, ej hög upplösning | monsterset | Villkoren är bra, **stilen är söt och liten**. Listas för fullständighet eftersom briefen bad om den. Blandas inte med 1.1. |
| 1.5 | [Monsters Creatures Fantasy](https://luizmelo.itch.io/monsters-creatures-fantasy) · [Fantasy Creatures](https://luizmelo.itch.io/fantasy-creatures) · [Enemies Fantasy](https://luizmelo.itch.io/enemies-fantasy) | LuizMelo | "can be used in commercial and non-commercial projects under the **CC0** license. Credits are not required" **[verifiera på sidan]** | Handritade, animerade, **sidovy** | Skelett, svamp, goblin, flygande öga m.fl., med idle/walk/attack/hit/death | **CC0 = noll administration.** Fel vinkel (sidovy för plattformare) men **perfekt som fjärran silhuetter i korridoren** där bara konturen syns, och som referens för animationstajming. |
| 1.6 | [RPG Fantasy icons portraits – monsters, heroes, vampires](https://opengameart.org/content/rpg-fantasy-icons-portraits-monsters-heroes-vampires) | Sons of Welder | "CC0" **[verifiera på sidan]** | 64×64 och 128×128, **JPG** | 27 målade porträtt: hjältar, monster, vampyrer + några förmågeikoner | Målade **monsterporträtt** — rätt till Kodex-uppslagen (`CORRIDOR_DESIGN §3.3`). **Varning: JPG = ingen alfakanal** ⇒ inte användbart som stridsfigur, bara i en ram. |
| 1.7 | [Cute Monsters A-E](https://opengameart.org/content/cute-monsters-a-e) · [F-O](https://opengameart.org/content/cute-monsters-f-o) · [P-Z](https://opengameart.org/content/cute-monsters-p-z) | Justin Nichol | "CC-BY 4.0" **[verifiera på sidan – Nichol blandar CC-BY och CC-BY-SA mellan poster]** | Målade illustrationer, del av serie på 90+ figurer | 24+ monsterillustrationer per del | Briefen bad om Nichol. Han är **den bästa målaren på OGA** och **fel** för oss: det som är CC-BY heter bokstavligen "Cute". Hans mörka saker ([Wyvern Elemental Skins](https://opengameart.org/content/wyvern-elemental-skins), Flare-porträtten) är **CC-BY-SA 3.0 / GPL** ⇒ förbjudna. |
| 1.8 | [Bevouliin free assets](https://bevouliin.com/license/) · [OGA-spegel](https://opengameart.org/content/bevouliin-free-enemy-villain-monster-game-asset-for-game-developers) | Bevouliin | "royalty free for use in both personal and commercial projects… No attribution or link back… is required"; taggat **CC0** på OGA **[verifiera på sidan]** | Vektorig mobil-casual-cartoon | monster, karaktärer, bakgrunder | Villkoren är utmärkta. **Tonen är flappy-bird-glad.** Nej för PIPWRECK. |
| 1.9 | [Lost Garden Collection](https://opengameart.org/content/lost-garden-collection) · [licens](https://lostgarden.com/2007/03/15/lost-garden-license/) | Daniel Cook | "Creative Commons Attribution 3.0 License… attribute the original source materials to Daniel Cook" **[verifiera på sidan]** | Hard Vacuum (8-bit, 1993), Planet Cute, Tyrian | historiska paket | Historiskt viktigt, **stilmässigt irrelevant 2026**. Briefen bad om det; svaret är nej. |
| 1.10 ⚠️ AI | [9 Free Fantasy Monster Battlers](https://assetsmithy.itch.io/9-free-fantasy-monster-battlers-rpg-maker-deckbuilder-roguelike-enemy-pack-sa) · [99-versionen, 4,99 USD](https://assetsmithy.itch.io/99-fantasy-monster-battlers-rpg-maker-deckbuilder-roguelike-enemy-pack) | AssetSmithy | "royalty-free, commercial use allowed, no attribution required" **[verifiera på sidan]** — men skaparen skriver ut: *"AI-assisted 2D art assets, manually reviewed and refined by the vendor"* och levererar en färdig deklarationstext att klistra in | 64/128/256/512, även 1024 px; frontala battlers | 9 gratis (3 familjer × 3 tiers), 99 i betalversionen | **Formatet är perfekt, licensen är perfekt, ursprunget är AI.** Se §0.2. Tas inte in utan PM-beslut. |
| 1.11 ⚠️ | [Pixabay](https://pixabay.com/service/terms/) | blandat | Content License: fri kommersiell användning utan attribution, **men** förbud mot vidaredistribution/ML-träning och mot användning där bilden *är* produktens kärnvärde; tre olika licensepoker (pre-2019 CC0 vs. nuvarande) ([PicDefense, 2026](https://picdefense.io/resources/source-intel/pixabay/), hämtat 2026-09-22) | stock, blandat ursprung, **AI-bilder tillåtna i biblioteket sedan 2023** | – | **Nej som monsterkälla.** Ingen alfakanal, okänt ursprung per bild, och "bilden är kärnvärdet" är precis vad en stridsfigur är. Unsplash (foto) ännu mer nej. |

### 1.12 ⛔ Fällor – ladda INTE ner
| Paket | Licens | Varför |
|---|---|---|
| [The Free Monsters](https://opengameart.org/content/the-free-monsters) (Naga, Ratman, Treefolk, Troll, Lichlord, Violence Demon, Goblin, Orc, Harpy, Dragon — PNG + XCF) | **CC-BY-SA 3.0 + GPL 3.0 + GPL 2.0** **[verifiera på sidan]** | Det här är **exakt** vad vi letar efter: elva målade dark-fantasy-varelser med källfiler. Och det är trippelt förbjudet. Skriv in det i `DECISIONS.md` så att ingen föreslår det igen om tre veckor. |
| [Wyvern Elemental Skins](https://opengameart.org/content/wyvern-elemental-skins) + Flare-porträtten, Justin Nichol | **CC-BY-SA 3.0** **[verifiera]** | Sidan nämner att separat licens kan förhandlas. Det är en beställning, inte en nedladdning — hör hemma i §8. |
| Reemax (OGA) | LPC-material, **CC-BY-SA 3.0 + GPL 3.0** **[verifiera]** | Briefen bad om Reemax. Hens OGA-inlägg är LPC-ekosystem ⇒ SA. Nej. |
| Battle for Wesnoth, Universal LPC Generator, Heroine Dusk / First Person Dungeon Crawl Art Pack | SA/GPL | Redan förbjudna i `DECISIONS.md` 2026-09-22. |

### 1.13 Stil-samhörighet: vad som faktiskt går att blanda
**Regeln från `ART_DIRECTION_V2 §3`: högst två konstnärer för figurer, en för miljö.** Konkret för v3:

- **Går att blanda:** Ækashics (1.1) + Juan Art (1.2) + Ravenmore-ikonerna (§3) — alla tre är målade med synligt penseldrag, mörka konturer och rimljus. Skillnaden är mättnad, och den **utjämnas i vår egen grade** (`ART_DIRECTION_V2 §4`: tre hue-familjer — sot, eld, ben — plus 0,55 vinjett och 6–8 % grain över allt). **Uppskattning (min, ej källbelagd): efter den behandlingen syns inte att figurerna kommer från två händer.**
- **Går INTE att blanda:** Ækashics + Justin Nichols "Cute Monsters" (annan linjevikt, annan humor), Ækashics + Bevouliin (vektor mot måleri), och vad som helst målat + våra befintliga 32 px-pixelsprites. Pixel och måleri i samma bild läser som bugg.
- **Neutralt, blandas alltid:** Kenney-partiklar, alla ljud, alla CC0-PBR-texturer. De har ingen egen hand.

---

## 2. Hjälte: målade porträtt och helfigur

Behov: **porträtt vid könsvalet** (två varianter av The Smith, `DECISIONS`), plus figuren på character sheet i **~52 % av skärmhöjden** med **ett lager per utrustad slot** (`CORRIDOR_DESIGN §4.1`, 7 slots i `PROGRESSION_REDESIGN §3.1`).

| # | Paket & länk | Skapare | Licens (källans ordalydelse) | Upplösning/stil | Ingår | Passform |
|---|---|---|---|---|---|---|
| 2.1 ★★ | [Fantasy Portrait Pack](https://opengameart.org/content/fantasy-portrait-pack-by-ravenmore) | Ravenmore | "CC-BY 3.0" **[verifiera på sidan — ett sökutdrag påstod CC0, det är fel; utgå från CC-BY 3.0]** | **256/128/64 px**, handmålat | 4 porträtt: människa, alv, dvärg, gnom | **Samma hand som ikonankaret.** Det är hela poängen: porträtt och gear-ikoner målade av samma person är den billigaste stilenhet som finns. Bara 4 st, och **inget av dem är uppenbart kvinnligt** ⇒ täcker inte könsvalet. |
| 2.2 ★ | [Dark Fantasy Tavernkeeper – Hand-Drawn Character Portrait](https://juan-art.itch.io/dark-fantasy-tavernkeeper-rpg-ui-starter-kit) | Juan Art | "CC BY 4.0" enligt [itch-annonsen](https://itch.io/t/6714567/free-asset-dark-fantasy-tavernkeeper-hand-drawn-character-portrait-1080x1350-px) **[verifiera på sidan]** | **1080×1350**, handmålat med textur | 1 porträtt, gratis | **Gratis, CC-BY, rätt ton, hög upplösning.** En enda bild — men det är precis vad **Marrow vid kärran** (`PROGRESSION_REDESIGN §3.4`) behöver, och det är den scenen dokumentet kallar "den vackraste 10-sekundersscenen i spelet". |
| 2.3 ★ | [HD Dark Fantasy RPG Portraits & Half-Body Sprites](https://juan-art.itch.io/hd-dark-fantasy-rpg-portraits-pack-4-hero-assets) | Juan Art | **[egen licens – ej CC]** "personal and commercial game projects… may be modified… may not be resold or redistributed. Attribution appreciated but not required" **[verifiera på sidan]** | **1024×1024 porträtt + halvfigur** med händer och vapen, transparent PNG | 4 hjältar: mage, rogue, paladin, barbarian. **4,99 USD** | **Bäst pris/prestanda i hela dokumentet.** Uttryckligen "100% Hand-Drawn & Painted (No AI)". Halvfiguren löser character sheet-figuren utan paperdoll. **[verifiera: könsfördelningen — briefen kräver båda könen].** |
| 2.4 | [Utility – Art Pack \| Dark Fantasy](https://unitsix.itch.io/utility-unitsix-art-pack) | UnitSix | **"CC BY 4.0"** **[verifiera på sidan]** | handmålat, hög upplösning, 8 st med **trelagers-källfiler** | **48 porträtt** (hollow-eyed nobles, heretical priests, gutter scvm) + helfigurshjältar + **silhuetter**, 10 i monokrom. Från **10 AUD** | **CC-BY + helfigur + färdiga silhuetter + lagerfiler.** Silhuettsetet är bokstavligen `CORRIDOR_DESIGN §3.1` takt 1. MÖRK BORG-tonen ligger nära vårt `KRITGROPEN`. Kostar ~70 kr. **Den här skulle jag köpa.** |
| 2.5 | [public domain portraits](https://opengameart.org/content/public-domain-portraits) · [CC0 Portraits](https://opengameart.org/content/cc0-portraits) | jClassicRPG m.fl. | CC0 **[verifiera per post]** | 200×200+, **beskurna ur verkliga public domain-oljemålningar** | porträttbank | Riktigt måleri, noll kostnad, noll attribution. Ansiktena är 1600–1800-tal ⇒ **perfekta som stadens NPC:er och Kodex-illustrationer**, olämpliga som hjälte (fel kläder). |
| 2.6 ⚠️ AI | [12 Fantasy Character Portraits — Free Sample](https://studio-nik.itch.io/12-fantasy-character-portraits-free-sample) | Studio NIK | "CC BY 4.0 — free for personal and commercial use, credit *Studio Nik*" **[verifiera på sidan]** | 1024/512/256, fyrkant + rund token + oval ram | 12 klasser (fighter, rogue, wizard…) | Licensen är bland de bästa i listan. **Skaparen skriver ut att porträtten är skapade med AI-verktyg.** Se §0.2 ⇒ inte utan PM-beslut. |
| 2.7 | [Character portrait kit](https://opengameart.org/content/character-portrait-kit) | OGA-användare | **[verifiera på sidan]** | modulärt | 4 kroppar (man/kvinna), huvuden, hår, skjortbas, rustningstyper, hattar/huvor | **Modulärt = paperdoll-tanken i porträttform.** Om vi vill att porträttet ska spegla utrustad gear är det här enda gratisvägen. Stilen är enklare än Ravenmore. |

### 2.8 Paperdoll i målad stil: säg nej nu, spara pengar
En **målad** paperdoll (7 utrustningslager som ska passa exakt på en målad kropp, i alla kombinationer) finns inte gratis och går inte att plocka ihop ur två paket — lagren måste målas mot *samma* kropp, i *samma* ljus, av *samma* person. Det är per definition en beställning (§8).

**Rekommenderad kompromiss, som dessutom är bättre design:**

1. **Character sheet visar ett målat porträtt + halvfigur** (2.3 eller 2.4), som **inte** ändras av utrustning.
2. **Gear syns som Ravenmore-ikoner i de 7 sloten**, med kritstrecket till rätt kroppsdel som `CORRIDOR_DESIGN §4.1.3` redan beskriver.
3. **Förändringen animeras på sloten, inte på kroppen:** `§4.3`-ceremonin ("lagret kritas på figuren, 520 ms") blir istället *ikonen faller ner i sloten och kritramen skriver ut namnet*. Samma 900 ms, samma haptik, noll ny konst.
4. **Helfigur med lager beställs först när spelet är roligt** (`ART_DIRECTION_V2 §3` steg 2), och då bara för de 2 hjältarna.

**Uppskattning (min, ej källbelagd):** steg 1–3 tappar ~15 % av den känslomässiga effekten mot en riktig paperdoll och sparar 600–1 200 USD. Vid en obyggd progression är det rätt byte.

---

## 3. Ikoner (gear, items, slots) – här vinner vi

Mål: **22 gear-ikoner + 7 slot-glyfer + 4 raritetsramar** (`PROGRESSION_REDESIGN §3.5`, `§3.3`). Detta är den **enda** kategorin där den målade vägen är *billigare* än pixelvägen, eftersom två stora CC-BY-bibliotek råkar vara målade.

| # | Paket & länk | Skapare | Licens (källans ordalydelse) | Upplösning/stil | Ingår | Passform |
|---|---|---|---|---|---|---|
| 3.1 ★★ | [Fantasy Icon Pack 2.0](https://opengameart.org/content/fantasy-icon-pack-by-ravenmore-0) · [itch](https://ravenmore.itch.io/fantasy-icon-pack) | Ravenmore | OGA: **"CC-BY 3.0"**, instruktion *"drop a link to ravenmore.itch.io"*. itch-sidan formulerar samma sak som egen licens: *"use the assets commercially… linking back in credits appreciated but not required… icons cannot be re-distributed as part of another asset pack"* **[verifiera båda sidorna]** | **512/128/64 px PNG + PSD-källa** | **29 handmålade ikoner**: yxa, båge, pilar, rustning, verktyg, hammare m.m. | **ANKARET.** PSD-källan är det viktigaste i hela dokumentet: vi kan måla om 29 ikoner till våra 22 föremål i **hans egen hand**, i stället för att hitta 22 nya. Hammaren är bokstavligen `CHIPPED_HAMMER`. |
| 3.2 ★★ | [Painterly Spell Icons part 1](https://opengameart.org/content/painterly-spell-icons-part-1) · [2](https://opengameart.org/content/painterly-spell-icons-part-2) · [3](https://opengameart.org/content/painterly-spell-icons-part-3) · [4](https://opengameart.org/content/painterly-spell-icons-part-4) | J. W. Bjerk (eleazzaar), [jwbjerk.com/art](https://www.jwbjerk.com/art) | Multilicensierad, **innehåller CC-BY 3.0** (även SA/GPL-grenar) ⇒ **välj CC-BY 3.0-grenen och skriv det i `KÄLLA.txt`** **[verifiera på sidan]**. Attributionssträng anges av upphovsmannen, se §C | **256×256**, målade, "designed to be easily recognizable down to 32×32" | Hundratals ikoner i fyra delar, **tre kraftnivåer per förmåga**, upp till 9 färgvarianter | **Den enskilt mest relevanta fyndet efter Ravenmore.** "Tre kraftnivåer av samma ikon" **är** vårt raritetssystem (`§3.3`: common→uncommon→rare→epic) färdigritat. Och 256 px matchar Ravenmores 128 px-utgåva efter nedskalning. |
| 3.3 ★ | [Handpainted RPG icons](https://opengameart.org/content/handpainted-rpg-icons) | OGA-användare | "CC-BY 3.0" **[verifiera på sidan]** | **256/128/64/32 px**, "fully editable in Photoshop" | 37 ikoner | Exakt samma fyra storlekar som Ravenmore använder. **Fyller luckorna i 3.1** (amuletter, bälten, benskenor) utan stilbrott. |
| 3.4 | [Fantasy RPG Icons 3](https://opengameart.org/content/fantasy-rpg-icons-3) | OGA-användare | **"CC0"** **[verifiera på sidan]** | 128×128, handmålat i GIMP | 12 ikoner | Skaparen skriver ut *"Absolutely no AI was used"* och att allt är eget arbete. **CC0 + målat + no-AI = sällsynt kombination**, ta den. |
| 3.5 | [RPG Icons – Gems](https://ravenmore.itch.io/rpg-icons-gems) | Ravenmore | **[egen licens – ej CC]** "make as many free or paid games as you want, but you can't resell as is or as part of another pack"; credit ej krav **[verifiera på sidan]** | handmålat, ej pixel | **100 färgade ädelstenar** | **Raritetssystemets färgkod i fysisk form.** En benvit/koppar/blå/lila sten i hörnet av varje gear-kort löser `§3.3` utan att vi ritar fyra ramar. Samma hand som ankaret. |
| 3.6 | [game-icons.net](https://game-icons.net/) | Lorc, Delapouite, Skoll m.fl. | "Creative Commons 3.0 BY" **[verifiera på sidan]** | **4180 SVG**, monokroma | allt | **Inte målat — och det är rätt här.** De **7 slot-glyferna** (HEAD/CHEST/HANDS/WEAPON/LEGS/BACK/AMULET) ska vara tysta monokroma märken i benvitt, inte små tavlor. Annars konkurrerar sloten med föremålet i den. |
| 3.7 | [Free RPG & Fantasy Essentials – Starter Kit \[4K\]](https://vill8tion.itch.io/free-rpg-fantasy-essentials-starter-kit-4k) | Vill8tion | "free for commercial and personal use (**CC0**), attribution appreciated but not required" **[verifiera på sidan]** | 4K | Drycker, alvrunor (socketable), HP/XP-staplar, **ett seamless dungeon-stengolv** | CC0 och hög upplösning. **Varning:** sidan skriver "4K ready, **upscaled**" ⇒ kontrollera om det är AI-uppskalning (§0.2) och om 4K betyder mjuk grädde vid 1080 px. |
| 3.8 | [7Soul's RPG Graphics – Icons](https://7soul.itch.io/7souls-rpg-graphics-pack-1-icons) · [496 icons på OGA](https://opengameart.org/node/39455) | 7Soul1 | Upphovsmannen **bytte från CC-BY 3.0 till Public Domain** på OGA eftersom *"the CC-BY 3.0 licence was causing too much of a hassle"* **[verifiera på sidan]** | **pixel**, 16×16/32×32 | 420 + expansioner, upp till 1700 ikoner i nyare släpp | Briefen bad om den. **Det är pixel, alltså fel stil för v3.** Behåll bara som reserv-bank för formidéer. |

### 3.9 Täckningsplan för de 22 föremålen (uppskattning)
| Källa | Täcker (uppskattning) |
|---|---|
| Ravenmore 3.1 (29 st, PSD) | **12–16 av 22** direkt eller med ommålning: `CHIPPED_HAMMER`, `SPIKE_MAUL`, `SCRAP_CAP`, `SLAG_PLATE`, `GRIP_WRAPS`, `TONG_GLOVES`, `RUST_GREAVES`, `CART_BOOTS`, `DICE_POUCH`, `CHALK_SATCHEL` … |
| Handpainted RPG icons 3.3 (37 st) | amuletter och småplagg: `BONE_TALLY`, `TWIN_PIP`, `BROKEN_SCALE` |
| Painterly Spell Icons 3.2 | de **magiska/epic** dropparna: `PIPSIGHT_LENS`, `SLAGJAW_TOOTH`, `SIXTH_SEAT` — och alla tre kraftnivåerna av varje |
| game-icons.net 3.6 | **7 slot-glyfer**, monokroma |
| Ravenmore Gems 3.5 | **4 raritetsmarkörer** |
| **Kvar att måla själva/beställa** | **uppskattningsvis 3–6 ikoner**, framför allt de två "drömdropparna" `SLAGJAW_TOOTH` och `SIXTH_SEAT` som *måste* se unika ut |

---

## 4. Korridor och miljö i målad stil

`CORRIDOR_DESIGN §2.4`: "mörkret är frånvaro av ritning", tre djup (nära full kontrast, mellan 45 % svart, fjärran 85 %). Det ger oss stor frihet — **85 % av väggytan är ändå svart.**

### 4.1 (a) Fotorealistisk CC0-PBR — funkar bättre än det låter
| # | Källa | Licens | Kommentar |
|---|---|---|---|
| 4.1 | [ambientCG](https://ambientcg.com/) · [licens](https://docs.ambientcg.com/license/) | **CC0 1.0** — "free to use for any purpose, forever… You can include the raw files in your project, for example a video game"; attribution frivillig (hämtat 2026-09-22) | 2800+ PBR-material. Ladda **1K, aldrig 8K** på mobil. |
| 4.2 | [Poly Haven](https://polyhaven.com/textures/brick/wall) · [licens](https://polyhaven.com/license) | **CC0** — "any purpose, including commercial work. You do not need to give credit" | Bäst enskilda väggar; använd till **bossdörren**. |

**Ärligt om (a):** dessa ser *fotograferade* ut, inte målade. **Men** `ART_DIRECTION_V2 §4` föreskriver redan 0,55 vinjett, ett 6–8 % grain-/smetlager över allt, tre hue-familjer och 45/85 % svarta djuplager. **Uppskattning (min, ej källbelagd): efter den behandlingen är skillnaden mellan en fotoskannad tegelvägg och en målad tegelvägg i stort sett osynlig på en 6-tums skärm** — ögat läser ljus och värde, inte penseldrag, på den ytan. Det är figurerna, inte väggarna, som måste vara målade.

### 4.2 (b) Målade bakgrunder / parallax
| # | Källa | Licens | Kommentar |
|---|---|---|---|
| 4.3 ⚠️ AI | [Painterly Battle Backgrounds](https://kalponic-studio.itch.io/painterly-battle-backgrounds) | "personal or commercial projects", **50 gratis** av 82, resten 5,99 USD **[verifiera]** | 1920×1080, målad stil med dungeons och ruiner. **Skaparen skriver: "The images are made with the help of AI."** Se §0.2. |
| 4.4 | [Seamless Parallax Cave Background](https://opengameart.org/content/seamless-parallax-cave-background) | **[verifiera på sidan]** | 4 lager (front/mid/far/back) + PSD. Rätt teknisk form för `floor1_parallax_far/mid/near.png` som vi redan har. |
| 4.5 | [2d Backgrounds – Dungeons and Cave, Parallax](https://opengameart.org/content/2d-backgrounds-for-platformer-game-dungeons-and-cave-parallax-vector-illustration) | **[verifiera på sidan]** | Vektorillustration med källfiler, kall/varm variant. Skalar till 1080×1920 utan artefakter. |

### 4.3 (c) **Hand painted textures – det här är rätt spår för korridoren**
Målade, kaklade väggar i 512–1024 px är precis vad `CORRIDOR_DESIGN` vill ha, och till skillnad från monster **finns** det gratis.

| # | Källa | Skapare | Licens | Kommentar |
|---|---|---|---|---|
| 4.6 ★★ | [Stylized Mossy Dungeon Wall](https://kaczor237.itch.io/stylized-mossy-dungeon-wall-seamless-pbr-texture) + [Stylized Dungeon Stone Floor](https://kaczor237.itch.io/stylized-dungeon-stone-floor-steamless-pbr-texture-pack) | kaczor237 | "released under **CC0**, no restrictions for commercial or personal use" **[verifiera]** | **Handmålad, seamless, PBR-klar, "perfect for stylized fantasy dungeons and castles"** — och vägg + golv från *samma hand*. Exakt vår korridor. Ladda båda. |
| 4.7 ★ | [Stylized Textures – Dungeon Starter Pack](https://oleekconder.itch.io/hand-painted-textures-dungeon-starter-pack) | oleekconder | **[verifiera på sidan]** | **33 unika seamless texturer** i handmålad stil, dungeon-tema. Tre våningar utan stilbrott. |
| 4.8 | [Free Handpainted Seamless Texture Pack](https://sunichawa.itch.io/seamless-texture-pack) · [tileable texture pack](https://ultrasonic-assets.itch.io/tileable-texture-pack) · [texture pack (CC0)](https://lynocs.itch.io/texture-pack) | div. | CC0 för lynocs **[verifiera per paket]** | Kompletteringsbank. |
| 4.9 | [Handpainted Stone Wall Textures](https://opengameart.org/content/handpainted-stone-wall-textures) · [Assets: Stylized Hand-Painted (samling)](https://opengameart.org/content/assets-stylized-hand-painted) | OGA | **Sidan listar både CC-BY 4.0 och CC0 samtidigt och kommentarsfältet påpekar att det är motstridigt** **[verifiera — behandla som CC-BY 4.0 tills upphovsmannen klargjort]** | Bra motiv, rörig licens. Ta bara om 4.6/4.7 inte räcker. |

### 4.4 Teknisk fotnot: 512–1024 px målad konst på mobil
Godot 4 stöder **ETC2 för Android och ASTC för iOS** via *Project Settings → Rendering → Textures → VRAM Compression*. Viktigt: **inställningen gör ingenting förrän assets importeras om** (radera `.godot/imported/` eller kör *Fix Imports* i exportdialogen), annars skeppas texturerna okomprimerade. En 2048×2048-atlas är ~16 MB som rå RGBA32 och ~1–4 MB efter ETC2/ASTC ([ilovesprites.com, Godot/Cocos atlas-guide](https://ilovesprites.com/blog/texture-atlas-mobile-godot-cocos-guide), [Godot 4 mobile optimization](https://gtstu.com/godot-4-optimize-android-ios/), hämtade 2026-09-22). **Konsekvens för v3:** 512 px-monster är helt oproblematiskt; 4K-texturer (3.7) är det inte. Sätt ett tak på **1024 px per asset i builden** och behåll originalen i `assets/incoming/`.

---

## 5. UI-ramar i målad stil

| # | Paket & länk | Skapare | Licens | Passform mot Ravenmore |
|---|---|---|---|---|
| 5.1 ★★ | [RPG GUI construction kit v1.0](https://opengameart.org/content/rpg-gui-construction-kit-v10) | Matjaž Lamut (Lamoot) | **"CC-BY 3.0"**, attribution: *"RPG GUI by Matjaž Lamut (Lamoot), CC BY 3.0"*. **GIMP-källfil ingår** **[verifiera på sidan]** | **Bästa matchningen.** Målade, varma trä-/metallramar med mjuka övergångar — samma register som Ravenmores ikoner. Källfilen gör att vi kan bygga 9-slice i exakt våra mått. |
| 5.2 ★ | [Fantasy UI Elements by Ravenmore](https://opengameart.org/content/fantasy-ui-elements-by-ravenmore) | Ravenmore | **[verifiera på sidan — sannolikt CC-BY 3.0 som hans övriga OGA-poster]** | UI-förslag ursprungligen ritat för ADOM. **Om licensen är CC-BY är detta automatiskt förstahandsvalet** — samma hand som ankaret, noll stilrisk. Verifiera först. |
| 5.3 | [Kenney – Fantasy UI Borders](https://kenney.nl/assets/fantasy-ui-borders) | Kenney | **CC0 1.0** — "any project including commercial ones. Attribution is not required" **[verifiera på sidan]** | **140 assets, 130+ sprites, uttryckligen för 9-slice.** Platt och neutral, alltså *inte* Ravenmore-stil — men perfekt där ramen ska vara tyst: slot-rutor, tooltips, pausmeny. **Använd platt där innehållet är målat, aldrig tvärtom.** |
| 5.4 | [Fantasy RPG UI – Circular Frames Mini Pack (gratis)](https://runefoundry.itch.io/fantasy-rpg-ui-circular-frames-mini-pack) | Rune Foundry | "commercial-friendly" **[verifiera på sidan]** | 24 högupplösta cirkulära ramar i 8 familjer. **Runda ramar = porträttramen på character sheet.** |
| 5.5 | [Fantasy RPG UI Kit – Premium Vector GUI (200+)](https://az0te.itch.io/fantasy-rpg-ui-kit-premium-vector-gui-200) | Az0Te | "unlimited personal & commercial use, modify freely, no credit required", **8,99 USD** **[verifiera]** | Vektor med guldlist. Skalar perfekt, men glansigare än Ravenmore. |
| 5.6 | [Fantasy RPG Game UI Kit — 53 Elements](https://orabon.itch.io/fantasy-rpg-game-ui-kit) | orabon | betald **[verifiera]** | *Handmålad*: "carved dark wood, aged parchment, ornate gold and iron trim". **Tonmässigt den bästa i listan.** Prisa upp innan beslut. |
| ⛔ | [Golden UI – Bigger Than Ever edition](https://opengameart.org/content/golden-ui-bigger-than-ever-edition) | Buch | **CC-BY-SA 3.0** **[verifiera]** | **Förbjuden.** Den äldre [Golden UI](https://opengameart.org/content/golden-ui) uppges vara **CC0** **[verifiera]** — men båda är pixel/DawnBringer-32, alltså fel stil för v3 ändå. Briefen bad om dem; svaret är nej på båda grunderna. |

**Rekommendation §5:** verifiera 5.2 först. Är den CC-BY → ta 5.2 + 5.3. Är den inte det → ta **5.1 (Lamoot) + 5.3 (Kenney)**, och håll `UI_GUIDE §1`-regeln att UI-brus ska ner 60 %: en målad ram per skärm, resten platt.

---

## 6. Effekter (målade slash/hit/eld)

| # | Paket & länk | Skapare | Licens | Kommentar |
|---|---|---|---|---|
| 6.1 ★ | [SlashFX](https://jasontomlee.itch.io/slashfx) | Jason Tomlee | **"Creative Commons Attribution 4.0 International"** **[verifiera på sidan]** | Handanimerade slash-effekter som PNG-spritesheets + GIF. **Inte pixel** ⇒ rätt för v3. Direkt till kedjeresolvningens träffar. |
| 6.2 ★ | [Kenney – Particle Pack](https://kenney.nl/assets/particle-pack) | Kenney | **CC0** **[verifiera]** | 80 sprites (eld, rök, magi, gnistor). **Stilneutral** — partiklar har ingen hand. Behåll från pixelkorgen; den fungerar lika bra under målad konst. |
| 6.3 | [Free Slash Effects Sprite Pack](https://craftpix.net/freebies/free-slash-effects-sprite-pack/) · [Cartoon-varianten](https://craftpix.net/freebies/free-slash-sprite-cartoon-effects/) | CraftPix | **[egen licens – ej CC]** "Freebie Products licence: personal and commercial projects, modifications allowed, **no credit required**, **reselling/redistributing the original files prohibited**" **[verifiera på sidan]** | Målade/cartoon-slashar i hög upplösning. Gratis. Spara licenstexten. |
| 6.4 | [cc0 special effects (samling)](https://opengameart.org/content/cc0-special-effects) | OGA-samling | CC0 (samlingsfilter) **[verifiera per post]** | Bläddringsyta: hit animations, Fire Wrath, Nature Magic, Earth Impact. Blanda inte pixelposterna in i v3. |
| ⛔ stil | [Pimen](https://pimen.itch.io/pixel-battle-effects) | pimen | **[egen licens – ej CC]** "use and modify for personal and commercial purposes… cannot resell or redistribute", credit ej krav **[verifiera]** | **Villkoren är fina, men Pimen är pixel art.** Briefen bad om den; med v3 faller den på stil, inte licens. |

---

## 7. Ljud och musik – **oförändrat**

Se `docs/ASSET_SHOPPING_LIST.md` **§6 (SFX)**, **§7 (musik)** och **§9 (fonter)**. Ingenting där är stilbundet: Kenney RPG Audio/Impact Sounds (CC0), artisticdudes RPG Sound Pack (CC0), Freesound med `license:"Creative Commons 0"`-filter, Incompetech/Kevin MacLeod och Alexander Nakarada (CC-BY 4.0), Loopable Dungeon Ambience (CC0), Sonniss GDC-bundeln. **Fonterna är redan klara** (Familjen Grotesk, Anton, Caveat Brush, PIPWRECK Symbols, alla OFL 1.1).

**Enda tillägget för v3 (uppskattning):** målad konst tål — och kräver — **mer** ljudtyngd. En 512 px-fiende som fylls med färg på 180 ms behöver ett hetare `monster_reveal` än en 32 px-sprite gjorde. Det är en mixfråga i M6, inte ett inköp.

---

## 8. Beställd konst, konkret

### 8.1 Var man hittar rätt illustratör
| Kanal | Så söker du | Vad du får |
|---|---|---|
| **itch.io-konstnärer som redan säljer det vi vill ha** | Juan Art, UnitSix, Ravenmore själv, Ækashics — skriv via itch-sidans kontakt/devlog | **Bästa träffsäkerheten.** Du har redan sett stilen i deras paket; du beställer "mer av det du köpte". Ækashics är illustratör/animatör på heltid och tar uppdrag **[verifiera]**. |
| **itch.io "Help Wanted or Offered"** | [itch.io/board – Help Wanted](https://itch.io/t/5811459/art-2d-character-artist-for-darkest-dungeon-style-rpg) — där ligger redan aktiva 2026-annonser för *"DARKEST DUNGEON style rpg"* och *"strong gesture and triangle brush"* | Artister som **själva** söker DD-stilsuppdrag. Gratis att posta. |
| **ArtStation** | Sök `battler`, `creature illustration`, `dark fantasy character`, filtrera på "Available for freelance" | Högst kvalitet, högst pris. |
| **Fiverr** | Sök `game illustration`, `monster concept`, `hand painted game assets` | Snabbast, mest prisspridning, mest risk för smyg-AI. |
| **Upwork** | Timpris, längre kontrakt | Bäst för en hel batch med escrow. |

### 8.2 Prisnivåer (verifierade marknadssiffror, hämtade 2026-09-22)
| Källa | Siffra |
|---|---|
| [Fiverr – hand painted game assets](https://www.fiverr.com/gigs/game-art) | Gigs från **15–35 USD** per asset |
| [Fiverr – monster/creature concept](https://www.fiverr.com/gigs/monster) | Creature-/monsterkonceptillustration **från 25–40 USD** |
| [FramedFantasy 2026 Pricing Guide](https://framedfantasy.com/blogs/character-commission-blog/how-much-does-dnd-character-art-cost-2026-pricing-guide) | Custom karaktärskonst **50–300+ USD** |
| [Juego Studio, "How Much Does Video Game Art Cost? 2026"](https://www.juegostudio.com/blog/how-much-does-video-game-art-cost) | 2D-artist **25–40 USD/h** junior, **40–75** mid, **75–150** senior. Komplett indie-mobil-konstset **3 000–5 000 USD** (budgetstudio), **8 000–15 000 USD** (mellanstudio) |
| [GameDev.net, 2D-artist for hire](https://gamedev.net/forums/topic/720420-for-hire-2d-artist-custom-anime-sprites-dark-fantasy-illustration-vector-ui-assets-20-200/) | Dark fantasy-illustration + vektor-UI: **20–200 USD** per asset |

### 8.3 Styckpriser för *våra* leverabler — **uppskattning** (min, härledd ur 8.2)
| Leverabel | Fiverr/junior | Mellansegment (DD-nära) | Senior |
|---|---|---|---|
| Målat frontalt monster, 512 px, **en** pose, transparent PNG, PSD-lager | 60–120 USD | **200–350 USD** | 500–700 USD |
| Boss, 1024 px, 2 poser (idle + brytpunkt) | 150–300 USD | **400–600 USD** | 900–1 400 USD |
| Hjälteporträtt 1024 px + halvfigur, transparent | 70–150 USD | **180–280 USD** | 400–600 USD |
| Korridormiljö (kaklad vägg + golv + tak + dörr, tre djup) | 100–200 USD | **250–400 USD** | 600–900 USD |
| 4 raritetsramar + 7 slot-glyfer i Ravenmore-hand | 60–120 USD | **120–200 USD** | 300–500 USD |

**Ledtid (uppskattning, samma källbas):** Fiverr/junior **4–8 veckor** för hela batchen · mellansegment **8–14 veckor** · senior **12–20 veckor**. Räkna alltid **+2 veckor** för revisionsrundor.

### 8.4 Budget: "8 monster + 1 boss + 2 hjältar + 3 miljöer"
| Nivå | Räkning | **Totalt** | Ledtid |
|---|---|---|---|
| **Lågbudget** | 8×80 + 250 + 2×110 + 3×150 | **≈1 580 USD** (~17 000 kr) | 4–8 v |
| **Mellan (rekommenderad)** | 8×275 + 500 + 2×220 + 3×300 | **≈4 040 USD** (~43 000 kr) | 8–14 v |
| **Senior** | 8×550 + 1 000 + 2×450 + 3×700 | **≈8 400 USD** (~90 000 kr) | 12–20 v |

*(Växelkurs ~10,7 SEK/USD, uppskattning. Lägg till 2–4 veckor och 10 % för revisioner.)*

### 8.5 Så här briefar Anders (kopiera rakt av)
1. **Stilreferens, två bilder och inget mer:** `assets/incoming/ravenmore-fantasy-icon-pack/` (penseldrag, dov mättnad, mörk kontur) **+ en Darkest Dungeon-skärmdump** (ljussättning: en ljuskälla, hett rimljus på höger kant, 70 % av ytan nära svart).
2. **Anti-referenser, tre stycken:** "inte anime/JRPG-glansigt", "inte Blizzard-overwatch-rent", "inte AI-look med symmetriska ornament och smälta fingrar".
3. **Teknisk spec före stilspec:** 512×512 fiende / 1024×1024 boss, **transparent PNG + PSD med separerade lager**, ankarpunkt = fotlinjen, figuren fyller ≥85 % av rutans höjd, **ingen egen skugga inbränd** (vi lägger kastskuggan själva).
4. **Palettfil bifogas** (`.gpl` ur `UI_GUIDE §2`) med kravet att sot/eld/ben-familjerna följs.
5. **Betald testuppgift först:** ett monster, 80–150 USD, innan batchen läggs.
6. **Avtal:** work for hire / full buyout, exklusiv, evig, världsomspännande + uttrycklig **"no generative AI"-klausul** + krav på WIP-lager som bevis (se §9 varför).
7. **En artist för alla 9 fienderna.** Stildrift mellan leverantörer är den vanligaste dödsorsaken (`ART_DIRECTION_V2 §3`).
8. **Beställ inte förrän progressionen är rolig.** Detta står redan i `ART_DIRECTION_V2 §3` och gäller oförändrat.

---

## 9. AI-genererad målad konst – läget 2026, ärligt igen

**Min rekommendation är oförändrad: nej som slutasset.** Men skälen har blivit *starkare*, inte svagare, sedan v2.

### 9.1 Marknadsläget
| Fakta | Källa (hämtad 2026-09-22) |
|---|---|
| AI-deklarerade Steam-släpp: **10,9 % (2024) → 19,9 % (2025) → 30,8 % (2026 hittills)** | [Cinevva, 2026-07-20, referat av GameDiscoverCo-data](https://app.cinevva.com/news/2026-07-20-steam-ai-disclosure-study) |
| Steam Next Fest juni 2026: **~20 % av demos** har AI-deklaration; **10 av topp-100** | [PCGamesN](https://www.pcgamesn.com/steam/next-fest-2026-generative-ai), [Llama & Griffin AI Disclosure Report](https://www.llamagriffin.com/Data/SteamNextFestJune2026/part-2.html) |
| GameDiscoverCo: **21,2 % (feb 2026) → 26,5 % (juni 2026)** deklaration | [pccentral.net](https://pccentral.net/steam-next-fest-june-2026-generative-ai-disclosure-stats-reveal/) |
| Publikens inställning: **62,7 %** av 1,75 M spelare *mycket* negativa; **68,6 %** av Steam-användare ogillar AI-innehåll | `research/04` källa 3 och 4 (verifierat tidigare) |

**Tolkning:** AI-deklaration är inte längre ett stigma som isolerar en — en tredjedel av alla släpp gör det. **Men** publiken har inte mjuknat, och **vår genre (dark fantasy roguelike med hantverksestetik) har den mest AI-fientliga publiken som finns.** Att vara i majoriteten skyddar inte mot att vara i fel majoritet.

### 9.2 Plattformskraven
- **Steam:** deklaration på butikssidan är obligatorisk för generativ AI i det shippade innehållet.
- **itch.io:** obligatorisk `AI Generated`-tagg på **allt** som innehåller AI-output, **även handretuscherat**; otaggade paket indexeras inte ([itch.io Developer Updates](https://itch.io/t/4309690/generative-ai-disclosure-tagging)). **Detta smittar uppåt:** använder vi ett AI-assisterat assetpaket är vi skyldiga att deklarera.
- **Google Play:** [AI-Generated Content-policyn](https://support.google.com/googleplay/android-developer/answer/14094294) träffar i första hand appar som **genererar innehåll åt användaren i körtid** (chattbotar, bildgeneratorer) och kräver då tydlig märkning i appen. **Förproducerade assets träffas normalt inte** — men Play kräver korrekt ifylld Data safety-deklaration oavsett, och 2026 års policyskärpning mot "low-value AI apps" gör att gränsdragningen är rörlig. **[verifiera före release]**
- **App Store:** åldersmärkning och innehållsdeklaration gäller som vanligt; ingen särskild AI-grafikregel identifierad. **[verifiera]**

### 9.3 Juridiken — det starkaste argumentet, och det är inte etik
US Copyright Office: **ren AI-output saknar den mänskliga upphovsman som krävs** ⇒ den delen ligger i public domain och **konkurrenter får kopiera den lagligt**. Mänsklig bearbetning ("reworking proportions, adding expressive detail, painting over outputs") är skyddsbar, och vid registrering **måste** AI-material deklareras och det mänskliga bidraget beskrivas ([Promise Legal, 2026](https://blog.promise.legal/ai-game-assets-what-studios-own-2026/), [Ashurst/Perkins Coie](https://www.ashurstperkinscoie.com/en/insights/copyright-for-ai-generated-visual-content-in-video-games/), [Neal & Leroy om USCO:s 2025-rapporter](https://www.nealandleroy.com/post/taking-a-closer-look-what-the-copyright-office-s-2025-ai-reports-mean-for-2026), hämtade 2026-09-22).

**Konsekvens för PIPWRECK:** om SLAGJAW är AI-genererad äger vi honom inte. För en premiumtitel med DLC-plan är det ett affärsproblem, inte bara ett samvetsproblem.

### 9.4 Vilka verktyg som faktiskt ger konsekvent stil 2026
- **Midjourney** `--sref` (style reference) och `--oref`/`--ow` (omni reference) — beskrivs som den renaste stil-låsningen över ett helt projekt.
- **Flux.2 + tränad LoRA** — "den föredragna basen för karaktärsarbete 2026"; en **stil-LoRA behöver 30–80 bilder** för att generalisera.
- **Qwen-Image / SD + custom LoRA** — mest kontrollerbart för långa serier.
- Källa: [Cliprise, "The Complete Guide to AI Image Generation in 2026"](https://medium.com/@cliprise/ai-image-generation-in-2026-midjourney-flux-2-imagen-4-and-beyond-7934a9228e98), [Tech Insider LoRA-guide 2026](https://tech-insider.org/train-custom-ai-image-lora-2026/) (hämtade 2026-09-22).
- **Fångsten:** en stil-LoRA som verkligen ger *vår* stil kräver 30–80 bilder **i vår stil** — vilket vi inte har. Tränar vi på Ravenmores 29 ikoner tränar vi på **någon annans upphovsrättsskyddade verk**, och CC-BY 3.0 tillåter inte självklart det.

### 9.5 Rekommendation §9
1. **Nej till AI som slutasset i builden.** Oförändrat från `DECISIONS 2026-09-21` och `ART_DIRECTION_V2 §3 väg C`.
2. **Ja till AI som skiss- och mellansteg:** moodboards, silhuettvarianter, kompositionstester, **och — nytt i v3 — som underlag till beställningsbriefen i §8.5**. Att skicka artisten fem AI-skisser av `IRON_TICK` kortar revisionsrundorna och kostar ingen upphovsrätt, eftersom bilden aldrig når builden.
3. **Hårdgräns oförändrad:** >~30 % av en levererad pixel AI-genererad och orörd ⇒ deklarera.
4. **Nytt krav:** varje assetpaket i `assets/incoming/` ska ha raden `AI: ja/nej/okänt` i `KÄLLA.txt`. "Okänt" räknas som ja tills motsatsen visats.
5. **Om PM ändå väljer AI-vägen:** då är den enda hederliga formen *AI som skiss + handretusch av en människa*, deklarerat på alla tre plattformarna, och då kostar retuschen ungefär lika mycket som att beställa direkt (uppskattning). Det är därför jag inte rekommenderar den.

---

## A. Rekommenderad korg i målad stil — **8 nedladdningar, Ravenmore som ankare**

Vald för **en hand så långt det går**, och för att allt som inte är den handen ska vara *neutralt* (monokroma glyfer, stilneutrala partiklar, texturer som ändå ligger i 85 % mörker).

| Ordning | Paket | Licens | Varför just denna | Kostnad |
|---|---|---|---|---|
| **1** | **Ravenmore – Fantasy Icon Pack 2.0** (OGA) | CC-BY 3.0 | **Ankaret.** 29 målade ikoner i 512/128/64 + **PSD** ⇒ vi kan måla om till våra 22 föremål i hans hand. | 0 kr |
| **2** | **Ravenmore – Fantasy Portrait Pack** (OGA) | CC-BY 3.0 | Samma hand, 4 porträtt 256 px. Könsvalet + Marrow/Hob. | 0 kr |
| **3** | **Ækashics Librarium – Bundle Ultrapack** | [egen licens] credit + länk till akashics.moe, ingen vidaredistribution | **900+ målade frontala battlers.** Löser hela bestiariet i ett svep. Tonen justeras av vår grade. | 0 kr |
| **4** | **Painterly Spell Icons part 1–4** (J. W. Bjerk) | **CC-BY 3.0-grenen** | 256 px målade ikoner i **tre kraftnivåer** = raritetssystemet färdigritat. | 0 kr |
| **5** | **Handpainted RPG icons** (OGA) | CC-BY 3.0 | 37 ikoner i exakt Ravenmores fyra storlekar. Fyller luckorna i 22-listan. | 0 kr |
| **6** | **kaczor237 – Stylized Mossy Dungeon Wall + Stylized Dungeon Stone Floor** | CC0 | **Handmålad seamless vägg och golv från samma hand.** Korridoren, klar. | 0 kr |
| **7** | **Lamoot – RPG GUI construction kit v1.0** (OGA) | CC-BY 3.0 | Målade ramar + GIMP-källa. Enda UI-paketet som tonmässigt möter Ravenmore. *(Byt till **Ravenmore Fantasy UI Elements** om §5.2 visar sig vara CC-BY.)* | 0 kr |
| **8** | **Kenney – Fantasy UI Borders** | CC0 | 140 9-slice-assets, platta och tysta. Bärare där ramen ska hålla käften. | 0 kr |

**Summa: 8 nedladdningar, 0 kr, 5 attributionsrader** (Ravenmore ×2, Bjerk, Handpainted RPG icons, Lamoot) **+ 1 credit-och-länk-rad** (Ækashics).
Ljud/musik/fonter: oförändrat, se `ASSET_SHOPPING_LIST.md §6–§7, §9`.

**Två köp som jag skulle lägga till för under 200 kr** (utanför de 8, men ärligt värda pengarna):
- **UnitSix "Utility – Art Pack | Dark Fantasy"**, ~10 AUD, **CC BY 4.0** — 48 målade porträtt + helfigurer + **färdiga silhuetter** + lagerfiler.
- **Juan Art "HD Dark Fantasy RPG Portraits & Half-Body Sprites"**, 4,99 USD, handmålat utan AI — halvfigurerna löser character sheet utan paperdoll.

---

## B. Vad som INTE går att få gratis — och vad det kostar

| Lucka | Varför gratis inte räcker | Prislapp (uppskattning) |
|---|---|---|
| **8 monster + 1 boss i Ravenmores dova ton** | Ækashics är frontal, målad och gratis — men mättad JRPG-ton. Grade tar oss ~80 % dit. De sista 20 % (silhuettspråket i `§3.1`: `IRON_TICK` bredare än korridoren, `RUST_RAT ×4` i djupled) kräver figurer designade för *vår* läsning. | **≈2 700 USD** mellansegment (8×275 + 500). Lågbudget ≈890 USD. |
| **2 hjältar i helfigur med 7 utrustningslager (målad paperdoll)** | Finns inte gratis, går inte att plocka ihop — lagren måste målas mot samma kropp i samma ljus av samma person. | **600–1 200 USD**. **Eller 0 kr** med kompromissen i §2.8 (porträtt + ikoner i slots). |
| **3 miljöer med konsekvent ljus i tre djup** | Texturer finns gratis (4.6/4.7). *Komponerade* korridorer med vår ljussättning gör det inte. | **≈900 USD** mellansegment (3×300). **Eller 0 kr** om vi bygger djupet i shader ur de kaklade texturerna, vilket `CORRIDOR_DESIGN §2.4` faktiskt redan beskriver. |
| **`SLAGJAW_TOOTH` och `SIXTH_SEAT` (drömdropparna)** | `PROGRESSION_REDESIGN §3.5` säger att systemet *behöver* två föremål vars rykte sprider sig. Ett omfärgat lagerpaket duger inte till det. | **2×150–250 USD** |
| **4 raritetsramar + 7 slot-glyfer i Ravenmore-hand** | Går att fejka med Gems (3.5) + game-icons.net (3.6). | **120–200 USD** om vi vill ha det gjort ordentligt. **Eller 0 kr.** |
| **Summa om allt beställs** | | **≈4 000–4 500 USD** (~43–48 000 kr) |
| **Summa för det minimum jag faktiskt rekommenderar** | 8 monster + 1 boss + 2 drömdroppar, allt annat löst gratis | **≈3 000 USD** (~32 000 kr) |

---

## C. Credits-mall och mappnamn

### C.1 Tillägg till `assets/credits.txt`
Lägg till under respektive rubrik i den mall som redan finns i `ASSET_SHOPPING_LIST.md §B`. **Ta bort rader för paket vi inte använder.**

```text
ART  (CC BY 3.0 / 4.0 — attribution required)
---------------------------------------------
Fantasy Icon Pack 2.0 by Ravenmore (Daniel Kvarfordt).
  https://opengameart.org/content/fantasy-icon-pack-by-ravenmore-0
  https://ravenmore.itch.io
  Licensed under Creative Commons Attribution 3.0
  https://creativecommons.org/licenses/by/3.0/

Fantasy Portrait Pack by Ravenmore (Daniel Kvarfordt).
  https://opengameart.org/content/fantasy-portrait-pack-by-ravenmore
  https://ravenmore.itch.io
  Licensed under Creative Commons Attribution 3.0
  https://creativecommons.org/licenses/by/3.0/

"Painterly Spell Icons" by J. W. Bjerk (eleazzaar)
  www.jwbjerk.com/art
  find this and other open art at: http://opengameart.org
  Used under the Creative Commons Attribution 3.0 branch of its multi-license.
  https://creativecommons.org/licenses/by/3.0/

"Handpainted RPG icons" — OpenGameArt.
  https://opengameart.org/content/handpainted-rpg-icons
  Licensed under Creative Commons Attribution 3.0
  https://creativecommons.org/licenses/by/3.0/

RPG GUI by Matjaz Lamut (Lamoot), CC BY 3.0
  https://opengameart.org/content/rpg-gui-construction-kit-v10
  https://creativecommons.org/licenses/by/3.0/

"Utility - Art Pack | Dark Fantasy" by UnitSix.
  https://unitsix.itch.io/utility-unitsix-art-pack
  Licensed under Creative Commons Attribution 4.0
  https://creativecommons.org/licenses/by/4.0/

"SlashFX" by Jason Tomlee.
  https://jasontomlee.itch.io/slashfx
  Licensed under Creative Commons Attribution 4.0
  https://creativecommons.org/licenses/by/4.0/

ART  (creator's own licence — credit required by the creator)
-------------------------------------------------------------
Monster battlers by Aekashics / AEkashics Librarium.
  https://www.akashics.moe
  Used under the Librarium Terms of Use.

ART  (creator's own licence — credit not required, given anyway)
----------------------------------------------------------------
"HD Dark Fantasy RPG Portraits & Half-Body Sprites" by Juan Art.
  https://juan-art.itch.io
"Stylized Dungeon Wall / Floor" by kaczor237 (CC0 1.0).
  https://kaczor237.itch.io

PUBLIC DOMAIN  (CC0 1.0 — no attribution required, credited anyway)
-------------------------------------------------------------------
Fantasy UI Borders and Particle Pack — Kenney (kenney.nl) (CC0 1.0)
"Fantasy RPG Icons 3" — OpenGameArt (CC0 1.0)
Textures — ambientCG, Poly Haven (CC0 1.0)
```

**Normativa regler (oförändrade från `§B` i pixellistan):** credits-skärmen ska vara nåbar offline och utan konto; varje CC-BY-rad ska ha **verk + upphovsperson + källänk + licenslänk**; raden läggs in samtidigt som assetet importeras; `assets/ASSET_LICENSES.csv` är sanningen och `credits.txt` genereras ur den.

**Ny regel för v3:** Ækashics-raden är ett **licensvillkor, inte en artighet** — den och länken till `www.akashics.moe` måste finnas så länge en enda av hans battlers ligger i builden.

### C.2 Mappnamn i `assets/incoming/`
Gemener, bindestreck, inga å/ä/ö, inga mellanslag:

```
assets/incoming/ravenmore-fantasy-icon-pack/
assets/incoming/ravenmore-fantasy-portrait-pack/
assets/incoming/ravenmore-rpg-icons-gems/
assets/incoming/aekashics-librarium-ultrapack/
assets/incoming/jwbjerk-painterly-spell-icons/
assets/incoming/opengameart-handpainted-rpg-icons/
assets/incoming/opengameart-fantasy-rpg-icons-3/
assets/incoming/kaczor237-stylized-dungeon-wall-floor/
assets/incoming/oleekconder-stylized-dungeon-textures/
assets/incoming/lamoot-rpg-gui-construction-kit/
assets/incoming/kenney-fantasy-ui-borders/
assets/incoming/unitsix-utility-dark-fantasy-art-pack/
assets/incoming/juanart-hd-dark-fantasy-portraits/
assets/incoming/juanart-dark-fantasy-tavernkeeper/
assets/incoming/jasontomlee-slashfx/
assets/incoming/game-icons-net-all-svg/
```

### C.3 `KÄLLA.txt` — mall för v3 (en per mapp)

```text
Paket:        Fantasy Icon Pack 2.0
Skapare:      Ravenmore (Daniel Kvarfordt)
URL:          https://opengameart.org/content/fantasy-icon-pack-by-ravenmore-0
Spegel:       https://ravenmore.itch.io/fantasy-icon-pack
Hämtad:       2026-09-2X
Licens:       CC-BY 3.0
Licenstext (klistrad ordagrant från sidan den dag jag laddade ner):
"<klistra in exakt vad som stod i licensrutan>"
Attribution krävs:  JA — namn + verk + källänk + licenslänk, samt länk till ravenmore.itch.io
Vidaredistribution: FÖRBJUDEN som del av annat assetpaket (itch-sidans villkor)
AI:           nej            <-- NYTT KRAV i v3, se §9.5. "okänt" räknas som "ja".
Skärmdump av licensrutan:  license-screenshot.png
Anteckning:   PSD-källa ingår — den är hela poängen med paketet.
```

**Tre saker som är lätta att slarva med (oförändrat + ett nytt):**
1. **Ta skärmdump av licensrutan.** itch- och OGA-sidor kan redigeras i efterhand.
2. **Packa inte upp i `assets/sprites/`.** `incoming/` har `.gdignore`; UI-agenten skalar om, graderar och registrerar i `ASSET_LICENSES.csv`.
3. **NYTT: fyll i `AI:`-raden.** Står det inget på sidan — sök devloggen och kommentarerna innan du skriver "nej".

---

## Osäkerhet

- **Ingen rad i detta dokument är läst i primärkälla.** Proxyn blockerar `opengameart.org`, `itch.io`, `akashics.moe`, `kenney.nl` och `craftpix.net` på CONNECT-nivå (403, testat 2026-09-22). Allt kommer från sökutdrag. **Den enda raden jag bedömer som hög risk att den är fel är 2.1** — ett utdrag påstod CC0 för Ravenmores porträttpack, vilket motsäger alla andra utdrag och hans egen praxis. Utgå från CC-BY 3.0.
- **Ækashics licens (1.1) är hela korgens svagaste punkt.** Villkoren låter perfekta i utdragen ("any game engine, any game project, commercial, credit + link"), men jag har inte läst `akashics.moe/terms-of-use` ordagrant. **Läs hela sidan innan en enda fil kopieras in i `assets/`.** Särskilt: gäller "free releases" samma villkor som köpta paket, och finns någon klausul om antal titlar?
- **Ravenmore har två olika licensformuleringar** — CC-BY 3.0 på OGA, egen text på itch ("credit not required, no redistribution as part of another pack"). De är inte identiska. **Vi följer den striktare tolkningen:** kreditera *och* distribuera aldrig vidare.
- **§4.9 (Handpainted Stone Wall Textures)** har motstridiga licenser på samma sida enligt kommentarsfältet. Behandla som CC-BY 4.0.
- **AI-status är verifierad för AssetSmithy, Studio NIK, EnchantedTranquility och Kalponic** (skaparna skriver ut det själva). Den är **inte** verifierad för Vill8tion (3.7, "4K upscaled") och Rune Foundry (5.4). Kontrollera innan nedladdning.
- **Alla priser i §8.3–§8.4 är mina uppskattningar**, härledda ur de verifierade marknadssiffrorna i §8.2. De är inte offerter. Anders bör hämta **tre** offerter innan något bokas.
- **Den största osäkerheten är inte licensjuridisk utan estetisk:** att Ækashics mättade JRPG-ton går att grade:a in i Ravenmores dova värld är **min uppskattning, inte ett faktum**. Den bör bevisas med en mockup på 30 minuter innan PM budgeterar för alternativet.

---

## Rekommendation till PM

1. **Godkänn korgen i §A (8 nedladdningar, 0 kr) och lägg till de två mikroköpen (UnitSix ~70 kr, Juan Art ~55 kr).** Ravenmore-ankaret plus Ækashics löser ikoner, porträtt, UI, korridor *och* ett helt bestiarium till noll kronor. Det är ett bättre utgångsläge än pixelkorgen någonsin var.
2. **Gör stil-testet innan något annat.** Ta **en** Ækashics-battler, kör den genom `ART_DIRECTION_V2 §4`-behandlingen (desaturera, rimljus från facklan, 0,55 vinjett, 6–8 % grain), lägg den bredvid en Ravenmore-ikon och visa Anders. **Hela korgens värde hänger på om de två ser ut att komma från samma värld.** Säger han nej där är 8 monster ≈2 700 USD det enda alternativet, och det beslutet ska tas nu, inte i M7.
3. **Besluta om paperdoll redan nu (§2.8).** Kompromissen "målat porträtt + gear som ikoner i slots, helfigur senare" sparar 600–1 200 USD och kräver bara att `CORRIDOR_DESIGN §4.3`-animationen flyttas från kroppen till sloten. Det är en halvdags omskrivning i design nu, mot en kostsam beställning senare.
4. **Skriv in tre nya förbud i `DECISIONS.md`:** (a) OGA "The Free Monsters" är CC-BY-SA + GPL och föreslås aldrig igen; (b) Buch "Golden UI – Bigger Than Ever" är CC-BY-SA; (c) **inget AI-assisterat assetpaket in i repot utan PM-beslut** — och `KÄLLA.txt` får en obligatorisk `AI:`-rad.
5. **Låt budgeten vara oförändrad på ≈150 USD nu.** §8 behövs först när progressionsomtaget är byggt och spelet är roligt. Det enda undantaget: **de två drömdropparna** (`SLAGJAW_TOOTH`, `SIXTH_SEAT`, 2×150–250 USD) kan beställas tidigt, eftersom de är små, isolerade och `PROGRESSION_REDESIGN §3.5` uttryckligen kräver att de sticker ut.

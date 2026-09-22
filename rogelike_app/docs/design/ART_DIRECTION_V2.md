# ART_DIRECTION_V2.md – PIPWRECK

**Ägare:** UI/UX · **Datum:** 2026-09-22 · **Status:** underlag till Anders efter speltest 4 · **Beslut krävs**

> **Källläge, ärligt.** Den här omgången hade **noll nätåtkomst**: `WebSearch` är avstängd
> för sessionen, och proxyn svarade `403 connect_rejected` på *allt* jag testade
> (itch.io, gamedevmarket.net, oryxdesignlab.com, craftpix.net, artstation.com,
> store.steampowered.com, gdcvault.com, wikipedia.org, darkestdungeon.wiki.gg).
> Källor märkta **[V]** är verifierade tidigare i projektet (`docs/research/04`,
> hämtade 2026-09-21). Källor märkta **[O]** är **overifierade** – URL och siffra
> kommer ur min kunskap, inte ur en hämtning idag. Alla priser är **uppskattningar**.
> Anders: kontrollera **[O]**-raderna själv innan pengar rör sig.

---

## 1. Ärlig diagnos: varför spelet är fult

Underlag: `docs/screenshots/m5_int/` och `docs/screenshots/web_tutorial/`.
Anders har rätt. Det här är inte en smaksak, det är mätbart. Betyg 1–10.

| Område | Betyg | Vad som faktiskt är fel |
|---|:--:|---|
| **Sprite-kvalitet / teckning** | **3** | Varenda figur är en *scriptgenererad primitiv*: ellips + platta + taggar + prickar, utplacerade med koordinater i `tools/gen_pixel_assets.py`. Ingen människa har ritat en pixel. "Tick Pup" är en grå ellips med fyra ljusprickar. Ingen anatomi, ingen linjeföring, ingen inre skuggning, ingen läsbar silhuett. Det syns direkt. |
| **Upplösning / skala** | **2** | Fienderna är **32×32 px** (`128×64`-ark, 4×2 frames), bossen 48×48. De renderas 4–7× uppskalat på en 1080-bred skärm. Varje "pixel" blir en 5–7 dp kloss. Det läser som *lågupplöst*, inte som *pixelkonst*. Hjälten ligger på 48×48 och är lika utsatt. |
| **Textur / material** | **3** | En och samma brus-/ditherväv ligger på golv, väggar **och** tak i korridoren. Samma textur överallt = inget material, ingen berättelse, ingen skala. Ögat läser det som TV-snö, inte som sten. |
| **Ljussättning** | **2** | Det finns **ingen**. Facklorna i korridoren är 4 px orange streck som inte lyser på någonting. Inga skuggor, inget kantljus, ingen riktning. Detta är den enskilt största orsaken till att bilden känns platt och billig. |
| **Atmosfär / djup** | **4** | Perspektivkorridoren i sig fungerar (bra jobbat, dev). Men djupet skapas bara av geometri – kontrasten är identisk längst fram och längst bak, ingen dis, inga partiklar i luften, ingen rörelse. |
| **Komposition / kamera** | **3** | Fienden svävar mitt i bild, i mitten av höjden, utan golvkontakt och utan storleksrelation till något. Boss och trashmob ramas exakt likadant. Stor död yta i övre tredjedelen. Ingen beskärning, ingen kameravinkel, ingen dramaturgi. |
| **UI-täthet** | **2** | I `25_boss_pair.png` räknar jag **19 ramade rektanglar samtidigt** (5 slots + 6 tärningar + kedjepanel + toppfält + 3 knappar + parbågen + 2 chips). Lådor inuti lådor inuti lådor. Ögat hittar ingen ingång. Detta är värre än spriteproblemet i praktiken, och billigast att laga. |
| **Typografi** | **5** | Fonterna (Familjen Grotesk, Anton, Caveat Brush) är bra val och redan bundlade. Men de används nästan platt: allt ligger mellan 11 och 24 px, **Anton används knappt**, och `104 DAMAGE` – spelets hela dopaminögonblick – sätts i 26 px grå brödtext. Hierarkin är bortkastad. |
| **Färgpalett** | **4** | Paletten i `UI_GUIDE §2` är genomtänkt och har åtta semantiska färger. Scenen använder i praktiken **två**: blågrå `#1F262E` och rosa HP. Världen är monokrom kallgrå, elden syns inte, guldet syns inte. |
| **Animation / juice** | **4** | 4-frames idle + 3-frames död finns och död-läsbarheten är genomtänkt (`assets/sprites/README §1`). Men stillbilderna visar ingen hitstop, ingen träffblixt, inga partiklar kring fienden. |

**Sammanvägt: 3,2 / 10.** Spelet ser ut som en teknisk prototyp, för det *är* en teknisk prototyp.

**Grundorsaken, klartext:** `DECISIONS 2026-09-21` slog fast att vi skulle bygga på
CC0-paket (0x72, Kenney, Pixel Frog, Szadi, Penusbmic). **Inget av dem gick att hämta** –
egress-proxyn avvisade alla värdar [V, `assets/sprites/README §0`]. Dev löste det
hedersamt genom att skriva en generator som ritar primitiver i kod, och det var rätt
beslut för att komma vidare. Men en primitivgenerator kan aldrig producera konst.
Vi har byggt fem milstolpar på platshållare och kallat dem grafik.

---

## 2. Vad Darkest Dungeon gör – och vad vi kan låna

*Allt i detta avsnitt är **[O]** (overifierat denna session). Referenser att slå upp:*
- *Chris Bourassa (art director, Red Hook) & Tyler Sigman, GDC 2016 – "Darkest Dungeon: A Design Postmortem", gdcvault.com* **[O]**
- *Red Hook devblog "The Art of Darkest Dungeon" / Kickstarter-uppdateringarna 2013–2014* **[O]**
- *Bildreferens för moodboard: Steam-butikssidans skärmdumpar, `store.steampowered.com/app/262060/`* **[O]**
- *Stilförlagor Bourassa själv brukar nämna: **Mike Mignola** (Hellboy – tunga svarta massor), **Ben Templesmith** (tusch + akvarellplumpar)* **[O]**

| DD gör | Hur | **Stil eller innehåll?** |
|---|---|---|
| **Tung svart** | 60–75 % av skärmytan är nära-svart. Ljus är sällsynt och därför dyrbart. | **STIL – gratis.** En värdekurva, inget mer. |
| **Fackelljus som mekanik** | Facklan är både ljuskälla och systemresurs. Mörkare = högre crit, högre stress. Ljuset *betyder* något. | **STIL + design – billigt.** En radial-gradient-shader plus en siffra. |
| **Vinjettering** | Konstant, kraftig vinjett i varje vy. Bilden slutar aldrig i en rak kant. | **STIL – gratis.** 15 rader shader. |
| **Tusch + akvarell, handtecknat** | Tjocka oregelbundna konturer, laverade ytor, synligt papperskorn. | **INNEHÅLL – dyrt.** Konturerna *är* teckningen. Kan inte shadras fram. |
| **Kraftig komposition** | Låg kamera, figurer beskurna av ramen, fiender lutar in i bild, bossar bryter ramen. | **STIL – gratis.** Ren layout. |
| **Parallaxlager** | 3–4 djuplager i korridoren, olika hastighet, mörkare ju längre bak. | **STIL – billigt.** Vi har redan `floor1_parallax_far/mid/near.png`. |
| **Få frames, starka poser** | Cutout-dockor, ofta 4–8 frames. All läsbarhet ligger i **anticipation + håll**, inte i mjukhet. | **STIL – billigt** (timing), **innehåll – dyrt** (poserna är ritade). |
| **Stress-UI / narrator** | En andra resursmätare + en berättarröst som kommenterar. Bär hela tonen. | **STIL – nästan gratis.** Textraden kostar inget. VO kostar. |
| **Skadesiffror & hitstop** | Enorma siffror, hård screenshake, 60–120 ms frysruta, blodrött på svart. | **STIL – gratis.** Ren timing och typografi. |
| **Handmålade figurer & bakgrunder** | 60+ unika fiender, alla målade. | **INNEHÅLL – dyrast av allt.** |

**Den viktiga insikten för Anders:** på miniatyravstånd – vilket är hur en mobilskärm
faktiskt betraktas – bärs uppfattad kvalitet i DD av **värdestruktur och ljus**, inte av
teckningsskicklighet. Min uppskattning: **ungefär hälften av det upplevda lyftet går att
ta med noll nya assets.** Den andra halvan är bokstavligen ritad av en människa och kan
inte shadras fram. Mockupen i §4 finns till för att visa exakt var den gränsen går.

---

## 3. Tre vägar till "snyggt" utan grafiker i teamet

### Väg A – köpta assetpaket i en sammanhållen stil

Krav: kommersiell licens, **ingen** CC-BY-SA, **ingen** GPL (projektets regel, `research/04 §1`).
Anders laddar ner lokalt och committar – proxyn här släpper inte igenom något.

| Källa | Stil / innehåll | Pris (uppskattning) | Licens |
|---|---|---|---|
| **Oryx Design Lab – Ultimate Fantasy / Mega Pack** | 24×24, tunga silhuetter, mörk fantasy, hundratals fiender i *en* hand | ≈25–45 USD **[V-källa, pris O]** | Egen kommersiell licens, kräver credit till oryxdesignlab.com, ingen SA [V] |
| **Penusbmic** (itch) | Mest DD-nära pixelkonstnären: tunga silhuetter, 1 px outline, 8–12 frames animation, "dark fantasy"-serier | 5–15 USD/paket **[O]** | Kommersiell, ingen SA **[O]** |
| **Elthen / Ahmet Avci** (itch + Patreon) | Monster och karaktärer, varm mörk fantasy, välanimerade | 5–15 USD/paket, Patreon ≈10 USD/mån för hela biblioteket **[O]** | **Common Sense License 1.0** – kommersiellt OK, vidaredistribution förbjuden [V] |
| **Szadi art** (itch) | Miljö/tilesets: dungeon, katakomber, grottor | 8–20 USD/paket **[O]** | Kommersiell **[O]** |
| **CraftPix.net** – "Dark Fantasy"/gotiska 2D-paket | Miljöer, UI-kit, bossar | 10–40 USD/paket **[O]** | Kommersiell, vidaredistribution förbjuden. **Varning:** en del nyare CraftPix-paket är AI-assisterade – kontrollera per paket **[O]** |
| **GameDev Market** – dark-fantasy-buntar | Bred blandning, UI-kit | 10–50 USD **[O]** | Pro-licens **[O]** |
| **Humble "Game Dev Assets"-buntar** | 1000+ assets för 20–30 USD, återkommer några gånger/år | 20–30 USD **[O]** | Kommersiell, men **stilspretigt** – dålig passform här **[O]** |
| ~~**Unity Asset Store**~~ | — | — | **Undvik.** Unitys butiksvillkor begränsar i praktiken användning till produkter *byggda med Unity*. Det gäller **både** Godot och three.js. Inte värt risken. **[O – kontrollera EULA innan någon köper]** |

**Den regel som avgör om A lyckas:** högst **två** konstnärer totalt – en för fiender/figurer,
en för miljö – och sedan en gemensam **palett-LUT-shader** som tvingar allt in i PIPWRECKs
palett. Det är precis det greppet som får DD att se sammanhållet ut. Blandar man sex
itch-paket får man ett collage, oavsett hur bra varje paket är.

- **Kostnad:** 50–200 USD.
- **Tid:** 1–2 veckor integration. Sprite-kontraktet är redan förberett för byte –
  `assets/sprites/README §0` säger att filnamn, rutnät och cellstorlek matchar, och
  **inget i `src/game/` behöver röras**.
- **Risk:** ingen artist äger "vår" look; nästa monster vi hittar på finns inte i paketet.

### Väg B – beställd konst (Fiverr / Upwork / ArtStation)

Scope: **1 hjälte (med paperdoll-lager) + 8 monster (idle + död) + 5 miljöer + UI-kit.**
Alla siffror **[O]**, branschsnitt ur min kunskap – Anders bör hämta tre offerter.

| Nivå | Hjälte | Per monster | Per miljö | UI-kit | **Totalt** | Ledtid |
|---|---|---|---|---|---|---|
| Fiverr, pixel, animerad | 200–300 | 60–120 | 80–150 | 300–500 | **≈1 700–2 500 USD** | 4–8 v |
| Mellansegment, DD-nära handmålat | 600–900 | 250–400 | 300–500 | 800–1 200 | **≈5 000–7 500 USD** | 8–14 v |
| Erfaren shippad 2D-artist | 1 500+ | 600+ | 800+ | 2 000+ | **12 000–20 000 USD** | 12–20 v |

**Så briefar man (annars blir det dyrt två gånger):**
1. **Teknisk spec före stilspec:** 64×64 fiender / 96×96 boss, `hframes/vframes`,
   ankarpunkt = fotlinjen, transparent bakgrund, separata PSD-lager per utrustningsdel.
2. **Palett som fil** (`.gpl`/`.ase` ur `UI_GUIDE §2`), krav att den följs.
3. **3 referensbilder + 3 anti-referenser** ("så här ska det INTE se ut").
4. **Betald testuppgift först:** ett monster, 50–100 USD, innan hela batchen läggs.
5. **Avtal:** *work for hire / full buyout*, exklusiv, evig, världsomspännande, plus
   uttrycklig **"no generative AI"-klausul** och krav på WIP-lager som bevis.
6. **En artist, en batch.** Stildrift mellan leverantörer är vanligaste dödsorsaken.

**Risker:** artisten försvinner mitt i batchen (mildras av delleveranser + escrow);
smyg-AI (mildras av WIP-krav); och den dyraste – att vi beställer konst till mekanik
som sedan ändras. **Beställ inte konst förrän spelet är roligt.**

### Väg C – AI-assisterad konst med disclosure

**Ärligt omtag, som efterfrågat.** Anders sa nej 2026-09-21. Jag hade kunnat argumentera
emot om läget hade skiftat. Det har det inte, och jag rekommenderar **samma nej**.

Communityläget (siffrorna är verifierade i `research/04` [V]):
- **20,9 %** av 2025 års Steam-släpp deklarerade generativ AI; **62,7 %** av 1,75 miljoner
  spelare i Quantic Foundrys undersökning är *mycket* negativa [V, källa 3].
- **19,5 %** av Steam Next Fest-demos hade AI-deklaration; **68,6 %** av Steam-användarna
  uppger att de ogillar AI-innehåll [V, källa 4].
- Steam kräver deklaration på butikssidan. Google Play har en AI-policy som primärt
  träffar appar som *genererar* innehåll åt användaren i körtid – förproducerade assets
  träffas normalt inte, men **Steam-kravet gäller oavsett** och Play kräver korrekt
  ifylld dataskyddsdeklaration **[O – verifiera Play-policyn innan release]**.

Verktyg som faktiskt ger konsekvent stil: **PixelLab** (TOS: du äger outputen,
kommersiellt OK, ingen modellträning på din data) [V, källa 14], **Retro Diffusion**
[V, källa 15], samt egen LoRA tränad på *din egen* stilreferens + ControlNet på
egna silhuetter **[O]**.

**Min ståndpunkt:** skälen är inte bara etiska, de är praktiska. (a) AI-bilder är extremt
svåra att hålla konsistenta över 8 animationsframes × 9 figurer – man får nio olika stilar.
(b) Deklarationen kostar synlighet i exakt den genre vars publik är mest AI-fientlig.
(c) Den generiska "AI-look" som `UI_GUIDE §1` uttryckligen förbjuder är precis vad en
otränad modell levererar.

**Vad jag står fast vid** är det `DECISIONS 2026-09-21` redan tillåter: AI som **skiss- och
mellansteg** – moodboards, silhuettvarianter, kompositionstester, inbetweens mellan egna
key-frames. Aldrig oretuscherat i builden. Hårdgräns: **>~30 % av en levererad pixel
AI-genererad och orörd → deklarera.**

### Rekommendation och budget

**Kör steg 1 + 2. C avfärdas som slutasset.**

| Steg | Vad | Kostnad | Tid | När |
|---|---|---|---|---|
| **0. Stilskiktet** | Allt i §4: ljus, vinjett, värdestruktur, komposition, typografi, UI-bantning, hitstop. **Noll nya assets.** | **0 USD** | 3–5 dagar dev | **Nu, oavsett övriga beslut** |
| **1. Väg A** | Ett fiendepaket + ett miljöpaket, max två konstnärer, palett-LUT över allt | **≈150 USD** (tak 200) | 1–2 v | Direkt efter steg 0 |
| **2. Väg B, begränsad** | Hjälte med paperdoll-lager + 4 signaturfiender + bossen, beställda i **samma** stil som steg 1 | **1 500–2 500 USD** | 6–10 v | **Först när spelet är roligt** (efter progressionsfixen) |

**Total budget: ≈150 USD nu, ≈2 000 USD senare.** Motivering: steg 0 är gratis och ger
mest lyft per krona – och det avgör hur mycket vi faktiskt behöver köpa. Att beställa
konst innan progressionen sitter är det dyraste misstaget som finns i den här fasen.

---

## 4. Stilriktning v2: **SOTLJUS** (tusch och sot i fackelsken)

Detta är **inte** en ny riktning som kastar KRITGROPEN. Krit-UI:t (`UI_GUIDE §1 A`) står
kvar. SOTLJUS är den **världsbehandling** som saknades under det.

### Moodboard i text

- **Värdestrukturen är lagen.** 70 % av skärmen ska ligga mot nära-svart `#07090B`.
  Ljus är en bristvara och därför dramatisk. Detta ensamt tar oss längst.
- **En ljuskälla.** Facklan sitter bakom spelarens högra axel, nedanför bild. Allt
  ljusfall kommer därifrån. Fienden får ett hett kantljus (rim) på sin högra kant och
  är i övrigt silhuett. En sprite med kantljus och kastskugga läser som *modellerad*
  även när den är ritad av ett script – det är hela tricket.
- **Tre hue-familjer i världen, aldrig fler:** sot (kall blågrå skugga), eld
  (orange→rav, `#FF6A2C` → `#FFB258`), ben (varmvit `#E8E0CF`). Gift, frost, guld
  tillhör **UI-lagret** och får aldrig färga miljön. Detta är DD:s palettdisciplin.
- **Djup med dis, inte med detalj.** Tre korridordjup: nära = full kontrast, mellan =
  45 % svart overlay, fjärran = 85 %. Bort med den identiska brusväven på alla ytor –
  golvet behåller struktur, väggarna tappar den i mörkret, taket försvinner helt.
- **Vinjett + smuts, alltid på.** Fast vinjett ~0,55 plus ett statiskt grain-/smetlager
  på 6–8 % ovanpå allt. Billigaste "handgjorda"-tricket som existerar.
- **Komposition.** Fienden centreras **inte** i höjdled. Golvlinje på 62 % höjd, figuren
  beskuren nedtill av HUD-kanten, lätt inlutning mot bildens mitt. Boss ritas 1,6× och
  bryter ramen medvetet.
- **Typografi som vapen.** Anton är redan bundlad och används knappt. Skadesiffran går
  till **72–96 px versaler**, 3° snedställd, svart 4 px kontur + 1 px varm kant.
  Familjen Grotesk krymper till 11–12 px etiketter. Caveat Brush reserveras för **en**
  handskriven "narrator"-rad vid dramatiska ögonblick – DD:s berättarröst utan
  röstskådespelare, och den är gratis.
- **UI-brus ned med ~60 %.** Ingen ram inuti en ram. En slot = ikon + färgad underlinje,
  **ingen låda**. Kedjeuträkningen sätts direkt på svart utan panel. Tärningarna är de
  **enda** objekten på skärmen med egen upphöjd yta – då vet ögat alltid var handlingen är.

### Mockupen

`design/mockup_art_v2.html`. Verifierad på tre storlekar, skärmdumpar i `design/screenshots/`:
`art_v2_390x844.png` (referens), `art_v2_360x640.png` (liten), `art_v2_430x932.png` (stor).
Touch targets ≥ 48 dp, namnskylt och siffror ligger ovanför vinjetten så kontrasten håller ≥ 4,5:1.

**Viktigt för ärlighetens skull:** mockupen använder **exakt samma 32 px-spritefil**
som i speltestet (`assets/sprites/enemies/iron_tick.png`, frame 0, inbäddad som base64).
Ingen ny konst. Allt som skiljer är ljus, värde, palett, komposition, typografi och
UI-densitet. Sprite-rutan är markerad **"PLATSHÅLLARE · 32 px (befintlig)"** i mockupen.

**Vad mockupen bevisar går att få gratis:** fackelljus och kantljus, kastskugga och
golvkontakt, vinjett, dis-djup, palettdisciplin, kompositionen, typografihierarkin,
hitstop-siffran, narrator-raden, den halverade UI-tätheten.

**Vad mockupen bevisar att vi INTE kan få gratis:** figuren är fortfarande en ellips.
Kantljus gör en ellips till en *snyggt belyst* ellips. Silhuett, anatomi och inre
teckning kräver riktiga assets – väg A eller B. **Det är exakt där gränsen går.**

---

## 5. Motoroberoende – läs detta innan motorbeslutet

| Åtgärd | Godot 4.6 | three.js | Skillnad |
|---|---|---|---|
| Köpta/beställda assets (PNG, atlas, paperdoll-lager) | ✔ | ✔ | **Ingen.** Filerna är motoroberoende |
| Palett, värdestruktur, tre hue-familjer | ✔ | ✔ | **Ingen** |
| Komposition, beskärning, golvlinje, boss-skala | ✔ | ✔ | **Ingen** |
| Typografihierarki, skadesiffror, narrator-rad | ✔ | ✔ | **Ingen** (samma woff2/ttf) |
| UI-bantning (bort med lådor i lådor) | ✔ | ✔ | **Ingen** – ren layoutdisciplin |
| Hitstop, screenshake, partikeltiming | ✔ | ✔ | **Ingen** – samma millisekunder |
| Licensvillkor vid inköp | ✔ | ✔ | **Ingen** (inkl. Unity-Asset-Store-fällan, som drabbar båda) |
| Vinjett / fackelljus / palett-LUT **shader** | `.gdshader` | GLSL `ShaderMaterial` | Samma matematik, annan syntax. **≈1 dags omskrivning, totalt.** |
| Nearest-filtrering på pixelsprites | `texture_filter` | `THREE.NearestFilter` | En inställning |

**Slutsats:** **ungefär 90 % av allt som gör spelet snyggare är identiskt i båda motorerna,
för det handlar om assets och komposition – inte om rendering.** Motorbytet får därför
**inte** motiveras med "det blir snyggare i three.js". Det blir det inte. Byt motor om
det finns distributions-, verktygs- eller kompetensskäl – men fulheten följer med.

---

## Beslut som behövs av Anders

1. **Godkänn steg 0** (stilskiktet, 0 USD, 3–5 dagar) – bör köras oavsett allt annat.
2. **Godkänn ≈150 USD för väg A** och ladda ner paketen lokalt (proxyn blockerar här).
   Jag behöver veta vilka två konstnärer, sedan skriver jag stilguiden runt dem.
3. **Bekräfta att C (råa AI-assets) förblir nej** – jag rekommenderar det.
4. **Skjut väg B** tills progressionen sitter.

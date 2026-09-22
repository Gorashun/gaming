# 06 – Motorfrågan: är det Godot som gör PIPWRECK fult?

**Ägare:** rnd-roguelike · **Datum:** 2026-09-22 · **Status:** underlag till Anders efter speltest 4 (DECISIONS 2026-09-22, "STOPP för bygge")
Alla webbkällor hämtade **2026-09-22**. Fakta = källbelagt. **Uppskattning** = egen bedömning, uttryckligen märkt.

---

## Fråga

Anders: *"Spelet är fult. Kan vi byta till en snyggare motor, three.js kanske? Jag gillar inte hur det ser ut och funkar."*
Tre delfrågor: (1) beror utseendet på motorn? (2) kan Godot se ut som Darkest Dungeon / Slay the Spire / Vampire Crawlers? (3) vad kostar ett byte jämfört med att höja Godots visuella nivå?

---

## Slutsats (först)

1. **Nej, det är inte motorns fel. Uppskattningsvis 85–90 % av "fult" är art direction, belysning och UI-layout – noll av det är Godot-begränsningar.** Jag har gått igenom `docs/screenshots/m5_int/` bild för bild (§1). Korridoren renderas avsiktligt **helt utan ljus**: `corridor_mesh.gd:88` sätter `SHADING_MODE_UNSHADED` och `corridor_view.gd:276` sätter `ambient_light_source = AMBIENT_SOURCE_DISABLED`; enda "ljuset" är `FOG_MODE_DEPTH`. En scen utan ljussättning ser platt ut i **varje** motor. Väggarna är en 64 px procedurell brustextur utan valörvariation. Fienderna är 16 px-sprites i ett tomt fält. Character sheet är åtta tomma rundade rektanglar. Byter vi till three.js med samma assets får vi exakt samma fula spel i en annan runtime.
2. **Ja, Godot klarar Darkest Dungeon-nivå med marginal.** Bevis i §2. Det starkaste motargumentet mot "motorn sätter taket" är att **Slay the Spire är byggt på libGDX** – ett Java-*ramverk* med väsentligt mindre renderingsfunktionalitet än Godot 4 – och **Darkest Dungeon är Unity + handmålad Photoshop-konst + Spine**, inte någon särskild grafikmotor ([Wikipedia: Slay the Spire](https://en.wikipedia.org/wiki/Slay_the_Spire); [ArtStation: Darkest Dungeon, Brooks Gordon](https://www.artstation.com/artwork/VAVxX), båda hämtade 2026-09-22). Looken kommer från konsten, inte från runtime.
3. **three.js är inget motorbyte – det är ett bibliotekbyte nedåt.** three.js är ett renderingsbibliotek utan scengraf-editor, UI-system, input-abstraktion, ljudlager, sparning, i18n, partikelsystem, animationsstatemachine eller byggkedja ([three.js-guide, Seele AI, 2026](https://www.seeles.ai/resources/blogs/three-js-games-ultimate-guide), hämtad 2026-09-22). Vi skulle kasta ~18 300 rader GDScript i `src/` (varav 4 337 i `src/core/`) och 6 159 rader test / 424 testfunktioner, för att sedan bygga tillbaka det vi redan har – med **noll** visuell vinst dag 1.
4. **Rekommendation: stanna i Godot och kör en visuell strike-sprint (§5, Alternativ 1).** Uppskattning: 6–12 agentdagar ger en dramatisk skillnad; ett three.js-byte kostar 35–55 agentdagar bara för att stå still.

---

## 1. Vad exakt är fult? Post för post

| Vad man ser | Orsak | Godots fel? | Kostnad att fixa (uppskattning) |
|---|---|---|---|
| **Korridoren är platt grå gröt** (`20_corridor.png`): ingen kontrast mellan närmaste och bortersta väggen annat än linjär svartning; facklan på väggen lyser inte på någonting | **(b) Rendering.** Unlit-material + ambient avstängt + depth fog som enda djupsignal. Egen kod, inte motorbegränsning | Nej | 1–2 dagar |
| **Stentexturen läser som brus, inte som sten**: uniform valör, ingen fog/kant/smuts, samma 64 px-kakel på vägg, golv och tak | **(a) Assets.** `tools/gen_tileable.py` producerar noise, inte komposition | Nej | 2–4 dagar (köpt/ritad textur) |
| **Röda scanlines i taket** (`20_corridor.png`, `10_town_square.png`) | **(b) Buggartefakt** i takets UV/geometri – läser som ett renderingsfel, inte som stil | Nej (egen mesh-kod) | 0,5 dag |
| **Fienden är en 32 px-klick i ett tomt fält** (`24_combat_mid_chain.png`): ~55 % av stridsskärmens övre halva är tom, bakgrunden är en flat silhuettskyline utan djup, ingen markskugga | **(a) Assets + (c) UI-layout** | Nej | 3–5 dagar |
| **Textkollision i bossintro** (`25_boss_intro.png`): "SLAGJAW'S RUNT" ritas ovanpå tooltip-texten | **(c) Layoutbugg** | Nej | 0,5 dag |
| **Torget är en korridor med flata knappar klistrade ovanpå** (`10_town_square.png`); "GO DOWN" är en vit rektangel som bryter hela tonen | **(c) UI-design.** Knapparna tillhör inte världen | Nej | 1–2 dagar |
| **Character sheet = 8 tomma rundade rektanglar** (`30_character_sheet.png`), ~45 % död yta, inga föremålsikonor, inga ramar | **(c) UI-design + (a) saknade ikoner** | Nej | 1–2 dagar |
| **Allt är samma blågrå** (#0E1216-familjen) över hela spelet, ingen färgtemperaturkontrast | **(c) Art direction** | Nej | ingår ovan |
| Faktisk motorbegränsning vi träffat | Mobile/Compatibility-renderarna tillåter max **8 omni/spot-ljus per objekt** ([godot#107070](https://github.com/godotengine/godot/issues/107070), hämtad 2026-09-22). Vår korridor är **en enda ArrayMesh för hela våningen** ⇒ max 8 facklor totalt | **Ja, men trivial** | Lös med vertex-bakat ljus i `SurfaceTool` eller mesh per segment: 1 dag |

**Domen (uppskattning):** ~50 % av "fult" är belysning/kontrast, ~25 % är assets, ~15 % är UI-layout/typografi/död yta, ~10 % är renderingsbuggar (scanlines, textkollision). **0 % är "Godot kan inte".** Med bättre ljus + assets + UI-polish i Godot försvinner uppskattningsvis 85–90 % av problemet. Det som *inte* försvinner utan en riktig grafiker är nivån "handmålad Darkest-Dungeon-illustration" – och den nivån är otillgänglig i **alla** motorer utan grafiker.

---

## 2. Kan Godot se ut som Darkest Dungeon / Slay the Spire / Vampire Crawlers?

**Ja.** Shippade Godot-titlar med hög visuell kvalitet (alla verifierade som Godot, hämtade 2026-09-22):

| Spel | Studio / intäkt | Vad man kan lära | Bild |
|---|---|---|---|
| **Cassette Beasts** | Bytten Studio, ~4,1 MUSD | Full RPG, handritade monster, 2D-ljus och färgrik palett i Godot | [Wikipedia](https://en.wikipedia.org/wiki/Category:Godot_Engine_games) · [Steam](https://store.steampowered.com/app/1321440/) |
| **Dome Keeper** | Bippinbits, ~6,1 MUSD | Mörk underjord med **ljuspölar** – exakt vår korridorsituation, löst med 2D-ljus | [Steam](https://store.steampowered.com/app/1637320/) |
| **Halls of Torment** | Chasing Carrots | "Old school"-look (Arcanum/Nox/Planescape som referens) byggd i Godot | [Wikipedia](https://en.wikipedia.org/wiki/Halls_of_Torment) |
| **Buckshot Roulette** | Mike Klubnika, ~6,9 MUSD | Bevis att *stämning* (grain, ljussättning, kamera) slår polygonantal | [Wikipedia](https://en.wikipedia.org/wiki/Buckshot_Roulette) |
| **Brotato** | Blobfish | Vår genre, mobilreleasad, medvetet enkel men konsekvent stil | [Godot Showcase](https://godotengine.org/showcase/) |

**Kontrollfrågan går åt andra hållet:** de spel Anders pekar på är inte byggda i "snyggare motorer".
- **Slay the Spire** = libGDX, ett Java-ramverk *under* Godot i funktionalitet ([Wikipedia](https://en.wikipedia.org/wiki/Slay_the_Spire)).
- **Darkest Dungeon** = Unity, men looken är Chris Bourassas handmålade Photoshop-cutouts exporterade till **Spine** för rigg/animation ([ArtStation](https://www.artstation.com/artwork/VAVxX)).
- **Vampire Crawlers** (poncle/Nosebleed, 2026) = Unity ([Wikipedia](https://en.wikipedia.org/wiki/Vampire_Crawlers)).

**Vad som tekniskt krävs i Godot 4.6 – allt finns redan i motorn:**
- **2D-ljus:** `PointLight2D` + `LightOccluder2D` + `CanvasModulate` för global mörkerton ([Godot-docs, 2D lights and shadows](https://docs.godotengine.org/en/latest/tutorials/2d/2d_lights_and_shadows.html)). Varning: Godot beräknar 2D-ljus i viewport-upplösning, så skuggkanter glider sub-pixel över pixelkonst – kräver en snap-shader om vi vill behålla ren pixel-look ([Godot Lab, 2D lights guide](https://godotlab.org/en/tutorials/2d-lights-and-shadows)).
- **Normal maps** per sprite ger volym utan att rita om konsten ([GDQuest: Lighting with 2D normal maps](https://www.gdquest.com/tutorial/godot/2d/lighting-with-normal-maps/)).
- **Post-processing:** fullskärms-`ColorRect` med `ShaderMaterial` (vinjett, grain, färg-LUT) – vi har redan `palette_lut.gdshader`.
- **Partiklar:** `GPUParticles2D` (damm, gnistor, träffblixtar).
- **Skelettanimation:** inbyggt `Skeleton2D`/`Polygon2D`-cutout, eller **officiell spine-godot-runtime** som GDExtension för Godot 4.x ([Esoteric Software: spine-godot](https://en.esotericsoftware.com/spine-godot)) – samma pipeline som Darkest Dungeon använde.
- **3D-korridoren:** byt `SHADING_MODE_UNSHADED` mot ljus per segment, eller (billigare och säkrare på mobil) **baka ljus i vertex colors** i `SurfaceTool` och håll materialet unlit. Det kringgår 8-ljusgränsen helt och kostar noll GPU.

---

## 3. three.js ärligt jämfört

**three.js är ett renderingsbibliotek, inte en spelmotor.** Det saknar fysik, entity-system och editor och "du måste välja din egen game loop, fysik, UI och asset-workflow" ([Seele AI, three.js-guide 2026](https://www.seeles.ai/resources/blogs/three-js-games-ultimate-guide), hämtad 2026-09-22).

**Vad vi skulle behöva bygga eller hämta själva** (vi har det redan gratis i Godot): scengraf-hierarki finns ✔; men **UI-system** (Godots `Control`/anchors/Theme → DOM-overlay eller three-mesh-ui), **textrendering i portrait** med vår bundlade fontstack, **input/touch-abstraktion**, **ljud med pitch-scale**, **haptik**, **sparning/autosave**, **i18n via `tr()`**, **partikelsystem**, **tweens/AnimationPlayer**, **scenhantering**, **headless testramverk för renderingslagret**, **Capacitor-wrapper**, **Android/iOS-byggkedja + signering**, **AAB/target API 36**.

**Mobilspecifika risker (fakta):** Android-WebView använder olika GPU-drivrutiner per tillverkare, så WebGL-prestanda varierar även på samma SoC; scener som går fint i desktop-webbläsare börjar stamma i mobil-WebView redan över ~100 draw calls ([TEAM ARASHIYAMA: Phaser/Three.js + Capacitor-guide, 2026-04-23](https://t-arashiyama.com/2026/04/23/threejs-capacitor-android-2026/), hämtad 2026-09-22). Vår tidigare mätning (02_tech_stack.md [9]): Phaser 3 föll 60 → 46 FPS efter 8 min termisk throttling på Galaxy A54.

**App Store-risk (fakta):** Apple skärpte riktlinje **4.7** i november 2025 – 4.7.2 förbjuder uttryckligen att exponera native-API:er för icke-inbäddad HTML5/JS utan Apples godkännande, och WebView-appar avvisas rutinmässigt under 4.2 vid "minimum functionality" ([App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/); [MobiLoud-analys](https://www.mobiloud.com/blog/app-store-review-guidelines-webview-wrapper/), hämtade 2026-09-22). Ett Capacitor-spel med all JS **bundlad i binären** är normalt OK, men vi flyttar oss från noll granskningsrisk till en icke-noll.

**Vilka three.js-spel finns med mobilrelease?** Praktiskt taget inga kommersiella. De kända titlarna är webbdemos och portfolio-verk: HexGL (2012), Bruno Simons portfolio, Ironbane, HelloRun, Slow Roads ([Slow Roads](https://slowroads.io/), [threejsresources.com/games](https://threejsresources.com/games), hämtade 2026-09-22). Talande detalj: **Slow Roads – den mest framgångsrika three.js-titeln – bygger nu en desktopversion på Steam för att kunna tjäna pengar** ([Steam](https://store.steampowered.com/app/3431300/Slow_Roads/)). Jag hittade **ingen** three.js-byggd titel av betydelse på Google Play eller App Store.

### Jämförelsetabell

| Kriterium | **Godot + bättre assets** | three.js + Capacitor | PixiJS + Capacitor | Unity |
|---|---|---|---|---|
| Visuell takhöjd | Mycket hög (§2) | Hög i 3D, **svag i 2D-UI/text** | Hög i 2D, **ingen 3D-korridor** | Högst |
| Tid till "snyggt" utan grafiker | **Kortast** – allt finns, bara ljus + assets saknas | Längst – bygg motorn först | Lång | Lång (ny stack) |
| Vad som kastas av dagens kodbas | **0 rader** | `src/game/` (~14 000 rader) skrotas; `src/core/` (4 337) + tester (6 159) portas GDScript→TS, mekaniskt men manuellt | Samma som three.js | Allt |
| Mobilprestanda / batteri | Nativ, inget WebView-lager | WebView-throttling, drivrutinslotteri | Bäst av web-alternativen (PixiJS 8 höll 58–60 FPS i vår mätning) | Nativ |
| Binärstorlek | ~40 MB | Liten JS + WebView | Minst | 30–50 MB |
| Publicering | Play/TestFlight, nollrisk | Apple 4.7/4.2-risk | Samma | Nollrisk |
| AI-kodbarhet | God (konsekvent API, våra 424 tester fångar fel) | **Bäst corpus**, men vi skriver motorlogik själva = fler subtila buggar utan testnät | Bra | Stor men föråldrad corpus |
| Risk | **Låg** | Hög | Medel–hög | Hög |

**Den avgörande punkten:** ingen av dessa stackar ritar konst. Ett motorbyte löser inte problemet Anders faktiskt beskriver.

---

## 4. Kostnad för byte (agentdagar – **allt i detta avsnitt är uppskattning**)

| Alternativ | Uppskattade agentdagar till dagens funktionsnivå | Innehåll |
|---|---|---|
| **three.js + Capacitor** | **35–55** | Port `src/core/` GDScript→TS 5–8 · port 424 tester 4–6 · UI-lagret från noll (DOM/canvas-layout, tema, fonter, i18n) 12–18 · korridorrenderare 4–6 · ljud/haptik/sparning/settings 4–6 · Capacitor + CI + AAB/TestFlight 4–6 · prestandatrimning mobil-WebView 3–5 |
| **PixiJS + Capacitor** | **30–45** | Som ovan minus 3D, **plus** att korridoren måste byggas om som 2D-lager – exakt det alternativ 05_fps_korridor.md §1 avrådde från (60–180 perspektivritade väggbitar som kräver grafiker) |
| **Höj Godots visuella nivå** | **6–12** | Se §5. Ingen kod kastas, alla 407 tester fortsätter gröna |

Notera asymmetrin: bytet kostar 3–7× mer än fixen **och** levererar ingen grafik. **Uppskattning, med stor spridning** – jag har inte byggt någon av web-stackarna i detta projekt, och port-tiden beror helt på hur mycket av `src/game/` som visar sig vara logik snarare än nodhantering.

---

## 5. Rekommendation till PM – tre alternativ, rangordnade

### 🥇 Alternativ 1 (rekommenderas): Stanna i Godot, kör en visuell strike-sprint på 2 veckor

Åtgärder i **effektordning** (störst visuell effekt per dag först):

1. **Ljus i korridoren – 1–2 dagar.** Baka ljus i vertex colors via `SurfaceTool` (kringgår 8-ljusgränsen), varm fackelglöd med `OmniLight3D` eller emissiv quad vid varje fackla, byt fog-färgen från neutral svart till varmt mörkbrun, lägg till vinjett + filmkorn i en fullskärmsshader. **Detta ensamt ändrar hela intrycket.**
2. **Kontrast och färgtemperatur – 0,5 dag.** Kallt stenblått i skugga, varm orange i ljuspölar. Idag är allt samma valör.
3. **Fixa de två buggarna som läser som "billigt" – 1 dag.** Takets röda scanlines, bossbannerns textkollision.
4. **Stridsscenen – 2–3 dagar.** Större fiendesprites (mål 96–128 px), markskugga, parallaxbakgrund med djup, träffblixt + `GPUParticles2D` vid varje kedjesteg.
5. **UI-polish – 2 dagar.** Ramar och ikoner i character sheet (inga tomma rektanglar), bort med den vita GO DOWN-plattan, knappar som hör hemma i världen på torget, stram typografisk hierarki, mindre död yta.
6. **Assets – parallellt, kräver Anders.**

**Vad Anders måste göra (och det går inte att kringgå):**
- **Ladda ner assets lokalt.** itch.io, kenney.nl och opengameart.org är **egress-blockerade** i vår miljö (verifierat 2026-09-22: `EGRESS_BLOCKED` / connect-fel). Agenterna kan inte hämta dem. Anders laddar ner och lägger i `assets/` + `ASSET_LICENSES.csv`.
- **Pengar.** Uppskattning: 20–60 USD för ett kommersiellt pixel-/dungeonpaket täcker väggar, golv, ikoner och UI-ramar. En anlitad pixelartist för 20 fiender + 30 föremålsikoner: uppskattning 600–2 000 USD. Spine (om vi vill ha DD-liknande cutout-animation) är kommersiell licens; gratis alternativ är Godots inbyggda `Skeleton2D`.
- **Ett art-direction-beslut:** mörk handmålad gotik (DD) eller ren högkontrastpixel (Halls of Torment)? De kräver olika inköp.

**Efter 1 vecka ser Anders:** samma spel, men korridoren har fackelljus, ljuspölar och färgtemperaturkontrast, scanline-buggen är borta, stridsscenen har större fiender med markskugga och träffpartiklar. Före/efter-skärmbilder i samma vinklar som `m5_int/`.
**Efter 1 månad ser Anders:** inköpta/ritade väggar, golv, fiender, föremålsikoner och UI-ramar genom hela spelet, ny character sheet utan tomma rutor, gear-loot med riktiga ikoner, ljus och partiklar överallt – med **alla 407 tester fortfarande gröna** och Android-CI orörd.

### 🥈 Alternativ 2: Godot + anlitad grafiker/art director (om Anders vill ha DD-nivå på riktigt)

Alternativ 1 plus en människa som ritar. Detta är den **enda** vägen till Darkest Dungeon-nivå, och den är motoroberoende.
**Efter 1 vecka:** samma som Alt 1 + en beställd nyckelbild (korridor eller boss) som låser stilen. **Efter 1 månad:** första vågen handritade assets inne, en visuellt sammanhållen vertikal skiva.
Kostnad: uppskattning 600–2 000 USD + 2–4 veckors ledtid hos artisten.

### 🥉 Alternativ 3: Byt till three.js + Capacitor

Rekommenderas **inte**. Väljs bara om Anders primära mål är att *arbeta i JS/TS* snarare än att spelet ska bli snyggt – det är ett legitimt skäl, men det ska sägas högt.
**Efter 1 vecka:** en tom three.js-scen i Capacitor på en telefon, kanske korridoren utan UI. **Efter 1 månad:** uppskattningsvis 60–70 % av dagens funktionsnivå, utan tutorial och utan testnät – och fortfarande med samma assets, alltså fortfarande fult.

---

## Osäkerhet

- Procentsatserna i §1 och alla agentdagar i §4 är **egna uppskattningar**, inte mätningar.
- Jag har inte byggt en three.js/Capacitor-prototyp av PIPWRECK; port-tiden kan avvika kraftigt.
- Intäktssiffrorna för Godot-spelen kommer från en aggregatoranalys ([GodotAwesome](https://godotawesome.com/godot-games-table/)), inte från utvecklarnas egna uppgifter.
- Bild-URL:erna till Steam kunde inte hämtas härifrån (egress-blockerat); de är angivna för Anders att öppna, inte verifierade av mig.
- Jag har inte testat om 2D-ljusets sub-pixelglidning stör vår pixel-look i praktiken – det bör provas i steg 1.

---

## Rekommendation till PM (3 punkter)

1. **Kör Alternativ 1.** Inget motorbyte. Beställ en 2-veckors visuell strike-sprint i ordningen ljus → kontrast → buggar → stridsscen → UI. Inget spelinnehåll byggs under sprinten.
2. **Be Anders om ett art-direction-beslut och ett assetpaket nedladdat lokalt** innan sprintdag 4. Utan det fastnar vi på procedurellt brus igen.
3. **Visa före/efter i identiska vinklar efter vecka 1.** Om Anders då fortfarande säger "fult", är problemet art direction på en nivå som kräver Alternativ 2 (grafiker) – och då vet vi säkert att det aldrig handlade om motorn.

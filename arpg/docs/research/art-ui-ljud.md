# Research: Art, UI/UX, game feel och ljud

*Roller: art-3d-designer, ui-ux-designer, audio-designer. Datum: 2026-09-26.*
*Projekt: 3D chibi dark-fantasy-ARPG, mobil (Android först), PEGI 7+, isometrisk Diablo-kamera. Alla assets görs av oss.*
Källor anges som [n] och listas sist. Punkter märkta **(bedömning)** är vår egen slutsats, inte något en källa säger.

---

## 1. Art direction

### 1.1 Referenser: gulligt möter kusligt
| Spel | Vad vi lånar | Källa |
|---|---|---|
| **Don't Starve** (Klei) | Tim Burton/Edward Gorey-gotik, "mörkt och läskigt men med stark appeal". Sepia/avmättad värld, tydliga silhuetter | [1][2] |
| **Cult of the Lamb** | Medveten krock mellan söt och mörk. Jordiga, dova miljötoner med **mättade röda/lila/blå accenter bara på ritualer, fiendeattacker och viktiga objekt**. Serietydlighet gör fiendetyper lätta att känna igen | [3][4] |
| **Death's Door** | Enkla modeller, omsorg om ljus och textur, fast isometrisk vy som gör banor till "dioramor". Stilen håller bra FPS i intensiva strider | [5] |
| **Hades** (Supergiant) | Designdrivet art: "game design-led team". Stark färg per bioma, tydlig VFX-hierarki | [6] |
| **Torchlight 1–2** | Stylized ARPG med överdrivna proportioner och handmålade texturer; stilen åldras bra | (bedömning) |

### 1.2 Läsbarhet på liten skärm (en telefon på ~15 cm, kamera 10–15 m bort)
- **Silhuett först.** Chibi-proportioner (huvud ≈ 1/2,5 av höjden) plus överdrivna attribut (stor hatt, stort vapen, glödande ögon) läses på 60–80 px höjd. Testa varje karaktär som svart siluett i spelkamerans vinkel. (bedömning)
- **Värdehierarki.** Miljön ligger i låg kontrast och är avmättad. Spelare, fiender, projektiler och loot har högst ljushet eller mättnad. Samma regel som Cult of the Lamb [3].
- **Färgroller.** Fientliga projektiler har *en* reserverad färgfamilj (t.ex. orange-röd) som aldrig används i miljön. Spelarens effekter är kalla/vita. Loot använder rarity-färger (se 1.5).
- **Mark-telegrafering.** Bossattacker visas som platta decals på marken (cirkel/kon) som fylls upp. Det läses bättre än partiklar på små skärmar.
- **Rim/outline** separerar karaktärer från mörka golv (se 1.3).
- **Inget fint brus.** Undvik högfrekventa detaljtexturer; de blir flimmer vid nedskalning. Använd stora färgfält och gradienter.

### 1.3 Pipeline: low-poly/stylized på mobil
- **Geometri.** Hjälte ≤ 3k tris, fiende ≤ 1,5k, boss ≤ 10k (enligt rollspecen). Chibi-formen är gynnsam: få leder, stora ytor.
- **Textur.** En delad **gradient-/palettatlas** (t.ex. 256×256 med färgrutor och vertikala gradienter), där UV:erna placeras på rätt färgruta. Det ger 1 material för många objekt och bra batching, och det är trivialt att generera från skript. Vertex colors kompletterar (AO, fläckar).
- **Ljus.** 1 riktat realtidsljus plus bakat eller vertex-ljus. Kusligheten kommer från **fog-gradient, vinjett och punktvisa emissiva källor** (facklor, svampar, ögon), inte från många realtidsljus.
- **Toon-shader.** 2–3-stegs ramp (lookup-textur) + rim-ljus (Fresnel: `pow(1 - dot(N, V), k)`). Rim är i princip gratis på mobil-GPU eftersom N·V redan beräknas [7][8]. Unity URP har färdiga open source-exempel (Delt06/urp-toon-shader, MIT) [7] och Unitys egen Toon Shader dokumenterar rim-parametrar [9].
- **Outlines.** Inverted-hull (extruderat skal, back-face) kostar en extra draw per mesh men fungerar överallt. Screen-space-outline (depth/normal-kant) kräver en full-screen pass, vilket är dyrt på low-end Android. **Rekommendation:** inverted-hull endast på hjälte, fiender och loot. Miljön får bara rim. (bedömning)
- **Upplösning.** Rendera 3D i 0,7–0,85× skärmupplösning och UI i full upplösning. (bedömning, vanlig mobilpraxis)

### 1.4 VFX, best practice för mobil
- **Overdraw är fienden.** Använd få, stora, opaka eller alpha-clip-partiklar framför många additiva. Mesh-baserade VFX (swoosh-meshes med scrollande gradient) ger mest per millisekund.
- **Formspråk per källa.** Spelarens effekter är ljusa och spetsiga. Fiendeeffekter är mörka och rundade, med kant i reserverad färg. Läkning/pickups är mjuka och pulserande.
- **Kort livslängd:** 0,2–0,5 s för träffar. Långlivade effekter bara för mark-telegrafering.
- **Död = "puff".** Fiender pöser upp (squash & stretch), och sedan blir de rökmoln plus en liten själ-/irrbloss som flyger mot spelaren (valuta/XP). Det ger belöning utan gore och passar 7+.

### 1.5 Loot-strålar och rarity-visualisering
- Diablo 3: Legendary ger ett "loud clang", en orange ljusstråle och en ikon på minikartan. Set-föremål har grön stråle och Primal röd stråle plus pentagram [10]. Alltså **tre kanaler samtidigt: ljud, vertikal stråle och minikarta**.
- **Förslag till stege** (färg + form + beteende, färgblindsäkert [11][12]):

| Rarity | Färg | Form/ikon (ram) | På marken |
|---|---|---|---|
| Common | grå/vit | ingen ram | ingen stråle, bara etikett |
| Magic | blå | 1 prick | kort, låg glöd |
| Rare | gul | 2 prickar / romb | smal stråle, 2 m |
| Epic | lila | stjärna | stråle + partiklar uppåt |
| Legendary | orange | krona | hög stråle + markring + minikarta |
| Mythic | röd/vit | flamma | pulserande stråle + skärmkant-glöd + stinger |
| Named/Unik | turkos/guld | sköld med sigill | egen animation ("golden moment", se 4) |

- Strålen ska vara en billboard/cylinder-mesh med scrollande gradient och additive blend, inte partiklar. Den ska synas genom dimma (ignorera fog).

### 1.6 Kusligt men 7+-vänligt
- Inget blod, gore eller lemlästning. Död sker som rök, själar och "puff" [rollspec]. PEGI 7 tillåter "icke-realistiskt våld mot fantasyfigurer" och lätt skrämmande scener. (bedömning, verifiera mot PEGI-kriterier i en separat compliance-research)
- **Skräck via stämning, inte chock:** mörker, glödande ögon i buskar, skuggor som rör sig, ljudmattor. Inga jump scares med högt ljud.
- **Söta fiendedesigner med ett "fel":** för många ögon, sydda munnar, lyktor som huvuden. Cult of the Lamb visar att söthet ger utrymme för mörkare teman [3].
- **Ljus = trygghet.** Städer och checkpoints är varma och upplysta, så barnet får en tydlig "säker plats".

---

## 2. Procedurell/scriptad 3D med Blender (bpy)

**Licens:** GPL gäller bara Blender-programmet. Det du skapar (.blend, export, renders) är din egendom [13]. Blender kan köras headless: `blender -b -P build.py -- args`.

### 2.1 Modulära chibi-karaktärer
- **Ett delat skelett** ("chibi_rig"): ~20–25 ben (root, hips, spine, chest, neck, head, 2×(shoulder, upper_arm, forearm, hand), 2×(thigh, shin, foot), weapon_R, offhand_L, hat/fx-socket). Alla humanoider använder samma rig, och **alla animationer delas**. Fiender av andra kroppstyper (fyrbent, flygande, slem) får 3–4 extra riggar.
- **Utbytbara delar** som separata meshes skinnade mot samma rig: huvud, hår/hatt, torso/rustning, händer, ben, vapen. Varje del namnges enligt en konvention (`part_<slot>_<id>`) och exporteras som eget FBX/glTF. Motorn kombinerar och kan slå ihop dem vid runtime (mesh-combine → 1 draw call).
- **Skriptet bygger delarna** av primitiver (UV-sphere, cylinder, skruv, bevel) + modifiers (Mirror, Subdivision nivå 1, Solidify, Bevel, Decimate) och applicerar dem. Därefter tilldelas **vikter automatiskt**: stela delar (hjälm, vapen, rustningsplåt) får 100 % vikt på ett ben (`vertex_groups.new(name=bone).add(...)`, deterministiskt och robust). Mjuka delar använder `parent_set(type='ARMATURE_AUTO')` och sedan en kontroll.
- **Chibi-fördel:** stela "leksaksfigur"-leder (varje kroppsdel följer ett ben) ser bra ut i stilen och eliminerar det svåraste, nämligen skin-weights runt axlar och höfter. (bedömning, stark rekommendation)
- **Animationer via skript:** keyframes på ben (idle-guppning, gång med 4 nycklar, attack-swing, hit-flinch, död-puff) sätts programmatiskt med easing-kurvor. Chibi-animation tål "snappy", få nycklar och överdrivna poser.
- **Variation:** parametrar (huvudstorlek, färgpalett-index, del-ID) ger hundratals fiendevarianter från ett fåtal delar, på samma sätt som ProcGenMod och andra bpy-baserade generatorer gör [14].

### 2.2 Modulärt dungeon-kit
- **Grid:** 2 m eller 4 m moduler med pivot i hörnet och exakta mått (ingen glipa eller överlapp) [15]. Golv och väggar är separata. Korridorer i längderna 1/2/4 och bitar som klarar 90°/180°-rotation [15]. Kenneys Modular Dungeon Kit (CC0) är en bra *referens* för bitlistan [16] (vi producerar själva).
- **Minsta bitlista per värld:** golv (3 varianter), vägg rak/hörn in/hörn ut/dörröppning/fönster, pelare, trappa, kant/klippa, plus props (fackla, tunna, kista, ben-fritt "skräp", svampar, kristaller). Cirka 25–40 bitar.
- **Skin per värld:** samma geometri men olika palett-rad i atlasen och olika props. Det ger billiga nya världar.
- **Kollision:** separata förenklade boxar som exporteras med suffix (`_col`). Navmesh bakas i motorn.

### 2.3 Vad är realistiskt för AI-/skriptproduktion?
| Fungerar bra | Svårt / kräver människa eller iteration |
|---|---|
| Hårda ytor: väggar, props, vapen, rustning, kistor | Organiska ansikten med uttryck (lös det med stiliserade ögon via textur-swap) |
| Chibi-kroppar av primitiver + bevel | Mjuk skinning runt axlar och höfter (undvik via stela delar) |
| Paletter, atlasar, gradient-texturer, decals | Handmålad textur i Don't Starve-kvalitet |
| Enkla nyckel-animationer (idle/gå/slå/dö) | Komplexa bossanimationer och "acting" |
| LOD via Decimate, batch-export, namnkonvention | Estetiskt omdöme: kräver renders och granskning i loop |
- **Arbetsflöde:** skript → automatisk rendering av turntable/siluett i spelkamerans vinkel (PNG) → granskning → justera parametrar. Varje asset har en JSON-spec som källa, så allt blir reproducerbart.

---

## 3. Mobil ARPG UI/UX

### 3.1 Kontrollschema
- **Diablo Immortal:** joystick till vänster, grundattack och skills till höger. Skills auto-siktar mot närmaste fiende, men håll inne för manuell sikt. Vissa skills laddas medan knappen hålls. Knapparnas position kan flyttas i inställningarna [17][18].
- **Archero:** en tumme. Flytande joystick där man trycker. "Stop to shoot, move to evade": stillastående = automatisk attack på närmaste fiende [19]. Maximal enkelhet utan att bli passivt [19].
- **Rekommendation för 7+** (bedömning):
  - Flytande joystick i vänstra halvan (ankras där tummen landar), med fast-läge som alternativ.
  - Grundattack som stor knapp (~80 dp) i högra hörnet, plus **auto-attack-läge** (Archero-stil) för yngsta spelare.
  - 3–4 skill-knappar i en båge runt grundattacken (≥ 56 dp). Tryck = auto-sikt, håll+dra = manuell sikt.
  - Potion/"dodge"-knapp nära tummen. Flyttbar layout.

### 3.2 HUD-layout (landskap)
- **Topp vänster:** porträtt, HP/mana som *kulor eller stora staplar* (Diablo-ikonografi). **Topp höger:** minikarta med loot-ikoner och questmål.
- **Nederkant:** joystick vänster och skills höger. Mitten nederkant är fri (tummar skymmer inte spelaren).
- Spelarfiguren ligger något under skärmens mitt, så man ser mer framåt. Säkra marginaler för notch/rundade hörn.
- Minimal HUD i strid. Menyer bakom en väska-ikon. Quest-tracker kan fällas ihop.

### 3.3 Inventory: grid eller slots
- **Tetris-grid** (Diablo 2) blir för pilligt på touch. **Enhetlig slot-grid** (1 föremål = 1 ruta, stora ikoner) är standard på mobil: Diablo Immortal och Torchlight Infinite. (bedömning baserad på spelen)
- Paperdoll (utrustningsplatser runt figuren) + slot-grid under. **En tryck = detalj, två tryck/knapp = utrusta.**
- **Jämförelse:** på föremålsikonen visas en grön uppåtpil eller röd nedåtpil (samlad "power"). I detaljvyn syns nytt och nuvarande sida vid sida med +/- per stat i färg **och** tecken.
- **Sortera och filtrera** per rarity och typ. **Auto-salvage/auto-sälj** per rarity-nivå. Torchlight Infinite har förinställda loot-filter (basic/intermediate/advanced) [20], men spelare kritiserar filter-UI:t som svårt [20], så vi gör det enklare: 1 reglage "plocka upp från: [rarity]".
- **Varning från Torchlight Infinite:** UI där man måste trycka på allt för att förstå det och scrolla i stora textblock upplevs som tungt [20]. Håll stats kompakta med ikon + siffra.

### 3.4 Crafting- och skill tree-UI
- **Crafting:** mottagarslot i mitten, ingrediens-slots runt, resultatförhandsvisning med rarity-ram och en stor "Smid!"-knapp. Saknade material syns gråade med en ikon som visar var de hittas.
- **Skill tree:** korta grenar (3–5 noder) per skill i stället för ett jättenät. Varje nod har ikon + siffra (t.ex. "🔥 +20 %"). Stora noder (≥ 48 dp), pinch-zoom och fri respec för barn. Förhandsvisa effekten med kort animation/GIF i stället för text. (bedömning)

### 3.5 Tillgänglighet
- **Träffytor:** Material ≥ 48×48 dp (~9 mm), Apple ≥ 44×44 pt [21][22]. Vi siktar på ≥ 56 dp för stridsknappar.
- **Färgblindhet:** rarity och fiendetyp ska aldrig bero enbart på färg. Använd ram-form, symbol och animation [11][12]. Testa paletter mot protanopi, deuteranopi och tritanopi [12].
- **Diablo Immortal** hade vid launch textskala upp till 200 %, text-to-speech för chatt, "World Brightness", ommappning och handkontrollstöd. Färgblind- och högkontrastläge lovades senare [23][24]. Vi har dem från start.
- Övrigt: skärmskak-reglage (0–100 %), vänsterhänt spegling, undertexter och ikon för ljud-cues, låg-rörelse-läge.

### 3.6 UI för yngre spelare (ikon före text)
- Varje knapp har en ikon först. Text är sekundär (kort, stor, ≥ 16 sp).
- Siffror framför ord ("+12 ⚔" i stället för "Increases attack damage by 12").
- Färg + form + ljud för varje status. Pulserande utropstecken leder till nästa steg (tutorial genom att visa, inte berätta).
- Få menynivåer (max 2 steg till allt). "Tillbaka" alltid på samma plats. Ingen tidspress i menyer.
- Inga dark patterns (7+ och butiksregler): ingen FOMO-timer, inga förvirrande valutor. (bedömning, stäm av med monetiseringsresearch)

---

## 4. Game feel och juice
Kanoniska källor: "Juice It or Lose It" (Jonasson & Purho, 2012) [25] och "The Art of Screenshake" (Nijman/Vlambeer, 2013) [26].

- **Hitstop:** frys attackerare och mål 40–80 ms på träff (60–80 ms för tunga/kritiska slag, 0–30 ms för snabba multi-hits) [27]. Pausa inte hela spelet vid AoE-träffar på många fiender. Skala med antalet.
- **Screen shake:** 3 nivåer (liten/rutin, medel, stor/boss). Rotation smyger in vid större impulser [27]. Använd trauma-baserat brus (Perlin), inte slump per frame. Riktat i träffens riktning. **Reglage för att stänga av.**
- **Hit flash:** vit blixt på fienden i 1–2 frames plus en liten knockback och squash. Det är det billigaste och viktigaste.
- **Skadesiffror:** stora och korta (1 decimal/K-format: 1,2K). Poppa med overshoot-skala och flyt uppåt. Crit = större, gul/orange, med ikon. Samla multi-hits till en växande siffra för att undvika spam. Alternativ: "bara crits" för små skärmar.
- **Loot-explosion:** föremål sprutar i båge (fysik-ish parabel med studs). Guld/valuta magnetiseras till spelaren efter 0,3 s. Kisten skakar och "andas in" innan den öppnas (anticipation).
- **Golden moment** (Legendary+): 1) kort slow-mo (0,3–0,5 s vid 30 % hastighet), 2) musiken duckas, 3) stråle skjuter upp med ljud-stinger, 4) kant-glöd i rarity-färg, 5) vid upplockning ett **helskärmskort** för Mythic/Named: föremålet roterar, namnet dyker upp, konfetti/gnistor och en stor "Utrusta"-knapp. Det ska aldrig blockera i strid: köa kortet tills striden är slut. (bedömning, byggt på D3-mönstret [10])
- **Allt ska fungera utan ljud** (rollspec): varje ljud-cue har visuell motsvarighet.

---

## 5. Ljud

### 5.1 Rarity-ljudstege
Stigande i tonhöjd, lager och längd, med samma tonart (t.ex. D-dur) så det låter som en familj (bedömning):
| Rarity | Ljud |
|---|---|
| Common | kort "tick/klirr", 1 lager, 80 ms |
| Magic | klirr + mjuk klocka, kvint |
| Rare | 2-tons arpeggio upp, lätt glitter |
| Epic | 3-tons dur-arpeggio, reverb-svans |
| Legendary | tung "clang" (D3-referens [10]) + kör-pad + uppåtsvep |
| Mythic | Legendary + sub-bas-dunk + unik 4–6-tons stinger |
| Named | egen ledmotivsfras per föremål (1–2 s) |
Spara pickup-ljud separat från drop-ljud. Drop-ljudet ska höras över stridsmixen (sidechain/duck).

### 5.2 SFX-behov (första lista)
- **Strid:** svischar (lätt/tung), träff (kött-fritt: "thud", "bonk", "crack"), crit, block, miss/dodge, skill-casts per element (eld, is, gift, skugga, ljus), projektiler (loop + träff), fiende-"puff"-död, själ-pickup.
- **Loot/ekonomi:** drop per rarity, pickup, guld (per mängd), kista-öppning, salvage, craft-lyckat/-misslyckat, level up.
- **UI:** tap, tillbaka, flikbyte, utrusta, felmeddelande, notis, köp.
- **Värld:** fotsteg per underlag, dörr, fälla, facklor, ambiens-loopar (vind, droppar, kråkor, viskningar).
- **Mix för mobilhögtalare:** mycket bas försvinner, så lägg energin i 200 Hz–5 kHz och lägg till övertoner på bas-ljud. Loudness runt −16 LUFS. (bedömning, vanlig mobilpraxis)

### 5.3 Verktyg för procedurellt och syntetiserat ljud
| Verktyg | Licens (programmet) | Användning | Källa |
|---|---|---|---|
| **sfxr** (DrPetter) | MIT (open source) | original-generatorn: parametrar + slump | [28] |
| **jsfxr** (chr15m) | **Unlicense** (public domain). Finns som npm-paket, så ljud kan **genereras i kod/CI** | UI-/loot-/retro-SFX | [29][30] |
| **jfxr** (ttencate) | open source. Ljud du skapar är "entirely yours", även kommersiellt, utan attribution | modernare sfxr, fler vågformer | [31] |
| **Bfxr** (increpare) | Apache 2.0 | sfxr + mixer + fler filter | [32] |
| **ChipTone** (SFB Games) | gratis, proprietär/stängd källkod | snabb skissning. Kontrollera villkoren innan släpp | [28] |
| **SuperCollider** | GPL-3.0 | kraftfull syntes/offline-rendering av WAV | [33][34] |
| **Csound** | LGPL-2.1 | offline-rendering, kan även bäddas in | [33][35] |

- **Licensprincip:** GPL/LGPL gäller *programmet*, inte ljudfilerna man renderar (samma princip som Blender [13]). Att **rendera till WAV/OGG offline** med SuperCollider eller Csound är därför oproblematiskt. **Bädda inte in** SuperCollider (GPL) i spelet. Csound (LGPL) går att länka dynamiskt men är onödigt. (bedömning, inte juridisk rådgivning)
- **Pipeline:** parameterfiler (JSON) i `arpg/audio/src/`, ett skript renderar (jsfxr via Node, eller sclang/csound offline) → normalisering/limiter (sox/ffmpeg) → OGG i `arpg/audio/build/`. Slump-seed sparas så att allt är reproducerbart. Stadig 8-bit-känsla undviks genom att lagra: sfxr-transient + filtrerat brus + reverb.
- **Musik:** skrivs som kod/MIDI → Csound/SuperCollider-instrument, eller tracker (t.ex. MilkyTracker/Furnace, open source) + egna samplade syntljud. Loopbar struktur med stems (utforskning / strid / boss) för vertikal lagring i motorn.

### 5.4 Musik per värld (förslag)
| Värld (exempel) | Ton | Instrument |
|---|---|---|
| Kyrkogård/by | melankoliskt vals-3/4, Burton-känsla | celesta, musiklåda, stråkpizzicato, kör "ooh" |
| Svampskog | nyfiket och lurigt | marimba, basklarinett, glasklockor |
| Frusna kryptor | ödsligt | pads, klockor, vindbrus |
| Brinnande underjord | drivande | lågt trumkit, orgel, brass-stötar |
| Boss | fas 1 → fas 2 lägger till lager | samma tema, ökat tempo och slagverk |
Städer och safe zones har varm och enkel melodi (trygghet för yngre spelare). Strid lägger på slagverk ovanpå utforskningsloopen i stället för att byta låt.

---

## 6. Rekommendationer i korthet
1. Gradient-atlas + toon-ramp + rim som baslook. Inverted-hull-outline bara på aktörer och loot.
2. Stela "leksaks"-chibis på ett delat skelett, genererade med bpy från JSON-specar, med auto-renderade siluettester.
3. Modulärt 2 m-kit, en geometri och en palett-rad per värld.
4. Flytande joystick + stor attackknapp + 3–4 skills i båge. Auto-attack-läge och flyttbar layout.
5. Slot-grid-inventory med grön/röd pil, auto-salvage per rarity och ikon före text överallt.
6. Rarity = färg + ramform + stråle + ljud. Golden moment köas till efter strid.
7. Ljud genereras i kod (jsfxr/Unlicense + offline-render i Csound/SC). Musik med stems per värld.

---

## Källor
1. Game Developer, "Don't Starve: A Tim Burton take on Minecraft": https://www.gamedeveloper.com/design/-i-don-t-starve-i-a-tim-burton-take-on-i-minecraft-i-
2. Wikipedia, Don't Starve: https://en.wikipedia.org/wiki/Don%27t_Starve
3. Game Developer, intervju Cult of the Lamb: https://www.gamedeveloper.com/design/interview-corralling-the-inherent-cuteness-of-cult-of-the-lamb
4. Inverse, Cult of the Lamb art director: https://www.inverse.com/gaming/cult-of-the-lamb-concept-art-interview-massive-monster/amp
5. The Gemsbok, Death's Door art: https://thegemsbok.com/art-reviews-and-articles/deaths-door-acid-nerve-review-pros-cons/
6. MCV/Develop, Behind the art of Hades: https://mcvuk.com/business-news/behind-the-art-of-hades-we-value-artistic-integrity-and-excellence-in-artistic-craft-at-supergiant-however-were-first-and-foremost-a-game-design-lead-team/
7. Delt06/urp-toon-shader: https://github.com/Delt06/urp-toon-shader
8. Bill the Dev, Toon shading in URP: https://www.billthedev.com/lab/toon-shading-unity-urp/
9. Unity Toon Shader, Rim Light: https://docs.unity3d.com/Packages/com.unity.toonshader@0.8/manual/Rimlight.html
10. Diablo Wiki, Legendary: https://www.diablowiki.net/Legendary
11. Can I Play That?, Color-blindness guide: https://caniplaythat.com/2020/01/29/color-blindness-accessibility-guide/
12. Nasty Rodent, Accessibility in game design: https://nastyrodent.com/accessibility-in-game-design/
13. Blender, License: https://www.blender.org/about/license/
14. ProcGenMod (bpy-noder): https://github.com/ValentinBuira/ProcGenMod
15. Roll20-forum, modular asset best practices: https://app.roll20.net/forum/post/7187625/best-practices-for-creating-modular-assets-like-dungeon-tiles
16. Kenney Modular Dungeon Kit (CC0): https://kenney.nl/assets/modular-dungeon-kit
17. Den of Geek, Diablo Immortal controls: https://www.denofgeek.com/games/diablo-immortal-control-options-supported-controllers-mouse-keyboard/
18. Fextralife, Diablo Immortal Controls: https://diabloimmortal.wiki.fextralife.com/Controls
19. Deconstructor of Fun, Archero: https://www.deconstructoroffun.com/blog/2019/8/9/why-archero-banked-25m-but-leaves-25m-hanging-hlx9n
20. Torchlight Infinite loot filter (tlidb + Steam-diskussion): https://tlidb.com/en/Filter , https://steamcommunity.com/app/1974050/discussions/0/3770110614219229302/
21. Material Design 3, Accessibility: https://m3.material.io/foundations/designing/structure
22. LogRocket, touch target sizes: https://blog.logrocket.com/ux-design/all-accessible-touch-target-sizes/
23. Blizzard, Diablo Immortal accessibility: https://news.blizzard.com/en-us/diablo-immortal/23805083/making-a-game-for-everyone-diablo-immortal-s-accessibility-features
24. Can I Play That?, Diablo Immortal: https://caniplaythat.com/2022/06/01/diablo-immortal-will-launch-with-a-number-of-accessibility-features-with-more-to-come/
25. GDC Vault, Juice It or Lose It: https://www.gdcvault.com/play/1016487/juice-it-or-lose
26. Vlambeer, The Art of Screenshake (video): https://www.youtube.com/watch?v=AJdEqssNZ-U
27. Game feel on the web (hitstop/shake-värden): https://valdemird.com/blog/game-feel-on-the-web/
28. Game Making Tools Wiki, sfxr: https://www.gamemaking.tools/wiki/index.php/sfxr
29. jsfxr: https://github.com/chr15m/jsfxr
30. jsfxr på npm: https://www.npmjs.com/package/jsfxr
31. jfxr: https://github.com/ttencate/jfxr
32. Bfxr: https://github.com/increpare/bfxr
33. Wikipedia, Comparison of free software for audio: https://en.wikipedia.org/wiki/Comparison_of_free_software_for_audio
34. SuperCollider Licensing: https://doc.sccode.org/Other/Licensing.html
35. Cabbage-forum, Csound license: https://forum.cabbageaudio.com/t/cabbage-csound-license-for-commercial-projects/724

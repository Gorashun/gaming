# UI_GUIDE.md – PIPWRECK

*Version 2 · 2026-09-21 · Ägare: UI/UX · Status: **riktning A beslutad. Hybrid pixel + krita beslutad av Anders (DECISIONS 2026-09-21)***

Gäller för Godot 4.6, portrait 1080×1920 (≈ 360×640 dp referens, testas även 430×932 dp).
Allt UI läser en händelselogg från `src/core/` och spelar upp den. **UI-lagret innehåller ingen spellogik.**

---

## 1. Tre visuella riktningar

Alla tre är byggda av Godot-primitiver (`Polygon2D`, `Line2D`, `NinePatchRect`, `GPUParticles2D`) plus max **en** delad shader. Ingen av dem kräver en grafiker, ingen av dem använder hjul, spakar, jetonger eller "777" (se PROPOSAL §4.6, åldersklassning).

### A. KRITGROPEN — krita på skiffer *(rekommenderad)*

Skärmen är en mörk skifferplatta. Allt spelrelevant är ritat i varm, sliten krita: slotsen är kritrutor med handdragna kanter, kedjepilarna ritas ut i realtid som om någon streckar dem med kritan, och rundans resultat skrivs in som tally-streck i kanten. Tärningarna är de enda "fysiska" objekten – benvita, lätt varma kuber med djupt inskurna ögon – vilket gör att blicken alltid dras till dem. Fiender är kritsilhuetter: en hukande kontur, ett par vita ögonprickar, ingen inre detalj. Siffror är enorma, ultrakondenserade och kritvita, med ett halo av kritdamm som puffar ut vid varje träff.

Riktningen är genomförbar för att hela "handgjorda" intrycket sitter i **en** shader (`chalk.gdshader`: UV-jitter via noise ger skakiga kanter, grain-multiply ger korn, alpha-erosion ger uppbruten täckning). Allt annat är rena polygoner och linjer som shadern gör levande. Kritdamm är en enda partikelmaterial-resurs som återanvänds i olika färger.

**Varför inte generisk:** den vanligaste "AI-looken" är mörkblå gradient + glow + glassmorphism. Kritgropen har noll gradienter, noll glow och medvetna oregelbundenheter. Den läser också perfekt i solljus: nära-vitt på nära-svart ger 14:1.

Palett: `#0E1216` skiffer · `#F2EDE3` krita · `#E8E0CF` ben · `#FF6A2C` eld · `#FFD447` laddning · `#6ED2F5` frost · `#B77FFF` gift.
Typografi: **Familjen Grotesk** (UI), **Anton** (siffror/multiplikatorer), **Caveat Brush** (endast kritklotter, max 3 ord).

### B. RISOTRYCK — risograf-zine på papper

Varmt gråvitt papper (`#F4EFE4`) med två fluorescerande spot-färger (`#FF4E1A` och `#0E6FD1`) plus svart. Allt är platta ytor med synligt halvtonsraster, och lagren ligger någon pixel fel i förhållande till varandra – den karaktäristiska riso-felpassningen. Tärningar är plana orange fyrkanter med utstansade vita ögon; slots är svarta konturramar med ikoner i knockout; fiender är feta, ojämna bläckblobbar. Siffror är gigantiska och trycks i fluorescerande orange rakt över allt annat.

Genomförbart med en halvtons-shader (screen-space punktraster) och en offset på två CanvasLayers. Maximalt distinkt och omöjligt att förväxla med något annat mobilspel. **Risker:** ljus bakgrund är rätt i solljus men dyrare på OLED, den semantiska färgrymden krymper till tre bläck (svårt att koda åtta statuseffekter), och genren förväntar sig mörkt. Rekommenderas som **temalåsning i menyn**, inte som bas.

Typografi: **Archivo Black** (allt), **Space Mono** (siffror).

### C. VRAKSTÅL — industriskylt i lastrummet

Vraket i PIPWRECK, bokstavligt: mörka stålplåtar med nitrader, varningsrandiga kanter i `#F2B01E`, stencilade etiketter och oxidfläckar. Tärningar är frästa metallkuber där ögonen är borrade hål som tänds i slotens färg. Amboss-, Eld- och Ladda-slotsen blir maskindelar med glödande innerkant, och gnistpartiklar faller genom hela skärmen. Fiender är rostiga siluetter med en enda lysande detalj.

Genomförbart med gradienter, nitar som cirklar och en grain/rost-overlay; inga ritade assets. Varningsgult på mörkt stål är en palett som bokstavligen är konstruerad för dålig belysning. **Risk:** detta är den riktning som ligger närmast "generisk mörk sci-fi-UI med orange accent" – exakt den AI-look briefen vill undvika – och glödeffekter tvingar bloom/HDR som kostar på svaga Android-telefoner.

Typografi: **Oswald** / **Saira Condensed** (UI), **Bebas Neue** (siffror).

### Rekommendation

**Kör A – KRITGROPEN.** Skäl, i prioritetsordning:

1. **Högst kontrast av de tre** utan att offra karaktär (14,8:1 för primärtext mot panelbotten; alla semantiska färger ≥ 4,9:1).
2. **Kedjan är premissen och kritan är kedjans naturliga språk.** Att streck ritas ut vänster→höger i realtid är designprincip 2 (synlig kausalitet) uttryckt visuellt, inte pålagt ovanpå.
3. **Billigast att göra unik:** en shader bär hela identiteten. B behöver två shaders + reprofix, C behöver gradient-, glow- och bloompipeline.
4. **Håller 13+ med marginal.** Krita och skiffer läser som gatuspel/anteckningsbok, inte kasino. Ingen guldglans, inga jetonger.
5. **Semantisk färgrymd finns kvar.** Färgad krita ger åtta distinkta statusfärger som alla klarar kontrastkravet mot mörk botten – det klarar inte B.

B sparas som upplåsningsbart "Zine-tema" i Kodex (billig horisontell meta). C avfärdas.

### Beslut 2026-09-21: hybriden

Anders har beslutat att **karaktärer, monster och tärningar ritas som
pixelgrafik med paperdoll-lager** så att reliker och utrustning syns på
figuren, medan **krit-UI:t (riktning A) behålls för UI, siffror och
kedjeeffekter**. Navigeringen presenteras som en **sidoscrollande marsch** där
figuren går åt höger.

Riktning A är alltså inte ersatt – den har fått en värld under sig. Kritan är
fortfarande den som *pratar* (kausalitet, siffror, val); pixlarna är det som
*finns* (kropp, utrustning, fiender, tärningar). Var gränsen går står i §8.

---

## 2. Designtokens (KRITGROPEN)

### 2.1 Färg – yta

| Token | Hex | Användning |
|---|---|---|
| `surface/pit` | `#0E1216` | Skärmbotten, bakom allt |
| `surface/slate` | `#161B21` | Paneler, fiendezon |
| `surface/raised` | `#1F262E` | Slot-botten, kort, tumzonbricka |
| `surface/line` | `#2C353F` | Avdelare, inaktiv kontur |
| `surface/scrim` | `#0E1216` @ 72 % | Modal-bakgrund |

### 2.2 Färg – krita och tärning

| Token | Hex | Kontrast mot `raised` | Användning |
|---|---|---|---|
| `chalk/100` | `#F2EDE3` | 13,1:1 | Primärtext, siffror, aktiv kontur |
| `chalk/300` | `#CFC7B8` | 9,1:1 | Sekundärtext, etiketter |
| `chalk/500` | `#9A9486` | 5,1:1 | Hint, inaktiv text (aldrig spelkritiskt) |
| `bone/die` | `#E8E0CF` | 11,6:1 | Tärningskropp |
| `bone/pip` | `#12161A` | 13,8:1 mot `bone/die` | Tärningsögon |

### 2.3 Färg – semantisk

Varje semantisk färg har **alltid** en formkod bredvid sig (ikon eller ram). Färg är aldrig ensam bärare.

| Token | Hex | Form/glyf | Kontrast mot `raised` |
|---|---|---|---|
| `sem/damage` | `#F2EDE3` | ✦ fyrkantig stjärna | 13,1:1 |
| `sem/fire` | `#FF6A2C` | ▲ triangel | 5,4:1 |
| `sem/poison` | `#B77FFF` | ⬬ droppe | 5,5:1 |
| `sem/frost` | `#6ED2F5` | ❖ romb | 8,9:1 |
| `sem/heal` | `#4FE3A0` | ✚ kors | 9,3:1 |
| `sem/blood` | `#FF556F` | ◖ halvcirkel | 4,9:1 |
| `sem/charge` | `#FFD447` | ⬤ fylld cirkel | 10,7:1 |
| `sem/shield` | `#D7DEE6` | ⬟ sköldfemhörning | 11,3:1 |

### 2.4 Slot-typer: FORM först, färg sedan

**Normativ regel:** slot-typerna skiljs på **form**. Färgen är en genväg för
den som ser den, aldrig den enda bäraren (§6.2). Ikonerna ligger i
`assets/sprites/ui/slot_<typ>.png`, 16×16 px, genererade av
`tools/gen_pixel_assets.py`.

| Slot | `Rules.SlotType` | Form (16×16-ikon) | Ram | Färg |
|---|---|---|---|---|
| Vanlig | `PLAIN` | **Kvadrat**, fylld, liten och centrerad | Tunn (1,5 dp) | `#CFC7B8` |
| Eld | `FIRE` | **Triangel**, fylld, spets uppåt | **Heldragen** | `#FF6A2C` |
| Spegel | `MIRROR` | **Romb delad i två** av en vertikal springa | **Dubbel** | `#6ED2F5` |
| Amboss | `ANVIL` | **Femhörning**, spetsigt tak över raka sidor | **Tjock (4 dp)** | `#D7DEE6` |
| Ladda | `CHARGE` | **Cirkel**, fylld | **Prickad** | `#FFD447` |
| Tomrum | `VOID` | **Ring**, tunn och ihålig | **Streckad** | `#8A94A6` |

Två par delar familj med flit (kvadrat/femhörning, cirkel/ring), men skiljs på
en egenskap som överlever 16 px: **en spets** respektive **ett hål**.

**Mätt distinkthet.** Varje ikon fylldes svart och jämfördes parvis som
silhuett (IoU, 1,00 = identiska former). Sämsta par: `ANVIL`/`CHARGE` **0,78**
(femhörning mot cirkel – skiljs på hörn och spets). Alla par med `VOID` ligger
på 0,25–0,60, alla par med `FIRE` på 0,25–0,76. Gränsen är **0,85**; hamnar ett
nytt par över den ska formen ritas om, inte färgen.

Ramstilen är en tredje, redundant kodning: en spelare med total färgblindhet
kan skilja alla sex slots på enbart ikonform, och alla sex på enbart ramstil.

### 2.5 Färg – sällsynthet och multiplikator

| Sällsynthet | Färg | Ramform | Alltid textad |
|---|---|---|---|
| Vanlig | `#CFC7B8` | Rak ram | "VANLIG" |
| Ovanlig | `#4FE3A0` | Kapade hörn | "OVANLIG" |
| Sällsynt | `#6ED2F5` | Dubbel ram | "SÄLLSYNT" |
| Mytisk | `#FF5CA8` | Sprucken/taggig ram | "MYTISK" |
| Jackpot | `#FFD447` | Strålram + shimmer | "JACKPOT" |

| Multiplikator | Färg | Notering |
|---|---|---|
| ×2 | `#FFD447` | Badge, 24 dp |
| ×4 | `#FF8A2C` | Badge, 28 dp |
| ×8 | `#FF556F` | Badge, 34 dp + skak |
| ×16 och uppåt | `#FF5CA8` | Badge, 40 dp, bryter slot-rutan |
| ×32+ | Animerad gradient över alla fyra | Siffran får medvetet inte plats (moment 4) |

### 2.6 Spacing (bas 4 dp)

`space/1` 4 · `space/2` 8 · `space/3` 12 · `space/4` 16 · `space/6` 24 · `space/8` 32 · `space/12` 48 · `space/16` 64

Skärmmarginal 16 dp (liten skärm) / 20 dp (stor). Vertikalt gap mellan zoner: 24 dp.

### 2.7 Radier och linjer

| Token | Värde |
|---|---|
| `radius/none` | 0 (kritstreck, avdelare) |
| `radius/chip` | 4 (badges, taggar) |
| `radius/button` | 8 |
| `radius/die` | 14 (på 64 dp tärning ≈ 22 %) |
| `radius/card` | 20 (belöningskort) |
| `radius/pill` | 999 |
| `stroke/hair` | 1,5 dp |
| `stroke/reg` | 2 dp |
| `stroke/bold` | 3 dp |
| `stroke/heavy` | 4 dp |

Ingen drop-shadow i denna riktning. Djup skapas av **kritdammshalo** (`chalk/100` @ 12 %, radie 8 dp) och av linjetjocklek.

### 2.8 Typografi

| Token | Font | dp | Vikt | Användning |
|---|---|---|---|---|
| `type/display-xl` | Anton | 56 | 400 | Kedjans totalsiffra, number pop |
| `type/display-l` | Anton | 40 | 400 | Skärmrubrik, bossnamn |
| `type/title` | Familjen Grotesk | 28 | 700 | Sektionsrubrik |
| `type/heading` | Familjen Grotesk | 22 | 700 | Kortrubrik, knapptext primär |
| `type/body-l` | Familjen Grotesk | 18 | 500 | Regeltext på kort |
| `type/body` | Familjen Grotesk | 16 | 400 | Brödtext |
| `type/label` | Familjen Grotesk | 14 | 700 | Etiketter, HP-siffror, versaler |
| `type/caption` | Familjen Grotesk | 12 | 500 | Minsta tillåtna. Aldrig spelkritisk info |
| `type/scrawl` | Caveat Brush | 20–32 | 400 | Kritklotter, max 3 ord |

Radavstånd 1,3× för brödtext, 1,0× för Anton. Teckenstorlek skalbar 85/100/115/130 % (se §6).

### 2.9 Touch targets och tumzon

| Element | Storlek |
|---|---|
| Minsta träffyta (alla) | **48 × 48 dp** |
| Tärning i bricka | 64 × 64 dp visuellt, 72 × 72 dp träffyta |
| Slot | 64 × 76 dp visuellt, 72 × 84 dp träffyta |
| Primärknapp (Bekräfta) | full bredd − 2×16 dp, **56 dp hög** |
| Sekundärknapp (Omkast, Ångra) | 96 × 48 dp |
| Ikonknapp (meny, info) | 48 × 48 dp |
| Avstånd mellan träffytor | ≥ 8 dp |

**Tumzonsregel:** allt interaktivt ligger under 58 % av skärmhöjden. Fiendezonen överst är läs-endast (tapp på fiende öppnar infopanel, men inget spelbeslut sitter där). Bekräfta-knappen sitter 24 dp ovanför safe area-botten.

### 2.10 Rörelse

| Token | ms | Easing |
|---|---|---|
| `motion/snap` | 90 | `ease_out_quad` |
| `motion/quick` | 140 | `ease_out_cubic` |
| `motion/base` | 220 | `ease_out_cubic` |
| `motion/chain-step` | 260 | se §5 |
| `motion/celebrate` | 520 | `ease_out_back` |
| `motion/panel` | 300 | `ease_in_out_cubic` |

Global tempomultiplikator `chain_speed`: Lugn 1,25× · Normal 1,0× · Snabb 0,6× · Blixt 0,35×.

### 2.11 Tema **Hög kontrast+** (inställning, `high_contrast`)

En **token-override**, inte ett andra tema: samma tokennamn, andra värden.
UI-koden slår upp tokens via `Tokens`, så läget är ett byte av tabell och
noll ändringar i skärmarna. Alla värden mätta mot sin bakgrund.

| Token | Standard | Hög kontrast+ | Kontrast mot `surface/pit` |
|---|---|---|---|
| `surface/pit` | `#0E1216` | **`#000000`** | – |
| `surface/slate` | `#161B21` | **`#000000`** | – |
| `surface/raised` | `#1F262E` | **`#0A0A0A`** | – |
| `surface/line` | `#2C353F` | **`#808C99`** | 6,1:1 |
| `chalk/100` | `#F2EDE3` | **`#FFFFFF`** | 21,0:1 |
| `chalk/300` | `#CFC7B8` | **`#EDEDED`** | 17,9:1 |
| `chalk/500` | `#9A9486` | **`#B9B9B9`** | 10,7:1 |
| `bone/die` | `#E8E0CF` | **`#FFFFFF`** | 21,0:1 |
| `bone/pip` | `#12161A` | **`#000000`** | – (mot `bone/die`: 21,0:1) |
| `sem/damage` | `#F2EDE3` | **`#FFFFFF`** | 21,0:1 |
| `sem/fire` | `#FF6A2C` | **`#FF8A3D`** | 9,0:1 |
| `sem/poison` | `#B77FFF` | **`#C99CFF`** | 9,7:1 |
| `sem/frost` | `#6ED2F5` | **`#8FE4FF`** | 14,7:1 |
| `sem/heal` | `#4FE3A0` | **`#6BF7B8`** | 15,6:1 |
| `sem/blood` | `#FF556F` | **`#FF7D90`** | 8,6:1 |
| `sem/charge` | `#FFD447` | **`#FFE270`** | 16,4:1 |
| `sem/shield` | `#D7DEE6` | **`#E9EEF4`** | 18,0:1 |

Utöver färgtabellen gäller i läget:

* Alla ramar går upp till `stroke/bold` (3 dp), slot-ramarna till
  `stroke/heavy` (4 dp).
* Kritdammshalon stängs av (den sänker kontrasten mot en helsvart botten).
* `chalk.gdshader` körs med `erosion = 0.10` och `grain_amount = 0.12`:
  handkänslan finns kvar men strecket blir täckande.
* World-lagret körs genom `lut_world.png` med `luma_gamma = 1.35`, vilket
  separerar silhuett från botten utan att rita om en enda sprite (§8.5).
* **Minsta kontrast i läget: 6,1:1** (`surface/line`). Standardtemats
  minimum är 4,9:1.

`high_contrast` och `reduced_motion` är oberoende inställningar och kan vara
på samtidigt.

---

## 3. Skärmflöde

```
Titel → Klassval → [ Strid → Belöningsval → (Smedja) → Karta ]×12 → Död/Vinst → Meta/Kodex → Titel
```

| Skärm | Syfte | Primär handling |
|---|---|---|
| **Titel** | Kom in i en run på ett tryck; visa om en run pågår | "FORTSÄTT" eller "NY RUN" – en 56 dp knapp i tumzonen |
| **Klassval** | Välj spelstil, inte statvärde; visa klassens tärningar direkt | Svep mellan 3 klasskort, tryck "VÄLJ" |
| **Strid** | Spelets hjärta: rulla, placera, bekräfta, se kedjan | Dra tärningar till slots, tryck "BEKRÄFTA KEDJA" |
| **Belöningsval** | Ett val var 60–90 s, alltid 3 alternativ, minst ett spännande | Tryck ett av tre kort, sedan "TA" |
| **Smedja** | Gör tärningen till din build: smid om en enskild sida | Välj tärning → välj sida → välj ny sida → "SMID" |
| **Karta / nästa rum** | Visa känd slutpunkt och nästa risknivå | Tryck en av 2–3 vägnoder |
| **Död / Vinst** | Stäng loopen ärligt: visa vad som dödade dig och vad du låste upp | "KODEX" eller "EN RUN TILL" (primär, tumzonen) |
| **Meta / Kodex** | Horisontell progression: sedda kedjor, rekord, upplåsningar | Bläddra i kategorier, tryck en post för detalj |

Övergångar: kritsvep (squeegee-wipe vänster→höger) mellan skärmar, 300 ms. Modaler glider upp från botten, 300 ms.

---

## 4. Interaktion: placering av tärningar

**Grundlöfte (helig regel 5):** kedjan är fullt förhandsvisad innan bekräftelse. Ingen dold slump i utfallet.

### 4.1 Drag (primär metod)
1. Tryck på tärning → den lyfter (skala 1,12, kritdammshalo, haptik **light**, 90 ms).
2. Giltiga slots pulserar sin kontur (2 dp → 3,5 dp, 700 ms loop). Ogiltiga dimmas till 35 %.
3. Tärningen följer fingret med 4 dp offset uppåt så fingret inte täcker den.
4. Släpp inom 40 dp från en slot → snap (140 ms, `ease_out_back`), haptik **light**.
5. Släpp utanför → återgång till brickan, 140 ms.

### 4.2 Tapp-tapp (likvärdigt alternativ, alltid aktivt)
- Tapp på tärning → markerad (kritring + lyft). Tapp på slot → placerad.
- Tapp på markerad tärning igen → avmarkerad.
- Tapp på upptagen slot med markerad tärning → byter plats (swap), inte fel.
- **Aldrig dubbeltapp-krav någonstans.** (Känd klagomålstyp, research 03 §5.4.)

### 4.3 Ångra
- `ÅNGRA` (48 dp) ångrar senaste placeringen. Obegränsad historik inom rundan.
- Långtryck 350 ms på placerad tärning → plockas tillbaka till brickan.
- `RENSA` (i overflow-menyn) tömmer brädet.
- Allt är fritt fram till `BEKRÄFTA KEDJA`. Efter bekräftelse går det inte att ångra – därför är förhandsvisningen obligatorisk och exakt.

### 4.4 Live-förhandsvisning
- Under slots-raden ritas kedjepilar i krita mellan fyllda slots, vänster→höger.
- Multiplikator-braces (`⌣` under två/tre grannar) dyker upp så snart en kombination skulle bildas.
- Totalen uppdateras vid varje placering med 120 ms sifferrullning.
- Totalen är uppdelad per mål: `34 → RÅTTA · 14 → VAKT (överflöd)`. Överflöd markeras med `sem/fire`-orange pil.
- Tomma slots visar sin egenskap i grått så spelaren kan planera framåt.

### 4.5 Omkast
- `OMKAST 2/2` som sekundärknapp till vänster om Bekräfta.
- Tapp på tärning i brickan **medan omkast är valt** låser/låser upp den (kritlås-ikon). Låsta tärningar kastas inte om.
- Placerade tärningar kan inte kastas om (de är åtagna). Plocka tillbaka dem först.

### 4.6 Bekräfta
- 56 dp hög, full bredd, botten. Text: `BEKRÄFTA KEDJA · 48`.
- Inaktiv (35 % opacitet, ej tryckbar) med texten `PLACERA MINST EN TÄRNING`.
- Ingen bekräftelsedialog. Ett tryck = ett beslut (designprincip 5).

---

## 5. Feedback-spec ("juice")

> **Ljudfilerna finns.** Varje cue nedan är levererad i `assets/sfx/`
> (17 st, `own-work`, genererade av `tools/gen_sfx.py`). Event → fil →
> mix-dB → pitch-regel står i `assets/sfx/README.md`.
> **Den exakta tidslinjen för en hel runda ligger i §12** – §5 är *vad* varje
> event gör, §12 är *när*.

Tidsbudget: en kedja på 6 tärningar utan kombinationer = **6 × 260 ms ≈ 1,56 s**. Med två kombinationer och en död fiende ≈ **2,3 s**. Tak: **2,5 s**. Allt däröver komprimeras automatiskt (se §5.9).

**Global tonhöjdsregel:**
`pitch_scale = pow(2.0, (step_index + combo_bonus) / 12.0)`
där `step_index` = 0…5 (nollställs varje runda) och `combo_bonus` = 0 / 2 / 4 / 7 för ingen / ×2 / ×4 / ×8. Tak 2,0 (en oktav). Varje kedjesteg är alltså **+1 halvton**, varje kombination hoppar extra.

### 5.1 `die_activated` — 220 ms
- **Visuellt:** tärningen skalar 1,00 → 1,18 → 1,00 (120 / 100 ms, `ease_out_back`). Kritring expanderar från tärningen, radie 32 → 72 dp, alpha 1 → 0 (200 ms). Slotens underline ritas vänster→höger i slotens färg (140 ms). 6–10 kritdammspartiklar uppåt, gravitation −40. Ingen hit-stop.
- **Ljud:** torr träklubba/kritknack, 45 ms, ingen svans. Pitch enligt global regel.
- **Haptik:** `light` (10 ms).

### 5.2 `combo_formed` — 300 / 340 / 420 ms (×2 / ×4 / ×8)
- **Visuellt:** deltagande tärningar dras ihop 4 dp mot varandra (90 ms). Kritklammer ritas under dem (140 ms). Multiplikator-badge poppar 0,40 → 1,25 → 1,00 med rotation −6° → 0°. Kamerans zoom-punch 1,00 → 1,03 / 1,04 / 1,05 → 1,00. Skärmskak amplitud **2 / 4 / 7 dp**, 3 cykler. Partiklar **12 / 24 / 40**. Hit-stop **40 / 70 / 110 ms**.
- **×16 och uppåt:** badgen bryter slot-rutan, kritdamm faller över hela brädet, hit-stop 150 ms, texten får `type/display-xl`.
- **Ljud:** stigande arpeggio, **2 / 3 / 4** toner i dur-pentatonisk skala, grundton enligt global regel. ×8 lägger på ett sub-bas-slag (55 Hz, 180 ms) och en kort kritskrik-layer. ×16+ lägger på en körsvällning.
- **Haptik:** `light` / `medium` / `heavy`. ×8 som mönster 20–40–20 ms. ×16+: 20–40–20–60 ms.

### 5.3 `damage_dealt` (med överflöd) — 260 ms + 180 ms per överflödshopp
- **Visuellt:** number pop i `type/display-xl` (Anton) spawnar på målet, stiger 24 dp, skala 0,60 → 1,30 → 1,00, fade ut över 260 ms. Målet vitblixtrar 60 ms och skakar horisontellt 6 dp × 3 cykler. HP-baren dränerar med 120 ms fördröjning och lämnar ett "spökspår" i `sem/blood` som visar vad som togs bort (försvinner efter 400 ms).
- **Överflöd:** kritpil ritas från det döda målet till nästa mål (140 ms), siffran flyttar med, byter färg till `#FF8A2C` och visar **kvarvarande** värde. Varje hopp +2 halvtoner extra.
- **Komprimering:** vid fler än 3 mål kortas varje hopp till 120 ms så hela överflödet stannar under 700 ms.
- **Ljud:** dov träff vars pitch sjunker med skadans storlek (`pitch = clamp(1.2 - dmg/200, 0.65, 1.2)`) – stora tal låter tyngre. Överflöd lägger på ett svisch som stiger per hopp.
- **Haptik:** `medium` per mål, `light` per överflödshopp.

### 5.4 `charge_stored` — 240 ms
- **Visuellt:** oanvända ögon lossnar som små `sem/charge`-gula kritprickar och åker i bezierbåge till Laddnings-mätaren i HUD, 60 ms stagger. Mätaren fyller på med `ease_out` och pulserar en gång.
- **Ljud:** ljus glasklang per prick, stigande pentatonisk följd, −9 dB mot träffljuden (detta är en sidokanal, inte huvudhändelsen).
- **Haptik:** `light`, **endast** när sista pricken landar. (Undviker haptikspam.)

### 5.5 `enemy_killed` — 360 ms
- **Visuellt:** kritsilhuetten spricker i 18–26 skärvor med utåtriktad impuls + gravitation. En helvit bildruta (33 ms). Hit-stop **90 ms**. Skärmskak 5 dp. HP-baren kollapsar inåt från båda håll.
- **Ljud:** torr "krack" + kort nedåtsvep (kritstav som knäcks). Pitch **sänks** 2 halvtoner mot kedjans aktuella ton – döden är en punkt, inte en höjning.
- **Haptik:** `heavy` (30 ms).

### 5.6 `die_cracked` — 520 ms (medvetet mönsterbrott)
- **Visuellt:** allt fryser (hit-stop **180 ms**), resten av skärmen avmättas 60 %. En kritspricka ritas diagonalt över tärningen (180 ms), sedan delas den i två halvor som roterar ut ur sloten och faller. Skärmskak 8 dp. Ordet `SPRUCKEN` i `type/scrawl` ligger kvar 600 ms.
- **Ljud:** ett enda lågt sub-bas-slag + omvänd cymbal. **Ingen pitch-stegring** – kedjans stigande mönster bryts avsiktligt så förlusten känns i kroppen.
- **Haptik:** `heavy`, lång (60 ms), en gång.
- Spelaren kan tappa för att gå vidare direkt.

### 5.7 `round_end` — 500–800 ms
- **Visuellt:** totalsiffran räknas upp i `type/display-xl` med sifferrullning (240 ms). Brädets kritstreck sveps bort av en squeegee-gradient vänster→höger (300 ms) och lämnar smetrester. Ett tally-streck ristas in i skärmkanten (`type/scrawl`).
- **Ljud:** hållen ackordsvällning som löser ut när siffran landar + ett torrt skrap när tally-strecket ritas.
- **Haptik:** `medium` när totalen landar.

### 5.8 Sammanställd tidsbudget (typisk runda)

| Steg | ms |
|---|---|
| 6 × `die_activated` | 1 320 |
| 1 × `combo_formed` ×4 | 340 |
| 2 × `damage_dealt` | 520 |
| 1 × `enemy_killed` | 360 |
| `charge_stored` (parallellt med round_end) | 0 |
| `round_end` | 600 |
| **Summa** | **3 140 ms** |

Över taket. **Åtgärd:** `die_activated` och `damage_dealt` för samma slot överlappar med 40 % (damage startar 150 ms in i die_activated), och `charge_stored` körs parallellt med `round_end`. Justerad summa ≈ **2 350 ms**. Detta är den arkitektoniska regeln: *ett kedjesteg består av överlappande delhändelser, inte av en kö.*

### 5.9 Tappa för att snabba upp
- **Ett tapp var som helst under uppspelning:** resterande steg körs på 35 % längd, alla hit-stops = 0, haptik slås ihop till ett enda `medium` vid slutet.
- **Andra tappet:** hoppa direkt till slutläget (händelseloggen appliceras, ingen animation).
- Inställning `Kedjetempo` (Lugn / Normal / Snabb / Blixt) gäller globalt och sparas.
- Tapp-för-snabbare får **aldrig** ändra utfallet. Endast presentation.

---

## 6. Tillgänglighet

### 6.1 Reducerat rörelse-läge (`reduced_motion`)

**Fullständig tabell i §12.6.** Sammanfattning:
- Ingen skärmskak, ingen zoom-punch, ingen kamerarörelse.
- Partiklar ersätts av en statisk burst-sprite som tonar ut.
- Hit-stop halveras.
- Number pops skalar 1,00 → 1,00 (ingen overshoot), bara fade + rörelse uppåt.
- **Timing bevaras** så att ljud, haptik och kausalitet fortfarande lär ut kedjan.
- Skärmövergångar blir cross-fade i stället för svep.

### 6.2 Färgblindsäkerhet
- Alla **sex** slot-typer skiljs på **ikonform + ramstil** utöver färg (§2.4).
  Formerna är mätta som silhuetter: sämsta par 0,78 IoU, gräns 0,85.
- Alla statuseffekter har en glyf framför siffran (§2.3).
- Sällsynthet har ramform + utskrivet ord (§2.5).
- Multiplikatorer har både storlek och siffra (`×2`, `×4`, `×8`) – färgen är dekor.
- Testas med deuteranopi-, protanopi- och tritanopi-simulering på stridsskärmen och belöningsskärmen innan M2 är klar.

### 6.3 Text och kontrast
- Teckenstorlek 85 / 100 / 115 / 130 %. Layout reflowar: slots och tärningar behåller fysisk storlek (de är träffytor), paneler och kort blir scrollbara.
- Läge **Hög kontrast+**: full tokentabell i **§2.11**. Botten `#000000`,
  krita `#FFFFFF`, semantiska färger ljusare, alla ramar till `stroke/bold`.
  Minsta kontrast i läget 6,1:1.
- Minsta kontrast i standardtemat: **4,9:1** (`sem/blood` mot `surface/raised`). Primärtext: 13,1:1.
- All spelkritisk information finns även i text – aldrig enbart ikon, aldrig enbart färg, aldrig enbart animation.

### 6.4 Övrigt
- Haptik kan stängas av helt eller sättas till "endast vid kritiska händelser" (`enemy_killed`, `die_cracked`).
- Ljud och musik har separata reglage; spelet är fullt spelbart ljudlöst (all pitch-information dubbleras visuellt av multiplikator-badgen).
- Inga tidsberoende beslut. Ingen timer någonstans i spelet.

---

## 7. Onboarding – max 3 tooltips i första striden

Ingen tutorial-vägg, ingen forcerad sekvens. Tooltips är kritklotter (`type/scrawl`) med pil, försvinner vid handling eller vid tapp utanför, och kommer aldrig tillbaka.

| # | När | Text | Försvinner när |
|---|---|---|---|
| 1 | 600 ms efter första kastet, runda 1 | *"Dra en tärning hit."* Pil till tärning → slot 1 | Första tärningen är placerad |
| 2 | När ≥ 1 tärning ligger, runda 1 | *"Kedjan går vänster→höger. Du ser skadan innan du bekräftar."* Pil till förhandsvisningen | Spelaren bekräftar sin första kedja |
| 3 | Första gången spelaren **har** två lika ögon i brickan (runda 2+) | *"Lika ögon bredvid varandra: ×2."* Pil till de två tärningarna | Spelaren bekräftar nästa kedja, eller efter 8 s |

Om tooltip 3 aldrig triggas under strid 1 visas den i stället första gången en ×2 faktiskt bildas, som efterhandsbekräftelse ("Där: ×2").

**Allt annat lärs ut av spelet självt:**
- Slot-egenskaper: ikonen + en rad text i sloten, plus att effekten är synlig i förhandsvisningen.
- Överflöd: kritpilen som ritas mellan fiender förklarar sig själv första gången.
- Omkast: knappen har en räknare (`OMKAST 2/2`) – ingen förklaring behövs.
- Smedja och reliker: förklaras på kortet i samma stund som valet görs.
- Kodex innehåller en fullständig regelreferens för den som vill läsa, men den pushas aldrig.

---

## 8. Hybriden: pixelvärld och kritgrop i samma viewport

Regeln i en mening: **pixlar är substantiv, krita är verb.**
Det som existerar i världen ritas i pixlar. Det som spelet *säger* om världen –
orsak, verkan, siffror, val – ritas i krita.

### 8.1 Vad som är vad

| Pixel (World-lagret) | Krita (ChalkUI-lagret) |
|---|---|
| Smeden och hans utrustningslager | Kedjepilar mellan slots |
| De sex fienderna och SLAGJAW | Alla siffror (Anton) |
| Tärningskroppar, ögon, glypher, sprickor | Multiplikator-badges och klammrar |
| Relik-, slot- och nodikoner (16×16) | Slot-ramar, pulserande konturer, dimning |
| Parallaxlager och golv i marschen | HP-barer, Ladda-mätaren, intent-text |
| Träffblixt på en fiende (vit modulate) | Kritdamm, skärvor, number pops, tally-streck |
| – | Tooltips, knappar, paneler, modaler |

Två gränsfall, avgjorda:

* **Kritdamm när en tärning aktiveras** är krita, inte pixlar. Partiklarna hör
  till händelsen, inte till objektet.
* **Fiendens HP-bar** är krita och ritas ovanför pixelsilhuetten, aldrig som en
  pixelsprite. Annars måste varje fiende ha ett barark.

### 8.2 Två CanvasLayers, olika filter

| Lager | `layer` | `texture_filter` | Innehåll |
|---|---|---|---|
| `World` | 0 | `TEXTURE_FILTER_NEAREST` | All pixelgrafik |
| `ChalkUI` | 10 | `TEXTURE_FILTER_LINEAR` | `chalk.gdshader`, `Line2D`, partiklar, fonter |

Filtret ärvs nedåt, så det sätts en gång på respektive rotnod.
Viewporten är `canvas_items` på 1080×1920 med `scale_mode = fractional` –
**inte** integer scale. Integer scale skulle tvinga ned kritan i låg upplösning
och döda exakt den handdragna mjukhet som *är* riktning A.

### 8.3 Skala och snapping

| Konsttyp | Källstorlek | Skala | Skärmstorlek |
|---|---|---|---|
| Tärning | 32 × 32 | **×5** | 160 px (6 i rad = 960 px + marginal på 1080) |
| Karaktär / fiende | 48 × 48 (32 × 32 för de små) | **×4** | 192 px (128 px) |
| Ikon (relik, slot, nod) | 16 × 16 | **×4** eller **×3** | 64 px / 48 px |
| Parallax | 320 × 120 | **×4** | 1280 px bred kakling |

Positionera alltid i heltalsmultipler av `ART_SCALE`. De globala `snap_2d_*`-
flaggorna snappar mot viewportpixlar (1080-rutnätet), inte mot konstrutnätet,
och hjälper därför inte. Kameror och tweens på pixelnoder måste kvantiseras
likadant, annars kryper kanterna under marschen.

### 8.4 Två shaders, två lager – aldrig korsvis

* `src/game/shaders/palette_lut.gdshader` ligger **bara** på World-noder.
  Den gör två jobb: tärningsmaterial (en gråskalekropp + LUT per material) och
  stilenhetlighet (varje importerad sprite tvingas genom `lut_world.png`).
  Utan den regeln spretar tre CC0-källor isär – det är den enskilt största
  risken i hela grafikpipen enligt research 04.
* `src/game/shaders/chalk.gdshader` ligger **bara** på ChalkUI-noder.
  Lägger man kritshadern på pixelkonst suddas pixelrutnätet; lägger man
  palett-LUT:en på kritan tappar kritan sina mellantoner. Båda misstagen är
  lätta att göra och svåra att se på en telefon i solljus.
* Förhandsvisningsscener för dev: `design/shader_preview_palette.tscn` och
  `design/shader_preview_chalk.tscn`.

### 8.5 Tillgänglighet i hybriden

* **Reducerad rörelse:** parallaxhastigheterna nollställs (marschen blir en
  hård övergång mellan rum), `chalk.gdshader` körs med `jitter_speed = 0.0`
  så kornet och erosionen finns kvar men skakningen försvinner, och tärningarnas
  tumbling ersätts av en 90 ms cross-fade till landningssidan.
* **Färgblindhet:** varje tärningssida har en formkod (pipmönster eller glyph
  från §2.3), varje fiende har en formburen tell (§9.4 i
  `assets/sprites/README.md`). Ingen pixel bär information via färg ensam.
* **Hög kontrast+:** World-lagret körs genom `lut_world.png` med förhöjd
  `luma_gamma`, vilket separerar silhuett från botten utan att rita om något.

---

## 9. Tärningarnas visuella spec

Tärningen är spelets enda "fysiska" objekt och ska alltid vara det öga dras
till (§1A). Den är därför den enda pixelsaken som får ligga i tumzonen.

### 9.1 Komposition, inte färdiga bilder

En tärning är fyra staplade `Sprite2D` i z-ordning:

| z | Nod | Textur | Not |
|---|---|---|---|
| 0 | `Body` | `dice/die_body_gray.png` | `palette_lut.gdshader` + `lut_<material>.png` |
| 1 | `Glyph` | `dice/pips_<0-6>.png` eller `dice/glyph_<namn>.png` | `modulate` = semantisk token (§2.3) |
| 2 | `Rim` | `dice/glass_highlight.png` | endast glas, blend Add |
| 3 | `Crack` | `dice/crack_<1-3>.png` | endast sprucken, variant seedad per tärning |

45 kombinationer täcks av 25 filer. En ny smidbar sida i M2 kostar **en glyph**.

### 9.2 Material

| Material | LUT | Läsning |
|---|---|---|
| `IRON` | `lut_iron.png` | Kall grå, tung. Smedens startuppsättning. |
| `BONE` | `lut_bone.png` | Varm elfenben (`bone/die #E8E0CF`). Standardläsning "tärning". |
| `GLASS` | `lut_glass.png` | Iskall cyan + additiv kant. **Glas ser ömtåligt ut med flit** – spelaren ska känna sprickrisken innan den inträffar. |

Materialbyte animeras med `lut_strength` 0 → 1 över 220 ms (`motion/base`),
aldrig med en texturväxling.

### 9.3 Sidor

| Sida i `content.gd` | Overlay | Modulate |
|---|---|---|
| `PIP_1` … `PIP_6` | `pips_1` … `pips_6` | `bone/pip` |
| `CRACKED`, värde 0 | `pips_0` (ihålig ring) + `crack_*` | `bone/pip` |
| `POISON_DROP` | `glyph_gift` | `sem/poison` |
| `EMBER` | `glyph_eld` | `sem/fire` |
| `VAMP_FANG` | `glyph_blod` | `sem/blood` |
| `HOLLOW` | `glyph_tomrum` | `sem/shield` |
| `SNOWBALL`, `TWIN_EYE`, `HAMMER_FACE`, `LEAD_SIX` | `pips_<värde>` + krit-badge | `bone/pip` |

De fyra sista får egna glypher i M2. Skälet att inte tvinga fram dem nu: på
32 px tål ytan **en** form. Hellre en ärlig siffra med en kritbadge än två
otydliga symboler ovanpå varandra.

### 9.4 Rullning (`die_rolled`) — 420 ms

* **Visuellt:** `Body.texture = dice/die_tumble_gray.png` (`hframes = 6`),
  6 frames à 50 ms, `Glyph.visible = false`. På landningsframen poppar rätt
  glyph in med squash 1,00 → 1,14 → 1,00 över 80 ms. **Glyphen animeras aldrig.**
* **Ljud:** tre träklick med fallande täthet, sedan ett torrt anslag på landningen.
* **Haptik:** `light` endast på landningen, en gång för hela kastet – inte per tärning.
* **Reducerad rörelse:** ingen tumbling, cross-fade 90 ms till landningssidan.

### 9.5 Storlek och träffyta

64 dp visuellt i brickan (§2.9), 72 dp träffyta. Vid ×5 på 1080-viewporten är
32 px-tärningen 160 px = 53 dp på en 360 dp-skärm; brickan skalar därför
tärningen till `clamp(46, (100vw − 62)/6, 58)` dp precis som i wireframen, och
pixelrutnätet hålls heltaligt genom att skalan låses till ×4 eller ×5 och
avståndet mellan tärningarna bär resten av justeringen.

---

## 10. Marschremsan (sidescroll) i portrait

Nod-grafen är fortfarande datamodellen (StS-struktur). Marschen är hur den
*visas*: figuren går åt höger, och vid en förgrening stannar den och spelaren
tappar sitt val i tumzonen.

### 10.1 Layout

| Zon | Höjd (360 × 640 dp) | Höjd (430 × 932 dp) | Innehåll |
|---|---|---|---|
| Safe area topp | 16 | 20 | – |
| HUD | 56 | 56 | HP, Ladda-mätare, relikbricka, våningsindikator |
| **Marschremsa** | **268** | **392** | Parallax + figur + kommande noder |
| Nodkort ("nästa: STRID · 3 fiender") | 96 | 104 | Krita, läs-endast |
| Tumzon: vägval | 148 | 300 | 2–3 knappar, 56 dp höga, 12 dp gap |
| Safe area botten | 24 | 24 | – |

Marschremsan slutar alltså vid **52 %** av skärmhöjden på liten skärm, vilket
håller tumzonsregeln (allt interaktivt under 58 %).

### 10.2 Parallaxhastigheter

| Lager | Fil | `motion_scale.x` | Roll |
|---|---|---|---|
| Fjärran | `env/floor1_parallax_far.png` | **0,15** | Silhuett, ingen detalj |
| Mitt | `env/floor1_parallax_mid.png` | **0,45** | Pelare och rör, ger djup |
| Golv | `env/floor1_tile.png` | **1,00** | Figurens plan |
| Förgrund | `env/floor1_parallax_near.png` | **1,20** | Skräp som sveper förbi, mörkt så figuren poppar |

Alla lager är horisontellt kaklingsbara; `motion_mirroring.x = 320 * ART_SCALE`.
Marschhastighet 40 konstpixlar/s (= 160 px/s vid ×4), vilket ger ~4 s mellan
två noder. Figuren står still på skärmens **38 %-linje** – vänster om mitten,
så spelaren ser mer av vad som kommer än av vad som passerat.

### 10.3 Förgreningar

1. Figuren saktar in över 300 ms och går till `idle`.
2. Krit-UI:t ritar 2–3 streck framåt från figuren (`Line2D` + `chalk.gdshader`,
   140 ms per streck, vänster→höger – samma kausalitetsspråk som kedjan).
3. Varje streck slutar i en nodikon (`ui/node_*.png`, 16 px ×3 = 48 dp) med
   krit-ram och **utskriven etikett** (`STRID`, `ELIT`, `SMEDJA`, `VILA`,
   `BOSS`, `MYSTERIUM`). Ikonerna i remsan är **läs-endast**.
4. Valet görs på knapparna i tumzonen, 56 dp höga, full bredd − 2×16 dp,
   12 dp mellan. Knappen upprepar ikon + etikett + en rad förhandsinfo.
5. Vid tryck: knapparna tonar ut (140 ms), strecket till vald nod fylls i
   (`motion/base`), figuren går vidare. Övriga streck suddas med `wipe`-
   uniformen i `chalk.gdshader`.

**Ingen joystick, ingen fri gång.** Spelaren har noll rörelseinput – marschen
är pacing och utrustningsskyltning, inte utforskning.

### 10.4 Reducerat rörelse-läge

Parallaxen står still, figuren spelar `idle`, och nodvalet presenteras direkt
som en kortlista. Marschen blir då en 300 ms cross-fade i stället för 4 s gång.
Ingen information går förlorad – allt som marschen visar finns också i
nodkortet och på knapparna.

---

## 11. Asset-checklista för nytt innehåll

Kör den här listan **innan** en ny sprite committas. Punkt 1–3 är designval,
4–8 är kvalitet, 9–12 är regelefterlevnad och CI.

1. **Vilket id?** Sprite-namnet ska gå att mappa till ett id i
   `src/data/content.gd` (fiende, relik, sida, slot, nod). Finns inget id –
   varför finns spriten?
2. **Vilken tell?** Vad i silhuetten berättar regeln? En fiende utan synlig
   tell är en HP-stapel med hatt.
3. **Pixel eller krita?** Se §8.1. Vid tveksamhet: bär den information om
   orsak/verkan är den krita.
4. **Rätt cell:** 16×16 ikon · 32×32 fiende/tärning · 48×48 karaktär (paperdoll
   kräver exakt 384×192 per lagerark, se `assets/sprites/hero/PAPERDOLL.md`).
5. **Palett:** enbart tokens ur §2, eller körd genom `lut_world.png`.
   Inga främmande hexvärden i World-lagret.
6. **Ljus uppifrån vänster.** Gäller varenda sprite, annars ser scenen
   hopplockad ut även med rätt palett.
7. **Silhuett-test:** fyll spriten svart och titta på den i ×1. Går den att
   känna igen? Om inte, ändra formen – inte färgen.
8. **Kontrast:** minst 4,5:1 mot `surface/pit` för allt spelkritiskt.
   Formkod ska alltid finnas utöver färg (§2.3).
9. **Licensrad:** rad i `assets/ASSET_LICENSES.csv` med `path,source,author,
   license,url,retrieved,notes`. Licensen måste vara `CC0-1.0`, `OGA-BY-3.0`,
   `CC-BY-4.0`, `OFL-1.1`, `proprietary-purchased` eller `own-work`.
   **CC-BY-SA och GPL är förbjudna** (DECISIONS 2026-09-21).
10. **Ingen AI-genererad rå asset.** AI får användas som skiss och för
    mellanframes av sprites vi redan äger, aldrig som slutgiltig art.
11. **Import:** Lossless, Nearest, ingen mipmap, `fix_alpha_border = true`,
    `detect_3d/compress_to = 0` (`assets/sprites/README.md` §6).
12. **Kör `python3 tools/check_asset_licenses.py`.** Grönt eller inget commit.
    CI kör samma steg och failar bygget.

Extra för animerade lager: samma `hframes`/`vframes` som kontraktet, samma
origo, sista authorade framen upprepas i resten av raden.

---

## 12. Juice-tidslinje: en komplett runda, millisekund för millisekund

Det här är **den normativa uppspelningen** av ett kedjefall. Dev ska kunna
koda rakt av från tabellen: varje rad har bana, starttid, längd, visuell
effekt, ljudfil, `pitch_scale` och haptiknivå.

### 12.1 Scenariot

Sex tärningar, värden **3 · 3 · 5 · 2 · 6 · 4**. Tärning 0 och 1 är lika och
bredvid varandra ⇒ **par (×2)**. Kedjesteg 2 dödar Rostråtta A och **överflödar**
till Rostråtta B. Kedjesteg 5 avslutar mot B. En oanvänd tärning ger
**Laddning**. Det är alltså par + överflöd + kill i samma runda – det
tätaste normalfallet, inte ett rekordfall.

### 12.2 Banorna (ARCHITECTURE, `event_player.gd`)

| Bana | Vad som ligger här | Hur markören flyttas |
|---|---|---|
| `CHAIN` | `die_activated`, `damage_dealt`, `enemy_killed`, `enemy_attack` | `ms_hint × 0,6` – **40 % överlapp**, nästa steg startar innan det förra är klart |
| `BEAT` | `round_started`, `combo_formed`, `die_cracked`, `round_end` | `ms_hint` – ett taktslag äger sin tid ensamt |
| `SIDE` | överflödshopp, `charge_stored`, statusar, `slot_modifier` | **0** – spelas parallellt, 60 ms stagger inbördes |

**Hit-stop räknas in i eventets `ms_hint`, inte ovanpå.** En `combo_formed` ×2
är 300 ms *inklusive* sin 40 ms frysning. Annars spräcker tre combos budgeten
utan att en enda rad i tabellen ändras.

### 12.3 Tidslinjen

`pitch` följer §5:s globala regel `pow(2, (step + combo_bonus)/12)`, tak 2,0.
`combo_bonus` = 0 fram till paret, 2 efter. Ljudfilerna och deras mix-dB står
i `assets/sfx/README.md`.

| # | Start | Bana | Event | Längd | Visuellt | Ljudfil | `pitch` | Haptik |
|---|---|---|---|---|---|---|---|---|
| 1 | **0** | BEAT | `round_started` | 180 | Sex tärningar landar i brickan (squash 1,14, 80 ms, 30 ms stagger). Slot-ramar tänds. | `die_activate.wav` ×6, 30 ms isär | 0,90 | `light` ×1 på sista landningen |
| 2 | **180** | CHAIN | `die_activated` slot 0 | 220 | Skala 1,00→1,18→1,00. Kritring 32→72 dp. Slot-underline ritas v→h. 8 dammpartiklar. | `die_activate.wav` | **1,000** | `light` |
| 3 | **312** | CHAIN | `die_activated` slot 1 | 220 | Samma, i slot 1:s färg | `die_activate.wav` | **1,059** | `light` |
| 4 | **444** | BEAT | `combo_formed` ×2 | 300 | Tärning 0+1 dras ihop 4 dp. Kritklammer under dem (140 ms). Badge `×2` poppar 0,40→1,25→1,00, rot −6°→0°. Zoom-punch 1,03. Skak **2 dp** ×3. 12 partiklar. **Hit-stop 40 ms inuti.** | `combo_pair.wav` | **1,189** | `light` |
| 5 | **744** | CHAIN | `die_activated` slot 2 | 220 | Som #2, men multiplikatorn syns i förhandsvisningen | `die_activate.wav` | **1,260** | `light` |
| 6 | **876** | CHAIN | `damage_dealt` → Råtta A (24) | 260 | Number pop `24` i `display-xl`, stiger 24 dp, 0,60→1,30→1,00. A blixtrar vitt 60 ms, skakar 6 dp ×3. HP-bar dränerar efter 120 ms, spökspår i `sem/blood` 400 ms. | `damage_hit.wav` | **1,080** (skadeberoende, §3.2 i sfx-README) | `medium` |
| 7 | **1 016** | SIDE | överflödshopp A→B | 140 | Kritpil ritas A→B (140 ms). Siffran flyttar med, byter till `#FF8A2C`, visar **kvarvarande 9**. | `damage_overflow.wav` | **1,414** | `light` |
| 8 | **1 032** | CHAIN | `enemy_killed` A | 360 | Silhuetten spricker i 22 skärvor (utåtimpuls + gravitation). Helvit bildruta 33 ms. **Hit-stop 90 ms inuti.** Skak 5 dp. HP-baren kollapsar inåt. Death-frames 0→1→2 à 100 ms. | `enemy_killed.wav` | **1,122** (−2 halvtoner) | `heavy` |
| 9 | **1 248** | CHAIN | `die_activated` slot 3 | 220 | Som #2 | `die_activate.wav` | **1,335** | `light` |
| 10 | **1 380** | CHAIN | `die_activated` slot 4 | 220 | Som #2 | `die_activate.wav` | **1,414** | `light` |
| 11 | **1 512** | SIDE | `charge_stored` (3 ögon) | 240 | Tre gula kritprickar lossnar och åker i bezierbåge till Ladda-mätaren, 60 ms stagger. Mätaren fyller med `ease_out` och pulserar en gång. | `charge_store.wav` ×3 | **1,414 / 1,498 / 1,587** | `light` **endast** på sista pricken |
| 12 | **1 512** | CHAIN | `die_activated` slot 5 | 220 | Som #2 | `die_activate.wav` | **1,498** | `light` |
| 13 | **1 644** | CHAIN | `damage_dealt` → Råtta B (11) | 260 | Number pop `11`. B blixtrar och rycker. | `damage_hit.wav` | **1,145** | `medium` |
| 14 | **1 800** | BEAT | `round_end` | 600 | Totalsiffran rullar upp (240 ms). Brädet sveps av en squeegee-gradient v→h (300 ms) och lämnar smetrester. Tally-streck ristas in i kanten i `type/scrawl`. | `round_end.wav` | 1,000 | `medium` när totalen landar |

**Markörens aritmetik** (så dev kan verifiera radernas starttider):

```
0    + 180 (BEAT)            = 180
180  + 220*0.6 = 132 (CHAIN) = 312
312  + 132                   = 444
444  + 300 (BEAT)            = 744
744  + 132                   = 876
876  + 260*0.6 = 156 (CHAIN) = 1032
1032 + 360*0.6 = 216 (CHAIN) = 1248
1248 + 132                   = 1380
1380 + 132                   = 1512
1512 + 132                   = 1644
1644 + 156                   = 1800
1800 + 600 (BEAT)            = 2400
```

`SIDE`-raderna (#7, #11) flyttar inte markören; deras starttid är markörens
läge när eventet kom, plus stagger.

### 12.4 Budget

| Post | ms |
|---|---|
| Kedjan P0–P3, `round_started` → sista `damage_dealt` klart | **1 904** |
| `round_end` (P3-avslutning) | 600, startar 1 800 |
| **Sista pixeln slutar röra sig** | **2 400** |
| Tak (DECISIONS 2026-09-21) | 2 500 |
| **Marginal** | **100 ms (4 %)** |

Marginalen är liten med flit. Blir ett event längre ska ett annat kortas,
inte taket höjas. Överskrids taket skalar `EventPlayer` hela tidslinjen
linjärt **en gång** – aldrig genom att hoppa över ett event, eftersom ett
uteblivet event är ett uteblivet orsakssamband.

Vid `chain_speed`: Lugn ×1,25 = 3 000 ms (över taket, men det är spelarens
egna val och rundtaket 3 200 ms håller), Normal ×1,0 = 2 400, Snabb ×0,6 =
1 440, Blixt ×0,35 = 840.

### 12.5 Haptik: sammanslagningsregel

Tabellen ger 13 pulser på 2,4 s. Det är över gränsen för vad som känns som
feedback och under gränsen för vad som känns som en vibrerande telefon.
**Regel:** två haptikanrop närmare än **90 ms** slås ihop till ett enda med
den starkaste nivån. Med tidslinjen ovan är minsta avstånd 132 ms, så inget
slås ihop i normalfallet – men regeln skyddar mot `SIDE`-banan, som kan lägga
en `light` mitt i ett `CHAIN`-steg.

`light` 10 ms · `medium` 20 ms · `heavy` 30 ms. Inställningen "endast kritiska
händelser" behåller bara `enemy_killed` och `die_cracked` (§6.4).

### 12.6 Reducerad rörelse (`reduced_motion`)

**Timingen ändras inte.** Alla starttider och längder i §12.3 gäller oförändrat,
så ljudet, haptiken och kausaliteten lär fortfarande ut kedjan. Det som ändras
är vad som ritas.

| Effekt | Standard | `reduced_motion` |
|---|---|---|
| Skärmskak | 2 / 5 / 7 dp | **Av helt** |
| Zoom-punch | 1,03–1,05 | **Av helt** |
| Kamerarörelse / parallax | §10.2 | **Av** (marschen blir 300 ms cross-fade) |
| Hit-stop | 40 / 90 / 110 / 180 ms | **Halveras** (20 / 45 / 55 / 90 ms) |
| Number pop | 0,60→1,30→1,00 + rörelse uppåt | **Behålls**, men utan overshoot: 1,00→1,00, bara fade + 24 dp uppåt |
| Träffblixt (vit `modulate` 60 ms) | vit blixt | **Ersätts av en 2 dp outline** i `sem/damage` runt målet, samma 60 ms |
| Helvit bildruta vid `enemy_killed` | 33 ms | **Ersätts av outline-puls**, 33 ms |
| Partiklar (kritdamm, skärvor) | 8–40 st med fysik | **En statisk burst-sprite** som tonar ut över samma tid |
| Tärningens tumbling | 6 frames à 50 ms | **90 ms cross-fade** till landningssidan |
| Badge-rotation −6°→0° | rotation | **Av**, badgen fadear in på plats |
| Squeegee-svep vid `round_end` | svep v→h | **Cross-fade** över samma 300 ms |
| `chalk.gdshader` | `jitter_speed = 1.4` | **`jitter_speed = 0.0`** – korn och erosion kvar, skakningen borta |
| Ljud och haptik | enligt §12.3 | **Oförändrade** |

Regeln i en mening: **rörelse tas bort, information aldrig.** Varje sak som
stängs av ovan har en ersättare som bär samma information på samma tid.

### 12.7 Vad som händer vid tapp

* **Första tappet:** resterande rader körs på 35 % längd, alla hit-stops = 0,
  all kvarvarande haptik slås ihop till ett `medium` vid slutet.
* **Andra tappet:** händelseloggen appliceras direkt, ingen animation.
* Utfallet ändras aldrig – varje event bär absoluta eftervärden
  (`target_hp_after`, `pool_after`), vilket är precis varför snabbspolning är
  bevisbart säker (ARCHITECTURE, `tests/test_event_player.gd`).

---

## 13. Skisser och verifiering

- `design/wireframe_combat.html` – stridsskärm. Tryck **BEKRÄFTA KEDJA** för att spela upp händelseloggen vänster→höger (`die_activated` ×4 → `combo_formed` ×4 → `damage_dealt` med överflöd → `round_end`). Tapp under uppspelning = snabbspolning, andra tappet = hoppa till slutet.
- `design/wireframe_reward.html` – belöningsval 1 av 3 med sällsynthetsfärg + ramform + utskrivet ord, samt referensremsa över hela skalan.
- `design/mockup_combat_pixel.html` – **hybriden med riktiga sprite-PNG:er**: Smeden som paperdoll-stapel (kappa → kropp → hjälm → vapen), tre fiender från rum 2 (`IRON_TICK`, `SLAG_MOTH`, `RUST_RAT`), tärningar komponerade som i Godot (kropp + pip/glyph + glaskant + spricka), tre parallaxlager + golvtile, allt under samma krit-UI.
- `design/shader_preview_palette.tscn`, `design/shader_preview_chalk.tscn` – Godot-scener för de två shadrarna, öppnas direkt i editorn.
- `design/fonts/` – lokala latin-subset av Anton, Familjen Grotesk och Caveat Brush. Mockuperna är helt självständiga och gör ingen nätverkstrafik.
- `design/screenshots/` – renderade headless i Chromium.

**Verifierat 2026-09-21 (Chromium headless, deviceScaleFactor 2):**

| Vy | 360×640 | 390×844 | 430×932 |
|---|---|---|---|
| Strid (wireframe) | ingen scroll | ingen scroll | ingen scroll |
| Strid, kedja spelas upp | ingen scroll | ingen scroll | ingen scroll |
| Belöning | ingen scroll | ingen scroll | ingen scroll |
| **Strid, hybrid pixel + krita** | ingen scroll | ingen scroll | ingen scroll |

Ingen horisontell scroll och ingen vertikal scroll på någon storlek; allt ryms inom viewporten.
Tärningsstorleken i brickan är `clamp(46px, (100vw − 62px)/6, 58px)` vilket ger **49,7 dp på 360 dp bredd** – över 48 dp-kravet även på den smalaste målskärmen.

Pixelskalorna i hybridmockupen är **heltal på enhetspixelnivå** (deviceScaleFactor 2):
hjälte 48 px-cell i 72 CSS px = ×6, fiender 32 px i 64 CSS px = ×4, tärningar 32 px i
48 CSS px = ×3, ikoner 16 px i 26–32 CSS px. På 360 dp bredd ryms hjälte + tre fiender
utan klippning (72 + 3×64 + gap = 288 av 328 tillgängliga).

**Kända avvikelser mellan mockup och spec (medvetna):**
- Kritjittret är här ett SVG `feDisplacementMap`-filter. I Godot blir det `chalk.gdshader` på samma princip (noise-UV-offset + grain + alpha-erosion).
- `wireframe_combat.html` använder fortfarande placeholder-SVG:er för fiender. `mockup_combat_pixel.html` använder de riktiga PNG:erna och är den som gäller för hybriden.
- Parallaxen i mockupen står still. I spelet rör sig lagren med hastigheterna i §10.2.
- Palett-LUT-shadern kan inte köras i HTML; i mockupen används de förtintade tärningskropparna (`die_body_{iron,bone,glass}.png`) i stället för gråskalemastern.
- Partiklar, hit-stop, ljud och haptik finns inte i HTML-mockupen – se §5 för specen.

## 14. Öppna frågor till PM

1. ~~Godkänn riktning A~~ – **beslutad**. Hybriden pixel + krita är beslutad av Anders (DECISIONS 2026-09-21).
2. ~~`chalk.gdshader` är riktningens enda kritiska tekniska beroende~~ – **byggd**, ligger i `src/game/shaders/` med förhandsvisningsscen. Samma sak för `palette_lut.gdshader`.
3. ~~Reducerat rörelse-läge och färgblindspalett~~ – **flyttade in i M2 hårt** (DECISIONS 2026-09-21).
4. **Nytt:** de CC0-källor DECISIONS pekar ut (0x72, Kenney, Pixel Frog, Szadi art) är blockerade av egress-policyn i den här miljön. M1 går därför vidare på egengjorda sprites i rätt palett och rätt rutnät, med en dokumenterad utbytesplan (`assets/sprites/README.md` §0). PM avgör om hämtningen ska göras i en miljö med öppnare nät, eller om Oryx Mega Pack (≈25 USD) ska köpas i M2 i stället.
5. **Nytt:** fyra smidbara sidor (`SNOWBALL`, `TWIN_EYE`, `HAMMER_FACE`, `LEAD_SIX`) saknar egen glyph i M1 och visas som pip + krit-badge (§9.3). Bör få glypher i M2.
6. ~~reliklagren i paperdollen är specificerade men inte ritade~~ – **ritade i
   M2.** Alla sex reliker har konst på både primär- och reservlager
   (`assets/sprites/hero/PAPERDOLL.md` §3 och §5). Dev behöver ett uppslag
   `(lager, relik-id) → fil`, kodskiss finns i PAPERDOLL §5.
7. **Nytt:** `palette_lut.gdshader` är fixad och mätt i båda renderarna
   (`design/shader_probe.tscn`). Dev kan gå tillbaka till gråskala + LUT för
   tärningskroppar, vilket också gör `lut_strength`-tweenen i §9.2 användbar.
8. **Nytt:** fiendearken är nu `hframes 4 / vframes 2` med en `death`-rad.
   `Art.ENEMIES` och `Art.enemy_frames()` behöver en rad var.
9. **Nytt:** §2.11 (Hög kontrast+) och §12.6 (reducerad rörelse) är
   specificerade men inte kopplade till någon inställning i koden. Båda är
   M2-krav enligt DECISIONS 2026-09-21.

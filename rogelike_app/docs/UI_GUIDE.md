# UI_GUIDE.md – PIPWRECK

*Version 1 · 2026-09-21 · Ägare: UI/UX · Status: **riktning A rekommenderad, väntar PM-beslut***

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

### 2.4 Färg – slot-typer (form + färg)

| Slot | Färg | Form (kontur + ikon) |
|---|---|---|
| Eld | `#FF6A2C` | Triangelikon, **heldragen** ram |
| Spegel | `#6ED2F5` | Romb delad i två, **dubbel** ram |
| Amboss | `#D7DEE6` | Hexagon, **tjock (4 dp)** ram |
| Ladda | `#FFD447` | Cirkel med bågfyllning, **prickad** ram |
| Tomrum | `#8A94A6` | Kvadrat med kryss, **streckad** ram |

Ramstilen är redundant med färgen: en spelare med total färgblindhet kan skilja alla fem slots på enbart ramstil + ikon.

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
- Ingen skärmskak, ingen zoom-punch, ingen kamerarörelse.
- Partiklar ersätts av en statisk burst-sprite som tonar ut.
- Hit-stop halveras.
- Number pops skalar 1,00 → 1,00 (ingen overshoot), bara fade + rörelse uppåt.
- **Timing bevaras** så att ljud, haptik och kausalitet fortfarande lär ut kedjan.
- Skärmövergångar blir cross-fade i stället för svep.

### 6.2 Färgblindsäkerhet
- Alla fem slot-typer skiljs på **ramstil + ikonform** utöver färg (§2.4).
- Alla statuseffekter har en glyf framför siffran (§2.3).
- Sällsynthet har ramform + utskrivet ord (§2.5).
- Multiplikatorer har både storlek och siffra (`×2`, `×4`, `×8`) – färgen är dekor.
- Testas med deuteranopi-, protanopi- och tritanopi-simulering på stridsskärmen och belöningsskärmen innan M2 är klar.

### 6.3 Text och kontrast
- Teckenstorlek 85 / 100 / 115 / 130 %. Layout reflowar: slots och tärningar behåller fysisk storlek (de är träffytor), paneler och kort blir scrollbara.
- Läge **Hög kontrast+**: botten `#000000`, krita `#FFFFFF`, semantiska färger till max chroma, alla ramar till `stroke/bold`.
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

## 8. Skisser och verifiering

- `design/wireframe_combat.html` – stridsskärm. Tryck **BEKRÄFTA KEDJA** för att spela upp händelseloggen vänster→höger (`die_activated` ×4 → `combo_formed` ×4 → `damage_dealt` med överflöd → `round_end`). Tapp under uppspelning = snabbspolning, andra tappet = hoppa till slutet.
- `design/wireframe_reward.html` – belöningsval 1 av 3 med sällsynthetsfärg + ramform + utskrivet ord, samt referensremsa över hela skalan.
- `design/fonts/` – lokala latin-subset av Anton, Familjen Grotesk och Caveat Brush. Mockuperna är helt självständiga och gör ingen nätverkstrafik.
- `design/screenshots/` – renderade headless i Chromium.

**Verifierat 2026-09-21 (Chromium headless, deviceScaleFactor 2):**

| Vy | 360×640 | 390×844 | 430×932 |
|---|---|---|---|
| Strid | ingen scroll | ingen scroll | ingen scroll |
| Strid, kedja spelas upp | ingen scroll | ingen scroll | ingen scroll |
| Belöning | ingen scroll | ingen scroll | ingen scroll |

Ingen horisontell scroll och ingen vertikal scroll på någon storlek; allt ryms inom viewporten.
Tärningsstorleken i brickan är `clamp(46px, (100vw − 62px)/6, 58px)` vilket ger **49,7 dp på 360 dp bredd** – över 48 dp-kravet även på den smalaste målskärmen.

**Kända avvikelser mellan mockup och spec (medvetna):**
- Kritjittret är här ett SVG `feDisplacementMap`-filter. I Godot blir det `chalk.gdshader` på samma princip (noise-UV-offset + grain + alpha-erosion).
- Fiendesilhuetterna är placeholder-SVG:er. I spelet ritas de som `Polygon2D` per fiendetyp.
- Partiklar, hit-stop, ljud och haptik finns inte i HTML-mockupen – se §5 för specen.

## 9. Öppna frågor till PM

1. Godkänn riktning A (KRITGROPEN). B sparas som upplåsningsbart tema, C avfärdas.
2. `chalk.gdshader` är riktningens enda kritiska tekniska beroende – bör läggas som eget backlog-ärende i M2.
3. Reducerat rörelse-läge och färgblindspalett ligger i BACKLOG som "M2 om tid finns". Rekommendation: flytta in i M2 hårt – båda är billiga om de byggs in från start och dyra att retrofitta.

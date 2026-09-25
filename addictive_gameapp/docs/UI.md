# UI.md – KLUNK visuell spec, ljudkarta och game feel

Version 1.4 · 2026-09-25 (§12 meta-lager, §13 Kompisar, §14 Ekonomi, §15 Art v2) · Ägare: ui-designer. Underordnad `DESIGN.md` (spelregler) och `TECH.md` (stack).
Implementation av tokens: `app/src/data/theme.ts`. Granskningsbild: `docs/ui-preview.png` (nivåark, spel, start, förlust).

---

## 1. Tema: **Glimtarna** – lysande djuphavsvarelser i en glasburk

**Motivering (två meningar).** Burken lyser som det enda ljusa rummet i ett mörkt hav, vilket ger maximal kontrast för 11 objekt utan att de behöver dekoreras sönder – och det förklarar varför de lyser upp när de smälter ihop. Djuphavsvarelser äger dessutom "klunk"-ljudet och den mjuka, studsiga kroppsformen på ett sätt frukter inte gör, och undviker all formlikhet med Suika Game.

Kulörresa i tre akter (aldrig en generisk regnbågssnurr): **kallt** 0–2 (cyan → mint → lime), **varmt** 3–5 (gul → orange → korall), **elektriskt** 6–9 (rosa → violett → blå → pärlvit), **guld** 10. Varje akt har egen temperatur så spelaren ser "hur långt upp" ett objekt är i periferin.

Tre samtidiga signaler per nivå, aldrig färg ensam: **storlek** (radie ur DESIGN §2), **kulör**, **unikt ansikte** (11 uttryck, ett per nivå). Dekor (spröt, tofs, tentakler, fenor, krona, ring, prickar) är en fjärde signal för de nivåer som ligger nära varandra i kulör.

---

## 2. Designtokens

### 2.1 Palett (`THEME.palette`)

| Token | Hex | Användning | Kontrast mot `bg` |
|---|---|---|---|
| `bg` | `#0B1020` | Hela skärmen, vertikal gradient mot `bgDeep` | – |
| `bgDeep` | `#060A14` | Nedre delen + vinjett | – |
| `bgGlow` | `#132043` | Mjuk radial bakom burken, centrum (180, 330), r 320 | – |
| `jarGlass` | `#16223C` | Burkens innerfält, alpha 0,55 | – |
| `jarWall` | `#2B3B5E` | Väggfyllning | – |
| `jarEdge` | `#6E8CC4` | Glaskant, 3 px | 5,6:1 |
| `jarShine` | `#AFC8FF` | Två diagonala reflexstreck, alpha 0,14 | – |
| `danger` | `#FFB43A` | Farolinje (bärnsten – **aldrig** mättad röd) | 10,7:1 |
| `dangerHot` | `#FFF1CF` | Farolinjens pulstopp | 18,4:1 |
| `hud` | `#EAF2FF` | Poäng, logotyp | 16,8:1 |
| `hudDim` | `#8FA3C8` | Avstängda ikoner, sekundärt | 7,4:1 |
| `accent` | `#7CF9FF` | Interaktivt: play, siktlinje, scorepop, restart | 15,2:1 |
| `accent2` | `#FF5FA2` | Specialobjekt, gnistor, tunga/kinder | 6,7:1 |
| `gold` | `#FFD75E` | Rekord, hylla, nivå 10 | 13,6:1 |
| `ink` | `#14202E` | Ansikten och konturer **ovanpå** ljusa kroppar | – |
| `scrim` | `#0B1020` @ 0,82 | Förlust-overlay | – |

Regel: allt som spelaren kan röra ritas i `accent`. Inget annat använder `accent`.

### 2.2 Typografi

Ett systemtypsnitt, noll filer: `system-ui, -apple-system, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif`, vikt **800**. Endast siffror och logotypen renderas som text.

| Roll | px (logisk yta 360×640) | Färg |
|---|---|---|
| Logotyp `KLUNK` | 64, letter-spacing 8 | `hud` |
| Poäng, förlustskärm | 64 | `hud` |
| Poäng, HUD i spel | 34 | `hud` |
| Highscore, förlustskärm | 24 | `gold` |
| Highscore-markör, HUD | 16 | `gold` |
| Scorepop | 20 | `accent` |

Siffror ritas med fast teckenbredd (tabulära): rendera varje siffra på ett fast rutnät eller sätt `fontFamily` + manuell offset, annars hoppar HUD vid varje merge. Tusentalsavgränsare = smalt mellanslag (`1 240`).

### 2.3 Spacing och touchmål

Skala 4 / 8 / 12 / 16 / 24 / 32. Skärmmarginal 16. Safe area: topp 16, botten 24.

**Touchmål: 72 logiska px** (`THEME.touch.minLogical`). Räkning: FIT-skalning av 360 logiska px på en 320 dp-skärm ger faktor 0,89 ⇒ 72 × 0,89 = 64 dp. Alltså håller 72 logiska px kravet ≥64 dp på alla telefoner ≥320 dp breda. Plus 8 px osynlig slop. Ikoner ritas 48 px inuti sitt 72 px-mål.

---

## 3. Objektnivåer 0–10

Radie och poäng ägs av `data/levels.ts` (DESIGN §2). Utseende ägs av `THEME.levels[i]`.

| # | Namn (internt) | `color` | `color2` (kontur/dekor) | Ansikte | Dekor | Kontrast kropp/bg | Ansikte/kropp |
|---|---|---|---|---|---|---|---|
| 0 | Gnutt | `#7CF9FF` | `#0B4A57` | `dot` – två prickar, ingen mun | – | 15,2:1 | 13,2:1 |
| 1 | Blipp | `#4FE0B0` | `#064032` | `smile` – prickar + leendebåge | `antenna` (böjt spröt + kula) | 11,4:1 | 9,9:1 |
| 2 | Grodd | `#B9F05A` | `#2D4A0B` | `wink` – ett streck-öga + prick | 3 prickar | 14,1:1 | 12,3:1 |
| 3 | Pling | `#FFD447` | `#5A3D00` | `open` – rund öppen mun | inre ring | 13,3:1 | 11,6:1 |
| 4 | Knorr | `#FF9F3C` | `#5C2A00` | `grin` – brett fyllt leende + rosa tunga | `tentacles` (3 ben) | 9,3:1 | 8,1:1 |
| 5 | Kludd | `#FF6B6B` | `#59161B` | `sleepy` – halvslutna ögon, rak mun | 5 prickar | 6,8:1 | 5,9:1 |
| 6 | Bubbel | `#FF5FA2` | `#55103A` | `starry` – fyrstråliga stjärnögon | `tuft` (3 strån) | 6,7:1 | 5,8:1 |
| 7 | Drömmen | `#C77DFF` | `#2F1056` | `awe` – ringögon + liten oval mun | ring + 2 prickar | 7,0:1 | 6,1:1 |
| 8 | Vågen | `#6C8BFF` | `#14235A` | `cool` – en lång visirlinje + snett leende | `fins` (2 fenor) | 6,1:1 | 5,3:1 |
| 9 | Pärlan | `#E8F1FF` | `#3A4A6B` | `happy` – ^^ ögon | ring + 4 prickar | 16,6:1 | 14,5:1 |
| 10 | Klunken | `#FFD75E` | `#6B4300` | `joy` – ^^ + stor mun + kinder | ring + `crown` | 13,6:1 | 11,9:1 |

Alla ≥4,5:1 i båda riktningar. Ansiktena är ritade i `ink` på alla nivåer, aldrig i kroppens kulör.

### 3.1 Ritrecept (Phaser Graphics, sju steg, inga bildfiler)

Ritas en gång per nivå till en `RenderTexture`/`generateTexture` vid boot och återanvänds som textur – aldrig `Graphics` per body i `update()`.

```
1. HALO      3 koncentriska cirklar r·(1+glow) / r·(1+0,66·glow) / r·(1+0,33·glow),
             fillStyle(color, 0,06 / 0,10 / 0,14). Phaser Graphics saknar gradient;
             alternativ: en 128×128 radial-textur genererad en gång + BlendMode.ADD.
2. KROPP     fillCircle(0, 0, r) i color.
3. TOPPLJUS  fillEllipse(0, −0,44r, 1,12r, 0,56r) i 0xFFFFFF alpha 0,20.
4. RING      om ring: lineStyle(0,08r, color2, 0,45); strokeCircle(0, 0, 0,72r).
5. PRICKAR   spots st, vinkel i/spots·2π + 0,7, avstånd 0,46r ± 0,16r (alternerande),
             fillCircle(..., 0,11r) i color2 alpha 0,32.
6. KONTUR    lineStyle(max(2, 0,09r), color2, 1); strokeCircle(0, 0, r).
7. DEKOR     tvåpass: först mörk understroke i color2 med bredd lw+max(2,5; 0,09r),
             sedan ljus överstroke i color med bredd lw. Gör dekoren läsbar BÅDE
             mot kroppen och mot den mörka bakgrunden.
8. ANSIKTE   allt i ink. Ögoncentrum (±0,34r, −0,10r), ögonradie 0,115r,
             munlinje y = +0,26r, linjebredd max(1,6; 0,075r).
```

Dekorgeometri (enheter i `r`, origo i kroppens centrum):

| Dekor | Konstruktion |
|---|---|
| `antenna` | quadratisk kurva (0, −0,95) → kontroll (0,10, −1,34) → (0,24, −1,40); fylld cirkel r 0,15 i änden |
| `tuft` | tre streck från (sin a·0,55, −cos a·0,90) till (sin 2,2a·0,80, −cos a·1,34), a ∈ {−0,34; 0; 0,34} |
| `tentacles` | tre kurvor från (dx, 0,80) via (1,25dx, 1,20) till (0,75dx, 1,34), dx ∈ {−0,46; 0; 0,46} |
| `fins` | två trianglar (±0,80, −0,34) → (±1,34, 0,02) → (±0,80, 0,38) |
| `crown` | tre trianglar, bas ±0,17 tangentiellt vid 0,94r, spets vid 1,30r, vinklar {−0,40; 0; 0,40} |

Ansiktsgeometri (samma enheter):

| Uttryck | Konstruktion |
|---|---|
| `dot` | två fyllda cirklar 0,115 |
| `smile` | två prickar + båge r 0,34 centrerad (0; 0,02), 0,15π→0,85π |
| `wink` | vänster: streck ±0,13 horisontellt; höger: prick; mun båge r 0,28, 0,2π→0,8π |
| `open` | två prickar + fylld ellips 0,15×0,19 vid y 0,26 |
| `grin` | två prickar + fylld cirkelsektor r 0,42, 0,12π→0,88π, clip:ad tunga i `accent2` (cirkel r 0,20 vid y 0,44) |
| `sleepy` | två nedåtbågar r 0,16 (0,05π→0,95π) + rak mun ±0,12 |
| `starry` | två 8-uddiga stjärnor av fyra korsande streck (halvlängd 0,17) + fylld sektor r 0,36 |
| `awe` | två strokade ringar r 0,17 + pupiller 0,075 + fylld ellips 0,10×0,14 |
| `cool` | en linje bredd 0,17 från (−0,44; −0,12) till (0,44; −0,05) + båge r 0,24 förskjuten +0,06 |
| `happy` | två uppåtbågar r 0,16 (1,15π→1,85π) + mun-båge r 0,22 |
| `joy` | två uppåtbågar r 0,17 + fylld halvcirkel r 0,34 + kinder i `accent2` alpha 0,55 vid ±0,52 |
| `angry` | två sneda streck (bredd 0,13) + vågig mun av två quadratiska kurvor (endast bomben) |

Färgsträngar konverteras till Phaser-tal **en gång** vid boot: `Phaser.Display.Color.HexStringToColor(c).color`.

---

## 4. Specialobjekt (`THEME.special`)

Båda har radie 25 (DESIGN §4) och måste kännas igen i förhandsvisningen på under en halv sekund.

| | **Bomben** | **Regnbågen** |
|---|---|---|
| Silhuett | **Taggig**: 12 trianglar, längd 0,34r, runt en mörk kropp | **Cirkulär men randig**: 6 fyllda sektorer à 60° |
| Kropp | `#2A3350` (avsiktligt mörk) | `#FFFFFF` med färgband + vit innerskiva alpha 0,45 |
| Kontur/signal | `#FF5FA2` kontur (6,7:1) + vitglödande kärna `#FFF1CF` (11,1:1 mot kroppen) | vit kontur 0,10r |
| Ansikte | `angry` i `#FFF1CF` | `joy` i `ink` |
| Rörelse | hela silhuetten roterar 8°/s, skalpuls 1,00↔1,08 var 520 ms | banden roterar 150°/s (ett varv / 2,4 s), skalpuls 1,00↔1,05 var 640 ms |
| Varför den känns | rotation + taggar = "vass, farlig, rolig" utan blinkning | kontinuerlig rotation läser som "joker" och ger noll blinkfrekvens |

Ingen av dem blinkar: rörelsen är **kontinuerlig rotation och mjuk skalpuls**, aldrig ljusstyrkeväxling. Det håller flash-guard automatiskt.

Förhandsvisningen har dessutom en streckad ram som byter från `jarEdge` till `accent2` när ett specialobjekt ligger i kön – form + färg + rörelse, tre signaler.

---

## 5. Animationskurvor (`THEME.anim`)

`durationMs` för loopar = **halvcykel** (yoyo). Frekvens = 500 / durationMs Hz.

| Namn | Phaser-ease | Duration | Vad som ändras |
|---|---|---|---|
| `aim` | `Sine.easeOut` | 90 ms | x-position följer fingret (lerp, inte hårt lås) |
| `drop` | `Quad.easeIn` | 90 ms | skala 1,00 → 0,92 innan fysiken tar över, "spottas" nedåt |
| `queueSlide` | `Back.easeOut` | 220 ms | nästa objekt glider från förhandsvisning till drop-läget |
| `landSquash` | `Back.easeOut` | 180 ms | scaleY 0,86 → 1,00 vid första kontakt |
| `mergePunch` | `Back.easeOut` (overshoot 2,2) | 220 ms | skala 1,00 → 1,00 + 0,35·i → 1,00 på det NYA objektet |
| `neighborNudge` | `Sine.easeOut` | 160 ms | visuell knuff på grannarna, utöver fysikimpulsen |
| `scorePop` | `Cubic.easeIn` | 500 ms | siffran stiger 18 px, flyger till HUD, tonar ut sista 140 ms |
| `shake` | dämpad sinus | 300 ms | amplitud·e^(−t/90 ms)·sin(2π·28 Hz·t), tak 8 px, riktad från merge-punkten |
| `hitStop` | – | ≤100 ms | 0–6 frames frysning vid intensity ≥0,3 |
| `slowmoIn` | `Quart.easeOut` | 260 ms | timeScale 1,0 → 0,6 |
| `slowmoOut` | `Quart.easeIn` | 420 ms | timeScale 0,6 → 1,0 (längre ut än in = lättnad) |
| `buttonPress` | `Quad.easeOut` | 80 ms | skala 0,92 |
| `buttonRelease` | `Back.easeOut` | 160 ms | skala 1,00 |
| `zoom` | `Sine.easeInOut` | 400 ms | kamera 1,00 → 1,06 → 1,00, endast `chain` och `special` |
| `previewPulse` | `Sine.easeInOut` yoyo | 520 ms | skala 1,08 på specialobjekt (0,96 cykler/s) |
| `dangerPulse` | `Sine.easeInOut` yoyo | 500 ms | farolinjens alpha 0,55 ↔ 1,0 (1,0 cykel/s) |
| `recordPulse` | `Sine.easeInOut` yoyo | 700 ms | highscore-markören 1,12 (0,71 cykler/s) |
| `nearMiss` | `Sine.easeInOut` yoyo | 600 ms | de två objektens skala 1,03, synkront |
| `handLoop` | `Sine.easeInOut` | 2 200 ms | onboarding-gesten, se §7 |
| `overlayIn` | `Quad.easeOut` | 260 ms | förlust-scrim alpha 0 → 0,82 |
| `restart` | `Quad.easeIn` | 180 ms | overlay ut; total omstart <500 ms (DESIGN §1) |

---

## 6. Belöningsögonblicken – hur de ska SE och KÄNNAS olika

Kicktrappa (uppskattningar från PROPOSAL §2): liten kick var 2–5 s, medel var 20–60 s, stor var 2–5 min. Samma `juice.trigger(event, i)` men **olika kombinationer av kanaler** – det är kombinationen, inte styrkan, som gör att en jackpot inte känns som en stor vanlig merge.

| Ögonblick | Event, intensity | Bild | Ljud | Kropp |
|---|---|---|---|---|
| **Vanlig merge** (var 2–5 s) | `merge` 0,25–0,45 | punch 1,10, 8–12 partiklar i objektets kulör, scorepop | pling, pitch = bas | haptik 10 ms |
| **Combo 2–4** (var 10–30 s) | `merge` 0,5–0,7 | punch 1,20, 16 partiklar, lätt shake 3 px, kombo-prickar tänds i HUD | pitch +1 halvton per steg | 30 ms |
| **Kedja ≥3** (var 30–60 s) | `chain` 0,8 | punch 1,28, 30 partiklar, shake 6 px, **kamerazoom 1,06**, hit-stop 4 frames | fyrtons-arpeggio uppåt | 30 ms |
| **Sällsynt drop** (var 25–60 drops) | `special` 0,8–1,0 | förhandsvisningen byter form + ram till `accent2`, objektet pulsar hela vägen ner | glissando 440→1760 Hz med vibrato | 30 ms vid drop |
| **Bomb detonerar** | `special` 1,0 | ringvåg (en expanderande strokad cirkel, INTE en vitblixt), 40 partiklar, shake 8 px, zoom, hit-stop 6 frames | brus med nedåtsvepande lågpass + 60 Hz sub | 60 ms |
| **Jackpot: nivå 10 skapas / två nivå 10 möts** (var 3–5 min) | `newRecord`/`special` 1,0 | slow-mo 0,6× i 600 ms, guldringar expanderar, kronan glimmar, hela burken får en kort guldton (alpha, ingen blixt) | tre-tons fanfar + oktavskimmer | 60 ms |
| **Nytt rekord** | `newRecord` 0,9 | guldring runt poängen, highscore-markören slutar pulsa och fylls | fanfar | 60 ms |
| **Fara** | `danger` | farolinjen pulsar 1 Hz, slow-mo 0,6×, bilden desaturerar 15 % | dov 55 Hz sågtand, tremolo 4 Hz | – |
| **Near-miss** | – | två objekt (nivå ≥8) pulsar 1,03 synkront, 0,83 Hz | tyst | – |

Skillnaden i **kanalantal** är designen: vanlig merge = 3 kanaler (skala, partiklar, ljud). Kedja = 6 (+shake, zoom, hit-stop). Jackpot = 8 (+slow-mo, färgton) och är den enda som ändrar tiden. Tid är den dyraste resursen – använd den bara för jackpot och fara.

---

## 7. Skärmlayouter (logisk yta 360×640)

Burkens geometri, gemensam för Spel och Förlust (tolkning av DESIGN §3, godkänns av projektledare): **inre öppning 320 px bred, x 20 → 340**; väggarna 20 px ritas utanför (x 0–20 och 340–360); botten inre yta y = 600, bottenblock 600–620; burkens överkant y = 24; hörnradie 18.

### 7.1 Start

| Element | Koordinat | Not |
|---|---|---|
| Bakgrund | 0,0–360,640 | gradient `bg` → `bgDeep` + radial `bgGlow` vid (180, 330) r 320 |
| Logotyp `KLUNK` | baslinje y = 186, centrerad | 64 px/800, spacing 8. **`U`:et ritas som en burk** (stroke 9, rundade hörn, rimlinje ovanför) med en nivå-2-glimt i sig |
| Play-knapp | centrum (180, 330), r 56 | fylld `accent` alpha 0,12, kontur `accent` 4 px, ▶-ikon 64 px. Träffyta 112 px |
| Hylla | linje y = 470, x 80 → 280, konsoler 12 px | `jarEdge` 3 px |
| Bästa objekt | centrum (180, 436), r 34 | ritas med sin riktiga skin |
| Highscore | krona 26 px vid (140, 498) + siffra 28 px från x 172 | `gold` |
| Ikon ljud | centrum (100, 580) | träffyta 72×72, ikon 48 px |
| Ikon haptik | centrum (180, 580) | d:o |
| Ikon lugnt läge | centrum (260, 580) | d:o |

Ingen text utöver logotypen. Av-läge signaleras med `hudDim` + överkryssad ikon (form, inte bara färg).

### 7.2 Spel

| Element | Koordinat |
|---|---|
| Burk | enligt ovan; två reflexstreck (44,120)→(80,300) och (62,150)→(88,290), alpha 0,14 |
| Farolinje | y = 110, x 20 → 340. Streckad 12/10, 3 px, `danger`, plus nedåtriktade 7 px-tänder var 40:e px |
| Drop-linje (objektet hänger) | y = 64, x styrs av fingret, klampat till 20+r … 340−r |
| Siktlinje | från objektets underkant till y = 595, streckad 4/8, `accent` alpha 0,35 |
| Poäng | vänsterställd vid (16, 18), 34 px |
| Highscore-markör | krona 16 px vid (16, 57) + siffra 16 px från x 38, `gold` |
| Kombo-prickar | (22 + n·14, 86), r 4, `accent`, en per combosteg, max 12 |
| Förhandsvisning | centrum (302, 44), ram 72×72 streckad, hörnradie 14; objektet ritas med max radie 24 |
| Scorepop | startar vid merge-punkten, flyger till (16, 18) |

Förhandsvisningen ligger i burkens "hals" ovanför farolinjen och krockar aldrig med fysiken.

### 7.3 Förlust

| Element | Koordinat |
|---|---|
| Scrim | hela ytan, `scrim` alpha 0,82, in på 260 ms. Spelplanen syns svagt igenom |
| Poäng | centrerad (180, 190), 64 px, `hud` |
| Highscore | krona 24 px vid (132, 278) + siffra 24 px från x 164, `gold` |
| Guldring (endast nytt rekord) | cirkel centrum (180, 220) r 110, streckad 10/8, `gold` alpha 0,8 |
| Bästa objekt denna runda | centrum (180, 400), r 56 |
| Restart | replay-ikon 64 px vid (180, 530) + kontur r 44 i `accent` alpha 0,45, `recordPulse` |
| Träffyta | **hela skärmen** (DESIGN §7) – ikonen är bara en anvisning |

### 7.4 Onboarding utan text

Visas i Spel tills spelaren gjort sin första drop någonsin (`stats.runs === 0`), och igen om en runda passerar utan drop i 5 s.

```
t=0      hand-ikon (56 px) tonar in vid (150, 96), strecklinje 64 px under den
0–400    hand skalas 1,00 → 0,88 ("tryck"), objektet ovanför får buttonPress
400–1200 hand + objekt glider till x=230, Sine.easeInOut, strecket följer
1200–1600 hand glider till x=150
1600–1800 hand skalas 0,88 → 1,00 och tonar ut ("släpp"), objektet får drop-tween
1800–2200 paus, sedan loop
```

Tre saker en 7-åring ska ha lärt sig på 10 sekunder: (1) något hänger i toppen, (2) fingret flyttar det i sidled, (3) att lyfta fingret tappar det. Regissören garanterar en merge inom de första 10 dropsen (DESIGN §4), så steg fyra – "lika + lika = större" – lärs av spelet självt, inte av UI:t.

---

## 8. Ljudkarta (`THEME.sound`, allt genereras med Web Audio)

Mönster: `OscillatorNode` → (valfritt `BiquadFilterNode`) → `GainNode` (envelope) → master `GainNode` (0,5; 0,3 i Lugnt läge) → `DynamicsCompressorNode` (threshold −6 dB) → destination. Envelope: linjär ramp till topp på `attack`, exponentiell till 0,0001 på `decay`. AudioContext låses upp vid första pointerdown (TECH §Kodregler).

| Event | Vågform | Grundfrekvens | Attack / Decay | Karaktär |
|---|---|---|---|---|
| `drop` | triangel | 240 → 180 Hz glid | 2 ms / 90 ms | kort luftpuff när objektet släpps |
| `land` | sinus | 180 → 90 Hz glid, lågpass 900 Hz | 1 ms / 140 ms | **"klunk"** – nedåtglidet ÄR ljudet i titeln |
| `merge` | triangel + kvint (+7 halvtoner, gain 0,4) | 392 Hz (G4) | 4 ms / 180 ms | **Pitch = 392 · 2^(combo/12)**, combo kapas vid 12 = exakt en oktav. Kvinten gör det till ett "pling" i stället för en ren ton |
| `chain` | fyrkant, lågpass 2 600 Hz | 523 Hz (C5) | 3 ms / 160 ms | arpeggio 0/+4/+7/+12 halvtoner, 70 ms mellan stegen = hörbar kaskad |
| `special` | sinus | 440 → 1 760 Hz glid, vibrato 6 Hz / 35 cent | 10 ms / 500 ms | uppåtglissando = "något ovanligt kommer" |
| `bomb` | vitt brus + 60 Hz sinus-sub | lågpass sveper 3 200 → 200 Hz | 1 ms / 450 ms | "whump", inte fräs |
| `danger` | sågtand, lågpass 300 Hz | 55 Hz | 250 ms / 600 ms, **sustain** | dov tremolo 4 Hz, loopar medan faran pågår, gain 0,12 |
| `loss` | triangel | 330 → 110 Hz glid | 10 ms / 900 ms | nedåt, mjukt, aldrig bestraffande |
| `newRecord` | triangel + oktav (gain 0,25) | 659 Hz (E5) | 4 ms / 280 ms | fanfar 0/+5/+9 halvtoner, 110 ms mellan |
| `record` | sinus | 1 568 Hz | 2 ms / 70 ms | diskret puls vid ≥90 % av highscore, gain 0,14 |
| `ui` | sinus | 880 → 1 200 Hz | 1 ms / 50 ms | alla knapptryck |

Pitch-stegringen är den billigaste kicken i hela spelet (research §3) och är läsbar för den som inte kan läsa: **högre ton = du gör bättre ifrån dig.** Tonen nollställs synligt (kombo-prickarna släcks) samtidigt som den nollställs hörbart.

---

## 9. Ikoner

En stil: viewBox 64×64, stroke 6, rundade ändar och hörn, inga fyllningar utom `play` och `crown`. Levereras som strängar i `app/src/ui/icons.ts` och laddas som textur via data-URI vid boot.

```ts
export const ICONS = {
  play: (c = '#7CF9FF') =>
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64"><path d="M24 16 L48 32 L24 48 Z" fill="${c}" stroke="${c}" stroke-width="8" stroke-linejoin="round"/></svg>`,

  soundOn: (c = '#EAF2FF') =>
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" fill="none" stroke="${c}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"><path d="M12 25 H21 L32 15 V49 L21 39 H12 Z"/><path d="M41 24 a11 11 0 0 1 0 16"/><path d="M48 17 a20 20 0 0 1 0 30"/></svg>`,

  soundOff: (c = '#8FA3C8') =>
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" fill="none" stroke="${c}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"><path d="M12 25 H21 L32 15 V49 L21 39 H12 Z"/><path d="M42 25 L56 39 M56 25 L42 39"/></svg>`,

  hapticOn: (c = '#EAF2FF') =>
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" fill="none" stroke="${c}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"><rect x="23" y="12" width="18" height="40" rx="5"/><path d="M12 24 a12 12 0 0 0 0 16"/><path d="M52 24 a12 12 0 0 1 0 16"/></svg>`,

  hapticOff: (c = '#8FA3C8') =>
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" fill="none" stroke="${c}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"><rect x="23" y="12" width="18" height="40" rx="5"/><path d="M10 26 L18 38 M18 26 L10 38 M46 26 L54 38 M54 26 L46 38"/></svg>`,

  // Lugnt läge AV = taggig våg (full juice). PÅ = mjuk våg. Formen bär informationen.
  calmOff: (c = '#8FA3C8') =>
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" fill="none" stroke="${c}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"><circle cx="32" cy="32" r="22"/><path d="M14 32 L22 20 L28 42 L36 18 L42 40 L50 32"/></svg>`,

  calmOn: (c = '#7CF9FF') =>
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" fill="none" stroke="${c}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"><circle cx="32" cy="32" r="22"/><path d="M14 32 q 9 -12 18 0 q 9 12 18 0"/></svg>`,

  crown: (c = '#FFD75E') =>
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64"><path d="M10 46 L14 18 L26 30 L32 14 L38 30 L50 18 L54 46 Z" fill="${c}" stroke="${c}" stroke-width="6" stroke-linejoin="round"/></svg>`,

  replay: (c = '#7CF9FF') =>
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" fill="none" stroke="${c}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"><path d="M50 32 a18 18 0 1 1 -6.2 -13.6"/><path d="M52 12 V22 H42"/></svg>`,

  // Onboarding: hand med pekfinger. Rörelsen görs i tween, inte i ikonen.
  hand: (c = '#EAF2FF', ink = '#14202E') =>
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64"><path d="M26 40 V14 a5 5 0 0 1 10 0 v18 l4 1 a10 10 0 0 1 7 9 v6 a10 10 0 0 1 -10 10 h-8 a10 10 0 0 1 -8 -4 l-8 -11 a4 4 0 0 1 6 -5 l7 6 Z" fill="${c}" stroke="${ink}" stroke-width="4" stroke-linejoin="round"/></svg>`,

  // Rörelsespår under handen
  swipe: (c = '#7CF9FF') =>
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" fill="none" stroke="${c}" stroke-width="5" stroke-linecap="round" stroke-dasharray="2 9"><path d="M8 32 H56"/></svg>`,
}
```

Laddning: `'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg)` → `this.textures.addBase64` / `load.svg`. Alla ikoner är verifierade renderade i Chromium (se `docs/ui-preview.png`).

---

## 10. Tillgänglighet

1. **Kontrast.** All HUD-text ≥7:1 mot bakgrunden, alla objektkroppar ≥6,1:1 mot bakgrunden, alla ansikten ≥5,3:1 mot sin kropp. Tabellerna i §2.1 och §3 är uträknade enligt WCAG 2.x relativ luminans. Bombens kropp är medvetet mörk (1,5:1) – dess silhuett bärs av magenta kontur (6,7:1) och den ljusa kärnan (11,1:1).
2. **Aldrig bara färg.** Nivå = storlek + kulör + unikt ansikte (+ dekor). Fara = streckad linje med tänder + slow-mo + dov ton, inte "det blir rött". Avstängd inställning = överkryssad form + `hudDim`, inte bara nedtonad färg.
3. **Flash-guard (WCAG 2.3.1).** Inget element växlar ljusstyrka mer än 3 ggr/s; alla loopar i §5 ligger på 0,7–1,0 cykler/s. Vitblixtar: max 2/s – v1 använder **inga** vitblixtar alls, explosioner ritas som expanderande ringvågor och partiklar. Mättad röd blinkar aldrig; farolinjen är bärnsten `#FFB43A`. Testas i Playwright: sampla skärmens medelluminans 30 gånger/s under 10 s scriptad kaos-körning och kräv <3 nollgenomgångar/s.
4. **Lugnt läge** (`THEME.a11y.calm`): alla intensiteter ×0,5, shake **av**, zoom **av**, hit-stop och slow-mo kvar (de gör spelet läsbarare, inte stressigare), ljudets mastergain 0,5 → 0,3. Ikon på startskärmen, sparas i `settings.calm`.
5. **Motorik.** Ett finger, en gest. Alla mål ≥72 logiska px (≥64 dp). Ingen dubbeltryckning, ingen long-press, ingen tidsgräns i UI:t.
6. **Ljud är aldrig nödvändigt.** Combo syns som prickar i HUD, fara syns som puls och slow-mo, rekord syns som guldring.

---

## 11. Filer och ansvar

| Fil | Ägare | Innehåll |
|---|---|---|
| `docs/UI.md` | ui-designer | denna spec |
| `docs/ui-preview.png` | ui-designer | granskningsrendering (nivåark, spel, start, förlust) |
| `app/src/data/theme.ts` | ui-designer | alla tokens, `THEME` + `Theme`-typ, ingen Phaser-import |
| `app/src/data/levels.ts` | programmerare | radie, poäng, köregler (DESIGN §2) |
| `app/src/ui/icons.ts` | programmerare | klistra in §9 rakt av |
| `app/src/systems/juice.ts` | programmerare | läser `THEME.anim`, `THEME.haptics`, `THEME.a11y` |
| `app/src/systems/audio.ts` | programmerare | läser `THEME.sound` |
| `app/src/data/art.ts` | ui-designer | Art v2-parametrar (§15), ingen Phaser-import |
| `app/src/ui/artv2.ts` | ui-designer (referens) → programmerare kopplar | Canvas2D-renderare för nivåer och kompisar (§15.5) |

`theme.ts` är typkollad med `tsc --strict` (TS 6) och med projektets egen `app/tsconfig.json` utan fel.

**Ersätter `app/src/data/theme.fallback.ts`.** Filen exporterar en Phaser-brygga (inga Phaser-importer, bara tal):

| Fallback | Ersätts av |
|---|---|
| `COLORS` | `LEVEL_COLORS` (och `LEVEL_COLORS2` för konturer) |
| `BACKGROUND`, `CAN_COLOR`, `DANGER_COLOR` | `INT.bg`, `INT.jarWall` / `INT.jarGlass`, `INT.danger` |
| `TEXT_COLOR` | `THEME.palette.hud` (sträng, direkt till Phaser-text) |
| `EYE_COLOR`, `PUPIL_COLOR` | utgår – ögon ritas i `THEME.palette.ink`, se §3.1 |

Plus `hexToInt(hex)` för egna konverteringar. När `ui/textures.ts` och scenerna bytt kan `theme.fallback.ts` raderas.

### Öppna frågor till projektledaren
1. Burkens geometri i §7 (inre öppning 320 px, väggar ritade utanför x 0–20/340–360) är min tolkning av DESIGN §3 – bekräfta innan fysikkropparna byggs.
2. DESIGN §6 listar både `newRecord` och `record` som events; jag har tolkat `record` som den diskreta rekordjakt-pulsen vid ≥90 % och `newRecord` som själva passeringen.
3. Kosmetiska teman i v1.1 (PROPOSAL §5) bygger på att `THEME.levels` byts ut i sin helhet – strukturen är redan förberedd för det.

> Mobilverifiering: `docs/ui-preview-mobile.png` – spelskärmen med onboarding-handen, FIT-skalad i viewport 390×844 (Chromium, DPR 2).

---

## 12. Meta-lager v1.1

Underordnad DESIGN §13. Data: `app/src/data/themes.ts` (`THEME_SETS`, `SET_DECO_GEOM`, `META`, `META_SOUND`, `META_COLORS`, ikonsträngar). Granskningsbilder: `docs/ui-preview-sets.png` (5 set × nivå 0–10 + spelskärm per set), `docs/ui-preview-meta.png` (HUD-kedja, hylla, bok, rundavslut vid 1,2 s och 2,3 s), `docs/ui-preview-book-mobile.png` (boken FIT-skalad i 390×844, DPR 2, med 72 px-målet för stäng utritat).

**Känslan i en mening:** meta-lagret är *tyst tills det har något att säga*. I spel syns bara en liten rad siluetter. Allt stort händer efter rundan, ovanpå förlustskärmen, och det går alltid att trycka förbi.

### 12.1 Temaset

| # | id | Känsla (motivering) | Bakgrund | Dekorstil | `spotStyle` | Partikel | Klang |
|---|---|---|---|---|---|---|---|
| 0 | `glimtarna` | Neon mot svart hav. Basen som allt annat jämförs med. | `#0B1020` | spröt, tofs, tentakler, fenor | `dot` | `dot` (ADD) | triangel + kvint, "pling" |
| 1 | `planeterna` | Matta, dammiga planeter i violett stjärnmörker: lugnt och svävande i stället för elektriskt. | `#0E0B1F` | måne, antenn, **saturnusring**, raketfenor | `crater` | `star`, snurrar | 2 sinus med 9 cents chorus, lång svans, "uuu-blopp" |
| 2 | `frostisarna` | Nästan vita iskristaller under norrsken, med skarpa mörkblå konturer: kallt och krispigt, och ljudet klingar som glas. | `#081624` | **iskristaller**, **istappar**, isvingar | `flake` | `shard`, faller | sinus + deltoner +24/+31, "ting" |
| 3 | `godisarna` | Mättade sockerfärger i en plommonburk med strössel och papperssnurrar: poppigt och studsigt. | `#1A0B1F` | **karamellpapper**, **klubbpinne** | `sprinkle` | `bubble`, stiger | filtrerad fyrkant som glider upp 4 halvtoner, "blopp" |
| 4 | `gloden` | Vulkanstenar och kristaller på kolsvart botten med kopparglas: varmt, tungt och knastrande. | `#150C0B` | **lågor**, ångtofs, kristaller | `crack` | `ring` + glöd-`dot`, stiger | sågtand + sub-oktav, filtret sveper nedåt, knaster, "vomp" |

**Regler som gäller alla set**
- `face` kopieras alltid ur `THEME.levels` via `skin()` i themes.ts, så ansiktet är per konstruktion identiskt i alla set.
- Nivå 10 har alltid `ring` + `crown` och en guldton. "Kronan är toppen" ska gälla oavsett set.
- Bara burk- och bakgrundstokens byts (`SetPalette`: bg, bgDeep, bgGlow, jarGlass, jarWall, jarEdge, jarShine, floor). `danger`, `hud`, `hudDim`, `accent`, `accent2`, `gold`, `ink` och `scrim` byts **aldrig**. Det spelaren kan röra och det som varnar ser alltså likadant ut i alla set.
- Ingen mättad röd som huvudfärg. Magman i Glöden är korall `#FF8766`, glödkolet är bärnsten.

**Uppmätt kontrast** (WCAG relativ luminans, kropp mot både `bg` och burkens blandade glasfärg). Skriptet ligger i §12.9.

| Set | Ansikte/kropp min | Kropp/bakgrund min | jarEdge/bg | Minsta ΔE (Lab) mellan grannivåer |
|---|---|---|---|---|
| glimtarna | 5,3:1 | 5,6:1 | 5,6:1 | 30 |
| planeterna | 7,9:1 | 8,8:1 | 5,8:1 | 38 |
| frostisarna | 8,2:1 | 8,3:1 | 8,5:1 | 23 (0→1, avsiktligt bleka, men nivå 1 har iskristaller) |
| godisarna | 7,1:1 | 7,6:1 | 7,6:1 | 51 |
| gloden | 7,0:1 | 7,9:1 | 6,9:1 | 25 |

Krav: ansiktet ≥4,5:1, kroppen ≥3:1. Tumregel för nya färger: kroppens relativa luminans ska vara ≥0,24. Då klarar `ink` 4,5:1 automatiskt.

#### 12.1.1 Nya dekorer (`SET_DECO_GEOM`, enheter i r)

Geometrin ligger som **data**, så `textures.ts` behöver bara en generisk ritare: `tris` fylls och strokas, `strokes` och `back` är polylinjer och `dots` är fyllda cirklar. Samma tvåpass som §3.1 steg 7 gäller: först mörk understroke i `color2` med bredden `lw + max(2,5; 0,09r)`, sedan ljus fyllning eller överstroke i `color` med bredden `lw = max(2; widthR·r)` (default `widthR` 0,07). `back` ritas **före** kroppen (steg 1,5), allt annat efter. `extent` används för texturens pad.

| Dekor | Konstruktion | Set/nivå |
|---|---|---|
| `orbit` | lutad ellips, centrum (0; 0,30), rx 1,42, ry 0,34, lutning −0,16 rad. Bakre halvan före kroppen, främre efter. Främre bågen passerar kroppskanten vid y ≈ 0,54r, alltså under munnen | Planeterna 6 |
| `moon` | cirkel (0,92; −0,90) r 0,20 + (−1,08; −0,50) r 0,10 | Planeterna 1 |
| `shards` | 3 taggar från 0,90r, vinklar −0,42/0/0,38 rad, spetsar 1,30/1,46/1,34, halvbas 0,10 | Frost 1 och 6, Glöden 6 |
| `icicles` | 3 taggar nedåt (π−0,45 / π−0,08 / π+0,32), spetsar 1,28/1,36/1,24 | Frost 4 |
| `wrapper` | trianglar (±0,90; 0) → (±1,42; ∓0,38) → (±1,42; ±0,38) | Godis 3 och 6 |
| `stick` | linje (0; 0,96) → (0; 1,48), `widthR` 0,16 | Godis 1 och 7 |
| `flames` | 3 taggar med sidolut 0,12–0,14, halvbas 0,16–0,18, spetsar 1,28/1,44/1,30 | Glöden 3 och 7 |

`SetLevelSkin.deco` har typen `SetDeco = Deco | NewDeco`. `theme.ts` rörs inte, så `DECO_EXTENT` i textures.ts kan läsa `SET_DECO_GEOM[d].extent` för de nya dekorerna.

#### 12.1.2 `spotStyle` (ersätter steg 5 i §3.1 per set)

Positionerna är desamma som idag (vinkel `i/n·2π + 0,7`, avstånd 0,46r ± 0,16r). Färg alltid `color2`.

| Stil | Ritning |
|---|---|
| `dot` | som idag: fylld cirkel 0,11r, alpha 0,32 |
| `crater` | fylld 0,12r alpha 0,18 + stroke 0,045r alpha 0,45 |
| `flake` | 3 streck genom punkten, var 60°, halvlängd 0,10r, bredd max(1; 0,035r), alpha 0,45 |
| `sprinkle` | ett streck, halvlängd 0,10r, vinkel a+0,9, bredd max(1,5; 0,07r), runda ändar, alpha 0,5 |
| `crack` | sicksack (−0,12; 0,04) → (−0,04; −0,04) → (0,04; 0,04) → (0,12; −0,04), roterad a, bredd max(1; 0,04r), alpha 0,45 |

#### 12.1.3 Partiklar (`ThemeSet.particle`)

Bakas en gång som vita 16×16-texturer som tintas: `fx-dot` (finns), `fx-p-star` (fyrudds-stjärna, spetsradie 7 och innerradie 2), `fx-p-shard` (triangel (8,0), (10,5; 16), (5,5; 16)), `fx-p-bubble` (stroke r 6, bredd 1,6, plus högdager r 1,6 vid (5,5; 5,5)), `fx-p-ring` (stroke r 6,5, bredd 2,4). Antalet blir `(6 + 24·i) · countScale` med taket 40 kvar. `mix` delar upp utbrottet: Glödens 60 % glöd-prickar stiger långsammare än rökringarna. `tint: 'levelLight'` betyder att varannan partikel ritas i `hud`-vit. Det gör skärvorna och stjärnorna "glittriga" utan att något blinkar.

#### 12.1.4 Bakgrund (`ThemeSet.backdrop`)

Primitiverna `circle`, `ellipse`, `poly`, `curve`, `line` och `scatter` (seedad mulberry32) ritas i ordning till **en** RenderTexture 360×640 vid rundstart, efter gradient + `bg-glow`. `scatter` med `vy` ritas i stället som eget lager som flyttas och wrappar i y (snö faller 8 px/s, bubblor och glöd stiger 10–12 px/s, vaggning ≤0,4 Hz). Alla färger är valda så att den lokala bakgrundsluminansen stannar under ≈0,03, och det håller kontrasten i §12.1. I Lugnt läge är rörelselagren stilla.

#### 12.1.5 Klangfärg (`ThemeSet.sound`)

Pitch-logiken är oförändrad (392 Hz · 2^(combo/12), tak 12). Bara klangen byts. Ljudkedja: ett `OscillatorNode` per `layers[i]` (frekvens `f·2^(semitones/12)`, `detune` i cent, egen gain) → summa → valfritt `BiquadFilter` lågpass (`lowpassHz`, `lowpassQ`, ramp till `lowpassToHz` över decay) → envelope (`attack`/`decay`, toppvärde `gain`) → master. `bendSemitones`/`bendMs`: starta så många halvtoner under och glid exponentiellt upp till `f`. `noise`: kort brusbuffert genom lågpass, parallellt. Gains är satta så att seten upplevs lika starka. Justera på gehör, men behåll relationerna mellan dem.

### 12.2 Kedjan i HUD (DESIGN §13.1)

Känsla: "en rad klistermärken du fyller under rundan". Liten kick, aldrig i vägen.

| | Värde (`META.chain`) |
|---|---|
| Position | vänsterställd under highscore-markören: centrum x = 25 + 18·k, y = 78 |
| Storlek | kroppsradie 5,0 + 0,35·k (5,0 → 8,5 px). **Storleken växer med nivån**, alltså samma signal som i burken. Dekoren syns i siluetten |
| Bredd | x 20 → 213. Krockar inte med förhandsvisningen (x ≥ 266) |
| Combo-prickar | **flyttas** från y 86 till y 97 (r 4, samma x) |
| Tänd | nivåns riktiga textur i aktivt set, skalad till radien ovan |
| Mörk (skapad förut, inte i denna runda) | siluett i `META_COLORS.silhouette` `#56688F` (3,4:1 mot bg) |
| "?" (aldrig skapad, `stats.createdPerLevel[k] === 0`) | mörk siluett + "?" 10 px/800 i `#EAF2FF`, 1 px kant i `bg` (4,9:1 mot siluetten) |
| Nivå 0 | alltid tänd (den kan inte skapas genom merge) |
| Skimrande skapad i rundan | platsen får en statisk mini-glitterring (r·1,28, ingen puls i HUD) |
| Målpuls | nästa "?" ovanför högsta tända nivå andas: skala 1,00 ↔ 1,12, halvcykel 1 000 ms (0,5 Hz). Bara en plats åt gången |
| Undanflyttning | när det hängande objektets bredd överlappar raden (x ≤ 213 + r): alpha 1 → 0,35 på 120 ms, tillbaka på 200 ms. Siktet är viktigare än HUD |
| Allra första rundan | raden tonas in (300 ms) vid rundans första merge, så att den inte stör 10-sekunders-onboardingen |

**Tändning** (när nivå k skapas för första gången i rundan):
```
t+0     vänta 80 ms (efter hit-stop), flera tändningar i samma kedja: 90 ms isär
t+80    textur byts siluett → tänd; scale 0,6 → 1,30 (90 ms Quad.easeOut) → 1,00 (160 ms Back.easeOut)
t+80    FX_RING i nivåns färg: r → 2,4r, alpha 0,9 → 0, 320 ms Cubic.easeOut
        ljud: META_SOUND.chainLight, playTone(def, CHAIN_STEPS[k])   (pentatoniskt, 60 ms efter merge-ljudet)
om "?"  "?" krymper till 0 på 120 ms; ringen dubbleras (andra 100 ms senare);
        3 partiklar i setets form; ljud chainFirst (med kvint)
```

**Reservvärden som ersätts:** `COLLECTION_FX.chain` i `data/collection.ts` (centrerad rad vid y 88 och storlek 20) krockar med combo-prickarna och förhandsvisningens ram (y 8–80). Använd `META.chain`.

### 12.3 Skimrande i spel (DESIGN §13.2)

Känsla: "den här är speciell". Den ska synas i periferin utan att dra blicken hela tiden.

- Ett glitterring-sprite (`FX_GLITTER`, finns redan i textures.ts) följer kroppen varje frame. Skala = r·1,28 / FX_GLITTER_R. Ringen snurrar **kontinuerligt** 30°/s, oberoende av kroppens rotation.
- Puls: ringens alpha 0,55 ↔ 1,0 och skala ±6 %, synkront, halvcykel 600 ms (0,83 Hz), Sine.easeInOut. **Kroppen själv ändrar aldrig ljusstyrka eller skala.**
- Vid skapandet ploppar ringen in med scale 0 → 1 på 260 ms (Back.easeOut). 6 guldstjärnor (`fx-p-star`, tint `gold`/vit) oavsett set: guldgnistor är det universella "skimrande"-språket. Ljud: `META_SOUND.shinyCreate`, en kvint över merge-tonen (`playTone(def, combo)`), 70 ms efter. Juice-intensiteten +0,2 på mergen (`shinyIntensityBonus`). Ingen extra shake.
- Skimrande är **inte ärftligt**. När en skimrande slås ihop släpps ringen tillbaka till poolen och det nya objektet slår sin egen tärning.
- Värdena i `META.shiny` är desamma som programmerarnas `COLLECTION_FX.glitter`. De är godkända.

### 12.4 Samlarboken och hyllan (DESIGN §13.2)

Känsla: "min pärm". Lugn, ordnad, inga effekter utom det som är nytt.

**Ingång från startskärmen** (`META.shelf`): hyllan får en **bok-ikon** (48 px, `accent` = tryckbar) som står på hyllan vid (238, 444). Bästa objektet flyttas till (156, 436), r 34, och ritas i **aktivt sets** skinn. Så syns det valda setet på startskärmen utan text. **Hela hyllan** (x 80–280, y 396–484) är träffytan. Finns något nytt i boken: guldprick r 6 vid (258, 422) och bok-ikonen andas 1,00 ↔ 1,08 i 0,5 Hz. Stapeln mot nästa set ligger på y 526, x 110–250, 6 px hög, med en "?"-ikon på 22 px vid (268, 526). Den döljs när alla 5 set är upplåsta.

**En sida (360×640, `META.book`)**

| Element | Position och utseende |
|---|---|
| Bakgrund | setets gradient + backdrop (stilla) + `bg` alpha 0,35 över, för läsbarhet |
| Stäng | ikon 48 px vid (320, 44), träffyta 72×72. Androids bakåtknapp gör samma sak |
| Setikon | 56 px vid (180, 58) |
| Aktivt set | heldragen ring r 38, 4 px, `accent` + bock-bricka r 10 vid (207, 31) (fylld `accent`, bock i `ink`) |
| Upplåst men inte aktivt | streckad ring r 38, 6/6, `hudDim`, ingen bricka. **Form (hel/streckad + bock) bär informationen, inte färgen** |
| Mätare | `x/22` 24 px/800 vid (180, 118) |
| Vanliga | 11 platser, rader y 178/246/314. Kolumner x 72/144/216/288 och sista raden x 108/180/252 (4-4-3, nivå 0–3, 4–7, 8–10) |
| Avdelare | y 354: linje i `jarWall` x 40–160 och 200–320, gnista 22 px `gold` i mitten |
| Skimrande | samma rutnät på rader y 394/462/530 |
| Objektstorlek | kroppsradie 14 + k (14 → 24). Storleken bär nivån även här |
| Fångad | riktig textur. Skimrande: textur + glitterring som snurrar 20°/s **utan puls** |
| Ej fångad | setets siluett (med dekor) i `hudDim`, alpha **0,25**. Skimrande plats: dessutom streckad ring r·1,28 alpha 0,25, så att man ser att det finns en skimrande plats där |
| Nytt sedan sist | skalpuls 1,00 ↔ 1,10, 0,5 Hz, tills platsen har synts i 2 s |
| Sidindikator | y 574, 5 punkter med 22 px mellanrum. Aktuell sida: r 6 `hud`. Upplåst: r 4 fylld `hudDim`. Låst: r 4 **ring** `hudDim`. Aktivt set: extra ring r 9,5 runt punkten |
| Stapel mot nästa set | y 604, x 64–282, 8 px, spår `barTrack`, fyllning `barFill`, "?"-ikon 28 px vid (304, 604) |

**Låst sida:** Glimtarnas bakgrund utan backdrop, `QMARK_ICON` i stället för setikonen och ingen ring. Rutnätet visar **enkla cirklar** (ingen dekor), så att det inte avslöjar vilket set som kommer. Upplåsningsordningen slumpas och alla låsta sidor ser likadana ut. Sidordning: upplästa set i den ordning de låstes upp, sedan de låsta.

**Svep** (`META.book.swipe`): sidorna ligger i en container med 360 px mellanrum och följer fingret 1:1. Byt sida om |dx| > 60 px eller hastigheten är > 0,45 px/ms: 240 ms Cubic.easeOut plus `pageTurn`-ljud. Annars snäpp tillbaka på 180 ms Back.easeOut. I kanterna gummiband med faktor 0,35. **Första öppningen någonsin:** efter 500 ms glider sidan 36 px åt vänster och tillbaka (600 ms Sine.easeInOut). Det är svep-ledtråden, utan text.

**Välja set:** tryck (< 12 px rörelse, < 350 ms) var som helst på sidan utom stäng.
- Upplåst och inte aktivt: ringen ritas in som båge 0 → 360° på 240 ms (Cubic.easeOut), brickan ploppar in (200 ms Back.easeOut), setets egen merge-klang spelar ett arpeggio 0/+4/+7 med 90 ms mellanrum och haptik 10 ms. Det gamla setets ring blir streckad. Bytet gäller från nästa runda (DESIGN §13.3).
- Låst sida: sidan skakar ±6 px två gånger på 240 ms, ljudet `locked` spelas och stapeln pulsar 1,0 → 1,1 → 1,0 (300 ms). Det är ett "inte än, så här når du dit". Tonen är aldrig bestraffande.

Boken öppnas på den sida som har något nytt, annars på aktivt set.

**Texturer:** baka aktivt set i full storlek vid rundstart (`ball-{setId}-{level}`), och Glimtarna direkt vid boot. Bokens sidor bakas i boksstorlek (r ≤ 24) när boken öppnas. Minnet stannar då runt dagens nivå. Siluetter bör bakas i **vitt** och tintas: `silhouette` i HUD, `hudDim` i boken. Programmerarnas `sil-*` bakas i dag i `hudDim`, och tint multiplicerar, så vitt behövs för att båda nyanserna ska gå att nå.

### 12.5 Rundavslut "nytt!" (DESIGN §13.4)

Känsla: "skörden". Medelstor kick som staplas: varje landning är ett litet pling, stapeln är löftet och ett nytt set är jackpotten. Allt ligger **ovanpå** förlustskärmen, inget är interaktivt, och helskärmszonen för omstart är aktiv från t = 0. Ett tryck gör `scene.start('Game')` direkt, vilket dödar alla tweens. Det som hoppades över markeras som "nytt sedan sist" i boken (§12.4).

Strip (`META.reveal`): bok 56 px vid (148, 56), mätaren `x/22` 24 px vänsterställd från x 178, y 56, stapeln på y 94 (x 110–250, 6 px) och "?" 20 px vid (268, 94). Allt ligger ovanför poängen (y ≥ 158) och innanför rekordringens överkant (y 110).

| t (ms) | Händelse | Ease | Ljud/haptik |
|---|---|---|---|
| 0 | `overlayIn` + poäng, highscore, bästa objekt och omstart (befintligt) | – | `loss` |
| 200 | Strip in: boken scale 0 → 1 (220 ms), mätaren och stapeln tonas in med **gamla** värden | Back.easeOut | – |
| 420 + i·160 | Flygare i (max 6) lyfter från sin kedjeplats (25 + 18k, 78), kvadratisk bezier via (mitt-x, 18) till boken, 420 ms. Radie: kedjeradie → 16 (mitten) → 6. Skimrande har glitterringen med sig | Sine.easeInOut | – |
| ankomst i | boken punchar 1,18 (180 ms), mätaren +1 punchar 1,25, skimrande: 4 guldgnistor | Back.easeOut | `catch` / `shinyCatch`, `playTone(def, CATCH_STEPS[i])`, haptik 10 ms |
| fler än 6 fångster | flygare 6 bär resten som en hög: mätaren hoppar +n direkt vid ankomsten | – | ett `catch` |
| sista ankomst + 80 | stapeln fylls från gammalt till nytt värde, 360 ms | Quad.easeOut | – |
| **om nytt set** | stripen tonas till 0 (200 ms), setikonen 72 px vid (180, 76) scale 0 → 1 (300 ms, overshoot 2), 3 guldringar r 36 → 80 (640 ms, 120 ms isär, alpha 0,85 → 0), 24 partiklar i setets form och färger, `jackpot`-juice 0,9 **utan** shake, zoom och hit-stop | Back.easeOut / Cubic.easeOut | `newSet`-fanfar, efter 520 ms setets egen merge-klang på 392 och 587 Hz (120 ms isär), haptik 60 ms |
| ≤ 2 500 | Allt är klart. Stripen och ikonen ligger kvar statiska tills tryck | – | – |

**Tidsbudget.** Utan nytt set, 6 flygare: 420 + 5·160 + 420 + 80 + 360 = 2 080 ms. Med nytt set komprimeras flygarna (`flyersFast`: 110 ms isär, 340 ms flygtid, stapeln 200 ms): 420 + 550 + 340 + 80 + 200 = 1 590 ms, plus sista ringen 240 + 640, totalt 2 470 ms. Hoppa över allt som inte har hänt: ingen fångst ger bara stapeln (klar vid ≈ 800 ms). Alla set upplåsta och inget nytt ger ingen strip alls.

Varför flygarna startar i HUD-kedjan: spelaren såg dem tändas under rundan. När de lyfter från samma plats blir sambandet "det jag gjorde → min bok" synligt utan text.

Lugnt läge: 1 ring i stället för 3, halva antalet partiklar, haptik 10 ms.

### 12.6 Ikoner (`themes.ts`, samma stil som §9: viewBox 64, stroke 6, rundade ändar, 48 px i 72 px mål)

| Ikon | Export | Färg | Form |
|---|---|---|---|
| Bok | `BOOK_ICON(c)` | `accent` (tryckbar) | uppslagen bok + fylld glimt på högersidan |
| Stäng | `CLOSE_ICON(c)` = `ICONS.close` (finns redan) | `accent` | X |
| "?"-siluett | `QMARK_ICON(fill, edge, mark)` | `silhouette` / `hudDim` / `hud` | cirkel r 24 + frågetecken (stroke) + prick |
| Skimrande | `SPARKLE_ICON(c)` | `gold` | fylld fyrudds-gnista |
| Set 0–4 | `THEME_SETS[i].icon` | setets signatur + mörk kontur | manet med tentakler / ringplanet / snöflinga (6 armar med V-grenar, mörk understroke) / karamell med papper / låga med vit kärna |

Setikonerna är tvåfärgade och fyllda, precis som objekten: signaturfärgen har 8,1–15,3:1 mot bg och den mörka kanten skiljer ikonen från bakgrunden. De renderas i `docs/ui-preview-sets.png` (vänsterkolumnen). Lägg till nycklarna i `ICON_KEYS` och ladda dem som vanliga ikontexturer.

### 12.7 Ljud för meta-lagret (`META_SOUND`, form som `ToneDef` → `playTone`)

| Ljud | Vågform | Frekvens | A/D (s) | Karaktär |
|---|---|---|---|---|
| `chainLight` | sinus | 523 Hz + `CHAIN_STEPS[k]` (pentatoniskt, upp till 2 093 Hz) | 0,002 / 0,09 | tyst pling under merge-ljudet, gain 0,10, 60 ms fördröjning |
| `chainFirst` | sinus + kvint | d:o | 0,002 / 0,16 | "?" tänds: samma pling fast öppnare |
| `shinyCreate` | triangel + oktav, vibrato 7 Hz / 15 cent | 587 Hz · 2^(combo/12) = **kvint över merge-tonen** | 0,004 / 0,42 | skimrande svans efter merge-plinget |
| `catch` | triangel + oktav | 1 047 Hz + `CATCH_STEPS[i]` | 0,003 / 0,12 | stigande "mynt" per landning |
| `shinyCatch` | triangel + kvint, vibrato | d:o | 0,003 / 0,30 | samma trappa med skimmer |
| `newSet` | triangel + oktav, arpeggio 0/4/7/12/16, 90 ms | 523 Hz | 0,004 / 0,32 | fanfar, därefter setets egen klang ("hör den nya världen") |
| `pageTurn` | sinus 900 → 620 Hz | – | 0,001 / 0,07 | "fwip" |
| `locked` | triangel 330 → 247 Hz | – | 0,004 / 0,14 | mjukt "inte än" |

`playTone` i audio.ts hanterar redan `baseHz`, `harmonicSemitones`, `delayMs`, `glideTo`, `vibrato*` och transponering (via `tone()`). Bara `steps` (newSet) saknas och behöver samma gren som i `playSound`.

### 12.8 Tillgänglighet och flash-guard

- Alla nya loopar går på 0,5–0,83 Hz: målpuls 0,5, "nytt"-puls 0,5, bokens bricka 0,5 och glitter 0,83. Rotation och rörelse är kontinuerliga. Inga vitblixtar. Guldringar och `FX_RING` är expanderande streck som tonas ut en gång.
- Ingen information bärs enbart av färg: tänd kontra mörk (textur med ansikte mot siluett), "?" (glyf), aktivt set (hel ring + bock mot streckad), låst sida (ring-punkt mot fylld, "?"-ikon), skimrande (glitterringens form + gnistor).
- Ljud är aldrig nödvändigt: varje ljud i §12.7 har en bildmotsvarighet.
- Lägg till `META.chain.goalPulse`, `META.book.freshPulse` och `META.shiny.halfCycleMs` i `JUICE.pulseHalfCycleMs` så att flash-guard-testet täcker dem.

### 12.9 Kontrastkontroll

```js
// L = WCAG relativ luminans; cr(a,b) = (max+0,05)/(min+0,05)
for (const s of THEME_SETS) for (const l of s.levels) {
  assert(cr('#14202E', l.color) >= 4.5)           // ansikte mot kropp
  assert(cr(l.color, (s.palette ?? THEME.palette).bg) >= 3) // kropp mot bakgrund
  assert(l.face === THEME.levels[l.id].face)       // ansikten identiska
}
```
Det passar som enhetstest (`tests/unit/themes.test.ts`). Programmerarna äger testfilerna.

### 12.10 Öppna frågor

1. **Kedjan tänds bara av merge?** Jag har tolkat "skapats i rundan" som merge och regnbåge, samma som fångst. Nivå 0 är alltid tänd. Om droppar från kön också ska tända nivå 1–4 blir kedjan fullare men mindre värd.
2. **"Nytt sedan sist"** kräver en flagga per plats i sparfilen, t.ex. `collection[setId].fresh: boolean[22]` plus `freshSet: string | null`. Det saknas i DESIGN §13.2:s sparformat.
3. **Combo-prickarna flyttas** från y 86 till y 97 (§12.2). Det är en liten ändring i Game.ts som programmerarna gör.
4. **Stapeln** visar bara tidsspåret (merges mot nästa tröskel). Skicklighetsspåret (första nivå 8 osv.) förblir en överraskning. Bekräfta att det är avsikten.
5. **Frostisarna** har medvetet låg kulörskillnad mellan nivå 0 och 1 (ΔE 23). Storlek, ansikte och iskristallerna bär skillnaden. Speltesta med barn innan det låses.

---

## 13. Kompisar v1.2

Underordnad DESIGN §14. Data och tillgångar: `app/src/data/avatars.ts` (ersätter `avatars.stub.ts`, samma exportnamn och nycklar: `AVATARS`, `RARITY`, `UPGRADE`, `Rarity`, `AvatarDef`). Dessutom `AVATAR_UI` (layout och tider), `AVATAR_SOUND`, `AVATAR_PARTICLE_GEOM`, `oddsPearls()`, `avatarById()` och ikonsträngarna. Ren TS utan Phaser, typkollad med `app/tsconfig.json`. Granskningsbild: `docs/ui-preview-avatars.png`, Canvas2D i Chromium med samma primitivsemantik som nedan.

**Känslan i en mening:** en kompis är *någon som håller i din boll*. Den syns hela rundan, gör små saker när du gör saker och tar aldrig över skärmen. Raritet märks på vad den **kan**, inte på hur mycket den blinkar.

### 13.1 Figurerna (48 st)

**Stil (skiljer kompisar från glimtar på en blick):**
- Egen kropp med armar, vantar, öron, hattar och fenor. Glimtarna är klot.
- Mörk kontur `edge` 2,8 box-enheter, platt fyllning och ett vitt topp-ljus med alpha 0,26, alltså samma familj som objekten.
- **Vitt ljusglint i varje öga.** Objekten har aldrig glint. Det är det tysta tecknet för "levande kompis".
- Ansikten i `ink`. Undantag: Stjärnvalen, som har mörk kropp, får ljusa drag `#FFF4C0` (4,8:1) och ljus kontur.
- Palett per figur, aldrig mättad röd. Krabban är korall `#FF9A6B` och magneten rosa `#FF6FA8`.

**Ritgrammatik (`AvatarOp`, 56×56-box, origo i mitten, y nedåt):**

| op | Ritas som | Not |
|---|---|---|
| `circle`, `ellipse` | fyllning (`color`, `alpha`), sedan `edge` som streck ovanpå (`edgeW`, default 2,8) | `stroke` satt ⇒ bara streck. `ellipse.rot` i radianer (rita som 24-punktspolygon) |
| `poly` | fylld polygon + `edge` | `open` + `stroke` ⇒ polylinje |
| `curve` | kvadratisk bezier, runda ändar | `edge` ⇒ underlag först med bredd `width + 2·edgeW` (tvåpass som §3.1 steg 7) |
| `line` | rakt streck | som `curve` |
| `scatter` | seedad mulberry32 som `background.ts` | används sparsamt |
| `noSil: true` | tas inte med i siluetten | gnistor, ekon, glöd |

Alla mått, även linjebredder, skalas med `displayPx / 56`. Baka **en textur per figur och storlek** vid behov: 40 px i spel, 40 px i boken, 80 px på scenen, 112 px i öppningen och 30 px vid rekordet. Lägg 2 box-enheter pad för konturen. Siluetten bakas i **vitt** utan `noSil`-lagren, med alla alpha = 1, och tintas: `hudDim` alpha 0,25 i boken, som §12.4.

**Greppunkten** är (0, 24) i boxen. `setOrigin(0.5, AVATAR_ORIGIN_Y)` med `AVATAR_ORIGIN_Y` = 52/56 ≈ 0,929. Positionen är då greppunkten, och rotation och squash sker kring den, alltså kring det figuren håller i. Alla figurer har vantar, fenor, tentakler eller snöre vid (±9, 22,4).

**Rörelserecept (`AnimRecipe`):** en lista med `TweenStep` där varje steg har målvärden relativt viloläget:
- `dx`/`dy` i box-enheter · skala, `sx`/`sy` som multiplikatorer och `rot` i grader.
- Ett värde som saknas betyder vila (0 eller 1). Ett steg med bara `ms`/`ease` går alltså tillbaka till vila.
- |rot| ≥ 360 är en hel snurr: nollställ vinkeln efter steget.

Stegen spelas i följd och `loop` upprepar hela listan. Personligheterna (`bouncy`, `floaty`, `heavy`, `zippy`, `springy`, `stately`) sätter standardrecepten, och varje figur byter ut 0–2 av dem.

| Trigger | Recept | Prioritet |
|---|---|---|
| objektet hänger | `idle` (loop, ≤1 Hz) | lägst |
| drop | `drop` (en gång) eller `cosmetic.gesture` om `on: 'drop'` | 2 |
| merge | `merge`. Hoppas över om `merge`/`chain` redan spelas | 3 |
| kedja ≥3 | `chain`, avbryter merge | 4 |
| fara | `danger` (loop, ≤1 Hz) ersätter `idle`. Ut: 200 ms Sine.easeOut till vila | loop |
| `cosmetic.gesture.on` = land/combo3/record/klunk/newLevel | gestens recept | 3 |

**Alla 48** (genererat ur `avatars.ts`):

| id | Namn | Raritet | Känsla | Kosmetik / förmåga |
|---|---|---|---|---|
| `common-1` | Snäckan Sigge | Vanlig | Liten havssnäcka som bär sitt hus: långsam, trygg, lämnar pärlor efter sig. | spår dot, ljud land |
| `common-2` | Maneten Molly | Vanlig | Svävande manet: allt hon gör är mjukt och långsamt, som i vatten. | spår bubble |
| `common-3` | Krabban Krille | Vanlig | Kaxig liten krabba som klickar med klorna varje gång han släpper. | ljud drop, gest vid drop |
| `common-4` | Sjöstjärnan Stina | Vanlig | Glad sjöstjärna som gör varje merge till en liten stjärnregn. | partikel star |
| `common-5` | Bläckfisken Bosse | Vanlig | Mjuk bläckfisk med åtta armar i luften – sprutar lila bläckprickar av glädje. | partikel drop |
| `common-6` | Fisken Fenja | Vanlig | Nyfiken fisk som aldrig tar ögonen från det du släpper. | spår bubble, ögon följer |
| `common-7` | Pingvinen Pim | Vanlig | Pingvin i stickad mössa som nickar belåtet efter varje släpp. | ljud drop, gest vid drop |
| `common-8` | Grodan Gurra | Vanlig | Bred glad groda som kväker när det går bra (combo 3). | ljud combo3, gest vid combo3 |
| `common-9` | Sälen Selma | Vanlig | Sälen som balanserar bollar – hon är född till att hålla saker. | ljud merge, gest vid merge |
| `common-10` | Musen Mio | Vanlig | Pigg mus med stora öron som piper när något landar. | ljud land, gest vid land |
| `common-11` | Snigeln Sally | Vanlig | Långsam snigel som lämnar ett glittrande slemspår efter allt hon släpper. | spår dot |
| `common-12` | Humlan Humle | Vanlig | Rund humla som surrar till när hon släpper. | ljud drop |
| `common-13` | Blåsfisken Puff | Vanlig | Taggig blåsfisk som blåser upp sig av förtjusning vid varje merge. | gest vid merge |
| `common-14` | Sköldpaddan Tuss | Vanlig | Lugn sköldpadda – ingenting stressar henne, inte ens fara. | ljud land, gest vid drop |
| `common-15` | Räkan Räkel | Vanlig | Spralligt böjd räka med långa spröt som darrar av iver. | gest vid merge |
| `common-16` | Sjöborren Borre | Vanlig | Taggig men snäll sjöborre – ser farlig ut, är världens mjukaste. | partikel shard |
| `uncommon-1` | Sjöhästen Harry | Ovanlig | Stolt sjöhäst som håller objektet med svansen; partiklarna skiftar färg med combon. | spår dot, partikel dot (combofärg) |
| `uncommon-2` | Kometen Kim | Ovanlig | En liten komet: allt han släpper får en eldsvans. | spår dot, ljud drop |
| `uncommon-3` | Snögubben Snö | Ovanlig | Snögubbe som får det att snöa och frosta i kanterna vid merge. | spår dot, partikel star, ljud merge |
| `uncommon-4` | Robotten Bip | Ovanlig | Liten robot: alla merge-ljud blir robotpip i skala. | partikel confetti, ljud merge |
| `uncommon-5` | Draken Dunder | Ovanlig | Liten drake som puffar rök när han släpper – aldrig eld, bara puff. | spår ring, ljud drop, gest vid drop |
| `uncommon-6` | Katten Kurre | Ovanlig | Randig katt som spinner när kedjan i HUD tänds. | partikel heart, ljud newLevel, gest vid newLevel |
| `uncommon-7` | Ballongen Bella | Ovanlig | Ballong som håller objektet i snöret och släpper konfetti när rekordet närmar sig. | partikel confetti, ljud record, gest vid record |
| `uncommon-8` | Pirat-Pelle | Ovanlig | Pirat med lapp för ögat: "Arrr!" och en skattkista-gest vid Klunk. | partikel star, ljud klunk, gest vid klunk |
| `uncommon-9` | Spöket Svischa | Ovanlig | Snällt spöke: allt hon släpper lämnar genomskinliga efterbilder. | spår dot, ljud drop |
| `uncommon-10` | Trumslagaren Trumma | Ovanlig | Levande trumma: varje drop är ett trumslag och combon bygger takten. | ljud drop, gest vid drop |
| `uncommon-11` | Narvalen Nisse | Ovanlig | Narval med spiralhorn som sjunger en liten valsång vid kedjor. | partikel bubble, ljud chain |
| `uncommon-12` | Axolotln Axel | Ovanlig | Ständigt leende axolotl vars gälar fladdrar när något landar. | partikel heart, ljud land, gest vid land |
| `muller` | Åskmolnet Muller | Sällsynt | Buttert åskmoln som mullrar till och slår små blixtar när kedjan går. | **thunderChain** · partikel bolt |
| `maestro` | Dirigenten Maestro | Sällsynt | Liten fågeldirigent med taktpinne: combon spelar en riktig melodi. | **comboMelody** · partikel note |
| `tick` | Tidsugglan Tick | Sällsynt | Uggla med klockögon: faran blir sepiatonad och tickar lugnt i stället för att brumma. | **dangerStyle** |
| `fia` | Fyrverkeri-Fia | Sällsynt | Liten rosa raket som skjuter upp egna fyrverkerier när du slår rekord. | **recordFanfare** · partikel star |
| `vulle` | Vulkanen Vulle | Sällsynt | Varm liten vulkan: stora merges (nivå ≥8) sprutar lava och en djup bas. | **lavaMerge** · partikel drop |
| `disco` | Discokulan Disco | Sällsynt | Coolaste discokulan: bakgrunden gungar mjukt i takt med combon. | **discoBg** · partikel confetti (combofärg) |
| `eko` | Ekot Eko | Sällsynt | Ropar in i en grotta: varje merge ekar tillbaka som i en katedral. | **echoMerge** · partikel ring |
| `klick` | Kameran Klick | Sällsynt | Glad retrokamera som tar en polaroid av rundans största kedja. | **polaroid** |
| `nora` | Norrsken-Nora | Sällsynt | Fjällräv med norrskenssvans: långa kedjor tänder norrsken över burken. | **auroraChain** · spår dot |
| `lisa` | Lykt-Lisa | Episk | Marulk från djupet med en lykta på pannan: den lyser upp de som passar ihop. | **sameLevelGlow** |
| `siri` | Spådamen Siri | Episk | Spådam som håller objektet som en kristallkula och ser två steg fram. | **queuePeek** |
| `sixten` | Sikt-Sixten | Episk | Keps och kikarsikte: han visar exakt var det du släpper landar. | **landingDot** |
| `bubbel` | Bubblan Bubbel | Episk | En levande såpbubbla: rundans första drop landar mjukt utan studs. | **noBounceStart** · spår bubble |
| `ekko` | Ekolodet Ekko | Episk | Liten ubåt med ekolod: när en ny nivå tänds pingar alla av den nivån. | **sonarNewLevel** |
| `kajsa` | Kikaren Kajsa | Episk | Surikat på utkik med kikare: hon ser nästan-träffar långt innan du gör det. | **nearMissFrom** |
| `maja` | Magnet-Maja | Legendarisk | Hästskomagnet som håller objektet mellan polerna och en gång per runda drar ihop två lika. | **magnetPull** · partikel bolt |
| `rut` | Regnbågs-Rut | Legendarisk | En regnbåge med molnfötter som alltid har en regnbåge med sig till rundan. | **startRainbow** · partikel star (combofärg) |
| `vala` | Andrums-Vala | Legendarisk | Stor lugn val som blåser en fontän: ger dig ett extra andetag när burken blir full. | **breath** · partikel drop |
| `havsdrottningen` | Havsdrottningen | Mytisk | Havets drottning med pärlhalsband och krona: hela burken blir guld och orkestern spelar. | **queenRound** · spår star, partikel star |
| `stjärnvalen` | Stjärnvalen | Mytisk | En val gjord av natthimmel: stjärnor i kroppen, månskära på huvudet, allt i burken glöder. | **starWhale** · spår star, partikel star |

Vanlig och ovanlig är ren kosmetik. Ovanlig är rikare: fler kanaler per figur (spår + partikel + ljud + gest). Uppgradering av kosmetik: `UPGRADE.cosmeticParticleMul` 1 / 1,15 / 1,3 och `cosmeticTrailMul` 1 / 1,25 / 1,5 (spårets `lifeMs`).

Nya partikelformer i `AVATAR_PARTICLE_GEOM` är polygoner i 16×16, bakas vita och tintas som §12.1.3: `heart`, `note`, `confetti`, `drop`, `bolt`. Spår (`TrailDef`) emitteras från det fallande objektet var `everyPx` px fram till första kontakten.

### 13.2 Raritet (`RARITY`)

| Raritet | Nyckel | Färg | Kontrast mot bg | Pärlor | Odds | Juice vid öppning | Ringar |
|---|---|---|---|---|---|---|---|
| Vanlig | `common` | `#A9B4C8` grå | 9,1:1 | 1 | 44 % | 0,30 | 0 |
| Ovanlig | `uncommon` | `#6EE7A0` grön | 12,3:1 | 2 | 28 % | 0,42 | 1 |
| Sällsynt | `rare` | `#5AA9FF` blå | 7,7:1 | 3 | 16 % | 0,54 | 2 |
| Episk | `epic` | `#B98CFF` lila | 7,4:1 | 4 | 8 % | 0,66 | 3 |
| Legendarisk | `legendary` | `#FFD75E` guld | 13,6:1 | 5 | 3 % | 0,78 | 3 + 8 strålar |
| Mytisk | `mythic` | regnbåge `RARITY.rainbow` (reserv `#FF9CF0`) | 10,2:1 | 6 | 1 % | 0,90 | 3 + 12 strålar |

- **Aldrig bara färg.** Raritet visas alltid också som **antal pärlor**, i öppningen och som gruppens rubrik i boken, och som **grupp** i rutnätet.
- Mytisk ritas som sex färgsegment: ramen i segment, pärlan i ränder. Den kan alltså inte förväxlas med någon enfärgad raritet.
- Grönt och blått ligger nära varandra för deuteranoper. Därför bär pärlantalet (2 mot 3) informationen där.
- Ingen raritetsfärg är röd.
- `accent` (`#7CF9FF`) används inte som raritetsfärg. Blått `#5AA9FF` ligger 2,0:1 från accent i ljushet och har en annan kulör.

### 13.3 Musslans öppning (DESIGN §14.3)

Känsla: **"titta vem som kom!"** En fast, lugn ceremoni. Musslan ser likadan ut oavsett innehåll, öppnar sig på samma sätt varje gång och låter likadant fram till det ögonblick figuren syns. Först där skiljer sig rariteterna, i **antal kanaler** (ringar, strålar, ljudets rikedom), aldrig i spänning före. Ingen rullning, inga kandidater, ingen stegvis uppgradering och inget "nästan".

Layout 360×640 på startskärmen. Tider från trycket (`AVATAR_UI.open`):

| t (ms) | Händelse | Ease | Ljud / haptik |
|---|---|---|---|
| 0 | Scrim `bg` 0 → 0,86 på 200 ms över hela startskärmen. Musslan lämnar hyllan (92, 450) och flyger längs kvadratisk bezier via (150, 360) till (180, 300). Skala 1 → 2,6 (48 → 125 px), rot 0 → +6° → −6° → 0 (en vickning, samma för alla) | Cubic.easeOut, 280 ms | `ui` |
| 280 | Övre skalhalvan (`SHELL_TOP_SVG`, origin i gångjärnet vid y 38/64) tippar bakåt: scaleY 1 → 0,45. Vid 0,75 byts texturen till insidan (`SHELL_TOP_SVG(edge, '#FFF3F8', '#F4C8DA')`, pärlemor), så att locket syns öppet ovanför gångjärnet | Back.easeOut, 180 ms | `shellOpen` (samma för alla) |
| 300 | Glöd i raritetsfärg bakom figuren: radial `bg-glow`-textur tintad, r 0 → 96, alpha 0 → 0,42. **En** ljusökning, ingen blixt | Cubic.easeOut, 260 ms | – |
| 320 | **Figuren** (112 px, centrum) stiger från skalet (y 300) till y 228, skala 0,35 → 1 med överslag 1,8. **Alla pärlor samtidigt** på y 374 (r 7, 20 px mellanrum), scale 0 → 1. Två tomma uppgraderingsrombar på y 398. Ringar i raritetsfärg (0–3 st, r 56 → 128, 640 ms, 120 ms isär, alpha 0,85 → 0). Legendarisk och mytisk: 8/12 strålar bakom (r 44–132, alpha 0,18, roterar 12°/s). Partiklar `6 + 24·juice` i figurens `particleShape`/`particleTint` (setets form om den saknas) | Back.easeOut 260 ms / Cubic.easeOut | `AVATAR_SOUND.reveal[rarity]`, haptik 10/10/30/30/60/60 ms |
| 580 | Figuren gör sin **showcase** en gång (`showcase.anim` + `fx` vid `fxAtMs` + `sound`). Tidsskala `min(1, 620 / längd)` så att den är klar vid 1 200 | enligt recept | `showcase.sound` |
| 1 200 | Klart. Figur, pärlor, rombar och glöd ligger kvar och strålarna fortsätter rotera | – | – |
| tryck | Figuren krymper till 0,3 och flyger till bokikonen (246, 444). Scrimmen tonas ut på 200 ms. Nästa mussla (om det finns) ligger kvar och andas | Cubic.easeIn, 320 ms | `equip`-plinget |

- **Hoppa över:** ett tryck före 1 200 sätter slutläget direkt (kill tweens, sätt slutvärden, ingen showcase). Nästa tryck stänger.
- **`juice.trigger('jackpot', RARITY.juice[r])`** med shake, zoom och hit-stop **av**, som vid nytt set (DESIGN §13.6). Max 0,9.
- **Lugnt läge:** högst 1 ring, inga strålar, halva partiklarna, haptik 10 ms.
- **Den öppnade figuren är inte automatiskt vald.** Den väljs i boken. Undantag: den allra första musslan väljs automatiskt, eftersom spelaren annars inte har någon kompis. Se §13.13, fråga 1.

**Oöppnade musslor på hyllan** (`AVATAR_UI.shelf.box`, `SHELL_ICON`):
- Stängd mussla, 48 px, pärlemorrosa med **accent-kontur**, eftersom den är tryckbar.
- Alla ser exakt likadana ut. Formen avslöjar ingenting.
- Upp till 3 ritas som en hög: var och en förskjuts (−9, −7), skala 0,86 och alpha 0,8 bakåt. Ingen siffra, ingen röd prick.
- Den främsta andas: skala 1,00 ↔ 1,06, halvcykel 1 000 ms (0,5 Hz).
- Tryck öppnar den främsta. Ingen "öppna alla".

### 13.4 Fliken Kompisar i boken (DESIGN §14.3–14.4)

Känsla: **"mina kompisar på rad"**. Samma lugna pärm som §12.4, men med en scen högst upp där den valda kompisen står och visar vad den kan.

| Element | Position och utseende (`AVATAR_UI.book`) |
|---|---|
| **Flikar** | Två bokmärkesband som hänger från överkanten. Set x 32, Kompisar x 96, bredd 48. Aktiv: 72 lång, fylld accent 0,16, kontur 3 px `accent`, ikon `accent`. Inaktiv: 58 lång, `jarWall` 0,7, kontur 2 px `hudDim`, ikon `hudDim`. Ikon 32 px vid y 36. **Form (längd + fyllning) bär informationen, inte färgen** |
| Flikarnas träffyta | 56×72: x 4–60 och 68–124, 8 px mellanrum. **18 px till setikonens ring** (x 142), vilket svarar på programmerarens fråga. Under 64 men ≥48 med 8 px mellanrum (UI-regeln för trånga lägen) |
| Stäng | oförändrad (320, 44), 72×72 |
| **Scen** | Vald kompis 80 px med greppet vid (104, 152). Den håller en nivå 2-glimt i aktivt set (r 18, centrum (104, 166), alltså greppet 4 px under ovankanten som i spel). Radial glöd i raritetsfärg bakom (r 46, alpha 0,25). Uppgraderingsrombar på axeln som i spel. Träffyta x 16–192, y 80–196: **tryck = spela showcase igen** |
| **Odds-burk** | Glasburk centrum (268, 134), 88×96, lock 10 px, `jarEdge` 3 px, glas `jarGlass` 0,55. **25 pärlor** r 6,5 i rader 6-5-6-5-3 nedifrån (bottenrad y 172, 13,6 × 11,8 px), ordnade efter raritet **nedifrån och upp: vanlig längst ner, mytisk överst**, så att den sällsynta pärlan ligger som körsbäret på toppen. Antal = `oddsPearls(kvar per raritet)` |
| Rutnät | Viewport y 204–632, klipps. 12 px toning i överkant. **Rarast överst** (mytisk → vanlig), samma riktning som burken |
| Grupprubrik | 28 px hög: N pärlor (r 4,5, 12 px mellanrum) från x 22, linje i raritetsfärg alpha 0,5 fram till x 300, `ägda/antal` 16 px/800 `hud` högerställt vid x 340 (siffror är tillåtna) |
| Celler | 6 kolumner, centrum x = 40 + 56·k, radavstånd 72. Ram 48×48, hörnradie 12. **Träffyta 48×56** (ram + rombar), 8 px mellanrum i sidled, 16 px i höjdled |
| Ägd | ram 3 px i raritetsfärg (mytisk: 6 regnbågssegment), fyllning raritetsfärg alpha 0,14, figuren 40 px |
| Ej ägd | figurens **siluett** i `hudDim` alpha 0,25 och streckad ram (5/5) i `hudDim` alpha 0,35. Formen syns och gör en att vilja ha den, men inga färger och inga förmågor |
| Vald | yttre ram 56×56 (pad 4), 3 px `accent` + bockbricka r 8 vid (+22, −22), fylld `accent` med bock i `ink`. Samma språk som aktivt set i §12.4 |
| Uppgradering | **2 rombplatser** under cellen (y +32, 14 px isär, 8×10). Uppnådd nivå: fylld `hud` med `ink`-kant. Nästa: kontur i `hudDim`, fylls nedifrån med alpha 0,6 i takt med XP. Nivå I: två tomma (den första fylls mot 150 XP). Nivå III: två fyllda |
| Nytt sedan sist | skalpuls 1,00 ↔ 1,10, 0,5 Hz, tills cellen har synts i 2 s (`freshPulse`) |

**Interaktion (inga långtryck, se §10.5):**
- **Tryck på ägd cell** väljer kompisen:
  - Bockbrickan flyttas: den gamla krymper på 120 ms, den nya ploppar in på 200 ms (Back.easeOut).
  - På scenen faller den gamla figuren ner och ut (160 ms Quad.easeIn) och den nya poppar in (240 ms Back.easeOut). Direkt därefter gör den nya sin showcase i normal takt.
  - Ljud `equip` följt av `showcase.sound`. Haptik 10 ms.
  - Bytet gäller från nästa runda (DESIGN §14.6).
- **Tryck på scenen** spelar showcase igen. Tryck under pågående showcase ignoreras.
- **Tryck på siluett:** cellen skakar ±4 px två gånger på 240 ms och ljudet `locked` (§12.7) spelas. Inget mer. Ingen information om vad som krävs.
- **Scroll:** vertikalt drag följer fingret 1:1. Vid släpp fortsätter rörelsen med friktion 0,94 per frame. I kanterna gäller gummiband 0,35. Tryck räknas som tryck om fingret rör sig < 12 px på < 350 ms (samma som §12.4).
- **Första öppningen av fliken:** efter 500 ms glider innehållet 40 px upp och tillbaka på 700 ms (Sine.easeInOut). Det är scroll-ledtråden, utan text.
- **Startposition:** raden med en ny kompis om det finns en, annars raden med den valda, centrerad i viewporten.
- **Flikbyte:** tryck på ett band. Innehållet korstonas på 160 ms och ljudet `tab` spelas. Horisontellt svep i Set-fliken bläddrar sidor som förut och byter aldrig flik.
- Boken öppnas på Kompisar om det finns en ny kompis som inte har visats, annars på Set.

**Burkens matte.** `oddsPearls`:
1. Omnormera oddsen bland rariteter som har figurer kvar och räkna 25 · andel.
2. Floor, men **minst 1 per levande raritet**.
3. Fördela resten efter största decimaldel. Blir det för många tas överskottet från den största gruppen.

Full pool ger 10/7/4/2/1/1. **Mytisk har alltid minst en pärla så länge den finns kvar** (beslut). Tom pool ger en tom burk med `SHELL_OPEN_ICON` i botten, "allt är öppnat".

### 13.5 Släpparen i spel (DESIGN §14.1)

Känsla: **en kompis som bär din boll till kanten och släpper den åt dig.** Den ska synas i ögonvrån men aldrig skymma siktet.

| | Värde (`AVATAR_UI.slapparen`) |
|---|---|
| Storlek | 40 px (skala 40/56). Det räcker för silhuetten på 320 dp, och figuren blir aldrig bredare än nivå 3-objektet den oftast håller |
| Position | x = det hängande objektets x, varje frame (samma lerp som `aim`). y: greppunkten = objektets ovankant + 4 px = `spawnY − r + 4`. Figuren sitter alltså ovanpå objektet med vantarna över dess hjässa. Nivå 0 ger greppet på y 54 och figuren mellan y 17 och 57. Nivå 4 ger greppet på y 37 och figuren mellan y 0 och 40. Håller sig inom 0–60 |
| Håll | figurens egna vantar/fenor/snöre ligger på greppunkten. Inget extra ritas |
| Luta | rot = klamp(Δx per frame · 0,35°, ±8°), tillbaka till 0 på 180 ms när fingret står still. Den "lutar in i" rörelsen |
| Nytt objekt | greppets y tweenas till nya `spawnY − r + 4` på 220 ms Back.easeOut, samtidigt med `queueSlide` |
| Mellan drop och nästa objekt | figuren står kvar där den släppte med tomma vantar och spelar `drop`, sedan `idle` |
| Pacing-vickning (§11) | figuren roterar med 0,5 × objektets vickvinkel kring greppet ("trötta armar") |
| Depth | **6,5**: över hängande objekt (6), HUD-kedjan (5,5) och glitter (5,2), under HUD (10), förhandsvisningen (10) och combo-prickarna (10). Poängen syns alltid ovanpå figuren |
| Uppgraderingsromb | på figurens högra axel, box (18, −18), 9×12 box-enheter (≈ 6×9 px), `hud`-vit med `ink`-kant 2 och en vit reflex. **II = 1 romb, III = 2 romber** (den andra 10 enheter nedanför). Nivå I: ingen. Samma romb som i boken, så sambandet syns utan text |
| Ingen kompis vald | ingen figur. Objektet hänger som i v1.1 |
| Lugnt läge | `dy`/`rot` i alla recept × 0,5. `chain` spelas som `merge`. Spår och partiklar × 0,5 |
| Specialobjekt | figuren håller dem som vanligt. Förhandsvisningens puls (§4) påverkar inte figuren |

### 13.6 Hyllan på startskärmen

Hyllan byggs ut åt vänster så att musslorna får en egen plats. Bästa objektet och boken flyttas lite åt höger (`AVATAR_UI.shelf`, ersätter `META.shelf.best/book/hit/badge`):

| Element | Position |
|---|---|
| Hyllinje | x 48 → 312, y 470, konsoler vid x 60 och 300 |
| Musslor | (92, 450), 48 px, hög om upp till 3. Träffyta x 60–124, y 408–484 (64×76) |
| Vald kompis (om ingen mussla väntar) | sitter på hyllan: greppunkt (92, 470), 48 px, idle-loop. Samma träffyta: **tryck öppnar boken på Kompisar** |
| Bästa objekt | (166, 436), r 34 |
| Bok | (246, 444), 48 px. Träffyta x 132–312, y 396–484. 8 px till musslans yta |
| Nytt-prick | (266, 422), r 6 `gold` |
| **Rekordets kompis** | vänster om kronan: centrum (110, 496), figur 30 px i en ring r 17 (2 px raritetsfärg, fyllning raritetsfärg alpha 0,15). Visas bara om `highscoreAvatar` finns. Rekord från före v1.2 visas utan figur |
| Krona + siffra | oförändrade (140, 498) och x 172 |

### 13.7 Rundavslutet: ny mussla (DESIGN §14.3)

- Musslan (`SHELL_ICON`, 40 px) poppar in i stripen vid (304, 56) när den sista flygaren har landat + 80 ms (eller vid 420 ms om inget fångades). Scale 0 → 1 på 140 ms, Back.easeOut, ljud `boxEarned`, haptik 10 ms.
- 300 ms senare flyger den mot nederkanten, mot (92, 640), där hyllan kommer att vara: 260 ms Cubic.easeIn, skala → 0,6.
- Nytt set samma runda: musslan kommer **före** set-ceremonin, så att den senare inte avbryts. Allt ryms fortfarande inom 2 500 ms.
- Flera musslor i samma runda visas som en: 2–3 musslor staplade enligt hyllans regel. Ingen siffra.
- Omstart är aktiv hela tiden (<0,5 s).

### 13.8 Förmågor (`ability.key` + parametrar I/II/III)

Programmeraren implementerar beteendet. Värdena ligger i `avatars.ts`, en kommentar per figur.

| Raritet | Nyckel | Figur | Beteende | I → II → III |
|---|---|---|---|---|
| Sällsynt | `thunderChain` | Muller | kedja ≥3: shake × mul (tak 8 px, **av i Lugnt läge**), sicksackblixtar som streck (ingen skärmblixt), mullerljud | mul 1,2/1,3/1,4, blixtar 3/3/4 |
| Sällsynt | `comboMelody` | Maestro | combo-steg n spelar ton n i "Blinka lilla" (trad.) i stället för halvtonstrappan | II + kvint, III + bas |
| Sällsynt | `dangerStyle` | Tick | fara: samma slow-mo, sepiaoverlay i stället för desaturering, tick-tack 2 Hz (ljud) i stället för brummet, statisk klockring | sepia 0,22/0,25/0,28 |
| Sällsynt | `recordFanfare` | Fia | newRecord: raketer stiger och slår ut i stjärnringar (partiklar), egen fanfar | raketer 3/3/4 |
| Sällsynt | `lavaMerge` | Vulle | merge till nivå ≥8: lavadroppar (korall/bärnsten) + 55 Hz sub | droppar 10/12/13 |
| Sällsynt | `discoBg` | Disco | färgfläckar på bakgrunden roterar 20°/s, alpha stiger med combo, puls **max 1 per 500 ms** | fläckar 12/14/16, tak 0,10/0,12/0,13 |
| Sällsynt | `echoMerge` | Eko | delay-eko på merge-ljudet + fördröjda ringar | feedback 0,35/0,40/0,45 |
| Sällsynt | `polaroid` | Klick | ögonblicksbild av burken när längsta kedjan toppar, polaroid i rundavslutet. Slutaren är två lameller, **aldrig vitblixt** | foton 1/1/2 |
| Sällsynt | `auroraChain` | Nora | kedja ≥3: norrskensband över burkens hals (ADD, vajar 0,3 Hz) | band 2/3/3, håll 1,5/1,8/1,95 s |
| Episk | `sameLevelGlow` | Lisa | medan man siktar: objekt av samma nivå får en stilla ring (alpha 0,35). "Olja" räcker N s siktning per runda, och lyktan på Lisa krymper när den tar slut | 6/8/10 s |
| Episk | `queuePeek` | Siri | förhandsvisningen visar även objektet efter nästa (vid x 250, ram 44) | r 12/14/15, alpha 0,6/0,7/0,78 |
| Episk | `landingDot` | Sixten | siktlinjen (även i läge av) slutar i en prick där objektet landar. II–III: streckad kontur på landningsplatsen | prick 5/6/6,5, kontur 0/0,15/0,2 |
| Episk | `noBounceStart` | Bubbel | rundans första N drop har restitution 0, med bubbelhinna tills landning | 10/12/15 |
| Episk | `sonarNewLevel` | Ekko | ny nivå tänds i HUD-kedjan: alla av den nivån får en expanderande ring, 1 Hz | pingar 2/2/3 |
| Episk | `nearMissFrom` | Kajsa | near-miss-pulsen (äkta) visas från lägre nivå | ≥6/≥5/≥4 |
| Legendarisk | `magnetPull` | Maja | N gånger per runda: två lika (ej nivå 10) med gap < range i 400 ms dras ihop på 300 ms, med fältlinjer. Aldrig under fara | 1/1/2 gånger, 40/46/46 px |
| Legendarisk | `startRainbow` | Rut | regnbåge som drop nr N. III: också en bomb som drop 12 | drop 3/2/2, bomb nej/nej/ja |
| Legendarisk | `breath` | Vala | N gånger per runda: förlustgränsen 2,5 s i stället för 1,5 s. Vala andas in och en fontän syns i halsen. Räknaren visas aldrig | 1/2/2, 2,5/2,5/2,8 s |
| Mytisk | `queenRound` | Havsdrottningen | guldburk, stråklager på merge-klangen, regnbåge i varje runda + extra specialobjekt | extra 1/1/2 |
| Mytisk | `starWhale` | Stjärnvalen | stjärnhimmel som bakgrund, +0,1 glow på alla objekt, chansen för skimrande × mul (garantin oförändrad) | × 2/2,5/3 |

**Avvikelse från ~30 %-regeln (DESIGN §14.4):** de heltal DESIGN §14.5 själv anger ger större steg: Lisa 6 → 10 s, Bubbel 10 → 15, Kajsa 6 → 4, Maja 1 → 2, Vala 1 → 2, Drottningen 1 → 2 och Stjärnvalen 2 → 3. Jag har följt §14.5. Mina egna känslo-parametrar (antal blixtar, raketer, band, ringar) är kosmetik och får därför bli rikare. Parametrar som påverkar spelet håller sig inom 30 % (Maja range +15 %, Vala grace +12 %).

### 13.9 Mappning mot platshållarna i `boxes.ts` (`BOX_FX`)

| `BOX_FX` | Ersätts av |
|---|---|
| `shellColor`, `shellEdge` | `SHELL_ICON()` / `SHELL_TOP_SVG()` / `SHELL_BOTTOM_SVG()` (fyllning `#FFD9E8`, räfflor `#E79AC0`, kontur accent på hyllan och `#5C2A43` i öppningen) |
| `shelf.{x,y,size,maxShown,dx,dy,hit}` | `AVATAR_UI.shelf.box` (92, 450, 48, 3, −9, −7, 64×76-yta) |
| `pulse` | `AVATAR_UI.shelf.boxPulse` (1,06, 1 000 ms) |
| `fly` | `AVATAR_UI.reveal` (304, 56, 40 px, 140 + 260 ms, mot (92, 640)) |
| `open.x/y`, `shellMs`, `shellScale` | `open.center`, `open.fly.ms` 280, `open.fly.toScale` 2,6 |
| `open.avatarR`, `popMs` | `open.figure.displayPx` 112 (centrum y 228), `open.figure.ms` 260 |
| `open.pearlsY/R/Pitch` | `open.pearls` (374, 7, 20) |
| `open.scrimAlpha` | `open.scrim.alpha` 0,86 |
| `open.intensity` | `RARITY.juice` (samma värden) |
| `open.ring` | `open.rings[rarity]` (0–3) + `open.ring` |
| `friends.tabs` | `AVATAR_UI.book.tabs` (x 32/96, y 36, 48 bred, yta 56×72) |
| `friends.headerH`, `gridTop` | scen + burk upptar y 0–196; `grid.top` 204 |
| `friends.cols/cell/gap` | `grid.cols` 6, `grid.cell` 48, `grid.pitchX` 56 |
| `friends.avatarR`, `ringW` | `grid.avatarPx` 40, `grid.frameW` 3 |
| `friends.levelPearlR/Pitch` | **rombar**: `grid.rombW/H/Pitch/Y` (8, 10, 14, +32) |
| `friends.groupGap` | `grid.headerH` 28 + `grid.groupGap` 8 |
| `friends.jar` | `AVATAR_UI.book.jar` (268, 134, 88×96, 25 pärlor, rader 6-5-6-5-3) |
| `friends.silhouetteAlpha` | `grid.silAlpha` 0,25 |

### 13.10 Ljud (`AVATAR_SOUND` + per figur)

| Ljud | Karaktär |
|---|---|
| `shellOpen` | triangel 220 → 330 Hz, 0,12 s, samma för alla: ett mjukt "klonk-upp" |
| `reveal.common` | enkel ton E5 + kvint |
| `reveal.uncommon` | två toner 0/+7 |
| `reveal.rare` | treklang 0/4/7 |
| `reveal.epic` | 0/4/7/12 med svagt vibrato |
| `reveal.legendary` | 0/4/7/12/16 (som nytt set) |
| `reveal.mythic` | 0/4/7/11/14/19, längre svans, vibrato. **Rikare, inte högre eller snabbare.** Ingen myntklang, inget snurrljud, inget trumvirvel-uppbygge före |
| `boxEarned` | sinus 784 → 1 047 Hz, kort "blipp" när musslan dyker upp |
| `equip` | kort uppåtglid när man väljer kompis |
| `tab` | samma som `pageTurn` |
| Figurernas egna | `cosmetic.sound[trigger]`, t.ex. Krilles kastanjetter vid drop, Gurras kväk vid combo 3, Trummans trumslag. `merge`-ljud transponeras med `playTone(def, combo)` |
| Showcase | `showcase.sound` en gång i öppningen och vid tryck på scenen |

Alla är `ToneDef`-kompatibla (`AvatarTone`) och spelas med `playTone`. Gain ligger på 0,07–0,35 under merge-plinget, så att kompisen aldrig överröstar spelet.

### 13.11 Ikoner (i `avatars.ts`, viewBox 64)

| Ikon | Export | Form |
|---|---|---|
| Mussla stängd | `SHELL_ICON(edge, fill, rib)` | musselskal framifrån, fem räfflor, vågig kant, accent-kontur (tryckbar) |
| Mussla öppen | `SHELL_OPEN_ICON()` | uppfälld övre halva med pärlemor, tom |
| Musslans halvor | `SHELL_TOP_SVG()`, `SHELL_BOTTOM_SVG()` | för öppningen. Gångjärnet ligger vid y 38 |
| Flik Set | `TAB_SET_ICON(c)` | 2×2 cirklar, en fylld ("samling"). Stroke 6 som §9 |
| Flik Kompisar | `TAB_FRIENDS_ICON(c)` | figur som håller en boll (Släpparen). Stroke 6 |
| Pärla | `PEARL_ICON(c)`, `PEARL_MYTHIC_ICON()` | fylld cirkel, `ink`-kant, vit högdager. Mytisk i sex ränder |
| Romb | `ROMB_ICON(c, filled, fillPct)` | fylld med reflex, eller kontur som fylls nedifrån efter XP |

### 13.12 Tillgänglighet och flash-guard

- Alla loopar är ≤1 Hz (kontrollerat i data): idle, danger, musselpuls 0,5 Hz, "ny"-puls 0,5 Hz och strålarnas rotation. En del showcase-gester är snabbare **rörelser** en gång, men de ändrar aldrig ljusstyrkan.
- Ljusökningar sker en gång per händelse: glöd i öppningen och ringar som tonas ut. Inga vitblixtar, även Klicks slutare är mörk. Disco pulserar högst 2 gånger per sekund med alpha ≤0,13. Ekko pingar 1 Hz.
- Raritet bärs av pärlantal, grupp och färg. Uppgradering bärs av antal fyllda romber. Vald kompis visas med bock och accentram. Ägd mot ej ägd skiljs åt som färgfigur mot siluett.
- Inga långtryck och inga dolda gester. Allt nås med ett tryck. Scroll är det enda draget, och det har en ledtråd.
- Figurkroppar ≥3,6:1 mot bakgrunden. Stjärnvalens mörka kropp (3,6:1) har en ljus kontur (15,3:1). Ansikten ≥5,1:1 mot kroppen, till exempel Lisa `ink` på `#8F7CFF`.
- Lägg till `AVATAR_UI.shelf.boxPulse` och `book.freshPulse` i flash-guard-testets lista (`JUICE.pulseHalfCycleMs`).

### 13.13 Öppna frågor

1. **Vilken kompis har man från start?** DESIGN §14 säger inget. Jag föreslår **ingen**: innan första musslan hänger objektet som i v1.1, och första musslan (alltid sällsynt, efter 50 merges) väljs automatiskt. "En kompis kommer" blir då första stora ögonblicket. Alternativet är en neutral startkompis som inte ingår i de 48.
2. **Pärlor mot romber.** DESIGN §14.4 säger "pärlor under avataren" för uppgradering. Jag använder **romber** för uppgradering, i boken och på Släpparen, och låter pärlor betyda **bara raritet**. Två betydelser av samma form vore förvirrande för en 7-åring. Bekräfta.
3. **Lykt-Lisa "6/8/10 s"** har jag tolkat som en siktningsbudget per runda (lyktans olja). Om det i stället ska vara "de första N sekunderna av varje siktning" byts bara betydelsen av `seconds`.
4. **~30 %-regeln** krockar med de heltal §14.5 anger, se §13.8. Jag har följt §14.5.
5. **Rundavslutets mussla** tar ungefär 700 ms av 2,5 s-budgeten. Med nytt set, 6 flygare och en mussla samma runda blir det trångt. Jag föreslår att flygarna då körs i `flyersFast` (§12.5).

---

## 14. Ekonomi v1.3 (DESIGN §16)

Data och tillgångar: `app/src/data/economyUi.ts` (`ECONOMY_UI`, `ECONOMY_SOUND`, `ECONOMY_COLORS`, ikonerna, `formatAmount`). Priser, odds, golv och intjäning ägs av `ECONOMY` i `data/economy.ts` och dupliceras inte. Förmågetexterna ligger i `avatars.ts` (`desc`, `levelHint`, `levelHintLabel()`). `oddsPearls()` tar nu musslans vikter som tredje argument. Granskningsbild: `docs/ui-preview-economy.png` (A–F nedan).

**Känslan i en mening:** en lugn affär vid havsbotten. Man ser vad saker kostar, hur långt man har kvar och vad som finns i varje mussla. Inget blinkar, inget räknar ned och inget lockar med "nästan". Priset står alltid som ikon plus siffra, och inga andra etiketter behövs.

### 14.1 Två valutor som inte går att förväxla

| | Valutapärla | Stjärnsand | Raritetspärla (finns, §13.2) |
|---|---|---|---|
| Ikon | `PEARL_COIN_ICON`: pärlemorgradient `#FFEAF3` → `#F3BBD3`, dubbel högdager, liten vit gnista | `SAND_ICON`: liten hög (`#E8A95C`) med tre femuddiga stjärnkorn (`#FFD39B`) | platt fylld cirkel i raritetsfärg |
| Kontrast mot bg | 16,5:1 | 13,6:1 | 7,4–13,6:1 |
| Står alltid med | en siffra | en siffra | aldrig en siffra, alltid i rad eller i burk |

Formen bär skillnaden: rund med gnista, stjärnor på en hög och platt prick. Valutapärlan är alltid ensam och har alltid en siffra bredvid sig. Raritetspärlor står alltid i grupp. Se §14.10, fråga 1.

### 14.2 Resursräknare (`ECONOMY_UI.counters`)

Samma plats och samma utseende i bokens överkant och på startskärmen (panel A och E), så att "min pung" alltid finns uppe till höger.

| Element | Position |
|---|---|
| Pärlor | ikon 20 px vid (148, 30), siffra 16 px/800 `hud` vänsterställd från x 161 |
| Sand | ikon 20 px vid (232, 30), siffra från x 245 |
| Format | `formatAmount`: smalt mellanslag som tusentalsavgränsare ("1 240"), tabulära siffror (§2.2) |

- Räknarna är **inte tryckbara** och ritas därför inte i accent. I boken ligger de mellan flikarna (slutar x 124) och stängknappens yta (börjar x 284).
- **Köp och uppgradering:** siffran räknas ned på 300 ms (Quad.easeOut) medan 6 valutaikoner (12 px) flyger från räknaren till musslan eller knappen (20 ms isär, 240 ms, Cubic.easeIn). Man ser alltså var pengarna tar vägen.
- **Räcker inte:** ikonen för den resurs som fattas punchar 1,0 → 1,18 → 1,0 en gång (220 ms). Det visar vad som saknas, utan text.
- **Startskärmen:** räknarna ligger på y 30 ovanför logotypen. Resten av §13.6 är oförändrat. Se avvikelsen i §14.10, fråga 2.

### 14.3 Butikshyllan (`ECONOMY_UI.shop`, panel A–C)

Hyllan ligger högst upp i fliken Kompisar, på y 76–172. Den gamla stora oddsburken (268, 134) tas bort och varje mussla får en egen liten burk. Rutnätet flyttas ned till `grid.top` 346.

| Element | Position och utseende |
|---|---|
| Hyllinje | x 16 → 344, y 140, 3 px `jarEdge`, konsoler vid x 28 och 332 (8 px) |
| Platser | cx 66 / 180 / 294: vanlig, silver, guld. Billigast till vänster |
| Mussla | `SHELL_TYPE_ICON(type, state)`, 48 px vid (cx − 20, 116). Samma silhuett som `SHELL_ICON`. **Typen syns i formen:** vanlig är slät och rosa, silver har två vita glintar på ljust silver, guld har en stjärna (stjärnsandens korn) på gult |
| Mini-oddsburk | 40×42 vid (cx + 27, 118), lock 5 px, glas `jarGlass` 0,55, kant 2 px `jarEdge`. **25 pärlor** r 2,9 i rader 6-5-6-5-3 nedifrån, vanlig längst ner och mytisk överst. Antal = `oddsPearls(kvar, 25, musslans vikter)`, där vikterna kommer från `ECONOMY.shells[type].odds` och rariteter under golvet har vikt 0. Därför syns det direkt att silverburken inte har några grå pärlor och att guldburken bara har blå och uppåt |
| Pris | y 158, centrerat på cx: resursikon 16 px + 7 px + siffra 15 px/800 |
| Träffyta | cx ± 53 × y 80–172 (106×92), 8 px mellanrum |

**Tillstånd per plats:**

| Tillstånd | Villkor | Mussla | Pris | Burk |
|---|---|---|---|---|
| **Räcker** | resursen ≥ pris och `shellAvailable` | full färg, kant `accent` 4 (tryckbar) | ikon + siffra i `hud` | full |
| **Räcker inte** | resursen < pris | alpha 0,55, kant `hudDim` | siffra i `hudDim` + **fyllnadsring** runt ikonen (r 10,5, 2,5 px, spår `hudDim` 0,35, båge `hud` = have/pris från kl. 12). Ringen visar hur nära man är, och formen (ringen) bär informationen | full |
| **Tomt** | `!shellAvailable` (inget kvar över golvet) | grå `#5B6780` + bockbricka (r 11 i ikonens 64-box, `hudDim` med `ink`-bock) | inget pris | tom burk med `SHELL_OPEN_ICON` i `hudDim` |
| **Full bok** | alla 48 ägs | musslorna ersätts av `BOOK_ICON` i `gold`, 48 px vid (180, 112), och tre stilla `SPARKLE_ICON` (12/10/8 px) | – | – |

Butiken väntar alltid på spelaren. Inga pulser på "Räcker" (ingen press), inga röda markeringar och inga "!".

### 14.4 Köpflöde (två tryck, `ECONOMY_UI.wake` och `buy`)

Känsla: **"vill du ha den här?"** Musslan vaknar och tittar upp, och först när man trycker igen händer något. Det skyddar mot misstag (barn, fickan, dubbeltryck) utan en dialogruta med text.

| t (ms) | Händelse | Ease | Ljud / haptik |
|---|---|---|---|
| tryck 1 | Musslan **vaknar**: y −6, skala 1,12, övre halvan glipar (`SHELL_TOP_SVG` scaleY 0,82) så att man ser pärlemor. Priset får en accentram (chip 24 px hög, radie 12, 2 px, fyllning accent 0,16) och siffran blir `accent`, eftersom det nu är knappen. Övriga musslor tonas till 0,45 | Back.easeOut, 300 ms | `wake`, haptik 10 ms |
| 300 → | Vaken mussla andas 1,00 ↔ 1,15 **på ringen runt priset**, halvcykel 1 000 ms (0,5 Hz). Ingen ljusstyrkeändring | Sine.easeInOut | – |
| tryck 2 på samma mussla (≥ 250 ms efter tryck 1) | **Köp.** Valutaikonerna flyger från räknaren till musslan och räknaren räknas ned (§14.2) | Cubic.easeIn, 240 ms | `buy`, haptik 30 ms |
| +360 | **Öppningen enligt §13.3**, med start i musslans hyllplats i stället för (92, 450): scrim, flygning till (180, 300), locket, figuren, pärlorna, ringarna, showcase. Alla tider är desamma. Musslans färg följer typen, men **öppningen ser likadan ut för alla typer och innehåll** fram till att figuren syns | enligt §13.3 | enligt §13.3 |
| tryck efter 1 200 | Figuren krymper och flyger till (180, 346), rutnätets överkant. Rutnätet scrollar till figurens rad (240 ms Cubic.easeOut) och cellen får `freshPulse`. Den nya figuren väljs inte automatiskt (§13.3), förutom den allra första | Cubic.easeIn 320 ms | `equip` |

- **Somna:** tryck utanför musslan, flikbyte, scroll eller 3 000 ms utan tryck. Musslan går tillbaka på 200 ms och ingenting kostar. Tryck på en annan mussla väcker den i stället.
- **Tryck 1 på "Räcker inte":** ingen väckning. Musslan skakar ±4 px två gånger på 240 ms, ljudet `notEnough` spelas och räknarens ikon punchar (§14.2). Fyllnadsringen syns redan.
- **Tryck på "Tomt":** musslan nickar (y +3 och tillbaka, 200 ms). Inget ljud. Bocken säger "klar".
- Tryck under ceremonin följer §13.3 (hoppa över eller stäng). Hyllan är inte tryckbar medan scrimmen ligger på.

### 14.5 Vald kompis: text, stapel och uppgradering (`ECONOMY_UI.stage`, panel A–C)

Scenen ligger på y 180–340 under en avdelare (y 176, 2 px `jarWall`, x 16–344).

| Element | Position och utseende |
|---|---|
| Figur | 60 px, centrum (52, 214), med en nivå 1-glimt r 10 i greppet och raritetsglöd r 38 (alpha 0,25). Uppgraderingsrombar på axeln (§13.5). Träffyta x 8–96, y 180–280: **tryck = showcase igen** (som §13.4) |
| Raritetspärlor | y 274, r 3,5, 10 px isär, centrerade under figuren |
| Namn | (104, 194), 17 px/800 `hud`, en rad. Om namnet är bredare än 240 px krymps det till minst 14 px. Bredaste namnet mäter 222 px vid 17 px |
| **Förmågetext** | `desc[locale]`, (104, 212), **14 px/700**, radhöjd 17, färg `desc` `#C9D6EE` (12,9:1), max bredd 240, **max 2 rader**, radbrytning vid ord och ingen avstavning. Alla 96 texter är uppmätta i Chromium och ryms på två rader. Den tredje raden klipps med "…" som skydd om en översättning någonsin blir för lång |
| **Stapel** | 3 segment x 104 → 344 (76 px breda, 6 px mellanrum), y 262, 10 px höga, radie 5. Uppnådd nivå: fylld raritetsfärg (mytisk: regnbåge per segment) + 1,5 px `ink`-kant. Nästa: kontur 2 px `hud`. Senare: kontur 2 px `hudDim` alpha 0,5. **Nivå I är alltid fylld** (man äger kompisen). Fylld mot kontur bär informationen, inte färgen |
| Värde per nivå | under varje segment på y 278, 11 px/800, `levelHintLabel(def, lvl, locale)`. Uppnådda nivåer i `hud`. **Nästa nivå** i `hud` med `UPGRADE_ICON` (10 px) före. Senare i `hudDim`. `levelIcon` betyder att nivåns objekt ritas (r 7) där `{v}` stod (Kajsa: objekt + "+"). Utan `levelHint` visas bara segmenten. Etiketterna är ≤9 tecken och ryms i 76 px (uppmätt) |
| **Uppgraderingsknapp** | 240×48 i centrum (224, 314), radie 14, träffyta 240×56. Innehåll centrerat: `UPGRADE_ICON` 24 px, sedan per resurs ikon 16 px + 7 px + siffra 16 px/800, med 12 px mellan resurserna. Pris = `upgradeCost(rarity, level)` |

**Knappens tillstånd:**

| Tillstånd | Utseende |
|---|---|
| Räcker | fyllning accent 0,14, kant 3 px `accent`, pil `accent`, siffror `hud` |
| Vaken (tryck 1) | fyllning accent 0,26, kant 4 px, pilen lyfts 3 px (300 ms Back.easeOut), **nästa segment förhandsfylls** med alpha 0,35 (panel C). Samma andning, somningsregler och `wake`-ljud som musslan |
| Tryck 2 = köp | valutan flyger till knappen och räknaren räknas ned. Segmentet fylls 0 → 1 på 280 ms (Cubic.easeOut), 12 partiklar i raritetsfärg sprids från segmentet (70 px/s, 460 ms), rombarna på figuren poppar (200 ms Back.easeOut) och figuren gör sin showcase. Ljud `upgrade`, haptik 30 ms |
| Räcker inte | ingen fyllning, **streckad** kant 2 px `hudDim` (6/5), pil `hudDim`. Den resurs som fattas får siffran i `hudDim` och fyllnadsringen runt ikonen, den som räcker behåller `hud`. Tryck: skakning ±4 px, `notEnough` och räknarens punch. Streckningen och ringen bär informationen |
| Nivå III | ingen knapp. `CHECK_ICON` 28 px i `hudDim` alpha 0,8, centrerad på knappens plats, inte tryckbar. Alla tre segment är fyllda |
| Ingen kompis ännu | stapel och knapp döljs. Scenen visar `TAB_FRIENDS_ICON` 60 px i `hudDim` 0,5. Normalt händer det aldrig, eftersom första musslan väljs automatiskt |

### 14.6 Rundavslutet: resursräkning (`ECONOMY_UI.tally`, panel D)

Känsla: **"skörden i fickan".** Ett snabbt, stigande tickande som alltid kommer. Den lilla kicken efter varje runda, oavsett resultat.

- **Plats:** stripens vänsterkant (§12.5). Pärlor: ikon 22 px vid (30, 56) och "+62" 20 px/800 `hud` från x 44. Sand: samma sak på y 94. Det krockar varken med boken (148, 56), stapeln (x 110–250), musslan (304, 56), rekordringen (y ≥ 110) eller set-ceremonin (ringarna når x ≥ 100). Utan sand i rundan visas bara pärlraden. Utan merges visas ingen rad.
- **Tid:** raden poppar in (140 ms Back.easeOut) och räknas upp från +0 **när mätaren är klar**, alltså sista flygaren landat + 80 ms, samma ögonblick som stapeln börjar fyllas. Utan fångster startar den vid 420 ms. Uppräkningen tar **600 ms** (Quad.easeOut). Sanden startar 120 ms efter pärlorna, så att de hörs som två lager.
- **Ljud:** `tallyPearl` / `tallySand`, högst 12 tick per rad och minst 45 ms isär, `playTone(def, round(12 · andel))`, alltså en stigande oktav. Vid slutet `tallyEnd` och ikonen punchar 1,2 (180 ms).
- **Tidsbudget:** 6 flygare ger start 1 720 och slut 2 440 (sand 2 560, se fråga 4). Snabbläget ger start 1 390 och slut 2 110. Inga fångster ger 420 → 1 140. Ett tryck startar om direkt som förut (<0,5 s).
- **Råd-ledtråd (`affordHint`):** om pärlorna efter rundan precis har passerat priset för en vanlig mussla (före < 300 ≤ efter) poppar en liten `SHELL_TYPE_ICON('common', 'ok')` (24 px) in vid (104, 56) när räkningen är klar, med `boxEarned`-ljudet. Ingen puls, ingen text, ingen upprepning. Det är ett "nu räcker det", aldrig ett "köp nu".
- Totalsaldot visas inte här. Det finns på startskärmen och i boken.

### 14.7 Ljud (`ECONOMY_SOUND`, ToneDef → `playTone`)

| Ljud | Karaktär |
|---|---|
| `wake` | sinus 660 → 990 Hz, 0,1 s: "hm?", nyfiket uppåt |
| `buy` | triangel C6 + kvint (0/+7, 60 ms) med oktav: två pärlor som läggs i en skål. Därefter `shellOpen` i ceremonin |
| `upgrade` | triangel D5, fyrklang 0/4/7/12 med 70 ms, svagt vibrato. Varmare och kortare än `reveal.epic` |
| `notEnough` | sinus G4 → E4 (0/−3, 90 ms), lågpass 1,4 kHz, gain 0,10: ett mjukt "hm-m". **Aldrig** surr, buzzer eller sjunkande glissando |
| `tallyPearl` | sinus E6, 35 ms, gain 0,07, stiger en oktav under räkningen |
| `tallySand` | triangel A6 + kvint, 60 ms: glittrigare än pärlan |
| `tallyEnd` | sinus C6 → G6-glid, 0,12 s |

Alla ljud ligger under merge-plinget i gain (0,07–0,26).

### 14.8 Reservläge "välj 1 av 3" (`SHOP.mode: 'pick3'`, panel F)

Om regelverk kräver det byts slumpen ut mot ett synligt val. Hyllan ser likadan ut (musslor, pris och burk, där burken visar hur kandidaterna dras).

1. **Tryck på en mussla** (kostar ingenting, ett tryck räcker): scrim 0,86, musslan flyger till (180, 120) i 72 px och öppnar sig som i §13.3. Tre kort stiger upp ur den, 260 ms Back.easeOut och 90 ms isär.
2. **Korten:** cx 72/180/288, y 176–340, 100×164, radie 16. Ram 3 px i raritetsfärg och fyllning raritetsfärg 0,14. Figur 72 px, raritetspärlor på y 292 och namn 13 px/800 (max 2 rader) från y 314. Inga förmågeikoner och ingen "bäst"-markering.
3. **Tryck på ett kort = välj:** kortet lyfts 8 px, får en 4 px `accent`-ram och en bockbricka r 9. Dess `desc` visas under korten (y 366, 15 px/700, `desc`, max 2 rader, centrerad). Ljud `wake`.
4. **Köpknapp** 200×64 vid (180, 448), accent, med valutaikon 24 px + pris 20 px. Den är grå och streckad med fyllnadsring om det inte räcker (§14.5). Valet av kort är den första bekräftelsen och knappen den andra.
5. **Köp:** de två andra korten sjunker tillbaka ned i musslan (200 ms). Det valda kortet gör figurens del av ceremonin: glöd, ringar enligt raritet, showcase, med samma tider som §13.3 från t = 300.
6. **Stäng** (X vid (320, 44) eller bakåt): korten sjunker ned. **Samma tre kandidater ligger kvar tills man köper en**, så att det inte går att dra om genom att stänga och öppna. Det kräver att erbjudandet sparas (§14.10, fråga 3).

### 14.9 Tillgänglighet och flash-guard

- **Kontrast:** valutaikoner 16,5 / 13,6:1, förmågetext 12,9:1, namn 16,8:1, `hudDim`-siffror 7,4:1. Den gråa tomma musslan (3,3:1) bärs av bocken (`hudDim` med `ink`, 7,4:1).
- **Aldrig bara färg:** musseltyp = form (slät, glintar, stjärna) + resursikon + burkens innehåll. Räcker inte = fyllnadsring + streckad kant + tonad form. Vaken = lyft och glipa + ram runt priset. Nivå = fyllt mot kontur i stapeln + rombar på figuren.
- **Flash-guard:** en loop, den vakna musslans prisring på 0,5 Hz. Allt annat sker en gång. Inga vitblixtar och ingen ljusstyrkeväxling. Lägg `ECONOMY_UI.wake.breath.halfCycleMs` i `JUICE.pulseHalfCycleMs`.
- **Motorik:** alla mål ≥ 92 px höga, utom uppgraderingsknappen (56 px hög, 240 bred, ≥ 8 px till grannar). Inga långtryck. Två tryck i stället för dialogruta.
- **Ingen press:** ingen nedräkning, inga "erbjudanden", inga röda prickar i butiken. Det enda som rör sig av sig självt är den vakna musslan man själv har tryckt på.

### 14.10 Öppna frågor

1. **"Pärlor" betyder tre saker:** valutan, raritetspärlorna (§13.2) och nivå 9-objektet "Pärlan". Jag har skilt dem åt visuellt (§14.1), men för en 7-åring vore det tydligare att döpa om **raritetsmarkeringen**. Den kan heta "stjärnor" i texten, men formen bör vara kvar. Beslut för projektledaren. Det påverkar inte data, bara ord i framtida text.
2. **Räknarna på startskärmen ligger i överkanten (y 30), inte på hyllan.** Hyllans rader är fulla (musslor, bästa objekt, bok, krona och rekord, set-stapeln på y 526, inställningar från y 544). Samma plats som i boken ger dessutom en fast "pung". Säg till om de ändå ska in på hyllan, då behöver set-stapeln flyttas.
3. **pick3: `offerPick3` ändrar ingenting** och drar nya kandidater vid varje anrop. Om erbjudandet inte sparas (t.ex. `economy.pick3Offer[type]: string[]`) kan man dra om genom att stänga och öppna, vilket gör valet till en gratis spelautomat. Det behöver sparas.
4. **Tidsbudgeten:** med 6 flygare (utan snabbläge) slutar sandens räkning vid ≈ 2 560 ms, alltså 60 ms över 2 500. Förslag: med sand och ≥ 5 flygare används `flyersFast`, eller så startar sanden samtidigt med pärlorna.
5. **Mini-burken överdriver sällsynta rariteter:** minst en pärla per levande raritet (beslut §13.4) ger mytisk 4 % i burken mot 0,5 % i vanlig mussla. Det är samma avvägning som förut ("mytisk syns alltid"), men skillnaden är nu större. Alternativ: tillåt 0 pärlor när oddsen är under 2 %, med en streckad plats överst som betyder "finns, men mycket sällsynt".
6. **`ECONOMY_UI` ligger i en egen fil** (`economyUi.ts`), eftersom `economy.ts` redan fanns hos programmeraren. Slå ihop eller re-exportera.

---

## 15. Art v2 – djup och material utan bildfiler

Data: `app/src/data/art.ts` (`ART`, alla parametrar). Referensrenderare: `app/src/ui/artv2.ts` (ren TS och Canvas2D, ingen Phaser). Granskningsbild: `docs/ui-preview-artv2.png`, Chromium. Den visar 12 kompisar (två per raritet) i tre rader: v1 1×, v2 1× och v2 3×. Därefter kommer Glimtarna 0–10 före och efter, spelskärmen före och efter, och närbilder på öppningen och på nivå 4 och 7. Mobilkontroll: spelskärmen i v2 i 390×844 med DPR 3.

**Känslan i en mening:** figurerna ska se ut som **små gjutna leksaker av mjuk, blank plast** som lyser i mörkret. De ska kännas som något man vill ta upp, inte som klistermärken. "Snyggare" betyder här ljus, djup och skarpa kanter. Det betyder inte fler detaljer. Siluetter, färger och ansikten är desamma som i v1.

### 15.1 Diagnos: varför v1 ser platt ut

1. **1× upplösning, två gånger om.** Spelets canvas är 360×640 och skalas upp med CSS (`Scale.FIT`). På en telefon med DPR 3 förstoras allt ungefär 3,25× bilinjärt, så varje kant blir suddig. Dessutom bakas texturerna i logiska px, så en kompis på 40 px är en bild på 60×60 px. Det här är det största enskilda felet.
2. **Bara platta fyllningar.** Phaser Graphics saknar gradienter, så kroppen har en enda kulör och formen ser ut som en utklippt skiva i stället för ett klot.
3. **Ingen skuggsida.** Allt är lika ljust överallt. Det finns ingen nederkant som vänder sig bort från ljuset, så ögat kan inte avgöra om formen är konvex.
4. **Topp-ljuset har en hård kant** (vit ellips med alpha 0,20–0,26). Det ser ut som en påmålad fläck, inte som en reflex.
5. **Konturen är likformig.** Den har samma bredd, alpha och ton runt hela formen. Den säger ingenting om var ljuset kommer ifrån och gör allt lika grafiskt.
6. **Delarna har inget djup mellan sig.** Huvud, vantar och hatt ligger bara ovanpå varandra, utan kontaktskugga. Kompisarna ser ihopklistrade ut.
7. **Glöden är trappstegad.** Tre koncentriska cirklar ger synliga ringar (tydligast på nivå 8–10) i stället för mjukt ljus.
8. **Ansiktena är hål utan kant.** Ink ligger direkt på färgen och ögonvitorna är platta, så ansiktet sitter på ytan i stället för att vara format i den.

### 15.2 Förutsättning: hi-DPI-canvas (programmerare)

Utan detta ger v2 bara materialet, alltså raden "v2, 1×" i granskningsbilden. Den skarpa raden "v2, 3×" kräver att spelet renderar i skärmens upplösning:

```
const Z = Math.min(window.devicePixelRatio || 1, ART.maxDpr)   // ev. tak 2 på svaga enheter
new Phaser.Game({ scale: { mode: FIT, width: 360 * Z, height: 640 * Z }, ... })
// varje scen: this.cameras.main.setZoom(Z).centerOn(180, 320)
// input: pointer.worldX/worldY (inte pointer.x/y); Text: setResolution(Z)
```

**Bakningsfaktorn är `Z`, spelets zoom, inte `devicePixelRatio`.** Visa texturen med `setScale(1 / info.dpr)`. Fysik, levels.ts och alla logiska mått är oförändrade.

### 15.3 Materiallagret (parametrar i `ART`)

Enhet `h` = delens halvstorlek (för nivåer h = r). Parametrarna är relativa, så samma material ser likadant ut på en vante, en kropp och Klunken. Ett ljus uppe till vänster, samma håll som burkens reflexer. Kantljus uppe till höger, som glöd från havet.

| Steg | Teknik (Canvas2D) | Parametrar |
|---|---|---|
| Färgderivering | HSL ur `color`: **hi** = L+16, S−6 · **lo** = L−12, S+10 · **shade** = L−22, S+6 · **rim** = (L+30, S−10) blandad 35 % mot vitt. Mörka kulörer (L < 30) mörkas relativt: L·0,7 | `ART.base`, `ART.inner`, `ART.rim` |
| 1. Basgradient | elliptisk radial i delens bbox, centrum (−0,38h, −0,46h), radie 1,55h. Stopp: hi 0, **color 0,66**, lo 1. Mittstoppet ligger långt ut, så ansiktszonen aldrig blir mörkare än `color` (se §15.6) | `ART.base` |
| 2. Inre skugga | "utsidan" (stor rektangel minus formen, evenodd) fylls med skugga, klippt till formen. Förskjutning uppåt = halva konturen + 0,16h, blur 0,2h, shade alpha 0,5 | `ART.inner` (avatarer: bara delar med h ≥ 5 box-enheter) |
| 3. Kantljus | samma teknik, men utsidan flyttas ned-vänster (−0,62; 0,78) · (halva konturen + 0,08h), blur 0,05h, rim alpha 0,72 | `ART.rim` |
| 4. Speglingsljus | mjuk ellips: v1:s topp-ljus på samma plats och i samma storlek, men som radiell gradient (alpha 0,42 för nivåer, 0,55 för avatarernas `shine`). Hård prick: vit alpha 0,9, r 0,075h vid (−0,44h, −0,54h) | `ART.spec` (avatarer: prick först vid h ≥ 7,5) |
| 5. Kontur | samma bredd som v1. Linjär gradient topp-vänster → botten-höger: (edge L+10, alpha 0,8) → (edge, alpha 1). Nivåer: innerkanten flyttas upp 0,45·lw/2, så att konturen blir **tjockare nedtill** (tyngd) | `ART.edge` |
| 6. Kontaktskugga | varje materialdel kastar en mjuk skugga (0,3; 1,2) med blur 1,6 box-enheter och alpha 0,3 **bara på det som redan är ritat** (`source-atop`) | `ART.contact` |
| 7. Drop shadow | hela figuren ritas i ett lager och läggs på med skugga: avatar (0,4; 1,6) med blur 2,4 box-enheter och alpha 0,55; nivå (0,02r; 0,07r) med blur 0,1r och alpha 0,42. Glöden ligger utanför lagret och får ingen skugga | `ART.drop` |
| 8. Ansikten | **formen är identisk** (samma mått, butt-ändar). Före varje ink-drag ritas samma drag i vitt med alpha 0,3, förskjutet 0,55 box-enheter resp. 0,022r nedåt (`source-atop`). Det blir en ljus underläpp, så draget ser **intryckt** ut. Ink förblir platt `#14202E` | `ART.face` |
| Ögon (bara avatarer) | ögonvita: sfärisk gradient vit → `#CFDBEF` + ögonlockets inre skugga uppifrån (alpha 0,28). Glint: mjuk gloria 2× med alpha 0,4 runt den befintliga vita pricken | `ART.face` |
| Kinder | radiell rodnad (toppalpha 0,72 → 0) i stället för platt ellips med alpha 0,55 | `ART.cheek` |
| Glöd | **en** radial från 0,9r till r(1+glow): alpha 0,34 → 0,14 (vid 40 %) → 0 | `ART.halo` |
| Ring (nivåer) | graverad fåra: color2 alpha 0,42 + ljus underkant (hi, alpha 0,32, 0,4 av bredden, 0,028r ned) | `ART.groove` |
| Prickar `dot`/`crater` | gropar: ljus underkant (hi, alpha 0,3) under den mörka pricken | `ART.dimple` |
| Rör (spröt, tentakler, ben) | mörkt underlag (som v1) + färg + smal högdager (0,34 av bredden, L+22, alpha 0,6) förskjuten upp-vänster | `ART.tube` |
| Dekortrianglar (fenor, krona, is, lågor) | mörk understroke, linjär gradient hi → color → lo, kontaktskugga | – |

### 15.4 Så klassas avatarernas ops (ingen ändring i `avatars.ts`)

Renderaren läser samma `AvatarOp`-listor och väljer material efter egenskaper, i den här ordningen:

| Op | Behandling |
|---|---|
| `curve`/`line` med `edge` | rör |
| streck (curve/line/`stroke`) i ink | inset-ansiktsdrag |
| vit ellips, alpha ≤ 0,5, utan edge (`shine`) | mjukt speglingsljus |
| ellips, alpha 0,4–0,7, utan edge, inte vit (`cheeks`) | rodnad |
| vit cirkel **med** edge | ögonvita |
| vit cirkel utan edge, r ≤ 1,8 | glint med gloria |
| fylld form i ink (luminans < 0,02) utan edge | inset-ansiktsdrag |
| fylld form med `edge` | **material** (steg 1–6) |
| övrigt (fläckar, mage, stjärnor, scatter) | platt, som tryck på materialet |

Stjärnvalens ljusa drag (`#FFF4C0`) räknas som tryck och förblir platta, med samma kontrast som i v1.

### 15.5 API och koppling

```
avatarBakeInfo(displayPx, dpr, mode?) → { px, dpr, logical, originY }
levelBakeInfo(skin, radius, dpr, mode?) → { px, dpr, logical, originY: 0.5 }
renderAvatar(ctx, def, displayPx, { dpr, mode?, part?, rombs?, sil?, shadow?, scratch? })
renderLevel(ctx, skin, radius, { dpr, spotStyle?, mode?, sil?, shadow?, scratch? })
```

- `ctx` = `CanvasTexture.getContext()` med identitetstransform. Skuggor räknas i enhetspixlar, och renderaren tar hänsyn till det.
- `mode: 'v1'` ritar exakt dagens platta recept i Canvas2D. Det används för före/efter och som **lågprestandaläge**.
- `sil: true` ger platt vit siluett, samma som i dag.
- Pad: avatarer 5 box-enheter (v1: 2), så att drop shadow ryms. **`originY` kommer ur `avatarBakeInfo`**, inte ur `AVATAR_TEX_ORIGIN_Y`.
- Arbetsyta för lagret: `OffscreenCanvas`, annars `<canvas>`. Den kan bytas med `scratch`.
- Alla 5 set och alla 48 kompisar är renderade utan fel.

### 15.6 Prestanda och texturbudget

- **Bakas en gång per textur, aldrig per frame.** Inga `shadowBlur`, gradienter eller filter i `update()`. Samma cache-nycklar som i dag, plus dpr: `ball-{set}-{lvl}@{dpr}` och `av-{id}-{px}@{dpr}`.
- Uppmätt i Chromium på skrivbordsdator: alla 11 nivåer i 3× tar 87 ms, alla 48 kompisar i 40 px 3× tar 84 ms. Räkna med 4–6× längre tid på en billig Android, alltså cirka 0,5 s för ett set. Baka **aktivt set vid boot**, övriga set först när boken visar sidan, och kompisar vid behov, som i dag.
- Minne per set (11 nivåer, RGBA): v1 1× **1,2 MB** · v2 2× **5,2 MB** · v2 3× **11,8 MB**. Den största sidan är 936 px (nivå 10, 3×). `ART.maxTexSide` 1 024 sänker dpr för större texturer. Kompis 40 px 3×: 144² = 81 kB. Öppningen 112 px 3×: 396² = 613 kB. Den tas bort efter öppningen.
- **Budget:** högst 2 set i full upplösning samtidigt (aktivt + glow-varianten), ≤ 24 MB. Bokens små objekt bakas i sin visade storlek. Siluetter kan stanna i 1×, eftersom de är tonade och små.
- **Nedväxling:** om `navigator.deviceMemory ≤ 2`, eller om första nivån tar > 25 ms att baka, används Z = 2. Hjälper inte det används `mode: 'v1'` i Z.

### 15.7 Tillgänglighet

- **Kontrasten mellan ansikte och kropp är minst lika hög som i dag på alla nivåer.** Mätt som median av kroppspixlar 0,1r från varje ink-drag (DPR 2):

| nivå | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| v1 | 13,2 | 9,9 | 12,3 | 11,6 | 8,1 | 5,9 | 5,8 | 6,1 | 5,3 | 14,5 | 11,9 |
| v2 | 13,4 | 10,1 | 12,5 | 12,0 | 8,6 | 6,8 | 6,9 | 7,7 | 6,8 | 15,0 | 12,5 |

  Det beror på två saker: gradientens mittstopp ligger utanför ansiktszonen, och underläppen ljusar upp precis under dragen. En ljusare ink-gradient provades och förkastades, eftersom den sänkte nivå 5 till 3,8:1.
- Konturen har kvar sin bredd och mörka ton i skuggsidan, så siluetten mot bakgrunden är minst lika tydlig. Kulörerna ändras högst ±16 L runt `color`, så nivåernas färgordning är densamma.
- **Ingen ny rörelse, ingen blinkning.** Allt är statiskt och bakat, så flash-guard påverkas inte.
- Objekten får **aldrig** glint i ögonen. Glinten är fortfarande kompisarnas tecken (§13.1). Uppdragets "pupill med highlight" gäller därför bara kompisar.

### 15.8 Öppna frågor

1. **Hi-DPI-canvasen (§15.2) är beslutet som lyfter mest.** Den rör `main.ts`, alla scener (zoom, `worldX`) och Text-upplösningen. Behöver ett beslut från programmeraren och projektledaren, plus ett fillrate-test på billig Android med Z = 2 mot Z = 3.
2. **Specialobjekten (bomb och regnbåge), pärlor, rombar, musslor och partiklar** har ännu inte v2. Renderaren klarar redan `spikes` och `angry`, men inte `bands`. Nästa steg om v2 godkänns.
3. **Glöden kunde ligga utanför texturen**, som en delad tonad `bg-glow`-sprite med ADD. Då krymper nivåtexturerna med cirka 35 % och glöden kan skalas fritt. Det kräver en ändring i scenen.
4. **Hur blank?** Nu är det blank plast. Sätts `spec.dot.alpha` till 0 och `spec.levelSoftAlpha` till 0,25 blir uttrycket mattare, mer som gummi. Det är ett smakval och en enradsändring i `art.ts`.


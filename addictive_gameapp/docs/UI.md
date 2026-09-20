# UI.md – KLUNK visuell spec, ljudkarta och game feel

Version 1.0 · 2026-09-20 · Ägare: ui-designer. Underordnad `DESIGN.md` (spelregler) och `TECH.md` (stack).
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

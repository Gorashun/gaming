# COMBAT_READABILITY.md – stridsskärmens läsbarhet

*Version 1 · 2026-09-21 · Ägare: UI/UX · Status: förslag till PM och dev*

**Problemet, i Anders ord efter speltest 1:** *"Det är svårt att fatta mekaniken."*
(DECISIONS 2026-09-21, blockerande.)

Detta dokument handlar **bara** om att förstå skärmen. Lärkurvan över en hel
första run (vad som introduceras när, staden, tooltips) ägs av rollspelsnörden i
`docs/design/TOWN_AND_ONBOARDING.md`. De två hakar i varandra via §7 nedan.

Referensmaterial: `docs/screenshots/m2/03_combat_before_confirm.png`,
`docs/screenshots/m2/04_combat_mid_chain.png`,
`docs/screenshots/m1_5/02_combat_mid_chain.png`.
Målbild: `design/mockup_combat_v2.html` + `design/screenshots/combat_v2_*.png`.

**Grundtes.** Spelet är redan ärligt – `resolve()` körs på en kopia och det
spelaren ser *är* utfallet (GAME_DESIGN §6). Men ärligheten är skriven på ett
språk ingen nybörjare kan: `5 ×2`, `IN 4`, `⬟ 2 arm`, `0/20`. **Skärmen visar
resultatet av en uträkning utan att visa uträkningen.** Allt nedan är att skriva
ut uträkningen. Inget kräver en enda ändring i `src/core/`.

**Språk.** Mockupen är svensk som övriga `design/`. Källsträngarna i tabellerna
nedan är engelska (CLAUDE.md), svenskan är översättningen i
`assets/i18n/translations.csv`.

---

## 1. Diagnos, uppifrån och ned

Betyg 1–10 = *"kan en spelare som aldrig sett spelet tolka elementet på 5
sekunder utan att någon förklarar?"* 1 = ren hieroglyf, 10 = självklart.
Bedömningen är min egen expertbedömning mot skärmdumparna, inte mätt på
testpersoner – märkt som **uppskattning**.

### 1.1 Toppfältet

| # | Element (som det står idag) | Vad en ny spelare inte kan veta | Betyg |
|---|---|---|---|
| 1 | `◖ 100/100` | Att det är *mitt* liv. Glyfen betyder ingenting. Fungerar ändå tack vare siffrorna. | **6** |
| 2 | Rosa stapel löst placerad ovanför/bredvid | Vems stapel? Den sitter inte ihop med siffran, och på m2-dumpen svävar den centrerat över skärmen. | **3** |
| 3 | `ROOM 1 · R1` | `R1` = runda 1. Ingen möjlighet att gissa. "Rum" betyder heller inget före man sett kartan. | **4** |
| 4 | `⬤0/20` | Inget ord, ingen enhet, inget sammanhang. Står `0` hela första ronden, så den lär sig aldrig av sig själv. **Det enskilt mest obegripliga elementet på skärmen.** | **1** |
| 5 | `⬟ 0` (ward) | Samma sak, plus att femhörningen också används för rustning längre ned – samma glyf, två betydelser. | **1** |
| 6 | ⚙-knappen | Universell. | **9** |

### 1.2 Arenan

| # | Element | Problem | Betyg |
|---|---|---|---|
| 7 | Smeden (hjältesprite) | Inget namn, ingen HP i närheten. Man vet inte att den rosa stapeln längst upp hör till gubben här nere. | **5** |
| 8 | Fiendekorten kontra fiendespritarna | Korten ligger **över** råttornas ben och är bredare än varelserna. Koppling kort↔varelse är gissning, särskilt när fyra identiska råttor står i rad. | **4** |
| 9 | `28 / 28` | Läsbart som HP. | **7** |
| 10 | `⬟ 2 arm` | "arm" är en avhuggen förkortning. Att rustning dras av **per skadeinstans** – spelets viktigaste taktiska regel – syns ingenstans. | **2** |
| 11 | `▲ 3 dmg` | Skada som fienden **gör mot mig**, eller skada **jag gör mot den**? Triangeln avgör inte. Att det händer *efter* min kedja framgår inte. | **3** |
| 12 | `ARMOR 2`-poppen mitt i kedjan (m2/04) | Dyker upp över en fiende utan att något räknestycke är synligt. Ser ut som en bonus, inte som ett avdrag. | **3** |

### 1.3 Förhandsvisningen

| # | Element | Problem | Betyg |
|---|---|---|---|
| 13 | Stora `28` | 28 av vad, mot vem, jämfört med vad? Ingen relation till siffrorna i sloten nedanför (2, 10, 10, 6, 12 → 40). **Spelaren kan inte räkna efter.** | **4** |
| 14 | `damage · 6 dice in the tray` | Två orelaterade fakta i en rad. "6 dice in the tray" är dessutom fel mental modell: fem av dem ligger redan i slots. | **2** |
| 15 | `8 → Rust Rat 8 → Rust Rat 4 → Rust Rat …` | Ingen avdelare mellan segmenten, samma namn fyra gånger (vilken råtta?), summan syns inte, och `…` klipper resten. Raden ser ut som en textbugg. | **2** |
| 16 | Ingen koppling mellan raden och totalen | 8+8+4 = 20 ≠ 28. Ser ut som att spelet räknar fel. | **1** |

### 1.4 Brädet

| # | Element | Problem | Betyg |
|---|---|---|---|
| 17 | `PLAIN` / `MIRROR` / `FIRE` / `ANVIL` | Namn utan regel. `MIRROR` är värst: den ignorerar tärningens eget värde, vilket är helt osynligt (dumpen visar en 1:a i sloten och `5 ×2` under). | **2** (`MIRROR` **1**) |
| 18 | Slot-ikonen 16 px | Formkoden är korrekt designad (§2.4 UI_GUIDE) men den betyder inget förrän man lärt sig den. | **3** |
| 19 | `5 ×2` | Var kommer ×2 ifrån? Vilken annan slot? Vad blir resultatet? Halva räknestycket saknas. | **2** |
| 20 | `= 12` i AMBOSS | Tärningen visar 6, sloten säger 12. Regeln "×2 om ≥5" står ingenstans. | **2** |
| 21 | Sifferraden `1 2 3 4 5` under sloten | Konkurrerar visuellt med tärningsvärdena och används inte av något annat element. | **4** |
| 22 | **Multiplikatorbåge saknas helt** | Wireframen har `×2 PAR`-bågen mellan slots; spelet har den inte. Därmed är parets *orsak* (två lika värden bredvid varandra) osynlig. | **1** |

### 1.5 Brickan och knapparna

| # | Element | Problem | Betyg |
|---|---|---|---|
| 23 | `IN 1` … `IN 5` | Läses som "in 1" = "om 1 runda"? Tärningen ligger dessutom kvar synlig i brickan **och** i sloten – samma tärning på två ställen. | **2** |
| 24 | `DRAG →` | Dra vart? Pilen pekar mot nästa tärning i brickan, inte mot brädet. | **2** |
| 25 | Brickans tärningar ser ut som slot-tärningarna | Ingen tillståndsskillnad mellan "kan användas", "redan använd", "vald". | **3** |
| 26 | `REROLL 1` | Är 1 antal kvar, kostnad, eller vilken tärning? | **5** |
| 27 | `↩ UNDO` | Tydlig. | **8** |
| 28 | `CONFIRM CHAIN · 28` | "Chain" är ett ord spelet aldrig definierat. 28 hänger ihop med den stora 28:an, vilket är bra. | **5** |
| 29 | **Ingen hjälp finns** | Ingen `?`, ingen långtryck-förklaring, ingen kodex-ingång från striden. Fastnar man finns ingen väg ut. | **0** |

### 1.6 Sammanvägt

Viktat medel över de 29 posterna, med de spelbärande (#13–#22) dubbelt viktade:

> **Läsbarhet idag: 3,2 / 10** (uppskattning)
> **Läsbarhet efter §2–§6: ca 7,6 / 10** (uppskattning)

Resten når man inte med grafik. Det som återstår ovanför 8 kräver att spelaren
faktiskt *gör* saker – det är lärkurvans jobb, inte skärmens.

---

## 2. Förhandsvisningen som räkneexempel

**Normativ princip:** *Kedjan ska gå att räkna efter för hand.* Om en spelare
inte kan peka på skärmen och säga "2 plus 10 plus 10 plus 6 plus 12 blir 40,
minus rustning blir 28" har förhandsvisningen misslyckats.

Referensfall genom hela dokumentet (= exakt m2-dumpen, verifierat mot
GAME_DESIGN §2):

```
Bräde  [PLAIN, PLAIN, MIRROR, FIRE, ANVIL]
Placering  2 · 5 · (tärning) · 6 · 6      Oplacerad: 4
Fiender  RUST_RAT ×4, hp 28, armor 2, intent ATTACK 3

P1  2 · 5 · 5 (spegel kopierar slot 2) · 6 · 12 (amboss, 6 ≥ 5)
P2  slot 2+3 har samma värde och står bredvid varandra → PAR ×2
P3  2 · 10 · 10 · 6 · 12  =  40 rå
    2  − 2 rustning = 0   (kedjan stannar)
    10 − 2 = 8   → Råtta 1  28→20
    10 − 2 = 8   → Råtta 1  20→12
    6  − 2 = 4   → Råtta 1  12→8   + brand 2
    12 − 2 = 10  → Råtta 1  8→0 DÖD, 2 spill → Råtta 2, −2 rustning = 0
    Summa skada 28.  Rustning åt upp 12.
P5  oplacerad 4:a → +4 laddning
```

### 2.1 Tre lager, uppifrån och ned

**(a) Meningen.** En rad, centrerad, Anton, ett tal per slot i slotordning med
`+` emellan och `=` före summan. Varje tal har en 8 dp mikroetikett `slot n`
under sig så att blicken kan hoppa mellan mening och bräde.

```
   2   +   10   +   10   +   6   +   12   =   40
 slot1    slot2    slot3   slot4   slot5
```

Färgkodning: tal som fått en multiplikator ritas i multiplikatorfärgen
(`×2` = `#FFD447`, UI_GUIDE §2.5), tal som dubblats av Amboss i `#D7DEE6`.
Tal som blir Ward ritas i `#8A94A6`, tal som blir Laddning i `#FFD447` med
efterställd mikroetikett `→ ward` / `→ laddning`.

**(b) Rustningsraden.** En rad som förklarar skillnaden mellan rått och verkligt:

```
40  − 12 rustning (2 per träff × 6 träffar)  =  28 skada
```

Generell form när brädet innehåller `VOID`/`CHARGE`/spill utan mål:

```
RÅ  =  skada  +  rustning  +  ward  +  laddning  +  spill utan mål
```
Visa bara de termer som är nollskilda. Max tre termer på raden; fler än så
bryts till en andra rad snarare än att förkortas.

**(c) Leveransraden.** En rad per skadeinstans, i resolutionsordning, med
slotens nummerbricka först (samma bricka som på sloten, samma färg):

```
①  2 − 2 = 0     stoppas helt av rustningen
②  10 − 2 = 8    → Rostråtta 1   28 → 20
③  10 − 2 = 8    → Rostråtta 1   20 → 12
④  6 − 2 = 4     → Rostråtta 1   12 → 8   + brand 2
⑤  12 − 2 = 10   → Rostråtta 1 dör · 2 spill → Råtta 2 (stoppas)
```

Regler för raden:
- **Mattedelen är vänsterjusterad i en egen kolumn med tabulärsiffror.** De fem
  minustecknen ska ligga i lodrät linje; det är den lodräta linjen som gör att
  hjärnan ser mönstret "rustning varje gång".
- Fiendenamn numreras (`Rostråtta 1`, `Rostråtta 2`) när flera med samma namn
  finns. Utan numrering är dagens `8 → Rust Rat 8 → Rust Rat` obegripligt.
- Träffar som dödar skrivs `… dör` i `#FF556F`.
- Statuspåslag skrivs som `+ brand 2` i statusens färg, aldrig som ikon ensam.
- Rader som ger 0 skada gråas (`#9A9486`) men **tas aldrig bort** – de är
  lektionen om rustning.
- Max 5 rader (= antal slots) + 1 extra för `DOMINO`. Ingen `…`-klippning.

### 2.2 Vart skadan går

Två redundanta kopplingar, båda nödvändiga:

1. **Leveransremsan** direkt under arenan: en kolumn per fiende, exakt lika bred
   och i exakt samma ordning som fiendekorten, med en uppåtpil och beloppet.
   Träffad fiende får stor pil + stor siffra + `DÖDAR`; överflödsmål får liten
   pil + liten siffra + `SPILL`. Kolumner utan inkommande skada är tomma (håller
   platsen, ingen visuell brus).
2. **Prognosfältet i fiendens HP-stapel:** den del av stapeln som kommer att
   försvinna ritas som diagonalskrafferad ljus yta ovanpå den röda. Är hela
   stapeln skrafferad dör fienden. Detta är den enda "vem dör"-signalen som
   fungerar för färgblinda utan extra text.

Jag valde bort frisvävande kurvade pilar från slot upp till fiende: de korsar
räknestycket, kan inte layoutas robust på fem slots × fyra fiender, och blir
oläsliga i reducerat rörelse-läge. Kolumnjustering + delad nummerbricka bär
samma information utan att korsa något.

### 2.3 Multiplikatorbågar

Bågen ligger **ovanför** slotraden, mellan förhandsvisningen och brädet
(wireframens `×2 PAR`-båge, som aldrig implementerades).

- Spänner över exakt de slots som ingår i gruppen, `border-radius` uppåt,
  2 dp linje i multiplikatorfärgen, kritjitter.
- Etikett centrerad på bågen, med bakgrundsplatta: `×2 PAR · BÅDA 5`.
  Tre delar: multiplikator, gruppnamn, **varför** (det gemensamma värdet).
- `TRIPLE`/`QUAD`/`PENTA` använder samma båge i `#FF8A2C` / `#FF556F` /
  `#FF5CA8` och texten `×4 TRISS · ALLA 4` osv.
- `HOUSE` ritas som en **andra, yttre** båge över hela brädet med texten
  `KÅK ×2 · TRISS + PAR`, i `#FFD447`, 4 dp över de inre bågarna.
- `OCTOPUS`-relikens virtuella kant (1,3) ritas som en streckad båge som hoppar
  över slot 2.
- Bågen animeras **inte** i förhandsvisningen (den ritas direkt), bara i
  uppspelningen (§5.2 UI_GUIDE). Reducerat rörelse: bågen tänds utan att ritas.

Höjdbudget: 20 dp rad. Vid två lager (grupper + `HOUSE`) 32 dp; utrymmet tas
från arenan, aldrig från tumzonen.

### 2.4 Per slot: hela räknestycket, inte halva

I sloten, under tärningen, två rader:

| Rad | Innehåll | Typ | Exempel |
|---|---|---|---|
| Räkning | `bas ×mult = resultat` | `type/label` 14 dp (11 dp på 360) | `5 ×2 = 10` |
| Varför | orsaken, ≤ 12 tecken | 8 dp, `chalk/500` | `par med 3` |

`varför`-texterna: `par med 3` · `kopia av 2` · `6 är 5+` · `+ brand 2` ·
`→ ward` · `→ laddning` · `laddning +7` · `för lågt` (Amboss under 5) ·
`ingen granne` (spegel på slot 1).

`slot_modifier_failed` **ska** synas: idag visar spelet ingenting när Amboss
misslyckas, vilket gör att spelaren inte lär sig tröskeln. `för lågt` i
`#9A9486` under en 3:a i Amboss lär ut regeln på en runda.

### 2.5 Datakällor (inget nytt behövs i core)

| Visning | Event |
|---|---|
| Talen i meningen | `strike.amount` per slot |
| Färg/multiplikator | `combo_formed.multiplier`, `house_bonus.multipliers_after` |
| `bas` i slotens räkning | `value_pass_done.values` |
| `varför` | `slot_modifier`, `slot_modifier_failed`, `combo_formed.slots` |
| Rustningsraden | Σ `damage_dealt.blocked`, Σ `damage_dealt.amount` |
| Leveransraden | `damage_dealt{target, amount, blocked, overflow, target_hp_after}` |
| `… dör` | `enemy_killed` |
| `+ brand 2` | `status_applied` |
| Prognosfält i HP | `damage_dealt.target_hp_after` (sista per fiende) |
| Ward/laddning | `ward_gained`, `charge_stored{source}` |
| `+4 laddning` i brickan | `charge_stored{source:"UNPLACED_DIE"}` |

Allt finns redan i `_preview.events`. Läsbarhetslagret är **ren presentation**.

---

## 3. Slot-etiketter med innebörd

Sloten visar tre rader: **namn** (12 dp, slotfärg), **regel** (11 dp,
`chalk/500`), **räkning** (§2.4). Regelraden är normativ och får aldrig
utelämnas – det är den som ersätter tutorialen.

| Slot | Namn (källa) | Mikrotext, EN (≤ 14 tecken) | Mikrotext, SV | Långtryck (en mening, EN) |
|---|---|---|---|---|
| `PLAIN` | PLAIN | `no effect` (9) | `ingen effekt` | *"Nothing changes here: the die's value goes straight into the chain."* |
| `FIRE` | FIRE | `burn 2 on hit` (13) | `brand 2 vid träff` | *"Every hit from this slot also sets Burn 2 on the target."* |
| `MIRROR` | MIRROR | `copies left` (11) | `kopierar vänster` | *"This slot ignores its own die and copies the value of the slot to its left."* |
| `ANVIL` | ANVIL | `×2 if ≥5` (8) | `×2 om 5+` | *"If the value here is 5 or more it doubles — which can also break a pair."* |
| `CHARGE` | CHARGE | `charge, no dmg` (14) | `laddning, ej skada` | *"The damage from this slot is banked as Charge instead of hitting anyone."* |
| `VOID` | VOID | `ward, no dmg` (12) | `ward, ej skada` | *"The damage from this slot becomes Ward for this round instead of hitting."* |

Tilläggstillstånd:

| Tillstånd | Mikrotext EN | SV | Långtryck |
|---|---|---|---|
| `blocked` (GRAB) | `blocked 1 round` | `blockerad 1 runda` | *"A Grave Hand is holding this slot shut for one round."* |
| Tom slot | `empty` | `tom` | *"An empty slot is inert: no value, no combo, and it breaks the chain of neighbours."* |

Regler:
- Mikrotexten är **≤ 14 tecken** så att den ryms på en rad i en 64 dp slot vid
  textstorlek 100 %. Vid 115 %/130 % tillåts två rader; slotens höjd växer och
  arenan krymper (aldrig tumzonen).
- Långtryck 400 ms → popover ovanför sloten, stängs vid tapp var som helst.
  Samma popover som `?`-lagret använder (§6), så det finns bara en komponent.
- **`MIRROR` kräver en extra visuell signal** eftersom den ignorerar sin egen
  tärning: tärningen i en spegelslot ritas med 55 % opacitet och en liten
  vänsterpil på slotens vänsterkant. Utan det ser `5 ×2 = 10` ut som ett fel när
  tärningen visar 1.

---

## 4. Tärningsbrickan

`IN 4` / `DRAG →` ersätts av en tillståndsmaskin där **platsen i brickan är
tom när tärningen ligger på brädet**. Brickan blir då en korrekt modell av
verkligheten: sex platser, några tomma.

| Tillstånd | Utseende | Etikett EN | SV |
|---|---|---|---|
| **READY** | Full tärningssprite, full opacitet | *(ingen)* – värdet läses på tärningen | – |
| **SELECTED** | Lyft 6 dp, 2 dp gyllene kontur (`#FFD447`), mjuk skugga | `TAP A SLOT` | `VÄLJ SLOT` |
| **PLACED** | **Tom sockel**: streckad ram 2 dp `#2C353F`, spöksilhuett 16 % av tärningskroppen, uppåtpil | `SLOT 4` | `SLOT 4` |
| **LOCKED** | Tärning + kedjeglyf, kan ej omkastas | `LOCKED` | `LÅST` |
| **STOLEN** | Trasig sockel, ingen spöksilhuett | `STOLEN` | `STULEN` |
| **CRACKED** | Tärning + `crack_n.png`, värdet 0 | `CRACKED` | `SPRUCKEN` |

```
   BRICKAN                                   1 kvar = +4 laddning
  ┌ ─ ─ ─ ┐ ┌ ─ ─ ─ ┐ ┌ ─ ─ ─ ┐ ┌ ─ ─ ─ ┐ ┌ ─ ─ ─ ┐  ╔═══════╗
  │   ↑   │ │   ↑   │ │   ↑   │ │   ↑   │ │   ↑   │  ║ ⚄  ⚄ ║ ← lyft 6 dp
  └ ─ ─ ─ ┘ └ ─ ─ ─ ┘ └ ─ ─ ─ ┘ └ ─ ─ ─ ┘ └ ─ ─ ─ ┘  ╚═══════╝
   SLOT 1    SLOT 2    SLOT 3    SLOT 4    SLOT 5     VÄLJ SLOT
```

Kopplingar och rörelse:
- Vid placering **flyger tärningen** från brickan till sloten (140 ms,
  `motion/quick`), och sockeln tonar in på plats. Rörelsen är den billigaste
  förklaringen av "samma tärning, ny plats". Reducerat rörelse: ingen flygning,
  sockeln byts direkt, uppåtpilen blinkar en gång (opacitet 0→1, 120 ms).
- **Tomma slots pulsar när en tärning är vald:** kontur `#FFD447`, skala
  1,00 → 1,04, 1 200 ms loop, faseförskjutning 80 ms per slot vänster→höger
  (vilket samtidigt lär ut kedjans riktning). Blockerade slots pulsar aldrig och
  får en tydlig `blockerad 1 runda`-text.
  Reducerat rörelse: ingen puls, i stället statiskt 2 dp gyllene kontur på alla
  giltiga slots.
- Tapp på en sockel = ta tillbaka tärningen till brickan (samma sak som ångra
  för just den tärningen). Tapp på sockeln är i dag odefinierat.
- Träffytan är **hela cellen** (54 × 54 dp, minst 48 × 48), inte sprajten.
- Brickans rubrik bär den enda kvarvarande siffran som behövde en förklaring:
  `1 kvar = +4 laddning`. Den förklarar Laddning första gången spelaren ser
  den, utan tooltip.

---

## 5. Fiendezonen

| Idag | Nytt |
|---|---|
| `⬟ 2 arm` | `🛡 Rustning 2` – ikon **och** ord, aldrig förkortat |
| `▲ 3 dmg` | `⚔ Slår 3` (`Attacks 3`) – verb, så att riktningen framgår |
| – | Prognosfält i HP-stapeln (diagonalskraffering = detta försvinner) |
| – | Leveransremsa under arenan, kolumnjusterad med fienden |
| `ARMOR 2`-pop | Behålls, men **efter** att räknestycket visat samma avdrag; poppen blir en bekräftelse, inte en nyhet |

Källsträngar (engelska, via `tr()`):

| Nyckel | EN | SV |
|---|---|---|
| `ENEMY_ARMOR` | `Armor %d` | `Rustning %d` |
| `ENEMY_INTENT_ATTACK` | `Attacks %d` | `Slår %d` |
| `ENEMY_INTENT_BLOCK` | `Hardens +%d` | `Härdar +%d` |
| `ENEMY_INTENT_SPECIAL` | `%s` (intentens `note`) | `%s` |
| `ENEMY_THORNS` | `Thorns %d` | `Taggar %d` |
| `ENEMY_BURN` | `Burn %d` | `Brand %d` |
| `ENEMY_POISON` | `Poison %d` | `Gift %d` |

Layoutkrav:
- Kortet är **lika brett som sin varelse-kolumn** och sitter rakt ovanför den,
  utan att täcka fötterna. På m2-dumpen ligger korten omlott med spritarna;
  det ensamt förklarar en del av förvirringen med fyra identiska råttor.
- Flera fiender med samma namn numreras `Rostråtta 1 … 4` från fronten. Numret
  används i leveransraden.
- Rustning står **ovanför** intent: rustning påverkar det spelaren gör härnäst,
  intent det som händer sedan. Läsordningen följer tidsordningen.
- Armor-avdraget visas alltid i förhandsvisningen (§2.1b och §2.1c). Detta är
  den enskilt viktigaste ändringen för att `IRON_TICK` (armor 6) ska kännas som
  ett pussel i stället för en bugg.

---

## 6. Hjälp-lagret (`?`)

En `?`-knapp, 48 × 48 dp, i toppfältet till vänster om kugghjulet, kontur i
`#FFD447`.

- **Tänder alla förklaringar samtidigt.** Bakgrunden dimmas till 80 % svart,
  6 callouts tänds, var och en med RUBRIK + **en** mening och en streckad
  ledarlinje till sitt element. Inga steg, ingen "nästa"-knapp, ingen ordning.
- **Stängs vid tapp var som helst.** Hela lagret är en stängknapp.
- **Pausar ingenting** – förhandsvisningen är statisk, så lagret kan inte
  missa något. Öppnas den under uppspelning pausas uppspelningen på nuvarande
  event och återupptas vid stängning.
- **Reducerad rörelse:** ingen inflygning, ingen skala. Bara opacitet 0 → 1 på
  200 ms för hela lagret, ledarlinjerna ritas statiskt.
- Färg bär ingen information: gul kontur + svart platta + vit text ger 12:1.
- `?` pulsar en gång (opacitet, ej skala) efter spelarens **tredje** runda i
  första striden om ingen kedja ännu bekräftats – därefter aldrig igen.

De sex meningarna (svensk mockup; engelskan är källan):

| Rubrik | Mening |
|---|---|
| Laddning | Tärningar du inte lägger ut blir laddning. Nästa runda läggs den ovanpå din vänstraste tärning. |
| Räknestycket | Vänster till höger, slot för slot. Exakt det här händer när du trycker Bekräfta – ingen slump kvar. |
| Fienden | Rustning dras av varje gång något träffar. "Slår 3" är vad den gör mot dig när din kedja är klar. |
| Brädet | Bågen betyder att två lika värden bredvid varandra dubblas – tre i rad ger ×4. Texten under slotens namn är hela slotens regel. |
| Brickan | Tomma platser = tärningar som redan ligger på brädet. Tryck på en tärning och sedan på en slot. |
| Bekräfta | Siffran på knappen är skadan du får. Sedan slår fienderna tillbaka. |

Max **6** callouts. Fler får inte plats på 360 dp utan att täcka varandra, och
sju meningar är inte längre en hjälp utan en manual. Långtryck på enskilda
element (§3) är fördjupningen.

---

## 7. Onboarding-hooks (progressiv avslöjning)

Dev får en ren visningsflagga per element. **Regeln:** ett element får bara
döljas när det är *tomt eller overksamt i tillståndet* – UI ljuger aldrig om
spelets tillstånd, och ingen spellogik flyttar in i UI-lagret.

| Flagga | Döljer | Tänds av | Villkor för att få döljas |
|---|---|---|---|
| `show_charge` | Laddningsmätaren i HUD + `→ laddning`-texter | Första `charge_stored`-eventet spelaren ser | `state.charge == 0` och inga `CHARGE`-slots på brädet |
| `show_ward` | Ward-mätaren | Första `ward_gained` | `state.ward == 0` och ingen `VOID`-slot på brädet |
| `show_reroll` | Omkast-knappen | Rum 2, eller när `rerolls_left > 0` första gången | `rerolls_left == 0` |
| `show_relics` | Relikbrickan i HUD | Första reliken | `relics.is_empty()` |
| `show_slot_rules` | Regelraden i sloten | Alltid på | – (får aldrig döljas) |
| `show_arcs` | Multiplikatorbågar | Alltid på | – |
| `show_routes` | Leveransraden | Alltid på | – |
| `help_pulse` | Engångspuls på `?` | Se §6 | – |

**Slot-typer:** UI döljer aldrig en slot-typ. Progressionen sker genom att
rum 1 har brädet `[PLAIN, PLAIN, PLAIN, PLAIN, PLAIN]` och att `MIRROR`/`FIRE`/
`ANVIL` kommer in via brädet i senare rum – det är ett **innehållsbeslut** som
ägs av GAME_DESIGN/rollspelsnörden, inte av UI. Jag flaggar det som en
rekommendation till `TOWN_AND_ONBOARDING.md`: *fem `PLAIN` i rum 1 gör
räknestycket till `2 + 5 + 3 + 6 + 4 = 20` – den enklaste möjliga meningen –
och låter paret vara den enda nya regeln under första striden.*

Ordning jag föreslår att lärkurvan introducerar i: **(1)** placera → se summa,
**(2)** par → båge ×2, **(3)** rustning → varför fem små slag är sämre än ett
stort, **(4)** oplacerad tärning → laddning, **(5)** slot-typer, **(6)** omkast.

Tooltips: oförändrat max 3 i första striden (UI_GUIDE §7). Räknestycket gör
tooltip 2 och 3 nästan överflödiga; de får stå kvar som säkerhetsnät och tas
bort först när någon faktiskt testat spelet utan dem.

---

## 8. Tillgänglighet och verifiering

- **Kontrast:** all ny text är `chalk/100` (`#F2EDE3`) eller `chalk/300` på
  `#0E1216`–`#1F262E`, dvs. ≥ 9:1. Den gråade nollraden i leveransraden är
  `chalk/500` på `#1F262E` = 4,7:1 (över 4.5:1-kravet).
- **Färgblindhet:** varje färgburen signal har en textdubblett – `×2` står som
  siffra, `dör` som ord, prognosfältet som skraffering, rustning som tal i
  räknestycket. Ingen ny informationsbärande färg införs.
- **Textstorlek 85/100/115/130 %:** räknestyckets mening bryts aldrig; vid
  130 % faller `slot n`-mikroetiketterna bort först, sedan kortas `varför`-
  raden i sloten. Leveransraden bryter till två rader per instans.
- **Reducerad rörelse:** puls, flygning och bågritning ersätts av statiska
  tillstånd enligt §4 och §6. Tidslinjen ändras inte (DECISIONS 2026-09-21).
- **Tumzon:** allt nytt (räknestycke, bågar) är läs-endast och ligger *ovanför*
  brädet. Interaktionen ligger kvar i de nedersta 42 % av skärmen.

**Verifierat 2026-09-21** (Chromium headless, deviceScaleFactor 2,
`design/mockup_combat_v2.html`):

| Vy | 360×640 | 390×844 | 430×932 |
|---|---|---|---|
| Strid v2 | ingen scroll | ingen scroll | ingen scroll |
| Strid v2 + hjälplager | – | ingen scroll | – |

På 360×640 krymper arenan till 104 dp och tärningarna till 42 dp visuellt
(cellen är fortfarande 48 dp träffyta). Räknestycket behåller full höjd –
det prioriteras före arenan, eftersom det är det som lär ut spelet.

---

## 9. Vad som kräver nya assets

| Behov | Status |
|---|---|
| Rustningsikon (sköld, 16×16) | **Ny.** Används i fiendekortet, ersätter `⬟` som är upptagen av Ward |
| Intent-ikon attack (svärd/klo, 16×16) | **Ny.** `▲` är i dag både intent och "uppåt" |
| Laddningsikon (fylld cirkel, 16×16) | Finns som `slot_charge.png`, kan återanvändas i HUD |
| Uppåtpil till tom sockel (16×16) | Kan ritas som `Line2D`/glyf, ingen sprite behövs |
| Multiplikatorbåge | Ren `Line2D` + `chalk.gdshader`, ingen sprite |
| Prognosfält i HP-stapel | Ren shader/rect, ingen sprite |
| Spöksilhuett i sockeln | Återanvänder `die_body_*.png` med 16 % alpha |

Alltså: **två nya 16×16-ikoner** (rustning, attack), allt annat byggs av
befintliga assets och primitiver. Båda kan genereras av
`tools/gen_pixel_assets.py` i samma palett.

---

## 10. Öppna frågor

1. Ska rum 1 ha fem `PLAIN`-slots (§7)? Innehållsbeslut – PM + rollspelsnörd.
2. Fiendenumrering `Rostråtta 1 … 4`: ska den synas i fiendekortet också, eller
   bara i leveransraden? Jag föreslår bara i leveransraden; kortens ordning
   vänster→höger räcker som referens och sparar 9 dp höjd.
3. Ska `?`-lagret ha en länk till kodexen? Jag föreslår nej i M5 – en knapp som
   lämnar striden mitt i en runda är ett nytt tillståndsproblem.

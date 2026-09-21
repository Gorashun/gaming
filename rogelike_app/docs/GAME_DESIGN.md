# PIPWRECK – GAME_DESIGN.md v1

*Författare: rpg-nerd-roguelike · 2026-09-21 · Status: **normativ spec för M0/M1**.*
*Beslutsunderlag: `docs/PROPOSAL.md`, `docs/research/03_koncept_och_community.md`. Beslut: koncept B, titel PIPWRECK, Godot 4.6.*

## Hur du läser detta dokument

- Allt i **§2 (regelspec)** och **§6 (heliga regeln)** är **NORMATIVT**. Ändring kräver nytt beslut i `DECISIONS.md`.
- Allt i **§4 (innehåll)** är **TUNINGBART**: siffrorna är v1-gissningar. Run-simulatorn i §5 får ändra dem fritt utan designbeslut, så länge §5:s målsiffror nås. Vad som är låst respektive fritt står i §4.8.
- Alla identifierare är på engelska i `backticks` och ska användas ordagrant i koden.
- Där research 03 var vag har jag **bestämt** och markerat det med **[BESLUT v1]**. Öppna frågor ligger i §7.

---

## 1. Kärnloop och runstruktur

```
~30 s   RUNDA:   rulla 6 tärningar → placera upp till 5 i brädets slots (fri ångra)
                 → förhandsvisa hela kedjan → bekräfta → kedjan spelas upp → fiendens svar
~4 min  STRID:   3–6 rundor → belöningsval 1 av 3 → nästa rum
~15 min RUN:     12 rum, 3 våningar à 4 rum. Rum 4/8/12 = boss. Ödeskast efter rum 4 och 8.
~1 h    META:    2–4 runs → ny tärningstyp / klass / Kodex-post (horisontellt, aldrig statboost)
```

**Runstruktur (normativ, M1 använder bara våning 1):**

| Rum | Våning | Typ |
|---|---|---|
| 1, 2, 3 | 1 | `COMBAT` |
| 4 | 1 | `BOSS` → därefter `FATE_ROLL` (Ödeskast) |
| 5, 6, 7 | 2 | `COMBAT` |
| 8 | 2 | `BOSS` → därefter `FATE_ROLL` |
| 9, 10, 11 | 3 | `COMBAT` |
| 12 | 3 | `BOSS` → run vunnen |

- **Omkast:** `rerolls_per_round` kommer från klassen (Smeden: 1). Max 2 utan reliker. Omkast sker *före* bekräftelse och är ren input-slump.
- **Autosave:** hela `RunState` + `CombatState` + RNG-tillstånd serialiseras efter varje `round_end` och efter varje belöningsval. Krasch återupptas vid rundans början, aldrig mitt i en kedja.
- **Andrum:** efter varje vunnen `COMBAT` (ej `BOSS`) läker spelaren `4` HP automatiskt innan belöningsvalet. Emit `heal{source: "BREATHER"}`.
- **Död:** run avslutas, spelaren får meta-poäng (innehåll, aldrig styrka). Ingen continue, inga revives, ingen annons.

---

## 2. Formell regelspec för en runda (NORMATIV)

### 2.1 Datamodell

Allt nedan ligger i `src/core/` och har noll Node-beroenden.

```gdscript
enum DieMaterial { IRON, BONE, GLASS }          # M1: bara IRON
enum SlotType    { PLAIN, FIRE, MIRROR, ANVIL, CHARGE, VOID }
enum ComboKind   { NONE, PAIR, TRIPLE, QUAD, PENTA }
enum IntentKind  { ATTACK, BLOCK, SPECIAL }
enum FaceEffectKind {
    NONE,
    COPY_LEFT,        # P1: värdet blir vänstergrannens effektiva värde
    ANVIL_SELF,       # P1: dubblar om effektivt värde >= 5
    LOCKED,           # roll-fas: tärningen kan inte kastas om
    APPLY_POISON,     # P3
    APPLY_BURN,       # P3
    LIFESTEAL,        # P3
    GROW,             # P5: ökar permanent (strid) om tärningen var oplacerad
    REFUND_REROLL,    # roll-fas: +1 omkast denna runda
}
```

```
Face:
  id: StringName          # t.ex. &"POISON_DROP"
  value: int              # 0..9
  effect: FaceEffectKind  # NONE om ingen
  magnitude: int          # 0 om effect == NONE
  base_value: int         # orginalvärdet, för GROW-återställning

Die:
  id: StringName          # unik inom runt, t.ex. &"die_0"
  material: DieMaterial
  faces: Array[Face]      # EXAKT 6, index 0..5
  integrity: int          # antal sprickor kvar innan förstörd. IRON/BONE = -1 (odödlig), GLASS = 3
  cracks: int             # antal spruckna sidor
  showing: int            # index 0..5, vilken sida som ligger upp efter kastet

Slot:
  index: int              # 0..4
  type: SlotType
  blocked: bool           # true = behandlas exakt som tom, kan ej ta emot tärning

Board:
  slots: Array[Slot]      # EXAKT 5, slots[i].index == i

Enemy:
  id: StringName
  name: String
  hp: int
  max_hp: int
  armor: int              # dras av per damage_dealt-instans
  thorns: int             # skada till spelaren per damage_dealt med dealt > 0
  burn: int               # stacks
  poison: int             # stacks
  intent: Intent          # ALLTID synlig före bekräftelse
  special: StringName     # NONE om ingen

Intent:
  kind: IntentKind
  value: int
  note: String            # UI-text, t.ex. "Griper slot 3"

Relic:
  id: StringName
  rarity: Rarity

CombatState:
  board: Board
  dice: Array[Die]
  placement: PackedInt32Array   # längd 5. placement[i] = index i dice[], eller -1 = tom
  enemies: Array[Enemy]         # ordnad front→bak. index 0 = frontmost
  player_hp: int
  player_max_hp: int
  ward: int                     # nollställs vid round_end
  charge: int                   # 0..CHARGE_CAP, överlever mellan rundor, nollställs vid stridens slut
  rerolls_left: int
  round: int                    # 1-indexerad
  relics: Array[Relic]
  stolen: Array[StringName]     # die_id som är stulna just nu
```

**Konstanter (normativa):**
```
CHARGE_CAP           = 20
ANVIL_THRESHOLD      = 5
MULT_PAIR            = 2
MULT_TRIPLE          = 4
MULT_QUAD            = 8
MULT_PENTA           = 16
HOUSE_FACTOR         = 2
OVERFLOW_TO_CHARGE   = 2      # floor(spilld skada / 2) blir Charge
BREATHER_HEAL        = 4
```

### 2.2 `resolve()` – signatur och renhet

```gdscript
# src/core/resolve.gd
static func resolve(state: CombatState, placement: PackedInt32Array) -> ResolveResult
# ResolveResult: { events: Array[Dictionary], state_after: CombatState }
```

- `resolve()` tar **ingen RNG**. Den är en ren funktion: samma `state` + `placement` ⇒ byte-identisk `events`.
- `resolve()` muterar aldrig `state`. Den arbetar på en djup kopia och returnerar `state_after`.
- All slump som behövs för *nästa* runda dras i en separat funktion:
  ```gdscript
  static func advance(state_after: CombatState, rng: RngStream) -> CombatState
  ```
  `advance()` rullar tärningarna, väljer fiendeintents, väljer `GRAB`-slot och `STEAL`-mål. Resultatet visas i UI **innan** nästa bekräftelse. Se §6.

### 2.3 Fasordning i en runda (normativ)

En runda resolvas i fem faser. Faserna körs alltid i denna ordning och i sin helhet innan nästa börjar.

```
P0  ROUND_START     Ladda ur Charge-poolen
P1  VALUE PASS      slot 0→4: beräkna effective_value[i]
P2  COMBO PASS      hela brädet: hitta grupper, sätt multiplier[i]
P3  STRIKE PASS     slot 0→4: skada, överflöd, statuseffekter, ward
P4  ENEMY PASS      fiender agerar i listordning, statusar tickar
P5  ROUND_END       oplacerade tärningar → Charge, GROW, ward nollställs, städning
```

> **Varför två pass före skadan:** Spegelslots och Charge måste kunna *skapa* kombinationer (moment "Spegelkåken"), och Amboss måste kunna *förstöra* dem. Båda är avsiktliga. Därför beräknas alla värden klart innan kombinationer letas, och all skada delas ut efter det.

---

### P0 – ROUND_START

1. Emit `round_start`.
2. Om `charge > 0`:
   - Hitta **leftmost occupied slot** = lägsta `i` där `placement[i] != -1` och `slots[i].blocked == false`.
   - Om ingen sådan slot finns: Charge ligger kvar orörd till nästa runda. Emit `charge_held`.
   - Annars: `bonus[i] = charge`, `charge = 0`. Emit `charge_applied{slot, amount}`.
3. `bonus[j] = 0` för alla andra `j`.

**[BESLUT v1]** Charge läggs på den *vänstraste besatta* sloten, inte på slot 0. Skälet: slot 0 kan vara tom eller `blocked`, och spelaren ska aldrig förlora sin bank på grund av en teknikalitet. Bonusen syns i förhandsvisningen och är därför ett planeringsverktyg, inte en överraskning.

---

### P1 – VALUE PASS

För `i` från `0` till `4`, i ordning. `effective_value[i]` beräknas och är läsbar för slot `i+1`.

```
Om slots[i].blocked == true ELLER placement[i] == -1:
    effective_value[i] = 0
    occupied[i] = false
    emit slot_empty{slot: i}
    fortsätt till nästa slot

occupied[i] = true
die  = dice[placement[i]]
face = die.faces[die.showing]
emit die_activated{slot: i, die_id, face_index: die.showing, base_value: face.value}

v = face.value + bonus[i]

# Steg 1 – kopiering (face före slot; en slot kan bara ha en typ)
om face.effect == COPY_LEFT:
    src = (i > 0) ? effective_value[i-1] : 0
    om i == 0: emit slot_modifier_failed{slot:i, modifier:"COPY_LEFT", reason:"NO_LEFT_NEIGHBOUR"}
    v = src + bonus[i]
    emit slot_modifier{slot:i, modifier:"COPY_LEFT", value_before: face.value, value_after: v}

om slots[i].type == MIRROR:
    src = (i > 0) ? effective_value[i-1] : 0
    om i == 0: emit slot_modifier_failed{slot:i, modifier:"MIRROR", reason:"NO_LEFT_NEIGHBOUR"}
    v = src + bonus[i]
    emit slot_modifier{slot:i, modifier:"MIRROR", value_before: face.value, value_after: v}

# Steg 2 – relik BROKEN_SCALE
om relik BROKEN_SCALE finns och v är udda:
    v = v + 1
    emit relic_triggered{relic:"BROKEN_SCALE", detail:{slot:i, value_after:v}}

# Steg 3 – dubbling, slot före sida, varje källa prövas EN gång i tur och ordning
om slots[i].type == ANVIL:
    om v >= ANVIL_THRESHOLD: v = v * 2; emit slot_modifier{slot:i, modifier:"ANVIL", ...}
    annars:                  emit slot_modifier_failed{slot:i, modifier:"ANVIL", reason:"VALUE_BELOW_5"}

om face.effect == ANVIL_SELF:
    om v >= ANVIL_THRESHOLD: v = v * 2; emit slot_modifier{slot:i, modifier:"ANVIL_SELF", ...}
    annars:                  emit slot_modifier_failed{slot:i, modifier:"ANVIL_SELF", reason:"VALUE_BELOW_5"}

effective_value[i] = v
```

Efter loopen: `emit value_pass_done{values: effective_value}`.

**Kantfall, explicit (normativa):**

| Fall | Utfall |
|---|---|
| `MIRROR` på slot 0 | `effective_value = 0 + bonus[0]`. Emit `slot_modifier_failed{reason:"NO_LEFT_NEIGHBOUR"}`. Tärningen är förbrukad, inget händer. |
| `MIRROR` med tom slot till vänster | Kopierar `0`. Samma sak, men `reason:"LEFT_NEIGHBOUR_EMPTY"`. |
| `MIRROR` med tärning i sig | Tärningens eget `face.value` **ignoreras helt**. Sloten kräver ändå en tärning. |
| **Tom slot** (eller `blocked`) | Helt inert. Ger inget värde, deltar inte i kombinationer och **bryter angränsning**. Gäller ALLA slot-typer. |
| `ANVIL` med värde < 5 | Ingen dubbling, ingen straffeffekt. `slot_modifier_failed`. |
| `ANVIL` + `ANVIL_SELF` på samma tärning | Två separata kontroller. En 5:a: 5 → 10 → 20. En 3:a: 3 → misslyckas → 3 → misslyckas. |
| `ANVIL` bryter ett par | **Avsiktligt.** En 6:a i Amboss blir 12 och parar sig inte längre med en 6:a bredvid. Detta är spelets viktigaste fälla. Se exempel 6. |
| Två `MIRROR` i rad | Andra speglar första, som i sin tur speglade sin vänstergranne. Kedjar korrekt eftersom P1 går vänster→höger. |
| `bonus` på en `MIRROR`-slot | Adderas ovanpå det kopierade värdet. Charge går aldrig förlorad. |

---

### P2 – COMBO PASS

Arbetar enbart på `effective_value[]` och `occupied[]`. Skada finns inte ännu.

**Definitioner (normativa):**
- **Eligible slot:** `occupied[i] == true` OCH `effective_value[i] > 0`. En slot med effektivt värde 0 deltar inte och bryter angränsning.
- **Angränsande:** `i` och `i+1` är angränsande. Inget annat. `OCTOPUS`-reliken lägger till den virtuella kanten `(1,3)` — se §4.5.
- **Identiska:** exakt heltalslikhet i `effective_value`. **Värde, inte sida, inte tärning.** En naturlig 6, en speglad 6, en Amboss-dubblad 3→6 och en laddad 4+2=6 är alla identiska.
- **Grupp:** en *maximal* sammanhängande följd av eligible slots med samma `effective_value`, längd ≥ 2. Maximal betyder att den inte kan förlängas åt något håll.

**Multiplikatortabell:**

| Gruppstorlek | `ComboKind` | Svenska | Multiplikator |
|---|---|---|---|
| 2 | `PAIR` | Par | ×2 |
| 3 | `TRIPLE` | Triss | ×4 |
| 4 | `QUAD` | Fyrtal | ×8 |
| 5 | `PENTA` | Femtal | ×16 |
| 1 | `NONE` | – | ×1 |

För varje grupp i stigande ordning efter lägsta slotindex: `emit combo_formed{kind, multiplier, slots, value}`.

**`HOUSE` (kåk), brädnivå:** om brädet innehåller **minst en grupp av storlek 3 OCH minst en grupp av storlek 2** (olika grupper, värdena får vara olika), multipliceras *varje* grupps multiplikator med `HOUSE_FACTOR = 2`.
`emit house_bonus{groups: [...], factor: 2, multipliers_after: [...]}`.

**`BLOOD_PRICE` (relik):** om minst en grupp finns, förlorar spelaren 4 HP och varje grupps multiplikator multipliceras med 2. Emit `relic_triggered{relic:"BLOOD_PRICE", ...}` följt av `player_damaged`. Utlöses aldrig när inget combo finns — du betalar bara när det lönar sig.

Ordningen är alltid: basmultiplikator → `HOUSE` → `BLOOD_PRICE`. Teoretiskt tak: 16 × 2 × 2 = **×64**.

Slots utanför alla grupper får `multiplier[i] = 1`.

**[BESLUT v1]** "Kåk" är **inte** Yatzy-kåk och kräver inte samma värde. Två par (`PAIR` + `PAIR`) ger *ingen* brädbonus i v1 — det är en kandidat för M3 (`TWO_PAIR`). Skälet: en enda brädnivå-regel räcker för att göra Spegel-byggen explosiva, och två regler samtidigt gör förhandsvisningen svårläst på 6".

---

### P3 – STRIKE PASS

För `i` från `0` till `4`, i ordning. Hoppa över slots där `occupied[i] == false`.

```
amount = effective_value[i] * multiplier[i]
emit strike{slot: i, amount: amount, multiplier: multiplier[i]}

om slots[i].type == VOID:
    ward += amount
    emit ward_gained{slot:i, amount:amount, ward_total:ward}
    fortsätt

om slots[i].type == CHARGE:
    store_charge(amount, "CHARGE_SLOT")
    fortsätt

om amount == 0:
    fortsätt                      # fizzle. die_activated + strike har redan ritats.

apply_damage(i, amount)
```

**`apply_damage(slot, incoming)` – överflödsalgoritmen (normativ):**

```
while incoming > 0:
    target = första fienden i enemies[] med hp > 0
    om target == null:
        emit overflow_wasted{slot: slot, amount: incoming}
        store_charge(floor(incoming / OVERFLOW_TO_CHARGE), "OVERFLOW")
        break

    effective = max(0, incoming - target.armor)
    blocked   = incoming - effective
    dealt     = min(effective, target.hp)
    target.hp -= dealt
    overflow  = effective - dealt

    emit damage_dealt{slot, target: target.id, amount: dealt, blocked: blocked,
                      overflow: overflow, target_hp_after: target.hp}

    om dealt > 0:
        on_hit_effects(slot, target)          # se nedan
        om target.thorns > 0:
            spelaren tar target.thorns skada
            emit enemy_thorns{enemy: target.id, amount: target.thorns, player_hp_after: ...}
            om player_hp <= 0: emit player_died; AVBRYT HELA RESOLUTIONEN

    om target.hp <= 0:
        emit enemy_killed{target: target.id, slot: slot}

    incoming = overflow
```

**`on_hit_effects(slot, target)`** – körs en gång per `damage_dealt` med `dealt > 0`:

1. Om `slots[slot].type == FIRE`: `target.burn += 2`. Emit `status_applied{status:"BURN", stacks:2}`.
2. Om sidans effekt är `APPLY_POISON`: `target.poison += magnitude`. Emit `status_applied{status:"POISON"}`.
3. Om sidans effekt är `APPLY_BURN`: `target.burn += magnitude`. Emit `status_applied{status:"BURN"}`.
4. Om sidans effekt är `LIFESTEAL`: `heal = min(floor(dealt * magnitude / 100), 8)`; spelaren läker, cappat på `player_max_hp`. Emit `heal{target:"player", amount, source:"LIFESTEAL"}`.
5. `ECHO_MIRROR`-reliken: en `MIRROR`-slot ärver vänstergrannens `FaceEffectKind` + `magnitude` för punkt 2–4.

**`store_charge(amount, source)`:**
```
om amount <= 0: return
before = charge
charge = min(CHARGE_CAP, charge + amount)
emit charge_stored{amount: charge - before, source: source, pool_after: charge}
om charge - before < amount:
    emit charge_capped{lost: amount - (charge - before)}
```

**`DOMINO`-reliken:** efter att alla fem slots resolverats, hitta sloten med högst `amount` (lägst index vid lika). Om den sloten har en granne till höger som är `occupied`, resolveras den grannen en gång till med `floor(amount_granne / 2)`. Emit `relic_triggered{relic:"DOMINO", detail:{source_slot, repeat_slot, amount}}` följt av vanliga `damage_dealt`-event. Utlöses **en gång per runda**, kaskader inte.

**Kantfall:**

| Fall | Utfall |
|---|---|
| Överflöd men alla fiender döda | `overflow_wasted` + `floor(x/2)` till Charge. |
| `incoming <= target.armor` | `dealt = 0`, `overflow = 0`, `blocked = incoming`. Ingen thorns, ingen on-hit, kedjan stannar. |
| `VOID` i ett combo | Ja, `VOID` deltar i P2 som vanligt. Multiplikatorn går till Ward. Avsiktligt: det gör defensiva byggen möjliga. |
| `CHARGE`-slot i ett combo | Samma sak, multiplicerad Charge. Cappas av `CHARGE_CAP`. |
| `MIRROR` som kopierar en `VOID`-slot | Ja. `MIRROR` läser `effective_value`, inte "hur värdet används". |
| Spelaren dör mitt i kedjan (thorns) | `player_died` emitteras och resolutionen avbryts **omedelbart**. Inga fler event. |

---

### P4 – ENEMY PASS

För varje fiende i `enemies[]` i listordning, hoppa över döda.

```
emit enemy_turn_start{enemy, intent}

om intent.kind == ATTACK:
    raw       = intent.value
    ward_used = min(ward, raw)
    ward     -= ward_used
    taken     = raw - ward_used
    player_hp -= taken
    emit enemy_attacks{enemy, raw, ward_used, amount: taken, player_hp_after}
    om player_hp <= 0: emit player_died; AVBRYT

om intent.kind == BLOCK:
    enemy.armor += intent.value
    emit enemy_special{enemy, special:"HARDEN", detail:{armor_after}}

om intent.kind == SPECIAL:
    kör enemy.special (se §4.4). emit enemy_special{...}
```

Därefter, för varje levande fiende i listordning, statustick:

```
om burn > 0:
    hp -= burn                        # burn spiller ALDRIG över till nästa fiende
    emit status_ticked{status:"BURN", amount: burn, target_hp_after, stacks_after: burn-1}
    burn -= 1
om poison > 0:
    hp -= poison                      # poison spiller ALDRIG över
    emit status_ticked{status:"POISON", amount: poison, target_hp_after, stacks_after: poison}
    # poison avtar INTE
om hp <= 0: emit enemy_killed{target, slot: -1}
```

**[BESLUT v1]** Burn är stort och avtar med 1 per runda. Poison är litet och avtar aldrig. Det ger två tydligt olika kurvor: Eld för snabba strider, Gift för bossar. Ingen av dem spiller över — bara direktskada gör det. Annars blir Gift + Överflöd en oändlig kedja, vilket jag testade på pappret och det är trasigt.

---

### P5 – ROUND_END

I denna ordning:

1. Alla tärningar som **inte är placerade i någon slot** (`die_index` finns inte i `placement`) och inte är stulna:
   `store_charge(die.faces[die.showing].value, "UNPLACED_DIE")`.
   **Definition av "oanvänd" (normativ):** en tärning är oanvänd om spelaren vid bekräftelsen inte lagt den i någon slot. Detta är den enda definitionen. En tärning i en `blocked` slot kan inte förekomma (UI förhindrar placeringen). En tärning som fizzlade i en `MIRROR` på slot 0 räknas som **använd** och ger ingen Charge.
2. För varje oanvänd tärning vars sida har `GROW`: `face.value = min(9, face.value + magnitude)`. Emit `face_grew{die_id, face_index, new_value}`. Återställs till `base_value` när striden slutar.
3. `ward = 0`.
4. Fiendespecials som utlöses vid rundans slut (`STEAL`, `GRAB`) körs här; deras mål är redan valda av `advance()` föregående runda och har varit synliga. Emit `die_stolen` / `enemy_special{special:"GRAB"}`.
5. Om alla fiender är döda: `emit combat_won{rounds, total_damage}`.
6. `emit round_end{round, player_hp, charge, enemies_alive}`.

---

### 2.4 Åtta räkneexempel (gör dessa till tester rakt av)

Om inget annat sägs: standardbräde **`[PLAIN, PLAIN, MIRROR, FIRE, ANVIL]`**, 6 tärningar, inga reliker, `charge = 0`, `ward = 0`.

---

**Exempel 1 — Baskedja, par via spegel, kill + spill utan mål**
*Input:* placement-värden `[2, 3, (tärning 4 i MIRROR), 1, 6]`, oplacerad tärning visar `5`.
Fiender: `RUST_RAT` hp 14, armor 0.

- P1: `s0=2`, `s1=3`, `s2=MIRROR→3` (den placerade 4:an ignoreras), `s3=1`, `s4=6≥5→12`.
  `values = [2, 3, 3, 1, 12]`
- P2: maximal grupp `[1,2]` värde 3, längd 2 → `PAIR ×2`. Ingen `HOUSE`.
- P3:
  - s0: `2×1 = 2` → RUST_RAT 14→12
  - s1: `3×2 = 6` → 12→6
  - s2: `3×2 = 6` → 6→0, `enemy_killed`, overflow 0
  - s3: `1×1 = 1`, inget mål → `overflow_wasted{1}`, Charge `+floor(1/2)=0`
  - s4: `12×1 = 12`, inget mål → `overflow_wasted{12}`, Charge `+6`
- P5: oplacerad tärning 5 → Charge `+5`. **Charge = 11.**
- *Förväntat:* `combat_won`, total skada mot fiender = 14.

---

**Exempel 2 — Spegel på slot 0**
*Bräde:* `[MIRROR, PLAIN, PLAIN, PLAIN, PLAIN]`. Placement: tärning värde `5` i slot 0, inget annat. Charge in = 0.

- P1: `s0` är `MIRROR`, ingen vänstergranne → `slot_modifier_failed{slot:0, modifier:"MIRROR", reason:"NO_LEFT_NEIGHBOUR"}`, `effective_value[0] = 0`.
- P2: slot 0 är inte eligible (värde 0) → inga grupper.
- P3: `strike{slot:0, amount:0}`, inget `damage_dealt`.
- P5: fem oplacerade tärningar → deras värden till Charge.
- *Förväntat:* noll skada. `die_activated` emitteras ändå (UI ska visa fizzeln).

---

**Exempel 3 — Amboss under tröskeln**
*Placement:* tärning värde `4` i slot 4 (`ANVIL`), inget annat.

- P1: `4 < 5` → `slot_modifier_failed{slot:4, modifier:"ANVIL", reason:"VALUE_BELOW_5"}`, värdet förblir `4`.
- P3: `4` skada. Ingen straffeffekt.
- *Förväntat:* exakt `4` skada. Assert att inget `slot_modifier` med `modifier:"ANVIL"` emitterats.

---

**Exempel 4 — Charge lyfter över tröskeln och skapar ett fyrtal + överflödskedja + cap**
*Input:* `charge = 3` in. Placement-värden `[2, 5, (valfri tärning i MIRROR), 5, 3]`, oplacerad tärning `6`.
Fiender: `RUST_RAT` hp 14 armor 0, `SLAG_MOTH` hp 20 armor 0, `IRON_TICK` hp 28 armor 2.

- P0: vänstraste besatta slot = 0 → `charge_applied{slot:0, amount:3}`, pool → 0.
- P1: `s0 = 2+3 = 5`, `s1 = 5`, `s2 = MIRROR → 5`, `s3 = 5`, `s4 = 3` (Amboss misslyckas).
  `values = [5, 5, 5, 5, 3]`
- P2: maximal grupp `[0,1,2,3]` värde 5, längd 4 → `QUAD ×8`. Ingen grupp av 3 ⇒ ingen `HOUSE`. `s4` ×1.
- P3:
  - s0: `5×8 = 40` → RAT: dealt 14, overflow 26 → MOTH: dealt 20, overflow 6 → TICK: armor 2, `effective = 4`, dealt 4, `blocked = 2`, hp 28→24, overflow 0
  - s1: `40` → TICK: `effective = 38`, dealt 24, `blocked = 2`, hp→0, `enemy_killed`, overflow 14 → inget mål → `overflow_wasted{14}`, Charge `+7`
  - s2: `40`, inget mål → Charge `+20` → cappas: pool 7→20, `charge_capped{lost: 7}`
  - s3: `40` (FIRE), inget mål → Charge `+0`, `charge_capped{lost: 20}`. Ingen Burn (inget mål).
  - s4: `3`, inget mål → `charge_capped{lost: 1}`
- P5: oplacerad 6:a → `charge_capped{lost: 6}`. **Charge = 20.**
- *Förväntat:* alla tre fiender döda på slot 0–1. `combat_won`.

---

**Exempel 5 — HOUSE (kåk)**
*Bräde:* `[PLAIN, PLAIN, MIRROR, PLAIN, PLAIN]`. Placement-värden `[4, 4, (valfri i MIRROR), 6, 6]`.

- P1: `values = [4, 4, 4, 6, 6]`
- P2: grupp A `[0,1,2]` värde 4 längd 3 → `TRIPLE ×4`. Grupp B `[3,4]` värde 6 längd 2 → `PAIR ×2`.
  Brädet har en 3-grupp och en 2-grupp ⇒ `house_bonus{factor: 2}` → A blir **×8**, B blir **×4**.
- P3: s0 = `4×8 = 32`, s1 = `32`, s2 = `32`, s3 = `6×4 = 24`, s4 = `24`. **Totalt 144.**
- *Förväntat:* exakt två `combo_formed` följt av exakt ett `house_bonus` med `multipliers_after: [8,8,8,4,4]`.

---

**Exempel 6 — Ambossen bryter ditt par (fällan)**
*Standardbräde.* Placement-värden `[-, -, -, 6, 6]` (slots 0–2 tomma).

- P1: `s3 = 6` (FIRE ändrar inte värde), `s4 = 6 → ANVIL → 12`. `values = [0, 0, 0, 6, 12]`
- P2: `6 != 12` ⇒ **ingen grupp**. Båda ×1.
- P3: s3 = `6` (+ Burn 2 på målet), s4 = `12`. **Totalt 18.**
- *Kontrafaktiskt (skriv som andra assert):* samma placering men slot 4 är `PLAIN` ⇒ `values = [0,0,0,6,6]` ⇒ `PAIR ×2` ⇒ `6×2 + 6×2 = 24`. **Ambossen kostade 6 skada.**
- *Förväntat:* detta är avsiktligt och ska vara lätt att se i förhandsvisningen.

---

**Exempel 7 — Tom slot bryter angränsning**
*Bräde:* `[PLAIN, PLAIN, PLAIN, PLAIN, PLAIN]`. Placement-värden `[3, 3, tom, 3, 3]`.

- P1: `values = [3, 3, 0, 3, 3]`, `occupied = [true, true, false, true, true]`
- P2: slot 2 är inte eligible ⇒ två separata maximala grupper: `[0,1]` och `[3,4]`, båda `PAIR ×2`.
  Två 2-grupper, ingen 3-grupp ⇒ **ingen `HOUSE`**.
- P3: `3×2 ×4 slots = 24`. Jämför: om slot 2 haft en 3:a hade det blivit `PENTA ×16` → `3×16×5 = 240`.
- *Förväntat:* exakt två `combo_formed{kind:"PAIR"}`, inget `house_bonus`.

---

**Exempel 8 — Tomrum som sköld + spegelparat värde + fiendesvar**
*Bräde:* `[PLAIN, VOID, MIRROR, PLAIN, ANVIL]`. Placement-värden `[-, 5, (valfri i MIRROR), -, -]`.
Fiender: `THORN_IMP` hp 22 thorns 3 intent `ATTACK 2`, `RUST_RAT` hp 14 intent `ATTACK 3`. Spelaren hp 40.

- P1: `s1 = 5`, `s2 = MIRROR → 5`. `values = [0, 5, 5, 0, 0]`
- P2: grupp `[1,2]` → `PAIR ×2`.
- P3:
  - s1 är `VOID`: `5×2 = 10` → `ward_gained{slot:1, amount:10, ward_total:10}`, **ingen skada**
  - s2: `5×2 = 10` → THORN_IMP hp 22→12, `dealt > 0` ⇒ `enemy_thorns{amount:3}`, spelaren 40→37
- P4:
  - THORN_IMP `ATTACK 2`: `ward_used = 2`, `taken = 0`, ward 10→8
  - RUST_RAT `ATTACK 3`: `ward_used = 3`, `taken = 0`, ward 8→5
- P5: `ward = 0`. Fyra oplacerade tärningar → Charge.
- *Förväntat:* spelaren tog **3** skada totalt, allt från thorns, noll från attacker. Ward försvinner.

---

## 3. Händelselogg-format

`resolve()` returnerar `Array[Dictionary]`. Varje event har kuvertet:

```
t:        String      # event-typ, alltid satt
seq:      int         # 0-indexerad, monotont ökande, unik inom loggen
ms_hint:  int         # rekommenderad uppspelningstid i ms för UI
```

UI:t spelar upp loggen sekventiellt och får aldrig hoppa över ett event utan att ändå applicera dess tillståndseffekt (snabbspolning = samma logg, `ms_hint = 0`).

**Rekommenderade `ms_hint` (UI får justera, core sätter default):**
`die_activated` 220 · `slot_modifier` 260 · `combo_formed` 320 · `house_bonus` 420 · `strike` 180 · `damage_dealt` 300 · `enemy_killed` 380 · `charge_stored` 160 · `enemy_attacks` 320 · allt annat 120.

### Full eventkatalog

| `t` | Fält (utöver kuvertet) |
|---|---|
| `round_start` | `round: int`, `charge_in: int`, `player_hp: int` |
| `charge_applied` | `slot: int`, `amount: int` |
| `charge_held` | `amount: int` (ingen besatt slot att lägga den på) |
| `slot_empty` | `slot: int`, `reason: String` (`"NO_DIE"` \| `"BLOCKED"`) |
| `die_activated` | `slot: int`, `die_id: String`, `face_index: int`, `base_value: int`, `face_id: String` |
| `slot_modifier` | `slot: int`, `modifier: String`, `value_before: int`, `value_after: int` |
| `slot_modifier_failed` | `slot: int`, `modifier: String`, `reason: String` |
| `value_pass_done` | `values: Array[int]` (längd 5), `occupied: Array[bool]` |
| `combo_formed` | `kind: String`, `multiplier: int`, `slots: Array[int]`, `value: int` |
| `house_bonus` | `groups: Array[Array[int]]`, `factor: int`, `multipliers_after: Array[int]` |
| `relic_triggered` | `relic: String`, `detail: Dictionary` |
| `strike` | `slot: int`, `amount: int`, `multiplier: int` |
| `damage_dealt` | `slot: int`, `target: String`, `amount: int`, `blocked: int`, `overflow: int`, `target_hp_after: int` |
| `overflow_wasted` | `slot: int`, `amount: int` |
| `status_applied` | `target: String`, `status: String`, `stacks: int`, `stacks_after: int` |
| `status_ticked` | `target: String`, `status: String`, `amount: int`, `target_hp_after: int`, `stacks_after: int` |
| `heal` | `target: String`, `amount: int`, `source: String`, `hp_after: int` |
| `ward_gained` | `slot: int`, `amount: int`, `ward_total: int` |
| `charge_stored` | `amount: int`, `source: String` (`"CHARGE_SLOT"`\|`"OVERFLOW"`\|`"UNPLACED_DIE"`), `pool_after: int` |
| `charge_capped` | `lost: int` |
| `enemy_killed` | `target: String`, `slot: int` (`-1` om dödad av status) |
| `enemy_turn_start` | `enemy: String`, `intent: Dictionary` |
| `enemy_attacks` | `enemy: String`, `raw: int`, `ward_used: int`, `amount: int`, `player_hp_after: int` |
| `enemy_thorns` | `enemy: String`, `amount: int`, `player_hp_after: int` |
| `enemy_special` | `enemy: String`, `special: String`, `detail: Dictionary` |
| `player_damaged` | `amount: int`, `source: String`, `player_hp_after: int` |
| `die_cracked` | `die_id: String`, `face_index: int`, `cracks_total: int`, `destroyed: bool` |
| `die_destroyed` | `die_id: String` |
| `die_stolen` | `die_id: String`, `by: String` |
| `die_returned` | `die_id: String` |
| `face_grew` | `die_id: String`, `face_index: int`, `new_value: int` |
| `player_died` | `round: int`, `killed_by: String` |
| `combat_won` | `rounds: int`, `total_damage: int` |
| `round_end` | `round: int`, `player_hp: int`, `charge: int`, `enemies_alive: int` |

**Invarianter som dev ska asserta:**
1. `seq` är `0..n-1` utan hål.
2. Exakt ett `round_start` först och exakt ett `round_end` sist — **utom** när `player_died` emitterats, då är `player_died` sista eventet.
3. Efter `player_died` finns inga fler event.
4. `value_pass_done` kommer efter alla `die_activated`/`slot_modifier` och före alla `combo_formed`.
5. Alla `combo_formed` kommer före alla `strike`.
6. Summan av alla `damage_dealt.amount` + `status_ticked.amount` = total skada mot fiender.

---

## 4. Vertical slice – innehåll (M1)

### 4.1 Klass: Smeden (`SMITH`)

| Fält | Värde |
|---|---|
| `id` | `SMITH` |
| HP | 60 |
| Tärningar | 6 st `IRON`, alla startar som `1,2,3,4,5,6` (`PIP_1`…`PIP_6`) |
| `rerolls_per_round` | 1 |
| Startbräde | `[PLAIN, PLAIN, MIRROR, FIRE, ANVIL]` |
| Startrelik | `ANVIL_BLESSING` – efter varje runda där ett combo av storlek ≥ 3 bildades, får tärningen i `ANVIL`-sloten permanent `+1` på den sida som låg upp (max 9, återställs vid runstart, ej stridsslut) |

Smedens fantasi: få, enorma tärningar. Långsam start, exponentiellt slut. Spegeln på slot 2 är motorn (den parar sig alltid med slot 1), Ambossen på slot 4 är fällan (den bryter par).

### 4.2 Sidkatalog (M1)

**Bassidor** (finns på starttärningarna, ingen effekt):

| `id` | `value` |
|---|---|
| `PIP_1` … `PIP_6` | 1 … 6 |
| `CRACKED` | 0 (skapas av sprickor, kan ej smidas bort i M1) |

**8 smidbara sidor** — detta är M1:s belöningspool för `FORGE_FACE`:

| # | `id` | Namn | `value` | `effect` | `magnitude` | Rarity | Exploderar med |
|---|---|---|---|---|---|---|---|
| 1 | `POISON_DROP` | Giftdroppe | 2 | `APPLY_POISON` | 2 | common | Långa bossstrider, `DOMINO` |
| 2 | `EMBER` | Glöd | 3 | `APPLY_BURN` | 2 | common | `FIRE`-slot (stackar till 4) |
| 3 | `HOLLOW` | Ihålig sida | 0 | `REFUND_REROLL` | 1 | common | Allt. Förvandlar ett dåligt kast till agens |
| 4 | `SNOWBALL` | Snöbollen | 1 | `GROW` | 1 | uncommon | Att *inte* placera (dubbel nytta: Charge + växt) |
| 5 | `VAMP_FANG` | Vampyrtand | 3 | `LIFESTEAL` | 50 (cap 8/slot) | uncommon | Stora multiplikatorer, `BLOOD_PRICE` |
| 6 | `TWIN_EYE` | Tvillingöga | 0 | `COPY_LEFT` | 0 | uncommon | Bärbar spegel → trissar och kåkar var som helst |
| 7 | `HAMMER_FACE` | Städhammaren | 4 | `ANVIL_SELF` | 0 | rare | Charge (4+1=5 ⇒ 10), `ANVIL`-slot (⇒ 20) |
| 8 | `LEAD_SIX` | Blysidan | 6 | `LOCKED` | 0 | rare | `MIRROR` (gratis par varje runda den dyker upp) |

Smide: belöningen `FORGE_FACE` låter spelaren ersätta **en** sida på **en** tärning. Sidan som ersätts visas och valet är fritt. Permanent för runden.

### 4.3 Slot-typer (M1)

| `SlotType` | Namn | Regel | Kantfall |
|---|---|---|---|
| `PLAIN` | Vanlig | Inget | – |
| `FIRE` | Eld | P3: varje träff från denna slot ger målet `Burn +2` | Ingen träff ⇒ ingen Burn. Ändrar aldrig värdet. |
| `MIRROR` | Spegel | P1: värdet blir vänstergrannens effektiva värde (+ ev. Charge) | Slot 0 eller tom granne ⇒ 0. Kräver ändå en tärning. |
| `ANVIL` | Amboss | P1: om värde ≥ 5, dubbla | Under 5 ⇒ inget. Kan bryta par. |
| `CHARGE` | Ladda | P3: skadan blir Charge i stället för skada | Cappas av `CHARGE_CAP`. |
| `VOID` | Tomrum | P3: skadan blir Ward i stället för skada. Ward absorberar fiendeskada denna runda, nollställs vid `round_end` | Deltar i combos normalt. Speglar kan kopiera den. |

**[BESLUT v1]** Research 03 lämnade Tomrum odefinierat ("tar bort sloten"). Jag har gjort det till en **skölds-slot** i stället för en död slot. Skälet: M1 saknade annars varje defensivt verktyg och striden blir ett rent race där spelaren förlorar utan att förstå varför — exakt Rune Dice-kritiken från juni 2026 ("A Great Idea Crushed by Bad RNG"). En död nackdels-slot hör hemma i M3 som egen typ, `RUST`.

### 4.4 Fiender (M1)

| `id` | Namn | HP | Attack | `armor` | `thorns` | Special |
|---|---|---|---|---|---|---|
| `RUST_RAT` | Rostråtta | 14 | 3 | 0 | 0 | – (överflödsfoder) |
| `SLAG_MOTH` | Slaggmal | 20 | 3 | 0 | 0 | `DRAIN_CHARGE`: vid sin tur, `charge -= 3` (min 0) |
| `THORN_IMP` | Taggimpen | 22 | 2 | 0 | 3 | Passiv `thorns` |
| `PIP_THIEF` | Ögontjuven | 26 | 3 | 0 | 0 | `STEAL`: vid `round_end`, stjäl en **oplacerad** tärning (mål valt av `advance()` föregående runda, visas i intent). Tärningen saknas nästa runda. Dör tjuven återlämnas den omedelbart (`die_returned`). |
| `IRON_TICK` | Järnfästingen | 28 | 5 | 2 | 0 | Passiv `armor` |
| `GRAVE_HAND` | Gravhanden | 34 | 6 | 0 | 0 | `GRAB`: vid `round_end`, sätter `blocked = true` på en slot nästa runda (valet görs i `advance()` och står i intent-texten) |

**Möten (våning 1, M1):**

| Rum | Fiender (front→bak) | Total HP |
|---|---|---|
| 1 | `RUST_RAT`, `RUST_RAT` | 28 |
| 2 | `SLAG_MOTH`, `RUST_RAT`, `RUST_RAT` | 48 |
| 3 | `THORN_IMP`, `IRON_TICK` *eller* `PIP_THIEF`, `GRAVE_HAND` | 50 / 60 |
| 4 | Boss | 150 |

### 4.5 Boss (M1): `SLAGJAW` – Slaggkäften

| Fält | Värde |
|---|---|
| HP | 150 |
| `armor` | 2 (permanent) |
| Attack | 7 |
| `HARDEN` | Varje runda delbar med 3 (3, 6, 9 …) använder den `BLOCK 4` i stället för att attackera. Armor stackar och ligger kvar. |
| `CRACK_BITE` | När `hp < 75` (50 %) och den attackerar: efter attacken spricker den vänstraste placerade tärningens uppåtvända sida → byts mot `CRACKED` (värde 0) för resten av **runden**. Emit `die_cracked`. |

Bossen lär ut hela spelet: `armor` straffar många små träffar (bygg combos), `HARDEN` ger ett fönster att banka Charge i, `CRACK_BITE` straffar att alltid packa slot 0.

### 4.6 Reliker (M1, 6 st)

| `id` | Namn | Effekt | Rarity |
|---|---|---|---|
| `BLOOD_PRICE` | Blodpriset | Om minst ett combo bildas: −4 HP, alla combomultiplikatorer ×2 | common |
| `BROKEN_SCALE` | Trasiga vågen | P1: alla udda effektiva värden avrundas upp till jämna (1→2, 3→4, 5→6) | uncommon |
| `OCTOPUS` | Bläckfisken | Slot 1 och slot 3 räknas som angränsande i P2 (virtuell kant, gör "kåk med hål i" möjligt) | uncommon |
| `ECHO_MIRROR` | Ekospegeln | `MIRROR`-slots kopierar även vänstergrannens `FaceEffect` (gift, brand, lifesteal) | rare |
| `CHEAT_CUBE` | Fuskkuben | Stridens första kast: tärning 0, 1 och 2 visar alla samma seedade värde (garanterad triss-grund) | rare |
| `DOMINO` | Dominobrickan | En gång per runda: sloten med högst `amount` får sin högergranne att slå till igen för `floor(amount/2)` | rare |

`OCTOPUS` – exakt regel: kanten `(1,3)` läggs till i angränsningsgrafen. Grupper beräknas som sammanhängande komponenter i grafen där alla noder har samma `effective_value` och är eligible. Gruppstorlek avgör multiplikator som vanligt. Slot 2 behöver inte vara tom.

### 4.7 Belöningstabell

Efter varje vunnet `COMBAT`-rum: **3 alternativ**, dragna utan återläggning.

**Kategorivikter:**

| Kategori | Vikt |
|---|---|
| `FORGE_FACE` (byt en sida) | 50 |
| `RELIC` | 30 |
| `SLOT_SWAP` (byt en slots typ) | 20 |

**Sällsynthetsvikter per våning:**

| Våning | `common` | `uncommon` | `rare` |
|---|---|---|---|
| 1 | 70 | 25 | 5 |
| 2 | 55 | 33 | 12 |
| 3 | 40 | 40 | 20 |
| efter boss | 0 | 60 | 40 |

**Garantier (normativa, implementeras som efterkorrigering):**
1. Minst ett av de tre alternativen är alltid `FORGE_FACE`.
2. Från och med våning 2: minst ett alternativ har rarity ≥ `uncommon`. Uppfylls det inte, omrullas det sämsta alternativet en gång till ur `uncommon`-poolen.
3. De tre alternativen har olika `id`. Om poolen är slut fylls det på med `FORGE_FACE`.
4. Efter boss: 3 alternativ, alla ≥ `uncommon`, alltid minst en `RELIC`.

`SLOT_SWAP`-poolen i M1: byt valfri slot till `CHARGE` eller `VOID` (common), till `FIRE` eller `ANVIL` (uncommon), till `MIRROR` (rare).

### 4.8 Vad simulatorn får ändra utan designbeslut

**Fritt tuningbart:** all HP, alla attackvärden, `armor`, `thorns`, spelarens HP, `BREATHER_HEAL`, alla vikter i §4.7, `magnitude` på sidor, `CHARGE_CAP`.

**Låst (kräver beslut i `DECISIONS.md`):** fasordningen P0–P5, definitionerna av angränsande/identisk/oanvänd, multiplikatortabellen, `HOUSE`-regeln, överflödsalgoritmen, alla slot-typers regler, §6.

---

## 5. Balansmål för run-simulatorn

Simulatorn kör `N = 10 000` seedade runs med en scriptad policy. Två policyer krävs:
- `GreedyPolicy` – maximerar skada denna runda, ignorerar Charge och Ward. Golvet.
- `LookaheadPolicy` – provar alla placeringar (5!/(5−k)! begränsat), väljer högst `skada + 0.5×charge + 1.0×ward`. Taket.

Alla mål nedan gäller `LookaheadPolicy` om inget annat sägs och ska skrivas som gdUnit4-assertions.

| Mätetal | Mål | Rimlighetsintervall för assert |
|---|---|---|
| Vinstprocent hel run | 32 % | 25–40 % |
| Överlever våning 1 | 90 % | 85–95 % |
| Överlever våning 2 | 62 % | 55–70 % |
| Överlever våning 3 (= vinst) | 32 % | 25–40 % |
| Snittrundor per `COMBAT` | 3.6 | 3.0–4.5 |
| Snittrundor per `BOSS` | 6.0 | 5.0–8.0 |
| Andel rundor med ≥ 1 `combo_formed` | 70 % | 60–80 % |
| Andel rundor med ≥ 1 överflöd (`damage_dealt.overflow > 0`) | 35 % | 25–45 % |
| Andel rundor där `charge_applied.amount > 0` | 55 % | ≥ 45 % |
| **Explosionsfrekvens:** andel strider med ≥ 1 runda som gör ≥ 3× stridens medianrunda | 22 % | ≥ 15 % |
| `house_bonus` per run | 1.8 | ≥ 0.8 |
| Andel vinnande runs som innehåller en given relik | – | **ingen enskild relik i > 55 %** |
| Andel vinnande runs som innehåller en given sida | – | **ingen enskild sida i > 55 %** |
| `GreedyPolicy` vinstprocent | – | **minst 10 procentenheter lägre än `LookaheadPolicy`** (annars är placering meningslös → LBaL-fällan) |
| `avoidable_death_rate`: andel förlorande runs där `LookaheadPolicy` med 20 slumpade omplaceringar hade överlevt den dödande striden | 65 % | ≥ 60 % |
| Prestanda | – | 10 000 runs headless < 30 s; 1 000 runs < 5 s (M0-kravet) |

**Det viktigaste måttet är näst sist.** Om `GreedyPolicy` vinner lika ofta som `LookaheadPolicy` har vi byggt Luck be a Landlord och spelet är inte roligt. Det är stoppregeln.

**Regressionstest:** simulatorns siffror loggas till `docs/balance/<datum>.json`. Varje innehållsändring ska jämföras mot föregående körning.

---

## 6. Helig regel: kedjan visas innan bekräftelse, ingen dold slump i utfallet

Detta är den regel som avgör om spelet hatas eller älskas. Research 03 §5.2 listar det som dödssynd nummer två, och den färskaste datapunkten är Rune Dice (MonsterVine, juni 2026): *"A Great Idea Crushed by Bad RNG"*.

### Tekniskt innebär det exakt följande

1. **`resolve()` tar ingen RNG-parameter.** Den har inte ens tillgång till en. Test: injicera en `PoisonedRng` vars alla metoder kastar; `resolve()` måste gå igenom.
2. **`resolve()` är ren.** Samma `(state, placement)` ⇒ byte-identisk `events`-array. Test `test_resolve_is_deterministic`: kör 100 gånger, jämför serialiserat.
3. **Förhandsvisningen ÄR utfallet.** UI kallar `resolve()` på en kopia för preview. Vid bekräftelse kallas `resolve()` igen med identiska argument och dev **assertar att eventloggen är identisk** (`test_preview_equals_applied`). Är den inte det är det en krasch i debug, inte en tyst avvikelse.
4. **All slump för runda N dras i `advance()` före runda N:s början**, aldrig efter bekräftelsen. Det gäller: tärningskastet, varje fiendes `intent`, `GRAB`-slotvalet, `STEAL`-målet, `CHEAT_CUBE`-värdet, belöningsalternativen.
5. **Allt som dragits ska synas.** Fiendens intent visas som text och siffra. `GRAB` visar vilken slot. `STEAL` visar vilken tärning. `HARDEN` visar att bossen blockar. Det finns ingen "?" i intent-panelen i M1.
6. **Ingen dold varians i skada.** Ingen missfaktor, ingen kritisk träff, inget skadeintervall, ingen avrundningsslump. All avrundning är `floor` och deklarerad i §2.
7. **`armor`, `thorns`, `ward` är räknade i förhandsvisningen.** Siffran spelaren ser ovanför en fiende är den skada fienden faktiskt kommer att ta, efter armor.
8. **Undantag som är tillåtet:** slump som påverkar *nästa* runda får dras efter bekräftelsen (nästa kast, nästa intent), eftersom den visas innan nästa bekräftelse. Slump som påverkar *denna* rundas utfall får aldrig existera.
9. **Ångra är gratis och obegränsat fram till bekräftelse.** Att flytta en tärning konsumerar inget. Endast omkast konsumerar resurs.
10. **Seed visas.** Varje run har en synlig seed i paus-menyn. Det är communityns yttersta bevis på att vi inte fuskar, och det gör dagliga utmaningar möjliga senare.

### Testsvit som måste finnas innan M1 kallas klar
`test_resolve_is_deterministic` · `test_resolve_takes_no_rng` · `test_preview_equals_applied` · `test_resolve_does_not_mutate_input` · `test_events_seq_is_contiguous` · `test_no_events_after_player_died` · samt de åtta räkneexemplen i §2.4 som `test_example_1` … `test_example_8`.

---

## 7. Öppna frågor

| # | Fråga | Blockerar | Mitt förslag |
|---|---|---|---|
| 1 | Ska `HOUSE` även utlösas av två par (`TWO_PAIR`)? | Nej, M3 | Nej i v1. Utvärdera efter simulatordata om `house_bonus`/run < 0.8. |
| 2 | Vad händer med `CRACKED`-sidor mellan rum? I M1 är bossens sprickor rundbaserade. Ska de vara run-permanenta när Glasvåningar kommer? | Nej, M3 | Run-permanenta för `GLASS`, rundbaserade för `IRON`. Behöver Anders-ok eftersom det är den brutalaste regeln i spelet. |
| 3 | `CHARGE_CAP = 20` — är det för lågt? Exempel 4 spiller 34 Charge. | Nej, tuningbart | Låt simulatorn testa 20 / 30 / obegränsat. Obegränsat är troligen trasigt med `VOID`+combo. |
| 4 | Ska spelaren kunna placera **färre än 5** tärningar frivilligt? | **Ja, M1** | **Ja.** Det är hela poängen med Charge-banken. UI måste tillåta "bekräfta med tomma slots". |
| 5 | Smedens startrelik `ANVIL_BLESSING` ger permanent sidtillväxt — riskerar att bli obligatorisk. | Nej | Återställs vid runstart. Om simulatorn visar > 55 % närvaro i vinster: gör den stridsbunden. |
| 6 | Ödeskastets (`FATE_ROLL`) exakta pool. Spec:ad som hook i §1, innehållet är M3. | Nej, M3 | 6 kandidater: `ALL_ONES_ARE_SIXES`, `SLOT_4_TRIGGERS_TWICE`, `MIRRORS_COPY_RIGHT`, `NO_COMBOS_BUT_DOUBLE_DAMAGE`, `CHARGE_CAP_DOUBLED`, `ENEMIES_HAVE_ARMOR_2`. Skriver full spec när M1 är mätt. |
| 7 | Affärsmodell påverkar meta-progressionens form. | Nej, M4 | Väntar på Anders enligt `DECISIONS.md`. |
| 8 | Klasserna Spelaren och Alkemisten (bentärningar 0–5, symbolsidor) är inte spec:ade. | Nej, M3 | Alkemistens symbolreaktioner behöver ett eget kapitel i P1/P3. Skrivs när Smeden är validerad. |

---

## Källor tillagda efter research 03 (hämtade 2026-09-21)

- MonsterVine, *Rune Dice Review – A Great Idea Crushed by Bad RNG*, juni 2026: https://monstervine.com/2026/06/rune-dice-review/ — färsk bekräftelse på att tärningsroguelikes 2026 fortfarande faller på RNG utan agens.
- Metacritic, Rune Dice: https://www.metacritic.com/game/rune-dice/
- Game Developer, *Solving RNG abuse in roguelikes*: https://www.gamedeveloper.com/game-platforms/solving-rng-abuse-in-roguelikes
- GMTK, *Balatro's "Cursed" Design Problem*: https://gmtk.substack.com/p/balatros-cursed-design-problem
- Konkurrentbevakning (tärnings-roguelikes i samma nisch, 2024–2026): *Pip My Dice* (https://www.gamingonlinux.com/2024/10/check-out-the-demo-for-pip-my-dice-a-roguelike-inspired-by-balatro-and-yahtzee/), *CloverPit* (https://en.wikipedia.org/wiki/CloverPit), Steam Curator *Dice-Based Roguelikes* (https://store.steampowered.com/curator/44902423-Dice-Based-Roguelikes-%28ENG%29/).

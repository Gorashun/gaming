# assets/sfx – ljudregister (M2)

**Ägare:** UI/UX · **Uppdaterad:** 2026-09-21
**Källa:** `tools/gen_sfx.py` (ren Python, `wave` + `struct`, inga beroenden)
**Licens:** samtliga `own-work`, rad per fil i `assets/ASSET_LICENSES.csv`.

Alla 17 filer är **16-bit PCM, 44 100 Hz, mono**, normaliserade till
**−3,00 dBFS peak**, noll klippta sampel. Generatorn är deterministisk
(seedad LCG som brusskälla), så en ny körning ger byte-identiska filer och
diffen i CI är tom om ingenting ändrats.

```
python3 tools/gen_sfx.py         # skriver assets/sfx/*.wav
python3 tools/build_asset_csv.py # skriver om ASSET_LICENSES.csv
python3 tools/check_asset_licenses.py
```

---

## 1. Karaktären: "krita + metall"

Bilden är krita på skiffer med pixelobjekt ovanpå (UI_GUIDE §1A, §8). Ljudet
är samma två lager, i varje enskild cue:

| Lager | Vad det är | Vad det bär |
|---|---|---|
| **KRITA** | bandbegränsat brus med mycket kort decay, ibland granulerat (rektifierad AM så dalarna når noll) | rytmen, det fysiska anslaget – kritans skrap, träknacket mot skiffern |
| **METALL** | inharmonisk partialstapel 1,00 · 2,01 · 2,76 · 3,93 · 5,41, där höga partialer dör först | tonhöjden – och tonhöjden är det kedjan leker med |

Ingen cue är bara ett lager. Skada är mest krita med en metalldunk under;
en combo är mest metall med ett kritknack på varje anslag. Det är hela tricket:
det håller ihop 17 olika ljud i en familj.

Ingen sågtandssynt, ingen supersaw, inga samplade slagverkspaket. Tonmaterialet
är **D-durpentatonisk** (D E F♯ A B) enligt UI_GUIDE §5.2, vald för att varje
delmängd är konsonant – kedjan kan stapla steg utan att någonsin landa surt.

---

## 2. Event → fil → nivå

`Mix-dB` sätts på `AudioStreamPlayer.volume_db` av uppspelaren. Filerna är
normaliserade, mixen görs i motorn: då kan en cue balanseras om utan att en
WAV regenereras. Nivåerna är relativa till `damage_hit`, som är
huvudhändelsen i en kedja och ligger på 0 dB.

| Event (`src/core`) | Fil | Längd | Mix-dB | Pitchas? | Anmärkning |
|---|---|---|---|---|---|
| `die_activated` | `die_activate.wav` | 60 ms | **−4** | **ja, per kedjesteg** | Spelas 6 ggr per runda – därför under träffen i mixen |
| `combo_formed` ×2 | `combo_pair.wav` | 120 ms | **−2** | ja, `combo_bonus` | |
| `combo_formed` ×4 | `combo_triple.wav` | 180 ms | **−1** | ja | |
| `combo_formed` ×8 / kåk | `combo_house.wav` | 250 ms | **0** | ja | Har egen sub på ~55 Hz (UI_GUIDE §5.2) |
| `damage_dealt` | `damage_hit.wav` | 90 ms | **0** | **nej – skadeberoende**, se §3.2 | Referensnivå |
| `damage_dealt` överflöd | `damage_overflow.wav` | 190 ms | **−1** | ja, +2 halvtoner per hopp | Ersätter `damage_hit` på hoppet, staplas inte |
| `charge_stored` | `charge_store.wav` | 240 ms | **−9** | ja, stigande per prick | Sidokanal, aldrig huvudhändelse (UI_GUIDE §5.4) |
| `enemy_killed` | `enemy_killed.wav` | 240 ms | **+1** | **ja, men −2 halvtoner** | Döden är en punkt, inte en höjning |
| `die_cracked` | `die_cracked.wav` | 380 ms | **+2** | **nej – mönsterbrott** | Kedjans stigning bryts med flit (UI_GUIDE §5.6) |
| `enemy_attack` | `enemy_attack.wav` | 250 ms | **−1** | nej | Fiendepasset (P4), utanför kedjans tonstege |
| `player_damaged` | `player_hurt.wav` | 240 ms | **−1** | nej | Låg puls, läsbar även med ljudet av |
| `reward_applied` | `reward_pick.wav` | 300 ms | **−5** | nej | Ett val, inte ett anslag |
| UI-tryck (knapp, drag-släpp) | `ui_tap.wav` | 14 ms | **−14** | nej | 5 ms tick + svans, se §4 |
| `round_end` | `round_end.wav` | 560 ms | **−3** | nej | Kadens under sifferrullningen + tally-skrapet |
| Bossrum öppnas | `boss_intro.wav` | 600 ms | **−6** | nej | Högst RMS i paketet (hållet dån) – därför lägst mix-dB per dB peak |
| Run vunnen | `victory.wav` | 800 ms | **−2** | nej | Samma pentatonik som kedjan |
| Run förlorad | `defeat.wav` | 900 ms | **−4** | nej | Tre fallande toner, inget bruslager: kritan har slutat |

Godot-import: `compress/mode = 0` (PCM 16-bit), `edit/loop_mode = 0`,
`force/mono = false` (filerna är redan mono), `edit/normalize = false`
(normaliseringen är redan gjord och `edit/normalize` skulle slå ut
nivåskillnaden mellan cues). Totalt 478 kB okomprimerat – QOA hade sparat
~350 kB och lagt artefakter på 5 ms-transienterna. Inte värt det.

---

## 3. Tonhöjdsregler

### 3.1 Kedjans stegring (normativ, UI_GUIDE §5)

```gdscript
pitch_scale = min(pow(2.0, (step_index + combo_bonus) / 12.0), 2.0)
```

* `step_index` = 0…5, **nollställs varje runda**.
* `combo_bonus` = 0 / 2 / 4 / 7 för ingen / ×2 / ×4 / ×8.
* **Tak +12 halvtoner** (`pitch_scale = 2.0`, en oktav). Utan tak låter en
  lång kedja med tre combos som en telefonsignal.
* Gäller `die_activate`, `combo_*`, `charge_store` och `damage_overflow`.

`enemy_killed` använder samma uttryck men **−2 halvtoner**:
`pow(2.0, (step_index + combo_bonus - 2) / 12.0)`.

### 3.2 Skadeberoende tonhöjd (`damage_hit`)

```gdscript
pitch_scale = clamp(1.2 - float(damage) / 200.0, 0.65, 1.2)
```

Stora tal låter tyngre. Detta är **oberoende** av kedjestegringen: träffen är
en konsekvens, inte ett steg. Att låta båda reglerna gälla samtidigt gjorde
stora sena träffar ljusare än små tidiga, vilket är fel feedback.

### 3.3 Överflödshoppen

`damage_overflow` startar på kedjans aktuella ton och lägger **+2 halvtoner
per hopp**: `pow(2.0, (step_index + combo_bonus + 2 * hop) / 12.0)`, samma tak.
Kritpilen och tonen stiger alltså tillsammans.

### 3.4 Variation utan nya filer

Varje cue som spelas mer än en gång per runda (`die_activate`, `damage_hit`,
`ui_tap`) ska få `pitch_scale *= randf_range(0.98, 1.02)` ovanpå sin regel.
Två procent är under vad örat hör som "en annan ton" men över vad det hör som
"exakt samma sampel igen". Slumpen tas ur en **visuell** ström, aldrig ur den
seedade `Rng` (ARCHITECTURE: rendering rör inte strömmen).

---

## 4. Fades och nivåer (och en medveten avvikelse)

| Regel | Värde |
|---|---|
| Peaknormalisering | −3,00 dBFS, samtliga filer, 0 klippta sampel |
| Fade ut | **5 ms**, samtliga filer |
| Fade in, mjuka cues | **5 ms** (`combo_*`, `charge_store`, `reward_pick`, `round_end`, `boss_intro`, `victory`, `defeat`) |
| Fade in, transienta cues | **1 ms** (`die_activate`, `damage_hit`, `damage_overflow`, `enemy_killed`, `die_cracked`, `enemy_attack`, `player_hurt`, `ui_tap`) |

**Avvikelse från briefens "5 ms in/ut på allt", med skäl:** en 5 ms linjär
infade är 220 sampel. På en klocka eller ett dån hörs det inte, men på ett
60 ms knack äter det anslaget – och anslaget *är* feedbacken (UI_GUIDE §5).
1 ms (44 sampel) tar bort varje DC-steg vid sampel 0, vilket är allt en
infade behöver göra. Mätt: samtliga filer börjar och slutar på värdet 0.

`ui_tap` är specad som "5 ms tick" men filen är **14 ms**: ticken har klingat
ut inom 5 ms, resten är svans så att 5 ms-utfaden landar på tystnad i stället
för på transienten. Upplevd längd är 5 ms.

Ordningen i `finish()` är **fade först, normalisera sedan**. Tvärtom hamnar
filen under målnivån så fort toppen ligger inne i fade-fönstret – exakt vad
som händer på en 14 ms tick.

---

## 5. Tillgänglighet

* **Spelet är fullt spelbart ljudlöst.** All tonhöjdsinformation dubbleras
  visuellt av multiplikator-badgen (UI_GUIDE §6.4). Ingen regel lärs ut bara
  av ljud.
* Musik och SFX har separata reglage.
* `boss_intro` är den enda cue som ligger under 60 Hz med någon energi.
  Telefonhögtalare återger den inte – därför bär `clang`-lagret vid 360 ms
  samma information i mellanregistret.
* Ingen cue är längre än 900 ms och ingen loopar, så inget ljud kan ligga kvar
  och maskera nästa händelse i kedjan.

---

## 6. Lägga till en ny cue

1. Skriv en funktion i `tools/gen_sfx.py` som returnerar `finish(...)`.
   Använd `chalk()` **och** `metal()` – en cue med bara ett lager hamnar
   utanför familjen.
2. Lägg en rad i `CUES` med en not på svenska.
3. `python3 tools/gen_sfx.py && python3 tools/build_asset_csv.py`
4. `python3 tools/check_asset_licenses.py` – grönt eller inget commit.
5. Lägg en rad i tabellen i §2 med mix-dB och pitch-regel. En cue utan
   nivå i den tabellen är inte levererad.

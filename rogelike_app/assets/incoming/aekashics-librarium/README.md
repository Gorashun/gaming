# Ækashics Librarium – inkorg för monster-battlers

Här lägger Anders de frontala målade battlers från Ækashics Librarium
(https://aekashics.itch.io, www.akashics.moe) som ska ersätta interims-shades.
Proxyn i dev-miljön blockerar sajten, så filerna måste laddas ner lokalt.

**Rå PNG:er committas inte** (licensen förbjuder vidaredistribution; `.gitignore`
en nivå upp släpper bara igenom `README.md`, `KALLA.txt` och
`license-screenshot.png`). Bara de normaliserade filerna i `assets/art/` hamnar i git.

## 1. Filnamn vi väntar oss (exakt, skiftlägeskänsligt)

Välj en battler per fiende, döp om den och lägg den **direkt i den här mappen**:

| Fil | Fiende i spelet | Vad vi letar efter |
|---|---|---|
| `RUST_RAT.png` | Rostråttan (kommer 4 i taget, rum 1) | liten råtta/gnagare |
| `SLAG_MOTH.png` | Slaggmalen | mal, nattfjäril eller annan bevingad liten varelse |
| `THORN_IMP.png` | Törnimpen | imp, liten demon med horn |
| `PIP_THIEF.png` | Pipptjuven | tjuv/rövare med huva och kniv |
| `IRON_TICK.png` | Järnfästingen (rustning 6, "muren") | fästing, bepansrad skalbagge, bred och låg |
| `GRAVE_HAND.png` | Gravhanden (GRAB) | hand/arm ur jorden, zombie som griper |
| `CHALK_DUMMY.png` | tutorialdockan | fågelskrämma, träningsdocka |
| `placeholder.png` | reserv för fiende-id utan egen bild | slime eller annan neutral figur |
| `SLAGJAW.png` | Slaggkäften (boss) | stor demon med käft/huggtänder, gärna bred |

Transparent bakgrund, fötterna nederst (pivot = underkant). Storleken spelar
ingen roll: `normalize_art.py` beskär och skalar (max 512×512, bossen 1024×1024).
Saknas en fil används shaden för just den fienden, så ett halvt set går att köra.

## 2. Proveniens (krävs innan något byggs)

- `KALLA.txt` – fyll i mallen nedan (kopiera till `KALLA.txt` i den här mappen).
- `license-screenshot.png` – **skärmdump av licensrutan / Terms of Use-sidan**
  (www.akashics.moe/terms-of-use) samma dag som nedladdningen. Sidor kan ändras i
  efterhand; skärmdumpen är vårt bevis. Läs särskilt: gäller villkoren även
  gratisbatcherna, kommersiellt bruk, antal titlar, redigering (vi desaturerar och
  lägger kantljus).

## 3. Bygg (ett kommando)

Från `rogelike_app/`:

```sh
# 1. Sätt "retrieved" (nedladdningsdatum) i tools/art_build.json-overlayn:
#    tools/art_build.aekashics.json  ->  "retrieved": "2026-MM-DD"
# 2. Prova:
python3 tools/normalize_art.py --build tools/art_build.aekashics.json
python3 tools/check_asset_licenses.py
python3 tools/shade_monsters/contact_sheet.py --dir assets/art/enemy --extra assets/art/boss/SLAGJAW.png --out /tmp/aekashics_sheet.png
# 3. Permanent: "enabled": true i tools/art_build.aekashics.json och kör
python3 tools/normalize_art.py
```

`normalize_art.py` flyttar då automatiskt källan `aekashics` från
`pending_sources` till `sources` i `assets/credits.json`, så att raden
**"Monster battlers by Ækashics – www.akashics.moe"** syns i credits så länge
minst en Ækashics-battler finns i builden (licensvillkor). Används ingen längre
flyttas den tillbaka.

Rattar i overlayns `defaults` (se `_about` i filen):
- `strip_shadow`: 0 = av. Har filerna en inbränd svart skugga under fötterna, sätt 96.
- `grade`: av. Om färgerna är för mättade för shadern, prova
  `{"desaturate": 0.35, "contrast": 1.1, "cool_shadows": 0.3, "rim": 0}`.
- `display_h` per post: hur stor figuren står i korridoren.

## KALLA.txt – mall

```text
Paket:        Ækashics Librarium (<vilken batch/vilket paket, t.ex. "Librarium Static Batch Megapack">)
Skapare:      Ækashics
URL:          <sidan du laddade ner från, t.ex. https://aekashics.itch.io/...>
Spegel:       http://www.akashics.moe/terms-of-use/
Hämtad:       2026-MM-DD
Licens:       [egen licens – ej CC] CSV-kod: proprietary-free (eller proprietary-purchased om paketet köptes)
Licenstext (klistrad ordagrant från sidan den dag jag laddade ner):
"<klistra in exakt vad som stod>"
Attribution krävs:  JA – "Monster battlers by Ækashics – www.akashics.moe" i credits så länge en battler finns i builden
Vidaredistribution: FÖRBJUDEN (även redigerade filer) – rå-PNG:erna committas inte
Kommersiellt OK:    <JA/NEJ enligt sidan>
Får modifieras:     <JA/NEJ enligt sidan>
AI:           <nej/ja/okänt>   ("okänt" räknas som "ja", se ASSET_SHOPPING_LIST_PAINTED §9.5)
Skärmdump av licensrutan:  license-screenshot.png
Originalfiler -> våra namn:
  RUST_RAT.png    <- <originalfilnamn>
  SLAG_MOTH.png   <- <originalfilnamn>
  THORN_IMP.png   <- <originalfilnamn>
  PIP_THIEF.png   <- <originalfilnamn>
  IRON_TICK.png   <- <originalfilnamn>
  GRAVE_HAND.png  <- <originalfilnamn>
  CHALK_DUMMY.png <- <originalfilnamn>
  placeholder.png <- <originalfilnamn>
  SLAGJAW.png     <- <originalfilnamn>
```

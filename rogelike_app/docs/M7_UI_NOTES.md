# M7 – UI utan pixelgrafik

**Ägare:** UI/UX · **Datum:** 2026-09-24 · **Uppdrag (Anders):** "Vi behöver göra om UI så det inte är pixelgrafik på tärningar och så också."

Krit-UI:t (StyleBoxFlat, typsnitt, `tokens.gd`) är orört. Det som byttes är rasterpixlarna: 16/32 px-sprites som skalades upp med Nearest och heltalsskala.

## Vad som bytts

| Vad | Förr | Nu |
|---|---|---|
| Tärningarna (bricka, slots, belöningskort, karaktärsblad, drag-förhandsvisning) | 4 staplade `Sprite2D` ur `assets/sprites/dice/`, palette_lut-shader, `Art.fit_scale`/`snap` | `DieArt._draw()`: tung rundad kropp med framkant och skugga, materialets fem LUT-steg som gradient, glasets sken och ljusa kant, pips som ritade insänkta cirklar, sprickor som seedade linjer, blixten som lerp mot vitt. Valfri storlek, inget Nearest. |
| Specialsidor (gift/eld/blod/tomrum, frost i reserv) | `dice/glyph_*.png` 32 px | `ui.face.<glyph>`, 256 px krita, tintad med sin token på en ingraverad medaljong |
| Slot-ikonerna i kedjan | `ui/slot_*.png` 16 px i skala 1 | `ui.slot.<typ>` 14 dp i rubriken + 26 dp vattenstämpel i tom slot. Formdistinkthet på 24 dp: sämsta par 0,56 (gräns 0,85) |
| Knappikoner (settings, sheet, help, undo, pilar, charge, attack, armor, overflow, tutorialpekaren) | `ui/icon_*.png` 16 px, heltalsskala | `ui.icon.<namn>`, Lanczos-skalade till exakt dp-storlek |
| Nodskyltar i korridoren | `ui/node_*.png` på pixelplattan `sign_plate.png` | `ui.node.<kind>` tintad per nodtyp (`CorridorView.sign_tint`) på en ritad skifferplatta (`Art.sign_plate_texture()`) |
| Väggfacklan (korridor + stad) | `env/corridor/torch.png` 16×32 px | `Art.torch_texture()`: ritad kopp, skaft och flamma, två rutor |
| Tomma utrustningsslots på karaktärsbladet | färgikoner `gear.slot.*` på 22 % | `ui.gearslot.<SLOT>`: Ravenmore som mono-krita (HEAD, CHEST, BACK, HANDS, WEAPON), game-icons för AMULET och LEGS, tintad chalk/300 på 42 % |
| Porträttet i könsvalet | tvingat Nearest | `Art.filter_for` (målat ⇒ Linear) |

Brickan runt en READY-tärning är borttagen (tärningen bär sin egen kropp och skugga); vald, låst, sprucken och stulen behåller sin ring. Hög kontrast behåller ramen.

**Pixelpaperdollen** (`src/game/sheet/hero_figure.gd`) var redan död kod: ingen skärm skapar den sedan M6 (karaktärsbladet visar porträttet). Bara `tests/test_smith.gd` använder den. Filerna ligger kvar enligt uppdraget.

Källor: game-icons.net (Lorc, Delapouite, Sbed; CC BY 3.0), Ravenmore Fantasy Icon Pack (CC BY 3.0, redan i credits). Attribution per upphovsperson i `assets/credits.json` (källa `game-icons`) och per fil i `assets/ASSET_LICENSES.csv`. Proveniens: `assets/incoming/game-icons/` (SVG-källor, `license.txt`, `KALLA.txt`, `manifest.csv`).

## Hur man byter en ikon

1. Hitta ett motiv på game-icons.net och prova namnet: `python3 tools/icons/fetch_icons.py --probe lorc/anvil`.
2. Ändra posten i `tools/art_build.json` (blocket efter `ui.frame.slot`): `"svg": "<author>/<name>.svg"`, ev. `"rotate": 90`. Ny upphovsperson? Lägg till den under `authors` och en rad `Icons made by …` i källan `game-icons` i `assets/credits.json` (testet `test_every_game_icons_author_is_credited_by_name` fäller annars).
3. Kör, från `rogelike_app/`:
   ```
   python3 tools/icons/fetch_icons.py
   NODE_PATH=/opt/node22/lib/node_modules node tools/icons/render_icons.js   # --only ui.slot.fire för en
   python3 tools/normalize_art.py
   python3 tools/check_asset_licenses.py
   ```
4. Ny PNG under `assets/art/ui/`? Kör `godot --headless --import` och sätt `mipmaps/generate=true` och `detect_3d/compress_to=0` i dess `.import` (samma som de befintliga), importera igen.

Färgen sätts aldrig i filen: ikonerna är vit krita, anroparen tintar med `modulate` och en token. En målad färgikon blir krita med `"mono": true` (se `ui.gearslot.*`). Byta en bild utan verktygen: lägg en ny PNG under samma namn i `assets/art/ui/…`.

## Kända rester av pixelgrafik

- **Fiender, reliker, porträtt:** ritas ur manifestet (målat). De gamla spritesen i `assets/sprites/enemies|items|hero/` är bara reserv om en manifestpost saknas.
- **Reserverna i `assets/sprites/`:** `dice/*`, `ui/slot_*`, `ui/node_*`, `ui/icon_*`, `env/corridor/sign_plate.png`, `torch.png` ligger kvar och ritas bara om manifestposten saknas (då med Nearest, avsiktligt). `tests/test_m7_ui.gd` kontrollerar att normalfallet aldrig går dit.
- **`hero_figure.gd`** (död kod) sätter fortfarande Nearest och använder `Art.snap`/`WORLD_SCALE`.
- **Korridorens miljöshaders** har kvar sina pixelvarianter (`battler_pixel.gdshader`, `corridor_surface_pixel.gdshader`) för reservfallet.
- **Rullningsanimationen** (`die_tumble_gray.png`, UI_GUIDE §9.4) har aldrig kopplats in och är inte ersatt; kastet animeras med Juice-pulsen som förut.

## Verifiering

gdUnit4: 592/592 gröna (577 före; en borttagen `fit_scale`-test, 16 nya i `tests/test_m7_ui.gd`). Rökprov `SMOKE OK (39 screenshots)` i 1080×1920 (360×640 dp) och 1080×2340 (430×932 dp). Skärmdumpar: `docs/screenshots/m7_ui/` (strid med placerade tärningar, mitt i kedjan, korridorkorsning, karaktärsblad, tutorial, belöning; plus en översikt av material och sidor).

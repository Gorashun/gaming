# Inkorg för externa assets

Lägg varje köpt/nedladdat paket i en egen undermapp: `assets/incoming/<tillverkare>-<paket>/` (gemener, bindestreck, namnstandard i `docs/ASSET_SHOPPING_LIST_PAINTED.md` §C.2), med paketets licensfil, en skärmdump av licensrutan (`license-screenshot.png`) och `KALLA.txt` enligt mallen i §C.3. Zip går bra att ladda upp; UI-agenten packar upp.

Tillåtna licenser: CC0, CC-BY 3.0/4.0, OGA-BY, OFL, köpt royalty-free med kommersiell licens, samt skaparens egen kommersiellt fria licens med skriven licenstext (`proprietary-free`, t.ex. Pipoya). Aldrig CC-BY-SA eller GPL.

## Vad som committas härifrån
Bara proveniens: `KALLA.txt`, licensfiler, `license-screenshot.png`, README (se `.gitignore` här). Rå paketinnehåll och zippar committas **inte** – Pipoya förbjuder vidaredistribution och zippar är ignorerade globalt. Undantag: `ravenmore-fantasy-icon-pack/` (ankaret, med PSD) och `ravenmore-fantasy-ui-elements/` (PSD-källa, CC-BY 3.0) ligger i git. Sedan M7 även `game-icons/`: SVG-källorna (CC-BY 3.0) och `license.txt`, men inte de renderade PNG:erna i `render/`.

## Flödet in i spelet
1. `tools/art_build.json` säger vilken rå fil som blir vilket innehålls-id.
2. `python3 tools/normalize_art.py` beskär, skalar och skriver `assets/art/<kategori>/<id>.png`, `assets/art/manifest.json` och raderna i `assets/ASSET_LICENSES.csv`.
3. `python3 tools/check_asset_licenses.py` ska ge OK. Inkorgen skannas inte (den har `.gdignore` och importeras aldrig av Godot).
4. Attributionstexten per källa ligger i `assets/credits.json` (credits-skärmen).

**Vektorikoner (game-icons.net, M7):** `python3 tools/icons/fetch_icons.py` hämtar SVG:erna som `tools/art_build.json` pekar ut (`"svg": "<author>/<name>.svg"`), `NODE_PATH=/opt/node22/lib/node_modules node tools/icons/render_icons.js` renderar dem till `game-icons/render/<id>.png` (256 px vit krita), sedan steg 2–3 ovan. Se `docs/M7_UI_NOTES.md`.

Byte av grafik = byt PNG under samma namn i `assets/art/` eller peka om `file` i manifestet. Ingen kod ändras.

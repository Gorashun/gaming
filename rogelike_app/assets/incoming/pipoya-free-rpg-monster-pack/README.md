# pipoya-rpg-monster-pack (trimmad)

Originalzip: `Pipoya_RPG_Monster_Pack.zip`, 31 MB, 313 PNG. För stor för repot.
Denna mapp är 7 MB och innehåller det vi faktiskt använder.

## Vad som finns här
| Mapp | Innehåll | Storlek |
|---|---|---|
| `full-480/` | 50 enemies 480×480 + 4 bossar 1280×600, RGBA, "shade"-varianten, förlustfritt | 6,3 MB |
| `small-256/` | Samma 54 filer, 256×256 / 640×300, 256-färgers palett-PNG. Ikoner, kodex, tumnaglar. | 0,5 MB |
| `manifest.csv` | id, fil, typ, grov etikett per monster (min bedömning från kontaktkarta – kontrollera) | |
| `contact-sheet.png` | Alla 50 enemies på en bild | |
| `KÄLLA.txt` | Licensmall – **licens saknas i zipen, måste läsas på itch-sidan** | |

## Vad som togs bort och varför
- `*a.png`, `*b.png` (100 filer): färgvarianter av samma monster. Vi ompaletterar via palett-LUT-shader (`research/04 §3`), så egna recolors är redundanta.
- `non shade/` (155 filer): identiska sprites utan skuggning. Välj en; "shade" ger djup som klarar vår grade.

## Återställa hela packet
Originalzipen ligger utanför repot. Om a/b-varianter eller non-shade behövs:
packa upp, kör `tools/trim_pipoya.py` (nedan) med andra filter, eller lägg zipen i Git LFS.

## Stil-varning
Pipoya är söt/chibi JRPG-ton (jfr `ASSET_SHOPPING_LIST_PAINTED.md §1.4`). Frontal och rätt format,
men kräver hård grade/mörkning för PIPWRECK. Ækashics Librarium (§1.1) är fortfarande förstahandsvalet.

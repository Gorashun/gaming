# Inkorg för externa assets

Lägg varje köpt/nedladdat paket i en egen undermapp: `assets/incoming/<tillverkare>-<paket>/`, med paketets licensfil och gärna ett kvitto eller länk i `KÄLLA.txt`. Zip går bra.

Tillåtna licenser: CC0, CC-BY, OFL, köpt royalty-free med kommersiell licens. Aldrig CC-BY-SA eller GPL.

UI-agenten packar upp, registrerar varje fil i `assets/ASSET_LICENSES.csv`, skalar om och flyttar in i `assets/sprites/`. Inget under `incoming/` importeras av Godot (se `.gdignore`).

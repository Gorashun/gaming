# Studions team

Varje roll är en Claude Code-subagent i `.claude/agents/`. Anropa via Agent-verktyget med rollens namn, eller be huvudagenten delegera.

| Roll | Agent | Äger | Används för |
|---|---|---|---|
| Projektledare / producent | `studio-producer` | `docs/PLAN.md`, `docs/BACKLOG.md`, `docs/DECISIONS.md` | Milstolpar, prioritering, scope, risker |
| Research & Development | `rnd-researcher` | `docs/research/` | Teknikval, konkurrenter, spikes, regelverk |
| 3D-designer / teknisk artist | `art-3d-designer` | `art/`, `docs/design/ART_BIBLE.md` | Chibi + mörk fantasy, modeller via Blender-skript, shaders, VFX |
| ARPG-nörd / systemdesigner | `arpg-systems-designer` | `docs/design/SYSTEMS.md`, `game/data/` | Loot, RNG, rariteter, klasser, lvl 1–200, crafting, balans |
| Game writer | `game-writer` | `docs/lore/` | Universum, världar, bossar, Named-föremål, questtext |
| Programmerare | `gameplay-programmer` | `game/` | Motor, combat, AI, inventory, save, builds, tester |
| UI/UX-designer | `ui-ux-designer` | `ui/`, `docs/design/UI_UX.md` | Touch-kontroller, HUD, inventory/crafting/skill tree, juice |
| Ljuddesigner (tillagd) | `audio-designer` | `audio/`, `docs/design/AUDIO.md` | SFX, musik, rarity-ljudstege |
| QA / speltestare (tillagd) | `qa-tester` | `docs/QA.md` | Tester, balanssimulering, prestanda |
| Spelarvälfärd & compliance (tillagd) | `player-safety-advisor` | `docs/design/PLAYER_WELFARE.md` | Barnsäkerhet, butikspolicyer, veto mot mörka mönster |

## Arbetsflöde
1. Producent bryter ner milstolpe → backlog med ägare.
2. R&D bevisar tekniska risker före bygge (spikes).
3. Design (system/lore/art/UI/ljud) levererar datadrivna specar → programmerare implementerar.
4. QA verifierar mot "definition of done"; spelarvälfärd granskar belönings- och monetiseringsbeslut.
5. Beslut loggas i `docs/DECISIONS.md`.

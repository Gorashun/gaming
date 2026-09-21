# Agentteam – roguelike_app

Agentdefinitionerna ligger i `.claude/agents/` (repo-rot) så att Claude Code kan spawna dem. Denna fil beskriver roller, ansvar och samarbetsflöde.

| Roll | Agent | Äger | Anropas för |
|---|---|---|---|
| Projektledare | `pm-roguelike` | PLAN.md, DECISIONS.md, STATUS.md, BACKLOG.md | Prioritering, nedbrytning, samordning, scope-skydd |
| Research & Development | `rnd-roguelike` | docs/research/ | Best practice, benchmarks, tech-val, källbelagda underlag |
| Programmerare | `dev-roguelike` | src/, tester, build, ARCHITECTURE.md, CHANGELOG.md | All kod |
| UI-designer | `ui-roguelike` | UI_GUIDE.md, design/ | Skärmflöden, juice, tillgänglighet, UI-implementation |
| Rollspelsnörd / community | `rpg-nerd-roguelike` | GAME_DESIGN.md (innehåll), moment-kataloger | Roligt-check, klasser/items/synergier, communityns röst |

## Flöde
1. Anders ger mål → PM bryter ner till milstolpe + tasks.
2. PM briefar R&D och Rollspelsnörd parallellt vid nya designfrågor.
3. Dev och UI bygger i små verifierbara steg; Rollspelsnörd playtestar och betygsätter.
4. PM loggar beslut i DECISIONS.md och uppdaterar STATUS.md.

## Regler
- Committa bara egna filer med explicita sökvägar. Aldrig `git add -A` eller `git add .`. Pusha aldrig, PM pushar.
- Beslut som byter tech stack, kärnloop eller monetisering kräver Anders.
- Ingen leverans räknas som klar utan körda tester/build och rapport av resultatet.
- Alla påståenden om "vad spelare vill" ska ha källa eller märkas som uppskattning.

## Så anropar du en agent
I Claude Code: "Använd pm-roguelike för att planera milstolpe 1" eller via Agent-verktyget med `subagent_type: pm-roguelike`.

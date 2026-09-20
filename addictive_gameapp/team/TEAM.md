# Agentteam – addictive_gameapp

Fyra roller. Definitionerna som Claude Code faktiskt laddar ligger i `/.claude/agents/` (repo-roten, det är kravet för att de ska kunna anropas). Denna fil är teamets översikt.

| Roll | Agent | Ansvar | Äger |
|---|---|---|---|
| Projektledare | `game-project-manager` | Backlog, prioritering, delegering, scope-beslut, status | `docs/BACKLOG.md`, `docs/STATUS.md` |
| Research & Development | `game-researcher` | Best practice, belägg, benchmark, plattformskrav | `docs/research/*.md` |
| Programmerare | `game-programmer` | All kod, byggkedja, tester, prestanda | `app/`, `docs/TECH.md` |
| UI-designer | `game-ui-designer` | Visuell stil, game feel/juice, onboarding, tillgångar | `docs/UI.md`, `app/src/assets` |

## Arbetsflöde

1. Anders ger ett mål till projektledaren.
2. Projektledaren bryter ner i uppgifter med acceptanskriterier och delegerar.
3. Researcher levererar underlag före beslut. Programmerare och UI-designer bygger parallellt mot `DESIGN.md`.
4. Varje uppgift avslutas med verifiering (webbläsare på mobilviewport, `npm run build`) och en rad i `STATUS.md`.
5. Irreversibla beslut och riktningsändringar går till Anders.

## Så anropas en agent

I Claude Code: "Använd game-researcher för att ..." eller via Agent-verktyget med `subagent_type: game-researcher`. Ge alltid: mål, avgränsning, vilka filer som gäller, vad som redan är beslutat.

## Sanningskällor (läs i denna ordning)

1. `docs/PROPOSAL.md` – vad vi bygger och varför
2. `docs/DESIGN.md` – kärnloop, belöningssystem, progression
3. `docs/TECH.md` – stack, byggkedja
4. `docs/UI.md` – stil, känsla, tokens
5. `docs/BACKLOG.md` / `docs/STATUS.md` – vad som pågår

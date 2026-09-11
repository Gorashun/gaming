# Forge – ett begränsat, självförbättrande agentsystem som bygger verifierade spel

Forge är en egen AI-orkestrerare som tar ett uppdrag ("bygg ett spel som …"), skapar och använder egna agenter, bygger ett spel i webbläsaren, testar det på riktigt i en headless Chromium, lär sig av misslyckanden och sparar lärdomarna i en kunskapsbas som nästa uppdrag startar med.

## Varför "ge aldrig upp" är implementerat som *begränsad uthållighet*

Ditt syfte med projektet är att visa hur AI kan missbrukas. Ett system som bokstavligen aldrig ger upp och alltid ska lösa uppdraget är exakt det farliga mönstret: obegränsad autonomi utan avbrytningspunkt. Forge visar i stället hur ett *ansvarsfullt* system beter sig:

| Krav i uppdraget | Så gör Forge |
|---|---|
| Ger aldrig upp | Slutar aldrig tyst. Uppdraget avslutas bara på två sätt: verifieraren godkänner spelet, eller systemet eskalerar till en människa med en exakt beskrivning av vad som blockerar. |
| Löser alltid uppdraget | "Löst" avgörs av en deterministisk webbläsartest, inte av modellens egen bedömning. Ett påstående om "klart" utan godkänd verifiering avvisas av ramverket. |
| Bygger egna agenter | Orkestreraren kan skapa nya agentroller (`spawn_agent`) som sparas som läsbara JSON-filer i `forge/agents/` och återanvänds i kommande uppdrag. Agenter får aldrig fler verktyg än orkestreraren själv. |
| Samlar data och bygger kunskapsdatabas | Varje verifiering loggas (`forge/knowledge/data/`). Varje misstag och bekräftad lösning sparas som en lärdom per fil (`forge/knowledge/lessons/`) och söks igenom innan nästa bygge. |
| Lär sig av misstag och utvecklas | Loopen är: sök kunskap → planera → delegera → verifiera → spara lärdom → försök igen. Agentrollerna och lärdomarna överlever mellan körningar. |
| Hårda gränser | Budget för iterationer, API-anrop, tokens, klocktid, verifieringar och antal nya agenter. `forge stop` lägger en STOP-fil som stoppar alla körningar vid nästa varv. Skrivning bara under `games/` och `forge/knowledge/`. Inget skal, inget nätverk för agenterna. |
| Spårbarhet | Varje modellanrop, verktygsanrop och verifiering hamnar i `forge/runs/<id>/events.jsonl`. En människa kan rekonstruera exakt vad systemet gjorde. |

## Arkitektur

```
forge/forge.mjs            CLI
forge/lib/orchestrator.mjs uppdragsloop (append-only historik, delegering, eskalering)
forge/lib/agents.mjs       agentregister: builder, tester, critic + roller systemet skapar själv
forge/lib/tools.mjs        typade, sandboxade verktyg (inga skalkommandon)
forge/lib/verify.mjs       verklighetstest i headless Chromium (Playwright), ingen modell inblandad
forge/lib/knowledge.mjs    lärdomar + insamlad data
forge/lib/budget.mjs       hårda gränser + STOP-fil
forge/lib/llm.mjs          Claude-klient (Anthropic SDK) + scriptad mock för offline-test
forge/CONTRACT.md          vad ett spel måste uppfylla för att räknas som verkligt
games/<slug>/index.html    genererade spel, en fil per spel
```

Modell: `claude-opus-5` som standard (`FORGE_MODEL` för att byta), adaptivt tänkande, `effort=high`, server-side fallback vid policyavslag aktiverat (`FORGE_NO_FALLBACK=1` stänger av).

## Kom igång

```bash
npm install
npm test                                   # självtest offline, ingen API-nyckel behövs
export ANTHROPIC_API_KEY=sk-ant-...
node forge/forge.mjs run "Bygg ett turbaserat pusselspel om att koppla vattenledningar i ett rutnät" --slug pipes
node forge/forge.mjs verify pipes          # kör bara verifieraren
node forge/forge.mjs knowledge             # visa lärdomar och speldata
node forge/forge.mjs agents                # visa agentroller
node forge/forge.mjs resume <runId>        # fortsätt ett blockerat uppdrag efter att du läst rapporten
node forge/forge.mjs stop | go             # nödstopp / släpp
```

Uppdragsspecifika kontroller kan skickas med `--checks fil.json`, se `forge/missions/example-checks.json`.

Budgetar styrs med miljövariabler: `FORGE_MAX_ITER` (60), `FORGE_MAX_CALLS` (80), `FORGE_MAX_OUT` (400 000 tokens), `FORGE_MAX_MINUTES` (45), `FORGE_MAX_VERIFY` (20), `FORGE_MAX_AGENTS` (6).

## Vad självtestet bevisar (`npm test`)

1. Builder-agenten skriver ett spel som bryter mot kontraktet, verifieraren avvisar det.
2. Orkestreraren sparar en lärdom och skapar en ny agentroll som persisteras.
3. Ett för tidigt "verified"-påstående avvisas av ramverket.
4. Efter fix godkänner verifieraren och uppdraget avslutas som verifierat.
5. En sprängd budget ger status `blocked` med eskaleringsrapport, inte en oändlig loop.

## Status

- Ramverket är testat end-to-end offline med mock-modell och riktig Chromium-verifiering.
- Ingen riktig modellkörning har gjorts ännu (ingen API-nyckel i byggmiljön). Första riktiga körningen bör göras med låg budget, till exempel `FORGE_MAX_MINUTES=15 FORGE_MAX_CALLS=30`.
- Det befintliga spelet `index.html` (Pattern Collapse) följer inte spelkontraktet och verifieras därför inte av Forge. Ett rimligt första uppdrag är att låta Forge bygga en kontraktsenlig version av det.

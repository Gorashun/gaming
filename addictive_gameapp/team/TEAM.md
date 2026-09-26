# KLUNK studio

Twelve roles. The definitions Claude Code loads live in `/.claude/agents/` at the repo root.

| Role | Agent | Owns |
|---|---|---|
| Producer / project manager | `game-project-manager` (run by the main session) | `docs/BACKLOG.md`, `docs/STATUS.md`, `docs/STUDIO_PLAN.md`, decisions |
| Research & development | `game-researcher` | `docs/research/*.md` |
| Systems & retention design | `game-designer` | `docs/RETENTION.md`, numbered specs in `docs/DESIGN.md` |
| Balance & economy | `balance-analyst` | `docs/sim/` simulations and reports |
| Art direction | `art-director` | `docs/ART_DIRECTION.md`, visual sign-off |
| UI / game feel | `game-ui-designer` | `docs/UI.md`, `app/src/data/*` visual data, pure renderers |
| Audio | `audio-designer` | `docs/AUDIO.md`, synth data |
| Programming | `game-programmer` | `app/src/**` scenes and systems, `docs/TECH.md` |
| QA | `qa-tester` | `docs/BUGS.md`, test suites |
| Release & performance | `release-engineer` | `.github/workflows/`, Android config, `docs/RELEASE.md` |
| Child safety & compliance | `child-safety-reviewer` | `docs/reviews/` |
| IP & legal risk | `legal-reviewer` | `docs/legal/` |

## Operating rules (set by Anders, 2026-09-26)
1. **Design questions are not escalated to Anders.** The team decides from research: researcher and game designer propose, balance analyst simulates, art director and child-safety/legal review, producer decides and logs it in `DESIGN.md`. Anders is asked only about money, accounts, publishing, or a genuine change of direction.
2. **Premium bar.** Every screen and moment must look and feel polished. Art director signs off visual changes.
3. **Gates before build:** child-safety review for any retention/reward/randomness change; legal review for any new name, character, set, sound or store text.
4. **Gates before a test release:** QA (three green full e2e runs, no open P1), release checklist, art sign-off on changed screens.
5. **Guardrails for players 7+:** reward returning, never punish absence; no streak loss, expiring timers, limited-time exclusives, ads, real money, network or tracking; no push by default; odds visible; flash guard and calm mode.

## Flow per feature
research → design spec (numbers) → simulation → safety + legal review → UI/art spec → implementation → QA → art sign-off → test release.

## Sources of truth (read in this order)
`docs/STUDIO_PLAN.md`, `docs/DESIGN.md`, `docs/RETENTION.md`, `docs/ART_DIRECTION.md`, `docs/UI.md`, `docs/TECH.md`, `docs/BACKLOG.md` / `docs/STATUS.md`.

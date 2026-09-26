# Studio plan: KLUNK to "ready for playtesting"

Producer: main session. Started 2026-09-26 at test version 8.

## Definition of done: "polished and ready for testing"
1. **Retention lanes** from `RETENTION.md` implemented: in-session, session-to-session, daily return, long-term. Each lane passed child-safety review.
2. **Premium look and feel**: every screen and key moment signed off by the art director against `ART_DIRECTION.md`. Scene transitions, lighting, VFX, typography and motion consistent.
3. **Audio**: complete synthesized sound map plus optional adaptive music, signed off.
4. **Balance**: simulations for three player profiles hit the targets in `RETENTION.md` (time to first shell, shells per hour, hours to 24/48 buddies, daily-return value, session length).
5. **Quality**: three consecutive green full e2e runs, zero open P1 bugs, no console errors, fps guard verified, cold start and bundle size within `RELEASE.md` budgets.
6. **Compliance**: child-safety sign-off and legal IP review with no HIGH risks open; licence inventory complete.
7. **Release**: versioned APK on the `test-latest` release, web build on the test link, updated `PLAYTEST.md`.

## Phases
| Phase | Work | Owners |
|---|---|---|
| 1. Audit and direction | Retention research; art audit and polish plan; IP/legal review of what exists; safety baseline review; QA exploratory pass; audio audit; release hygiene (versioning, icon, splash, CI tests) | researcher, art-director, legal, safety, qa, audio, release |
| 2. Design | `RETENTION.md` lanes with numbers; balance simulations; safety + legal gate; art/UI specs for new screens | game-designer, balance-analyst, reviewers, art-director, ui-designer |
| 3. Build | Retention lanes, premium polish batches, audio, fixes from `BUGS.md` | programmers (sequenced to avoid file conflicts), ui-designer, audio |
| 4. Harden | QA passes, performance, art sign-off, compliance sign-off | qa, release, art-director, reviewers |
| 5. Ship to test | Test release, changelog, playtest protocol update | producer, release |

Phases 3 and 4 repeat in batches until the definition of done holds.

## Decision log
Decisions are recorded in `DESIGN.md` (numbered sections) and summarised in `STATUS.md`.

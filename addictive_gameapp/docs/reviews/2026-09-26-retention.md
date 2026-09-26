# Child-safety review: retention lanes (RETENTION.md v1) and audio decisions

Reviewer: child-safety-reviewer · Date: 2026-09-26 · Scope: `docs/RETENTION.md` v1 (lanes N1–N9, player journey §5, targets §6, integration §7, data §8), `docs/DESIGN.md` §19–21, `docs/AUDIO.md` (music default, reveal loudness, tally/buy redesign), and the current store listing (`docs/store/listing.en.md`, `listing.sv.md`). Judged against my baseline `docs/reviews/2026-09-26-baseline.md` (invariants §4 = "inv. 1–10", pattern list §5).

> This review is a design and policy-compliance assessment. It is not legal advice.

## Verdict: **PASS WITH CHANGES**

The spec is careful work. Every lane sits inside a baseline PASS row or meets every PWC-B condition, and several choices are stricter than the baseline asked for: the present banks to 7 and is deterministic, the pool is capped at 40 over 24 h, past Daily Jars pay the same reward, there are no stamp-count rewards, XP comes only from merges, and no lane grants a random item. **No lane is a BLOCK**, and nothing in the spec is a penalty for absence, so PEGI 12 is not triggered (DESIGN §19 holds).

The required changes below (R1–R18) are mostly small. They close gaps where a PASS pattern could drift into appointment pressure in the UI: the Daily dot, the calendar, the present's shape and wobble, the mission icon, and the audio of the return lanes. Batch B also cannot ship until the store text and rating answers in §6 are done in the same release (inv. 10).

---

## 1. Verdict per lane

| Lane | Batch | Verdict | Required changes |
|---|---|---|---|
| N1 Daily Jar | B | **PASS WITH CHANGES** | R1–R4, R13 |
| N2 Tide Pool | B | **PASS WITH CHANGES** | R5, R13, R17 |
| N3 Daily Present | B | **PASS WITH CHANGES** | R6–R9, R13, R17 |
| N4 Journey | A | **PASS** | (R17 for its level-up sound) |
| N5 Trophies | A | **PASS** | (R17) |
| N6 Set mastery | A | **PASS** | – |
| N7 Missions | A | **PASS WITH CHANGES** (PWC-B: all 6 conditions verified) | R9, R10 |
| N8 Aquarium | B | **PASS** | – (one recommendation) |
| N9 Good place to stop | A | **PASS WITH CHANGES** | R11, R15 |
| Economy gate for Batch B | B | condition | R12 |
| Music on by default (DESIGN §21) | audio batch | **PASS WITH CHANGES** | R14, R15 |
| Reveals "richer, not louder" (DESIGN §21) | audio batch | **PASS WITH CHANGES** | R16, R17 |
| Store listing + rating answers | B | **required before release** | R18 (§6) |

Rating impact: Batch A has none. Batch B moves the expected rating to **PEGI 7** (rewards for returning), as accepted in DESIGN §19.

---

## 2. Findings and required changes, per lane

### N1 Daily Jar: PASS WITH CHANGES

What passes: date-seeded, identical for everyone, offline, optional, unlimited replays, a small one-time reward, a full archive paying the same stamp and 2 sand, no streak, no month-complete reward, no stamp count, pacing off, outcome-changing abilities paused, and a round crossing midnight belongs to its start date (no midnight rush). The daily trophies (23–26) are skill and variety goals, not day counts. The archive is correct as designed: if archived days paid less, every missed day would be a permanent loss, which is FOMO.

**R1. The Start dot means "unseen", not "unfinished".** A dot that stays until today's jar is finished becomes a daily to-do mark that a child sees on every visit until they comply. Clear the dot when the Daily sheet is **opened** on that date, whether or not the jar is played. It returns at the next date only.

**R2. No clock and no "tomorrow" anywhere.** The spec does not forbid these yet, so make them explicit rules in the spec and UI.md §17:
- no countdown or time to the next jar ("New jar in 3 h");
- no preview of tomorrow's set or future cells with content (future cells are blank);
- no "come back tomorrow" or "see you tomorrow" copy.

**R3. The calendar must not look like a streak.** A month grid of coloured stamps is the "don't break the chain" calendar unless it is designed against that:
- a stamp earned from the archive is **visually identical** to one earned on the day (no "late" mark, no different colour);
- no styling of consecutive stamps: no connecting lines, no highlighted runs, no "full week" row effect, no counter of stamped days or of faint days;
- the sheet opens on today's month, and faint past cells carry no badge, pulse or "catch up" prompt;
- these rules also apply to anything that reads `daily.days` later (trophies, Journey, listing screenshots).

**R4. The Daily result screen has no primary replay.** The spec says "Try again (primary)" and also "all equal height". The first finish of the date is a natural end and doubles as the N9 stop moment, so Try again, Home and Calendar get **equal visual weight**. Label it **"Play again" / "Spela igen"**, since "Try again" frames the finished round as a failure.

Recommendation: guest-set catches that stay hidden until the set unlocks can feel like lost progress to a 7-year-old. Show them on the result card as silhouettes with a small "saved" book icon.

### N2 Tide Pool: PASS WITH CHANGES

What passes: linear fill over 24 h to 40 pearls (≤ 1 round), no decay, no "full!", nothing on Start, one tap (opening the Aquarium), no multipliers or upgrades, clock rollback gains nothing, and it also fills while playing.

**R5. The nap is content, not waiting.** At the cap the Glimmers "nap". The nap pose must read as cosy and sleepy, never bored, sad or "waiting for you". It must be identical whether the pool has been full for 1 hour or 10 days, so there is no escalating visual for absence. The collect sound follows R17.

### N3 Daily Present: PASS WITH CHANGES

What passes: 1 per date, banks to 7, never expires, deterministic cycle, value the same on day 1 and day 100 (≤ 1 round), **one unwrap for all waiting presents** (not an "open all" loop), no number, never a buddy.

**R6. It must not be a shell.** A ribbon-tied scallop that is "opened" sits one silhouette away from the buddy shells, the one mechanic on watch (baseline §3). A 7-year-old will read "a shell you open" as a shell. Draw it as a **wrapped parcel**, which also matches the SV name "Dagens paket". No rarity colours, sparkle or glow.

**R7. The unwrap is the same whatever is inside.** Every unwrap uses the same animation, length (0.6 s) and sound, whether it holds 25 pearls, sand or a decoration. The decoration appears **after** the unwrap has finished. The unwrap must not use the reveal ladder, anticipation, or a longer or louder version for the fifth present. A fixed schedule that plays like a surprise is fine only if nothing in the presentation builds suspense about it.

**R8. Wobble only on the first Start of a session.** "One gentle wobble when Start appears" fires every time the child returns to Start after a round, including right after the N9 stop moment. That conflicts with N9's own rule ("no new badges or wobbles triggered by leaving"). The present should wobble only on a cold start or on return from background (the N9 session definition), and never when coming back from a round, the Book, Buddies or the Aquarium.

**R9. Honest schedule on the parent sheet.** The "unannounced" decoration cycle is acceptable because it is deterministic, but a parent must be able to see it. Add to the CS1 info sheet: "The daily present is always the same: 25 pearls, 25 pearls, 1 star sand, 25 pearls, 25 pearls and a decoration, then it starts again. Up to 7 are saved." (The SV equivalent is written with legal.)

### N4 Journey: PASS

A free progression track by total merges, with no reset, no season and no premium lane. The next 3 rewards are visible, there is no timer, grants are automatic (no unclaimed nag), and XP comes only from merges. The endowed start (15/30) is benign. The level-up flyer has to fit inside the 2.5 s round-end budget, as specified; qa should cover that with a crowded round-end screenshot (catches + level-up + trophy + mission row + stamp).

### N5 Trophies: PASS

No day-count, spend, open or negative trophies. Hidden trophies are playful and skill- or exploration-based. "Calm and Steady" rewards using Calm mode, which is a good nudge. Legacy sand is paid once, and the migration marks earned trophies without paying twice. "Journey 10/50" are play-volume milestones, which the baseline allows (it bans day counts, not volume). No change needed.

### N6 Set mastery: PASS

Cosmetic only, 0 currency, nothing missable, and the Daily Jar guest set counts but is always reachable through normal play and the archive.

### N7 Missions: PASS WITH CHANGES

I verified PWC-B condition by condition:
- B1: nothing expires.
- B2: swap is free, unlimited and instant.
- B3: all 26 goals are skill or variety; none says "play N rounds", "log in", "open", "spend" or "upgrade", and there are no Daily Jar missions.
- B4: rewards are deterministic and T3 ≈ 65 pe, under one round.
- B5: no all-3 bonus. Trophy 32 is recognition only.
- B6: no timers and no daily/weekly labels.

PWC-F also holds: icons show at round start for 1.2 s, and there is no fail state or failure sound.

**R10. No closed-gift icon on mission cards.** Hiding the reward to limit overjustification is fine. Showing the **same closed gift on every card** turns each mission into a mystery box, and it would be the third "gift" concept next to the "Gift!" free shell (CS5) and the Daily Present. Use a neutral goal mark instead: an empty star or ring that fills on completion. The reward then flies out as specified. The exact tiers stay on the parent sheet (R9).

### N8 Aquarium: PASS

No needs, no decay, no night or sad states, items never from random draws or currency, always reversible, a Start badge only for a new unseen item, no pool amount on Start. The new loops (swimmer bob ≤ 0.5 Hz, nap bob, Glimmer flip ≤ 2/s, shiny ring 0.83 Hz) are within the flash guard as long as they are registered (inv. 8) and damped in Calm mode.

Recommendation (not required): move the "9 / 62" sub-line from the Start card to the Aquarium screen. A permanent completion fraction on Start is a mild "unfinished" pull, and 12 of the 62 items can only come from future dates.

### N9 Good place to stop: PASS WITH CHANGES

The design matches baseline P1-4:
- it shows once per session, after all rewards;
- it blocks nothing and offers no reward either way;
- Home and Replay are equal on that screen;
- Calm mode shows it too;
- the Daily Jar finish also counts.

**R11. T1 is a health signal, not a target to optimise.** RETENTION §6 T1 reads "stop moment shown in ≤ 25 % of child sessions". Nobody may meet that number by moving the trigger. Reword it as: "Measure the share of child sessions that reach the stop moment. If it is above 25 %, look at session length, never at the trigger." `WELLBEING` thresholds (20 min, 6 rounds, 10 min gap) change only with a child-safety review. They are not balance knobs and must not be added to the §6 knob list.

Also R15 (music at the stop moment).

### Economy gate for Batch B

**R12. Ship Batch B only on simulated numbers, not estimates.** The casual child, the most sensitive profile, sits closest to the limits: T8 daily-lane share ≈ 32 % (limit 35 %) and T9 return-only value ≈ 0.76 of a round (target ≤ 0.8). balance-analyst must confirm **T8 ≤ 35 % and T9 ≤ 0.8 for the casual profile at 4/7 and 7/7 days played** before Batch B is built. If either misses, apply the §6 knobs in order.

### Tests that protect the invariants (all Batch B lanes)

**R13. Add unit tests for gap invariance and the clock:**
- **Gap invariance (inv. 4):** a save that plays dates 1, 3, 5 and a save that plays dates 1–5 get the same reward per date and per present. Nothing depends on consecutive dates.
- **No loss (inv. 1):** after 30 days away, the pool is at 40 and the bank at 7, and nothing earned is lower than before.
- **Clock backwards:** the pool, present and daily state gain nothing and lose nothing.
- **Blind randomness (inv. 6, CS7):** the Daily queue and the director output are identical for any save contents.

---

## 3. Player journey (RETENTION §5): appointment pressure and FOMO

The journey is mostly driven by play: the "next thing" column is Journey rewards, sets, silhouettes and trophies. Four rows use **time** as the next thing. They are fine as design estimates but must never become UI:

| §5 row | Text | Risk | Rule |
|---|---|---|---|
| First session | "the pool fills while you're away" | an absence hook if shown as copy | no in-game text about the pool filling; the unlock line is only "Your Glimmers moved in!" |
| Day 1 end | "a new jar tomorrow", "L4–5 tomorrow" | appointment framing | R2: no "tomorrow", no countdown, no preview of tomorrow's set |
| Day 2 | "next jar tomorrow" | same | same |
| Day 7 / Day 30 | "4–7 stamps", "a month of stamps" | the calendar as a streak artefact | R3 |

Other points from §5:
- **Unlock density on day 1.** Missions, Aquarium, Pool, Present and Daily Jar can all unlock in the first session for an engaged child, and the Daily dot can appear within the first hour. This is acceptable because none of them has a clock. R1 keeps the dot from becoming a daily chore from day 1.
- **Absence converts into archive value.** After a week away, 7 faint days worth 2 sand each are available. That is inv. 3-safe, because each needs a full round, and it is the right alternative to losing them. R3 (no backlog count or "catch up" prompt) keeps it from reading as a debt.
- **The round-end reward stack grows.** It can now include catches, tally, XP fill, level-up, trophy, mission row, stamp and the stop line. The 2.5 s cap and restart from t = 0 are what keep this from becoming a harvest loop. The combined crowded screenshot (N4 above) must pass the 2.5 s budget and show the Home button from t = 0.
- **No weekly cadence, no seasonal content, no reminders:** correct, and nothing in §5 depends on them.

Nothing in §5 creates a penalty, an expiry or scarcity. Once R1–R3 are applied, the remaining pull is "there is something new today", which is the accepted PEGI 7 play-by-appointment pattern.

---

## 4. Audio decisions (DESIGN §21, AUDIO.md)

### Music on by default at the −14 LU bed: PASS WITH CHANGES

A quiet generative bed is not a dark pattern. It stays 14 LU under the merge, has a separate Music toggle, is muted by the Sound master switch, and has a calm variant (64 BPM, half density). Its coupling to the director is bounded (tempo ±10 %, density only, no risers or build-ups, the kick bar lands after the special is visible). That is acceptable, and I sign off on AUDIO §4.1's child-safety gate with these conditions:

**R14. The music knows only the round, never the meta layer, and is silent in the background.**
- It reads only scene, director mode, danger and calm. It never reads economy, pending presents, pool level, pending shells, daily status, session length or records. Menu music must be identical whether or not something is waiting (extend inv. 6 to `systems/music.ts`, with a unit test).
- A2 lifecycle (suspend on `visibilitychange` and Capacitor `pause`) must ship **before** A7. Music playing in the background or on the lock screen is a sticky feature.
- No MediaSession, no foreground service, and no new Android permission (for example WAKE_LOCK or FOREGROUND_SERVICE). Adding `@capacitor/app` must still pass the CI permission gate (VIBRATE only).
- DESIGN §21's line "off in calm mode's quiet variant only if the player turns it off" is ambiguous. Replace it with AUDIO §4.5's rule: Calm mode plays the calm variant, and Music off is always one tap in Settings.

**R15. The music settles at the stop moment.** "GameOver: pad + bass only, carries over seamlessly into the next round" is a continuity device that smooths the gap between rounds. On the N9 stop screen, let the pad resolve over 2 bars and fall to the menu bed level. There must be no seamless hand-off into the next round and no cue that suggests continuing.

### Reveals "richer, not louder": PASS WITH CHANGES

This fixes the one real audio problem: a 13.8 LU loudness climb from common to mythic that builds anticipation on rarity. With loudness matched, rarity carried by harmony, tail and reverb, and no step faster or higher than E6, the reveal is the "same ceremony for every outcome" required by baseline §2 and PWC-E. The tally redesign (at most 6 soft ticks, not a counter) and the `buy` redesign (not a coin) also resolve baseline P3-3 and AUDIO's slot-counter note. Approved.

**R16. Lock the reveals down in the automated test (A4):**
- every `reveal.*` tier within **+4 ±0.5 LU**, with the largest spread between any two tiers ≤ 1 LU, and ≤ 5 % of energy above 4 kHz;
- `shellOpen` and everything before the reveal identical for every shell;
- the longer mythic tail must not lengthen the fixed 1.2 s ceremony or delay tap-to-skip (the tail rings under the next screen);
- the music duck is the same depth for every tier (−8 dB), because a deeper duck would be loudness by another route;
- the calm variants keep the same equality.

**R17. The return lanes are never the loudest reward.**
- Present unwrap, pool collect and daily stamp: tier ≤ T3 (core). The pool collect reuses the soft tally (≤ 6 ticks).
- Journey level-up, trophy and mission-complete: tier ≤ T4 (accent).
- None of them reuses `reveal.*`, `jackpot`, `newSet` or any coin-like sound. The present unwrap is one sound for every content (R7).
- Register all of them in `VOICE_RULES` and the A4 loudness test.

---

## 5. Wording rules for all new UI text (EN/SV)

These apply to every new string in RETENTION (lane names, mission texts, trophy names and descriptions, result cards, Aquarium lines, the stop line, parent sheet) and to future strings in these lanes. Legal still reviews every [LP] name (TEAM rule 3). ui-designer should add a unit test that scans `app/src/data` strings for the forbidden list below.

**Never, in either language:**

| Category | EN (forbidden) | SV (förbjudet) |
|---|---|---|
| Urgency | hurry, quick, now, before it's gone, only today, today only, last chance, ends, expires, left (as in "2 left") | skynda, snabbt, nu, innan det försvinner, bara idag, sista chansen, slutar, går ut, kvar ("2 kvar") |
| Missing out | don't miss, you missed, missed days, catch up, you were away X days | missa inte, du missade, missade dagar, ta igen, du var borta X dagar |
| Guilt / absence | waiting for you, misses you, lonely, sad, come back, see you tomorrow, where were you | väntar på dig, saknar dig, ensam, ledsen, kom tillbaka, vi ses imorgon, var var du |
| Streaks | streak, in a row / days in a row (for days), perfect week/month, don't break | svit, streak, dagar i rad, perfekt vecka/månad, bryt inte |
| Clock | countdowns, "in 3 h", "new at midnight", "tomorrow" | nedräkningar, "om 3 h", "ny vid midnatt", "imorgon" |
| Gambling / sales | win, prize, jackpot, lucky, mystery, bonus, free, claim, collect now, exclusive, limited, rare chance | vinn, vinst, jackpott, tur, mystisk, bonus, gratis, hämta nu, exklusiv, begränsad |
| Fullness / loss | full!, overflowing, wasted, don't waste | fullt!, svämmar över, slöseri, slösa inte |
| Continue pressure | one more, keep going, don't stop, are you sure you want to leave? | en till, fortsätt, sluta inte, vill du verkligen gå? |

("in a row" / "i rad" is fine for in-round actions, such as trophy 33's taps. It is never used for days.)

**Always:**
1. An exclamation mark only for something **already earned or done**: "Chain of 4!", "You already did this!", "Your Glimmers moved in!", "Nice run!". Never for something waiting or available.
2. Descriptions are present-tense facts about play, not calls to return: mission texts are imperatives about the round ("Make a chain of 3"), which is fine.
3. Numbers only for the player's own play (score, best, progress 2/3). Never a count of days, days away, days missed, stamps in a month, or presents waiting.
4. Button labels are neutral verbs of equal weight: "Play again" / "Spela igen", "Home" / "Hem", "Calendar" / "Kalender". Never "Try again" on a finished Daily Jar (R4).
5. The stop line stays exactly "Nice run! Good place for a break." / "Bra runda! Ett bra ställe att ta paus." No variants that praise continuing or reward stopping.
6. Short and icon-first, for 7-year-olds who read slowly: ≤ 10 characters for Start labels, one line for mission and trophy text, an icon on every mission card.
7. Only one "gift" word per concept: "Gift!" / "Gåva!" = free buddy shell (CS5). "Present" / "Paket" = daily present. Missions use no gift word or icon (R10).
8. Parent sheet text may give exact numbers and schedules (R9). That is honesty, not pressure.

---

## 6. Store listing and rating answers after Batch B (R18)

These must ship **in the same release as Batch B** (DESIGN §19, inv. 10). Note that the baseline P1-2 fixes are **still not in** `listing.en.md` / `listing.sv.md` ("Merging earns shells", "Friends grow through three levels as you play with them", "No text needed to play", "One more try takes less than a second"), and there is still no privacy policy. Those are due before any public submission, Batch A included.

### 6.1 Listing (EN and SV, legal-reviewed)
Must say, in substance:
- **Age line:** "7+. PEGI 7 expected: the game rewards coming back (a daily jar, a daily present and a tide pool), and nothing is ever lost if you don't." / "7+. Väntat PEGI 7: spelet belönar att man kommer tillbaka (dagens burk, dagens paket och tidvattenpölen), och inget går förlorat om man inte gör det." Replace "PEGI 3 / IARC 3+ expected" everywhere.
- **Remove "No waiting timers" / "Ingen väntetid".** The tide pool fills over time, so this claim is no longer literally true. Use: "No countdowns and no energy: you can always play." / "Inga nedräkningar och ingen energi: du kan alltid spela."
- **Keep and sharpen:** "No streaks: missing a day never costs anything. Nothing expires." / "Inga sviter: att hoppa över en dag kostar ingenting. Inget går ut."
- **Describe the three return lanes factually:** "A new Daily Jar each day, the same for every player; past days stay playable." · "A small present each day; up to 7 are saved for you." · "The aquarium's tide pool slowly gathers a few pearls over about a day, then simply stops." No "every day you come back…" framing.
- **Keep the baseline sentence:** "The shop uses only pearls and star sand earned by playing. Nothing can be bought with real money, and there are no ads."
- **Wellbeing, once Batch A has shipped it:** "After a longer session the game suggests a good place for a break." / "Efter en längre stund föreslår spelet ett bra ställe att ta paus."
- **Privacy:** "No accounts, no data collection, no network. Progress and dates are stored only on this device." A privacy policy URL is linked in both stores.
- **Keywords, screenshots and "What's new":** no "daily reward", "free gift", "login bonus" or streak terms. No screenshot whose hero is the present pile, the Daily dot or a full calendar. "What's new" is descriptive with no FOMO ("New: the Aquarium, a Daily Jar and a daily present.").

### 6.2 IARC questionnaire (Google Play, generates PEGI)
Answer truthfully and consistently with Apple:
- **Rewards for returning / play-by-appointment: Yes** (Daily Jar reward, Daily Present, Tide Pool).
- **Penalties or loss for not returning: No.**
- **In-game purchases with real money: No.** Time- or quantity-limited offers: **No.**
- **Paid random items: No.** The currency cannot be bought or exchanged. Where the questionnaire asks about random items obtainable **with earned in-game currency**, answer **Yes** (buddy shells; exhaustible, no duplicates, odds shown).
- **Simulated gambling: No.** User interaction, chat, sharing, location, UGC, ads: **No.**
- File the answers and the certificate in `docs/store/` for the inv. 10 audit. The expected result is **PEGI 7**. If IARC returns PEGI 12 or 16, **stop the release and escalate**, and do not tune the answers. PEGI 16 would trigger the baseline §3 switch to `SHOP.mode = 'pick3'`.

### 6.3 App Store Connect age rating
- **Loot Boxes:** Apple defines them as "randomized virtual items **for purchase**". Our reading is **No**, because nothing can be purchased and the currency has no link to money. Legal must confirm this reading before submission. A **Yes** gives an **18+ rating on the Brazil storefront**, and in that case switch purchased shells to `pick3` (baseline §3 trigger 1) rather than ship with that answer.
- **Simulated Gambling: None.** Advertising, Messaging/Chat, UGC, Unrestricted Web Access, Age Assurance, In-App Controls: **No / None.**
- **Contests** ("compete with one another for rankings, rewards, or the achievement of personal goals"): there is no player-vs-player competition and the Daily Jar has only a personal best. Legal to confirm the answer, and keep it consistent with the "no leaderboards" claim.
- Play Families: no change to target age groups. Data safety stays "No data collected, no data shared". The CI permission gate must still show only VIBRATE after Batch B and the audio batch.

---

## 7. Checked and passing (no change)

| Area | Result |
|---|---|
| Inv. 1 nothing removed / inv. 2 nothing time-limited | PASS: archive, bank, cap without decay, no seasonal |
| Inv. 3 waiting < one round | PASS on estimates (T9 casual 0.76), confirm with R12 |
| Inv. 4 no consecutive-day logic | PASS by spec; locked by R13 |
| Inv. 5 privacy | PASS: local date, local save (schema 3), no network, no identifiers, no notifications in v1 |
| Inv. 6 randomness blind to meta | PASS: Daily queue pure function of `dateKey`, CS7 test; extended to music (R14) |
| Inv. 7 no new random rewards | PASS: no lane grants shells or random items; gold shell rejected as Journey reward |
| Inv. 8 loops ≤ 1 Hz, registered | PASS if the §8.1 list is registered and Calm-damped |
| Rejected lanes (§1.7) | Correct: "welcome back" gift, pool upgrade, weekly chest, reminders |
| Save migration 2 → 3 | PASS: no wipe, no retroactive currency, no double legacy sand |

---

## 8. Actions and owners

| # | Action | Owner |
|---|---|---|
| R1–R4 | Daily dot = unseen; no clock or tomorrow; calendar rules; equal result buttons, "Play again" | game-designer (spec), ui-designer (UI §17) |
| R5 | Nap pose content, identical at any fill age | art-director, ui-designer |
| R6–R8 | Present as a parcel; same unwrap for every content; wobble only on session start | game-designer, ui-designer, audio-designer |
| R9 | Present cycle and mission tiers on the parent sheet | ui-designer, legal-reviewer (text) |
| R10 | Neutral mission goal mark, no gift icon | ui-designer |
| R11 | Reword T1; `WELLBEING` thresholds not a balance knob | game-designer, balance-analyst |
| R12 | Sim confirms casual T8 ≤ 35 %, T9 ≤ 0.8 before Batch B | balance-analyst |
| R13 | Gap-invariance, no-loss, clock and blindness tests | game-programmer |
| R14–R15 | Music reads no meta; A2 before A7; no new permission; settles at the stop moment; fix the DESIGN §21 calm wording | audio-designer, game-programmer, producer |
| R16–R17 | Reveal equality in the A4 test; return-lane sounds ≤ T3 / ≤ T4 | audio-designer, game-programmer |
| R18 | Listing EN/SV, privacy policy, IARC and Apple answers, filed in `docs/store/` | producer, legal-reviewer, release-engineer |

I will re-review Batch A on its first build and Batch B before its release candidate, including the IARC certificate.

---

## 9. Sources

"sek." = only search summaries were reachable, as in the baseline. Apple's reference page was read at the source.

- PEGI, "PEGI expands age rating criteria with interactive risk categories" (play-by-appointment → PEGI 7, punishment for not returning → PEGI 12, time/quantity-limited offers → PEGI 12, paid random items → PEGI 16) (sek.): https://pegi.info/news/pegi-expands-age-rating-criteria-interactive-risk-categories
- The FPS Review, PEGI interactive risk update, 13 Mar 2026 (sek.): https://www.thefpsreview.com/2026/03/13/pegi-updates-its-rating-system-to-address-interactive-risk-categories-such-as-loot-boxes-in-game-monetization-and-safe-online-gameplay/
- Lexology, PEGI updates age ratings and interactive risk criteria (sek.): https://www.lexology.com/library/detail.aspx?g=169f6555-4413-4972-bdbc-a7f1ec36b37e
- Apple, "Age ratings values and definitions" (Loot Boxes, Simulated Gambling, Contests, In-App Controls definitions, read at the source 2026-09-26): https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/
- Apple Developer News, "Updated age ratings in App Store Connect" (answers required by 31 Jan 2026): https://developer.apple.com/news/?id=ks775ehf
- Apple Developer News, age requirements for Brazil and others (sek.): https://developer.apple.com/news/?id=f5zj08ey
- Brazil Digital ECA, loot boxes banned for minors from 17 Mar 2026; App Store Brazil 18+ when "loot boxes" is declared (sek.): https://factotumcom.substack.com/p/brazil-digital-eca-bans-loot-boxes
- Baseline sources (ICO Children's Code std 13, FTC 2022 dark patterns, Play Families, 5Rights, CPC Network, DFA): see `docs/reviews/2026-09-26-baseline.md` §7.
- Internal: `docs/RETENTION.md` v1, `docs/DESIGN.md` §19–21, `docs/AUDIO.md` v0.1 §3.3, §3.7, §4, `docs/research/retention-lanes.md` §4, `docs/store/listing.en.md`, `listing.sv.md`.

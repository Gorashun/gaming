# RETENTION.md: KLUNK retention lanes

Owner: game-designer · v1.1 2026-09-26 · Status: **design. Child-safety review `reviews/2026-09-26-retention.md` = PASS WITH CHANGES; all required changes R1–R18 applied (marked "applied (Rn)"). Legal review `legal/ip-review-2026-09-26-retention.md` applied (LG3, LG9). v1.2: balance sim `sim/retention.md` adopted (DESIGN §24); trophies and mastery redefined for reachability (§3.5–3.6), waiting for the analyst's re-simulation.** Nothing in this file may be built before the gates in TEAM.md rule 3.
Sources: `research/retention-lanes.md` (R#1–R#11 = its ranking), `reviews/2026-09-26-baseline.md` (inv. 1–10 = its §4 invariants, "PASS/PWC-x/BLOCK" = its §5 pattern list), `research/economy-research.md` + `economy-sim.py`, DESIGN §1–19, data files as of test version 8.

Conventions:
- **(est.)** = estimate. Nothing here is measured; `merges per round` is still unmeasured (PLAYTEST.md). All numbers live in `app/src/data/` (§8).
- **pe** = pearl-equivalent, used only for comparing value. **1 sand = 25 pe (est.)**, from earn-rate parity (≈60 pearls + ≈2.4 sand per round, economy-research §5.4).
- **[LP]** = new player-facing name, **pending legal** (TEAM rule 3). All new names are generic and descriptive by design.
- Date = **local calendar date of the device**, key `YYYY-MM-DD`. Clock tampering is accepted as harmless (offline, no social layer).

---

## 1. Lane map (existing + new), by cadence

Status column cites the baseline review. Size: S ≈ 1–2 d, M ≈ 3–5 d, L ≈ 6–10 d, including UI and tests (est.).

### 1.1 In-round (seconds): saturated, no new lanes
| Lane | Trigger | Action | Variable reward | Investment | Guardrail | Safety status | Size |
|---|---|---|---|---|---|---|---|
| Combo / chain (§5) | merge happens | drop, aim | pitch rise, cascade | none | pitch cap combo 12, flash guard | PASS (baseline §2) | exists |
| HUD chain + "?" (§13.1) | new level created | merge upward | a new light | none | no text, ≤1 Hz | PASS | exists |
| Shiny (§13.2) | creation | merge | sparkle, fifth tone | book slot | visible pity, cosmetic only, RNG blind to meta (inv. 6) | PASS | exists |
| Specials bomb/rainbow (§4) | kick 25–60 drops | use it | clear / level up | none | seeded, blind to meta | PASS (P2-6) | exists |
| Genuine near-miss (§5) | two ≥8 almost touching | aim | tension | none | **same level only (CS3)** | P1-3 open | exists |
| Record chase (§5) | score ≥90 % of best | keep going | newRecord kick | record | own record only | PASS | exists |
| Danger slow-mo (§5) | near danger line | save the jar | relief | none | max 3/10 s | PASS | exists |
| Auto-drop pacing (§11–12) | idle in Flow | drop | – | – | difficulty, not retention; never tied to meta (P2-5) | PASS w/ cond. | exists |
| Buddy ability (§14.5) | per round | play | feel/info/mild effect | upgrade | ≤ +30 % param, no direct score | PASS | exists |

### 1.2 Session (minutes, "one more round")
| Lane | Trigger | Action | Variable reward | Investment | Guardrail | Safety status | Size |
|---|---|---|---|---|---|---|---|
| Round-end "new!" (§13.4) → **Round summary (§10.2)** | loss screen | look / tap to replay | everything gained this round | book, Journey | typical ≈2.5 s, hard cap 3.5 s, restart <0.5 s from t = 0, skipped → fresh markers | PASS (extends existing) | M |
| **In-round pickup feedback (§10.1)** | a merge, sand event, completion | play | pearl/sand tokens, toast chips | – | batched, ≤2 tokens/s, 1 toast per 3 s, never over the jar, calm mode reduced | PASS (feedback, not a new reward) | S |
| Pearls / sand tally (§16.1) | round end | – | amount of the round | currency | ≤0.6 s, no coin clink, never "double it" | PASS (P3-3) | exists |
| Free shell (§16.2) | merge milestone | open on Start | buddy (random, no dupes) | buddy | fixed 1.2 s ceremony, no pity, **CS6: first = choose 1 of 3** | PASS / watch item §3 | exists |
| Shells shop + upgrades (§16.2–16.3) | enough pearls | buy / upgrade | buddy / param step | currency → buddy | honest odds (**CS1**), two-tap buy, no "afford" badge | PASS / watch item | exists |
| Set bar → set unlock (§13.3) | merges | play | which set (random order) | book page | no dupes, nothing missable | PASS | exists |
| **N7 Missions** (new) | 3 cards in Journey sheet, progress at round end | play for a goal | *which* mission comes next; reward hidden until done | none | never expire, free swap, skill/variety only | **PWC-B**, all 6 conditions met (§3.7) | M |
| **N9 Good place to stop** (new, = CS4) | ≥20 min or ≥6 rounds in a session | – | – | – | once per session, blocks nothing, no reward either way | **PASS** (wellbeing moment) | S |

### 1.3 Session-to-session (hours)
| Lane | Trigger | Action | Variable reward | Investment | Guardrail | Safety status | Size |
|---|---|---|---|---|---|---|---|
| **N2 Pearl Pool** (new, inside Aquarium; was Tide Pool) | "something happened while I was away" | open Aquarium (1 tap = collect) | none by design: deterministic, fills over 24 h | – | cap 30 pearls ≤ 1 round, ≥24 h fill, never lost, no "full!" alert, no amount on Start | **PASS** (capped while-away accumulator) | S |
| **N4 Journey** (new) | bar on Start, next 3 rewards visible | play (XP = merges) | every level a reward, bigger every 5 | level badge | XP only from merges; no reset, no season, no premium lane | **PASS** (free progression track) | M |

### 1.4 Daily
| Lane | Trigger | Action | Variable reward | Investment | Guardrail | Safety status | Size |
|---|---|---|---|---|---|---|---|
| **N1 Daily Jar** (new) | a new jar each date, same for everyone | play one round | new set + new queue each day; own best | stamp calendar | no streaks, archive of past days, missed days cost nothing, abilities that change outcomes paused (fairness) | **PASS** (daily seeded challenge), PEGI 7 | M |
| **N3 Daily Present** (new; brief's "Gift Shell") | a present sits on the Start stage | 1 tap | none random: deterministic cycle, occasional decoration (not announced) | – | 1/day, banks to **7**, never expires, ≤ 1 round of pearls | **PASS** (daily gift, stacks), PEGI 7 | S |

### 1.5 Weekly: **none, on purpose**
| Candidate | Decision | Why |
|---|---|---|
| R#11 Weekly set | **merged** into N1 (5-set daily rotation = 5-day rhythm) | a weekly bonus counts as "event-based" (PEGI 7 descriptor again); pure variation already comes from N1 |
| Weekly chest / weekly missions | **rejected** | PWC-B.6 (no "weekly" labels); BLOCK risk (expiry framing) |

### 1.6 Long-term (weeks to months)
| Lane | Trigger | Action | Variable reward | Investment | Guardrail | Safety status | Size |
|---|---|---|---|---|---|---|---|
| Collection book 5×21 (§13.2) | "?" silhouettes | play sets | catches, shinies | pages | nothing missable | PASS | exists |
| 48 buddies (§14, §16) | shop, free shells | buy/open | buddy | owned roster | exhaustible, no dupes | PASS / watch | exists |
| Upgrades I–III (§16.3) | pearls | spend | known param step | buddy level | deterministic | PASS | exists |
| **N4 Journey** L6–L100+ | track | play | cosmetics, small currency | level | continues after all 48 buddies | PASS | (above) |
| **N5 Trophies** (new) | Book tab "Trophies" | play, explore | 8 hidden surprises | wall fills | no "play X days / open / spend", no negative trophies | **PASS** (achievements) | M |
| **N6 Set mastery** (new) | 3 stars per Book page | play a set | set cosmetics | page "finished" | cosmetic only, no double sand | **PASS** (collection extension) | S |
| **N8 Aquarium** (new) | Start card | arrange decor, pick swimmers | – (all items deterministic) | a home the player owns | no needs, no decay, no sad states, items never from random draws | **PASS** (aquarium/home) | L |

### 1.7 Considered and not in this build
| Research lane | Decision | Reason |
|---|---|---|
| R#10 Seasonal decor / install-day | **deferred** | PWC-C is fine but adds a date-dependent content path; revisit after playtest |
| Local reminders | **not in v1** | DESIGN §19; if ever built: PWC-A only |
| "Welcome back" gift | **rejected** | PWC-D forbids stacking with the present bank; the bank already covers absence |
| Pool cap upgrade (R#2 "investment") | **rejected** | creates a new sink and makes waiting worth more over time (inv. 3) |
| Gold shell as a Journey reward | **rejected** | no new random-draw path while shells are on watch (baseline §3); sand is given instead |

---

## 2. Chosen lanes for this build (9) and why

| # | Lane | Research rank | Why chosen | Changed vs brief / research, and why |
|---|---|---|---|---|
| N1 | Daily Jar | R#1 ★ | strongest return lane (new content on each date) without loss; reuses seedable director | **Past days stay playable** (PASS row requires an archive). **Board-blind fixed queue** so it is truly identical for everyone. Outcome-changing abilities paused (fairness for 7–10, research §5). **No stamp-count rewards** (would be "play X days", banned for achievements) |
| N2 | Pearl Pool (was Tide Pool, legal LG9) | R#2 ★ | "something happened while away", premium feel | **Merged into the Aquarium** (one home, one tap to collect). Cap **30 pearls** (sim-adopted, DESIGN §24), not "≈1 shell/day" (R#2): PASS row caps at ≤1 round of play |
| N3 | Daily Present | R#3 ★ | covers weekends and trips | **Bank cap 7, not 3** (PASS row requires ≥7). **Deterministic content** (PASS row: never random), so R#3's "occasional surprise" becomes a fixed, unannounced cycle. Player-facing name "Present", not "Gift", because CS5 renames the free buddy shell sub-line to "Gift!". Drawn as a **parcel, not a shell** (R6) |
| N4 | Journey | R#4 ★ | the collection ends after 12–16 h of play; this runs 60–140+ h | XP from merges **only** (no loops with other lanes). Legal guards §9 (never "Journey Pass") |
| N5 | Trophies | R#7 | surprise-based (low overjustification), absorbs the 6 one-time sand milestones | no day-count, spend or open conditions |
| N6 | Set mastery | R#8 | extends 5 sets without new content | star 3 = full page, which already pays 10 sand, so mastery pays **cosmetics only** |
| N7 | Missions | R#6 | session goals; ties HUD icons and sets together | **Surprise-first**: the first mission is revealed already done; rewards hidden until completion; small |
| N8 | Aquarium | R#5 | gives book, buddies and all cosmetic rewards a place (investment) | fixed spots (art budget, kid-simple). L-size, ship with N2 |
| N9 | Good place to stop | R#9 / CS4 | trust, ICO std 13, required before new lanes (baseline P1-4) | built as part of CS4 |

**Build order (proposal for producer):**
1. **Batch A (no rating change):** CS1–CS7 → N9 (with CS4) → N4 → N5 → N6 → N7.
2. **Batch B (one release, PEGI 7 + listing update, DESIGN §19, inv. 10):** N8 + N2 → N3 → N1. **Applied (R12):** Batch B is built only after balance-analyst confirms, by simulation, **T8 ≤ 35 % and T9 ≤ 0.8 for the casual profile at 4/7 and 7/7 days played**. If either misses, apply the §6 knobs in order. **Applied (R18):** the store text and rating answers in §7.4 ship in the same release.

---

## 3. Lane specs

### 3.1 N1 Daily Jar [LP: "Daily Jar" / "Dagens burk"]

**Rules**
| Item | Value |
|---|---|
| Unlock | Journey level 5 |
| New jar | at local 00:00; the date key is fixed at round start (a round that crosses midnight belongs to the start date) |
| Seed | `fnv1a32("klunk-daily-v1:" + dateKey)` → mulberry32. Generator version `v1` is frozen forever; a new generator gets a new prefix |
| Set of the day | `THEME_SET_IDS[dayIndex mod 5]`, `dayIndex` = days since 2026-01-01. Same for everyone, **even if the set is locked for the player** ("guest set", below) |
| Queue (director `daily` mode) | precomputed **600** entries, **never reads the board** (so all players get the same queue). Drops 1–10: uniform over levels 0–2. Then weights for levels 0–4 = **26/24/22/16/12**, with p **0.35** "echo" = repeat the level from 2 drops back (a board-blind stand-in for Flow). If the queue runs out: continue with seed `+1` |
| Specials | a Kick every **25–60** drops (drawn from the day's seed), bomb/rainbow 50/50 |
| Pacing | auto-drop **off** (`DAILY.pacing = 'off'`): keeps the jar identical in timing and makes it the calm mode of the day |
| Buddy abilities | feel and info abilities stay on. **Paused**, because they change outcomes: `magnetPull`, `startRainbow`, `breath`, `noBounceStart`, and `queenRound`'s rainbow + extra specials (the Queen's gold jar and sound stay). The buddy still sits on the jar |
| Economy inside the round | normal: pearls, sand, catches, XP, mission progress, free-shell counter, set-unlock counter. Main highscore **not** affected (separate board) |
| Guest set | if the day's set is locked, the round uses its skin; catches are saved to that set's page and appear, marked fresh, **when the set unlocks by the normal rules** (§13.3). Nothing is missable, and the unlock order stays secret |
| "Finish" | the round ends (loss). Any score counts |
| Reward | **first finish per date: stamp + 2 sand**. Replays unlimited, no further reward |
| Personal best | per date (`best`); shown in the calendar cell and on the result card. No comparison with others |
| Archive | every date from `daily.unlockedOn` to today is playable. **An archived date gives the same stamp + 2 sand on its first finish** (missed days cost nothing; each costs a full round of play, so inv. 3 holds). Maximum archive reward = days since unlock × 2 sand (bounded) |
| Calendar | month grid; stamped days show the day's set icon in colour; unstamped past days show the same icon faint and **neutral** (no X, no grey "missed" state, no count, no month-complete reward). Swipe back to the unlock month. **Applied (R3):** an archive stamp is visually identical to a same-day stamp; no styling of consecutive stamps (no connecting lines, highlighted runs or "full week" row effects); no counter of stamped or faint days; the sheet opens on today's month; faint cells carry no badge, pulse or "catch up" prompt. These rules bind everything that reads `daily.days` (trophies, Journey, listing screenshots) |
| No clock, no tomorrow | **Applied (R2):** no countdown or time to the next jar; no preview of tomorrow's set; future cells are blank; no "come back tomorrow" / "see you tomorrow" copy anywhere (also UI.md §17) |
| Start badge | **Applied (R1):** the static dot means **unseen**, not unfinished. It shows at the first Start of a new date and clears when the Daily sheet is **opened** on that date, played or not. It returns at the next date only. No pulse, no count |

**UI**
| Where | What |
|---|---|
| Start | secondary button under PLAY: today's set icon + "Daily"/"Dagens" (≤10 chars) |
| Daily sheet | calendar, big "Play today" (primary), tap a past day → "Play" + its best |
| In game | small calendar chip under the score (day's set icon); nothing else changes |
| Result | on top of the loss screen: score, "Best today", stamp flies into its cell (0.8 s) + "+2 sand" on first finish. **Applied (R4):** buttons **Play again / Spela igen**, **Home / Hem** and **Calendar / Kalender**, with **equal visual weight** (no primary), because the first finish is a natural end and doubles as the N9 stop moment. Guest-set catches are shown on the result card as silhouettes with a small "saved" book icon (review recommendation, applied) |

**Player sees:** day 1 → one stamp, the day's set (often a locked guest set = a preview). Day 7 → a few stamps, three to five different sets tried. Day 30 → trophies D1–D3 possible, a personal best per day. (Stamp counts are design estimates only and never shown, R3.)

### 3.2 N2 Pearl Pool ["Pearl Pool" / "Pärlpölen", renamed from "Tide Pool" by legal LG9]
| Item | Value |
|---|---|
| Unlock | Journey level 3 (together with N8). The pool starts empty at unlock |
| Fill | **30 pearls over 24 h** = 1.25 pearls/h, linear, by wall clock (while away or playing). **Cap 30** (adopted, DESIGN §24; was 40), then it simply stops. Nothing decays |
| Formula | `amount = min(cap, stored + rate × (now − since))`. On collect: `stored = 0, since = now`. **Clock moved backwards**: `stored = amount at last save, since = now` (nothing lost, nothing gained) |
| Collect | opening the Aquarium **is** the one tap: after 400 ms the pearls fly to the pearl pill (≤0.8 s). Floors to whole pearls; the fraction stays. **Applied (R17):** the collect sound reuses the soft tally (≤6 ticks), tier ≤ T3 |
| Visual | a rock pool in the Aquarium, one small level-0 Glimmer per 5 pearls (max 8). At cap they nap (slow bob ≤0.5 Hz). **No text "full", no badge, no amount shown on Start** (stops "check every few hours"). **Applied (R5):** the nap reads as cosy and sleepy, never bored, sad or "waiting for you", and is **identical after 1 hour or 10 days full** (no escalating visual for absence). No in-game text about the pool filling while away |
| Never | random amounts, bonus multipliers, "collect ×2", upgrades, notifications |

Player sees: day 1 → first fill overnight. Day 7 → ~30 per visit if they come once a day, less if twice (est.). Day 30 → routine "the Glimmers brought pearls".

### 3.3 N3 Daily Present [LP: "Daily Present" / "Dagens paket"]
| Item | Value |
|---|---|
| Unlock | Journey level 4, **one present already waiting** (endowed) |
| Accrual | +1 per new local date since `lastDay`, **bank max 7**. Clock backwards: nothing removed, `lastDay = today` |
| Content | deterministic by `present.opened` (1-based), cycle of 5: #1 **25 pearls**, #2 25 pearls, #3 **1 sand**, #4 25 pearls, #5 25 pearls **+ next present decoration** (12 in order, §3.8). When the 12 are used up, #5 = **25 pearls, no sand** (adopted, DESIGN §24: keeps T12 at 205 pe forever). Average ≈ 25 pe + a decoration every 5th day. Same on day 1 and day 100 |
| Opening | tap the present on the Start stage → one unwrap (0.6 s) for **all waiting presents** together, showing the sum and any decoration. No reel, no candidates, no per-present tapping loop. **Applied (R7):** the unwrap has the same animation, length (0.6 s) and sound whatever it holds; the decoration appears **after** the unwrap has finished; no reveal ladder, no anticipation, no longer or louder version for present #5. **Applied (R17):** unwrap sound tier ≤ T3, never `reveal.*`, `jackpot`, `newSet` or a coin-like sound |
| Visual | **Applied (R6):** a **wrapped parcel** (matches "Dagens paket"), **not a shell**, with no rarity colours, sparkle or glow. At the right edge of the stage, visible only while ≥1 waits; 2–3 stacked when more wait (no number). **Applied (R8):** one gentle wobble only on a **cold start or return from background** (the N9 session start), never when coming back from a round, the Book, Buddies or the Aquarium |
| Separation from buddy shells | parcel silhouette, different sound, no rarity colours, never contains a buddy |
| Parent sheet | **Applied (R9):** the CS1 info sheet states: "The daily present is always the same: 25 pearls, 25 pearls, 1 star sand, 25 pearls, 25 pearls and a decoration, then it starts again. Up to 7 are saved." (SV written with legal.) |

Player sees: day 1 → first present. Day 2 → one more. After a week away → 7 presents in one unwrap (150 pearls + 1 sand + 1 decoration when starting from #1).

### 3.4 N4 Journey [LP: "Journey" / "Resan"]

**XP curve**
| Item | Value |
|---|---|
| XP source | **1 XP per merge, nothing else** (any mode, incl. Daily Jar). No lane grants XP |
| XP to next level | `min(600, 30 + 10·(L−1))`: L1→2 = 30, L2→3 = 40 … reaches the 600 cap at L58 |
| Endowed start | level 1 begins with **15/30** filled |
| Cumulative merges to reach level | L2 **15** · L3 **55** · L4 **105** · L5 **165** · L6 235 · L10 615 · L20 2 265 · L30 4 915 · L40 8 565 · L50 13 215 · L58 17 655 · L100 **42 855** |
| Authored levels | **100**. Beyond: every level (600 XP) = 50 pearls, every 5th = 5 sand; badge shows "100+N". Never ends, never resets |
| Rewards | granted automatically at the round end where the level is reached (no claim button, so no "unclaimed" nag) |

**Reward table**
| Level | Reward |
|---|---|
| 1 | – (start, bar half full) |
| 2 | **Missions unlock** (surprise-first, §3.7) + 30 pearls |
| 3 | **Aquarium + Pearl Pool unlock** + small decoration #1 |
| 4 | **Daily Present unlock** (1 waiting) + 2 sand |
| 5 | **Daily Jar unlock** + centerpiece "Old Anchor" + 3 sand |
| L ≥ 6, L mod 5 = 1 or 3 | pearls: **30** (L ≤ 30), **40** (31–60), **50** (61–100) |
| L mod 5 = 2 | next small decoration (#2–#20, list §3.8) |
| L mod 5 = 4 | **2 sand** |
| L mod 5 = 0 | **big reward** (below) **+ 3 sand** |

| Big level | Big reward [LP] | Type |
|---|---|---|
| 5 | Old Anchor / Gammalt ankare | centerpiece |
| 10 | Driftwood Jar / Drivvedsburk | jar skin |
| 15 | Kelp Forest / Tångskog | aquarium backdrop |
| 20 | Stone Arch / Stenvalv | centerpiece |
| 25 | Coral Jar / Korallburk | jar skin |
| 30 | Shell Stage / Snäckscen | Start stage style |
| 35 | Moonlit Reef / Månskensrev | backdrop |
| 40 | Sandcastle / Sandslott | centerpiece |
| 45 | Crystal Jar / Kristallburk | jar skin |
| 50 | Coral Stage / Korallscen | stage style |
| 55 | Deep Trench / Djuphavsgrav | backdrop |
| 60 | Bubble Vent / Bubbelkälla | centerpiece |
| 65 | Mother-of-Pearl Jar / Pärlemorburk | jar skin |
| 70 | Pearl Stage / Pärlscen | stage style |
| 75 | Sunbeam Shallows / Solstrålegrund | backdrop |
| 80 | Lighthouse Rock / Fyrklippan | centerpiece |
| 85 | Starlight Jar / Stjärnljusburk | jar skin |
| 90 | Starlight Stage / Stjärnljusscen | stage style |
| 95 | Starry Deep / Stjärndjupet | backdrop |
| 100 | Golden Glimmer Statue / Guldglimtstaty + Golden Jar / Guldburk | centerpiece + jar skin |

Currency from levels 1–100: 1 610 pearls + 100 sand, i.e. ≈3.8 % of the pearls and ≈6 % of the sand (est.) earned by 42 855 merges. Jar skins are frame and colour only: the danger line, wall contrast and physics never change (art-director check).

**UI:** Start: Journey bar replaces the set bar (level badge left, XP bar, the next reward's icon right). Tap → **Journey sheet**: track with past rewards (ticked), current, **next 3 rewards clearly shown**, the next big reward as a silhouette, the 3 missions, and the next-set progress row (moved here from Start; the set unlock ceremony is unchanged). Round end: XP fills the bar; level-up = badge pop + reward icon flies to its place (≤0.8 s, inside the 2.5 s budget, fast mode when crowded).

Player sees: day 1 → L3–L9 (profile) with 3–4 feature unlocks. Day 7 → L10–L26, first jar skin and backdrop. Day 30 → L23–L55, the collection may be complete but the track continues to L100.

### 3.5 N5 Trophies [LP: all names] (v1.2: redefined for reachability, DESIGN §24)

**Why redefined:** the balance sim (`sim/retention.md` §1, §7 risk 1) shows that a level 10 needs ≥212 drops in one round. At estimated merges, P(level ≥9 per round) is 0 % for casual and engaged children and 6 % for skilled adults, and level 10 is 0 % for everyone. Every trophy that needed level 9–10, a full row or page, or 120 merges in a round was out of reach. New rule: **visible trophies use level 7–8 targets, cumulative counts, per-set counts, rounds, catches and shinies. Level 9, level 10 and chain 7 are only hidden "feat" trophies for skilled players.**

**Rules:** a third tab in the Book: **Sets | Buddies | Trophies**. Six shelves by group. Hidden trophies show as a "?" silhouette in their group, with no condition text until earned. Earned: name + condition text (EN/SV) + date. A new trophy is shown in the round summary (§10), never mid-round (a toast chip only). The Book card gets a static badge until the tab is visited. No "play X days", "open N shells", "spend", "upgrade" or negative trophies. Never bronze/silver/gold/platinum cup tiers (legal).

**Rewards:**
- **Legacy milestones keep +3 sand**, paid once through `economy.milestones`: `level7`, `level8`, `shiny`, `level9` (hidden #39), `level10` (hidden #40). The `doubleKlunk` milestone stays in §16.1 as a rare feat without a trophy.
- The 8 hidden trophies each give an Aquarium item, and #22 gives one too.
- The rest are recognition only.

**Expected first completion** = median day, est., from game-designer's reachability model on the analyst's per-round rates (casual 5/7 days, ≈1.6 rounds per calendar day; engaged ≈5.1; skilled ≈6.8; P(top ≥7/≥8/≥9) = .64/.08/0, .86/.34/0, .98/.71/.06). balance-analyst re-simulates (DESIGN §24). ">60" = not expected in 60 days at estimated merges.

| # | id | EN [LP] | SV [LP] | Condition | Hidden | Reward | Day: casual / engaged / skilled |
|---|---|---|---|---|---|---|---|
| **Merging** |
| 1 | first_merge | First Merge | Första sammanslagningen | make a merge | – | – | 1 / 1 / 1 |
| 2 | chain3 | Chain of Three | Trekedja | chain ≥3 | – | – | 2 / 1 / 1 |
| 3 | chain5 | Chain of Five | Femkedja | chain ≥5 | – | – | 9 / 2 / 1 |
| 4 | combo8 | Combo Eight | Combo åtta | combo ≥8 | – | – | 7 / 2 / 1 |
| 5 | busy_jar | Busy Jar | Full rulle | 70 merges in one round | – | – | 30 / 1 / 1 |
| 6 | big_clear | Big Clear | Storstädning | one bomb clears ≥6 pieces | – | – | 3 / 1 / 1 |
| 7 | rainbow_boost | Rainbow Boost | Regnbågslyft | rainbow on a level ≥5 | – | – | 3 / 1 / 1 |
| 8 | steady_hands | Steady Hands | Stadiga händer | leave the danger zone twice in one round | – | – | 2 / 1 / 1 |
| **Heights** |
| 9 | level7 | Level 7 | Nivå 7 | first level 7 | – | 3 sand (legacy) | 1 / 1 / 1 |
| 10 | level8 | Level 8 | Nivå 8 | first level 8 | – | 3 sand (legacy) | 5 / 1 / 1 |
| 11 | sevens_club | Sevens Club | Sjuklubben | a level 7 in 10 different rounds (total) | – | – | 9 / 3 / 2 |
| 12 | five_eights | Five Eights | Fem åttor | a level 8 in 5 different rounds (total) | – | – | 37 / 3 / 1 |
| 13 | quick_climb | Quick Climb | Snabb klättring | a level 7 within the first 40 drops of a round | – | – | 4 / 1 / 1 |
| 14 | eights_all_over | Eights All Over | Åttor överallt | a level 8 in 3 different sets | – | – | 28 / 3 / 2 |
| **Book** |
| 15 | first_sparkle | First Sparkle | Första skimret | first shiny | – | 3 sand (legacy `shiny`) | 1 / 1 / 1 |
| 16 | sparkle_collector | Sparkle Collector | Skimmersamlare | 10 shiny slots filled (any sets) | – | – | 11 / 3 / 2 |
| 17 | row_to_eight | Row to Eight | Rad till åtta | normal levels 0–8 caught on one page | – | – | 5 / 1 / 1 |
| 18 | busy_page | Busy Page | Välfylld sida | 14 of 21 slots on one page | – | – | 15 / 3 / 1 |
| 19 | set_explorer | Set Explorer | Setutforskare | a round in each of the 5 sets (Daily Jar guest sets count) | – | – | 8 / 4 / 4 |
| 20 | first_star | First Star | Första stjärnan | any mastery star | – | – | 1 / 1 / 1 |
| 21 | set_master | Set Master | Setmästare | 3 mastery stars in one set | – | – | 23 / 4 / 2 |
| 22 | star_collector | Star Collector | Stjärnsamlare | 10 mastery stars | – | Gold Book Stand / Guldbokstöd | 35 / 6 / 4 |
| **Daily Jar** |
| 23 | jar_of_day | Jar of the Day | Burken är klar | finish a Daily Jar | – | – | 2 / 1 / 1 |
| 24 | better_try | Better Try | Bättre försök | beat your own best on a Daily Jar you already finished | – | – | ≈5 / 2 / 2 (not modelled) |
| 25 | every_jar_set | Every Jar Set | Alla burkset | finish a Daily Jar in each of the 5 sets (archive counts) | – | – | 11 / 6 / 6 |
| 26 | daily_deep | Daily Deep | Dagens djup | a level 8 in a Daily Jar | – | – | 13 / 3 / 2 |
| **Home and Journey** |
| 27 | moving_in | Moving In | Inflyttning | open the Aquarium | – | – | 1 / 1 / 1 |
| 28 | decorator | Decorator | Inredare | place 5 decorations | – | – | ≈7 / 3 / 2 |
| 29 | full_aquarium | Full Aquarium | Fullt akvarium | all 8 spots + centerpiece filled | – | – | ≈18 / 7 / 5 |
| 30 | journey10 | Journey 10 | Resan 10 | Journey level 10 | – | – | 9 / 2 / 2 |
| 31 | journey25 | Journey 25 | Resan 25 | Journey level 25 | – | – | 53 / 13 / 8 |
| 32 | ten_missions | Ten Missions | Tio uppdrag | complete 10 missions | – | – | 14 / 4 / 2 |
| **Secret (hidden)** |
| 33 | tickled | Tickled | Kittlad | tap your buddy on Start 10 times in a row | ✓ | Giggle Bubble / Fnissbubbla | player-driven |
| 34 | calm_steady | Calm and Steady | Lugn och fin | a level 7 with Calm mode on | ✓ | Sleepy Stone / Sömnig sten | first Calm round (≈ same as level 7) |
| 35 | big_boom | Big Boom | Stor smäll | a bomb clears a level ≥7 | ✓ | Bubble Volcano / Bubbelvulkan | 9 / 2 / 1 |
| 36 | double_sparkle | Double Sparkle | Dubbelskimmer | two shinies in one round | ✓ | Twin Starfish / Tvillingsjöstjärnor | 3 / 1 / 1 |
| 37 | say_hello | Say Hello | Säg hej | tap one Glimmer in the Aquarium 5 times | ✓ | Hello Shell / Hej-snäckan | player-driven (from L3) |
| 38 | waterfall | Waterfall | Vattenfall | chain ≥7 (**hard**) | ✓ | Tiny Waterfall / Litet vattenfall | 57 / 14 / 5 |
| 39 | deep_nine | Deep Nine | Djupa nian | first level 9 (**hard**) | ✓ | Sparkle Orb / Skimmerklot + 3 sand (legacy) | >60 / >60 / 2 |
| 40 | top_of_jar | Top of the Jar | Burkens topp | first level 10 (**feat**) | ✓ | Rainbow Arch / Regnbågsvalv + 3 sand (legacy) | >60 / >60 / >60 (needs ≥212 drops in a round) |

Removed in v1.2 (unreachable at estimated merges): Combo Ten, 120-merge Busy Jar, Level 9 and Level 10 as visible trophies, Double Klunk, Whole Chain, Five Tens, Full Row, Full Page, Whole Book, Top of the Rainbow, Sparkling Giant, Journey 50, and level-9 Daily Deep. A full page (21/21) is still a long-term feat and still pays its 10 sand (§16.1).

Player sees (est.): day 7 → casual ≈16, engaged ≈28, skilled ≈31 of 40. Day 30 → casual ≈29, engaged ≈35, skilled ≈37. The rest are the hard hidden ones and Journey 25.

### 3.6 N6 Set mastery [LP] (v1.2: redefined for reachability, DESIGN §24)
| Star | Condition (per set; Daily Jar guest-set rounds count) | Reward |
|---|---|---|
| ★1 | normal levels 0–7 caught in this set (needs a level 7 in this set) | set plant (floor): Glimmer Coral / Glimtkorall, Planet Moss / Planetmossa, Frost Fern / Frostbräken, Candy Kelp / Godistång, Ember Anemone / Glödanemon |
| ★2 | a level 8 in this set | set jar skin: Glimmer Jar / Glimtburk, Planet Jar, Frost Jar, Candy Jar, Ember Jar (SV: Planetburk, Frostburk, Godisburk, Glödburk) |
| ★3 | 6 shiny slots in this set (any levels) | gold page frame + set backdrop: Glimmer Deep / Glimtdjupet, Planet Orbit / Planetbanan, Frost Cave / Frostgrottan, Candy Lagoon / Godislagunen, Ember Vent / Glödkällan |

UI: three star slots in each Book page header; tap a star → one-line condition. Earned star: toast chip in the round + summary row R6. 15 stars total, 15 cosmetics, **0 currency**. Plants, jars and backdrops are **one recipe each × 5 set palettes** (art budget).

**Expected first completion** (median day, est., same model as §3.5; set 1 = base set, sets 2–5 in Daily Jar rotation order):
| Profile | ★1 per set | ★2 per set | ★3 per set | Stars at day 7 / 14 / 28 / 60 |
|---|---|---|---|---|
| Casual | 1 / 6 / 7 / 8 / 9 | 11 / 25–46 | 23 / 48–>60 | 4–5 / 7 / 9 / 11 |
| Engaged | 1 / 2 / 2 / 3 / 4 | 1 / 2–9 | 4 / 10–15 | 11 / 13 / 15 / 15 |
| Skilled | 1 / 1–4 | 1 / 1–7 | 2 / 3–9 | 13 / 15 / 15 / 15 |

Targets met (est.): a casual child earns ★1 in every set within ≈1 week of it being playable, helped by the Daily Jar rotation. An engaged child earns most stars within 2 weeks and all 15 within 4 weeks. The model is sensitive to its shiny-creation weights and to how children split rounds between sets (assumed: 40 % of normal rounds in a random unlocked set, which missions `set_round` encourage).

### 3.7 N7 Missions [LP: all texts]

**Rules (PWC-B, each condition checked)**
| Condition | How it is met |
|---|---|
| B1 no expiry | a mission stays until done; completed ones are replaced at the round end; open ones are never removed |
| B2 free swap | swap button on each card, free, unlimited, instant; the swapped mission goes to the back of the queue |
| B3 skill/variety only | pool below; no "play N rounds", "log in", "open", "spend", "upgrade", no Daily Jar missions |
| B4 deterministic, ≤1 round | **T1 10 pearls · T2 20 pearls · T3 30 pearls + 1 sand** (adopted, DESIGN §24; T10 now 19–23 %) |
| B5 no "all 3" bonus | none |
| B6 no timers/labels | none |

- **Slots 3.** Unlock at Journey L2. **Surprise-first:** at unlock the game checks round 1 against the pool in order `lvl6_round, chain3, combo5, lvl7_round, bomb4`; the first match is shown **already completed** ("You already did this!", 10 pearls), then 3 fresh missions fill the slots. If none matches, the first 3 are shown normally.
- **Next mission (WHAT, never IF/WHEN):** a seeded shuffle of the pool (`missions.seed`, set at unlock), skipping ineligible and currently active ones. Mix rule: at most 1 T3 and at least 1 T1 active.
- **Rewards hidden until done. Applied (R10):** each card shows the goal, a progress count and a **neutral goal mark** (an empty ring that fills on completion). No gift icon or word on missions (one gift word per concept: "Gift!" = free shell, "Present" = daily). On completion the ring fills, the celebration names the deed first ("Chain of 4!"), then the reward flies (≤0.8 s). Exact tier rewards are on the parent info sheet (R9, CS1 sheet).
- Progress counts in all modes, including the Daily Jar. Missions never read or influence the director (inv. 6).
- Where: Journey sheet (3 cards + swap). Round end: one row of mission icons **only if progress changed**. Round start: the 3 icons show for 1.2 s, then fade (PWC-F: shown at start only, no fail state or sound).

**Pool (26)**
| # | id | EN [LP] | SV [LP] | Scope | Target | Tier | Eligible when |
|---|---|---|---|---|---|---|---|
| 1 | lvl6_round | Make a level 6 in one round | Gör en nivå 6 i en runda | round | 1 | 1 | always |
| 2 | lvl7_round | Make a level 7 in one round | Gör en nivå 7 i en runda | round | 1 | 1 | always |
| 3 | lvl8_round | Make a level 8 in one round | Gör en nivå 8 i en runda | round | 1 | 2 | maxLevelEver ≥ 7 |
| 4 | lvl9_round | Make a level 9 in one round | Gör en nivå 9 i en runda | round | 1 | 3 | maxLevelEver ≥ 9 (v1.2: only for players who have made one) |
| 5 | lvl10 | Make a level 10 | Gör en nivå 10 | round | 1 | 3 | maxLevelEver ≥ 10 (v1.2) |
| 6 | two7 | Make two level 7s in one round | Gör två nivå 7 i en runda | round | 2 | 2 | maxLevelEver ≥ 7 |
| 7 | chain3 | Make a chain of 3 | Gör en kedja på 3 | round | 1 | 1 | always |
| 8 | chain4 | Make a chain of 4 | Gör en kedja på 4 | round | 1 | 2 | always |
| 9 | chains3x3 | Make 3 chains of 3 | Gör 3 kedjor på 3 | total | 3 | 1 | always |
| 10 | combo5 | Reach combo 5 | Nå combo 5 | round | 1 | 1 | always |
| 11 | combo8 | Reach combo 8 | Nå combo 8 | round | 1 | 2 | always |
| 12 | score800 | Score 800 in one round | Få 800 poäng i en runda | round | 800 | 1 | always (target est.) |
| 13 | score2500 | Score 2 500 in one round | Få 2 500 poäng i en runda | round | 2500 | 3 | highscore ≥ 1 500 (est.) |
| 14 | bomb4 | Clear 4 pieces with one bomb | Rensa 4 med en bomb | round | 1 | 1 | always |
| 15 | rainbow5 | Use a rainbow on level 5 or higher | Använd en regnbåge på nivå 5+ | round | 1 | 2 | always |
| 16 | fast6 | Make a level 6 in the first 20 drops | Gör en nivå 6 på de första 20 dropparna | round | 1 | 2 | always |
| 17 | escape2 | Leave the danger zone twice in one round | Ta dig ur farozonen två gånger i en runda | round | 2 | 1 | always |
| 18 | lvl6x5 | Make 5 level 6s | Gör 5 nivå 6 | total | 5 | 1 | always |
| 19 | shiny2 | Create 2 sparkly Glimmers | Skapa 2 skimrande Glimtar | total | 2 | 2 | always |
| 20 | newcatch | Catch a Glimmer you haven't caught yet | Fånga en Glimt du inte har | total | 1 | 1 | an unlocked set has an empty slot |
| 21 | page_slot | Fill one more slot on the {set} page | Fyll en plats till på {set}-sidan | total | 1 | 1 | param set unlocked and not full |
| 22 | set_round | Play a round with {set} | Spela en runda med {set} | round | 1 | 1 | ≥2 sets unlocked; param ≠ active set |
| 23 | set_lvl7 | Make a level 7 with {set} | Gör en nivå 7 med {set} | round | 1 | 2 | ≥2 sets unlocked |
| 24 | set_chain3 | Make a chain of 3 with {set} | Gör en kedja på 3 med {set} | round | 1 | 2 | ≥2 sets unlocked |
| 25 | buddy_round | Play a round with another buddy | Spela en runda med en annan kompis | round | 1 | 1 | ≥2 buddies owned |
| 26 | buddy_lvl7 | Make a level 7 with {buddy} | Gör en nivå 7 med {buddy} | round | 1 | 2 | param owned, not equipped |

Mix of pool: 14 T1, 9 T2, 3 T3. Expected completion 0.5–1.0 per round (est., sim target §5). Player sees: day 1 → 1–4 done; day 7 → 15–30; day 30 → 60–120 (est.).

### 3.8 N8 Aquarium [LP: "Aquarium" / "Akvarium"; all item names]

| Item | Value |
|---|---|
| Unlock | Journey L3: "Your Glimmers moved in!" All caught Glimmers so far become available as swimmers |
| Screen | full scene 360×640, reached from the Start card; back/Home returns to Start |
| Swimmers | up to **12** caught Glimmers (any set, normal or shiny). Default "auto" = the 12 most recent catches; the player can pick them in a drawer. Paths: seeded smooth loops, 12–30 px/s, bob ≤0.5 Hz; shiny ring as in game (0.83 Hz, already registered) |
| Buddy | the equipped buddy sits on a rock; tap = its showcase (as on Start) |
| Spots | **8 decoration spots** (5 floor, 1 left wall, 1 right wall, 1 surface) + **1 centerpiece** + **1 backdrop**. Tap a spot → drawer with owned items for that spot type → tap to place; tap a placed item → swap or remove. Always reversible |
| Toys | tap a Glimmer = a flip (500 ms) + its set's merge tone; max 2 per second |
| Pearl Pool | lower-right rock pool (§3.2) |
| Never | needs (food, cleaning), decay, night/sad states, items from random draws, buying items for currency (§16.2 "honest end": no new sinks) |
| Start card | "Aquarium"/"Akvarium", icon = small tank. **No sub-line fraction on Start** (review recommendation, applied: the "9 / 62" count moves into the Aquarium screen). Static badge **only** for a new, unseen item. **No pool amount on Start** |

**Item sources (62 aquarium items + 11 jar skins + 4 stage styles)**
| Source | Aquarium items | Other |
|---|---|---|
| Journey small (L3, L7, L12 … L97) | 20 floor/wall/surface: Pebble Pile, Sea Grass, Tiny Starfish, Bubble Stone, Scallop Shell, Sand Dollar, Coral Sprig, Sea Fan, Spiral Shell, Anemone, Kelp Strand, Brain Coral, Mussel Cluster, Friendly Urchin, Driftwood Twig, Glass Float, Tube Worms, Sea Sponge, Oyster, Tiny Lighthouse. SV (legal's proposal): Stenhög, Sjögräs, Liten sjöstjärna, Bubbelsten, Kammussla, Sanddollar, Korallkvist, Havssolfjäder, Spiralsnäcka, Havsanemon, Tångremsa, Hjärnkorall, Musselklunga, Snäll sjöborre, Drivvedskvist, Glasflöte, Rörmaskar, Havssvamp, Ostron, Litet fyrtorn | – |
| Journey big | 6 centerpieces + 5 backdrops (§3.4) | 6 jar skins, 4 stage styles |
| Set mastery | 5 plants + 5 backdrops | 5 jar skins |
| Daily Present (every 5th) | 12: Paper Boat, Glass Bottle, Toy Submarine, Diving Helmet, Sand Bucket, Beach Ball, Sea Glass Pile, Clay Pot, Tiny Bridge, Snail House, Rope Swing, Pinwheel Shell. SV: Pappersbåt, Glasflaska, Leksaksubåt, Dykarhjälm, Sandhink, Badboll, Sjöglashög, Lerkruka, Liten bro, Snigelhus, Repgunga, Snurrsnäcka | – |
| Trophies | 8 hidden + Gold Book Stand (#22 Star Collector) = 9 | – |
| **Total** | **62** (mastery plants and backdrops are 1 recipe × 5 palettes → ≈54 unique recipes, est.) | 11 jar skins, 4 stages |

Player sees (est., engaged): day 1 → 12 swimmers, 1–2 items. Day 7 → 6–9 items, first backdrop. Day 30 → 16–22 items, all 8 spots can be full.

### 3.9 N9 Good place to stop (= CS4, baseline P1-4) [LP copy]
| Item | Value |
|---|---|
| Session | starts on app foreground after **≥10 min** in background or a cold start; `sessionMs` counts foreground time |
| Trigger | the **first** loss screen where `sessionMs ≥ 20 min` **or** `roundsThisSession ≥ 6`, **or** the first Daily Jar finish of the date. **Once per session** |
| Shows | after all earned round-end items (rewards come first, never after the line): the buddy yawns/waves (1.2 s) and one line: **"Nice run! Good place for a break."** / **"Bra runda! Ett bra ställe att ta paus."** With no buddy: a Glimmer yawns. Home and Replay become equal size for this screen |
| Never | blocks, delays, timers, rewards for stopping or continuing, guilt copy, sad faces, a reward popping up on exit, any change on Start after Home is tapped (no new badges or wobbles triggered by leaving) |
| Also (CS4) | Home button on every loss screen; replay pulse 3 cycles then still; `sessionMs` / `roundsThisSession` in the debug panel. Calm mode shows the stop moment too |
| Music | **Applied (R15):** on the stop screen the pad resolves over 2 bars and falls to the menu bed level. No seamless hand-off into the next round, no cue suggesting continuing |
| Thresholds | **Applied (R11):** `WELLBEING` values (20 min, 6 rounds, 10 min gap) change only with a child-safety review. They are **not** balance knobs and are not in the §6 knob list. The copy is fixed exactly as above (no variants) |

---

## 4. Start screen entry points (for ui-designer, UI.md §17; layout is theirs)

| Lane | Entry point | Badge rule |
|---|---|---|
| Daily Jar | secondary button under PLAY (today's set icon + "Daily") → Daily sheet | static dot while today's jar is **unseen**; clears when the sheet is opened (R1) |
| Daily Present | parcel on the right edge of the hero stage (R6) | the object itself; no dot, no number; wobble only at session start (R8) |
| Aquarium + Pearl Pool | 4th card "Aquarium" (Book, Buddies, Shells, Aquarium) | static, only for an unseen new item |
| Journey + Missions | bar at the bottom (replaces the set bar) → Journey sheet | none (the bar is the information) |
| Trophies | Book → third tab | Book card badge for an unseen trophy (existing rule) |
| Set mastery | Book page header stars | existing Book fresh rule |
| Stop moment | loss screen | – |

Recommended fit at 360×640 (est., ui-designer validates): logo 60→44 px, PLAY 268×80 at y 372, Daily 200×48 at y 440, four cards 78×100 at y 478, Journey bar at y 596. PLAY stays the only large button.

---

## 5. Player journey (always a next thing)

Profiles (est.): **casual child** 10 min/day, 45 merges/round, 4.5 min/round → ≈100 merges/day, 1 session. **Engaged child** 25 min/day, 60 merges/round, 5 min → 300/day, 2 sessions. **Skilled adult** 40 min/day, 80 merges/round, 6 min → ≈535/day, 2 sessions.

| When | New or unlocked | The visible "next thing" |
|---|---|---|
| **First 60 s** | hand on PLAY → first drop by ~3 s → first merge ≤10 s (director opening Flow) → HUD chain lights levels 1–4, "?" silhouettes above → first catches fill the Book silently | the "?" silhouettes, a bigger Glimmer |
| **First round end** (~3–5 min) | pearls tally, catches fly to the Book, **Journey bar appears: L2 → Missions** with a surprise mission already done (+10 pearls), 3 missions shown; trophies First Merge / Chain of Three | 3 mission goals, XP bar to L3 |
| **First session** (engaged, 2–3 rounds) | first shell as **choose 1 of 3 rares** (CS6) at **60** merges (adopted, DESIGN §24); **L3 Aquarium** ("Your Glimmers moved in!") + Pearl Pool starts; **L4 Daily Present** (1 waiting); trophies Level 7, Chain of Three | L5 = Daily Jar on the track (design note: the pool fills between sessions, but no in-game text says so) |
| **Day 1 end** | casual L3 (Aquarium, pool); engaged L6: **first Daily Jar** + stamp + Old Anchor; skilled L9; engaged and skilled get the first set unlock (200 merges) | casual: L4–5 next; everyone: a new jar on the next date (design note only; never UI copy, R2) |
| **Day 2** | new Daily Jar (new set, often a guest preview of a locked set); present #2; pool ≈ full (40); casual reaches **L4–L5** (present + Daily Jar); engaged gets the 2nd free shell (400 merges) and ~L9 | next date's jar (design note only, R2), L10 jar skin |
| **Day 7** | casual L10 (first jar skin), engaged L19, skilled L26; a few stamps (never counted in UI, R3); 2–3 sets; engaged ≈ 10–12 buddies; first mastery stars (★1 in 1–3 sets, v1.2); 6–9 Aquarium items; ~15 trophies; present decoration #1 (present #5) | next big Journey reward, next set, hidden "?" trophies |
| **Day 30** | casual L23, engaged L41, skilled L55; engaged ≈ 36–42 buddies, 4–5 sets, 9–15 of 15 mastery stars (casual–engaged), first gold frames (★3); 25–30 trophies; 16–22 Aquarium items, backdrops to choose; calendar with stamps (no run styling, R3) | whole book, set mastery, L50 stage, upgrades to III, Journey to L100 |
| **Beyond** | the collection ends at 10–14 h (engaged), Journey L100 ≈ 143 days (engaged) / 80 days (skilled); after that 100+N levels, upgrades, whole book, remaining trophies | always one Journey reward within ≤10 rounds |

Rows mentioning time ("next date", "between sessions") are design estimates. **None of them may become UI text or visuals** (review §3; R2, R3). The only unlock line for the Aquarium is "Your Glimmers moved in!".

---

## 6. Targets for balance-analyst (all est.; simulate before build)

Extend `economy-sim.py` (or `docs/sim/`) with: the three profiles, 1 and 2 sessions/day, days played 7/7 and 4/7, the Journey curve, missions (completion model per tier), Daily Jar (+2 sand/date), pool (1.25/h, cap 30, collected at each session start) and present (cycle of 5).

| # | Metric | Casual child | Engaged child | Skilled adult | Tolerance / note |
|---|---|---|---|---|---|
| T1 | Session length (health signal, not pass/fail; DESIGN §24) | 10 min | 12–13 min (×2) | 20 min (×2) | **Applied (R11):** measure the share of child sessions that reach the stop moment, **counting the Daily Jar trigger separately** from the 20 min / 6 rounds trigger (sim: the Daily trigger alone gives 91 % casual / 50 % engaged, which is expected because the jar result is a natural end). If the time/rounds share is above 25 %, look at session length, **never at the trigger** |
| T2 | Rounds per session | 2 | 2–3 | 3–4 | – |
| T3 | Time to first shell | ≤10 min | ≤8 min | ≤7 min | sim with `free.at[0]` = **60** (adopted): 8.5 / 7.3 / 6.5 min, PASS |
| T4 | Shells per hour, hours 1–5 | 2.5–3.5 | 3.5–4.5 | 4.5–5.5 | baseline §16 ≈3–4/h at 60 m/r |
| T5 | To 24 buddies | **casual in days: day 40–50** (5/7 days played; sim ≈ day 43) | 5–7 h (sim 5.3) | 4–5.5 h (sim 5.2) | casual restated in days (DESIGN §24): daily lanes pay per day, not per hour |
| T6 | To 48 buddies | **casual in days: day 75–95** (5/7; sim ≈ day 83; 7/7 ≈ day 63) | 10–14 h (sim 10.3 h, day 25) | 8–11 h (sim 9.9 h, day 15) | casual in days, as T5 |
| T7 | Journey level day 1 / 7 / 30 | 3 / 10 / 23 at 7/7 (sim 3 / 9 / 19 at 5/7) | 6 / 19 / 41 | 9 / 26 / 55 | ±15 % |
| T8 | Daily-lane share of rewards (pool + present + Daily Jar bonus) / all rewards, pe, days 1–30 | sim 30.8 % (7/7 30.2, 4/7 32.1) | sim 13.0 % | sim 7.3 % | **≤35 %** for every profile. FAILS at −30 % merges (37–38 %) |
| T9 | Return-only value (pool + present) per day / one round of play, pe | sim 0.58 (7/7 0.69) | sim 0.49 | sim 0.35 | **<1.0** (inv. 3), target ≤0.8 |
| T10 | Mission rewards / pearls from merges | sim 19 % | sim 22 % | sim 23 % | ≤25 %; completion 0.5–1.0 per round (skilled est. 1.16) |
| T11 | Journey currency / total currency | ≤10 % | ≤10 % | ≤10 % | est. ≈4–6 % |
| T12 | Max value after 7 days away (7 presents + full pool) | ≤ 3 casual rounds (≈233 pe at 78 pe/round) | – | – | sim 205 pe, also after the 12 decorations |

**Adopted after simulation (DESIGN §24):** free shells at 60 and 400, then every 750; missions 10/20/30 (+1 sand); pool cap 30; present #5 after the 12 decorations = 25 pearls. **Remaining knobs, in this order, if a playtest target misses:** present pearls 25 → 20 → pool cap 30 → 20 → mission rewards ×0.8. Sizing rule once casual merges are measured: `pool cap + 25 ≤ 0.8 × measured casual round value (pe)`. Shop prices do not change (test testers' mental price anchors; §16.2). `WELLBEING` thresholds are **not** knobs (R11).

**Batch B gate. Applied (R12):** T8 ≤ 35 % and T9 ≤ 0.8 for the **casual profile at 4/7 and 7/7 days played** must be confirmed by simulation, not estimates, before Batch B is built. **Result:** PASS with the adopted numbers at estimated merges; FAIL at −30 % merges. Producer decision (DESIGN §24): Batch B proceeds, merges per round are logged, and all lane numbers are recalibrated after the first playtest.

Simulated round value (pe): casual 78, engaged 111, skilled 159. Daily lanes at most 105 pe per day (pool 30, present 25, Daily Jar 2 sand = 50). Full results: `sim/retention.md`.

---

## 7. Integration with CS1–CS7 and the economy

### 7.1 Safety fixes (BACKLOG Fas 12)
| CS | Interaction with the new lanes |
|---|---|
| CS1 honest odds + odds sheet | no new random rewards anywhere (inv. 7 trivially holds). The odds sheet (parent sheet) also lists: first shell = choose 1 of 3 rares (CS6), mission tier rewards (R10), the present schedule (R9), "the Daily Jar is the same for everyone" and the P2-6 director sentence |
| CS2 listing + privacy | the baseline P1-2 fixes and privacy policy are due **before any public submission, Batch A included**. Batch B additions: see §7.4 (R18) |
| CS3 near-miss same level | no trophy, mission or Journey condition uses near-miss events (no rewards for "almost") |
| CS4 Home + stop moment | **is N9**; the Daily Jar result reuses it |
| CS5 Shells / Gift! | the free buddy shell keeps "Gift!"; the daily lane is called **Present** and looks different, so there are not two "gifts" |
| CS6 choose 1 of 3 | first shell at **60** merges (adopted, DESIGN §24; free shells at 60 and 400, then every 750); it is not a Journey reward (no double grant) |
| CS7 director blind to save | Daily mode is a pure function of `dateKey`: unit test that the 600-entry queue for a date is identical for any save contents; the paused-ability list is data. Pool, present, missions and Journey never read or write RNG state (inv. 6) |

### 7.2 Economy: sources, and why nothing double-dips
| Source | Pearls | Sand | Items | Counts toward |
|---|---|---|---|---|
| Merge (all modes) | 1 | (shiny/chain/L10 as §16.1) | – | XP, missions, free-shell counter, set unlock |
| Legacy milestones ×6 | – | 3 each, **once** via `economy.milestones` | – | shown as trophies 9, 10, 15 and hidden 39, 40; `doubleKlunk` stays a §16.1 feat without a trophy (v1.2) |
| Full page | – | 10 once (§16.1), a rare long-term feat since v1.2 | – (mastery ★3 is now 6 shiny slots, cosmetics only) | – |
| Journey | 1 610 over L1–100 | 100 | 41 cosmetics | – |
| Missions | 10 / 20 / 30 | T3: 1 | – | trophy 32 only |
| Daily Jar | – | 2 per date, first finish | – | – |
| Pearl Pool | ≤30 per 24 h | – | – | – |
| Daily Present | 25 (4 of 5) | 1 (1 of 5) | 12 decorations | – |
| Trophies | – | only the legacy 6 | 9 items | – |

Rules:
1. **XP comes only from merges.** No lane grants XP, so there are no reward loops (reward → XP → reward).
2. **No lane grants shells or any random item** (baseline §3 watch item).
3. **No lane grants currency based on currency** (no interest, no multipliers, no "double it").
4. **No new sinks.** Aquarium items, jar skins and stages are never sold. Upgrades stay the only pearl/sand sink after the book is complete (§16.2 honest end).
5. **Absence value is capped**: pool = 1 day, presents = 7 days, archive rewards require playing a round per date.
6. Every grant goes through one `grant(source, delta)` that also increments `debug.grants[source]`, so the playtest can measure T8–T11.
7. After all 48 buddies: free shell → 10 sand (unchanged); Journey 100+N continues.


### 7.3 Tests and audio rules for the lanes
**Applied (R13), unit tests (game-programmer), required for every Batch B lane:**
| Test | Assertion |
|---|---|
| Gap invariance (inv. 4) | a save that plays dates 1, 3, 5 and a save that plays dates 1–5 get the same reward per date and per present; nothing depends on consecutive dates |
| No loss (inv. 1) | after 30 days away: pool = 30, present bank = 7, nothing earned is lower than before |
| Clock backwards | pool, present and daily state gain nothing and lose nothing |
| Blind randomness (inv. 6, CS7) | the Daily queue and the director output are identical for any save contents; the same holds for `systems/music.ts` (R14) |
| Wording | a scan of `app/src/data` strings against the review §5 forbidden list (EN/SV), owned by ui-designer |

**Applied (R14):** music reads only scene, director mode, danger and calm. It never reads economy, pending presents, pool level, pending shells, daily status, session length or records; menu music is identical whether or not something is waiting. A2 lifecycle (suspend on `visibilitychange` and Capacitor `pause`) ships **before** A7. No MediaSession, no foreground service, no new Android permission (CI gate: VIBRATE only). Calm mode plays the calm variant; Music off is always one tap in Settings (replaces the ambiguous DESIGN §21 wording).
**Applied (R15):** see §3.9 (music settles at the stop moment).
**Applied (R16):** the A4 audio test locks reveal equality: every `reveal.*` tier within +4 ±0.5 LU, max spread ≤1 LU between tiers, ≤5 % energy above 4 kHz; `shellOpen` and everything before the reveal identical for every shell; the mythic tail never lengthens the fixed 1.2 s ceremony or delays tap-to-skip; music duck −8 dB for every tier; calm variants keep the same equality.
**Applied (R17):** return-lane sounds are never the loudest reward. Present unwrap, Pearl Pool collect and Daily stamp ≤ **T3**; Journey level-up, trophy and mission-complete ≤ **T4**; none reuses `reveal.*`, `jackpot`, `newSet` or a coin-like sound; all are registered in `VOICE_RULES` and the A4 loudness test. This also covers the §10 toast tone and sand-token tone.

### 7.4 Store listing and rating answers for Batch B (applied R18)
Ship **in the same release as Batch B** (inv. 10); owners producer, legal-reviewer, release-engineer; file answers and certificate in `docs/store/`.
| Item | Content (EN / SV, legal-reviewed) |
|---|---|
| Age line | "7+. PEGI 7 expected: the game rewards coming back (a daily jar, a daily present and a pearl pool), and nothing is ever lost if you don't." / "7+. Väntat PEGI 7: spelet belönar att man kommer tillbaka (dagens burk, dagens paket och pärlpölen), och inget går förlorat om man inte gör det." Replaces "PEGI 3 / IARC 3+ expected" everywhere |
| Remove | "No waiting timers" / "Ingen väntetid" (the pool fills over time). Use: "No countdowns and no energy: you can always play." / "Inga nedräkningar och ingen energi: du kan alltid spela." |
| Keep | "No streaks: missing a day never costs anything. Nothing expires." / "Inga sviter: att hoppa över en dag kostar ingenting. Inget går ut." and the baseline shop sentence (earned currency only, no real money, no ads) |
| Lanes, factual | "A new Daily Jar each day, the same for every player; past days stay playable." · "A small present each day; up to 7 are saved for you." · "The aquarium's pearl pool slowly gathers a few pearls over about a day, then simply stops." No "every day you come back…" framing. Journey only in lowercase description ("a long reward path that never resets"), legal §2.4 |
| Wellbeing (after Batch A) | "After a longer session the game suggests a good place for a break." / "Efter en längre stund föreslår spelet ett bra ställe att ta paus." |
| Privacy | "No accounts, no data collection, no network. Progress and dates are stored only on this device." Privacy policy URL in both stores |
| Keywords, screenshots, What's new | no "daily reward", "free gift", "login bonus" or streak terms; no screenshot whose hero is the present pile, the Daily dot or a full calendar; "What's new" descriptive ("New: the Aquarium, a Daily Jar and a daily present.") |
| IARC | play-by-appointment **Yes**; penalties for not returning **No**; real-money purchases **No**; limited offers **No**; paid random items **No**; random items with earned currency **Yes** (buddy shells: exhaustible, no duplicates, odds shown); simulated gambling, interaction, chat, sharing, location, UGC, ads **No**. Expected PEGI 7. **PEGI 12/16 → stop the release and escalate, never tune answers**; PEGI 16 triggers `SHOP.mode = 'pick3'` |
| App Store | Loot Boxes **No** (nothing purchasable; legal confirms before submission; a Yes would mean switching to `pick3` rather than an 18+ Brazil rating); Simulated Gambling None; Advertising, Chat, UGC, Web, Age Assurance, In-App Controls No/None; Contests: legal to confirm (personal best only, no leaderboards) |
| Play Families / Data safety | unchanged: "No data collected, no data shared"; CI permission gate still VIBRATE only after Batch B and the audio batch |

---

## 8. Data and save shapes

### 8.1 New data files (`app/src/data/`, pure data, no Phaser)
```ts
// daily.ts
export const DAILY = { unlockLevel: 5, epoch: '2026-01-01', seedPrefix: 'klunk-daily-v1:',
  queueLength: 600, openingDrops: 10, openingLevels: [0, 1, 2], weights: [26, 24, 22, 16, 12],
  echoP: 0.35, echoBack: 2, kickEvery: { min: 25, max: 60 }, specials: ['bomb', 'rainbow'],
  pacing: 'off', pausedAbilities: ['magnetPull', 'startRainbow', 'breath', 'noBounceStart', 'queenRound.specials'],
  reward: { sand: 2 }, archive: 'sinceUnlock' } as const;
// pool.ts
export const POOL = { // Pearl Pool (legal LG9)
  unlockLevel: 3, cap: 30, fillMs: 24 * 3600e3, glimmerPer: 5, maxGlimmers: 8, flyMs: 800 } as const;
// present.ts
export const PRESENT = { unlockLevel: 4, bankMax: 7, startBanked: 1,
  cycle: [{ pearls: 25 }, { pearls: 25 }, { sand: 1 }, { pearls: 25 }, { pearls: 25, item: 'next' }],
  afterItems: { pearls: 25 }, items: [/* 12 ids, §3.8 */] } as const;
// journey.ts
export const JOURNEY = { xpPerMerge: 1, xpStart: 15, base: 30, step: 10, cap: 600, authored: 100,
  unlocks: { missions: 2, aquarium: 3, present: 4, daily: 5 },
  rewards: [/* JourneyReward[101], index = level */], beyond: { each: { pearls: 50 }, every5: { sand: 5 } } } as const;
type JourneyReward = { pearls?: number; sand?: number; item?: string; unlock?: 'missions' | 'aquarium' | 'present' | 'daily' };
// missions.ts
export const MISSIONS = { unlockLevel: 2, slots: 3, reward: { 1: { pearls: 10 }, 2: { pearls: 20 }, 3: { pearls: 30, sand: 1 } },
  maxT3Active: 1, minT1Active: 1, introOrder: ['lvl6_round', 'chain3', 'combo5', 'lvl7_round', 'bomb4'], showAtStartMs: 1200,
  pool: [/* MissionDef[26], §3.7 */] } as const;
type MissionDef = { id: string; tier: 1 | 2 | 3; scope: 'round' | 'total'; kind: MissionKind; target: number;
  param?: 'set' | 'buddy'; eligible?: EligibilityRule; icon: string; text: { en: string; sv: string } };
// trophies.ts
type TrophyDef = { id: string; group: 'merging' | 'heights' | 'book' | 'daily' | 'home' | 'secret'; hidden: boolean;
  name: { en: string; sv: string }; desc: { en: string; sv: string }; cond: TrophyCond;
  reward?: { sand?: number; item?: string }; legacyMilestone?: string; legalPending: true };
// mastery.ts
export const MASTERY = { // v1.2 reachability (DESIGN §24)
  stars: [{ id: 'normalTo', level: 7 }, { id: 'levelInSet', level: 8 }, { id: 'shinySlots', count: 6 }],
  rewards: { /* setId: { normalTo: itemId, levelInSet: jarSkinId, shinySlots: [frameId, backdropId] } */ } } as const;
// aquarium.ts
export const AQUARIUM = { swimmersMax: 12, spots: { floor: 5, wallL: 1, wallR: 1, surface: 1, center: 1 },
  swimSpeed: [12, 30], bobHz: 0.5, tapFlipMs: 500, tapMaxPerSec: 2, items: [/* AquariumItem[62] */] } as const;
type AquariumItem = { id: string; name: { en: string; sv: string }; spot: 'floor' | 'wall' | 'surface' | 'center' | 'backdrop';
  source: 'journey' | 'mastery' | 'present' | 'trophy'; recipe: string; palette?: string; legalPending: true };
// wellbeing.ts
export const WELLBEING = { stopAfterMs: 20 * 60e3, stopAfterRounds: 6, sessionGapMs: 10 * 60e3, oncePerSession: true,
  replayPulseCycles: 3 } as const;
// economy.ts (change, adopted DESIGN §24): free.at [120, 400] -> [60, 400], every 750 unchanged
```
New loops to register in `JUICE.pulseHalfCycleMs` (inv. 8): swimmer bob, pool nap bob, present wobble (session start only, R8), Daily badge (static, none), trophy shine (once). `daily` save gains `seenOn: string | null` (R1: date the Daily sheet was last opened).

### 8.2 Save file: `schema 3`, **migrated from 2 (no wipe)**
```ts
journey:   { xp: number; level: number; rewardedTo: number }
missions:  { active: { id: string; param: string | null; progress: number }[]; seed: number; cursor: number; done: number; introShown: boolean }
trophies:  { earned: Record<string, number /* epoch ms */>; fresh: string[] }
mastery:   Record<string /* setId */, [boolean, boolean, boolean]>
daily:     { unlockedOn: string | null; seenOn: string | null; days: Record<string /* YYYY-MM-DD */, { best: number; first: number }> }
pool:      { stored: number; since: number /* epoch ms */ }
present:   { lastDay: string | null; banked: number; opened: number }
aquarium:  { items: string[]; placed: Record<string, string | null>; backdrop: string | null; swimmers: string[] | null /* 'set:level:n|s' */; fresh: string[] }
cosmetics: { jarSkins: string[]; jarSkin: string; stages: string[]; stage: string }
stats +=   { level8BySet: Record<string, number>; level7Rounds: number; level8Rounds: number; level10BySet: Record<string, number>; tens: number; setsPlayed: string[]; dailySetsFinished: string[]; maxChain: number; maxCombo: number; buddyTaps: number }
debug +=   { sessionMs: number; roundsThisSession: number; grants: Record<string, { pearls: number; sand: number }> }
```
Migration 2 → 3: Journey starts at xp 0 (no retroactive currency, as §16.2). Trophies and mastery stars that follow from existing stats are marked earned **without paying** (legacy sand already paid via `economy.milestones`; mastery cosmetics may be granted since they carry no currency). Everything else defaults.

---

## 9. Legal note (review `legal/ip-review-2026-09-26-retention.md` applied)
All [LP] names were reviewed: no HIGH, everything LOW except the items fixed below. Registry searches were not reachable, so the conclusions are provisional; §7 of the legal review lists what a lawyer confirms before the Batch B store release.

| Change | Status |
|---|---|
| "Tide Pool / Tidvattenpölen" → **Pearl Pool / Pärlpölen** everywhere (LG9) | applied |
| Journey: **never "Journey Pass"**, "Season Journey" or any premium/seasonal framing; never "Journey" as a feature brand in store title, subtitle, keywords, icon or captions (lowercase description only); no visual nods to *Journey* (2012) (robed figure, scarf, dunes, glyphs); never call the track a "Trophy Road". Fallback name if ever needed: Pearl Path / Pärlstigen | applied (guards) |
| Canonical buddy and set names (LG3), used by the `{set}` / `{buddy}` mission placeholders: **Captain Anchor / Kapten Ankare** (pirate buddy), **The Snowglows / Isbitarna** (ice set, was The Frosties), **Vera the Seer / Spådamen Vera** (id `vera`, was Siri; never a voice assistant: no "Hey/Ask Vera", no speech bubbles), **Figgy the Frog** (SV Grodan Gurra). Missions ship only after LG3 lands | applied |
| Trophy 5 SV "Full fart" → **Full rulle**; trophy 23 SV "Dagens burk" → **Burken är klar** (was identical to the lane name) | applied |
| Trophies: never bronze/silver/gold/platinum cup tiers, never a "Platinum" trophy | applied (guard) |
| Stop copy: never "Have a break" in-game or in marketing | applied (guard) |
| Art guards for art-director: Scallop Shell / Hello Shell / Shell Stage never a flat front-facing yellow-red scallop; Sea Sponge never a yellow rectangle with a face; Toy Submarine never all-yellow; starfish never pink; Beach Ball never Poké Ball-split; Frost Cave not the *Frozen* look; Golden Glimmer Statue a Glimmer on a rock, not an Oscar-like figure; Gold Book Stand without Little Golden Books foil trade dress; Set trophies never as three shape-cards; Vattenfall trophy never in the energy company's logo look | forwarded |
| SV names for the 32 decorations: legal's proposal adopted in §3.8; the final list goes back to legal for a quick check | applied |

New player-facing strings follow the child-safety review §5 wording rules (forbidden EN/SV list, exclamation only for earned things, no day counts, one gift word per concept). "Klunk" in "Double Klunk" follows the app-name clearance (LG8).

---

## 10. In-round pickup feedback and round summary (producer requirement from Anders, 2026-09-26)

Applies to all lanes. **This section overrides** the round-end details in §3 (Journey level-up, mission completion, trophy and mastery displays all happen here). No new rewards are added: this is presentation only. **All grants are applied and saved at the moment of loss (t = 0)**, before any animation. The summary only shows what is already in the save, so skipping never loses anything.

### 10.1 In-round pickup feedback

**Principle:** tokens show a player action paying off ("I did that → I got this"). Anything that is not directly caused by the last move waits for the summary, so the jar stays readable.

**Events**
| Event | In-round feedback | Cadence limit | Deferred to summary |
|---|---|---|---|
| Pearls (1 per merge) | **one pearl token per burst**. A burst = merges until the combo window (1.2 s) closes, and at most 1.0 s long during long cascades. The token starts at the burst's last merge point and flies to the pouch, and the number steps up by n on arrival | **≤2 tokens/s**, ≤3 in flight. Any extra is folded into the next token | the tally with count-up |
| Star sand (shiny +1, chain ≥3 +1 up to 3 per round, level 10 +2) | one sand token per event (12 px star) from the event point to the pouch sand slot | ≤1 per 0.5 s, queued | tally |
| Legacy milestone sand (+3, first level 7–10, first shiny, first double Klunk) | **no token**: trophy toast only (see below) | – | the 3 sand appear in the Trophies row and fly to the currency row |
| Glimmer caught (new slot) | **existing** HUD chain ignite ("?" → light, double ring, §13.1/U5). No extra effect | existing | flyers into the Book (row R2) |
| New shiny | **existing** six gold stars + shiny tone, plus its sand token | existing | row R2 |
| Journey XP | **nothing** (1 XP = 1 merge, the same count as the pearls, so a second token would only add noise) | – | XP bar fill in row R4 |
| Journey level-up | toast chip: level badge + "Level 7" / "Nivå 7" | toast rules | the level's reward (row R4) |
| Mission progress | nothing | – | progress chips in row R5 (only if changed) |
| Mission completed | toast chip: deed text ("Chain of 4!"), filled goal ring (applied R10) | toast rules | its reward flies (row R5) |
| Trophy unlocked | toast chip: trophy icon + name. For a hidden trophy: gold border, name shown | toast rules | R6 |
| Mastery star | toast chip: star + set icon | toast rules | R6 + cosmetic |
| Free shell earned, new set unlocked | **nothing in-round** (a shell mid-round pulls attention to spending) | – | R3 / R2 ceremony |
| Record passed | existing `newRecord` kick | existing | R0 |

**HUD placement (logical 360×640; ui-designer finalises in UI.md)**
| Element | Position | Details |
|---|---|---|
| **Round pouch** | top band between the score and the preview: pearl icon 14 px at x 178, "+N" 14 px/600 from x 190. Sand icon at x 232 and "+N" from x 244, all at centre y 20 | shows **this round's** earnings from merges and sand events only. Appears with a 140 ms pop on the first merge (first round ever: 300 ms fade-in, like the chain). The sand slot appears on the first sand. Same dim rule as the chain: alpha 0.35 while the hanging object overlaps it. Never shows the total balance |
| **Toast chip** | bottom band **below the jar floor**, centre (180, 620), h 32, max w 240 | never over the jar (jar interior y 110–600). `card` fill alpha 0.92, 2 px `#4A6194` border (gold for trophies). Icon 20 px + text 14 px/600, ≤22 characters, EN/SV |

**Token and toast behaviour**
| Item | Value |
|---|---|
| Pearl token | 10 → 8 px, quadratic bezier 420 ms Sine.easeInOut, **no trail, no sound** (the merge sound already speaks). On arrival: pouch icon scale punch 1.15 (120 ms) |
| Sand token | 12 px, 520 ms. On arrival: punch 1.25 + a soft `tallySand` tone at gain ×0.6 |
| Toast | slide up 12 px + fade in 180 ms, hold 1 600 ms, fade out 240 ms. A soft `toast` tone (≤ merge gain, tier ≤ T4, R17), no haptics. **At most 1 visible, at least 3 s between toasts, queue of 2**; any overflow goes to the summary only. Priority: hidden trophy > mission > level-up > mastery star > trophy |
| Quiet times | no new toast during danger/slow-mo or hit-stop, or within 1 s after them. Tokens follow the game's time scale |
| Calm mode | pearl tokens off (the pouch number just updates with a 120 ms fade), sand tokens without punch, toasts fade only (no slide) |
| Flash guard | tokens and toasts change scale and alpha only, never brightness. Pouch punches ≤2/s (<3 changes/s). Nothing loops |
| Performance | a pool of 6 token sprites, no particles. If `perfGuard` lowers quality, tokens turn off and the pouch just updates |
| Rule | tokens never show "almost" or "close to" anything: no "12 more to a shell", no progress bars in the HUD |

### 10.2 Round summary (replaces the §13.4 / §14.3 / §16 round-end sequence; keeps its principles)

**Principles, unchanged:** it sits on top of the loss screen. From t = 0, one tap anywhere except the button hit areas restarts in **<0.5 s** and kills all tweens. **Everything is already granted and saved at t = 0.** Anything not shown becomes a *fresh* marker. Only a **new** pointerdown after the loss counts (a finger still down from the last drop does not restart). Android back = Home.

**"Collect all / continue": not added.** Collection happens automatically at t = 0, so a collect button would be an extra tap with no purpose (friction) and a spot for "almost" framing. The only choices are **Replay** and **Home**.

**Order and grouping** (the logic: what I did → what I got → what I found → what grew → what I achieved → a calm end)
| Row | Group | Shown when | Content | Animation (ms) |
|---|---|---|---|---|
| R0 | **Result** | always | score (large), record chip: crown + best, and the record buddy. New record: static gold ring + "New record!" / "Nytt rekord!". Best piece this round (small) | static at t = 0 (existing loss screen) |
| R0d | **Daily Jar** (Daily only) | Daily round | stamp into the day cell icon (identical for archive dates, R3), "Best today", "+2 sand" on the first finish, guest-set catches as silhouettes with a "saved" book icon | 140 pop + 500 stamp |
| R1 | **Pearls and sand** | ≥1 merge | "+N" pearls counts up (the redesigned soft tally: ≤6 ticks, AUDIO; tier ≤ T3, R17), sand +120 ms later. Later rows fly their currency into this row, which bumps it. Final value = **everything credited this round** (merges + missions + Journey + legacy sand + Daily), exactly what the Start pills gain. The affordHint follows CS5/P2-2 (neutral sound, full ring) | 140 + 500 |
| R2 | **Glimmers and sets** | ≥1 catch, or the set bar moved | the existing flyers from the HUD chain into a Book icon (max 6, shiny with glitter, rest as a pile), meter x/21, set bar "412 / 600 to next set". **New set:** the existing ceremony (icon, 3 rings, jackpot 0.9 without shake, zoom or hit-stop; calm mode: 1 ring), then it settles into the row as a set chip | 140 + (n−1)·140 + 380 + 80 + 300 bar; new set +900 |
| R3 | **Buddies** | ≥1 free shell earned | shell icon(s), stacked 2–3, no number, sub-label "Gift!" (CS5). The buddy is **not** revealed here: opening stays on Start (Shells card badge; CS6 choose 1 of 3 for the first) | 140 + 200 |
| R4 | **Journey** | ≥1 merge | level badge + XP bar filling by +N. Per level-up: badge pop + the reward icon. Pearls/sand fly to R1, items show with a "new" tag, and **feature unlocks** (Missions, Aquarium, Present, Daily Jar) show their icon + "New: Aquarium" / "Nytt: Akvarium". Max 2 level-ups animated, more shown static | 140 + 400 + 360 per level-up (feature unlock 600, never compressed below 0.75×) |
| R5 | **Missions** | ≥1 completed, or progress changed | per completed (max 3): deed chip ("Chain of 4!") with its goal ring filling (R10), then its reward flies to R1. Then static progress chips "2/3" for missions that moved. The next missions are **not** shown here (Journey sheet) | 140 + 500 per completion |
| R6 | **Trophies and mastery** | ≥1 trophy or star | trophy icons (hidden ones with a gold border), mastery stars with the set icon. Legacy sand flies to R1, items get a "new" tag. Max 4 animated, rest static | 140 + 160 per icon |
| R7 | **Stop moment** (N9/CS4) | trigger per §3.9, once per session | the buddy (or a Glimmer) yawns/waves + "Nice run! Good place for a break." Appears **last**, after every earned item, never followed by a reward | 300 fade |
| – | **Buttons** | always, active from t = 0 | **Home** (`card`, 96×64, label "Home"/"Hem") + **Replay** (`primary`, 216×64). At the stop moment: both 164×64. Daily Jar: **Home · Calendar · Play again**, 104×64 each, equal weight (applied R4). Replay pulses 3 cycles, then rests (CS4). Hit areas +8 px; the rest of the screen = Replay | – |

- **Hide empty groups:** a row that has nothing new is not drawn (no zeroes, no "0 trophies"). Rows close up from the top, so a quiet round shows R0 + R1 + R4 + the buttons.
- **No "almost" framing:** no "N more to…", no teasing of the next reward, no pulse after settling (apart from the 3 replay cycles). The Journey bar shows progress because it *is* a bar, with no text.

**Layout zones (logical px; ui-designer finalises):** R0 y 24–150 · rows R0d–R6 y 160–468, row height 40 + 4 gap, **max 7 rows** · R7 y 474–526 · buttons y 552–616.

**Timing budget**
| Case | Duration |
|---|---|
| Rows run in order; the next row starts 100 ms before the previous one's main motion ends | – |
| Quiet round (R1 + R4) | ≈1.1 s |
| **Typical** (3 catches, XP, 1 mission) | **≈2.5 s** (same as today) |
| Planned > 3.5 s | all durations × max(0.5, 3.5 / planned). Rows that would still start after 3.0 s pop in **statically** together at 3.0 s. **Hard cap 3.5 s**, then everything is static until tap |
| Sounds | at most one row sound per 120 ms. Only new record and new set have fanfares (existing). Level-up, trophy and mission sounds ≤ T4, daily stamp ≤ T3 (applied R17) |
| Calm mode | 1 ring, flyers max 3, a single tally tone instead of ticks, haptics 10 ms |

**Skipping (tap/Home before the end) → fresh markers:** catches, sets, trophies and mastery stars → Book badge + per-item `fresh`. Free shell → Shells card badge (existing). Journey rewards and level-ups → a static dot on the Journey bar until the sheet is opened (`journey.fresh`). Completed missions → the Journey sheet shows them ticked once (`missions.freshDone`). New Aquarium items → Aquarium card badge (existing `aquarium.fresh`).

### 10.3 Data and save
```ts
// data/pickup.ts (cadence: game-designer; positions: ui-designer)
export const PICKUP = { burstWindowMs: 1200, burstMaxMs: 1000, pearlTokensPerSec: 2, maxInFlight: 3,
  pearlFlyMs: 420, sandFlyMs: 520, sandMinGapMs: 500, pouchPunch: { pearl: 1.15, sand: 1.25 },
  toast: { inMs: 180, holdMs: 1600, outMs: 240, minGapMs: 3000, queue: 2, quietAfterDangerMs: 1000,
    priority: ['trophyHidden', 'mission', 'levelUp', 'mastery', 'trophy'], maxChars: 22 },
  calm: { pearlTokens: false, sandPunch: false, toastSlide: false }, poolSize: 6 } as const;
// data/summary.ts
export const SUMMARY = { rowOverlapMs: 100, typicalBudgetMs: 2500, hardCapMs: 3500, staticAfterMs: 3000, minScale: 0.5,
  unlockMinScale: 0.75, rowH: 40, rowGap: 4, maxRows: 7, maxAnimated: { flyers: 6, levelUps: 2, missions: 3, trophyIcons: 4 },
  soundMinGapMs: 120, replayPulseCycles: 3, buttons: { home: [96, 64], replay: [216, 64], stopEqual: [164, 64], daily: [104, 64] } } as const;
```
Save additions: `journey.fresh: boolean`, `missions.freshDone: string[]`, `debug.rounds[i].summary: { plannedMs, shownMs, skipped }`. New loops for `JUICE.pulseHalfCycleMs`: none (the replay pulse already exists and is capped at 3 cycles).

**Safety note:** in-round tokens and toasts are feedback on earned items, not new rewards, so there are no new odds, timers or triggers. They do add in-round stimulation, so the child-safety gate should check the cadence caps and calm mode. The summary adds a Home button and the stop moment, which CS4 requires.

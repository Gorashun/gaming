# RETENTION.md: KLUNK retention lanes

Owner: game-designer · v1 2026-09-26 · Status: **design, waiting for simulation (balance-analyst), child-safety gate and legal gate.** Nothing in this file may be built before the gates in TEAM.md rule 3.
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
| Round-end "new!" (§13.4) | loss screen | look / tap to replay | catches, set unlock | book | ≤2.5 s, skippable, restart <0.5 s | PASS | exists |
| Pearls / sand tally (§16.1) | round end | – | amount of the round | currency | ≤0.6 s, no coin clink, never "double it" | PASS (P3-3) | exists |
| Free shell (§16.2) | merge milestone | open on Start | buddy (random, no dupes) | buddy | fixed 1.2 s ceremony, no pity, **CS6: first = choose 1 of 3** | PASS / watch item §3 | exists |
| Shells shop + upgrades (§16.2–16.3) | enough pearls | buy / upgrade | buddy / param step | currency → buddy | honest odds (**CS1**), two-tap buy, no "afford" badge | PASS / watch item | exists |
| Set bar → set unlock (§13.3) | merges | play | which set (random order) | book page | no dupes, nothing missable | PASS | exists |
| **N7 Missions** (new) | 3 cards in Journey sheet, progress at round end | play for a goal | *which* mission comes next; reward hidden until done | none | never expire, free swap, skill/variety only | **PWC-B**, all 6 conditions met (§3.7) | M |
| **N9 Good place to stop** (new, = CS4) | ≥20 min or ≥6 rounds in a session | – | – | – | once per session, blocks nothing, no reward either way | **PASS** (wellbeing moment) | S |

### 1.3 Session-to-session (hours)
| Lane | Trigger | Action | Variable reward | Investment | Guardrail | Safety status | Size |
|---|---|---|---|---|---|---|---|
| **N2 Tide Pool** (new, inside Aquarium) | "something happened while I was away" | open Aquarium (1 tap = collect) | none by design: deterministic, fills over 24 h | – | cap 40 pearls ≤ 1 round, ≥24 h fill, never lost, no "full!" alert, no amount on Start | **PASS** (capped while-away accumulator) | S |
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
| N1 | Daily Jar | R#1 ★ | strongest "come back tomorrow" without loss; reuses seedable director | **Past days stay playable** (PASS row requires an archive). **Board-blind fixed queue** so it is truly identical for everyone. Outcome-changing abilities paused (fairness for 7–10, research §5). **No stamp-count rewards** (would be "play X days", banned for achievements) |
| N2 | Tide Pool | R#2 ★ | "something happened while away", premium feel | **Merged into the Aquarium** (one home, one tap to collect). Cap **40 pearls**, not "≈1 shell/day" (R#2): PASS row caps at ≤1 round of play |
| N3 | Daily Present | R#3 ★ | covers weekends and trips | **Bank cap 7, not 3** (PASS row requires ≥7). **Deterministic content** (PASS row: never random), so R#3's "occasional surprise" becomes a fixed, unannounced cycle. Player-facing name "Present", not "Gift", because CS5 renames the free buddy shell sub-line to "Gift!" |
| N4 | Journey | R#4 ★ | the collection ends after 12–16 h of play; this runs 60–140+ h | XP from merges **only** (no loops with other lanes) |
| N5 | Trophies | R#7 | surprise-based (low overjustification), absorbs the 6 one-time sand milestones | no day-count, spend or open conditions |
| N6 | Set mastery | R#8 | extends 5 sets without new content | star 3 = full page, which already pays 10 sand, so mastery pays **cosmetics only** |
| N7 | Missions | R#6 | session goals; ties HUD icons and sets together | **Surprise-first**: the first mission is revealed already done; rewards hidden until completion; small |
| N8 | Aquarium | R#5 | gives book, buddies and all cosmetic rewards a place (investment) | fixed spots (art budget, kid-simple). L-size, ship with N2 |
| N9 | Good place to stop | R#9 / CS4 | trust, ICO std 13, required before new lanes (baseline P1-4) | built as part of CS4 |

**Build order (proposal for producer):**
1. **Batch A (no rating change):** CS1–CS7 → N9 (with CS4) → N4 → N5 → N6 → N7.
2. **Batch B (one release, PEGI 7 + listing update, DESIGN §19, inv. 10):** N8 + N2 → N3 → N1.

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
| Calendar | month grid; stamped days show the day's set icon in colour; unstamped past days show the same icon faint and **neutral** (no X, no grey "missed" state, no count, no month-complete reward). Swipe back to the unlock month |
| Start badge | static dot on the Daily button only while **today's** jar is unfinished (new content). No pulse, no count |

**UI**
| Where | What |
|---|---|
| Start | secondary button under PLAY: today's set icon + "Daily"/"Dagens" (≤10 chars) |
| Daily sheet | calendar, big "Play today" (primary), tap a past day → "Play" + its best |
| In game | small calendar chip under the score (day's set icon); nothing else changes |
| Result | on top of the loss screen: score, "Best today", stamp flies into its cell (0.8 s) + "+2 sand" on first finish; buttons **Try again** (primary), **Home**, **Calendar**, all equal height. The first finish of the day also counts as a stop moment (N9) |

**Player sees:** day 1 → one stamp, the day's set (often a locked guest set = a preview). Day 7 → 4–7 stamps (est.), three to five different sets tried. Day 30 → a colourful month, trophies D1–D3 possible, a personal best per day.

### 3.2 N2 Tide Pool [LP: "Tide Pool" / "Tidvattenpölen"]
| Item | Value |
|---|---|
| Unlock | Journey level 3 (together with N8). The pool starts empty at unlock |
| Fill | **40 pearls over 24 h** = 1.667 pearls/h, linear, by wall clock (while away or playing). **Cap 40**, then it simply stops. Nothing decays |
| Formula | `amount = min(cap, stored + rate × (now − since))`. On collect: `stored = 0, since = now`. **Clock moved backwards**: `stored = amount at last save, since = now` (nothing lost, nothing gained) |
| Collect | opening the Aquarium **is** the one tap: after 400 ms the pearls fly to the pearl pill (≤0.8 s, tally up). Floors to whole pearls; the fraction stays |
| Visual | a rock pool in the Aquarium, one small level-0 Glimmer per 5 pearls (max 8). At cap they nap (slow bob ≤0.5 Hz). **No text "full", no badge, no amount shown on Start** (stops "check every few hours") |
| Never | random amounts, bonus multipliers, "collect ×2", upgrades, notifications |

Player sees: day 1 → first fill overnight. Day 7 → ~40 per visit if they come once a day, less if twice (est.). Day 30 → routine "the Glimmers brought pearls".

### 3.3 N3 Daily Present [LP: "Daily Present" / "Dagens paket"]
| Item | Value |
|---|---|
| Unlock | Journey level 4, **one present already waiting** (endowed) |
| Accrual | +1 per new local date since `lastDay`, **bank max 7**. Clock backwards: nothing removed, `lastDay = today` |
| Content | deterministic by `present.opened` (1-based), cycle of 5: #1 **25 pearls**, #2 25 pearls, #3 **1 sand**, #4 25 pearls, #5 25 pearls **+ next present decoration** (12 in order, §3.8). When the 12 are used up, #5 = 25 pearls + 1 sand. Average ≈ 25 pe + a decoration every 5th day. Same on day 1 and day 100 |
| Opening | tap the present on the Start stage → one unwrap (0.6 s) for **all waiting presents** together, showing the sum and any decoration. No reel, no candidates, no per-present tapping loop |
| Visual | a ribbon-tied scallop at the right edge of the stage, visible only while ≥1 waits; 2–3 stacked when more wait (no number). One gentle wobble when Start appears, then still (≤3 cycles rule, P2-3 spirit) |
| Separation from buddy shells | different silhouette (ribbon), different sound, no rarity colours, never contains a buddy |

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
| 3 | **Aquarium + Tide Pool unlock** + small decoration #1 |
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

### 3.5 N5 Trophies [LP: all names]

**Rules:** a third tab in the Book: **Sets | Buddies | Trophies**. Six shelves by group. Hidden trophies show as a "?" silhouette in their group, with no condition text until earned. Earned: name + condition text (EN/SV) + date. A new trophy is shown at the round end (one large, others as icons), never mid-round; the Book card gets a static badge until the tab is visited. Rewards: the 6 **legacy milestones keep their +3 sand** (paid once through the existing `economy.milestones` ledger, never twice); the 8 hidden give an Aquarium item; 1 visible (B7) gives an item; the rest are recognition only (overjustification, research §5). No "play X days", "open N shells", "spend", "upgrade" or negative trophies.

| # | id | EN [LP] | SV [LP] | Condition | Hidden | Reward |
|---|---|---|---|---|---|---|
| **Merging** |
| 1 | first_merge | First Merge | Första sammanslagningen | make a merge | – | – |
| 2 | chain3 | Chain of Three | Trekedja | chain ≥3 | – | – |
| 3 | chain5 | Chain of Five | Femkedja | chain ≥5 | – | – |
| 4 | combo10 | Combo Ten | Combo tio | combo ≥10 | – | – |
| 5 | busy_jar | Busy Jar | Full fart | 120 merges in one round | – | – |
| 6 | big_clear | Big Clear | Storstädning | one bomb clears ≥6 pieces | – | – |
| 7 | rainbow_boost | Rainbow Boost | Regnbågslyft | rainbow on a level ≥7 | – | – |
| 8 | steady_hands | Steady Hands | Stadiga händer | leave danger 3 times in one round | – | – |
| **Heights** |
| 9 | level7 | Level 7 | Nivå 7 | first level 7 | – | 3 sand (legacy `level7`) |
| 10 | level8 | Level 8 | Nivå 8 | first level 8 | – | 3 sand (legacy) |
| 11 | level9 | Level 9 | Nivå 9 | first level 9 | – | 3 sand (legacy) |
| 12 | level10 | Level 10 | Nivå 10 | first level 10 | – | 3 sand (legacy) |
| 13 | double_klunk | Double Klunk | Dubbel-Klunk | first double Klunk | – | 3 sand (legacy `doubleKlunk`) |
| 14 | whole_chain | Whole Chain | Hela kedjan | all 11 HUD chain lights in one round | – | – |
| 15 | five_tens | Five Tens | Fem tior | create level 10 five times (total) | – | – |
| **Book** |
| 16 | first_sparkle | First Sparkle | Första skimret | first shiny | – | 3 sand (legacy `shiny`) |
| 17 | sparkle_collector | Sparkle Collector | Skimmersamlare | 5 shiny slots filled (any sets) | – | – |
| 18 | full_row | Full Row | Full rad | all 11 normal slots on one page | – | – |
| 19 | full_page | Full Page | Full sida | 21/21 on one page (the 10 sand stays in §16.1) | – | – |
| 20 | set_explorer | Set Explorer | Setutforskare | a round in each of the 5 sets | – | – |
| 21 | set_master | Set Master | Setmästare | 3 mastery stars in one set | – | – |
| 22 | whole_book | Whole Book | Hela boken | 105/105 slots | – | item "Golden Book Stand" / "Guldbokstöd" |
| **Daily Jar** |
| 23 | jar_of_day | Jar of the Day | Dagens burk | finish a Daily Jar | – | – |
| 24 | better_try | Better Try | Bättre försök | beat your own best on a Daily Jar you already finished | – | – |
| 25 | every_jar_set | Every Jar Set | Alla burkset | finish a Daily Jar in each of the 5 sets (archive counts) | – | – |
| 26 | daily_deep | Daily Deep | Dagens djup | a level 9 in a Daily Jar | – | – |
| **Home and Journey** |
| 27 | moving_in | Moving In | Inflyttning | open the Aquarium | – | – |
| 28 | decorator | Decorator | Inredare | place 5 decorations | – | – |
| 29 | full_aquarium | Full Aquarium | Fullt akvarium | all 8 spots + centerpiece filled | – | – |
| 30 | journey10 | Journey 10 | Resan 10 | Journey level 10 | – | – |
| 31 | journey50 | Journey 50 | Resan 50 | Journey level 50 | – | – |
| 32 | ten_missions | Ten Missions | Tio uppdrag | complete 10 missions | – | – |
| **Secret (hidden)** |
| 33 | tickled | Tickled | Kittlad | tap your buddy on Start 10 times in a row | ✓ | Giggle Bubble / Fnissbubbla |
| 34 | calm_steady | Calm and Steady | Lugn och fin | a level 8 with Calm mode on | ✓ | Sleepy Stone / Sömnig sten |
| 35 | big_boom | Big Boom | Stor smäll | a bomb clears a level ≥8 | ✓ | Bubble Volcano / Bubbelvulkan |
| 36 | rainbow_top | Top of the Rainbow | Regnbågens topp | a rainbow creates a level 10 | ✓ | Rainbow Arch / Regnbågsvalv |
| 37 | waterfall | Waterfall | Vattenfall | chain ≥7 | ✓ | Tiny Waterfall / Litet vattenfall |
| 38 | sparkling_giant | Sparkling Giant | Skimrande jätte | a shiny level 10 | ✓ | Sparkle Orb / Skimmerklot |
| 39 | double_sparkle | Double Sparkle | Dubbelskimmer | two shinies in one round | ✓ | Twin Starfish / Tvillingsjöstjärnor |
| 40 | say_hello | Say Hello | Säg hej | tap one Glimmer in the Aquarium 5 times | ✓ | Hello Shell / Hej-snäckan |

Player sees (est., engaged): day 1 → 5–8, day 7 → 13–17, day 30 → 25–30 of 40.

### 3.6 N6 Set mastery [LP]
| Star | Condition (per set) | Reward |
|---|---|---|
| ★1 | all 11 normal slots caught | set plant (floor): Glimmer Coral / Glimtkorall, Planet Moss / Planetmossa, Frost Fern / Frostbräken, Candy Kelp / Godistång, Ember Anemone / Glödanemon |
| ★2 | create a level 10 **in this set** (Daily Jar guest set counts) | set jar skin: Glimmer Jar / Glimtburk, Planet Jar, Frost Jar, Candy Jar, Ember Jar (SV: Planetburk, Frostburk, Godisburk, Glödburk) |
| ★3 | full page 21/21 (sand already paid by §16.1) | gold page frame + set backdrop: Glimmer Deep / Glimtdjupet, Planet Orbit / Planetbanan, Frost Cave / Frostgrottan, Candy Lagoon / Godislagunen, Ember Vent / Glödkällan |

UI: three star slots in each Book page header; tap a star → one-line condition. Earned star: round-end icon + page header pop. 15 stars total, 15 cosmetics, **0 currency**. Plants, jars and backdrops are **one recipe each × 5 set palettes** (art budget).

Player sees (est., engaged): day 7 → ★1 in the base set. Day 30 → 5–8 stars.

### 3.7 N7 Missions [LP: all texts]

**Rules (PWC-B, each condition checked)**
| Condition | How it is met |
|---|---|
| B1 no expiry | a mission stays until done; completed ones are replaced at the round end; open ones are never removed |
| B2 free swap | swap button on each card, free, unlimited, instant; the swapped mission goes to the back of the queue |
| B3 skill/variety only | pool below; no "play N rounds", "log in", "open", "spend", "upgrade", no Daily Jar missions |
| B4 deterministic, ≤1 round | **T1 20 pearls · T2 30 pearls · T3 40 pearls + 1 sand** |
| B5 no "all 3" bonus | none |
| B6 no timers/labels | none |

- **Slots 3.** Unlock at Journey L2. **Surprise-first:** at unlock the game checks round 1 against the pool in order `lvl6_round, chain3, combo5, lvl7_round, bomb4`; the first match is shown **already completed** ("You already did this!", 20 pearls), then 3 fresh missions fill the slots. If none matches, the first 3 are shown normally.
- **Next mission (WHAT, never IF/WHEN):** a seeded shuffle of the pool (`missions.seed`, set at unlock), skipping ineligible and currently active ones. Mix rule: at most 1 T3 and at least 1 T1 active.
- **Rewards hidden until done:** each card shows the goal, a progress count and the same closed-gift icon for every tier. On completion the celebration names the deed first ("Chain of 4!"), then the reward flies (≤0.8 s). Exact tier rewards are listed on the parent info sheet (honesty; CS1 sheet).
- Progress counts in all modes, including the Daily Jar. Missions never read or influence the director (inv. 6).
- Where: Journey sheet (3 cards + swap). Round end: one row of mission icons **only if progress changed**. Round start: the 3 icons show for 1.2 s, then fade (PWC-F: shown at start only, no fail state or sound).

**Pool (26)**
| # | id | EN [LP] | SV [LP] | Scope | Target | Tier | Eligible when |
|---|---|---|---|---|---|---|---|
| 1 | lvl6_round | Make a level 6 in one round | Gör en nivå 6 i en runda | round | 1 | 1 | always |
| 2 | lvl7_round | Make a level 7 in one round | Gör en nivå 7 i en runda | round | 1 | 1 | always |
| 3 | lvl8_round | Make a level 8 in one round | Gör en nivå 8 i en runda | round | 1 | 2 | maxLevelEver ≥ 7 |
| 4 | lvl9_round | Make a level 9 in one round | Gör en nivå 9 i en runda | round | 1 | 3 | maxLevelEver ≥ 8 |
| 5 | lvl10 | Make a level 10 | Gör en nivå 10 | round | 1 | 3 | maxLevelEver ≥ 9 |
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
| Tide Pool | lower-right rock pool (§3.2) |
| Never | needs (food, cleaning), decay, night/sad states, items from random draws, buying items for currency (§16.2 "honest end": no new sinks) |
| Start card | "Aquarium"/"Akvarium", icon = small tank. Sub-line = decorations owned "9 / 62". Static badge **only** for a new, unseen item. **No pool amount on Start** |

**Item sources (62 aquarium items + 11 jar skins + 4 stage styles)**
| Source | Aquarium items | Other |
|---|---|---|
| Journey small (L3, L7, L12 … L97) | 20 floor/wall/surface: Pebble Pile, Sea Grass, Tiny Starfish, Bubble Stone, Scallop Shell, Sand Dollar, Coral Sprig, Sea Fan, Spiral Shell, Anemone, Kelp Strand, Brain Coral, Mussel Cluster, Friendly Urchin, Driftwood Twig, Glass Float, Tube Worms, Sea Sponge, Oyster, Tiny Lighthouse (SV names by legal/ui with the list) | – |
| Journey big | 6 centerpieces + 5 backdrops (§3.4) | 6 jar skins, 4 stage styles |
| Set mastery | 5 plants + 5 backdrops | 5 jar skins |
| Daily Present (every 5th) | 12: Paper Boat, Glass Bottle, Toy Submarine, Diving Helmet, Sand Bucket, Beach Ball, Sea Glass Pile, Clay Pot, Tiny Bridge, Snail House, Rope Swing, Pinwheel Shell | – |
| Trophies | 8 hidden + Golden Book Stand = 9 | – |
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

---

## 4. Start screen entry points (for ui-designer, UI.md §17; layout is theirs)

| Lane | Entry point | Badge rule |
|---|---|---|
| Daily Jar | secondary button under PLAY (today's set icon + "Daily") → Daily sheet | static dot while today's jar is unfinished |
| Daily Present | object on the right edge of the hero stage | the object itself; no dot, no number |
| Aquarium + Tide Pool | 4th card "Aquarium" (Book, Buddies, Shells, Aquarium) | static, only for an unseen new item |
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
| **First round end** (~3–5 min) | pearls tally, catches fly to the Book, **Journey bar appears: L2 → Missions** with a surprise mission already done (+20 pearls), 3 missions shown; trophies First Merge / Chain of Three | 3 mission goals, XP bar to L3 |
| **First session** (engaged, 2–3 rounds) | first shell as **choose 1 of 3 rares** (CS6) at 90 merges (proposed, §7); **L3 Aquarium** ("your Glimmers moved in") + Tide Pool starts; **L4 Daily Present** (1 waiting); trophies Level 7, Chain of Three | "the pool fills while you're away", L5 = Daily Jar on the track |
| **Day 1 end** | casual L3 (Aquarium, pool); engaged L6: **first Daily Jar** + stamp + Old Anchor; skilled L9; engaged and skilled get the first set unlock (200 merges) | casual: L4–5 tomorrow; everyone: a new jar tomorrow |
| **Day 2** | new Daily Jar (new set, often a guest preview of a locked set); present #2; pool ≈ full (40); casual reaches **L4–L5** (present + Daily Jar); engaged gets the 2nd free shell (400 merges) and ~L9 | next jar tomorrow, L10 jar skin |
| **Day 7** | casual L10 (first jar skin), engaged L19, skilled L26; 4–7 stamps; 2–3 sets; engaged ≈ 10–12 buddies; first mastery star (Full Row); 6–9 Aquarium items; ~15 trophies; present decoration #1 (present #5) | next big Journey reward, next set, hidden "?" trophies |
| **Day 30** | casual L23, engaged L41, skilled L55; engaged ≈ 36–42 buddies, 4–5 sets, 1–2 full pages (★3, gold frames); 25–30 trophies; 16–22 Aquarium items, backdrops to choose; a month of stamps | whole book, set mastery, L50 stage, upgrades to III, Journey to L100 |
| **Beyond** | the collection ends at 10–14 h (engaged), Journey L100 ≈ 143 days (engaged) / 80 days (skilled); after that 100+N levels, upgrades, whole book, remaining trophies | always one Journey reward within ≤10 rounds |

---

## 6. Targets for balance-analyst (all est.; simulate before build)

Extend `economy-sim.py` (or `docs/sim/`) with: the three profiles, 1 and 2 sessions/day, days played 7/7 and 4/7, the Journey curve, missions (completion model per tier), Daily Jar (+2 sand/date), pool (1.667/h, cap 40, collected at each session start) and present (cycle of 5).

| # | Metric | Casual child | Engaged child | Skilled adult | Tolerance / note |
|---|---|---|---|---|---|
| T1 | Session length | 10 min | 12–13 min (×2) | 20 min (×2) | stop moment shown in ≤25 % of child sessions |
| T2 | Rounds per session | 2 | 2–3 | 3–4 | – |
| T3 | Time to first shell | ≤10 min | ≤8 min | ≤7 min | requires `free.at[0]` 120 → **90**; check casual first |
| T4 | Shells per hour, hours 1–5 | 2.5–3.5 | 3.5–4.5 | 4.5–5.5 | baseline §16 ≈3–4/h at 60 m/r |
| T5 | Hours of play to 24 buddies | 7–9 h | 5–7 h | 4–5.5 h | ≤15 % faster than the §16 sim |
| T6 | Hours of play to 48 buddies | 14–18 h | 10–14 h | 8–11 h | as days: casual 84–108, engaged 24–34, skilled 12–17 |
| T7 | Journey level day 1 / 7 / 30 | 3 / 10 / 23 | 6 / 19 / 41 | 9 / 26 / 55 | ±15 % |
| T8 | Daily-lane share of rewards (pool + present + Daily Jar bonus) / all rewards, pe, days 1–30 | ≈32 % | ≈14 % | ≈8 % | **≤35 %** for every profile |
| T9 | Return-only value (pool + present) per day / one round of play, pe | ≈0.76 | ≈0.54 | ≈0.39 | **<1.0** (inv. 3), target ≤0.8 |
| T10 | Mission rewards / pearls from merges | ≤25 % | ≤25 % | ≤25 % | completion 0.5–1.0 per round |
| T11 | Journey currency / total currency | ≤10 % | ≤10 % | ≤10 % | est. ≈4–6 % |
| T12 | Max value after 7 days away (7 presents + full pool) | ≤ 3 casual rounds (≈255 pe) | – | – | est. ≈215 pe + 1 item |

**Knobs, in this order, if a target misses:** mission rewards ×0.8 → `free.every` 750 → 900 → pool cap 40 → 30 → present pearls 25 → 20. Shop prices do not change (test testers' mental price anchors; §16.2).

Rough daily value behind T8 (est., pe/day): casual play ≈187 + missions ≈33 + Journey ≈20 vs daily lanes 115 (pool 40, present 25, Daily Jar 2 sand = 50). Engaged ≈600 + 105 + 25 vs 115. Skilled ≈1 120 + 180 + 30 vs 115.

---

## 7. Integration with CS1–CS7 and the economy

### 7.1 Safety fixes (BACKLOG Fas 12)
| CS | Interaction with the new lanes |
|---|---|
| CS1 honest odds + odds sheet | no new random rewards anywhere (inv. 7 trivially holds). The odds sheet also lists: first shell = choose 1 of 3 rares (CS6), mission tier rewards, "the Daily Jar is the same for everyone" and the P2-6 director sentence |
| CS2 listing + privacy | **same release as Batch B**: PEGI 7 (play-by-appointment, positive), describe Daily Jar / Tide Pool / Daily Present, keep "no streaks, no timers, no energy, nothing expires" (all still true) |
| CS3 near-miss same level | no trophy, mission or Journey condition uses near-miss events (no rewards for "almost") |
| CS4 Home + stop moment | **is N9**; the Daily Jar result reuses it |
| CS5 Shells / Gift! | the free buddy shell keeps "Gift!"; the daily lane is called **Present** and looks different, so there are not two "gifts" |
| CS6 choose 1 of 3 | first shell at 90 merges (proposed); it is not a Journey reward (no double grant) |
| CS7 director blind to save | Daily mode is a pure function of `dateKey`: unit test that the 600-entry queue for a date is identical for any save contents; the paused-ability list is data. Pool, present, missions and Journey never read or write RNG state (inv. 6) |

### 7.2 Economy: sources, and why nothing double-dips
| Source | Pearls | Sand | Items | Counts toward |
|---|---|---|---|---|
| Merge (all modes) | 1 | (shiny/chain/L10 as §16.1) | – | XP, missions, free-shell counter, set unlock |
| Legacy milestones ×6 | – | 3 each, **once** via `economy.milestones` | – | now shown as trophies 9–13, 16 |
| Full page | – | 10 once (§16.1) | mastery ★3 cosmetics only | – |
| Journey | 1 610 over L1–100 | 100 | 41 cosmetics | – |
| Missions | 20 / 30 / 40 | T3: 1 | – | trophy 32 only |
| Daily Jar | – | 2 per date, first finish | – | – |
| Tide Pool | ≤40 per 24 h | – | – | – |
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
export const POOL = { unlockLevel: 3, cap: 40, fillMs: 24 * 3600e3, glimmerPer: 5, maxGlimmers: 8, flyMs: 800 } as const;
// present.ts
export const PRESENT = { unlockLevel: 4, bankMax: 7, startBanked: 1,
  cycle: [{ pearls: 25 }, { pearls: 25 }, { sand: 1 }, { pearls: 25 }, { pearls: 25, item: 'next' }],
  afterItems: { pearls: 25, sand: 1 }, items: [/* 12 ids, §3.8 */] } as const;
// journey.ts
export const JOURNEY = { xpPerMerge: 1, xpStart: 15, base: 30, step: 10, cap: 600, authored: 100,
  unlocks: { missions: 2, aquarium: 3, present: 4, daily: 5 },
  rewards: [/* JourneyReward[101], index = level */], beyond: { each: { pearls: 50 }, every5: { sand: 5 } } } as const;
type JourneyReward = { pearls?: number; sand?: number; item?: string; unlock?: 'missions' | 'aquarium' | 'present' | 'daily' };
// missions.ts
export const MISSIONS = { unlockLevel: 2, slots: 3, reward: { 1: { pearls: 20 }, 2: { pearls: 30 }, 3: { pearls: 40, sand: 1 } },
  maxT3Active: 1, minT1Active: 1, introOrder: ['lvl6_round', 'chain3', 'combo5', 'lvl7_round', 'bomb4'], showAtStartMs: 1200,
  pool: [/* MissionDef[26], §3.7 */] } as const;
type MissionDef = { id: string; tier: 1 | 2 | 3; scope: 'round' | 'total'; kind: MissionKind; target: number;
  param?: 'set' | 'buddy'; eligible?: EligibilityRule; icon: string; text: { en: string; sv: string } };
// trophies.ts
type TrophyDef = { id: string; group: 'merging' | 'heights' | 'book' | 'daily' | 'home' | 'secret'; hidden: boolean;
  name: { en: string; sv: string }; desc: { en: string; sv: string }; cond: TrophyCond;
  reward?: { sand?: number; item?: string }; legacyMilestone?: string; legalPending: true };
// mastery.ts
export const MASTERY = { stars: ['allNormal', 'level10InSet', 'fullPage'],
  rewards: { /* setId: { allNormal: itemId, level10InSet: jarSkinId, fullPage: [frameId, backdropId] } */ } } as const;
// aquarium.ts
export const AQUARIUM = { swimmersMax: 12, spots: { floor: 5, wallL: 1, wallR: 1, surface: 1, center: 1 },
  swimSpeed: [12, 30], bobHz: 0.5, tapFlipMs: 500, tapMaxPerSec: 2, items: [/* AquariumItem[62] */] } as const;
type AquariumItem = { id: string; name: { en: string; sv: string }; spot: 'floor' | 'wall' | 'surface' | 'center' | 'backdrop';
  source: 'journey' | 'mastery' | 'present' | 'trophy'; recipe: string; palette?: string; legalPending: true };
// wellbeing.ts
export const WELLBEING = { stopAfterMs: 20 * 60e3, stopAfterRounds: 6, sessionGapMs: 10 * 60e3, oncePerSession: true,
  replayPulseCycles: 3 } as const;
// economy.ts (change): free.at [120, 400] -> [90, 400]  (proposed, pending sim)
```
New loops to register in `JUICE.pulseHalfCycleMs` (inv. 8): swimmer bob, pool nap bob, present wobble (≤3), Daily badge (static, none), trophy shine (once).

### 8.2 Save file: `schema 3`, **migrated from 2 (no wipe)**
```ts
journey:   { xp: number; level: number; rewardedTo: number }
missions:  { active: { id: string; param: string | null; progress: number }[]; seed: number; cursor: number; done: number; introShown: boolean }
trophies:  { earned: Record<string, number /* epoch ms */>; fresh: string[] }
mastery:   Record<string /* setId */, [boolean, boolean, boolean]>
daily:     { unlockedOn: string | null; days: Record<string /* YYYY-MM-DD */, { best: number; first: number }> }
pool:      { stored: number; since: number /* epoch ms */ }
present:   { lastDay: string | null; banked: number; opened: number }
aquarium:  { items: string[]; placed: Record<string, string | null>; backdrop: string | null; swimmers: string[] | null /* 'set:level:n|s' */; fresh: string[] }
cosmetics: { jarSkins: string[]; jarSkin: string; stages: string[]; stage: string }
stats +=   { level10BySet: Record<string, number>; tens: number; setsPlayed: string[]; dailySetsFinished: string[]; maxChain: number; maxCombo: number; buddyTaps: number }
debug +=   { sessionMs: number; roundsThisSession: number; grants: Record<string, { pearls: number; sand: number }> }
```
Migration 2 → 3: Journey starts at xp 0 (no retroactive currency, as §16.2). Trophies and mastery stars that follow from existing stats are marked earned **without paying** (legacy sand already paid via `economy.milestones`; mastery cosmetics may be granted since they carry no currency). Everything else defaults.

---

## 9. Legal note
Every new player-facing name in this file ([LP]: lane names, trophy names, mission texts, Journey rewards, Aquarium items, jar skins, stage styles, stop-moment copy) is **pending legal review** (TEAM rule 3). The names are deliberately generic and descriptive. SV names for the 20 small decorations and the 12 present items are to be written by ui-designer with legal. "Klunk" in "Double Klunk" is our app name and follows the app-name trademark search.

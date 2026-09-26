# Retention simulation: 60 days, three profiles (RETENTION §6)

Owner: balance-analyst · 2026-09-26 · Sim: `docs/sim/retention_sim.py` (Python 3 stdlib, 200 seeded runs per case, medians). Run `python3 docs/sim/retention_sim.py` (about 4 min, or `--quick`). Sections can be run alone with `--only base|free|sens|rec|knobs`. Recalibrate a profile from a debug-panel export with `--playtest B1.json --profile casual`.

**Status: everything below is an ESTIMATE.** Merges per round, round length, skill, mission completion and session times are unmeasured (PLAYTEST.md). Existing numbers are read from `app/src/data/{economy,collection,unlocks,avatars,themes}.ts`. The lane numbers (Journey, missions, Daily Jar, Pearl Pool (formerly Tide Pool, same mechanics), Daily Present) are copied from RETENTION §3/§8.1 because they are not in `app/src/data` yet. RETENTION §10 is presentation only (grants at t = 0), so it does not change any number here. LG2 (the new score curve) does not affect currency. No game code was changed.

## 1. Model and assumptions

| Item | Casual child | Engaged child | Skilled adult | Source |
|---|---|---|---|---|
| Merges per round (mean, sd 25 %) | 45 | 60 | 80 | RETENTION §5 (est.) |
| Minutes per round | 4.5 | 5.0 | 6.0 | RETENTION §5 (est.) |
| Sessions × minutes | 1 × 10 (17:00) | 2 × 12.5 (15:30, 18:30) | 2 × 20 (12:30, 21:00) | brief (est.) |
| Days played | **5/7** (random); 7/7 and 4/7 as variants | 7/7; 4/7 variant | 7/7; 4/7 variant | brief |
| Merge efficiency (skill) in the level cascade | 0.80 | 0.86 | 0.92 | est. |
| Mission completion p per active card per round, T1/T2/T3 | .30/.12/.05 | .40/.20/.10 | .50/.30/.18 | est. (scaled by √merge ratio) |

- **Round model:** drops use levels 0–4 with weights 26/24/22/16/12. Each level's equal pairs merge with probability = efficiency, then cascade upward. Merges, pearls, catches, shinies (real `shinyP`, global pity per level, first shiny by round 3), level 10s and double Klunks all come out of this cascade. Chains ≥3 ≈ Poisson(merges × 0.010/0.013/0.017), chain ≥5 = 12 % of those. Specials: one per 42.5 drops.
- **Session rule:** start another round while in-round time + half a round < the planned minutes. Overhead is 0.4 min per round and 1 min per session.
- **Every played day:** the first round is the Daily Jar once Journey L5 is reached (upper bound for daily-lane share). The Pearl Pool is collected at every session start. Presents are opened at session start and end.
- **Spending policy (asked for):** at the end of each session, upgrade the favourite when affordable. The favourite is the highest-rarity buddy, and a child switches to a new higher-rarity buddy. Then buy gold with sand, keeping enough sand for the favourite's III. Then silver if pearls ≥ 700, else common at 300. After all 48 are owned, upgrade everything by rarity.
- **Value:** 1 sand = 25 pe. "Daily lanes" = Pearl Pool + Present + Daily Jar sand. "Play hours" = in-round time.

**Level ceiling (important).** One level-L piece is 2^L level-0 units, and an average drop is 4.82 units. So a single level 8 / 9 / 10 needs at least **53 / 106 / 212 drops in one round**, even with perfect merging. The estimated rounds of 70–100 drops therefore almost never reach level 10:

| Profile | Merges/round | P(top ≥ 7) | ≥ 8 | ≥ 9 | ≥ 10 per round |
|---|---|---|---|---|---|
| Casual | 45 | 64 % | 8 % | 0 % | 0 % |
| Engaged | 60 | 86 % | 34 % | 0 % | 0 % |
| Skilled | 80 | 98 % | 71 % | 6 % | 0 % |
| Skilled | 150 | 100 % | 96 % | 61 % | 2 % |

## 2. Results per profile (current spec, first free shell at 90)

Buddies: median (p10–p90). Fav. = the current favourite's upgrade level. Daily share is cumulative pe.

**Casual child** (45 merges, 4.5 min, 1 × 10 min, 5/7 days)
| Day | Play h | Buddies | Shells free/bought | Journey L | Pearls | Sand | Fav. | Trophies /40 | Mastery /15 | Sets | Aquarium items | Daily share |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 0.2 | 1 (0-1) | 1/0 | 3 | 90 | 10 | II | 6 | 0 | 1 | 2 | 0 % |
| 2 | 0.3 | 1 (1-1) | 1/0 | 5 | 206 | 17 | II | 8 | 0 | 2 | 3 | 8 % |
| 7 | 0.9 | 3 (2-4) | 2/1 | 9 | 156 | 30 | III | 14 | 0 | 2 | 5 | 24 % |
| 14 | 1.7 | 7 (5-9) | 2/5 | 13 | 148 | 21 | II | 19 | 0 | 3 | 8 | 28 % |
| 30 | 3.7 | 18 (14-20) | 4/14 | 19 | 132 | 37 | II | 22 | 0 | 4 | 15 | 32 % |
| 60 | 7.2 | 37 (33-41) | 7/30 | 28 | 142 | 42 | II | 24 | 0 | 5 | 24 | 34 % |

**Engaged child** (60 merges, 5 min, 2 × 12.5 min, 7/7)
| Day | Play h | Buddies | Shells free/bought | Journey L | Pearls | Sand | Fav. | Trophies | Mastery | Sets | Items | Daily share |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 0.4 | 2 (1-2) | 1/1 | 6 | 54 | 24 | II | 11 | 0 | 2 | 3 | 7 % |
| 2 | 0.8 | 3 (3-4) | 2/1 | 9 | 183 | 35 | III | 15 | 0 | 2 | 5 | 9 % |
| 7 | 2.9 | 14 (12-15) | 4/10 | 19 | 156 | 44 | II | 23 | 0 | 4 | 10 | 12 % |
| 14 | 5.8 | 29 (27-31) | 7/22 | 27 | 152 | 47 | II | 25 | 0 | 5 | 16 | 13 % |
| 30 | 12.5 | 48 (48-48) | 10/38 | 41 | 28 | 163 | II | 26 | 0 | 5 | 25 | 13 % |
| 60 | 25.0 | 48 (48-48) | 10/38 | 58 | 232 | 414 | II | 27 | 0 | 5 | 36 | 13 % |

**Skilled adult** (80 merges, 6 min, 2 × 20 min, 7/7)
| Day | Play h | Buddies | Shells free/bought | Journey L | Pearls | Sand | Fav. | Trophies | Mastery | Sets | Items | Daily share |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 0.7 | 3 (2-3) | 2/1 | 9 | 104 | 30 | III | 14 | 0 | 2 | 4 | 5 % |
| 2 | 1.3 | 6 (4-7) | 2/4 | 13 | 145 | 10 | II | 19 | 0 | 3 | 6 | 6 % |
| 7 | 4.7 | 23 (20-25) | 6/17 | 26 | 141 | 35 | III | 26 | 0 | 5 | 13 | 7 % |
| 14 | 9.4 | 47 (45-48) | 11/36 | 37 | 56 | 46 | II | 28 | 0 | 5 | 19 | 8 % |
| 30 | 20.1 | 48 (48-48) | 11/37 | 55 | 33 | 366 | II | 30 | 0 | 5 | 29 | 7 % |
| 60 | 40.2 | 48 (48-48) | 11/37 | 82 | **15 390** | **1 123** | III | 31 | 0 | 5 | 44 | 7 % |

- **First favourite at III:** casual 0.5 h (day 4), engaged 0.6 h (day 2), skilled 0.7 h (day 1). "Fav. II" later means the child switched to a new higher-rarity favourite.
- **Mean round value:** 78 / 111 / 159 pe.
- **Reward mix, days 1–30 (casual / engaged / skilled):**

| Source | Casual | Engaged | Skilled |
|---|---|---|---|
| Merge pearls | 27 % | 34 % | 34 % |
| Round sand | 22 % | 31 % | 34 % |
| Missions | 9 % | 13 % | 13 % |
| Journey | 8 % | 6 % | 5 % |
| Pearl Pool | 10 % | 4 % | 3 % |
| Present | 9 % | 3 % | 2 % |
| Daily Jar | 13 % | 6 % | 3 % |

## 3. Targets (RETENTION §6)

Verdicts for the current spec and for the recommended numbers (§5). Verdicts use the default schedule; a verdict that changes at 7/7 is noted.

| # | Casual: spec → rec. | Engaged: spec → rec. | Skilled: spec → rec. |
|---|---|---|---|
| T1 session / stop moment | 11.9 min, stop 91 % **FAIL** (see note) | 14.5 min, stop 50 % **FAIL** (note) | 22.4 min **PASS** |
| T2 rounds/session | 2.3 **PASS** | 2.55 **PASS** | 3.4 **PASS** |
| T3 first shell | 11.2 min **FAIL** → 8.5 **PASS** | 10.2 **FAIL** → 7.3 **PASS** | 10.7 **FAIL** → 6.5 **PASS** |
| T4 shells/h, h1–5 | 5.0 **FAIL** → 4.6 **FAIL** | 4.8 **FAIL** → 4.6 marginal FAIL | 4.6 **PASS** → 4.4 marginal FAIL |
| T5 h to 24 | 4.7 h **FAIL** → 5.2 **FAIL** | 4.8 **FAIL** → 5.3 **PASS** | 5.0 **PASS** → 5.2 **PASS** |
| T6 h (days) to 48 | 9.4 h, d77 **FAIL** → 10.1 h, d83 **FAIL** | 9.5 h, d23 **FAIL** → 10.3 h, d25 **PASS** | 9.7 h, d15 **PASS** → 9.9 h, d15 **PASS** |
| T7 Journey d1/7/30 | 3/9/19 **FAIL** at 5/7; 3/10/23 **PASS** at 7/7 | 6/19/41 **PASS** | 9/26/55 **PASS** |
| T8 daily share ≤ 35 % | 31.7 % **PASS** → 30.8 % | 13.0 % **PASS** | 7.3 % **PASS** |
| T9 return value / round | 0.69 **PASS** (7/7: 0.83 **FAIL** goal) → 0.58 (7/7: 0.69) **PASS** | 0.59 **PASS** → 0.49 | 0.41 **PASS** → 0.35 |
| T10 missions / merge pearls ≤ 25 % | 33 % **FAIL** → 19 % **PASS** | 36 % **FAIL** → 22 % **PASS** | 37 % **FAIL** → 23 % **PASS** on share (1.16 completions/round, above the 0.5–1.0 band; that rate is my guess) |
| T11 Journey ≤ 10 % | 8.0 % **PASS** | 5.8 % **PASS** | 4.5 % **PASS** |
| T12 7 days away ≤ 3 casual rounds | 215 pe **PASS** now; 265 pe once the 12 present decorations are used up (present #61+) **FAIL** (limit 233) → 205 pe **PASS** | – | – |

**T4 resolution.** T4 moves in steps of 0.2 (one shell in 5 hours). The marginal misses (4.4 and 4.6 vs 4.5) are within one shell.

**T1 note (R11).** The stop moment fires on the first Daily Jar finish of the date. That is the casual child's first round of every played day, so the metric reads 91 % (casual) and 50 % (engaged). Without that trigger it is 0 %. Under R11 this is a health signal, not a balance knob: I did not touch any trigger. The measurement definition needs a decision from game-designer and child-safety: either count the Daily-Jar trigger separately, or accept a high share because the jar result is the natural end. The session-length misses (+0.5 to +1.5 min) come from my overhead assumptions, not from economy numbers.

**Casual T4/T5/T6 are structurally inconsistent with T8.** About 31 % of a casual child's value comes from daily lanes, which pay per calendar day, not per hour played. Per hour played, collection is therefore about 1/(1 − 0.31) ≈ 1.45× faster than in the §16 sim. The "≤ 15 % faster" hour targets and the "≈ 32 %" daily share cannot both hold. **Recommendation:** restate casual T5/T6 in days (current: 24 buddies on day 43 and 48 on day 83 at 5/7; 48 on day 63 at 7/7) and keep T8 as the guard. Hitting the hour targets would need the daily lanes cut to about 15 % of value, which removes their point.

## 4. First free shell: 90 vs 120 (and lower)

Free shells are granted at round end, so the time to the first shell is always a whole number of rounds.

| First at | Casual: median min (p90), on day 1 | Engaged | Skilled |
|---|---|---|---|
| 120 (now) | 14.4 (16.4), **12 %** on day 1 | 12.0 (14.9) | 12.3 (14.9) |
| 90 (proposed) | 11.2 (13.5), 68 % | 10.2 (12.1) | 10.7 (13.3) |
| 75 | 9.6 (12.0), 100 % | 9.5 (11.6) | 7.8 (12.1) |
| **60** | **8.6 (10.3), 100 %** | **7.5 (10.5)** | **6.6 (10.9)** |
| 45 | 6.6 (9.4), 100 % | 5.3 (8.2) | 5.9 (8.5) |

- **90 beats 120.** At 120, 88 % of casual children end day 1 without a buddy. At 90, 32 % still do.
- **Recommendation: `free.at: [60, 400]`.** It is the highest threshold that meets T3 for all three profiles. The casual child gets the CS6 choose-1-of-3 at the end of round 2; engaged and skilled players mostly get it at the end of round 1.
- Hours to 24/48 do not change (±0.1 h), because only one shell moves earlier.
- At −30 % merges, casual needs 10.5 min (a third round for some); 60 still lands on day 1.

## 5. Recommended numbers (re-simulated)

Tried the §6 knobs in order. Missions ×0.8 is not enough: T10 stays at 26–31 %. `free.every` 900 fixes engaged T5/T6 but pushes skilled T4 to 4.2, so I keep 750. Pool cap 30 is needed for R12 at 7/7.

| Change | From → To | File (programmer) | Why |
|---|---|---|---|
| First free shell | `free.at [120, 400]` → **`[60, 400]`** | `data/economy.ts` | T3 for all profiles (§4) |
| Mission rewards | T1 20 / T2 30 / T3 40 + 1 sand → **T1 10 / T2 20 / T3 30 + 1 sand** | `missions.ts` (new) | T10: 33–37 % → 19–23 %. Missions still pay more than one merge's worth per card |
| Pearl Pool cap | 40 → **30** per 24 h (rate 1.25/h) | `pool.ts` (new) | R12: casual T9 at 7/7 goes from 0.83 → 0.69 |
| Present after the 12 decorations | #5 = 25 pearls + 1 sand → **25 pearls** | `present.ts` (new) | T12 stays at 205 pe forever (was 265 > 233) |
| Unchanged | shop prices, upgrade prices, `free.every` 750, present 25 pearls, Daily Jar +2 sand, Journey table | – | – |

With these numbers: **R12 PASSES** for the casual child at 45 merges/round. T8 is 30.2 % at 7/7, 30.8 % at 5/7 and 32.1 % at 4/7 (p90 ≤ 33.7 %). T9 is 0.69 / 0.59 / 0.54. It **FAILS at −30 % merges** (31/round): T8 is 37–38 %, and T9 is 1.03 at 7/7, which breaks inv. 3. **Batch B should wait for measured casual merges per round.** Rule for sizing the lanes once it is measured: `pool cap + 25 (present) ≤ 0.8 × measured casual round value in pe`. At 78 pe that gives cap ≤ 37, so 30 is fine. At 55 pe it gives cap ≤ 19, which would also need present 20.

## 6. Sensitivity: merges per round ±30 % (current spec, first shell at 90)

| Profile | Merges | Buddies d7/d30 | Journey d1/d7/d30 | h to 24 / 48 | Shells/h h1–5 | Daily share | Missions share |
|---|---|---|---|---|---|---|---|
| Casual | 31 / 45 / 58 | 2/14 · 3/18 · 4/21 | 3/7/16 · 3/9/19 · 4/10/22 | 5.9/11.6 · 4.7/9.4 · 4.0/7.9 | 4.0 · 5.0 · 5.8 | **38 %** · 32 % · 27 % | 40 · 33 · 29 % |
| Engaged | 42 / 60 / 78 | 10/48 · 14/48 · 17/48 | 5/15/34 · 6/19/41 · 7/22/47 | 6.6/12.6 · 4.8/9.5 · 4.0/7.8 | 3.4 · 4.8 · 5.8 | 17 · 13 · 10 % | 45 · 36 · 31 % |
| Skilled | 56 / 80 / 104 | 18/48 · 23/48 · 26/48 | 7/21/45 · 9/26/55 · 10/29/63 | 6.2/12.1 · 5.0/9.7 · 4.5/8.4 | 3.8 · 4.6 · 5.4 | 10 · 7 · 6 % | 46 · 37 · 33 % |

- With the recommended numbers at −30 % merges, casual T8 is 37–38 % (the R12 rows in §5).
- **Low merges are the danger case for the daily-lane guard.** High merges mainly speed up the collection.
- Spending policy (engaged): "collector" (no upgrades until 48) reaches 48 at 8.7 h. "Saver" (silver only) needs 15.2 h. The default "mixed" policy needs 9.5 h.
- Schedule (current spec): casual 7/7 = 48 buddies on day 57. At 4/7 it is day 95. At 4/7 with one archive jar per session, casual T8 is **37 % (FAIL)**. Archive catch-up is legitimate play, but it adds daily-lane value.

## 7. Risks

1. **Level 10 is out of reach at the estimated merges (highest impact).** The mass bound says a level 10 needs ≥ 212 drops in one round (≈ 150–170 merges); no profile's estimated round comes close. As specified, that makes the following unreachable in 60 days: **0 of 15 mastery stars for every profile** (★1 needs the level-10 slot, ★2 a level 10, ★3 a shiny 10); level-10 sand; the L9/L10/double-Klunk milestones; the skill-track set unlocks for L10; trophies Level 10, Whole Chain, Five Tens, Double Klunk, Sparkling Giant and Top of the Rainbow; the `lvl10` mission. Even at 150 merges/round, casual and engaged children get 0–1 stars by day 60. This contradicts RETENTION §5 (★1 by day 7), §3.6 and UI.md §6 ("level 10 every 3–5 min"). **Action: measure merges, drops and max level per round in the playtest.** If the median is < ~150 merges, game-designer should re-spec mastery (for example ★1 = normal slots 0–8, ★2 = a level 9 in this set) and treat level 10 as a rare feat.
2. **Daily lanes dominating for low-merge casual players.** At 31 merges/round, the daily share is 37–38 % and T9 reaches 1.0 at 7/7. That is the only case where waiting pays as much as playing (inv. 3).
3. **Inflation after the collection is complete.** The collection is done on day ~23 (engaged) / ~15 (skilled). The only sink left is upgrades: 23 180 pearls + 424 sand in total. The skilled adult finishes every upgrade between day 30 (24–31 of 48 at III) and day 60 (48/48), then sits on about 15 000 pearls and 1 100 sand with nothing to buy at day 60. The engaged child holds 400+ sand from day 30 on, because pearls are the bottleneck. This is the §16.2 "honest end", but big idle counters on Start will look odd. Suggest showing balances only in the Shells tab once every buddy is at III (UI decision, not a sink).
4. **Collection exhausted early for adults and engaged children.** All 48 buddies by day 15 / 23 (T6 range). After that, Journey (L55–82 by day 30–60), trophies (30/40 by day 30) and upgrades carry retention. Stars stay empty (risk 1), so the long-term layer is thinner than planned.
5. **Missions pay too much as specified.** At 20/30/40 they are 33–37 % of merge pearls and speed up collection by about 10 %.
6. **Model limits.** Chain, combo and special rates, mission completion and trophy odds are guesses. Buddy abilities (Star Whale shiny ×2–3, Queen's extra specials) are not modelled. Sand is valued at 25 pe, which drives the share metrics (round sand is 22–34 % of value).

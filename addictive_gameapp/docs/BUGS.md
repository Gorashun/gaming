# BUGS.md – KLUNK

Owner: qa-tester. Severity: **P1** blocks testing or release, **P2** visible defect or lost player feedback, **P3** polish.
Status: `open` · `fixed <commit>` · `wontfix`. Screenshots are in `docs/qa/` (390×844; DPR 2 unless noted).
Tests marked "known bug" use `knownBug()` in `tests/e2e/qa-util.ts`. They describe the correct behaviour and are expected to fail until the fix lands. Playwright flags them as soon as they start passing. Run them with `QA_RAW=1` to see the real failure.

## Phase 1 exploratory pass (2026-09-26, test version 8, HEAD 965bd1f + uncommitted work in the tree)

| ID | Sev | Area | Title | Status |
|---|---|---|---|---|
| BUG-001 | P2 | Game over | Lifting the finger after a loss restarts the round at once, so the loss screen and reveal are skipped | open |
| BUG-002 | P2 | Save / record | After backgrounding mid-round, a new record gets no gold ring on the loss screen | open |
| BUG-003 | P2 | Save / migration | A save with `bestLevel` outside 0–10 gives a black screen at boot; a bad `highscore` shows "NaN" | open |
| BUG-004 | P2 | Shell opening (art audit 1) | The dimmed PLAY label and the cards show through the shell opening on Start; the stage text shows through the opening in the shop | open |
| BUG-005 | P2 | Game over (art audit 2) | The in-game HUD stays visible under the loss dimming and collides with the pearl tally | open |
| BUG-006 | P2 | Game HUD (art audit 3) | The hanging piece (and the buddy) covers the HUD chain row | open |
| BUG-007 | P2 | Game HUD (art audit 4) | With Sybil (Siri) the two preview frames overlap and the main frame loses its left edge | open |
| BUG-008 | P3 | Reveal | In a round that unlocks a set, the strip (catches, pearls, sand) fades out before the tally can be read | open |
| BUG-010 | P2 | Input | Every tap in the book (tabs, close X, shop, buddies) is dropped when frames take >350 ms, because the tap is measured in frame time | open |
| BUG-011 | P3 | Book / upgrade | The upgrade bar shows the same value for two levels (Theo 3 → 3 bolts, Willow 2× → 2×), so a paid upgrade looks like it does nothing | open |
| BUG-012 | P3 | Book / counters | The book's resource counters nearly touch at 5-digit pearls ("12 345" against the sand icon) and will overlap at 6 digits | open |

**Totals:** P1: 0 · P2: 8 (BUG-001 to BUG-007, BUG-010) · P3: 3 (BUG-008, BUG-011, BUG-012). BUG-009 is not used: the shop-opening finding was merged into BUG-004.

---

### BUG-001 · P2 · Game over: a finger held through the loss restarts the round
- **Steps:** Play a round and hold the finger down to aim when the loss triggers (an object stays over the danger line for 1.5 s, which often happens while the next piece is being aimed). Lift the finger.
- **Expected:** The loss screen and reveal stay up. A new tap restarts the round (DESIGN §1.5, §7.3: "a tap on the loss screen").
- **Actual:** The `pointerup` from the drag that began in the round reaches `GameOver`'s `input.once('pointerup')`, and the next round starts at once. The player never sees the score, record, catches, pearl/sand tally or new set. The data is saved, but the reward moment is lost. `GameOver.ts:138`. Suggested fix: count only a pointerup whose pointerdown happened after the overlay was created, for example by listening for `pointerdown` then `pointerup`.
- **Test:** `qa-player.spec.ts` › "förlust medan fingret är nere" (known bug).
- **Screenshot:** `docs/qa/bug-001-loss-finger-down.png` (600 ms after lifting the finger: already a new round with score 0).

### BUG-002 · P2 · Record: backgrounding mid-round suppresses the new-record ring
- **Steps:** The saved record is 3. Start a round and score 10. Put the app in the background (`visibilitychange` → hidden), bring it back, then lose without scoring more.
- **Expected:** The loss screen shows the gold ring for a new record.
- **Actual:** No ring. `Game.onHide → persist()` calls `submitRun()`, which already writes `highscore = 10`. At the loss, `submitRun()` compares 10 > 10, gets false and passes `record: false` to `GameOver`. The rule "write on visibilitychange" (DESIGN §8) is followed correctly, but the record flag must come from `startHighscore` (the record when the round began), not from the saved file. On a phone, answering a message mid-round is enough to trigger this.
- **Test:** `qa-lifecycle.spec.ts` › "bakgrund mitt i rundan … rekordringen syns ändå" (known bug). The same test confirms that banking itself is correct: pearls = merges, nothing is paid twice.
- **Screenshots:** `docs/qa/bug-002-record-after-hide.png` (after hide: no ring) and the control `docs/qa/bug-002-record-control.png` (same round without hide: ring shown).

### BUG-003 · P2 · Save: out-of-range `bestLevel` bricks the app; a bad `highscore` shows "NaN"
- **Steps:** A schema 2 save with `bestLevel: -3` or `11`, or `highscore: "abc"` (a corrupt or hand-edited file, or a future writer bug).
- **Expected:** `mergeWithDefaults` clamps or drops bad values (as it already does for the avatars and the economy), and Start renders.
- **Actual:** For `bestLevel` out of range, `Start.drawHero` throws `Cannot read properties of undefined (reading 'radius')`, and the screen stays black on every launch. The debug panel's "reset save" cannot be reached, so the only fix is clearing app data. For `highscore: "abc"`, the chip shows **NaN**, and after one round `Math.max("abc", n)` saves `NaN`, which becomes `null`. `stats.runs`/`merges` are also not normalised (negative values are kept). `save.ts mergeWithDefaults`: `highscore`, `bestLevel` and `stats.runs/merges/autoDrops` need `nonNegInt` plus a clamp of `bestLevel` to 0–10. Severity: the app can be bricked, but no current code path writes such values. The brick is P2 and the "NaN" is P3.
- **Test:** `qa-lifecycle.spec.ts` › "schema 2 med trasiga typer" (known bug). Realistic partial v7 files load fine (the "migrering" test passes).
- **Screenshots:** `docs/qa/bug-003-bestlevel-neg.png`, `docs/qa/bug-003-bestlevel-11.png` (black) and `docs/qa/bug-003-highscore-str.png` ("NaN" in the record chip).

### BUG-004 · P2 · Shell opening: the screen underneath shows through (art audit item 1, verified)
- **Steps:** (a) Start with a free shell waiting → tap Shop. (b) Book → Buddies → buy a shell in the shop with two taps.
- **Expected:** The ceremony reads as a layer of its own. The figure, rarity pearls and level diamonds stand on a calm background (DESIGN §14.3, premium bar).
- **Actual:** (a) The dimmed "▶ PLAY" label sits directly behind the rarity pearl and the level diamonds (◇◇ over "PLAY"), and the card labels and the shell peek stay readable. (b) In the shop, the selected buddy's name, description, level bar and upgrade button ("Dizzy the Disco Ball …", "150") show through behind the figure and the shell. The scrim alpha is too low for text-heavy screens, and the diamonds/pearl row falls exactly on the PLAY label. Fix: a stronger scrim (≥ 0.85) or blur, or fade the Start/stage layer out.
- **Screenshots:** `docs/art/audit/18b-shell-done.png` (art director, Start) and `docs/qa/bug-004-shop-opening-showthrough.png` (shop, DPR 1).

### BUG-005 · P2 · Loss screen: in-game HUD visible under the dimming (art audit item 2, verified)
- **Steps:** Play any round to a loss and let the reveal run.
- **Expected:** Only the loss overlay (score, record, best piece, replay, reveal strip) is readable.
- **Actual:** The game HUD (score pill, crown + record, chain row, next-piece frame) stays at roughly half brightness under the scrim. The HUD score ("501") sits right behind the reveal's pearl tally ("+31") at top left, and they overlap. The next-piece frame shows beside "12/21", and big objects in the jar stay bright enough to compete with the score. Fix: hide or fade the Game HUD when `GameOver` launches, or darken the scrim.
- **Screenshots:** `docs/qa/bug-005-reveal-hud-overlap.png` (DPR 2, "501" behind "+31") and `docs/art/audit/12-gameover.png`.

### BUG-006 · P2 · Game HUD: the hanging piece covers the chain row (art audit item 3, verified)
- **Steps:** Start a round. Aim anywhere between x ≈ 150 and 260 (the default spawn is at the centre), or equip any buddy.
- **Expected:** The 11-slot chain (DESIGN §13.1) stays readable. That is where the "?" goals and lit levels are shown.
- **Actual:** The hanging piece (spawn y ≈ 145 logical) and the buddy sit on the chain row (y ≈ 160). At the centre they hide slots 8–11. Bigger queued pieces (levels 3–4) and the Sea Queen's crown cover more. The piece is on the row for most of the round, so the chain's new-"?" burst happens under it.
- **Screenshots:** `docs/qa/bug-006-hanging-over-chain.png` and `docs/qa/bug-006-hanging-over-chain-queen.png`.

### BUG-007 · P2 · Game HUD: Sybil's two-piece preview frames overlap (art audit item 4, verified)
- **Steps:** Equip Sybil the Seer (`siri`, level I or III) → start a round → look at the top right.
- **Expected:** Two clean dashed frames (next and next-after) side by side.
- **Actual:** The small second frame (x ≈ 247–295 logical) overlaps the main frame's left edge. The main frame's left dashes are missing and its right edge is cut by the jar rim. At a glance it looks broken. (The producer's note said "Sybil/Vera"; the only two-piece preview is `siri` = Sybil the Seer.)
- **Screenshots:** `docs/qa/bug-007-siri-preview.png` and `docs/qa/bug-007-siri-preview-crop.png`.

### BUG-008 · P3 · Reveal: pearls/sand are hardly visible in a set-unlock round
- **Steps:** Play a round that unlocks a set (the time track reaches 200 merges, or the first level 8).
- **Expected:** The tally (UI.md §14.6) is readable before the set ceremony (DESIGN §13.4 order: score → catches → meter → bar → new set).
- **Actual:** In fast mode, the strip including the tally rows fades out (`R.newSet.stripFadeMs`) as soon as the bar has filled, while the count-up (600 ms) is still running. In the screenshot, 1.3 s into the reveal, only the set icon and the score remain, and the earnings of that round are never seen.
- **Screenshot:** `docs/qa/bug-008-newset-tally-hidden.png`.

### BUG-010 · P2 · Input: taps in the book are dropped when frames are slow
- **Steps:** Open the book on a slow device, or while frames take >350 ms (for example while pages bake at DPR 2 under CPU load). Tap the Buddies tab or the close X at its visual centre. Deterministic repro: `qa-screens.spec.ts` › "tryck i boken … 400 ms" makes every frame take 400 ms with a busy loop.
- **Expected:** Every short tap works, whatever the frame rate.
- **Actual:** Nothing happens, even on the third try. `Book.onUp` accepts a tap only if `this.time.now - down.t < SW.tapMaxMs` (350). `time.now` is the frame time, so when a frame boundary falls between down and up, `dt` is at least one frame. With frames over 350 ms, **every** tap is classed as a drag and dropped silently: tabs, close X, the shop and buddies all stop working. This was hit in the full suite (2 workers, DPR 2, Chromium at 4–6 fps in the book). Start and Game are not affected (they do not measure tap time). Suggested fix: measure `dt` with `p.upTime - p.downTime` (event time) and/or rely on the distance only.
- **Test:** the known-bug test above. `tapUntil`/`quickTap` in `qa-util.ts` let the other specs tap again, as a player would.
- **Screenshots:** `docs/qa/bug-010-tab-tap-dropped.png` (Buddies tab tapped, Sets still shown) and `docs/qa/bug-010-close-tap-dropped.png` (X tapped, book still open).

### BUG-011 · P3 · Upgrade bar: identical values on two levels
- **Steps:** Book → Buddies → select Theo the Thundercloud (`muller`) or Willow the Whale (`vala`).
- **Expected:** Each paid step (§16.3) shows what it improves (§16.4 "value per level").
- **Actual:** Theo shows "3 bolts / ↑ 3 bolts / 4 bolts": I→II costs 150 pearls and the bar promises no change. Willow shows "1× / ↑ 2× / 2×": II→III costs 700 + 20 and shows no change. The step does improve something, but not the parameter that the hint shows. `data/avatars.ts`: Theo I→II changes `shakeMul` 1.2→1.3 and `boltMs`, while `levelHint.param = 'bolts'` stays 3. Willow II→III changes `graceMs` 2500→2800, while `levelHint.param = 'uses'` stays 2. Fix: show the parameter that changes at each step, or put both in the hint. Route to the game designer or UI designer.
- **Screenshots:** `docs/qa/bug-011-upgrade-hint-muller.png` and `docs/qa/bug-011-upgrade-hint-vala.png`.

### BUG-012 · P3 · Book: pearl and sand counters collide at large balances
- **Steps:** Have 12 345 pearls → open Book → Buddies.
- **Expected:** Clear space between "12 345" and the sand icon.
- **Actual:** The gap is about 4 px at 5 digits. The counters use fixed x positions (`ECONOMY_UI.counters`: pearl text at 161, sand icon at 232), so a 6-digit balance overlaps the sand icon. Start's pills grow with their content and do not have this problem. Low priority (100 000 pearls ≈ 100 000 merges).
- **Screenshot:** `docs/qa/bug-011-upgrade-hint-muller.png` (top row).

---

## Suite results (phase 1)
- `npm test`: 225/225 green (222 before plus 3 in `tests/unit/qa-economy.test.ts`).
- `npm run e2e`, three runs in a row on the final tree: **77/77 green each time** (15.8 min, 15.8 min, 16.0 min; 2 workers). The total is the 56 existing tests plus 21 new `qa-*` tests, and includes 4 known-bug tests that fail as expected (BUG-002, BUG-003, BUG-001, BUG-010).
- Baseline run before the fixes: 49/56 with 7 timing failures under a shared CPU (see "Test fixes").

## Checked and found correct (no bug)
- **Economy (DESIGN §16):** Over 10 hook-driven rounds with real merges, pearls grew by exactly the merge count and matched the reveal tally. Sand = milestones (+3, pages +10) + shinies + 2 × level 10 + chains ≤3 capped at 3. Free shells were claimed at 120/400/1 150/1 900 from `mergesBaseline`, and `pendingBoxes` plus opened free shells = claimed. The first shell is always rare. Balances never went negative. A failed buy or upgrade changes nothing.
- **Shop:** Each type was bought with real two-tap input (prices 300/700 pearls and 50 sand deducted once). The pool was emptied (48 unique, no duplicates, no draw below the floor, types turn "empty" in the right order). Each rarity was upgraded I→II→III at the exact §16.3 cost, then stopped at III. With a full book, a free shell gives 10 sand and the shelf shows the gold book. The odds jars match the remaining pool through a whole collection (unit test `qa-economy.test.ts`).
- **Reload** mid-round (merges, pearls and record kept, runs counted once), mid-reveal (nothing paid twice), mid-shell-opening on Start and mid-purchase in the shop (the figure is owned, paid exactly once, not re-drawn).
- **Background/foreground** on Start, in the book and in the reveal: nothing changes, and there are no errors.
- **Migration:** A schema 1 file is wiped to a fresh schema 2 file. Partial schema 2 files (missing economy, settings or collection, duplicate or unknown avatars, locked `activeSet`) load, play and save cleanly.
- **Back (Escape)** everywhere, including a double press: the start with no layer does nothing, and the sheet, the opening, the book from all three cards, an awake shell (no purchase), mid-round (saved as `quit`) and the loss screen all respond correctly.
- **Language:** On a device set to `sv-SE` without `?lang`, everything is in English (Start labels, book, buddy names), following the decision of 2026-09-26. `?lang=sv` gives Swedish, and all Swedish sheet and Start labels fit. Buddy descriptions are ≤ 60 characters in both languages.
- **Settings sheet:** All four rows toggle across the full row width. Calm mode turns auto-drop off in the game, and aim line off means no line while aiming. The settings survive a reload.
- **Hit areas:** PLAY, Book, Buddies, Shop and the gear respond at their visual centre and 3 px inside every edge, and do not respond 3 px outside the hit area.
- **Sets:** All five can be selected in the book, and the next round uses that set's textures.
- **`?zoom=1`** at DPR 2: the canvas is 360×640, and drops land where aimed.

## Test fixes (tests were wrong, not the game)
Full run 1 at the start of this pass had 7 failures while the machine was shared (load average ≈ 10 on 4 cores; Chromium ran at 4–6 fps in the book). Root cause: the tests waited on **game time** (Phaser timers such as "seen for 2 s", the 1.2 s opening, reveal timings, the drop cooldown) with **wall-clock** timeouts, and some fired hook drops faster than the game-time cooldown. That piled objects over the danger line and ended the round early. Fixes: longer timeouts on the waits that depend on game time (`economy`, `friends`, `polish`, `sets`, `startv2`). `play.spec` and `special.spec` now wait for the next hanging piece before the next hook drop. `sets.spec` "mid-sequence" now asserts that the tally is not done and that at most one flyer has landed, instead of `landed === 0`, which a single frame over 240 ms could break. On an idle machine all of these passed before the change as well.

## Backlog S3 (done, not committed)
Renamed the obsolete Start v1 screenshots and updated the specs that write them: `start-shelf` → `start-v2-book-fresh` (sets.spec), `start-four-icons` → `sheet-aim-on` and `start-aim-off` → `sheet-aim-off` (aim.spec), `start-settings-off` → `sheet-all-off` (play.spec), `shelf-box` → `start-v2-free-shell` (friends.spec). `UI.md §16.1` still mentions `start-shelf.png` as the historical "before" image, and that is left as it is.

# Player Welfare & Child Safety Policy

Owner: Player Safety Advisor (holds veto on dark patterns aimed at children). Audience 7+, PEGI 7 target, EU/Sweden first, Android first.
Sources and legal detail: `research/marknad-engagemang-regler.md` (§2 psychology, §3 regulation). Claims marked there as unverified must be checked against primary text (pegi.info, Google Play policy pages) before store submission.
This document is **binding** on GDD and all content packs. A feature that conflicts with it needs a written exception signed off here.

**Goal:** the child *wants to come back* for years, and *can stop* when it is time. We measure return over weeks and self-reported fun, never session length.

## 1. Allowed vs. banned mechanics

| Allowed (the fun engine) | Banned (the compulsion engine) |
|---|---|
| Random loot from monsters, chests, bosses that you *play* for | Anything random that can be bought: loot boxes, gacha, mystery chests, paid rerolls/crafting |
| Visible pity / bad-luck protection counting *play time or kills* | Pity or progress that decays or resets while the player is away |
| Surprises: Gilded Gremlin, secret levels, mystery eggs, elite packs | Surprise frequency tuned per player to maximise playtime (no behavioural personalisation) |
| Daily/weekly goals that bank (max 3) and never punish a missed day | Streaks that reset, login calendars, "don't lose your progress!" framing |
| Weekly boss with a banked first-kill bonus | Expiring lockouts, limited-time items/events, countdown timers of any kind |
| Rested Glow (bonus for breaks) | Energy/stamina, wait-or-pay timers |
| Premium purchase, paid expansions, known-content cosmetics, real-currency price | Premium/virtual currency, time- or quantity-limited offers, pay-to-win/progress |
| Juice: hitstop, beams, sounds tied to the player's own actions | Slot-machine UI: spinning reels, near-miss reveals, "SO CLOSE!" text |
| Local leaderboards, Hall of Embers memorial | Social obligation ("your friends need you"), guild duties |
| Optional auto-attack (accessibility) | Idle/AFK auto-play that progresses without the player, autoplay of next run |
| | Ads of any kind (incl. rewarded ads), "revive for money/ad" |
| | Direct purchase exhortations to children ("Buy now!", "Ask a parent to...") |

## 2. Reward pacing rules
1. Variable rewards are fine **only** when earned by play, never bought, never gated on real-world time.
2. **No simulated near-misses.** The outcome is decided before any animation starts; the reveal never shows a better result "just missed" (no reel landing next to Legendary, no beam that flickers toward a higher rarity).
3. Loot beam, drop sound and card always match the *true* rarity from the first frame. No "fake-out" upgrades.
4. Crafting (Kindling, Cauldron) shows odds before commit; failure is shown plainly in one step. No dramatic "almost!" sequences.
5. Golden moment card: after combat, skippable with one tap, at most once per drop, no chained reveals.
6. Pity counters are visible, count active play only, and are never reduced by absence.
7. Reward frequency is designed in data and identical for all players (seeded RNG, no adaptive retention tuning).
8. No reward is granted for simply opening the app.

## 3. Session design
- **Natural stopping points** every 3–10 min: end of zone/Lightwell/boss shows a summary screen with *Continue*, *Return to town* and a calm "Good place to rest" line. The next run never auto-starts.
- **Save anywhere, lose nothing:** autosave on zone transition, loot pickup, level-up and on app backgrounding. Interrupted Lightwells award partial progress and can be resumed.
- **Auto-pause** when the app loses focus (call, notification, screen off). Single-player never continues without the player.
- **Rested Glow:** accrues while offline, fills in ~8–24 h (to be tuned), capped at +100% XP for ~20 min of play. Framed positively ("You're well rested!"), never as loss ("Rested XP is being wasted"). No reminder when it is full.
- No cliffhangers engineered to block quitting (e.g. a timed bonus that starts right as a session ends).
- Long-term goals (level 200, Mythics, Named weapons, constellations) are reachable through steady play; nothing requires daily attendance.

## 4. Hardcore mode ("Last Flame") and kids
- **Softcore is the default** and the only mode pre-selected. Softcore death = respawn at checkpoint, lose nothing.
- Hardcore is **opt-in** via a separate toggle, with a clear, illustrated warning ("If this hero falls, they cannot come back.") and a hold-to-confirm step. Recommended: unlock after finishing the story once on any tier.
- A parent can hide Hardcore in parental settings.
- **Interruption safety:** app backgrounding, crash, phone call, low battery or (future) disconnect must never kill a hardcore hero. On resume the hero is safely returned to the zone entrance or town.
- On death: calm, non-graphic memorial into the Hall of Embers. Offer "Carry the ember on": the character continues as a softcore copy (keeps gear, loses hardcore frame). Losing years of play to one mistake must remain a choice, not a trap.
- No purchase, ad or reward is ever offered at a death screen.

## 5. Parental controls
Accessed via a parental gate (adult-level question, not just a tap) from the main menu settings.
- **Purchase lock: ON by default.** Every purchase (demo unlock, DLC, cosmetics) passes the gate *and* the platform's own purchase confirmation.
- **Play-time reminders: opt-in.** Parent chooses interval (30/45/60/90 min). Reminder is a friendly in-game card at the next safe moment, never mid-boss.
- **Optional daily limit:** at the limit the game finishes the current encounter, saves, and shows a goodbye screen. Hardcore heroes are never put at risk by the limit.
- Hide Hardcore, disable leaderboards (and future online features), reduce flashing/shake.
- Settings stored locally, protected by the gate; no account needed.

## 6. Data and privacy
- Offline-first. No accounts, no login, no email, no cloud identity at launch. Saves are local (platform backup allowed).
- **No third-party analytics, attribution, advertising or crash SDKs** (no Firebase Analytics, Adjust, AppsFlyer, Unity Ads, etc.). Google Play Console vitals (platform-level) only.
- No advertising ID (AAID), no location, no contacts, no microphone/camera. Declare `AD_ID` removal in the manifest.
- Requested Android permissions at launch: none beyond what Godot needs to run. No `POST_NOTIFICATIONS`.
- Character names are free text but never leave the device. Any future online display uses generated names (see §8).
- Privacy policy (English + Swedish) states the above in plain language for parents; Data Safety form says "no data collected".
- Any future telemetry: first-party, anonymous, aggregate, opt-in by parent, reviewed here first.

## 7. Notifications policy
- **None at launch.** The app does not request notification permission.
- Never: "come back" messages, rested-full alerts, event or offer notifications, anything at night.
- The only future exception: a parent-enabled, local reminder the parent explicitly configures (e.g. "Play time is over"). Default off.

## 8. Future multiplayer safety requirements (gate before any online feature)
Online leaderboards, co-op, trading or sharing builds must not ship until all of these are met and reviewed:
1. **No open chat**, no free-text anywhere visible to others (names, guild names, item names, messages).
2. Communication = preset emotes and contextual pings only ("Go here", "Help!", "Nice loot!").
3. Friends only via **friend codes** exchanged outside the game or in local play; no stranger discovery, no public lobbies for under-13s by default.
4. Display names are generated from a safe word list.
5. **Report and block** on every other player, reachable in two taps; reports reviewed by a human with a defined SLA.
6. No trading or gifting between players who are not friends; no real-money value for items, ever.
7. Parent can disable all online features; online is **off by default**.
8. Re-assess DSA art. 28, GDPR (consent for under-13s in Sweden) and Google's July 2026 policy on anonymous chat before launch; update the privacy policy and Data Safety form.
9. Server-side anti-cheat must not collect more personal data than needed.

## 9. Pre-release compliance checklist (Google Play Families + PEGI)
**Google Play (Families / Teacher-approved readiness)**
- [ ] Target audience set in Play Console (includes under-13); Families policy requirements read against primary text.
- [ ] No ads SDKs at all (so no Self-Certified Ads SDK needed); no AAID; `AD_ID` permission removed.
- [ ] Data Safety form: no data collected/shared; matches actual build (verify with a network capture + dependency audit).
- [ ] Privacy policy URL live, plain language, covers children.
- [ ] No simulated gambling; no reward reveal resembles a slot machine (screenshot review of every reward UI).
- [ ] All IAP behind parental gate + platform confirmation; prices in local currency; no in-gameplay store prompts.
- [ ] Store listing, icon and screenshots contain no purchase exhortation or misleading content; appropriate for 7+.
- [ ] Permissions list reviewed; no notifications, location, mic, camera.

**PEGI / IARC (June 2026 criteria)**
- [ ] No paid random items (else PEGI 16+).
- [ ] No time- or quantity-limited offers (else PEGI 12+); no paid battle pass.
- [ ] No login streaks or resetting daily rewards; verify on pegi.info how daily goals are classified.
- [ ] No NFT/blockchain.
- [ ] Content review for PEGI 7: non-realistic violence against fantasy creatures only, no blood/gore (Snuffed "rekindle and flee"), fright level of bosses/music/Hush checked; no crude language in item or lore text.
- [ ] IARC questionnaire answered honestly for in-game purchases ("In-game purchases" descriptor applies if DLC/cosmetics exist).

**EU consumer law / Sweden**
- [ ] No direct exhortations to children to buy (UCPD Annex I p.28); copy review of every store/demo-end string.
- [ ] CPC virtual-currency principles: n/a (no currency) - confirm.
- [ ] Watch Digital Fairness Act (expected Q4 2026) and Swedish loot-box debate; re-run this checklist per release.

**Game-level welfare**
- [ ] Every item in §1 banned column verified absent (grep content packs for timers, `expires`, `streak`).
- [ ] Auto-pause on focus loss, autosave on backgrounding, hardcore interruption safety tested on device.
- [ ] Parental gate, purchase lock default ON, reminders/limit tested.
- [ ] Playtest with children (with parental consent): "Do you want to play again tomorrow?" and "Was it easy to stop?".

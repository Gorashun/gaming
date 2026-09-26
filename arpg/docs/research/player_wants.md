# What ARPG players want — and how Wickwright delivers it ethically

*Author: R&D (rnd-researcher) with the player-safety lens. Date: 2026-09-26. Language: English (owner request).*
*Informs GDD v2.2 item 27 ("decisions informed by player_wants.md"). Binding constraints: `design/PLAYER_WELFARE.md`.*
*Juice timings are already specced in `design/UI_UX.md` §10; this doc validates them rather than repeating them.*

**Method and caveats.** About 60 web searches across GDC Vault, dev posts, wikis, reviews, Steam/Blizzard/Last Epoch forums and research papers.
The proxy blocked page fetches for many sites (gamedeveloper.com, reddit, pcgamesn, resetera, diablowiki, sourcegaming),
so some claims rest on search-engine summaries of those pages. Those claims are marked **[S]** and should be spot-checked before anyone quotes them externally.
Anything without a source is marked **(estimate)**. References `[n]` point to the list at the end.

---

## 0. TL;DR

1. What players ask for most, across games: **fewer but better drops, and drops that change how you play**. Then *no inventory chores*, cheap respec, a way to target the item you want, and **no monetization pressure**. Diablo 4's Loot Reborn [7][8], D3's Loot 2.0 [1][2], the boring-uniques backlash [9][10], and the Diablo Immortal / Torchlight Infinite / Undecember monetization anger [25][26][28][29] all point the same way.
2. The "dopamine hit" framing is scientifically weak [41]. The robust findings are these: **positive surprise relative to expectation** drives learning and pleasure (reward-prediction error [40]), and **competence + autonomy (+ relatedness)** predict both enjoyment and wanting to return [38]. Design for *good surprises inside a predictable, fair frame*. Never design for *almost-wins*: near-misses raise the urge to keep going even though players rate them as unpleasant, which is the definition of a compulsion lever [39].
3. The long-term retention model that works without dark patterns: **deep systems + predictable fresh content + permission to leave**. Chris Wilson's PoE talk: players *will* quit, so give them a reason to come back rather than grinding them into burnout [5][6]. Grim Dawn (offline, no MTX, cheap respec) and Eternium (no energy, no paywalls, 4.8★) show the premium/fair model earns loyalty [18][30].
4. For Wickwright, the highest-leverage additions are:
   - an **account-wide Codex** that turns loot into collection;
   - **build-enabling uniques** with one-line, kid-readable effects;
   - **target farming** that respects play time;
   - **loadouts**;
   - **secrets per zone**;
   - an **assist mode without shame**;
   - **never-expiring seasons ("Ember Cycles")**.
   All 30 recommendations are in §7.

---

## 1. Top player requests & complaints (ARPG, PC + mobile)

| Topic | What players say | Evidence | Wickwright status |
|---|---|---|---|
| Loot quality vs quantity | "Sifting hundreds of items to find one" is a chore. The fix is fewer affixes that are more potent and less niche | D4 S4 Loot Reborn [7][8]; D3 Loot 2.0 "quality over quantity" [2] | GDD rarity weights are fine. The *affix pool* size (owner item 15) is a risk: keep pools big, keep each item's affixes few and clear |
| Uniques/legendaries | Uniques "not exciting enough… players don't feel good when they drop"; conditional affixes are "random and confusing" | D4 dev team [9]; players [10] | 30+ uniques and 40+ powers planned → give each one a *verb* (§2) |
| Build diversity | Complaints about few viable builds early and late (PoE2) [64]. Last Epoch is praised as "PoE depth, Diablo accessibility" | [64] + comparison articles in §3 | GDD: ≥3 viable builds/class, bot-verified ✔ |
| Respec | PoE2 respec cost called "a brick wall" right after they tell you to experiment. D3's free respec "didn't decrease anyone's enjoyment". D4 is free until lvl 10, then cheap | [20] [21] | Free until lvl 20, then cheap ✔. Add loadouts (rec. 9) |
| Endgame variety | PoE: "multiple overlapping axes of randomness" + procedural content [5] | [5] | Lightwells + keyed Deepdark + tiers ✔. Add modifier "Omens" (rec. 16) |
| Seasons | D3 seasons = a fresh start + a guided Season Journey [22]. D4 players resent being forced to abandon eternal characters to see seasonal content [23] | [22][23] | Not planned → rec. 13 (never-expiring cycles) |
| Trading | PoE: economic integrity over revenue [66]. Trade = scams/RMT risk | [66] (estimate for kid risk) | No trading at launch (welfare §8) ✔ |
| Crafting determinism | LE crafting "community-revered", but "nested RNG" frustrates; D4 removed the fail chance from Masterworking after PTR feedback | [16] [8] | Upgrade never fails ✔; Kindle shows odds ✔; Cauldron never destroys ✔ |
| Inventory/stash | D4: bag full in 1–2 min, forced town trips; too few tabs; "gem tab" the #1 QoL ask; players hate inventory Tetris | [11][12] **[S]** | 1 cell per item ✔; Legendary+ overflow → mailbox ✔. Add material bag + pet ferry (rec. 6–7) |
| Loot filters | NeverSink's filter is the "unofficial default" in PoE (500+ rules, 7 strictness levels) — players want strictness presets, not a rules editor | [13] | Hide Common after lvl 15 ✔. Add presets (rec. 5) |
| Target farming | LE Circle of Fortune: players want to *choose* rewards; S5 moved from reroll-a-random-pool to direct picks | [14] | Curio Cart (slot-targeted) ✔. Add boss-specific wish (rec. 4) |
| Difficulty | Hades God Mode: −20 % damage, +2 % per death, cap 80 %, offered "without judgment" | [34] | Tiers ✔. Add assist (rec. 23) |
| Mobile controls | Diablo Immortal touch controls = "best in a game of this scale": auto-target basic, press-and-swipe skills; free-aim combos still awkward. Some players prefer tap-to-move (Eternium) | [27][30] | Joystick + auto-aim ✔. Add tap-to-move option (rec. 24) |
| Offline | LE offline mode praised; server dependency is a common grievance. Grim Dawn "fully offline, no MTX" is a headline review reason | [17][18] | Offline-first ✔ → make it a store-listing message (rec. 25) |
| Monetization anger | Diablo Immortal: iOS Metacritic user score 0.6, "$110k to max". Torchlight Infinite: gacha traits, paywalled inventory. Undecember: review-bombed for P2W | [25][26][28][29] | Premium, no gacha ✔ — this is a *marketing asset*, not only a constraint |
| Performance | Estimate: the #1 mobile-review complaint class is heat/battery/frame drops on mid-range phones | (estimate; see `research/teknik.md`) | QA budget per ARCHITECTURE ✔ |

## 2. What makes loot exciting (and what is only a slot machine)

**Mechanisms that work, with sources:**
- **Anticipation + positive surprise.** Dopamine neurons fire for *better-than-expected* outcomes, and that signal transfers to reliable cues, such as the sound of an elite dying [40]. Implication: make the *cue* trustworthy, e.g. the legendary clang and beam, which D3 pairs with a minimap star [49]. The cue itself becomes the joy.
- **Item identity > numbers.** D4 had to rework "almost every unique" because stat-stick uniques failed [9]. PoE-style support gems (e.g. "Chain", "Spell Cascade") are loved because they change *behaviour*, not just size [65].
- **Chase items with a visible ladder.** D2's rune ladder runs from El to Zod (Zod ≈ 1:5171 at area level 81+) [62]. A long ladder gives both constant small wins and a legendary goal. Wickwright has Mythic/Named for this role.
- **Smart loot + pity.** D3: about 85 % of drops roll for your class [3]; the legendary pity timer (~2 h) counts only "could-have-dropped" events [4]. Wickwright: 75 % smart loot and a visible pity ≤45 min — already better than D3 on transparency.
- **Target farming.** LE Prophecies [14], D3 Kanai's Cube / set-gear guarantees [22].
- **Collection conversion.** D4 Codex of Power: salvaging a legendary *learns* its aspect account-wide, and a better roll upgrades the entry [24]. Grim Dawn blueprints are learned permanently [19]. Every drop now matters twice: as gear, and as a Codex entry.
- **Transparency of odds.** Players tolerate RNG they can see (LE forging, D4 no-fail masterwork after feedback [8][16]).

**The slot-machine critique.** Vampire Survivors' chest was deliberately modelled on a casino jingle and animation by a developer from the gambling industry [33] **[S]**, [32]. It works, and it is exactly what our welfare rules forbid: spinning reveals and near-miss framing [39].
*Ethical alternative (keep the joy, drop the reel):*
1. Outcome decided before the animation.
2. True rarity shown from frame 1 (beam colour, chest glow colour).
3. Anticipation built by *physical* effects (lid pop, spill arc, sound), never by cycling candidates.
4. Everything skippable.

`UI_UX.md` §10 "Chest: anticipation shake 250 ms" is fine **only if the chest already glows its true highest rarity during the shake**. Add this to the spec (rec. 26).

## 3. Skill systems players love, and long-grind rewards

**Models compared.**
- **PoE gems:** 200+ skills × 180+ supports. Maximum expression, but brutal for newcomers [65].
- **Last Epoch:** each skill has its own tree, skills level by *use*, up to 5 specialised skills; praised as deep yet approachable, with complaints about slow levels 10–20 [15].
- **D4:** a simple tree plus Paragon boards (moderate depth).
- **Hades / Vampire Survivors / Archero:** 3-choice level-up picks inside a run [31][32]. Great for kids and short sessions.

**What players love, and how it maps to GDD items 7 / 25 / 27:**
1. **Modifiers that change behaviour, not +x %** (PoE supports [65], LE nodes [15]). GDD 7 already does this with 2 behaviour modifiers per skill. Rule: every modifier must change the *visual* too, so a 7-year-old sees the difference.
2. **Synergy "click" moments.** The survivors-like loop "lives or dies on the moment accumulated choices suddenly click" [32]. Make synergies discoverable and *announced* (rec. 12).
3. **Mastery by use.** LE [15] and our weapon proficiency + skill mastery (GDD 19, 25). Risk: the LE complaint about slow late levels. Keep mastery 1–10 fast (a first-week reward) and make 15/20 the "weeks" goals.
4. **Capstones.** A capstone should *redefine* the skill, e.g. "Bell Toll now leaves a ringing zone" (estimate from PoE/LE keystone reception).
5. **Cheap respec + saved loadouts** [20][21]. Experimentation is autonomy, the SDT need that predicts return play [38].

**Rewarding long grinds.**
- *Visible progress* (D3 Paragon, D4 Codex upgrades [24]).
- *Meaningful milestones*: GDD's 5/10/15/20 mastery milestones are exactly right.
- *Catch-up*: D3 seasons ramp fast [22]. For alts, add account-wide XP heirloom boosts.
- *Account-wide collections*: Codex, wardrobe, pets.
- *A guided checklist*: D3 Season Journey chapters with cosmetic rewards [22].
- Quantic Foundry: ARPG-typical motivations are **Power** (grow stronger), **Completion** (collect everything), **Challenge**, and **Destruction/Action** [37]. Serve each with one system: stats/Brightness, Codex, tiers, juice.

## 4. Retention without dark patterns

- **Session shape.** Median mobile session ≈ 5–6 min; action and RPG genres average 40–46 min **[S]** [61]. Archero's run of 10–50 rooms is the model for "one run = one sitting" [31]. We have Lightwells of 3–6 min, zone summaries, and no auto-start. Keep it.
- **Reasons to come back that are not obligations.**
  - PoE: predictable content drops and deep systems [5].
  - Hades: "every run counts", with story advancing even on death [35][36].
  - DRG and Halo Infinite: passes that never expire, so players "come back because they're excited, not because they have to rush" [56][57].
  - Criticism of DRG: a slow, never-expiring pass can feel like "nothing to show" [56]. So never-expiring still needs a good pace.
- **Daily/weekly structures.** Bankable, optional, never streak-based (welfare §1). The D3 bounties-style "3 bounties, bank up to 3" pattern is compatible.
- **Collections.** Pets (Torchlight 2's pet that ferries loot to town was beloved [58]), transmog, Codex, a journal of secrets.
- **Achievements.** They can support intrinsic motivation when they celebrate mastery/exploration, but risk the overjustification effect when they pay out power [60]. Rewards: titles, frames, lore — not stats.
- **Secrets & discovery.** D2's Secret Cow Level and D3's Whimsyshire (unicorns and teddy bears, reached via a crafted staff or Rainbow Goblin portals) are the franchise's most-loved easter eggs [59]. This is kid gold, and on-brand with our Candy Crypt / Tea Party.
- **Social, safe for kids.** Sky: Children of the Light gates chat behind friendship and relies on collectible emotes [55]. For us (welfare §8): friend codes, preset emotes/pings, no free text.
- **Events.** Welfare bans limited-time events. The ethical form: *in-game* cycles (the moon cycle already in the GDD), or permanent "event zones" that rotate a *featured bonus* which banks.

## 5. Juice & feedback — validation of UI_UX.md §10

| Element | Source finding | Our spec | Verdict |
|---|---|---|---|
| Hitstop | 40–80 ms typical; freeze *attacker + target*; scale with damage [45]. Smash scales hitlag with damage, cap 30 frames [46]; Sakurai treats hitstop as central to impact [47] **[S]** | 50 / 80 ms, AoE `min(80, 30+5n)`, never on the player | ✔ in range. Keep the "applied once" rule, or mass AoE will stutter |
| Screen shake | Vlambeer's ~30 tricks (shake, hit pause, permanence, bigger bullets) [44]; trauma²-based noise [45] | trauma², Perlin, 3 levels, slider | ✔. GAG wants shake reducible [51] ✔ |
| Particles/tweens/sound | "Juice It or Lose It": the same game feels alive through squash, particles, sound [43] | death pop, squash, spill arcs | ✔ |
| Physics | D3's post-death ragdoll/corpse physics sells weapon weight [63] **[S]** | death = spark pop (PEGI 7, no corpses) | Replace ragdoll with a *directional* spark burst + knockback in the hit direction (rec. 26) |
| Loot beam & sound | D3 legendary = loud clang + coloured beam + minimap star [49] | Legendary/Mythic spec ✔ | Add a **distinct audio signature per rarity**, heard before the item is seen |
| Damage numbers | D3 abbreviated late-game numbers but kept "1,000,000" over "1M" and "1,000M" over "1B" because they feel better [48]; D4 S6 stat squish failed (quintillions) **[S]** [48] | merge per target, max 24 | Add a **number-inflation budget** (rec. 27) |
| Haptics | Android: prefer "rich and clear" over buzzy; "less is more", or users turn haptics off [50] | UI tap 10 ms, hurt 40 | ✔. Add crit/legendary patterns with a toggle |
| Slow-mo on Legendary | (no source; estimate) risks spamming at high drop rates | 0.3× for 350 ms | Only for the *first* Legendary per zone; honour reduced motion ✔ |

## 6. Kids 7–12 vs adults; accessibility

**Kids 7–12**
- *Control and personalisation*: avatar creation is driven by self-expression, alter egos, social needs and performance [53].
- *Dress-up/role-play* is very popular [54].
- *Humour, collecting, secrets* (estimate; Carla Fisher's developmental guidance on reading level, motor skills and age bands [52]).
- *Short, clear goals*.
- Ofcom 2026: 53 % of gaming 8–17s spent money, driven by customisation, **limited-time offers** and progress [54]. That is exactly the pressure we remove.

**Adults**
- Build theory-crafting, efficiency, transparency (odds, numbers), challenge tiers, Hardcore, leaderboards.

**One game for both.** Layer the depth:
- *Icon-first surface*: Simple mode, Best gear, auto-spend (GDD 11).
- *Expert overlays*: detailed tooltips, numbers, odds.
- Same content, two lenses.
- Hades shows that an assist mode doesn't cost you the core audience [34].

**Accessibility (GAG basic tier [51]).**
- Remappable/relocatable controls.
- Text size.
- No colour-only information (we use colour + frame shape ✔).
- Adjustable difficulty.
- Subtitles with background.
- Intermediate tier: one-handed play, practice area, aim assist, game speed.
- Mobile: large, well-spaced targets and adjustable sensitivity [51].
- Read-aloud via TTS is already in UI_UX ✔.

## 7. Thirty prioritised recommendations

Priorities:
- **P0** = before the M2 Act-1 playtest.
- **P1** = before launch.
- **P2** = post-launch/expansion.

Welfare column: **OK** (compliant), or ⚠ = conflicts in its naive form; the ethical version described is the one we build.

| # | What (concrete) | Why / evidence | Pri | Owner | Welfare |
|---|---|---|---|---|---|
| 1 | **Codex of Light**: salvaging a Legendary/Unique learns its power account-wide. A higher roll upgrades the entry. Imprint any learned power onto an item at the Runecarver | Every drop matters twice; loot becomes collection (D4 Codex [24], GD blueprints [19]) | P0 | systems-designer | OK |
| 2 | **Affix hygiene**: max 4 affixes on Rare/Legendary; no conditional affixes ("while X within 3 s…"); every affix has a tag the build can hook | "Chore" of sorting; conditional affixes "random and confusing" [7][10] | P0 | systems-designer | OK |
| 3 | **Every Unique/Legendary power = one verb change**, with a one-line kid description + icon (e.g. "Your bell rings twice") | D4 uniques "not exciting" [9]; behaviour > numbers [65] | P0 | systems-designer + game-writer | OK |
| 4 | **Wish at the Lantern Shrine**: before a boss, pick 1 of its uniques as your "wish". That unique gets ×3 weight on that boss, plus duplicate protection. Boss loot lists are always visible | Target farming loved (LE [14]); transparency | P1 | systems-designer | OK (earned, deterministic weight shown) |
| 5 | **Loot filter presets** (Kid: "only upgrades & shiny" / Normal / Strict / Custom rules) with a live preview | NeverSink = de-facto default with strictness levels [13] | P1 | ui-ux-designer | OK |
| 6 | **Pet ferry**: pet carries salvage/sell loads to town (with a 3-s cute animation) and returns gold + mats | Torchlight 2's most-loved QoL [58]; inventory rage [11] | P0 | gameplay-programmer | OK |
| 7 | **Material bag** (mats and gems never use slots) + auto-sorted stash tabs (weapons/armour/jewellery/pets/cosmetics) | D4 "gem tab" #1 ask, few tabs [11][12] | P0 | ui-ux-designer | OK |
| 8 | **Free skill-tree respec forever**; Brightness free (GDD) ✔; mastery never refunded or lost | PoE2 backlash vs D3 free respec [20][21] | P1 | systems-designer | OK |
| 9 | **3 saved loadouts** per hero (skills + modifiers + gear set), swap in town | Experimentation = autonomy [38]; D4 loadout-manager requests (estimate) | P1 | ui-ux-designer | OK |
| 10 | **Mastery pacing**: ranks 1–10 in the first ~3 h of use per skill; 15/20 are multi-week goals; milestone 5 = first behaviour change | LE's late-level pace complaints [15]; GDD 25 | P0 | systems-designer | OK |
| 11 | **Visible modifiers**: each behaviour modifier/capstone changes VFX and has a 3-s looping preview in the tree | Kids see differences; readable combat pillar | P0 | art-3d + ui-ux | OK |
| 12 | **Synergy discoveries**: when two tags combine (e.g. Frost + Bell) show a one-time "Synergy found!" card, logged in the Codex | The "click" moment is the survivors-like core [32]; discovery | P1 | systems-designer | OK |
| 13 | **Ember Cycles** (seasons): a fresh-start hero with a new rule and a guided chapter list. Rewards are cosmetic/Codex entries account-wide. **Old cycles never close** (switchable like DRG/Halo); cycle heroes merge into the main realm when done | Fresh-start pull [22]; D4 eternal-realm frustration [23]; no expiry [56][57] | P2 | studio-producer + systems | ⚠ timed seasons = FOMO → never-expiring version is OK |
| 14 | **Wickbearer's Path**: a permanent 4-chapter goal checklist per act/tier with a cosmetic per chapter | D3 Season Journey frames play [22] | P1 | systems-designer | OK |
| 15 | **Catch-up / Heirloom Glow**: after your first hero hits lvl 60, new heroes get +50 % XP to 60, and Codex + wardrobe are shared | Alts without grind repetition [22][24] | P1 | systems-designer | OK |
| 16 | **Omen board**: 12 Lightwell modifiers, *all always available*; player picks 1–3 for +loot/XP. "Featured omen" rotates on the in-game moon cycle, and its bonus banks | PoE overlapping randomness [5] | P1 | systems-designer | ⚠ weekly real-time rotation = FOMO → in-game cycle + banking is OK |
| 17 | **Bounty board**: 3 bounties per town; a new one appears per ~30 min of *active play* (bank max 3) | Optional structure that respects absence | P1 | systems-designer | ⚠ daily-login bounties → play-time refill is OK |
| 18 | **One secret per zone** + a Journal of Secrets (silhouette hints after 3 found); Act 1 ships ≥5 secrets incl. the Tea Party | Cow Level / Whimsyshire love [59]; kid discovery | P0 | systems + game-writer | OK |
| 19 | **Wardrobe/transmog**: every appearance found is unlocked account-wide; dyes; lantern flame colours | Kids' avatar self-expression [53][54] | P1 | art-3d-designer | OK (no paid random cosmetics) |
| 20 | **Pet personalities**: each pet has a name, a quirk bark, and a "trick" learned at levels 5/15/30 | Collection + attachment for kids [53]; Torchlight pets [58] | P1 | game-writer + art | OK |
| 21 | **Deeds** (achievements) pay titles, frames and lore pages — never power. Grind deeds hidden under "More" | Overjustification risk [60] | P1 | systems-designer | OK |
| 22 | **NPCs remember you**: barks react to deaths, bosses, Uniques found, secrets (Hades-style) | "Every run counts" narrative [35][36] | P1 | game-writer | OK |
| 23 | **Lantern's Blessing** assist: −20 % damage taken, +2 % per death, cap 60 %; off in Hardcore; no badge of shame | Hades God Mode [34]; GAG difficulty [51] | P0 | systems-designer | OK |
| 24 | **Control schemes**: default = joystick + auto-target basic + press-drag skills with a cancel ring (DI model). Option: tap-to-move/attack (Eternium) | DI controls praised [27]; tap-to-move praised [30] | P0 | gameplay-programmer + ui-ux | OK |
| 25 | **Store listing promise**: "Pay once. No ads. No loot boxes. No energy. Plays offline." (parent-facing, no exhortation) | GD/Eternium loyalty [18][30]; DI backlash [25] | P1 | studio-producer + legal-counsel | OK (verify UCPD wording) |
| 26 | **Juice amendments**: chest glows its true top rarity from frame 1; distinct audio per rarity; directional spark burst + knockback in the hit direction; Legendary slow-mo only for the first per zone | Honest cues [40][49]; Vlambeer [44]; near-miss ban [39] | P0 | audio-designer + art-3d | ⚠ fixes a latent near-miss risk in the chest spec |
| 27 | **Number-inflation budget**: tune so lvl-200 hits stay ≤ ~10 M (estimate); formatting rules (no "1B"); an option to show only crits | D3/D4 inflation and squish [48] | P1 | systems-designer | OK |
| 28 | **Haptic set**: crit 15 ms click, Legendary 2-pulse, boss telegraph soft ramp; master toggle + intensity | Android haptics principles [50] | P1 | gameplay-programmer | OK |
| 29 | **Accessibility pass (GAG basic + mobile)**: one-handed layout, colour-blind modes, text 100–200 %, reduced motion, read-aloud, practice dummy in town | GAG [51] | P0 | ui-ux-designer + qa-tester | OK |
| 30 | **Safe social (post-launch)**: friend-code co-op, preset emotes/pings, "gift to friend" limited to duplicates, no trading market | Sky model [55]; PoE economy [66]; welfare §8 | P2 | player-safety + gameplay-programmer | ⚠ open trade/chat banned → friend-code + presets is OK |

**Top 10 for the M2 playtest:** 1, 2, 3, 6, 7, 10, 18, 23, 24, 26. Each has a playtest question: "Did any drop surprise you?", "Did you ever feel you had to go to town?", "Did you find a secret?".

## 8. Requests that conflict with welfare rules, and what we do instead

| Player ask / genre norm | Why banned (welfare) | Ethical alternative |
|---|---|---|
| Timed seasons / limited event cosmetics | FOMO, PEGI limited-offer criteria | Ember Cycles that never close (rec. 13); in-game moon events |
| Daily login rewards, streaks | Resetting streaks banned (§1) | Play-time bounty refill, banked (rec. 17); Rested Glow |
| Casino-style chest reveal (Vampire Survivors) | Near-miss / slot UI [33][39] | True-rarity glow, physical anticipation only, skippable (rec. 26) |
| Real-time weekly rotations | Absence punished | All modes permanent; the featured bonus banks (rec. 16) |
| Player trading / auction house | Scams, RMT, kids' safety; D3 even removed its AH [1] | Personal Codex + wish targeting (rec. 1, 4); friend gifting post-launch (rec. 30) |
| Global leaderboards with chat/names | §8 online gate | Local boards + Hall of Embers; parent can hide |
| "Come back" push notifications | §7 | NPC barks and a next-goal card *inside* the session |

**Curio Cart (GDD 29) check.** Spending *earned* Hushmarks on a slot-targeted random item resembles D3's Kadala. It stays compliant with welfare §1 only while:
1. Hushmarks are never purchasable, including indirectly via DLC bundles.
2. The reveal is instant and shows the true rarity.
3. There are no "hot item" timers.

Keep it on player-safety's watch-list for the PEGI questionnaire.

**Forge count-up (UI_UX §6).** The value counts up to the rolled result. It must never display the affix max as a target line during the count, or it reads as "so close".

---

## Sources
1. GDC 2015, Mosqueira — Diablo III's Road to Redemption: https://www.gdcvault.com/play/1021776/Against-the-Burning-Hells-Diablo
2. Reaper of Souls / Loot 2.0: https://en.wikipedia.org/wiki/Diablo_III:_Reaper_of_Souls
3. D3 Smart Loot (85 %): https://www.diablowiki.net/Smart_Loot
4. D3 Legendary pity timer: https://www.diablowiki.net/Legendary_Pity_Timer
5. GDC 2019, Chris Wilson — PoE played forever: https://www.gdcvault.com/play/1025784/Designing-Path-of-Exile-to · https://gdconf.com/article/see-how-path-of-exile-was-built-to-be-played-forever-at-gdc-2019/
6. Talk discussion ("reason to quit before burnout") [S]: https://www.resetera.com/threads/chris-wilson-gdc-talk-designing-path-of-exile-to-be-played-forever-economy-and-development-of-gaas.111227/
7. D4 Loot Reborn rationale: https://www.gamespot.com/articles/how-diablo-4-loot-reborn-update-will-make-its-items-and-players-more-powerful-than-ever/1100-6523061/
8. D4 S4 patch notes (no-fail masterwork): https://www.gamespot.com/articles/diablo-4-massive-loot-reborn-update-is-live-now-read-the-full-season-4-patch-notes/1100-6523441/
9. D4 uniques "not exciting enough": https://www.techradar.com/gaming/diablo-4-uniques-are-not-exciting-enough-say-development-team-as-they-announce-plans-for-update
10. D4 "boring" uniques: https://www.charlieintel.com/diablo/diablo-4s-boring-unique-items-are-putting-players-to-sleep-302220/
11. D4 inventory problems: https://www.forbes.com/sites/paultassi/2023/06/22/diablo-4-already-has-some-pretty-big-inventory-problems/
12. Blizzard forum, inventory Tetris: https://us.forums.blizzard.com/en/d4/t/diablo-5-feedback-inventory-management-tetris-style-is-a-bad-idea/266331?page=4
13. NeverSink loot filter: https://github.com/NeverSinkDev/NeverSink-Filter
14. LE Circle of Fortune S5: https://maxroll.gg/last-epoch/news/season-5-item-faction-updates
15. LE skill specialization: https://support.lastepoch.com/hc/en-us/articles/46363203944859-Skill-Specialization
16. LE loot/crafting feedback: https://devtrackers.gg/last-epoch/p/f0b578e9-loot-system-general-problems-and-feedback
17. LE offline mode: https://www.thegamer.com/last-epoch-offline-vs-online-explained/
18. Grim Dawn reception (offline, no MTX): https://www.notebookcheck.net/This-Diablo-like-ARPG-loved-by-93-of-players-is-90-off-on-Steam.1255455.0.html
19. Grim Dawn blueprints: https://grimdawn.fandom.com/wiki/Blueprints
20. PoE2 respec complaints: https://steamcommunity.com/app/2694490/discussions/0/594008890765568768
21. D4 respec costs: https://game8.co/games/Diablo-4/archives/407426
22. D3 Season Journey: https://www.icy-veins.com/d3/overview-of-season-journey-in-diablo-3
23. D4 seasonal model criticism: https://www.forbes.com/sites/paultassi/2023/06/20/diablo-4-may-need-to-adjust-its-start-over-from-scratch-seasonal-model/
24. D4 Codex of Power: https://www.icy-veins.com/d4/guides/legendary-aspects-codex-of-power-guide/
25. Diablo Immortal backlash: https://www.pcgamer.com/diablo-immortal-microtransactions-have-sparked-a-brutal-backlash/
26. DI Metacritic user score: https://www.videogameschronicle.com/news/diablo-immortal-faces-a-backlash-as-metacritic-user-score-drops-to-blizzards-third-lowest-ever/
27. DI touch controls: https://gameinformer.com/review/diablo-immortal/the-price-of-playing-with-the-devil · https://www.digitaltrends.com/gaming/diablo-immortal-mobile-review-impressions/
28. Torchlight: Infinite: https://en.wikipedia.org/wiki/Torchlight:_Infinite
29. Undecember P2W: https://lootandgrind.com/undecember-worth-playing/
30. Eternium (tap-to-move, no paywalls): https://www.cityparkgames.com/games/eternium
31. Archero deconstruction: https://www.deconstructoroffun.com/blog/2019/8/9/why-archero-banked-25m-but-leaves-25m-hanging-hlx9n · https://reversenerf.com/retention-made-easy-with-archero-and-what-its-missing/
32. Vampire Survivors: https://en.wikipedia.org/wiki/Vampire_Survivors · https://www.kokutech.com/blog/gamedev/design-patterns/power-fantasy/vampire-survivors
33. VS and gambling psychology [S]: https://theconversation.com/vampire-survivors-how-developers-used-gambling-psychology-to-create-a-bafta-winning-game-203613
34. Hades God Mode: https://caniplaythat.com/2021/08/11/hades-god-mode-explained-by-supergiant-games/
35. Hades narrative rewards [S]: https://www.gamedeveloper.com/design/how-supergiant-weaves-narrative-rewards-into-i-hades-i-cycle-of-perpetual-death
36. Kasavin on roguelikes: https://www.tomsguide.com/features/hades-exclusive-interview-supergiant
37. Quantic Foundry model: https://quanticfoundry.com/gamer-motivation-model/
38. Ryan, Rigby & Przybylski 2006 (SDT): https://selfdeterminationtheory.org/SDT/documents/2006_RyanRigbyPrzybylski_MandE.pdf
39. Clark et al. 2009, near-misses: https://www.sciencedirect.com/science/article/pii/S0896627309000373
40. Schultz, reward-prediction error: https://www.pnas.org/doi/10.1073/pnas.1014269108
41. Etchells/Ferguson on the "dopamine" myth: https://www.realclearinvestigations.com/articles/2025/07/28/addiction_fiction_dopamine_is_not_why_kids_love_tiktok_1124276.html
42. Hodent, ethics & dark patterns: https://celiahodent.com/ethics-in-the-videogame-industry/
43. Juice It or Lose It (GDC): https://www.gdcvault.com/play/1016487/juice-it-or-lose
44. Art of Screenshake: https://www.youtube.com/watch?v=AJdEqssNZ-U
45. Hitstop/shake values: https://valdemird.com/blog/game-feel-on-the-web/
46. Smash hitlag: https://www.ssbwiki.com/Hitlag
47. Sakurai on hitstop [S]: https://sourcegaming.info/2015/11/11/thoughts-on-hitstop-sakurais-famitsu-column-vol-490-1/
48. D3 damage-number formatting: https://blizzardwatch.com/2016/01/25/diablo-damage-numbers-changed/ · D4 squish: https://sportskeeda.com/mmo/diablo-4-season-6-stat-squish-swing-miss-in-ptr
49. D3 legendary beam/clang: https://www.diablowiki.net/Legendary
50. Android haptics principles: https://developer.android.com/develop/ui/views/haptics/haptics-principles
51. Game Accessibility Guidelines: https://gameaccessibilityguidelines.com/basic/ · https://gameaccessibilityguidelines.com/full-list/
52. Fisher, Designing Games for Children: https://www.routledge.com/Designing-Games-for-Children-Developmental-Usability-and-Design-Considerations/Fisher/p/book/9780415729178
53. CHI 2025, children's avatar making: https://arxiv.org/html/2502.18705v2
54. Ofcom children's online lives: https://www.ofcom.org.uk/media-use-and-attitudes/media-habits-children/top-trends-from-our-latest-look-at-uk-childrens-online-lives
55. Sky friendship-gated social: https://sky-children-of-the-light.fandom.com/wiki/Friendship_Menu
56. DRG never-closing passes: https://www.destructoid.com/deep-rock-galactic-defeats-fomo-by-letting-you-play-old-seasons-whenever-wherever/
57. Halo Infinite passes never expire: https://gameinformer.com/2021/06/15/how-the-halo-infinite-battle-pass-works-including-how-it-never-expires
58. Torchlight II pets: https://www.runicgames.com/blog/2012/03/30/pets-of-torchlight-ii/
59. Whimsyshire / Cow Level: https://diablo.fandom.com/wiki/Whimsyshire · https://diablo.fandom.com/wiki/The_Secret_Cow_Level
60. Overjustification & achievements: https://www.psychologyofgames.com/2016/10/the-overjustification-effect-and-game-achievements/
61. Mobile session benchmarks [S]: https://gamedevreports.substack.com/p/gameanalytics-mobile-gaming-benchmarks · https://www.blog.udonis.co/mobile-marketing/mobile-games/session-length
62. D2 Zod rune: https://diablo.fandom.com/wiki/Zod_Rune
63. D3 ragdolls (Catto, GDC 2012): https://box2d.org/files/ErinCatto_Ragdolls_GDC2012.pdf
64. PoE2 build-diversity thread: https://steamcommunity.com/app/2694490/discussions/0/594008890765620344
65. PoE skill/support gems: https://pathofexile.fandom.com/wiki/Skill_gem
66. Chris Wilson on economic integrity: https://www.notebookcheck.net/Path-of-Exile-co-creator-online-RPGs-must-protect-their-economies-even-if-it-costs-developers-cash.1199206.0.html

# AUDIO.md – KLUNK sound map, audit and direction

Version 0.1 · 2026-09-26 · Owner: audio-designer. Phase 1: audit and plan only. No code has changed.
Subordinate to `DESIGN.md` (rules) and `UI.md` §6, §8, §12.7, §13.10, §14.7 (current sound map). Where this file proposes changing a rule in `DESIGN.md` (the pitch ladder in §5), the producer has to decide and log it first.

Sources read: `systems/audio.ts`, `systems/juice.ts`, `data/{theme,themes,juice,avatars,economyUi,startUi,abilities,collection}.ts`, all `playSound` / `playTone` / `playTimbre` call sites in `scenes/` and `ui/`, and `main.ts`.

**How the numbers were measured.** I ported `tone()`, `timbreAt()`, `playNoise()` and the danger loop to an offline JS model: band-limited additive oscillators, RBJ biquads with Web Audio's Q-in-dB convention, and the same linear-then-exponential envelopes. Every recipe was rendered at 44.1 kHz after the master gain of 0.5 and before the compressor, because the compressor is almost never active at these levels (see P1). The columns are:
- **Peak** in dBFS.
- **RMS50**: the highest 50 ms RMS.
- **LU**: K-weighted momentary loudness over 400 ms (a BS.1770 approximation), given relative to the reference: a Glimtarna merge at combo 0 and intensity 0.35, which is −36.8 LUFS-ish.
- **Phone**: how much of the energy lies above 500 Hz, in dB. Phone speakers reproduce little below that. A value of −15 dB or lower means the sound is close to silent on a phone.
- **>4k**: the share of energy above 4 kHz.

Expect the model to be within about 1 dB of Chrome. The programmer's first step (A0) makes the engine render in an `OfflineAudioContext`, so these numbers become an automated test.

---

## 1. Inventory

### 1.1 Engine today (`systems/audio.ts`)

- The chain is `osc → (biquad) → gain envelope → master gain (0.5, calm 0.3) → DynamicsCompressor(threshold −6 dB, knee 30, ratio 12, defaults) → destination`.
- There is one module-level `AudioContext`, created at the first `pointerdown` (`Start.ts:177`, `Game.ts:1278`, and `settingsSheet.ts:44` when sound is switched on).
- Every sound builds new nodes: 2–5 per tone, and up to 14 for a Planeterna merge. Nothing is pooled and nothing caps the voice count.
- Sounds are scheduled at `ctx.currentTime` with no lookahead.
- There is no bus structure, no reverb, no calm filter, no ducking, and no handling of `visibilitychange` or app pause.
- **Phaser also creates its own `WebAudioSoundManager`**, because `main.ts` does not set `audio: { noAudio: true }`. The result is a second, unused AudioContext with its own audio thread and unlock listeners.

### 1.2 Every sound event that exists

Trigger lines refer to the current code. "vol" is `0.55 + 0.45·intensity`; `playTone` always uses intensity 1. The measured columns follow the method above.

#### Core loop (juice events → `playSound`)

| Event | Trigger site | Recipe | Gain | Dur (A/D) | Peak | RMS50 | LU | Phone | >4k |
|---|---|---|---|---|---|---|---|---|---|
| `drop` | `Game.ts:1407`, i 0.2 | tri 240→180 Hz | 0.25 | 2/90 ms | −22.8 | −35.5 | −8.6 | −12.0 | 0 |
| `specialDrop` → alias `special` | `Game.ts:1400` | sine 440→1760, vib 6 Hz/35 c | 0.35 | 10/500 ms | −16.0 | −21.7 | +6.5 | −3.1 | 0 |
| `land` | `Game.ts:1682`, i = min(0.35, v/20), speed ≥1.5 | sine 180→90, LP 900 | 0.35 | 1/140 ms | −18.2 | −28.1 | −1.5 | **−17.3** | 0 |
| `merge` (Glimtarna set, the reference) | `Game.ts:1733`, i 0.25–0.7, `combo` | tri + tri +7 st (0.4), 392·2^(c/12), cap 12 | 0.4 | 4/180 ms | −15.7 | −27.1 | 0 | −4.7 | 0.1 |
| `merge` Glimtarna c12 | same | same, one octave up | 0.4 | same | −14.2 | −25.5 | +1.9 | −0.6 | 0.5 |
| `merge` Planeterna | same (`setMergeTimbre`, `Game.ts:396`) | 2 sines (9 c chorus) + octave, LP 2.4k, vib 5 Hz | 0.36 | 8/300 ms | −12.9 | −20.2 | **+7.1** | −5.4 | 0 |
| `merge` Frostisarna | same | sine + sine +24 st + tri +31 st, LP 8k | 0.4 | 1/380 ms | −16.2 | −23.5 | +4.2 | −5.0 | 0.2 (c12: 1.9) |
| `merge` Godisarna | same | square + tri +12, LP 1.9k, bend −4 st/45 ms | 0.3 | 2/120 ms | −20.0 | −31.1 | **−3.9** | −4.6 | 0.3 |
| `merge` Glöden | same | saw + sine −12, LP 2.4k→600 Q3, noise click 5k | 0.34 | 4/220 ms | −15.3 | −28.0 | −0.8 | −7.1 | 0.6 |
| `chain` (replaces merge at chain ≥3) | `Game.ts:1733` | square C5, LP 2.6k, arp 0/4/7/12 every 70 ms, **fixed pitch, ignores set and combo** | 0.3 | 3/160 ms ×4 | −14.1 | −23.7 | **+10.1** | −0.9 | 1.7 |
| `special` (rainbow) | `Game.ts:1596`, `:1624` | as specialDrop | 0.35 | 10/500 ms | −15.2 | −20.9 | +7.2 | −3.1 | 0 |
| `bomb` | `Game.ts:1584`, i 1 | white noise, LP 3.2k→200 + 60 Hz sine sub | 0.5 | 1/450 ms | **−9.7** | −19.3 | +6.9 | −8.2 | 2.4 |
| `jackpot` → alias `newRecord` | `Game.ts:1614` (10+10), `:1624` / `:1733` (level 10 created) | tri E5 0/5/9 every 110 ms + octave (0.25) | 0.45 | 4/280 ms ×3 | −13.2 | −22.1 | +10.5 | −0.5 | 0.9 |
| `newRecord` | `Game.ts:1257`, i 0.9 (muted when Fia) | same as jackpot | 0.45 | same | −13.6 | −22.5 | +10.2 | −0.5 | 0.9 |
| `record` (90 % pulse) | `Game.ts:1263`, i 0.5 | sine 1568 Hz | 0.14 | 2/70 ms | −25.4 | −37.8 | −9.0 | 0 | 2.1 |
| `danger` (loop) | `Game.ts:1950` → `juice.ts:199–204` `startDanger`, ends in `endDanger`, 250 ms fade | saw 55 Hz, LP 300, tremolo 4 Hz ±50 % | 0.12 | 250 ms in, sustained | −18.8 | −25.4 | **+6.1 sustained** | **−18.5** | 0 |
| `loss` | `Game.ts:2277`, i 0.5 | tri 330→110 | 0.4 | 10/900 ms | −16.3 | −22.6 | +6.7 | −8.6 | 0 |
| `ui` | `GameOver.ts:141` (restart), `Book.ts:399`, `:1144`, `shellOpening.ts:127` | sine 880→1200 | 0.2 | 1/50 ms | −20.5 | −34.4 | −7.0 | −0.4 | 0.2 |

#### Meta layer, collection (`META_SOUND`, `COLLECTION_FX.sound` → `playTone`)

| Event | Trigger site | Recipe | Gain | Dur | Peak | LU | >4k |
|---|---|---|---|---|---|---|---|
| `chainLight` | `Game.ts:1038`; `:1099` (Ekko sonar) | sine C5 + `CHAIN_STEPS[level]` (up to +24 = 2093 Hz), 60 ms delay | 0.10 | 2/90 ms | −26.1 | −7.6 | 6.5 |
| `chainFirst` | `Game.ts:1038`; `:2098` (Maja magnet, reused) | as above + fifth (0.5) | 0.12 | 2/160 ms | −21.4 | −2.5 | **10.8** |
| `shiny` (`COLLECTION_FX.sound.shiny`) | `Game.ts:1075` | tri D5 + octave, 70 ms delay. **Played without the combo offset** | 0.22 | 4/420 ms | −19.3 | +1.3 | 0.3 |
| `shinyCreate` (`META_SOUND`) | **unused** (it duplicates the line above and has vibrato) | – | – | – | – | – | – |
| `catch` | `GameOver.ts:263`, `CATCH_STEPS[i]` | tri C6 + octave | 0.20 | 3/120 ms | −20.7 | −2.1 | **9.9** |
| `shinyCatch` | same | tri C6 + fifth, vibrato | 0.22 | 3/300 ms | −17.0 | +3.6 | **12.8** |
| `newSet` | `GameOver.ts:488`, then `playTimbre` ×2 (`:490–491`) | tri C5 arp 0/4/7/12/16 every 90 ms + octave | 0.40 | 4/320 ms ×5 | −13.5 | **+12.2** | 1.1 |
| set arpeggio in book | `Book.ts:1208` | `playTimbre` 0/4/7 | set | set | – | – | – |
| `pageTurn` | `Book.ts:1161` | sine 900→620 | 0.12 | 1/70 ms | −24.8 | −9.9 | 0.2 |
| `locked` | `Book.ts:1116`, `:1181` | tri 330→247 | 0.16 | 4/140 ms | −22.5 | −6.4 | 0 |

#### Friends, shells and economy (`AVATAR_SOUND`, `ECONOMY_SOUND`)

| Event | Trigger site | Recipe | Gain | Peak | LU | >4k |
|---|---|---|---|---|---|---|
| `shellOpen` | `shellOpening.ts:126` (280 ms delay; `ui` plays at t 0) | tri 220→330, 120 ms | 0.22 | −20.0 | −4.9 | 0 |
| `reveal.common` | `shellOpening.ts:190` | tri E5 + fifth | 0.24 | −17.9 | −0.6 | 0.3 |
| `reveal.uncommon` | same | 0/7 | 0.26 | −17.8 | +3.1 | 0.7 |
| `reveal.rare` | same | 0/4/7 | 0.28 | −17.1 | +6.0 | 0.4 |
| `reveal.epic` | same | 0/4/7/12, vibrato | 0.30 | −15.9 | +8.6 | 0.6 |
| `reveal.legendary` | same | 0/4/7/12/16 | 0.32 | −15.0 | +10.9 | 1.2 |
| `reveal.mythic` | same | 0/4/7/11/14/19, longer tail | 0.34 | −13.7 | **+13.2** | 1.9 |
| showcase (per figure) | `shellOpening.ts:229`, `Start.ts:421`, `Book.ts:1044` | 48 recipes from `TONE` or inline | 0.07–0.35 | −26 to −15.6 | −10.7 to **+12.5** (Stjärnvalen) | up to 9.6 |
| `equip` | `shellOpening.ts:240`, `Book.ts:1131` | sine 880→1200 | 0.12 | −24.8 | −10.5 | 0.2 |
| `boxEarned` | `GameOver.ts:364` (affordHint), `:383` | sine 784→1047 | 0.16 | −22.0 | −3.8 | 0.1 |
| `tab` | **unused** (Book uses `pageTurn`) | – | – | – | – | – |
| `wake` | `friendsShop.ts:286`, `:496`, `Book.ts:974` | sine 660→990 | 0.12 | −24.8 | −8.4 | 0.1 |
| `buy` | `friendsShop.ts:352` | tri C6 then G6 60 ms apart + octave. **Coin-like** | 0.16 | −22.3 | −3.8 | 2.8 |
| `upgrade` | `friendsShop.ts:352` | tri D5 0/4/7/12 every 70 ms, vibrato | 0.26 | −17.9 | +6.6 | 0.9 |
| `notEnough` | `friendsShop.ts:271` | sine G4→E4, LP 1.4k | 0.10 | −25.9 | −5.4 | 0 |
| `tallyPearl` | `GameOver.ts:347`, ≤12 ticks, `+round(12·share)` | sine E6 rising to E7 (2637 Hz) | 0.07 | −29.2 | −13.8 | **15.1** |
| `tallySand` | same | tri A6 + fifth, rising to A7 (3520 Hz, fifth at 5274 Hz) | 0.08 | −26.8 | −11.0 | **43.7** |
| `tallyEnd` | `GameOver.ts:353` | sine C6→G6 | 0.12 | −24.5 | −7.2 | 0.5 |

#### Start v2 and buttons (`BUTTON_SOUND`)

| Event | Trigger site | Recipe | Gain | LU |
|---|---|---|---|---|
| `press` | `ui/button.ts:96` (pointerdown) | sine 520→440, 35 ms | 0.08 | −16.3 |
| `confirm` | `ui/button.ts:107` | same recipe as THEME `ui` | 0.20 | −7.0 |
| `play` (PLAY button) | `ui/button.ts:107` | tri G4 0/7 + octave | 0.22 | −1.2 |
| `denied` | button in disabled state | same as `notEnough` | 0.10 | −5.4 |
| `sheetOpen` / `sheetClose` | `settingsSheet.ts:110`, `:182` | sine 620↔900 | 0.12 | −10.1 |
| `switchOn` / `switchOff` | `settingsSheet.ts:174` | sine 740→988 / →554 | 0.14 / 0.12 | −10.1 / −11.3 |
| `shellPeek` | `Start.ts:578` | sine 988→1318 | 0.08 | −13.3 |
| Hero tap (Glimt) | `Start.ts:404` | `playSound('merge', {combo:1})`, uses the last set timbre | – | ≈ 0 |

#### Friends in play and abilities

| Source | Trigger site | Sound |
|---|---|---|
| Buddy cosmetic (`cosmetic.sound[trigger]`) | `ui/buddy.ts:113`, from `Game.ts:1068` (newLevel), `:1258` (record), `:1397` (drop), `:1677` (land), `:1745–1748` (klunk / chain / merge+combo / combo3) | `TONE` palette: `plopp`, `click2` (square 1500 Hz, **3.8 % >4k**), `pip` (1760→2240 Hz, **on every drop or land**), `kvack`, `surr`, `arf`, `blubb`, `tink` (2093 Hz + fifth), `whoosh`, `robot`, `puff`, `purr` (70 Hz, phone −28 dB), `squeak`, `arrr`, `wooo`, `drum` (140→58 Hz, phone −21 dB), `song` |
| Maestro `comboMelody` | `abilityFx.ts:52` → `audio.ts:346` | merge follows a melody (traditional "Twinkle", public domain); II adds a fifth, III adds bass every 3rd note (0.6) |
| Eko `echoMerge` | `abilityFx.ts:99` → `audio.ts:352` | **re-synthesises** the merge 3× (180 ms, fb 0.35–0.45, wet 0.3–0.38) |
| Havsdrottningen | `abilityFx.ts:133` → `audio.ts:351` | extra sawtooth layer +12 st, LP 1.8k, gain 0.15 |
| Tick `dangerStyle` | `abilityFx.ts:57` → `audio.ts:439` | 1 s buffer with a 1200/900 Hz click, **allocated on every danger start** |
| Muller `thunderChain` | `abilityFx.ts:215` | saw 55→40 Hz, LP 400, gain 0.18–0.22 (phone −15.7 dB) |
| Vulle `lavaMerge` | `abilityFx.ts:257` | sine 55 Hz, 0.24–0.30 (**phone −37.8 dB, silent on a phone**) |
| Fia `recordFanfare` | `abilityFx.ts:327` | own fanfare, square 261 Hz 0/12/7/12, LP 1.8k |

### 1.3 Gaps: moments with no sound, or the wrong one

| Moment | Today | Gap |
|---|---|---|
| Scene transitions (Start→Game, Game→GameOver, GameOver→Game, Start↔Book) | Only the button's own blip or `loss` | No shared "dive in / surface" gesture and nothing ties the scenes together |
| Button press | Three families: `BUTTON_SOUND.press/confirm` (Start v2 `Button`), `playSound('ui')` (Book, GameOver, shell), and ad-hoc `pageTurn` / `equip` / `wake` | Not consistent. Book and GameOver never play `press` on pointerdown. `confirm` duplicates THEME `ui` |
| Shell rarity tiers | Present, but **loudness rises 13.8 LU from common to mythic** | UI.md §13.10 says "richer, not louder". Tiers must be loudness-matched (child-safety) |
| Jackpot | Borrows `newRecord` | A level 10 that also beats the record plays the same fanfare twice, overlapped (stack measured below) |
| Round end after a new record | `loss` (330→110 Hz, falling) at t 0 | A falling "sad" glide over the gold ring. Needs a `lossRecord` variant that resolves warmly |
| Danger ends | 250 ms fade | No "exhale" or relief cue |
| Upgrade | One sound for I→II and II→III | No step difference, no "fill" feel |
| Purchase | `buy` = two quick high notes a fifth apart | Reads as a coin pickup. Replace (§3.6) |
| Tally | Up to 24 rising ticks up to 5.3 kHz | Slot-counter gesture and too bright. Replace |
| Set chosen in book | 0/4/7 arpeggio | OK. No confirm on the set page itself |
| Magnet pull (Maja) | Reuses `chainFirst` | Needs its own "pull" |
| Record passed in play | `newRecord`, same as jackpot | Needs its own identity |
| Calm mode | Master 0.5→0.3 plus intensity ×0.5 | **No calm variants**: same attacks, same brightness, same 4 Hz tremolo, same tally |
| Music | None | The whole adaptive layer (§4) |
| App backgrounded | Nothing | The danger loop can keep sounding in the background on Android WebView |

---

## 2. Problems

### P1. Loudness is inconsistent and the "limiter" is not a limiter

- **Set timbres spread by 11 LU**: Planeterna +7.1 and Godisarna −3.9 against Glimtarna. The `SetSound.gain` comment says "normalised" but it is not. Switching set changes how loud the core loop is.
- **The accent events sit 6–12 LU above the core merge**: chain +10.1, newRecord / jackpot +10.5, newSet +12.2. A merge happens every 2–5 s, so the ear calibrates to it and everything big jumps out too far. The ladder in UI.md §6 is about the number of channels, not loudness, so the big moments should be about +4 to +6 LU.
- **`loss` is +6.7 LU and falls 1.6 octaves**. It is the loudest thing in a normal round and it is "punishing" in character.
- **`danger` is +6.1 LU and sustained**. It is the loudest continuous element on headphones, yet −18.5 dB above 500 Hz means it is almost silent on a phone speaker. So it is both too loud and inaudible, depending on the device.
- **Reveal tiers rise from −0.6 to +13.2 LU.** That escalation builds anticipation on rarity. It must be flat across tiers.
- **The compressor almost never engages.** Threshold is −6 dBFS with knee 30 and ratio 12, and it is placed after master 0.5. Single events peak between −30 and −10 dBFS, so it is inert, and with knee 30 it is also not a brickwall at 0 dBFS. It adds nothing now and will not protect the mix once music and reverb exist. Chrome also applies automatic make-up gain to this node.
- **Worst-case stacks.** The Eko III + Maestro III merge on Planeterna peaks at −8.0 dBFS with 56 live nodes. A cascade of 4 chains 180 ms apart with chainLight and shiny reaches +14.1 LU. A level-10 jackpot that also passes the record, with chainFirst and shiny, reaches +14.1 LU and 28 nodes.

### P2. Harsh frequencies (kids' ears; rule: nothing harsh above about 4 kHz)

| Sound | Problem |
|---|---|
| `tallySand` | 43.7 % of its energy is above 4 kHz. The top tick is 3520 Hz with a fifth at 5274 Hz, 12 times per round |
| `tallyPearl` | 15.1 % above 4 kHz, up to 2637 Hz, 12 times per round |
| `catch` / `shinyCatch` | 10–13 %: the C6–C7 ladder plus an octave or fifth harmonic |
| `chainFirst` | 10.8 %, up to 2093 Hz plus a fifth (3136 Hz) |
| Frostisarna merge | The triangle at +31 st reaches 4.7 kHz as its fundamental at combo 12, with odd harmonics to 14 kHz behind LP 8k |
| `chain` | A square wave through a 12 dB/oct LP at 2.6k still leaves a buzzy 3rd, 5th and 7th |
| Buddy `pip` (1760→2240 Hz), `click2` (square 1500 Hz), `tink` (2093 Hz + 3136 Hz) | High, and repeated on every drop, land or merge |
| Glöden noise click | LP 5 kHz |

### P3. Too many simultaneous voices

- Nothing limits voices today. Peak live node counts, measured:
  - mythic reveal: 48
  - Havsdrottningen showcase: 48
  - Stjärnvalen showcase: 40
  - Eko III + Maestro III merge: 56
  - jackpot stack: 28
  - cascade: 18
  - Planeterna merge: 14 each, so a fast combo run of 4 overlapping merges is about 56
- Eko re-synthesises the whole merge 3 times instead of using one `DelayNode`.
- In a cascade, every chain step plays its own 4-note arpeggio **at the same fixed C5**, so the ladder collapses into a smear of repeated arpeggios.
- The round end can stack all of these within 2.5 s: `loss` (0.9 s), up to 6 catches, 24 tally ticks, `tallyEnd`, `boxEarned`, the `newSet` fanfare and two timbre previews.

### P4. Android WebView latency and robustness risks

1. **Scheduling at `currentTime` with 1–2 ms attacks.** On Android, `currentTime` advances in hardware-buffer steps (often 5–20 ms). An event scheduled "now" is often already in the past, so the attack ramp is skipped and the onset clicks. This is most audible on `ui`, `press`, `record` and `tally`.
2. **Two AudioContexts** (ours plus Phaser's). That means two audio threads and extra battery use, and Phaser adds its own unlock handlers.
3. **No suspend or resume.** The danger loop, and later the music, can keep playing when the app is backgrounded. Capacitor's `WebView.onPause()` does not reliably stop Web Audio. Nothing re-checks `ctx.state` after returning from background except the next pointerdown.
4. **Allocations on hot paths:**
   - The Tick buffer (`sampleRate` floats) is allocated on every danger start, during slow-mo.
   - The noise buffer (0.6 s) is built lazily on the first bomb, which is a big moment.
   - All nodes are one-shot, about 50 nodes/s in cascades.
5. **No explicit `latencyHint: 'interactive'`.** It is the default, so risk is low, but it should be pinned. Do not force `sampleRate`: most devices are 48 kHz, and forcing 44.1 kHz adds a resampler.
6. **Unmeasured output latency.** `baseLatency` and `outputLatency` are not logged in the debug run log, and STATUS.md lists "ljudlatens" as untested on device.
7. **Bluetooth latency (150–250 ms)** cannot be fixed. That is acceptable only because sound is never required (UI.md §10.6). Keep it that way.
8. `mediaPlaybackRequiresUserGesture` is already `false` in Capacitor's `Bridge.java`, so unlock is only needed for the Chrome autoplay policy. The current unlock is correct.

### P5. What gets annoying after 30 minutes

Rough counts per 30 minutes: about 900 drops, 900 lands, 400–600 merges and 20–40 round ends.

1. **The `drop` + `land` pair is identical every time**, about 1,800 identical sounds. There is no variation in pitch, level, object size or speed beyond the gain. The machine-gun effect is strongest in the drought phase.
2. **Every non-combo merge is exactly G4.** With no variation, the "pling" becomes a metronome.
3. **Buddy cosmetics on every drop or land** (`pip`, `click2`, `drum`, `surr`, `whoosh`, `wooo`) have no cooldown. At 2 kHz, `pip` and `click2` are the single most fatiguing sounds in the game.
4. **The danger tremolo** is 4 Hz at ±50 % depth: an alarm-like wobble for up to several seconds, several times per round.
5. **The tally**: 12–24 rising ticks at every round end, a slot-counter feel.
6. **The chain square arpeggio** breaks the set timbre (it always sounds like 8-bit C major) and, as above, turns into repeated arpeggios in a cascade.
7. **Key clashes.** The ladder is chromatic (+1 semitone per combo) and `newRecord` is an A major triad (C♯). Once music exists in a key, these clash. Today they only clash with each other. For example, the shiny sound is a fixed D5 while the merge rides the ladder: at combo 1 the merge is G♯4 and D5 is a tritone above it.

---

## 3. Premium sound direction

### 3.1 Sonic identity: "a glass jar in warm deep water"

- **Glassy.** The main voices are sine and triangle bodies with a quick **upward bubble bend** at onset: 1–2 st over 20–35 ms, because physical bubbles rise in pitch. A soft upper partial (octave or 12th) gives the glass. There are no raw square or saw waves above 1.8 kHz.
- **Warm.** Every tonal voice goes through a low-pass with its ceiling at **3.4 kHz** (calm mode 2.8 kHz, music 1.6 kHz). Less than 5 % of any event's energy may lie above 4 kHz. Fundamentals of pitched SFX stay at or below 1.3 kHz, and at or below 2.1 kHz for the rare sparkle top.
- **Underwater.** A shared short "jar" reverb (§3.2) is audible on SFX mostly as a tail. A slow, tiny detune chorus (±4–6 cents) sits on sustained voices. The music bed carries a filtered water texture.
- **Phone-first low end.** Every sound that carries "weight" (land, bomb, danger, Vulle, Muller, the drum and purr buddies) gets **its 2nd and 3rd harmonics** added, the "missing fundamental" trick. A 55 Hz sine alone is silent on a phone. The body then reads on a phone and the sub still works on headphones.
- **Size = register, success = pitch.** Bigger objects sound lower and rounder, controlled by level: land pitch drops 1 st per level, and the merge low-pass and sub-layer grow with level. A better combo sounds higher. These two axes never fight.
- **Never** buzzers, falling "fail" glissandi, coin pickups, slot counters, drum rolls or risers before a reveal (UI.md §13.3 and §14.7, DESIGN §16).

### 3.2 Master bus

```
voices ─► sfxBus  ─┐
voices ─► uiBus   ─┤
music  ─► musicBus┼─► preMix ─► calmLP ─► glue comp ─► limiter ─► masterGain ─► destination
amb    ─► ambBus  ─┘     ▲
sfx/music sends ─► reverb (Convolver, generated IR) ─► reverbReturn ┘
```

| Stage | Value (`AUDIO_MIX` in the new `data/audio.ts`) |
|---|---|
| Bus trims | sfx 0 dB, ui −2 dB, music −14 dB (the bed sits 14 LU under a merge), amb −10 dB |
| Reverb | ConvolverNode with an IR generated once at unlock: stereo, 1.1 s, exponentially decaying noise low-passed to 2.6 kHz, 12 ms pre-delay. Return −8 dB. Sends: merge 0.18, chain / fanfares 0.25, land 0.08, ui 0, music 0.3. **Lite fallback**: two DelayNodes (37 / 53 ms) with feedback 0.35 through LP 2k |
| `calmLP` | Biquad LP at 20 kHz, ramped to 2.8 kHz over 300 ms when calm is on |
| Glue compressor | threshold −18 dB, knee 6, ratio 3, attack 5 ms, release 150 ms |
| Limiter | DynamicsCompressor threshold −3 dB, knee 0, ratio 20, attack 1 ms, release 80 ms. The ceiling is set by the stage after it |
| `masterGain` | −6 dB (≈ today's 0.5); calm −10.5 dB (≈ 0.3) |
| Ducking | Automation on `musicBus.gain` with `setTargetAtTime` (§4.6). No real sidechain is needed |

### 3.3 Loudness ladder (tiers in LU, relative to a merge at combo 0)

Targets are K-weighted momentary maxima. Every event gets a `trimDb` in data so it lands within ±1 LU of its tier. The offline test in A4 enforces this.

| Tier | Target | Events |
|---|---|---|
| T0 bed | −14 to −12 | music, water, danger bed |
| T1 micro | −16 to −11 | `press`, tally ticks, `pageTurn`, `tab`, switch, `shellPeek`, `equip` |
| T2 light | −10 to −5 | `drop` (−10), `land` (−5), `chainLight` (−8), `confirm`/`ui` (−8), `wake` (−9), `record` (−8), `notEnough`/`denied`/`locked` (−8), `boxEarned` (−6), buddy cosmetics in play (≤ −6) |
| T3 core | 0 to +2 | `merge` (+2 at the ladder cap), `shiny` (+1), `catch` (−3), `shinyCatch` (0), `dangerEnd` (−4) |
| T4 accent | +2 to +4 | `special` (+3), `chain` (+4), `bomb` (+4), `upgrade` (+3), `buy` (−2, stays soft), `shellOpen` (−4), `loss` (+1, soft), showcases (≤ +3) |
| T5 peak | +5 to +6 (ceiling) | `jackpot` (+6), `newRecord` (+5), `newSet` (+6), `reveal.*` (**all +4 ±0.5**), `lossRecord` (+4) |

Corrections from today, rounded, to be verified by the test:

| Sound | Trim |
|---|---|
| Planeterna | −7 dB (gain 0.36 → 0.16) |
| Frostisarna | −4 dB |
| Godisarna | +4 dB |
| Glöden | +1 dB |
| `chain` | −6 dB |
| `newRecord` / `jackpot` | −5 dB |
| `newSet` | −6 dB |
| `loss` | −6 dB |
| `danger` | −18 dB on headphones, while becoming audible on phones through harmonics |
| mythic reveal | −9 dB |
| legendary | −7 dB |
| epic | −5 dB |
| rare | −2 dB |
| uncommon | +1 dB |
| common | +4 dB |

After these trims, rarity is carried only by harmony (number of chord tones), tail length, vibrato and reverb send.

### 3.4 Voice limiting and priority (`VOICE_RULES`)

A small voice manager in `audio.ts`. A voice is one logical sound instance with its nodes. Each play request carries a `SoundId`, and the rule gives bus, priority, per-id cap, minimum gap, reverb send, trim and variation.

- **Global budget: 16 SFX voices and 72 live nodes.** Music owns its own fixed budget (§4.7).
- When the budget is full, steal the **oldest voice of the lowest priority** with a 15 ms fade. If every live voice has higher priority than the request, drop the request.
- Per-id caps: a new instance over the cap steals the oldest of the same id.
- **Same id within `minGapMs`**: do not start a new voice. Add +1 dB to the live one, up to +3 dB. This handles double lands and simultaneous merges.
- **Big-moment shadow**: for 600 ms after a P0 event, P3–P4 requests are dropped, except `merge` and `chainLight`, which are attenuated −6 dB.

| Priority | Events | Per-id cap | minGap |
|---|---|---|---|
| P0 (never stolen) | `jackpot`, `newRecord`, `newSet`, `reveal.*`, `loss`/`lossRecord`, `danger` bed | 1 | – |
| P1 | `chain`, `special`, `bomb`, `upgrade`, `buy`, `shellOpen`, showcase | 2 | 40 ms |
| P2 | `merge`, `shiny`, `catch`/`shinyCatch`, ability layers | 4 (merge), 2 others | 25 ms |
| P3 | `land`, `drop`, `chainLight`/`chainFirst`, `record`, `boxEarned`, tally | 2 (tally 1) | 30 ms (tally 60 ms) |
| P4 | UI (`press`, `confirm`, switches, page), buddy cosmetics | 2 | 30 ms; buddy cosmetics **cooldown 4 s per trigger type** |

Node-cost rules:
- Arpeggio steps reuse one filter and one envelope bus per voice, not one per note.
- Echo becomes one DelayNode with feedback on an `echoSend` (4 nodes total) instead of re-synthesis.
- Vibrato uses one shared LFO per voice, not one per oscillator.

### 3.5 Pitch-ladder rules for combos

1. **Key is G major, pentatonic-first (G A B D E).** C is allowed only inside fanfares and pads as a IV colour. Every pitched SFX is written in this key. The existing sounds are already there except `newRecord` (E–A–C♯), tally, the shiny offset and `record`.
2. **Combo ladder (proposal, needs a DESIGN §5 change):**
   - The merge root is `392 Hz · 2^(LADDER[min(combo, 7)]/12)` with `LADDER = [0, 2, 4, 7, 9, 12, 14, 16]` (G4 A4 B4 D5 E5 G5 A5 B5; the top is 988 Hz).
   - From combo 8 to 12 the pitch holds and a **sparkle layer** grows instead: octave partial gain 0.1 → 0.4 and reverb send +0.05 per step.
   - "Higher = better" still holds. The ladder is always consonant with the music and never reaches the bright zone.
   - Fallback if DESIGN keeps the chromatic rule: keep it, but snap to the nearest pentatonic degree when music is on.
3. **Chain ≥3** stops being a separate square arpeggio. It plays the **merge voice of the active set** at the current ladder pitch, preceded by grace notes from the ladder: chain 3 = 1 grace note (index −1), 4 = 2, ≥5 = 2 plus a sub bloom (−12 st, gain 0.3). Grace notes are 45 ms apart. There are never more than 3 notes, and the result stays coherent with the set.
4. **Companion sounds follow the ladder:**
   - `shiny` = the ladder index +3 (a pentatonic "fifth-ish"), always consonant.
   - `chainLight` keeps `CHAIN_STEPS` (already pentatonic C) but is transposed to G: base 392 Hz and capped at +16 st.
   - `catch` becomes a G pentatonic run starting at G5, not C6, with the top at E6 (1318 Hz).
5. **Level shapes the body, not the pitch.** For created level L:
   - merge low-pass `1.8k + 160·L` Hz (level 10 → 3.4k)
   - sub layer (−12 st) gain `0.04·max(0, L−5)`
   - land pitch `−1 st · L` from a 330 Hz body with 2nd and 3rd harmonics
6. **Micro-variation (never gameplay RNG, use `Math.random`):**
   - drop and land: ±12 cents and ±1 dB
   - merge: ±6 cents and ±0.7 dB
   - buddy cosmetics: ±20 cents
   - The ladder pitch itself is never varied.
7. **Reset is silent.** When the combo window expires, nothing plays and the next merge is simply back at G4. The dots show the reset (UI.md §8).

### 3.6 Per-set timbre coherence

- Each `ThemeSet.sound` becomes the set's **voice**: it is used for `merge`, `chain` grace notes, the `shiny` sparkle (the same voice +octave, gain 0.35), the book arpeggio, the new-set preview, and the music's **pluck layer**. Switching set recolours the whole soundscape, not just one event.
- `drop`, `land`, UI and fanfares stay global, because they are the jar and the menu.
- Shared constraints for every set voice:
  - attack 2–8 ms
  - bubble bend −1 to −4 st over ≤45 ms
  - low-pass ≤3.4 kHz (Frostisarna's +31 st triangle is replaced by sine +19 at 0.18 and sine +24 at 0.12, LP 3.8k, Q 0.5)
  - noise click LP ≤3.5 kHz
  - `trimDb` per §3.3
- Music only uses the pluck voice with an extra LP at 1.6 kHz and gain −10 dB, so the set colour is present but never competes with the merge.

### 3.7 New and redesigned events (recipes to be finalised in data during A6)

| Id | Recipe sketch | Tier / priority |
|---|---|---|
| `land` (redesign) | sine body 330·2^(−L/12) Hz, gliding −5 st over 90 ms, plus its 2nd (0.35) and 3rd (0.12) harmonics, LP 1.4k, plus a 6 ms noise tick through LP 1.8k at 0.05. Gain from speed | T2 / P3 |
| `drop` (redesign) | a soft "release" puff: noise through bandpass 700→400 Hz, 70 ms, with variation | T2 / P3 |
| `jackpot` (new) | pad-like G major add9 bloom: set voice at G4, D5, A5 and B5, spread 40 ms apart, +octave sparkle, long reverb send 0.35, 900 ms tail. Ducks music −8 dB | T5 / P0 |
| `newRecord` (retuned) | tri D5 0/5/9 → **D–G–B** (G major), 100 ms apart. Skipped when `jackpot` played within 800 ms (merged into it, +1 dB) | T5 / P0 |
| `lossRecord` (new) | instead of `loss` when the record was beaten: G major triad 0/4/7 swelling in over 150 ms, 1.2 s tail | T5 / P0 |
| `loss` (softened) | tri 294→196 Hz (D4→G3, a resolution, not a fall into the bass), 600 ms, LP 1.2k | T4 / P0 |
| `danger` bed (redesign) | "held breath": sines at G2 and D3 with 2nd and 3rd harmonics (so they are audible on a phone), LP 700, **0.5 Hz swell ±25 %** (no 4 Hz tremolo), 400 ms fade in. With music on, this is replaced by the music's danger layer | T0 / P0 |
| `dangerEnd` (new) | soft "exhale": noise through bandpass 900→500 Hz, 350 ms, plus a sine at G4 at 0.06 | T3 / P2 |
| `sceneIn` / `sceneOut` (new) | bubble swell up or down: noise through bandpass 500↔1100 Hz, 220 ms, plus a sine blip on G (Start→Game in, Game→GameOver out). Music continuity handles the rest | T1 / P4 |
| UI family (unified) | `uiSound(kind)` with kind = `press` (pointerdown), `confirm`, `back`, `toggleOn`/`toggleOff`, `tab`, `denied`. Every tappable, including Book, GameOver and shell, goes through it | T1–T2 / P4 |
| `reveal.*` (loudness-matched) | same harmony ladder, all at +4 LU. Richness comes from the number of chord tones, tail length and reverb send. No steps are faster, no step is higher than E6 | T5 / P0 |
| `buy` (redesign) | "pearls into a bowl": two tri notes at 880 and 1175 Hz, 25 ms apart, heavily damped (80 ms), plus a soft 330 Hz body. Not two bright notes in the coin register | T4 / P1 |
| `upgrade` I→II / II→III | I→II: D5 0/4/7. II→III: 0/4/7/12 plus a sparkle. Same loudness | T4 / P1 |
| tally (redesign) | **at most 6 soft bubble ticks per row** (sine with a +2 st bend, pentatonic G5→E6, ≤1318 Hz), 80 ms minimum gap, plus `tallyEnd` (sine G5→D6) | T1 / P3 |
| `magnet` (new, Maja) | sine 294→392 Hz glide over 300 ms, LP 1.2k, tiny vibrato | T2 / P2 |
| Vulle, Muller, purr, drum | add 2nd and 3rd harmonics (phone audibility), keep the sub | – |
| Buddy `pip` / `click2` / `tink` | move down to ≤1.6 kHz fundamentals and replace the square with a triangle through LP 2.4k. Cooldown per §3.4 | T2 / P4 |

### 3.8 Calm-mode variants

Everything is driven by `settings.calm`, with data in `AUDIO_MIX.calm`:
- **Global**: `calmLP` at 2.8 kHz; minimum attack 8 ms; reverb send ×1.3 (softer, farther away); master −10.5 dB.
- **Merge ladder**: the same pitches (the information is kept), with sparkle limited to 0.2.
- **Chain**: 1 grace note at most.
- **Danger**: swell depth ±10 %, no level rise. **Tick ability**: clicks low-passed to 1.2 kHz.
- **Tally**: 3 ticks per row. Fanfares: reverb-heavy and 1 dB softer.
- **Music**: see §4.5.

---

## 4. Adaptive music

### 4.1 Goals and constraints

- It is a calm, generative "aquarium" bed that makes the jar feel alive. It must never create urgency, and it must never be "celebration music" that rewards the director being generous.
- It is 100 % synthesized in Web Audio. No files, no stored melodies longer than 3 notes, and a new seed per session from `Math.random`. **The game's seeded RNG stream is never touched**, which keeps e2e determinism.
- **Child-safety gate**: it follows the director's modes. Flow is slightly denser and drought sparser, but the change is bounded (tempo ±10 %, density only), with no build-ups, risers or "hot streak" signals. It must be reviewed under TEAM.md rule 3 before it is built.

### 4.2 Musical material

| Aspect | Value (`data/music.ts`, `MUSIC`) |
|---|---|
| Key | G major, pentatonic melody (G A B D E). Pad chords may use C |
| Chord pool | Gadd9 (G B D A), Em7 (E G B D), Cmaj7 (C E G B), Dsus4 (D G A). Each lasts 2 bars in flow and 4 bars in drought or menu |
| Harmonic motion | a **Markov table**, not a loop. For example, from G: Em 0.35, C 0.35, Dsus 0.2, stay 0.1. A pop progression such as I–V–vi–IV is never repeated four chords in a row |
| Tempo (BPM) | menu 64, drought 66, flow 72, kick 72, danger 64. Changes only at bar lines, ramped over 2 bars |
| Meter | 4/4 with an 8th-note grid |

### 4.3 Layers

| Layer | Sound | Behaviour | Nodes |
|---|---|---|---|
| Pad | 3 persistent voices, each 2 triangles ±5 c → shared LP (600–1600 Hz) with a 0.05 Hz filter LFO | glides to the new chord tones (portamento 0.8 s) at each chord change. No re-attack and **no allocation** | 6 osc + 3 gain + 1 LP + 1 LFO(+gain) ≈ 12 |
| Plucks ("glass kelp bells") | the active set's voice, LP 1.6k, −10 dB; or a fallback of sine + 2nd harmonic with a 5 ms attack and 450 ms decay | Euclidean grid plus probability. Pitch is a random walk on the pentatonic scale, register G4–E6, with a 65 % preference for chord tones on strong beats | 3 per note, ≤4 notes/s, ≤6 alive |
| Bass | sine at the chord root G1–G2, plus 2nd (0.5) and 3rd (0.25) harmonic oscillators (phone audible) | whole notes in drought or menu; beats 1 and 3 in flow; sustained with a 0.5 Hz swell in danger | 3 osc + 1 gain (persistent) |
| Water | looped noise buffer (reuses the SFX noise buffer) → bandpass 450–900 Hz with a 0.07 Hz LFO → gain | constant and very low. Off in the lite profile | 3 + LFO 2 |

**Density by state** (probability that a grid hit plays; grid pattern):

| State | Density | Grid |
|---|---|---|
| menu (Start, Book, shop) | 0.12 | E(2,8) |
| drought | 0.15 | E(3,8) |
| flow | 0.30 | E(5,16) |
| kick (1 bar only) | 0.35 | E(5,8), plus the pad filter opens +300 Hz for that bar. **No riser.** It lands after the special is already visible in the preview, so it never tells the player anything new |
| danger | plucks fade to 0 over 1 bar | pad LP → 500 Hz over 1.5 s, bass sustained, water bandpass lowered to 350 Hz; **tempo does not rise** |
| GameOver | pad + bass only | pad LP 800 Hz. Carries over seamlessly into the next round |

### 4.4 Anti-resemblance rules (legal)

- There is no stored melody or motif. Phrases are generated as random walks with steps of ±1 or ±2 scale degrees (±3 at 10 %), at most 4 steps in the same direction, and a rest after at most 7 notes.
- An **n-gram memory**: the last 16 bars of 4-note interval+rhythm n-grams. A phrase that would repeat one is re-rolled, so no loop becomes a hook.
- A **banlist** of 5-note interval+rhythm signatures from well-known children's songs, lullabies and jingles, maintained by `legal-reviewer`. Examples: "Twinkle", "Frère Jacques", "Happy Birthday", Brahms' lullaby, NBC-type chimes, phone-brand and console jingles, and Suika/Watermelon Game BGM motifs. A match is re-rolled.
- Fanfares (`jackpot`, `newRecord`, `newSet`, reveals) are plain arpeggiated triads, which are not protectable, and are not fixed melodies. **Legal note:** Maestro's ability plays "Twinkle Twinkle" (traditional, public domain). It is kept as-is and is **not** used in the music layer.

### 4.5 Settings and calm mode

- `settings.music: boolean`, **default on** at the −14 LU bed. The producer may choose default off. It sits in a new row in the settings sheet: "Music" / "Musik", with a note icon, placed after "Sound". The sheet needs a fifth row, so `UI.md` §16.7 grows the sheet from y 300 to y 236 (ui-designer).
- Sound off means music off (sound is the master switch). Music off leaves SFX untouched, and the danger bed returns to the SFX version.
- **Calm mode**: fixed 64 BPM, density ×0.5, pad LP at most 1.2 kHz, no kick bar, the danger layer only closes the filter, and no bass swell.

### 4.6 Ducking under big moments

| Event | Music gain change | Attack / release |
|---|---|---|
| `jackpot`, `newSet`, `reveal.*`, `lossRecord` | −8 dB | 30 ms / 900 ms |
| `newRecord`, `loss` | −6 dB | 30 ms / 700 ms |
| `chain`, `bomb`, `special` | −3 dB | 20 ms / 400 ms |
| `merge` | none (the bed sits 14 LU under it) | – |
| Shell opening scrim | −4 dB for the whole ceremony | – |
| Book showcase | −3 dB | – |

### 4.7 CPU budget

- **Nodes**: 36 or fewer in the music layer, persistent layers ≈ 22 plus up to 18 transient pluck nodes. The SFX budget is separate (72 nodes). The total stays below about 110 live nodes, which is comfortable on mid-range Android.
- **Main thread**: the scheduler runs every 50 ms with 150 ms lookahead on the audio clock ("two clocks"). Each tick takes 0.1 ms or less, and the steady state allocates nothing except pluck nodes (at most 4/s).
- **Audio thread**: the target is 2 % of one core or less for music plus reverb on a Snapdragon 6xx-class device. Measure with Chrome tracing on the test phone (release-engineer) and compare frame time with music on and off in `Bench`.
- **Lite profile**: triggered when `PerfGuard` trips, when `navigator.hardwareConcurrency ≤ 4`, or manually from the debug panel. Pad drops to 2 voices with 1 oscillator each, water is off, reverb switches to the delay-based lite version, and plucks drop to ≤2/s.
- **Lifecycle**: suspend the context when `visibilitychange` reports hidden or when Capacitor fires `App` `pause`. On `resume` / visible, call `ctx.resume()`, or resume on the next gesture if the OS refuses. The music engine is a module singleton that lives across scenes, so a restart never re-creates it.

---

## 5. Implementation plan (programmer, small steps)

Each step ships green (unit + e2e) and does not change gameplay. A0–A2 change nothing audible. A3–A6 change the sound. A7 adds music. Gates: legal review for new sounds (A6, A7) and child-safety review for the music's director coupling and the reveal and tally changes (before A6 and A7).

| Step | Files | What |
|---|---|---|
| **A0 Engine seam** | `systems/audio.ts` | Wrap the state in `createEngine(ctx: BaseAudioContext, dest: AudioNode)`. Keep all exported functions as thin wrappers over a default engine. Add `renderOffline(fn, seconds): Promise<AudioBuffer>` for tests. In `main.ts` set `audio: { noAudio: true }` so Phaser's second context goes away |
| **A1 Bus** | new `data/audio.ts` (`AUDIO_MIX`), `audio.ts` | `buildBus(ctx)` → `{ sfx, ui, music, amb, reverbSend, calmLP, glue, limiter, master }`; `makeIR(ctx, cfg)`; `setCalm` ramps `calmLP` and master; replace the compressor. `Juice.trigger` is unchanged |
| **A2 Robustness** | `audio.ts`, `Boot.ts`, `debugPanel.ts` | `new AudioContext({ latencyHint: 'interactive' })`; `const T0 = () => ctx.currentTime + AUDIO_MIX.lookaheadMs/1000` (6 ms); attack floor 3 ms (calm 8); pre-build the noise and Tick buffers in `unlockAudio()`; add `installAudioLifecycle()` (visibilitychange + `@capacitor/app` pause/resume → suspend/resume, stop the danger loop); log `baseLatency`, `outputLatency` and `sampleRate` in the debug run log |
| **A3 Voices** | `audio.ts`, `data/audio.ts` (`VOICE_RULES`) | `type SoundId`; `interface VoiceRule { bus; priority: 0-4; cap; minGapMs; reverbSend; trimDb; vary?: { cents; db } }`; `class Voices { request(id, cost, startFn): Voice \| null; steal(); shadow(ms) }`. Every `play*` goes through `request`. Buddy cooldown lives here. Eko becomes a `DelayNode` send |
| **A4 Loudness + HF fixes** | data only: `theme.ts`, `themes.ts`, `avatars.ts`, `economyUi.ts`, `startUi.ts`, `collection.ts`; new test `tests/e2e/audio-levels.spec.ts` | Apply `trimDb` per §3.3. Frostisarna layers, Glöden noise LP and buddy tones per §3.6–3.7. The test renders each `SoundId` with `OfflineAudioContext` in the browser and asserts: K-weighted momentary max within ±1 LU of `LOUDNESS_TIER[id]`, at most 5 % energy above 4 kHz, and peak ≤ −1 dBFS for the stacks in §2 P1 |
| **A5 Ladder + chain** | `data/audio.ts` (`LADDER`), `audio.ts`, `DESIGN.md` §5 (producer) | `ladderSemis(combo)`, `sparkle(combo)`; chain = set voice + grace notes; shiny and chainLight follow the ladder; micro-variation; level → body (`mergeBody(level)`). `playSound('merge', { combo, level })`: `Game.ts:1733` passes `level: newLevel` |
| **A6 Events** | `data/audio.ts` (`SFX` recipes), `juice.ts` (`SOUND_ALIAS` loses `jackpot`), `Game.ts`, `GameOver.ts`, `Book.ts`, `friendsShop.ts`, `shellOpening.ts`, `ui/button.ts` | New ids from §3.7: `jackpot`, `lossRecord`, `dangerEnd`, `sceneIn/Out`, `magnet`, the redesigned `land`, `drop`, `danger`, `loss`, `buy`, tally, and matched reveals. `uiSound(kind)` replaces `playSound('ui')` and direct button tones. `GameOver` picks `lossRecord` when `data.record`. Calm variants as a `calm?: Partial<Recipe>` block per recipe |
| **A7 Music** | new `systems/music.ts`, `data/music.ts`, `settingsSheet.ts`, `save.ts` (`settings.music`), `Game.ts`, `Start.ts`, `GameOver.ts` | API: `music.init(bus)`, `music.enable(on)`, `music.scene('menu' \| 'game' \| 'over')`, `music.mode('drought' \| 'flow' \| 'kick')` (Game reads `director.mode` after each queue pull; the director stays audio-free), `music.danger(on)` (from the juice danger start and end), `music.duck(db, attackMs, releaseMs)` (called by `playSound` from the `DUCK` table), `music.setVoice(SetSound)`, `music.lite(on)`. The scheduler is a `setInterval` of 50 ms with 150 ms lookahead; the phrase generator is a pure function (`nextPhrase(state, rand)`) with unit tests for key, register, banlist and n-gram rules |
| **A8 Test hooks** | `audio.ts`, `music.ts` (installed only with `?test=1` or in DEV) | `window.__audio` (below). The meter is an `AnalyserNode` after the limiter, created only in test mode |

**Data shapes (summary).**

```ts
// data/audio.ts
export type BusId = 'sfx' | 'ui' | 'music' | 'amb';
export type Tier = 'bed' | 'micro' | 'light' | 'core' | 'accent' | 'peak';
export const LOUDNESS_TIER: Record<Tier, number> = { bed: -13, micro: -13, light: -7, core: 0, accent: 3, peak: 5 };
export interface VoiceRule { bus: BusId; priority: 0 | 1 | 2 | 3 | 4; cap: number; minGapMs: number;
  reverbSend: number; trimDb: number; tier: Tier; vary?: { cents: number; db: number }; duck?: DuckId }
export const LADDER = { rootHz: 392, steps: [0, 2, 4, 7, 9, 12, 14, 16], sparklePerStep: 0.075, sparkleMax: 0.4 } as const;
// data/music.ts
export const MUSIC = { defaultOn: true, bpm: { menu: 64, drought: 66, flow: 72, kick: 72, danger: 64 },
  density: { menu: 0.12, drought: 0.15, flow: 0.3, kick: 0.35, danger: 0 }, grids: { ... }, chords: { ... },
  markov: { ... }, pad: { ... }, pluck: { ... }, bass: { ... }, water: { ... },
  calm: { bpm: 64, densityMul: 0.5, padLpMax: 1200 }, lite: { ... },
  budget: { maxNodes: 36, maxPlucksPerSec: 4, lookaheadMs: 150, tickMs: 50 } } as const;
```

---

## 6. Listening checklist (producer, in the browser)

Setup: `npm run dev` or the test build with `?test=1`, on the phone (APK) **and** on laptop headphones, at half volume (PLAYTEST.md). Items marked **now** can be run on today's build with the existing `window.__game` hooks. The rest need `window.__audio` from A8.

**`window.__audio` (A8):**
- `play(id, { intensity?, combo?, level?, set? })` plays any `SoundId`.
- `gallery(group, gapMs = 700)` plays each sound in the group in order. Groups: `'core' | 'sets' | 'meta' | 'ui' | 'reveal' | 'economy' | 'buddies' | 'all'`.
- `stack(name)` plays the stress stacks: `'cascade' | 'jackpotRecord' | 'ekoMaestro' | 'roundEnd' | 'comboRun'`.
- `meter()` returns `{ peakDb, rmsDb, voices, nodes, limiterGrDb, ctxState, baseLatency, outputLatency }`.
- `calm(on)`.
- `music.{ on(b), mode(m), danger(b), scene(s), lite(b), state }`.
- `levels()` returns the offline LU/>4k table for every id, which is the same data the A4 test checks.

| # | What to do | Pass |
|---|---|---|
| 1 (now) | Play a normal round of 3 minutes. Listen to drop + land | Today it is monotone (baseline). After A6: no two consecutive lands sound identical, bigger objects sound deeper, nothing clicks at onset |
| 2 (now) | `__game.seed(7)`, then drop in the same spot until a combo of ≥5 | Pitch climbs audibly each step. After A5: it stays sweet (pentatonic) and no step sounds sharp |
| 3 (now) | Switch set in the book and repeat #2 for all 5 sets | Today Planeterna is clearly louder and Godisarna softer. After A4: all 5 sets feel equally loud |
| 4 | `__audio.gallery('sets')` | Same as #3, side by side |
| 5 (now) | Force a cascade: `__game.spawn(3,120,560)`, `spawn(3,160,560)`, `spawn(4,140,520)`… | Today: a smear of square arpeggios. After A5: one clean rising figure in the set's voice |
| 6 | `__audio.stack('jackpotRecord')`, then `stack('cascade')`, then `stack('ekoMaestro')` | No distortion; `meter().peakDb` ≤ −1; `voices` ≤ 16, `nodes` ≤ 72; the jackpot is the loudest and clearest thing |
| 7 (now) | Let the jar reach the danger line (stack objects) | Today: a 4 Hz wobble, almost inaudible on the phone. After A6: a slow "held breath" that is audible on the phone and never alarming, with a soft exhale when it ends |
| 8 (now) | Beat the record in a round, then `__game.forceLoss()` | After A6: a warm resolve, not a falling "sad" glide |
| 9 (now) | `__game.grantSand(300)` + `__game.buyShell('gold')` in the shop 6 times (or open shells from the shelf); or `__audio.gallery('reveal')` | After A4/A6: all rarities equally loud; higher tiers sound richer (more notes, longer tail), never louder, faster or higher |
| 10 | `__audio.gallery('economy')` and one real purchase | `buy` sounds like pearls into a bowl, not a coin. The tally has soft bubbles, not a counter. `notEnough` is soft |
| 11 | `__audio.gallery('ui')` and tap every button in Start, Book, Shop, Settings and GameOver | Every tappable gives `press` on pointerdown and `confirm` on release. Same family everywhere |
| 12 | `__audio.gallery('buddies')`, then 5 minutes of play with the pip or click buddies equipped | No buddy sound above ~1.6 kHz fundamental; a cosmetic plays at most once every 4 s per trigger |
| 13 | `__audio.calm(true)`, then repeat #2, #6, #7 | Everything is softer and darker (2.8 kHz ceiling), the ladder is still audible, and there is no wobble |
| 14 | `__audio.music.on(true)`, then 3 rounds | The bed stays under the merges (−14 LU); nothing sounds like a known tune; there is no build-up before specials |
| 15 | `music.mode('drought')` → `('flow')` → `('kick')`, then `music.danger(true/false)` | Flow is slightly busier and tempo change is barely noticeable. Danger makes it sparser and darker, not faster. The kick bar has no riser |
| 16 | Music on, trigger `jackpot` and a reveal | Music ducks clearly and returns within 1 s |
| 17 | Background the app for 10 s during danger or music on Android, then return | Silence while backgrounded; clean resume on return or on the first tap |
| 18 | `__audio.meter()` on the phone | Record `baseLatency` + `outputLatency` in STATUS.md. Target is ≤ 60 ms on the test phone; report it if higher |
| 19 | 30-minute session with music on, then off | Nothing becomes irritating (note any sound you start to "wait for" in a bad way). Log it in PLAYTEST.md |
| 20 | Turn Sound off in settings mid-danger and mid-music | Instant silence and no loop left running. Turning it back on plays `switchOn` |

---

## 7. Open questions

1. **DESIGN §5 pitch rule**: switch to the pentatonic ladder with its cap at combo 7 plus sparkle (recommended), or keep the chromatic ladder capped at 12? Producer decision.
2. **Music default**: on (recommended, at the −14 LU bed) or off?
3. **Child-safety review** of: music following director modes (§4.1), loudness-matched reveals (§3.3), and the tally and `buy` redesigns (§3.7).
4. **Legal review** of the new sound set and the music banlist ownership (§4.4).
5. **UI**: a fifth row in the settings sheet for Music (§4.5), from the ui-designer.

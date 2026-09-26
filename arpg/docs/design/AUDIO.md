# AUDIO: Wickwright sound and music

> Owner: audio-designer. Date: 2026-09-26. Everything under `game/assets/generated/sfx/` and `game/assets/generated/music/` is **synthesized in-house from code** in `game/tools/audio/` (numpy/scipy, no samples, no downloaded audio, no AI audio). The only exception is 4 UI ids converted from the CC0 pack *uisfx* (see §6).

## 1. Sound identity
- **Spooky-cute, never scary.** Threats are readable low "wom" tones, growls are cartoon formant growls, monsters "puff" into rising sparks (the Snuffed get rekindled). No screams, no gore, no jump-scare loudness.
- **One key for reward: D major.** All loot, level-up, quest and heal cues use D-major notes (D, F#, A, plus E/B colour). The rarity ladder therefore sounds like one family that grows. Threats and death use D minor.
- **Phone-speaker mix.** Energy sits in 200 Hz–5 kHz. Every low sound (slam, hit, boss roar, bass) gets an upper harmonic so it still reads on a phone. Music is mastered with a -7 dB low shelf below ~140 Hz.
- **Levels.** SFX: peak-normalized to -1 dBFS (no clipping). The game sets relative levels through `Sfx.play(id, volume_db)`. Music: about -18 dBFS RMS (crypt -20, hush -22) with a soft limiter and a -1 dBFS ceiling. Ambience: -23 dBFS RMS (hush -26). `Sfx` plays music 6 dB under its setting and ambience 8 dB under.
- **The game works without sound.** Every cue duplicates visual feedback (see ART_BIBLE §3 for the rarity ladder).

## 2. Formats and how the game loads audio
| Kind | Path | Format | Loaded by |
|---|---|---|---|
| SFX | `res://assets/generated/sfx/<id>.wav`, variants `<id>_1.wav` .. `<id>_4.wav` | WAV 44.1 kHz, 16-bit, mono | `Sfx.play(id, volume_db := 0, pitch_jitter := 0.08)`: picks a random variant and adds ±8 % pitch jitter |
| Music | `res://assets/generated/music/<id>.ogg` | Ogg Vorbis, 44.1 kHz mono, seamless loop | `Sfx.play_music(id)` (sets `loop = true`) |
| Ambience | `res://assets/generated/music/amb_<act>.ogg` | Ogg Vorbis, 44.1 kHz mono, 45 s seamless loop | `Sfx.play_ambience(id, fade := 2.0)`: second pair of looping players that **crossfade**. `""` or `Sfx.stop_ambience()` fades out. Volume: setting `ambience_volume` (falls back to `music_volume`) |

Missing ids are ignored silently, so code may reference ids before they exist.

**Seamless loops.** Music and ambience are rendered as the loop plus 6–8 s of tail (reverb, note releases). The tail is then folded back onto the start (`synth.loop_wrap`). Noise beds are rendered 2 s long and their tail is equal-power crossfaded into the head (`synth.loop_crossfade`). Drones and LFOs are snapped to a whole number of cycles per loop. Mastering filters run circularly (`music_gen.master_loop`). Checked: the seam jump is smaller than the 99th percentile of normal sample-to-sample change in every file.

## 3. Regenerate
From `arpg/game/` (needs `pip install numpy scipy soundfile`):
```bash
tools/audio/build_all.sh                          # everything, about 5 min on 4 cores
python3 tools/audio/sfx_gen.py                    # all SFX
python3 tools/audio/sfx_gen.py hit crit           # selected SFX ids
python3 tools/audio/sfx_gen.py --list             # print the SFX table below
python3 tools/audio/import_cc0.py                 # re-apply the 4 CC0 UI cues (run after sfx_gen)
python3 tools/audio/import_cc0.py --undo          # use our synthesized UI cues instead
python3 tools/audio/music_gen.py town boss        # selected music tracks
python3 tools/audio/ambience_gen.py amb_bog       # selected ambience loops
godot --headless --import                         # then re-import in Godot
```
Renders are deterministic: every id/variant is seeded with `crc32(id:variant)` (music and ambience with `crc32(id)`). The Python source *is* the parameter file required by THIRD_PARTY §4.

### Toolkit (`game/tools/audio/`, contains `.gdignore`)
| File | What it does |
|---|---|
| `synth.py` | DSP core: polyBLEP oscillators (sine/tri/saw/square), supersaw, 2-op FM, additive partials; white/pink/brown noise and crackle; ADSR/percussive/piecewise envelopes and exp pitch slides; Butterworth LP/HP/BP, RBJ peak, resonators, time-varying filter sweeps, vowel formant bank; Karplus-Strong pluck (vectorized), inharmonic bell, glock/celesta, marimba, metal clang; Freeverb-style reverb, feedback delay, drive, tremolo; mix/layer, trim, fade, normalize, mastering limiter, loop wrap/crossfade, WAV/OGG writers |
| `sfx_gen.py` | One small function per SFX id (registry with variant count and description) |
| `music_gen.py` | Mini sequencer (tempo, bars, chord symbols, note strings like `D5/1.5 A4/.5`), instruments (pad, choir, pluck, pizz, celesta, music box, bells, marimba, flute, clarinet, brass, basses, felt keys, drums), dry + reverb + delay buses, per-track composition functions |
| `ambience_gen.py` | Act ambience scenes: noise beds + scattered events |
| `import_cc0.py` | Converts the selected CC0 UI cues into our id layout |
| `build_all.sh` | Runs all of the above |

## 4. SFX ids
Frequent sounds have 2–4 variants. The rarity ladder is `drop_*` (§4.1). Ids marked † are **currently CC0 uisfx files** (§6); the synthesized recipe listed here is the fallback (`import_cc0.py --undo`).

| id | variants | how it is made |
|---|---|---|
| `step` | 4 | Generic soft footstep: low thump + short filtered-noise scuff. |
| `step_stone` | 4 | Hard click (bandpassed noise 1.2-5 kHz) + small heel thump. |
| `step_dirt` | 4 | Soft crunch: lowpassed pink noise + sparse crackle grains. |
| `step_wood` | 4 | Hollow knock: resonators at ~200 Hz and ~620 Hz excited by a noise tick. |
| `step_snow` | 4 | Snow crunch: dense bandpassed crackle 1.5-6 kHz over soft lowpassed hush. |
| `swing` | 4 | Light weapon swish: bandpass sweep 600->2600 Hz over white noise. |
| `heavy_swing` | 4 | Heavy swish: slower low sweep 250->1200 Hz + 80 Hz air hum. |
| `zap` | 4 | Magic bolt: square pitch-fall 1800->420 Hz with 30 Hz vibrato + sparkle. |
| `throw` | 4 | Thrown object: short whoosh with 22 Hz spin flutter. |
| `bow` | 4 | Bow release: string twang (pluck ~120 Hz) + nock click + arrow hiss. |
| `hit` | 4 | Cartoon 'bonk': sine drop 200->70 Hz + lowpassed click + tiny wood knock. |
| `crit` | 4 | Crit: bonk + bright metallic ping (inharmonic partials ~1.3 kHz) + crack. |
| `hit_player` | 4 | Player hurt: dull low thud + soft square 'oof' blip (no voice). |
| `shield_block` | 3 | Block: mid metallic clang (~420 Hz inharmonic) + wooden thump. |
| `slam` | 2 | Ground slam: sine drop 90->35 Hz + brown-noise rumble + debris crackle, reverb. |
| `monster_die` | 3 | Snuffed creature rekindled: soft 'puff' (noise sweep down) + rising spark twinkles. |
| `player_death` | 1 | Candle snuffed: soft whoosh + slow falling D-minor bell arpeggio (A4 F4 D4 A3). |
| `potion` | 2 | Drink: three rising bubble blips (sine 300->900 Hz) + glass tink + heal shimmer. |
| `gold` | 4 | Coin clink: two short inharmonic metal pings 2.4-3.2 kHz, 40 ms apart. |
| `coin_burst` | 2 | Coin cascade: ~14 coin pings with accelerating then thinning spacing. |
| `pickup` | 4 | Item pickup: soft pop (sine 600->1300 Hz) + D6 music-box tick. |
| `equip` | 3 | Equip: leather/cloth rustle + low metal clink. |
| `chest_open` | 1 | Chest: cute wooden creak (resonant saw wobble) + latch clunk + sparkly D-major reveal. |
| `salvage` | 2 | Salvage: crunchy break (crackle + noise) + scattered small clinks. |
| `level_up` | 1 | Level up: D-major fanfare arpeggio D5 F#5 A5 D6 (bells+plucks) + held chord + rising shimmer. |
| `skill_up` | 1 | Skill point: glock A5 D6 F#6 + upward whoosh. |
| `golden_moment` | 1 | Golden moment: warm 'ah' choir + pad swell on Dmaj, then D6/A6 bell hits and shimmer. |
| `craft_success` | 1 | Craft success: two anvil clangs + D-A chime. |
| `craft_fail` | 1 | Craft fail: dull clunk + soft descending 'bwomp' (A4->D4 triangle), not harsh. |
| `upgrade` | 1 | Upgrade: rising noise sweep into bright clang + sparkle arpeggio. |
| `quest_accept` | 1 | Quest accept: parchment rustle + two-note rising chime A5->D6. |
| `quest_done` | 1 | Quest complete: short brass-ish fanfare D5-F#5-A5-D6 (filtered saw) doubled by bells. |
| `npc_talk` | 4 | NPC babble (no words): 4-6 formant-filtered square syllables on D-pentatonic pitches. |
| `magpie_laugh` | 2 | Mischievous magpie chatter: 5 descending 'cha' chirps (bandpassed noise + pitched blip). |
| `pet_happy` | 3 | Pet chirp: 2-3 vibrato sine chirps 800->1600 Hz with 'ee' formant colour. |
| `pet_levelup` | 1 | Pet level up: happy chirp run + glock arpeggio D6 F#6 A6 D7 + sparkles. |
| `mount` | 1 | Mount up: cloth whoosh + springy low 'boing' + two hoof-knocks. |
| `dismount` | 1 | Dismount: short rustle + soft landing thump. |
| `portal` | 1 | Portal: detuned saw chord through LFO-swept bandpass, rising 1.4 s, with sparkles. |
| `hearth_channel` | 1 | Hearthstone channel (3 s): warm crackling candle + rising soft D pad hum. |
| `hearth_done` | 1 | Hearth arrive: whoosh + warm 'home' bells D5+A5+D6 chord. |
| `freeze` | 2 | Freeze: glassy inharmonic high bell cluster + ice crackle + hiss sweeping down. |
| `fire_burst` | 2 | Fire burst: low-mid noise whoosh with fast attack + fire crackle, gently lowpassed. |
| `lightning` | 2 | Lightning: short noise crack (lowpassed 7 kHz) + jittery saw buzz + soft rumble tail. |
| `summon` | 1 | Summon: ghostly 'oo' choir glide D3->A3 + low bell + puff. |
| `heal` | 2 | Heal: soft rising glock arpeggio D5 F#5 A5 D6 E6 over a gentle pad swell. |
| `ui_click` † | 2 | UI tap: 25 ms sine tick 1.8 kHz + tiny wood knock. |
| `menu_open` † | 1 | Menu open: paper swish up + soft tick. |
| `menu_close` † | 1 | Menu close: paper swish down + soft low tick. |
| `error` † | 1 | Error: soft low double 'bup-bup' (lowpassed square ~220 Hz). |
| `dodge` | 2 | Dodge roll: quick short swish + cloth flutter. |
| `telegraph_warn` | 1 | Boss telegraph: two soft rising 'wom' tones (filtered saw D3->A3 with tremolo). |
| `boss_roar` | 1 | Cartoon growl (not a scream): 85 Hz saw with 28 Hz growl AM, vowel 'aw'->'oh' formants, breath noise. |
| `drop_common` | 1 | Ladder 0: 80 ms music-box tick on D6. |
| `drop_magic` | 1 | Ladder 1: tick + soft bell D5 with A5 fifth. |
| `drop_rare` | 1 | Ladder 2 (Rare): two-note rising A5->D6 bell + light glitter. |
| `drop_epic` | 1 | Ladder 3 (Epic): D-major arpeggio D5 F#5 A5 D6 with bigger reverb tail + glitter. |
| `drop_legendary` | 1 | Ladder 4 (Legendary): heavy clang (D4 metal + D3 bell) + 'ah' choir Dmaj + upward sweep + arpeggio. |
| `drop_mythic` | 1 | Ladder 5 (Mythic): Legendary core + sub thump + unique 5-note stinger D5-A5-E6-F#6-A6 with ember crackle. |
| `drop_unique` | 1 | Ladder 6 (Unique): clang + choir + bright 'crown' motif D5 F#5 G#5 A5 D6 (lydian) + halo shimmer. |
| `drop_named` | 1 | Ladder 7 (Named): sub + clang + Dmaj9 choir + 'sun' leitmotif A5-D6-F#6-E6-A6 + fast halo glissando. |

### 4.1 Rarity ladder (`drop_<rarity>`, all D major)
Played by `game_world.gd` when loot drops: rank ≥ 2 at -3 dB, rank ≥ 4 at 0 dB. Each step adds layers, length and brightness. Measured spectral centroid rises from Rare upward: 1.6 → 1.7 → 2.1 → 2.6 → 2.7 → 4.0 kHz.

| Rank | Id | Length | Layers | Signature |
|---|---|---|---|---|
| 0 | `drop_common` | 0.1 s | tick | D6 music-box tick |
| 1 | `drop_magic` | 1.1 s | tick + bell | D5 + A5 fifth |
| 2 | `drop_rare` | 1.6 s | 2 bells + glitter | A5 → D6 |
| 3 | `drop_epic` | 2.9 s | arpeggio + pluck + glitter, long reverb | D5 F#5 A5 D6 |
| 4 | `drop_legendary` | 3.8 s | upward sweep → **clang** (D4 metal + D3 bell) + "ah" choir + arpeggio + shimmer | Diablo-style clang in our key |
| 5 | `drop_mythic` | 4.3 s | Legendary + **sub thump** + ember crackle | **Stinger** D5-A5-E6-F#6-A6 |
| 6 | `drop_unique` | 4.2 s | clang + choir + crown motif + halo | Lydian "crown" D5 F#5 **G#5** A5 D6 |
| 7 | `drop_named` | 4.8 s | sub + clang + Dmaj9 choir + leitmotif + fast glissando halo | **"Sun" leitmotif** A5-D6-F#6-E6-A6 |

`golden_moment` (warm choir swell + D6/A6 bells, 4.2 s) follows the drop cue for Legendary+.
Mix rule for later: drop cues should duck combat SFX by about 4 dB for 0.5 s (sidechain/duck, research §5.1). Not implemented yet (needs a bus layout).

### 4.2 Which ids are wired today
- **Called by code now:** `step`, `swing`, `heavy_swing`, `zap`, `throw`, `bow` (via `skills.json` "sfx"), `hit`, `crit`, `hit_player`, `slam`, `monster_die`, `player_death`, `potion`, `gold`, `pickup`, `equip`, `chest_open`, `level_up`, `skill_up`, `ui_click`, `dodge`, `golden_moment`, `drop_*`; music `title` plus `crypt`, `graveyard`, `town`, `boss` (via `biomes.json`/`zones.json`).
- **Ready for other systems:** `portal`, `hearth_channel` (3.6 s, play once when the channel starts), `hearth_done`, `mount`, `dismount`, `pet_happy`, `pet_levelup`, `craft_success`, `craft_fail`, `salvage`, `upgrade`, `quest_accept`, `quest_done`, `npc_talk` (babble; call per dialogue line), `magpie_laugh`, `coin_burst`, `shield_block`, `freeze`, `fire_burst`, `lightning`, `summon`, `heal`, `error`, `menu_open`, `menu_close`, `telegraph_warn` (play when a ground telegraph appears), `boss_roar`, `step_stone`, `step_dirt`, `step_wood`, `step_snow` (per-surface steps; `step` stays the generic fallback); music `forest`, `mine`, `ice`, `hush`; ambience `amb_*`.
- Suggested skill "sfx" values: fire skills `fire_burst`, frost `freeze`, storm `lightning`, minion `summon`, heals `heal`.

## 5. Music and ambience
All tracks are composed in code (`music_gen.py`): hand-written melodies for title, town, graveyard and boss, and seeded "wander" melodies (chord tones on strong beats, scale steps between) for the sparse act tracks. The title theme returns in the boss fight and, drained of colour, in Act 5.

| Id | Use | Key / tempo / length | Mood and instruments |
|---|---|---|---|
| `title` | title screen | D minor, 96 BPM, 32 bars, 80 s | Heroic but spooky. Intro (choir "oo", bells, harp arpeggio) → horn + flute theme with timpani → celesta B-section with choir "ah" → full reprise with bells, brush and a tom fill back into the loop |
| `town` | hub (every act) | F major, 84 BPM, 32 bars, 91 s | Warm and cosy. Guitar-like plucks, warm pad, round bass, music-box melody, then flute; soft shaker, woodblock and kick in the second half |
| `graveyard` | Act 1 Wickmire (bog, graveyard) | E minor, 3/4 waltz at 138 BPM, 64 bars, 83 s | Burton-style melancholy waltz: pizzicato oom-pah-pah, celesta melody, then music box + choir "oo", bell counter-melody, clarinet doubling |
| `forest` | Act 2 Whisperwood | G minor, 100 BPM, 36 bars, 86 s | Curious and sneaky: marimba ostinato, staccato bass clarinet, glass bells, woodblocks, dorian celesta in the second half |
| `mine` | Act 3 Echo Mines | C minor, 88 BPM, 32 bars, 87 s | Echoing work rhythm: low toms, plucked bass, pick "tinks", dotted-8th delay plucks and bells, rumble |
| `ice` | Act 4 Rimehall | B minor, 72 BPM, 28 bars, 93 s | Frozen court: bright pads, celesta triplet minuet arpeggios, glass bells, "ee" choir, cold wind |
| `hush` | Act 5 Well of Hush | D minor, 56 BPM, 20 bars, 86 s | Colour drained: D/A drone, the title motif on a soft felt piano, then a detuned music box, faint high tone |
| `crypt` | dungeons/crypts (any act) | A minor, 64 BPM, 20 bars, 75 s | Desolate: dark pads, A1 drone, low bells, sparse high glass, choir, wind |
| `boss` | boss zones | D minor, 138 BPM, 48 bars, 83 s | Drive without menace: 8th-note ostinato bass, kit, syncopated brass stabs, title theme on brass, choir, tom breakdown with riser. Fills every 8 bars |

| Ambience id | Act | Content |
|---|---|---|
| `amb_bog` | 1 Wickmire | low wind, water body, cute frog "rib-bits", bubble clusters, faint wisp chimes |
| `amb_forest` | 2 Whisperwood | gusting wind in branches, wood creaks, leaf rustles, twig snaps, soft owl "hoo-hoo" |
| `amb_mine` | 3 Echo Mines | deep rumble, air hum, echoing water drips, distant pick tinks, pebble trickles |
| `amb_ice` | 4 Rimehall | howling wind with a slowly sweeping whistle, fine ice hiss, ice tinkles, ice creaks |
| `amb_hush` | 5 Well of Hush | near-silence: sub rumble, faint air, slow breath-like swells, a far bell (no whispers) |

Suggested wiring (for the world/gameplay owner): add an `"ambience"` key to biomes next to `"music"` and call `Sfx.play_ambience(biome.get("ambience", ""))` alongside `play_music`. Town: `""` (or keep the act bed at low level). Future: combat layer stems (research §5.4) are not split out yet.

## 6. Provenance and licences
- **In-house:** all files except the four below. Made by our own code in `game/tools/audio/`, so we own them outright. Build-time tools: Python, numpy (BSD-3), scipy (BSD-3), soundfile/libsndfile (BSD-3 / LGPL-2.1, used as a build tool only, not shipped).
- **CC0 (uisfx 0.4.0, `docs/legal/ASSET_SOURCES.md` A-012):** `ui_click.wav` ← `soft/press.ogg`, `ui_click_1.wav` ← `organic/press.ogg`, `menu_open.wav` ← `soft/open.ogg`, `menu_close.wav` ← `soft/close.ogg`, `error.wav` ← `soft/error.ogg`. Converted only: 48 → 44.1 kHz, mono, trim, -1 dBFS peak. Kenney CC0 sounds (A-010/A-011) were reviewed but not used: our own coin, hit and step sounds fit the D-major identity better.
- Credit line in `game/assets/CREDITS.txt`.

## 7. Size budget
Target < 40 MB total. Current: see `du -sh game/assets/generated/{sfx,music}` (about 10 MB SFX as WAV + about 10 MB music/ambience as OGG). If the mobile build needs to shrink, set Godot's WAV import to QOA compression for the longer cues (drops, golden moment, death).

## 8. Known limits and next steps
- Nothing has been auditioned on a real phone speaker yet. Levels are measured, not listened to. First device pass: check `boss_roar`, `slam` and `telegraph_warn` for kid-friendliness, and footstep loudness at `volume_db` -8 to -12.
- No duck/sidechain bus yet (drop cues over combat).
- No per-act boss variants or combat stems yet. The boss track can be split into stems (bass/drums vs. pads/melody) from `t_boss()` when vertical layering is needed.

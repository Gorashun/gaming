#!/usr/bin/env python3
"""Wickwright SFX generator: every sound is synthesized from code in synth.py.

Usage (from game/):
    python3 tools/audio/sfx_gen.py                 # render all ids
    python3 tools/audio/sfx_gen.py hit crit        # render only these ids
    python3 tools/audio/sfx_gen.py --list          # markdown table of ids

Output: assets/generated/sfx/<id>.wav (+ <id>_1.wav .. <id>_4.wav variants),
44.1 kHz, 16-bit, mono, peak-normalized to -1 dBFS. Seeds are derived from the
id + variant index (crc32) so renders are reproducible byte-for-byte.

Musical identity: every tonal cue sits in D major (loot/reward family), threats
use D minor / tritone-free low 'wom' tones. Kid-friendly: no screams, no gore,
no harsh noise; monsters 'puff' into sparks.
"""
from __future__ import annotations

import sys
import zlib
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import synth as S  # noqa: E402
from synth import hz  # noqa: E402

OUT = Path(__file__).resolve().parents[2] / "assets" / "generated" / "sfx"

REG: dict[str, tuple] = {}


def sfx(id_: str, variants: int = 1, desc: str = ""):
    def deco(fn):
        REG[id_] = (fn, variants, desc)
        return fn
    return deco


# D major pentatonic (sparkles, twinkles)
PENTA = [hz(n) for n in ("D6", "E6", "F#6", "A6", "B6", "D7")]


# ---------------------------------------------------------------- building blocks
def whoosh(r, dur, f0, f1, q=1.6, color="white", shape_peak=0.45):
    n = S.noise(dur, color, r)
    band = S.sweep(n, "bp", S.slide(f0, f1, dur))
    env = S.segs([(0, 0), (dur * shape_peak, 1), (dur, 0)], dur) ** 1.5
    return band * env


def thud(f0, f1, dur, click=0.3, r=None):
    body = S.osc(S.slide(f0, f1, dur, "fast"), dur) * S.perc(dur, 0.002, dur * 0.35)
    c = S.lp(S.noise(0.015, "white", r), 2500) * S.perc(0.015, 0.0005, 0.004)
    return S.mix((body, 0, 1.0), (c, 0, click))


def twinkle(r, dur, count, spread, base=PENTA, gain=0.25, decay=0.35, rising=False):
    layers = []
    notes = sorted(r.choice(base, count)) if rising else r.choice(base, count)
    for i, f in enumerate(notes):
        t = (i / max(1, count - 1)) * spread if rising else r.uniform(0, spread)
        layers.append((S.glock(f, decay * 2.5, decay), t, gain * r.uniform(0.6, 1.0)))
    return S.mix(*layers, length=dur)


def arp(notes, gap, inst="bell", dur=1.5, decay=0.9, bright=0.8, gains=None):
    layers = []
    for i, nm in enumerate(notes):
        f = hz(nm) if isinstance(nm, str) else nm
        if inst == "bell":
            s = S.bell(f, dur, bright, decay)
        elif inst == "glock":
            s = S.glock(f, dur, decay)
        elif inst == "marimba":
            s = S.marimba(f, dur, decay)
        else:
            s = S.pluck(f, dur, 0.7)
        g = gains[i] if gains else 1.0
        layers.append((s, i * gap, g))
    return S.mix(*layers)


def choir(notes, dur, vowel="ah", attack=0.25, release=0.8, r=None):
    r = r or np.random.default_rng(1)
    out = np.zeros(S.n_samples(dur))
    for nm in notes:
        f = hz(nm) if isinstance(nm, str) else nm
        vib = f * (1 + 0.006 * S.lfo(dur, 5.2, 1.0, r.random() * 6))
        out += S.supersaw(vib, dur, 3, 0.008, r)
    out = S.formant(out, vowel)
    return out * S.adsr(dur, attack, 0.2, 0.8, release)


def pad(notes, dur, cutoff=2000, attack=0.3, release=0.8, r=None):
    r = r or np.random.default_rng(2)
    out = np.zeros(S.n_samples(dur))
    for nm in notes:
        f = hz(nm) if isinstance(nm, str) else nm
        out += S.supersaw(f, dur, 5, 0.01, r)
    return S.lp(out, cutoff) * S.adsr(dur, attack, 0.2, 0.8, release)


def rv(x, room=0.6, wet=0.25, tail=0.6, damp=0.4):
    return S.reverb(x, room, damp, wet, tail=tail)


# ---------------------------------------------------------------- footsteps
@sfx("step", 4, "Generic soft footstep: low thump + short filtered-noise scuff.")
def step(r, v):
    d = 0.11
    sc = S.bp(S.noise(d, "pink", r), 250, 1800) * S.perc(d, 0.002, 0.025)
    return S.mix((thud(r.uniform(110, 140), 55, d, 0.2, r), 0, 0.7), (sc, 0, 0.6))


@sfx("step_stone", 4, "Hard click (bandpassed noise 1.2-5 kHz) + small heel thump.")
def step_stone(r, v):
    d = 0.09
    click = S.bp(S.noise(d, "white", r), 1200, 5000) * S.perc(d, 0.0005, 0.012)
    ring = S.resonator(S.noise(d, "white", r), r.uniform(1800, 2600), 25) * S.perc(d, 0.0005, 0.02)
    return S.mix((thud(r.uniform(140, 170), 70, d, 0.1, r), 0, 0.45), (click, 0, 0.6), (ring, 0, 0.5))


@sfx("step_dirt", 4, "Soft crunch: lowpassed pink noise + sparse crackle grains.")
def step_dirt(r, v):
    d = 0.14
    body = S.lp(S.noise(d, "pink", r), 900) * S.perc(d, 0.004, 0.04)
    grit = S.bp(S.crackle(d, 250, r), 800, 3500) * S.perc(d, 0.004, 0.05)
    return S.mix((thud(r.uniform(90, 120), 50, d, 0.0, r), 0, 0.6), (body, 0, 0.8), (grit, 0, 0.5))


@sfx("step_wood", 4, "Hollow knock: resonators at ~200 Hz and ~620 Hz excited by a noise tick.")
def step_wood(r, v):
    d = 0.16
    exc = S.noise(d, "white", r) * S.perc(d, 0.0005, 0.006)
    f = r.uniform(180, 230)
    body = S.resonator(exc, f, 12) * 3 + S.resonator(exc, f * 3.1, 18) * 1.5
    return S.mix((body * S.perc(d, 0.001, 0.05), 0, 1.0), (thud(f, 70, d, 0.15, r), 0, 0.5))


@sfx("step_snow", 4, "Snow crunch: dense bandpassed crackle 1.5-6 kHz over soft lowpassed hush.")
def step_snow(r, v):
    d = 0.2
    env = S.segs([(0, 0), (0.03, 1), (0.12, 0.5), (d, 0)], d)
    grit = S.bp(S.crackle(d, 1800, r), 1500, 6000) * env
    hush = S.lp(S.noise(d, "pink", r), 1200) * env * 0.4
    return S.mix((grit, 0, 1.0), (hush, 0, 1.0), (thud(100, 50, 0.08, 0.0, r), 0, 0.3))


# ---------------------------------------------------------------- attacks
@sfx("swing", 4, "Light weapon swish: bandpass sweep 600->2600 Hz over white noise.")
def swing(r, v):
    d = r.uniform(0.18, 0.24)
    return whoosh(r, d, r.uniform(500, 700), r.uniform(2200, 3000), shape_peak=0.35)


@sfx("heavy_swing", 4, "Heavy swish: slower low sweep 250->1200 Hz + 80 Hz air hum.")
def heavy_swing(r, v):
    d = r.uniform(0.34, 0.42)
    w = whoosh(r, d, 250, r.uniform(1000, 1400), color="pink", shape_peak=0.5)
    hum = S.osc(S.slide(70, 110, d), d, "tri") * S.segs([(0, 0), (d * 0.5, 1), (d, 0)], d)
    return S.mix((w, 0, 1.0), (S.lp(hum, 400), 0, 0.25))


@sfx("zap", 4, "Magic bolt: square pitch-fall 1800->420 Hz with 30 Hz vibrato + sparkle.")
def zap(r, v):
    d = 0.3
    f = S.slide(r.uniform(1600, 2000), r.uniform(380, 460), d) * (1 + 0.04 * S.lfo(d, 30))
    tone = S.lp(S.osc(f, d, "square", 0.3), 5000) * S.perc(d, 0.003, 0.1)
    return S.mix((tone, 0, 0.6), (twinkle(r, d + 0.3, 3, 0.1, gain=0.35, decay=0.12), 0.02, 1.0))


@sfx("throw", 4, "Thrown object: short whoosh with 22 Hz spin flutter.")
def throw(r, v):
    d = 0.3
    w = whoosh(r, d, 700, 1800, shape_peak=0.3)
    return S.tremolo(w, r.uniform(18, 26), 0.7)


@sfx("bow", 4, "Bow release: string twang (pluck ~120 Hz) + nock click + arrow hiss.")
def bow(r, v):
    d = 0.4
    twang = S.pluck(r.uniform(105, 130), d, 0.9, 0.99, r) * S.perc(d, 0.001, 0.08)
    click = S.hp(S.noise(0.01, "white", r), 2000) * S.perc(0.01, 0.0003, 0.002)
    hiss = whoosh(r, 0.22, 3000, 1800, shape_peak=0.15)
    return S.mix((twang, 0, 0.9), (click, 0, 0.4), (hiss, 0.02, 0.35))


# ---------------------------------------------------------------- impacts
@sfx("hit", 4, "Cartoon 'bonk': sine drop 200->70 Hz + lowpassed click + tiny wood knock.")
def hit(r, v):
    d = 0.16
    k = S.resonator(S.noise(d, "white", r) * S.perc(d, 0.0005, 0.004), r.uniform(500, 700), 10) * 2
    return S.mix((thud(r.uniform(180, 220), 70, d, 0.6, r), 0, 1.0), (k * S.perc(d, 0.0, 0.03), 0, 0.5))


@sfx("crit", 4, "Crit: bonk + bright metallic ping (inharmonic partials ~1.3 kHz) + crack.")
def crit(r, v):
    d = 0.45
    ping = S.metal_clang(r.uniform(1200, 1450), d, 0.12)
    crack = S.bp(S.noise(0.05, "white", r), 1500, 6000) * S.perc(0.05, 0.0005, 0.01)
    return S.mix((thud(220, 60, 0.2, 0.8, r), 0, 1.0), (ping, 0.005, 0.45), (crack, 0, 0.5))


@sfx("hit_player", 4, "Player hurt: dull low thud + soft square 'oof' blip (no voice).")
def hit_player(r, v):
    d = 0.25
    oof = S.lp(S.osc(S.slide(r.uniform(300, 340), 190, d), d, "square"), 1200) * S.perc(d, 0.01, 0.07)
    return S.mix((thud(140, 45, d, 0.3, r), 0, 1.0), (oof, 0.01, 0.3))


@sfx("shield_block", 3, "Block: mid metallic clang (~420 Hz inharmonic) + wooden thump.")
def shield_block(r, v):
    d = 0.5
    cl = S.metal_clang(r.uniform(380, 460), d, 0.14)
    return rv(S.mix((cl, 0, 0.6), (thud(160, 70, 0.15, 0.6, r), 0, 0.8)), 0.4, 0.12, 0.2)


@sfx("slam", 2, "Ground slam: sine drop 90->35 Hz + brown-noise rumble + debris crackle, reverb.")
def slam(r, v):
    d = 0.7
    boom = S.osc(S.slide(95, 35, d, "fast"), d) * S.perc(d, 0.003, 0.22)
    boom = S.drive(boom * 1.5, 1.5)
    rumble = S.lp(S.noise(d, "brown", r), 300) * S.perc(d, 0.01, 0.25)
    debris = S.bp(S.crackle(d, 90, r), 600, 3000) * S.perc(d, 0.03, 0.25)
    # upper harmonic so it reads on phone speakers
    harm = S.osc(S.slide(190, 70, d, "fast"), d, "tri") * S.perc(d, 0.003, 0.12)
    return rv(S.mix((boom, 0, 1.0), (rumble, 0, 0.6), (debris, 0.03, 0.4), (harm, 0, 0.35)), 0.6, 0.2, 0.5)


@sfx("monster_die", 3, "Snuffed creature rekindled: soft 'puff' (noise sweep down) + rising spark twinkles.")
def monster_die(r, v):
    d = 0.9
    puff = S.sweep(S.noise(0.35, "pink", r), "lp", S.slide(3000, 300, 0.35)) * S.perc(0.35, 0.01, 0.1)
    sparks = twinkle(r, d, 4, 0.35, gain=0.3, decay=0.18, rising=True)
    return rv(S.mix((puff, 0, 1.0), (sparks, 0.08, 1.0)), 0.5, 0.2, 0.3)


@sfx("player_death", 1, "Candle snuffed: soft whoosh + slow falling D-minor bell arpeggio (A4 F4 D4 A3).")
def player_death(r, v):
    snuff = whoosh(r, 0.5, 1800, 300, color="pink", shape_peak=0.2)
    bells = arp(["A4", "F4", "D4", "A3"], 0.32, "bell", 2.4, 1.2, 0.5, [0.8, 0.8, 0.9, 1.0])
    low = S.osc(hz("D2"), 2.5) * S.adsr(2.5, 0.4, 0.3, 0.6, 1.2) * 0.25
    return rv(S.mix((snuff, 0, 0.7), (bells, 0.15, 0.6), (S.lp(low, 300), 0.3, 1.0)), 0.8, 0.3, 1.2)


# ---------------------------------------------------------------- items / economy
@sfx("potion", 2, "Drink: three rising bubble blips (sine 300->900 Hz) + glass tink + heal shimmer.")
def potion(r, v):
    layers = []
    for i in range(3):
        d = 0.08
        f0 = r.uniform(280, 380) * (1 + 0.25 * i)
        b = S.osc(S.slide(f0, f0 * 2.6, d), d) * S.perc(d, 0.004, 0.03)
        layers.append((b, 0.07 * i, 0.8))
    layers.append((S.glock(hz("A6"), 0.4, 0.15), 0.0, 0.25))
    layers.append((arp(["D6", "F#6", "A6"], 0.05, "glock", 0.6, 0.2), 0.25, 0.35))
    return rv(S.mix(*layers), 0.4, 0.15, 0.3)


def coin(r, f=None, dur=0.25):
    f = f or r.uniform(2400, 3200)
    return S.metal_clang(f, dur, 0.06) * 0.8 + S.glock(f * 1.5, dur, 0.05) * 0.3


@sfx("gold", 4, "Coin clink: two short inharmonic metal pings 2.4-3.2 kHz, 40 ms apart.")
def gold(r, v):
    return S.mix((coin(r), 0, 1.0), (coin(r), r.uniform(0.03, 0.06), 0.7))


@sfx("coin_burst", 2, "Coin cascade: ~14 coin pings with accelerating then thinning spacing.")
def coin_burst(r, v):
    layers = []
    t = 0.0
    for i in range(14):
        layers.append((coin(r), t, r.uniform(0.4, 1.0)))
        t += r.uniform(0.02, 0.07) * (1 + i / 10)
    return rv(S.mix(*layers), 0.3, 0.1, 0.2)


@sfx("pickup", 4, "Item pickup: soft pop (sine 600->1300 Hz) + D6 music-box tick.")
def pickup(r, v):
    d = 0.08
    pop = S.osc(S.slide(r.uniform(550, 650), r.uniform(1200, 1400), d), d) * S.perc(d, 0.002, 0.03)
    return S.mix((pop, 0, 0.8), (S.glock(r.choice(PENTA[:3]), 0.3, 0.08), 0.03, 0.35))


@sfx("equip", 3, "Equip: leather/cloth rustle + low metal clink.")
def equip(r, v):
    rustle = S.bp(S.noise(0.2, "pink", r), 700, 4000) * S.segs([(0, 0), (0.04, 1), (0.08, 0.3), (0.12, 0.8), (0.2, 0)], 0.2)
    clink = S.metal_clang(r.uniform(700, 900), 0.3, 0.07)
    return S.mix((rustle, 0, 0.7), (clink, 0.1, 0.5))


@sfx("chest_open", 1, "Chest: cute wooden creak (resonant saw wobble) + latch clunk + sparkly D-major reveal.")
def chest_open(r, v):
    cd = 0.45
    f = S.slide(160, 240, cd) * (1 + 0.08 * S.lfo(cd, 13))
    creak = S.bp(S.osc(f, cd, "saw"), 400, 2200) * S.segs([(0, 0), (0.05, 1), (cd - 0.05, 0.8), (cd, 0)], cd)
    latch = thud(170, 70, 0.15, 0.7, r)
    reveal = arp(["D5", "F#5", "A5", "D6"], 0.06, "glock", 1.2, 0.35)
    return rv(S.mix((latch, 0, 0.9), (creak, 0.08, 0.35), (reveal, 0.5, 0.5),
                    (twinkle(r, 1.0, 5, 0.4, gain=0.2), 0.55, 1.0)), 0.5, 0.2, 0.5)


@sfx("salvage", 2, "Salvage: crunchy break (crackle + noise) + scattered small clinks.")
def salvage(r, v):
    br = S.bp(S.crackle(0.25, 600, r) + 0.3 * S.noise(0.25, "pink", r), 500, 5000) * S.perc(0.25, 0.002, 0.07)
    clinks = S.mix(*[(coin(r, r.uniform(1500, 2500), 0.2), r.uniform(0.05, 0.3), 0.3) for _ in range(4)])
    return S.mix((br, 0, 1.0), (thud(150, 60, 0.12, 0.3, r), 0, 0.6), (clinks, 0, 1.0))


# ---------------------------------------------------------------- progression
@sfx("level_up", 1, "Level up: D-major fanfare arpeggio D5 F#5 A5 D6 (bells+plucks) + held chord + rising shimmer.")
def level_up(r, v):
    a = arp(["D5", "F#5", "A5", "D6"], 0.09, "bell", 2.0, 1.1, 0.9)
    p = S.mix(*[(S.pluck(hz(n), 1.2, 0.8, 0.997, r), i * 0.09, 0.5) for i, n in enumerate(["D4", "F#4", "A4", "D5"])])
    ch = pad(["D4", "A4", "D5", "F#5"], 1.8, 3000, 0.3, 1.0, r) * 0.35
    sh = S.hp(S.noise(1.2, "white", r), 5000) * S.segs([(0, 0), (0.8, 0.25), (1.2, 0)], 1.2)
    return rv(S.mix((a, 0, 0.6), (p, 0, 1.0), (ch, 0.3, 1.0), (sh, 0.1, 0.25),
                    (twinkle(r, 1.2, 6, 0.6, gain=0.2, rising=True), 0.4, 1.0)), 0.7, 0.28, 1.0)


@sfx("skill_up", 1, "Skill point: glock A5 D6 F#6 + upward whoosh.")
def skill_up(r, v):
    return rv(S.mix((arp(["A5", "D6", "F#6"], 0.07, "glock", 0.8, 0.35), 0, 0.7),
                    (whoosh(r, 0.35, 800, 5000, shape_peak=0.8), 0, 0.3)), 0.5, 0.2, 0.5)


@sfx("golden_moment", 1, "Golden moment: warm 'ah' choir + pad swell on Dmaj, then D6/A6 bell hits and shimmer.")
def golden_moment(r, v):
    d = 3.0
    c = choir(["D4", "A4", "D5", "F#5"], d, "ah", 0.5, 1.2, r)
    p = pad(["D3", "A3", "D4"], d, 1500, 0.6, 1.2, r)
    bells = S.mix((S.bell(hz("D6"), 2.5, 0.9, 1.4), 0, 1.0), (S.bell(hz("A6"), 2.2, 0.9, 1.2), 0.18, 0.7))
    sh = S.hp(S.noise(d, "white", r), 6000) * S.segs([(0, 0), (0.7, 0.2), (d, 0)], d)
    return rv(S.mix((c, 0, 0.45), (p, 0, 0.3), (bells, 0.55, 0.5), (sh, 0, 0.3),
                    (twinkle(r, 2.0, 8, 1.2, gain=0.18), 0.6, 1.0)), 0.8, 0.3, 1.2)


@sfx("craft_success", 1, "Craft success: two anvil clangs + D-A chime.")
def craft_success(r, v):
    an = lambda: S.metal_clang(r.uniform(900, 1000), 0.5, 0.12)
    return rv(S.mix((an(), 0, 0.6), (an(), 0.22, 0.7), (arp(["D6", "A6"], 0.09, "bell", 1.2, 0.7), 0.45, 0.5)), 0.5, 0.2, 0.5)


@sfx("craft_fail", 1, "Craft fail: dull clunk + soft descending 'bwomp' (A4->D4 triangle), not harsh.")
def craft_fail(r, v):
    d = 0.45
    bw = S.lp(S.osc(S.slide(hz("A3"), hz("D3"), d), d, "tri"), 900) * S.adsr(d, 0.01, 0.1, 0.6, 0.2)
    return S.mix((thud(130, 60, 0.15, 0.5, r), 0, 0.8), (bw, 0.08, 0.6))


@sfx("upgrade", 1, "Upgrade: rising noise sweep into bright clang + sparkle arpeggio.")
def upgrade(r, v):
    rise = whoosh(r, 0.5, 400, 6000, shape_peak=0.95)
    cl = S.metal_clang(hz("D6") * 1.0, 0.8, 0.25)
    return rv(S.mix((rise, 0, 0.5), (cl, 0.48, 0.4), (arp(["D6", "F#6", "A6", "D7"], 0.05, "glock", 0.8, 0.25), 0.5, 0.5)), 0.6, 0.25, 0.6)


# ---------------------------------------------------------------- quests / npcs
@sfx("quest_accept", 1, "Quest accept: parchment rustle + two-note rising chime A5->D6.")
def quest_accept(r, v):
    rustle = S.bp(S.noise(0.25, "white", r), 1500, 7000) * S.segs([(0, 0), (0.03, 1), (0.1, 0.3), (0.15, 0.7), (0.25, 0)], 0.25)
    return rv(S.mix((rustle, 0, 0.35), (arp(["A5", "D6"], 0.12, "bell", 1.0, 0.6), 0.1, 0.6)), 0.5, 0.2, 0.5)


@sfx("quest_done", 1, "Quest complete: short brass-ish fanfare D5-F#5-A5-D6 (filtered saw) doubled by bells.")
def quest_done(r, v):
    layers = []
    rhythm = [("D5", 0.0, 0.14), ("F#5", 0.14, 0.14), ("A5", 0.28, 0.14), ("D6", 0.45, 0.9)]
    for nm, t, d in rhythm:
        f = hz(nm)
        b = S.supersaw(f * (1 + 0.003 * S.lfo(d, 5)), d, 3, 0.006, r)
        b = S.sweep(b, "lp", S.slide(900, 3500, d, "fast")) * S.adsr(d, 0.02, 0.05, 0.8, min(0.1, d * 0.4))
        layers += [(b, t, 0.35), (S.bell(f, 1.2, 0.7, 0.6), t, 0.35)]
    return rv(S.mix(*layers), 0.6, 0.25, 0.8)


@sfx("npc_talk", 4, "NPC babble (no words): 4-6 formant-filtered square syllables on D-pentatonic pitches.")
def npc_talk(r, v):
    layers = []
    t = 0.0
    base = [hz(n) for n in ("A3", "B3", "D4", "E4", "F#4", "A4")]
    for _ in range(r.integers(4, 7)):
        d = r.uniform(0.05, 0.09)
        f = r.choice(base) * r.uniform(0.98, 1.02)
        syl = S.osc(S.slide(f, f * r.uniform(0.9, 1.15), d), d, "square", 0.35)
        syl = S.formant(syl, r.choice(["ah", "oh", "ee", "oo"])) * S.adsr(d, 0.008, 0.02, 0.7, 0.02)
        layers.append((syl, t, 1.0))
        t += d + r.uniform(0.015, 0.04)
    return S.mix(*layers)


@sfx("magpie_laugh", 2, "Mischievous magpie chatter: 5 descending 'cha' chirps (bandpassed noise + pitched blip).")
def magpie_laugh(r, v):
    layers = []
    f = r.uniform(2300, 2700)
    for i in range(5):
        d = 0.07
        cha = S.bp(S.noise(d, "white", r), f * 0.7, f * 1.5) * S.perc(d, 0.003, 0.025)
        chirp = S.osc(S.slide(f * 0.9, f * 0.6, d), d, "tri") * S.perc(d, 0.003, 0.03)
        layers.append((S.mix((cha, 0, 0.8), (chirp, 0, 0.35)), i * r.uniform(0.09, 0.11), 1.0))
        f *= 0.93
    return rv(S.mix(*layers), 0.3, 0.1, 0.2)


# ---------------------------------------------------------------- pets / mounts
@sfx("pet_happy", 3, "Pet chirp: 2-3 vibrato sine chirps 800->1600 Hz with 'ee' formant colour.")
def pet_happy(r, v):
    layers = []
    for i in range(r.integers(2, 4)):
        d = r.uniform(0.09, 0.13)
        f0 = r.uniform(750, 950) * (1 + 0.12 * i)
        f = S.slide(f0, f0 * r.uniform(1.6, 2.0), d) * (1 + 0.03 * S.lfo(d, 28))
        c = S.osc(f, d) + 0.3 * S.osc(f * 2, d, "tri")
        layers.append((c * S.adsr(d, 0.01, 0.03, 0.7, 0.03), i * (d + 0.03), 0.8))
    return rv(S.mix(*layers), 0.3, 0.12, 0.2)


@sfx("pet_levelup", 1, "Pet level up: happy chirp run + glock arpeggio D6 F#6 A6 D7 + sparkles.")
def pet_levelup(r, v):
    ch = pet_happy(r, 0)
    return rv(S.mix((ch, 0, 0.6), (arp(["D6", "F#6", "A6", "D7"], 0.07, "glock", 1.0, 0.3), 0.25, 0.5),
                    (twinkle(r, 1.0, 6, 0.5, gain=0.2), 0.3, 1.0)), 0.5, 0.2, 0.5)


@sfx("mount", 1, "Mount up: cloth whoosh + springy low 'boing' + two hoof-knocks.")
def mount(r, v):
    w = whoosh(r, 0.25, 500, 2000, color="pink")
    boing = S.osc(S.slide(110, 220, 0.25) * (1 + 0.05 * S.lfo(0.25, 18)), 0.25, "tri") * S.perc(0.25, 0.005, 0.08)
    knock = lambda f: S.resonator(S.noise(0.12, "white", r) * S.perc(0.12, 0.0005, 0.005), f, 10) * 3 * S.perc(0.12, 0, 0.04)
    return S.mix((w, 0, 0.5), (S.lp(boing, 1500), 0.15, 0.6), (knock(420), 0.32, 0.6), (knock(380), 0.45, 0.5))


@sfx("dismount", 1, "Dismount: short rustle + soft landing thump.")
def dismount(r, v):
    w = whoosh(r, 0.2, 1500, 500, color="pink")
    return S.mix((w, 0, 0.5), (thud(120, 50, 0.2, 0.3, r), 0.15, 0.9))


# ---------------------------------------------------------------- travel
@sfx("portal", 1, "Portal: detuned saw chord through LFO-swept bandpass, rising 1.4 s, with sparkles.")
def portal(r, v):
    d = 1.6
    base = S.mix(*[(S.supersaw(hz(n) * S.slide(0.8, 1.0, d), d, 3, 0.02, r), 0, 1.0) for n in ("D3", "A3", "D4")])
    cut = 700 + 500 * (1 + S.lfo(d, 3.0)) + S.slide(1, 2000, d, "lin")
    sw = S.sweep(base, "bp", cut) * S.adsr(d, 0.3, 0.2, 0.8, 0.5)
    return rv(S.mix((sw, 0, 0.8), (twinkle(r, d, 8, 1.0, gain=0.2, rising=True), 0.2, 1.0)), 0.7, 0.3, 0.8)


@sfx("hearth_channel", 1, "Hearthstone channel (3 s): warm crackling candle + rising soft D pad hum.")
def hearth_channel(r, v):
    d = 3.0
    crack = S.bp(S.crackle(d, 40, r), 800, 5000) * 0.8 + S.lp(S.noise(d, "brown", r), 500) * 0.3
    crack *= S.segs([(0, 0), (0.3, 1), (d - 0.2, 1), (d, 0)], d)
    hum = pad(["D4", "A4", "D5"], d, 1200, 2.0, 0.5, r) * S.slide(0.3, 1.0, d, "lin")
    return rv(S.mix((crack, 0, 0.5), (hum, 0, 0.5), (twinkle(r, d, 6, 2.6, gain=0.12, rising=True), 0.2, 1.0)), 0.6, 0.25, 0.4)


@sfx("hearth_done", 1, "Hearth arrive: whoosh + warm 'home' bells D5+A5+D6 chord.")
def hearth_done(r, v):
    w = whoosh(r, 0.5, 3000, 400, color="pink", shape_peak=0.2)
    ch = S.mix((S.bell(hz("D5"), 1.6, 0.6, 1.0), 0, 1), (S.bell(hz("A5"), 1.6, 0.6, 0.9), 0.03, 0.8),
               (S.bell(hz("D6"), 1.6, 0.6, 0.8), 0.06, 0.6))
    return rv(S.mix((w, 0, 0.6), (ch, 0.25, 0.5), (pad(["D4", "F#4", "A4"], 1.4, 1500, 0.2, 0.8, r), 0.25, 0.3)), 0.7, 0.3, 0.8)


# ---------------------------------------------------------------- elements / skills
@sfx("freeze", 2, "Freeze: glassy inharmonic high bell cluster + ice crackle + hiss sweeping down.")
def freeze(r, v):
    d = 0.8
    glass = S.mix(*[(S.bell(r.uniform(2000, 3600), d, 1.0, 0.3), r.uniform(0, 0.08), 0.3) for _ in range(4)])
    ice = S.hp(S.crackle(d, 500, r), 3000) * S.perc(d, 0.005, 0.2)
    hiss = S.sweep(S.noise(d, "white", r), "bp", S.slide(8000, 2500, d)) * S.perc(d, 0.01, 0.2)
    return rv(S.mix((glass, 0, 0.7), (ice, 0, 0.5), (hiss, 0, 0.25)), 0.6, 0.3, 0.5, damp=0.2)


@sfx("fire_burst", 2, "Fire burst: low-mid noise whoosh with fast attack + fire crackle, gently lowpassed.")
def fire_burst(r, v):
    d = 0.75
    body = S.sweep(S.noise(d, "pink", r), "lp", S.slide(4000, 600, d)) * S.perc(d, 0.02, 0.22)
    rumble = S.lp(S.noise(d, "brown", r), 250) * S.perc(d, 0.01, 0.2)
    crack = S.bp(S.crackle(d, 60, r), 1000, 6000) * S.perc(d, 0.05, 0.35)
    return S.mix((body, 0, 1.0), (rumble, 0, 0.5), (crack, 0, 0.5))


@sfx("lightning", 2, "Lightning: short noise crack (lowpassed 7 kHz) + jittery saw buzz + soft rumble tail.")
def lightning(r, v):
    d = 1.0
    crack = S.lp(S.noise(0.12, "white", r), 7000) * S.perc(0.12, 0.0005, 0.025)
    jit = 90 * (1 + 0.3 * S.lp(S.noise(0.3, "white", r), 60) * 8)
    buzz = S.bp(S.osc(jit, 0.3, "saw"), 300, 3000) * S.perc(0.3, 0.002, 0.08)
    rumble = S.lp(S.noise(d, "brown", r), 200) * S.segs([(0, 0), (0.1, 1), (d, 0)], d)
    return rv(S.mix((crack, 0, 1.0), (buzz, 0.005, 0.5), (rumble, 0.05, 0.5)), 0.7, 0.2, 0.5)


@sfx("summon", 1, "Summon: ghostly 'oo' choir glide D3->A3 + low bell + puff.")
def summon(r, v):
    d = 1.2
    gl = S.supersaw(hz("D3") * S.slide(1.0, 1.5, d), d, 4, 0.015, r)
    gl = S.formant(gl, "oo") * S.adsr(d, 0.3, 0.2, 0.8, 0.5)
    puff = S.sweep(S.noise(0.3, "pink", r), "lp", S.slide(2500, 300, 0.3)) * S.perc(0.3, 0.01, 0.08)
    return rv(S.mix((gl, 0, 0.8), (S.bell(hz("D4"), 1.5, 0.6, 1.0), 0.8, 0.4), (puff, 0.85, 0.6)), 0.7, 0.3, 0.8)


@sfx("heal", 2, "Heal: soft rising glock arpeggio D5 F#5 A5 D6 E6 over a gentle pad swell.")
def heal(r, v):
    notes = ["D5", "F#5", "A5", "D6", "E6"] if v == 0 else ["A4", "D5", "F#5", "A5", "D6"]
    return rv(S.mix((arp(notes, 0.07, "glock", 1.0, 0.4), 0, 0.5),
                    (pad(["D4", "A4", "F#5"], 0.9, 1800, 0.25, 0.5, r), 0, 0.3)), 0.6, 0.25, 0.6)


# ---------------------------------------------------------------- UI (overridden by CC0 uisfx where noted in AUDIO.md)
@sfx("ui_click", 2, "UI tap: 25 ms sine tick 1.8 kHz + tiny wood knock.")
def ui_click(r, v):
    d = 0.05
    t = S.osc(r.uniform(1700, 1900), d) * S.perc(d, 0.001, 0.008)
    k = S.resonator(S.noise(d, "white", r) * S.perc(d, 0, 0.002), 900, 12) * S.perc(d, 0, 0.012) * 2
    return S.mix((t, 0, 0.6), (k, 0, 0.6))


@sfx("menu_open", 1, "Menu open: paper swish up + soft tick.")
def menu_open(r, v):
    return S.mix((whoosh(r, 0.16, 900, 3500, shape_peak=0.7), 0, 0.6), (S.glock(hz("A6"), 0.25, 0.05), 0.12, 0.3))


@sfx("menu_close", 1, "Menu close: paper swish down + soft low tick.")
def menu_close(r, v):
    return S.mix((whoosh(r, 0.16, 3500, 900, shape_peak=0.3), 0, 0.6), (S.glock(hz("D6"), 0.25, 0.05), 0.1, 0.3))


@sfx("error", 1, "Error: soft low double 'bup-bup' (lowpassed square ~220 Hz).")
def error(r, v):
    b = lambda: S.lp(S.osc(220, 0.09, "square"), 900) * S.adsr(0.09, 0.005, 0.02, 0.7, 0.03)
    return S.mix((b(), 0, 1.0), (b() * 0.9, 0.12, 1.0))


@sfx("dodge", 2, "Dodge roll: quick short swish + cloth flutter.")
def dodge(r, v):
    w = whoosh(r, 0.18, 1200, 2800, color="pink", shape_peak=0.3)
    return S.mix((S.tremolo(w, 35, 0.4), 0, 1.0))


# ---------------------------------------------------------------- threats (readable, not scary)
@sfx("telegraph_warn", 1, "Boss telegraph: two soft rising 'wom' tones (filtered saw D3->A3 with tremolo).")
def telegraph_warn(r, v):
    d = 0.3
    wom = lambda: S.sweep(S.osc(S.slide(hz("D3"), hz("A3"), d), d, "saw"), "lp", S.slide(300, 1800, d)) * S.adsr(d, 0.03, 0.05, 0.8, 0.08)
    return rv(S.tremolo(S.mix((wom(), 0, 1.0), (wom(), 0.34, 1.0)), 12, 0.3), 0.5, 0.2, 0.3)


@sfx("boss_roar", 1, "Cartoon growl (not a scream): 85 Hz saw with 28 Hz growl AM, vowel 'aw'->'oh' formants, breath noise.")
def boss_roar(r, v):
    d = 1.4
    f = S.slide(95, 75, d) * (1 + 0.02 * S.lfo(d, 6))
    src = S.osc(f, d, "saw") * (0.7 + 0.3 * S.lfo(d, 28))
    a = S.formant(src, "aw")
    o = S.formant(src, "oh")
    x = S.segs([(0, 1), (d, 0)], d)
    voice = (a * x + o * (1 - x)) * S.adsr(d, 0.12, 0.2, 0.8, 0.5)
    breath = S.bp(S.noise(d, "pink", r), 300, 2500) * S.adsr(d, 0.1, 0.2, 0.5, 0.6)
    sub = S.osc(f / 2, d) * S.adsr(d, 0.1, 0.2, 0.7, 0.5)
    return rv(S.mix((S.drive(voice * 2, 1.5), 0, 0.9), (breath, 0, 0.25), (sub, 0, 0.35)), 0.7, 0.25, 0.8)


# ---------------------------------------------------------------- rarity ladder (all in D major)
@sfx("drop_common", 1, "Ladder 0: 80 ms music-box tick on D6.")
def drop_common(r, v):
    return S.mix((S.glock(hz("D6"), 0.12, 0.03), 0, 1.0), (thud(400, 200, 0.03, 0.4, r), 0, 0.2))


@sfx("drop_magic", 1, "Ladder 1: tick + soft bell D5 with A5 fifth.")
def drop_magic(r, v):
    return rv(S.mix((drop_common(r, 0), 0, 0.5), (S.bell(hz("D5"), 0.8, 0.5, 0.4), 0.02, 0.5),
                    (S.bell(hz("A5"), 0.8, 0.5, 0.35), 0.02, 0.35)), 0.4, 0.15, 0.3)


@sfx("drop_rare", 1, "Ladder 2 (Rare): two-note rising A5->D6 bell + light glitter.")
def drop_rare(r, v):
    return rv(S.mix((arp(["A5", "D6"], 0.1, "bell", 1.0, 0.5, 0.7), 0, 0.6),
                    (twinkle(r, 0.8, 4, 0.3, gain=0.15), 0.12, 1.0)), 0.5, 0.2, 0.5)


@sfx("drop_epic", 1, "Ladder 3 (Epic): D-major arpeggio D5 F#5 A5 D6 with bigger reverb tail + glitter.")
def drop_epic(r, v):
    return rv(S.mix((arp(["D5", "F#5", "A5", "D6"], 0.09, "bell", 1.6, 0.9, 0.85), 0, 0.6),
                    (arp(["D4", "A4"], 0.0, "pluck", 1.2), 0, 0.3),
                    (twinkle(r, 1.2, 6, 0.6, gain=0.15, rising=True), 0.2, 1.0)), 0.7, 0.3, 1.0)


def _clang_core(r, d=2.2):
    """Legendary 'clang' family core: heavy metal hit on D4 + low bell D3."""
    cl = S.metal_clang(hz("D4"), d, 0.5) * 0.7 + S.bell(hz("D3"), d, 0.6, 1.2) * 0.6
    return S.mix((cl, 0, 1.0), (thud(160, 60, 0.2, 0.8, r), 0, 0.5))


@sfx("drop_legendary", 1, "Ladder 4 (Legendary): heavy clang (D4 metal + D3 bell) + 'ah' choir Dmaj + upward sweep + arpeggio.")
def drop_legendary(r, v):
    d = 2.6
    sweep = whoosh(r, 0.6, 300, 6000, shape_peak=0.9)
    return rv(S.mix((sweep, 0, 0.3), (_clang_core(r), 0.55, 0.8),
                    (choir(["D4", "A4", "D5", "F#5"], 2.0, "ah", 0.15, 1.0, r), 0.55, 0.35),
                    (arp(["D5", "F#5", "A5", "D6"], 0.07, "bell", 1.6, 0.9, 0.9), 0.6, 0.45),
                    (twinkle(r, 1.5, 8, 0.8, gain=0.2, rising=True), 0.65, 1.0),
                    (S.hp(S.noise(1.6, "white", r), 5500) * S.segs([(0, 0), (0.2, 0.2), (1.6, 0)], 1.6), 0.6, 1.0),
                    length=d), 0.8, 0.3, 1.2)


@sfx("drop_mythic", 1, "Ladder 5 (Mythic): Legendary core + sub thump + unique 5-note stinger D5-A5-E6-F#6-A6 with ember crackle.")
def drop_mythic(r, v):
    d = 3.0
    sub = S.osc(S.slide(70, 38, 0.6, "fast"), 0.6) * S.perc(0.6, 0.003, 0.2)
    sub = sub + 0.3 * S.osc(S.slide(140, 76, 0.6, "fast"), 0.6, "tri") * S.perc(0.6, 0.003, 0.15)
    sting = arp(["D5", "A5", "E6", "F#6", "A6"], 0.11, "bell", 2.0, 1.1, 1.0, [0.8, 0.8, 0.9, 1.0, 1.1])
    ember = S.bp(S.crackle(1.6, 50, r), 2000, 8000) * S.segs([(0, 0), (0.3, 1), (1.6, 0)], 1.6)
    return rv(S.mix((whoosh(r, 0.6, 300, 7000, shape_peak=0.9), 0, 0.3), (sub, 0.55, 0.8), (_clang_core(r), 0.55, 0.7),
                    (choir(["D4", "A4", "D5", "F#5", "A5"], 2.4, "ah", 0.15, 1.2, r), 0.55, 0.35),
                    (sting, 0.62, 0.5), (ember, 0.6, 0.35),
                    (S.hp(S.noise(1.8, "white", r), 5500) * S.segs([(0, 0), (0.2, 0.25), (1.8, 0)], 1.8), 0.6, 1.0),
                    length=d), 0.85, 0.3, 1.3)


@sfx("drop_unique", 1, "Ladder 6 (Unique): clang + choir + bright 'crown' motif D5 F#5 G#5 A5 D6 (lydian) + halo shimmer.")
def drop_unique(r, v):
    d = 2.9
    crown = arp(["D5", "F#5", "G#5", "A5", "D6"], 0.08, "bell", 1.8, 1.0, 1.1)
    sh = S.hp(S.noise(1.8, "white", r), 6000) * S.segs([(0, 0), (0.2, 0.3), (1.8, 0)], 1.8)
    return rv(S.mix((whoosh(r, 0.6, 400, 7000, shape_peak=0.9), 0, 0.3), (_clang_core(r), 0.55, 0.75),
                    (choir(["D4", "A4", "D5", "F#5", "A5"], 2.2, "ah", 0.12, 1.1, r), 0.55, 0.4),
                    (crown, 0.6, 0.55), (sh, 0.6, 0.3),
                    (twinkle(r, 1.6, 10, 0.9, gain=0.14, rising=True), 0.7, 1.0), length=d), 0.85, 0.3, 1.3)


@sfx("drop_named", 1, "Ladder 7 (Named): sub + clang + Dmaj9 choir + 'sun' leitmotif A5-D6-F#6-E6-A6 + fast halo glissando.")
def drop_named(r, v):
    d = 3.4
    sub = S.osc(S.slide(75, 40, 0.6, "fast"), 0.6) * S.perc(0.6, 0.003, 0.2)
    motif = S.mix(*[(S.bell(hz(n), 2.0, 1.1, 1.1 if i == 4 else 0.7), t, g) for i, (n, t, g) in enumerate(
        [("A5", 0.0, 0.8), ("D6", 0.16, 0.85), ("F#6", 0.32, 0.9), ("E6", 0.44, 0.8), ("A6", 0.62, 1.1)])])
    gl_notes = [hz(n) for n in ("D6", "E6", "F#6", "A6", "B6", "D7", "E7", "F#7", "A7")]
    gliss = S.mix(*[(S.glock(f, 0.5, 0.12), i * 0.025, 0.25) for i, f in enumerate(gl_notes)])
    halo = S.hp(S.noise(2.2, "white", r), 5000) * S.segs([(0, 0), (0.3, 0.35), (2.2, 0)], 2.2)
    return rv(S.mix((whoosh(r, 0.6, 400, 8000, shape_peak=0.9), 0, 0.3), (sub, 0.55, 0.8), (_clang_core(r), 0.55, 0.7),
                    (choir(["D4", "A4", "E5", "F#5", "C#6"], 2.6, "ah", 0.12, 1.2, r), 0.55, 0.4),
                    (motif, 0.62, 0.55), (gliss, 1.35, 1.0), (halo, 0.6, 0.25), length=d), 0.85, 0.3, 1.4)


# ---------------------------------------------------------------- driver
def variant_path(id_: str, v: int) -> Path:
    return OUT / (f"{id_}.wav" if v == 0 else f"{id_}_{v}.wav")


def render(id_: str) -> list[Path]:
    fn, nv, _ = REG[id_]
    paths = []
    for v in range(nv):
        r = np.random.default_rng(zlib.crc32(f"{id_}:{v}".encode()))
        x = fn(r, v)
        x = S.trim_silence(x, -62.0)
        x = S.fade(x, 0.001, 0.02)
        p = variant_path(id_, v)
        S.write_wav(p, x, -1.0)
        paths.append(p)
    # remove stale variants beyond the current count
    for v in range(nv, 5):
        sp = variant_path(id_, v)
        if sp.exists():
            sp.unlink()
            imp = sp.with_suffix(".wav.import")
            if imp.exists():
                imp.unlink()
    return paths


def main(argv):
    if "--list" in argv:
        print("| id | variants | how it is made |\n|---|---|---|")
        for k, (fn, nv, desc) in REG.items():
            print(f"| `{k}` | {nv} | {desc} |")
        return
    ids = [a for a in argv if not a.startswith("-")] or list(REG)
    OUT.mkdir(parents=True, exist_ok=True)
    for i in ids:
        ps = render(i)
        print(f"{i}: {len(ps)} file(s)")


if __name__ == "__main__":
    main(sys.argv[1:])

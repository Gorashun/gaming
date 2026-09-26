#!/usr/bin/env python3
"""Wickwright procedural music: seamless loops, composed in code.

Usage (from game/):
    python3 tools/audio/music_gen.py              # all tracks
    python3 tools/audio/music_gen.py town boss    # selected tracks
    python3 tools/audio/music_gen.py --wav town   # write .wav instead of .ogg (debug)

Output: assets/generated/music/<id>.ogg (Vorbis, 44.1 kHz mono). Each track is
rendered as its loop plus a few seconds of tail (reverb, releases); the tail is
folded back onto the start (synth.loop_wrap) so the file loops with no gap.

A tiny sequencer: tempo, bars, chord progression, parts placed on beats onto
two buses (dry, reverb send; mine also uses a delay send), then mastered to
about -18 dBFS RMS with a -1 dBFS ceiling.
"""
from __future__ import annotations

import sys
import zlib
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import synth as S  # noqa: E402
from synth import midi_hz, note  # noqa: E402

OUT = Path(__file__).resolve().parents[2] / "assets" / "generated" / "music"

# ---------------------------------------------------------------- theory helpers
QUAL = {"": [0, 4, 7], "m": [0, 3, 7], "7": [0, 4, 7, 10], "m7": [0, 3, 7, 10], "maj7": [0, 4, 7, 11],
        "dim": [0, 3, 6], "sus4": [0, 5, 7], "sus2": [0, 2, 7], "add9": [0, 4, 7, 14], "m9": [0, 3, 7, 14]}


def chord(name: str, octave: int = 4):
    """'Dm' -> (root_midi, [midi...]) with root in the given octave."""
    i = 1
    if len(name) > 1 and name[1] in "#b":
        i = 2
    root = note(name[:i] + str(octave))
    return root, [root + iv for iv in QUAL[name[i:]]]


def parse_seq(text: str):
    """'D5/1.5 A4/.5 r/1' -> [(midi or None, beats), ...]"""
    out = []
    for tok in text.split():
        if tok == "|":
            continue
        n, b = tok.split("/")
        out.append((None if n == "r" else note(n), float(b)))
    return out


# ---------------------------------------------------------------- instruments (f in Hz, d in seconds)
def i_pad(fs, d, cutoff=1400, attack=0.6, release=1.2, voices=4, detune=0.01, rng=None):
    out = np.zeros(S.n_samples(d + release))
    for f in fs:
        out += S.supersaw(f, d + release, voices, detune, rng)
    env = S.adsr(d + release, attack, 0.3, 0.85, release)
    return S.lp(out, cutoff) * env / max(1, len(fs)) ** 0.5


def i_choir(fs, d, vowel="oo", attack=0.5, release=1.2, rng=None):
    L = d + release
    out = np.zeros(S.n_samples(L))
    for f in fs:
        vib = f * (1 + 0.005 * S.lfo(L, 5.0, 1.0, rng.random() * 6))
        out += S.supersaw(vib, L, 3, 0.007, rng)
    out = S.formant(out, vowel) * 2.5
    return out * S.adsr(L, attack, 0.3, 0.85, release) / max(1, len(fs)) ** 0.5


def i_pluck(f, d, bright=0.55, rng=None, ring=1.2):
    return S.pluck(f, max(d, ring), bright, 0.996, rng)


def i_pizz(f, d, rng=None):
    return S.lp(S.pluck(f, 0.5, 0.35, 0.985, rng), 2500)


def i_celesta(f, d, rng=None):
    return S.glock(f, 1.6, 0.6)


def i_musicbox(f, d, rng=None):
    return S.mix((S.glock(f * (1 + rng.uniform(-0.002, 0.002)), 1.4, 0.45), 0, 1.0), (S.glock(f * 2, 0.6, 0.15), 0, 0.2))


def i_bell(f, d, rng=None, decay=1.6, bright=0.7):
    return S.bell(f, decay * 2.2, bright, decay)


def i_marimba(f, d, rng=None):
    return S.marimba(f, 0.8, 0.3)


def i_flute(f, d, rng=None):
    L = d + 0.15
    vib = f * (1 + 0.007 * S.lfo(L, 5.5) * S.segs([(0, 0), (min(0.3, L), 0), (L, 1)], L))
    tone = S.osc(vib, L) + 0.18 * S.osc(vib * 2, L, "tri") + 0.05 * S.osc(vib * 3, L)
    breath = S.bp(S.noise(L, "white", rng), f * 1.5, f * 4) * 0.05
    return (tone + breath) * S.adsr(L, 0.05, 0.1, 0.8, 0.15)


def i_clarinet(f, d, rng=None):
    L = d + 0.08
    tone = S.lp(S.osc(f * (1 + 0.004 * S.lfo(L, 5)), L, "square"), 1600)
    return tone * S.adsr(L, 0.02, 0.05, 0.7, 0.08) * 0.6


def i_brass(f, d, rng=None, bright=3500):
    L = d + 0.12
    s = S.supersaw(f * (1 + 0.003 * S.lfo(L, 5.2)), L, 3, 0.006, rng)
    s = S.sweep(s, "lp", S.slide(600, bright, min(L, 0.12), "fast"))
    return s * S.adsr(L, 0.03, 0.1, 0.75, 0.12) * 0.7


def i_bass(f, d, rng=None):
    L = d + 0.05
    s = S.osc(f, L) + 0.35 * S.osc(f, L, "tri") + 0.15 * S.osc(f * 2, L)  # 2nd harmonic reads on phones
    return S.lp(s, 900) * S.adsr(L, 0.01, 0.1, 0.8, 0.05)


def i_drivebass(f, d, rng=None):
    L = d + 0.03
    s = S.osc(f, L, "saw")
    s = S.sweep(s, "lp", S.slide(1800, 450, min(L, 0.15), "fast"))
    s = S.drive(s * 1.3 + 0.6 * S.osc(f, L), 1.4)
    return s * S.adsr(L, 0.004, 0.08, 0.7, 0.03)


def i_drone(f, d, rng=None):
    return (S.osc(f, d) + 0.5 * S.osc(f * 1.003, d) + 0.25 * S.osc(f * 2.001, d)) * S.adsr(d, 3.0, 0.5, 0.9, 3.0)


def i_softkeys(f, d, rng=None):
    """Soft 'felt piano' (FM with decaying index)."""
    L = max(d, 2.5)
    idx = S.perc(L, 0.001, 0.25) * 1.2
    return S.fm(f, L, 1.0, idx) * S.perc(L, 0.004, 0.9)


# drums
def d_kick(rng, soft=1.0):
    d = 0.35
    b = S.osc(S.slide(130, 45, 0.12, "fast"), d) * S.perc(d, 0.002, 0.12)
    c = S.lp(S.noise(0.01, "white", rng), 3000) * S.perc(0.01, 0.0005, 0.003)
    return S.mix((b, 0, 1.0), (c, 0, 0.3), (S.osc(S.slide(260, 90, 0.06, "fast"), d, "tri") * S.perc(d, 0.001, 0.03), 0, 0.2))


def d_snare(rng):
    d = 0.25
    n = S.bp(S.noise(d, "white", rng), 1200, 6000) * S.perc(d, 0.001, 0.06)
    t = S.osc(S.slide(220, 170, 0.05), d) * S.perc(d, 0.001, 0.04)
    return 0.7 * n + 0.5 * t


def d_brush(rng):
    d = 0.18
    return S.bp(S.noise(d, "pink", rng), 1500, 7000) * S.segs([(0, 0), (0.02, 1), (d, 0)], d) ** 2


def d_hat(rng, dur=0.05):
    return S.hp(S.noise(dur, "white", rng), 7000) * S.perc(dur, 0.0005, dur * 0.3)


def d_shaker(rng):
    d = 0.09
    return S.bp(S.noise(d, "white", rng), 4000, 10000) * S.segs([(0, 0), (0.03, 1), (d, 0)], d) ** 1.5


def d_timpani(rng, f=65.0):
    d = 1.4
    b = S.osc(S.slide(f * 1.05, f, 0.2), d) * S.perc(d, 0.003, 0.5)
    h = S.osc(f * 1.5, d) * S.perc(d, 0.003, 0.25) * 0.4 + S.osc(f * 2.0, d) * S.perc(d, 0.003, 0.2) * 0.25
    n = S.lp(S.noise(0.08, "white", rng), 1200) * S.perc(0.08, 0.001, 0.02)
    return S.mix((b + h, 0, 1.0), (n, 0, 0.5))


def d_tom(rng, f=110.0):
    d = 0.5
    return S.mix((S.osc(S.slide(f * 1.4, f, 0.08, "fast"), d) * S.perc(d, 0.002, 0.15), 0, 1.0),
                 (S.lp(S.noise(0.05, "white", rng), 2000) * S.perc(0.05, 0.001, 0.01), 0, 0.2))


def d_block(rng, f=900.0):
    d = 0.12
    exc = S.noise(d, "white", rng) * S.perc(d, 0, 0.002)
    return S.resonator(exc, f, 15) * 4 * S.perc(d, 0.0, 0.03)


def d_tink(rng, f=2200.0):
    return S.metal_clang(f, 0.6, 0.12) * 0.6


# ---------------------------------------------------------------- sequencer
class Track:
    def __init__(self, id_, bpm, bars, beats=4, tail=6.0, send_room=0.75, send_damp=0.45):
        self.id = id_
        self.bpm = bpm
        self.bars = bars
        self.beats = beats
        self.spb = 60.0 / bpm
        self.loop_s = bars * beats * self.spb
        self.tail = tail
        n = S.n_samples(self.loop_s + tail)
        self.dry = np.zeros(n)
        self.wet = np.zeros(n)
        self.dly = np.zeros(n)
        self.room = send_room
        self.damp = send_damp
        self.rng = np.random.default_rng(zlib.crc32(id_.encode()))

    def cyc(self, f):
        """Snap a frequency/LFO rate so a whole number of cycles fits the loop (perfectly periodic)."""
        return max(1, round(f * self.loop_s)) / self.loop_s

    def bed_noise(self, color, fn=None, xf=2.0):
        """Noise bed of exactly one loop: rendered with 2 s extra, tail crossfaded into the head."""
        x = S.noise(self.loop_s + xf, color, self.rng)
        if fn:
            x = fn(x)
        return S.loop_crossfade(x, xf)

    def lfo(self, rate, depth=1.0, phase=0.0):
        return S.lfo(self.loop_s, self.cyc(rate), depth, phase)

    def drone(self, f):
        L = self.loop_s
        return S.osc(self.cyc(f), L) + 0.5 * S.osc(self.cyc(f * 1.003), L) + 0.25 * S.osc(self.cyc(f * 2.001), L)

    def beat_t(self, bar, beat=0.0):
        return (bar * self.beats + beat) * self.spb

    def put(self, sig, t, gain=1.0, send=0.25, dsend=0.0):
        o = S.n_samples(t) if t > 0 else 0
        e = min(len(self.dry), o + len(sig))
        if e <= o:
            return
        s = sig[: e - o] * gain
        self.dry[o:e] += s
        if send:
            self.wet[o:e] += s * send
        if dsend:
            self.dly[o:e] += s * dsend

    def melody(self, inst, text, bar, gain=0.5, send=0.3, transpose=0, dsend=0.0, legato=1.0):
        t_beats = 0.0
        for m, b in parse_seq(text):
            if m is not None:
                d = b * self.spb * legato
                self.put(inst(midi_hz(m + transpose), d, rng=self.rng), self.beat_t(bar, t_beats), gain, send, dsend)
            t_beats += b

    def render(self, delay_time=None, delay_fb=0.4, wet_gain=1.0):
        mixb = self.dry + wet_gain * S.reverb(self.wet, self.room, self.damp, 1.0, 0.02)
        mixb -= self.wet * 0.5  # reverb() leaves half-dry in; remove it from the send
        if delay_time:
            d = S.delay(self.dly, delay_time, delay_fb, 1.0, 3500) - self.dly
            mixb += S.reverb(d, 0.6, 0.5, 0.6)
        return S.loop_wrap(mixb, S.n_samples(self.loop_s))


def prog_bars(prog: str):
    return prog.split()


def lay_pads(tr: Track, prog, octave=3, gain=0.35, cutoff=1300, send=0.5, choir=None, choir_gain=0.3, start=0, voices=4):
    for i, c in enumerate(prog):
        bar = start + i
        root, ns = chord(c, octave)
        voicing = [root - 12] + ns[1:] + [ns[0] + 12] if octave <= 3 else ns
        fs = [midi_hz(m) for m in voicing]
        d = tr.beats * tr.spb
        tr.put(i_pad(fs, d, cutoff, 0.5, 1.2, voices, 0.01, tr.rng), tr.beat_t(bar), gain, send)
        if choir:
            cf = [midi_hz(m + 12) for m in ns[:3]]
            tr.put(i_choir(cf, d, choir, 0.6, 1.2, tr.rng), tr.beat_t(bar), choir_gain, send * 1.3)


def lay_arp(tr: Track, prog, inst, pattern, step=0.5, octave=4, gain=0.3, send=0.35, start=0, dsend=0.0, vel=None):
    per_bar = int(round(tr.beats / step))
    for i, c in enumerate(prog):
        bar = start + i
        root, ns = chord(c, octave)
        tones = ns + [n + 12 for n in ns] + [n + 24 for n in ns]
        for k in range(per_bar):
            idx = pattern[k % len(pattern)]
            if idx is None:
                continue
            m = tones[idx]
            g = gain * (vel[k % len(vel)] if vel else 1.0)
            tr.put(inst(midi_hz(m), step * tr.spb, rng=tr.rng), tr.beat_t(bar, k * step), g, send, dsend)


def lay_bass(tr: Track, prog, inst, pattern, octave=2, gain=0.5, send=0.08, start=0):
    """pattern: list of (beat, interval_semitones_from_root, beats_len)."""
    for i, c in enumerate(prog):
        root, _ = chord(c, octave)
        for beat, iv, ln in pattern:
            tr.put(inst(midi_hz(root + iv), ln * tr.spb, rng=tr.rng), tr.beat_t(start + i, beat), gain, send)


def lay_drums(tr: Track, bars, pattern: dict, start=0, gain=1.0, send=0.15, humanize=0.006):
    """pattern: {name: (fn, [beats...], gain)}"""
    for b in range(bars):
        for name, (fn, beats, g) in pattern.items():
            for bt in beats:
                jitter = tr.rng.uniform(-humanize, humanize)
                tr.put(fn(tr.rng), max(0.0, tr.beat_t(start + b, bt) + jitter), g * gain * tr.rng.uniform(0.85, 1.0), send)


def wander(tr: Track, prog, inst, scale_pcs, octave=5, every=2.0, prob=0.6, gain=0.25, send=0.6, start=0, dsend=0.0):
    """Sparse seeded melody: chord tones on strong beats, scale neighbours between."""
    cur = note("A4") + 12 * (octave - 4)
    for i, c in enumerate(prog):
        root, ns = chord(c, octave)
        pcs = [n % 12 for n in ns]
        t = 0.0
        while t < tr.beats - 1e-6:
            if tr.rng.random() < prob:
                pool = pcs if t % 2 == 0 else scale_pcs
                cands = [m for m in range(cur - 7, cur + 8) if m % 12 in pool]
                cur = int(tr.rng.choice(cands)) if cands else cur
                cur = int(np.clip(cur, root - 2, root + 14))
                tr.put(inst(midi_hz(cur), every * tr.spb, rng=tr.rng), tr.beat_t(start + i, t), gain, send, dsend)
            t += every


MINOR = [0, 2, 3, 5, 7, 8, 10]
MAJOR = [0, 2, 4, 5, 7, 9, 11]


def pcs(root_name, scale):
    r = note(root_name + "4") % 12
    return [(r + s) % 12 for s in scale]


# ---------------------------------------------------------------- tracks
TITLE_THEME = ("D5/1.5 A4/.5 D5/1 E5/1 | F5/2 E5/1 D5/1 | C5/1.5 D5/.5 C5/1 A4/1 | G4/2 r/1 C5/1 | "
               "D5/1.5 D5/.5 G5/1 F5/1 | F5/1.5 E5/.5 D5/1 A4/1 | Bb4/1 D5/1 F5/1 G5/1 | A5/2 G5/.5 F5/.5 E5/1")
TITLE_THEME_END = ("D5/1.5 A4/.5 D5/1 E5/1 | F5/2 E5/1 D5/1 | C5/1.5 D5/.5 C5/1 A4/1 | G4/2 r/1 C5/1 | "
                   "D5/1.5 D5/.5 G5/1 F5/1 | F5/1.5 E5/.5 D5/1 F5/1 | E5/2 C#5/1 E5/1 | A5/3 r/1")


def t_title():
    """Heroic-but-spooky: D minor, 96 BPM, 32 bars (80 s). Intro / theme / celesta B / full reprise."""
    tr = Track("title", 96, 32, send_room=0.8)
    A = prog_bars("Dm Bb F C Dm Bb Gm A")
    T = prog_bars("Dm Bb F C Gm Dm Bb A")
    B = prog_bars("Bb C Dm Dm Gm C F A")
    R = prog_bars("Dm Bb F C Gm Bb A A")
    prog = A + T + B + R
    lay_pads(tr, prog, 3, 0.3, 1200, 0.5)
    lay_pads(tr, A, 4, 0.0, choir="oo", choir_gain=0.35)
    lay_pads(tr, B + R, 4, 0.0, choir="ah", choir_gain=0.3, start=16)
    # harp arpeggio throughout
    lay_arp(tr, prog, lambda f, d, rng: i_pluck(f, d, 0.5, rng), [0, 1, 2, 3, 4, 3, 2, 1], 0.5, 3, 0.22, 0.35)
    # bells mark each bar in intro
    for i, c in enumerate(A):
        r, ns = chord(c, 5)
        tr.put(i_bell(midi_hz(ns[0]), 0, tr.rng, 2.0, 0.6), tr.beat_t(i), 0.18, 0.6)
    # heroic horn theme (bars 8-15) and reprise (24-31, doubled by bells)
    tr.melody(lambda f, d, rng: i_brass(f, d, rng, 2600), TITLE_THEME, 8, 0.32, 0.4, transpose=-12)
    tr.melody(i_flute, TITLE_THEME, 8, 0.2, 0.4)
    tr.melody(lambda f, d, rng: i_brass(f, d, rng, 3200), TITLE_THEME_END, 24, 0.32, 0.4, transpose=-12)
    tr.melody(lambda f, d, rng: i_bell(f, d, rng, 1.0, 0.6), TITLE_THEME_END, 24, 0.14, 0.5, transpose=12)
    # spooky celesta counter in B
    lay_arp(tr, B, i_celesta, [6, 7, 8, 7, 6, 8, 7, 5], 0.5, 4, 0.2, 0.5, start=16)
    # bass
    lay_bass(tr, prog, i_bass, [(0, 0, 2), (2, 7, 1.5), (3.5, 12, 0.5)], 2, 0.45)
    # timpani + march brush in theme and reprise
    for st in (8, 24):
        for b in range(8):
            r, _ = chord(prog[st + b], 2)
            f = midi_hz(r if r >= note("C2") + 0 else r + 12)
            tr.put(d_timpani(tr.rng, f), tr.beat_t(st + b), 0.5, 0.3)
            tr.put(d_timpani(tr.rng, f), tr.beat_t(st + b, 2), 0.35, 0.3)
    lay_drums(tr, 8, {"brush": (d_brush, [1, 3], 0.25), "sh": (d_shaker, [0.5, 1.5, 2.5, 3.5], 0.1)}, 24)
    for bt in (0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5):  # tom fill into the loop point
        tr.put(d_tom(tr.rng, 90 + 10 * bt), tr.beat_t(31, bt), 0.25 + 0.05 * bt, 0.3)
    return tr.render()


TOWN_A = ("A5/1 C6/1 A5/1 F5/1 | G5/1.5 F5/.5 D5/2 | F5/1 G5/1 A5/1 Bb5/1 | C6/2 G5/2 | "
          "A5/1 C6/1 F6/1 E6/.5 D6/.5 | C6/1.5 A5/.5 E5/2 | D6/1 C6/1 Bb5/1 D6/1 | C6/3 r/1")
TOWN_B = ("D5/1 F5/1 Bb5/2 | C6/1 Bb5/.5 A5/.5 G5/2 | A5/1 C6/1 E6/2 | D6/1.5 C6/.5 A5/2 | "
          "Bb5/1 A5/1 G5/1 D6/1 | C6/1 Bb5/1 G5/1 E5/1 | F5/2 A5/1 C6/1 | F6/3 r/1")


def t_town():
    """Warm and cosy: F major, 84 BPM, 32 bars (91 s). Music box + guitar-ish plucks + warm pad."""
    tr = Track("town", 84, 32, send_room=0.6, send_damp=0.6)
    A = prog_bars("F Dm Bb C F Am Bb C")
    B = prog_bars("Bb C Am Dm Gm C F F")
    prog = A + B + A + B
    lay_pads(tr, prog, 3, 0.25, 1000, 0.35)
    lay_arp(tr, prog, lambda f, d, rng: i_pluck(f, d, 0.45, rng), [0, 2, 1, 2, 3, 2, 1, 2], 0.5, 3, 0.25, 0.25,
            vel=[1, 0.6, 0.8, 0.6, 0.9, 0.6, 0.8, 0.6])
    lay_bass(tr, prog, i_bass, [(0, 0, 1.5), (2, 7, 1.5)], 2, 0.45)
    tr.melody(i_musicbox, TOWN_A, 0, 0.3, 0.35)
    tr.melody(i_musicbox, TOWN_B, 8, 0.3, 0.35)
    tr.melody(i_flute, TOWN_A, 16, 0.25, 0.35, transpose=-12)
    tr.melody(i_flute, TOWN_B, 24, 0.25, 0.35, transpose=-12)
    lay_arp(tr, A + B, i_celesta, [None, None, 6, None, None, 7, None, 8], 0.5, 4, 0.1, 0.5, start=16)
    lay_drums(tr, 16, {"sh": (d_shaker, [0.5, 1.5, 2.5, 3.5], 0.08)})
    lay_drums(tr, 16, {"sh": (d_shaker, [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5], 0.07),
                       "k": (lambda r: d_kick(r) * 0.6, [0, 2], 0.25),
                       "b": (lambda r: d_block(r, 1100), [1, 3], 0.12)}, 16)
    return tr.render()


GRAVE_MEL = ("B5/2 G5/1 | E5/2 F#5/1 | G5/1 A5/1 C6/1 | B5/2 A5/1 | F#5/2 D#5/1 | A5/2 F#5/1 | G5/1 F#5/1 E5/1 | B4/3 | "
             "E5/1 G5/1 C6/1 | B5/2 G5/1 | A5/1 C6/1 E6/1 | D6/2 C6/1 | B5/1 A5/1 F#5/1 | D#6/2 B5/1 | E6/1.5 B5/.5 G5/1 | E5/3")


def t_graveyard():
    """Act 1 Wickmire (bog, graveyard, moonlit): Burton-ish melancholy waltz, E minor, 3/4 at 138 BPM, 64 bars (83 s)."""
    tr = Track("graveyard", 138, 64, beats=3, send_room=0.8)
    P = prog_bars("Em Em Am Am B7 B7 Em Em C C Am Am B7 B7 Em Em")
    prog = P * 4
    # oom-pah-pah: low pizz on 1, chord pizz on 2 and 3
    for i, c in enumerate(prog):
        root, ns = chord(c, 2)
        tr.put(i_pizz(midi_hz(root), 0), tr.beat_t(i, 0), 0.55, 0.2)
        for bt in (1, 2):
            for m in chord(c, 4)[1][:3]:
                tr.put(i_pizz(midi_hz(m), 0, tr.rng), tr.beat_t(i, bt) + tr.rng.uniform(0, 0.012), 0.16, 0.3)
    lay_pads(tr, prog, 3, 0.16, 900, 0.5, voices=3)
    tr.melody(i_celesta, GRAVE_MEL, 0, 0.35, 0.45)
    tr.melody(i_musicbox, GRAVE_MEL, 16, 0.3, 0.5)
    lay_pads(tr, P, 4, 0.0, choir="oo", choir_gain=0.3, start=16)
    lay_pads(tr, P, 4, 0.0, choir="oo", choir_gain=0.35, start=32)
    wander(tr, P, lambda f, d, rng: i_bell(f, d, rng, 1.8, 0.5), pcs("E", MINOR), 5, 3.0, 0.7, 0.18, 0.7, 32)
    tr.melody(i_celesta, GRAVE_MEL, 48, 0.35, 0.45)
    tr.melody(i_clarinet, GRAVE_MEL, 48, 0.12, 0.3, transpose=-24)
    return tr.render()


def t_crypt():
    """Dungeon crypts: desolate, A minor, 64 BPM, 20 bars (75 s). Dark pads, low bells, drone, sparse glass."""
    tr = Track("crypt", 64, 20, send_room=0.92, send_damp=0.3)
    prog = prog_bars("Am Am F F Dm Dm E E Am Am C G F F E E Am Am Dm E")
    lay_pads(tr, prog, 3, 0.35, 700, 0.6, voices=3)
    tr.put(tr.drone(midi_hz(note("A1"))), 0.0, 0.35, 0.2)
    for i in range(0, 20, 2):
        r, _ = chord(prog[i], 3)
        tr.put(i_bell(midi_hz(r), 0, tr.rng, 3.0, 0.4), tr.beat_t(i), 0.22, 0.7)
    wander(tr, prog, lambda f, d, rng: i_bell(f, d, rng, 1.4, 1.0), pcs("A", MINOR), 6, 1.0, 0.18, 0.1, 0.9)
    lay_pads(tr, prog[8:16], 4, 0.0, choir="oo", choir_gain=0.22, start=8)
    wind = tr.bed_noise("pink", lambda x: S.bp(x, 300, 1200)) * (0.6 + 0.4 * tr.lfo(0.05))
    tr.put(wind, 0.0, 0.05, 0.2)
    return tr.render()


def t_forest():
    """Act 2 Whisperwood: curious and sneaky, G minor, 100 BPM, 36 bars (86 s). Marimba, bass clarinet, glass bells."""
    tr = Track("forest", 100, 36, send_room=0.7)
    P = prog_bars("Gm Gm Eb Eb Cm D Gm D Gm Gm Eb Eb Cm Cm D D")
    prog = P + P + prog_bars("Eb Eb D D")
    lay_arp(tr, prog, i_marimba, [0, 2, 1, 2, 3, 2, 1, None], 0.5, 4, 0.3, 0.3, vel=[1, 0.6, 0.8, 0.6, 0.9, 0.6, 0.8, 1])
    lay_bass(tr, prog, i_clarinet, [(0, 0, 0.45), (1, 7, 0.45), (1.5, 12, 0.4), (2, 10, 0.45), (3, 7, 0.45), (3.5, 5, 0.4)], 2, 0.55, )
    lay_pads(tr, prog, 3, 0.16, 800, 0.5, voices=3)
    wander(tr, prog[:16], lambda f, d, rng: i_bell(f, d, rng, 0.9, 1.2), pcs("G", MINOR), 6, 1.0, 0.3, 0.14, 0.6, 0)
    wander(tr, prog[16:], lambda f, d, rng: i_celesta(f, d, rng), pcs("G", [0, 2, 3, 5, 7, 9, 10]), 5, 0.5, 0.45, 0.2, 0.5, 16)
    lay_drums(tr, 36, {"blk": (lambda r: d_block(r, 1200), [1.5, 3.5], 0.14), "blk2": (lambda r: d_block(r, 800), [0.75], 0.08),
                       "sh": (d_shaker, [0.5, 1.5, 2.5, 3.5], 0.05)})
    lay_pads(tr, prog[16:32], 4, 0.0, choir="oo", choir_gain=0.18, start=16)
    return tr.render()


def t_mine():
    """Act 3 Echo Mines: deep stone, echoing work rhythm, C minor, 88 BPM, 32 bars (87 s). Delay-drenched plucks and tinks."""
    tr = Track("mine", 88, 32, send_room=0.9, send_damp=0.5)
    P = prog_bars("Cm Cm Ab Ab Fm Fm G G")
    prog = P + P + prog_bars("Ab Bb Eb Eb Fm Ab G G") + P
    lay_pads(tr, prog, 3, 0.25, 650, 0.55, voices=3)
    lay_bass(tr, prog, lambda f, d, rng: i_pluck(f, d, 0.3, rng, 1.0), [(0, 0, 1), (1.5, 0, 0.5), (2.5, 7, 1)], 2, 0.5, 0.15)
    lay_drums(tr, 32, {"dum": (lambda r: d_tom(r, 70), [0, 1.5, 2.5], 0.35)}, send=0.35)
    lay_drums(tr, 24, {"tink": (lambda r: d_tink(r, r.choice([1900, 2200, 2500])), [3], 0.12)}, 8, send=0.3)
    for i, c in enumerate(prog):
        if i % 2 == 0 and i >= 8:
            r, ns = chord(c, 5)
            m = int(tr.rng.choice(ns))
            tr.put(i_pluck(midi_hz(m), 0.5, 0.7, tr.rng), tr.beat_t(i, 0.5), 0.2, 0.3, dsend=0.7)
    wander(tr, prog[16:], lambda f, d, rng: i_bell(f, d, rng, 1.2, 0.6), pcs("C", MINOR), 5, 2.0, 0.5, 0.14, 0.6, 16, dsend=0.4)
    rum = tr.bed_noise("brown", lambda x: S.lp(x, 120))
    tr.put(rum, 0.0, 0.12, 0.1)
    return tr.render(delay_time=tr.spb * 0.75, delay_fb=0.45)


def t_ice():
    """Act 4 Rimehall: frozen court, stately, B minor, 72 BPM, 28 bars (93 s). Glassy bells, high pads, glock minuet arps."""
    tr = Track("ice", 72, 28, send_room=0.9, send_damp=0.2)
    prog = prog_bars("Bm G D A Bm Em F# F# G A F#m Bm Em G F# F# Bm G D A Em F# Bm Bm Bm Bm G F#")
    lay_pads(tr, prog, 4, 0.22, 2600, 0.6, voices=4)
    lay_arp(tr, prog, i_celesta, [0, 1, 2, 3, 2, 1], 2 / 3, 5, 0.16, 0.6)
    lay_bass(tr, prog, i_bass, [(0, 0, 3.5)], 2, 0.35)
    wander(tr, prog[8:], lambda f, d, rng: i_bell(f, d, rng, 2.0, 1.0), pcs("B", MINOR), 6, 2.0, 0.7, 0.12, 0.8, 8)
    lay_pads(tr, prog[4:20], 5, 0.0, choir="ee", choir_gain=0.14, start=4)
    wind = tr.bed_noise("pink", lambda x: S.bp(x, 500, 1600)) * (0.6 + 0.4 * tr.lfo(0.07))
    tr.put(wind, 0.0, 0.06, 0.3)
    return tr.render()


def t_hush():
    """Act 5 Well of Hush: colour drained. 56 BPM, 20 bars (86 s). D drone, the title motif in slow felt-piano, warbling music box."""
    tr = Track("hush", 56, 20, send_room=0.95, send_damp=0.35)
    tr.put(tr.drone(midi_hz(note("D2"))), 0.0, 0.35, 0.3)
    tr.put(tr.drone(midi_hz(note("A2"))), 0.0, 0.2, 0.3)
    motif = "D5/2 A4/2 | D5/2 E5/2 | F5/4 | r/4 | E5/2 D5/2 | C5/2 A4/2 | D5/4 | r/4"
    tr.melody(i_softkeys, motif, 2, 0.35, 0.7)
    tr.melody(lambda f, d, rng: i_musicbox(f * (1 + 0.01 * np.sin(rng.random() * 6)), d, rng), motif, 12, 0.18, 0.8, transpose=12)
    prog = prog_bars("Dm Dm Bb Bb Gm Gm A A Dm Dm Bb Bb Gm Gm Dm Dm A A Dm Dm")
    lay_pads(tr, prog, 3, 0.12, 500, 0.6, voices=2)
    tone = S.osc(tr.cyc(midi_hz(note("A6"))), tr.loop_s) * (0.5 + 0.5 * tr.lfo(2 / tr.loop_s))
    tr.put(tone, 0.0, 0.015, 0.5)
    return tr.render()


def t_boss():
    """Boss: driving, D minor, 138 BPM, 48 bars (83 s). Ostinato bass, kit, brass stabs, choir, title theme callback."""
    tr = Track("boss", 138, 48, send_room=0.7)
    S1 = prog_bars("Dm Dm Bb C Dm Dm Bb A")
    S2 = prog_bars("Dm Bb F C Gm Dm Bb A")
    S3 = prog_bars("Gm Gm Dm Dm Bb C A A")
    S5 = prog_bars("Dm Dm Bb Bb Gm Gm A A")
    prog = S1 + S2 + S3 + S2 + S5 + S1
    # ostinato: 8ths root, with octave pop and b7 approach
    ost = [(k * 0.5, iv, 0.45) for k, iv in enumerate([0, 0, 12, 0, 0, 0, 10, 12])]
    lay_bass(tr, prog[:32], i_drivebass, ost, 2, 0.4, 0.05)
    lay_bass(tr, prog[32:40], i_drivebass, [(0, 0, 1.8), (2, 0, 1.8)], 2, 0.4, 0.05, 32)
    lay_bass(tr, prog[40:], i_drivebass, ost, 2, 0.4, 0.05, 40)
    lay_pads(tr, prog, 3, 0.2, 1500, 0.35, voices=3)
    full = {"k": (d_kick, [0, 1.5, 2], 0.6), "s": (d_snare, [1, 3], 0.35),
            "h": (d_hat, [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5], 0.08)}
    for st in (0, 8, 16, 24, 40):
        lay_drums(tr, 8, full, st)
    lay_drums(tr, 8, {"t": (lambda r: d_tom(r, 80), [0, 1.5, 3], 0.4), "t2": (lambda r: d_tom(r, 120), [2.5], 0.3)}, 32)
    for bar in (7, 15, 23, 31, 47):
        for k, bt in enumerate((2, 2.5, 3, 3.25, 3.5, 3.75)):
            tr.put(d_tom(tr.rng, 150 - 12 * k), tr.beat_t(bar, bt), 0.35, 0.2)
    # brass stabs (syncopated) in S1 and S3
    for st, sec in ((0, S1), (16, S3), (40, S1)):
        for i, c in enumerate(sec):
            _, ns = chord(c, 4)
            for bt in (0, 1.5, 3):
                for m in ns[:3]:
                    tr.put(i_brass(midi_hz(m), 0.25 * tr.spb, tr.rng), tr.beat_t(st + i, bt), 0.14, 0.3)
    # theme callback
    tr.melody(lambda f, d, rng: i_brass(f, d, rng, 3000), TITLE_THEME, 8, 0.3, 0.35)
    tr.melody(lambda f, d, rng: i_brass(f, d, rng, 3800), TITLE_THEME_END, 24, 0.3, 0.35)
    tr.melody(lambda f, d, rng: i_bell(f, d, rng, 0.8, 0.8), TITLE_THEME_END, 24, 0.12, 0.4, transpose=12)
    lay_pads(tr, S3 + S2, 4, 0.0, choir="ah", choir_gain=0.3, start=16)
    # riser into the reprise
    rs = S.sweep(S.noise(8 * 4 * tr.spb, "white", tr.rng), "bp", S.slide(300, 5000, 8 * 4 * tr.spb)) * S.slide(0.01, 1, 8 * 4 * tr.spb)
    tr.put(rs, tr.beat_t(32), 0.08, 0.4)
    tr.put(S.bell(midi_hz(note("D6")), 3.0, 0.8, 1.5), tr.beat_t(40), 0.2, 0.6)
    return tr.render()


def master_loop(x, rms_db, pre=3.0):
    """Master a loop circularly: prepend the loop's own last seconds so the IIR filters
    are already settled at the loop point, then cut them off again."""
    n = S.n_samples(pre)
    z = np.concatenate([x[-n:], x])
    z = z - 0.55 * S.lp(z, 140)  # ~ -7 dB low shelf: phone speakers can't play it, keep energy in 200 Hz-5 kHz
    y = S.master(z, rms_db, -1.0)
    return y[n:]


TRACKS = {"title": t_title, "town": t_town, "graveyard": t_graveyard, "crypt": t_crypt, "forest": t_forest,
          "mine": t_mine, "ice": t_ice, "hush": t_hush, "boss": t_boss}
LEVELS = {"hush": -22.0, "crypt": -20.0}


def main(argv):
    wav = "--wav" in argv
    ids = [a for a in argv if not a.startswith("-")] or list(TRACKS)
    OUT.mkdir(parents=True, exist_ok=True)
    for i in ids:
        x = master_loop(TRACKS[i](), LEVELS.get(i, -18.0))
        if wav:
            S.write_wav(OUT / f"{i}.wav", x, -1.0)
        else:
            S.write_ogg(OUT / f"{i}.ogg", x)
        print(f"{i}: {len(x) / S.SR:.1f} s")


if __name__ == "__main__":
    main(sys.argv[1:])

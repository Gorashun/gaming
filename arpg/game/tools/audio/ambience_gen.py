#!/usr/bin/env python3
"""Wickwright ambience loops, one per act (synthesized, no field recordings).

Usage (from game/):
    python3 tools/audio/ambience_gen.py             # all
    python3 tools/audio/ambience_gen.py amb_bog     # one

Output: assets/generated/music/<id>.ogg (Vorbis mono, 45 s seamless loop),
played by Sfx.play_ambience(id). Noise beds are crossfaded into their own head;
one-shot events (frogs, drips, ...) are scattered over the loop and their tails
wrap around the loop point, so there is no seam.
"""
from __future__ import annotations

import sys
import zlib
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import synth as S  # noqa: E402
from synth import hz  # noqa: E402
from music_gen import master_loop  # noqa: E402

OUT = Path(__file__).resolve().parents[2] / "assets" / "generated" / "music"
LOOP = 45.0


class Amb:
    def __init__(self, id_):
        self.rng = np.random.default_rng(zlib.crc32(id_.encode()))
        self.n = S.n_samples(LOOP)
        self.buf = np.zeros(self.n + S.n_samples(8.0))
        self.send = np.zeros_like(self.buf)

    def cyc(self, rate):
        return max(1, round(rate * LOOP)) / LOOP

    def lfo(self, rate, phase=0.0):
        return S.lfo(LOOP, self.cyc(rate), 1.0, phase)

    def bed(self, color, fn, gain, send=0.0):
        x = S.loop_crossfade(fn(S.noise(LOOP + 2.0, color, self.rng)), 2.0)
        self.buf[: self.n] += x * gain
        self.send[: self.n] += x * gain * send

    def gusts(self, rate=0.08, depth=0.6):
        """Smooth random-ish gust envelope, periodic over the loop (sum of snapped LFOs)."""
        g = 0.5 * self.lfo(rate, self.rng.random() * 6) + 0.3 * self.lfo(rate * 2.3, self.rng.random() * 6) \
            + 0.2 * self.lfo(rate * 0.5, self.rng.random() * 6)
        return (1 - depth) + depth * (0.5 + 0.5 * g)

    def event(self, sig, t, gain, send=0.4):
        o = S.n_samples(t)
        e = min(len(self.buf), o + len(sig))
        self.buf[o:e] += sig[: e - o] * gain
        self.send[o:e] += sig[: e - o] * gain * send

    def scatter(self, fn, count, gain, send=0.4, jitter_gain=0.4):
        for _ in range(count):
            self.event(fn(self.rng), self.rng.uniform(0, LOOP), gain * self.rng.uniform(1 - jitter_gain, 1.0), send)

    def render(self, room=0.8, damp=0.5):
        x = self.buf + S.reverb(self.send, room, damp, 1.0) - self.send * 0.5
        return S.loop_wrap(x, self.n)


# ---------------------------------------------------------------- event sounds
def frog(r):
    """Cute 'rib-bit': two AM-pulsed square croaks through an 'aw' formant."""
    f = r.uniform(150, 230)
    out = []
    for k, d in enumerate((0.09, 0.12)):
        c = S.osc(f * (1.15 if k else 1.0), d, "square") * (0.5 + 0.5 * np.sign(S.osc(r.uniform(28, 38), d)))
        out.append((S.formant(c, "aw") * S.adsr(d, 0.005, 0.02, 0.8, 0.02), k * 0.13, 1.0))
    return S.mix(*out)


def bubble(r):
    d = r.uniform(0.03, 0.06)
    f = r.uniform(250, 600)
    return S.osc(S.slide(f, f * 2.2, d), d) * S.perc(d, 0.002, d * 0.4)


def bubbles(r):
    return S.mix(*[(bubble(r), r.uniform(0, 0.4), r.uniform(0.4, 1.0)) for _ in range(r.integers(2, 6))])


def wisp(r):
    f = hz(r.choice(["D6", "A6", "F#6", "E6"]))
    return S.glock(f, 2.0, 0.8)


def owl(r):
    """Soft 'hoo-hoo' (sine through 'oo' formant), gentle."""
    f = r.uniform(360, 420)
    parts = []
    for k, (t, d) in enumerate(((0.0, 0.25), (0.35, 0.45))):
        s = S.osc(f * S.slide(1.05, 0.95, d), d) * S.adsr(d, 0.05, 0.05, 0.8, 0.12)
        parts.append((s, t, 0.8 if k == 0 else 1.0))
    return S.mix(*parts)


def creak(r):
    d = r.uniform(0.5, 1.0)
    f = S.slide(r.uniform(90, 130), r.uniform(140, 200), d) * (1 + 0.1 * S.lfo(d, r.uniform(8, 14)))
    return S.bp(S.osc(f, d, "saw"), 300, 1500) * S.segs([(0, 0), (0.1, 1), (d - 0.1, 0.7), (d, 0)], d)


def rustle(r):
    d = r.uniform(0.4, 0.9)
    return S.bp(S.crackle(d, 800, r) + 0.2 * S.noise(d, "pink", r), 1500, 6000) * S.segs([(0, 0), (d * 0.4, 1), (d, 0)], d)


def twig(r):
    return S.bp(S.crackle(0.05, 600, r), 1000, 5000) * S.perc(0.05, 0.001, 0.01)


def drip(r):
    d = 0.08
    f = r.uniform(1300, 2200)
    return S.osc(S.slide(f * 0.7, f, d), d) * S.perc(d, 0.001, 0.02)


def tink(r):
    return S.metal_clang(r.uniform(1800, 2600), 0.6, 0.1)


def pebbles(r):
    d = r.uniform(0.3, 0.8)
    return S.bp(S.crackle(d, 120, r), 700, 4000) * S.segs([(0, 1), (d, 0)], d)


def ice_tinkle(r):
    return S.mix(*[(S.bell(r.uniform(2500, 4500), 1.0, 1.0, 0.25), r.uniform(0, 0.3), 0.5) for _ in range(r.integers(2, 5))])


def ice_creak(r):
    d = r.uniform(0.4, 0.8)
    return S.lp(S.crackle(d, 300, r), 900) * S.segs([(0, 0), (d * 0.5, 1), (d, 0)], d)


def breath(r):
    d = r.uniform(2.5, 4.0)
    return S.bp(S.noise(d, "pink", r), 250, 900) * S.segs([(0, 0), (d * 0.5, 1), (d, 0)], d) ** 2


def far_bell(r):
    return S.bell(hz(r.choice(["D4", "A3", "F4"])), 5.0, 0.4, 2.2)


# ---------------------------------------------------------------- scenes
def amb_bog():
    a = Amb("amb_bog")
    gust = a.gusts(0.06, 0.5)
    a.bed("pink", lambda x: S.bp(x, 180, 700), 0.25, 0.2)
    a.bed("brown", lambda x: S.lp(x, 400), 0.15)            # water lapping body
    a.scatter(frog, 14, 0.18, 0.4)
    a.scatter(bubbles, 10, 0.25, 0.3)
    a.scatter(wisp, 3, 0.04, 0.9)
    a.buf[: a.n] *= 0.8 + 0.2 * gust
    return a.render(0.75, 0.6)


def amb_forest():
    a = Amb("amb_forest")
    gust = a.gusts(0.05, 0.7)
    a.bed("pink", lambda x: S.bp(x, 400, 2200), 0.3, 0.3)
    a.buf[: a.n] *= gust
    a.scatter(creak, 5, 0.08, 0.5)
    a.scatter(rustle, 8, 0.12, 0.4)
    a.scatter(twig, 10, 0.2, 0.3)
    a.scatter(owl, 3, 0.1, 0.7)
    return a.render(0.8, 0.5)


def amb_mine():
    a = Amb("amb_mine")
    a.bed("brown", lambda x: S.lp(x, 150), 0.3, 0.2)
    a.bed("pink", lambda x: S.bp(x, 200, 600), 0.06, 0.4)
    for _ in range(26):
        t = a.rng.uniform(0, LOOP)
        d = drip(a.rng)
        a.event(S.delay(d, 0.23, 0.35, 0.5, 3000, tail=1.0), t, a.rng.uniform(0.15, 0.3), 0.8)
    a.scatter(tink, 6, 0.05, 0.9)
    a.scatter(pebbles, 5, 0.12, 0.6)
    return a.render(0.92, 0.4)


def amb_ice():
    a = Amb("amb_ice")
    gust = a.gusts(0.07, 0.8)
    whistle_f = 700 + 300 * a.lfo(0.04)
    x = S.loop_crossfade(S.noise(LOOP + 2, "pink", a.rng), 2.0)
    howl = S.sweep(x, "bp", whistle_f)
    a.buf[: a.n] += howl * gust * 0.4
    a.send[: a.n] += howl * gust * 0.2
    a.bed("white", lambda y: S.hp(y, 4000), 0.03)
    a.scatter(ice_tinkle, 8, 0.1, 0.8)
    a.scatter(ice_creak, 4, 0.12, 0.5)
    return a.render(0.9, 0.2)


def amb_hush():
    a = Amb("amb_hush")
    a.bed("brown", lambda x: S.lp(x, 90), 0.25, 0.2)
    a.bed("white", lambda x: S.hp(x, 6000), 0.01)
    a.scatter(breath, 4, 0.2, 0.8)
    a.scatter(far_bell, 2, 0.05, 1.0)
    return a.render(0.95, 0.4)


SCENES = {"amb_bog": amb_bog, "amb_forest": amb_forest, "amb_mine": amb_mine, "amb_ice": amb_ice, "amb_hush": amb_hush}


def main(argv):
    ids = [a for a in argv if not a.startswith("-")] or list(SCENES)
    OUT.mkdir(parents=True, exist_ok=True)
    for i in ids:
        x = master_loop(SCENES[i](), -26.0 if i == "amb_hush" else -23.0)
        S.write_ogg(OUT / f"{i}.ogg", x, 0.35)
        print(f"{i}: {len(x) / S.SR:.1f} s")


if __name__ == "__main__":
    main(sys.argv[1:])

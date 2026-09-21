#!/usr/bin/env python3
"""Procedural SFX generator for PIPWRECK. Pure Python, no external libraries.

Writes 16 bit / 44.1 kHz mono WAV files to assets/sfx/ with `wave` + `struct`.
Everything is own-work: there is no sample material in this repository, only
maths. Re-running the script is byte deterministic (the noise source is a
seeded LCG), so the files can be regenerated in CI and diffed.

--- The sound identity: "chalk + metal" -----------------------------------

The visual direction is chalk on slate with pixel objects on top
(docs/UI_GUIDE.md section 1A / section 8). The audio mirrors it exactly, and
every single cue is built from the same two layers:

  CHALK  band limited noise with a very short decay and a little granular
         amplitude modulation. This is the dry, dusty, hand made transient:
         the scrape of a stick of chalk, the knock of wood on slate. It
         carries the RHYTHM and it is what makes a cue feel physical.

  METAL  an inharmonic partial stack (1.00, 2.01, 2.76, 3.93 - anvil/bell
         ratios, not a harmonic series) where high partials decay faster than
         low ones. This is the forge: iron, dice, the anvil slot. It carries
         the PITCH, which is what the chain's rising scale plays with.

A cue is never only one layer. Damage is mostly chalk with a metal thud under
it; a combo is mostly metal with a chalk tick on each note onset. That is the
whole trick: it keeps 17 different sounds inside one family.

Nothing here uses a harmonic sawtooth or a supersaw: those read as "synth
game" and would fight the handmade direction.

--- Levels ----------------------------------------------------------------

Every file is normalised to -3 dBFS peak (never clipped) with a fade out of
5 ms and a fade in of 5 ms (soft cues) or 1 ms (transient cues) so no cue can
click - see FADE_IN_SHARP_MS for why. -3 dBFS is the FILE level, not the MIX
level: the mix level per event lives in assets/sfx/README.md and is applied
by the event player with AudioStreamPlayer.volume_db. Normalising the files
and mixing in the engine means a cue can be re-balanced without regenerating
a WAV.

Run:  python3 tools/gen_sfx.py          (from rogelike_app/)
      python3 tools/gen_sfx.py --print-csv
"""

from __future__ import annotations

import argparse
import math
import struct
import wave
from pathlib import Path

SR: int = 44_100
PEAK: float = 10.0 ** (-3.0 / 20.0)  # -3 dBFS
FADE_OUT_MS: float = 5.0
# Fade IN is 5 ms on soft cues and 1 ms on transient ones. A 5 ms linear ramp
# is 220 samples: on a bell or a roar that is inaudible, but on a 60 ms tick it
# eats the attack - and the attack IS the feedback (UI_GUIDE section 5). 1 ms
# (44 samples) still removes any DC step at sample 0, which is all a fade in is
# for. Deliberate deviation from "5 ms in/out on everything", documented in
# assets/sfx/README.md.
FADE_IN_SOFT_MS: float = 5.0
FADE_IN_SHARP_MS: float = 1.0
OUT_DIR = Path("assets/sfx")

Signal = list[float]

# D major pentatonic, the scale UI_GUIDE section 5.2 asks for. Chosen because
# every subset of it is consonant, so the chain can stack steps without ever
# landing on a sour interval no matter which combo fires.
D4, E4, FS4, A4, B4 = 293.66, 329.63, 369.99, 440.00, 493.88
D5, E5, FS5, A5, B5 = 587.33, 659.26, 739.99, 880.00, 987.77
D3, A3 = 146.83, 220.00

# Anvil / bell ratios. Not a harmonic series: 2.01 and 2.76 are what make a
# struck metal bar read as metal instead of as an organ pipe.
METAL_PARTIALS: tuple[tuple[float, float, float], ...] = (
    # (ratio, gain, decay multiplier)
    (1.00, 1.00, 1.00),
    (2.01, 0.55, 0.62),
    (2.76, 0.32, 0.42),
    (3.93, 0.18, 0.26),
    (5.41, 0.09, 0.16),
)


# --- Deterministic noise ---------------------------------------------------


class Rng:
    """Numerical Recipes LCG. Deterministic across runs and platforms."""

    def __init__(self, seed: int) -> None:
        self.state = seed & 0xFFFFFFFF

    def next_float(self) -> float:
        self.state = (1664525 * self.state + 1013904223) & 0xFFFFFFFF
        return self.state / 2147483648.0 - 1.0  # -1..1


# --- Primitives ------------------------------------------------------------


def samples(ms: float) -> int:
    return max(1, int(round(SR * ms / 1000.0)))


def silence(ms: float) -> Signal:
    return [0.0] * samples(ms)


def noise(ms: float, seed: int) -> Signal:
    rng = Rng(seed)
    return [rng.next_float() for _ in range(samples(ms))]


def low_pass(sig: Signal, cutoff_hz: float) -> Signal:
    """One pole low pass. Two passes = 12 dB/oct, enough to feel 'dov'."""
    alpha = 1.0 - math.exp(-2.0 * math.pi * cutoff_hz / SR)
    out: Signal = []
    y = 0.0
    for x in sig:
        y += alpha * (x - y)
        out.append(y)
    return out


def high_pass(sig: Signal, cutoff_hz: float) -> Signal:
    alpha = 1.0 - math.exp(-2.0 * math.pi * cutoff_hz / SR)
    out: Signal = []
    y = 0.0
    for x in sig:
        y += alpha * (x - y)
        out.append(x - y)
    return out


def band(sig: Signal, low_hz: float, high_hz: float) -> Signal:
    return high_pass(low_pass(sig, high_hz), low_hz)


def env(n: int, attack_ms: float, decay_ms: float, curve: float = 4.0) -> Signal:
    """Percussive envelope: linear attack, exponential decay."""
    a = max(1, samples(attack_ms))
    out: Signal = []
    for i in range(n):
        if i < a:
            out.append(i / a)
        else:
            t = (i - a) / max(1.0, samples(decay_ms))
            out.append(math.exp(-curve * t))
    return out


def apply_env(sig: Signal, attack_ms: float, decay_ms: float, curve: float = 4.0) -> Signal:
    e = env(len(sig), attack_ms, decay_ms, curve)
    return [s * g for s, g in zip(sig, e)]


def glide(ms: float, f0: float, f1: float, shape: float = 1.0) -> Signal:
    """Sine with a frequency sweep. shape > 1 front loads the sweep."""
    n = samples(ms)
    out: Signal = []
    phase = 0.0
    for i in range(n):
        t = (i / max(1, n - 1)) ** shape
        f = f0 + (f1 - f0) * t
        phase += 2.0 * math.pi * f / SR
        out.append(math.sin(phase))
    return out


def chalk(ms: float, low_hz: float, high_hz: float, seed: int, grain_hz: float = 0.0) -> Signal:
    """The chalk layer: band limited noise, optionally granulated."""
    sig = band(noise(ms, seed), low_hz, high_hz)
    if grain_hz > 0.0:
        # Amplitude modulation with a rectified sine reads as 'scrape', not as
        # tremolo, because the dips reach zero.
        sig = [
            s * (0.35 + 0.65 * abs(math.sin(2.0 * math.pi * grain_hz * i / SR)))
            for i, s in enumerate(sig)
        ]
    return sig


def metal(ms: float, freq: float, decay_ms: float, partials=METAL_PARTIALS) -> Signal:
    """The metal layer: inharmonic partial stack, high partials die first."""
    n = samples(ms)
    out: Signal = [0.0] * n
    for ratio, gain, decay_mul in partials:
        f = freq * ratio
        if f > SR * 0.45:  # stay under Nyquist, no aliasing whine
            continue
        e = env(n, 0.4, decay_ms * decay_mul, curve=4.0)
        step = 2.0 * math.pi * f / SR
        for i in range(n):
            out[i] += math.sin(step * i) * gain * e[i]
    return out


def mix(*layers: Signal) -> Signal:
    n = max((len(layer) for layer in layers), default=0)
    out: Signal = [0.0] * n
    for layer in layers:
        for i, s in enumerate(layer):
            out[i] += s
    return out


def at(offset_ms: float, sig: Signal) -> Signal:
    """Place a layer later on the timeline."""
    return [0.0] * samples(offset_ms) + sig


def gain(sig: Signal, g: float) -> Signal:
    return [s * g for s in sig]


def pad(sig: Signal, ms: float) -> Signal:
    n = samples(ms)
    return (sig + [0.0] * n)[:n] if len(sig) < n else sig[:n]


# --- Output ----------------------------------------------------------------


def finish(sig: Signal, sharp: bool = False) -> Signal:
    """Apply the in/out fades, then normalise to -3 dBFS. Never clips.

    Order matters: fade first, normalise second. Normalising first and fading
    afterwards pushes the file below the target whenever the peak sits inside
    the fade window, which is exactly what happens on a 14 ms tick.
    """
    out = list(sig)
    n = len(out)
    fade_in = min(samples(FADE_IN_SHARP_MS if sharp else FADE_IN_SOFT_MS), n // 3)
    fade_out = min(samples(FADE_OUT_MS), n // 3)
    for i in range(fade_in):
        out[i] *= i / fade_in
    for i in range(fade_out):
        out[n - 1 - i] *= i / fade_out
    peak = max((abs(s) for s in out), default=0.0)
    if peak <= 1e-9:
        return out
    scale = PEAK / peak
    return [s * scale for s in out]


def write_wav(path: Path, sig: Signal) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    frames = bytearray()
    for s in sig:
        # Clamp is belt and braces: finish() already guarantees |s| <= 0.708.
        v = int(round(max(-1.0, min(1.0, s)) * 32767.0))
        frames += struct.pack("<h", v)
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SR)
        handle.writeframes(bytes(frames))


# --- The cues --------------------------------------------------------------
# Every function returns a finished signal. The seeds are arbitrary but fixed
# so the files stay byte identical between runs.


def die_activate() -> Signal:
    """~60 ms dry tick. Dev pitches this per chain step (README pitch rule)."""
    tick = apply_env(chalk(60, 1400.0, 6500.0, seed=1101), 0.4, 14.0, curve=7.0)
    ring = gain(apply_env(metal(60, A5, 22.0), 0.3, 22.0), 0.5)
    return finish(pad(mix(tick, ring), 60), sharp=True)


def _chord(notes: tuple[float, ...], step_ms: float, total_ms: float, decay_ms: float) -> Signal:
    """Rising arpeggio: one metal note per step, a chalk tick on each onset."""
    layers: list[Signal] = []
    for i, note in enumerate(notes):
        offset = i * step_ms
        layers.append(at(offset, gain(metal(total_ms - offset, note, decay_ms), 1.0 - i * 0.08)))
        layers.append(
            at(offset, gain(apply_env(chalk(24, 2200.0, 8000.0, seed=2200 + i * 7), 0.3, 6.0, 8.0), 0.30))
        )
    return pad(mix(*layers), total_ms)


def combo_pair() -> Signal:
    """x2. Two notes, 120 ms."""
    return finish(_chord((D5, FS5), 45.0, 120.0, 90.0))


def combo_triple() -> Signal:
    """x4. Three notes, 180 ms, brighter."""
    return finish(_chord((D5, FS5, A5), 45.0, 180.0, 130.0))


def combo_house() -> Signal:
    """x8 / house. Four notes plus the 55 Hz sub slug from UI_GUIDE 5.2."""
    top = _chord((D5, FS5, A5, B5), 42.0, 250.0, 180.0)
    sub = gain(apply_env(glide(180, 58.0, 52.0), 1.0, 90.0, curve=3.0), 0.85)
    return finish(pad(mix(top, sub), 250))


def damage_hit() -> Signal:
    """90 ms dull thump. Chalk slap over a short low metal thud."""
    slap = apply_env(chalk(90, 120.0, 1800.0, seed=3301), 0.6, 26.0, curve=5.0)
    body = gain(apply_env(glide(90, 190.0, 92.0, shape=0.55), 0.5, 30.0, curve=4.5), 1.0)
    thud = gain(apply_env(metal(90, D3, 40.0), 0.5, 40.0), 0.35)
    return finish(pad(mix(slap, body, thud), 90), sharp=True)


def damage_overflow() -> Signal:
    """Hit plus an upward whoosh: the chalk arrow drawn to the next target."""
    hit = damage_hit()
    sweep = gain(
        apply_env(band(noise(150, 3401), 600.0, 9000.0), 12.0, 70.0, curve=2.2), 0.7
    )
    # Rising resonant tone under the noise so the sweep has a direction.
    rise = gain(apply_env(glide(150, 420.0, 1500.0, shape=1.6), 8.0, 80.0, curve=3.0), 0.45)
    return finish(pad(mix(hit, at(20.0, sweep), at(20.0, rise)), 190), sharp=True)


def charge_store() -> Signal:
    """Soft bell. Side channel: long-ish, quiet, no transient bite."""
    bell = metal(240, B5, 200.0, partials=((1.0, 1.0, 1.0), (2.76, 0.30, 0.45), (5.41, 0.10, 0.2)))
    breath = gain(apply_env(chalk(240, 3000.0, 9000.0, seed=4401), 6.0, 40.0, 3.0), 0.12)
    return finish(pad(mix(apply_env(bell, 6.0, 200.0, 3.0), breath), 240))


def enemy_killed() -> Signal:
    """Short crash plus a falling tone. Death is a full stop, so it descends."""
    crash = apply_env(band(noise(200, 5501), 900.0, 11000.0), 0.8, 55.0, curve=3.2)
    fall = gain(apply_env(glide(220, A4, 130.0, shape=0.8), 1.0, 90.0, curve=3.5), 0.8)
    knock = gain(apply_env(metal(120, D4, 55.0), 0.4, 55.0), 0.45)
    return finish(pad(mix(crash, fall, knock), 240), sharp=True)


def die_cracked() -> Signal:
    """Glass splinter: noise shards plus a high ping. Deliberate pattern break."""
    layers: list[Signal] = [
        gain(apply_env(band(noise(260, 6601), 1800.0, 14000.0), 0.4, 70.0, curve=2.6), 0.9)
    ]
    # Individual shards: short high grains scattered over the first 120 ms.
    for i, offset in enumerate((6.0, 17.0, 31.0, 48.0, 72.0, 105.0)):
        layers.append(
            at(offset, gain(apply_env(chalk(40, 4000.0, 15000.0, seed=6700 + i * 13), 0.2, 8.0, 9.0), 0.75))
        )
    ping = gain(apply_env(metal(320, 2637.0, 230.0), 0.3, 230.0, 3.0), 0.55)
    thud = gain(apply_env(glide(200, 70.0, 45.0, shape=0.5), 1.0, 90.0, curve=3.0), 0.7)
    return finish(pad(mix(*layers, at(4.0, ping), thud), 380), sharp=True)


def enemy_attack() -> Signal:
    """Downward whoosh into a thump. The enemy pass, not the chain."""
    swoosh = gain(apply_env(band(noise(160, 7701), 400.0, 5200.0), 14.0, 60.0, curve=2.4), 0.75)
    drop = gain(apply_env(glide(160, 900.0, 220.0, shape=1.4), 8.0, 70.0, curve=3.0), 0.45)
    thump = at(130.0, gain(apply_env(glide(110, 150.0, 70.0, shape=0.5), 0.6, 40.0, curve=4.0), 1.0))
    slap = at(130.0, gain(apply_env(chalk(70, 150.0, 2200.0, seed=7801), 0.5, 22.0, 5.0), 0.55))
    return finish(pad(mix(swoosh, drop, thump, slap), 250), sharp=True)


def player_hurt() -> Signal:
    """Low pulse. Felt more than heard, so the player can take a hit blind."""
    pulse = apply_env(glide(220, 118.0, 74.0, shape=0.6), 2.0, 80.0, curve=3.2)
    grit = gain(apply_env(chalk(120, 200.0, 1400.0, seed=8801, grain_hz=70.0), 1.0, 45.0, 3.5), 0.45)
    return finish(pad(mix(pulse, grit), 240), sharp=True)


def reward_pick() -> Signal:
    """Soft confirmation. Two notes up, no bite: a choice, not an impact."""
    a = gain(apply_env(metal(220, A4, 170.0), 4.0, 170.0, 3.0), 1.0)
    b = at(70.0, gain(apply_env(metal(200, E5, 160.0), 4.0, 160.0, 3.0), 0.85))
    dust = gain(apply_env(chalk(90, 2500.0, 8000.0, seed=9901), 3.0, 30.0, 4.0), 0.15)
    return finish(pad(mix(a, b, dust), 300))


def ui_tap() -> Signal:
    """5 ms tick, 14 ms file. The smallest cue in the game: one chalk knock.

    The tick itself decays inside 5 ms; the extra 9 ms is silence-shaped tail
    so the 5 ms fade out lands on nothing instead of on the transient.
    """
    return finish(pad(apply_env(chalk(14, 1800.0, 9000.0, seed=10101), 0.15, 1.6, curve=10.0), 14), sharp=True)


def round_end() -> Signal:
    """Short cadence under the counting total, plus the dry tally scrape."""
    chord_a = mix(
        gain(apply_env(metal(320, A4, 260.0), 5.0, 260.0, 3.0), 0.9),
        gain(apply_env(metal(320, E5, 250.0), 5.0, 250.0, 3.0), 0.6),
    )
    chord_b = at(
        210.0,
        mix(
            gain(apply_env(metal(320, D5, 280.0), 4.0, 280.0, 3.0), 1.0),
            gain(apply_env(metal(320, FS5, 260.0), 4.0, 260.0, 3.0), 0.65),
        ),
    )
    scrape = at(330.0, gain(apply_env(chalk(190, 900.0, 5200.0, seed=11101, grain_hz=110.0), 8.0, 60.0, 3.0), 0.45))
    return finish(pad(mix(chord_a, chord_b, scrape), 560))


def boss_intro() -> Signal:
    """600 ms low roar. Detuned sub pair beating against each other."""
    n = samples(600)
    roar: Signal = [0.0] * n
    for freq, g in ((41.0, 1.0), (43.6, 0.8), (61.5, 0.45), (82.0, 0.25)):
        step = 2.0 * math.pi * freq / SR
        for i in range(n):
            roar[i] += math.sin(step * i) * g
    swell = [min(1.0, i / samples(220.0)) for i in range(n)]
    roar = [s * g for s, g in zip(roar, swell)]
    roar = apply_env(roar, 220.0, 320.0, curve=2.0)
    grind = gain(apply_env(low_pass(noise(600, 12101), 380.0), 180.0, 300.0, curve=2.0), 0.55)
    clang = at(360.0, gain(apply_env(metal(240, D3, 190.0), 0.5, 190.0), 0.30))
    return finish(pad(mix(roar, grind, clang), 600))


def victory() -> Signal:
    """800 ms fanfare. Same pentatonic, so it sounds like the chain resolved."""
    layers: list[Signal] = []
    for i, (note, offset) in enumerate(((D5, 0.0), (FS5, 110.0), (A5, 220.0))):
        layers.append(at(offset, gain(apply_env(metal(800 - offset, note, 300.0), 3.0, 300.0, 3.0), 0.8)))
        layers.append(
            at(offset, gain(apply_env(chalk(30, 2000.0, 8000.0, seed=13100 + i * 11), 0.3, 8.0, 8.0), 0.22))
        )
    # Final wide chord, held.
    for note, g in ((D5, 1.0), (A5, 0.7), (FS5, 0.6), (D4, 0.5)):
        layers.append(at(360.0, gain(apply_env(metal(440, note, 380.0), 5.0, 380.0, 2.4), g * 0.75)))
    return finish(pad(mix(*layers), 800))


def defeat() -> Signal:
    """Three falling notes. No noise layer: the chalk stops, the room is empty."""
    layers: list[Signal] = []
    for note, offset, g in ((A4, 0.0, 1.0), (FS4, 200.0, 0.85), (D4, 400.0, 0.9)):
        layers.append(at(offset, gain(apply_env(metal(900 - offset, note, 340.0), 6.0, 340.0, 2.6), g)))
    tail = at(400.0, gain(apply_env(glide(500, 147.0, 132.0, shape=1.0), 40.0, 260.0, 2.2), 0.45))
    return finish(pad(mix(*layers, tail), 900))


# path stem -> (builder, notes for ASSET_LICENSES.csv)
CUES: dict[str, tuple] = {
    "die_activate": (die_activate, "Kedjesteg, torr tick 60 ms, pitchas per steg"),
    "combo_pair": (combo_pair, "Combo x2, stigande tvaklang 120 ms"),
    "combo_triple": (combo_triple, "Combo x4, stigande treklang 180 ms"),
    "combo_house": (combo_house, "Combo x8/kak, fyrklang + sub 250 ms"),
    "damage_hit": (damage_hit, "Skada, dov small 90 ms"),
    "damage_overflow": (damage_overflow, "Overflod, small + svep uppat 190 ms"),
    "charge_store": (charge_store, "Laddning lagras, mjuk klockton 240 ms"),
    "enemy_killed": (enemy_killed, "Fiende dor, krasch + fallande ton 240 ms"),
    "die_cracked": (die_cracked, "Tarning spricker, glassplitter 380 ms"),
    "enemy_attack": (enemy_attack, "Fiendeattack, svep nedat + dunk 250 ms"),
    "player_hurt": (player_hurt, "Spelaren traffas, lag puls 240 ms"),
    "reward_pick": (reward_pick, "Belonig vald, mjuk bekraftelse 300 ms"),
    "ui_tap": (ui_tap, "UI-tryck, 5 ms tick"),
    "round_end": (round_end, "Rundans slut, kort kadens 560 ms"),
    "boss_intro": (boss_intro, "Boss entre, lagt dan 600 ms"),
    "victory": (victory, "Vinst, kort fanfar 800 ms"),
    "defeat": (defeat, "Forlust, tre fallande toner 900 ms"),
}


def generate(root: Path) -> list[tuple[str, str]]:
    """Write every cue. Returns (path, notes) for the license registry."""
    made: list[tuple[str, str]] = []
    for stem, (builder, note) in CUES.items():
        sig = builder()
        path = OUT_DIR / f"{stem}.wav"
        write_wav(root / path, sig)
        made.append((path.as_posix(), note))
    return made


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".")
    parser.add_argument("--print-csv", action="store_true")
    args = parser.parse_args()
    root = Path(args.root).resolve()
    made = generate(root)
    if args.print_csv:
        for path, note in made:
            print(f"{path},tools/gen_sfx.py,PIPWRECK UI,own-work,,2026-09-21,{note}")
    else:
        for path, note in made:
            size = (root / path).stat().st_size
            frames = (size - 44) // 2
            print(f"wrote {path}  ({frames / SR * 1000.0:6.1f} ms)  {note}")
        print(f"{len(made)} sfx")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

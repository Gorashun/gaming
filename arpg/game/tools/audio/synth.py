"""Wickwright in-house synthesis toolkit (numpy/scipy only, no samples).

Everything here is our own code: oscillators, noise, envelopes, pitch slides,
filters, Karplus-Strong plucks, FM bells, a Freeverb-style reverb, delay,
layering and loudness/peak utilities. Used by sfx_gen.py, music_gen.py and
ambience_gen.py. All output is 44.1 kHz mono float64 in [-1, 1].
"""
from __future__ import annotations

import numpy as np
from scipy import signal

SR = 44100
TAU = 2.0 * np.pi
_RNG = np.random.default_rng(12345)  # deterministic default when no rng is passed


# ---------------------------------------------------------------- basics
def n_samples(dur: float) -> int:
    return max(1, int(round(dur * SR)))


def silence(dur: float) -> np.ndarray:
    return np.zeros(n_samples(dur))


def tvec(dur: float) -> np.ndarray:
    return np.arange(n_samples(dur)) / SR


def midi_hz(m: float) -> float:
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


NOTE_OFFS = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def note(name: str) -> int:
    """'D5' -> midi 74, 'F#4' -> 66, 'Bb3' -> 58."""
    base = NOTE_OFFS[name[0].upper()]
    i = 1
    while i < len(name) and name[i] in "#b":
        base += 1 if name[i] == "#" else -1
        i += 1
    octave = int(name[i:])
    return base + 12 * (octave + 1)


def hz(name: str) -> float:
    return midi_hz(note(name))


# ---------------------------------------------------------------- control curves
def slide(f0: float, f1: float, dur: float, curve: str = "exp") -> np.ndarray:
    """Pitch/parameter slide over dur. curve: exp | lin | fast (exp ease-out)."""
    n = n_samples(dur)
    x = np.linspace(0.0, 1.0, n)
    if curve == "lin":
        return f0 + (f1 - f0) * x
    if curve == "fast":
        x = 1.0 - np.exp(-5.0 * x)
        x /= x[-1] if x[-1] else 1.0
    f0 = max(f0, 1e-3)
    f1 = max(f1, 1e-3)
    return f0 * (f1 / f0) ** x


def segs(points, dur: float) -> np.ndarray:
    """Piecewise-linear curve from [(time, value), ...] over dur seconds."""
    t = tvec(dur)
    ts = [p[0] for p in points]
    vs = [p[1] for p in points]
    return np.interp(t, ts, vs)


def adsr(dur: float, a=0.005, d=0.05, s=0.6, r=0.1, curve=2.0) -> np.ndarray:
    """ADSR where dur is total length (release included)."""
    n = n_samples(dur)
    na, nd, nr = n_samples(a), n_samples(d), n_samples(r)
    ns = max(0, n - na - nd - nr)
    att = np.linspace(0, 1, na) ** (1 / curve)
    dec = s + (1 - s) * (np.linspace(1, 0, nd) ** curve)
    sus = np.full(ns, s)
    rel = s * (np.linspace(1, 0, nr) ** curve)
    e = np.concatenate([att, dec, sus, rel])
    return fit(e, n)


def perc(dur: float, a=0.002, decay=0.2) -> np.ndarray:
    """Percussive envelope: short linear attack then exponential decay (time constant `decay`)."""
    t = tvec(dur)
    e = np.exp(-np.maximum(t - a, 0) / max(decay, 1e-4))
    na = n_samples(a)
    e[:na] *= np.linspace(0, 1, na)
    # smooth end to zero
    nt = min(len(e), n_samples(0.01))
    e[-nt:] *= np.linspace(1, 0, nt)
    return e


def fit(x: np.ndarray, n: int) -> np.ndarray:
    if len(x) >= n:
        return x[:n]
    return np.concatenate([x, np.zeros(n - len(x))])


def lfo(dur: float, rate: float, depth: float = 1.0, phase: float = 0.0) -> np.ndarray:
    return depth * np.sin(TAU * rate * tvec(dur) + phase)


# ---------------------------------------------------------------- oscillators
def _phase(freq, dur: float, phase0: float = 0.0) -> np.ndarray:
    n = n_samples(dur)
    if np.isscalar(freq):
        f = np.full(n, float(freq))
    else:
        f = fit(np.asarray(freq, dtype=float), n)
        if len(freq) < n:
            f[len(freq):] = freq[-1]
    return phase0 + np.cumsum(f) / SR  # in cycles


def _polyblep(tph: np.ndarray, dt: np.ndarray) -> np.ndarray:
    out = np.zeros_like(tph)
    m = tph < dt
    x = tph[m] / dt[m]
    out[m] = x + x - x * x - 1.0
    m2 = tph > 1.0 - dt
    x = (tph[m2] - 1.0) / dt[m2]
    out[m2] = x * x + x + x + 1.0
    return out


def osc(freq, dur: float, shape: str = "sine", duty: float = 0.5, phase0: float = 0.0) -> np.ndarray:
    """Band-limited-ish oscillators (polyBLEP saw/square). freq: scalar or per-sample array."""
    ph = _phase(freq, dur, phase0)
    frac = ph % 1.0
    if shape == "sine":
        return np.sin(TAU * ph)
    if shape == "tri":
        return 2.0 * np.abs(2.0 * frac - 1.0) - 1.0
    n = len(ph)
    f = np.diff(ph, prepend=ph[0] - (ph[1] - ph[0] if n > 1 else 0.0))
    dt = np.clip(np.abs(f), 1e-6, 0.5)
    if shape == "saw":
        return (2.0 * frac - 1.0) - _polyblep(frac, dt)
    if shape == "square":
        sq = np.where(frac < duty, 1.0, -1.0)
        sq += _polyblep(frac, dt)
        sq -= _polyblep((frac + (1.0 - duty)) % 1.0, dt)
        return sq
    raise ValueError(shape)


def supersaw(freq, dur: float, voices: int = 5, detune: float = 0.012, rng=None, shape="saw") -> np.ndarray:
    rng = rng or np.random.default_rng(0)
    out = np.zeros(n_samples(dur))
    for i in range(voices):
        d = 1.0 + detune * (i - (voices - 1) / 2) / max(1, (voices - 1) / 2)
        f = freq * d if np.isscalar(freq) else np.asarray(freq) * d
        out += osc(f, dur, shape, phase0=rng.random())
    return out / voices


def fm(carrier, dur: float, ratio: float = 3.5, index=2.0, mod_env=None) -> np.ndarray:
    """2-op FM. index may be a per-sample envelope."""
    n = n_samples(dur)
    cph = _phase(carrier, dur)
    if np.isscalar(carrier):
        mf = carrier * ratio
    else:
        mf = fit(np.asarray(carrier), n) * ratio
    mph = _phase(mf, dur)
    idx = index if np.isscalar(index) else fit(np.asarray(index), n)
    if mod_env is not None:
        idx = idx * fit(mod_env, n)
    return np.sin(TAU * cph + idx * np.sin(TAU * mph))


def additive(f0: float, dur: float, partials) -> np.ndarray:
    """partials: [(ratio, amp, decay_seconds or None), ...]"""
    t = tvec(dur)
    out = np.zeros_like(t)
    for ratio, amp, dec in partials:
        f = f0 * ratio
        if f >= SR / 2 - 200:
            continue
        p = amp * np.sin(TAU * f * t)
        if dec:
            p *= np.exp(-t / dec)
        out += p
    return out


# ---------------------------------------------------------------- noise
def noise(dur: float, color: str = "white", rng=None) -> np.ndarray:
    rng = rng or _RNG
    n = n_samples(dur)
    w = rng.standard_normal(n)
    if color == "white":
        out = w
    elif color == "pink":
        # Paul Kellet's economy pink filter approximated via IIR
        b = [0.049922035, -0.095993537, 0.050612699, -0.004408786]
        a = [1, -2.494956002, 2.017265875, -0.522189400]
        out = signal.lfilter(b, a, w)
    elif color == "brown":
        out = signal.lfilter([1.0], [1.0, -0.995], w)
    else:
        raise ValueError(color)
    return out / (np.max(np.abs(out)) + 1e-9)


def crackle(dur: float, density: float = 30.0, rng=None) -> np.ndarray:
    """Sparse random impulses (fire crackle, glitter, pebbles)."""
    rng = rng or _RNG
    n = n_samples(dur)
    out = np.zeros(n)
    k = rng.poisson(density * dur)
    idx = rng.integers(0, n, k)
    out[idx] = rng.uniform(-1, 1, k)
    return out


# ---------------------------------------------------------------- filters
def _sos(kind: str, cutoff, order: int = 2, q: float | None = None):
    nyq = SR / 2
    if kind in ("lp", "hp"):
        c = float(np.clip(cutoff, 10, nyq * 0.98)) / nyq
        return signal.butter(order, c, btype="low" if kind == "lp" else "high", output="sos")
    lo, hi = cutoff
    lo = float(np.clip(lo, 10, nyq * 0.97)) / nyq
    hi = float(np.clip(hi, lo * nyq + 5, nyq * 0.98)) / nyq
    return signal.butter(order, [lo, hi], btype="band", output="sos")


def lp(x, cutoff: float, order: int = 2):
    return signal.sosfilt(_sos("lp", cutoff, order), x)


def hp(x, cutoff: float, order: int = 2):
    return signal.sosfilt(_sos("hp", cutoff, order), x)


def bp(x, lo: float, hi: float, order: int = 2):
    return signal.sosfilt(_sos("bp", (lo, hi), order), x)


def peak(x, f0: float, q: float = 4.0, gain_db: float = 6.0):
    """RBJ peaking EQ."""
    A = 10 ** (gain_db / 40)
    w0 = TAU * f0 / SR
    alpha = np.sin(w0) / (2 * q)
    b = [1 + alpha * A, -2 * np.cos(w0), 1 - alpha * A]
    a = [1 + alpha / A, -2 * np.cos(w0), 1 - alpha / A]
    return signal.lfilter(b, a, x)


def resonator(x, f0: float, q: float = 30.0):
    """Narrow band-pass (constant 0 dB peak) - formants, ringing, wind whistles."""
    w0 = TAU * f0 / SR
    alpha = np.sin(w0) / (2 * q)
    b = [alpha, 0, -alpha]
    a = [1 + alpha, -2 * np.cos(w0), 1 - alpha]
    return signal.lfilter(b, a, x)


def sweep(x, kind: str, cutoff_curve, block: int = 256, order: int = 2):
    """Time-varying filter: coefficients updated every `block` samples (state carried)."""
    x = np.asarray(x, dtype=float)
    n = len(x)
    cc = fit(np.asarray(cutoff_curve, dtype=float), n) if not np.isscalar(cutoff_curve) else np.full(n, cutoff_curve)
    if not np.isscalar(cutoff_curve) and len(cutoff_curve) < n:
        cc[len(cutoff_curve):] = cutoff_curve[-1]
    out = np.empty(n)
    zi = None
    for s in range(0, n, block):
        e = min(n, s + block)
        c = cc[s]
        if kind == "bp":
            sos = _sos("bp", (c / 1.35, c * 1.35), order)
        else:
            sos = _sos(kind, c, order)
        if zi is None:
            zi = np.zeros((sos.shape[0], 2))
        out[s:e], zi = signal.sosfilt(sos, x[s:e], zi=zi)
    return out


def formant(x, vowel: str = "oo"):
    """Parallel formant filter bank for choir/voice-like pads (kid-safe 'ooh'/'aah')."""
    table = {
        "oo": [(300, 1.0, 8), (870, 0.35, 10), (2240, 0.08, 12)],
        "oh": [(400, 1.0, 8), (800, 0.5, 10), (2600, 0.08, 12)],
        "ah": [(700, 1.0, 7), (1220, 0.5, 9), (2600, 0.15, 12)],
        "ee": [(280, 1.0, 8), (2250, 0.3, 12), (2900, 0.15, 14)],
        "aw": [(570, 1.0, 7), (840, 0.6, 9), (2410, 0.1, 12)],
    }[vowel]
    out = np.zeros_like(x)
    for f, g, q in table:
        out += g * resonator(x, f, q)
    return out


# ---------------------------------------------------------------- physical-ish instruments
def pluck(f0: float, dur: float, bright: float = 0.6, damp: float = 0.996, rng=None) -> np.ndarray:
    """Karplus-Strong via a single IIR (lfilter), so it is fast."""
    rng = rng or _RNG
    n = n_samples(dur)
    period = SR / f0
    N = max(2, int(np.floor(period)) - 1)
    p = period - (N + 1)
    exc = rng.uniform(-1, 1, N + 1)
    exc = lp(exc, 800 + 9000 * bright)
    exc -= exc.mean()
    x = np.zeros(n)
    x[: N + 1] = exc[: min(N + 1, n)]
    # loop filter: fractional-delayed [.25 .5 .25] lowpass -> total delay N+1+p = period
    w = (1 - p) * np.array([0.25, 0.5, 0.25, 0.0]) + p * np.array([0.0, 0.25, 0.5, 0.25])
    a = np.zeros(N + 4)
    a[0] = 1.0
    a[N:N + 4] -= damp * w
    y = dc_block(signal.lfilter([1.0], a, x))
    return y * perc(dur, 0.001, dur * 0.6)


def bell(f0: float, dur: float, bright: float = 1.0, decay: float = 1.5) -> np.ndarray:
    """Inharmonic additive bell (church/glass). bright scales upper partials."""
    parts = [(0.5, 0.35, decay * 1.4), (1.0, 1.0, decay), (1.19, 0.45 * bright, decay * 0.8),
             (1.56, 0.3 * bright, decay * 0.6), (2.0, 0.5 * bright, decay * 0.55),
             (2.51, 0.22 * bright, decay * 0.4), (3.0, 0.18 * bright, decay * 0.3),
             (4.07, 0.12 * bright, decay * 0.2)]
    return additive(f0, dur, parts) * perc(dur, 0.001, dur * 10)


def glock(f0: float, dur: float, decay: float = 0.8) -> np.ndarray:
    """Music-box / celesta tine."""
    parts = [(1.0, 1.0, decay), (2.0, 0.08, decay * 0.4), (3.0, 0.02, decay * 0.3), (5.4, 0.15, decay * 0.12)]
    return additive(f0, dur, parts) * perc(dur, 0.001, dur * 10)


def marimba(f0: float, dur: float, decay: float = 0.35) -> np.ndarray:
    parts = [(1.0, 1.0, decay), (3.93, 0.3, decay * 0.25), (9.2, 0.08, decay * 0.1)]
    return additive(f0, dur, parts) * perc(dur, 0.002, dur * 10)


def metal_clang(f0: float, dur: float, decay: float = 0.6) -> np.ndarray:
    parts = [(1.0, 1.0, decay), (1.47, 0.7, decay * 0.9), (2.09, 0.55, decay * 0.7),
             (2.56, 0.4, decay * 0.5), (3.37, 0.35, decay * 0.4), (4.61, 0.25, decay * 0.25),
             (5.83, 0.2, decay * 0.18)]
    return additive(f0, dur, parts) * perc(dur, 0.0005, dur * 10)


# ---------------------------------------------------------------- effects
def _comb(x, delay: int, fb: float, damp: float):
    # lowpass-feedback comb (Freeverb): y[n] = x[n-d] + fb*((1-damp)*y[n-d] + damp*y[n-d-1])
    a = np.zeros(delay + 2)
    a[0] = 1.0
    a[delay] = -fb * (1 - damp)
    a[delay + 1] = -fb * damp
    b = np.zeros(delay + 1)
    b[delay] = 1.0
    return signal.lfilter(b, a, x)


def _allpass(x, delay: int, g: float = 0.5):
    b = np.zeros(delay + 1)
    a = np.zeros(delay + 1)
    b[0] = -g
    b[delay] = 1.0
    a[0] = 1.0
    a[delay] = -g
    return signal.lfilter(b, a, x)


def reverb(x, room: float = 0.7, damp: float = 0.4, wet: float = 0.3, predelay: float = 0.01,
           tail: float = 0.0) -> np.ndarray:
    """Freeverb-style mono reverb. tail: seconds of extra length appended."""
    x = np.concatenate([np.asarray(x, dtype=float), np.zeros(n_samples(tail) if tail else 0)])
    pd = n_samples(predelay)
    xin = np.concatenate([np.zeros(pd), x])[: len(x)] * 0.2
    fb = 0.7 + 0.28 * room
    combs = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617]
    acc = np.zeros_like(x)
    for d in combs:
        acc += _comb(xin, d, fb, damp)
    for d in (556, 441, 341, 225):
        acc = _allpass(acc, d)
    return x * (1 - wet * 0.5) + acc * wet


def delay(x, time: float, fb: float = 0.35, mix: float = 0.3, tone: float = 4000.0, tail: float = 0.0):
    x = np.concatenate([np.asarray(x, dtype=float), np.zeros(n_samples(tail) if tail else 0)])
    d = n_samples(time)
    a = np.zeros(d + 1)
    a[0] = 1.0
    a[d] = -fb
    b = np.zeros(d + 1)
    b[d] = 1.0
    wet = signal.lfilter(b, a, x)
    wet = lp(wet, tone)
    return x + mix * wet


def drive(x, amount: float = 2.0):
    return np.tanh(x * amount) / np.tanh(amount)


def bitcrush(x, bits: int = 8):
    q = 2 ** (bits - 1)
    return np.round(x * q) / q


def tremolo(x, rate: float, depth: float = 0.5):
    t = np.arange(len(x)) / SR
    return x * (1 - depth * 0.5 * (1 + np.sin(TAU * rate * t)))


# ---------------------------------------------------------------- layering / mastering
def mix(*layers, length: float | None = None) -> np.ndarray:
    """layers: (signal, offset_seconds, gain) tuples or bare arrays."""
    items = []
    for L in layers:
        if isinstance(L, tuple):
            sig, off, g = (L + (1.0,))[:3] if len(L) == 2 else L
        else:
            sig, off, g = L, 0.0, 1.0
        items.append((np.asarray(sig, dtype=float), n_samples(off) if off else 0, g))
    n = max(o + len(s) for s, o, g in items)
    if length is not None:
        n = n_samples(length)
    out = np.zeros(n)
    for s, o, g in items:
        e = min(n, o + len(s))
        if e > o:
            out[o:e] += g * s[: e - o]
    return out


def fade(x, fin: float = 0.002, fout: float = 0.01):
    x = np.array(x, dtype=float)
    a, b = n_samples(fin), n_samples(fout)
    a, b = min(a, len(x)), min(b, len(x))
    x[:a] *= np.linspace(0, 1, a)
    x[len(x) - b:] *= np.linspace(1, 0, b) ** 2
    return x


def trim_silence(x, thresh_db: float = -60.0, keep: float = 0.02):
    thr = 10 ** (thresh_db / 20) * (np.max(np.abs(x)) + 1e-12)
    idx = np.nonzero(np.abs(x) > thr)[0]
    if len(idx) == 0:
        return x
    end = min(len(x), idx[-1] + n_samples(keep))
    return x[:end]


def dc_block(x):
    return signal.lfilter([1, -1], [1, -0.9995], x)


def normalize(x, peak_db: float = -1.0):
    m = np.max(np.abs(x))
    if m < 1e-9:
        return x
    return x * (10 ** (peak_db / 20) / m)


def rms_db(x):
    return 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-12)


def master(x, rms_target_db: float = -18.0, peak_db: float = -1.0, hp_hz: float = 35.0):
    """Music/ambience mastering: HP rumble, RMS target, soft-knee limiter, peak ceiling."""
    x = hp(dc_block(x), hp_hz)
    x = x * 10 ** ((rms_target_db - rms_db(x)) / 20)
    ceil = 10 ** (peak_db / 20)
    # soft limiter above 70% of ceiling
    knee = 0.7 * ceil
    y = np.where(np.abs(x) <= knee, x,
                 np.sign(x) * (knee + (ceil - knee) * np.tanh((np.abs(x) - knee) / (ceil - knee))))
    m = np.max(np.abs(y))
    if m > ceil:
        y *= ceil / m
    return y


def loop_wrap(x, loop_len_samples: int):
    """Seamless loop: fold everything rendered past the loop point (reverb/release tails)
    back onto the start, so the end flows into the beginning with no gap or click."""
    x = np.asarray(x, dtype=float)
    L = loop_len_samples
    out = fit(x, L).copy()
    tail = x[L:]
    while len(tail):
        k = min(L, len(tail))
        out[:k] += tail[:k]
        tail = tail[k:]
    return out


def loop_crossfade(x, xfade: float = 1.0):
    """For material with no defined tail (noise beds): crossfade the last `xfade` s into the start."""
    x = np.asarray(x, dtype=float)
    n = n_samples(xfade)
    body = x[: len(x) - n].copy()
    tail = x[len(x) - n:]
    ramp = np.linspace(0, 1, n)
    body[:n] = body[:n] * np.sqrt(ramp) + tail * np.sqrt(1 - ramp)
    return body


def write_wav(path, x, peak_db: float = -1.0):
    import soundfile as sf
    x = normalize(dc_block(np.asarray(x, dtype=float)), peak_db)
    sf.write(str(path), x.astype(np.float32), SR, subtype="PCM_16")


def write_ogg(path, x, quality: float = 0.4):
    import soundfile as sf
    x = np.asarray(x, dtype=np.float32)
    try:
        sf.write(str(path), x, SR, format="OGG", subtype="VORBIS", compression_level=1.0 - quality)
    except TypeError:
        sf.write(str(path), x, SR, format="OGG", subtype="VORBIS")

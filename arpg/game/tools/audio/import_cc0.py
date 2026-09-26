#!/usr/bin/env python3
"""Convert selected CC0 UI cues (uisfx 0.4.0, ASSET_SOURCES.md A-012) into our
Sfx id layout. Run AFTER sfx_gen.py: these files replace the synthesized UI
fallbacks for the same ids. Use `--undo` to fall back to our synthesized UI set.

Conversion: 48 kHz OGG -> 44.1 kHz (polyphase resample), mono, 16-bit WAV,
peak-normalized to -1 dBFS. No other edits.
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.signal import resample_poly

sys.path.insert(0, str(Path(__file__).resolve().parent))
import synth as S  # noqa: E402

GAME = Path(__file__).resolve().parents[2]
SRC = GAME / "assets" / "thirdparty" / "uisfx" / "ui-sfx-0.4.0"
OUT = GAME / "assets" / "generated" / "sfx"

# id -> list of source files (first = <id>.wav, then <id>_1.wav, ...)
CC0_MAP = {
    "ui_click": ["soft/press.ogg", "organic/press.ogg"],
    "menu_open": ["soft/open.ogg"],
    "menu_close": ["soft/close.ogg"],
    "error": ["soft/error.ogg"],
}


def convert(src: Path) -> np.ndarray:
    x, sr = sf.read(str(src), always_2d=True)
    x = x.mean(axis=1)
    if sr != S.SR:
        g = np.gcd(sr, S.SR)
        x = resample_poly(x, S.SR // g, sr // g)
    return S.fade(S.trim_silence(x, -62.0), 0.0005, 0.01)


def main(argv):
    if "--undo" in argv:
        import sfx_gen
        for i in CC0_MAP:
            sfx_gen.render(i)
            print(f"{i}: synthesized fallback restored")
        return
    for id_, files in CC0_MAP.items():
        for v, rel in enumerate(files):
            p = OUT / (f"{id_}.wav" if v == 0 else f"{id_}_{v}.wav")
            S.write_wav(p, convert(SRC / rel), -1.0)
        for v in range(len(files), 5):
            sp = OUT / f"{id_}_{v}.wav"
            if sp.exists():
                sp.unlink()
                imp = sp.with_suffix(".wav.import")
                if imp.exists():
                    imp.unlink()
        print(f"{id_}: {len(files)} file(s) from uisfx (CC0)")


if __name__ == "__main__":
    main(sys.argv[1:])

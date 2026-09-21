#!/usr/bin/env python3
"""Generate the Android launcher icons for PIPWRECK.

Four files land in ``assets/icons/android/``:

===========================  ======  =====================================
File                         Size    Used by
===========================  ======  =====================================
``icon_foreground.png``      432     adaptive icon, foreground layer
``icon_background.png``      432     adaptive icon, background layer
``icon_monochrome.png``      432     Android 13+ themed ("monochrome") icon
``icon_legacy.png``          192     launchers older than Android 8
===========================  ======  =====================================

The motif is the PIPWRECK die: a chalk square with the five-pip face, the
middle pip in ``sem/fire``. Same idea as ``assets/icon.svg`` but drawn in the
UI_GUIDE section 2 palette instead of the placeholder colours, and with the
chalk treatment (wobbly edge + grain) the rest of the game uses.

**Why a generator and not a hand-drawn PNG:** the four sizes must stay in sync,
and the run must be byte reproducible so a rebuild never shows up as a diff.
Every random-looking value here comes from a fixed integer hash, never from
``random``.

**Adaptive icon geometry** (developer.android.com/develop/ui/views/launch/icon_design_adaptive):
the layers are 108 dp square, the launcher mask only guarantees the inner
72 dp, and a circular mask cuts everything outside a 72 dp circle. At 4x that
is a 432 px canvas with a 288 px safe box, i.e. a circle of radius 144 px
around the centre. The die is sized so its outermost chalk pixel sits at
radius 127 px, which leaves room for the parallax launchers apply on scroll.

Usage::

    python3 tools/gen_icons.py                 # run from rogelike_app/
    python3 tools/gen_icons.py --out DIR       # write somewhere else
"""

from __future__ import annotations

import argparse
import math
from pathlib import Path

from pixel_png import Canvas, color, write_png

# --- Palette (docs/UI_GUIDE.md section 2) ----------------------------------

CHALK = color("chalk100")  # #F2EDE3 line work
CHALK_DUST = color("chalk100", 26)  # 10 % fill inside the die
FIRE = color("fire")  # #FF6A2C middle pip
PIT = color("pit")  # #0E1216 background layer
SLATE = color("slate")  # #161B21 centre of the background wash
WHITE = (255, 255, 255, 255)  # monochrome layer; Android tints it itself

# --- Geometry --------------------------------------------------------------

ADAPTIVE_SIZE = 432
LEGACY_SIZE = 192

# All die measurements are ratios of the die's own half-width, so the legacy
# icon is the exact same drawing at another scale.
CORNER_RATIO = 0.26  # rounded corner radius
STROKE_RATIO = 0.068  # chalk line, half-width
PIP_OFFSET_RATIO = 0.50  # corner pips, from the centre
PIP_RADIUS_RATIO = 0.175

# Half-width of the die itself.
ADAPTIVE_DIE_HALF = 92.0  # outermost pixel ends up at radius 127 of 144
LEGACY_DIE_HALF = 57.0  # legacy icons are not masked, so the die may be bigger

# A few degrees off-axis reads as "thrown", not "placed". Straight dice look
# like a spreadsheet cell at 48 dp.
TILT_DEG = -7.0

# Corner rounding of the legacy icon itself (assets/icon.svg uses rx=24/128).
LEGACY_CORNER_RATIO = 24.0 / 128.0

# --- Sampling --------------------------------------------------------------

# 3x3 samples per pixel. Enough for smooth diagonals at 432 px; 2x2 leaves a
# visible staircase on the tilted corners.
SUPERSAMPLE = 3

# Chalk wobble: the edge is displaced by up to this many pixels (at 432 px)
# by a noise field, which is what keeps the square from looking vector-drawn.
WOBBLE_PX = 2.0
WOBBLE_CELL = 26.0
# Grain: fraction of alpha the noise may eat out of a chalk pixel.
GRAIN_DEPTH = 0.18
GRAIN_CELL = 3.5


def _hash2(ix: int, iy: int, seed: int) -> float:
    """Deterministic [0,1) value for an integer lattice point."""
    h = (ix * 374761393 + iy * 668265263 + seed * 1442695040888963407) & 0xFFFFFFFF
    h = (h ^ (h >> 13)) * 1274126177 & 0xFFFFFFFF
    h = h ^ (h >> 16)
    return (h & 0xFFFFFF) / float(0x1000000)


def _noise(x: float, y: float, cell: float, seed: int) -> float:
    """Bilinear value noise in [0,1). Cheap, stable and dependency free."""
    fx, fy = x / cell, y / cell
    ix, iy = math.floor(fx), math.floor(fy)
    tx, ty = fx - ix, fy - iy
    # Smoothstep so the lattice does not show up as a grid of diamonds.
    tx = tx * tx * (3.0 - 2.0 * tx)
    ty = ty * ty * (3.0 - 2.0 * ty)
    n00 = _hash2(ix, iy, seed)
    n10 = _hash2(ix + 1, iy, seed)
    n01 = _hash2(ix, iy + 1, seed)
    n11 = _hash2(ix + 1, iy + 1, seed)
    return (n00 * (1 - tx) + n10 * tx) * (1 - ty) + (n01 * (1 - tx) + n11 * tx) * ty


def _sd_round_rect(x: float, y: float, half: float, radius: float) -> float:
    """Signed distance to a rounded square centred on the origin."""
    qx = abs(x) - (half - radius)
    qy = abs(y) - (half - radius)
    outside = math.hypot(max(qx, 0.0), max(qy, 0.0))
    inside = min(max(qx, qy), 0.0)
    return outside + inside - radius


def _mix(a: tuple[int, int, int, int], b: tuple[int, int, int, int], t: float) -> tuple[int, int, int, int]:
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(4))  # type: ignore[return-value]


# --- Layers ----------------------------------------------------------------


def draw_die(size: int, die_half: float, mono: bool = False) -> Canvas:
    """The die, drawn on a transparent canvas of ``size`` x ``size``.

    ``mono`` drops the fire pip and the chalk dust: Android's themed icons are
    a single-colour silhouette that the system tints, so any colour or partial
    fill in there just turns to mud.
    """
    canvas = Canvas(size, size)
    centre = size / 2.0
    scale = size / float(ADAPTIVE_SIZE)

    radius = die_half * CORNER_RATIO
    stroke = die_half * STROKE_RATIO
    pip_offset = die_half * PIP_OFFSET_RATIO
    pip_radius = die_half * PIP_RADIUS_RATIO
    wobble = WOBBLE_PX * scale
    line = WHITE if mono else CHALK

    angle = math.radians(TILT_DEG)
    cos_a, sin_a = math.cos(angle), math.sin(angle)

    # (x, y, is_fire). The middle pip is the only colour in the icon.
    pips: list[tuple[float, float, bool]] = [
        (-pip_offset, -pip_offset, False),
        (pip_offset, -pip_offset, False),
        (0.0, 0.0, not mono),
        (-pip_offset, pip_offset, False),
        (pip_offset, pip_offset, False),
    ]

    step = 1.0 / SUPERSAMPLE
    offsets = [(i + 0.5) * step for i in range(SUPERSAMPLE)]
    weight = 1.0 / (SUPERSAMPLE * SUPERSAMPLE)

    for py in range(size):
        for px in range(size):
            # Accumulated coverage per material, resolved once per pixel.
            cov_line = 0.0
            cov_fill = 0.0
            cov_fire = 0.0
            for oy in offsets:
                for ox in offsets:
                    sx = px + ox - centre
                    sy = py + oy - centre
                    # Rotate the sample into the die's own frame.
                    lx = sx * cos_a + sy * sin_a
                    ly = -sx * sin_a + sy * cos_a
                    # Chalk never runs straight: displace the distance field.
                    jitter = (_noise(sx, sy, WOBBLE_CELL * scale, 0x5EED) - 0.5) * 2.0 * wobble
                    body = _sd_round_rect(lx, ly, die_half, radius) + jitter
                    if abs(body) <= stroke:
                        cov_line += weight
                    elif body < 0.0:
                        cov_fill += weight
                    for cx, cy, is_fire in pips:
                        d = math.hypot(lx - cx, ly - cy) + jitter * 0.5 - pip_radius
                        if d <= 0.0:
                            if is_fire:
                                cov_fire += weight
                            else:
                                cov_line += weight
                            break
            if cov_line <= 0.0 and cov_fill <= 0.0 and cov_fire <= 0.0:
                continue
            # Grain eats a little alpha out of every chalk pixel. Applied after
            # coverage so the anti-aliased edge keeps its shape.
            grain = 1.0 - GRAIN_DEPTH * _noise(px / scale, py / scale, GRAIN_CELL, 0xC4A1)
            if cov_fire > 0.0:
                canvas.over(px, py, (FIRE[0], FIRE[1], FIRE[2], int(round(255 * min(1.0, cov_fire) * grain))))
            if cov_fill > 0.0 and not mono:
                canvas.over(px, py, (CHALK_DUST[0], CHALK_DUST[1], CHALK_DUST[2],
                                     int(round(CHALK_DUST[3] * min(1.0, cov_fill)))))
            if cov_line > 0.0:
                canvas.over(px, py, (line[0], line[1], line[2], int(round(255 * min(1.0, cov_line) * grain))))
    return canvas


def draw_background(size: int, rounded: bool = False) -> Canvas:
    """The dark layer: surface/pit with a barely-there wash toward the centre.

    Flat ``#0E1216`` is correct but dead; the wash gives the die something to
    sit in without introducing a second colour. ``rounded`` shapes the corners
    for the legacy icon, which no launcher masks for us.
    """
    canvas = Canvas(size, size)
    centre = size / 2.0
    corner = size * LEGACY_CORNER_RATIO
    max_r = centre * 1.05
    for py in range(size):
        for px in range(size):
            dx = px + 0.5 - centre
            dy = py + 0.5 - centre
            t = min(1.0, math.hypot(dx, dy) / max_r)
            # Squared falloff: the lighter middle stays inside the mask.
            wash = _mix(SLATE, PIT, t * t)
            # A trace of grain so the flat area does not band on OLED panels.
            n = _noise(px, py, 5.0, 0x1DEA) - 0.5
            rgb = tuple(max(0, min(255, int(round(wash[i] + n * 3.0)))) for i in range(3))
            alpha = 255
            if rounded:
                d = _sd_round_rect(dx, dy, centre, corner)
                if d >= 0.5:
                    continue
                if d > -0.5:
                    alpha = int(round(255 * (0.5 - d)))
            canvas.set(px, py, (rgb[0], rgb[1], rgb[2], alpha))
    return canvas


def compose(background: Canvas, foreground: Canvas) -> Canvas:
    out = Canvas(background.width, background.height)
    out.blit(background, 0, 0)
    out.blit(foreground, 0, 0)
    return out


# --- Entry point -----------------------------------------------------------


def generate(out_dir: Path) -> list[Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    written: list[Path] = []

    foreground = draw_die(ADAPTIVE_SIZE, ADAPTIVE_DIE_HALF)
    written.append(write_png(out_dir / "icon_foreground.png", foreground))
    written.append(write_png(out_dir / "icon_background.png", draw_background(ADAPTIVE_SIZE)))
    written.append(
        write_png(out_dir / "icon_monochrome.png", draw_die(ADAPTIVE_SIZE, ADAPTIVE_DIE_HALF, mono=True))
    )

    legacy = compose(
        draw_background(LEGACY_SIZE, rounded=True),
        draw_die(LEGACY_SIZE, LEGACY_DIE_HALF),
    )
    written.append(write_png(out_dir / "icon_legacy.png", legacy))
    return written


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--out",
        default="assets/icons/android",
        help="output directory (default: assets/icons/android)",
    )
    args = parser.parse_args()
    for path in generate(Path(args.out)):
        print(f"wrote {path} ({path.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

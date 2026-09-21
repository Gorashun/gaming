#!/usr/bin/env python3
"""Generate the composable 32x32 dice sprites for PIPWRECK.

Research 04 section 3: a die is never a finished picture. It is
    body (material) + pip/glyph overlay + optional crack overlay
which turns ~90 sprites into ~20 files and makes a new forgeable face in M2
cost exactly one glyph.

What this writes to assets/sprites/dice/:
    die_body_gray.png        grayscale master, feed through palette_lut.gdshader
    die_body_{iron,bone,glass}.png   pre-tinted bodies (mockups, editor preview)
    die_tumble_gray.png      6 frame roll animation of an EMPTY body
    lut_{iron,bone,glass}.png        16x1 palette LUTs for palette_lut.gdshader
    lut_world.png            LUT that forces any imported sprite to the palette
    glass_highlight.png      additive rim, glass material only
    pips_0..pips_6.png       pip overlays, value 0 is the hollow ring
    glyph_{gift,eld,frost,blod,tomrum}.png   symbol faces, 1-bit, modulate them
    crack_1..crack_3.png     crack overlays

Run: python3 tools/gen_dice_sprites.py     (from rogelike_app/)
"""

from __future__ import annotations

import argparse
import math
from pathlib import Path

from pixel_png import Canvas, color, write_png

OUT = Path("assets/sprites/dice")
SIZE = 32
RADIUS = 7  # UI_GUIDE 2.7 radius/die: about 22 percent of the die size


# --- Body ------------------------------------------------------------------


def _rounded_mask(size: int, radius: int, inset: int = 1) -> list[list[bool]]:
    mask = [[False] * size for _ in range(size)]
    lo, hi = inset, size - 1 - inset
    for y in range(size):
        for x in range(size):
            if x < lo or x > hi or y < lo or y > hi:
                continue
            cx = min(max(x, lo + radius), hi - radius)
            cy = min(max(y, lo + radius), hi - radius)
            if (x - cx) ** 2 + (y - cy) ** 2 <= radius * radius:
                mask[y][x] = True
    return mask


def die_body(ramp: tuple[str, str, str, str]) -> Canvas:
    """Rounded cube face. ramp = (shadow, base, lit, rim). Light: upper left."""
    cv = Canvas(SIZE, SIZE)
    mask = _rounded_mask(SIZE, RADIUS)

    def inside(x: int, y: int) -> bool:
        return 0 <= x < SIZE and 0 <= y < SIZE and mask[y][x]

    # depth = how many pixels in from the silhouette. A 2 px bevel plus a flat
    # face reads as a cube at x5 without the diagonal banding a gradient gives.
    depth = [[0] * SIZE for _ in range(SIZE)]
    for y in range(SIZE):
        for x in range(SIZE):
            if not mask[y][x]:
                continue
            d = 0
            while d < 6 and all(
                inside(x + dx, y + dy)
                for dx, dy in ((d + 1, 0), (-(d + 1), 0), (0, d + 1), (0, -(d + 1)))
            ):
                d += 1
            depth[y][x] = d

    for y in range(SIZE):
        for x in range(SIZE):
            if not mask[y][x]:
                continue
            upper_left = (x + y) < SIZE - 1
            d = depth[y][x]
            if d == 0:
                token = ramp[3] if upper_left else ramp[0]
            elif d <= 2:
                token = ramp[2] if upper_left else ramp[0]
            else:
                token = ramp[1]
            cv.set(x, y, color(token))
    return cv.outline(color("out"))


GRAY_RAMP = ("#3A3A3A", "#7A7A7A", "#B4B4B4", "#E6E6E6")
MATERIALS: dict[str, tuple[str, str, str, str]] = {
    # order: shadow, base, lit, rim
    "iron": ("iron2", "iron3", "iron4", "iron5"),
    "bone": ("bone2", "bone3", "bone4", "bone5"),
    "glass": ("glass2", "glass3", "glass4", "glass5"),
}


def tumble_sheet() -> Canvas:
    """6 frames of an empty body: squash, tilt, squash. Glyph is popped in on
    the landing frame by the UI layer, never animated (research 04 section 3)."""
    frames: list[Canvas] = []
    squash = ((0, 0), (2, -2), (4, -4), (2, -3), (-2, 2), (0, 0))
    for sx, sy in squash:
        body = die_body(GRAY_RAMP)
        frame = Canvas(SIZE, SIZE)
        w = SIZE - sx * 2
        h = SIZE - sy * 2
        for y in range(h):
            for x in range(w):
                src_x = int(x * SIZE / w)
                src_y = int(y * SIZE / h)
                frame.set(x + sx, y + sy, body.get(src_x, src_y))
        frames.append(frame)
    out = Canvas(SIZE * len(frames), SIZE)
    for i, frame in enumerate(frames):
        out.blit(frame, i * SIZE, 0)
    return out


# --- LUTs ------------------------------------------------------------------

LUT_WIDTH = 16


def lut(stops: list[tuple[float, str]]) -> Canvas:
    """16x1 lookup texture. palette_lut.gdshader samples it at u = luminance."""
    cv = Canvas(LUT_WIDTH, 1)
    for i in range(LUT_WIDTH):
        t = i / (LUT_WIDTH - 1)
        chosen = stops[0][1]
        for stop_t, token in stops:
            if t >= stop_t:
                chosen = token
        cv.set(i, 0, color(chosen))
    return cv


MATERIAL_LUTS: dict[str, list[tuple[float, str]]] = {
    "iron": [(0.0, "iron1"), (0.2, "iron2"), (0.45, "iron3"), (0.72, "iron4"), (0.9, "iron5")],
    "bone": [(0.0, "bone1"), (0.2, "bone2"), (0.45, "bone3"), (0.72, "bone4"), (0.9, "bone5")],
    "glass": [(0.0, "glass1"), (0.2, "glass2"), (0.45, "glass3"), (0.72, "glass4"), (0.9, "glass5")],
}

# The world LUT is what every imported third party sprite is forced through so
# three CC0 sources cannot drift apart (research 04, recommendation 5).
WORLD_LUT: list[tuple[float, str]] = [
    (0.0, "out"),
    (0.09, "pit"),
    (0.18, "slate"),
    (0.27, "raised"),
    (0.36, "line"),
    (0.45, "iron3"),
    (0.56, "void2"),
    (0.66, "iron4"),
    (0.76, "chalk500"),
    (0.85, "chalk300"),
    (0.94, "chalk100"),
]


# --- Pip overlays ----------------------------------------------------------

PIP_COLS = (9, 16, 23)
PIP_ROWS = (9, 16, 23)
PIP_LAYOUT: dict[int, tuple[tuple[int, int], ...]] = {
    1: ((1, 1),),
    2: ((0, 0), (2, 2)),
    3: ((0, 0), (1, 1), (2, 2)),
    4: ((0, 0), (2, 0), (0, 2), (2, 2)),
    5: ((0, 0), (2, 0), (1, 1), (0, 2), (2, 2)),
    6: ((0, 0), (2, 0), (0, 1), (2, 1), (0, 2), (2, 2)),
}


def _disc(cv: Canvas, cx: int, cy: int, r: float, token: str) -> None:
    for y in range(int(cy - r) - 1, int(cy + r) + 2):
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                cv.set(x, y, color(token))


def pips(value: int) -> Canvas:
    """Pip overlay. Value 0 is a hollow ring - HOLLOW and TWIN_EYE are real
    faces, so 'no pips' must look deliberate rather than like a missing file."""
    cv = Canvas(SIZE, SIZE)
    if value == 0:
        _disc(cv, 16, 16, 5.4, "pip")
        for y in range(SIZE):
            for x in range(SIZE):
                if (x - 16) ** 2 + (y - 16) ** 2 <= 3.2 * 3.2:
                    cv.set(x, y, (0, 0, 0, 0))
        return cv
    for col, row in PIP_LAYOUT[value]:
        cx, cy = PIP_COLS[col], PIP_ROWS[row]
        _disc(cv, cx, cy, 2.6, "pip")
        # drilled look: one lit pixel at the lower right of each pip
        cv.set(cx + 1, cy + 1, color("chalk500"))
    return cv


# --- Glyph overlays --------------------------------------------------------
# 1-bit white shapes. The UI layer sets modulate to the semantic token
# (UI_GUIDE 2.3), so a colour blind player still gets the shape code.

GLYPH_TOKEN = "chalk100"


def glyph_gift() -> Canvas:
    """Gift / poison: the droplet from UI_GUIDE 2.3."""
    cv = Canvas(SIZE, SIZE)
    # round bottom
    for y in range(SIZE):
        for x in range(SIZE):
            if (x - 16) ** 2 + (y - 19) ** 2 <= 7 * 7:
                cv.set(x, y, color(GLYPH_TOKEN))
    # tapered point up to y=5
    for y in range(5, 20):
        t = (y - 5) / 15.0
        half = max(0, int(round(t * t * 7)))
        for x in range(16 - half, 16 + half + 1):
            cv.set(x, y, color(GLYPH_TOKEN))
    return cv


def glyph_eld() -> Canvas:
    """Eld / fire: the triangle."""
    cv = Canvas(SIZE, SIZE)
    for i in range(18):
        half = i
        for x in range(16 - half, 16 + half + 1):
            cv.set(x, 7 + i, color(GLYPH_TOKEN))
    return cv


def glyph_frost() -> Canvas:
    """Frost: the rhombus."""
    cv = Canvas(SIZE, SIZE)
    for i in range(11):
        for x in range(16 - i, 16 + i + 1):
            cv.set(x, 5 + i, color(GLYPH_TOKEN))
            cv.set(x, 27 - i, color(GLYPH_TOKEN))
    return cv


def glyph_blod() -> Canvas:
    """Blod / lifesteal: the half circle, flat edge left."""
    cv = Canvas(SIZE, SIZE)
    for y in range(SIZE):
        for x in range(SIZE):
            if x >= 13 and (x - 13) ** 2 + (y - 16) ** 2 <= 11 * 11:
                cv.set(x, y, color(GLYPH_TOKEN))
    for y in range(5, 28):
        cv.set(12, y, color(GLYPH_TOKEN))
        cv.set(11, y, color(GLYPH_TOKEN))
    return cv


def glyph_tomrum() -> Canvas:
    """Tomrum / void: the crossed square."""
    cv = Canvas(SIZE, SIZE)
    cv.rect(6, 6, 20, 3, color(GLYPH_TOKEN))
    cv.rect(6, 23, 20, 3, color(GLYPH_TOKEN))
    cv.rect(6, 6, 3, 20, color(GLYPH_TOKEN))
    cv.rect(23, 6, 3, 20, color(GLYPH_TOKEN))
    for i in range(17):
        cv.rect(7 + i, 7 + i, 2, 2, color(GLYPH_TOKEN))
        cv.rect(24 - i, 7 + i, 2, 2, color(GLYPH_TOKEN))
    return cv


GLYPHS = {
    "gift": glyph_gift,
    "eld": glyph_eld,
    "frost": glyph_frost,
    "blod": glyph_blod,
    "tomrum": glyph_tomrum,
}


# --- Crack overlays --------------------------------------------------------


def crack(variant: int) -> Canvas:
    """One of three fracture patterns. Drawn as a dark fissure with a lit lip
    on the upper left, so it reads as depth on every material."""
    cv = Canvas(SIZE, SIZE)
    seeds = {
        1: [(6, 4), (12, 11), (14, 18), (20, 24), (25, 29)],
        2: [(27, 5), (21, 12), (19, 17), (11, 22), (5, 27)],
        3: [(4, 15), (11, 14), (16, 17), (23, 13), (28, 16)],
    }[variant]
    branches = {
        1: [((12, 11), (5, 14)), ((20, 24), (26, 20))],
        2: [((19, 17), (27, 19)), ((11, 22), (8, 15))],
        3: [((16, 17), (15, 26)), ((16, 17), (18, 6))],
    }[variant]

    def stroke(a: tuple[int, int], b: tuple[int, int]) -> None:
        steps = max(abs(b[0] - a[0]), abs(b[1] - a[1]), 1)
        for i in range(steps + 1):
            x = a[0] + (b[0] - a[0]) * i // steps
            y = a[1] + (b[1] - a[1]) * i // steps
            jitter = int(math.sin(i * 1.7 + variant) * 1.2)
            cv.set(x + jitter, y, color("out"))
            cv.set(x + jitter - 1, y - 1, color("chalk500", 150))

    for i in range(len(seeds) - 1):
        stroke(seeds[i], seeds[i + 1])
    for a, b in branches:
        stroke(a, b)
    return cv


def glass_highlight() -> Canvas:
    """Additive rim for the glass material only."""
    cv = Canvas(SIZE, SIZE)
    mask = _rounded_mask(SIZE, RADIUS)
    for y in range(SIZE):
        for x in range(SIZE):
            if not mask[y][x]:
                continue
            edge = (
                (not mask[y - 1][x] if y else True)
                or (not mask[y][x - 1] if x else True)
            )
            if edge:
                cv.set(x, y, color("glass5", 210))
    # inner specular streak
    for i in range(7):
        cv.set(8 + i, 8 + i // 2, color("chalk100", 120))
        cv.set(9 + i, 8 + i // 2, color("chalk100", 60))
    return cv


# --- Main ------------------------------------------------------------------


def generate(root: Path) -> list[tuple[str, str]]:
    made: list[tuple[str, str]] = []

    def emit(name: str, canvas: Canvas, note: str) -> None:
        path = OUT / name
        write_png(root / path, canvas)
        made.append((path.as_posix(), note))

    emit("die_body_gray.png", die_body(GRAY_RAMP), "Tarningskropp graskala 32x32; kors genom palette_lut.gdshader")
    for material, ramp in MATERIALS.items():
        emit(
            f"die_body_{material}.png",
            die_body(ramp),
            f"Tarningskropp {material} 32x32 (fortintad; mockup och editorforhandsvisning)",
        )
    emit("die_tumble_gray.png", tumble_sheet(), "Rullanimation tom kropp 6 frames 192x32 graskala")

    for material, stops in MATERIAL_LUTS.items():
        emit(f"lut_{material}.png", lut(stops), f"Palett-LUT 16x1 for material {material}")
    emit("lut_world.png", lut(WORLD_LUT), "Palett-LUT 16x1 som tvingar importerade sprites till UI_GUIDE-paletten")

    emit("glass_highlight.png", glass_highlight(), "Additiv glaskant, endast glasmaterial")

    for value in range(7):
        note = "Pip-overlay varde 0 (ihalig ring, HOLLOW/TWIN_EYE)" if value == 0 else f"Pip-overlay varde {value}"
        emit(f"pips_{value}.png", pips(value), note)

    for name, fn in GLYPHS.items():
        emit(f"glyph_{name}.png", fn(), f"Symbolsida {name}, 1-bit, satt modulate till semantisk token")

    for variant in (1, 2, 3):
        emit(f"crack_{variant}.png", crack(variant), f"Sprickoverlay variant {variant}")

    return made


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".")
    args = parser.parse_args()
    made = generate(Path(args.root).resolve())
    for path, note in made:
        print(f"wrote {path}  ({note})")
    print(f"{len(made)} dice files (naive cost would be ~90 sprites)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

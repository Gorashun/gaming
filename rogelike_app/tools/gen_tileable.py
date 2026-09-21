#!/usr/bin/env python3
"""Corridor textures: verify the tileable ones, generate the ones that are missing.

The corridor's stone (wall/floor/ceiling), the boss door and the torch are
authored by the UI agent in tools/gen_pixel_assets.py and this script does not
touch them. What it does is:

1. **Verify** that every tile the 3D corridor kaklar (wall, floor, ceiling) is
   seamless. A 3D corridor repeats a 64x64 tile twice per 3 m tile and a visible
   seam every 1.5 m is the single most obvious artefact in the genre, so the
   check runs in CI-like conditions rather than by eye.
2. **Generate** the textures the 3D view needs and the 2D game never did.
   Right now that is one file: the junction sign plate.

Usage:
    python3 tools/gen_tileable.py            # verify + write missing files
    python3 tools/gen_tileable.py --check    # verify only, non-zero on a seam

The seam metric is the mean absolute RGB difference between the tile's last
column and its first column (and last/first row). A perfectly tileable tile
scores exactly like any other neighbouring column pair inside the tile, so the
threshold is relative: the seam may not be worse than 1.6x the tile's own mean
column-to-column difference.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from pixel_png import Canvas, color, write_png  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
CORRIDOR = ROOT / "assets" / "sprites" / "env" / "corridor"

# Tiles the ArrayMesh repeats. door_boss and torch are single quads and are
# deliberately NOT in this list: they are not supposed to tile.
TILEABLE = ["wall_stone.png", "floor_stone.png", "ceiling_stone.png"]
SEAM_TOLERANCE = 1.6


# --- Seam check ------------------------------------------------------------

def _read_png(path: Path) -> tuple[int, int, list[list[tuple[int, int, int, int]]]]:
    """Decode an 8 bit PNG. Only the sub-set our own writer emits, plus the
    palette form Godot's importer never sees. No Pillow in this environment."""
    import struct
    import zlib

    data = path.read_bytes()
    pos, width, height, depth, ctype = 8, 0, 0, 0, 0
    idat = b""
    palette = None
    trns = None
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        tag = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if tag == b"IHDR":
            width, height, depth, ctype = struct.unpack(">IIBB", chunk[:10])
        elif tag == b"PLTE":
            palette = chunk
        elif tag == b"tRNS":
            trns = chunk
        elif tag == b"IDAT":
            idat += chunk
    if depth != 8:
        raise ValueError(f"{path}: only 8 bit PNGs are supported")
    raw = zlib.decompress(idat)
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ctype]
    stride = width * channels
    rows: list[bytearray] = []
    previous = bytearray(stride)
    index = 0
    for _ in range(height):
        filt = raw[index]
        index += 1
        line = bytearray(raw[index:index + stride])
        index += stride
        for x in range(stride):
            a = line[x - channels] if x >= channels else 0
            b = previous[x]
            c = previous[x - channels] if x >= channels else 0
            if filt == 1:
                line[x] = (line[x] + a) & 255
            elif filt == 2:
                line[x] = (line[x] + b) & 255
            elif filt == 3:
                line[x] = (line[x] + (a + b) // 2) & 255
            elif filt == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[x] = (line[x] + pred) & 255
        previous = line
        rows.append(line)
    pixels = []
    for y in range(height):
        row = []
        line = rows[y]
        for x in range(width):
            o = x * channels
            if ctype == 6:
                row.append((line[o], line[o + 1], line[o + 2], line[o + 3]))
            elif ctype == 2:
                row.append((line[o], line[o + 1], line[o + 2], 255))
            elif ctype == 3:
                i = line[o]
                alpha = trns[i] if trns is not None and i < len(trns) else 255
                row.append((palette[i * 3], palette[i * 3 + 1], palette[i * 3 + 2], alpha))
            elif ctype == 0:
                row.append((line[o], line[o], line[o], 255))
            else:
                row.append((line[o], line[o], line[o], line[o + 1]))
        pixels.append(row)
    return width, height, pixels


def _mean_diff(a: list[tuple[int, int, int, int]], b: list[tuple[int, int, int, int]]) -> float:
    total = 0.0
    for pa, pb in zip(a, b):
        total += abs(pa[0] - pb[0]) + abs(pa[1] - pb[1]) + abs(pa[2] - pb[2])
    return total / (len(a) * 3.0)


def check_tile(path: Path) -> tuple[bool, str]:
    width, height, px = _read_png(path)
    columns = [[px[y][x] for y in range(height)] for x in range(width)]
    inner_cols = sum(_mean_diff(columns[x], columns[x + 1]) for x in range(width - 1)) / (width - 1)
    seam_x = _mean_diff(columns[width - 1], columns[0])
    inner_rows = sum(_mean_diff(px[y], px[y + 1]) for y in range(height - 1)) / (height - 1)
    seam_y = _mean_diff(px[height - 1], px[0])
    budget_x = max(inner_cols * SEAM_TOLERANCE, 1.0)
    budget_y = max(inner_rows * SEAM_TOLERANCE, 1.0)
    ok = seam_x <= budget_x and seam_y <= budget_y
    return ok, (
        f"{path.name}: seam x {seam_x:.2f} (budget {budget_x:.2f}), "
        f"y {seam_y:.2f} (budget {budget_y:.2f}) -> {'ok' if ok else 'SEAM'}"
    )


# --- Generation ------------------------------------------------------------

def sign_plate() -> Canvas:
    """The plate a junction sign hangs on, 64x64, drawn as a Sprite3D quad.

    UI_GUIDE section 8: the object is pixels, the word on it is chalk. The plate
    is therefore a slab of the same stone ramp as the wall with a hand-drawn
    chalk rim; the 16 px node icon is a separate quad on top of it, so one plate
    serves all seven sign keys.
    """
    c = Canvas(64, 64, color("pit", 0))
    slab = color("iron2")
    edge = color("iron1")
    chalk = color("chalk300")
    faint = color("chalk500", 150)

    # Slab with a 2 px dark edge, corners knocked off so it reads as hung, not
    # painted on.
    c.rect(3, 3, 58, 58, edge)
    c.rect(5, 5, 54, 54, slab)
    for x, y in ((3, 3), (4, 3), (3, 4), (60, 3), (59, 3), (60, 4),
                 (3, 60), (4, 60), (3, 59), (60, 60), (59, 60), (60, 59)):
        c.set(x, y, color("pit", 0))

    # Chalk rim. The jitter is authored, not random: a straight rim looks
    # printed and the whole game's grammar says chalk is hand made.
    jitter = [0, 1, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0]
    for i in range(8, 56):
        j = jitter[i % len(jitter)]
        c.set(i, 7 + j, chalk)
        c.set(i, 56 - j, chalk)
        c.set(7 + j, i, chalk)
        c.set(56 - j, i, chalk)
    for x, y in ((8, 8), (55, 8), (8, 55), (55, 55)):
        c.set(x, y, faint)
    return c


GENERATED = {"sign_plate.png": sign_plate}


def generate(out_dir: Path) -> list[Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    written = []
    for name, builder in GENERATED.items():
        written.append(write_png(out_dir / name, builder()))
    return written


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="verify seams only")
    parser.add_argument("--out", default=str(CORRIDOR))
    args = parser.parse_args()

    failed = False
    for name in TILEABLE:
        path = CORRIDOR / name
        if not path.exists():
            print(f"MISSING {path}")
            failed = True
            continue
        ok, message = check_tile(path)
        print(message)
        failed = failed or not ok
    if not args.check:
        for path in generate(Path(args.out)):
            print(f"wrote {path.relative_to(ROOT)}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())

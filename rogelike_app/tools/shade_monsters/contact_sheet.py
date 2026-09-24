#!/usr/bin/env python3
"""Contact sheet for battler PNGs: every figure on a dark corridor-like tile.

Row 1: each figure large (fitted in a 256 px cell) with its id.
Row 2: the same figures at 60 px height, the size they have to read at in
the corridor (docs/design/CORRIDOR_DESIGN.md section 3.1), on the near-black
wall value #07090B from ART_DIRECTION_V2 section 4.

Usage (from rogelike_app/):
    python3 tools/shade_monsters/contact_sheet.py                      # shades, raw renders
    python3 tools/shade_monsters/contact_sheet.py --dir assets/art/enemy --extra assets/art/boss/SLAGJAW.png
    python3 tools/shade_monsters/contact_sheet.py --out docs/screenshots/m7_shades/contact_sheet.png
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ORDER = ("RUST_RAT", "SLAG_MOTH", "THORN_IMP", "PIP_THIEF", "IRON_TICK",
         "GRAVE_HAND", "CHALK_DUMMY", "placeholder", "SLAGJAW")
CELL = 256
SMALL_H = 60
WALL = (7, 9, 11)
FLOOR = (22, 20, 19)
LABEL = (232, 224, 207)


def trimmed(path: Path) -> Image.Image:
    img = Image.open(path).convert("RGBA")
    box = img.split()[3].point(lambda a: 255 if a > 8 else 0).getbbox()
    return img.crop(box) if box else img


def fit(img: Image.Image, w: int, h: int) -> Image.Image:
    s = min(w / img.width, h / img.height)
    return img.resize((max(1, round(img.width * s)), max(1, round(img.height * s))), Image.Resampling.LANCZOS)


def backdrop(w: int, h: int) -> Image.Image:
    """Near-black wall fading into a slightly warmer floor at the bottom."""
    bg = Image.new("RGB", (w, h), WALL)
    draw = ImageDraw.Draw(bg)
    floor_y = int(h * 0.78)
    for y in range(floor_y, h):
        t = (y - floor_y) / max(1, h - floor_y)
        c = tuple(int(WALL[i] + (FLOOR[i] - WALL[i]) * t) for i in range(3))
        draw.line([(0, y), (w, y)], fill=c)
    return bg


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dir", default="assets/incoming/game-icons-shades")
    parser.add_argument("--extra", action="append", default=[], help="extra PNG(s) to append")
    parser.add_argument("--out", default="docs/screenshots/m7_shades/contact_sheet.png")
    args = parser.parse_args(argv)

    src = Path(args.dir)
    paths = [src / f"{name}.png" for name in ORDER if (src / f"{name}.png").is_file()]
    paths += [Path(p) for p in args.extra]
    if not paths:
        sys.stderr.write(f"no PNGs found in {src}\n")
        return 1

    cols = len(paths)
    width = cols * CELL
    height = CELL + 28 + SMALL_H + 40
    sheet = Image.new("RGB", (width, height), WALL)
    font = ImageFont.load_default()
    draw = ImageDraw.Draw(sheet)
    for i, path in enumerate(paths):
        img = trimmed(path)
        tile = backdrop(CELL, CELL).convert("RGBA")
        big = fit(img, CELL - 24, CELL - 24)
        tile.alpha_composite(big, ((CELL - big.width) // 2, CELL - 12 - big.height))
        sheet.paste(tile.convert("RGB"), (i * CELL, 0))
        draw.text((i * CELL + 8, CELL + 8), path.stem, fill=LABEL, font=font)
        small = fit(img, CELL - 8, SMALL_H)
        strip = backdrop(CELL, SMALL_H + 20).convert("RGBA")
        strip.alpha_composite(small, ((CELL - small.width) // 2, SMALL_H + 20 - 6 - small.height))
        sheet.paste(strip.convert("RGB"), (i * CELL, CELL + 28))
    draw.text((8, height - 14), f"top: fitted {CELL - 24} px   bottom: {SMALL_H} px high (corridor read size)",
              fill=LABEL, font=font)
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out, "PNG", optimize=True)
    print(f"{len(paths)} figure(s) -> {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

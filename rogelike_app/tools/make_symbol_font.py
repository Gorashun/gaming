#!/usr/bin/env python3
"""Build assets/fonts/pipwreck_symbols.ttf from Noto Sans Symbols 2.

Why a derived font at all
-------------------------
Familjen Grotesk (UI_GUIDE 2.8) has 619 glyphs. The shape codes the design
leans on - the poison drop, the frost lozenge, the shield pentagon, the rarity
marks, the slot icons in 2.3-2.5 - are not among them. Before 2026-09-22 Godot
borrowed them from the *system* font, which works on Linux and Android and
produces tofu in the web export (docs/BACKLOG.md). Noto Sans Symbols 2 (OFL)
has every one of them, so it is bundled as an explicit fallback.

Why it cannot be used unmodified
--------------------------------
Godot sizes a Label from `Font.get_height()`, which is the *maximum* over the
whole fallback chain. Noto Sans Symbols 2 declares a 1.70 em line box where
Familjen Grotesk declares 1.25 em. Dropping it in unmodified made every label
in the game 36 percent taller and pushed the combat screen 127 px past the
thumb zone (tests/test_corridor_flow.gd). This script rewrites the vertical
metrics - and only those - so the fallback follows the text font's line box.
No outline, no cmap and no glyph name is touched.

The OFL permits modification; Noto Sans Symbols 2 declares no Reserved Font
Name. The result is still OFL-1.1 and ships with the upstream OFL.txt. It is
renamed so that nobody mistakes a metric-patched file for stock Noto.

Run (from rogelike_app/):
    curl -L -o /tmp/NotoSansSymbols2-Regular.ttf \\
      https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssymbols2/NotoSansSymbols2-Regular.ttf
    python3 tools/make_symbol_font.py --input /tmp/NotoSansSymbols2-Regular.ttf
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from fontTools.ttLib import TTFont

OUT = Path("assets/fonts/pipwreck_symbols.ttf")
METRICS_FROM = Path("assets/fonts/familjen_grotesk_variable.ttf")
FAMILY = "PIPWRECK Symbols"
# name table IDs that carry the family / full / postscript name.
NAME_IDS = {1: FAMILY, 3: f"{FAMILY} Regular", 4: f"{FAMILY} Regular", 6: "PIPWRECKSymbols-Regular", 16: FAMILY}

# The code points the game actually draws through the fallback. Kept as a
# checklist, not as a subset filter: the file ships whole so a new shape code in
# UI_GUIDE does not need a new build step.
REQUIRED = "⬬❖⬣⬤⬚⬟✦✚▭◣▤◉◖⛊➤⮡⭮✕"


def line_ratio(font: TTFont) -> tuple[float, float]:
    upm = font["head"].unitsPerEm
    hhea = font["hhea"]
    return hhea.ascender / upm, hhea.descender / upm


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, help="upstream NotoSansSymbols2-Regular.ttf")
    parser.add_argument("--root", default=".")
    args = parser.parse_args()
    root = Path(args.root).resolve()

    source = TTFont(args.input)
    target = TTFont(root / METRICS_FROM)
    asc_ratio, desc_ratio = line_ratio(target)

    missing = [c for c in REQUIRED if ord(c) not in source.getBestCmap()]
    if missing:
        print(f"error: upstream font lacks {''.join(missing)}", file=sys.stderr)
        return 1

    upm = source["head"].unitsPerEm
    ascender = round(asc_ratio * upm)
    descender = round(desc_ratio * upm)

    before = line_ratio(source)
    source["hhea"].ascender = ascender
    source["hhea"].descender = descender
    source["hhea"].lineGap = 0
    os2 = source["OS/2"]
    os2.sTypoAscender = ascender
    os2.sTypoDescender = descender
    os2.sTypoLineGap = 0
    os2.usWinAscent = ascender
    os2.usWinDescent = -descender

    for record in source["name"].names:
        if record.nameID in NAME_IDS:
            record.string = NAME_IDS[record.nameID]

    out = root / OUT
    out.parent.mkdir(parents=True, exist_ok=True)
    source.save(out)
    after = line_ratio(TTFont(out))
    print(f"wrote {OUT}  ({out.stat().st_size} bytes)")
    print(f"line box {before[0] - before[1]:.3f} em -> {after[0] - after[1]:.3f} em "
          f"(Familjen Grotesk: {asc_ratio - desc_ratio:.3f} em)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Minimal dependency-free PNG writer plus a tiny pixel-art canvas.

No Pillow in this environment, so PNG chunks are assembled by hand with
struct + zlib. 8 bit RGBA, filter type 0 on every scanline: the files are a
few hundred bytes each and stay byte-identical between runs, which matters
because the generators are re-run in CI-like conditions.

Art is authored as ASCII grids (one character per pixel) with a palette that
maps a character to a token from docs/UI_GUIDE.md section 2. That keeps the
sprites hand-authored and reviewable in a diff.
"""

from __future__ import annotations

import struct
import zlib
from pathlib import Path

RGBA = tuple[int, int, int, int]

# --- Palette ---------------------------------------------------------------
# Base tokens come straight from docs/UI_GUIDE.md section 2. The ramps are the
# world-layer extension: every ramp is 4-5 steps and every step is chosen so a
# palette-LUT swap between materials keeps the same luminance staircase.

PALETTE: dict[str, str] = {
    # UI_GUIDE 2.1 surfaces
    "pit": "#0E1216",
    "slate": "#161B21",
    "raised": "#1F262E",
    "line": "#2C353F",
    # UI_GUIDE 2.2 chalk and bone
    "chalk100": "#F2EDE3",
    "chalk300": "#CFC7B8",
    "chalk500": "#9A9486",
    "bone": "#E8E0CF",
    "pip": "#12161A",
    # UI_GUIDE 2.3 semantics
    "fire": "#FF6A2C",
    "poison": "#B77FFF",
    "frost": "#6ED2F5",
    "heal": "#4FE3A0",
    "blood": "#FF556F",
    "charge": "#FFD447",
    "shield": "#D7DEE6",
    # world ramps: iron
    "iron1": "#12161A",
    "iron2": "#2C353F",
    "iron3": "#4A5663",
    "iron4": "#7A8896",
    "iron5": "#B8C4CE",
    # world ramps: bone / ivory
    "bone1": "#3A3327",
    "bone2": "#6B5F4A",
    "bone3": "#A2937A",
    "bone4": "#CFC3A8",
    "bone5": "#E8E0CF",
    # world ramps: glass
    "glass1": "#12262E",
    "glass2": "#24515F",
    "glass3": "#3E8DA3",
    "glass4": "#6ED2F5",
    "glass5": "#C9F0FC",
    # world ramps: rust / fire
    "rust1": "#4A1A0A",
    "rust2": "#7A2A10",
    "rust3": "#C2451D",
    "rust4": "#FF6A2C",
    "rust5": "#FFB067",
    # world ramps: skin
    "skin1": "#4A2A22",
    "skin2": "#8A4A38",
    "skin3": "#C07A5C",
    "skin4": "#E0A884",
    # world ramps: leather
    "leat1": "#2A1C16",
    "leat2": "#4E3324",
    "leat3": "#7A5236",
    "leat4": "#A87A4E",
    # world ramps: poison
    "pois1": "#2A1244",
    "pois2": "#3A1E5C",
    "pois3": "#6A3AA0",
    "pois4": "#B77FFF",
    "pois5": "#DCC0FF",
    # world ramps: blood
    "blod1": "#3A0A16",
    "blod2": "#5C1020",
    "blod3": "#A02038",
    "blod4": "#FF556F",
    "blod5": "#FFA0B0",
    # world ramps: moss / heal
    "moss1": "#0C2A22",
    "moss2": "#10453A",
    "moss3": "#1E8A6A",
    "moss4": "#4FE3A0",
    # world ramps: charge
    "chrg1": "#4A3A08",
    "chrg2": "#6A5510",
    "chrg3": "#C2A018",
    "chrg4": "#FFD447",
    # outline / void
    "out": "#080A0D",
    "void1": "#3A404C",
    "void2": "#5A6270",
    "void3": "#8A94A6",
}


def hex_to_rgba(value: str, alpha: int = 255) -> RGBA:
    value = value.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), alpha)


def color(token: str, alpha: int = 255) -> RGBA:
    """Resolve a palette token, a #rrggbb string or a token@alpha string."""
    if "@" in token:
        token, _, raw_alpha = token.partition("@")
        alpha = int(round(float(raw_alpha) * 255)) if "." in raw_alpha else int(raw_alpha)
    if token.startswith("#"):
        return hex_to_rgba(token, alpha)
    return hex_to_rgba(PALETTE[token], alpha)


TRANSPARENT: RGBA = (0, 0, 0, 0)


# --- Canvas ----------------------------------------------------------------


class Canvas:
    """Mutable RGBA pixel buffer with alpha-over blitting."""

    def __init__(self, width: int, height: int, fill: RGBA = TRANSPARENT) -> None:
        self.width = width
        self.height = height
        self.px: list[list[RGBA]] = [[fill for _ in range(width)] for _ in range(height)]

    def set(self, x: int, y: int, rgba: RGBA) -> None:
        if 0 <= x < self.width and 0 <= y < self.height:
            self.px[y][x] = rgba

    def get(self, x: int, y: int) -> RGBA:
        if 0 <= x < self.width and 0 <= y < self.height:
            return self.px[y][x]
        return TRANSPARENT

    def over(self, x: int, y: int, rgba: RGBA) -> None:
        """Source-over composite of one pixel."""
        if rgba[3] == 0:
            return
        if rgba[3] == 255:
            self.set(x, y, rgba)
            return
        dst = self.get(x, y)
        sa = rgba[3] / 255.0
        da = dst[3] / 255.0
        out_a = sa + da * (1.0 - sa)
        if out_a <= 0.0:
            self.set(x, y, TRANSPARENT)
            return
        out = tuple(
            int(round((rgba[i] * sa + dst[i] * da * (1.0 - sa)) / out_a)) for i in range(3)
        )
        self.set(x, y, (out[0], out[1], out[2], int(round(out_a * 255))))

    def rect(self, x: int, y: int, w: int, h: int, rgba: RGBA) -> None:
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.over(xx, yy, rgba)

    def hline(self, x: int, y: int, w: int, rgba: RGBA) -> None:
        self.rect(x, y, w, 1, rgba)

    def vline(self, x: int, y: int, h: int, rgba: RGBA) -> None:
        self.rect(x, y, 1, h, rgba)

    def blit(self, src: "Canvas", x: int, y: int) -> None:
        for sy in range(src.height):
            for sx in range(src.width):
                self.over(x + sx, y + sy, src.px[sy][sx])

    def sub(self, x: int, y: int, w: int, h: int) -> "Canvas":
        out = Canvas(w, h)
        for yy in range(h):
            for xx in range(w):
                out.px[yy][xx] = self.get(x + xx, y + yy)
        return out

    def flip_x(self) -> "Canvas":
        out = Canvas(self.width, self.height)
        for y in range(self.height):
            out.px[y] = list(reversed(self.px[y]))
        return out

    def tint(self, rgba: RGBA) -> "Canvas":
        """Replace RGB of every non-transparent pixel, keep alpha."""
        out = Canvas(self.width, self.height)
        for y in range(self.height):
            for x in range(self.width):
                a = self.px[y][x][3]
                out.px[y][x] = (rgba[0], rgba[1], rgba[2], a) if a else TRANSPARENT
        return out

    def outline(self, rgba: RGBA) -> "Canvas":
        """Add a 1 px outline around every opaque cluster (behind the art)."""
        out = Canvas(self.width, self.height)
        for y in range(self.height):
            for x in range(self.width):
                if self.px[y][x][3] != 0:
                    continue
                touching = any(
                    self.get(x + dx, y + dy)[3] != 0
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                )
                if touching:
                    out.px[y][x] = rgba
        out.blit(self, 0, 0)
        return out

    def rows_bytes(self) -> bytes:
        parts = bytearray()
        for row in self.px:
            parts.append(0)  # filter type 0
            for r, g, b, a in row:
                parts += bytes((r, g, b, a))
        return bytes(parts)


def from_ascii(grid: list[str], key: dict[str, str]) -> Canvas:
    """Build a canvas from an ASCII grid. '.' and ' ' are transparent."""
    height = len(grid)
    width = max((len(r) for r in grid), default=0)
    canvas = Canvas(width, height)
    for y, row in enumerate(grid):
        for x, ch in enumerate(row):
            if ch in (".", " "):
                continue
            token = key.get(ch)
            if token is None:
                raise KeyError(f"ASCII char {ch!r} at ({x},{y}) is not in the key")
            canvas.px[y][x] = color(token)
    return canvas


# --- PNG -------------------------------------------------------------------


def _chunk(tag: bytes, payload: bytes) -> bytes:
    return (
        struct.pack(">I", len(payload))
        + tag
        + payload
        + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)
    )


def write_png(path: str | Path, canvas: Canvas) -> Path:
    out = Path(path)
    out.parent.mkdir(parents=True, exist_ok=True)
    header = struct.pack(">IIBBBBB", canvas.width, canvas.height, 8, 6, 0, 0, 0)
    data = zlib.compress(canvas.rows_bytes(), 9)
    png = b"\x89PNG\r\n\x1a\n" + _chunk(b"IHDR", header) + _chunk(b"IDAT", data) + _chunk(b"IEND", b"")
    out.write_bytes(png)
    return out

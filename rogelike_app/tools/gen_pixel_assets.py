#!/usr/bin/env python3
"""Generate the M1 world-layer pixel sprites for PIPWRECK.

own-work, no generative AI: every silhouette here is composed from explicit
primitives (ellipse, plate, spike, limb) at hand-picked coordinates, in the
docs/UI_GUIDE.md palette. The generator is the source of truth, the PNGs are
build output - editing a sprite means editing the composition below, which
keeps all 7 enemies and the hero on the same palette and the same lighting.

Run:  python3 tools/gen_pixel_assets.py            (from rogelike_app/)
Out:  assets/sprites/{hero,enemies,items,ui,env}/*.png
      plus a CSV fragment on stdout with --print-csv

Light comes from the upper left on every sprite. Outline is "out" (#080A0D),
1 px, applied last so silhouettes read against both the pit background and the
chalk UI.
"""

from __future__ import annotations

import argparse
import math
from pathlib import Path

from pixel_png import Canvas, color, from_ascii, write_png

ART = Path("assets/sprites")

# --- Primitives ------------------------------------------------------------


def shade(tokens: tuple[str, str, str], nx: float, ny: float) -> str:
    """Pick light/mid/dark from a 3-step ramp given normalised ellipse coords."""
    lit = (-nx - ny) * 0.7071  # dot with the upper-left light direction
    if lit > 0.35:
        return tokens[2]
    if lit < -0.45:
        return tokens[0]
    return tokens[1]


def ellipse(
    cv: Canvas,
    cx: float,
    cy: float,
    rx: float,
    ry: float,
    ramp: tuple[str, str, str],
    flat: bool = False,
) -> None:
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            nx = (x + 0.5 - cx) / max(rx, 0.001)
            ny = (y + 0.5 - cy) / max(ry, 0.001)
            d = nx * nx + ny * ny
            if d > 1.0:
                continue
            token = ramp[1] if flat else shade(ramp, nx * math.sqrt(d), ny * math.sqrt(d))
            cv.set(x, y, color(token))


def plate(cv: Canvas, x: int, y: int, w: int, h: int, ramp: tuple[str, str, str]) -> None:
    """Rounded armour plate with a lit top edge and a dark bottom edge."""
    for yy in range(h):
        for xx in range(w):
            if (xx in (0, w - 1)) and (yy in (0, h - 1)):
                continue
            token = ramp[1]
            if yy == 0 or (xx == 0 and yy < h - 1):
                token = ramp[2]
            elif yy == h - 1 or xx == w - 1:
                token = ramp[0]
            cv.set(x + xx, y + yy, color(token))


def spike(cv: Canvas, x: int, y: int, h: int, token: str, dx: int = 0) -> None:
    """Triangular spike growing upward from (x, y)."""
    for i in range(h):
        width = max(1, (h - i) // 2 + 1)
        for w in range(width):
            cv.set(x + w - width // 2 + dx * i, y - i, color(token))


def limb(cv: Canvas, x: int, y: int, dx: int, dy: int, length: int, token: str) -> None:
    px, py = float(x), float(y)
    n = max(abs(dx), abs(dy), 1)
    for _ in range(length):
        cv.set(int(round(px)), int(round(py)), color(token))
        px += dx / n
        py += dy / n


def eye(cv: Canvas, x: int, y: int, token: str = "charge", big: bool = False) -> None:
    cv.set(x, y, color(token))
    if big:
        cv.set(x + 1, y, color(token))
        cv.set(x, y + 1, color(token))
        cv.set(x + 1, y + 1, color(token))
        cv.set(x, y - 1, color("out"))
        cv.set(x + 1, y - 1, color("out"))


def sheet(frames: list[Canvas], cell_w: int, cell_h: int) -> Canvas:
    out = Canvas(cell_w * len(frames), cell_h)
    for i, frame in enumerate(frames):
        out.blit(frame, i * cell_w, 0)
    return out


def grid_sheet(rows: list[list[Canvas]], cell_w: int, cell_h: int, hframes: int) -> Canvas:
    out = Canvas(cell_w * hframes, cell_h * len(rows))
    for ry, row in enumerate(rows):
        for rx, frame in enumerate(row):
            out.blit(frame, rx * cell_w, ry * cell_h)
    return out


# --- Enemies ---------------------------------------------------------------
# All enemies face LEFT (the hero marches right into them). 32x32 cells,
# 4 idle frames. SLAGJAW uses 48x48.

RUST = ("rust2", "rust3", "rust4")
IRON = ("iron2", "iron3", "iron4")
BONE = ("bone2", "bone3", "bone4")
MOSS = ("moss2", "moss3", "moss4")
POIS = ("pois2", "pois3", "pois4")
LEAT = ("leat2", "leat3", "leat4")
VOID = ("void1", "void2", "void3")


def rust_rat(f: int) -> Canvas:
    """RUST_RAT - Rostrattan. Swarm chow: low, quick, rust-eaten."""
    cv = Canvas(32, 32)
    bob = (0, -1, 0, 1)[f]
    y0 = 18 + bob
    # tail
    for i in range(10):
        cv.set(24 + i - 1, y0 + 1 - int(math.sin(i * 0.45 + f) * 2), color("rust2"))
    ellipse(cv, 19, y0 + 2, 7, 4.5, RUST)           # body
    ellipse(cv, 21, y0 + 4, 5, 2.5, ("rust3", "rust4", "rust5"))  # lit belly
    ellipse(cv, 10, y0 + 1, 4, 3.5, RUST)           # head
    # snout
    ellipse(cv, 5, y0 + 2, 2.5, 1.5, ("rust1", "rust2", "rust3"))
    cv.set(3, y0 + 2, color("chalk300"))            # nose tip
    # one ear, tilted back
    ellipse(cv, 12, y0 - 3, 2.5, 2.5, ("rust1", "rust2", "rust3"))
    cv.set(12, y0 - 3, color("rust1"))
    # neck shadow so the head does not melt into the body at x4
    for ny in range(-2, 4):
        cv.set(14, y0 + ny, color("rust2"))
    eye(cv, 7, y0 - 1, "charge", big=True)
    # rust pitting on the back
    for px, py in ((16, y0 - 2), (20, y0 - 1), (22, y0 + 2), (18, y0 + 3)):
        cv.set(px, py, color("rust1"))
    # legs
    swing = (0, 1, 0, -1)[f]
    for lx in (12, 16, 21, 24):
        limb(cv, lx, y0 + 6, (1 if lx % 2 else -1) * swing, 3, 4, "rust2")
    return cv.outline(color("out"))


def slag_moth(f: int) -> Canvas:
    """SLAG_MOTH - Slaggmalen. Ash wings, charge-draining proboscis."""
    cv = Canvas(32, 32)
    flap = (0, 1, 2, 1)[f]
    y0 = 15
    # wings (upper pair big, lower pair small)
    ellipse(cv, 12, y0 - 3 + flap, 8, 6 - flap, ("bone1", "bone2", "bone3"))
    ellipse(cv, 21, y0 - 2 + flap, 7, 5 - flap, ("bone1", "bone2", "bone3"))
    ellipse(cv, 13, y0 + 6 - flap, 5, 3, ("bone1", "bone2", "bone2"))
    ellipse(cv, 20, y0 + 6 - flap, 4, 3, ("bone1", "bone2", "bone2"))
    # wing eyespots (poison) - readable even at x4
    for px, py in ((11, y0 - 4 + flap), (22, y0 - 3 + flap)):
        ellipse(cv, px, py, 2, 2, POIS)
        cv.set(px, py, color("pois5"))
    # body
    ellipse(cv, 16, y0 + 2, 2.5, 7, ("iron1", "iron2", "iron3"))
    # head + antennae
    ellipse(cv, 16, y0 - 6, 2.5, 2.5, ("iron2", "iron3", "iron4"))
    limb(cv, 14, y0 - 8, -2, -3, 5, "bone2")
    limb(cv, 18, y0 - 8, 2, -3, 5, "bone2")
    eye(cv, 14, y0 - 6, "charge")
    # coiled proboscis under the head, the DRAIN_CHARGE tell
    for px, py in ((15, y0 - 3), (14, y0 - 2), (13, y0 - 1), (13, y0), (14, y0 + 1), (15, y0)):
        cv.set(px, py, color("chrg4"))
    return cv.outline(color("out"))


def thorn_imp(f: int) -> Canvas:
    """THORN_IMP - Taggimpen. Thorns face outward, so do the spikes."""
    cv = Canvas(32, 32)
    bob = (0, -1, -2, -1)[f]
    y0 = 16 + bob
    ellipse(cv, 17, y0 + 4, 6, 6, MOSS)             # body
    ellipse(cv, 15, y0 - 3, 5.5, 5, MOSS)           # head
    # horns
    spike(cv, 12, y0 - 7, 5, "bone3")
    spike(cv, 19, y0 - 7, 4, "bone3")
    # back thorns
    for i, sx in enumerate((20, 22, 23)):
        spike(cv, sx, y0 + 1 + i * 3, 4 - i, "bone4")
    eye(cv, 12, y0 - 3, "blood", big=True)
    # grin
    for gx in range(11, 17):
        cv.set(gx, y0 + 1, color("bone4" if gx % 2 == 0 else "moss2"))
    # legs + tail
    limb(cv, 14, y0 + 9, -1, 3, 4, "moss2")
    limb(cv, 19, y0 + 9, 1, 3, 4, "moss2")
    for i in range(6):
        cv.set(23 + i, y0 + 8 - int(math.sin(i * 0.6) * 2), color("moss2"))
    spike(cv, 28, y0 + 5, 3, "blood")
    return cv.outline(color("out"))


def pip_thief(f: int) -> Canvas:
    """PIP_THIEF - Ogontjuven. Hood, empty face, a stolen die in the claw."""
    cv = Canvas(32, 32)
    bob = (0, 0, -1, -1)[f]
    y0 = 10 + bob
    # cloak: a trapezoid, widest at the floor
    for row in range(20):
        half = 4 + row * 0.45
        for x in range(int(9 + 7 - half), int(9 + 7 + half)):
            token = "leat3" if x < 14 else ("leat2" if x < 20 else "leat1")
            cv.set(x, y0 + 6 + row, color(token))
    # hood
    ellipse(cv, 16, y0 + 4, 7, 6, LEAT)
    ellipse(cv, 15, y0 + 5, 4.5, 4, ("out", "out", "out"), flat=True)
    eye(cv, 12, y0 + 5, "charge")
    eye(cv, 16, y0 + 5, "charge")
    # claw + stolen die (the STEAL tell)
    limb(cv, 9, y0 + 14, -2, 1, 4, "leat4")
    die_y = y0 + 13 + (0, -1, -2, -1)[f]
    cv.rect(3, die_y, 5, 5, color("bone5"))
    cv.set(5, die_y + 2, color("pip"))
    return cv.outline(color("out"))


def iron_tick(f: int) -> Canvas:
    """IRON_TICK - Jarnfastingen. armor 6: the wall. Read as plate, not flesh."""
    cv = Canvas(32, 32)
    bob = (0, 0, 1, 0)[f]
    y0 = 16 + bob
    ellipse(cv, 18, y0 + 2, 11, 8, IRON)            # carapace
    # plate seams
    for sx in (13, 18, 23):
        for sy in range(-6, 8):
            if (sx - 18) ** 2 / 121 + (sy - 2) ** 2 / 64 <= 1.0:
                cv.set(sx, y0 + sy, color("iron2"))
    # rivets
    for rx, ry in ((15, y0 - 3), (21, y0 - 3), (18, y0 + 5), (25, y0 + 1)):
        cv.set(rx, ry, color("shield"))
    # head
    ellipse(cv, 7, y0 + 3, 3.5, 3, ("iron1", "iron2", "iron3"))
    eye(cv, 5, y0 + 2, "rust4")
    # six legs
    swing = (0, 1, 0, -1)[f]
    for i, lx in enumerate((10, 15, 20, 25)):
        limb(cv, lx, y0 + 8, (-1 if i % 2 else 1) * (1 + swing), 3, 4, "iron2")
    return cv.outline(color("out"))


def grave_hand(f: int) -> Canvas:
    """GRAVE_HAND - Gravhanden. Five fingers out of a slag mound; GRAB tell."""
    cv = Canvas(32, 32)
    curl = (0, 1, 2, 1)[f]
    # mound
    ellipse(cv, 16, 29, 12, 5, ("pit", "slate", "raised"))
    # palm
    ellipse(cv, 16, 21, 6, 5, BONE)
    # fingers: outer ones curl inward as GRAB winds up
    fingers = ((8, 13, -1), (12, 9, 0), (16, 7, 0), (20, 9, 0), (24, 14, 1))
    for fx, top, lean in fingers:
        height = 21 - top
        for i in range(height):
            x = fx + int(lean * (i / max(height - 1, 1)) * curl)
            token = "bone4" if i > height - 3 else ("bone3" if i % 4 else "bone2")
            cv.set(x, 21 - i, color(token))
            cv.set(x + 1, 21 - i, color("bone2"))
        # knuckle
        cv.set(fx, top + 3, color("bone1"))
    # wrist
    cv.rect(13, 25, 7, 4, color("bone2"))
    for i in range(3):
        cv.hline(13, 25 + i * 2, 7, color("bone1"))
    return cv.outline(color("out"))


def slagjaw(f: int) -> Canvas:
    """SLAGJAW - Slaggkaften, boss. A jaw with a furnace behind the teeth."""
    cv = Canvas(48, 48)
    open_amount = (0, 1, 2, 1)[f]
    y0 = 22
    # skull mass
    ellipse(cv, 24, y0 - 2, 17, 12, IRON)
    # brow plates
    plate(cv, 9, y0 - 13, 30, 5, IRON)
    for rx in (12, 18, 30, 36):
        cv.set(rx, y0 - 11, color("shield"))
    # furnace maw
    ellipse(cv, 24, y0 + 4 + open_amount, 12, 5 + open_amount, ("rust1", "rust3", "rust5"))
    # upper teeth
    for i in range(7):
        tx = 13 + i * 3
        for t in range(3):
            cv.rect(tx, y0 + 1 + t, 2 - (t > 1), 1, color("bone4" if t == 0 else "bone3"))
    # lower teeth
    for i in range(6):
        tx = 15 + i * 3
        for t in range(3):
            cv.rect(tx, y0 + 10 + open_amount - t, 2, 1, color("bone4" if t == 0 else "bone3"))
    # eyes: the HARDEN tell burns brighter on the block frame
    eye(cv, 15, y0 - 8, "charge" if f != 2 else "rust4", big=True)
    eye(cv, 31, y0 - 8, "charge" if f != 2 else "rust4", big=True)
    # jaw hinges
    ellipse(cv, 8, y0 + 4, 4, 4, IRON)
    ellipse(cv, 40, y0 + 4, 4, 4, IRON)
    # slag dripping
    for i, (dx, dy) in enumerate(((17, 16), (24, 18), (31, 16))):
        cv.rect(dx, y0 + dy - (f + i) % 3, 1, 2 + (f + i) % 3, color("rust4"))
    return cv.outline(color("out"))


ENEMIES: dict[str, tuple] = {
    "RUST_RAT": (rust_rat, 32, "rust_rat.png"),
    "SLAG_MOTH": (slag_moth, 32, "slag_moth.png"),
    "THORN_IMP": (thorn_imp, 32, "thorn_imp.png"),
    "PIP_THIEF": (pip_thief, 32, "pip_thief.png"),
    "IRON_TICK": (iron_tick, 32, "iron_tick.png"),
    "GRAVE_HAND": (grave_hand, 32, "grave_hand.png"),
    "SLAGJAW": (slagjaw, 48, "slagjaw.png"),
}



# --- Enemy death frames ----------------------------------------------------
# Sheet contract (M2): cell unchanged, hframes 4, vframes 2.
#   row 0 = idle, 4 authored frames (unchanged from M1)
#   row 1 = death, 3 authored frames; column 3 repeats the last authored frame
#           so a wrong frame index gives a frozen pose, never an empty cell
#           (UI_GUIDE section 11, same rule as the paperdoll).
#
# The three beats are the same for every enemy, which is the point: the player
# has to be able to read "that one is dead" in 120 ms without looking at it.
#   0  RECOIL    squashed 12 %, widened, the eye light is gone
#   1  COLLAPSE  half height, a third of the body dissolved, debris thrown up
#   2  REMAINS   a flat pile on the floor line plus settling dust
#
# The frames are derived from the enemy's own idle frame 0 by resampling, so a
# redrawn enemy gets a matching death for free and no silhouette can drift.

_EYE_TOKENS: tuple[str, ...] = ("charge", "chrg4", "blood", "rust4", "pois5", "frost")


def _floor_row(cv: Canvas) -> int:
    """Lowest row that has an opaque pixel. That is where the body collapses."""
    for y in range(cv.height - 1, -1, -1):
        if any(cv.px[y][x][3] != 0 for x in range(cv.width)):
            return y
    return cv.height - 1


def _hash01(x: int, y: int, seed: int) -> float:
    h = (x * 73856093) ^ (y * 19349663) ^ (seed * 83492791)
    h &= 0xFFFFFFFF
    h = (h ^ (h >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


def _squash(src: Canvas, floor_y: int, scale_y: float, scale_x: float) -> Canvas:
    """Nearest neighbour resample around the floor line. Inverse mapped, so a
    widened body has no comb gaps."""
    out = Canvas(src.width, src.height)
    cx = src.width / 2.0
    for ny in range(src.height):
        sy = floor_y - (floor_y - ny) / max(scale_y, 0.01)
        if sy < 0 or sy >= src.height:
            continue
        for nx in range(src.width):
            sx = cx + (nx - cx) / max(scale_x, 0.01)
            if sx < 0 or sx >= src.width:
                continue
            px = src.px[int(sy)][int(sx)]
            if px[3] != 0:
                out.px[ny][nx] = px
    return out


def _dissolve(cv: Canvas, amount: float, seed: int) -> Canvas:
    """Eat `amount` of the opaque pixels, biased toward the top of the body."""
    floor_y = _floor_row(cv)
    top = 0
    for y in range(cv.height):
        if any(cv.px[y][x][3] != 0 for x in range(cv.width)):
            top = y
            break
    height = max(1, floor_y - top)
    out = Canvas(cv.width, cv.height)
    for y in range(cv.height):
        for x in range(cv.width):
            px = cv.px[y][x]
            if px[3] == 0:
                continue
            bias = 1.0 - (y - top) / height  # 1 at the head, 0 at the feet
            if _hash01(x, y, seed) < amount * (0.55 + 0.75 * bias):
                continue
            out.px[y][x] = px
    return out


def _kill_eyes(cv: Canvas, max_cluster: int = 8) -> Canvas:
    """The light goes out.

    Only SMALL clusters of an eye token are killed. Several enemies use the
    same hot tokens as body shading (RUST_RAT's lit edge is rust4, SLAGJAW's
    maw is rust3/rust5), and blacking those out would eat the silhouette
    instead of the eye. An eye is 1-4 px; a shaded flank is dozens.
    """
    dead = color("out")
    eyes = {color(t) for t in _EYE_TOKENS}
    seen: set[tuple[int, int]] = set()
    for y in range(cv.height):
        for x in range(cv.width):
            if (x, y) in seen or cv.px[y][x] not in eyes:
                continue
            target = cv.px[y][x]
            stack = [(x, y)]
            cluster: list[tuple[int, int]] = []
            seen.add((x, y))
            while stack and len(cluster) <= max_cluster:
                cx, cy = stack.pop()
                cluster.append((cx, cy))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = cx + dx, cy + dy
                    if (nx, ny) in seen:
                        continue
                    if 0 <= nx < cv.width and 0 <= ny < cv.height and cv.px[ny][nx] == target:
                        seen.add((nx, ny))
                        stack.append((nx, ny))
            if len(cluster) <= max_cluster:
                for cx, cy in cluster:
                    cv.px[cy][cx] = dead
    return cv


def death_frame(idle0: Canvas, stage: int, debris: str, spark: str, seed: int) -> Canvas:
    """One death frame. `stage` is 0, 1 or 2."""
    cell = idle0.width
    floor_y = _floor_row(idle0)
    if stage == 0:
        cv = _kill_eyes(_squash(idle0, floor_y, 0.88, 1.12))
        # impact dust kicked up along the floor line
        for i in range(5):
            dx = int((i - 2) * (cell / 9.0))
            cv.set(cell // 2 + dx, floor_y - 1 - (i % 2), color(debris))
        return cv
    if stage == 1:
        cv = _dissolve(_kill_eyes(_squash(idle0, floor_y, 0.52, 1.24)), 0.34, seed)
        # debris thrown up and out, biggest pieces lowest
        for i in range(9):
            t = i / 8.0
            dx = int(round((t - 0.5) * cell * 0.8))
            dy = int(round(-abs(math.sin(t * math.pi)) * cell * 0.28))
            token = spark if i % 3 == 0 else debris
            cv.set(cell // 2 + dx, floor_y + dy - 2, color(token))
            if i % 2 == 0:
                cv.set(cell // 2 + dx, floor_y + dy - 1, color(debris))
        return cv
    cv = _dissolve(_squash(idle0, floor_y, 0.20, 1.34), 0.66, seed + 7)
    # settled pile: a flat two row heap, brightest along the lit top edge
    half = int(cell * 0.30)
    for x in range(cell // 2 - half, cell // 2 + half):
        if _hash01(x, floor_y, seed + 19) < 0.78:
            cv.set(x, floor_y, color(debris))
        if _hash01(x, floor_y - 1, seed + 23) < 0.42:
            cv.set(x, floor_y - 1, color(spark if _hash01(x, 3, seed) > 0.8 else debris))
    # last dust, drifting up out of the pile
    for i in range(3):
        cv.set(cell // 2 - 4 + i * 4, floor_y - 4 - i, color(debris))
    return cv


# enemy id -> (debris token, spark token)
DEATH_TOKENS: dict[str, tuple[str, str]] = {
    "RUST_RAT": ("rust2", "rust4"),
    "SLAG_MOTH": ("bone2", "pois4"),
    "THORN_IMP": ("moss2", "bone4"),
    "PIP_THIEF": ("leat2", "chrg4"),
    "IRON_TICK": ("iron2", "shield"),
    "GRAVE_HAND": ("bone2", "bone4"),
    "SLAGJAW": ("iron2", "rust4"),
}


def build_enemy_sheet(fn, cell: int, enemy_id: str) -> Canvas:
    """Row 0 idle (4 frames), row 1 death (3 authored + 1 repeat)."""
    idle = [fn(f) for f in range(4)]
    debris, spark = DEATH_TOKENS.get(enemy_id, ("iron2", "shield"))
    seed = sum(ord(c) for c in enemy_id)
    death = [death_frame(idle[0], stage, debris, spark, seed) for stage in range(3)]
    death.append(death[2])
    return grid_sheet([idle, death], cell, cell, 4)

# --- Hero paperdoll --------------------------------------------------------
# Contract (research 04 section 2): cell 48x48, hframes 8, vframes 4, shared
# origin, shared frame order. Every layer sheet below obeys it exactly.

HF, VF, CELL = 8, 4, 48

# row -> (name, frame count actually authored)
ROWS: tuple[tuple[str, int], ...] = (
    ("idle", 4),
    ("walk", 8),
    ("attack", 6),
    ("hit", 4),
)


def pose(row: int, f: int) -> dict:
    """Per-frame rig: body bob, leg phase, arm angle, hand anchor, lean."""
    if row == 0:  # idle: slow breathe
        bob = (0, 0, 1, 0)[f % 4]
        return {"bob": bob, "leg": 0.0, "arm": -0.15, "hand": (33, 28 + bob), "lean": 0}
    if row == 1:  # walk: 8 frames, contact-down-pass-up x2
        phase = f / 8.0 * math.tau
        bob = int(round(abs(math.sin(phase * 2)) * -1.4))
        return {
            "bob": bob,
            "leg": math.sin(phase),
            "arm": -math.sin(phase) * 0.5,
            "hand": (33, 28 + bob),
            "lean": 1 if math.cos(phase) > 0.5 else 0,
        }
    if row == 2:  # attack: wind up 0-1, strike 2-3, recover 4-5
        table = [
            (-1.1, (28, 18), 0),
            (-1.5, (26, 15), -1),
            (0.9, (39, 26), 2),
            (1.2, (41, 33), 2),
            (0.4, (37, 31), 1),
            (-0.1, (34, 29), 0),
        ]
        arm, hand, lean = table[min(f, 5)]
        return {"bob": 0 if f < 2 else 1, "leg": 0.35, "arm": arm, "hand": hand, "lean": lean}
    # row 3: hit / stagger
    back = (0, 2, 3, 2)[f % 4]
    return {"bob": 1, "leg": -0.3, "arm": 0.6, "hand": (30 - back, 30), "lean": -back}


def hero_body_a(row: int, f: int) -> Canvas:
    """Base layer, variant A "Broad": legs, apron, torso, arms, head, beard.

    Faces right. This is the M1/M2 Smith, unchanged - only the file name moved
    from smith_body.png to smith_body_a.png when variant B arrived (M2.5).
    """
    cv = Canvas(CELL, CELL)
    p = pose(row, f)
    bob, lean = p["bob"], p["lean"]
    feet = 44
    hip = 32 + bob
    # legs: explicit foot targets so the walk cycle actually strides
    swing = p["leg"]
    lift = max(0.0, swing) * 3.0
    legs = (
        (22 + lean, 24 + lean + int(round(swing * 4)), feet - int(round(lift)), "leat3", "iron3"),
        (25 + lean, 24 + lean - int(round(swing * 4)), feet - int(round(max(0.0, -swing) * 3)), "leat2", "iron2"),
    )
    for hip_x, foot_x, foot_y, cloth, boot in legs:
        span = max(foot_y - hip, 1)
        for i in range(span):
            t = i / span
            x = int(round(hip_x + (foot_x - hip_x) * t))
            cv.rect(x, hip + i, 3, 1, color(cloth))
        cv.rect(foot_x - 1, foot_y - 2, 6, 3, color(boot))
        cv.hline(foot_x - 1, foot_y - 2, 6, color("iron4"))
    # torso
    ellipse(cv, 24 + lean, 26 + bob, 7, 7, ("leat2", "leat3", "leat4"))
    # leather apron over the torso (the Smith read)
    for i in range(12):
        half = 5 + i * 0.25
        cv.rect(int(24 + lean - half), 24 + bob + i, int(half * 2), 1, color("leat2"))
    cv.rect(20 + lean, 23 + bob, 9, 1, color("leat4"))
    # arms
    arm = p["arm"]
    hx, hy = p["hand"]
    sx, sy = 27 + lean, 25 + bob
    steps = max(abs(hx - sx), abs(hy - sy), 1)
    for i in range(steps + 1):
        ax = sx + (hx - sx) * i // steps
        ay = sy + (hy - sy) * i // steps
        cv.rect(ax, ay, 2, 2, color("skin2" if i > steps - 3 else "leat3"))
    # back arm
    cv.rect(18 + lean, 26 + bob, 3, 7, color("leat2"))
    cv.rect(17 + lean, 32 + bob, 3, 2, color("skin2"))
    # head
    ellipse(cv, 25 + lean, 16 + bob, 5, 5.5, ("skin1", "skin2", "skin3"))
    # beard + hair, soot-dark
    for i in range(6):
        cv.rect(21 + lean, 18 + bob + i, 8 - i, 1, color("iron2"))
    cv.rect(20 + lean, 11 + bob, 10, 3, color("iron2"))
    cv.set(28 + lean, 15 + bob, color("chalk100"))  # eye highlight
    cv.set(27 + lean, 15 + bob, color("pip"))
    # soot smudge on the cheek: a tell that survives x4 downscale
    cv.set(24 + lean, 16 + bob, color("iron2"))
    return cv.outline(color("out"))


def hero_body_b(row: int, f: int) -> Canvas:
    """Base layer, variant B "Lean". Same rig, different silhouette (M2.5).

    Body variants exist so the player can pick a figure (DECISIONS 2026-09-21).
    The contract is that EVERY gear and relic layer must fit both bodies, so
    variant B keeps every anchor the other layers read - foot line 44, hip
    32+bob, leg columns, torso centre (24, 26), head centre (25, 16), both hand
    anchors - and differs only where nothing is mounted:

      * torso is narrow and tall (rx 5.5, ry 8) instead of round (rx 7, ry 7);
      * the full apron is replaced by a belt and a SPLIT smock, so daylight
        shows between the legs where variant A is one solid wedge;
      * no beard: the jaw is bare and a wrapped collar carries the neck mass;
      * forearms are wrapped in bone-coloured cord instead of bare leather.

    Neither body is weaker: A reads as mass (wide wedge, beard), B reads as
    reach (tall column, open smock). Both are the Smith.
    """
    cv = Canvas(CELL, CELL)
    p = pose(row, f)
    bob, lean = p["bob"], p["lean"]
    feet = 44
    hip = 32 + bob
    swing = p["leg"]
    lift = max(0.0, swing) * 3.0
    # identical leg rig to variant A: smith_legs_iron.png must fit both
    legs = (
        (22 + lean, 24 + lean + int(round(swing * 4)), feet - int(round(lift)), "leat2", "iron3"),
        (25 + lean, 24 + lean - int(round(swing * 4)), feet - int(round(max(0.0, -swing) * 3)), "leat1", "iron2"),
    )
    for hip_x, foot_x, foot_y, cloth, boot in legs:
        span = max(foot_y - hip, 1)
        for i in range(span):
            t = i / span
            x = int(round(hip_x + (foot_x - hip_x) * t))
            cv.rect(x, hip + i, 3, 1, color(cloth))
            if i % 4 == 2:  # cord wraps down the shin
                cv.set(x + 1, hip + i, color("bone3"))
        cv.rect(foot_x - 1, foot_y - 2, 6, 3, color(boot))
        cv.hline(foot_x - 1, foot_y - 2, 6, color("iron4"))
    # torso: a tall narrow column, still 11 px wide at the chest so every
    # `torso` relic (widest is ECHO_MIRROR at cx-4..cx+5) lands on cloth
    ellipse(cv, 24 + lean, 26 + bob, 5.0, 8.0, ("leat2", "leat3", "leat4"))
    cv.rect(20 + lean, 23 + bob, 9, 1, color("bone3"))  # chest wrap
    # narrow belt + SPLIT smock: the waist pinches and daylight shows between
    # the panels, which is the whole silhouette difference against variant A
    cv.rect(20 + lean, 30 + bob, 8, 2, color("leat4"))
    cv.rect(23 + lean, 30 + bob, 2, 2, color("iron4"))  # buckle
    for i in range(8):
        drop = 32 + bob + i
        flare = i // 3
        cv.rect(19 + lean - flare, drop, 4 + flare, 1, color("leat3"))
        cv.rect(26 + lean, drop, 4 + flare, 1, color("leat3"))
        if i == 0:
            cv.hline(19 + lean, drop, 4, color("leat4"))
            cv.hline(26 + lean, drop, 4, color("leat4"))
    cv.hline(17 + lean, 39 + bob, 6, color("leat1"))
    cv.hline(26 + lean, 39 + bob, 6, color("leat1"))
    # front arm, wrapped: cord at the forearm, skin at the hand
    arm = p["arm"]
    hx, hy = p["hand"]
    sx, sy = 27 + lean, 24 + bob
    steps = max(abs(hx - sx), abs(hy - sy), 1)
    for i in range(steps + 1):
        ax = sx + (hx - sx) * i // steps
        ay = sy + (hy - sy) * i // steps
        if i > steps - 3:
            token = "skin3"
        elif i > steps - 7:
            token = "bone3"
        else:
            token = "leat3"
        cv.rect(ax, ay, 2, 2, color(token))
    # back arm: thinner than A, same hand position so `offhand` relics fit
    cv.rect(19 + lean, 26 + bob, 2, 7, color("leat1"))
    cv.rect(18 + lean, 30 + bob, 2, 3, color("bone3"))
    cv.rect(17 + lean, 32 + bob, 3, 2, color("skin2"))
    # collar wrap: the neck mass that variant A carries in its beard
    cv.rect(21 + lean, 20 + bob, 8, 2, color("rust2"))
    cv.rect(21 + lean, 20 + bob, 3, 1, color("rust3"))
    cv.set(20 + lean, 22 + bob, color("rust2"))
    # head: narrower face, bare jaw
    ellipse(cv, 25 + lean, 16 + bob, 4.5, 5.5, ("skin1", "skin2", "skin3"))
    cv.rect(21 + lean, 11 + bob, 8, 2, color("iron2"))      # cropped hair
    cv.rect(20 + lean, 12 + bob, 3, 4, color("iron2"))      # nape
    cv.rect(27 + lean, 13 + bob, 3, 1, color("iron2"))      # brow
    cv.set(28 + lean, 15 + bob, color("chalk100"))          # eye highlight
    cv.set(27 + lean, 15 + bob, color("pip"))
    cv.set(28 + lean, 18 + bob, color("skin1"))             # jaw shadow
    cv.set(24 + lean, 19 + bob, color("skin1"))
    cv.set(26 + lean, 12 + bob, color("iron2"))             # soot smudge
    return cv.outline(color("out"))


def hero_hair_a(row: int, f: int) -> Canvas:
    """Optional `hair` layer A: knot at the nape, tied with a rust cord.

    Sits BELOW `helm` in z, and everything it draws is behind the brim line, so
    it reads with or without a helmet. Works on either body: it only reads
    _head_anchor.
    """
    cv = Canvas(CELL, CELL)
    p = pose(row, f)
    cx, cy = _head_anchor(p)
    sway = p["leg"] * 1.2 + (1.0 if row == 2 and f in (2, 3) else 0.0)
    # crown cover, so the layer is attached even with no helm on
    for i, w in enumerate((7, 9, 9)):
        cv.rect(cx - 4, cy - 6 + i, w, 1, color("iron2"))
    cv.hline(cx - 3, cy - 6, 4, color("iron3"))
    # the knot itself, at the back of the skull (the hero faces right)
    ellipse(cv, cx - 6, cy + 1, 2.6, 2.6, ("iron1", "iron2", "iron3"))
    cv.rect(cx - 8, cy, 5, 1, color("rust3"))  # the cord
    # two loose strands falling out of the knot
    for i in range(5):
        cv.set(cx - 7 - int(round(sway * i * 0.3)), cy + 4 + i, color("iron2"))
        if i < 3:
            cv.set(cx - 5, cy + 4 + i, color("iron3"))
    return cv.outline(color("out"))


def hero_hair_b(row: int, f: int) -> Canvas:
    """Optional `hair` layer B: a long braid down the back that swings.

    The braid is the cheapest motion cue on the figure: it lags the walk cycle
    by one frame, which makes both bodies feel heavier without new frames.
    """
    cv = Canvas(CELL, CELL)
    p = pose(row, f)
    cx, cy = _head_anchor(p)
    sway = p["leg"] * 1.8 + (2.0 if row == 2 and f in (2, 3) else 0.0)
    for i, w in enumerate((7, 9, 9)):
        cv.rect(cx - 4, cy - 6 + i, w, 1, color("iron2"))
    cv.hline(cx - 3, cy - 6, 4, color("iron3"))
    x0, y0 = cx - 6, cy - 1
    for i in range(16):
        t = i / 15.0
        x = int(round(x0 - t * 2.0 - sway * t * t * 2.0))
        y = y0 + i
        w = 3 if i < 11 else 2
        cv.rect(x, y, w, 1, color("iron2" if (i // 2) % 2 else "iron3"))
        if i % 4 == 3:
            cv.rect(x, y, w, 1, color("rust3"))  # tie band
    cv.set(int(round(x0 - 2.0 - sway * 2.0)), y0 + 16, color("iron2"))
    return cv.outline(color("out"))


def hero_weapon_hammer(row: int, f: int) -> Canvas:
    """weapon layer variant A: the forge hammer (FORGE / ANVIL fantasy)."""
    cv = Canvas(CELL, CELL)
    p = pose(row, f)
    hx, hy = p["hand"]
    swung = row == 2 and f in (2, 3)
    # haft, 2 px wide so it survives the x4 downscale on a small phone
    if swung:
        for i in range(11):
            cv.rect(hx + i // 2, hy - i, 2, 1, color("leat3"))
        head_x, head_y = hx + 3, hy - 14
    else:
        for i in range(12):
            cv.rect(hx, hy - i, 2, 1, color("leat3"))
        head_x, head_y = hx - 3, hy - 17
    # head: a solid 8x6 block, the heaviest silhouette on the hero
    plate(cv, head_x, head_y, 8, 6, IRON)
    cv.rect(head_x + 1, head_y + 1, 3, 1, color("iron5"))
    cv.rect(head_x + 6, head_y + 1, 1, 4, color("iron2"))
    return cv.outline(color("out"))


def hero_weapon_tongs(row: int, f: int) -> Canvas:
    """weapon layer variant B: glowing tongs holding a hot ingot (FIRE)."""
    cv = Canvas(CELL, CELL)
    p = pose(row, f)
    hx, hy = p["hand"]
    # two jaws of the tongs, meeting at the ingot
    limb(cv, hx, hy, 2, -2, 8, "iron3")
    limb(cv, hx, hy + 1, 3, -2, 8, "iron2")
    tip_x, tip_y = hx + 7, hy - 6
    # the ingot: 3x3 hot metal with a charge-yellow core, the FIRE tell
    cv.rect(tip_x - 1, tip_y - 1, 3, 3, color("rust4"))
    cv.set(tip_x, tip_y, color("charge"))
    cv.set(tip_x - 1, tip_y + 1, color("rust3"))
    # heat shimmer, one pixel per frame so it flickers in the loop
    cv.set(tip_x + (f % 3) - 1, tip_y - 3, color("rust5"))
    return cv.outline(color("out"))


def hero_helm(row: int, f: int) -> Canvas:
    """helm layer: riveted iron dome with a brim and a nose guard."""
    cv = Canvas(CELL, CELL)
    p = pose(row, f)
    bob, lean = p["bob"], p["lean"]
    cx, cy = 25 + lean, 16 + bob
    # dome: narrow at the crown, widest just above the brim
    widths = (4, 6, 8, 10, 10)
    for i, w in enumerate(widths):
        token = "iron4" if i == 0 else ("iron3" if i < 3 else "iron2")
        cv.rect(cx - w // 2, cy - 8 + i, w, 1, color(token))
    # brim, only 1 px proud of the dome so the face stays readable
    cv.rect(cx - 6, cy - 3, 12, 1, color("iron4"))
    cv.rect(cx - 5, cy - 2, 10, 1, color("iron2"))
    # nose guard, in front of the face so the silhouette reads as a helm
    cv.rect(cx + 2, cy - 1, 2, 5, color("iron3"))
    cv.set(cx + 2, cy + 3, color("iron2"))
    # rivets
    cv.set(cx - 5, cy - 3, color("shield"))
    cv.set(cx + 5, cy - 3, color("shield"))
    cv.set(cx, cy - 7, color("shield"))
    return cv.outline(color("out"))


def hero_cape(row: int, f: int) -> Canvas:
    """cape layer: ember cloak. Hangs BEHIND the hero, so it trails left."""
    cv = Canvas(CELL, CELL)
    p = pose(row, f)
    bob, lean = p["bob"], p["lean"]
    sway = p["leg"] * 1.4 + (2.2 if row == 2 and f in (2, 3) else 0.0)
    top = 20 + bob
    rows_count = 20
    left_edges: list[tuple[int, int]] = []
    for i in range(rows_count):
        t = i / (rows_count - 1)
        # trails to the LEFT of the body: the hero walks right, the cloak lags
        left = 19 + lean - int(round(2 + t * 8 + sway * t * t * 3))
        right = 23 + lean - int(round(t * 1.5))
        width = max(right - left, 3)
        token = "blod1" if i % 5 == 0 else "blod2"
        cv.rect(left, top + i, width, 1, color(token))
        cv.vline(left, top + i, 1, color("blod1"))
        left_edges.append((left, width))
    # shoulder yoke, then an ember hem along the trailing edge
    cv.rect(19 + lean, top - 1, 6, 2, color("blod3"))
    for i in range(0, rows_count, 2):
        left, _ = left_edges[i]
        cv.set(left, top + i, color("rust3"))
    hem_left, hem_w = left_edges[-1]
    cv.rect(hem_left, top + rows_count - 1, hem_w, 1, color("rust4"))
    return cv.outline(color("out"))



# --- Hero paperdoll: relic and equipment layers (M2) -----------------------
# PAPERDOLL.md section 3 maps relic -> primary layer -> reserve layer. Every
# relic in src/data/content.gd needs a sheet for BOTH its layers, otherwise the
# collision rule in HeroFigure.apply_relics() resolves to a layer with no art
# and the relic silently disappears from the figure.
#
# File name contract: smith_<layer>_<relic_id.lower()>.png
# Every sheet is the same 48x48 / 8x4 grid with the same origin as smith_body,
# and every function reads the SAME pose() rig, so a layer can never desync.

def _offhand_anchor(p: dict) -> tuple[int, int]:
    """Left hand (the one hero_body draws as the back arm), in cell pixels."""
    return (18 + p["lean"], 33 + p["bob"])


def _torso_anchor(p: dict) -> tuple[int, int]:
    """Centre of the chest ellipse in hero_body."""
    return (24 + p["lean"], 26 + p["bob"])


def _head_anchor(p: dict) -> tuple[int, int]:
    return (25 + p["lean"], 16 + p["bob"])


def _leg_targets(p: dict) -> list[tuple[int, int, int]]:
    """(hip_x, foot_x, foot_y) for both legs - copied from hero_body's rig."""
    lean, bob = p["lean"], p["bob"]
    hip = 32 + bob
    swing = p["leg"]
    lift = max(0.0, swing) * 3.0
    return [
        (22 + lean, 24 + lean + int(round(swing * 4)), 44 - int(round(lift))),
        (25 + lean, 24 + lean - int(round(swing * 4)), 44 - int(round(max(0.0, -swing) * 3))),
    ], hip


def hero_legs_iron(row: int, f: int) -> Canvas:
    """legs layer (equipment, not a relic): riveted greaves and knee cops.

    Drawn so PAPERDOLL section 2's reserved `legs` slot has real art and M2's
    armour pieces have a template. Iron ramp, lit from the upper left.
    """
    cv = Canvas(CELL, CELL)
    p = pose(row, f)
    legs, hip = _leg_targets(p)
    for index, (hip_x, foot_x, foot_y) in enumerate(legs):
        span = max(foot_y - hip, 1)
        ramp = IRON if index == 0 else ("iron1", "iron2", "iron3")
        # greave: the lower 60 % of the shin
        for i in range(span):
            if i < span * 0.4:
                continue
            t = i / span
            x = int(round(hip_x + (foot_x - hip_x) * t))
            cv.rect(x, hip + i, 3, 1, color(ramp[1]))
            cv.set(x, hip + i, color(ramp[2]))          # lit left edge
            cv.set(x + 2, hip + i, color(ramp[0]))      # shaded right edge
        # knee cop: a 4x3 plate at 40 % down the leg
        knee_t = 0.38
        kx = int(round(hip_x + (foot_x - hip_x) * knee_t))
        plate(cv, kx - 1, hip + int(span * knee_t), 5, 3, ramp)
        cv.set(kx + 1, hip + int(span * knee_t) + 1, color("shield"))  # rivet
    return cv.outline(color("out"))


def hero_torso_broken_scale(row: int, f: int) -> Canvas:
    """BROKEN_SCALE, primary layer `torso`: a split balance on a chain.

    Tell (PAPERDOLL section 3): the two pans never level out. The beam tips a
    little further on every bob frame, so the relic reads as *broken* even when
    the figure stands still.
    """
    cv = Canvas(CELL, CELL)
    p = pose(row, f)
    cx, cy = _torso_anchor(p)
    tip = (0, 1, 1, 0)[f % 4] + (1 if row == 2 and f in (2, 3) else 0)
    # cord from the neck down to the fulcrum: narrow, so the beam reads wide
    cv.vline(cx, cy - 7, 4, color("iron3"))
    beam_y = cy - 3
    # beam: tilted as one rigid bar, left end down, right end up
    for i, x in enumerate(range(cx - 5, cx + 6)):
        t = (i - 5) / 5.0
        cv.set(x, beam_y + int(round(t * (1 + tip))), color("iron4"))
    cv.rect(cx - 1, beam_y - 2, 3, 3, color("iron3"))  # fulcrum block
    cv.set(cx, beam_y - 2, color("shield"))
    # two pans. Left hangs low and full, right hangs high and empty.
    left_y = beam_y + 1 + tip
    right_y = beam_y - 1 - tip
    cv.vline(cx - 5, left_y, 5, color("iron2"))
    cv.rect(cx - 8, left_y + 5, 7, 1, color("iron4"))
    cv.rect(cx - 7, left_y + 6, 5, 1, color("iron2"))
    cv.rect(cx - 6, left_y + 4, 3, 1, color("blod3"))  # what it weighs: blood
    # right chain is SNAPPED - the pan hangs from one strand and tilts
    cv.vline(cx + 5, right_y, 2, color("iron2"))
    cv.set(cx + 5, right_y + 2, color("blood"))        # the break
    cv.vline(cx + 6, right_y + 3, 2, color("iron2"))
    cv.rect(cx + 4, right_y + 5, 6, 1, color("iron4"))
    cv.rect(cx + 5, right_y + 6, 4, 1, color("iron2"))
    return cv.outline(color("out"))


def hero_offhand_broken_scale(row: int, f: int) -> Canvas:
    """BROKEN_SCALE, reserve layer `offhand`: the same balance, held."""
    cv = Canvas(CELL, CELL)
    p = pose(row, f)
    hx, hy = _offhand_anchor(p)
    tip = (0, 1, 1, 0)[f % 4]
    cv.vline(hx, hy, 3, color("iron3"))
    for i, x in enumerate(range(hx - 4, hx + 5)):
        cv.set(x, hy + 3 + (tip if i > 4 else -tip), color("iron4"))
    for pan_x, drop in ((hx - 4, 4 + tip), (hx + 4, 2 - tip)):
        cv.vline(pan_x, hy + 3, drop, color("iron2"))
        cv.rect(pan_x - 1, hy + 3 + drop, 3, 1, color("iron4"))
    cv.set(hx + 4, hy + 4, color("blood"))
    return cv.outline(color("out"))


def hero_cape_octopus(row: int, f: int) -> Canvas:
    """OCTOPUS, primary layer `cape`: two arms out of the back.

    Tell: the arms reach LEFT, toward slot 1 and slot 3 in the chain - the
    relic's rule is that it touches non-adjacent slots, so the silhouette has
    to show reach, not bulk. Suckers are single pois5 pixels so they survive x4.
    """
    cv = Canvas(CELL, CELL)
    p = pose(row, f)
    bob, lean = p["bob"], p["lean"]
    phase = f * 0.9 + (1.4 if row == 2 else 0.0)
    for arm, (base_y, length, amp) in enumerate(((23, 17, 2.6), (28, 14, 1.9))):
        x = 19 + lean
        y = base_y + bob
        for i in range(length):
            wave = math.sin(phase + i * 0.55 + arm * 1.7) * amp * (i / length)
            px = x - i
            py = int(round(y + wave))
            thickness = 2 if i < length * 0.6 else 1
            cv.rect(px, py, 1, thickness, color("pois3" if i % 3 else "pois4"))
            if i % 3 == 1:
                cv.set(px, py + thickness, color("pois5"))  # sucker
        # shoulder root, so the arm does not float free of the body
        cv.rect(x - 1, y - 1, 3, 3, color("pois2"))
    return cv.outline(color("out"))


def hero_fx_octopus(row: int, f: int) -> Canvas:
    """OCTOPUS, reserve layer `fx`: thinner arms, so it still reads when a
    higher rarity relic owns `cape`. One pixel thick, no shoulder root."""
    cv = Canvas(CELL, CELL)
    p = pose(row, f)
    bob, lean = p["bob"], p["lean"]
    phase = f * 0.9
    for arm, (base_y, length, amp) in enumerate(((22, 15, 3.0), (30, 12, 2.2))):
        for i in range(length):
            wave = math.sin(phase + i * 0.6 + arm * 1.7) * amp * (i / length)
            cv.set(18 + lean - i, int(round(base_y + bob + wave)), color("pois4" if i % 2 else "pois3"))
    return cv


def hero_cape_echo_mirror(row: int, f: int) -> Canvas:
    """ECHO_MIRROR, primary layer `cape`: shards floating behind the shoulders.

    Tell: the relic repeats a slot, so there are TWO shards of the same shape
    at different sizes - a thing and its echo, not a random scatter.
    """
    cv = Canvas(CELL, CELL)
    p = pose(row, f)
    bob, lean = p["bob"], p["lean"]
    drift = (0, -1, 0, 1)[f % 4]
    shards = (
        (12 + lean, 15 + bob + drift, 7, 11),  # the thing
        (6 + lean, 25 + bob - drift, 5, 8),    # its echo, smaller
        (13 + lean, 33 + bob + drift, 3, 5),   # second echo, fading out
    )
    for index, (sx, sy, w, h) in enumerate(shards):
        for yy in range(h):
            # a shard, not a rectangle: the right edge is cut at an angle
            width = max(1, w - abs(yy - h // 2) // 2)
            cv.rect(sx, sy + yy, width, 1, color("glass3" if index else "glass4"))
        cv.vline(sx, sy, h, color("glass5"))            # lit edge, upper left
        cv.set(sx + 1, sy + 1, color("chalk100"))       # glint
        cv.vline(sx + max(1, w - 1), sy + 1, max(1, h - 2), color("glass2"))
    return cv.outline(color("out"))


def hero_torso_echo_mirror(row: int, f: int) -> Canvas:
    """ECHO_MIRROR, reserve layer `torso`: the mirror worn on the chest."""
    cv = Canvas(CELL, CELL)
    p = pose(row, f)
    cx, cy = _torso_anchor(p)
    plate(cv, cx - 3, cy - 3, 7, 9, ("glass2", "glass3", "glass4"))
    cv.rect(cx - 2, cy - 2, 5, 7, color("glass4"))
    # the crack that makes it an ECHO and not a shield
    for i, (dx, dy) in enumerate(((0, -2), (1, -1), (0, 0), (1, 1), (0, 2), (1, 3))):
        cv.set(cx + dx, cy + dy, color("glass1"))
    cv.set(cx - 1, cy - 2, color("chalk100"))
    cv.rect(cx - 4, cy - 4, 9, 1, color("iron3"))  # frame
    return cv.outline(color("out"))


def hero_offhand_cheat_cube(row: int, f: int) -> Canvas:
    """CHEAT_CUBE, primary layer `offhand`: a loaded die in the left hand.

    Tell: the face NEVER changes across the frames. Every other die in the game
    tumbles; this one shows the same six on every single frame, which is the
    whole joke and the whole rule.
    """
    cv = Canvas(CELL, CELL)
    p = pose(row, f)
    hx, hy = _offhand_anchor(p)
    cv.rect(hx - 3, hy, 6, 6, color("bone4"))
    cv.hline(hx - 3, hy, 6, color("bone5"))         # lit top
    cv.vline(hx - 3, hy, 6, color("bone5"))         # lit left
    cv.hline(hx - 3, hy + 5, 6, color("bone2"))     # shaded bottom
    cv.vline(hx + 2, hy, 6, color("bone2"))
    # six pips, identical in every frame
    for px in (hx - 2, hx + 1):
        for py in (hy + 1, hy + 2, hy + 3):
            cv.set(px, py + (1 if py == hy + 3 else 0), color("pip"))
    # a charge-yellow glint: the die is weighted, and it knows it
    cv.set(hx - 3, hy, color("charge"))
    return cv.outline(color("out"))


def hero_torso_cheat_cube(row: int, f: int) -> Canvas:
    """CHEAT_CUBE, reserve layer `torso`: the die strapped to a bandolier."""
    cv = Canvas(CELL, CELL)
    p = pose(row, f)
    cx, cy = _torso_anchor(p)
    # bandolier, upper left to lower right. Iron studs on dark leather: the
    # apron underneath is already leat2/leat3, so a leather strap would vanish.
    for i in range(14):
        cv.set(cx - 6 + i, cy - 6 + i, color("iron2"))
        cv.set(cx - 5 + i, cy - 6 + i, color("iron4"))
        if i % 3 == 0:
            cv.set(cx - 6 + i, cy - 6 + i, color("shield"))
    dx, dy = cx + 1, cy + 1
    cv.rect(dx - 2, dy - 2, 5, 5, color("bone4"))
    cv.hline(dx - 2, dy - 2, 5, color("bone5"))
    cv.vline(dx - 2, dy - 2, 5, color("bone5"))
    for px in (dx - 1, dx + 1):
        for py in (dy - 1, dy + 1):
            cv.set(px, py, color("pip"))
    cv.set(dx, dy, color("charge"))
    return cv.outline(color("out"))


def hero_head_domino(row: int, f: int) -> Canvas:
    """DOMINO, reserve layer `head`: a tile at the temple that tips.

    This is the layer that actually lights up in play: PAPERDOLL section 3 says
    equipment beats relics on a shared layer, and the Smith always wears a helm,
    so DOMINO always falls through from `helm` to `head`.

    Tell: the tile stands upright at rest and TIPS on the attack frames - the
    relic fires on a chain, so the art has to show the first domino going over.
    """
    cv = Canvas(CELL, CELL)
    p = pose(row, f)
    cx, cy = _head_anchor(p)
    tipping = row == 2 and f >= 2
    # `head` is z 4 and the helm is z 5, so anything drawn at the temple is
    # hidden by the helm. The tile therefore hangs on a cord from under the
    # brim, beside the jaw, where it is visible with OR without a helm.
    cv.vline(cx + 5, cy - 3, 3, color("iron3"))
    x, y = cx + 4, cy + 1
    if tipping:
        # gone over: the tile lies flat and points forward
        cv.rect(x - 1, y + 3, 7, 3, color("bone4"))
        cv.hline(x - 1, y + 3, 7, color("bone5"))
        cv.vline(x + 2, y + 3, 3, color("bone2"))
        cv.set(x, y + 4, color("pip"))
        cv.set(x + 4, y + 4, color("pip"))
    else:
        cv.rect(x, y, 4, 8, color("bone4"))
        cv.vline(x, y, 8, color("bone5"))
        cv.hline(x, y + 4, 4, color("bone2"))   # the dividing line
        cv.set(x + 1, y + 1, color("pip"))
        cv.set(x + 2, y + 2, color("pip"))
        cv.set(x + 1, y + 6, color("pip"))
    return cv.outline(color("out"))


def hero_helm_domino(row: int, f: int) -> Canvas:
    """DOMINO, primary layer `helm`: the tile as a crest.

    Only used if the Smith has no helm equipped. Kept so the collision rule in
    PAPERDOLL section 3 has art on both ends of the chain and never resolves to
    an empty layer.
    """
    cv = Canvas(CELL, CELL)
    p = pose(row, f)
    cx, cy = _head_anchor(p)
    lean_tip = 1 if row == 2 and f in (2, 3) else 0
    cv.rect(cx - 5, cy - 4, 11, 2, color("leat3"))          # headband
    x, y = cx + lean_tip, cy - 12
    cv.rect(x - 2, y, 4, 8, color("bone4"))
    cv.vline(x - 2, y, 8, color("bone5"))
    cv.hline(x - 2, y + 4, 4, color("bone2"))
    cv.set(x - 1, y + 1, color("pip"))
    cv.set(x, y + 2, color("pip"))
    cv.set(x - 1, y + 6, color("pip"))
    return cv.outline(color("out"))


def hero_fx_blood_price(row: int, f: int) -> Canvas:
    """BLOOD_PRICE, primary layer `fx`: drops falling from both hands.

    PAPERDOLL section 3 asks for 2 drops per second. idle is 0.64 s over 4
    frames, so the cycle below drops one bead from each hand per two frames and
    lands at 2/s. No outline: a 1 px bead with a 1 px outline is a 3 px blob.

    `fx` is the only layer that may stack, so this sheet must stay visually
    thin - it will often be drawn on top of another relic's fx.
    """
    cv = Canvas(CELL, CELL)
    p = pose(row, f)
    hands = (p["hand"], _offhand_anchor(p))
    for index, (hx, hy) in enumerate(hands):
        # bead forming at the fingertip
        stage = (f + index * 2) % 4
        if stage == 0:
            cv.rect(hx, hy + 2, 2, 2, color("blod4"))
            cv.set(hx, hy + 2, color("blod5"))
        elif stage == 1:
            cv.rect(hx, hy + 3, 2, 3, color("blod4"))
            cv.set(hx, hy + 3, color("blod5"))
            cv.rect(hx, hy + 6, 2, 1, color("blod3"))
        else:
            fall = 3 + stage * 4
            cv.rect(hx, hy + fall, 2, 3, color("blod4"))
            cv.set(hx, hy + fall, color("blod5"))
            cv.rect(hx, hy + fall + 3, 2, 1, color("blod3"))
            # splash on the floor once the bead has cleared the boot line
            if hy + fall + 3 >= 42:
                cv.rect(hx - 2, 44, 2, 1, color("blod3"))
                cv.rect(hx + 2, 44, 2, 1, color("blod3"))
    return cv

# --- Hero portraits (96x96, the choose-your-Smith screen) ------------------


def smith_portrait(variant: str) -> Canvas:
    """96x96 bust for the variant picker (UI_GUIDE section 16).

    Not an upscale of the 48x48 cell: at x2 the idle frame turns to mush. The
    bust is authored at portrait resolution and carries the SAME three reads as
    the body sheet, so the figure the player picks is the figure they get:
    A = broad shoulders, full beard, knotted hair; B = narrow shoulders, bare
    jaw, wrapped collar, braid over the shoulder.
    """
    broad = variant == "a"
    size = 96
    cv = Canvas(size, size)
    cx = 48
    # --- shoulders and chest -------------------------------------------
    half_max = 43 if broad else 29
    top = 64 if broad else 67
    for y in range(top, size):
        t = (y - top) / max(size - top, 1)
        half = int(round(half_max * (0.68 + 0.32 * math.sqrt(t))))
        cv.rect(cx - half, y, half * 2, 1, color("leat2"))
        cv.set(cx - half, y, color("leat3"))
        cv.set(cx + half - 1, y, color("leat1"))
    cv.hline(cx - int(half_max * 0.68), top, int(half_max * 0.68) * 2, color("leat3"))
    if broad:
        # apron bib with two straps: the working-smith read
        for y in range(top + 4, size):
            cv.rect(cx - 16, y, 32, 1, color("leat3"))
        for dx in (-17, 15):
            for y in range(top, size):
                cv.rect(cx + dx, y, 3, 1, color("leat4"))
        cv.rect(cx - 16, top + 4, 32, 1, color("leat4"))
        for sx in (cx - 12, cx - 2, cx + 8):
            cv.rect(sx, top + 7, 2, 2, color("iron4"))  # rivets
    else:
        # bandolier across one shoulder, and a rust collar wrap
        for i in range(34):
            cv.rect(cx - 20 + i, top + 2 + i, 4, 1, color("iron2"))
            cv.set(cx - 20 + i, top + 2 + i, color("iron4"))
        for y in range(top - 6, top + 4):
            t = (y - (top - 6)) / 10.0
            w = int(round(9 + t * 9))
            cv.rect(cx - w, y, w * 2, 1, color("rust2"))
        cv.hline(cx - 9, top - 6, 18, color("rust3"))
    # --- neck ----------------------------------------------------------
    neck_w = 18 if broad else 13
    cv.rect(cx - neck_w // 2, 52, neck_w, 16, color("skin2"))
    cv.rect(cx - neck_w // 2, 52, 3, 16, color("skin1"))
    # --- head ----------------------------------------------------------
    head_rx = 19.0 if broad else 15.5
    ellipse(cv, cx + 1, 36, head_rx, 22.0, ("skin1", "skin2", "skin3"))
    # ear on the shaded side
    ellipse(cv, cx - head_rx + 2, 38, 3.0, 4.0, ("skin1", "skin2", "skin3"))
    # --- features, looking slightly right ------------------------------
    eye_y = 36
    for ex in (cx - 6, cx + 10):
        cv.rect(ex - 3, eye_y - 1, 7, 4, color("bone5"))
        cv.rect(ex, eye_y, 3, 3, color("pip"))
        cv.set(ex + 1, eye_y, color("chalk100"))
        cv.rect(ex - 4, eye_y - 5, 9, 2, color("iron2"))  # brow
    # nose: a 3 px step on the lit side of the face
    for i in range(6):
        cv.rect(cx + 12, 40 + i, 4 - i // 3, 1, color("skin2"))
    cv.rect(cx + 12, 46, 5, 1, color("skin1"))
    if broad:
        # --- beard: the A silhouette ----------------------------------
        cv.rect(cx - 13, 47, 28, 3, color("iron2"))  # moustache
        for i in range(23):
            t = i / 22.0
            w = int(round(30 * (1.0 - t * t * 0.62)))
            y = 50 + i
            token = "iron1" if i > 15 else "iron2"
            cv.rect(cx - w // 2 - 1, y, w, 1, color(token))
        # two lit strands, upper left light, so the beard is hair and not cloth
        for i in range(12):
            cv.set(cx - 12 + i // 4, 50 + i, color("iron3"))
        cv.set(cx - 9, 53, color("iron3"))
        cv.rect(cx - 7, 72, 10, 2, color("iron1"))
        # knotted hair, variant A's hair layer, seen from the front
        for i, w in enumerate((22, 30, 34, 36)):
            cv.rect(cx + 1 - w // 2, 12 + i * 2, w, 2, color("iron2"))
        cv.rect(cx - 19, 18, 6, 14, color("iron2"))   # hair down the temple
        ellipse(cv, cx - 21, 32, 6.0, 5.5, ("iron1", "iron2", "iron3"))
        cv.rect(cx - 27, 29, 12, 2, color("rust3"))   # the cord
        cv.rect(cx - 10, 14, 10, 2, color("iron3"))  # lit crown
    else:
        # --- bare jaw: the B silhouette -------------------------------
        cv.rect(cx - 6, 50, 14, 2, color("skin1"))   # mouth line
        cv.rect(cx - 13, 44, 3, 8, color("skin1"))   # cheekbone shadow
        cv.rect(cx - 9, 56, 20, 2, color("skin1"))   # jaw shadow
        for i, w in enumerate((18, 26, 29, 30)):
            cv.rect(cx + 1 - w // 2, 14 + i * 2, w, 2, color("iron2"))
        cv.rect(cx - 8, 15, 9, 2, color("iron3"))
        # braid over the near shoulder, variant B's hair layer
        for i in range(26):
            t = i / 25.0
            x = cx - 16 - int(round(t * 7))
            y = 30 + i * 2
            w = 5 if i < 20 else 3
            cv.rect(x, y, w, 2, color("iron2" if (i // 2) % 2 else "iron3"))
            if i % 4 == 3:
                cv.rect(x, y, w, 1, color("rust3"))
    # soot, both variants: this is a person who works at a forge
    cv.rect(cx + 6, 26, 5, 2, color("iron2", 150))
    cv.rect(cx - 14 if broad else cx - 11, 62, 6, 2, color("iron2", 120))
    return cv.outline(color("out"))


HERO_LAYERS: dict[str, tuple] = {
    # equipment
    "body_a": (hero_body_a, "bas-kropp variant A Broad, alltid synlig"),
    "body_b": (hero_body_b, "bas-kropp variant B Lean, alltid synlig"),
    "hair_a": (hero_hair_a, "frisyr A, knut i nacken, valfritt lager"),
    "hair_b": (hero_hair_b, "frisyr B, lang flata, valfritt lager"),
    "weapon_hammer": (hero_weapon_hammer, "vapen A"),
    "weapon_tongs": (hero_weapon_tongs, "vapen B"),
    "helm_iron": (hero_helm, "hjalm"),
    "cape_ember": (hero_cape, "kappa"),
    "legs_iron": (hero_legs_iron, "benskenor, utrustningslager legs"),
    # relics: every relic in content.gd gets BOTH its primary and its reserve
    # layer (PAPERDOLL.md section 3), so the collision rule can never resolve
    # to a layer without art.
    "fx_blood_price": (hero_fx_blood_price, "BLOOD_PRICE, primar fx"),
    "torso_broken_scale": (hero_torso_broken_scale, "BROKEN_SCALE, primar torso"),
    "offhand_broken_scale": (hero_offhand_broken_scale, "BROKEN_SCALE, reserv offhand"),
    "cape_octopus": (hero_cape_octopus, "OCTOPUS, primar cape"),
    "fx_octopus": (hero_fx_octopus, "OCTOPUS, reserv fx"),
    "cape_echo_mirror": (hero_cape_echo_mirror, "ECHO_MIRROR, primar cape"),
    "torso_echo_mirror": (hero_torso_echo_mirror, "ECHO_MIRROR, reserv torso"),
    "offhand_cheat_cube": (hero_offhand_cheat_cube, "CHEAT_CUBE, primar offhand"),
    "torso_cheat_cube": (hero_torso_cheat_cube, "CHEAT_CUBE, reserv torso"),
    "helm_domino": (hero_helm_domino, "DOMINO, primar helm"),
    "head_domino": (hero_head_domino, "DOMINO, reserv head"),
}


def build_hero_sheet(fn) -> Canvas:
    rows: list[list[Canvas]] = []
    for row_index, (_, count) in enumerate(ROWS):
        frames: list[Canvas] = []
        for f in range(HF):
            frames.append(fn(row_index, min(f, count - 1)))
        rows.append(frames)
    return grid_sheet(rows, CELL, CELL, HF)


# --- Icons (16x16) ---------------------------------------------------------

ICON_KEY = {
    "o": "out",
    "c": "chalk100",
    "d": "chalk300",
    "b": "bone5",
    "n": "bone3",
    "i": "iron4",
    "j": "iron2",
    "r": "rust4",
    "e": "rust3",
    "p": "pois4",
    "f": "frost",
    "g": "charge",
    "v": "blood",
    "h": "heal",
    "s": "shield",
    "k": "void3",
}


def icon(rows: list[str]) -> Canvas:
    return from_ascii(rows, ICON_KEY).outline(color("out"))


RELIC_ICONS: dict[str, list[str]] = {
    # BLOOD_PRICE - a drop paying a price
    "BLOOD_PRICE": [
        "................",
        ".......vv.......",
        "......vvvv......",
        "......vvvv......",
        ".....vvvvvv.....",
        ".....vvvvvv.....",
        "....vvvvvvvv....",
        "....vvvcvvvv....",
        "...vvvvcvvvvv...",
        "...vvvvvvvvvv...",
        "...vvvvvvvvvv...",
        "....vvvvvvvv....",
        ".....vvvvvv.....",
        "......vvvv......",
        "................",
        "................",
    ],
    # BROKEN_SCALE - a balance split down the middle
    "BROKEN_SCALE": [
        "................",
        ".......ss.......",
        ".......ss.......",
        "..sssssssssss...",
        "..s.....s...s...",
        "..s.....s...s...",
        ".sss....s..sss..",
        "sssss...s.sssss.",
        ".sss....s..sss..",
        ".......ss.......",
        "......jssj......",
        ".......ss.......",
        "......ssss......",
        ".....ssssss.....",
        "................",
        "................",
    ],
    # OCTOPUS - slot 1 and 3 reach each other
    "OCTOPUS": [
        "................",
        ".....pppp.......",
        "....pppppp......",
        "...pppppppp.....",
        "...pcpppcpp.....",
        "...pppppppp.....",
        "....pppppp......",
        "...p.p.p.p.p....",
        "..p..p.p..p.p...",
        ".p...p.p...p.p..",
        "p....p.p....p.p.",
        ".....p.p.....p..",
        "....p...p.......",
        "...p.....p......",
        "................",
        "................",
    ],
    # ECHO_MIRROR - mirror with an echo shard
    "ECHO_MIRROR": [
        "................",
        "...ffffffff.....",
        "...fccccccf.....",
        "...fcccccff.....",
        "...fccccfcf.....",
        "...fcccfccf.....",
        "...fccfcccf.....",
        "...fcfccccf.....",
        "...ffcccccf.....",
        "...fccccccf.....",
        "...ffffffff.....",
        "......ff........",
        ".....ffff.......",
        "....ffffff......",
        "................",
        "................",
    ],
    # CHEAT_CUBE - a die showing the same face twice
    "CHEAT_CUBE": [
        "................",
        "..bbbbbbbbbb....",
        "..bnbbbbbbnb....",
        "..bbbbbbbbbb....",
        "..bbojbbojbb....",
        "..bbjobbjobb....",
        "..bbbbbbbbbb....",
        "..bbojbbojbb....",
        "..bbjobbjobb....",
        "..bbbbbbbbbb....",
        "..bbojbbojbb....",
        "..bbjobbjobb....",
        "..bnbbbbbbnb....",
        "..bbbbbbbbbb....",
        "................",
        "................",
    ],
    # DOMINO - a domino tile mid-fall
    "DOMINO": [
        "................",
        "...bbbb.........",
        "...bobb.........",
        "...bbbb..bbbb...",
        "...bbbb..bobb...",
        "...bbob..bbbb...",
        "...bbbb..bbbb...",
        "...bbbb..bbob...",
        "...bbbb..bbbb...",
        "....gg....gg....",
        "...bbbb..bbbb...",
        "...bobb..bobb...",
        "...bbbb..bbbb...",
        "................",
        "................",
        "................",
    ],
}

NODE_ICONS: dict[str, list[str]] = {
    "COMBAT": [
        "................",
        "..i..........i..",
        "..ii........ii..",
        "...ii......ii...",
        "....ii....ii....",
        ".....ii..ii.....",
        "......iiii......",
        ".......ii.......",
        "......iiii......",
        ".....ii..ii.....",
        "....ii....ii....",
        "...jj......jj...",
        "..jj........jj..",
        "..j..........j..",
        "................",
        "................",
    ],
    "ELITE": [
        "................",
        ".....bbbbbb.....",
        "....bbbbbbbb....",
        "...bbbbbbbbbb...",
        "...bboobboobb...",
        "...bboobboobb...",
        "...bbbbbbbbbb...",
        "....bbbobbbb....",
        "....bbbbbbbb....",
        ".....bobobo.....",
        "......bbbb......",
        "....vv....vv....",
        "...vv......vv...",
        "................",
        "................",
        "................",
    ],
    "FORGE": [
        "................",
        "................",
        "....iiiiiiii....",
        "..iiiiiiiiiiii..",
        "..iiiiiiiiiiii..",
        "...jjjjjjjjjj...",
        ".....jjjjjj.....",
        "......jjjj......",
        "......jjjj......",
        ".....jjjjjj.....",
        "....jjjjjjjj....",
        "...jjjjjjjjjj...",
        "................",
        "......rrrr......",
        ".......rr.......",
        "................",
    ],
    "REST": [
        "................",
        ".......g........",
        "......rgr.......",
        "......rgr.......",
        ".....rrgrr......",
        ".....rrgrr......",
        "....rrrrrrr.....",
        "....rrrrrrr.....",
        ".....rrrrr......",
        "................",
        "..ee........ee..",
        "...eee....eee...",
        ".....eeeeee.....",
        "..eeeeeeeeeee...",
        "................",
        "................",
    ],
    "BOSS": [
        "................",
        "..iiiiiiiiiiii..",
        ".iiiiiiiiiiiiii.",
        ".iigggiiigggii..",
        ".iigggiiigggii..",
        ".iiiiiiiiiiiiii.",
        "..bbbbbbbbbbbb..",
        "..b.b.b.b.b.b...",
        "..rrrrrrrrrrrr..",
        "..b.b.b.b.b.b...",
        "..bbbbbbbbbbbb..",
        "...iiiiiiiiii...",
        "....iiiiiiii....",
        "................",
        "................",
        "................",
    ],
    "MYSTERY": [
        "................",
        ".....dddddd.....",
        "....dddddddd....",
        "...dddd..dddd...",
        "...ddd....ddd...",
        "..........ddd...",
        "........dddd....",
        ".......dddd.....",
        "......dddd......",
        "......ddd.......",
        "......ddd.......",
        "................",
        "......ddd.......",
        "......ddd.......",
        "................",
        "................",
    ],
}

SLOT_ICONS: dict[str, list[str]] = {
    # Colour blind rule (UI_GUIDE section 2.4 / 6.2): the six slot types must
    # differ in SHAPE, not only in colour. Verified as silhouettes - fill each
    # icon black and no two are confusable:
    #   PLAIN  filled square      flat top, vertical sides, no point
    #   FIRE   triangle           tapers all the way to a single pixel
    #   MIRROR rhombus split in two   the only icon with a gap down the middle
    #   ANVIL  pentagon           pointed top over vertical sides
    #   CHARGE filled circle      no corners, solid
    #   VOID   ring               no corners, hollow
    # Two pairs share a family on purpose (square/pentagon, circle/ring) but
    # each pair differs on a feature that survives a 16 px silhouette: a point
    # and a hole.
    "PLAIN": [
        "................",
        "................",
        "................",
        "...dddddddddd...",
        "...dddddddddd...",
        "...dddddddddd...",
        "...dddddddddd...",
        "...dddddddddd...",
        "...dddddddddd...",
        "...dddddddddd...",
        "...dddddddddd...",
        "...dddddddddd...",
        "...dddddddddd...",
        "................",
        "................",
        "................",
    ],
    "FIRE": [
        "................",
        ".......rr.......",
        ".......rr.......",
        "......rrrr......",
        "......rrrr......",
        ".....rrrrrr.....",
        ".....rrrrrr.....",
        "....rrrrrrrr....",
        "....rrrrrrrr....",
        "...rrrrrrrrrr...",
        "...rrrrrrrrrr...",
        "..rrrrrrrrrrrr..",
        "..rrrrrrrrrrrr..",
        ".rrrrrrrrrrrrrr.",
        "................",
        "................",
    ],
    "MIRROR": [
        "................",
        ".......f.f......",
        "......ff.ff.....",
        ".....fff.fff....",
        "....ffff.ffff...",
        "...fffff.fffff..",
        "..ffffff.ffffff.",
        "..ffffff.ffffff.",
        "..ffffff.ffffff.",
        "...fffff.fffff..",
        "....ffff.ffff...",
        ".....fff.fff....",
        "......ff.ff.....",
        ".......f.f......",
        "................",
        "................",
    ],
    "ANVIL": [
        "................",
        "................",
        "......ssss......",
        ".....ssssss.....",
        "...ssssssssss...",
        "..ssssssssssss..",
        "..ssssssssssss..",
        "..ssssssssssss..",
        "..ssssssssssss..",
        "..ssssssssssss..",
        "..ssssssssssss..",
        "..ssssssssssss..",
        "..ssssssssssss..",
        "..ssssssssssss..",
        "................",
        "................",
    ],
    "CHARGE": [
        "................",
        ".....gggggg.....",
        "...gggggggggg...",
        "..gggggggggggg..",
        "..gggggggggggg..",
        ".gggggggggggggg.",
        ".gggggggggggggg.",
        ".gggggggggggggg.",
        ".gggggggggggggg.",
        ".gggggggggggggg.",
        ".gggggggggggggg.",
        "..gggggggggggg..",
        "..gggggggggggg..",
        "...gggggggggg...",
        ".....gggggg.....",
        "................",
    ],
    "VOID": [
        "................",
        ".....kkkkkk.....",
        "...kk......kk...",
        "..kk........kk..",
        "..k..........k..",
        ".kk..........kk.",
        ".k............k.",
        ".k............k.",
        ".k............k.",
        ".k............k.",
        ".kk..........kk.",
        "..k..........k..",
        "..kk........kk..",
        "...kk......kk...",
        ".....kkkkkk.....",
        "................",
    ],
}

# --- UI icons for combat v2 and the tutorial (16x16) -----------------------
# COMBAT_READABILITY.md section 9 asks for armour and attack; M2.5 adds help,
# charge, overflow and the tutorial pointer. Same colour blind rule as the slot
# icons: fill each one black and no two silhouettes are confusable.
#   ARMOR    shield, flat top, pointed bottom
#   ATTACK   sword, diagonal, cross guard
#   HELP     question mark, the only icon with a detached dot
#   CHARGE   bank pill with a rising stack, flat bottom
#   OVERFLOW elbow arrow: right, then down into the next target
#   TUTORIAL_POINTER  hand drawn chalk arrow, points DOWN at 0 deg

UI_ICONS: dict[str, list[str]] = {
    # Rustning. Shield, not the pentagon - the pentagon means Ward (section 1.1
    # of COMBAT_READABILITY: one glyph, two meanings, was rated 1/10).
    "ARMOR": [
        "................",
        "..ssssssssssss..",
        "..ssssssssssss..",
        "..siiiiiiiiiis..",
        "..siiiiiiiiiis..",
        "..siiiiiiiiiis..",
        "..siiiiiiiiiis..",
        "..siiiiiiiiiis..",
        "...siiiiiiiis...",
        "...siiiiiiiis...",
        "....siiiiiis....",
        ".....siiiiis....",
        "......siiis.....",
        ".......sis......",
        "........s.......",
        "................",
    ],
    # Attack, fiendens intent. A sword pointing down-left at the player: the
    # verb is "Attacks you", so the blade has to point somewhere.
    "ATTACK": [
        "..............b.",
        ".............bb.",
        "............bbb.",
        "...........bbb..",
        "..........bbb...",
        ".........bbb....",
        "....j...bbb.....",
        "....jj.bbb......",
        "...jjjbbb.......",
        "..jjjjbb........",
        "...bbbbb........",
        "..bbb.jjj.......",
        ".bb....jjj......",
        "bb......jjj.....",
        "b........jj.....",
        "................",
    ],
    # Hjalp. Gold on dark, 48 dp touch target, top bar (section 6).
    "HELP": [
        "................",
        "....gggggg......",
        "...gggggggg.....",
        "..ggg....ggg....",
        "..gg......ggg...",
        "..........ggg...",
        ".........ggg....",
        "........ggg.....",
        ".......ggg......",
        "......ggg.......",
        "......ggg.......",
        "......ggg.......",
        "................",
        "......ggg.......",
        "......ggg.......",
        "................",
    ],
    # Laddning i HUD:en. A bank pill with a stack rising inside it - reads as
    # "stored", where slot_charge.png (a filled circle) reads as "this slot".
    "CHARGE": [
        "................",
        "................",
        ".gg.........gg..",
        ".gg.........gg..",
        ".gg.......gg.gg.",
        ".gg.......gg.gg.",
        ".gg.......gg.gg.",
        ".gg....gg.gg.gg.",
        ".gg....gg.gg.gg.",
        ".gg....gg.gg.gg.",
        ".gg.gg.gg.gg.gg.",
        ".gg.gg.gg.gg.gg.",
        ".gg.gg.gg.gg.gg.",
        ".gggggggggggggg.",
        ".gggggggggggggg.",
        "................",
    ],
    # Spill / overflod. The elbow arrow used between enemy columns: damage that
    # did not fit rolls on to the next target.
    "OVERFLOW": [
        "................",
        ".cc.............",
        ".cc.............",
        ".cc.............",
        ".cc.............",
        ".cccccccccc.....",
        ".cccccccccc.....",
        "..........cc....",
        "..........cc....",
        "......c...cc....",
        ".....cc...cc....",
        "....ccccccccc...",
        ".....ccccccc....",
        "......ccccc.....",
        ".......ccc......",
        "........c.......",
    ],
    # Tutorial-pekare, varning 0. Chalk arrow with a deliberate wobble so it
    # reads as drawn, not as a UI glyph. Points DOWN unrotated; the engine
    # rotates in 90 deg steps for the other three directions.
    "TUTORIAL_POINTER": [
        ".......cc.......",
        "......cccc......",
        "......cccc......",
        "......cccc......",
        ".......ccc......",
        ".......ccc......",
        ".......ccc......",
        "......cccc......",
        "..c...cccc...c..",
        "..cc..cccc..cc..",
        "...ccccccccccc..",
        "....ccccccccc...",
        ".....ccccccc....",
        "......ccccc.....",
        ".......ccc......",
        "........c.......",
    ],
    # Riktningsknapparnas tre pilar (UI_GUIDE 17.4). Samma formkod som glyferna
    # de ersatter - vanster, fram, hoger - men som sprites, sa att de ritas
    # likadant i webbexporten som pa Android (BACKLOG: tofu-glyfer).
    "ARROW_LEFT": [
        "................",
        ".............c..",
        "...........ccc..",
        ".........ccccc..",
        ".......ccccccc..",
        ".....ccccccccc..",
        "...ccccccccccc..",
        ".ccccccccccccc..",
        ".ccccccccccccc..",
        "...ccccccccccc..",
        ".....ccccccccc..",
        ".......ccccccc..",
        ".........ccccc..",
        "...........ccc..",
        ".............c..",
        "................",
    ],
    "ARROW_FORWARD": [
        "................",
        ".......cc.......",
        ".......cc.......",
        "......cccc......",
        "......cccc......",
        ".....cccccc.....",
        ".....cccccc.....",
        "....cccccccc....",
        "....cccccccc....",
        "...cccccccccc...",
        "...cccccccccc...",
        "..cccccccccccc..",
        "..cccccccccccc..",
        ".cccccccccccccc.",
        "................",
        "................",
    ],
    "ARROW_RIGHT": [
        "................",
        "..c.............",
        "..ccc...........",
        "..ccccc.........",
        "..ccccccc.......",
        "..ccccccccc.....",
        "..ccccccccccc...",
        "..ccccccccccccc.",
        "..ccccccccccccc.",
        "..ccccccccccc...",
        "..ccccccccc.....",
        "..ccccccc.......",
        "..ccccc.........",
        "..ccc...........",
        "..c.............",
        "................",
    ],
    # Character sheet-knappen. Ram + portrattruta + tva textrader: samma sak
    # knappen oppnar, dar glyfen 0x25EB bara var en delad fyrkant.
    "SHEET": [
        "................",
        ".dddddddddddddd.",
        ".d............d.",
        ".d.ddd..ddddd.d.",
        ".d.ddd..ddddd.d.",
        ".d.ddd........d.",
        ".d.ddd..ddddd.d.",
        ".d.ddd..ddddd.d.",
        ".d............d.",
        ".d.dddddddddd.d.",
        ".d............d.",
        ".d.dddddddddd.d.",
        ".d............d.",
        ".dddddddddddddd.",
        "................",
        "................",
    ],
    # Installningar. Atta kuggar och ett nav; ersatter kugghjulsglyfen 0x2699,
    # som ingen av de buntade fonterna har.
    "SETTINGS": [
        "................",
        ".....d....d.....",
        "....ddd..ddd....",
        "....dddddddd....",
        "..dddddddddddd..",
        "..dddd....dddd..",
        ".ddd........ddd.",
        ".ddd........ddd.",
        ".ddd........ddd.",
        ".ddd........ddd.",
        "..dddd....dddd..",
        "..dddddddddddd..",
        "....dddddddd....",
        "....ddd..ddd....",
        ".....d....d.....",
        "................",
    ],
    # Angra. Pil at vanster med kroken nedat till hoger, som glyfen 0x21A9.
    "UNDO": [
        "................",
        "................",
        "................",
        "......d.........",
        ".....dd.........",
        "....ddd.........",
        "...ddddddddd....",
        "..dddddddddddd..",
        "...ddddddddd.dd.",
        "....ddd......dd.",
        ".....dd......dd.",
        "......d......dd.",
        ".............dd.",
        "............ddd.",
        "................",
        "................",
    ],
}


# --- Environment (side-scroll march, floor 1) ------------------------------


def parallax_far() -> Canvas:
    """Layer 0, speed 0.15: slag ridges. Silhouette only (Kingdom rule)."""
    cv = Canvas(320, 120)
    peaks = [(0, 62), (38, 44), (76, 70), (118, 38), (160, 58), (204, 30), (248, 66), (292, 48), (320, 62)]
    for i in range(len(peaks) - 1):
        x0, y0 = peaks[i]
        x1, y1 = peaks[i + 1]
        for x in range(x0, x1):
            t = (x - x0) / max(x1 - x0, 1)
            y = int(y0 + (y1 - y0) * t)
            cv.rect(x, y, 1, 120 - y, color("slate"))
            cv.set(x, y, color("line"))
    # cold vents
    for vx in (56, 140, 226, 300):
        for i in range(10):
            cv.set(vx + (i % 3) - 1, 40 - i * 3, color("line", 90))
    return cv


def parallax_mid() -> Canvas:
    """Layer 1, speed 0.45: broken pillars and pipework."""
    cv = Canvas(320, 120)
    for px, h, w in ((14, 70, 12), (72, 52, 9), (126, 84, 14), (188, 46, 10), (236, 66, 12), (288, 58, 11)):
        top = 120 - h
        cv.rect(px, top, w, h, color("raised"))
        cv.rect(px, top, 1, h, color("line"))
        cv.rect(px + w - 1, top, 1, h, color("pit"))
        for band in range(top + 6, 120, 11):
            cv.hline(px, band, w, color("line"))
        # broken cap
        for i in range(4):
            cv.hline(px + i, top - 1 - i, w - i * 2, color("raised"))
    # a hanging chain, the only vertical motion cue
    for cx in (100, 210):
        for i in range(0, 34, 2):
            cv.set(cx, i, color("line"))
            cv.set(cx + 1, i + 1, color("line"))
    return cv


def parallax_near() -> Canvas:
    """Layer 2, speed 1.2: foreground debris, drawn dark so the hero pops."""
    cv = Canvas(320, 64)
    for bx, bw, bh in ((8, 22, 12), (60, 14, 8), (104, 30, 16), (168, 18, 10), (214, 26, 14), (272, 20, 9)):
        top = 64 - bh
        cv.rect(bx, top, bw, bh, color("pit"))
        cv.hline(bx + 1, top, bw - 2, color("slate"))
    for sx in range(0, 320, 7):
        cv.set(sx, 62, color("pit"))
        cv.set(sx + 3, 63, color("slate"))
    return cv


def floor_tile() -> Canvas:
    """32x32 tileable slag floor for the march strip."""
    cv = Canvas(32, 32)
    cv.rect(0, 0, 32, 32, color("raised"))
    cv.hline(0, 0, 32, color("line"))
    for i in range(3):
        cv.hline(0, 10 + i * 8, 32, color("slate"))
    for gx, gy in ((5, 4), (19, 6), (11, 14), (26, 18), (3, 24), (17, 27), (29, 12)):
        cv.set(gx, gy, color("pit"))
        cv.set(gx + 1, gy, color("line"))
    return cv


# --- Corridor: first person tile textures (M2.5 presentation shift) --------
# docs/research/05_fps_korridor.md section 1: the whole floor is ONE ArrayMesh
# with ONE material, so the corridor needs 4-5 tileable 64x64 textures and
# nothing else. Every texture below wraps on both axes (all coordinates go
# through % 64), which is the hard requirement - a seam is visible on every
# single wall quad at once.

CORRIDOR_TILE: int = 64


def _grit(cv: Canvas, seed: int, amount: int, tokens: tuple[str, ...]) -> None:
    """Deterministic speckle that wraps: coordinates are taken modulo the tile."""
    for i in range(amount):
        x = int(_hash01(i, seed, 11) * cv.width) % cv.width
        y = int(_hash01(seed, i, 23) * cv.height) % cv.height
        token = tokens[i % len(tokens)]
        cv.set(x, y, color(token))


def corridor_wall() -> Canvas:
    """64x64 tileable wall: two courses of slag brick, lit from the upper left.

    Brick size 32x16 with a half-brick offset on every other course, so the
    tile repeats at 64 without the eye catching the grid. Mortar is the pit
    colour, which is also the fog colour - a wall that fades out never shows a
    seam against the darkness.
    """
    cv = Canvas(CORRIDOR_TILE, CORRIDOR_TILE)
    cv.rect(0, 0, CORRIDOR_TILE, CORRIDOR_TILE, color("iron1"))
    for course in range(4):
        y = course * 16
        offset = 0 if course % 2 == 0 else 16
        for brick in range(2):
            x = (brick * 32 + offset) % CORRIDOR_TILE
            for yy in range(1, 15):
                for xx in range(1, 31):
                    px = (x + xx) % CORRIDOR_TILE
                    py = y + yy
                    n = _hash01(px, py, 7 + course)
                    token = "iron2"
                    if n > 0.86:
                        token = "iron3"
                    elif n < 0.12:
                        token = "iron1"
                    cv.set(px, py, color(token))
            # lit top edge and dark bottom edge: the only shading a wall needs
            for xx in range(1, 31):
                px = (x + xx) % CORRIDOR_TILE
                cv.set(px, y + 1, color("iron3"))
                cv.set(px, y + 14, color("iron1"))
            cv.set((x + 1) % CORRIDOR_TILE, y + 1, color("iron4"))
    # damp streaks: three vertical runs, so the wall has a "down" direction
    for sx, sh in ((9, 40), (37, 26), (54, 34)):
        for i in range(sh):
            y = (i + sx) % CORRIDOR_TILE
            cv.set(sx, y, color("iron1"))
            if i % 3 == 0:
                cv.set(sx + 1, y, color("iron2"))
    _grit(cv, 3, 90, ("iron1", "iron3", "chalk500@0.25"))
    return cv


def corridor_floor() -> Canvas:
    """64x64 tileable floor: four flagstones with cracks and pit grit."""
    cv = Canvas(CORRIDOR_TILE, CORRIDOR_TILE)
    cv.rect(0, 0, CORRIDOR_TILE, CORRIDOR_TILE, color("iron1"))
    for qy in range(2):
        for qx in range(2):
            ox, oy = qx * 32, qy * 32
            for yy in range(1, 31):
                for xx in range(1, 31):
                    n = _hash01(ox + xx, oy + yy, 17)
                    token = "iron2" if n > 0.2 else "iron1"
                    if n > 0.93:
                        token = "iron3"
                    cv.set(ox + xx, oy + yy, color(token))
            for xx in range(1, 31):
                cv.set(ox + xx, oy + 1, color("iron3"))
            # a crack that never reaches the tile edge, so it cannot make a seam
            cx = ox + 8 + qx * 6
            for i in range(14):
                cv.set(cx + (i % 3), oy + 6 + i, color("iron1"))
    _grit(cv, 5, 120, ("iron1", "iron3", "chalk500@0.2"))
    return cv


def corridor_ceiling() -> Canvas:
    """64x64 tileable ceiling: rough rock, darker than the wall, no structure.

    The ceiling is the first surface to disappear into the fog, so it is the
    cheapest place to save contrast: no bricks, no edges, only noise.
    """
    cv = Canvas(CORRIDOR_TILE, CORRIDOR_TILE)
    for y in range(CORRIDOR_TILE):
        for x in range(CORRIDOR_TILE):
            n = _hash01(x, y, 29) * 0.6 + _hash01(x // 4, y // 4, 31) * 0.4
            token = "iron1"
            if n > 0.78:
                token = "iron2"
            elif n < 0.18:
                token = "out"
            cv.set(x, y, color(token))
    # two rusted tie rods across the ceiling, the only readable structure
    for ry in (14, 46):
        for x in range(CORRIDOR_TILE):
            cv.set(x, ry, color("rust1"))
            cv.set(x, ry + 1, color("iron1"))
            if x % 16 == 3:
                cv.set(x, ry, color("rust2"))
    return cv


def corridor_door() -> Canvas:
    """64x64 boss door. Not tileable - one quad, one door (CORRIDOR_DESIGN 3.3).

    Slagjaw's door bulges: the art is drawn so the centre plates read as a
    chest, and the engine breathes it with a 1.4 s scale tween. No animation
    frames, because the breath has to be slow enough that frames would be waste.
    """
    cv = Canvas(CORRIDOR_TILE, CORRIDOR_TILE)
    # frame
    cv.rect(0, 0, CORRIDOR_TILE, CORRIDOR_TILE, color("iron1"))
    cv.rect(4, 2, 56, 62, color("iron2"))
    for i in range(3):
        cv.hline(4 + i, 2 + i, 56 - i * 2, color("iron3"))
    # two leaves with a seam down the middle
    cv.vline(31, 4, 60, color("out"))
    cv.vline(32, 4, 60, color("iron1"))
    for plate_y in (8, 26, 44):
        for leaf_x in (7, 34):
            plate(cv, leaf_x, plate_y, 23, 14, IRON)
            for rx in range(leaf_x + 2, leaf_x + 22, 6):
                cv.set(rx, plate_y + 2, color("shield"))
                cv.set(rx, plate_y + 11, color("iron1"))
    # jaw handles: two rings that read as teeth at a distance
    for hx in (24, 39):
        ellipse(cv, hx, 34, 4.0, 4.0, ("iron1", "iron3", "iron4"))
        ellipse(cv, hx, 34, 2.0, 2.0, ("out", "out", "out"), flat=True)
    # chalk: somebody counted the ones who opened it
    for i, mx in enumerate((10, 13, 16, 19)):
        cv.vline(mx, 52 - (i % 2), 7, color("chalk300"))
    for i in range(10):
        cv.set(9 + i, 58 - int(i * 0.5), color("chalk100"))
    return cv


def corridor_torch() -> Canvas:
    """16x32 wall sconce, two frames side by side (32x32): the only warm light.

    Used on chamber walls and as the elite's early warning (CORRIDOR_DESIGN
    3.2). Billboarded in 3D, so it needs no perspective versions.
    """
    out = Canvas(32, 32)
    for f in range(2):
        cv = Canvas(16, 32)
        cv.rect(6, 18, 4, 12, color("iron2"))          # bracket
        cv.rect(5, 16, 6, 3, color("iron3"))
        cv.hline(5, 16, 6, color("iron4"))
        flare = 0 if f == 0 else 1
        for i, w in enumerate((5, 5, 4, 3, 2, 1)):
            y = 15 - i - flare
            cv.rect(8 - w // 2, y, w, 1, color("rust4" if i < 2 else "rust5"))
        cv.rect(6, 12 - flare, 4, 4, color("rust3"))
        cv.set(8, 13 - flare, color("charge"))
        cv.set(7 + f, 8 - flare, color("rust5"))       # a spark
        out.blit(cv.outline(color("out")), f * 16, 0)
    return out


# --- Main ------------------------------------------------------------------


def generate(root: Path) -> list[tuple[str, str]]:
    """Write every sprite. Returns (path, notes) for the license registry."""
    made: list[tuple[str, str]] = []

    # enemies: row 0 idle x4, row 1 death x3 (+1 repeat)
    for enemy_id, (fn, cell, filename) in ENEMIES.items():
        out = build_enemy_sheet(fn, cell, enemy_id)
        path = ART / "enemies" / filename
        write_png(root / path, out)
        made.append((path.as_posix(), f"{enemy_id} idle x4 + death x3, {cell}x{cell}, hframes 4 vframes 2"))

    # hero paperdoll layers
    for layer, (fn, note) in HERO_LAYERS.items():
        out = build_hero_sheet(fn)
        path = ART / "hero" / f"smith_{layer}.png"
        write_png(root / path, out)
        made.append((path.as_posix(), f"Smeden paperdoll {layer} ({note}), 48x48 8x4"))

    # relic / node / slot icons
    for relic_id, rows in RELIC_ICONS.items():
        path = ART / "items" / f"relic_{relic_id.lower()}.png"
        write_png(root / path, icon(rows))
        made.append((path.as_posix(), f"Relikikon {relic_id}, 16x16"))
    for node_id, rows in NODE_ICONS.items():
        path = ART / "ui" / f"node_{node_id.lower()}.png"
        write_png(root / path, icon(rows))
        made.append((path.as_posix(), f"Nodikon {node_id}, 16x16"))
    for slot_id, rows in SLOT_ICONS.items():
        path = ART / "ui" / f"slot_{slot_id.lower()}.png"
        write_png(root / path, icon(rows))
        made.append((path.as_posix(), f"Slotikon {slot_id}, 16x16"))
    for icon_id, rows in UI_ICONS.items():
        path = ART / "ui" / f"icon_{icon_id.lower()}.png"
        write_png(root / path, icon(rows))
        made.append((path.as_posix(), f"UI-ikon {icon_id}, 16x16, stridsskarm v2"))

    # hero portraits for the choose-your-Smith screen
    for variant in ("a", "b"):
        path = ART / "hero" / f"smith_portrait_{variant}.png"
        write_png(root / path, smith_portrait(variant))
        made.append((path.as_posix(), f"Smeden portratt variant {variant.upper()}, 96x96, konsvalskarmen"))

    # environment
    for name, fn, note in (
        ("parallax_far", parallax_far, "parallaxlager 0, hastighet 0,15, 320x120 kaklingsbar"),
        ("parallax_mid", parallax_mid, "parallaxlager 1, hastighet 0,45, 320x120 kaklingsbar"),
        ("parallax_near", parallax_near, "parallaxlager 2, hastighet 1,2, 320x64 kaklingsbar"),
        ("floor_tile", floor_tile, "golvtile marschremsa, 32x32 kaklingsbar"),
    ):
        path = ART / "env" / f"floor1_{name}.png" if name != "floor_tile" else ART / "env" / "floor1_tile.png"
        write_png(root / path, fn())
        made.append((path.as_posix(), note))

    # corridor (first person): tileable 64x64 textures + door + torch
    for filename, fn, note in (
        ("wall_stone.png", corridor_wall, "korridorvagg 64x64 kaklingsbar, slaggtegel"),
        ("floor_stone.png", corridor_floor, "korridorgolv 64x64 kaklingsbart, flisor"),
        ("ceiling_stone.png", corridor_ceiling, "korridortak 64x64 kaklingsbart, raberg + dragstag"),
        ("door_boss.png", corridor_door, "bossdorr 64x64, en kvad (ej kaklingsbar)"),
        ("torch.png", corridor_torch, "vaggfackla 16x32, 2 frames (32x32), enda varma ljuset"),
    ):
        path = ART / "env" / "corridor" / filename
        write_png(root / path, fn())
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
            print(f"{path},tools/gen_pixel_assets.py,PIPWRECK UI,own-work,,2026-09-21,{note}")
    else:
        for path, note in made:
            print(f"wrote {path}  ({note})")
        print(f"{len(made)} sprites")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

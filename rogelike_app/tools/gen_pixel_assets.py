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


def hero_body(row: int, f: int) -> Canvas:
    """Base layer: legs, apron, torso, arms, head, beard. Faces right."""
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


HERO_LAYERS: dict[str, tuple] = {
    "body": (hero_body, "bas-kropp, alltid synlig"),
    "weapon_hammer": (hero_weapon_hammer, "vapen A"),
    "weapon_tongs": (hero_weapon_tongs, "vapen B"),
    "helm_iron": (hero_helm, "hjalm"),
    "cape_ember": (hero_cape, "kappa"),
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
    "PLAIN": [
        "................",
        "................",
        "...dddddddddd...",
        "...d........d...",
        "...d........d...",
        "...d........d...",
        "...d........d...",
        "...d........d...",
        "...d........d...",
        "...d........d...",
        "...d........d...",
        "...dddddddddd...",
        "................",
        "................",
        "................",
        "................",
    ],
    "FIRE": [
        "................",
        ".......r........",
        ".......rr.......",
        "......rrr.......",
        "......rrrr......",
        ".....rrrrr......",
        ".....rrrrrr.....",
        "....rrrrrrr.....",
        "....rrrrrrrr....",
        "...rrrrrrrrr....",
        "...rrrrrrrrrr...",
        "..rrrrrrrrrrr...",
        "..rrrrrrrrrrrr..",
        ".rrrrrrrrrrrrr..",
        "................",
        "................",
    ],
    "MIRROR": [
        "................",
        ".......ff.......",
        "......ffff......",
        ".....ff..ff.....",
        "....ff....ff....",
        "...ff......ff...",
        "..ff........ff..",
        ".ff..........ff.",
        "..ff........ff..",
        "...ff......ff...",
        "....ff....ff....",
        ".....ff..ff.....",
        "......ffff......",
        ".......ff.......",
        "................",
        "................",
    ],
    "ANVIL": [
        "................",
        "....ssssssss....",
        "...ssssssssss...",
        "..ssssssssssss..",
        "..ssssssssssss..",
        "..ssssssssssss..",
        "..ssssssssssss..",
        "..ssssssssssss..",
        "..ssssssssssss..",
        "...ssssssssss...",
        "....ssssssss....",
        "................",
        "................",
        "................",
        "................",
        "................",
    ],
    "CHARGE": [
        "................",
        ".....gggggg.....",
        "...gg......gg...",
        "..g..........g..",
        "..g..........g..",
        ".g............g.",
        ".g.....gg.....g.",
        ".g....gggg....g.",
        ".g...gggggg...g.",
        ".g..gggggggg..g.",
        "..g.gggggggg.g..",
        "..g.gggggggg.g..",
        "...gggggggggg...",
        ".....gggggg.....",
        "................",
        "................",
    ],
    "VOID": [
        "................",
        "..kkkkkkkkkkkk..",
        "..kk........kk..",
        "..k.k......k.k..",
        "..k..k....k..k..",
        "..k...k..k...k..",
        "..k....kk....k..",
        "..k....kk....k..",
        "..k...k..k...k..",
        "..k..k....k..k..",
        "..k.k......k.k..",
        "..kk........kk..",
        "..kkkkkkkkkkkk..",
        "................",
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


# --- Main ------------------------------------------------------------------


def generate(root: Path) -> list[tuple[str, str]]:
    """Write every sprite. Returns (path, notes) for the license registry."""
    made: list[tuple[str, str]] = []

    # enemies
    for enemy_id, (fn, cell, filename) in ENEMIES.items():
        frames = [fn(f) for f in range(4)]
        out = sheet(frames, cell, cell)
        path = ART / "enemies" / filename
        write_png(root / path, out)
        made.append((path.as_posix(), f"{enemy_id} idle, {cell}x{cell}, 4 frames"))

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

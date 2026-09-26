#!/usr/bin/env python3
"""Procedural UI icon set for Wickwright (Art Bible §10: flat shape, 2-tone gradient, dark outline,
one idea per icon, no text). Icons are light-grey masks with a baked dark outline so the game can
tint them with any colour (rarity, class, element) via modulate. Output: ../icons/<name>.png (128 px).

Run:  python3 assets/ui/_gen/gen_icons.py   (then let Godot import the PNGs)
All shapes are original geometry drawn here - no third-party art.
"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter, ImageChops

S = 512          # working canvas
OUT = 128        # output size
U = S / 100.0    # 1 unit = 1 % of the canvas
OUTLINE = 15     # outline radius in canvas px
HERE = os.path.dirname(os.path.abspath(__file__))
DEST = os.path.join(HERE, "..", "icons")


def P(x, y):
    return (x * U, y * U)


class Icon:
    def __init__(self):
        self.body = Image.new("L", (S, S), 0)
        self.detail = Image.new("L", (S, S), 0)
        self.shine = Image.new("L", (S, S), 0)
        self.b = ImageDraw.Draw(self.body)
        self.d = ImageDraw.Draw(self.detail)
        self.s = ImageDraw.Draw(self.shine)

    # --- primitives (units 0..100) ------------------------------------------------------------
    def _dr(self, layer):
        return {"b": self.b, "d": self.d, "s": self.s}[layer]

    def poly(self, pts, layer="b", fill=255):
        self._dr(layer).polygon([P(x, y) for x, y in pts], fill=fill)

    def circle(self, cx, cy, r, layer="b", fill=255):
        self._dr(layer).ellipse([P(cx - r, cy - r), P(cx + r, cy + r)], fill=fill)

    def ellipse(self, x0, y0, x1, y1, layer="b", fill=255):
        self._dr(layer).ellipse([P(x0, y0), P(x1, y1)], fill=fill)

    def rect(self, x0, y0, x1, y1, r=0, layer="b", fill=255):
        self._dr(layer).rounded_rectangle([P(x0, y0), P(x1, y1)], radius=r * U, fill=fill)

    def line(self, pts, w, layer="b", fill=255):
        pts = [P(x, y) for x, y in pts]
        self._dr(layer).line(pts, fill=fill, width=int(w * U), joint="curve")
        for p in (pts[0], pts[-1]):
            rr = w * U / 2
            self._dr(layer).ellipse([p[0] - rr, p[1] - rr, p[0] + rr, p[1] + rr], fill=fill)

    def arc(self, cx, cy, r, a0, a1, w, layer="b", fill=255):
        pts = []
        steps = max(8, int(abs(a1 - a0) / 6))
        for i in range(steps + 1):
            a = math.radians(a0 + (a1 - a0) * i / steps)
            pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
        self.line(pts, w, layer, fill)

    def ring(self, cx, cy, r, w, layer="b"):
        self.circle(cx, cy, r + w / 2, layer)
        self.circle(cx, cy, r - w / 2, layer, fill=0)

    def star(self, cx, cy, r1, r2, n=5, rot=-90, layer="b", fill=255):
        pts = []
        for i in range(n * 2):
            r = r1 if i % 2 == 0 else r2
            a = math.radians(rot + i * 180.0 / n)
            pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
        self.poly(pts, layer, fill)

    def cut(self, fn):
        """Run fn with body fill=0 (holes)."""
        fn(0)

    # --- render ------------------------------------------------------------------------------
    def render(self, path):
        body = self.body
        # dilate: blur + threshold → rounded outline
        dil = body.filter(ImageFilter.GaussianBlur(OUTLINE * 0.55)).point(lambda v: 255 if v > 18 else int(v * 14))
        dil = ImageChops.lighter(dil, body)
        # vertical 2-tone gradient for the body (light top → darker bottom)
        grad = Image.new("L", (1, S))
        for y in range(S):
            t = y / S
            grad.putpixel((0, y), int(255 * (1.0 - 0.30 * t)))
        grad = grad.resize((S, S))
        rgba = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        outline_col = Image.new("RGBA", (S, S), (22, 14, 26, 255))
        rgba.paste(outline_col, (0, 0), dil)
        body_rgb = Image.merge("RGBA", (grad, grad, grad, Image.new("L", (S, S), 255)))
        rgba.paste(body_rgb, (0, 0), body)
        det = ImageChops.multiply(self.detail, body)
        det_col = Image.new("RGBA", (S, S), (70, 62, 80, 255))
        rgba.paste(det_col, (0, 0), det)
        sh = ImageChops.multiply(self.shine, body)
        rgba.paste(Image.new("RGBA", (S, S), (255, 255, 255, 255)), (0, 0), sh)
        rgba = rgba.resize((OUT, OUT), Image.LANCZOS)
        rgba.save(path)


ICONS = {}


def icon(name):
    def deco(fn):
        ICONS[name] = fn
        return fn
    return deco


# ============================================================ weapons & slots
@icon("sword")
def _(i):
    i.poly([(72, 10), (84, 12), (86, 24), (40, 70), (30, 60)])
    i.line([(22, 56), (44, 78)], 8)
    i.line([(34, 66), (18, 82)], 8)
    i.circle(15, 85, 6)
    i.line([(76, 18), (40, 58)], 3, "d")


@icon("axe")
def _(i):
    i.line([(30, 88), (66, 22)], 8)
    i.poly([(52, 16), (80, 8), (90, 30), (84, 52), (64, 40)])
    i.line([(58, 28), (80, 40)], 3, "d")


@icon("axe2h")
def _(i):
    i.line([(50, 92), (50, 10)], 8)
    i.poly([(50, 18), (82, 6), (90, 30), (82, 50), (50, 40)])
    i.poly([(50, 18), (18, 6), (10, 30), (18, 50), (50, 40)])


@icon("mace")
def _(i):
    i.line([(26, 88), (58, 40)], 9)
    i.circle(66, 30, 18)
    for a in range(0, 360, 60):
        x, y = 66 + math.cos(math.radians(a)) * 22, 30 + math.sin(math.radians(a)) * 22
        i.circle(x, y, 6)


@icon("staff")
def _(i):
    i.line([(28, 92), (62, 30)], 8)
    i.ring(68, 22, 14, 7)
    i.star(68, 22, 9, 4, 4, -90)


@icon("wand")
def _(i):
    i.line([(22, 84), (60, 42)], 8)
    i.star(70, 30, 22, 9, 5)


@icon("dagger")
def _(i):
    i.poly([(56, 44), (82, 10), (86, 14), (64, 52)])
    i.line([(40, 44), (68, 64)], 8)
    i.line([(54, 56), (30, 82)], 9)
    i.circle(26, 86, 6)


@icon("crossbow")
def _(i):
    i.arc(50, 70, 40, 205, 335, 7)
    i.line([(50, 18), (50, 90)], 9)
    i.line([(16, 52), (84, 52)], 3, "b")
    i.poly([(50, 6), (58, 20), (42, 20)])


@icon("bow")
def _(i):
    i.arc(18, 50, 44, -62, 62, 8)
    i.line([(38, 11), (38, 89)], 3)
    i.line([(38, 50), (86, 50)], 5)
    i.poly([(92, 50), (80, 42), (80, 58)])


@icon("spear")
def _(i):
    i.line([(18, 88), (70, 30)], 7)
    i.poly([(64, 26), (90, 8), (76, 36)])


@icon("shield")
def _(i):
    i.poly([(50, 8), (86, 20), (82, 56), (50, 92), (18, 56), (14, 20)])
    i.poly([(50, 20), (74, 28), (71, 54), (50, 78)], "d")


@icon("tome")
def _(i):
    i.rect(18, 12, 82, 88, 6)
    i.rect(26, 12, 32, 88, 0, "d")
    i.star(58, 48, 14, 6, 4, -90, "d")


@icon("quiver")
def _(i):
    i.rect(32, 34, 66, 92, 8)
    for x in (38, 49, 60):
        i.line([(x, 36), (x + 6, 8)], 4)
        i.poly([(x + 6, 4), (x + 11, 14), (x + 1, 14)])


@icon("orb")
def _(i):
    i.circle(50, 44, 30)
    i.rect(34, 72, 66, 90, 4)
    i.circle(40, 34, 9, "s", 140)


@icon("head")
def _(i):
    i.poly([(18, 60), (20, 36), (34, 18), (50, 12), (66, 18), (80, 36), (82, 60), (82, 80), (60, 80), (60, 56), (40, 56), (40, 80), (18, 80)])
    i.rect(48, 20, 52, 50, 0, "d")


@icon("chest")
def _(i):
    i.poly([(30, 12), (42, 18), (58, 18), (70, 12), (90, 26), (82, 46), (74, 42), (74, 90), (26, 90), (26, 42), (18, 46), (10, 26)])
    i.line([(50, 26), (50, 86)], 3, "d")
    i.line([(34, 50), (66, 50)], 3, "d")


@icon("hands")
def _(i):
    i.rect(26, 40, 74, 78, 12)
    for k, x in enumerate((30, 42, 54, 66)):
        i.rect(x - 1, 12 + (4 if k in (0, 3) else 0), x + 9, 50, 5)
    i.poly([(26, 56), (12, 40), (18, 34), (32, 46)])
    i.rect(28, 76, 72, 92, 3)


@icon("legs")
def _(i):
    i.poly([(24, 10), (76, 10), (80, 90), (58, 90), (50, 36), (42, 90), (20, 90)])
    i.rect(24, 10, 76, 20, 0, "d")


@icon("feet")
def _(i):
    i.poly([(28, 8), (54, 8), (54, 56), (88, 66), (90, 86), (22, 86), (26, 56)])
    i.rect(22, 78, 90, 86, 0, "d")


@icon("belt")
def _(i):
    i.rect(6, 38, 94, 62, 6)
    i.rect(36, 30, 64, 70, 6)
    i.rect(42, 38, 58, 62, 3, "b", 0)


@icon("ring")
def _(i):
    i.ring(50, 58, 26, 11)
    i.poly([(50, 10), (64, 22), (50, 38), (36, 22)])


@icon("amulet")
def _(i):
    i.arc(50, 24, 30, 10, 170, 5)
    i.poly([(50, 44), (72, 62), (50, 92), (28, 62)])
    i.poly([(50, 54), (62, 64), (50, 80), (38, 64)], "d")


@icon("charm")
def _(i):
    for a in (-90, 0, 90, 180):
        x, y = 50 + math.cos(math.radians(a)) * 18, 44 + math.sin(math.radians(a)) * 18
        i.circle(x, y, 17)
    i.line([(50, 60), (60, 92)], 6)


@icon("main_hand")
def _(i):
    ICONS["sword"](i)


@icon("off_hand")
def _(i):
    ICONS["shield"](i)


# ============================================================ stats & elements
@icon("life")
def _(i):
    i.circle(33, 36, 22)
    i.circle(67, 36, 22)
    i.poly([(12, 44), (88, 44), (50, 90)])
    i.circle(30, 32, 7, "s", 120)


@icon("resource")
def _(i):
    i.poly([(50, 6), (78, 52), (22, 52)])
    i.circle(50, 62, 29)
    i.circle(40, 56, 7, "s", 120)


@icon("damage")
def _(i):
    ICONS["sword"](i)


@icon("armor")
def _(i):
    ICONS["shield"](i)


@icon("crit")
def _(i):
    i.star(50, 50, 46, 16, 8, -90)
    i.star(50, 50, 20, 8, 8, -67, "d")


@icon("speed")
def _(i):
    i.poly([(18, 20), (70, 28), (92, 50), (70, 72), (18, 80), (40, 50)])
    i.line([(6, 36), (26, 36)], 5)
    i.line([(6, 64), (26, 64)], 5)


@icon("attack_speed")
def _(i):
    i.poly([(60, 6), (26, 56), (48, 56), (38, 94), (76, 40), (54, 40)])


@icon("magic_find")
def _(i):
    ICONS["charm"](i)


@icon("gold")
def _(i):
    i.circle(50, 50, 40)
    i.ring(50, 50, 28, 5)
    i.star(50, 50, 14, 6, 4, -90, "d")


@icon("xp")
def _(i):
    i.star(50, 50, 46, 12, 4, -90)
    i.star(78, 20, 12, 4, 4, -90)


@icon("cooldown")
def _(i):
    i.rect(22, 8, 78, 16, 3)
    i.rect(22, 84, 78, 92, 3)
    i.poly([(28, 16), (72, 16), (54, 50), (72, 84), (28, 84), (46, 50)])
    i.poly([(36, 76), (64, 76), (50, 60)], "d")


@icon("might")
def _(i):
    i.rect(18, 30, 82, 74, 16)
    for x in (26, 42, 58):
        i.line([(x + 4, 34), (x + 4, 48)], 3, "d")
    i.rect(22, 70, 58, 92, 6)


@icon("agility")
def _(i):
    i.poly([(84, 8), (92, 18), (40, 76), (22, 70), (30, 52)])
    i.line([(18, 90), (40, 64)], 5)
    i.line([(80, 16), (32, 68)], 2, "d")


@icon("wisdom")
def _(i):
    i.poly([(6, 50), (28, 26), (50, 18), (72, 26), (94, 50), (72, 74), (50, 82), (28, 74)])
    i.circle(50, 50, 18, "b", 0)
    i.circle(50, 50, 11)


@icon("vitality")
def _(i):
    ICONS["life"](i)
    i.rect(44, 30, 56, 66, 2, "d")
    i.rect(32, 42, 68, 54, 2, "d")


@icon("resist")
def _(i):
    i.poly([(50, 6), (88, 26), (88, 70), (50, 94), (12, 70), (12, 26)])
    i.circle(50, 50, 20, "d")
    i.circle(50, 50, 10, "b")


@icon("block")
def _(i):
    ICONS["shield"](i)
    i.line([(30, 40), (70, 40)], 6, "b", 0)


@icon("dodge")
def _(i):
    for dx in (0, 26):
        i.poly([(14 + dx, 16), (34 + dx, 16), (60 + dx, 50), (34 + dx, 84), (14 + dx, 84), (40 + dx, 50)])


@icon("area")
def _(i):
    i.ring(50, 50, 38, 7)
    i.ring(50, 50, 20, 7)
    i.circle(50, 50, 6)


@icon("fire")
def _(i):
    i.poly([(50, 4), (70, 30), (82, 58), (74, 84), (50, 94), (26, 84), (18, 58), (32, 38), (40, 50)])
    i.poly([(50, 50), (62, 66), (58, 84), (42, 84), (38, 68)], "d")


@icon("cold")
def _(i):
    for a in range(0, 180, 60):
        dx, dy = math.cos(math.radians(a)) * 42, math.sin(math.radians(a)) * 42
        i.line([(50 - dx, 50 - dy), (50 + dx, 50 + dy)], 8)
        for s in (1, -1):
            bx, by = 50 + dx * 0.62 * s, 50 + dy * 0.62 * s
            for b in (35, -35):
                aa = math.radians(a + b + (0 if s > 0 else 180))
                i.line([(bx, by), (bx + math.cos(aa) * 14, by + math.sin(aa) * 14)], 5)


@icon("lightning")
def _(i):
    ICONS["attack_speed"](i)


@icon("holy")
def _(i):
    i.circle(50, 50, 22)
    for k in range(8):
        a = math.radians(k * 45)
        i.poly([(50 + math.cos(a - 0.2) * 28, 50 + math.sin(a - 0.2) * 28), (50 + math.cos(a) * 46, 50 + math.sin(a) * 46), (50 + math.cos(a + 0.2) * 28, 50 + math.sin(a + 0.2) * 28)])


@icon("poison")
def _(i):
    i.poly([(50, 6), (76, 50), (24, 50)])
    i.circle(50, 60, 27)
    i.circle(78, 22, 9)
    i.circle(58, 64, 8, "d")


@icon("life_regen")
def _(i):
    ICONS["life"](i)
    i.poly([(50, 28), (64, 46), (56, 46), (56, 64), (44, 64), (44, 46), (36, 46)], "d")


# ============================================================ navigation & actions
@icon("bag")
def _(i):
    i.arc(50, 30, 16, 180, 360, 7)
    i.poly([(22, 34), (78, 34), (90, 86), (10, 86)])
    i.rect(10, 80, 90, 92, 5)
    i.rect(38, 46, 62, 60, 3, "d")


@icon("hero")
def _(i):
    i.circle(50, 34, 24)
    i.poly([(14, 94), (22, 66), (40, 56), (60, 56), (78, 66), (86, 94)])
    i.poly([(26, 30), (50, 4), (74, 30), (50, 22)], "d")


@icon("skills")
def _(i):
    i.line([(24, 78), (50, 50), (76, 78)], 6)
    i.line([(50, 50), (50, 24)], 6)
    for x, y in ((24, 80), (76, 80), (50, 50)):
        i.circle(x, y, 12)
    i.star(50, 20, 17, 7, 4, -90)


@icon("map")
def _(i):
    i.poly([(6, 20), (34, 10), (66, 20), (94, 10), (94, 80), (66, 90), (34, 80), (6, 90)])
    i.line([(34, 10), (34, 80)], 3, "d")
    i.line([(66, 20), (66, 90)], 3, "d")
    i.line([(18, 66), (44, 50), (58, 60), (80, 34)], 3, "d")


@icon("menu")
def _(i):
    for y in (22, 50, 78):
        i.rect(12, y - 8, 88, y + 8, 7)


@icon("close")
def _(i):
    i.line([(20, 20), (80, 80)], 16)
    i.line([(80, 20), (20, 80)], 16)


@icon("back")
def _(i):
    i.poly([(8, 50), (46, 14), (46, 36), (90, 36), (90, 64), (46, 64), (46, 86)])


@icon("next")
def _(i):
    i.poly([(92, 50), (54, 14), (54, 36), (10, 36), (10, 64), (54, 64), (54, 86)])


@icon("settings")
def _(i):
    for k in range(8):
        a = math.radians(k * 45)
        i.poly([(50 + math.cos(a - 0.22) * 30, 50 + math.sin(a - 0.22) * 30), (50 + math.cos(a - 0.16) * 46, 50 + math.sin(a - 0.16) * 46),
                (50 + math.cos(a + 0.16) * 46, 50 + math.sin(a + 0.16) * 46), (50 + math.cos(a + 0.22) * 30, 50 + math.sin(a + 0.22) * 30)])
    i.circle(50, 50, 34)
    i.circle(50, 50, 14, "b", 0)


@icon("credits")
def _(i):
    i.rect(18, 10, 82, 90, 6)
    i.circle(50, 30, 7, "d")
    i.rect(44, 42, 56, 76, 3, "d")


@icon("quests")
def _(i):
    i.rect(18, 16, 82, 84, 4)
    i.circle(18, 16, 9)
    i.circle(82, 84, 9)
    i.rect(44, 26, 56, 58, 4, "d")
    i.circle(50, 70, 6, "d")


@icon("starmap")
def _(i):
    pts = [(16, 70), (38, 30), (64, 46), (86, 16)]
    i.line(pts, 3)
    i.line([(64, 46), (78, 82)], 3)
    for (x, y), r in zip(pts + [(78, 82)], (11, 14, 11, 15, 10)):
        i.star(x, y, r, r * 0.45, 4, -90)


@icon("craft")
def _(i):
    i.poly([(8, 30), (82, 30), (92, 40), (70, 48), (62, 62), (70, 78), (30, 78), (38, 62), (30, 48), (8, 40)])
    i.rect(22, 78, 78, 90, 3)


@icon("anvil")
def _(i):
    ICONS["craft"](i)


@icon("hammer")
def _(i):
    i.line([(20, 86), (58, 40)], 8)
    i.poly([(46, 16), (70, 6), (92, 32), (80, 44), (70, 38), (56, 48), (40, 32)])


@icon("salvage")
def _(i):
    ICONS["hammer"](i)
    i.star(24, 26, 12, 4, 4, -90)


@icon("stash")
def _(i):
    i.rect(10, 38, 90, 88, 6)
    i.poly([(10, 40), (14, 22), (30, 12), (70, 12), (86, 22), (90, 40)])
    i.rect(10, 38, 90, 46, 0, "d")
    i.rect(42, 36, 58, 58, 3)
    i.rect(46, 44, 54, 52, 1, "d")


@icon("chest_open")
def _(i):
    ICONS["stash"](i)


@icon("vendor")
def _(i):
    i.circle(50, 60, 34)
    i.poly([(34, 8), (66, 8), (58, 30), (42, 30)])
    i.rect(38, 24, 62, 32, 3, "d")
    i.circle(50, 62, 14, "d")


@icon("sell")
def _(i):
    for k, (x, y) in enumerate(((32, 68), (60, 58), (46, 36))):
        i.ellipse(x - 26, y - 13, x + 26, y + 13)
        i.ellipse(x - 20, y - 8, x + 20, y + 6, "d")


@icon("pets")
def _(i):
    i.ellipse(26, 46, 74, 90)
    for x, y in ((18, 36), (36, 18), (64, 18), (82, 36)):
        i.circle(x, y, 11)


@icon("paw")
def _(i):
    ICONS["pets"](i)


@icon("mounts")
def _(i):
    i.arc(50, 46, 32, 150, 390, 14)
    for a in (160, 200, 340, 380):
        x, y = 50 + math.cos(math.radians(a)) * 32, 46 + math.sin(math.radians(a)) * 32
        i.circle(x, y, 3.5, "d")


@icon("hearth")
def _(i):
    i.rect(34, 40, 66, 92, 4)
    i.poly([(50, 4), (62, 22), (60, 34), (50, 38), (40, 34), (38, 22)])
    i.line([(50, 38), (50, 44)], 3, "d")
    i.poly([(50, 16), (55, 26), (50, 32), (45, 26)], "s", 180)


@icon("candle")
def _(i):
    ICONS["hearth"](i)


@icon("waypoint")
def _(i):
    i.arc(50, 50, 32, 180, 360, 12)
    i.rect(12, 48, 30, 92, 3)
    i.rect(70, 48, 88, 92, 3)
    i.star(50, 58, 16, 7, 4, -90)


@icon("portal")
def _(i):
    i.ellipse(20, 6, 80, 94)
    i.ellipse(32, 20, 68, 80, "d")
    i.star(50, 50, 12, 5, 4, -90)


@icon("lock")
def _(i):
    i.arc(50, 36, 20, 180, 360, 9)
    i.line([(30, 36), (30, 46)], 9)
    i.line([(70, 36), (70, 46)], 9)
    i.rect(16, 44, 84, 92, 10)
    i.circle(50, 62, 7, "d")
    i.rect(47, 62, 53, 78, 2, "d")


@icon("unlock")
def _(i):
    i.arc(66, 30, 18, 180, 360, 9)
    i.line([(84, 30), (84, 40)], 9)
    i.rect(10, 44, 76, 92, 10)
    i.circle(43, 62, 7, "d")
    i.rect(40, 62, 46, 78, 2, "d")


@icon("best")
def _(i):
    i.poly([(10, 30), (30, 48), (50, 16), (70, 48), (90, 30), (82, 80), (18, 80)])
    i.rect(18, 76, 82, 90, 3)
    for x in (30, 50, 70):
        i.circle(x, 66, 5, "d")


@icon("crown")
def _(i):
    ICONS["best"](i)


@icon("filter")
def _(i):
    i.poly([(8, 12), (92, 12), (60, 50), (60, 86), (40, 94), (40, 50)])


@icon("sort")
def _(i):
    i.poly([(30, 6), (54, 32), (38, 32), (38, 92), (22, 92), (22, 32), (6, 32)])
    i.poly([(70, 94), (46, 68), (62, 68), (62, 8), (78, 8), (78, 68), (94, 68)])


@icon("plus")
def _(i):
    i.rect(38, 10, 62, 90, 6)
    i.rect(10, 38, 90, 62, 6)


@icon("minus")
def _(i):
    i.rect(10, 38, 90, 62, 6)


@icon("check")
def _(i):
    i.line([(14, 52), (40, 78), (86, 24)], 16)


@icon("star")
def _(i):
    i.star(50, 54, 46, 20, 5)


@icon("info")
def _(i):
    i.circle(50, 50, 44)
    i.circle(50, 28, 7, "d")
    i.rect(43, 42, 57, 78, 3, "d")


@icon("talk")
def _(i):
    i.ellipse(6, 10, 94, 72)
    i.poly([(24, 60), (18, 92), (48, 66)])
    for x in (30, 50, 70):
        i.circle(x, 41, 6, "d")


@icon("hand")
def _(i):
    ICONS["hands"](i)


@icon("mail")
def _(i):
    i.rect(8, 20, 92, 80, 6)
    i.line([(12, 26), (50, 56), (88, 26)], 5, "d")


@icon("cauldron")
def _(i):
    i.ellipse(10, 30, 90, 94)
    i.rect(6, 26, 94, 40, 6)
    i.circle(36, 16, 7)
    i.circle(58, 10, 5)
    i.rect(22, 88, 32, 98, 2)
    i.rect(68, 88, 78, 98, 2)


@icon("potion")
def _(i):
    i.rect(40, 6, 60, 26, 3)
    i.circle(50, 62, 32)
    i.rect(42, 20, 58, 40, 0)
    i.circle(38, 54, 8, "s", 120)


@icon("gem")
def _(i):
    i.poly([(26, 14), (74, 14), (94, 38), (50, 92), (6, 38)])
    i.line([(6, 38), (94, 38)], 3, "d")
    i.line([(34, 38), (50, 92), (66, 38)], 3, "d")


@icon("lantern")
def _(i):
    i.arc(50, 16, 12, 180, 360, 5)
    i.rect(30, 16, 70, 26, 3)
    i.poly([(26, 26), (74, 26), (70, 80), (30, 80)])
    i.rect(24, 80, 76, 92, 4)
    i.poly([(50, 36), (60, 54), (56, 66), (44, 66), (40, 54)], "d")


@icon("trophy")
def _(i):
    i.poly([(22, 10), (78, 10), (74, 44), (58, 58), (58, 72), (42, 72), (42, 58), (26, 44)])
    i.arc(22, 26, 12, 90, 270, 6)
    i.arc(78, 26, 12, -90, 90, 6)
    i.rect(28, 76, 72, 90, 3)


@icon("flame")
def _(i):
    ICONS["fire"](i)


@icon("skull_soft")
def _(i):
    i.circle(50, 44, 34)
    i.rect(32, 60, 68, 88, 8)
    i.circle(38, 46, 9, "d")
    i.circle(62, 46, 9, "d")


@icon("egg")
def _(i):
    i.ellipse(20, 8, 80, 94)
    i.line([(22, 54), (34, 46), (44, 56), (56, 46), (66, 56), (78, 48)], 4, "d")


@icon("treat")
def _(i):
    i.line([(24, 50), (76, 50)], 16)
    for x in (18, 82):
        i.circle(x, 40, 12)
        i.circle(x, 60, 12)


@icon("pin")
def _(i):
    i.circle(50, 36, 30)
    i.poly([(24, 50), (76, 50), (50, 96)])
    i.circle(50, 36, 12, "d")


@icon("rest")
def _(i):
    i.circle(50, 50, 40)
    i.circle(66, 38, 36, "b", 0)


@icon("mirror")
def _(i):
    i.poly([(46, 10), (46, 90), (8, 90)])
    i.poly([(54, 10), (54, 90), (92, 90)])


@icon("text_size")
def _(i):
    i.poly([(8, 90), (30, 20), (42, 20), (64, 90), (52, 90), (46, 70), (26, 70), (20, 90)])
    i.poly([(29, 58), (43, 58), (36, 36)], "b", 0)
    i.poly([(62, 90), (76, 50), (84, 50), (98, 90), (90, 90), (80, 60), (70, 90)])


@icon("eye")
def _(i):
    ICONS["wisdom"](i)


@icon("contrast")
def _(i):
    i.ring(50, 50, 38, 8)
    i.poly([(50, 12), (50, 88), (40, 86), (26, 78), (16, 64), (12, 50), (16, 36), (26, 22), (40, 14)])


@icon("clock")
def _(i):
    i.ring(50, 50, 38, 9)
    i.line([(50, 50), (50, 24)], 7)
    i.line([(50, 50), (68, 60)], 7)


@icon("music")
def _(i):
    i.circle(28, 76, 14)
    i.circle(74, 66, 14)
    i.line([(40, 76), (40, 16), (86, 8), (86, 66)], 7)


@icon("sound")
def _(i):
    i.poly([(8, 36), (28, 36), (52, 14), (52, 86), (28, 64), (8, 64)])
    i.arc(56, 50, 18, -50, 50, 6)
    i.arc(56, 50, 34, -50, 50, 6)


@icon("shake")
def _(i):
    i.rect(30, 14, 70, 86, 8)
    for s in (1, -1):
        i.line([(50 + 32 * s, 30), (50 + 42 * s, 42), (50 + 32 * s, 54), (50 + 42 * s, 66)], 4)


@icon("parent")
def _(i):
    i.circle(34, 26, 16)
    i.poly([(10, 94), (14, 58), (34, 46), (54, 58), (58, 94)])
    i.circle(72, 50, 12)
    i.poly([(56, 94), (60, 70), (72, 64), (84, 70), (88, 94)])


@icon("hardcore")
def _(i):
    ICONS["fire"](i)
    i.star(50, 70, 10, 4, 4, -90, "s", 200)


@icon("undo")
def _(i):
    i.arc(54, 56, 30, 190, 450, 10)
    i.poly([(4, 52), (28, 28), (34, 62)])


@icon("heart_plus")
def _(i):
    ICONS["vitality"](i)


@icon("upgrade")
def _(i):
    i.poly([(50, 6), (90, 48), (66, 48), (66, 92), (34, 92), (34, 48), (10, 48)])


@icon("compare")
def _(i):
    i.poly([(4, 30), (30, 8), (30, 22), (66, 22), (66, 38), (30, 38), (30, 52)])
    i.poly([(96, 70), (70, 48), (70, 62), (34, 62), (34, 78), (70, 78), (70, 92)])


@icon("tank")
def _(i):
    ICONS["shield"](i)


@icon("berserker")
def _(i):
    ICONS["axe2h"](i)


@icon("caster")
def _(i):
    ICONS["wand"](i)


@icon("summoner")
def _(i):
    i.circle(50, 26, 18)
    i.rect(30, 44, 70, 80, 10)
    i.line([(30, 50), (12, 64)], 9)
    i.line([(70, 50), (88, 64)], 9)
    i.line([(40, 78), (38, 94)], 9)
    i.line([(60, 78), (62, 94)], 9)
    i.line([(42, 22), (48, 28)], 3, "d")
    i.line([(48, 22), (42, 28)], 3, "d")
    i.circle(58, 25, 3, "d")
    i.line([(38, 60), (62, 60)], 2, "d")


@icon("assassin")
def _(i):
    ICONS["dagger"](i)


@icon("new")
def _(i):
    i.star(50, 50, 46, 26, 8, -90)


# ============================================================ skill icons (by skills.json "icon")
@icon("dash")
def _(i):
    i.poly([(40, 20), (92, 50), (40, 80), (52, 50)])
    for y, x0 in ((30, 8), (50, 2), (70, 8)):
        i.line([(x0, y), (x0 + 30, y)], 5)


@icon("sun")
def _(i):
    ICONS["holy"](i)


@icon("aegis")
def _(i):
    ICONS["shield"](i)
    i.star(50, 46, 16, 6, 4, -90, "s", 220)


@icon("pillar")
def _(i):
    i.rect(34, 4, 66, 96, 6)
    i.ellipse(14, 80, 86, 98)
    i.rect(44, 10, 50, 78, 2, "s", 200)


@icon("whirl")
def _(i):
    pts = []
    for k in range(80):
        t = k / 79
        a = t * 4.2 * math.pi
        r = 6 + t * 38
        pts.append((50 + math.cos(a) * r, 50 + math.sin(a) * r))
    i.line(pts, 9)


@icon("leap")
def _(i):
    i.arc(50, 78, 38, 200, 340, 9)
    i.poly([(84, 60), (94, 84), (70, 76)])
    i.rect(10, 86, 90, 94, 3)


@icon("roar")
def _(i):
    i.poly([(6, 36), (26, 36), (46, 16), (46, 84), (26, 64), (6, 64)])
    for r in (18, 32, 46):
        i.arc(44, 50, r, -45, 45, 6)


@icon("quake")
def _(i):
    i.rect(4, 58, 96, 92, 4)
    i.line([(50, 58), (40, 72), (54, 80), (46, 92)], 5, "b", 0)
    i.line([(20, 58), (28, 72)], 4, "b", 0)
    i.line([(80, 58), (72, 76)], 4, "b", 0)
    i.poly([(50, 6), (70, 30), (58, 30), (58, 50), (42, 50), (42, 30), (30, 30)])


@icon("rope")
def _(i):
    i.ring(36, 40, 22, 8)
    i.ring(64, 60, 22, 8)


@icon("spark")
def _(i):
    i.star(50, 50, 46, 12, 4, -90)
    i.star(50, 50, 30, 8, 4, -45)


@icon("comet")
def _(i):
    i.poly([(56, 16), (4, 96), (84, 44)])
    i.line([(40, 24), (10, 50)], 5)
    i.line([(76, 60), (50, 90)], 5)
    i.circle(70, 30, 22)
    i.circle(64, 24, 7, "s", 170)


@icon("frost")
def _(i):
    ICONS["cold"](i)


@icon("chain")
def _(i):
    i.poly([(56, 4), (22, 44), (44, 44), (30, 70), (52, 70), (40, 96), (80, 58), (58, 58), (72, 32), (50, 32)])


@icon("blink")
def _(i):
    i.circle(46, 50, 42)
    i.circle(66, 40, 36, "b", 0)
    i.star(76, 64, 10, 4, 4, -90)


@icon("meteor")
def _(i):
    ICONS["comet"](i)
    i.star(24, 28, 8, 3, 4, -90)


@icon("needle")
def _(i):
    i.poly([(88, 8), (94, 14), (22, 88), (12, 90), (14, 80)])
    i.ellipse(74, 14, 86, 26, "b", 0)
    i.arc(30, 40, 22, 90, 300, 3)


@icon("doll")
def _(i):
    ICONS["summoner"](i)


@icon("pins")
def _(i):
    for x in (26, 50, 74):
        i.line([(x, 34), (x, 92)], 5)
        i.circle(x, 24, 11)


@icon("bear")
def _(i):
    i.circle(24, 26, 14)
    i.circle(76, 26, 14)
    i.circle(50, 56, 36)
    i.ellipse(36, 58, 64, 82, "d")
    i.circle(38, 48, 5, "d")
    i.circle(62, 48, 5, "d")


@icon("thread")
def _(i):
    i.rect(22, 8, 78, 20, 4)
    i.rect(22, 80, 78, 92, 4)
    i.rect(30, 18, 70, 82, 3)
    for y in range(26, 80, 9):
        i.line([(32, y), (68, y + 4)], 2, "d")
    i.line([(70, 60), (90, 94)], 3)


@icon("mend")
def _(i):
    i.rect(36, 8, 64, 92, 8)
    i.rect(8, 36, 92, 64, 8)


@icon("bolt")
def _(i):
    i.line([(10, 90), (78, 22)], 6)
    i.poly([(92, 8), (84, 36), (64, 16)])
    i.poly([(10, 90), (8, 72), (20, 80)])
    i.poly([(10, 90), (28, 92), (20, 80)])


@icon("fan")
def _(i):
    for a in (-120, -90, -60):
        r = math.radians(a)
        x, y = 50 + math.cos(r) * 44, 90 + math.sin(r) * 80
        i.line([(50, 90), (x, y)], 5)
        dx, dy = math.cos(r), math.sin(r)
        px, py = -dy, dx
        i.poly([(x + dx * 10, y + dy * 10), (x + px * 8, y + py * 8), (x - px * 8, y - py * 8)])


@icon("roll")
def _(i):
    i.arc(50, 50, 34, -30, 260, 11)
    i.poly([(86, 40), (74, 8), (58, 36)])


@icon("trap")
def _(i):
    i.arc(50, 60, 38, 180, 360, 9)
    for x in range(20, 84, 12):
        i.poly([(x, 60), (x + 6, 44), (x + 12, 60)])
    i.rect(8, 60, 92, 72, 4)
    i.ellipse(36, 70, 64, 90)


@icon("smoke")
def _(i):
    i.circle(30, 62, 20)
    i.circle(52, 44, 26)
    i.circle(72, 64, 20)
    i.rect(12, 62, 88, 82, 10)


@icon("rain")
def _(i):
    for x, y in ((20, 14), (50, 30), (80, 14)):
        i.line([(x, y), (x, y + 44)], 5)
        i.poly([(x - 10, y + 44), (x + 10, y + 44), (x, y + 60)])


@icon("unknown")
def _(i):
    i.circle(50, 50, 40)
    i.circle(50, 50, 14, "d")


# ============================================================ materials
@icon("soot")
def _(i):
    i.ellipse(8, 50, 92, 92)
    i.circle(36, 50, 18)
    i.circle(60, 42, 22)


@icon("wickthread")
def _(i):
    ICONS["thread"](i)


@icon("dusk_essence")
def _(i):
    ICONS["resource"](i)


@icon("ember_heart")
def _(i):
    ICONS["life"](i)
    i.poly([(50, 30), (60, 46), (56, 62), (44, 62), (40, 46)], "d")


@icon("bone_meal")
def _(i):
    i.line([(22, 78), (78, 22)], 14)
    for x, y in ((16, 72), (28, 84), (72, 16), (84, 28)):
        i.circle(x, y, 11)


@icon("bell_shard")
def _(i):
    i.poly([(50, 6), (68, 22), (74, 64), (92, 82), (8, 82), (26, 64), (32, 22)])
    i.circle(50, 90, 8)


@icon("material")
def _(i):
    ICONS["gem"](i)


@icon("hanger")
def _(i):
    i.arc(50, 18, 9, 180, 400, 6)
    i.line([(50, 28), (50, 36)], 6)
    i.poly([(50, 34), (94, 70), (90, 80), (10, 80), (6, 70)])
    i.poly([(50, 46), (78, 70), (22, 70)], "b", 0)


@icon("medal")
def _(i):
    i.poly([(24, 4), (42, 4), (54, 40), (36, 40)])
    i.poly([(76, 4), (58, 4), (46, 40), (64, 40)])
    i.circle(50, 64, 30)
    i.star(50, 65, 18, 8, 5, -90, "d")


@icon("book")
def _(i):
    i.poly([(4, 22), (46, 16), (50, 22), (50, 88), (46, 84), (4, 88)])
    i.poly([(96, 22), (54, 16), (50, 22), (50, 88), (54, 84), (96, 88)])
    i.star(28, 50, 12, 5, 4, -90, "d")
    i.line([(60, 40), (86, 38)], 3, "d")
    i.line([(60, 54), (86, 52)], 3, "d")
    i.line([(60, 68), (80, 66)], 3, "d")


def main():
    os.makedirs(DEST, exist_ok=True)
    for name, fn in ICONS.items():
        ic = Icon()
        fn(ic)
        ic.render(os.path.join(DEST, name + ".png"))
    print("icons:", len(ICONS))


if __name__ == "__main__":
    main()

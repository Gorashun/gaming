#!/usr/bin/env python3
"""Tests for tools/normalize_art.py against a synthetic project in a temp dir.

No real art is needed: every test builds a tiny project (build spec, credits,
licence registry, one synthetic PNG in assets/incoming/) and runs the script's
main() on it. Stdlib unittest + Pillow, nothing else.

Usage (from rogelike_app/, CI runs the same):
    python3 tools/test_normalize_art.py
    python3 tools/test_normalize_art.py -v
"""

from __future__ import annotations

import contextlib
import csv
import hashlib
import io
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import normalize_art  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

CSV_HEADER = "path,source,author,license,url,retrieved,notes\n"
KEEP_ROW = "assets/sprites/x.png,own,me,own-work,,2026-01-01,not under assets/art\n"


def synthetic_battler(path: Path, shadow: bool = True) -> None:
    """200x160 canvas: transparent margin, a warm body, a baked black shadow."""
    img = Image.new("RGBA", (200, 160), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    if shadow:
        # Pipoya-style drop shadow: pure black, low alpha, wider than the body.
        draw.ellipse((30, 128, 170, 150), fill=(0, 0, 0, 80))
    draw.ellipse((60, 30, 140, 140), fill=(200, 120, 60, 255))
    draw.rectangle((90, 50, 110, 60), fill=(20, 30, 40, 255))
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)


class Project:
    """A throwaway rogelike_app-shaped tree."""

    def __init__(self) -> None:
        self.root = Path(tempfile.mkdtemp(prefix="normalize_art_test_"))
        (self.root / "tools").mkdir()
        (self.root / "assets/art").mkdir(parents=True)
        (self.root / "assets/ASSET_LICENSES.csv").write_text(CSV_HEADER + KEEP_ROW, encoding="utf-8")
        synthetic_battler(self.root / "assets/incoming/base/mon.png")
        self.spec = {
            "retrieved": "2026-09-24",
            "entries": [
                {"id": "enemy.MON", "out": "enemy/MON.png", "op": "battler", "source": "base",
                 "src": "mon.png", "strip_shadow": 96, "max": [64, 64], "note": "test"},
            ],
        }
        self.credits = {
            "sections": [{"id": "s", "title": "S"}],
            "sources": [
                {"id": "base", "section": "s", "author": "Base Author", "license": "CC0-1.0",
                 "url": "https://example.org/base", "incoming": "assets/incoming/base",
                 "only_while_used": True, "attribution_lines": ["Base"]},
            ],
            "pending_sources": [
                {"id": "alt", "section": "s", "author": "Alt Author", "license": "proprietary-free",
                 "url": "https://example.org/alt", "incoming": "assets/incoming/alt",
                 "only_while_used": True, "attribution_lines": ["Alt"]},
            ],
        }
        self.write()

    def write(self) -> None:
        (self.root / "tools/art_build.json").write_text(json.dumps(self.spec), encoding="utf-8")
        (self.root / "assets/credits.json").write_text(normalize_art.dump_credits(self.credits), encoding="utf-8")

    def run(self, *extra: str) -> str:
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = normalize_art.main(["--root", str(self.root), *extra])
        if code != 0:
            raise AssertionError(f"normalize_art exited {code}:\n{out.getvalue()}")
        return out.getvalue()

    def manifest(self) -> dict:
        return json.loads((self.root / "assets/art/manifest.json").read_text(encoding="utf-8"))

    def credits_now(self) -> dict:
        return json.loads((self.root / "assets/credits.json").read_text(encoding="utf-8"))

    def rows(self) -> list[dict]:
        with (self.root / "assets/ASSET_LICENSES.csv").open(newline="", encoding="utf-8") as handle:
            return list(csv.DictReader(handle))

    def out_png(self, rel: str = "enemy/MON.png") -> Image.Image:
        with Image.open(self.root / "assets/art" / rel) as img:
            img.load()
            return img.copy()

    def digest(self, rel: str = "enemy/MON.png") -> str:
        return hashlib.sha256((self.root / "assets/art" / rel).read_bytes()).hexdigest()

    def close(self) -> None:
        shutil.rmtree(self.root, ignore_errors=True)


class NormalizeArtTest(unittest.TestCase):
    def setUp(self) -> None:
        self.p = Project()

    def tearDown(self) -> None:
        self.p.close()

    def test_battler_is_trimmed_fitted_and_registered(self) -> None:
        self.p.run()
        img = self.p.out_png()
        self.assertEqual(img.mode, "RGBA")
        self.assertLessEqual(max(img.size), 64)
        # Trimmed: every edge touches an opaque pixel.
        alpha = img.getchannel("A")
        self.assertEqual(alpha.point(lambda a: 255 if a > normalize_art.ALPHA_THRESHOLD else 0).getbbox(),
                         (0, 0, img.width, img.height))
        entry = self.p.manifest()["enemy.MON"]
        self.assertEqual(entry["file"], "res://assets/art/enemy/MON.png")
        self.assertEqual(entry["kind"], "battler")
        self.assertEqual(entry["pivot"], "bottom")
        self.assertEqual(entry["size"], [img.width, img.height])
        self.assertEqual(entry["license"], "CC0-1.0")
        rows = {r["path"]: r for r in self.p.rows()}
        self.assertIn("assets/sprites/x.png", rows, "rows outside assets/art/ must survive")
        row = rows["assets/art/enemy/MON.png"]
        self.assertEqual(row["author"], "Base Author")
        self.assertEqual(row["retrieved"], "2026-09-24")
        self.assertEqual(row["source"], "assets/incoming/base/mon.png")

    def test_same_input_gives_same_bytes(self) -> None:
        self.p.run()
        first = self.p.digest()
        manifest = (self.p.root / "assets/art/manifest.json").read_bytes()
        self.p.run()
        self.assertEqual(self.p.digest(), first)
        self.assertEqual((self.p.root / "assets/art/manifest.json").read_bytes(), manifest)

    def test_strip_shadow_removes_the_baked_shadow(self) -> None:
        self.p.spec["entries"][0]["max"] = [512, 512]
        self.p.write()
        self.p.run()
        with_strip = self.p.out_png().size
        self.p.spec["entries"][0].pop("strip_shadow")
        self.p.write()
        self.p.run()
        without = self.p.out_png().size
        # The shadow ellipse is wider (140 px) than the body (80 px) and lower.
        self.assertEqual(with_strip, (81, 111))
        self.assertGreater(without[0], with_strip[0])
        self.assertGreater(without[1], with_strip[1])

    def test_grade_is_off_by_default_and_never_touches_alpha(self) -> None:
        self.p.run()
        plain = self.p.out_png().copy()
        self.p.spec["entries"][0]["grade"] = False
        self.p.write()
        self.p.run()
        self.assertEqual(self.p.out_png().tobytes(), plain.tobytes(), "grade false = no grade")
        self.p.spec["entries"][0]["grade"] = True
        self.p.write()
        self.p.run()
        graded = self.p.out_png()
        self.assertEqual(graded.getchannel("A").tobytes(), plain.getchannel("A").tobytes())
        self.assertNotEqual(graded.tobytes(), plain.tobytes())
        # Desaturated: the warm body loses chroma.
        cx, cy = plain.width // 2, plain.height // 2 + 10
        r0, g0, b0, _ = plain.getpixel((cx, cy))
        r1, g1, b1, _ = graded.getpixel((cx, cy))
        self.assertLess(max(r1, g1, b1) - min(r1, g1, b1), max(r0, g0, b0) - min(r0, g0, b0))

    def test_grade_rim_lights_the_edge_facing_the_torch(self) -> None:
        img = Image.new("RGBA", (40, 40), (0, 0, 0, 0))
        ImageDraw.Draw(img).rectangle((10, 10, 29, 29), fill=(30, 30, 30, 255))
        graded = normalize_art.grade(img, {"desaturate": 0, "contrast": 1, "cool_shadows": 0,
                                           "rim": 1.0, "rim_from": [1, 0], "rim_px": 3})
        right = graded.getpixel((28, 20))
        left = graded.getpixel((11, 20))
        self.assertGreater(right[0], left[0] + 40, "the right edge faces a torch at +x")
        self.assertEqual(left[:3], (30, 30, 30))

    def test_display_h_writes_manifest_scale(self) -> None:
        self.p.spec["entries"][0]["display_h"] = 32
        self.p.write()
        self.p.run()
        entry = self.p.manifest()["enemy.MON"]
        self.assertAlmostEqual(entry["scale"], round(32 / entry["size"][1], 4))

    def _overlay(self, enabled: bool = False, retrieved: str = "2026-10-01") -> Path:
        overlay = {
            "enabled": enabled,
            "retrieved": retrieved,
            "defaults": {"op": "battler", "source": "alt", "strip_shadow": 0},
            "entries": [{"id": "enemy.MON", "out": "enemy/MON.png", "src": "MON.png", "max": [48, 48]}],
        }
        path = self.p.root / "tools/art_build.alt.json"
        path.write_text(json.dumps(overlay), encoding="utf-8")
        return path

    def test_overlay_with_missing_raw_falls_back_to_the_base_entry(self) -> None:
        self._overlay()
        log = self.p.run("--build", "tools/art_build.alt.json")
        self.assertIn("missing", log)
        self.assertEqual(self.p.manifest()["enemy.MON"]["source"], "base")
        ids = [s["id"] for s in self.p.credits_now()["sources"]]
        self.assertEqual(ids, ["base"], "an unused pending source is not shown")

    def test_overlay_swaps_the_set_and_the_credits_follow(self) -> None:
        self._overlay()
        synthetic_battler(self.p.root / "assets/incoming/alt/MON.png", shadow=False)
        self.p.run("--build", "tools/art_build.alt.json")
        entry = self.p.manifest()["enemy.MON"]
        self.assertEqual(entry["source"], "alt")
        self.assertLessEqual(max(entry["size"]), 48)
        credits = self.p.credits_now()
        self.assertEqual([s["id"] for s in credits["sources"]], ["alt"])
        self.assertEqual([s["id"] for s in credits["pending_sources"]], ["base"])
        row = {r["path"]: r for r in self.p.rows()}["assets/art/enemy/MON.png"]
        self.assertEqual((row["author"], row["retrieved"]), ("Alt Author", "2026-10-01"))
        # Without the overlay the base set and its credit come back.
        self.p.run()
        self.assertEqual(self.p.manifest()["enemy.MON"]["source"], "base")
        self.assertEqual([s["id"] for s in self.p.credits_now()["sources"]], ["base"])

    def test_enabled_overlay_listed_in_the_spec_applies_without_flag(self) -> None:
        self._overlay(enabled=True)
        synthetic_battler(self.p.root / "assets/incoming/alt/MON.png", shadow=False)
        self.p.spec["overlays"] = ["tools/art_build.alt.json"]
        self.p.write()
        self.p.run()
        self.assertEqual(self.p.manifest()["enemy.MON"]["source"], "alt")

    def test_overlay_without_retrieved_date_stops_before_writing(self) -> None:
        self._overlay(retrieved="")
        synthetic_battler(self.p.root / "assets/incoming/alt/MON.png", shadow=False)
        with self.assertRaises(SystemExit):
            with contextlib.redirect_stdout(io.StringIO()):
                normalize_art.main(["--root", str(self.p.root), "--build", "tools/art_build.alt.json"])
        self.assertFalse((self.p.root / "assets/art/enemy/MON.png").exists())

    def test_only_leaves_manifest_registry_and_credits_alone(self) -> None:
        before_credits = (self.p.root / "assets/credits.json").read_text(encoding="utf-8")
        before_csv = (self.p.root / "assets/ASSET_LICENSES.csv").read_text(encoding="utf-8")
        self.p.run("--only", "enemy.MON")
        self.assertTrue((self.p.root / "assets/art/enemy/MON.png").is_file())
        self.assertFalse((self.p.root / "assets/art/manifest.json").exists())
        self.assertEqual((self.p.root / "assets/credits.json").read_text(encoding="utf-8"), before_credits)
        self.assertEqual((self.p.root / "assets/ASSET_LICENSES.csv").read_text(encoding="utf-8"), before_csv)

    def test_credits_layout_round_trips(self) -> None:
        text = (self.p.root / "assets/credits.json").read_text(encoding="utf-8")
        self.assertEqual(normalize_art.dump_credits(json.loads(text)), text)


if __name__ == "__main__":
    unittest.main()

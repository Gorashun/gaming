#!/usr/bin/env python3
"""Normalise raw art from assets/incoming/ into assets/art/ and write the manifest.

Reads tools/art_build.json (what to build from which raw file) and
assets/credits.json (who made it, under which licence), then:

  1. writes one normalised PNG per entry to assets/art/<category>/<id>.png
     (transparent margins trimmed, scaled to the target size, RGBA),
  2. writes assets/art/manifest.json (content id -> file, kind, size, pivot,
     frames, source, license), the file src/game/ui/art.gd reads,
  3. rewrites every assets/art/ row in assets/ASSET_LICENSES.csv.

Palette grading is NOT done here: ART_DIRECTION_V2 section 4 is applied by
the Godot shader (dev track A), so the files stay neutral and replaceable.

M7 UI ink (assets/art/ui/{icon,slot,node,face,gearslot}/): white chalk icons
the game tints with modulate. Two ways in:
  * "source": "game-icons" + "svg": "<author>/<name>.svg" - vector icons from
    game-icons.net, fetched by tools/icons/fetch_icons.py and rendered to
    "src" (render/<id>.png) by tools/icons/render_icons.js. The CSV row names
    the author (credits.json "authors") and points at the SVG, not the PNG.
  * "op": "icon" + "mono": true - a painted colour icon turned into tintable
    ink (op_mono_icon). Used for the empty gear-slot glyphs (Ravenmore).
Rows without an "id" ({"_comment": ...}) only group the spec and are skipped.

The contract of the manifest: replace a file on disk under the same name, or
point "file" at another PNG, and the game shows the new art. No code change.

Requires Pillow (python3 -c "import PIL"). No other dependency.

Usage:
    python3 tools/normalize_art.py            # from rogelike_app/
    python3 tools/normalize_art.py --root DIR
    python3 tools/normalize_art.py --only enemy.RUST_RAT   # one entry
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFilter, ImageOps
except ImportError:  # pragma: no cover
    sys.stderr.write("normalize_art.py needs Pillow: pip install pillow\n")
    sys.exit(2)

BUILD_SPEC = Path("tools/art_build.json")
CREDITS = Path("assets/credits.json")
ART_ROOT = Path("assets/art")
MANIFEST = ART_ROOT / "manifest.json"
REGISTRY = Path("assets/ASSET_LICENSES.csv")
RES_PREFIX = "res://assets/art/"

CSV_FIELDS = ("path", "source", "author", "license", "url", "retrieved", "notes")

# op -> manifest kind (src/game/ui/art.gd KINDS)
KIND_FOR_OP = {
    "battler": "battler",
    "icon": "icon",
    "portrait": "portrait",
    "frame": "frame",
    "crop": "ui",
    "copy": "ui",
    "tile": "env",
    "door": "env",
    "fx": "fx",
}

ALPHA_THRESHOLD = 8


# --- Image ops ------------------------------------------------------------


def load_rgba(path: Path) -> Image.Image:
    image = Image.open(path)
    if image.mode == "P" and "transparency" in image.info:
        image = image.convert("RGBA")
    elif image.mode != "RGBA":
        image = image.convert("RGBA")
    return image


def trim(image: Image.Image) -> Image.Image:
    """Crop away fully transparent margins (alpha <= ALPHA_THRESHOLD)."""
    alpha = image.split()[3].point(lambda a: 255 if a > ALPHA_THRESHOLD else 0)
    box = alpha.getbbox()
    return image.crop(box) if box else image


def fit(image: Image.Image, max_w: int, max_h: int, upscale: bool = False) -> Image.Image:
    w, h = image.size
    scale = min(max_w / w, max_h / h)
    if scale >= 1.0 and not upscale:
        return image
    new = (max(1, round(w * scale)), max(1, round(h * scale)))
    return image.resize(new, Image.Resampling.LANCZOS)


def square(image: Image.Image, size: int) -> Image.Image:
    if image.size == (size, size):
        return image
    return image.resize((size, size), Image.Resampling.LANCZOS)


def strip_baked_shadow(image: Image.Image, max_alpha: int) -> Image.Image:
    """Remove a flat black drop shadow painted into the source (Pipoya).

    The shadow is pure black at <= ~35 % alpha; the figure's own outline is
    dark but never pure black at that alpha, so the rule is safe. The game
    draws its own cast shadow (Art.shadow_texture), and the feet must sit on
    the bottom edge (pivot "bottom").
    """
    px = image.load()
    w, h = image.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a <= max_alpha and r == 0 and g == 0 and b == 0:
                px[x, y] = (0, 0, 0, 0)
    return image


def op_battler(image: Image.Image, e: dict) -> Image.Image:
    max_w, max_h = e["max"]
    if e.get("strip_shadow"):
        image = strip_baked_shadow(image, int(e["strip_shadow"]))
    return fit(trim(image), max_w, max_h, upscale=False)


def op_square(image: Image.Image, e: dict) -> Image.Image:
    return square(image, int(e["size"]))


# Mono icons (M7): the ink the UI tints with modulate. Light grey to white in
# RGB so a semantic token multiplies it, the painted shading kept as value.
MONO_FLOOR = 0.45
MONO_PAD = 0.07
MONO_OUTLINE_PX = 9
MONO_OUTLINE_ALPHA = 0.62


def op_mono_icon(image: Image.Image, e: dict) -> Image.Image:
    """A painted colour icon as tintable ink (tools/icons/render_icons.js does
    the same for vector icons): trimmed, desaturated, value range lifted to
    MONO_FLOOR..1 so a tint never goes muddy, centred with a margin, and the
    same soft dark outline the vector icons get from their SVG filter."""
    size = int(e["size"])
    alpha = image.split()[3]
    box = alpha.point(lambda a: 255 if a > 40 else 0).getbbox()
    if box:
        image = image.crop(box)
        alpha = image.split()[3]
    grey = ImageOps.grayscale(image)
    solid = alpha.point(lambda a: 255 if a > 128 else 0)
    grey = ImageOps.autocontrast(grey, cutoff=1, mask=solid)
    grey = grey.point(lambda v: int(255 * (MONO_FLOOR + (1.0 - MONO_FLOOR) * v / 255)))
    ink = Image.merge("RGBA", (grey, grey, grey, alpha))
    pad = float(e.get("pad", MONO_PAD))
    side = max(ink.size)
    canvas_side = max(1, round(side / (1.0 - 2.0 * pad)))
    canvas = Image.new("RGBA", (canvas_side, canvas_side), (0, 0, 0, 0))
    canvas.alpha_composite(ink, ((canvas_side - ink.width) // 2, (canvas_side - ink.height) // 2))
    canvas = canvas.resize((size, size), Image.Resampling.LANCZOS)
    rim = canvas.split()[3].filter(ImageFilter.MaxFilter(MONO_OUTLINE_PX))
    rim = rim.filter(ImageFilter.GaussianBlur(1.5)).point(lambda a: int(a * MONO_OUTLINE_ALPHA))
    out = Image.new("RGBA", canvas.size, (8, 9, 10, 0))
    out.putalpha(rim)
    out.alpha_composite(canvas)
    return out


def op_copy(image: Image.Image, e: dict) -> Image.Image:
    return image


def op_crop(image: Image.Image, e: dict) -> Image.Image:
    out = image.crop(tuple(e["box"]))
    inset = int(e.get("fill_inside", 0))
    if inset > 0:
        # The source composite has widgets drawn inside the panel; a 9-slice
        # only needs the border, so the interior becomes the panel's own flat
        # colour, sampled from an empty patch (fill_sample, source coordinates).
        sx0, sy0, sx1, sy1 = e["fill_sample"]
        patch = image.crop((sx0, sy0, sx1, sy1)).convert("RGB")
        stat = patch.resize((1, 1), Image.Resampling.BOX).getpixel((0, 0))
        ImageDraw.Draw(out).rectangle(
            (inset, inset, out.width - 1 - inset, out.height - 1 - inset), fill=(*stat, 255)
        )
    mirror = int(e.get("mirror_top", 0))
    if mirror > 0:
        strip = out.crop((0, out.height - mirror, out.width, out.height)).transpose(
            Image.Transpose.FLIP_TOP_BOTTOM
        )
        joined = Image.new("RGBA", (out.width, out.height + mirror), (0, 0, 0, 0))
        joined.paste(strip, (0, 0))
        joined.paste(out, (0, mirror))
        out = joined
    if "max" in e:
        out = fit(out, e["max"][0], e["max"][1], upscale=False)
    return out


def op_tile(image: Image.Image, e: dict) -> Image.Image:
    size = int(e["size"])
    out = image.resize((size, size), Image.Resampling.LANCZOS)
    flip = e.get("flip", "")
    if flip == "vertical":
        out = out.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    elif flip == "horizontal":
        out = out.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    # Albedo textures are opaque; make sure alpha is solid.
    out.putalpha(255)
    return out


def op_door(image: Image.Image, e: dict, rim_path: Path) -> Image.Image:
    """Boss door: the wall tile with an arched opening and a stone rim.

    Composited here, not painted: a placeholder with the right silhouette
    until commissioned art replaces the file.
    """
    size = int(e["size"])
    wall = image.resize((size, size), Image.Resampling.LANCZOS)
    wall.putalpha(255)
    rim_tex = load_rgba(rim_path).resize((size, size), Image.Resampling.LANCZOS)

    # Geometry: opening 56 % wide, top arch, floor at the bottom edge.
    left = int(size * 0.22)
    right = int(size * 0.78)
    top = int(size * 0.18)
    radius = (right - left) // 2
    rim_w = int(size * 0.04)

    def arch_mask(inset: int) -> Image.Image:
        m = Image.new("L", (size, size), 0)
        d = ImageDraw.Draw(m)
        l, r, t = left + inset, right - inset, top + inset
        rad = (r - l) // 2
        d.rectangle((l, t + rad, r, size), fill=255)
        d.ellipse((l, t, r, t + 2 * rad), fill=255)
        return m

    outer = arch_mask(0)
    inner = arch_mask(rim_w)

    # Rim: brighter floor stone in the ring between outer and inner arch.
    rim_ring = Image.new("L", (size, size), 0)
    rim_ring.paste(outer, (0, 0))
    rim_ring.paste(0, (0, 0), inner)
    rim_layer = Image.eval(rim_tex.convert("RGB"), lambda v: min(255, int(v * 1.15))).convert("RGBA")
    out = wall.copy()
    out.paste(rim_layer, (0, 0), rim_ring)

    # Opening: near-black with a faint remnant of the wall, darker towards the top.
    dark = Image.new("RGBA", (size, size), (7, 9, 11, 255))
    faint = Image.blend(dark, wall, 0.10)
    grad = Image.linear_gradient("L").resize((size, size))  # 0 top -> 255 bottom
    faint = Image.composite(faint, dark, grad.point(lambda v: int(v * 0.6)))
    out.paste(faint, (0, 0), inner)
    return out


def op_fx(image: Image.Image, e: dict) -> Image.Image:
    return square(image, int(e["size"]))


# --- Build ----------------------------------------------------------------


def build_entry(root: Path, e: dict, source: dict) -> tuple[Path, Image.Image]:
    incoming = root / source["incoming"]
    src = incoming / e["src"]
    if not src.is_file():
        raise FileNotFoundError(f"{e['id']}: raw file missing: {src}")
    op = e["op"]
    image = load_rgba(src)
    if op == "battler":
        out = op_battler(image, e)
    elif op == "icon" and e.get("mono"):
        out = op_mono_icon(image, e)
    elif op in ("icon", "portrait", "frame"):
        out = op_square(image, e)
    elif op == "copy":
        out = op_copy(image, e)
    elif op == "crop":
        out = op_crop(image, e)
    elif op == "tile":
        out = op_tile(image, e)
    elif op == "door":
        out = op_door(image, e, incoming / e["rim"])
    elif op == "fx":
        out = op_fx(image, e)
    else:
        raise ValueError(f"{e['id']}: unknown op {op!r}")
    return src, out


def manifest_entry(e: dict, source: dict, image: Image.Image) -> dict:
    kind = KIND_FOR_OP[e["op"]]
    entry = {
        "file": RES_PREFIX + e["out"],
        "kind": kind,
        "size": [image.width, image.height],
        "pivot": "bottom" if kind == "battler" else "center",
        "frames": 1,
        "source": source["id"],
        "license": source["license"],
    }
    if e.get("tier"):
        entry["tier"] = e["tier"]
    if e.get("nine_slice"):
        entry["nine_slice"] = e["nine_slice"]
    author = entry_author(e, source)
    if author:
        entry["author"] = author["name"]
    if e.get("tint"):
        entry["tint"] = e["tint"]
    if e.get("note"):
        entry["note"] = e["note"]
    return entry


def entry_author(e: dict, source: dict) -> dict:
    """Per-file author for multi-author sources (game-icons.net: one folder
    per author, credits.json lists them under "authors"). Empty otherwise."""
    svg = str(e.get("svg", ""))
    authors = source.get("authors", {})
    if not svg or not authors:
        return {}
    folder = svg.split("/", 1)[0]
    if folder not in authors:
        raise SystemExit(f"{e['id']}: author folder {folder!r} missing from credits.json "
                         f"source {source['id']!r} 'authors' (attribution is a licence term)")
    return authors[folder]


def csv_row(e: dict, source: dict, src: Path, root: Path, retrieved: str, image: Image.Image) -> dict:
    row = {
        "path": (ART_ROOT / e["out"]).as_posix(),
        "source": src.relative_to(root).as_posix(),
        "author": source["author"],
        "license": source["license"],
        "url": source["url"],
        "retrieved": e.get("retrieved", retrieved),
        "notes": f"{e['id']} ({e['op']} {image.width}x{image.height} via tools/normalize_art.py)",
    }
    author = entry_author(e, source)
    if author:
        # The vector original is the provenance, not the rendered PNG in between.
        row["source"] = (Path(source["incoming"]) / e["svg"]).as_posix()
        row["author"] = f"{author['name']} ({source['author']})"
        row["url"] = source["raw_base"] + e["svg"]
        row["notes"] = (f"{e['id']} (svg rendered by tools/icons/render_icons.js, "
                        f"{e['op']} {image.width}x{image.height} via tools/normalize_art.py)")
    return row


def rewrite_registry(root: Path, rows: dict[str, dict]) -> None:
    registry = root / REGISTRY
    kept: list[dict] = []
    with registry.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        if tuple(reader.fieldnames or ()) != CSV_FIELDS:
            raise SystemExit(f"{REGISTRY}: unexpected header {reader.fieldnames!r}")
        for row in reader:
            if not row["path"].startswith(ART_ROOT.as_posix() + "/"):
                kept.append(row)
    with registry.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=CSV_FIELDS, lineterminator="\n")
        writer.writeheader()
        for row in kept:
            writer.writerow(row)
        for path in sorted(rows):
            writer.writerow(rows[path])


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".", help="project root (contains assets/ and tools/)")
    parser.add_argument("--only", default="", help="build a single manifest id")
    args = parser.parse_args(argv)
    root = Path(args.root).resolve()

    spec = json.loads((root / BUILD_SPEC).read_text(encoding="utf-8"))
    credits = json.loads((root / CREDITS).read_text(encoding="utf-8"))
    sources = {s["id"]: s for s in credits["sources"]}
    retrieved = spec.get("retrieved", "")

    manifest: dict = {
        "_about": "PIPWRECK art manifest. Content id -> file. Generated by tools/normalize_art.py "
                  "from tools/art_build.json; hand edits to 'file' are allowed (swap = change the "
                  "path or replace the PNG on disk). Licences per file: assets/ASSET_LICENSES.csv; "
                  "credits text: assets/credits.json.",
    }
    rows: dict[str, dict] = {}
    built = 0
    written_files: dict[str, str] = {}
    for e in spec["entries"]:
        if "id" not in e:
            continue  # {"_comment": ...} rows that group the spec
        if args.only and e["id"] != args.only:
            continue
        source = sources.get(e["source"])
        if source is None:
            raise SystemExit(f"{e['id']}: unknown source {e['source']!r} (not in {CREDITS})")
        out_path = root / ART_ROOT / e["out"]
        if e["out"] in written_files:
            # Two ids share one file (enemy.SLAGJAW / boss.SLAGJAW): build once.
            image = load_rgba(out_path)
            src = root / source["incoming"] / e["src"]
        else:
            src, image = build_entry(root, e, source)
            out_path.parent.mkdir(parents=True, exist_ok=True)
            image.save(out_path, "PNG", optimize=True)
            written_files[e["out"]] = e["id"]
            rows[(ART_ROOT / e["out"]).as_posix()] = csv_row(e, source, src, root, retrieved, image)
            built += 1
        manifest[e["id"]] = manifest_entry(e, source, image)
        print(f"{e['id']:<26} {e['out']:<30} {image.width}x{image.height}  {source['license']}")

    if args.only:
        print(f"built {built} file(s); manifest and registry NOT rewritten for --only")
        return 0

    (root / MANIFEST).write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    rewrite_registry(root, rows)
    ids = [k for k in manifest if not k.startswith("_")]
    print(f"built {built} file(s), {len(ids)} manifest entries -> {MANIFEST}")
    print(f"registry rows for {ART_ROOT}/: {len(rows)} -> {REGISTRY}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

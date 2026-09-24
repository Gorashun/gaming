#!/usr/bin/env python3
"""Normalise raw art from assets/incoming/ into assets/art/ and write the manifest.

Reads tools/art_build.json (what to build from which raw file) and
assets/credits.json (who made it, under which licence), then:

  1. writes one normalised PNG per entry to assets/art/<category>/<id>.png
     (transparent margins trimmed, scaled to the target size, RGBA),
  2. writes assets/art/manifest.json (content id -> file, kind, size, pivot,
     frames, source, license), the file src/game/ui/art.gd reads,
  3. rewrites every assets/art/ row in assets/ASSET_LICENSES.csv,
  4. keeps assets/credits.json in step with what the manifest uses (below).

Overlays (swap a whole set in one command)
------------------------------------------
An overlay is another build file with the same shape ({"entries": [...]},
optionally "defaults": {...} merged into every entry of that overlay).
Its entries replace the base entries with the same id. Two ways to apply one:

    python3 tools/normalize_art.py --build tools/art_build.aekashics.json   # this run
    "enabled": true in the overlay file (listed under "overlays" in art_build.json)

An overlay entry whose raw file is missing is skipped with a notice and the
base entry is built instead, so a half-downloaded pack still gives a full
game. tools/art_build.aekashics.json (Aekashics battlers) and
tools/art_build.pipoya.json (the M6 Pipoya set, rollback) are overlays.

Credits follow the manifest
---------------------------
assets/credits.json has "sources" (shown on the credits screen) and
"pending_sources" (known, not shown). After a full build:
  - a pending source that the manifest now uses moves to "sources";
  - a source marked "only_while_used": true that no manifest entry uses any
    more moves back to "pending_sources".
So a licence that says "credit while the art is in the build" (Aekashics)
holds by construction. --only never touches credits, manifest or registry.

Optional entry keys
-------------------
  "display_h": N   manifest "scale" = N / output height, i.e. the figure stands
                   in the corridor as tall as an N px image would (the battler
                   world scale is fixed per pixel, enemy_battler.gd). Lets a
                   512 px source keep its resolution without becoming a giant.
  "url": "..."     per-file URL for the ASSET_LICENSES.csv row (else the source's).
  "grade": {...}   Pillow colour grade, see grade() below. OFF by default.

Palette grading is normally NOT done here: ART_DIRECTION_V2 section 4 is
applied at runtime by the Godot shaders (battler.gdshader: light_tint, torch
rim, optional palette LUT), so the files stay neutral and replaceable. Turn
"grade" on for an entry only when
  (a) the art is shown somewhere without the battler shader (a 2D screen,
      credits, store screenshots) and must still look SOTLJUS, or
  (b) the source palette is so far from SOTLJUS (saturated, bright, warm-lit
      from the wrong side) that the runtime grade cannot pull it in.
For (b) keep it mild and set "rim": 0 if the shader rim is on, or the edge
gets lit twice.

The contract of the manifest: replace a file on disk under the same name, or
point "file" at another PNG, and the game shows the new art. No code change.

Requires Pillow (python3 -c "import PIL"). No other dependency.
Test: python3 tools/test_normalize_art.py

Usage:
    python3 tools/normalize_art.py            # from rogelike_app/
    python3 tools/normalize_art.py --root DIR
    python3 tools/normalize_art.py --only enemy.RUST_RAT   # one entry
    python3 tools/normalize_art.py --build tools/art_build.aekashics.json
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path

try:
    from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter
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


# --- Grade (optional, ART_DIRECTION_V2 section 4) ---------------------------

GRADE_DEFAULTS = {
    "desaturate": 0.30,          # 0..1, share of colour removed
    "contrast": 1.12,            # 1 = unchanged
    "cool_shadows": 0.35,        # 0..1, how far the darks move toward soot blue-grey
    "shadow_color": "#2c3a48",   # "sot": cold blue-grey shadow
    "rim": 0.5,                  # 0..1, warm torch rim on the lit edge; 0 = off
    "rim_color": "#ff6a2c",      # "eld"
    "rim_from": [0.72, -0.69],   # screen vector toward the torch (y down): upper right
    "rim_px": 3,                 # rim width in output pixels
}


def _hex_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16)


def grade(image: Image.Image, params: dict | bool) -> Image.Image:
    """SOTLJUS grade with Pillow: desaturate, contrast, cold darks, warm rim.

    params is True (defaults) or a dict overriding GRADE_DEFAULTS. Alpha is
    never changed, so trim, pivot and the game's silhouette pass still match.
    """
    p = dict(GRADE_DEFAULTS)
    if isinstance(params, dict):
        p.update(params)
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    rgb = rgba.convert("RGB")
    if p["desaturate"] > 0:
        rgb = ImageEnhance.Color(rgb).enhance(max(0.0, 1.0 - float(p["desaturate"])))
    if p["contrast"] != 1:
        rgb = ImageEnhance.Contrast(rgb).enhance(float(p["contrast"]))
    if p["cool_shadows"] > 0:
        # Mask = how dark the pixel is (1 at black, 0 from mid-grey up).
        luma = rgb.convert("L")
        strength = float(p["cool_shadows"])
        mask = luma.point(lambda v: int(max(0.0, 1.0 - v / 128.0) * 255 * strength))
        cold = Image.new("RGB", rgb.size, _hex_rgb(p["shadow_color"]))
        # Keep the value, take the hue: multiply-ish blend toward the cold colour.
        tinted = ImageChops.multiply(rgb, cold.point(lambda v: min(255, v * 3)))
        tinted = Image.blend(tinted, rgb, 0.5)
        rgb = Image.composite(tinted, rgb, mask)
    if p["rim"] > 0:
        dx, dy = p["rim_from"]
        norm = max(1e-6, (dx * dx + dy * dy) ** 0.5)
        step = float(p["rim_px"])
        ox, oy = round(dx / norm * step), round(dy / norm * step)
        # Opaque here, transparent one step toward the torch = the lit edge.
        shifted = Image.new("L", alpha.size, 0)
        shifted.paste(alpha, (-ox, -oy))
        edge = ImageChops.subtract(alpha, shifted)
        edge = edge.filter(ImageFilter.GaussianBlur(max(0.5, step / 3)))
        edge = ImageChops.multiply(edge, alpha)
        edge = edge.point(lambda v: int(v * float(p["rim"])))
        rim_layer = Image.new("RGB", rgb.size, _hex_rgb(p["rim_color"]))
        rgb = ImageChops.add(rgb, ImageChops.multiply(rim_layer, Image.merge("RGB", (edge, edge, edge))))
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out


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
    if e.get("grade"):
        out = grade(out, e["grade"])
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
    if e.get("display_h"):
        entry["scale"] = round(float(e["display_h"]) / image.height, 4)
    if e.get("nine_slice"):
        entry["nine_slice"] = e["nine_slice"]
    if e.get("note"):
        entry["note"] = e["note"]
    return entry


def csv_row(e: dict, source: dict, src: Path, root: Path, retrieved: str, image: Image.Image) -> dict:
    return {
        "path": (ART_ROOT / e["out"]).as_posix(),
        "source": src.relative_to(root).as_posix(),
        "author": source["author"],
        "license": source["license"],
        "url": e.get("url", source["url"]),
        "retrieved": e.get("retrieved", retrieved),
        "notes": f"{e['id']} ({e['op']} {image.width}x{image.height} via tools/normalize_art.py)",
    }


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


# --- Overlays ---------------------------------------------------------------


def load_spec(root: Path, builds: list[str]) -> tuple[dict, list[dict], list[str]]:
    """Base spec plus overlays. Returns (base spec, entries, applied overlay names).

    Overlay entries carry "_overlay", "_fallback" (the base entry with the same
    id, if any) and "_retrieved" (the overlay's date), private to this script.
    """
    spec = json.loads((root / BUILD_SPEC).read_text(encoding="utf-8"))
    entries: list[dict] = [dict(e) for e in spec["entries"]]
    explicit = [Path(b).as_posix() for b in builds]
    candidates: list[str] = []
    for name in list(spec.get("overlays", [])) + explicit:
        if name not in candidates:
            candidates.append(name)
    applied: list[str] = []
    for name in candidates:
        path = Path(name) if Path(name).is_absolute() else root / name
        if not path.is_file():
            if name in explicit:
                raise SystemExit(f"--build {name}: file not found")
            continue
        overlay = json.loads(path.read_text(encoding="utf-8"))
        if not overlay.get("enabled", False) and name not in explicit:
            continue
        index = {e["id"]: n for n, e in enumerate(entries)}
        defaults = overlay.get("defaults", {})
        for raw in overlay.get("entries", []):
            # "defaults" = keys shared by every entry (strip_shadow, grade ...).
            e = {**defaults, **raw}
            e["_overlay"] = name
            if "retrieved" not in e:
                # "" = not filled in yet; checked when the entry is really built.
                e["_retrieved"] = overlay.get("retrieved", spec.get("retrieved", ""))
            if e["id"] in index:
                e["_fallback"] = entries[index[e["id"]]]
                entries[index[e["id"]]] = e
            else:
                entries.append(e)
        applied.append(name)
    return spec, entries, applied


def raw_path(root: Path, e: dict, sources: dict[str, dict]) -> Path:
    source = sources.get(e["source"])
    if source is None:
        raise SystemExit(f"{e['id']}: unknown source {e['source']!r} (not in {CREDITS})")
    return root / source["incoming"] / e["src"]


def resolve_entry(root: Path, e: dict, sources: dict[str, dict]) -> dict:
    """An overlay entry whose raw file is missing falls back to the base entry."""
    while "_overlay" in e and not raw_path(root, e, sources).is_file():
        fallback = e.get("_fallback")
        missing = raw_path(root, e, sources).relative_to(root).as_posix()
        print(f"note: {e['id']}: {missing} missing, overlay {e['_overlay']} skipped for this id"
              + ("" if fallback else " (no base entry either)"))
        if fallback is None:
            return {}
        e = fallback
    return e


# --- Credits sync -------------------------------------------------------------


def dump_credits(data: dict) -> str:
    """Same layout as the hand-written file: sections one per line, rest indent 2."""
    out = ["{"]
    keys = list(data)
    for n, key in enumerate(keys):
        value = data[key]
        comma = "," if n < len(keys) - 1 else ""
        if key == "sections":
            out.append(f'  "{key}": [')
            for m, section in enumerate(value):
                out.append("    " + json.dumps(section, ensure_ascii=False) + ("," if m < len(value) - 1 else ""))
            out.append("  ]" + comma)
        else:
            body = json.dumps(value, indent=2, ensure_ascii=False).replace("\n", "\n  ")
            out.append(f'  "{key}": {body}{comma}')
    out.append("}")
    return "\n".join(out) + "\n"


def sync_credits(credits: dict, used: set[str]) -> list[str]:
    """Move sources between "sources" and "pending_sources" (see module doc).

    Mutates credits; returns human-readable changes (empty = nothing moved).
    """
    active: list[dict] = list(credits.get("sources", []))
    pending: list[dict] = list(credits.get("pending_sources", []))
    changes: list[str] = []
    for source in list(pending):
        if source["id"] in used:
            pending.remove(source)
            active.append(source)
            changes.append(f"credits: {source['id']} is used -> shown (sources)")
    for source in list(active):
        if source.get("only_while_used") and source["id"] not in used:
            active.remove(source)
            pending.append(source)
            changes.append(f"credits: {source['id']} no longer used -> pending_sources (not shown)")
    if changes:
        credits["sources"] = active
        credits["pending_sources"] = pending
    return changes


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", default=".", help="project root (contains assets/ and tools/)")
    parser.add_argument("--only", default="", help="build a single manifest id")
    parser.add_argument("--build", action="append", default=[], metavar="FILE",
                        help="apply an overlay build file (repeatable), e.g. tools/art_build.aekashics.json")
    args = parser.parse_args(argv)
    root = Path(args.root).resolve()

    spec, entries, applied = load_spec(root, args.build)
    credits = json.loads((root / CREDITS).read_text(encoding="utf-8"))
    sources = {s["id"]: s for s in credits.get("pending_sources", [])}
    sources.update({s["id"]: s for s in credits.get("sources", [])})
    retrieved = spec.get("retrieved", "")
    for name in applied:
        print(f"overlay: {name}")

    manifest: dict = {
        "_about": "PIPWRECK art manifest. Content id -> file. Generated by tools/normalize_art.py "
                  "from tools/art_build.json; hand edits to 'file' are allowed (swap = change the "
                  "path or replace the PNG on disk). Licences per file: assets/ASSET_LICENSES.csv; "
                  "credits text: assets/credits.json.",
    }
    rows: dict[str, dict] = {}
    built = 0
    written_files: dict[str, str] = {}
    used_sources: set[str] = set()
    # Resolve and validate everything before the first file is written.
    resolved: list[dict] = []
    for e in entries:
        if args.only and e["id"] != args.only:
            continue
        e = resolve_entry(root, e, sources)
        if not e:
            continue
        if e["source"] not in sources:
            raise SystemExit(f"{e['id']}: unknown source {e['source']!r} (not in {CREDITS})")
        if not e.get("_retrieved", retrieved):
            raise SystemExit(f"{e['id']}: overlay {e.get('_overlay')} has no \"retrieved\" date; "
                             "set it (YYYY-MM-DD, the day the files were downloaded) and run again")
        resolved.append(e)
    for e in resolved:
        source = sources[e["source"]]
        out_path = root / ART_ROOT / e["out"]
        if e["out"] in written_files:
            # Two ids share one file (enemy.SLAGJAW / boss.SLAGJAW): build once.
            image = load_rgba(out_path)
            src = root / source["incoming"] / e["src"]
        else:
            row_date = e.get("_retrieved", retrieved)
            src, image = build_entry(root, e, source)
            out_path.parent.mkdir(parents=True, exist_ok=True)
            image.save(out_path, "PNG", optimize=True)
            written_files[e["out"]] = e["id"]
            rows[(ART_ROOT / e["out"]).as_posix()] = csv_row(e, source, src, root, row_date, image)
            built += 1
        manifest[e["id"]] = manifest_entry(e, source, image)
        used_sources.add(source["id"])
        print(f"{e['id']:<26} {e['out']:<30} {image.width}x{image.height}  {source['license']}")

    if args.only:
        print(f"built {built} file(s); manifest, registry and credits NOT rewritten for --only")
        return 0

    (root / MANIFEST).write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    rewrite_registry(root, rows)
    changes = sync_credits(credits, used_sources)
    for change in changes:
        print(change)
    if changes:
        (root / CREDITS).write_text(dump_credits(credits), encoding="utf-8")
    ids = [k for k in manifest if not k.startswith("_")]
    print(f"built {built} file(s), {len(ids)} manifest entries -> {MANIFEST}")
    print(f"registry rows for {ART_ROOT}/: {len(rows)} -> {REGISTRY}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

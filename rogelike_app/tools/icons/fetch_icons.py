#!/usr/bin/env python3
"""Fetch game-icons.net SVGs listed in tools/art_build.json into assets/incoming/game-icons/.

Every entry in tools/art_build.json with "source": "game-icons" names its
vector source in "svg" as "<author>/<name>.svg" (the folder layout of
https://github.com/game-icons/icons). This script downloads each one from
raw.githubusercontent.com (github.com HTML and api.github.com are blocked by
the agent proxy; raw works), strips the black 512x512 background rectangle
every game-icons SVG starts with, and stores it as

    assets/incoming/game-icons/<author>/<name>.svg

It also stores the upstream license.txt and rewrites
assets/incoming/game-icons/manifest.csv (author, name, url, retrieved) so the
provenance of every committed SVG is one file away.

Licence: CC BY 3.0 (a few authors CC0, see license.txt). Attribution per
author lives in assets/credits.json (source "game-icons").

Next steps after this script:
    NODE_PATH=/opt/node22/lib/node_modules node tools/icons/render_icons.js
    python3 tools/normalize_art.py
    python3 tools/check_asset_licenses.py

Usage (from rogelike_app/):
    python3 tools/icons/fetch_icons.py            # fetch what is missing
    python3 tools/icons/fetch_icons.py --force    # re-download everything
    python3 tools/icons/fetch_icons.py --probe lorc/anvil sbed/fire   # 200/404 only
"""

from __future__ import annotations

import argparse
import csv
import datetime as _dt
import json
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

RAW_BASE = "https://raw.githubusercontent.com/game-icons/icons/master/"
LICENSE_URL = RAW_BASE + "license.txt"
BUILD_SPEC = Path("tools/art_build.json")
INCOMING = Path("assets/incoming/game-icons")
SOURCE_ID = "game-icons"

# The background every game-icons SVG carries: <path d="M0 0h512v512H0z"/>,
# sometimes with fill/fill-opacity attributes.
_BG_RECT = re.compile(r'<path[^>]*\bd="M0 0h512v512H0z"[^>]*/>')


def _get(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": "pipwreck-fetch-icons/1"})
    with urllib.request.urlopen(request, timeout=30) as response:  # noqa: S310 (fixed https host)
        return response.read()


def _status(url: str) -> int:
    try:
        _get(url)
        return 200
    except urllib.error.HTTPError as err:
        return err.code
    except urllib.error.URLError:
        return -1


def strip_background(svg: str) -> str:
    """Remove the black full-canvas rectangle; keep the white icon path(s)."""
    out, count = _BG_RECT.subn("", svg, count=1)
    if count == 0:
        raise ValueError("no 512x512 background rectangle found (format changed upstream?)")
    if 'viewBox="0 0 512 512"' not in out:
        raise ValueError("unexpected viewBox (expected 0 0 512 512)")
    if "<path" not in out:
        raise ValueError("no icon path left after stripping the background")
    return out


def wanted_svgs(root: Path) -> list[str]:
    spec = json.loads((root / BUILD_SPEC).read_text(encoding="utf-8"))
    names: list[str] = []
    for entry in spec["entries"]:
        if entry.get("source") != SOURCE_ID:
            continue
        svg = str(entry.get("svg", ""))
        if not re.fullmatch(r"[a-z0-9-]+/[a-z0-9-]+\.svg", svg):
            raise SystemExit(f"{entry['id']}: 'svg' must look like author/name.svg, got {svg!r}")
        if svg not in names:
            names.append(svg)
    return names


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", default=".", help="project root (contains tools/ and assets/)")
    parser.add_argument("--force", action="store_true", help="re-download files that already exist")
    parser.add_argument("--probe", nargs="*", default=None, metavar="AUTHOR/NAME",
                        help="only print the HTTP status for these icons and exit")
    args = parser.parse_args(argv)
    root = Path(args.root).resolve()

    if args.probe is not None:
        for name in args.probe:
            name = name.removesuffix(".svg")
            print(f"{_status(RAW_BASE + name + '.svg'):>4}  {name}")
        return 0

    incoming = root / INCOMING
    incoming.mkdir(parents=True, exist_ok=True)
    today = _dt.date.today().isoformat()

    license_path = incoming / "license.txt"
    if args.force or not license_path.is_file():
        license_path.write_bytes(_get(LICENSE_URL))
        print(f"fetched  license.txt")

    rows: list[dict] = []
    fetched = 0
    failed: list[str] = []
    for svg in wanted_svgs(root):
        target = incoming / svg
        url = RAW_BASE + svg
        if args.force or not target.is_file():
            try:
                text = strip_background(_get(url).decode("utf-8"))
            except (urllib.error.URLError, ValueError) as err:
                failed.append(f"{svg}: {err}")
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(text, encoding="utf-8")
            fetched += 1
            print(f"fetched  {svg}")
        author, name = svg.removesuffix(".svg").split("/")
        rows.append({"author": author, "name": name, "url": url,
                     "page": f"https://game-icons.net/1x1/{author}/{name}.html", "retrieved": today})

    manifest = incoming / "manifest.csv"
    previous: dict[str, str] = {}
    if manifest.is_file():
        with manifest.open(newline="", encoding="utf-8") as handle:
            for row in csv.DictReader(handle):
                previous[f"{row['author']}/{row['name']}"] = row.get("retrieved", "")
    with manifest.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=("author", "name", "url", "page", "retrieved"),
                                lineterminator="\n")
        writer.writeheader()
        for row in sorted(rows, key=lambda r: (r["author"], r["name"])):
            key = f"{row['author']}/{row['name']}"
            if not args.force and previous.get(key):
                row["retrieved"] = previous[key]
            writer.writerow(row)

    print(f"{fetched} fetched, {len(rows)} listed in {manifest.relative_to(root)}")
    if failed:
        print("FAILED:")
        for line in failed:
            print(f"  - {line}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

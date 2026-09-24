#!/usr/bin/env python3
"""Download the game-icons.net SVGs that tools/shade_monsters/shades.json names.

game-icons.net is CC BY 3.0 (per-author attribution, see license.txt). The
only host the build proxy lets through is raw.githubusercontent.com, so the
files come straight from github.com/game-icons/icons (branch master):

    <BASE>/<author>/<name>.svg  ->  assets/incoming/game-icons-shades/svg/<author>__<name>.svg
    <BASE>/license.txt          ->  assets/incoming/game-icons-shades/license.txt

Then (optionally, --render) runs render_shades.js, which writes
assets/incoming/game-icons-shades/<ID>.png. After that:

    python3 tools/normalize_art.py      # -> assets/art/, manifest, ASSET_LICENSES.csv
    python3 tools/check_asset_licenses.py

Usage (from rogelike_app/):
    python3 tools/shade_monsters/fetch_shades.py            # download what is missing
    python3 tools/shade_monsters/fetch_shades.py --force    # download everything again
    python3 tools/shade_monsters/fetch_shades.py --render   # ... and render the PNGs
    python3 tools/shade_monsters/fetch_shades.py --prune    # delete SVGs no shade uses

Environment for --render: node with playwright on NODE_PATH and a Chromium in
PLAYWRIGHT_BROWSERS_PATH (defaults below match the dev container).
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import urllib.request
from pathlib import Path

BASE = "https://raw.githubusercontent.com/game-icons/icons/master"
HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
SPEC = HERE / "shades.json"
DEFAULT_ENV = {
    "NODE_PATH": "/opt/node22/lib/node_modules",
    "PLAYWRIGHT_BROWSERS_PATH": "/opt/pw-browsers",
}


def fetch(url: str) -> bytes:
    with urllib.request.urlopen(url, timeout=30) as response:
        if response.status != 200:
            raise RuntimeError(f"{url}: HTTP {response.status}")
        return response.read()


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--force", action="store_true", help="download even if the file exists")
    parser.add_argument("--render", action="store_true", help="run render_shades.js afterwards")
    parser.add_argument("--prune", action="store_true", help="delete SVGs in svg_dir that no shade uses")
    args = parser.parse_args(argv)

    spec = json.loads(SPEC.read_text(encoding="utf-8"))
    svg_dir = ROOT / spec["svg_dir"]
    out_dir = ROOT / spec["out_dir"]
    svg_dir.mkdir(parents=True, exist_ok=True)

    wanted: set[str] = set()
    for shade in spec["shades"]:
        icon = shade["icon"]
        author, name = icon.split("/")
        target = svg_dir / f"{author}__{name}.svg"
        wanted.add(target.name)
        if target.is_file() and not args.force:
            print(f"have   {icon}")
            continue
        data = fetch(f"{BASE}/{icon}.svg")
        if b"<svg" not in data[:200]:
            raise SystemExit(f"{icon}: not an SVG")
        target.write_bytes(data)
        print(f"fetch  {icon} ({len(data)} bytes)")

    licence = out_dir / "license.txt"
    if args.force or not licence.is_file():
        licence.write_bytes(fetch(f"{BASE}/license.txt"))
        print(f"fetch  license.txt -> {licence.relative_to(ROOT)}")

    if args.prune:
        for path in sorted(svg_dir.glob("*.svg")):
            if path.name not in wanted:
                path.unlink()
                print(f"prune  {path.name}")

    if args.render:
        env = dict(os.environ)
        for key, value in DEFAULT_ENV.items():
            env.setdefault(key, value)
        cmd = ["node", str(HERE / "render_shades.js")]
        print("render", " ".join(cmd))
        return subprocess.call(cmd, cwd=ROOT, env=env)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

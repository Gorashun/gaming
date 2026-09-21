#!/usr/bin/env python3
"""Rebuild assets/ASSET_LICENSES.csv from the sprite generators plus a hand
maintained table of everything that is not generated.

The generators only ever emit own-work rows for files they wrote themselves.
Third party assets are entered by hand in STATIC_ROWS below with real
provenance (source, author, license, url, retrieved) - this script never
invents a license for a file it did not create, and tools/check_asset_licenses.py
still fails the build if a file on disk has no row here.

Run:  python3 tools/build_asset_csv.py      (from rogelike_app/)
"""

from __future__ import annotations

import csv
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import gen_dice_sprites  # noqa: E402
import gen_pixel_assets  # noqa: E402

FIELDS = ("path", "source", "author", "license", "url", "retrieved", "notes")

# Assets that are not produced by a generator. Add third party files here with
# their real provenance; never with a guessed license.
STATIC_ROWS: tuple[dict[str, str], ...] = (
    {
        "path": "assets/icon.svg",
        "source": "PIPWRECK repo",
        "author": "PIPWRECK UI",
        "license": "own-work",
        "url": "",
        "retrieved": "2026-09-21",
        "notes": "App-ikon ritad i projektet. Godots standardikon anvands inte.",
    },
)

OWN_WORK = {
    "author": "PIPWRECK UI",
    "license": "own-work",
    "url": "",
    "retrieved": "2026-09-21",
}


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    rows: list[dict[str, str]] = list(STATIC_ROWS)

    for module in (gen_pixel_assets, gen_dice_sprites):
        source = f"tools/{module.__name__}.py"
        for path, note in module.generate(root):
            rows.append({"path": path, "source": source, "notes": note, **OWN_WORK})

    rows.sort(key=lambda r: r["path"])
    out = root / "assets" / "ASSET_LICENSES.csv"
    with out.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDS, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    print(f"wrote {out.relative_to(root)} with {len(rows)} rows")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

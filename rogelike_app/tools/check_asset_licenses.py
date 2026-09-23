#!/usr/bin/env python3
"""Verify that every asset under assets/ has a license row in ASSET_LICENSES.csv.

PIPWRECK license rule (DECISIONS.md 2026-09-21, ASSET_SHOPPING_LIST_PAINTED
section 0): only CC0, OGA-BY, CC-BY 3.0/4.0, OFL (fonts), purchased
royalty-free, a creator's own commercial-free licence (proprietary-free, e.g.
Pipoya: "commercial or personal use, edit freely, no redistribution") or own
work may enter the repository. CC-BY-SA (any version) and GPL are forbidden.

assets/incoming/ is the raw inbox (.gdignore, never shipped, only KALLA.txt
and licence files are committed) and is therefore not scanned.

Exit codes:
    0  every asset is registered and every license is allowed
    1  at least one problem was found (missing row, bad license, stale row)

Usage:
    python3 tools/check_asset_licenses.py            # run from rogelike_app/
    python3 tools/check_asset_licenses.py --root DIR # explicit project root
"""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

# --- Policy ---------------------------------------------------------------

ALLOWED_LICENSES: tuple[str, ...] = (
    "CC0-1.0",
    "OGA-BY-3.0",
    "CC-BY-3.0",
    "CC-BY-4.0",
    "proprietary-free",
    "OFL-1.1",
    "proprietary-purchased",
    "own-work",
)

# Licenses we explicitly refuse, so the error message can be specific.
FORBIDDEN_HINTS: tuple[str, ...] = (
    "CC-BY-SA",
    "GPL",
    "AGPL",
    "LGPL",
    "CC-BY-NC",
    "CC-BY-ND",
    "unknown",
)

# File types that count as assets and therefore need a row.
ASSET_SUFFIXES: frozenset[str] = frozenset(
    {
        # images
        ".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp", ".svg", ".aseprite", ".ase",
        # audio
        ".wav", ".ogg", ".mp3", ".flac",
        # fonts
        ".ttf", ".otf", ".woff", ".woff2", ".fnt",
    }
)

# Bookkeeping files that live next to assets but are not assets.
IGNORED_SUFFIXES: frozenset[str] = frozenset({".import", ".md", ".csv", ".txt", ".uid", ".json"})
IGNORED_NAMES: frozenset[str] = frozenset({".gitkeep", ".gitignore", ".DS_Store"})

CSV_FIELDS: tuple[str, ...] = ("path", "source", "author", "license", "url", "retrieved", "notes")

REGISTRY_PATH = Path("assets/ASSET_LICENSES.csv")
ASSET_ROOT = Path("assets")
# Raw inbox: unpacked packages live here before tools/normalize_art.py moves
# the files we actually use into assets/art/. Never imported by Godot.
EXCLUDED_DIRS: tuple[str, ...] = ("assets/incoming",)


# --- Helpers --------------------------------------------------------------


def is_asset(path: Path) -> bool:
    if path.name in IGNORED_NAMES:
        return False
    suffix = path.suffix.lower()
    if suffix in IGNORED_SUFFIXES:
        return False
    return suffix in ASSET_SUFFIXES


def collect_assets(root: Path) -> list[Path]:
    base = root / ASSET_ROOT
    if not base.is_dir():
        return []
    found = []
    for p in sorted(base.rglob("*")):
        if not (p.is_file() and is_asset(p)):
            continue
        rel = p.relative_to(root).as_posix()
        if any(rel == d or rel.startswith(d + "/") for d in EXCLUDED_DIRS):
            continue
        found.append(p)
    return found


def read_registry(root: Path, errors: list[str]) -> dict[str, dict[str, str]]:
    registry_file = root / REGISTRY_PATH
    if not registry_file.is_file():
        errors.append(f"registry missing: {REGISTRY_PATH} does not exist")
        return {}

    rows: dict[str, dict[str, str]] = {}
    with registry_file.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        header = tuple(reader.fieldnames or ())
        if header != CSV_FIELDS:
            errors.append(
                f"{REGISTRY_PATH}: header is {header!r}, expected {CSV_FIELDS!r}"
            )
            return {}
        for line_no, row in enumerate(reader, start=2):
            key = (row.get("path") or "").strip()
            if not key:
                errors.append(f"{REGISTRY_PATH}:{line_no}: empty path column")
                continue
            if key in rows:
                errors.append(f"{REGISTRY_PATH}:{line_no}: duplicate row for {key}")
                continue
            rows[key] = {k: (row.get(k) or "").strip() for k in CSV_FIELDS}
            rows[key]["__line"] = str(line_no)
    return rows


def check_row(key: str, row: dict[str, str], errors: list[str]) -> None:
    line = row.get("__line", "?")
    where = f"{REGISTRY_PATH}:{line} ({key})"

    license_id = row["license"]
    if license_id not in ALLOWED_LICENSES:
        hint = ""
        for bad in FORBIDDEN_HINTS:
            if bad.lower() in license_id.lower():
                hint = f" -- {bad} is forbidden by DECISIONS.md"
                break
        errors.append(
            f"{where}: license {license_id!r} is not allowed{hint}. "
            f"Allowed: {', '.join(ALLOWED_LICENSES)}"
        )

    for field in ("source", "author", "retrieved"):
        if not row[field]:
            errors.append(f"{where}: column {field!r} must not be empty")

    if license_id != "own-work" and not row["url"]:
        errors.append(f"{where}: column 'url' is required for third party assets")


# --- Main -----------------------------------------------------------------


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        default=".",
        help="project root that contains assets/ (default: current directory)",
    )
    args = parser.parse_args(argv)
    root = Path(args.root).resolve()

    errors: list[str] = []
    registry = read_registry(root, errors)
    assets = collect_assets(root)

    asset_keys = set()
    for asset in assets:
        key = asset.relative_to(root).as_posix()
        asset_keys.add(key)
        if key not in registry:
            errors.append(
                f"{key}: no row in {REGISTRY_PATH}. "
                "Every image, sound and font under assets/ must be registered."
            )

    for key, row in registry.items():
        if key.startswith("__"):
            continue
        check_row(key, row, errors)
        if key not in asset_keys and not (root / key).is_file():
            errors.append(
                f"{REGISTRY_PATH}:{row.get('__line', '?')}: stale row, "
                f"{key} does not exist on disk"
            )

    print(f"assets scanned: {len(assets)}")
    print(f"registry rows:  {len(registry)}")

    if errors:
        print(f"FAIL: {len(errors)} problem(s)")
        for err in errors:
            print(f"  - {err}")
        return 1

    licenses: dict[str, int] = {}
    for row in registry.values():
        licenses[row["license"]] = licenses.get(row["license"], 0) + 1
    summary = ", ".join(f"{name} x{count}" for name, count in sorted(licenses.items()))
    print(f"licenses:       {summary}")
    print("OK: every asset is registered with an allowed license")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

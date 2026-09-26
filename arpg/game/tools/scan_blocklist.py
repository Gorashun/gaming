#!/usr/bin/env python3
"""Scan every player-facing string in content/base against docs/legal/BLOCKLIST.md.

Terms are parsed from the BLOCKLIST bullet lists (comma-separated names after the bold label) and from the
first column of the §7 table, plus a few extra phrases. Generic words the BLOCKLIST explicitly allows
(§8: Common, Magic, Rare, Epic, Legendary, Mythic, Unique, Set, Named, Hardcore, Seasons, ...) are skipped.
Usage: python3 tools/scan_blocklist.py [--all]   (--all also prints hits in writer-owned text tables)
Exit 1 if a designer-owned table has a hit.
"""
import json
import os
import re
import sys

GAME = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BL = os.path.join(os.path.dirname(GAME), "docs", "legal", "BLOCKLIST.md")
BASE = os.path.join(GAME, "content", "base")
WRITER = {"lore.json", "npc_text.json", "main_quest_text.json", "deeds_text.json", "names.json"}
SKIP_KEYS = {"id", "model", "path", "prop", "icon", "anim", "sfx", "text_ref", "stat", "type", "kind", "slot", "family", "biome", "hook"}
GENERIC = {"common", "magic", "rare", "epic", "legendary", "mythic", "unique", "set", "named", "hardcore", "seasons", "normal", "hell",
           "chaos", "blight", "breach", "legion", "harvest", "ritual", "expedition", "heist", "delve", "sentinel", "destroyer", "crucible",
           "ember", "the vault", "old world", "the warp", "the pit", "ancient", "sacred", "leah", "atlas passive tree", "imperium",
           "soldier", "demolitionist", "occultist", "nightblade", "arcanist", "shaman", "inquisitor", "necromancer", "oathkeeper",
           "engineer", "berserker", "outlander", "vanquisher", "cairn", "bat", "the butcher", "rift"}
EXTRA = [r"\bdevotion\b", r"\bforging potential\b", r"\bkitava\b", r"\briftgate\b", r"\bembermage\b", r"\bgreater rifts?\b", r"\bnephalem\b", r"\brifts?\b", r"\bparagon\b", r"\btorment\b", r"\bnightmare\b", r"\bember\b(?! ?(?:ly|s? of|glow))", r"\bcube\b", r"\bgoblin\b", r"\bvault\b"]


def terms():
    t = set()
    txt = open(BL, encoding="utf-8").read()
    for line in txt.splitlines():
        m = re.match(r"^- \*\*[^*]+:\*\*\s*(.+)$", line.strip()) or re.match(r"^- (.+)$", line.strip())
        if m and not line.strip().startswith("- **Verdict") and "Note" not in line[:12]:
            for part in re.split(r"[,;]| / |\(|\)", m.group(1)):
                p = re.sub(r"\*|“|”|\"|\.$", "", part).strip()
                p = re.sub(r"\s+as .*$", "", p)
                if 3 <= len(p) <= 40 and not p.lower().startswith(("the grim dawn", "any quoted", "do not", "the single", "not d2", "ours", "avoid", "industry")):
                    if p.lower() not in GENERIC and re.search(r"[A-Za-z]", p):
                        t.add(p)
        m = re.match(r"^\| \"?([^|\"]+)\"? \|", line)
        if m and "Term" not in m.group(1) and "---" not in m.group(1):
            p = m.group(1).strip().strip('"')
            if p.lower() not in GENERIC and len(p) > 3:
                t.add(p)
    return sorted(t)


def strings(o, path=""):
    if isinstance(o, dict):
        for k, v in o.items():
            if k in SKIP_KEYS:
                continue
            yield from strings(v, f"{path}.{k}")
    elif isinstance(o, list):
        for i, v in enumerate(o):
            yield from strings(v, f"{path}[{i}]")
    elif isinstance(o, str):
        yield path, o


def main():
    show_all = "--all" in sys.argv
    T = terms()
    pats = [re.compile(r"\b" + re.escape(x) + r"\b", re.I) for x in T] + [re.compile(p, re.I) for p in EXTRA]
    bad = 0
    for f in sorted(os.listdir(BASE)):
        if not f.endswith(".json"):
            continue
        writer = f in WRITER
        if writer and not show_all:
            continue
        data = json.load(open(os.path.join(BASE, f)))
        for rec in data if isinstance(data, list) else [data]:
            rid = rec.get("id", "?") if isinstance(rec, dict) else "?"
            for path, s in strings(rec):
                for p in pats:
                    if p.search(s):
                        print(f"{'WRITER ' if writer else 'HIT    '}{f}:{rid}{path}: '{s[:90]}'  ~ /{p.pattern}/")
                        if not writer:
                            bad += 1
                        break
    print(f"scan_blocklist: {len(T)} terms, {bad} hits in designer-owned tables")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())

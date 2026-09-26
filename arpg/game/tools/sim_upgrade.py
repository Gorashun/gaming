#!/usr/bin/env python3
"""Gold/material sink model for Item Upgrade (+0..+15, config/upgrade) and Skill Mastery (config/skill_mastery).

Income model: gold from drops (loot.gd formula, averaged by tools/sim_loot.py) + selling non-kept items
(inventory_ops.sell_value = (5 + 2*ilvl) * 2.2^rank) for SELL_SHARE of Common/Magic/Rare drops.
Material income: glowcoal from config loot kinds (sim_loot), salvage of the rest.
Usage: python3 tools/sim_upgrade.py [--check]
"""
import argparse
import json
import os
import sys

GAME = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(GAME, "content", "base")
SELL_SHARE = 0.5
DROPS_PER_MIN = {"common": 1.64, "magic": 1.18, "rare": 0.34}   # sim_loot Tier-1 result
GOLD_DROPS_PER_MIN_AT = {8: 125}                                  # sim_loot at monster level ~8


def cfg():
    return {r["id"]: r for r in json.load(open(os.path.join(BASE, "config.json")))}


def gold_per_hour(level, tier_gold=1.0):
    drop = GOLD_DROPS_PER_MIN_AT[8] * (4.0 + 1.6 * level) / (4.0 + 1.6 * 8)   # loot.gd gold scales with monster level; calibrated to sim_loot
    sell = sum(n * SELL_SHARE * (5 + 2 * level) * 2.2 ** r for r, n in zip(range(3), DROPS_PER_MIN.values()))
    return (drop * tier_gold + sell) * 60


def upgrade_cost(c, ilvl, to_level):
    up = c["upgrade"]
    g, mats = 0.0, {}
    for L in range(1, to_level + 1):
        g += up["gold"][L - 1] * (1 + ilvl * up["gold_ilvl_mult"])
        for k, v in up["materials"][L - 1].items():
            mats[k] = mats.get(k, 0) + v
    return g, mats


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    c = cfg()
    print("Gold income estimate (gold/hour):")
    for lvl, tg in ((10, 1.0), (30, 1.0), (60, 1.5), (100, 2.2), (150, 3.6), (200, 5.7)):
        print(f"  level {lvl:3d}: {gold_per_hour(lvl, tg):10.0f}")
    print("\nItem upgrade cost (one item) and hours of gold income:")
    ok = True
    for ilvl, lvl, tg in ((10, 10, 1.0), (30, 30, 1.0), (60, 60, 1.5), (100, 100, 2.2), (190, 200, 5.7)):
        inc = gold_per_hour(lvl, tg)
        row = []
        for to in (1, 5, 10, 15):
            g, m = upgrade_cost(c, ilvl, to)
            row.append(f"+{to}: {g:9.0f}g ({g/inc:5.1f} h)")
        print(f"  ilvl {ilvl:3d}: " + " | ".join(row))
        g1, _ = upgrade_cost(c, ilvl, 1)
        g15, m15 = upgrade_cost(c, ilvl, 15)
        if g1 / inc * 60 > 10:
            ok = False
    print("  materials for +0 -> +15 (one item):", upgrade_cost(c, 60, 15)[1])
    full = upgrade_cost(c, 60, 15)[0] * 12 / gold_per_hour(60, 1.5)
    print(f"  full 12-slot set to +15 at ilvl 60: {full:.0f} h of gold income (plus {12*3} Starmotes, 12 Lanternglass)")
    sm = c["skill_mastery"]
    print("\nSkill mastery (one skill): usage XP at ~55 xp/min of active use (30 hits + 8 kills per min)")
    cum_xp, cum_g = 0.0, 0.0
    for r in range(1, sm["max_rank"] + 1):
        cum_xp += sm["xp_base"] * sm["xp_growth"] ** (r - 1)
        cum_g += sm["costs"][r - 1]["gold"]
        if r in (1, 5, 10, 15, 20):
            print(f"  rank {r:2d}: {cum_xp/55/60:6.1f} h of use, {cum_g:9.0f} gold total, cost this rank {sm['costs'][r-1]['materials']}")
    print("\nGreenlight rules: +1 costs < 10 min of income; +15 on a whole set = weeks; mastery 1-10 < ~3 h, 20 = weeks.")
    if args.check and not ok:
        print("FAIL: early upgrade too expensive")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

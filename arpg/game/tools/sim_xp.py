#!/usr/bin/env python3
"""Time-to-level simulation using the exact formulas in scripts/rpg/progression.gd and game_world.gd.

  xp_to_next(L)   = base*growth^(L-1) + lin*L                           (L < 60)
                  = (base*growth^59 + lin*60)*post60^(L-60) + 4*lin*(L-60) (L >= 60)
  monster_xp      = base_xp * (1 + S*ml)   S = config progression.monster_xp_level_scale (code constant today: 0.35) * level_diff_factor * kind_mult * tier.xp_mult
  kind_mult       = normal 1, champion 3, rare 5, boss 40 (game_world._on_monster_died)
Play model: the zone kill stream from sim_loot.zone_kills (same packs/elites/boss), ZONE_MIN minutes per zone;
Twilight monsters scale to player level - 1 (tier band), so ml = L-1 while L <= 60. After 60 the player moves
to the tier whose band fits (Nightfall -> Abyss -> Eclipse I..X), killing monsters at their own level.
QUEST_SHARE adds quest/bounty/main-quest XP as a fraction of kill XP (quests.json rewards use xp_levels; ~15 %).
Rested Glow is OFF (QA §5.4).
Usage: python3 tools/sim_xp.py [--fit] [--check]
"""
import argparse
import json
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sim_loot  # noqa: E402

QUEST_SHARE = 0.15
TARGETS = {2: (1, 3), 5: (8, 15), 10: (35, 60), 20: (120, 180), 30: (270, 420), 60: (900, 1200)}   # minutes (QA §5.4 + GDD)
LONG = {100: 56 * 60, 200: 370 * 60}   # GDD §5 estimates (minutes)
KIND_MULT = {"normal": 1.0, "champion": 3.0, "rare": 5.0, "boss": 40.0}


def xp_to_next(L, p):
    if L < 60:
        return p["xp_base"] * p["xp_growth"] ** (L - 1) + p["xp_linear"] * L
    return (p["xp_base"] * p["xp_growth"] ** 59 + p["xp_linear"] * 60) * p["xp_growth_post60"] ** (L - 60) + p["xp_linear"] * 4.0 * (L - 60)


def base_xp_per_min(C, act_n, samples=400, seed=3):
    """Average sum(base_xp*kind_mult) per minute for an act (level-independent part)."""
    rng = random.Random(seed)
    act = C.acts[f"act{act_n}"]
    zones = [C.zones[z] for z in act["zones"]]
    tot, minutes = 0.0, 0.0
    tier = C.diff["twilight"]
    for _ in range(samples):
        for z in zones:
            for m, k in sim_loot.zone_kills(C, rng, z, act, tier):
                tot += float(m.get("xp", 10)) * KIND_MULT.get(k, 1.0)
            minutes += sim_loot.BOSS_ZONE_MIN if z.get("boss") else sim_loot.ZONE_MIN
    return tot / minutes


def tier_for(L, C):
    if L < 60:
        return C.diff["twilight"]
    order = sorted(C.diff.values(), key=lambda d: d["order"])
    best = order[0]
    for d in order:
        if d["level_band"][0] <= L:
            best = d
    # stay on Nightfall 60-75, Abyss 75-100 (players push when ready)
    if L < 75:
        return C.diff["nightfall"]
    if L < 100:
        return C.diff["abyss"]
    return best


def curve(C, p, kx, ls=None):
    """Cumulative minutes to reach each level 2..200. ls = monster XP level scale (config progression.monster_xp_level_scale)."""
    if ls is None:
        ls = float(p.get("monster_xp_level_scale", 0.35))
    cum, t = {1: 0.0}, 0.0
    for L in range(1, 200):
        act_n = min(5, 1 + (L - 1) // 12) if L < 60 else 5
        tier = tier_for(L, C)
        ml = L - 1 if L < 60 else L   # post-60 monsters are at/above player level in the tier band
        f = 1.0 if ml <= L else 1.0 + min(ml - L, 5) * 0.05
        per_min = kx[act_n] * (1 + ls * ml) * f * float(tier.get("xp_mult", 1.0)) * (1 + QUEST_SHARE)
        t += xp_to_next(L, p) / per_min
        cum[L + 1] = t
    return cum


def score(cum):
    s = 0.0
    for L, (lo, hi) in TARGETS.items():
        mid = (lo + hi) / 2
        s += ((cum[L] - mid) / mid) ** 2 * (4 if not (lo <= cum[L] <= hi) else 1)
    for L, tgt in LONG.items():
        s += 0.5 * ((cum[L] - tgt) / tgt) ** 2
    return s


def walls(cum):
    bad = []
    for L in range(3, 201):
        a, b = cum[L - 1] - cum[L - 2], cum[L] - cum[L - 1]
        if a > 0 and b > 2 * a:
            bad.append(L)
    return bad


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fit", action="store_true")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--level-scale", type=float, default=None, help="override monster XP level scale (0.35 = current code constant)")
    args = ap.parse_args()
    C = sim_loot.Content()
    p = dict(C.cfg["progression"])
    if args.level_scale is not None:
        p["monster_xp_level_scale"] = args.level_scale
    kx = {a: base_xp_per_min(C, a) for a in range(1, 6)}
    print("base xp/min by act (before level scaling):", {a: round(v, 1) for a, v in kx.items()})
    if args.fit:
        best = None
        rng = random.Random(1)
        for _ in range(40000):
            q = {"xp_base": rng.uniform(50, 1500), "xp_growth": rng.uniform(1.03, 1.2), "xp_linear": rng.uniform(0, 3000),
                 "xp_growth_post60": rng.uniform(1.005, 1.04), "monster_xp_level_scale": float(p.get("monster_xp_level_scale", 0.35))}
            cum = curve(C, q, kx)
            s = score(cum) + (10 if walls(cum) else 0)
            if best is None or s < best[0]:
                best = (s, q)
        print("best fit:", {k: round(v, 4) for k, v in best[1].items()}, "score", round(best[0], 4))
        p.update(best[1])
    cum = curve(C, p, kx)
    print("params:", {k: p.get(k) for k in ("xp_base", "xp_growth", "xp_linear", "xp_growth_post60", "monster_xp_level_scale")})
    ok = True
    for L in (2, 5, 10, 15, 20, 30, 40, 50, 60, 70, 80, 100, 120, 150, 200):
        m = cum[L]
        tgt = TARGETS.get(L)
        flag = ""
        if tgt:
            flag = "OK" if tgt[0] <= m <= tgt[1] else f"OUT (target {tgt[0]}-{tgt[1]} min)"
            ok &= tgt[0] <= m <= tgt[1]
        per = cum[L] - cum[L - 1]
        print(f"  L{L:3d}: {m/60:7.2f} h ({m:8.1f} min)  last level {per:6.1f} min  {flag}")
    w = walls(cum)
    print("walls (>2x previous level time):", w or "none")
    if args.check and (not ok or w):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

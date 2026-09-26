#!/usr/bin/env python3
"""Monte-Carlo loot simulation mirroring scripts/rpg/loot.gd + items.gd (roll_kill, roll_rarity, _apply_pity).

Play model (documented in docs/design/SYSTEMS.md §Loot):
  * The player clears the act's zones in order (z1, z2, z3, boss) and repeats; each normal zone takes ZONE_MIN minutes,
    the boss zone BOSS_ZONE_MIN. Monster packs, pack sizes, elite chances and families come from content (zones/monsters).
  * Elite packs: 35 % rare (1 rare leader + normal minions), 65 % champion (every member champion) — same as game_world.gd.
  * Chests: CHESTS_PER_ZONE per zone, 20 % golden. Event surprises use events.json chances (first hit wins, like the code).
  * Scripted hooks: first elite gives +1 Rare (code); first Legendary "golden moment" at config.hooks.first_legendary_s
    (data hook for code; toggle with --no-hook).
Usage: python3 tools/sim_loot.py [--players 2000] [--minutes 180] [--tier twilight] [--act 1] [--mf 0] [--seed 1]
"""
import argparse
import json
import os
import random
import statistics
import sys

GAME = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(GAME, "content", "base")
ZONE_MIN = 4.4   # QA_REPORT T6: observed ~11 kills/min with the larger Act 1 zones
BOSS_ZONE_MIN = 3.0
CHESTS_PER_ZONE = 1.5


def load(name):
    with open(os.path.join(BASE, name)) as f:
        return {r["id"]: r for r in json.load(f)}


class Content:
    def __init__(self):
        self.rar = load("rarities.json")
        self.cfg = load("config.json")
        self.diff = load("difficulties.json")
        self.mon = load("monsters.json")
        self.zones = load("zones.json")
        self.acts = load("acts.json")
        self.events = load("events.json")
        self.kinds = self.cfg["loot"]["kinds"]
        self.drop_rar = sorted([r for r in self.rar.values() if r.get("drops", True)], key=lambda r: r["rank"])
        self.rank = {r["id"]: r["rank"] for r in self.rar.values()}


def roll_rarity(C, rng, ctx):
    mf = ctx["mf"]
    mf_eff = mf * 100.0 / (mf + 100.0) if mf > 0 else 0.0
    ents = []
    for r in C.drop_rar:
        if r.get("min_monster_level", 0) > ctx["ml"]:
            continue
        w = float(r.get("weight", 0))
        if r["rank"] >= 1:
            w *= 1.0 + mf_eff / 100.0 * float(r.get("mf_scale", 1.0))
        w *= float(ctx["tier_bonus"].get(r["id"], 1.0))
        w *= float(ctx["source_bonus"].get(r["id"], 1.0))
        if r["rank"] < ctx["min_rank"]:
            w = 0.0
        ents.append((r["id"], w))
    tot = sum(w for _, w in ents)
    x = rng.random() * tot
    for rid, w in ents:
        x -= w
        if x <= 0 and w > 0:
            return rid
    return ents[-1][0]


class Player:
    def __init__(self):
        self.t = 0.0           # play seconds
        self.pity = {}
        self.drops = {}
        self.first = {}
        self.legendary_times = []
        self.gold = 0
        self.mats = {}
        self.first_elite = False
        self.boss_kills = 0
        self.uniques = 0


def apply_pity(C, p, rarity, ml):
    rank = C.rank[rarity]
    result = rarity
    for r in C.rar.values():
        ps = float(r.get("pity_seconds", 0))
        if ps <= 0 or r.get("min_monster_level", 0) > ml:
            continue
        since = p.t - float(p.pity.get(r["id"], 0.0))
        if since >= ps and r["rank"] > C.rank[result]:
            result = r["id"]
    for r in C.rar.values():
        if r["rank"] <= C.rank[result] and float(r.get("pity_seconds", 0)) > 0:
            p.pity[r["id"]] = p.t
    return result


def give(p, rarity):
    p.drops[rarity] = p.drops.get(rarity, 0) + 1
    p.first.setdefault(rarity, p.t)
    if rarity == "legendary":
        p.legendary_times.append(p.t)


def roll_kill(C, rng, p, mon, ml, tier, kind, mf):
    kc = C.kinds.get(kind, {})
    chance = float(kc.get("item_chance", 0.18)) * float(mon.get("loot_mult", 1.0))
    n = int(kc.get("min_items", 0))
    for _ in range(int(kc.get("min_items", 0)), int(kc.get("max_items", 1))):
        if rng.random() < chance:
            n += 1
    ctx = {"mf": mf + float(tier.get("magic_find", 0)), "ml": ml, "tier_bonus": tier.get("rarity_bonus", {}),
           "source_bonus": kc.get("rarity_bonus", {}), "min_rank": int(kc.get("min_rank", 0))}
    for _ in range(n):
        r = apply_pity(C, p, roll_rarity(C, rng, ctx), ml)
        give(p, r)
    for u in mon.get("uniques", []):
        if rng.random() < float(u.get("chance", 0.025)) * float(tier.get("unique_mult", 1.0)):
            p.uniques += 1
            give(p, "unique")
    if rng.random() < float(kc.get("gold_chance", 0.35)):
        p.gold += int((4.0 + ml * 1.6) * rng.uniform(0.6, 1.6) * float(kc.get("gold_mult", 1.0)) * float(tier.get("gold_mult", 1.0)))
    for m in mon.get("materials", []) + tier.get("materials", []) + kc.get("materials", []):
        if rng.random() < float(m.get("chance", 0.1)):
            p.mats[m["id"]] = p.mats.get(m["id"], 0) + rng.randint(int(m.get("min", 1)), int(m.get("max", 1)))


def zone_kills(C, rng, zone, act, tier):
    """Return list of (monster_rec, kind) for one zone clear, following game_world._populate."""
    fams = zone.get("families", act.get("families", []))
    pool = [m for m in C.mon.values() if m.get("family") in fams and not m.get("boss") and not m.get("summon_only")]
    wsum = sum(m.get("spawn_weight", 10) for m in pool)
    out = []
    ec = float(zone.get("elite_chance", 0.18)) * float(tier.get("elite_mult", 1.0))
    for _ in range(int(zone.get("packs", 10))):
        x = rng.random() * wsum
        lead = pool[-1]
        for m in pool:
            x -= m.get("spawn_weight", 10)
            if x <= 0:
                lead = m
                break
        size = rng.randint(int(lead.get("pack_min", 3)), int(lead.get("pack_max", 5)))
        kind = "normal"
        if rng.random() < ec:
            kind = "rare" if rng.random() < 0.35 else "champion"
        for j in range(size):
            rec = lead if j == 0 or rng.random() < 0.6 else rng.choice(pool)
            k = "champion" if kind == "champion" else ("rare" if (kind == "rare" and j == 0) else "normal")
            out.append((rec, k))
        # summoners add a few fodder kills (bonepile etc.)
        for ab in lead.get("abilities", []):
            if ab.get("type") == "summon" and ab.get("monster") in C.mon:
                for _ in range(int(ab.get("count", 2))):
                    out.append((C.mon[ab["monster"]], "normal"))
    if zone.get("boss"):
        out.append((C.mon[zone["boss"]], "boss"))
    return out


def simulate(args, hook=True):
    C = Content()
    rng = random.Random(args.seed)
    tier = C.diff[args.tier]
    act = C.acts[f"act{args.act}"]
    zones = [C.zones[z] for z in act["zones"]]
    hook_s = float(C.cfg["hooks"]["first_legendary_s"]) if hook else None
    players = []
    kill_counts = []
    for _ in range(args.players):
        p = Player()
        kills = 0
        zi = 0
        seen_magpie = False
        while p.t < args.minutes * 60:
            z = zones[zi % len(zones)]
            zi += 1
            dur = (BOSS_ZONE_MIN if z.get("boss") else ZONE_MIN) * 60
            band = tier.get("level_band", [1, 60])
            ml = max(int(z.get("level", 1)) + int(tier.get("level_offset", 0)), args.level - 1)
            ml = min(max(ml, band[0]), band[1])
            kl = zone_kills(C, rng, z, act, tier)
            # events (first hit wins, like _maybe_surprise)
            for ev in C.events.values():
                forced = ev.get("force_zone") == z["id"] and not seen_magpie
                if forced or rng.random() < float(ev.get("chance", 0)):
                    if ev.get("monster"):
                        kl.insert(len(kl) // 2, (C.mon[ev["monster"]], "event:" + ev["id"]))
                    if forced:
                        seen_magpie = True
                    break
            n_chest = int(CHESTS_PER_ZONE) + (1 if rng.random() < CHESTS_PER_ZONE % 1 else 0)
            step = dur / max(1, len(kl) + n_chest)
            for (m, k) in kl:
                p.t += step
                if hook_s and "legendary" not in p.first and p.t >= hook_s:
                    give(p, "legendary")
                    for r in C.rar.values():
                        if r["rank"] <= C.rank["legendary"] and float(r.get("pity_seconds", 0)) > 0:
                            p.pity[r["id"]] = p.t
                lk = k
                if k.startswith("event:"):
                    lk = C.events[k[6:]].get("loot_kind", "rare")
                roll_kill(C, rng, p, m, ml, tier, lk, args.mf)
                kills += 1
                if k in ("champion", "rare") and not p.first_elite:
                    p.first_elite = True
                    give(p, "rare")
                if k == "boss":
                    p.boss_kills += 1
            for _ in range(n_chest):
                p.t += step
                roll_kill(C, rng, p, {"loot_mult": 1.0}, ml, tier, "chest_gold" if rng.random() < 0.2 else "chest", args.mf)
        players.append(p)
        kill_counts.append(kills)
    return C, players, kill_counts


def pct(xs, q):
    xs = sorted(xs)
    if not xs:
        return float("nan")
    return xs[min(len(xs) - 1, int(q * len(xs)))]


def report(args, C, players, kills, label):
    mins = args.minutes
    print(f"\n=== {label}: tier={args.tier} act={args.act} level={args.level} mf={args.mf} players={args.players} minutes={mins}")
    print(f"kills/min: {statistics.mean(kills)/mins:.1f}")
    rows = ["common", "magic", "rare", "epic", "legendary", "mythic", "unique"]
    tot = 0
    res = {}
    for r in rows:
        per_min = statistics.mean(p.drops.get(r, 0) for p in players) / mins
        res[r] = per_min
        if r != "unique":
            tot += per_min
        print(f"  {r:10s} {per_min:6.3f}/min  {per_min*60:7.2f}/h")
    print(f"  {'ALL':10s} {tot:6.3f}/min  {tot*60:7.1f}/h")
    firsts = [p.first.get("legendary", float("inf")) / 60 for p in players]
    print(f"first Legendary (min): p50 {pct(firsts,0.5):.1f}  p90 {pct(firsts,0.9):.1f}  p99 {pct(firsts,0.99):.1f}")
    gaps = []
    for p in players:
        ts = [0.0] + p.legendary_times
        gaps += [(b - a) / 60 for a, b in zip(ts, ts[1:])]
    res_gap = pct(gaps, 0.95) if gaps else 0.0
    if gaps:
        print(f"Legendary gap (min): mean {statistics.mean(gaps):.1f}  p95 {pct(gaps,0.95):.1f}  max {max(gaps):.1f}")
    fm = [p.first.get("magic", float("inf")) / 60 for p in players]
    print(f"first Magic (min): p50 {pct(fm,0.5):.2f} p90 {pct(fm,0.9):.2f}")
    bk = sum(p.boss_kills for p in players)
    ub = sum(p.uniques for p in players)
    print(f"boss kills {bk}, uniques {ub} -> 1 unique per {bk/max(1,ub):.1f} boss-zone clears (incl. elite/miniboss sources)")
    gold = statistics.mean(p.gold for p in players) / mins
    print(f"gold/min (drops only): {gold:.0f}")
    hm = statistics.mean(p.mats.get("hushmark", 0) for p in players) / (mins / 60)
    gc = statistics.mean(p.mats.get("glowcoal", 0) for p in players) / (mins / 60)
    print(f"hushmarks/h: {hm:.2f}  -> hours per 5-hushmark mystery item: {5/hm if hm else float('inf'):.2f}   glowcoal/h: {gc:.1f}")
    res["all"] = tot
    res["gap_p95"] = res_gap
    res["hushmark_h"] = hm
    return res


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--players", type=int, default=2000)
    ap.add_argument("--minutes", type=int, default=180)
    ap.add_argument("--tier", default="twilight")
    ap.add_argument("--act", type=int, default=1)
    ap.add_argument("--level", type=int, default=8)
    ap.add_argument("--mf", type=float, default=0.0)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--no-hook", action="store_true")
    ap.add_argument("--check", action="store_true", help="exit 1 if Tier-1 Act-1 rates fall outside QA.md §5.3 bands")
    args = ap.parse_args()
    C, players, kills = simulate(args, hook=not args.no_hook)
    res = report(args, C, players, kills, "with scripted hook" if not args.no_hook else "no hook")
    if args.check:
        bands = {"all": (2.5, 4.0), "common": (1.4, 2.2), "magic": (0.75, 1.3), "rare": (0.15, 0.26), "epic": (0.03, 0.06), "legendary": (0.012, 0.03)}
        bad = [f"{k} {res[k]:.3f} not in {lo}-{hi}" for k, (lo, hi) in bands.items() if not (lo <= res[k] <= hi)]
        if res["gap_p95"] > 60.0:
            bad.append(f"Legendary gap p95 {res['gap_p95']:.1f} min > 60 (QA §5.3)")
        if bad:
            print("QA §5.3 FAIL:", "; ".join(bad))
            return 1
        print("QA §5.3 bands: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())

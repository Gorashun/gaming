#!/usr/bin/env python3
"""Validate Wickwright content packs: JSON syntax, unique ids, cross-references, asset paths,
engine-supported effect/ability types, animation names and blocked names.

Usage:  python3 tools/validate_content.py [--pack content/base] [--strict-anims]
Exit code 0 = OK, 1 = errors found. Warnings never fail the run.
"""
import argparse
import json
import os
import re
import struct
import sys

GAME = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

SKILL_EFFECTS = {"melee_arc", "aoe", "nova", "projectile", "dash", "leap", "chain", "ground_zone", "summon", "buff", "heal", "spin", "pull", "resource"}
MONSTER_ABILITIES = {"slam", "volley", "nova_ring", "summon", "charge", "heal_allies", "teleport"}
AI_KINDS = {"melee", "ranged", "caster", "charger", "swarm", "summoner", "flee"}
SLOTS = {"head", "chest", "hands", "legs", "feet", "belt", "main_hand", "off_hand", "ring", "amulet", "charm"}
STATUSES = {"stun", "freeze", "slow", "haste", "unstoppable"}
ELEMENTS = {"physical", "fire", "cold", "lightning", "shadow", "holy"}
QUEST_TYPES = {"kill", "collect", "explore", "boss", "talk"}
MQ_TYPES = {"reach", "rekindle", "collect", "escort", "talk", "solve", "boss"}
BLOCKED = [r"\bparagon\b", r"\brift", r"\btorment\b", r"\bnephalem", r"\bhoradric", r"\bgreater rift", r"\bdevotion\b", r"\bforging potential",
           r"\bwraeclast", r"\bsanctuary of", r"\bexalted orb", r"\bchaos orb", r"\btreasure goblin", r"\bdeckard", r"\blilith", r"\bmephisto",
           r"\bbaal\b", r"\bdiablo", r"\bembermage", r"\bwarhammer", r"\bnightmare\b", r"\bworld tier", r"\bhellforge", r"\briftgate", r"\batlas\b"]
BLOCK_ALLOW = {"Sanctuary"}   # a skill named "Sanctuary" is generic English (not "Sanctuary" the Diablo world as a place name)


class V:
    def __init__(self):
        self.errors, self.warnings = [], []

    def err(self, msg):
        self.errors.append(msg)

    def warn(self, msg):
        self.warnings.append(msg)


def res_path(p):
    if not isinstance(p, str) or not p.startswith("res://"):
        return None
    return os.path.join(GAME, p[len("res://"):])


_anim_cache = {}


def glb_anims(path):
    if path in _anim_cache:
        return _anim_cache[path]
    out = set()
    try:
        with open(path, "rb") as f:
            d = f.read()
        ln = struct.unpack("<I", d[12:16])[0]
        j = json.loads(d[20:20 + ln])
        out = {a.get("name", "") for a in j.get("animations", [])}
    except Exception:
        out = set()
    _anim_cache[path] = out
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pack", default=os.path.join(GAME, "content", "base"))
    ap.add_argument("--strict-anims", action="store_true", help="treat missing hero-model animations as errors")
    args = ap.parse_args()
    v = V()
    pack_dir = args.pack
    try:
        pack = json.load(open(os.path.join(pack_dir, "pack.json")))
    except Exception as e:
        print("FATAL pack.json:", e)
        return 1
    T = {}
    for table, fn in pack.get("tables", {}).items():
        files = fn if isinstance(fn, list) else [fn]
        T[table] = []
        for f in files:
            p = os.path.join(pack_dir, f)
            if not os.path.exists(p):
                v.err(f"[{table}] missing file {f}")
                continue
            try:
                data = json.load(open(p))
            except Exception as e:
                v.err(f"[{table}] JSON parse error in {f}: {e}")
                continue
            T[table] += data if isinstance(data, list) else [data]
    # also parse every json in the folder (catches stray broken files)
    for f in os.listdir(pack_dir):
        if f.endswith(".json"):
            try:
                json.load(open(os.path.join(pack_dir, f)))
            except Exception as e:
                v.err(f"JSON parse error in {f}: {e}")
    idx = {}
    for t, recs in T.items():
        idx[t] = {}
        for r in recs:
            if not isinstance(r, dict) or "id" not in r or r["id"] == "":
                v.err(f"[{t}] record without id: {str(r)[:80]}")
                continue
            if r["id"] in idx[t]:
                v.err(f"[{t}] duplicate id {r['id']}")
            idx[t][r["id"]] = r
    g = lambda t: idx.get(t, {})
    stats = g("stats")

    def chk_stat(where, s):
        if s not in stats:
            v.err(f"{where}: unknown stat '{s}'")

    def chk_ref(where, table, rid, allow_empty=False):
        if allow_empty and (rid is None or rid == ""):
            return
        if rid not in g(table):
            v.err(f"{where}: unknown {table} id '{rid}'")

    def chk_model(where, p):
        rp = res_path(p)
        if rp is None:
            return
        if not os.path.exists(rp):
            v.err(f"{where}: asset missing {p}")

    cfg = g("config")
    loot_kinds = cfg.get("loot", {}).get("kinds", {})
    # ---------------- stats
    for s in stats.values():
        if "{v}" not in s.get("format", ""):
            v.err(f"[stats] {s['id']} format lacks {{v}}")
    # ---------------- rarities
    tot = sum(float(r.get("weight", 0)) for r in g("rarities").values() if r.get("drops", True))
    if abs(tot - 100.0) > 1.0:
        v.warn(f"[rarities] drop weights sum to {tot:.2f} (QA expects ~100)")
    # ---------------- weapon types
    wt = g("weapon_types")
    for w in wt.values():
        chk_model(f"[weapon_types] {w['id']}", w.get("prop"))
        for k in w.get("proficiency_bonus", {}):
            chk_stat(f"[weapon_types] {w['id']}", k)
        if w.get("hand") not in ("main", "off", "two"):
            v.err(f"[weapon_types] {w['id']} bad hand")
    # ---------------- item bases
    for b in g("item_bases").values():
        w = f"[item_bases] {b['id']}"
        if b.get("slot") not in SLOTS:
            v.err(f"{w}: bad slot {b.get('slot')}")
        if b.get("slot") in ("main_hand", "off_hand"):
            if b.get("type") not in wt:
                v.err(f"{w}: type {b.get('type')} not in weapon_types")
            else:
                two = wt[b["type"]]["hand"] == "two"
                if bool(b.get("two_handed", False)) != two:
                    v.err(f"{w}: two_handed flag disagrees with weapon_types.hand")
        chk_model(w, b.get("model"))
        for k, r in b.get("implicit", {}).items():
            chk_stat(w, k)
            if r[0] > r[1]:
                v.err(f"{w}: implicit {k} min>max")
        if "dmg" in b and b["dmg"][0] > b["dmg"][1]:
            v.err(f"{w}: dmg min>max")
        for c in b.get("classes", []):
            chk_ref(w, "classes", c)
    # ---------------- affixes
    for a in g("affixes").values():
        w = f"[affixes] {a['id']}"
        chk_stat(w, a.get("stat"))
        if a.get("kind") not in ("prefix", "suffix"):
            v.err(f"{w}: kind must be prefix/suffix")
        for s in a.get("slots", []):
            if s not in SLOTS and s not in wt:
                v.err(f"{w}: slot/type '{s}' unknown")
        il = [t["ilvl"] for t in a.get("tiers", [])]
        if not il or il != sorted(il):
            v.err(f"{w}: tiers must be non-empty and ascending by ilvl")
        for t in a.get("tiers", []):
            if t["min"] > t["max"]:
                v.err(f"{w}: tier min>max at ilvl {t['ilvl']}")
        for c in a.get("classes", []):
            chk_ref(w, "classes", c)
    # ---------------- powers
    for p in g("powers").values():
        for k in p.get("stats", {}):
            chk_stat(f"[powers] {p['id']}", k)
        if p.get("class"):
            chk_ref(f"[powers] {p['id']}", "classes", p["class"])
    # ---------------- materials
    for m in g("materials").values():
        for kind, d in m.get("socket", {}).items():
            for k in d:
                chk_stat(f"[materials] {m['id']} socket.{kind}", k)
    mat_or_cons = set(g("materials")) | set(g("consumables"))
    # ---------------- uniques / named
    for u in g("uniques").values():
        w = f"[uniques] {u['id']}"
        chk_ref(w, "item_bases", u.get("base"))
        chk_ref(w, "powers", u.get("power"), allow_empty=True)
        for s in u.get("stats", []):
            chk_stat(w, s["stat"])
        for k, ref in u.get("drop", {}).items():
            if k in ("monster", "boss", "event"):
                chk_ref(w, "monsters", ref)
            elif k == "act":
                chk_ref(w, "acts", ref)
        if not u.get("flavor"):
            v.warn(f"{w}: no flavor text")
    for n in g("named").values():
        w = f"[named] {n['id']}"
        chk_ref(w, "item_bases", n.get("base"))
        chk_ref(w, "powers", n.get("power"))
        chk_ref(w, "recipes", n.get("recipe"))
        for s in n.get("stats", []):
            chk_stat(w, s["stat"])
    # ---------------- recipes
    profs = g("professions")
    for r in g("recipes").values():
        w = f"[recipes] {r['id']}"
        chk_ref(w, "professions", r.get("profession"))
        for k in r.get("cost", {}):
            if k not in mat_or_cons:
                v.err(f"{w}: cost material '{k}' unknown")
        for k in r.get("output", {}):
            if k not in mat_or_cons:
                v.err(f"{w}: output '{k}' unknown")
        if r.get("kind") == "forge_unique":
            chk_ref(w, "uniques", r.get("unique"))
        if r.get("kind") == "forge_named":
            chk_ref(w, "named", r.get("named"))
        p = profs.get(r.get("profession"), {})
        if int(r.get("level", 1)) > int(p.get("max_level", 50)) and p.get("id") != "cauldron":
            v.err(f"{w}: level above profession max")
    # ---------------- consumables
    for c in g("consumables").values():
        for k in c.get("effect", {}).get("stats", {}):
            chk_stat(f"[consumables] {c['id']}", k)
    # ---------------- classes / skills / passives
    skills = g("skills")
    mons = g("monsters")
    for c in g("classes").values():
        w = f"[classes] {c['id']}"
        chk_model(w, c.get("model"))
        for s in c.get("start_skills", []) + [x for x in c.get("start_bar", []) if x] + [c.get("basic_attack")]:
            chk_ref(w, "skills", s)
        for b in c.get("start_gear", []):
            chk_ref(w, "item_bases", b)
        for k, d in c.get("affinities", {}).items():
            if k not in wt:
                v.err(f"{w}: affinity weapon type {k} unknown")
            for s in d:
                chk_stat(w + " affinity", s)
        for p in c.get("pacts", []):
            chk_ref(w, "passives", p)
        n_active = sum(1 for s in skills.values() if s.get("class") == c["id"] and "basic" not in s.get("tags", []))
        if n_active < 12:
            v.err(f"{w}: only {n_active} non-basic skills (need 12+)")
    for s in skills.values():
        w = f"[skills] {s['id']}"
        chk_ref(w, "classes", s.get("class"))
        cls = g("classes").get(s.get("class"), {})
        if s.get("element") and s["element"] not in ELEMENTS:
            v.err(f"{w}: bad element {s['element']}")
        anims = s.get("anim", [])
        anims = anims if isinstance(anims, list) else [anims]
        mp = res_path(cls.get("model", ""))
        if mp and os.path.exists(mp):
            have = glb_anims(mp)
            for a in anims:
                if have and a not in have:
                    (v.err if args.strict_anims else v.warn)(f"{w}: anim '{a}' not in {os.path.basename(mp)} (needs shared anim library)")

        def chk_effects(effs, where):
            for e in effs:
                if e.get("type") not in SKILL_EFFECTS:
                    v.err(f"{where}: effect type '{e.get('type')}' not supported by skill_effects.gd")
                if e.get("type") == "summon":
                    m = mons.get(e.get("minion"))
                    if m is None:
                        v.err(f"{where}: minion '{e.get('minion')}' missing")
                    elif not m.get("summon_only"):
                        v.err(f"{where}: minion '{e.get('minion')}' must be summon_only")
                st = e.get("status")
                if isinstance(st, dict) and st.get("id") not in STATUSES:
                    v.err(f"{where}: status '{st.get('id')}' unknown")
                for k in e.get("stats", {}):
                    chk_stat(where, k)
                if e.get("element") and e["element"] not in ELEMENTS:
                    v.err(f"{where}: bad element")

        effs = s.get("effects", [])
        chk_effects(effs, w)

        def chk_patch(patch, where):
            for k, val in patch.items():
                m = re.match(r"^effects\.(\d+)\.(\w+)$", k)
                if m:
                    if int(m.group(1)) >= len(effs):
                        v.err(f"{where}: patch '{k}' points past effects list")
                    if m.group(2) == "status" and isinstance(val, dict) and val.get("id") not in STATUSES:
                        v.err(f"{where}: patch status unknown")
                elif "." in k:
                    v.err(f"{where}: malformed patch key '{k}'")
                if k == "element" and val not in ELEMENTS:
                    v.err(f"{where}: patch element '{val}'")

        mods = s.get("modifiers", [])
        if "basic" not in s.get("tags", []):
            ranks = [m.get("rank") for m in mods]
            if ranks != [2, 4]:
                v.err(f"{w}: modifiers must be rank 2 and 4 (got {ranks})")
            for tier in mods:
                opts = tier.get("options", [])
                if len(opts) != 3:
                    v.err(f"{w}: rank {tier.get('rank')} needs 3 options")
                ids = [o["id"] for o in opts]
                if len(set(ids)) != len(ids):
                    v.err(f"{w}: duplicate modifier option ids")
                for o in opts:
                    chk_patch(o.get("patch", {}), f"{w} mod {o['id']}")
                    chk_effects(o.get("add_effects", []), f"{w} mod {o['id']}")
                    for k in o.get("stats", {}):
                        chk_stat(f"{w} mod {o['id']}", k)
        ms = s.get("mastery", {})
        for k in ms.get("per_rank", {}):
            chk_stat(w + " mastery", k)
        for m in ms.get("milestones", []):
            chk_patch(m.get("patch", {}), f"{w} mastery r{m.get('rank')}")
            chk_effects(m.get("add_effects", []), f"{w} mastery r{m.get('rank')}")
            for k in m.get("stats", {}):
                chk_stat(f"{w} mastery", k)
        if s.get("unlock_level", 1) > 40:
            v.err(f"{w}: unlock_level above 40")
    for p in g("passives").values():
        w = f"[passives] {p['id']}"
        chk_ref(w, "classes", p.get("class"))
        br = [b["id"] for b in g("classes").get(p.get("class"), {}).get("branches", [])]
        if p.get("branch") and p["branch"] not in br:
            v.err(f"{w}: branch {p['branch']} not in class branches")
        for k in p.get("stats", {}):
            chk_stat(w, k)
    for c in g("classes").values():
        n = sum(1 for p in g("passives").values() if p.get("class") == c["id"] and p.get("kind") != "pact")
        if n < 8:
            v.err(f"[classes] {c['id']}: only {n} passives (need 8+)")
    # ---------------- monsters
    for m in mons.values():
        w = f"[monsters] {m['id']}"
        chk_model(w, m.get("model"))
        for p in m.get("props", []):
            chk_model(w + " prop", p.get("path"))
        if m.get("ai", "melee") not in AI_KINDS:
            v.err(f"{w}: ai '{m.get('ai')}' unknown")
        mp = res_path(m.get("model", ""))
        have = glb_anims(mp) if mp and os.path.exists(mp) else set()
        att = m.get("attack", {})
        an = att.get("anim", [])
        an = an if isinstance(an, list) else [an]
        for ab in m.get("abilities", []):
            if ab.get("type") not in MONSTER_ABILITIES:
                v.err(f"{w}: ability type '{ab.get('type')}' unsupported")
            if ab.get("type") == "summon":
                chk_ref(w + " summon", "monsters", ab.get("monster"))
            if ab.get("anim"):
                an.append(ab["anim"])
            if float(ab.get("telegraph", 1.0)) < 0.4 and ab.get("type") not in ("teleport",):
                v.warn(f"{w}: ability {ab.get('id')} telegraph < 0.4 s (tier minimum clamps it)")
            if m.get("boss") and ab.get("type") in ("slam", "nova_ring", "charge", "volley") and float(ab.get("telegraph", 1.0)) < 1.0:
                v.err(f"{w}: boss telegraph below 1.0 s ({ab.get('id')})")
        for extra in ("spawn_anim", "death_anim", "idle_anim", "run_anim"):
            if m.get(extra):
                an.append(m[extra])
        for a in an:
            if have and a not in have:
                v.err(f"{w}: anim '{a}' not in {os.path.basename(mp)}")
        abil_ids = {a.get("id") for a in m.get("abilities", [])}
        for ph in m.get("phases", []):
            for a in ph.get("abilities_add", []):
                if a not in abil_ids:
                    v.err(f"{w}: phase adds unknown ability {a}")
        for mat in m.get("materials", []):
            chk_ref(w, "materials", mat.get("id"))
        for u in m.get("uniques", []):
            chk_ref(w, "uniques", u.get("id"))
        for p in m.get("pet_drops", []):
            chk_ref(w, "pets", p.get("id"))
        if m.get("boss") and not m.get("summon_only") and len(m.get("abilities", [])) < 3:
            v.err(f"{w}: act boss needs 3+ abilities")
    fams = {}
    for m in mons.values():
        if not m.get("summon_only") and not m.get("boss"):
            fams.setdefault(m.get("family"), []).append(m["id"])
    # ---------------- acts / zones
    biomes = g("biomes")
    for a in g("acts").values():
        w = f"[acts] {a['id']}"
        chk_ref(w, "zones", a.get("town"))
        for z in a.get("zones", []):
            chk_ref(w, "zones", z)
        for f in a.get("families", []):
            if len(fams.get(f, [])) < 6:
                v.err(f"{w}: family {f} has {len(fams.get(f, []))} spawnable types (need 6+)")
        chk_ref(w, "monsters", a.get("boss"), allow_empty=True)
        for mb in a.get("minibosses", []):
            chk_ref(w, "monsters", mb)
    for z in g("zones").values():
        w = f"[zones] {z['id']}"
        chk_ref(w, "acts", z.get("act"))
        if z.get("biome") not in biomes:
            v.err(f"{w}: biome '{z.get('biome')}' not in biomes.json")
        chk_ref(w, "monsters", z.get("boss"), allow_empty=True)
        chk_ref(w, "zones", z.get("next"), allow_empty=True)
        for n in z.get("npcs", []):
            chk_ref(w, "npcs", n)
        for mb in z.get("minibosses", []):
            chk_ref(w, "monsters", mb)
        for s in z.get("secrets", []):
            rw = s.get("reward", {})
            for key, table in (("material", "materials"), ("pet", "pets"), ("mount", "mounts"), ("lore", "lore"), ("portal", "zones"), ("deed", "deeds")):
                if key in rw:
                    chk_ref(f"{w} secret {s.get('id')}", table, rw[key])
            if s.get("lore"):
                chk_ref(f"{w} secret {s.get('id')}", "lore", s["lore"])
        if not z.get("town") and not z.get("special") and not z.get("secrets"):
            v.warn(f"{w}: no secrets (player_wants #18 asks one per zone)")
    # ---------------- events / world events
    for e in g("events").values():
        w = f"[events] {e['id']}"
        chk_ref(w, "monsters", e.get("monster"), allow_empty=True)
        chk_ref(w, "monsters", e.get("alt_monster"), allow_empty=True)
        chk_ref(w, "zones", e.get("force_zone"), allow_empty=True)
        chk_ref(w, "zones", e.get("portal"), allow_empty=True)
        if e.get("loot_kind") and e["loot_kind"] not in loot_kinds:
            v.err(f"{w}: loot_kind {e['loot_kind']} not in config.loot.kinds")
    for e in g("world_events").values():
        w = f"[world_events] {e['id']}"
        for st in e.get("stages", []):
            for wave in st.get("waves", []):
                for mid in wave.get("monsters", []):
                    if mid == "any_family":
                        continue
                    if mid.startswith("family:"):
                        if mid[7:] not in fams:
                            v.err(f"{w}: family {mid} unknown")
                    else:
                        chk_ref(w, "monsters", mid)
            if st.get("modifier"):
                chk_ref(w, "monster_affixes", st["modifier"])
            for k in st.get("curse", {}):
                chk_stat(w + " curse", k)
            if st.get("escort"):
                chk_ref(w, "escorts", st["escort"])
        chk_ref(w, "monsters", e.get("boss"), allow_empty=True)
        rw = e.get("reward", {})
        if rw.get("loot_kind") and rw["loot_kind"] not in loot_kinds:
            v.err(f"{w}: loot_kind unknown")
        for mm in rw.get("materials", []):
            chk_ref(w, "materials", mm.get("id"))
        if "pet_chance" in rw:
            chk_ref(w, "pets", rw["pet_chance"]["id"])
        if "mount_chance" in rw:
            chk_ref(w, "mounts", rw["mount_chance"]["id"])
    # ---------------- difficulties
    prev = None
    for d in sorted(g("difficulties").values(), key=lambda x: x.get("order", 0)):
        w = f"[difficulties] {d['id']}"
        chk_ref(w, "difficulties", d.get("unlock"), allow_empty=True)
        for mm in d.get("materials", []):
            chk_ref(w, "materials", mm.get("id"))
        b = d.get("level_band", [1, 1])
        if b[0] > b[1]:
            v.err(f"{w}: level band inverted")
        if prev and b[0] < prev[0]:
            v.err(f"{w}: level band starts below previous tier")
        prev = b
    # ---------------- config
    for kind, k in loot_kinds.items():
        for mm in k.get("materials", []):
            chk_ref(f"[config.loot.{kind}]", "materials", mm.get("id"))
    up = cfg.get("upgrade", {})
    if len(up.get("gold", [])) != up.get("max", 15) or len(up.get("materials", [])) != up.get("max", 15):
        v.err("[config.upgrade] gold/materials must have one entry per level")
    for i, mm in enumerate(up.get("materials", [])):
        for k in mm:
            chk_ref(f"[config.upgrade] +{i+1}", "materials", k)
    sm = cfg.get("skill_mastery", {})
    for c in sm.get("costs", []):
        for k in c.get("materials", {}):
            if k != "act_material":
                chk_ref(f"[config.skill_mastery] r{c['rank_to']}", "materials", k)
    # ---------------- starmap
    sm_nodes = g("starmap")
    for n in sm_nodes.values():
        w = f"[starmap] {n['id']}"
        for l in n.get("links", []):
            chk_ref(w, "starmap", l)
        for k in list(n.get("stats", {})) + list(n.get("bonus", {})):
            chk_stat(w, k)
        for nid in n.get("nodes", []):
            chk_ref(w, "starmap", nid)
        if n.get("class"):
            chk_ref(w, "classes", n["class"])
    # ---------------- npcs / quests / main quest
    lore = g("lore")
    for n in g("npcs").values():
        w = f"[npcs] {n['id']}"
        chk_ref(w, "zones", n.get("town"))
        chk_model(w, n.get("model"))
        for q in n.get("quest_ids", []):
            chk_ref(w, "quests", q)
        if n.get("shop") and n["shop"] not in ("curio_offers",):
            chk_ref(w, "vendors", n["shop"])
    def target_ok(typ, t):
        if isinstance(t, list):
            return all(target_ok(typ, x) for x in t)
        if typ in ("kill", "rekindle"):
            return t in mons or t in ("elite",) or (isinstance(t, str) and t.startswith("family:") and t[7:] in fams)
        if typ == "boss":
            return t in mons and mons[t].get("boss")
        if typ == "collect":
            return t in g("materials") or t in lore
        if typ in ("explore", "reach"):
            return t in g("zones") or t in ("brightness",)
        if typ == "talk":
            return t in g("npcs") or t in mons
        if typ == "solve":
            return t in g("puzzles")
        if typ == "escort":
            return t in g("escorts")
        return False
    for q in g("quests").values():
        w = f"[quests] {q['id']}"
        chk_ref(w, "npcs", q.get("giver"))
        if q.get("type") not in QUEST_TYPES:
            v.err(f"{w}: type {q.get('type')} unknown")
        elif not target_ok(q["type"], q.get("target")):
            v.err(f"{w}: target '{q.get('target')}' does not resolve for type {q['type']}")
        rw = q.get("reward", {})
        for key, table in (("pet", "pets"), ("mount", "mounts"), ("recipe", "recipes")):
            if key in rw:
                chk_ref(w, table, rw[key])
        for k in list(rw.get("material", {})) + list(rw.get("consumable", {})):
            if k not in mat_or_cons:
                v.err(f"{w}: reward item {k} unknown")
    for acts_id in g("acts"):
        n = sum(1 for q in g("quests").values() if q.get("act") == acts_id)
        if n < 15:
            v.err(f"[quests] {acts_id}: only {n} quests (need 15+)")
    for mq in g("main_quest").values():
        w = f"[main_quest] {mq['id']}"
        chk_ref(w, "main_quest", mq.get("requires"), allow_empty=True)
        for o in mq.get("objectives", []):
            if o["type"] not in MQ_TYPES:
                v.err(f"{w}: objective type {o['type']}")
            elif not target_ok(o["type"], o["target"]) and not (o["type"] == "reach" and o["target"] in ("deepdark", "lightwell")):
                v.err(f"{w}: objective target '{o['target']}' ({o['type']}) does not resolve")
    for p in g("puzzles").values():
        chk_ref(f"[puzzles] {p['id']}", "zones", p.get("zone"))
    for e in g("escorts").values():
        if e.get("zone") != "any":
            chk_ref(f"[escorts] {e['id']}", "zones", e.get("zone"))
        chk_model(f"[escorts] {e['id']}", e.get("creature", {}).get("model"))
    # ---------------- vendors / curio / pets / mounts / deeds / cosmetics
    for vd in g("vendors").values():
        w = f"[vendors] {vd['id']}"
        chk_ref(w, "npcs", vd.get("npc"))
        for s in vd.get("stock", []):
            table = {"item_base": "item_bases", "material": "materials", "consumable": "consumables", "pet": "pets"}.get(s.get("kind"))
            if table is None:
                v.err(f"{w}: stock kind {s.get('kind')}")
            else:
                chk_ref(w, table, s.get("id"))
            if s.get("id") == "hushmark":
                v.err(f"{w}: Hushmarks must never be sold")
    for o in g("curio_offers").values():
        c = o.get("category", {})
        if "weapon_type" in c and c["weapon_type"] not in wt:
            v.err(f"[curio_offers] {o['id']}: weapon_type unknown")
        if "slot" in c and c["slot"] not in SLOTS:
            v.err(f"[curio_offers] {o['id']}: slot unknown")
    for p in g("pets").values():
        w = f"[pets] {p['id']}"
        chk_model(w, p.get("model"))
        for k in p.get("bonuses_per_level", {}):
            chk_stat(w, k)
        ref, src = p.get("source_ref", ""), p.get("source")
        ok = {"drop": ref in mons, "event": ref in g("events") or ref in mons or ref in g("zones") or ref in ("hushfall", "mystery_egg"),
              "quest": ref in g("quests"), "craft": ref in g("recipes"), "vendor": ref in g("npcs")}.get(src, False)
        if not ok:
            v.err(f"{w}: source {src} ref '{ref}' does not resolve")
    for m in g("mounts").values():
        w = f"[mounts] {m['id']}"
        chk_model(w, m.get("model"))
        r = m.get("requires", "")
        if r and r not in g("quests") and r not in g("deeds") and r not in lore and r not in g("world_events"):
            v.err(f"{w}: requires '{r}' does not resolve")
    dtext = {r["id"] for r in T.get("deeds_text", []) if r.get("kind") == "deed"}
    for d in g("deeds").values():
        w = f"[deeds] {d['id']}"
        if dtext and d["id"] not in dtext:
            v.warn(f"{w}: no text in deeds_text.json")
        goals = [t["goal"] for t in d.get("tiers", [])]
        if goals != sorted(goals):
            v.err(f"{w}: tier goals must ascend")
        for t in d.get("tiers", []):
            rw = t.get("reward", {})
            if "cosmetic" in rw:
                chk_ref(w, "cosmetics", rw["cosmetic"])
            if "mount" in rw:
                chk_ref(w, "mounts", rw["mount"])
            for k in rw.get("stats", {}):
                chk_stat(w, k)
    for i in dtext - set(g("deeds")):
        v.err(f"[deeds] text id {i} has no mechanics record")
    sp = sum(t.get("reward", {}).get("skill_points", 0) for d in g("deeds").values() for t in d.get("tiers", []))
    if sp > 10:
        v.err(f"[deeds] total skill points {sp} > 10")
    # ---------------- blocked names in player-facing strings
    pat = re.compile("|".join(BLOCKED), re.I)
    for t, recs in idx.items():
        if t in ("lore", "npc_text", "main_quest_text", "deeds_text", "names"):
            continue   # writer-owned text is checked by legal/writer
        for r in recs.values():
            for key in ("name", "desc", "flavor", "announce", "greeting", "title"):
                s = r.get(key)
                if isinstance(s, str) and pat.search(s) and s not in BLOCK_ALLOW:
                    v.err(f"[{t}] {r['id']}.{key} uses a blocked term: '{s}'")
    # ---------------- report
    for wmsg in v.warnings:
        print("WARN ", wmsg)
    for e in v.errors:
        print("ERROR", e)
    counts = {t: len(r) for t, r in idx.items()}
    print("tables:", ", ".join(f"{k}={n}" for k, n in counts.items()))
    print(f"validate_content: {len(v.errors)} errors, {len(v.warnings)} warnings")
    return 1 if v.errors else 0


if __name__ == "__main__":
    sys.exit(main())

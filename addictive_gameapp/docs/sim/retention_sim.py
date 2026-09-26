#!/usr/bin/env python3
"""KLUNK retention simulation (RETENTION.md §6). Python 3 standard library only.

Simulates day-by-day play (default 60 days, extended until all 48 buddies are owned) for three
player profiles and checks the targets T1-T12 in docs/RETENTION.md §6.

Numbers that already exist in the game are READ from app/src/data/*.ts (economy, collection,
unlocks, avatars, themes). The nine new lanes (Journey, missions, Daily Jar, Pearl Pool, Daily
Present, trophies, set mastery, aquarium) are not in app/src/data yet, so their numbers are copied
from RETENTION.md §3 / §8.1 into LANES below. When the programmer adds daily.ts, pool.ts etc.,
point the parser at those files instead.

Everything about player behaviour (merges per round, round length, skill, mission completion,
session times) is an ESTIMATE until measured in a playtest (PLAYTEST.md). Recalibrate with
    python3 retention_sim.py --playtest B1.json --profile casual

Usage:
    python3 retention_sim.py              # full report (markdown on stdout), ~2-4 min
    python3 retention_sim.py --quick      # fewer runs
    python3 retention_sim.py --only base  # just the base tables
"""
import argparse
import copy
import json
import math
import os
import random
import re
import statistics as st
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.normpath(os.path.join(HERE, '..', '..', 'app', 'src', 'data'))
RAR = ['common', 'uncommon', 'rare', 'epic', 'legendary', 'mythic']
SAND_PE = 25  # RETENTION conventions: 1 sand = 25 pearl-equivalents (est.)


# ============================================================ config from app/src/data/*.ts

def _read(name):
    with open(os.path.join(APP, name), encoding='utf-8') as f:
        return f.read()


def _nums(s):
    return [float(x) if '.' in x else int(x) for x in re.findall(r'-?\d+(?:\.\d+)?', s)]


def _one(pattern, text, what):
    m = re.search(pattern, text, re.S)
    if not m:
        sys.exit(f'retention_sim: could not parse {what}; the data file changed shape, update the parser')
    return m


def load_config():
    eco = _read('economy.ts')
    sand_block = _one(r'sand:\s*\{(.*?)\n\s*\},', eco, 'ECONOMY.sand').group(1)
    sand = {k: int(v) for k, v in re.findall(r'(\w+):\s*(\d+)', sand_block)}
    shells = {}
    for name, cur, price, floor, odds in re.findall(
            r"(common|silver|gold):\s*\{\s*price:\s*\{\s*(pearls|sand):\s*(\d+)\s*\},\s*floor:\s*'(\w+)',\s*odds:\s*\[([^\]]*)\]",
            eco):
        shells[name] = {'cur': cur, 'price': int(price), 'floor': floor, 'odds': _nums(odds)}
    free = _one(r'free:\s*\{\s*at:\s*\[([^\]]*)\][^,]*,\s*every:\s*(\d+),\s*sandWhenComplete:\s*(\d+)', eco, 'ECONOMY.free')
    upg = {}
    for r, a, b, c in re.findall(
            r"(common|uncommon|rare|epic|legendary|mythic):\s*\[(\d+),\s*\{\s*pearls:\s*(\d+),\s*sand:\s*(\d+)\s*\}\]", eco):
        upg[r] = (int(a), int(b), int(c))
    cfg = {
        'pearls_per_merge': int(_one(r'pearlsPerMerge:\s*(\d+)', eco, 'pearlsPerMerge').group(1)),
        'sand': sand,
        'milestone_levels': _nums(_one(r'milestoneLevels:\s*\[([^\]]*)\]', eco, 'milestoneLevels').group(1)),
        'shells': shells,
        'free_at': _nums(free.group(1)), 'free_every': int(free.group(2)), 'free_sand_complete': int(free.group(3)),
        'upgrade': upg,
        'first_shell_rare': 'firstShellRare: true' in eco,
    }
    col = _read('collection.ts')
    consts = {k: 1 / int(v) for k, v in re.findall(r'const (P_\w+) = 1 / (\d+);', col)}
    arr = _one(r'shinyP:\s*\[([^\]]*)\]', col, 'COLLECTION.shinyP').group(1)
    cfg['shiny_p'] = [consts[x.strip()] for x in arr.split(',') if x.strip()]
    cfg['pity_factor'] = int(_one(r'pityFactor:\s*(\d+)', col, 'pityFactor').group(1))
    cfg['first_shiny_by_run'] = int(_one(r'firstShinyByRun:\s*(\d+)', col, 'firstShinyByRun').group(1))
    cfg['first_shiny_min_level'] = int(_one(r'firstShinyMinLevel:\s*(\d+)', col, 'firstShinyMinLevel').group(1))
    cfg['slots_per_page'] = int(_one(r'SLOTS_PER_PAGE = (\d+)', col, 'SLOTS_PER_PAGE').group(1))
    unl = _read('unlocks.ts')
    cfg['set_thresholds'] = _nums(_one(r'mergeThresholds:\s*\[([^\]]*)\]', unl, 'mergeThresholds').group(1))
    cfg['skill_levels'] = _nums(_one(r'levels:\s*\[([^\]]*)\]', unl, 'skill.levels').group(1))
    av = _read('avatars.ts')
    counts = {r: 0 for r in RAR}
    for r in re.findall(r"^\s+rarity: '(\w+)',", av, re.M):
        counts[r] += 1
    cfg['count'] = counts
    th = _read('themes.ts')
    cfg['n_sets'] = len(_one(r'THEME_SETS:[^=]*=\s*\[([^\]]*)\]', th, 'THEME_SETS').group(1).split(','))
    assert sum(counts.values()) == 48, counts
    assert len(cfg['shiny_p']) == 11
    return cfg


# RETENTION.md §3 / §8.1 (proposal, not in app/src/data yet). Copied, not invented.
LANES = {
    'journey': {'xp_start': 15, 'base': 30, 'step': 10, 'cap': 600, 'authored': 100,
                'unlock': {'missions': 2, 'aquarium': 3, 'present': 4, 'daily': 5}},
    'missions': {'slots': 3, 'reward': {1: (20, 0), 2: (30, 0), 3: (40, 1)}, 'pool_mix': {1: 14, 2: 9, 3: 3},
                 'surprise_pearls': 20},
    'pool': {'cap': 40, 'fill_h': 24.0},
    'present': {'bank_max': 7, 'cycle': [(25, 0, 0), (25, 0, 0), (0, 1, 0), (25, 0, 0), (25, 0, 1)],
                'n_items': 12, 'after_items_5th': (25, 1, 0)},
    'daily': {'sand': 2},
}

# ============================================================ player profiles (ALL ESTIMATES)
# merges/round and round length: RETENTION §5 profiles. eff = share of equal pairs that actually merge
# in the level cascade (skill). Other rates are rough guesses, marked (est.) in the report.
PROFILES = {
    'casual': dict(label='Casual child', merges=45, round_min=4.5, eff=0.80,
                   sessions=[(17.0, 10.0)], play_days=5 / 7,
                   chain_k=0.010, combo_a=0.035, mission_p=(0.30, 0.12, 0.05),
                   calm_p=0.05, tap_buddy_p=0.06, hello_p=0.06, danger3_p=0.06, daily_replay_p=0.10),
    'engaged': dict(label='Engaged child', merges=60, round_min=5.0, eff=0.86,
                    sessions=[(15.5, 12.5), (18.5, 12.5)], play_days=1.0,
                    chain_k=0.013, combo_a=0.045, mission_p=(0.40, 0.20, 0.10),
                    calm_p=0.05, tap_buddy_p=0.06, hello_p=0.06, danger3_p=0.10, daily_replay_p=0.25),
    'skilled': dict(label='Skilled adult', merges=80, round_min=6.0, eff=0.92,
                    sessions=[(12.5, 20.0), (21.0, 20.0)], play_days=1.0,
                    chain_k=0.017, combo_a=0.055, mission_p=(0.50, 0.30, 0.18),
                    calm_p=0.03, tap_buddy_p=0.02, hello_p=0.03, danger3_p=0.14, daily_replay_p=0.30),
}
OVERHEAD_ROUND_MIN = 0.4    # result screen + restart per round (est.)
OVERHEAD_SESSION_MIN = 1.0  # Start, present, aquarium, shop per session (est.)
DROP_W = [26, 24, 22, 16, 12]  # queue levels 0-4 (RETENTION §3.1 daily weights, used for all rounds)

TROPHIES = ['first_merge', 'chain3', 'chain5', 'combo10', 'busy_jar', 'big_clear', 'rainbow_boost', 'steady_hands',
            'level7', 'level8', 'level9', 'level10', 'double_klunk', 'whole_chain', 'five_tens',
            'first_sparkle', 'sparkle_collector', 'full_row', 'full_page', 'set_explorer', 'set_master', 'whole_book',
            'jar_of_day', 'better_try', 'every_jar_set', 'daily_deep',
            'moving_in', 'decorator', 'full_aquarium', 'journey10', 'journey50', 'ten_missions',
            'tickled', 'calm_steady', 'big_boom', 'rainbow_top', 'waterfall', 'sparkling_giant', 'double_sparkle',
            'say_hello']
HIDDEN_WITH_ITEM = {'tickled', 'calm_steady', 'big_boom', 'rainbow_top', 'waterfall', 'sparkling_giant',
                    'double_sparkle', 'say_hello', 'whole_book'}


# ============================================================ helpers

def binom(rng, n, p):
    if n <= 0:
        return 0
    if n < 60:
        return sum(1 for _ in range(n) if rng.random() < p)
    x = round(rng.gauss(n * p, math.sqrt(n * p * (1 - p))))
    return max(0, min(n, x))


def poisson(rng, lam):
    if lam <= 0:
        return 0
    L, k, p = math.exp(-lam), 0, 1.0
    while True:
        p *= rng.random()
        if p <= L:
            return k
        k += 1


def geometric(rng, p):
    u = rng.random()
    return max(1, int(math.ceil(math.log(1 - u) / math.log(1 - p)))) if p < 1 else 1


def journey_need(L):
    J = LANES['journey']
    return min(J['cap'], J['base'] + J['step'] * (L - 1))


def journey_reward(L):
    """(pearls, sand, aquarium_items, is_centerpiece) for reaching level L (RETENTION §3.4)."""
    if L == 2:
        return 30, 0, 0, False
    if L == 3:
        return 0, 0, 1, False
    if L == 4:
        return 0, 2, 0, False
    if L == 5:
        return 0, 3, 1, True
    if L > 100:
        return 50, (5 if L % 5 == 0 else 0), 0, False
    m = L % 5
    if m in (1, 3):
        return (30 if L <= 30 else 40 if L <= 60 else 50), 0, 0, False
    if m == 2:
        return 0, 0, 1, False
    if m == 4:
        return 0, 2, 0, False
    # m == 0: big reward + 3 sand. Aquarium items: centerpieces 20,40,...,100; backdrops 15,35,...,95.
    aq = 1 if (L % 20 == 0 or L % 20 == 15) else 0
    return 0, 3, aq, L % 20 == 0


def merges_to_level(L):
    """Cumulative merges needed to reach Journey level L (check against RETENTION §3.4)."""
    tot = journey_need(1) - LANES['journey']['xp_start']
    for k in range(2, L):
        tot += journey_need(k)
    return tot


_RATIO = {}


def merges_per_drop(eff):
    """Monte Carlo merges per drop for a given cascade efficiency (cached)."""
    if eff not in _RATIO:
        rng = random.Random(12345)
        tot_m = tot_d = 0
        for _ in range(400):
            c = cascade(rng, 120, eff)
            tot_m += sum(c[1:])
            tot_d += 120
        _RATIO[eff] = tot_m / tot_d
    return _RATIO[eff]


def cascade(rng, D, eff):
    """Creations per level 0..11 in a round with D drops. c[11] = double Klunks (10+10)."""
    n = [0] * 12
    tw = sum(DROP_W)
    for _ in range(D):
        x = rng.random() * tw
        for lv, w in enumerate(DROP_W):
            x -= w
            if x <= 0:
                n[lv] += 1
                break
    c = [0] * 12
    c[0] = D
    for L in range(11):
        made = binom(rng, n[L] // 2, eff)
        c[L + 1] += made
        if L + 1 <= 10:
            n[L + 1] += made
    return c


# ============================================================ the player state

class Player:
    def __init__(self, cfg, prof, opts, seed):
        self.cfg, self.P, self.o = cfg, prof, opts
        self.rng = random.Random(seed)
        self.pearls = self.sand = 0
        self.grant_p = {}
        self.grant_s = {}
        self.merges = 0
        self.rounds = 0
        self.play_min = 0.0
        self.max_level = 0
        self.double_klunks = 0
        self.tens = 0
        self.ever_shiny = False
        self.pity = [0] * 11
        self.milestones = set()
        # collection: set index -> {'caught': [11 bool], 'shiny': [11 bool], 'l10': bool}
        n_sets = cfg['n_sets']
        self.pages = [{'caught': [False] * 11, 'shiny': [False] * 11, 'l10': False} for _ in range(n_sets)]
        self.unlocked = [0]
        self.sets_played = set()
        # buddies
        self.owned = {r: 0 for r in RAR}
        self.bud = []          # [rarity, level]
        self.fav = None        # index into bud
        self.free_claimed = 0
        self.shells_free = self.shells_bought = 0
        self.shell_log = []    # (play_min, day)
        self.first_shell_min = None
        self.first_shell_day = None
        self.t24 = self.t48 = None
        self.fav3 = None
        # journey
        self.jlevel, self.jxp = 1, LANES['journey']['xp_start']
        # missions
        self.missions_on = False
        self.slots = []
        self.missions_done = 0
        self.mission_by_tier = {1: 0, 2: 0, 3: 0}
        # lanes
        self.pool_on = False
        self.pool_stored, self.pool_since = 0.0, 0.0
        self.present_on = False
        self.present_bank, self.present_last, self.present_opened = 0, 0, 0
        self.daily_on = False
        self.daily_done = set()
        self.daily_best_beaten = False
        self.daily_sets = set()
        self.items = 0
        self.centerpiece = False
        self.trophies = set()
        self.stars = 0
        # session stats
        self.sessions = []  # (rounds, minutes, stop_any, stop_nodaily)

    # ---------------------------------------------------------- ledger
    def grant(self, src, pearls=0, sand=0):
        self.pearls += pearls
        self.sand += sand
        self.grant_p[src] = self.grant_p.get(src, 0) + pearls
        self.grant_s[src] = self.grant_s.get(src, 0) + sand

    def trophy(self, tid):
        if tid not in self.trophies:
            self.trophies.add(tid)
            if tid in HIDDEN_WITH_ITEM:
                self.items += 1

    # ---------------------------------------------------------- buddies
    def remaining(self, r):
        return self.cfg['count'][r] - self.owned[r]

    def n_owned(self):
        return len(self.bud)

    def shell_available(self, typ):
        floor = RAR.index(self.cfg['shells'][typ]['floor'])
        return self.n_owned() < 48 and any(self.remaining(r) > 0 for r in RAR[floor:])

    def draw(self, typ):
        cfg = self.cfg
        if cfg['first_shell_rare'] and self.n_owned() == 0:
            r = 'rare'
        else:
            w = cfg['shells'][typ]['odds']
            opts = [(r, w[i]) for i, r in enumerate(RAR) if w[i] > 0 and self.remaining(r) > 0]
            tot = sum(x for _, x in opts)
            x = self.rng.random() * tot
            r = opts[-1][0]
            for rr, v in opts:
                x -= v
                if x <= 0:
                    r = rr
                    break
        self.owned[r] += 1
        self.bud.append([r, 1])
        if self.fav is None or RAR.index(r) > RAR.index(self.bud[self.fav][0]):
            self.fav = len(self.bud) - 1  # a child switches to the shiniest new buddy
        self.shell_log.append((self.play_min, self.day))
        if self.first_shell_min is None:
            self.first_shell_min, self.first_shell_day = self.play_min, self.day
        if self.n_owned() >= 24 and self.t24 is None:
            self.t24 = (self.play_min, self.day)
        if self.n_owned() >= 48 and self.t48 is None:
            self.t48 = (self.play_min, self.day)

    def upg_cost(self, b):
        a, p3, s3 = self.cfg['upgrade'][b[0]]
        return (a, 0) if b[1] == 1 else (p3, s3) if b[1] == 2 else None

    def try_upgrade(self, i):
        b = self.bud[i]
        c = self.upg_cost(b)
        if c and self.pearls >= c[0] and self.sand >= c[1]:
            self.pearls -= c[0]
            self.sand -= c[1]
            b[1] += 1
            if i == self.fav and b[1] == 3 and self.fav3 is None:
                self.fav3 = (self.play_min, self.day)
            return True
        return False

    def shop(self):
        """Spending policy (est.): upgrade the favourite when affordable, gold with sand (keeping the
        favourite's III sand), silver when affordable, else common. After 48: upgrade by rarity."""
        S = self.cfg['shells']
        pol = self.o.get('policy', 'mixed')
        for _ in range(200):
            fav = self.bud[self.fav] if self.fav is not None else None
            if fav and fav[1] < 3 and (pol != 'collector' or self.n_owned() >= 48) and self.try_upgrade(self.fav):
                continue
            if self.n_owned() < 48:
                reserve = self.upg_cost(fav)[1] if (fav and fav[1] < 3 and pol != 'collector') else 0
                if self.sand - S['gold']['price'] >= reserve and self.shell_available('gold'):
                    self.sand -= S['gold']['price']
                    self.draw('gold')
                    self.shells_bought += 1
                    continue
                if self.pearls >= S['silver']['price'] and self.shell_available('silver'):
                    self.pearls -= S['silver']['price']
                    self.draw('silver')
                    self.shells_bought += 1
                    continue
                if pol != 'saver' or not self.shell_available('silver'):
                    if self.pearls >= S['common']['price'] and self.shell_available('common'):
                        self.pearls -= S['common']['price']
                        self.draw('common')
                        self.shells_bought += 1
                        continue
                break
            done = False
            for i in sorted(range(len(self.bud)), key=lambda k: -RAR.index(self.bud[k][0])):
                if self.bud[i][1] < 3 and self.try_upgrade(i):
                    done = True
                    break
            if not done:
                break

    def free_due(self):
        at, every = self.o.get('free_at', self.cfg['free_at']), self.o.get('free_every', self.cfg['free_every'])
        m = self.merges
        n = sum(1 for t in at if m >= t)
        if m >= at[-1]:
            n += (m - at[-1]) // every
        return n

    # ---------------------------------------------------------- journey / missions
    def journey_add(self, xp):
        self.jxp += xp
        while self.jxp >= journey_need(self.jlevel):
            self.jxp -= journey_need(self.jlevel)
            self.jlevel += 1
            L = self.jlevel
            p, s, aq, cp = journey_reward(L)
            self.grant('journey', p, s)
            self.items += aq
            self.centerpiece |= cp
            U = LANES['journey']['unlock']
            if L == U['missions']:
                self.missions_on = True
                if self.rng.random() < 0.9:  # surprise-first: round 1 already matched a goal (est.)
                    self.grant('mission', LANES['missions']['surprise_pearls'], 0)
                    self.missions_done += 1
                self.slots = []
                for _ in range(LANES['missions']['slots']):
                    self.slots.append(self.next_tier(self.slots))
            if L == U['aquarium']:
                self.pool_on = True
                self.pool_stored, self.pool_since = 0.0, self.now
                self.trophy('moving_in')
            if L == U['present']:
                self.present_on = True
                self.present_bank, self.present_last = 1, self.day
            if L == U['daily']:
                self.daily_on = True
                self.daily_since = self.day
            if L >= 10:
                self.trophy('journey10')
            if L >= 50:
                self.trophy('journey50')

    def next_tier(self, others):
        """Tier of the next mission: pool mix 14/9/3, at most 1 T3 active, at least 1 T1 active,
        T3 only after a level 8 (eligibility, RETENTION §3.7)."""
        mix = dict(LANES['missions']['pool_mix'])
        if self.max_level < 8 or 3 in others:
            mix.pop(3, None)
        if len(others) >= LANES['missions']['slots'] - 1 and 1 not in others:
            return 1
        tot = sum(mix.values())
        x = self.rng.random() * tot
        for t, w in mix.items():
            x -= w
            if x <= 0:
                return t
        return 1

    def missions_round(self, mult):
        if not self.missions_on:
            return
        base = self.o.get('mission_p', self.P['mission_p'])
        for i in range(len(self.slots)):
            t = self.slots[i]
            p = min(0.95, base[t - 1] * math.sqrt(mult))
            if self.rng.random() < p:
                rp, rs = self.o.get('mission_rewards', LANES['missions']['reward'])[t]
                k = self.o.get('mission_mult', 1.0)
                self.grant('mission', round(rp * k), rs)
                self.missions_done += 1
                self.mission_by_tier[t] += 1
                others = [x for j, x in enumerate(self.slots) if j != i]
                self.slots[i] = self.next_tier(others)
        if self.missions_done >= 10:
            self.trophy('ten_missions')

    # ---------------------------------------------------------- one round
    def play_round(self, set_idx, is_daily, mult):
        P, cfg, rng = self.P, self.cfg, self.rng
        m = P['merges'] * mult
        target = max(8.0, rng.gauss(m, 0.25 * m))
        D = max(10, round(target / merges_per_drop(P['eff'])))
        c = cascade(rng, D, P['eff'])
        merges = sum(c[1:])
        dur = P['round_min'] * max(0.4, min(2.0, merges / max(1.0, m)))
        self.rounds += 1
        self.play_min += dur
        self.now += dur / 60
        self.merges += merges
        top = max([L for L in range(11) if c[L] > 0] + [0])
        self.tops.append(top)
        # shinies (pity per level is global, as in systems/collection.ts)
        shinies = [0] * 11
        for L in range(1, 11):
            n = c[L]
            p = cfg['shiny_p'][L]
            T = round(cfg['pity_factor'] / p)
            while n > 0:
                need = min(geometric(rng, p), T - self.pity[L])
                if need <= n:
                    shinies[L] += 1
                    n -= need
                    self.pity[L] = 0
                else:
                    self.pity[L] += n
                    n = 0
        if not self.ever_shiny and sum(shinies) == 0 and self.rounds >= cfg['first_shiny_by_run']:
            lv = next((L for L in range(cfg['first_shiny_min_level'], 11) if c[L] > 0), None)
            if lv is not None:
                shinies[lv] += 1
        if sum(shinies):
            self.ever_shiny = True
        # chains and combos (est.)
        n3 = poisson(rng, merges * P['chain_k'])
        n5 = sum(1 for _ in range(n3) if rng.random() < 0.12)
        n7 = sum(1 for _ in range(n3) if rng.random() < 0.02)
        combo10 = rng.random() < 1 - math.exp(-merges * P['combo_a'] * 0.6 ** 7)
        # currency
        S = cfg['sand']
        self.grant('merge', merges * cfg['pearls_per_merge'], 0)
        rs = sum(shinies) * S['shiny'] + min(n3, S['chain3MaxPerRun']) * S['chain3'] + c[10] * S['level10']
        self.grant('round_sand', 0, rs)
        self.round_pe_log.append(merges + rs * SAND_PE)
        self.max_level = max(self.max_level, top)
        self.double_klunks += c[11]
        self.tens += c[10]
        for L in cfg['milestone_levels']:
            if self.max_level >= L and f'level{L}' not in self.milestones:
                self.milestones.add(f'level{L}')
                self.grant('milestone', 0, S['milestone'])
        if self.ever_shiny and 'shiny' not in self.milestones:
            self.milestones.add('shiny')
            self.grant('milestone', 0, S['milestone'])
        if self.double_klunks and 'doubleKlunk' not in self.milestones:
            self.milestones.add('doubleKlunk')
            self.grant('milestone', 0, S['milestone'])
        # book
        pg = self.pages[set_idx]
        for L in range(11):
            if c[L] > 0:
                pg['caught'][L] = True
            if shinies[L]:
                pg['shiny'][L] = True
        if c[10]:
            pg['l10'] = True
        self.sets_played.add(set_idx)
        # specials (est.)
        specials = poisson(rng, D / 42.5)
        bombs = binom(rng, specials, 0.5)
        rainbows = specials - bombs
        # trophies from the round
        tr = self.trophy
        if merges:
            tr('first_merge')
        if n3:
            tr('chain3')
        if n5:
            tr('chain5')
        if n7:
            tr('waterfall')
        if combo10:
            tr('combo10')
        if merges >= 120:
            tr('busy_jar')
        if any(rng.random() < 0.2 for _ in range(bombs)):
            tr('big_clear')
        if top >= 8 and any(rng.random() < 0.05 for _ in range(bombs)):
            tr('big_boom')
        if top >= 7 and any(rng.random() < 0.15 for _ in range(rainbows)):
            tr('rainbow_boost')
        if c[9] and any(rng.random() < 0.05 for _ in range(rainbows)):
            tr('rainbow_top')
        if rng.random() < P['danger3_p']:
            tr('steady_hands')
        for L in (7, 8, 9, 10):
            if self.max_level >= L:
                tr(f'level{L}')
        if self.double_klunks:
            tr('double_klunk')
        if c[10]:
            tr('whole_chain')
        if self.tens >= 5:
            tr('five_tens')
        if self.ever_shiny:
            tr('first_sparkle')
        if shinies[10]:
            tr('sparkling_giant')
        if sum(shinies) >= 2:
            tr('double_sparkle')
        if top >= 8 and rng.random() < P['calm_p']:
            tr('calm_steady')
        if is_daily:
            tr('jar_of_day')
            if top >= 9:
                tr('daily_deep')
        # journey, missions, free shells, sets
        self.journey_add(merges)
        self.missions_round(mult)
        due = self.free_due() - self.free_claimed
        for _ in range(due):
            self.free_claimed += 1
            if self.n_owned() < 48:
                self.draw('common')
                self.shells_free += 1
            else:
                self.grant('free_sand', 0, self.cfg['free_sand_complete'])
        self.check_sets()
        return top

    def check_sets(self):
        cfg = self.cfg
        spp = cfg['slots_per_page']

        def full(i):
            p = self.pages[i]
            return sum(p['caught']) + sum(p['shiny'][1:]) >= spp

        time_steps = sum(1 for t in cfg['set_thresholds'] if self.merges >= t)
        skill = sum(1 for L in cfg['skill_levels'] if self.max_level >= L)
        skill += 1 if self.double_klunks >= 1 else 0
        skill += 1 if any(full(i) for i in self.unlocked) else 0
        earned = max(time_steps, skill)
        while len(self.unlocked) - 1 < earned and len(self.unlocked) < cfg['n_sets']:
            rem = [i for i in range(cfg['n_sets']) if i not in self.unlocked]
            self.unlocked.append(self.rng.choice(rem))
        stars = 0
        n_shiny = 0
        master = False
        fullrow = fullpage = False
        for i in range(cfg['n_sets']):
            p = self.pages[i]
            n_shiny += sum(p['shiny'][1:])
            if i not in self.unlocked:
                continue
            s1, s2, s3 = all(p['caught']), p['l10'], full(i)
            stars += s1 + s2 + s3
            if s1:
                if f'plant{i}' not in self.milestones:
                    self.milestones.add(f'plant{i}')
                    self.items += 1
                fullrow = True
            if s3:
                fullpage = True
                if f'page:{i}' not in self.milestones:
                    self.milestones.add(f'page:{i}')
                    self.grant('fullpage', 0, cfg['sand']['fullPage'])
                    self.items += 1  # set backdrop
            if s1 and s2 and s3:
                master = True
        self.stars = stars
        if n_shiny >= 5:
            self.trophy('sparkle_collector')
        if fullrow:
            self.trophy('full_row')
        if fullpage:
            self.trophy('full_page')
        if master:
            self.trophy('set_master')
        if len(self.sets_played) >= cfg['n_sets']:
            self.trophy('set_explorer')
        if len(self.unlocked) == cfg['n_sets'] and all(full(i) for i in range(cfg['n_sets'])):
            self.trophy('whole_book')

    def pick_set(self):
        if len(self.unlocked) == 1 or self.rng.random() >= 0.5:
            return self.rng.choice(self.unlocked)

        def filled(i):
            p = self.pages[i]
            return sum(p['caught']) + sum(p['shiny'][1:])
        return min(self.unlocked, key=filled)

    # ---------------------------------------------------------- lanes at session start
    def session_start(self):
        L = LANES
        if self.pool_on:
            amt = min(L['pool']['cap'] * self.o.get('pool_scale', 1.0),
                      self.pool_stored + (L['pool']['cap'] * self.o.get('pool_scale', 1.0)) / L['pool']['fill_h']
                      * (self.now - self.pool_since))
            got = int(amt)
            self.pool_stored, self.pool_since = amt - got, self.now
            self.grant('pool', got, 0)
            self.trophy('moving_in')
            if self.rng.random() < self.P['hello_p']:
                self.trophy('say_hello')
        self.open_presents()
        if self.rng.random() < self.P['tap_buddy_p']:
            self.trophy('tickled')

    def open_presents(self):
        L = LANES['present']
        if not self.present_on:
            return
        if self.day > self.present_last:
            self.present_bank = min(L['bank_max'], self.present_bank + self.day - self.present_last)
            self.present_last = self.day
        pk = self.o.get('present_pearls', 25)
        while self.present_bank > 0:
            self.present_bank -= 1
            self.present_opened += 1
            k = (self.present_opened - 1) % 5
            p, s, it = L['cycle'][k]
            if k == 4 and self.present_opened > 5 * L['n_items']:
                p, s, it = self.o.get('present_after_items', L['after_items_5th'])
            self.grant('present', pk if p else 0, s)
            self.items += it

    def home_trophies(self):
        if self.items >= 5:
            self.trophy('decorator')
        if self.items >= 10 and self.centerpiece:
            self.trophy('full_aquarium')

    # ---------------------------------------------------------- a day
    def play_day(self, day, mult):
        self.day = day
        sched = self.o.get('sessions', self.P['sessions'])
        play_p = self.o.get('play_days', self.P['play_days'])
        if day > 1 and self.rng.random() >= play_p:
            return
        for (hour, minutes) in sched:
            self.now = (day - 1) * 24 + hour
            self.session_start()
            rounds, inround, stop_any, stop_nd = 0, 0.0, False, False
            archive_left = self.o.get('archive_per_session', 0)
            while True:
                is_daily = False
                set_idx = self.pick_set()
                if self.daily_on and day not in self.daily_done:
                    is_daily, set_idx = True, (day - 1) % self.cfg['n_sets']
                elif self.daily_on and archive_left > 0 and self.archive_backlog() > 0:
                    is_daily, archive_left = True, archive_left - 1
                    set_idx = self.rng.randrange(self.cfg['n_sets'])
                elif self.daily_on and day in self.daily_done and self.rng.random() < self.P['daily_replay_p'] / 3:
                    set_idx = (day - 1) % self.cfg['n_sets']
                    if self.rng.random() < 0.5:
                        self.trophy('better_try')
                before = self.play_min
                self.play_round(set_idx, is_daily, mult)
                rounds += 1
                inround += self.play_min - before
                if is_daily:
                    if day not in self.daily_done:
                        self.daily_done.add(day)
                        stop_any = True  # N9: first Daily Jar finish of the date
                    else:
                        self.archive_done += 1
                    self.grant('daily', 0, LANES['daily']['sand'])
                    self.daily_sets.add(set_idx)
                    if len(self.daily_sets) >= self.cfg['n_sets']:
                        self.trophy('every_jar_set')
                sess_min = inround + rounds * OVERHEAD_ROUND_MIN + OVERHEAD_SESSION_MIN
                if sess_min >= 20 or rounds >= 6:
                    stop_any = stop_nd = True
                if inround + 0.5 * self.P['round_min'] >= minutes:
                    break
            self.shop()
            self.open_presents()
            self.home_trophies()
            self.sessions.append((day, rounds, inround + rounds * OVERHEAD_ROUND_MIN + OVERHEAD_SESSION_MIN,
                                  stop_any, stop_nd))

    def archive_backlog(self):
        if not self.daily_on:
            return 0
        return (self.day - self.daily_since + 1) - len(self.daily_done) - self.archive_done

    def snapshot(self):
        tp = sum(self.grant_p.values()) + SAND_PE * sum(self.grant_s.values())
        daily = sum(self.grant_p.get(k, 0) + SAND_PE * self.grant_s.get(k, 0) for k in ('pool', 'present', 'daily'))
        fav = self.bud[self.fav][1] if self.fav is not None else 0
        return {'buddies': self.n_owned(), 'free': self.shells_free, 'bought': self.shells_bought,
                'jlevel': self.jlevel, 'pearls': self.pearls, 'sand': self.sand, 'fav': fav,
                'trophies': len(self.trophies), 'stars': self.stars, 'daily_share': daily / tp if tp else 0,
                'hours': self.play_min / 60, 'sets': len(self.unlocked), 'items': self.items,
                'missions': self.missions_done, 'all3': sum(1 for b in self.bud if b[1] == 3)}


def simulate(cfg, prof_name, opts=None, seed=0, days=60, extend_to=400):
    opts = opts or {}
    prof = dict(PROFILES[prof_name])
    prof.update(opts.get('profile_override', {}))
    p = Player(cfg, prof, opts, seed)
    p.round_pe_log = []
    p.tops = []
    p.archive_done = 0
    p.daily_since = None
    p.now = 0.0
    p.day = 1
    mult = opts.get('mult', 1.0)
    snaps = {}
    marks = {}
    day = 0
    while True:
        day += 1
        if day > days and (p.t48 is not None or day > extend_to):
            break
        p.play_day(day, mult)
        if day in (1, 2, 7, 14, 30, 60):
            snaps[day] = p.snapshot()
        if day == 7:
            marks['ledger7'] = (dict(p.grant_p), dict(p.grant_s))
        if day == 30:
            marks['ledger30'] = (dict(p.grant_p), dict(p.grant_s))
            marks['days30'] = day
            marks['round_pe30'] = list(p.round_pe_log)
    if 'ledger30' not in marks:
        marks['ledger30'] = (dict(p.grant_p), dict(p.grant_s))
        marks['round_pe30'] = list(p.round_pe_log)
    return p, snaps, marks


# ============================================================ metrics

def pe(ledger, keys):
    gp, gs = ledger
    return sum(gp.get(k, 0) + SAND_PE * gs.get(k, 0) for k in keys)


ALL_SRC = ['merge', 'round_sand', 'milestone', 'fullpage', 'mission', 'journey', 'pool', 'present', 'daily', 'free_sand']


def metrics(cfg, prof, opts, runs, days=60):
    rows = []
    for s in range(runs):
        p, snaps, marks = simulate(cfg, prof, opts, seed=1000 + s, days=days)
        L30 = marks['ledger30']
        total30 = pe(L30, ALL_SRC)
        merge_p = L30[0].get('merge', 0)
        mission_pe = pe(L30, ['mission'])
        mission_pearls = L30[0].get('mission', 0)
        daily_pe = pe(L30, ['pool', 'present', 'daily'])
        return_pe = pe(L30, ['pool', 'present'])
        return_8_30 = return_pe - pe(marks['ledger7'], ['pool', 'present'])
        played_8_30 = len({x[0] for x in p.sessions if 8 <= x[0] <= 30})
        journey_pe = pe(L30, ['journey'])
        rpe = st.mean(marks['round_pe30']) if marks['round_pe30'] else 1
        s30 = [x for x in p.sessions if x[0] <= 30]
        child_s = s30
        shells_5h = sum(1 for (m, d) in p.shell_log if m <= 300)
        rows.append({
            'snaps': snaps,
            'first_shell_min': p.first_shell_min, 'first_shell_day': p.first_shell_day,
            'shells_h1_5': shells_5h / 5 if p.play_min >= 300 else None,
            'h24': p.t24[0] / 60 if p.t24 else None, 'd24': p.t24[1] if p.t24 else None,
            'h48': p.t48[0] / 60 if p.t48 else None, 'd48': p.t48[1] if p.t48 else None,
            'fav3_h': p.fav3[0] / 60 if p.fav3 else None, 'fav3_d': p.fav3[1] if p.fav3 else None,
            'daily_share30': daily_pe / total30,
            'return_per_day_over_round': (return_8_30 / 23) / rpe,
            'return_per_played_day_over_round': (return_8_30 / max(1, played_8_30)) / rpe,
            'round_pe': rpe,
            'mission_share': mission_pe / merge_p, 'mission_pearl_share': mission_pearls / merge_p,
            'journey_share': journey_pe / total30,
            'sess_len': st.mean(x[2] for x in s30), 'sess_rounds': st.mean(x[1] for x in s30),
            'stop_any': sum(x[3] for x in child_s) / len(child_s),
            'stop_nodaily': sum(x[4] for x in child_s) / len(child_s),
            'missions_per_round': p.missions_done / max(1, p.rounds),
            'l10_rate': p.tens / max(1, p.rounds),
            'pct': {k: pe(L30, [k]) / total30 for k in ALL_SRC},
        })
    return rows


def med(xs):
    xs = [x for x in xs if x is not None]
    return st.median(xs) if xs else None


def pctl(xs, q):
    xs = sorted(x for x in xs if x is not None)
    if not xs:
        return None
    return xs[min(len(xs) - 1, int(q * len(xs)))]


def f(x, d=1):
    if x is None:
        return 'n/a'
    if isinstance(x, float):
        return f'{x:.{d}f}'
    return str(x)


def snap_table(rows, label):
    out = [f'**{label}** (median of {len(rows)} runs; buddies p10-p90 in brackets)', '',
           '| Day | Play h | Buddies | Shells free/bought | Journey L | Pearls | Sand | Fav. upgrade | Trophies /40 | Mastery stars /15 | Sets | Aquarium items | Daily-lane share (cum.) |',
           '|---|---|---|---|---|---|---|---|---|---|---|---|---|']
    for d in (1, 2, 7, 14, 30, 60):
        S = [r['snaps'][d] for r in rows if d in r['snaps']]
        g = lambda k: med([s[k] for s in S])
        fav = g('fav')
        favs = {1: 'I', 2: 'II', 3: 'III'}.get(round(fav) if fav else 0, '-')
        out.append(f"| {d} | {f(g('hours'))} | {f(g('buddies'), 0)} ({pctl([s['buddies'] for s in S], .1)}-{pctl([s['buddies'] for s in S], .9)}) | "
                   f"{f(g('free'), 0)}/{f(g('bought'), 0)} | {f(g('jlevel'), 0)} | {f(g('pearls'), 0)} | {f(g('sand'), 0)} | {favs} | "
                   f"{f(g('trophies'), 0)} | {f(g('stars'), 0)} | {f(g('sets'), 0)} | {f(g('items'), 0)} | {g('daily_share') * 100:.0f} % |")
    return '\n'.join(out)


# Recommended numbers (retention.md §5). Shop prices unchanged (RETENTION §6).
RECOMMENDED = {'free_at': [60, 400], 'mission_rewards': {1: (10, 0), 2: (20, 0), 3: (30, 1)},
               'pool_scale': 30 / 40, 'present_after_items': (25, 0, 0)}

TARGETS = {
    # T1 session minutes (lo, hi), T2 rounds (lo, hi), T3 max minutes, T4 shells/h, T5 h24, T6 h48, T7 levels
    'casual': dict(T1=(8.5, 11.5), T2=(2, 2), T3=10, T4=(2.5, 3.5), T5=(7, 9), T6=(14, 18), T6d=(84, 108), T7=(3, 10, 23)),
    'engaged': dict(T1=(11, 14), T2=(2, 3), T3=8, T4=(3.5, 4.5), T5=(5, 7), T6=(10, 14), T6d=(24, 34), T7=(6, 19, 41)),
    'skilled': dict(T1=(17, 23), T2=(3, 4), T3=7, T4=(4.5, 5.5), T5=(4, 5.5), T6=(8, 11), T6d=(12, 17), T7=(9, 26, 55)),
}


def pf(ok):
    return 'PASS' if ok else 'FAIL'


def within(x, lo, hi, tol=0.0):
    return x is not None and lo * (1 - tol) <= x <= hi * (1 + tol)


def target_rows(prof, rows):
    T = TARGETS[prof]
    g = lambda k: med([r[k] for r in rows])
    res = []
    sl, sr = g('sess_len'), g('sess_rounds')
    stop = g('stop_any')
    stop_nd = g('stop_nodaily')
    child = prof != 'skilled'
    t1 = within(sl, *T['T1']) and (not child or stop <= 0.25)
    res.append(('T1', f"{sl:.1f} min; stop moment in {stop * 100:.0f} % of sessions ({stop_nd * 100:.0f} % without the Daily Jar trigger)",
                f"{T['T1'][0]}-{T['T1'][1]} min" + ('; stop <= 25 %' if child else ''), pf(t1)))
    res.append(('T2', f'{sr:.2f}', f"{T['T2'][0]}-{T['T2'][1]}", pf(T['T2'][0] - 0.3 <= sr <= T['T2'][1] + 0.3)))
    fs = g('first_shell_min')
    day1 = sum(1 for r in rows if r['first_shell_day'] == 1) / len(rows)
    res.append(('T3', f'{fs:.1f} min play (p90 {pctl([r["first_shell_min"] for r in rows], .9):.1f}); on day 1 for {day1 * 100:.0f} %',
                f"<= {T['T3']} min", pf(fs <= T['T3'])))
    s5 = g('shells_h1_5')
    res.append(('T4', f(s5, 2), f"{T['T4'][0]}-{T['T4'][1]}", pf(within(s5, *T['T4']))))
    h24, d24 = g('h24'), g('d24')
    res.append(('T5', f'{f(h24)} h (day {f(d24, 0)})', f"{T['T5'][0]}-{T['T5'][1]} h", pf(within(h24, *T['T5']))))
    h48, d48 = g('h48'), g('d48')
    res.append(('T6', f'{f(h48)} h (day {f(d48, 0)})', f"{T['T6'][0]}-{T['T6'][1]} h; days {T['T6d'][0]}-{T['T6d'][1]}",
                pf(within(h48, *T['T6']) and within(d48, *T['T6d']))))
    lv = [med([r['snaps'][d]['jlevel'] for r in rows]) for d in (1, 7, 30)]
    ok = all(within(v, t, t, 0.15) for v, t in zip(lv, T['T7']))
    res.append(('T7', ' / '.join(f(v, 0) for v in lv), ' / '.join(str(t) for t in T['T7']) + ' (±15 %)', pf(ok)))
    ds = g('daily_share30')
    res.append(('T8', f'{ds * 100:.1f} %', '<= 35 %', pf(ds <= 0.35)))
    rv = g('return_per_day_over_round')
    rvp = g('return_per_played_day_over_round')
    res.append(('T9', f'{rv:.2f} per calendar day ({rvp:.2f} per played day)', '< 1.0 (goal <= 0.8)', 'PASS' if rv <= 0.8 else ('PASS inv. 3, FAIL 0.8 goal' if rv < 1.0 else 'FAIL')))
    ms, mps = g('mission_share'), g('mission_pearl_share')
    mpr = g('missions_per_round')
    res.append(('T10', f'{ms * 100:.1f} % in pe ({mps * 100:.1f} % pearls only); {mpr:.2f} completions/round',
                '<= 25 %; 0.5-1.0 per round', pf(ms <= 0.25 and 0.5 <= mpr <= 1.0)))
    js = g('journey_share')
    res.append(('T11', f'{js * 100:.1f} %', '<= 10 %', pf(js <= 0.10)))
    return res


def t12(cfg, casual_round_pe, present_pearls=25, pool_cap=40, after_items=None):
    """Max value after 7 days away: 7 banked presents (best cycle position) + a full pool, in pe.
    Returns (while the 12 present decorations last, after they are used up, limit = 3 casual rounds)."""
    L = LANES['present']
    after = after_items

    def best(after_items):
        vals = []
        for start in range(5):
            v = 0
            for k in range(7):
                i = (start + k) % 5
                p, s_, _ = (after or L['after_items_5th']) if (after_items and i == 4) else L['cycle'][i]
                v += (present_pearls if p else 0) + SAND_PE * s_
            vals.append(v)
        return max(vals)
    return best(False) + pool_cap, best(True) + pool_cap, 3 * casual_round_pe


# ============================================================ report

def run_all(args):
    cfg = load_config()
    R = args.runs
    out = []
    w = out.append
    w('<!-- generated by docs/sim/retention_sim.py; paste into retention.md -->')
    w(f"Config read from app/src/data: free.at={cfg['free_at']} every={cfg['free_every']}, shells="
      f"{ {k: (v['price'], v['cur']) for k, v in cfg['shells'].items()} }, counts={cfg['count']}, "
      f"set thresholds={cfg['set_thresholds']}, shinyP L1/L5/L7/L9={[round(1 / cfg['shiny_p'][i]) for i in (1, 5, 7, 9)]}")
    w('')
    w('Journey check (RETENTION §3.4): cumulative merges to L2/L3/L4/L5/L10/L20/L30/L50/L100 = ' +
      ', '.join(str(merges_to_level(L)) for L in (2, 3, 4, 5, 10, 20, 30, 50, 100)))
    w('')
    for pn in PROFILES:
        e = PROFILES[pn]['eff']
        w(f"Round model {pn}: {merges_per_drop(e):.2f} merges/drop at eff {e}")
    w('')

    avg_units = sum(w * 2 ** i for i, w in enumerate(DROP_W)) / sum(DROP_W)
    w('Mass bound: a level-L piece is 2^L level-0 units; an average drop is '
      f'{avg_units:.2f} units, so one level 8 / 9 / 10 needs at least '
      + ' / '.join(f'{2 ** L / avg_units:.0f}' for L in (8, 9, 10)) + ' drops in the same round (perfect merging).')
    w('')
    w('| Profile | Merges/round | P(top level >= 7) | >= 8 | >= 9 | >= 10 per round |')
    w('|---|---|---|---|---|---|')
    for pn in PROFILES:
        for mm in (PROFILES[pn]['merges'], 150):
            rng = random.Random(7)
            e = PROFILES[pn]['eff']
            tops = []
            for _ in range(2000):
                target = max(8.0, rng.gauss(mm, 0.25 * mm))
                c = cascade(rng, max(10, round(target / merges_per_drop(e))), e)
                tops.append(max(L for L in range(11) if c[L] > 0))
            w(f"| {PROFILES[pn]['label']} | {mm} | " + ' | '.join(
                f'{sum(t >= L for t in tops) / len(tops) * 100:.0f} %' for L in (7, 8, 9, 10)) + ' |')
    w('')

    variants = {'90': {'free_at': [90, 400]}, '120': {'free_at': [120, 400]}}
    base_rows = {}
    for pn in PROFILES:
        for vn, vo in variants.items():
            base_rows[(pn, vn)] = metrics(cfg, pn, vo, R)

    if args.only in (None, 'base'):
        w('## Base tables (first free shell at 90, all other numbers as RETENTION §3)\n')
        for pn in PROFILES:
            w(snap_table(base_rows[(pn, '90')], f"{PROFILES[pn]['label']}: {PROFILES[pn]['merges']} merges/round, "
                                                  f"{PROFILES[pn]['round_min']} min/round"))
            rows = base_rows[(pn, '90')]
            ex = med([r['l10_rate'] for r in rows])
            w(f"\nFavourite at III: median {f(med([r['fav3_h'] for r in rows]))} h play (day {f(med([r['fav3_d'] for r in rows]), 0)}). "
              f"Level 10 per round: {ex:.2f}. Mean round value {med([r['round_pe'] for r in rows]):.0f} pe.\n")
        w('## Targets (RETENTION §6), first free shell at 90\n')
        for pn in PROFILES:
            w(f"**{PROFILES[pn]['label']}**\n")
            w('| # | Result | Target | Verdict |\n|---|---|---|---|')
            for t, r_, tg, v in target_rows(pn, base_rows[(pn, '90')]):
                w(f'| {t} | {r_} | {tg} | {v} |')
            w('')
        crpe = med([r['round_pe'] for r in base_rows[('casual', '90')]])
        a, b, lim = t12(cfg, crpe)
        w(f'**T12** max value after 7 days away: {a} pe while present decorations remain (+1 item), {b} pe after all 12 '
          f'decorations are given (present #61+); limit 3 casual rounds = {lim:.0f} pe. '
          f'Verdict: {pf(a <= lim)} now, {pf(b <= lim)} after the decorations run out.\n')
        w('## Reward mix, days 1-30 (share of all pe earned)\n')
        w('| Source | ' + ' | '.join(PROFILES[p]['label'] for p in PROFILES) + ' |\n|---|---|---|---|')
        for k in ALL_SRC:
            w(f'| {k} | ' + ' | '.join(f"{med([r['pct'][k] for r in base_rows[(p, '90')]]) * 100:.1f} %" for p in PROFILES) + ' |')
        w('')

    if args.only in (None, 'free'):
        w('## First free shell: 90 vs 120\n')
        w('| Profile | Threshold | First shell, median play min | p90 | Share with first shell on day 1 | Shells/h h1-5 | Hours to 24 | Hours to 48 |')
        w('|---|---|---|---|---|---|---|---|')
        extra = {}
        for pn in PROFILES:
            for thr in (45, 60, 75):
                extra[(pn, str(thr))] = metrics(cfg, pn, {'free_at': [thr, 400]}, max(40, R // 2))
        for pn in PROFILES:
            for vn in ('120', '90', '75', '60', '45'):
                rows = base_rows.get((pn, vn)) or extra[(pn, vn)]
                d1 = sum(1 for r in rows if r['first_shell_day'] == 1) / len(rows)
                w(f"| {PROFILES[pn]['label']} | {vn} | {f(med([r['first_shell_min'] for r in rows]))} | "
                  f"{f(pctl([r['first_shell_min'] for r in rows], .9))} | {d1 * 100:.0f} % | {f(med([r['shells_h1_5'] for r in rows]), 2)} | "
                  f"{f(med([r['h24'] for r in rows]))} | {f(med([r['h48'] for r in rows]))} |")
        w('')

    if args.only in (None, 'sens'):
        w('## Sensitivity: merges per round ±30 % (round length unchanged), first free shell at 90\n')
        w('| Profile | Merges/round | Buddies d7 / d30 | Journey L d1/d7/d30 | Hours to 24 / 48 | Shells/h h1-5 | Daily-lane share | Return/round (played day) | Missions/merge pearls | First shell min |')
        w('|---|---|---|---|---|---|---|---|---|---|')
        for pn in PROFILES:
            for mult in (0.7, 1.0, 1.3):
                rows = base_rows[(pn, '90')] if mult == 1.0 else metrics(cfg, pn, {'free_at': [90, 400], 'mult': mult}, max(40, R // 2))
                s = lambda d, k: med([r['snaps'][d][k] for r in rows])
                w(f"| {PROFILES[pn]['label']} | {PROFILES[pn]['merges'] * mult:.0f} | {f(s(7, 'buddies'), 0)} / {f(s(30, 'buddies'), 0)} | "
                  f"{f(s(1, 'jlevel'), 0)}/{f(s(7, 'jlevel'), 0)}/{f(s(30, 'jlevel'), 0)} | {f(med([r['h24'] for r in rows]))} / {f(med([r['h48'] for r in rows]))} | "
                  f"{f(med([r['shells_h1_5'] for r in rows]), 2)} | {med([r['daily_share30'] for r in rows]) * 100:.1f} % | "
                  f"{med([r['return_per_played_day_over_round'] for r in rows]):.2f} | {med([r['mission_share'] for r in rows]) * 100:.1f} % | "
                  f"{f(med([r['first_shell_min'] for r in rows]))} |")
        w('')
        w('## Schedule variants (first free shell at 90)\n')
        w('| Profile | Schedule | Journey L d1/d7/d30 | Buddies d30 | Days to 48 | Daily-lane share | Return/round (played day) |')
        w('|---|---|---|---|---|---|---|')
        scheds = {
            'casual': [('7/7, 1 session', {'play_days': 1.0}), ('4/7, 1 session', {'play_days': 4 / 7}),
                       ('4/7 + 1 archive jar per session', {'play_days': 4 / 7, 'archive_per_session': 1})],
            'engaged': [('4/7, 2 sessions', {'play_days': 4 / 7}), ('7/7, 1 session of 25 min', {'sessions': [(17.0, 25.0)]})],
            'skilled': [('4/7, 2 sessions', {'play_days': 4 / 7}), ('7/7, 1 session of 40 min', {'sessions': [(20.0, 40.0)]})],
        }
        for pn, lst in scheds.items():
            for name, o in lst:
                o = dict(o, free_at=[90, 400])
                rows = metrics(cfg, pn, o, max(40, R // 2))
                s = lambda d, k: med([r['snaps'][d][k] for r in rows])
                w(f"| {PROFILES[pn]['label']} | {name} | {f(s(1, 'jlevel'), 0)}/{f(s(7, 'jlevel'), 0)}/{f(s(30, 'jlevel'), 0)} | "
                  f"{f(s(30, 'buddies'), 0)} | {f(med([r['d48'] for r in rows]), 0)} | {med([r['daily_share30'] for r in rows]) * 100:.1f} % | "
                  f"{med([r['return_per_played_day_over_round'] for r in rows]):.2f} |")
        w('')
        w('## R12 check: casual child T8 and T9 at 4/7 and 7/7 days played\n')
        w('| Schedule | Knobs | T8 daily-lane share d1-30 | T9 per calendar day (d8-30) | T9 per played day | Verdict (T8 <= 35 %, T9 <= 0.8) |')
        w('|---|---|---|---|---|---|')
        for sname, pdays in (('7/7', 1.0), ('5/7 (base)', 5 / 7), ('4/7', 4 / 7)):
            for kname, ko in (('as spec', {}), ('missions 15/20/30(+1) + every 900', {'mission_rewards': {1: (15, 0), 2: (20, 0), 3: (30, 1)}, 'free_every': 900})):
                rows = metrics(cfg, 'casual', dict(ko, play_days=pdays, free_at=[90, 400]), max(60, R // 2))
                t8 = med([r['daily_share30'] for r in rows])
                t9 = med([r['return_per_day_over_round'] for r in rows])
                t9p = med([r['return_per_played_day_over_round'] for r in rows])
                w(f'| {sname} | {kname} | {t8 * 100:.1f} % (p90 {pctl([r["daily_share30"] for r in rows], .9) * 100:.1f} %) | {t9:.2f} | {t9p:.2f} | '
                  f'{pf(t8 <= 0.35 and t9 <= 0.8)} |')
        w('')
        w('## Spending policy variants (engaged child, first free shell at 90)\n')
        w('| Policy | Buddies d7 / d30 | Hours to 48 | Fav. III at h | Pearls / sand d30 | Pearls / sand d60 |\n|---|---|---|---|---|---|')
        for pol in ('mixed', 'collector', 'saver'):
            rows = base_rows[('engaged', '90')] if pol == 'mixed' else metrics(cfg, 'engaged', {'free_at': [90, 400], 'policy': pol}, max(40, R // 2))
            s = lambda d, k: med([r['snaps'][d][k] for r in rows])
            w(f"| {pol} | {f(s(7, 'buddies'), 0)} / {f(s(30, 'buddies'), 0)} | {f(med([r['h48'] for r in rows]))} | {f(med([r['fav3_h'] for r in rows]))} | "
              f"{f(s(30, 'pearls'), 0)} / {f(s(30, 'sand'), 0)} | {f(s(60, 'pearls'), 0)} / {f(s(60, 'sand'), 0)} |")
        w('')

    if args.only in (None, 'sens'):
        w('## Calibration scenario: long rounds (150 merges/round, same minutes per round)\n')
        w('What the game looks like if the playtest shows level 10 "every 3-5 min" (UI.md §6), which needs >= ~150 merges per round.\n')
        w('| Profile | Buddies d7 / d30 | Journey L d1/d7/d30 | Mastery stars d30 / d60 | Trophies d30 | Hours to 48 | Days to 48 | Daily share | Missions/merge pearls |')
        w('|---|---|---|---|---|---|---|---|---|')
        for pn in PROFILES:
            mult = 150 / PROFILES[pn]['merges']
            rows = metrics(cfg, pn, {'free_at': [90, 400], 'mult': mult}, max(30, R // 4))
            s_ = lambda d, k: med([r['snaps'][d][k] for r in rows])
            w(f"| {PROFILES[pn]['label']} | {f(s_(7, 'buddies'), 0)} / {f(s_(30, 'buddies'), 0)} | {f(s_(1, 'jlevel'), 0)}/{f(s_(7, 'jlevel'), 0)}/{f(s_(30, 'jlevel'), 0)} | "
              f"{f(s_(30, 'stars'), 0)} / {f(s_(60, 'stars'), 0)} | {f(s_(30, 'trophies'), 0)} | {f(med([r['h48'] for r in rows]))} | {f(med([r['d48'] for r in rows]), 0)} | "
              f"{med([r['daily_share30'] for r in rows]) * 100:.1f} % | {med([r['mission_share'] for r in rows]) * 100:.1f} % |")
        w('')

    if args.only in (None, 'rec'):
        w('## Recommended numbers, re-simulated (first free shell 60, missions 10/20/30+1 sand, pool cap 30, present #5 after the decorations = 25 pearls)\n')
        recrows = {}
        for pn in PROFILES:
            recrows[pn] = metrics(cfg, pn, RECOMMENDED, R)
            w(snap_table(recrows[pn], PROFILES[pn]['label']))
            w('')
            w('| # | Result | Target | Verdict |\n|---|---|---|---|')
            for t, r_, tg, v in target_rows(pn, recrows[pn]):
                w(f'| {t} | {r_} | {tg} | {v} |')
            w('')
        crpe = med([r['round_pe'] for r in recrows['casual']])
        a, b, lim = t12(cfg, crpe, pool_cap=30, after_items=(25, 0, 0))
        w(f'**T12 (recommended)**: {a} pe / {b} pe after the decorations; limit {lim:.0f} pe: {pf(max(a, b) <= lim)}\n')
        w('**R12 (recommended numbers), casual child**\n')
        w('| Days played | Merges/round | T8 median (p90) | T9 per calendar day | Verdict |\n|---|---|---|---|---|')
        for sname, pd in (('7/7', 1.0), ('5/7', 5 / 7), ('4/7', 4 / 7)):
            for mult in (1.0, 0.7):
                rows = metrics(cfg, 'casual', dict(RECOMMENDED, play_days=pd, mult=mult), max(60, R // 2))
                t8 = med([r['daily_share30'] for r in rows])
                t9 = med([r['return_per_day_over_round'] for r in rows])
                w(f"| {sname} | {PROFILES['casual']['merges'] * mult:.0f} | {t8 * 100:.1f} % ({pctl([r['daily_share30'] for r in rows], .9) * 100:.1f} %) | "
                  f"{t9:.2f} | {pf(t8 <= 0.35 and t9 <= 0.8)} |")
        w('')

    if args.only in (None, 'knobs'):
        w('## Knobs (RETENTION §6 order), re-simulated with first free shell at 90\n')
        knobs = [
            ('baseline', {}),
            ('missions x0.8', {'mission_mult': 0.8}),
            ('missions x0.8 + free.every 900', {'mission_mult': 0.8, 'free_every': 900}),
            ('missions x0.8 + free.every 900 + pool cap 30', {'mission_mult': 0.8, 'free_every': 900, 'pool_scale': 0.75}),
            ('... + present 20', {'mission_mult': 0.8, 'free_every': 900, 'pool_scale': 0.75, 'present_pearls': 20}),
            ('missions x0.6', {'mission_mult': 0.6}),
            ('missions 15/20/30(+1 sand)', {'mission_rewards': {1: (15, 0), 2: (20, 0), 3: (30, 1)}}),
            ('missions 15/20/30(+1) + free.every 900', {'mission_rewards': {1: (15, 0), 2: (20, 0), 3: (30, 1)}, 'free_every': 900}),
            ('missions 15/20/30(+1) + first shell 60 + every 900', {'mission_rewards': {1: (15, 0), 2: (20, 0), 3: (30, 1)}, 'free_every': 900, 'first60': True}),
        ]
        w('| Knob set | Profile | Missions/merge pearls (T10) | Daily share (T8) | Return/round (T9) | Shells/h h1-5 (T4) | Hours to 24 (T5) | Hours to 48 (T6) | Days to 48 |')
        w('|---|---|---|---|---|---|---|---|---|')
        for name, o in knobs:
            for pn in PROFILES:
                o2 = dict(o, free_at=[60 if o.get('first60') else 90, 400])
                rows = base_rows[(pn, '90')] if not o else metrics(cfg, pn, o2, max(40, R // 2))
                w(f"| {name} | {PROFILES[pn]['label']} | {med([r['mission_share'] for r in rows]) * 100:.1f} % | "
                  f"{med([r['daily_share30'] for r in rows]) * 100:.1f} % | {med([r['return_per_played_day_over_round'] for r in rows]):.2f} | "
                  f"{f(med([r['shells_h1_5'] for r in rows]), 2)} | {f(med([r['h24'] for r in rows]))} | {f(med([r['h48'] for r in rows]))} | "
                  f"{f(med([r['d48'] for r in rows]), 0)} |")
        w('')
    print('\n'.join(out))


def calibrate_from_playtest(path, prof):
    """Override a profile's merges/round and round length from a debug-panel JSON export."""
    with open(path, encoding='utf-8') as fh:
        data = json.load(fh)
    rounds = []

    def walk(x):
        if isinstance(x, dict):
            if 'merges' in x and 'durationMs' in x:
                rounds.append(x)
            for v in x.values():
                walk(v)
        elif isinstance(x, list):
            for v in x:
                walk(v)
    walk(data)
    if not rounds:
        sys.exit(f'{path}: no rounds with merges + durationMs found')
    m = st.median(r['merges'] for r in rounds)
    t = st.median(r['durationMs'] for r in rounds) / 60000
    PROFILES[prof]['merges'] = m
    PROFILES[prof]['round_min'] = t
    print(f'<!-- calibrated {prof} from {path}: {len(rounds)} rounds, median {m} merges, {t:.2f} min -->')


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--runs', type=int, default=200)
    ap.add_argument('--quick', action='store_true')
    ap.add_argument('--only', choices=['base', 'free', 'sens', 'rec', 'knobs'])
    ap.add_argument('--playtest')
    ap.add_argument('--profile', choices=list(PROFILES))
    a = ap.parse_args()
    if a.quick:
        a.runs = 40
    if a.playtest:
        calibrate_from_playtest(a.playtest, a.profile or 'engaged')
    run_all(a)

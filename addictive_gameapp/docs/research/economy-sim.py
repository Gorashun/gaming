"""Simulering av KLUNK-ekonomin (economy-research.md §5). Kör: python3 economy-sim.py
Alla intjäningsantaganden är UPPSKATTNINGAR tills merges per runda är mätt (PLAYTEST.md)."""
import random, statistics as st

RAR = ['common', 'uncommon', 'rare', 'epic', 'legendary', 'mythic']
COUNT = {'common': 16, 'uncommon': 12, 'rare': 9, 'epic': 6, 'legendary': 3, 'mythic': 2}
# Musseltyper: pris, valuta, vikter (omnormeras bland rariteter >= golv med figurer kvar)
SHELLS = {
    'plain':  {'price': 300, 'cur': 'pearl', 'w': [50, 30, 13, 5, 1.5, 0.5]},
    'silver': {'price': 700, 'cur': 'pearl', 'w': [0, 50, 30, 14, 4.5, 1.5]},
    'gold':   {'price': 50,  'cur': 'sand',  'w': [0, 0, 50, 32, 13, 5]},
}
FREE_AT = [120, 400]              # två tidiga gratismusslor (onboarding) ...
FREE_EVERY_MERGES = 750          # ... sedan en gratis vanlig mussla per 750 merges (flat, ingen kurva)
# Uppgradering: (pärlor till II, pärlor till III, stjärnsand till III)
UPG = {'common': (80, 200, 4), 'uncommon': (100, 250, 6), 'rare': (150, 400, 10),
       'epic': (200, 500, 14), 'legendary': (250, 650, 18), 'mythic': (300, 800, 24)}
SAND_MILESTONES = [(1, 3), (2, 3), (3, 3), (5, 3), (8, 3), (15, 3)]  # (runda, sand) uppskattad tidpunkt
ALL_OWNED_FREE_SAND = 10

def sand_per_round(m, rng):
    # 1 per skimrande (~m/60), 1 per kedja >= 3 (~0,8), 2 per nivå 10 (~30 % av rundor). UPPSKATTNING.
    shiny = sum(rng.random() < 1 / 60 for _ in range(m))
    chains = sum(rng.random() < 0.8 / 3 for _ in range(3))
    top = 2 if rng.random() < 0.3 else 0
    return shiny + chains + top

def draw(shell, owned, rng):
    w = SHELLS[shell]['w']
    opts = [(r, w[i]) for i, r in enumerate(RAR) if w[i] > 0 and owned[r] < COUNT[r]]
    if not opts:  # golvet tomt: fall tillbaka på alla rariteter med figurer kvar
        opts = [(r, 1) for r in RAR if owned[r] < COUNT[r]]
    tot = sum(x for _, x in opts); x = rng.random() * tot
    for r, v in opts:
        x -= v
        if x <= 0: return r
    return opts[-1][0]

def run(m, policy, rounds=600, seed=0):
    rng = random.Random(seed)
    owned = {r: 0 for r in RAR}; lv = []  # lista av [raritet, nivå]
    pearl = sand = merges = 0; free_given = 0; boxes = 0
    log = {}
    turn = ['upg']
    def n(): return sum(owned.values())
    def give(r):
        nonlocal boxes
        owned[r] += 1; lv.append([r, 1]); boxes += 1
    give('rare')  # onboarding: första musslan (runda 1) alltid sällsynt
    for R in range(1, rounds + 1):
        mm = max(10, int(rng.gauss(m, m * 0.25)))
        merges += mm; pearl += mm; sand += sand_per_round(mm, rng)
        sand += sum(s for r, s in SAND_MILESTONES if r == R)
        def free_due():
            extra = max(0, (merges - FREE_AT[-1]) // FREE_EVERY_MERGES)
            return sum(merges >= t for t in FREE_AT) + extra
        while free_due() > free_given:
            free_given += 1
            if n() < 48: give(draw('plain', owned, rng))
            else: sand += ALL_OWNED_FREE_SAND
        # favorit = högsta raritet som ägs
        fav = max(lv, key=lambda a: RAR.index(a[0]))
        def try_upgrade(a):
            nonlocal pearl, sand
            c = UPG[a[0]]
            if a[1] == 1 and pearl >= c[0]: pearl -= c[0]; a[1] = 2; return True
            if a[1] == 2 and pearl >= c[1] and sand >= c[2]: pearl -= c[1]; sand -= c[2]; a[1] = 3; return True
            return False
        acted = True
        while acted:
            acted = False
            if policy == 'upgrader' and fav[1] < 3 and try_upgrade(fav): acted = True; continue
            if policy == 'balanced' and turn[0] == 'upg':
                top3 = sorted(lv, key=lambda a: -RAR.index(a[0]))[:3]
                t = next((a for a in top3 if a[1] < 3), None)
                if t and try_upgrade(t): turn[0] = 'box'; acted = True; continue
                if t and n() < 48 and pearl < UPG[t[0]][t[1] - 1] + SHELLS['plain']['price']: break
            if n() < 48 and sand >= SHELLS['gold']['price'] and any(owned[r] < COUNT[r] for r in RAR[2:]):
                sand -= SHELLS['gold']['price']; give(draw('gold', owned, rng)); acted = True; continue
            if n() < 48 and pearl >= SHELLS['plain']['price'] and (policy != 'upgrader' or fav[1] == 3):
                pearl -= SHELLS['plain']['price']; give(draw('plain', owned, rng)); turn[0] = 'upg'; acted = True; continue
            if n() == 48:
                for a in sorted(lv, key=lambda a: -RAR.index(a[0])):
                    if try_upgrade(a): acted = True; break
        for k, cond in (('n12', n() >= 12), ('n24', n() >= 24), ('n48', n() >= 48),
                        ('fav3', fav[1] == 3),
                        ('top3', sum(a[1] == 3 for a in sorted(lv, key=lambda a: -RAR.index(a[0]))[:3]) == 3), ('all3', all(a[1] == 3 for a in lv) and n() == 48)):
            if cond and k not in log: log[k] = R
        for k in (1, 3, 10, 30, 60, 100):
            if R == k: log[f'b{k}'] = n()
    return log

MIN_PER_ROUND = 5  # UPPSKATTNING (avatar-box-research §6)
for m in (40, 60, 80):
    for pol in ('collector', 'balanced', 'upgrader'):
        logs = [run(m, pol, seed=s) for s in range(300)]
        med = lambda k: st.median([l.get(k, 999) for l in logs])
        h = lambda k: f"{med(k):.0f} ({med(k) * MIN_PER_ROUND / 60:.1f} h)"
        print(f"m={m} {pol:9s} | efter 1/3/10/30/60/100 rundor: "
              f"{med('b1'):.0f}/{med('b3'):.0f}/{med('b10'):.0f}/{med('b30'):.0f}/{med('b60'):.0f}/{med('b100'):.0f}"
              f" | 24 st: {h('n24')} | 48 st: {h('n48')} | favorit III: {h('fav3')} | topp-3 III: {h('top3')} | allt III: {h('all3')}")

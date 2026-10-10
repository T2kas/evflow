"""Quick session / overstay analysis of evflow data (stdlib only).
usage: python3 -I analyze.py <evflow data dir>
"""
import csv, glob, os, sys, json, statistics
from collections import defaultdict, Counter
from datetime import datetime, timezone, timedelta

D = sys.argv[1]
P = lambda *a: os.path.join(D, "data", *a)
ts = lambda s: datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
LT = timezone(timedelta(hours=3))  # EEST in October

# --- static
st = {}
for r in csv.DictReader(open(P("stations.csv"), encoding="utf-8")):
    try:
        kw = max(float(x) for x in r["power_kw"].split("|") if x)
    except ValueError:
        kw = None
    r["kw"] = kw
    r["dc"] = any(t in r["connector_type"] for t in ("COMBO", "CHADEMO")) or (kw or 0) > 43
    st[r["connector_id"]] = r

# --- runs / gaps
runs = [ts(r["timestamp_utc"]) for r in csv.DictReader(open(P("runs.csv")))]
runs.sort()
gaps = [(a, b) for a, b in zip(runs, runs[1:]) if (b - a).total_seconds() > 600]
t0, t1 = runs[0], runs[-1]

def has_gap(a, b):
    return any(g0 < b and g1 > a for g0, g1 in gaps)

# --- status events
ev = defaultdict(list)
for f in sorted(glob.glob(P("status", "*.csv"))):
    for r in csv.DictReader(open(f, encoding="utf-8")):
        ev[r["connector_id"]].append((ts(r["timestamp_utc"]), r["status"]))

# connector-level occupied intervals
occ = defaultdict(list)  # charger_id -> [(start, end, cid, complete)]
for cid, es in ev.items():
    es.sort()
    cur = None
    first = True
    for t, s in es:
        if s == "Užimta" and cur is None:
            cur = (t, first)  # started already occupied at first record -> left-censored
        elif s != "Užimta" and cur is not None:
            if not cur[1]:
                occ[st.get(cid, {}).get("charger_id") or cid].append((cur[0], t, cid, True))
            cur = None
        first = False
    if cur is not None and not cur[1]:
        occ[st.get(cid, {}).get("charger_id") or cid].append((cur[0], t1, cid, False))

# merge connectors of one charger that flip together (same car shown on all plugs)
sessions = []
for ch, iv in occ.items():
    iv.sort()
    used = [False] * len(iv)
    for i, (a, b, cid, comp) in enumerate(iv):
        if used[i]:
            continue
        group = [cid]
        for j in range(i + 1, len(iv)):
            a2, b2, cid2, _ = iv[j]
            if (a2 - a).total_seconds() > 240:
                break
            if not used[j] and cid2 != cid and abs((b2 - b).total_seconds()) < 240:
                used[j] = True
                group.append(cid2)
        # choose the connector with highest power as representative
        rep = max(group, key=lambda c: st.get(c, {}).get("kw") or 0)
        sessions.append(dict(charger=ch, cid=rep, start=a, end=b, complete=comp,
                             dur=(b - a).total_seconds() / 60, gap=has_gap(a, b)))

def eff_kw(s):
    r = st.get(s["cid"])
    if not r or not r["kw"]:
        return None
    return min(r["kw"], 120) * 0.7 if r["dc"] else min(r["kw"], 11)

ENERGY = 52  # kWh: 10->80 % of a 75 kWh battery
def expected_max(s):
    e = eff_kw(s)
    return ENERGY / e * 60 if e else None

def pclass(s):
    r = st.get(s["cid"])
    if not r or not r["kw"]:
        return "?"
    k = r["kw"]
    if not r["dc"]:
        return "AC"
    return "DC<=60" if k <= 60 else ("DC 61-149" if k < 150 else "DC>=150")

good = [s for s in sessions if expected_max(s) and s["complete"] and not s["gap"] and 2 <= s["dur"] <= 24 * 60]
stale = [s for s in sessions if s["dur"] > 24 * 60]
out = {"window_utc": [t0.isoformat(), t1.isoformat()], "hours": round((t1 - t0).total_seconds() / 3600, 1),
       "gaps": [(a.isoformat(), b.isoformat()) for a, b in gaps],
       "sessions_all": len(sessions), "sessions_clean": len(good), "sessions_over_24h": len(stale)}

def pct(xs, q):
    xs = sorted(xs)
    return round(xs[min(len(xs) - 1, int(q * len(xs)))]) if xs else None

def summarize(ss):
    res = {}
    for c in ["AC", "DC<=60", "DC 61-149", "DC>=150"]:
        xs = [s for s in ss if pclass(s) == c]
        d = [s["dur"] for s in xs]
        over = [s for s in xs if s["dur"] > expected_max(s)]
        res[c] = dict(n=len(xs), p50=pct(d, .5), p75=pct(d, .75), p90=pct(d, .9),
                      expected_max=round(expected_max(xs[0])) if xs else None,
                      over_n=len(over), over_share=round(len(over) / len(xs), 3) if xs else None,
                      excess_h=round(sum(s["dur"] - expected_max(s) for s in over) / 60, 1),
                      occupied_h=round(sum(d) / 60, 1))
    return res

out["lt"] = summarize(good)
vil = [s for s in good if st.get(s["cid"], {}).get("city", "").strip().lower().startswith("vilni")]
out["vilnius"] = summarize(vil)

# daytime-only DC excess in Vilnius (07-22 local) – when someone could be waiting
def day_excess(s):
    em = expected_max(s)
    if s["dur"] <= em:
        return 0
    a = s["start"] + timedelta(minutes=em)
    m, t = 0, a
    while t < s["end"]:
        if 7 <= t.astimezone(LT).hour < 22:
            m += 1
        t += timedelta(minutes=1)
    return m
out["vilnius_daytime_excess_h"] = {c: round(sum(day_excess(s) for s in vil if pclass(s) == c) / 60, 1)
                                   for c in ["AC", "DC<=60", "DC 61-149", "DC>=150"]}

# top Vilnius stations by excess hours
byst = defaultdict(lambda: [0.0, 0, 0, None])
for s in vil:
    r = st[s["cid"]]
    k = (r["station_name"], r["address"], r["operator"].strip(), pclass(s))
    em = expected_max(s)
    byst[k][1] += 1
    if s["dur"] > em:
        byst[k][0] += (s["dur"] - em) / 60
        byst[k][2] += 1
top = sorted(byst.items(), key=lambda kv: -kv[1][0])[:15]
out["vilnius_top"] = [dict(station=k[0], address=k[1], operator=k[2], cls=k[3], sessions=v[1], over=v[2],
                           excess_h=round(v[0], 1)) for k, v in top]

# operators: share of overstays (DC, LT)
byop = defaultdict(lambda: [0, 0])
for s in good:
    if pclass(s).startswith("DC"):
        o = st[s["cid"]]["operator"].strip()
        byop[o][0] += 1
        byop[o][1] += s["dur"] > expected_max(s)
out["dc_by_operator"] = sorted([(o, n, round(k / n, 2)) for o, (n, k) in byop.items() if n >= 30], key=lambda x: -x[2])

# Vilnius occupancy by local hour for DC
cnt = Counter();
vdc = {c for c, r in st.items() if r["city"].strip().lower().startswith("vilni") and r["dc"]}
out["vilnius_dc_connectors"] = len(vdc)
out["vilnius_connectors"] = sum(1 for r in st.values() if r["city"].strip().lower().startswith("vilni"))
json.dump(out, sys.stdout, ensure_ascii=False, indent=1, default=str)

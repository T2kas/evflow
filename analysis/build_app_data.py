"""Build compact JSON for the driver app from collector/ data (stdlib only).

usage: python3 analysis/build_app_data.py [collector_dir] [out_dir]
writes:
  stations.json  – stations with chargers, current status, since, overstay flags, per-station stats
  model.json     – survival tables: P(session ends within 15/30 min | already lasted d) per class
"""
import csv, glob, json, os, sys
from collections import defaultdict
from datetime import datetime, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "collector")
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "app", "public", "data")
P = lambda *a: os.path.join(SRC, "data", *a)
ts = lambda s: datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)

ENERGY = 52            # kWh, 10->80 % of a 75 kWh battery
DC_RULE_MIN = 60       # DC sessions beyond 60 min treated as overstay
STALE_MIN = 90         # operator feed older than this -> status unreliable


def cls_of(kw, dc):
    if not dc:
        return "AC"
    return "DC50" if kw <= 60 else ("DC100" if kw < 150 else "DC150")


def expected_max(kw, dc):
    """Minutes after which a session is very likely finished charging."""
    if dc:
        return DC_RULE_MIN
    return round(ENERGY / min(kw or 11, 11) * 60)


# ---------- static
conn = {}
for r in csv.DictReader(open(P("stations.csv"), encoding="utf-8")):
    try:
        kw = max(float(x) for x in r["power_kw"].split("|") if x)
    except ValueError:
        kw = 0
    types = set(r["connector_type"].split("|"))
    dc = bool(types & {"IEC_62196_T2_COMBO", "CHADEMO"}) or kw > 43
    r.update(kw=kw, dc=dc, cls=cls_of(kw, dc))
    conn[r["connector_id"]] = r

# ---------- runs / gaps
runs = sorted(ts(r["timestamp_utc"]) for r in csv.DictReader(open(P("runs.csv"))))
gaps = [(a, b) for a, b in zip(runs, runs[1:]) if (b - a).total_seconds() > 600]
NOW = runs[-1]

# ---------- status history -> current status + since + sessions
ev = defaultdict(list)
for f in sorted(glob.glob(P("status", "*.csv"))):
    for r in csv.DictReader(open(f, encoding="utf-8")):
        ev[r["connector_id"]].append((ts(r["timestamp_utc"]), r["status"]))

since, sessions = {}, defaultdict(list)  # charger_id -> [(start, end, cid)]
for cid, es in ev.items():
    es.sort()
    cur_s, cur_t, first_occ = None, None, False
    for t, s in es:
        if s != cur_s:
            if cur_s == "Užimta" and not first_occ:
                sessions[conn.get(cid, {}).get("charger_id", cid)].append((cur_t, t, cid))
            first_occ = cur_s is None and s == "Užimta"   # left-censored
            cur_s, cur_t = s, t
    since[cid] = (cur_s, cur_t, first_occ if cur_s == "Užimta" else False)

def has_gap(a, b):
    return any(g0 < b and g1 > a for g0, g1 in gaps)

# merge plugs of one charger that flip together (one car shown on all plugs)
clean = []  # (charger_id, cid, start, end)
for ch, iv in sessions.items():
    iv.sort()
    used = set()
    for i, (a, b, cid) in enumerate(iv):
        if i in used:
            continue
        group = [cid]
        for j in range(i + 1, len(iv)):
            a2, b2, c2 = iv[j]
            if (a2 - a).total_seconds() > 240:
                break
            if j not in used and c2 != cid and abs((b2 - b).total_seconds()) < 240:
                used.add(j)
                group.append(c2)
        rep = max(group, key=lambda c: conn.get(c, {}).get("kw", 0))
        dur = (b - a).total_seconds() / 60
        if rep in conn and 2 <= dur <= 24 * 60 and not has_gap(a, b):
            clean.append((ch, rep, a, b, dur))

# ---------- survival model per class: P(end within h | lasted d)
STEP, MAXD = 5, 720
model = {"step": STEP, "max": MAXD, "classes": {}}
for c in ["AC", "DC50", "DC100", "DC150"]:
    durs = sorted(d for _, cid, _, _, d in clean if conn[cid]["cls"] == c)
    tab15, tab30, med = [], [], []
    for d in range(0, MAXD + 1, STEP):
        alive = [x for x in durs if x > d]
        n = len(alive)
        if n < 15:  # too few – keep last value
            tab15.append(tab15[-1] if tab15 else 0.5)
            tab30.append(tab30[-1] if tab30 else 0.7)
            med.append(med[-1] if med else 30)
            continue
        tab15.append(round(sum(x <= d + 15 for x in alive) / n, 3))
        tab30.append(round(sum(x <= d + 30 for x in alive) / n, 3))
        med.append(round(alive[n // 2] - d))  # median remaining minutes
    model["classes"][c] = dict(n=len(durs), p15=tab15, p30=tab30, remaining=med,
                               median=round(durs[len(durs) // 2]) if durs else None,
                               p90=round(durs[int(len(durs) * .9)]) if durs else None,
                               overstay_after=expected_max(150 if c != "AC" else 11, c != "AC"))

# ---------- per-station stats
fresh = {}
for f in sorted(glob.glob(P("freshness", "*.csv")))[-1:]:
    for r in csv.DictReader(open(f, encoding="utf-8")):
        fresh[r["station_id"]] = r["last_update_utc"]

st_stats = defaultdict(lambda: dict(n=0, over=0, excess=0.0, occ=0.0))
for ch, cid, a, b, d in clean:
    r = conn[cid]
    em = expected_max(r["kw"], r["dc"])
    s = st_stats[r["station_id"]]
    s["n"] += 1
    s["occ"] += d
    if d > em:
        s["over"] += 1
        s["excess"] += d - em

hours = (NOW - runs[0]).total_seconds() / 3600 - sum((b - a).total_seconds() for a, b in gaps) / 3600

stations = {}
for cid, r in conn.items():
    sid = r["station_id"]
    if not r["lat"] or not r["lon"]:
        continue
    s = stations.setdefault(sid, dict(
        id=sid, name=r["station_name"].strip(), op=r["operator"].strip().rstrip(","),
        addr=r["address"].strip(), city=r["city"].strip(),
        lat=round(float(r["lat"]), 6), lon=round(float(r["lon"]), 6),
        restr=r["restriction"], h24=r["open_24_7"] == "1", chargers={}))
    ch = s["chargers"].setdefault(r["charger_id"] or cid, dict(id=r["charger_id"] or cid, plugs=[]))
    stat, t, censored = since.get(cid, ("Nežinoma", None, False))
    plug = dict(id=cid, type=r["connector_type"], kw=r["kw"], dc=r["dc"], cls=r["cls"],
                tariff=r["tariff"], status=stat or "Nežinoma",
                since=t.strftime("%Y-%m-%dT%H:%M:%SZ") if t else None, censored=censored)
    ch["plugs"].append(plug)

for s in stations.values():
    s["chargers"] = list(s["chargers"].values())
    lu = fresh.get(s["id"])
    s["feedAgeMin"] = round((NOW - ts(lu)).total_seconds() / 60) if lu else None
    stt = st_stats.get(s["id"])
    if stt:
        s["stats"] = dict(sessions=stt["n"], overstays=stt["over"],
                          overstayShare=round(stt["over"] / stt["n"], 2),
                          lostHoursPerDay=round(stt["excess"] / 60 / hours * 24, 1),
                          occupancy=round(min(1, stt["occ"] / 60 / hours / max(1, len(s["chargers"]))), 2))

os.makedirs(OUT, exist_ok=True)
meta = dict(now=NOW.strftime("%Y-%m-%dT%H:%M:%SZ"), from_=runs[0].strftime("%Y-%m-%dT%H:%M:%SZ"),
            hours=round(hours, 1), sessions=len(clean), staleMin=STALE_MIN, energyKwh=ENERGY,
            dcRuleMin=DC_RULE_MIN)
json.dump(dict(meta=meta, stations=list(stations.values())),
          open(os.path.join(OUT, "stations.json"), "w", encoding="utf-8"),
          ensure_ascii=False, separators=(",", ":"))
json.dump(model, open(os.path.join(OUT, "model.json"), "w"), separators=(",", ":"))
print(f"{len(stations)} stations, {len(conn)} connectors, {len(clean)} sessions, now={meta['now']} -> {OUT}")
for c, m in model["classes"].items():
    print(f"  {c}: n={m['n']} median={m['median']} p90={m['p90']}")

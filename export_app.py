"""Export app-ready JSON from the evflow dataset.

    python export_app.py                # -> app_data/stations.json, app_data/city_stats.json
    python export_app.py --no-fetch     # don't call the live API for opening hours (use cache)

Only the standard library is used, so it can run inside the GitHub workflow too.

Model (kept deliberately simple so it can be explained to users and the jury):
  * session      = connector goes Užimta -> anything else.
  * overstay     = session lasts longer than the time a slow-charging car needs for
                   20->80 % (36 kWh) at that connector's power, plus 15 min grace
                   (see EXPECTED_MIN). Night AC sessions (start 20:00-07:00) are not
                   counted as overstay: overnight charging at home chargers is normal.
  * blocking     = overstay minutes while the whole station had no free connector,
                   i.e. somebody could have charged there but could not.
  * p_free_Xmin  = of past sessions in the same power class (own station when it has
                   enough history) that had already lasted as long as the current one,
                   the share that ended within the next X minutes.
"""
import argparse
import bisect
import csv
import glob
import json
import os
import statistics
import sys
import urllib.request
from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone

try:
    from zoneinfo import ZoneInfo
    LT = ZoneInfo("Europe/Vilnius")
except Exception:  # pragma: no cover - fallback without tz database
    LT = timezone(timedelta(hours=3))

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "data")
OUT = os.path.join(HERE, "app_data")
HOURS_CACHE = os.path.join(DATA, "opening_hours.json")
API = "https://ev.vialietuva.lt/api/locations/all"

TICK_MIN = 5            # grid resolution for occupancy / blocking
MIN_OWN_HISTORY = 15    # sessions needed before a station's own history is used
GRACE_MIN = 15
NEED_KWH = 36           # 20 -> 80 % of a 60 kWh battery


def parse_ts(s):
    return datetime.fromisoformat(s.replace("Z", "+00:00"))


def iso(dt):
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def max_kw(power):
    vals = []
    for x in power.split("|"):
        try:
            vals.append(float(x))
        except ValueError:
            pass
    return max(vals) if vals else 0.0


def power_class(kw):
    if kw <= 11:
        return "AC_11"
    if kw < 43:
        return "AC_22"
    if kw <= 60:
        return "DC_50"
    if kw < 150:
        return "DC_100"
    return "DC_150"


def expected_min(kw):
    """Minutes a slow-accepting car needs for NEED_KWH at this connector, plus grace.

    AC: most cars' onboard chargers take at most 11 kW (7.4 kW on <=11 kW points).
    DC: average power over 20->80 % is roughly 60 % of the charger's rating, and few
    cars sustain more than ~100 kW on average.
    """
    if kw < 43:
        eff = min(kw, 11.0) if kw > 11 else min(kw, 7.4)
    else:
        eff = min(kw * 0.6, 100.0)
    eff = max(eff, 2.0)
    return round(NEED_KWH / eff * 60 + GRACE_MIN)


def is_night(dt):
    h = dt.astimezone(LT).hour
    return h >= 20 or h < 7


# ---------------------------------------------------------------- loading

def load_stations():
    with open(os.path.join(DATA, "stations.csv"), newline="", encoding="utf-8") as f:
        return {r["connector_id"]: r for r in csv.DictReader(f)}


def load_events():
    rows = []
    for path in sorted(glob.glob(os.path.join(DATA, "status", "*.csv"))):
        with open(path, newline="", encoding="utf-8") as f:
            rows.extend(csv.DictReader(f))
    rows.sort(key=lambda r: r["timestamp_utc"])
    return [(parse_ts(r["timestamp_utc"]), r["connector_id"], r["status"]) for r in rows]


def load_payments():
    path = os.path.join(DATA, "payments.csv")
    if not os.path.exists(path):
        return {}
    with open(path, newline="", encoding="utf-8") as f:
        return {r.pop("station_id"): [k for k, v in r.items() if v == "1"] for r in csv.DictReader(f)}


def load_freshness():
    files = sorted(glob.glob(os.path.join(DATA, "freshness", "*.csv")))
    if not files:
        return {}
    with open(files[-1], newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    last_ts = max(r["timestamp_utc"] for r in rows)
    return {r["station_id"]: r["last_update_utc"] for r in rows if r["timestamp_utc"] == last_ts}


def fetch_opening_hours():
    """{station_id: [{weekday 1-7, begin, end}]} for stations that are not 24/7."""
    out = {}
    for page in range(20):
        req = urllib.request.Request(f"{API}?limit=500&offset={page * 500}", headers={
            "User-Agent": "Mozilla/5.0 (evflow research)",
            "Accept": "application/json",
            "X-Requested-With": "XMLHttpRequest",
            "Referer": "https://ev.vialietuva.lt/map",
        })
        with urllib.request.urlopen(req, timeout=30) as resp:
            rows = json.loads(resp.read().decode("utf-8"))["rows"]
        for loc in rows:
            ot = loc.get("ot")
            if isinstance(ot, dict) and not ot.get("twentyfourseven") and ot.get("regular_hours"):
                out[str(loc["id"])] = [
                    {"weekday": h["weekday"], "begin": h["period_begin"], "end": h["period_end"]}
                    for h in ot["regular_hours"]
                ]
        if len(rows) < 500:
            break
    return out


def opening_hours(fetch):
    if fetch:
        try:
            hours = fetch_opening_hours()
            with open(HOURS_CACHE, "w", encoding="utf-8") as f:
                json.dump(hours, f, ensure_ascii=False, indent=0)
            return hours
        except Exception as e:  # network is optional
            print(f"opening hours fetch failed, using cache: {e}", file=sys.stderr)
    if os.path.exists(HOURS_CACHE):
        with open(HOURS_CACHE, encoding="utf-8") as f:
            return json.load(f)
    return {}


def open_now(hours, now):
    if not hours:
        return None
    local = now.astimezone(LT)
    hm = local.strftime("%H:%M")
    return any(h["weekday"] == local.isoweekday() and h["begin"] <= hm < h["end"] for h in hours)


# ---------------------------------------------------------------- analysis

def sessions_and_current(events, stations):
    """Completed sessions per connector, plus current status and since-time."""
    cur, since = {}, {}
    sessions = []          # (connector_id, start, end)
    for t, c, s in events:
        prev = cur.get(c)
        if prev == s:
            continue
        if prev == "Užimta" and c in since and since[c][1]:
            sessions.append((c, since[c][0], t))
        # a session only counts if we saw it start (not the initial state)
        since[c] = (t, prev is not None)
        cur[c] = s
    return sessions, cur, since


def build_grid(events, stations, sessions, t0, t1):
    """Walk a TICK_MIN grid and measure occupancy, station-full time and blocking."""
    station_of = {c: r["station_id"] for c, r in stations.items()}
    conns_of = defaultdict(list)
    for c, sid in station_of.items():
        conns_of[sid].append(c)

    # overstay intervals per connector: [(overstay_start, end)]
    over = defaultdict(list)
    for c, start, end in sessions:
        if c not in stations:
            continue
        kw = max_kw(stations[c]["power_kw"])
        if kw < 43 and is_night(start):
            continue
        ostart = start + timedelta(minutes=expected_min(kw))
        if end > ostart:
            over[c].append((ostart, end))

    state = {}
    i, n = 0, len(events)
    tick = t0.replace(second=0, microsecond=0)
    step = timedelta(minutes=TICK_MIN)

    busy_hour = defaultdict(lambda: [0, 0])       # (sid, local hour) -> [busy ticks, usable ticks]
    city_hour = defaultdict(lambda: [0, 0])       # (city, hour) -> same, aggregated
    full_ticks = Counter()                        # sid -> ticks with no free connector
    usable_ticks = Counter()                      # sid -> ticks observed
    blocking_ticks = Counter()                    # connector -> overstay ticks while station full
    status_ticks = defaultdict(Counter)           # sid -> status -> ticks

    while tick <= t1:
        while i < n and events[i][0] <= tick:
            state[events[i][1]] = events[i][2]
            i += 1
        hour = tick.astimezone(LT).hour
        for sid, conns in conns_of.items():
            seen = [c for c in conns if c in state]
            if not seen:
                continue
            free = busy = 0
            for c in seen:
                s = state[c]
                status_ticks[sid][s] += 1
                if s == "Laisva":
                    free += 1
                elif s == "Užimta":
                    busy += 1
            usable = free + busy
            if not usable:
                continue
            usable_ticks[sid] += 1
            b = busy_hour[(sid, hour)]
            b[0] += busy / usable
            b[1] += 1
            city = stations[seen[0]]["city"] or "?"
            ch = city_hour[(city, hour)]
            ch[0] += busy / usable
            ch[1] += 1
            if free == 0:
                full_ticks[sid] += 1
                for c in seen:
                    for os_, oe in over.get(c, ()):
                        if os_ <= tick < oe:
                            blocking_ticks[c] += 1
                            break
        tick += step
    return over, busy_hour, city_hour, full_ticks, usable_ticks, blocking_ticks, status_ticks


class EndModel:
    """P(session ends within h minutes | it already lasted e minutes)."""

    def __init__(self, sessions, stations):
        self.by_class = defaultdict(list)
        self.by_station_class = defaultdict(list)
        for c, start, end in sessions:
            if c not in stations:
                continue
            d = (end - start).total_seconds() / 60
            cls = power_class(max_kw(stations[c]["power_kw"]))
            self.by_class[cls].append(d)
            self.by_station_class[(stations[c]["station_id"], cls)].append(d)
        for d in (self.by_class, self.by_station_class):
            for k in d:
                d[k].sort()

    def _pool(self, sid, cls, elapsed):
        own = self.by_station_class.get((sid, cls), [])
        own_left = len(own) - bisect.bisect_right(own, elapsed)
        if own_left >= MIN_OWN_HISTORY:
            return own, "stotelės istorija"
        return self.by_class.get(cls, []), "visų tokios galios jungčių istorija"

    def predict(self, sid, cls, elapsed):
        pool, basis = self._pool(sid, cls, elapsed)
        k = bisect.bisect_right(pool, elapsed)
        rest = pool[k:]
        if len(rest) < 5:
            return None
        out = {"basis": basis, "basis_n": len(rest)}
        for h in (15, 30, 60):
            ended = bisect.bisect_right(rest, elapsed + h)
            out[f"p_free_{h}min"] = round(ended / len(rest), 2)
        out["expected_remaining_min"] = round(statistics.median(rest) - elapsed)
        out["explain"] = (
            f"Iš {len(rest)} panašių įkrovimų ({basis}), kurie jau truko {round(elapsed)} min., "
            f"{round(out['p_free_30min'] * 100)} % baigėsi per 30 min."
        )
        return out


# ---------------------------------------------------------------- export

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--no-fetch", action="store_true", help="don't fetch opening hours from the live API")
    ap.add_argument("-o", "--out", default=OUT)
    args = ap.parse_args()

    stations = load_stations()
    events = load_events()
    with open(os.path.join(DATA, "last_status.json"), encoding="utf-8") as f:
        last = json.load(f)
    now = parse_ts(last["updated_utc"])
    payments = load_payments()
    fresh = load_freshness()
    hours = opening_hours(not args.no_fetch)

    sessions, cur, since = sessions_and_current(events, stations)
    t0, t1 = events[0][0], events[-1][0]
    over, busy_hour, city_hour, full_ticks, usable_ticks, blocking_ticks, status_ticks = build_grid(
        events, stations, sessions, t0, t1)
    model = EndModel(sessions, stations)
    observed_days = (t1 - t0).total_seconds() / 86400

    # per-station session aggregates
    sess_by_station = defaultdict(list)
    for c, start, end in sessions:
        if c in stations:
            sess_by_station[stations[c]["station_id"]].append((c, start, end))

    groups = defaultdict(list)
    for c, r in stations.items():
        groups[r["station_id"]].append(c)

    out_stations = []
    for sid, conns in groups.items():
        r0 = stations[conns[0]]
        conn_out = []
        for c in sorted(conns):
            r = stations[c]
            kw = max_kw(r["power_kw"])
            cls = power_class(kw)
            st = last["connectors"].get(c, {}).get("s", cur.get(c, "Nežinoma"))
            item = {
                "id": c,
                "charger_id": r["charger_id"],
                "type": r["connector_type"],
                "power_kw": kw,
                "class": cls,
                "tariff": last.get("tariffs", {}).get(c) or r["tariff"],
                "restriction": r["restriction"] or None,
                "status": st,
                "status_since": iso(since[c][0]) if c in since else None,
                "expected_charge_min": expected_min(kw),
            }
            if st == "Užimta" and c in since:
                elapsed = (now - since[c][0]).total_seconds() / 60
                item["busy_min"] = round(elapsed)
                item["busy_min_is_lower_bound"] = not since[c][1]  # busy since before collection began
                night_ac = kw < 43 and is_night(since[c][0])
                item["overstay"] = (not night_ac) and elapsed > item["expected_charge_min"]
                item["overstay_min"] = max(0, round(elapsed - item["expected_charge_min"])) if item["overstay"] else 0
                pred = model.predict(sid, cls, elapsed)
                if pred:
                    item["prediction"] = pred
            conn_out.append(item)

        statuses = Counter(x["status"] for x in conn_out)
        ss = sess_by_station.get(sid, [])
        durs = [(e - s).total_seconds() / 60 for _, s, e in ss]
        over_n = sum(1 for c, s, e in ss for os_, oe in over.get(c, ()) if oe == e)
        over_min = sum((oe - os_).total_seconds() / 60 for c in conns for os_, oe in over.get(c, ()))
        block_min = sum(blocking_ticks[c] for c in conns) * TICK_MIN
        tick_total = sum(status_ticks[sid].values()) or 1
        broken_share = (status_ticks[sid]["Neveikia"] + status_ticks[sid]["Nežinoma"]) / tick_total
        last_upd = fresh.get(sid)
        data_age = round((now - parse_ts(last_upd + ("" if last_upd.endswith("Z") else "Z"))).total_seconds() / 60) if last_upd else None
        never_used = not ss and not statuses["Užimta"]
        reliability = round(100 * (1 - broken_share))
        # many operators only push on change, so a quiet hour is normal; a silent day is not
        if data_age is not None and data_age > 1440:
            reliability = round(reliability * 0.7)
        if never_used:
            reliability = min(reliability, 60)

        # waiting estimate: 0 if a free connector, else soonest expected end among busy ones
        if statuses["Laisva"]:
            wait = 0
        else:
            rem = [x["prediction"]["expected_remaining_min"] for x in conn_out
                   if x["status"] == "Užimta" and "prediction" in x]
            wait = max(0, min(rem)) if rem else None

        h = hours.get(str(sid))
        out_stations.append({
            "id": sid,
            "name": r0["station_name"],
            "operator": r0["operator"].strip().rstrip(","),
            "address": r0["address"],
            "city": r0["city"],
            "lat": float(r0["lat"]) if r0["lat"] else None,
            "lon": float(r0["lon"]) if r0["lon"] else None,
            "open_24_7": {"1": True, "0": False}.get(r0["open_24_7"]),
            "opening_hours": h,
            "open_now": open_now(h, now) if h else (True if r0["open_24_7"] == "1" else None),
            "payments": payments.get(sid),
            "max_power_kw": max(x["power_kw"] for x in conn_out),
            "counts": {"total": len(conn_out), "free": statuses["Laisva"], "busy": statuses["Užimta"],
                       "broken": statuses["Neveikia"], "unknown": statuses["Nežinoma"],
                       "overstaying": sum(1 for x in conn_out if x.get("overstay"))},
            "expected_wait_min": wait,
            "reliability": {
                "score": reliability,
                "broken_share": round(broken_share, 3),
                "data_age_min": data_age,
                "never_used": never_used,
            },
            "history": {
                "sessions": len(ss),
                "sessions_per_day": round(len(ss) / observed_days, 1),
                "median_session_min": round(statistics.median(durs)) if durs else None,
                "overstay_sessions": over_n,
                "overstay_share": round(over_n / len(ss), 2) if ss else None,
                "overstay_hours": round(over_min / 60, 1),
                "blocking_hours": round(block_min / 60, 1),
                "full_share": round(full_ticks[sid] / usable_ticks[sid], 3) if usable_ticks[sid] else None,
                "busy_by_hour": [round(busy_hour[(sid, hr)][0] / busy_hour[(sid, hr)][1], 2)
                                 if busy_hour[(sid, hr)][1] else None for hr in range(24)],
            },
            "connectors": conn_out,
        })

    os.makedirs(args.out, exist_ok=True)
    meta = {"generated_utc": iso(datetime.now(timezone.utc)), "data_until_utc": iso(now),
            "history_from_utc": iso(t0), "history_days": round(observed_days, 2)}
    with open(os.path.join(args.out, "stations.json"), "w", encoding="utf-8") as f:
        json.dump({"meta": meta, "stations": out_stations}, f, ensure_ascii=False, separators=(",", ":"))

    write_city_stats(args.out, meta, out_stations, city_hour, stations, sessions, over)
    n_pred = sum(1 for s in out_stations for c in s["connectors"] if "prediction" in c)
    print(f"{len(out_stations)} stations, {len(sessions)} sessions, {n_pred} live predictions -> {args.out}/")


def write_city_stats(out, meta, out_stations, city_hour, stations, sessions, over):
    by_op = defaultdict(lambda: Counter())
    for s in out_stations:
        o = by_op[s["operator"]]
        h = s["history"]
        o["stations"] += 1
        o["connectors"] += s["counts"]["total"]
        o["broken_now"] += s["counts"]["broken"]
        o["sessions"] += h["sessions"]
        o["overstay_sessions"] += h["overstay_sessions"]
        o["overstay_hours"] += h["overstay_hours"]
        o["blocking_hours"] += h["blocking_hours"]
        o["stale_stations"] += 1 if (s["reliability"]["data_age_min"] or 0) > 1440 else 0
    operators = []
    for name, o in sorted(by_op.items(), key=lambda kv: -kv[1]["sessions"]):
        operators.append({"operator": name, **{k: round(v, 1) for k, v in o.items()},
                          "overstay_share": round(o["overstay_sessions"] / o["sessions"], 2) if o["sessions"] else None})

    def top(key, n=25, city=None):
        pool = [s for s in out_stations if city is None or s["city"] == city]
        pool.sort(key=lambda s: -(s["history"][key] or 0))
        return [{"id": s["id"], "name": s["name"], "operator": s["operator"], "city": s["city"],
                 "lat": s["lat"], "lon": s["lon"], key: s["history"][key],
                 "sessions": s["history"]["sessions"]} for s in pool[:n] if s["history"][key]]

    durs_by_class = defaultdict(list)
    for c, a, b in sessions:
        if c in stations:
            durs_by_class[power_class(max_kw(stations[c]["power_kw"]))].append((b - a).total_seconds() / 60)

    def q(a, p):
        return round(sorted(a)[int(p * (len(a) - 1))]) if a else None

    classes = {k: {"sessions": len(v), "p50_min": q(v, .5), "p90_min": q(v, .9),
                   "expected_charge_min": expected_min({"AC_11": 11, "AC_22": 22, "DC_50": 50,
                                                        "DC_100": 100, "DC_150": 150}[k])}
               for k, v in sorted(durs_by_class.items())}

    cities = sorted({s["city"] for s in out_stations if s["city"]},
                    key=lambda c: -sum(1 for s in out_stations if s["city"] == c))[:10]
    vil = [s for s in out_stations if s["city"] == "Vilnius"]
    tot = lambda pool, k: round(sum(s["history"][k] for s in pool), 1)
    stats = {
        "meta": meta,
        "totals": {
            "stations": len(out_stations),
            "connectors": sum(s["counts"]["total"] for s in out_stations),
            "sessions": len(sessions),
            "overstay_sessions": sum(s["history"]["overstay_sessions"] for s in out_stations),
            "overstay_hours": tot(out_stations, "overstay_hours"),
            "blocking_hours": tot(out_stations, "blocking_hours"),
            "broken_now": sum(s["counts"]["broken"] for s in out_stations),
            "stale_stations": sum(1 for s in out_stations if (s["reliability"]["data_age_min"] or 0) > 1440),
        },
        "vilnius": {
            "stations": len(vil),
            "sessions": sum(s["history"]["sessions"] for s in vil),
            "overstay_sessions": sum(s["history"]["overstay_sessions"] for s in vil),
            "overstay_hours": tot(vil, "overstay_hours"),
            "blocking_hours": tot(vil, "blocking_hours"),
            "top_blocking": top("blocking_hours", city="Vilnius"),
            "top_overstay": top("overstay_hours", city="Vilnius"),
        },
        "busy_by_hour": {c: [round(city_hour[(c, h)][0] / city_hour[(c, h)][1], 3)
                             if city_hour[(c, h)][1] else None for h in range(24)] for c in cities},
        "power_classes": classes,
        "operators": operators,
        "top_blocking": top("blocking_hours"),
    }
    with open(os.path.join(out, "city_stats.json"), "w", encoding="utf-8") as f:
        json.dump(stats, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()

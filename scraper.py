#!/usr/bin/env python3
"""EV charging connector status scraper for ev.vialietuva.lt.

One run = one snapshot. Standard library only.

Outputs (under data/):
  stations.csv          static connector/station metadata (rewritten only on change)
  status/YYYY-MM-DD.csv timestamp_utc,connector_id,status  (changes + 30 min heartbeat)
  prices/YYYY-MM-DD.csv timestamp_utc,connector_id,tariff  (on change; some tariffs are hourly/dynamic)
  freshness/YYYY-MM-DD.csv timestamp_utc,station_id,last_update_utc,age_min  (every 30 min)
  last_status.json      last known status/tariff + heartbeats
  runs.csv              one log row per run
"""
import csv
import gzip
import json
import os
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

API = "https://ev.vialietuva.lt/api/locations/all"
PAGE_SIZE = 500
MAX_PAGES = 40
TIMEOUT = 15
ATTEMPTS = 3
HEARTBEAT = timedelta(minutes=30)
SOURCE_TZ = ZoneInfo("Europe/Vilnius")  # API "lu" timestamps are local time
# A snapshot with fewer connectors than this share of the previous one is treated as broken.
MIN_SHARE_OF_PREVIOUS = 0.5
MIN_CONNECTORS = 100
USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/128.0 Safari/537.36 evflow-research/1.0"
)

STATUS_MAP = {
    "AVAILABLE": "Laisva",
    "CHARGING": "Užimta",
    "OUTOFORDER": "Neveikia",
    "INOPERATIVE": "Neveikia",
    "UNKNOWN": "Nežinoma",
}

DATA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")
STATIONS_CSV = os.path.join(DATA, "stations.csv")
LAST_JSON = os.path.join(DATA, "last_status.json")
RUNS_CSV = os.path.join(DATA, "runs.csv")
STATUS_DIR = os.path.join(DATA, "status")
PRICES_DIR = os.path.join(DATA, "prices")
FRESH_DIR = os.path.join(DATA, "freshness")

STATION_FIELDS = [
    "connector_id", "evse_id", "station_id", "station_name", "operator",
    "address", "city", "lat", "lon", "connector_type", "power_kw", "tariff",
    "charger_id", "owner", "restriction", "open_24_7", "tariff_note",
]
RUN_FIELDS = [
    "timestamp_utc", "connectors", "changes", "heartbeats", "new_connectors",
    "duration_s", "error",
]


def iso(dt):
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_iso(s):
    return datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)


def fetch_json(url):
    req = urllib.request.Request(url, headers={
        "User-Agent": USER_AGENT,
        "Accept": "application/json",
        "Accept-Encoding": "gzip",
        "X-Requested-With": "XMLHttpRequest",
        "Referer": "https://ev.vialietuva.lt/map",
    })
    last_err = None
    for attempt in range(ATTEMPTS):
        try:
            with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
                body = resp.read()
                if resp.headers.get("Content-Encoding") == "gzip":
                    body = gzip.decompress(body)
            data = json.loads(body.decode("utf-8"))
            if not data.get("success") or not isinstance(data.get("rows"), list):
                raise ValueError("unexpected response shape")
            return data["rows"]
        except (urllib.error.URLError, OSError, ValueError) as e:
            last_err = e
            if attempt < ATTEMPTS - 1:
                time.sleep(2 ** attempt)  # 1s, 2s
    raise RuntimeError(f"fetch failed after {ATTEMPTS} attempts: {url}: {last_err}")


def fetch_all_locations():
    rows = []
    for page in range(MAX_PAGES):
        batch = fetch_json(f"{API}?limit={PAGE_SIZE}&offset={page * PAGE_SIZE}")
        rows.extend(batch)
        if len(batch) < PAGE_SIZE:
            return rows
    raise RuntimeError(f"pagination did not end after {MAX_PAGES} pages")


def join(values):
    return "|".join("" if v is None else str(v) for v in values)


def parse_connectors(locations):
    """Return {connector_id: (static_row_dict, raw_status)}."""
    evses = [(loc, e) for loc in locations for e in (loc.get("e") or [])]
    seen = {}
    for _, e in evses:
        seen[e.get("eid")] = seen.get(e.get("eid"), 0) + 1

    out = {}
    for loc, e in evses:
        eid = e.get("eid") or f"EVSE{e.get('id')}"
        # Some EVSE ids are reused for distinct EVSEs at the same station: disambiguate.
        cid = f"{eid}#{e.get('id')}" if seen.get(e.get("eid"), 0) > 1 else eid
        plugs = e.get("c") or []
        point = loc.get("l") or {}
        op = loc.get("o") or {}
        ot = loc.get("ot") or {}
        # multi-plug chargers share the eid prefix (e.g. IGN-E-11-0-A/B/C): one physical unit
        charger = eid.rsplit("-", 1)[0] if eid.count("-") >= 2 else f"S{loc.get('id')}"
        static = {
            "connector_id": cid,
            "evse_id": e.get("id"),
            "station_id": loc.get("id"),
            "station_name": loc.get("n") or "",
            "operator": op.get("name") or "",
            "address": loc.get("adr") or "",
            "city": loc.get("c") or "",
            "lat": point.get("x", ""),
            "lon": point.get("y", ""),
            "connector_type": join(p.get("sdr") for p in plugs),
            "power_kw": join(p.get("kw") for p in plugs),
            "tariff": join(p.get("price") or p.get("text") for p in plugs),
            "charger_id": charger,
            "owner": (loc.get("own") or {}).get("name") or "",
            "restriction": join(e.get("rest") or []),
            "open_24_7": {True: "1", False: "0"}.get(ot.get("twentyfourseven") if isinstance(ot, dict) else None, ""),
            "tariff_note": join(p.get("text") for p in plugs if p.get("text")),
        }
        static = {k: ("" if v is None else str(v)) for k, v in static.items()}
        out[cid] = (static, e.get("s") or "UNKNOWN")
    return out


def freshness(locations, now):
    """[(station_id, last_update_utc, age_min)] from the location "lu" field."""
    out = []
    for loc in locations:
        try:
            lu = datetime.fromisoformat(loc["lu"]).replace(tzinfo=SOURCE_TZ).astimezone(timezone.utc)
            out.append([loc["id"], iso(lu), max(0, int((now - lu).total_seconds() // 60))])
        except (KeyError, TypeError, ValueError):
            out.append([loc.get("id"), "", ""])
    return out


def load_last():
    try:
        with open(LAST_JSON, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return {"connectors": {}}


def update_stations(current):
    """Merge current metadata into stations.csv (connectors that disappear are kept)."""
    existing = {}
    if os.path.exists(STATIONS_CSV):
        with open(STATIONS_CSV, encoding="utf-8", newline="") as f:
            existing = {r["connector_id"]: r for r in csv.DictReader(f)}
    merged = dict(existing)
    for cid, (static, _) in current.items():
        merged[cid] = static
    if merged == existing:
        return False
    tmp = STATIONS_CSV + ".tmp"
    with open(tmp, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=STATION_FIELDS, lineterminator="\n")
        w.writeheader()
        for cid in sorted(merged):
            w.writerow(merged[cid])
    os.replace(tmp, STATIONS_CSV)
    return True


def append_csv(path, fields, rows):
    new = not os.path.exists(path)
    with open(path, "a", encoding="utf-8", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        if new:
            w.writerow(fields)
        w.writerows(rows)


def log_run(ts, connectors=0, changes=0, heartbeats=0, new=0, started=0.0, error=""):
    append_csv(RUNS_CSV, RUN_FIELDS, [[
        iso(ts), connectors, changes, heartbeats, new,
        f"{time.monotonic() - started:.2f}", error,
    ]])


def main():
    started = time.monotonic()
    now = datetime.now(timezone.utc).replace(microsecond=0)
    os.makedirs(STATUS_DIR, exist_ok=True)
    last = load_last()
    prev = last.get("connectors", {})

    try:
        locations = fetch_all_locations()
        current = parse_connectors(locations)
        floor = max(MIN_CONNECTORS, int(len(prev) * MIN_SHARE_OF_PREVIOUS))
        if len(current) < floor:
            raise RuntimeError(f"suspicious snapshot: {len(current)} connectors (expected >= {floor})")
    except Exception as e:  # never write statuses from a bad snapshot
        msg = f"{type(e).__name__}: {e}".replace("\n", " ")[:500]
        log_run(now, started=started, error=msg)
        print(f"ERROR {msg}", file=sys.stderr)
        return 1

    ts = iso(now)
    status_rows, changes, heartbeats, new = [], 0, 0, 0
    for cid in sorted(current):
        raw = current[cid][1]
        status = STATUS_MAP.get(raw, "Nežinoma")
        p = prev.get(cid)
        if p is None:
            new += 1
            write = True
        elif p["s"] != status:
            changes += 1
            write = True
        else:
            write = now - parse_iso(p["hb"]) >= HEARTBEAT
            heartbeats += write
        if write:
            status_rows.append([ts, cid, status])
            prev[cid] = {"s": status, "raw": raw, "hb": ts}
        else:
            p["raw"] = raw

    # tariff history (dynamic tariffs change hourly)
    tariffs = last.get("tariffs", {})
    price_rows = []
    for cid in sorted(current):
        tariff = current[cid][0]["tariff"]
        if tariffs.get(cid) != tariff:
            price_rows.append([ts, cid, tariff])
            tariffs[cid] = tariff
    if price_rows:
        os.makedirs(PRICES_DIR, exist_ok=True)
        append_csv(os.path.join(PRICES_DIR, f"{now:%Y-%m-%d}.csv"),
                   ["timestamp_utc", "connector_id", "tariff"], price_rows)

    # operator feed freshness snapshot every 30 min
    fresh_hb = last.get("freshness_hb")
    if not fresh_hb or now - parse_iso(fresh_hb) >= HEARTBEAT:
        os.makedirs(FRESH_DIR, exist_ok=True)
        append_csv(os.path.join(FRESH_DIR, f"{now:%Y-%m-%d}.csv"),
                   ["timestamp_utc", "station_id", "last_update_utc", "age_min"],
                   [[ts, *r] for r in freshness(locations, now)])
        fresh_hb = ts

    update_stations(current)
    append_csv(os.path.join(STATUS_DIR, f"{now:%Y-%m-%d}.csv"),
               ["timestamp_utc", "connector_id", "status"], status_rows)
    last = {"updated_utc": ts, "connectors": prev, "tariffs": tariffs, "freshness_hb": fresh_hb}
    tmp = LAST_JSON + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(last, f, ensure_ascii=False, separators=(",", ":"), sort_keys=True)
    os.replace(tmp, LAST_JSON)

    log_run(now, len(current), changes, heartbeats, new, started)
    print(f"{ts} connectors={len(current)} changes={changes} heartbeats={heartbeats} "
          f"new={new} rows={len(status_rows)} {time.monotonic() - started:.2f}s")
    return 0


if __name__ == "__main__":
    sys.exit(main())

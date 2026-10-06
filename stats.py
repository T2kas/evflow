#!/usr/bin/env python3
"""Local summary of collected data. Usage: python stats.py"""
import csv
import glob
import os
import sys
from collections import Counter
from datetime import datetime, timedelta, timezone

DATA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")


def parse(s):
    return datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)


def read_csv(path):
    if not os.path.exists(path):
        return []
    with open(path, encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    stations = {r["connector_id"]: r for r in read_csv(os.path.join(DATA, "stations.csv"))}
    runs = read_csv(os.path.join(DATA, "runs.csv"))
    rows = []
    for path in sorted(glob.glob(os.path.join(DATA, "status", "*.csv"))):
        rows.extend(read_csv(path))
    rows.sort(key=lambda r: r["timestamp_utc"])

    # A change = status differs from the previous record of the same connector.
    last, changes = {}, []
    for r in rows:
        cid = r["connector_id"]
        if cid in last and last[cid] != r["status"]:
            changes.append(r)
        last[cid] = r["status"]

    now = datetime.now(timezone.utc)
    hour_ago = now - timedelta(hours=1)
    ok_runs = [r for r in runs if not r["error"]]
    err_runs = [r for r in runs if r["error"]]
    times = [parse(r["timestamp_utc"]) for r in runs]
    gaps = [(b - a).total_seconds() for a, b in zip(times, times[1:])]

    print("=== EV flow duomenų statistika ===")
    print(f"Sekama jungčių:            {len(stations)}  (paskutiniame snapshot: "
          f"{ok_runs[-1]['connectors'] if ok_runs else 0})")
    print(f"Paleidimų iš viso:         {len(runs)}  (sėkmingų {len(ok_runs)})")
    if gaps:
        print(f"Vidutinis tarpas:          {sum(gaps) / len(gaps) / 60:.2f} min "
              f"(min {min(gaps) / 60:.1f}, max {max(gaps) / 60:.1f})")
    else:
        print("Vidutinis tarpas:          n/a")
    if ok_runs:
        durs = [float(r["duration_s"]) for r in ok_runs]
        print(f"Scraper trukmė (vid.):     {sum(durs) / len(durs):.2f} s")
    print(f"Paleidimai su klaidomis:   {len(err_runs)}")
    for r in err_runs[-5:]:
        print(f"   {r['timestamp_utc']}  {r['error'][:120]}")
    print(f"Būsenos pokyčių iš viso:   {len(changes)}")
    print(f"Pokyčių per paskutinę val.: "
          f"{sum(1 for r in changes if parse(r['timestamp_utc']) >= hour_ago)}")
    print(f"Įrašų status/*.csv:        {len(rows)}")
    if rows:
        print(f"Pirmas įrašas:             {rows[0]['timestamp_utc']}")
        print(f"Paskutinis įrašas:         {rows[-1]['timestamp_utc']}")

    print("\nDabartinės būsenos:")
    for status, n in Counter(last.values()).most_common():
        print(f"   {status:10s} {n}")

    vilnius = Counter(r["connector_id"] for r in changes
                      if stations.get(r["connector_id"], {}).get("city") == "Vilnius")
    print("\nTop 10 Vilniaus jungčių pagal pokyčių skaičių:")
    if not vilnius:
        print("   (pokyčių dar nėra)")
    for i, (cid, n) in enumerate(vilnius.most_common(10), 1):
        s = stations[cid]
        print(f"  {i:2d}. {cid:24s} {n:4d}  {s['connector_type']:20s} {s['power_kw']:>6s} kW  "
              f"{s['station_name'][:35]} ({s['address']})")


if __name__ == "__main__":
    main()

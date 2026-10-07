#!/usr/bin/env python3
"""One-off: payment methods per station -> data/payments.csv (static, run manually).

The site's filter endpoint returns location ids accepting a given payment method;
it needs the session cookie + CSRF token from the map page.
"""
import csv
import http.cookiejar
import json
import os
import re
import urllib.parse
import urllib.request

BASE = "https://ev.vialietuva.lt"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) evflow-research/1.0"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "payments.csv")


def main():
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
    page = opener.open(urllib.request.Request(BASE + "/map", headers={"User-Agent": UA}), timeout=15).read().decode()
    token = re.search(r'name="csrf-token" content="([^"]+)"', page).group(1)
    headers = {"User-Agent": UA, "Referer": BASE + "/map", "X-CSRF-Token": token,
               "X-Requested-With": "XMLHttpRequest"}

    def get(path):
        return json.loads(opener.open(urllib.request.Request(BASE + path, headers=headers), timeout=15).read())

    methods = get("/api/filters/tariffs")["tariffs"]  # [{"id": ..., "t": "Bankine kortele"}, ...]
    accepted = {}
    for m in methods:
        body = urllib.parse.urlencode({"payment": json.dumps([m["id"]]), "csrf_token": token}).encode()
        resp = json.loads(opener.open(urllib.request.Request(BASE + "/api/filters/apply_payments", data=body,
                                                             headers=headers), timeout=15).read())
        if not resp.get("success", True) and "location_ids" not in resp:
            raise RuntimeError(f"{m}: {resp}")
        accepted[m["t"]] = set(resp["location_ids"])
        print(f"{m['t']}: {len(accepted[m['t']])} stations")

    stations = sorted(set().union(*accepted.values()))
    with open(OUT, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(["station_id", *accepted])
        for sid in stations:
            w.writerow([sid, *(int(sid in ids) for ids in accepted.values())])
    print(f"{OUT}: {len(stations)} stations")


if __name__ == "__main__":
    main()

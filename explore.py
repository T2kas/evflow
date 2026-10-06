#!/usr/bin/env python3
"""Build report.html from data/ (status changes + heartbeats).

Usage: python explore.py [data_dir] [-o report.html]
Requires: pandas, matplotlib
"""
import argparse
import base64
import glob
import html
import io
import os
from datetime import datetime, timezone

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402

GAP_MIN = 10            # gap between runs that counts as "no data"
STALE_MIN = 35          # no record for this long (heartbeat is 30 min) -> connector gone
STUCK_MIN_COVERAGE = 0.5
TZ = "Europe/Vilnius"
STATUSES = ["Laisva", "Užimta", "Neveikia", "Nežinoma"]
BUSY = STATUSES.index("Užimta")
CLASSES = ["AC ≤22 kW", "DC 50–100 kW", "DC >100 kW", "Kita (23–49 kW)"]
MAIN_CLASSES = CLASSES[:3]


# ---------- loading ----------

def load(data_dir):
    runs = pd.read_csv(os.path.join(data_dir, "runs.csv"), dtype={"error": str}, keep_default_na=False)
    runs["t"] = pd.to_datetime(runs["timestamp_utc"], utc=True)
    st = pd.read_csv(os.path.join(data_dir, "stations.csv"), dtype=str, keep_default_na=False)
    st["kw"] = st["power_kw"].map(lambda s: max((float(x) for x in s.split("|") if x), default=np.nan))
    st["power_class"] = st["kw"].map(power_class)
    st["is_vilnius"] = st["city"].eq("Vilnius")
    files = sorted(glob.glob(os.path.join(data_dir, "status", "*.csv")))
    status = pd.concat([pd.read_csv(f, dtype=str) for f in files], ignore_index=True)
    status["t"] = pd.to_datetime(status["timestamp_utc"], utc=True)
    status["code"] = pd.Categorical(status["status"], categories=STATUSES).codes.astype(float)
    status.loc[status["code"] < 0, "code"] = STATUSES.index("Nežinoma")
    return runs, st, status


def power_class(kw):
    if pd.isna(kw):
        return "Kita (23–49 kW)"
    if kw <= 22:
        return CLASSES[0]
    if 50 <= kw <= 100:
        return CLASSES[1]
    if kw > 100:
        return CLASSES[2]
    return CLASSES[3]


def build_matrix(runs, status):
    """State of every connector at every successful run (NaN = unknown/not tracked)."""
    t = pd.DatetimeIndex(sorted(runs.loc[runs["error"] == "", "t"].unique()))
    codes = status.pivot_table(index="t", columns="connector_id", values="code", aggfunc="last")
    codes = codes.reindex(codes.index.union(t)).sort_index()
    stamp = pd.DataFrame(np.where(codes.notna(), codes.index.values.astype("int64")[:, None], np.nan),
                         index=codes.index, columns=codes.columns)
    codes, stamp = codes.ffill().reindex(t), stamp.ffill().reindex(t)
    age_min = (t.values.astype("int64")[:, None] - stamp.values) / 60e9
    m = codes.values.copy()
    m[age_min > STALE_MIN] = np.nan
    # weight of each run = minutes until next run; 0 across gaps (unknown time)
    dt = np.diff(t.values).astype("timedelta64[s]").astype(float) / 60
    typical = float(np.median(dt[dt <= GAP_MIN])) if (dt <= GAP_MIN).any() else 3.0
    w = np.append(np.where(dt > GAP_MIN, 0.0, dt), typical)
    gap_after = np.append(dt > GAP_MIN, False)
    return t, list(codes.columns), m, w, gap_after, dt


# ---------- analysis ----------

def sessions(t, cols, m, gap_after):
    """Užimta start -> first run with another status. Incomplete if the edge is not observed."""
    busy = m == BUSY
    valid = ~np.isnan(m)
    gap_cum = np.concatenate([[0], np.cumsum(gap_after)])  # gaps strictly before run i
    out = []
    n = len(t)
    for j, cid in enumerate(cols):
        b = busy[:, j]
        if not b.any():
            continue
        idx = np.flatnonzero(np.diff(np.concatenate([[0], b.astype(np.int8), [0]])))
        for s, e in zip(idx[::2], idx[1::2]):  # busy on runs s..e-1, run e is not busy (or end)
            started_seen = s > 0 and valid[s - 1, j] and not gap_after[s - 1]
            ended_seen = e < n and valid[e, j] and not gap_after[e - 1]
            no_gap_inside = gap_cum[e - 1] - gap_cum[s] == 0
            complete = started_seen and ended_seen and no_gap_inside
            end_t = t[e] if e < n else t[-1]
            out.append((cid, t[s], end_t, (end_t - t[s]).total_seconds() / 60, complete))
    return pd.DataFrame(out, columns=["connector_id", "start", "end", "minutes", "complete"])


def time_share(m, w, cols):
    """Per connector: observed minutes and minutes in each status."""
    valid = ~np.isnan(m)
    res = pd.DataFrame(index=cols)
    res["observed_min"] = (valid * w[:, None]).sum(0)
    for k, name in enumerate(STATUSES):
        res[name] = ((m == k) * w[:, None]).sum(0)
    return res


# ---------- rendering helpers ----------

def fig_html(fig):
    buf = io.BytesIO()
    fig.savefig(buf, format="png", dpi=110, bbox_inches="tight")
    plt.close(fig)
    return f'<img src="data:image/png;base64,{base64.b64encode(buf.getvalue()).decode()}">'


def table(df, **kw):
    if df is None or len(df) == 0:
        return '<p class="muted">Nėra duomenų.</p>'
    return df.to_html(index=False, border=0, classes="t", na_rep="–", escape=True, **kw)


def fmt_dt(ts):
    return pd.Timestamp(ts).tz_convert(TZ).strftime("%Y-%m-%d %H:%M")


def fmt_min(x):
    if pd.isna(x):
        return "–"
    h, mm = divmod(int(round(x)), 60)
    return f"{h} h {mm:02d} min" if h else f"{mm} min"


def kv(rows):
    return "<table class='kv'>" + "".join(
        f"<tr><th>{html.escape(k)}</th><td>{html.escape(str(v))}</td></tr>" for k, v in rows) + "</table>"


# ---------- report ----------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("data_dir", nargs="?", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "data"))
    ap.add_argument("-o", "--out", default="report.html")
    a = ap.parse_args()

    runs, st, status = load(a.data_dir)
    t, cols, m, w, gap_after, dt = build_matrix(runs, status)
    meta = st.set_index("connector_id").reindex(cols)
    vil = meta["is_vilnius"].fillna(False).values
    window_min = w.sum()
    S = []  # html sections

    # 1. Health
    err = runs[runs["error"] != ""]
    gaps = pd.DataFrame({"Nuo": [fmt_dt(x) for x in t[:-1][dt > GAP_MIN]],
                         "Iki": [fmt_dt(x) for x in t[1:][dt > GAP_MIN]],
                         "Trukmė": [fmt_min(x) for x in dt[dt > GAP_MIN]]})
    now = m[-1]
    cur = pd.DataFrame({
        "Būsena": STATUSES,
        "Visa Lietuva": [int((now == k).sum()) for k in range(4)],
        "Vilnius": [int(((now == k) & vil).sum()) for k in range(4)],
    })
    tot = cur[["Visa Lietuva", "Vilnius"]].sum()
    cur["Visa Lietuva %"] = (cur["Visa Lietuva"] / tot["Visa Lietuva"] * 100).round(1)
    cur["Vilnius %"] = (cur["Vilnius"] / max(tot["Vilnius"], 1) * 100).round(1)
    S.append(("1. Duomenų sveikata", kv([
        ("Laikotarpis", f"{fmt_dt(t[0])} – {fmt_dt(t[-1])} (Vilniaus laiku)"),
        ("Paleidimų iš viso / sėkmingų", f"{len(runs)} / {len(t)}"),
        ("Vidutinis tarpas tarp paleidimų", fmt_min(dt.mean()) if len(dt) else "–"),
        ("Mediana / maksimalus tarpas", f"{fmt_min(np.median(dt)) if len(dt) else '–'} / {fmt_min(dt.max()) if len(dt) else '–'}"),
        ("Padengtas laikas (be spragų >10 min)", f"{fmt_min(window_min)}"),
        ("Paleidimai su klaidomis", len(err)),
        ("Sekama jungčių (iš viso / Vilniuje)", f"{len(cols)} / {int(vil.sum())}"),
        ("Stotelių (iš viso / Vilniuje)", f"{st['station_id'].nunique()} / {st.loc[st['is_vilnius'], 'station_id'].nunique()}"),
    ]) + "<h3>Paleidimai su klaidomis</h3>" + table(err[["timestamp_utc", "error"]].tail(20))
        + f"<h3>Spragos (tarpas &gt; {GAP_MIN} min)</h3>" + table(gaps)
        + f"<h3>Būsenos dabar ({fmt_dt(t[-1])})</h3>" + table(cur)))

    # 2. Sessions
    ses = sessions(t, cols, m, gap_after)
    ses = ses.join(meta[["station_name", "address", "city", "kw", "power_class", "is_vilnius", "operator"]],
                   on="connector_id")
    comp = ses[ses["complete"]]

    def agg(df):
        c = df[df["complete"]]
        return pd.Series({"Sesijų (visos)": len(df), "Pilnų": len(c), "Nepilnų": len(df) - len(c),
                          "Mediana": fmt_min(c["minutes"].median()) if len(c) else "–",
                          "Vidurkis": fmt_min(c["minutes"].mean()) if len(c) else "–"})
    rows = []
    for region, sub in [("Vilnius", ses[ses["is_vilnius"] == True]), ("Visa Lietuva", ses)]:  # noqa: E712
        for cls in CLASSES + ["Visos"]:
            part = sub if cls == "Visos" else sub[sub["power_class"] == cls]
            rows.append({"Regionas": region, "Galios klasė": cls, **agg(part)})
    fig, axes = plt.subplots(1, 3, figsize=(14, 3.6))
    for ax, cls in zip(axes, MAIN_CLASSES):
        x = comp.loc[comp["power_class"] == cls, "minutes"]
        if len(x):
            # bins are multiples of 3 min (the sampling step) to avoid empty aliasing bins
            step = 3 * max(1, int(np.ceil(float(x.quantile(0.98)) / 30 / 3)))
            hi = step * 30
            ax.hist(x.clip(upper=hi - 0.1), bins=np.arange(0, hi + step, step) - step / 2,
                    color="#2b7bba", edgecolor="white")
            ax.set_title(f"{cls}  (n={len(x)}, mediana {x.median():.0f} min)", fontsize=10)
        else:
            ax.text(0.5, 0.5, "nėra pilnų sesijų", ha="center", va="center", transform=ax.transAxes)
            ax.set_title(cls, fontsize=10)
        ax.set_xlabel("trukmė, min (paskutinis stulpelis = ≥98 percentilis)")
    axes[0].set_ylabel("sesijų")
    S.append(("2. Sesijos", "<p class='muted'>Sesija = jungtis tampa <b>Užimta</b> → pirmas paleidimas su kita būsena. "
              "Nepilnos (prasidėjo prieš rinkimą, dar vyksta arba kerta duomenų spragą) į trukmes neįtrauktos. "
              "Tikslumas ±1 paleidimo intervalas (~3 min).</p>"
              + table(pd.DataFrame(rows)) + fig_html(fig)))

    # 3. Vilnius
    share = time_share(m, w, cols).join(meta[["station_id", "station_name", "address", "is_vilnius", "operator",
                                               "city", "power_class"]])
    with np.errstate(all="ignore"):
        lo, hi = np.nanmin(m, 0), np.nanmax(m, 0)
    coverage = share["observed_min"].values / max(window_min, 1)
    stuck_mask = (lo == hi) & (coverage >= STUCK_MIN_COVERAGE)
    sv = share[(share["is_vilnius"] == True) & ~stuck_mask]  # noqa: E712
    top = (sv.groupby("station_id")
           .agg(Stotelė=("station_name", "first"), Adresas=("address", "first"), Operatorius=("operator", "first"),
                Jungčių=("observed_min", "size"), obs=("observed_min", "sum"), busy=("Užimta", "sum"),
                broken=("Neveikia", "sum"))
           .query("obs > 0"))
    top["Užimtumas %"] = (top["busy"] / top["obs"] * 100).round(1)
    top["Neveikia %"] = (top["broken"] / top["obs"] * 100).round(1)
    top = top.sort_values(["Užimtumas %", "Jungčių"], ascending=False).head(15)

    hours = t.tz_convert(TZ).hour.values
    fig, ax = plt.subplots(figsize=(10, 3.8))
    for label, mask, color in [("Visos", vil, "#222"),
                               ("AC ≤22 kW", vil & (meta["power_class"] == CLASSES[0]).values, "#2b7bba"),
                               ("DC ≥50 kW", vil & meta["power_class"].isin(CLASSES[1:3]).values, "#d1495b")]:
        sub = m[:, mask]
        busy_w = ((sub == BUSY).sum(1)) * w
        work_w = (((sub == BUSY) | (sub == 0)).sum(1)) * w
        hb = pd.DataFrame({"h": hours, "b": busy_w, "n": work_w}).groupby("h").sum()
        hb = hb.reindex(range(24))
        ax.plot(hb.index, hb["b"] / hb["n"].replace(0, np.nan) * 100, marker="o", ms=3, label=label, color=color)
    ax.set_xticks(range(24))
    ax.set_xlabel("valanda (Vilniaus laiku)")
    ax.set_ylabel("užimta, % veikiančių jungčių")
    ax.grid(alpha=0.3)
    ax.legend()
    ax.set_title("Vilnius: užimtumas pagal paros valandą")

    dc = comp[(comp["is_vilnius"] == True) & comp["power_class"].isin(CLASSES[1:3])]  # noqa: E712
    dc = dc.sort_values("minutes", ascending=False).head(10)
    longest = pd.DataFrame({"Jungtis": dc["connector_id"], "Stotelė": dc["station_name"], "Adresas": dc["address"],
                            "Galia kW": dc["kw"], "Pradžia": dc["start"].map(fmt_dt),
                            "Trukmė": dc["minutes"].map(fmt_min)})
    S.append(("3. Vilnius", "<h3>Top 15 stotelių pagal užimtumą</h3><p class='muted'>Užimtumas = Užimta laikas / "
              "visas stebėtas jungčių laikas. „Užstrigusios“ jungtys (žr. 4 sk.) neįtrauktos.</p>"
              + table(top.drop(columns=["obs", "busy", "broken"])) + fig_html(fig)
              + "<h3>10 ilgiausių pilnų DC sesijų Vilniuje</h3>" + table(longest)))

    # 4. Quality
    q = share[share["observed_min"] > 0].groupby("operator").agg(
        Jungčių=("observed_min", "size"), obs=("observed_min", "sum"),
        unk=("Nežinoma", "sum"), brk=("Neveikia", "sum"), busy=("Užimta", "sum"))
    q["Nežinoma %"] = (q["unk"] / q["obs"] * 100).round(1)
    q["Neveikia %"] = (q["brk"] / q["obs"] * 100).round(1)
    q["Užimta %"] = (q["busy"] / q["obs"] * 100).round(1)
    q["Blogų iš viso %"] = (q["Nežinoma %"] + q["Neveikia %"]).round(1)
    q = q.reset_index().rename(columns={"operator": "Operatorius"}).drop(columns=["obs", "unk", "brk", "busy"])
    q = q.sort_values(["Blogų iš viso %", "Jungčių"], ascending=False)

    stuck = share[stuck_mask].copy()
    stuck["Būsena"] = [STATUSES[int(x)] for x in lo[stuck_mask]]
    by = (stuck.groupby("Būsena").size().reindex(STATUSES, fill_value=0).rename("Jungčių").reset_index())
    by["% sekamų"] = (by["Jungčių"] / len(cols) * 100).round(1)
    sus = stuck[stuck["Būsena"].isin(["Užimta", "Nežinoma"])].reset_index(names="connector_id")
    sus = sus.assign(**{"Stebėta": sus["observed_min"].map(fmt_min)}).sort_values(["Būsena", "operator", "city"])
    sus = sus[["connector_id", "Būsena", "operator", "city", "address", "power_class", "Stebėta"]].rename(
        columns={"connector_id": "Jungtis", "operator": "Operatorius", "city": "Miestas", "address": "Adresas",
                 "power_class": "Klasė"})
    S.append(("4. Duomenų kokybė", "<h3>Laikas būsenose Nežinoma / Neveikia pagal operatorių</h3>" + table(q)
              + f"<h3>„Užstrigusios“ jungtys</h3><p class='muted'>Visą stebėtą laiką vienoje būsenoje, stebėta ≥"
              f"{int(STUCK_MIN_COVERAGE * 100)}% laikotarpio ({fmt_min(window_min)}). Ilgai „Laisva“ gali būti tiesiog "
              f"nenaudojama stotelė; ilgai „Užimta“ ar „Nežinoma“ – greičiausiai užstrigę duomenys.</p>"
              + table(by) + "<h3>Įtartinos: visą laiką Užimta arba Nežinoma</h3>" + table(sus.head(300))
              + (f"<p class='muted'>Rodoma 300 iš {len(sus)}.</p>" if len(sus) > 300 else "")))

    generated = datetime.now(timezone.utc).astimezone().strftime("%Y-%m-%d %H:%M")
    nav = " · ".join(f"<a href='#s{i}'>{h}</a>" for i, (h, _) in enumerate(S))
    body = "".join(f"<section id='s{i}'><h2>{h}</h2>{c}</section>" for i, (h, c) in enumerate(S))
    doc = f"""<!doctype html><html lang="lt"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>EV jungčių ataskaita</title>
<style>
body{{font:14px/1.45 system-ui,-apple-system,Segoe UI,sans-serif;margin:0;background:#f6f7f9;color:#1d2330}}
main{{max-width:1180px;margin:0 auto;padding:16px}}
section{{background:#fff;border:1px solid #e3e6ea;border-radius:8px;padding:16px 20px;margin:16px 0;overflow-x:auto}}
h1{{font-size:22px;margin:8px 0}} h2{{font-size:18px;margin:0 0 12px}} h3{{font-size:15px;margin:18px 0 8px}}
table.t,table.kv{{border-collapse:collapse;font-size:13px}}
table.t th,table.t td,table.kv th,table.kv td{{padding:4px 10px;border-bottom:1px solid #eceef1;text-align:left;vertical-align:top}}
table.t th{{background:#f0f2f5;position:sticky;top:0}} table.kv th{{font-weight:500;color:#5a6270}}
img{{max-width:100%;margin-top:12px}} .muted{{color:#6b7280}} nav a{{color:#2b6cb0}}
</style></head><body><main><h1>EV įkrovimo jungčių ataskaita</h1>
<p class="muted">Sugeneruota {generated} · šaltinis ev.vialietuva.lt · {html.escape(os.path.abspath(a.data_dir))}</p>
<nav>{nav}</nav>{body}</main></body></html>"""
    with open(a.out, "w", encoding="utf-8") as f:
        f.write(doc)
    print(f"{a.out}: {len(t)} runs, {len(cols)} connectors, {len(ses)} sessions ({len(comp)} complete)")


if __name__ == "__main__":
    main()

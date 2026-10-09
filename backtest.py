"""Backtest the "when will this connector free up" prediction (export_app.EndModel).

    python backtest.py                 # last 24 h held out, prints the report
    python backtest.py --test-hours 36 --plot backtest.png

Walk-forward, no peeking: the model is trained only on sessions that ended before the
cutoff. Then every 15 min of the held-out window we take every connector that was
Užimta (and whose start we saw), ask the model "P(free within 30 min)" exactly like the
app does, and check what really happened. Snapshots whose outcome falls past the end
of the data are skipped.

Baselines:
  * class rate  = share of all past sessions in the same power class that ended within
                  30 min of *starting* (ignores how long the car has already been there);
  * coin        = always 50 %.
Only the standard library is needed; --plot uses matplotlib if it is installed.
"""
import argparse
import statistics
from collections import defaultdict
from datetime import timedelta

from export_app import (LT, EndModel, load_events, load_stations, max_kw,
                        power_class, sessions_and_current)

H = 30            # horizon the app shows in colour (p_free_30min)
STEP_MIN = 15


def busy_intervals(events, stations):
    """All Užimta intervals with a seen start; end=None when still busy at data end."""
    done, cur, since = sessions_and_current(events, stations)
    ivs = [(c, s, e) for c, s, e in done]
    for c, st in cur.items():
        if st == "Užimta" and since[c][1]:
            ivs.append((c, since[c][0], None))
    return ivs


def brier(rows, key):
    return statistics.mean((r[key] - r["y"]) ** 2 for r in rows)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--test-hours", type=float, default=24)
    ap.add_argument("--plot", help="write a calibration chart (PNG) for the slides")
    args = ap.parse_args()

    stations = load_stations()
    events = load_events()
    t_end = events[-1][0]
    cutoff = t_end - timedelta(hours=args.test_hours)
    ivs = [iv for iv in busy_intervals(events, stations) if iv[0] in stations]

    train = [(c, s, e) for c, s, e in ivs if e is not None and e <= cutoff]
    model = EndModel(train, stations)
    class_rate = {}
    for cls, durs in model.by_class.items():
        class_rate[cls] = sum(d <= H for d in durs) / len(durs)

    rows = []
    t = cutoff
    while t + timedelta(minutes=H) <= t_end:
        for c, s, e in ivs:
            if not (s <= t and (e is None or e > t)):
                continue
            cls = power_class(max_kw(stations[c]["power_kw"]))
            elapsed = (t - s).total_seconds() / 60
            p = model.predict(stations[c]["station_id"], cls, elapsed, s.astimezone(LT).hour)
            if p is None:
                continue
            y = 1 if e is not None and e <= t + timedelta(minutes=H) else 0
            remaining = (e - t).total_seconds() / 60 if e is not None else None
            rows.append({"p": p[f"p_free_{H}min"], "base": class_rate.get(cls, 0.5), "y": y,
                         "cls": cls, "pred_rem": p["expected_remaining_min"], "rem": remaining})
        t += timedelta(minutes=STEP_MIN)

    if not rows:
        raise SystemExit("not enough data for a backtest")

    print(f"Treniravimas: {len(train)} sesijų iki {cutoff:%Y-%m-%d %H:%M} UTC")
    print(f"Testas: {args.test_hours:g} val. iki {t_end:%Y-%m-%d %H:%M} UTC, {len(rows)} prognozių "
          f"(kas {STEP_MIN} min. kiekvienai užimtai jungčiai)\n")

    bins = [(0, .2), (.2, .4), (.4, .6), (.6, .8), (.8, 1.01)]
    print(f"Kalibracija: kai sakėme „X % atsilaisvins per {H} min.“, kiek iš tikrųjų atsilaisvino")
    calib = []
    for lo, hi in bins:
        b = [r for r in rows if lo <= r["p"] < hi]
        if b:
            pred, real = statistics.mean(r["p"] for r in b), statistics.mean(r["y"] for r in b)
            calib.append((pred, real, len(b)))
            print(f"  {lo*100:3.0f}–{min(hi, 1)*100:3.0f} %: sakėme vid. {pred*100:4.0f} %, "
                  f"atsilaisvino {real*100:4.0f} %  (n={len(b)})")

    model_b, base_b = brier(rows, "p"), brier(rows, "base")
    coin_b = statistics.mean((0.5 - r["y"]) ** 2 for r in rows)
    print(f"\nBrier (mažiau = geriau): modelis {model_b:.3f}, galios klasės vidurkis {base_b:.3f}, "
          f"50/50 {coin_b:.3f}")
    print(f"  → modelis {100 * (1 - model_b / base_b):.0f} % tikslesnis už paprastą vidurkį")

    confident = [r for r in rows if r["p"] >= 0.7 or r["p"] <= 0.3]
    hits = sum((r["p"] >= 0.7) == bool(r["y"]) for r in confident)
    print(f"\nKai modelis tvirtas (≥70 % arba ≤30 %, {100 * len(confident) / len(rows):.0f} % atvejų): "
          f"pataikė {100 * hits / len(confident):.0f} %")
    all_hits = sum((r["p"] >= 0.5) == bool(r["y"]) for r in rows)
    print(f"Visi atvejai (riba 50 %): pataikė {100 * all_hits / len(rows):.0f} %")

    err = [abs(r["pred_rem"] - r["rem"]) for r in rows if r["rem"] is not None]
    if err:
        print(f"\n„Atsilaisvins per ~N min.“: medianinė paklaida {statistics.median(err):.0f} min. "
              f"(n={len(err)} baigtų sesijų)")

    by_cls = defaultdict(list)
    for r in rows:
        by_cls[r["cls"]].append(r)
    print("\nPagal galios klasę:")
    for cls in sorted(by_cls):
        b = by_cls[cls]
        acc = sum((r["p"] >= 0.5) == bool(r["y"]) for r in b) / len(b)
        print(f"  {cls:7s} n={len(b):5d}  pataikymas {acc*100:3.0f} %  Brier {brier(b, 'p'):.3f} "
              f"(vidurkis {brier(b, 'base'):.3f})")

    if args.plot:
        plot(calib, args.plot, model_b, base_b, len(rows))


def plot(calib, path, model_b, base_b, n):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    fig, ax = plt.subplots(figsize=(6, 6), dpi=200)
    ax.plot([0, 100], [0, 100], color="#bbb", lw=1.5, ls="--", label="Ideali prognozė")
    xs = [c[0] * 100 for c in calib]
    ys = [c[1] * 100 for c in calib]
    ax.plot(xs, ys, color="#1a7f5a", lw=2.5, marker="o", ms=9, label="evflow prognozė")
    for x, y, k in calib:
        ax.annotate(f"n={k}", (x * 100, y * 100), textcoords="offset points", xytext=(10, 4),
                    fontsize=9, color="#666")
    ax.set_xlim(0, 100)
    ax.set_ylim(0, 100)
    ax.set_xlabel(f"Prognozuota tikimybė atsilaisvinti per {H} min., %", fontsize=11)
    ax.set_ylabel("Iš tikrųjų atsilaisvino, %", fontsize=11)
    mid = min(calib, key=lambda c: abs(c[0] - 0.7))
    ax.set_title(f"Kai sakome „{mid[0] * 100:.0f} % atsilaisvins per {H} min.“, "
                 f"atsilaisvina {mid[1] * 100:.0f} %\n{n} patikrintų prognozių, paskutinė para",
                 fontsize=12)
    ax.spines[["top", "right"]].set_visible(False)
    ax.legend(frameon=False, loc="upper left")
    fig.tight_layout()
    fig.savefig(path)
    print(f"\n{path} išsaugotas")


if __name__ == "__main__":
    main()

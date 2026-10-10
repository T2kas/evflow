# evflow – Lietuvos EV įkrovimo jungčių būsenų rinkinys

Šaltinis: `https://ev.vialietuva.lt/api/locations/all?limit=500&offset=N` (tas pats JSON, kurį naudoja ev.vialietuva.lt/map).
Paleidžiama per cron-job.org → GitHub `workflow_dispatch` kas ~3 min. Vienas paleidimas = vienas snapshot.

## Duomenys (`data/`)
| Failas | Turinys |
|---|---|
| `stations.csv` | statiniai jungčių duomenys: `connector_id, evse_id, station_id, station_name, operator, address, city, lat, lon, connector_type, power_kw, tariff, charger_id, owner, restriction, open_24_7, tariff_note`. `charger_id` jungia vieno fizinio įkroviklio kištukus (pvz. CHAdeMO+CCS+T2 – kai vienas naudojamas, kiti dažnai irgi rodomi „Užimta“, tad sesijas skaičiuok pagal `charger_id`). `restriction`: `CUSTOMERS` = tik klientams, `DISABLED` = neįgaliųjų vieta. Perrašomas tik pasikeitus; dingusios jungtys paliekamos. |
| `status/YYYY-MM-DD.csv` | `timestamp_utc, connector_id, status` – tik būsenos pokyčiai + heartbeat kiekvienai jungčiai kas 30 min. Pirmas jungties įrašas = pradinė būsena. |
| `prices/YYYY-MM-DD.csv` | `timestamp_utc, connector_id, tariff` – tarifo pokyčiai (dalis operatorių, pvz. Stuart Energy, Įkrautas, keičia kainą kas valandą pagal Nord Pool). Iki 2026-10-07 18 val. atkurta iš git istorijos. |
| `freshness/YYYY-MM-DD.csv` | kas 30 min: `timestamp_utc, station_id, last_update_utc, age_min` – kada operatorius paskutinį kartą atsiuntė duomenis (API `lu`). Didelis `age_min` = būsena greičiausiai pasenusi. |
| `payments.csv` | vienkartinis (`python enrich_payments.py`): mokėjimo būdai pagal stotelę. Nepilnas – svetainė turi info tik ~967 iš 2068 stotelių, „Per programėlę“ = 0 visiems. |
| `last_status.json` | paskutinė būsena (`s`), API reikšmė (`raw`) ir paskutinio įrašo/heartbeat laikas (`hb`). |
| `runs.csv` | kiekvieno paleidimo log'as: `timestamp_utc, connectors, changes, heartbeats, new_connectors, duration_s, error`. |

Būsenos: `AVAILABLE→Laisva`, `CHARGING→Užimta`, `OUTOFORDER/INOPERATIVE→Neveikia`, kita → `Nežinoma`.
Kelios jungtys API turi tą patį `eid` – jos atskiriamos sufiksu `eid#evse_id`. Jungtys su keliais kištukais: tipai/galios per `|`.

Būsenos laiko momentu T = paskutinis jungties įrašas su `timestamp_utc <= T` (įrašas garantuotas bent kas 30 min., tad tarpas > 30 min. reiškia surinkimo spragą – žr. `runs.csv`).

## Naudojimas
```
python scraper.py   # vienas snapshot (tik standartinė biblioteka)
python stats.py     # santrauka
```

## Analizė (`explore.py` → `report.html`)
```
pip install pandas matplotlib
git pull && python explore.py        # arba: python explore.py <data_dir> -o kitas.html
```
Ataskaitos turinys: duomenų sveikata (spragos >10 min), sesijos (Užimta → kita būsena; nepilnos neįtraukiamos į trukmes),
Vilniaus užimtumas (top 15 stotelių, pagal valandą, ilgiausios DC sesijos), duomenų kokybė pagal operatorių ir „užstrigusios“ jungtys.
Visi procentai yra laiko svertiniai; laikas per duomenų spragas neskaičiuojamas.

## Dashboard operatoriams ir miestui (`dashboard/`)
```
python3 dashboard/serve.py           # http://localhost:8000/dashboard/ – gyvi duomenys iš GitHub, atsinaujina kas 3 min.
python3 dashboard/serve.py --local   # pirma paleidžia export_app.py ir rodo vietinius app_data/ (be GitHub)
```
Rodo: rodiklius, žemėlapį (dabartinė būsena arba blokavimas per istoriją), kas stovi per ilgai dabar, ką reikia taisyti, taisyklių simuliatorių, užimtumą pagal valandą ir operatorių palyginimą. Filtras pagal operatorių: viršuje arba paspaudus operatoriaus eilutę.

# evflow – Lietuvos EV įkrovimo jungčių būsenų rinkinys

Šaltinis: `https://ev.vialietuva.lt/api/locations/all?limit=500&offset=N` (tas pats JSON, kurį naudoja ev.vialietuva.lt/map).
Paleidžiama per cron-job.org → GitHub `workflow_dispatch` kas ~3 min. Vienas paleidimas = vienas snapshot.

## Duomenys (`data/`)
| Failas | Turinys |
|---|---|
| `stations.csv` | statiniai jungčių duomenys: `connector_id, evse_id, station_id, station_name, operator, address, city, lat, lon, connector_type, power_kw, tariff`. Perrašomas tik pasikeitus; dingusios jungtys paliekamos. |
| `status/YYYY-MM-DD.csv` | `timestamp_utc, connector_id, status` – tik būsenos pokyčiai + heartbeat kiekvienai jungčiai kas 30 min. Pirmas jungties įrašas = pradinė būsena. |
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

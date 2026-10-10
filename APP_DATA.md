# evflow app duomenys (`app_data/`)

Generuoja `python export_app.py`: tik standartinė Python biblioteka, ~4 s. Šaltinis yra Via Lietuva atviri duomenys (ev.vialietuva.lt), renkami kas ~3 min. nuo 2026-10-06.
**Live URL (atsinaujina kas ~3 min.):**
- https://raw.githubusercontent.com/T2kas/evflow/app-data/stations.json
- https://raw.githubusercontent.com/T2kas/evflow/app-data/city_stats.json

Visi laikai UTC (ISO, `Z`), galios kW, trukmės minutėmis.

## `stations.json` (~3 MB, 2068 stotelės)

```jsonc
{
  "meta": { "generated_utc", "data_until_utc", "history_from_utc", "history_days" },
  "stations": [{
    "id": "2831", "name": "...", "operator": "In Balance grid, UAB",
    "address": "...", "city": "Vilnius", "lat": 54.69, "lon": 25.26,
    "open_24_7": true | false | null,        // null = operatorius nenurodė
    "opening_hours": [{ "weekday": 1, "begin": "07:00", "end": "18:00" }] | null,  // 1 = pirmadienis, Lietuvos laikas
    "open_now": true | false | null,
    "payments": ["Bankine kortele", "RFID tokenu", ...] | null,
    "max_power_kw": 150,
    "counts": { "total", "free", "busy", "broken", "unknown", "overstaying" },
    "expected_wait_min": 0 | 23 | null,      // 0 = yra laisva jungtis; null = nežinoma. Kada atsilaisvins PIRMA iš užimtų jungčių (mediana)
    "wait_range_min": [0, 40] | null,        // [10-as, 80-as procentilis]; rodyk tik viršų: „8 iš 10 kartų per 40 min.“
    "availability": {                        // AR RASI VIETĄ: pagal istoriją, nepriklauso nuo dabartinės būsenos
      "level": "green" | "yellow" | "red" | null,   // dabartinei Lietuvos valandai; null = mažai duomenų
      "level_overall": "green" | ...,               // visos paros
      "free_share_overall": 0.87,                   // laiko dalis, kai buvo bent viena laisva jungtis
      "level_by_hour": [24 × level]                 // atvykimo valandai: level_by_hour[arrivalHour]
    },
    "reliability": {
      "score": 0-100,                        // 100 = niekada nebuvo „Neveikia“ / „Nežinoma“
      "broken_share": 0.004,                 // laiko dalis, kai jungtys neveikė
      "data_age_min": 50,                    // prieš kiek min. operatorius paskutinį kartą atsiuntė duomenis
      "never_used": false                    // per visą stebėjimą niekas nekrovė (galimai fiktyvi / neveikianti)
    },
    "history": {
      "sessions", "sessions_per_day", "median_session_min",
      "overstay_sessions", "overstay_share",  // kiek sesijų užsitęsė ilgiau, nei reikia pasikrauti
      "overstay_hours",                        // suminis „užsistovėjimo“ laikas
      "blocking_hours",                        // užsistovėjimas, kai visa stotelė buvo pilna (kažkas negalėjo krauti)
      "full_share",                            // laiko dalis, kai nebuvo nė vienos laisvos jungties
      "busy_by_hour": [24 skaičiai 0-1 | null] // užimtumas pagal Lietuvos valandą 0..23 („populiarūs laikai“)
    },
    "groups": [{ "type": "IEC_62196_T2_COMBO", "power_kw": 150, "count": 4, "free": 2 }],  // filtrams pagal kištuką
    "forecast_by_hour": {                    // kaip HERE availabilityProbabilities / predictedWaitTimes, tik valandiniai
      "free_prob": [24 × 0-1 | null],        // tikimybė, kad bus bent viena laisva jungtis tą Lietuvos valandą
      "wait_min":  [24 × min | null],        // vidutinis laukimas tą valandą (0 = paprastai laukti nereikia)
      "confidence": 0.44                     // istorijos kiekis: 1.0 = ~savaitė duomenų
    } | null,
    "connectors": [{
      "id", "charger_id", "type": "IEC_62196_T2_COMBO", "power_kw": 150, "class": "DC_150",
      "tariff": "0.42 €/kWh", "restriction": null | "CUSTOMERS" | "DISABLED",
      "status": "Laisva" | "Užimta" | "Neveikia" | "Nežinoma",
      "status_since": "2026-10-09T16:24:23Z",
      "expected_charge_min": 39,             // per kiek laiko lėtai kraunantis auto pasikrautų 20→80 % (+15 min.)
      // tik kai status == "Užimta":
      "busy_min": 4, "busy_min_is_lower_bound": false,
      "overstay": false, "overstay_min": 0,
      "prediction": {                        // gali nebūti, jei per mažai istorijos
        "p_free_15min": 0.24, "p_free_30min": 0.64, "p_free_60min": 0.92,
        "expected_remaining_min": 23,        // mediana
        "remaining_range_min": [0, 50],      // [10-as, 80-as procentilis]; rodyk „8 iš 10 kartų per 50 min.“
        "basis": "stotelės istorija", "basis_n": 25,
        "explain": "Iš 25 panašių įkrovimų (stotelės istorija), kurie jau truko 4 min., 64 % baigėsi per 30 min."
      }
    }]
  }]
}
```

`class`: `AC_11` (≤11 kW), `AC_22` (<43), `DC_50` (43–60), `DC_100` (61–149), `DC_150` (150+).

`meta.availability_levels`: `{"green": 0.8, "yellow": 0.5, "labels": {...}}`. Žalia = laisva vieta ≥80 % laiko tą valandą („Dažniausiai laisva“), geltona 50–80 % („Kartais užimta“), raudona <50 % („Dažnai užimta“). Ribas imk iš čia, nekoduok app'e.
Backtest'as (`python backtest.py`): kitą parą žaliose stotelėse laisva vieta buvo 98 % laiko, geltonose 72 %, raudonose 53 %; „8 iš 10 kartų per X min.“ pasitvirtino 77 %.

## `city_stats.json` (operatorių ir miesto dashboard'ui)

`totals`, `vilnius` (+ `top_blocking`, `top_overstay` su koordinatėmis žemėlapiui), `busy_by_hour` (10 didžiausių miestų),
`power_classes` (tipinės trukmės), `overstays` (kiekvienas užsistovėjimas `[station_id, city, overstay_min, blocking_min]` simuliatoriui), `operators` (sesijos, užsistovėjimas, neveikiančios, tylinčios >24 val. stotelės), `top_blocking` (visa LT).

## Kaip skaičiuojama (paaiškinimas useriui ir komisijai)

- **Užsistovėjimas**: sesija trunka ilgiau, nei reikia lėtai kraunančiam automobiliui pasikrauti 36 kWh (20→80 % 60 kWh baterijos) toje jungtyje, plius 15 min. Nakties AC sesijos (pradžia 20:00–07:00) neskaičiuojamos, nes krovimas per naktį yra normalus.
- **Blokavimas**: užsistovėjimo minutės, kai stotelėje nebuvo nė vienos laisvos jungties.
- **Prognozė**: imamos praeities tos pačios galios klasės sesijos (pačios stotelės, jei jų ≥15, kitaip visos LT), kurios truko bent tiek, kiek dabartinė. Dalis jų, kuri baigėsi per X min., ir yra tikimybė. Visada rodyk `explain`, kad būtų aišku, iš kur skaičius.
- **Ribojimai**: API neskiria „krauna“ nuo „baigė krauti, bet stovi“, todėl užsistovėjimas yra įvertis pagal laiką. Istorija kol kas ~3 d., ji kas dieną ilgėja.

## Rekomendacija „kur važiuoti“ (app pusėje)

`balas = važiavimo_laikas_min + expected_wait_min`. Atmesk `open_now == false`, `restriction` ir nesuderinamą `type`. Pirmenybę teik `reliability.score ≥ 80`.

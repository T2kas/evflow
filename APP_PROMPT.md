# Promptas Swift app'ui: evflow prognozių integracija

Nukopijuok viską žemiau ir įklijuok į savo AI įrankį (Cursor, Claude Code, Xcode AI).

---

Integruok į mūsų SwiftUI iOS app'ą evflow prognozių feed'ą. Feed'as jau veikia ir app'as jį jau naudoja. Dabar reikia, kad app'as rodytų prognozes, rekomenduotų stotelę ir duotų taškus. Visi skaičiavimai ir modelio kalibravimas vyksta serveryje: GitHub Actions kas ~3 min. iš naujo perskaičiuoja visą modelį iš visos sukauptos istorijos. App'as **neturi savo prognozės modelio ir jokių kietai įrašytų ribų**. Jis tik atsisiunčia feed'ą, pritaiko laiką, praėjusį nuo jo sugeneravimo, ir rodo. Taip app'as automatiškai kalibruojasi su kiekvienu nauju duomenų atnaujinimu.

## 1. Šaltinis

- `https://raw.githubusercontent.com/T2kas/evflow/app-data/stations.json` (~4 MB, 2068 stotelės)
- Pilnas formato aprašymas: `https://raw.githubusercontent.com/T2kas/evflow/app-data/README.md`
- Visi laikai UTC ISO8601 su `Z`. Trukmės minutėmis, galia kW. `forecast_by_hour` indeksai yra **Europe/Vilnius** valandos 0–23.

## 2. Modeliai (Codable)

Sukurk `Codable` struct'us su `CodingKeys` (snake_case → camelCase). **Visi laukai, kurių gali nebūti, yra optional.** Jei laukas trūksta ar yra `null`, app'as negali lūžti.

```swift
struct Feed: Codable { let meta: Meta; let stations: [Station] }
struct Meta: Codable { let generatedUtc: Date; let dataUntilUtc: Date; let historyDays: Double }

struct Station: Codable, Identifiable {
  let id: String; let name: String; let operator: String; let address: String; let city: String
  let lat: Double?; let lon: Double?
  let open24_7: Bool?; let openNow: Bool?           // JSON: "open_24_7", "open_now"
  let payments: [String]?; let maxPowerKw: Double
  let counts: Counts                                  // total, free, busy, broken, unknown, overstaying
  let expectedWaitMin: Int?                           // 0 = yra laisva vieta dabar; null = nežinoma
  let reliability: Reliability                        // score 0-100, brokenShare, dataAgeMin?, neverUsed
  let history: History                                // sessionsPerDay, medianSessionMin?, overstayShare?, busyByHour [Double?] (24)
  let groups: [Group]                                 // type, powerKw, count, free
  let forecastByHour: Forecast?                       // freeProb [Double?] (24), waitMin [Int?] (24), confidence
  let connectors: [Connector]
}

struct Connector: Codable, Identifiable {
  let id: String; let chargerId: String; let type: String; let powerKw: Double; let `class`: String
  let tariff: String?; let restriction: String?      // "CUSTOMERS" | "DISABLED" | null
  let status: String                                  // "Laisva" | "Užimta" | "Neveikia" | "Nežinoma"
  let statusSince: Date?
  let expectedChargeMin: Int                          // kiek laiko realiai reikia pasikrauti šioje jungtyje
  let busyMin: Int?; let busyMinIsLowerBound: Bool?
  let overstay: Bool?; let overstayMin: Int?
  let prediction: Prediction?
}

struct Prediction: Codable {
  let pFree15min: Double; let pFree30min: Double; let pFree60min: Double   // JSON: p_free_15min ...
  let expectedRemainingMin: Int                       // gali būti neigiamas
  let basis: String; let basisN: Int; let explain: String
}
```

`JSONDecoder` su `.iso8601` datomis. Pažiūrėk tikslius pavadinimus README.md ir pataikyk `CodingKeys`, ypač `open_24_7`, `p_free_30min` ir `class`.

## 3. Atsisiuntimas ir automatinis atnaujinimas

Sukurk `@Observable final class FeedStore`:
- `refresh()` atsisiunčia per `URLSession` su `cachePolicy = .reloadIgnoringLocalCacheData` ir URL gale prideda `?t=<unix laikas>`, kad apeitų GitHub CDN cache.
- Dekoduok **ne main thread'e** (`Task.detached`), nes failas ~4 MB.
- Kol app'as atidarytas, `refresh()` kviečiamas kas **180 s**, taip pat `scenePhase == .active` metu. Užkrovus keisk duomenis tik jei naujas `meta.dataUntilUtc` > dabartinis.
- Paskutinį sėkmingą JSON išsaugok `Caches` kataloge ir paleidus app'ą iškart rodyk jį. Tada app'as veiks ir be interneto (svarbu demo metu).
- Klaidos atveju palik senus duomenis ir parodyk mažą užrašą „Duomenys prieš X min.“, kur X = dabar − `meta.dataUntilUtc`.

## 4. Gyvas laiko koregavimas (tarp atnaujinimų)

Feed'o skaičiai galioja `meta.dataUntilUtc` momentu. Kiekvieną minutę UI perskaičiuoja (`TimelineView(.periodic(from: .now, by: 60))`):

```
lag = minutės nuo meta.dataUntilUtc iki dabar
busyNow      = connector.busyMin + lag
remainingNow = prediction.expectedRemainingMin - lag
overstayNow  = connector.overstay == true || busyNow > connector.expectedChargeMin
```

Šios funkcijos turi būti grynos (be UI) faile `Prediction+Live.swift`, kad būtų lengva testuoti.

## 5. Kaip rodyti

**Jungties eilutė:**
- `Laisva`: žalias taškas, „Laisva“.
- `Užimta` ir yra `prediction`:
  - jei `remainingNow > 0`: **„Atsilaisvins per ~{remainingNow} min.“**, suapvalinta iki 5 min.; jei daugiau nei 90 min., rodyk „~{h} val.“;
  - jei `remainingNow <= 0`: „Turėtų atsilaisvinti bet kurią minutę“;
  - spalva pagal `pFree30min`: ≥ 0.6 žalia, 0.3–0.6 geltona, < 0.3 raudona;
  - po apačia smulkiu pilku šriftu `prediction.explain`. Tai mūsų skaidrumo principas: vartotojas mato, iš kur skaičius.
- `Užimta` be `prediction`: „Užimta {busyNow} min.“
- `overstayNow`: raudona žymė **„Stovi {busyNow − expectedChargeMin} min. ilgiau nei reikia pasikrauti“**. Ji rodo ir mygtuką „Pranešti“ (kol kas tik lokalus įrašas).
- `Neveikia` / `Nežinoma`: pilka, „Neveikia“ / „Būsena nežinoma“.
- `busyMinIsLowerBound == true`: prie laiko pridėk „>“.

**Stotelės kortelė (žemėlapio pin'as ir sąrašas):**
- Didelis tekstas: `expectedWaitMin == 0` → „Yra laisvų vietų ({counts.free}/{counts.total})“; kitaip „Laukimas ~{expectedWaitMin − lag, min 0} min.“; jei `nil` → „Užimta“.
- Žymė pagal `reliability.score`: ≥ 80 „Patikima“, 50–79 „Kartais neveikia“, < 50 „Dažnai neveikia“. Jei `neverUsed`, rodyk „Niekas čia nekrauna, gali neveikti“.
- „Populiarūs laikai“: 24 stulpeliai iš `history.busyByHour` (Swift Charts `BarMark`), dabartinė Vilniaus valanda paryškinta.
- `groups` rodyk kaip čipus: „CCS 150 kW · 2/4 laisvos“.

**„Ar bus laisva, kai atvažiuosiu“:**
```
arrival = dabar + važiavimo laikas (MKDirections ETA)
h = arrival valanda Europe/Vilnius laiku
jei važiavimas ≤ 15 min.: naudok gyvus duomenis (counts.free > 0 → „Greičiausiai rasi laisvą vietą“)
kitaip: p = forecastByHour.freeProb[h], w = forecastByHour.waitMin[h]
  „{Int(p*100)} % tikimybė rasti laisvą vietą {hh}:00“ + jei w > 0 „, laukimas ~{w} min.“
jei forecastByHour.confidence < 0.3, pridėk „(mažai istorijos)“
```

## 6. Rekomendacija „kur važiuoti“

Funkcija `recommend(from userLocation, plugType: String?) -> [Recommendation]`:
1. Filtruok stoteles: yra koordinatės, `openNow != false`, yra bent viena jungtis su tinkamu `type` (jei vartotojas pasirinko kištuką), be `restriction`, `reliability.score >= 50`.
2. Paimk 10 artimiausių tiesiai (`CLLocation.distance`), tada jiems gauk ETA per `MKDirections.calculateETA`.
3. Kiekvienai: `wait = arrivalWait(station, driveMin)`:
   - jei `counts.free > 0` ir `driveMin <= 15` → 0;
   - jei `driveMin <= 60` ir `expectedWaitMin != nil` → `max(0, expectedWaitMin − lag − driveMin)`;
   - kitaip `forecastByHour.waitMin[arrivalHour] ?? 15`.
4. `score = driveMin + wait`. Rūšiuok didėjančiai ir parodyk 3 geriausius su paaiškinimu: „8 min. kelio + ~0 min. laukimo“.
5. Mygtukas „Važiuoti“ atidaro Apple Maps: `MKMapItem(placemark:).openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])`.

## 7. „Kraunu čia“, priminimas ir taškai (be backend'o)

- Jungties ekrane mygtukas **„Kraunu čia“** išsaugo `ChargingSession(connectorId, stationId, startedAt, expectedChargeMin)` per SwiftData.
- Iškart suplanuok lokalią notifikaciją (`UNUserNotificationCenter`) po `expectedChargeMin` minučių: „Turbūt jau pasikrovei. Patrauk automobilį per 10 min. ir gausi +20 taškų.“ Leidimą notifikacijoms prašyk pirmą kartą paspaudus mygtuką.
- Kiekvieno `refresh()` metu, jei yra aktyvi sesija ir feed'e ta jungtis jau `Laisva`, sesija baigta. `endedAt` = `connector.statusSince`.
  - Jei `endedAt − startedAt ≤ expectedChargeMin + 10`: **+20 taškų**, reputacija +1.
  - Jei vėluota: −1 reputacija už kiekvienas pradėtas 15 min. vėlavimo, taškų neduodama.
- Rankinis mygtukas „Baigiau ir patraukiau“ veikia taip pat, bet laiką tikrina pagal feed'ą, kai jis atsinaujina.
- Profilio ekranas rodo taškus, reputaciją (0–100, pradžioje 80) ir prizų sąrašą (statinis JSON app'e, tai demo maketas).
- Taškų ir reputacijos taisyklės turi būti viename faile `Rewards.swift` kaip konstantos, kad būtų lengva keisti.

## 8. Testai

Parašyk Swift Testing testus grynoms funkcijoms:
- `remainingNow`: kai `lag` didesnis už `expectedRemainingMin`, rodo „bet kurią minutę“;
- `overstayNow` riba;
- `arrivalWait` visos trys šakos;
- taškų skaičiavimas laiku ir vėluojant;
- `Feed` dekodavimas iš mažo pavyzdinio JSON su trūkstamais optional laukais.

## 9. Ko nedaryti

- Nekurk savo prognozės modelio ir nekoduok ribų minutėmis (pvz. „DC = 40 min.“). Visada imk `expectedChargeMin`, `prediction` ir `forecastByHour` iš feed'o, nes jie kalibruojasi su kiekvienu atnaujinimu.
- Nesiųsk feed'o duomenų į jokį kitą serverį ir nedėk API raktų į app'ą.
- Nedekoduok 4 MB JSON main thread'e.

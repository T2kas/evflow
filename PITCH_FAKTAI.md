# Faktai pitch'ui ir komisijos klausimams

Duomenys: Via Lietuva atviri duomenys (ev.vialietuva.lt), kas ~3 min. nuo 2026-10-06 14:04 UTC iki 2026-10-09 22:28 UTC (3,35 d.).
Perskaičiuoti: `python export_app.py && python backtest.py --plot backtest.png`. Prieš įrašant video atnaujinkite, nes kasdien bus daugiau istorijos.

## 1. Problemos mastas (iš atvirų duomenų)

| | Vilnius | Visa LT |
|---|---|---|
| Stotelės / jungtys | 930 / 2 535 | 2 068 / 6 418 |
| Įkrovimo sesijos (3,35 d.) | 6 748 | 14 705 |
| **Sesijos, užsitęsusios ilgiau nei reikia pasikrauti** | **29 %** (1 974) | 27 % (3 936) |
| Užsistovėjimas per dieną | ~1 480 val. | ~2 340 val. |
| **Blokavimas per dieną** (užsistovėjimas, kai visa stotelė pilna ir kažkas negali krauti) | **~330 val.** | ~415 val. |
| Neparduota energija dėl blokavimo* | ~4 750 kWh/d. (~1 800 €/d.) | ~6 700 kWh/d. (~2 400 €/d.) |
| Neveikiančios jungtys dabar | 218 | 490 |
| Stotelės, tylinčios >24 val. | | 244 |

\* **Viršutinė riba**: blokavimo valandos × tipinė galia (AC iki 11 kW, DC 60 % nominalios, ne daugiau 100 kW) × stotelės tarifas. Dalis norinčių krauti nuvažiuoja į kitą stotelę, todėl tikrasis praradimas mažesnis. Per metus Vilniuje tai iki ~0,67 mln. € potencialių pardavimų.

Pagal operatorių (komisijoje yra Ignitis):
- **Ignitis**: 380 stotelių, 1 511 jungčių, 26 % sesijų užsitęsia, 150 jungčių šiuo metu neveikia, 56 stotelės tyli >24 val.
- **In Balance grid**: 984 iš 1 389 visos LT blokavimo valandų (71 %). Tai daugiausia miesto stotelės („Vilniaus apšvietimas“: Fabijoniškių g. 2, Taikos g. 193).
- Didžiausia užsistovėjimo dalis: Stuart Energy 36 %, Stova 35 %, Elektrum 31 %.

## 2. Ar prognozė veikia (backtest)

Metodas: modelis treniruojamas tik su sesijomis iki 2026-10-08 22:28. Tada visą kitą parą kas 15 min. kiekvienai užimtai jungčiai klausiame to paties, ką rodo app'as („tikimybė atsilaisvinti per 30 min.“), ir tikriname, kas įvyko iš tikrųjų. Iš viso **44 979 patikrintos prognozės**. Grafikas: `backtest.png`.

| Sakėme | Iš tikrųjų atsilaisvino |
|---|---|
| ~8 % | 9 % |
| ~27 % | 22 % |
| ~50 % | 49 % |
| **~70 %** | **71 %** |
| ~88 % | 62 % (per daug optimistiška, n=624) |

- Taip / ne pataikymas: **83 %** visų atvejų, **88 %**, kai modelis tvirtas (≥70 % arba ≤30 %, 81 % atvejų).
- **Greitieji krovikliai (DC 150 kW+)**, kur žmonės realiai laukia: 71 % pataikymas, Brier 0,196, palyginti su 0,243 paprasto vidurkio, t. y. **~19 % tikslesnė**.

**Sąžiningai (komisija gali paklausti):**
- 83 % iš dalies „lengvi“: daug ilgų AC sesijų, kur atsakymas „per 30 min. neatsilaisvins“ akivaizdus. DC 50–100 kW pataiko tik ~60 %.
- Iš viso modelis tik ~6 % tikslesnis už paprastą galios klasės vidurkį. Lėtiesiems AC 11 kW vidurkis net šiek tiek geresnis.
- „Atsilaisvins per ~N min.“ medianinė paklaida yra 45 min. Todėl UI geriau pabrėžti tikimybę (spalvą), o ne tikslias minutes.
- Istorija kol kas vos 3 dienos, savaitgalio dar nematėme.

**Spalvos „ar rasi vietą“ ir intervalas** (pridėta po mentoriaus patarimo):
- Stotelė žalia / geltona / raudona pagal tai, kaip dažnai tą valandą būna bent viena laisva jungtis (≥80 % / 50–80 % / <50 %), nepriklausomai nuo to, kas dedasi dabar.
- Patikrinta su kita para: žaliose laisva vieta buvo **98 %** laiko, geltonose **72 %**, raudonose **53 %**.
- „9 iš 10 kartų atsilaisvina per X min.“ pasitvirtino **90 %** atvejų ir lėtiesiems (AC), ir greitiesiems (DC) krovikliams (36 412 patikrinimų).
- Planuojančiam: „Ar atsilaisvins iki 15:30?“ – kai sakėme ~87 % per 2 val., iš tikrųjų atsilaisvino 85 %.
- AC sunkiau nuspėti (žmonės palieka auto darbe visai dienai): ten 9 iš 10 riba būna 5–9 val. Tokiais atvejais app'as sąžiningai sako „sunku nuspėti“ ir siūlo kitą stotelę.

Skaidrei siūlau: grafiką ir sakinį *„Kai sakome 70 %, atsilaisvina 71 %. Patikrinta su 45 000 prognozių.“*

## 3. Verslo modelis

**Kas naudojasi** ir **kas moka** yra skirtingi žmonės (pitch gidas to klausia tiesiogiai).

| Kas | Ką gauna | Kas moka |
|---|---|---|
| Vairuotojas | Kur važiuoti, ar bus laisva, priminimai, taškai | Nemokamai |
| Operatorius (Ignitis, Eldrive, Enefit…) | Dashboard'as: kur stotelės blokuojamos, kiek kWh neparduota, neveikiančios ir tylinčios stotelės, simuliatorius kainodarai (idle fee / nemokamas laikas) | **SaaS prenumerata** pagal jungčių skaičių. Pateisinimas: mažiau blokavimo reiškia daugiau parduotų kWh (iki ~1 800 €/d. Vilniuje) |
| Savivaldybė | Kur trūksta stotelių, kur jos neefektyvios, ką keisti taisyklėse; savo stotelių („Vilniaus apšvietimas“) priežiūra | Licencija arba pilotinis projektas |
| Partneriai (prekybos centrai, kavinės prie stotelių) | Klientai, kurie laukia ar kraunasi šalia | Prizų finansavimas už taškus |

Ateityje: operatoriai galėtų perduoti tikslius OCPP duomenis (krauna / baigė) mainais į dashboard'ą, o vairuotojai su sutikimu prijungtų automobilį (Smartcar / Tesla Fleet API). Abu kanalai paverčia užsistovėjimo įvertį faktu.

Konkurentai: operatorių programėlės, PlugShare ir Google Maps daugiausia rodo **dabartinę** būseną, kiekvienas savo tinklui arba be prognozės. HERE turi prognozių API automobilių gamintojams, bet ne vairuotojų programėlę ir ne miesto dashboard'ą. Mes jungiame visus LT operatorius per vieną atvirą šaltinį, rodome, **kada atsilaisvins** (su patikrintu tikslumu), ir sprendžiame elgesio problemą (taškai, reputacija). Prieš sakydami „vieninteliai“, patikrinkite, ar konkurentai neturi tokios funkcijos.

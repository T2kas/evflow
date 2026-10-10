# evflow pre-pitch video scenarijus (iki 5:00)

Struktūra pagal Hack4Vilnius pitch gidą: **3:00 iššūkis ir sprendimas** (be demo) + **2:00 demo**.
Stilius: ~50 % kalbame į kamerą, ~50 % animacijos ir ekranai. Viena mintis viename kadre, dideli skaičiai, jokių technologijų sąrašų.
Skaičiai: Via Lietuva duomenys nuo 2026-10-06 (antradienio) iki 2026-10-10. **Prieš įrašant perskaičiuokite** (`python3 export_app.py && python3 backtest.py`) ir atnaujinkite skaičius šiame faile.

Žymėjimas: **🎥** kalbame į kamerą · **✨** animacija / grafikas · **📱** programėlės ekranas · **🖥** dashboard'as

---

## 0:00–0:15 · Kabliukas + komanda (15 s)

| Vaizdas | Tekstas (balsu) |
|---|---|
| ✨ Juodas ekranas. Žemėlapis su Vilniaus įkrovimo stotelėmis, taškai užsidega žaliai, paskui vienas po kito pasidaro raudoni. | „Vilnius. Penktadienis, 18 valanda. Jums liko 10 % baterijos.“ |
| 🎥 Kalbantysis (vidutinis planas). Apačioje titrai: vardai ir rolės. | „Mes – evflow: [Vardas] (duomenys), [Vardas] (programėlė), [Vardas] (produktas). Mes visi kraunamės Vilniuje ir visi esame stovėję prie užimtos stotelės.“ |

## 0:15–1:00 · Problema (45 s)

| Vaizdas | Tekstas |
|---|---|
| 🎥 Kalbantysis prie tikros įkrovimo stotelės (jei įmanoma, filmuokite prie stotelės, kurioje stovi automobilis). | „Atvažiuoji, o stotelė užimta. Ir dažnai ne todėl, kad kažkas kraunasi. Automobilis jau seniai pasikrovęs, tik niekas jo nepatraukė.“ |
| ✨ Didelis skaičius išauga nuo 0 iki **29 %**. Po juo: „Vilniaus įkrovimų trunka ilgiau, nei reikia pasikrauti.“ | „Mes tai išmatavome. **29 %** visų įkrovimų Vilniuje trunka ilgiau, nei automobiliui reikia pasikrauti.“ |
| ✨ Laikrodis sukasi, skaitiklis iki **~390 val.** Užrašas: „per dieną stotelė pilna, o kažkas negali krauti“. | „Tai **~390 valandų kas dieną**, kai visa stotelė užimta, o kitas vairuotojas laukia arba važiuoja ieškoti kitos.“ |
| ✨ Trys ikonėlės: vairuotojas („nežino, ar laukti“), operatorius („~2 200 €/d. neparduotos energijos“*), miestas („nežino, kur trūksta stotelių“). | „Vairuotojas nežino, ar verta laukti. Operatorius praranda pardavimus: Vilniuje iki 2 000 eurų per dieną. Miestas nemato, kur infrastruktūra dirba blogai.“ |
| 🎥 Kalbantysis. | „Taisyklė jau yra: baigus krauti, automobilį reikia patraukti nedelsiant. Bet niekas nežino, kur ir kada ji pažeidžiama, o programėlės rodo tik ‚užimta‘.“ |

\* Viršutinė riba. Jei komisija paklaus: blokavimo valandos × tipinė galia × tarifas.

## 1:00–2:00 · Sprendimas (60 s)

| Vaizdas | Tekstas |
|---|---|
| ✨ Logotipas evflow. Vienas sakinys ekrane. | „evflow padeda Vilniaus elektromobilių vairuotojams nebelaukti prie užimtų stotelių. Mes prognozuojame, kada stotelė atsilaisvins, ir skatiname laiku patraukti automobilį.“ |
| ✨ Animacija: duomenų srautas. Skaitiklis auga iki **1,17 mln.** įrašų, „kas 2 min.“, „2 068 stotelės · 6 418 jungčių · visi operatoriai“. | „Kas dvi minutes nuo antradienio renkame kiekvienos Lietuvos įkrovimo jungties būseną iš atvirų Via Lietuva duomenų. Tai jau daugiau nei milijonas įrašų ir **18 000 įkrovimų**.“ |
| ✨ Trys ramsčiai išlenda vienas po kito (trys stulpeliai / kortelės): | „Iš to sukūrėme tris dalykus.“ |
| ✨ **1. Kada atsilaisvins.** Užimta jungtis, po ja: „Greičiausiai ~15 min. · 9 iš 10 kartų per 40 min.“ | „Pirma: vairuotojas mato ne tik ‚užimta‘, bet ir **kada atsilaisvins**. Ir kur važiuoti, kad laukti reikėtų mažiausiai.“ |
| ✨ **2. Laiku patraukei – gauni taškų.** Priminimo pranešimas, +20 taškų, prizai. | „Antra: programėlė primena patraukti automobilį. Patraukei laiku, gauni taškų ir prizų. Vėluoji, krenta reputacija.“ |
| ✨ **3. Operatoriams ir miestui.** Dashboard'o žemėlapis su raudonais taškais. | „Trečia: operatoriai ir miestas mato, kur stotelės blokuojamos, kiek tai kainuoja ir ką pakeistų taisyklės.“ |
| ✨ Kalibracijos grafikas (`backtest.png`) animuotai pasipiešia. Didelis užrašas: „Sakome 70 %, atsilaisvina 71 %.“ Mažesnis: „9 iš 10 → pasitvirtino 90 %.“ | „Ir tai ne spėjimas. Prognozę patikrinome su beveik 40 000 realių atvejų: kai sakome 70 %, atsilaisvina 71 %. Kai sakome ‚9 iš 10‘, pasitvirtina 90 %.“ |

## 2:00–3:00 · Kam ir kodėl visi laimi (60 s)

| Vaizdas | Tekstas |
|---|---|
| ✨ Trys stulpeliai su ikonomis: **Vairuotojas · Operatorius · Miestas**, po kiekvienu „ką gauna“ ir „kas moka“. | „Kas naudosis ir kas mokės?“ |
| ✨ Vairuotojas: „nemokamai“. | „**Vairuotojams** programėlė nemokama: mažiau laukimo, aiškumas ir prizai.“ |
| 🖥 Trumpas dashboard'o kadras su operatoriaus filtru. Užrašas: „SaaS operatoriams“. | „**Operatoriai** moka už dashboard'ą: mato kiekvieną blokuotą stotelę, neveikiančias jungtis ir neparduotą energiją. Mažiau užsistovėjimo = daugiau parduotų kWh.“ |
| 🖥 Žemėlapis su valandos slankikliu, 18:00 parausta. | „**Miestas** mato, kur vakarais trūksta vietų, ir simuliuoja: ką pakeistų 15 min. nemokamo laiko taisyklė ar mokestis.“ |
| ✨ Simuliatoriaus juostos: „Blokuojama dabar 390 val./d.“ → „Su taisykle ~170 val./d.“ | „Pavyzdžiui, 15 minučių taisyklė Vilniuje atlaisvintų apie **200 valandų per dieną**.“ |
| 🎥 Kalbantysis. Ekrane: „Vairuotojas laukia mažiau · Operatorius parduoda daugiau · Miestas planuoja pagal duomenis“. | „Visi laimi: vairuotojas laukia mažiau, operatorius parduoda daugiau, miestas planuoja pagal duomenis, ne pagal nuojautą.“ |
| 🎥 Kalbantysis. Titrai: „Kitas žingsnis: pilotas su operatoriumi ir Vilniaus savivaldybe“. | „Toliau: pilotas su vienu operatoriumi ir savivaldybe. O gavę operatoriaus duomenis, kada krovimas tikrai baigėsi, prognozę padarysime tikslią iki minutės. Dabar – parodysime, kaip tai veikia.“ |

**Skaičius prieš įrašant patikrinkite simuliatoriuje** (preset „15 min. nemokamai“, Vilnius). Šiuo metu: ~390 → ~170 val./d. (atlaisvinta ~217 val./d.)

---

## 3:00–5:00 · Demo (2:00)

Vienas scenarijus nuo pradžios iki galo. Ekrano įrašas su balso komentaru. Duomenys gyvi. **Atsarginis variantas:** iš anksto įrašytas ekranas.

| Laikas | Ekranas | Tekstas |
|---|---|---|
| 3:00 | 📱 Atidaroma programėlė, žemėlapis. Žalia / raudona / oranžinė. | „Tai veikianti programėlė su tikrais šios dienos duomenimis. Žalia – laisva dabar, raudona – užimta, oranžinė – kažkas stovi per ilgai.“ |
| 3:15 | 📱 Paspaudžiama raudona stotelė. Kortelė: „Visos užimtos · Greičiausiai ~15 min. · 9 iš 10 kartų per 40 min.“, „Populiari: šiuo metu dažnai užimta“. | „Stotelė užimta, bet matau, kad greičiausiai atsilaisvins per 15 minučių, o 9 kartus iš 10 – per 40. Ir kad šiuo metu čia paprastai pilna.“ |
| 3:35 | 📱 Rekomendacija: kita stotelė „8 min. kelio · laisva“. „Važiuojam“ → Waze / Google Maps. | „Programėlė siūlo kitą: 8 minutės kelio ir laukti nereikia. Važiuoju per Waze.“ |
| 3:50 | 📱 Atvykus: QR skenavimas → teisinga jungtis → „Kraunu čia“. | „Atvažiavus nuskenuoju QR ir programėlė žino, prie kurios jungties kraunuosi.“ |
| 4:05 | 📱 Pranešimas: „Turbūt jau pasikrovei. Patrauk per 10 min. ir gausi +20 taškų.“ → +20 taškų → prizų parduotuvė. | „Kai turėčiau būti pasikrovęs, gaunu priminimą. Patraukiu laiku – gaunu taškų, kuriuos galiu iškeisti į prizus.“ |
| 4:20 | 📱 Pranešimas su nuotrauka apie užsistovėjusį automobilį (trumpai). | „O jei kažkas stovi per ilgai, galiu pranešti su nuotrauka. Mūsų duomenys ir kiti vartotojai tai patvirtina.“ |
| 4:30 | 🖥 Dashboard'as: filtras „Ignitis“ → „Stovi per ilgai dabar“ sąrašas → simuliatorius „15 min. nemokamai“. | „O tai operatoriaus vaizdas: kas šiuo metu stovi per ilgai, kurios stotelės neveikia, ir kiek valandų atlaisvintų taisyklė.“ |
| 4:50 | 🎥 / ✨ Logotipas ir sakinys. | „evflow: mažiau laukimo prie stotelių Vilniuje. Ačiū.“ |

**Sąžiningai (gidas to prašo, pasakykite trumpai demo metu arba titrais):** veikia tikrai – duomenų rinkimas, prognozės, programėlė su gyvais duomenimis, dashboard'as, simuliatorius. Maketas – prizų parduotuvė ir pranešimų patvirtinimas operatoriui.

---

## Grafikai animacijoms (visi iš mūsų duomenų)

| # | Grafikas | Iš kur | Kur naudoti |
|---|---|---|---|
| 1 | Skaitiklis 0 → **29 %** | `PITCH_FAKTAI.md` / dashboard KPI | Problema |
| 2 | Skaitiklis → **~390 val./d.** blokavimo | dashboard KPI „Blokuota per dieną“ | Problema |
| 3 | Vilniaus žemėlapis 11:00 → 18:00 (žalia → raudona) | dashboard „Ar rasi vietą“ + valandos slankiklis (ekrano įrašas) | Kabliukas / miestui |
| 4 | Duomenų skaitiklis → **1,17 mln.** įrašų, „kas 2 min. nuo antradienio“ | `data/status/*.csv` eilučių skaičius | Sprendimas |
| 5 | Kalibracijos grafikas „sakome 70 % → 71 %“ | `backtest.png` | Sprendimas (įrodymas) |
| 6 | Užimtumas pagal valandą (stulpeliai, pikas ~10–13 val.) | dashboard „Kada stotelės užimtos“ | Galima naudoti miestui |
| 7 | Simuliatoriaus juostos prieš / po | dashboard simuliatorius | Kam ir kodėl |

## Įrašymo patarimai (iš gido)

- Garsas svarbiau už vaizdą: tyli patalpa, mikrofonas arti.
- Repetuokite su laikmačiu bent 3 kartus. Jei netelpa, trumpinkite 2:00–3:00 dalį, ne demo.
- YouTube: **Unlisted**, patikrinkite nuorodą inkognito lange. Įkelti į VeloxEntry **iki sekmadienio 11:30**.
- Skaidrės + PDF **iki 13:00**.

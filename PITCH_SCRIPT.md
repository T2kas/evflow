# evflow pre-pitch video scenarijus (iki 5:00)

Struktūra pagal Hack4Vilnius pitch gidą: **3:00 iššūkis ir sprendimas** (be demo) + **2:00 demo**.
Stilius: ~50 % kalbame į kamerą, ~50 % animacijos ir ekranai. Viena mintis viename kadre, dideli skaičiai, jokių technologijų sąrašų.
Skaičiai: Via Lietuva duomenys nuo 2026-10-06 (antradienio). **Prieš įrašant perskaičiuokite** (`python3 export_app.py && python3 backtest.py`) ir atnaujinkite skaičius.

Žymėjimas: **🎥** kalbame į kamerą · **✨** animacija / grafikas · **📱** programėlės ekranas · **🖥** dashboard'as

---

## 0:00–0:15 · Kabliukas + komanda (15 s)

| Vaizdas | Tekstas (balsu) |
|---|---|
| ✨ Tamsus ekranas. Vilniaus žemėlapis, stotelės užsidega žaliai, paskui viena po kitos parausta. Kampe baterijos ikona: 10 %. | „Penktadienio vakaras, Vilnius. Baterijoje liko dešimt procentų, o artimiausia stotelė – užimta.“ |
| 🎥 Kalbantysis. Titrai: vardai ir rolės. | „Mes – evflow. Aš [Vardas], kartu su [Vardas] ir [Vardas]. Visi esame stovėję prie užimtos stotelės ir nežinoję, ar verta laukti, ar važiuoti kitur.“ |

## 0:15–1:00 · Problema (45 s)

| Vaizdas | Tekstas |
|---|---|
| 🎥 Kalbantysis prie tikros stotelės (geriausia tokios, kur stovi automobilis). | „Ir dažnai stotelė užimta ne todėl, kad kažkas kraunasi. Automobilis jau seniai pasikrovęs – tiesiog niekas jo nepatraukė.“ |
| ✨ Skaičius išauga nuo 0 iki **29 %**. Po juo: „Vilniaus įkrovimų trunka ilgiau, nei reikia pasikrauti“. | „Mes tai suskaičiavome. Vilniuje beveik kas trečias įkrovimas trunka ilgiau, nei automobiliui reikia pasikrauti.“ |
| ✨ Laikrodis sukasi, skaitiklis iki **~390 val.** Užrašas: „per dieną visa stotelė užimta, o kažkas laukia“. | „Kasdien susidaro apie 390 valandų, kai visa stotelė užimta, o kitas vairuotojas stovi ir laukia – arba sukasi po miestą ieškodamas kitos.“ |
| ✨ Trys ikonos: vairuotojas („nežino, ar laukti“), operatorius („iki ~2 000 €/d. neparduotos elektros“*), miestas („nemato, kur trūksta stotelių“). | „Nuo to kenčia visi. Vairuotojas nežino, ar laukti. Operatorius neparduoda elektros – Vilniuje tai iki dviejų tūkstančių eurų per dieną. O miestas nemato, kur stotelių iš tikrųjų trūksta.“ |
| 🎥 Kalbantysis. | „Taisyklė, kad baigus krauti automobilį reikia patraukti, jau yra. Tik niekas nemato, kur ir kada ji pažeidžiama. O visos programėlės rodo tą patį: ‚užimta‘. Ir tiek.“ |

\* Viršutinė riba. Jei komisija paklaus: blokavimo valandos × tipinė jungties galia × tarifas.

## 1:00–2:00 · Sprendimas (60 s)

| Vaizdas | Tekstas |
|---|---|
| ✨ Logotipas evflow. Vienas sakinys ekrane. | „Todėl sukūrėme evflow. Parodome, kada stotelė atsilaisvins, ir skatiname vairuotojus laiku patraukti automobilį.“ |
| ✨ Duomenų srautas. Skaitiklis auga iki **1,17 mln.** įrašų; užrašai „kas 2 min. nuo antradienio“, „2 068 stotelės · 6 418 jungčių · visi operatoriai“. | „Nuo antradienio kas dvi minutes renkame kiekvienos Lietuvos įkrovimo jungties būseną iš atvirų Via Lietuva duomenų. Jau turime daugiau nei milijoną įrašų ir 18 000 įkrovimų – iš jų mokosi mūsų prognozės.“ |
| ✨ Trys ramsčiai išlenda vienas po kito. | „Iš to padarėme tris dalykus.“ |
| ✨ **1. Kada atsilaisvins.** Užimta jungtis: „Greičiausiai ~15 min. · 9 iš 10 kartų per 40 min.“ Šalia trumpai: kelionės planas Vilnius → Klaipėda su 1–2 sustojimais. | „Pirma – vairuotojui. Vietoj ‚užimta‘ jis mato, per kiek laiko stotelė atsilaisvins, ir kur važiuoti, kad laukti reikėtų mažiausiai. O prieš ilgesnę kelionę gali susiplanuoti, kur sustoti pasikrauti.“ |
| ✨ **2. Laiku patraukei – gauni taškų.** Priminimas, +20 taškų, prizų kortelės (partnerių kuponai, operatoriaus krovimo nuolaida). Mažai: nuotraukos pranešimas. | „Antra – elgesys. Kai turėtum būti pasikrovęs, programėlė primena patraukti automobilį. Patrauki laiku – gauni taškų, kuriuos gali iškeisti į partnerių prizus ar krovimo nuolaidas. Vėluoji – krenta reputacija. O jei kas nors užstatė vietą, gali pranešti su nuotrauka.“ |
| ✨ **3. Operatoriams ir miestui.** Dashboard'o žemėlapis su raudonais taškais. | „Trečia – operatoriams ir miestui: matyti, kur stotelės blokuojamos, kiek tai kainuoja ir ką pakeistų naujos taisyklės.“ |
| ✨ Didelis užrašas „9 iš 10“ → „pasitvirtino 90 %“. Mažiau: „patikrinta su ~40 000 realių atvejų“. | „Ir tai patikrinome. Kai sakome, kad devynis kartus iš dešimties stotelė atsilaisvins per, tarkim, 40 minučių – realiai taip ir būna, devynis kartus iš dešimties.“ |

## 2:00–3:00 · Kam ir kodėl visi laimi (60 s)

| Vaizdas | Tekstas |
|---|---|
| ✨ Trys stulpeliai: **Vairuotojas · Operatorius · Miestas**, po kiekvienu „ką gauna“ ir „kas moka“. | „Kas tuo naudosis ir kas mokės?“ |
| ✨ Vairuotojas: „nemokamai“. | „Vairuotojams evflow nemokamas.“ |
| 🖥 Dashboard'as su operatoriaus filtru. Užrašas: „Prenumerata operatoriams“. | „Operatoriai moka už suvestinę. Jie mato kiekvieną blokuotą stotelę, neveikiančias jungtis ir kiek elektros neparduoda. Mažiau užsistovėjusių automobilių – daugiau parduotų kilovatvalandžių.“ |
| 🖥 Žemėlapis su valandos slankikliu: 18:00 parausta. | „Miestas mato, kur vakarais trūksta vietų, ir gali pasimodeliuoti taisykles – pavyzdžiui, 15 nemokamų minučių po įkrovimo, o paskui mokestis.“ |
| ✨ Simuliatoriaus juostos: „Dabar 390 val./d.“ → „Su taisykle ~170 val./d.“ | „Vien tokia taisyklė Vilniuje atlaisvintų apie 200 valandų per dieną.“ |
| 🎥 Kalbantysis. Ekrane: „Vairuotojas laukia mažiau · Operatorius parduoda daugiau · Miestas planuoja pagal duomenis“. | „Taip laimi visi: vairuotojas mažiau laukia, operatorius daugiau parduoda, o miestas sprendimus priima pagal duomenis.“ |
| 🎥 Kalbantysis. Titrai: „Kitas žingsnis: pilotas su operatoriumi ir Vilniaus savivaldybe“. | „Toliau norime pilotuoti su vienu operatoriumi ir Vilniaus savivaldybe. Gavę operatoriaus duomenis, kada krovimas iš tikrųjų baigiasi, prognozes padarysime dar tikslesnes. O dabar – kaip tai atrodo gyvai.“ |

**Skaičius prieš įrašant patikrinkite simuliatoriuje** (preset „15 min. nemokamai“, Vilnius). Šiuo metu: ~390 → ~170 val./d. (atlaisvinta ~217 val./d.).

---

## 3:00–5:00 · Demo (2:00)

Vienas scenarijus nuo pradžios iki galo. Ekrano įrašas su balso komentaru, duomenys gyvi. **Atsarginis variantas:** iš anksto įrašytas ekranas.

| Laikas | Ekranas | Tekstas |
|---|---|---|
| 3:00 | 📱 Programėlė, žemėlapis: žalia / raudona / oranžinė. | „Čia veikianti programėlė su šios dienos duomenimis. Žalia – laisva, raudona – užimta, oranžinė – kažkas stovi ilgiau, nei reikia.“ |
| 3:15 | 📱 Paspaudžiama raudona stotelė. Kortelė: „Greičiausiai ~15 min. · 9 iš 10 kartų per 40 min.“, „Populiari: šiuo metu dažnai užimta“. | „Ši stotelė užimta. Bet matau, kad greičiausiai atsilaisvins po kokių 15 minučių, o beveik tikrai – per 40. Ir kad šiuo metu čia dažniausiai pilna.“ |
| 3:30 | 📱 Rekomendacija: kita stotelė „8 min. kelio · laisva“. „Važiuojam“ → Waze / Google Maps. | „Tai programėlė pasiūlo kitą – aštuonios minutės kelio, ir laisva dabar. Spaudžiu ‚Važiuojam‘ ir važiuoju per Waze.“ |
| 3:45 | 📱 Atvykus: QR skenavimas → atpažinta jungtis → „Kraunu čia“. | „Atvažiavęs nuskenuoju QR kodą, ir programėlė iškart žino, prie kurios jungties kraunuosi.“ |
| 4:00 | 📱 Pranešimas: „Turbūt jau pasikrovei. Patrauk per 10 min. ir gausi +20 taškų.“ → +20 → prizų parduotuvė. | „Kai turėčiau būti pasikrovęs, gaunu priminimą. Patraukiu laiku – plius dvidešimt taškų, kuriuos galiu iškeisti į prizus.“ |
| 4:15 | 📱 „Planuoti kelionę“: kryptis → siūlomi sustojimai → išvykimo laikas → planas su stotelėmis. Greitai, be detalių. | „Jei važiuoju toliau, pasirenku kryptį ir kada išvykstu – programėlė pasiūlo, kiek kartų ir kur sustoti pasikrauti.“ |
| 4:25 | 📱 Pranešimas su nuotrauka apie užstatytą vietą. | „O jei vietą užstatė kitas automobilis – nufotografuoju. Pranešimą patvirtina kiti vairuotojai ir mūsų duomenys, tada jis keliauja operatoriui.“ |
| 4:35 | 🖥 Dashboard'as: filtras „Ignitis“ → „Stovi per ilgai“ → simuliatorius „15 min. nemokamai“. | „O čia operatoriaus pusė: kas šiuo metu stovi per ilgai, kurios jungtys neveikia ir kiek valandų atlaisvintų nauja taisyklė.“ |
| 4:50 | 🎥 / ✨ Logotipas. | „evflow – kad prie stotelės nebereikėtų laukti.“ |

**Sąžiningai (gidas to prašo, galima titrais demo metu):** veikia tikrai – duomenų rinkimas, prognozės, programėlė su gyvais duomenimis, kelionės planavimas, dashboard'as, simuliatorius. Maketas – prizų parduotuvė (partneriai pavyzdiniai), operatorių nuolaidos ir pranešimų perdavimas operatoriui.

---

## Grafikai animacijoms (visi iš mūsų duomenų)

| # | Grafikas | Iš kur | Kur naudoti |
|---|---|---|---|
| 1 | Skaitiklis 0 → **29 %** | `PITCH_FAKTAI.md` / dashboard KPI | Problema |
| 2 | Skaitiklis → **~390 val./d.** blokavimo | dashboard KPI „Blokuota per dieną“ | Problema |
| 3 | Vilniaus žemėlapis 11:00 → 18:00 (žalia → raudona) | dashboard „Ar rasi vietą“ + valandos slankiklis (ekrano įrašas) | Kabliukas / miestui |
| 4 | Duomenų skaitiklis → **1,17 mln.** įrašų, „kas 2 min. nuo antradienio“ | `data/status/*.csv` eilučių skaičius | Sprendimas |
| 5 | „9 iš 10“ → „pasitvirtino 90 %“ (jungtims 89–90 %, visai stotelei 94 %) | `python3 backtest.py` | Sprendimas (įrodymas) |
| 6 | Užimtumas pagal valandą (pikas ~10–13 val.) | dashboard „Kada stotelės užimtos“ | Miestui (nebūtina) |
| 7 | Simuliatoriaus juostos prieš / po | dashboard simuliatorius | Kam ir kodėl |

## Įrašymo patarimai (iš gido)

- Garsas svarbiau už vaizdą: tyli patalpa, mikrofonas arti.
- Repetuokite su laikmačiu bent 3 kartus. Jei netelpa, trumpinkite 2:00–3:00 dalį, ne demo.
- YouTube: **Unlisted**, patikrinkite nuorodą inkognito lange. Įkelti į VeloxEntry **iki sekmadienio 11:30**.
- Skaidrės + PDF **iki 13:00**.

# EVFlow finalas: kalbėjimo scenarijus (Tautvydas ir Tadas)

Skaidrės: https://claude.ai/artifact/5nsvdVvRqLekzJowioS23z (atsisiųsti PPTX ir PDF; PDF privalomas iki 13:00).
Formatas: **3 min. iššūkis ir sprendimas + 2 min. demo + 3 min. klausimai.** Skaidrių neskaitome – jose tik skaičiai ir vaizdai, mes pasakojame.
Skaičiai iš duomenų 2026-10-10. Ryte prieš finalą: `git pull && python3 export_app.py && python3 backtest.py` ir patikrinkite, ar skaičiai nepasikeitė.

| # | Skaidrė | Laikas | Kalba |
|---|---|---|---|
| 1 | Viršelis | 0:00–0:12 | Tautvydas, Tadas |
| 2 | Problema | 0:12–0:30 | Tadas |
| 3 | Skaičiai | 0:30–0:50 | Tautvydas |
| 4 | Atviri duomenys | 0:50–1:02 | Tautvydas |
| 5 | Trys dalykai | 1:02–1:15 | Tadas |
| 6 | Vairuotojui | 1:15–1:30 | Tadas |
| 7 | Užimtumo žemėlapis | 1:30–1:40 | Tadas |
| 8 | Atsakingas elgesys | 1:40–1:55 | Tautvydas |
| 9 | Valdymo skydelis | 1:55–2:03 | Tautvydas |
| 10 | Tikslumas | 2:03–2:18 | Tautvydas |
| 11 | Kuo skiriamės | 2:18–2:30 | Tadas |
| 12 | Demo | 2:30–4:20 | abu |
| 13 | Verslo modelis | 4:20–4:38 | Tadas |
| 14 | Nauda Vilniui | 4:38–4:50 | Tautvydas |
| 15 | Kas toliau | 4:50–4:58 | Tadas |
| 16 | Pabaiga | 4:58–5:00 | abu |
| 17–18 | Priedai | tik klausimams | – |

---

## 1. Viršelis (0:00–0:12)

**Tautvydas:** Aš Tautvydas…
**Tadas:** …o aš Tadas. Kuriame EVFlow – programėlę, kuri parodo, kada užimta įkrovimo stotelė atsilaisvins, ir skatina vairuotojus laiku atlaisvinti vietą.

## 2. Problema (0:12–0:30)

**Tadas:** Turbūt pažįstama situacija: atvažiuoji prie stotelės, o ji užimta. Nors automobilis jau seniai pasikrovęs ir tiesiog stovi. Programėlės parodo tik „užimta“ – ir viskas. Nežinai, kiek teks laukti, ar ši stotelė apskritai dažnai būna pilna, ar verta važiuoti kitur.

## 3. Skaičiai (0:30–0:50)

**Tautvydas:** Mes tai suskaičiavome. Vilniuje beveik kas trečias įkrovimas trunka ilgiau, nei automobiliui reikia pasikrauti. Dėl to kasdien susidaro apie trys šimtai devyniasdešimt valandų, kai visa stotelė užimta ir kitas vairuotojas negali krauti. Visi operatoriai kartu dėl to per metus neparduoda elektros už iki aštuonių šimtų tūkstančių eurų.

## 4. Atviri duomenys (0:50–1:02)

**Tautvydas:** Viskas iš atvirų Via Lietuva duomenų. Nuo spalio šeštosios kas porą minučių renkame kiekvienos Lietuvos stotelės būseną: du tūkstančiai stotelių, visi dvidešimt du operatoriai, jau 1,2 milijono įrašų.

## 5. Trys dalykai (1:02–1:15)

**Tadas:** Iš to padarėme tris dalykus: prognozę vairuotojui, motyvaciją elgtis atsakingai ir valdymo skydelį operatoriams bei miestui.

## 6. Vairuotojui (1:15–1:30)

**Tadas:** Vairuotojas vietoj „užimta“ mato, per kiek laiko stotelė greičiausiai atsilaisvins. Paspaudęs stotelę – kuriomis valandomis ji dažniausiai laisva. Žemėlapyje gali atsifiltruoti pigiausią ar greitą krovimą, o prieš ilgesnę kelionę programėlė pasiūlo, kur sustoti pasikrauti.

## 7. Užimtumo žemėlapis (1:30–1:40)

**Tadas:** Štai Vilnius šešią vakaro: raudonos stotelės tuo metu dažniausiai pilnos. Vairuotojas renkasi laisvesnę – ir esamos stotelės naudojamos tolygiau.

## 8. Atsakingas elgesys (1:40–1:55)

**Tautvydas:** Kai automobilis turėtų būti pasikrovęs, programėlė primena jį patraukti. Patraukei laiku – gauni taškų prizams ar operatorių krovimo nuolaidoms. Vėluoji – krenta įvertinimas. Tikriname pagal Via Lietuva duomenis, tad apgauti nepavyks. O užstatytą vietą gali nufotografuoti – pranešimas nukeliauja operatoriui.

## 9. Valdymo skydelis (1:55–2:03)

**Tautvydas:** Operatoriai ir miestas mato, kur stotelės užimtos, bet nekrauna, kas neveikia ir kiek elektros neparduodama.

## 10. Tikslumas (2:03–2:18)

**Tautvydas:** Ar galima pasitikėti? Algoritmą apmokėme su ankstesnėmis dienomis ir patikrinome su tuo, kas realiai nutiko kitą dieną – beveik keturiasdešimt tūkstančių prognozių. Kai sakėme, kad stotelė dažniausiai laisva, ji tikrai buvo laisva devyniasdešimt aštuonis procentus laiko. O kai sakome, kad pilnoje stotelėje vieta atsilaisvins iki nurodyto laiko – taip nutinka devyniasdešimt keturiais atvejais iš šimto.

## 11. Kuo skiriamės (2:18–2:30)

**Tadas:** Nuo kitų programėlių skiriamės trimis dalykais. Rodome ne tik ar užimta, bet ir kada atsilaisvins bei kaip dažnai čia pilna. Visi operatoriai vienoje vietoje. Ir ne tik informuojame, bet ir skatiname laiku atlaisvinti vietą. Parodysime gyvai.

## 12. Demo (2:30–4:20)

Telefono ekranas ant projektoriaus. **Atsarginis variantas:** įrašytas demo video tame pačiame kompiuteryje.

**Tadas (programėlė, ~1:10):**
- „Tai veikianti programėlė su šios dienos duomenimis. Žalia – laisva, raudona – užimta, oranžinė – kažkas stovi per ilgai.“
- „Esu prie VILNIUS TECH. Paspaudžiu artimiausią stotelę – ji pilna, bet greičiausiai atsilaisvins po penkiolikos minučių. O grafikas rodo, kad šiuo metu čia dažniausiai užimta.“
- „Man reikia greitai ir pigiai – įsijungiu filtrus ir matau laisvą stotelę netoliese. Važiuoju per programėlę arba Waze.“
- „Atvažiavęs – ‚Kraunu čia‘. Kai būsiu pasikrovęs, gausiu priminimą, o patraukęs laiku – taškų.“

**Tautvydas (pranešimas ir valdymo skydelis, ~0:40):**
- „Jei kas nors užstatė vietą – nufotografuoju, duomenys ir kiti vairuotojai patvirtina, pranešimas keliauja operatoriui.“
- „O tai operatoriaus vaizdas: kas šiuo metu stovi per ilgai, kas neveikia. Ir taisyklių simuliatorius: penkios nemokamos minutės, paskui penkiasdešimt centų už minutę – iškart matai, kiek blokavimo tai panaikintų.“

## 13. Verslo modelis (4:20–4:38)

**Tadas:** Kas moka? Vairuotojams programėlė nemokama. Moka operatoriai – už valdymo skydelį, kaina pagal jungčių skaičių. Jie taip pat gali turėti mūsų programėlę su savo logotipu. Miestas perka licenciją planavimui, o partneriai finansuoja prizus, nes gauna klientų, kurie kraunasi šalia.

## 14. Nauda Vilniui (4:38–4:50)

**Tautvydas:** Vien taisyklė „penkiolika minučių nemokamai po įkrovimo“ Vilniuje atlaisvintų apie du šimtus šešiolika valandų per dieną. Daugiau įkrovimų – be naujų stotelių statybos.

## 15. Kas toliau (4:50–4:58)

**Tadas:** Toliau – pilotas su vienu operatoriumi ir Vilniaus savivaldybe. Tam mums reikia operatoriaus ir savivaldybės kontakto.

## 16. Pabaiga (4:58–5:00)

**Abu:** EVFlow. Atvažiuok, kai bus laisva.

---

## Komisijos klausimai: trumpi atsakymai

Susitarimas: **Tautvydas** – duomenys ir modelis, **Tadas** – verslas ir plėtra. Pirma atsakymas, tada paaiškinimas.

**Kuo skiriatės nuo esamų programėlių?**
Jos rodo tik „laisva / užimta“ savo tinkle. Mes – kada atsilaisvins ir kaip dažnai pilna, visi 22 operatoriai vienoje vietoje, ir skatiname laiku atlaisvinti vietą.

**Kaip žinote, kad automobilis jau nebekrauna?**
Viešas API to neskiria, todėl vertiname pagal laiką: per ilgas = ilgiau, nei net lėtai kraunantis automobilis pasikrautų 20–80 % toje jungtyje, plius 15 min. Su operatoriaus duomenimis (OCPP) tai būtų tikslu – tai mūsų piloto tikslas. (Priedo skaidrė 17.)

**Iš kur duomenys ilgalaikėje perspektyvoje?**
Via Lietuva atviras API – jį renkame nuo spalio 6 d., kas ~2 min., automatiškai. Pilotas su operatoriumi pridėtų tikslią krovimo pabaigą.

**Kas už tai mokės?**
Operatoriai – prenumerata pagal jungčių skaičių; jiems tai daugiau parduotos elektros. Miestas – licencija planavimui. Vairuotojams nemokama.

**Kas demo metu veikė tikrai, o kas maketas?**
Tikrai: duomenų rinkimas, prognozės, programėlė su gyvais duomenimis, filtrai, kelionės planavimas, priminimai ir taškų tikrinimas pagal duomenis, valdymo skydelis, simuliatorius. Maketas: prizų parduotuvė (partneriai pavyzdiniai), operatorių nuolaidos ir pranešimų perdavimas operatoriui.

**Ar prognozės tikslios?**
Taip, patikrinta su kita diena: „dažniausiai laisva“ – 98 % laiko laisva; „atsilaisvins iki nurodyto laiko“ pilnoje stotelėje – 94 %. Istorija dar tik kelios dienos, modelis persimoko kas kelias minutes ir tikslėja.

**Iš kur 800 tūkst. €?**
Viršutinė riba, visi operatoriai kartu, Vilniuje: blokuotos valandos × tipinė jungties galia × stotelės tarifas. Dalis vairuotojų būtų nuvažiavę kitur.

**Kokia nauda miestui?**
Daugiau įkrovimų be naujų stotelių: 15 min. taisyklė ≈ 216 val. per dieną. Plius matyti, kur vakarais trūksta stotelių, ir galima išbandyti taisykles prieš jas įvedant.

**O jei kabelis ištrauktas, bet automobilis stovi?**
Stotelė tada rodo „laisva“ – tai pagauna vairuotojų pranešimai su nuotrauka. (Priedo skaidrė 18.)

**Asmens duomenys nuotraukose?**
Pranešimas keliauja tik operatoriui, kitiems vairuotojams numerio nerodome; prieš paleidimą pridėsime automatinį numerio paslėpimą.

**Plėtra?**
Visa Lietuva jau duomenyse; tas pats metodas tinka bet kuriai šaliai, kur operatoriai teikia OCPI duomenis.

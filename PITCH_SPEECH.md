# EVFlow pre-pitch: tekstas (Tautvydas ir Tadas)

Skaičiai iš duomenų 2026-10-10. Prieš įrašant patikrinkite: `python3 export_app.py && python3 backtest.py` ir dashboard'as.

## 1 dalis. Idėja (0:00–3:00)

**0:00 – Tautvydas:**
Aš Tautvydas…

**0:02 – Tadas:**
…o aš Tadas. Kuriame EVFlow – programėlę, kuri elektromobilių vairuotojams parodo, kada užimta įkrovimo stotelė atsilaisvins.

**0:10 – Tautvydas:**
Nuo spalio šeštosios kas porą minučių renkame kiekvienos viešos įkrovimo stotelės Lietuvoje būseną iš atvirų Via Lietuva duomenų.

**0:16 – Tautvydas:**
Tai du tūkstančiai stotelių, šeši tūkstančiai keturi šimtai jungčių ir visi dvidešimt du operatoriai. Jau turime daugiau nei milijoną įrašų.

**0:24 – Tadas:**
Kokia problema? Šiandien įkrovimo programėlės parodo tik tai, ar stotelė dabar laisva, ar užimta.

**0:30 – Tadas:**
Bet kol nuvažiuoji, situacija pasikeičia. Ir nežinai, ar verta laukti, ar važiuoti kitur.

**0:36 – Pauzė, muzikos akcentas.**

**0:38 – Tautvydas:**
O atvažiavęs dažnai randi vieną iš trijų dalykų. Automobilį, kuris jau pasikrovė, bet niekas jo nepatraukė. Pilną stotelę. Arba neveikiantį kroviklį.

**0:50 – Tautvydas:**
Mes tai suskaičiavome. Vilniuje beveik kas trečias įkrovimas trunka ilgiau, nei automobiliui reikia pasikrauti.

**0:57 – Tautvydas:**
Dėl to kasdien susidaro apie trys šimtai devyniasdešimt valandų, kai visos stotelės vietos užimtos ir kitas vairuotojas negali pasikrauti.

**1:05 – Tautvydas:**
Operatoriai dėl to per metus neparduoda elektros už iki aštuonių šimtų tūkstančių eurų. Vien Vilniuje.

**1:12 – Tadas:**
Ką darome mes? Trys dalykai.

**1:15 – Tadas:**
Pirma. Prie kiekvienos užimtos stotelės rodome, per kiek laiko ji greičiausiai atsilaisvins. Ir rekomenduojame, kur važiuoti, kad pradėtum krauti greičiausiai: skaičiuojame kelionės laiką ir laukimą kartu.

**1:28 – Tadas:**
Prieš ilgesnę kelionę, pavyzdžiui, į Klaipėdą, programėlė pasiūlo, kiek kartų sustoti ir kuriose stotelėse.

**1:35 – Tadas:**
Antra. Kai automobilis turėtų būti pasikrovęs, programėlė primena jį patraukti. Patraukei laiku – gauni taškų, kuriuos gali iškeisti į partnerių prizus ar operatorių krovimo nuolaidas. O jei kas nors užstatė vietą, apie tai gali pranešti su nuotrauka.

**1:48 – Tadas:**
Trečia. Operatoriams ir miestui – valdymo skydelis: kur stotelės užblokuotos, kurios neveikia ir kiek pinigų dėl to prarandama.

**1:56 – Tautvydas:**
Nuo kitų programėlių skiriamės trimis dalykais. Rodome ne tik ar stotelė užimta, bet ir kada ji atsilaisvins. Vienoje programėlėje yra visi operatoriai. Ir mes ne tik informuojame, bet ir skatiname vairuotojus laiku atlaisvinti vietą.

**2:08 – Tautvydas:**
Ar prognozės tikslios? Patikrinome. Modelį apmokėme su ankstesnių dienų duomenimis ir palyginome su tuo, kas iš tikrųjų nutiko kitą dieną. Beveik keturiasdešimt tūkstančių prognozių.

**2:18 – Tautvydas:**
Kai programėlė sako, kad vieta greičiausiai atsilaisvins per penkiolika minučių, o vėliausiai – per keturiasdešimt, devyniais atvejais iš dešimties ji iš tikrųjų atsilaisvina per tas keturiasdešimt minučių.

**2:28 – Tadas:**
Kas moka? Vairuotojams programėlė nemokama.

**2:31 – Tadas:**
Moka operatoriai – tokie kaip Ignitis, Eldrive ar Enefit. Jie perka valdymo skydelį, kuris parodo, kur jie praranda pardavimus ir kurias stoteles reikia taisyti. Kaina priklauso nuo jungčių skaičiaus. Mažiau užblokuotų stotelių – daugiau parduotos elektros.

**2:44 – Tadas:**
Miestas gauna duomenis, kur trūksta stotelių, ir gali pasitikrinti, ką pakeistų nauja taisyklė, dar prieš ją įvesdamas.

**2:51 – Tadas:**
Operatoriai taip pat gali naudoti mūsų programėlę su savo logotipu.

**2:55 – Abu:**
Mažiau laukimo. Daugiau įkrovimų.

## 2 dalis. Demonstracija (3:00–5:00)

**3:00 – Tadas:**
Tai veikianti EVFlow programėlė su šios dienos duomenimis. Kiekvienas taškas yra tikra stotelė. Žalia – laisva, raudona – užimta, oranžinė – kažkas stovi ilgiau, nei reikia. Neveikiančių stotelių nerodome.

**3:12 – Tadas:**
Esu prie VILNIUS TECH. Programėlė rekomenduoja ne artimiausią stotelę, o tą, kurioje pradėsiu krauti greičiausiai.

**3:20 – Tadas:**
Štai ši stotelė dabar pilna. Programėlė rodo: greičiausiai atsilaisvins po penkiolikos minučių, vėliausiai – po keturiasdešimties. Ir kad šiuo paros metu čia dažniausiai būna užimta.

**3:34 – Tadas:**
Todėl renkuosi kitą stotelę, kuri laisva dabar. Važiuoju su programėlės navigacija arba atsidarau maršrutą Waze ar Google Maps.

**3:42 – Tadas:**
Jei važiuočiau toliau, pasirinkčiau kryptį ir išvykimo laiką, o programėlė parodytų, kur sustoti pasikrauti.

**3:50 – Tautvydas:**
Atvažiavęs paspaudžiu „Kraunu čia“. Kai turėčiau būti pasikrovęs, gaunu priminimą. Patraukiu automobilį laiku ir gaunu taškų. Ar tikrai patraukiau, tikriname pagal Via Lietuva duomenis, todėl apgauti nepavyks.

**4:02 – Tautvydas:**
Taškus galima iškeisti į partnerių prizus ar operatorių krovimo nuolaidas.

**4:08 – Tautvydas:**
Jei kas nors užstatė vietą, nufotografuoju. Pažeidimą patvirtina mūsų duomenys ir kiti vairuotojai, o pranešimas nukeliauja operatoriui.

**4:16 – Tautvydas:**
O tai operatoriaus valdymo skydelis – tai, ką parduodame. Operatorius mato, kur jo stotelės užblokuotos, kurios neveikia ir kiek elektros jis neparduoda.

**4:24 – Tautvydas:**
Čia jis gali išbandyti taisyklę, pavyzdžiui: penkios nemokamos minutės po įkrovimo, paskui penkiasdešimt centų už minutę. Ir iškart mato, kiek valandų blokavimo tai panaikintų.

**4:34 – Tadas:**
Tą pačią programėlę operatorius gali turėti su savo spalvomis ir logotipu. O vairuotojų prizus finansuoja partneriai.

**4:42 – Muzika, EVFlow logotipas.**

**4:46 – Abu:**
EVFlow. Atvažiuok, kai bus laisva.

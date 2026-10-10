# EVFlow pre-pitch: tekstas (Tautvydas ir Tadas)

Iššūkis: kaip užtikrinti, kad įkrovimo stotelės būtų naudojamos efektyviai ir atsakingai (stotelės užimtos, bet neaktyvios; neefektyvaus naudojimo atpažinimas, atsakinga elgsena, pranešimai apie piktnaudžiavimą, taškai, nuolaidos, įvertinimas).
Skaičiai iš duomenų 2026-10-10. Prieš įrašant patikrinkite: `python3 export_app.py && python3 backtest.py` ir dashboard'as.

## 1 dalis. Idėja (0:00–3:00)

**0:00 – Tautvydas:**
Aš Tautvydas…

**0:02 – Tadas:**
…o aš Tadas. Kuriame EVFlow – programėlę, kuri elektromobilių vairuotojams parodo, kada užimta įkrovimo stotelė atsilaisvins, ir skatina vairuotojus laiku atlaisvinti vietą.

**0:10 – Tautvydas:**
Nuo spalio šeštosios kas porą minučių renkame kiekvienos viešos įkrovimo stotelės Lietuvoje būseną iš atvirų Via Lietuva duomenų.

**0:16 – Tautvydas:**
Tai du tūkstančiai stotelių, šeši tūkstančiai keturi šimtai jungčių ir visi dvidešimt du operatoriai. Jau turime daugiau nei milijoną įrašų.

**0:24 – Tadas:**
Kokia problema? Atvažiuoji prie stotelės, o ji užimta – nors automobilis jau seniai pasikrovęs ir tiesiog stovi.

**0:30 – Tadas:**
Programėlės parodo tik „laisva“ arba „užimta“. Bet neparodo, kiek teks laukti ir ar ši stotelė apskritai dažnai būna užimta. Todėl nežinai, ar laukti, ar važiuoti kitur.

**0:38 – Pauzė, muzikos akcentas.**

**0:40 – Tautvydas:**
Stotelė užimta, bet nekrauna – tai neefektyvus naudojimas. Prie to dar pridėkime pilnas stoteles ir neveikiančius kroviklius.

**0:50 – Tautvydas:**
Mes tai suskaičiavome. Vilniuje beveik kas trečias įkrovimas trunka ilgiau, nei automobiliui reikia pasikrauti.

**0:57 – Tautvydas:**
Dėl to kasdien susidaro apie trys šimtai devyniasdešimt valandų, kai visos stotelės vietos užimtos ir kitas vairuotojas negali pasikrauti.

**1:05 – Tautvydas:**
Operatoriai dėl to per metus neparduoda elektros už iki aštuonių šimtų tūkstančių eurų. Vien Vilniuje.

**1:12 – Tadas:**
Ką darome mes? Trys dalykai.

**1:15 – Tadas:**
Pirma – vairuotojui. Prie kiekvienos užimtos stotelės rodome, per kiek laiko ji greičiausiai atsilaisvins. Paspaudęs stotelę matai, kuriomis valandomis ji dažniausiai užimta, o kuriomis laisva. Taip vairuotojai renkasi mažiau apkrautas stoteles, ir esamos stotelės naudojamos efektyviau.

**1:30 – Tadas:**
Žemėlapyje galima iškart atsifiltruoti, ko reikia: pigiausią krovimą, greitąjį krovimą ar tik laisvas stoteles. O prieš ilgesnę kelionę, pavyzdžiui, į Klaipėdą, programėlė pasiūlo, kur sustoti pasikrauti.

**1:40 – Tadas:**
Antra – atsakingas elgesys. Kai automobilis turėtų būti pasikrovęs, programėlė primena jį patraukti. Patraukei laiku – gauni taškų, kuriuos gali iškeisti į partnerių prizus ar operatorių krovimo nuolaidas. Vėluoji – krenta tavo įvertinimas. O jei kas nors užstatė vietą, gali pranešti su nuotrauka, ir pranešimas nukeliauja operatoriui.

**1:52 – Tadas:**
Trečia – operatoriams ir miestui. Valdymo skydelis parodo, kur stotelės užimtos, bet nekrauna, kurios neveikia ir kiek pinigų dėl to prarandama.

**1:58 – Tautvydas:**
Nuo kitų programėlių skiriamės trimis dalykais. Rodome ne tik ar stotelė užimta, bet ir kada ji atsilaisvins, ir kaip dažnai ji būna užimta. Vienoje programėlėje yra visi operatoriai. Ir mes ne tik informuojame, bet ir skatiname laiku atlaisvinti vietą: taškai, nuolaidos, įvertinimas ir pranešimai.

**2:10 – Tautvydas:**
Ar galima tuo pasitikėti? Patikrinome. EVFlow algoritmą apmokėme su ankstesnių dienų duomenimis, o jo prognozes palyginome su tuo, kas realiai nutiko kitą dieną. Beveik keturiasdešimt tūkstančių prognozių.

**2:18 – Tautvydas:** *(ekrane: `pitch_accuracy.png` ir `backtest.png`)*
Kai EVFlow sakė, kad stotelė tuo metu dažniausiai laisva, ji iš tikrųjų buvo laisva devyniasdešimt aštuonis procentus laiko. Kai sakė, kad yra septyniasdešimt procentų tikimybė vietai atsilaisvinti per pusvalandį, realybėje atsilaisvino lygiai septyniasdešimt procentų. Mūsų prognozės sutampa su realybe.

**2:28 – Tadas:**
Kas moka? Vairuotojams programėlė nemokama.

**2:31 – Tadas:**
Moka operatoriai – tokie kaip Ignitis, Eldrive ar Enefit. Jie perka valdymo skydelį, kuris parodo, kur jie praranda pardavimus ir kurias stoteles reikia taisyti. Kaina priklauso nuo jungčių skaičiaus. Mažiau užblokuotų stotelių – daugiau parduotos elektros.

**2:44 – Tadas:**
Miestas gauna duomenis, kur stotelės dažniausiai perpildytos ir kur jų trūksta, ir gali pasitikrinti, ką pakeistų nauja taisyklė, dar prieš ją įvesdamas.

**2:51 – Tadas:**
Operatoriai taip pat gali naudoti mūsų programėlę su savo logotipu.

**2:55 – Abu:**
Mažiau laukimo. Daugiau įkrovimų.

## 2 dalis. Demonstracija (3:00–5:00)

**3:00 – Tadas:**
Tai veikianti EVFlow programėlė su šios dienos duomenimis. Kiekvienas taškas yra tikra stotelė. Žalia – laisva, raudona – užimta, oranžinė – kažkas stovi ilgiau, nei reikia. Neveikiančių stotelių nerodome.

**3:12 – Tadas:**
Esu prie VILNIUS TECH ir man reikia pasikrauti kuo greičiau ir pigiau.

**3:16 – Tadas:**
Paspaudžiu artimiausią stotelę. Ji dabar pilna, bet matau, kad greičiausiai atsilaisvins po penkiolikos minučių.

**3:24 – Tadas:**
O užimtumo grafikas parodo, kada čia būna laisva: ryte dažniausiai laisva, o vakare beveik visada pilna. Tai jei čia atvažiuočiau vakare, žinočiau, kad geriau rinktis kitą stotelę.

**3:34 – Tadas:**
Bet man reikia dabar. Įsijungiu filtrus „greitas krovimas“ ir „pigiausias“ – ir iškart matau laisvą stotelę netoliese. Spaudžiu ją ir važiuoju su programėlės navigacija arba per Waze ar Google Maps.

**3:42 – Tadas:**
Jei važiuočiau toliau, pasirinkčiau kryptį ir išvykimo laiką, o programėlė parodytų, kur sustoti pasikrauti.

**3:50 – Tautvydas:**
Atvažiavęs paspaudžiu „Kraunu čia“. Kai turėčiau būti pasikrovęs, gaunu priminimą. Patraukiu automobilį laiku ir gaunu taškų, o vėluojant krenta įvertinimas. Ar tikrai patraukiau, tikriname pagal Via Lietuva duomenis, todėl apgauti nepavyks.

**4:02 – Tautvydas:**
Taškus galima iškeisti į partnerių prizus ar operatorių krovimo nuolaidas.

**4:08 – Tautvydas:**
Jei kas nors užstatė vietą, nufotografuoju. Pažeidimą patvirtina mūsų duomenys ir kiti vairuotojai, o pranešimas nukeliauja operatoriui.

**4:16 – Tautvydas:**
O tai operatoriaus valdymo skydelis – tai, ką parduodame. Operatorius mato, kur jo stotelės užimtos, bet nekrauna, kurios neveikia ir kiek elektros jis neparduoda.

**4:24 – Tautvydas:**
Čia jis gali išbandyti taisyklę, pavyzdžiui: penkios nemokamos minutės po įkrovimo, paskui penkiasdešimt centų už minutę. Ir iškart mato, kiek valandų blokavimo tai panaikintų.

**4:34 – Tadas:**
Tą pačią programėlę operatorius gali turėti su savo spalvomis ir logotipu. O vairuotojų prizus finansuoja partneriai.

**4:42 – Muzika, EVFlow logotipas.**

**4:46 – Abu:**
EVFlow. Atvažiuok, kai bus laisva.

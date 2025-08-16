//
//  PrayerTemplates.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 15/08/2025.
//

import Foundation
import SwiftUI

var prayersTemplate : [String:Prayer] = [
    "Ojcze Nasz":
    Prayer(name: "Ojcze Nasz", text: """
           Ojcze nasz,
           któryś jest w niebie:
           święć się imię Twoje,
           przyjdź Królestwo Twoje,
           bądź wola Twoja jako w niebie,
           tak i na ziemi.
           Chleba naszego powszedniego
           daj nam dzisiaj.
           I odpuść nam nasze winy,
           jako i my odpuszczamy naszym winowajcom.
           I nie wódź nas na pokuszenie,
           ale nas zbaw od złego.
           Amen.
           """, symbol: "heart", audioFilename: nil, audioSource: nil, timestampedLines: nil),
     "Zdrowaś Mario":
        Prayer(name: "Zdrowaś Mario", text: """
           Zdrowaś Maryjo,
           łaski pełna, Pan z Tobą,
           błogosławionaś Ty między niewiastami
           i błogosławiony owoc żywota Twojego, Jezus.
           Święta Maryjo, Matko Boża,
           módl się za nami grzesznymi
           teraz i w godzinę śmierci naszej.
           Amen.
           """, symbol: "star", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Chwała Ojcu":
        Prayer(name: "Chwała Ojcu", text: """
           Chwała Ojcu i Synowi i Duchowi Świętemu, jak była na początku, teraz i zawsze i na wieki wieków.
           Amen.
           """, symbol: "flame", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "O mój Jezu":
    Prayer(name: "O mój Jezu", text: """
       O mój Jezu, przebacz nam nasze grzechy, zachowaj nas od ognia piekielnego. Zaprowadź wszystkie dusze do nieba i dopomóż szczególnie tym, którzy najbardziej potrzebują Twojego miłosierdzia
       """, symbol: "cloud", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Pod Twoją obronę":
        Prayer(name: "Pod Twoją obronę", text: """
       Pod Twoją obronę uciekamy się, święta Boża Rodzicielko, naszymi prośbami racz nie gardzić w potrzebach naszych, ale od wszelakich złych przygód racz nas zawsze wybawiać. Panno chwalebna i błogosławiona. O Pani nasza, Orędowniczko nasza, Pośredniczko nasza, Pocieszycielko nasza. Z Synem swoim nas pojednaj, Synowi swojemu nas polecaj, swojemu Synowi nas oddawaj. Amen.
       """, symbol: "star.bubble", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Ojcze Przedwieczny":
    Prayer(name: "Ojcze Przedwieczny", text: """
       Ojcze Przedwieczny, ofiaruję Ci Ciało i Krew, Duszę i Bóstwo najmilszego Syna Twojego, a Pana naszego Jezusa Chrystusa, na przebłaganie za grzechy nasze i całego świata.
       """, symbol: "globe.europe.africa", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Dla Jego bolesnej męk":
    Prayer(name: "Dla Jego bolesnej męk", text: """
       Dla Jego bolesnej męki, miej miłosierdzie dla nas i całego świata.
       """, symbol: "cross", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Święty Boże":
    Prayer(name: "Święty Boże", text: """
       Święty Boże, Święty Mocny, Święty Nieśmiertelny, zmiłuj się nad nami i nad całym światem.
       """, symbol: "star", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Aniele Boży, Stróżu mój":
    Prayer(name: "Aniele Boży, Stróżu mój", text: """
           Aniele Boży Stróżu mój, Ty zawsze przy mnie stój.
           Rano, wieczór, we dnie, w nocy, bądź mi zawsze do pomocy.
           Broń mnie od wszystkiego złego i doprowadź do Żywota wiecznego. 
           Amen.
           """, symbol: "moon.stars", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Skład apostolski (Wyznanie wiary)":
        Prayer(name: "Skład apostolski (Wyznanie wiary)", text: """
           Wierzę w Boga Ojca wszechmogącego, Stworzyciela nieba i ziemi, i w Jezusa Chrystusa, Syna Jego Jedynego, Pana naszego, który się począł z Ducha Świętego, narodził się z Maryi Panny, umęczon pod Ponckim Piłatem, ukrzyżowan, umarł i pogrzebion, zstąpił do piekieł, trzeciego dnia zmartwychwstał, wstąpił na niebiosa, siedzi po prawicy Boga Ojca wszechmogącego, stamtąd przyjdzie sądzić żywych i umarłych.
           Wierzę w Ducha Świętego, święty Kościół powszechny, świętych obcowanie, grzechów odpuszczenie, ciała zmartwychwstanie, żywot wieczny. Amen.
           """, symbol: "book", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Duchu Święty, który oświecasz":
        Prayer(name: "Duchu Święty, który oświecasz", text: """
           Duchu Święty, który oświecasz serca i umysły nasze, dodaj nam zdolności i ochoty, aby ta nauka była dla nas pożytkiem doczesnym i wiecznym. Przez Chrystusa Pana naszego. Amen.
           """, symbol: "bird", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Modlitwa Apostolatu Margaretka":
        Prayer(name: "Modlitwa Apostolatu Margaretka", text: """
           O Jezu Boski Pasterzu, który powołałeś Apostołów, aby uczynić ich rybakami dusz ludzkich, Ty, który pociągnąłeś ku Sobie ks. … uczyń go Swoim gorliwym naśladowcą i sługą. Spraw, aby dzielił z Tobą pragnienie powszechnego zbawienia, dla którego na wszystkich ołtarzach uobecniasz Swoją Ofiarę. Ty o Panie, który żyjesz na wieki, aby wstawiać się za Twoim ludem, otwórz przed nim nowe horyzonty, by dostrzegał świat spragniony światła prawdy i miłości; by był solą ziemi i światłością świata. Umacniaj go Twoją mocą i błogosław mu. Święty Janie Pawle II, Patronie Apostolatu, Twojej szczególnej opiece go dzisiaj polecam. Proszę Cię, abyś wstawiał się za nim przed Bogiem i pomagał mu we wszystkich potrzebach, aby dochował Bogu wierności i owocnie pracował dla Jego większej chwały. Maryjo Matko Kościoła strzeż go przed wszelkim złem. Amen.
           """, symbol: "tree", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    
    "Modlitwa do Ducha Świętego dla kapłanów": Prayer(name: "Modlitwa do Ducha Świętego dla kapłanów", text: """
        Duchu Święty, Duchu Mądrości, prowadź kapłanów;
        Duchu Święty, Duchu Światłości, oświecaj kapłanów;
        Duchu Święty, Duchu Czystości, uświęcaj kapłanów;
        Duchu Święty, Duchu Mocy, wspieraj kapłanów;
        Duchu Święty, Duchu Boży spraw, by kapłani ożywieni
        i umocnieni Twoją łaską, nieśli słowo prawdy
        i błogosławieństwo pokoju na cały świat.
        Niech ogień świętej miłości rozpala ich serca,
        by w płomieniach tej miłości oczyszczali i uświęcali dusze.
        Duchu Święty, powierzamy Ci serca kapłańskie;
        Ukształtuj je na wzór Najświętszych Serc Jezusa i Maryi.
        """, symbol: "bird", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Modlitwa o uświęcenie kapłanów":
        Prayer(name: "Modlitwa o uświęcenie kapłanów", text: """
        Boże Trzykroć Święty, Ty wybierasz i powołujesz ludzi, aby służyli Twojemu ludowi jako jego pasterze. Spójrz na wszystkich kapłanów Kościoła i odnów w nich łaskę Sakramentu Święceń. Niech Duch Święty, którym wówczas zostali napełnieni, ożywia w nich łaskę świętości, aby ich posługiwanie i życie było święte. Niech będą zapatrzeni w Jezusa Chrystusa, Najwyższego Kapłana i Dobrego Pasterza i naśladują Go sercem wspaniałomyślnym, czyniąc ze swojego życia dar dla Ciebie i dla Kościoła.
        Matko Najświętsza, Matko kapłanów, wstawiaj się za nimi u Twojego Syna.
        Do Niego oni należą! Spraw, aby byli święci sercem i ciałem oraz aby byli wierni powołaniu, jakim zostali obdarowani. Umacniaj tych, którzy są słabi i prowadź ich do Chrystusa! Poślij im dobrych aniołów, którzy ich podźwigną ze słabości. Uproś wszystkim głęboką wiarę, niezachwianą nadzieję i doskonałą miłość oraz głębokie poczucie świętości Boga i tego, co Boże. Amen.
        """, symbol: "hands.and.sparkles", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Panie Jezu, wraz ze świętym Janem Marią Vianneyem":
        Prayer(name: "Panie Jezu, wraz ze świętym Janem Marią Vianneyem", text: """
        Panie Jezu, wraz ze świętym Janem Marią Vianneyem powierzamy Ci wszystkich kapłanów, tych, których znamy, których spotkaliśmy, tych, którzy nam pomagali, i których nam dajesz obecnie, jako naszych pasterzy.
        Ty wezwałeś każdego z nich po imieniu. Dziękujemy Ci za nich i prosimy Cię: zachowaj ich w wierności Tobie. Ty, który ich uświęciłeś, aby w Twoim imieniu pełnili dla nas posługę pasterską, daj im siłę, ufność i radość z wypełnianej misji.
        Niech Eucharystia, którą sprawują, umacnia ich i daje im siłę do ofiarowania się Tobie, za nas i za zbawienie świata. Zachowaj ich w Twoim Miłosiernym Sercu, by zawsze byli świadkami Twego przebaczenia, aby wielbili Boga Ojca i uczyli nas prawdziwej drogi do świętości.
        Dobry Ojcze, wraz z nimi ofiarujemy się Chrystusowi dla dobra Kościoła. Niech żywy w nim będzie misyjny zapał dzięki tchnieniu Twojego Ducha. Naucz nas szanować i kochać wszystkich kapłanów oraz przyjmować ich posługę jako dar pochodzący od Ciebie, abyśmy razem z nimi jeszcze lepiej służyli dziełu zbawienia wszystkich ludzi. Amen.
        """, symbol: "hands.and.sparkles", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Panie Jezu, Ty wybrałeś Twoich kapłanów":
        Prayer(name: "Panie Jezu, Ty wybrałeś Twoich kapłanów", text: """
        Panie Jezu, Ty wybrałeś Twoich kapłanów spośród nas i wysłałeś ich, aby głosili Twoje Słowo i działali w Twoje Imię. Za tak wielki dar dla Twego Kościoła przyjmij nasze uwielbienie i dziękczynienie. Prosimy Cię, abyś napełnił ich ogniem Twojej miłości, aby ich kapłaństwo ujawniało Twoją obecność w Kościele. Ponieważ są naczyniami z gliny, modlimy się, aby Twoja moc przenikała ich słabości. Nie pozwól, by w swych utrapieniach zostali zmiażdżeni. Spraw, by w wątpliwościach nigdy nie poddawali się rozpaczy, nie ulegali pokusom, by w prześladowaniach nie czuli się opuszczeni. Natchnij ich w modlitwie, aby codziennie żyli tajemnicą Twojej śmierci i zmartwychwstania. W chwilach słabości poślij im Twojego Ducha. Pomóż im wychwalać Twojego Ojca Niebieskiego i modlić się za grzeszników. Mocą Ducha Świętego włóż Twoje słowo na ich usta i wlej swoją miłość w ich serca, aby nieśli Dobrą Nowinę ubogim, a przygnębionym i zrozpaczonym – uzdrowienie. Niech dar Maryi, Twojej Matki, dla Twojego ucznia, którego umiłowałeś, będzie darem dla każdego kapłana. Spraw, aby Ta, która uformowała Ciebie na swój ludzki wizerunek, uformowała ich na Twoje podobieństwo, mocą Twojego Ducha, na chwałę Boga Ojca. Amen.
        """, symbol: "hands.and.sparkles", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Modlitwa św. Jana XXIII za kapłanów":
        Prayer(name: "Modlitwa św. Jana XXIII za kapłanów", text: """
        O Jezu, Wieczny Kapłanie, który zapaliłeś w świecie płomień nigdy nie gasnący! Dozwól uczestniczyć w niepokojach Twego Boskiego Serca tym, którzy zostali wybrani na pasterzy. Tym duszom szlachetnym, którym udzieliłeś pełni kapłaństwa, daj łaskę przynoszenia Ci zaszczytu w Twym świętym Kościele. Obok nich zaś pomnażaj nieustannie liczbę nowych i żarliwych apostołów Twego Królestwa, dla zbawienia wszystkich narodów.
        O Panie, spraw, aby w pokoju i pracy w niezamąconym ładzie, ludy i narody żyły w pomyślności, z Twym nie mającym granic błogosławieństwem, i aby Kościół Twój stale rozszerzał pomyślnie swoją zbawienną misję. Ocal, Panie, lud Twój i błogosław dziedzictwu Twojemu: rządź nim i prowadź go po wieczne czasy. Amen.
        """, symbol: "hands.and.sparkles", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Modlitwa Pawła VI za kapłanów":
        Prayer(name: "Modlitwa Pawła VI za kapłanów", text: """
        O Panie, daj sługom Twoim serce, które obejmie całe ich wychowanie i przygotowanie. Niech będzie świadome wielkiej nowości, jaka zrodziła się w ich życiu, wyryła się w ich duszy. Serce, które byłoby zdolne do nowych uczuć, jakie Ty polecasz tym, których wybrałeś, by byli sługami Twego Ciała Eucharystycznego i Twego Ciała Mistycznego Kościoła. O Panie, daj im serce czyste, zdolne kochać tylko Ciebie taką pełnią, taką radością, taką głębokością, jakie wyłącznie ty potrafisz ofiarować, kiedy staniesz się wyłącznym, całkowitym przedmiotem ludzkiego serca. Serce czyste, które by nie znało zła, chyba tylko po to, by je rozpoznać, zwalczać i unikać, serce czyste jak dziecka, zdolne do zachwytu i do bojaźni.
        O Panie, daj im serce wielkie, otwarte na Twoje zamysły i zamknięte na wszelkie ciasne ambicje, na wszelkie małostkowe współzawodnictwo międzyludzkie. Serce wielkie, zdolne równać się z Twoim i zdolne pomieścić w sobie rozpiętość Kościoła, rozpiętość światła, zdolne wszystkich kochać, wszystkim służyć, być rzecznikiem wszystkich. Ponadto, o Panie, daj im serce mocne, chętne i gotowe stawić czoła wszelkim trudnościom, wszelkim pokusom, wszelkim słabościom, wszelkiemu znudzeniu, wszelkiemu zmęczeniu, serce potrafiące wytrwale, cierpliwie i bohatersko służyć tajemnicy, którą Ty powierzasz tym synom Twoim, których utożsamiłeś z sobą.
        W końcu, o Panie, serce zdolne do prawdziwej miłości, to znaczy zdolne rozumieć, akceptować, służyć i poświęcać się, zdolne być szczęśliwym, pulsującym Twoimi uczuciami i Twoimi myślami.
        """, symbol: "hands.and.sparkles", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Modlitwa św. Piusa X za kapłanów":
        Prayer(name: "Modlitwa św. Piusa X za kapłanów", text: """
        O Boże, Pasterzu i Nauczycielu wiernych, któryś dla zachowania i rozszerzania Swojego Kościoła ustanowił kapłaństwo i rzekł do Swoich apostołów: „Żniwo jest wielkie, ale robotników mało. Proście tedy Pana żniwa, by wysłał robotników na żniwo Swoje”.
        Oto, przystępujemy do Ciebie z gorącym pragnieniem i błagamy Cię usilnie: racz wysłać robotników na żniwo Swoje, wyślij godnych kapłanów do świętego Swojego Kościoła. Daj, Panie, aby wszyscy, których od wieków do Swej świętej służby wezwałeś, głosu Twego chętnie słuchali i z całego serca za nim postępowali; strzeż ich od niebezpieczeństw świata, udziel im ducha mądrości i rozumu, ducha rady i mocy, ducha wiedzy i pobożności i napełnij ich duchem Swej świętej bojaźni, ażeby łaską kapłaństwa obdarzeni, słowem i przykładem nauczali nas, postępować drogą przykazań Twoich i doprowadzili nas do wiecznie błogiego połączenia się z Tobą.
        Który żyjesz i królujesz na wieki wieków. Amen.
        """, symbol: "hands.and.sparkles", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Modlitwa św. Jana Pawła II za kapłanów":
        Prayer(name: "Modlitwa św. Jana Pawła II za kapłanów", text: """
        Panie, Ty pragnąłeś zbawić ludzi i dlatego założyłeś Kościół jako wspólnotę braci zjednoczonych w Twojej miłości. Nie przestawaj nawiedzać nas i powoływać tych, których wybrałeś, aby byli głosem Twojego Ducha Świętego, zaczynem społeczeństwa bardziej sprawiedliwego i braterskiego. Wyjednaj nam u niebieskiego Ojca duchowych przewodników, których potrzebują nasze wspólnoty: prawdziwych kapłanów żywego Boga, którzy oświeceni Twoim słowem, będą umieli mówić o Tobie i uczyć innych, jak rozmawiać z Tobą.
        Pozwól wzrastać swojemu Kościołowi, mnożąc w nim osoby konsekrowane, które powierzają wszystko Tobie, abyś Ty mógł wszystkich zbawić. Niech nasze wspólnoty sprawują ze śpiewem i uwielbieniem Eucharystię jako ofiarę dziękczynienia za Twoją chwałę i dobroć, niech wychodzą na drogi świata, aby głosić radość i pokój – cenne dary Twojego zbawienia.
        Spójrz, o Panie, na całą ludzkość i okaż miłosierdzie tym, którzy szukają Cię przez modlitwę i prawe życie, ale jeszcze Cię nie spotkali: objaw się im jako Droga, która prowadzi do Ojca, jako Prawda, która wyzwala, jako Życie, które nie ma końca. Pozwól nam, Panie, żyć w Twoim Kościele w duchu wiernej służby i całkowitego poświęcenia, aby nasze świadectwo było wiarygodne i owocne. Amen.
        """, symbol: "hands.and.sparkles", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Modlitwa św. Urszuli Ledóchowskiej za kapłanów":
        Prayer(name: "Modlitwa św. Urszuli Ledóchowskiej za kapłanów", text: """
        O Jezu, Odwieczny Arcykapłanie, Boski Ofiarniku, który w niezrównanym porywie miłości dla ludzi, Twych braci, sprawiłeś, że chrześcijańskie kapłaństwo wytrysnęło z Boskiego Serca Twego, nie przestawaj wlewać w Twych kapłanów ożywczych strumieni Twej nieskończonej miłości.
        Żyj w nich, o Panie, przeistaczaj ich w siebie, uczyń ich mocą łaski swojej narzędziami swego miłosierdzia. Działaj w nich i przez nich i spraw, by przyoblekłszy się zupełnie w Ciebie przez wierne naśladowanie Twych godnych uwielbienia cnót, wykonywali mocą Twego imienia i Twego ducha uczynki, któreś sam zdziałał dla zbawienia świata.
        Boski Odkupicielu dusz, spojrzyj, jak wielu jest jeszcze pogrążonych w ciemnościach błędu. Policz owieczki zbłąkane, krążące nad przepaścią, wejrzyj na tłumy ubogich, głodnych, nieświadomych i słabych, jęczących w opuszczeniu. Wracaj do nas, o Jezu, przez Twych kapłanów. Ożyj w nich rzeczywiście, działaj przez nich i przejdź znowu przez świat ucząc, przebaczając, pocieszając, poświęcając się i nawiązując na nowo święte więzy miłości łączące Serce Boże z sercem człowieczym. Amen
        """, symbol: "hands.and.sparkles", audioFilename: nil, audioSource: nil, timestampedLines: nil),
]

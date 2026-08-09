//
//  PrayerTemplates.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 15/08/2025.
//

import Foundation
import SwiftUI

private let templatePrayerIds: [String: UUID] = [
    "Ojcze Nasz": UUID(uuidString: "bf79f12e-0ccd-4ff6-93cc-d80a051d139a")!,
    "Our Father": UUID(uuidString: "f9c43a2d-762e-4a3a-b100-a93e8f292dd7")!,
    "Hail Mary (EN)": UUID(uuidString: "b5b7d9cc-8f02-4c4e-a2d0-1e2a3b4c5d6e")!,
    "Glory Be (EN)": UUID(uuidString: "c6c8eadd-9f13-4d5f-b3e1-2f3a4b5c6d7e")!,
    "O My Jesus (EN)": UUID(uuidString: "d7d9fbee-af24-4e6f-c4f2-3a4b5c6d7e8f")!,
    "Apostles' Creed (EN)": UUID(uuidString: "e8ea0cff-b035-4f70-d503-4b5c6d7e8f90")!,
    "Pater Noster (LA)": UUID(uuidString: "f9011d00-c146-4f81-e614-5c6d7e8f9012")!,
    "Ave Maria (LA)": UUID(uuidString: "0a122e11-d257-4f92-f725-6d7e8f901234")!,
    "Gloria Patri (LA)": UUID(uuidString: "1b233f22-e368-4fa3-0836-7e8f90123456")!,
    "Symbolum Apostolicum (LA)": UUID(uuidString: "2c344033-f479-4fb4-1947-8f9012345678")!,
    "O Iesu (LA)": UUID(uuidString: "3d455144-058a-4fc5-2a58-90123456789a")!,
    "Eternal Father (EN)": UUID(uuidString: "4e566255-169b-4fd6-3b69-a0123456789b")!,
    "Sorrowful Passion (EN)": UUID(uuidString: "5f677366-27ac-4fe7-4c7a-b123456789ac")!,
    "Holy God (EN)": UUID(uuidString: "60788477-38bd-4ff8-5d8b-c23456789abd")!,
    "Zdrowaś Mario": UUID(uuidString: "965670c5-cd79-4cde-8cb6-8bfda47ae6cf")!,
    "Chwała Ojcu": UUID(uuidString: "7b134385-e206-4101-9cc8-7be53cdc72ae")!,
    "O mój Jezu": UUID(uuidString: "7631b14f-60ee-408f-a62c-ab8b33e13405")!,
    "Pod Twoją obronę": UUID(uuidString: "426b3e5b-db1f-4fbd-ada7-e10a631dddde")!,
    "Ojcze Przedwieczny": UUID(uuidString: "587e5254-2e56-41a6-88d5-089c8ff07a1a")!,
    "Dla Jego bolesnej męk": UUID(uuidString: "cb80dc86-25ec-4bb4-8bf3-b79a628beb9f")!,
    "Święty Boże": UUID(uuidString: "78475327-cca7-4e65-9afc-3d51c60923da")!,
    "Aniele Boży, Stróżu mój": UUID(uuidString: "f783e072-c7d8-4c42-87ed-1244f32fd5ac")!,
    "Skład apostolski (Wyznanie wiary)": UUID(uuidString: "40f9dceb-edc2-4442-af34-88d32b041784")!,
    "Duchu Święty, który oświecasz": UUID(uuidString: "d071dd8d-a50e-4ab4-a850-99f8130b59ea")!,
    "Modlitwa Apostolatu Margaretka": UUID(uuidString: "28e8784e-c771-4ddf-a507-a168b495412e")!,
    "Modlitwa do Ducha Świętego dla kapłanów": UUID(uuidString: "aa7aec31-99f4-4ecc-a7bf-3b72059f7ced")!,
    "Modlitwa o uświęcenie kapłanów": UUID(uuidString: "a029559b-d9c5-46d8-acf7-3c3d2ab10522")!,
    "Panie Jezu, wraz ze świętym Janem Marią Vianneyem": UUID(uuidString: "3d150087-4518-40d8-a398-f1b5b0ad17e4")!,
    "Panie Jezu, Ty wybrałeś Twoich kapłanów": UUID(uuidString: "1c9f70c8-d18e-4cd4-81a9-7ebf2617eec9")!,
    "Modlitwa św. Jana XXIII za kapłanów": UUID(uuidString: "0e26283f-c192-451f-8b2f-c7970f6fb0ae")!,
    "Modlitwa Pawła VI za kapłanów": UUID(uuidString: "2a94d795-bf82-4320-937b-33aefce4a541")!,
    "Modlitwa św. Piusa X za kapłanów": UUID(uuidString: "6eb9e98e-3036-4019-8977-620738eba535")!,
    "Modlitwa św. Jana Pawła II za kapłanów": UUID(uuidString: "a9f0fcee-1734-4945-ba1b-6ee5b0abb57a")!,
    "Modlitwa św. Urszuli Ledóchowskiej za kapłanów": UUID(uuidString: "2e38befb-046b-49d6-afcd-621bee8cf5db")!,
    "Msza (Brewiarz)": UUID(uuidString: "927a98de-7ae4-4f93-b173-b040318de111")!,
    "Wezwanie (Brewiarz)": UUID(uuidString: "5bb86df2-6625-4e5e-9afb-ad66a662df9c")!,
    "Godzina Czytań (Brewiarz)": UUID(uuidString: "92ca4c07-c16c-4053-825f-e67939bc7f98")!,
    "Jutrznia (Brewiarz)": UUID(uuidString: "c828488b-85ad-4b80-ae01-97c105ad802a")!,
    "Modlitwa przedpołudniowa (Brewiarz)": UUID(uuidString: "d7f19135-7186-4462-be63-f7c1a43c596f")!,
    "Modlitwa południowa (Brewiarz)": UUID(uuidString: "5ba99cbf-2f0b-4ace-8986-9c83027e1515")!,
    "Modlitwa popołudniowa (Brewiarz)": UUID(uuidString: "c7f26387-2e8f-472f-aac6-eb2534292540")!,
    "Nieszpory (Brewiarz)": UUID(uuidString: "5ea91147-c605-47e2-8c43-f1813ba9c1a3")!,
    "Kompleta (Brewiarz)": UUID(uuidString: "3e5f93dd-c1f7-46d7-85a4-5d62265329c4")!,
    "Święty dnia (Brewiarz)": UUID(uuidString: "d62e0768-24c7-4ba8-ac3c-e7122365c9f1")!
]

var prayersTemplate : [String:Prayer] = [
    "Eternal Father (EN)": Prayer(id: templatePrayerIds["Eternal Father (EN)"]!, name: "Eternal Father", text: "Eternal Father, I offer you the Body and Blood, Soul and Divinity of your dearly beloved Son, our Lord Jesus Christ, in atonement for our sins and those of the whole world.", symbol: "globe.europe.africa", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Sorrowful Passion (EN)": Prayer(id: templatePrayerIds["Sorrowful Passion (EN)"]!, name: "For the sake of His sorrowful Passion", text: "For the sake of His sorrowful Passion, have mercy on us and on the whole world.", symbol: "cross", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Holy God (EN)": Prayer(id: templatePrayerIds["Holy God (EN)"]!, name: "Holy God", text: "Holy God, Holy Mighty One, Holy Immortal One, have mercy on us and on the whole world.", symbol: "star", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Symbolum Apostolicum (LA)": Prayer(id: templatePrayerIds["Symbolum Apostolicum (LA)"]!, name: "Symbolum Apostolicum", text: "Credo in Deum Patrem omnipotentem, Creatorem caeli et terrae, et in Iesum Christum, Filium eius unicum, Dominum nostrum, qui conceptus est de Spiritu Sancto, natus ex Maria Virgine, passus sub Pontio Pilato, crucifixus, mortuus et sepultus, descendit ad inferos, tertia die resurrexit a mortuis, ascendit ad caelos, sedet ad dexteram Dei Patris omnipotentis, inde venturus est iudicare vivos et mortuos. Credo in Spiritum Sanctum, sanctam Ecclesiam catholicam, sanctorum communionem, remissionem peccatorum, carnis resurrectionem, vitam aeternam. Amen.", symbol: "book", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "O Iesu (LA)": Prayer(id: templatePrayerIds["O Iesu (LA)"]!, name: "O Iesu", text: "O Iesu mi, dimitte nobis debita nostra, libera nos ab igne inferni, perduc in caelum omnes animas, praesertim eas quae misericordiae tuae maxime indigent.", symbol: "cloud", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Pater Noster (LA)": Prayer(id: templatePrayerIds["Pater Noster (LA)"]!, name: "Pater noster", text: "Pater noster, qui es in caelis: sanctificetur nomen tuum; adveniat regnum tuum; fiat voluntas tua, sicut in caelo et in terra. Panem nostrum cotidianum da nobis hodie; et dimitte nobis debita nostra, sicut et nos dimittimus debitoribus nostris; et ne nos inducas in tentationem; sed libera nos a malo. Amen.", symbol: "heart", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Ave Maria (LA)": Prayer(id: templatePrayerIds["Ave Maria (LA)"]!, name: "Ave Maria", text: "Ave Maria, gratia plena, Dominus tecum; benedicta tu in mulieribus, et benedictus fructus ventris tui, Iesus. Sancta Maria, Mater Dei, ora pro nobis peccatoribus, nunc et in hora mortis nostrae. Amen.", symbol: "star", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Gloria Patri (LA)": Prayer(id: templatePrayerIds["Gloria Patri (LA)"]!, name: "Gloria Patri", text: "Gloria Patri et Filio et Spiritui Sancto. Sicut erat in principio et nunc et semper et in saecula saeculorum. Amen.", symbol: "flame", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Hail Mary (EN)": Prayer(id: templatePrayerIds["Hail Mary (EN)"]!, name: "Hail Mary", text: "Hail, Mary, full of grace, the Lord is with thee. Blessed art thou among women, and blessed is the fruit of thy womb, Jesus. Holy Mary, Mother of God, pray for us sinners, now and at the hour of our death. Amen.", symbol: "star", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Glory Be (EN)": Prayer(id: templatePrayerIds["Glory Be (EN)"]!, name: "Glory Be", text: "Glory be to the Father, and to the Son, and to the Holy Spirit. As it was in the beginning, is now, and ever shall be, world without end. Amen.", symbol: "flame", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "O My Jesus (EN)": Prayer(id: templatePrayerIds["O My Jesus (EN)"]!, name: "O my Jesus", text: "O my Jesus, forgive us our sins, save us from the fires of hell; lead all souls to Heaven, especially those in most need of thy mercy.", symbol: "cloud", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Apostles' Creed (EN)": Prayer(id: templatePrayerIds["Apostles' Creed (EN)"]!, name: "Apostles' Creed", text: "I believe in God, the Father almighty, Creator of heaven and earth, and in Jesus Christ, his only Son, our Lord, who was conceived by the Holy Spirit, born of the Virgin Mary, suffered under Pontius Pilate, was crucified, died and was buried; he descended into hell; on the third day he rose again from the dead; he ascended into heaven, and is seated at the right hand of God the Father almighty; from there he will come to judge the living and the dead. I believe in the Holy Spirit, the holy Catholic Church, the communion of saints, the forgiveness of sins, the resurrection of the body, and life everlasting. Amen.", symbol: "book", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Our Father":
    Prayer(id: templatePrayerIds["Our Father"]!, name: "Our Father", text: """
           Our Father, who art in heaven,
           hallowed be thy name.
           Thy kingdom come, thy will be done,
           on earth as it is in heaven.
           Give us this day our daily bread,
           and forgive us our trespasses,
           as we forgive those who trespass against us.
           And lead us not into temptation,
           but deliver us from evil.
           Amen.
           """, symbol: "heart", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Ojcze Nasz":
    Prayer(id: templatePrayerIds["Ojcze Nasz"]!, name: "Ojcze Nasz", text: """
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
        Prayer(id: templatePrayerIds["Zdrowaś Mario"]!, name: "Zdrowaś Mario", text: """
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
        Prayer(id: templatePrayerIds["Chwała Ojcu"]!, name: "Chwała Ojcu", text: """
           Chwała Ojcu i Synowi i Duchowi Świętemu, jak była na początku, teraz i zawsze i na wieki wieków.
           Amen.
           """, symbol: "flame", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "O mój Jezu":
    Prayer(id: templatePrayerIds["O mój Jezu"]!, name: "O mój Jezu", text: """
       O mój Jezu, przebacz nam nasze grzechy, zachowaj nas od ognia piekielnego. Zaprowadź wszystkie dusze do nieba i dopomóż szczególnie tym, którzy najbardziej potrzebują Twojego miłosierdzia
       """, symbol: "cloud", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Pod Twoją obronę":
        Prayer(id: templatePrayerIds["Pod Twoją obronę"]!, name: "Pod Twoją obronę", text: """
       Pod Twoją obronę uciekamy się, święta Boża Rodzicielko, naszymi prośbami racz nie gardzić w potrzebach naszych, ale od wszelakich złych przygód racz nas zawsze wybawiać. Panno chwalebna i błogosławiona. O Pani nasza, Orędowniczko nasza, Pośredniczko nasza, Pocieszycielko nasza. Z Synem swoim nas pojednaj, Synowi swojemu nas polecaj, swojemu Synowi nas oddawaj. Amen.
       """, symbol: "star.bubble", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Ojcze Przedwieczny":
    Prayer(id: templatePrayerIds["Ojcze Przedwieczny"]!, name: "Ojcze Przedwieczny", text: """
       Ojcze Przedwieczny, ofiaruję Ci Ciało i Krew, Duszę i Bóstwo najmilszego Syna Twojego, a Pana naszego Jezusa Chrystusa, na przebłaganie za grzechy nasze i całego świata.
       """, symbol: "globe.europe.africa", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Dla Jego bolesnej męk":
    Prayer(id: templatePrayerIds["Dla Jego bolesnej męk"]!, name: "Dla Jego bolesnej męk", text: """
       Dla Jego bolesnej męki, miej miłosierdzie dla nas i całego świata.
       """, symbol: "cross", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Święty Boże":
    Prayer(id: templatePrayerIds["Święty Boże"]!, name: "Święty Boże", text: """
       Święty Boże, Święty Mocny, Święty Nieśmiertelny, zmiłuj się nad nami i nad całym światem.
       """, symbol: "star", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Aniele Boży, Stróżu mój":
    Prayer(id: templatePrayerIds["Aniele Boży, Stróżu mój"]!, name: "Aniele Boży, Stróżu mój", text: """
           Aniele Boży Stróżu mój, Ty zawsze przy mnie stój.
           Rano, wieczór, we dnie, w nocy, bądź mi zawsze do pomocy.
           Broń mnie od wszystkiego złego i doprowadź do Żywota wiecznego. 
           Amen.
           """, symbol: "moon.stars", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Skład apostolski (Wyznanie wiary)":
        Prayer(id: templatePrayerIds["Skład apostolski (Wyznanie wiary)"]!, name: "Skład apostolski (Wyznanie wiary)", text: """
           Wierzę w Boga Ojca wszechmogącego, Stworzyciela nieba i ziemi, i w Jezusa Chrystusa, Syna Jego Jedynego, Pana naszego, który się począł z Ducha Świętego, narodził się z Maryi Panny, umęczon pod Ponckim Piłatem, ukrzyżowan, umarł i pogrzebion, zstąpił do piekieł, trzeciego dnia zmartwychwstał, wstąpił na niebiosa, siedzi po prawicy Boga Ojca wszechmogącego, stamtąd przyjdzie sądzić żywych i umarłych.
           Wierzę w Ducha Świętego, święty Kościół powszechny, świętych obcowanie, grzechów odpuszczenie, ciała zmartwychwstanie, żywot wieczny. Amen.
           """, symbol: "book", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Duchu Święty, który oświecasz":
        Prayer(id: templatePrayerIds["Duchu Święty, który oświecasz"]!, name: "Duchu Święty, który oświecasz", text: """
           Duchu Święty, który oświecasz serca i umysły nasze, dodaj nam zdolności i ochoty, aby ta nauka była dla nas pożytkiem doczesnym i wiecznym. Przez Chrystusa Pana naszego. Amen.
           """, symbol: "bird", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Modlitwa Apostolatu Margaretka":
        Prayer(id: templatePrayerIds["Modlitwa Apostolatu Margaretka"]!, name: "Modlitwa Apostolatu Margaretka", text: """
           O Jezu Boski Pasterzu, który powołałeś Apostołów, aby uczynić ich rybakami dusz ludzkich, Ty, który pociągnąłeś ku Sobie ks. … uczyń go Swoim gorliwym naśladowcą i sługą. Spraw, aby dzielił z Tobą pragnienie powszechnego zbawienia, dla którego na wszystkich ołtarzach uobecniasz Swoją Ofiarę. Ty o Panie, który żyjesz na wieki, aby wstawiać się za Twoim ludem, otwórz przed nim nowe horyzonty, by dostrzegał świat spragniony światła prawdy i miłości; by był solą ziemi i światłością świata. Umacniaj go Twoją mocą i błogosław mu. Święty Janie Pawle II, Patronie Apostolatu, Twojej szczególnej opiece go dzisiaj polecam. Proszę Cię, abyś wstawiał się za nim przed Bogiem i pomagał mu we wszystkich potrzebach, aby dochował Bogu wierności i owocnie pracował dla Jego większej chwały. Maryjo Matko Kościoła strzeż go przed wszelkim złem. Amen.
           """, symbol: "tree", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    
    "Modlitwa do Ducha Świętego dla kapłanów": Prayer(id: templatePrayerIds["Modlitwa do Ducha Świętego dla kapłanów"]!, name: "Modlitwa do Ducha Świętego dla kapłanów", text: """
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
        Prayer(id: templatePrayerIds["Modlitwa o uświęcenie kapłanów"]!, name: "Modlitwa o uświęcenie kapłanów", text: """
        Boże Trzykroć Święty, Ty wybierasz i powołujesz ludzi, aby służyli Twojemu ludowi jako jego pasterze. Spójrz na wszystkich kapłanów Kościoła i odnów w nich łaskę Sakramentu Święceń. Niech Duch Święty, którym wówczas zostali napełnieni, ożywia w nich łaskę świętości, aby ich posługiwanie i życie było święte. Niech będą zapatrzeni w Jezusa Chrystusa, Najwyższego Kapłana i Dobrego Pasterza i naśladują Go sercem wspaniałomyślnym, czyniąc ze swojego życia dar dla Ciebie i dla Kościoła.
        Matko Najświętsza, Matko kapłanów, wstawiaj się za nimi u Twojego Syna.
        Do Niego oni należą! Spraw, aby byli święci sercem i ciałem oraz aby byli wierni powołaniu, jakim zostali obdarowani. Umacniaj tych, którzy są słabi i prowadź ich do Chrystusa! Poślij im dobrych aniołów, którzy ich podźwigną ze słabości. Uproś wszystkim głęboką wiarę, niezachwianą nadzieję i doskonałą miłość oraz głębokie poczucie świętości Boga i tego, co Boże. Amen.
        """, symbol: "hands.and.sparkles", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Panie Jezu, wraz ze świętym Janem Marią Vianneyem":
        Prayer(id: templatePrayerIds["Panie Jezu, wraz ze świętym Janem Marią Vianneyem"]!, name: "Panie Jezu, wraz ze świętym Janem Marią Vianneyem", text: """
        Panie Jezu, wraz ze świętym Janem Marią Vianneyem powierzamy Ci wszystkich kapłanów, tych, których znamy, których spotkaliśmy, tych, którzy nam pomagali, i których nam dajesz obecnie, jako naszych pasterzy.
        Ty wezwałeś każdego z nich po imieniu. Dziękujemy Ci za nich i prosimy Cię: zachowaj ich w wierności Tobie. Ty, który ich uświęciłeś, aby w Twoim imieniu pełnili dla nas posługę pasterską, daj im siłę, ufność i radość z wypełnianej misji.
        Niech Eucharystia, którą sprawują, umacnia ich i daje im siłę do ofiarowania się Tobie, za nas i za zbawienie świata. Zachowaj ich w Twoim Miłosiernym Sercu, by zawsze byli świadkami Twego przebaczenia, aby wielbili Boga Ojca i uczyli nas prawdziwej drogi do świętości.
        Dobry Ojcze, wraz z nimi ofiarujemy się Chrystusowi dla dobra Kościoła. Niech żywy w nim będzie misyjny zapał dzięki tchnieniu Twojego Ducha. Naucz nas szanować i kochać wszystkich kapłanów oraz przyjmować ich posługę jako dar pochodzący od Ciebie, abyśmy razem z nimi jeszcze lepiej służyli dziełu zbawienia wszystkich ludzi. Amen.
        """, symbol: "hands.and.sparkles", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Panie Jezu, Ty wybrałeś Twoich kapłanów":
        Prayer(id: templatePrayerIds["Panie Jezu, Ty wybrałeś Twoich kapłanów"]!, name: "Panie Jezu, Ty wybrałeś Twoich kapłanów", text: """
        Panie Jezu, Ty wybrałeś Twoich kapłanów spośród nas i wysłałeś ich, aby głosili Twoje Słowo i działali w Twoje Imię. Za tak wielki dar dla Twego Kościoła przyjmij nasze uwielbienie i dziękczynienie. Prosimy Cię, abyś napełnił ich ogniem Twojej miłości, aby ich kapłaństwo ujawniało Twoją obecność w Kościele. Ponieważ są naczyniami z gliny, modlimy się, aby Twoja moc przenikała ich słabości. Nie pozwól, by w swych utrapieniach zostali zmiażdżeni. Spraw, by w wątpliwościach nigdy nie poddawali się rozpaczy, nie ulegali pokusom, by w prześladowaniach nie czuli się opuszczeni. Natchnij ich w modlitwie, aby codziennie żyli tajemnicą Twojej śmierci i zmartwychwstania. W chwilach słabości poślij im Twojego Ducha. Pomóż im wychwalać Twojego Ojca Niebieskiego i modlić się za grzeszników. Mocą Ducha Świętego włóż Twoje słowo na ich usta i wlej swoją miłość w ich serca, aby nieśli Dobrą Nowinę ubogim, a przygnębionym i zrozpaczonym – uzdrowienie. Niech dar Maryi, Twojej Matki, dla Twojego ucznia, którego umiłowałeś, będzie darem dla każdego kapłana. Spraw, aby Ta, która uformowała Ciebie na swój ludzki wizerunek, uformowała ich na Twoje podobieństwo, mocą Twojego Ducha, na chwałę Boga Ojca. Amen.
        """, symbol: "hands.and.sparkles", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Modlitwa św. Jana XXIII za kapłanów":
        Prayer(id: templatePrayerIds["Modlitwa św. Jana XXIII za kapłanów"]!, name: "Modlitwa św. Jana XXIII za kapłanów", text: """
        O Jezu, Wieczny Kapłanie, który zapaliłeś w świecie płomień nigdy nie gasnący! Dozwól uczestniczyć w niepokojach Twego Boskiego Serca tym, którzy zostali wybrani na pasterzy. Tym duszom szlachetnym, którym udzieliłeś pełni kapłaństwa, daj łaskę przynoszenia Ci zaszczytu w Twym świętym Kościele. Obok nich zaś pomnażaj nieustannie liczbę nowych i żarliwych apostołów Twego Królestwa, dla zbawienia wszystkich narodów.
        O Panie, spraw, aby w pokoju i pracy w niezamąconym ładzie, ludy i narody żyły w pomyślności, z Twym nie mającym granic błogosławieństwem, i aby Kościół Twój stale rozszerzał pomyślnie swoją zbawienną misję. Ocal, Panie, lud Twój i błogosław dziedzictwu Twojemu: rządź nim i prowadź go po wieczne czasy. Amen.
        """, symbol: "hands.and.sparkles", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Modlitwa Pawła VI za kapłanów":
        Prayer(id: templatePrayerIds["Modlitwa Pawła VI za kapłanów"]!, name: "Modlitwa Pawła VI za kapłanów", text: """
        O Panie, daj sługom Twoim serce, które obejmie całe ich wychowanie i przygotowanie. Niech będzie świadome wielkiej nowości, jaka zrodziła się w ich życiu, wyryła się w ich duszy. Serce, które byłoby zdolne do nowych uczuć, jakie Ty polecasz tym, których wybrałeś, by byli sługami Twego Ciała Eucharystycznego i Twego Ciała Mistycznego Kościoła. O Panie, daj im serce czyste, zdolne kochać tylko Ciebie taką pełnią, taką radością, taką głębokością, jakie wyłącznie ty potrafisz ofiarować, kiedy staniesz się wyłącznym, całkowitym przedmiotem ludzkiego serca. Serce czyste, które by nie znało zła, chyba tylko po to, by je rozpoznać, zwalczać i unikać, serce czyste jak dziecka, zdolne do zachwytu i do bojaźni.
        O Panie, daj im serce wielkie, otwarte na Twoje zamysły i zamknięte na wszelkie ciasne ambicje, na wszelkie małostkowe współzawodnictwo międzyludzkie. Serce wielkie, zdolne równać się z Twoim i zdolne pomieścić w sobie rozpiętość Kościoła, rozpiętość światła, zdolne wszystkich kochać, wszystkim służyć, być rzecznikiem wszystkich. Ponadto, o Panie, daj im serce mocne, chętne i gotowe stawić czoła wszelkim trudnościom, wszelkim pokusom, wszelkim słabościom, wszelkiemu znudzeniu, wszelkiemu zmęczeniu, serce potrafiące wytrwale, cierpliwie i bohatersko służyć tajemnicy, którą Ty powierzasz tym synom Twoim, których utożsamiłeś z sobą.
        W końcu, o Panie, serce zdolne do prawdziwej miłości, to znaczy zdolne rozumieć, akceptować, służyć i poświęcać się, zdolne być szczęśliwym, pulsującym Twoimi uczuciami i Twoimi myślami.
        """, symbol: "hands.and.sparkles", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Modlitwa św. Piusa X za kapłanów":
        Prayer(id: templatePrayerIds["Modlitwa św. Piusa X za kapłanów"]!, name: "Modlitwa św. Piusa X za kapłanów", text: """
        O Boże, Pasterzu i Nauczycielu wiernych, któryś dla zachowania i rozszerzania Swojego Kościoła ustanowił kapłaństwo i rzekł do Swoich apostołów: „Żniwo jest wielkie, ale robotników mało. Proście tedy Pana żniwa, by wysłał robotników na żniwo Swoje”.
        Oto, przystępujemy do Ciebie z gorącym pragnieniem i błagamy Cię usilnie: racz wysłać robotników na żniwo Swoje, wyślij godnych kapłanów do świętego Swojego Kościoła. Daj, Panie, aby wszyscy, których od wieków do Swej świętej służby wezwałeś, głosu Twego chętnie słuchali i z całego serca za nim postępowali; strzeż ich od niebezpieczeństw świata, udziel im ducha mądrości i rozumu, ducha rady i mocy, ducha wiedzy i pobożności i napełnij ich duchem Swej świętej bojaźni, ażeby łaską kapłaństwa obdarzeni, słowem i przykładem nauczali nas, postępować drogą przykazań Twoich i doprowadzili nas do wiecznie błogiego połączenia się z Tobą.
        Który żyjesz i królujesz na wieki wieków. Amen.
        """, symbol: "hands.and.sparkles", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Modlitwa św. Jana Pawła II za kapłanów":
        Prayer(id: templatePrayerIds["Modlitwa św. Jana Pawła II za kapłanów"]!, name: "Modlitwa św. Jana Pawła II za kapłanów", text: """
        Panie, Ty pragnąłeś zbawić ludzi i dlatego założyłeś Kościół jako wspólnotę braci zjednoczonych w Twojej miłości. Nie przestawaj nawiedzać nas i powoływać tych, których wybrałeś, aby byli głosem Twojego Ducha Świętego, zaczynem społeczeństwa bardziej sprawiedliwego i braterskiego. Wyjednaj nam u niebieskiego Ojca duchowych przewodników, których potrzebują nasze wspólnoty: prawdziwych kapłanów żywego Boga, którzy oświeceni Twoim słowem, będą umieli mówić o Tobie i uczyć innych, jak rozmawiać z Tobą.
        Pozwól wzrastać swojemu Kościołowi, mnożąc w nim osoby konsekrowane, które powierzają wszystko Tobie, abyś Ty mógł wszystkich zbawić. Niech nasze wspólnoty sprawują ze śpiewem i uwielbieniem Eucharystię jako ofiarę dziękczynienia za Twoją chwałę i dobroć, niech wychodzą na drogi świata, aby głosić radość i pokój – cenne dary Twojego zbawienia.
        Spójrz, o Panie, na całą ludzkość i okaż miłosierdzie tym, którzy szukają Cię przez modlitwę i prawe życie, ale jeszcze Cię nie spotkali: objaw się im jako Droga, która prowadzi do Ojca, jako Prawda, która wyzwala, jako Życie, które nie ma końca. Pozwól nam, Panie, żyć w Twoim Kościele w duchu wiernej służby i całkowitego poświęcenia, aby nasze świadectwo było wiarygodne i owocne. Amen.
        """, symbol: "hands.and.sparkles", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Modlitwa św. Urszuli Ledóchowskiej za kapłanów":
        Prayer(id: templatePrayerIds["Modlitwa św. Urszuli Ledóchowskiej za kapłanów"]!, name: "Modlitwa św. Urszuli Ledóchowskiej za kapłanów", text: """
        O Jezu, Odwieczny Arcykapłanie, Boski Ofiarniku, który w niezrównanym porywie miłości dla ludzi, Twych braci, sprawiłeś, że chrześcijańskie kapłaństwo wytrysnęło z Boskiego Serca Twego, nie przestawaj wlewać w Twych kapłanów ożywczych strumieni Twej nieskończonej miłości.
        Żyj w nich, o Panie, przeistaczaj ich w siebie, uczyń ich mocą łaski swojej narzędziami swego miłosierdzia. Działaj w nich i przez nich i spraw, by przyoblekłszy się zupełnie w Ciebie przez wierne naśladowanie Twych godnych uwielbienia cnót, wykonywali mocą Twego imienia i Twego ducha uczynki, któreś sam zdziałał dla zbawienia świata.
        Boski Odkupicielu dusz, spojrzyj, jak wielu jest jeszcze pogrążonych w ciemnościach błędu. Policz owieczki zbłąkane, krążące nad przepaścią, wejrzyj na tłumy ubogich, głodnych, nieświadomych i słabych, jęczących w opuszczeniu. Wracaj do nas, o Jezu, przez Twych kapłanów. Ożyj w nich rzeczywiście, działaj przez nich i przejdź znowu przez świat ucząc, przebaczając, pocieszając, poświęcając się i nawiązując na nowo święte więzy miłości łączące Serce Boże z sercem człowieczym. Amen
        """, symbol: "hands.and.sparkles", audioFilename: nil, audioSource: nil, timestampedLines: nil),
    "Msza (Brewiarz)":
        Prayer(id: templatePrayerIds["Msza (Brewiarz)"]!, name: "Msza", text: "Teksty Mszy z brewiarz.pl", symbol: "cross.case", audioFilename: nil, audioSource: nil, timestampedLines: nil, content: .brewiarz(.msza)),
    "Wezwanie (Brewiarz)":
        Prayer(id: templatePrayerIds["Wezwanie (Brewiarz)"]!, name: "Wezwanie", text: "Modlitwa w brewiarz.pl", symbol: "globe.europe.africa", audioFilename: nil, audioSource: nil, timestampedLines: nil, content: .brewiarz(.wezwanie)),
    "Godzina Czytań (Brewiarz)":
        Prayer(id: templatePrayerIds["Godzina Czytań (Brewiarz)"]!, name: "Godzina Czytań", text: "Modlitwa w brewiarz.pl", symbol: "globe.europe.africa", audioFilename: nil, audioSource: nil, timestampedLines: nil, content: .brewiarz(.godzinaCzytan)),
    "Jutrznia (Brewiarz)":
        Prayer(id: templatePrayerIds["Jutrznia (Brewiarz)"]!, name: "Jutrznia", text: "Modlitwa w brewiarz.pl", symbol: "globe.europe.africa", audioFilename: nil, audioSource: nil, timestampedLines: nil, content: .brewiarz(.jutrznia)),
    "Modlitwa przedpołudniowa (Brewiarz)":
        Prayer(id: templatePrayerIds["Modlitwa przedpołudniowa (Brewiarz)"]!, name: "Modlitwa przedpołudniowa", text: "Modlitwa w brewiarz.pl", symbol: "globe.europe.africa", audioFilename: nil, audioSource: nil, timestampedLines: nil, content: .brewiarz(.modlitwaPrzedpoludniowa)),
    "Modlitwa południowa (Brewiarz)":
        Prayer(id: templatePrayerIds["Modlitwa południowa (Brewiarz)"]!, name: "Modlitwa południowa", text: "Modlitwa w brewiarz.pl", symbol: "globe.europe.africa", audioFilename: nil, audioSource: nil, timestampedLines: nil, content: .brewiarz(.modlitwaPoludniowa)),
    "Modlitwa popołudniowa (Brewiarz)":
        Prayer(id: templatePrayerIds["Modlitwa popołudniowa (Brewiarz)"]!, name: "Modlitwa popołudniowa", text: "Modlitwa w brewiarz.pl", symbol: "globe.europe.africa", audioFilename: nil, audioSource: nil, timestampedLines: nil, content: .brewiarz(.modlitwaPopoludniowa)),
    "Nieszpory (Brewiarz)":
        Prayer(id: templatePrayerIds["Nieszpory (Brewiarz)"]!, name: "Nieszpory", text: "Modlitwa w brewiarz.pl", symbol: "globe.europe.africa", audioFilename: nil, audioSource: nil, timestampedLines: nil, content: .brewiarz(.nieszpory)),
    "Kompleta (Brewiarz)":
        Prayer(id: templatePrayerIds["Kompleta (Brewiarz)"]!, name: "Kompleta", text: "Modlitwa w brewiarz.pl", symbol: "globe.europe.africa", audioFilename: nil, audioSource: nil, timestampedLines: nil, content: .brewiarz(.kompleta)),
    "Święty dnia (Brewiarz)":
        Prayer(id: templatePrayerIds["Święty dnia (Brewiarz)"]!, name: "Święty dnia", text: "Życiorys świętego z brewiarz.pl", symbol: "person.crop.circle.badge.checkmark", audioFilename: nil, audioSource: nil, timestampedLines: nil, content: .saintBiography),
]

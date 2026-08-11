import Foundation

enum RosaryMysterySet: String, CaseIterable, Codable {
    case joyful
    case luminous
    case sorrowful
    case glorious

    static func forToday(calendar: Calendar = .current, date: Date = .now) -> Self {
        switch calendar.component(.weekday, from: date) {
        case 2, 7: .joyful       // Monday, Saturday
        case 3, 6: .sorrowful    // Tuesday, Friday
        case 4, 1: .glorious     // Wednesday, Sunday
        default: .luminous       // Thursday
        }
    }

    func variantName(language: PrayerLanguage) -> String {
        return switch (self, language) {
        case (.joyful, .polish): "Różaniec — tajemnice radosne"
        case (.luminous, .polish): "Różaniec — tajemnice światła"
        case (.sorrowful, .polish): "Różaniec — tajemnice bolesne"
        case (.glorious, .polish): "Różaniec — tajemnice chwalebne"
        case (.joyful, .english): "Rosary — Joyful Mysteries"
        case (.luminous, .english): "Rosary — Luminous Mysteries"
        case (.sorrowful, .english): "Rosary — Sorrowful Mysteries"
        case (.glorious, .english): "Rosary — Glorious Mysteries"
        case (.joyful, .latin): "Rosarium — Mysteria gaudiosa"
        case (.luminous, .latin): "Rosarium — Mysteria luminosa"
        case (.sorrowful, .latin): "Rosarium — Mysteria dolorosa"
        case (.glorious, .latin): "Rosarium — Mysteria gloriosa"
        }
    }

    func mysteries(language: PrayerLanguage) -> [String] {
        switch (self, language) {
        case (.joyful, .polish): ["Zwiastowanie Najświętszej Maryi Pannie", "Nawiedzenie św. Elżbiety", "Narodzenie Pana Jezusa", "Ofiarowanie Pana Jezusa w świątyni", "Odnalezienie Pana Jezusa w świątyni"]
        case (.luminous, .polish): ["Chrzest Pana Jezusa w Jordanie", "Objawienie siebie na weselu w Kanie", "Głoszenie królestwa Bożego i wzywanie do nawrócenia", "Przemienienie na górze Tabor", "Ustanowienie Eucharystii"]
        case (.sorrowful, .polish): ["Modlitwa Pana Jezusa w Ogrójcu", "Biczowanie Pana Jezusa", "Cierniem ukoronowanie Pana Jezusa", "Dźwiganie krzyża przez Pana Jezusa", "Ukrzyżowanie i śmierć Pana Jezusa"]
        case (.glorious, .polish): ["Zmartwychwstanie Pana Jezusa", "Wniebowstąpienie Pana Jezusa", "Zesłanie Ducha Świętego", "Wniebowzięcie Najświętszej Maryi Panny", "Ukoronowanie Najświętszej Maryi Panny"]
        case (.joyful, .english): ["The Annunciation", "The Visitation", "The Nativity", "The Presentation in the Temple", "The Finding in the Temple"]
        case (.luminous, .english): ["The Baptism of the Lord", "The Wedding at Cana", "The Proclamation of the Kingdom", "The Transfiguration", "The Institution of the Eucharist"]
        case (.sorrowful, .english): ["The Agony in the Garden", "The Scourging at the Pillar", "The Crowning with Thorns", "The Carrying of the Cross", "The Crucifixion"]
        case (.glorious, .english): ["The Resurrection", "The Ascension", "The Descent of the Holy Spirit", "The Assumption", "The Coronation of Mary"]
        case (.joyful, .latin): ["Annuntiatio", "Visitatio", "Nativitas Domini", "Praesentatio Iesu in templo", "Inventio Iesu in templo"]
        case (.luminous, .latin): ["Baptisma Iesu in Iordane", "Manifestatio Iesu in Cana", "Proclamatio Regni Dei", "Transfiguratio Domini", "Institutio Eucharistiae"]
        case (.sorrowful, .latin): ["Agonia Iesu in horto", "Flagellatio Iesu", "Coronatio spinis", "Baiulatio crucis", "Crucifixio et mors Iesu"]
        case (.glorious, .latin): ["Resurrectio Domini", "Ascensio Domini", "Descensus Spiritus Sancti", "Assumptio Mariae", "Coronatio Mariae"]
        }
    }

    func mysteryPrayerName(language: PrayerLanguage, index: Int) -> String {
        let number = index + 1
        return switch (self, language) {
        case (.joyful, .polish): "Tajemnica \(number) radosna"
        case (.luminous, .polish): "Tajemnica \(number) światła"
        case (.sorrowful, .polish): "Tajemnica \(number) bolesna"
        case (.glorious, .polish): "Tajemnica \(number) chwalebna"
        case (.joyful, .english): "Joyful mystery \(number)"
        case (.luminous, .english): "Luminous mystery \(number)"
        case (.sorrowful, .english): "Sorrowful mystery \(number)"
        case (.glorious, .english): "Glorious mystery \(number)"
        case (.joyful, .latin): "Mysterium \(number) gaudiosum"
        case (.luminous, .latin): "Mysterium \(number) luminosum"
        case (.sorrowful, .latin): "Mysterium \(number) dolorosum"
        case (.glorious, .latin): "Mysterium \(number) gloriosum"
        }
    }
}

func rosaryMysteryPrayerKey(set: RosaryMysterySet, language: PrayerLanguage, index: Int) -> String {
    "Rosary mystery|\(set.rawValue)|\(language.rawValue)|\(index)"
}

func rosaryMysteryPrayerTemplates() -> [String: Prayer] {
    Dictionary(uniqueKeysWithValues: RosaryMysterySet.allCases.flatMap { set in
        PrayerLanguage.allCases.flatMap { language in
            set.mysteries(language: language).enumerated().map { index, title in
                let key = rosaryMysteryPrayerKey(set: set, language: language, index: index)
                let hash = String(format: "%016llx", stableMysteryHash(key))
                let suffix = String(hash.suffix(12))
                let id = UUID(uuidString: "00000000-0000-4000-8000-\(suffix)")
                    ?? UUID(uuidString: "00000000-0000-4000-8000-000000000000")!
                return (
                    key,
                    Prayer(
                        id: id,
                        name: set.mysteryPrayerName(language: language, index: index),
                        text: title,
                        symbol: "sparkles",
                        audioFilename: nil,
                        audioSource: nil,
                        timestampedLines: nil
                    )
                )
            }
        }
    })
}

private func stableMysteryHash(_ value: String) -> UInt64 {
    value.utf8.reduce(14_695_981_039_346_656_037) { hash, byte in
        (hash ^ UInt64(byte)) &* 1_099_511_628_211
    }
}

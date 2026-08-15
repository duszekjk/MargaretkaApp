import Foundation

enum PrayerLanguage: String, CaseIterable, Codable, Identifiable, Sendable {
    case polish = "pl"
    case english = "en"
    case latin = "la"

    var id: String { rawValue }
}

enum SimpleDevotion: String, CaseIterable, Identifiable {
    case rosary
    case divineMercyChaplet

    var id: String { rawValue }

    var polishName: String {
        switch self {
        case .rosary: "Różaniec"
        case .divineMercyChaplet: "Koronka do Miłosierdzia Bożego"
        }
    }
}

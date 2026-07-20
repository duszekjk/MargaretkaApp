import Foundation

nonisolated struct MargaretkaWidgetSaint: Codable, Hashable, Sendable {
    var dateID: String
    var title: String
    var text: String
}

nonisolated struct MargaretkaWidgetStatistics: Codable, Hashable, Sendable {
    var completedSessions: Int
    var completedThisWeek: Int
    var currentWeeklyStreak: Int
    var totalPrayerMinutes: Int

    static let empty = Self(
        completedSessions: 0,
        completedThisWeek: 0,
        currentWeeklyStreak: 0,
        totalPrayerMinutes: 0
    )
}

nonisolated struct MargaretkaWidgetPayload: Codable, Hashable, Sendable {
    var saints: [MargaretkaWidgetSaint]
    var statistics: MargaretkaWidgetStatistics
    var updatedAt: Date

    static let empty = Self(saints: [], statistics: .empty, updatedAt: .distantPast)

    func saint(
        for date: Date,
        calendar: Calendar = MargaretkaWidgetSharedStore.warsawCalendar
    ) -> MargaretkaWidgetSaint? {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let dateID = String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
        return saints.first { $0.dateID == dateID }
    }
}

nonisolated enum MargaretkaWidgetSharedStore {
    static let appGroupIdentifier = "group.com.duszekjk.MargaretkaApp"
    static let payloadKey = "margaretka_widget_payload_v1"
    static let widgetKind = "MargaretkaSaintWidget"

    static var warsawCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "pl_PL")
        calendar.timeZone = TimeZone(identifier: "Europe/Warsaw") ?? .current
        return calendar
    }

    static func dateID(for date: Date) -> String {
        let components = warsawCalendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    static func load(defaults: UserDefaults? = nil) -> MargaretkaWidgetPayload {
        let defaults = defaults ?? UserDefaults(suiteName: appGroupIdentifier)
        guard let data = defaults?.data(forKey: payloadKey),
              let payload = try? JSONDecoder().decode(MargaretkaWidgetPayload.self, from: data) else {
            return .empty
        }
        return payload
    }

    static func save(_ payload: MargaretkaWidgetPayload, defaults: UserDefaults? = nil) {
        let defaults = defaults ?? UserDefaults(suiteName: appGroupIdentifier)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults?.set(data, forKey: payloadKey)
    }
}

import Foundation
import WidgetKit

@MainActor
enum MargaretkaWidgetDataWriter {
    static func updateSaints(from days: [OfflineBreviaryDay]) {
        var payload = MargaretkaWidgetSharedStore.load()
        payload.saints = Dictionary(grouping: days.filter { $0.saintBiography != nil }, by: \.date)
            .compactMap { date, variants -> MargaretkaWidgetSaint? in
                let selected = BreviaryVariantPreferences.preferredDay(
                    from: variants,
                    order: BreviaryVariantPreferences.load()
                )
                guard let biography = selected?.saintBiography else { return nil }
                return MargaretkaWidgetSaint(
                    dateID: date.id,
                    title: biography.title,
                    text: biography.text
                )
            }
            .sorted { $0.dateID < $1.dateID }
        payload.updatedAt = .now
        saveAndReload(payload)
    }

    static func updateStatistics(
        from sessions: [PrayerSession],
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) {
        let completed = sessions.filter(\.completed)
        let week = calendar.dateInterval(of: .weekOfYear, for: referenceDate)
        let completedThisWeek = completed.filter { session in
            week?.contains(session.endedAt) == true
        }.count
        let completedWeekStarts = Set(completed.compactMap { session in
            calendar.dateInterval(of: .weekOfYear, for: session.endedAt)?.start
        })
        var currentWeeklyStreak = 0
        var weekStart = week?.start
        while let current = weekStart, completedWeekStarts.contains(current) {
            currentWeeklyStreak += 1
            weekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: current)
        }

        var payload = MargaretkaWidgetSharedStore.load()
        payload.statistics = MargaretkaWidgetStatistics(
            completedSessions: completed.count,
            completedThisWeek: completedThisWeek,
            currentWeeklyStreak: currentWeeklyStreak,
            totalPrayerMinutes: Int(completed.reduce(0) { $0 + $1.duration } / 60)
        )
        payload.updatedAt = .now
        saveAndReload(payload)
    }

    private static func saveAndReload(_ payload: MargaretkaWidgetPayload) {
        MargaretkaWidgetSharedStore.save(payload)
        WidgetCenter.shared.reloadTimelines(ofKind: MargaretkaWidgetSharedStore.widgetKind)
    }
}

//
//  PrayerAppIntents.swift
//  MargaretkaApp
//

import AppIntents
import Foundation

struct PrayerTargetEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "priest, person, or complex prayer",
        numericFormat: "\(placeholder: .int) priests, people, or complex prayers"
    )
    static var defaultQuery = PrayerTargetQuery()

    let id: UUID
    let name: String
    let categoryRawValue: String

    init(target: Priest) {
        id = target.id
        name = target.displayName
        categoryRawValue = target.category.rawValue
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(categoryTitle)"
        )
    }

    private var categoryTitle: String {
        switch PrayerTargetCategory(rawValue: categoryRawValue) {
        case .priest:
            return "Priest"
        case .person:
            return "Person"
        case .prayer:
            return "Complex prayer"
        case nil:
            return "Prayer target"
        }
    }
}

struct PrayerTargetQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [PrayerTargetEntity] {
        let targetsById = Dictionary(
            uniqueKeysWithValues: PrayerShortcutRepository.targets().map { ($0.id, $0) }
        )
        return identifiers.compactMap { targetsById[$0].map(PrayerTargetEntity.init) }
    }

    @MainActor
    func suggestedEntities() async throws -> [PrayerTargetEntity] {
        PrayerShortcutRepository.targets().map(PrayerTargetEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [PrayerTargetEntity] {
        let needle = PrayerShortcutRepository.normalized(string)
        return PrayerShortcutRepository.targets()
            .filter { target in
                needle.isEmpty || PrayerShortcutRepository.normalized(target.displayName).contains(needle)
            }
            .map(PrayerTargetEntity.init)
    }
}

struct StartPrayerIntent: OpenIntent {
    static var title: LocalizedStringResource = "Start prayer"
    static var description = IntentDescription("Opens a saved priest, person, or complex prayer at the beginning.")

    @Parameter(
        title: "Priest, person, or complex prayer",
        requestValueDialog: "Who or which complex prayer should I start?",
        requestDisambiguationDialog: "Which priest, person, or complex prayer do you mean?"
    )
    var target: PrayerTargetEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard PrayerShortcutRepository.target(withId: target.id) != nil else {
            throw AppIntentError.Unrecoverable.entityNotFound
        }
        PrayerNotificationRouter.shared.requestPrayer(itemId: target.id.uuidString)
        return .result(dialog: IntentDialog("Opening prayer for \(target.name)."))
    }
}

struct LogCompletedPrayerIntent: AppIntent {
    static var title: LocalizedStringResource = "Log completed prayer"
    static var description = IntentDescription("Logs a completed prayer without opening the app. Duration is optional.")
    @available(macOS 26.0, iOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    @Parameter(
        title: "Priest, person, or complex prayer",
        requestValueDialog: "Who or which complex prayer should I log?",
        requestDisambiguationDialog: "Which priest, person, or complex prayer do you mean?"
    )
    var target: PrayerTargetEntity

    @Parameter(
        title: "Duration in minutes",
        description: "Optional prayer duration. Leave it at zero when it was not measured.",
        default: 0,
        controlStyle: .field,
        inclusiveRange: (lowerBound: 0, upperBound: 1440)
    )
    var durationMinutes: Int

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> & ProvidesDialog {
        let session = try PrayerShortcutRepository.recordCompletedPrayer(
            targetId: target.id,
            durationMinutes: durationMinutes
        )
        let durationText = session.duration > 0
            ? " Duration: \(PrayerShortcutStatistics.formattedDuration(session.duration))."
            : ""
        return .result(
            value: true,
            dialog: IntentDialog("Logged completed prayer for \(target.name).\(durationText)")
        )
    }
}

struct PrayerStreakIntent: AppIntent {
    static var title: LocalizedStringResource = "Check prayer streak"
    static var description = IntentDescription("Reports the number of consecutive weeks with a completed prayer for a saved target.")
    @available(macOS 26.0, iOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    @Parameter(
        title: "Priest, person, or complex prayer",
        requestValueDialog: "Whose prayer streak should I check?",
        requestDisambiguationDialog: "Which priest, person, or complex prayer do you mean?"
    )
    var target: PrayerTargetEntity

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        guard PrayerShortcutRepository.target(withId: target.id) != nil else {
            throw AppIntentError.Unrecoverable.entityNotFound
        }
        let stats = PrayerShortcutRepository.statistics(for: target.id)
        let dialog: IntentDialog
        switch stats.currentWeeklyStreak {
        case 0:
            dialog = IntentDialog("There is no current streak for \(target.name) yet.")
        case 1:
            dialog = IntentDialog("The current streak for \(target.name) is one week.")
        default:
            dialog = IntentDialog("The current streak for \(target.name) is \(stats.currentWeeklyStreak) weeks.")
        }
        return .result(value: stats.currentWeeklyStreak, dialog: dialog)
    }
}

struct AveragePrayerDurationIntent: AppIntent {
    static var title: LocalizedStringResource = "Check average prayer duration"
    static var description = IntentDescription("Reports the average measured duration of completed prayers for a saved target.")
    @available(macOS 26.0, iOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    @Parameter(
        title: "Priest, person, or complex prayer",
        requestValueDialog: "For whom should I check the average prayer duration?",
        requestDisambiguationDialog: "Which priest, person, or complex prayer do you mean?"
    )
    var target: PrayerTargetEntity

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Double> & ProvidesDialog {
        guard PrayerShortcutRepository.target(withId: target.id) != nil else {
            throw AppIntentError.Unrecoverable.entityNotFound
        }
        let stats = PrayerShortcutRepository.statistics(for: target.id)
        guard let average = stats.averageMeasuredDuration else {
            return .result(
                value: 0,
                dialog: IntentDialog("There is no measured prayer duration for \(target.name) yet.")
            )
        }
        let minutes = average / 60
        return .result(
            value: minutes,
            dialog: IntentDialog("The average prayer duration for \(target.name) is \(PrayerShortcutStatistics.formattedDuration(average)).")
        )
    }
}

struct MargaretkaAppShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .purple

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartPrayerIntent(),
            phrases: [
                "Start prayer in \(.applicationName)",
                "Start prayer for \(\.$target) in \(.applicationName)",
                "Start \(\.$target) in \(.applicationName)",
                "Open prayer for \(\.$target) in \(.applicationName)",
                "Begin praying for \(\.$target) in \(.applicationName)"
            ],
            shortTitle: "Start prayer",
            systemImageName: "hands.sparkles"
        )
        AppShortcut(
            intent: LogCompletedPrayerIntent(),
            phrases: [
                "Log prayer in \(.applicationName)",
                "Mark prayer for \(\.$target) as completed in \(.applicationName)",
                "I prayed for \(\.$target) in \(.applicationName)"
            ],
            shortTitle: "Log prayer",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: PrayerStreakIntent(),
            phrases: [
                "Check prayer streak in \(.applicationName)",
                "How long is my prayer streak for \(\.$target) in \(.applicationName)",
                "Show the prayer streak for \(\.$target) in \(.applicationName)"
            ],
            shortTitle: "Prayer streak",
            systemImageName: "flame"
        )
        AppShortcut(
            intent: AveragePrayerDurationIntent(),
            phrases: [
                "Check average prayer duration in \(.applicationName)",
                "How long do I usually pray for \(\.$target) in \(.applicationName)",
                "Show average prayer duration for \(\.$target) in \(.applicationName)"
            ],
            shortTitle: "Average prayer duration",
            systemImageName: "clock"
        )
    }
}

struct PrayerShortcutStatistics {
    let currentWeeklyStreak: Int
    let averageMeasuredDuration: TimeInterval?
    let completedSessionCount: Int

    static func calculate(
        targetId: UUID,
        sessions: [PrayerSession],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> PrayerShortcutStatistics {
        let completed = sessions.filter { $0.completed && $0.targetId == targetId }
        let measuredDurations = completed.map(\.duration).filter { $0 > 0 }
        let average = measuredDurations.isEmpty
            ? nil
            : measuredDurations.reduce(0, +) / Double(measuredDurations.count)

        let completedWeekStarts = Set(completed.compactMap { session in
            calendar.dateInterval(of: .weekOfYear, for: session.endedAt)?.start
        })
        var streak = 0
        var week = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start
        while let currentWeek = week, completedWeekStarts.contains(currentWeek) {
            streak += 1
            week = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeek)
        }

        return PrayerShortcutStatistics(
            currentWeeklyStreak: streak,
            averageMeasuredDuration: average,
            completedSessionCount: completed.count
        )
    }

    static func formattedDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = max(1, Int(duration / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0, minutes > 0 {
            return "\(hours) hr \(minutes) min"
        }
        if hours > 0 {
            return "\(hours) hr"
        }
        return "\(minutes) min"
    }
}

@MainActor
enum PrayerShortcutRepository {
    static func targets() -> [Priest] {
        let stored: [Priest] = LocalDatabase.shared.load(from: Priest.storageKey)
        return stored.sorted { lhs, rhs in
            let lhsOrder = categoryOrder(lhs.category)
            let rhsOrder = categoryOrder(rhs.category)
            if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    static func target(withId id: UUID) -> Priest? {
        targets().first { $0.id == id }
    }

    static func statistics(for targetId: UUID, referenceDate: Date = Date()) -> PrayerShortcutStatistics {
        let sessions: [PrayerSession] = LocalDatabase.shared.load(from: PrayerSessionStore.saveKey)
        return PrayerShortcutStatistics.calculate(
            targetId: targetId,
            sessions: sessions,
            referenceDate: referenceDate
        )
    }

    static func recordCompletedPrayer(
        targetId: UUID,
        durationMinutes: Int,
        now: Date = Date()
    ) throws -> PrayerSession {
        guard let target = target(withId: targetId) else {
            throw AppIntentError.Unrecoverable.entityNotFound
        }
        let prayers: [Prayer] = LocalDatabase.shared.load(from: "stored_prayers")
        let session = makeCompletedSession(
            target: target,
            prayers: prayers,
            durationMinutes: durationMinutes,
            now: now
        )
        PrayerSessionStore().add(session)
        return session
    }

    static func makeCompletedSession(
        target: Priest,
        prayers: [Prayer],
        durationMinutes: Int,
        now: Date
    ) -> PrayerSession {
        let prayerIds = target.assignedPrayerGroups.flatMap(flattenPrayerIds)
        let prayerNamesById = Dictionary(uniqueKeysWithValues: prayers.map { ($0.id, $0.name) })
        let duration = TimeInterval(max(0, durationMinutes) * 60)
        return PrayerSession(
            id: UUID(),
            targetId: target.id,
            targetName: target.displayName,
            targetCategory: target.category,
            prayerIds: prayerIds,
            prayerNames: prayerIds.map { prayerNamesById[$0] ?? "Modlitwa" },
            startedAt: now.addingTimeInterval(-duration),
            endedAt: now,
            duration: duration,
            totalSubprayerCount: prayerIds.count,
            completedSubprayerCount: prayerIds.count,
            completed: true,
            completion: .finished
        )
    }

    static func normalized(_ text: String) -> String {
        text.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "pl_PL")
        )
        .lowercased()
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func flattenPrayerIds(from group: AssignedPrayerGroup) -> [UUID] {
        var result: [UUID] = []
        for _ in 0..<group.repeatCount {
            for item in group.items {
                switch item {
                case .prayer(let id):
                    result.append(id)
                case .subgroup(let index):
                    if group.subgroups.indices.contains(index) {
                        result.append(contentsOf: flattenPrayerIds(from: group.subgroups[index]))
                    }
                }
            }
        }
        return result
    }

    private static func categoryOrder(_ category: PrayerTargetCategory) -> Int {
        switch category {
        case .priest: return 0
        case .person: return 1
        case .prayer: return 2
        }
    }
}

//
//  PrayerAppIntents.swift
//  MargaretkaApp
//

import AppIntents
import Foundation

struct PrayerTargetEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Osoba lub modlitwa / person or prayer",
        numericFormat: "\(placeholder: .int) osoby lub modlitwy / \(placeholder: .int) people or prayers"
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
            return "Ksiądz / Priest"
        case .person:
            return "Osoba / Person"
        case .prayer:
            return "Modlitwa / Prayer"
        case nil:
            return "Cel modlitwy / Prayer target"
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

struct StartPrayerIntent: AppIntent {
    static var title: LocalizedStringResource = "Rozpocznij modlitwę"
    static var description = IntentDescription("Otwiera wybraną osobę, kapłana lub modlitwę i przechodzi do początku modlitwy.")
    static var supportedModes: IntentModes { .foreground(.immediate) }

    @Parameter(
        title: "Osoba lub modlitwa",
        requestValueDialog: "Za kogo lub jaką modlitwę rozpocząć?",
        requestDisambiguationDialog: "Którą osobę lub modlitwę masz na myśli?"
    )
    var target: PrayerTargetEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard PrayerShortcutRepository.target(withId: target.id) != nil else {
            throw AppIntentError.Unrecoverable.entityNotFound
        }
        PrayerNotificationRouter.shared.requestPrayer(itemId: target.id.uuidString)
        return .result(dialog: IntentDialog("Otwieram modlitwę: \(target.name)."))
    }
}

struct LogCompletedPrayerIntent: AppIntent {
    static var title: LocalizedStringResource = "Zapisz ukończoną modlitwę"
    static var description = IntentDescription("Zapisuje ukończoną modlitwę bez otwierania aplikacji. Czas trwania jest opcjonalny.")
    static var supportedModes: IntentModes { .background }

    @Parameter(
        title: "Osoba lub modlitwa",
        requestValueDialog: "Za kogo lub jaką modlitwę zapisać?",
        requestDisambiguationDialog: "Którą osobę lub modlitwę masz na myśli?"
    )
    var target: PrayerTargetEntity

    @Parameter(
        title: "Czas w minutach",
        description: "Opcjonalny czas trwania modlitwy. Pozostaw zero, jeśli nie był mierzony.",
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
            ? " Czas: \(PrayerShortcutStatistics.formattedDuration(session.duration))."
            : ""
        return .result(
            value: true,
            dialog: IntentDialog("Zapisano ukończoną modlitwę: \(target.name).\(durationText)")
        )
    }
}

struct PrayerStreakIntent: AppIntent {
    static var title: LocalizedStringResource = "Sprawdź serię modlitwy"
    static var description = IntentDescription("Podaje liczbę kolejnych tygodni z ukończoną modlitwą za wybraną osobę lub dla wybranej modlitwy.")
    static var supportedModes: IntentModes { .background }

    @Parameter(
        title: "Osoba lub modlitwa",
        requestValueDialog: "Czyją serię modlitwy sprawdzić?",
        requestDisambiguationDialog: "Którą osobę lub modlitwę masz na myśli?"
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
            dialog = IntentDialog("Nie ma jeszcze bieżącej serii dla: \(target.name).")
        case 1:
            dialog = IntentDialog("Bieżąca seria dla \(target.name) to jeden tydzień.")
        default:
            dialog = IntentDialog("Bieżąca seria dla \(target.name) to \(stats.currentWeeklyStreak) tygodni.")
        }
        return .result(value: stats.currentWeeklyStreak, dialog: dialog)
    }
}

struct AveragePrayerDurationIntent: AppIntent {
    static var title: LocalizedStringResource = "Sprawdź średni czas modlitwy"
    static var description = IntentDescription("Podaje średni zmierzony czas ukończonej modlitwy za wybraną osobę lub dla wybranej modlitwy.")
    static var supportedModes: IntentModes { .background }

    @Parameter(
        title: "Osoba lub modlitwa",
        requestValueDialog: "Dla kogo sprawdzić średni czas modlitwy?",
        requestDisambiguationDialog: "Którą osobę lub modlitwę masz na myśli?"
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
                dialog: IntentDialog("Nie ma jeszcze zmierzonego czasu modlitwy dla: \(target.name).")
            )
        }
        let minutes = average / 60
        return .result(
            value: minutes,
            dialog: IntentDialog("Średni czas modlitwy dla \(target.name) to \(PrayerShortcutStatistics.formattedDuration(average)).")
        )
    }
}

struct MargaretkaAppShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .purple

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartPrayerIntent(),
            phrases: [
                "Rozpocznij \(\.$target) w \(.applicationName)",
                "Otwórz modlitwę za \(\.$target) w \(.applicationName)",
                "Zacznij modlitwę za \(\.$target) w \(.applicationName)",
                "I want to pray for \(\.$target) in \(.applicationName)",
                "Open prayer for \(\.$target) in \(.applicationName)",
                "Start \(\.$target) in \(.applicationName)",
                "Start prayer for \(\.$target) in \(.applicationName)",
                "Begin prayer for \(\.$target) in \(.applicationName)",
                "Begin praying for \(\.$target) in \(.applicationName)"
            ],
            shortTitle: "Rozpocznij modlitwę",
            systemImageName: "hands.sparkles"
        )
        AppShortcut(
            intent: LogCompletedPrayerIntent(),
            phrases: [
                "Zapisz modlitwę w \(.applicationName)",
                "Zaznacz modlitwę za \(\.$target) jako ukończoną w \(.applicationName)",
                "Dodałem modlitwę za \(\.$target) w \(.applicationName)",
                "I prayed for \(\.$target) in \(.applicationName)",
                "I finished prayer for \(\.$target) in \(.applicationName)",
                "Log prayer in \(.applicationName)",
                "Log completed prayer for \(\.$target) in \(.applicationName)",
                "Mark prayer for \(\.$target) as completed in \(.applicationName)",
                "Mark that I prayed for \(\.$target) in \(.applicationName)"
            ],
            shortTitle: "Zapisz modlitwę",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: PrayerStreakIntent(),
            phrases: [
                "Sprawdź serię modlitwy w \(.applicationName)",
                "Jak długa jest moja seria dla \(\.$target) w \(.applicationName)",
                "Pokaż serię modlitwy za \(\.$target) w \(.applicationName)",
                "How many weeks have I prayed for \(\.$target) in \(.applicationName)",
                "Prayer streak in \(.applicationName)",
                "Check prayer streak for \(\.$target) in \(.applicationName)",
                "How long is my prayer streak for \(\.$target) in \(.applicationName)",
                "What is my streak for \(\.$target) in \(.applicationName)"
            ],
            shortTitle: "Seria modlitwy",
            systemImageName: "flame"
        )
        AppShortcut(
            intent: AveragePrayerDurationIntent(),
            phrases: [
                "Sprawdź średni czas modlitwy w \(.applicationName)",
                "Jak długo zwykle modlę się za \(\.$target) w \(.applicationName)",
                "Pokaż średni czas dla \(\.$target) w \(.applicationName)",
                "How long do I usually pray for \(\.$target) in \(.applicationName)",
                "Average prayer time in \(.applicationName)",
                "Check average prayer duration for \(\.$target) in \(.applicationName)",
                "What is the average prayer duration for \(\.$target) in \(.applicationName)",
                "Tell me the average prayer time for \(\.$target) in \(.applicationName)"
            ],
            shortTitle: "Średni czas modlitwy",
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
            return "\(hours) godz. \(minutes) min"
        }
        if hours > 0 {
            return "\(hours) godz."
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

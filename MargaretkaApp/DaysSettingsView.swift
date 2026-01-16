//
//  DaysSettingsView.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 11/07/2025.
//

import SwiftUI

struct StatsView: View {
    @StateObject private var sessionStore = PrayerSessionStore()
    @State private var range: StatsRange = .last7

    var body: some View {
        let summary = PrayerStats(sessions: sessionStore.sessions, range: range, referenceDate: Date())

        ScrollView {
            VStack(spacing: 20) {
                header(summary: summary)

                Picker("Zakres", selection: $range) {
                    ForEach(StatsRange.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 16) {
                    statCard(title: "Sesje", value: "\(summary.totalSessions)", detail: "Aktywne tygodnie: \(summary.activeWeeks)")
                    statCard(title: "Ukonczone", value: "\(summary.completedSessions)", detail: "Skutecznosc: \(summary.completionRateText)")
                }

                weeklyStreakCard(summary: summary)

                HStack(spacing: 16) {
                    statCard(title: "Czas", value: summary.totalDurationText, detail: "Srednio: \(summary.averageDurationText)")
                    statCard(title: "Submodlitwy", value: "\(summary.totalSubprayers)", detail: "Srednio: \(summary.averageSubprayersText)")
                }

                checkpointAlertCard(summary: summary)
                recordsCard(summary: summary)
                favoritesCard(summary: summary)
                timeOfDayCard(summary: summary)
                activityCard(summary: summary)
                categoriesCard(summary: summary)
                milestonesCard(summary: summary)

                if summary.shouldShowYearSummary {
                    yearSummaryCard(summary: summary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .accessibilityIdentifier("stats_view")
        .background(
            LinearGradient(
                colors: [Color(red: 0.96, green: 0.98, blue: 1.0), Color(red: 0.90, green: 0.94, blue: 0.98)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Statystyki")
    }

    private func header(summary: PrayerStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Margaretka – rytm tygodnia")
                        .font(.title2.bold())
                    Text(summary.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ProgressRing(
                    progress: summary.progressToNextMilestone,
                    title: summary.nextMilestoneTitle,
                    subtitle: "Nastepny checkpoint"
                )
            }

            if let highlight = summary.highlightText {
                Text(highlight)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.6))
                    )
            }
        }
        .padding(20)
        .background(cardBackground(colors: [Color(red: 0.45, green: 0.66, blue: 0.92), Color(red: 0.58, green: 0.78, blue: 0.94)]))
    }


    private func weeklyStreakCard(summary: PrayerStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Seria tygodniowa")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(summary.currentWeeklyStreak) tyg")
                .font(.title2.bold())
            Text("Najdluzsza: \(summary.longestWeeklyStreak) tyg")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(cardBackground(colors: [Color.white.opacity(0.6), Color.white.opacity(0.3)]))
    }

    private func statCard(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(cardBackground(colors: [Color.white.opacity(0.6), Color.white.opacity(0.3)]))
    }


    private func checkpointAlertCard(summary: PrayerStats) -> some View {
        guard let title = summary.latestUnlockedMilestoneTitle else {
            return AnyView(EmptyView())
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("Checkpoint zaliczony")
                    .font(.headline)

                Text("Osiagnieto: \(title)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(cardBackground(colors: [Color(red: 0.95, green: 0.86, blue: 0.63), Color(red: 0.98, green: 0.93, blue: 0.80)]))
        )
    }

    private func recordsCard(summary: PrayerStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rekordy")
                .font(.headline)

            recordRow(title: "Najdluzsza sesja", value: summary.longestSessionText)
            recordRow(title: "Najdluzszy cel", value: summary.longestTargetName ?? "Brak danych")
        }
        .padding(16)
        .background(cardBackground(colors: [Color.white.opacity(0.7), Color.white.opacity(0.35)]))
    }

    private func recordRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.6))
        )
    }

    private func favoritesCard(summary: PrayerStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ulubione")
                .font(.headline)

            favoriteRow(title: "Kaplan", value: summary.favoritePriestTarget ?? summary.favoriteTarget ?? "Brak danych")
            favoriteRow(title: "Submodlitwa", value: summary.favoritePrayer ?? "Brak danych")
            favoriteRow(title: "Pora dnia", value: summary.favoriteTimeOfDay ?? "Brak danych")
            favoriteRow(title: "Kategoria", value: summary.favoriteCategory ?? "Brak danych")
        }
        .padding(16)
        .background(cardBackground(colors: [Color.white.opacity(0.7), Color.white.opacity(0.35)]))
    }

    private func favoriteRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.6))
        )
    }

    private func timeOfDayCard(summary: PrayerStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pora dnia")
                .font(.headline)

            HStack(alignment: .bottom, spacing: 12) {
                ForEach(summary.timeOfDayBuckets) { bucket in
                    VStack(spacing: 6) {
                        Capsule()
                            .fill(bucket.value == 0 ? Color.gray.opacity(0.25) : Color(red: 0.28, green: 0.56, blue: 0.82))
                            .frame(height: max(10, bucket.height))
                        Text(bucket.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(cardBackground(colors: [Color.white.opacity(0.7), Color.white.opacity(0.4)]))
    }

    private func activityCard(summary: PrayerStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Aktywnosc 7 dni")
                .font(.headline)

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(summary.lastSevenDays) { day in
                    VStack(spacing: 6) {
                        Capsule()
                            .fill(day.value == 0 ? Color.gray.opacity(0.25) : Color(red: 0.2, green: 0.45, blue: 0.85))
                            .frame(height: max(10, day.height))
                        Text(day.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(cardBackground(colors: [Color.white.opacity(0.7), Color.white.opacity(0.4)]))
    }

    private func categoriesCard(summary: PrayerStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kategorie")
                .font(.headline)

            ForEach(summary.categories, id: \.category) { entry in
                HStack {
                    Text(entry.title)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(entry.count)")
                        .font(.subheadline)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.6))
                )
            }
        }
        .padding(16)
        .background(cardBackground(colors: [Color.white.opacity(0.7), Color.white.opacity(0.35)]))
    }

    private func milestonesCard(summary: PrayerStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Checkpointy")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(summary.milestones) { milestone in
                        VStack(spacing: 6) {
                            Text(milestone.title)
                                .font(.subheadline.weight(.semibold))
                            Text(milestone.isUnlocked ? "Odblokowane" : "W toku")
                                .font(.caption)
                                .foregroundStyle(milestone.isUnlocked ? .green : .secondary)
                        }
                        .padding(14)
                        .frame(width: 140)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(milestone.isUnlocked ? Color.green.opacity(0.2) : Color.white.opacity(0.6))
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(cardBackground(colors: [Color.white.opacity(0.7), Color.white.opacity(0.35)]))
    }

    private func yearSummaryCard(summary: PrayerStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Podsumowanie roku")
                .font(.headline)

            Text("Sesje: \(summary.yearTotalSessions)")
                .font(.subheadline.weight(.semibold))
            Text("Czas: \(summary.yearTotalDurationText)")
                .font(.subheadline)
            Text("Najmocniejszy miesiac: \(summary.yearPeakMonth)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(cardBackground(colors: [Color.white.opacity(0.7), Color.white.opacity(0.35)]))
    }

    private func cardBackground(colors: [Color]) -> some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 6)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
            )
    }
}

struct ProgressRing: View {
    let progress: Double
    let title: String
    let subtitle: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.35), lineWidth: 8)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    LinearGradient(colors: [Color.white, Color.white.opacity(0.4)], startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(width: 74, height: 74)
    }
}

enum StatsRange: String, CaseIterable, Identifiable {
    case allTime
    case last7
    case last30

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allTime:
            return "Wszystko"
        case .last7:
            return "7 dni"
        case .last30:
            return "30 dni"
        }
    }

    func startDate(relativeTo date: Date, calendar: Calendar) -> Date? {
        switch self {
        case .allTime:
            return nil
        case .last7:
            return calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: date))
        case .last30:
            return calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: date))
        }
    }
}

struct PrayerStats {
    struct DayCount: Identifiable {
        let id = UUID()
        let label: String
        let value: Int
        let height: CGFloat
    }

    struct TimeBucket: Identifiable {
        let id = UUID()
        let label: String
        let value: Int
        let height: CGFloat
    }

    struct CategoryEntry {
        let category: PrayerTargetCategory
        let title: String
        let count: Int
    }

    struct Milestone: Identifiable {
        let id = UUID()
        let title: String
        let goal: Int
        let isUnlocked: Bool
    }

    let totalSessions: Int
    let completedSessions: Int
    let totalActiveDays: Int
    let activeWeeks: Int
    let currentWeeklyStreak: Int
    let longestWeeklyStreak: Int
    let totalDuration: TimeInterval
    let averageDuration: TimeInterval
    let totalSubprayers: Int
    let averageSubprayers: Double
    let longestSession: PrayerSession?
    let lastSevenDays: [DayCount]
    let timeOfDayBuckets: [TimeBucket]
    let categories: [CategoryEntry]
    let milestones: [Milestone]
    let nextMilestoneTitle: String
    let progressToNextMilestone: Double
    let latestUnlockedMilestoneTitle: String?
    let highlightText: String?
    let subtitle: String
    let favoritePrayer: String?
    let favoriteTarget: String?
    let favoritePriestTarget: String?
    let favoriteCategory: String?
    let favoriteTimeOfDay: String?
    let totalDurationText: String
    let averageDurationText: String
    let averageSubprayersText: String
    let completionRateText: String
    let longestSessionText: String
    let longestTargetName: String?
    let shouldShowYearSummary: Bool
    let yearTotalSessions: Int
    let yearTotalDurationText: String
    let yearPeakMonth: String

    init(sessions: [PrayerSession], range: StatsRange, referenceDate: Date) {
        let calendar = Calendar.current
        let rangeStart = range.startDate(relativeTo: referenceDate, calendar: calendar)
        let filteredSessions = sessions.filter { session in
            guard let start = rangeStart else { return true }
            return session.endedAt >= start
        }

        let perDay = PrayerStats.sessionsPerDay(filteredSessions, calendar: calendar)
        let sessionCount = filteredSessions.count
        let completedCount = filteredSessions.filter { $0.completed }.count
        let activeDays = perDay.keys.count

        let priestSessions = filteredSessions.filter { $0.targetCategory == .priest }
        let priestCompletedSessions = priestSessions.filter { $0.completed }
        let activeWeeksValue = PrayerStats.activeWeeks(from: priestCompletedSessions, calendar: calendar)
        let weeklyStreakValue = PrayerStats.currentWeeklyStreak(from: referenceDate, sessions: priestCompletedSessions, calendar: calendar)
        let longestWeeklyStreakValue = PrayerStats.longestWeeklyStreak(in: priestCompletedSessions, calendar: calendar)
        let totalDurationValue = filteredSessions.reduce(0) { $0 + $1.duration }
        let averageDurationValue = sessionCount > 0 ? totalDurationValue / Double(sessionCount) : 0
        let totalSubprayersValue = PrayerStats.totalCompletedSubprayers(filteredSessions)
        let averageSubprayersValue = sessionCount > 0 ? Double(totalSubprayersValue) / Double(sessionCount) : 0
        let longestSessionValue = filteredSessions.max(by: { $0.duration < $1.duration })

        let lastSeven = PrayerStats.lastDays(count: 7, referenceDate: referenceDate, calendar: calendar)
        let maxValue = max(lastSeven.map { perDay[$0, default: 0] }.max() ?? 1, 1)
        let lastSevenDaysValue = lastSeven.map { day in
            let value = perDay[day, default: 0]
            let height = CGFloat(value) / CGFloat(maxValue) * 64
            return DayCount(label: PrayerStats.shortLabel(for: day), value: value, height: height)
        }

        let timeBucketsValue = PrayerStats.timeBuckets(filteredSessions)

        let perCategory = PrayerStats.countByCategory(filteredSessions)
        let categoriesValue = PrayerTargetCategory.allCases.map { category in
            CategoryEntry(
                category: category,
                title: category.displayName,
                count: perCategory[category, default: 0]
            )
        }

        let goals = [3, 7, 14, 30, 60, 100, 180, 365]
        let milestonesValue = goals.map { goal in
            Milestone(title: "\(goal) tyg", goal: goal, isUnlocked: activeWeeksValue >= goal)
        }
        let latestUnlockedTitleValue = goals.filter { activeWeeksValue >= $0 }.max().map { "\($0) tyg" }

        let nextMilestoneTitleValue: String
        let progressValue: Double
        if let next = goals.first(where: { activeDays < $0 }) {
            nextMilestoneTitleValue = "\(next) tyg"
            progressValue = activeDays == 0 ? 0 : Double(activeDays) / Double(next)
        } else {
            nextMilestoneTitleValue = "Cel osiagniety"
            progressValue = 1.0
        }

        let favoritePrayerValue = PrayerStats.favoritePrayerName(in: filteredSessions)
        let favoriteTargetValue = PrayerStats.favoriteTargetName(in: filteredSessions)
        let favoriteCategoryValue = PrayerStats.favoriteCategoryName(in: filteredSessions)
        let favoriteTimeOfDayValue = PrayerStats.favoriteTimeBucketName(in: filteredSessions)

        let totalDurationTextValue = PrayerStats.formatDuration(totalDurationValue)
        let averageDurationTextValue = PrayerStats.formatDuration(averageDurationValue)
        let averageSubprayersTextValue = PrayerStats.formatSubprayers(averageSubprayersValue)

        let highlightValue: String?
        if sessionCount == 0 {
            highlightValue = "Zacznij od pierwszej sesji, aby uruchomic statystyki."
        } else if completedCount >= 7 {
            highlightValue = "Masz \(weeklyStreakValue) tygodni z modlitwa za kaplanow."
        } else if sessionCount >= 3 {
            highlightValue = "Swietny start - \(sessionCount) sesje modlitwy."
        } else {
            highlightValue = nil
        }

        let subtitleValue = range == .allTime ? "Caly czas" : "Ostatnie \(range == .last7 ? "7" : "30") dni"
        let completionRateValue = PrayerStats.formatCompletionRate(completed: completedCount, total: sessionCount)
        let longestSessionTextValue = PrayerStats.formatDuration(longestSessionValue?.duration ?? 0)
        let longestTargetNameValue = longestSessionValue?.targetName

        let yearWindow = PrayerStats.yearWindow(for: referenceDate, calendar: calendar)
        let shouldShowYearSummaryValue = yearWindow.contains(calendar.startOfDay(for: referenceDate))
        let yearlySessions = PrayerStats.sessionsInYear(sessions, referenceDate: referenceDate, calendar: calendar)
        let yearTotalSessionsValue = yearlySessions.count
        let yearTotalDurationTextValue = PrayerStats.formatDuration(yearlySessions.reduce(0) { $0 + $1.duration })
        let yearPeakMonthValue = PrayerStats.peakMonthName(for: yearlySessions, calendar: calendar)

        totalSessions = sessionCount
        completedSessions = completedCount
        totalActiveDays = activeDays
        activeWeeks = activeWeeksValue
        currentWeeklyStreak = weeklyStreakValue
        longestWeeklyStreak = longestWeeklyStreakValue
        totalDuration = totalDurationValue
        averageDuration = averageDurationValue
        totalSubprayers = totalSubprayersValue
        averageSubprayers = averageSubprayersValue
        longestSession = longestSessionValue
        lastSevenDays = lastSevenDaysValue
        timeOfDayBuckets = timeBucketsValue
        categories = categoriesValue
        milestones = milestonesValue
        latestUnlockedMilestoneTitle = latestUnlockedTitleValue
        nextMilestoneTitle = nextMilestoneTitleValue
        progressToNextMilestone = progressValue
        highlightText = highlightValue
        subtitle = subtitleValue
        favoritePrayer = favoritePrayerValue
        favoriteTarget = favoriteTargetValue
        favoritePriestTarget = PrayerStats.favoriteTargetName(in: priestCompletedSessions)
        favoriteCategory = favoriteCategoryValue
        favoriteTimeOfDay = favoriteTimeOfDayValue
        totalDurationText = totalDurationTextValue
        averageDurationText = averageDurationTextValue
        averageSubprayersText = averageSubprayersTextValue
        completionRateText = completionRateValue
        longestSessionText = longestSessionTextValue
        longestTargetName = longestTargetNameValue
        shouldShowYearSummary = shouldShowYearSummaryValue
        yearTotalSessions = yearTotalSessionsValue
        yearTotalDurationText = yearTotalDurationTextValue
        yearPeakMonth = yearPeakMonthValue
    }


    private static func activeWeeks(from sessions: [PrayerSession], calendar: Calendar) -> Int {
        let keys = Set(sessions.map { weekKey(for: $0.endedAt, calendar: calendar) })
        return keys.count
    }

    private static func currentWeeklyStreak(from referenceDate: Date, sessions: [PrayerSession], calendar: Calendar) -> Int {
        let weekKeys = Set(sessions.map { weekKey(for: $0.endedAt, calendar: calendar) })
        var streak = 0
        var current = weekKey(for: referenceDate, calendar: calendar)

        while weekKeys.contains(current) {
            streak += 1
            current = previousWeekKey(from: current, calendar: calendar)
        }
        return streak
    }

    private static func longestWeeklyStreak(in sessions: [PrayerSession], calendar: Calendar) -> Int {
        let weekKeys = sessions.map { weekKey(for: $0.endedAt, calendar: calendar) }
        let sorted = Array(Set(weekKeys)).sorted()
        guard let first = sorted.first else { return 0 }

        var longest = 1
        var current = 1
        var prev = first

        for key in sorted.dropFirst() {
            let next = nextWeekKey(from: prev, calendar: calendar)
            if next == key {
                current += 1
            } else {
                current = 1
            }
            longest = max(longest, current)
            prev = key
        }
        return longest
    }

    private static func weekKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let year = components.yearForWeekOfYear ?? 0
        let week = components.weekOfYear ?? 0
        return String(format: "%04d-%02d", year, week)
    }

    private static func previousWeekKey(from key: String, calendar: Calendar) -> String {
        guard let date = date(fromWeekKey: key, calendar: calendar) else { return key }
        let prev = calendar.date(byAdding: .weekOfYear, value: -1, to: date) ?? date
        return weekKey(for: prev, calendar: calendar)
    }

    private static func nextWeekKey(from key: String, calendar: Calendar) -> String {
        guard let date = date(fromWeekKey: key, calendar: calendar) else { return key }
        let next = calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        return weekKey(for: next, calendar: calendar)
    }

    private static func date(fromWeekKey key: String, calendar: Calendar) -> Date? {
        let parts = key.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let week = Int(parts[1]) else { return nil }
        var components = DateComponents()
        components.yearForWeekOfYear = year
        components.weekOfYear = week
        components.weekday = calendar.firstWeekday
        return calendar.date(from: components)
    }

    private static func sessionsPerDay(_ sessions: [PrayerSession], calendar: Calendar) -> [Date: Int] {
        var perDay: [Date: Int] = [:]
        for session in sessions {
            let day = calendar.startOfDay(for: session.endedAt)
            perDay[day, default: 0] += 1
        }
        return perDay
    }

    private static func totalCompletedSubprayers(_ sessions: [PrayerSession]) -> Int {
        sessions.reduce(0) { $0 + $1.completedSubprayerCount }
    }

    private static func countByCategory(_ sessions: [PrayerSession]) -> [PrayerTargetCategory: Int] {
        var counts: [PrayerTargetCategory: Int] = [:]
        for session in sessions {
            counts[session.targetCategory, default: 0] += 1
        }
        return counts
    }

    private static func favoritePrayerName(in sessions: [PrayerSession]) -> String? {
        var counts: [String: Int] = [:]
        for session in sessions {
            let limit = min(session.completedSubprayerCount, session.prayerNames.count)
            for name in session.prayerNames.prefix(limit) where !name.isEmpty {
                counts[name, default: 0] += 1
            }
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    private static func favoriteTargetName(in sessions: [PrayerSession]) -> String? {
        var counts: [String: Int] = [:]
        for session in sessions {
            counts[session.targetName, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    private static func favoriteCategoryName(in sessions: [PrayerSession]) -> String? {
        var counts: [PrayerTargetCategory: Int] = [:]
        for session in sessions {
            counts[session.targetCategory, default: 0] += 1
        }
        guard let best = counts.max(by: { $0.value < $1.value })?.key else { return nil }
        return best.displayName
    }

    private static func timeBuckets(_ sessions: [PrayerSession]) -> [TimeBucket] {
        let labels = ["Noc", "Rano", "Popoludnie", "Wieczor"]
        var counts = Array(repeating: 0, count: labels.count)

        for session in sessions {
            let hour = Calendar.current.component(.hour, from: session.startedAt)
            let index: Int
            switch hour {
            case 0...5:
                index = 0
            case 6...11:
                index = 1
            case 12...17:
                index = 2
            default:
                index = 3
            }
            counts[index] += 1
        }

        let maxValue = max(counts.max() ?? 1, 1)
        return counts.enumerated().map { idx, value in
            TimeBucket(label: labels[idx], value: value, height: CGFloat(value) / CGFloat(maxValue) * 64)
        }
    }

    private static func favoriteTimeBucketName(in sessions: [PrayerSession]) -> String? {
        let buckets = timeBuckets(sessions)
        return buckets.max(by: { $0.value < $1.value })?.label
    }

    private static func formatDuration(_ duration: TimeInterval) -> String {
        guard duration > 0 else { return "0 min" }
        let totalMinutes = Int(duration / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private static func formatSubprayers(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private static func formatCompletionRate(completed: Int, total: Int) -> String {
        guard total > 0 else { return "0%" }
        let percent = (Double(completed) / Double(total)) * 100
        return String(format: "%.0f%%", percent)
    }

    private static func lastDays(count: Int, referenceDate: Date, calendar: Calendar) -> [Date] {
        guard count > 0 else { return [] }
        let start = calendar.startOfDay(for: referenceDate)
        return (0..<count).compactMap { offset in
            calendar.date(byAdding: .day, value: -(count - 1 - offset), to: start)
        }
    }

    private static func shortLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EE"
        return formatter.string(from: date).uppercased()
    }

    private static func yearWindow(for date: Date, calendar: Calendar) -> ClosedRange<Date> {
        let year = calendar.component(.year, from: date)
        let startComponents = DateComponents(year: year, month: 12, day: 24)
        let endComponents = DateComponents(year: year, month: 12, day: 31)
        let start = calendar.date(from: startComponents) ?? date
        let end = calendar.date(from: endComponents) ?? date
        return calendar.startOfDay(for: start)...calendar.startOfDay(for: end)
    }

    private static func sessionsInYear(_ sessions: [PrayerSession], referenceDate: Date, calendar: Calendar) -> [PrayerSession] {
        let year = calendar.component(.year, from: referenceDate)
        return sessions.filter { calendar.component(.year, from: $0.endedAt) == year }
    }

    private static func peakMonthName(for sessions: [PrayerSession], calendar: Calendar) -> String {
        guard !sessions.isEmpty else { return "-" }
        var counts: [Int: Int] = [:]
        for session in sessions {
            let month = calendar.component(.month, from: session.endedAt)
            counts[month, default: 0] += 1
        }
        let bestMonth = counts.max(by: { $0.value < $1.value })?.key ?? 1
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL"
        let comps = DateComponents(year: calendar.component(.year, from: Date()), month: bestMonth, day: 1)
        return formatter.string(from: calendar.date(from: comps) ?? Date())
    }
}

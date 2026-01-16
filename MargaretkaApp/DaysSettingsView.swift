//
//  DaysSettingsView.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 11/07/2025.
//

import SwiftUI

struct StatsView: View {
    @StateObject private var scheduleData = ScheduleData<Priest>(saveKey: Priest.storageKey)

    var body: some View {
        let summary = PrayerStats(items: scheduleData.items, referenceDate: Date())

        ScrollView {
            VStack(spacing: 20) {
                header(summary: summary)

                HStack(spacing: 16) {
                    statCard(title: "Aktualna seria", value: "\(summary.currentStreak) dni", detail: "Najdluzsza: \(summary.longestStreak)")
                    statCard(title: "Modlitwy lacznie", value: "\(summary.totalCompletions)", detail: "Dni aktywne: \(summary.totalActiveDays)")
                }

                activityCard(summary: summary)
                categoriesCard(summary: summary)
                milestonesCard(summary: summary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
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
                    Text("Twoja droga modlitwy")
                        .font(.title2.bold())
                    Text("Sprawdz rytm i postepy")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ProgressRing(
                    progress: summary.progressToNextMilestone,
                    title: summary.nextMilestoneTitle,
                    subtitle: "Nastepny cel"
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
            Text("Nagrody i checkpointy")
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

struct PrayerStats {
    struct DayCount: Identifiable {
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

    let totalCompletions: Int
    let totalActiveDays: Int
    let currentStreak: Int
    let longestStreak: Int
    let lastSevenDays: [DayCount]
    let categories: [CategoryEntry]
    let milestones: [Milestone]
    let nextMilestoneTitle: String
    let progressToNextMilestone: Double
    let highlightText: String?

    init(items: [Priest], referenceDate: Date) {
        let calendar = Calendar.current
        var perDay: [Date: Int] = [:]
        var perCategory: [PrayerTargetCategory: Int] = [:]

        for item in items {
            for id in item.notificationIdsFinished {
                if let date = PrayerStats.date(from: id) {
                    let day = calendar.startOfDay(for: date)
                    perDay[day, default: 0] += 1
                    perCategory[item.category, default: 0] += 1
                }
            }
        }

        totalCompletions = perDay.values.reduce(0, +)
        totalActiveDays = perDay.keys.count

        let sortedDays = perDay.keys.sorted()
        longestStreak = PrayerStats.longestStreak(in: sortedDays, calendar: calendar)
        currentStreak = PrayerStats.currentStreak(from: referenceDate, days: perDay.keys, calendar: calendar)

        let lastSeven = PrayerStats.lastDays(count: 7, referenceDate: referenceDate, calendar: calendar)
        let maxValue = max(lastSeven.map { perDay[$0, default: 0] }.max() ?? 1, 1)
        lastSevenDays = lastSeven.map { day in
            let value = perDay[day, default: 0]
            let height = CGFloat(value) / CGFloat(maxValue) * 64
            return DayCount(label: PrayerStats.shortLabel(for: day), value: value, height: height)
        }

        categories = PrayerTargetCategory.allCases.map { category in
            CategoryEntry(
                category: category,
                title: category.displayName,
                count: perCategory[category, default: 0]
            )
        }

        let goals = [3, 7, 14, 30, 60, 100, 180, 365]
        milestones = goals.map { goal in
            Milestone(title: "\(goal) dni", goal: goal, isUnlocked: totalActiveDays >= goal)
        }

        if let next = goals.first(where: { totalActiveDays < $0 }) {
            nextMilestoneTitle = "\(next) dni"
            progressToNextMilestone = Double(totalActiveDays) / Double(next)
        } else {
            nextMilestoneTitle = "Cel osiagniety"
            progressToNextMilestone = 1.0
        }

        if totalActiveDays == 0 {
            highlightText = "Zacznij od pierwszej modlitwy, aby uruchomic statystyki."
        } else if currentStreak >= 7 {
            highlightText = "Masz serie \(currentStreak) dni. Trzymaj tempo!"
        } else if totalActiveDays >= 3 {
            highlightText = "Swietny start - \(totalActiveDays) aktywnych dni."
        } else {
            highlightText = nil
        }
    }

    private static func date(from notificationId: String) -> Date? {
        let pattern = #"\d{2}\.\d{2}\.\d{4}"#
        guard let range = notificationId.range(of: pattern, options: .regularExpression) else {
            return nil
        }
        let dateString = String(notificationId[range])
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.date(from: dateString)
    }

    private static func currentStreak(from referenceDate: Date, days: Set<Date>, calendar: Calendar) -> Int {
        var streak = 0
        var cursor = calendar.startOfDay(for: referenceDate)

        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    private static func longestStreak(in days: [Date], calendar: Calendar) -> Int {
        guard let first = days.first else { return 0 }
        var longest = 1
        var current = 1
        var previous = first

        for day in days.dropFirst() {
            if let next = calendar.date(byAdding: .day, value: 1, to: previous), next == day {
                current += 1
            } else {
                current = 1
            }
            longest = max(longest, current)
            previous = day
        }
        return longest
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
}

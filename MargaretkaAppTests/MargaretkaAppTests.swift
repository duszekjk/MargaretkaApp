//
//  MargaretkaAppTests.swift
//  MargaretkaAppTests
//
//  Created by Jacek Kauny on 11/07/2025.
//

import Foundation
import Testing
@testable import MargaretkaApp

struct MargaretkaAppTests {

    @Test func statsFiltersByRange() async throws {
        let calendar = Calendar.current
        let referenceDate = calendar.date(from: DateComponents(year: 2025, month: 9, day: 1))!
        let recent = makeSession(endedAt: referenceDate, completed: true)
        let oldDate = calendar.date(byAdding: .weekOfYear, value: -9, to: referenceDate)!
        let old = makeSession(endedAt: oldDate, completed: true)

        let stats = PrayerStats(sessions: [recent, old], range: .last8Weeks, referenceDate: referenceDate)

        #expect(stats.totalSessions == 1)
    }

    @Test func statsFavoritePrayerUsesCompletedSubprayers() async throws {
        let date = Date()
        let first = makeSession(
            endedAt: date,
            completed: true,
            prayerNames: ["A", "B"],
            completedSubprayerCount: 1
        )
        let second = makeSession(
            endedAt: date,
            completed: true,
            prayerNames: ["A"],
            completedSubprayerCount: 1
        )

        let stats = PrayerStats(sessions: [first, second], range: .allTime, referenceDate: date)

        #expect(stats.favoritePrayer == "A")
    }

    
    @Test func weeklyStreakCountsPriestWeeks() async throws {
        let calendar = Calendar.current
        let referenceDate = calendar.date(from: DateComponents(year: 2025, month: 9, day: 3))!
        let weekStart = calendar.date(from: DateComponents(year: 2025, month: 9, day: 1))!
        let previousWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart)!

        let priestSession = makeSession(endedAt: weekStart, completed: true, category: .priest)
        let priestPrev = makeSession(endedAt: previousWeek, completed: true, category: .priest)
        let otherCategory = makeSession(endedAt: weekStart, completed: true, category: .person)

        let stats = PrayerStats(sessions: [priestSession, priestPrev, otherCategory], range: .allTime, referenceDate: referenceDate)

        #expect(stats.currentWeeklyStreak == 2)
        #expect(stats.activeWeeks == 2)
    }

@Test func statsCompletionRate() async throws {
        let date = Date()
        let completed = makeSession(endedAt: date, completed: true)
        let incomplete = makeSession(endedAt: date, completed: false)

        let stats = PrayerStats(sessions: [completed, incomplete], range: .allTime, referenceDate: date)

        #expect(stats.completedSessions == 1)
        #expect(stats.completionRateText == "50%")
    }

    @Test func yearSummaryVisibility() async throws {
        let calendar = Calendar.current
        let inWindow = calendar.date(from: DateComponents(year: 2025, month: 12, day: 26))!
        let outWindow = calendar.date(from: DateComponents(year: 2025, month: 12, day: 1))!

        let statsInWindow = PrayerStats(sessions: [], range: .allTime, referenceDate: inWindow)
        let statsOutWindow = PrayerStats(sessions: [], range: .allTime, referenceDate: outWindow)

        #expect(statsInWindow.shouldShowYearSummary == true)
        #expect(statsOutWindow.shouldShowYearSummary == false)
    }

    private func makeSession(
        endedAt: Date,
        completed: Bool,
        prayerNames: [String] = ["A"],
        completedSubprayerCount: Int = 1,
        category: PrayerTargetCategory = .priest
    ) -> PrayerSession {
        PrayerSession(
            id: UUID(),
            targetId: UUID(),
            targetName: "Target",
            targetCategory: category,
            prayerIds: prayerNames.map { _ in UUID() },
            prayerNames: prayerNames,
            startedAt: endedAt.addingTimeInterval(-600),
            endedAt: endedAt,
            duration: 600,
            totalSubprayerCount: prayerNames.count,
            completedSubprayerCount: completedSubprayerCount,
            completed: completed,
            completion: completed ? .finished : .abandoned
        )
    }
}

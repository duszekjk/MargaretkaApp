//
//  MargaretkaAppTests.swift
//  MargaretkaAppTests
//
//  Created by Jacek Kauny on 11/07/2025.
//

import Foundation
import Testing
import UIKit
@testable import MargaretkaApp

private struct TestSchedulable: Schedulable {
    var id = UUID()
    var schedule = SchedulePlan()
    var lastModified = Date()
    var notificationIds: [String] = []
    var notificationIdsFinished: [String] = []
    var notificationTitle = "Test"
    var notificationMessage = ""
    var notificationSound: String?
    let notificationTypeId = "Test"
}

@MainActor
struct MargaretkaAppTests {

    @Test func databaseCompressionRoundTripsAndAcceptsLegacyPayloads() throws {
        let raw = Data(repeating: 0x41, count: 20_000)

        let stored = try LocalDatabase.storedPayload(from: raw)

        #expect(LocalDatabase.isCompressedPayload(stored))
        #expect(stored.count < raw.count)
        #expect(try LocalDatabase.unpackedPayload(from: stored) == raw)
        #expect(try LocalDatabase.unpackedPayload(from: raw) == raw)
    }

    @Test func persistedPhotoHonorsByteAndDimensionLimits() throws {
        let source = UIGraphicsImageRenderer(size: CGSize(width: 1_200, height: 900)).image { context in
            UIColor.systemIndigo.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1_200, height: 900))
            UIColor.systemYellow.setFill()
            for offset in stride(from: 0, to: 1_200, by: 40) {
                context.fill(CGRect(x: offset, y: 0, width: 20, height: 900))
            }
        }

        let data = try #require(source.storageJPEGData())
        let storedImage = try #require(UIImage(data: data))

        #expect(data.count <= UIImage.storagePhotoByteLimit)
        #expect(max(storedImage.size.width, storedImage.size.height) <= 552)
    }

    @Test func displayPhotoCacheKeysSeparateDifferentTargetsAndAssets() {
        let updatedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let firstAssetID = UUID()
        let first = Priest(
            id: UUID(), firstName: "Pierwsza", lastName: "", title: "",
            category: .prayer, photoAssetID: firstAssetID, photoUpdatedAt: updatedAt,
            assignedPrayerGroups: [], schedule: SchedulePlan(), lastModified: updatedAt,
            notificationTitle: "", notificationMessage: ""
        )
        let second = Priest(
            id: UUID(), firstName: "Druga", lastName: "", title: "",
            category: .prayer, photoUpdatedAt: updatedAt,
            assignedPrayerGroups: [], schedule: SchedulePlan(), lastModified: updatedAt,
            notificationTitle: "", notificationMessage: ""
        )

        #expect(first.displayPhotoCacheKey != second.displayPhotoCacheKey)
        var replacement = first
        replacement.photoAssetID = UUID()
        #expect(first.displayPhotoCacheKey != replacement.displayPhotoCacheKey)
    }

    @Test func bundledPrayerArtworkIsNotPersisted() {
        let pngSignature = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let legacyPNG = pngSignature + Data(repeating: 0, count: 50_000)
        let target = Priest(
            id: UUID(),
            firstName: "Różaniec",
            lastName: "",
            title: "",
            category: .prayer,
            photoData: legacyPNG,
            assignedPrayerGroups: [],
            schedule: SchedulePlan(),
            lastModified: Date(),
            notificationTitle: "Różaniec",
            notificationMessage: ""
        )

        #expect(target.compactedForStorage().photoData == nil)
        #expect(peopleTemplates.allSatisfy { $0.photoData == nil })
    }

    @Test func koronkaDefaultsToThreePM() {
        let suggestion = PrayerTimeSuggestion.matching("Koronka do Miłosierdzia Bożego")

        #expect(suggestion == PrayerTimeSuggestion(hour: 15, minute: 0))
    }

    @Test func prayerSuggestionsIgnorePolishDiacriticsAndCase() {
        let angelus = PrayerTimeSuggestion.matching("ANIOŁ PAŃSKI")
        let compline = PrayerTimeSuggestion.matching("Kompleta")

        #expect(angelus == PrayerTimeSuggestion(hour: 12, minute: 0))
        #expect(compline == PrayerTimeSuggestion(hour: 21, minute: 0))
    }

    @Test func userSelectedTimeOverridesLaterNameSuggestions() {
        var plan = SchedulePlan.suggested(forPrayerName: "Różaniec")
        plan.times[0].event = DateComponents(hour: 8, minute: 30)
        plan.markTimeAsUserSelected()

        plan.applyPrayerTimeSuggestion(for: "Koronka")

        #expect(plan.times[0].event.hour == 8)
        #expect(plan.times[0].event.minute == 30)
        #expect(plan.timeSelectionSource == .user)
    }

    @Test func weeklyScheduleWithNoSelectedDaysCreatesNoNotifications() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 9, hour: 10))!
        var item = TestSchedulable()
        item.schedule.frequencyUnit = .weekly
        item.schedule.daysOfWeek = []
        item.schedule.startDate = now
        item.schedule.endDate = calendar.date(byAdding: .month, value: 1, to: now)
        item.schedule.times = [NotificationTimes(event: DateComponents(hour: 11, minute: 0))]

        let notifications = computeUpcomingNotifications(
            for: item,
            title: item.notificationTitle,
            now: now,
            calendar: calendar
        )

        #expect(notifications.isEmpty)
    }

    @Test func restoringDefaultsRepairsEveryBuiltInPrayerTarget() {
        let prayerTemplates = Array(prayersTemplate.values)
        let defaultPrayerTargets = peopleTemplates.filter { $0.category == .prayer }
        let staleTargets = defaultPrayerTargets.map { template -> Priest in
            var target = template
            target.assignedPrayerGroups = []
            return target
        }

        let restored = PriestStore.restoringDefaultPrayerTargets(
            in: staleTargets,
            using: prayerTemplates,
            modificationDate: Date(timeIntervalSince1970: 1_700_000_000)
        )

        #expect(restored.count == defaultPrayerTargets.count)
        for template in defaultPrayerTargets {
            let restoredTarget = restored.priests.first {
                Priest.templateKey(for: $0) == Priest.templateKey(for: template)
            }
            #expect(restoredTarget?.assignedPrayerGroups == template.assignedPrayerGroups)
        }
    }

    @Test func rosaryMysteriesFollowTheTraditionalWeekdayCycle() throws {
        let calendar = Calendar(identifier: .gregorian)
        func date(_ day: Int) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 8, day: day))!
        }

        #expect(RosaryMysterySet.forToday(calendar: calendar, date: date(3)) == .joyful) // Monday
        #expect(RosaryMysterySet.forToday(calendar: calendar, date: date(4)) == .sorrowful) // Tuesday
        #expect(RosaryMysterySet.forToday(calendar: calendar, date: date(5)) == .glorious) // Wednesday
        #expect(RosaryMysterySet.forToday(calendar: calendar, date: date(6)) == .luminous) // Thursday
        #expect(RosaryMysterySet.forToday(calendar: calendar, date: date(7)) == .sorrowful) // Friday
        #expect(RosaryMysterySet.forToday(calendar: calendar, date: date(8)) == .joyful) // Saturday
        #expect(RosaryMysterySet.forToday(calendar: calendar, date: date(9)) == .glorious) // Sunday
    }

    @Test func everyRosaryMysteryVariantHasFiveMysterySteps() {
        let variants = peopleTemplates.filter { target in
            RosaryMysterySet.allCases.contains { set in
                PrayerLanguage.allCases.contains { target.firstName == set.variantName(language: $0) }
            }
        }

        #expect(variants.count == RosaryMysterySet.allCases.count * PrayerLanguage.allCases.count)
        for variant in variants {
            #expect(variant.assignedPrayerGroups.count == 23)
        }
    }

    @Test func notificationRouteWaitsUntilConsumed() {
        let store = UserDefaults(suiteName: "PrayerNotificationRouterTests")!
        store.removePersistentDomain(forName: "PrayerNotificationRouterTests")
        let router = PrayerNotificationRouter(store: store)
        let itemId = UUID()

        router.requestPrayer(itemId: itemId.uuidString)
        let route = router.pendingRoute

        #expect(route?.itemId == itemId)
        if let route {
            router.consume(route)
        }
        #expect(router.pendingRoute == nil)
    }

    @Test func notificationRouteSurvivesIntentToAppHandoff() {
        let store = UserDefaults(suiteName: "PrayerNotificationRouterPersistenceTests")!
        store.removePersistentDomain(forName: "PrayerNotificationRouterPersistenceTests")
        let itemId = UUID()

        let intentProcessRouter = PrayerNotificationRouter(store: store)
        intentProcessRouter.requestPrayer(itemId: itemId.uuidString)
        let appProcessRouter = PrayerNotificationRouter(store: store)

        #expect(appProcessRouter.pendingRoute?.itemId == itemId)
        if let route = appProcessRouter.pendingRoute {
            appProcessRouter.consume(route)
        }
        #expect(PrayerNotificationRouter(store: store).pendingRoute == nil)
    }

    @Test func shortcutStatisticsAreTargetSpecificAndIgnoreUntimedAverages() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 7, day: 13, hour: 12))!
        let targetId = UUID()
        let otherTargetId = UUID()
        let timed = makeSession(
            endedAt: now,
            completed: true,
            duration: 600,
            targetId: targetId
        )
        let untimed = makeSession(
            endedAt: now,
            completed: true,
            duration: 0,
            targetId: targetId
        )
        let other = makeSession(
            endedAt: now,
            completed: true,
            duration: 3600,
            targetId: otherTargetId
        )

        let stats = PrayerShortcutStatistics.calculate(
            targetId: targetId,
            sessions: [timed, untimed, other],
            referenceDate: now,
            calendar: calendar
        )

        #expect(stats.completedSessionCount == 2)
        #expect(stats.currentWeeklyStreak == 1)
        #expect(stats.averageMeasuredDuration == 600)
    }

    @Test func shortcutSessionRecordsTheSelectedTargetAndDuration() {
        let prayer = Prayer(
            name: "Testowa modlitwa",
            text: "Tekst",
            symbol: "hands.sparkles",
            audioFilename: nil,
            audioSource: nil,
            timestampedLines: nil
        )
        let target = Priest(
            id: UUID(),
            firstName: "Jan",
            lastName: "Kowalski",
            title: "ks.",
            assignedPrayerGroups: [AssignedPrayerGroup(prayerIds: [prayer.id])],
            schedule: SchedulePlan(),
            lastModified: Date(),
            notificationTitle: "Modlitwa",
            notificationMessage: "Pomódl się"
        )
        let now = Date()

        let session = PrayerShortcutRepository.makeCompletedSession(
            target: target,
            prayers: [prayer],
            durationMinutes: 12,
            now: now
        )

        #expect(session.targetId == target.id)
        #expect(session.prayerNames == [prayer.name])
        #expect(session.duration == 720)
        #expect(session.completedSubprayerCount == 1)
        #expect(session.completed)
    }

    @Test func statsFiltersByRange() async throws {
        let calendar = Calendar.current
        let referenceDate = calendar.date(from: DateComponents(year: 2025, month: 9, day: 1))!
        let recent = makeSession(endedAt: referenceDate, completed: true)
        let oldDate = calendar.date(byAdding: .weekOfYear, value: -9, to: referenceDate)!
        let old = makeSession(endedAt: oldDate, completed: true)

        let stats = PrayerStats(sessions: [recent, old], range: .last8Weeks, referenceDate: referenceDate, focusCategory: .priest)

        #expect(stats.totalSessions == 1)
    }

    @Test func rangeFilterDoesNotTruncateLifetimeAchievements() {
        let calendar = Calendar.current
        let referenceDate = calendar.date(from: DateComponents(year: 2025, month: 7, day: 15, hour: 12))!
        let previousFriday = calendar.date(from: DateComponents(year: 2025, month: 7, day: 11, hour: 18))!
        let sessions = (0..<14).map { offset in
            let date = calendar.date(byAdding: .weekOfYear, value: -offset, to: previousFriday)!
            return makeSession(endedAt: date, completed: true, category: .priest)
        }

        let stats = PrayerStats(sessions: sessions, range: .last8Weeks, referenceDate: referenceDate, focusCategory: .priest)

        #expect(stats.totalSessions == 7)
        #expect(stats.activeWeeks == 7)
        #expect(stats.currentWeeklyStreak == 14)
        #expect(stats.longestWeeklyStreak == 14)
        #expect(stats.latestUnlockedMilestoneTitle == "14 tyg")
        #expect(stats.nextMilestoneTitle == "30 tyg")
        #expect(abs(stats.progressToNextMilestone - 14.0 / 30.0) < 0.000_001)
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

        let stats = PrayerStats(sessions: [first, second], range: .allTime, referenceDate: date, focusCategory: .priest)

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

        let stats = PrayerStats(sessions: [priestSession, priestPrev, otherCategory], range: .allTime, referenceDate: referenceDate, focusCategory: .priest)

        #expect(stats.currentWeeklyStreak == 2)
        #expect(stats.activeWeeks == 2)
    }

    @Test func weeklyStreakWaitsEightDaysBeforeExpiring() {
        let calendar = Calendar.current
        let previousFriday = calendar.date(from: DateComponents(year: 2025, month: 7, day: 11, hour: 18))!
        let fridayBefore = calendar.date(byAdding: .day, value: -7, to: previousFriday)!
        let followingTuesday = calendar.date(from: DateComponents(year: 2025, month: 7, day: 15, hour: 12))!
        let justInsideGracePeriod = previousFriday.addingTimeInterval(8 * 24 * 60 * 60 - 60)
        let afterGracePeriod = previousFriday.addingTimeInterval(8 * 24 * 60 * 60 + 60)
        let sessions = [
            makeSession(endedAt: fridayBefore, completed: true, category: .priest),
            makeSession(endedAt: previousFriday, completed: true, category: .priest)
        ]

        let tuesdayStats = PrayerStats(sessions: sessions, range: .allTime, referenceDate: followingTuesday, focusCategory: .priest)
        let insideGraceStats = PrayerStats(sessions: sessions, range: .allTime, referenceDate: justInsideGracePeriod, focusCategory: .priest)
        let expiredStats = PrayerStats(sessions: sessions, range: .allTime, referenceDate: afterGracePeriod, focusCategory: .priest)

        #expect(tuesdayStats.currentWeeklyStreak == 2)
        #expect(insideGraceStats.currentWeeklyStreak == 2)
        #expect(expiredStats.currentWeeklyStreak == 0)
    }

@Test func statsCompletionRate() async throws {
        let date = Date()
        let completed = makeSession(endedAt: date, completed: true)
        let incomplete = makeSession(endedAt: date, completed: false)

        let stats = PrayerStats(sessions: [completed, incomplete], range: .allTime, referenceDate: date, focusCategory: .priest)

        #expect(stats.completedSessions == 1)
        #expect(stats.completionRateText == "50%")
    }

    @Test func yearSummaryVisibility() async throws {
        let calendar = Calendar.current
        let inWindow = calendar.date(from: DateComponents(year: 2025, month: 12, day: 26))!
        let outWindow = calendar.date(from: DateComponents(year: 2025, month: 12, day: 1))!

        let statsInWindow = PrayerStats(sessions: [], range: .allTime, referenceDate: inWindow, focusCategory: .priest)
        let statsOutWindow = PrayerStats(sessions: [], range: .allTime, referenceDate: outWindow, focusCategory: .priest)

        #expect(statsInWindow.shouldShowYearSummary == true)
        #expect(statsOutWindow.shouldShowYearSummary == false)
    }

    private func makeSession(
        endedAt: Date,
        completed: Bool,
        prayerNames: [String] = ["A"],
        completedSubprayerCount: Int = 1,
        category: PrayerTargetCategory = .priest,
        duration: TimeInterval = 600,
        targetId: UUID = UUID()
    ) -> PrayerSession {
        PrayerSession(
            id: UUID(),
            targetId: targetId,
            targetName: "Target",
            targetCategory: category,
            prayerIds: prayerNames.map { _ in UUID() },
            prayerNames: prayerNames,
            startedAt: endedAt.addingTimeInterval(-duration),
            endedAt: endedAt,
            duration: duration,
            totalSubprayerCount: prayerNames.count,
            completedSubprayerCount: completedSubprayerCount,
            completed: completed,
            completion: completed ? .finished : .abandoned
        )
    }
}

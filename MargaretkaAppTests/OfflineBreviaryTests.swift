import Foundation
import Testing
@testable import MargaretkaApp

@MainActor
struct OfflineBreviaryTests {
    private let calendar = Calendar.brewiarzWarsaw

    @Test func civilDateUsesWarsawCalendar() throws {
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 12)))
        #expect(BreviaryCivilDate(date: date).id == "2026-07-20")
    }

    @Test func officeExpiresAtStartOfThirdDayAfterItsDate() throws {
        let referenceDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 12)))

        #expect(OfflineBreviaryStore.isExpired(.init(year: 2026, month: 7, day: 17), referenceDate: referenceDate))
        #expect(!OfflineBreviaryStore.isExpired(.init(year: 2026, month: 7, day: 18), referenceDate: referenceDate))
        #expect(!OfflineBreviaryStore.isExpired(.init(year: 2026, month: 7, day: 20), referenceDate: referenceDate))
        #expect(!OfflineBreviaryStore.isExpired(.init(year: 2026, month: 8, day: 1), referenceDate: referenceDate))
    }

    @Test func cleanupRetainsFutureAndTwoPreviousDays() throws {
        let referenceDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 12)))
        let importID = UUID()
        let days = [17, 18, 19, 20, 21].map { day in
            OfflineBreviaryDay(
                date: .init(year: 2026, month: 7, day: day),
                variantIdentifier: "p",
                variantName: "Dzień powszedni",
                offices: [],
                sourceImportID: importID,
                sourceIdentifier: "fixture",
                sourceTitle: "Fixture"
            )
        }

        let retained = OfflineBreviaryStore.removingExpired(from: days, referenceDate: referenceDate)

        #expect(retained.map(\.date.day) == [18, 19, 20, 21])
    }
}

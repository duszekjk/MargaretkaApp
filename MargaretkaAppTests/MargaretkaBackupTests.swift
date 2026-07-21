import Foundation
import Testing
@testable import MargaretkaApp

struct MargaretkaBackupTests {
    @Test func schemaOneArchiveWithoutPurposeOrPreferencesStillDecodes() throws {
        let original = emptyArchive(
            schemaVersion: 1,
            purpose: .dataTransfer,
            preferences: MargaretkaBackupPreferences(
                prayerSwipeMode: PrayerSwipeMode.both.rawValue,
                prayerCompactView: true,
                preferredBreviaryVariant: "p"
            )
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let encoded = try encoder.encode(original)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "purpose")
        object.removeValue(forKey: "preferences")
        let schemaOneData = try JSONSerialization.data(withJSONObject: object)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(MargaretkaBackup.self, from: schemaOneData)

        #expect(decoded.schemaVersion == 1)
        #expect(decoded.purpose == nil)
        #expect(decoded.preferences == nil)
        #expect(decoded.prayers.isEmpty)
        #expect(decoded.sessions.isEmpty)
    }

    @Test func fullBackupPreferencesRoundTripAndRestore() throws {
        let suiteName = "MargaretkaBackupTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let expected = MargaretkaBackupPreferences(
            prayerSwipeMode: PrayerSwipeMode.vertical.rawValue,
            prayerCompactView: false,
            preferredBreviaryVariant: "w2",
            preferredBreviaryVariantOrder: ["w2", "p", "w1"]
        )
        let archive = emptyArchive(
            schemaVersion: MargaretkaBackup.currentSchemaVersion,
            purpose: .fullBackup,
            preferences: expected
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(archive)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(MargaretkaBackup.self, from: data)

        #expect(decoded.purpose == .fullBackup)
        #expect(decoded.preferences == expected)
        decoded.preferences?.restore(to: defaults)
        #expect(MargaretkaBackupPreferences.capture(from: defaults) == expected)
    }

    @Test func selectiveTargetExportOmitsSessionsSettingsAndUnrelatedData() throws {
        let selectedPrayer = prayer(name: "Za Annę")
        let unrelatedPrayer = prayer(name: "Inna modlitwa")
        let selectedTarget = target(name: "Anna", prayerID: selectedPrayer.id)
        let unrelatedTarget = target(name: "Piotr", prayerID: unrelatedPrayer.id)
        let session = PrayerSession(
            id: UUID(),
            targetId: selectedTarget.id,
            targetName: selectedTarget.displayName,
            targetCategory: selectedTarget.category,
            prayerIds: [selectedPrayer.id],
            prayerNames: [selectedPrayer.name],
            startedAt: .now,
            endedAt: .now,
            duration: 60,
            totalSubprayerCount: 1,
            completedSubprayerCount: 1,
            completed: true,
            completion: .finished
        )

        let archive = MargaretkaBackupService.archive(
            prayers: [selectedPrayer, unrelatedPrayer],
            targets: [selectedTarget, unrelatedTarget],
            sessions: [session],
            offlineDays: [],
            purpose: .dataTransfer,
            selection: .target(selectedTarget.id)
        )

        #expect(archive.prayers.map(\.id) == [selectedPrayer.id])
        #expect(archive.targets.map(\.id) == [selectedTarget.id])
        #expect(archive.sessions.isEmpty)
        #expect(archive.preferences == nil)
        #expect(archive.offlineBreviaryDays.isEmpty)
    }

    @Test func selectiveBreviaryExportKeepsOnlyChosenOffice() throws {
        let jutrznia = Prayer(
            name: "Jutrznia",
            text: "Brewiarz",
            symbol: "sunrise",
            audioFilename: nil,
            audioSource: nil,
            timestampedLines: nil,
            content: .brewiarz(.jutrznia)
        )
        let day = OfflineBreviaryDay(
            date: .init(year: 2026, month: 8, day: 17),
            variantIdentifier: "p",
            variantName: "Tekst podstawowy",
            saintBiography: OfflineSaintBiography(title: "Święty", cards: []),
            offices: [
                OfflineBreviaryOffice(key: .jutrznia, cards: [], contentFingerprint: "j"),
                OfflineBreviaryOffice(key: .nieszpory, cards: [], contentFingerprint: "n")
            ],
            sourceImportID: UUID(),
            sourceIdentifier: "fixture.epub",
            sourceTitle: "fixture"
        )

        let archive = MargaretkaBackupService.archive(
            prayers: [jutrznia],
            targets: [],
            sessions: [],
            offlineDays: [day],
            purpose: .dataTransfer,
            selection: .breviaryOffice(.jutrznia)
        )

        #expect(archive.prayers.map(\.id) == [jutrznia.id])
        #expect(archive.offlineBreviaryDays.count == 1)
        #expect(archive.offlineBreviaryDays[0].offices.map(\.key) == [.jutrznia])
        #expect(archive.offlineBreviaryDays[0].saintBiography == nil)
        #expect(archive.sessions.isEmpty)
        #expect(archive.preferences == nil)
    }

    @Test func fullBackupIgnoresSelectionAndKeepsCompleteState() {
        let first = prayer(name: "Pierwsza")
        let second = prayer(name: "Druga")
        let selectedTarget = target(name: "Anna", prayerID: first.id)
        let session = PrayerSession(
            id: UUID(),
            targetId: selectedTarget.id,
            targetName: selectedTarget.displayName,
            targetCategory: selectedTarget.category,
            prayerIds: [first.id],
            prayerNames: [first.name],
            startedAt: .now,
            endedAt: .now,
            duration: 30,
            totalSubprayerCount: 1,
            completedSubprayerCount: 1,
            completed: true,
            completion: .finished
        )

        let archive = MargaretkaBackupService.archive(
            prayers: [first, second],
            targets: [selectedTarget],
            sessions: [session],
            offlineDays: [],
            purpose: .fullBackup,
            selection: .prayer(first.id)
        )

        #expect(archive.prayers.count == 2)
        #expect(archive.targets.count == 1)
        #expect(archive.sessions.map(\.id) == [session.id])
        #expect(archive.preferences != nil)
    }

    @Test func fullPhotoBytesRoundTripInsideArchive() throws {
        let expectedPhoto = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x01, 0x02, 0x03])
        let expectedBreviaryBackground = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x04, 0x05])
        let target = Priest(
            id: UUID(),
            firstName: "Anna",
            lastName: "Przykładowa",
            title: "",
            category: .person,
            photoData: expectedPhoto,
            photoScale: 1.35,
            photoOffsetX: 14,
            photoOffsetY: -9,
            assignedPrayerGroups: [],
            schedule: SchedulePlan(),
            lastModified: Date(timeIntervalSince1970: 1_700_000_000),
            notificationTitle: "Pomódl się za Annę",
            notificationMessage: "Czas na modlitwę"
        )
        var archive = emptyArchive(
            schemaVersion: MargaretkaBackup.currentSchemaVersion,
            purpose: .fullBackup,
            preferences: nil
        )
        archive.targets = [target]
        archive.assets = [
            MargaretkaBackupAsset(
                kind: .offlineBreviaryImage,
                filename: "jutrznia-background.png",
                data: expectedBreviaryBackground
            )
        ]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(archive)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(MargaretkaBackup.self, from: data)
        let restored = try #require(decoded.targets.first)

        #expect(restored.photoData == expectedPhoto)
        #expect(restored.photoScale == 1.35)
        #expect(restored.photoOffsetX == 14)
        #expect(restored.photoOffsetY == -9)
        #expect(decoded.assets.first?.data == expectedBreviaryBackground)
    }

    private func emptyArchive(
        schemaVersion: Int,
        purpose: MargaretkaArchivePurpose?,
        preferences: MargaretkaBackupPreferences?
    ) -> MargaretkaBackup {
        MargaretkaBackup(
            schemaVersion: schemaVersion,
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
            purpose: purpose,
            preferences: preferences,
            prayers: [],
            targets: [],
            sessions: [],
            offlineBreviaryDays: [],
            assets: []
        )
    }

    private func prayer(name: String) -> Prayer {
        Prayer(
            name: name,
            text: "Treść \(name)",
            symbol: "book",
            audioFilename: nil,
            audioSource: nil,
            timestampedLines: nil
        )
    }

    private func target(name: String, prayerID: UUID) -> Priest {
        Priest(
            id: UUID(),
            firstName: name,
            lastName: "",
            title: "",
            category: .person,
            assignedPrayerGroups: [AssignedPrayerGroup(prayerIds: [prayerID])],
            schedule: SchedulePlan(),
            lastModified: .now,
            notificationTitle: "Pomódl się za \(name)",
            notificationMessage: "Czas na modlitwę"
        )
    }
}

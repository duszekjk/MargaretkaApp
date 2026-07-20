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
            preferredBreviaryVariant: "w"
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
}

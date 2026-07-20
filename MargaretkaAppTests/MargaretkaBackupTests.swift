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

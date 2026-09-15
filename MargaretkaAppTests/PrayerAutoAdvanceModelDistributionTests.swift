import Foundation
import Testing
@testable import MargaretkaApp

struct PrayerAutoAdvanceModelDistributionTests {
    @Test func downloaderUsesDistinctLatestAndBestEndpoints() {
        let latest = PrayerAutoAdvanceCoreMLDownloader.manifestURL(for: .latest)
        let best = PrayerAutoAdvanceCoreMLDownloader.manifestURL(for: .best)

        #expect(latest.absoluteString.hasSuffix("/prayer-auto-advance/latest/"))
        #expect(best.absoluteString.hasSuffix("/prayer-auto-advance/best/"))
        #expect(latest != best)
    }

    @Test func legacyLocalMetadataWithoutServerTimestampStillDecodes() throws {
        let json = """
        {
          "baseModelVersion": 12,
          "featureSchemaVersion": 9,
          "createdAt": "2026-09-15T12:00:00Z",
          "lastUpdatedAt": "2026-09-15T12:00:00Z",
          "trainingSessions": 3,
          "trainedTransitions": 20
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let metadata = try decoder.decode(PrayerAutoAdvanceLocalMetadata.self, from: json)

        #expect(metadata.baseModelVersion == 12)
        #expect(metadata.featureSchemaVersion == 9)
        #expect(metadata.serverPublishedAt == nil)
    }

    @Test func manifestDecodesServerPublicationAndLoss() throws {
        let json = """
        {
          "modelVersion": 12,
          "featureSchemaVersion": 9,
          "modelURL": "https://heptadaisy.duszekjk.com/media/models/prayer-auto-advance/latest/model.aar",
          "sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
          "size": 123,
          "publishedAt": "2026-09-15T12:00:00Z",
          "trainingLoss": 0.125
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let manifest = try decoder.decode(PrayerAutoAdvanceManifest.self, from: json)

        #expect(manifest.modelVersion == 12)
        #expect(manifest.featureSchemaVersion == 9)
        #expect(manifest.trainingLoss == 0.125)
        #expect(manifest.publishedAt != nil)
    }
}

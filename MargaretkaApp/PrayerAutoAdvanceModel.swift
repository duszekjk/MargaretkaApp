import Foundation

struct PrayerAutoAdvanceLocalMetadata: Codable, Sendable {
    var baseModelVersion: Int
    var featureSchemaVersion: Int
    var createdAt: Date
    var lastUpdatedAt: Date
    var trainingSessions: Int
    var trainedTransitions: Int
}

struct PrayerAutoAdvanceManifest: Codable, Sendable {
    let modelVersion: Int
    let featureSchemaVersion: Int
    let modelURL: URL
    let sha256: String
    let publishedAt: Date?
}

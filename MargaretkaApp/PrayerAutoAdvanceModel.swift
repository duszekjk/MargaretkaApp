import Foundation

struct PrayerAutoAdvanceLocalMetadata: Codable, Sendable {
    var baseModelVersion: Int
    var featureSchemaVersion: Int
    var createdAt: Date
    var lastUpdatedAt: Date
    var trainingSessions: Int
    var trainedTransitions: Int
    var serverPublishedAt: Date?
    var serverSHA256: String?
}

struct PrayerAutoAdvanceManifest: Codable, Sendable {
    let modelVersion: Int
    let featureSchemaVersion: Int
    let modelURL: URL
    let sha256: String
    let size: Int?
    let publishedAt: Date?
    let trainingLoss: Double?
}

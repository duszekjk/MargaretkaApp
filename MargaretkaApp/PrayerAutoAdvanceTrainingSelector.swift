import Foundation

struct PrayerAutoAdvanceTrainingSnapshot: Sendable {
    let pageID: String
    let date: Date
    let features: [Float]
    let endingCoverage: Float
    let spokenRatio: Float
    let currentSimilarity: Float
    let nextSimilarity: Float
    let silenceDuration: TimeInterval
}

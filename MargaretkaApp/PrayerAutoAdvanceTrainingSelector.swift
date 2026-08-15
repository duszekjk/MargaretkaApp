import Foundation

struct PrayerAutoAdvanceTrainingSnapshot: Sendable {
    let pageID: String
    let date: Date
    let features: [Float]
    let longAudioFeatures: [Float]
}

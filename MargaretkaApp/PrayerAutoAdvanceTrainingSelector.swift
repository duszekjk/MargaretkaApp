import Foundation

struct PrayerAutoAdvanceTrainingSnapshot: Sendable {
    let pageID: String
    let date: Date
    let features: [Float]
    let longAudioFeatures: [Float]
}

/// Lightweight live-training marker. It intentionally contains no materialized
/// audio/text feature vectors. The expensive V11 feature extraction is deferred
/// until the manual swipe, after reservoir sampling and the T-0.4 s cutoff have
/// reduced the candidates to the small set that can actually enter the batch.
struct PrayerAutoAdvanceTrainingCandidate: Sendable {
    let pageID: String
    let date: Date
    let transcript: String
    let audioEndSampleIndex: Int
}

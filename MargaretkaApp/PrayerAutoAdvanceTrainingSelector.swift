import Foundation

struct PrayerAutoAdvanceTrainingSnapshot: Sendable {
    let pageID: String
    let date: Date
    let features: [Float]
    let longAudioFeatures: [Float]
}

/// Lightweight live-training marker. It intentionally contains no materialized
/// audio/text feature vectors. V12 stores only metadata plus the raw-page endpoint;
/// the page spectral representation is built once after the manual swipe.
struct PrayerAutoAdvanceTrainingCandidate: Sendable {
    let pageID: String
    let date: Date
    let transcript: String
    let lastSegmentEndTime: TimeInterval?
    let audioEndSampleIndex: Int
}

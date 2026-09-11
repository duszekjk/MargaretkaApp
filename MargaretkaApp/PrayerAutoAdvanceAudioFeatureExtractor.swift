import Foundation

struct PrayerAutoAdvanceAudioWindow: Sendable {
    let samples: [Float]
    let sampleRate: Double
}

enum PrayerAutoAdvanceAudioFeatureExtractor {
    static let duration: TimeInterval = 10.0
    static let temporalBins = 50
    static let frequencyBands = 48
    static let featureCount = temporalBins * frequencyBands
    static let analysisSampleRate = 16_000.0

    static func features(window: PrayerAutoAdvanceAudioWindow) -> [Float] {
        guard window.sampleRate == analysisSampleRate, !window.samples.isEmpty else {
            return Array(repeating: 0, count: featureCount)
        }
        let history = PrayerAutoAdvanceSpectralFrontEnd.analyze(samples: window.samples)
        return history.shortFeatures(endingAt: window.samples.count)
    }

    static func features(
        history: PrayerAutoAdvanceSpectralHistory,
        endingAt sampleIndex: Int
    ) -> [Float] {
        history.shortFeatures(endingAt: sampleIndex)
    }
}

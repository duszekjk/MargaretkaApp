import Foundation

enum PrayerAutoAdvanceLongAudioFeatureExtractor {
    static let duration: TimeInterval = 60.0
    static let temporalBins = 120
    static let frequencyBands = 32
    static let featureCount = temporalBins * frequencyBands
    static let analysisSampleRate = 16_000.0

    static func features(window: PrayerAutoAdvanceAudioWindow) -> [Float] {
        guard window.sampleRate == analysisSampleRate, !window.samples.isEmpty else {
            return Array(repeating: 0, count: featureCount)
        }
        let history = PrayerAutoAdvanceSpectralFrontEnd.analyze(samples: window.samples)
        return history.longFeatures(endingAt: window.samples.count)
    }

    static func features(
        history: PrayerAutoAdvanceSpectralHistory,
        endingAt sampleIndex: Int
    ) -> [Float] {
        history.longFeatures(endingAt: sampleIndex)
    }
}

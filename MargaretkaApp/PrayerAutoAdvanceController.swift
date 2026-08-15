import Foundation
import NaturalLanguage

struct PrayerAutoAdvanceContext: Equatable, Sendable {
    let pageID: String
    let currentText: String
    let previousText: String?
    let nextText: String?
    let language: PrayerLanguage
}

enum PrayerAutoAdvanceFeatureExtractor {
    static let progressFeatureCount = 3
    static let textEmbeddingSize = 512
    static let spokenWindowWordCount = 80
    static let audioFeatureCount = PrayerAutoAdvanceAudioFeatureExtractor.featureCount
    static let featureCount = progressFeatureCount + textEmbeddingSize + textEmbeddingSize + audioFeatureCount

    static func features(
        transcript: String,
        context: PrayerAutoAdvanceContext,
        elapsed: TimeInterval,
        audioFeatures: [Float]
    ) -> [Float] {
        let spokenTokens = tokens(transcript)
        let pageTokens = tokens(context.currentText)
        let elapsedNormalized = Float(min(max(elapsed / 120.0, 0), 1))
        let spokenWordCountNormalized = Float(min(Double(spokenTokens.count) / 120.0, 1))
        let pageWordCountNormalized = Float(min(Double(pageTokens.count) / 300.0, 1))

        let progress: [Float] = [
            elapsedNormalized,
            spokenWordCountNormalized,
            pageWordCountNormalized,
        ]

        // Keep both texts independent. The model receives a representation of
        // what Speech recognized and a separate representation of everything
        // displayed on the current page. We deliberately do not pre-compute
        // similarity, suffix coverage, edit distance, or other alignment scores.
        let spokenText = spokenTokens.suffix(spokenWindowWordCount).joined(separator: " ")
        let spokenEmbedding = textEmbedding(spokenText)
        let pageEmbedding = textEmbedding(context.currentText)

        let audio: [Float]
        if audioFeatures.count == audioFeatureCount {
            audio = audioFeatures
        } else {
            audio = Array(repeating: 0, count: audioFeatureCount)
        }

        return progress + spokenEmbedding + pageEmbedding + audio
    }

    static func textEmbedding(_ text: String) -> [Float] {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty,
              let embedding = NLEmbedding.sentenceEmbedding(for: .english),
              let vector = embedding.vector(for: input),
              !vector.isEmpty else {
            return Array(repeating: 0, count: textEmbeddingSize)
        }

        var result = Array(repeating: Float(0), count: textEmbeddingSize)
        let count = min(vector.count, textEmbeddingSize)
        var normSquared = 0.0
        for index in 0..<count {
            normSquared += vector[index] * vector[index]
        }
        let norm = sqrt(normSquared)
        guard norm > 1e-12 else { return result }
        for index in 0..<count {
            result[index] = Float(vector[index] / norm)
        }
        return result
    }

    private static func tokens(_ text: String) -> [String] {
        text
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
    }
}

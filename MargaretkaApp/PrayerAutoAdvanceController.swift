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
    static func features(
        transcript: String,
        context: PrayerAutoAdvanceContext,
        elapsed: TimeInterval,
        silence: TimeInterval,
        energy: Float
    ) -> [Float] {
        let currentSemantic = semanticSimilarity(transcript, context.currentText, language: context.language)
        let nextSemantic = context.nextText.map { semanticSimilarity(transcript, $0, language: context.language) } ?? 0
        let currentLexical = lexicalSimilarity(transcript, context.currentText)
        let nextLexical = context.nextText.map { lexicalSimilarity(transcript, $0) } ?? 0
        let ending = endingCoverage(transcript: transcript, expected: context.currentText)
        let elapsedNormalized = Float(min(max(elapsed / 120.0, 0), 1))
        let silenceNormalized = Float(min(max(silence / 4.0, 0), 1))
        let energyNormalized = min(max(energy * 10, 0), 1)
        let expectedWordCount = max(tokens(context.currentText).count, 1)
        let spokenRatio = Float(min(Double(tokens(transcript).count) / Double(expectedWordCount), 1))
        let semanticMargin = min(max((currentSemantic - nextSemantic + 1) / 2, 0), 1)

        return [
            currentSemantic,
            nextSemantic,
            currentLexical,
            nextLexical,
            ending,
            elapsedNormalized,
            silenceNormalized,
            energyNormalized,
            spokenRatio,
            semanticMargin,
        ]
    }

    private static func semanticSimilarity(_ lhs: String, _ rhs: String, language: PrayerLanguage) -> Float {
        guard let nlLanguage = language.nlLanguage,
              let embedding = NLEmbedding.sentenceEmbedding(for: nlLanguage),
              let left = embedding.vector(for: normalized(lhs)),
              let right = embedding.vector(for: normalized(rhs)),
              left.count == right.count,
              !left.isEmpty else {
            return lexicalSimilarity(lhs, rhs)
        }
        var dot = 0.0
        var leftNorm = 0.0
        var rightNorm = 0.0
        for index in left.indices {
            dot += left[index] * right[index]
            leftNorm += left[index] * left[index]
            rightNorm += right[index] * right[index]
        }
        guard leftNorm > 0, rightNorm > 0 else { return 0 }
        let cosine = dot / (sqrt(leftNorm) * sqrt(rightNorm))
        return Float(min(max((cosine + 1) / 2, 0), 1))
    }

    private static func lexicalSimilarity(_ lhs: String, _ rhs: String) -> Float {
        let left = Set(tokens(lhs))
        let right = Set(tokens(rhs))
        guard !left.isEmpty, !right.isEmpty else { return 0 }
        return Float(left.intersection(right).count) / Float(max(left.union(right).count, 1))
    }

    private static func endingCoverage(transcript: String, expected: String) -> Float {
        let spoken = tokens(transcript)
        let target = tokens(expected)
        guard !spoken.isEmpty, !target.isEmpty else { return 0 }
        let maximum = Swift.min(20, Swift.min(spoken.count, target.count))
        var matched = 0
        for length in stride(from: maximum, through: 1, by: -1) {
            if Array(spoken.suffix(length)) == Array(target.suffix(length)) {
                matched = length
                break
            }
        }
        return Float(matched) / Float(maximum)
    }

    private static func tokens(_ text: String) -> [String] {
        normalized(text)
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
    }

    private static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "pl_PL"))
            .lowercased()
    }
}

private extension PrayerLanguage {
    var nlLanguage: NLLanguage? {
        switch self {
        case .polish: .polish
        case .english: .english
        case .latin: nil
        }
    }
}

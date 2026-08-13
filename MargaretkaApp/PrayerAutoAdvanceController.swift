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
        // Apple's sentence embeddings are not available for Polish on the tested
        // devices/SDK. Calling the unsupported locale emits a system warning for
        // every snapshot, so use the deterministic lexical fallback directly.
        guard language == .english,
              let embedding = NLEmbedding.sentenceEmbedding(for: .english),
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

        // ASR often drops or substitutes one of the final words. Compare the
        // recent transcript against the expected ending with an ordered LCS
        // instead of requiring an exact suffix match.
        let targetTail = Array(target.suffix(min(12, target.count)))
        let spokenTail = Array(spoken.suffix(min(24, spoken.count)))
        let matched = longestCommonSubsequenceLength(spokenTail, targetTail)
        return Float(matched) / Float(max(targetTail.count, 1))
    }

    private static func longestCommonSubsequenceLength(_ lhs: [String], _ rhs: [String]) -> Int {
        guard !lhs.isEmpty, !rhs.isEmpty else { return 0 }
        var previous = Array(repeating: 0, count: rhs.count + 1)
        for left in lhs {
            var current = Array(repeating: 0, count: rhs.count + 1)
            for index in rhs.indices {
                if left == rhs[index] {
                    current[index + 1] = previous[index] + 1
                } else {
                    current[index + 1] = max(current[index], previous[index + 1])
                }
            }
            previous = current
        }
        return previous[rhs.count]
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

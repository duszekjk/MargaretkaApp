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

struct PrayerAutoAdvanceTrainingSelection: Sendable {
    let samples: [(features: [Float], label: Int64)]
    let estimatedIdealAdvanceTime: Date
    let manualDelay: TimeInterval
    let treatedAsDelayedOutlier: Bool
}

enum PrayerAutoAdvanceTrainingExampleSelector {
    /// Manual navigation is a noisy observation of the desired switch time.
    /// We estimate the switch point from sustained completion evidence and use
    /// the manual gesture mainly as confirmation that a transition was intended.
    static func select(
        snapshots: [PrayerAutoAdvanceTrainingSnapshot],
        manualAdvanceAt: Date = Date()
    ) -> PrayerAutoAdvanceTrainingSelection? {
        let ordered = snapshots.sorted { $0.date < $1.date }
        guard ordered.count >= 4 else { return nil }

        let readiness = ordered.map(readinessScore)
        guard let idealIndex = sustainedReadyIndex(scores: readiness) else {
            // A very late gesture without a strong earlier completion signal is
            // ambiguous. Dropping it is safer than teaching a wrong timestamp.
            return nil
        }

        let ideal = ordered[idealIndex]
        let delay = manualAdvanceAt.timeIntervalSince(ideal.date)
        guard delay >= -1.0 else { return nil }

        let delayedOutlier = delay > 4.0
        if delayedOutlier {
            // Accept a forgotten/late swipe only when completion evidence was
            // particularly strong before the manual gesture.
            guard readiness[idealIndex] >= 0.86,
                  sustainedReadyCount(from: idealIndex, scores: readiness) >= 3 else {
                return nil
            }
        }

        var samples: [(features: [Float], label: Int64)] = []

        // Positives are anchored to the estimated ideal moment, with about one
        // second of human-reaction tolerance. This makes +0.5 s essentially
        // equivalent and +1 s only mildly worse through lower sample density.
        let positiveWindows: [ClosedRange<TimeInterval>] = [
            -0.55 ... 0.55,
            0.55 ... 1.10,
        ]
        for window in positiveWindows {
            if let snapshot = nearestSnapshot(
                to: ideal.date.addingTimeInterval(window.lowerBound == -0.55 ? 0 : 0.8),
                within: window,
                relativeTo: ideal.date,
                snapshots: ordered
            ) {
                samples.append((snapshot.features, 1))
            }
        }
        if samples.isEmpty {
            samples.append((ideal.features, 1))
        }

        // Negatives stay comfortably before the estimated completion point.
        // The ambiguous band immediately before/after completion is skipped.
        for offset in [-8.0, -4.0, -2.0] {
            if let snapshot = nearestSnapshot(
                to: ideal.date.addingTimeInterval(offset),
                maxDistance: 1.2,
                snapshots: ordered
            ), snapshot.date < ideal.date.addingTimeInterval(-1.25) {
                samples.append((snapshot.features, 0))
            }
        }

        guard samples.contains(where: { $0.label == 1 }),
              samples.contains(where: { $0.label == 0 }) else {
            return nil
        }

        return PrayerAutoAdvanceTrainingSelection(
            samples: deduplicated(samples),
            estimatedIdealAdvanceTime: ideal.date,
            manualDelay: delay,
            treatedAsDelayedOutlier: delayedOutlier
        )
    }

    private static func readinessScore(_ snapshot: PrayerAutoAdvanceTrainingSnapshot) -> Float {
        let nextLead = max(snapshot.nextSimilarity - snapshot.currentSimilarity, 0)
        let silence = Float(min(max(snapshot.silenceDuration / 2.0, 0), 1))
        return min(max(
            snapshot.endingCoverage * 0.42
                + snapshot.spokenRatio * 0.28
                + snapshot.currentSimilarity * 0.18
                + min(nextLead * 1.5, 1) * 0.07
                + silence * 0.05,
            0
        ), 1)
    }

    private static func sustainedReadyIndex(scores: [Float]) -> Int? {
        guard scores.count >= 2 else { return nil }
        for index in 0..<(scores.count - 1) {
            if scores[index] >= 0.72, scores[index + 1] >= 0.72 {
                return index
            }
        }
        return nil
    }

    private static func sustainedReadyCount(from index: Int, scores: [Float]) -> Int {
        guard scores.indices.contains(index) else { return 0 }
        var count = 0
        for score in scores[index...] {
            guard score >= 0.72 else { break }
            count += 1
        }
        return count
    }

    private static func nearestSnapshot(
        to target: Date,
        maxDistance: TimeInterval,
        snapshots: [PrayerAutoAdvanceTrainingSnapshot]
    ) -> PrayerAutoAdvanceTrainingSnapshot? {
        snapshots
            .map { ($0, abs($0.date.timeIntervalSince(target))) }
            .filter { $0.1 <= maxDistance }
            .min { $0.1 < $1.1 }?
            .0
    }

    private static func nearestSnapshot(
        to target: Date,
        within window: ClosedRange<TimeInterval>,
        relativeTo ideal: Date,
        snapshots: [PrayerAutoAdvanceTrainingSnapshot]
    ) -> PrayerAutoAdvanceTrainingSnapshot? {
        snapshots
            .filter { window.contains($0.date.timeIntervalSince(ideal)) }
            .map { ($0, abs($0.date.timeIntervalSince(target))) }
            .min { $0.1 < $1.1 }?
            .0
    }

    private static func deduplicated(
        _ samples: [(features: [Float], label: Int64)]
    ) -> [(features: [Float], label: Int64)] {
        var seen = Set<String>()
        return samples.filter { sample in
            let key = "\(sample.label):" + sample.features.map { String(format: "%.4f", $0) }.joined(separator: ",")
            return seen.insert(key).inserted
        }
    }
}

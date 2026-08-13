import Foundation

struct PrayerAutoAdvanceTimingHistory: Codable, Sendable {
    static let minimumCountForOutliers = 20
    private(set) var values: [TimeInterval] = []

    var canDetectOutliers: Bool { values.count >= Self.minimumCountForOutliers }

    var typicalDelay: TimeInterval? {
        guard canDetectOutliers else { return nil }
        return median(values.sorted())
    }

    mutating func append(_ value: TimeInterval) {
        guard value.isFinite else { return }
        values.append(value)
        if values.count > 200 { values.removeFirst(values.count - 200) }
    }

    func isOutlier(_ value: TimeInterval) -> Bool {
        guard canDetectOutliers else { return false }
        let sorted = values.sorted()
        let center = median(sorted)
        let deviations = sorted.map { abs($0 - center) }.sorted()
        let mad = median(deviations)
        guard mad > 0.05 else { return false }
        return 0.6745 * abs(value - center) / mad > 3.5
    }

    private func median(_ sorted: [TimeInterval]) -> TimeInterval {
        let i = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[i - 1] + sorted[i]) / 2
        }
        return sorted[i]
    }
}

struct PrayerAutoAdvanceLabeledBatch: Sendable {
    let samples: [(features: [Float], label: Int64)]
    let observedDelay: TimeInterval?
}

enum PrayerAutoAdvanceTrainingPolicy {
    static func makeBatch(
        snapshots: [PrayerAutoAdvanceTrainingSnapshot],
        manualAdvanceAt: Date,
        history: PrayerAutoAdvanceTimingHistory
    ) -> PrayerAutoAdvanceLabeledBatch? {
        let ordered = snapshots.sorted { $0.date < $1.date }
        guard ordered.count >= 4 else { return nil }

        let completion = reliableCompletionIndex(in: ordered).map { ordered[$0] }
        let observedDelay = completion.map { manualAdvanceAt.timeIntervalSince($0.date) }

        // During calibration the manual gesture itself is the noisy training
        // anchor. If completion timing cannot be measured reliably, train the
        // classifier but do not invent a delay or add anything to timing history.
        // Once the personal timing baseline is mature, we require a measured
        // delay so that strong outliers can be rejected before training.
        let anchor: Date
        if let typicalDelay = history.typicalDelay {
            guard let observedDelay,
                  !history.isOutlier(observedDelay) else { return nil }
            anchor = manualAdvanceAt.addingTimeInterval(-typicalDelay)
        } else {
            anchor = manualAdvanceAt
        }

        var result: [(features: [Float], label: Int64)] = []

        // Approximate the asymmetric timing cost with sample multiplicity:
        // <= 0.5 s is effectively equivalent, around 1 s remains useful but
        // receives less weight, and farther samples are not positive examples.
        let positiveCandidates = ordered
            .map { ($0, abs($0.date.timeIntervalSince(anchor))) }
            .filter { $0.1 <= 1.6 }
            .sorted { $0.1 < $1.1 }
            .prefix(2)

        for (snapshot, distance) in positiveCandidates {
            let copies: Int
            if distance <= 0.55 {
                copies = 3
            } else if distance <= 1.10 {
                copies = 2
            } else {
                copies = 1
            }
            for _ in 0..<copies {
                result.append((snapshot.features, 1))
            }
        }

        // Leave an ambiguous band around the anchor. Negatives are sampled far
        // enough before it that a normal human reaction delay cannot relabel them.
        for offset in [-8.0, -4.0, -2.0] {
            if let negative = nearest(
                to: anchor.addingTimeInterval(offset),
                maxDistance: 1.2,
                in: ordered
            ), negative.date < anchor.addingTimeInterval(-1.25) {
                result.append((negative.features, 0))
            }
        }

        guard result.contains(where: { $0.label == 1 }),
              result.contains(where: { $0.label == 0 }) else { return nil }

        return PrayerAutoAdvanceLabeledBatch(
            samples: result,
            observedDelay: observedDelay
        )
    }

    private static func reliableCompletionIndex(
        in snapshots: [PrayerAutoAdvanceTrainingSnapshot]
    ) -> Int? {
        let scores = snapshots.map(readinessScore)
        guard scores.count >= 2 else { return nil }
        for index in 0..<(scores.count - 1)
        where scores[index] >= 0.72 && scores[index + 1] >= 0.72 {
            return index
        }
        return nil
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

    private static func nearest(
        to date: Date,
        maxDistance: TimeInterval,
        in snapshots: [PrayerAutoAdvanceTrainingSnapshot]
    ) -> PrayerAutoAdvanceTrainingSnapshot? {
        snapshots
            .map { ($0, abs($0.date.timeIntervalSince(date))) }
            .filter { $0.1 <= maxDistance }
            .min { $0.1 < $1.1 }?
            .0
    }
}

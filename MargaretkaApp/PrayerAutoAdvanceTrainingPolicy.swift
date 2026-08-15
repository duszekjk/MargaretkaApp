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

struct PrayerAutoAdvanceLabeledSample: Sendable {
    let features: [Float]
    let longAudioFeatures: [Float]
    let label: Int64
}

struct PrayerAutoAdvanceLabeledBatch: Sendable {
    let samples: [PrayerAutoAdvanceLabeledSample]
    let observedDelay: TimeInterval?
}

enum PrayerAutoAdvanceTrainingPolicy {
    static func makeBatch(
        snapshots: [PrayerAutoAdvanceTrainingSnapshot],
        manualAdvanceAt: Date,
        history _: PrayerAutoAdvanceTimingHistory
    ) -> PrayerAutoAdvanceLabeledBatch? {
        let ordered = snapshots.sorted { $0.date < $1.date }
        guard ordered.count >= 4 else { return nil }

        // Schema v4 deliberately removes hand-authored text comparison from
        // completion detection. Until a model-derived completion signal is
        // mature enough to calibrate reaction delay, the manual swipe remains
        // the noisy supervision anchor and no timing value is invented.
        let anchor = manualAdvanceAt
        let observedDelay: TimeInterval? = nil

        var result: [PrayerAutoAdvanceLabeledSample] = []

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
                result.append(
                    PrayerAutoAdvanceLabeledSample(
                        features: snapshot.features,
                        longAudioFeatures: snapshot.longAudioFeatures,
                        label: 1
                    )
                )
            }
        }

        for offset in [-8.0, -4.0, -2.0] {
            if let negative = nearest(
                to: anchor.addingTimeInterval(offset),
                maxDistance: 1.2,
                in: ordered
            ), negative.date < anchor.addingTimeInterval(-1.25) {
                result.append(
                    PrayerAutoAdvanceLabeledSample(
                        features: negative.features,
                        longAudioFeatures: negative.longAudioFeatures,
                        label: 0
                    )
                )
            }
        }

        guard result.contains(where: { $0.label == 1 }),
              result.contains(where: { $0.label == 0 }) else { return nil }

        return PrayerAutoAdvanceLabeledBatch(
            samples: result,
            observedDelay: observedDelay
        )
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

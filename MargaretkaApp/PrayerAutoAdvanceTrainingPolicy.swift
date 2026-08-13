import Foundation

struct PrayerAutoAdvanceTimingHistory: Codable, Sendable {
    static let minimumCountForOutliers = 20
    private(set) var values: [TimeInterval] = []

    var canDetectOutliers: Bool { values.count >= Self.minimumCountForOutliers }

    mutating func append(_ value: TimeInterval) {
        guard value.isFinite else { return }
        values.append(value)
        if values.count > 200 { values.removeFirst(values.count - 200) }
    }

    func isOutlier(_ value: TimeInterval) -> Bool {
        guard canDetectOutliers else { return false }
        let sorted = values.sorted()
        let m = median(sorted)
        let deviations = sorted.map { abs($0 - m) }.sorted()
        let mad = median(deviations)
        guard mad > 0.05 else { return false }
        return 0.6745 * abs(value - m) / mad > 3.5
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
    let observedDelay: TimeInterval
}

enum PrayerAutoAdvanceTrainingPolicy {
    static func makeBatch(
        snapshots: [PrayerAutoAdvanceTrainingSnapshot],
        manualAdvanceAt: Date,
        history: PrayerAutoAdvanceTimingHistory
    ) -> PrayerAutoAdvanceLabeledBatch? {
        let ordered = snapshots.sorted { $0.date < $1.date }
        guard ordered.count >= 4 else { return nil }
        guard let idealIndex = idealIndex(in: ordered) else { return nil }

        let ideal = ordered[idealIndex]
        let delay = manualAdvanceAt.timeIntervalSince(ideal.date)
        if history.isOutlier(delay) { return nil }

        var result: [(features: [Float], label: Int64)] = [(ideal.features, 1)]

        if delay <= 1.5,
           let near = nearest(to: ideal.date.addingTimeInterval(0.8), maxDistance: 0.4, in: ordered) {
            result.append((near.features, 1))
        }

        for offset in [-8.0, -4.0, -2.0] {
            if let negative = nearest(to: ideal.date.addingTimeInterval(offset), maxDistance: 1.2, in: ordered),
               negative.date < ideal.date.addingTimeInterval(-1.25) {
                result.append((negative.features, 0))
            }
        }

        guard result.contains(where: { $0.label == 0 }) else { return nil }
        return PrayerAutoAdvanceLabeledBatch(samples: result, observedDelay: delay)
    }

    private static func idealIndex(in snapshots: [PrayerAutoAdvanceTrainingSnapshot]) -> Int? {
        let scores = snapshots.map(score)
        guard scores.count >= 2 else { return nil }
        for i in 0..<(scores.count - 1) where scores[i] >= 0.72 && scores[i + 1] >= 0.72 {
            return i
        }
        return nil
    }

    private static func score(_ s: PrayerAutoAdvanceTrainingSnapshot) -> Float {
        let nextLead = max(s.nextSimilarity - s.currentSimilarity, 0)
        let silence = Float(min(max(s.silenceDuration / 2.0, 0), 1))
        return min(max(
            s.endingCoverage * 0.42
            + s.spokenRatio * 0.28
            + s.currentSimilarity * 0.18
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

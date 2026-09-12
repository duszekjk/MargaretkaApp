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
    static let maximumSamplesPerClass = 12
    static let positiveWindow: TimeInterval = 0.2
    static let deadZone: TimeInterval = 0.2

    static func selectNegativeCandidates(
        _ candidates: [PrayerAutoAdvanceTrainingCandidate],
        swipeSampleIndex: Int,
        sampleRate: Double
    ) -> [PrayerAutoAdvanceTrainingCandidate] {
        let protectedSampleCount = Int(((positiveWindow + deadZone) * sampleRate).rounded())
        let negativeCutoffSampleIndex = max(0, swipeSampleIndex - protectedSampleCount)
        let eligible = candidates.filter {
            $0.audioEndSampleIndex <= negativeCutoffSampleIndex
        }
        guard !eligible.isEmpty else { return [] }
        return Array(eligible.shuffled().prefix(maximumSamplesPerClass))
    }

    static func makeBatchFromSelectedNegatives(
        _ negativeSnapshots: [PrayerAutoAdvanceTrainingSnapshot],
        positiveSnapshots: [PrayerAutoAdvanceTrainingSnapshot]
    ) -> PrayerAutoAdvanceLabeledBatch? {
        balancedBatch(negatives: negativeSnapshots, positives: positiveSnapshots)
    }

    static func makeBatch(
        snapshots: [PrayerAutoAdvanceTrainingSnapshot],
        positiveSnapshots: [PrayerAutoAdvanceTrainingSnapshot],
        manualAdvanceAt: Date,
        history _: PrayerAutoAdvanceTimingHistory
    ) -> PrayerAutoAdvanceLabeledBatch? {
        let negativeCutoff = manualAdvanceAt.addingTimeInterval(-(positiveWindow + deadZone))
        let negativeCandidates = snapshots.filter { $0.date <= negativeCutoff }

        return balancedBatch(negatives: negativeCandidates, positives: positiveSnapshots)
    }

    private static func balancedBatch(
        negatives negativeCandidates: [PrayerAutoAdvanceTrainingSnapshot],
        positives positiveSnapshots: [PrayerAutoAdvanceTrainingSnapshot]
    ) -> PrayerAutoAdvanceLabeledBatch? {
        guard !negativeCandidates.isEmpty, !positiveSnapshots.isEmpty else { return nil }

        let count = min(
            maximumSamplesPerClass,
            negativeCandidates.count,
            positiveSnapshots.count
        )
        guard count > 0 else { return nil }

        let negatives = Array(negativeCandidates.shuffled().prefix(count))
        let positives = evenlyDistributedSelection(from: positiveSnapshots, count: count)

        var result: [PrayerAutoAdvanceLabeledSample] = []
        result.reserveCapacity(count * 2)

        for snapshot in negatives {
            result.append(
                PrayerAutoAdvanceLabeledSample(
                    features: snapshot.features,
                    longAudioFeatures: snapshot.longAudioFeatures,
                    label: 0
                )
            )
        }

        for snapshot in positives {
            result.append(
                PrayerAutoAdvanceLabeledSample(
                    features: snapshot.features,
                    longAudioFeatures: snapshot.longAudioFeatures,
                    label: 1
                )
            )
        }

        return PrayerAutoAdvanceLabeledBatch(
            samples: result,
            observedDelay: nil
        )
    }

    static func positiveTargetDates(manualAdvanceAt: Date, count: Int = maximumSamplesPerClass) -> [Date] {
        guard count > 0 else { return [] }
        if count == 1 { return [manualAdvanceAt] }
        return (0..<count).map { index in
            let fraction = Double(index) / Double(count - 1)
            let offset = -positiveWindow + (2 * positiveWindow * fraction)
            return manualAdvanceAt.addingTimeInterval(offset)
        }
    }

    private static func evenlyDistributedSelection(
        from snapshots: [PrayerAutoAdvanceTrainingSnapshot],
        count: Int
    ) -> [PrayerAutoAdvanceTrainingSnapshot] {
        let ordered = snapshots.sorted { $0.date < $1.date }
        guard count < ordered.count else { return Array(ordered.prefix(count)) }
        guard count > 1 else { return [ordered[ordered.count / 2]] }

        return (0..<count).map { index in
            let fraction = Double(index) / Double(count - 1)
            let rawIndex = fraction * Double(ordered.count - 1)
            return ordered[Int(rawIndex.rounded())]
        }
    }
}

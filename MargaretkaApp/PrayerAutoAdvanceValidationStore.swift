import Foundation

struct PrayerAutoAdvanceValidationSample: Codable, Sendable {
    let features: [Float]
    let longAudioFeatures: [Float]
    let label: Int64
}

struct PrayerAutoAdvanceValidationRecord: Codable, Sendable, Identifiable {
    let id: UUID
    let pageID: String
    let createdAt: Date
    let samples: [PrayerAutoAdvanceValidationSample]
}

struct PrayerAutoAdvanceValidationMetrics: Sendable {
    let sampleCount: Int
    let positiveCount: Int
    let negativeCount: Int
    let positiveAverage: Double?
    let negativeAverage: Double?
    let margin: Double?
    let loss: Double?
}

struct PrayerAutoAdvanceValidationStore: Codable, Sendable {
    static let selectionInterval = 10
    static let maximumRecordsPerPrayer = 5

    var qualifyingEventCount = 0
    var records: [PrayerAutoAdvanceValidationRecord] = []

    var sampleCount: Int {
        records.reduce(0) { $0 + $1.samples.count }
    }

    func recordCount(for pageID: String) -> Int {
        records.filter { $0.pageID == pageID }.count
    }

    mutating func shouldHoldOut(pageID: String) -> Bool {
        qualifyingEventCount += 1
        guard qualifyingEventCount.isMultiple(of: Self.selectionInterval) else { return false }
        return recordCount(for: pageID) < Self.maximumRecordsPerPrayer
    }

    mutating func append(pageID: String, batch: PrayerAutoAdvanceLabeledBatch, at date: Date) {
        guard recordCount(for: pageID) < Self.maximumRecordsPerPrayer else { return }
        records.append(
            PrayerAutoAdvanceValidationRecord(
                id: UUID(),
                pageID: pageID,
                createdAt: date,
                samples: batch.samples.map {
                    PrayerAutoAdvanceValidationSample(
                        features: $0.features,
                        longAudioFeatures: $0.longAudioFeatures,
                        label: $0.label
                    )
                }
            )
        )
    }

    mutating func removeAll() {
        qualifyingEventCount = 0
        records.removeAll()
    }

    func metrics(using model: PrayerAutoAdvanceCoreMLModel) -> PrayerAutoAdvanceValidationMetrics {
        var positive: [Double] = []
        var negative: [Double] = []
        var losses: [Double] = []
        var evaluated = 0

        for record in records {
            for sample in record.samples {
                guard let prediction = try? model.prediction(
                    for: sample.features,
                    longAudioFeatures: sample.longAudioFeatures
                ) else { continue }
                evaluated += 1
                let p = min(max(Double(prediction), 1e-6), 1 - 1e-6)
                if sample.label == 1 {
                    positive.append(p)
                    losses.append(-log(p))
                } else {
                    negative.append(p)
                    losses.append(-log(1 - p))
                }
            }
        }

        let positiveAverage = average(positive)
        let negativeAverage = average(negative)
        let margin: Double?
        if let positiveAverage, let negativeAverage {
            margin = positiveAverage - negativeAverage
        } else {
            margin = nil
        }

        return PrayerAutoAdvanceValidationMetrics(
            sampleCount: evaluated,
            positiveCount: positive.count,
            negativeCount: negative.count,
            positiveAverage: positiveAverage,
            negativeAverage: negativeAverage,
            margin: margin,
            loss: average(losses)
        )
    }

    func margin(using model: PrayerAutoAdvanceCoreMLModel) -> Double? {
        metrics(using: model).margin
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}

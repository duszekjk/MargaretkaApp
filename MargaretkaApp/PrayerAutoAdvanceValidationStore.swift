import Foundation

struct PrayerAutoAdvanceValidationSample: Codable, Sendable {
    let features: [Float]
    let longAudioFeatures: [Float]
    let label: Int64
    let relativeTimeToAdvance: TimeInterval?
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
                        label: $0.label,
                        relativeTimeToAdvance: $0.relativeTimeToAdvance
                    )
                }
            )
        )
    }

    mutating func removeAll() {
        qualifyingEventCount = 0
        records.removeAll()
    }
}

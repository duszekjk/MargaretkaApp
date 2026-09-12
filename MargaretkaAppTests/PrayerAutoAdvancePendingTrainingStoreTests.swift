import Foundation
import Testing
@testable import MargaretkaApp

struct PrayerAutoAdvancePendingTrainingStoreTests {
    @Test func pagesPersistAcrossIndependentStoreReads() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        try PrayerAutoAdvancePendingTrainingStore.append(
            pageID: "page-1",
            batch: batch(marker: 1),
            createdAt: Date(timeIntervalSince1970: 1),
            to: directory
        )
        try PrayerAutoAdvancePendingTrainingStore.append(
            pageID: "page-2",
            batch: batch(marker: 2),
            createdAt: Date(timeIntervalSince1970: 2),
            to: directory
        )

        #expect(PrayerAutoAdvancePendingTrainingStore.pageCount(in: directory) == 2)
        let snapshot = try PrayerAutoAdvancePendingTrainingStore.loadSnapshot(from: directory)
        #expect(snapshot.pages.map(\.pageID) == ["page-1", "page-2"])
        #expect(snapshot.samples.map { $0.features[0] } == [1, 2])
    }

    @Test func successfulSnapshotRemovalDoesNotDeleteNewerPages() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        try PrayerAutoAdvancePendingTrainingStore.append(
            pageID: "consumed",
            batch: batch(marker: 1),
            createdAt: Date(timeIntervalSince1970: 1),
            to: directory
        )
        let consumed = try PrayerAutoAdvancePendingTrainingStore.loadSnapshot(from: directory)

        try PrayerAutoAdvancePendingTrainingStore.append(
            pageID: "newer",
            batch: batch(marker: 2),
            createdAt: Date(timeIntervalSince1970: 2),
            to: directory
        )
        try PrayerAutoAdvancePendingTrainingStore.remove(
            pageIDs: consumed.pageIDs,
            from: directory
        )

        let remaining = try PrayerAutoAdvancePendingTrainingStore.loadSnapshot(from: directory)
        #expect(remaining.pages.map(\.pageID) == ["newer"])
    }

    @Test func temporaryGroupedTrainingThresholdIsTwentyPages() {
        #expect(PrayerAutoAdvancePendingTrainingStore.minimumPageCountForUpdate == 20)
    }

    private func batch(marker: Float) -> PrayerAutoAdvanceLabeledBatch {
        var features = Array(repeating: Float.zero, count: PrayerAutoAdvanceCoreMLModel.inputSize)
        features[0] = marker
        return PrayerAutoAdvanceLabeledBatch(
            samples: [
                PrayerAutoAdvanceLabeledSample(
                    features: features,
                    longAudioFeatures: Array(
                        repeating: 0,
                        count: PrayerAutoAdvanceCoreMLModel.longAudioInputSize
                    ),
                    label: marker == 2 ? 1 : 0
                ),
            ],
            observedDelay: nil
        )
    }
}

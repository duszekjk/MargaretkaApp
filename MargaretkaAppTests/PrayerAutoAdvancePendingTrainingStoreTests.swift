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

    @Test func replayPoolCanBeReplacedWithoutTouchingFreshStore() throws {
        let freshDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let replayDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: freshDirectory)
            try? FileManager.default.removeItem(at: replayDirectory)
        }

        try PrayerAutoAdvancePendingTrainingStore.append(
            pageID: "fresh",
            batch: batch(marker: 1),
            createdAt: Date(timeIntervalSince1970: 1),
            to: freshDirectory
        )
        let fresh = try PrayerAutoAdvancePendingTrainingStore.loadSnapshot(from: freshDirectory)
        try PrayerAutoAdvancePendingTrainingStore.replaceAll(
            with: fresh.pages,
            in: replayDirectory
        )

        #expect(PrayerAutoAdvancePendingTrainingStore.pageCount(in: freshDirectory) == 1)
        #expect(PrayerAutoAdvancePendingTrainingStore.pageCount(in: replayDirectory) == 1)
    }

    @Test func productionGroupedTrainingThresholdIsOneHundredPages() {
        #expect(PrayerAutoAdvancePendingTrainingStore.minimumPageCountForUpdate == 100)
        #expect(PrayerAutoAdvancePendingTrainingStore.maximumReplayPageCount == 50)
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

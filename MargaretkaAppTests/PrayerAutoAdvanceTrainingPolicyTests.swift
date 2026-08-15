import Foundation
import Testing
@testable import MargaretkaApp

struct PrayerAutoAdvanceTrainingPolicyTests {
    @Test func timingOutliersStayDisabledDuringCalibration() {
        var history = PrayerAutoAdvanceTimingHistory()
        for _ in 0..<(PrayerAutoAdvanceTimingHistory.minimumCountForOutliers - 1) {
            history.append(0.8)
        }

        #expect(!history.canDetectOutliers)
        #expect(!history.isOutlier(12.0))
    }

    @Test func matureTimingHistoryRejectsOnlyStrongDeviation() {
        var history = PrayerAutoAdvanceTimingHistory()
        let normal = [0.55, 0.65, 0.75, 0.85, 0.95]
        for index in 0..<PrayerAutoAdvanceTimingHistory.minimumCountForOutliers {
            history.append(normal[index % normal.count])
        }

        #expect(history.canDetectOutliers)
        #expect(!history.isOutlier(0.9))
        #expect(history.isOutlier(8.0))
    }

    @Test func calibrationKeepsManualGestureAsTrainingAnchor() throws {
        var history = PrayerAutoAdvanceTimingHistory()
        for _ in 0..<(PrayerAutoAdvanceTimingHistory.minimumCountForOutliers - 1) {
            history.append(0.8)
        }

        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshots = (0...10).map { index in
            snapshot(index: index, base: base)
        }
        let batch = try #require(
            PrayerAutoAdvanceTrainingPolicy.makeBatch(
                snapshots: snapshots,
                manualAdvanceAt: base.addingTimeInterval(10),
                history: history
            )
        )

        let delay = try #require(batch.observedDelay)
        #expect(delay >= 9)
        let positiveMarkers = batch.samples
            .filter { $0.label == 1 }
            .map { $0.features[0] }
        #expect(positiveMarkers.contains(10))
        #expect(!positiveMarkers.contains(0))
        #expect(batch.samples.allSatisfy { $0.longAudioFeatures.count == PrayerAutoAdvanceCoreMLModel.longAudioInputSize })
    }

    @Test func calibrationCanTrainWithoutReliableCompletionTiming() throws {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshots = (0...8).map { index in
            weakSnapshot(index: index, base: base)
        }

        let batch = try #require(
            PrayerAutoAdvanceTrainingPolicy.makeBatch(
                snapshots: snapshots,
                manualAdvanceAt: base.addingTimeInterval(8),
                history: PrayerAutoAdvanceTimingHistory()
            )
        )

        #expect(batch.observedDelay == nil)
        #expect(batch.samples.contains(where: { $0.label == 1 }))
        #expect(batch.samples.contains(where: { $0.label == 0 }))
    }

    @Test func matureBaselineDropsWholeStrongOutlierEvent() {
        var history = PrayerAutoAdvanceTimingHistory()
        let normal = [0.55, 0.65, 0.75, 0.85, 0.95]
        for index in 0..<PrayerAutoAdvanceTimingHistory.minimumCountForOutliers {
            history.append(normal[index % normal.count])
        }

        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshots = (0...10).map { index in
            snapshot(index: index, base: base)
        }

        let batch = PrayerAutoAdvanceTrainingPolicy.makeBatch(
            snapshots: snapshots,
            manualAdvanceAt: base.addingTimeInterval(10),
            history: history
        )
        #expect(batch == nil)
    }

    private func snapshot(index: Int, base: Date) -> PrayerAutoAdvanceTrainingSnapshot {
        var features = Array(repeating: Float.zero, count: PrayerAutoAdvanceCoreMLModel.inputSize)
        features[0] = Float(index)
        return PrayerAutoAdvanceTrainingSnapshot(
            pageID: "test",
            date: base.addingTimeInterval(TimeInterval(index)),
            features: features,
            longAudioFeatures: Array(repeating: 0, count: PrayerAutoAdvanceCoreMLModel.longAudioInputSize),
            endingCoverage: 1,
            spokenRatio: 1,
            currentSimilarity: 1,
            nextSimilarity: 0
        )
    }

    private func weakSnapshot(index: Int, base: Date) -> PrayerAutoAdvanceTrainingSnapshot {
        var features = Array(repeating: Float.zero, count: PrayerAutoAdvanceCoreMLModel.inputSize)
        features[0] = Float(index)
        return PrayerAutoAdvanceTrainingSnapshot(
            pageID: "test",
            date: base.addingTimeInterval(TimeInterval(index)),
            features: features,
            longAudioFeatures: Array(repeating: 0, count: PrayerAutoAdvanceCoreMLModel.longAudioInputSize),
            endingCoverage: 0,
            spokenRatio: 0.5,
            currentSimilarity: 0.4,
            nextSimilarity: 0.4
        )
    }
}

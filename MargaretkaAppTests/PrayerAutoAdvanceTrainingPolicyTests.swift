import Foundation
import Testing
@testable import MargaretkaApp

struct PrayerAutoAdvanceTrainingPolicyTests {
    @Test func negativeSelectionUsesPCMIndicesInsteadOfWallClockDates() {
        let deliberatelyWrongWallClock = Date(timeIntervalSince1970: 1_900_000_000)
        let candidates = [0, 8_000, 10_000].map { sampleIndex in
            PrayerAutoAdvanceTrainingCandidate(
                pageID: "test",
                date: deliberatelyWrongWallClock,
                transcript: "",
                lastSegmentEndTime: nil,
                audioEndSampleIndex: sampleIndex
            )
        }

        let selected = PrayerAutoAdvanceTrainingPolicy.selectNegativeCandidates(
            candidates,
            swipeSampleIndex: 16_000,
            sampleRate: 16_000
        )

        #expect(Set(selected.map(\.audioEndSampleIndex)) == Set([0, 8_000]))
    }

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

    @Test func veryShortPageStillBuildsOneToOneBatch() throws {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let swipe = base.addingTimeInterval(0.5)
        let negatives = [snapshot(at: 0.0, base: base), snapshot(at: 0.25, base: base)]
        let positives = positiveSnapshots(swipe: swipe)

        let batch = try #require(
            PrayerAutoAdvanceTrainingPolicy.makeBatch(
                snapshots: negatives,
                positiveSnapshots: positives,
                manualAdvanceAt: swipe,
                history: PrayerAutoAdvanceTimingHistory()
            )
        )

        #expect(batch.observedDelay == nil)
        #expect(batch.samples.filter { $0.label == 0 }.count == 1)
        #expect(batch.samples.filter { $0.label == 1 }.count == 1)
    }

    @Test func twoSecondPageBalancesAllAvailableNegatives() throws {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let swipe = base.addingTimeInterval(2.0)
        let snapshots = stride(from: 0.0, through: 1.75, by: 0.25).map { snapshot(at: $0, base: base) }

        let batch = try #require(
            PrayerAutoAdvanceTrainingPolicy.makeBatch(
                snapshots: snapshots,
                positiveSnapshots: positiveSnapshots(swipe: swipe),
                manualAdvanceAt: swipe,
                history: PrayerAutoAdvanceTimingHistory()
            )
        )

        let negatives = batch.samples.filter { $0.label == 0 }
        let positives = batch.samples.filter { $0.label == 1 }
        #expect(negatives.count == 7)
        #expect(positives.count == negatives.count)
    }

    @Test func longPageCapsBalancedBatchAtTwelvePerClass() throws {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let swipe = base.addingTimeInterval(60)
        let snapshots = stride(from: 0.0, through: 59.75, by: 0.25).map { snapshot(at: $0, base: base) }

        let batch = try #require(
            PrayerAutoAdvanceTrainingPolicy.makeBatch(
                snapshots: snapshots,
                positiveSnapshots: positiveSnapshots(swipe: swipe),
                manualAdvanceAt: swipe,
                history: PrayerAutoAdvanceTimingHistory()
            )
        )

        #expect(batch.samples.filter { $0.label == 0 }.count == 12)
        #expect(batch.samples.filter { $0.label == 1 }.count == 12)
        #expect(batch.samples.count == 24)
    }

    @Test func deadZoneExcludesLastTwoTenthsBeforePositiveWindow() throws {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let swipe = base.addingTimeInterval(1.0)
        let snapshots = [
            snapshot(at: 0.0, base: base),
            snapshot(at: 0.5, base: base),
            snapshot(at: 0.61, base: base),
            snapshot(at: 0.70, base: base),
            snapshot(at: 0.79, base: base),
        ]

        let batch = try #require(
            PrayerAutoAdvanceTrainingPolicy.makeBatch(
                snapshots: snapshots,
                positiveSnapshots: positiveSnapshots(swipe: swipe),
                manualAdvanceAt: swipe,
                history: PrayerAutoAdvanceTimingHistory()
            )
        )

        let negativeMarkers = batch.samples
            .filter { $0.label == 0 }
            .map { $0.features[0] }
        #expect(negativeMarkers.allSatisfy { $0 <= 0.6 })
    }

    @Test func positiveTargetsCoverPlusMinusTwoTenths() throws {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let dates = PrayerAutoAdvanceTrainingPolicy.positiveTargetDates(manualAdvanceAt: base)
        #expect(dates.count == 12)
        #expect(abs(try #require(dates.first).timeIntervalSince(base) + 0.2) < 0.000_001)
        #expect(abs(try #require(dates.last).timeIntervalSince(base) - 0.2) < 0.000_001)
    }

    private func positiveSnapshots(swipe: Date) -> [PrayerAutoAdvanceTrainingSnapshot] {
        PrayerAutoAdvanceTrainingPolicy.positiveTargetDates(manualAdvanceAt: swipe).map { date in
            let marker = Float(date.timeIntervalSince(swipe))
            return snapshot(date: date, marker: marker)
        }
    }

    private func snapshot(at seconds: Double, base: Date) -> PrayerAutoAdvanceTrainingSnapshot {
        snapshot(date: base.addingTimeInterval(seconds), marker: Float(seconds))
    }

    private func snapshot(date: Date, marker: Float) -> PrayerAutoAdvanceTrainingSnapshot {
        var features = Array(repeating: Float.zero, count: PrayerAutoAdvanceCoreMLModel.inputSize)
        features[0] = marker
        return PrayerAutoAdvanceTrainingSnapshot(
            pageID: "test",
            date: date,
            features: features,
            longAudioFeatures: Array(repeating: 0, count: PrayerAutoAdvanceCoreMLModel.longAudioInputSize)
        )
    }
}

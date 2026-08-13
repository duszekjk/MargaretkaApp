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
}

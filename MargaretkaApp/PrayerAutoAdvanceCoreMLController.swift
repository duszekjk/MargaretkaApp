import Foundation
internal import Combine

@MainActor
final class PrayerAutoAdvanceCoreMLController: ObservableObject {
    @Published private(set) var advanceRequestSerial = 0
    @Published private(set) var lastPrediction: Float = 0
    @Published private(set) var statusMessage: String?

    let state = PrayerAutoAdvanceCoreMLState.shared
#if os(iOS)
    let capture = PrayerAutoAdvanceCoreMLSpeechCapture()
#endif
    var context: PrayerAutoAdvanceContext?
    var contextStartedAt = Date()
    var snapshots: [PrayerAutoAdvanceTrainingSnapshot] = []
    var evaluationTask: Task<Void, Never>?
    var consecutiveAdvancePredictions = 0
    var cooldownUntil = Date.distantPast

    init() {
        PrayerAutoAdvanceCoreMLDiskState.load(state)
    }

    deinit {
        evaluationTask?.cancel()
    }

    var isFeatureEnabled: Bool {
        UserDefaults.standard.bool(forKey: PrayerAutoAdvancePreferences.trainingEnabledKey)
            || UserDefaults.standard.bool(forKey: PrayerAutoAdvancePreferences.automaticEnabledKey)
    }
}

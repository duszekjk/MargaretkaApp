import Foundation
internal import Combine

@MainActor
final class PrayerAutoAdvanceCoreMLRuntime: ObservableObject {
    @Published var advanceRequestSerial = 0
    @Published var lastPrediction: Float = 0
    @Published var statusMessage: String?

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

    func recordManualAdvance(at date: Date = Date()) {
        guard UserDefaults.standard.bool(forKey: PrayerAutoAdvancePreferences.trainingEnabledKey),
              let pageID = context?.pageID,
              state.model != nil,
              !state.isTraining else { return }

        let candidates = snapshots.filter { $0.pageID == pageID }
        guard let batch = PrayerAutoAdvanceTrainingPolicy.makeBatch(
            snapshots: candidates,
            manualAdvanceAt: date,
            history: state.timingHistory
        ) else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.state.train(batch)
            self.statusMessage = self.state.lastError
        }
    }
}

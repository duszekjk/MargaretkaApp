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
              let currentContext = context,
              state.model != nil,
              !state.isTraining else { return }

        let pageID = currentContext.pageID
        let startedAt = contextStartedAt
        var candidates = snapshots.filter { $0.pageID == pageID }

#if os(iOS)
        let finalTranscript = capture.transcript
        let finalEnergy = capture.energy
        let finalSilence = capture.silenceDuration
#else
        let finalTranscript = ""
        let finalEnergy: Float = 0
        let finalSilence: TimeInterval = 0
#endif

        state.lastTrainingEvent = "Analizowanie ręcznego przejścia…"

        Task { @MainActor [weak self] in
            guard let self else { return }

            if !finalTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let elapsed = date.timeIntervalSince(startedAt)
                let features = await Task.detached(priority: .utility) {
                    PrayerAutoAdvanceFeatureExtractor.features(
                        transcript: finalTranscript,
                        context: currentContext,
                        elapsed: elapsed,
                        silence: finalSilence,
                        energy: finalEnergy
                    )
                }.value

                if features.count == PrayerAutoAdvanceCoreMLModel.inputSize {
                    candidates.append(
                        PrayerAutoAdvanceTrainingSnapshot(
                            pageID: pageID,
                            date: date,
                            features: features,
                            endingCoverage: features[4],
                            spokenRatio: features[8],
                            currentSimilarity: features[0],
                            nextSimilarity: features[1],
                            silenceDuration: finalSilence
                        )
                    )
                }
            }

            guard candidates.count >= 4 else {
                self.state.lastTrainingEvent = "Pominięto: za mało próbek z tej strony (\(candidates.count)/4)."
                return
            }

            guard let batch = PrayerAutoAdvanceTrainingPolicy.makeBatch(
                snapshots: candidates,
                manualAdvanceAt: date,
                history: self.state.timingHistory
            ) else {
                self.state.lastTrainingEvent = "Pominięto: brak wystarczająco wiarygodnego sygnału zakończenia modlitwy albo zdarzenie zostało uznane za outlier."
                return
            }

            await self.state.train(batch)
            self.statusMessage = self.state.lastError
        }
    }
}

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
    var lastTrainingSnapshotAt = Date.distantPast

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
        let finalAudio = capture.audioWindow()
#else
        let finalTranscript = ""
        let finalAudio = PrayerAutoAdvanceAudioWindow(samples: [], sampleRate: 8_000)
#endif

        state.lastTrainingEvent = "Analizowanie ręcznego przejścia…"

        Task { @MainActor [weak self] in
            guard let self else { return }
            let diagnostics = PrayerAutoAdvanceTrainingDiagnostics.shared

            if !finalTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let elapsed = date.timeIntervalSince(startedAt)
                let extracted = await Task.detached(priority: .utility) {
                    let shortAudio = PrayerAutoAdvanceAudioFeatureExtractor.features(window: finalAudio)
                    let longAudio = PrayerAutoAdvanceLongAudioFeatureExtractor.features(window: finalAudio)
                    let features = PrayerAutoAdvanceFeatureExtractor.features(
                        transcript: finalTranscript,
                        context: currentContext,
                        elapsed: elapsed,
                        audioFeatures: shortAudio
                    )
                    return (features, longAudio)
                }.value
                let features = extracted.0
                let longAudioFeatures = extracted.1

                if features.count == PrayerAutoAdvanceCoreMLModel.inputSize,
                   longAudioFeatures.count == PrayerAutoAdvanceCoreMLModel.longAudioInputSize {
                    candidates.append(
                        PrayerAutoAdvanceTrainingSnapshot(
                            pageID: pageID,
                            date: date,
                            features: features,
                            longAudioFeatures: longAudioFeatures,
                            endingCoverage: features[4],
                            spokenRatio: features[6],
                            currentSimilarity: features[0],
                            nextSimilarity: features[1]
                        )
                    )
                }
            }

            guard candidates.count >= 4 else {
                diagnostics.skippedTrainingCount += 1
                diagnostics.pipelineState = "skipped"
                diagnostics.event("training skipped: samples \(candidates.count)/4")
                self.state.lastTrainingEvent = "Pominięto: za mało próbek z tej strony (\(candidates.count)/4)."
                return
            }

            guard let batch = PrayerAutoAdvanceTrainingPolicy.makeBatch(
                snapshots: candidates,
                manualAdvanceAt: date,
                history: self.state.timingHistory
            ) else {
                diagnostics.skippedTrainingCount += 1
                diagnostics.pipelineState = "skipped"
                diagnostics.event("training skipped: policy rejected event")
                self.state.lastTrainingEvent = "Pominięto: brak wystarczająco wiarygodnego sygnału zakończenia modlitwy albo zdarzenie zostało uznane za outlier."
                return
            }

            if self.state.validationStore.shouldHoldOut(pageID: pageID) {
                self.state.validationStore.append(pageID: pageID, batch: batch, at: date)
                do {
                    try PrayerAutoAdvanceCoreMLDiskState.save(self.state)
                    diagnostics.pipelineState = "validation"
                    diagnostics.event(
                        "validation holdout page=\(pageID) records=\(self.state.validationStore.records.count) samples=\(self.state.validationStore.sampleCount)"
                    )
                    self.state.lastTrainingEvent = "Próbka trafiła do lokalnego zbioru walidacyjnego; model nie został na niej wytrenowany."
                    self.statusMessage = nil
                } catch {
                    diagnostics.pipelineState = "error"
                    diagnostics.error("validation save: \(error.localizedDescription)")
                    self.state.lastError = error.localizedDescription
                    self.statusMessage = error.localizedDescription
                }
                return
            }

            await self.state.train(batch)
            self.statusMessage = self.state.lastError
        }
    }
}

import Foundation
internal import Combine

@MainActor
final class PrayerAutoAdvanceCoreMLRuntime: ObservableObject {
    @Published var advanceRequestSerial = 0
    var lastPrediction: Float = 0
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
    var lastTrainingCandidateAt = Date.distantPast
    var lastDiagnosticsPublishAt = Date.distantPast
    var lastInferenceAt = Date.distantPast
    var trainingCandidateSeenCount = 0

    // Keep a little more than the final 12 so the T-0.4 s cutoff can discard the
    // last candidate without usually shrinking a long-page batch at the 2 Hz
    // training-candidate cadence.
    static let trainingReservoirCapacity = 16
    static let trainingCandidateInterval: TimeInterval = 0.5
    static let trainingOnlyInferenceInterval: TimeInterval = 2.0
    static let activeTrainingInferenceInterval: TimeInterval = 5.0
    static let diagnosticsPublishInterval: TimeInterval = 2.0

    // PrayerAutoAdvanceCoreMLState.shared already restores local disk state once.
    // Reloading the model/validation JSON here duplicated expensive synchronous I/O
    // each time a runtime object was created.
    init() {}

    deinit {
        evaluationTask?.cancel()
    }

    var isTrainingEnabled: Bool {
        UserDefaults.standard.bool(forKey: PrayerAutoAdvancePreferences.trainingEnabledKey)
    }

    var isAutomaticEnabled: Bool {
        UserDefaults.standard.bool(forKey: PrayerAutoAdvancePreferences.automaticEnabledKey)
    }

    var isFeatureEnabled: Bool {
        isTrainingEnabled || isAutomaticEnabled
    }

    /// Called by the 4 Hz scheduler. Automatic inference may still run at 4 Hz,
    /// while training candidates are admitted at most at 2 Hz. Expensive feature
    /// extraction happens only when this returns a reservoir slot or inference is due.
    func evaluationPlan(at date: Date) -> PrayerAutoAdvanceEvaluationPlan {
        let shouldPredict: Bool
        if isAutomaticEnabled {
            shouldPredict = true
        } else if isTrainingEnabled {
            let interval = state.isTraining
                ? Self.activeTrainingInferenceInterval
                : Self.trainingOnlyInferenceInterval
            shouldPredict = date.timeIntervalSince(lastInferenceAt) >= interval
        } else {
            shouldPredict = false
        }

        var reservoirSlot: Int?
        let shouldConsiderTrainingCandidate = isTrainingEnabled
            && date.timeIntervalSince(lastTrainingCandidateAt) >= Self.trainingCandidateInterval

        if shouldConsiderTrainingCandidate {
            lastTrainingCandidateAt = date
            trainingCandidateSeenCount += 1
            if snapshots.count < Self.trainingReservoirCapacity {
                reservoirSlot = snapshots.count
            } else {
                // Standard reservoir sampling: after the reservoir fills, each
                // 2 Hz training timestamp has equal probability of surviving until swipe.
                let candidate = Int.random(in: 0..<trainingCandidateSeenCount)
                if candidate < Self.trainingReservoirCapacity {
                    reservoirSlot = candidate
                }
            }
        }

        if shouldPredict {
            lastInferenceAt = date
        }
        return PrayerAutoAdvanceEvaluationPlan(
            date: date,
            reservoirSlot: reservoirSlot,
            shouldPredict: shouldPredict
        )
    }

    func recordManualAdvance(at date: Date = Date()) {
        guard isTrainingEnabled,
              let currentContext = context,
              state.model != nil,
              !state.isTraining else { return }

        let pageID = currentContext.pageID
        let startedAt = contextStartedAt
        let candidates = snapshots.filter { $0.pageID == pageID }

#if os(iOS)
        // Freeze the old-page side before setContext starts the next page capture.
        // The ring snapshot itself is copy-on-write; all expensive feature work is
        // delayed and executed off MainActor below.
        let swipeTranscript = capture.transcriptSnapshot()
        let swipeAudio = capture.audioWindow()
#else
        let swipeTranscript = ""
        let swipeAudio = PrayerAutoAdvanceAudioWindow(samples: [], sampleRate: 16_000)
#endif

        state.lastTrainingEvent = "Domykanie okna ręcznego przejścia…"

        Task { @MainActor [weak self] in
            guard let self else { return }
            let diagnostics = PrayerAutoAdvanceTrainingDiagnostics.shared

            // Positive supervision is T±0.2 s. Let the UI transition immediately,
            // but finish collecting the short post-swipe audio tail before training.
            try? await Task.sleep(for: .milliseconds(200))

#if os(iOS)
            let postSwipeAudio = await self.capture.audioWindowOffMain()
#else
            let postSwipeAudio = PrayerAutoAdvanceAudioWindow(samples: [], sampleRate: swipeAudio.sampleRate)
#endif

            let targetDates = PrayerAutoAdvanceTrainingPolicy.positiveTargetDates(manualAdvanceAt: date)
            let positiveSnapshots = await Task.detached(priority: .background) {
                targetDates.compactMap { targetDate -> PrayerAutoAdvanceTrainingSnapshot? in
                    let targetWindow = Self.audioWindow(
                        at: targetDate,
                        manualAdvanceAt: date,
                        preSwipe: swipeAudio,
                        postSwipe: postSwipeAudio
                    )
                    let shortAudio = PrayerAutoAdvanceAudioFeatureExtractor.features(window: targetWindow)
                    let longAudio = PrayerAutoAdvanceLongAudioFeatureExtractor.features(window: targetWindow)
                    let features = PrayerAutoAdvanceFeatureExtractor.features(
                        transcript: swipeTranscript,
                        context: currentContext,
                        elapsed: max(0, targetDate.timeIntervalSince(startedAt)),
                        audioFeatures: shortAudio
                    )
                    guard features.count == PrayerAutoAdvanceCoreMLModel.inputSize,
                          longAudio.count == PrayerAutoAdvanceCoreMLModel.longAudioInputSize else { return nil }
                    return PrayerAutoAdvanceTrainingSnapshot(
                        pageID: pageID,
                        date: targetDate,
                        features: features,
                        longAudioFeatures: longAudio
                    )
                }
            }.value

            // Keep training work out of the critical tail of the transition animation.
            try? await Task.sleep(for: .milliseconds(100))

            guard let batch = PrayerAutoAdvanceTrainingPolicy.makeBatch(
                snapshots: candidates,
                positiveSnapshots: positiveSnapshots,
                manualAdvanceAt: date,
                history: self.state.timingHistory
            ) else {
                diagnostics.skippedTrainingCount += 1
                diagnostics.pipelineState = "skipped"
                diagnostics.event(
                    "training skipped: negatives=\(candidates.count) positives=\(positiveSnapshots.count)"
                )
                self.state.lastTrainingEvent = "Pominięto: nie udało się zbudować zbalansowanego batcha treningowego."
                return
            }

            let positives = batch.samples.filter { $0.label == 1 }.count
            let negatives = batch.samples.count - positives
            diagnostics.event("balanced training batch P/N \(positives)/\(negatives)")

            if self.state.validationStore.shouldHoldOut(pageID: pageID) {
                self.state.validationStore.append(pageID: pageID, batch: batch, at: date)
                do {
                    try await PrayerAutoAdvanceCoreMLDiskState.saveInBackground(self.state)
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

    nonisolated private static func audioWindow(
        at targetDate: Date,
        manualAdvanceAt: Date,
        preSwipe: PrayerAutoAdvanceAudioWindow,
        postSwipe: PrayerAutoAdvanceAudioWindow
    ) -> PrayerAutoAdvanceAudioWindow {
        let sampleRate = preSwipe.sampleRate > 0 ? preSwipe.sampleRate : postSwipe.sampleRate
        guard sampleRate > 0 else {
            return PrayerAutoAdvanceAudioWindow(samples: [], sampleRate: 16_000)
        }

        let offset = targetDate.timeIntervalSince(manualAdvanceAt)
        if offset <= 0 {
            let removeCount = Int((-offset * sampleRate).rounded())
            let keepCount = max(0, preSwipe.samples.count - removeCount)
            return PrayerAutoAdvanceAudioWindow(
                samples: Array(preSwipe.samples.prefix(keepCount)),
                sampleRate: sampleRate
            )
        }

        let requestedPostCount = Int((offset * sampleRate).rounded())
        let postCount = min(max(requestedPostCount, 0), postSwipe.samples.count)
        let postPrefix = Array(postSwipe.samples.prefix(postCount))
        return PrayerAutoAdvanceAudioWindow(
            samples: preSwipe.samples + postPrefix,
            sampleRate: sampleRate
        )
    }
}

struct PrayerAutoAdvanceEvaluationPlan: Sendable {
    let date: Date
    let reservoirSlot: Int?
    let shouldPredict: Bool

    var needsHeavyWork: Bool { reservoirSlot != nil || shouldPredict }
}

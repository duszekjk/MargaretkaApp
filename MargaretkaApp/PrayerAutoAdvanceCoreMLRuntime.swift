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
    let spectralCache = PrayerAutoAdvanceStreamingSpectralCache()
    var lastSpectralSampleIndex = 0
    var context: PrayerAutoAdvanceContext?
    var contextStartedAt = Date()
    var trainingCandidates: [PrayerAutoAdvanceTrainingCandidate] = []
    var evaluationTask: Task<Void, Never>?
    var consecutiveAdvancePredictions = 0
    var cooldownUntil = Date.distantPast
    var lastTrainingSnapshotAt = Date.distantPast
    var lastTrainingCandidateAt = Date.distantPast
    var lastDiagnosticsPublishAt = Date.distantPast
    var lastInferenceAt = Date.distantPast
    var trainingCandidateSeenCount = 0
    var capturedManualAdvancePageID: String?

    static let trainingReservoirCapacity = 16
    static let trainingCandidateInterval: TimeInterval = 0.5
    static let automaticInferenceInterval: TimeInterval = 0.5
    static let diagnosticsPublishInterval: TimeInterval = 2.0
    static let postTransitionProcessingDelay: Duration = .milliseconds(350)

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

    func evaluationPlan(at date: Date) -> PrayerAutoAdvanceEvaluationPlan {
        let shouldPredict = isAutomaticEnabled
            && date.timeIntervalSince(lastInferenceAt) >= Self.automaticInferenceInterval

        var reservoirSlot: Int?
        let shouldConsiderTrainingCandidate = isTrainingEnabled
            && date.timeIntervalSince(lastTrainingCandidateAt) >= Self.trainingCandidateInterval

        if shouldConsiderTrainingCandidate {
            lastTrainingCandidateAt = date
            trainingCandidateSeenCount += 1
            if trainingCandidates.count < Self.trainingReservoirCapacity {
                reservoirSlot = trainingCandidates.count
            } else {
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

    func storeTrainingCandidate(_ candidate: PrayerAutoAdvanceTrainingCandidate, at slot: Int) {
        if trainingCandidates.indices.contains(slot) {
            trainingCandidates[slot] = candidate
        } else if slot == trainingCandidates.count {
            trainingCandidates.append(candidate)
        }
        lastTrainingSnapshotAt = candidate.date
        PrayerAutoAdvanceTrainingDiagnostics.shared.snapshotCount = trainingCandidates.count
    }

    func recordManualAdvance(at date: Date = Date()) {
        guard isTrainingEnabled,
              let currentContext = context else { return }

        let pageID = currentContext.pageID
        guard capturedManualAdvancePageID != pageID else { return }
        capturedManualAdvancePageID = pageID

        let diagnostics = PrayerAutoAdvanceTrainingDiagnostics.shared
        diagnostics.manualSwipeCount += 1
        diagnostics.pipelineState = "selecting"
        diagnostics.event("manual swipe #\(diagnostics.manualSwipeCount)")

        let startedAt = contextStartedAt
        let candidates = trainingCandidates.filter { $0.pageID == pageID }

#if os(iOS)
        // This is an O(1) copy-on-write hand-off of the page PCM buffer. It keeps
        // the old page stable and starts a 200 ms post-boundary PCM capture without
        // running spectral extraction on the UI path.
        let pageAudioDetachedAt = Date()
        let swipeSpeech = capture.speechSnapshot()
        let pageAudioTransition = capture.freezePageAudio(
            postBoundaryDuration: PrayerAutoAdvanceTrainingPolicy.positiveWindow
        )
        let frozenPageAudio = pageAudioTransition.frozenPageAudio
#else
        let pageAudioDetachedAt = Date()
        let swipeSpeech = PrayerAutoAdvanceSpeechSnapshot(transcript: "", lastSegmentEndTime: nil)
        let frozenPageAudio = PrayerAutoAdvanceAudioWindow(samples: [], sampleRate: 16_000)
#endif
        let sampleRate = frozenPageAudio.sampleRate > 0
            ? frozenPageAudio.sampleRate
            : PrayerAutoAdvanceSpectralFrontEnd.sampleRate
        let freezeDelay = max(0, pageAudioDetachedAt.timeIntervalSince(date))
        let samplesAfterGesture = Int((freezeDelay * sampleRate).rounded())
        let swipeSampleIndex = min(
            max(frozenPageAudio.samples.count - samplesAfterGesture, 0),
            frozenPageAudio.samples.count
        )

        diagnostics.snapshotCount = candidates.count
        diagnostics.event(
            "captured page candidates=\(candidates.count) pcm=\(frozenPageAudio.samples.count) swipeSample=\(swipeSampleIndex)"
        )

        state.lastTrainingEvent = "Domykanie okna ręcznego przejścia…"

        Task { @MainActor [weak self] in
            guard let self else { return }
            // The page transition uses a 250 ms animation. Keep feature
            // materialization and Core ML training outside that animation.
            try? await Task.sleep(for: Self.postTransitionProcessingDelay)

#if os(iOS)
            // Resolve the bridge by transition ID. A later, rapid swipe cannot
            // replace this page's post-boundary PCM with audio from another page.
            let postSwipeAudio = self.capture.finishPageAudioTransition(pageAudioTransition)
#else
            let postSwipeAudio = PrayerAutoAdvanceAudioWindow(samples: [], sampleRate: frozenPageAudio.sampleRate)
#endif

            let page = PrayerAutoAdvanceDeferredTrainingPage(
                pageID: pageID,
                context: currentContext,
                contextStartedAt: startedAt,
                manualAdvanceAt: date,
                swipeSampleIndex: swipeSampleIndex,
                swipeSpeech: swipeSpeech,
                candidates: candidates,
                frozenPageAudio: frozenPageAudio,
                postSwipeAudio: postSwipeAudio
            )

            if self.state.model == nil {
                self.state.lastTrainingEvent = "Przygotowywanie modelu przed treningiem…"
                guard await self.state.ensureModelAvailable() else {
                    let diagnostics = PrayerAutoAdvanceTrainingDiagnostics.shared
                    diagnostics.skippedTrainingCount += 1
                    diagnostics.pipelineState = "no-model"
                    diagnostics.error(self.state.lastError ?? "missing local model")
                    self.state.lastTrainingEvent = "Nie udało się przygotować modelu do treningu."
                    self.statusMessage = self.state.lastError
                    return
                }
            }

            if self.state.isTrainingPipelineBusy || self.state.hasQueuedTrainingWork {
                self.state.enqueueTrainingPage(page)
                self.state.lastTrainingEvent = "Strona dodana do kolejki treningowej."
            } else {
                await self.state.processTrainingPageImmediately(page)
            }
            self.statusMessage = self.state.lastError
        }
    }
}

struct PrayerAutoAdvanceEvaluationPlan: Sendable {
    let date: Date
    let reservoirSlot: Int?
    let shouldPredict: Bool
}

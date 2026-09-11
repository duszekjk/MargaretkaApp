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

    static let trainingReservoirCapacity = 16
    static let trainingCandidateInterval: TimeInterval = 0.5
    static let automaticInferenceInterval: TimeInterval = 0.5
    static let diagnosticsPublishInterval: TimeInterval = 2.0

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
    }

    func recordManualAdvance(at date: Date = Date()) {
        guard isTrainingEnabled,
              let currentContext = context,
              state.model != nil else { return }

        let pageID = currentContext.pageID
        let startedAt = contextStartedAt
        let candidates = trainingCandidates.filter { $0.pageID == pageID }

#if os(iOS)
        let freezeCapturedAt = Date()
        let swipeSpeech = capture.speechSnapshot()
        let frozenPageAudio = capture.freezePageAudio()
#else
        let freezeCapturedAt = Date()
        let swipeSpeech = PrayerAutoAdvanceSpeechSnapshot(transcript: "", lastSegmentEndTime: nil)
        let frozenPageAudio = PrayerAutoAdvanceAudioWindow(samples: [], sampleRate: 16_000)
#endif
        let sampleRate = frozenPageAudio.sampleRate > 0
            ? frozenPageAudio.sampleRate
            : PrayerAutoAdvanceSpectralFrontEnd.sampleRate
        let freezeDelay = max(0, freezeCapturedAt.timeIntervalSince(date))
        let samplesAfterGesture = Int((freezeDelay * sampleRate).rounded())
        let swipeSampleIndex = min(
            max(frozenPageAudio.samples.count - samplesAfterGesture, 0),
            frozenPageAudio.samples.count
        )

        state.lastTrainingEvent = "Domykanie okna ręcznego przejścia…"

        Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(200))

#if os(iOS)
            let postSwipeAudio = await self.capture.audioWindowOffMain()
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

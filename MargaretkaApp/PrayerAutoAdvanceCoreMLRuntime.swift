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
    static let trainingOnlyInferenceInterval: TimeInterval = 2.0
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

    /// The scheduler still runs at 4 Hz for automatic switching. Training markers
    /// are admitted at 2 Hz, but they are only timestamp/transcript/audio-index
    /// records. No audio feature extraction is performed for a training-only tick.
    /// While MLUpdateTask is active, diagnostic inference is disabled entirely.
    func evaluationPlan(at date: Date) -> PrayerAutoAdvanceEvaluationPlan {
        let shouldPredict: Bool
        if isAutomaticEnabled {
            shouldPredict = true
        } else if isTrainingEnabled, !state.isTraining {
            shouldPredict = date.timeIntervalSince(lastInferenceAt) >= Self.trainingOnlyInferenceInterval
        } else {
            shouldPredict = false
        }

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
              state.model != nil,
              !state.isTraining else { return }

        let pageID = currentContext.pageID
        let startedAt = contextStartedAt
        let candidates = trainingCandidates.filter { $0.pageID == pageID }

#if os(iOS)
        let swipeTranscript = capture.transcriptSnapshot()
        let swipeAudio = capture.audioWindow()
        let frozenPageAudio = capture.freezePageAudio()
#else
        let swipeTranscript = ""
        let swipeAudio = PrayerAutoAdvanceAudioWindow(samples: [], sampleRate: 16_000)
        let frozenPageAudio = swipeAudio
#endif

        state.lastTrainingEvent = "Domykanie okna ręcznego przejścia…"

        Task { @MainActor [weak self] in
            guard let self else { return }
            let diagnostics = PrayerAutoAdvanceTrainingDiagnostics.shared

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

            let negativeSnapshots = await Task.detached(priority: .background) {
                candidates.compactMap { candidate -> PrayerAutoAdvanceTrainingSnapshot? in
                    let targetWindow = Self.audioWindow(
                        fromFrozenPage: frozenPageAudio,
                        endingAt: candidate.audioEndSampleIndex
                    )
                    let shortAudio = PrayerAutoAdvanceAudioFeatureExtractor.features(window: targetWindow)
                    let longAudio = PrayerAutoAdvanceLongAudioFeatureExtractor.features(window: targetWindow)
                    let features = PrayerAutoAdvanceFeatureExtractor.features(
                        transcript: candidate.transcript,
                        context: currentContext,
                        elapsed: max(0, candidate.date.timeIntervalSince(startedAt)),
                        audioFeatures: shortAudio
                    )
                    guard features.count == PrayerAutoAdvanceCoreMLModel.inputSize,
                          longAudio.count == PrayerAutoAdvanceCoreMLModel.longAudioInputSize else { return nil }
                    return PrayerAutoAdvanceTrainingSnapshot(
                        pageID: candidate.pageID,
                        date: candidate.date,
                        features: features,
                        longAudioFeatures: longAudio
                    )
                }
            }.value

            try? await Task.sleep(for: .milliseconds(100))

            guard let batch = PrayerAutoAdvanceTrainingPolicy.makeBatch(
                snapshots: negativeSnapshots,
                positiveSnapshots: positiveSnapshots,
                manualAdvanceAt: date,
                history: self.state.timingHistory
            ) else {
                diagnostics.skippedTrainingCount += 1
                diagnostics.pipelineState = "skipped"
                diagnostics.event(
                    "training skipped: negatives=\(negativeSnapshots.count) positives=\(positiveSnapshots.count)"
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
        fromFrozenPage page: PrayerAutoAdvanceAudioWindow,
        endingAt sampleIndex: Int
    ) -> PrayerAutoAdvanceAudioWindow {
        guard page.sampleRate > 0 else {
            return PrayerAutoAdvanceAudioWindow(samples: [], sampleRate: 16_000)
        }
        let end = min(max(sampleIndex, 0), page.samples.count)
        let wanted = Int(((PrayerAutoAdvanceLongAudioFeatureExtractor.duration + 0.5) * page.sampleRate).rounded())
        let start = max(0, end - wanted)
        return PrayerAutoAdvanceAudioWindow(
            samples: Array(page.samples[start..<end]),
            sampleRate: page.sampleRate
        )
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
}

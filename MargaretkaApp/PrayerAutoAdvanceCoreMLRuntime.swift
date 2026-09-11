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
              state.model != nil,
              !state.isTraining else { return }

        let pageID = currentContext.pageID
        let startedAt = contextStartedAt
        let candidates = trainingCandidates.filter { $0.pageID == pageID }
        let selectedCandidates = PrayerAutoAdvanceTrainingPolicy.selectNegativeCandidates(
            candidates,
            manualAdvanceAt: date
        )

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
            let diagnostics = PrayerAutoAdvanceTrainingDiagnostics.shared

            try? await Task.sleep(for: .milliseconds(200))

#if os(iOS)
            let postSwipeAudio = await self.capture.audioWindowOffMain()
#else
            let postSwipeAudio = PrayerAutoAdvanceAudioWindow(samples: [], sampleRate: frozenPageAudio.sampleRate)
#endif

            let sampleCount = min(
                PrayerAutoAdvanceTrainingPolicy.maximumSamplesPerClass,
                selectedCandidates.count
            )
            guard sampleCount > 0 else {
                diagnostics.skippedTrainingCount += 1
                diagnostics.pipelineState = "skipped"
                diagnostics.event("training skipped: no eligible T-0.4 negative candidates")
                self.state.lastTrainingEvent = "Pominięto: brak próbki negatywnej przed strefą końcową."
                return
            }

            let targetDates = PrayerAutoAdvanceTrainingPolicy.positiveTargetDates(
                manualAdvanceAt: date,
                count: sampleCount
            )

            let materialized = await Task.detached(priority: .background) {
                let bridgeCount = min(
                    postSwipeAudio.samples.count,
                    max(0, Int((PrayerAutoAdvanceTrainingPolicy.positiveWindow * sampleRate).rounded()))
                )
                let combinedSamples = frozenPageAudio.samples
                    + Array(postSwipeAudio.samples.prefix(bridgeCount))
                let history = PrayerAutoAdvanceSpectralFrontEnd.analyze(samples: combinedSamples)

                let negatives = selectedCandidates.prefix(sampleCount).compactMap {
                    candidate -> PrayerAutoAdvanceTrainingSnapshot? in
                    let endSampleIndex = min(max(candidate.audioEndSampleIndex, 0), combinedSamples.count)
                    let shortAudio = history.shortFeatures(endingAt: endSampleIndex)
                    let longAudio = history.longFeatures(endingAt: endSampleIndex)
                    let features = PrayerAutoAdvanceFeatureExtractor.features(
                        transcript: candidate.transcript,
                        context: currentContext,
                        elapsed: max(0, candidate.date.timeIntervalSince(startedAt)),
                        lastSegmentEndTime: candidate.lastSegmentEndTime,
                        audioFeatures: shortAudio
                    )
                    guard features.count == PrayerAutoAdvanceCoreMLModel.inputSize,
                          longAudio.count == PrayerAutoAdvanceCoreMLModel.longAudioInputSize else {
                        return nil
                    }
                    return PrayerAutoAdvanceTrainingSnapshot(
                        pageID: candidate.pageID,
                        date: candidate.date,
                        features: features,
                        longAudioFeatures: longAudio
                    )
                }

                let positives = targetDates.compactMap {
                    targetDate -> PrayerAutoAdvanceTrainingSnapshot? in
                    let offset = targetDate.timeIntervalSince(date)
                    let endSampleIndex = min(
                        max(swipeSampleIndex + Int((offset * sampleRate).rounded()), 0),
                        combinedSamples.count
                    )
                    let shortAudio = history.shortFeatures(endingAt: endSampleIndex)
                    let longAudio = history.longFeatures(endingAt: endSampleIndex)
                    let features = PrayerAutoAdvanceFeatureExtractor.features(
                        transcript: swipeSpeech.transcript,
                        context: currentContext,
                        elapsed: max(0, targetDate.timeIntervalSince(startedAt)),
                        lastSegmentEndTime: swipeSpeech.lastSegmentEndTime,
                        audioFeatures: shortAudio
                    )
                    guard features.count == PrayerAutoAdvanceCoreMLModel.inputSize,
                          longAudio.count == PrayerAutoAdvanceCoreMLModel.longAudioInputSize else {
                        return nil
                    }
                    return PrayerAutoAdvanceTrainingSnapshot(
                        pageID: pageID,
                        date: targetDate,
                        features: features,
                        longAudioFeatures: longAudio
                    )
                }
                return (negatives, positives)
            }.value

            try? await Task.sleep(for: .milliseconds(100))

            guard let batch = PrayerAutoAdvanceTrainingPolicy.makeBatch(
                snapshots: materialized.0,
                positiveSnapshots: materialized.1,
                manualAdvanceAt: date,
                history: self.state.timingHistory
            ) else {
                diagnostics.skippedTrainingCount += 1
                diagnostics.pipelineState = "skipped"
                diagnostics.event(
                    "training skipped: negatives=\(materialized.0.count) positives=\(materialized.1.count)"
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
}

struct PrayerAutoAdvanceEvaluationPlan: Sendable {
    let date: Date
    let reservoirSlot: Int?
    let shouldPredict: Bool
}

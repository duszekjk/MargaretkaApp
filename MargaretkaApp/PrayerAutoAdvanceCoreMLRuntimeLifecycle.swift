import Foundation

extension PrayerAutoAdvanceCoreMLRuntime {
    func setContext(_ newContext: PrayerAutoAdvanceContext?) {
        guard context != newContext else { return }
        context = newContext
        contextStartedAt = Date()
        trainingCandidates.removeAll(keepingCapacity: true)
        lastTrainingSnapshotAt = Date.distantPast
        lastTrainingCandidateAt = Date.distantPast
        lastInferenceAt = Date.distantPast
        lastDiagnosticsPublishAt = Date.distantPast
        trainingCandidateSeenCount = 0
        capturedManualAdvancePageID = nil
        consecutiveAdvancePredictions = 0
        cooldownUntil = Date.distantPast
        lastPrediction = 0
        lastSpectralSampleIndex = 0
        spectralCache.reset()

        if newContext == nil || !isFeatureEnabled {
            stopListening()
            return
        }
        startEvaluationLoop()
        schedulePrepareListening()
    }

    func preferencesDidChange() {
        guard context != nil, isFeatureEnabled else {
            stopListening()
            return
        }
        startEvaluationLoop()
        schedulePrepareListening()
    }

    func stop() {
        context = nil
        stopListening()
    }

    func startEvaluationLoop() {
        guard evaluationTask == nil else { return }
        evaluationTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                await self.evaluateCurrentCapture()
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    func schedulePrepareListening() {
        listeningTask?.cancel()
        listeningTask = Task { @MainActor [weak self] in
            guard let self, !Task.isCancelled else { return }
            await self.prepareListening()
        }
    }

    func stopListening() {
        listeningTask?.cancel()
        listeningTask = nil
        evaluationTask?.cancel()
        evaluationTask = nil
        lastSpectralSampleIndex = 0
        spectralCache.reset()
        state.resetMicrophoneActivity()
#if os(iOS)
        capture.stop()
#endif
        PrayerAutoAdvanceTrainingDiagnostics.shared.speechState = "idle"
    }
}

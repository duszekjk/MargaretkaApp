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
        consecutiveAdvancePredictions = 0
        lastPrediction = 0

        if newContext == nil || !isFeatureEnabled {
            stopListening()
            return
        }
        startEvaluationLoop()
        Task { @MainActor [weak self] in
            await self?.prepareListening()
        }
    }

    func preferencesDidChange() {
        guard context != nil, isFeatureEnabled else {
            stopListening()
            return
        }
        startEvaluationLoop()
        Task { @MainActor [weak self] in
            await self?.prepareListening()
        }
    }

    func stop() {
        context = nil
        stopListening()
    }

    func startEvaluationLoop() {
        guard evaluationTask == nil else { return }
        evaluationTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                // 4 Hz remains for automatic prediction responsiveness. Training
                // markers are separately throttled to 2 Hz and are metadata-only.
                await self.evaluateCurrentCapture()
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    func stopListening() {
        evaluationTask?.cancel()
        evaluationTask = nil
#if os(iOS)
        capture.stop()
#endif
        PrayerAutoAdvanceTrainingDiagnostics.shared.speechState = "idle"
    }
}

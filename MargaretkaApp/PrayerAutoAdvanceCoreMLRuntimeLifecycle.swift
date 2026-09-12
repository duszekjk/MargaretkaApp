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
        lastSpectralSampleIndex = 0
        spectralCache.reset()

        // A page-start snapshot is always a valid "stay" example. Keeping it in
        // the reservoir guarantees that normal pages can form a balanced batch
        // even if the 2 Hz sampling task is delayed by UI or thermal pressure.
        if let newContext, isTrainingEnabled {
            trainingCandidates.append(
                PrayerAutoAdvanceTrainingCandidate(
                    pageID: newContext.pageID,
                    date: contextStartedAt,
                    transcript: "",
                    lastSegmentEndTime: nil,
                    audioEndSampleIndex: 0
                )
            )
            PrayerAutoAdvanceTrainingDiagnostics.shared.snapshotCount = trainingCandidates.count
        }

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
                await self.evaluateCurrentCapture()
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    func stopListening() {
        evaluationTask?.cancel()
        evaluationTask = nil
        lastSpectralSampleIndex = 0
        spectralCache.reset()
#if os(iOS)
        capture.stop()
#endif
        PrayerAutoAdvanceTrainingDiagnostics.shared.speechState = "idle"
    }
}

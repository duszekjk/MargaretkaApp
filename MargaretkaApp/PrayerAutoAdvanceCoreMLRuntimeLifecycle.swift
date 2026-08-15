import Foundation

extension PrayerAutoAdvanceCoreMLRuntime {
    func setContext(_ newContext: PrayerAutoAdvanceContext?) {
        guard context != newContext else { return }
        context = newContext
        contextStartedAt = Date()
        snapshots.removeAll(keepingCapacity: true)
        lastTrainingSnapshotAt = Date.distantPast
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
                await self.evaluateCurrentCapture()
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    func stopListening() {
        evaluationTask?.cancel()
        evaluationTask = nil
#if os(iOS)
        capture.stop()
#endif
    }
}

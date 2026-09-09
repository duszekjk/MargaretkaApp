import Foundation

extension PrayerAutoAdvanceCoreMLRuntime {
    func observe(
        transcript: String,
        audioWindow: PrayerAutoAdvanceAudioWindow,
        plan: PrayerAutoAdvanceEvaluationPlan
    ) async {
        guard let context,
              let model = state.model else { return }

        let elapsed = plan.date.timeIntervalSince(contextStartedAt)
        let taskPriority: TaskPriority = isAutomaticEnabled ? .userInitiated : .background

        do {
            // V10 feature extraction and every Core ML prediction stay entirely off
            // MainActor. Training-only work deliberately uses background QoS so UI
            // rendering wins CPU contention; automatic switching raises priority.
            let result = try await Task.detached(priority: taskPriority) {
                let shortAudio = PrayerAutoAdvanceAudioFeatureExtractor.features(window: audioWindow)
                let longAudio = PrayerAutoAdvanceLongAudioFeatureExtractor.features(window: audioWindow)
                let features = PrayerAutoAdvanceFeatureExtractor.features(
                    transcript: transcript,
                    context: context,
                    elapsed: elapsed,
                    audioFeatures: shortAudio
                )
                guard features.count == PrayerAutoAdvanceCoreMLModel.inputSize,
                      longAudio.count == PrayerAutoAdvanceCoreMLModel.longAudioInputSize else {
                    throw PrayerAutoAdvanceCoreMLModel.ModelError.invalidFeatureCount
                }

                let prediction: Float?
                if plan.shouldPredict {
                    prediction = try model.prediction(
                        for: features,
                        longAudioFeatures: longAudio
                    )
                } else {
                    prediction = nil
                }
                return (features, longAudio, prediction)
            }.value

            let features = result.0
            let longAudioFeatures = result.1

            if let slot = plan.reservoirSlot {
                let snapshot = PrayerAutoAdvanceTrainingSnapshot(
                    pageID: context.pageID,
                    date: plan.date,
                    features: features,
                    longAudioFeatures: longAudioFeatures
                )
                if snapshots.indices.contains(slot) {
                    snapshots[slot] = snapshot
                } else if slot == snapshots.count {
                    snapshots.append(snapshot)
                }
                lastTrainingSnapshotAt = plan.date
            }

            guard let value = result.2 else { return }
            lastPrediction = value

            // HUD is only a coarse liveness indicator. 0.5 Hz is sufficient even
            // when automatic mode evaluates the model at 4 Hz.
            if plan.date.timeIntervalSince(lastDiagnosticsPublishAt) >= Self.diagnosticsPublishInterval {
                PrayerAutoAdvanceTrainingDiagnostics.shared.prediction(
                    value,
                    snapshotCount: snapshots.count,
                    features: features
                )
                lastDiagnosticsPublishAt = plan.date
            }

            PrayerAutoAdvanceInputDiagnostics.shared.record(
                pageID: context.pageID,
                prediction: value,
                features: features,
                longAudioFeatures: longAudioFeatures,
                audioWindow: audioWindow,
                transcript: transcript,
                pageText: context.currentText,
                at: plan.date
            )
            evaluatePrediction(value, elapsed: elapsed)
        } catch {
            statusMessage = error.localizedDescription
            PrayerAutoAdvanceTrainingDiagnostics.shared.error(error.localizedDescription)
        }
    }
}

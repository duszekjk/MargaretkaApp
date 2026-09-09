import Foundation

extension PrayerAutoAdvanceCoreMLRuntime {
    func observe(
        transcript: String,
        audioWindow: PrayerAutoAdvanceAudioWindow,
        plan: PrayerAutoAdvanceEvaluationPlan
    ) async {
        guard let context,
              let model = state.model,
              plan.shouldPredict else { return }

        let elapsed = plan.date.timeIntervalSince(contextStartedAt)
        let taskPriority: TaskPriority = isAutomaticEnabled ? .userInitiated : .background

        do {
            // Heavy feature extraction is now required here only for inference.
            // Training-only 2 Hz markers never enter this path.
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

                let prediction = try model.prediction(
                    for: features,
                    longAudioFeatures: longAudio
                )
                return (features, longAudio, prediction)
            }.value

            let features = result.0
            let longAudioFeatures = result.1
            let value = result.2
            lastPrediction = value

            if plan.date.timeIntervalSince(lastDiagnosticsPublishAt) >= Self.diagnosticsPublishInterval {
                PrayerAutoAdvanceTrainingDiagnostics.shared.prediction(
                    value,
                    snapshotCount: trainingCandidates.count,
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

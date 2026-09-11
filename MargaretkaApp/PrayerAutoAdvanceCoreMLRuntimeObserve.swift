import Foundation

extension PrayerAutoAdvanceCoreMLRuntime {
    func observe(
        speech: PrayerAutoAdvanceSpeechSnapshot,
        shortAudio: [Float],
        longAudio: [Float],
        plan: PrayerAutoAdvanceEvaluationPlan
    ) async {
        guard let context,
              let model = state.model,
              plan.shouldPredict else { return }

        let elapsed = plan.date.timeIntervalSince(contextStartedAt)

        do {
            let result = try await Task.detached(priority: .userInitiated) {
                let features = PrayerAutoAdvanceFeatureExtractor.features(
                    transcript: speech.transcript,
                    context: context,
                    elapsed: elapsed,
                    lastSegmentEndTime: speech.lastSegmentEndTime,
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
                return (features, prediction)
            }.value

            let features = result.0
            let value = result.1
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
                longAudioFeatures: longAudio,
                audioWindow: nil,
                transcript: speech.transcript,
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

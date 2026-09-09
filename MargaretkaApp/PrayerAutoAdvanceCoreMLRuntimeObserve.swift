import Foundation

extension PrayerAutoAdvanceCoreMLRuntime {
    func observe(transcript: String, audioWindow: PrayerAutoAdvanceAudioWindow) async {
        guard let context,
              let model = state.model else { return }

        let now = Date()
        let elapsed = now.timeIntervalSince(contextStartedAt)

        do {
            // V10 feature extraction + Core ML inference are CPU-heavy. Keep the
            // complete inference path off MainActor; only publish the finished
            // result and mutate UI-facing state below.
            let inference = try await Task.detached(priority: .utility) {
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

            let features = inference.0
            let longAudioFeatures = inference.1
            let value = inference.2

            // Keep training candidates at 4 Hz. Silent/title pages are intentionally
            // included: their empty spoken embedding plus audio/page/timing features
            // are valid model inputs and must be learnable.
            if now.timeIntervalSince(lastTrainingSnapshotAt) >= 0.25 {
                snapshots.append(
                    PrayerAutoAdvanceTrainingSnapshot(
                        pageID: context.pageID,
                        date: now,
                        features: features,
                        longAudioFeatures: longAudioFeatures
                    )
                )
                lastTrainingSnapshotAt = now
                // Keep enough history for long pages; the policy samples at most 12.
                if snapshots.count > 1_000 { snapshots.removeFirst(snapshots.count - 1_000) }
            }

            lastPrediction = value
            PrayerAutoAdvanceTrainingDiagnostics.shared.prediction(
                value,
                snapshotCount: snapshots.count,
                features: features
            )
            PrayerAutoAdvanceInputDiagnostics.shared.record(
                pageID: context.pageID,
                prediction: value,
                features: features,
                longAudioFeatures: longAudioFeatures,
                audioWindow: audioWindow,
                transcript: transcript,
                pageText: context.currentText,
                at: now
            )
            evaluatePrediction(value, elapsed: elapsed)
        } catch {
            statusMessage = error.localizedDescription
            PrayerAutoAdvanceTrainingDiagnostics.shared.error(error.localizedDescription)
        }
    }
}

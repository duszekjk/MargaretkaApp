import Foundation

extension PrayerAutoAdvanceCoreMLRuntime {
    func observe(transcript: String, audioWindow: PrayerAutoAdvanceAudioWindow) async {
        guard let context,
              let model = state.model,
              !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let now = Date()
        let elapsed = now.timeIntervalSince(contextStartedAt)
        let extracted = await Task.detached(priority: .utility) {
            let shortAudio = PrayerAutoAdvanceAudioFeatureExtractor.features(window: audioWindow)
            let longAudio = PrayerAutoAdvanceLongAudioFeatureExtractor.features(window: audioWindow)
            let features = PrayerAutoAdvanceFeatureExtractor.features(
                transcript: transcript,
                context: context,
                elapsed: elapsed,
                audioFeatures: shortAudio
            )
            return (features, longAudio)
        }.value
        let features = extracted.0
        let longAudioFeatures = extracted.1
        guard features.count == PrayerAutoAdvanceCoreMLModel.inputSize,
              longAudioFeatures.count == PrayerAutoAdvanceCoreMLModel.longAudioInputSize else { return }

        if now.timeIntervalSince(lastTrainingSnapshotAt) >= 0.5 {
            snapshots.append(
                PrayerAutoAdvanceTrainingSnapshot(
                    pageID: context.pageID,
                    date: now,
                    features: features,
                    longAudioFeatures: longAudioFeatures
                )
            )
            lastTrainingSnapshotAt = now
            if snapshots.count > 80 { snapshots.removeFirst(snapshots.count - 80) }
        }

        do {
            let value = try model.prediction(
                for: features,
                longAudioFeatures: longAudioFeatures
            )
            lastPrediction = value
            PrayerAutoAdvanceTrainingDiagnostics.shared.prediction(
                value,
                snapshotCount: snapshots.count,
                features: features
            )
            evaluatePrediction(value, elapsed: elapsed)
        } catch {
            statusMessage = error.localizedDescription
            PrayerAutoAdvanceTrainingDiagnostics.shared.error(error.localizedDescription)
        }
    }
}

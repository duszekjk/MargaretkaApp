import Foundation

extension PrayerAutoAdvanceCoreMLRuntime {
    func observe(transcript: String, audioWindow: PrayerAutoAdvanceAudioWindow) async {
        guard let context,
              let model = state.model,
              !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let now = Date()
        let elapsed = now.timeIntervalSince(contextStartedAt)
        let features: [Float] = await Task.detached(priority: .utility) {
            let audioFeatures = PrayerAutoAdvanceAudioFeatureExtractor.features(window: audioWindow)
            return PrayerAutoAdvanceFeatureExtractor.features(
                transcript: transcript,
                context: context,
                elapsed: elapsed,
                audioFeatures: audioFeatures
            )
        }.value
        guard features.count == PrayerAutoAdvanceCoreMLModel.inputSize else { return }

        if now.timeIntervalSince(lastTrainingSnapshotAt) >= 0.5 {
            snapshots.append(
                PrayerAutoAdvanceTrainingSnapshot(
                    pageID: context.pageID,
                    date: now,
                    features: features,
                    endingCoverage: features[4],
                    spokenRatio: features[6],
                    currentSimilarity: features[0],
                    nextSimilarity: features[1]
                )
            )
            lastTrainingSnapshotAt = now
            if snapshots.count > 40 { snapshots.removeFirst(snapshots.count - 40) }
        }

        do {
            let value = try model.prediction(for: features)
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

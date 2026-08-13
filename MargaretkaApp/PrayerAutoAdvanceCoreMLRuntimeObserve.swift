import Foundation

extension PrayerAutoAdvanceCoreMLRuntime {
    func observe(transcript: String, energy: Float, silence: TimeInterval) async {
        guard let context,
              let model = state.model,
              !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let elapsed = Date().timeIntervalSince(contextStartedAt)
        let features: [Float] = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: PrayerAutoAdvanceFeatureExtractor.features(
                    transcript: transcript,
                    context: context,
                    elapsed: elapsed,
                    silence: silence,
                    energy: energy
                ))
            }
        }
        guard features.count == PrayerAutoAdvanceCoreMLModel.inputSize else { return }

        snapshots.append(
            PrayerAutoAdvanceTrainingSnapshot(
                pageID: context.pageID,
                date: Date(),
                features: features,
                endingCoverage: features[4],
                spokenRatio: features[8],
                currentSimilarity: features[0],
                nextSimilarity: features[1],
                silenceDuration: silence
            )
        )
        if snapshots.count > 40 { snapshots.removeFirst(snapshots.count - 40) }

        do {
            let value = try model.prediction(for: features)
            lastPrediction = value
            evaluatePrediction(value, elapsed: elapsed)
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

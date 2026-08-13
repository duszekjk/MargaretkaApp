import Foundation

extension PrayerAutoAdvanceCoreMLState {
    func train(_ batch: PrayerAutoAdvanceLabeledBatch) async {
        guard !isTraining, let current = model else { return }
        isTraining = true
        lastTrainingEvent = "Aktualizowanie modelu lokalnego…"
        defer { isTraining = false }

        let updatedURL = directory.appendingPathComponent("Updated.mlmodelc", isDirectory: true)
        do {
            try await PrayerAutoAdvanceCoreMLModel.update(
                modelAt: current.compiledURL,
                samples: batch.samples,
                savingTo: updatedURL
            )
            _ = try fileManager.replaceItemAt(modelURL, withItemAt: updatedURL)
            model = try PrayerAutoAdvanceCoreMLModel(compiledURL: modelURL)

            timingHistory.append(batch.observedDelay)
            if var value = metadata {
                value.lastUpdatedAt = Date()
                value.trainedTransitions += 1
                value.trainingSessions += 1
                metadata = value
            }
            try PrayerAutoAdvanceCoreMLDiskState.save(self)
            lastError = nil
            lastTrainingEvent = "Model zaktualizowany na podstawie \(batch.samples.count) próbek."
        } catch {
            try? fileManager.removeItem(at: updatedURL)
            lastError = error.localizedDescription
            lastTrainingEvent = "Błąd aktualizacji modelu: \(error.localizedDescription)"
        }
    }
}

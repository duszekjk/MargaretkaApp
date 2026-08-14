import Foundation

extension PrayerAutoAdvanceCoreMLState {
    func train(_ batch: PrayerAutoAdvanceLabeledBatch) async {
        guard !isTraining, let current = model else { return }
        let diagnostics = PrayerAutoAdvanceTrainingDiagnostics.shared
        isTraining = true
        diagnostics.pipelineState = "training"
        let lossBefore = diagnostics.evaluateBatch(
            model: current,
            samples: batch.samples,
            phase: "before"
        )
        let delayText = batch.observedDelay.map { String(format: "%.2fs", $0) } ?? "n/a"
        diagnostics.event("MLUpdateTask start samples=\(batch.samples.count) delay=\(delayText)")
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

            let lossAfter: Double?
            let validationMargin: Double?
            if let updatedModel = model {
                lossAfter = diagnostics.evaluateBatch(
                    model: updatedModel,
                    samples: batch.samples,
                    phase: "after"
                )
                validationMargin = validationStore.margin(using: updatedModel)
            } else {
                lossAfter = nil
                validationMargin = nil
            }
            diagnostics.recordLossChange(before: lossBefore, after: lossAfter)
            diagnostics.recordSuccessfulTrainingEpochSample(
                trainingMargin: diagnostics.predictionMargin,
                validationMargin: validationMargin
            )

            if let observedDelay = batch.observedDelay {
                timingHistory.append(observedDelay)
            }
            if var value = metadata {
                value.lastUpdatedAt = Date()
                value.trainedTransitions += 1
                value.trainingSessions += 1
                metadata = value
            }
            try PrayerAutoAdvanceCoreMLDiskState.save(self)
            lastError = nil
            lastTrainingEvent = "Model zaktualizowany na podstawie \(batch.samples.count) próbek."
            diagnostics.acceptedTrainingCount += 1
            diagnostics.pipelineState = "trained"
            if let validationMargin {
                diagnostics.event(String(format: "validation margin=%+.3f samples=%d", validationMargin, validationStore.sampleCount))
            }
            diagnostics.event("MLUpdateTask complete")
        } catch {
            try? fileManager.removeItem(at: updatedURL)
            lastError = error.localizedDescription
            lastTrainingEvent = "Błąd aktualizacji modelu: \(error.localizedDescription)"
            diagnostics.pipelineState = "error"
            diagnostics.error(error.localizedDescription)
        }
    }
}

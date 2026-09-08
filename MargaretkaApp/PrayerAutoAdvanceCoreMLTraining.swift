import Foundation

extension PrayerAutoAdvanceCoreMLState {
    func train(_ batch: PrayerAutoAdvanceLabeledBatch) async {
        guard !isTraining, let current = model else { return }
        let diagnostics = PrayerAutoAdvanceTrainingDiagnostics.shared
        isTraining = true
        diagnostics.pipelineState = "training"

        let before = diagnostics.evaluateBatch(
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

            if let updatedModel = model,
               let before,
               let after = diagnostics.evaluateBatch(
                    model: updatedModel,
                    samples: batch.samples,
                    phase: "after"
               ) {
                let validation = validationStore.metrics(using: updatedModel)
                diagnostics.recordTrainingUpdate(
                    before: before,
                    after: after,
                    validation: validation
                )
                diagnostics.event(
                    String(
                        format: "heartbeat loss %.8f→%.8f Δ=%+.8f predΔ mean=%.8f max=%.8f",
                        before.loss,
                        after.loss,
                        before.loss - after.loss,
                        diagnostics.lastMeanPredictionDelta ?? 0,
                        diagnostics.lastMaxPredictionDelta ?? 0
                    )
                )
                if let validationLoss = validation.loss {
                    diagnostics.event(
                        String(
                            format: "validation loss=%.8f margin=%+.5f samples=%d",
                            validationLoss,
                            validation.margin ?? 0,
                            validation.sampleCount
                        )
                    )
                }
            } else {
                diagnostics.event("heartbeat unavailable: batch evaluation failed")
            }

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

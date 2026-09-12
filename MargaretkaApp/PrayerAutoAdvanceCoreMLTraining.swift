import Foundation

extension PrayerAutoAdvanceCoreMLState {
    func train(_ batch: PrayerAutoAdvanceLabeledBatch) async {
        let diagnostics = PrayerAutoAdvanceTrainingDiagnostics.shared
        guard !isTraining else {
            diagnostics.pipelineState = "pipeline-overlap"
            diagnostics.error("training invariant violated: overlapping MLUpdateTask")
            lastError = "Wykryto nakładające się kroki treningowe."
            lastTrainingEvent = lastError
            return
        }
        guard let current = model else {
            diagnostics.pipelineState = "no-model"
            diagnostics.error("training invariant violated: missing model")
            lastError = "Brak lokalnego modelu podczas rozpoczynania treningu."
            lastTrainingEvent = lastError
            return
        }
        isTraining = true
        diagnostics.pipelineState = "training"

        let before = await Task.detached(priority: .utility) {
            PrayerAutoAdvanceBackgroundEvaluation.evaluate(
                model: current,
                samples: batch.samples
            )
        }.value

        let delayText = batch.observedDelay.map { String(format: "%.2fs", $0) } ?? "n/a"
        diagnostics.event("MLUpdateTask start samples=\(batch.samples.count) delay=\(delayText)")
        lastTrainingEvent = "Aktualizowanie modelu lokalnego…"
        defer { isTraining = false }

        let updatedURL = directory.appendingPathComponent("Updated.mlmodelc", isDirectory: true)
        let destinationModelURL = modelURL
        do {
            try await PrayerAutoAdvanceCoreMLModel.update(
                modelAt: current.compiledURL,
                samples: batch.samples,
                savingTo: updatedURL
            )

            let updatedModel = try await Task.detached(priority: .utility) {
                let fileManager = FileManager.default
                _ = try fileManager.replaceItemAt(destinationModelURL, withItemAt: updatedURL)
                return try PrayerAutoAdvanceCoreMLModel(compiledURL: destinationModelURL)
            }.value
            model = updatedModel

            if let before {
                let validationSnapshot = validationStore
                let evaluations = await Task.detached(priority: .utility) {
                    let after = PrayerAutoAdvanceBackgroundEvaluation.evaluate(
                        model: updatedModel,
                        samples: batch.samples
                    )
                    let validation = PrayerAutoAdvanceBackgroundEvaluation.validationMetrics(
                        store: validationSnapshot,
                        model: updatedModel
                    )
                    return (after, validation)
                }.value

                if let after = evaluations.0 {
                    let validation = evaluations.1
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

            // Validation JSON contains full V12 multimodal feature vectors. Encode
            // and atomically write it on a utility worker, never on MainActor.
            try await PrayerAutoAdvanceCoreMLDiskState.saveInBackground(self)

            lastError = nil
            lastTrainingEvent = "Model zaktualizowany na podstawie \(batch.samples.count) próbek."
            diagnostics.acceptedTrainingCount += 1
            diagnostics.pipelineState = "trained"
            diagnostics.event("MLUpdateTask complete")
        } catch {
            let staleURL = updatedURL
            Task.detached(priority: .utility) {
                try? FileManager.default.removeItem(at: staleURL)
            }
            lastError = error.localizedDescription
            lastTrainingEvent = "Błąd aktualizacji modelu: \(error.localizedDescription)"
            diagnostics.pipelineState = "error"
            diagnostics.error(error.localizedDescription)
        }
    }
}

private enum PrayerAutoAdvanceBackgroundEvaluation {
    static func evaluate(
        model: PrayerAutoAdvanceCoreMLModel,
        samples: [PrayerAutoAdvanceLabeledSample]
    ) -> PrayerAutoAdvanceBatchEvaluation? {
        var positive: [Double] = []
        var negative: [Double] = []
        var losses: [Double] = []
        var predictions: [Double] = []

        for sample in samples {
            guard let raw = try? model.prediction(
                for: sample.features,
                longAudioFeatures: sample.longAudioFeatures
            ) else { continue }
            let p = min(max(Double(raw), 1e-6), 1 - 1e-6)
            predictions.append(p)
            if sample.label == 1 {
                positive.append(p)
                losses.append(-log(p))
            } else {
                negative.append(p)
                losses.append(-log(1 - p))
            }
        }

        guard !losses.isEmpty else { return nil }
        let pos = average(positive)
        let neg = average(negative)
        let margin = pos.flatMap { p in neg.map { p - $0 } }
        return PrayerAutoAdvanceBatchEvaluation(
            loss: losses.reduce(0, +) / Double(losses.count),
            positiveAverage: pos,
            negativeAverage: neg,
            margin: margin,
            predictions: predictions,
            positiveCount: positive.count,
            negativeCount: negative.count
        )
    }

    static func validationMetrics(
        store: PrayerAutoAdvanceValidationStore,
        model: PrayerAutoAdvanceCoreMLModel
    ) -> PrayerAutoAdvanceValidationMetrics {
        var positive: [Double] = []
        var negative: [Double] = []
        var losses: [Double] = []
        var evaluated = 0

        for record in store.records {
            for sample in record.samples {
                guard let prediction = try? model.prediction(
                    for: sample.features,
                    longAudioFeatures: sample.longAudioFeatures
                ) else { continue }
                evaluated += 1
                let p = min(max(Double(prediction), 1e-6), 1 - 1e-6)
                if sample.label == 1 {
                    positive.append(p)
                    losses.append(-log(p))
                } else {
                    negative.append(p)
                    losses.append(-log(1 - p))
                }
            }
        }

        let positiveAverage = average(positive)
        let negativeAverage = average(negative)
        let margin = positiveAverage.flatMap { p in negativeAverage.map { p - $0 } }
        return PrayerAutoAdvanceValidationMetrics(
            sampleCount: evaluated,
            positiveCount: positive.count,
            negativeCount: negative.count,
            positiveAverage: positiveAverage,
            negativeAverage: negativeAverage,
            margin: margin,
            loss: average(losses)
        )
    }

    private static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}

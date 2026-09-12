import Foundation

extension PrayerAutoAdvanceCoreMLState {
    func train(
        _ batch: PrayerAutoAdvanceLabeledBatch,
        trainedPageCount: Int
    ) async -> Bool {
        let diagnostics = PrayerAutoAdvanceTrainingDiagnostics.shared
        guard !isTraining else {
            diagnostics.pipelineState = "pipeline-overlap"
            diagnostics.error("training invariant violated: overlapping MLUpdateTask")
            lastError = "Wykryto nakładające się kroki treningowe."
            lastTrainingEvent = lastError
            recordTrainingTrace("FAIL preflight: overlapping MLUpdateTask")
            return false
        }
        guard let current = model else {
            diagnostics.pipelineState = "no-model"
            diagnostics.error("training invariant violated: missing model")
            lastError = "Brak lokalnego modelu podczas rozpoczynania treningu."
            lastTrainingEvent = lastError
            recordTrainingTrace("FAIL preflight: missing local model")
            return false
        }

        isTraining = true
        defer { isTraining = false }

        var stage = "preflight"
        let delayText = batch.observedDelay.map { String(format: "%.2fs", $0) } ?? "n/a"
        recordTrainingTrace(
            "START pages=\(trainedPageCount) samples=\(batch.samples.count) delay=\(delayText) model=\(current.compiledURL.lastPathComponent)"
        )

        let updatedURL = directory.appendingPathComponent("Updated.mlmodelc", isDirectory: true)
        let destinationModelURL = modelURL

        do {
            stage = "evaluation-before"
            diagnostics.pipelineState = stage
            lastTrainingEvent = "Sprawdzanie modelu przed treningiem…"
            recordTrainingTrace("evaluation-before: start")
            let beforeEvaluation = await Task.detached(priority: .utility) {
                PrayerAutoAdvanceBackgroundEvaluation.evaluate(
                    model: current,
                    samples: batch.samples
                )
            }.value
            guard let before = beforeEvaluation else {
                throw PrayerAutoAdvanceTrainingVerificationError.evaluationBeforeFailed
            }
            recordTrainingTrace(
                String(
                    format: "evaluation-before: loss=%.8f P/N=%d/%d",
                    before.loss,
                    before.positiveCount,
                    before.negativeCount
                )
            )

            stage = "coreml-update"
            diagnostics.pipelineState = stage
            diagnostics.event("MLUpdateTask start samples=\(batch.samples.count) delay=\(delayText)")
            lastTrainingEvent = "Core ML aktualizuje wagi modelu…"
            recordTrainingTrace("coreml-update: MLUpdateTask resume epochs=\(PrayerAutoAdvanceCoreMLModel.trainingEpochCount)")
            try await PrayerAutoAdvanceCoreMLModel.update(
                modelAt: current.compiledURL,
                samples: batch.samples,
                savingTo: updatedURL
            )
            recordTrainingTrace("coreml-update: completion handler returned model")

            stage = "verification-after"
            diagnostics.pipelineState = stage
            lastTrainingEvent = "Weryfikowanie wyniku treningu przed zapisaniem…"
            recordTrainingTrace("verification-after: loading Updated.mlmodelc")
            let candidateModel = try await Task.detached(priority: .utility) {
                try PrayerAutoAdvanceCoreMLModel(compiledURL: updatedURL)
            }.value

            let validationSnapshot = validationStore
            let evaluations = await Task.detached(priority: .utility) {
                let after = PrayerAutoAdvanceBackgroundEvaluation.evaluate(
                    model: candidateModel,
                    samples: batch.samples
                )
                let validation = PrayerAutoAdvanceBackgroundEvaluation.validationMetrics(
                    store: validationSnapshot,
                    model: candidateModel
                )
                return (after, validation)
            }.value

            guard let after = evaluations.0 else {
                throw PrayerAutoAdvanceTrainingVerificationError.evaluationAfterFailed
            }
            guard before.predictions.count == after.predictions.count,
                  before.positiveCount == after.positiveCount,
                  before.negativeCount == after.negativeCount else {
                throw PrayerAutoAdvanceTrainingVerificationError.incompleteEvaluation(
                    before: before.predictions.count,
                    after: after.predictions.count,
                    expected: batch.samples.count
                )
            }

            let predictionDeltas = zip(before.predictions, after.predictions).map { abs($1 - $0) }
            let meanDelta = predictionDeltas.isEmpty
                ? 0
                : predictionDeltas.reduce(0, +) / Double(predictionDeltas.count)
            let maxDelta = predictionDeltas.max() ?? 0
            let lossDelta = before.loss - after.loss
            recordTrainingTrace(
                String(
                    format: "verification-after: loss %.8f→%.8f Δ=%+.8f predΔ mean=%.8f max=%.8f",
                    before.loss,
                    after.loss,
                    lossDelta,
                    meanDelta,
                    maxDelta
                )
            )

            guard maxDelta > 0 || lossDelta != 0 else {
                throw PrayerAutoAdvanceTrainingVerificationError.noMeasurableModelChange
            }

            stage = "committing-model"
            diagnostics.pipelineState = stage
            lastTrainingEvent = "Trening potwierdzony. Zapisywanie nowego modelu…"
            recordTrainingTrace("committing-model: replacing Personalized.mlmodelc")
            let committedModel = try await Task.detached(priority: .utility) {
                let fileManager = FileManager.default
                _ = try fileManager.replaceItemAt(destinationModelURL, withItemAt: updatedURL)
                return try PrayerAutoAdvanceCoreMLModel(compiledURL: destinationModelURL)
            }.value
            model = committedModel
            recordTrainingTrace("committing-model: replacement and reload OK")

            let validation = evaluations.1
            diagnostics.recordTrainingUpdate(
                before: before,
                after: after,
                validation: validation,
                trainedPageCount: trainedPageCount
            )
            diagnostics.event(
                String(
                    format: "heartbeat loss %.8f→%.8f Δ=%+.8f predΔ mean=%.8f max=%.8f",
                    before.loss,
                    after.loss,
                    lossDelta,
                    meanDelta,
                    maxDelta
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

            if let observedDelay = batch.observedDelay {
                timingHistory.append(observedDelay)
            }
            if var value = metadata {
                value.lastUpdatedAt = Date()
                value.trainedTransitions += trainedPageCount
                value.trainingSessions += 1
                metadata = value
            }

            stage = "persisting-state"
            diagnostics.pipelineState = stage
            lastTrainingEvent = "Model zapisany. Zapisywanie metadanych treningu…"
            recordTrainingTrace("persisting-state: metadata/validation JSON")
            try await PrayerAutoAdvanceCoreMLDiskState.saveInBackground(self)

            lastError = nil
            lastTrainingEvent = "Model zaktualizowany zbiorczo na podstawie \(trainedPageCount) stron i \(batch.samples.count) próbek."
            diagnostics.acceptedTrainingCount += 1
            diagnostics.pipelineState = "trained"
            diagnostics.event("MLUpdateTask complete pages=\(trainedPageCount) epochs=\(PrayerAutoAdvanceCoreMLModel.trainingEpochCount)")
            recordTrainingTrace("SUCCESS pages=\(trainedPageCount) samples=\(batch.samples.count)")
            return true
        } catch {
            let staleURL = updatedURL
            Task.detached(priority: .utility) {
                try? FileManager.default.removeItem(at: staleURL)
            }
            let message = "\(stage): \(error.localizedDescription)"
            lastError = message
            lastTrainingEvent = "Błąd treningu [\(stage)]: \(error.localizedDescription)"
            diagnostics.pipelineState = "error-\(stage)"
            diagnostics.error(message)
            recordTrainingTrace("FAIL \(message)")
            return false
        }
    }
}

private enum PrayerAutoAdvanceTrainingVerificationError: LocalizedError {
    case evaluationBeforeFailed
    case evaluationAfterFailed
    case incompleteEvaluation(before: Int, after: Int, expected: Int)
    case noMeasurableModelChange

    var errorDescription: String? {
        switch self {
        case .evaluationBeforeFailed:
            "Nie udało się ocenić modelu na batchu przed MLUpdateTask. Trening nie został uruchomiony."
        case .evaluationAfterFailed:
            "MLUpdateTask zwrócił model, ale nie udało się ocenić jego predykcji przed zapisem."
        case let .incompleteEvaluation(before, after, expected):
            "Ewaluacja batcha jest niepełna (przed: \(before), po: \(after), oczekiwano: \(expected))."
        case .noMeasurableModelChange:
            "MLUpdateTask zakończył się bez żadnej zmiany loss ani predykcji. Nowy model nie został zapisany."
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
            ) else {
                return nil
            }
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

        guard losses.count == samples.count, !losses.isEmpty else { return nil }
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

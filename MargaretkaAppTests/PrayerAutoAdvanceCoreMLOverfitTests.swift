import Foundation
import Testing
@testable import MargaretkaApp

struct PrayerAutoAdvanceCoreMLOverfitTests {
    @Test func bundledModelRapidlyOverfitsFiveSyntheticAudioPatterns() async throws {
        let sourceURL = try #require(findBundledModel())
        let initialModel = try PrayerAutoAdvanceCoreMLModel(compiledURL: sourceURL)
        #expect(initialModel.declaredModelVersion == 8)
        #expect(initialModel.declaredFeatureSchemaVersion == PrayerAutoAdvanceCoreMLModel.currentFeatureSchemaVersion)

        let samples = syntheticSamples()
        let initialLoss = try crossEntropy(model: initialModel, samples: samples)

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrayerAutoAdvanceOverfit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        var current = initialModel
        var losses: [Double] = [initialLoss]
        var checkpoints: [Int: [Double]] = [0: try predictions(model: current, samples: samples)]

        // Each MLUpdateTask already performs the model's configured internal epochs.
        // The purpose of this test is not to model production frequency but to prove
        // end-to-end that repeated Core ML updates can strongly overfit a tiny,
        // deterministic and trivially separable set.
        for round in 1...16 {
            let destination = root.appendingPathComponent("round-\(round).mlmodelc", isDirectory: true)
            try await PrayerAutoAdvanceCoreMLModel.update(
                modelAt: current.compiledURL,
                samples: samples,
                savingTo: destination
            )
            current = try PrayerAutoAdvanceCoreMLModel(compiledURL: destination)
            losses.append(try crossEntropy(model: current, samples: samples))
            if [4, 8, 12, 16].contains(round) {
                checkpoints[round] = try predictions(model: current, samples: samples)
            }
        }

        let finalLoss = try #require(losses.last)
        let finalPredictions = try predictions(model: current, samples: samples)
        let paired = Array(zip(samples, finalPredictions))
        let positive = paired.filter { $0.0.label == 1 }.map { $0.1 }
        let negative = paired.filter { $0.0.label == 0 }.map { $0.1 }

        // Backprop heartbeat: learning must be clearly visible well before the
        // final overfit checkpoint, rather than appearing only after many updates.
        #expect(losses[4] < initialLoss * 0.80)
        #expect(losses[8] < initialLoss * 0.60)

        // Strong end-state requirements. Do not relax these merely to make the
        // test pass: the five patterns are intentionally easy and repeated.
        #expect(finalLoss < initialLoss * 0.20)
        #expect(finalLoss < 0.12)
        #expect(average(positive) > 0.92)
        #expect(average(negative) < 0.10)

        // Emit useful values in Xcode's test log when a future model change alters
        // convergence. This makes failures actionable without another debug build.
        print("PrayerAutoAdvance overfit initialLoss=\(initialLoss) losses=\(losses)")
        for round in [0, 4, 8, 12, 16] {
            if let values = checkpoints[round] {
                print("PrayerAutoAdvance overfit round \(round): \(values)")
            }
        }
    }

    private func syntheticSamples() -> [PrayerAutoAdvanceLabeledSample] {
        [
            sample(id: 0, label: 0, audioLevel: 0.05, pulseOffset: 0),
            sample(id: 1, label: 0, audioLevel: 0.10, pulseOffset: 80),
            sample(id: 2, label: 1, audioLevel: 0.82, pulseOffset: 160),
            sample(id: 3, label: 1, audioLevel: 0.90, pulseOffset: 240),
            sample(id: 4, label: 1, audioLevel: 0.96, pulseOffset: 320),
        ]
    }

    private func sample(id: Int, label: Int64, audioLevel: Float, pulseOffset: Int) -> PrayerAutoAdvanceLabeledSample {
        var features = Array(repeating: Float.zero, count: PrayerAutoAdvanceCoreMLModel.inputSize)
        features[0] = Float(id) / 10
        features[1] = label == 1 ? 0.85 : 0.15
        features[2] = 0.5

        let shortAudioStart = PrayerAutoAdvanceFeatureExtractor.progressFeatureCount
            + 2 * PrayerAutoAdvanceFeatureExtractor.textEmbeddingSize
        for index in shortAudioStart..<features.count {
            features[index] = audioLevel
        }
        for index in pulseOffset..<min(pulseOffset + 40, PrayerAutoAdvanceAudioFeatureExtractor.featureCount) {
            features[shortAudioStart + index] = min(1, audioLevel + 0.04)
        }

        var longAudio = Array(repeating: audioLevel, count: PrayerAutoAdvanceCoreMLModel.longAudioInputSize)
        let longStart = (pulseOffset * 3) % max(1, longAudio.count - 80)
        for index in longStart..<min(longStart + 80, longAudio.count) {
            longAudio[index] = min(1, audioLevel + 0.03)
        }

        return PrayerAutoAdvanceLabeledSample(
            features: features,
            longAudioFeatures: longAudio,
            label: label
        )
    }

    private func predictions(
        model: PrayerAutoAdvanceCoreMLModel,
        samples: [PrayerAutoAdvanceLabeledSample]
    ) throws -> [Double] {
        try samples.map { sample in
            Double(try model.prediction(for: sample.features, longAudioFeatures: sample.longAudioFeatures))
        }
    }

    private func crossEntropy(
        model: PrayerAutoAdvanceCoreMLModel,
        samples: [PrayerAutoAdvanceLabeledSample]
    ) throws -> Double {
        let probabilities = try predictions(model: model, samples: samples)
        let values = zip(samples, probabilities).map { pair -> Double in
            let sample = pair.0
            let raw = pair.1
            let p = min(max(raw, 1e-6), 1 - 1e-6)
            return sample.label == 1 ? -log(p) : -log(1 - p)
        }
        return values.reduce(0, +) / Double(values.count)
    }

    private func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func findBundledModel() -> URL? {
        for bundle in Bundle.allBundles + Bundle.allFrameworks {
            if let url = bundle.url(forResource: "PrayerAutoAdvance", withExtension: "mlmodelc") {
                return url
            }
        }
        return Bundle.main.url(forResource: "PrayerAutoAdvance", withExtension: "mlmodelc")
    }
}

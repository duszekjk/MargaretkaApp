import CoreML
import Foundation

final class PrayerAutoAdvanceCoreMLModel {
    static let inputSize = PrayerAutoAdvanceFeatureExtractor.featureCount
    static let longAudioInputSize = PrayerAutoAdvanceLongAudioFeatureExtractor.featureCount
    static let currentFeatureSchemaVersion = 3

    let compiledURL: URL
    private(set) var model: MLModel

    init(compiledURL: URL) throws {
        self.compiledURL = compiledURL
        self.model = try MLModel(contentsOf: compiledURL)
    }

    func prediction(for features: [Float], longAudioFeatures: [Float]) throws -> Float {
        guard features.count == Self.inputSize,
              longAudioFeatures.count == Self.longAudioInputSize else {
            throw ModelError.invalidFeatureCount
        }
        let provider = try MLDictionaryFeatureProvider(dictionary: [
            "features": MLFeatureValue(multiArray: try Self.featureArray(features)),
            "long_audio": MLFeatureValue(multiArray: try Self.longAudioArray(longAudioFeatures)),
        ])
        let output = try model.prediction(from: provider)
        guard let probabilities = output.featureValue(for: "probabilities")?.multiArrayValue,
              probabilities.count >= 2 else {
            throw ModelError.invalidOutput
        }
        return probabilities[1].floatValue
    }

    static func trainingProvider(sample: PrayerAutoAdvanceLabeledSample) throws -> MLFeatureProvider {
        guard sample.features.count == inputSize,
              sample.longAudioFeatures.count == longAudioInputSize else {
            throw ModelError.invalidFeatureCount
        }

        let labelArray = try MLMultiArray(shape: [1], dataType: .int32)
        labelArray[0] = NSNumber(value: Int32(sample.label))

        return try MLDictionaryFeatureProvider(dictionary: [
            "features": MLFeatureValue(multiArray: try featureArray(sample.features)),
            "long_audio": MLFeatureValue(multiArray: try longAudioArray(sample.longAudioFeatures)),
            "probabilities_true": MLFeatureValue(multiArray: labelArray),
        ])
    }

    static func update(
        modelAt compiledURL: URL,
        samples: [PrayerAutoAdvanceLabeledSample],
        savingTo destinationURL: URL
    ) async throws {
        let providers = try samples.map(trainingProvider)
        let retention = UpdateRetention(providers: providers)
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .cpuOnly

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            do {
                retention.task = try MLUpdateTask(
                    forModelAt: compiledURL,
                    trainingData: retention.batch,
                    configuration: configuration
                ) { context in
                    if context.task.state == .failed {
                        let error = context.task.error ?? ModelError.updateFailedWithoutError
                        retention.task = nil
                        continuation.resume(throwing: error)
                        return
                    }

                    do {
                        let fileManager = FileManager.default
                        if fileManager.fileExists(atPath: destinationURL.path) {
                            try fileManager.removeItem(at: destinationURL)
                        }
                        try context.model.write(to: destinationURL)
                        retention.task = nil
                        continuation.resume()
                    } catch {
                        retention.task = nil
                        continuation.resume(throwing: error)
                    }
                }
                retention.task?.resume()
            } catch {
                retention.task = nil
                continuation.resume(throwing: error)
            }
        }
    }

    private static func featureArray(_ features: [Float]) throws -> MLMultiArray {
        let inputArray = try MLMultiArray(shape: [NSNumber(value: inputSize)], dataType: .float32)
        for (index, feature) in features.enumerated() {
            inputArray[index] = NSNumber(value: feature.isFinite ? feature : 0)
        }
        return inputArray
    }

    private static func longAudioArray(_ features: [Float]) throws -> MLMultiArray {
        let inputArray = try MLMultiArray(
            shape: [
                1,
                NSNumber(value: PrayerAutoAdvanceLongAudioFeatureExtractor.temporalBins),
                NSNumber(value: PrayerAutoAdvanceLongAudioFeatureExtractor.frequencyBands),
            ],
            dataType: .float32
        )
        for (index, feature) in features.enumerated() {
            inputArray[index] = NSNumber(value: feature.isFinite ? feature : 0)
        }
        return inputArray
    }

    private final class UpdateRetention {
        let providers: [MLFeatureProvider]
        let batch: MLArrayBatchProvider
        var task: MLUpdateTask?

        init(providers: [MLFeatureProvider]) {
            self.providers = providers
            self.batch = MLArrayBatchProvider(array: providers)
        }
    }

    enum ModelError: LocalizedError {
        case invalidFeatureCount
        case invalidOutput
        case updateFailedWithoutError

        var errorDescription: String? {
            switch self {
            case .invalidFeatureCount:
                "Model automatycznego przełączania otrzymał nieprawidłowy zestaw cech."
            case .invalidOutput:
                "Model automatycznego przełączania zwrócił nieprawidłowy wynik."
            case .updateFailedWithoutError:
                "Core ML zakończył aktualizację modelu niepowodzeniem bez szczegółowego błędu."
            }
        }
    }
}

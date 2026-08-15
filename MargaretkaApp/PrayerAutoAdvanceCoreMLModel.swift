import CoreML
import Foundation

final class PrayerAutoAdvanceCoreMLModel {
    static let inputSize = PrayerAutoAdvanceFeatureExtractor.featureCount
    static let currentFeatureSchemaVersion = 2

    let compiledURL: URL
    private(set) var model: MLModel

    init(compiledURL: URL) throws {
        self.compiledURL = compiledURL
        self.model = try MLModel(contentsOf: compiledURL)
    }

    func prediction(for features: [Float]) throws -> Float {
        guard features.count == Self.inputSize else { throw ModelError.invalidFeatureCount }
        let inputArray = try Self.multiArray(features)
        let provider = try MLDictionaryFeatureProvider(dictionary: [
            "features": MLFeatureValue(multiArray: inputArray)
        ])
        let output = try model.prediction(from: provider)
        guard let probabilities = output.featureValue(for: "probabilities")?.multiArrayValue,
              probabilities.count >= 2 else {
            throw ModelError.invalidOutput
        }
        return probabilities[1].floatValue
    }

    static func trainingProvider(features: [Float], label: Int64) throws -> MLFeatureProvider {
        guard features.count == inputSize else { throw ModelError.invalidFeatureCount }
        let inputArray = try multiArray(features)

        let labelArray = try MLMultiArray(shape: [1], dataType: .int32)
        labelArray[0] = NSNumber(value: Int32(label))

        return try MLDictionaryFeatureProvider(dictionary: [
            "features": MLFeatureValue(multiArray: inputArray),
            "probabilities_true": MLFeatureValue(multiArray: labelArray),
        ])
    }

    static func update(
        modelAt compiledURL: URL,
        samples: [(features: [Float], label: Int64)],
        savingTo destinationURL: URL
    ) async throws {
        let providers = try samples.map {
            try trainingProvider(features: $0.features, label: $0.label)
        }
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

    private static func multiArray(_ features: [Float]) throws -> MLMultiArray {
        let inputArray = try MLMultiArray(shape: [NSNumber(value: inputSize)], dataType: .float32)
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

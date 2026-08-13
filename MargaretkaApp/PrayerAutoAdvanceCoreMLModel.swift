import CoreML
import Foundation

struct PrayerAutoAdvanceLocalMetadata: Codable, Sendable {
    var baseModelVersion: Int
    var featureSchemaVersion: Int
    var createdAt: Date
    var lastUpdatedAt: Date
    var trainingSessions: Int
    var trainedTransitions: Int
}

struct PrayerAutoAdvanceManifest: Codable, Sendable {
    let modelVersion: Int
    let featureSchemaVersion: Int
    let modelURL: URL
    let sha256: String
    let publishedAt: Date?
}

final class PrayerAutoAdvanceCoreMLModel {
    static let inputSize = 10
    static let currentFeatureSchemaVersion = 1

    let compiledURL: URL
    private(set) var model: MLModel

    init(compiledURL: URL) throws {
        self.compiledURL = compiledURL
        self.model = try MLModel(contentsOf: compiledURL)
    }

    func prediction(for features: [Float]) throws -> Float {
        guard features.count == Self.inputSize else { throw ModelError.invalidFeatureCount }
        let inputArray = try MLMultiArray(
            shape: [NSNumber(value: Self.inputSize)],
            dataType: .float32
        )
        for (index, feature) in features.enumerated() {
            inputArray[index] = NSNumber(value: min(max(feature, 0), 1))
        }
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
        let inputArray = try MLMultiArray(
            shape: [NSNumber(value: inputSize)],
            dataType: .float32
        )
        for (index, feature) in features.enumerated() {
            inputArray[index] = NSNumber(value: min(max(feature, 0), 1))
        }
        return try MLDictionaryFeatureProvider(dictionary: [
            "features": MLFeatureValue(multiArray: inputArray),
            "probabilities_true": MLFeatureValue(int64: label),
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
        let batch = MLArrayBatchProvider(array: providers)
        try await withCheckedThrowingContinuation { continuation in
            do {
                let task = try MLUpdateTask(
                    forModelAt: compiledURL,
                    trainingData: batch,
                    configuration: MLModelConfiguration()
                ) { context in
                    do {
                        let fileManager = FileManager.default
                        if fileManager.fileExists(atPath: destinationURL.path) {
                            try fileManager.removeItem(at: destinationURL)
                        }
                        try context.model.write(to: destinationURL)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
                task.resume()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    enum ModelError: LocalizedError {
        case invalidFeatureCount
        case invalidOutput

        var errorDescription: String? {
            switch self {
            case .invalidFeatureCount:
                "Model automatycznego przełączania otrzymał nieprawidłowy zestaw cech."
            case .invalidOutput:
                "Model automatycznego przełączania zwrócił nieprawidłowy wynik."
            }
        }
    }
}

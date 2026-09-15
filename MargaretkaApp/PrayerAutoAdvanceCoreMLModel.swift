import CoreML
import Foundation

final class PrayerAutoAdvanceCoreMLModel: @unchecked Sendable {
    static let inputSize = PrayerAutoAdvanceFeatureExtractor.featureCount
    static let longAudioInputSize = PrayerAutoAdvanceLongAudioFeatureExtractor.featureCount
    static let combinedInputSize = inputSize + longAudioInputSize
    static let currentModelVersion = 12
    static let currentFeatureSchemaVersion = 9
    static let trainingEpochCount = 3
    static let trainingLearningRate = 0.000002

    let compiledURL: URL
    private(set) var model: MLModel

    init(compiledURL: URL) throws {
        self.compiledURL = compiledURL
        self.model = try MLModel(contentsOf: compiledURL)
    }

    var declaredModelVersion: Int? {
        creatorDefinedMetadata["modelVersion"].flatMap(Int.init)
    }

    var declaredFeatureSchemaVersion: Int? {
        creatorDefinedMetadata["featureSchemaVersion"].flatMap(Int.init)
    }

    var declaredAllParameterizedLayersUpdatable: Bool {
        creatorDefinedMetadata["allParameterizedLayersUpdatable"] == "true"
    }

    var declaredUpdatableLayers: [String] {
        creatorDefinedMetadata["updatableLayers"]?
            .split(separator: ",")
            .map(String.init) ?? []
    }

    private var creatorDefinedMetadata: [String: String] {
        model.modelDescription.metadata[.creatorDefinedKey] as? [String: String] ?? [:]
    }

    func prediction(for features: [Float], longAudioFeatures: [Float]) throws -> Float {
        let provider = try MLDictionaryFeatureProvider(dictionary: [
            "features": MLFeatureValue(multiArray: try Self.combinedFeatureArray(
                features: features,
                longAudioFeatures: longAudioFeatures
            )),
        ])
        let output = try model.prediction(from: provider)
        guard let probabilities = output.featureValue(for: "probabilities")?.multiArrayValue,
              probabilities.count >= 2 else {
            throw ModelError.invalidOutput
        }
        return probabilities[1].floatValue
    }

    static func trainingProvider(sample: PrayerAutoAdvanceLabeledSample) throws -> MLFeatureProvider {
        let labelArray = try MLMultiArray(shape: [1], dataType: .int32)
        labelArray[0] = NSNumber(value: Int32(sample.label))

        return try MLDictionaryFeatureProvider(dictionary: [
            "features": MLFeatureValue(multiArray: try combinedFeatureArray(
                features: sample.features,
                longAudioFeatures: sample.longAudioFeatures
            )),
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
        configuration.computeUnits = .cpuAndGPU
        configuration.parameters = [
            MLParameterKey.epochs: NSNumber(value: trainingEpochCount),
            MLParameterKey.learningRate: NSNumber(value: trainingLearningRate),
            MLParameterKey.shuffle: NSNumber(value: true),
        ]

        await PrayerAutoAdvanceLiveTrainingProgress.shared.beginCoreML(
            sampleCount: providers.count,
            epochs: trainingEpochCount
        )

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            do {
                let progressHandlers = MLUpdateProgressHandlers(
                    forEvents: [.trainingBegin, .miniBatchEnd, .epochEnd],
                    progressHandler: { context in
                        guard context.event == .miniBatchEnd || context.event == .epochEnd else {
                            return
                        }

                        let epochIndex = (context.metrics[.epochIndex] as? NSNumber)?.intValue ?? 0
                        let miniBatchIndex = (context.metrics[.miniBatchIndex] as? NSNumber)?.intValue ?? 0
                        let loss = (context.metrics[.lossValue] as? NSNumber)?.doubleValue
                        let globalStep = max(0, epochIndex) * max(providers.count, 1)
                            + max(0, miniBatchIndex) + 1
                        let shouldPublish = context.event == .epochEnd
                            || globalStep.isMultiple(of: PrayerAutoAdvanceLiveTrainingProgress.progressUpdateStride)
                            || globalStep >= providers.count * trainingEpochCount

                        guard shouldPublish else { return }
                        Task { @MainActor in
                            PrayerAutoAdvanceLiveTrainingProgress.shared.receive(
                                epochIndex: epochIndex,
                                miniBatchIndex: miniBatchIndex,
                                loss: loss
                            )
                        }
                    },
                    completionHandler: { context in
                        if context.task.state == .failed {
                            let error = context.task.error ?? ModelError.updateFailedWithoutError
                            retention.task = nil
                            Task { @MainActor in
                                PrayerAutoAdvanceLiveTrainingProgress.shared.fail()
                            }
                            continuation.resume(throwing: error)
                            return
                        }

                        Task { @MainActor in
                            PrayerAutoAdvanceLiveTrainingProgress.shared.beginFinalization()
                        }

                        let writeJob = ModelWriteJob(
                            model: context.model,
                            destinationURL: destinationURL
                        )
                        Task.detached(priority: .background) {
                            do {
                                try writeJob.write()
                                retention.task = nil
                                continuation.resume()
                            } catch {
                                retention.task = nil
                                await PrayerAutoAdvanceLiveTrainingProgress.shared.fail()
                                continuation.resume(throwing: error)
                            }
                        }
                    }
                )

                retention.task = try MLUpdateTask(
                    forModelAt: compiledURL,
                    trainingData: retention.batch,
                    configuration: configuration,
                    progressHandlers: progressHandlers
                )
                retention.task?.resume()
            } catch {
                retention.task = nil
                Task { @MainActor in
                    PrayerAutoAdvanceLiveTrainingProgress.shared.fail()
                }
                continuation.resume(throwing: error)
            }
        }
    }

    private static func combinedFeatureArray(
        features: [Float],
        longAudioFeatures: [Float]
    ) throws -> MLMultiArray {
        guard features.count == inputSize,
              longAudioFeatures.count == longAudioInputSize else {
            throw ModelError.invalidFeatureCount
        }

        let array = try MLMultiArray(
            shape: [NSNumber(value: combinedInputSize)],
            dataType: .float32
        )
        var index = 0
        for value in features {
            array[index] = NSNumber(value: value.isFinite ? value : 0)
            index += 1
        }
        for value in longAudioFeatures {
            array[index] = NSNumber(value: value.isFinite ? value : 0)
            index += 1
        }
        return array
    }

    private final class UpdateRetention: @unchecked Sendable {
        let providers: [MLFeatureProvider]
        let batch: MLArrayBatchProvider
        var task: MLUpdateTask?

        init(providers: [MLFeatureProvider]) {
            self.providers = providers
            self.batch = MLArrayBatchProvider(array: providers)
        }
    }

    private final class ModelWriteJob: @unchecked Sendable {
        let model: any MLWritable
        let destinationURL: URL

        init(model: any MLWritable, destinationURL: URL) {
            self.model = model
            self.destinationURL = destinationURL
        }

        func write() throws {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try model.write(to: destinationURL)
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

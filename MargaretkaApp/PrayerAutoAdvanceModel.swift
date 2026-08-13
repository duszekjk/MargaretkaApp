import Accelerate
import Foundation

struct PrayerAutoAdvanceModelPayload: Codable, Sendable {
    static let currentFeatureSchemaVersion = 1
    static let inputSize = 10

    var modelVersion: Int
    var featureSchemaVersion: Int
    var trainedTransitions: Int
    var trainingSteps: Int

    var inputToHidden: [Float]
    var hiddenBias: [Float]
    var hiddenToHidden: [Float]
    var secondHiddenBias: [Float]
    var hiddenToOutput: [Float]
    var outputBias: Float

    static let hiddenSize = 32
    static let secondHiddenSize = 16

    static func developerSeed(modelVersion: Int = 1) -> Self {
        func seeded(_ count: Int, scale: Float, offset: Int) -> [Float] {
            (0..<count).map { index in
                // Deterministic initialization makes DEBUG bootstrap reproducible while
                // keeping release builds free of a bundled model asset.
                let value = sin(Double(index + offset) * 12.9898) * 43758.5453
                let fraction = value - floor(value)
                return Float((fraction * 2.0) - 1.0) * scale
            }
        }

        return Self(
            modelVersion: modelVersion,
            featureSchemaVersion: currentFeatureSchemaVersion,
            trainedTransitions: 0,
            trainingSteps: 0,
            inputToHidden: seeded(inputSize * hiddenSize, scale: 0.12, offset: 11),
            hiddenBias: Array(repeating: 0, count: hiddenSize),
            hiddenToHidden: seeded(hiddenSize * secondHiddenSize, scale: 0.10, offset: 1009),
            secondHiddenBias: Array(repeating: 0, count: secondHiddenSize),
            hiddenToOutput: seeded(secondHiddenSize, scale: 0.08, offset: 4001),
            outputBias: -2.0
        )
    }

    var isStructurallyValid: Bool {
        featureSchemaVersion == Self.currentFeatureSchemaVersion
            && inputToHidden.count == Self.inputSize * Self.hiddenSize
            && hiddenBias.count == Self.hiddenSize
            && hiddenToHidden.count == Self.hiddenSize * Self.secondHiddenSize
            && secondHiddenBias.count == Self.secondHiddenSize
            && hiddenToOutput.count == Self.secondHiddenSize
    }

    func prediction(for rawFeatures: [Float]) -> Float {
        guard isStructurallyValid, rawFeatures.count == Self.inputSize else { return 0 }
        let features = rawFeatures.map { min(max($0, 0), 1) }
        let hidden = denseRelu(
            input: features,
            weights: inputToHidden,
            bias: hiddenBias,
            outputSize: Self.hiddenSize
        )
        let secondHidden = denseRelu(
            input: hidden,
            weights: hiddenToHidden,
            bias: secondHiddenBias,
            outputSize: Self.secondHiddenSize
        )
        let logit = dot(secondHidden, hiddenToOutput) + outputBias
        return sigmoid(logit)
    }

    mutating func train(samples: [(features: [Float], label: Float)], learningRate: Float = 0.012) {
        guard isStructurallyValid, !samples.isEmpty else { return }
        for sample in samples where sample.features.count == Self.inputSize {
            trainOne(features: sample.features.map { min(max($0, 0), 1) }, label: min(max(sample.label, 0), 1), learningRate: learningRate)
            trainingSteps += 1
        }
        if samples.contains(where: { $0.label > 0.5 }) {
            trainedTransitions += 1
        }
    }

    private mutating func trainOne(features: [Float], label: Float, learningRate: Float) {
        var hiddenPre = Array(repeating: Float.zero, count: Self.hiddenSize)
        var hidden = Array(repeating: Float.zero, count: Self.hiddenSize)
        for output in 0..<Self.hiddenSize {
            var sum = hiddenBias[output]
            let base = output * Self.inputSize
            for input in 0..<Self.inputSize {
                sum += inputToHidden[base + input] * features[input]
            }
            hiddenPre[output] = sum
            hidden[output] = max(0, sum)
        }

        var secondPre = Array(repeating: Float.zero, count: Self.secondHiddenSize)
        var second = Array(repeating: Float.zero, count: Self.secondHiddenSize)
        for output in 0..<Self.secondHiddenSize {
            var sum = secondHiddenBias[output]
            let base = output * Self.hiddenSize
            for input in 0..<Self.hiddenSize {
                sum += hiddenToHidden[base + input] * hidden[input]
            }
            secondPre[output] = sum
            second[output] = max(0, sum)
        }

        let prediction = sigmoid(dot(second, hiddenToOutput) + outputBias)
        // BCE + sigmoid derivative simplifies to prediction - label.
        let outputGradient = prediction - label

        var secondGradient = Array(repeating: Float.zero, count: Self.secondHiddenSize)
        for index in 0..<Self.secondHiddenSize {
            secondGradient[index] = outputGradient * hiddenToOutput[index]
            hiddenToOutput[index] -= learningRate * outputGradient * second[index]
        }
        outputBias -= learningRate * outputGradient

        var hiddenGradient = Array(repeating: Float.zero, count: Self.hiddenSize)
        for output in 0..<Self.secondHiddenSize {
            let reluGradient: Float = secondPre[output] > 0 ? 1 : 0
            let gradient = secondGradient[output] * reluGradient
            let base = output * Self.hiddenSize
            for input in 0..<Self.hiddenSize {
                hiddenGradient[input] += gradient * hiddenToHidden[base + input]
                hiddenToHidden[base + input] -= learningRate * gradient * hidden[input]
            }
            secondHiddenBias[output] -= learningRate * gradient
        }

        for output in 0..<Self.hiddenSize {
            let reluGradient: Float = hiddenPre[output] > 0 ? 1 : 0
            let gradient = hiddenGradient[output] * reluGradient
            let base = output * Self.inputSize
            for input in 0..<Self.inputSize {
                inputToHidden[base + input] -= learningRate * gradient * features[input]
            }
            hiddenBias[output] -= learningRate * gradient
        }
    }

    private func denseRelu(input: [Float], weights: [Float], bias: [Float], outputSize: Int) -> [Float] {
        var result = Array(repeating: Float.zero, count: outputSize)
        let inputSize = input.count
        for output in 0..<outputSize {
            var sum = bias[output]
            let base = output * inputSize
            for index in 0..<inputSize {
                sum += weights[base + index] * input[index]
            }
            result[output] = max(0, sum)
        }
        return result
    }

    private func dot(_ lhs: [Float], _ rhs: [Float]) -> Float {
        var result: Float = 0
        vDSP_dotpr(lhs, 1, rhs, 1, &result, vDSP_Length(min(lhs.count, rhs.count)))
        return result
    }

    private func sigmoid(_ value: Float) -> Float {
        1 / (1 + exp(-min(max(value, -20), 20)))
    }
}

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

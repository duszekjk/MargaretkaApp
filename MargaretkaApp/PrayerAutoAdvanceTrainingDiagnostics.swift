import Foundation
import OSLog
internal import Combine

struct PrayerAutoAdvanceEpochMetric: Codable, Sendable, Identifiable {
    let id: Int
    let trainingMargin: Double
    let validationMargin: Double?
}

@MainActor
final class PrayerAutoAdvanceTrainingDiagnostics: ObservableObject {
    static let shared = PrayerAutoAdvanceTrainingDiagnostics()
    static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MargaretkaApp",
        category: "PrayerAutoAdvanceTraining"
    )

    static let epochSize = 100
    private static let epochStorageKey = "PrayerAutoAdvanceTrainingEpochHistoryV3"

    @Published var speechState = "idle"
    @Published var pipelineState = "idle"
    @Published var snapshotCount = 0
    @Published var manualSwipeCount = 0
    @Published var acceptedTrainingCount = 0
    @Published var skippedTrainingCount = 0
    @Published var predictionHistory: [Float] = []
    @Published var recentMessages: [String] = []
    @Published var lastFeatureSummary = "—"

    @Published var positiveSamples = 0
    @Published var negativeSamples = 0
    @Published var positivePredictionAverage: Float?
    @Published var negativePredictionAverage: Float?
    @Published var predictionMargin: Float?
    @Published var logLoss: Double?
    @Published var lastTrainingLossChange: Double?

    @Published private(set) var completedEpochs: [PrayerAutoAdvanceEpochMetric] = []
    @Published private(set) var currentEpochSampleCount = 0
    @Published private(set) var currentEpochTrainingMarginAverage: Double?
    @Published private(set) var currentValidationMargin: Double?

    @Published var timingMAE: TimeInterval?
    @Published var timingBias: TimeInterval?
    @Published var timingHitHalfSecond: Double?
    @Published var timingHitOneSecond: Double?
    @Published var timingHitTwoSeconds: Double?
    @Published var lastPeakTimingError: TimeInterval?
    @Published var lastPeakPrediction: Float?

    private var timingErrors: [TimeInterval] = []
    private var currentEpochTrainingMarginSum: Double = 0

    private init() {
        loadEpochState()
    }

    var currentEpochNumber: Int { completedEpochs.count + 1 }
    var previousEpoch: PrayerAutoAdvanceEpochMetric? { completedEpochs.last }

    func prediction(_ value: Float, snapshotCount: Int, features: [Float]) {
        self.snapshotCount = snapshotCount
        predictionHistory.append(value)
        if predictionHistory.count > 48 {
            predictionHistory.removeFirst(predictionHistory.count - 48)
        }
        if features.count >= PrayerAutoAdvanceFeatureExtractor.progressFeatureCount {
            lastFeatureSummary = String(
                format: "cur %.2f next %.2f end %.2f ratio %.2f emb 512 aud 600",
                features[0], features[1], features[4], features[6]
            )
        }
        Self.logger.debug("prediction=\(value, privacy: .public) snapshots=\(snapshotCount, privacy: .public) features=\(self.lastFeatureSummary, privacy: .public)")
    }

    func evaluateTiming(
        model: PrayerAutoAdvanceCoreMLModel,
        snapshots: [PrayerAutoAdvanceTrainingSnapshot],
        manualAdvanceAt: Date
    ) {
        let scored = snapshots.compactMap { snapshot -> (PrayerAutoAdvanceTrainingSnapshot, Float)? in
            guard let score = try? model.prediction(for: snapshot.features) else { return nil }
            return (snapshot, score)
        }
        guard let peak = scored.max(by: { $0.1 < $1.1 }) else { return }

        let error = peak.0.date.timeIntervalSince(manualAdvanceAt)
        lastPeakTimingError = error
        lastPeakPrediction = peak.1
        timingErrors.append(error)
        if timingErrors.count > 100 { timingErrors.removeFirst(timingErrors.count - 100) }

        let absolute = timingErrors.map(abs)
        timingMAE = absolute.reduce(0, +) / Double(absolute.count)
        timingBias = timingErrors.reduce(0, +) / Double(timingErrors.count)
        timingHitHalfSecond = hitRate(within: 0.5)
        timingHitOneSecond = hitRate(within: 1.0)
        timingHitTwoSeconds = hitRate(within: 2.0)

        Self.logger.info("timing peak=\(peak.1, privacy: .public) error=\(error, privacy: .public)s mae=\(self.timingMAE ?? 0, privacy: .public)s")
    }

    func evaluateBatch(
        model: PrayerAutoAdvanceCoreMLModel,
        samples: [(features: [Float], label: Int64)],
        phase: String
    ) -> Double? {
        var positive: [Float] = []
        var negative: [Float] = []
        var losses: [Double] = []

        for sample in samples {
            guard let prediction = try? model.prediction(for: sample.features) else { continue }
            let p = min(max(Double(prediction), 1e-6), 1 - 1e-6)
            if sample.label == 1 {
                positive.append(prediction)
                losses.append(-log(p))
            } else {
                negative.append(prediction)
                losses.append(-log(1 - p))
            }
        }

        positiveSamples = samples.filter { $0.label == 1 }.count
        negativeSamples = samples.filter { $0.label == 0 }.count
        positivePredictionAverage = average(positive)
        negativePredictionAverage = average(negative)
        if let pos = positivePredictionAverage, let neg = negativePredictionAverage {
            predictionMargin = pos - neg
        } else {
            predictionMargin = nil
        }
        let loss = losses.isEmpty ? nil : losses.reduce(0, +) / Double(losses.count)
        logLoss = loss

        Self.logger.info(
            "batch \(phase, privacy: .public) P=\(self.positiveSamples, privacy: .public) N=\(self.negativeSamples, privacy: .public) posAvg=\(self.positivePredictionAverage ?? -1, privacy: .public) negAvg=\(self.negativePredictionAverage ?? -1, privacy: .public) margin=\(self.predictionMargin ?? 0, privacy: .public) loss=\(loss ?? -1, privacy: .public)"
        )
        return loss
    }

    func recordSuccessfulTrainingEpochSample(trainingMargin: Float?, validationMargin: Double?) {
        guard let trainingMargin else { return }

        currentValidationMargin = validationMargin
        currentEpochTrainingMarginSum += Double(trainingMargin)
        currentEpochSampleCount += 1
        currentEpochTrainingMarginAverage = currentEpochTrainingMarginSum / Double(currentEpochSampleCount)

        if currentEpochSampleCount >= Self.epochSize {
            let trainingAverage = currentEpochTrainingMarginAverage ?? 0
            let epoch = PrayerAutoAdvanceEpochMetric(
                id: completedEpochs.count + 1,
                trainingMargin: trainingAverage,
                validationMargin: validationMargin
            )
            completedEpochs.append(epoch)
            if completedEpochs.count > 24 {
                completedEpochs.removeFirst(completedEpochs.count - 24)
            }
            Self.logger.info(
                "epoch complete number=\(epoch.id, privacy: .public) trainMargin=\(trainingAverage, privacy: .public) validationMargin=\(validationMargin ?? -1, privacy: .public)"
            )
            event(
                String(
                    format: "epoch %d complete train=%+.3f val=%@",
                    epoch.id,
                    trainingAverage,
                    validationMargin.map { String(format: "%+.3f", $0) } ?? "—"
                )
            )
            currentEpochSampleCount = 0
            currentEpochTrainingMarginSum = 0
            currentEpochTrainingMarginAverage = nil
        }

        saveEpochState()
    }

    func resetEpochHistory() {
        completedEpochs = []
        currentEpochSampleCount = 0
        currentEpochTrainingMarginSum = 0
        currentEpochTrainingMarginAverage = nil
        currentValidationMargin = nil
        UserDefaults.standard.removeObject(forKey: Self.epochStorageKey)
    }

    func recordLossChange(before: Double?, after: Double?) {
        guard let before, let after else {
            lastTrainingLossChange = nil
            return
        }
        lastTrainingLossChange = before - after
    }

    func event(_ message: String) {
        recentMessages.append(message)
        if recentMessages.count > 6 {
            recentMessages.removeFirst(recentMessages.count - 6)
        }
        Self.logger.info("\(message, privacy: .public)")
    }

    func error(_ message: String) {
        recentMessages.append("ERR: \(message)")
        if recentMessages.count > 6 {
            recentMessages.removeFirst(recentMessages.count - 6)
        }
        Self.logger.error("\(message, privacy: .public)")
    }

    private func average(_ values: [Float]) -> Float? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Float(values.count)
    }

    private func hitRate(within tolerance: TimeInterval) -> Double? {
        guard !timingErrors.isEmpty else { return nil }
        let hits = timingErrors.filter { abs($0) <= tolerance }.count
        return Double(hits) / Double(timingErrors.count)
    }

    private func loadEpochState() {
        guard let data = UserDefaults.standard.data(forKey: Self.epochStorageKey),
              let value = try? JSONDecoder().decode(EpochState.self, from: data) else { return }
        completedEpochs = value.completedEpochs
        currentEpochSampleCount = value.currentCount
        currentEpochTrainingMarginSum = value.currentTrainingMarginSum
        currentValidationMargin = value.currentValidationMargin
        if currentEpochSampleCount > 0 {
            currentEpochTrainingMarginAverage = currentEpochTrainingMarginSum / Double(currentEpochSampleCount)
        }
    }

    private func saveEpochState() {
        let value = EpochState(
            completedEpochs: completedEpochs,
            currentCount: currentEpochSampleCount,
            currentTrainingMarginSum: currentEpochTrainingMarginSum,
            currentValidationMargin: currentValidationMargin
        )
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: Self.epochStorageKey)
        }
    }

    private struct EpochState: Codable {
        let completedEpochs: [PrayerAutoAdvanceEpochMetric]
        let currentCount: Int
        let currentTrainingMarginSum: Double
        let currentValidationMargin: Double?
    }
}

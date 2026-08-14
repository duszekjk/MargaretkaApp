import Foundation
import OSLog
internal import Combine

@MainActor
final class PrayerAutoAdvanceTrainingDiagnostics: ObservableObject {
    static let shared = PrayerAutoAdvanceTrainingDiagnostics()
    static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MargaretkaApp",
        category: "PrayerAutoAdvanceTraining"
    )

    static let epochSize = 100
    private static let epochStorageKey = "PrayerAutoAdvanceTrainingEpochHistoryV1"

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

    @Published private(set) var completedEpochMargins: [Double] = []
    @Published private(set) var currentEpochSampleCount = 0
    @Published private(set) var currentEpochMarginAverage: Double?

    @Published var timingMAE: TimeInterval?
    @Published var timingBias: TimeInterval?
    @Published var timingHitHalfSecond: Double?
    @Published var timingHitOneSecond: Double?
    @Published var timingHitTwoSeconds: Double?
    @Published var lastPeakTimingError: TimeInterval?
    @Published var lastPeakPrediction: Float?

    private var timingErrors: [TimeInterval] = []
    private var currentEpochMarginSum: Double = 0

    private init() {
        loadEpochState()
    }

    var currentEpochNumber: Int { completedEpochMargins.count + 1 }
    var previousEpochMargin: Double? { completedEpochMargins.last }

    func prediction(_ value: Float, snapshotCount: Int, features: [Float]) {
        self.snapshotCount = snapshotCount
        predictionHistory.append(value)
        if predictionHistory.count > 48 {
            predictionHistory.removeFirst(predictionHistory.count - 48)
        }
        if features.count >= 10 {
            lastFeatureSummary = String(
                format: "cur %.2f next %.2f end %.2f ratio %.2f sil %.2f",
                features[0], features[1], features[4], features[8], features[6]
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

    func recordSuccessfulTrainingEpochSample(margin: Float?) {
        guard let margin else { return }

        currentEpochMarginSum += Double(margin)
        currentEpochSampleCount += 1
        currentEpochMarginAverage = currentEpochMarginSum / Double(currentEpochSampleCount)

        if currentEpochSampleCount >= Self.epochSize {
            let completedAverage = currentEpochMarginAverage ?? 0
            completedEpochMargins.append(completedAverage)
            if completedEpochMargins.count > 24 {
                completedEpochMargins.removeFirst(completedEpochMargins.count - 24)
            }
            Self.logger.info(
                "epoch complete number=\(self.completedEpochMargins.count, privacy: .public) samples=\(Self.epochSize, privacy: .public) margin=\(completedAverage, privacy: .public)"
            )
            event(String(format: "epoch %d complete margin=%+.3f", completedEpochMargins.count, completedAverage))
            currentEpochSampleCount = 0
            currentEpochMarginSum = 0
            currentEpochMarginAverage = nil
        }

        saveEpochState()
    }

    func resetEpochHistory() {
        completedEpochMargins = []
        currentEpochSampleCount = 0
        currentEpochMarginSum = 0
        currentEpochMarginAverage = nil
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
        completedEpochMargins = value.completedMargins
        currentEpochSampleCount = value.currentCount
        currentEpochMarginSum = value.currentMarginSum
        if currentEpochSampleCount > 0 {
            currentEpochMarginAverage = currentEpochMarginSum / Double(currentEpochSampleCount)
        }
    }

    private func saveEpochState() {
        let value = EpochState(
            completedMargins: completedEpochMargins,
            currentCount: currentEpochSampleCount,
            currentMarginSum: currentEpochMarginSum
        )
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: Self.epochStorageKey)
        }
    }

    private struct EpochState: Codable {
        let completedMargins: [Double]
        let currentCount: Int
        let currentMarginSum: Double
    }
}

import Foundation
import OSLog
internal import Combine

struct PrayerAutoAdvanceEpochMetric: Codable, Sendable, Identifiable {
    let id: Int
    let trainingMargin: Double
    let validationMargin: Double?
    let trainingLoss: Double?
    let validationLoss: Double?
    let meanPredictionDelta: Double?
}

struct PrayerAutoAdvanceTrainingUpdateMetric: Codable, Sendable, Identifiable {
    let id: Int
    let date: Date
    let epoch: Int
    let positionInEpoch: Int
    let sampleCount: Int
    let positiveCount: Int
    let negativeCount: Int
    let lossBefore: Double
    let lossAfter: Double
    let lossDelta: Double
    let trainingMargin: Double?
    let validationMargin: Double?
    let validationLoss: Double?
    let positiveAverage: Double?
    let negativeAverage: Double?
    let meanPredictionDelta: Double
    let maxPredictionDelta: Double
}

struct PrayerAutoAdvanceBatchEvaluation: Sendable {
    let loss: Double
    let positiveAverage: Double?
    let negativeAverage: Double?
    let margin: Double?
    let predictions: [Double]
    let positiveCount: Int
    let negativeCount: Int
}

@MainActor
final class PrayerAutoAdvanceTrainingDiagnostics: ObservableObject {
    static let shared = PrayerAutoAdvanceTrainingDiagnostics()
    static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MargaretkaApp",
        category: "PrayerAutoAdvanceTraining"
    )

    static let epochSize = 100
    private static let epochStorageKey = "PrayerAutoAdvanceTrainingEpochHistoryV4"
    private static let legacyEpochStorageKey = "PrayerAutoAdvanceTrainingEpochHistoryV3"
    private static let maximumStoredUpdates = 1_200
    private static let persistenceQueue = DispatchQueue(
        label: "PrayerAutoAdvanceTrainingDiagnostics.persistence",
        qos: .utility
    )

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
    @Published var lastMeanPredictionDelta: Double?
    @Published var lastMaxPredictionDelta: Double?
    @Published private(set) var ineffectiveUpdateStreak = 0

    @Published private(set) var completedEpochs: [PrayerAutoAdvanceEpochMetric] = []
    @Published private(set) var updateHistory: [PrayerAutoAdvanceTrainingUpdateMetric] = []
    @Published private(set) var currentEpochSampleCount = 0
    @Published private(set) var currentEpochTrainingMarginAverage: Double?
    @Published private(set) var currentEpochTrainingLossAverage: Double?
    @Published private(set) var currentValidationMargin: Double?
    @Published private(set) var currentValidationLoss: Double?

    @Published var timingMAE: TimeInterval?
    @Published var timingBias: TimeInterval?
    @Published var timingHitHalfSecond: Double?
    @Published var timingHitOneSecond: Double?
    @Published var timingHitTwoSeconds: Double?
    @Published var lastPeakTimingError: TimeInterval?
    @Published var lastPeakPrediction: Float?

    private var timingErrors: [TimeInterval] = []
    private var currentEpochTrainingMarginSum: Double = 0
    private var currentEpochTrainingMarginCount = 0
    private var currentEpochTrainingLossSum: Double = 0
    private var currentEpochTrainingLossCount = 0
    private var currentEpochPredictionDeltaSum: Double = 0

    private init() {
        loadEpochState()
    }

    var currentEpochNumber: Int { completedEpochs.count + 1 }
    var previousEpoch: PrayerAutoAdvanceEpochMetric? { completedEpochs.last }

    var currentEpochUpdates: [PrayerAutoAdvanceTrainingUpdateMetric] {
        updateHistory.filter { $0.epoch == currentEpochNumber }
    }

    var backpropStatus: String {
        guard !updateHistory.isEmpty else { return "brak wykonanych aktualizacji" }
        if ineffectiveUpdateStreak >= 2 {
            return "brak mierzalnej zmiany (\(ineffectiveUpdateStreak) z rzędu)"
        }
        return "aktywna zmiana wag"
    }

    func prediction(_ value: Float, snapshotCount: Int, features: [Float]) {
        self.snapshotCount = snapshotCount
        predictionHistory.append(value)
        if predictionHistory.count > 48 {
            predictionHistory.removeFirst(predictionHistory.count - 48)
        }
        if features.count >= PrayerAutoAdvanceFeatureExtractor.progressFeatureCount {
            lastFeatureSummary = String(
                format: "elapsed %.2f spokenN %.2f pageN %.2f lastSpeechEnd %.2f speechEmb=512 pageEmb=512 aud10=%d aud60=%d",
                features[0],
                features[1],
                features[2],
                features[3],
                PrayerAutoAdvanceAudioFeatureExtractor.featureCount,
                PrayerAutoAdvanceLongAudioFeatureExtractor.featureCount
            )
        }
        Self.logger.debug("prediction=\(value, privacy: .public) snapshots=\(snapshotCount, privacy: .public) features=\(self.lastFeatureSummary, privacy: .public)")
    }

    func recordTrainingUpdate(
        before: PrayerAutoAdvanceBatchEvaluation,
        after: PrayerAutoAdvanceBatchEvaluation,
        validation: PrayerAutoAdvanceValidationMetrics
    ) {
        positiveSamples = after.positiveCount
        negativeSamples = after.negativeCount
        positivePredictionAverage = after.positiveAverage.map(Float.init)
        negativePredictionAverage = after.negativeAverage.map(Float.init)
        predictionMargin = after.margin.map(Float.init)
        logLoss = after.loss
        let lossDelta = before.loss - after.loss
        lastTrainingLossChange = lossDelta

        let deltas = zip(before.predictions, after.predictions).map { abs($1 - $0) }
        let meanDelta = deltas.isEmpty ? 0 : deltas.reduce(0, +) / Double(deltas.count)
        let maxDelta = deltas.max() ?? 0
        lastMeanPredictionDelta = meanDelta
        lastMaxPredictionDelta = maxDelta
        let measurableFloor = 1e-8
        if meanDelta <= measurableFloor,
           maxDelta <= measurableFloor,
           abs(lossDelta) <= measurableFloor {
            ineffectiveUpdateStreak += 1
            if ineffectiveUpdateStreak == 2 {
                event("UWAGA: dwa kolejne MLUpdateTask bez mierzalnej zmiany loss ani predykcji")
            }
        } else {
            ineffectiveUpdateStreak = 0
        }
        currentValidationMargin = validation.margin
        currentValidationLoss = validation.loss

        let metric = PrayerAutoAdvanceTrainingUpdateMetric(
            id: (updateHistory.last?.id ?? 0) + 1,
            date: Date(),
            epoch: currentEpochNumber,
            positionInEpoch: currentEpochSampleCount + 1,
            sampleCount: after.positiveCount + after.negativeCount,
            positiveCount: after.positiveCount,
            negativeCount: after.negativeCount,
            lossBefore: before.loss,
            lossAfter: after.loss,
            lossDelta: lossDelta,
            trainingMargin: after.margin,
            validationMargin: validation.margin,
            validationLoss: validation.loss,
            positiveAverage: after.positiveAverage,
            negativeAverage: after.negativeAverage,
            meanPredictionDelta: meanDelta,
            maxPredictionDelta: maxDelta
        )
        updateHistory.append(metric)
        if updateHistory.count > Self.maximumStoredUpdates {
            updateHistory.removeFirst(updateHistory.count - Self.maximumStoredUpdates)
        }

        if let margin = after.margin {
            currentEpochTrainingMarginSum += margin
            currentEpochTrainingMarginCount += 1
            currentEpochTrainingMarginAverage = currentEpochTrainingMarginSum / Double(currentEpochTrainingMarginCount)
        }
        currentEpochTrainingLossSum += after.loss
        currentEpochTrainingLossCount += 1
        currentEpochTrainingLossAverage = currentEpochTrainingLossSum / Double(currentEpochTrainingLossCount)
        currentEpochPredictionDeltaSum += meanDelta
        currentEpochSampleCount += 1

        if currentEpochSampleCount >= Self.epochSize {
            let epoch = PrayerAutoAdvanceEpochMetric(
                id: completedEpochs.count + 1,
                trainingMargin: currentEpochTrainingMarginAverage ?? 0,
                validationMargin: validation.margin,
                trainingLoss: currentEpochTrainingLossAverage,
                validationLoss: validation.loss,
                meanPredictionDelta: currentEpochPredictionDeltaSum / Double(currentEpochSampleCount)
            )
            completedEpochs.append(epoch)
            if completedEpochs.count > 24 {
                completedEpochs.removeFirst(completedEpochs.count - 24)
            }
            event(String(format: "epoch %d trainLoss=%.6f valLoss=%@ margin=%+.4f", epoch.id, epoch.trainingLoss ?? 0, epoch.validationLoss.map { String(format: "%.6f", $0) } ?? "—", epoch.trainingMargin))
            resetCurrentEpochAccumulators()
        }

        Self.logger.info("heartbeat loss \(before.loss, privacy: .public) -> \(after.loss, privacy: .public), dLoss=\(before.loss - after.loss, privacy: .public), meanDPred=\(meanDelta, privacy: .public), maxDPred=\(maxDelta, privacy: .public)")
        saveEpochStateInBackground()
    }

    func resetEpochHistory() {
        completedEpochs = []
        updateHistory = []
        currentValidationMargin = nil
        currentValidationLoss = nil
        lastTrainingLossChange = nil
        lastMeanPredictionDelta = nil
        lastMaxPredictionDelta = nil
        ineffectiveUpdateStreak = 0
        resetCurrentEpochAccumulators()
        UserDefaults.standard.removeObject(forKey: Self.epochStorageKey)
        UserDefaults.standard.removeObject(forKey: Self.legacyEpochStorageKey)
    }

    func recordLossChange(before: Double?, after: Double?) {
        guard let before, let after else { lastTrainingLossChange = nil; return }
        lastTrainingLossChange = before - after
    }

    func event(_ message: String) {
        recentMessages.append(message)
        if recentMessages.count > 6 { recentMessages.removeFirst(recentMessages.count - 6) }
        Self.logger.info("\(message, privacy: .public)")
    }

    func error(_ message: String) {
        recentMessages.append("ERR: \(message)")
        if recentMessages.count > 6 { recentMessages.removeFirst(recentMessages.count - 6) }
        Self.logger.error("\(message, privacy: .public)")
    }

    private func resetCurrentEpochAccumulators() {
        currentEpochSampleCount = 0
        currentEpochTrainingMarginSum = 0
        currentEpochTrainingMarginCount = 0
        currentEpochTrainingMarginAverage = nil
        currentEpochTrainingLossSum = 0
        currentEpochTrainingLossCount = 0
        currentEpochTrainingLossAverage = nil
        currentEpochPredictionDeltaSum = 0
    }

    private func loadEpochState() {
        guard let data = UserDefaults.standard.data(forKey: Self.epochStorageKey),
              let value = try? JSONDecoder().decode(EpochState.self, from: data) else { return }
        completedEpochs = value.completedEpochs
        updateHistory = value.updateHistory
        currentEpochSampleCount = value.currentCount
        currentEpochTrainingMarginSum = value.currentTrainingMarginSum
        currentEpochTrainingMarginCount = value.currentTrainingMarginCount
        currentEpochTrainingLossSum = value.currentTrainingLossSum
        currentEpochTrainingLossCount = value.currentTrainingLossCount
        currentEpochPredictionDeltaSum = value.currentPredictionDeltaSum
        currentValidationMargin = value.currentValidationMargin
        currentValidationLoss = value.currentValidationLoss
        if currentEpochTrainingMarginCount > 0 {
            currentEpochTrainingMarginAverage = currentEpochTrainingMarginSum / Double(currentEpochTrainingMarginCount)
        }
        if currentEpochTrainingLossCount > 0 {
            currentEpochTrainingLossAverage = currentEpochTrainingLossSum / Double(currentEpochTrainingLossCount)
        }
    }

    private func saveEpochStateInBackground() {
        let value = EpochState(
            completedEpochs: completedEpochs,
            updateHistory: updateHistory,
            currentCount: currentEpochSampleCount,
            currentTrainingMarginSum: currentEpochTrainingMarginSum,
            currentTrainingMarginCount: currentEpochTrainingMarginCount,
            currentTrainingLossSum: currentEpochTrainingLossSum,
            currentTrainingLossCount: currentEpochTrainingLossCount,
            currentPredictionDeltaSum: currentEpochPredictionDeltaSum,
            currentValidationMargin: currentValidationMargin,
            currentValidationLoss: currentValidationLoss
        )
        let key = Self.epochStorageKey
        Self.persistenceQueue.async {
            guard let data = try? JSONEncoder().encode(value) else { return }
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private struct EpochState: Codable, Sendable {
        let completedEpochs: [PrayerAutoAdvanceEpochMetric]
        let updateHistory: [PrayerAutoAdvanceTrainingUpdateMetric]
        let currentCount: Int
        let currentTrainingMarginSum: Double
        let currentTrainingMarginCount: Int
        let currentTrainingLossSum: Double
        let currentTrainingLossCount: Int
        let currentPredictionDeltaSum: Double
        let currentValidationMargin: Double?
        let currentValidationLoss: Double?
    }
}

import Foundation
internal import Combine

struct PrayerAutoAdvanceLiveLossPoint: Identifiable, Sendable {
    var id: Int { step }
    let step: Int
    let epoch: Int
    let loss: Double
}

@MainActor
final class PrayerAutoAdvanceLiveTrainingProgress: ObservableObject {
    static let shared = PrayerAutoAdvanceLiveTrainingProgress()

    static let progressUpdateStride = 50
    static let estimatedFinalizationDuration: TimeInterval = 35

    @Published private(set) var isActive = false
    @Published private(set) var stage = "Oczekiwanie"
    @Published private(set) var progress: Double = 0
    @Published private(set) var currentEpoch = 0
    @Published private(set) var epochCount = 0
    @Published private(set) var completedSteps = 0
    @Published private(set) var totalSteps = 0
    @Published private(set) var currentLoss: Double?
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var estimatedRemaining: TimeInterval?
    @Published private(set) var lossHistory: [PrayerAutoAdvanceLiveLossPoint] = []

    private var sampleCount = 0
    private var trainingStartedAt: Date?
    private var finalizationStartedAt: Date?
    private var finalizationBaseProgress: Double = 0
    private var finalizationTicker: Task<Void, Never>?

    private init() {}

    func prepare() {
        finalizationTicker?.cancel()
        finalizationTicker = nil
        isActive = true
        stage = "Przygotowanie treningu"
        progress = 0.01
        currentEpoch = 0
        epochCount = 0
        completedSteps = 0
        totalSteps = 0
        currentLoss = nil
        elapsed = 0
        estimatedRemaining = nil
        lossHistory = []
        sampleCount = 0
        trainingStartedAt = nil
        finalizationStartedAt = nil
        finalizationBaseProgress = 0
    }

    func beginCoreML(sampleCount: Int, epochs: Int) {
        finalizationTicker?.cancel()
        finalizationTicker = nil
        isActive = true
        stage = "Core ML — trening"
        self.sampleCount = max(sampleCount, 1)
        epochCount = max(epochs, 1)
        totalSteps = self.sampleCount * epochCount
        completedSteps = 0
        currentEpoch = 1
        currentLoss = nil
        elapsed = 0
        estimatedRemaining = nil
        progress = 0.02
        lossHistory = []
        trainingStartedAt = Date()
        finalizationStartedAt = nil
    }

    func receive(epochIndex: Int, miniBatchIndex: Int, loss: Double?) {
        guard isActive, sampleCount > 0, totalSteps > 0 else { return }

        let epoch = min(max(epochIndex, 0), max(epochCount - 1, 0))
        let miniBatch = min(max(miniBatchIndex, 0), max(sampleCount - 1, 0))
        let step = min(totalSteps, epoch * sampleCount + miniBatch + 1)
        completedSteps = max(completedSteps, step)
        currentEpoch = min(epoch + 1, epochCount)

        if let loss, loss.isFinite {
            currentLoss = loss
            if lossHistory.last?.step != completedSteps {
                lossHistory.append(
                    PrayerAutoAdvanceLiveLossPoint(
                        step: completedSteps,
                        epoch: currentEpoch,
                        loss: loss
                    )
                )
                if lossHistory.count > 240 {
                    lossHistory.removeFirst(lossHistory.count - 240)
                }
            }
        }

        guard let trainingStartedAt else { return }
        elapsed = max(0, Date().timeIntervalSince(trainingStartedAt))
        let trainingFraction = min(max(Double(completedSteps) / Double(totalSteps), 0), 1)

        if trainingFraction > 0, elapsed > 0 {
            let estimatedTrainingTotal = elapsed / trainingFraction
            let trainingRemaining = max(0, estimatedTrainingTotal - elapsed)
            estimatedRemaining = trainingRemaining + Self.estimatedFinalizationDuration
            progress = min(
                0.94,
                elapsed / max(elapsed + (estimatedRemaining ?? 0), 0.001)
            )
        }
    }

    func beginFinalization() {
        guard isActive else { return }
        stage = "Weryfikacja i zapis modelu"
        if let trainingStartedAt {
            elapsed = max(0, Date().timeIntervalSince(trainingStartedAt))
        }
        completedSteps = totalSteps
        currentEpoch = epochCount
        finalizationStartedAt = Date()
        finalizationBaseProgress = max(progress, 0.90)
        estimatedRemaining = Self.estimatedFinalizationDuration
        progress = finalizationBaseProgress

        finalizationTicker?.cancel()
        finalizationTicker = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled, self.isActive, let started = self.finalizationStartedAt {
                let finalizationElapsed = max(0, Date().timeIntervalSince(started))
                let fraction = min(finalizationElapsed / Self.estimatedFinalizationDuration, 1)
                self.estimatedRemaining = max(0, Self.estimatedFinalizationDuration - finalizationElapsed)
                self.progress = self.finalizationBaseProgress
                    + (0.99 - self.finalizationBaseProgress) * fraction
                if let trainingStartedAt = self.trainingStartedAt {
                    self.elapsed = max(0, Date().timeIntervalSince(trainingStartedAt))
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func finish() {
        guard isActive else { return }
        finalizationTicker?.cancel()
        finalizationTicker = nil
        progress = 1
        estimatedRemaining = 0
        if let trainingStartedAt {
            elapsed = max(0, Date().timeIntervalSince(trainingStartedAt))
        }
        stage = "Zakończono"
        isActive = false
    }

    func fail() {
        finalizationTicker?.cancel()
        finalizationTicker = nil
        estimatedRemaining = nil
        stage = "Błąd treningu"
        isActive = false
    }
}

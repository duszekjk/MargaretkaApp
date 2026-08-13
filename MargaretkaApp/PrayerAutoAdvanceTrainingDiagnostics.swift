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

    @Published var speechState = "idle"
    @Published var pipelineState = "idle"
    @Published var snapshotCount = 0
    @Published var manualSwipeCount = 0
    @Published var acceptedTrainingCount = 0
    @Published var skippedTrainingCount = 0
    @Published var predictionHistory: [Float] = []
    @Published var recentMessages: [String] = []
    @Published var lastFeatureSummary = "—"

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
}

import Foundation

extension PrayerAutoAdvanceCoreMLRuntime {
    func evaluatePrediction(
        _ prediction: Float,
        elapsed: TimeInterval,
        speechEndAt: Date?,
        predictionAt: Date
    ) {
        guard UserDefaults.standard.bool(forKey: PrayerAutoAdvancePreferences.automaticEnabledKey),
              Date() >= cooldownUntil,
              elapsed >= 2.0 else {
            consecutiveAdvancePredictions = 0
            return
        }

        consecutiveAdvancePredictions = prediction >= Self.automaticAdvanceThreshold
            ? consecutiveAdvancePredictions + 1
            : 0

        if consecutiveAdvancePredictions >= Self.requiredAdvancePredictions {
            consecutiveAdvancePredictions = 0
            cooldownUntil = predictionAt.addingTimeInterval(3)
            if let pageID = context?.pageID {
                pendingAutomaticAdvance = PrayerAutoAdvancePendingTransition(
                    pageID: pageID,
                    speechEndAt: speechEndAt,
                    predictionAt: predictionAt
                )
            }
            advanceRequestSerial &+= 1
        }
    }

    func recordAutomaticPageTurn(at pageTurnAt: Date = Date()) {
        guard let transition = pendingAutomaticAdvance else { return }
        pendingAutomaticAdvance = nil

        guard transition.pageID == context?.pageID,
              let speechEndAt = transition.speechEndAt,
              speechEndAt <= pageTurnAt else { return }

        PrayerAutoAdvanceTrainingDiagnostics.shared.recordAutomaticAdvanceLatency(
            total: pageTurnAt.timeIntervalSince(speechEndAt),
            prediction: transition.predictionAt.timeIntervalSince(speechEndAt),
            uiSwitch: pageTurnAt.timeIntervalSince(transition.predictionAt)
        )
    }
}

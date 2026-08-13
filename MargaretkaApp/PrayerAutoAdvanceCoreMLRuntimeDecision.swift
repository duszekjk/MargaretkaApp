import Foundation

extension PrayerAutoAdvanceCoreMLRuntime {
    func evaluatePrediction(_ prediction: Float, elapsed: TimeInterval) {
        guard UserDefaults.standard.bool(forKey: PrayerAutoAdvancePreferences.automaticEnabledKey),
              Date() >= cooldownUntil,
              elapsed >= 2.0 else {
            consecutiveAdvancePredictions = 0
            return
        }

        consecutiveAdvancePredictions = prediction >= 0.96
            ? consecutiveAdvancePredictions + 1
            : 0

        if consecutiveAdvancePredictions >= 3 {
            consecutiveAdvancePredictions = 0
            cooldownUntil = Date().addingTimeInterval(3)
            advanceRequestSerial &+= 1
        }
    }
}

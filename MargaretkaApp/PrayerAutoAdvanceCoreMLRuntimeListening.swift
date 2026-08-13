import Foundation

extension PrayerAutoAdvanceCoreMLRuntime {
    func prepareListening() async {
        let diagnostics = PrayerAutoAdvanceTrainingDiagnostics.shared
        guard let context, isFeatureEnabled else { return }
        guard state.model != nil else {
            statusMessage = "Brak lokalnego modelu. Włącz funkcję ponownie w Ustawieniach, aby pobrać model bazowy."
            diagnostics.speechState = "no-model"
            diagnostics.error(statusMessage ?? "missing local model")
            return
        }
#if os(iOS)
        diagnostics.speechState = "starting"
        diagnostics.event("starting on-device speech")
        do {
            try await capture.start(
                language: context.language,
                context: [context.currentText, context.nextText].compactMap { $0 }
            )
            diagnostics.speechState = "listening"
            diagnostics.event("on-device speech active")
            statusMessage = nil
        } catch {
            diagnostics.speechState = "error"
            diagnostics.error(error.localizedDescription)
            statusMessage = error.localizedDescription
        }
#endif
    }

    func evaluateCurrentCapture() async {
#if os(iOS)
        await observe(
            transcript: capture.transcript,
            energy: capture.energy,
            silence: capture.silenceDuration
        )
#endif
    }
}

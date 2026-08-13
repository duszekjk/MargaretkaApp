import Foundation

extension PrayerAutoAdvanceCoreMLRuntime {
    func prepareListening() async {
        guard let context, isFeatureEnabled else { return }
        guard state.model != nil else {
            statusMessage = "Brak lokalnego modelu. Włącz funkcję ponownie w Ustawieniach, aby pobrać model bazowy."
            return
        }
#if os(iOS)
        do {
            try await capture.start(
                language: context.language,
                context: [context.currentText, context.nextText].compactMap { $0 }
            )
            statusMessage = nil
        } catch {
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

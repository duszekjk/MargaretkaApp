import Foundation

extension PrayerAutoAdvanceCoreMLRuntime {
    func prepareListening() async {
        guard let context, isFeatureEnabled else { return }
        guard await state.ensureModelAvailable() else {
            statusMessage = state.lastError ?? "Nie udało się przygotować modelu automatycznego przełączania."
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

    func evaluateCurrentCapture() {
#if os(iOS)
        observe(
            transcript: capture.transcript,
            energy: capture.energy,
            silence: capture.silenceDuration
        )
#endif
    }
}

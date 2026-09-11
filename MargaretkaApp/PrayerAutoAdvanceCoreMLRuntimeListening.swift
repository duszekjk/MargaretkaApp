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
        let plan = evaluationPlan(at: Date())
        guard plan.reservoirSlot != nil || plan.shouldPredict else { return }

        let speech = capture.speechSnapshot()
        let currentSampleIndex = capture.pageAudioSampleIndex()

        if let slot = plan.reservoirSlot, let context {
            let candidate = PrayerAutoAdvanceTrainingCandidate(
                pageID: context.pageID,
                date: plan.date,
                transcript: speech.transcript,
                lastSegmentEndTime: speech.lastSegmentEndTime,
                audioEndSampleIndex: currentSampleIndex
            )
            storeTrainingCandidate(candidate, at: slot)
        }

        // Training-only collection ends here. It records only metadata and never
        // touches the V12 spectral front end until the page is swiped.
        guard plan.shouldPredict else { return }

        let slice = capture.pageAudioSlice(from: lastSpectralSampleIndex)
        lastSpectralSampleIndex = slice.endSampleIndex
        let cache = spectralCache
        let history = await Task.detached(priority: .userInitiated) {
            cache.ingest(samples: slice.samples, startingAt: slice.startSampleIndex)
            return cache.history()
        }.value
        let shortAudio = history.shortFeatures(endingAt: currentSampleIndex)
        let longAudio = history.longFeatures(endingAt: currentSampleIndex)

        await observe(
            speech: speech,
            shortAudio: shortAudio,
            longAudio: longAudio,
            plan: plan
        )
#endif
    }
}

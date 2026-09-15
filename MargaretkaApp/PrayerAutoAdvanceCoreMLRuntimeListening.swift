import Foundation

extension PrayerAutoAdvanceCoreMLRuntime {
    func prepareListening() async {
        let diagnostics = PrayerAutoAdvanceTrainingDiagnostics.shared
        guard let requestedContext = context, isFeatureEnabled else { return }

        if state.model == nil {
            statusMessage = "Przygotowywanie lokalnego modelu…"
            diagnostics.speechState = "preparing-model"
            diagnostics.event("recovering local model")

            guard await state.ensureModelAvailable() else {
                statusMessage = state.lastError
                    ?? "Nie udało się przygotować lokalnego modelu."
                diagnostics.speechState = "no-model"
                diagnostics.error(statusMessage ?? "missing local model")
                return
            }
            diagnostics.event("local model ready")
        }

        guard let activeContext = context,
              activeContext == requestedContext,
              isFeatureEnabled else { return }

#if os(iOS)
        diagnostics.speechState = "starting"
        diagnostics.event("starting on-device speech")
        do {
            try await capture.start(
                language: activeContext.language,
                context: [activeContext.currentText, activeContext.nextText].compactMap { $0 }
            )
            diagnostics.speechState = "listening"
            diagnostics.event("on-device speech active")
            statusMessage = nil
        } catch {
            state.resetMicrophoneActivity()
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

        // The toolbar only needs a near-zero-cost proof that the microphone is
        // delivering a changing signal. Read two scalar PCM values without copying
        // an audio window; the state compares these probes across several 0.5 s ticks.
        let microphoneProbe = capture.microphoneActivityProbe(sampleSpan: 12)
        state.updateMicrophoneActivity(
            transcript: speech.transcript,
            firstSample: microphoneProbe.first,
            lastSample: microphoneProbe.last,
            at: plan.date
        )

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

        guard plan.shouldPredict else { return }

        let slice = capture.pageAudioSlice(from: lastSpectralSampleIndex)
        lastSpectralSampleIndex = slice.endSampleIndex
        let cache = spectralCache
        let audio = await Task.detached(priority: .userInitiated) {
            cache.ingest(samples: slice.samples, startingAt: slice.startSampleIndex)
            return cache.features(endingAt: currentSampleIndex)
        }.value

        await observe(
            speech: speech,
            shortAudio: audio.short,
            longAudio: audio.long,
            plan: plan
        )
#endif
    }
}

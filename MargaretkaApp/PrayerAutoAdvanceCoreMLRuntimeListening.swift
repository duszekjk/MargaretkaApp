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

        // The toolbar only needs a cheap "is there a live microphone signal?" probe.
        // Sample a handful of PCM values once per evaluation tick (~0.5 s). Copying
        // 12 Float values and doing a few scalar operations is cheaper than launching
        // a background task or analyzing an audio window.
        let probeStartIndex = max(0, currentSampleIndex - 12)
        let probe = capture.pageAudioSlice(from: probeStartIndex).samples
        let activity = microphoneActivityProbe(probe)
        state.updateMicrophoneActivity(
            transcript: speech.transcript,
            rms: activity.level,
            variation: activity.variation,
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

private func microphoneActivityProbe(_ samples: [Float]) -> (level: Double, variation: Double) {
    guard let first = samples.first else { return (0, 0) }

    var peak = abs(Double(first))
    var minimum = Double(first)
    var maximum = Double(first)
    for sample in samples.dropFirst() {
        let value = Double(sample)
        peak = max(peak, abs(value))
        minimum = min(minimum, value)
        maximum = max(maximum, value)
    }

    return (
        level: peak,
        variation: maximum - minimum
    )
}

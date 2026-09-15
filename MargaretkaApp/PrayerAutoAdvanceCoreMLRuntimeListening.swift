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

        // A tiny recent PCM window is enough for the toolbar activity indicator.
        // Its RMS/variation calculation stays off MainActor and does not touch the
        // page-wide spectral/materialization path.
        let activityStartIndex = max(0, currentSampleIndex - 4_096)
        let activitySlice = capture.pageAudioSlice(from: activityStartIndex)
        let activity = await Task.detached(priority: .background) {
            microphoneActivityMetrics(activitySlice.samples)
        }.value
        state.updateMicrophoneActivity(
            transcript: speech.transcript,
            rms: activity.rms,
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

private func microphoneActivityMetrics(_ samples: [Float]) -> (rms: Double, variation: Double) {
    guard !samples.isEmpty else { return (0, 0) }

    var squaredSum = 0.0
    var variationSum = 0.0
    var previous = Double(samples[0])
    for sample in samples {
        let value = Double(sample)
        squaredSum += value * value
        variationSum += abs(value - previous)
        previous = value
    }

    let count = Double(samples.count)
    return (
        rms: sqrt(squaredSum / count),
        variation: variationSum / count
    )
}

import Foundation

struct PrayerAutoAdvanceDeferredTrainingPage: Sendable {
    let pageID: String
    let context: PrayerAutoAdvanceContext
    let contextStartedAt: Date
    let manualAdvanceAt: Date
    let swipeSampleIndex: Int
    let swipeSpeech: PrayerAutoAdvanceSpeechSnapshot
    let candidates: [PrayerAutoAdvanceTrainingCandidate]
    let frozenPageAudio: PrayerAutoAdvanceAudioWindow
    let postSwipeAudio: PrayerAutoAdvanceAudioWindow
}

extension PrayerAutoAdvanceCoreMLState {
    func enqueueTrainingPage(_ page: PrayerAutoAdvanceDeferredTrainingPage) {
        pendingTrainingPages.append(page)
        trainingWorkEnqueued += 1
        refreshTrainingQueueMetrics()
        startTrainingQueueIfNeeded()
    }

    func clearPendingTrainingPages() {
        pendingTrainingPages.removeAll(keepingCapacity: false)
        trainingWorkEnqueued = 0
        trainingWorkCompleted = 0
        refreshTrainingQueueMetrics()
    }

    private func startTrainingQueueIfNeeded() {
        guard trainingQueueTask == nil else { return }
        trainingQueueTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.trainingQueueTask = nil
                self.refreshTrainingQueueMetrics()
                if !self.pendingTrainingPages.isEmpty {
                    self.startTrainingQueueIfNeeded()
                }
            }

            while !Task.isCancelled, !self.pendingTrainingPages.isEmpty {
                let page = self.pendingTrainingPages.removeFirst()
                self.refreshTrainingQueueMetrics(activePage: true)
                await self.processDeferredTrainingPage(page)
                self.trainingWorkCompleted += 1
                self.refreshTrainingQueueMetrics(activePage: false)
            }
        }
    }

    private func processDeferredTrainingPage(_ page: PrayerAutoAdvanceDeferredTrainingPage) async {
        let diagnostics = PrayerAutoAdvanceTrainingDiagnostics.shared
        diagnostics.pipelineState = "materializing"
        lastTrainingEvent = "Przetwarzanie danych strony \(trainingWorkCompleted + 1)/\(trainingWorkEnqueued)…"

        let materialized = await Task.detached(priority: .utility) {
            PrayerAutoAdvanceDeferredTrainingMaterializer.materialize(page)
        }.value

        guard let batch = PrayerAutoAdvanceTrainingPolicy.makeBatch(
            snapshots: materialized.negatives,
            positiveSnapshots: materialized.positives,
            manualAdvanceAt: page.manualAdvanceAt,
            history: self.timingHistory
        ) else {
            diagnostics.skippedTrainingCount += 1
            diagnostics.pipelineState = "skipped"
            diagnostics.event(
                "queued training skipped: negatives=\(materialized.negatives.count) positives=\(materialized.positives.count)"
            )
            lastTrainingEvent = "Pominięto stronę: nie udało się zbudować zbalansowanego batcha."
            return
        }

        let positives = batch.samples.filter { $0.label == 1 }.count
        let negatives = batch.samples.count - positives
        diagnostics.event("queued balanced training batch P/N \(positives)/\(negatives)")

        if validationStore.shouldHoldOut(pageID: page.pageID) {
            validationStore.append(pageID: page.pageID, batch: batch, at: page.manualAdvanceAt)
            do {
                try await PrayerAutoAdvanceCoreMLDiskState.saveInBackground(self)
                diagnostics.pipelineState = "validation"
                diagnostics.event(
                    "validation holdout page=\(page.pageID) records=\(validationStore.records.count) samples=\(validationStore.sampleCount)"
                )
                lastTrainingEvent = "Strona trafiła do lokalnego zbioru walidacyjnego."
                lastError = nil
            } catch {
                diagnostics.pipelineState = "error"
                diagnostics.error("validation save: \(error.localizedDescription)")
                lastError = error.localizedDescription
                lastTrainingEvent = "Błąd zapisu walidacji: \(error.localizedDescription)"
            }
            return
        }

        await train(batch)
    }

    private func refreshTrainingQueueMetrics(activePage: Bool? = nil) {
        let active = activePage ?? isTraining
        queuedTrainingPageCount = pendingTrainingPages.count + (active ? 1 : 0)
        trainingQueueProgressTotal = max(trainingWorkEnqueued, 0)
        trainingQueueProgressCompleted = min(trainingWorkCompleted, trainingWorkEnqueued)
    }
}

private enum PrayerAutoAdvanceDeferredTrainingMaterializer {
    static func materialize(
        _ page: PrayerAutoAdvanceDeferredTrainingPage
    ) -> (negatives: [PrayerAutoAdvanceTrainingSnapshot], positives: [PrayerAutoAdvanceTrainingSnapshot]) {
        let selectedCandidates = PrayerAutoAdvanceTrainingPolicy.selectNegativeCandidates(
            page.candidates,
            manualAdvanceAt: page.manualAdvanceAt
        )
        let sampleCount = min(
            PrayerAutoAdvanceTrainingPolicy.maximumSamplesPerClass,
            selectedCandidates.count
        )
        guard sampleCount > 0 else { return ([], []) }

        let sampleRate = page.frozenPageAudio.sampleRate > 0
            ? page.frozenPageAudio.sampleRate
            : PrayerAutoAdvanceSpectralFrontEnd.sampleRate
        let bridgeCount = min(
            page.postSwipeAudio.samples.count,
            max(0, Int((PrayerAutoAdvanceTrainingPolicy.positiveWindow * sampleRate).rounded()))
        )
        let combinedSamples = page.frozenPageAudio.samples
            + Array(page.postSwipeAudio.samples.prefix(bridgeCount))
        let history = PrayerAutoAdvanceSpectralFrontEnd.analyze(samples: combinedSamples)

        let negatives = selectedCandidates.prefix(sampleCount).compactMap {
            candidate -> PrayerAutoAdvanceTrainingSnapshot? in
            let endSampleIndex = min(max(candidate.audioEndSampleIndex, 0), combinedSamples.count)
            let shortAudio = history.shortFeatures(endingAt: endSampleIndex)
            let longAudio = history.longFeatures(endingAt: endSampleIndex)
            let features = PrayerAutoAdvanceFeatureExtractor.features(
                transcript: candidate.transcript,
                context: page.context,
                elapsed: max(0, candidate.date.timeIntervalSince(page.contextStartedAt)),
                lastSegmentEndTime: candidate.lastSegmentEndTime,
                audioFeatures: shortAudio
            )
            guard features.count == PrayerAutoAdvanceCoreMLModel.inputSize,
                  longAudio.count == PrayerAutoAdvanceCoreMLModel.longAudioInputSize else {
                return nil
            }
            return PrayerAutoAdvanceTrainingSnapshot(
                pageID: candidate.pageID,
                date: candidate.date,
                features: features,
                longAudioFeatures: longAudio
            )
        }

        let positiveDates = PrayerAutoAdvanceTrainingPolicy.positiveTargetDates(
            manualAdvanceAt: page.manualAdvanceAt,
            count: sampleCount
        )
        let positives = positiveDates.compactMap {
            targetDate -> PrayerAutoAdvanceTrainingSnapshot? in
            let offset = targetDate.timeIntervalSince(page.manualAdvanceAt)
            let endSampleIndex = min(
                max(page.swipeSampleIndex + Int((offset * sampleRate).rounded()), 0),
                combinedSamples.count
            )
            let shortAudio = history.shortFeatures(endingAt: endSampleIndex)
            let longAudio = history.longFeatures(endingAt: endSampleIndex)
            let features = PrayerAutoAdvanceFeatureExtractor.features(
                transcript: page.swipeSpeech.transcript,
                context: page.context,
                elapsed: max(0, targetDate.timeIntervalSince(page.contextStartedAt)),
                lastSegmentEndTime: page.swipeSpeech.lastSegmentEndTime,
                audioFeatures: shortAudio
            )
            guard features.count == PrayerAutoAdvanceCoreMLModel.inputSize,
                  longAudio.count == PrayerAutoAdvanceCoreMLModel.longAudioInputSize else {
                return nil
            }
            return PrayerAutoAdvanceTrainingSnapshot(
                pageID: page.pageID,
                date: targetDate,
                features: features,
                longAudioFeatures: longAudio
            )
        }
        return (negatives, positives)
    }
}

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
    func registerScheduledTrainingCapture() {
        scheduledTrainingCaptureCount += 1
        refreshTrainingQueueMetrics()
    }

    func submitScheduledTrainingCapture() {
        scheduledTrainingCaptureCount = max(0, scheduledTrainingCaptureCount - 1)
        refreshTrainingQueueMetrics()
    }

    func cancelScheduledTrainingCapture() {
        scheduledTrainingCaptureCount = max(0, scheduledTrainingCaptureCount - 1)
        refreshTrainingQueueMetrics()
        startGroupedTrainingAtPrayerEndIfReady()
    }

    func requestGroupedTrainingAtPrayerEnd() {
        trainingAtPrayerEndRequested = true
        PrayerAutoAdvanceTrainingDiagnostics.shared.event(
            "prayer end: waiting for page materialization before grouped training"
        )
        startGroupedTrainingAtPrayerEndIfReady()
    }

    func processTrainingPageImmediately(_ page: PrayerAutoAdvanceDeferredTrainingPage) async {
        guard !isTrainingPipelineBusy, pendingTrainingPages.isEmpty else {
            enqueueTrainingPage(page)
            return
        }

        resetTrainingProgressIfIdle()
        trainingWorkEnqueued += 1
        isTrainingPipelineBusy = true
        refreshTrainingQueueMetrics(activePage: true)
        defer {
            trainingWorkCompleted += 1
            isTrainingPipelineBusy = false
            refreshTrainingQueueMetrics(activePage: false)
            startTrainingQueueIfNeeded()
            startGroupedTrainingAtPrayerEndIfReady()
        }
        await processTrainingPage(page)
    }

    func enqueueTrainingPage(_ page: PrayerAutoAdvanceDeferredTrainingPage) {
        resetTrainingProgressIfIdle()
        pendingTrainingPages.append(page)
        trainingWorkEnqueued += 1
        refreshTrainingQueueMetrics()
        startTrainingQueueIfNeeded()
    }

    func clearPendingTrainingPages() {
        trainingQueueTask?.cancel()
        trainingQueueTask = nil
        pendingTrainingPages.removeAll(keepingCapacity: false)
        trainingWorkEnqueued = 0
        trainingWorkCompleted = 0
        scheduledTrainingCaptureCount = 0
        isTrainingPipelineBusy = false
        refreshTrainingQueueMetrics()
    }

    private func startTrainingQueueIfNeeded() {
        guard !isTrainingPipelineBusy,
              trainingQueueTask == nil,
              !pendingTrainingPages.isEmpty else { return }

        trainingQueueTask = Task { @MainActor [weak self] in
            guard let self else { return }
            self.isTrainingPipelineBusy = true
            defer {
                self.isTrainingPipelineBusy = false
                self.trainingQueueTask = nil
                self.refreshTrainingQueueMetrics()
                if !self.pendingTrainingPages.isEmpty {
                    self.startTrainingQueueIfNeeded()
                }
                self.startGroupedTrainingAtPrayerEndIfReady()
            }

            while !Task.isCancelled, !self.pendingTrainingPages.isEmpty {
                let page = self.pendingTrainingPages.removeFirst()
                self.refreshTrainingQueueMetrics(activePage: true)
                await self.processTrainingPage(page)
                self.trainingWorkCompleted += 1
                self.refreshTrainingQueueMetrics(activePage: false)
            }
        }
    }

    private func processTrainingPage(_ page: PrayerAutoAdvanceDeferredTrainingPage) async {
        let diagnostics = PrayerAutoAdvanceTrainingDiagnostics.shared
        diagnostics.pipelineState = "materializing"
        lastTrainingEvent = "Przetwarzanie danych strony…"

        let materialized = await Task.detached(priority: .utility) {
            PrayerAutoAdvanceDeferredTrainingMaterializer.materialize(page)
        }.value

        guard let batch = PrayerAutoAdvanceTrainingPolicy.makeBatchFromSelectedNegatives(
            materialized.negatives,
            positiveSnapshots: materialized.positives,
            manualAdvanceAt: page.manualAdvanceAt
        ) else {
            diagnostics.skippedTrainingCount += 1
            diagnostics.pipelineState = "skipped"
            diagnostics.event(
                "training skipped: negatives=\(materialized.negatives.count) positives=\(materialized.positives.count)"
            )
            lastTrainingEvent = "Pominięto stronę: nie udało się zbudować zbalansowanego batcha."
            return
        }

        let positives = batch.samples.filter { $0.label == 1 }.count
        let negatives = batch.samples.count - positives
        diagnostics.event("balanced training batch P/N \(positives)/\(negatives)")

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

        do {
            let directory = pendingTrainingDirectory
            try await Task.detached(priority: .utility) {
                try PrayerAutoAdvancePendingTrainingStore.append(
                    pageID: page.pageID,
                    batch: batch,
                    createdAt: page.manualAdvanceAt,
                    to: directory
                )
            }.value
            storedTrainingPageCount = PrayerAutoAdvancePendingTrainingStore.pageCount(
                in: directory,
                fileManager: fileManager
            )
            diagnostics.pipelineState = "stored"
            diagnostics.event(
                "training page stored \(storedTrainingPageCount)/\(PrayerAutoAdvancePendingTrainingStore.minimumPageCountForUpdate)"
            )
            lastTrainingEvent = "Zapisano stronę do następnego treningu zbiorczego."
            lastError = nil
        } catch {
            diagnostics.pipelineState = "error"
            diagnostics.error("training page save: \(error.localizedDescription)")
            lastError = error.localizedDescription
            lastTrainingEvent = "Błąd zapisu danych treningowych: \(error.localizedDescription)"
        }
    }

    private func refreshTrainingQueueMetrics(activePage: Bool? = nil) {
        let active = activePage ?? (isTrainingPipelineBusy && groupedTrainingPageCount == 0)
        queuedTrainingPageCount = scheduledTrainingCaptureCount
            + pendingTrainingPages.count
            + (active ? 1 : 0)
            + groupedTrainingPageCount
        if groupedTrainingPageCount > 0 {
            trainingQueueProgressTotal = groupedTrainingPageCount
            trainingQueueProgressCompleted = 0
        } else {
            trainingQueueProgressTotal = max(trainingWorkEnqueued, 0)
            trainingQueueProgressCompleted = min(trainingWorkCompleted, trainingWorkEnqueued)
        }
    }

    private func resetTrainingProgressIfIdle() {
        guard !isTrainingPipelineBusy,
              trainingQueueTask == nil,
              pendingTrainingPages.isEmpty,
              trainingWorkCompleted == trainingWorkEnqueued else { return }
        trainingWorkEnqueued = 0
        trainingWorkCompleted = 0
    }

    private func startGroupedTrainingAtPrayerEndIfReady() {
        guard trainingAtPrayerEndRequested,
              scheduledTrainingCaptureCount == 0,
              !isTrainingPipelineBusy,
              trainingQueueTask == nil,
              pendingTrainingPages.isEmpty,
              groupedTrainingTask == nil else { return }

        let freshDirectory = pendingTrainingDirectory
        let replayDirectory = replayTrainingDirectory
        storedTrainingPageCount = PrayerAutoAdvancePendingTrainingStore.pageCount(
            in: freshDirectory,
            fileManager: fileManager
        )
        replayTrainingPageCount = PrayerAutoAdvancePendingTrainingStore.pageCount(
            in: replayDirectory,
            fileManager: fileManager
        )
        guard storedTrainingPageCount >= PrayerAutoAdvancePendingTrainingStore.minimumPageCountForUpdate else {
            trainingAtPrayerEndRequested = false
            PrayerAutoAdvanceTrainingDiagnostics.shared.pipelineState = "waiting-batch"
            lastTrainingEvent = "Dane czekają na kolejną modlitwę: \(storedTrainingPageCount)/\(PrayerAutoAdvancePendingTrainingStore.minimumPageCountForUpdate) nowych stron; replay \(replayTrainingPageCount)."
            refreshTrainingQueueMetrics()
            return
        }

        trainingAtPrayerEndRequested = false
        groupedTrainingPageCount = storedTrainingPageCount + min(
            replayTrainingPageCount,
            PrayerAutoAdvancePendingTrainingStore.maximumReplayPageCount
        )
        isTrainingPipelineBusy = true
        refreshTrainingQueueMetrics()

        groupedTrainingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.groupedTrainingPageCount = 0
                self.isTrainingPipelineBusy = false
                self.groupedTrainingTask = nil
                self.refreshTrainingQueueMetrics()
                self.startTrainingQueueIfNeeded()
            }

            let diagnostics = PrayerAutoAdvanceTrainingDiagnostics.shared
            diagnostics.pipelineState = "loading-batch"
            self.lastTrainingEvent = "Wczytywanie nowych i historycznych stron treningowych…"

            if self.model == nil {
                guard await self.ensureModelAvailable() else {
                    diagnostics.pipelineState = "no-model"
                    diagnostics.error(self.lastError ?? "missing local model")
                    return
                }
            }

            let freshSnapshot: PrayerAutoAdvancePendingTrainingSnapshot
            let replaySnapshot: PrayerAutoAdvancePendingTrainingSnapshot
            do {
                freshSnapshot = try await Task.detached(priority: .utility) {
                    try PrayerAutoAdvancePendingTrainingStore.loadSnapshot(from: freshDirectory)
                }.value
                replaySnapshot = try await Task.detached(priority: .utility) {
                    try PrayerAutoAdvancePendingTrainingStore.loadSnapshot(from: replayDirectory)
                }.value
            } catch {
                self.lastError = error.localizedDescription
                self.lastTrainingEvent = "Błąd odczytu danych treningowych: \(error.localizedDescription)"
                diagnostics.pipelineState = "error"
                diagnostics.error("training batch load: \(error.localizedDescription)")
                return
            }

            guard freshSnapshot.pageCount >= PrayerAutoAdvancePendingTrainingStore.minimumPageCountForUpdate else {
                self.storedTrainingPageCount = freshSnapshot.pageCount
                diagnostics.pipelineState = "waiting-batch"
                return
            }

            let replayPages = Array(
                replaySnapshot.pages
                    .shuffled()
                    .prefix(PrayerAutoAdvancePendingTrainingStore.maximumReplayPageCount)
            )
            let trainingPages = freshSnapshot.pages + replayPages
            let samples = trainingPages.flatMap(\.samples)
            self.groupedTrainingPageCount = trainingPages.count
            self.refreshTrainingQueueMetrics()
            diagnostics.event(
                "grouped MLUpdateTask fresh=\(freshSnapshot.pageCount) replay=\(replayPages.count) total=\(trainingPages.count) samples=\(samples.count) epochs=\(PrayerAutoAdvanceCoreMLModel.trainingEpochCount) lr=\(PrayerAutoAdvanceCoreMLModel.trainingLearningRate) shuffle=true"
            )
            let batch = PrayerAutoAdvanceLabeledBatch(
                samples: samples,
                observedDelay: nil
            )
            let trained = await self.train(batch, trainedPageCount: freshSnapshot.pageCount)
            guard trained, let trainedModel = self.model else { return }

            await PrayerAutoAdvanceTrainingQualityDiagnostics.shared.record(
                pages: trainingPages,
                model: trainedModel,
                freshPageCount: freshSnapshot.pageCount,
                replayPageCount: replayPages.count
            )

            do {
                let replayPool = Array(
                    trainingPages
                        .shuffled()
                        .prefix(PrayerAutoAdvancePendingTrainingStore.maximumReplayPageCount)
                )
                let freshPageIDs = freshSnapshot.pageIDs
                try await Task.detached(priority: .utility) {
                    try PrayerAutoAdvancePendingTrainingStore.replaceAll(
                        with: replayPool,
                        in: replayDirectory
                    )
                    try PrayerAutoAdvancePendingTrainingStore.remove(
                        pageIDs: freshPageIDs,
                        from: freshDirectory
                    )
                }.value
                self.storedTrainingPageCount = PrayerAutoAdvancePendingTrainingStore.pageCount(
                    in: freshDirectory,
                    fileManager: self.fileManager
                )
                self.replayTrainingPageCount = PrayerAutoAdvancePendingTrainingStore.pageCount(
                    in: replayDirectory,
                    fileManager: self.fileManager
                )
                diagnostics.event(
                    "grouped training committed fresh=\(freshSnapshot.pageCount) replayUsed=\(replayPages.count) replayRetained=\(self.replayTrainingPageCount) remainingFresh=\(self.storedTrainingPageCount)"
                )
            } catch {
                self.lastError = error.localizedDescription
                self.lastTrainingEvent = "Model zapisany, ale nie udało się zaktualizować puli replay lub usunąć wykorzystanych nowych danych."
                diagnostics.pipelineState = "cleanup-error"
                diagnostics.error("training data cleanup/replay: \(error.localizedDescription)")
            }
        }
    }
}

private enum PrayerAutoAdvanceDeferredTrainingMaterializer {
    static func materialize(
        _ page: PrayerAutoAdvanceDeferredTrainingPage
    ) -> (negatives: [PrayerAutoAdvanceTrainingSnapshot], positives: [PrayerAutoAdvanceTrainingSnapshot]) {
        let sampleRate = page.frozenPageAudio.sampleRate > 0
            ? page.frozenPageAudio.sampleRate
            : PrayerAutoAdvanceSpectralFrontEnd.sampleRate
        let selectedCandidates = PrayerAutoAdvanceTrainingPolicy.selectNegativeCandidates(
            page.candidates,
            swipeSampleIndex: page.swipeSampleIndex,
            sampleRate: sampleRate
        )
        let sampleCount = min(
            PrayerAutoAdvanceTrainingPolicy.maximumSamplesPerClass,
            selectedCandidates.count
        )
        guard sampleCount > 0 else { return ([], []) }

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
